param(
  [Parameter(Mandatory = $true)]
  [string]$RunDir,

  [Parameter(Mandatory = $true)]
  [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

$rawDir = Join-Path $RunDir "raw"
$telemetryDir = Join-Path $RunDir "telemetry"
New-Item -ItemType Directory -Force $rawDir | Out-Null
New-Item -ItemType Directory -Force $telemetryDir | Out-Null

$summaryPath = Join-Path $telemetryDir "priority-mirror-summary.json"
$manifestPath = Join-Path $telemetryDir "priority-mirror-manifest.json"
$eventsCsvPath = Join-Path $telemetryDir "priority-mirror-events.csv"
$operatorRunbookPath = Join-Path $rawDir "operator-runbook.md"
$commandSummaryPath = Join-Path $rawDir "command-plan-summary.md"

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $Value | ConvertTo-Json -Depth 32 | Set-Content -Encoding UTF8 $Path
}

function New-Gate {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [Parameter(Mandatory = $true)]
    [string]$Status,

    [Parameter(Mandatory = $true)]
    [string]$Observed
  )

  [pscustomobject][ordered]@{
    id = $Id
    status = $Status
    observed = $Observed
  }
}

function Read-JsonLines {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  return @(Get-Content -Path $Path | ForEach-Object {
      if ([string]::IsNullOrWhiteSpace($_)) {
        return
      }

      try {
        $_ | ConvertFrom-Json
      } catch {
        $null
      }
    } | Where-Object { $null -ne $_ })
}

function Get-LatestPrioritySummaryPath {
  param([string]$Root)

  if ($env:FIELDLAB_PRIORITY_SUMMARY_PATH) {
    return $env:FIELDLAB_PRIORITY_SUMMARY_PATH
  }

  $runsPath = Join-Path $Root "fieldlab\runs"
  if (-not (Test-Path $runsPath)) {
    return $null
  }

  $candidate = Get-ChildItem -Path $runsPath -Recurse -Filter "priority-load-summary.json" |
    Where-Object { $_.FullName -match "valheim-lumberjacks-priority-load-order" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if ($candidate) {
    return $candidate.FullName
  }

  return $null
}

function Invoke-HealthProbe {
  param([string]$Url)

  try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 5
    return [ordered]@{
      ok = $true
      status_code = [int]$response.StatusCode
      body = $response.Content
      error = $null
    }
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    return [ordered]@{
      ok = $false
      status_code = $statusCode
      body = $null
      error = $_.Exception.Message
    }
  }
}

function Test-TcpPort {
  param(
    [Parameter(Mandatory = $true)]
    [string]$HostName,

    [Parameter(Mandatory = $true)]
    [int]$Port
  )

  $client = [System.Net.Sockets.TcpClient]::new()
  try {
    $task = $client.ConnectAsync($HostName, $Port)
    $ok = $task.Wait(3000) -and $client.Connected
    return [ordered]@{
      ok = $ok
      host = $HostName
      port = $Port
      error = if ($ok) { $null } else { "connect_timeout_or_refused" }
    }
  } catch {
    return [ordered]@{
      ok = $false
      host = $HostName
      port = $Port
      error = $_.Exception.Message
    }
  } finally {
    $client.Dispose()
  }
}

function Invoke-EventLogPost {
  param(
    [Parameter(Mandatory = $true)]
    [string]$EventLogUrl,

    [Parameter(Mandatory = $true)]
    [object]$Event
  )

  $json = $Event | ConvertTo-Json -Depth 32 -Compress
  try {
    $response = Invoke-WebRequest `
      -Uri "$EventLogUrl/events" `
      -Method Post `
      -Body $json `
      -ContentType "application/json" `
      -UseBasicParsing `
      -TimeoutSec 20

    return [ordered]@{
      ok = $true
      status_code = [int]$response.StatusCode
      body = $response.Content
      error = $null
    }
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    return [ordered]@{
      ok = $false
      status_code = $statusCode
      body = $null
      error = $_.Exception.Message
    }
  }
}

