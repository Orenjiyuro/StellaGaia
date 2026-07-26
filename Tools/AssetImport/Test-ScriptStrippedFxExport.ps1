[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-Contract {
    param(
        [Parameter(Mandatory)]
        [bool] $Condition,
        [Parameter(Mandatory)]
        [string] $Message
    )

    if (-not $Condition) {
        throw "SFXR static contract failed: $Message"
    }
}

function Get-ContractInt64 {
    param(
        [Parameter(Mandatory)]
        [string] $Runner,
        [Parameter(Mandatory)]
        [string] $Name
    )

    $matches = [regex]::Matches(
        $Runner,
        "(?m)^\s*$([regex]::Escape($Name))\s*=\s*\[int64\](\d+)\s*$")
    Assert-Contract ($matches.Count -eq 1) "$Name must have exactly one literal Int64 assignment"
    return [int64]$matches[0].Groups[1].Value
}

$runnerPath = Join-Path $PSScriptRoot 'Invoke-ScriptStrippedFxExport.ps1'
Assert-Contract (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'runner is missing'

$runner = [IO.File]::ReadAllText($runnerPath)
$tokens = $null
$parseErrors = $null
[void] [Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref] $tokens,
    [ref] $parseErrors)
Assert-Contract (@($parseErrors).Count -eq 0) 'runner has PowerShell syntax errors'

$expectedMembers = @(
    [pscustomobject]@{ path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; length = '4909859'; sha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' },
    [pscustomobject]@{ path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; length = '6682'; sha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' },
    [pscustomobject]@{ path = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; length = '3080984'; sha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' },
    [pscustomobject]@{ path = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; length = '37819874'; sha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' },
    [pscustomobject]@{ path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'; length = '11641'; sha256 = '0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048' },
    [pscustomobject]@{ path = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d'; length = '3576'; sha256 = '0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f' },
    [pscustomobject]@{ path = 'Persistent_Store/AssetBundles/char_14401_fx.unity3d'; length = '1944422'; sha256 = '02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab' }
)

foreach ($member in $expectedMembers) {
    Assert-Contract ($runner.Contains("'$($member.path)'", [StringComparison]::Ordinal)) "missing exact member $($member.path)"
    Assert-Contract ($runner.Contains($member.length, [StringComparison]::Ordinal)) "missing length for $($member.path)"
    Assert-Contract ($runner.Contains("'$($member.sha256)'", [StringComparison]::Ordinal)) "missing SHA-256 for $($member.path)"
}

Assert-Contract (([regex]::Matches($runner, "relativePath = '.*?\.unity3d'")).Count -eq 7) 'authorized member count is not exactly seven'
Assert-Contract ($runner.Contains("Extracted\DirectCharacterConsumerProof\char_14401\LO-DCP1-A02\Input", [StringComparison]::Ordinal)) 'A02 input root is not fixed'
Assert-Contract ($runner.Contains("Extracted\ScriptStrippedFxReconstruction\char_14401\LO1", [StringComparison]::Ordinal)) 'LO1 output root is not fixed'

Assert-Contract ($runner.Contains("'24e973ded1f9d7c97b8334c82b82e69d6dc227798441d9ffa43bb4a80ec070f9'", [StringComparison]::Ordinal)) 'tool manifest SHA-256 is not fixed'
Assert-Contract ($runner.Contains("'AssetRipper.GUI.Free.exe'", [StringComparison]::Ordinal)) 'AssetRipper leaf is not fixed'
Assert-Contract ($runner.Contains("'AssetRipper.GUI.Free'", [StringComparison]::Ordinal)) 'AssetRipper product is not fixed'
Assert-Contract ($runner.Contains("'1.3.14.0'", [StringComparison]::Ordinal)) 'AssetRipper version is not fixed'
Assert-Contract ($runner.Contains('124776960', [StringComparison]::Ordinal)) 'AssetRipper length is not fixed'
Assert-Contract ($runner.Contains("'11ec892dcd70b1b86f2e52db631e83e007f6103daa20a9616ecaa7a95baa9f21'", [StringComparison]::Ordinal)) 'AssetRipper SHA-256 is not fixed'
Assert-Contract ($runner.Contains('assetRipperPort = 17777', [StringComparison]::Ordinal)) 'AssetRipper port is not fixed'

Assert-Contract (([regex]::Matches($runner, '(?m)^\s*\$process\s*=\s*Start-Process\b')).Count -eq 1) 'runner must contain exactly one AssetRipper process start'
Assert-Contract ($runner.Contains('processStartCount++', [StringComparison]::Ordinal)) 'process start accounting is missing'
Assert-Contract ($runner.Contains('[IO.FileMode]::CreateNew', [StringComparison]::Ordinal)) 'CreateNew terminal publishing is missing'
Assert-Contract ($runner.Contains('Stop-SfxrProcessTree', [StringComparison]::Ordinal)) 'process-tree cleanup is missing'
Assert-Contract ($runner.Contains('listenerAbsentAfterShutdown', [StringComparison]::Ordinal)) 'listener cleanup evidence is missing'
Assert-Contract ($runner.Contains('relatedProcessCountAfterShutdown', [StringComparison]::Ordinal)) 'process cleanup evidence is missing'
Assert-Contract ($runner.Contains("'Unity', 'UnityShaderCompiler', 'UnityCrashHandler64'", [StringComparison]::Ordinal)) 'Unity Editor process gate is not exact'
$startupTimeoutMilliseconds = Get-ContractInt64 -Runner $runner -Name 'startupTimeoutMilliseconds'
$loadTimeoutMilliseconds = Get-ContractInt64 -Runner $runner -Name 'loadTimeoutMilliseconds'
$exportTimeoutMilliseconds = Get-ContractInt64 -Runner $runner -Name 'exportTimeoutMilliseconds'
$overallTimeoutMilliseconds = Get-ContractInt64 -Runner $runner -Name 'overallTimeoutMilliseconds'
Assert-Contract ($startupTimeoutMilliseconds -eq 60000) 'startup timeout must equal 60000'
Assert-Contract ($loadTimeoutMilliseconds -eq 600000) 'load timeout must equal 600000'
Assert-Contract ($exportTimeoutMilliseconds -eq 1200000) 'export timeout must equal 1200000'
Assert-Contract ($overallTimeoutMilliseconds -eq 1800000) 'overall timeout must equal 1800000'
Assert-Contract ($overallTimeoutMilliseconds -le 1800000) 'overall timeout must not exceed 1800000'
Assert-Contract ($runner.Contains('Get-SfxrRemainingTimeoutSeconds', [StringComparison]::Ordinal)) 'overall timeout stage clamp is missing'
Assert-Contract ($runner.Contains('$remaining = $OverallTimeoutMilliseconds - $Stopwatch.ElapsedMilliseconds', [StringComparison]::Ordinal)) 'overall remaining-time calculation is missing'
Assert-Contract ($runner.Contains('$stopwatch.ElapsedMilliseconds -ge $contract.overallTimeoutMilliseconds', [StringComparison]::Ordinal)) 'startup is not constrained by overall timeout'
Assert-Contract (([regex]::Matches($runner, '-OverallTimeoutMilliseconds \$contract\.overallTimeoutMilliseconds')).Count -eq 2) 'Load and Export must each use the overall timeout clamp'
Assert-Contract ($runner.Contains('inputUnchanged', [StringComparison]::Ordinal)) 'input before/after identity is missing'
Assert-Contract ($runner.Contains('extensionDistribution', [StringComparison]::Ordinal)) 'extension distribution is missing'
Assert-Contract ($runner.Contains('missingDependencyWarningCount', [StringComparison]::Ordinal)) 'missing dependency diagnostics are missing'
Assert-Contract ($runner.Contains('scriptDeserializationIssueCount', [StringComparison]::Ordinal)) 'script deserialization diagnostics are missing'
Assert-Contract ($runner.Contains("nextAction = 'AwaitSFXRLO1Audit'", [StringComparison]::Ordinal)) 'terminal nextAction is not fixed'
Assert-Contract ($runner.Contains('sourcePathLeakCount', [StringComparison]::Ordinal)) 'portable result leak accounting is missing'
Assert-Contract ($runner.Contains('exportedScriptsExecuted = $false', [StringComparison]::Ordinal)) 'script non-execution evidence is missing'
Assert-Contract ($runner.Contains('exportedProjectLaunched = $false', [StringComparison]::Ordinal)) 'exported project launch prohibition is missing'
Assert-Contract ($runner.Contains('PostInputIdentityFailure', [StringComparison]::Ordinal)) 'post-input failure transition is missing'
Assert-Contract ($runner.Contains('EvidenceCollectionFailure', [StringComparison]::Ordinal)) 'evidence collection failure transition is missing'

Assert-Contract ($runner.Contains('/LoadFolder', [StringComparison]::Ordinal)) 'FFS LoadFolder invocation is missing'
Assert-Contract ($runner.Contains('/Export/UnityProject', [StringComparison]::Ordinal)) 'FFS UnityProject export invocation is missing'
Assert-Contract ($runner.Contains('--headless=true', [StringComparison]::Ordinal)) 'FFS headless invocation form is missing'
Assert-Contract (-not $runner.Contains('AssetStudio', [StringComparison]::OrdinalIgnoreCase)) 'AssetStudio fallback is forbidden'
Assert-Contract (-not $runner.Contains('UnityPy', [StringComparison]::OrdinalIgnoreCase)) 'UnityPy fallback is forbidden'
Assert-Contract (-not $runner.Contains('Il2Cpp', [StringComparison]::OrdinalIgnoreCase)) 'IL2CPP tooling is forbidden'
Assert-Contract (-not $runner.Contains('PB-I03', [StringComparison]::OrdinalIgnoreCase)) 'real-source locator access is forbidden'
Assert-Contract (-not $runner.Contains('sourceBoundary', [StringComparison]::OrdinalIgnoreCase)) 'real-source boundary access is forbidden'
Assert-Contract (-not $runner.Contains('Unity.exe', [StringComparison]::OrdinalIgnoreCase)) 'Unity launch is forbidden'
Assert-Contract (-not $runner.Contains('Invoke-AssetRipperFolderExport.ps1', [StringComparison]::OrdinalIgnoreCase)) 'historical generic runner must not be invoked'
Assert-Contract (-not $runner.Contains('Invoke-DcpLo1.ps1', [StringComparison]::OrdinalIgnoreCase)) 'DCP runner must not be invoked'
Assert-Contract (-not $runner.Contains('retry', [StringComparison]::OrdinalIgnoreCase)) 'automatic retry is forbidden'
Assert-Contract (-not $runner.Contains('fallback', [StringComparison]::OrdinalIgnoreCase)) 'fallback is forbidden'

Write-Output 'SFXR static contract GREEN: members=7 processStartMax=1 fallback=0 Unity=0'
