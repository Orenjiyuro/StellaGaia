[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ProjectPath,
    [string]$ReferenceCsv,
    [string]$OutputRoot,
    [string]$AssetPathPattern = '^Assets/assetbundles/environment/',
    [string[]]$Extensions = @('.prefab'),
    [int]$Top = 100
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

function Get-AssetNameScore {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    $score = 0
    if ($AssetPath -match '/roguelike_2/') { $score += 1000 }
    if ($AssetPath -match 'roguelike_battle_009|Roguelike_Battle_009|Roguelike_2_Battle_009') { $score += 700 }
    if ($AssetPath -match '/mesh/') { $score += 400 }
    if ($AssetPath -match '/interactive/') { $score += 250 }
    if ($AssetPath -match '/fx/') { $score += 100 }
    if ($AssetPath -match 'floor|Floor') { $score += 120 }
    if ($AssetPath -match 'building|Building') { $score += 100 }
    if ($AssetPath -match 'wall|Wall') { $score += 60 }
    if ($AssetPath -match 'door|Door|gate|Gate') { $score += 40 }
    return $score
}

function Get-StaticAssetCounts {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$AssetPath
    )

    $fullPath = Join-Path $ProjectPath $AssetPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        return [PSCustomObject]@{
            FileExists = $false
            GameObjectCount = 0
            RendererComponentCount = 0
            MeshReferenceLineCount = 0
            MaterialArrayLineCount = 0
            ParticleRendererComponentCount = 0
            AnimatorReferenceLineCount = 0
            FileBytes = 0
        }
    }

    $lines = [string[]](Get-Content -LiteralPath $fullPath)
    $gameObjectCount = @($lines | Where-Object { $_ -match '^--- !u!1 &' }).Count
    $rendererComponentCount = @($lines | Where-Object { $_ -match '^--- !u!(23|199|212|120|96) &' }).Count
    $particleRendererComponentCount = @($lines | Where-Object { $_ -match '^--- !u!199 &' }).Count
    $meshReferenceLineCount = @($lines | Where-Object { $_ -match '\bm_Mesh\d*:\s*\{fileID:' }).Count
    $materialArrayLineCount = @($lines | Where-Object { $_ -match '\bm_Materials:\s*$' }).Count
    $animatorReferenceLineCount = @($lines | Where-Object { $_ -match '\bm_(Controller|AnimatorController|Avatar):\s*\{fileID:' }).Count
    $fileBytes = (Get-Item -LiteralPath $fullPath).Length

    return [PSCustomObject]@{
        FileExists = $true
        GameObjectCount = $gameObjectCount
        RendererComponentCount = $rendererComponentCount
        MeshReferenceLineCount = $meshReferenceLineCount
        MaterialArrayLineCount = $materialArrayLineCount
        ParticleRendererComponentCount = $particleRendererComponentCount
        AnimatorReferenceLineCount = $animatorReferenceLineCount
        FileBytes = $fileBytes
    }
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
    $OutputRoot = Join-Path $extractedRoot 'Validation\UnitySalvageCandidates'
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

$extensionSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$Extensions | ForEach-Object { [void]$extensionSet.Add($_) }

$assetFiles = @(
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'Assets') -Recurse -File |
        Where-Object { $extensionSet.Contains([System.IO.Path]::GetExtension($_.FullName)) } |
        ForEach-Object {
            Get-RelativePath -RootPath $ProjectPath -Path $_.FullName
        } |
        Where-Object { $_ -match $AssetPathPattern }
)

$references = @(Import-Csv -LiteralPath $ReferenceCsv)
$referencesBySource = @{}
foreach ($reference in $references) {
    if (-not $referencesBySource.ContainsKey($reference.SourceAssetPath)) {
        $referencesBySource[$reference.SourceAssetPath] = [System.Collections.Generic.List[object]]::new()
    }
    $referencesBySource[$reference.SourceAssetPath].Add($reference)
}

