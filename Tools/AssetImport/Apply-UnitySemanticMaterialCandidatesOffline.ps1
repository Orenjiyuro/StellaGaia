[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01SemanticMaterialRebind01',
    [string]$SourceProjectPath,
    [string]$MaterialSourceProjectPath,
    [string]$CandidateCsv,
    [string]$OutputProjectPath,
    [string]$ReportRoot,
    [int]$MinimumCandidateScore = 120,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $fullPath = (Get-FullPath -Path $Path).TrimEnd('\', '/')
    $fullRoot = (Get-FullPath -Path $Root).TrimEnd('\', '/')
    return $fullPath.Equals($fullRoot, $comparison) -or $fullPath.StartsWith($fullRoot + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-PathUnderOrEqual -Path $Path -Root $Root)) {
        throw "$Description must stay under $Root. Got: $Path"
    }
}

function Assert-ProjectAssetPath {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    if ($AssetPath -notmatch '^Assets[/\\].+') {
        throw "Asset path must start with Assets/: $AssetPath"
    }
    if ([System.IO.Path]::IsPathRooted($AssetPath)) {
        throw "Asset path must be project-relative: $AssetPath"
    }
    foreach ($segment in ($AssetPath -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Asset path contains unsafe segment: $AssetPath"
        }
    }
}

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    return $FullPath.Substring($ProjectRoot.Length + 1).Replace('\', '/')
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    $metaPath = "$AssetPath.meta"
    if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
        return ''
    }

    $match = Select-String -LiteralPath $metaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $match) {
        return ''
    }

    return $match.Matches.Groups[1].Value
}

function Copy-DirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($Source.Length + 1)
        $targetPath = Join-Path $Destination $relativePath
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetPath) | Out-Null
        Copy-Item -LiteralPath $_.FullName -Destination $targetPath -Force
    }
}

function Copy-SanitizedMaterial {
    param(
        [Parameter(Mandatory = $true)][string]$CandidateAssetPath,
        [Parameter(Mandatory = $true)][string]$SourceProject,
        [Parameter(Mandatory = $true)][string]$OutputProject
    )

    Assert-ProjectAssetPath -AssetPath $CandidateAssetPath
    $sourceMaterial = Join-Path $SourceProject $CandidateAssetPath
    if (-not (Test-Path -LiteralPath $sourceMaterial -PathType Leaf)) {
        throw "Candidate material not found: $sourceMaterial"
    }

    $targetMaterial = Join-Path $OutputProject $CandidateAssetPath

    $content = Get-Content -LiteralPath $sourceMaterial -Raw
    $texturePlaceholderPattern = 'm_Texture:\s*\{fileID:\s*(?!0\b)\d+,\s*guid:\s*[0-9a-f]*dead(?:beef|f00d)[0-9a-f]*,\s*type:\s*\d+\}'
    $shaderPlaceholderPattern = 'm_Shader:\s*\{fileID:\s*(?!0\b)\d+,\s*guid:\s*[0-9a-f]*dead(?:beef|f00d)[0-9a-f]*,\s*type:\s*\d+\}'
    $texturePlaceholderCount = [regex]::Matches($content, $texturePlaceholderPattern).Count
    $shaderPlaceholderCount = [regex]::Matches($content, $shaderPlaceholderPattern).Count
    $sanitized = [regex]::Replace($content, $texturePlaceholderPattern, 'm_Texture: {fileID: 0}')
    $sanitized = [regex]::Replace($sanitized, $shaderPlaceholderPattern, 'm_Shader: {fileID: 4800000, guid: 6fdbcb0b2ef343a4a93a2d46f8bd25a1, type: 3}')

    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $targetMaterial) | Out-Null
        Set-Content -LiteralPath $targetMaterial -Value $sanitized -Encoding UTF8
        $sourceMeta = "$sourceMaterial.meta"
        if (Test-Path -LiteralPath $sourceMeta -PathType Leaf) {
            Copy-Item -LiteralPath $sourceMeta -Destination "$targetMaterial.meta" -Force
        }
    }

    [PSCustomObject]@{
        CandidateMaterialPath = $CandidateAssetPath
        CandidateMaterialGuid = Get-MetaGuid -AssetPath $sourceMaterial
        SanitizedTexturePlaceholderReferenceCount = $texturePlaceholderCount
        SanitizedShaderPlaceholderReferenceCount = $shaderPlaceholderCount
        OutputMaterialPath = Get-ProjectRelativePath -FullPath $targetMaterial -ProjectRoot $OutputProject
    }
}

