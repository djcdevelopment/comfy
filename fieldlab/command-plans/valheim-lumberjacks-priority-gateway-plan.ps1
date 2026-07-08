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

$summaryPath = Join-Path $telemetryDir "priority-gateway-plan-summary.json"
$operatorRunbookPath = Join-Path $rawDir "operator-runbook.md"

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

$gatewayUrl = if ($env:FIELDLAB_LUMBERJACKS_GATEWAY_URL) {
  $env:FIELDLAB_LUMBERJACKS_GATEWAY_URL.TrimEnd("/")
} else {
  "http://localhost:4000"
}

$reliableBudget = if ($env:FIELDLAB_PRIORITY_RELIABLE_BUDGET) {
  [int]$env:FIELDLAB_PRIORITY_RELIABLE_BUDGET
} else {
  256
}

$datagramBudget = if ($env:FIELDLAB_PRIORITY_DATAGRAM_BUDGET) {
  [int]$env:FIELDLAB_PRIORITY_DATAGRAM_BUDGET
} else {
  768
}

$eventLimit = if ($env:FIELDLAB_PRIORITY_EVENT_LIMIT) {
  [int]$env:FIELDLAB_PRIORITY_EVENT_LIMIT
} else {
  500
}

$logDir = Resolve-NetworkSenseLogDir
$priorityMirrorPath = Join-Path $logDir "priority-mirror.jsonl"
$mirrorRows = @(Read-JsonLines $priorityMirrorPath)
$latestStop = @($mirrorRows | Where-Object { [string]$_.event -eq "stop" } | Sort-Object timestamp_utc | Select-Object -Last 1)
$latestStop = if ($latestStop.Count -gt 0) { $latestStop[0] } else { $null }
$manifestId = if ($latestStop) { [string]$latestStop.manifest_id } else { $null }
$sessionId = if ($latestStop) { [string]$latestStop.session_id } else { $null }

$plan = $null
$activation = $null
$planError = $null
$activationError = $null

if ($manifestId) {
  $encodedManifest = [uri]::EscapeDataString($manifestId)
  $planUrl = "$gatewayUrl/valheim/priority-manifests/$encodedManifest/delivery-plan?reliableBudget=$reliableBudget&datagramBudget=$datagramBudget&eventLimit=$eventLimit"
  $activationUrl = "$gatewayUrl/valheim/priority-manifests/$encodedManifest/activate?reliableBudget=$reliableBudget&datagramBudget=$datagramBudget&eventLimit=$eventLimit"

  try {
    $planResponse = Invoke-WebRequest -Uri $planUrl -UseBasicParsing -TimeoutSec 30
    $plan = $planResponse.Content | ConvertFrom-Json
  } catch {
    $planError = $_.Exception.Message
  }

  if ($plan) {
    try {
      $activationResponse = Invoke-WebRequest -Method Post -Uri $activationUrl -UseBasicParsing -TimeoutSec 30
      $activation = $activationResponse.Content | ConvertFrom-Json
    } catch {
      $activationError = $_.Exception.Message
    }
  }
}

$mirrorObjectRecords = if ($latestStop) { [int]$latestStop.object_records } else { 0 }
$mirrorObjectBatchEvents = if ($latestStop) { [int]$latestStop.object_batch_events } else { 0 }
$reliableCount = if ($plan) { @($plan.reliable).Count } else { 0 }
$datagramCount = if ($plan) { @($plan.datagram).Count } else { 0 }
$deferredCount = if ($plan) { @($plan.deferred).Count } else { 0 }
$bucketTotal = $reliableCount + $datagramCount + $deferredCount

$gatewayPlanOk =
  $null -ne $plan -and
  [int]$plan.matched_event_count -eq $mirrorObjectBatchEvents -and
  [int]$plan.total_input_objects -eq $mirrorObjectRecords
$countsMatch =
  $null -ne $plan -and
  [int]$plan.total_input_objects -eq $mirrorObjectRecords
$bucketAccounting =
  $null -ne $plan -and
  $bucketTotal -eq [int]$plan.unique_objects
$activationOk =
  $null -ne $activation -and
  [string]$activation.manifest_id -eq $manifestId -and
  [int]$activation.total_input_objects -eq $mirrorObjectRecords

