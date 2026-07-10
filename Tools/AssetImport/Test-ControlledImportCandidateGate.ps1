[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ValidationRoot,
    [switch]$RunUnity,
    [ValidateSet('DirectOnly', 'Closure')]
    [string]$CopyPlanMode = 'DirectOnly',
    [string[]]$CandidateId,
    [int]$MaxClosureAssetCount = 200
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

function Test-IsExtractedWorkspacePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $full = Get-CanonicalPath $Path
    if (Test-IsPathUnderOrEqual -CandidatePath $full -RootPath $extractedRoot) {
        return $true
    }

    return $full -match '(?i)(^|[\\/])Extracted([\\/]|$)'
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

function Add-Issue {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Issues,
        [Parameter(Mandatory = $true)][string]$Message
    )

    $Issues.Add($Message) | Out-Null
}

function Get-NumberProperty {
    param(
        [object]$Object,
        [string]$Name,
        [double]$Default = 0.0
    )

    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        return $Default
    }

    $result = 0.0
    if ([double]::TryParse([string]$Object.$Name, [ref]$result)) {
        return $result
    }

    return $Default
}

function Convert-ToTsvField {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ($Value -replace "`t", ' ' -replace "`r?`n", ' ')
}

function New-ControlledImportPath {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Candidate
    )

    $leaf = Split-Path -Leaf ($Candidate.Replace('\', '/'))
    if ([string]::IsNullOrWhiteSpace($leaf)) {
        $leaf = "$Id.prefab"
    }

    return "Assets/StellaGaia/Imported/ControlledCandidates/$Id/$leaf"
}

function Assert-SafeProjectAssetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '^Assets[/\\].+') {
        throw "Project asset path must start with Assets/: $Path"
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        throw "Project asset path must not be rooted: $Path"
    }
    foreach ($segment in ($Path -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Project asset path contains an unsafe segment: $Path"
        }
    }
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$MetaPath)

    $line = Select-String -LiteralPath $MetaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $line) {
        return $null
    }

    return $line.Matches.Groups[1].Value
}

function Get-GuidReferences {
    param([Parameter(Mandatory = $true)][string]$Path)

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    $textExtensions = @(
        '.anim',
        '.asmdef',
        '.asset',
        '.controller',
        '.cs',
        '.lighting',
        '.mat',
        '.overridecontroller',
        '.playable',
        '.prefab',
        '.shader',
        '.unity'
    )
    if ($textExtensions -notcontains $extension) {
        return @()
    }

    try {
        return Select-String -LiteralPath $Path -Pattern 'guid: ([0-9a-f]{32})' -AllMatches |
            ForEach-Object { $_.Matches.Groups[1].Value } |
            Sort-Object -Unique
    }
    catch {
        return @()
    }
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

function Resolve-GuidAssetPath {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$Guid,
        [Parameter(Mandatory = $true)][hashtable]$GuidToAssetCache
    )

    if ($GuidToAssetCache.ContainsKey($Guid)) {
        return $GuidToAssetCache[$Guid]
    }

    $assetsRoot = Join-Path $ProjectPath 'Assets'
    $metaPath = $null
    $rg = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $rg) {
        $metaPath = & $rg.Source --files-with-matches --fixed-strings -g '*.meta' "guid: $Guid" $assetsRoot 2>$null | Select-Object -First 1
    } else {
        $metaPath = Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -Filter '*.meta' |
            Select-String -Pattern "^guid: $Guid$" -List |
            Select-Object -First 1 -ExpandProperty Path
    }

    if ([string]::IsNullOrWhiteSpace($metaPath)) {
        $GuidToAssetCache[$Guid] = ''
        return ''
    }

    $metaFullPath = Get-CanonicalPath $metaPath
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $metaFullPath -RootPath $ProjectPath)) {
        $GuidToAssetCache[$Guid] = ''
        return ''
    }

    $assetFullPath = $metaFullPath.Substring(0, $metaFullPath.Length - 5)
    if (-not (Test-Path -LiteralPath $assetFullPath -PathType Leaf)) {
        $GuidToAssetCache[$Guid] = ''
        return ''
    }

    $assetPath = $assetFullPath.Substring($ProjectPath.Length + 1).Replace('\', '/')
    $GuidToAssetCache[$Guid] = $assetPath
    return $assetPath
}

