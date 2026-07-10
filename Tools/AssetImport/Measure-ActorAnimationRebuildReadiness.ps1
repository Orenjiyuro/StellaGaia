[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$OutputRoot,
    [string[]]$CandidateIds = @('player_character', 'enemy')
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsPathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $candidate = (Get-CanonicalPath $CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if ([string]::Equals($candidate, $root, $comparison)) {
        return $true
    }

    return $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must stay under $RootPath. Got: $Path"
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $candidate = Get-CanonicalPath $Path
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description 'Relative path source'

    if ([string]::Equals($root, $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }

    return $candidate.Substring(($root + [System.IO.Path]::DirectorySeparatorChar).Length).Replace('\', '/')
}

function Get-MetaGuid {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AssetPath
    )

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

function New-GuidMap {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $map = @{}
    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return $map
    }

    $metaFiles = Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.meta' -Force -ErrorAction SilentlyContinue | Sort-Object FullName
    foreach ($metaFile in $metaFiles) {
        $match = Select-String -LiteralPath $metaFile.FullName -Pattern '^guid:\s*([0-9a-fA-F]{32})' -CaseSensitive:$false | Select-Object -First 1
        if ($null -eq $match) {
            continue
        }

        $assetPath = $metaFile.FullName.Substring(0, $metaFile.FullName.Length - 5)
        $guid = $match.Matches[0].Groups[1].Value.ToLowerInvariant()
        if (-not $map.ContainsKey($guid)) {
            $map[$guid] = Get-RelativePath -RootPath $ProjectPath -Path $assetPath
        }
    }

    return $map
}

function Get-PrefabGuidField {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PrefabPath,
        [Parameter(Mandatory = $true)]
        [string]$FieldName
    )

    if (-not (Test-Path -LiteralPath $PrefabPath -PathType Leaf)) {
        return ''
    }

    $text = Get-Content -LiteralPath $PrefabPath -Raw
    $pattern = "$([regex]::Escape($FieldName)):\s*\{fileID:\s*[^,}]+,\s*guid:\s*([0-9a-fA-F]{32}),\s*type:\s*\d+\}"
    $match = [regex]::Match($text, $pattern)
    if (-not $match.Success) {
        return ''
    }

    return $match.Groups[1].Value.ToLowerInvariant()
}

function Test-FileContainsPattern {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $match = Select-String -LiteralPath $Path -Pattern $Pattern -CaseSensitive:$false -Quiet
    return [bool]$match
}

function Get-CoreClipGroups {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidateId
    )

    if ($CandidateId -eq 'player_character') {
        return @(
            [PSCustomObject]@{ Group = 'idle'; Required = $true; Names = @('144_Idle.anim') },
            [PSCustomObject]@{ Group = 'move'; Required = $true; Names = @('144_Run.anim', '144_Walk.anim') },
            [PSCustomObject]@{ Group = 'attack'; Required = $true; Names = @('144_Attack.anim', '144_Attack_1.anim') },
            [PSCustomObject]@{ Group = 'hurt'; Required = $true; Names = @('144_HurtA1.anim', '144_HurtA2.anim', '144_HurtB.anim') },
            [PSCustomObject]@{ Group = 'die'; Required = $true; Names = @('144_Die.anim') },
            [PSCustomObject]@{ Group = 'dodge'; Required = $false; Names = @('144_Dodge.anim', '144_Rush.anim') }
        )
    }

    if ($CandidateId -eq 'enemy') {
        return @(
            [PSCustomObject]@{ Group = 'idle'; Required = $true; Names = @('10001TuBoShu_Idle.anim') },
            [PSCustomObject]@{ Group = 'move'; Required = $true; Names = @('10001TuBoShu_Run.anim') },
            [PSCustomObject]@{ Group = 'attack'; Required = $true; Names = @('10001TuBoShu_Attack.anim', '10001TuBoShu_Skill1.anim') },
            [PSCustomObject]@{ Group = 'hurt'; Required = $true; Names = @('10001TuBoShu_Hurt.anim', '10001TuBoShu_Hurt2.anim') },
            [PSCustomObject]@{ Group = 'die'; Required = $true; Names = @('10001TuBoShu_Die.anim', '10001TuBoShu_Die2.anim') },
            [PSCustomObject]@{ Group = 'skill'; Required = $false; Names = @('10001TuBoShu_Skill1.anim', '10001TuBoShu_Skill2.anim', '10001TuBoShu_Skill3_start.anim') }
        )
    }

    return @()
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot '..\..\docs\asset-migration\minimum-vertical-slice-assets.json'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\ActorAnimationRebuildReadiness'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$docsRoot = Get-CanonicalPath (Join-Path $repoRoot 'docs')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$ManifestPath = Get-CanonicalPath $ManifestPath
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $docsRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing minimum vertical-slice manifest: $ManifestPath"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$candidateReports = New-Object System.Collections.Generic.List[object]
$clipRows = New-Object System.Collections.Generic.List[object]

foreach ($candidateId in $CandidateIds) {
    $requirement = @($manifest.minimumRequirements | Where-Object { $_.id -eq $candidateId } | Select-Object -First 1)
    if ($requirement.Count -eq 0) {
        $candidateReports.Add([PSCustomObject]@{
            Id = $candidateId
            Status = 'ManifestRequirementMissing'
            RebuildReadiness = 'NotReady'
            Notes = 'No matching minimum vertical-slice requirement exists.'
        }) | Out-Null
        continue
    }

    $requirement = $requirement[0]
    $projectPath = Get-CanonicalPath (Join-Path $repoRoot "Extracted\AssetRipper\ByCategory\$($requirement.sourceCategory)\ExportedProject")
    $prefabPath = Get-CanonicalPath (Join-Path $projectPath ([string]$requirement.candidate))
    Assert-PathUnderOrEqual -Path $projectPath -RootPath $extractedRoot -Description 'Source project path'
    Assert-PathUnderOrEqual -Path $prefabPath -RootPath $projectPath -Description 'Candidate prefab path'

    $actorRoot = Split-Path -Parent $prefabPath
    $animationRoot = Join-Path $actorRoot 'animations'
    $guidMap = New-GuidMap -RootPath $actorRoot -ProjectPath $projectPath

    $prefabExists = Test-Path -LiteralPath $prefabPath -PathType Leaf
    $prefabHasAnimator = Test-FileContainsPattern -Path $prefabPath -Pattern '^Animator:'
    $prefabHasPlaceholder = Test-FileContainsPattern -Path $prefabPath -Pattern 'deadbeef|deadf00d'
    $avatarGuid = Get-PrefabGuidField -PrefabPath $prefabPath -FieldName 'm_Avatar'
    $controllerGuid = Get-PrefabGuidField -PrefabPath $prefabPath -FieldName 'm_Controller'
    $avatarPath = if ($guidMap.ContainsKey($avatarGuid)) { [string]$guidMap[$avatarGuid] } else { '' }
    $controllerPath = if ($guidMap.ContainsKey($controllerGuid)) { [string]$guidMap[$controllerGuid] } else { '' }
    $controllerFullPath = if ([string]::IsNullOrWhiteSpace($controllerPath)) { '' } else { Join-Path $projectPath $controllerPath }
    $controllerHasPlaceholder = if ([string]::IsNullOrWhiteSpace($controllerFullPath)) { $false } else { Test-FileContainsPattern -Path $controllerFullPath -Pattern 'deadbeef|deadf00d' }

    $animFiles = if (Test-Path -LiteralPath $animationRoot -PathType Container) {
        @(Get-ChildItem -LiteralPath $animationRoot -File -Filter '*.anim' -Force | Sort-Object Name)
    } else {
        @()
    }
    $avatarFiles = @(Get-ChildItem -LiteralPath $actorRoot -Recurse -File -Filter '*Avatar*.asset' -Force -ErrorAction SilentlyContinue | Sort-Object FullName)

    $coreGroups = @(Get-CoreClipGroups -CandidateId $candidateId)
    $foundRequiredGroups = 0
    $requiredGroups = @($coreGroups | Where-Object { $_.Required }).Count
    $corePlaceholderCount = 0
    $coreAnimationClipMarkerCount = 0
    $coreClipCount = 0

    foreach ($group in $coreGroups) {
        $selected = $null
        foreach ($name in $group.Names) {
            $candidateClipPath = Join-Path $animationRoot $name
            if (Test-Path -LiteralPath $candidateClipPath -PathType Leaf) {
                $selected = Get-Item -LiteralPath $candidateClipPath
                break
            }
        }

        $exists = $null -ne $selected
        if ($exists -and $group.Required) {
            $foundRequiredGroups += 1
        }
        if ($exists) {
            $coreClipCount += 1
        }

        $clipGuid = if ($exists) { Get-MetaGuid -AssetPath $selected.FullName } else { '' }
        $hasPlaceholder = if ($exists) { Test-FileContainsPattern -Path $selected.FullName -Pattern 'deadbeef|deadf00d' } else { $false }
        $hasAnimationClipMarker = if ($exists) { Test-FileContainsPattern -Path $selected.FullName -Pattern '^AnimationClip:' } else { $false }
        if ($hasPlaceholder) {
            $corePlaceholderCount += 1
        }
        if ($hasAnimationClipMarker) {
            $coreAnimationClipMarkerCount += 1
        }

        $clipRows.Add([PSCustomObject]@{
            CandidateId = $candidateId
            Group = [string]$group.Group
            Required = [bool]$group.Required
            Found = [bool]$exists
            SelectedClip = if ($exists) { $selected.Name } else { '' }
            Length = if ($exists) { [int64]$selected.Length } else { 0 }
            Guid = $clipGuid
            HasAnimationClipMarker = [bool]$hasAnimationClipMarker
            HasPlaceholder = [bool]$hasPlaceholder
        }) | Out-Null
    }

    $rebuildReadiness = if (-not $prefabExists) {
        'NotReadyMissingPrefab'
    } elseif (-not $prefabHasAnimator) {
        'NotReadyMissingAnimator'
    } elseif ([string]::IsNullOrWhiteSpace($avatarPath)) {
        'NotReadyMissingResolvedAvatar'
    } elseif ($foundRequiredGroups -lt $requiredGroups) {
        'NotReadyMissingCoreClips'
    } elseif ($corePlaceholderCount -gt 0) {
        'NotReadyCoreClipsContainPlaceholders'
    } else {
        'StaticReadyForPrototypeControllerRebuild'
    }

    $candidateReports.Add([PSCustomObject]@{
        Id = $candidateId
        Status = 'Assessed'
        SourceCategory = [string]$requirement.sourceCategory
        Candidate = [string]$requirement.candidate
        ProjectPath = $projectPath
        ActorRoot = $actorRoot
        AnimationRoot = $animationRoot
        PrefabExists = [bool]$prefabExists
        PrefabHasAnimator = [bool]$prefabHasAnimator
        PrefabHasPlaceholder = [bool]$prefabHasPlaceholder
        AvatarGuid = $avatarGuid
        AvatarPath = $avatarPath
        AvatarResolved = -not [string]::IsNullOrWhiteSpace($avatarPath)
        ControllerGuid = $controllerGuid
        ControllerPath = $controllerPath
        ControllerResolved = -not [string]::IsNullOrWhiteSpace($controllerPath)
        ControllerHasPlaceholder = [bool]$controllerHasPlaceholder
        AnimationClipCount = $animFiles.Count
        AvatarAssetCount = $avatarFiles.Count
        RequiredCoreGroups = $requiredGroups
        FoundRequiredCoreGroups = $foundRequiredGroups
        CoreClipCount = $coreClipCount
        CoreAnimationClipMarkerCount = $coreAnimationClipMarkerCount
        CorePlaceholderCount = $corePlaceholderCount
        RebuildReadiness = $rebuildReadiness
        Notes = if ($rebuildReadiness -eq 'StaticReadyForPrototypeControllerRebuild') {
            'Original exported clips and avatar look sufficient for a prototype Unity controller rebuild, but this is not proof that the original Animator Controller was recovered.'
        } else {
            'Core static animation evidence is incomplete; do not rebuild or stage this actor until the missing requirement is resolved.'
        }
    }) | Out-Null
}

$summary = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    ManifestPath = $ManifestPath
    OutputRoot = $OutputRoot
    CandidateCount = $candidateReports.Count
    StaticReadyForPrototypeControllerRebuildCount = @($candidateReports.ToArray() | Where-Object { $_.RebuildReadiness -eq 'StaticReadyForPrototypeControllerRebuild' }).Count
    NotReadyCount = @($candidateReports.ToArray() | Where-Object { $_.RebuildReadiness -ne 'StaticReadyForPrototypeControllerRebuild' }).Count
    Candidates = @($candidateReports.ToArray())
    Safety = [ordered]@{
        WritesOnlyUnder = $extractedRoot
        Notes = 'This script reads exported AssetRipper actor files and writes only ignored validation reports. It does not create Unity controllers or import assets.'
    }
}

