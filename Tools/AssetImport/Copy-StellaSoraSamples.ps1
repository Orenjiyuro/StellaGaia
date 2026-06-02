[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$SampleManifestPath,
    [string]$OutputRoot,
    [string]$LogRoot
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsPathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $candidate = Get-CanonicalPath $CandidatePath
    $root = Get-CanonicalPath $RootPath
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if ([string]::Equals($candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), $trimmedRoot, $comparison)) {
        return $true
    }

    $rootWithSeparator = $trimmedRoot + [System.IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($rootWithSeparator, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must stay under $RootPath. Got: $Path"
    }
}

function Assert-SafeFileNameSegment {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Description must not be empty."
    }
    if ([System.IO.Path]::IsPathRooted($Value)) {
        throw "$Description must be a single filename segment, not a rooted path: $Value"
    }
    if ($Value -eq '.' -or $Value -eq '..' -or $Value.Contains('..')) {
        throw "$Description must not contain traversal segments: $Value"
    }
    if ($Value.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0 -or $Value.Contains('/') -or $Value.Contains('\')) {
        throw "$Description contains invalid filename or path separator characters: $Value"
    }
}

function Resolve-SafeSourcePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceInstall,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RelativeSource
    )

    if ([string]::IsNullOrWhiteSpace($RelativeSource)) {
        throw "Manifest source must not be empty."
    }
    if ([System.IO.Path]::IsPathRooted($RelativeSource)) {
        throw "Manifest source must be relative to sourceInstall, not absolute: $RelativeSource"
    }

    $sourcePath = Get-CanonicalPath (Join-Path $SourceInstall $RelativeSource)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $SourceInstall -Description 'Manifest source path'
    return $sourcePath
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($SampleManifestPath)) {
    $SampleManifestPath = Join-Path $PSScriptRoot 'sample-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Samples'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

$toolManifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
$sampleManifest = Get-Content -LiteralPath $SampleManifestPath -Raw | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $toolManifest.sourceInstall -PathType Container)) {
    throw "Missing source install directory: $($toolManifest.sourceInstall)"
}
$sourceInstall = Get-CanonicalPath $toolManifest.sourceInstall

$outputRootInfo = [System.IO.Directory]::CreateDirectory($OutputRoot)
$logRootInfo = [System.IO.Directory]::CreateDirectory($LogRoot)
$OutputRoot = $outputRootInfo.FullName
$LogRoot = $logRootInfo.FullName

$items = @()
$items += @($sampleManifest.assetBundles) | ForEach-Object {
    [PSCustomObject]@{
        Kind = 'AssetBundle'
        Category = $_.category
        Source = $_.source
        TargetName = $_.targetName
    }
}
$items += @($sampleManifest.audio) | ForEach-Object {
    [PSCustomObject]@{
        Kind = 'Audio'
        Category = $_.category
        Source = $_.source
        TargetName = $_.targetName
    }
}

$copyLog = foreach ($item in $items) {
    Assert-SafeFileNameSegment -Value $item.Category -Description 'Manifest category'
    Assert-SafeFileNameSegment -Value $item.TargetName -Description 'Manifest targetName'

    $sourcePath = Resolve-SafeSourcePath -SourceInstall $sourceInstall -RelativeSource $item.Source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing sample source: $sourcePath"
    }

    $targetDirectory = Join-Path $OutputRoot (Join-Path $item.Kind $item.Category)
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    $targetPath = Join-Path $targetDirectory $item.TargetName
    Assert-PathUnderOrEqual -Path $targetPath -RootPath $OutputRoot -Description 'Target path'
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force

    $targetItem = Get-Item -LiteralPath $targetPath
    $hash = Get-FileHash -LiteralPath $targetPath -Algorithm SHA256
    [PSCustomObject]@{
        Kind = $item.Kind
        Category = $item.Category
        SourcePath = $sourcePath
        TargetPath = $targetItem.FullName
        Length = $targetItem.Length
        Sha256 = $hash.Hash
    }
}

$jsonPath = Join-Path $LogRoot 'sample-copy-log.json'
$csvPath = Join-Path $LogRoot 'sample-copy-log.csv'
$copyLog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$copyLog | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$copyLog | Format-Table Kind,Category,Length,TargetPath -AutoSize
Write-Host "Sample copy log written to $jsonPath"
