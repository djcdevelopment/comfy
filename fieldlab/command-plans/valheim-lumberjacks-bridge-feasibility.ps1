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

$summaryPath = Join-Path $telemetryDir "bridge-feasibility-summary.json"
$surfacePath = Join-Path $telemetryDir "valheim-network-surface.json"
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
  param(
    [Parameter(Mandatory = $true)]
    [string]$Url
  )

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

function Get-ValheimNetworkSurface {
  param([string]$ValheimDir)

  $managed = Join-Path $ValheimDir "valheim_Data\Managed"
  $assemblyPath = Join-Path $managed "assembly_valheim.dll"

  $surface = [ordered]@{
    valheim_dir = $ValheimDir
    assembly_path = $assemblyPath
    assembly_exists = Test-Path $assemblyPath
    inspected = $false
    types = @()
    notes = @(
      "Field inventory only; method reflection against Unity/Mono metadata can crash on some Valheim builds.",
      "Presence of these types supports bridge experiments but does not make ZDO transport replacement safe."
    )
  }

  if (-not (Test-Path $assemblyPath)) {
    return $surface
  }

  $resolver = [ResolveEventHandler]{
    param($sender, $args)
    $name = (New-Object System.Reflection.AssemblyName($args.Name)).Name + ".dll"
    $path = Join-Path $managed $name
    if (Test-Path $path) {
      return [System.Reflection.Assembly]::LoadFrom($path)
    }
    return $null
  }

  [System.AppDomain]::CurrentDomain.add_AssemblyResolve($resolver)
  try {
    $assembly = [System.Reflection.Assembly]::LoadFrom($assemblyPath)
    $typeNames = @("ZNet", "ZDOMan", "ZDO", "ZNetView", "ZRoutedRpc", "ZNetPeer", "ZPackage")
    $types = @()

    foreach ($typeName in $typeNames) {
      try {
        $type = $assembly.GetType($typeName, $false)
        if ($null -eq $type) {
          $types += [ordered]@{ name = $typeName; exists = $false; fields = @(); error = $null }
          continue
        }

        $fields = @($type.GetFields([Reflection.BindingFlags]"Public,NonPublic,Instance,Static,DeclaredOnly") |
          Where-Object { $_.Name -match "m_|instance|owner|zdo|rpc|peer|socket|session|send|queue|objects|position|server|client" } |
          Select-Object -First 40 |
          ForEach-Object {
            [ordered]@{
              name = $_.Name
              field_type = $_.FieldType.Name
              is_public = $_.IsPublic
              is_static = $_.IsStatic
            }
          })

        $types += [ordered]@{ name = $typeName; exists = $true; fields = $fields; error = $null }
      } catch {
        $types += [ordered]@{ name = $typeName; exists = $null; fields = @(); error = $_.Exception.Message }
      }
    }

    $surface.inspected = $true
    $surface.types = $types
  } catch {
    $surface.error = $_.Exception.Message
  } finally {
    [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($resolver)
  }

  return $surface
}

$gatewayWs = if ($env:FIELDLAB_LUMBERJACKS_GATEWAY_WS) { $env:FIELDLAB_LUMBERJACKS_GATEWAY_WS } else { "ws://127.0.0.1:4000" }
$gatewayHttp = $gatewayWs -replace "^ws://", "http://" -replace "^wss://", "https://"
$regionId = if ($env:FIELDLAB_LUMBERJACKS_REGION) { $env:FIELDLAB_LUMBERJACKS_REGION } else { "region-spawn" }
$valheimDir = if ($env:FIELDLAB_VALHEIM_DIR) { $env:FIELDLAB_VALHEIM_DIR } else { "C:\Program Files (x86)\Steam\steamapps\common\Valheim" }
$pluginPath = Join-Path $valheimDir "BepInEx\plugins\ComfyNetworkSense.dll"
$logDir = Resolve-NetworkSenseLogDir
$probeLogPath = Join-Path $logDir "lumberjacks-bridge-probes.jsonl"
$projectionLogPath = Join-Path $logDir "lumberjacks-projection.jsonl"

$health = [ordered]@{
  gateway = Test-HealthEndpoint "$gatewayHttp/health"
  eventlog = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4002") + "/health")
  progression = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4003") + "/health")
  operatorapi = Test-HealthEndpoint (($gatewayHttp -replace ":4000", ":4004") + "/health")
}

$plugin = Get-AssemblyVersionInfo $pluginPath
$processes = @(Get-ValheimProcesses)
$surface = Get-ValheimNetworkSurface $valheimDir
$probeRows = Read-JsonLines $probeLogPath
$latestProbe = @($probeRows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
$latestProbeValue = if ($latestProbe.Count -gt 0) { $latestProbe[0] } else { $null }
$projectionRows = Read-JsonLines $projectionLogPath
$latestProjection = @($projectionRows | Sort-Object timestamp_utc -Descending | Select-Object -First 1)
$latestProjectionValue = if ($latestProjection.Count -gt 0) { $latestProjection[0] } else { $null }

$versionOk = $false
if ($plugin.version) {
  try {
    $versionOk = ([version]$plugin.version) -ge ([version]"0.4.5.0")
  } catch {
    $versionOk = $false
  }
}

$bridgeStatus = if ($latestProbeValue) { [string]$latestProbeValue.status } else { "not_observed" }
$bridgePass = $bridgeStatus -eq "pass_sidecar_protocol"
$projectionStatus = if ($latestProjectionValue) { [string]$latestProjectionValue.status } else { "not_observed" }
$projectionProxyCount = if ($latestProjectionValue -and $null -ne $latestProjectionValue.proxy_count) { [int]$latestProjectionValue.proxy_count } else { 0 }
$projectionEntitiesProjected = if ($latestProjectionValue -and $null -ne $latestProjectionValue.entities_projected) { [int]$latestProjectionValue.entities_projected } else { 0 }
$projectionUpdates = if ($latestProjectionValue -and $null -ne $latestProjectionValue.entity_updates_received) { [int]$latestProjectionValue.entity_updates_received } else { 0 }
$projectionPass = $projectionProxyCount -gt 0 -or $projectionEntitiesProjected -gt 0

$gates = @(
  New-Gate -Id "lumberjacks_runtime" -Status ($(if ($health.gateway.ok) { "pass" } else { "fail" })) -Observed "Gateway health at $gatewayHttp/health: ok=$($health.gateway.ok), status=$($health.gateway.status_code), error=$($health.gateway.error)"
  New-Gate -Id "mod_deployed" -Status ($(if ($versionOk) { "pass" } else { "fail" })) -Observed "ComfyNetworkSense installed version: $($plugin.version)"
  New-Gate -Id "valheim_running" -Status ($(if (@($processes).Count -gt 0) { "pass" } else { "warn" })) -Observed "$(@($processes).Count) Valheim processes visible."
  New-Gate -Id "bridge_protocol" -Status ($(if ($bridgePass) { "pass" } elseif ($latestProbeValue) { "fail" } else { "warn" })) -Observed "Latest bridge probe status: $bridgeStatus"
  New-Gate -Id "local_visual_projection" -Status ($(if ($projectionPass) { "pass" } elseif ($latestProjectionValue) { "warn" } else { "warn" })) -Observed "Latest projection status: $projectionStatus, proxy_count=$projectionProxyCount, entities_projected=$projectionEntitiesProjected, updates=$projectionUpdates"
  New-Gate -Id "authority_scope" -Status "pass" -Observed "Packet scopes side-channel protocol separately from ZDO transport, physics authority, and Steam/PlayFab sockets."
)

$decisionMatrix = @(
  [ordered]@{
    layer = "side_channel_protocol"
    status = if ($bridgePass) { "proven" } else { "ready_to_test" }
    evidence = "network_sense_lumberjacks_probe writes lumberjacks-bridge-probes.jsonl."
    next_gate = "pass_sidecar_protocol from live Valheim process"
  }
  [ordered]@{
    layer = "local_visual_projection"
    status = if ($projectionPass) { "proven_local_only" } else { "implemented_waiting_for_visual_run" }
    evidence = "network_sense_lumberjacks_projection writes lumberjacks-projection.jsonl and renders plain Unity primitives without ZNetView or ZDO ownership."
    next_gate = "Run projection start/status in Valheim and confirm visible local proxy markers."
  }
  [ordered]@{
    layer = "shadow_movement_authority"
    status = "high_risk"
    evidence = "Valheim local player movement remains owned by Valheim; Lumberjacks can only shadow until correction application is proven."
    next_gate = "Compare Lumberjacks authoritative position against Valheim local player movement for drift without applying corrections."
  }
  [ordered]@{
    layer = "valheim_zdo_transport_replacement"
    status = "likely_not_viable_without_invasive_patch"
    evidence = "Valheim assembly exposes ZNet/ZDOMan/ZNetView private state, object dictionaries, peers, RPC routing, send queues, ownership, and sockets."
    next_gate = "Controlled proxy-object ownership/send-queue substitution without breaking save/load or peer sync."
  }
  [ordered]@{
    layer = "valheim_dedicated_server_on_lumberjacks"
    status = "not_viable_as_worded"
    evidence = "Lumberjacks can host a native runtime; Valheim dedicated server remains a closed Unity runtime with its own save, ZDO, physics, and socket stack."
    next_gate = "Rephrase as bridge/adapter or native reimplementation, not Valheim server replacement."
  }
)

$summaryStatus = if ($bridgePass) {
  if ($projectionPass) { "pass_local_visual_projection" } else { "pass_sidecar_protocol" }
} elseif ($health.gateway.ok -and $versionOk) {
  "staged_waiting_for_valheim_probe"
} else {
  "blocked_setup"
}

$summary = [ordered]@{
  schema_version = 1
  status = $summaryStatus
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  gateway_ws = $gatewayWs
  gateway_http = $gatewayHttp
  region_id = $regionId
  network_sense_log_dir = $logDir
  probe_log_path = $probeLogPath
  projection_log_path = $projectionLogPath
  health = $health
  plugin = $plugin
  valheim_processes = $processes
  valheim_process_count = @($processes).Count
  bridge_probe = [ordered]@{
    observed_rows = @($probeRows).Count
    latest = $latestProbeValue
  }
  projection = [ordered]@{
    observed_rows = @($projectionRows).Count
    latest = $latestProjectionValue
    pass = $projectionPass
  }
  gates = $gates
  decision_matrix = $decisionMatrix
  console_command = "network_sense_lumberjacks_probe $gatewayWs $regionId 12"
  projection_command = "network_sense_lumberjacks_projection start $gatewayWs $regionId"
  claims_not_proven = @(
    "Valheim ZDO transport replacement",
    "Valheim physics authority replacement",
    "Steam/PlayFab socket replacement",
    "Valheim dedicated server running on Lumberjacks"
  )
}

Write-JsonFile -Value $surface -Path $surfacePath
Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Lumberjacks Bridge Feasibility",
  "",
  "## Current Status",
  "",
  "- Summary status: $summaryStatus",
  "- Gateway: $gatewayWs",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense: $($plugin.version)",
  "- Valheim processes visible: $(@($processes).Count)",
  "- Latest bridge probe: $bridgeStatus",
  "- Latest projection: $projectionStatus, proxy_count=$projectionProxyCount, entities_projected=$projectionEntitiesProjected, updates=$projectionUpdates",
  "",
  "## Run In Valheim",
  "",
  "Restart Valheim after installing ComfyNetworkSense 0.4.5, open the console, then run:",
  "",
  '```text',
  "network_sense_lumberjacks_probe $gatewayWs $regionId 12",
  "network_sense_lumberjacks_projection start $gatewayWs $regionId",
  "network_sense_lumberjacks_projection status",
  "network_sense_lumberjacks_projection stop",
  '```',
  "",
  "Then rerun this scenario:",
  "",
  '```powershell',
  ".\fieldlab\scripts\run-experiment.ps1 .\fieldlab\scenarios\valheim-lumberjacks-bridge-feasibility.yaml",
  '```',
  "",
  "## What Pass Means",
  "",
  "pass_sidecar_protocol means the live Valheim plugin process can speak the Lumberjacks Gateway protocol as a side-channel client. pass_local_visual_projection additionally means local-only proxy markers were populated from Lumberjacks rows. Neither status means Valheim ZDO replication, physics authority, or sockets have been replaced.",
  "",
  "## Next Spike",
  "",
  "$(if ($projectionPass) { 'Move to shadow movement authority: compare Lumberjacks authoritative position against Valheim local motion without applying corrections.' } else { 'Run the projection command above and confirm visible local proxy markers before moving to shadow movement authority.' })"
) | Set-Content -Encoding UTF8 $runbookPath

@(
  "network_sense_lumberjacks_probe $gatewayWs $regionId 12",
  "network_sense_lumberjacks_projection start $gatewayWs $regionId",
  "network_sense_lumberjacks_projection status",
  "network_sense_lumberjacks_projection stop",
  "network_sense_mcp_mark lumberjacks_bridge_probe_ran"
) | Set-Content -Encoding UTF8 $commandsPath

@(
  "# Command Plan Summary",
  "",
  "- Status: $summaryStatus",
  "- Gateway health: ok=$($health.gateway.ok), status=$($health.gateway.status_code)",
  "- Installed ComfyNetworkSense version: $($plugin.version)",
  "- Latest bridge probe status: $bridgeStatus",
  "- Latest projection status: $projectionStatus, proxy_count=$projectionProxyCount, entities_projected=$projectionEntitiesProjected, updates=$projectionUpdates",
  "- Summary: telemetry/bridge-feasibility-summary.json",
  "- Valheim surface: telemetry/valheim-network-surface.json",
  "- Runbook: raw/operator-runbook.md"
) | Set-Content -Encoding UTF8 $commandSummaryPath
