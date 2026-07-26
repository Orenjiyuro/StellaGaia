[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-SfxrTest {
    param(
        [Parameter(Mandatory)][bool] $Condition,
        [Parameter(Mandatory)][string] $Message
    )
    if (-not $Condition) {
        throw "SFXR-T2 test failed: $Message"
    }
}

function Get-TestGuid {
    param([Parameter(Mandatory)][string] $Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant().Substring(0, 32)
}

function Write-TestUtf8 {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Text
    )
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path)) | Out-Null
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Add-TestAsset {
    param(
        [Parameter(Mandatory)][string] $AssetsRoot,
        [Parameter(Mandatory)][string] $RelativePath,
        [Parameter(Mandatory)][string] $Content,
        [string] $Guid
    )
    if ([string]::IsNullOrWhiteSpace($Guid)) {
        $Guid = Get-TestGuid -Text $RelativePath
    }
    $path = Join-Path $AssetsRoot $RelativePath
    Write-TestUtf8 -Path $path -Text $Content
    Write-TestUtf8 -Path ($path + '.meta') -Text "fileFormatVersion: 2`nguid: $Guid`n"
    return $Guid
}

function New-TestFixture {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][ValidateSet('Ready', 'Unresolved', 'Duplicate', 'Ambiguous')][string] $Mode
    )

    $assets = Join-Path $Root 'Assets'
    [IO.Directory]::CreateDirectory($assets) | Out-Null
    $materialRelative = 'shared/materials/main.mat'
    $textureRelative = 'shared/textures/main.png'
    $textureGuid = Add-TestAsset -AssetsRoot $assets -RelativePath $textureRelative -Content 'synthetic-png'
    $materialGuid = Add-TestAsset -AssetsRoot $assets -RelativePath $materialRelative -Content @"
%YAML 1.1
--- !u!21 &2100000
Material:
  m_Shader: {fileID: 4800000, guid: 0000000000000000f000000000000000, type: 0}
  m_SavedProperties:
    m_TexEnvs:
    - _MainTex:
        m_Texture: {fileID: 2800000, guid: $textureGuid, type: 3}
