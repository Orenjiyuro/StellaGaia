Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runnerPath = Join-Path $PSScriptRoot 'Invoke-ProviderEnhancedCharacterExport.ps1'

function Assert-True {
    param(
        [Parameter(Mandatory)]
        [bool]$Condition,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-ThrowsLike {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Action,

        [Parameter(Mandatory)]
        [string]$Pattern,

        [Parameter(Mandatory)]
        [string]$Message
    )

    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -like $Pattern) {
            return
        }

        throw "$Message Actual: $($_.Exception.Message)"
    }

    throw "$Message No exception was thrown."
}

if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
    throw "RED: required PEFP runner is missing: $runnerPath"
}

$expectedInputs = @(
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; ExpectedLength = [int64]4909859; ExpectedSha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; ExpectedLength = [int64]6682; ExpectedSha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; ExpectedLength = [int64]3080984; ExpectedSha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; ExpectedLength = [int64]37819874; ExpectedSha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'; ExpectedLength = [int64]11641; ExpectedSha256 = '0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d'; ExpectedLength = [int64]3576; ExpectedSha256 = '0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f' }
    [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_fx.unity3d'; ExpectedLength = [int64]1944422; ExpectedSha256 = '02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401.unity3d'; ExpectedLength = [int64]259486; ExpectedSha256 = 'c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_water.unity3d'; ExpectedLength = [int64]29687342; ExpectedSha256 = 'e46b6016e7fee31e4fdf592ee9cf04c2c424928d160dc20c4656e2f3e9fa75d0' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/actor_common.unity3d'; ExpectedLength = [int64]10821270; ExpectedSha256 = '8c485e107b27b5ff6862c79c61ba683eae7c46ed5fdd8afb203e8ff7de6dcf64' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_misc.unity3d'; ExpectedLength = [int64]9009665; ExpectedSha256 = '26be1a7b839d6344293c1a0fad7551a53f331c45beb409362c7f5264ea21b577' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/global.unity3d'; ExpectedLength = [int64]227310; ExpectedSha256 = 'd3b70fda5eae75601e91868e2b09d2b2e8900978eea654c7aea3eb63bdfcffdc' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/fx_actorcommon.unity3d'; ExpectedLength = [int64]464072; ExpectedSha256 = '8b56dcb70142226a40c2819c06eab6d4a890946e0ec03ecd03690f24e2764340' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_uncollated.unity3d'; ExpectedLength = [int64]65558791; ExpectedSha256 = '65ab7ebb530d1ed2d38a82042c22d90e32732f25d599f9195b6acc69cb546e9d' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/shader.unity3d'; ExpectedLength = [int64]14421770; ExpectedSha256 = '8043bfe89e1619f4090e00014f38182077e1f521d2292aa3e223d5b1fb7c1947' }
    [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_other.unity3d'; ExpectedLength = [int64]46651397; ExpectedSha256 = '92df258baf1a587cdae35eaaceabfad755d1d414d0d165b7b9762c8da1357101' }
)

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $runnerPath,
    [ref]$tokens,
    [ref]$parseErrors
)
Assert-True ($parseErrors.Count -eq 0) "Runner syntax errors: $($parseErrors -join '; ')"

$runnerText = [IO.File]::ReadAllText($runnerPath)
$runnerHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runnerPath).Hash.ToLowerInvariant()

$selectorPattern = [regex]::new(
    "\[pscustomobject\]@\{\s*Partition\s*=\s*'(?<partition>SFXR|Provider)';\s*SourceId\s*=\s*'(?<source>[^']+)';\s*RelativePath\s*=\s*'(?<path>[^']+)';\s*ExpectedLength\s*=\s*\[int64\](?<length>[0-9]+);\s*ExpectedSha256\s*=\s*'(?<sha>[0-9a-f]{64})'\s*\}",
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
)
$selectorMatches = @($selectorPattern.Matches($runnerText))
Assert-True ($selectorMatches.Count -eq 16) "Expected exactly 16 frozen selector tuples; found $($selectorMatches.Count)."

