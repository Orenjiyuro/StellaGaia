[CmdletBinding()]
param(
    [string]$AndroidRoot,
    [string]$PcRawAssetRoot,
    [string]$OutputRoot,
    [string]$TargetPattern = '(?i)(roguelike|env_roguelike|level_common_roguelike|env_breakout_roguelike)'
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

function Get-BundleCategory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseName,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $name = $BaseName.ToLowerInvariant()
    $path = $RelativePath.ToLowerInvariant()

    if ($name -match '^char[_-]') { return 'CharacterArt' }
    if ($name -match '^mons[_-]') { return 'EnemyArt' }
    if ($name -match '^(npc|storyactivity|story_activity|talk|dialog)[_-]') { return 'NpcOrStoryArt' }
    if ($name -match '^(env|roguelike|map|scene|level|terrain)[_-]' -or $path -match 'roguelike') { return 'EnvironmentArt' }
    if ($name -match '^(fx|vfx|effect)[_-]') { return 'EffectArt' }
    if ($name -match '^(ui|icon|item|card|drop|buff|equip|weapon|relic)[_-]?') { return 'UiOrItemArt' }
    if ($name -match '^(spine|live2d|portrait|avatar|emoji)[_-]') { return 'CharacterUiArt' }
    return 'UnityBundleOther'
}

function New-BundleRecord {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Container,
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,
        [Parameter(Mandatory = $true)]
        [long]$Length
    )

    $normalized = $RelativePath.Replace('\', '/')
    $fileName = [System.IO.Path]::GetFileName($normalized)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

    return [PSCustomObject]@{
        Source = $Source
        Container = $Container
        RelativePath = $RelativePath
        FileName = $fileName
        BaseName = $baseName.ToLowerInvariant()
        Category = Get-BundleCategory -BaseName $baseName -RelativePath $RelativePath
        Length = [int64]$Length
        IsTarget = $normalized -match $TargetPattern
    }
}

function Read-ApkUnityEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApkPath,
        [Parameter(Mandatory = $true)]
        [string]$AndroidRootPath
    )

    $records = New-Object System.Collections.Generic.List[object]
    $apkRelative = Get-RelativePath -RootPath $AndroidRootPath -Path $ApkPath
    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
    } catch {
        Write-Warning "Cannot read APK as zip: $ApkPath. $($_.Exception.Message)"
        return @()
    }

    try {
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName -notmatch '(?i)\.unity3d$') {
                continue
            }

            $records.Add((New-BundleRecord -Source 'AndroidApk' -Container $apkRelative -RelativePath "$apkRelative!/$($entry.FullName)" -Length $entry.Length)) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }

    return @($records.ToArray())
}

function Read-FileUnityEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [string]$Container
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return @()
    }

    $records = New-Object System.Collections.Generic.List[object]
    $files = Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.unity3d' -Force -ErrorAction SilentlyContinue | Sort-Object FullName
    foreach ($file in $files) {
        $relativePath = Get-RelativePath -RootPath $RootPath -Path $file.FullName
        $records.Add((New-BundleRecord -Source $Source -Container $Container -RelativePath $relativePath -Length $file.Length)) | Out-Null
    }

    return @($records.ToArray())
}

function Get-FirstRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Records
    )

    if ($Records.Count -eq 0) {
        return ''
    }

    return [string]$Records[0].RelativePath
}

function Add-RecordToGroupMap {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    $key = [string]$Record.BaseName
    if (-not $Map.ContainsKey($key)) {
        $Map[$key] = New-Object System.Collections.Generic.List[object]
    }

    $Map[$key].Add($Record) | Out-Null
}

function Get-GroupRecords {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    if (-not $Map.ContainsKey($BaseName)) {
        return @()
    }

    return @($Map[$BaseName].ToArray())
}

if ([string]::IsNullOrWhiteSpace($AndroidRoot)) {
    $AndroidRoot = Join-Path $PSScriptRoot '..\..\Android'
}
if ([string]::IsNullOrWhiteSpace($PcRawAssetRoot)) {
    $PcRawAssetRoot = Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\AndroidPcBundleComparison'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$AndroidRoot = Get-CanonicalPath $AndroidRoot
$PcRawAssetRoot = Get-CanonicalPath $PcRawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $PcRawAssetRoot -RootPath $extractedRoot -Description 'PcRawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $PcRawAssetRoot -RootPath $extractedRoot -Description 'PcRawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $AndroidRoot -PathType Container)) {
    throw "Missing Android input root: $AndroidRoot"
}
if (-not (Test-Path -LiteralPath $PcRawAssetRoot -PathType Container)) {
    throw "Missing PC raw asset root: $PcRawAssetRoot"
}

