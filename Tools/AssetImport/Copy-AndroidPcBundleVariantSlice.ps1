[CmdletBinding()]
param(
    [string]$SliceName = 'Environment009A05AndroidPcVariant',
    [string[]]$BaseName = @(
        'roguelike_battle_009_a_05_assets',
        'roguelike_battle_009_a_05_mir_assets',
        'env_roguelike_2_fx',
        'env_roguelike_2_ani',
        'env_roguelike_2_timeline',
        'env_roguelike_2_mesh-1',
        'env_roguelike_2_fx_materials',
        'env_roguelike_2_interactive'
    ),
    [string]$ComparisonCsvPath,
    [string]$AndroidRoot,
    [string]$PcRawAssetRoot,
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
    $candidate = (Get-CanonicalPath $CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if ([string]::Equals($candidate, $root, $comparison)) {
        return $true
    }

    return $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
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

function Assert-SafeNameSegment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($Value -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "$Description must be a simple path segment. Got: $Value"
    }
}

function Copy-InputFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot
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
        Status = $status
        Length = $sourceItem.Length
    }
}

function Copy-ApkEntry {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AndroidExample,
        [Parameter(Mandatory = $true)]
        [string]$AndroidRootPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot,
        [Parameter(Mandatory = $true)]
        [string]$TargetRelativePath
    )

    $separator = '!/'
    $separatorIndex = $AndroidExample.IndexOf($separator, [System.StringComparison]::Ordinal)
    if ($separatorIndex -lt 1) {
        throw "Android example is not an APK entry: $AndroidExample"
    }

    $archiveRelativePath = $AndroidExample.Substring(0, $separatorIndex)
    $entryPath = $AndroidExample.Substring($separatorIndex + $separator.Length)
    Assert-SafeRelativePath -RelativePath $archiveRelativePath
    if ([string]::IsNullOrWhiteSpace($entryPath) -or $entryPath -match '(^|/)\.\.?(/|$)') {
        throw "Unsafe APK entry path: $entryPath"
    }

    $archivePath = Get-CanonicalPath (Join-Path $AndroidRootPath $archiveRelativePath)
    Assert-PathUnderOrEqual -Path $archivePath -RootPath $AndroidRootPath -Description 'APK path'
    if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "Missing APK file: $archivePath"
    }

    $targetPath = Get-CanonicalPath (Join-Path $TargetRoot $TargetRelativePath)
    Assert-PathUnderOrEqual -Path $targetPath -RootPath $TargetRoot -Description 'APK target file'
    $targetDirectory = Split-Path -Parent $targetPath
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $TargetRoot -Description 'APK target directory'

    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entry = $archive.GetEntry($entryPath)
        if ($null -eq $entry) {
            throw "Missing APK entry $entryPath in $archivePath"
        }

        $status = 'Extracted'
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $targetItem = Get-Item -LiteralPath $targetPath
            if ($targetItem.Length -eq $entry.Length) {
                $status = 'SkippedExistingSameLength'
            }
        }

        if ($status -ne 'SkippedExistingSameLength') {
            $entryStream = $entry.Open()
            try {
                $fileStream = [System.IO.File]::Open($targetPath, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                try {
                    $entryStream.CopyTo($fileStream)
                } finally {
                    $fileStream.Dispose()
                }
            } finally {
                $entryStream.Dispose()
            }
        }

        return [PSCustomObject]@{
            Status = $status
            Length = $entry.Length
        }
    } finally {
        $archive.Dispose()
    }
}

