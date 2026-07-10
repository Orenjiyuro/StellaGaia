[CmdletBinding()]
param(
    [string]$Name = 'Environment009ModuleSalvageSet01SemanticMaterialTextureRebind03',
    [string]$SourceProjectPath,
    [string]$TextureProjectPath,
    [string]$CopiedMaterialCsv,
    [string]$ManualTextureMappingCsv,
    [string]$OutputProjectPath,
    [string]$ReportDirectory,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $fullPath = (Get-FullPath -Path $Path).TrimEnd('\', '/')
    $fullRoot = (Get-FullPath -Path $Root).TrimEnd('\', '/')
    return $fullPath.Equals($fullRoot, $comparison) -or $fullPath.StartsWith($fullRoot + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-PathUnderOrEqual -Path $Path -Root $Root)) {
        throw "$Description must stay under $Root. Got: $Path"
    }
}

function Assert-SafeNameSegment {
    param([Parameter(Mandatory = $true)][string]$Value)

    if ($Value -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "Name must be a simple path segment. Got: $Value"
    }
}

function Get-ProjectRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$FullPath,
        [Parameter(Mandatory = $true)][string]$ProjectRoot
    )

    return $FullPath.Substring($ProjectRoot.Length + 1).Replace('\', '/')
}

function Normalize-AssetName {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return ([regex]::Replace($Value.ToLowerInvariant(), '[^a-z0-9]', ''))
}

function Get-MetaGuid {
    param([Parameter(Mandatory = $true)][string]$AssetPath)

    $metaPath = "$AssetPath.meta"
    if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
        return ''
    }

    $match = Select-String -LiteralPath $metaPath -Pattern '^guid: ([0-9a-f]{32})' -List
    if ($null -eq $match) {
        return ''
    }

    return $match.Matches.Groups[1].Value
}

function Get-TextureRoleAndBase {
    param([Parameter(Mandatory = $true)][string]$Stem)

    $role = 'Diffuse'
    $base = $Stem
    if ($Stem -match '^(.*)_([dnme])(\d*)$') {
        $base = $Matches[1]
        switch ($Matches[2].ToLowerInvariant()) {
            'd' { $role = 'Diffuse' }
            'n' { $role = 'Normal' }
            'm' { $role = 'Metallic' }
            'e' { $role = 'Emission' }
        }
    }

    return [PSCustomObject]@{
        Base = $base
        Role = $role
    }
}

function New-TextureIndex {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$AssetsRoot
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    $textureFiles = @(Get-ChildItem -LiteralPath $AssetsRoot -Recurse -File -Include *.png,*.jpg,*.jpeg,*.tga,*.psd)
    foreach ($file in $textureFiles) {
        $roleAndBase = Get-TextureRoleAndBase -Stem ([System.IO.Path]::GetFileNameWithoutExtension($file.Name))
        $guid = Get-MetaGuid -AssetPath $file.FullName
        if ([string]::IsNullOrWhiteSpace($guid)) {
            continue
        }

        $rows.Add([PSCustomObject]@{
            AssetPath = Get-ProjectRelativePath -FullPath $file.FullName -ProjectRoot $ProjectPath
            FullPath = $file.FullName
            MetaPath = "$($file.FullName).meta"
            Name = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            Base = $roleAndBase.Base
            NormalizedBase = Normalize-AssetName -Value $roleAndBase.Base
            Role = $roleAndBase.Role
            Guid = $guid
        })
    }

    return @($rows)
}

function Select-ExactRoleTexture {
    param(
        [Parameter(Mandatory = $true)][object[]]$Textures,
        [Parameter(Mandatory = $true)][string]$MaterialName,
        [Parameter(Mandatory = $true)][string]$Role
    )

    $normalizedMaterial = Normalize-AssetName -Value $MaterialName
    $matches = @($Textures | Where-Object { $_.NormalizedBase -eq $normalizedMaterial -and $_.Role -eq $Role } | Sort-Object AssetPath)
    if ($matches.Count -eq 0) {
        return $null
    }

    return $matches[0]
}

