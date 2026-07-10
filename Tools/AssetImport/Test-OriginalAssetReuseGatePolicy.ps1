[CmdletBinding()]
param(
    [string]$ValidationRoot
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Add-PolicyIssue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Issues,
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        $Issues.Add($Message) | Out-Null
    }
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Join-Path $repoRoot 'Extracted'
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\OriginalAssetReuseGatePolicy'
}

$summary = & (Join-Path $PSScriptRoot 'Test-OriginalAssetReuseGate.ps1') -ValidationRoot $ValidationRoot

$issues = [System.Collections.Generic.List[string]]::new()
$requiredDecisions = @('UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'Stop')

Add-PolicyIssue -Issues $issues -Condition ($null -eq $summary.gateInterpretation) -Message 'Original asset reuse gate summary is missing gateInterpretation.'
Add-PolicyIssue -Issues $issues -Condition ($null -eq $summary.postUnityManifestRerunPolicy) -Message 'Original asset reuse gate summary is missing postUnityManifestRerunPolicy.'
Add-PolicyIssue -Issues $issues -Condition ($null -eq $summary.laneTriage) -Message 'Original asset reuse gate summary is missing laneTriage.'

if ($null -ne $summary.gateInterpretation) {
    Add-PolicyIssue -Issues $issues -Condition ([bool]$summary.gateInterpretation.canMakeGameplayGoDecision) -Message 'A non-Unity root gate run must not be able to make a gameplay Go decision.'
    Add-PolicyIssue -Issues $issues -Condition (-not [bool]$summary.gateInterpretation.requiresUnityFocusedTriage) -Message 'A non-Unity root gate run must require Unity focused triage.'
}

if ($null -ne $summary.postUnityManifestRerunPolicy) {
    Add-PolicyIssue -Issues $issues -Condition (-not [bool]$summary.postUnityManifestRerunPolicy.requiredAfterRunUnity) -Message 'Post-Unity manifest rerun policy must be explicit.'
    Add-PolicyIssue -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$summary.postUnityManifestRerunPolicy.minimumVerticalSliceManifest)) -Message 'Post-Unity policy must name the minimum vertical slice manifest.'
    Add-PolicyIssue -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$summary.postUnityManifestRerunPolicy.assetAcceptanceManifest)) -Message 'Post-Unity policy must name the asset acceptance manifest.'
}

if ($null -ne $summary.laneTriage) {
    foreach ($decision in $requiredDecisions) {
        Add-PolicyIssue -Issues $issues -Condition ($decision -notin @($summary.laneTriage.decisionVocabulary)) -Message "Lane triage vocabulary is missing '$decision'."
    }

    $requiredLanes = @('environment', 'actorPrototypeControllers', 'uiReward', 'audio', 'controlledImportCandidates')
    foreach ($laneName in $requiredLanes) {
        $lane = $summary.laneTriage.lanes.$laneName
        Add-PolicyIssue -Issues $issues -Condition ($null -eq $lane) -Message "Lane triage is missing lane '$laneName'."
        if ($null -ne $lane) {
            Add-PolicyIssue -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$lane.decision)) -Message "Lane '$laneName' is missing a decision."
            Add-PolicyIssue -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$lane.directGateSummary)) -Message "Lane '$laneName' is missing directGateSummary."
            Add-PolicyIssue -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$lane.nextAllowedAction)) -Message "Lane '$laneName' is missing nextAllowedAction."
            Add-PolicyIssue -Issues $issues -Condition ($null -eq $lane.unityEvidence) -Message "Lane '$laneName' is missing unityEvidence."
        }
    }
}

$policySummary = [PSCustomObject]@{
    gateSummary = [string]$summary.summaryJson
    issueCount = $issues.Count
    issues = @($issues)
}

if ($issues.Count -gt 0) {
    $policySummary | ConvertTo-Json -Depth 6 | Write-Output
    throw "Original asset reuse gate policy validation failed with $($issues.Count) issue(s)."
}

$policySummary
