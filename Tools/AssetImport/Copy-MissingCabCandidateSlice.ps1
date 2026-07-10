[CmdletBinding()]
param(
    [string]$SliceName = 'Environment009A05AndroidCabClosure',
    [string]$CandidateCsvPath,
    [string]$BaseInputPath,
    [string]$RawAssetRoot,
    [string]$OutputRoot,
    [string]$LogRoot
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
    return [string]::Equals($candidate, $root, $comparison) -or $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
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
    if (-not [string]::Equals($trimmedRoot, $trimmedCandidate, $comparison)) {
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

function Assert-SafeNameSegment {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ($Value -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "$Description must be a simple path segment. Got: $Value"
    }
}

function Assert-SafeRelativePath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Relative path must not be empty.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Relative path must not be rooted: $RelativePath"
    }
    foreach ($segment in $RelativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Relative path contains an unsafe segment: $RelativePath"
        }
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = Get-CanonicalPath $Path
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description 'Relative path source'
    return $candidate.Substring(($root + [System.IO.Path]::DirectorySeparatorChar).Length)
}

function Copy-SafeFile {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$TargetRoot,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$LogicalName
    )

    Assert-PathUnderOrEqual -Path $TargetPath -RootPath $TargetRoot -Description 'Target file'
    $targetDirectory = Split-Path -Parent $TargetPath
    Assert-PathUnderOrEqual -Path $targetDirectory -RootPath $TargetRoot -Description 'Target directory'
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $TargetRoot -Description 'Target directory'

    $sourceItem = Get-Item -LiteralPath $SourcePath
    $status = 'Copied'
    if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
        $targetItem = Get-Item -LiteralPath $TargetPath
        if ($targetItem.Length -eq $sourceItem.Length) {
            $status = 'SkippedExistingSameLength'
        }
    }
    if ($status -ne 'SkippedExistingSameLength') {
        Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
    }

    return [PSCustomObject]@{
        Kind = $Kind
        LogicalName = $LogicalName
        Status = $status
        Source = $SourcePath
        Target = $TargetPath
        Length = $sourceItem.Length
    }
}

if ([string]::IsNullOrWhiteSpace($CandidateCsvPath)) {
    $CandidateCsvPath = Join-Path $PSScriptRoot '..\..\Extracted\Validation\MissingCabResolution\Environment009A05AndroidVariant-greedy-selected-bundles.csv'
}
if ([string]::IsNullOrWhiteSpace($BaseInputPath)) {
    $BaseInputPath = Join-Path $PSScriptRoot '..\..\Extracted\AssetRipper\AndroidPcVariantSlices\Environment009A05AndroidPcVariant\AndroidInput'
}
if ([string]::IsNullOrWhiteSpace($RawAssetRoot)) {
    $RawAssetRoot = Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\AssetRipper\MissingCabCandidateSlices'
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = Join-Path $PSScriptRoot '..\..\Extracted\Logs'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$CandidateCsvPath = Get-CanonicalPath $CandidateCsvPath
$BaseInputPath = Get-CanonicalPath $BaseInputPath
$RawAssetRoot = Get-CanonicalPath $RawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-SafeNameSegment -Value $SliceName -Description 'SliceName'
Assert-PathUnderOrEqual -Path $CandidateCsvPath -RootPath $extractedRoot -Description 'CandidateCsvPath'
Assert-PathUnderOrEqual -Path $BaseInputPath -RootPath $extractedRoot -Description 'BaseInputPath'
Assert-PathUnderOrEqual -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $BaseInputPath -RootPath $extractedRoot -Description 'BaseInputPath'
Assert-NoExistingReparsePointUnderRoot -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $CandidateCsvPath -PathType Leaf)) {
    throw "Missing candidate CSV: $CandidateCsvPath"
}
if (-not (Test-Path -LiteralPath $BaseInputPath -PathType Container)) {
    throw "Missing base input path: $BaseInputPath"
}
if (-not (Test-Path -LiteralPath $RawAssetRoot -PathType Container)) {
    throw "Missing raw asset root: $RawAssetRoot"
}

