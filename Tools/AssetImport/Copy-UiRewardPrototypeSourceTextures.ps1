[CmdletBinding()]
param(
    [string]$PlanCsvPath,
    [string]$OutputRoot,
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

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

function Copy-AssetWithMeta {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][string]$TargetPath
    )

    [void][System.IO.Directory]::CreateDirectory((Split-Path -Parent $TargetPath))
    Copy-Item -LiteralPath $SourcePath -Destination $TargetPath -Force
    Copy-Item -LiteralPath "$SourcePath.meta" -Destination "$TargetPath.meta" -Force
}

function Convert-ToBool {
    param([object]$Value)

    if ($null -eq $Value) {
        return $false
    }

    $text = [string]$Value
    return $text.Equals('true', [System.StringComparison]::OrdinalIgnoreCase) -or
        $text.Equals('1', [System.StringComparison]::OrdinalIgnoreCase) -or
        $text.Equals('yes', [System.StringComparison]::OrdinalIgnoreCase)
}

function Write-StagingReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][object[]]$Rows,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# UI Reward Prototype Texture Staging') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Apply | $($Summary.apply) |") | Out-Null
    $lines.Add("| Status | $($Summary.status) |") | Out-Null
    $lines.Add("| Planned texture count | $($Summary.plannedTextureCount) |") | Out-Null
    $lines.Add("| Existing target files | $($Summary.existingTargetFileCount) |") | Out-Null
    $lines.Add("| Can apply | $($Summary.canApply) |") | Out-Null
    $lines.Add("| Applied texture count | $($Summary.appliedTextureCount) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Textures') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Role | Review | Target | Applied |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- |') | Out-Null
    foreach ($row in $Rows) {
        $lines.Add("| $($row.Id) | $($row.Role) | $($row.Review) | `$($row.TargetAssetPath)` | $($row.Applied) |") | Out-Null
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
    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$assetsRoot = Get-CanonicalPath (Join-Path $repoRoot 'Assets')
$controlledCandidatesRoot = Get-CanonicalPath (Join-Path $assetsRoot 'StellaGaia\Imported\ControlledCandidates')
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($PlanCsvPath)) {
    $PlanCsvPath = Join-Path $extractedRoot 'Validation\UiRewardPrototypeRebuildPlan\ui-reward-prototype-source-textures.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'Validation\UiRewardPrototypeTextureStaging'
}

$PlanCsvPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $PlanCsvPath
$OutputRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $OutputRoot

Assert-PathUnderOrEqual -Path $PlanCsvPath -RootPath $extractedRoot -Description 'PlanCsvPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathNotUnder -Path $PlanCsvPath -RootPath $sourceInstall -Description 'PlanCsvPath'
Assert-PathNotUnder -Path $OutputRoot -RootPath $sourceInstall -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $PlanCsvPath -PathType Leaf)) {
    throw "Missing UI/reward prototype source texture plan CSV: $PlanCsvPath"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$issues = [System.Collections.Generic.List[string]]::new()
$selectedRows = [System.Collections.Generic.List[object]]::new()
$targetSources = @{}
$guidTargets = @{}
$existingGuidIndex = Get-ExistingProjectGuidIndex -RootPath $assetsRoot

$missingSourceCount = 0
$missingMetaCount = 0
$duplicateGuidCount = 0
$projectGuidConflictCount = 0
$targetCollisionCount = 0
$existingTargetFileCount = 0
$existingTargetMetaCount = 0
$targetOverwriteRiskCount = 0

foreach ($row in Import-Csv -LiteralPath $PlanCsvPath) {
    if (-not (Convert-ToBool -Value $row.acceptedForPrototypePlan)) {
        continue
    }

    $id = [string]$row.id
    $sourcePath = Get-CanonicalPath ([string]$row.sourcePath)
    $sourceMetaPath = Get-CanonicalPath ([string]$row.sourceMetaPath)
    $targetAssetPath = ([string]$row.targetAssetPath).Replace('\', '/')
    $targetFullPath = Get-CanonicalPath ([string]$row.targetFullPath)
    $targetMetaPath = Get-CanonicalPath ([string]$row.targetMetaPath)

    Assert-SafeAssetPath -Path $targetAssetPath
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $extractedRoot -Description "Texture source '$id'"
    Assert-PathUnderOrEqual -Path $sourceMetaPath -RootPath $extractedRoot -Description "Texture meta '$id'"
    Assert-PathUnderOrEqual -Path $targetFullPath -RootPath $controlledCandidatesRoot -Description "Target texture '$id'"
    Assert-PathNotUnder -Path $sourcePath -RootPath $sourceInstall -Description "Texture source '$id'"

    $expectedTargetFullPath = Get-CanonicalPath (Join-Path $repoRoot $targetAssetPath)
    if (-not $targetFullPath.Equals($expectedTargetFullPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        $issues.Add("Target full path does not match target asset path for '$id': $targetFullPath vs $expectedTargetFullPath") | Out-Null
    }

    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        $missingSourceCount += 1
        $issues.Add("Missing texture source '$id': $sourcePath") | Out-Null
    }
    if (-not (Test-Path -LiteralPath $sourceMetaPath -PathType Leaf)) {
        $missingMetaCount += 1
        $issues.Add("Missing texture meta '$id': $sourceMetaPath") | Out-Null
    }

    $sourceGuid = Get-MetaGuid -MetaPath $sourceMetaPath
    if ([string]::IsNullOrWhiteSpace($sourceGuid)) {
        $missingMetaCount += 1
        $issues.Add("Missing texture meta GUID '$id': $sourceMetaPath") | Out-Null
    } elseif (-not $sourceGuid.Equals(([string]$row.sourceGuid), [System.StringComparison]::OrdinalIgnoreCase)) {
        $issues.Add("Texture source GUID mismatch '$id': CSV=$($row.sourceGuid) meta=$sourceGuid") | Out-Null
    }

    if ($targetSources.ContainsKey($targetAssetPath) -and [string]$targetSources[$targetAssetPath] -ne $sourcePath) {
        $targetCollisionCount += 1
        $issues.Add("Multiple sources would target '$targetAssetPath': $($targetSources[$targetAssetPath]) and $sourcePath") | Out-Null
    } else {
        $targetSources[$targetAssetPath] = $sourcePath
    }

    if (-not [string]::IsNullOrWhiteSpace($sourceGuid)) {
        if ($guidTargets.ContainsKey($sourceGuid) -and [string]$guidTargets[$sourceGuid] -ne $targetAssetPath) {
            $duplicateGuidCount += 1
            $issues.Add("Texture GUID '$sourceGuid' would be copied to multiple targets: $($guidTargets[$sourceGuid]) and $targetAssetPath") | Out-Null
        } else {
            $guidTargets[$sourceGuid] = $targetAssetPath
        }

        if ($existingGuidIndex.ContainsKey($sourceGuid)) {
            $conflicts = @($existingGuidIndex[$sourceGuid] | Where-Object {
                -not ([string]$_).Equals($targetMetaPath, [System.StringComparison]::OrdinalIgnoreCase)
            })
            if ($conflicts.Count -gt 0) {
                $projectGuidConflictCount += 1
                $issues.Add("Texture GUID '$sourceGuid' for '$id' already exists outside planned target: $($conflicts -join '; ')") | Out-Null
            }
        }
    }

    if (Test-Path -LiteralPath $targetFullPath -PathType Leaf) {
        $existingTargetFileCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourcePath -RightPath $targetFullPath)) {
            $targetOverwriteRiskCount += 1
            $issues.Add("Existing target texture differs for '$id': $targetFullPath") | Out-Null
        }
    }
    if (Test-Path -LiteralPath $targetMetaPath -PathType Leaf) {
        $existingTargetMetaCount += 1
        if (-not (Test-SameFileContent -LeftPath $sourceMetaPath -RightPath $targetMetaPath)) {
            $targetOverwriteRiskCount += 1
            $issues.Add("Existing target texture meta differs for '$id': $targetMetaPath") | Out-Null
        }
    }

    $selectedRows.Add([PSCustomObject]@{
        Id = $id
        Role = [string]$row.role
        Review = [string]$row.review
        SourcePath = $sourcePath
        SourceMetaPath = $sourceMetaPath
        SourceGuid = $sourceGuid
        TargetAssetPath = $targetAssetPath
        TargetFullPath = $targetFullPath
        TargetMetaPath = $targetMetaPath
        Width = [int]$row.width
        Height = [int]$row.height
        Length = [int64]$row.bytes
        Applied = $false
    }) | Out-Null
}

