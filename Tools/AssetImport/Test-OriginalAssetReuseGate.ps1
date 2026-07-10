[CmdletBinding()]
param(
    [string]$ValidationRoot,
    [switch]$RunUnity,
    [ValidateSet('NotReviewed', 'Recognizable', 'Unrecognizable')]
    [string]$EnvironmentFidelityReview = 'NotReviewed',
    [ValidateSet('NotReviewed', 'Recognizable', 'Unrecognizable')]
    [string]$UiFidelityReview = 'NotReviewed',
    [ValidateSet('NotReviewed', 'Confirmed', 'Rejected')]
    [string]$AudioListeningReview = 'NotReviewed'
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

function Get-ObjectProperty {
    param(
        [object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object -or $Object.PSObject.Properties.Name -notcontains $Name) {
        return $Default
    }

    return $Object.$Name
}

function Get-LaneDecision {
    param(
        [string]$GateStatus,
        [bool]$Accepted
    )

    if ($Accepted) {
        return 'UseOriginalAsset'
    }
    if ($GateStatus -like 'Rejected*') {
        return 'PrototypeReplacement'
    }
    if ($GateStatus -eq 'Stop') {
        return 'Stop'
    }

    return 'RepairOnce'
}

function New-UnityEvidenceSummary {
    param([object]$Unity)

    return [PSCustomObject]@{
        status = [string](Get-ObjectProperty -Object $Unity -Name 'status' -Default '')
        validationJson = [string](Get-ObjectProperty -Object $Unity -Name 'validationJson' -Default '')
        validationText = [string](Get-ObjectProperty -Object $Unity -Name 'validationText' -Default '')
        unityLog = [string](Get-ObjectProperty -Object $Unity -Name 'unityLog' -Default '')
        visibleScreenshotCount = [int](Get-ObjectProperty -Object $Unity -Name 'visibleScreenshotCount' -Default 0)
        audioSourceAttachCount = [int](Get-ObjectProperty -Object $Unity -Name 'audioSourceAttachCount' -Default 0)
    }
}

function New-LaneSummary {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$GateStatus,
        [bool]$Accepted,
        [string]$DirectGateSummary,
        [string]$DirectGateReport,
        [string]$NextAllowedAction,
        [object]$Unity
    )

    return [PSCustomObject]@{
        name = $Name
        gateStatus = $GateStatus
        accepted = $Accepted
        decision = Get-LaneDecision -GateStatus $GateStatus -Accepted $Accepted
        directGateSummary = $DirectGateSummary
        directGateReport = $DirectGateReport
        unityEvidence = New-UnityEvidenceSummary -Unity $Unity
        nextAllowedAction = $NextAllowedAction
    }
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Original Asset Reuse Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Can start gameplay mainline | $($Summary.canStartGameplayMainline) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Gate Interpretation') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Asset acquisition feasibility | $($Summary.gateInterpretation.assetAcquisitionFeasibility) |") | Out-Null
    $lines.Add("| Asset reuse feasibility | $($Summary.gateInterpretation.assetReuseFeasibility) |") | Out-Null
    $lines.Add("| Can make gameplay Go decision | $($Summary.gateInterpretation.canMakeGameplayGoDecision) |") | Out-Null
    $lines.Add("| Requires Unity focused triage | $($Summary.gateInterpretation.requiresUnityFocusedTriage) |") | Out-Null
    $lines.Add("| Not original project restoration | $($Summary.gateInterpretation.notOriginalProjectRestoration) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Asset Acquisition Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.assetAcquisition.gateStatus) |") | Out-Null
    $lines.Add("| Can support Unity import triage | $($Summary.componentGates.assetAcquisition.canSupportUnityImportTriage) |") | Out-Null
    $lines.Add("| Can grant development usability | $($Summary.componentGates.assetAcquisition.canGrantDevelopmentUsability) |") | Out-Null
    $lines.Add("| Report | $($Summary.componentGates.assetAcquisition.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Unity Script Compile Preflight') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Compile status | $($Summary.unityScriptCompilePreflight.status) |") | Out-Null
    $lines.Add("| Script count | $($Summary.unityScriptCompilePreflight.scriptCount) |") | Out-Null
    $lines.Add("| Compile warnings | $($Summary.unityScriptCompilePreflight.warningCount) |") | Out-Null
    $lines.Add("| Compile errors | $($Summary.unityScriptCompilePreflight.errorCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Unity Focused Validation Readiness') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.unityFocusedValidationReadiness.gateStatus) |") | Out-Null
    $lines.Add("| Can run focused Unity validation | $($Summary.componentGates.unityFocusedValidationReadiness.canRunUnityFocusedValidation) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.componentGates.unityFocusedValidationReadiness.issueCount) |") | Out-Null
    $lines.Add("| Warning count | $($Summary.componentGates.unityFocusedValidationReadiness.warningCount) |") | Out-Null
    $lines.Add("| Report | $($Summary.componentGates.unityFocusedValidationReadiness.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Audio Audition Pack') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.audio.auditionPackStatus) |") | Out-Null
    $lines.Add("| Preview count | $($Summary.componentGates.audio.auditionPreviewCount) |") | Out-Null
    $lines.Add("| Review TSV | $($Summary.componentGates.audio.auditionReviewTsv) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## UI/Reward Visual Review Pack') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.uiReward.visualReviewPackStatus) |") | Out-Null
    $lines.Add("| Texture previews | $($Summary.componentGates.uiReward.texturePreviewCount) |") | Out-Null
    $lines.Add("| Prefabs with placeholders | $($Summary.componentGates.uiReward.prefabWithPlaceholderCount) |") | Out-Null
    $lines.Add("| Prefab static risk | $($Summary.componentGates.uiReward.prefabStaticRiskStatus) |") | Out-Null
    $lines.Add("| High-risk UI prefabs | $($Summary.componentGates.uiReward.highRiskPrefabCount) |") | Out-Null
    $lines.Add("| Visual-missing drop prefabs | $($Summary.componentGates.uiReward.visualMissingPrefabCount) |") | Out-Null
    $lines.Add("| Rebuild build gate | $($Summary.componentGates.uiReward.prototypeBuildGateStatus) |") | Out-Null
    $lines.Add("| Texture rebuild plan | $($Summary.componentGates.uiReward.prototypeRebuildPlanStatus) |") | Out-Null
    $lines.Add("| Rebuild-plan accepted textures | $($Summary.componentGates.uiReward.prototypeRebuildAcceptedTextureCount) |") | Out-Null
    $lines.Add("| Can stage rebuild textures | $($Summary.componentGates.uiReward.prototypeRebuildCanStageSourceTextures) |") | Out-Null
    $lines.Add("| Rebuild textures staged | $($Summary.componentGates.uiReward.prototypeTextureSourceStaged) |") | Out-Null
    $lines.Add("| Rebuild builder compile | $($Summary.componentGates.uiReward.prototypeBuilderCompileStatus) |") | Out-Null
    $lines.Add("| Review TSV | $($Summary.componentGates.uiReward.visualReviewTsv) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Environment Material Review Pack') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.environment.materialReviewPackStatus) |") | Out-Null
    $lines.Add("| Texture previews | $($Summary.componentGates.environment.materialTexturePreviewCount) |") | Out-Null
    $lines.Add("| Unbound materials | $($Summary.componentGates.environment.unboundMaterialCount) |") | Out-Null
    $lines.Add("| Review TSV | $($Summary.componentGates.environment.materialReviewTsv) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Offline Manual Review Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.componentGates.offlineManualReview.gateStatus) |") | Out-Null
    $lines.Add("| Total rows | $($Summary.componentGates.offlineManualReview.totalRowCount) |") | Out-Null
    $lines.Add("| Reviewed rows | $($Summary.componentGates.offlineManualReview.reviewedRowCount) |") | Out-Null
    $lines.Add("| Not reviewed rows | $($Summary.componentGates.offlineManualReview.notReviewedRowCount) |") | Out-Null
    $lines.Add("| Accepted rows | $($Summary.componentGates.offlineManualReview.acceptedRowCount) |") | Out-Null
    $lines.Add("| Rejected rows | $($Summary.componentGates.offlineManualReview.rejectedRowCount) |") | Out-Null
    $lines.Add("| Report | $($Summary.componentGates.offlineManualReview.reportPath) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Component Gates') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Gate | Status | Accepted |') | Out-Null
    $lines.Add('| --- | --- | --- |') | Out-Null
    $lines.Add("| Environment module | $($Summary.componentGates.environment.gateStatus) | $($Summary.componentGates.environment.canAcceptEnvironmentModule) |") | Out-Null
    $lines.Add("| Controlled import candidates | $($Summary.componentGates.controlledImportCandidates.gateStatus) | $($Summary.componentGates.controlledImportCandidates.canClearCandidateBlockingStatus) |") | Out-Null
    $lines.Add("| Actor prototype controllers | $($Summary.componentGates.actorPrototypeControllers.gateStatus) | $($Summary.componentGates.actorPrototypeControllers.canAcceptActorPrototypeControllers) |") | Out-Null
    $lines.Add("| UI/reward | $($Summary.componentGates.uiReward.gateStatus) | $($Summary.componentGates.uiReward.canSatisfyMinimumUiRewardArt) |") | Out-Null
    $lines.Add("| Audio | $($Summary.componentGates.audio.gateStatus) | $($Summary.componentGates.audio.canSatisfyMinimumAudio) |") | Out-Null
    $lines.Add("| Unity focused validation readiness | $($Summary.componentGates.unityFocusedValidationReadiness.gateStatus) | $($Summary.componentGates.unityFocusedValidationReadiness.canRunUnityFocusedValidation) |") | Out-Null
    $lines.Add("| Offline manual review | $($Summary.componentGates.offlineManualReview.gateStatus) | $($Summary.componentGates.offlineManualReview.canSatisfyDevelopmentUsability) |") | Out-Null
    $lines.Add("| Minimum vertical slice | $($Summary.componentGates.minimumVerticalSlice.readinessStatus) | $($Summary.componentGates.minimumVerticalSlice.canStartGameplayMainline) |") | Out-Null
    $lines.Add("| Asset acceptance | $($Summary.componentGates.assetAcceptance.rootGateStatus) | $($Summary.componentGates.assetAcceptance.canProceedGameplayMainline) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Lane Triage') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Lane | Gate status | Decision | Accepted | Direct summary |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- |') | Out-Null
    foreach ($laneProperty in @($Summary.laneTriage.lanes.PSObject.Properties)) {
        $lane = $laneProperty.Value
        $lines.Add("| $($lane.name) | $($lane.gateStatus) | $($lane.decision) | $($lane.accepted) | $($lane.directGateSummary) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Actor Builder Preflight') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Compile status | $($Summary.componentGates.actorPrototypeControllers.compilePreflightStatus) |") | Out-Null
    $lines.Add("| Compile warnings | $($Summary.componentGates.actorPrototypeControllers.compilePreflightWarningCount) |") | Out-Null
    $lines.Add("| Compile errors | $($Summary.componentGates.actorPrototypeControllers.compilePreflightErrorCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    $lines.Add('') | Out-Null
    if ($Summary.issues.Count -eq 0) {
        $lines.Add('None.') | Out-Null
    } else {
        foreach ($issue in $Summary.issues) {
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
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\OriginalAssetReuseGate'
}

$ValidationRoot = Get-CanonicalPath $ValidationRoot
Assert-PathUnderOrEqual -Path $ValidationRoot -Root $extractedRoot -Label 'ValidationRoot'
New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null

$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = [string]$toolManifest.sourceInstall

$issues = [System.Collections.Generic.List[string]]::new()
$sourceSafety = [PSCustomObject]@{
    sourceInstall = $sourceInstall
    sourceExists = (Test-Path -LiteralPath $sourceInstall -PathType Container)
    extractedExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Extracted'))
    assetsExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Assets'))
    toolsExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Tools'))
}
Add-IssueIf -Issues $issues -Condition (-not [bool]$sourceSafety.sourceExists) -Message "Source install is not accessible: $sourceInstall"
Add-IssueIf -Issues $issues -Condition ([bool]$sourceSafety.extractedExists) -Message 'Source install contains generated Extracted directory.'
Add-IssueIf -Issues $issues -Condition ([bool]$sourceSafety.assetsExists) -Message 'Source install contains generated Assets directory.'
Add-IssueIf -Issues $issues -Condition ([bool]$sourceSafety.toolsExists) -Message 'Source install contains generated Tools directory.'

$unityScriptCompilePreflight = & (Join-Path $PSScriptRoot 'Test-UnityEditorScriptCompilePreflight.ps1') -AllStellaGaiaScripts -NoThrow
Add-IssueIf -Issues $issues -Condition ([string]$unityScriptCompilePreflight.status -eq 'CompileFailed') -Message 'Unity-side validation scripts failed offline compile preflight.'
Add-IssueIf -Issues $issues -Condition ([string]$unityScriptCompilePreflight.status -eq 'PreflightInputFailed') -Message 'Unity-side validation script compile preflight inputs are missing.'

$assetAcquisition = & (Join-Path $PSScriptRoot 'Test-AssetAcquisitionGate.ps1')
Add-IssueIf -Issues $issues -Condition ([int]$assetAcquisition.issueCount -gt 0) -Message 'Asset acquisition gate has evidence or policy issues.'
Add-IssueIf -Issues $issues -Condition (-not [bool]$assetAcquisition.canSupportUnityImportTriage) -Message 'Asset acquisition gate cannot support Unity import triage.'
Add-IssueIf -Issues $issues -Condition ([bool]$assetAcquisition.canGrantDevelopmentUsability) -Message 'Asset acquisition gate must not grant DevelopmentUsable status.'

$environmentArgs = @{}
$controlledImportCandidateArgs = @{}
$actorPrototypeArgs = @{}
$uiArgs = @{}
$audioArgs = @{}
if ($RunUnity) {
    $environmentArgs.RunUnity = $true
    $controlledImportCandidateArgs.RunUnity = $true
    $actorPrototypeArgs.RunUnity = $true
    $uiArgs.RunUnity = $true
    $audioArgs.RunUnity = $true
}
$environmentArgs.FidelityReview = $EnvironmentFidelityReview
$uiArgs.FidelityReview = $UiFidelityReview
$audioArgs.ListeningReview = $AudioListeningReview

$environmentGate = & (Join-Path $PSScriptRoot 'Test-EnvironmentModuleReuseGate.ps1') @environmentArgs
$controlledImportCandidates = & (Join-Path $PSScriptRoot 'Test-ControlledImportCandidateGate.ps1') @controlledImportCandidateArgs
$actorPrototypeControllers = & (Join-Path $PSScriptRoot 'Test-ActorPrototypeControllerRebuildGate.ps1') @actorPrototypeArgs
$uiRewardGate = & (Join-Path $PSScriptRoot 'Test-UiRewardReuseGate.ps1') @uiArgs
$audioGate = & (Join-Path $PSScriptRoot 'Test-AudioReuseGate.ps1') @audioArgs
$offlineManualReview = & (Join-Path $PSScriptRoot 'Test-OfflineManualReviewGate.ps1')
$minimumVerticalSlice = & (Join-Path $PSScriptRoot 'Test-MinimumVerticalSliceAssets.ps1')
$assetAcceptance = & (Join-Path $PSScriptRoot 'Test-AssetAcceptanceManifest.ps1')
$unityFocusedValidationReadiness = $null
$unityFocusedValidationReadinessError = ''
try {
    $unityFocusedValidationReadiness = & (Join-Path $PSScriptRoot 'Test-UnityFocusedValidationReadiness.ps1')
} catch {
    $unityFocusedValidationReadinessError = $_.Exception.Message
    $readinessSummaryPath = Join-Path $extractedRoot 'Validation\UnityFocusedValidationReadiness\unity-focused-validation-readiness-summary.json'
    $unityFocusedValidationReadiness = Read-JsonFile -Path $readinessSummaryPath
}

Add-IssueIf -Issues $issues -Condition ([int]$environmentGate.staticIssueCount -gt 0) -Message 'Environment module static gate has issues.'
Add-IssueIf -Issues $issues -Condition ([int]$controlledImportCandidates.staticIssueCount -gt 0) -Message 'Controlled import candidate static gate has issues.'
Add-IssueIf -Issues $issues -Condition ([int]$actorPrototypeControllers.issueCount -gt 0) -Message 'Actor prototype controller rebuild gate has issues.'
Add-IssueIf -Issues $issues -Condition ([int]$uiRewardGate.staticIssueCount -gt 0) -Message 'UI/reward static gate has issues.'
Add-IssueIf -Issues $issues -Condition ([int]$audioGate.staticIssueCount -gt 0) -Message 'Audio static gate has issues.'
Add-IssueIf -Issues $issues -Condition ([int]$offlineManualReview.issueCount -gt 0) -Message 'Offline manual review gate has input issues.'
Add-IssueIf -Issues $issues -Condition ([int]$minimumVerticalSlice.IssueCount -gt 0) -Message 'Minimum vertical slice manifest has validation issues.'
Add-IssueIf -Issues $issues -Condition ([int]$assetAcceptance.IssueCount -gt 0) -Message 'Asset acceptance manifest has validation issues.'
Add-IssueIf -Issues $issues -Condition ($null -eq $unityFocusedValidationReadiness) -Message 'Unity focused validation readiness gate did not produce a readable summary.'
Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($unityFocusedValidationReadinessError)) -Message "Unity focused validation readiness gate failed: $unityFocusedValidationReadinessError"
Add-IssueIf -Issues $issues -Condition ($null -ne $unityFocusedValidationReadiness -and [int]$unityFocusedValidationReadiness.issueCount -gt 0) -Message 'Unity focused validation readiness gate has offline prerequisite issues.'

$unityBlocked = @($environmentGate.gateStatus, $controlledImportCandidates.gateStatus, $actorPrototypeControllers.gateStatus, $uiRewardGate.gateStatus, $audioGate.gateStatus) -contains 'BlockedUnityLicense'
$allAccepted = [bool]$environmentGate.canAcceptEnvironmentModule -and [bool]$controlledImportCandidates.canClearCandidateBlockingStatus -and [bool]$actorPrototypeControllers.canAcceptActorPrototypeControllers -and [bool]$uiRewardGate.canSatisfyMinimumUiRewardArt -and [bool]$audioGate.canSatisfyMinimumAudio
$manifestAllowsGameplay = [bool]$minimumVerticalSlice.CanStartGameplayMainline -and [bool]$assetAcceptance.CanProceedGameplayMainline
$canStartGameplayMainline = $allAccepted -and $manifestAllowsGameplay -and $issues.Count -eq 0

$gateStatus = 'NotPassed'
$nextRequiredAction = 'Run the focused Unity gates and only proceed if they pass with recognizable/confirmed asset reuse.'
if ($issues.Count -gt 0) {
    $gateStatus = 'StaticFailed'
    $nextRequiredAction = 'Fix source safety or static gate issues before Unity validation.'
} elseif ($unityBlocked) {
    $gateStatus = 'BlockedUnityLicense'
    $nextRequiredAction = 'Activate the Unity editor license, then rerun `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity`.'
} elseif ($canStartGameplayMainline) {
    $gateStatus = 'Passed'
    $nextRequiredAction = 'Gameplay mainline may start under controlled vertical-slice import rules.'
} elseif (-not $RunUnity) {
    $gateStatus = 'StaticReadyNeedsUnityFocusedValidation'
    $nextRequiredAction = 'Run `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity` after Unity licensing is active; then confirm actor sampled-animation screenshots, environment/UI fidelity, and audio semantics.'
} else {
    $gateStatus = 'UnityFocusedValidationIncomplete'
    $nextRequiredAction = 'Inspect child gate reports, fix or reject failing actor, environment, UI, or audio categories, and keep gameplay mainline blocked until all required gates pass.'
}

$summaryJson = Join-Path $ValidationRoot 'original-asset-reuse-gate-summary.json'
$reportPath = Join-Path $ValidationRoot 'original-asset-reuse-gate-report.md'
$gateInterpretation = [PSCustomObject]@{
    assetAcquisitionFeasibility = if ([bool]$assetAcquisition.canSupportUnityImportTriage) { 'HighForLocateExtractDecodeAndCrossCheck' } else { 'InsufficientEvidence' }
    assetReuseFeasibility = if ($canStartGameplayMainline) { 'DevelopmentUsableMinimumSlice' } elseif ($RunUnity) { 'UnityFocusedTriageIncomplete' } else { 'NeedsUnityFocusedTriage' }
    canMakeGameplayGoDecision = [bool]($RunUnity -and $canStartGameplayMainline)
    requiresUnityFocusedTriage = [bool](-not $RunUnity -and -not $canStartGameplayMainline)
    unityRunIsTriageOnlyUntilManifestsRerun = [bool]($RunUnity -and -not $canStartGameplayMainline)
    notOriginalProjectRestoration = $true
    interpretation = 'Asset acquisition evidence supports locating, extracting, decoding, and preparing StellaSora media. Original asset reuse remains blocked until Unity visible/audible gates and post-Unity manifests agree.'
}
$postUnityManifestRerunPolicy = [PSCustomObject]@{
    requiredAfterRunUnity = $true
    minimumVerticalSliceManifest = 'docs\asset-migration\minimum-vertical-slice-assets.json'
    assetAcceptanceManifest = 'docs\asset-migration\asset-acceptance-manifest.json'
    requiredCommands = @(
        'Tools\AssetImport\Test-MinimumVerticalSliceAssets.ps1',
        'Tools\AssetImport\Test-AssetAcceptanceManifest.ps1',
        'Tools\AssetImport\Test-OriginalAssetReuseGate.ps1'
    )
    canStartGameplayMainlineOnlyFromRerunRootGate = $true
    rationale = 'A Unity run is a triage input until child gate evidence is reflected in both manifests and the root gate is rerun.'
}
$laneTriage = [PSCustomObject]@{
    decisionVocabulary = @('UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'Stop')
    lanes = [PSCustomObject]@{
        environment = New-LaneSummary `
            -Name 'environment' `
            -GateStatus ([string]$environmentGate.gateStatus) `
            -Accepted ([bool]$environmentGate.canAcceptEnvironmentModule) `
            -DirectGateSummary ([string]$environmentGate.summaryJson) `
            -DirectGateReport ([string]$environmentGate.reportPath) `
            -NextAllowedAction ([string]$environmentGate.nextRequiredAction) `
            -Unity $environmentGate.unity
        controlledImportCandidates = New-LaneSummary `
            -Name 'controlledImportCandidates' `
            -GateStatus ([string]$controlledImportCandidates.gateStatus) `
            -Accepted ([bool]$controlledImportCandidates.canClearCandidateBlockingStatus) `
            -DirectGateSummary ([string]$controlledImportCandidates.summaryJson) `
            -DirectGateReport ([string]$controlledImportCandidates.reportPath) `
            -NextAllowedAction ([string]$controlledImportCandidates.nextRequiredAction) `
            -Unity $controlledImportCandidates.unity
        actorPrototypeControllers = New-LaneSummary `
            -Name 'actorPrototypeControllers' `
            -GateStatus ([string]$actorPrototypeControllers.gateStatus) `
            -Accepted ([bool]$actorPrototypeControllers.canAcceptActorPrototypeControllers) `
            -DirectGateSummary ([string]$actorPrototypeControllers.summaryJson) `
            -DirectGateReport ([string]$actorPrototypeControllers.reportPath) `
            -NextAllowedAction ([string]$actorPrototypeControllers.nextRequiredAction) `
            -Unity $actorPrototypeControllers.unity
        uiReward = New-LaneSummary `
            -Name 'uiReward' `
            -GateStatus ([string]$uiRewardGate.gateStatus) `
            -Accepted ([bool]$uiRewardGate.canSatisfyMinimumUiRewardArt) `
            -DirectGateSummary ([string]$uiRewardGate.summaryJson) `
            -DirectGateReport ([string]$uiRewardGate.reportPath) `
            -NextAllowedAction ([string]$uiRewardGate.nextRequiredAction) `
            -Unity $uiRewardGate.unity
        audio = New-LaneSummary `
            -Name 'audio' `
            -GateStatus ([string]$audioGate.gateStatus) `
            -Accepted ([bool]$audioGate.canSatisfyMinimumAudio) `
            -DirectGateSummary ([string]$audioGate.summaryJson) `
            -DirectGateReport ([string]$audioGate.reportPath) `
            -NextAllowedAction ([string]$audioGate.nextRequiredAction) `
            -Unity $audioGate.unity
    }
}

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    runUnity = [bool]$RunUnity
    gateStatus = $gateStatus
    summaryJson = $summaryJson
    reportPath = $reportPath
    canStartGameplayMainline = $canStartGameplayMainline
    gateInterpretation = $gateInterpretation
    postUnityManifestRerunPolicy = $postUnityManifestRerunPolicy
    laneTriage = $laneTriage
    issueCount = $issues.Count
    issues = @($issues)
    sourceSafety = $sourceSafety
    unityScriptCompilePreflight = [PSCustomObject]@{
        status = [string]$unityScriptCompilePreflight.status
        allStellaGaiaScripts = [bool]$unityScriptCompilePreflight.allStellaGaiaScripts
        scriptCount = [int]$unityScriptCompilePreflight.scriptCount
        warningCount = [int]$unityScriptCompilePreflight.warningCount
        errorCount = [int]$unityScriptCompilePreflight.errorCount
        issueCount = [int]$unityScriptCompilePreflight.issueCount
        outputText = [string]$unityScriptCompilePreflight.outputText
        summaryJson = [string]$unityScriptCompilePreflight.summaryJson
        interpretation = [string]$unityScriptCompilePreflight.interpretation
    }
    componentGates = [PSCustomObject]@{
        assetAcquisition = [PSCustomObject]@{
            gateStatus = [string]$assetAcquisition.gateStatus
            canSupportUnityImportTriage = [bool]$assetAcquisition.canSupportUnityImportTriage
            canGrantDevelopmentUsability = [bool]$assetAcquisition.canGrantDevelopmentUsability
            requiredGroupCount = [int]$assetAcquisition.requiredGroupCount
            missingEvidenceCount = [int]$assetAcquisition.missingEvidenceCount
            issueCount = [int]$assetAcquisition.issueCount
            summaryJson = [string]$assetAcquisition.summaryJson
            reportPath = [string]$assetAcquisition.reportPath
            interpretation = [string]$assetAcquisition.interpretation
        }
        environment = [PSCustomObject]@{
            gateStatus = [string]$environmentGate.gateStatus
            canAcceptEnvironmentModule = [bool]$environmentGate.canAcceptEnvironmentModule
            materialReviewPackStatus = [string]$environmentGate.materialReviewPack.status
            materialTexturePreviewCount = [int]$environmentGate.materialReviewPack.texturePreviewCount
            unboundMaterialCount = [int]$environmentGate.materialReviewPack.unboundMaterialCount
            manualBoundMaterialCount = [int]$environmentGate.materialReviewPack.manualBoundMaterialCount
            materialReviewIndexHtml = [string]$environmentGate.materialReviewPack.indexHtml
            materialReviewTsv = [string]$environmentGate.materialReviewPack.materialReviewTsv
            nextRequiredAction = [string]$environmentGate.nextRequiredAction
        }
        controlledImportCandidates = [PSCustomObject]@{
            gateStatus = [string]$controlledImportCandidates.gateStatus
            candidateCount = [int]$controlledImportCandidates.candidateCount
            staticReadyCount = [int]$controlledImportCandidates.staticReadyCount
            canClearCandidateBlockingStatus = [bool]$controlledImportCandidates.canClearCandidateBlockingStatus
            nextRequiredAction = [string]$controlledImportCandidates.nextRequiredAction
        }
        actorPrototypeControllers = [PSCustomObject]@{
            gateStatus = [string]$actorPrototypeControllers.gateStatus
            candidateCount = [int]$actorPrototypeControllers.candidateCount
            sourceStaged = [bool]$actorPrototypeControllers.sourceStaged
            canAcceptActorPrototypeControllers = [bool]$actorPrototypeControllers.canAcceptActorPrototypeControllers
            compilePreflightStatus = [string]$actorPrototypeControllers.compilePreflight.status
            compilePreflightWarningCount = [int]$actorPrototypeControllers.compilePreflight.warningCount
            compilePreflightErrorCount = [int]$actorPrototypeControllers.compilePreflight.errorCount
            compilePreflightSummary = [string]$actorPrototypeControllers.compilePreflight.summaryJson
            compilePreflightOutput = [string]$actorPrototypeControllers.compilePreflight.outputText
            unityStatus = [string]$actorPrototypeControllers.unity.status
            visibleScreenshotCount = [int]$actorPrototypeControllers.unity.visibleScreenshotCount
            nextRequiredAction = [string]$actorPrototypeControllers.nextRequiredAction
        }
        uiReward = [PSCustomObject]@{
            gateStatus = [string]$uiRewardGate.gateStatus
            canSatisfyMinimumUiRewardArt = [bool]$uiRewardGate.canSatisfyMinimumUiRewardArt
            visualReviewPackStatus = [string]$uiRewardGate.visualReviewPack.status
            texturePreviewCount = [int]$uiRewardGate.visualReviewPack.texturePreviewCount
            prefabWithPlaceholderCount = [int]$uiRewardGate.visualReviewPack.prefabWithPlaceholderCount
            prefabStaticRiskStatus = [string]$uiRewardGate.prefabStaticRisk.gateStatus
            highRiskPrefabCount = [int]$uiRewardGate.prefabStaticRisk.highRiskPrefabCount
            visualMissingPrefabCount = [int]$uiRewardGate.prefabStaticRisk.visualMissingPrefabCount
            prefabStaticRiskReport = [string]$uiRewardGate.prefabStaticRisk.reportPath
            visualReviewIndexHtml = [string]$uiRewardGate.visualReviewPack.indexHtml
            visualReviewTsv = [string]$uiRewardGate.visualReviewPack.visualReviewTsv
            prototypeBuildGateStatus = [string]$uiRewardGate.prototypeBuildGate.gateStatus
            prototypeBuildGateCanAccept = [bool]$uiRewardGate.prototypeBuildGate.canAcceptUiRewardPrototype
            prototypeBuildGateSummary = [string]$uiRewardGate.prototypeBuildGate.summaryJson
            prototypeBuildGateReport = [string]$uiRewardGate.prototypeBuildGate.reportPath
            prototypeRebuildPlanStatus = [string]$uiRewardGate.prototypeRebuildPlan.status
            prototypeRebuildAcceptedTextureCount = [int]$uiRewardGate.prototypeRebuildPlan.acceptedTextureCount
            prototypeRebuildCanStageSourceTextures = [bool]$uiRewardGate.prototypeRebuildPlan.canStageSourceTextures
            prototypeRebuildReport = [string]$uiRewardGate.prototypeRebuildPlan.reportPath
            prototypeTextureStagingStatus = [string]$uiRewardGate.prototypeTextureStaging.status
            prototypeTextureSourceStaged = [bool]$uiRewardGate.prototypeTextureStaging.sourceTexturesStaged
            prototypeTextureStagedFileCount = [int]$uiRewardGate.prototypeTextureStaging.existingTargetFileCount
            prototypeTextureStagedMetaCount = [int]$uiRewardGate.prototypeTextureStaging.existingTargetMetaCount
            prototypeTextureStagingReport = [string]$uiRewardGate.prototypeTextureStaging.reportPath
            prototypeBuilderCompileStatus = [string]$uiRewardGate.prototypeBuilderPreflight.status
            prototypeBuilderCompileWarningCount = [int]$uiRewardGate.prototypeBuilderPreflight.warningCount
            prototypeBuilderCompileErrorCount = [int]$uiRewardGate.prototypeBuilderPreflight.errorCount
            prototypeBuilderCompileSummary = [string]$uiRewardGate.prototypeBuilderPreflight.summaryJson
            nextRequiredAction = [string]$uiRewardGate.nextRequiredAction
        }
        audio = [PSCustomObject]@{
            gateStatus = [string]$audioGate.gateStatus
            canSatisfyMinimumAudio = [bool]$audioGate.canSatisfyMinimumAudio
            auditionPackStatus = [string]$audioGate.auditionPack.status
            auditionPreviewCount = [int]$audioGate.auditionPack.previewCount
            auditionWaveformCount = [int]$audioGate.auditionPack.waveformCount
            auditionIndexHtml = [string]$audioGate.auditionPack.indexHtml
            auditionReviewTsv = [string]$audioGate.auditionPack.listeningReviewTsv
            nextRequiredAction = [string]$audioGate.nextRequiredAction
        }
        unityFocusedValidationReadiness = [PSCustomObject]@{
            gateStatus = if ($null -ne $unityFocusedValidationReadiness) { [string]$unityFocusedValidationReadiness.gateStatus } else { 'Missing' }
            canRunUnityFocusedValidation = if ($null -ne $unityFocusedValidationReadiness) { [bool]$unityFocusedValidationReadiness.canRunUnityFocusedValidation } else { $false }
            issueCount = if ($null -ne $unityFocusedValidationReadiness) { [int]$unityFocusedValidationReadiness.issueCount } else { 1 }
            warningCount = if ($null -ne $unityFocusedValidationReadiness) { [int]$unityFocusedValidationReadiness.warningCount } else { 0 }
            actorReady = if ($null -ne $unityFocusedValidationReadiness) { [bool]$unityFocusedValidationReadiness.components.actorPrototypeControllers.ready } else { $false }
            environmentReady = if ($null -ne $unityFocusedValidationReadiness) { [bool]$unityFocusedValidationReadiness.components.environmentModule.ready } else { $false }
            uiRewardReady = if ($null -ne $unityFocusedValidationReadiness) { [bool]$unityFocusedValidationReadiness.components.uiReward.ready } else { $false }
            audioReady = if ($null -ne $unityFocusedValidationReadiness) { [bool]$unityFocusedValidationReadiness.components.audio.ready } else { $false }
            summaryJson = if ($null -ne $unityFocusedValidationReadiness) { [string]$unityFocusedValidationReadiness.summaryJson } else { '' }
            reportPath = if ($null -ne $unityFocusedValidationReadiness) { [string]$unityFocusedValidationReadiness.reportPath } else { '' }
            nextRequiredAction = if ($null -ne $unityFocusedValidationReadiness) { [string]$unityFocusedValidationReadiness.nextRequiredAction } else { 'Run Tools\AssetImport\Test-UnityFocusedValidationReadiness.ps1 and fix any offline prerequisite errors.' }
        }
        offlineManualReview = [PSCustomObject]@{
            gateStatus = [string]$offlineManualReview.gateStatus
            totalRowCount = [int]$offlineManualReview.totalRowCount
            reviewedRowCount = [int]$offlineManualReview.reviewedRowCount
            notReviewedRowCount = [int]$offlineManualReview.notReviewedRowCount
            acceptedRowCount = [int]$offlineManualReview.acceptedRowCount
            rejectedRowCount = [int]$offlineManualReview.rejectedRowCount
            issueCount = [int]$offlineManualReview.issueCount
            canSatisfyDevelopmentUsability = [bool]$offlineManualReview.canSatisfyDevelopmentUsability
            summaryJson = [string]$offlineManualReview.summaryJson
            reportPath = [string]$offlineManualReview.reportPath
            nextRequiredAction = [string]$offlineManualReview.nextRequiredAction
        }
        minimumVerticalSlice = [PSCustomObject]@{
            readinessStatus = [string]$minimumVerticalSlice.ReadinessStatus
            canStartGameplayMainline = [bool]$minimumVerticalSlice.CanStartGameplayMainline
            blockingRequirementCount = [int]$minimumVerticalSlice.BlockingRequirementCount
            blockingRequirements = @($minimumVerticalSlice.BlockingRequirements)
            uiRewardPrototypeBuildGateStatus = [string]$minimumVerticalSlice.UiRewardPrototypeBuildGateStatus
            uiRewardPrototypeBuildGateCanAccept = [bool]$minimumVerticalSlice.UiRewardPrototypeBuildGateCanAccept
            environmentModuleGateStatus = [string]$minimumVerticalSlice.EnvironmentModuleGateStatus
            environmentModuleGateCanAccept = [bool]$minimumVerticalSlice.EnvironmentModuleGateCanAccept
            audioReuseGateStatus = [string]$minimumVerticalSlice.AudioReuseGateStatus
            audioReuseGateCanSatisfy = [bool]$minimumVerticalSlice.AudioReuseGateCanSatisfy
        }
        assetAcceptance = [PSCustomObject]@{
            rootGateStatus = [string]$assetAcceptance.RootGateStatus
            canProceedGameplayMainline = [bool]$assetAcceptance.CanProceedGameplayMainline
        }
    }
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Original asset reuse gate failed static validation with $($issues.Count) issue(s)."
}
