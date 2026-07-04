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

$summaryPath = Join-Path $telemetryDir "teleport-rehearsal-summary.json"
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

  $candidate = Get-ChildItem -Path $runsPath -Directory -Filter "*valheim-era16-volunteer-readiness-baseline" |
    Sort-Object LastWriteTime -Descending |
    Where-Object { Test-Path (Join-Path $_.FullName "telemetry\teleport-route-contract.json") } |
    Select-Object -First 1

  if ($candidate) {
    return (Join-Path $candidate.FullName "telemetry\teleport-route-contract.json")
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

function Get-ValheimProcessSummary {
  $processes = @(Get-CimInstance Win32_Process | Where-Object {
      $_.Name -match "^(valheim|valheim_server)\.exe$" -or $_.CommandLine -match "(?i)(\\|/)(valheim|valheim_server)\.exe(\s|$)"
    } | ForEach-Object {
      [ordered]@{
        process_id = $_.ProcessId
        name = $_.Name
        command_line = $_.CommandLine
      }
    })

  $udpPorts = @(Get-NetUDPEndpoint -LocalPort 2456, 2457, 2458 -ErrorAction SilentlyContinue | ForEach-Object {
      [ordered]@{
        local_address = $_.LocalAddress
        local_port = $_.LocalPort
        owning_process = $_.OwningProcess
      }
    })

  [ordered]@{
    process_count = $processes.Count
    udp_listener_count = $udpPorts.Count
    processes = $processes
    udp_ports = $udpPorts
  }
}

function Test-Gateway {
  try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:8720/healthz" -TimeoutSec 3
    return [ordered]@{
      ok = [bool]$response.ok
      response = $response
    }
  } catch {
    return [ordered]@{
      ok = $false
      error = $_.Exception.Message
    }
  }
}

function Set-NetworkSenseConfigValues {
  param([string]$ConfigPath)

  $desired = [ordered]@{
    liveSampleIntervalSeconds = "0.5"
    serverPulseIntervalSeconds = "2"
    benchmarkDurationSeconds = "60"
    writeTelemetryLogs = "true"
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
    profile = "baseline_route"
    changes = @($changes)
    requires_reload = $true
  }
}

$resourceProfile = if ($env:FIELDLAB_RESOURCE_PROFILE) { $env:FIELDLAB_RESOURCE_PROFILE } else { "host_full" }
$logDir = Resolve-NetworkSenseLogDir
$routeContractPath = Get-LatestRouteContractPath -Root $RepoRoot
$routeContract = $null
$routeSteps = @()

if ($routeContractPath -and (Test-Path $routeContractPath)) {
  $routeContract = Get-Content -Raw $routeContractPath | ConvertFrom-Json
  $routeSteps = @($routeContract.route_steps)
}

$tsvLines = @("id`tworld_x`tworld_z`tsettle_seconds`tbenchmark_seconds")
foreach ($step in $routeSteps) {
  $tsvLines += "$($step.id)`t$($step.world_x)`t$($step.world_z)`t$($step.settle_seconds)`t$($step.benchmark_seconds)"
}
$tsvLines | Set-Content -Encoding UTF8 $routeTsvPath

$deployedRoutePath = Join-Path $logDir "teleport-route.tsv"
$routeFileCopied = $false
if (Test-Path $logDir -PathType Container) {
  Copy-Item $routeTsvPath $deployedRoutePath -Force
  $routeFileCopied = Test-Path $deployedRoutePath
}

$modSourcePath = Join-Path $RepoRoot "network\mod\ComfyNetworkSense\ComfyNetworkSense.cs"
$pluginDllPath = "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\plugins\ComfyNetworkSense.dll"
$networkSenseConfigPath = "C:\Program Files (x86)\Steam\steamapps\common\Valheim\BepInEx\config\djcdevelopment.valheim.comfynetworksense.cfg"
$modSource = if (Test-Path $modSourcePath) { Get-Content -Raw $modSourcePath } else { "" }
$modSupportsRouteRun = $modSource -match "network_sense_route_run"
$modSupportsRehearsal = $modSource -match "network_sense_rehearsal"
$pluginDll = if (Test-Path $pluginDllPath) { Get-Item $pluginDllPath } else { $null }
$configProfile = Set-NetworkSenseConfigValues -ConfigPath $networkSenseConfigPath
$gateway = Test-Gateway
$valheim = Get-ValheimProcessSummary

$events = Read-JsonLines -Path (Join-Path $logDir "event-timeline.jsonl")
$benchmarks = Read-JsonLines -Path (Join-Path $logDir "benchmark-results.jsonl")
$routeMarkerCount = 0
$completedStopIds = @()
foreach ($step in $routeSteps) {
  $endMarker = "$($step.id) end"
  $matched = @($events | Where-Object { $_.event_name -eq "dev_marker" -and ([string]$_.message).Contains($endMarker) })
  if ($matched.Count -gt 0) {
    $routeMarkerCount += $matched.Count
    $completedStopIds += $step.id
  }
}

$routeComplete = $routeSteps.Count -gt 0 -and $completedStopIds.Count -eq $routeSteps.Count
$benchmarkCount = @($benchmarks).Count

$commands = @(
  "network_sense_rehearsal teleport-route.tsv $resourceProfile"
)
$commands | Set-Content -Encoding UTF8 $consoleCommandsPath