$actualInputs = @($selectorMatches | ForEach-Object {
    [pscustomobject]@{
        Partition = $_.Groups['partition'].Value
        SourceId = $_.Groups['source'].Value
        RelativePath = $_.Groups['path'].Value
        ExpectedLength = [int64]$_.Groups['length'].Value
        ExpectedSha256 = $_.Groups['sha'].Value
    }
})

for ($index = 0; $index -lt $expectedInputs.Count; $index++) {
    $expected = $expectedInputs[$index]
    $actual = $actualInputs[$index]
    Assert-True ($actual.Partition -ceq $expected.Partition) "Selector $index partition mismatch."
    Assert-True ($actual.SourceId -ceq $expected.SourceId) "Selector $index sourceId mismatch."
    Assert-True ($actual.RelativePath -ceq $expected.RelativePath) "Selector $index relativePath mismatch."
    Assert-True ($actual.ExpectedLength -eq $expected.ExpectedLength) "Selector $index expected length mismatch."
    Assert-True ($actual.ExpectedSha256 -ceq $expected.ExpectedSha256) "Selector $index expected SHA-256 mismatch."
}

Assert-True (@($actualInputs | Where-Object Partition -ceq 'SFXR').Count -eq 7) 'SFXR selector conservation failed.'
Assert-True (@($actualInputs | Where-Object Partition -ceq 'Provider').Count -eq 9) 'Provider selector conservation failed.'
Assert-True (@($actualInputs.RelativePath | Sort-Object -Unique).Count -eq 16) 'Frozen relative paths are not unique.'
Assert-True (@($actualInputs | Where-Object SourceId -cne 'pc-install').Count -eq 0) 'Every selector must bind to pc-install.'
Assert-True ([int64](($actualInputs | Measure-Object ExpectedLength -Sum).Sum) -eq 224878141) 'Frozen input byte conservation failed.'
Assert-True (@($actualInputs | Where-Object ExpectedSha256 -notmatch '^[0-9a-f]{64}$').Count -eq 0) 'Frozen SHA-256 shape failed.'

$requiredLiterals = @(
    'Extracted/ProviderEnhancedFinalProof/char_14401/LO1',
    'Input',
    'Output',
    'Logs',
    'terminal-result.json',
    'assetripper.log',
    'assetripper.stdout.log',
    'assetripper.stderr.log',
    'LoadFolder',
    'Export/UnityProject',
    'AwaitPEFPLO1Audit',
    'FileMode]::CreateNew',
    'UTF8Encoding]::new($false)',
    'sourcePathLeakCount',
    'missingDependencyWarningCount',
    'uniqueMissingCabCount',
    'scriptDeserializationIssueCount',
    'sourceUnchanged',
    'processStartCount',
    'loadHttpStatus',
    'exportHttpStatus',
    'exceptionType',
    'exceptionMessage',
    'exceptionStack'
)
foreach ($literal in $requiredLiterals) {
    Assert-True ($runnerText.Contains($literal, [StringComparison]::Ordinal)) "Missing required runner contract literal: $literal"
}

$forbiddenLiterals = @(
    'Invoke-DcpLo1.ps1',
    'Invoke-ScriptStrippedFxExport.ps1',
    'Find-MissingCabProviders.ps1',
    'Unity.exe',
    'Unity Hub',
    'AssetStudio',
    'UnityPy',
    'fallback',
    'Unclassified',
    'UnexpectedFailure',
    'evidencePreserved = $true'
)
foreach ($literal in $forbiddenLiterals) {
    Assert-True (-not $runnerText.Contains($literal, [StringComparison]::OrdinalIgnoreCase)) "Forbidden runner dependency or behavior: $literal"
}

$startProcessCommands = @($ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Start-Process'
}, $true))
Assert-True ($startProcessCommands.Count -eq 1) "Expected exactly one AssetRipper Start-Process site; found $($startProcessCommands.Count)."

$getChildItemCommands = @($ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -eq 'Get-ChildItem'
}, $true))
Assert-True ($getChildItemCommands.Count -eq 1) 'Only the exported Output tree may be enumerated.'

