[CmdletBinding()]
param(
    [string]$PlanDirectory,
    [string]$OutputRoot,
    [string[]]$CandidateId,
    [switch]$Apply
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

function Test-IsExtractedWorkspacePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = Get-CanonicalPath $Path
    if (Test-IsPathUnderOrEqual -CandidatePath $full -RootPath $extractedRoot) {
        return $true
    }

    return $full -match '(?i)(^|[\\/])Extracted([\\/]|$)'
}

function Assert-SafeAssetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '^Assets[/\\].+') {
        throw "Asset path must start with Assets/: $Path"
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        throw "Asset path must not be rooted: $Path"
    }
    foreach ($segment in ($Path -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Asset path contains an unsafe segment: $Path"
        }
    }
}

function Convert-ToSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $safe = $Value -replace '[^A-Za-z0-9_.-]', '_'
    if ([string]::IsNullOrWhiteSpace($safe)) {
        return 'default'
    }

    return $safe
}

function Convert-ToTargetDependencyPath {
    param(
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$SourceAssetPath
    )

    $safeCandidate = Convert-ToSafeFileName -Value $Candidate
    $relative = $SourceAssetPath.Replace('\', '/')
    Assert-SafeAssetPath -Path $relative
    return "Assets/StellaGaia/Imported/ControlledCandidates/$safeCandidate/Dependencies/$relative"
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$MetaPath)

    if (-not (Test-Path -LiteralPath $MetaPath -PathType Leaf)) {
        return ''
    }

    $line = Select-String -LiteralPath $MetaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $line) {
        return ''
    }

    return $line.Matches.Groups[1].Value
}

function Test-SameFileContent {
    param(
        [Parameter(Mandatory = $true)][string]$LeftPath,
        [Parameter(Mandatory = $true)][string]$RightPath
    )

    if (-not (Test-Path -LiteralPath $LeftPath -PathType Leaf) -or -not (Test-Path -LiteralPath $RightPath -PathType Leaf)) {
        return $false
    }

    $left = Get-Item -LiteralPath $LeftPath
    $right = Get-Item -LiteralPath $RightPath
    if ($left.Length -ne $right.Length) {
        return $false
    }

    $leftHash = (Get-FileHash -LiteralPath $LeftPath -Algorithm SHA256).Hash
    $rightHash = (Get-FileHash -LiteralPath $RightPath -Algorithm SHA256).Hash
    return $leftHash.Equals($rightHash, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ExistingProjectGuidIndex {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $index = @{}
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $index
    }

    foreach ($metaFile in Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.meta' -ErrorAction SilentlyContinue) {
        $guid = Get-MetaGuid -MetaPath $metaFile.FullName
        if ([string]::IsNullOrWhiteSpace($guid)) {
            continue
        }

        if (-not $index.ContainsKey($guid)) {
            $index[$guid] = [System.Collections.Generic.List[string]]::new()
        }
        $index[$guid].Add((Get-CanonicalPath $metaFile.FullName)) | Out-Null
    }

    return $index
}

function Copy-AssetWithMeta {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $TargetPath) | Out-Null
    Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force

    $sourceMeta = "$SourcePath.meta"
    if (Test-Path -LiteralPath $sourceMeta -PathType Leaf) {
        Copy-Item -LiteralPath $sourceMeta -Destination "$TargetPath.meta" -Force
    }
}

