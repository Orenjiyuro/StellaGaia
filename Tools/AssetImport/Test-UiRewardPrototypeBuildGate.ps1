[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [switch]$ApplyTextureStaging,
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
    $lines.Add('# UI Reward Prototype Build Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Apply texture staging | $($Summary.applyTextureStaging) |") | Out-Null
    $lines.Add("| Accepted textures | $($Summary.rebuildPlan.acceptedTextureCount) |") | Out-Null
    $lines.Add("| Texture staging | $($Summary.textureStaging.status) |") | Out-Null
    $lines.Add("| Texture sources staged | $($Summary.sourceTexturesStaged) |") | Out-Null
    $lines.Add("| Builder compile | $($Summary.compilePreflight.status) |") | Out-Null
    $lines.Add("| Unity status | $($Summary.unity.status) |") | Out-Null
    $lines.Add("| Unity visible screenshots | $($Summary.unity.visibleScreenshotCount) |") | Out-Null
    $lines.Add("| Can accept rebuilt UI/reward prototype | $($Summary.canAcceptUiRewardPrototype) |") | Out-Null
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
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\UiRewardPrototypeBuildGate'
}

$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$gateOutput = Join-Path $ValidationRoot 'RebuiltUiReward'

Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$toolManifest = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$toolManifest.sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'
[void][System.IO.Directory]::CreateDirectory($gateOutput)

$issues = [System.Collections.Generic.List[string]]::new()

$rebuildPlan = & (Join-Path $PSScriptRoot 'New-UiRewardPrototypeRebuildPlan.ps1')
Add-IssueIf -Issues $issues -Condition ([int]$rebuildPlan.issueCount -gt 0) -Message 'UI/reward prototype rebuild plan has issues.'
Add-IssueIf -Issues $issues -Condition (-not [bool]$rebuildPlan.canStageSourceTextures) -Message 'UI/reward prototype source textures cannot be staged safely.'

$textureStagingArgs = @{
    PlanCsvPath = [string]$rebuildPlan.sourcePlanCsv
}
if ($ApplyTextureStaging) {
    $textureStagingArgs.Apply = $true
}
$textureStaging = & (Join-Path $PSScriptRoot 'Copy-UiRewardPrototypeSourceTextures.ps1') @textureStagingArgs
Add-IssueIf -Issues $issues -Condition ([int]$textureStaging.issueCount -gt 0) -Message 'UI/reward prototype texture staging has issues.'
Add-IssueIf -Issues $issues -Condition (-not [bool]$textureStaging.canApply) -Message 'UI/reward prototype texture staging cannot apply safely.'

$plannedTextureCount = [int]$textureStaging.plannedTextureCount
$sourceTexturesStaged = ([int]$textureStaging.appliedTextureCount -eq $plannedTextureCount -and $plannedTextureCount -gt 0) -or
    ([int]$textureStaging.existingTargetFileCount -ge $plannedTextureCount -and [int]$textureStaging.existingTargetMetaCount -ge $plannedTextureCount -and $plannedTextureCount -gt 0 -and [int]$textureStaging.targetOverwriteRiskCount -eq 0)

$compilePreflight = & (Join-Path $PSScriptRoot 'Test-UnityEditorScriptCompilePreflight.ps1') -ToolManifestPath $ToolManifestPath -EditorScriptPath @('Assets\StellaGaia\Editor\UiRewardPrototypeBuilder.cs') -ValidationRoot (Join-Path $extractedRoot 'Validation\UiRewardPrototypeBuildPreflight') -NoThrow
Add-IssueIf -Issues $issues -Condition ([string]$compilePreflight.status -eq 'CompileFailed') -Message 'UI/reward prototype Unity editor builder failed offline compile preflight.'
Add-IssueIf -Issues $issues -Condition ([string]$compilePreflight.status -eq 'PreflightInputFailed') -Message 'UI/reward prototype Unity editor builder compile preflight input is missing.'

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
    validationJson = Join-Path $gateOutput 'unity-ui-reward-prototype-build.json'
    validationText = Join-Path $gateOutput 'unity-ui-reward-prototype-build.txt'
    unityLog = Join-Path $gateOutput 'unity-ui-reward-prototype-build.log'
    specPath = [string]$rebuildPlan.specJson
    loadedSpriteCount = 0
    createdPrefabCount = 0
    renderedScreenshotCount = 0
    visibleScreenshotCount = 0
    successfulPrefabCount = 0
    criticalIssueCount = 0
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity -and $issues.Count -eq 0) {
    if (-not $sourceTexturesStaged) {
        $unity.status = 'NeedsTextureStaging'
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
            '-executeMethod', 'StellaGaia.EditorTools.UiRewardPrototypeBuilder.Run',
            '-logFile', $unity.unityLog,
            '-stellaGaiaUiRewardPrototypeSpec', ([string]$rebuildPlan.specJson),
            '-stellaGaiaUiRewardPrototypeOutput', $gateOutput,
            '-stellaGaiaUiRewardPrototypeOverwrite', ($(if ($OverwriteGeneratedAssets) { 'true' } else { 'false' }))
        )

        $process = Start-Process -FilePath $unityEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
        if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
            $unity.licenseBlocked = [bool](Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet)
        }

        $unityReport = Read-JsonFile -Path $unity.validationJson
        if ($null -ne $unityReport) {
            $validationInfo = Get-Item -LiteralPath $unity.validationJson
            $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
            $unity.loadedSpriteCount = [int]$unityReport.loadedSpriteCount
            $unity.createdPrefabCount = [int]$unityReport.createdPrefabCount
            $unity.renderedScreenshotCount = [int]$unityReport.renderedScreenshotCount
            $unity.visibleScreenshotCount = [int]$unityReport.visibleScreenshotCount
            $unity.successfulPrefabCount = [int]$unityReport.successfulPrefabCount
            $unity.criticalIssueCount = [int]$unityReport.criticalIssueCount
        }

        if ($unity.licenseBlocked) {
            $unity.status = 'BlockedUnityLicense'
        } elseif ($process.ExitCode -ne 0 -and -not $unity.freshValidation) {
            $unity.status = 'UnityPrototypeBuildFailed'
        } elseif (-not $unity.freshValidation) {
            $unity.status = 'MissingFreshUnityPrototypeBuildReport'
        } elseif ([int]$unity.criticalIssueCount -gt 0) {
            $unity.status = 'PrototypeBuiltWithIssues'
        } elseif ([int]$unity.successfulPrefabCount -ge 3 -and [int]$unity.visibleScreenshotCount -ge 3) {
            $unity.status = 'PrototypeBuildPassed'
        } else {
            $unity.status = 'PrototypeBuildIncomplete'
        }
    }
}

