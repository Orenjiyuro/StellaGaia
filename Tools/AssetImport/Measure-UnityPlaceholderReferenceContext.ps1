[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ProjectPath,
    [string]$ReferenceCsv,
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

function Get-PropertyName {
    param([Parameter(Mandatory = $true)][string]$Line)

    $trimmed = $Line.Trim()
    $match = [regex]::Match($trimmed, '^(?:-\s*)?([A-Za-z_][A-Za-z0-9_.$\[\]-]*)\s*:\s*\{[^{}]*guid:\s*[0-9a-f]{32}')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    $beforeGuid = $trimmed -replace '\{[^{}]*guid:\s*[0-9a-f]{32}.*$', ''
    $beforeGuid = $beforeGuid.Trim()
    if ([string]::IsNullOrWhiteSpace($beforeGuid)) {
        return '(inline)'
    }
    return $beforeGuid
}

function Get-NearestObjectHeader {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][int]$LineIndex
    )

    for ($i = $LineIndex; $i -ge 0 -and $i -ge ($LineIndex - 300); $i--) {
        if ($Lines[$i] -match '^--- !u!(\d+) &(-?\d+)') {
            return $Lines[$i].Trim()
        }
    }
    return ''
}

function Get-NearestNamedKey {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][int]$LineIndex
    )

    for ($i = $LineIndex - 1; $i -ge 0 -and $i -ge ($LineIndex - 20); $i--) {
        $trimmed = $Lines[$i].Trim()
        if ($trimmed -match '^(m_Name|m_GameObject|m_Materials|m_Mesh|m_Shader|m_Script|m_Texture|m_Controller|m_AnimatorController|m_AnimationClip|m_EditorClassIdentifier)\b') {
            return $trimmed
        }
    }
    return ''
}

function Get-ClassIdFromObjectHeader {
    param([string]$ObjectHeader)

    if ($ObjectHeader -match '^--- !u!(\d+)') {
        return $Matches[1]
    }
    return ''
}

function Get-ReferenceKind {
    param(
        [string]$PropertyName,
        [string]$FileId,
        [string]$SourceExtension,
        [string]$ClassId
    )

    if ($PropertyName -match 'Shader' -or $FileId -eq '4800000' -or $FileId -eq '2700000') {
        return 'ShaderOrMaterialDependency'
    }
    if ($PropertyName -match 'Mesh' -or $FileId -eq '4300000') {
        return 'MeshDependency'
    }
    if ($PropertyName -match 'Material' -or $FileId -eq '2100000') {
        return 'MaterialDependency'
    }
    if ($PropertyName -match 'Texture|Tex|Map' -or $FileId -eq '2800000') {
        return 'TextureDependency'
    }
    if ($PropertyName -match 'Script' -or $FileId -eq '11500000') {
        return 'ScriptDependency'
    }
    if ($SourceExtension -eq '.anim') {
        return 'AnimationBinding'
    }
    if ($SourceExtension -eq '.playable') {
        return 'TimelineBinding'
    }
    if ($SourceExtension -eq '.mat' -or $ClassId -eq '21') {
        return 'MaterialFileReference'
    }
    return 'OtherReference'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = Join-Path $extractedRoot "AssetRipper\FolderExports\$Name\ExportedProject"
}
if ([string]::IsNullOrWhiteSpace($ReferenceCsv)) {
    $ReferenceCsv = Join-Path $extractedRoot "Validation\UnityReferenceGraph\$Name\references.csv"
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UnityPlaceholderContext'
}

$ProjectPath = Get-CanonicalPath $ProjectPath
$ReferenceCsv = Get-CanonicalPath $ReferenceCsv
$OutputRoot = Get-CanonicalPath $OutputRoot
$outputDir = Join-Path $OutputRoot $Name