$repoRoot = Get-FullPath -Path (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-FullPath -Path (Join-Path $repoRoot 'Extracted')
if (-not $SourceProjectPath) {
    $SourceProjectPath = Join-Path $extractedRoot 'AssetRipper\EnvironmentModuleSlices\Environment009ModuleSalvageSet01GuidClosure\ExportedProject'
}
if (-not $MaterialSourceProjectPath) {
    $MaterialSourceProjectPath = Join-Path $extractedRoot 'AssetRipper\RoomSamples\EnvironmentRoomSample009CabFocused\ExportedProject'
}
if (-not $CandidateCsv) {
    $CandidateCsv = Join-Path $extractedRoot 'Validation\UnitySemanticMaterialCandidates\Environment009ModuleSalvageSet01GuidClosure\semantic-material-candidates.csv'
}
if (-not $OutputProjectPath) {
    $OutputProjectPath = Join-Path $extractedRoot "AssetRipper\EnvironmentModuleSlices\$Name\ExportedProject"
}
if (-not $ReportRoot) {
    $ReportRoot = Join-Path $extractedRoot 'Repairs\SemanticMaterials'
}

$SourceProjectPath = Get-FullPath -Path $SourceProjectPath
$MaterialSourceProjectPath = Get-FullPath -Path $MaterialSourceProjectPath
$CandidateCsv = Get-FullPath -Path $CandidateCsv
$OutputProjectPath = Get-FullPath -Path $OutputProjectPath
$ReportRoot = Get-FullPath -Path $ReportRoot
$reportDirectory = Join-Path $ReportRoot $Name

Assert-PathUnderOrEqual -Path $SourceProjectPath -Root $extractedRoot -Description 'SourceProjectPath'
Assert-PathUnderOrEqual -Path $MaterialSourceProjectPath -Root $extractedRoot -Description 'MaterialSourceProjectPath'
Assert-PathUnderOrEqual -Path $CandidateCsv -Root $extractedRoot -Description 'CandidateCsv'
Assert-PathUnderOrEqual -Path $OutputProjectPath -Root $extractedRoot -Description 'OutputProjectPath'
Assert-PathUnderOrEqual -Path $ReportRoot -Root $extractedRoot -Description 'ReportRoot'

if (-not (Test-Path -LiteralPath (Join-Path $SourceProjectPath 'Assets') -PathType Container)) {
    throw "Source project is missing Assets: $SourceProjectPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $MaterialSourceProjectPath 'Assets') -PathType Container)) {
    throw "Material source project is missing Assets: $MaterialSourceProjectPath"
}
if (-not (Test-Path -LiteralPath $CandidateCsv -PathType Leaf)) {
    throw "Candidate CSV not found: $CandidateCsv"
}
if ((Test-Path -LiteralPath $OutputProjectPath) -and -not $DryRun) {
    throw "Output project already exists. Choose a new Name or OutputProjectPath: $OutputProjectPath"
}

$candidateRows = @(Import-Csv -LiteralPath $CandidateCsv | Where-Object {
    $_.CandidateStatus -eq 'SemanticCandidate' -and
    -not [string]::IsNullOrWhiteSpace($_.CandidateMaterialPath) -and
    [int]$_.CandidateScore -ge $MinimumCandidateScore
})

if ($candidateRows.Count -eq 0) {
    throw "No semantic material candidate rows met the threshold: $MinimumCandidateScore"
}

$rowsByPrefab = $candidateRows | Group-Object -Property PrefabAssetPath
$candidateMaterialPaths = @($candidateRows | Select-Object -ExpandProperty CandidateMaterialPath -Unique | Sort-Object)

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $OutputProjectPath | Out-Null
    Copy-DirectoryTree -Source $SourceProjectPath -Destination $OutputProjectPath
}

