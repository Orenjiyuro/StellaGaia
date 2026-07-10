[CmdletBinding()]
param(
    [string]$InputRoot,
    [string]$OutputRoot,
    [long]$InspectNestedArchiveMaxBytes = 536870912
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

function New-IndicatorCounters {
    return [ordered]@{
        ApkFiles = 0
        SplitApkFiles = 0
        ApksArchives = 0
        XapkArchives = 0
        ObbFiles = 0
        AssetPackFiles = 0
        UnityPlayerLibraries = 0
        UnityDataEntries = 0
        StreamingAssetsEntries = 0
        AssetBundleEntries = 0
        AddressablesCatalogEntries = 0
        WwiseBankEntries = 0
        WemEntries = 0
        AssetCacheCandidates = 0
        UnitySerializedAssetEntries = 0
    }
}

function Convert-CountersToObject {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Counters
    )

    return [PSCustomObject]@{
        ApkFiles = [int]$Counters.ApkFiles
        SplitApkFiles = [int]$Counters.SplitApkFiles
        ApksArchives = [int]$Counters.ApksArchives
        XapkArchives = [int]$Counters.XapkArchives
        ObbFiles = [int]$Counters.ObbFiles
        AssetPackFiles = [int]$Counters.AssetPackFiles
        UnityPlayerLibraries = [int]$Counters.UnityPlayerLibraries
        UnityDataEntries = [int]$Counters.UnityDataEntries
        StreamingAssetsEntries = [int]$Counters.StreamingAssetsEntries
        AssetBundleEntries = [int]$Counters.AssetBundleEntries
        AddressablesCatalogEntries = [int]$Counters.AddressablesCatalogEntries
        WwiseBankEntries = [int]$Counters.WwiseBankEntries
        WemEntries = [int]$Counters.WemEntries
        AssetCacheCandidates = [int]$Counters.AssetCacheCandidates
        UnitySerializedAssetEntries = [int]$Counters.UnitySerializedAssetEntries
    }
}

function Add-Counter {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Counters,
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [int]$Amount = 1
    )

    $Counters[$Name] = [int]$Counters[$Name] + $Amount
}

function Get-IndicatorTags {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [bool]$IsArchiveEntry
    )

    $normalized = $Name.Replace('\', '/').ToLowerInvariant()
    $fileName = [System.IO.Path]::GetFileName($normalized)
    $extension = [System.IO.Path]::GetExtension($fileName)
    $tags = New-Object System.Collections.Generic.List[string]

    if ($extension -eq '.apk') { $tags.Add('ApkFiles') }
    if ($fileName -match '(^|[._-])split[._-]' -or $fileName -match 'config\.[a-z0-9_]+\.apk$') { $tags.Add('SplitApkFiles') }
    if ($extension -eq '.apks') { $tags.Add('ApksArchives') }
    if ($extension -eq '.xapk') { $tags.Add('XapkArchives') }
    if ($extension -eq '.obb') { $tags.Add('ObbFiles') }
    if ($normalized -match 'asset[_-]?pack' -or $normalized -match '/assetpacks?/' -or $normalized -match '\.assetpack$') { $tags.Add('AssetPackFiles') }
    if ($normalized -match 'libunity\.so$' -or $normalized -match 'unityplayer') { $tags.Add('UnityPlayerLibraries') }
    if ($normalized -match 'assets/bin/data/' -or $fileName -in @('globalgamemanagers', 'resources.assets', 'sharedassets0.assets', 'data.unity3d')) { $tags.Add('UnityDataEntries') }
    if ($normalized -match 'assets/streamingassets/' -or $normalized -match 'assets/aa/' -or $normalized -match 'streamingassets/') { $tags.Add('StreamingAssetsEntries') }
    if ($extension -in @('.unity3d', '.bundle', '.ab') -or $normalized -match '/assetbundles?/' -or $normalized -match '/bundles?/' -or $normalized -match '\.bundle$') { $tags.Add('AssetBundleEntries') }
    if ($fileName -match '^catalog.*\.json$' -or $normalized -match 'addressables' -or $normalized -match 'settings\.json$') { $tags.Add('AddressablesCatalogEntries') }
    if ($extension -eq '.bnk') { $tags.Add('WwiseBankEntries') }
    if ($extension -eq '.wem') { $tags.Add('WemEntries') }
    if ($extension -in @('.assets', '.resource', '.ress', '.res') -or $fileName -match '^sharedassets\d+\.assets$') { $tags.Add('UnitySerializedAssetEntries') }
    if (-not $IsArchiveEntry -and ($normalized -match 'android/data/' -or $normalized -match 'android/obb/' -or $normalized -match '/cache/' -or $normalized -match '/files/')) { $tags.Add('AssetCacheCandidates') }

    return @($tags)
}

