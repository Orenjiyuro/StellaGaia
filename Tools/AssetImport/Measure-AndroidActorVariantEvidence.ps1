[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ComparisonCsv,
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

function Get-ActorBundlePrefix {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Requirement
    )

    $candidate = [string]$Requirement.candidate
    if ($candidate -match '(?i)actor[\\/]+character[\\/]+([^\\/]+)') {
        return "char_$($Matches[1].ToLowerInvariant())"
    }

    if ($candidate -match '(?i)actor[\\/]+monster[\\/]+([^\\/]+)') {
        return "mons_$($Matches[1].ToLowerInvariant())"
    }

    return ''
}

function Get-ExpectedActorBaseNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BundlePrefix,
        [Parameter(Mandatory = $true)]
        [string]$SourceCategory
    )

    $suffixes = if ($SourceCategory -eq 'CharacterArt') {
        @('', '_models', '_materials', '_textures', '_animations', '_fx', '_timeline', '_weapons', '_combos', '_combos_monster', '_configs', '_buff')
    } else {
        @('', '_models', '_materials', '_textures', '_animations', '_fx', '_combo', '_configs', '_weapon')
    }

    foreach ($suffix in $suffixes) {
        [PSCustomObject]@{
            BaseName = "$BundlePrefix$suffix"
            Kind = if ([string]::IsNullOrEmpty($suffix)) { 'main' } else { $suffix.TrimStart('_') }
        }
    }
}

function Get-RowByBaseName {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$RowsByBaseName,
        [Parameter(Mandatory = $true)]
        [string]$BaseName
    )

    $key = $BaseName.ToLowerInvariant()
    if (-not $RowsByBaseName.ContainsKey($key)) {
        return $null
    }

    return $RowsByBaseName[$key]
}

