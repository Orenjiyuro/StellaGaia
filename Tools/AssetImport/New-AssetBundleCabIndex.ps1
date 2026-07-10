[CmdletBinding()]
param(
    [string]$InventoryCsvPath,
    [string]$RawAssetRoot,
    [string]$OutputRoot,
    [string]$MissingCabLogPath
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsPathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$CandidatePath,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $candidate = (Get-CanonicalPath $CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $candidate.Equals($root, $comparison) -or $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must stay under $RootPath. Got: $Path"
    }
}

function Assert-NoExistingReparsePointUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    $candidate = Get-CanonicalPath $Path
    $root = Get-CanonicalPath $RootPath
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description $Description

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $trimmedCandidate = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    $pathsToCheck = @($trimmedRoot)
    if (-not $trimmedRoot.Equals($trimmedCandidate, $comparison)) {
        $relativePath = $trimmedCandidate.Substring(($trimmedRoot + [System.IO.Path]::DirectorySeparatorChar).Length)
        $currentPath = $trimmedRoot
        foreach ($segment in $relativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
            if ([string]::IsNullOrWhiteSpace($segment)) {
                continue
            }
            $currentPath = Join-Path $currentPath $segment
            $pathsToCheck += $currentPath
        }
    }

    foreach ($pathToCheck in $pathsToCheck) {
        if (-not (Test-Path -LiteralPath $pathToCheck)) {
            break
        }
        $item = Get-Item -LiteralPath $pathToCheck -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Description must not include symlinks, junctions, or reparse points. Reparse point: $($item.FullName)"
        }
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $pathFull = Get-CanonicalPath $Path
    $rootFull = (Get-CanonicalPath $Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $pathFull.Substring(($rootFull + [System.IO.Path]::DirectorySeparatorChar).Length)
}

if ([string]::IsNullOrWhiteSpace($InventoryCsvPath)) {
    $InventoryCsvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Inventory\asset-inventory.csv'))
}
if ([string]::IsNullOrWhiteSpace($RawAssetRoot)) {
    $RawAssetRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\DependencyIndex'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$InventoryCsvPath = Get-CanonicalPath $InventoryCsvPath
$RawAssetRoot = Get-CanonicalPath $RawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $InventoryCsvPath -RootPath $extractedRoot -Description 'InventoryCsvPath'
Assert-PathUnderOrEqual -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $InventoryCsvPath -PathType Leaf)) {
    throw "Missing inventory CSV: $InventoryCsvPath"
}
if (-not (Test-Path -LiteralPath $RawAssetRoot -PathType Container)) {
    throw "Missing raw asset root: $RawAssetRoot"
}

$rg = Get-Command rg -ErrorAction SilentlyContinue
if ($null -eq $rg) {
    throw 'ripgrep (rg) is required to build the CAB index.'
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$inventoryByRelativePath = @{}
Import-Csv -LiteralPath $InventoryCsvPath |
    Where-Object { $_.Extension -eq '.unity3d' } |
    ForEach-Object {
        $inventoryByRelativePath[$_.RelativePath] = $_
    }

$rawMatchesPath = Join-Path $OutputRoot 'assetbundle-cab-scan-raw.txt'
$indexCsvPath = Join-Path $OutputRoot 'assetbundle-cab-index.csv'
$summaryJsonPath = Join-Path $OutputRoot 'assetbundle-cab-summary.json'
Assert-PathUnderOrEqual -Path $rawMatchesPath -RootPath $OutputRoot -Description 'Raw match output'
Assert-PathUnderOrEqual -Path $indexCsvPath -RootPath $OutputRoot -Description 'Index CSV output'
Assert-PathUnderOrEqual -Path $summaryJsonPath -RootPath $OutputRoot -Description 'Summary JSON output'

$arguments = @(
    '-a',
    '-o',
    '--no-heading',
    '--with-filename',
    '--glob',
    '*.unity3d',
    'CAB-[0-9a-f]{32}',
    $RawAssetRoot
)
& $rg.Source @arguments | Set-Content -LiteralPath $rawMatchesPath -Encoding UTF8

$index = New-Object System.Collections.Generic.List[object]
$seen = New-Object System.Collections.Generic.HashSet[string]
foreach ($line in Get-Content -LiteralPath $rawMatchesPath) {
    if ($line -notmatch '^(?<path>.*):(?<cab>CAB-[0-9a-f]{32})$') {
        continue
    }

    $filePath = Get-CanonicalPath $Matches.path
    Assert-PathUnderOrEqual -Path $filePath -RootPath $RawAssetRoot -Description 'Indexed bundle path'
    $relativePath = Get-RelativePath -Path $filePath -Root $RawAssetRoot
    $cab = $Matches.cab
    $dedupeKey = "$cab|$relativePath"
    if (-not $seen.Add($dedupeKey)) {
        continue
    }

    $inventoryRow = $inventoryByRelativePath[$relativePath]
    $fileItem = Get-Item -LiteralPath $filePath
    $index.Add([PSCustomObject]@{
        CabId = $cab
        Category = if ($inventoryRow) { $inventoryRow.Category } else { '' }
        RelativePath = $relativePath
        Length = $fileItem.Length
    })
}

$index |
    Sort-Object CabId, RelativePath |
    Export-Csv -LiteralPath $indexCsvPath -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    RawAssetRoot = $RawAssetRoot
    Unity3dInventoryRows = $inventoryByRelativePath.Count
    IndexedCabIds = @($index | Select-Object -ExpandProperty CabId -Unique).Count
    IndexedCabBundlePairs = $index.Count
    IndexCsv = $indexCsvPath
    RawScan = $rawMatchesPath
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8

$resolutionPath = $null
if (-not [string]::IsNullOrWhiteSpace($MissingCabLogPath)) {
    $MissingCabLogPath = Get-CanonicalPath $MissingCabLogPath
    Assert-PathUnderOrEqual -Path $MissingCabLogPath -RootPath $extractedRoot -Description 'Missing CAB log'
    if (-not (Test-Path -LiteralPath $MissingCabLogPath -PathType Leaf)) {
        throw "Missing CAB log path: $MissingCabLogPath"
    }

    $missingCabIds = Select-String -LiteralPath $MissingCabLogPath -Pattern 'CAB-[0-9a-f]{32}' -AllMatches |
        ForEach-Object { $_.Matches.Value } |
        Sort-Object -Unique

    $indexByCab = $index | Group-Object CabId -AsHashTable -AsString
    $resolution = foreach ($cab in $missingCabIds) {
        $matches = @($indexByCab[$cab])
        [PSCustomObject]@{
            CabId = $cab
            Status = if ($matches.Count -gt 0) { 'ResolvedToRawBundle' } else { 'Unresolved' }
            MatchCount = $matches.Count
            Categories = (($matches | Select-Object -ExpandProperty Category -Unique) -join ';')
            RelativePaths = (($matches | Select-Object -ExpandProperty RelativePath -Unique) -join ';')
        }
    }

    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($MissingCabLogPath)
    $resolutionPath = Join-Path $OutputRoot "$baseName-cab-resolution.csv"
    Assert-PathUnderOrEqual -Path $resolutionPath -RootPath $OutputRoot -Description 'Resolution CSV output'
    $resolution | Export-Csv -LiteralPath $resolutionPath -NoTypeInformation -Encoding UTF8
}

$output = [PSCustomObject]@{
    IndexedCabIds = $summary.IndexedCabIds
    IndexedCabBundlePairs = $summary.IndexedCabBundlePairs
    IndexCsv = $indexCsvPath
    ResolutionCsv = $resolutionPath
}
$output | Format-List
