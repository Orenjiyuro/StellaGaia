[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runtimeFolderMeta = Join-Path $root 'Assets\StellaGaia\Scripts\VASP.meta'
$runtime = Join-Path $root 'Assets\StellaGaia\Scripts\VASP\VisualAssetSubsetProofRunner.cs'
$runtimeMeta = $runtime + '.meta'
$builder = Join-Path $root 'Assets\StellaGaia\Editor\VisualAssetSubsetProofBuilder.cs'
$builderMeta = $builder + '.meta'
$invoke = Join-Path $root 'Tools\AssetImport\Invoke-VisualAssetSubsetProof.ps1'
$offline = Join-Path $root 'Tools\AssetImport\Test-VisualAssetSubsetProofOfflineCompile.ps1'

function Assert-Contract {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw "VASP-T1 static contract failed: $Message"
    }
}

foreach ($path in @(
    $runtimeFolderMeta,
    $runtime,
    $runtimeMeta,
    $builder,
    $builderMeta,
    $invoke,
    $offline
)) {
    Assert-Contract (Test-Path -LiteralPath $path -PathType Leaf) "missing $path"
}

$runtimeText = [IO.File]::ReadAllText($runtime)
$builderText = [IO.File]::ReadAllText($builder)
$invokeText = [IO.File]::ReadAllText($invoke)
$offlineText = [IO.File]::ReadAllText($offline)

foreach ($script in @($invoke, $offline)) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile(
        $script,
        [ref]$tokens,
        [ref]$errors)
    Assert-Contract ($errors.Count -eq 0) "PowerShell parse errors in $script"
}

Assert-Contract ($runtimeText -notmatch '(?m)^\s*using\s+UnityEditor\s*;') 'runtime imports UnityEditor'
Assert-Contract ($runtimeText -notmatch '\bUnityEditor\.|\bBuildPipeline\b|\bEditorApplication\b') 'runtime references Editor APIs'
Assert-Contract ($runtimeText -notmatch '(?i)AssetRipper|Process\.Start|System\.Diagnostics\.Process') 'runtime invokes an external tool'
Assert-Contract ($runtimeText -notmatch 'EverythingNormal') 'runtime self-declares the audited outcome'

foreach ($literal in @(
    'namespace StellaGaia.VASP',
    'public static class VisualAssetSubsetProofRunner',
    'RuntimeInitializeOnLoadMethod',
    'RuntimeInitializeLoadType.BeforeSceneLoad',
    'StellaGaia.UDCP.DirectCharacterPlayerProofRunner, Assembly-CSharp',
    'field.SetValue(null, true)',
    'STELLAGAIA_VASP_PLAYER_INPUT_ROOT',
    'STELLAGAIA_VASP_PLAYER_OUTPUT_ROOT',
    'LO-DCP1-A02/Input',
    'AuthorizedMemberCount = 17',
    'EffectiveBundleCount = 12',
    'VisualAttemptCount = 7',
    'ExplicitExcludedCount = 5',
    'ShadowedMemberCount = 5',
    'AssetBundle.LoadFromFile',
    'LoadAllAssets<AnimationClip>()',
    'LoadAllAssets<GameObject>()',
    'SkinnedMeshRenderer',
    'rootBone',
    'sharedMesh',
    'Hidden/InternalErrorShader',
    '!shader.isSupported',
    'useAutoRandomSeed = false',
    'eligibleAnimationCount',
    'passedAnimationCount',
    'failedAnimationCount',
    'eligibleFxCount',
    'passedFxCount',
    'failedFxCount',
    'eligibleAttackAnimationCount',
    'eligibleAttackFxCount',
    'attack-combination.png',
    'animation-frames',
    'fx-frames',
    'foregroundPixelCount',
    'brightnessRange',
    'distinctColorCount',
    'bundleLoadFailureCount',
    'consumerValidationStarted',
    'failureStage',
    'failureBundle',
    'failureAsset',
    'failureObject',
    'exceptionType',
    'exceptionMessage',
    'exceptionStack',
    'FileMode.CreateNew',
    'Unload(true)',
    'Application.Quit(exitCode)',
    'AwaitVASPFinalAudit'
)) {
    Assert-Contract ($runtimeText.Contains($literal, [StringComparison]::Ordinal)) "runtime missing $literal"
}

$memberPattern = 'new\s+AuthorizedMember\s*\(\s*"(?<path>[^"]+)"\s*,\s*(?<length>\d+)L\s*,\s*"(?<sha>[0-9a-f]{64})"\s*\)'
$members = @([regex]::Matches($runtimeText, $memberPattern))
Assert-Contract ($members.Count -eq 17) "authorized tuple count is $($members.Count)"
Assert-Contract (
    @($members | ForEach-Object { $_.Groups['path'].Value } |
        Select-Object -Unique).Count -eq 17
) 'authorized paths are not unique'
Assert-Contract (
    (@($members | ForEach-Object { [long]$_.Groups['length'].Value } |
        Measure-Object -Sum).Sum) -eq 117082750L
) 'authorized input bytes drifted'

$visualExpected = @(
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d',
    'Persistent_Store/AssetBundles/char_14401_models.unity3d',
    'Persistent_Store/AssetBundles/char_14401_animations.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d',
    'Persistent_Store/AssetBundles/char_14401_fx.unity3d'
)
$excludedExpected = @(
    'Persistent_Store/AssetBundles/char_14401.unity3d',
    'Persistent_Store/AssetBundles/char_14401_timeline.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d'
)

function Get-FrozenArray {
    param([string]$Name)
    $match = [regex]::Match(
        $runtimeText,
        "private\s+static\s+readonly\s+string\[\]\s+$Name\s*=\s*\{(?<body>.*?)\};",
        [Text.RegularExpressions.RegexOptions]::Singleline)
    Assert-Contract $match.Success "array $Name is missing"
    return @([regex]::Matches($match.Groups['body'].Value, '"(?<value>[^"]+)"') |
        ForEach-Object { $_.Groups['value'].Value })
}

$visualActual = @(Get-FrozenArray 'VisualBundlePaths')
$excludedActual = @(Get-FrozenArray 'ExplicitExcludedPaths')
Assert-Contract ($visualActual.Count -eq 7) 'visual partition is not 7'
Assert-Contract ($excludedActual.Count -eq 5) 'excluded partition is not 5'
Assert-Contract (($visualActual -join "`n") -ceq ($visualExpected -join "`n")) 'visual order drifted'
Assert-Contract (($excludedActual -join "`n") -ceq ($excludedExpected -join "`n")) 'excluded set drifted'
Assert-Contract (@($visualActual + $excludedActual | Select-Object -Unique).Count -eq 12) '7/5 partition overlaps'

Assert-Contract (([regex]::Matches($runtimeText, 'AssetBundle\.LoadFromFile\s*\(')).Count -eq 1) 'runtime does not have one load call site'
$attemptIndex = $runtimeText.IndexOf('AttemptVisualBundles(', [StringComparison]::Ordinal)
$failureGateIndex = $runtimeText.IndexOf('report.bundleLoadFailureCount != 0', [StringComparison]::Ordinal)
$consumerIndex = $runtimeText.IndexOf('report.consumerValidationStarted = true', [StringComparison]::Ordinal)
Assert-Contract ($attemptIndex -ge 0 -and $failureGateIndex -gt $attemptIndex -and $consumerIndex -gt $failureGateIndex) 'consumer gate is not after complete load diagnostics'
Assert-Contract ($runtimeText.Contains('continue;', [StringComparison]::Ordinal)) 'load failure does not continue diagnostics'
Assert-Contract ($runtimeText -match 'eligibleAnimationCount\s*!=\s*\r?\n?\s*report\.passedAnimationCount\s*\+\s*report\.failedAnimationCount') 'animation conservation missing'
Assert-Contract ($runtimeText -match 'eligibleFxCount\s*!=\s*\r?\n?\s*report\.passedFxCount\s*\+\s*report\.failedFxCount') 'FX conservation missing'

foreach ($literal in @(
    'public static class VisualAssetSubsetProofBuilder',
    'public static void Build()',
    '2022.3.62f2',
    'Assets/StellaGaia/Scenes/SampleValidation.unity',
    'BuildTarget.StandaloneWindows64',
    'BuildPipeline.BuildPlayer',
    'VisualAssetSubsetProof.exe',
    'VASP-LO1-Player',
    'FileMode.CreateNew',
    'EditorApplication.Exit(exitCode)'
)) {
    Assert-Contract ($builderText.Contains($literal, [StringComparison]::Ordinal)) "builder missing $literal"
}

foreach ($literal in @(
    '[CmdletBinding()]',
    'param()',
    'C:\SoftWork\Unity\Editor\Unity.exe',
    'VASP-LO1-Player',
    'VisualAssetSubsetProofBuilder.Build',
    'VisualAssetSubsetProof.exe',
    'STELLAGAIA_VASP_PLAYER_INPUT_ROOT',
    'STELLAGAIA_VASP_PLAYER_OUTPUT_ROOT',
    'unityBuildProcessStartCount',
    'playerProcessStartCount',
    'FileMode]::CreateNew',
    'AwaitVASPFinalAudit'
)) {
    Assert-Contract ($invokeText.Contains($literal, [StringComparison]::Ordinal)) "orchestrator missing $literal"
}
Assert-Contract (([regex]::Matches($invokeText, 'ProcessStartInfo\]::new\(')).Count -eq 2) 'orchestrator must expose exactly two process sites'
Assert-Contract ($invokeText -notmatch '(?i)-nographics|retry|fallback') 'orchestrator contains a forbidden route'
Assert-Contract ($invokeText -notmatch '(?i)FileName\s*=\s*.+AssetRipper') 'orchestrator can launch AssetRipper'

foreach ($literal in @(
    'Data\NetCoreRuntime\dotnet.exe',
    'Data\DotNetSdkRoslyn\csc.dll',
    'Data\NetStandard',
    'Data\Managed\UnityEngine',
    'UnityEditor.dll',
    'UnityEditor.CoreModule.dll',
    'VisualAssetSubsetProofRunner.cs',
    'VisualAssetSubsetProofBuilder.cs',
    'VASP-T1-OfflineCompile',
    'warningCount',
    'errorCount',
    'not a Unity Player build or runtime validation'
)) {
    Assert-Contract ($offlineText.Contains($literal, [StringComparison]::Ordinal)) "offline compile missing $literal"
}
Assert-Contract ($offlineText -notmatch 'Unity\.exe') 'offline compile can launch Unity'

"VASP-T1 static GREEN: authorized=17 effective=12 visual=7 excluded=5"
