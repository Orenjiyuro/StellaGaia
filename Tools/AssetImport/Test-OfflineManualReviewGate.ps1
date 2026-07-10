[CmdletBinding()]
param(
    [string]$ValidationRoot,
    [string]$AudioReviewTsv,
    [string]$UiRewardReviewTsv,
    [string]$EnvironmentMaterialReviewTsv
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

function Get-ReviewValue {
    param([object]$Row)

    if ($null -eq $Row -or -not ($Row.PSObject.Properties.Name -contains 'review')) {
        return ''
    }

    return ([string]$Row.review).Trim()
}

function Test-ReviewPack {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $pathExists = Test-Path -LiteralPath $Path -PathType Leaf
    if (-not $pathExists) {
        $issues.Add("Missing review TSV for $Name`: $Path") | Out-Null
        return [PSCustomObject]@{
            name = $Name
            kind = $Kind
            path = $Path
            status = 'ManualReviewInputsMissing'
            totalRowCount = 0
            reviewedRowCount = 0
            notReviewedRowCount = 0
            acceptedRowCount = 0
            rejectedRowCount = 0
            unexpectedReviewCount = 0
            issueCount = $issues.Count
            issues = @($issues)
        }
    }

    $rows = @(Import-Csv -LiteralPath $Path -Delimiter "`t")
    $hasReviewColumn = $rows.Count -eq 0 -or ($rows[0].PSObject.Properties.Name -contains 'review')
    Add-IssueIf -Issues $issues -Condition (-not $hasReviewColumn) -Message "Review TSV for $Name has no 'review' column: $Path"

    $notReviewedCount = 0
    $acceptedCount = 0
    $rejectedCount = 0
    $unexpectedCount = 0
    $acceptedValues = @('Confirmed', 'Recognizable')
    $rejectedValues = @('Rejected', 'Unrecognizable')
    $pendingValues = @('', 'NotReviewed')
    $allowedValues = @($pendingValues + $acceptedValues + $rejectedValues)

    foreach ($row in $rows) {
        $review = Get-ReviewValue -Row $row
        if ($pendingValues -contains $review) {
            $notReviewedCount++
        } elseif ($acceptedValues -contains $review) {
            $acceptedCount++
        } elseif ($rejectedValues -contains $review) {
            $rejectedCount++
        } else {
            $unexpectedCount++
        }
    }

    Add-IssueIf -Issues $issues -Condition ($unexpectedCount -gt 0) -Message "$Name has $unexpectedCount unexpected review value(s). Allowed: $($allowedValues -join ', ')."

    $reviewedCount = [Math]::Max(0, $rows.Count - $notReviewedCount - $unexpectedCount)
    $status = 'ReadyForManualReview'
    if ($issues.Count -gt 0) {
        $status = 'ManualReviewInputInvalid'
    } elseif ($rows.Count -eq 0) {
        $status = 'ManualReviewInputEmpty'
    } elseif ($rejectedCount -gt 0) {
        $status = 'ManualReviewRejected'
    } elseif ($reviewedCount -eq 0) {
        $status = 'ReadyForManualReview'
    } elseif ($notReviewedCount -gt 0) {
        $status = 'ManualReviewInProgress'
    } else {
        $status = 'ManualReviewCompletedNeedsUnityValidation'
    }

    return [PSCustomObject]@{
        name = $Name
        kind = $Kind
        path = $Path
        status = $status
        totalRowCount = $rows.Count
        reviewedRowCount = $reviewedCount
        notReviewedRowCount = $notReviewedCount
        acceptedRowCount = $acceptedCount
        rejectedRowCount = $rejectedCount
        unexpectedReviewCount = $unexpectedCount
        issueCount = $issues.Count
        issues = @($issues)
    }
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Offline Manual Review Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Total rows | $($Summary.totalRowCount) |") | Out-Null
    $lines.Add("| Reviewed rows | $($Summary.reviewedRowCount) |") | Out-Null
    $lines.Add("| Not reviewed rows | $($Summary.notReviewedRowCount) |") | Out-Null
    $lines.Add("| Accepted rows | $($Summary.acceptedRowCount) |") | Out-Null
    $lines.Add("| Rejected rows | $($Summary.rejectedRowCount) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add("| Can satisfy development usability | $($Summary.canSatisfyDevelopmentUsability) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Packs') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Pack | Status | Rows | Reviewed | Not reviewed | Accepted | Rejected |') | Out-Null
    $lines.Add('| --- | --- | ---: | ---: | ---: | ---: | ---: |') | Out-Null
    foreach ($pack in $Summary.packs) {
        $lines.Add("| $($pack.name) | $($pack.status) | $($pack.totalRowCount) | $($pack.reviewedRowCount) | $($pack.notReviewedRowCount) | $($pack.acceptedRowCount) | $($pack.rejectedRowCount) |") | Out-Null
    }
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
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\OfflineManualReviewGate'
}
if ([string]::IsNullOrWhiteSpace($AudioReviewTsv)) {
    $AudioReviewTsv = Join-Path $extractedRoot 'Validation\MinimumAudioAuditionPack\minimum-audio-listening-review.tsv'
}
if ([string]::IsNullOrWhiteSpace($UiRewardReviewTsv)) {
    $UiRewardReviewTsv = Join-Path $extractedRoot 'Validation\MinimumUiRewardVisualReviewPack\minimum-ui-reward-visual-review.tsv'
}
if ([string]::IsNullOrWhiteSpace($EnvironmentMaterialReviewTsv)) {
    $EnvironmentMaterialReviewTsv = Join-Path $extractedRoot 'Validation\EnvironmentModuleMaterialReviewPack\Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04\environment-module-material-review.tsv'
}

$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$AudioReviewTsv = Resolve-RepoPath -RepoRoot $repoRoot -Path $AudioReviewTsv
$UiRewardReviewTsv = Resolve-RepoPath -RepoRoot $repoRoot -Path $UiRewardReviewTsv
$EnvironmentMaterialReviewTsv = Resolve-RepoPath -RepoRoot $repoRoot -Path $EnvironmentMaterialReviewTsv

Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
Assert-PathUnderOrEqual -Path $AudioReviewTsv -RootPath $extractedRoot -Description 'AudioReviewTsv'
Assert-PathUnderOrEqual -Path $UiRewardReviewTsv -RootPath $extractedRoot -Description 'UiRewardReviewTsv'
Assert-PathUnderOrEqual -Path $EnvironmentMaterialReviewTsv -RootPath $extractedRoot -Description 'EnvironmentMaterialReviewTsv'
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'
Assert-PathNotUnder -Path $AudioReviewTsv -RootPath $sourceInstall -Description 'AudioReviewTsv'
Assert-PathNotUnder -Path $UiRewardReviewTsv -RootPath $sourceInstall -Description 'UiRewardReviewTsv'
Assert-PathNotUnder -Path $EnvironmentMaterialReviewTsv -RootPath $sourceInstall -Description 'EnvironmentMaterialReviewTsv'

New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null

$packs = @(
    (Test-ReviewPack -Name 'MinimumAudioAudition' -Kind 'AudioListening' -Path $AudioReviewTsv),
    (Test-ReviewPack -Name 'MinimumUiRewardVisual' -Kind 'VisualFidelity' -Path $UiRewardReviewTsv),
    (Test-ReviewPack -Name 'EnvironmentModuleMaterial' -Kind 'MaterialFidelity' -Path $EnvironmentMaterialReviewTsv)
)

$issues = [System.Collections.Generic.List[string]]::new()
foreach ($pack in $packs) {
    foreach ($issue in @($pack.issues)) {
        $issues.Add("$($pack.name): $issue") | Out-Null
    }
}

$totalRows = 0
$reviewedRows = 0
$notReviewedRows = 0
$acceptedRows = 0
$rejectedRows = 0
$unexpectedRows = 0
foreach ($pack in $packs) {
    $totalRows += [int]$pack.totalRowCount
    $reviewedRows += [int]$pack.reviewedRowCount
    $notReviewedRows += [int]$pack.notReviewedRowCount
    $acceptedRows += [int]$pack.acceptedRowCount
    $rejectedRows += [int]$pack.rejectedRowCount
    $unexpectedRows += [int]$pack.unexpectedReviewCount
}

$gateStatus = 'ReadyForManualReview'
$nextRequiredAction = 'Fill the offline review TSVs, then run Unity focused validation before accepting any asset as development-usable.'
if ($issues.Count -gt 0) {
    $gateStatus = 'ManualReviewInputsInvalid'
    $nextRequiredAction = 'Regenerate or fix the missing/invalid review TSVs before manual review.'
} elseif ($totalRows -eq 0) {
    $gateStatus = 'ManualReviewInputsEmpty'
    $nextRequiredAction = 'Regenerate the audio, UI/reward, and environment review packs; empty TSVs cannot support reuse decisions.'
} elseif ($rejectedRows -gt 0) {
    $gateStatus = 'ManualReviewRejected'
    $nextRequiredAction = 'Replace or repair rejected candidates; do not move rejected assets toward gameplay integration.'
} elseif ($reviewedRows -eq 0) {
    $gateStatus = 'ReadyForManualReview'
    $nextRequiredAction = 'Review the generated HTML packs and fill the TSV review columns. This still will not replace Unity render/playback validation.'
} elseif ($notReviewedRows -gt 0) {
    $gateStatus = 'ManualReviewInProgress'
    $nextRequiredAction = 'Finish all NotReviewed rows, then run focused Unity gates for render/playback proof.'
} else {
    $gateStatus = 'ManualReviewCompletedNeedsUnityValidation'
    $nextRequiredAction = 'Run focused Unity gates. Manual review can only screen candidates; it cannot prove Unity development usability.'
}

$summaryJson = Join-Path $ValidationRoot 'offline-manual-review-gate-summary.json'
$reportPath = Join-Path $ValidationRoot 'offline-manual-review-gate-report.md'
$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    validationRoot = $ValidationRoot
    gateStatus = $gateStatus
    totalRowCount = $totalRows
    reviewedRowCount = $reviewedRows
    notReviewedRowCount = $notReviewedRows
    acceptedRowCount = $acceptedRows
    rejectedRowCount = $rejectedRows
    unexpectedReviewCount = $unexpectedRows
    issueCount = $issues.Count
    issues = @($issues)
    packs = @($packs)
    summaryJson = $summaryJson
    reportPath = $reportPath
    canSatisfyDevelopmentUsability = $false
    interpretation = 'Offline manual review can confirm that previewed candidates are recognizable or listenable enough to keep testing. It is not Unity import, render, playback, dependency closure, or gameplay usability evidence.'
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Offline manual review gate has $($issues.Count) issue(s)."
}