Assert-PathUnderOrEqual -Path $ProjectPath -RootPath $extractedRoot -Description 'ProjectPath'
Assert-PathUnderOrEqual -Path $ReferenceCsv -RootPath $extractedRoot -Description 'ReferenceCsv'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $ReferenceCsv -PathType Leaf)) {
    throw "Reference CSV not found: $ReferenceCsv"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$references = @(Import-Csv -LiteralPath $ReferenceCsv | Where-Object { $null -ne $_ -and $_.TargetStatus -eq 'DeadbeefGuid' -and -not [string]::IsNullOrWhiteSpace($_.SourceAssetPath) })
$lineCache = @{}
$contextRows = [System.Collections.Generic.List[object]]::new()

foreach ($reference in $references) {
    $sourceFullPath = Join-Path $ProjectPath $reference.SourceAssetPath
    if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Leaf)) {
        $contextRows.Add([PSCustomObject]@{
            SourceAssetPath = $reference.SourceAssetPath
            SourceExtension = $reference.SourceExtension
            LineNumber = $reference.LineNumber
            FileId = $reference.FileId
            Type = $reference.Type
            PropertyName = ''
            ReferenceKind = 'SourceMissing'
            ClassId = ''
            ObjectHeader = ''
            NearbyKey = ''
            Line = ''
        })
        continue
    }

    if (-not $lineCache.ContainsKey($sourceFullPath)) {
        $lineCache[$sourceFullPath] = [string[]](Get-Content -LiteralPath $sourceFullPath)
    }

    $lines = $lineCache[$sourceFullPath]
    $lineNumber = [int]$reference.LineNumber
    $lineIndex = [Math]::Max(0, $lineNumber - 1)
    $line = if ($lineIndex -lt $lines.Count) { $lines[$lineIndex] } else { '' }
    $propertyName = Get-PropertyName -Line $line
    $objectHeader = Get-NearestObjectHeader -Lines $lines -LineIndex $lineIndex
    $classId = Get-ClassIdFromObjectHeader -ObjectHeader $objectHeader
    $nearbyKey = Get-NearestNamedKey -Lines $lines -LineIndex $lineIndex
    $referenceKind = Get-ReferenceKind -PropertyName $propertyName -FileId $reference.FileId -SourceExtension $reference.SourceExtension -ClassId $classId

    $contextRows.Add([PSCustomObject]@{
        SourceAssetPath = $reference.SourceAssetPath
        SourceExtension = $reference.SourceExtension
        LineNumber = $reference.LineNumber
        FileId = $reference.FileId
        Type = $reference.Type
        PropertyName = $propertyName
        ReferenceKind = $referenceKind
        ClassId = $classId
        ObjectHeader = $objectHeader
        NearbyKey = $nearbyKey
        Line = $line.Trim()
    })
}

$kindSummaryRows = @(
    $contextRows |
        Group-Object -Property ReferenceKind |
        ForEach-Object {
            [PSCustomObject]@{
                ReferenceKind = $_.Name
                Count = $_.Count
                SourceAssetCount = @($_.Group | Select-Object -ExpandProperty SourceAssetPath -Unique).Count
            }
        } |
        Sort-Object -Property Count -Descending
)

$propertySummaryRows = @(
    $contextRows |
        Group-Object -Property ReferenceKind, PropertyName, FileId, SourceExtension |
        ForEach-Object {
            $first = $_.Group[0]
            [PSCustomObject]@{
                ReferenceKind = $first.ReferenceKind
                PropertyName = $first.PropertyName
                FileId = $first.FileId
                SourceExtension = $first.SourceExtension
                Count = $_.Count
                SourceAssetCount = @($_.Group | Select-Object -ExpandProperty SourceAssetPath -Unique).Count
                FirstSourceAssetPath = $first.SourceAssetPath
            }
        } |
        Sort-Object -Property Count -Descending
)

