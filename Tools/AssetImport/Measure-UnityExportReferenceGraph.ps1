[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ProjectPath,
    [string]$OutputRoot,
    [int]$Top = 50
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

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $root = Get-CanonicalPath $RootPath
    $full = Get-CanonicalPath $Path
    if ($full.Length -le $root.Length) {
        return ''
    }
    return $full.Substring($root.Length + 1).Replace('\', '/')
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$MetaPath)

    $line = Select-String -LiteralPath $MetaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $line) {
        return $null
    }
    return $line.Matches.Groups[1].Value
}

function Get-ReferenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][hashtable]$GuidToAsset
    )

    if ($Guid -eq '00000000000000000000000000000000') {
        return 'ZeroGuid'
    }
    if ($Guid -eq '0000000000000000e000000000000000' -or $Guid -eq '0000000000000000f000000000000000') {
        return 'BuiltinResource'
    }
    if ($Guid -match 'deadbeef|deadf00d') {
        return 'DeadbeefGuid'
    }
    if ($GuidToAsset.ContainsKey($Guid)) {
        return 'Existing'
    }
    return 'MissingGuid'
}

function ConvertTo-CsvSafe {
    param([AllowEmptyCollection()][object[]]$Rows)

    if ($Rows.Count -eq 0) {
        return @()
    }
    return $Rows
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $extractedRoot "AssetRipper\FolderExports\$Name\ExportedProject"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UnityReferenceGraph'
}

$ProjectPath = Get-CanonicalPath $ProjectPath
$OutputRoot = Get-CanonicalPath $OutputRoot
$outputDir = Join-Path $OutputRoot $Name

Assert-PathUnderOrEqual -Path $ProjectPath -RootPath $extractedRoot -Description 'ProjectPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) {
    throw "ProjectPath is not an AssetRipper Unity export project: $ProjectPath"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$guidToAsset = @{}
$guidRows = [System.Collections.Generic.List[object]]::new()
Get-ChildItem -LiteralPath $ProjectPath -Recurse -File -Filter '*.meta' | ForEach-Object {
    $guid = Get-MetaGuid -MetaPath $_.FullName
    if ([string]::IsNullOrWhiteSpace($guid)) {
        return
    }

    $assetFullPath = $_.FullName.Substring(0, $_.FullName.Length - 5)
    $assetPath = Get-RelativePath -RootPath $ProjectPath -Path $assetFullPath
    $assetKind = if (Test-Path -LiteralPath $assetFullPath -PathType Container) { 'Directory' } elseif (Test-Path -LiteralPath $assetFullPath -PathType Leaf) { 'File' } else { 'MissingAssetForMeta' }
    $assetExtension = [System.IO.Path]::GetExtension($assetFullPath).ToLowerInvariant()

    if (-not $guidToAsset.ContainsKey($guid)) {
        $guidToAsset[$guid] = $assetPath
    }

    $guidRows.Add([PSCustomObject]@{
        Guid = $guid
        AssetPath = $assetPath
        AssetKind = $assetKind
        Extension = $assetExtension
    })
}

$textExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
    '.anim',
    '.asmdef',
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
) | ForEach-Object { [void]$textExtensions.Add($_) }

$referenceRows = [System.Collections.Generic.List[object]]::new()
$referencePattern = 'guid:\s*([0-9a-f]{32})'
$fileIdPattern = 'fileID:\s*(-?\d+)'
$typePattern = 'type:\s*(\d+)'

Get-ChildItem -LiteralPath $ProjectPath -Recurse -File | Where-Object {
    $textExtensions.Contains([System.IO.Path]::GetExtension($_.FullName))
} | ForEach-Object {
    $sourceFullPath = $_.FullName
    $sourceAssetPath = Get-RelativePath -RootPath $ProjectPath -Path $sourceFullPath
    $sourceExtension = [System.IO.Path]::GetExtension($sourceFullPath).ToLowerInvariant()

    try {
        Select-String -LiteralPath $sourceFullPath -Pattern $referencePattern -AllMatches | ForEach-Object {
            $lineText = $_.Line
            $fileIdMatch = [regex]::Match($lineText, $fileIdPattern)
            $typeMatch = [regex]::Match($lineText, $typePattern)
            $fileId = if ($fileIdMatch.Success) { $fileIdMatch.Groups[1].Value } else { '' }
            $type = if ($typeMatch.Success) { $typeMatch.Groups[1].Value } else { '' }

            foreach ($match in $_.Matches) {
                $guid = $match.Groups[1].Value
                $status = Get-ReferenceStatus -Guid $guid -GuidToAsset $guidToAsset
                $targetAssetPath = if ($guidToAsset.ContainsKey($guid)) { $guidToAsset[$guid] } else { '' }

                $referenceRows.Add([PSCustomObject]@{
                    SourceAssetPath = $sourceAssetPath
                    SourceExtension = $sourceExtension
                    LineNumber = $_.LineNumber
                    FileId = $fileId
                    Guid = $guid
                    Type = $type
                    TargetStatus = $status
                    TargetAssetPath = $targetAssetPath
                })
            }
        }
    }
    catch {
        $referenceRows.Add([PSCustomObject]@{
            SourceAssetPath = $sourceAssetPath
            SourceExtension = $sourceExtension
            LineNumber = 0
            FileId = ''
            Guid = ''
            Type = ''
            TargetStatus = 'ScanError'
            TargetAssetPath = $_.Exception.Message
        })
    }
}

