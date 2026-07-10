[CmdletBinding()]
param(
    [string]$SelectionPath,
    [string]$BankRoot,
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

function Get-BankChunks {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    $chunks = [System.Collections.Generic.List[object]]::new()
    $position = 0
    while ($position -le $Bytes.Length - 8) {
        $chunkId = [System.Text.Encoding]::ASCII.GetString($Bytes, $position, 4)
        $size = [System.BitConverter]::ToUInt32($Bytes, $position + 4)
        $dataStart = $position + 8
        $dataEnd = [Math]::Min($dataStart + [int64]$size, $Bytes.Length)

        $chunks.Add([PSCustomObject]@{
            id = $chunkId
            size = [int64]$size
            dataStart = [int64]$dataStart
            dataEnd = [int64]$dataEnd
        }) | Out-Null

        $next = $dataEnd
        if ($next -le $position) {
            break
        }
        $position = [int]$next
    }

    return @($chunks)
}

function Get-DidxMediaIds {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)]$Chunks
    )

    $didx = @($Chunks | Where-Object { $_.id -eq 'DIDX' } | Select-Object -First 1)
    if ($didx.Count -eq 0) {
        return @()
    }

    $mediaIds = [System.Collections.Generic.List[uint32]]::new()
    for ($position = [int64]$didx[0].dataStart; $position -le [int64]$didx[0].dataEnd - 12; $position += 12) {
        $mediaIds.Add([uint32][System.BitConverter]::ToUInt32($Bytes, [int]$position)) | Out-Null
    }

    return @($mediaIds)
}

function Find-BytePatternOffsets {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)][byte[]]$Pattern
    )

    $offsets = [System.Collections.Generic.List[int]]::new()
    if ($Pattern.Length -eq 0 -or $Bytes.Length -lt $Pattern.Length) {
        return @()
    }

    for ($i = 0; $i -le $Bytes.Length - $Pattern.Length; $i++) {
        $matched = $true
        for ($j = 0; $j -lt $Pattern.Length; $j++) {
            if ($Bytes[$i + $j] -ne $Pattern[$j]) {
                $matched = $false
                break
            }
        }
        if ($matched) {
            $offsets.Add($i) | Out-Null
        }
    }

    return @($offsets)
}

function Get-ChunkIdForOffset {
    param(
        [Parameter(Mandatory = $true)]$Chunks,
        [int]$Offset
    )

    $chunk = @($Chunks | Where-Object { $Offset -ge [int]$_.dataStart -and $Offset -lt [int]$_.dataEnd } | Select-Object -First 1)
    if ($chunk.Count -eq 0) {
        return ''
    }

    return [string]$chunk[0].id
}

function Get-StringsNearOffset {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [int]$Offset,
        [int]$Radius = 384
    )

    $start = [Math]::Max(0, $Offset - $Radius)
    $end = [Math]::Min($Bytes.Length - 1, $Offset + $Radius)
    $length = $end - $start + 1
    if ($length -le 0) {
        return @()
    }

    $window = New-Object byte[] $length
    [System.Array]::Copy($Bytes, $start, $window, 0, $length)
    $strings = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $ascii = [System.Text.Encoding]::ASCII.GetString($window)
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($ascii, '[A-Za-z0-9_./:-]{3,}')) {
        $value = $match.Value.Trim('.','/','-',':','_')
        if ($value.Length -ge 3) {
            $strings.Add($value) | Out-Null
        }
    }

    $unicode = [System.Text.Encoding]::Unicode.GetString($window)
    foreach ($match in [System.Text.RegularExpressions.Regex]::Matches($unicode, '[A-Za-z0-9_./:-]{3,}')) {
        $value = $match.Value.Trim('.','/','-',':','_')
        if ($value.Length -ge 3) {
            $strings.Add($value) | Out-Null
        }
    }

    return @($strings | Sort-Object)
}

