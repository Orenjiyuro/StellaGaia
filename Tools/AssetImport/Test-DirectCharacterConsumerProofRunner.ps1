Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$runnerPath = Join-Path $repositoryRoot 'Assets\StellaGaia\Editor\DirectCharacterConsumerProofRunner.cs'
$metaPath = $runnerPath + '.meta'

function Assert-Contract {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw "UDCP-T1 static contract failed: $Message"
    }
}

Assert-Contract (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'runner source is missing'
Assert-Contract (Test-Path -LiteralPath $metaPath -PathType Leaf) 'runner meta is missing'

$source = [System.IO.File]::ReadAllText($runnerPath)
$meta = [System.IO.File]::ReadAllText($metaPath)

$expectedMembers = @(
    [pscustomobject]@{ Path = 'Persistent_Store/AssetBundles/char_14401.unity3d'; Length = 259486L; Sha256 = 'c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b' },
    [pscustomobject]@{ Path = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; Length = 37819874L; Sha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' },
    [pscustomobject]@{ Path = 'Persistent_Store/AssetBundles/char_14401_fx.unity3d'; Length = 1944422L; Sha256 = '02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab' },
    [pscustomobject]@{ Path = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; Length = 3080984L; Sha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' },
    [pscustomobject]@{ Path = 'Persistent_Store/AssetBundles/char_14401_timeline.unity3d'; Length = 4341943L; Sha256 = '22cafed7bb84fec59a0b2f4ccf0687ff9434ad38e7a21de9041ca313565d0228' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d'; Length = 268634L; Sha256 = 'f288167adbc49837d977e81aa4c76fba136e50c2533cd86577248bbe8f0902f7' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d'; Length = 54889767L; Sha256 = '50f48caaefa85c371ff53de88f5165d974b5898de4a64ac6d4ca73a989f98a4c' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d'; Length = 3576L; Sha256 = '0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d'; Length = 35134L; Sha256 = 'e5c4ef03fa7c9b8c31de99f15e2fe296c8014c99657c5f4f62187d81e079ba47' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d'; Length = 27828L; Sha256 = '6005f95be7a3e66a87a5549fde3728f60a234ea6cc8763fdbc95c49962be22e0' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d'; Length = 3956L; Sha256 = 'de1aa4e4f2f2de24f8ab5994c8be5bfd0f2fc903888c3168159fd2531c2a5397' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d'; Length = 1998022L; Sha256 = '409358d533ffe6a00d04494232b454e07c1d7a6db070990c9b2a3641472b80ec' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; Length = 6682L; Sha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d'; Length = 3078427L; Sha256 = '8c16df97fd2facbcc6ee94b5b46d5d4ebe46ec2948b3a2453684f3ac5a249427' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; Length = 4909859L; Sha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d'; Length = 4402515L; Sha256 = '6e6b8cb2bfd82f93b2651a46fc1f367ed21076fe53f34bf00a8adf3b09cce5e1' },
    [pscustomobject]@{ Path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'; Length = 11641L; Sha256 = '0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048' }
)

$memberPattern = 'new\s+AuthorizedMember\s*\(\s*"(?<path>(?:Persistent_Store/AssetBundles|xtlr_Data/StreamingAssets/InstallResource)/char_14401[^"]*\.unity3d)"\s*,\s*(?<length>\d+)L\s*,\s*"(?<sha>[0-9a-f]{64})"\s*\)'
$memberMatches = @([System.Text.RegularExpressions.Regex]::Matches($source, $memberPattern))
$actualSelectors = [string[]]@($memberMatches | ForEach-Object { $_.Groups['path'].Value })
Assert-Contract ($memberMatches.Count -eq 17) "expected 17 frozen path/length/SHA tuples, found $($memberMatches.Count)"
Assert-Contract (@($actualSelectors | Select-Object -Unique).Count -eq 17) 'selector literals are not unique'
for ($index = 0; $index -lt $expectedMembers.Count; $index++) {
    $actual = $memberMatches[$index]
    $expected = $expectedMembers[$index]
    Assert-Contract ($actual.Groups['path'].Value -ceq $expected.Path) "member[$index] path drifted"
    Assert-Contract ([long]$actual.Groups['length'].Value -eq $expected.Length) "member[$index] length drifted"
    Assert-Contract ($actual.Groups['sha'].Value -ceq $expected.Sha256) "member[$index] SHA-256 drifted"
}

$effective = [ordered]@{}
foreach ($selector in $actualSelectors) {
    $logicalName = [System.IO.Path]::GetFileName($selector)
    $priority = if ($selector.StartsWith('Persistent_Store/AssetBundles/', [System.StringComparison]::Ordinal)) { 0 } else { 1 }
    if (-not $effective.Contains($logicalName) -or $priority -lt $effective[$logicalName].priority) {
        $effective[$logicalName] = [pscustomobject]@{ relativePath = $selector; priority = $priority }
    }
}
$expectedEffectivePaths = [string[]]@(
    'Persistent_Store/AssetBundles/char_14401.unity3d',
    'Persistent_Store/AssetBundles/char_14401_animations.unity3d',
    'Persistent_Store/AssetBundles/char_14401_fx.unity3d',
    'Persistent_Store/AssetBundles/char_14401_models.unity3d',
    'Persistent_Store/AssetBundles/char_14401_timeline.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'
)
$actualEffectivePaths = [string[]]@($effective.Values | ForEach-Object { $_.relativePath })
Assert-Contract ($actualEffectivePaths.Count -eq 12) "expected 12 effective bundles, found $($actualEffectivePaths.Count)"
Assert-Contract (@(Compare-Object -ReferenceObject $expectedEffectivePaths -DifferenceObject $actualEffectivePaths -SyncWindow 0).Count -eq 0) 'effective priority result drifted'

$requiredLiterals = [string[]]@(
    'namespace StellaGaia.Editor',
    'public static class DirectCharacterConsumerProofRunner',
    'public static void RunSmoke()',
    'STELLAGAIA_UDCP_INPUT_ROOT',
    'STELLAGAIA_UDCP_OUTPUT_ROOT',
    'Environment.GetEnvironmentVariable',
    'ExpectedInputRelativePath',
    'Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1-A02/Input',
    'Application.dataPath',
    'ComputeSha256',
    'SHA256.Create',
    'expectedLength',
    'expectedSha256',
    'actualSha256',
    'AuthorizedMembers',
    'BuildEffectiveBundles',
    'StringComparer.Ordinal',
    'TryGetValue',
    'effective.Count != EffectiveBundleCount',
    'Path.GetFileName',
    'Path.IsPathRooted',
    'IsUncOrDevicePath',
    'IsSameOrDescendant',
    'FileAttributes.ReparsePoint',
    'AssetBundle.LoadFromFile',
    'GetAllAssetNames',
    'LoadAsset',
    'InstantiateAndValidateAttackFx',
    'Object.Instantiate',
    'SkinnedMeshRenderer',
    'sharedMesh',
    'rootBone',
    'bones',
    'sharedMaterials',
    'GetTexturePropertyNames',
    'AnimationUtility.GetCurveBindings',
    'SampleAnimation',
    'CollectCharacterBones',
    'characterBones.Contains(target)',
    'bindingPath',
    'numericChangeMagnitude',
    'float.IsNaN',
    'ParticleSystem',
    'ParticleSystemRenderer',
    'particleSystem.particleCount',
    'particleSystem.GetComponent<ParticleSystemRenderer>()',
    'liveParticleCount',
    'Renderer',
    'renderer.enabled',
    'activeInHierarchy',
    'shader.isSupported',
    'qualifyingFxRendererCount',
    'IsFinite(renderer.bounds)',
    'attackTokens',
    'RenderTexture',
    'Camera',
    'EncodeToPNG',
    'smoke-screenshot.png',
    'ScreenshotWidth = 512',
    'ScreenshotHeight = 512',
    'CharacterProofLayer = 30',
    'FxProofLayer = 31',
    'MinimumForegroundPixels',
    'MinimumBrightnessRange',
    'MinimumDistinctColorBins',
    'AnalyzeVisibility',
    'baselinePixels',
    'characterForegroundPixelCount',
    'characterBrightnessRange',
    'characterDistinctColorCount',
    'fxForegroundPixelCount',
    'fxBrightnessRange',
    'fxDistinctColorCount',
    'compositeForegroundPixelCount',
    'SetLayerRecursively',
    'useAutoRandomSeed = false',
    'randomSeed',
    'Application.unityVersion',
    'authorizedMemberCount',
    'effectiveBundleCount',
    'bundleResults',
    'exceptionType',
    'exceptionMessage',
    'exceptionStack',
    'failureBundle',
    'failureAsset',
    'failureObject',
    'GetType().FullName',
    'SanitizePortableText',
    'EditorApplication.Exit(exitCode)',
    'FileMode.CreateNew',
    'terminal-result.json',
    'finally',
    'Unload(true)',
    'nextAction'
)
foreach ($literal in $requiredLiterals) {
    Assert-Contract ($source.Contains($literal, [System.StringComparison]::Ordinal)) "missing required source contract: $literal"
}

$environmentVariables = @(
    [System.Text.RegularExpressions.Regex]::Matches($source, '"(?<name>STELLAGAIA_UDCP_[A-Z_]+)"') |
        ForEach-Object { $_.Groups['name'].Value } |
        Select-Object -Unique
)
Assert-Contract ($environmentVariables.Count -eq 2) 'unexpected UDCP environment variable surface'
Assert-Contract ($environmentVariables -contains 'STELLAGAIA_UDCP_INPUT_ROOT') 'input environment variable missing'
Assert-Contract ($environmentVariables -contains 'STELLAGAIA_UDCP_OUTPUT_ROOT') 'output environment variable missing'

$bannedPatterns = [ordered]@{
    'external process API' = '(?i)\bProcess\s*\.\s*Start\b|System\.Diagnostics\.Process'
    'AssetRipper dependency' = '(?i)AssetRipper'
    'directory scanning' = '\bDirectory\.(GetFiles|EnumerateFiles|GetDirectories|EnumerateDirectories)\b'
    'parallel or retry execution' = '(?i)\b(Task|Thread|Parallel)\s*\.|retry|fallback'
    'historical source binding' = 'STELLAGAIA_DCP_SOURCE_ROOT|PB-I03|personal-local-mode-inputs|tool-manifest'
    'AnimatorController dependency' = '\bAnimatorController\b'
    'hard-coded Windows absolute path' = '[A-Za-z]:\\'
}
foreach ($entry in $bannedPatterns.GetEnumerator()) {
    Assert-Contract ($source -notmatch $entry.Value) "banned $($entry.Key) found"
}

Assert-Contract ($source -match 'exitCode\s*=\s*1') 'failure exit code is not initialized nonzero'
Assert-Contract ($source -match 'exitCode\s*=\s*0') 'success exit code is not set to zero'
Assert-Contract ($source -notmatch 'evidencePreserved\s*=\s*true') 'evidence preservation is claimed unconditionally'
Assert-Contract ($source -match 'stage\s*=\s*"PathGate"') 'PathGate stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"MemberValidation"') 'MemberValidation stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"BundleLoad"') 'BundleLoad stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"TerminalWrite"') 'TerminalWrite stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"InputIdentity"') 'InputIdentity stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"CharacterInstantiation"') 'CharacterInstantiation stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"AnimationSampling"') 'AnimationSampling stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"AttackFxInstantiation"') 'AttackFxInstantiation stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"Screenshot"') 'Screenshot stage is absent'
Assert-Contract ($source -match 'modelConsumerProofPassed\s*=\s*true') 'model consumer proof cannot pass'
Assert-Contract ($source -match 'animationConsumerProofPassed\s*=\s*true') 'animation consumer proof cannot pass'
Assert-Contract ($source -match 'battleFxConsumerProofPassed\s*=\s*true') 'attack FX consumer proof cannot pass'
Assert-Contract ($source -match 'screenshotProofPassed\s*=\s*true') 'screenshot proof cannot pass'
Assert-Contract (
    $source -match 'modelConsumerProofPassed\s*&&\s*\r?\n?\s*report\.animationConsumerProofPassed\s*&&\s*\r?\n?\s*report\.battleFxConsumerProofPassed\s*&&\s*\r?\n?\s*report\.screenshotProofPassed'
) 'overall success is not gated by all four consumer proofs'
Assert-Contract ($source -notmatch '(modelCount|animationClipCount|battleFxCount)\s*<=\s*0') 'asset counts are still accepted as consumer proof'
Assert-Contract ($source -match 'if\s*\(\s*!PathsEqual\(normalized,\s*expectedInputRoot\)\s*\)') 'input root is not strictly equal to A02/Input'
Assert-Contract ($source -match 'fileInfo\.Length\s*!=\s*expected\.expectedLength') 'member length is not checked against the frozen tuple'
Assert-Contract ($source -match 'actualSha256,\s*\r?\n?\s*expected\.expectedSha256') 'member SHA-256 is not checked against the frozen tuple'
Assert-Contract (($expectedMembers | Measure-Object -Property Length -Sum).Sum -eq 117082750L) 'frozen tuple byte conservation drifted'
Assert-Contract ($source -match 'failureStage\s*=\s*report\.stage') 'failure stage is not captured'
Assert-Contract ($source -match 'failureBundle\s*=\s*report\.contextBundle') 'failure bundle is not captured'
Assert-Contract ($source -match 'failureAsset\s*=\s*report\.contextAsset') 'failure asset is not captured'
Assert-Contract ($source -match 'failureObject\s*=\s*report\.contextObject') 'failure object is not captured'
Assert-Contract ($source -match 'exceptionType\s*=\s*exception\.GetType\(\)\.FullName') 'failure exception type is not captured'

