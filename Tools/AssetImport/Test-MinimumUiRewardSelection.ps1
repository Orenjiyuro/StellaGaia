[CmdletBinding()]
param(
    [string]$ManifestPath,
    [switch]$RequireArtReady
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

function Measure-ImageAlpha {
    param([Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Image)

    $sampleCount = 0
    $alphaCount = 0
    $opaqueCount = 0
    $xStep = [Math]::Max(1, [Math]::Floor($Image.Width / 64))
    $yStep = [Math]::Max(1, [Math]::Floor($Image.Height / 64))

    for ($y = 0; $y -lt $Image.Height; $y += $yStep) {
        for ($x = 0; $x -lt $Image.Width; $x += $xStep) {
            $sampleCount++
            $pixel = $Image.GetPixel($x, $y)
            if ($pixel.A -gt 0) {
                $alphaCount++
            }
            if ($pixel.A -gt 220) {
                $opaqueCount++
            }
        }
    }

    if ($sampleCount -eq 0) {
        return [PSCustomObject]@{
            AlphaSampleRatio = 0.0
            OpaqueSampleRatio = 0.0
        }
    }

    return [PSCustomObject]@{
        AlphaSampleRatio = [Math]::Round($alphaCount / [double]$sampleCount, 6)
        OpaqueSampleRatio = [Math]::Round($opaqueCount / [double]$sampleCount, 6)
    }
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $repoRoot 'docs\asset-migration\minimum-ui-reward-selection.json'
}

$ManifestPath = Get-CanonicalPath $ManifestPath
if (-not (Test-IsPathUnderOrEqual -CandidatePath $ManifestPath -RootPath $repoRoot)) {
    throw "ManifestPath must stay under repository root. Got: $ManifestPath"
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    throw "Missing minimum UI/reward selection manifest: $ManifestPath"
}

Add-Type -AssemblyName System.Drawing

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$validStatuses = @(
    'SelectedNeedsUnityVisibleValidation',
    'StaticReadableNeedsUnitySpriteValidation',
    'RepairCandidateNeedsDependencyClosure',
    'DevelopmentUsable',
    'Rejected',
    'NotUsableYet'
)

if ([string]::IsNullOrWhiteSpace([string]$manifest.status)) {
    $issues.Add('Manifest is missing status.') | Out-Null
} elseif ([string]$manifest.status -notin $validStatuses) {
    $issues.Add("Manifest has unsupported status '$($manifest.status)'.") | Out-Null
}

if ($RequireArtReady -and -not [bool]$manifest.canSatisfyVerticalSliceArt) {
    $issues.Add('RequireArtReady was set, but canSatisfyVerticalSliceArt is false.') | Out-Null
}

$sourceExportPath = $null
if (-not [string]::IsNullOrWhiteSpace([string]$manifest.sourceExport)) {
    $sourceExportPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.sourceExport)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $sourceExportPath -RootPath $repoRoot)) {
        $issues.Add("sourceExport points outside repository root: $($manifest.sourceExport)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $sourceExportPath -PathType Container)) {
        $issues.Add("Missing sourceExport directory: $($manifest.sourceExport)") | Out-Null
    }
}

if (-not [string]::IsNullOrWhiteSpace([string]$manifest.categoryValidation)) {
    $categoryValidationPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path ([string]$manifest.categoryValidation)
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $categoryValidationPath -RootPath $repoRoot)) {
        $issues.Add("categoryValidation points outside repository root: $($manifest.categoryValidation)") | Out-Null
    } elseif (-not (Test-Path -LiteralPath $categoryValidationPath -PathType Leaf)) {
        $issues.Add("Missing categoryValidation file: $($manifest.categoryValidation)") | Out-Null
    }
}

$roleMinimums = @{}
foreach ($requiredRole in @($manifest.requiredRoles)) {
    $role = [string]$requiredRole.role
    if ([string]::IsNullOrWhiteSpace($role)) {
        $issues.Add('A requiredRoles entry is missing role.') | Out-Null
        continue
    }

    $minimumCount = [int]$requiredRole.minimumCount
    if ($minimumCount -lt 1) {
        $issues.Add("Required role '$role' must have minimumCount >= 1.") | Out-Null
        continue
    }

    $roleMinimums[$role] = $minimumCount
}

$roleCounts = @{}
$selectionSummaries = [System.Collections.Generic.List[object]]::new()
$textureCount = 0
$prefabCount = 0

