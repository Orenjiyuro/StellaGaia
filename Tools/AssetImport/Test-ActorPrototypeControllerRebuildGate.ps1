[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [string[]]$CandidateId = @('player_character', 'enemy'),
    [switch]$ApplySourceStaging,
    [switch]$RunUnity,
    [switch]$OverwriteGeneratedAssets
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
    $lines.Add('# Actor Prototype Controller Rebuild Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Apply source staging | $($Summary.applySourceStaging) |") | Out-Null
    $lines.Add("| Candidate count | $($Summary.candidateCount) |") | Out-Null
    $lines.Add("| Readiness ready count | $($Summary.readiness.staticReadyForPrototypeControllerRebuildCount) |") | Out-Null
    $lines.Add("| Planned source assets | $($Summary.plan.plannedSourceAssetCount) |") | Out-Null
    $lines.Add("| Source copy can apply | $($Summary.sourceCopy.canApply) |") | Out-Null
    $lines.Add("| Source staged | $($Summary.sourceStaged) |") | Out-Null
    $lines.Add("| Compile preflight | $($Summary.compilePreflight.status) |") | Out-Null
    $lines.Add("| Unity status | $($Summary.unity.status) |") | Out-Null
    $lines.Add("| Unity visible screenshots | $($Summary.unity.visibleScreenshotCount) |") | Out-Null
    $lines.Add("| Can accept actor prototype controllers | $($Summary.canAcceptActorPrototypeControllers) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
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
    $lines.Add('## Interpretation') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.interpretation) | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Next Required Action') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.nextRequiredAction) | Out-Null

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$assetsRoot = Get-CanonicalPath (Join-Path $repoRoot 'Assets')
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\ActorPrototypeControllerRebuildGate'
}

$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$gateOutput = Join-Path $ValidationRoot 'SelectedActors'

Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$toolManifest = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$toolManifest.sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'
[void][System.IO.Directory]::CreateDirectory($gateOutput)

$candidateFilter = @($CandidateId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$issues = [System.Collections.Generic.List[string]]::new()

$readinessArgs = @{}
if ($candidateFilter.Count -gt 0) {
    $readinessArgs.CandidateId = $candidateFilter
}
$readinessSummaryPath = Join-Path $extractedRoot 'Validation\ActorAnimationRebuildReadiness\actor-animation-rebuild-readiness-summary.json'
$readinessClipCsvPath = Join-Path $extractedRoot 'Validation\ActorAnimationRebuildReadiness\actor-animation-core-clips.csv'
& (Join-Path $PSScriptRoot 'Measure-ActorAnimationRebuildReadiness.ps1') @readinessArgs | Out-Null
$readiness = Read-JsonFile -Path $readinessSummaryPath
if ($null -eq $readiness) {
    throw "Missing actor animation rebuild readiness summary: $readinessSummaryPath"
}

$planArgs = @{}
if ($candidateFilter.Count -gt 0) {
    $planArgs.CandidateId = $candidateFilter
}
$planSummaryPath = Join-Path $extractedRoot 'Validation\ActorPrototypeControllerRebuildPlan\actor-prototype-controller-rebuild-plan-summary.json'
& (Join-Path $PSScriptRoot 'New-ActorPrototypeControllerRebuildPlan.ps1') @planArgs | Out-Null
$plan = Read-JsonFile -Path $planSummaryPath
if ($null -eq $plan) {
    throw "Missing actor prototype controller rebuild plan summary: $planSummaryPath"
}

$copyArgs = @{}
if ($candidateFilter.Count -gt 0) {
    $copyArgs.CandidateId = $candidateFilter
}
if ($ApplySourceStaging) {
    $copyArgs.Apply = $true
}
$sourceCopyOutputLeaf = 'actor-prototype-controller-source-assets-' + ($(if ($candidateFilter.Count -eq 0) { 'all' } else { $candidateFilter -join '_' }))
$sourceCopySummaryName = if ($ApplySourceStaging) { 'actor-prototype-controller-source-copy-apply-summary.json' } else { 'actor-prototype-controller-source-copy-summary.json' }
$sourceCopySummaryPath = Join-Path (Join-Path $extractedRoot "Validation\ActorPrototypeControllerSourceCopy\$sourceCopyOutputLeaf") $sourceCopySummaryName
& (Join-Path $PSScriptRoot 'Copy-ActorPrototypeControllerSourceAssets.ps1') @copyArgs | Out-Null
$sourceCopy = Read-JsonFile -Path $sourceCopySummaryPath
if ($null -eq $sourceCopy) {
    throw "Missing actor prototype controller source copy summary: $sourceCopySummaryPath"
}

$candidateCount = if ($candidateFilter.Count -gt 0) { $candidateFilter.Count } else { [int]$readiness.CandidateCount }
Add-IssueIf -Issues $issues -Condition ([int]$readiness.StaticReadyForPrototypeControllerRebuildCount -lt $candidateCount) -Message "Not all selected actors are static-ready for prototype controller rebuild."
Add-IssueIf -Issues $issues -Condition ([int]$readiness.NotReadyCount -gt 0) -Message "One or more selected actors are not ready for prototype controller rebuild."
Add-IssueIf -Issues $issues -Condition ([int]$plan.issueCount -gt 0) -Message "Actor prototype controller rebuild plan has issues."
Add-IssueIf -Issues $issues -Condition (-not [bool]$plan.canStageSourceAssets) -Message "Actor prototype controller source assets cannot be staged safely."
Add-IssueIf -Issues $issues -Condition ([int]$sourceCopy.issueCount -gt 0) -Message "Actor prototype controller source copy preflight has issues."
Add-IssueIf -Issues $issues -Condition (-not [bool]$sourceCopy.canApply) -Message "Actor prototype controller source copy cannot apply safely."

$compilePreflight = & (Join-Path $PSScriptRoot 'Test-UnityEditorScriptCompilePreflight.ps1') -ToolManifestPath $ToolManifestPath -EditorScriptPath @('Assets\StellaGaia\Editor\ActorPrototypeControllerBuilder.cs')
Add-IssueIf -Issues $issues -Condition ([string]$compilePreflight.status -eq 'CompileFailed') -Message 'Actor prototype controller Unity editor builder failed offline compile preflight.'
Add-IssueIf -Issues $issues -Condition ([string]$compilePreflight.status -eq 'PreflightInputFailed') -Message 'Actor prototype controller Unity editor builder compile preflight input is missing.'

$plannedAssetCount = [int]$sourceCopy.plannedAssetCount
$sourceStaged = ([int]$sourceCopy.appliedAssetCount -eq $plannedAssetCount -and $plannedAssetCount -gt 0) -or
    ([int]$sourceCopy.existingTargetFileCount -ge $plannedAssetCount -and [int]$sourceCopy.existingTargetMetaCount -ge $plannedAssetCount -and $plannedAssetCount -gt 0)

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

$unity = [ordered]@{
    status = if ($RunUnity) { 'Pending' } else { 'NotRun' }
    validationJson = Join-Path $gateOutput 'unity-actor-prototype-controller-build.json'
    validationText = Join-Path $gateOutput 'unity-actor-prototype-controller-build.txt'
    unityLog = Join-Path $gateOutput 'unity-actor-prototype-controller-build.log'
    specPath = [string]$plan.controllerSpecJson
    successfulActorCount = 0
    criticalIssueCount = 0
    createdControllerCount = 0
    createdPrefabCount = 0
    animationSampleCount = 0
    renderedScreenshotCount = 0
    visibleScreenshotCount = 0
    magentaScreenshotCount = 0
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity -and $issues.Count -eq 0) {
    if (-not $sourceStaged) {
        $unity.status = 'NeedsSourceStaging'
    } else {
        $unityEditor = Get-CanonicalPath ([string]$toolManifest.unityEditor)
        if (-not (Test-Path -LiteralPath $unityEditor -PathType Leaf)) {
            throw "Missing Unity editor: $unityEditor"
        }

        $startedAt = Get-Date
        $arguments = @(
            '-batchmode',
            '-quit',
            '-projectPath', $repoRoot,
            '-executeMethod', 'StellaGaia.EditorTools.ActorPrototypeControllerBuilder.Run',
            '-logFile', $unity.unityLog,
            '-stellaGaiaActorPrototypeControllerSpec', ([string]$plan.controllerSpecJson),
            '-stellaGaiaActorPrototypeControllerBuildOutput', $gateOutput,
            '-stellaGaiaActorPrototypeControllerOverwrite', ($(if ($OverwriteGeneratedAssets) { 'true' } else { 'false' }))
        )

        $process = Start-Process -FilePath $unityEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
            $unity.licenseBlocked = [bool](Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet)
        }

        $unityReport = Read-JsonFile -Path $unity.validationJson
        if ($null -ne $unityReport) {
            $validationInfo = Get-Item -LiteralPath $unity.validationJson
            $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
            $unity.successfulActorCount = [int]$unityReport.successfulActorCount
            $unity.criticalIssueCount = [int]$unityReport.criticalIssueCount
            $unity.createdControllerCount = [int]$unityReport.createdControllerCount
            $unity.createdPrefabCount = [int]$unityReport.createdPrefabCount
            $unity.animationSampleCount = [int]$unityReport.animationSampleCount
            $unity.renderedScreenshotCount = [int]$unityReport.renderedScreenshotCount
            $unity.visibleScreenshotCount = [int]$unityReport.visibleScreenshotCount
            $unity.magentaScreenshotCount = [int]$unityReport.magentaScreenshotCount
        }

        if ($unity.licenseBlocked) {
            $unity.status = 'BlockedUnityLicense'
        } elseif ($process.ExitCode -ne 0 -and -not $unity.freshValidation) {
            $unity.status = 'UnityBuildFailed'
        } elseif (-not $unity.freshValidation) {
            $unity.status = 'MissingFreshUnityBuildReport'
        } elseif ([int]$unity.criticalIssueCount -gt 0) {
            $unity.status = 'PrototypeControllerBuiltWithIssues'
        } elseif ([int]$unity.successfulActorCount -eq $candidateCount) {
            $unity.status = 'PrototypeControllerBuildPassed'
        } else {
            $unity.status = 'PrototypeControllerBuildIncomplete'
        }
    }
}

$canAcceptActorPrototypeControllers = $RunUnity -and [string]$unity.status -eq 'PrototypeControllerBuildPassed' -and $issues.Count -eq 0
$gateStatus = 'StaticFailed'
$nextRequiredAction = 'Fix actor rebuild static readiness, staging plan, or source safety issues.'
$interpretation = 'Actor prototype controller rebuild is a repair/downgrade route using original exported clips and Avatars; it is not recovery of the original Animator Override Controller.'

if ($issues.Count -eq 0) {
    if ($RunUnity -and [string]$unity.status -eq 'BlockedUnityLicense') {
        $gateStatus = 'BlockedUnityLicense'
        $nextRequiredAction = 'Activate the Unity editor license, then rerun this gate with -RunUnity after source staging is present.'
    } elseif ($RunUnity -and [string]$unity.status -eq 'NeedsSourceStaging') {
        $gateStatus = 'NeedsExplicitSourceStaging'
        $nextRequiredAction = 'Run this gate with -ApplySourceStaging before attempting the Unity prototype controller build.'
    } elseif ($canAcceptActorPrototypeControllers) {
        $gateStatus = 'PassedPrototypeControllerBuild'
        $nextRequiredAction = 'Use these generated actor prefabs only as controlled vertical-slice candidates; still validate visible playback and do not batch import CharacterArt or EnemyArt.'
    } elseif ($RunUnity) {
        $gateStatus = [string]$unity.status
        $nextRequiredAction = 'Inspect the Unity actor prototype controller build report, repair only the selected actors, then rerun this gate.'
    } elseif ($sourceStaged) {
        $gateStatus = 'SourceStagedNeedsUnityPrototypeBuild'
        $nextRequiredAction = 'Run this gate with -RunUnity after Unity licensing is active to build and validate the prototype controllers.'
    } else {
        $gateStatus = 'StaticReadyNeedsExplicitSourceStaging'
        $nextRequiredAction = 'Run `Tools\AssetImport\Test-ActorPrototypeControllerRebuildGate.ps1 -ApplySourceStaging` to copy the 16 planned actor source assets into the controlled candidate directory, then run with -RunUnity after Unity licensing is active.'
    }
}

$summaryJson = Join-Path $gateOutput 'actor-prototype-controller-rebuild-gate-summary.json'
$reportPath = Join-Path $gateOutput 'actor-prototype-controller-rebuild-gate-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    validationRoot = $ValidationRoot
    gateOutput = $gateOutput
    runUnity = [bool]$RunUnity
    applySourceStaging = [bool]$ApplySourceStaging
    overwriteGeneratedAssets = [bool]$OverwriteGeneratedAssets
    gateStatus = $gateStatus
    summaryJson = $summaryJson
    reportPath = $reportPath
    candidateFilter = @($candidateFilter)
    candidateCount = $candidateCount
    readiness = [PSCustomObject]@{
        candidateCount = [int]$readiness.CandidateCount
        staticReadyForPrototypeControllerRebuildCount = [int]$readiness.StaticReadyForPrototypeControllerRebuildCount
        notReadyCount = [int]$readiness.NotReadyCount
        summary = $readinessSummaryPath
        clipCsv = $readinessClipCsvPath
    }
    plan = [PSCustomObject]@{
        selectedCandidateCount = [int]$plan.selectedCandidateCount
        plannedSourceAssetCount = [int]$plan.plannedSourceAssetCount
        plannedControllerSpecCount = [int]$plan.plannedControllerSpecCount
        canStageSourceAssets = [bool]$plan.canStageSourceAssets
        issueCount = [int]$plan.issueCount
        totalBytes = [int64]$plan.totalBytes
        sourcePlanCsv = [string]$plan.sourcePlanCsv
        controllerSpecJson = [string]$plan.controllerSpecJson
    }
    sourceCopy = [PSCustomObject]@{
        apply = [bool]$sourceCopy.apply
        selectedCandidateCount = [int]$sourceCopy.selectedCandidateCount
        plannedAssetCount = [int]$sourceCopy.plannedAssetCount
        existingTargetFileCount = [int]$sourceCopy.existingTargetFileCount
        existingTargetMetaCount = [int]$sourceCopy.existingTargetMetaCount
        canApply = [bool]$sourceCopy.canApply
        appliedAssetCount = [int]$sourceCopy.appliedAssetCount
        issueCount = [int]$sourceCopy.issueCount
        totalBytes = [int64]$sourceCopy.totalBytes
        outputDirectory = [string]$sourceCopy.outputDirectory
        planCsv = [string]$sourceCopy.planCsv
    }
    compilePreflight = [PSCustomObject]@{
        status = [string]$compilePreflight.status
        scriptCount = [int]$compilePreflight.scriptCount
        warningCount = [int]$compilePreflight.warningCount
        errorCount = [int]$compilePreflight.errorCount
        issueCount = [int]$compilePreflight.issueCount
        outputText = [string]$compilePreflight.outputText
        summaryJson = [string]$compilePreflight.summaryJson
        interpretation = [string]$compilePreflight.interpretation
    }
    sourceStaged = $sourceStaged
    sourceSafety = $sourceSafety
    unity = [PSCustomObject]$unity
    canAcceptActorPrototypeControllers = $canAcceptActorPrototypeControllers
    issueCount = $issues.Count
    issues = @($issues)
    interpretation = $interpretation
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Actor prototype controller rebuild gate failed static validation with $($issues.Count) issue(s)."
}