@(
  "# Valheim Era16 Teleport Rehearsal Runbook",
  "",
  "Resource profile: ``$resourceProfile``",
  "",
  "1. Start the dedicated server or local world with Era16 loaded.",
  "2. Start Valheim with the rebuilt ``ComfyNetworkSense.dll``.",
  "3. Open the Valheim console and run this command:",
  "",
  '```text'
) + $commands + @(
  '```',
  "",
  "This command reloads NetworkSense config, checks the local MCP gateway, records rehearsal markers, runs the route, and exports the session at the end.",
  "",
  "The route runner reads:",
  "",
  "``$deployedRoutePath``",
  "",
  "It will teleport through these stops, wait for settlement, start one benchmark per stop, and write markers:",
  ""
) + @($routeSteps | ForEach-Object {
  "- $($_.id): $($_.density_band) at ($($_.world_x), $($_.world_z)), settle $($_.settle_seconds)s, benchmark $($_.benchmark_seconds)s"
}) + @(
  "",
  "After the route finishes, rerun this FieldLab scenario and then rerun the volunteer readiness baseline."
) | Set-Content -Encoding UTF8 $operatorRunbookPath

$gates = @(
  New-Gate -Id "route_contract" -Status ($(if ($routeSteps.Count -gt 0) { "pass" } else { "fail" })) -Observed "$($routeSteps.Count) route steps from $routeContractPath."
  New-Gate -Id "mod_support" -Status ($(if ($modSupportsRouteRun -and $modSupportsRehearsal -and $pluginDll) { "pass" } elseif ($modSupportsRouteRun -and $modSupportsRehearsal) { "warn" } else { "fail" })) -Observed "route_run_support=$modSupportsRouteRun, rehearsal_support=$modSupportsRehearsal, plugin_dll_exists=$([bool]$pluginDll)."
  New-Gate -Id "route_file" -Status ($(if ($routeFileCopied) { "pass" } else { "fail" })) -Observed "generated=$routeTsvPath, deployed=$deployedRoutePath, copied=$routeFileCopied."
  New-Gate -Id "network_sense_config" -Status ($(if ($configProfile.exists) { "pass" } else { "warn" })) -Observed "profile=$($configProfile.profile), changes=$(@($configProfile.changes).Count), requires_reload=$($configProfile.requires_reload)."
  New-Gate -Id "gateway" -Status ($(if ($gateway.ok) { "pass" } else { "warn" })) -Observed "ok=$($gateway.ok)."
  New-Gate -Id "valheim_running" -Status ($(if ($valheim.process_count -gt 0 -or $valheim.udp_listener_count -gt 0) { "pass" } else { "warn" })) -Observed "$($valheim.process_count) Valheim processes, $($valheim.udp_listener_count) UDP listeners."
  New-Gate -Id "route_completion" -Status ($(if ($routeComplete) { "pass" } else { "pending" })) -Observed "$($completedStopIds.Count)/$($routeSteps.Count) stop end markers observed; benchmark_results_total=$benchmarkCount."
)

$failCount = @($gates | Where-Object { $_.status -eq "fail" }).Count
$warnCount = @($gates | Where-Object { $_.status -eq "warn" }).Count
$pendingCount = @($gates | Where-Object { $_.status -eq "pending" }).Count

$status = if ($failCount -gt 0) {
  "rehearsal_blocked"
} elseif ($routeComplete) {
  "pass"
} elseif ($valheim.process_count -gt 0 -or $valheim.udp_listener_count -gt 0) {
  "rehearsal_ready_game_running"
} else {
  "rehearsal_ready_not_running"
}

$summary = [ordered]@{
  schema_version = 1
  status = $status
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  resource_profile = $resourceProfile
  network_sense_log_dir = $logDir
  route_contract_path = $routeContractPath
  route_step_count = $routeSteps.Count
  route_file = [ordered]@{
    run_artifact = "telemetry/teleport-route.tsv"
    deployed_path = $deployedRoutePath
    copied = $routeFileCopied
  }
  mod = [ordered]@{
    source_supports_route_run = $modSupportsRouteRun
    source_supports_rehearsal = $modSupportsRehearsal
    plugin_dll_path = $pluginDllPath
    plugin_dll_exists = [bool]$pluginDll
    plugin_dll_last_write_utc = if ($pluginDll) { $pluginDll.LastWriteTimeUtc.ToString("o") } else { $null }
  }
  network_sense_config = $configProfile
  gateway = $gateway
  valheim = $valheim
  observed = [ordered]@{
    completed_stop_count = $completedStopIds.Count
    completed_stop_ids = $completedStopIds
    route_complete = $routeComplete
    benchmark_results_total = $benchmarkCount
  }
  gates = $gates
  fail_count = $failCount
  warn_count = $warnCount
  pending_count = $pendingCount
  outputs = [ordered]@{
    summary = "telemetry/teleport-rehearsal-summary.json"
    route_tsv = "telemetry/teleport-route.tsv"
    runbook = "raw/operator-runbook.md"
    console_commands = "raw/valheim-console-commands.txt"
  }
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Era16 Teleport Rehearsal",
  "",
  "Status: $status",
  "",
  "Route steps: $($routeSteps.Count)",
  "Resource profile: $resourceProfile",
  "Route file copied: $routeFileCopied",
  "Valheim processes: $($valheim.process_count)",
  "Observed completion: $($completedStopIds.Count)/$($routeSteps.Count)",
  "",
  "Next command in Valheim:",
  "",
  "``network_sense_rehearsal teleport-route.tsv $resourceProfile``"
) | Set-Content -Encoding UTF8 $commandSummaryPath

exit 0