function Normalize-AssetPath {
    param([AllowNull()][string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    return $Value.Replace('\', '/').TrimStart('/')
}

function Select-TextureByAssetPath {
    param(
        [Parameter(Mandatory = $true)][object[]]$Textures,
        [Parameter(Mandatory = $true)][string]$AssetPath
    )

    $normalized = Normalize-AssetPath -Value $AssetPath
    $matches = @($Textures | Where-Object { $_.AssetPath -eq $normalized } | Sort-Object AssetPath)
    if ($matches.Count -eq 0) {
        throw "Manual texture mapping references missing texture: $AssetPath"
    }

    return $matches[0]
}

function Copy-TextureAsset {
    param(
        [Parameter(Mandatory = $true)][object]$Texture,
        [Parameter(Mandatory = $true)][string]$TextureProjectPath,
        [Parameter(Mandatory = $true)][string]$OutputProjectPath
    )

    $relativePath = $Texture.AssetPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $destination = Join-Path $OutputProjectPath $relativePath
    $destinationMeta = "$destination.meta"

    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination))
    Copy-Item -LiteralPath $Texture.FullPath -Destination $destination
    Copy-Item -LiteralPath $Texture.MetaPath -Destination $destinationMeta
}

function Set-MaterialTextureRefs {
    param(
        [Parameter(Mandatory = $true)][string]$MaterialPath,
        [AllowNull()][object]$Diffuse,
        [AllowNull()][object]$Normal,
        [AllowNull()][object]$Metallic,
        [AllowNull()][object]$Emission,
        [switch]$DryRun
    )

    $propertyRole = @{
        '_BaseMap' = 'Diffuse'
        '_MainTex' = 'Diffuse'
        '_NormalMap' = 'Normal'
        '_BumpMap' = 'Normal'
        '_MetallicGlossMap' = 'Metallic'
        '_EmissionMap' = 'Emission'
    }
    $roleTexture = @{
        'Diffuse' = $Diffuse
        'Normal' = $Normal
        'Metallic' = $Metallic
        'Emission' = $Emission
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in [System.IO.File]::ReadAllLines($MaterialPath)) {
        $lines.Add($line)
    }

    $currentProperty = ''
    $patched = 0
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if ($line -match '^\s{6}([A-Za-z0-9_]+):\s*$') {
            $currentProperty = $Matches[1]
            continue
        }

        if ($line -notmatch '^(\s*)m_Texture:\s*\{') {
            continue
        }

        if (-not $propertyRole.ContainsKey($currentProperty)) {
            continue
        }

        $role = $propertyRole[$currentProperty]
        $texture = $roleTexture[$role]
        if ($null -eq $texture) {
            continue
        }

        $lines[$index] = "$($Matches[1])m_Texture: {fileID: 2800000, guid: $($texture.Guid), type: 3}"
        $patched++
    }

    if (-not $DryRun -and $patched -gt 0) {
        [System.IO.File]::WriteAllLines($MaterialPath, $lines)
    }

    return $patched
}

