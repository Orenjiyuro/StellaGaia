[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceProjectPath,
    [Parameter(Mandatory = $true)]
    [string[]]$RootAssetPath,
    [Parameter(Mandatory = $true)]
    [string]$OutputProjectPath,
    [string]$ReportRoot
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

function Assert-SafeProjectAssetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '^Assets[/\\].+') {
        throw "Root asset path must start with Assets/: $Path"
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        throw "Asset path must not be rooted: $Path"
    }
    foreach ($segment in ($Path -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Asset path contains an unsafe segment: $Path"
        }
    }
}

function Copy-DirectoryIfPresent {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$SourceProject,
        [Parameter(Mandatory = $true)][string]$OutputProject
    )

    $source = Join-Path $SourceProject $Name
    if (-not (Test-Path -LiteralPath $source -PathType Container)) {
        return
    }

    $target = Join-Path $OutputProject $Name
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($source.Length + 1)
        $targetPath = Join-Path $target $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
}

function Copy-ProjectAssetFile {
    param(
        [Parameter(Mandatory = $true)][string]$AssetPath,
        [Parameter(Mandatory = $true)][string]$SourceProject,
        [Parameter(Mandatory = $true)][string]$OutputProject
    )

    $sourcePath = Join-Path $SourceProject $AssetPath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        return $false
    }

    $targetPath = Join-Path $OutputProject $AssetPath
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force

    $sourceMeta = "$sourcePath.meta"
    if (Test-Path -LiteralPath $sourceMeta -PathType Leaf) {
        Copy-Item -LiteralPath $sourceMeta -Destination "$targetPath.meta" -Force
    }

    return $true
}

function Get-GuidReferences {
    param([Parameter(Mandatory = $true)][string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $textExtensions = @(
        '.anim',
        '.asset',
        '.controller',
        '.cs',
        '.lighting',
        '.mat',
        '.overridecontroller',
        '.playable',
        '.prefab',
        '.shader',
        '.unity'
    )
    if ($textExtensions -notcontains $extension) {
        return @()
    }

    try {
        return Select-String -LiteralPath $Path -Pattern 'guid: ([0-9a-f]{32})' -AllMatches |
            ForEach-Object { $_.Matches.Groups[1].Value } |
            Sort-Object -Unique
    }
    catch {
        return @()
    }
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$SourceProjectPath = Get-CanonicalPath $SourceProjectPath
$OutputProjectPath = Get-CanonicalPath $OutputProjectPath
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
    $ReportRoot = Join-Path $extractedRoot 'DependencyIndex'
}
$ReportRoot = Get-CanonicalPath $ReportRoot

Assert-PathUnderOrEqual -Path $SourceProjectPath -RootPath $extractedRoot -Description 'SourceProjectPath'
Assert-PathUnderOrEqual -Path $OutputProjectPath -RootPath $extractedRoot -Description 'OutputProjectPath'
Assert-PathUnderOrEqual -Path $ReportRoot -RootPath $extractedRoot -Description 'ReportRoot'

if (-not (Test-Path -LiteralPath (Join-Path $SourceProjectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) {
    throw "Source project is missing ProjectSettings/ProjectVersion.txt: $SourceProjectPath"
}

foreach ($assetPath in $RootAssetPath) {
    Assert-SafeProjectAssetPath -Path $assetPath
}

New-Item -ItemType Directory -Force -Path $OutputProjectPath | Out-Null
New-Item -ItemType Directory -Force -Path $ReportRoot | Out-Null
Copy-DirectoryIfPresent -Name 'Packages' -SourceProject $SourceProjectPath -OutputProject $OutputProjectPath
Copy-DirectoryIfPresent -Name 'ProjectSettings' -SourceProject $SourceProjectPath -OutputProject $OutputProjectPath
New-Item -ItemType Directory -Force -Path (Join-Path $OutputProjectPath 'Assets') | Out-Null

$guidToAsset = @{}
Get-ChildItem -LiteralPath (Join-Path $SourceProjectPath 'Assets') -Recurse -File -Filter '*.meta' | ForEach-Object {
    $guidLine = Select-String -LiteralPath $_.FullName -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $guidLine) {
        return
    }

    $assetFullPath = $_.FullName.Substring(0, $_.FullName.Length - 5)
    if (-not (Test-Path -LiteralPath $assetFullPath -PathType Leaf)) {
        return
    }

    $assetPath = $assetFullPath.Substring($SourceProjectPath.Length + 1).Replace('\', '/')
    $guidToAsset[$guidLine.Matches.Groups[1].Value] = $assetPath
}

$queue = [System.Collections.Generic.Queue[string]]::new()
$visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$missing = [System.Collections.Generic.List[object]]::new()
$copied = [System.Collections.Generic.List[object]]::new()

foreach ($assetPath in $RootAssetPath) {
    $queue.Enqueue($assetPath.Replace('\', '/'))
}

while ($queue.Count -gt 0) {
    $assetPath = $queue.Dequeue()
    if (-not $visited.Add($assetPath)) {
        continue
    }

    $sourceFile = Join-Path $SourceProjectPath $assetPath
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        $missing.Add([PSCustomObject]@{
            Type = 'MissingAssetPath'
            AssetPath = $assetPath
            Guid = ''
        })
        continue
    }

    [void](Copy-ProjectAssetFile -AssetPath $assetPath -SourceProject $SourceProjectPath -OutputProject $OutputProjectPath)
    $copied.Add([PSCustomObject]@{
        AssetPath = $assetPath
        Length = (Get-Item -LiteralPath $sourceFile).Length
    })

    foreach ($guid in Get-GuidReferences -Path $sourceFile) {
        if ($guidToAsset.ContainsKey($guid)) {
            $queue.Enqueue($guidToAsset[$guid])
        }
        else {
            $missing.Add([PSCustomObject]@{
                Type = 'MissingGuid'
                AssetPath = $assetPath
                Guid = $guid
            })
        }
    }
}

$sliceName = Split-Path -Leaf (Split-Path -Parent $OutputProjectPath)
$safeSliceName = if ([string]::IsNullOrWhiteSpace($sliceName)) { 'UnityGuidClosureSlice' } else { $sliceName }
$copiedCsv = Join-Path $ReportRoot "$safeSliceName-guid-closure-copied.csv"
$missingCsv = Join-Path $ReportRoot "$safeSliceName-guid-closure-missing.csv"
$summaryJson = Join-Path $ReportRoot "$safeSliceName-guid-closure-summary.json"

$copied | Export-Csv -LiteralPath $copiedCsv -NoTypeInformation -Encoding UTF8
$missing | Export-Csv -LiteralPath $missingCsv -NoTypeInformation -Encoding UTF8
[PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    SourceProjectPath = $SourceProjectPath
    OutputProjectPath = $OutputProjectPath
    RootAssetPath = $RootAssetPath
    CopiedAssetCount = $copied.Count
    MissingReferenceCount = $missing.Count
    CopiedCsv = $copiedCsv
    MissingCsv = $missingCsv
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

[PSCustomObject]@{
    CopiedAssetCount = $copied.Count
    MissingReferenceCount = $missing.Count
    OutputProjectPath = $OutputProjectPath
    SummaryJson = $summaryJson
} | Format-List