foreach ($selection in @($manifest.selections)) {
    $id = [string]$selection.id
    $role = [string]$selection.role
    $kind = [string]$selection.kind
    $status = [string]$selection.status
    $pathText = [string]$selection.path

    if ([string]::IsNullOrWhiteSpace($id)) {
        $issues.Add('A selection is missing id.') | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($role)) {
        $issues.Add("Selection '$id' is missing role.") | Out-Null
    } else {
        if (-not $roleCounts.ContainsKey($role)) {
            $roleCounts[$role] = 0
        }
        $roleCounts[$role]++
    }
    if ([string]::IsNullOrWhiteSpace($kind)) {
        $issues.Add("Selection '$id' is missing kind.") | Out-Null
    }
    if ($status -notin $validStatuses) {
        $issues.Add("Selection '$id' has unsupported status '$status'.") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($pathText)) {
        $issues.Add("Selection '$id' is missing path.") | Out-Null
        continue
    }

    $assetPath = Resolve-RepoRelativePath -RepoRoot $repoRoot -Path $pathText
    if (-not (Test-IsPathUnderOrEqual -CandidatePath $assetPath -RootPath $repoRoot)) {
        $issues.Add("Selection '$id' points outside repository root: $pathText") | Out-Null
        continue
    }
    if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        $issues.Add("Selection '$id' path is missing: $pathText") | Out-Null
        continue
    }

    $fileItem = Get-Item -LiteralPath $assetPath
    $summary = [ordered]@{
        Id = $id
        Role = $role
        Kind = $kind
        Status = $status
        Path = $pathText
        Bytes = $fileItem.Length
    }

    switch ($kind) {
        'Texture2D' {
            $textureCount++
            $image = [System.Drawing.Bitmap]::FromFile($assetPath)
            try {
                $alpha = Measure-ImageAlpha -Image $image
                $summary.Width = $image.Width
                $summary.Height = $image.Height
                $summary.PixelFormat = $image.PixelFormat.ToString()
                $summary.AlphaSampleRatio = $alpha.AlphaSampleRatio
                $summary.OpaqueSampleRatio = $alpha.OpaqueSampleRatio

                if ($image.Width -lt 16 -or $image.Height -lt 16) {
                    $issues.Add("Texture selection '$id' is smaller than 16x16: $($image.Width)x$($image.Height).") | Out-Null
                }
                if ($alpha.AlphaSampleRatio -le 0.001) {
                    $issues.Add("Texture selection '$id' appears empty from sampled alpha.") | Out-Null
                }
            } finally {
                $image.Dispose()
            }
        }
        'Prefab' {
            $prefabCount++
            $content = Get-Content -LiteralPath $assetPath -Raw
            $deadbeefCount = ([regex]::Matches($content, 'deadbeef|deadf00d', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)).Count
            $guidRefCount = ([regex]::Matches($content, 'guid: [0-9a-fA-F]{32}')).Count
            $monoBehaviourCount = ([regex]::Matches($content, '(?m)^MonoBehaviour:')).Count
            $rendererTokenCount = ([regex]::Matches($content, '(?m)^(MeshRenderer|SkinnedMeshRenderer|SpriteRenderer|ParticleSystemRenderer|CanvasRenderer):')).Count
            $summary.DeadbeefCount = $deadbeefCount
            $summary.GuidRefCount = $guidRefCount
            $summary.MonoBehaviourCount = $monoBehaviourCount
            $summary.RendererTokenCount = $rendererTokenCount

            if ($deadbeefCount -gt 0) {
                $warnings.Add("Prefab selection '$id' has $deadbeefCount deadbeef/deadf00d placeholder reference(s).") | Out-Null
            }
            if ($status -eq 'DevelopmentUsable' -and $deadbeefCount -gt 0) {
                $issues.Add("Prefab selection '$id' is DevelopmentUsable but still has placeholder references.") | Out-Null
            }
        }
        default {
            $issues.Add("Selection '$id' has unsupported kind '$kind'.") | Out-Null
        }
    }

    $selectionSummaries.Add([PSCustomObject]$summary) | Out-Null
}

foreach ($role in $roleMinimums.Keys) {
    $actual = 0
    if ($roleCounts.ContainsKey($role)) {
        $actual = [int]$roleCounts[$role]
    }
    if ($actual -lt [int]$roleMinimums[$role]) {
        $issues.Add("Required role '$role' has $actual selection(s), expected at least $($roleMinimums[$role]).") | Out-Null
    }
}

if ([bool]$manifest.canSatisfyVerticalSliceArt -and [string]$manifest.status -ne 'DevelopmentUsable') {
    $issues.Add('Manifest allows vertical-slice art while status is not DevelopmentUsable.') | Out-Null
}

$summaryObject = [PSCustomObject]@{
    ManifestPath = $ManifestPath
    Status = [string]$manifest.status
    CanSatisfyVerticalSliceArt = [bool]$manifest.canSatisfyVerticalSliceArt
    SelectionCount = @($manifest.selections).Count
    TextureSelectionCount = $textureCount
    PrefabSelectionCount = $prefabCount
    RequiredRoleCount = $roleMinimums.Count
    RoleCounts = $roleCounts
    WarningCount = $warnings.Count
    Warnings = @($warnings)
    IssueCount = $issues.Count
    Issues = @($issues)
    Selections = @($selectionSummaries)
}

if ($issues.Count -gt 0) {
    $summaryObject | ConvertTo-Json -Depth 8 | Write-Output
    throw "Minimum UI/reward selection validation failed with $($issues.Count) issue(s)."
}

$summaryObject