function Get-ActorDecision {
    param(
        [AllowNull()]
        [object]$AnimationStatus,
        [AllowNull()]
        [object]$TextureStatus
    )

    $animationPresence = if ($null -eq $AnimationStatus) { 'Missing' } else { [string]$AnimationStatus.SourcePresence }
    $texturePresence = if ($null -eq $TextureStatus) { 'Missing' } else { [string]$TextureStatus.SourcePresence }

    if ($animationPresence -eq 'AndroidOnly') {
        return 'InvestigateAndroidOnlyAnimationBundle'
    }

    if ($animationPresence -eq 'Both') {
        if ([string]$AnimationStatus.AnySameLength -eq 'False') {
            return 'InvestigateAndroidAnimationVariant'
        }

        return 'AndroidHasNoDifferentAnimationEvidence'
    }

    if ($texturePresence -eq 'Both' -and [string]$TextureStatus.AnySameLength -eq 'False') {
        return 'TextureVariantOnlyNoControllerHelp'
    }

    return 'LowAndroidHelpForControllerRecovery'
}

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $PSScriptRoot '..\..\docs\asset-migration\minimum-vertical-slice-assets.json'
}
if ([string]::IsNullOrWhiteSpace($ComparisonCsv)) {
    $ComparisonCsv = Join-Path $PSScriptRoot '..\..\Extracted\Validation\AndroidPcBundleComparison\android-pc-unity-bundle-comparison.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\AndroidActorVariantEvidence'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$docsRoot = Get-CanonicalPath (Join-Path $repoRoot 'docs')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$ManifestPath = Get-CanonicalPath $ManifestPath
$ComparisonCsv = Get-CanonicalPath $ComparisonCsv
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $docsRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $ComparisonCsv -RootPath $extractedRoot -Description 'ComparisonCsv'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing minimum vertical slice manifest: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ComparisonCsv -PathType Leaf)) {
    throw "Missing Android/PC comparison CSV: $ComparisonCsv. Run Tools\AssetImport\Compare-AndroidPcUnityBundles.ps1 first."
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$comparisonRows = @(Import-Csv -LiteralPath $ComparisonCsv)
$rowsByBaseName = @{}
foreach ($row in $comparisonRows) {
    $rowsByBaseName[[string]$row.BaseName] = $row
}

$candidateReports = New-Object System.Collections.Generic.List[object]
$statusRows = New-Object System.Collections.Generic.List[object]

foreach ($candidateId in $CandidateIds) {
    $requirement = @($manifest.minimumRequirements | Where-Object { $_.id -eq $candidateId } | Select-Object -First 1)
    if ($requirement.Count -eq 0) {
        $candidateReports.Add([PSCustomObject]@{
            Id = $candidateId
            Status = 'ManifestRequirementMissing'
            ActorBundlePrefix = ''
            Decision = 'CannotAssess'
            ExpectedBundleCount = 0
            AndroidPresentCount = 0
            PcOnlyCount = 0
            BothDifferentLengthCount = 0
            Notes = 'No matching minimum vertical-slice requirement exists.'
        }) | Out-Null
        continue
    }

    $requirement = $requirement[0]
    $prefix = Get-ActorBundlePrefix -Requirement $requirement
    if ([string]::IsNullOrWhiteSpace($prefix)) {
        $candidateReports.Add([PSCustomObject]@{
            Id = $candidateId
            Status = 'ActorPrefixNotDetected'
            ActorBundlePrefix = ''
            Decision = 'CannotAssess'
            ExpectedBundleCount = 0
            AndroidPresentCount = 0
            PcOnlyCount = 0
            BothDifferentLengthCount = 0
            Notes = "Cannot infer actor bundle prefix from candidate '$($requirement.candidate)'."
        }) | Out-Null
        continue
    }

    $expected = @(Get-ExpectedActorBaseNames -BundlePrefix $prefix -SourceCategory ([string]$requirement.sourceCategory))
    $candidateStatusRows = New-Object System.Collections.Generic.List[object]
    foreach ($expectedBundle in $expected) {
        $row = Get-RowByBaseName -RowsByBaseName $rowsByBaseName -BaseName ([string]$expectedBundle.BaseName)
        $statusRow = [PSCustomObject]@{
            CandidateId = $candidateId
            SourceCategory = [string]$requirement.sourceCategory
            ActorBundlePrefix = $prefix
            BundleKind = [string]$expectedBundle.Kind
            BaseName = [string]$expectedBundle.BaseName
            SourcePresence = if ($null -eq $row) { 'MissingFromComparison' } else { [string]$row.SourcePresence }
            PcCount = if ($null -eq $row) { 0 } else { [int]$row.PcCount }
            AndroidCount = if ($null -eq $row) { 0 } else { [int]$row.AndroidCount }
            PcLengths = if ($null -eq $row) { '' } else { [string]$row.PcLengths }
            AndroidLengths = if ($null -eq $row) { '' } else { [string]$row.AndroidLengths }
            AnySameLength = if ($null -eq $row) { $false } else { [bool]::Parse([string]$row.AnySameLength) }
            PcExample = if ($null -eq $row) { '' } else { [string]$row.PcExample }
            AndroidExample = if ($null -eq $row) { '' } else { [string]$row.AndroidExample }
        }
        $candidateStatusRows.Add($statusRow) | Out-Null
        $statusRows.Add($statusRow) | Out-Null
    }

    $candidateRows = @($candidateStatusRows.ToArray())
    $animationStatus = @($candidateRows | Where-Object { $_.BundleKind -eq 'animations' } | Select-Object -First 1)
    $textureStatus = @($candidateRows | Where-Object { $_.BundleKind -eq 'textures' } | Select-Object -First 1)
    $decision = Get-ActorDecision -AnimationStatus $(if ($animationStatus.Count -eq 0) { $null } else { $animationStatus[0] }) -TextureStatus $(if ($textureStatus.Count -eq 0) { $null } else { $textureStatus[0] })

    $candidateReports.Add([PSCustomObject]@{
        Id = $candidateId
        Status = 'Assessed'
        ActorBundlePrefix = $prefix
        Decision = $decision
        ExpectedBundleCount = $candidateRows.Count
        AndroidPresentCount = @($candidateRows | Where-Object { $_.AndroidCount -gt 0 }).Count
        PcOnlyCount = @($candidateRows | Where-Object { $_.SourcePresence -eq 'PcOnly' }).Count
        BothDifferentLengthCount = @($candidateRows | Where-Object { $_.SourcePresence -eq 'Both' -and -not $_.AnySameLength }).Count
        AnimationSourcePresence = if ($animationStatus.Count -eq 0) { 'MissingFromComparison' } else { [string]$animationStatus[0].SourcePresence }
        TextureSourcePresence = if ($textureStatus.Count -eq 0) { 'MissingFromComparison' } else { [string]$textureStatus[0].SourcePresence }
        Candidate = [string]$requirement.candidate
        Notes = switch ($decision) {
            'InvestigateAndroidOnlyAnimationBundle' { 'Android has an animation bundle that PC comparison does not show; prioritize a focused Android actor export.' }
            'InvestigateAndroidAnimationVariant' { 'Android has an animation bundle with different bytes; prioritize comparing the animation export result.' }
            'AndroidHasNoDifferentAnimationEvidence' { 'Android has an animation bundle but no different-length evidence; it may not address controller recovery.' }
            'TextureVariantOnlyNoControllerHelp' { 'Android has useful texture variant evidence, but no animation bundle evidence for controller recovery.' }
            default { 'Android comparison does not currently improve the actor controller recovery path for this candidate.' }
        }
    }) | Out-Null
}

$summary = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    ManifestPath = $ManifestPath
    ComparisonCsv = $ComparisonCsv
    OutputRoot = $OutputRoot
    CandidateCount = $candidateReports.Count
    LowControllerHelpCount = @($candidateReports.ToArray() | Where-Object { $_.Decision -in @('LowAndroidHelpForControllerRecovery', 'TextureVariantOnlyNoControllerHelp', 'AndroidHasNoDifferentAnimationEvidence') }).Count
    InvestigationCandidateCount = @($candidateReports.ToArray() | Where-Object { $_.Decision -in @('InvestigateAndroidOnlyAnimationBundle', 'InvestigateAndroidAnimationVariant') }).Count
    Candidates = @($candidateReports.ToArray())
    Safety = [ordered]@{
        WritesOnlyUnder = $extractedRoot
        Notes = 'This script reads existing comparison evidence and writes only ignored validation reports.'
    }
}

$statusCsvPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-actor-variant-status.csv')
$summaryPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-actor-variant-summary.json')
$markdownPath = Get-CanonicalPath (Join-Path $OutputRoot 'android-actor-variant-report.md')

Assert-PathUnderOrEqual -Path $statusCsvPath -RootPath $OutputRoot -Description 'Status CSV'
Assert-PathUnderOrEqual -Path $summaryPath -RootPath $OutputRoot -Description 'Summary JSON'
Assert-PathUnderOrEqual -Path $markdownPath -RootPath $OutputRoot -Description 'Markdown report'

$statusRows.ToArray() | Export-Csv -LiteralPath $statusCsvPath -NoTypeInformation -Encoding UTF8
$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8

$markdown = @(
    '# Android Actor Variant Evidence',
    '',
    "Generated: $($summary.GeneratedAt)",
    '',
    '| Metric | Count |',
    '| --- | ---: |',
    "| Candidates | $($summary.CandidateCount) |",
    "| Low controller-help candidates | $($summary.LowControllerHelpCount) |",
    "| Animation investigation candidates | $($summary.InvestigationCandidateCount) |",
    '',
    '## Candidate Decisions',
    '',
    '| Candidate | Prefix | Animation presence | Texture presence | Android present bundles | PC-only bundles | Different-length both-present bundles | Decision |',
    '| --- | --- | --- | --- | ---: | ---: | ---: | --- |'
)
foreach ($candidate in $candidateReports.ToArray()) {
    $markdown += "| ``$($candidate.Id)`` | ``$($candidate.ActorBundlePrefix)`` | ``$($candidate.AnimationSourcePresence)`` | ``$($candidate.TextureSourcePresence)`` | $($candidate.AndroidPresentCount) | $($candidate.PcOnlyCount) | $($candidate.BothDifferentLengthCount) | ``$($candidate.Decision)`` |"
}

$markdown += @(
    '',
    '## Expected Bundle Status',
    '',
    '| Candidate | Kind | Base name | Presence | PC lengths | Android lengths | PC example | Android example |',
    '| --- | --- | --- | --- | ---: | ---: | --- | --- |'
)
foreach ($row in $statusRows.ToArray()) {
    $markdown += "| ``$($row.CandidateId)`` | ``$($row.BundleKind)`` | ``$($row.BaseName)`` | ``$($row.SourcePresence)`` | ``$($row.PcLengths)`` | ``$($row.AndroidLengths)`` | ``$($row.PcExample)`` | ``$($row.AndroidExample)`` |"
}
$markdown += @(
    '',
    '## Interpretation',
    '',
    '- `LowAndroidHelpForControllerRecovery` means the Android package does not contain an actor animation bundle for this selected candidate in the current comparison evidence.',
    '- `TextureVariantOnlyNoControllerHelp` means Android may help texture comparison, but it does not address the current Animator Controller blocker.',
    '- This report does not import or extract bundles. It only narrows the next extraction attempts.'
)
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[PSCustomObject]@{
    CandidateCount = $summary.CandidateCount
    LowControllerHelpCount = $summary.LowControllerHelpCount
    InvestigationCandidateCount = $summary.InvestigationCandidateCount
    StatusCsv = $statusCsvPath
    Summary = $summaryPath
    Report = $markdownPath
    Candidates = @($candidateReports.ToArray() | Select-Object Id, ActorBundlePrefix, AnimationSourcePresence, TextureSourcePresence, AndroidPresentCount, PcOnlyCount, BothDifferentLengthCount, Decision)
} | Format-List