function Get-GuidAssetIndex {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    $guidToAsset = @{}
    $assetsRoot = Join-Path $ProjectPath 'Assets'
    $rg = Get-Command rg -ErrorAction SilentlyContinue
    if ($null -ne $rg) {
        $lines = & $rg.Source -n --no-heading -g '*.meta' '^guid: [0-9a-f]{32}$' $assetsRoot
        foreach ($line in $lines) {
            $match = [regex]::Match([string]$line, '^(?<meta>.*?\.meta):\d+:guid: (?<guid>[0-9a-f]{32})$')
            if (-not $match.Success) {
                continue
            }

            $metaFullPath = Get-CanonicalPath $match.Groups['meta'].Value
            if (-not (Test-IsPathUnderOrEqual -CandidatePath $metaFullPath -RootPath $ProjectPath)) {
                continue
            }

            $assetFullPath = $metaFullPath.Substring(0, $metaFullPath.Length - 5)
            if (-not (Test-Path -LiteralPath $assetFullPath -PathType Leaf)) {
                continue
            }

            $guid = $match.Groups['guid'].Value
            if (-not $guidToAsset.ContainsKey($guid)) {
                $guidToAsset[$guid] = $assetFullPath.Substring($ProjectPath.Length + 1).Replace('\', '/')
            }
        }

        return $guidToAsset
    }

    Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -Filter '*.meta' | ForEach-Object {
        $guid = Get-MetaGuid -MetaPath $_.FullName
        if ([string]::IsNullOrWhiteSpace($guid)) {
            return
        }

        $assetFullPath = $_.FullName.Substring(0, $_.FullName.Length - 5)
        if (-not (Test-Path -LiteralPath $assetFullPath -PathType Leaf)) {
            return
        }

        if (-not $guidToAsset.ContainsKey($guid)) {
            $guidToAsset[$guid] = $assetFullPath.Substring($ProjectPath.Length + 1).Replace('\', '/')
        }
    }

    return $guidToAsset
}

function New-CopyPlan {
    param(
        [Parameter(Mandatory = $true)][string]$CandidateId,
        [Parameter(Mandatory = $true)][string]$SourceProjectPath,
        [Parameter(Mandatory = $true)][string]$RootAssetPath,
        [Parameter(Mandatory = $true)][hashtable]$GuidToAsset,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$AssetRows,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$MissingRows,
        [int]$MaxAssetCount = 200
    )

    Assert-SafeProjectAssetPath -Path $RootAssetPath

    $queue = [System.Collections.Generic.Queue[string]]::new()
    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue.Enqueue($RootAssetPath.Replace('\', '/'))

    $assetCount = 0
    $totalBytes = 0L
    $missingGuidCount = 0
    $deadbeefGuidCount = 0
    $zeroGuidCount = 0
    $limitHit = $false

    while ($queue.Count -gt 0) {
        $assetPath = $queue.Dequeue()
        if (-not $visited.Add($assetPath)) {
            continue
        }

        if ($assetCount -ge $MaxAssetCount) {
            $limitHit = $true
            $MissingRows.Add([PSCustomObject]@{
                CandidateId = $CandidateId
                SourceAssetPath = $assetPath
                Guid = ''
                TargetStatus = 'ClosureAssetLimitHit'
                TargetAssetPath = ''
            }) | Out-Null
            break
        }

        $sourceFile = Join-Path $SourceProjectPath $assetPath
        if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
            $missingGuidCount++
            $MissingRows.Add([PSCustomObject]@{
                CandidateId = $CandidateId
                SourceAssetPath = $assetPath
                Guid = ''
                TargetStatus = 'MissingAssetPath'
                TargetAssetPath = ''
            }) | Out-Null
            continue
        }

        $item = Get-Item -LiteralPath $sourceFile
        $assetCount++
        $totalBytes += $item.Length
        $AssetRows.Add([PSCustomObject]@{
            CandidateId = $CandidateId
            SourceProjectPath = $SourceProjectPath
            SourceAssetPath = $assetPath
            Length = $item.Length
        }) | Out-Null

        foreach ($guid in Get-GuidReferences -Path $sourceFile) {
            $status = Get-ReferenceStatus -Guid $guid -GuidToAsset $GuidToAsset
            if ($status -eq 'Existing') {
                $queue.Enqueue($GuidToAsset[$guid])
            } elseif ($status -eq 'ZeroGuid') {
                $zeroGuidCount++
            } elseif ($guid -eq '0000000000000000e000000000000000' -or $guid -eq '0000000000000000f000000000000000') {
                continue
            } elseif ($status -ne 'BuiltinResource') {
                if ($status -eq 'DeadbeefGuid') {
                    $deadbeefGuidCount++
                } else {
                    $missingGuidCount++
                }
                $MissingRows.Add([PSCustomObject]@{
                    CandidateId = $CandidateId
                    SourceAssetPath = $assetPath
                    Guid = $guid
                    TargetStatus = $status
                    TargetAssetPath = ''
                }) | Out-Null
            }
        }
    }

    return [PSCustomObject]@{
        AssetCount = $assetCount
        TotalBytes = $totalBytes
        MissingGuidCount = $missingGuidCount
        DeadbeefGuidCount = $deadbeefGuidCount
        ZeroGuidCount = $zeroGuidCount
        LimitHit = $limitHit
        QueueRemaining = $queue.Count
    }
}

function New-DirectCopyPlan {
    param(
        [Parameter(Mandatory = $true)][string]$CandidateId,
        [Parameter(Mandatory = $true)][string]$SourceProjectPath,
        [Parameter(Mandatory = $true)][string]$RootAssetPath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$AssetRows,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$MissingRows
    )

    Assert-SafeProjectAssetPath -Path $RootAssetPath
    $sourceFile = Join-Path $SourceProjectPath $RootAssetPath
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) {
        $MissingRows.Add([PSCustomObject]@{
            CandidateId = $CandidateId
            SourceAssetPath = $RootAssetPath
            Guid = ''
            TargetStatus = 'MissingAssetPath'
            TargetAssetPath = ''
        }) | Out-Null
        return [PSCustomObject]@{
            AssetCount = 0
            TotalBytes = 0
            MissingGuidCount = 1
            DeadbeefGuidCount = 0
            ZeroGuidCount = 0
            DirectGuidCount = 0
            DirectUniqueGuidCount = 0
        }
    }

    $item = Get-Item -LiteralPath $sourceFile
    $AssetRows.Add([PSCustomObject]@{
        CandidateId = $CandidateId
        SourceProjectPath = $SourceProjectPath
        SourceAssetPath = $RootAssetPath
        Length = $item.Length
    }) | Out-Null

    $guidRefs = @(Get-GuidReferences -Path $sourceFile)
    $deadbeefGuidCount = 0
    $zeroGuidCount = 0
    foreach ($guid in $guidRefs) {
        if ($guid -eq '00000000000000000000000000000000') {
            $zeroGuidCount++
        } elseif ($guid -match 'deadbeef|deadf00d') {
            $deadbeefGuidCount++
            $MissingRows.Add([PSCustomObject]@{
                CandidateId = $CandidateId
                SourceAssetPath = $RootAssetPath
                Guid = $guid
                TargetStatus = 'DeadbeefGuid'
                TargetAssetPath = ''
            }) | Out-Null
        }
    }

    return [PSCustomObject]@{
        AssetCount = 1
        TotalBytes = $item.Length
        MissingGuidCount = 0
        DeadbeefGuidCount = $deadbeefGuidCount
        ZeroGuidCount = $zeroGuidCount
        DirectGuidCount = $guidRefs.Count
        DirectUniqueGuidCount = @($guidRefs | Sort-Object -Unique).Count
    }
}

function Find-SampleForCandidate {
    param(
        [Parameter(Mandatory = $true)][object]$Validation,
        [Parameter(Mandatory = $true)][string]$Candidate
    )

    $candidateText = $Candidate.Replace('\', '/')
    $candidateLeaf = Split-Path -Leaf $candidateText
    foreach ($sample in @($Validation.samples)) {
        $samplePath = ([string]$sample.path).Replace('\', '/')
        if ($samplePath.Equals($candidateText, [System.StringComparison]::OrdinalIgnoreCase) -or
            $samplePath.EndsWith('/' + $candidateText, [System.StringComparison]::OrdinalIgnoreCase) -or
            $samplePath.EndsWith('/' + $candidateLeaf, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $sample
        }
    }

    return $null
}

function Write-GateReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Controlled Import Candidate Gate') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Copy plan mode | $($Summary.copyPlanMode) |") | Out-Null
    $lines.Add("| Candidate count | $($Summary.candidateCount) |") | Out-Null
    $lines.Add("| Static ready count | $($Summary.staticReadyCount) |") | Out-Null
    $lines.Add("| Staged root ready count | $($Summary.stagedRootReadyCount) |") | Out-Null
    $lines.Add("| Static issue count | $($Summary.staticIssueCount) |") | Out-Null
    $lines.Add("| Copy plan asset count | $($Summary.copyPlanAssetCount) |") | Out-Null
    $lines.Add("| Copy plan missing refs | $($Summary.copyPlanMissingReferenceCount) |") | Out-Null
    $lines.Add("| Can clear candidate blocking | $($Summary.canClearCandidateBlockingStatus) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('## Candidates') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Id | Candidate | Static ready | Staged root ready | Staged asset | Staged meta | Non-bg ratio | Magenta ratio |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- | --- | ---: | ---: |') | Out-Null
    foreach ($candidate in $Summary.candidates) {
        $candidatePath = ([string]$candidate.candidate) -replace '\|', '/'
        $lines.Add("| $($candidate.id) | $candidatePath | $($candidate.staticReady) | $($candidate.stagedRootReady) | $($candidate.stagedAssetExists) | $($candidate.stagedMetaExists) | $($candidate.nonBackgroundPixelRatio) | $($candidate.magentaPixelRatio) |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    $lines.Add('') | Out-Null
    if ($Summary.staticIssues.Count -eq 0) {
        $lines.Add('None.') | Out-Null
    } else {
        foreach ($issue in $Summary.staticIssues) {
            $lines.Add("- $issue") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Next Required Action') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add($Summary.nextRequiredAction) | Out-Null

    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Join-Path $repoRoot 'Extracted'
$toolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
$toolManifest = Read-JsonFile -Path $toolManifestPath
$sourceInstall = if ($null -ne $toolManifest) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }

if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-vertical-slice-assets.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\ControlledImportCandidateGate'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
Assert-PathUnderOrEqual -Path $ManifestPath -Root $repoRoot -Label 'ManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -Root $extractedRoot -Label 'ValidationRoot'
Assert-PathNotUnder -Path $ValidationRoot -Root $sourceInstall -Label 'ValidationRoot'

$candidateFilter = @($CandidateId | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$isDefaultOutput = $CopyPlanMode -eq 'DirectOnly' -and $candidateFilter.Count -eq 0
$gateOutput = $ValidationRoot
if (-not $isDefaultOutput) {
    $safeFilter = if ($candidateFilter.Count -eq 0) { 'all' } else { ($candidateFilter -join '_') }
    $safeFilter = $safeFilter -replace '[^A-Za-z0-9_.-]', '_'
    $gateOutput = Join-Path $ValidationRoot ("Runs\{0}-{1}" -f $CopyPlanMode, $safeFilter)
}
$gateOutput = Get-CanonicalPath $gateOutput
Assert-PathUnderOrEqual -Path $gateOutput -Root $extractedRoot -Label 'GateOutput'
Assert-PathNotUnder -Path $gateOutput -Root $sourceInstall -Label 'GateOutput'

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing minimum vertical-slice manifest: $ManifestPath"
}

New-Item -ItemType Directory -Force -Path $gateOutput | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
$issues = [System.Collections.Generic.List[string]]::new()
$candidateRows = [System.Collections.Generic.List[object]]::new()
$copyPlanAssetRows = [System.Collections.Generic.List[object]]::new()
$copyPlanMissingRows = [System.Collections.Generic.List[object]]::new()
$guidIndexByProject = @{}

$candidateRequirements = @($manifest.minimumRequirements | Where-Object {
    [string]$_.status -eq 'CandidateReadyForControlledImport' -and
    ($candidateFilter.Count -eq 0 -or [string]$_.id -in $candidateFilter)
})
if ($candidateRequirements.Count -eq 0) {
    Add-Issue -Issues $issues -Message 'Minimum vertical-slice manifest has no CandidateReadyForControlledImport entries.'
}

foreach ($requirement in $candidateRequirements) {
    $id = [string]$requirement.id
    $candidate = [string]$requirement.candidate
    $controlledImportPath = [string]$requirement.controlledImportPath
    $rowIssues = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace($id)) {
        Add-Issue -Issues $rowIssues -Message 'Candidate requirement is missing id.'
    }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        Add-Issue -Issues $rowIssues -Message "Candidate requirement '$id' is missing candidate."
    }
    if ([string]::IsNullOrWhiteSpace($controlledImportPath) -and -not [string]::IsNullOrWhiteSpace($id) -and -not [string]::IsNullOrWhiteSpace($candidate)) {
        $controlledImportPath = New-ControlledImportPath -Id $id -Candidate $candidate
    }
    if ([string]::IsNullOrWhiteSpace($controlledImportPath) -or -not $controlledImportPath.Replace('\', '/').StartsWith('Assets/', [System.StringComparison]::Ordinal)) {
        Add-Issue -Issues $rowIssues -Message "Candidate '$id' has invalid controlledImportPath: $controlledImportPath"
    }

    $validationPath = $null
    $screenshotPath = $null
    foreach ($evidence in @($requirement.evidence)) {
        $evidenceText = [string]$evidence
        if ([string]::IsNullOrWhiteSpace($evidenceText)) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' contains an empty evidence path."
            continue
        }

        $resolved = Resolve-RepoPath -RepoRoot $repoRoot -Path $evidenceText
        if (-not (Test-IsPathUnderOrEqual -CandidatePath $resolved -RootPath $repoRoot)) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' evidence points outside repository root: $evidenceText"
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' evidence is missing: $evidenceText"
            continue
        }

        if ((Split-Path -Leaf $resolved) -eq 'validation.json') {
            $validationPath = $resolved
        }
        if ([System.IO.Path]::GetExtension($resolved).Equals('.png', [System.StringComparison]::OrdinalIgnoreCase)) {
            $screenshotPath = $resolved
        }
    }

    if ([string]::IsNullOrWhiteSpace($validationPath)) {
        Add-Issue -Issues $rowIssues -Message "Candidate '$id' lacks validation.json evidence."
    }
    if ([string]::IsNullOrWhiteSpace($screenshotPath)) {
        Add-Issue -Issues $rowIssues -Message "Candidate '$id' lacks screenshot PNG evidence."
    }

    $sample = $null
    $sourceProjectPath = ''
    $sourceAssetPath = ''
    $copyPlan = [PSCustomObject]@{
        AssetCount = 0
        TotalBytes = 0
        MissingGuidCount = 0
        DeadbeefGuidCount = 0
        ZeroGuidCount = 0
        LimitHit = $false
        QueueRemaining = 0
    }
    if (-not [string]::IsNullOrWhiteSpace($validationPath)) {
        $validation = Read-JsonFile -Path $validationPath
        if ($null -eq $validation) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' validation JSON could not be read."
        } else {
            $sourceProjectPath = Get-CanonicalPath ([string]$validation.projectPath)
            if (-not (Test-IsExtractedWorkspacePath -Path $sourceProjectPath)) {
                Add-Issue -Issues $rowIssues -Message "Candidate '$id' source project is outside an Extracted workspace: $sourceProjectPath"
            } elseif ((Test-Path -LiteralPath $sourceInstall) -and (Test-IsPathUnderOrEqual -CandidatePath $sourceProjectPath -RootPath $sourceInstall)) {
                Add-Issue -Issues $rowIssues -Message "Candidate '$id' source project is under source install: $sourceProjectPath"
            } elseif (-not (Test-Path -LiteralPath (Join-Path $sourceProjectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) {
                Add-Issue -Issues $rowIssues -Message "Candidate '$id' source project is missing ProjectSettings/ProjectVersion.txt: $sourceProjectPath"
            } elseif ($CopyPlanMode -eq 'Closure' -and -not $guidIndexByProject.ContainsKey($sourceProjectPath)) {
                $guidIndexByProject[$sourceProjectPath] = Get-GuidAssetIndex -ProjectPath $sourceProjectPath
            }

            $sample = Find-SampleForCandidate -Validation $validation -Candidate $candidate
            if ($null -eq $sample) {
                Add-Issue -Issues $rowIssues -Message "Candidate '$id' is not present in validation samples: $candidate"
            } else {
                $sourceAssetPath = ([string]$sample.path).Replace('\', '/')
                if (-not (Test-Path -LiteralPath (Join-Path $sourceProjectPath $sourceAssetPath) -PathType Leaf)) {
                    Add-Issue -Issues $rowIssues -Message "Candidate '$id' source asset is missing in export project: $sourceAssetPath"
                } elseif ($CopyPlanMode -eq 'DirectOnly') {
                    $copyPlan = New-DirectCopyPlan `
                        -CandidateId $id `
                        -SourceProjectPath $sourceProjectPath `
                        -RootAssetPath $sourceAssetPath `
                        -AssetRows $copyPlanAssetRows `
                        -MissingRows $copyPlanMissingRows
                    if ([int]$copyPlan.DeadbeefGuidCount -gt 0) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' direct copy plan has $($copyPlan.DeadbeefGuidCount) deadbeef/deadf00d reference(s)."
                    }
                } elseif ($guidIndexByProject.ContainsKey($sourceProjectPath)) {
                    $copyPlan = New-CopyPlan `
                        -CandidateId $id `
                        -SourceProjectPath $sourceProjectPath `
                        -RootAssetPath $sourceAssetPath `
                        -GuidToAsset $guidIndexByProject[$sourceProjectPath] `
                        -AssetRows $copyPlanAssetRows `
                        -MissingRows $copyPlanMissingRows `
                        -MaxAssetCount $MaxClosureAssetCount
                    if ([int]$copyPlan.MissingGuidCount -gt 0) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' copy plan has $($copyPlan.MissingGuidCount) missing GUID reference(s)."
                    }
                    if ([int]$copyPlan.DeadbeefGuidCount -gt 0) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' copy plan has $($copyPlan.DeadbeefGuidCount) deadbeef/deadf00d reference(s)."
                    }
                    if ([bool]$copyPlan.LimitHit) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' copy plan hit MaxClosureAssetCount=$MaxClosureAssetCount before closure completed."
                    }
                }
            }
        }
    }

    $rendered = $false
    $visible = $false
    $criticalIssueCount = 0
    $missingMaterialSlotCount = 0
    $missingMeshCount = 0
    $missingAnimatorControllerCount = 0
    $magentaPixelRatio = 0.0
    $nonBackgroundPixelRatio = 0.0
    $controlledImportFullPath = ''
    $controlledImportMetaPath = ''
    $stagedAssetExists = $false
    $stagedMetaExists = $false
    $stagedMetaGuid = ''
    $sourceRootMetaGuid = ''
    $stagedMetaGuidMatchesSource = $false
    $stagedRootReady = $false

    if ($null -ne $sample) {
        $rendered = [bool]$sample.rendered
        $visible = [bool]$sample.visible
        $criticalIssueCount = [int](Get-NumberProperty -Object $sample -Name 'criticalIssueCount')
        $missingMaterialSlotCount = [int](Get-NumberProperty -Object $sample -Name 'missingMaterialSlotCount')
        $missingMeshCount = [int](Get-NumberProperty -Object $sample -Name 'missingMeshCount')
        $missingAnimatorControllerCount = [int](Get-NumberProperty -Object $sample -Name 'missingAnimatorControllerCount')
        $magentaPixelRatio = Get-NumberProperty -Object $sample -Name 'magentaPixelRatio'
        $nonBackgroundPixelRatio = Get-NumberProperty -Object $sample -Name 'nonBackgroundPixelRatio'

        if (-not $rendered) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' did not render in prior validation."
        }
        if (-not $visible) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' was not visible in prior validation."
        }
        if ($criticalIssueCount -gt 0) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' still has $criticalIssueCount sampled critical issue(s)."
        }
        if ($missingMaterialSlotCount -gt 0) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' has $missingMaterialSlotCount missing material slot(s)."
        }
        if ($missingMeshCount -gt 0) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' has $missingMeshCount missing mesh reference(s)."
        }
        if ($missingAnimatorControllerCount -gt 0) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' has $missingAnimatorControllerCount missing Animator Controller reference(s)."
        }
        if ($magentaPixelRatio -gt 0.001) {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' has magenta pixel ratio above threshold: $magentaPixelRatio"
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($controlledImportPath) -and $controlledImportPath.Replace('\', '/').StartsWith('Assets/', [System.StringComparison]::Ordinal)) {
        $controlledImportPathNormalized = $controlledImportPath.Replace('\', '/')
        try {
            Assert-SafeProjectAssetPath -Path $controlledImportPathNormalized
            $controlledImportFullPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $controlledImportPathNormalized
            $controlledImportMetaPath = "$controlledImportFullPath.meta"
            if (-not (Test-IsPathUnderOrEqual -CandidatePath $controlledImportFullPath -RootPath $repoRoot)) {
                Add-Issue -Issues $rowIssues -Message "Candidate '$id' controlled import target escapes repository root: $controlledImportPathNormalized"
            } else {
                $stagedAssetExists = Test-Path -LiteralPath $controlledImportFullPath -PathType Leaf
                $stagedMetaExists = Test-Path -LiteralPath $controlledImportMetaPath -PathType Leaf
                if ($stagedMetaExists) {
                    $stagedMetaGuid = [string](Get-MetaGuid -MetaPath $controlledImportMetaPath)
                }

                if (-not [string]::IsNullOrWhiteSpace($sourceProjectPath) -and -not [string]::IsNullOrWhiteSpace($sourceAssetPath)) {
                    $sourceRootMetaPath = Join-Path $sourceProjectPath "$sourceAssetPath.meta"
                    if (Test-Path -LiteralPath $sourceRootMetaPath -PathType Leaf) {
                        $sourceRootMetaGuid = [string](Get-MetaGuid -MetaPath $sourceRootMetaPath)
                    }
                }

                if ($stagedAssetExists -and -not $stagedMetaExists) {
                    Add-Issue -Issues $rowIssues -Message "Candidate '$id' has a staged controlled import asset but no matching .meta: $controlledImportMetaPath"
                } elseif ($stagedMetaExists -and -not $stagedAssetExists) {
                    Add-Issue -Issues $rowIssues -Message "Candidate '$id' has a staged controlled import .meta but no matching asset: $controlledImportFullPath"
                } elseif ($stagedAssetExists -and $stagedMetaExists) {
                    if ([string]::IsNullOrWhiteSpace($sourceRootMetaGuid)) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' is staged but the source root meta guid could not be read."
                    } elseif (-not $stagedMetaGuid.Equals($sourceRootMetaGuid, [System.StringComparison]::OrdinalIgnoreCase)) {
                        Add-Issue -Issues $rowIssues -Message "Candidate '$id' staged meta guid does not match source root meta guid. staged=$stagedMetaGuid source=$sourceRootMetaGuid"
                    } else {
                        $stagedMetaGuidMatchesSource = $true
                        $stagedRootReady = $true
                    }
                }
            }
        }
        catch {
            Add-Issue -Issues $rowIssues -Message "Candidate '$id' controlled import staging audit failed: $($_.Exception.Message)"
        }
    }

    foreach ($rowIssue in $rowIssues) {
        Add-Issue -Issues $issues -Message $rowIssue
    }

    $candidateRows.Add([PSCustomObject]@{
        id = $id
        candidate = $candidate
        sourceCategory = [string]$requirement.sourceCategory
        sourceProjectPath = $sourceProjectPath
        sourceAssetPath = $sourceAssetPath
        controlledImportPath = $controlledImportPath.Replace('\', '/')
        controlledImportFullPath = $controlledImportFullPath
        controlledImportMetaPath = $controlledImportMetaPath
        stagedAssetExists = $stagedAssetExists
        stagedMetaExists = $stagedMetaExists
        stagedMetaGuid = $stagedMetaGuid
        sourceRootMetaGuid = $sourceRootMetaGuid
        stagedMetaGuidMatchesSource = $stagedMetaGuidMatchesSource
        stagedRootReady = $stagedRootReady
        copyPlanAssetCount = [int]$copyPlan.AssetCount
        copyPlanTotalBytes = [long]$copyPlan.TotalBytes
        copyPlanMissingGuidCount = [int]$copyPlan.MissingGuidCount
        copyPlanDeadbeefGuidCount = [int]$copyPlan.DeadbeefGuidCount
        copyPlanZeroGuidCount = [int]$copyPlan.ZeroGuidCount
        copyPlanDirectGuidCount = if ($copyPlan.PSObject.Properties.Name -contains 'DirectGuidCount') { [int]$copyPlan.DirectGuidCount } else { 0 }
        copyPlanDirectUniqueGuidCount = if ($copyPlan.PSObject.Properties.Name -contains 'DirectUniqueGuidCount') { [int]$copyPlan.DirectUniqueGuidCount } else { 0 }
        copyPlanLimitHit = if ($copyPlan.PSObject.Properties.Name -contains 'LimitHit') { [bool]$copyPlan.LimitHit } else { $false }
        copyPlanQueueRemaining = if ($copyPlan.PSObject.Properties.Name -contains 'QueueRemaining') { [int]$copyPlan.QueueRemaining } else { 0 }
        validationJson = $validationPath
        screenshot = $screenshotPath
        rendered = $rendered
        visible = $visible
        criticalIssueCount = $criticalIssueCount
        missingMaterialSlotCount = $missingMaterialSlotCount
        missingMeshCount = $missingMeshCount
        missingAnimatorControllerCount = $missingAnimatorControllerCount
        magentaPixelRatio = $magentaPixelRatio
        nonBackgroundPixelRatio = $nonBackgroundPixelRatio
        staticReady = ($rowIssues.Count -eq 0)
        issueCount = $rowIssues.Count
        issues = @($rowIssues)
    }) | Out-Null
}

$copyPlanAssetsCsv = Join-Path $gateOutput 'controlled-import-copy-plan-assets.csv'
$copyPlanMissingCsv = Join-Path $gateOutput 'controlled-import-copy-plan-missing.csv'
$copyPlanAssetRows | Export-Csv -LiteralPath $copyPlanAssetsCsv -NoTypeInformation -Encoding UTF8
$copyPlanMissingRows | Export-Csv -LiteralPath $copyPlanMissingCsv -NoTypeInformation -Encoding UTF8

$candidateListPath = Join-Path $gateOutput 'controlled-import-candidates.tsv'
$candidateListLines = [System.Collections.Generic.List[string]]::new()
$candidateListLines.Add("id`tsourceCategory`tsourceCandidate`tcontrolledImportPath") | Out-Null
foreach ($candidateRow in $candidateRows) {
    $candidateListLines.Add(("{0}`t{1}`t{2}`t{3}" -f
        (Convert-ToTsvField $candidateRow.id),
        (Convert-ToTsvField $candidateRow.sourceCategory),
        (Convert-ToTsvField $candidateRow.candidate),
        (Convert-ToTsvField $candidateRow.controlledImportPath))) | Out-Null
}
$candidateListLines | Set-Content -LiteralPath $candidateListPath -Encoding UTF8

$unity = [ordered]@{
    status = if ($RunUnity) { 'Pending' } else { 'NotRun' }
    candidateList = $candidateListPath
    validationJson = Join-Path $gateOutput 'unity-controlled-import-validation.json'
    validationText = Join-Path $gateOutput 'unity-controlled-import-validation.txt'
    unityLog = Join-Path $gateOutput 'unity-controlled-import.log'
    candidateCount = 0
    loadedPrefabCount = 0
    instantiatedCount = 0
    usableCandidateCount = 0
    criticalIssueCount = 0
    licenseBlocked = $false
    freshValidation = $false
}

if ($RunUnity -and $issues.Count -eq 0) {
    $unityEditor = Get-CanonicalPath ([string]$toolManifest.unityEditor)
    if (-not (Test-Path -LiteralPath $unityEditor -PathType Leaf)) {
        throw "Missing Unity editor: $unityEditor"
    }

    $startedAt = Get-Date
    $arguments = @(
        '-batchmode',
        '-quit',
        '-projectPath', $repoRoot,
        '-executeMethod', 'StellaGaia.EditorTools.ControlledImportCandidateValidator.Run',
        '-logFile', $unity.unityLog,
        '-stellaGaiaControlledImportCandidateList', $candidateListPath,
        '-stellaGaiaControlledImportOutput', $gateOutput
    )

    $process = Start-Process -FilePath $unityEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
    if (Test-Path -LiteralPath $unity.unityLog -PathType Leaf) {
        $unity.licenseBlocked = [bool](Select-String -LiteralPath $unity.unityLog -Pattern 'No valid Unity Editor license found' -Quiet)
    }

    $unityReport = Read-JsonFile -Path $unity.validationJson
    if ($null -ne $unityReport) {
        $validationInfo = Get-Item -LiteralPath $unity.validationJson
        $unity.freshValidation = $validationInfo.LastWriteTime -ge $startedAt.AddSeconds(-2)
        $unity.candidateCount = [int]$unityReport.candidateCount
        $unity.loadedPrefabCount = [int]$unityReport.loadedPrefabCount
        $unity.instantiatedCount = [int]$unityReport.instantiatedCount
        $unity.usableCandidateCount = [int]$unityReport.usableCandidateCount
        $unity.criticalIssueCount = [int]$unityReport.criticalIssueCount
    }

    if ($unity.licenseBlocked) {
        $unity.status = 'BlockedUnityLicense'
    } elseif ($process.ExitCode -ne 0 -and -not $unity.freshValidation) {
        $unity.status = 'UnityValidationFailed'
    } elseif (-not $unity.freshValidation) {
        $unity.status = 'MissingFreshUnityValidation'
    } elseif ($unity.criticalIssueCount -gt 0) {
        $unity.status = 'ControlledImportHasIssues'
    } elseif ($unity.usableCandidateCount -eq $candidateRequirements.Count) {
        $unity.status = 'ControlledImportPassed'
    } else {
        $unity.status = 'ControlledImportIncomplete'
    }
}

$staticReadyCount = @($candidateRows | Where-Object { [bool]$_.staticReady }).Count
$stagedRootReadyCount = @($candidateRows | Where-Object { [bool]$_.stagedRootReady }).Count
$stagedAssetCount = @($candidateRows | Where-Object { [bool]$_.stagedAssetExists }).Count
$stagedMetaCount = @($candidateRows | Where-Object { [bool]$_.stagedMetaExists }).Count
$gateStatus = 'StaticReadyNeedsControlledProjectImport'
$nextRequiredAction = 'Create a controlled Unity project import proof for these exact candidates before clearing CandidateReadyForControlledImport blocking status.'
$canClearCandidateBlockingStatus = $false
if ($issues.Count -gt 0) {
    $gateStatus = 'StaticFailed'
    $nextRequiredAction = 'Fix candidate evidence, validation samples, or screenshots before attempting controlled project import.'
} elseif ($RunUnity -and $unity.status -eq 'BlockedUnityLicense') {
    $gateStatus = 'BlockedUnityLicense'
    $nextRequiredAction = 'Activate the Unity editor license, then rerun this script with -RunUnity.'
} elseif ($RunUnity -and $unity.status -eq 'ControlledImportPassed') {
    $gateStatus = 'PassedControlledProjectImport'
    $canClearCandidateBlockingStatus = $true
    $nextRequiredAction = 'Candidate blocking status may be cleared for these exact imported prefabs only; do not batch import the source categories.'
} elseif ($RunUnity) {
    $gateStatus = $unity.status
    $nextRequiredAction = 'Inspect the Unity controlled import validation output, import or repair only the exact candidates, then rerun this gate.'
} elseif ($CopyPlanMode -eq 'DirectOnly') {
    $nextRequiredAction = 'Direct copy-plan evidence is clean, but full dependency closure is not proven. Create a controlled Unity project import proof for these exact candidates before clearing CandidateReadyForControlledImport blocking status.'
}

$summaryJson = Join-Path $gateOutput 'controlled-import-candidate-gate-summary.json'
$reportPath = Join-Path $gateOutput 'controlled-import-candidate-gate-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    validationRoot = $ValidationRoot
    gateOutput = $gateOutput
    runUnity = [bool]$RunUnity
    copyPlanMode = $CopyPlanMode
    candidateFilter = @($candidateFilter)
    maxClosureAssetCount = $MaxClosureAssetCount
    gateStatus = $gateStatus
    summaryJson = $summaryJson
    reportPath = $reportPath
    candidateCount = $candidateRequirements.Count
    staticReadyCount = $staticReadyCount
    stagedRootReadyCount = $stagedRootReadyCount
    stagedAssetCount = $stagedAssetCount
    stagedMetaCount = $stagedMetaCount
    staticIssueCount = $issues.Count
    staticIssues = @($issues)
    candidateList = $candidateListPath
    copyPlanAssetsCsv = $copyPlanAssetsCsv
    copyPlanMissingCsv = $copyPlanMissingCsv
    copyPlanAssetCount = $copyPlanAssetRows.Count
    copyPlanMissingReferenceCount = $copyPlanMissingRows.Count
    candidates = @($candidateRows)
    unity = [PSCustomObject]$unity
    canClearCandidateBlockingStatus = $canClearCandidateBlockingStatus
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
Write-GateReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Controlled import candidate gate failed static validation with $($issues.Count) issue(s)."
}
