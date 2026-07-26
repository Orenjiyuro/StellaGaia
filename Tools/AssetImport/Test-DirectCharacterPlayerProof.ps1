Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runtimeFolderMeta = Join-Path $repositoryRoot 'Assets\StellaGaia\Scripts\UDCP.meta'
$runtimePath = Join-Path $repositoryRoot 'Assets\StellaGaia\Scripts\UDCP\DirectCharacterPlayerProofRunner.cs'
$runtimeMetaPath = $runtimePath + '.meta'
$builderPath = Join-Path $repositoryRoot 'Assets\StellaGaia\Editor\DirectCharacterPlayerProofBuilder.cs'
$builderMetaPath = $builderPath + '.meta'
$orchestratorPath = Join-Path $repositoryRoot 'Tools\AssetImport\Invoke-DirectCharacterPlayerProof.ps1'
$offlineCompilePath = Join-Path $repositoryRoot 'Tools\AssetImport\Test-DirectCharacterPlayerProofOfflineCompile.ps1'
$scenePath = Join-Path $repositoryRoot 'Assets\StellaGaia\Scenes\SampleValidation.unity'
$projectVersionPath = Join-Path $repositoryRoot 'ProjectSettings\ProjectVersion.txt'

function Assert-Contract {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw "UDCP-T3 static contract failed: $Message"
    }
}

foreach ($requiredPath in @(
    $runtimeFolderMeta,
    $runtimePath,
    $runtimeMetaPath,
    $builderPath,
    $builderMetaPath,
    $orchestratorPath,
    $offlineCompilePath
)) {
    Assert-Contract (Test-Path -LiteralPath $requiredPath -PathType Leaf) "required file missing: $requiredPath"
}

$runtime = [System.IO.File]::ReadAllText($runtimePath)
$runtimeMeta = [System.IO.File]::ReadAllText($runtimeMetaPath)
$runtimeFolderMetaText = [System.IO.File]::ReadAllText($runtimeFolderMeta)
$builder = [System.IO.File]::ReadAllText($builderPath)
$builderMeta = [System.IO.File]::ReadAllText($builderMetaPath)
$orchestrator = [System.IO.File]::ReadAllText($orchestratorPath)
$offline = [System.IO.File]::ReadAllText($offlineCompilePath)
Assert-Contract (Test-Path -LiteralPath $scenePath -PathType Leaf) 'fixed build scene is missing'
Assert-Contract (
    ([System.IO.File]::ReadAllText($projectVersionPath)).Contains(
        'm_EditorVersion: 2022.3.62f2',
        [System.StringComparison]::Ordinal)
) 'project Unity version drifted'
foreach ($scriptPath in @($orchestratorPath, $offlineCompilePath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $scriptPath,
        [ref]$tokens,
        [ref]$parseErrors)
    Assert-Contract ($parseErrors.Count -eq 0) "PowerShell parse failure: $scriptPath"
}

Assert-Contract ($runtime -notmatch '(?m)^\s*using\s+UnityEditor\s*;') 'runtime imports UnityEditor'
Assert-Contract ($runtime -notmatch '\bUnityEditor\.|\bBuildPipeline\b|\bEditorApplication\b') 'runtime references an Editor API'
Assert-Contract ($runtime -notmatch '(?i)AssetRipper|Process\.Start|System\.Diagnostics\.Process') 'runtime invokes an external tool'