$canAcceptUiRewardPrototype = $RunUnity -and [string]$unity.status -eq 'PrototypeBuildPassed' -and $issues.Count -eq 0
$gateStatus = 'StaticFailed'
$nextRequiredAction = 'Fix UI/reward prototype plan, texture staging, builder compile, or source safety issues.'
$interpretation = 'This gate validates the rebuilt UI/reward route from accepted original StellaSora Texture2D assets. It does not accept the original high-risk UI/drop prefabs.'

if ($issues.Count -eq 0) {
    if ($RunUnity -and [string]$unity.status -eq 'BlockedUnityLicense') {
        $gateStatus = 'BlockedUnityLicense'
        $nextRequiredAction = 'Activate the Unity editor license, then rerun this gate with -RunUnity.'
    } elseif ($RunUnity -and [string]$unity.status -eq 'NeedsTextureStaging') {
        $gateStatus = 'NeedsExplicitTextureStaging'
        $nextRequiredAction = 'Run this gate with -ApplyTextureStaging before attempting the Unity prototype build.'
    } elseif ($canAcceptUiRewardPrototype) {
        $gateStatus = 'PassedRebuiltUiRewardPrototype'
        $nextRequiredAction = 'Use the generated reward/card UI prefabs only as controlled vertical-slice candidates; do not batch import UiOrItemArt.'
    } elseif ($RunUnity) {
        $gateStatus = [string]$unity.status
        $nextRequiredAction = 'Inspect the Unity UI reward prototype build report and screenshots, then repair or reject the rebuilt UI route.'
    } elseif ($sourceTexturesStaged) {
        $gateStatus = 'StaticReadyNeedsUnityPrototypeBuild'
        $nextRequiredAction = 'Run this gate with -RunUnity after Unity licensing is active to build reward/card prefabs and capture screenshot evidence.'
    } else {
        $gateStatus = 'StaticReadyNeedsExplicitTextureStaging'
        $nextRequiredAction = 'Run `Tools\AssetImport\Test-UiRewardPrototypeBuildGate.ps1 -ApplyTextureStaging`, then run with -RunUnity after Unity licensing is active.'
    }
}

$summaryJson = Join-Path $gateOutput 'ui-reward-prototype-build-gate-summary.json'
$reportPath = Join-Path $gateOutput 'ui-reward-prototype-build-gate-report.md'
$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    validationRoot = $ValidationRoot
    gateOutput = $gateOutput
    runUnity = [bool]$RunUnity
    applyTextureStaging = [bool]$ApplyTextureStaging
    overwriteGeneratedAssets = [bool]$OverwriteGeneratedAssets
    gateStatus = $gateStatus
    rebuildPlan = [PSCustomObject]@{
        status = [string]$rebuildPlan.status
        acceptedTextureCount = [int]$rebuildPlan.acceptedTextureCount
        requiredAcceptedTextureCount = [int]$rebuildPlan.requiredAcceptedTextureCount
        optionalAcceptedTextureCount = [int]$rebuildPlan.optionalAcceptedTextureCount
        canStageSourceTextures = [bool]$rebuildPlan.canStageSourceTextures
        issueCount = [int]$rebuildPlan.issueCount
        totalBytes = [int64]$rebuildPlan.totalBytes
        sourcePlanCsv = [string]$rebuildPlan.sourcePlanCsv
        specJson = [string]$rebuildPlan.specJson
        reportPath = [string]$rebuildPlan.reportPath
    }
    textureStaging = [PSCustomObject]@{
        apply = [bool]$textureStaging.apply
        status = [string]$textureStaging.status
        plannedTextureCount = [int]$textureStaging.plannedTextureCount
        existingTargetFileCount = [int]$textureStaging.existingTargetFileCount
        existingTargetMetaCount = [int]$textureStaging.existingTargetMetaCount
        canApply = [bool]$textureStaging.canApply
        appliedTextureCount = [int]$textureStaging.appliedTextureCount
        targetOverwriteRiskCount = [int]$textureStaging.targetOverwriteRiskCount
        projectGuidConflictCount = [int]$textureStaging.projectGuidConflictCount
        issueCount = [int]$textureStaging.issueCount
        summaryJson = [string]$textureStaging.summaryJson
        reportPath = [string]$textureStaging.reportPath
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
    sourceTexturesStaged = $sourceTexturesStaged
    sourceSafety = $sourceSafety
    unity = [PSCustomObject]$unity
    canAcceptUiRewardPrototype = $canAcceptUiRewardPrototype
    issueCount = $issues.Count
    issues = @($issues)
    summaryJson = $summaryJson
    reportPath = $reportPath
    interpretation = $interpretation
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 9 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "UI/reward prototype build gate failed static validation with $($issues.Count) issue(s)."
}