if ($selectedRows.Count -eq 0) {
    $issues.Add('No accepted UI/reward texture rows were selected for staging.') | Out-Null
}

$canApply = ($issues.Count -eq 0 -and $selectedRows.Count -gt 0)
if ($Apply -and $canApply) {
    foreach ($selectedRow in $selectedRows.ToArray()) {
        Copy-AssetWithMeta -SourcePath ([string]$selectedRow.SourcePath) -TargetPath ([string]$selectedRow.TargetFullPath)
        $selectedRow.Applied = $true
    }
}

$totalBytes = 0L
foreach ($selectedRow in $selectedRows.ToArray()) {
    $totalBytes += [int64]$selectedRow.Length
}
$appliedTextureCount = @($selectedRows.ToArray() | Where-Object { [bool]$_.Applied }).Count
$status = if ($canApply -and $Apply) {
    'TextureSourcesStaged'
} elseif ($canApply) {
    'TextureSourceStagingReady'
} else {
    'TextureSourceStagingBlocked'
}

$planCsv = if ($Apply) {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging-apply.csv'
} else {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging-dry-run.csv'
}
$summaryJson = if ($Apply) {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging-apply-summary.json'
} else {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging-summary.json'
}
$reportPath = if ($Apply) {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging-apply.md'
} else {
    Join-Path $OutputRoot 'ui-reward-prototype-texture-staging.md'
}

$selectedRows.ToArray() | Export-Csv -LiteralPath $planCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    apply = [bool]$Apply
    status = $status
    planCsvPath = $PlanCsvPath
    outputRoot = $OutputRoot
    plannedTextureCount = $selectedRows.Count
    existingTargetFileCount = $existingTargetFileCount
    existingTargetMetaCount = $existingTargetMetaCount
    missingSourceCount = $missingSourceCount
    missingMetaCount = $missingMetaCount
    duplicateGuidCount = $duplicateGuidCount
    projectGuidConflictCount = $projectGuidConflictCount
    targetCollisionCount = $targetCollisionCount
    targetOverwriteRiskCount = $targetOverwriteRiskCount
    canApply = $canApply
    appliedTextureCount = $appliedTextureCount
    totalBytes = $totalBytes
    issueCount = $issues.Count
    issues = @($issues)
    planCsv = $planCsv
    summaryJson = $summaryJson
    reportPath = $reportPath
    interpretation = 'This stages only accepted original StellaSora Texture2D assets for a rebuilt local UI/reward prototype. It does not accept or copy the high-risk original UI/drop prefabs.'
    safety = [PSCustomObject]@{
        sourceMustStayUnder = $extractedRoot
        targetMustStayUnder = $controlledCandidatesRoot
        sourceInstallMustRemainReadOnly = $sourceInstall
    }
}
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-StagingReport -Summary $summary -Rows $selectedRows.ToArray() -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "UI/reward prototype texture staging has $($issues.Count) issue(s)."
}