$missingLikeRows = @($referenceRows | Where-Object { $_.TargetStatus -ne 'Existing' -and $_.TargetStatus -ne 'BuiltinResource' })
$missingGuidRows = @($referenceRows | Where-Object { $_.TargetStatus -eq 'MissingGuid' })

$guidSummaryRows = @(
    $missingLikeRows |
        Group-Object -Property Guid, TargetStatus |
        ForEach-Object {
            $first = $_.Group[0]
            [PSCustomObject]@{
                Guid = $first.Guid
                TargetStatus = $first.TargetStatus
                ReferenceCount = $_.Count
                SourceAssetCount = @($_.Group | Select-Object -ExpandProperty SourceAssetPath -Unique).Count
                FirstSourceAssetPath = $first.SourceAssetPath
            }
        } |
        Sort-Object -Property ReferenceCount -Descending
)

$sourceSummaryRows = @(
    $missingLikeRows |
        Group-Object -Property SourceAssetPath |
        ForEach-Object {
            $first = $_.Group[0]
            [PSCustomObject]@{
                SourceAssetPath = $first.SourceAssetPath
                SourceExtension = $first.SourceExtension
                MissingLikeReferenceCount = $_.Count
                MissingGuidCount = @($_.Group | Where-Object { $_.TargetStatus -eq 'MissingGuid' }).Count
                DeadbeefGuidCount = @($_.Group | Where-Object { $_.TargetStatus -eq 'DeadbeefGuid' }).Count
                ZeroGuidCount = @($_.Group | Where-Object { $_.TargetStatus -eq 'ZeroGuid' }).Count
                UniqueProblemGuidCount = @($_.Group | Select-Object -ExpandProperty Guid -Unique).Count
            }
        } |
        Sort-Object -Property MissingLikeReferenceCount -Descending
)

$existingTargetSummaryRows = @(
    $referenceRows |
        Where-Object { $_.TargetStatus -eq 'Existing' } |
        Group-Object -Property TargetAssetPath |
        ForEach-Object {
            [PSCustomObject]@{
                TargetAssetPath = $_.Name
                ReferenceCount = $_.Count
                SourceAssetCount = @($_.Group | Select-Object -ExpandProperty SourceAssetPath -Unique).Count
            }
        } |
        Sort-Object -Property ReferenceCount -Descending
)

$guidMapCsv = Join-Path $outputDir 'guid-map.csv'
$referencesCsv = Join-Path $outputDir 'references.csv'
$missingGuidSummaryCsv = Join-Path $outputDir 'missing-guid-summary.csv'
$sourceSummaryCsv = Join-Path $outputDir 'source-missing-reference-summary.csv'
$existingTargetSummaryCsv = Join-Path $outputDir 'existing-target-reference-summary.csv'
$summaryJson = Join-Path $outputDir 'reference-graph-summary.json'
$reportPath = Join-Path $outputDir 'reference-graph-report.md'

ConvertTo-CsvSafe -Rows @($guidRows) | Export-Csv -LiteralPath $guidMapCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($referenceRows) | Export-Csv -LiteralPath $referencesCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($guidSummaryRows) | Export-Csv -LiteralPath $missingGuidSummaryCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($sourceSummaryRows) | Export-Csv -LiteralPath $sourceSummaryCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($existingTargetSummaryRows) | Export-Csv -LiteralPath $existingTargetSummaryCsv -NoTypeInformation -Encoding UTF8

