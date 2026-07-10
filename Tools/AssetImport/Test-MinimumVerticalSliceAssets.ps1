[CmdletBinding()]
param(
    [string]$ManifestPath,
    [switch]$AllowMissingEvidence,
    [switch]$RequireGameplayReady
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

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-vertical-slice-assets.json'
}

$ManifestPath = Get-CanonicalPath $ManifestPath
if (-not (Test-IsPathUnderOrEqual -CandidatePath $ManifestPath -RootPath $repoRoot)) {
    throw "ManifestPath must stay under repository root. Got: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing minimum vertical slice manifest: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$issues = [System.Collections.Generic.List[string]]::new()
$blockingStatuses = @(
    'AssetLocated',
    'ExtractedReadable',
    'CrossToolVerified',
    'SemanticContextRecovered',
    'UnityImportCandidate',
    'ReconstructedPrototypeAsset',
    'CandidateReadyForControlledImport',
    'BlockedNeedsUnityVisibleValidation',
    'MediaAvailableNeedsSelection',
    'SelectedNeedsUnityPlaybackValidation',
    'SelectedNeedsUnityVisibleValidation',
    'PendingRepairOrReplacement',
    'Rejected',
    'NotUsableYet'
)
$validStatuses = @(
    'AssetLocated',
    'ExtractedReadable',
    'CrossToolVerified',
    'SemanticContextRecovered',
    'UnityImportCandidate',
    'ReconstructedPrototypeAsset',
    'CandidateReadyForControlledImport',
    'BlockedNeedsUnityVisibleValidation',
    'MediaAvailableNeedsSelection',
    'SelectedNeedsUnityPlaybackValidation',
    'SelectedNeedsUnityVisibleValidation',
    'PendingRepairOrReplacement',
    'DevelopmentUsable',
    'Rejected',
    'NotUsableYet'
)

if ([string]::IsNullOrWhiteSpace([string]$manifest.assetAcceptanceManifest)) {
    $issues.Add('Manifest is missing assetAcceptanceManifest.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.originalAssetReuseGate)) {
    $issues.Add('Manifest is missing originalAssetReuseGate.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.controlledImportCandidateGate)) {
    $issues.Add('Manifest is missing controlledImportCandidateGate.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.actorPrototypeControllerGate)) {
    $issues.Add('Manifest is missing actorPrototypeControllerGate.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.uiRewardPrototypeBuildGate)) {
    $issues.Add('Manifest is missing uiRewardPrototypeBuildGate.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.environmentModuleGate)) {
    $issues.Add('Manifest is missing environmentModuleGate.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.audioReuseGate)) {
    $issues.Add('Manifest is missing audioReuseGate.') | Out-Null
}

$acceptancePath = $null
$acceptance = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.assetAcceptanceManifest)) {
    $acceptancePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.assetAcceptanceManifest)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $acceptancePath -RootPath $repoRoot)) {
        $issues.Add("assetAcceptanceManifest points outside repository root: $($manifest.assetAcceptanceManifest)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $acceptancePath -PathType Leaf)) {
        $issues.Add("Missing assetAcceptanceManifest: $($manifest.assetAcceptanceManifest)") | Out-Null
    } else {
        $acceptance = Get-Content -LiteralPath $acceptancePath -Raw | ConvertFrom-Json
    }
}

$originalAssetReuseGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.originalAssetReuseGate)) {
    $originalAssetReuseGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.originalAssetReuseGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $originalAssetReuseGatePath -RootPath $repoRoot)) {
        $issues.Add("originalAssetReuseGate points outside repository root: $($manifest.originalAssetReuseGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $originalAssetReuseGatePath -PathType Leaf)) {
        $issues.Add("Missing originalAssetReuseGate script: $($manifest.originalAssetReuseGate)") | Out-Null
    }
}

