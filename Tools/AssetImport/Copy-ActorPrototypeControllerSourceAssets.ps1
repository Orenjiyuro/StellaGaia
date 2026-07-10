[CmdletBinding()]
param(
    [string]$PlanCsvPath,
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

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$MetaPath)

    if (-not (Test-Path -LiteralPath $MetaPath -PathType Leaf)) {
        return ''
    }

    $match = Select-String -LiteralPath $MetaPath -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
    if ($null -eq $match) {
        return ''
    }

    return $match.Matches[0].Groups[1].Value.ToLowerInvariant()
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

    foreach ($metaFile in Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.meta' -Force -ErrorAction SilentlyContinue) {
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

    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $TargetPath))
    Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force

    $sourceMetaPath = "$SourcePath.meta"
    if (Test-Path -LiteralPath $sourceMetaPath -PathType Leaf) {
        Copy-Item -LiteralPath $sourceMetaPath -Destination "$TargetPath.meta" -Force
    }
}

function Test-IsExtractedWorkspacePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = Get-CanonicalPath $Path
    if (Test-IsPathUnderOrEqual -CandidatePath $full -RootPath $extractedRoot) {
        return $true
    }

    return $full -match '(?i)(^|[\\/])Extracted([\\/]|$)'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$assetsRoot = Get-CanonicalPath (Join-Path $repoRoot 'Assets')
$controlledCandidatesRoot = Get-CanonicalPath (Join-Path $assetsRoot 'StellaGaia\Imported\ControlledCandidates')
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = if (Test-Path -LiteralPath $toolManifestPath -PathType Leaf) {
    Get-Content -LiteralPath $toolManifestPath -Raw | ConvertFrom-Json
} else {
    $null
}
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($PlanCsvPath)) {
    $PlanCsvPath = Join-Path $extractedRoot 'Validation\ActorPrototypeControllerRebuildPlan\actor-prototype-controller-source-assets.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\ActorPrototypeControllerSourceCopy'
}

$PlanCsvPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $PlanCsvPath
$OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot

Assert-PathUnderOrEqual -Path $PlanCsvPath -RootPath $extractedRoot -Description 'PlanCsvPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathNotUnder -Path $PlanCsvPath -RootPath $sourceInstall -Description 'PlanCsvPath'
Assert-PathNotUnder -Path $OutputRoot -RootPath $sourceInstall -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $PlanCsvPath -PathType Leaf)) {
    throw "Missing actor prototype controller source plan CSV: $PlanCsvPath"
}

