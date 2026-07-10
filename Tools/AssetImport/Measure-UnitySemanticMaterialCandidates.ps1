[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01GuidClosure',
    [string]$ProjectPath,
    [string]$MaterialSourceProjectPath,
    [string]$OutputRoot,
    [int]$MinimumCandidateScore = 120
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

function Get-Tokens {
    param([AllowNull()][string]$Text)

    $stopWords = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @('assetbundles', 'environment', 'material', 'materials', 'mesh', 'roguelike', 'battle') | ForEach-Object { [void]$stopWords.Add($_) }
    $tokens = [System.Collections.Generic.List[string]]::new()
    $expanded = [regex]::Replace(([string]$Text), '(?<=[a-z])(?=[A-Z])', ' ')
    foreach ($match in [regex]::Matches($expanded.ToLowerInvariant(), '[a-z]+\d+[a-z]*|[a-z]+|\d+')) {
        $token = $match.Value
        if ($stopWords.Contains($token)) {
            continue
        }
        $tokens.Add($token)
    }
    return @($tokens | Select-Object -Unique)
}

function Get-SemanticKeys {
    param([AllowNull()][string]$Text)

    $keys = [System.Collections.Generic.List[string]]::new()
    foreach ($token in (Get-Tokens -Text $Text)) {
        $normalized = $token
        if ($normalized -match '^([a-z]+)(\d+)[a-z]$') {
            $normalized = "$($Matches[1])$($Matches[2])"
        }

        if ($normalized -match '^(building|floor|wall|glass|door|commodity|background|camera|icebox|light|object|poster|radio|shelf|washing|prop|plane|trim|edge|star|moon|window)\d*$') {
            $keys.Add($normalized)
            if ($normalized -match '^([a-z]+)\d+$') {
                $keys.Add($Matches[1])
            }
        }
        elseif ($normalized -in @('building', 'floor', 'wall', 'glass', 'door', 'commodity', 'background', 'camera', 'icebox', 'light', 'object', 'poster', 'radio', 'shelf', 'washing', 'prop', 'plane', 'trim', 'edge', 'star', 'moon', 'window')) {
            $keys.Add($normalized)
        }
    }

    return @($keys | Select-Object -Unique)
}

function Get-MaterialInfo {
    param(
        [Parameter(Mandatory = $true)][string]$MaterialPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    $content = Get-Content -LiteralPath $MaterialPath -Raw
    $nameMatch = [regex]::Match($content, '(?m)^\s*m_Name:\s*(.+?)\s*$')
    $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value.Trim() } else { [System.IO.Path]::GetFileNameWithoutExtension($MaterialPath) }
    $relativePath = Get-ProjectRelativePath -FullPath $MaterialPath -ProjectRoot $ProjectRoot
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($MaterialPath)
    $deadbeefRefs = [regex]::Matches($content, 'deadbeef|deadf00d').Count
    $texturePlaceholderRefs = [regex]::Matches($content, 'm_Texture:\s*\{fileID:\s*(?!0\b)\d+,\s*guid:\s*[0-9a-f]*dead(?:beef|f00d)[0-9a-f]*,\s*type:\s*\d+\}').Count
    $shaderPlaceholderRefs = [regex]::Matches($content, 'm_Shader:\s*\{fileID:\s*(?!0\b)\d+,\s*guid:\s*[0-9a-f]*dead(?:beef|f00d)[0-9a-f]*,\s*type:\s*\d+\}').Count
    $textureRefs = [regex]::Matches($content, 'm_Texture:\s*\{fileID:\s*(?!0\b)\d+,\s*guid:\s*([0-9a-f]{32}),\s*type:\s*\d+\}').Count

    return [PSCustomObject]@{
        Guid = Get-MetaGuid -AssetPath $MaterialPath
        Name = $name
        Stem = $stem
        AssetPath = $relativePath
        FullPath = $MaterialPath
        IsGeneric = ($relativePath -match '^Assets/Material/' -or $name -match '^Lit(_\d+)?$')
        Tokens = @(Get-Tokens -Text "$name $relativePath")
        DeadbeefReferenceCount = $deadbeefRefs
        TextureReferenceCount = $textureRefs
        TexturePlaceholderReferenceCount = $texturePlaceholderRefs
        ShaderPlaceholderReferenceCount = $shaderPlaceholderRefs
    }
}

function Get-NameScore {
    param(
        [Parameter(Mandatory = $true)][string]$RendererName,
        [Parameter(Mandatory = $true)][string]$PrefabName,
        [Parameter(Mandatory = $true)]$Candidate
    )

    $rendererNorm = $RendererName.ToLowerInvariant()
    $prefabNorm = $PrefabName.ToLowerInvariant()
    $candidateNorm = ([string]$Candidate.Stem).ToLowerInvariant()
    $score = 0
    $rendererKeys = @(Get-SemanticKeys -Text $RendererName)
    $prefabKeys = @(Get-SemanticKeys -Text $PrefabName)
    $candidateKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($key in (Get-SemanticKeys -Text $Candidate.Stem)) {
        [void]$candidateKeys.Add($key)
    }

    if ($candidateNorm -eq $rendererNorm) {
        $score += 1000
    }
    elseif ($candidateNorm.Contains($rendererNorm) -or $rendererNorm.Contains($candidateNorm)) {
        $score += 600
    }

    if ($candidateNorm -eq $prefabNorm) {
        $score += 500
    }
    elseif ($candidateNorm.Contains($prefabNorm) -or $prefabNorm.Contains($candidateNorm)) {
        $score += 250
    }

    $sourceTokens = @(Get-Tokens -Text "$RendererName $PrefabName")
    $candidateTokens = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($token in $Candidate.Tokens) {
        [void]$candidateTokens.Add($token)
    }

    foreach ($token in $sourceTokens) {
        if (-not $candidateTokens.Contains($token)) {
            continue
        }

        if ($token -match '^\d+$') {
            if ($token.Length -ge 2) {
                $score += 80
            }
            else {
                $score += 15
            }
        }
        elseif ($token.Length -ge 4) {
            $score += 70
        }
        elseif ($token.Length -ge 2) {
            $score += 30
        }
        else {
            $score += 5
        }
    }

    $sourceRoomTokens = @($sourceTokens | Where-Object { $_ -match '^\d{3}$' } | Select-Object -Unique)
    $candidateRoomTokens = @($Candidate.Tokens | Where-Object { $_ -match '^\d{3}$' } | Select-Object -Unique)
    foreach ($roomToken in $sourceRoomTokens) {
        if ($candidateRoomTokens -contains $roomToken) {
            $score += 320
        }
        elseif ($candidateRoomTokens.Count -gt 0) {
            $score -= 1000
        }
    }

    foreach ($key in ($rendererKeys | Select-Object -Unique)) {
        if ($candidateKeys.Contains($key)) {
            if ($key -match '\d+$') {
                $score += 500
            }
            else {
                $score += 120
            }
        }
    }

    foreach ($key in ($prefabKeys | Select-Object -Unique)) {
        if ($candidateKeys.Contains($key)) {
            if ($key -match '\d+$') {
                $score += 250
            }
            else {
                $score += 60
            }
        }
    }

    $hasRendererSemanticKey = @($rendererKeys | Where-Object { $_ -notmatch '^\d+$' }).Count -gt 0
    $hasSharedRendererSemanticKey = $false
    foreach ($key in $rendererKeys) {
        if ($candidateKeys.Contains($key)) {
            $hasSharedRendererSemanticKey = $true
            break
        }
    }
    if ($hasRendererSemanticKey -and -not $hasSharedRendererSemanticKey) {
        $score -= 220
    }

    foreach ($misleadingKey in @('star', 'moon', 'light')) {
        if ($candidateKeys.Contains($misleadingKey) -and ($rendererKeys -notcontains $misleadingKey)) {
            $score -= 120
        }
    }

    return $score
}

function Get-BestMaterialCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$RendererName,
        [Parameter(Mandatory = $true)][string]$PrefabName,
        [Parameter(Mandatory = $true)][array]$Candidates
    )

    $ranked = @(
        foreach ($candidate in $Candidates) {
            [PSCustomObject]@{
                Candidate = $candidate
                Score = Get-NameScore -RendererName $RendererName -PrefabName $PrefabName -Candidate $candidate
            }
        }
    ) | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, @{ Expression = { $_.Candidate.TexturePlaceholderReferenceCount }; Descending = $false }, @{ Expression = { $_.Candidate.AssetPath }; Descending = $false }

    if ($ranked.Count -eq 0) {
        return $null
    }

    return $ranked[0]
}

