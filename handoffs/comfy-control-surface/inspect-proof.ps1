param(
  [string]$ValheimDir = "C:\Program Files (x86)\Steam\steamapps\common\Valheim"
)

$ErrorActionPreference = "Stop"

$root = Join-Path $ValheimDir "BepInEx\config\comfy-control"
$status = Join-Path $root "status"
$outbox = Join-Path $root "outbox"
$evidence = Join-Path $root "evidence"
$traces = Join-Path $root "traces"

if (!(Test-Path -LiteralPath $root)) {
  throw "Comfy control root was not found: $root"
}

Write-Host "Comfy control root:"
Write-Host "  $root"
Write-Host ""

$pluginStatus = Join-Path $status "plugin-status.json"
if (Test-Path -LiteralPath $pluginStatus) {
  Write-Host "plugin-status.json:"
  Get-Content -LiteralPath $pluginStatus
  Write-Host ""
} else {
  Write-Host "missing plugin-status.json"
  Write-Host ""
}

$lastSubmission = Join-Path $status "last-submission.json"
if (Test-Path -LiteralPath $lastSubmission) {
  Write-Host "last-submission.json:"
  Get-Content -LiteralPath $lastSubmission
  Write-Host ""
}

$lastError = Join-Path $status "last-error.json"
if (Test-Path -LiteralPath $lastError) {
  Write-Host "last-error.json:"
  Get-Content -LiteralPath $lastError
  Write-Host ""
}

$latestPayload = Get-ChildItem -LiteralPath $outbox -Filter *.json -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($latestPayload) {
  Write-Host "latest outbox payload:"
  Write-Host "  $($latestPayload.FullName)"
  Get-Content -LiteralPath $latestPayload.FullName
  Write-Host ""
} else {
  Write-Host "no outbox payloads yet"
  Write-Host ""
}

$latestEvidence = Get-ChildItem -LiteralPath $evidence -Filter *.png -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($latestEvidence) {
  Write-Host "latest evidence:"
  Write-Host "  $($latestEvidence.FullName)"
  Write-Host "  $($latestEvidence.Length) bytes"
  Write-Host ""
} else {
  Write-Host "no evidence screenshots yet"
  Write-Host ""
}

$latestTrace = Get-ChildItem -LiteralPath $traces -Filter *.trace.jsonl -ErrorAction SilentlyContinue |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($latestTrace) {
  Write-Host "latest trace:"
  Write-Host "  $($latestTrace.FullName)"
  Get-Content -LiteralPath $latestTrace.FullName
} else {
  Write-Host "no traces found"
}
