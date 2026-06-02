[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$SampleManifestPath,
    [string]$OutputRoot,
    [string]$LogRoot
)

$ErrorActionPreference = 'Stop'

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

$toolManifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
$sampleManifest = Get-Content -LiteralPath $SampleManifestPath -Raw | ConvertFrom-Json

if (-not (Test-Path -LiteralPath $toolManifest.sourceInstall -PathType Container)) {
    throw "Missing source install directory: $($toolManifest.sourceInstall)"
}

$outputRootInfo = New-Item -ItemType Directory -Force -Path $OutputRoot
$logRootInfo = New-Item -ItemType Directory -Force -Path $LogRoot
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
    $sourcePath = Join-Path $toolManifest.sourceInstall $item.Source
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing sample source: $sourcePath"
    }

    $targetDirectory = Join-Path $OutputRoot (Join-Path $item.Kind $item.Category)
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    $targetPath = Join-Path $targetDirectory $item.TargetName
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