$fxParticleGateIndex = $source.IndexOf('if (liveParticleCount <= 0)', [System.StringComparison]::Ordinal)
$fxRendererGateIndex = $source.IndexOf('if (qualifyingFxRendererCount <= 0)', [System.StringComparison]::Ordinal)
$fxPassIndex = $source.IndexOf('report.battleFxConsumerProofPassed = true;', [System.StringComparison]::Ordinal)
Assert-Contract (
    $fxParticleGateIndex -ge 0 -and
    $fxRendererGateIndex -gt $fxParticleGateIndex -and
    $fxPassIndex -gt $fxRendererGateIndex
) 'attack FX can pass before live-particle and qualifying-renderer gates'

$characterVisibilityGateIndex = $source.IndexOf('RequireVisibility("character-only"', [System.StringComparison]::Ordinal)
$fxVisibilityGateIndex = $source.IndexOf('RequireVisibility("FX-only"', [System.StringComparison]::Ordinal)
$compositeVisibilityGateIndex = $source.IndexOf('RequireVisibility("composite"', [System.StringComparison]::Ordinal)
$screenshotPassIndex = $source.IndexOf('report.screenshotProofPassed = true;', [System.StringComparison]::Ordinal)
$visibilityAssignments = [string[]]@(
    'report.characterForegroundPixelCount =',
    'report.characterBrightnessRange =',
    'report.characterDistinctColorCount =',
    'report.fxForegroundPixelCount =',
    'report.fxBrightnessRange =',
    'report.fxDistinctColorCount =',
    'report.compositeForegroundPixelCount =',
    'report.compositeBrightnessRange =',
    'report.compositeDistinctColorCount ='
)
foreach ($assignment in $visibilityAssignments) {
    $assignmentIndex = $source.IndexOf($assignment, [System.StringComparison]::Ordinal)
    Assert-Contract (
        $assignmentIndex -ge 0 -and
        $assignmentIndex -lt $characterVisibilityGateIndex
    ) "visibility metric assignment occurs after the first gate: $assignment"
}
Assert-Contract (
    $characterVisibilityGateIndex -ge 0 -and
    $fxVisibilityGateIndex -gt $characterVisibilityGateIndex -and
    $compositeVisibilityGateIndex -gt $fxVisibilityGateIndex -and
    $screenshotPassIndex -gt $compositeVisibilityGateIndex
) 'screenshot can pass before character-only, FX-only, and composite visibility gates'

