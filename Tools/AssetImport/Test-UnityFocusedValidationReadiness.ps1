[CmdletBinding()]
param(
    [string]$ValidationRoot
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

function Add-WarningIf {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Warnings,
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        $Warnings.Add($Message) | Out-Null
    }
}

function Write-ReadinessReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Unity Focused Validation Readiness') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('This report does not run Unity and does not accept any asset as development-usable. It only checks whether the focused Unity validation run has all known offline prerequisites staged.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Can run focused Unity validation | $($Summary.canRunUnityFocusedValidation) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add("| Warning count | $($Summary.warningCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Component Gates') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Component | Status | Ready |') | Out-Null
    $lines.Add('| --- | --- | --- |') | Out-Null
    $lines.Add("| Unity scripts | $($Summary.components.unityScripts.status) | $($Summary.components.unityScripts.ready) |") | Out-Null
    $lines.Add("| Controlled import candidates | $($Summary.components.controlledImportCandidates.status) | $($Summary.components.controlledImportCandidates.ready) |") | Out-Null
    $lines.Add("| Actor prototype controllers | $($Summary.components.actorPrototypeControllers.status) | $($Summary.components.actorPrototypeControllers.ready) |") | Out-Null
    $lines.Add("| Environment module | $($Summary.components.environmentModule.status) | $($Summary.components.environmentModule.ready) |") | Out-Null
    $lines.Add("| UI/reward | $($Summary.components.uiReward.status) | $($Summary.components.uiReward.ready) |") | Out-Null
    $lines.Add("| Audio | $($Summary.components.audio.status) | $($Summary.components.audio.ready) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    if ($Summary.issues.Count -eq 0) {
        $lines.Add('') | Out-Null
        $lines.Add('- None.') | Out-Null
    } else {
        foreach ($issue in $Summary.issues) {
            $lines.Add("- $issue") | Out-Null
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add('## Warnings') | Out-Null
    if ($Summary.warnings.Count -eq 0) {
        $lines.Add('') | Out-Null
        $lines.Add('- None.') | Out-Null
    } else {
        foreach ($warning in $Summary.warnings) {
            $lines.Add("- $warning") | Out-Null
        }
    }

    $lines.Add('') | Out-Null
    $lines.Add("Next required action: $($Summary.nextRequiredAction)") | Out-Null
    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\UnityFocusedValidationReadiness'
}

$ValidationRoot = Get-CanonicalPath $ValidationRoot
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
[void][System.IO.Directory]::CreateDirectory($ValidationRoot)

$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest -and -not [string]::IsNullOrWhiteSpace([string]$toolManifest.sourceInstall)) {
    [string]$toolManifest.sourceInstall
} else {
    'C:\SoftGame\YostarGames\StellaSora_CN'
}
$sourceInstall = Get-CanonicalPath $sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

$unityScripts = & (Join-Path $PSScriptRoot 'Test-UnityEditorScriptCompilePreflight.ps1') -AllStellaGaiaScripts -NoThrow
$controlledImport = & (Join-Path $PSScriptRoot 'Test-ControlledImportCandidateGate.ps1')
$actorPrototype = & (Join-Path $PSScriptRoot 'Test-ActorPrototypeControllerRebuildGate.ps1')
$environment = & (Join-Path $PSScriptRoot 'Test-EnvironmentModuleReuseGate.ps1')
$uiReward = & (Join-Path $PSScriptRoot 'Test-UiRewardReuseGate.ps1')
$audio = & (Join-Path $PSScriptRoot 'Test-AudioReuseGate.ps1')
$offlineManualReview = & (Join-Path $PSScriptRoot 'Test-OfflineManualReviewGate.ps1')

$sourceSafety = [PSCustomObject]@{
    sourceInstall = $sourceInstall
    sourceExists = (Test-Path -LiteralPath $sourceInstall -PathType Container)
    extractedExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Extracted'))
    assetsExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Assets'))
    toolsExists = (Test-Path -LiteralPath (Join-Path $sourceInstall 'Tools'))
}

$unityScriptsReady = [string]$unityScripts.status -eq 'CompilePassed' -and [int]$unityScripts.errorCount -eq 0 -and [int]$unityScripts.issueCount -eq 0
$controlledReady = [string]$controlledImport.gateStatus -eq 'StaticReadyNeedsControlledProjectImport' -and [int]$controlledImport.staticIssueCount -eq 0
$actorReady = [string]$actorPrototype.gateStatus -eq 'SourceStagedNeedsUnityPrototypeBuild' -and [bool]$actorPrototype.sourceStaged -and [string]$actorPrototype.compilePreflight.status -eq 'CompilePassed' -and [int]$actorPrototype.issueCount -eq 0
$environmentReady = [string]$environment.gateStatus -eq 'StaticReadyNeedsUnityVisibleValidation' -and [int]$environment.staticIssueCount -eq 0 -and [int]$environment.materialReviewPack.issueCount -eq 0
$uiPrototypeReady = [string]$uiReward.prototypeBuildGate.gateStatus -eq 'StaticReadyNeedsUnityPrototypeBuild' -and [bool]$uiReward.prototypeBuildGate.sourceTexturesStaged -and [int]$uiReward.prototypeBuildGate.issueCount -eq 0
$uiRewardReady = ([string]$uiReward.gateStatus -in @('StaticReadyNeedsUnityVisibleValidation', 'StaticReadableWithPrefabDependencyRisksNeedsUnityVisibleValidation')) -and [int]$uiReward.staticIssueCount -eq 0 -and $uiPrototypeReady
$audioReady = [string]$audio.gateStatus -eq 'StaticReadyNeedsUnityPlaybackAndListening' -and [int]$audio.staticIssueCount -eq 0 -and [string]$audio.auditionPack.status -eq 'ReadyForManualListening'
$sourceSafe = [bool]$sourceSafety.sourceExists -and -not [bool]$sourceSafety.extractedExists -and -not [bool]$sourceSafety.assetsExists -and -not [bool]$sourceSafety.toolsExists

Add-IssueIf -Issues $issues -Condition (-not $unityScriptsReady) -Message 'Unity editor validation scripts are not compile-ready in offline preflight.'
Add-IssueIf -Issues $issues -Condition (-not $controlledReady) -Message 'Controlled import candidates are not static-ready for focused Unity validation.'
Add-IssueIf -Issues $issues -Condition (-not $actorReady) -Message 'Actor prototype controller route is not source-staged and compile-ready for focused Unity validation.'
Add-IssueIf -Issues $issues -Condition (-not $environmentReady) -Message 'Environment module route is not static-ready for Unity visible validation.'
Add-IssueIf -Issues $issues -Condition (-not $uiRewardReady) -Message 'UI/reward route is not staged and static-ready for Unity visible validation.'
Add-IssueIf -Issues $issues -Condition (-not $audioReady) -Message 'Audio route is not selected and static-ready for Unity playback/listening validation.'
Add-IssueIf -Issues $issues -Condition (-not $sourceSafe) -Message 'Source install safety check failed; generated directories exist under the source install or source install is unavailable.'

Add-WarningIf -Warnings $warnings -Condition ([int]$uiReward.prefabStaticRisk.highRiskPrefabCount -gt 0 -or [int]$uiReward.prefabStaticRisk.visualMissingPrefabCount -gt 0) -Message 'Selected original UI/reward prefabs retain known static prefab dependency risks; the staged texture rebuild route is the safer Unity validation path.'
Add-WarningIf -Warnings $warnings -Condition ([int]$offlineManualReview.notReviewedRowCount -gt 0) -Message "Offline manual review still has $($offlineManualReview.notReviewedRowCount) pending row(s); this does not block running Unity validation, but it still blocks development-usability acceptance."
Add-WarningIf -Warnings $warnings -Condition $true -Message 'Unity license state is intentionally not checked by this script. Run focused Unity validation only after the Unity editor license is active.'

$gateStatus = if ($issues.Count -eq 0) { 'ReadyForUnityFocusedValidation' } else { 'NeedsOfflineRepairBeforeUnityFocusedValidation' }
$canRunUnityFocusedValidation = $issues.Count -eq 0
$nextRequiredAction = if ($canRunUnityFocusedValidation) {
    'After confirming the Unity editor license is active, run `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity` and inspect actor animation screenshots, environment/UI fidelity screenshots, and audio playback/listening evidence.'
} else {
    'Fix the listed offline readiness issues before attempting a focused Unity validation run.'
}

$summaryJson = Join-Path $ValidationRoot 'unity-focused-validation-readiness-summary.json'
$reportPath = Join-Path $ValidationRoot 'unity-focused-validation-readiness-report.md'
$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    validationRoot = $ValidationRoot
    gateStatus = $gateStatus
    canRunUnityFocusedValidation = $canRunUnityFocusedValidation
    summaryJson = $summaryJson
    reportPath = $reportPath
    sourceSafety = $sourceSafety
    components = [PSCustomObject]@{
        unityScripts = [PSCustomObject]@{
            ready = $unityScriptsReady
            status = [string]$unityScripts.status
            scriptCount = [int]$unityScripts.scriptCount
            warningCount = [int]$unityScripts.warningCount
            errorCount = [int]$unityScripts.errorCount
            issueCount = [int]$unityScripts.issueCount
            summaryJson = [string]$unityScripts.summaryJson
        }
        controlledImportCandidates = [PSCustomObject]@{
            ready = $controlledReady
            status = [string]$controlledImport.gateStatus
            staticIssueCount = [int]$controlledImport.staticIssueCount
            candidateCount = [int]$controlledImport.candidateCount
            summaryJson = [string]$controlledImport.summaryJson
            reportPath = [string]$controlledImport.reportPath
        }
        actorPrototypeControllers = [PSCustomObject]@{
            ready = $actorReady
            status = [string]$actorPrototype.gateStatus
            sourceStaged = [bool]$actorPrototype.sourceStaged
            plannedAssetCount = [int]$actorPrototype.sourceCopy.plannedAssetCount
            existingTargetFileCount = [int]$actorPrototype.sourceCopy.existingTargetFileCount
            existingTargetMetaCount = [int]$actorPrototype.sourceCopy.existingTargetMetaCount
            compileStatus = [string]$actorPrototype.compilePreflight.status
            issueCount = [int]$actorPrototype.issueCount
            summaryJson = [string]$actorPrototype.summaryJson
            reportPath = [string]$actorPrototype.reportPath
        }
        environmentModule = [PSCustomObject]@{
            ready = $environmentReady
            status = [string]$environment.gateStatus
            staticIssueCount = [int]$environment.staticIssueCount
            materialIssueCount = [int]$environment.materialReviewPack.issueCount
            materialTexturePreviewCount = [int]$environment.materialReviewPack.texturePreviewCount
            summaryJson = [string]$environment.summaryJson
            reportPath = [string]$environment.reportPath
        }
        uiReward = [PSCustomObject]@{
            ready = $uiRewardReady
            status = [string]$uiReward.gateStatus
            staticIssueCount = [int]$uiReward.staticIssueCount
            staticWarningCount = [int]$uiReward.staticWarningCount
            prototypeBuildGateStatus = [string]$uiReward.prototypeBuildGate.gateStatus
            prototypeSourceTexturesStaged = [bool]$uiReward.prototypeBuildGate.sourceTexturesStaged
            prototypeIssueCount = [int]$uiReward.prototypeBuildGate.issueCount
            highRiskPrefabCount = [int]$uiReward.prefabStaticRisk.highRiskPrefabCount
            visualMissingPrefabCount = [int]$uiReward.prefabStaticRisk.visualMissingPrefabCount
            summaryJson = [string]$uiReward.summaryJson
            reportPath = [string]$uiReward.reportPath
            prototypeSummaryJson = [string]$uiReward.prototypeBuildGate.summaryJson
            prototypeReportPath = [string]$uiReward.prototypeBuildGate.reportPath
        }
        audio = [PSCustomObject]@{
            ready = $audioReady
            status = [string]$audio.gateStatus
            staticIssueCount = [int]$audio.staticIssueCount
            auditionPackStatus = [string]$audio.auditionPack.status
            previewCount = [int]$audio.auditionPack.previewCount
            waveformCount = [int]$audio.auditionPack.waveformCount
            summaryJson = [string]$audio.summaryJson
            reportPath = [string]$audio.reportPath
        }
        offlineManualReview = [PSCustomObject]@{
            status = [string]$offlineManualReview.gateStatus
            reviewedRowCount = [int]$offlineManualReview.reviewedRowCount
            notReviewedRowCount = [int]$offlineManualReview.notReviewedRowCount
            acceptedRowCount = [int]$offlineManualReview.acceptedRowCount
            rejectedRowCount = [int]$offlineManualReview.rejectedRowCount
            summaryJson = [string]$offlineManualReview.summaryJson
            reportPath = [string]$offlineManualReview.reportPath
        }
    }
    issueCount = $issues.Count
    issues = @($issues)
    warningCount = $warnings.Count
    warnings = @($warnings)
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-ReadinessReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Unity focused validation readiness failed with $($issues.Count) issue(s)."
}