foreach ($literal in @(
    'namespace StellaGaia.UDCP',
    'public static class DirectCharacterPlayerProofRunner',
    'RuntimeInitializeOnLoadMethod',
    'Application.unityVersion',
    '2022.3.62f2',
    'STELLAGAIA_UDCP_PLAYER_INPUT_ROOT',
    'STELLAGAIA_UDCP_PLAYER_OUTPUT_ROOT',
    'ExpectedInputRelativePath',
    'LO-DCP1-A02/Input',
    'AuthorizedMemberCount = 17',
    'EffectiveBundleCount = 12',
    'AuthorizedMembers',
    'expectedLength',
    'expectedSha256',
    'FileMode.CreateNew',
    'terminal-result.json',
    'player-proof/1.0.0',
    'AssetBundle.LoadFromFile',
    'Unload(true)',
    'LoadAllAssets<AnimationClip>()',
    'char_14401_animations.unity3d',
    'totalAnimationClipCount',
    'eligibleAnimationCount',
    'passedAnimationCount',
    'failedAnimationCount',
    'report.failedAnimationCount != 0',
    'RestoreBaselinePose',
    'clip.length * 0.25f',
    'clip.length * 0.50f',
    'clip.length * 0.75f',
    'lastFrameTime',
    'ValidateFinitePoseAndBounds',
    'animationResults',
    'LoadAllAssets<GameObject>()',
    'char_14401_fx.unity3d',
    'char_14401_buff.unity3d',
    'char_14401_weapons.unity3d',
    'HasVisualComponents',
    'SimulationTimes',
    'useAutoRandomSeed = false',
    'Hidden/InternalErrorShader',
    'shader == null',
    '!shader.isSupported',
    'eligibleFxCount',
    'passedFxCount',
    'failedFxCount',
    'report.failedFxCount != 0',
    'eligibleAttackFxCount',
    'passedAttackFxCount',
    'failedAttackFxCount',
    'attack-combination.png',
    'RequireVisibility',
    'foregroundPixelCount',
    'brightnessRange',
    'distinctColorCount',
    'characterBrightnessRange',
    'characterDistinctColorCount',
    'fxBrightnessRange',
    'fxDistinctColorCount',
    'compositeBrightnessRange',
    'compositeDistinctColorCount',
    'modelConsumerProofPassed',
    'animationConsumerProofPassed',
    'battleFxConsumerProofPassed',
    'screenshotProofPassed',
    'failureStage',
    'failureBundle',
    'failureAsset',
    'failureObject',
    'exceptionType',
    'exceptionMessage',
    'exceptionStack',
    'Application.Quit(exitCode)'
)) {
    Assert-Contract ($runtime.Contains($literal, [System.StringComparison]::Ordinal)) "runtime contract missing: $literal"
}

$memberPattern = 'new\s+AuthorizedMember\s*\(\s*"(?<path>(?:Persistent_Store/AssetBundles|xtlr_Data/StreamingAssets/InstallResource)/char_14401[^"]*\.unity3d)"\s*,\s*(?<length>\d+)L\s*,\s*"(?<sha>[0-9a-f]{64})"\s*\)'
$members = @([regex]::Matches($runtime, $memberPattern))
Assert-Contract ($members.Count -eq 17) "expected 17 frozen tuples, found $($members.Count)"
Assert-Contract (@($members | ForEach-Object { $_.Groups['path'].Value } | Select-Object -Unique).Count -eq 17) 'runtime tuple paths are not unique'
Assert-Contract (
    (@($members | ForEach-Object { [long]$_.Groups['length'].Value } | Measure-Object -Sum).Sum) -eq 117082750L
) 'runtime tuple byte conservation drifted'

$effective = [ordered]@{}
foreach ($member in $members) {
    $relativePath = $member.Groups['path'].Value
    $logicalName = [System.IO.Path]::GetFileName($relativePath)
    $priority = if ($relativePath.StartsWith('Persistent_Store/AssetBundles/', [System.StringComparison]::Ordinal)) { 0 } else { 1 }
    if (-not $effective.Contains($logicalName) -or $priority -lt $effective[$logicalName].priority) {
        $effective[$logicalName] = [pscustomobject]@{ priority = $priority; relativePath = $relativePath }
    }
}
Assert-Contract ($effective.Count -eq 12) "expected 12 effective bundles, found $($effective.Count)"
Assert-Contract (
    $effective['char_14401_animations.unity3d'].relativePath -ceq
    'Persistent_Store/AssetBundles/char_14401_animations.unity3d'
) 'animation effective override drifted'

Assert-Contract ($runtime -match 'foreach\s*\(\s*AnimationClip\s+\w+\s+in\s+\w+\s*\)') 'all animation clips are not enumerated'
Assert-Contract ($runtime -match 'foreach\s*\(\s*GameObject\s+\w+\s+in\s+\w+\s*\)') 'all FX GameObjects are not enumerated'
Assert-Contract ($runtime -match 'result\.status\s*=\s*"Failed"') 'per-subject failures are not retained'
Assert-Contract (
    $runtime -match 'eligibleAnimationCount\s*!=\s*\r?\n?\s*report\.passedAnimationCount\s*\+\s*report\.failedAnimationCount'
) 'animation result conservation is absent'
Assert-Contract (
    $runtime -match 'eligibleFxCount\s*!=\s*\r?\n?\s*report\.passedFxCount\s*\+\s*report\.failedFxCount'
) 'FX result conservation is absent'

