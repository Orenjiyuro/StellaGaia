[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [int]$MaxPreviewSize = 512,
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

function Measure-ImageContent {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Image)

    $sampleCount = 0
    $alphaCount = 0
    $opaqueCount = 0
    $nonWhiteCount = 0
    $nonTransparentNonWhiteCount = 0
    $xStep = [Math]::Max(1, [Math]::Floor($Image.Width / 96))
    $yStep = [Math]::Max(1, [Math]::Floor($Image.Height / 96))

    for ($y = 0; $y -lt $Image.Height; $y += $yStep) {
        for ($x = 0; $x -lt $Image.Width; $x += $xStep) {
            $sampleCount++
            $pixel = $Image.GetPixel($x, $y)
            $hasAlpha = $pixel.A -gt 0
            $isOpaque = $pixel.A -gt 220
            $isNonWhite = $pixel.R -lt 245 -or $pixel.G -lt 245 -or $pixel.B -lt 245
            if ($hasAlpha) {
                $alphaCount++
            }
            if ($isOpaque) {
                $opaqueCount++
            }
            if ($isNonWhite) {
                $nonWhiteCount++
            }
            if ($hasAlpha -and $isNonWhite) {
                $nonTransparentNonWhiteCount++
            }
        }
    }

    if ($sampleCount -eq 0) {
        return [PSCustomObject]@{
            alphaSampleRatio = 0.0
            opaqueSampleRatio = 0.0
            nonWhiteSampleRatio = 0.0
            visibleContentSampleRatio = 0.0
        }
    }

    return [PSCustomObject]@{
        alphaSampleRatio = [Math]::Round($alphaCount / [double]$sampleCount, 6)
        opaqueSampleRatio = [Math]::Round($opaqueCount / [double]$sampleCount, 6)
        nonWhiteSampleRatio = [Math]::Round($nonWhiteCount / [double]$sampleCount, 6)
        visibleContentSampleRatio = [Math]::Round($nonTransparentNonWhiteCount / [double]$sampleCount, 6)
    }
}

function Save-CheckerboardPreview {
    param(
        [Parameter(Mandatory = $true)][string]$InputPath,
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][int]$MaxSize
    )

    $image = [System.Drawing.Bitmap]::FromFile($InputPath)
    try {
        $scale = [Math]::Min($MaxSize / [double]$image.Width, $MaxSize / [double]$image.Height)
        if ($scale -gt 1.0) {
            $scale = 1.0
        }
        $width = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
        $height = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))
        $preview = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($preview)
            try {
                $cell = 16
                $light = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 238, 238, 238))
                $dark = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 190, 190, 190))
                try {
                    for ($y = 0; $y -lt $height; $y += $cell) {
                        for ($x = 0; $x -lt $width; $x += $cell) {
                            $brush = if ((([Math]::Floor($x / $cell) + [Math]::Floor($y / $cell)) % 2) -eq 0) { $light } else { $dark }
                            $graphics.FillRectangle($brush, $x, $y, [Math]::Min($cell, $width - $x), [Math]::Min($cell, $height - $y))
                        }
                    }
                    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.DrawImage($image, 0, 0, $width, $height)
                } finally {
                    $light.Dispose()
                    $dark.Dispose()
                }
            } finally {
                $graphics.Dispose()
            }

            $preview.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        } finally {
            $preview.Dispose()
        }
    } finally {
        $image.Dispose()
    }
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
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-ui-reward-selection.json'
}
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $repoRoot 'Tools\AssetImport\tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\MinimumUiRewardVisualReviewPack'
}

$ManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ManifestPath
$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$previewRoot = Join-Path $ValidationRoot 'previews'
$indexHtmlPath = Join-Path $ValidationRoot 'minimum-ui-reward-visual-review-pack.html'
$reviewTsvPath = Join-Path $ValidationRoot 'minimum-ui-reward-visual-review.tsv'
$summaryJsonPath = Join-Path $ValidationRoot 'minimum-ui-reward-visual-review-pack-summary.json'

Assert-PathUnderOrEqual -Path $ManifestPath -RootPath $repoRoot -Description 'ManifestPath'
Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing UI/reward manifest: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$tools = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$tools.sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null