function Get-PrefabRendererMaterialRows {
    param(
        [Parameter(Mandatory = $true)][string]$PrefabPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][hashtable]$TargetMaterialsByGuid,
        [Parameter(Mandatory = $true)][array]$SourceMaterialCandidates
    )

    $relativePrefabPath = Get-ProjectRelativePath -FullPath $PrefabPath -ProjectRoot $ProjectRoot
    $prefabName = [System.IO.Path]::GetFileNameWithoutExtension($PrefabPath)
    $content = Get-Content -LiteralPath $PrefabPath -Raw
    $sections = [regex]::Split($content, '(?m)^--- ')
    $gameObjectNames = @{}
    $rendererSections = [System.Collections.Generic.List[object]]::new()

    foreach ($section in $sections) {
        $header = [regex]::Match($section, '^!u!(\d+) &(\d+)')
        if (-not $header.Success) {
            continue
        }

        $classId = $header.Groups[1].Value
        $objectId = $header.Groups[2].Value
        if ($classId -eq '1') {
            $nameMatch = [regex]::Match($section, '(?m)^\s*m_Name:\s*(.+?)\s*$')
            if ($nameMatch.Success) {
                $gameObjectNames[$objectId] = $nameMatch.Groups[1].Value.Trim()
            }
        }
        elseif ($classId -in @('23', '137')) {
            $rendererSections.Add([PSCustomObject]@{
                ObjectId = $objectId
                Section = $section
            })
        }
    }

    foreach ($rendererSection in $rendererSections) {
        $gameObjectIdMatch = [regex]::Match($rendererSection.Section, 'm_GameObject:\s*\{fileID:\s*(\d+)\}')
        $gameObjectId = if ($gameObjectIdMatch.Success) { $gameObjectIdMatch.Groups[1].Value } else { '' }
        $rendererName = if ($gameObjectId -and $gameObjectNames.ContainsKey($gameObjectId)) { $gameObjectNames[$gameObjectId] } else { $prefabName }
        $materialMatches = [regex]::Matches($rendererSection.Section, '\{fileID:\s*2100000,\s*guid:\s*([0-9a-f]{32}),\s*type:\s*\d+\}')

        $slotIndex = 0
        foreach ($materialMatch in $materialMatches) {
            $guid = $materialMatch.Groups[1].Value
            $targetMaterial = if ($TargetMaterialsByGuid.ContainsKey($guid)) { $TargetMaterialsByGuid[$guid] } else { $null }
            $isGeneric = ($null -ne $targetMaterial -and $targetMaterial.IsGeneric)
            $best = if ($isGeneric) { Get-BestMaterialCandidate -RendererName $rendererName -PrefabName $prefabName -Candidates $SourceMaterialCandidates } else { $null }
            $candidate = if ($best) { $best.Candidate } else { $null }
            $candidateScore = if ($best) { $best.Score } else { 0 }
            $candidateStatus = if (-not $isGeneric) {
                'NotGeneric'
            }
            elseif ($null -eq $candidate) {
                'NoCandidate'
            }
            elseif ($candidateScore -ge $MinimumCandidateScore) {
                'SemanticCandidate'
            }
            else {
                'WeakCandidate'
            }

            [PSCustomObject]@{
                PrefabAssetPath = $relativePrefabPath
                PrefabName = $prefabName
                RendererObjectId = $rendererSection.ObjectId
                RendererGameObjectName = $rendererName
                MaterialSlot = $slotIndex
                OriginalMaterialGuid = $guid
                OriginalMaterialPath = if ($targetMaterial) { $targetMaterial.AssetPath } else { '' }
                OriginalMaterialName = if ($targetMaterial) { $targetMaterial.Name } else { '' }
                OriginalMaterialIsGeneric = $isGeneric
                CandidateStatus = $candidateStatus
                CandidateScore = $candidateScore
                CandidateMaterialPath = if ($candidate) { $candidate.AssetPath } else { '' }
                CandidateMaterialName = if ($candidate) { $candidate.Name } else { '' }
                CandidateDeadbeefReferenceCount = if ($candidate) { $candidate.DeadbeefReferenceCount } else { 0 }
                CandidateTextureReferenceCount = if ($candidate) { $candidate.TextureReferenceCount } else { 0 }
                CandidateTexturePlaceholderReferenceCount = if ($candidate) { $candidate.TexturePlaceholderReferenceCount } else { 0 }
                CandidateShaderPlaceholderReferenceCount = if ($candidate) { $candidate.ShaderPlaceholderReferenceCount } else { 0 }
            }
            $slotIndex++
        }
    }
}

