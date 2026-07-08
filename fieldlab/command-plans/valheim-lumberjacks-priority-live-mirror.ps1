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

$summaryPath = Join-Path $telemetryDir "priority-live-mirror-summary.json"
$operatorRunbookPath = Join-Path $rawDir "operator-runbook.md"

function Write-JsonFile {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value,

    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $Value | ConvertTo-Json -Depth 24 | Set-Content -Encoding UTF8 $Path
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

  [ordered]@{
    id = $Id
    status = $Status
    observed = $Observed
  }
}

function Resolve-NetworkSenseLogDir {
  if ($env:FIELDLAB_NETWORKSENSE_LOG_DIR -and (Test-Path $env:FIELDLAB_NETWORKSENSE_LOG_DIR -PathType Container)) {
    return (Resolve-Path $env:FIELDLAB_NETWORKSENSE_LOG_DIR).Path
  }

  $default = "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense"
  if (Test-Path $default -PathType Container) {
    return (Resolve-Path $default).Path
  }

  return $default
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

function Get-Payload {
  param([object]$Event)

  if (-not $Event -or -not $Event.payload) {
    return $null
  }

  if ($Event.payload -is [string]) {
    return $Event.payload | ConvertFrom-Json
  }

  return $Event.payload
}

function Query-ManifestEvents {
  param(
    [string]$EventLogUrl,
    [string]$EventType,
    [string]$ManifestId,
    [int]$Limit = 500
  )

  $encodedType = [uri]::EscapeDataString($EventType)
  $response = Invoke-WebRequest -Uri "$EventLogUrl/events?type=$encodedType&limit=$Limit" -UseBasicParsing -TimeoutSec 20
  $parsed = $response.Content | ConvertFrom-Json
  return @($parsed.events | Where-Object { (Get-Payload $_).manifest_id -eq $ManifestId })
}

$eventLogUrl = if ($env:FIELDLAB_LUMBERJACKS_EVENTLOG_URL) {
  $env:FIELDLAB_LUMBERJACKS_EVENTLOG_URL.TrimEnd("/")
} else {
  "http://localhost:4002"
}

$logDir = Resolve-NetworkSenseLogDir
$priorityMirrorPath = Join-Path $logDir "priority-mirror.jsonl"
$priorityLoadPath = Join-Path $logDir "priority-load.jsonl"
$eventTimelinePath = Join-Path $logDir "event-timeline.jsonl"

$mirrorRows = @(Read-JsonLines $priorityMirrorPath)
$latestStop = @($mirrorRows | Where-Object { [string]$_.event -eq "stop" } | Sort-Object timestamp_utc | Select-Object -Last 1)
$latestStop = if ($latestStop.Count -gt 0) { $latestStop[0] } else { $null }
$manifestId = if ($latestStop) { [string]$latestStop.manifest_id } else { $null }
$sessionId = if ($latestStop) { [string]$latestStop.session_id } else { $null }

$priorityRows = @(Read-JsonLines $priorityLoadPath | Where-Object {
    $_.session_id -eq $sessionId -and $_.run_label -eq "priority_route"
  })
$localSamples = @($priorityRows | Where-Object { [string]$_.event -eq "sample" })
$localObjects = @($priorityRows | Where-Object { [string]$_.event -eq "object" })

$timelineRows = @(Read-JsonLines $eventTimelinePath | Where-Object { $_.session_id -eq $sessionId })
$routeCompleted = @($timelineRows | Where-Object {
    [string]$_.event_name -eq "dev_marker" -and [string]$_.message -eq "lumberjacks_priority_route end"
  }).Count -gt 0

$sampleEvents = @()
$objectEvents = @()
$completeEvents = @()
$objectRecordCount = 0
$queryError = $null

if ($manifestId) {
  try {
    $sampleEvents = @(Query-ManifestEvents $eventLogUrl "valheim.priority_manifest.sample" $manifestId)
    $objectEvents = @(Query-ManifestEvents $eventLogUrl "valheim.priority_manifest.objects" $manifestId)
    $completeEvents = @(Query-ManifestEvents $eventLogUrl "valheim.priority_manifest.complete" $manifestId)
    foreach ($event in $objectEvents) {
      $payload = Get-Payload $event
      $objectRecordCount += @($payload.records).Count
    }
  } catch {
    $queryError = $_.Exception.Message
  }
}

$mirrorHealthy =
  $latestStop -and
  [int]$latestStop.posted_failed -eq 0 -and
  [int]$latestStop.sample_events -eq $localSamples.Count -and
  [int]$latestStop.object_records -eq $localObjects.Count
$eventlogRoundtrip =
  $queryError -eq $null -and
  $sampleEvents.Count -eq $localSamples.Count -and
  $objectRecordCount -eq $localObjects.Count -and
  $completeEvents.Count -ge 1
$localRemoteMatch =
  $sampleEvents.Count -eq $localSamples.Count -and
  $objectRecordCount -eq $localObjects.Count

$gates = @(
  New-Gate -Id "live_mirror_status" -Status ($(if ($mirrorHealthy) { "pass" } else { "fail" })) -Observed "manifest=$manifestId, session=$sessionId, local_samples=$($localSamples.Count), mirror_samples=$($latestStop.sample_events), local_objects=$($localObjects.Count), mirror_objects=$($latestStop.object_records), posted_failed=$($latestStop.posted_failed)."
  New-Gate -Id "eventlog_roundtrip" -Status ($(if ($eventlogRoundtrip) { "pass" } else { "fail" })) -Observed "sample_events=$($sampleEvents.Count), object_batch_events=$($objectEvents.Count), object_records=$objectRecordCount, complete_events=$($completeEvents.Count), query_error=$queryError."
  New-Gate -Id "local_remote_counts_match" -Status ($(if ($localRemoteMatch) { "pass" } else { "fail" })) -Observed "local_samples=$($localSamples.Count), eventlog_samples=$($sampleEvents.Count), local_objects=$($localObjects.Count), eventlog_object_records=$objectRecordCount."
  New-Gate -Id "route_completion" -Status ($(if ($routeCompleted) { "pass" } else { "fail" })) -Observed "route completion marker observed for session ${sessionId}: $routeCompleted."
)

$status = if ($mirrorHealthy -and $eventlogRoundtrip -and $localRemoteMatch -and $routeCompleted) {
  "pass_priority_live_mirror"
} elseif ($latestStop) {
  "fail_priority_live_mirror"
} else {
  "blocked_no_live_mirror_stop"
}

$phase = if ($status -eq "pass_priority_live_mirror") {
  "ready_for_gateway_priority_delivery"
} else {
  "debug_live_mirror"
}

$summary = [ordered]@{
  schema_version = 1
  status = $status
  phase = $phase
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  network_sense_log_dir = $logDir
  eventlog_url = $eventLogUrl
  manifest_id = $manifestId
  session_id = $sessionId
  local = [ordered]@{
    sample_rows = $localSamples.Count
    object_rows = $localObjects.Count
  }
  mirror = [ordered]@{
    sample_events = if ($latestStop) { [int]$latestStop.sample_events } else { 0 }
    object_batch_events = if ($latestStop) { [int]$latestStop.object_batch_events } else { 0 }
    object_records = if ($latestStop) { [int]$latestStop.object_records } else { 0 }
    posted_ok = if ($latestStop) { [int]$latestStop.posted_ok } else { 0 }
    posted_failed = if ($latestStop) { [int]$latestStop.posted_failed } else { 0 }
    queued_posts_at_stop = if ($latestStop) { [int]$latestStop.queued_posts } else { 0 }
  }
  eventlog = [ordered]@{
    sample_events = $sampleEvents.Count
    object_batch_events = $objectEvents.Count
    object_records = $objectRecordCount
    complete_events = $completeEvents.Count
    query_error = $queryError
  }
  route_completed = $routeCompleted
  gates = $gates
  next_marker_command = if ($status -eq "pass_priority_live_mirror") {
    "network_sense_mcp_mark lumberjacks_priority_live_mirror_ready"
  } else {
    "network_sense_mcp_mark lumberjacks_priority_live_mirror_blocked"
  }
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Lumberjacks Priority Live Mirror",
  "",
  "- Status: $status",
  "- Phase: $phase",
  "- Manifest: $manifestId",
  "- Session: $sessionId",
  "- Local samples/objects: $($localSamples.Count)/$($localObjects.Count)",
  "- EventLog samples/object batches/object records/completions: $($sampleEvents.Count)/$($objectEvents.Count)/$objectRecordCount/$($completeEvents.Count)",
  "- Next marker: ``$($summary.next_marker_command)``",
  "",
  "## Next",
  "",
  "A pass means the side-channel manifest is live from BepInEx to Lumberjacks EventLog. The next build should promote priority manifest events into Gateway delivery/load-shaping semantics."
) | Set-Content -Encoding UTF8 $operatorRunbookPath