$sliceRoot = Get-CanonicalPath (Join-Path $OutputRoot $SliceName)
$inputRoot = Get-CanonicalPath (Join-Path $sliceRoot 'Input')
Assert-PathUnderOrEqual -Path $sliceRoot -RootPath $OutputRoot -Description 'Slice root'
Assert-PathUnderOrEqual -Path $inputRoot -RootPath $sliceRoot -Description 'Input root'
New-Item -ItemType Directory -Force -Path $inputRoot, $LogRoot | Out-Null
Assert-NoExistingReparsePointUnderRoot -Path $sliceRoot -RootPath $OutputRoot -Description 'Slice root'

$copyLog = New-Object System.Collections.Generic.List[object]

$baseFiles = @(Get-ChildItem -LiteralPath $BaseInputPath -Recurse -File -Filter '*.unity3d' -Force -ErrorAction SilentlyContinue | Sort-Object FullName)
foreach ($file in $baseFiles) {
    $relative = Get-RelativePath -RootPath $BaseInputPath -Path $file.FullName
    Assert-SafeRelativePath -RelativePath $relative
    $targetPath = Get-CanonicalPath (Join-Path $inputRoot (Join-Path 'Base' $relative))
    $copyLog.Add((Copy-SafeFile -SourcePath $file.FullName -TargetPath $targetPath -TargetRoot $inputRoot -Kind 'BaseInput' -LogicalName $relative)) | Out-Null
}

$candidateRows = @(Import-Csv -LiteralPath $CandidateCsvPath)
foreach ($row in $candidateRows) {
    $relative = [string]$row.RelativePath
    Assert-SafeRelativePath -RelativePath $relative
    $sourcePath = Get-CanonicalPath (Join-Path $RawAssetRoot $relative)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $RawAssetRoot -Description 'Candidate source'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing candidate source: $sourcePath"
    }

    $targetPath = Get-CanonicalPath (Join-Path $inputRoot (Join-Path 'Candidate' $relative))
    $copyLog.Add((Copy-SafeFile -SourcePath $sourcePath -TargetPath $targetPath -TargetRoot $inputRoot -Kind 'Candidate' -LogicalName $relative)) | Out-Null
}

$files = @(Get-ChildItem -LiteralPath $inputRoot -Recurse -File -Filter '*.unity3d' -Force -ErrorAction SilentlyContinue)
$totalBytes = ($files | Measure-Object Length -Sum).Sum
if ($null -eq $totalBytes) {
    $totalBytes = 0
}

$logCsvPath = Get-CanonicalPath (Join-Path $LogRoot "missing-cab-candidate-slice-$SliceName-copy-log.csv")
$summaryJsonPath = Get-CanonicalPath (Join-Path $LogRoot "missing-cab-candidate-slice-$SliceName-summary.json")
Assert-PathUnderOrEqual -Path $logCsvPath -RootPath $LogRoot -Description 'Copy log CSV'
Assert-PathUnderOrEqual -Path $summaryJsonPath -RootPath $LogRoot -Description 'Summary JSON'

$copyLog | Export-Csv -LiteralPath $logCsvPath -NoTypeInformation -Encoding UTF8
$summary = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    SliceName = $SliceName
    SliceRoot = $sliceRoot
    InputRoot = $inputRoot
    BaseInputPath = $BaseInputPath
    CandidateCsvPath = $CandidateCsvPath
    BaseFileCount = $baseFiles.Count
    CandidateFileCount = $candidateRows.Count
    InputFileCount = $files.Count
    InputTotalBytes = [int64]$totalBytes
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8

[PSCustomObject]@{
    SliceName = $SliceName
    BaseFileCount = $summary.BaseFileCount
    CandidateFileCount = $summary.CandidateFileCount
    InputFileCount = $summary.InputFileCount
    InputTotalBytes = $summary.InputTotalBytes
    InputRoot = $inputRoot
    Summary = $summaryJsonPath
} | Format-List