function Add-IndicatorEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Counters,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Evidence,
        [Parameter(Mandatory = $true)]
        [string]$Location,
        [Parameter(Mandatory = $true)]
        [long]$Length,
        [Parameter(Mandatory = $true)]
        [bool]$IsArchiveEntry
    )

    $tags = Get-IndicatorTags -Name $Location -IsArchiveEntry $IsArchiveEntry
    foreach ($tag in $tags) {
        Add-Counter -Counters $Counters -Name $tag
    }

    if ($tags.Count -gt 0 -and $Evidence.Count -lt 500) {
        $Evidence.Add([PSCustomObject]@{
            Location = $Location
            Length = $Length
            Tags = @($tags)
        }) | Out-Null
    }
}

function Read-ArchiveEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArchivePath,
        [Parameter(Mandatory = $true)]
        [string]$ArchiveLabel,
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Counters,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Evidence,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$ArchiveDiagnostics
    )

    try {
        $archive = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    } catch {
        $ArchiveDiagnostics.Add([PSCustomObject]@{
            Archive = $ArchiveLabel
            Status = 'NotZipReadable'
            Message = $_.Exception.Message
        }) | Out-Null
        return
    }

    try {
        foreach ($entry in $archive.Entries) {
            $entryLabel = "$ArchiveLabel!/$($entry.FullName)"
            Add-IndicatorEvidence -Counters $Counters -Evidence $Evidence -Location $entryLabel -Length $entry.Length -IsArchiveEntry $true

            $entryName = $entry.FullName.ToLowerInvariant()
            if (($entryName.EndsWith('.apk') -or $entryName.EndsWith('.zip')) -and $entry.Length -gt 0) {
                if ($entry.Length -gt $InspectNestedArchiveMaxBytes) {
                    $ArchiveDiagnostics.Add([PSCustomObject]@{
                        Archive = $entryLabel
                        Status = 'NestedArchiveSkipped'
                        Message = "Nested archive is larger than InspectNestedArchiveMaxBytes=$InspectNestedArchiveMaxBytes"
                    }) | Out-Null
                    continue
                }

                try {
                    $memory = New-Object System.IO.MemoryStream
                    $entryStream = $entry.Open()
                    try {
                        $entryStream.CopyTo($memory)
                    } finally {
                        $entryStream.Dispose()
                    }
                    $memory.Position = 0
                    $nested = [System.IO.Compression.ZipArchive]::new($memory, [System.IO.Compression.ZipArchiveMode]::Read, $false)
                    try {
                        foreach ($nestedEntry in $nested.Entries) {
                            $nestedLabel = "$entryLabel!/$($nestedEntry.FullName)"
                            Add-IndicatorEvidence -Counters $Counters -Evidence $Evidence -Location $nestedLabel -Length $nestedEntry.Length -IsArchiveEntry $true
                        }
                    } finally {
                        $nested.Dispose()
                        $memory.Dispose()
                    }
                } catch {
                    $ArchiveDiagnostics.Add([PSCustomObject]@{
                        Archive = $entryLabel
                        Status = 'NestedArchiveUnreadable'
                        Message = $_.Exception.Message
                    }) | Out-Null
                }
            }
        }

        $ArchiveDiagnostics.Add([PSCustomObject]@{
            Archive = $ArchiveLabel
            Status = 'Read'
            Message = "Entries=$($archive.Entries.Count)"
        }) | Out-Null
    } finally {
        $archive.Dispose()
    }
}

function Get-UsefulnessAssessment {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Counters
    )

    $hasUnityRuntime = [int]$Counters.UnityPlayerLibraries -gt 0 -or [int]$Counters.UnityDataEntries -gt 0
    $hasUnityContent = [int]$Counters.UnityDataEntries -gt 0 -or [int]$Counters.AssetBundleEntries -gt 0 -or [int]$Counters.UnitySerializedAssetEntries -gt 0
    $hasDependencyMaps = [int]$Counters.AddressablesCatalogEntries -gt 0
    $hasExternalPayload = [int]$Counters.ObbFiles -gt 0 -or [int]$Counters.AssetPackFiles -gt 0 -or [int]$Counters.AssetCacheCandidates -gt 0
    $hasAudioMetadata = [int]$Counters.WwiseBankEntries -gt 0 -or [int]$Counters.WemEntries -gt 0

    if ($hasUnityContent -and ($hasDependencyMaps -or $hasExternalPayload -or [int]$Counters.AssetBundleEntries -gt 10)) {
        return [PSCustomObject]@{
            PotentialUsefulness = 'High'
            GateDecision = 'ProceedToDependencyComparison'
            Reason = 'Android input appears to contain Unity content plus dependency, bundle, cache, OBB, or asset-pack evidence.'
        }
    }

    if ($hasUnityContent -or ($hasUnityRuntime -and ($hasExternalPayload -or $hasAudioMetadata))) {
        return [PSCustomObject]@{
            PotentialUsefulness = 'Medium'
            GateDecision = 'ProceedWithLimitedExpectations'
            Reason = 'Android input contains Unity or audio payload evidence, but dependency closure evidence is incomplete.'
        }
    }

    if ([int]$Counters.ApkFiles -gt 0 -or [int]$Counters.ApksArchives -gt 0 -or [int]$Counters.XapkArchives -gt 0) {
        return [PSCustomObject]@{
            PotentialUsefulness = 'Low'
            GateDecision = 'NeedCompleteInstallPayload'
            Reason = 'APK-like files are present, but no Unity asset payload was detected by the lightweight scan.'
        }
    }

    return [PSCustomObject]@{
        PotentialUsefulness = 'Unknown'
        GateDecision = 'MissingInput'
        Reason = 'No Android package or cache input was found.'
    }
}

if ([string]::IsNullOrWhiteSpace($InputRoot)) {
    $repoAndroidInput = Join-Path $PSScriptRoot '..\..\Android'
    if (Test-Path -LiteralPath $repoAndroidInput) {
        $InputRoot = $repoAndroidInput
    } else {
        $InputRoot = Join-Path $PSScriptRoot '..\..\Extracted\AndroidInput'
    }
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\AndroidIntake'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$inputRootFull = Get-CanonicalPath $InputRoot
$outputRootFull = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $outputRootFull -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
$outputRootInfo = [System.IO.Directory]::CreateDirectory($outputRootFull)
$outputRootFull = $outputRootInfo.FullName
Assert-NoExistingReparsePointUnderRoot -Path $outputRootFull -RootPath $extractedRoot -Description 'OutputRoot'

[System.Reflection.Assembly]::Load('System.IO.Compression.FileSystem') | Out-Null

$counters = New-IndicatorCounters
$evidence = New-Object System.Collections.Generic.List[object]
$archiveDiagnostics = New-Object System.Collections.Generic.List[object]
$fileRows = New-Object System.Collections.Generic.List[object]

if (Test-Path -LiteralPath $inputRootFull -PathType Container) {
    Assert-NoExistingReparsePointUnderRoot -Path $inputRootFull -RootPath $inputRootFull -Description 'InputRoot'

    $files = Get-ChildItem -LiteralPath $inputRootFull -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object FullName
    foreach ($file in $files) {
        $relativePath = Get-RelativePath -RootPath $inputRootFull -Path $file.FullName
        Add-IndicatorEvidence -Counters $counters -Evidence $evidence -Location $relativePath -Length $file.Length -IsArchiveEntry $false

        $fileRows.Add([PSCustomObject]@{
            RelativePath = $relativePath
            Extension = $file.Extension.ToLowerInvariant()
            Length = $file.Length
            LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('O')
        }) | Out-Null

        if ($file.Extension.ToLowerInvariant() -in @('.apk', '.apks', '.xapk', '.zip', '.obb')) {
            Read-ArchiveEntries -ArchivePath $file.FullName -ArchiveLabel $relativePath -Counters $counters -Evidence $evidence -ArchiveDiagnostics $archiveDiagnostics
        }
    }
} elseif (Test-Path -LiteralPath $inputRootFull -PathType Leaf) {
    $parent = Split-Path -Parent $inputRootFull
    $relativePath = Split-Path -Leaf $inputRootFull
    $file = Get-Item -LiteralPath $inputRootFull -Force
    Add-IndicatorEvidence -Counters $counters -Evidence $evidence -Location $relativePath -Length $file.Length -IsArchiveEntry $false
    $fileRows.Add([PSCustomObject]@{
        RelativePath = $relativePath
        Extension = $file.Extension.ToLowerInvariant()
        Length = $file.Length
        LastWriteTimeUtc = $file.LastWriteTimeUtc.ToString('O')
    }) | Out-Null

    if ($file.Extension.ToLowerInvariant() -in @('.apk', '.apks', '.xapk', '.zip', '.obb')) {
        Read-ArchiveEntries -ArchivePath $file.FullName -ArchiveLabel $relativePath -Counters $counters -Evidence $evidence -ArchiveDiagnostics $archiveDiagnostics
    }
} else {
    $archiveDiagnostics.Add([PSCustomObject]@{
        Archive = $inputRootFull
        Status = 'MissingInput'
        Message = 'InputRoot does not exist. Place base APK, split APKs, APKS/XAPK, OBB, asset packs, or Android/data cache here before rerunning.'
    }) | Out-Null
}

$assessment = Get-UsefulnessAssessment -Counters $counters
$counterObject = Convert-CountersToObject -Counters $counters
$evidenceArray = @($evidence.ToArray())
$archiveDiagnosticsArray = @($archiveDiagnostics.ToArray())
$report = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    InputRoot = $inputRootFull
    OutputRoot = $outputRootFull
    Safety = [ordered]@{
        WritesOnlyUnder = $extractedRoot
        SourceInstallUntouched = $true
        Notes = 'This script performs read-only scanning on InputRoot and writes report files only under OutputRoot.'
    }
    Counters = $counterObject
    Assessment = $assessment
    Evidence = $evidenceArray
    ArchiveDiagnostics = $archiveDiagnosticsArray
}

$reportJsonPath = Get-CanonicalPath (Join-Path $outputRootFull 'android-intake-report.json')
$fileCsvPath = Get-CanonicalPath (Join-Path $outputRootFull 'android-intake-files.csv')
Assert-PathUnderOrEqual -Path $reportJsonPath -RootPath $outputRootFull -Description 'Report JSON path'
Assert-PathUnderOrEqual -Path $fileCsvPath -RootPath $outputRootFull -Description 'File CSV path'

$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportJsonPath -Encoding UTF8
$fileRows | Export-Csv -LiteralPath $fileCsvPath -NoTypeInformation -Encoding UTF8

[PSCustomObject]@{
    InputRoot = $inputRootFull
    PotentialUsefulness = $assessment.PotentialUsefulness
    GateDecision = $assessment.GateDecision
    ApkFiles = $counters.ApkFiles
    UnityDataEntries = $counters.UnityDataEntries
    AssetBundleEntries = $counters.AssetBundleEntries
    AddressablesCatalogEntries = $counters.AddressablesCatalogEntries
    ObbFiles = $counters.ObbFiles
    AssetPackFiles = $counters.AssetPackFiles
    WwiseBankEntries = $counters.WwiseBankEntries
    Report = $reportJsonPath
} | Format-List
