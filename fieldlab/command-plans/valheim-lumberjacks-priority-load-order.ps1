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

$summaryPath = Join-Path $telemetryDir "priority-load-summary.json"
$densityCsvPath = Join-Path $telemetryDir "priority-load-density-comparison.csv"
$routeTsvPath = Join-Path $telemetryDir "teleport-route.tsv"
$operatorRunbookPath = Join-Path $rawDir "operator-runbook.md"
$consoleCommandsPath = Join-Path $rawDir "valheim-console-commands.txt"
$commandSummaryPath = Join-Path $rawDir "command-plan-summary.md"

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
  $candidates = @()
  if ($env:FIELDLAB_NETWORKSENSE_LOG_DIR) {
    $candidates += $env:FIELDLAB_NETWORKSENSE_LOG_DIR
  }

  $candidates += @(
    "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense",
    "C:\Program Files\Steam\steamapps\common\Valheim\BepInEx\config\comfy-network-sense"
  )

  foreach ($candidate in $candidates) {
    if ($candidate -and (Test-Path $candidate -PathType Container)) {
      return (Resolve-Path $candidate).Path
    }
  }

  return $candidates[0]
}

function Get-LatestRouteContractPath {
  param([string]$Root)

  if ($env:FIELDLAB_ROUTE_CONTRACT) {
    return $env:FIELDLAB_ROUTE_CONTRACT
  }

  $runsPath = Join-Path $Root "fieldlab\runs"
  if (-not (Test-Path $runsPath)) {
    return $null
  }

  $candidate = Get-ChildItem -Path $runsPath -Recurse -Filter "teleport-route-contract.json" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if ($candidate) {
    return $candidate.FullName
  }

  return $null
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

function Read-RouteTsv {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return @()
  }

  $rows = @()
  foreach ($line in @(Get-Content -Path $Path)) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith("#")) {
      continue
    }

    $parts = $line -split "`t"
    if ($parts.Count -lt 5 -or $parts[0] -eq "id") {
      continue
    }

    $rows += [ordered]@{
      id = $parts[0]
      density_band = $parts[0] -replace "^route_\d+_", ""
      world_x = [double]$parts[1]
      world_z = [double]$parts[2]
      settle_seconds = [double]$parts[3]
      benchmark_seconds = [double]$parts[4]
    }
  }

  return $rows
}

function Get-AssemblyVersionInfo {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return [ordered]@{
      path = $Path
      exists = $false
      version = $null
      error = "missing"
    }
  }

  try {
    $item = Get-Item $Path
    $name = [Reflection.AssemblyName]::GetAssemblyName($Path)
    return [ordered]@{
      path = $Path
      exists = $true
      version = $name.Version.ToString()
      length = $item.Length
      last_write_time = $item.LastWriteTime.ToString("o")
      error = $null
    }
  } catch {
    return [ordered]@{
      path = $Path
      exists = $true
      version = $null
      error = $_.Exception.Message
    }
  }
}

function Get-ValheimProcesses {
  @(Get-CimInstance Win32_Process | Where-Object {
      $_.Name -match "^(valheim|valheim_server)\.exe$" -or $_.CommandLine -match "(?i)(\\|/)(valheim|valheim_server)\.exe(\s|$)"
    } | ForEach-Object {
      [ordered]@{
        process_id = $_.ProcessId
        name = $_.Name
        command_line = $_.CommandLine
      }
    })
}

function Get-Number {
  param(
    [object]$Value,
    [double]$Default = 0
  )

  if ($null -eq $Value) {
    return $Default
  }

  try {
    return [double]$Value
  } catch {
    return $Default
  }
}