function Get-RoleKeywords {
    param([Parameter(Mandatory = $true)][string]$Role)

    switch -Regex ($Role) {
        'Music' { return @('music', 'combat', 'battle', 'bgm', 'loop') }
        'Attack' { return @('attack', 'atk', 'skill', 'shoot', 'fire', 'slash', 'hit') }
        'Hit' { return @('impact', 'hit', 'hurt', 'damage', 'atk') }
        'Death' { return @('die', 'death', 'dead', 'kill', 'monster') }
        'Voice' { return @('voice', 'vo', 'combat', 'ult', 'skill') }
        default { return @('combat', 'battle') }
    }
}

function Test-KeywordMatch {
    param(
        [Parameter(Mandatory = $true)][string[]]$Strings,
        [Parameter(Mandatory = $true)][string[]]$Keywords
    )

    $matches = [System.Collections.Generic.List[string]]::new()
    foreach ($keyword in $Keywords) {
        foreach ($string in $Strings) {
            if ($string.IndexOf($keyword, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
                $matches.Add($keyword) | Out-Null
                break
            }
        }
    }

    return @($matches | Sort-Object -Unique)
}

function Write-HintReport {
    param(
        [Parameter(Mandatory = $true)][object]$Summary,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Minimum Audio Semantic Hints') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('This report is bank/media provenance evidence only. It does not replace manual listening, Wwise event recovery, or Unity AudioClip playback validation.') | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Field | Value |') | Out-Null
    $lines.Add('| --- | --- |') | Out-Null
    $lines.Add("| Gate status | $($Summary.gateStatus) |") | Out-Null
    $lines.Add("| Selection count | $($Summary.selectionCount) |") | Out-Null
    $lines.Add("| Media indexed count | $($Summary.mediaIndexedCount) |") | Out-Null
    $lines.Add("| Role hint count | $($Summary.roleHintCount) |") | Out-Null
    $lines.Add("| Issue count | $($Summary.issueCount) |") | Out-Null
    $lines.Add('') | Out-Null
    $lines.Add('| Selection | Role | Bank | Media ID | DIDX | Hint status | Role hints |') | Out-Null
    $lines.Add('| --- | --- | --- | ---: | --- | --- | --- |') | Out-Null
    foreach ($row in $Summary.rows) {
        $lines.Add("| $($row.id) | $($row.role) | $($row.sourceBank) | $($row.mediaId) | $($row.mediaInDidx) | $($row.semanticHintStatus) | $($row.roleKeywordMatches -join ', ') |") | Out-Null
    }
    $lines.Add('') | Out-Null
    $lines.Add('## Issues') | Out-Null
    if ($Summary.issues.Count -eq 0) {
        $lines.Add('') | Out-Null
        $lines.Add('- None.') | Out-Null
    } else {
        foreach ($issue in $Summary.issues) {
            $lines.Add("- $issue") | Out-Null
        }
    }
    $lines.Add('') | Out-Null
    $lines.Add("Next required action: $($Summary.nextRequiredAction)") | Out-Null
    $lines | Set-Content -LiteralPath $Path -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($SelectionPath)) {
    $SelectionPath = Join-Path $repoRoot 'docs\asset-migration\minimum-audio-selection.json'
}
if ([string]::IsNullOrWhiteSpace($BankRoot)) {
    $BankRoot = Join-Path $extractedRoot 'RawAssets\Persistent_Store\SoundBanks'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\MinimumAudioSemanticHints'
}

$SelectionPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $SelectionPath
$BankRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $BankRoot
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot

$toolManifest = Read-JsonFile -Path (Join-Path $PSScriptRoot 'tool-manifest.json')
$sourceInstall = if ($null -ne $toolManifest -and -not [string]::IsNullOrWhiteSpace([string]$toolManifest.sourceInstall)) { [string]$toolManifest.sourceInstall } else { 'C:\SoftGame\YostarGames\StellaSora_CN' }
$sourceInstall = Get-CanonicalPath $sourceInstall

Assert-PathUnderOrEqual -Path $SelectionPath -RootPath $repoRoot -Description 'SelectionPath'
Assert-PathUnderOrEqual -Path $BankRoot -RootPath $extractedRoot -Description 'BankRoot'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'

if (-not (Test-Path -LiteralPath $SelectionPath -PathType Leaf)) {
    throw "Missing minimum audio selection: $SelectionPath"
}
if (-not (Test-Path -LiteralPath $BankRoot -PathType Container)) {
    throw "Missing Wwise bank root: $BankRoot"
}

[void][System.IO.Directory]::CreateDirectory($ValidationRoot)

$selection = Get-Content -LiteralPath $SelectionPath -Raw | ConvertFrom-Json
$issues = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[object]]::new()
$bankCache = @{}

