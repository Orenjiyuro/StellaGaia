[CmdletBinding()]
param(
    [string]$ManifestPath
)

$ErrorActionPreference = 'Stop'
if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json

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

$headerBytes = ([System.IO.File]::ReadAllBytes($unityData))[0..63]
$headerText = [System.Text.Encoding]::ASCII.GetString($headerBytes)
if ($headerText -notmatch 'UnityFS' -or $headerText -notmatch [regex]::Escape($manifest.unityVersion)) {
    throw "UnityFS version check failed for $unityData. Expected $($manifest.unityVersion)."
}

Write-Host "Toolchain verified for Unity $($manifest.unityVersion)."
