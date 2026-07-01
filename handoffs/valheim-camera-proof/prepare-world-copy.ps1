param(
  [string]$WorldName = "ComfyEra16",
  [string]$SourceDir = ".\erasave",
  [string]$WorldsLocal = "$env:USERPROFILE\AppData\LocalLow\IronGate\Valheim\worlds_local"
)

$ErrorActionPreference = "Stop"

$sourceRoot = Resolve-Path -LiteralPath $SourceDir
$db = Join-Path $sourceRoot "$WorldName.db"
$fwl = Join-Path $sourceRoot "$WorldName.fwl"

if (!(Test-Path -LiteralPath $db)) {
  throw "Missing source world db: $db"
}
if (!(Test-Path -LiteralPath $fwl)) {
  throw "Missing source world fwl: $fwl"
}

New-Item -ItemType Directory -Force -Path $WorldsLocal | Out-Null

$destDb = Join-Path $WorldsLocal "$WorldName.db"
$destFwl = Join-Path $WorldsLocal "$WorldName.fwl"

Copy-Item -LiteralPath $db -Destination $destDb -Force
Copy-Item -LiteralPath $fwl -Destination $destFwl -Force

Write-Host "Copied disposable world files:"
Write-Host "  $destDb"
Write-Host "  $destFwl"
Write-Host ""
Write-Host "Next: launch Valheim with -console and load world '$WorldName'."