$clipCsvPath = Get-CanonicalPath (Join-Path $OutputRoot 'actor-animation-core-clips.csv')
$summaryPath = Get-CanonicalPath (Join-Path $OutputRoot 'actor-animation-rebuild-readiness-summary.json')
$markdownPath = Get-CanonicalPath (Join-Path $OutputRoot 'actor-animation-rebuild-readiness-report.md')

Assert-PathUnderOrEqual -Path $clipCsvPath -RootPath $OutputRoot -Description 'Core clip CSV'
Assert-PathUnderOrEqual -Path $summaryPath -RootPath $OutputRoot -Description 'Summary JSON'
Assert-PathUnderOrEqual -Path $markdownPath -RootPath $OutputRoot -Description 'Markdown report'

$clipRows.ToArray() | Export-Csv -LiteralPath $clipCsvPath -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$markdown = @(
    '# Actor Animation Rebuild Readiness',
    '',
    "Generated: $($summary.GeneratedAt)",
    '',
    '| Metric | Count |',
    '| --- | ---: |',
    "| Candidates | $($summary.CandidateCount) |",
    "| Static-ready for prototype controller rebuild | $($summary.StaticReadyForPrototypeControllerRebuildCount) |",
    "| Not ready | $($summary.NotReadyCount) |",
    '',
    '## Candidate Decisions',
    '',
    '| Candidate | Animator | Avatar resolved | Controller resolved | Controller placeholder | Animation clips | Required core groups | Found required groups | Core placeholders | Decision |',
    '| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |'
)
foreach ($candidate in $candidateReports.ToArray()) {
    $markdown += "| ``$($candidate.Id)`` | $($candidate.PrefabHasAnimator) | $($candidate.AvatarResolved) | $($candidate.ControllerResolved) | $($candidate.ControllerHasPlaceholder) | $($candidate.AnimationClipCount) | $($candidate.RequiredCoreGroups) | $($candidate.FoundRequiredCoreGroups) | $($candidate.CorePlaceholderCount) | ``$($candidate.RebuildReadiness)`` |"
}