$originalAssetReuseGateSummaryPath = $null
$originalAssetReuseGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.originalAssetReuseGateSummary)) {
    $originalAssetReuseGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.originalAssetReuseGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $originalAssetReuseGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("originalAssetReuseGateSummary points outside repository root: $($manifest.originalAssetReuseGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $originalAssetReuseGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing originalAssetReuseGateSummary: $($manifest.originalAssetReuseGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $originalAssetReuseGateSummaryPath -PathType Leaf) {
        $originalAssetReuseGateSummary = Get-Content -LiteralPath $originalAssetReuseGateSummaryPath -Raw | ConvertFrom-Json
    }
}

$controlledImportCandidateGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.controlledImportCandidateGate)) {
    $controlledImportCandidateGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.controlledImportCandidateGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $controlledImportCandidateGatePath -RootPath $repoRoot)) {
        $issues.Add("controlledImportCandidateGate points outside repository root: $($manifest.controlledImportCandidateGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $controlledImportCandidateGatePath -PathType Leaf)) {
        $issues.Add("Missing controlledImportCandidateGate script: $($manifest.controlledImportCandidateGate)") | Out-Null
    }
}

$controlledImportCandidateGateSummaryPath = $null
$controlledImportCandidateGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.controlledImportCandidateGateSummary)) {
    $controlledImportCandidateGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.controlledImportCandidateGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $controlledImportCandidateGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("controlledImportCandidateGateSummary points outside repository root: $($manifest.controlledImportCandidateGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $controlledImportCandidateGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing controlledImportCandidateGateSummary: $($manifest.controlledImportCandidateGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $controlledImportCandidateGateSummaryPath -PathType Leaf) {
        $controlledImportCandidateGateSummary = Get-Content -LiteralPath $controlledImportCandidateGateSummaryPath -Raw | ConvertFrom-Json
    }
}

$actorPrototypeControllerGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.actorPrototypeControllerGate)) {
    $actorPrototypeControllerGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.actorPrototypeControllerGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $actorPrototypeControllerGatePath -RootPath $repoRoot)) {
        $issues.Add("actorPrototypeControllerGate points outside repository root: $($manifest.actorPrototypeControllerGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $actorPrototypeControllerGatePath -PathType Leaf)) {
        $issues.Add("Missing actorPrototypeControllerGate script: $($manifest.actorPrototypeControllerGate)") | Out-Null
    }
}

$actorPrototypeControllerGateSummaryPath = $null
$actorPrototypeControllerGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.actorPrototypeControllerGateSummary)) {
    $actorPrototypeControllerGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.actorPrototypeControllerGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $actorPrototypeControllerGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("actorPrototypeControllerGateSummary points outside repository root: $($manifest.actorPrototypeControllerGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $actorPrototypeControllerGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing actorPrototypeControllerGateSummary: $($manifest.actorPrototypeControllerGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $actorPrototypeControllerGateSummaryPath -PathType Leaf) {
        $actorPrototypeControllerGateSummary = Get-Content -LiteralPath $actorPrototypeControllerGateSummaryPath -Raw | ConvertFrom-Json
    }
}

$uiRewardPrototypeBuildGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.uiRewardPrototypeBuildGate)) {
    $uiRewardPrototypeBuildGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.uiRewardPrototypeBuildGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $uiRewardPrototypeBuildGatePath -RootPath $repoRoot)) {
        $issues.Add("uiRewardPrototypeBuildGate points outside repository root: $($manifest.uiRewardPrototypeBuildGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $uiRewardPrototypeBuildGatePath -PathType Leaf)) {
        $issues.Add("Missing uiRewardPrototypeBuildGate script: $($manifest.uiRewardPrototypeBuildGate)") | Out-Null
    }
}

