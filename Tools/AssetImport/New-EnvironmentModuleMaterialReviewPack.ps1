[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04',
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [int]$MaxPreviewSize = 384,
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

function Measure-ImageContent {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Image)

    $sampleCount = 0
    $alphaCount = 0
    $nonWhiteCount = 0
    $xStep = [Math]::Max(1, [Math]::Floor($Image.Width / 96))
    $yStep = [Math]::Max(1, [Math]::Floor($Image.Height / 96))

    for ($y = 0; $y -lt $Image.Height; $y += $yStep) {
        for ($x = 0; $x -lt $Image.Width; $x += $xStep) {
            $sampleCount++
            $pixel = $Image.GetPixel($x, $y)
            if ($pixel.A -gt 0) {
                $alphaCount++
            }
            if ($pixel.R -lt 245 -or $pixel.G -lt 245 -or $pixel.B -lt 245) {
                $nonWhiteCount++
            }
        }
    }

    if ($sampleCount -eq 0) {
        return [PSCustomObject]@{
            alphaSampleRatio = 0.0
            nonWhiteSampleRatio = 0.0
        }
    }

    return [PSCustomObject]@{
        alphaSampleRatio = [Math]::Round($alphaCount / [double]$sampleCount, 6)
        nonWhiteSampleRatio = [Math]::Round($nonWhiteCount / [double]$sampleCount, 6)
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

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $repoRoot 'Tools\AssetImport\tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot "Validation\EnvironmentModuleMaterialReviewPack\$Name"
}

$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$previewRoot = Join-Path $ValidationRoot 'previews'
$indexHtmlPath = Join-Path $ValidationRoot 'environment-module-material-review-pack.html'
$reviewTsvPath = Join-Path $ValidationRoot 'environment-module-material-review.tsv'
$summaryJsonPath = Join-Path $ValidationRoot 'environment-module-material-review-pack-summary.json'

Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}

$tools = Read-JsonFile -Path $ToolManifestPath
$sourceInstall = [string]$tools.sourceInstall
Assert-PathNotUnder -Path $ValidationRoot -RootPath $sourceInstall -Description 'ValidationRoot'

$projectPath = Join-Path $extractedRoot "AssetRipper\EnvironmentModuleSlices\$Name\ExportedProject"
$bindingCsvPath = Join-Path $extractedRoot "Repairs\SemanticMaterialTextures\$Name\semantic-material-texture-bindings.csv"
$manualMappingPath = Join-Path $repoRoot 'Tools\AssetImport\ManualTextureMaps\Environment009ModuleSalvageSet01TextureRebind04.csv'
$salvageCsvPath = Join-Path $extractedRoot "Validation\UnitySalvageCandidates\$Name\salvage-candidates-static.csv"

foreach ($pathInfo in @(
    @{ Path = $projectPath; Root = $extractedRoot; Kind = 'Container'; Label = 'Environment module project' },
    @{ Path = $bindingCsvPath; Root = $extractedRoot; Kind = 'Leaf'; Label = 'Texture binding CSV' },
    @{ Path = $manualMappingPath; Root = $repoRoot; Kind = 'Leaf'; Label = 'Manual mapping CSV' },
    @{ Path = $salvageCsvPath; Root = $extractedRoot; Kind = 'Leaf'; Label = 'Salvage candidate CSV' }
)) {
    Assert-PathUnderOrEqual -Path $pathInfo.Path -RootPath $pathInfo.Root -Description $pathInfo.Label
    Assert-PathNotUnder -Path $pathInfo.Path -RootPath $sourceInstall -Description $pathInfo.Label
    if (-not (Test-Path -LiteralPath $pathInfo.Path -PathType $pathInfo.Kind)) {
        throw "Missing $($pathInfo.Label): $($pathInfo.Path)"
    }
}

Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $previewRoot | Out-Null

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$textureRows = [System.Collections.Generic.List[object]]::new()
$materialRows = [System.Collections.Generic.List[object]]::new()
$previewCount = 0
$missingTextureCount = 0