$manifest = Read-JsonFile -Path $ManifestPath
$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[object]]::new()
$textureCount = 0
$texturePreviewCount = 0
$prefabCount = 0
$prefabWithPlaceholderCount = 0

foreach ($selection in @($manifest.selections)) {
    $id = [string]$selection.id
    $role = [string]$selection.role
    $kind = [string]$selection.kind
    $status = [string]$selection.status
    $assetPath = Resolve-RepoPath -RepoRoot $repoRoot -Path ([string]$selection.path)
    Assert-PathUnderOrEqual -Path $assetPath -RootPath $repoRoot -Description "UI/reward selection '$id'"
    Assert-PathNotUnder -Path $assetPath -RootPath $sourceInstall -Description "UI/reward selection '$id'"
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        $issues.Add("Missing UI/reward source for $id`: $assetPath") | Out-Null
        continue
    }

    $safeName = Convert-ToSafeFileName -Value "$id-$role"
    if ([string]::IsNullOrWhiteSpace($safeName)) {
        $safeName = Convert-ToSafeFileName -Value ([System.IO.Path]::GetFileNameWithoutExtension($assetPath))
    }

    $row = [ordered]@{
        id = $id
        role = $role
        kind = $kind
        status = $status
        sourcePath = $assetPath
        previewPath = ''
        width = $null
        height = $null
        alphaSampleRatio = $null
        visibleContentSampleRatio = $null
        deadbeefCount = $null
        monoBehaviourCount = $null
        rendererTokenCount = $null
        review = 'NotReviewed'
        note = ''
    }

    if ($kind -eq 'Texture2D') {
        $textureCount++
        $previewPath = Join-Path $previewRoot "$safeName.png"
        Assert-PathUnderOrEqual -Path $previewPath -RootPath $ValidationRoot -Description "Preview path '$id'"
        if ($Force -or -not (Test-OutputIsFresh -OutputPath $previewPath -InputPath $assetPath)) {
            Save-CheckerboardPreview -InputPath $assetPath -OutputPath $previewPath -MaxSize $MaxPreviewSize
        }

        $image = [System.Drawing.Bitmap]::FromFile($assetPath)
        try {
            $content = Measure-ImageContent -Image $image
            $row.width = $image.Width
            $row.height = $image.Height
            $row.alphaSampleRatio = $content.alphaSampleRatio
            $row.visibleContentSampleRatio = $content.visibleContentSampleRatio
            if ($content.alphaSampleRatio -le 0.001) {
                $issues.Add("Texture '$id' appears empty by sampled alpha.") | Out-Null
            }
            if ($content.visibleContentSampleRatio -le 0.001) {
                $warnings.Add("Texture '$id' has very low non-white visible content; review against checkerboard preview.") | Out-Null
            }
        } finally {
            $image.Dispose()
        }

        if (Test-Path -LiteralPath $previewPath -PathType Leaf) {
            $texturePreviewCount++
        }
        $row.previewPath = $previewPath
    } elseif ($kind -eq 'Prefab') {
        $prefabCount++
        $content = Get-Content -LiteralPath $assetPath -Raw
        $deadbeefCount = ([regex]::Matches($content, 'deadbeef|deadf00d', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
        $monoBehaviourCount = ([regex]::Matches($content, '(?m)^MonoBehaviour:')).Count
        $rendererTokenCount = ([regex]::Matches($content, '(?m)^(MeshRenderer|SkinnedMeshRenderer|SpriteRenderer|ParticleSystemRenderer|CanvasRenderer):')).Count
        $row.deadbeefCount = $deadbeefCount
        $row.monoBehaviourCount = $monoBehaviourCount
        $row.rendererTokenCount = $rendererTokenCount
        if ($deadbeefCount -gt 0) {
            $prefabWithPlaceholderCount++
            $warnings.Add("Prefab '$id' has $deadbeefCount deadbeef/deadf00d placeholder reference(s); Unity dependency closure is required.") | Out-Null
        }
    } else {
        $issues.Add("Selection '$id' has unsupported kind '$kind'.") | Out-Null
    }

    $rows.Add([PSCustomObject]$row) | Out-Null
}

$reviewLines = [System.Collections.Generic.List[string]]::new()
$reviewLines.Add("id`trole`tkind`tstatus`tpreviewPath`tsourcePath`treview`tconfirmedMeaning`tnote") | Out-Null
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
        (Convert-ToTsvField $row.kind),
        (Convert-ToTsvField $row.status),
        (Convert-ToTsvField $row.previewPath),
        (Convert-ToTsvField $row.sourcePath),
        (Convert-ToTsvField $review),
        (Convert-ToTsvField $confirmedMeaning),
        (Convert-ToTsvField $note))) | Out-Null
}
$reviewLines | Set-Content -LiteralPath $reviewTsvPath -Encoding UTF8