$uiRewardPrototypeBuildGateSummaryPath = $null
$uiRewardPrototypeBuildGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.uiRewardPrototypeBuildGateSummary)) {
    $uiRewardPrototypeBuildGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.uiRewardPrototypeBuildGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $uiRewardPrototypeBuildGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("uiRewardPrototypeBuildGateSummary points outside repository root: $($manifest.uiRewardPrototypeBuildGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $uiRewardPrototypeBuildGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing uiRewardPrototypeBuildGateSummary: $($manifest.uiRewardPrototypeBuildGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $uiRewardPrototypeBuildGateSummaryPath -PathType Leaf) {
        $uiRewardPrototypeBuildGateSummary = Get-Content -LiteralPath $uiRewardPrototypeBuildGateSummaryPath -Raw | ConvertFrom-Json
    }
}

$environmentModuleGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.environmentModuleGate)) {
    $environmentModuleGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.environmentModuleGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $environmentModuleGatePath -RootPath $repoRoot)) {
        $issues.Add("environmentModuleGate points outside repository root: $($manifest.environmentModuleGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $environmentModuleGatePath -PathType Leaf)) {
        $issues.Add("Missing environmentModuleGate script: $($manifest.environmentModuleGate)") | Out-Null
    }
}

$environmentModuleGateSummaryPath = $null
$environmentModuleGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.environmentModuleGateSummary)) {
    $environmentModuleGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.environmentModuleGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $environmentModuleGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("environmentModuleGateSummary points outside repository root: $($manifest.environmentModuleGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $environmentModuleGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing environmentModuleGateSummary: $($manifest.environmentModuleGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $environmentModuleGateSummaryPath -PathType Leaf) {
        $environmentModuleGateSummary = Get-Content -LiteralPath $environmentModuleGateSummaryPath -Raw | ConvertFrom-Json
    }
}

$audioReuseGatePath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.audioReuseGate)) {
    $audioReuseGatePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.audioReuseGate)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $audioReuseGatePath -RootPath $repoRoot)) {
        $issues.Add("audioReuseGate points outside repository root: $($manifest.audioReuseGate)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $audioReuseGatePath -PathType Leaf)) {
        $issues.Add("Missing audioReuseGate script: $($manifest.audioReuseGate)") | Out-Null
    }
}

$audioReuseGateSummaryPath = $null
$audioReuseGateSummary = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.audioReuseGateSummary)) {
    $audioReuseGateSummaryPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.audioReuseGateSummary)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $audioReuseGateSummaryPath -RootPath $repoRoot)) {
        $issues.Add("audioReuseGateSummary points outside repository root: $($manifest.audioReuseGateSummary)") | Out-Null
    } elseif (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $audioReuseGateSummaryPath -PathType Leaf)) {
        $issues.Add("Missing audioReuseGateSummary: $($manifest.audioReuseGateSummary)") | Out-Null
    } elseif (Test-Path -LiteralPath $audioReuseGateSummaryPath -PathType Leaf) {
        $audioReuseGateSummary = Get-Content -LiteralPath $audioReuseGateSummaryPath -Raw | ConvertFrom-Json
    }
}

