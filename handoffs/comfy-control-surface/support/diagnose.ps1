[CmdletBinding()]
param(
  [string]$ValheimDir = "C:\Program Files (x86)\Steam\steamapps\common\Valheim",
  [string]$ControlRoot = "",
  [string]$OutputDir = $PSScriptRoot,
  [string]$Configuration = "Release",
  [int]$LogTail = 40
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($ControlRoot)) {
  $ControlRoot = Join-Path $ValheimDir "BepInEx\config\comfy-control"
}

function Write-Step {
  param([string]$Message)
  Write-Verbose $Message
}

function Test-LiteralPath {
  param([string]$Path)
  return (![string]::IsNullOrWhiteSpace($Path) -and (Test-Path -LiteralPath $Path))
}

function Get-FileSummary {
  param([string]$Path)

  if (!(Test-LiteralPath $Path)) {
    return [ordered]@{
      exists = $false
      path = $Path
    }
  }

  $item = Get-Item -LiteralPath $Path
  return [ordered]@{
    exists = $true
    path = $item.FullName
    bytes = $item.Length
    last_write_time_utc = $item.LastWriteTimeUtc.ToString("o")
  }
}

function Get-DirectorySummary {
  param(
    [string]$Path,
    [string]$Filter = "*"
  )

  if (!(Test-LiteralPath $Path)) {
    return [ordered]@{
      exists = $false
      path = $Path
      count = 0
    }
  }

  $items = @(Get-ChildItem -LiteralPath $Path -Filter $Filter -File -ErrorAction SilentlyContinue)
  return [ordered]@{
    exists = $true
    path = (Get-Item -LiteralPath $Path).FullName
    filter = $Filter
    count = $items.Count
  }
}

function Get-LatestFile {
  param(
    [string]$Path,
    [string]$Filter = "*"
  )

  if (!(Test-LiteralPath $Path)) {
    return $null
  }

  return Get-ChildItem -LiteralPath $Path -Filter $Filter -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
}

function ConvertTo-PlainValue {
  param($Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [string] -or $Value -is [bool] -or $Value -is [char] -or $Value -is [byte] -or
      $Value -is [int16] -or $Value -is [int] -or $Value -is [int64] -or
      $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or
      $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
    return $Value
  }

  if ($Value -is [datetime]) {
    return $Value.ToUniversalTime().ToString("o")
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $plain = [ordered]@{}
    foreach ($key in $Value.Keys) {
      $plain[$key] = ConvertTo-PlainValue $Value[$key]
    }
    return $plain
  }

  if ($Value -is [System.Collections.IEnumerable]) {
    $items = @()
    foreach ($item in $Value) {
      $items += ConvertTo-PlainValue $item
    }
    return ,$items
  }

  $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" })
  if ($properties.Count -gt 0) {
    $plain = [ordered]@{}
    foreach ($property in $properties) {
      $plain[$property.Name] = ConvertTo-PlainValue $property.Value
    }
    return $plain
  }

  return [string]$Value
}

function ConvertTo-SimpleJsonString {
  param([string]$Value)

  $escaped = $Value.Replace('\', '\\').
    Replace('"', '\"').
    Replace("`b", '\b').
    Replace("`f", '\f').
    Replace("`n", '\n').
    Replace("`r", '\r').
    Replace("`t", '\t')

  return '"' + $escaped + '"'
}

function ConvertTo-SimpleJson {
  param($Value)

  if ($null -eq $Value) {
    return "null"
  }

  if ($Value -is [string] -or $Value -is [char]) {
    return ConvertTo-SimpleJsonString ([string]$Value)
  }

  if ($Value -is [bool]) {
    if ($Value) {
      return "true"
    }
    return "false"
  }

  if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int] -or $Value -is [int64] -or
      $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or $Value -is [decimal]) {
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
  }

  if ($Value -is [single]) {
    if ([single]::IsNaN($Value) -or [single]::IsInfinity($Value)) {
      return "null"
    }
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
  }

  if ($Value -is [double]) {
    if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) {
      return "null"
    }
    return [Convert]::ToString($Value, [Globalization.CultureInfo]::InvariantCulture)
  }

  if ($Value -is [datetime]) {
    return ConvertTo-SimpleJsonString $Value.ToUniversalTime().ToString("o")
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $parts = @()
    foreach ($key in $Value.Keys) {
      $parts += (ConvertTo-SimpleJsonString ([string]$key)) + ":" + (ConvertTo-SimpleJson $Value[$key])
    }
    return "{" + ($parts -join ",") + "}"
  }

  if ($Value -is [System.Collections.IEnumerable]) {
    $parts = @()
    foreach ($item in $Value) {
      $parts += ConvertTo-SimpleJson $item
    }
    return "[" + ($parts -join ",") + "]"
  }

  $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -eq "NoteProperty" })
  if ($properties.Count -gt 0) {
    $plain = [ordered]@{}
    foreach ($property in $properties) {
      $plain[$property.Name] = $property.Value
    }
    return ConvertTo-SimpleJson $plain
  }

  return ConvertTo-SimpleJsonString ([string]$Value)
}