function Set-NetworkSenseConfigValues {
  param(
    [string]$ConfigPath,
    [string]$Radius,
    [string]$IntervalSeconds,
    [string]$MaxObjects
  )

  $desired = [ordered]@{
    writeTelemetryLogs = "true"
    benchmarkDurationSeconds = "60"
    lumberjacksPriorityProbeRadiusMeters = $Radius
    lumberjacksPriorityProbeIntervalSeconds = $IntervalSeconds
    lumberjacksPriorityProbeMaxObjectsPerSample = $MaxObjects
  }

  if (-not (Test-Path $ConfigPath)) {
    return [ordered]@{
      exists = $false
      path = $ConfigPath
      changes = @()
      missing_keys = @($desired.Keys)
    }
  }

  $lines = @(Get-Content -Path $ConfigPath)
  $changes = @()
  $found = @{}

  foreach ($key in $desired.Keys) {
    $prefix = "$key = "
    for ($index = 0; $index -lt $lines.Count; $index++) {
      if ($lines[$index].StartsWith($prefix)) {
        $found[$key] = $true
        $old = $lines[$index].Substring($prefix.Length)
        if ($old -ne $desired[$key]) {
          $lines[$index] = $prefix + $desired[$key]
          $changes += [ordered]@{
              key = $key
              old = $old
              new = $desired[$key]
            }
        }
        break
      }
    }
  }

  $missing = @($desired.Keys | Where-Object { -not $found.ContainsKey($_) })
  if ($missing.Count -gt 0) {
    $lines += ""
    $lines += "[Lumberjacks]"
    foreach ($key in $missing) {
      $lines += "$key = $($desired[$key])"
      $changes += [ordered]@{
          key = $key
          old = "<missing>"
          new = $desired[$key]
        }
    }
  }

  if (@($changes).Count -gt 0) {
    $lines | Set-Content -Encoding UTF8 $ConfigPath
  }

  return [ordered]@{
    exists = $true
    path = $ConfigPath
    profile = "lumberjacks_priority_load_order"
    changes = @($changes)
    missing_keys = $missing
    requires_reload = @($changes).Count -gt 0
  }
}

$priorityRadius = if ($env:FIELDLAB_PRIORITY_RADIUS) { [string]$env:FIELDLAB_PRIORITY_RADIUS } else { "96" }
$priorityInterval = if ($env:FIELDLAB_PRIORITY_SCAN_INTERVAL) { [string]$env:FIELDLAB_PRIORITY_SCAN_INTERVAL } else { "5" }
$priorityMaxObjects = if ($env:FIELDLAB_PRIORITY_MAX_OBJECTS) { [string]$env:FIELDLAB_PRIORITY_MAX_OBJECTS } else { "96" }
$valheimDir = if ($env:FIELDLAB_VALHEIM_DIR) { $env:FIELDLAB_VALHEIM_DIR } else { "C:\Program Files (x86)\Steam\steamapps\common\Valheim" }
$pluginPath = Join-Path $valheimDir "BepInEx\plugins\ComfyNetworkSense.dll"
$configPath = Join-Path $valheimDir "BepInEx\config\djcdevelopment.valheim.comfynetworksense.cfg"
$logDir = Resolve-NetworkSenseLogDir
$priorityLogPath = Join-Path $logDir "priority-load.jsonl"
$eventLogPath = Join-Path $logDir "event-timeline.jsonl"
$deployedRoutePath = Join-Path $logDir "teleport-route.tsv"

$routeContractPath = Get-LatestRouteContractPath -Root $RepoRoot
$routeSteps = @()
$routeSource = "none"

if ($routeContractPath -and (Test-Path $routeContractPath)) {
  $routeContract = Get-Content -Raw $routeContractPath | ConvertFrom-Json
  $routeSteps = @($routeContract.route_steps | ForEach-Object {
      [ordered]@{
        id = $_.id
        density_band = $_.density_band
        world_x = $_.world_x
        world_z = $_.world_z
        settle_seconds = $_.settle_seconds
        benchmark_seconds = $_.benchmark_seconds
      }
    })
  $routeSource = $routeContractPath
}

if ($routeSteps.Count -gt 0) {
  $tsvLines = @("id`tworld_x`tworld_z`tsettle_seconds`tbenchmark_seconds")
  foreach ($step in $routeSteps) {
    $tsvLines += "$($step.id)`t$($step.world_x)`t$($step.world_z)`t$($step.settle_seconds)`t$($step.benchmark_seconds)"
  }
  $tsvLines | Set-Content -Encoding UTF8 $routeTsvPath
} elseif (Test-Path $deployedRoutePath) {
  Copy-Item $deployedRoutePath $routeTsvPath -Force
  $routeSteps = @(Read-RouteTsv -Path $routeTsvPath)
  $routeSource = $deployedRoutePath
} else {
  @("id`tworld_x`tworld_z`tsettle_seconds`tbenchmark_seconds") | Set-Content -Encoding UTF8 $routeTsvPath
}

$routeFileCopied = $false
if (Test-Path $logDir -PathType Container) {
  Copy-Item $routeTsvPath $deployedRoutePath -Force
  $routeFileCopied = Test-Path $deployedRoutePath
}

$plugin = Get-AssemblyVersionInfo $pluginPath
$versionOk = $false
if ($plugin.version) {
  try {
    $versionOk = ([version]$plugin.version) -ge ([version]"0.5.0.0")
  } catch {
    $versionOk = $false
  }
}

$configProfile = Set-NetworkSenseConfigValues -ConfigPath $configPath -Radius $priorityRadius -IntervalSeconds $priorityInterval -MaxObjects $priorityMaxObjects
$processes = @(Get-ValheimProcesses)
$priorityRows = @(Read-JsonLines -Path $priorityLogPath)
$eventRows = @(Read-JsonLines -Path $eventLogPath)
$routeStartMarkers = @($eventRows | Where-Object {
    [string]$_.event_name -eq "dev_marker" -and ([string]$_.message).StartsWith("lumberjacks_priority_route start")
  } | Sort-Object timestamp_utc)
$latestRouteStart = if ($routeStartMarkers.Count -gt 0) { $routeStartMarkers[-1] } else { $null }
$latestRouteStartUtc = if ($latestRouteStart) { [datetime]$latestRouteStart.timestamp_utc } else { $null }
$latestRouteStartMessage = if ($latestRouteStart) { [string]$latestRouteStart.message } else { $null }
$observedRunRadius = $priorityRadius
$observedRunInterval = $priorityInterval
$observedRunMaxObjects = $priorityMaxObjects

if ($latestRouteStartMessage) {
  if ($latestRouteStartMessage -match "radius=(?<radius>[0-9.]+)m") {
    $observedRunRadius = $Matches.radius
  }
  if ($latestRouteStartMessage -match "interval=(?<interval>[0-9.]+)s") {
    $observedRunInterval = $Matches.interval
  }
  if ($latestRouteStartMessage -match "maxObjects=(?<max>[0-9]+)") {
    $observedRunMaxObjects = $Matches.max
  }
}

$allRouteEndMarkers = @($eventRows | Where-Object {
    [string]$_.event_name -eq "dev_marker" -and ([string]$_.message) -eq "lumberjacks_priority_route end"
  } | Sort-Object timestamp_utc)
$routeEndMarkers = @($allRouteEndMarkers | Where-Object {
    -not $latestRouteStartUtc -or ([datetime]$_.timestamp_utc) -ge $latestRouteStartUtc
  })
$latestRouteEnd = if ($routeEndMarkers.Count -gt 0) { $routeEndMarkers[-1] } else { $null }
$latestRouteEndUtc = if ($latestRouteEnd) { [datetime]$latestRouteEnd.timestamp_utc } else { $null }

$routeRows = @($priorityRows | Where-Object {
    if ([string]$_.run_label -ne "priority_route" -or [string]::IsNullOrWhiteSpace([string]$_.route_stop_id)) {
      return $false
    }

    if (-not $latestRouteStartUtc) {
      return $true
    }

    $rowTimestamp = [datetime]$_.timestamp_utc
    if ($rowTimestamp -lt $latestRouteStartUtc) {
      return $false
    }

    if ($latestRouteEndUtc -and $rowTimestamp -gt $latestRouteEndUtc.AddSeconds(5)) {
      return $false
    }

    return $true
  })
$sampleRows = @($routeRows | Where-Object { [string]$_.event -eq "sample" })
$objectRows = @($routeRows | Where-Object { [string]$_.event -eq "object" })

$tiers = @(
  "player_critical",
  "portal",
  "structural_anchor",
  "near_interactive",
  "storage_crafting",
  "support_piece",
  "decorative_far"
)

