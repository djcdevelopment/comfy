[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "dist")
)

$ErrorActionPreference = "Stop"

$repoRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$manifestPath = Join-Path $repoRoot "manifest.json"
$manifest = Get-Content -Raw -Encoding UTF8 -LiteralPath $manifestPath | ConvertFrom-Json
$version = [string]$manifest.version
$packageName = "discord-search-exporter-private-v$version"
$packageTimestamp = [DateTime]::Parse(
    "2026-07-29T00:00:00Z",
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::AdjustToUniversal
)

$outputRoot = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$zipPath = [IO.Path]::GetFullPath((Join-Path $outputRoot "$packageName.zip"))
$zipHashPath = [IO.Path]::GetFullPath((Join-Path $outputRoot "$packageName.zip.sha256"))
$outputPrefix = $outputRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $zipPath.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase) -or
    -not $zipHashPath.StartsWith($outputPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved package outputs escaped the intended output directory."
}

$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stageParent = [IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot ("dse-package-" + [Guid]::NewGuid().ToString("N")))
)
$temporaryPrefix = $temporaryRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $stageParent.StartsWith($temporaryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Resolved staging directory escaped the system temporary directory."
}
$stageRoot = Join-Path $stageParent $packageName
$extensionRoot = Join-Path $stageRoot "extension"

$packageFiles = @(
    @{ Source = "START-HERE.html"; Destination = "START-HERE.html" },
    @{ Source = "PRIVATE-USE-NOTICE.txt"; Destination = "PRIVATE-USE-NOTICE.txt" },
    @{ Source = "README.md"; Destination = "extension\README.md" },
    @{ Source = "manifest.json"; Destination = "extension\manifest.json" },
    @{ Source = "content.js"; Destination = "extension\content.js" }
)

try {
    New-Item -ItemType Directory -Force -Path $extensionRoot | Out-Null

    foreach ($item in $packageFiles) {
        $sourcePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $item.Source))
        $destinationPath = [IO.Path]::GetFullPath((Join-Path $stageRoot $item.Destination))
        $repoPrefix = $repoRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        $stagePrefix = $stageRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if (-not $sourcePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Package source escaped the repository: $sourcePath"
        }
        if (-not $destinationPath.StartsWith($stagePrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Package destination escaped the staging directory: $destinationPath"
        }
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Required package source is missing: $sourcePath"
        }
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath
    }

    $hashLines = Get-ChildItem -LiteralPath $stageRoot -File -Recurse |
        Sort-Object FullName |
        ForEach-Object {
            $relativePath = $_.FullName.Substring($stageRoot.Length + 1).Replace("\", "/")
            $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            "$hash  $relativePath"
        }
    $utf8NoBom = [Text.UTF8Encoding]::new($false)
    [IO.File]::WriteAllLines((Join-Path $stageRoot "SHA256SUMS.txt"), $hashLines, $utf8NoBom)
    Get-ChildItem -LiteralPath $stageRoot -File -Recurse |
        ForEach-Object { $_.LastWriteTimeUtc = $packageTimestamp }

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    if (Test-Path -LiteralPath $zipHashPath) {
        Remove-Item -LiteralPath $zipHashPath -Force
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory(
        $stageRoot,
        $zipPath,
        [IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($zipHashPath, "$zipHash  $packageName.zip`n", $utf8NoBom)

    [PSCustomObject]@{
        Package = $zipPath
        Sha256 = $zipHash
        Sidecar = $zipHashPath
    }
}
finally {
    if ((Test-Path -LiteralPath $stageParent) -and
        $stageParent.StartsWith($temporaryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $stageParent -Recurse -Force
    }
}