function Read-JsonFile {
  param([string]$Path)

  if (!(Test-LiteralPath $Path)) {
    return [ordered]@{
      exists = $false
      path = $Path
      data = $null
      error = $null
    }
  }

  try {
    $raw = Get-Content -LiteralPath $Path -Raw
    $parsed = $raw | ConvertFrom-Json
    return [ordered]@{
      exists = $true
      path = (Get-Item -LiteralPath $Path).FullName
      data = ConvertTo-PlainValue $parsed
      error = $null
    }
  } catch {
    return [ordered]@{
      exists = $true
      path = (Get-Item -LiteralPath $Path).FullName
      data = $null
      error = $_.Exception.Message
    }
  }
}

function Get-TextTail {
  param(
    [string]$Path,
    [int]$Tail = 20
  )

  if (!(Test-LiteralPath $Path)) {
    return @()
  }

  return @(Get-Content -LiteralPath $Path -Tail $Tail)
}

function Get-AssemblyVersion {
  param([string]$Path)

  if (!(Test-LiteralPath $Path)) {
    return $null
  }

  try {
    return [System.Reflection.AssemblyName]::GetAssemblyName($Path).Version.ToString()
  } catch {
    return $null
  }
}

function Get-ZipContents {
  param([string]$Path)

  if (!(Test-LiteralPath $Path)) {
    return @()
  }

  try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
      return @($zip.Entries | Sort-Object FullName | ForEach-Object {
        [ordered]@{
          path = $_.FullName
          bytes = $_.Length
        }
      })
    } finally {
      $zip.Dispose()
    }
  } catch {
    return @([ordered]@{
      path = $Path
      error = $_.Exception.Message
    })
  }
}

function Get-MatchingLogLines {
  param(
    [string]$Path,
    [string]$Pattern,
    [int]$Tail = 40
  )

  if (!(Test-LiteralPath $Path)) {
    return @()
  }

  return @(Select-String -LiteralPath $Path -Pattern $Pattern -SimpleMatch:$false |
    Select-Object -Last $Tail |
    ForEach-Object { "L$($_.LineNumber): $($_.Line)" })
}

function Add-Finding {
  param(
    [System.Collections.ArrayList]$Findings,
    [string]$Severity,
    [string]$Message
  )

  [void]$Findings.Add([ordered]@{
    severity = $Severity
    message = $Message
  })
}

$bepInExDir = Join-Path $ValheimDir "BepInEx"
$bepInExCore = Join-Path $bepInExDir "core\BepInEx.dll"
$pluginsDir = Join-Path $bepInExDir "plugins"
$installedPlugin = Join-Path $pluginsDir "ComfyControlSurface.dll"
$bepInExLog = Join-Path $bepInExDir "LogOutput.log"

$actionsJson = Join-Path $ControlRoot "actions.json"
$statusDir = Join-Path $ControlRoot "status"
$outboxDir = Join-Path $ControlRoot "outbox"
$evidenceDir = Join-Path $ControlRoot "evidence"
$tracesDir = Join-Path $ControlRoot "traces"
$receiptsDir = Join-Path $ControlRoot "receipts"
$bridgeReviewDir = Join-Path $ControlRoot "bridge-review"