New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null

$materialCopyRows = @(
    foreach ($candidateMaterialPath in $candidateMaterialPaths) {
        Copy-SanitizedMaterial -CandidateAssetPath $candidateMaterialPath -SourceProject $MaterialSourceProjectPath -OutputProject $OutputProjectPath
    }
)

$candidateGuidByPath = @{}
foreach ($materialRow in $materialCopyRows) {
    if ([string]::IsNullOrWhiteSpace($materialRow.CandidateMaterialGuid)) {
        throw "Candidate material has no GUID: $($materialRow.CandidateMaterialPath)"
    }
    $candidateGuidByPath[$materialRow.CandidateMaterialPath] = $materialRow.CandidateMaterialGuid
}

$prefabPatchRows = [System.Collections.Generic.List[object]]::new()
foreach ($group in $rowsByPrefab) {
    $prefabAssetPath = [string]$group.Name
    Assert-ProjectAssetPath -AssetPath $prefabAssetPath
    $prefabPath = if ($DryRun) {
        Join-Path $SourceProjectPath $prefabAssetPath
    }
    else {
        Join-Path $OutputProjectPath $prefabAssetPath
    }
    if (-not (Test-Path -LiteralPath $prefabPath -PathType Leaf)) {
        throw "Prefab not found in output project: $prefabPath"
    }

    $content = Get-Content -LiteralPath $prefabPath -Raw
    $rowArray = @($group.Group)
    $replacementIndex = 0
    $materialReferencePattern = 'fileID:\s*2100000,\s*guid:\s*([0-9a-f]{32}),\s*type:\s*2'
    $matches = [regex]::Matches($content, $materialReferencePattern)
    $builder = [System.Text.StringBuilder]::new()
    $lastIndex = 0
    foreach ($match in $matches) {
        [void]$builder.Append($content.Substring($lastIndex, $match.Index - $lastIndex))

        if ($replacementIndex -lt $rowArray.Count) {
            $row = $rowArray[$replacementIndex]
            $oldGuid = [string]$row.OriginalMaterialGuid
            $candidatePath = [string]$row.CandidateMaterialPath
            if ($match.Groups[1].Value -eq $oldGuid) {
                if (-not $candidateGuidByPath.ContainsKey($candidatePath)) {
                    throw "Candidate material GUID is not available: $candidatePath"
                }

                $newGuid = [string]$candidateGuidByPath[$candidatePath]
                $newReference = "fileID: 2100000, guid: $newGuid, type: 2"
                [void]$builder.Append($newReference)
                $prefabPatchRows.Add([PSCustomObject]@{
                    PrefabAssetPath = $prefabAssetPath
                    RendererGameObjectName = $row.RendererGameObjectName
                    MaterialSlot = $row.MaterialSlot
                    OriginalMaterialGuid = $oldGuid
                    OriginalMaterialPath = $row.OriginalMaterialPath
                    CandidateMaterialGuid = $newGuid
                    CandidateMaterialPath = $candidatePath
                    CandidateScore = $row.CandidateScore
                    ReplacedInPrefab = $true
                })
                $replacementIndex++
            }
            else {
                [void]$builder.Append($match.Value)
            }
        }
        else {
            [void]$builder.Append($match.Value)
        }

        $lastIndex = $match.Index + $match.Length
    }
    [void]$builder.Append($content.Substring($lastIndex))
    $updatedContent = $builder.ToString()

    while ($replacementIndex -lt $rowArray.Count) {
        $row = $rowArray[$replacementIndex]
        $candidatePath = [string]$row.CandidateMaterialPath
        $candidateGuid = if ($candidateGuidByPath.ContainsKey($candidatePath)) { [string]$candidateGuidByPath[$candidatePath] } else { '' }
        $prefabPatchRows.Add([PSCustomObject]@{
            PrefabAssetPath = $prefabAssetPath
            RendererGameObjectName = $row.RendererGameObjectName
            MaterialSlot = $row.MaterialSlot
            OriginalMaterialGuid = $row.OriginalMaterialGuid
            OriginalMaterialPath = $row.OriginalMaterialPath
            CandidateMaterialGuid = $candidateGuid
            CandidateMaterialPath = $candidatePath
            CandidateScore = $row.CandidateScore
            ReplacedInPrefab = $false
        })
        $replacementIndex++
    }

    if (-not $DryRun) {
        Set-Content -LiteralPath $prefabPath -Value $updatedContent -Encoding UTF8
    }
}

