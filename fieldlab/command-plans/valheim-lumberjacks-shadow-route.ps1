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

$summaryPath = Join-Path $telemetryDir "shadow-route-summary.json"
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

  $Value | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $Path
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

function Test-HealthEndpoint {
  param([Parameter(Mandatory = $true)][string]$Url)

  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Url -TimeoutSec 2
    [ordered]@{
      ok = $true
      status_code = [int]$response.StatusCode
      body = [string]$response.Content
      error = $null
    }
  } catch {
    [ordered]@{
      ok = $false
      status_code = $null
      body = $null
      error = $_.Exception.Message
    }
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
  $lines = @(Get-Content -Path $Path)
  foreach ($line in $lines) {
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

function Set-NetworkSenseConfigValues {
  param([string]$ConfigPath)

  $desired = [ordered]@{
    writeTelemetryLogs = "true"
    benchmarkDurationSeconds = "60"
    lumberjacksShadowInputHz = "10"
    lumberjacksShadowLogIntervalSeconds = "2"
  }

  if (-not (Test-Path $ConfigPath)) {
    return [ordered]@{
      exists = $false
      path = $ConfigPath
      changes = @()
    }
  }

  $lines = @(Get-Content -Path $ConfigPath)
  $changes = @()

  foreach ($key in $desired.Keys) {
    $prefix = "$key = "
    for ($index = 0; $index -lt $lines.Count; $index++) {
      if ($lines[$index].StartsWith($prefix)) {
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

  if (@($changes).Count -gt 0) {
    $lines | Set-Content -Encoding UTF8 $ConfigPath
  }

  return [ordered]@{
    exists = $true
    path = $ConfigPath
    profile = "lumberjacks_shadow_route"
    changes = @($changes)
    requires_reload = @($changes).Count -gt 0
  }
}

$gatewayWs = if ($env:FIELDLAB_LUMBERJACKS_GATEWAY_WS) { $env:FIELDLAB_LUMBERJACKS_GATEWAY_WS } else { "ws://127.0.0.1:4000" }
$gatewayHttp = $gatewayWs -replace "^ws://", "http://" -replace "^wss://", "https://"
$regionId = if ($env:FIELDLAB_LUMBERJACKS_REGION) { $env:FIELDLAB_LUMBERJACKS_REGION } else { "region-spawn" }
$profile = if ($env:FIELDLAB_SHADOW_ROUTE_PROFILE) { $env:FIELDLAB_SHADOW_ROUTE_PROFILE } else { "movement_only" }
$valheimDir = if ($env:FIELDLAB_VALHEIM_DIR) { $env:FIELDLAB_VALHEIM_DIR } else { "C:\Program Files (x86)\Steam\steamapps\common\Valheim" }
$pluginPath = Join-Path $valheimDir "BepInEx\plugins\ComfyNetworkSense.dll"
$configPath = Join-Path $valheimDir "BepInEx\config\djcdevelopment.valheim.comfynetworksense.cfg"
$logDir = Resolve-NetworkSenseLogDir
$shadowLogPath = Join-Path $logDir "lumberjacks-shadow.jsonl"
$eventLogPath = Join-Path $logDir "event-timeline.jsonl"
$deployedRoutePath = Join-Path $logDir "teleport-route.tsv"

$routeContractPath = Get-LatestRouteContractPath -Root $RepoRoot
$routeContract = $null
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

$health = [ordered]@{
  gateway = Test-HealthEndpoint "$gatewayHttp/health"
  eventlog = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4002") + "/health")
  progression = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4003") + "/health")
  operatorapi = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4004") + "/health")
}

$plugin = Get-AssemblyVersionInfo $pluginPath
$versionOk = $false
if ($plugin.version) {
  try {
    $versionOk = ([version]$plugin.version) -ge ([version]"0.4.7.0")
  } catch {
    $versionOk = $false
  }
}

$configProfile = Set-NetworkSenseConfigValues -ConfigPath $configPath
$processes = @(Get-ValheimProcesses)
$shadowRows = @(Read-JsonLines -Path $shadowLogPath)
$eventRows = @(Read-JsonLines -Path $eventLogPath)
$routeRows = @($shadowRows | Where-Object {
    [string]$_.run_label -eq "shadow_route" -and -not [string]::IsNullOrWhiteSpace([string]$_.route_stop_id)
  })
$routeStopRows = @($routeRows | Where-Object { [string]$_.event -eq "route_stop" -or [string]$_.event -eq "stop" })
$routeEndMarkers = @($eventRows | Where-Object {
    [string]$_.event_name -eq "dev_marker" -and ([string]$_.message) -eq "lumberjacks_shadow_route end"
  })

$observedStopIds = @($routeRows | ForEach-Object { [string]$_.route_stop_id } | Where-Object { $_ } | Sort-Object -Unique)
$successfulStopIds = @($routeRows | Where-Object {
    ($null -ne $_.inputs_sent -and [int]$_.inputs_sent -gt 0) -and
    ($null -ne $_.self_authority_updates -and [int]$_.self_authority_updates -gt 0) -and
    ($null -ne $_.drift_samples -and [int]$_.drift_samples -gt 0) -and
    ($null -ne $_.errors -and [int]$_.errors -eq 0)
  } | ForEach-Object { [string]$_.route_stop_id } | Where-Object { $_ } | Sort-Object -Unique)

$perStop = @($routeSteps | ForEach-Object {
    $stop = $_
    $rows = @($routeRows | Where-Object { [string]$_.route_stop_id -eq [string]$stop.id })
    $latest = @($rows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
    $latestValue = if ($latest.Count -gt 0) { $latest[0] } else { $null }
    [ordered]@{
      id = $stop.id
      density_band = $stop.density_band
      row_count = $rows.Count
      observed = $rows.Count -gt 0
      latest_event = if ($latestValue) { [string]$latestValue.event } else { $null }
      inputs_sent = if ($latestValue -and $null -ne $latestValue.inputs_sent) { [int]$latestValue.inputs_sent } else { 0 }
      self_authority_updates = if ($latestValue -and $null -ne $latestValue.self_authority_updates) { [int]$latestValue.self_authority_updates } else { 0 }
      drift_samples = if ($latestValue -and $null -ne $latestValue.drift_samples) { [int]$latestValue.drift_samples } else { 0 }
      last_drift_meters = if ($latestValue -and $null -ne $latestValue.last_drift_meters) { [double]$latestValue.last_drift_meters } else { $null }
      max_drift_meters = if ($latestValue -and $null -ne $latestValue.max_drift_meters) { [double]$latestValue.max_drift_meters } else { $null }
      average_drift_meters = if ($latestValue -and $null -ne $latestValue.average_drift_meters) { [double]$latestValue.average_drift_meters } else { $null }
      errors = if ($latestValue -and $null -ne $latestValue.errors) { [int]$latestValue.errors } else { 0 }
      latest_timestamp_utc = if ($latestValue) { [string]$latestValue.timestamp_utc } else { $null }
    }
  })

$routeRowsObserved = $routeRows.Count -gt 0
$allStopsObserved = $routeSteps.Count -gt 0 -and $successfulStopIds.Count -ge $routeSteps.Count
$partialStopsObserved = $successfulStopIds.Count -gt 0

$gates = @(
  New-Gate -Id "route_file" -Status ($(if ($routeSteps.Count -gt 0 -and $routeFileCopied) { "pass" } elseif ($routeSteps.Count -gt 0) { "fail" } else { "fail" })) -Observed "route_steps=$($routeSteps.Count), source=$routeSource, generated=$routeTsvPath, deployed=$deployedRoutePath, copied=$routeFileCopied."
  New-Gate -Id "mod_deployed" -Status ($(if ($versionOk) { "pass" } else { "fail" })) -Observed "ComfyNetworkSense installed version: $($plugin.version)."
  New-Gate -Id "lumberjacks_runtime" -Status ($(if ($health.gateway.ok) { "pass" } else { "warn" })) -Observed "Gateway health at $gatewayHttp/health: ok=$($health.gateway.ok), status=$($health.gateway.status_code), error=$($health.gateway.error)."
  New-Gate -Id "valheim_running" -Status ($(if (@($processes).Count -gt 0) { "pass" } else { "warn" })) -Observed "$(@($processes).Count) Valheim processes visible."
  New-Gate -Id "shadow_route_rows" -Status ($(if ($routeRowsObserved) { "pass" } else { "pending" })) -Observed "route-tagged shadow rows=$($routeRows.Count), route_stop rows=$($routeStopRows.Count)."
  New-Gate -Id "route_drift_distribution" -Status ($(if ($allStopsObserved) { "pass" } elseif ($partialStopsObserved) { "pending" } else { "pending" })) -Observed "$($successfulStopIds.Count)/$($routeSteps.Count) route stops have inputs, self updates, drift samples, and zero errors."
  New-Gate -Id "route_completion_marker" -Status ($(if ($routeEndMarkers.Count -gt 0) { "pass" } elseif ($partialStopsObserved) { "pending" } else { "pending" })) -Observed "$($routeEndMarkers.Count) lumberjacks_shadow_route end markers observed."
  New-Gate -Id "no_corrections_scope" -Status "pass" -Observed "Route command is measurement-only: no Valheim transform corrections, ZNetView changes, or ZDO writes are applied."
)

$summaryStatus = if ($allStopsObserved -and $routeEndMarkers.Count -gt 0) {
  "pass_shadow_route_observed"
} elseif ($partialStopsObserved) {
  "shadow_route_partial"
} elseif ($routeSteps.Count -gt 0 -and $routeFileCopied -and $versionOk) {
  "staged_waiting_for_shadow_route"
} else {
  "blocked_setup"
}

$shadowCommand = "network_sense_lumberjacks_shadow_route teleport-route.tsv $profile $gatewayWs $regionId"
$estimatedSeconds = 0
foreach ($step in $routeSteps) {
  $estimatedSeconds += [double]$step.settle_seconds + [double]$step.benchmark_seconds + 3.0
}

$summary = [ordered]@{
  schema_version = 1
  status = $summaryStatus
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  gateway_ws = $gatewayWs
  gateway_http = $gatewayHttp
  region_id = $regionId
  movement_profile = $profile
  network_sense_log_dir = $logDir
  shadow_log_path = $shadowLogPath
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
  health = $health
  plugin = $plugin
  network_sense_config = $configProfile
  valheim_processes = $processes
  valheim_process_count = @($processes).Count
  observed = [ordered]@{
    shadow_rows_total = $shadowRows.Count
    shadow_route_rows = $routeRows.Count
    route_stop_rows = $routeStopRows.Count
    observed_stop_count = $observedStopIds.Count
    observed_stop_ids = $observedStopIds
    successful_stop_count = $successfulStopIds.Count
    successful_stop_ids = $successfulStopIds
    route_end_markers = $routeEndMarkers.Count
    per_stop = $perStop
  }
  gates = $gates
  shadow_route_command = $shadowCommand
  claims_not_proven = @(
    "Valheim transform correction safety",
    "Valheim ZDO transport replacement",
    "Valheim physics authority replacement",
    "Steam/PlayFab socket replacement"
  )
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  $shadowCommand,
  "network_sense_mcp_mark lumberjacks_shadow_route_command_ran"
) | Set-Content -Encoding UTF8 $consoleCommandsPath

@(
  "# Valheim Lumberjacks Shadow Route Drift",
  "",
  "## Current Status",
  "",
  "- Summary status: $summaryStatus",
  "- Gateway: $gatewayWs",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense: $($plugin.version)",
  "- Route source: $routeSource",
  "- Route steps: $($routeSteps.Count)",
  "- Route file copied: $routeFileCopied",
  "- Route-tagged rows observed: $($routeRows.Count)",
  "- Successful route stops observed: $($successfulStopIds.Count)/$($routeSteps.Count)",
  "",
  "## Run In Valheim",
  "",
  "Restart Valheim after installing ComfyNetworkSense 0.4.7, load the Era16 test world, keep the game foregrounded, open the console, then run:",
  "",
  '```text',
  $shadowCommand,
  '```',
  "",
  "The command teleports through the route, starts one Lumberjacks shadow window per stop, moves locally in a small repeatable circle during the benchmark window, writes route-tagged rows to lumberjacks-shadow.jsonl, and exports the NetworkSense session at the end.",
  "",
  "Estimated route time: $([math]::Round($estimatedSeconds / 60.0, 1)) minutes.",
  "",
  "Then rerun this scenario:",
  "",
  '```powershell',
  ".\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-shadow-route.yaml",
  '```',
  "",
  "## What Pass Means",
  "",
  "pass_shadow_route_observed means every route stop has route-tagged Lumberjacks shadow rows with sent inputs, authoritative self updates, drift samples, zero errors, and a route completion marker. It does not mean corrections can be safely applied to Valheim.",
  "",
  "## Next Spike",
  "",
  "$(if ($allStopsObserved) { 'Compare open-control drift against dense/extreme drift and decide whether bounded local-only correction experiments are worth staging.' } else { 'Run the in-game shadow route command above and rerun this packet to capture the per-stop drift distribution.' })"
) | Set-Content -Encoding UTF8 $operatorRunbookPath

@(
  "# Command Plan Summary",
  "",
  "- Status: $summaryStatus",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense version: $($plugin.version)",
  "- Route source: $routeSource",
  "- Route file copied: $routeFileCopied",
  "- Route-tagged rows observed: $($routeRows.Count)",
  "- Successful route stops observed: $($successfulStopIds.Count)/$($routeSteps.Count)",
  "- Command: ``$shadowCommand``",
  "- Summary: telemetry/shadow-route-summary.json",
  "- Runbook: raw/operator-runbook.md"
) | Set-Content -Encoding UTF8 $commandSummaryPath
