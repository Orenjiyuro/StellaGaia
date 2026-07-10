[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04',
    [string]$ExportRoot,
    [string]$ValidationRoot,
    [int]$SampleLimit = 12,
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

function Get-IntProperty {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        return 0
    }

    $text = [string]$Object.$Name
    $result = 0
    if ([int]::TryParse($text, [ref]$result)) {
        return $result
    }

    $doubleResult = 0.0
    if ([double]::TryParse($text, [ref]$doubleResult)) {
        return [int]$doubleResult
    }

    return 0
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Add-IssueIf {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Issues,
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        $Issues.Add($Message) | Out-Null
    }
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Environment Module Reuse Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add(('Name: `{0}`' -f $Summary.name)) | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Static issue count | $($Summary.staticIssueCount) |") | Out-Null
    $lines.Add("| Unity status | $($Summary.unity.status) |") | Out-Null
    $lines.Add("| Visible samples | $($Summary.unity.visibleSampleCount) |") | Out-Null
    $lines.Add("| Critical issues | $($Summary.unity.criticalIssueCount) |") | Out-Null
    $lines.Add("| Material review pack | $($Summary.materialReviewPack.status) |") | Out-Null
    $lines.Add("| Fidelity review | $($Summary.fidelity.review) |") | Out-Null
    $lines.Add("| Can accept environment module | $($Summary.canAcceptEnvironmentModule) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Static Metrics') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Metric | Value |') | Out-Null
    $lines.Add('| --- | ---: |') | Out-Null
    foreach ($property in $Summary.staticMetrics.PSObject.Properties) {
        $lines.Add("| $($property.Name) | $($property.Value) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Root Prefabs') | Out-Null
    $lines.Add('') | Out-Null
    foreach ($prefab in $Summary.rootPrefabs) {
        $lines.Add(('- `{0}`' -f $prefab)) | Out-Null
    }
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
    $lines.Add('## Next Required Action') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.nextRequiredAction) | Out-Null

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Join-Path $repoRoot 'Extracted'
$manifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$manifest = Read-JsonFile -Path $manifestPath
$sourceInstall = if ($null -ne $manifest) { [string]$manifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ExportRoot)) {
    $ExportRoot = Join-Path $extractedRoot 'AssetRipper\EnvironmentModuleSlices'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\EnvironmentModuleReuseGate'
}

$ExportRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ExportRoot
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$projectPath = Join-Path $ExportRoot "$Name\ExportedProject"
$gateOutput = Join-Path $ValidationRoot $Name

Assert-PathUnderOrEqual -Path $ExportRoot -Root $extractedRoot -Label 'ExportRoot'
Assert-PathUnderOrEqual -Path $ValidationRoot -Root $extractedRoot -Label 'ValidationRoot'
Assert-PathNotUnder -Path $ExportRoot -Root $sourceInstall -Label 'ExportRoot'
Assert-PathNotUnder -Path $ValidationRoot -Root $sourceInstall -Label 'ValidationRoot'
Assert-PathNotUnder -Path $projectPath -Root $sourceInstall -Label 'ProjectPath'

New-Item -ItemType Directory -Force -Path $gateOutput | Out-Null

$manualMappingPath = Join-Path $repoRoot 'Tools\AssetImport\ManualTextureMaps\Environment009ModuleSalvageSet01TextureRebind04.csv'
$textureSummaryPath = Join-Path $extractedRoot "Repairs\SemanticMaterialTextures\$Name\semantic-material-texture-rebind-summary.json"
$referenceSummaryPath = Join-Path $extractedRoot "Validation\UnityReferenceGraph\$Name\reference-graph-summary.json"
$placeholderSummaryPath = Join-Path $extractedRoot "Validation\UnityPlaceholderContext\$Name\placeholder-context-summary.json"
$salvageSummaryPath = Join-Path $extractedRoot "Validation\UnitySalvageCandidates\$Name\salvage-candidates-summary.json"

$rootPrefabs = @(
    'Assets/assetbundles/environment/roguelike_2/mesh/Roguelike_Battle_009_A_01_Building01.prefab',
    'Assets/assetbundles/environment/roguelike_2/mesh/Roguelike_Battle_009_A_06_Floor01.prefab',
    'Assets/assetbundles/environment/roguelike_2/mesh/Roguelike_2_Battle_009_MainWall.prefab',
    'Assets/assetbundles/environment/roguelike_2/mesh/Roguelike_Battle_009_A_05_door01.prefab',
    'Assets/assetbundles/environment/roguelike_2/mesh/Roguelike_Battle_009_A_04_commodity01.prefab'
)

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

Add-IssueIf -Issues $issues -Condition (-not (Test-Path -LiteralPath $projectPath -PathType Container)) -Message "Missing exported project: $projectPath"
Add-IssueIf -Issues $issues -Condition (-not (Test-Path -LiteralPath (Join-Path $projectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) -Message 'Missing ProjectSettings\ProjectVersion.txt in exported project.'

foreach ($evidencePath in @($manualMappingPath, $textureSummaryPath, $referenceSummaryPath, $placeholderSummaryPath, $salvageSummaryPath)) {
    Add-IssueIf -Issues $issues -Condition (-not (Test-Path -LiteralPath $evidencePath -PathType Leaf)) -Message "Missing environment gate evidence: $evidencePath"
}

foreach ($rootPrefab in $rootPrefabs) {
    $prefabPath = Join-Path $projectPath ($rootPrefab -replace '/', [System.IO.Path]::DirectorySeparatorChar)
    Add-IssueIf -Issues $issues -Condition (-not (Test-Path -LiteralPath $prefabPath -PathType Leaf)) -Message "Missing root prefab: $rootPrefab"
}

$textureSummary = Read-JsonFile -Path $textureSummaryPath
$referenceSummary = Read-JsonFile -Path $referenceSummaryPath
$placeholderSummary = Read-JsonFile -Path $placeholderSummaryPath
$salvageSummary = Read-JsonFile -Path $salvageSummaryPath

$materialsProcessed = Get-IntProperty -Object $textureSummary -Name 'MaterialsProcessed'
$exactTextureMatches = Get-IntProperty -Object $textureSummary -Name 'MaterialsWithAnyExactTexture'
$manualTextureMatches = Get-IntProperty -Object $textureSummary -Name 'MaterialsWithAnyManualTexture'
$diffuseMaterials = Get-IntProperty -Object $textureSummary -Name 'MaterialsWithDiffuseTexture'
$copiedTextures = Get-IntProperty -Object $textureSummary -Name 'UniqueTextureFilesToCopy'
$patchedTextureProperties = Get-IntProperty -Object $textureSummary -Name 'PatchedTextureProperties'
$referenceCount = Get-IntProperty -Object $referenceSummary -Name 'ReferenceCount'
$existingReferenceCount = Get-IntProperty -Object $referenceSummary -Name 'ExistingReferenceCount'
$missingGuidReferenceCount = Get-IntProperty -Object $referenceSummary -Name 'MissingGuidReferenceCount'
$deadbeefReferenceCount = Get-IntProperty -Object $referenceSummary -Name 'DeadbeefGuidReferenceCount'
$zeroGuidReferenceCount = Get-IntProperty -Object $referenceSummary -Name 'ZeroGuidReferenceCount'
$scanErrorCount = Get-IntProperty -Object $referenceSummary -Name 'ScanErrorCount'
$placeholderReferenceCount = Get-IntProperty -Object $placeholderSummary -Name 'PlaceholderReferenceCount'
$staticCandidateCount = Get-IntProperty -Object $salvageSummary -Name 'StaticRenderableSalvageCandidateCount'
$assetCount = Get-IntProperty -Object $salvageSummary -Name 'AssetCount'

$materialReviewPack = & (Join-Path $PSScriptRoot 'New-EnvironmentModuleMaterialReviewPack.ps1') -Name $Name
$materialReviewPackStatus = if ([int]$materialReviewPack.issueCount -eq 0 -and [int]$materialReviewPack.texturePreviewCount -eq [int]$materialReviewPack.textureBindingCount) { 'ReadyForManualMaterialReview' } else { 'HasIssues' }
foreach ($issue in @($materialReviewPack.issues)) {
    $issues.Add("Environment material review pack: $issue") | Out-Null
}
foreach ($warning in @($materialReviewPack.warnings)) {
    $warnings.Add("Environment material review pack: $warning") | Out-Null
}

Add-IssueIf -Issues $issues -Condition ($materialsProcessed -lt 12) -Message "Expected at least 12 semantic materials processed; got $materialsProcessed."
Add-IssueIf -Issues $issues -Condition ($diffuseMaterials -lt 11) -Message "Expected at least 11 diffuse-bound materials; got $diffuseMaterials."
Add-IssueIf -Issues $issues -Condition ($manualTextureMatches -lt 3) -Message "Expected at least 3 manually reviewed texture bindings; got $manualTextureMatches."
Add-IssueIf -Issues $issues -Condition ($referenceCount -eq 0) -Message 'Reference graph summary has no references.'
Add-IssueIf -Issues $issues -Condition ($referenceCount -ne $existingReferenceCount) -Message "Reference graph is not closed: $existingReferenceCount of $referenceCount refs exist."
Add-IssueIf -Issues $issues -Condition ($missingGuidReferenceCount -ne 0) -Message "Reference graph has $missingGuidReferenceCount missing GUID refs."
Add-IssueIf -Issues $issues -Condition ($deadbeefReferenceCount -ne 0) -Message "Reference graph has $deadbeefReferenceCount placeholder refs."
Add-IssueIf -Issues $issues -Condition ($zeroGuidReferenceCount -ne 0) -Message "Reference graph has $zeroGuidReferenceCount zero GUID refs."
Add-IssueIf -Issues $issues -Condition ($scanErrorCount -ne 0) -Message "Reference graph has $scanErrorCount scan errors."
Add-IssueIf -Issues $issues -Condition ($placeholderReferenceCount -ne 0) -Message "Placeholder context found $placeholderReferenceCount placeholder refs."
Add-IssueIf -Issues $issues -Condition ($assetCount -lt 5) -Message "Expected at least 5 scanned module prefabs; got $assetCount."
Add-IssueIf -Issues $issues -Condition ($staticCandidateCount -lt 5) -Message "Expected at least 5 static renderable root candidates; got $staticCandidateCount."

$backgroundMappingStatus = 'Missing'
if (Test-Path -LiteralPath $manualMappingPath -PathType Leaf) {
    $backgroundRows = @(Import-Csv -LiteralPath $manualMappingPath | Where-Object { [string]$_.MaterialName -eq 'Roguelike_Battle_009_A_04_background01' })
    if ($backgroundRows.Count -gt 0) {
        $skipRows = @($backgroundRows | Where-Object { [string]$_.Decision -eq 'Skip' })
        if ($skipRows.Count -gt 0) {
            $backgroundMappingStatus = 'IntentionallySkipped'
        } else {
            $backgroundMappingStatus = 'MappedOrUndeclared'
            $warnings.Add('background01 is no longer explicitly skipped; confirm this was a visible-fidelity decision, not a metrics-only bind.') | Out-Null
        }
    } else {
        $warnings.Add('Manual mapping manifest has no row for Roguelike_Battle_009_A_04_background01.') | Out-Null
    }
}

$unity = [ordered]@{
    status = if ($RunUnity) { 'Pending' } else { 'NotRun' }
    validationJson = Join-Path $gateOutput 'validation.json'
    unityLog = Join-Path $gateOutput 'unity-import-and-validation.log'
    summaryJson = Join-Path $extractedRoot 'Logs\asset-category-usability-summary.json'
    visibleSampleCount = 0
    criticalIssueCount = 0
    usabilityStatus = ''
    importStatus = ''
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity) {
    $categoryValidator = Join-Path $PSScriptRoot 'Test-AssetRipperCategoryUsability.ps1'
    $startedAt = Get-Date
    try {
        & $categoryValidator -Category $Name -ExportRoot $ExportRoot -ValidationRoot $ValidationRoot -SampleLimit $SampleLimit | Out-Host
    } catch {
        $warnings.Add("Unity validator invocation threw: $($_.Exception.Message)") | Out-Null
    }

    if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
        $licenseHit = Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet
        $unity.licenseBlocked = [bool]$licenseHit
    }

    if (Test-Path -LiteralPath $unity.validationJson -PathType Leaf) {
        $validationInfo = Get-Item -LiteralPath $unity.validationJson
        $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
        if ($unity.freshValidation) {
            $validation = Read-JsonFile -Path $unity.validationJson
            $unity.visibleSampleCount = Get-IntProperty -Object $validation -Name 'visibleSampleCount'
            $unity.criticalIssueCount = Get-IntProperty -Object $validation -Name 'criticalIssueCount'
        }
    }

    $summaryRows = Read-JsonFile -Path $unity.summaryJson
    if ($null -ne $summaryRows) {
        $matchingRows = @($summaryRows | Where-Object { [string]$_.Category -eq $Name })
        if ($matchingRows.Count -gt 0) {
            $row = $matchingRows[0]
            $unity.usabilityStatus = [string]$row.UsabilityStatus
            $unity.importStatus = [string]$row.ImportStatus
            if ($unity.visibleSampleCount -eq 0) {
                $unity.visibleSampleCount = Get-IntProperty -Object $row -Name 'VisibleSampleCount'
            }
            if ($unity.criticalIssueCount -eq 0) {
                $unity.criticalIssueCount = Get-IntProperty -Object $row -Name 'CriticalIssueCount'
            }
        }
    }

    if ($unity.licenseBlocked) {
        $unity.status = 'BlockedUnityLicense'
    } elseif (-not $unity.freshValidation) {
        $unity.status = 'MissingFreshValidation'
    } elseif ($unity.visibleSampleCount -lt 5) {
        $unity.status = 'VisibleSmokeFailed'
    } elseif ($unity.criticalIssueCount -ne 0) {
        $unity.status = 'VisibleSmokeHasCriticalIssues'
    } else {
        $unity.status = 'VisibleSmokePassed'
    }
}

$staticMetrics = [ordered]@{
    materialsProcessed = $materialsProcessed
    exactTextureMatches = $exactTextureMatches
    manualTextureMatches = $manualTextureMatches
    diffuseBoundMaterials = $diffuseMaterials
    copiedTextureFiles = $copiedTextures
    patchedTextureProperties = $patchedTextureProperties
    referenceCount = $referenceCount
    existingReferenceCount = $existingReferenceCount
    missingGuidReferenceCount = $missingGuidReferenceCount
    placeholderReferenceCount = $placeholderReferenceCount
    zeroGuidReferenceCount = $zeroGuidReferenceCount
    scanErrorCount = $scanErrorCount
    scannedPrefabCount = $assetCount
    staticRenderableRootCandidateCount = $staticCandidateCount
    background01MappingStatus = $backgroundMappingStatus
}

$gateStatus = 'StaticFailed'
$nextRequiredAction = 'Fix static evidence before running Unity visible validation.'
$canAcceptEnvironmentModule = $false
if ($issues.Count -eq 0) {
    if (-not $RunUnity) {
        $gateStatus = 'StaticReadyNeedsUnityVisibleValidation'
        $nextRequiredAction = 'Run `Tools\AssetImport\Test-EnvironmentModuleReuseGate.ps1 -RunUnity` after Unity licensing is active, then review screenshots for recognizable original StellaSora module fidelity.'
    } elseif ($unity.status -eq 'BlockedUnityLicense') {
        $gateStatus = 'BlockedUnityLicense'
        $nextRequiredAction = 'Activate the Unity editor license, then rerun this script with -RunUnity.'
    } elseif ($unity.status -eq 'VisibleSmokePassed') {
        if ($FidelityReview -eq 'Recognizable') {
            $gateStatus = 'PassedDevelopmentUsableCandidate'
            $canAcceptEnvironmentModule = $true
            $nextRequiredAction = 'Use this module set only for a controlled vertical-slice import proof; do not batch expand EnvironmentArt.'
        } elseif ($FidelityReview -eq 'Unrecognizable') {
            $gateStatus = 'RejectedVisibleFidelity'
            $nextRequiredAction = 'Reject this EnvironmentArt module route for the Hades-like room loop and switch room art to replacement/original assets.'
        } else {
            $gateStatus = 'VisibleSmokePassedNeedsFidelityReview'
            $nextRequiredAction = 'Inspect the generated screenshots. Continue only if the modules are recognizable original StellaSora environment art, not merely non-empty fallback geometry.'
        }
    } else {
        $gateStatus = $unity.status
        $nextRequiredAction = 'Use the Unity log, validation JSON, and screenshots to repair the module slice or reject EnvironmentArt for gameplay-room reuse.'
    }
}

$summaryJson = Join-Path $gateOutput 'environment-module-reuse-gate-summary.json'
$reportPath = Join-Path $gateOutput 'environment-module-reuse-gate-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    name = $Name
    projectPath = $projectPath
    exportRoot = $ExportRoot
    validationRoot = $ValidationRoot
    runUnity = [bool]$RunUnity
    gateStatus = $gateStatus
    canAcceptEnvironmentModule = $canAcceptEnvironmentModule
    summaryJson = $summaryJson
    reportPath = $reportPath
    rootPrefabs = @($rootPrefabs)
    staticIssueCount = $issues.Count
    staticIssues = @($issues)
    staticWarnings = @($warnings)
    staticMetrics = [PSCustomObject]$staticMetrics
    materialReviewPack = [PSCustomObject]@{
        status = $materialReviewPackStatus
        materialCount = [int]$materialReviewPack.materialCount
        boundMaterialCount = [int]$materialReviewPack.boundMaterialCount
        unboundMaterialCount = [int]$materialReviewPack.unboundMaterialCount
        manualBoundMaterialCount = [int]$materialReviewPack.manualBoundMaterialCount
        textureBindingCount = [int]$materialReviewPack.textureBindingCount
        texturePreviewCount = [int]$materialReviewPack.texturePreviewCount
        staticPrefabCandidateCount = [int]$materialReviewPack.staticPrefabCandidateCount
        skippedManualMappingCount = [int]$materialReviewPack.skippedManualMappingCount
        warningCount = [int]$materialReviewPack.warningCount
        issueCount = [int]$materialReviewPack.issueCount
        indexHtml = [string]$materialReviewPack.indexHtml
        materialReviewTsv = [string]$materialReviewPack.materialReviewTsv
        summaryJson = [string]$materialReviewPack.summaryJson
        interpretation = [string]$materialReviewPack.interpretation
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

if ($issues.Count -gt 0) {
    throw "Environment module reuse gate static validation failed with $($issues.Count) issue(s)."
}
