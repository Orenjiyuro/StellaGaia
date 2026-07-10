[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$OutputRoot
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

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = Get-CanonicalPath $Path
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description 'Relative path source'

    if ([string]::Equals($root, $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }

    return $candidate.Substring(($root + [System.IO.Path]::DirectorySeparatorChar).Length)
}

function Get-TopDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        return ''
    }

    return ($RelativePath -split '[\\/]')[0]
}

function Get-AssetCategory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Extension,
        [Parameter(Mandatory = $true)]
        [string]$BaseName,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $name = $BaseName.ToLowerInvariant()
    $path = $RelativePath.ToLowerInvariant()

    switch ($Extension.ToLowerInvariant()) {
        '.unity3d' {
            if ($name -match '^char[_-]') { return 'CharacterArt' }
            if ($name -match '^mons[_-]') { return 'EnemyArt' }
            if ($name -match '^(npc|storyactivity|story_activity|talk|dialog)[_-]') { return 'NpcOrStoryArt' }
            if ($name -match '^(env|roguelike|map|scene|level|terrain)[_-]') { return 'EnvironmentArt' }
            if ($name -match '^(fx|vfx|effect)[_-]') { return 'EffectArt' }
            if ($name -match '^(ui|icon|item|card|drop|buff|equip|weapon|relic)[_-]?') { return 'UiOrItemArt' }
            if ($name -match '^(spine|live2d|portrait|avatar|emoji)[_-]') { return 'CharacterUiArt' }
            if ($path -match '[\\/]assetbundles[\\/]') { return 'AssetBundleOther' }
            return 'UnityBundleOther'
        }
        '.wem' {
            if ($name -match '^(vo|voice)[_-]' -or $path -match '[\\/]voice') { return 'VoiceAudio' }
            if ($name -match '(music|bgm|battle|combat)' -or $path -match '[\\/]media[\\/]') { return 'MusicAudioCandidate' }
            return 'SfxAudioCandidate'
        }
        '.bnk' { return 'WwiseBankMetadata' }
        '.mp4' { return 'VideoArt' }
        '.srt' { return 'SubtitleCompanion' }
        default { return 'OtherResourceCandidate' }
    }
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Inventory'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.sourceInstall) -or -not (Test-Path -LiteralPath $manifest.sourceInstall -PathType Container)) {
    throw "Missing source install directory: $($manifest.sourceInstall)"
}

$sourceInstall = Get-CanonicalPath $manifest.sourceInstall
$outputRootInfo = [System.IO.Directory]::CreateDirectory($OutputRoot)
$OutputRoot = $outputRootInfo.FullName
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

$extensions = @('.unity3d', '.wem', '.bnk', '.mp4', '.srt')
$files = Get-ChildItem -LiteralPath $sourceInstall -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object FullName

$inventory = foreach ($file in $files) {
    $relativePath = Get-RelativePath -RootPath $sourceInstall -Path $file.FullName
    $category = Get-AssetCategory -Extension $file.Extension -BaseName $file.BaseName -RelativePath $relativePath

    [PSCustomObject]@{
        Category = $category
        Extension = $file.Extension.ToLowerInvariant()
        TopDirectory = Get-TopDirectory -RelativePath $relativePath
        RelativePath = $relativePath
        Length = $file.Length
        LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('O')
    }
}

$summaryByCategory = $inventory |
    Group-Object Category |
    Sort-Object Count -Descending |
    ForEach-Object {
        [PSCustomObject]@{
            Category = $_.Name
            Count = $_.Count
            TotalBytes = ($_.Group | Measure-Object Length -Sum).Sum
        }
    }

$summaryByExtension = $inventory |
    Group-Object Extension |
    Sort-Object Count -Descending |
    ForEach-Object {
        [PSCustomObject]@{
            Extension = $_.Name
            Count = $_.Count
            TotalBytes = ($_.Group | Measure-Object Length -Sum).Sum
        }
    }

$summaryByTopDirectory = $inventory |
    Group-Object TopDirectory |
    Sort-Object Count -Descending |
    ForEach-Object {
        [PSCustomObject]@{
            TopDirectory = $_.Name
            Count = $_.Count
            TotalBytes = ($_.Group | Measure-Object Length -Sum).Sum
        }
    }

$summary = [PSCustomObject]@{
    SourceInstall = $sourceInstall
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    TotalCount = @($inventory).Count
    TotalBytes = ($inventory | Measure-Object Length -Sum).Sum
    ByCategory = @($summaryByCategory)
    ByExtension = @($summaryByExtension)
    ByTopDirectory = @($summaryByTopDirectory)
}

$inventoryJsonPath = Get-CanonicalPath (Join-Path $OutputRoot 'asset-inventory.json')
$inventoryCsvPath = Get-CanonicalPath (Join-Path $OutputRoot 'asset-inventory.csv')
$summaryJsonPath = Get-CanonicalPath (Join-Path $OutputRoot 'asset-inventory-summary.json')
Assert-PathUnderOrEqual -Path $inventoryJsonPath -RootPath $OutputRoot -Description 'Inventory JSON path'
Assert-PathUnderOrEqual -Path $inventoryCsvPath -RootPath $OutputRoot -Description 'Inventory CSV path'
Assert-PathUnderOrEqual -Path $summaryJsonPath -RootPath $OutputRoot -Description 'Summary JSON path'

$inventory | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $inventoryJsonPath -Encoding UTF8
$inventory | Export-Csv -LiteralPath $inventoryCsvPath -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8

$summary.ByCategory | Format-Table Category,Count,TotalBytes -AutoSize
Write-Host "Inventory written to $inventoryJsonPath"
Write-Host "Summary written to $summaryJsonPath"
