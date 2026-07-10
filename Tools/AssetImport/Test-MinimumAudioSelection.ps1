[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ToolManifestPath
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

function Resolve-RepoRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return Get-CanonicalPath $Path
    }

    return Get-CanonicalPath (Join-Path $RepoRoot $Path)
}

function Read-FfprobeInfo {
    param(
        [Parameter(Mandatory = $true)][string]$FfprobePath,
        [Parameter(Mandatory = $true)][string]$AudioPath
    )

    $jsonText = & $FfprobePath -v error -show_entries stream=codec_name,channels,sample_rate,duration -show_entries format=duration,size -of json $AudioPath
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $AudioPath with exit code $LASTEXITCODE"
    }

    return $jsonText | ConvertFrom-Json
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-audio-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $repoRoot 'Tools\AssetImport\tool-manifest.json'
}

$ManifestPath = Get-CanonicalPath $ManifestPath
$ToolManifestPath = Get-CanonicalPath $ToolManifestPath
foreach ($entry in @(
    @{ Path = $ManifestPath; Label = 'ManifestPath' },
    @{ Path = $ToolManifestPath; Label = 'ToolManifestPath' }
)) {
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $entry.Path -RootPath $repoRoot)) {
        throw "$($entry.Label) must stay under repository root. Got: $($entry.Path)"
    }
    if (-not (Test-Path -LiteralPath $entry.Path -PathType Leaf)) {
        throw "Missing $($entry.Label): $($entry.Path)"
    }
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$tools = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
$ffprobe = Get-CanonicalPath ([string]$tools.ffprobe)
if (-not (Test-Path -LiteralPath $ffprobe -PathType Leaf)) {
    throw "Missing ffprobe: $ffprobe"
}

$issues = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[object]]::new()
$requiredRoles = @('CombatMusic', 'CombatSfxAttack', 'CombatSfxHit', 'CombatSfxDeath')
$roleCounts = @{}
foreach ($role in $requiredRoles) {
    $roleCounts[$role] = 0
}

$selections = @($manifest.selections)
if ($selections.Count -eq 0) {
    $issues.Add('Audio manifest has no selections.') | Out-Null
}

foreach ($selection in $selections) {
    $id = [string]$selection.id
    $role = [string]$selection.role
    if ([string]::IsNullOrWhiteSpace($id)) {
        $issues.Add('An audio selection is missing id.') | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($role)) {
        $issues.Add("Selection '$id' is missing role.") | Out-Null
    }
    if ($roleCounts.ContainsKey($role)) {
        $roleCounts[$role]++
    }

    $audioPathText = [string]$selection.path
    if ([string]::IsNullOrWhiteSpace($audioPathText)) {
        $issues.Add("Selection '$id' is missing path.") | Out-Null
        continue
    }

    $audioPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $audioPathText
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $audioPath -RootPath $repoRoot)) {
        $issues.Add("Selection '$id' points outside repository root: $audioPathText") | Out-Null
        continue
    }
    if (-not (Test-Path -LiteralPath $audioPath -PathType Leaf)) {
        $issues.Add("Selection '$id' missing WAV: $audioPathText") | Out-Null
        continue
    }

    $info = Read-FfprobeInfo -FfprobePath $ffprobe -AudioPath $audioPath
    if ($null -eq $info.streams -or @($info.streams).Count -eq 0) {
        $issues.Add("Selection '$id' has no audio stream according to ffprobe.") | Out-Null
        continue
    }

    $stream = @($info.streams)[0]
    $duration = [double]$info.format.duration
    $channels = [int]$stream.channels
    $sampleRate = [int]$stream.sample_rate
    $minDuration = [double]$selection.expected.minDurationSeconds
    $maxDuration = [double]$selection.expected.maxDurationSeconds
    $minChannels = [int]$selection.expected.minChannels

    if ($duration -lt $minDuration -or $duration -gt $maxDuration) {
        $issues.Add("Selection '$id' duration $duration is outside expected range $minDuration..$maxDuration seconds.") | Out-Null
    }
    if ($channels -lt $minChannels) {
        $issues.Add("Selection '$id' has $channels channel(s), expected at least $minChannels.") | Out-Null
    }
    if ($sampleRate -le 0) {
        $issues.Add("Selection '$id' has invalid sample rate $sampleRate.") | Out-Null
    }

    $rows.Add([PSCustomObject]@{
        Id = $id
        Role = $role
        Status = [string]$selection.status
        SemanticStatus = [string]$selection.semanticStatus
        SourceBank = [string]$selection.sourceBank
        SemanticEvidence = [string]$selection.semanticEvidence
        Path = $audioPathText
        Codec = [string]$stream.codec_name
        Channels = $channels
        SampleRate = $sampleRate
        DurationSeconds = [Math]::Round($duration, 6)
        SizeBytes = [int64]$info.format.size
    }) | Out-Null
}

foreach ($role in $requiredRoles) {
    if ([int]$roleCounts[$role] -lt 1) {
        $issues.Add("Missing required audio role: $role") | Out-Null
    }
}

$summary = [PSCustomObject]@{
    ManifestPath = $ManifestPath
    Status = [string]$manifest.status
    SemanticStatus = [string]$manifest.semanticStatus
    SelectionCount = $selections.Count
    RequiredRoleCount = $requiredRoles.Count
    MissingRequiredRoleCount = @($requiredRoles | Where-Object { [int]$roleCounts[$_] -lt 1 }).Count
    IssueCount = $issues.Count
    Issues = @($issues)
    Selections = @($rows)
}

if ($issues.Count -gt 0) {
    $summary | ConvertTo-Json -Depth 8 | Write-Output
    throw "Minimum audio selection validation failed with $($issues.Count) issue(s)."
}

$summary
