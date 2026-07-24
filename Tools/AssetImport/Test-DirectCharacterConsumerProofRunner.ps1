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

$expectedSelectors = [string[]]@(
    'Persistent_Store/AssetBundles/char_14401.unity3d',
    'Persistent_Store/AssetBundles/char_14401_animations.unity3d',
    'Persistent_Store/AssetBundles/char_14401_fx.unity3d',
    'Persistent_Store/AssetBundles/char_14401_models.unity3d',
    'Persistent_Store/AssetBundles/char_14401_timeline.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d',
    'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'
)

$selectorPattern = '"(?<path>(?:Persistent_Store/AssetBundles|xtlr_Data/StreamingAssets/InstallResource)/char_14401[^"]*\.unity3d)"'
$selectorMatches = @([System.Text.RegularExpressions.Regex]::Matches($source, $selectorPattern))
$actualSelectors = [string[]]@($selectorMatches | ForEach-Object { $_.Groups['path'].Value })
Assert-Contract ($actualSelectors.Count -eq 17) "expected 17 selector literals, found $($actualSelectors.Count)"
Assert-Contract (@($actualSelectors | Select-Object -Unique).Count -eq 17) 'selector literals are not unique'
Assert-Contract (@(Compare-Object -ReferenceObject $expectedSelectors -DifferenceObject $actualSelectors -SyncWindow 0).Count -eq 0) 'selector order or identity drifted'

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
    'asset is GameObject',
    'asset is AnimationClip',
    'BattleFx',
    'Application.unityVersion',
    'authorizedMemberCount',
    'effectiveBundleCount',
    'bundleResults',
    'modelCount',
    'animationClipCount',
    'battleFxCount',
    'exceptionType',
    'exceptionMessage',
    'exceptionStack',
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
Assert-Contract ($source -match 'stage\s*=\s*"Discovery"') 'Discovery stage is absent'
Assert-Contract ($source -match 'stage\s*=\s*"TerminalWrite"') 'TerminalWrite stage is absent'

$resolveOutputIndex = $source.IndexOf('outputRoot = ResolveOutputRoot();', [System.StringComparison]::Ordinal)
$separationGateIndex = $source.IndexOf('AssertSeparatedRoots(inputRoot, outputRoot);', [System.StringComparison]::Ordinal)
$prepareOutputIndex = $source.IndexOf('PrepareOutputRoot(outputRoot);', [System.StringComparison]::Ordinal)
Assert-Contract (
    $resolveOutputIndex -ge 0 -and
    $separationGateIndex -gt $resolveOutputIndex -and
    $prepareOutputIndex -gt $separationGateIndex
) 'output root creation is not ordered after the input/output separation gate'

Assert-Contract ($meta -match '(?m)^fileFormatVersion: 2$') 'meta fileFormatVersion is invalid'
Assert-Contract ($meta -match '(?m)^guid: [0-9a-f]{32}$') 'meta GUID is invalid'
Assert-Contract ($meta -match '(?m)^MonoImporter:$') 'meta importer is invalid'

"UDCP-T1 static contract GREEN: selectors=17 effectiveBundles=12"