$rows = [System.Collections.Generic.List[object]]::new()
foreach ($assetPath in $assetFiles) {
    $assetReferences = if ($referencesBySource.ContainsKey($assetPath)) { @($referencesBySource[$assetPath]) } else { @() }
    $existingRefs = @($assetReferences | Where-Object { $_.TargetStatus -eq 'Existing' })
    $placeholderRefs = @($assetReferences | Where-Object { $_.TargetStatus -eq 'DeadbeefGuid' })
    $missingRefs = @($assetReferences | Where-Object { $_.TargetStatus -eq 'MissingGuid' })
    $zeroRefs = @($assetReferences | Where-Object { $_.TargetStatus -eq 'ZeroGuid' })
    $builtinRefs = @($assetReferences | Where-Object { $_.TargetStatus -eq 'BuiltinResource' })
    $meshRefs = @($assetReferences | Where-Object { $_.FileId -eq '4300000' -or $_.SourceAssetPath -match '\.prefab$' -and $_.LineNumber -ne '' -and $_.TargetAssetPath -match '\.asset$' })
    $materialRefs = @($assetReferences | Where-Object { $_.FileId -eq '2100000' -or $_.TargetAssetPath -match '\.mat$' })
    $textureRefs = @($assetReferences | Where-Object { $_.FileId -eq '2800000' -or $_.FileId -eq '2700000' -or $_.TargetAssetPath -match '\.(png|tga|jpg|jpeg|texture2d)$' })
    $counts = Get-StaticAssetCounts -ProjectPath $ProjectPath -AssetPath $assetPath
    $nameScore = Get-AssetNameScore -AssetPath $assetPath

    $hasRenderableEvidence = ($counts.RendererComponentCount -gt 0 -or $counts.MeshReferenceLineCount -gt 0)
    $candidateStatus = if ($placeholderRefs.Count -eq 0 -and $missingRefs.Count -eq 0 -and $zeroRefs.Count -eq 0 -and $hasRenderableEvidence) {
        'StaticRenderableSalvageCandidate'
    }
    elseif ($placeholderRefs.Count -eq 0 -and $missingRefs.Count -eq 0 -and $zeroRefs.Count -eq 0) {
        'StaticNonRenderableCleanCandidate'
    }
    elseif ($placeholderRefs.Count -gt 0) {
        'HasPlaceholderReferences'
    }
    elseif ($missingRefs.Count -gt 0 -or $zeroRefs.Count -gt 0) {
        'HasMissingReferences'
    }
    else {
        'NeedsReview'
    }

    $rows.Add([PSCustomObject]@{
        AssetPath = $assetPath
        Extension = [System.IO.Path]::GetExtension($assetPath).ToLowerInvariant()
        CandidateStatus = $candidateStatus
        Score = ($nameScore + ($counts.RendererComponentCount * 10) + ($counts.MeshReferenceLineCount * 8) + ($existingRefs.Count * 2) - ($placeholderRefs.Count * 20) - ($missingRefs.Count * 30))
        NameScore = $nameScore
        ExistingReferenceCount = $existingRefs.Count
        PlaceholderReferenceCount = $placeholderRefs.Count
        MissingGuidReferenceCount = $missingRefs.Count
        ZeroGuidReferenceCount = $zeroRefs.Count
        BuiltinResourceReferenceCount = $builtinRefs.Count
        MeshReferenceCount = $meshRefs.Count
        MaterialReferenceCount = $materialRefs.Count
        TextureReferenceCount = $textureRefs.Count
        GameObjectCount = $counts.GameObjectCount
        RendererComponentCount = $counts.RendererComponentCount
        ParticleRendererComponentCount = $counts.ParticleRendererComponentCount
        MeshReferenceLineCount = $counts.MeshReferenceLineCount
        MaterialArrayLineCount = $counts.MaterialArrayLineCount
        AnimatorReferenceLineCount = $counts.AnimatorReferenceLineCount
        FileBytes = $counts.FileBytes
    })
}

$sortedRows = @($rows | Sort-Object -Property @{ Expression = 'CandidateStatus'; Descending = $false }, @{ Expression = 'Score'; Descending = $true })
$candidateRows = @($rows | Where-Object { $_.CandidateStatus -eq 'StaticRenderableSalvageCandidate' } | Sort-Object -Property Score -Descending)
$statusRows = @(
    $rows |
        Group-Object -Property CandidateStatus |
        ForEach-Object {
            [PSCustomObject]@{
                CandidateStatus = $_.Name
                Count = $_.Count
            }
        } |
        Sort-Object -Property CandidateStatus
)

$allCsv = Join-Path $outputDir 'salvage-candidates-all.csv'
$candidateCsv = Join-Path $outputDir 'salvage-candidates-static.csv'
$statusCsv = Join-Path $outputDir 'salvage-candidate-status-summary.csv'
$summaryJson = Join-Path $outputDir 'salvage-candidates-summary.json'
$reportPath = Join-Path $outputDir 'salvage-candidates-report.md'

$sortedRows | Export-Csv -LiteralPath $allCsv -NoTypeInformation -Encoding UTF8
$candidateRows | Export-Csv -LiteralPath $candidateCsv -NoTypeInformation -Encoding UTF8
$statusRows | Export-Csv -LiteralPath $statusCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    ProjectPath = $ProjectPath
    ReferenceCsv = $ReferenceCsv
    AssetPathPattern = $AssetPathPattern
    Extensions = $Extensions
    AssetCount = $rows.Count
    StaticRenderableSalvageCandidateCount = $candidateRows.Count
    StatusSummaryCsv = $statusCsv
    AllCandidatesCsv = $allCsv
    StaticCandidatesCsv = $candidateCsv
    Report = $reportPath
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Unity Export Salvage Candidates: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Project: `{0}`' -f $ProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Scanned assets | $($summary.AssetCount) |")
$reportLines.Add("| Static renderable salvage candidates | $($summary.StaticRenderableSalvageCandidateCount) |")
$reportLines.Add('')
$reportLines.Add('## Status Counts')
$reportLines.Add('')
$reportLines.Add('| Status | Count |')
$reportLines.Add('| --- | ---: |')
$statusRows | ForEach-Object {
    $reportLines.Add(('| {0} | {1} |' -f $_.CandidateStatus, $_.Count))
}
$reportLines.Add('')
$reportLines.Add('## Top Static Renderable Salvage Candidates')
$reportLines.Add('')
$reportLines.Add('| Asset | Score | Renderers | Mesh refs | Material refs | Existing refs | Bytes |')
$reportLines.Add('| --- | ---: | ---: | ---: | ---: | ---: | ---: |')
$candidateRows | Select-Object -First $Top | ForEach-Object {
    $reportLines.Add(('| `{0}` | {1} | {2} | {3} | {4} | {5} | {6} |' -f $_.AssetPath, $_.Score, $_.RendererComponentCount, $_.MeshReferenceLineCount, $_.MaterialReferenceCount, $_.ExistingReferenceCount, $_.FileBytes))
}
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $allCsv))
$reportLines.Add(('- `{0}`' -f $candidateCsv))
$reportLines.Add(('- `{0}`' -f $statusCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary | Format-List
