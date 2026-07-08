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

$summaryPath = Join-Path $telemetryDir "shadow-authority-summary.json"
$runbookPath = Join-Path $rawDir "operator-runbook.md"
$commandsPath = Join-Path $rawDir "valheim-console-commands.txt"
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

$gatewayWs = if ($env:FIELDLAB_LUMBERJACKS_GATEWAY_WS) { $env:FIELDLAB_LUMBERJACKS_GATEWAY_WS } else { "ws://127.0.0.1:4000" }
$gatewayHttp = $gatewayWs -replace "^ws://", "http://" -replace "^wss://", "https://"
$regionId = if ($env:FIELDLAB_LUMBERJACKS_REGION) { $env:FIELDLAB_LUMBERJACKS_REGION } else { "region-spawn" }
$valheimDir = if ($env:FIELDLAB_VALHEIM_DIR) { $env:FIELDLAB_VALHEIM_DIR } else { "C:\Program Files (x86)\Steam\steamapps\common\Valheim" }
$pluginPath = Join-Path $valheimDir "BepInEx\plugins\ComfyNetworkSense.dll"
$logDir = Resolve-NetworkSenseLogDir
$bridgeLogPath = Join-Path $logDir "lumberjacks-bridge-probes.jsonl"
$projectionLogPath = Join-Path $logDir "lumberjacks-projection.jsonl"
$shadowLogPath = Join-Path $logDir "lumberjacks-shadow.jsonl"

$health = [ordered]@{
  gateway = Test-HealthEndpoint "$gatewayHttp/health"
  eventlog = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4002") + "/health")
  progression = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4003") + "/health")
  operatorapi = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4004") + "/health")
}

$plugin = Get-AssemblyVersionInfo $pluginPath
$processes = @(Get-ValheimProcesses)

$bridgeRows = Read-JsonLines $bridgeLogPath
$projectionRows = Read-JsonLines $projectionLogPath
$shadowRows = Read-JsonLines $shadowLogPath