$repoRoot = Get-FullPath -Path (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-FullPath -Path (Join-Path $repoRoot 'Extracted')
if (-not $ProjectPath) {
    $ProjectPath = Join-Path $extractedRoot "AssetRipper\EnvironmentModuleSlices\$Name\ExportedProject"
}
if (-not $MaterialSourceProjectPath) {
    $MaterialSourceProjectPath = Join-Path $extractedRoot 'AssetRipper\RoomSamples\EnvironmentRoomSample009CabFocused\ExportedProject'
}
if (-not $OutputRoot) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UnitySemanticMaterialCandidates'
}

$ProjectPath = Get-FullPath -Path $ProjectPath
$MaterialSourceProjectPath = Get-FullPath -Path $MaterialSourceProjectPath
$OutputRoot = Get-FullPath -Path $OutputRoot
$outputDirectory = Join-Path $OutputRoot $Name

Assert-PathUnderOrEqual -Path $ProjectPath -Root $extractedRoot -Description 'ProjectPath'
Assert-PathUnderOrEqual -Path $MaterialSourceProjectPath -Root $extractedRoot -Description 'MaterialSourceProjectPath'
Assert-PathUnderOrEqual -Path $OutputRoot -Root $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'Assets') -PathType Container)) {
    throw "ProjectPath is missing Assets: $ProjectPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $MaterialSourceProjectPath 'Assets') -PathType Container)) {
    throw "MaterialSourceProjectPath is missing Assets: $MaterialSourceProjectPath"
}