$bindingRows = Import-Csv -LiteralPath $bindingCsvPath
foreach ($binding in $bindingRows) {
    $textureFields = @(
        @{ Role = 'Diffuse'; Path = [string]$binding.DiffuseTexture },
        @{ Role = 'Normal'; Path = [string]$binding.NormalTexture },
        @{ Role = 'Metallic'; Path = [string]$binding.MetallicTexture },
        @{ Role = 'Emission'; Path = [string]$binding.EmissionTexture }
    )

    $materialRows.Add([PSCustomObject]@{
        materialName = [string]$binding.MaterialName
        status = [string]$binding.Status
        exactTextureCount = [int]$binding.ExactTextureCount
        manualTextureCount = [int]$binding.ManualTextureCount
        manualRoles = [string]$binding.ManualRoles
        matchedTextureCount = [int]$binding.MatchedTextureCount
        patchedTextureProperties = [int]$binding.PatchedTextureProperties
    }) | Out-Null

    if ([string]$binding.Status -eq 'NoTextureMatch') {
        $warnings.Add("Material '$($binding.MaterialName)' has no texture binding and requires Unity visible review or replacement.") | Out-Null
    }

    foreach ($textureField in $textureFields) {
        if ([string]::IsNullOrWhiteSpace($textureField.Path)) {
            continue
        }

        $texturePath = Join-Path $projectPath ($textureField.Path -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        Assert-PathUnderOrEqual -Path $texturePath -RootPath $projectPath -Description "Texture '$($binding.MaterialName)' '$($textureField.Role)'"
        if (-not (Test-Path -LiteralPath $texturePath -PathType Leaf)) {
            $missingTextureCount++
            $issues.Add("Missing texture for material '$($binding.MaterialName)' role '$($textureField.Role)': $($textureField.Path)") | Out-Null
            continue
        }

        $safeName = Convert-ToSafeFileName -Value "$($binding.MaterialName)-$($textureField.Role)"
        $previewPath = Join-Path $previewRoot "$safeName.png"
        Assert-PathUnderOrEqual -Path $previewPath -RootPath $ValidationRoot -Description 'Preview path'
        if ($Force -or -not (Test-OutputIsFresh -OutputPath $previewPath -InputPath $texturePath)) {
            Save-CheckerboardPreview -InputPath $texturePath -OutputPath $previewPath -MaxSize $MaxPreviewSize
        }

        $image = [System.Drawing.Bitmap]::FromFile($texturePath)
        try {
            $content = Measure-ImageContent -Image $image
            $textureRows.Add([PSCustomObject]@{
                materialName = [string]$binding.MaterialName
                materialStatus = [string]$binding.Status
                role = [string]$textureField.Role
                texturePath = $texturePath
                previewPath = $previewPath
                width = $image.Width
                height = $image.Height
                alphaSampleRatio = $content.alphaSampleRatio
                nonWhiteSampleRatio = $content.nonWhiteSampleRatio
                isManual = ([string]$binding.ManualRoles -split ';') -contains [string]$textureField.Role
                review = 'NotReviewed'
                note = ''
            }) | Out-Null
        } finally {
            $image.Dispose()
        }

        if (Test-Path -LiteralPath $previewPath -PathType Leaf) {
            $previewCount++
        }
    }
}

$manualRows = @(Import-Csv -LiteralPath $manualMappingPath)
$skippedManualRows = @($manualRows | Where-Object { [string]$_.Decision -eq 'Skip' })
$staticPrefabRows = @(Import-Csv -LiteralPath $salvageCsvPath)

$reviewLines = [System.Collections.Generic.List[string]]::new()
$reviewLines.Add("materialName`trole`tmaterialStatus`tisManual`ttexturePath`tpreviewPath`treview`tconfirmedMeaning`tnote") | Out-Null
$existingReviewsByKey = @{}
if (Test-Path -LiteralPath $reviewTsvPath -PathType Leaf) {
    foreach ($existingReview in @(Import-Csv -LiteralPath $reviewTsvPath -Delimiter "`t")) {
        $existingKey = "{0}`t{1}`t{2}" -f ([string]$existingReview.materialName), ([string]$existingReview.role), ([string]$existingReview.texturePath)
        if (-not [string]::IsNullOrWhiteSpace($existingKey.Trim())) {
            $existingReviewsByKey[$existingKey] = $existingReview
        }
    }
}
foreach ($row in $textureRows) {
    $existingKey = "{0}`t{1}`t{2}" -f ([string]$row.materialName), ([string]$row.role), ([string]$row.texturePath)
    $existingReview = $existingReviewsByKey[$existingKey]
    $review = if ($null -ne $existingReview -and -not [string]::IsNullOrWhiteSpace([string]$existingReview.review)) { [string]$existingReview.review } else { 'NotReviewed' }
    $confirmedMeaning = if ($null -ne $existingReview) { [string]$existingReview.confirmedMeaning } else { '' }
    $note = if ($null -ne $existingReview) { [string]$existingReview.note } else { '' }
    $reviewLines.Add(("{0}`t{1}`t{2}`t{3}`t{4}`t{5}`t{6}`t{7}`t{8}" -f
        (Convert-ToTsvField $row.materialName),
        (Convert-ToTsvField $row.role),
        (Convert-ToTsvField $row.materialStatus),
        (Convert-ToTsvField ([string]$row.isManual)),
        (Convert-ToTsvField $row.texturePath),
        (Convert-ToTsvField $row.previewPath),
        (Convert-ToTsvField $review),
        (Convert-ToTsvField $confirmedMeaning),
        (Convert-ToTsvField $note))) | Out-Null
}
$reviewLines | Set-Content -LiteralPath $reviewTsvPath -Encoding UTF8

$htmlLines = [System.Collections.Generic.List[string]]::new()
$htmlLines.Add('<!doctype html>') | Out-Null
$htmlLines.Add('<html lang="en">') | Out-Null
$htmlLines.Add('<head><meta charset="utf-8"><title>StellaGaia Environment Module Material Review Pack</title>') | Out-Null
$htmlLines.Add('<style>body{font-family:Segoe UI,Arial,sans-serif;margin:24px;line-height:1.35;color:#202124}article{border:1px solid #d7dce2;border-radius:6px;padding:14px;margin:14px 0}img{max-width:220px;height:auto;border:1px solid #e0e0e0;background:#ddd;margin:4px}code{background:#f4f6f8;padding:2px 4px;border-radius:3px}.warn{color:#8a5a00}.grid{display:flex;flex-wrap:wrap;gap:12px}.tile{max-width:240px}</style></head>') | Out-Null
$htmlLines.Add('<body>') | Out-Null
$htmlLines.Add("<h1>Environment Module Material Review Pack: $(Convert-ToHtml $Name)</h1>") | Out-Null
$htmlLines.Add('<p>This pack previews material texture bindings for the repaired module slice. It is not Unity render validation and does not prove room-scale environment reuse.</p>') | Out-Null
$htmlLines.Add("<p><strong>Static root prefab candidates:</strong> $($staticPrefabRows.Count). <strong>Skipped manual mappings:</strong> $($skippedManualRows.Count).</p>") | Out-Null
foreach ($material in $materialRows) {
    $htmlLines.Add('<article>') | Out-Null
    $htmlLines.Add("<h2>$(Convert-ToHtml $material.materialName)</h2>") | Out-Null
    $htmlLines.Add("<p><strong>Status:</strong> $(Convert-ToHtml $material.status), <strong>exact:</strong> $($material.exactTextureCount), <strong>manual:</strong> $($material.manualTextureCount), <strong>patched:</strong> $($material.patchedTextureProperties)</p>") | Out-Null
    if ([string]$material.status -eq 'NoTextureMatch') {
        $htmlLines.Add('<p class="warn">No texture is bound. This material must be checked in Unity visible validation before acceptance.</p>') | Out-Null
    }
    $materialTextures = @($textureRows | Where-Object { [string]$_.materialName -eq [string]$material.materialName })
    if ($materialTextures.Count -gt 0) {
        $htmlLines.Add('<div class="grid">') | Out-Null
        foreach ($texture in $materialTextures) {
            $previewRelative = [System.IO.Path]::GetRelativePath($ValidationRoot, [string]$texture.previewPath) -replace '\\', '/'
            $manualLabel = if ([bool]$texture.isManual) { ' manual' } else { '' }
            $htmlLines.Add('<div class="tile">') | Out-Null
            $htmlLines.Add("<strong>$(Convert-ToHtml $texture.role)$manualLabel</strong><br>") | Out-Null
            $htmlLines.Add("<img alt=""$(Convert-ToHtml $texture.materialName) $(Convert-ToHtml $texture.role)"" src=""$previewRelative"">") | Out-Null
            $htmlLines.Add("<br><small>$($texture.width)x$($texture.height), nonWhite=$($texture.nonWhiteSampleRatio)</small>") | Out-Null
            $htmlLines.Add('</div>') | Out-Null
        }
        $htmlLines.Add('</div>') | Out-Null
    }
    $htmlLines.Add('</article>') | Out-Null
}
$htmlLines.Add('</body></html>') | Out-Null
$htmlLines | Set-Content -LiteralPath $indexHtmlPath -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    name = $Name
    projectPath = $projectPath
    validationRoot = $ValidationRoot
    materialCount = @($bindingRows).Count
    boundMaterialCount = @($bindingRows | Where-Object { [int]$_.MatchedTextureCount -gt 0 }).Count
    unboundMaterialCount = @($bindingRows | Where-Object { [int]$_.MatchedTextureCount -eq 0 }).Count
    manualBoundMaterialCount = @($bindingRows | Where-Object { [int]$_.ManualTextureCount -gt 0 }).Count
    textureBindingCount = $textureRows.Count
    texturePreviewCount = $previewCount
    staticPrefabCandidateCount = $staticPrefabRows.Count
    skippedManualMappingCount = $skippedManualRows.Count
    missingTextureCount = $missingTextureCount
    warningCount = $warnings.Count
    warnings = @($warnings)
    issueCount = $issues.Count
    issues = @($issues)
    indexHtml = $indexHtmlPath
    materialReviewTsv = $reviewTsvPath
    summaryJson = $summaryJsonPath
    materials = @($materialRows)
    textureRows = @($textureRows)
    interpretation = 'This offline material review pack previews texture bindings for the repaired environment module slice. It is not Unity visible validation and does not prove full StellaSora room/map reuse.'
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8
$summary

if ($issues.Count -gt 0) {
    throw "Environment module material review pack generated with $($issues.Count) issue(s)."
}
