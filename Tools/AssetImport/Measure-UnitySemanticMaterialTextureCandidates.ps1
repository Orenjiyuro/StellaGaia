[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01WeakTextureCandidates01',
    [string]$TextureProjectPath,
    [string]$MaterialTextureBindingCsv,
    [string]$SemanticMaterialCandidateCsv,
    [string]$OutputRoot,
    [int]$TopPerMaterial = 12,
    [int]$ReviewScoreThreshold = 300
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

function Assert-SafeNameSegment {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Name must be a simple path segment. Got: $Value"
    }
}

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    return $FullPath.Substring($ProjectRoot.Length + 1).Replace('\', '/')
}

function Normalize-AssetName {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ([regex]::Replace($Value.ToLowerInvariant(), '[^a-z0-9]', ''))
}

function Get-Tokens {
    param([AllowNull()][string]$Value)

    $stopWords = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(
        'assets',
        'assetbundles',
        'environment',
        'roguelike',
        'texture',
        'textures',
        'material',
        'materials',
        'mesh',
        'prefab',
        'battle'
    ) | ForEach-Object { [void]$stopWords.Add($_) }

    $expanded = [regex]::Replace(([string]$Value), '(?<=[a-z])(?=[A-Z])', ' ')
    $tokens = [System.Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($expanded.ToLowerInvariant(), '[a-z]+|\d+')) {
        $token = $match.Value
        if ($stopWords.Contains($token)) {
            continue
        }
        $tokens.Add($token)
    }

    return @($tokens | Sort-Object -Unique)
}

function Get-TextureRoleAndBase {
    param([Parameter(Mandatory = $true)][string]$Stem)

    $role = 'Diffuse'
    $base = $Stem
    if ($Stem -match '^(.*)_([dnme])(\d*)$') {
        $base = $Matches[1]
        switch ($Matches[2].ToLowerInvariant()) {
            'd' { $role = 'Diffuse' }
            'n' { $role = 'Normal' }
            'm' { $role = 'Metallic' }
            'e' { $role = 'Emission' }
        }
    }

    return [PSCustomObject]@{
        Base = $base
        Role = $role
    }
}

function New-TextureIndex {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$AssetsRoot
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $textureFiles = @(Get-ChildItem -LiteralPath $AssetsRoot -Recurse -File -Include *.png,*.jpg,*.jpeg,*.tga,*.psd)
    foreach ($file in $textureFiles) {
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $roleAndBase = Get-TextureRoleAndBase -Stem $stem
        $assetPath = Get-ProjectRelativePath -FullPath $file.FullName -ProjectRoot $ProjectPath
        $rows.Add([PSCustomObject]@{
            AssetPath = $assetPath
            Name = $stem
            Base = $roleAndBase.Base
            Role = $roleAndBase.Role
            NormalizedBase = Normalize-AssetName -Value $roleAndBase.Base
            Tokens = @(Get-Tokens -Value "$assetPath $($roleAndBase.Base)")
        })
    }

    return @($rows)
}

function Get-MaterialContexts {
    param([Parameter(Mandatory = $true)][string]$SemanticMaterialCandidateCsv)

    $contexts = @{}
    if (-not (Test-Path -LiteralPath $SemanticMaterialCandidateCsv -PathType Leaf)) {
        return $contexts
    }

    foreach ($row in Import-Csv -LiteralPath $SemanticMaterialCandidateCsv) {
        $name = [string]$row.CandidateMaterialName
        if ([string]::IsNullOrWhiteSpace($name)) {
            continue
        }

        if (-not $contexts.ContainsKey($name)) {
            $contexts[$name] = [System.Collections.Generic.List[string]]::new()
        }

        $contexts[$name].Add([string]$row.PrefabAssetPath)
        $contexts[$name].Add([string]$row.PrefabName)
        $contexts[$name].Add([string]$row.RendererGameObjectName)
        $contexts[$name].Add([string]$row.CandidateMaterialPath)
    }

    return $contexts
}

