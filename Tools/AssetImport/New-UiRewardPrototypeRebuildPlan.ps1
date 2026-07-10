[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$VisualReviewTsv,
    [string]$PrefabRiskSummaryPath,
    [string]$OutputRoot
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

function Assert-PathNotUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if ((Test-Path -LiteralPath $RootPath) -and (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must not stay under source install $RootPath. Got: $Path"
    }
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return Get-CanonicalPath $Path
    }

    return Get-CanonicalPath (Join-Path $RepoRoot $Path)
}

function Assert-SafeAssetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '^Assets[/\\].+') {
        throw "Asset path must start with Assets/: $Path"
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

function Convert-ToSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9_.-]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'default'
    }

    return $safe
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    $metaPath = "$AssetPath.meta"
    if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
        return ''
    }

    $match = Select-String -LiteralPath $metaPath -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
    if ($null -eq $match) {
        return ''
    }

    return $match.Matches[0].Groups[1].Value.ToLowerInvariant()
}

function Get-ExistingProjectGuidIndex {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $index = @{}
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $index
    }

    foreach ($metaFile in Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.meta' -Force -ErrorAction SilentlyContinue) {
        $match = Select-String -LiteralPath $metaFile.FullName -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
        if ($null -eq $match) {
            continue
        }

        $guid = $match.Matches[0].Groups[1].Value.ToLowerInvariant()
        if (-not $index.ContainsKey($guid)) {
            $index[$guid] = [System.Collections.Generic.List[string]]::new()
        }
        $index[$guid].Add((Get-CanonicalPath $metaFile.FullName)) | Out-Null
    }

    return $index
}

function Test-SameFileContent {
    param(
        [Parameter(Mandatory = $true)][string]$LeftPath,
        [Parameter(Mandatory = $true)][string]$RightPath
    )

    if (-not (Test-Path -LiteralPath $LeftPath -PathType Leaf) -or -not (Test-Path -LiteralPath $RightPath -PathType Leaf)) {
        return $false
    }

    $left = Get-Item -LiteralPath $LeftPath
    $right = Get-Item -LiteralPath $RightPath
    if ($left.Length -ne $right.Length) {
        return $false
    }

    $leftHash = (Get-FileHash -LiteralPath $LeftPath -Algorithm SHA256).Hash
    $rightHash = (Get-FileHash -LiteralPath $RightPath -Algorithm SHA256).Hash
    return $leftHash.Equals($rightHash, [System.StringComparison]::OrdinalIgnoreCase)
}

function Measure-ImageContent {
    param([Parameter(Mandatory = $true)][string]$Path)

    $image = [System.Drawing.Bitmap]::FromFile($Path)
    try {
        $sampleCount = 0
        $alphaCount = 0
        $nonWhiteCount = 0
        $xStep = [Math]::Max(1, [Math]::Floor($image.Width / 64))
        $yStep = [Math]::Max(1, [Math]::Floor($image.Height / 64))
        for ($y = 0; $y -lt $image.Height; $y += $yStep) {
            for ($x = 0; $x -lt $image.Width; $x += $xStep) {
                $sampleCount++
                $pixel = $image.GetPixel($x, $y)
                if ($pixel.A -gt 0) {
                    $alphaCount++
                }
                if ($pixel.A -gt 0 -and ($pixel.R -lt 245 -or $pixel.G -lt 245 -or $pixel.B -lt 245)) {
                    $nonWhiteCount++
                }
            }
        }

        return [PSCustomObject]@{
            width = $image.Width
            height = $image.Height
            alphaSampleRatio = if ($sampleCount -eq 0) { 0.0 } else { [Math]::Round($alphaCount / [double]$sampleCount, 6) }
            visibleContentSampleRatio = if ($sampleCount -eq 0) { 0.0 } else { [Math]::Round($nonWhiteCount / [double]$sampleCount, 6) }
        }
    } finally {
        $image.Dispose()
    }
}

function Convert-ToTargetTexturePath {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$SourcePath
    )

    $safeId = Convert-ToSafeFileName -Value $Id
    $fileName = [System.IO.Path]::GetFileName($SourcePath)
    return "Assets/StellaGaia/Imported/ControlledCandidates/ui_reward/PrototypeRebuild/Textures/$safeId/$fileName"
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$docsRoot = Join-Path $repoRoot 'docs'
$extractedRoot = Join-Path $repoRoot 'Extracted'
$assetsRoot = Join-Path $repoRoot 'Assets'
$controlledRoot = Join-Path $assetsRoot 'StellaGaia\Imported\ControlledCandidates'
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $docsRoot 'asset-migration\minimum-ui-reward-selection.json'
}
if ([string]::IsNullOrWhiteSpace($VisualReviewTsv)) {
    $VisualReviewTsv = Join-Path $extractedRoot 'Validation\MinimumUiRewardVisualReviewPack\minimum-ui-reward-visual-review.tsv'
}
if ([string]::IsNullOrWhiteSpace($PrefabRiskSummaryPath)) {
    $PrefabRiskSummaryPath = Join-Path $extractedRoot 'Validation\UiRewardPrefabStaticRiskGate\ui-reward-prefab-static-risk-summary.json'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UiRewardPrototypeRebuildPlan'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$VisualReviewTsv = Resolve-RepoPath -RepoRoot $repoRoot -Path $VisualReviewTsv
$PrefabRiskSummaryPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $PrefabRiskSummaryPath
$OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $docsRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $VisualReviewTsv -RootPath $extractedRoot -Description 'VisualReviewTsv'
Assert-PathUnderOrEqual -Path $PrefabRiskSummaryPath -RootPath $extractedRoot -Description 'PrefabRiskSummaryPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathNotUnder -Path $OutputRoot -RootPath $sourceInstall -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing UI/reward manifest: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $VisualReviewTsv -PathType Leaf)) {
    throw "Missing UI/reward visual review TSV: $VisualReviewTsv"
}
if (-not (Test-Path -LiteralPath $PrefabRiskSummaryPath -PathType Leaf)) {
    throw "Missing UI/reward prefab risk summary: $PrefabRiskSummaryPath"
}

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
$prefabRisk = Read-JsonFile -Path $PrefabRiskSummaryPath
$existingGuidIndex = Get-ExistingProjectGuidIndex -RootPath $assetsRoot
$reviewById = @{}
foreach ($review in @(Import-Csv -LiteralPath $VisualReviewTsv -Delimiter "`t")) {
    $reviewById[[string]$review.id] = $review
}

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$textureRows = [System.Collections.Generic.List[object]]::new()
$specTextures = [System.Collections.Generic.List[object]]::new()
$acceptedReviews = @('Recognizable', 'Confirmed')
$requiredTextureRoles = @('RewardItemTexture', 'UpgradeCardIcon', 'UpgradeCardLargeArt')
$optionalTextureRoles = @('UpgradeCardPackArt')

foreach ($selection in @($manifest.selections | Where-Object { [string]$_.kind -eq 'Texture2D' })) {
    $id = [string]$selection.id
    $role = [string]$selection.role
    $review = $reviewById[$id]
    $reviewValue = if ($null -eq $review) { 'NotReviewed' } else { [string]$review.review }
    $sourcePath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$selection.path)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $extractedRoot -Description "Texture source '$id'"
    Assert-PathNotUnder -Path $sourcePath -RootPath $sourceInstall -Description "Texture source '$id'"

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $issues.Add("Missing texture source '$id': $sourcePath") | Out-Null
        continue
    }

    $targetAssetPath = Convert-ToTargetTexturePath -Id $id -SourcePath $sourcePath
    Assert-SafeAssetPath -Path $targetAssetPath
    $targetFullPath = Get-CanonicalPath (Join-Path $repoRoot $targetAssetPath)
    Assert-PathUnderOrEqual -Path $targetFullPath -RootPath $controlledRoot -Description "Target texture '$id'"
    $targetMetaPath = "$targetFullPath.meta"

    $sourceGuid = Get-MetaGuid -AssetPath $sourcePath
    if ([string]::IsNullOrWhiteSpace($sourceGuid)) {
        $issues.Add("Missing texture source meta GUID '$id': $sourcePath.meta") | Out-Null
    }

    if ($acceptedReviews -notcontains $reviewValue) {
        if ($requiredTextureRoles -contains $role) {
            $issues.Add("Required texture '$id' has no accepted offline review: $reviewValue") | Out-Null
        } else {
            $warnings.Add("Optional texture '$id' has no accepted offline review: $reviewValue") | Out-Null
        }
    }

    $content = Measure-ImageContent -Path $sourcePath
    if ($content.alphaSampleRatio -le 0.001) {
        $issues.Add("Texture '$id' appears empty by alpha sampling.") | Out-Null
    }

    if (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
        if (-not (Test-SameFileContent -LeftPath $sourcePath -RightPath $targetFullPath)) {
            $issues.Add("Existing target texture differs for '$id': $targetFullPath") | Out-Null
        }
    }
    if (Test-Path -LiteralPath $targetMetaPath -PathType Leaf) {
        if (-not (Test-SameFileContent -LeftPath "$sourcePath.meta" -RightPath $targetMetaPath)) {
            $issues.Add("Existing target texture meta differs for '$id': $targetMetaPath") | Out-Null
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($sourceGuid) -and $existingGuidIndex.ContainsKey($sourceGuid)) {
        $canonicalTargetMetaPath = Get-CanonicalPath $targetMetaPath
        $conflicts = @($existingGuidIndex[$sourceGuid] | Where-Object {
            -not ([string]$_).Equals($canonicalTargetMetaPath, [System.StringComparison]::OrdinalIgnoreCase)
        })
        if ($conflicts.Count -gt 0) {
            $issues.Add("Texture GUID '$sourceGuid' for '$id' already exists outside planned target: $($conflicts -join '; ')") | Out-Null
        }
    }

    $isRequired = $requiredTextureRoles -contains $role
    $isOptional = $optionalTextureRoles -contains $role
    $isAccepted = $acceptedReviews -contains $reviewValue
    $row = [PSCustomObject]@{
        id = $id
        role = $role
        required = $isRequired
        optional = $isOptional
        review = $reviewValue
        sourcePath = $sourcePath
        sourceMetaPath = "$sourcePath.meta"
        sourceGuid = $sourceGuid
        targetAssetPath = $targetAssetPath
        targetFullPath = $targetFullPath
        targetMetaPath = $targetMetaPath
        width = [int]$content.width
        height = [int]$content.height
        alphaSampleRatio = [double]$content.alphaSampleRatio
        visibleContentSampleRatio = [double]$content.visibleContentSampleRatio
        bytes = [int64](Get-Item -LiteralPath $sourcePath).Length
        acceptedForPrototypePlan = $isAccepted
    }
    $textureRows.Add($row) | Out-Null
    if ($isAccepted) {
        $specTextures.Add([PSCustomObject]@{
            id = $id
            role = $role
            targetAssetPath = $targetAssetPath
            width = [int]$content.width
            height = [int]$content.height
            review = $reviewValue
        }) | Out-Null
    }
}

foreach ($role in $requiredTextureRoles) {
    $matching = @($textureRows | Where-Object { [string]$_.role -eq $role -and [bool]$_.acceptedForPrototypePlan })
    if ($matching.Count -lt 1) {
        $issues.Add("Missing accepted texture role for prototype rebuild: $role") | Out-Null
    }
}

$totalBytes = 0L
foreach ($row in $textureRows) {
    if ([bool]$row.acceptedForPrototypePlan) {
        $totalBytes += [int64]$row.bytes
    }
}

$generatedRoot = 'Assets/StellaGaia/Imported/ControlledCandidates/ui_reward/PrototypeRebuild/Generated'
$generatedAssets = @(
    [PSCustomObject]@{ kind = 'RewardDropPrefab'; assetPath = "$generatedRoot/RewardDropPrototype.prefab"; sourceTextureRole = 'RewardItemTexture' },
    [PSCustomObject]@{ kind = 'UpgradeCardWidgetPrefab'; assetPath = "$generatedRoot/UpgradeCardWidgetPrototype.prefab"; sourceTextureRole = 'UpgradeCardIcon;UpgradeCardLargeArt' },
    [PSCustomObject]@{ kind = 'UpgradeChoicePanelPrefab'; assetPath = "$generatedRoot/UpgradeChoicePanelPrototype.prefab"; sourceTextureRole = 'UpgradeCardIcon;UpgradeCardLargeArt;UpgradeCardPackArt' }
)

$canStageSourceTextures = ($issues.Count -eq 0 -and $specTextures.Count -ge 3)
$status = if ($canStageSourceTextures) { 'TextureSourcePlanReadyNeedsControlledStaging' } else { 'TextureSourcePlanBlocked' }
$nextRequiredAction = if ($canStageSourceTextures) {
    'Stage the accepted UI/reward textures into the controlled candidate area, then use a Unity Editor builder to create simple reward/card UI prefabs from those textures. This does not accept the original high-risk UI prefabs.'
} else {
    'Fix missing texture review, source, meta, or GUID issues before staging UI/reward texture sources.'
}

$sourcePlanCsv = Join-Path $OutputRoot 'ui-reward-prototype-source-textures.csv'
$specJson = Join-Path $OutputRoot 'ui-reward-prototype-rebuild-spec.json'
$summaryJson = Join-Path $OutputRoot 'ui-reward-prototype-rebuild-plan-summary.json'
$reportPath = Join-Path $OutputRoot 'ui-reward-prototype-rebuild-plan.md'

$textureRows | Export-Csv -LiteralPath $sourcePlanCsv -NoTypeInformation -Encoding UTF8
$spec = [PSCustomObject]@{
    mode = 'UiRewardTexturePrototypeRebuild'
    note = 'Build simple local Unity reward/card UI using selected original StellaSora Texture2D assets. Do not import original high-risk UI prefabs as runtime-ready assets.'
    textureAssets = @($specTextures)
    generatedAssets = @($generatedAssets)
    rejectedOriginalPrefabRoute = [PSCustomObject]@{
        gateStatus = [string]$prefabRisk.gateStatus
        highRiskPrefabCount = [int]$prefabRisk.highRiskPrefabCount
        visualMissingPrefabCount = [int]$prefabRisk.visualMissingPrefabCount
        summaryJson = $PrefabRiskSummaryPath
    }
}
$spec | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $specJson -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    status = $status
    manifestPath = $ManifestPath
    visualReviewTsv = $VisualReviewTsv
    prefabRiskSummaryPath = $PrefabRiskSummaryPath
    outputRoot = $OutputRoot
    acceptedTextureCount = @($textureRows | Where-Object { [bool]$_.acceptedForPrototypePlan }).Count
    requiredAcceptedTextureCount = @($textureRows | Where-Object { [bool]$_.required -and [bool]$_.acceptedForPrototypePlan }).Count
    optionalAcceptedTextureCount = @($textureRows | Where-Object { [bool]$_.optional -and [bool]$_.acceptedForPrototypePlan }).Count
    totalBytes = $totalBytes
    canStageSourceTextures = $canStageSourceTextures
    issueCount = $issues.Count
    issues = @($issues)
    warningCount = $warnings.Count
    warnings = @($warnings)
    sourcePlanCsv = $sourcePlanCsv
    specJson = $specJson
    reportPath = $reportPath
    interpretation = 'This is a dry-run plan for rebuilding simple UI/reward prefabs from accepted original StellaSora textures. It does not stage textures, run Unity, render UI, or accept original UI prefabs.'
    nextRequiredAction = $nextRequiredAction
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# UI Reward Prototype Rebuild Plan') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Field | Value |') | Out-Null
$lines.Add('| --- | --- |') | Out-Null
$lines.Add("| Status | $($summary.status) |") | Out-Null
$lines.Add("| Accepted textures | $($summary.acceptedTextureCount) |") | Out-Null
$lines.Add("| Required accepted textures | $($summary.requiredAcceptedTextureCount) |") | Out-Null
$lines.Add("| Optional accepted textures | $($summary.optionalAcceptedTextureCount) |") | Out-Null
$lines.Add("| Can stage source textures | $($summary.canStageSourceTextures) |") | Out-Null
$lines.Add("| Issue count | $($summary.issueCount) |") | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Texture Sources') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Id | Role | Review | Size | Target |') | Out-Null
$lines.Add('| --- | --- | --- | ---: | --- |') | Out-Null
foreach ($row in $textureRows) {
    $lines.Add("| $($row.id) | $($row.role) | $($row.review) | $($row.width)x$($row.height) | `$($row.targetAssetPath)` |") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Generated Asset Plan') | Out-Null
$lines.Add('') | Out-Null
$lines.Add('| Kind | Planned asset | Source texture role |') | Out-Null
$lines.Add('| --- | --- | --- |') | Out-Null
foreach ($asset in $generatedAssets) {
    $lines.Add("| $($asset.kind) | `$($asset.assetPath)` | `$($asset.sourceTextureRole)` |") | Out-Null
}
$lines.Add('') | Out-Null
$lines.Add('## Issues') | Out-Null
$lines.Add('') | Out-Null
if ($issues.Count -eq 0) {
    $lines.Add('None.') | Out-Null
} else {
    foreach ($issue in $issues) {
        $lines.Add("- $issue") | Out-Null
    }
}
$lines.Add('') | Out-Null
$lines.Add('## Interpretation') | Out-Null
$lines.Add('') | Out-Null
$lines.Add($summary.interpretation) | Out-Null
$lines.Add('') | Out-Null
$lines.Add('## Next Required Action') | Out-Null
$lines.Add('') | Out-Null
$lines.Add($summary.nextRequiredAction) | Out-Null
$lines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary

if ($issues.Count -gt 0) {
    throw "UI/reward prototype rebuild plan has $($issues.Count) issue(s)."
}
