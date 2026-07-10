[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ValidationRoot,
    [switch]$AllowMissingOptionalEvidence
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

function Resolve-RepoRelativePath {
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

function Get-StageRank {
    param([Parameter(Mandatory = $true)][string]$Status)

    switch ($Status) {
        'AssetLocated' { return 1 }
        'DiagnosticInputOnly' { return 1 }
        'ExtractedReadable' { return 2 }
        'CrossToolVerified' { return 3 }
        'SemanticContextRecovered' { return 4 }
        'UnityImportCandidate' { return 5 }
        'ReconstructedPrototypeAsset' { return 6 }
        'DevelopmentUsable' { return 7 }
        default { return 0 }
    }
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Asset Acquisition Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Can support Unity import triage | $($Summary.canSupportUnityImportTriage) |") | Out-Null
    $lines.Add("| Can grant development usability | $($Summary.canGrantDevelopmentUsability) |") | Out-Null
    $lines.Add("| Required group count | $($Summary.requiredGroupCount) |") | Out-Null
    $lines.Add("| Missing evidence count | $($Summary.missingEvidenceCount) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Evidence Groups') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Group | Status | Required | Evidence files | Missing files |') | Out-Null
    $lines.Add('| --- | --- | --- | ---: | ---: |') | Out-Null
    foreach ($group in @($Summary.evidenceGroups)) {
        $lines.Add("| $($group.id) | $($group.status) | $($group.requiredForAssetAcquisitionGate) | $($group.evidenceCount) | $($group.missingEvidenceCount) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    $lines.Add('') | Out-Null
    if ($Summary.issues.Count -eq 0) {
        $lines.Add('None.') | Out-Null
    } else {
        foreach ($issue in @($Summary.issues)) {
            $lines.Add("- $issue") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Interpretation') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.interpretation) | Out-Null

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Join-Path $repoRoot 'Extracted'
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\asset-acquisition-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\AssetAcquisitionGate'
}

$ManifestPath = Get-CanonicalPath $ManifestPath
$ValidationRoot = Get-CanonicalPath $ValidationRoot
if (-not (Test-IsPathUnderOrEqual -CandidatePath $ManifestPath -RootPath $repoRoot)) {
    throw "ManifestPath must stay under repository root. Got: $ManifestPath"
}
if (-not (Test-IsPathUnderOrEqual -CandidatePath $ValidationRoot -RootPath $extractedRoot)) {
    throw "ValidationRoot must stay under Extracted. Got: $ValidationRoot"
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing asset acquisition manifest: $ManifestPath"
}

New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$issues = [System.Collections.Generic.List[string]]::new()
$missingEvidence = [System.Collections.Generic.List[string]]::new()
$validStatuses = @($manifest.statusVocabulary)

Add-IssueIf -Issues $issues -Condition ([string]::IsNullOrWhiteSpace([string]$manifest.objective)) -Message 'Manifest is missing objective.'
Add-IssueIf -Issues $issues -Condition ($null -eq $manifest.policy -or -not [bool]$manifest.policy.assetAcquisitionDoesNotGrantDevelopmentUsability) -Message 'Manifest policy must state that acquisition does not grant development usability.'
Add-IssueIf -Issues $issues -Condition ($null -eq $manifest.policy -or -not [bool]$manifest.policy.requiresUnityVisibleOrAudibleEvidenceForDevelopmentUsable) -Message 'Manifest policy must require Unity visible/audible evidence for DevelopmentUsable.'

if ($null -ne $toolManifest) {
    $sourceInstall = [string]$toolManifest.sourceInstall
    Add-IssueIf -Issues $issues -Condition ([string]::IsNullOrWhiteSpace($sourceInstall)) -Message 'tool-manifest.json is missing sourceInstall.'
    Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($sourceInstall) -and -not (Test-Path -LiteralPath $sourceInstall -PathType Container)) -Message "Source install is not accessible: $sourceInstall"
    Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($sourceInstall) -and (Test-Path -LiteralPath (Join-Path $sourceInstall 'Extracted'))) -Message 'Source install contains generated Extracted directory.'
    Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($sourceInstall) -and (Test-Path -LiteralPath (Join-Path $sourceInstall 'Assets'))) -Message 'Source install contains generated Assets directory.'
    Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($sourceInstall) -and (Test-Path -LiteralPath (Join-Path $sourceInstall 'Tools'))) -Message 'Source install contains generated Tools directory.'

    foreach ($tool in @($manifest.toolRoutes)) {
        if ([string]$tool.configuredBy -ne 'Tools\AssetImport\tool-manifest.json') {
            continue
        }

        $propertyName = switch ([string]$tool.id) {
            'AssetRipper' { 'assetRipper' }
            'vgmstream' { 'vgmstreamCli' }
            default { '' }
        }
        if ([string]::IsNullOrWhiteSpace($propertyName)) {
            continue
        }

        $configuredPath = [string]$toolManifest.$propertyName
        if ([bool]$tool.requiredForCurrentGate) {
            Add-IssueIf -Issues $issues -Condition ([string]::IsNullOrWhiteSpace($configuredPath)) -Message "Required tool '$($tool.id)' is not configured in tool-manifest.json."
            Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($configuredPath) -and -not (Test-Path -LiteralPath $configuredPath -PathType Leaf)) -Message "Required tool '$($tool.id)' is not accessible: $configuredPath"
        }
    }
} else {
    $issues.Add("Missing tool manifest: $toolManifestPath") | Out-Null
}

$groupSummaries = [System.Collections.Generic.List[object]]::new()
foreach ($group in @($manifest.evidenceGroups)) {
    $id = [string]$group.id
    $status = [string]$group.status
    $required = [bool]$group.requiredForAssetAcquisitionGate
    $minimumRequiredStatus = [string]$group.minimumRequiredStatus
    if ([string]::IsNullOrWhiteSpace($id)) {
        $issues.Add('An evidence group is missing id.') | Out-Null
    }
    Add-IssueIf -Issues $issues -Condition ($status -notin $validStatuses) -Message "Evidence group '$id' uses unsupported status '$status'."
    Add-IssueIf -Issues $issues -Condition (-not [string]::IsNullOrWhiteSpace($minimumRequiredStatus) -and $minimumRequiredStatus -notin $validStatuses) -Message "Evidence group '$id' uses unsupported minimumRequiredStatus '$minimumRequiredStatus'."

    if ([string]$status -eq 'DevelopmentUsable') {
        $issues.Add("Evidence group '$id' is DevelopmentUsable in the acquisition manifest. Development usability must be granted by Unity reuse gates, not acquisition evidence.") | Out-Null
    }

    if ($required -and (Get-StageRank -Status $status) -lt (Get-StageRank -Status $minimumRequiredStatus)) {
        $issues.Add("Evidence group '$id' status '$status' is below required '$minimumRequiredStatus'.") | Out-Null
    }

    $groupMissingEvidence = [System.Collections.Generic.List[string]]::new()
    $evidenceCount = 0
    foreach ($evidence in @($group.evidence)) {
        $evidenceText = [string]$evidence
        if ([string]::IsNullOrWhiteSpace($evidenceText)) {
            $issues.Add("Evidence group '$id' contains an empty evidence path.") | Out-Null
            continue
        }

        $evidenceCount++
        $evidencePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $evidenceText
        if (-not (Test-IsPathUnderOrEqual -CandidatePath $evidencePath -RootPath $repoRoot)) {
            $issues.Add("Evidence for '$id' points outside repository root: $evidenceText") | Out-Null
            continue
        }

        if (-not (Test-Path -LiteralPath $evidencePath)) {
            if ($required -or -not $AllowMissingOptionalEvidence) {
                $missing = "$id :: $evidenceText"
                $groupMissingEvidence.Add($missing) | Out-Null
                $missingEvidence.Add($missing) | Out-Null
            }
        }
    }

    $groupSummaries.Add([PSCustomObject]@{
        id = $id
        label = [string]$group.label
        status = $status
        requiredForAssetAcquisitionGate = $required
        minimumRequiredStatus = $minimumRequiredStatus
        evidenceCount = $evidenceCount
        missingEvidenceCount = $groupMissingEvidence.Count
        missingEvidence = @($groupMissingEvidence)
        meaning = [string]$group.meaning
    }) | Out-Null
}

foreach ($missing in @($missingEvidence)) {
    $issues.Add("Missing evidence path: $missing") | Out-Null
}

$requiredGroups = @($groupSummaries | Where-Object { [bool]$_.requiredForAssetAcquisitionGate })
$canSupportUnityImportTriage = $issues.Count -eq 0 -and $missingEvidence.Count -eq 0 -and $requiredGroups.Count -gt 0
$gateStatus = if ($issues.Count -gt 0) {
    'StaticFailed'
} elseif (-not $canSupportUnityImportTriage) {
    'AssetAcquisitionIncomplete'
} else {
    'AssetAcquisitionEvidenceReady'
}

$summaryJson = Join-Path $ValidationRoot 'asset-acquisition-gate-summary.json'
$reportPath = Join-Path $ValidationRoot 'asset-acquisition-gate-report.md'
$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    summaryJson = $summaryJson
    reportPath = $reportPath
    gateStatus = $gateStatus
    canSupportUnityImportTriage = $canSupportUnityImportTriage
    canGrantDevelopmentUsability = $false
    requiredGroupCount = $requiredGroups.Count
    evidenceGroupCount = @($groupSummaries).Count
    missingEvidenceCount = $missingEvidence.Count
    issueCount = $issues.Count
    issues = @($issues)
    evidenceGroups = @($groupSummaries)
    interpretation = 'Asset acquisition evidence can raise confidence that assets can be located, extracted, decoded, and prepared for reconstruction. It does not prove original Unity project restoration or Development-Usable Asset status.'
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Asset acquisition gate failed with $($issues.Count) issue(s)."
}
