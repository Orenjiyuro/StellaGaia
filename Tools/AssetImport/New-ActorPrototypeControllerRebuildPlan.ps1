[CmdletBinding()]
param(
    [string]$ReadinessSummaryPath,
    [string]$CoreClipCsvPath,
    [string]$OutputRoot,
    [string[]]$CandidateId = @('player_character', 'enemy')
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

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = Get-CanonicalPath $Path
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description 'Relative path source'

    if ([string]::Equals($root, $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }

    return $candidate.Substring(($root + [System.IO.Path]::DirectorySeparatorChar).Length).Replace('\', '/')
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
    return "Assets/StellaGaia/Imported/ControlledCandidates/$safeCandidate/PrototypeControllerRebuild/Dependencies/$relative"
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    $metaPath = "$AssetPath.meta"
    if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
        return ''
    }

    $match = Select-String -LiteralPath $metaPath -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
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
        $match = Select-String -LiteralPath $metaFile.FullName -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
        if ($null -eq $match) {
            continue
        }

        $guid = $match.Matches[0].Groups[1].Value.ToLowerInvariant()
        if (-not $index.ContainsKey($guid)) {
            $index[$guid] = [System.Collections.Generic.List[string]]::new()
        }
        $index[$guid].Add((Get-CanonicalPath $metaFile.FullName)) | Out-Null
    }

    return $index
}

function Add-PlannedSourceAsset {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[object]]$Rows,
        [Parameter(Mandatory = $true)][string]$Candidate,
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$SourceProjectPath,
        [Parameter(Mandatory = $true)][string]$SourceAssetPath,
        [Parameter(Mandatory = $true)][string]$TargetAssetPath
    )

    $sourceAssetPath = $SourceAssetPath.Replace('\', '/')
    $targetAssetPath = $TargetAssetPath.Replace('\', '/')
    Assert-SafeAssetPath -Path $sourceAssetPath
    Assert-SafeAssetPath -Path $targetAssetPath

    $sourceFullPath = Get-CanonicalPath (Join-Path $SourceProjectPath $sourceAssetPath)
    $sourceMetaPath = "$sourceFullPath.meta"
    $targetFullPath = Get-CanonicalPath (Join-Path $repoRoot $targetAssetPath)
    $targetMetaPath = "$targetFullPath.meta"
    Assert-PathUnderOrEqual -Path $targetFullPath -RootPath $controlledCandidatesRoot -Description "Target asset '$Candidate'"

    $sourceExists = Test-Path -LiteralPath $sourceFullPath -PathType Leaf
    $sourceMetaExists = Test-Path -LiteralPath $sourceMetaPath -PathType Leaf
    $guid = if ($sourceExists) { Get-MetaGuid -AssetPath $sourceFullPath } else { '' }
    $hasPlaceholder = if ($sourceExists) { Select-String -LiteralPath $sourceFullPath -Pattern 'deadbeef|deadf00d' -CaseSensitive:$false -Quiet } else { $false }

    $Rows.Add([PSCustomObject]@{
        CandidateId = $Candidate
        Kind = $Kind
        SourceProjectPath = $SourceProjectPath
        SourceAssetPath = $sourceAssetPath
        SourceFullPath = $sourceFullPath
        SourceMetaPath = $sourceMetaPath
        SourceExists = [bool]$sourceExists
        SourceMetaExists = [bool]$sourceMetaExists
        SourceGuid = $guid
        SourceHasPlaceholder = [bool]$hasPlaceholder
        TargetAssetPath = $targetAssetPath
        TargetFullPath = $targetFullPath
        TargetMetaPath = $targetMetaPath
        TargetAssetExists = (Test-Path -LiteralPath $targetFullPath -PathType Leaf)
        TargetMetaExists = (Test-Path -LiteralPath $targetMetaPath -PathType Leaf)
        Length = if ($sourceExists) { [int64](Get-Item -LiteralPath $sourceFullPath).Length } else { 0 }
    }) | Out-Null
}

if ([string]::IsNullOrWhiteSpace($ReadinessSummaryPath)) {
    $ReadinessSummaryPath = Join-Path $PSScriptRoot '..\..\Extracted\Validation\ActorAnimationRebuildReadiness\actor-animation-rebuild-readiness-summary.json'
}
if ([string]::IsNullOrWhiteSpace($CoreClipCsvPath)) {
    $CoreClipCsvPath = Join-Path $PSScriptRoot '..\..\Extracted\Validation\ActorAnimationRebuildReadiness\actor-animation-core-clips.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\ActorPrototypeControllerRebuildPlan'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$assetsRoot = Get-CanonicalPath (Join-Path $repoRoot 'Assets')
$controlledCandidatesRoot = Get-CanonicalPath (Join-Path $assetsRoot 'StellaGaia\Imported\ControlledCandidates')
$sourceInstall = 'C:\SoftGame\YostarGames\StellaSora_CN'

$ReadinessSummaryPath = Get-CanonicalPath $ReadinessSummaryPath
$CoreClipCsvPath = Get-CanonicalPath $CoreClipCsvPath
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $ReadinessSummaryPath -RootPath $extractedRoot -Description 'ReadinessSummaryPath'
Assert-PathUnderOrEqual -Path $CoreClipCsvPath -RootPath $extractedRoot -Description 'CoreClipCsvPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathNotUnder -Path $OutputRoot -RootPath $sourceInstall -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $ReadinessSummaryPath -PathType Leaf)) {
    throw "Missing actor animation rebuild readiness summary: $ReadinessSummaryPath"
}
if (-not (Test-Path -LiteralPath $CoreClipCsvPath -PathType Leaf)) {
    throw "Missing actor core clip CSV: $CoreClipCsvPath"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$readiness = Get-Content -LiteralPath $ReadinessSummaryPath -Raw | ConvertFrom-Json
$coreClips = @(Import-Csv -LiteralPath $CoreClipCsvPath)
$candidateFilter = @($CandidateId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$existingGuidIndex = Get-ExistingProjectGuidIndex -RootPath $assetsRoot
$issues = [System.Collections.Generic.List[string]]::new()
$sourceAssetRows = [System.Collections.Generic.List[object]]::new()
$controllerSpecs = [System.Collections.Generic.List[object]]::new()

foreach ($candidate in @($readiness.Candidates)) {
    $id = [string]$candidate.Id
    if ($candidateFilter.Count -gt 0 -and $id -notin $candidateFilter) {
        continue
    }

    if ([string]$candidate.RebuildReadiness -ne 'StaticReadyForPrototypeControllerRebuild') {
        $issues.Add("Candidate '$id' is not static-ready for prototype controller rebuild: $($candidate.RebuildReadiness)") | Out-Null
        continue
    }

    $sourceProjectPath = Get-CanonicalPath ([string]$candidate.ProjectPath)
    Assert-PathUnderOrEqual -Path $sourceProjectPath -RootPath $extractedRoot -Description "Source project '$id'"
    Assert-PathNotUnder -Path $sourceProjectPath -RootPath $sourceInstall -Description "Source project '$id'"

    $safeId = Convert-ToSafeFileName -Value $id
    $targetRoot = "Assets/StellaGaia/Imported/ControlledCandidates/$safeId/PrototypeControllerRebuild"
    $prefabLeaf = [System.IO.Path]::GetFileName(([string]$candidate.Candidate).Replace('\', '/'))
    $targetPrefabPath = "$targetRoot/$prefabLeaf"
    $generatedControllerPath = "$targetRoot/${safeId}_Prototype.controller"
    $generatedPrefabPath = "$targetRoot/${safeId}_Prototype.prefab"

    Add-PlannedSourceAsset -Rows $sourceAssetRows -Candidate $id -Kind 'rootPrefab' -SourceProjectPath $sourceProjectPath -SourceAssetPath ([string]$candidate.Candidate) -TargetAssetPath $targetPrefabPath
    Add-PlannedSourceAsset -Rows $sourceAssetRows -Candidate $id -Kind 'avatar' -SourceProjectPath $sourceProjectPath -SourceAssetPath ([string]$candidate.AvatarPath) -TargetAssetPath (Convert-ToTargetDependencyPath -Candidate $id -SourceAssetPath ([string]$candidate.AvatarPath))

    $states = [System.Collections.Generic.List[object]]::new()
    foreach ($clip in @($coreClips | Where-Object { [string]$_.CandidateId -eq $id -and [string]$_.Found -eq 'True' })) {
        $clipSourcePath = Get-RelativePath -RootPath $sourceProjectPath -Path (Join-Path ([string]$candidate.AnimationRoot) ([string]$clip.SelectedClip))
        $clipTargetPath = Convert-ToTargetDependencyPath -Candidate $id -SourceAssetPath $clipSourcePath
        Add-PlannedSourceAsset -Rows $sourceAssetRows -Candidate $id -Kind "clip:$($clip.Group)" -SourceProjectPath $sourceProjectPath -SourceAssetPath $clipSourcePath -TargetAssetPath $clipTargetPath

        $states.Add([PSCustomObject]@{
            group = [string]$clip.Group
            stateName = ([string]$clip.Group).Substring(0, 1).ToUpperInvariant() + ([string]$clip.Group).Substring(1)
            required = [bool]::Parse([string]$clip.Required)
            sourceClip = $clipSourcePath
            targetClip = $clipTargetPath
            clipGuid = [string]$clip.Guid
        }) | Out-Null
    }

    $controllerSpecs.Add([PSCustomObject]@{
        id = $id
        sourceCategory = [string]$candidate.SourceCategory
        repairMode = 'PrototypeControllerRebuild'
        sourcePrefab = [string]$candidate.Candidate
        targetPrefab = $targetPrefabPath
        generatedController = $generatedControllerPath
        generatedPrefab = $generatedPrefabPath
        avatarSource = [string]$candidate.AvatarPath
        avatarTarget = Convert-ToTargetDependencyPath -Candidate $id -SourceAssetPath ([string]$candidate.AvatarPath)
        originalController = [string]$candidate.ControllerPath
        originalControllerHasPlaceholder = [bool]$candidate.ControllerHasPlaceholder
        states = @($states.ToArray())
        note = 'Use Unity Editor to create the generated controller and prefab. This is a local repair/downgrade route, not original controller recovery.'
    }) | Out-Null
}

if ($controllerSpecs.Count -eq 0) {
    $issues.Add('No actor prototype controller rebuild specs were created.') | Out-Null
}

$seenTargetPaths = @{}
$seenGuids = @{}
$missingSourceCount = 0
$missingMetaCount = 0
$placeholderSourceCount = 0
$duplicateGuidCount = 0
$projectGuidConflictCount = 0
$targetOverwriteRiskCount = 0
foreach ($row in $sourceAssetRows.ToArray()) {
    if (-not [bool]$row.SourceExists) {
        $missingSourceCount += 1
        $issues.Add("Missing source asset for '$($row.CandidateId)': $($row.SourceFullPath)") | Out-Null
    }
    if (-not [bool]$row.SourceMetaExists -or [string]::IsNullOrWhiteSpace([string]$row.SourceGuid)) {
        $missingMetaCount += 1
        $issues.Add("Missing source meta/guid for '$($row.CandidateId)': $($row.SourceMetaPath)") | Out-Null
    }
    if ([bool]$row.SourceHasPlaceholder) {
        $placeholderSourceCount += 1
        $issues.Add("Planned source asset contains placeholder refs for '$($row.CandidateId)': $($row.SourceAssetPath)") | Out-Null
    }

    $targetPath = [string]$row.TargetAssetPath
    if ($seenTargetPaths.ContainsKey($targetPath) -and [string]$seenTargetPaths[$targetPath] -ne [string]$row.SourceFullPath) {
        $targetOverwriteRiskCount += 1
        $issues.Add("Multiple source assets target '$targetPath': $($seenTargetPaths[$targetPath]) and $($row.SourceFullPath)") | Out-Null
    } else {
        $seenTargetPaths[$targetPath] = [string]$row.SourceFullPath
    }

    if ([bool]$row.TargetAssetExists -and -not (Test-SameFileContent -LeftPath ([string]$row.SourceFullPath) -RightPath ([string]$row.TargetFullPath))) {
        $targetOverwriteRiskCount += 1
        $issues.Add("Existing target asset differs for '$($row.CandidateId)': $($row.TargetFullPath)") | Out-Null
    }
    if ([bool]$row.TargetMetaExists -and -not (Test-SameFileContent -LeftPath ([string]$row.SourceMetaPath) -RightPath ([string]$row.TargetMetaPath))) {
        $targetOverwriteRiskCount += 1
        $issues.Add("Existing target meta differs for '$($row.CandidateId)': $($row.TargetMetaPath)") | Out-Null
    }

    $guid = [string]$row.SourceGuid
    if (-not [string]::IsNullOrWhiteSpace($guid)) {
        if ($seenGuids.ContainsKey($guid) -and [string]$seenGuids[$guid] -ne $targetPath) {
            $duplicateGuidCount += 1
            $issues.Add("Source guid '$guid' would be copied to multiple target paths: $($seenGuids[$guid]) and $targetPath") | Out-Null
        } else {
            $seenGuids[$guid] = $targetPath
        }

        if ($existingGuidIndex.ContainsKey($guid)) {
            $canonicalTargetMetaPath = Get-CanonicalPath ([string]$row.TargetMetaPath)
            $conflicts = @($existingGuidIndex[$guid] | Where-Object {
                -not ([string]$_).Equals($canonicalTargetMetaPath, [System.StringComparison]::OrdinalIgnoreCase)
            })
            if ($conflicts.Count -gt 0) {
                $projectGuidConflictCount += 1
                $issues.Add("Source guid '$guid' for '$($row.CandidateId)' already exists in project outside planned target: $($conflicts -join '; ')") | Out-Null
            }
        }
    }
}

$totalBytes = 0L
foreach ($row in $sourceAssetRows.ToArray()) {
    $totalBytes += [int64]$row.Length
}

$sourcePlanPath = Join-Path $OutputRoot 'actor-prototype-controller-source-assets.csv'
$controllerSpecPath = Join-Path $OutputRoot 'actor-prototype-controller-spec.json'
$summaryPath = Join-Path $OutputRoot 'actor-prototype-controller-rebuild-plan-summary.json'
$markdownPath = Join-Path $OutputRoot 'actor-prototype-controller-rebuild-plan.md'

$sourceAssetRows.ToArray() | Export-Csv -LiteralPath $sourcePlanPath -NoTypeInformation -Encoding UTF8
@($controllerSpecs.ToArray()) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $controllerSpecPath -Encoding UTF8

$canStageSourceAssets = ($issues.Count -eq 0 -and $sourceAssetRows.Count -gt 0 -and $controllerSpecs.Count -gt 0)
$summary = [ordered]@{
    generatedAt = (Get-Date).ToString('O')
    readinessSummaryPath = $ReadinessSummaryPath
    coreClipCsvPath = $CoreClipCsvPath
    outputRoot = $OutputRoot
    selectedCandidateCount = $controllerSpecs.Count
    plannedSourceAssetCount = $sourceAssetRows.Count
    plannedControllerSpecCount = $controllerSpecs.Count
    missingSourceCount = $missingSourceCount
    missingMetaCount = $missingMetaCount
    placeholderSourceCount = $placeholderSourceCount
    duplicateGuidCount = $duplicateGuidCount
    projectGuidConflictCount = $projectGuidConflictCount
    targetOverwriteRiskCount = $targetOverwriteRiskCount
    totalBytes = $totalBytes
    canStageSourceAssets = $canStageSourceAssets
    issueCount = $issues.Count
    issues = @($issues)
    sourcePlanCsv = $sourcePlanPath
    controllerSpecJson = $controllerSpecPath
    safety = [ordered]@{
        writesOnlyUnder = $extractedRoot
        notes = 'Dry-run only. This script does not copy assets, create controllers, patch prefabs, or write to the StellaSora source install.'
    }
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$markdown = @(
    '# Actor Prototype Controller Rebuild Plan',
    '',
    "Generated: $($summary.generatedAt)",
    '',
    '| Metric | Count |',
    '| --- | ---: |',
    "| Selected candidates | $($summary.selectedCandidateCount) |",
    "| Planned source assets | $($summary.plannedSourceAssetCount) |",
    "| Controller specs | $($summary.plannedControllerSpecCount) |",
    "| Missing sources | $($summary.missingSourceCount) |",
    "| Missing meta/guid | $($summary.missingMetaCount) |",
    "| Placeholder source assets | $($summary.placeholderSourceCount) |",
    "| Project GUID conflicts | $($summary.projectGuidConflictCount) |",
    "| Target overwrite risks | $($summary.targetOverwriteRiskCount) |",
    "| Can stage source assets | $($summary.canStageSourceAssets) |",
    '',
    '## Controller Specs',
    '',
    '| Candidate | Target prefab | Generated controller | Generated prefab | Original controller placeholder | State count |',
    '| --- | --- | --- | --- | --- | ---: |'
)
foreach ($spec in $controllerSpecs.ToArray()) {
    $markdown += "| ``$($spec.id)`` | ``$($spec.targetPrefab)`` | ``$($spec.generatedController)`` | ``$($spec.generatedPrefab)`` | $($spec.originalControllerHasPlaceholder) | $(@($spec.states).Count) |"
}

$markdown += @(
    '',
    '## Issues',
    ''
)
if ($issues.Count -eq 0) {
    $markdown += '- None.'
} else {
    foreach ($issue in $issues) {
        $markdown += "- $issue"
    }
}
$markdown += @(
    '',
    '## Interpretation',
    '',
    '- This is a dry-run staging plan for source prefab, Avatar, and core animation clips only.',
    '- The generated controller and generated prefab paths are planned outputs for a later Unity Editor builder.',
    '- This route is a local repair/downgrade using original exported clips, not recovery of the original Animator Override Controller.'
)
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[PSCustomObject]@{
    selectedCandidateCount = $summary.selectedCandidateCount
    plannedSourceAssetCount = $summary.plannedSourceAssetCount
    plannedControllerSpecCount = $summary.plannedControllerSpecCount
    canStageSourceAssets = $summary.canStageSourceAssets
    issueCount = $summary.issueCount
    totalBytes = $summary.totalBytes
    sourcePlanCsv = $sourcePlanPath
    controllerSpecJson = $controllerSpecPath
    summary = $summaryPath
    report = $markdownPath
    issues = @($issues)
} | Format-List

if ($issues.Count -gt 0) {
    throw "Actor prototype controller rebuild plan has $($issues.Count) issue(s)."
}