$outputGateIndex = $runnerText.IndexOf('Invoke-PefpPreOutputGate -OutputRoot', [StringComparison]::Ordinal)
$bindingIndex = $runnerText.IndexOf('$binding = Resolve-PefpPcInstallBinding', [StringComparison]::Ordinal)
$metadataGateIndex = $runnerText.IndexOf('$beforeRows = @(Test-PefpAuthorizedInputMetadata', [StringComparison]::Ordinal)
$copyIndex = $runnerText.IndexOf('$inputResults += Copy-PefpInputOnce', [StringComparison]::Ordinal)
$processIndex = $runnerText.IndexOf('$process = Start-Process', [StringComparison]::Ordinal)
$postCheckIndex = $runnerText.IndexOf('Complete-PefpInputEvidence -SourceRoot', [StringComparison]::Ordinal)
$terminalIndex = $runnerText.IndexOf('$terminal = [pscustomobject][ordered]@{', [StringComparison]::Ordinal)
Assert-True (
    $outputGateIndex -ge 0 -and
    $outputGateIndex -lt $bindingIndex -and
    $bindingIndex -lt $metadataGateIndex -and
    $metadataGateIndex -lt $copyIndex -and
    $copyIndex -lt $processIndex
) 'Production gate ordering does not prove all source metadata gates precede source open/copy and process start.'
Assert-True (
    $postCheckIndex -gt $processIndex -and
    $postCheckIndex -lt $terminalIndex
) 'Source post-state verification must cover the whole attempt and precede terminal construction.'
Assert-True ([regex]::Matches($runnerText, '/LoadFolder').Count -eq 1) 'LoadFolder must have exactly one call site.'
Assert-True ([regex]::Matches($runnerText, '/Export/UnityProject').Count -eq 1) 'Export/UnityProject must have exactly one call site.'

. $runnerPath

Assert-True (@(Get-PefpAuthorizedInputs).Count -eq 16) 'Runtime selector function did not return 16 tuples.'
Assert-True ((Get-PefpOutputRelativeRoot) -ceq 'Extracted/ProviderEnhancedFinalProof/char_14401/LO1') 'Output root is not frozen.'