$htmlLines = [System.Collections.Generic.List[string]]::new()
$htmlLines.Add('<!doctype html>') | Out-Null
$htmlLines.Add('<html lang="en">') | Out-Null
$htmlLines.Add('<head><meta charset="utf-8"><title>StellaGaia Minimum UI/Reward Visual Review Pack</title>') | Out-Null
$htmlLines.Add('<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;line-height:1.35;color:#202124}article{border:1px solid #d7dce2;border-radius:6px;padding:14px;margin:14px 0}img{max-width:100%;height:auto;border:1px solid #e0e0e0;background:#ddd}code{background:#f4f6f8;padding:2px 4px;border-radius:3px}.warn{color:#8a5a00}</style></head>') | Out-Null
$htmlLines.Add('<body>') | Out-Null
$htmlLines.Add('<h1>StellaGaia Minimum UI/Reward Visual Review Pack</h1>') | Out-Null
$htmlLines.Add('<p>This pack supports offline visual review of selected textures and static prefab risk review. It is not a Unity sprite, UI, prefab, or gameplay validation pass.</p>') | Out-Null
foreach ($row in $rows) {
    $htmlLines.Add('<article>') | Out-Null
    $htmlLines.Add("<h2>$(Convert-ToHtml $row.id) - $(Convert-ToHtml $row.role)</h2>") | Out-Null
    $htmlLines.Add("<p><strong>Kind:</strong> $(Convert-ToHtml $row.kind)<br><strong>Status:</strong> $(Convert-ToHtml $row.status)</p>") | Out-Null
    if ($row.kind -eq 'Texture2D' -and -not [string]::IsNullOrWhiteSpace([string]$row.previewPath)) {
        $previewRelative = [System.IO.Path]::GetRelativePath($ValidationRoot, [string]$row.previewPath) -replace '\\', '/'
        $htmlLines.Add("<p><strong>Size:</strong> $($row.width)x$($row.height), <strong>alpha sample:</strong> $($row.alphaSampleRatio), <strong>visible content sample:</strong> $($row.visibleContentSampleRatio)</p>") | Out-Null
        $htmlLines.Add("<img alt=""Preview for $(Convert-ToHtml $row.id)"" src=""$previewRelative"">") | Out-Null
    } elseif ($row.kind -eq 'Prefab') {
        $htmlLines.Add("<p class=""warn""><strong>Prefab static risk:</strong> placeholders=$($row.deadbeefCount), MonoBehaviour blocks=$($row.monoBehaviourCount), renderer tokens=$($row.rendererTokenCount). Unity import/render validation is required.</p>") | Out-Null
    }
    $htmlLines.Add("<p><code>$(Convert-ToHtml $row.sourcePath)</code></p>") | Out-Null
    $htmlLines.Add('</article>') | Out-Null
}
$htmlLines.Add('</body></html>') | Out-Null
$htmlLines | Set-Content -LiteralPath $indexHtmlPath -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    manifestPath = $ManifestPath
    validationRoot = $ValidationRoot
    selectionCount = @($manifest.selections).Count
    textureCount = $textureCount
    texturePreviewCount = $texturePreviewCount
    prefabCount = $prefabCount
    prefabWithPlaceholderCount = $prefabWithPlaceholderCount
    warningCount = $warnings.Count
    warnings = @($warnings)
    issueCount = $issues.Count
    issues = @($issues)
    indexHtml = $indexHtmlPath
    visualReviewTsv = $reviewTsvPath
    summaryJson = $summaryJsonPath
    rows = @($rows)
    interpretation = 'This offline visual review pack previews selected texture candidates and records selected prefab placeholder risk. It is not Unity visible validation and does not make UI/reward art development-usable.'
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8
$summary

if ($issues.Count -gt 0) {
    throw "Minimum UI/reward visual review pack generated with $($issues.Count) issue(s)."
}