$candidateFilter = @($CandidateId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$planName = Convert-ToSafeFileName -Value ((Split-Path -LeafBase $PlanCsvPath) + '-' + ($(if ($candidateFilter.Count -eq 0) { 'all' } else { $candidateFilter -join '_' })))
$outputDir = Join-Path $OutputRoot $planName
[void][System.IO.Directory]::CreateDirectory($outputDir)

$issues = [System.Collections.Generic.List[string]]::new()
$selectedRows = [System.Collections.Generic.List[object]]::new()
$targetSources = @{}
$guidTargets = @{}
$existingGuidIndex = Get-ExistingProjectGuidIndex -RootPath $assetsRoot

$missingSourceCount = 0
$missingMetaCount = 0
$placeholderSourceCount = 0
$duplicateGuidCount = 0
$projectGuidConflictCount = 0
$targetCollisionCount = 0
$existingTargetFileCount = 0
$existingTargetMetaCount = 0
$targetOverwriteRiskCount = 0

foreach ($row in Import-Csv -LiteralPath $PlanCsvPath) {
    $candidate = [string]$row.CandidateId
    if ($candidateFilter.Count -gt 0 -and $candidate -notin $candidateFilter) {
        continue
    }

    $sourceProjectPath = Get-CanonicalPath ([string]$row.SourceProjectPath)
    $sourceFullPath = Get-CanonicalPath ([string]$row.SourceFullPath)
    $sourceMetaPath = Get-CanonicalPath ([string]$row.SourceMetaPath)
    $targetAssetPath = ([string]$row.TargetAssetPath).Replace('\', '/')
    $targetFullPath = Get-CanonicalPath ([string]$row.TargetFullPath)
    $targetMetaPath = Get-CanonicalPath ([string]$row.TargetMetaPath)

    Assert-SafeAssetPath -Path ([string]$row.SourceAssetPath)
    Assert-SafeAssetPath -Path $targetAssetPath
    Assert-PathUnderOrEqual -Path $sourceProjectPath -RootPath $extractedRoot -Description "Source project '$candidate'"
    Assert-PathNotUnder -Path $sourceProjectPath -RootPath $sourceInstall -Description "Source project '$candidate'"
    Assert-PathUnderOrEqual -Path $targetFullPath -RootPath $controlledCandidatesRoot -Description "Target asset '$candidate'"

    if (-not (Test-IsExtractedWorkspacePath -Path $sourceFullPath)) {
        $issues.Add("Source file for '$candidate' is outside Extracted: $sourceFullPath") | Out-Null
    }
    if ((Test-Path -LiteralPath $sourceInstall) -and (Test-IsPathUnderOrEqual -CandidatePath $sourceFullPath -RootPath $sourceInstall)) {
        $issues.Add("Source file for '$candidate' is under source install: $sourceFullPath") | Out-Null
    }

    if (-not (Test-Path -LiteralPath $sourceFullPath -PathType Leaf)) {
        $missingSourceCount += 1
        $issues.Add("Missing source asset for '$candidate': $sourceFullPath") | Out-Null
    }
    if (-not (Test-Path -LiteralPath $sourceMetaPath -PathType Leaf)) {
        $missingMetaCount += 1
        $issues.Add("Missing source meta for '$candidate': $sourceMetaPath") | Out-Null
    }

    $sourceGuid = Get-MetaGuid -MetaPath $sourceMetaPath
    if ([string]::IsNullOrWhiteSpace($sourceGuid)) {
        $missingMetaCount += 1
        $issues.Add("Missing source GUID for '$candidate': $sourceMetaPath") | Out-Null
    }

    if ((Test-Path -LiteralPath $sourceFullPath -PathType Leaf) -and (Select-String -LiteralPath $sourceFullPath -Pattern 'deadbeef|deadf00d' -CaseSensitive:$false -Quiet)) {
        $placeholderSourceCount += 1
        $issues.Add("Planned source asset still contains placeholder refs for '$candidate': $sourceFullPath") | Out-Null
    }

    if ($targetSources.ContainsKey($targetAssetPath) -and [string]$targetSources[$targetAssetPath] -ne $sourceFullPath) {
        $targetCollisionCount += 1
        $issues.Add("Multiple sources would target '$targetAssetPath': $($targetSources[$targetAssetPath]) and $sourceFullPath") | Out-Null
    } else {
        $targetSources[$targetAssetPath] = $sourceFullPath
    }

    if (-not [string]::IsNullOrWhiteSpace($sourceGuid)) {
        if ($guidTargets.ContainsKey($sourceGuid) -and [string]$guidTargets[$sourceGuid] -ne $targetAssetPath) {
            $duplicateGuidCount += 1
            $issues.Add("Source GUID '$sourceGuid' would be copied to multiple target assets: $($guidTargets[$sourceGuid]) and $targetAssetPath") | Out-Null
        } else {
            $guidTargets[$sourceGuid] = $targetAssetPath
        }

        if ($existingGuidIndex.ContainsKey($sourceGuid)) {
            $canonicalTargetMetaPath = Get-CanonicalPath $targetMetaPath
            $conflicts = @($existingGuidIndex[$sourceGuid] | Where-Object {
                -not ([string]$_).Equals($canonicalTargetMetaPath, [System.StringComparison]::OrdinalIgnoreCase)
            })
            if ($conflicts.Count -gt 0) {
                $projectGuidConflictCount += 1
                $issues.Add("Source GUID '$sourceGuid' for '$candidate' already exists outside planned target: $($conflicts -join '; ')") | Out-Null
            }
        }
    }

    if (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
        $existingTargetFileCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourceFullPath -RightPath $targetFullPath)) {
            $targetOverwriteRiskCount += 1
            $issues.Add("Existing target asset differs for '$candidate': $targetFullPath") | Out-Null
        }
    }
    if (Test-Path -LiteralPath $targetMetaPath -PathType Leaf) {
        $existingTargetMetaCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourceMetaPath -RightPath $targetMetaPath)) {
            $targetOverwriteRiskCount += 1
            $issues.Add("Existing target meta differs for '$candidate': $targetMetaPath") | Out-Null
        }
    }

    $selectedRows.Add([PSCustomObject]@{
        CandidateId = $candidate
        Kind = [string]$row.Kind
        SourceFullPath = $sourceFullPath
        SourceMetaPath = $sourceMetaPath
        SourceGuid = $sourceGuid
        TargetAssetPath = $targetAssetPath
        TargetFullPath = $targetFullPath
        TargetMetaPath = $targetMetaPath
        Length = [int64]$row.Length
        Applied = $false
    }) | Out-Null
}