function Read-CandidateSelections {
    param([Parameter(Mandatory = $true)][string]$Path)

    $rows = [System.Collections.Generic.List[object]]::new()
    $lines = Get-Content -LiteralPath $Path
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $parts = $line.Split("`t")
        if ($parts.Count -lt 4) {
            continue
        }

        $rows.Add([PSCustomObject]@{
            Id = $parts[0]
            SourceCategory = $parts[1]
            SourceCandidate = $parts[2].Replace('\', '/')
            ControlledImportPath = $parts[3].Replace('\', '/')
        }) | Out-Null
    }

    return @($rows)
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$assetsRoot = Get-CanonicalPath (Join-Path $repoRoot 'Assets')
$controlledCandidatesRoot = Get-CanonicalPath (Join-Path $assetsRoot 'StellaGaia\Imported\ControlledCandidates')
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($PlanDirectory)) {
    $PlanDirectory = Join-Path $extractedRoot 'Validation\ControlledImportCandidateGate'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\ControlledImportCopy'
}

$PlanDirectory = Resolve-RepoPath -RepoRoot $repoRoot -Path $PlanDirectory
$OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot
Assert-PathUnderOrEqual -Path $PlanDirectory -Root $extractedRoot -Label 'PlanDirectory'
Assert-PathUnderOrEqual -Path $OutputRoot -Root $extractedRoot -Label 'OutputRoot'
Assert-PathNotUnder -Path $PlanDirectory -Root $sourceInstall -Label 'PlanDirectory'
Assert-PathNotUnder -Path $OutputRoot -Root $sourceInstall -Label 'OutputRoot'

$candidateListPath = Join-Path $PlanDirectory 'controlled-import-candidates.tsv'
$copyPlanPath = Join-Path $PlanDirectory 'controlled-import-copy-plan-assets.csv'
if (-not (Test-Path -LiteralPath $candidateListPath -PathType Leaf)) {
    throw "Missing candidate list: $candidateListPath"
}
if (-not (Test-Path -LiteralPath $copyPlanPath -PathType Leaf)) {
    throw "Missing copy plan asset CSV: $copyPlanPath"
}

$candidateFilter = @($CandidateId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$selections = @{}
foreach ($selection in Read-CandidateSelections -Path $candidateListPath) {
    if ($candidateFilter.Count -gt 0 -and [string]$selection.Id -notin $candidateFilter) {
        continue
    }

    Assert-SafeAssetPath -Path ([string]$selection.ControlledImportPath)
    $targetFullPath = Join-Path $repoRoot ([string]$selection.ControlledImportPath)
    Assert-PathUnderOrEqual -Path $targetFullPath -Root $controlledCandidatesRoot -Label "ControlledImportPath '$($selection.Id)'"
    $selections[[string]$selection.Id] = $selection
}

if ($selections.Count -eq 0) {
    throw 'No controlled import candidates selected.'
}

$planName = Convert-ToSafeFileName -Value ((Split-Path -Leaf $PlanDirectory) + '-' + ($(if ($candidateFilter.Count -eq 0) { 'all' } else { $candidateFilter -join '_' })))
$outputDir = Join-Path $OutputRoot $planName
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$issues = [System.Collections.Generic.List[string]]::new()
$planRows = [System.Collections.Generic.List[object]]::new()
$guidTargets = @{}
$targetSources = @{}
$existingProjectGuidIndex = Get-ExistingProjectGuidIndex -RootPath $assetsRoot
$missingSourceCount = 0
$missingMetaGuidCount = 0
$duplicateGuidCount = 0
$targetCollisionCount = 0
$projectGuidConflictCount = 0
$existingTargetFileCount = 0
$existingTargetMetaCount = 0
$targetOverwriteRiskCount = 0
$copyRows = @(Import-Csv -LiteralPath $copyPlanPath)
foreach ($row in $copyRows) {
    $candidate = [string]$row.CandidateId
    if (-not $selections.ContainsKey($candidate)) {
        continue
    }

    $selection = $selections[$candidate]
    $sourceProjectPath = Get-CanonicalPath ([string]$row.SourceProjectPath)
    $sourceAssetPath = ([string]$row.SourceAssetPath).Replace('\', '/')
    Assert-SafeAssetPath -Path $sourceAssetPath

    if (-not (Test-IsExtractedWorkspacePath -Path $sourceProjectPath)) {
        $issues.Add("Source project for '$candidate' is outside an Extracted workspace: $sourceProjectPath") | Out-Null
        continue
    }
    if ((Test-Path -LiteralPath $sourceInstall) -and (Test-IsPathUnderOrEqual -CandidatePath $sourceProjectPath -RootPath $sourceInstall)) {
        $issues.Add("Source project for '$candidate' is under source install: $sourceProjectPath") | Out-Null
        continue
    }

    $sourceFullPath = Join-Path $sourceProjectPath $sourceAssetPath
    if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Leaf)) {
        $issues.Add("Missing source asset for '$candidate': $sourceFullPath") | Out-Null
        $missingSourceCount += 1
        continue
    }

    $isRoot = $sourceAssetPath.Equals(([string]$selection.SourceCandidate), [System.StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $sourceAssetPath).Equals((Split-Path -Leaf ([string]$selection.SourceCandidate)), [System.StringComparison]::OrdinalIgnoreCase)
    $targetAssetPath = if ($isRoot) { [string]$selection.ControlledImportPath } else { Convert-ToTargetDependencyPath -Candidate $candidate -SourceAssetPath $sourceAssetPath }
    Assert-SafeAssetPath -Path $targetAssetPath
    $targetFullPath = Join-Path $repoRoot $targetAssetPath
    Assert-PathUnderOrEqual -Path $targetFullPath -Root $controlledCandidatesRoot -Label "Target asset '$candidate'"

    if ($targetSources.ContainsKey($targetAssetPath) -and [string]$targetSources[$targetAssetPath] -ne $sourceFullPath) {
        $issues.Add("Multiple source assets would target the same project path '$targetAssetPath': $($targetSources[$targetAssetPath]) and $sourceFullPath") | Out-Null
        $targetCollisionCount += 1
    } else {
        $targetSources[$targetAssetPath] = $sourceFullPath
    }

    $sourceMetaPath = "$sourceFullPath.meta"
    $metaGuid = Get-MetaGuid -MetaPath $sourceMetaPath
    $targetMetaPath = "$targetFullPath.meta"
    if (Test-Path -LiteralPath $targetFullPath -PathType Container) {
        $issues.Add("Target asset path is an existing directory for '$candidate': $targetFullPath") | Out-Null
        $targetOverwriteRiskCount += 1
    } elseif (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
        $existingTargetFileCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourceFullPath -RightPath $targetFullPath)) {
            $issues.Add("Existing target asset differs for '$candidate': $targetFullPath") | Out-Null
            $targetOverwriteRiskCount += 1
        }
    }
    if (Test-Path -LiteralPath $targetMetaPath -PathType Container) {
        $issues.Add("Target meta path is an existing directory for '$candidate': $targetMetaPath") | Out-Null
        $targetOverwriteRiskCount += 1
    } elseif (Test-Path -LiteralPath $targetMetaPath -PathType Leaf) {
        $existingTargetMetaCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourceMetaPath -RightPath $targetMetaPath)) {
            $issues.Add("Existing target meta differs for '$candidate': $targetMetaPath") | Out-Null
            $targetOverwriteRiskCount += 1
        }
    }

    if ([string]::IsNullOrWhiteSpace($metaGuid)) {
        $issues.Add("Missing or unreadable source meta guid for '$candidate': $sourceMetaPath") | Out-Null
        $missingMetaGuidCount += 1
    } elseif ($guidTargets.ContainsKey($metaGuid) -and [string]$guidTargets[$metaGuid] -ne $targetAssetPath) {
        $issues.Add("Duplicate source guid '$metaGuid' would be copied to multiple targets: $($guidTargets[$metaGuid]) and $targetAssetPath") | Out-Null
        $duplicateGuidCount += 1
    } else {
        $guidTargets[$metaGuid] = $targetAssetPath
    }
    if (-not [string]::IsNullOrWhiteSpace($metaGuid) -and $existingProjectGuidIndex.ContainsKey($metaGuid)) {
        $canonicalTargetMetaPath = Get-CanonicalPath $targetMetaPath
        $conflictingMetaPaths = @($existingProjectGuidIndex[$metaGuid] | Where-Object {
            -not ([string]$_).Equals($canonicalTargetMetaPath, [System.StringComparison]::OrdinalIgnoreCase)
        })
        if ($conflictingMetaPaths.Count -gt 0) {
            $issues.Add("Source guid '$metaGuid' for '$candidate' already exists in project meta outside the planned target: $($conflictingMetaPaths -join '; ')") | Out-Null
            $projectGuidConflictCount += 1
        }
    }

    $planRows.Add([PSCustomObject]@{
        CandidateId = $candidate
        SourceProjectPath = $sourceProjectPath
        SourceAssetPath = $sourceAssetPath
        SourceFullPath = $sourceFullPath
        SourceMetaPath = $sourceMetaPath
        SourceGuid = $metaGuid
        TargetAssetPath = $targetAssetPath
        TargetFullPath = $targetFullPath
        TargetMetaPath = $targetMetaPath
        TargetAssetExists = (Test-Path -LiteralPath $targetFullPath -PathType Leaf)
        TargetMetaExists = (Test-Path -LiteralPath $targetMetaPath -PathType Leaf)
        Length = [long]$row.Length
        IsRoot = $isRoot
        Applied = $false
    }) | Out-Null
}

if ($planRows.Count -eq 0) {
    $issues.Add('No source assets were selected for the controlled import copy plan.') | Out-Null
}

$canApply = ($issues.Count -eq 0 -and $planRows.Count -gt 0)
if ($Apply -and $canApply) {
    foreach ($planRow in $planRows) {
        Copy-AssetWithMeta -SourcePath ([string]$planRow.SourceFullPath) -TargetPath ([string]$planRow.TargetFullPath)
        $planRow.Applied = $true
    }
}

$totalBytes = 0L
foreach ($planRow in $planRows) {
    $totalBytes += [long]$planRow.Length
}
$plannedMetaCount = @($planRows | Where-Object { Test-Path -LiteralPath ([string]$_.SourceMetaPath) -PathType Leaf }).Count
$appliedAssetCount = @($planRows | Where-Object { [bool]$_.Applied }).Count

$planCsv = if ($Apply) {
    Join-Path $outputDir 'controlled-import-copy-apply.csv'
} else {
    Join-Path $outputDir 'controlled-import-copy-dry-run.csv'
}
$summaryJson = if ($Apply) {
    Join-Path $outputDir 'controlled-import-copy-apply-summary.json'
} else {
    Join-Path $outputDir 'controlled-import-copy-summary.json'
}
$planRows | Export-Csv -LiteralPath $planCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    apply = [bool]$Apply
    planDirectory = $PlanDirectory
    outputDirectory = $outputDir
    selectedCandidateCount = $selections.Count
    plannedFileCount = $planRows.Count
    plannedAssetCount = $planRows.Count
    plannedMetaCount = $plannedMetaCount
    plannedRootAssetCount = @($planRows | Where-Object { [bool]$_.IsRoot }).Count
    duplicateGuidCount = $duplicateGuidCount
    missingSourceCount = $missingSourceCount
    missingMetaGuidCount = $missingMetaGuidCount
    targetCollisionCount = $targetCollisionCount
    projectGuidConflictCount = $projectGuidConflictCount
    existingTargetFileCount = $existingTargetFileCount
    existingTargetMetaCount = $existingTargetMetaCount
    targetOverwriteRiskCount = $targetOverwriteRiskCount
    canApply = $canApply
    appliedAssetCount = $appliedAssetCount
    totalBytes = $totalBytes
    issueCount = $issues.Count
    issues = @($issues)
    planCsv = $planCsv
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$summary

if ($issues.Count -gt 0) {
    throw "Controlled import copy plan failed with $($issues.Count) issue(s)."
}
