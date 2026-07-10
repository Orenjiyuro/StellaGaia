[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$InventoryCsvPath,
    [string]$OutputRoot,
    [string]$LogRoot,
    [string[]]$Category,
    [switch]$DryRun
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

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($InventoryCsvPath)) {
    $InventoryCsvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Inventory\asset-inventory.csv'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$InventoryCsvPath = Get-CanonicalPath $InventoryCsvPath
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $InventoryCsvPath -RootPath $extractedRoot -Description 'InventoryCsvPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.sourceInstall) -or -not (Test-Path -LiteralPath $manifest.sourceInstall -PathType Container)) {
    throw "Missing source install directory: $($manifest.sourceInstall)"
}
if (-not (Test-Path -LiteralPath $InventoryCsvPath -PathType Leaf)) {
    throw "Missing inventory CSV: $InventoryCsvPath. Run New-StellaSoraAssetInventory.ps1 first."
}

$sourceInstall = Get-CanonicalPath $manifest.sourceInstall
$categoryFilter = @{}
foreach ($entry in @($Category)) {
    if (-not [string]::IsNullOrWhiteSpace($entry)) {
        $categoryFilter[$entry] = $true
    }
}

$inventory = Import-Csv -LiteralPath $InventoryCsvPath
if ($categoryFilter.Count -gt 0) {
    $inventory = @($inventory | Where-Object { $categoryFilter.ContainsKey($_.Category) })
}

if ($inventory.Count -eq 0) {
    throw 'No inventory rows matched the requested copy set.'
}

if (-not $DryRun) {
    [void][System.IO.Directory]::CreateDirectory($OutputRoot)
    [void][System.IO.Directory]::CreateDirectory($LogRoot)
}

$copyLog = foreach ($row in $inventory) {
    Assert-SafeRelativePath -RelativePath $row.RelativePath

    $sourcePath = Get-CanonicalPath (Join-Path $sourceInstall $row.RelativePath)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $sourceInstall -Description 'Source path'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing source file: $sourcePath"
    }

    $destinationPath = Get-CanonicalPath (Join-Path $OutputRoot $row.RelativePath)
    Assert-PathUnderOrEqual -Path $destinationPath -RootPath $OutputRoot -Description 'Destination path'

    $sourceItem = Get-Item -LiteralPath $sourcePath
    $status = 'Copied'

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $destinationItem = Get-Item -LiteralPath $destinationPath
        if ($destinationItem.Length -eq $sourceItem.Length) {
            $status = 'SkippedExistingSameLength'
        }
    }

    if ($DryRun) {
        $status = "DryRun:$status"
    }
    elseif ($status -ne 'SkippedExistingSameLength') {
        $destinationDirectory = Split-Path -Parent $destinationPath
        Assert-PathUnderOrEqual -Path $destinationDirectory -RootPath $OutputRoot -Description 'Destination directory'
        Assert-NoExistingReparsePointUnderRoot -Path $destinationDirectory -RootPath $OutputRoot -Description 'Destination directory'
        New-Item -ItemType Directory -Force -Path $destinationDirectory | Out-Null
        Assert-NoExistingReparsePointUnderRoot -Path $destinationDirectory -RootPath $OutputRoot -Description 'Destination directory'
        Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
        Assert-NoExistingReparsePointUnderRoot -Path $destinationPath -RootPath $OutputRoot -Description 'Destination path'
    }

    [PSCustomObject]@{
        Status = $status
        Category = $row.Category
        Extension = $row.Extension
        RelativePath = $row.RelativePath
        SourcePath = $sourcePath
        DestinationPath = $destinationPath
        Length = $sourceItem.Length
    }
}

$logSuffix = if ($DryRun) { 'dry-run' } else { 'copy' }
$csvLogPath = Get-CanonicalPath (Join-Path $LogRoot "full-raw-assets-$logSuffix-log.csv")
$jsonLogPath = Get-CanonicalPath (Join-Path $LogRoot "full-raw-assets-$logSuffix-log.json")
Assert-PathUnderOrEqual -Path $csvLogPath -RootPath $LogRoot -Description 'CSV log path'
Assert-PathUnderOrEqual -Path $jsonLogPath -RootPath $LogRoot -Description 'JSON log path'

$copyLog | Export-Csv -LiteralPath $csvLogPath -NoTypeInformation -Encoding UTF8
$copyLog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonLogPath -Encoding UTF8

$copyLog |
    Group-Object Status |
    Sort-Object Count -Descending |
    Select-Object Count,Name |
    Format-Table -AutoSize

Write-Host "Raw asset output root: $OutputRoot"
Write-Host "Raw asset copy log written to $csvLogPath"