foreach ($literal in @(
    'namespace StellaGaia.Editor',
    'public static class DirectCharacterPlayerProofBuilder',
    'public static void Build()',
    'Application.unityVersion',
    '2022.3.62f2',
    'Assets/StellaGaia/Scenes/SampleValidation.unity',
    'BuildTarget.StandaloneWindows64',
    'BuildPipeline.BuildPlayer',
    'DirectCharacterPlayerProof.exe',
    'BuildResult.Succeeded',
    'EditorApplication.Exit(exitCode)',
    'FileMode.CreateNew',
    'build-result.json'
)) {
    Assert-Contract ($builder.Contains($literal, [System.StringComparison]::Ordinal)) "builder contract missing: $literal"
}
Assert-Contract ($builder -notmatch '(?i)AssetRipper|AssetBundle\.LoadFromFile') 'builder consumes bundle content'

foreach ($literal in @(
    '[CmdletBinding()]',
    'param()',
    'C:\SoftWork\Unity\Editor\Unity.exe',
    'Data\PlaybackEngines\windowsstandalonesupport',
    'Assets\StellaGaia\Scenes\SampleValidation.unity',
    'UDCP-LO2-Player',
    'DirectCharacterPlayerProofBuilder.Build',
    'DirectCharacterPlayerProof.exe',
    'STELLAGAIA_UDCP_PLAYER_INPUT_ROOT',
    'STELLAGAIA_UDCP_PLAYER_OUTPUT_ROOT',
    'processStartCount',
    'unityBuildProcessStartCount',
    'playerProcessStartCount',
    'build-result.json',
    'terminal-result.json',
    'orchestration-result.json',
    'FileMode]::CreateNew',
    'AwaitUDCPFinalAudit'
)) {
    Assert-Contract ($orchestrator.Contains($literal, [System.StringComparison]::Ordinal)) "orchestrator contract missing: $literal"
}
Assert-Contract ($orchestrator -notmatch '(?i)RunFullValidation|retry|fallback') 'orchestrator contains a forbidden route'
Assert-Contract ($orchestrator -notmatch '(?i)FileName\s*=\s*.+AssetRipper') 'orchestrator can launch AssetRipper'
Assert-Contract (
    ([regex]::Matches($orchestrator, 'ProcessStartInfo\]::new\(')).Count -eq 2
) 'orchestrator does not freeze exactly two top-level process launches'

foreach ($literal in @(
    'C:\SoftWork\Unity\Editor\Data\NetCoreRuntime\dotnet.exe',
    'C:\SoftWork\Unity\Editor\Data\DotNetSdkRoslyn\csc.dll',
    'Data\NetStandard\ref\2.1.0',
    'Data\NetStandard\compat\2.1.0\shims',
    'Data\Managed\UnityEngine',
    'UnityEditor.dll',
    'UnityEditor.CoreModule.dll',
    'DirectCharacterPlayerProofRunner.cs',
    'DirectCharacterPlayerProofBuilder.cs',
    'UDCP-T3-OfflineCompile',
    '-warnaserror+',
    'runtimeErrorCount',
    'builderErrorCount',
    'not a Unity Player build or runtime validation'
)) {
    Assert-Contract ($offline.Contains($literal, [System.StringComparison]::OrdinalIgnoreCase)) "offline compile contract missing: $literal"
}
Assert-Contract ($offline -notmatch '(?i)Unity\.exe|AssetRipper|Test-UnityEditorScriptCompilePreflight') 'offline compile invokes a forbidden runtime'

foreach ($metaText in @($runtimeFolderMetaText, $runtimeMeta, $builderMeta)) {
    Assert-Contract ($metaText -match '(?m)^fileFormatVersion: 2$') 'meta fileFormatVersion is invalid'
    Assert-Contract ($metaText -match '(?m)^guid: [0-9a-f]{32}$') 'meta GUID is invalid'
}
Assert-Contract ($runtimeFolderMetaText -match '(?m)^folderAsset: yes$') 'UDCP folder meta is not a folder asset'
Assert-Contract ($runtimeMeta -match '(?m)^MonoImporter:$') 'runtime meta importer is invalid'
Assert-Contract ($builderMeta -match '(?m)^MonoImporter:$') 'builder meta importer is invalid'

"UDCP-T3 static contract GREEN: members=17 effective=12 build=1 player=1"
