[CmdletBinding()]
param(
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

function Test-AbsoluteFileSystemPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return $Path -match '^[A-Za-z]:[\\/]' -or $Path -match '^[\\/]{2}[^\\/]+[\\/][^\\/]+'
}

$requiredFields = @(
    'sourceInstall',
    'unityEditor',
    'assetRipper',
    'vgmstreamCli',
    'ffmpeg',
    'ffprobe',
    'unityVersion'
)

foreach ($field in $requiredFields) {
    $value = $manifest.$field
    if ($null -eq $value -or [string]::IsNullOrWhiteSpace([string]$value)) {
        throw "Missing required manifest field: $field"
    }
}

$pathFields = @(
    'sourceInstall',
    'unityEditor',
    'assetRipper',
    'vgmstreamCli',
    'ffmpeg',
    'ffprobe'
)

foreach ($field in $pathFields) {
    $value = [string]$manifest.$field
    if (-not (Test-AbsoluteFileSystemPath -Path $value)) {
        throw "Manifest path field $field must be an absolute filesystem path: $value"
    }
}

$checks = @(
    @{ Name = 'sourceInstall'; Path = $manifest.sourceInstall; Kind = 'Directory' },
    @{ Name = 'unityEditor'; Path = $manifest.unityEditor; Kind = 'File' },
    @{ Name = 'assetRipper'; Path = $manifest.assetRipper; Kind = 'File' },
    @{ Name = 'vgmstreamCli'; Path = $manifest.vgmstreamCli; Kind = 'File' },
    @{ Name = 'ffmpeg'; Path = $manifest.ffmpeg; Kind = 'File' },
    @{ Name = 'ffprobe'; Path = $manifest.ffprobe; Kind = 'File' }
)

$results = foreach ($check in $checks) {
    $exists = Test-Path -LiteralPath $check.Path
    $kindMatches = switch ($check.Kind) {
        'Directory' { Test-Path -LiteralPath $check.Path -PathType Container }
        'File' { Test-Path -LiteralPath $check.Path -PathType Leaf }
        default { $false }
    }

    [PSCustomObject]@{
        Name = $check.Name
        Kind = $check.Kind
        Path = $check.Path
        Exists = $exists
        KindMatches = $kindMatches
    }
}

$invalid = $results | Where-Object { -not $_.Exists -or -not $_.KindMatches }
$results | Format-Table -AutoSize

if ($invalid) {
    $names = ($invalid | ForEach-Object { "$($_.Name)=$($_.Path) (expected $($_.Kind))" }) -join '; '
    throw "Missing or invalid required paths: $names"
}

$unityData = Join-Path $manifest.sourceInstall 'xtlr_Data\data.unity3d'
if (-not (Test-Path -LiteralPath $unityData)) {
    throw "Missing Unity data file: $unityData"
}

$headerBytes = [byte[]]::new(64)
$stream = [System.IO.File]::Open($unityData, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
try {
    $bytesRead = $stream.Read($headerBytes, 0, $headerBytes.Length)
} finally {
    $stream.Dispose()
}

if ($bytesRead -lt $headerBytes.Length) {
    throw "Unity data file header is shorter than 64 bytes: $unityData"
}

$headerText = [System.Text.Encoding]::ASCII.GetString($headerBytes)
if ($headerText -notmatch 'UnityFS' -or $headerText -notmatch [regex]::Escape($manifest.unityVersion)) {
    throw "UnityFS version check failed for $unityData. Expected $($manifest.unityVersion)."
}

Write-Host "Toolchain verified for Unity $($manifest.unityVersion)."