$latestBridge = @($bridgeRows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
$latestProjection = @($projectionRows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
$latestShadow = @($shadowRows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)

$latestBridgeValue = if ($latestBridge.Count -gt 0) { $latestBridge[0] } else { $null }
$latestProjectionValue = if ($latestProjection.Count -gt 0) { $latestProjection[0] } else { $null }
$latestShadowValue = if ($latestShadow.Count -gt 0) { $latestShadow[0] } else { $null }

$versionOk = $false
if ($plugin.version) {
  try {
    $versionOk = ([version]$plugin.version) -ge ([version]"0.4.6.0")
  } catch {
    $versionOk = $false
  }
}

$bridgeStatus = if ($latestBridgeValue) { [string]$latestBridgeValue.status } else { "not_observed" }
$bridgePass = $bridgeStatus -eq "pass_sidecar_protocol"

$projectionProxyCount = if ($latestProjectionValue -and $null -ne $latestProjectionValue.proxy_count) { [int]$latestProjectionValue.proxy_count } else { 0 }
$projectionEntitiesProjected = if ($latestProjectionValue -and $null -ne $latestProjectionValue.entities_projected) { [int]$latestProjectionValue.entities_projected } else { 0 }
$projectionPass = $projectionProxyCount -gt 0 -or $projectionEntitiesProjected -gt 0
$projectionStatus = if ($latestProjectionValue) { [string]$latestProjectionValue.status } else { "not_observed" }

$shadowStatus = if ($latestShadowValue) { [string]$latestShadowValue.status } else { "not_observed" }
$shadowInputsSent = if ($latestShadowValue -and $null -ne $latestShadowValue.inputs_sent) { [int]$latestShadowValue.inputs_sent } else { 0 }
$shadowSelfUpdates = if ($latestShadowValue -and $null -ne $latestShadowValue.self_authority_updates) { [int]$latestShadowValue.self_authority_updates } else { 0 }
$shadowDriftSamples = if ($latestShadowValue -and $null -ne $latestShadowValue.drift_samples) { [int]$latestShadowValue.drift_samples } else { 0 }
$shadowErrors = if ($latestShadowValue -and $null -ne $latestShadowValue.errors) { [int]$latestShadowValue.errors } else { 0 }
$shadowPass = $shadowInputsSent -gt 0 -and $shadowSelfUpdates -gt 0 -and $shadowDriftSamples -gt 0 -and $shadowErrors -eq 0

$gates = @(
  New-Gate -Id "lumberjacks_runtime" -Status ($(if ($health.gateway.ok) { "pass" } else { "fail" })) -Observed "Gateway health at $gatewayHttp/health: ok=$($health.gateway.ok), status=$($health.gateway.status_code), error=$($health.gateway.error)"
  New-Gate -Id "mod_deployed" -Status ($(if ($versionOk) { "pass" } else { "fail" })) -Observed "ComfyNetworkSense installed version: $($plugin.version)"
  New-Gate -Id "valheim_running" -Status ($(if (@($processes).Count -gt 0) { "pass" } else { "warn" })) -Observed "$(@($processes).Count) Valheim processes visible."
  New-Gate -Id "bridge_protocol" -Status ($(if ($bridgePass) { "pass" } elseif ($latestBridgeValue) { "fail" } else { "warn" })) -Observed "Latest bridge probe status: $bridgeStatus"
  New-Gate -Id "local_visual_projection" -Status ($(if ($projectionPass) { "pass" } elseif ($latestProjectionValue) { "warn" } else { "warn" })) -Observed "Latest projection status: $projectionStatus, proxy_count=$projectionProxyCount, entities_projected=$projectionEntitiesProjected"
  New-Gate -Id "shadow_authority_compare" -Status ($(if ($shadowPass) { "pass" } elseif ($latestShadowValue) { "warn" } else { "warn" })) -Observed "Latest shadow status: $shadowStatus, inputs_sent=$shadowInputsSent, self_updates=$shadowSelfUpdates, drift_samples=$shadowDriftSamples, errors=$shadowErrors"
  New-Gate -Id "no_corrections_scope" -Status "pass" -Observed "Packet scopes this as measurement only: no Valheim transform corrections, ZNetView changes, or ZDO writes."
)

$summaryStatus = if ($shadowPass) {
  "pass_shadow_movement_observed"
} elseif ($projectionPass) {
  "staged_waiting_for_shadow_probe"
} elseif ($bridgePass) {
  "staged_waiting_for_projection"
} elseif ($health.gateway.ok -and $versionOk) {
  "staged_waiting_for_bridge_probe"
} else {
  "blocked_setup"
}

$decisionMatrix = @(
  [ordered]@{
    layer = "shadow_movement_authority"
    status = if ($shadowPass) { "measurable_without_corrections" } else { "implemented_waiting_for_motion_run" }
    evidence = "network_sense_lumberjacks_shadow writes lumberjacks-shadow.jsonl with inputs, self authority updates, and drift samples."
    next_gate = "Run a repeatable movement route and compare drift distribution before considering correction application."
  }
  [ordered]@{
    layer = "correction_application"
    status = "not_started"
    evidence = "No Valheim transform corrections are applied by this packet."
    next_gate = "Bounded local-only correction sandbox after drift behavior is characterized."
  }
  [ordered]@{
    layer = "valheim_zdo_transport_replacement"
    status = "still_not_proven"
    evidence = "Shadow authority is side-channel measurement only."
    next_gate = "Separate controlled proxy-object ownership/send-queue proof."
  }
)

$summary = [ordered]@{
  schema_version = 1
  status = $summaryStatus
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  gateway_ws = $gatewayWs
  gateway_http = $gatewayHttp
  region_id = $regionId
  network_sense_log_dir = $logDir
  bridge_log_path = $bridgeLogPath
  projection_log_path = $projectionLogPath
  shadow_log_path = $shadowLogPath
  health = $health
  plugin = $plugin
  valheim_processes = $processes
  valheim_process_count = @($processes).Count
  bridge = [ordered]@{ observed_rows = @($bridgeRows).Count; latest = $latestBridgeValue; pass = $bridgePass }
  projection = [ordered]@{ observed_rows = @($projectionRows).Count; latest = $latestProjectionValue; pass = $projectionPass }
  shadow = [ordered]@{ observed_rows = @($shadowRows).Count; latest = $latestShadowValue; pass = $shadowPass }
  gates = $gates
  decision_matrix = $decisionMatrix
  shadow_command = "network_sense_lumberjacks_shadow start $gatewayWs $regionId"
  claims_not_proven = @(
    "Valheim transform correction safety",
    "Valheim ZDO transport replacement",
    "Valheim physics authority replacement",
    "Steam/PlayFab socket replacement"
  )
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Lumberjacks Shadow Authority",
  "",
  "## Current Status",
  "",
  "- Summary status: $summaryStatus",
  "- Gateway: $gatewayWs",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense: $($plugin.version)",
  "- Valheim processes visible: $(@($processes).Count)",
  "- Latest bridge probe: $bridgeStatus",
  "- Latest projection: $projectionStatus, proxy_count=$projectionProxyCount, entities_projected=$projectionEntitiesProjected",
  "- Latest shadow: $shadowStatus, inputs_sent=$shadowInputsSent, self_updates=$shadowSelfUpdates, drift_samples=$shadowDriftSamples, errors=$shadowErrors",
  "",
  "## Run In Valheim",
  "",
  "Restart Valheim after installing ComfyNetworkSense 0.4.6, open the console, then run:",
  "",
  '```text',
  "network_sense_lumberjacks_shadow start $gatewayWs $regionId",
  "# move the local player around for 60-120 seconds",
  "network_sense_lumberjacks_shadow status",
  "network_sense_lumberjacks_shadow stop",
  '```',
  "",
  "Then rerun this scenario:",
  "",
  '```powershell',
  ".\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-shadow-authority.yaml",
  '```',
  "",
  "## What Pass Means",
  "",
  "pass_shadow_movement_observed means Valheim-derived player_input reached Lumberjacks, authoritative self updates came back, and drift samples were recorded. It does not mean corrections can be safely applied to Valheim.",
  "",
  "## Next Spike",
  "",
  "$(if ($shadowPass) { 'Run a repeatable movement route and compare drift distribution before considering bounded correction experiments.' } else { 'Run the shadow command above while moving the local player so drift samples can be captured.' })"
) | Set-Content -Encoding UTF8 $runbookPath

@(
  "network_sense_lumberjacks_shadow start $gatewayWs $regionId",
  "network_sense_lumberjacks_shadow status",
  "network_sense_lumberjacks_shadow stop",
  "network_sense_mcp_mark lumberjacks_shadow_probe_ran"
) | Set-Content -Encoding UTF8 $commandsPath

@(
  "# Command Plan Summary",
  "",
  "- Status: $summaryStatus",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense version: $($plugin.version)",
  "- Latest shadow status: $shadowStatus, inputs_sent=$shadowInputsSent, self_updates=$shadowSelfUpdates, drift_samples=$shadowDriftSamples, errors=$shadowErrors",
  "- Summary: telemetry/shadow-authority-summary.json",
  "- Runbook: raw/operator-runbook.md"
) | Set-Content -Encoding UTF8 $commandSummaryPath
