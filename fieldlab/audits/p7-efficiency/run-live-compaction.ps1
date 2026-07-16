[CmdletBinding()]
param([string] $BaseUrl = "http://127.0.0.1:14000")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$outDir = Join-Path $root "runs\audits\p7-efficiency"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$before = Invoke-RestMethod "$($BaseUrl.TrimEnd('/'))/api/v0/telemetry/cutover" -TimeoutSec 8
$compact = Invoke-RestMethod -Method Post "$($BaseUrl.TrimEnd('/'))/valheim/zdo-redirect/compact" -TimeoutSec 60
$after = Invoke-RestMethod "$($BaseUrl.TrimEnd('/'))/api/v0/telemetry/cutover" -TimeoutSec 8
[ordered]@{
  schema = "p7-efficiency-live-compaction/v1"
  capturedUtc = (Get-Date).ToUniversalTime().ToString("o")
  baseUrl = $BaseUrl
  before = $before
  compact = $compact
  after = $after
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outDir "live-compaction-$stamp.json") -Encoding UTF8
Write-Output (Join-Path $outDir "live-compaction-$stamp.json")