$repoRoot = Get-FullPath -Path (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-FullPath -Path (Join-Path $repoRoot 'Extracted')

Assert-SafeNameSegment -Value $Name

if ([string]::IsNullOrWhiteSpace($SourceProjectPath)) {
    $SourceProjectPath = Join-Path $extractedRoot 'AssetRipper\EnvironmentModuleSlices\Environment009ModuleSalvageSet01SemanticMaterialRebind02\ExportedProject'
}
if ([string]::IsNullOrWhiteSpace($TextureProjectPath)) {
    $TextureProjectPath = Join-Path $extractedRoot 'AssetRipper\FolderExports\EnvironmentRoguelike2TextureOnly01\ExportedProject'
}
if ([string]::IsNullOrWhiteSpace($CopiedMaterialCsv)) {
    $CopiedMaterialCsv = Join-Path $extractedRoot 'Repairs\SemanticMaterials\Environment009ModuleSalvageSet01SemanticMaterialRebind02\semantic-material-copied-materials.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputProjectPath)) {
    $OutputProjectPath = Join-Path $extractedRoot "AssetRipper\EnvironmentModuleSlices\$Name\ExportedProject"
}
if ([string]::IsNullOrWhiteSpace($ReportDirectory)) {
    $ReportDirectory = Join-Path $extractedRoot "Repairs\SemanticMaterialTextures\$Name"
}

$SourceProjectPath = Get-FullPath -Path $SourceProjectPath
$TextureProjectPath = Get-FullPath -Path $TextureProjectPath
$CopiedMaterialCsv = Get-FullPath -Path $CopiedMaterialCsv
if (-not [string]::IsNullOrWhiteSpace($ManualTextureMappingCsv)) {
    $ManualTextureMappingCsv = Get-FullPath -Path $ManualTextureMappingCsv
}
$OutputProjectPath = Get-FullPath -Path $OutputProjectPath
$ReportDirectory = Get-FullPath -Path $ReportDirectory

foreach ($entry in @(
    @{ Path = $SourceProjectPath; Label = 'SourceProjectPath' },
    @{ Path = $TextureProjectPath; Label = 'TextureProjectPath' },
    @{ Path = $CopiedMaterialCsv; Label = 'CopiedMaterialCsv' },
    @{ Path = $OutputProjectPath; Label = 'OutputProjectPath' },
    @{ Path = $ReportDirectory; Label = 'ReportDirectory' }
)) {
    Assert-PathUnderOrEqual -Path $entry.Path -Root $extractedRoot -Description $entry.Label
}

if (-not (Test-Path -LiteralPath $SourceProjectPath -PathType Container)) {
    throw "Missing source project: $SourceProjectPath"
}
if (-not (Test-Path -LiteralPath (Join-Path $TextureProjectPath 'Assets') -PathType Container)) {
    throw "Missing texture export Assets folder: $TextureProjectPath"
}
if (-not (Test-Path -LiteralPath $CopiedMaterialCsv -PathType Leaf)) {
    throw "Missing copied material CSV: $CopiedMaterialCsv"
}
if (-not [string]::IsNullOrWhiteSpace($ManualTextureMappingCsv)) {
    Assert-PathUnderOrEqual -Path $ManualTextureMappingCsv -Root $repoRoot -Description 'ManualTextureMappingCsv'
    if (-not (Test-Path -LiteralPath $ManualTextureMappingCsv -PathType Leaf)) {
        throw "Missing manual texture mapping CSV: $ManualTextureMappingCsv"
    }
}
if ((Test-Path -LiteralPath $OutputProjectPath) -and -not $DryRun) {
    throw "OutputProjectPath already exists: $OutputProjectPath"
}

$textureRows = New-TextureIndex -ProjectPath $TextureProjectPath -AssetsRoot (Join-Path $TextureProjectPath 'Assets')
$materialRows = @(Import-Csv -LiteralPath $CopiedMaterialCsv | Sort-Object CandidateMaterialPath -Unique)
$manualTextureRows = @()
$manualTextureMap = @{}
if (-not [string]::IsNullOrWhiteSpace($ManualTextureMappingCsv)) {
    $manualTextureRows = @(Import-Csv -LiteralPath $ManualTextureMappingCsv)
    foreach ($row in $manualTextureRows) {
        if ([string]::IsNullOrWhiteSpace($row.Decision) -or $row.Decision -ne 'Bind') {
            continue
        }

        $role = [string]$row.Role
        if ($role -notin @('Diffuse', 'Normal', 'Metallic', 'Emission')) {
            throw "Manual texture mapping role must be Diffuse, Normal, Metallic, or Emission. Got: $role"
        }

        if ([string]::IsNullOrWhiteSpace($row.TexturePath)) {
            throw "Manual texture mapping row is Bind but has no TexturePath for $($row.MaterialName) $role"
        }

        $texture = Select-TextureByAssetPath -Textures $textureRows -AssetPath $row.TexturePath
        $materialPath = Normalize-AssetPath -Value $row.MaterialPath
        $materialName = [string]$row.MaterialName
        if ([string]::IsNullOrWhiteSpace($materialPath) -and [string]::IsNullOrWhiteSpace($materialName)) {
            throw "Manual texture mapping row must include MaterialPath or MaterialName."
        }

        $keyBase = if (-not [string]::IsNullOrWhiteSpace($materialPath)) {
            "path:$materialPath"
        } else {
            "name:$materialName"
        }
        $key = "$keyBase|$role"
        if ($manualTextureMap.ContainsKey($key)) {
            throw "Duplicate manual texture mapping for $key"
        }

        $manualTextureMap[$key] = [PSCustomObject]@{
            Texture = $texture
            Role = $role
            Decision = [string]$row.Decision
            Reason = [string]$row.Reason
            MaterialName = $materialName
            MaterialPath = $materialPath
        }
    }
}

if (-not $DryRun) {
    [void][System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($OutputProjectPath))
    Copy-Item -LiteralPath $SourceProjectPath -Destination $OutputProjectPath -Recurse
}
[void][System.IO.Directory]::CreateDirectory($ReportDirectory)

$rows = [System.Collections.Generic.List[object]]::new()
$texturesToCopy = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)

