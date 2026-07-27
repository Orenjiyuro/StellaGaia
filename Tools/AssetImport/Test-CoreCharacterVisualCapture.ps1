[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runnerPath = Join-Path $root 'Assets\StellaGaia\Scripts\CCVC\CoreCharacterVisualCaptureRunner.cs'
$builderPath = Join-Path $root 'Assets\StellaGaia\Editor\CoreCharacterVisualCaptureBuilder.cs'
$invokePath = Join-Path $root 'Tools\AssetImport\Invoke-CoreCharacterVisualCapture.ps1'
$offlinePath = Join-Path $root 'Tools\AssetImport\Test-CoreCharacterVisualCaptureOfflineCompile.ps1'
$legacyPath = Join-Path $root 'Assets\StellaGaia\Scripts\VASP\VisualAssetSubsetProofRunner.cs'

$legacy = [IO.File]::ReadAllText($legacyPath)
foreach ($fragment in @(
    'AttemptVisualBundles(effective, loadedBundles, report);',
    'if (report.bundleLoadFailureCount != 0)',
    'report.consumerValidationStarted = true;',
    '"char_14401_fx.unity3d"',
    '"char_14401_buff.unity3d"',
    '"char_14401_weapons.unity3d"'
)) {
    if (-not $legacy.Contains($fragment)) {
        throw "Legacy FX suppression evidence missing: $fragment"
    }
}
if ($legacy.IndexOf('if (report.bundleLoadFailureCount != 0)', [StringComparison]::Ordinal) -gt
    $legacy.IndexOf('report.consumerValidationStarted = true;', [StringComparison]::Ordinal)) {
    throw 'Legacy VASP no longer suppresses core validation after an FX bundle failure.'
}

foreach ($path in @($runnerPath, $builderPath, $invokePath, $offlinePath)) {
    if (-not [IO.File]::Exists($path)) {
        throw "CCVC harness file missing: $path"
    }
}

$runner = [IO.File]::ReadAllText($runnerPath)
$builder = [IO.File]::ReadAllText($builderPath)
$invoke = [IO.File]::ReadAllText($invokePath)
$offline = [IO.File]::ReadAllText($offlinePath)

$coreTuples = @(
    @('xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d', '4909859L', 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd'),
    @('xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d', '6682L', '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb'),
    @('Persistent_Store/AssetBundles/char_14401_models.unity3d', '3080984L', '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7'),
    @('Persistent_Store/AssetBundles/char_14401_animations.unity3d', '37819874L', '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d')
)
foreach ($tuple in $coreTuples) {
    foreach ($value in $tuple) {
        if (-not $runner.Contains($value) -or -not $invoke.Contains($value.Replace('L', ''))) {
            throw "Frozen core tuple value missing: $value"
        }
    }
}
$tupleMatches = [regex]::Matches(
    $runner,
    'new AuthorizedMember\(\s*"([^"]+)"\s*,\s*(\d+)L\s*,\s*"([0-9a-f]{64})"\s*\)')
if ($tupleMatches.Count -ne $coreTuples.Count) {
    throw 'Runtime authorized-member set does not contain exactly four tuples.'
}
for ($index = 0; $index -lt $coreTuples.Count; $index++) {
    $actual = @(
        $tupleMatches[$index].Groups[1].Value,
        ($tupleMatches[$index].Groups[2].Value + 'L'),
        $tupleMatches[$index].Groups[3].Value
    )
    if (($actual -join '|') -ne ($coreTuples[$index] -join '|')) {
        throw "Runtime tuple order/identity mismatch at ordinal $($index + 1)."
    }
}

foreach ($denied in @(
    'char_14401_fx.unity3d',
    'char_14401_buff.unity3d',
    'char_14401_weapons.unity3d'
)) {
    if (-not $runner.Contains($denied) -or -not $invoke.Contains($denied)) {
        throw "Core deny-list missing: $denied"
    }
}
foreach ($fragment in @(
    'AssetBundle.LoadFromFile',
    'LoadAllAssets<GameObject>()',
    'LoadAllAssets<AnimationClip>()',
    'SkinnedMeshRenderer',
    'rootBone',
    'sharedMesh',
    'shader.isSupported',
    'Hidden/InternalErrorShader',
    'SampleAnimation',
    '0.25f',
    '0.50f',
    '0.75f',
    'ConstantPose',
    'camera.Render();',
    'RenderTexture',
    'EncodeToPNG',
    'foregroundPixelCount',
    'brightnessRange',
    'distinctColorCount',
    'magentaPixelCount',
    'front.png',
    'three-quarter.png',
    'side.png',
    'idle-00.png',
    'idle-25.png',
    'idle-50.png',
    'idle-75.png',
    'attack-00.png',
    'attack-25.png',
    'attack-50.png',
    'attack-75.png',
    'AwaitHumanVisualAcceptance',
    'CoreVisualFailed'
)) {
    if (-not $runner.Contains($fragment)) {
        throw "Runtime contract fragment missing: $fragment"
    }
}
$captureMethod = [regex]::Match(
    $runner,
    '(?s)private static string\[\] CaptureNames\(\).*?return new\[\]\s*\{(?<body>.*?)\};')
if (-not $captureMethod.Success) {
    throw 'Capture name registry could not be parsed.'
}
$actualCaptures = @(
    [regex]::Matches($captureMethod.Groups['body'].Value, '"([^"]+\.png)"') |
        ForEach-Object { $_.Groups[1].Value }
)
$expectedCaptures = @(
    'front.png', 'three-quarter.png', 'side.png',
    'idle-00.png', 'idle-25.png', 'idle-50.png', 'idle-75.png',
    'attack-00.png', 'attack-25.png', 'attack-50.png', 'attack-75.png'
)
if (($actualCaptures -join '|') -ne ($expectedCaptures -join '|')) {
    throw 'Capture registry is not the exact ordered 11-file contract.'
}
foreach ($forbidden in @('UnityEditor', 'EverythingNormal', 'AssetRipper', 'Process.Start')) {
    if ($runner.Contains($forbidden)) {
        throw "Forbidden runtime dependency found: $forbidden"
    }
}
if (-not $runner.Contains('passedAnimationCount + report.failedAnimationCount')) {
    throw 'Animation conservation gate is missing.'
}
if (-not $runner.Contains('SelectUniqueRepresentative')) {
    throw 'Deterministic unique idle/attack selection is missing.'
}
if (-not $runner.Contains('FileMode.CreateNew')) {
    throw 'Runtime evidence must use CreateNew.'
}

foreach ($fragment in @(
    '2022.3.62f2',
    'SampleValidation.unity',
    'StandaloneWindows64',
    'CoreCharacterVisualCapture.exe',
    'FileMode.CreateNew'
)) {
    if (-not $builder.Contains($fragment)) {
        throw "Builder contract fragment missing: $fragment"
    }
}

foreach ($fragment in @(
    'CCVC-LO1',
    'STELLAGAIA_CCVC_PLAYER_INPUT_ROOT',
    'STELLAGAIA_CCVC_PLAYER_OUTPUT_ROOT',
    'unityBuildProcessStartCount',
    'playerProcessStartCount',
    'processStartCount',
    'WaitForExit',
    'Kill($true)',
    'AwaitHumanVisualAcceptance'
)) {
    if (-not $invoke.Contains($fragment)) {
        throw "Orchestrator contract fragment missing: $fragment"
    }
}
if ([regex]::Matches($invoke, '\.Start\(\)').Count -ne 2) {
    throw 'Orchestrator must contain exactly one Unity and one Player start.'
}
if ($invoke.Contains('-nographics')) {
    throw 'Player capture must retain graphics.'
}
if (-not $invoke.Contains('[IO.FileMode]::CreateNew')) {
    throw 'Orchestration result must use CreateNew.'
}
if ($invoke.Contains('PB-I03') -or $invoke.Contains('manifest')) {
    throw 'Orchestrator must not access real-source binding.'
}

foreach ($fragment in @(
    'DotNetSdkRoslyn\csc.dll',
    'CoreCharacterVisualCaptureRunner.cs',
    'CoreCharacterVisualCaptureBuilder.cs',
    'warnaserror+',
    'runtimeWarningCount',
    'builderWarningCount',
    'not a Unity Player build or runtime validation'
)) {
    if (-not $offline.Contains($fragment)) {
        throw "Offline compile contract fragment missing: $fragment"
    }
}

"CCVC focused contract GREEN: coreMembers=4 captures=11 buildStarts=1 playerStarts=1"