function Invoke-EventLogQuery {
  param(
    [Parameter(Mandatory = $true)]
    [string]$EventLogUrl,

    [Parameter(Mandatory = $true)]
    [string]$EventType,

    [int]$Limit = 2000
  )

  try {
    $encodedType = [uri]::EscapeDataString($EventType)
    $response = Invoke-WebRequest `
      -Uri "$EventLogUrl/events?type=$encodedType&limit=$Limit" `
      -UseBasicParsing `
      -TimeoutSec 20

    $parsed = if ([string]::IsNullOrWhiteSpace($response.Content)) {
      $null
    } else {
      $response.Content | ConvertFrom-Json
    }

    return [ordered]@{
      ok = $true
      status_code = [int]$response.StatusCode
      events = if ($parsed -and $parsed.events) { @($parsed.events) } else { @() }
      count = if ($parsed -and $null -ne $parsed.count) { [int]$parsed.count } else { 0 }
      error = $null
    }
  } catch {
    $statusCode = $null
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $statusCode = [int]$_.Exception.Response.StatusCode
    }

    return [ordered]@{
      ok = $false
      status_code = $statusCode
      events = @()
      count = 0
      error = $_.Exception.Message
    }
  }
}

function Get-PayloadValue {
  param(
    [object]$Event,
    [string]$Name
  )

  if (-not $Event -or -not $Event.payload) {
    return $null
  }

  try {
    $payload = if ($Event.payload -is [string]) {
      $Event.payload | ConvertFrom-Json
    } else {
      $Event.payload
    }

    return $payload.$Name
  } catch {
    return $null
  }
}

function Convert-PriorityObjectRow {
  param(
    [object]$Row,
    [int]$ManifestSeq
  )

  [ordered]@{
    manifest_seq = $ManifestSeq
    timestamp_utc = [string]$Row.timestamp_utc
    session_id = [string]$Row.session_id
    route_stop_id = [string]$Row.route_stop_id
    density_band = [string]$Row.density_band
    sample_index = if ($null -ne $Row.sample_index) { [int]$Row.sample_index } else { 0 }
    object_seq = if ($null -ne $Row.object_seq) { [int]$Row.object_seq } else { $ManifestSeq }
    priority_order = if ($null -ne $Row.priority_order) { [int]$Row.priority_order } else { $ManifestSeq }
    priority_tier = [string]$Row.priority_tier
    priority_reason = [string]$Row.priority_reason
    prefab_name = [string]$Row.object_kind
    object_name = [string]$Row.object_name
    distance_meters = if ($null -ne $Row.distance_meters) { [double]$Row.distance_meters } else { $null }
    world_x = if ($null -ne $Row.object_x) { [double]$Row.object_x } else { $null }
    world_y = if ($null -ne $Row.object_y) { [double]$Row.object_y } else { $null }
    world_z = if ($null -ne $Row.object_z) { [double]$Row.object_z } else { $null }
    owner = if ($null -ne $Row.owner_id) { [string]$Row.owner_id } else { $null }
    creator = if ($null -ne $Row.creator_id) { [string]$Row.creator_id } else { $null }
  }
}

function Convert-PrioritySampleRow {
  param(
    [object]$Row,
    [int]$ManifestSeq
  )

  [pscustomobject][ordered]@{
    manifest_seq = $ManifestSeq
    timestamp_utc = [string]$Row.timestamp_utc
    session_id = [string]$Row.session_id
    route_stop_id = [string]$Row.route_stop_id
    density_band = [string]$Row.density_band
    sample_index = if ($null -ne $Row.sample_index) { [int]$Row.sample_index } else { 0 }
    radius_meters = if ($null -ne $Row.radius_meters) { [double]$Row.radius_meters } else { $null }
    scan_duration_ms = if ($null -ne $Row.scan_duration_ms) { [int]$Row.scan_duration_ms } else { $null }
    collider_count = if ($null -ne $Row.collider_count) { [int]$Row.collider_count } else { $null }
    collider_buffer_full = if ($null -ne $Row.collider_buffer_full) { [bool]$Row.collider_buffer_full } else { $false }
    candidate_count = if ($null -ne $Row.candidate_count) { [int]$Row.candidate_count } else { 0 }
    emitted_object_count = if ($null -ne $Row.emitted_object_count) { [int]$Row.emitted_object_count } else { 0 }
    top_priority_tier = [string]$Row.top_priority_tier
    top_object_name = [string]$Row.top_object_name
    player_critical_count = if ($null -ne $Row.player_critical_count) { [int]$Row.player_critical_count } else { 0 }
    portal_count = if ($null -ne $Row.portal_count) { [int]$Row.portal_count } else { 0 }
    structural_anchor_count = if ($null -ne $Row.structural_anchor_count) { [int]$Row.structural_anchor_count } else { 0 }
    near_interactive_count = if ($null -ne $Row.near_interactive_count) { [int]$Row.near_interactive_count } else { 0 }
    storage_crafting_count = if ($null -ne $Row.storage_crafting_count) { [int]$Row.storage_crafting_count } else { 0 }
    support_piece_count = if ($null -ne $Row.support_piece_count) { [int]$Row.support_piece_count } else { 0 }
    decorative_far_count = if ($null -ne $Row.decorative_far_count) { [int]$Row.decorative_far_count } else { 0 }
  }
}

$eventLogUrl = if ($env:FIELDLAB_LUMBERJACKS_EVENTLOG_URL) {
  $env:FIELDLAB_LUMBERJACKS_EVENTLOG_URL.TrimEnd("/")
} else {
  "http://localhost:4002"
}
$postgresHost = if ($env:FIELDLAB_LUMBERJACKS_POSTGRES_HOST) { $env:FIELDLAB_LUMBERJACKS_POSTGRES_HOST } else { "localhost" }
$postgresPort = if ($env:FIELDLAB_LUMBERJACKS_POSTGRES_PORT) { [int]$env:FIELDLAB_LUMBERJACKS_POSTGRES_PORT } else { 5433 }

$prioritySummaryPath = Get-LatestPrioritySummaryPath -Root $RepoRoot
$prioritySummary = $null
$priorityRows = @()
$routeRows = @()
$sampleRows = @()
$objectRows = @()
$selectedObjectRows = @()
$selectedSampleRows = @()
$manifestSamples = @()
$manifestObjects = @()
$manifestId = "valheim-priority-mirror-" + (Get-Date -Format "yyyyMMdd-HHmmss")
$worldId = "valheim-era16"
$actorId = "comfy-network-sense"
$summaryStatusFromPriority = $null
$priorityStartUtc = $null
$priorityEndUtc = $null
$priorityRouteCompleted = $false

if ($prioritySummaryPath -and (Test-Path $prioritySummaryPath)) {
  $prioritySummary = Get-Content -Raw $prioritySummaryPath | ConvertFrom-Json
  $summaryStatusFromPriority = [string]$prioritySummary.status
  $priorityRouteCompleted = if ($prioritySummary.observed_route_run) { [bool]$prioritySummary.observed_route_run.completed } else { $false }
  if ($prioritySummary.observed_route_run -and $prioritySummary.observed_route_run.start_timestamp_utc) {
    $priorityStartUtc = [datetime]$prioritySummary.observed_route_run.start_timestamp_utc
  }
  if ($prioritySummary.observed_route_run -and $prioritySummary.observed_route_run.end_timestamp_utc) {
    $priorityEndUtc = [datetime]$prioritySummary.observed_route_run.end_timestamp_utc
  }

  if ($prioritySummary.priority_log_path) {
    $priorityRows = @(Read-JsonLines -Path ([string]$prioritySummary.priority_log_path))
  }
}

if ($priorityRows.Count -gt 0) {
  $routeRows = @($priorityRows | Where-Object {
      if ([string]$_.run_label -ne "priority_route" -or [string]::IsNullOrWhiteSpace([string]$_.route_stop_id)) {
        return $false
      }

      if ($priorityStartUtc) {
        $rowTimestamp = [datetime]$_.timestamp_utc
        if ($rowTimestamp -lt $priorityStartUtc) {
          return $false
        }

        if ($priorityEndUtc -and $rowTimestamp -gt $priorityEndUtc.AddSeconds(5)) {
          return $false
        }
      }

      return $true
    })

  $sampleRows = @($routeRows | Where-Object { [string]$_.event -eq "sample" })
  $objectRows = @($routeRows | Where-Object { [string]$_.event -eq "object" })

  $selectedSampleRows = @($sampleRows | Sort-Object timestamp_utc, route_stop_id, sample_index)

  $latestSamplesByStop = @{}
  foreach ($sample in @($sampleRows | Sort-Object timestamp_utc)) {
    $latestSamplesByStop[[string]$sample.route_stop_id] = $sample
  }

  $selectedObjectRows = @()
  foreach ($stopId in @($latestSamplesByStop.Keys | Sort-Object)) {
    $latestSample = $latestSamplesByStop[$stopId]
    $latestSampleId = if ($null -ne $latestSample.sample_id) { [string]$latestSample.sample_id } else { $null }
    $stopObjects = @($objectRows | Where-Object {
        [string]$_.route_stop_id -eq $stopId -and
        ($null -eq $latestSampleId -or [string]$_.sample_id -eq $latestSampleId)
      } | Sort-Object priority_order, distance_meters, object_name)

    $selectedObjectRows += $stopObjects
  }

  $seq = 0
  foreach ($sample in $selectedSampleRows) {
    $seq++
    $manifestSamples += Convert-PrioritySampleRow -Row $sample -ManifestSeq $seq
  }

  foreach ($object in $selectedObjectRows) {
    $seq++
    $manifestObjects += Convert-PriorityObjectRow -Row $object -ManifestSeq $seq
  }
}

$routeStopBuckets = [ordered]@{}
foreach ($record in $manifestObjects) {
  $key = [string]$record.route_stop_id
  if (-not $routeStopBuckets.Contains($key)) {
    $routeStopBuckets[$key] = @()
  }
  $routeStopBuckets[$key] = @($routeStopBuckets[$key]) + $record
}

$routeStopManifests = @($routeStopBuckets.Keys | Sort-Object | ForEach-Object {
    $stopId = [string]$_
    $stopObjects = @($routeStopBuckets[$stopId] | Sort-Object manifest_seq)
    $tierBuckets = [ordered]@{}
    foreach ($record in $stopObjects) {
      $tier = [string]$record.priority_tier
      if (-not $tierBuckets.Contains($tier)) {
        $tierBuckets[$tier] = 0
      }
      $tierBuckets[$tier] = [int]$tierBuckets[$tier] + 1
    }

    [ordered]@{
      route_stop_id = $stopId
      object_rows = $stopObjects.Count
      first_manifest_seq = if ($stopObjects.Count -gt 0) { [int]$stopObjects[0].manifest_seq } else { $null }
      last_manifest_seq = if ($stopObjects.Count -gt 0) { [int]$stopObjects[-1].manifest_seq } else { $null }
      priority_tiers = @($tierBuckets.Keys | Sort-Object | ForEach-Object {
          $tier = [string]$_
          [ordered]@{
            tier = $tier
            count = [int]$tierBuckets[$tier]
          }
        })
    }
  })

$manifest = [ordered]@{
  schema_version = 1
  manifest_id = $manifestId
  source = [ordered]@{
    priority_summary_path = $prioritySummaryPath
    priority_log_path = if ($prioritySummary) { [string]$prioritySummary.priority_log_path } else { $null }
    priority_status = $summaryStatusFromPriority
    route_completed = $priorityRouteCompleted
    start_timestamp_utc = if ($priorityStartUtc) { $priorityStartUtc.ToUniversalTime().ToString("o") } else { $null }
    end_timestamp_utc = if ($priorityEndUtc) { $priorityEndUtc.ToUniversalTime().ToString("o") } else { $null }
    sparse_fixture_note = $summaryStatusFromPriority -eq "pass_priority_route_observed_with_sparse_gap"
  }
  policy = [ordered]@{
    sample_rows = "all route samples from selected route run"
    object_rows = "latest sample per route stop"
    event_order = "sample rows first, object rows second, completion event last"
  }
  counts = [ordered]@{
    source_priority_rows = $priorityRows.Count
    source_route_rows = $routeRows.Count
    source_sample_rows = $sampleRows.Count
    source_object_rows = $objectRows.Count
    mirrored_sample_rows = $manifestSamples.Count
    mirrored_object_rows = $manifestObjects.Count
    mirrored_object_batch_events = $routeStopManifests.Count
    expected_event_count = $manifestSamples.Count + $routeStopManifests.Count + 1
  }
  route_stops = $routeStopManifests
  samples = $manifestSamples
  objects = $manifestObjects
}

Write-JsonFile -Value $manifest -Path $manifestPath

$health = Invoke-HealthProbe -Url "$eventLogUrl/health"
$postgresProbe = Test-TcpPort -HostName $postgresHost -Port $postgresPort
$postResults = @()
$postedOk = 0
$postedFailed = 0
$eventSeq = 0

if ($health.ok -and $postgresProbe.ok -and $manifest.counts.expected_event_count -gt 1 -and $priorityRouteCompleted) {
  foreach ($sample in $manifestSamples) {
    $eventSeq++
    $eventKey = "$manifestId-sample-$($sample.manifest_seq)"
    $eventId = [guid]::NewGuid().ToString()
    $event = [ordered]@{
      event_id = $eventId
      event_type = "valheim.priority_manifest.sample"
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
      world_id = $worldId
      region_id = [string]$sample.route_stop_id
      actor_id = $actorId
      guild_id = $null
      source_service = "ComfyNetworkSense.FieldLab"
      schema_version = 1
      payload = [ordered]@{
        manifest_id = $manifestId
        event_key = $eventKey
        event_seq = $eventSeq
        record = $sample
      }
    }

    $result = Invoke-EventLogPost -EventLogUrl $eventLogUrl -Event $event
    if ($result.ok) { $postedOk++ } else { $postedFailed++ }
    $postResults += [pscustomobject]@{
      event_id = $eventId
      event_key = $eventKey
      event_type = "valheim.priority_manifest.sample"
      event_seq = $eventSeq
      manifest_seq = $sample.manifest_seq
      route_stop_id = $sample.route_stop_id
      priority_tier = ""
      ok = $result.ok
      status_code = $result.status_code
      error = $result.error
    }
  }

  foreach ($stop in $routeStopManifests) {
    $eventSeq++
    $stopObjects = @($manifestObjects | Where-Object { [string]$_.route_stop_id -eq [string]$stop.route_stop_id } | Sort-Object manifest_seq)
    $eventKey = "$manifestId-objects-$($stop.route_stop_id)"
    $eventId = [guid]::NewGuid().ToString()
    $event = [ordered]@{
      event_id = $eventId
      event_type = "valheim.priority_manifest.objects"
      occurred_at = (Get-Date).ToUniversalTime().ToString("o")
      world_id = $worldId
      region_id = [string]$stop.route_stop_id
      actor_id = $actorId
      guild_id = $null
      source_service = "ComfyNetworkSense.FieldLab"
      schema_version = 1
      payload = [ordered]@{
        manifest_id = $manifestId
        event_key = $eventKey
        event_seq = $eventSeq
        route_stop = $stop
        records = $stopObjects
      }
    }

    $result = Invoke-EventLogPost -EventLogUrl $eventLogUrl -Event $event
    if ($result.ok) { $postedOk++ } else { $postedFailed++ }
    $postResults += [pscustomobject]@{
      event_id = $eventId
      event_key = $eventKey
      event_type = "valheim.priority_manifest.objects"
      event_seq = $eventSeq
      manifest_seq = $stop.first_manifest_seq
      route_stop_id = $stop.route_stop_id
      priority_tier = "batch"
      ok = $result.ok
      status_code = $result.status_code
      error = $result.error
    }
  }

  $eventSeq++
  $completeEventKey = "$manifestId-complete"
  $completeEventId = [guid]::NewGuid().ToString()
  $completeEvent = [ordered]@{
    event_id = $completeEventId
    event_type = "valheim.priority_manifest.complete"
    occurred_at = (Get-Date).ToUniversalTime().ToString("o")
    world_id = $worldId
    region_id = "era16-route"
    actor_id = $actorId
    guild_id = $null
    source_service = "ComfyNetworkSense.FieldLab"
    schema_version = 1
    payload = [ordered]@{
      manifest_id = $manifestId
      event_key = $completeEventKey
      event_seq = $eventSeq
      source_priority_status = $summaryStatusFromPriority
      sample_rows = $manifestSamples.Count
      object_rows = $manifestObjects.Count
      expected_event_count = $manifest.counts.expected_event_count
      sparse_fixture_note = $manifest.source.sparse_fixture_note
      route_stops = $manifest.route_stops
    }
  }

  $result = Invoke-EventLogPost -EventLogUrl $eventLogUrl -Event $completeEvent
  if ($result.ok) { $postedOk++ } else { $postedFailed++ }
  $postResults += [pscustomobject]@{
    event_id = $completeEventId
    event_key = $completeEventKey
    event_type = "valheim.priority_manifest.complete"
    event_seq = $eventSeq
    manifest_seq = $eventSeq
    route_stop_id = "era16-route"
    priority_tier = ""
    ok = $result.ok
    status_code = $result.status_code
    error = $result.error
  }
}

if ($postResults.Count -gt 0) {
  $postResults | Export-Csv -NoTypeInformation -Encoding UTF8 $eventsCsvPath
}

$objectQuery = Invoke-EventLogQuery -EventLogUrl $eventLogUrl -EventType "valheim.priority_manifest.objects" -Limit ([Math]::Max(200, $routeStopManifests.Count + 50))
$sampleQuery = Invoke-EventLogQuery -EventLogUrl $eventLogUrl -EventType "valheim.priority_manifest.sample" -Limit ([Math]::Max(200, $manifestSamples.Count + 50))
$completeQuery = Invoke-EventLogQuery -EventLogUrl $eventLogUrl -EventType "valheim.priority_manifest.complete" -Limit 50

$queriedObjectEvents = @($objectQuery.events | Where-Object { (Get-PayloadValue -Event $_ -Name "manifest_id") -eq $manifestId })
$queriedSampleEvents = @($sampleQuery.events | Where-Object { (Get-PayloadValue -Event $_ -Name "manifest_id") -eq $manifestId })
$queriedCompleteEvents = @($completeQuery.events | Where-Object { (Get-PayloadValue -Event $_ -Name "manifest_id") -eq $manifestId })

$expectedObjectSeqs = @($manifestObjects | ForEach-Object { [int]$_.manifest_seq } | Sort-Object)
$queriedObjectSeqs = @($queriedObjectEvents | ForEach-Object {
    $records = Get-PayloadValue -Event $_ -Name "records"
    foreach ($record in @($records)) {
      if ($record -and $null -ne $record.manifest_seq) {
        [int]$record.manifest_seq
      }
    }
  } | Sort-Object)

$missingObjectSeqs = @($expectedObjectSeqs | Where-Object { $queriedObjectSeqs -notcontains $_ })
$extraObjectSeqs = @($queriedObjectSeqs | Where-Object { $expectedObjectSeqs -notcontains $_ })
$objectSequenceSetPreserved = $missingObjectSeqs.Count -eq 0 -and $extraObjectSeqs.Count -eq 0 -and $expectedObjectSeqs.Count -eq $queriedObjectSeqs.Count

$postedAll = $postedFailed -eq 0 -and $postedOk -eq $manifest.counts.expected_event_count
$sampleRoundtrip = $queriedSampleEvents.Count -eq $manifestSamples.Count
$objectRoundtrip = $queriedObjectEvents.Count -eq $routeStopManifests.Count -and $objectSequenceSetPreserved
$completeRoundtrip = $queriedCompleteEvents.Count -ge 1
$roundtripOk = $sampleRoundtrip -and $objectRoundtrip -and $completeRoundtrip
$boundedManifest = $manifestObjects.Count -le ([Math]::Max(1, $manifest.route_stops.Count) * 192) -and $manifestObjects.Count -gt 0

$gates = @(
  New-Gate -Id "priority_manifest_available" -Status ($(if ($prioritySummary -and $priorityRouteCompleted -and $manifestObjects.Count -gt 0) { "pass" } else { "fail" })) -Observed "summary=$prioritySummaryPath, status=$summaryStatusFromPriority, route_completed=$priorityRouteCompleted, mirrored_objects=$($manifestObjects.Count)."
  New-Gate -Id "eventlog_health" -Status ($(if ($health.ok) { "pass" } else { "fail" })) -Observed "$eventLogUrl/health ok=$($health.ok), status=$($health.status_code), error=$($health.error)."
  New-Gate -Id "eventlog_database" -Status ($(if ($postgresProbe.ok) { "pass" } else { "fail" })) -Observed "$($postgresProbe.host):$($postgresProbe.port) ok=$($postgresProbe.ok), error=$($postgresProbe.error)."
  New-Gate -Id "manifest_bounded" -Status ($(if ($boundedManifest) { "pass" } else { "fail" })) -Observed "mirrored_object_rows=$($manifestObjects.Count), source_object_rows=$($objectRows.Count), route_stops=$($manifest.route_stops.Count), policy=latest sample per route stop."
  New-Gate -Id "post_complete" -Status ($(if ($postedAll) { "pass" } else { "fail" })) -Observed "posted_ok=$postedOk, posted_failed=$postedFailed, expected=$($manifest.counts.expected_event_count)."
  New-Gate -Id "query_roundtrip" -Status ($(if ($roundtripOk) { "pass" } else { "fail" })) -Observed "sample=$($queriedSampleEvents.Count)/$($manifestSamples.Count), object_batches=$($queriedObjectEvents.Count)/$($routeStopManifests.Count), object_records=$($queriedObjectSeqs.Count)/$($manifestObjects.Count), complete=$($queriedCompleteEvents.Count)."
  New-Gate -Id "order_preserved" -Status ($(if ($objectSequenceSetPreserved) { "pass" } else { "fail" })) -Observed "object sequence set preserved=$objectSequenceSetPreserved, missing=$($missingObjectSeqs.Count), extra=$($extraObjectSeqs.Count)."
  New-Gate -Id "sparse_fixture_note" -Status ($(if ($manifest.source.sparse_fixture_note) { "warn" } else { "pass" })) -Observed "sparse_fixture_note=$($manifest.source.sparse_fixture_note), inherited priority status=$summaryStatusFromPriority."
)

$summaryStatus = if (-not $prioritySummary -or -not $priorityRouteCompleted -or $manifestObjects.Count -eq 0) {
  "blocked_priority_manifest_missing"
} elseif (-not $health.ok) {
  "blocked_eventlog_unavailable"
} elseif (-not $postgresProbe.ok) {
  "blocked_eventlog_database_unavailable"
} elseif (-not $postedAll) {
  "fail_priority_mirror_post"
} elseif (-not $roundtripOk) {
  "fail_priority_mirror_roundtrip"
} elseif (-not $objectSequenceSetPreserved) {
  "fail_priority_mirror_order"
} elseif ($manifest.source.sparse_fixture_note) {
  "pass_priority_mirror_with_sparse_fixture_note"
} else {
  "pass_priority_mirror"
}

$phaseName = if ($summaryStatus -eq "pass_priority_mirror" -or $summaryStatus -eq "pass_priority_mirror_with_sparse_fixture_note") {
  "ready_for_live_mirror_or_dual_channel_load"
} elseif ($summaryStatus -like "blocked*") {
  "fix_input_or_runtime"
} else {
  "debug_eventlog_delivery"
}

$nextMarker = if ($summaryStatus -eq "pass_priority_mirror" -or $summaryStatus -eq "pass_priority_mirror_with_sparse_fixture_note") {
  "network_sense_mcp_mark lumberjacks_priority_mirror_ready"
} else {
  "network_sense_mcp_mark lumberjacks_priority_mirror_blocked"
}

$summary = [ordered]@{
  schema_version = 1
  status = $summaryStatus
  phase = $phaseName
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  eventlog_url = $eventLogUrl
  postgres = $postgresProbe
  manifest_id = $manifestId
  priority_summary_path = $prioritySummaryPath
  priority_status = $summaryStatusFromPriority
  priority_route_completed = $priorityRouteCompleted
  manifest_policy = $manifest.policy
  manifest_counts = $manifest.counts
  health = $health
  posts = [ordered]@{
    posted_ok = $postedOk
    posted_failed = $postedFailed
    expected_event_count = $manifest.counts.expected_event_count
    csv = "telemetry/priority-mirror-events.csv"
  }
  query = [ordered]@{
    sample_events = $queriedSampleEvents.Count
    object_batch_events = $queriedObjectEvents.Count
    object_events = $queriedObjectSeqs.Count
    complete_events = $queriedCompleteEvents.Count
    object_sequence_set_preserved = $objectSequenceSetPreserved
    missing_object_sequences = $missingObjectSeqs
    extra_object_sequences = $extraObjectSeqs
  }
  route_stops = $manifest.route_stops
  gates = $gates
  mcp_phase = [ordered]@{
    current_phase = $phaseName
    next_marker_command = $nextMarker
    handoff_signal = "Run this marker after reviewing the mirror packet; agents should choose live in-mod mirror or dual-channel load next."
  }
  claims_not_proven = @(
    "Live in-game streaming to Lumberjacks",
    "Gateway dual-channel delivery of Valheim object manifests",
    "Client-side load-order enforcement",
    "Vanilla ZDO transport replacement"
  )
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Lumberjacks Priority Mirror",
  "",
  "## Current Status",
  "",
  "- Summary status: $summaryStatus",
  "- Phase: $phaseName",
  "- Manifest id: $manifestId",
  "- EventLog: $eventLogUrl",
  "- Postgres: $($postgresProbe.host):$($postgresProbe.port), ok=$($postgresProbe.ok)",
  "- Priority source: $prioritySummaryPath",
  "- Mirrored samples: $($manifestSamples.Count)",
  "- Mirrored objects: $($manifestObjects.Count)",
  "- Posted events: $postedOk/$($manifest.counts.expected_event_count)",
  "- Queried object batches: $($queriedObjectEvents.Count)/$($routeStopManifests.Count)",
  "- Queried object records: $($queriedObjectSeqs.Count)/$($manifestObjects.Count)",
  "- Object order preserved: $objectSequenceSetPreserved",
  "",
  "## What This Proves",
  "",
  "The latest Valheim priority manifest can be carried by Lumberjacks EventLog as ordered side-channel metadata and read back with sequence integrity. This is a runtime delivery proof for the manifest, not yet a live Gateway dual-channel stream.",
  "",
  "## Next Marker",
  "",
  '```text',
  $nextMarker,
  '```',
  "",
  "## Next Build",
  "",
  "If this packet passes, build the live mirror path: either a BepInEx command that posts sample/object events as they are scanned, or a Gateway message type that promotes these events into the dual-channel broadcast path. If it is blocked on the database, restart the Lumberjacks Postgres service and rerun this scenario."
) | Set-Content -Encoding UTF8 $operatorRunbookPath

@(
  "# Command Plan Summary",
  "",
  "- Status: $summaryStatus",
  "- Phase: $phaseName",
  "- Manifest id: $manifestId",
  "- EventLog: $eventLogUrl",
  "- Postgres: $($postgresProbe.host):$($postgresProbe.port), ok=$($postgresProbe.ok)",
  "- Mirrored samples: $($manifestSamples.Count)",
  "- Mirrored objects: $($manifestObjects.Count)",
  "- Posted ok: $postedOk",
  "- Posted failed: $postedFailed",
  "- Object batches roundtrip: $($queriedObjectEvents.Count)/$($routeStopManifests.Count)",
  "- Object records roundtrip: $($queriedObjectSeqs.Count)/$($manifestObjects.Count)",
  "- Sequence preserved: $objectSequenceSetPreserved",
  "- Next MCP marker: ``$nextMarker``",
  "- Summary: telemetry/priority-mirror-summary.json",
  "- Manifest: telemetry/priority-mirror-manifest.json",
  "- Events CSV: telemetry/priority-mirror-events.csv"
) | Set-Content -Encoding UTF8 $commandSummaryPath
