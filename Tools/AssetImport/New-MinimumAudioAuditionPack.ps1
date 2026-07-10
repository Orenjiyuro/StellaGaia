[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [int]$PreviewSeconds = 18,
    [switch]$Force
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
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Convert-ToSafeFileName {
    param([Parameter(Mandatory = $true)][string]$Value)

    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $Value.ToCharArray()) {
        if ($invalid -contains $character) {
            [void]$builder.Append('_')
        } elseif ([char]::IsLetterOrDigit($character) -or $character -eq '-' -or $character -eq '_') {
            [void]$builder.Append($character)
        } else {
            [void]$builder.Append('_')
        }
    }

    return $builder.ToString().Trim('_')
}

function Convert-ToHtml {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return [System.Net.WebUtility]::HtmlEncode($Value)
}

function Convert-ToTsvField {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ($Value -replace "`t", ' ' -replace "`r?`n", ' ')
}

function Test-OutputIsFresh {
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$InputPath
    )

    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
        return $false
    }

    return (Get-Item -LiteralPath $OutputPath).LastWriteTimeUtc -ge (Get-Item -LiteralPath $InputPath).LastWriteTimeUtc
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-audio-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $repoRoot 'Tools\AssetImport\tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\MinimumAudioAuditionPack'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$previewRoot = Join-Path $ValidationRoot 'previews'
$waveformRoot = Join-Path $ValidationRoot 'waveforms'
$indexHtmlPath = Join-Path $ValidationRoot 'minimum-audio-audition-pack.html'
$reviewTsvPath = Join-Path $ValidationRoot 'minimum-audio-listening-review.tsv'
$summaryJsonPath = Join-Path $ValidationRoot 'minimum-audio-audition-pack-summary.json'

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $repoRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing audio manifest: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$tools = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$tools.sourceInstall
$ffmpeg = Get-CanonicalPath ([string]$tools.ffmpeg)
$ffprobe = Get-CanonicalPath ([string]$tools.ffprobe)
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ffmpeg -PathType Leaf)) {
    throw "Missing ffmpeg: $ffmpeg"
}
if (-not (Test-Path -LiteralPath $ffprobe -PathType Leaf)) {
    throw "Missing ffprobe: $ffprobe"
}

New-Item -ItemType Directory -Force -Path $previewRoot, $waveformRoot | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
$issues = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[object]]::new()
$previewCount = 0
$waveformCount = 0

foreach ($selection in @($manifest.selections)) {
    $id = [string]$selection.id
    $role = [string]$selection.role
    $audioPath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$selection.path)
    Assert-PathUnderOrEqual -Path $audioPath -RootPath $extractedRoot -Description "Audio selection '$id'"
    Assert-PathNotUnder -Path $audioPath -RootPath $sourceInstall -Description "Audio selection '$id'"
    if (-not (Test-Path -LiteralPath $audioPath -PathType Leaf)) {
        $issues.Add("Missing audio source for $id`: $audioPath") | Out-Null
        continue
    }

    $safeName = Convert-ToSafeFileName -Value "$id-$role"
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = Convert-ToSafeFileName -Value ([System.IO.Path]::GetFileNameWithoutExtension($audioPath))
    }

    $previewPath = Join-Path $previewRoot "$safeName.ogg"
    $waveformPath = Join-Path $waveformRoot "$safeName.png"
    Assert-PathUnderOrEqual -Path $previewPath -RootPath $ValidationRoot -Description "Preview path '$id'"
    Assert-PathUnderOrEqual -Path $waveformPath -RootPath $ValidationRoot -Description "Waveform path '$id'"

    if ($Force -or -not (Test-OutputIsFresh -OutputPath $previewPath -InputPath $audioPath)) {
        $previewArgs = @(
            '-y',
            '-hide_banner',
            '-loglevel', 'error',
            '-i', $audioPath,
            '-t', [string]$PreviewSeconds,
            '-vn',
            '-c:a', 'libvorbis',
            '-q:a', '4',
            $previewPath
        )
        & $ffmpeg @previewArgs
        if ($LASTEXITCODE -ne 0) {
            throw "ffmpeg preview generation failed for $id with exit code $LASTEXITCODE"
        }
    }

    if ($Force -or -not (Test-OutputIsFresh -OutputPath $waveformPath -InputPath $audioPath)) {
        $waveformArgs = @(
            '-y',
            '-hide_banner',
            '-loglevel', 'error',
            '-i', $audioPath,
            '-t', [string]$PreviewSeconds,
            '-filter_complex', 'aformat=channel_layouts=mono,showwavespic=s=1200x180:colors=#2f7dd1',
            '-frames:v', '1',
            $waveformPath
        )
        & $ffmpeg @waveformArgs
        if ($LASTEXITCODE -ne 0) {
            throw "ffmpeg waveform generation failed for $id with exit code $LASTEXITCODE"
        }
    }

    $probeText = & $ffprobe -v error -show_entries stream=codec_name,channels,sample_rate,duration -show_entries format=duration,size -of json $audioPath
    if ($LASTEXITCODE -ne 0) {
        throw "ffprobe failed for $id with exit code $LASTEXITCODE"
    }
    $probe = $probeText | ConvertFrom-Json
    $stream = @($probe.streams)[0]
    $duration = [double]$probe.format.duration

    if (Test-Path -LiteralPath $previewPath -PathType Leaf) {
        $previewCount++
    }
    if (Test-Path -LiteralPath $waveformPath -PathType Leaf) {
        $waveformCount++
    }

    $rows.Add([PSCustomObject]@{
        id = $id
        role = $role
        sourceBank = [string]$selection.sourceBank
        semanticStatus = [string]$selection.semanticStatus
        semanticEvidence = [string]$selection.semanticEvidence
        originalPath = $audioPath
        previewPath = $previewPath
        waveformPath = $waveformPath
        durationSeconds = [Math]::Round($duration, 6)
        channels = [int]$stream.channels
        sampleRate = [int]$stream.sample_rate
        expectedReview = 'NotReviewed'
        reviewNote = ''
    }) | Out-Null
}