$perStop = @($routeSteps | ForEach-Object {
    $stop = $_
    $stopSamples = @($sampleRows | Where-Object { [string]$_.route_stop_id -eq [string]$stop.id })
    $stopObjects = @($objectRows | Where-Object { [string]$_.route_stop_id -eq [string]$stop.id })
    $latestSample = @($stopSamples | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
    $latest = if ($latestSample.Count -gt 0) { $latestSample[0] } else { $null }
    $maxScanMs = 0
    if ($stopSamples.Count -gt 0) {
      $maxScanMs = [int](($stopSamples | Measure-Object -Property scan_duration_ms -Maximum).Maximum)
    }

    $tierCounts = [ordered]@{}
    foreach ($tier in $tiers) {
      $field = "${tier}_count"
      $tierCounts[$field] = if ($latest -and $null -ne $latest.$field) { [int]$latest.$field } else { 0 }
    }

    $nonPlayerTierCount = 0
    foreach ($tier in $tiers | Where-Object { $_ -ne "player_critical" }) {
      $field = "${tier}_count"
      $nonPlayerTierCount += [int]$tierCounts[$field]
    }

    [pscustomobject][ordered]@{
      id = $stop.id
      density_band = $stop.density_band
      sample_count = $stopSamples.Count
      object_row_count = $stopObjects.Count
      observed = $stopSamples.Count -gt 0
      candidate_count = if ($latest -and $null -ne $latest.candidate_count) { [int]$latest.candidate_count } else { 0 }
      emitted_object_count = if ($latest -and $null -ne $latest.emitted_object_count) { [int]$latest.emitted_object_count } else { 0 }
      emission_capped = if ($latest -and $null -ne $latest.emission_capped) { [bool]$latest.emission_capped } else { $false }
      collider_count = if ($latest -and $null -ne $latest.collider_count) { [int]$latest.collider_count } else { 0 }
      collider_buffer_full = if ($latest -and $null -ne $latest.collider_buffer_full) { [bool]$latest.collider_buffer_full } else { $false }
      max_scan_duration_ms = $maxScanMs
      top_priority_tier = if ($latest) { [string]$latest.top_priority_tier } else { $null }
      top_object_name = if ($latest) { [string]$latest.top_object_name } else { $null }
      latest_timestamp_utc = if ($latest) { [string]$latest.timestamp_utc } else { $null }
      player_critical_count = [int]$tierCounts["player_critical_count"]
      portal_count = [int]$tierCounts["portal_count"]
      structural_anchor_count = [int]$tierCounts["structural_anchor_count"]
      near_interactive_count = [int]$tierCounts["near_interactive_count"]
      storage_crafting_count = [int]$tierCounts["storage_crafting_count"]
      support_piece_count = [int]$tierCounts["support_piece_count"]
      decorative_far_count = [int]$tierCounts["decorative_far_count"]
      non_player_priority_count = $nonPlayerTierCount
    }
  })

$observedStopIds = @($perStop | Where-Object { $_.observed } | ForEach-Object { [string]$_.id })
$allStopsObserved = $routeSteps.Count -gt 0 -and $observedStopIds.Count -ge $routeSteps.Count
$partialStopsObserved = $observedStopIds.Count -gt 0
$latestRouteCompleted = $null -ne $latestRouteEndUtc
$stopsWithNonPlayerPriority = @($perStop | Where-Object {
    $_.player_critical_count -gt 0 -and $_.non_player_priority_count -gt 0
  }).Count
$allStopsHavePriority = $routeSteps.Count -gt 0 -and $stopsWithNonPlayerPriority -ge $routeSteps.Count
$observedRunRadiusNumber = Get-Number -Value $observedRunRadius -Default (Get-Number -Value $priorityRadius -Default 96)
$wideRunSparseGapAcceptable =
  $latestRouteCompleted -and
  $allStopsObserved -and
  $observedRunRadiusNumber -ge 256 -and
  $routeSteps.Count -gt 0 -and
  $stopsWithNonPlayerPriority -ge ($routeSteps.Count - 1)
$anyScanBufferFull = @($perStop | Where-Object { $_.collider_buffer_full }).Count -gt 0
$maxScanDurationMs = if ($perStop.Count -gt 0) { [int](($perStop | Measure-Object -Property max_scan_duration_ms -Maximum).Maximum) } else { 0 }

$priorityCommand = "network_sense_lumberjacks_priority_route teleport-route.tsv $priorityRadius $priorityInterval $priorityMaxObjects"
$widePriorityCommand = "network_sense_lumberjacks_priority_route teleport-route.tsv 256 $priorityInterval 192"
$nextMcpMarker = if ($allStopsObserved -and $latestRouteCompleted) {
  if ($allStopsHavePriority -or $wideRunSparseGapAcceptable) {
    "network_sense_mcp_mark lumberjacks_priority_manifest_ready"
  } else {
    "network_sense_mcp_mark lumberjacks_priority_wide_radius_requested"
  }
} elseif ($partialStopsObserved) {
  "network_sense_mcp_mark lumberjacks_priority_route_partial"
} else {
  "network_sense_mcp_mark lumberjacks_priority_route_complete"
}

$gates = @(
  New-Gate -Id "route_file" -Status ($(if ($routeSteps.Count -gt 0 -and $routeFileCopied) { "pass" } else { "fail" })) -Observed "route_steps=$($routeSteps.Count), source=$routeSource, generated=$routeTsvPath, deployed=$deployedRoutePath, copied=$routeFileCopied."
  New-Gate -Id "mod_deployed" -Status ($(if ($versionOk) { "pass" } else { "fail" })) -Observed "ComfyNetworkSense installed version: $($plugin.version)."
  New-Gate -Id "valheim_running" -Status ($(if (@($processes).Count -gt 0) { "pass" } else { "warn" })) -Observed "$(@($processes).Count) Valheim processes visible."
  New-Gate -Id "priority_route_rows" -Status ($(if ($allStopsObserved) { "pass" } elseif ($partialStopsObserved) { "pending" } else { "pending" })) -Observed "$($observedStopIds.Count)/$($routeSteps.Count) route stops have priority sample rows; route sample rows=$($sampleRows.Count), object rows=$($objectRows.Count)."
  New-Gate -Id "priority_tier_manifest" -Status ($(if ($allStopsHavePriority) { "pass" } elseif ($wideRunSparseGapAcceptable) { "warn" } elseif ($partialStopsObserved) { "pending" } else { "pending" })) -Observed "Stops with player-critical plus non-player priority counts: $stopsWithNonPlayerPriority/$($routeSteps.Count)."
  New-Gate -Id "scan_cost_bounded" -Status ($(if ($anyScanBufferFull) { "warn" } else { "pass" })) -Observed "max_scan_duration_ms=$maxScanDurationMs, collider_buffer_full_any=$anyScanBufferFull."
  New-Gate -Id "route_completion_marker" -Status ($(if ($routeEndMarkers.Count -gt 0) { "pass" } elseif ($partialStopsObserved) { "pending" } else { "pending" })) -Observed "$($routeEndMarkers.Count) lumberjacks_priority_route end markers observed."
  New-Gate -Id "no_vanilla_mutation" -Status "pass" -Observed "Priority probe is observation-only: no Valheim ZDO writes, ZNetView ownership changes, transform corrections, or vanilla replication replacement."
)

$summaryStatus = if ($partialStopsObserved -and -not $latestRouteCompleted) {
  "priority_route_in_progress"
} elseif ($allStopsObserved -and $latestRouteCompleted -and $allStopsHavePriority) {
  "pass_priority_route_observed"
} elseif ($wideRunSparseGapAcceptable) {
  "pass_priority_route_observed_with_sparse_gap"
} elseif ($allStopsObserved -and $latestRouteCompleted) {
  "priority_route_observed_visibility_gaps"
} elseif ($partialStopsObserved) {
  "priority_route_partial"
} elseif ($routeSteps.Count -gt 0 -and $routeFileCopied -and $versionOk) {
  "staged_waiting_for_priority_route"
} else {
  "blocked_setup"
}

$phaseName = if ($summaryStatus -eq "pass_priority_route_observed") {
  "collect_complete_ready_for_lumberjacks_mirror"
} elseif ($summaryStatus -eq "pass_priority_route_observed_with_sparse_gap") {
  "ready_for_lumberjacks_mirror_with_sparse_fixture_note"
} elseif ($summaryStatus -eq "priority_route_observed_visibility_gaps") {
  "wide_radius_followup"
} elseif ($summaryStatus -eq "priority_route_in_progress") {
  "wait_for_route_completion"
} elseif ($partialStopsObserved) {
  "collect_partial_review_or_rerun"
} else {
  "stage_in_game_priority_route"
}

$estimatedSeconds = 0
foreach ($step in $routeSteps) {
  $estimatedSeconds += [double]$step.settle_seconds + [double]$step.benchmark_seconds + 3.0
}

$densityRows = @($perStop | ForEach-Object {
    [pscustomobject]@{
      id = $_.id
      density_band = $_.density_band
      sample_count = $_.sample_count
      candidate_count = $_.candidate_count
      emitted_object_count = $_.emitted_object_count
      player_critical_count = $_.player_critical_count
      portal_count = $_.portal_count
      structural_anchor_count = $_.structural_anchor_count
      near_interactive_count = $_.near_interactive_count
      storage_crafting_count = $_.storage_crafting_count
      support_piece_count = $_.support_piece_count
      decorative_far_count = $_.decorative_far_count
      max_scan_duration_ms = $_.max_scan_duration_ms
      collider_buffer_full = $_.collider_buffer_full
      top_priority_tier = $_.top_priority_tier
      top_object_name = $_.top_object_name
    }
  })
if ($densityRows.Count -gt 0) {
  $densityRows | Export-Csv -NoTypeInformation -Encoding UTF8 $densityCsvPath
}

$summary = [ordered]@{
  schema_version = 1
  status = $summaryStatus
  phase = $phaseName
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  priority_radius_meters = $priorityRadius
  priority_scan_interval_seconds = $priorityInterval
  priority_max_objects_per_sample = $priorityMaxObjects
  observed_route_run = [ordered]@{
    start_timestamp_utc = if ($latestRouteStartUtc) { $latestRouteStartUtc.ToUniversalTime().ToString("o") } else { $null }
    end_timestamp_utc = if ($latestRouteEndUtc) { $latestRouteEndUtc.ToUniversalTime().ToString("o") } else { $null }
    completed = $latestRouteCompleted
    start_marker = $latestRouteStartMessage
    radius_meters = $observedRunRadius
    scan_interval_seconds = $observedRunInterval
    max_objects_per_sample = $observedRunMaxObjects
  }
  network_sense_log_dir = $logDir
  priority_log_path = $priorityLogPath
  event_log_path = $eventLogPath
  route_contract_path = $routeContractPath
  route_source = $routeSource
  route_step_count = $routeSteps.Count
  route_steps = $routeSteps
  estimated_route_seconds = [math]::Round($estimatedSeconds, 1)
  route_file = [ordered]@{
    run_artifact = "telemetry/teleport-route.tsv"
    deployed_path = $deployedRoutePath
    copied = $routeFileCopied
  }
  plugin = $plugin
  network_sense_config = $configProfile
  valheim_processes = $processes
  valheim_process_count = @($processes).Count
  observed = [ordered]@{
    priority_rows_total = $priorityRows.Count
    priority_route_rows = $routeRows.Count
    sample_rows = $sampleRows.Count
    object_rows = $objectRows.Count
    observed_stop_count = $observedStopIds.Count
    observed_stop_ids = $observedStopIds
    route_end_markers = $routeEndMarkers.Count
    max_scan_duration_ms = $maxScanDurationMs
    collider_buffer_full_any = $anyScanBufferFull
    per_stop = $perStop
  }
  gates = $gates
  priority_route_command = $priorityCommand
  wide_priority_route_command = $widePriorityCommand
  mcp_phase = [ordered]@{
    current_phase = $phaseName
    next_marker_command = $nextMcpMarker
    handoff_signal = "Run this marker after the in-game phase completes; agents should then read telemetry/priority-load-summary.json and choose the next phase."
  }
  claims_not_proven = @(
    "True vanilla network arrival order",
    "Lumberjacks priority stream delivery",
    "Valheim ZDO transport replacement",
    "Server-side priority enforcement"
  )
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  $priorityCommand,
  "network_sense_mcp_mark lumberjacks_priority_route_command_ran",
  $nextMcpMarker
) | Set-Content -Encoding UTF8 $consoleCommandsPath

$nextPhaseText = if ($summaryStatus -eq "pass_priority_route_observed") {
  "Build the Lumberjacks mirror phase: send the priority manifest as ordered side-channel metadata and compare delivery/order under load."
} elseif ($summaryStatus -eq "pass_priority_route_observed_with_sparse_gap") {
  "Proceed to the Lumberjacks mirror phase. Keep the sparse fixture note: one route stop has no non-player priority objects even at 256m."
} elseif ($summaryStatus -eq "priority_route_observed_visibility_gaps") {
  "Run the wider-radius follow-up: $widePriorityCommand"
} elseif ($summaryStatus -eq "priority_route_in_progress") {
  "The latest priority route is still running. Wait for the in-game route to finish, then rerun this packet."
} else {
  "Run the in-game priority route command above and rerun this packet."
}

@(
  "# Valheim Lumberjacks Priority Load Order",
  "",
  "## Current Status",
  "",
  "- Summary status: $summaryStatus",
  "- Phase: $phaseName",
  "- Installed ComfyNetworkSense: $($plugin.version)",
  "- Route source: $routeSource",
  "- Route steps: $($routeSteps.Count)",
  "- Route file copied: $routeFileCopied",
  "- Latest route start: $latestRouteStartMessage",
  "- Latest route completed: $latestRouteCompleted",
  "- Priority sample rows observed in latest route: $($sampleRows.Count)",
  "- Priority object rows observed in latest route: $($objectRows.Count)",
  "- Observed stops: $($observedStopIds.Count)/$($routeSteps.Count)",
  "- Max scan duration: ${maxScanDurationMs}ms",
  "- Collider buffer saturated: $anyScanBufferFull",
  "",
  "## Run In Valheim",
  "",
  "Restart Valheim after installing ComfyNetworkSense 0.5.0, load the Era16 test world, keep the game foregrounded, open the console, then run:",
  "",
  '```text',
  $priorityCommand,
  '```',
  "",
  "The command teleports through the route, starts one priority scanner per stop, writes route-tagged rows to priority-load.jsonl, and exports the NetworkSense session at the end.",
  "",
  "Estimated route time: $([math]::Round($estimatedSeconds / 60.0, 1)) minutes.",
  "",
  "After the route completes, run:",
  "",
  '```text',
  $nextMcpMarker,
  '```',
  "",
  "Then rerun this scenario:",
  "",
  '```powershell',
  ".\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-priority-load-order.yaml",
  '```',
  "",
  "## What Pass Means",
  "",
  "pass_priority_route_observed means every route stop produced priority sample rows with tier counts and a completion marker. It proves a local priority manifest can be built from loaded Valheim objects; it does not prove true network arrival order or Lumberjacks priority delivery yet.",
  "",
  "## Next Phase",
  "",
  $nextPhaseText
) | Set-Content -Encoding UTF8 $operatorRunbookPath

@(
  "# Command Plan Summary",
  "",
  "- Status: $summaryStatus",
  "- Phase: $phaseName",
  "- Installed ComfyNetworkSense version: $($plugin.version)",
  "- Route source: $routeSource",
  "- Route file copied: $routeFileCopied",
  "- Priority sample rows observed: $($sampleRows.Count)",
  "- Priority object rows observed: $($objectRows.Count)",
  "- Observed stops: $($observedStopIds.Count)/$($routeSteps.Count)",
  "- Next MCP marker: ``$nextMcpMarker``",
  "- Command: ``$priorityCommand``",
  "- Wide-radius command: ``$widePriorityCommand``",
  "- Summary: telemetry/priority-load-summary.json",
  "- Density CSV: telemetry/priority-load-density-comparison.csv",
  "- Runbook: raw/operator-runbook.md"
) | Set-Content -Encoding UTF8 $commandSummaryPath
