[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ValidationRoot
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

function Convert-ToTsvField {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ($Value -replace "`t", ' ' -replace "`r?`n", ' ')
}

function ConvertTo-CsvSafe {
    param([AllowEmptyCollection()][object[]]$Rows)

    if ($Rows.Count -eq 0) {
        return @()
    }

    return $Rows
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$MetaPath)

    $line = Select-String -LiteralPath $MetaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $line) {
        return $null
    }

    return $line.Matches.Groups[1].Value
}

function Get-ReferenceStatus {
    param(
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][hashtable]$GuidToAsset
    )

    if ($Guid -eq '00000000000000000000000000000000') {
        return 'ZeroGuid'
    }
    if ($Guid -eq '0000000000000000e000000000000000' -or $Guid -eq '0000000000000000f000000000000000') {
        return 'BuiltinResource'
    }
    if ($Guid -match 'deadbeef|deadf00d') {
        return 'DeadbeefGuid'
    }
    if ($GuidToAsset.ContainsKey($Guid)) {
        return 'Existing'
    }

    return 'MissingGuid'
}

function Get-PropertyName {
    param([Parameter(Mandatory = $true)][string]$Line)

    $trimmed = $Line.Trim()
    $match = [regex]::Match($trimmed, '^(?:-\s*)?([A-Za-z_][A-Za-z0-9_.$\[\]-]*)\s*:\s*\{[^{}]*guid:\s*[0-9a-f]{32}')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    $beforeGuid = $trimmed -replace '\{[^{}]*guid:\s*[0-9a-f]{32}.*$', ''
    $beforeGuid = $beforeGuid.Trim()
    if ([string]::IsNullOrWhiteSpace($beforeGuid)) {
        return '(inline)'
    }

    return $beforeGuid
}

function Get-NearestObjectHeader {
    param(
        [Parameter(Mandatory = $true)][string[]]$Lines,
        [Parameter(Mandatory = $true)][int]$LineIndex
    )

    for ($i = $LineIndex; $i -ge 0 -and $i -ge ($LineIndex - 250); $i--) {
        if ($Lines[$i] -match '^--- !u!(\d+) &(-?\d+)') {
            return $Lines[$i].Trim()
        }
    }

    return ''
}

function Get-ClassIdFromObjectHeader {
    param([AllowNull()][string]$ObjectHeader)

    if ($ObjectHeader -match '^--- !u!(\d+)') {
        return $Matches[1]
    }

    return ''
}

function Get-ReferenceKind {
    param(
        [AllowNull()][string]$PropertyName,
        [AllowNull()][string]$FileId,
        [AllowNull()][string]$ClassId
    )

    if ($PropertyName -match 'Sprite|sprite') { return 'SpriteDependency' }
    if ($PropertyName -match 'font|Font') { return 'FontOrTextDependency' }
    if ($PropertyName -match 'Material|material|m_sharedMaterial|m_fontMaterial' -or $FileId -eq '2100000') { return 'MaterialDependency' }
    if ($PropertyName -match 'Controller|Animator' -or $FileId -eq '9100000') { return 'AnimationControllerDependency' }
    if ($PropertyName -match 'Script' -or $FileId -eq '11500000') { return 'ScriptDependency' }
    if ($PropertyName -match 'Fx|FX|Effect|Particle|idleFx|takeEffectFx') { return 'EffectPrefabDependency' }
    if ($ClassId -eq '114') { return 'MonoBehaviourReference' }
    return 'OtherDependency'
}