"@
    $modelGuid = Get-TestGuid -Text 'assetbundles/actor/character/14401/models/14401.prefab'
    if ($Mode -eq 'Duplicate') {
        $materialMeta = Join-Path $assets ($materialRelative + '.meta')
        Write-TestUtf8 -Path $materialMeta -Text "fileFormatVersion: 2`nguid: $modelGuid`n"
    }
    $modelReferenceGuid = if ($Mode -eq 'Unresolved') { '11111111111111111111111111111111' } else { $materialGuid }
    [void](Add-TestAsset `
        -AssetsRoot $assets `
        -RelativePath 'assetbundles/actor/character/14401/models/14401.prefab' `
        -Guid $modelGuid `
        -Content @"
%YAML 1.1
--- !u!1 &1
GameObject:
  m_Component:
  - component: {fileID: 4}
--- !u!4 &4
Transform:
  m_GameObject: {fileID: 1}
  m_Material: {fileID: 2100000, guid: $modelReferenceGuid, type: 2}
"@)

    for ($index = 1; $index -le 61; $index++) {
        $name = if ($index -eq 1) { '144_Attack.anim' } else { '144_Action_{0:D2}.anim' -f $index }
        [void](Add-TestAsset `
            -AssetsRoot $assets `
            -RelativePath "assetbundles/actor/character/14401/animations/$name" `
            -Content "%YAML 1.1`n--- !u!74 &7400000`nAnimationClip:`n  m_Name: $name`n")
    }

    for ($index = 1; $index -le 95; $index++) {
        $name = 'fx_14401_Attack_{0:D3}.prefab' -f $index
        $extraReference = if ($Mode -eq 'Ambiguous' -and $index -eq 1) {
            '  m_ExternalLocalReference: {fileID: 114}'
        } else {
            ''
        }
        [void](Add-TestAsset `
            -AssetsRoot $assets `
            -RelativePath "assetbundles/actor/character/14401/fx/$name" `
            -Content @"
%YAML 1.1
--- !u!1 &1
GameObject:
  m_Component:
  - component: {fileID: 4}
  - component: {fileID: 198}
  - component: {fileID: 199}
  - component: {fileID: 114}
--- !u!4 &4
Transform:
  m_GameObject: {fileID: 1}
--- !u!198 &198
ParticleSystem:
  m_GameObject: {fileID: 1}
$extraReference
--- !u!199 &199
ParticleSystemRenderer:
  m_GameObject: {fileID: 1}
  m_Materials:
  - {fileID: 2100000, guid: $materialGuid, type: 2}
--- !u!114 &114
MonoBehaviour:
  m_GameObject: {fileID: 1}
  m_Script: {fileID: 11500000, guid: 99999999999999999999999999999999, type: 3}
"@)
    }
    return $assets
}

$runnerPath = Join-Path $PSScriptRoot 'New-ScriptStrippedFxStage.ps1'
Assert-SfxrTest (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'runner is missing'

$runnerText = [IO.File]::ReadAllText($runnerPath)
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($runnerPath, [ref]$tokens, [ref]$parseErrors)
Assert-SfxrTest (@($parseErrors).Count -eq 0) 'runner syntax is invalid'
Assert-SfxrTest ($runnerText.Contains("'ab797c994e896d7ff8e914bdaff3bda14ef7c8cb7299f85857b3ceea8abbb94b'", [StringComparison]::Ordinal)) 'terminal identity is not fixed'
Assert-SfxrTest ($runnerText.Contains("'82ffafec53e6cf7c2270453b3054c43fd23022f03de9c307daf312701ee1bd61'", [StringComparison]::Ordinal)) 'log identity is not fixed'
Assert-SfxrTest ($runnerText.Contains('expectedExportFileCount = 1966', [StringComparison]::Ordinal)) 'Export file count is not fixed'
Assert-SfxrTest ($runnerText.Contains('expectedExportBytes = [int64]414098635', [StringComparison]::Ordinal)) 'Export byte count is not fixed'
Assert-SfxrTest ($runnerText.Contains('expectedAnimationSeedCount = 61', [StringComparison]::Ordinal)) 'animation seed count is not fixed'
Assert-SfxrTest ($runnerText.Contains('expectedFxSeedCount = 95', [StringComparison]::Ordinal)) 'FX seed count is not fixed'
Assert-SfxrTest ($runnerText.Contains("'0000000000000000f000000000000000'", [StringComparison]::Ordinal)) 'builtin GUID allowlist is missing'
Assert-SfxrTest ($runnerText.Contains("'ReadyForScriptStrippedUnityStaging'", [StringComparison]::Ordinal)) 'Ready decision is missing'
Assert-SfxrTest ($runnerText.Contains("'BlockedRequiredVisualDependency'", [StringComparison]::Ordinal)) 'dependency block decision is missing'
Assert-SfxrTest ($runnerText.Contains("'BlockedAmbiguousYamlRewrite'", [StringComparison]::Ordinal)) 'rewrite block decision is missing'
Assert-SfxrTest ($runnerText.Contains("'BlockedExportIdentityDrift'", [StringComparison]::Ordinal)) 'identity block decision is missing'
Assert-SfxrTest ($runnerText.Contains('[IO.FileMode]::CreateNew', [StringComparison]::Ordinal)) 'CreateNew publication is missing'
Assert-SfxrTest ($runnerText.Contains('^--- !u!(?<classId>\d+)', [StringComparison]::Ordinal)) 'YAML document recognition is missing'
Assert-SfxrTest ($runnerText.Contains("Groups['classId'].Value -ceq '114'", [StringComparison]::Ordinal)) 'MonoBehaviour class recognition is missing'
Assert-SfxrTest ($runnerText.Contains('m_Component', [StringComparison]::Ordinal)) 'GameObject component rewrite is missing'
Assert-SfxrTest ($runnerText.Contains('deadbeef', [StringComparison]::OrdinalIgnoreCase)) 'deadbeef rejection is missing'
Assert-SfxrTest (-not $runnerText.Contains('Start-Process', [StringComparison]::OrdinalIgnoreCase)) 'external process start is forbidden'
Assert-SfxrTest (-not $runnerText.Contains('Unity.exe', [StringComparison]::OrdinalIgnoreCase)) 'Unity is forbidden'
Assert-SfxrTest (-not $runnerText.Contains('AssetRipper.GUI', [StringComparison]::OrdinalIgnoreCase)) 'AssetRipper is forbidden'
Assert-SfxrTest (-not $runnerText.Contains('sourceBoundary', [StringComparison]::OrdinalIgnoreCase)) 'real source access is forbidden'

$previousDefinitionsMode = $env:STELLAGAIA_SFXR_T2_DEFINITIONS_ONLY
try {
    $env:STELLAGAIA_SFXR_T2_DEFINITIONS_ONLY = '1'
    . $runnerPath
} finally {
    $env:STELLAGAIA_SFXR_T2_DEFINITIONS_ONLY = $previousDefinitionsMode
}
Assert-SfxrTest ($null -ne (Get-Command Invoke-SfxrStageCore -ErrorAction SilentlyContinue)) 'core function was not loaded'

$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('sfxr-t2-test-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
try {
    $readyAssets = New-TestFixture -Root (Join-Path $temporaryRoot 'ready') -Mode Ready
    $readyStage = Join-Path $temporaryRoot 'ready-stage'
    $ready = Invoke-SfxrStageCore -AssetsRoot $readyAssets -StagedRoot $readyStage
    Assert-SfxrTest ($ready.decision -ceq 'ReadyForScriptStrippedUnityStaging') 'ready fixture did not pass'
    Assert-SfxrTest ($ready.modelSeedCount -eq 1 -and $ready.animationSeedCount -eq 61 -and $ready.fxSeedCount -eq 95) 'seed conservation failed'
    Assert-SfxrTest ($ready.monoBehaviourDocumentCount -eq 95 -and $ready.stagedMonoBehaviourDocumentCount -eq 0) 'MonoBehaviour stripping failed'
    Assert-SfxrTest ($ready.stagedScriptReferenceCount -eq 0 -and $ready.generatedScriptFileCount -eq 0) 'script-free stage failed'
    Assert-SfxrTest ($ready.danglingStrippedFileIdCount -eq 0) 'stripped local fileID is dangling'
    Assert-SfxrTest ($ready.unresolvedRequiredGuidCount -eq 0) 'ready fixture has unresolved GUIDs'
    Assert-SfxrTest ($ready.particleSystemDocumentCount -eq 95 -and $ready.rendererDocumentCount -eq 95) 'visual documents were not conserved'

    $unresolvedAssets = New-TestFixture -Root (Join-Path $temporaryRoot 'unresolved') -Mode Unresolved
    $unresolvedStage = Join-Path $temporaryRoot 'unresolved-stage'
    $unresolved = Invoke-SfxrStageCore -AssetsRoot $unresolvedAssets -StagedRoot $unresolvedStage
    Assert-SfxrTest ($unresolved.decision -ceq 'BlockedRequiredVisualDependency') 'unresolved GUID did not block'
    Assert-SfxrTest (-not (Test-Path -LiteralPath $unresolvedStage)) 'blocked dependency published staging'

    $duplicateAssets = New-TestFixture -Root (Join-Path $temporaryRoot 'duplicate') -Mode Duplicate
    $duplicateStage = Join-Path $temporaryRoot 'duplicate-stage'
    $duplicate = Invoke-SfxrStageCore -AssetsRoot $duplicateAssets -StagedRoot $duplicateStage
    Assert-SfxrTest ($duplicate.decision -ceq 'BlockedExportIdentityDrift') 'duplicate GUID did not block'
    Assert-SfxrTest (-not (Test-Path -LiteralPath $duplicateStage)) 'duplicate GUID published staging'

    $ambiguousAssets = New-TestFixture -Root (Join-Path $temporaryRoot 'ambiguous') -Mode Ambiguous
    $ambiguousStage = Join-Path $temporaryRoot 'ambiguous-stage'
    $ambiguous = Invoke-SfxrStageCore -AssetsRoot $ambiguousAssets -StagedRoot $ambiguousStage
    Assert-SfxrTest ($ambiguous.decision -ceq 'BlockedAmbiguousYamlRewrite') 'ambiguous local fileID did not block'
    Assert-SfxrTest (-not (Test-Path -LiteralPath $ambiguousStage)) 'ambiguous rewrite published staging'
} finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}

Write-Output 'SFXR-T2 GREEN: ready=1 unresolved=blocked duplicate=blocked ambiguous=blocked'