function Measure-CandidateScore {
    param(
        [Parameter(Mandatory = $true)][object]$Material,
        [Parameter(Mandatory = $true)][string[]]$ContextTokens,
        [Parameter(Mandatory = $true)][object]$Texture
    )

    $materialName = [string]$Material.MaterialName
    $normalizedMaterial = Normalize-AssetName -Value $materialName
    $normalizedTexture = [string]$Texture.NormalizedBase
    $materialTokens = @(Get-Tokens -Value $materialName)
    $textureTokens = @($Texture.Tokens)
    $shared = @($ContextTokens | Where-Object { $textureTokens -contains $_ } | Sort-Object -Unique)
    $materialShared = @($materialTokens | Where-Object { $textureTokens -contains $_ } | Sort-Object -Unique)

    $score = 0
    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($normalizedTexture -eq $normalizedMaterial) {
        $score += 1000
        $reasons.Add('exact-normalized-name')
    } elseif ($normalizedTexture.Contains($normalizedMaterial) -or $normalizedMaterial.Contains($normalizedTexture)) {
        $score += 450
        $reasons.Add('contains-normalized-name')
    }

    if ($materialShared.Count -gt 0) {
        $score += $materialShared.Count * 120
        $reasons.Add("material-token:$($materialShared -join '+')")
    }

    if ($shared.Count -gt 0) {
        $score += $shared.Count * 70
        $reasons.Add("context-token:$($shared -join '+')")
    }

    foreach ($important in @('door', 'window', 'glass', 'background', 'light', 'mall', 'camera', 'commodity', 'icebox', 'poster', 'washing', 'floor', 'wall', 'building')) {
        if ($materialTokens -contains $important -and $textureTokens -contains $important) {
            $score += 180
            $reasons.Add("important-token:$important")
        }
    }

    if ($Texture.Role -eq 'Diffuse') {
        $score += 40
        $reasons.Add('diffuse-preferred')
    }
    if (($materialTokens -contains 'light' -or $materialTokens -contains 'glass') -and $Texture.Role -eq 'Emission') {
        $score += 80
        $reasons.Add('emission-for-light-or-glass')
    }

    return [PSCustomObject]@{
        Score = $score
        SharedTokens = ($shared -join ';')
        MaterialSharedTokens = ($materialShared -join ';')
        Reasons = ($reasons | Select-Object -Unique) -join ';'
    }
}

