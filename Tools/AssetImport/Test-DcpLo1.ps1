Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$runnerPath = Join-Path $PSScriptRoot 'Invoke-DcpLo1.ps1'
$formalAttemptRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..\Extracted\DirectCharacterConsumerProof\char_14401\LO-DCP1')
)
if (Test-Path -LiteralPath $formalAttemptRoot) {
    throw 'Formal LO-DCP1 attempt root must remain absent during synthetic tests.'
}

. $runnerPath

$script:results = [System.Collections.Generic.List[object]]::new()

function Assert-DcpTest {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Add-DcpTestResult {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action
    )
    try {
        & $Action
        $script:results.Add([pscustomobject][ordered]@{ name = $Name; status = 'Passed'; detail = $null })
    }
    catch {
        $script:results.Add([pscustomobject][ordered]@{
            name = $Name
            status = 'Failed'
            detail = [string]$_.Exception.Message
        })
    }
}

function New-DcpSyntheticFixture {
    param(
        [Parameter(Mandatory)][string]$Base,
        [Parameter(Mandatory)][string]$CaseName
    )
    $caseRoot = Join-Path $Base $CaseName
    $repositoryRoot = Join-Path $caseRoot 'repo'
    $sourceRoot = Join-Path $caseRoot 'source'
    [System.IO.Directory]::CreateDirectory($repositoryRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($sourceRoot) | Out-Null
    $members = [System.Collections.Generic.List[object]]::new()
    $inputBytes = 0L
    for ($index = 1; $index -le 17; $index++) {
        $relative = "synthetic/group$([int](($index - 1) / 6))/member$($index.ToString('D2')).bin"
        $leaf = Join-Path $sourceRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($leaf)) | Out-Null
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes("DCP-LO1-SYNTHETIC-$($index.ToString('D2'))")
        [System.IO.File]::WriteAllBytes($leaf, $bytes)
        $sha = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($bytes)
        ).ToLowerInvariant()
        $members.Add([pscustomobject][ordered]@{
            relativePath = $relative
            length = [int64]$bytes.Length
            sha256 = $sha
        })
        $inputBytes += $bytes.Length
    }
    $canonicalSourceRoot = ([System.IO.DirectoryInfo]::new($sourceRoot)).FullName
    $sourceFingerprint = Get-DcpLo1SourceRootFingerprint -SourceId 'pc-install' -CanonicalSourceRoot $canonicalSourceRoot
    $snapshot = [pscustomobject][ordered]@{
        schemaVersion = 'dcp-source-snapshot/1.0.0'
        candidateId = 'char_14401'
        sourceRootFingerprint = $sourceFingerprint
        members = $members.ToArray()
        memberCount = 17
        inputBytes = $inputBytes
        status = 'SnapshotComplete'
    }
    $snapshotRelative = 'Extracted/DirectCharacterConsumerProof/char_14401/T1/current-input.json'
    $snapshotPath = Join-Path $repositoryRoot $snapshotRelative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($snapshotPath)) | Out-Null
    [System.IO.File]::WriteAllText(
        $snapshotPath,
        ($snapshot | ConvertTo-Json -Depth 10 -Compress),
        [System.Text.UTF8Encoding]::new($false)
    )
    $snapshotItem = Get-Item -LiteralPath $snapshotPath
    $attemptPortable = 'Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1'
    $contract = [pscustomobject][ordered]@{
        candidateId = 'char_14401'
        sourceId = 'pc-install'
        sourceKind = 'PcInstall'
        repositoryRoot = $repositoryRoot
        runnerIdentityPath = $runnerPath
        runnerPortablePath = 'Tools/AssetImport/Invoke-DcpLo1.ps1'
        snapshotPortablePath = $snapshotRelative
        snapshotByteCount = [int64]$snapshotItem.Length
        snapshotSha256 = Get-DcpLo1Sha256 $snapshotPath
        sourceRootFingerprint = $sourceFingerprint
        memberCount = 17
        inputByteCount = $inputBytes
        toolManifestPortablePath = 'Tools/AssetImport/tool-manifest.json'
        toolManifestSha256 = ('11' * 32)
        assetRipperLeafName = 'AssetRipper.GUI.Free.exe'
        assetRipperProductName = 'AssetRipper.GUI.Free'
        assetRipperVersion = '1.3.14.0'
        assetRipperByteCount = 1L
        assetRipperSha256 = ('22' * 32)
        port = 17777
        attemptPortableRoot = $attemptPortable
        stagingPortableRoot = "$attemptPortable/Input"
        outputPortableRoot = "$attemptPortable/Output"
        logPortablePath = "$attemptPortable/Logs/assetripper.log"
        terminalPortablePath = "$attemptPortable/terminal-result.json"
        stagingTimeoutMilliseconds = 240000L
        startupTimeoutMilliseconds = 30000L
        loadTimeoutMilliseconds = 300000L
        exportTimeoutMilliseconds = 1200000L
        shutdownTimeoutMilliseconds = 30000L
        overallTimeoutMilliseconds = 1800000L
        maxProcessStartCount = 1
        allowedChildProcessCount = 0
    }
    return [pscustomobject][ordered]@{
        caseRoot = $caseRoot
        repositoryRoot = $repositoryRoot
        sourceRoot = $canonicalSourceRoot
        snapshotPath = $snapshotPath
        snapshot = $snapshot
        contract = $contract
        attemptRoot = Join-Path $repositoryRoot $attemptPortable.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        terminalPath = Join-Path $repositoryRoot "$attemptPortable/terminal-result.json".Replace('/', [System.IO.Path]::DirectorySeparatorChar)
    }
}

function New-DcpSuccessProcessAdapter {
    return {
        param($context)
        $projectRoot = Join-Path $context.outputRoot 'ExportedProject'
        [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'Assets')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'Packages')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'ProjectSettings')) | Out-Null
        [System.IO.File]::WriteAllBytes(
            (Join-Path $projectRoot 'Assets/synthetic-export.asset'),
            [byte[]](1, 2, 3, 4)
        )
        [System.IO.File]::WriteAllText(
            $context.logPath,
            'synthetic AssetRipper log',
            [System.Text.UTF8Encoding]::new($false)
        )
        $context.processFacts.processStartCount = 1
        $context.processFacts.listenerOwnedDuringRun = $true
        $context.processFacts.loadHttpStatus = 200
        $context.processFacts.exportHttpStatus = 200
        $context.processFacts.shutdownAttempted = $true
        $context.processFacts.shutdownProcessExited = $true
        $context.processFacts.listenerAbsentAfterShutdown = $true
        return [pscustomobject][ordered]@{
            listenerOwned = $true
            unauthorizedChildProcessCount = 0
            classification = 'Exported'
        }
    }
}

function Invoke-DcpSyntheticCore {
    param(
        [Parameter(Mandatory)][object]$Fixture,
        [scriptblock]$SourceResolver,
        [scriptblock]$ToolResolver,
        [scriptblock]$PortProbe,
        [scriptblock]$ProcessAdapter,
        [scriptblock]$Clock
    )
    if ($null -eq $SourceResolver) {
        $source = $Fixture.sourceRoot
        $SourceResolver = { param($contract) $source }.GetNewClosure()
    }
    if ($null -eq $ToolResolver) {
        $ToolResolver = { param($contract) 'synthetic-assetripper.exe' }
    }
    if ($null -eq $PortProbe) {
        $PortProbe = { param($port) $true }
    }
    if ($null -eq $ProcessAdapter) {
        $ProcessAdapter = New-DcpSuccessProcessAdapter
    }
    if ($null -eq $Clock) {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $Clock = { [int64]$watch.ElapsedMilliseconds }.GetNewClosure()
    }
    return Invoke-DcpLo1Core `
        -Contract $Fixture.contract `
        -SourceRootResolver $SourceResolver `
        -AssetRipperResolver $ToolResolver `
        -PortProbe $PortProbe `
        -ProcessAdapter $ProcessAdapter `
        -Clock $Clock
}

function New-DcpSyntheticPbBinding {
    param(
        [Parameter(Mandatory)][object]$Fixture,
        [Parameter(Mandatory)][string]$Name
    )
    $bindingRoot = Join-Path $Fixture.caseRoot $Name
    $apkPath = Join-Path $bindingRoot 'StellaSora.apk'
    $androidDataRoot = Join-Path $bindingRoot 'android-data'
    [System.IO.Directory]::CreateDirectory($bindingRoot) | Out-Null
    [System.IO.Directory]::CreateDirectory($androidDataRoot) | Out-Null
    [System.IO.File]::WriteAllBytes($apkPath, [byte[]](0x50, 0x4b, 0x03, 0x04))
    $manifestPath = Join-Path $bindingRoot 'source-root-manifest.json'
    $locatorPath = Join-Path $bindingRoot 'personal-local-mode-inputs.json'
    $manifestRows = @(
        [pscustomobject][ordered]@{
            sourceId = 'pc-install'
            sourceKind = 'PcInstall'
            rootPath = $Fixture.sourceRoot
        },
        [pscustomobject][ordered]@{
            sourceId = 'android-apk'
            sourceKind = 'AndroidApk'
            rootPath = $apkPath
        },
        [pscustomobject][ordered]@{
            sourceId = 'android-data'
            sourceKind = 'AndroidDataOrCache'
            rootPath = $androidDataRoot
        }
    )
    $manifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $manifestRows }
    [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8 -Compress))
    $locator = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        manifestPath = $manifestPath
        baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
        sourceBoundary = [pscustomobject][ordered]@{
            schemaVersion = '1.0.0'
            sources = @(
                [pscustomobject][ordered]@{
                    sourceId = 'pc-install'
                    sourceKind = 'PcInstall'
                    rootPath = Join-Path $Fixture.sourceRoot '.'
                },
                $manifestRows[1],
                $manifestRows[2]
            )
        }
    }
    [System.IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8 -Compress))
    return [pscustomobject][ordered]@{
        locatorPath = $locatorPath
        manifestPath = $manifestPath
        locator = $locator
        manifest = $manifest
        apkPath = $apkPath
        androidDataRoot = $androidDataRoot
    }
}

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$testRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot ('stella-dcp-lo1-' + [guid]::NewGuid().ToString('N')))
)
if (-not $testRoot.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Synthetic test root is outside the OS temporary directory.'
}
[System.IO.Directory]::CreateDirectory($testRoot) | Out-Null

try {
    Add-DcpTestResult 'SnapshotBindingFailure' {
        $fixture = New-DcpSyntheticFixture $testRoot 'snapshot-binding'
        [System.IO.File]::AppendAllText($fixture.snapshotPath, 'x')
        $result = Invoke-DcpSyntheticCore $fixture
        Assert-DcpTest ($result.classification -ceq 'SnapshotIdentityFailure') 'Snapshot identity drift was not rejected.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Snapshot failure started a process.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 0) 'Snapshot failure opened source content.'
    }

    Add-DcpTestResult 'ToolBindingFailure' {
        $fixture = New-DcpSyntheticFixture $testRoot 'tool-binding'
        $resolver = { param($contract) Stop-DcpLo1 'ToolIdentityFailure' }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ToolResolver $resolver
        Assert-DcpTest ($result.classification -ceq 'ToolIdentityFailure') 'Tool binding failure was not retained.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Tool failure started a process.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 0) 'Tool failure opened source content.'
    }

    Add-DcpTestResult 'SourceRootBindingFailure' {
        $fixture = New-DcpSyntheticFixture $testRoot 'root-binding'
        $resolver = { param($contract) Stop-DcpLo1 'SourceBindingFailure' }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -SourceResolver $resolver
        Assert-DcpTest ($result.classification -ceq 'SourceBindingFailure') 'Source binding failure was not retained.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Source binding failure started a process.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 0) 'Source binding failure opened source content.'
    }

    Add-DcpTestResult 'SingleOpenSuccessAndPortableResult' {
        $fixture = New-DcpSyntheticFixture $testRoot 'single-open'
        $result = Invoke-DcpSyntheticCore $fixture
        Assert-DcpTest ($result.status -ceq 'Exported') 'Synthetic success was not Exported.'
        Assert-DcpTest ($result.processStartCount -eq 1) 'Synthetic success did not use one process start.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 17) 'Each source member was not opened exactly once.'
        Assert-DcpTest ($result.stagedMemberCount -eq 17) 'Staged member count mismatch.'
        Assert-DcpTest ($result.stagedBytes -eq $fixture.contract.inputByteCount) 'Staged byte conservation failed.'
        Assert-DcpTest ($result.runnerSha256 -ceq (Get-DcpLo1Sha256 $runnerPath)) 'Actual runner identity was not recorded.'
        Assert-DcpTest ($result.toolManifestSha256 -ceq $fixture.contract.toolManifestSha256) 'Tool-manifest identity was not recorded.'
        Assert-DcpTest ($result.sourceRootFingerprint -ceq $fixture.contract.sourceRootFingerprint) 'Source-root fingerprint was not recorded.'
        Assert-DcpTest ($result.stagingInventoryIdentity -cmatch '^[0-9a-f]{64}$') 'Staging inventory identity was not recorded.'
        Assert-DcpTest ($result.loadHttpStatus -eq 200 -and $result.exportHttpStatus -eq 200) 'HTTP status facts were not recorded.'
        Assert-DcpTest ($result.shutdownAttempted -and $result.shutdownProcessExited -and $result.listenerAbsentAfterShutdown) 'Shutdown facts were not recorded.'
        Assert-DcpTest (-not $result.roleAcceptanceClaimed) 'Production classification claimed role acceptance.'
        $terminalRaw = [System.IO.File]::ReadAllText($fixture.terminalPath)
        Assert-DcpTest ($terminalRaw -notmatch '[A-Za-z]:\\') 'Terminal result leaked an absolute path.'
        Assert-DcpTest (-not $terminalRaw.Contains($fixture.sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) 'Terminal result leaked source root.'
    }

    Add-DcpTestResult 'NoOverwriteOrRerun' {
        $fixture = New-DcpSyntheticFixture $testRoot 'no-overwrite'
        $first = Invoke-DcpSyntheticCore $fixture
        Assert-DcpTest ($first.status -ceq 'Exported') 'First synthetic invocation failed.'
        $terminalHash = Get-DcpLo1Sha256 $fixture.terminalPath
        $threw = $false
        try { $null = Invoke-DcpSyntheticCore $fixture }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:AttemptAlreadyExists' }
        Assert-DcpTest $threw 'Existing attempt root did not prevent rerun.'
        Assert-DcpTest ((Get-DcpLo1Sha256 $fixture.terminalPath) -ceq $terminalHash) 'Existing terminal result was modified.'
    }

    Add-DcpTestResult 'StagingMismatchZeroProcess' {
        $fixture = New-DcpSyntheticFixture $testRoot 'staging-mismatch'
        $firstMember = $fixture.snapshot.members[0]
        $leaf = Join-Path $fixture.sourceRoot $firstMember.relativePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
        $bytes = [System.IO.File]::ReadAllBytes($leaf)
        $bytes[0] = $bytes[0] -bxor 0xff
        [System.IO.File]::WriteAllBytes($leaf, $bytes)
        $result = Invoke-DcpSyntheticCore $fixture
        Assert-DcpTest ($result.classification -ceq 'StagingMemberMismatch') 'Equal-size staging mutation was not rejected.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Staging mismatch started a process.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 1) 'Staging mismatch did not stop on the first opened member.'
        Assert-DcpTest ($result.evidencePreserved -and $result.stagingPresent) 'Failed staging evidence was not preserved.'
    }

    Add-DcpTestResult 'PortOccupiedZeroProcess' {
        $fixture = New-DcpSyntheticFixture $testRoot 'port-occupied'
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -PortProbe { param($port) $false }
        Assert-DcpTest ($result.classification -ceq 'PortOccupied') 'Occupied port was not rejected.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Occupied port started a process.'
        Assert-DcpTest ($result.sourceContentOpenCount -eq 0) 'Occupied port opened source content.'
    }

    Add-DcpTestResult 'ListenerPidOwnership' {
        $fixture = New-DcpSyntheticFixture $testRoot 'listener-owner'
        $adapter = {
            param($context)
            [System.IO.File]::WriteAllText($context.logPath, 'synthetic wrong owner')
            $context.processFacts.processStartCount = 1
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            return [pscustomobject][ordered]@{
                listenerOwned = $false
                unauthorizedChildProcessCount = 0
                classification = 'Exported'
            }
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'ListenerOwnershipFailure') 'Wrong listener PID was not rejected.'
        Assert-DcpTest ($result.processStartCount -eq 1) 'PID ownership test did not record one process start.'
    }

    Add-DcpTestResult 'UnauthorizedChildProcess' {
        $fixture = New-DcpSyntheticFixture $testRoot 'child-process'
        $adapter = {
            param($context)
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.unauthorizedChildProcessCount = 1
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            return [pscustomobject][ordered]@{
                listenerOwned = $true
                unauthorizedChildProcessCount = 1
                classification = 'Exported'
            }
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'UnexpectedChildProcess') 'Unauthorized child process was not reported.'
        Assert-DcpTest ($result.processStartCount -eq 1) 'Child-process test did not record one process start.'
    }

    Add-DcpTestResult 'OverallTimeout' {
        $fixture = New-DcpSyntheticFixture $testRoot 'overall-timeout'
        $fixture.contract.overallTimeoutMilliseconds = 1000L
        $script:syntheticClock = 0L
        $clock = { [int64]$script:syntheticClock }
        $adapter = {
            param($context)
            $projectRoot = Join-Path $context.outputRoot 'ExportedProject'
            [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'Assets')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'Packages')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $projectRoot 'ProjectSettings')) | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $projectRoot 'Assets/late.asset'), [byte[]](1))
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            $script:syntheticClock = 1001L
            return [pscustomobject][ordered]@{
                listenerOwned = $true
                unauthorizedChildProcessCount = 0
                classification = 'Exported'
            }
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter -Clock $clock
        Assert-DcpTest ($result.classification -ceq 'OverallTimeout') 'Overall timeout was not enforced.'
        Assert-DcpTest ($result.processStartCount -eq 1) 'Timeout test did not record one process start.'
        Assert-DcpTest ($result.evidencePreserved -and $result.stagingPresent -and $result.outputPresent) 'Timeout evidence was not preserved.'
    }

    Add-DcpTestResult 'StartFailureKeepsZeroProcessCount' {
        $fixture = New-DcpSyntheticFixture $testRoot 'start-failure'
        $adapter = { param($context) Stop-DcpLo1 'AssetRipperStartFailure' }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'AssetRipperStartFailure') 'Start failure classification was not retained.'
        Assert-DcpTest ($result.processStartCount -eq 0) 'Failed Start-Process was counted as started.'
        Assert-DcpTest ($result.stagingPresent -and $result.outputPresent) 'Start-failure evidence was not preserved.'
    }

    Add-DcpTestResult 'CleanupIncompleteAfterShutdown' {
        $fixture = New-DcpSyntheticFixture $testRoot 'cleanup-incomplete'
        $adapter = {
            param($context)
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $false
            $context.processFacts.listenerAbsentAfterShutdown = $false
            Stop-DcpLo1 'CleanupIncomplete'
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'CleanupIncomplete') 'Incomplete shutdown/listener cleanup was not retained.'
        Assert-DcpTest ($result.processStartCount -eq 1) 'Cleanup test did not retain successful process start.'
        Assert-DcpTest (-not $result.shutdownProcessExited -and -not $result.listenerAbsentAfterShutdown) 'Cleanup failure facts were not retained.'
    }

    Add-DcpTestResult 'RequiredExportTree' {
        $fixture = New-DcpSyntheticFixture $testRoot 'required-export-tree'
        $adapter = {
            param($context)
            $assets = Join-Path $context.outputRoot 'ExportedProject/Assets'
            [System.IO.Directory]::CreateDirectory($assets) | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $assets 'only.meta'), [byte[]](1))
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.loadHttpStatus = 200
            $context.processFacts.exportHttpStatus = 200
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            [pscustomobject]@{ listenerOwned = $true; unauthorizedChildProcessCount = 0; classification = 'Exported' }
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'OutputMissingOrInvalid') 'Incomplete ExportedProject tree was accepted.'
        Assert-DcpTest ($result.outputPresent) 'Invalid output evidence was not preserved.'
    }

    Add-DcpTestResult 'MetaOnlyAssetsRejected' {
        $fixture = New-DcpSyntheticFixture $testRoot 'meta-only-assets'
        $adapter = {
            param($context)
            $project = Join-Path $context.outputRoot 'ExportedProject'
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'Assets')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'Packages')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'ProjectSettings')) | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $project 'Assets/only.meta'), [byte[]](1))
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            [pscustomobject]@{ listenerOwned = $true; unauthorizedChildProcessCount = 0; classification = 'Exported' }
        }
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'OutputMissingOrInvalid') 'Assets containing only .meta files were accepted.'
    }

    Add-DcpTestResult 'OutputTreeReparseRejected' {
        $fixture = New-DcpSyntheticFixture $testRoot 'output-reparse'
        $externalTarget = Join-Path $fixture.caseRoot 'external-output-target'
        [System.IO.Directory]::CreateDirectory($externalTarget) | Out-Null
        $adapter = {
            param($context)
            $project = Join-Path $context.outputRoot 'ExportedProject'
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'Assets')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'Packages')) | Out-Null
            [System.IO.Directory]::CreateDirectory((Join-Path $project 'ProjectSettings')) | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $project 'Assets/payload.asset'), [byte[]](1))
            $null = New-Item -ItemType Junction -Path (Join-Path $project 'Packages/linked') -Target $externalTarget
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            [pscustomobject]@{ listenerOwned = $true; unauthorizedChildProcessCount = 0; classification = 'Exported' }
        }.GetNewClosure()
        $result = Invoke-DcpSyntheticCore -Fixture $fixture -ProcessAdapter $adapter
        Assert-DcpTest ($result.classification -ceq 'OutputMissingOrInvalid') 'Reparse entry in output tree was accepted.'
    }

    Add-DcpTestResult 'ExplicitHttpFailureClassifications' {
        $loadFixture = New-DcpSyntheticFixture $testRoot 'http-load'
        $loadAdapter = {
            param($context)
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            Stop-DcpLo1 'AssetRipperLoadFailure'
        }
        $loadResult = Invoke-DcpSyntheticCore -Fixture $loadFixture -ProcessAdapter $loadAdapter
        Assert-DcpTest ($loadResult.classification -ceq 'AssetRipperLoadFailure') 'Load failure fell through to another classification.'

        $exportFixture = New-DcpSyntheticFixture $testRoot 'http-export'
        $exportAdapter = {
            param($context)
            $context.processFacts.processStartCount = 1
            $context.processFacts.listenerOwnedDuringRun = $true
            $context.processFacts.shutdownAttempted = $true
            $context.processFacts.shutdownProcessExited = $true
            $context.processFacts.listenerAbsentAfterShutdown = $true
            Stop-DcpLo1 'AssetRipperExportTimeout'
        }
        $exportResult = Invoke-DcpSyntheticCore -Fixture $exportFixture -ProcessAdapter $exportAdapter
        Assert-DcpTest ($exportResult.classification -ceq 'AssetRipperExportTimeout') 'Export timeout fell through to another classification.'
    }

    Add-DcpTestResult 'HttpStatusAndSafetyClassification' {
        $facts = [pscustomobject][ordered]@{ loadHttpStatus = $null; exportHttpStatus = $null }
        $threw = $false
        try {
            Set-DcpLo1HttpStatusOrFail -ProcessFacts $facts -StageName Load -StatusCode 418 -IsSuccessStatusCode $false
        }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:AssetRipperLoadFailure' }
        Assert-DcpTest ($threw -and $facts.loadHttpStatus -eq 418) 'Load non-2xx status was not recorded before failure.'
        $threw = $false
        try {
            Set-DcpLo1HttpStatusOrFail -ProcessFacts $facts -StageName Export -StatusCode 503 -IsSuccessStatusCode $false
        }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:AssetRipperExportFailure' }
        Assert-DcpTest ($threw -and $facts.exportHttpStatus -eq 503) 'Export non-2xx status was not recorded before failure.'
        foreach ($code in @(
            'ChildProcessInspectionFailure',
            'UnexpectedChildProcess',
            'ListenerOwnershipFailure',
            'AssetRipperExitedUnexpectedly',
            'OverallTimeout'
        )) {
            Assert-DcpTest (Test-DcpLo1HttpPreservedFailure -Message "DCPLO1:$code") "$code would be rewritten as an HTTP stage failure."
        }
        Assert-DcpTest (-not (Test-DcpLo1HttpPreservedFailure -Message 'socket closed')) 'Ordinary transport failure was treated as a safety classification.'
    }

    Add-DcpTestResult 'PbI03FullBindingValidation' {
        $fixture = New-DcpSyntheticFixture $testRoot 'pb-i03-binding'
        $binding = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'valid'
        $resolved = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $binding.locatorPath
        Assert-DcpTest ($resolved -ceq $fixture.sourceRoot) 'Normalized PB-I03/manifest paths did not bind bidirectionally.'
        Assert-DcpTest ((Get-Item -LiteralPath $binding.apkPath) -is [System.IO.FileInfo]) 'Synthetic AndroidApk is not a real file.'
        Assert-DcpTest ((Get-Item -LiteralPath $binding.androidDataRoot) -is [System.IO.DirectoryInfo]) 'Synthetic AndroidDataOrCache is not a real directory.'
        Assert-DcpTest (@($binding.manifest.sources).Count -eq 3 -and @($binding.locator.sourceBoundary.sources).Count -eq 3) 'Three-source binding was not constructed.'

        $binding.locator.baseline.path = $binding.manifestPath
        [System.IO.File]::WriteAllText($binding.locatorPath, ($binding.locator | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $binding.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'Invalid baseline disposition/path was accepted.'

        $duplicate = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'duplicate'
        $duplicate.manifest.sources += [pscustomobject][ordered]@{
            sourceId = 'PC-INSTALL'
            sourceKind = 'PcInstall'
            rootPath = $fixture.sourceRoot
        }
        [System.IO.File]::WriteAllText($duplicate.manifestPath, ($duplicate.manifest | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $duplicate.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'Case-insensitive duplicate sourceId was accepted.'
    }

    Add-DcpTestResult 'PbI03ArrayIdAndLeafTypeRejections' {
        $fixture = New-DcpSyntheticFixture $testRoot 'pb-i03-negative'

        $singleBoundary = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'single-boundary'
        $singleBoundary.locator.sourceBoundary.sources = $singleBoundary.locator.sourceBoundary.sources[0]
        [System.IO.File]::WriteAllText($singleBoundary.locatorPath, ($singleBoundary.locator | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $singleBoundary.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'Single-object sourceBoundary.sources masquerading as an array was accepted.'

        $singleManifest = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'single-manifest'
        $singleManifest.manifest.sources = $singleManifest.manifest.sources[0]
        [System.IO.File]::WriteAllText($singleManifest.manifestPath, ($singleManifest.manifest | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $singleManifest.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'Single-object manifest.sources masquerading as an array was accepted.'

        $invalidId = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'invalid-id'
        $invalidId.locator.sourceBoundary.sources[2].sourceId = 'bad source id'
        $invalidId.manifest.sources[2].sourceId = 'bad source id'
        [System.IO.File]::WriteAllText($invalidId.locatorPath, ($invalidId.locator | ConvertTo-Json -Depth 8 -Compress))
        [System.IO.File]::WriteAllText($invalidId.manifestPath, ($invalidId.manifest | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $invalidId.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'Invalid sourceId characters were accepted.'

        $apkAsDirectory = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'apk-as-directory'
        $apkAsDirectory.locator.sourceBoundary.sources[1].rootPath = $apkAsDirectory.androidDataRoot
        $apkAsDirectory.manifest.sources[1].rootPath = $apkAsDirectory.androidDataRoot
        [System.IO.File]::WriteAllText($apkAsDirectory.locatorPath, ($apkAsDirectory.locator | ConvertTo-Json -Depth 8 -Compress))
        [System.IO.File]::WriteAllText($apkAsDirectory.manifestPath, ($apkAsDirectory.manifest | ConvertTo-Json -Depth 8 -Compress))
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $apkAsDirectory.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        Assert-DcpTest $threw 'AndroidApk bound to a directory was accepted.'
    }

    Add-DcpTestResult 'UncManifestPathRejectedBeforeAccess' {
        $fixture = New-DcpSyntheticFixture $testRoot 'pb-i03-unc-manifest'
        $binding = New-DcpSyntheticPbBinding -Fixture $fixture -Name 'unc-manifest'
        $binding.locator.manifestPath = '//server/share/manifest.json'
        [System.IO.File]::WriteAllText($binding.locatorPath, ($binding.locator | ConvertTo-Json -Depth 8 -Compress))
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $threw = $false
        try { $null = Resolve-DcpLo1SourceRootFromLocator -Contract $fixture.contract -LocatorPath $binding.locatorPath }
        catch { $threw = $_.Exception.Message -ceq 'DCPLO1:SourceBindingFailure' }
        $watch.Stop()
        Assert-DcpTest $threw 'Forward-slash UNC manifestPath was not rejected.'
        Assert-DcpTest ($watch.ElapsedMilliseconds -lt 1000) 'UNC manifestPath rejection was not immediate.'
    }

    Add-DcpTestResult 'SnapshotAndToolPathReparseRejected' {
        $caseRoot = Join-Path $testRoot 'path-reparse'
        $target = Join-Path $caseRoot 'target'
        $junction = Join-Path $caseRoot 'junction'
        [System.IO.Directory]::CreateDirectory($target) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $target 'bound.json'), '{}')
        $null = New-Item -ItemType Junction -Path $junction -Target $target
        foreach ($code in @('SnapshotIdentityFailure', 'ToolIdentityFailure')) {
            $threw = $false
            try {
                Assert-DcpLo1NoReparseChain -AbsolutePath (Join-Path $junction 'bound.json') -LeafKind File -FailureCode $code
            }
            catch { $threw = $_.Exception.Message -ceq "DCPLO1:$code" }
            Assert-DcpTest $threw "$code did not reject a reparse path chain."
        }
    }

    Add-DcpTestResult 'FormalEntryBoundary' {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $runnerPath,
            [ref]$tokens,
            [ref]$errors
        )
        Assert-DcpTest ($errors.Count -eq 0) 'Runner has parser errors.'
        Assert-DcpTest ($null -eq $ast.ParamBlock -or $ast.ParamBlock.Parameters.Count -eq 0) 'Runner exposes top-level parameters.'
        $startCalls = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -ceq 'Start-Process'
        }, $true))
        Assert-DcpTest ($startCalls.Count -eq 1) 'Runner must contain exactly one AssetRipper process-start site.'
        $legacyReferences = @($ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.StringConstantExpressionAst] -and
            $node.Value -match 'Invoke-CergLo1|Invoke-AssetRipperFolderExport'
        }, $true))
        Assert-DcpTest ($legacyReferences.Count -eq 0) 'Runner references a historical CERG runner.'
        $runnerText = [System.IO.File]::ReadAllText($runnerPath)
        Assert-DcpTest ($runnerText -match 'processStartCount = \$null') 'Emergency output still claims a known process count.'
        Assert-DcpTest ($runnerText -match "processStartCountState = 'Unknown'") 'Emergency output lacks Unknown process-count state.'
        Assert-DcpTest ($runnerText -match 'evidenceComplete = \$false') 'Emergency output does not mark evidence incomplete.'
    }
}
finally {
    $resolved = [System.IO.Path]::GetFullPath($testRoot)
    if (-not $resolved.StartsWith($temporaryRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing unsafe synthetic cleanup.'
    }
    if (Test-Path -LiteralPath $resolved) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}

if (Test-Path -LiteralPath $formalAttemptRoot) {
    throw 'Synthetic tests created the formal LO-DCP1 attempt root.'
}

$failed = @($script:results | Where-Object status -cne 'Passed')
$script:results | Format-Table -AutoSize
if ($failed.Count -gt 0) {
    throw "DCP LO1 focused tests failed: $($failed.Count)"
}
"DCP LO1 focused tests passed: $($script:results.Count)"