$pluginStatusPath = Join-Path $statusDir "plugin-status.json"
$lastSubmissionPath = Join-Path $statusDir "last-submission.json"
$lastReceiptPath = Join-Path $statusDir "last-receipt.json"
$lastErrorPath = Join-Path $statusDir "last-error.json"

Write-Step "Finding latest artifacts."
$latestStartupTrace = Get-LatestFile $tracesDir "plugin-*.trace.jsonl"
$latestOutboxPayload = Get-LatestFile $outboxDir "*.json"
$latestEvidence = Get-LatestFile $evidenceDir "*.png"
$latestReceipt = Get-LatestFile $receiptsDir "*.json"
$latestBridgeReview = Get-LatestFile $bridgeReviewDir "*.md"
$latestPackage = Get-LatestFile (Join-Path $projectRoot "bin\$Configuration") "*.zip"

Write-Step "Reading status JSON."
$pluginStatus = Read-JsonFile $pluginStatusPath
$actionsConfig = Read-JsonFile $actionsJson
$lastSubmission = Read-JsonFile $lastSubmissionPath
$lastReceipt = Read-JsonFile $lastReceiptPath
$lastError = Read-JsonFile $lastErrorPath
$latestPayloadJson = $null
if ($latestOutboxPayload) {
  $latestPayloadJson = Read-JsonFile $latestOutboxPayload.FullName
}

$findings = [System.Collections.ArrayList]::new()

Write-Step "Evaluating findings."
if (!(Test-LiteralPath $ValheimDir)) {
  Add-Finding $findings "error" "Valheim install was not found."
}
if (!(Test-LiteralPath $bepInExCore)) {
  Add-Finding $findings "error" "BepInEx core DLL was not found."
}
if (!(Test-LiteralPath $installedPlugin)) {
  Add-Finding $findings "error" "ComfyControlSurface.dll is not installed in BepInEx/plugins."
}
if (!(Test-LiteralPath $ControlRoot)) {
  Add-Finding $findings "warning" "comfy-control workbench root was not found."
}
if (!(Test-LiteralPath $actionsJson)) {
  Add-Finding $findings "warning" "actions.json was not found."
}
if (!$pluginStatus.exists) {
  Add-Finding $findings "warning" "plugin-status.json was not found; the plugin may not have loaded yet."
} elseif ($pluginStatus.error) {
  Add-Finding $findings "warning" "plugin-status.json exists but could not be parsed."
} elseif ($pluginStatus.data.actions_loaded -eq $false) {
  Add-Finding $findings "error" "actions.json failed to load according to plugin-status.json."
}
if ($actionsConfig.exists -and !$actionsConfig.error -and $pluginStatus.exists -and !$pluginStatus.error) {
  $configuredActionCount = @($actionsConfig.data.actions).Count
  if ($null -ne $pluginStatus.data.action_count -and $configuredActionCount -ne $pluginStatus.data.action_count) {
    Add-Finding $findings "warning" "actions.json has $configuredActionCount action(s), but plugin-status.json reports $($pluginStatus.data.action_count). Reload the plugin/actions."
  }
}
if ($lastError.exists) {
  Add-Finding $findings "warning" "last-error.json exists."
}
if (!$latestStartupTrace) {
  Add-Finding $findings "warning" "No startup trace was found."
}
if (!$latestPackage) {
  Add-Finding $findings "warning" "No generated package zip was found."
}

$installedPluginSummary = Get-FileSummary $installedPlugin
$localDll = Join-Path $projectRoot "bin\$Configuration\ComfyControlSurface.dll"
$manifest = Read-JsonFile (Join-Path $projectRoot "manifest.json")