[System.Reflection.Assembly]::Load('System.IO.Compression.FileSystem') | Out-Null
[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$pcRecords = @(Read-FileUnityEntries -RootPath $PcRawAssetRoot -Source 'PcRawAssets' -Container $PcRawAssetRoot)
$androidDataRoot = Join-Path $AndroidRoot 'DATA'
$androidDataRecords = @(Read-FileUnityEntries -RootPath $androidDataRoot -Source 'AndroidData' -Container $androidDataRoot)
$apkRecords = New-Object System.Collections.Generic.List[object]
$apkFiles = Get-ChildItem -LiteralPath $AndroidRoot -Recurse -File -Filter '*.apk' -Force -ErrorAction SilentlyContinue | Sort-Object FullName
foreach ($apk in $apkFiles) {
    foreach ($record in (Read-ApkUnityEntries -ApkPath $apk.FullName -AndroidRootPath $AndroidRoot)) {
        $apkRecords.Add($record) | Out-Null
    }
}

$androidRecords = @($androidDataRecords + @($apkRecords.ToArray()))
$allRecords = @($pcRecords + $androidRecords)

$pcByBaseName = @{}
foreach ($record in $pcRecords) {
    Add-RecordToGroupMap -Map $pcByBaseName -Record $record
}

$androidByBaseName = @{}
foreach ($record in $androidRecords) {
    Add-RecordToGroupMap -Map $androidByBaseName -Record $record
}

$baseNameSet = @{}
foreach ($baseName in $pcByBaseName.Keys) {
    $baseNameSet[$baseName] = $true
}
foreach ($baseName in $androidByBaseName.Keys) {
    $baseNameSet[$baseName] = $true
}

$comparisonRows = New-Object System.Collections.Generic.List[object]
$allBaseNames = @($baseNameSet.Keys | Sort-Object)
foreach ($baseName in $allBaseNames) {
    $pc = @(Get-GroupRecords -Map $pcByBaseName -BaseName $baseName)
    $android = @(Get-GroupRecords -Map $androidByBaseName -BaseName $baseName)
    $allForName = @($pc + $android)
    $sourcePresence = if ($pc.Count -gt 0 -and $android.Count -gt 0) {
        'Both'
    } elseif ($android.Count -gt 0) {
        'AndroidOnly'
    } else {
        'PcOnly'
    }

    $pcLengths = @($pc | Select-Object -ExpandProperty Length -Unique | Sort-Object)
    $androidLengths = @($android | Select-Object -ExpandProperty Length -Unique | Sort-Object)
    $sameLength = $false
    foreach ($length in $pcLengths) {
        if ($androidLengths -contains $length) {
            $sameLength = $true
            break
        }
    }

    $comparisonRows.Add([PSCustomObject]@{
        BaseName = $baseName
        Category = ($allForName | Select-Object -First 1).Category
        SourcePresence = $sourcePresence
        IsTarget = @($allForName | Where-Object { $_.IsTarget }).Count -gt 0
        PcCount = $pc.Count
        AndroidCount = $android.Count
        PcLengths = ($pcLengths -join ';')
        AndroidLengths = ($androidLengths -join ';')
        AnySameLength = $sameLength
        PcExample = Get-FirstRelativePath -Records $pc
        AndroidExample = Get-FirstRelativePath -Records $android
    }) | Out-Null
}

$comparison = @($comparisonRows.ToArray())
$targetRows = @($comparison | Where-Object { $_.IsTarget })
$targetEnvironmentRows = @($targetRows | Where-Object { $_.Category -eq 'EnvironmentArt' })
$androidOnlyTargetRows = @($targetEnvironmentRows | Where-Object { $_.SourcePresence -eq 'AndroidOnly' })
$bothDifferentLengthRows = @($targetEnvironmentRows | Where-Object { $_.SourcePresence -eq 'Both' -and -not $_.AnySameLength })

$summaryByPresence = $comparison |
    Group-Object SourcePresence |
    Sort-Object Name |
    ForEach-Object { [PSCustomObject]@{ SourcePresence = $_.Name; Count = $_.Count } }

$targetSummaryByPresence = $targetEnvironmentRows |
    Group-Object SourcePresence |
    Sort-Object Name |
    ForEach-Object { [PSCustomObject]@{ SourcePresence = $_.Name; Count = $_.Count } }

$report = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    AndroidRoot = $AndroidRoot
    PcRawAssetRoot = $PcRawAssetRoot
    OutputRoot = $OutputRoot
    TargetPattern = $TargetPattern
    Totals = [ordered]@{
        PcUnity3d = $pcRecords.Count
        AndroidDataUnity3d = $androidDataRecords.Count
        AndroidApkUnity3d = $apkRecords.Count
        AndroidUnity3d = $androidRecords.Count
        ComparedBaseNames = $comparison.Count
        TargetEnvironmentBaseNames = $targetEnvironmentRows.Count
        AndroidOnlyTargetEnvironmentBaseNames = $androidOnlyTargetRows.Count
        BothDifferentLengthTargetEnvironmentBaseNames = $bothDifferentLengthRows.Count
    }
    SummaryByPresence = @($summaryByPresence)
    TargetEnvironmentSummaryByPresence = @($targetSummaryByPresence)
    AndroidOnlyTargetEnvironmentCandidates = @($androidOnlyTargetRows | Select-Object -First 100)
    BothDifferentLengthTargetEnvironmentCandidates = @($bothDifferentLengthRows | Select-Object -First 100)
    Safety = [ordered]@{
        WritesOnlyUnder = $extractedRoot
        Notes = 'This comparison is read-only for Android and PC input roots. It does not extract archives or import Unity assets.'
    }
}

$allRecordsPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-pc-unity-bundle-records.csv')
$comparisonPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-pc-unity-bundle-comparison.csv')
$targetPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-pc-roguelike-bundle-comparison.csv')
$summaryPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-pc-bundle-comparison-summary.json')
$markdownPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-pc-roguelike-bundle-comparison.md')

Assert-PathUnderOrEqual -Path $allRecordsPath -RootPath $OutputRoot -Description 'All records path'
Assert-PathUnderOrEqual -Path $comparisonPath -RootPath $OutputRoot -Description 'Comparison path'
Assert-PathUnderOrEqual -Path $targetPath -RootPath $OutputRoot -Description 'Target comparison path'
Assert-PathUnderOrEqual -Path $summaryPath -RootPath $OutputRoot -Description 'Summary path'
Assert-PathUnderOrEqual -Path $markdownPath -RootPath $OutputRoot -Description 'Markdown path'

$allRecords | Export-Csv -LiteralPath $allRecordsPath -NoTypeInformation -Encoding UTF8
$comparison | Export-Csv -LiteralPath $comparisonPath -NoTypeInformation -Encoding UTF8
$targetEnvironmentRows | Export-Csv -LiteralPath $targetPath -NoTypeInformation -Encoding UTF8
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$markdown = @(
    '# Android/PC Roguelike Bundle Comparison',
    '',
    "Generated: $($report.GeneratedAt)",
    '',
    '| Metric | Count |',
    '| --- | ---: |',
    "| PC `.unity3d` records | $($report.Totals.PcUnity3d) |",
    "| Android DATA `.unity3d` records | $($report.Totals.AndroidDataUnity3d) |",
    "| Android APK `.unity3d` records | $($report.Totals.AndroidApkUnity3d) |",
    "| Compared base names | $($report.Totals.ComparedBaseNames) |",
    "| Target EnvironmentArt base names | $($report.Totals.TargetEnvironmentBaseNames) |",
    "| Android-only target EnvironmentArt base names | $($report.Totals.AndroidOnlyTargetEnvironmentBaseNames) |",
    "| Both-present target EnvironmentArt with different lengths | $($report.Totals.BothDifferentLengthTargetEnvironmentBaseNames) |",
    '',
    '## Target Environment Presence',
    '',
    '| Presence | Count |',
    '| --- | ---: |'
)
foreach ($row in $targetSummaryByPresence) {
    $markdown += "| $($row.SourcePresence) | $($row.Count) |"
}
$markdown += @(
    '',
    '## Android-Only Target Environment Candidates',
    '',
    '| Base name | Android example |',
    '| --- | --- |'
)
foreach ($row in ($androidOnlyTargetRows | Select-Object -First 30)) {
    $baseName = [string]$row.BaseName
    $androidExample = [string]$row.AndroidExample
    $markdown += "| ``$baseName`` | ``$androidExample`` |"
}
$markdown += @(
    '',
    '## Both-Present Different-Length Target Candidates',
    '',
    '| Base name | PC lengths | Android lengths | PC example | Android example |',
    '| --- | ---: | ---: | --- | --- |'
)
foreach ($row in ($bothDifferentLengthRows | Select-Object -First 30)) {
    $baseName = [string]$row.BaseName
    $pcLengths = [string]$row.PcLengths
    $androidLengths = [string]$row.AndroidLengths
    $pcExample = [string]$row.PcExample
    $androidExample = [string]$row.AndroidExample
    $markdown += "| ``$baseName`` | ``$pcLengths`` | ``$androidLengths`` | ``$pcExample`` | ``$androidExample`` |"
}
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[PSCustomObject]@{
    PcUnity3d = $pcRecords.Count
    AndroidDataUnity3d = $androidDataRecords.Count
    AndroidApkUnity3d = $apkRecords.Count
    TargetEnvironmentBaseNames = $targetEnvironmentRows.Count
    AndroidOnlyTargetEnvironmentBaseNames = $androidOnlyTargetRows.Count
    BothDifferentLengthTargetEnvironmentBaseNames = $bothDifferentLengthRows.Count
    Summary = $summaryPath
    TargetCsv = $targetPath
} | Format-List
