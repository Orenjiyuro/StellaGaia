[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ProjectPath,
    [string]$RepairRoot,
    [string]$ShaderAssetPath = 'Assets/StellaGaia/Fallback/StellaGaiaFallbackOpaque.shader',
    [string]$ShaderGuid = '6fdbcb0b2ef343a4a93a2d46f8bd25a1',
    [switch]$DryRun
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

function Assert-SafeProjectAssetPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ($Path -notmatch '^Assets[/\\].+') {
        throw "ShaderAssetPath must start with Assets/: $Path"
    }
    if ([System.IO.Path]::IsPathRooted($Path)) {
        throw "ShaderAssetPath must not be rooted: $Path"
    }
    foreach ($segment in ($Path -split '[\\/]')) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "ShaderAssetPath contains an unsafe segment: $Path"
        }
    }
}

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $root = Get-CanonicalPath $RootPath
    $full = Get-CanonicalPath $Path
    if ($full.Length -le $root.Length) {
        return ''
    }
    return $full.Substring($root.Length + 1).Replace('\', '/')
}

function Write-FallbackShaderAsset {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectPath,
        [Parameter(Mandatory = $true)][string]$ShaderAssetPath,
        [Parameter(Mandatory = $true)][string]$ShaderGuid
    )

    $shaderFullPath = Join-Path $ProjectPath $ShaderAssetPath
    $shaderMetaPath = "$shaderFullPath.meta"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $shaderFullPath) | Out-Null

    $shaderSource = @'
Shader "StellaGaia/Fallback/OpaqueColor"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        _Color ("Color", Color) = (0.5, 0.5, 0.5, 1)
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "Queue" = "Geometry" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
            };

            fixed4 _BaseColor;
            fixed4 _Color;

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return _BaseColor * _Color;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
'@

    $metaSource = @"
fileFormatVersion: 2
guid: $ShaderGuid
ShaderImporter:
  externalObjects: {}
  defaultTextures: []
  nonModifiableTextures: []
  userData:
  assetBundleName:
  assetBundleVariant:
"@

    Set-Content -LiteralPath $shaderFullPath -Value $shaderSource -Encoding UTF8
    Set-Content -LiteralPath $shaderMetaPath -Value $metaSource -Encoding UTF8
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($RepairRoot)) {
    $RepairRoot = Join-Path $extractedRoot 'Repairs\OfflineShaderFallback'
}

$ProjectPath = Get-CanonicalPath $ProjectPath
$RepairRoot = Get-CanonicalPath $RepairRoot
$repairDir = Join-Path $RepairRoot $Name
$backupDir = Join-Path $repairDir 'Backups'

Assert-PathUnderOrEqual -Path $ProjectPath -RootPath $extractedRoot -Description 'ProjectPath'
Assert-PathUnderOrEqual -Path $RepairRoot -RootPath $extractedRoot -Description 'RepairRoot'
Assert-SafeProjectAssetPath -Path $ShaderAssetPath