foreach ($material in $materialRows) {
    $materialAssetPath = $material.CandidateMaterialPath
    $materialName = [System.IO.Path]::GetFileNameWithoutExtension($materialAssetPath)
    $sourceMaterialPath = Join-Path $SourceProjectPath $materialAssetPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    $outputMaterialPath = Join-Path $OutputProjectPath $materialAssetPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    if (-not (Test-Path -LiteralPath $sourceMaterialPath -PathType Leaf)) {
        throw "Missing source material in rebound project: $sourceMaterialPath"
    }

    $diffuse = Select-ExactRoleTexture -Textures $textureRows -MaterialName $materialName -Role 'Diffuse'
    $normal = Select-ExactRoleTexture -Textures $textureRows -MaterialName $materialName -Role 'Normal'
    $metallic = Select-ExactRoleTexture -Textures $textureRows -MaterialName $materialName -Role 'Metallic'
    $emission = Select-ExactRoleTexture -Textures $textureRows -MaterialName $materialName -Role 'Emission'
    $exactTextures = @($diffuse, $normal, $metallic, $emission) | Where-Object { $null -ne $_ }
    $exactTextureCount = @($exactTextures).Count
    $manualRoleBindings = [System.Collections.Generic.List[string]]::new()
    foreach ($role in @('Diffuse', 'Normal', 'Metallic', 'Emission')) {
        $pathKey = "path:$(Normalize-AssetPath -Value $materialAssetPath)|$role"
        $nameKey = "name:$materialName|$role"
        $manual = $null
        if ($manualTextureMap.ContainsKey($pathKey)) {
            $manual = $manualTextureMap[$pathKey]
        } elseif ($manualTextureMap.ContainsKey($nameKey)) {
            $manual = $manualTextureMap[$nameKey]
        }

        if ($null -eq $manual) {
            continue
        }

        switch ($role) {
            'Diffuse' { $diffuse = $manual.Texture }
            'Normal' { $normal = $manual.Texture }
            'Metallic' { $metallic = $manual.Texture }
            'Emission' { $emission = $manual.Texture }
        }
        $manualRoleBindings.Add($role) | Out-Null
    }
    $matchedTextures = @($diffuse, $normal, $metallic, $emission) | Where-Object { $null -ne $_ }
    $manualTextureCount = $manualRoleBindings.Count

    foreach ($texture in $matchedTextures) {
        if (-not $texturesToCopy.ContainsKey($texture.AssetPath)) {
            $texturesToCopy.Add($texture.AssetPath, $texture)
        }
    }

    $patchedProperties = 0
    if (-not $DryRun -and $matchedTextures.Count -gt 0) {
        foreach ($texture in $matchedTextures) {
            Copy-TextureAsset -Texture $texture -TextureProjectPath $TextureProjectPath -OutputProjectPath $OutputProjectPath
        }
        $patchedProperties = Set-MaterialTextureRefs -MaterialPath $outputMaterialPath -Diffuse $diffuse -Normal $normal -Metallic $metallic -Emission $emission
    } elseif ($DryRun -and $matchedTextures.Count -gt 0) {
        $patchedProperties = Set-MaterialTextureRefs -MaterialPath $sourceMaterialPath -Diffuse $diffuse -Normal $normal -Metallic $metallic -Emission $emission -DryRun
    }

    $rows.Add([PSCustomObject]@{
        MaterialPath = $materialAssetPath
        MaterialName = $materialName
        Status = if ($matchedTextures.Count -gt 0) {
            if ($manualTextureCount -gt 0 -and $exactTextureCount -gt 0) {
                if ($DryRun) { 'WouldBindExactAndManualTextures' } else { 'BoundExactAndManualTextures' }
            } elseif ($manualTextureCount -gt 0) {
                if ($DryRun) { 'WouldBindManualTextures' } else { 'BoundManualTextures' }
            } else {
                if ($DryRun) { 'WouldBindExactTextures' } else { 'BoundExactTextures' }
            }
        } else {
            'NoTextureMatch'
        }
        DiffuseTexture = if ($diffuse) { $diffuse.AssetPath } else { '' }
        NormalTexture = if ($normal) { $normal.AssetPath } else { '' }
        MetallicTexture = if ($metallic) { $metallic.AssetPath } else { '' }
        EmissionTexture = if ($emission) { $emission.AssetPath } else { '' }
        ExactTextureCount = $exactTextureCount
        ManualTextureCount = $manualTextureCount
        ManualRoles = ($manualRoleBindings -join ';')
        MatchedTextureCount = $matchedTextures.Count
        PatchedTextureProperties = $patchedProperties
    })
}