New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

$targetMaterialsByGuid = @{}
Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'Assets') -Recurse -File -Filter '*.mat' | ForEach-Object {
    $info = Get-MaterialInfo -MaterialPath $_.FullName -ProjectRoot $ProjectPath
    if (-not [string]::IsNullOrWhiteSpace($info.Guid)) {
        $targetMaterialsByGuid[$info.Guid] = $info
    }
}

$sourceMaterialRoot = Join-Path $MaterialSourceProjectPath 'Assets\assetbundles\environment\roguelike_2\material'
if (-not (Test-Path -LiteralPath $sourceMaterialRoot -PathType Container)) {
    throw "Material source project is missing roguelike_2/material: $sourceMaterialRoot"
}

$sourceMaterialCandidates = @(
    Get-ChildItem -LiteralPath $sourceMaterialRoot -Recurse -File -Filter '*.mat' |
        ForEach-Object { Get-MaterialInfo -MaterialPath $_.FullName -ProjectRoot $MaterialSourceProjectPath }
)

$prefabRows = @(
    Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'Assets\assetbundles\environment\roguelike_2\mesh') -File -Filter '*.prefab' |
        Sort-Object -Property FullName |
        ForEach-Object {
            Get-PrefabRendererMaterialRows -PrefabPath $_.FullName -ProjectRoot $ProjectPath -TargetMaterialsByGuid $targetMaterialsByGuid -SourceMaterialCandidates $sourceMaterialCandidates
        }
)