Write-Step "Building report object."
$report = [ordered]@{
  generated_at_utc = (Get-Date).ToUniversalTime().ToString("o")
  inputs = [ordered]@{
    valheim_dir = $ValheimDir
    control_root = $ControlRoot
    project_root = $projectRoot
    configuration = $Configuration
  }
  environment = [ordered]@{
    valheim = [ordered]@{
      exists = Test-LiteralPath $ValheimDir
      path = $ValheimDir
    }
    bepinex = [ordered]@{
      exists = Test-LiteralPath $bepInExCore
      core_dll = $bepInExCore
      directory = $bepInExDir
    }
    installed_plugin = $installedPluginSummary
    installed_plugin_version = Get-AssemblyVersion $installedPlugin
    local_build = Get-FileSummary $localDll
    local_build_version = Get-AssemblyVersion $localDll
    manifest = $manifest
  }
  workbench = [ordered]@{
    root = [ordered]@{
      exists = Test-LiteralPath $ControlRoot
      path = $ControlRoot
    }
    actions_json = Get-FileSummary $actionsJson
    actions_config = $actionsConfig
    plugin_status = $pluginStatus
    last_submission = $lastSubmission
    last_receipt = $lastReceipt
    last_error = $lastError
  }
  artifacts = [ordered]@{
    outbox = Get-DirectorySummary $outboxDir "*.json"
    evidence = Get-DirectorySummary $evidenceDir "*.png"
    traces = Get-DirectorySummary $tracesDir "*.trace.jsonl"
    receipts = Get-DirectorySummary $receiptsDir "*.json"
    bridge_review = Get-DirectorySummary $bridgeReviewDir "*.md"
    latest_outbox_payload = if ($latestOutboxPayload) { Get-FileSummary $latestOutboxPayload.FullName } else { $null }
    latest_outbox_payload_json = $latestPayloadJson
    latest_evidence = if ($latestEvidence) { Get-FileSummary $latestEvidence.FullName } else { $null }
    latest_receipt = if ($latestReceipt) { Get-FileSummary $latestReceipt.FullName } else { $null }
    latest_startup_trace = if ($latestStartupTrace) { Get-FileSummary $latestStartupTrace.FullName } else { $null }
    latest_startup_trace_tail = if ($latestStartupTrace) { Get-TextTail $latestStartupTrace.FullName 30 } else { @() }
    latest_bridge_review = if ($latestBridgeReview) { Get-FileSummary $latestBridgeReview.FullName } else { $null }
  }
  logs = [ordered]@{
    bepinex_log = Get-FileSummary $bepInExLog
    comfy_control_lines = Get-MatchingLogLines $bepInExLog "ComfyControlSurface|Comfy control surface" $LogTail
  }
  package = [ordered]@{
    latest_zip = if ($latestPackage) { Get-FileSummary $latestPackage.FullName } else { $null }
    contents = if ($latestPackage) { Get-ZipContents $latestPackage.FullName } else { @() }
  }
  findings = @($findings)
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$jsonPath = Join-Path $OutputDir "support-report.json"
$mdPath = Join-Path $OutputDir "support-report.md"

Write-Step "Writing JSON report."
ConvertTo-SimpleJson $report | Set-Content -LiteralPath $jsonPath -Encoding UTF8

Write-Step "Writing Markdown report."
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("# ComfyControlSurface support report")
$lines.Add("")
$lines.Add("- Generated UTC: $($report.generated_at_utc)")
$lines.Add("- Valheim: $ValheimDir")
$lines.Add("- Control root: $ControlRoot")
$lines.Add("")
$lines.Add("## Findings")
if ($findings.Count -eq 0) {
  $lines.Add("")
  $lines.Add("No blocking findings detected.")
} else {
  $lines.Add("")
  foreach ($finding in $findings) {
    $lines.Add("- $($finding.severity): $($finding.message)")
  }
}

$lines.Add("")
$lines.Add("## Install")
$lines.Add("")
$lines.Add("| Check | Result | Detail |")
$lines.Add("| --- | --- | --- |")
$lines.Add("| Valheim install | $(if ($report.environment.valheim.exists) { 'ok' } else { 'missing' }) | $ValheimDir |")
$lines.Add("| BepInEx | $(if ($report.environment.bepinex.exists) { 'ok' } else { 'missing' }) | $bepInExCore |")
$lines.Add("| Plugin DLL | $(if ($installedPluginSummary.exists) { 'ok' } else { 'missing' }) | $installedPlugin |")
$lines.Add("| Plugin version | $(if ($report.environment.installed_plugin_version) { $report.environment.installed_plugin_version } else { 'unknown' }) | installed assembly |")
$lines.Add("| Local build | $(if ($report.environment.local_build.exists) { 'ok' } else { 'missing' }) | $localDll |")

$lines.Add("")
$lines.Add("## Workbench")
$lines.Add("")
$lines.Add("| Check | Result | Detail |")
$lines.Add("| --- | --- | --- |")
$lines.Add("| Control root | $(if ($report.workbench.root.exists) { 'ok' } else { 'missing' }) | $ControlRoot |")
$lines.Add("| actions.json | $(if ($report.workbench.actions_json.exists) { 'ok' } else { 'missing' }) | $actionsJson |")
if ($actionsConfig.exists -and !$actionsConfig.error) {
  $lines.Add("| configured actions | $(@($actionsConfig.data.actions).Count) | actions.json |")
}
$lines.Add("| plugin-status.json | $(if ($pluginStatus.exists) { 'ok' } else { 'missing' }) | $pluginStatusPath |")
if ($pluginStatus.exists -and !$pluginStatus.error -and $pluginStatus.data) {
  $lines.Add("| actions loaded | $($pluginStatus.data.actions_loaded) | action_count=$($pluginStatus.data.action_count); error=$($pluginStatus.data.error) |")
}

$lines.Add("")
$lines.Add("## Latest Artifacts")
$lines.Add("")
$lines.Add("| Artifact | Count | Latest |")
$lines.Add("| --- | ---: | --- |")
$latestOutboxText = if ($latestOutboxPayload) { $latestOutboxPayload.FullName } else { "none" }
$latestEvidenceText = if ($latestEvidence) { $latestEvidence.FullName } else { "none" }
$latestReceiptText = if ($latestReceipt) { $latestReceipt.FullName } else { "none" }
$latestTraceText = if ($latestStartupTrace) { $latestStartupTrace.FullName } else { "none" }
$latestReviewText = if ($latestBridgeReview) { $latestBridgeReview.FullName } else { "none" }
$lines.Add("| outbox json | $($report.artifacts.outbox.count) | $latestOutboxText |")
$lines.Add("| evidence png | $($report.artifacts.evidence.count) | $latestEvidenceText |")
$lines.Add("| receipt json | $($report.artifacts.receipts.count) | $latestReceiptText |")
$lines.Add("| startup traces | $($report.artifacts.traces.count) | $latestTraceText |")
$lines.Add("| bridge reviews | $($report.artifacts.bridge_review.count) | $latestReviewText |")

if ($lastSubmission.exists -and !$lastSubmission.error) {
  $lines.Add("")
  $lines.Add("## Last Submission")
  $lines.Add("")
  $lines.Add('```json')
  $lines.Add((ConvertTo-SimpleJson $lastSubmission.data))
  $lines.Add('```')
}

if ($lastError.exists -and !$lastError.error) {
  $lines.Add("")
  $lines.Add("## Last Error")
  $lines.Add("")
  $lines.Add('```json')
  $lines.Add((ConvertTo-SimpleJson $lastError.data))
  $lines.Add('```')
}

$lines.Add("")
$lines.Add("## BepInEx Log")
$lines.Add("")
if ($report.logs.comfy_control_lines.Count -eq 0) {
  $lines.Add("No matching ComfyControlSurface log lines found.")
} else {
  $lines.Add('```text')
  foreach ($line in $report.logs.comfy_control_lines) {
    $lines.Add($line)
  }
  $lines.Add('```')
}

$lines.Add("")
$lines.Add("## Package")
$lines.Add("")
if ($latestPackage) {
  $lines.Add("- Zip: $($latestPackage.FullName)")
  $lines.Add("")
  $lines.Add('```text')
  foreach ($entry in $report.package.contents) {
    if ($entry.error) {
      $lines.Add("ERROR: $($entry.error)")
    } else {
      $lines.Add("$($entry.path) ($($entry.bytes) bytes)")
    }
  }
  $lines.Add('```')
} else {
  $lines.Add("No package zip found under bin/$Configuration.")
}

$lines | Set-Content -LiteralPath $mdPath -Encoding UTF8

Write-Host "Wrote support diagnostics:"
Write-Host "  $mdPath"
Write-Host "  $jsonPath"