$prefabPatchCsv = Join-Path $reportDirectory 'semantic-material-prefab-patches.csv'
$materialCopyCsv = Join-Path $reportDirectory 'semantic-material-copied-materials.csv'
$summaryJson = Join-Path $reportDirectory 'semantic-material-rebind-summary.json'
$reportPath = Join-Path $reportDirectory 'semantic-material-rebind-report.md'

$prefabPatchRows | Export-Csv -LiteralPath $prefabPatchCsv -NoTypeInformation -Encoding UTF8
$materialCopyRows | Export-Csv -LiteralPath $materialCopyCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString('O')
    Name = $Name
    SourceProjectPath = $SourceProjectPath
    MaterialSourceProjectPath = $MaterialSourceProjectPath
    CandidateCsv = $CandidateCsv
    OutputProjectPath = $OutputProjectPath
    ReportDirectory = $reportDirectory
    DryRun = [bool]$DryRun
    MinimumCandidateScore = $MinimumCandidateScore
    CandidateRows = $candidateRows.Count
    UniqueCandidateMaterials = $candidateMaterialPaths.Count
    PrefabsPatched = @($prefabPatchRows | Select-Object -ExpandProperty PrefabAssetPath -Unique).Count
    PrefabPatchRows = $prefabPatchRows.Count
    ReplacedPrefabRows = @($prefabPatchRows | Where-Object { $_.ReplacedInPrefab }).Count
    SanitizedTexturePlaceholderReferenceCount = @($materialCopyRows | Measure-Object -Property SanitizedTexturePlaceholderReferenceCount -Sum).Sum
    SanitizedShaderPlaceholderReferenceCount = @($materialCopyRows | Measure-Object -Property SanitizedShaderPlaceholderReferenceCount -Sum).Sum
    PrefabPatchCsv = $prefabPatchCsv
    MaterialCopyCsv = $materialCopyCsv
    SummaryJson = $summaryJson
    Report = $reportPath
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Unity Semantic Material Rebind: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Source project: `{0}`' -f $SourceProjectPath))
$reportLines.Add('')
$reportLines.Add(('Output project: `{0}`' -f $OutputProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Candidate rows | $($summary.CandidateRows) |")
$reportLines.Add("| Unique candidate materials | $($summary.UniqueCandidateMaterials) |")
$reportLines.Add("| Prefabs patched | $($summary.PrefabsPatched) |")
$reportLines.Add("| Prefab patch rows | $($summary.PrefabPatchRows) |")
$reportLines.Add("| Replaced prefab rows | $($summary.ReplacedPrefabRows) |")
$reportLines.Add("| Sanitized placeholder texture refs | $($summary.SanitizedTexturePlaceholderReferenceCount) |")
$reportLines.Add("| Sanitized shader placeholder refs | $($summary.SanitizedShaderPlaceholderReferenceCount) |")
$reportLines.Add('')
$reportLines.Add('## Interpretation')
$reportLines.Add('')
$reportLines.Add('This is an offline material-identity repair experiment. It can replace generic `Lit_*` renderer slots with better-named semantic materials, but sanitized texture placeholders mean original texture fidelity is still not restored. Unity visible validation is still required.')
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $prefabPatchCsv))
$reportLines.Add(('- `{0}`' -f $materialCopyCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary
