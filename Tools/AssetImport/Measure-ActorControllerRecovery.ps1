[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$OutputRoot
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

function Get-OverrideControllerInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $controllerGuid = ''
    $controllerLine = Select-String -LiteralPath $Path -Pattern 'm_Controller: \{fileID: 9300000, guid: ([0-9a-f]{32}), type: 2\}' -List
    if ($null -ne $controllerLine) {
        $controllerGuid = $controllerLine.Matches.Groups[1].Value
    }

    $deadbeefRefs = @(Select-String -LiteralPath $Path -Pattern 'deadbeef|deadf00d' -AllMatches)

    return [PSCustomObject]@{
        path = $Path
        controllerGuid = $controllerGuid
        controllerDeadbeef = ($controllerGuid -match 'deadbeef|deadf00d')
        deadbeefReferenceCount = ($deadbeefRefs | ForEach-Object { $_.Matches.Count } | Measure-Object -Sum).Sum
    }
}

function Get-MaterialPlaceholderSlots {
    param([Parameter(Mandatory = $true)][string]$Path)

    $slots = [System.Collections.Generic.List[string]]::new()
    $currentSlot = ''
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s+- (_[^:]+):\s*$') {
            $currentSlot = $Matches[1]
        } elseif ($line -match 'deadbeef|deadf00d') {
            if ([string]::IsNullOrWhiteSpace($currentSlot)) {
                $slots.Add('(unknown)') | Out-Null
            } else {
                $slots.Add($currentSlot) | Out-Null
            }
        }
    }

    return @($slots | Sort-Object -Unique)
}