$uniqueCandidates = @($prefabRows | Where-Object { $_.CandidateStatus -eq 'SemanticCandidate' } | Select-Object -Property CandidateMaterialPath -Unique)
$summary = [PSCustomObject]@{
    GeneratedAt = (Get-Date).ToString('O')
    Name = $Name
    ProjectPath = $ProjectPath
    MaterialSourceProjectPath = $MaterialSourceProjectPath
    OutputDirectory = $outputDirectory
    TargetMaterialCount = $targetMaterialsByGuid.Count
    SourceMaterialCandidateCount = $sourceMaterialCandidates.Count
    PrefabCount = @($prefabRows | Select-Object -Property PrefabAssetPath -Unique).Count
    RendererMaterialSlotCount = $prefabRows.Count
    GenericRendererMaterialSlotCount = @($prefabRows | Where-Object { $_.OriginalMaterialIsGeneric }).Count
    SemanticCandidateSlotCount = @($prefabRows | Where-Object { $_.CandidateStatus -eq 'SemanticCandidate' }).Count
    WeakCandidateSlotCount = @($prefabRows | Where-Object { $_.CandidateStatus -eq 'WeakCandidate' }).Count
    NoCandidateSlotCount = @($prefabRows | Where-Object { $_.CandidateStatus -eq 'NoCandidate' }).Count
    UniqueSemanticCandidateCount = $uniqueCandidates.Count
    SemanticCandidateSlotsWithTexturePlaceholders = @($prefabRows | Where-Object { $_.CandidateStatus -eq 'SemanticCandidate' -and $_.CandidateTexturePlaceholderReferenceCount -gt 0 }).Count
    MinimumCandidateScore = $MinimumCandidateScore
}

$rowsCsv = Join-Path $outputDirectory 'semantic-material-candidates.csv'
$summaryJson = Join-Path $outputDirectory 'semantic-material-candidate-summary.json'
$reportPath = Join-Path $outputDirectory 'semantic-material-candidate-report.md'

$prefabRows | Export-Csv -LiteralPath $rowsCsv -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Unity Semantic Material Candidates: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Project: `{0}`' -f $ProjectPath))
$reportLines.Add('')
$reportLines.Add(('Material source: `{0}`' -f $MaterialSourceProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Target materials | $($summary.TargetMaterialCount) |")
$reportLines.Add("| Source material candidates | $($summary.SourceMaterialCandidateCount) |")
$reportLines.Add("| Prefabs | $($summary.PrefabCount) |")
$reportLines.Add("| Renderer material slots | $($summary.RendererMaterialSlotCount) |")
$reportLines.Add("| Generic renderer material slots | $($summary.GenericRendererMaterialSlotCount) |")
$reportLines.Add("| Semantic candidate slots | $($summary.SemanticCandidateSlotCount) |")
$reportLines.Add("| Weak candidate slots | $($summary.WeakCandidateSlotCount) |")
$reportLines.Add("| No-candidate slots | $($summary.NoCandidateSlotCount) |")
$reportLines.Add("| Unique semantic candidates | $($summary.UniqueSemanticCandidateCount) |")
$reportLines.Add("| Semantic candidate slots with placeholder textures | $($summary.SemanticCandidateSlotsWithTexturePlaceholders) |")
$reportLines.Add('')
$reportLines.Add('## Top Candidate Rows')
$reportLines.Add('')
$reportLines.Add('| Prefab | Renderer | Original | Candidate | Score | Texture placeholders |')
$reportLines.Add('| --- | --- | --- | --- | ---: | ---: |')
foreach ($row in ($prefabRows | Where-Object { $_.OriginalMaterialIsGeneric } | Sort-Object -Property PrefabAssetPath, RendererGameObjectName, MaterialSlot | Select-Object -First 40)) {
    $candidate = if ($row.CandidateMaterialPath) { $row.CandidateMaterialPath } else { $row.CandidateStatus }
    $reportLines.Add(('| `{0}` | `{1}` | `{2}` | `{3}` | {4} | {5} |' -f $row.PrefabAssetPath, $row.RendererGameObjectName, $row.OriginalMaterialPath, $candidate, $row.CandidateScore, $row.CandidateTexturePlaceholderReferenceCount))
}
$reportLines.Add('')
$reportLines.Add('## Interpretation')
$reportLines.Add('')
$reportLines.Add('This is a static material-provenance scan only. A semantic material candidate can improve material identity and color parameters, but any candidate with placeholder texture references still lacks original texture fidelity. It is not a Unity visible pass and does not authorize batch expansion.')
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $rowsCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary | Add-Member -NotePropertyName RowsCsv -NotePropertyValue $rowsCsv -Force
$summary | Add-Member -NotePropertyName Report -NotePropertyValue $reportPath -Force
$summary