foreach ($entry in @($selection.selections)) {
    $sourceBank = [string]$entry.sourceBank
    $bankFileName = if ($sourceBank -match '^[^\\/]+\.bnk$') { $sourceBank } else { '' }
    $wavPathText = [string]$entry.path
    $mediaIdText = [System.IO.Path]::GetFileNameWithoutExtension($wavPathText)
    $mediaId = 0
    $hasNumericMediaId = [uint32]::TryParse($mediaIdText, [ref]$mediaId)
    $keywords = @(Get-RoleKeywords -Role ([string]$entry.role))
    $bankNameStrings = @($sourceBank, [string]$entry.id, [string]$entry.role, [string]$entry.semanticEvidence, $wavPathText)
    $stringsNearMedia = @()
    $roleMatches = @(Test-KeywordMatch -Strings $bankNameStrings -Keywords $keywords)
    $mediaInDidx = $false
    $mediaReferenceCount = 0
    $mediaReferenceChunks = @()
    $bankPath = ''
    $semanticHintStatus = 'NoBankMediaMapping'

    if ([string]::IsNullOrWhiteSpace($bankFileName)) {
        if ($wavPathText.IndexOf('combat', [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or $wavPathText.IndexOf('ultskill', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            $semanticHintStatus = 'FilenameSemanticHintOnly'
        }
    } elseif (-not $hasNumericMediaId) {
        $semanticHintStatus = 'BankPresentButNoNumericMediaId'
        $bankPath = Get-CanonicalPath (Join-Path $BankRoot $bankFileName)
        Add-IssueIf -Issues $issues -Condition (-not (Test-Path -LiteralPath $bankPath -PathType Leaf)) -Message "Missing source bank for $($entry.id): $bankPath"
    } else {
        $bankPath = Get-CanonicalPath (Join-Path $BankRoot $bankFileName)
        Assert-PathUnderOrEqual -Path $bankPath -RootPath $BankRoot -Description 'Bank path'
        if (-not (Test-Path -LiteralPath $bankPath -PathType Leaf)) {
            Add-IssueIf -Issues $issues -Condition $true -Message "Missing source bank for $($entry.id): $bankPath"
        } else {
            if (-not $bankCache.ContainsKey($bankPath)) {
                $bytes = [System.IO.File]::ReadAllBytes($bankPath)
                $chunks = @(Get-BankChunks -Bytes $bytes)
                $mediaIds = @(Get-DidxMediaIds -Bytes $bytes -Chunks $chunks)
                $bankCache[$bankPath] = [PSCustomObject]@{
                    bytes = $bytes
                    chunks = $chunks
                    mediaIds = $mediaIds
                }
            }

            $bank = $bankCache[$bankPath]
            $mediaInDidx = @($bank.mediaIds | Where-Object { [uint32]$_ -eq [uint32]$mediaId }).Count -gt 0
            $pattern = [System.BitConverter]::GetBytes([uint32]$mediaId)
            $offsets = @(Find-BytePatternOffsets -Bytes $bank.bytes -Pattern $pattern)
            $mediaReferenceCount = $offsets.Count
            $mediaReferenceChunks = @($offsets | ForEach-Object { Get-ChunkIdForOffset -Chunks $bank.chunks -Offset $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
            foreach ($offset in @($offsets | Select-Object -First 8)) {
                foreach ($text in Get-StringsNearOffset -Bytes $bank.bytes -Offset $offset) {
                    $stringsNearMedia += $text
                }
            }
            $stringsNearMedia = @($stringsNearMedia | Sort-Object -Unique)
            $roleMatches = @(Test-KeywordMatch -Strings @($bankNameStrings + $stringsNearMedia) -Keywords $keywords)

            if ($mediaInDidx -and $roleMatches.Count -gt 0) {
                $semanticHintStatus = 'MediaIndexedByExpectedBankWithRoleHints'
            } elseif ($mediaInDidx) {
                $semanticHintStatus = 'MediaIndexedByExpectedBank'
            } else {
                $semanticHintStatus = 'MediaNotIndexedByExpectedBank'
            }
        }
    }

    $rows.Add([PSCustomObject]@{
        id = [string]$entry.id
        role = [string]$entry.role
        sourceBank = $sourceBank
        bankPath = $bankPath
        mediaId = if ($hasNumericMediaId) { [string]$mediaId } else { '' }
        mediaInDidx = $mediaInDidx
        mediaReferenceCount = $mediaReferenceCount
        mediaReferenceChunks = @($mediaReferenceChunks)
        semanticHintStatus = $semanticHintStatus
        roleKeywordMatches = @($roleMatches)
        stringsNearMedia = @($stringsNearMedia | Select-Object -First 30)
        interpretation = 'Semantic hints are candidate-screening evidence only; they do not prove the in-game event role without listening/event mapping.'
    }) | Out-Null
}

$selectionCount = $rows.Count
$mediaIndexedCount = @($rows | Where-Object { $_.mediaInDidx }).Count
$roleHintCount = @($rows | Where-Object { @($_.roleKeywordMatches).Count -gt 0 }).Count
Add-IssueIf -Issues $issues -Condition ($selectionCount -eq 0) -Message 'Minimum audio selection has no rows.'
Add-IssueIf -Issues $issues -Condition ($mediaIndexedCount -lt 4) -Message "Expected at least 4 numeric selected media rows to be indexed by their source banks, got $mediaIndexedCount."

$gateStatus = if ($issues.Count -eq 0) { 'SemanticHintsReadyNeedsListeningAndUnityPlayback' } else { 'SemanticHintsIncomplete' }
$nextRequiredAction = 'Use this report only to prioritize listening and Unity playback validation. Manual listening or Wwise event recovery is still required for SFX roles, and Test-AudioReuseGate.ps1 -RunUnity is still required for Unity playback.'
$summaryJson = Join-Path $ValidationRoot 'minimum-audio-semantic-hints-summary.json'
$csvPath = Join-Path $ValidationRoot 'minimum-audio-semantic-hints.csv'
$reportPath = Join-Path $ValidationRoot 'minimum-audio-semantic-hints-report.md'

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    selectionPath = $SelectionPath
    bankRoot = $BankRoot
    validationRoot = $ValidationRoot
    gateStatus = $gateStatus
    selectionCount = $selectionCount
    mediaIndexedCount = $mediaIndexedCount
    roleHintCount = $roleHintCount
    issueCount = $issues.Count
    issues = @($issues)
    rows = @($rows)
    summaryJson = $summaryJson
    csvPath = $csvPath
    reportPath = $reportPath
    nextRequiredAction = $nextRequiredAction
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
$rows | Select-Object id,role,sourceBank,mediaId,mediaInDidx,mediaReferenceCount,@{Name='mediaReferenceChunks';Expression={$_.mediaReferenceChunks -join ';'}},semanticHintStatus,@{Name='roleKeywordMatches';Expression={$_.roleKeywordMatches -join ';'}} | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
Write-HintReport -Summary $summary -Path $reportPath

$summary

if ($issues.Count -gt 0) {
    throw "Minimum audio semantic hints failed with $($issues.Count) issue(s)."
}