if ($selectedRows.Count -eq 0) {
    $issues.Add('No actor prototype controller source assets were selected.') | Out-Null
}

$canApply = ($issues.Count -eq 0 -and $selectedRows.Count -gt 0)
if ($Apply -and $canApply) {
    foreach ($selectedRow in $selectedRows.ToArray()) {
        Copy-AssetWithMeta -SourcePath ([string]$selectedRow.SourceFullPath) -TargetPath ([string]$selectedRow.TargetFullPath)
        $selectedRow.Applied = $true
    }
}

$totalBytes = 0L
foreach ($selectedRow in $selectedRows.ToArray()) {
    $totalBytes += [int64]$selectedRow.Length
}
$appliedAssetCount = @($selectedRows.ToArray() | Where-Object { [bool]$_.Applied }).Count

$planCsv = if ($Apply) {
    Join-Path $outputDir 'actor-prototype-controller-source-copy-apply.csv'
} else {
    Join-Path $outputDir 'actor-prototype-controller-source-copy-dry-run.csv'
}
$summaryPath = if ($Apply) {
    Join-Path $outputDir 'actor-prototype-controller-source-copy-apply-summary.json'
} else {
    Join-Path $outputDir 'actor-prototype-controller-source-copy-summary.json'
}

$selectedRows.ToArray() | Export-Csv -LiteralPath $planCsv -NoTypeInformation -Encoding UTF8

$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('O')
    apply = [bool]$Apply
    planCsvPath = $PlanCsvPath
    outputDirectory = $outputDir
    selectedCandidateCount = @($selectedRows.ToArray() | Select-Object -ExpandProperty CandidateId -Unique).Count
    plannedAssetCount = $selectedRows.Count
    existingTargetFileCount = $existingTargetFileCount
    existingTargetMetaCount = $existingTargetMetaCount
    missingSourceCount = $missingSourceCount
    missingMetaCount = $missingMetaCount
    placeholderSourceCount = $placeholderSourceCount
    duplicateGuidCount = $duplicateGuidCount
    projectGuidConflictCount = $projectGuidConflictCount
    targetCollisionCount = $targetCollisionCount
    targetOverwriteRiskCount = $targetOverwriteRiskCount
    canApply = $canApply
    appliedAssetCount = $appliedAssetCount
    totalBytes = $totalBytes
    issueCount = $issues.Count
    issues = @($issues)
    planCsv = $planCsv
    safety = [ordered]@{
        sourceMustStayUnder = $extractedRoot
        targetMustStayUnder = $controlledCandidatesRoot
        sourceInstallMustRemainReadOnly = $sourceInstall
    }
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

[PSCustomObject]$summary | Format-List

if ($issues.Count -gt 0) {
    throw "Actor prototype controller source copy plan has $($issues.Count) issue(s)."
}