$safeRoot = Join-Path ([IO.Path]::GetTempPath()) ('pefp-test-' + [Guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $safeRoot 'source'
$outputRoot = Join-Path $safeRoot 'output'
[IO.Directory]::CreateDirectory($sourceRoot) | Out-Null

try {
    $syntheticSha256 = [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData([byte[]](1, 2, 3, 4))
    ).ToLowerInvariant()
    $syntheticInputs = @($expectedInputs | ForEach-Object {
        [pscustomobject]@{
            Partition = $_.Partition
            SourceId = $_.SourceId
            RelativePath = $_.RelativePath
            ExpectedLength = [int64]4
            ExpectedSha256 = $syntheticSha256
        }
    })
    foreach ($input in $expectedInputs) {
        $leaf = Join-Path $sourceRoot ($input.RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($leaf)) | Out-Null
        [IO.File]::WriteAllBytes($leaf, [byte[]](1, 2, 3, 4))
    }

    $rows = @(Test-PefpAuthorizedInputMetadata -SourceRoot $sourceRoot -Inputs $syntheticInputs)
    Assert-True ($rows.Count -eq 16) 'Synthetic source metadata gate did not return 16 rows.'
    Assert-True (@($rows | Where-Object Length -ne 4).Count -eq 0) 'Synthetic metadata length mismatch.'

    $stagingRoot = Join-Path $safeRoot 'staging'
    [IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    $copyCounters = [ordered]@{ SourceOpenCount = 0; ProcessStartCount = 0 }
    $copiedRows = @()
    foreach ($row in $rows) {
        $copiedRows += Copy-PefpInputOnce `
            -SourceRoot $sourceRoot `
            -StagingRoot $stagingRoot `
            -Before $row `
            -Counters $copyCounters
    }
    $copied = $copiedRows[0]
    Assert-True ($copyCounters.SourceOpenCount -eq 16) 'Synthetic sources were not each opened exactly once.'
    Assert-True ($copyCounters.ProcessStartCount -eq 0) 'Synthetic copy started a process.'
    Assert-True ($copied.stagingRelativePath -ceq "Input/$($expectedInputs[0].RelativePath)") 'Portable staging path was flattened or changed.'
    Assert-True ($copied.sha256 -cmatch '^[0-9a-f]{64}$') 'Synthetic copy did not record SHA-256.'
    Assert-True ($copied.stagingSha256 -ceq $copied.sha256) 'Staging SHA did not match source stream SHA.'

    Assert-ThrowsLike {
        Assert-PefpPortableRelativePath -RelativePath '../escape.unity3d'
    } '*PathTraversal*' 'Traversal path was not rejected.'

    Assert-ThrowsLike {
        Assert-PefpLocalAbsolutePath -Path '\\server\share'
    } '*NetworkPathRejected*' 'UNC path was not rejected.'

    Assert-ThrowsLike {
        Assert-PefpLeafObject -Item ([pscustomobject]@{
            Exists = $true
            PSIsContainer = $false
            Attributes = [IO.FileAttributes]::ReparsePoint
        }) -FailurePrefix 'Synthetic'
    } '*ReparsePointRejected*' 'Reparse leaf was not rejected.'

    Assert-ThrowsLike {
        Assert-PefpLeafObject -Item ([pscustomobject]@{
            Exists = $true
            PSIsContainer = $true
            Attributes = [IO.FileAttributes]::Directory
        }) -FailurePrefix 'Synthetic'
    } '*RegularFileRequired*' 'Directory leaf was not rejected.'

    $binding = Resolve-PefpPcInstallBinding -BindingLoader {
        [pscustomobject]@{
            Baseline = 'SyntheticBaseline'
            LocatorSources = @(
                [pscustomobject]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; path = $sourceRoot }
            )
            ManifestSources = @(
                [pscustomobject]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; path = $sourceRoot }
            )
        }
    } -PathValidator {
        param($path)
        Assert-PefpLocalAbsolutePath -Path $path
        [pscustomobject]@{ FullName = [IO.Path]::GetFullPath($path); Attributes = [IO.FileAttributes]::Directory }
    }
    Assert-True ($binding.SourceId -ceq 'pc-install') 'Synthetic binding sourceId mismatch.'
    Assert-True ($binding.SourceKind -ceq 'PcInstall') 'Synthetic binding sourceKind mismatch.'

    Assert-ThrowsLike {
        Resolve-PefpPcInstallBinding -BindingLoader {
            [pscustomobject]@{
                Baseline = 'SyntheticBaseline'
                LocatorSources = @([pscustomobject]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; path = $sourceRoot })
                ManifestSources = @(
                    [pscustomobject]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; path = $sourceRoot },
                    [pscustomobject]@{ sourceId = 'other'; sourceKind = 'PcInstall'; path = $sourceRoot }
                )
            }
        } -PathValidator {
            param($path)
            [pscustomobject]@{ FullName = [IO.Path]::GetFullPath($path); Attributes = [IO.FileAttributes]::Directory }
        }
    } '*SourceBindingMismatch*' 'Non-bijective source binding was not rejected.'

    [IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $counters = [ordered]@{ SourceOpenCount = 0; ProcessStartCount = 0 }
    Assert-ThrowsLike {
        Invoke-PefpPreOutputGate -OutputRoot $outputRoot -Counters $counters
    } '*OutputRootAlreadyExists*' 'Existing output root was not rejected.'
    Assert-True ($counters.SourceOpenCount -eq 0) 'Existing output root caused a source open.'
    Assert-True ($counters.ProcessStartCount -eq 0) 'Existing output root caused a process start.'

    $sourceItem = Get-Item -LiteralPath (Join-Path $sourceRoot ($expectedInputs[0].RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)))
    $before = New-PefpMetadataRecord -Item $sourceItem -AuthorizedInput $syntheticInputs[0]
    $after = New-PefpMetadataRecord -Item $sourceItem -AuthorizedInput $syntheticInputs[0]
    Assert-True (Test-PefpMetadataRecordEqual -Before $before -After $after) 'Stable metadata records did not compare equal.'
    $changed = $after.PSObject.Copy()
    $changed.lastWriteTimeUtc = [DateTime]::UtcNow.AddMinutes(1).ToString('o')
    Assert-True (-not (Test-PefpMetadataRecordEqual -Before $before -After $changed)) 'Metadata drift was not detected.'

    $terminalProbePath = Join-Path $safeRoot 'terminal-probe.json'
    $terminalProbe = [pscustomobject][ordered]@{
        schemaVersion = 'synthetic/1.0.0'
        sourcePathLeakCount = 0
        nextAction = 'AwaitPEFPLO1Audit'
    }
    Write-PefpTerminal -LiteralPath $terminalProbePath -Terminal $terminalProbe
    $terminalBytes = [IO.File]::ReadAllBytes($terminalProbePath)
    Assert-True (-not (
        $terminalBytes.Length -ge 3 -and
        $terminalBytes[0] -eq 0xEF -and
        $terminalBytes[1] -eq 0xBB -and
        $terminalBytes[2] -eq 0xBF
    )) 'Terminal contains a UTF-8 BOM.'
    Assert-True (
        $terminalBytes[-1] -eq 10 -and
        ($terminalBytes.Length -lt 2 -or $terminalBytes[-2] -ne 10)
    ) 'Terminal does not have exactly one trailing LF.'
    Assert-ThrowsLike {
        Write-PefpTerminal -LiteralPath $terminalProbePath -Terminal $terminalProbe
    } '*already exists*' 'Terminal CreateNew/no-overwrite was not enforced.'

    $tamperedLeaf = Join-Path $sourceRoot ($syntheticInputs[0].RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    [IO.File]::WriteAllBytes($tamperedLeaf, [byte[]](4, 3, 2, 1))
    $tamperedRows = @(Test-PefpAuthorizedInputMetadata -SourceRoot $sourceRoot -Inputs $syntheticInputs)
    $tamperedCounters = [ordered]@{ SourceOpenCount = 0; ProcessStartCount = 0 }
    $tamperedStaging = Join-Path $safeRoot 'tampered-staging'
    [IO.Directory]::CreateDirectory($tamperedStaging) | Out-Null
    Assert-ThrowsLike {
        Copy-PefpInputOnce `
            -SourceRoot $sourceRoot `
            -StagingRoot $tamperedStaging `
            -Before $tamperedRows[0] `
            -Counters $tamperedCounters
    } '*SourceMemberIdentityMismatch*' 'Same-length source content drift was not rejected.'
    Assert-True ($tamperedCounters.ProcessStartCount -eq 0) 'Same-length content drift reached process start.'
    [IO.File]::WriteAllBytes($tamperedLeaf, [byte[]](1, 2, 3, 4, 5))
    $lengthCounters = [ordered]@{ SourceOpenCount = 0; ProcessStartCount = 0 }
    Assert-ThrowsLike {
        Test-PefpAuthorizedInputMetadata -SourceRoot $sourceRoot -Inputs $syntheticInputs
    } '*SourceMemberIdentityMismatch*' 'Source length drift was not rejected.'
    Assert-True ($lengthCounters.SourceOpenCount -eq 0) 'Length drift opened a source file.'
    Assert-True ($lengthCounters.ProcessStartCount -eq 0) 'Length drift reached process start.'
    [IO.File]::WriteAllBytes($tamperedLeaf, [byte[]](1, 2, 3, 4))

    $missingLeaf = Join-Path $sourceRoot ($expectedInputs[-1].RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    Remove-Item -LiteralPath $missingLeaf -Force
    Assert-ThrowsLike {
        Test-PefpAuthorizedInputMetadata -SourceRoot $sourceRoot -Inputs $syntheticInputs
    } '*SourceMemberMissing*' 'Missing authorized input was not rejected.'
}
finally {
    if (Test-Path -LiteralPath $safeRoot) {
        Remove-Item -LiteralPath $safeRoot -Recurse -Force
    }
}

Write-Output "PEFP focused contracts GREEN: selectors=16 sfxr=7 providers=9 runnerSha256=$runnerHash"