$reviewLines = [System.Collections.Generic.List[string]]::new()
$reviewLines.Add("id`trole`tsourceBank`tsemanticStatus`tpreviewPath`twaveformPath`treview`tconfirmedMeaning`tnote") | Out-Null
$existingReviewsById = @{}
if (Test-Path -LiteralPath $reviewTsvPath -PathType Leaf) {
    foreach ($existingReview in @(Import-Csv -LiteralPath $reviewTsvPath -Delimiter "`t")) {
        $existingId = [string]$existingReview.id
        if (-not [string]::IsNullOrWhiteSpace($existingId)) {
            $existingReviewsById[$existingId] = $existingReview
        }
    }
}
foreach ($row in $rows) {
    $existingReview = $existingReviewsById[[string]$row.id]
    $review = if ($null -ne $existingReview -and -not [string]::IsNullOrWhiteSpace([string]$existingReview.review)) { [string]$existingReview.review } else { 'NotReviewed' }
    $confirmedMeaning = if ($null -ne $existingReview) { [string]$existingReview.confirmedMeaning } else { '' }
    $note = if ($null -ne $existingReview) { [string]$existingReview.note } else { '' }
    $reviewLines.Add(("{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}" -f
        (Convert-ToTsvField $row.id),
        (Convert-ToTsvField $row.role),
        (Convert-ToTsvField $row.sourceBank),
        (Convert-ToTsvField $row.semanticStatus),
        (Convert-ToTsvField $row.previewPath),
        (Convert-ToTsvField $row.waveformPath),
        (Convert-ToTsvField $review),
        (Convert-ToTsvField $confirmedMeaning),
        (Convert-ToTsvField $note))) | Out-Null
}
$reviewLines | Set-Content -LiteralPath $reviewTsvPath -Encoding UTF8

$htmlLines = [System.Collections.Generic.List[string]]::new()
$htmlLines.Add('<!doctype html>') | Out-Null
$htmlLines.Add('<html lang="en">') | Out-Null
$htmlLines.Add('<head><meta charset="utf-8"><title>StellaGaia Minimum Audio Audition Pack</title>') | Out-Null
$htmlLines.Add('<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;line-height:1.35;color:#202124}article{border:1px solid #d7dce2;border-radius:6px;padding:14px;margin:14px 0}img{max-width:100%;height:auto;border:1px solid #e0e0e0}audio{width:100%;margin:8px 0}code{background:#f4f6f8;padding:2px 4px;border-radius:3px}</style></head>') | Out-Null
$htmlLines.Add('<body>') | Out-Null
$htmlLines.Add('<h1>StellaGaia Minimum Audio Audition Pack</h1>') | Out-Null
$htmlLines.Add('<p>This pack supports manual listening review only. It does not prove Unity playback or Wwise event semantics.</p>') | Out-Null
foreach ($row in $rows) {
    $previewRelative = [System.IO.Path]::GetRelativePath($ValidationRoot, $row.previewPath) -replace '\\', '/'
    $waveformRelative = [System.IO.Path]::GetRelativePath($ValidationRoot, $row.waveformPath) -replace '\\', '/'
    $htmlLines.Add('<article>') | Out-Null
    $htmlLines.Add("<h2>$(Convert-ToHtml $row.id) - $(Convert-ToHtml $row.role)</h2>") | Out-Null
    $htmlLines.Add("<p><strong>Source bank:</strong> $(Convert-ToHtml $row.sourceBank)<br><strong>Semantic status:</strong> $(Convert-ToHtml $row.semanticStatus)<br><strong>Duration:</strong> $($row.durationSeconds)s, <strong>channels:</strong> $($row.channels), <strong>sample rate:</strong> $($row.sampleRate) Hz</p>") | Out-Null
    $htmlLines.Add("<p>$(Convert-ToHtml $row.semanticEvidence)</p>") | Out-Null
    $htmlLines.Add("<audio controls preload=""metadata"" src=""$previewRelative""></audio>") | Out-Null
    $htmlLines.Add("<img alt=""Waveform for $(Convert-ToHtml $row.id)"" src=""$waveformRelative"">") | Out-Null
    $htmlLines.Add('</article>') | Out-Null
}
$htmlLines.Add('</body></html>') | Out-Null
$htmlLines | Set-Content -LiteralPath $indexHtmlPath -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    validationRoot = $ValidationRoot
    previewSeconds = $PreviewSeconds
    selectionCount = @($manifest.selections).Count
    previewCount = $previewCount
    waveformCount = $waveformCount
    issueCount = $issues.Count
    issues = @($issues)
    indexHtml = $indexHtmlPath
    listeningReviewTsv = $reviewTsvPath
    summaryJson = $summaryJsonPath
    rows = @($rows)
    interpretation = 'This audition pack enables manual listening review of selected decoded WAV candidates. It is not Unity playback evidence and does not recover Wwise event mappings.'
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8
$summary

if ($issues.Count -gt 0) {
    throw "Minimum audio audition pack generated with $($issues.Count) issue(s)."
}