$sourceSummaryRows = @(
    $contextRows |
        Group-Object -Property SourceAssetPath |
        ForEach-Object {
            $first = $_.Group[0]
            [PSCustomObject]@{
                SourceAssetPath = $first.SourceAssetPath
                SourceExtension = $first.SourceExtension
                Count = $_.Count
                ReferenceKinds = (@($_.Group | Select-Object -ExpandProperty ReferenceKind -Unique) -join ';')
                PropertyNames = (@($_.Group | Select-Object -ExpandProperty PropertyName -Unique) -join ';')
            }
        } |
        Sort-Object -Property Count -Descending
)

$contextCsv = Join-Path $outputDir 'placeholder-context.csv'
$kindSummaryCsv = Join-Path $outputDir 'placeholder-kind-summary.csv'
$propertySummaryCsv = Join-Path $outputDir 'placeholder-property-summary.csv'
$sourceSummaryCsv = Join-Path $outputDir 'placeholder-source-summary.csv'
$summaryJson = Join-Path $outputDir 'placeholder-context-summary.json'
$reportPath = Join-Path $outputDir 'placeholder-context-report.md'

$contextRows | Export-Csv -LiteralPath $contextCsv -NoTypeInformation -Encoding UTF8
$kindSummaryRows | Export-Csv -LiteralPath $kindSummaryCsv -NoTypeInformation -Encoding UTF8
$propertySummaryRows | Export-Csv -LiteralPath $propertySummaryCsv -NoTypeInformation -Encoding UTF8
$sourceSummaryRows | Export-Csv -LiteralPath $sourceSummaryCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    ProjectPath = $ProjectPath
    ReferenceCsv = $ReferenceCsv
    PlaceholderReferenceCount = $contextRows.Count
    SourceAssetCount = @($contextRows | Select-Object -ExpandProperty SourceAssetPath -Unique).Count
    KindSummaryCsv = $kindSummaryCsv
    PropertySummaryCsv = $propertySummaryCsv
    SourceSummaryCsv = $sourceSummaryCsv
    ContextCsv = $contextCsv
    Report = $reportPath
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Unity Placeholder Reference Context: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Project: `{0}`' -f $ProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Placeholder references | $($summary.PlaceholderReferenceCount) |")
$reportLines.Add("| Source assets | $($summary.SourceAssetCount) |")
$reportLines.Add('')
$reportLines.Add('## Reference Kinds')
$reportLines.Add('')
$reportLines.Add('| Kind | References | Sources |')
$reportLines.Add('| --- | ---: | ---: |')
$kindSummaryRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| {0} | {1} | {2} |' -f $_.ReferenceKind, $_.Count, $_.SourceAssetCount))
}
$reportLines.Add('')
$reportLines.Add('## Top Properties')
$reportLines.Add('')
$reportLines.Add('| Kind | Property | FileID | Ext | References | Sources | First Source |')
$reportLines.Add('| --- | --- | ---: | --- | ---: | ---: | --- |')
$propertySummaryRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| {0} | `{1}` | `{2}` | `{3}` | {4} | {5} | `{6}` |' -f $_.ReferenceKind, $_.PropertyName, $_.FileId, $_.SourceExtension, $_.Count, $_.SourceAssetCount, $_.FirstSourceAssetPath))
}
$reportLines.Add('')
$reportLines.Add('## Top Source Assets')
$reportLines.Add('')
$reportLines.Add('| Source | Ext | References | Kinds | Properties |')
$reportLines.Add('| --- | --- | ---: | --- | --- |')
$sourceSummaryRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| `{0}` | `{1}` | {2} | `{3}` | `{4}` |' -f $_.SourceAssetPath, $_.SourceExtension, $_.Count, $_.ReferenceKinds, $_.PropertyNames))
}
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $contextCsv))
$reportLines.Add(('- `{0}`' -f $kindSummaryCsv))
$reportLines.Add(('- `{0}`' -f $propertySummaryCsv))
$reportLines.Add(('- `{0}`' -f $sourceSummaryCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary | Format-List
