[CmdletBinding()]
param(
    [string]$ManifestPath,
    [switch]$AllowMissingEvidence
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

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\asset-acceptance-manifest.json'
}

$ManifestPath = Get-CanonicalPath $ManifestPath
if (-not (Test-IsPathUnderOrEqual -CandidatePath $ManifestPath -RootPath $repoRoot)) {
    throw "ManifestPath must stay under repository root. Got: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing asset acceptance manifest: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$issues = [System.Collections.Generic.List[string]]::new()
$validStatuses = @(
    'AssetLocated',
    'ExtractedReadable',
    'CrossToolVerified',
    'SemanticContextRecovered',
    'UnityImportCandidate',
    'ReconstructedPrototypeAsset',
    'PendingExport',
    'ExportedWithMissingDependencies',
    'VisibleBroken',
    'RepairCandidate',
    'DevelopmentUsable',
    'Rejected',
    'NotUsableYet',
    'UsableWithKnownIssues',
    'SelectedNeedsUnityPlaybackValidation',
    'SelectedNeedsUnityVisibleValidation'
)

if ([string]::IsNullOrWhiteSpace([string]$manifest.sourceInstall)) {
    $issues.Add('Manifest is missing sourceInstall.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.extractWorkspace)) {
    $issues.Add('Manifest is missing extractWorkspace.') | Out-Null
}
if ($null -eq $manifest.rootGate) {
    $issues.Add('Manifest is missing rootGate.') | Out-Null
} else {
    if ([string]::IsNullOrWhiteSpace([string]$manifest.rootGate.status)) {
        $issues.Add('rootGate.status is missing.') | Out-Null
    }
    if ($manifest.rootGate.status -eq 'NotPassed' -and [bool]$manifest.rootGate.canProceedGameplayMainline) {
        $issues.Add('rootGate is NotPassed but canProceedGameplayMainline is true.') | Out-Null
    }
    if ($manifest.rootGate.status -eq 'Passed' -and -not [bool]$manifest.rootGate.canProceedGameplayMainline) {
        $issues.Add('rootGate is Passed but canProceedGameplayMainline is false.') | Out-Null
    }
}

$categories = @($manifest.categories)
if ($categories.Count -eq 0) {
    $issues.Add('Manifest has no categories.') | Out-Null
}

$evidenceCount = 0
$missingEvidence = [System.Collections.Generic.List[string]]::new()
$originalAssetReuseGateSummary = $null
$rootGateEvidenceLeafNames = [System.Collections.Generic.List[string]]::new()
if ($null -ne $manifest.rootGate) {
    $rootGateEvidence = @($manifest.rootGate.evidence)
    if ($rootGateEvidence.Count -eq 0) {
        $issues.Add('rootGate.evidence is missing.') | Out-Null
    }

    foreach ($evidence in $rootGateEvidence) {
        $evidenceText = [string]$evidence
        if ([string]::IsNullOrWhiteSpace($evidenceText)) {
            $issues.Add('rootGate contains an empty evidence path.') | Out-Null
            continue
        }

        $evidenceCount++
        $evidencePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $evidenceText
        if (-not (Test-IsPathUnderOrEqual -CandidatePath $evidencePath -RootPath $repoRoot)) {
            $issues.Add("rootGate evidence points outside repository root: $evidenceText") | Out-Null
            continue
        }
        $rootGateEvidenceLeafNames.Add((Split-Path -Leaf $evidencePath)) | Out-Null

        if (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $evidencePath)) {
            $missingEvidence.Add("rootGate :: $evidenceText") | Out-Null
        } elseif ((Split-Path -Leaf $evidencePath) -eq 'original-asset-reuse-gate-summary.json' -and (Test-Path -LiteralPath $evidencePath -PathType Leaf)) {
            $originalAssetReuseGateSummary = Read-JsonFile -Path $evidencePath
        }
    }

    if ('original-asset-reuse-gate-summary.json' -notin $rootGateEvidenceLeafNames) {
        $issues.Add('rootGate.evidence must include original-asset-reuse-gate-summary.json.') | Out-Null
    }
    if ('original-asset-reuse-gate-report.md' -notin $rootGateEvidenceLeafNames) {
        $issues.Add('rootGate.evidence must include original-asset-reuse-gate-report.md.') | Out-Null
    }
}
$categoryEvidencePaths = @{}
foreach ($category in $categories) {
    $categoryName = [string]$category.category
    if ([string]::IsNullOrWhiteSpace($categoryName)) {
        $issues.Add('A category entry is missing category name.') | Out-Null
    }

    $status = [string]$category.status
    if ($status -notin $validStatuses) {
        $issues.Add("Category '$categoryName' has unsupported status '$status'.") | Out-Null
    }

    $resolvedEvidencePaths = [System.Collections.Generic.List[string]]::new()
    foreach ($evidence in @($category.evidence)) {
        $evidenceText = [string]$evidence
        if ([string]::IsNullOrWhiteSpace($evidenceText)) {
            $issues.Add("Category '$categoryName' contains an empty evidence path.") | Out-Null
            continue
        }

        $evidenceCount++
        $evidencePath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $evidenceText
        if (-not (Test-IsPathUnderOrEqual -CandidatePath $evidencePath -RootPath $repoRoot)) {
            $issues.Add("Evidence for '$categoryName' points outside repository root: $evidenceText") | Out-Null
            continue
        }
        $resolvedEvidencePaths.Add($evidencePath) | Out-Null

        if (-not $AllowMissingEvidence -and -not (Test-Path -LiteralPath $evidencePath)) {
            $missingEvidence.Add("$categoryName :: $evidenceText") | Out-Null
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($categoryName)) {
        $categoryEvidencePaths[$categoryName] = @($resolvedEvidencePaths)
    }
}

foreach ($missing in $missingEvidence) {
    $issues.Add("Missing evidence path: $missing") | Out-Null
}

$environment = @($categories | Where-Object { $_.category -eq 'EnvironmentArt' } | Select-Object -First 1)
if ($environment.Count -eq 0) {
    $issues.Add('Manifest is missing EnvironmentArt category.') | Out-Null
} elseif ([string]$environment[0].status -eq 'DevelopmentUsable' -and $manifest.rootGate.status -ne 'Passed') {
    $issues.Add('EnvironmentArt is DevelopmentUsable but rootGate is not Passed.') | Out-Null
}
foreach ($category in @($categories | Where-Object { [string]$_.status -eq 'DevelopmentUsable' })) {
    $categoryName = [string]$category.category
    $paths = @($categoryEvidencePaths[$categoryName])
    switch ($categoryName) {
        'EnvironmentArt' {
            $gateSummaryPath = @($paths | Where-Object { (Split-Path -Leaf $_) -eq 'environment-module-reuse-gate-summary.json' } | Select-Object -First 1)
            if ($gateSummaryPath.Count -eq 0) {
                $issues.Add('EnvironmentArt is DevelopmentUsable but lacks environment-module-reuse-gate-summary.json evidence.') | Out-Null
            } else {
                $gateSummary = Read-JsonFile -Path $gateSummaryPath[0]
                if ($null -eq $gateSummary -or -not [bool]$gateSummary.canAcceptEnvironmentModule) {
                    $issues.Add('EnvironmentArt is DevelopmentUsable but its environment module gate summary does not accept the module.') | Out-Null
                }
            }
        }
        'UiOrItemArt' {
            $gateSummaryPath = @($paths | Where-Object { (Split-Path -Leaf $_) -eq 'ui-reward-reuse-gate-summary.json' } | Select-Object -First 1)
            if ($gateSummaryPath.Count -eq 0) {
                $issues.Add('UiOrItemArt is DevelopmentUsable but lacks ui-reward-reuse-gate-summary.json evidence.') | Out-Null
            } else {
                $gateSummary = Read-JsonFile -Path $gateSummaryPath[0]
                if ($null -eq $gateSummary -or -not [bool]$gateSummary.canSatisfyMinimumUiRewardArt) {
                    $issues.Add('UiOrItemArt is DevelopmentUsable but its UI/reward gate summary does not accept the selected art.') | Out-Null
                }
            }
        }
        'DecodedAudioCollection' {
            $gateSummaryPath = @($paths | Where-Object { (Split-Path -Leaf $_) -eq 'audio-reuse-gate-summary.json' } | Select-Object -First 1)
            if ($gateSummaryPath.Count -eq 0) {
                $issues.Add('DecodedAudioCollection is DevelopmentUsable but lacks audio-reuse-gate-summary.json evidence.') | Out-Null
            } else {
                $gateSummary = Read-JsonFile -Path $gateSummaryPath[0]
                if ($null -eq $gateSummary -or -not [bool]$gateSummary.canSatisfyMinimumAudio) {
                    $issues.Add('DecodedAudioCollection is DevelopmentUsable but its audio gate summary does not accept the selected audio.') | Out-Null
                }
            }
        }
        default {
            $hasValidationJson = @($paths | Where-Object { (Split-Path -Leaf $_) -eq 'validation.json' }).Count -gt 0
            $hasScreenshot = @($paths | Where-Object { [System.IO.Path]::GetExtension($_).Equals('.png', [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
            if (-not $hasValidationJson) {
                $issues.Add("Category '$categoryName' is DevelopmentUsable but lacks validation.json evidence.") | Out-Null
            }
            if (-not $hasScreenshot) {
                $issues.Add("Category '$categoryName' is DevelopmentUsable but lacks screenshot evidence.") | Out-Null
            }
        }
    }
}
if ($null -ne $originalAssetReuseGateSummary -and [bool]$manifest.rootGate.canProceedGameplayMainline) {
    if (-not [bool]$originalAssetReuseGateSummary.canStartGameplayMainline) {
        $issues.Add('rootGate allows gameplay mainline while original asset reuse gate summary does not.') | Out-Null
    }
    if ([string]$originalAssetReuseGateSummary.gateStatus -ne 'Passed') {
        $issues.Add("rootGate allows gameplay mainline while original asset reuse gate status is '$($originalAssetReuseGateSummary.gateStatus)'.") | Out-Null
    }
}

$summary = [PSCustomObject]@{
    ManifestPath = $ManifestPath
    RootGateStatus = [string]$manifest.rootGate.status
    OriginalAssetReuseGateStatus = if ($null -ne $originalAssetReuseGateSummary) { [string]$originalAssetReuseGateSummary.gateStatus } else { $null }
    CanProceedGameplayMainline = [bool]$manifest.rootGate.canProceedGameplayMainline
    CategoryCount = $categories.Count
    EvidenceCount = $evidenceCount
    MissingEvidenceCount = $missingEvidence.Count
    IssueCount = $issues.Count
    Issues = @($issues)
}

if ($issues.Count -gt 0) {
    $summary | ConvertTo-Json -Depth 5 | Write-Output
    throw "Asset acceptance manifest validation failed with $($issues.Count) issue(s)."
}

$summary