$resolveOutputIndex = $source.IndexOf('outputRoot = ResolveOutputRoot();', [System.StringComparison]::Ordinal)
$separationGateIndex = $source.IndexOf('AssertSeparatedRoots(expectedInputRoot, outputRoot);', [System.StringComparison]::Ordinal)
$prepareOutputIndex = $source.IndexOf('PrepareOutputRoot(outputRoot);', [System.StringComparison]::Ordinal)
Assert-Contract (
    $resolveOutputIndex -ge 0 -and
    $separationGateIndex -gt $resolveOutputIndex -and
    $prepareOutputIndex -gt $separationGateIndex
) 'output root creation is not ordered after the input/output separation gate'

$terminalStageIndex = $source.IndexOf('BeginStage(report, report.stage);', $source.IndexOf('report.stage = "TerminalWrite"', [System.StringComparison]::Ordinal), [System.StringComparison]::Ordinal)
$terminalCompleteIndex = $source.IndexOf('CompleteStage(report);', $terminalStageIndex, [System.StringComparison]::Ordinal)
$terminalSerializeIndex = $source.IndexOf('JsonUtility.ToJson(report, true)', $terminalStageIndex, [System.StringComparison]::Ordinal)
Assert-Contract (
    $terminalStageIndex -ge 0 -and
    $terminalCompleteIndex -gt $terminalStageIndex -and
    $terminalSerializeIndex -gt $terminalCompleteIndex
) 'TerminalWrite is not marked Succeeded in the persisted terminal JSON'

Assert-Contract ($meta -match '(?m)^fileFormatVersion: 2$') 'meta fileFormatVersion is invalid'
Assert-Contract ($meta -match '(?m)^guid: [0-9a-f]{32}$') 'meta GUID is invalid'
Assert-Contract ($meta -match '(?m)^MonoImporter:$') 'meta importer is invalid'

"UDCP-T1 static contract GREEN: selectors=17 effectiveBundles=12"