if ([string]::IsNullOrWhiteSpace($ComparisonCsvPath)) {
    $ComparisonCsvPath = Join-Path $PSScriptRoot '..\..\Extracted\Validation\AndroidPcBundleComparison\android-pc-roguelike-bundle-comparison.csv'
}
if ([string]::IsNullOrWhiteSpace($AndroidRoot)) {
    $AndroidRoot = Join-Path $PSScriptRoot '..\..\Android'
}
if ([string]::IsNullOrWhiteSpace($PcRawAssetRoot)) {
    $PcRawAssetRoot = Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\AssetRipper\AndroidPcVariantSlices'
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = Join-Path $PSScriptRoot '..\..\Extracted\Logs'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$ComparisonCsvPath = Get-CanonicalPath $ComparisonCsvPath
$AndroidRoot = Get-CanonicalPath $AndroidRoot
$PcRawAssetRoot = Get-CanonicalPath $PcRawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-SafeNameSegment -Value $SliceName -Description 'SliceName'
foreach ($name in $BaseName) {
    Assert-SafeNameSegment -Value $name -Description 'BaseName'
}
Assert-PathUnderOrEqual -Path $ComparisonCsvPath -RootPath $extractedRoot -Description 'ComparisonCsvPath'
Assert-PathUnderOrEqual -Path $PcRawAssetRoot -RootPath $extractedRoot -Description 'PcRawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

if (-not (Test-Path -LiteralPath $ComparisonCsvPath -PathType Leaf)) {
    throw "Missing comparison CSV: $ComparisonCsvPath"
}
if (-not (Test-Path -LiteralPath $AndroidRoot -PathType Container)) {
    throw "Missing Android root: $AndroidRoot"
}
if (-not (Test-Path -LiteralPath $PcRawAssetRoot -PathType Container)) {
    throw "Missing PC raw asset root: $PcRawAssetRoot"
}

[System.Reflection.Assembly]::Load('System.IO.Compression.FileSystem') | Out-Null

$sliceRoot = Get-CanonicalPath (Join-Path $OutputRoot $SliceName)
$pcInputRoot = Get-CanonicalPath (Join-Path $sliceRoot 'PcInput')
$androidInputRoot = Get-CanonicalPath (Join-Path $sliceRoot 'AndroidInput')
$combinedInputRoot = Get-CanonicalPath (Join-Path $sliceRoot 'CombinedInput')
Assert-PathUnderOrEqual -Path $sliceRoot -RootPath $OutputRoot -Description 'Slice root'
Assert-PathUnderOrEqual -Path $pcInputRoot -RootPath $sliceRoot -Description 'PC input root'
Assert-PathUnderOrEqual -Path $androidInputRoot -RootPath $sliceRoot -Description 'Android input root'
Assert-PathUnderOrEqual -Path $combinedInputRoot -RootPath $sliceRoot -Description 'Combined input root'

New-Item -ItemType Directory -Force -Path $pcInputRoot, $androidInputRoot, $combinedInputRoot, $LogRoot | Out-Null
Assert-NoExistingReparsePointUnderRoot -Path $sliceRoot -RootPath $OutputRoot -Description 'Slice root'

$rows = Import-Csv -LiteralPath $ComparisonCsvPath
$selectedRows = foreach ($name in $BaseName) {
    $match = @($rows | Where-Object { $_.BaseName -eq $name } | Select-Object -First 1)
    if ($match.Count -eq 0) {
        throw "BaseName not found in comparison CSV: $name"
    }
    $match[0]
}

$copyLog = New-Object System.Collections.Generic.List[object]
foreach ($row in $selectedRows) {
    $base = [string]$row.BaseName

    if (-not [string]::IsNullOrWhiteSpace([string]$row.PcExample)) {
        $pcRelative = [string]$row.PcExample
        Assert-SafeRelativePath -RelativePath $pcRelative
        $pcSource = Get-CanonicalPath (Join-Path $PcRawAssetRoot $pcRelative)
        Assert-PathUnderOrEqual -Path $pcSource -RootPath $PcRawAssetRoot -Description 'PC source'
        if (-not (Test-Path -LiteralPath $pcSource -PathType Leaf)) {
            throw "Missing PC source: $pcSource"
        }

        $pcTargetRelative = Join-Path 'Pc' (Join-Path 'AssetBundles' ([System.IO.Path]::GetFileName($pcRelative)))
        $pcTarget = Get-CanonicalPath (Join-Path $pcInputRoot $pcTargetRelative)
        $pcCopy = Copy-InputFile -SourcePath $pcSource -TargetPath $pcTarget -TargetRoot $pcInputRoot

        $combinedPcTarget = Get-CanonicalPath (Join-Path $combinedInputRoot $pcTargetRelative)
        $combinedPcCopy = Copy-InputFile -SourcePath $pcSource -TargetPath $combinedPcTarget -TargetRoot $combinedInputRoot

        $copyLog.Add([PSCustomObject]@{
            BaseName = $base
            Side = 'PC'
            Status = $pcCopy.Status
            Source = $pcRelative
            Target = $pcTarget
            CombinedTarget = $combinedPcTarget
            Length = $pcCopy.Length
        }) | Out-Null
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$row.AndroidExample)) {
        $androidExample = [string]$row.AndroidExample
        $fileName = [System.IO.Path]::GetFileName($androidExample.Replace('/', '\'))
        $androidTargetRelative = Join-Path 'Android' (Join-Path 'AssetBundles' $fileName)
        $androidTarget = Get-CanonicalPath (Join-Path $androidInputRoot $androidTargetRelative)
        $combinedAndroidTarget = Get-CanonicalPath (Join-Path $combinedInputRoot $androidTargetRelative)

        if ($androidExample.Contains('!/')) {
            $androidCopy = Copy-ApkEntry -AndroidExample $androidExample -AndroidRootPath $AndroidRoot -TargetRoot $androidInputRoot -TargetRelativePath $androidTargetRelative
            $combinedAndroidCopy = Copy-ApkEntry -AndroidExample $androidExample -AndroidRootPath $AndroidRoot -TargetRoot $combinedInputRoot -TargetRelativePath $androidTargetRelative
        } else {
            Assert-SafeRelativePath -RelativePath $androidExample
            $androidSource = Get-CanonicalPath (Join-Path (Join-Path $AndroidRoot 'DATA') $androidExample)
            Assert-PathUnderOrEqual -Path $androidSource -RootPath (Join-Path $AndroidRoot 'DATA') -Description 'Android DATA source'
            if (-not (Test-Path -LiteralPath $androidSource -PathType Leaf)) {
                throw "Missing Android DATA source: $androidSource"
            }

            $androidCopy = Copy-InputFile -SourcePath $androidSource -TargetPath $androidTarget -TargetRoot $androidInputRoot
            $combinedAndroidCopy = Copy-InputFile -SourcePath $androidSource -TargetPath $combinedAndroidTarget -TargetRoot $combinedInputRoot
        }

        $copyLog.Add([PSCustomObject]@{
            BaseName = $base
            Side = 'Android'
            Status = $androidCopy.Status
            Source = $androidExample
            Target = $androidTarget
            CombinedTarget = $combinedAndroidTarget
            Length = $androidCopy.Length
        }) | Out-Null
    }
}

$logCsvPath = Get-CanonicalPath (Join-Path $LogRoot "android-pc-variant-slice-$SliceName-copy-log.csv")
$logJsonPath = Get-CanonicalPath (Join-Path $LogRoot "android-pc-variant-slice-$SliceName-summary.json")
Assert-PathUnderOrEqual -Path $logCsvPath -RootPath $LogRoot -Description 'Copy log CSV'
Assert-PathUnderOrEqual -Path $logJsonPath -RootPath $LogRoot -Description 'Copy log JSON'

$pcFiles = @(Get-ChildItem -LiteralPath $pcInputRoot -Recurse -File -Filter '*.unity3d' -ErrorAction SilentlyContinue)
$androidFiles = @(Get-ChildItem -LiteralPath $androidInputRoot -Recurse -File -Filter '*.unity3d' -ErrorAction SilentlyContinue)
$combinedFiles = @(Get-ChildItem -LiteralPath $combinedInputRoot -Recurse -File -Filter '*.unity3d' -ErrorAction SilentlyContinue)

$summary = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    SliceName = $SliceName
    BaseNames = @($BaseName)
    SliceRoot = $sliceRoot
    PcInputRoot = $pcInputRoot
    AndroidInputRoot = $androidInputRoot
    CombinedInputRoot = $combinedInputRoot
    PcFileCount = $pcFiles.Count
    AndroidFileCount = $androidFiles.Count
    CombinedFileCount = $combinedFiles.Count
    PcTotalBytes = [int64](($pcFiles | Measure-Object Length -Sum).Sum ?? 0)
    AndroidTotalBytes = [int64](($androidFiles | Measure-Object Length -Sum).Sum ?? 0)
    CombinedTotalBytes = [int64](($combinedFiles | Measure-Object Length -Sum).Sum ?? 0)
    CopyLog = @($copyLog.ToArray())
}

$copyLog | Export-Csv -LiteralPath $logCsvPath -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $logJsonPath -Encoding UTF8

[PSCustomObject]@{
    SliceName = $SliceName
    PcFileCount = $summary.PcFileCount
    AndroidFileCount = $summary.AndroidFileCount
    CombinedFileCount = $summary.CombinedFileCount
    PcTotalBytes = $summary.PcTotalBytes
    AndroidTotalBytes = $summary.AndroidTotalBytes
    CombinedTotalBytes = $summary.CombinedTotalBytes
    SliceRoot = $sliceRoot
    Summary = $logJsonPath
} | Format-List
