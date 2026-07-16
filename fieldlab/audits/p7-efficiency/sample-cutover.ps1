[CmdletBinding()]
param(
  [string] $BaseUrl = "http://127.0.0.1:14000",
  [int] $Seconds = 60,
  [int] $IntervalSeconds = 10,
  [string] $Label = "single-client"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$outDir = Join-Path $root "runs\audits\p7-efficiency"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir "cutover-$Label-$stamp.json"
$samples = [System.Collections.Generic.List[object]]::new()
$deadline = (Get-Date).AddSeconds($Seconds)

while ((Get-Date) -lt $deadline) {
  $captured = (Get-Date).ToUniversalTime().ToString("o")
  try {
    $cutover = Invoke-RestMethod ("$($BaseUrl.TrimEnd('/'))/api/v0/telemetry/cutover") -TimeoutSec 8
    $samples.Add([ordered]@{ capturedUtc = $captured; ok = $true; cutover = $cutover })
  } catch {
    $samples.Add([ordered]@{ capturedUtc = $captured; ok = $false; error = $_.Exception.Message })
  }
  if ((Get-Date).AddSeconds($IntervalSeconds) -lt $deadline) { Start-Sleep -Seconds $IntervalSeconds } else { break }
}

[ordered]@{
  schema = "p7-efficiency-cutover-sample/v1"
  label = $Label
  baseUrl = $BaseUrl
  startedUtc = $samples[0].capturedUtc
  finishedUtc = (Get-Date).ToUniversalTime().ToString("o")
  samples = $samples
} | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outFile -Encoding UTF8

Write-Output $outFile