function Get-PrefabRiskDecision {
    param(
        [int]$DeadbeefCount,
        [int]$MissingGuidCount,
        [int]$RendererTokenCount,
        [AllowEmptyCollection()][string[]]$DeadbeefProperties
    )

    $optionalFxNames = @('idleFx', 'takeEffectFx')
    $nonEmptyDeadbeefProperties = @($DeadbeefProperties | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
    $onlyMissingFx = $nonEmptyDeadbeefProperties.Count -gt 0
    foreach ($property in $nonEmptyDeadbeefProperties) {
        if ($optionalFxNames -notcontains $property) {
            $onlyMissingFx = $false
            break
        }
    }

    if ($DeadbeefCount -eq 0 -and $MissingGuidCount -eq 0 -and $RendererTokenCount -gt 0) {
        return 'StaticRenderableNeedsUnityVisibleValidation'
    }
    if ($DeadbeefCount -eq 0 -and $MissingGuidCount -eq 0) {
        return 'StaticPrefabNeedsUnityVisibleValidation'
    }
    if ($onlyMissingFx -and $RendererTokenCount -eq 0) {
        return 'VisualDependsOnMissingFxPrefab'
    }
    if ($onlyMissingFx -and $RendererTokenCount -gt 0) {
        return 'OptionalFxPlaceholderNeedsUnityVisibleValidation'
    }
    if ($DeadbeefCount -ge 50 -or $MissingGuidCount -gt 0) {
        return 'HighRiskDependencyClosureRequired'
    }

    return 'RepairCandidateNeedsDependencyClosure'
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# UI Reward Prefab Static Risk Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Prefab count | $($Summary.prefabCount) |") | Out-Null
    $lines.Add("| Low-risk prefab count | $($Summary.lowRiskPrefabCount) |") | Out-Null
    $lines.Add("| High-risk prefab count | $($Summary.highRiskPrefabCount) |") | Out-Null
    $lines.Add("| Visual-missing prefab count | $($Summary.visualMissingPrefabCount) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Prefabs') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Role | Decision | Renderers | Deadbeef | Missing GUIDs | Existing refs | Main deadbeef properties |') | Out-Null
    $lines.Add('| --- | --- | --- | ---: | ---: | ---: | ---: | --- |') | Out-Null
    foreach ($prefab in $Summary.prefabs) {
        $lines.Add("| $($prefab.id) | $($prefab.role) | $($prefab.decision) | $($prefab.rendererTokenCount) | $($prefab.deadbeefReferenceCount) | $($prefab.missingGuidReferenceCount) | $($prefab.existingReferenceCount) | `$($prefab.deadbeefProperties)` |") | Out-Null
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
$docsRoot = Join-Path $repoRoot 'docs'
$extractedRoot = Join-Path $repoRoot 'Extracted'
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $docsRoot 'asset-migration\minimum-ui-reward-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\UiRewardPrefabStaticRiskGate'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $docsRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
Assert-PathNotUnder -Path $ManifestPath -RootPath $sourceInstall -Description 'ManifestPath'
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing UI/reward manifest: $ManifestPath"
}

New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
$sourceExport = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$manifest.sourceExport)
Assert-PathUnderOrEqual -Path $sourceExport -RootPath $extractedRoot -Description 'sourceExport'
Assert-PathNotUnder -Path $sourceExport -RootPath $sourceInstall -Description 'sourceExport'

$guidToAsset = @{}
Get-ChildItem -LiteralPath $sourceExport -Recurse -File -Filter '*.meta' | ForEach-Object {
    $guid = Get-MetaGuid -MetaPath $_.FullName
    if ([string]::IsNullOrWhiteSpace($guid)) {
        return
    }

    $assetFullPath = $_.FullName.Substring(0, $_.FullName.Length - 5)
    if (-not $guidToAsset.ContainsKey($guid)) {
        $guidToAsset[$guid] = [System.IO.Path]::GetRelativePath($sourceExport, $assetFullPath).Replace('\', '/')
    }
}

$issues = [System.Collections.Generic.List[string]]::new()
$prefabRows = [System.Collections.Generic.List[object]]::new()
$referenceRows = [System.Collections.Generic.List[object]]::new()
$deadbeefContextRows = [System.Collections.Generic.List[object]]::new()

foreach ($selection in @($manifest.selections | Where-Object { [string]$_.kind -eq 'Prefab' })) {
    $id = [string]$selection.id
    $assetPath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$selection.path)
    Assert-PathUnderOrEqual -Path $assetPath -RootPath $sourceExport -Description "Prefab selection '$id'"
    Assert-PathNotUnder -Path $assetPath -RootPath $sourceInstall -Description "Prefab selection '$id'"
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        $issues.Add("Missing prefab selection '$id': $assetPath") | Out-Null
        continue
    }

    $content = Get-Content -LiteralPath $assetPath -Raw
    $lines = [string[]](Get-Content -LiteralPath $assetPath)
    $relativePath = [System.IO.Path]::GetRelativePath($sourceExport, $assetPath).Replace('\', '/')

    $gameObjectCount = ([regex]::Matches($content, '(?m)^GameObject:')).Count
    $rectTransformCount = ([regex]::Matches($content, '(?m)^RectTransform:')).Count
    $monoBehaviourCount = ([regex]::Matches($content, '(?m)^MonoBehaviour:')).Count
    $canvasRendererCount = ([regex]::Matches($content, '(?m)^CanvasRenderer:')).Count
    $meshRendererCount = ([regex]::Matches($content, '(?m)^MeshRenderer:')).Count
    $spriteRendererCount = ([regex]::Matches($content, '(?m)^SpriteRenderer:')).Count
    $particleRendererCount = ([regex]::Matches($content, '(?m)^ParticleSystemRenderer:')).Count
    $rendererTokenCount = $canvasRendererCount + $meshRendererCount + $spriteRendererCount + $particleRendererCount

    $statusCounts = @{
        Existing = 0
        MissingGuid = 0
        DeadbeefGuid = 0
        BuiltinResource = 0
        ZeroGuid = 0
    }
    $deadbeefProperties = [System.Collections.Generic.List[string]]::new()
    $referencePattern = 'guid:\s*([0-9a-f]{32})'
    $fileIdPattern = 'fileID:\s*(-?\d+)'
    $typePattern = 'type:\s*(\d+)'

    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $matches = [regex]::Matches($line, $referencePattern)
        if ($matches.Count -eq 0) {
            continue
        }

        $fileIdMatch = [regex]::Match($line, $fileIdPattern)
        $typeMatch = [regex]::Match($line, $typePattern)
        $fileId = if ($fileIdMatch.Success) { $fileIdMatch.Groups[1].Value } else { '' }
        $type = if ($typeMatch.Success) { $typeMatch.Groups[1].Value } else { '' }
        $propertyName = Get-PropertyName -Line $line
        $objectHeader = Get-NearestObjectHeader -Lines $lines -LineIndex $index
        $classId = Get-ClassIdFromObjectHeader -ObjectHeader $objectHeader
        $referenceKind = Get-ReferenceKind -PropertyName $propertyName -FileId $fileId -ClassId $classId

        foreach ($match in $matches) {
            $guid = $match.Groups[1].Value.ToLowerInvariant()
            $referenceStatus = Get-ReferenceStatus -Guid $guid -GuidToAsset $guidToAsset
            if (-not $statusCounts.ContainsKey($referenceStatus)) {
                $statusCounts[$referenceStatus] = 0
            }
            $statusCounts[$referenceStatus]++
            $targetAsset = if ($guidToAsset.ContainsKey($guid)) { [string]$guidToAsset[$guid] } else { '' }

            $referenceRow = [PSCustomObject]@{
                id = $id
                role = [string]$selection.role
                prefabPath = $relativePath
                lineNumber = $index + 1
                propertyName = $propertyName
                referenceKind = $referenceKind
                fileId = $fileId
                guid = $guid
                type = $type
                status = $referenceStatus
                targetAsset = $targetAsset
                line = $line.Trim()
            }
            $referenceRows.Add($referenceRow) | Out-Null

            if ($referenceStatus -eq 'DeadbeefGuid') {
                $deadbeefProperties.Add($propertyName) | Out-Null
                $deadbeefContextRows.Add($referenceRow) | Out-Null
            }
        }
    }

    $uniqueDeadbeefProperties = @($deadbeefProperties | Sort-Object -Unique)
    $decision = Get-PrefabRiskDecision -DeadbeefCount ([int]$statusCounts.DeadbeefGuid) -MissingGuidCount ([int]$statusCounts.MissingGuid) -RendererTokenCount $rendererTokenCount -DeadbeefProperties $uniqueDeadbeefProperties
    $canUseForPrototypePrefab = $decision -in @('StaticRenderableNeedsUnityVisibleValidation', 'OptionalFxPlaceholderNeedsUnityVisibleValidation')

    $prefabRows.Add([PSCustomObject]@{
        id = $id
        role = [string]$selection.role
        path = $relativePath
        decision = $decision
        canUseForPrototypePrefab = $canUseForPrototypePrefab
        gameObjectCount = $gameObjectCount
        rectTransformCount = $rectTransformCount
        monoBehaviourCount = $monoBehaviourCount
        canvasRendererCount = $canvasRendererCount
        meshRendererCount = $meshRendererCount
        spriteRendererCount = $spriteRendererCount
        particleRendererCount = $particleRendererCount
        rendererTokenCount = $rendererTokenCount
        guidReferenceCount = ($referenceRows | Where-Object { $_.id -eq $id }).Count
        existingReferenceCount = [int]$statusCounts.Existing
        missingGuidReferenceCount = [int]$statusCounts.MissingGuid
        deadbeefReferenceCount = [int]$statusCounts.DeadbeefGuid
        builtinResourceReferenceCount = [int]$statusCounts.BuiltinResource
        zeroGuidReferenceCount = [int]$statusCounts.ZeroGuid
        deadbeefProperties = ($uniqueDeadbeefProperties -join ';')
    }) | Out-Null
}

$prefabs = @($prefabRows)
$highRisk = @($prefabs | Where-Object { [string]$_.decision -eq 'HighRiskDependencyClosureRequired' })
$visualMissing = @($prefabs | Where-Object { [string]$_.decision -eq 'VisualDependsOnMissingFxPrefab' })
$lowRisk = @($prefabs | Where-Object { [bool]$_.canUseForPrototypePrefab })
$gateStatus = 'NoPrefabSelections'
$nextRequiredAction = 'No selected UI/reward prefabs were found.'

if ($issues.Count -gt 0) {
    $gateStatus = 'StaticInputFailed'
    $nextRequiredAction = 'Fix missing selected prefab inputs before UI/reward validation.'
} elseif ($prefabs.Count -gt 0 -and $highRisk.Count -gt 0) {
    $gateStatus = 'HighRiskDependencyClosureRequired'
    $nextRequiredAction = 'Do not import high-risk UI prefabs into the runtime project. Either close dependencies in a focused slice, rebuild UI using accepted texture candidates, or wait for Unity visible validation.'
} elseif ($prefabs.Count -gt 0 -and $visualMissing.Count -gt 0) {
    $gateStatus = 'PrefabVisualsDependOnMissingFx'
    $nextRequiredAction = 'Treat selected drop prefabs as controller/anchor data only. Use accepted texture candidates or Unity-built replacements for visible reward drops until missing FX prefabs are recovered.'
} elseif ($prefabs.Count -gt 0 -and $lowRisk.Count -eq $prefabs.Count) {
    $gateStatus = 'StaticReadyNeedsUnityVisibleValidation'
    $nextRequiredAction = 'Run selected UI/reward Unity visible validation before accepting any prefab.'
}

$referenceCsv = Join-Path $ValidationRoot 'ui-reward-prefab-references.csv'
$deadbeefCsv = Join-Path $ValidationRoot 'ui-reward-prefab-deadbeef-context.csv'
$prefabCsv = Join-Path $ValidationRoot 'ui-reward-prefab-static-risk.csv'
$summaryJson = Join-Path $ValidationRoot 'ui-reward-prefab-static-risk-summary.json'
$reportPath = Join-Path $ValidationRoot 'ui-reward-prefab-static-risk-report.md'

ConvertTo-CsvSafe -Rows @($prefabRows) | Export-Csv -LiteralPath $prefabCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($referenceRows) | Export-Csv -LiteralPath $referenceCsv -NoTypeInformation -Encoding UTF8
ConvertTo-CsvSafe -Rows @($deadbeefContextRows) | Export-Csv -LiteralPath $deadbeefCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    sourceExport = $sourceExport
    validationRoot = $ValidationRoot
    gateStatus = $gateStatus
    prefabCount = $prefabs.Count
    lowRiskPrefabCount = $lowRisk.Count
    highRiskPrefabCount = $highRisk.Count
    visualMissingPrefabCount = $visualMissing.Count
    issueCount = $issues.Count
    issues = @($issues)
    prefabCsv = $prefabCsv
    referenceCsv = $referenceCsv
    deadbeefContextCsv = $deadbeefCsv
    summaryJson = $summaryJson
    reportPath = $reportPath
    prefabs = @($prefabs)
    interpretation = 'This is a static YAML/meta risk classifier for selected UI/reward prefabs. It does not instantiate prefabs, render UI, recover scripts, or prove development usability.'
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "UI/reward prefab static risk gate failed with $($issues.Count) issue(s)."
}
