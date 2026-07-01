param(
  [string]$ValheimDir = "C:\Program Files (x86)\Steam\steamapps\common\Valheim",
  [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$project = Join-Path $PSScriptRoot "ComfyCameraProof.csproj"
$plugins = Join-Path $ValheimDir "BepInEx\plugins"
$bepinex = Join-Path $ValheimDir "BepInEx\core\BepInEx.dll"

if (!(Test-Path -LiteralPath $bepinex)) {
  throw "BepInEx is not installed at '$ValheimDir'. Install BepInExPack Valheim and launch once."
}
$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
if (!$dotnet -and (Test-Path -LiteralPath "C:\Program Files\dotnet\dotnet.exe")) {
  $dotnet = "C:\Program Files\dotnet\dotnet.exe"
}
if (!$dotnet) {
  throw "dotnet is not on PATH. Install .NET SDK / Build Tools or build ComfyCameraProof.csproj in an IDE."
}

& $dotnet build $project -c $Configuration -p:ValheimDir="$ValheimDir"

$dll = Join-Path $PSScriptRoot "bin\$Configuration\net472\ComfyCameraProof.dll"
if (!(Test-Path -LiteralPath $dll)) {
  throw "Build completed but DLL was not found: $dll"
}

New-Item -ItemType Directory -Force -Path $plugins | Out-Null
Copy-Item -LiteralPath $dll -Destination (Join-Path $plugins "ComfyCameraProof.dll") -Force

Write-Host "Installed ComfyCameraProof.dll to:"
Write-Host "  $plugins"
Write-Host ""
Write-Host "Next: copy waypoints.json to BepInEx\config\waypoints.json, enter the world, press F8 then F9."
