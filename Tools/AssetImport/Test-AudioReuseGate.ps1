[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [switch]$RunUnity,
    [ValidateSet('NotReviewed', 'Confirmed', 'Rejected')]
    [string]$ListeningReview = 'NotReviewed',
    [string]$ListeningNote
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

function Convert-ToTsvField {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ($Value -replace "`t", ' ' -replace "`r?`n", ' ')
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Audio Reuse Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Run Unity | $($Summary.runUnity) |") | Out-Null
    $lines.Add("| Static issue count | $($Summary.staticIssueCount) |") | Out-Null
    $lines.Add("| Unity status | $($Summary.unity.status) |") | Out-Null
    $lines.Add("| Audition pack | $($Summary.auditionPack.status) |") | Out-Null
    $lines.Add("| Semantic hints | $($Summary.semanticHints.gateStatus) |") | Out-Null
    $lines.Add("| Listening review | $($Summary.listening.review) |") | Out-Null
    $lines.Add("| Can satisfy minimum audio | $($Summary.canSatisfyMinimumAudio) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Selected Audio') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Role | Duration | Channels | Source bank |') | Out-Null
    $lines.Add('| --- | --- | ---: | ---: | --- |') | Out-Null
    foreach ($selection in $Summary.selections) {
        $lines.Add("| $($selection.Id) | $($selection.Role) | $($selection.DurationSeconds) | $($selection.Channels) | $($selection.SourceBank) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Semantic Hints') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Status | $($Summary.semanticHints.gateStatus) |") | Out-Null
    $lines.Add("| Media indexed count | $($Summary.semanticHints.mediaIndexedCount) |") | Out-Null
    $lines.Add("| Role hint count | $($Summary.semanticHints.roleHintCount) |") | Out-Null
    $lines.Add("| Report | $($Summary.semanticHints.reportPath) |") | Out-Null
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
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-audio-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $repoRoot 'Tools\AssetImport\tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\AudioReuseGate'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$gateOutput = Join-Path $ValidationRoot 'MinimumAudioSelection'

Assert-PathUnderOrEqual -Path $ManifestPath -Root $repoRoot -Label 'ManifestPath'
Assert-PathUnderOrEqual -Path $ToolManifestPath -Root $repoRoot -Label 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -Root $extractedRoot -Label 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing audio manifest: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$toolManifest = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$toolManifest.sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -Root $sourceInstall -Label 'ValidationRoot'

New-Item -ItemType Directory -Force -Path $gateOutput | Out-Null

$minimumAudio = & (Join-Path $PSScriptRoot 'Test-MinimumAudioSelection.ps1') -ManifestPath $ManifestPath -ToolManifestPath $ToolManifestPath
$staticIssues = [System.Collections.Generic.List[string]]::new()
foreach ($issue in @($minimumAudio.Issues)) {
    $staticIssues.Add([string]$issue) | Out-Null
}

$selectionListPath = Join-Path $gateOutput 'selected-audio.tsv'
$selectionLines = [System.Collections.Generic.List[string]]::new()
$selectionLines.Add("id`trole`tpath") | Out-Null
foreach ($selection in @($minimumAudio.Selections)) {
    $audioPath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$selection.Path)
    Assert-PathUnderOrEqual -Path $audioPath -Root $extractedRoot -Label "Audio selection '$($selection.Id)'"
    Assert-PathNotUnder -Path $audioPath -Root $sourceInstall -Label "Audio selection '$($selection.Id)'"
    $selectionLines.Add(("{0}`t{1}`t{2}" -f (Convert-ToTsvField $selection.Id), (Convert-ToTsvField $selection.Role), (Convert-ToTsvField $audioPath))) | Out-Null
}
$selectionLines | Set-Content -LiteralPath $selectionListPath -Encoding UTF8

$auditionPack = & (Join-Path $PSScriptRoot 'New-MinimumAudioAuditionPack.ps1') -ManifestPath $ManifestPath -ToolManifestPath $ToolManifestPath
$auditionPackStatus = if ([int]$auditionPack.issueCount -eq 0 -and [int]$auditionPack.previewCount -eq [int]$auditionPack.selectionCount) { 'ReadyForManualListening' } else { 'HasIssues' }
foreach ($issue in @($auditionPack.issues)) {
    $staticIssues.Add("Audio audition pack: $issue") | Out-Null
}

$semanticHints = & (Join-Path $PSScriptRoot 'Test-MinimumAudioSemanticHints.ps1') -SelectionPath $ManifestPath
foreach ($issue in @($semanticHints.issues)) {
    $staticIssues.Add("Audio semantic hints: $issue") | Out-Null
}

$unity = [ordered]@{
    status = if ($RunUnity) { 'Pending' } else { 'NotRun' }
    selectionList = $selectionListPath
    validationJson = Join-Path $gateOutput 'unity-audio-gate-validation.json'
    validationText = Join-Path $gateOutput 'unity-audio-gate-validation.txt'
    unityLog = Join-Path $gateOutput 'unity-audio-gate.log'
    decodedClipCount = 0
    loadFailureCount = 0
    audioSourceAttachCount = 0
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity) {
    $unityEditor = Get-CanonicalPath ([string]$toolManifest.unityEditor)
    if (-not (Test-Path -LiteralPath $unityEditor -PathType Leaf)) {
        throw "Missing Unity editor: $unityEditor"
    }

    $startedAt = Get-Date
    $arguments = @(
        '-batchmode',
        '-quit',
        '-projectPath', $repoRoot,
        '-executeMethod', 'StellaGaia.EditorTools.AudioReuseGateValidator.Run',
        '-logFile', $unity.unityLog,
        '-stellaGaiaAudioSelectionList', $selectionListPath,
        '-stellaGaiaAudioGateOutput', $gateOutput
    )

    $process = Start-Process -FilePath $unityEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
        $unity.licenseBlocked = [bool](Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet)
    }

    $unityReport = Read-JsonFile -Path $unity.validationJson
    if ($null -ne $unityReport) {
        $validationInfo = Get-Item -LiteralPath $unity.validationJson
        $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
        $unity.decodedClipCount = [int]$unityReport.decodedClipCount
        $unity.loadFailureCount = [int]$unityReport.loadFailureCount
        $unity.audioSourceAttachCount = [int]$unityReport.audioSourceAttachCount
    }

    if ($unity.licenseBlocked) {
        $unity.status = 'BlockedUnityLicense'
    } elseif ($process.ExitCode -ne 0 -and -not $unity.freshValidation) {
        $unity.status = 'UnityValidationFailed'
    } elseif (-not $unity.freshValidation) {
        $unity.status = 'MissingFreshUnityValidation'
    } elseif ($unity.loadFailureCount -gt 0) {
        $unity.status = 'UnityClipDecodeFailed'
    } elseif ($ListeningReview -eq 'Confirmed') {
        $unity.status = 'UnityClipDecodePassedListeningConfirmed'
    } elseif ($ListeningReview -eq 'Rejected') {
        $unity.status = 'RejectedListeningSemantics'
    } else {
        $unity.status = 'UnityClipDecodePassedNeedsListening'
    }
}

$gateStatus = 'StaticFailed'
$canSatisfyMinimumAudio = $false
$nextRequiredAction = 'Fix static audio selection issues before Unity playback validation.'
if ($staticIssues.Count -eq 0) {
    if (-not $RunUnity) {
        $gateStatus = 'StaticReadyNeedsUnityPlaybackAndListening'
        $nextRequiredAction = 'Run `Tools\AssetImport\Test-AudioReuseGate.ps1 -RunUnity` after Unity licensing is active, then confirm BGM loop and SFX/voice semantics by listening or Wwise event mapping.'
    } elseif ($unity.status -eq 'BlockedUnityLicense') {
        $gateStatus = 'BlockedUnityLicense'
        $nextRequiredAction = 'Activate the Unity editor license, then rerun this script with -RunUnity.'
    } elseif ($unity.status -eq 'UnityClipDecodePassedListeningConfirmed') {
        $gateStatus = 'PassedDevelopmentUsableCandidate'
        $canSatisfyMinimumAudio = $true
        $nextRequiredAction = 'Use these clips only for controlled vertical-slice audio integration; do not treat bank-name evidence as complete Wwise event recovery.'
    } elseif ($unity.status -eq 'RejectedListeningSemantics') {
        $gateStatus = 'RejectedListeningSemantics'
        $nextRequiredAction = 'Select replacement clips or build stronger Wwise event mapping before gameplay mainline work.'
    } else {
        $gateStatus = $unity.status
        $nextRequiredAction = 'Use Unity audio validation output plus listening/event mapping to confirm or replace selected BGM/SFX/voice candidates.'
    }
}

$summaryJson = Join-Path $gateOutput 'audio-reuse-gate-summary.json'
$reportPath = Join-Path $gateOutput 'audio-reuse-gate-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    validationRoot = $ValidationRoot
    runUnity = [bool]$RunUnity
    gateStatus = $gateStatus
    canSatisfyMinimumAudio = $canSatisfyMinimumAudio
    summaryJson = $summaryJson
    reportPath = $reportPath
    selectedAudioList = $selectionListPath
    staticIssueCount = $staticIssues.Count
    staticIssues = @($staticIssues)
    selections = @($minimumAudio.Selections)
    auditionPack = [PSCustomObject]@{
        status = $auditionPackStatus
        selectionCount = [int]$auditionPack.selectionCount
        previewCount = [int]$auditionPack.previewCount
        waveformCount = [int]$auditionPack.waveformCount
        issueCount = [int]$auditionPack.issueCount
        indexHtml = [string]$auditionPack.indexHtml
        listeningReviewTsv = [string]$auditionPack.listeningReviewTsv
        summaryJson = [string]$auditionPack.summaryJson
        interpretation = [string]$auditionPack.interpretation
    }
    semanticHints = [PSCustomObject]@{
        gateStatus = [string]$semanticHints.gateStatus
        selectionCount = [int]$semanticHints.selectionCount
        mediaIndexedCount = [int]$semanticHints.mediaIndexedCount
        roleHintCount = [int]$semanticHints.roleHintCount
        issueCount = [int]$semanticHints.issueCount
        summaryJson = [string]$semanticHints.summaryJson
        csvPath = [string]$semanticHints.csvPath
        reportPath = [string]$semanticHints.reportPath
        interpretation = 'Bank/media semantic hints are not listening, Wwise event recovery, or Unity playback evidence.'
    }
    unity = [PSCustomObject]$unity
    listening = [PSCustomObject]@{
        review = $ListeningReview
        note = if ([string]::IsNullOrWhiteSpace($ListeningNote)) { '' } else { $ListeningNote }
    }
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($staticIssues.Count -gt 0) {
    throw "Audio reuse gate static validation failed with $($staticIssues.Count) issue(s)."
}