if ($null -ne $acceptance) {
    if ($acceptance.rootGate.status -ne 'Passed' -and [bool]$manifest.canStartGameplayMainline) {
        $issues.Add('Vertical slice manifest allows gameplay mainline while asset acceptance rootGate is not Passed.') | Out-Null
    }
    if ([bool]$acceptance.rootGate.canProceedGameplayMainline -ne [bool]$manifest.canStartGameplayMainline -and [bool]$manifest.canStartGameplayMainline) {
        $issues.Add('Vertical slice manifest allows gameplay mainline but asset acceptance manifest does not.') | Out-Null
    }
}
if ($null -ne $originalAssetReuseGateSummary -and [bool]$manifest.canStartGameplayMainline) {
    if (-not [bool]$originalAssetReuseGateSummary.canStartGameplayMainline) {
        $issues.Add('Vertical slice manifest allows gameplay mainline while original asset reuse gate summary does not.') | Out-Null
    }
    if ([string]$originalAssetReuseGateSummary.gateStatus -ne 'Passed') {
        $issues.Add("Vertical slice manifest allows gameplay mainline while original asset reuse gate status is '$($originalAssetReuseGateSummary.gateStatus)'.") | Out-Null
    }
}
if ($null -ne $controlledImportCandidateGateSummary -and [bool]$manifest.canStartGameplayMainline -and -not [bool]$controlledImportCandidateGateSummary.canClearCandidateBlockingStatus) {
    $issues.Add('Vertical slice manifest allows gameplay mainline while controlled import candidate gate has not cleared candidate blocking status.') | Out-Null
}
if ($null -ne $actorPrototypeControllerGateSummary -and [bool]$manifest.canStartGameplayMainline -and -not [bool]$actorPrototypeControllerGateSummary.canAcceptActorPrototypeControllers) {
    $issues.Add('Vertical slice manifest allows gameplay mainline while actor prototype controller gate has not accepted player/enemy actors.') | Out-Null
}
if ($null -ne $uiRewardPrototypeBuildGateSummary -and [bool]$manifest.canStartGameplayMainline -and -not [bool]$uiRewardPrototypeBuildGateSummary.canAcceptUiRewardPrototype) {
    $issues.Add('Vertical slice manifest allows gameplay mainline while rebuilt UI/reward prototype gate has not accepted reward/card visuals.') | Out-Null
}
if ($null -ne $environmentModuleGateSummary -and [bool]$manifest.canStartGameplayMainline -and -not [bool]$environmentModuleGateSummary.canAcceptEnvironmentModule) {
    $issues.Add('Vertical slice manifest allows gameplay mainline while environment module gate has not accepted room/map visuals.') | Out-Null
}
if ($null -ne $audioReuseGateSummary -and [bool]$manifest.canStartGameplayMainline -and -not [bool]$audioReuseGateSummary.canSatisfyMinimumAudio) {
    $issues.Add('Vertical slice manifest allows gameplay mainline while audio reuse gate has not accepted minimum combat audio.') | Out-Null
}

$requirements = @($manifest.minimumRequirements)
if ($requirements.Count -eq 0) {
    $issues.Add('Manifest has no minimumRequirements.') | Out-Null
}

$evidenceCount = 0
$missingEvidence = [System.Collections.Generic.List[string]]::new()
$blockingRequirements = [System.Collections.Generic.List[string]]::new()
foreach ($requirement in $requirements) {
    $id = [string]$requirement.id
    if ([string]::IsNullOrWhiteSpace($id)) {
        $issues.Add('A minimum requirement is missing id.') | Out-Null
    }

    $status = [string]$requirement.status
    if ($status -notin $validStatuses) {
        $issues.Add("Requirement '$id' has unsupported status '$status'.") | Out-Null
    }

    if ([bool]$requirement.requiredForGameplayMainline -and $status -in $blockingStatuses) {
        $blockingRequirements.Add(('{0}:{1}' -f $id, $status)) | Out-Null
    }

    foreach ($evidence in @($requirement.evidence)) {
        $evidenceText = [string]$evidence
        if ([string]::IsNullOrWhiteSpace($evidenceText)) {
            $issues.Add("Requirement '$id' contains an empty evidence path.") | Out-Null
            continue
        }

        $evidenceCount++
        $evidencePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $evidenceText
        if (-not (Test-IsPathUnderOrEqual -CandidatePath $evidencePath -RootPath $repoRoot)) {
            $issues.Add("Evidence for '$id' points outside repository root: $evidenceText") | Out-Null
            continue
        }

        if (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $evidencePath)) {
            $missingEvidence.Add("$id :: $evidenceText") | Out-Null
        }
    }
}

foreach ($missing in $missingEvidence) {
    $issues.Add("Missing evidence path: $missing") | Out-Null
}

if ([bool]$manifest.canStartGameplayMainline -and $blockingRequirements.Count -gt 0) {
    $issues.Add("Manifest allows gameplay mainline with blocking requirements: $($blockingRequirements -join ', ')") | Out-Null
}
if ($RequireGameplayReady -and -not [bool]$manifest.canStartGameplayMainline) {
    $issues.Add('RequireGameplayReady was set, but canStartGameplayMainline is false.') | Out-Null
}

$summary = [PSCustomObject]@{
    ManifestPath = $ManifestPath
    AssetAcceptanceManifest = $acceptancePath
    OriginalAssetReuseGate = $originalAssetReuseGatePath
    OriginalAssetReuseGateSummary = $originalAssetReuseGateSummaryPath
    OriginalAssetReuseGateStatus = if ($null -ne $originalAssetReuseGateSummary) { [string]$originalAssetReuseGateSummary.gateStatus } else { $null }
    ControlledImportCandidateGate = $controlledImportCandidateGatePath
    ControlledImportCandidateGateSummary = $controlledImportCandidateGateSummaryPath
    ControlledImportCandidateGateStatus = if ($null -ne $controlledImportCandidateGateSummary) { [string]$controlledImportCandidateGateSummary.gateStatus } else { $null }
    ActorPrototypeControllerGate = $actorPrototypeControllerGatePath
    ActorPrototypeControllerGateSummary = $actorPrototypeControllerGateSummaryPath
    ActorPrototypeControllerGateStatus = if ($null -ne $actorPrototypeControllerGateSummary) { [string]$actorPrototypeControllerGateSummary.gateStatus } else { $null }
    UiRewardPrototypeBuildGate = $uiRewardPrototypeBuildGatePath
    UiRewardPrototypeBuildGateSummary = $uiRewardPrototypeBuildGateSummaryPath
    UiRewardPrototypeBuildGateStatus = if ($null -ne $uiRewardPrototypeBuildGateSummary) { [string]$uiRewardPrototypeBuildGateSummary.gateStatus } else { $null }
    UiRewardPrototypeBuildGateCanAccept = if ($null -ne $uiRewardPrototypeBuildGateSummary) { [bool]$uiRewardPrototypeBuildGateSummary.canAcceptUiRewardPrototype } else { $false }
    EnvironmentModuleGate = $environmentModuleGatePath
    EnvironmentModuleGateSummary = $environmentModuleGateSummaryPath
    EnvironmentModuleGateStatus = if ($null -ne $environmentModuleGateSummary) { [string]$environmentModuleGateSummary.gateStatus } else { $null }
    EnvironmentModuleGateCanAccept = if ($null -ne $environmentModuleGateSummary) { [bool]$environmentModuleGateSummary.canAcceptEnvironmentModule } else { $false }
    AudioReuseGate = $audioReuseGatePath
    AudioReuseGateSummary = $audioReuseGateSummaryPath
    AudioReuseGateStatus = if ($null -ne $audioReuseGateSummary) { [string]$audioReuseGateSummary.gateStatus } else { $null }
    AudioReuseGateCanSatisfy = if ($null -ne $audioReuseGateSummary) { [bool]$audioReuseGateSummary.canSatisfyMinimumAudio } else { $false }
    ReadinessStatus = [string]$manifest.readinessStatus
    CanStartGameplayMainline = [bool]$manifest.canStartGameplayMainline
    RequirementCount = $requirements.Count
    BlockingRequirementCount = $blockingRequirements.Count
    BlockingRequirements = @($blockingRequirements)
    EvidenceCount = $evidenceCount
    MissingEvidenceCount = $missingEvidence.Count
    IssueCount = $issues.Count
    Issues = @($issues)
}

if ($issues.Count -gt 0) {
    $summary | ConvertTo-Json -Depth 6 | Write-Output
    throw "Minimum vertical slice asset validation failed with $($issues.Count) issue(s)."
}

$summary