$gates = @(
  New-Gate -Id "gateway_delivery_plan" -Status ($(if ($gatewayPlanOk) { "pass" } else { "fail" })) -Observed "manifest=$manifestId, matched_events=$($plan.matched_event_count), expected_object_batch_events=$mirrorObjectBatchEvents, total_input_objects=$($plan.total_input_objects), plan_error=$planError."
  New-Gate -Id "manifest_counts_match" -Status ($(if ($countsMatch) { "pass" } else { "fail" })) -Observed "gateway_total_input_objects=$($plan.total_input_objects), mirror_object_records=$mirrorObjectRecords."
  New-Gate -Id "bucket_accounting" -Status ($(if ($bucketAccounting) { "pass" } else { "fail" })) -Observed "reliable=$reliableCount, datagram=$datagramCount, deferred=$deferredCount, bucket_total=$bucketTotal, unique_objects=$($plan.unique_objects)."
  New-Gate -Id "activation" -Status ($(if ($activationOk) { "pass" } else { "fail" })) -Observed "activation_manifest=$($activation.manifest_id), activation_total_input_objects=$($activation.total_input_objects), activation_error=$activationError."
)

$status = if (-not $latestStop) {
  "blocked_no_live_mirror_stop"
} elseif ($gatewayPlanOk -and $countsMatch -and $bucketAccounting -and $activationOk) {
  "pass_priority_gateway_plan"
} elseif ($null -eq $plan) {
  "blocked_gateway_priority_endpoint"
} else {
  "fail_priority_gateway_plan"
}

$phase = if ($status -eq "pass_priority_gateway_plan") {
  "ready_for_socket_delivery"
} else {
  "debug_gateway_priority_plan"
}

$summary = [ordered]@{
  schema_version = 1
  status = $status
  phase = $phase
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  gateway_url = $gatewayUrl
  network_sense_log_dir = $logDir
  manifest_id = $manifestId
  session_id = $sessionId
  budgets = [ordered]@{
    reliable = $reliableBudget
    datagram = $datagramBudget
    event_limit = $eventLimit
  }
  mirror = [ordered]@{
    object_batch_events = $mirrorObjectBatchEvents
    object_records = $mirrorObjectRecords
    posted_failed = if ($latestStop) { [int]$latestStop.posted_failed } else { 0 }
  }
  gateway_plan = [ordered]@{
    available = $null -ne $plan
    plan_error = $planError
    matched_event_count = if ($plan) { [int]$plan.matched_event_count } else { 0 }
    total_input_objects = if ($plan) { [int]$plan.total_input_objects } else { 0 }
    unique_objects = if ($plan) { [int]$plan.unique_objects } else { 0 }
    duplicates_removed = if ($plan) { [int]$plan.duplicates_removed } else { 0 }
    reliable_count = $reliableCount
    datagram_count = $datagramCount
    deferred_count = $deferredCount
  }
  activation = [ordered]@{
    available = $null -ne $activation
    activation_error = $activationError
    manifest_id = if ($activation) { [string]$activation.manifest_id } else { $null }
    total_input_objects = if ($activation) { [int]$activation.total_input_objects } else { 0 }
  }
  gates = $gates
  next_marker_command = if ($status -eq "pass_priority_gateway_plan") {
    "network_sense_mcp_mark lumberjacks_priority_gateway_plan_ready"
  } else {
    "network_sense_mcp_mark lumberjacks_priority_gateway_plan_blocked"
  }
}

Write-JsonFile -Value $summary -Path $summaryPath

@(
  "# Valheim Lumberjacks Priority Gateway Plan",
  "",
  "- Status: $status",
  "- Phase: $phase",
  "- Gateway: $gatewayUrl",
  "- Manifest: $manifestId",
  "- Mirror object batches/records: $mirrorObjectBatchEvents/$mirrorObjectRecords",
  "- Gateway reliable/datagram/deferred: $reliableCount/$datagramCount/$deferredCount",
  "- Next marker: ``$($summary.next_marker_command)``",
  "",
  "## Next",
  "",
  "A pass means Gateway can shape the live EventLog manifest into delivery buckets. The next build should connect this activated plan to socket-level delivery and client observation."
) | Set-Content -Encoding UTF8 $operatorRunbookPath