$markdown += @(
    '',
    '## Core Clip Evidence',
    '',
    '| Candidate | Group | Required | Found | Selected clip | Length | Clip marker | Placeholder |',
    '| --- | --- | --- | --- | --- | ---: | --- | --- |'
)
foreach ($clip in $clipRows.ToArray()) {
    $markdown += "| ``$($clip.CandidateId)`` | ``$($clip.Group)`` | $($clip.Required) | $($clip.Found) | ``$($clip.SelectedClip)`` | $($clip.Length) | $($clip.HasAnimationClipMarker) | $($clip.HasPlaceholder) |"
}

$markdown += @(
    '',
    '## Interpretation',
    '',
    '- `StaticReadyForPrototypeControllerRebuild` means the exported original clips and Avatar are statically present for a small prototype controller rebuild.',
    '- It does not mean the original Animator Controller was recovered. The original controller remains blocked if its exported `.overrideController` still contains placeholder refs.',
    '- A controller rebuild is a repair/downgrade path for local prototyping, not a claim of exact original runtime behavior.'
)
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[PSCustomObject]@{
    CandidateCount = $summary.CandidateCount
    StaticReadyForPrototypeControllerRebuildCount = $summary.StaticReadyForPrototypeControllerRebuildCount
    NotReadyCount = $summary.NotReadyCount
    ClipCsv = $clipCsvPath
    Summary = $summaryPath
    Report = $markdownPath
    Candidates = @($candidateReports.ToArray() | Select-Object Id, AnimationClipCount, AvatarResolved, ControllerResolved, ControllerHasPlaceholder, FoundRequiredCoreGroups, RequiredCoreGroups, CorePlaceholderCount, RebuildReadiness)
} | Format-List
