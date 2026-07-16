[CmdletBinding()]
param(
  [string] $FieldlabRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
  [string] $SshTarget = "comfy-p7",
  [switch] $IncludeRemote,
  [switch] $RequireRemote
)

$ErrorActionPreference = "Stop"
$stamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$outDir = Join-Path $FieldlabRoot "runs\audits\p7-efficiency"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$outFile = Join-Path $outDir "manifest-$stamp.json"

function Git-Value([string] $Path, [string[]] $GitArgs) {
  $v = (& git -C $Path @GitArgs 2>$null | Out-String).Trim()
  if ($LASTEXITCODE -ne 0) { return $null }
  return $v
}

function Hash-IfPresent([string] $Path) {
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

$comfyRoot = "C:\work\comfy"
$lumberRoot = "C:\work\lumberjacks"
$manifest = [ordered]@{
  schema = "p7-efficiency-audit/v1"
  capturedUtc = $stamp
  host = [ordered]@{ computer = $env:COMPUTERNAME; user = $env:USERNAME; os = (Get-CimInstance Win32_OperatingSystem).Caption }
  fieldlab = [ordered]@{
    root = $FieldlabRoot
    git = [ordered]@{ sha = (Git-Value $FieldlabRoot @("rev-parse","HEAD")); dirty = [bool](Git-Value $FieldlabRoot @("status","--porcelain")) }
  }
  comfy = [ordered]@{
    root = $comfyRoot
    git = [ordered]@{ sha = (Git-Value $comfyRoot @("rev-parse","HEAD")); dirty = [bool](Git-Value $comfyRoot @("status","--porcelain")) }
    p7Scripts = Get-ChildItem -LiteralPath "$comfyRoot\infra\gcp\p7\scripts" -File -ErrorAction SilentlyContinue | ForEach-Object {
      [ordered]@{ name = $_.Name; sha256 = Hash-IfPresent $_.FullName; length = $_.Length }
    }
  }
  lumberjacks = [ordered]@{
    root = $lumberRoot
    git = [ordered]@{ sha = (Git-Value $lumberRoot @("rev-parse","HEAD")); dirty = [bool](Git-Value $lumberRoot @("status","--porcelain")) }
  }
  localArtifacts = Get-ChildItem -LiteralPath (Join-Path $FieldlabRoot "evidence") -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
    [ordered]@{ path = $_.FullName.Substring($FieldlabRoot.Length).TrimStart('\'); length = $_.Length; lastWriteUtc = $_.LastWriteTimeUtc.ToString("o") }
  }
}

if ($IncludeRemote) {
  $previousPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $remoteCommand = @'
hostname
date -u +%FT%TZ
sudo docker ps --format '{{json .}}' | jq -s .
printf '\nWAL_BYTES\n'
sudo find /mnt/comfy-p7/lumberjacks/zdo-queue -maxdepth 1 -type f -printf '%p %s %TY-%Tm-%TdT%TH:%TM:%TSZ\n' 2>/dev/null
'@
  $remoteLines = @(& ssh $SshTarget $remoteCommand)
  $remoteExit = $LASTEXITCODE
  $ErrorActionPreference = $previousPreference
  $remoteRaw = ($remoteLines -join "`n").Trim()
  $hostLine = @($remoteLines | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' } | Select-Object -First 1)
  $jsonStart = $remoteRaw.IndexOf('[')
  $jsonEnd = $remoteRaw.LastIndexOf(']')
  $remoteRecord = [ordered]@{ target = $SshTarget; exitCode = $remoteExit; rawTail = $remoteRaw.Substring([Math]::Max(0, $remoteRaw.Length - 2000)) }
  if ($hostLine.Count -gt 0) { $remoteRecord.host = $hostLine[0] }
  if ($jsonStart -ge 0 -and $jsonEnd -gt $jsonStart) {
    try { $remoteRecord.containers = $remoteRaw.Substring($jsonStart, $jsonEnd - $jsonStart + 1) | ConvertFrom-Json } catch { }
  }
  if ($remoteRecord.host) { $manifest.remote = $remoteRecord }
  elseif ($RequireRemote) { throw "Remote provenance collection failed for $SshTarget`n$remoteRaw" }
  else { $manifest.remoteError = $remoteRaw }
}

$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $outFile -Encoding UTF8
Write-Output $outFile