$materialTextureCsv = Join-Path $ReportDirectory 'semantic-material-texture-bindings.csv'
$summaryJson = Join-Path $ReportDirectory 'semantic-material-texture-rebind-summary.json'
$reportPath = Join-Path $ReportDirectory 'semantic-material-texture-rebind-report.md'

$rows | Export-Csv -LiteralPath $materialTextureCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    SourceProjectPath = $SourceProjectPath
    TextureProjectPath = $TextureProjectPath
    CopiedMaterialCsv = $CopiedMaterialCsv
    ManualTextureMappingCsv = $ManualTextureMappingCsv
    OutputProjectPath = $OutputProjectPath
    ReportDirectory = $ReportDirectory
    DryRun = [bool]$DryRun
    MaterialsProcessed = $rows.Count
    MaterialsWithAnyExactTexture = @($rows | Where-Object { $_.ExactTextureCount -gt 0 }).Count
    MaterialsWithAnyManualTexture = @($rows | Where-Object { $_.ManualTextureCount -gt 0 }).Count
    MaterialsWithDiffuseTexture = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.DiffuseTexture) }).Count
    MaterialsWithNormalTexture = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.NormalTexture) }).Count
    MaterialsWithMetallicTexture = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.MetallicTexture) }).Count
    MaterialsWithEmissionTexture = @($rows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.EmissionTexture) }).Count
    UniqueTextureFilesToCopy = $texturesToCopy.Count
    PatchedTextureProperties = @($rows | Measure-Object -Property PatchedTextureProperties -Sum).Sum
    MaterialTextureCsv = $materialTextureCsv
    SummaryJson = $summaryJson
    Report = $reportPath
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Semantic Material Texture Rebind")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add("| Metric | Value |")
$reportLines.Add("| --- | ---: |")
$reportLines.Add("| Materials processed | $($summary.MaterialsProcessed) |")
$reportLines.Add("| Materials with exact texture match | $($summary.MaterialsWithAnyExactTexture) |")
$reportLines.Add("| Materials with manual texture match | $($summary.MaterialsWithAnyManualTexture) |")
$reportLines.Add("| Materials with diffuse texture | $($summary.MaterialsWithDiffuseTexture) |")
$reportLines.Add("| Materials with normal texture | $($summary.MaterialsWithNormalTexture) |")
$reportLines.Add("| Materials with metallic texture | $($summary.MaterialsWithMetallicTexture) |")
$reportLines.Add("| Materials with emission texture | $($summary.MaterialsWithEmissionTexture) |")
$reportLines.Add("| Unique texture files copied | $($summary.UniqueTextureFilesToCopy) |")
$reportLines.Add("| Patched material texture properties | $($summary.PatchedTextureProperties) |")
$reportLines.Add('')
$reportLines.Add('Exact material-name to texture-base matches are bound automatically. Manual rows are applied only when `Decision` is `Bind` in the supplied mapping CSV.')
$reportLines.Add('')
$reportLines.Add('| Material | Status | Manual roles | Diffuse | Normal | Metallic | Emission |')
$reportLines.Add('| --- | --- | --- | --- | --- | --- | --- |')
foreach ($row in $rows) {
    $reportLines.Add(('| `{0}` | {1} | `{2}` | `{3}` | `{4}` | `{5}` | `{6}` |' -f $row.MaterialName, $row.Status, $row.ManualRoles, $row.DiffuseTexture, $row.NormalTexture, $row.MetallicTexture, $row.EmissionTexture))
}
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary
