[CmdletBinding()]
param(
    [string]$InventoryCsvPath,
    [string]$RawAssetRoot,
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
    $trimmedCandidate = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if ([string]::Equals($trimmedCandidate, $trimmedRoot, $comparison)) {
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

function Assert-NoExistingReparsePointUnderRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $candidate = Get-CanonicalPath $Path
    $root = Get-CanonicalPath $RootPath
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description $Description

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $trimmedCandidate = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    $pathsToCheck = @($trimmedRoot)
    if (-not [string]::Equals($trimmedRoot, $trimmedCandidate, $comparison)) {
        $rootWithSeparator = $trimmedRoot + [System.IO.Path]::DirectorySeparatorChar
        $relativePath = $trimmedCandidate.Substring($rootWithSeparator.Length)
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

function Assert-SafeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Inventory relative path must not be empty.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Inventory relative path must not be rooted: $RelativePath"
    }
    foreach ($segment in $RelativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Inventory relative path contains an unsafe segment: $RelativePath"
        }
    }
}

if ([string]::IsNullOrWhiteSpace($InventoryCsvPath)) {
    $InventoryCsvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Inventory\asset-inventory.csv'))
}
if ([string]::IsNullOrWhiteSpace($RawAssetRoot)) {
    $RawAssetRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\SamplesWithDependencies\AssetBundle'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$InventoryCsvPath = Get-CanonicalPath $InventoryCsvPath
$RawAssetRoot = Get-CanonicalPath $RawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $InventoryCsvPath -RootPath $extractedRoot -Description 'InventoryCsvPath'
Assert-PathUnderOrEqual -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

if (-not (Test-Path -LiteralPath $InventoryCsvPath -PathType Leaf)) {
    throw "Missing inventory CSV: $InventoryCsvPath"
}
if (-not (Test-Path -LiteralPath $RawAssetRoot -PathType Container)) {
    throw "Missing raw asset root: $RawAssetRoot"
}

$patterns = @(
    '\\char_14401[^\\/]*\.unity3d$',
    '\\char_2d_14401\.unity3d$',
    '\\mons_16510fengcao[^\\/]*\.unity3d$',
    '\\env_roguelike_2[^\\/]*\.unity3d$',
    '\\roguelike_2[^\\/]*\.unity3d$',
    '\\fx_actorcommon[^\\/]*\.unity3d$',
    '\\icon-[0-9a-f]\.unity3d$',
    '\\ui_big_sprites\.unity3d$'
)
$combinedPattern = '(?i)' + ($patterns -join '|')

$rows = Import-Csv -LiteralPath $InventoryCsvPath |
    Where-Object { $_.Extension -eq '.unity3d' -and $_.RelativePath -match $combinedPattern } |
    Sort-Object RelativePath

if ($rows.Count -eq 0) {
    throw 'No dependency sample rows matched.'
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)
[void][System.IO.Directory]::CreateDirectory($LogRoot)

$copyLog = foreach ($row in $rows) {
    Assert-SafeRelativePath -RelativePath $row.RelativePath

    $sourcePath = Get-CanonicalPath (Join-Path $RawAssetRoot $row.RelativePath)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $RawAssetRoot -Description 'Source path'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing raw source file: $sourcePath"
    }

    $targetPath = Get-CanonicalPath (Join-Path $OutputRoot $row.RelativePath)
    Assert-PathUnderOrEqual -Path $targetPath -RootPath $OutputRoot -Description 'Target path'
    $targetDirectory = Split-Path -Parent $targetPath
    Assert-PathUnderOrEqual -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'

    $sourceItem = Get-Item -LiteralPath $sourcePath
    $status = 'Copied'
    if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
        $targetItem = Get-Item -LiteralPath $targetPath
        if ($targetItem.Length -eq $sourceItem.Length) {
            $status = 'SkippedExistingSameLength'
        }
    }

    if ($status -ne 'SkippedExistingSameLength') {
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        Assert-NoExistingReparsePointUnderRoot -Path $targetPath -RootPath $OutputRoot -Description 'Target path'
    }

    [PSCustomObject]@{
        Status = $status
        Category = $row.Category
        RelativePath = $row.RelativePath
        Length = $sourceItem.Length
        TargetPath = $targetPath
    }
}

$csvLogPath = Get-CanonicalPath (Join-Path $LogRoot 'assetripper-dependency-sample-copy-log.csv')
$jsonLogPath = Get-CanonicalPath (Join-Path $LogRoot 'assetripper-dependency-sample-copy-log.json')
Assert-PathUnderOrEqual -Path $csvLogPath -RootPath $LogRoot -Description 'CSV log path'
Assert-PathUnderOrEqual -Path $jsonLogPath -RootPath $LogRoot -Description 'JSON log path'

$copyLog | Export-Csv -LiteralPath $csvLogPath -NoTypeInformation -Encoding UTF8
$copyLog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonLogPath -Encoding UTF8

$copyLog |
    Group-Object Category |
    Sort-Object Count -Descending |
    Select-Object Count,Name |
    Format-Table -AutoSize

Write-Host "Dependency sample output root: $OutputRoot"
Write-Host "Dependency sample copy log written to $csvLogPath"