function Write-MarkdownReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Actor Controller Recovery') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Candidate count | $($Summary.candidateCount) |") | Out-Null
    $lines.Add("| Recoverable candidate count | $($Summary.recoverableCandidateCount) |") | Out-Null
    $lines.Add("| Generated at | $($Summary.generatedAt) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Candidates') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Source category | Local controllers | Override controllers | Controller placeholders | Material placeholder files | Decision |') | Out-Null
    $lines.Add('| --- | --- | ---: | ---: | ---: | ---: | --- |') | Out-Null
    foreach ($candidate in $Summary.candidates) {
        $lines.Add("| $($candidate.id) | $($candidate.sourceCategory) | $($candidate.localControllerCount) | $($candidate.localOverrideControllerCount) | $($candidate.localOverrideControllerPlaceholderCount) | $($candidate.materialPlaceholderFileCount) | $($candidate.recoveryDecision) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Notes') | Out-Null
    $lines.Add('') | Out-Null
    foreach ($candidate in $Summary.candidates) {
        $candidateId = [string]$candidate.id
        $candidateNote = [string]$candidate.note
        $lines.Add(("- `{0}`: {1}" -f $candidateId, $candidateNote)) | Out-Null
    }

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-vertical-slice-assets.json'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\ActorControllerRecovery'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot
Assert-PathUnderOrEqual -Path $ManifestPath -Root $repoRoot -Label 'ManifestPath'
Assert-PathUnderOrEqual -Path $OutputRoot -Root $extractedRoot -Label 'OutputRoot'

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
if ($null -eq $manifest) {
    throw "Could not read manifest: $ManifestPath"
}

$candidateRows = [System.Collections.Generic.List[object]]::new()
$actorRequirements = @($manifest.minimumRequirements | Where-Object {
    [string]$_.id -in @('player_character', 'enemy')
})

foreach ($requirement in $actorRequirements) {
    $id = [string]$requirement.id
    $sourceCategory = [string]$requirement.sourceCategory
    $validationPath = ''
    foreach ($evidence in @($requirement.evidence)) {
        $resolved = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$evidence)
        if ((Split-Path -Leaf $resolved) -eq 'validation.json') {
            $validationPath = $resolved
            break
        }
    }

    $projectPath = ''
    $sourceAssetPath = ''
    if (-not [string]::IsNullOrWhiteSpace($validationPath) -and (Test-Path -LiteralPath $validationPath -PathType Leaf)) {
        $validation = Read-JsonFile -Path $validationPath
        $projectPath = Get-CanonicalPath ([string]$validation.projectPath)
        $candidateText = ([string]$requirement.candidate).Replace('\', '/')
        $candidateLeaf = Split-Path -Leaf $candidateText
        foreach ($sample in @($validation.samples)) {
            $samplePath = ([string]$sample.path).Replace('\', '/')
            if ($samplePath.Equals($candidateText, [System.StringComparison]::OrdinalIgnoreCase) -or
                $samplePath.EndsWith('/' + $candidateText, [System.StringComparison]::OrdinalIgnoreCase) -or
                $samplePath.EndsWith('/' + $candidateLeaf, [System.StringComparison]::OrdinalIgnoreCase)) {
                $sourceAssetPath = $samplePath
                break
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($projectPath) -or [string]::IsNullOrWhiteSpace($sourceAssetPath)) {
        $candidateRows.Add([PSCustomObject]@{
            id = $id
            sourceCategory = $sourceCategory
            projectPath = $projectPath
            sourceAssetPath = $sourceAssetPath
            localControllerCount = 0
            localOverrideControllerCount = 0
            localOverrideControllerPlaceholderCount = 0
            projectOverrideControllerCount = 0
            projectOverrideControllerPlaceholderCount = 0
            materialPlaceholderFileCount = 0
            materialPlaceholderSlots = @()
            recoveryDecision = 'BlockedMissingEvidence'
            note = 'Could not resolve validation project path or source asset path.'
        }) | Out-Null
        continue
    }

    Assert-PathUnderOrEqual -Path $projectPath -Root $extractedRoot -Label "ProjectPath '$id'"
    $sourceFolder = Get-CanonicalPath (Split-Path -Parent (Join-Path $projectPath $sourceAssetPath))
    $actorRoot = $sourceFolder
    while ((Split-Path -Leaf $actorRoot) -notin @('14401', '10001tuboshu') -and (Test-IsPathUnderOrEqual -CandidatePath $actorRoot -RootPath $projectPath)) {
        $parent = Split-Path -Parent $actorRoot
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $actorRoot) {
            break
        }
        $actorRoot = $parent
    }

    $localControllers = @(Get-ChildItem -LiteralPath $actorRoot -Recurse -File -Filter '*.controller' -ErrorAction SilentlyContinue)
    $localOverrideControllers = @(Get-ChildItem -LiteralPath $actorRoot -Recurse -File -Filter '*.overrideController' -ErrorAction SilentlyContinue)
    $projectOverrideControllers = @(Get-ChildItem -LiteralPath (Join-Path $projectPath 'Assets') -Recurse -File -Filter '*.overrideController' -ErrorAction SilentlyContinue)

    $localOverrideInfo = @($localOverrideControllers | ForEach-Object { Get-OverrideControllerInfo -Path $_.FullName })
    $projectOverrideInfo = @($projectOverrideControllers | ForEach-Object { Get-OverrideControllerInfo -Path $_.FullName })

    $materialFiles = @(Get-ChildItem -LiteralPath $actorRoot -Recurse -File -Filter '*.mat' -ErrorAction SilentlyContinue)
    $materialPlaceholderFiles = [System.Collections.Generic.List[string]]::new()
    $materialPlaceholderSlots = [System.Collections.Generic.List[string]]::new()
    foreach ($materialFile in $materialFiles) {
        $slots = @(Get-MaterialPlaceholderSlots -Path $materialFile.FullName)
        if ($slots.Count -gt 0) {
            $materialPlaceholderFiles.Add($materialFile.FullName.Substring($projectPath.Length + 1)) | Out-Null
            foreach ($slot in $slots) {
                $materialPlaceholderSlots.Add($slot) | Out-Null
            }
        }
    }

    $localOverridePlaceholderCount = @($localOverrideInfo | Where-Object { [bool]$_.controllerDeadbeef -or [int]$_.deadbeefReferenceCount -gt 0 }).Count
    $projectOverridePlaceholderCount = @($projectOverrideInfo | Where-Object { [bool]$_.controllerDeadbeef }).Count
    $projectOverrideCount = $projectOverrideInfo.Count
    $allProjectOverridesUsePlaceholderController = ($projectOverrideCount -gt 0 -and $projectOverridePlaceholderCount -eq $projectOverrideCount)

    $decision = 'RepairCandidateStaticOnly'
    $note = 'Actor has readable model/material/animation assets, but Animator Override Controller base controller/original clip placeholders prevent normal animated staging.'
    if ($localOverrideControllers.Count -eq 0) {
        $decision = 'RepairCandidateNoOverrideController'
        $note = 'No local override controller was found under the actor root; use direct animation clips or build a new controller.'
    } elseif ($localOverridePlaceholderCount -eq 0) {
        $decision = 'PotentiallyRecoverableWithExistingController'
        $note = 'Local override controllers have no placeholder controller refs; verify Unity import before staging.'
    } elseif ($allProjectOverridesUsePlaceholderController) {
        $decision = 'BlockedSystemicOverrideControllerPlaceholder'
        $note = 'Every scanned Animator Override Controller in the category uses a placeholder base controller ref, so this is likely a systemic AssetRipper export limitation rather than a single missing local controller.'
    }

    $candidateRows.Add([PSCustomObject]@{
        id = $id
        sourceCategory = $sourceCategory
        projectPath = $projectPath
        actorRoot = $actorRoot
        sourceAssetPath = $sourceAssetPath
        localControllerCount = $localControllers.Count
        localOverrideControllerCount = $localOverrideControllers.Count
        localOverrideControllerPlaceholderCount = $localOverridePlaceholderCount
        projectOverrideControllerCount = $projectOverrideCount
        projectOverrideControllerPlaceholderCount = $projectOverridePlaceholderCount
        allProjectOverridesUsePlaceholderController = $allProjectOverridesUsePlaceholderController
        materialPlaceholderFileCount = $materialPlaceholderFiles.Count
        materialPlaceholderFiles = @($materialPlaceholderFiles)
        materialPlaceholderSlots = @($materialPlaceholderSlots | Sort-Object -Unique)
        recoveryDecision = $decision
        note = $note
    }) | Out-Null
}

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    outputRoot = $OutputRoot
    candidateCount = $candidateRows.Count
    recoverableCandidateCount = @($candidateRows | Where-Object { [string]$_.recoveryDecision -eq 'PotentiallyRecoverableWithExistingController' }).Count
    candidates = @($candidateRows)
}

$summaryJson = Join-Path $OutputRoot 'actor-controller-recovery-summary.json'
$reportPath = Join-Path $OutputRoot 'actor-controller-recovery-report.md'
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-MarkdownReport -Summary $summary -Path $reportPath

$summary