$repoRoot = Get-FullPath -Path (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-FullPath -Path (Join-Path $repoRoot 'Extracted')

Assert-SafeNameSegment -Value $Name

if ([string]::IsNullOrWhiteSpace($TextureProjectPath)) {
    $TextureProjectPath = Join-Path $extractedRoot 'AssetRipper\FolderExports\EnvironmentRoguelike2TextureOnly01\ExportedProject'
}
if ([string]::IsNullOrWhiteSpace($MaterialTextureBindingCsv)) {
    $MaterialTextureBindingCsv = Join-Path $extractedRoot 'Repairs\SemanticMaterialTextures\Environment009ModuleSalvageSet01SemanticMaterialTextureRebind03\semantic-material-texture-bindings.csv'
}
if ([string]::IsNullOrWhiteSpace($SemanticMaterialCandidateCsv)) {
    $SemanticMaterialCandidateCsv = Join-Path $extractedRoot 'Validation\UnitySemanticMaterialCandidates\Environment009ModuleSalvageSet01GuidClosure\semantic-material-candidates.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UnitySemanticMaterialTextureCandidates'
}

$TextureProjectPath = Get-FullPath -Path $TextureProjectPath
$MaterialTextureBindingCsv = Get-FullPath -Path $MaterialTextureBindingCsv
$SemanticMaterialCandidateCsv = Get-FullPath -Path $SemanticMaterialCandidateCsv
$OutputRoot = Get-FullPath -Path $OutputRoot
$outputDirectory = Get-FullPath -Path (Join-Path $OutputRoot $Name)

foreach ($entry in @(
    @{ Path = $TextureProjectPath; Label = 'TextureProjectPath' },
    @{ Path = $MaterialTextureBindingCsv; Label = 'MaterialTextureBindingCsv' },
    @{ Path = $SemanticMaterialCandidateCsv; Label = 'SemanticMaterialCandidateCsv' },
    @{ Path = $OutputRoot; Label = 'OutputRoot' },
    @{ Path = $outputDirectory; Label = 'OutputDirectory' }
)) {
    Assert-PathUnderOrEqual -Path $entry.Path -Root $extractedRoot -Description $entry.Label
}

if (-not (Test-Path -LiteralPath (Join-Path $TextureProjectPath 'Assets') -PathType Container)) {
    throw "Missing texture export Assets folder: $TextureProjectPath"
}
if (-not (Test-Path -LiteralPath $MaterialTextureBindingCsv -PathType Leaf)) {
    throw "Missing material texture binding CSV: $MaterialTextureBindingCsv"
}
if (-not (Test-Path -LiteralPath $SemanticMaterialCandidateCsv -PathType Leaf)) {
    throw "Missing semantic material candidate CSV: $SemanticMaterialCandidateCsv"
}

[void][System.IO.Directory]::CreateDirectory($outputDirectory)

$textures = New-TextureIndex -ProjectPath $TextureProjectPath -AssetsRoot (Join-Path $TextureProjectPath 'Assets')
$materialContexts = Get-MaterialContexts -SemanticMaterialCandidateCsv $SemanticMaterialCandidateCsv
$materials = @(Import-Csv -LiteralPath $MaterialTextureBindingCsv)
$unboundMaterials = @($materials | Where-Object { [int]$_.MatchedTextureCount -eq 0 })

$candidateRows = [System.Collections.Generic.List[object]]::new()
foreach ($material in $unboundMaterials) {
    $contextText = "$($material.MaterialName) $($material.MaterialPath)"
    if ($materialContexts.ContainsKey($material.MaterialName)) {
        $contextText += ' ' + (($materialContexts[$material.MaterialName] | Select-Object -Unique) -join ' ')
    }
    $contextTokens = @(Get-Tokens -Value $contextText)

    $scored = foreach ($texture in $textures) {
        $scoreInfo = Measure-CandidateScore -Material $material -ContextTokens $contextTokens -Texture $texture
        if ($scoreInfo.Score -le 0) {
            continue
        }

        [PSCustomObject]@{
            MaterialName = $material.MaterialName
            MaterialPath = $material.MaterialPath
            TexturePath = $texture.AssetPath
            TextureName = $texture.Name
            TextureRole = $texture.Role
            Score = $scoreInfo.Score
            CandidateStatus = if ($scoreInfo.Score -ge $ReviewScoreThreshold) { 'ReviewCandidate' } else { 'WeakCandidate' }
            MaterialSharedTokens = $scoreInfo.MaterialSharedTokens
            SharedTokens = $scoreInfo.SharedTokens
            Reasons = $scoreInfo.Reasons
        }
    }

    foreach ($row in @($scored | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, TexturePath | Select-Object -First $TopPerMaterial)) {
        $candidateRows.Add($row)
    }
}

$rowsCsv = Join-Path $outputDirectory 'weak-texture-candidates.csv'
$summaryJson = Join-Path $outputDirectory 'weak-texture-candidates-summary.json'
$reportPath = Join-Path $outputDirectory 'weak-texture-candidates-report.md'

$candidateRows | Export-Csv -LiteralPath $rowsCsv -NoTypeInformation -Encoding UTF8

$materialsWithReviewCandidates = @(
    $candidateRows |
        Where-Object { $_.CandidateStatus -eq 'ReviewCandidate' } |
        Select-Object -ExpandProperty MaterialName -Unique
).Count

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    TextureProjectPath = $TextureProjectPath
    MaterialTextureBindingCsv = $MaterialTextureBindingCsv
    SemanticMaterialCandidateCsv = $SemanticMaterialCandidateCsv
    OutputDirectory = $outputDirectory
    TextureCount = $textures.Count
    MaterialsProcessed = $materials.Count
    UnboundMaterials = $unboundMaterials.Count
    CandidateRows = $candidateRows.Count
    ReviewScoreThreshold = $ReviewScoreThreshold
    MaterialsWithReviewCandidates = $materialsWithReviewCandidates
    RowsCsv = $rowsCsv
    SummaryJson = $summaryJson
    Report = $reportPath
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add('# Weak Texture Candidates')
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add('| Metric | Value |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Texture count | $($summary.TextureCount) |")
$reportLines.Add("| Materials processed | $($summary.MaterialsProcessed) |")
$reportLines.Add("| Unbound materials | $($summary.UnboundMaterials) |")
$reportLines.Add("| Candidate rows | $($summary.CandidateRows) |")
$reportLines.Add("| Review score threshold | $($summary.ReviewScoreThreshold) |")
$reportLines.Add("| Materials with review candidates | $($summary.MaterialsWithReviewCandidates) |")
$reportLines.Add('')
$reportLines.Add('These are not automatically bound. They require manual image/fidelity review before creating another texture rebind.')
$reportLines.Add('')

foreach ($materialName in @($unboundMaterials | Select-Object -ExpandProperty MaterialName)) {
    $reportLines.Add("## $materialName")
    $reportLines.Add('')
    $reportLines.Add('| Status | Score | Role | Texture | Reasons |')
    $reportLines.Add('| --- | ---: | --- | --- | --- |')
    foreach ($row in @($candidateRows | Where-Object { $_.MaterialName -eq $materialName } | Sort-Object -Property @{ Expression = 'Score'; Descending = $true }, TexturePath)) {
        $reportLines.Add(('| {0} | {1} | {2} | `{3}` | {4} |' -f $row.CandidateStatus, $row.Score, $row.TextureRole, $row.TexturePath, $row.Reasons))
    }
    $reportLines.Add('')
}

$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary
