$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-McbrTest {
    param(
        [Parameter(Mandatory)][bool] $Condition,
        [Parameter(Mandatory)][string] $Message
    )
    if (-not $Condition) {
        throw "MCBR-T1 test failed: $Message"
    }
}

function Assert-McbrThrows {
    param(
        [Parameter(Mandatory)][scriptblock] $Action,
        [Parameter(Mandatory)][string] $Message
    )
    $threw = $false
    try {
        & $Action
    }
    catch {
        $threw = $true
    }
    Assert-McbrTest $threw $Message
}

function Assert-McbrThrowsCode {
    param(
        [Parameter(Mandatory)][scriptblock] $Action,
        [Parameter(Mandatory)][string] $ExpectedCode,
        [Parameter(Mandatory)][string] $Message
    )
    $actual = $null
    try {
        & $Action
    }
    catch {
        if ($_.Exception.Message -match '^MCBR:(.+)$') {
            $actual = $Matches[1]
        }
    }
    Assert-McbrTest ($actual -ceq $ExpectedCode) "$Message (expected $ExpectedCode, actual $actual)"
}

function Add-McbrTestAsciiZ {
    param([Collections.Generic.List[byte]] $Buffer, [string] $Value)
    $Buffer.AddRange([Text.Encoding]::ASCII.GetBytes($Value))
    $Buffer.Add(0)
}

function Add-McbrTestBe16 {
    param([Collections.Generic.List[byte]] $Buffer, [uint16] $Value)
    $Buffer.Add([byte](($Value -shr 8) -band 0xff))
    $Buffer.Add([byte]($Value -band 0xff))
}

function Add-McbrTestBe32 {
    param([Collections.Generic.List[byte]] $Buffer, [uint32] $Value)
    foreach ($shift in @(24, 16, 8, 0)) {
        $Buffer.Add([byte](($Value -shr $shift) -band 0xff))
    }
}

function Add-McbrTestBe64 {
    param([Collections.Generic.List[byte]] $Buffer, [uint64] $Value)
    foreach ($shift in @(56, 48, 40, 32, 24, 16, 8, 0)) {
        $Buffer.Add([byte](($Value -shr $shift) -band 0xff))
    }
}

function Compress-McbrTestLz4Literal {
    param([byte[]] $Bytes)
    $result = [Collections.Generic.List[byte]]::new()
    if ($Bytes.Length -lt 15) {
        $result.Add([byte]($Bytes.Length -shl 4))
    }
    else {
        $result.Add(0xf0)
        $remaining = $Bytes.Length - 15
        while ($remaining -ge 255) {
            $result.Add(255)
            $remaining -= 255
        }
        $result.Add([byte]$remaining)
    }
    $result.AddRange($Bytes)
    return $result.ToArray()
}

function New-McbrTestUnityFs {
    param(
        [Parameter(Mandatory)][string[]] $DirectoryNodes,
        [Parameter(Mandatory)][byte[]] $Payload,
        [Parameter(Mandatory)][ValidateSet('Stored', 'Lz4')][string] $BlockInfoCompression
    )
    if ($Payload.Length -eq 0) {
        $Payload = [byte[]]@(0)
    }
    $blockInfo = [Collections.Generic.List[byte]]::new()
    $blockInfo.AddRange([byte[]]::new(16))
    Add-McbrTestBe32 $blockInfo 1
    Add-McbrTestBe32 $blockInfo ([uint32]$Payload.Length)
    Add-McbrTestBe32 $blockInfo ([uint32]$Payload.Length)
    Add-McbrTestBe16 $blockInfo 0
    Add-McbrTestBe32 $blockInfo ([uint32]$DirectoryNodes.Count)
    foreach ($node in $DirectoryNodes) {
        Add-McbrTestBe64 $blockInfo 0
        Add-McbrTestBe64 $blockInfo 1
        Add-McbrTestBe32 $blockInfo 0
        Add-McbrTestAsciiZ $blockInfo $node
    }
    $uncompressed = $blockInfo.ToArray()
    [byte[]]$compressed = if ($BlockInfoCompression -ceq 'Lz4') {
        Compress-McbrTestLz4Literal $uncompressed
    }
    else {
        $uncompressed
    }
    $compressionFlag = if ($BlockInfoCompression -ceq 'Lz4') { 2 } else { 0 }
    $header = [Collections.Generic.List[byte]]::new()
    Add-McbrTestAsciiZ $header 'UnityFS'
    Add-McbrTestBe32 $header 7
    Add-McbrTestAsciiZ $header '2022.3.62f2'
    Add-McbrTestAsciiZ $header '2022.3.62f2'
    $sizePosition = $header.Count
    Add-McbrTestBe64 $header 0
    Add-McbrTestBe32 $header ([uint32]$compressed.Length)
    Add-McbrTestBe32 $header ([uint32]$uncompressed.Length)
    Add-McbrTestBe32 $header ([uint32](0x40 -bor $compressionFlag))
    [uint64]$bundleSize = $header.Count + $compressed.Length + $Payload.Length
    for ($index = 0; $index -lt 8; $index++) {
        $header[$sizePosition + $index] = [byte](($bundleSize -shr (56 - (8 * $index))) -band 0xff)
    }
    $result = [Collections.Generic.List[byte]]::new()
    $result.AddRange($header.ToArray())
    $result.AddRange($compressed)
    $result.AddRange($Payload)
    return $result.ToArray()
}

$runnerPath = Join-Path $PSScriptRoot 'Find-MissingCabProviders.ps1'
Assert-McbrTest (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'runner is missing'

$runnerText = [IO.File]::ReadAllText($runnerPath)
$forbiddenPatterns = @(
    'Start-Process',
    'AssetRipper.GUI.Free.exe',
    'Unity.exe',
    'UnityHub',
    'Invoke-WebRequest',
    'Invoke-RestMethod',
    'System.Net.Http',
    'Il2Cpp',
    'fallback'
)
foreach ($pattern in $forbiddenPatterns) {
    Assert-McbrTest (-not $runnerText.Contains($pattern, [StringComparison]::OrdinalIgnoreCase)) "forbidden token '$pattern' is present"
}
Assert-McbrTest (-not [regex]::IsMatch($runnerText, '[A-Za-z]:\\(?![^''"]*LocalApplicationData)')) 'machine absolute path is hard-coded'
Assert-McbrTest ($runnerText.Contains('[IO.FileMode]::CreateNew', [StringComparison]::Ordinal)) 'CreateNew output contract is absent'
Assert-McbrTest ($runnerText.Contains('Get-McbrValidatedSourceBoundaries', [StringComparison]::Ordinal)) 'source-boundary validator is absent'
Assert-McbrTest ($runnerText.Contains('[IO.Compression.ZipArchive]', [StringComparison]::Ordinal)) 'APK ZIP entry streaming is absent'
Assert-McbrTest ($runnerText.Contains('Get-McbrUnityFsDirectoryNodes', [StringComparison]::Ordinal)) 'UnityFS directory-node parser is absent'
Assert-McbrTest (-not $runnerText.Contains('ReadAllBytes', [StringComparison]::Ordinal)) 'APK must not be retained as a byte array'
Assert-McbrTest ($runnerText.Contains('[IO.FileAttributes]::ReparsePoint', [StringComparison]::Ordinal)) 'reparse rejection is absent'
Assert-McbrTest ($runnerText.Contains('sourcePathLeakCount', [StringComparison]::Ordinal)) 'portable output leak accounting is absent'

$oldTestMode = $env:STELLAGAIA_MCBR_TEST_MODE
$env:STELLAGAIA_MCBR_TEST_MODE = '1'
try {
    . $runnerPath
}
finally {
    $env:STELLAGAIA_MCBR_TEST_MODE = $oldTestMode
}

$contract = Get-McbrContract
Assert-McbrTest ($contract.schemaVersion -ceq '1.0.0') 'schema version drifted'
Assert-McbrTest ($contract.logPortablePath -ceq 'Extracted/ScriptStrippedFxReconstruction/char_14401/LO1/Logs/assetripper.log') 'frozen log path drifted'
Assert-McbrTest ($contract.logSha256 -ceq '82ffafec53e6cf7c2270453b3054c43fd23022f03de9c307daf312701ee1bd61') 'frozen log SHA drifted'
Assert-McbrTest ($contract.planPortablePath -ceq 'Extracted/ScriptStrippedFxReconstruction/char_14401/T2/reconstruction-plan.json') 'frozen plan path drifted'
Assert-McbrTest ($contract.planSha256 -ceq '48124da20a27f353e5d1e836e931f74ad0180e47bfb3153c56b8ad574c3bc11f') 'frozen plan SHA drifted'
Assert-McbrTest ($contract.outputPortablePath -ceq 'Extracted/MissingCabClosureRecovery/char_14401/LO1/cab-provider-scan.json') 'output path drifted'
Assert-McbrTest ($contract.targetCabCount -eq 25) 'target CAB count drifted'
Assert-McbrTest ($contract.overallTimeoutMilliseconds -eq 1800000) '30-minute timeout is not exact'
Assert-McbrTest ($contract.overallTimeoutMilliseconds -le 1800000) 'timeout exceeds 30 minutes'
Assert-McbrTest ($contract.maxCandidateFileCount -eq 100000) 'candidate file cap drifted'
Assert-McbrTest ($contract.maxCandidateEntryCount -eq 100000) 'candidate entry cap drifted'
Assert-McbrTest ($contract.maxSingleEntryUncompressedBytes -eq 536870912) 'single entry byte cap drifted'
Assert-McbrTest ($contract.maxTotalEntryUncompressedBytes -eq 8589934592) 'total entry byte cap drifted'
Assert-McbrTest (($contract.scanSourceKinds -join ',') -ceq 'PcInstall,AndroidApk,AndroidDataOrCache') 'scan source kinds drifted'
Assert-McbrTest ($contract.maxFileOpenCountPerCandidate -eq 1) 'single-open contract drifted'

$evidence = Read-McbrFrozenEvidence -Contract $contract
Assert-McbrTest ($evidence.targetCabIds.Count -eq 25) 'frozen log did not yield exactly 25 unique CAB IDs'
Assert-McbrTest ((@($evidence.targetCabIds | Sort-Object -Unique).Count) -eq 25) 'CAB IDs are not unique'
Assert-McbrTest ($evidence.unresolvedRequiredGuidCount -eq 940) 'unresolved reference count drifted'
Assert-McbrTest ($evidence.unresolvedClassificationTotal -eq 940) 'unresolved classification does not conserve 940'
Assert-McbrTest ($evidence.placeholderGuid -ceq '0000000deadbeef15deadf00d0000000') 'placeholder GUID drifted'
$expectedClassification = [ordered]@{
    Shader = 304
    Texture = 485
    Mesh = 129
    AnimationClip = 20
    Material = 1
    Controller = 1
}
foreach ($name in $expectedClassification.Keys) {
    Assert-McbrTest ($evidence.unresolvedClassification[$name] -eq $expectedClassification[$name]) "unresolved $name count drifted"
}

$cabA = 'CAB-0123456789abcdef0123456789abcdef'
$cabB = 'CAB-fedcba9876543210fedcba9876543210'
$cabC = 'CAB-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$cabD = 'CAB-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
$storedFixture = New-McbrTestUnityFs `
    -DirectoryNodes @("archive:/$cabA/$cabA") `
    -Payload ([Text.Encoding]::ASCII.GetBytes("archive:/$cabB/$cabC")) `
    -BlockInfoCompression Stored
$stream = [IO.MemoryStream]::new($storedFixture, $false)
try {
    $storedScan = Find-McbrCabTokensInStream -Stream $stream -KnownLength $storedFixture.Length -ChunkSize 7 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $stream.Dispose()
}
Assert-McbrTest $storedScan.unityFsDirectoryParsed 'stored UnityFS directory was not parsed'
Assert-McbrTest ($storedScan.unityFsDirectoryNodeCount -eq 1) 'stored UnityFS node count drifted'
$storedA = @($storedScan.matches | Where-Object cabId -CEQ $cabA.ToLowerInvariant())
$storedB = @($storedScan.matches | Where-Object cabId -CEQ $cabB.ToLowerInvariant())
$storedC = @($storedScan.matches | Where-Object cabId -CEQ $cabC.ToLowerInvariant())
Assert-McbrTest ($storedA.Count -eq 2 -and @($storedA | Where-Object disposition -CNE 'ProviderCandidate').Count -eq 0) 'directory-node provider evidence was not preserved'
Assert-McbrTest ($storedB.Count -eq 1 -and $storedB[0].disposition -ceq 'DependencyOnlyReference') 'first archive-path CAB was not dependency-only'
Assert-McbrTest ($storedC.Count -eq 1 -and $storedC[0].disposition -ceq 'DependencyOnlyReference') 'second archive-path CAB became a provider candidate'

$lz4Fixture = New-McbrTestUnityFs `
    -DirectoryNodes @("CAB-$('b' * 32)") `
    -Payload ([byte[]]@(1, 2, 3, 4)) `
    -BlockInfoCompression Lz4
$stream = [IO.MemoryStream]::new($lz4Fixture, $false)
try {
    $lz4Scan = Find-McbrCabTokensInStream -Stream $stream -KnownLength $lz4Fixture.Length -ChunkSize 11 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $stream.Dispose()
}
Assert-McbrTest $lz4Scan.unityFsDirectoryParsed 'LZ4 UnityFS directory was not parsed'
Assert-McbrTest (@($lz4Scan.matches | Where-Object { $_.cabId -ceq $cabD.ToLowerInvariant() -and $_.disposition -ceq 'ProviderCandidate' }).Count -eq 1) 'LZ4 provider node was not identified'

$multiFixture = New-McbrTestUnityFs `
    -DirectoryNodes @($cabA, $cabD) `
    -Payload ([byte[]]@(5, 6, 7, 8)) `
    -BlockInfoCompression Stored
$stream = [IO.MemoryStream]::new($multiFixture, $false)
try {
    $multiScan = Find-McbrCabTokensInStream -Stream $stream -KnownLength $multiFixture.Length -ChunkSize 13 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $stream.Dispose()
}
Assert-McbrTest (@($multiScan.matches | Where-Object disposition -CEQ 'ProviderCandidate').Count -eq 2) 'multiple provider nodes were collapsed'

$payload = [Text.Encoding]::ASCII.GetBytes("UnityFS`0prefix-$cabA-middle-archive:/$cabB/$cabC-tail")
$stream = [IO.MemoryStream]::new($payload, $false)
try {
    $scan = Find-McbrCabTokensInStream -Stream $stream -KnownLength $payload.Length -ChunkSize 7 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $stream.Dispose()
}
Assert-McbrTest ($scan.byteCount -eq $payload.Length) 'chunk scanner byte accounting drifted'
Assert-McbrTest ($scan.matches.Count -eq 3) 'chunk scanner missed or duplicated a cross-chunk CAB'
$first = $scan.matches | Where-Object cabId -CEQ $cabA.ToLowerInvariant()
$second = $scan.matches | Where-Object cabId -CEQ $cabB.ToLowerInvariant()
$third = $scan.matches | Where-Object cabId -CEQ $cabC.ToLowerInvariant()
Assert-McbrTest ($null -ne $first -and $first.disposition -ceq 'Ambiguous') 'raw UnityFS payload token was promoted to provider'
Assert-McbrTest ($null -ne $second -and $second.disposition -ceq 'DependencyOnlyReference') 'dependency-only classification failed'
Assert-McbrTest ($null -ne $third -and $third.disposition -ceq 'DependencyOnlyReference') 'second raw archive-path CAB became a provider'

$plainPayload = [Text.Encoding]::ASCII.GetBytes("plain-$cabA")
$plainStream = [IO.MemoryStream]::new($plainPayload, $false)
try {
    $plainScan = Find-McbrCabTokensInStream -Stream $plainStream -KnownLength $plainPayload.Length -ChunkSize 5 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $plainStream.Dispose()
}
Assert-McbrTest ($plainScan.matches.Count -eq 1 -and $plainScan.matches[0].disposition -ceq 'Ambiguous') 'plain string occurrence was promoted to provider evidence'
$expiredStream = [IO.MemoryStream]::new($plainPayload, $false)
try {
    Assert-McbrThrowsCode {
        Find-McbrCabTokensInStream `
            -Stream $expiredStream `
            -KnownLength $plainPayload.Length `
            -ChunkSize 5 `
            -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMilliseconds(-1))
    } 'OverallTimeout' 'overall timeout was not enforced'
}
finally {
    $expiredStream.Dispose()
}

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mcbr-t1-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $pcRoot = Join-Path $tempRoot 'pc'
    $androidRoot = Join-Path $tempRoot 'android-data'
    [IO.Directory]::CreateDirectory($pcRoot) | Out-Null
    [IO.Directory]::CreateDirectory($androidRoot) | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $pcRoot 'one.unity3d'), [byte[]]@(1))
    [IO.File]::WriteAllBytes((Join-Path $pcRoot 'two.unity3d'), [byte[]]@(2))
    Assert-McbrThrowsCode {
        Get-McbrDirectoryCandidateFiles `
            -Root $pcRoot `
            -CandidateExtensions @('.unity3d') `
            -MaxCandidateFileCount 1 `
            -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
    } 'CandidateFileCap' 'candidate file cap was not enforced'
    $apkPath = Join-Path $tempRoot 'game.apk'
    $apkFile = [IO.File]::Open($apkPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($apkFile, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            $entry = $archive.CreateEntry('assets/bundles/provider.unity3d')
            $entryStream = $entry.Open()
            try {
                $entryBytes = $storedFixture
                $entryStream.Write($entryBytes, 0, $entryBytes.Length)
            }
            finally {
                $entryStream.Dispose()
            }
            $secondEntry = $archive.CreateEntry('assets/bundles/empty.bundle')
            $secondStream = $secondEntry.Open()
            try {
                $emptyBytes = [Text.Encoding]::ASCII.GetBytes('no-cab-here')
                $secondStream.Write($emptyBytes, 0, $emptyBytes.Length)
            }
            finally {
                $secondStream.Dispose()
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $apkFile.Dispose()
    }

    $manifestPath = Join-Path $tempRoot 'manifest.json'
    $sources = @(
        [pscustomobject][ordered]@{ sourceId = 'pc'; sourceKind = 'PcInstall'; rootPath = $pcRoot },
        [pscustomobject][ordered]@{ sourceId = 'apk'; sourceKind = 'AndroidApk'; rootPath = $apkPath },
        [pscustomobject][ordered]@{ sourceId = 'android'; sourceKind = 'AndroidDataOrCache'; rootPath = $androidRoot }
    )
    $manifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $locatorPath = Join-Path $tempRoot 'locator.json'
    $locator = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        manifestPath = $manifestPath
        baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
        sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
    }
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    $boundaries = Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds
    Assert-McbrTest ($boundaries.Count -eq 3) 'three-way source boundary did not validate'
    Assert-McbrTest ((@($boundaries | Where-Object sourceKind -CEQ 'AndroidApk').Count) -eq 1) 'APK boundary is absent'

    $apkLength = (Get-Item -LiteralPath $apkPath).Length
    $apkStream = [IO.File]::Open($apkPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $apkScan = Find-McbrCabTokensInApkStream `
            -Stream $apkStream `
            -SourceId 'apk' `
            -RelativePath 'game.apk' `
            -FileLength $apkLength `
            -ChunkSize 5 `
            -MaxCandidateEntryCount 2 `
            -MaxSingleEntryUncompressedBytes 1048576 `
            -MaxTotalEntryUncompressedBytes 2097152 `
            -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
    }
    finally {
        $apkStream.Dispose()
    }
    Assert-McbrTest ($apkScan.candidateEntryCount -eq 2) 'APK candidate entry accounting drifted'
    Assert-McbrTest ($apkScan.apkShaComputationCount -eq 1) 'APK SHA was not computed exactly once'
    Assert-McbrTest ($apkScan.matches.Count -eq 4) 'APK CAB match accounting drifted'
    Assert-McbrTest ($apkScan.matches[0].archiveEntry -ceq 'assets/bundles/provider.unity3d') 'APK entry path was not portable'
    Assert-McbrTest ($apkScan.matches[0].disposition -ceq 'ProviderCandidate') 'APK provider evidence classification failed'

    foreach ($capCase in @(
        [pscustomobject]@{ entries = 1; single = 1048576; total = 2097152; code = 'CandidateEntryCap'; name = 'candidate entry count' },
        [pscustomobject]@{ entries = 2; single = 1; total = 2097152; code = 'SingleEntryByteCap'; name = 'single entry bytes' },
        [pscustomobject]@{ entries = 2; single = 1048576; total = 1; code = 'TotalEntryByteCap'; name = 'total entry bytes' }
    )) {
        $capStream = [IO.File]::Open($apkPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        try {
            Assert-McbrThrowsCode {
                Find-McbrCabTokensInApkStream `
                    -Stream $capStream `
                    -SourceId 'apk' `
                    -RelativePath 'game.apk' `
                    -FileLength $apkLength `
                    -ChunkSize 5 `
                    -MaxCandidateEntryCount $capCase.entries `
                    -MaxSingleEntryUncompressedBytes $capCase.single `
                    -MaxTotalEntryUncompressedBytes $capCase.total `
                    -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
            } $capCase.code "$($capCase.name) cap was not enforced"
        }
        finally {
            $capStream.Dispose()
        }
    }

    $mismatch = $locator | ConvertTo-Json -Depth 8 | ConvertFrom-Json -Depth 8
    $mismatch.sourceBoundary.sources[0].rootPath = $androidRoot
    [IO.File]::WriteAllText($locatorPath, ($mismatch | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'bidirectional mismatch was accepted'

    $singleManifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources[0] }
    [IO.File]::WriteAllText($manifestPath, ($singleManifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'single-object sources masquerading as an array was accepted'

    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $junctionPath = Join-Path $tempRoot 'reparse-pc'
    New-Item -ItemType Junction -Path $junctionPath -Target $pcRoot | Out-Null
    $reparseSources = @(
        [pscustomobject][ordered]@{ sourceId = 'pc'; sourceKind = 'PcInstall'; rootPath = $junctionPath },
        $sources[1],
        $sources[2]
    )
    $reparseManifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $reparseSources }
    $reparseLocator = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        manifestPath = $manifestPath
        baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
        sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $reparseSources }
    }
    [IO.File]::WriteAllText($manifestPath, ($reparseManifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($locatorPath, ($reparseLocator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'reparse source root was accepted'

    $locator.manifestPath = '//server/share/manifest.json'
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'network manifest path was accepted'

    $outPath = Join-Path $tempRoot 'result.json'
    $terminal = New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence
    Write-McbrJsonCreateNew -LiteralPath $outPath -Value $terminal
    Assert-McbrThrows { Write-McbrJsonCreateNew -LiteralPath $outPath -Value $terminal } 'existing output was overwritten'
    $portableJson = [IO.File]::ReadAllText($outPath)
    Assert-McbrTest (-not $portableJson.Contains($tempRoot, [StringComparison]::OrdinalIgnoreCase)) 'portable JSON leaked a synthetic absolute path'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

$terminalKeys = @((New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence).PSObject.Properties.Name)
$expectedTerminalKeys = @(
    'schemaVersion', 'artifactId', 'status', 'decision', 'stage', 'failureCode',
    'exceptionType', 'head', 'elapsedMilliseconds', 'timeoutMilliseconds', 'caps', 'sourceBoundaryValidated',
    'scanCompleted', 'sourceScanLOUsed', 'targetCabCount', 'targetCabIds',
    'scannedSourceCount', 'scannedFileCount', 'scannedArchiveEntryCount',
    'candidateFileCount', 'candidateEntryCount', 'totalEntryUncompressedBytes',
    'apkShaComputationCount', 'scannedBytes', 'fileOpenCount', 'cabAccounting', 'matches',
    'inputEvidence', 'sourcePathLeakCount', 'sourceUnchanged', 'blockers',
    'nextAction'
)
Assert-McbrTest (($terminalKeys -join ',') -ceq ($expectedTerminalKeys -join ',')) 'terminal artifact registry shape drifted'
$decisions = @(
    'AllProvidersUniquelyIdentified',
    'PartialProvidersIdentified',
    'AmbiguousProviderCandidates',
    'BlockedScanCap',
    'BlockedSourceBoundary'
)
Assert-McbrTest (($contract.allowedDecisions -join ',') -ceq ($decisions -join ',')) 'decision registry drifted'
Assert-McbrTest (($contract.occurrenceDispositions -join ',') -ceq 'ProviderCandidate,DependencyOnlyReference,Ambiguous') 'occurrence partition drifted'
Assert-McbrTest (($contract.matchPropertyNames -join ',') -ceq 'cabId,disposition,sourceId,sourceKind,relativePath,archiveEntry,offset,fileLength,fileSha256,entryLength,entrySha256,evidence') 'match artifact schema drifted'
Assert-McbrTest (($contract.cabAccountingPropertyNames -join ',') -ceq 'cabId,disposition,totalOccurrences,providerCandidateCount,uniqueProviderCandidateCount,dependencyOnlyReferenceCount,ambiguousCount') 'CAB accounting schema drifted'
Assert-McbrTest ($contract.failureTransitions.FrozenEvidenceMismatch -ceq 'SuppressOutput') 'evidence failure output was not suppressed'
Assert-McbrTest ($contract.failureTransitions.SourceBoundary -ceq 'BlockedSourceBoundary') 'boundary failure transition drifted'
foreach ($capCode in @('OverallTimeout', 'CandidateFileCap', 'CandidateEntryCap', 'SingleEntryByteCap', 'TotalEntryByteCap')) {
    Assert-McbrTest ($contract.failureTransitions[$capCode] -ceq 'BlockedScanCap') "$capCode failure transition drifted"
}
Assert-McbrTest (-not $runnerText.Contains('UnclassifiedFailure', [StringComparison]::Ordinal)) 'unsanitized unclassified failure remains'
Assert-McbrTest ($runnerText.Contains("stage = 'TerminalWrite'", [StringComparison]::Ordinal)) 'terminal-write emergency stage is absent'
Assert-McbrTest (-not $runnerText.Contains('UnityBundleHeaderAndFirstNonDependencyCabIdentity', [StringComparison]::Ordinal)) 'rejected provider heuristic remains'
Assert-McbrTest ($runnerText.Contains('provider + dependencyOnly + ambiguous -eq totalOccurrences', [StringComparison]::Ordinal)) 'occurrence conservation formula is absent'
Assert-McbrTest ($runnerText.Contains('matched + unmatched -eq targetCabCount', [StringComparison]::Ordinal)) 'CAB conservation formula is absent'
Assert-McbrTest ($runnerText.Contains('BlockedSourceBoundary', [StringComparison]::Ordinal)) 'boundary failure transition is absent'
Assert-McbrTest ($runnerText.Contains('BlockedScanCap', [StringComparison]::Ordinal)) 'scan-cap failure transition is absent'

$allUnique = @(1..25 | ForEach-Object { [pscustomobject]@{ disposition = 'UniqueProviderCandidate' } })
$oneMissing = @($allUnique | Select-Object -First 24) + @([pscustomobject]@{ disposition = 'Unmatched' })
$oneAmbiguous = @($allUnique | Select-Object -First 24) + @([pscustomobject]@{ disposition = 'Ambiguous' })
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $allUnique -TargetCabCount 25) -ceq 'AllProvidersUniquelyIdentified') '25/25 unique decision drifted'
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $oneMissing -TargetCabCount 25) -ceq 'PartialProvidersIdentified') 'partial decision drifted'
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $oneAmbiguous -TargetCabCount 25) -ceq 'AmbiguousProviderCandidates') 'ambiguous decision drifted'
Assert-McbrThrows { Get-McbrDecisionFromAccounting -Accounting @() -TargetCabCount 25 } 'zero-row accounting was accepted'

$diagnosticTerminal = New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence
$diagnosticState = New-McbrScanState
$diagnosticTerminal = Set-McbrFailureDiagnostic `
    -Terminal $diagnosticTerminal `
    -Stage 'SourceScan' `
    -Exception ([InvalidOperationException]::new('synthetic message with C:\private\path')) `
    -State $diagnosticState `
    -Evidence $evidence
Assert-McbrTest ($diagnosticTerminal.stage -ceq 'SourceScan') 'failure stage was not retained'
Assert-McbrTest ($diagnosticTerminal.failureCode -ceq 'InternalFailure') 'unknown exception was not sanitized'
Assert-McbrTest ($diagnosticTerminal.exceptionType -ceq 'System.InvalidOperationException') 'exception type was not retained'
Assert-McbrTest ($diagnosticTerminal.decision -ceq 'BlockedScanCap') 'post-evidence internal failure transition drifted'
Assert-McbrTest (-not (($diagnosticTerminal | ConvertTo-Json -Depth 20).Contains('C:\private', [StringComparison]::OrdinalIgnoreCase))) 'exception message leaked into diagnostics'

$boundaryTerminal = New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence
$boundaryTerminal = Set-McbrFailureDiagnostic `
    -Terminal $boundaryTerminal `
    -Stage 'SourceBoundary' `
    -Exception ([InvalidOperationException]::new('MCBR:SourceBoundary')) `
    -State (New-McbrScanState) `
    -Evidence $evidence
Assert-McbrTest ($boundaryTerminal.failureCode -ceq 'SourceBoundary' -and $boundaryTerminal.decision -ceq 'BlockedSourceBoundary') 'source-boundary diagnostic transition drifted'

Write-Output 'MCBR-T1 focused tests passed: cabIds=25 unresolved=940 chunkBoundary=GREEN apkStream=GREEN sourceBoundary=GREEN createNew=GREEN'