if ($ShaderGuid -notmatch '^[0-9a-f]{32}$') {
    throw "ShaderGuid must be 32 lowercase hex characters: $ShaderGuid"
}
if (-not (Test-Path -LiteralPath (Join-Path $ProjectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) {
    throw "ProjectPath is not an exported Unity project: $ProjectPath"
}

New-Item -ItemType Directory -Force -Path $repairDir | Out-Null
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
}

$pattern = 'm_Shader:\s*\{fileID:\s*4800000,\s*guid:\s*0000000deadbeef15deadf00d0000000,\s*type:\s*2\}'
$replacement = "m_Shader: {fileID: 4800000, guid: $ShaderGuid, type: 3}"
$rows = [System.Collections.Generic.List[object]]::new()
$changedCount = 0

$materialFiles = @(Get-ChildItem -LiteralPath (Join-Path $ProjectPath 'Assets') -Recurse -File -Filter '*.mat')
foreach ($material in $materialFiles) {
    $content = Get-Content -LiteralPath $material.FullName -Raw
    $matches = [regex]::Matches($content, $pattern)
    if ($matches.Count -eq 0) {
        continue
    }

    $relativePath = Get-RelativePath -RootPath $ProjectPath -Path $material.FullName
    $backupPath = Join-Path $backupDir $relativePath
    if (-not $DryRun) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupPath) | Out-Null
        Copy-Item -LiteralPath $material.FullName -Destination $backupPath -Force
        $newContent = [regex]::Replace($content, $pattern, $replacement)
        Set-Content -LiteralPath $material.FullName -Value $newContent -Encoding UTF8
    }

    $changedCount += $matches.Count
    $rows.Add([PSCustomObject]@{
        MaterialPath = $relativePath
        ReplacementCount = $matches.Count
        BackupPath = if ($DryRun) { '' } else { $backupPath }
        ReplacementShaderGuid = $ShaderGuid
        ReplacementShaderAssetPath = $ShaderAssetPath
        DryRun = [bool]$DryRun
    })
}

if ($changedCount -gt 0 -and -not $DryRun) {
    Write-FallbackShaderAsset -ProjectPath $ProjectPath -ShaderAssetPath $ShaderAssetPath -ShaderGuid $ShaderGuid
}

$changedCsv = Join-Path $repairDir 'offline-shader-repair-changed-materials.csv'
$summaryJson = Join-Path $repairDir 'offline-shader-repair-summary.json'
$reportPath = Join-Path $repairDir 'offline-shader-repair-report.md'
$rows | Export-Csv -LiteralPath $changedCsv -NoTypeInformation -Encoding UTF8

$summary = [PSCustomObject]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    ProjectPath = $ProjectPath
    DryRun = [bool]$DryRun
    ScannedMaterialCount = $materialFiles.Count
    ChangedMaterialCount = $rows.Count
    ReplacementCount = $changedCount
    ShaderAssetPath = $ShaderAssetPath
    ShaderGuid = $ShaderGuid
    ChangedCsv = $changedCsv
    Report = $reportPath
}
$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryJson -Encoding UTF8

$reportLines = [System.Collections.Generic.List[string]]::new()
$reportLines.Add("# Offline Deadbeef Shader Repair: $Name")
$reportLines.Add('')
$reportLines.Add("Generated: $($summary.GeneratedAt)")
$reportLines.Add('')
$reportLines.Add(('Project: `{0}`' -f $ProjectPath))
$reportLines.Add('')
$reportLines.Add('## Summary')
$reportLines.Add('')
$reportLines.Add('| Metric | Count |')
$reportLines.Add('| --- | ---: |')
$reportLines.Add("| Scanned materials | $($summary.ScannedMaterialCount) |")
$reportLines.Add("| Changed materials | $($summary.ChangedMaterialCount) |")
$reportLines.Add("| Replaced shader refs | $($summary.ReplacementCount) |")
$reportLines.Add('')
$reportLines.Add('## Replacement')
$reportLines.Add('')
$reportLines.Add(('- Shader asset: `{0}`' -f $ShaderAssetPath))
$reportLines.Add(('- Shader GUID: `{0}`' -f $ShaderGuid))
$reportLines.Add(('- Dry run: `{0}`' -f ([bool]$DryRun)))
$reportLines.Add('')
$reportLines.Add('## Changed Materials')
$reportLines.Add('')
$reportLines.Add('| Material | Replacements |')
$reportLines.Add('| --- | ---: |')
$rows | ForEach-Object {
    $reportLines.Add(('| `{0}` | {1} |' -f $_.MaterialPath, $_.ReplacementCount))
}
$reportLines.Add('')
$reportLines.Add('## Output Files')
$reportLines.Add('')
$reportLines.Add(('- `{0}`' -f $changedCsv))
$reportLines.Add(('- `{0}`' -f $summaryJson))
$reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8

$summary | Format-List
