[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ValidationRoot,
    [switch]$RunUnity,
    [ValidateSet('NotReviewed', 'Recognizable', 'Unrecognizable')]
    [string]$FidelityReview = 'NotReviewed',
    [string]$FidelityNote
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
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $Root)) {
        throw "$Label must stay under $Root. Got: $Path"
    }
}

function Assert-PathNotUnder {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ((Test-Path -LiteralPath $Root) -and (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $Root)) {
        throw "$Label must not stay under source install $Root. Got: $Path"
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

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Convert-ToUnityAssetPath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$ProjectPath
    )

    $project = (Get-CanonicalPath $ProjectPath).TrimEnd('\', '/')
    $full = Get-CanonicalPath $FullPath
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $full -RootPath $project)) {
        throw "Selection path must stay under sourceExport project. Got: $FullPath"
    }

    return $full.Substring($project.Length + 1).Replace('\', '/')
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# UI Reward Reuse Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Static issue count | $($Summary.staticIssueCount) |") | Out-Null
    $lines.Add("| Static warning count | $($Summary.staticWarningCount) |") | Out-Null
    $lines.Add("| Unity status | $($Summary.unity.status) |") | Out-Null
    $lines.Add("| Visual review pack | $($Summary.visualReviewPack.status) |") | Out-Null
    $lines.Add("| Prefab static risk | $($Summary.prefabStaticRisk.gateStatus) |") | Out-Null
    $lines.Add("| Prototype build gate | $($Summary.prototypeBuildGate.gateStatus) |") | Out-Null
    $lines.Add("| Prototype rebuild plan | $($Summary.prototypeRebuildPlan.status) |") | Out-Null
    $lines.Add("| Prototype texture staging | $($Summary.prototypeTextureStaging.status) |") | Out-Null
    $lines.Add("| Prototype builder compile | $($Summary.prototypeBuilderPreflight.status) |") | Out-Null
    $lines.Add("| Can satisfy minimum UI/reward art | $($Summary.canSatisfyMinimumUiRewardArt) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Selected Assets') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Role | Kind | Unity path |') | Out-Null
    $lines.Add('| --- | --- | --- | --- |') | Out-Null
    foreach ($selection in $Summary.selections) {
        $lines.Add("| $($selection.id) | $($selection.role) | $($selection.kind) | `$($selection.unityPath)` |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Selected Prefab Static Risk') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.prefabStaticRisk.gateStatus) |") | Out-Null
    $lines.Add("| Prefabs | $($Summary.prefabStaticRisk.prefabCount) |") | Out-Null
    $lines.Add("| High-risk prefabs | $($Summary.prefabStaticRisk.highRiskPrefabCount) |") | Out-Null
    $lines.Add("| Visual-missing prefabs | $($Summary.prefabStaticRisk.visualMissingPrefabCount) |") | Out-Null
    $lines.Add("| Report | $($Summary.prefabStaticRisk.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Texture Prototype Build Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.prototypeBuildGate.gateStatus) |") | Out-Null
    $lines.Add("| Source textures staged | $($Summary.prototypeBuildGate.sourceTexturesStaged) |") | Out-Null
    $lines.Add("| Can accept rebuilt UI/reward prototype | $($Summary.prototypeBuildGate.canAcceptUiRewardPrototype) |") | Out-Null
    $lines.Add("| Report | $($Summary.prototypeBuildGate.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Texture Prototype Rebuild Plan') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.prototypeRebuildPlan.status) |") | Out-Null
    $lines.Add("| Accepted textures | $($Summary.prototypeRebuildPlan.acceptedTextureCount) |") | Out-Null
    $lines.Add("| Required accepted textures | $($Summary.prototypeRebuildPlan.requiredAcceptedTextureCount) |") | Out-Null
    $lines.Add("| Optional accepted textures | $($Summary.prototypeRebuildPlan.optionalAcceptedTextureCount) |") | Out-Null
    $lines.Add("| Can stage source textures | $($Summary.prototypeRebuildPlan.canStageSourceTextures) |") | Out-Null
    $lines.Add("| Report | $($Summary.prototypeRebuildPlan.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Texture Prototype Staging') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.prototypeTextureStaging.status) |") | Out-Null
    $lines.Add("| Planned textures | $($Summary.prototypeTextureStaging.plannedTextureCount) |") | Out-Null
    $lines.Add("| Existing target files | $($Summary.prototypeTextureStaging.existingTargetFileCount) |") | Out-Null
    $lines.Add("| Existing target metas | $($Summary.prototypeTextureStaging.existingTargetMetaCount) |") | Out-Null
    $lines.Add("| Source textures staged | $($Summary.prototypeTextureStaging.sourceTexturesStaged) |") | Out-Null
    $lines.Add("| Report | $($Summary.prototypeTextureStaging.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Texture Prototype Builder Preflight') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.prototypeBuilderPreflight.status) |") | Out-Null
    $lines.Add("| Script count | $($Summary.prototypeBuilderPreflight.scriptCount) |") | Out-Null
    $lines.Add("| Warnings | $($Summary.prototypeBuilderPreflight.warningCount) |") | Out-Null
    $lines.Add("| Errors | $($Summary.prototypeBuilderPreflight.errorCount) |") | Out-Null
    $lines.Add("| Output | $($Summary.prototypeBuilderPreflight.outputText) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    $lines.Add('') | Out-Null
    if ($Summary.staticIssues.Count -eq 0) {
        $lines.Add('None.') | Out-Null
    } else {
        foreach ($issue in $Summary.staticIssues) {
            $lines.Add("- $issue") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Warnings') | Out-Null
    $lines.Add('') | Out-Null
    if ($Summary.staticWarnings.Count -eq 0) {
        $lines.Add('None.') | Out-Null
    } else {
        foreach ($warning in $Summary.staticWarnings) {
            $lines.Add("- $warning") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Next Required Action') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.nextRequiredAction) | Out-Null

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Join-Path $repoRoot 'Extracted'
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-ui-reward-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\UiRewardReuseGate'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$gateOutput = Join-Path $ValidationRoot 'MinimumUiRewardSelection'

Assert-PathUnderOrEqual -Path $ManifestPath -Root $repoRoot -Label 'ManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -Root $extractedRoot -Label 'ValidationRoot'
Assert-PathNotUnder -Path $ValidationRoot -Root $sourceInstall -Label 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing UI/reward manifest: $ManifestPath"
}

New-Item -ItemType Directory -Force -Path $gateOutput | Out-Null

$selectionCheck = & (Join-Path $PSScriptRoot 'Test-MinimumUiRewardSelection.ps1') -ManifestPath $ManifestPath
$manifest = Read-JsonFile -Path $ManifestPath
$sourceExportPath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$manifest.sourceExport)
Assert-PathUnderOrEqual -Path $sourceExportPath -Root $extractedRoot -Label 'sourceExport'
Assert-PathNotUnder -Path $sourceExportPath -Root $sourceInstall -Label 'sourceExport'

$staticIssues = [System.Collections.Generic.List[string]]::new()
$staticWarnings = [System.Collections.Generic.List[string]]::new()
foreach ($issue in @($selectionCheck.Issues)) {
    $staticIssues.Add([string]$issue) | Out-Null
}
foreach ($warning in @($selectionCheck.Warnings)) {
    $staticWarnings.Add([string]$warning) | Out-Null
}

$visualReviewPack = & (Join-Path $PSScriptRoot 'New-MinimumUiRewardVisualReviewPack.ps1') -ManifestPath $ManifestPath
$visualReviewPackStatus = if ([int]$visualReviewPack.issueCount -eq 0 -and [int]$visualReviewPack.texturePreviewCount -eq [int]$visualReviewPack.textureCount) { 'ReadyForManualVisualReview' } else { 'HasIssues' }
foreach ($issue in @($visualReviewPack.issues)) {
    $staticIssues.Add("UI/reward visual review pack: $issue") | Out-Null
}
foreach ($warning in @($visualReviewPack.warnings)) {
    $staticWarnings.Add("UI/reward visual review pack: $warning") | Out-Null
}

$prefabStaticRisk = & (Join-Path $PSScriptRoot 'Test-UiRewardPrefabStaticRiskGate.ps1') -ManifestPath $ManifestPath
foreach ($issue in @($prefabStaticRisk.issues)) {
    $staticIssues.Add("UI/reward prefab static risk: $issue") | Out-Null
}
if ([string]$prefabStaticRisk.gateStatus -eq 'HighRiskDependencyClosureRequired') {
    $staticWarnings.Add('UI/reward prefab static risk: selected UI prefab requires high-risk dependency closure before runtime import.') | Out-Null
}
if ([int]$prefabStaticRisk.visualMissingPrefabCount -gt 0) {
    $staticWarnings.Add("UI/reward prefab static risk: $($prefabStaticRisk.visualMissingPrefabCount) selected drop prefab(s) have no renderer and depend on missing FX prefab references for visible output.") | Out-Null
}

$prototypeBuildGateArgs = @{}
if ($RunUnity) {
    $prototypeBuildGateArgs.RunUnity = $true
}
$prototypeBuildGate = & (Join-Path $PSScriptRoot 'Test-UiRewardPrototypeBuildGate.ps1') @prototypeBuildGateArgs
if ([int]$prototypeBuildGate.issueCount -gt 0) {
    foreach ($issue in @($prototypeBuildGate.issues)) {
        $staticIssues.Add("UI/reward prototype build gate: $issue") | Out-Null
    }
}
$prototypeRebuildPlan = $prototypeBuildGate.rebuildPlan
$prototypeTextureStaging = $prototypeBuildGate.textureStaging
$prototypeBuilderPreflight = $prototypeBuildGate.compilePreflight
$sourceTexturesStaged = [bool]$prototypeBuildGate.sourceTexturesStaged
if ([bool]$prototypeRebuildPlan.canStageSourceTextures) {
    $staticWarnings.Add('UI/reward texture prototype rebuild plan: accepted original Texture2D candidates can be staged for a controlled rebuild route; this does not accept the original UI/drop prefabs.') | Out-Null
}
if ($sourceTexturesStaged) {
    $staticWarnings.Add('UI/reward texture staging: accepted original Texture2D candidates are already staged under controlled candidates; Unity builder/render validation is still required.') | Out-Null
}

$selectedRows = [System.Collections.Generic.List[object]]::new()
$selectedAssetLines = [System.Collections.Generic.List[string]]::new()
foreach ($selection in @($manifest.selections)) {
    $pathText = [string]$selection.path
    $fullPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $pathText
    $unityPath = Convert-ToUnityAssetPath -FullPath $fullPath -ProjectPath $sourceExportPath
    $selectedAssetLines.Add($unityPath) | Out-Null
    $selectedRows.Add([PSCustomObject]@{
        id = [string]$selection.id
        role = [string]$selection.role
        kind = [string]$selection.kind
        status = [string]$selection.status
        path = $pathText
        unityPath = $unityPath
    }) | Out-Null
}

$selectedAssetListPath = Join-Path $gateOutput 'selected-assets.txt'
$selectedAssetLines | Set-Content -LiteralPath $selectedAssetListPath -Encoding UTF8

$unity = [ordered]@{
    status = if ($RunUnity) { 'Pending' } else { 'NotRun' }
    validationJson = Join-Path $ValidationRoot 'UiOrItemArt\validation.json'
    unityLog = Join-Path $ValidationRoot 'UiOrItemArt\unity-import-and-validation.log'
    selectedAssetList = $selectedAssetListPath
    visibleSampleCount = 0
    criticalIssueCount = 0
    requiredRolePassCount = 0
    requiredRoleCount = @($manifest.requiredRoles).Count
    failedRequiredRoles = @()
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity) {
    $validator = Join-Path $PSScriptRoot 'Test-AssetRipperCategoryUsability.ps1'
    $startedAt = Get-Date
    try {
        & $validator -Category UiOrItemArt -ExportRoot (Join-Path $extractedRoot 'AssetRipper\ByCategory') -ValidationRoot $ValidationRoot -AssetListPath $selectedAssetListPath -SampleLimit @($selectedRows).Count | Out-Host
    } catch {
        $staticWarnings.Add("Unity selected UI/reward validator threw: $($_.Exception.Message)") | Out-Null
    }

    if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
        $unity.licenseBlocked = [bool](Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet)
    }

    $validation = $null
    if (Test-Path -LiteralPath $unity.validationJson -PathType Leaf) {
        $validationInfo = Get-Item -LiteralPath $unity.validationJson
        $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
        if ($unity.freshValidation) {
            $validation = Read-JsonFile -Path $unity.validationJson
            $unity.visibleSampleCount = [int]$validation.visibleSampleCount
            $unity.criticalIssueCount = [int]$validation.criticalIssueCount
        }
    }

    if ($null -ne $validation) {
        $samplesByPath = @{}
        foreach ($sample in @($validation.samples)) {
            $samplesByPath[[string]$sample.path] = $sample
        }

        $failedRoles = [System.Collections.Generic.List[string]]::new()
        foreach ($requiredRole in @($manifest.requiredRoles)) {
            $role = [string]$requiredRole.role
            $roleSelections = @($selectedRows | Where-Object { $_.role -eq $role })
            $passed = $false
            foreach ($roleSelection in $roleSelections) {
                $sample = $samplesByPath[[string]$roleSelection.unityPath]
                if ($null -ne $sample -and [bool]$sample.visible -and [int]$sample.criticalIssueCount -eq 0) {
                    $passed = $true
                    break
                }
            }
            if ($passed) {
                $unity.requiredRolePassCount++
            } else {
                $failedRoles.Add($role) | Out-Null
            }
        }
        $unity.failedRequiredRoles = @($failedRoles)
    }

    if ($unity.licenseBlocked) {
        $unity.status = 'BlockedUnityLicense'
    } elseif (-not $unity.freshValidation) {
        $unity.status = 'MissingFreshSelectedValidation'
    } elseif ($unity.failedRequiredRoles.Count -gt 0) {
        $unity.status = 'SelectedVisibleSmokeFailed'
    } elseif ($FidelityReview -eq 'Recognizable') {
        $unity.status = 'SelectedVisibleSmokePassed'
    } elseif ($FidelityReview -eq 'Unrecognizable') {
        $unity.status = 'RejectedVisibleFidelity'
    } else {
        $unity.status = 'SelectedVisibleSmokePassedNeedsFidelityReview'
    }
}

$gateStatus = 'StaticFailed'
$canSatisfyMinimumUiRewardArt = $false
$nextRequiredAction = 'Fix static UI/reward selection issues before Unity visible validation.'
if ($staticIssues.Count -eq 0) {
    if (-not $RunUnity) {
        $gateStatus = if ($staticWarnings.Count -gt 0) { 'StaticReadableWithPrefabDependencyRisksNeedsUnityVisibleValidation' } else { 'StaticReadyNeedsUnityVisibleValidation' }
        if ([bool]$prototypeRebuildPlan.canStageSourceTextures) {
            if ($sourceTexturesStaged) {
                $nextRequiredAction = 'Build simple Unity reward/card prefabs from the staged accepted original UI/reward textures, then run focused Unity visible validation. Do not import the original high-risk UI/drop prefabs as runtime-ready assets.'
            } else {
                $nextRequiredAction = 'Stage the accepted original UI/reward textures into controlled candidates and build simple Unity reward/card prefabs from them, then run focused Unity visible validation. Do not import the original high-risk UI/drop prefabs as runtime-ready assets.'
            }
        } else {
            $nextRequiredAction = 'Run `Tools\AssetImport\Test-UiRewardReuseGate.ps1 -RunUnity` after Unity licensing is active, then inspect screenshots for selected reward/card visual fidelity.'
        }
    } elseif ($unity.status -eq 'BlockedUnityLicense') {
        $gateStatus = 'BlockedUnityLicense'
        $nextRequiredAction = 'Activate the Unity editor license, then rerun this script with -RunUnity.'
    } elseif ($unity.status -eq 'SelectedVisibleSmokePassed') {
        $gateStatus = 'PassedDevelopmentUsableCandidate'
        $canSatisfyMinimumUiRewardArt = $true
        $nextRequiredAction = 'Use these selected assets only for a controlled vertical-slice import proof; do not batch expand UiOrItemArt.'
    } elseif ($unity.status -eq 'RejectedVisibleFidelity') {
        $gateStatus = 'RejectedVisibleFidelity'
        $nextRequiredAction = 'Select replacement reward/card visuals or repair the selected UI/reward candidates before gameplay mainline work.'
    } else {
        $gateStatus = $unity.status
        $nextRequiredAction = 'Use selected-asset screenshots and validation JSON to repair or replace the failing reward/card candidates.'
    }
}

$summaryJson = Join-Path $gateOutput 'ui-reward-reuse-gate-summary.json'
$reportPath = Join-Path $gateOutput 'ui-reward-reuse-gate-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    sourceExport = $sourceExportPath
    validationRoot = $ValidationRoot
    runUnity = [bool]$RunUnity
    gateStatus = $gateStatus
    summaryJson = $summaryJson
    reportPath = $reportPath
    canSatisfyMinimumUiRewardArt = $canSatisfyMinimumUiRewardArt
    selectedAssetList = $selectedAssetListPath
    selectionCount = @($selectedRows).Count
    staticIssueCount = $staticIssues.Count
    staticIssues = @($staticIssues)
    staticWarningCount = $staticWarnings.Count
    staticWarnings = @($staticWarnings)
    selections = @($selectedRows)
    visualReviewPack = [PSCustomObject]@{
        status = $visualReviewPackStatus
        selectionCount = [int]$visualReviewPack.selectionCount
        textureCount = [int]$visualReviewPack.textureCount
        texturePreviewCount = [int]$visualReviewPack.texturePreviewCount
        prefabCount = [int]$visualReviewPack.prefabCount
        prefabWithPlaceholderCount = [int]$visualReviewPack.prefabWithPlaceholderCount
        warningCount = [int]$visualReviewPack.warningCount
        issueCount = [int]$visualReviewPack.issueCount
        indexHtml = [string]$visualReviewPack.indexHtml
        visualReviewTsv = [string]$visualReviewPack.visualReviewTsv
        summaryJson = [string]$visualReviewPack.summaryJson
        interpretation = [string]$visualReviewPack.interpretation
    }
    prefabStaticRisk = [PSCustomObject]@{
        gateStatus = [string]$prefabStaticRisk.gateStatus
        prefabCount = [int]$prefabStaticRisk.prefabCount
        lowRiskPrefabCount = [int]$prefabStaticRisk.lowRiskPrefabCount
        highRiskPrefabCount = [int]$prefabStaticRisk.highRiskPrefabCount
        visualMissingPrefabCount = [int]$prefabStaticRisk.visualMissingPrefabCount
        issueCount = [int]$prefabStaticRisk.issueCount
        summaryJson = [string]$prefabStaticRisk.summaryJson
        reportPath = [string]$prefabStaticRisk.reportPath
        nextRequiredAction = [string]$prefabStaticRisk.nextRequiredAction
    }
    prototypeBuildGate = [PSCustomObject]@{
        gateStatus = [string]$prototypeBuildGate.gateStatus
        sourceTexturesStaged = [bool]$prototypeBuildGate.sourceTexturesStaged
        canAcceptUiRewardPrototype = [bool]$prototypeBuildGate.canAcceptUiRewardPrototype
        runUnity = [bool]$prototypeBuildGate.runUnity
        unityStatus = [string]$prototypeBuildGate.unity.status
        visibleScreenshotCount = [int]$prototypeBuildGate.unity.visibleScreenshotCount
        issueCount = [int]$prototypeBuildGate.issueCount
        summaryJson = [string]$prototypeBuildGate.summaryJson
        reportPath = [string]$prototypeBuildGate.reportPath
        nextRequiredAction = [string]$prototypeBuildGate.nextRequiredAction
    }
    prototypeRebuildPlan = [PSCustomObject]@{
        status = [string]$prototypeRebuildPlan.status
        acceptedTextureCount = [int]$prototypeRebuildPlan.acceptedTextureCount
        requiredAcceptedTextureCount = [int]$prototypeRebuildPlan.requiredAcceptedTextureCount
        optionalAcceptedTextureCount = [int]$prototypeRebuildPlan.optionalAcceptedTextureCount
        totalBytes = [int64]$prototypeRebuildPlan.totalBytes
        canStageSourceTextures = [bool]$prototypeRebuildPlan.canStageSourceTextures
        issueCount = [int]$prototypeRebuildPlan.issueCount
        warningCount = [int]$prototypeRebuildPlan.warningCount
        sourcePlanCsv = [string]$prototypeRebuildPlan.sourcePlanCsv
        specJson = [string]$prototypeRebuildPlan.specJson
        reportPath = [string]$prototypeRebuildPlan.reportPath
        nextRequiredAction = [string]$prototypeRebuildPlan.nextRequiredAction
    }
    prototypeTextureStaging = [PSCustomObject]@{
        status = [string]$prototypeTextureStaging.status
        plannedTextureCount = [int]$prototypeTextureStaging.plannedTextureCount
        existingTargetFileCount = [int]$prototypeTextureStaging.existingTargetFileCount
        existingTargetMetaCount = [int]$prototypeTextureStaging.existingTargetMetaCount
        missingSourceCount = [int]$prototypeTextureStaging.missingSourceCount
        missingMetaCount = [int]$prototypeTextureStaging.missingMetaCount
        duplicateGuidCount = [int]$prototypeTextureStaging.duplicateGuidCount
        projectGuidConflictCount = [int]$prototypeTextureStaging.projectGuidConflictCount
        targetCollisionCount = [int]$prototypeTextureStaging.targetCollisionCount
        targetOverwriteRiskCount = [int]$prototypeTextureStaging.targetOverwriteRiskCount
        canApply = [bool]$prototypeTextureStaging.canApply
        sourceTexturesStaged = [bool]$sourceTexturesStaged
        summaryJson = [string]$prototypeTextureStaging.summaryJson
        reportPath = [string]$prototypeTextureStaging.reportPath
    }
    prototypeBuilderPreflight = [PSCustomObject]@{
        status = [string]$prototypeBuilderPreflight.status
        scriptCount = [int]$prototypeBuilderPreflight.scriptCount
        warningCount = [int]$prototypeBuilderPreflight.warningCount
        errorCount = [int]$prototypeBuilderPreflight.errorCount
        issueCount = [int]$prototypeBuilderPreflight.issueCount
        summaryJson = [string]$prototypeBuilderPreflight.summaryJson
        outputText = [string]$prototypeBuilderPreflight.outputText
        interpretation = [string]$prototypeBuilderPreflight.interpretation
    }
    unity = [PSCustomObject]$unity
    fidelity = [PSCustomObject]@{
        review = $FidelityReview
        note = if ([string]::IsNullOrWhiteSpace($FidelityNote)) { '' } else { $FidelityNote }
    }
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($staticIssues.Count -gt 0) {
    throw "UI/reward reuse gate static validation failed with $($staticIssues.Count) issue(s)."
}