$statusCounts = @{}
$referenceRows | Group-Object -Property TargetStatus | ForEach-Object {
    $statusCounts[$_.Name] = $_.Count
}

$extensionCounts = @{}
$referenceRows | Group-Object -Property SourceExtension | ForEach-Object {
    $extensionCounts[$_.Name] = $_.Count
}

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    ProjectPath = $ProjectPath
    OutputDirectory = $outputDir
    MetaGuidCount = $guidRows.Count
    ReferenceCount = $referenceRows.Count
    ExistingReferenceCount = if ($statusCounts.ContainsKey('Existing')) { $statusCounts['Existing'] } else { 0 }
    MissingGuidReferenceCount = $missingGuidRows.Count
    UniqueMissingGuidCount = @($missingGuidRows | Select-Object -ExpandProperty Guid -Unique).Count
    DeadbeefGuidReferenceCount = if ($statusCounts.ContainsKey('DeadbeefGuid')) { $statusCounts['DeadbeefGuid'] } else { 0 }
    BuiltinResourceReferenceCount = if ($statusCounts.ContainsKey('BuiltinResource')) { $statusCounts['BuiltinResource'] } else { 0 }
    ZeroGuidReferenceCount = if ($statusCounts.ContainsKey('ZeroGuid')) { $statusCounts['ZeroGuid'] } else { 0 }
    ScanErrorCount = if ($statusCounts.ContainsKey('ScanError')) { $statusCounts['ScanError'] } else { 0 }
    SourceWithMissingLikeReferenceCount = @($sourceSummaryRows).Count
    StatusCounts = $statusCounts
    SourceExtensionReferenceCounts = $extensionCounts
    GuidMapCsv = $guidMapCsv
    ReferencesCsv = $referencesCsv
    MissingGuidSummaryCsv = $missingGuidSummaryCsv
    SourceSummaryCsv = $sourceSummaryCsv
    ExistingTargetSummaryCsv = $existingTargetSummaryCsv
    Report = $reportPath
}

$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Unity Export Reference Graph: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Project: `{0}`' -f $ProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Meta GUIDs | $($summary.MetaGuidCount) |")
$reportLines.Add("| YAML GUID references | $($summary.ReferenceCount) |")
$reportLines.Add("| Existing references | $($summary.ExistingReferenceCount) |")
$reportLines.Add("| Missing GUID references | $($summary.MissingGuidReferenceCount) |")
$reportLines.Add("| Unique missing GUIDs | $($summary.UniqueMissingGuidCount) |")
$reportLines.Add("| Deadbeef placeholder references | $($summary.DeadbeefGuidReferenceCount) |")
$reportLines.Add("| Unity built-in resource references | $($summary.BuiltinResourceReferenceCount) |")
$reportLines.Add("| Zero GUID references | $($summary.ZeroGuidReferenceCount) |")
$reportLines.Add("| Scan errors | $($summary.ScanErrorCount) |")
$reportLines.Add('')
$reportLines.Add('## Top Problem GUIDs')
$reportLines.Add('')
$reportLines.Add('| GUID | Status | References | Sources | First Source |')
$reportLines.Add('| --- | --- | ---: | ---: | --- |')
$guidSummaryRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| `{0}` | {1} | {2} | {3} | `{4}` |' -f $_.Guid, $_.TargetStatus, $_.ReferenceCount, $_.SourceAssetCount, $_.FirstSourceAssetPath))
}
$reportLines.Add('')
$reportLines.Add('## Top Source Assets With Problem References')
$reportLines.Add('')
$reportLines.Add('| Source | Ext | Problem refs | Missing GUID refs | Deadbeef refs | Zero refs | Unique problem GUIDs |')
$reportLines.Add('| --- | --- | ---: | ---: | ---: | ---: | ---: |')
$sourceSummaryRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| `{0}` | `{1}` | {2} | {3} | {4} | {5} | {6} |' -f $_.SourceAssetPath, $_.SourceExtension, $_.MissingLikeReferenceCount, $_.MissingGuidCount, $_.DeadbeefGuidCount, $_.ZeroGuidCount, $_.UniqueProblemGuidCount))
}
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $guidMapCsv))
$reportLines.Add(('- `{0}`' -f $referencesCsv))
$reportLines.Add(('- `{0}`' -f $missingGuidSummaryCsv))
$reportLines.Add(('- `{0}`' -f $sourceSummaryCsv))
$reportLines.Add(('- `{0}`' -f $existingTargetSummaryCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))

$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary | Format-List
