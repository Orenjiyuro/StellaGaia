[CmdletBinding()]
param(
    [ValidateSet('AllFile', 'FileRoot', 'Conservation', 'FailureModes', 'All')]
    [string]$Case = 'All'
)

$modulePath = Join-Path $PSScriptRoot 'SourceCorpusGate.psm1'
Import-Module $modulePath -Force
$ErrorActionPreference = 'Stop'
$issues = [System.Collections.Generic.List[string]]::new()
$tempRoots = [System.Collections.Generic.List[string]]::new()
$counts = [ordered]@{
    expectedFileCount = 0
    catalogedFileCount = 0
    catalogedBytes = 0
    unknownInputCount = 0
    fileRootCatalogedFileCount = 0
    fileRootCatalogedBytes = 0
    fileRootBoundaryOutcome = 'NotRun'
    junctionTestOutcome = 'NotRun'
}

function Add-Issue([string]$Message) { $issues.Add($Message) }
function Assert-Equal([string]$Name, [AllowNull()][object]$Expected, [AllowNull()][object]$Actual) {
    if ($Expected -cne $Actual) { Add-Issue "$Name expected '$Expected', got '$Actual'." }
}
function Assert-Throws([string]$Name, [scriptblock]$Action, [string]$ExpectedMessage) {
    try { & $Action | Out-Null; Add-Issue "$Name did not throw." }
    catch { if ($_.Exception.Message -cne $ExpectedMessage) { Add-Issue "$Name threw '$($_.Exception.Message)', expected '$ExpectedMessage'." } }
}
function Assert-PrivateSummary {
    param([object]$Summary, [object[]]$Exclusions)
    if (
        [long]$Summary.sourceFileCount -ne ([long]$Summary.catalogedFileCount + [long]$Summary.explicitlyExcludedFileCount) -or
        [long]$Summary.sourceBytes -ne ([long]$Summary.catalogedBytes + [long]$Summary.explicitlyExcludedBytes)
    ) { throw 'Source catalog conservation failed.' }
    Assert-ValidSourceExclusions -Exclusions $Exclusions -SourceId ([string]$Summary.sourceId) | Out-Null
}
function New-FixtureRoot {
    $root = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-catalog-{0}" -f [guid]::NewGuid().ToString('N'))
    $tempRoots.Add($root)
    foreach ($directory in @('known', 'unknown', 'hidden', 'empty')) {
        [System.IO.Directory]::CreateDirectory((Join-Path $root $directory)) | Out-Null
    }
    [System.IO.File]::WriteAllText((Join-Path $root 'known\data.unity3d'), 'bundle')
    [System.IO.File]::WriteAllText((Join-Path $root 'unknown\payload.arcx'), 'arcx')
    [System.IO.File]::WriteAllText((Join-Path $root 'unknown\metadata.arch'), 'arch')
    [System.IO.File]::WriteAllText((Join-Path $root 'unknown\README'), 'readme')
    $hiddenPath = Join-Path $root 'hidden\hidden.dat'
    [System.IO.File]::WriteAllText($hiddenPath, 'hidden')
    [System.IO.File]::SetAttributes($hiddenPath, ([System.IO.File]::GetAttributes($hiddenPath) -bor [System.IO.FileAttributes]::Hidden))
    [System.IO.File]::WriteAllBytes((Join-Path $root 'empty\zero.bin'), [byte[]]@())
    return $root
}
function Invoke-JunctionAncestorTest {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$IssueSink,
        [scriptblock]$JunctionCreator = {
            param($path, $target)
            New-Item -ItemType Junction -Path $path -Target $target -ErrorAction Stop | Out-Null
        }
    )
    $junctionTarget = Join-Path $Root 'junction-target'
    $junctionPath = Join-Path $Root 'junction-link'
    [System.IO.Directory]::CreateDirectory((Join-Path $junctionTarget 'nested')) | Out-Null
    try {
        & $JunctionCreator $junctionPath $junctionTarget
        try {
            New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath (Join-Path $junctionPath 'nested') -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') | Out-Null
            $IssueSink.Add('junction ancestor was accepted.')
        }
        catch {
            if ($_.Exception.Message -notlike '*junction-link is a reparse point.') { $IssueSink.Add("junction ancestor threw unexpected '$($_.Exception.Message)'.") }
        }
        return 'Passed'
    }
    catch {
        if ($IsWindows) {
            $IssueSink.Add("Junction setup failed on supported Windows: $($_.Exception.Message)")
            return "Failed: $($_.Exception.Message)"
        }
        return "Skipped (junction capability unsupported on this platform): $($_.Exception.Message)"
    }
}
function Invoke-AllFile {
    $root = New-FixtureRoot
    try {
        $capturedAt = [datetimeoffset]'2026-07-10T12:34:56+08:00'
        $catalog = New-SourceCorpusCatalog -SnapshotId 'fixture-snapshot' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt $capturedAt
        $expected = @('empty/zero.bin', 'hidden/hidden.dat', 'known/data.unity3d', 'unknown/README', 'unknown/metadata.arch', 'unknown/payload.arcx') | Sort-Object -CaseSensitive
        $actual = @($catalog.files.relativePath | Sort-Object -CaseSensitive)
        Assert-Equal 'all-file count' 6 $actual.Count
        Assert-Equal 'all-file paths' ($expected -join '|') ($actual -join '|')
        Assert-Equal 'unique all-file paths' 6 @($actual | Select-Object -Unique).Count
        Assert-Equal 'cataloged count' 6 $catalog.catalogedFileCount
        Assert-Equal 'excluded count' 0 $catalog.explicitlyExcludedFileCount
        $expectedBytes = [long](Get-ChildItem -LiteralPath $root -Recurse -File -Force | Measure-Object Length -Sum).Sum
        Assert-Equal 'cataloged bytes' $expectedBytes $catalog.catalogedBytes
        $counts.expectedFileCount = 6; $counts.catalogedFileCount = $catalog.catalogedFileCount; $counts.catalogedBytes = $catalog.catalogedBytes
        $unknown = @($catalog.files | Where-Object containerKind -CEQ 'UnknownInput')
        $counts.unknownInputCount = $unknown.Count
        Assert-Equal 'unknown input count' 5 $unknown.Count
        foreach ($row in $catalog.files) {
            Assert-Equal "$($row.relativePath) C0 row shape" 'snapshotId|sourceId|sourceKind|relativePath|sizeBytes|sha256|capturedAt|containerKind|parseStatus|disposition|evidence|status' ($row.PSObject.Properties.Name -join '|')
            Assert-Equal "$($row.relativePath) snapshot" 'fixture-snapshot' $row.snapshotId
            Assert-Equal "$($row.relativePath) source" 'pc-install' $row.sourceId
            Assert-Equal "$($row.relativePath) kind" 'PcInstall' $row.sourceKind
            Assert-Equal "$($row.relativePath) capturedAt" '2026-07-10T04:34:56.0000000+00:00' $row.capturedAt
            Assert-Equal "$($row.relativePath) parse" 'NotAttempted' $row.parseStatus
            Assert-Equal "$($row.relativePath) disposition" 'RetainForLater' $row.disposition
            Assert-Equal "$($row.relativePath) evidence" 0 @($row.evidence).Count
            Assert-Equal "$($row.relativePath) corpus" 'Cataloged' $row.status.corpus
            Assert-Equal "$($row.relativePath) extraction" 'NotAttempted' $row.status.extraction
            Assert-Equal "$($row.relativePath) semantics" 'Unknown' $row.status.semantics
            Assert-Equal "$($row.relativePath) unity" 'NotTested' $row.status.unity
            Assert-Equal "$($row.relativePath) status disposition" 'RetainForLater' $row.status.disposition
            if ([string]$row.sha256 -cnotmatch '^[0-9a-f]{64}$') { Add-Issue "$($row.relativePath) SHA-256 is invalid." }
        }
        Assert-Equal 'known bundle kind' 'UnityBundle' ($catalog.files | Where-Object relativePath -CEQ 'known/data.unity3d').containerKind
        Assert-Equal 'zero byte size' 0 ($catalog.files | Where-Object relativePath -CEQ 'empty/zero.bin').sizeBytes
        Assert-Equal 'small streaming hash' '1e6ed65d77d6364eeaed5a745ba5c4985ae2b700dd85d7cf7f027bdf294a33fc' ($catalog.files | Where-Object relativePath -CEQ 'known/data.unity3d').sha256
        Assert-Equal 'zero streaming hash' 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855' ($catalog.files | Where-Object relativePath -CEQ 'empty/zero.bin').sha256
        if ((Get-Content -LiteralPath $modulePath -Raw) -match '\bReadAllBytes\b') { Add-Issue 'production module still contains ReadAllBytes.' }
        $containerCases = [ordered]@{
            'a.unity3d' = 'UnityBundle'; 'a.bundle' = 'UnityBundle'; 'a.assets' = 'UnitySerializedAsset'
            'a.wem' = 'DirectAudio'; 'a.bnk' = 'AudioMetadata'; 'a.mp4' = 'DirectVideo'
            'a.srt' = 'Metadata'; 'a.json' = 'ConfigurationCandidate'; 'README' = 'UnknownInput'
        }
        foreach ($containerCase in $containerCases.GetEnumerator()) {
            Assert-Equal "container kind $($containerCase.Key)" $containerCase.Value (Get-SourceContainerKind -RelativePath $containerCase.Key)
        }
    }
    catch { Add-Issue "AllFile: $($_.Exception.Message)" }
}
function Invoke-FileRoot {
    $fixtureDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-file-root-{0}" -f [guid]::NewGuid().ToString('N'))
    $tempRoots.Add($fixtureDirectory)
    [System.IO.Directory]::CreateDirectory($fixtureDirectory) | Out-Null
    $apkPath = Join-Path $fixtureDirectory 'stella-synthetic.apk'
    $siblingPath = Join-Path $fixtureDirectory 'sibling.apk'
    [System.IO.File]::WriteAllText($apkPath, 'synthetic-apk-root')
    [System.IO.File]::WriteAllText($siblingPath, 'synthetic-sibling')
    try {
        $catalog = New-SourceCorpusCatalog -SnapshotId 'fixture-file-root' -SourceId 'android-apk' -SourceKind 'AndroidApk' -RootPath $apkPath -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z')
        $expectedBytes = [long](Get-Item -LiteralPath $apkPath -Force).Length
        $expectedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $apkPath).Hash.ToLowerInvariant()
        $row = @($catalog.files)[0]

        Assert-Equal 'file root row count' 1 @($catalog.files).Count
        Assert-Equal 'file root cataloged count' 1 $catalog.catalogedFileCount
        Assert-Equal 'file root cataloged bytes' $expectedBytes $catalog.catalogedBytes
        Assert-Equal 'file root excluded count' 0 $catalog.explicitlyExcludedFileCount
        Assert-Equal 'file root relative path' 'stella-synthetic.apk' $row.relativePath
        Assert-Equal 'file root source kind' 'AndroidApk' $row.sourceKind
        Assert-Equal 'file root size' $expectedBytes $row.sizeBytes
        Assert-Equal 'file root hash' $expectedHash $row.sha256
        Assert-Equal 'file root count conservation' 1L ([long]$catalog.catalogedFileCount + [long]$catalog.explicitlyExcludedFileCount)
        Assert-Equal 'file root byte conservation' $expectedBytes ([long]$catalog.catalogedBytes + [long]$catalog.explicitlyExcludedBytes)

        Assert-Throws 'file root sibling enumerator rejected' {
            New-SourceCorpusCatalog -SnapshotId 'fixture-file-root' -SourceId 'android-apk' -SourceKind 'AndroidApk' -RootPath $apkPath -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -FileEnumerator {
                param($path)
                Get-Item -LiteralPath $path -Force
                Get-Item -LiteralPath $siblingPath -Force
            }
        } "File path is outside source root: $siblingPath"

        $counts.fileRootCatalogedFileCount = $catalog.catalogedFileCount
        $counts.fileRootCatalogedBytes = $catalog.catalogedBytes
        $counts.fileRootBoundaryOutcome = 'Passed'
    }
    catch { Add-Issue "FileRoot: $($_.Exception.Message)" }
}
function Invoke-Conservation {
    $root = New-FixtureRoot
    try {
        $exclusion = [pscustomobject][ordered]@{
            sourceId = 'pc-install'
            relativePath = 'known/explicitly-excluded.bin'
            sizeBytes = 3L
            reason = 'Fixture-only explicit exclusion.'
        }
        $catalog = New-SourceCorpusCatalog -SnapshotId 'fixture-snapshot' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -Exclusions @($exclusion)
        $summary = [pscustomobject][ordered]@{
            sourceId = 'pc-install'
            sourceFileCount = [long]$catalog.catalogedFileCount + [long]$catalog.explicitlyExcludedFileCount
            sourceBytes = [long]$catalog.catalogedBytes + [long]$catalog.explicitlyExcludedBytes
            catalogedFileCount = [long]$catalog.catalogedFileCount
            catalogedBytes = [long]$catalog.catalogedBytes
            explicitlyExcludedFileCount = [long]$catalog.explicitlyExcludedFileCount
            explicitlyExcludedBytes = [long]$catalog.explicitlyExcludedBytes
        }
        Assert-PrivateSummary -Summary $summary -Exclusions $catalog.exclusions
        Assert-Equal 'validated exclusion count' 1 $catalog.explicitlyExcludedFileCount
        Assert-Equal 'validated exclusion bytes' 3L $catalog.explicitlyExcludedBytes
        Assert-Equal 'source count conservation' 7L $summary.sourceFileCount
        Assert-Equal 'source byte conservation' ([long]$catalog.catalogedBytes + 3L) $summary.sourceBytes

        $badCount = $summary.PSObject.Copy(); $badCount.catalogedFileCount++
        Assert-Throws 'mutated cataloged count rejected' { Assert-PrivateSummary -Summary $badCount -Exclusions $catalog.exclusions } 'Source catalog conservation failed.'
        $badBytes = $summary.PSObject.Copy(); $badBytes.catalogedBytes++
        Assert-Throws 'mutated cataloged bytes rejected' { Assert-PrivateSummary -Summary $badBytes -Exclusions $catalog.exclusions } 'Source catalog conservation failed.'
        $badExclusion = $exclusion.PSObject.Copy(); $badExclusion.reason = ' '
        Assert-Throws 'mutated exclusion reason rejected' { Assert-PrivateSummary -Summary $summary -Exclusions @($badExclusion) } "Invalid explicit exclusion for sourceId 'pc-install'."

        $largeExclusions = @(
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'large/a.bin'; sizeBytes = 9007199254740992L; reason = 'large fixture' },
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'large/b.bin'; sizeBytes = 1L; reason = 'large fixture' }
        )
        $largeCatalog = New-SourceCorpusCatalog -SnapshotId 'large' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -Exclusions $largeExclusions
        Assert-Equal 'exact Int64 exclusion sum' 9007199254740993L $largeCatalog.explicitlyExcludedBytes
        $overflowExclusions = @(
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'overflow/a.bin'; sizeBytes = [long]::MaxValue; reason = 'overflow fixture' },
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'overflow/b.bin'; sizeBytes = 1L; reason = 'overflow fixture' }
        )
        Assert-Throws 'exclusion total overflow rejected' {
            New-SourceCorpusCatalog -SnapshotId 'overflow' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -Exclusions $overflowExclusions
        } 'Int64 total overflow.'

        $emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-empty-{0}" -f [guid]::NewGuid().ToString('N'))
        $tempRoots.Add($emptyRoot); [System.IO.Directory]::CreateDirectory($emptyRoot) | Out-Null
        $emptyCatalog = New-SourceCorpusCatalog -SnapshotId 'empty' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $emptyRoot -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z')
        Assert-Equal 'empty catalog files' 0 @($emptyCatalog.files).Count
        Assert-Equal 'empty catalog count' 0 $emptyCatalog.catalogedFileCount
        Assert-Equal 'empty catalog bytes' 0L $emptyCatalog.catalogedBytes
    }
    catch { Add-Issue "Conservation: $($_.Exception.Message)" }
}
function Invoke-FailureModes {
    $root = New-FixtureRoot
    try {
        Assert-Throws 'enumeration access failure' {
            New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -FileEnumerator {
                param($path)
                throw [System.UnauthorizedAccessException]::new('denied-fixture')
            }
        } 'Source enumeration failed: denied-fixture'
        Assert-Throws 'source root reparse rejected' {
            Assert-NoReparsePoint -Attributes ([System.IO.FileAttributes]::ReparsePoint) -Label 'Source root'
        } 'Source root is a reparse point.'
        Assert-Throws 'child reparse rejected' {
            Assert-NoReparsePoint -Attributes ([System.IO.FileAttributes]::ReparsePoint) -Label 'child-link'
        } 'child-link is a reparse point.'
        Assert-Throws 'exact duplicate rejected' {
            Assert-UniquePortablePaths -RelativePaths @('a/b.bin', 'a/b.bin')
        } 'Duplicate normalized relative path: a/b.bin'
        Assert-Throws 'case-only collision rejected' {
            Assert-UniquePortablePaths -RelativePaths @('A/b.bin', 'a/b.bin')
        } 'Case-only relative path collision: a/b.bin'

        foreach ($metadataCase in @(
            @{ Name = 'blank snapshot'; SnapshotId = ' '; SourceId = 'pc-install'; SourceKind = 'PcInstall'; Message = 'Invalid snapshotId.' },
            @{ Name = 'NUL snapshot'; SnapshotId = "bad`0snapshot"; SourceId = 'pc-install'; SourceKind = 'PcInstall'; Message = 'Invalid snapshotId.' },
            @{ Name = 'blank source'; SnapshotId = 'fixture'; SourceId = ' '; SourceKind = 'PcInstall'; Message = 'Invalid sourceId.' },
            @{ Name = 'LF source'; SnapshotId = 'fixture'; SourceId = "bad`nsource"; SourceKind = 'PcInstall'; Message = 'Invalid sourceId.' },
            @{ Name = 'unsupported kind'; SnapshotId = 'fixture'; SourceId = 'pc-install'; SourceKind = 'Bogus'; Message = 'Unsupported sourceKind: Bogus' }
        )) {
            Assert-Throws $metadataCase.Name {
                New-SourceCorpusCatalog -SnapshotId $metadataCase.SnapshotId -SourceId $metadataCase.SourceId -SourceKind $metadataCase.SourceKind -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z')
            } $metadataCase.Message
        }
        Assert-Throws 'fabricated enumerator item rejected' {
            New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -FileEnumerator {
                param($path)
                [pscustomobject]@{ FullName = (Join-Path $path 'fabricated.bin'); Attributes = [System.IO.FileAttributes]::Normal; Directory = Get-Item -LiteralPath $path }
            }
        } 'Enumerator item could not be resolved: fabricated.bin'
        Assert-Throws 'directory enumerator item rejected' {
            New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -FileEnumerator {
                param($path)
                Get-Item -LiteralPath (Join-Path $path 'known') -Force
            }
        } 'Enumerator item is not a regular file: known'
        $outsideFile = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-outside-{0}.bin" -f [guid]::NewGuid().ToString('N'))
        [System.IO.File]::WriteAllText($outsideFile, 'outside')
        try {
            Assert-Throws 'outside enumerator item rejected' {
                New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -FileEnumerator {
                    param($path)
                    Get-Item -LiteralPath $outsideFile -Force
                }
            } "File path is outside source root: $outsideFile"
        }
        finally { Remove-Item -LiteralPath $outsideFile -Force }

        $valid = [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'known/excluded.bin'; sizeBytes = 3L; reason = 'fixture' }
        $badSource = $valid.PSObject.Copy(); $badSource.sourceId = 'other'
        $badPath = $valid.PSObject.Copy(); $badPath.relativePath = 'known/../excluded.bin'
        $badSize = $valid.PSObject.Copy(); $badSize.sizeBytes = -1L
        $badReason = $valid.PSObject.Copy(); $badReason.reason = ' '
        $missingSize = [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'known/excluded.bin'; reason = 'fixture' }
        $stringSize = $valid.PSObject.Copy(); $stringSize.sizeBytes = '3'
        $fractionalSize = $valid.PSObject.Copy(); $fractionalSize.sizeBytes = 1.5
        $numericReason = $valid.PSObject.Copy(); $numericReason.reason = 7
        foreach ($entry in @($badSource, $badPath, $badSize, $badReason, $missingSize, $stringSize, $fractionalSize, $numericReason)) {
            Assert-Throws 'invalid exclusion rejected' {
                Assert-ValidSourceExclusions -Exclusions @($entry) -SourceId 'pc-install'
            } "Invalid explicit exclusion for sourceId 'pc-install'."
        }
        $duplicateExclusions = @(
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'excluded/a.bin'; sizeBytes = 1L; reason = 'fixture' },
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'excluded/a.bin'; sizeBytes = 1L; reason = 'fixture' }
        )
        Assert-Throws 'duplicate exclusions rejected' { Assert-ValidSourceExclusions -Exclusions $duplicateExclusions -SourceId 'pc-install' } 'Duplicate normalized relative path: excluded/a.bin'
        $caseExclusions = @(
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'Excluded/a.bin'; sizeBytes = 1L; reason = 'fixture' },
            [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'excluded/a.bin'; sizeBytes = 1L; reason = 'fixture' }
        )
        Assert-Throws 'case-only exclusions rejected' { Assert-ValidSourceExclusions -Exclusions $caseExclusions -SourceId 'pc-install' } 'Case-only relative path collision: excluded/a.bin'
        $overlap = [pscustomobject]@{ sourceId = 'pc-install'; relativePath = 'known/data.unity3d'; sizeBytes = 1L; reason = 'fixture' }
        Assert-Throws 'catalog exclusion overlap rejected' {
            New-SourceCorpusCatalog -SnapshotId 'fixture' -SourceId 'pc-install' -SourceKind 'PcInstall' -RootPath $root -CapturedAt ([datetimeoffset]'2026-07-10T00:00:00Z') -Exclusions @($overlap)
        } 'Explicit exclusion overlaps cataloged relative path: known/data.unity3d'

        $probeIssues = [System.Collections.Generic.List[string]]::new()
        $probeOutcome = Invoke-JunctionAncestorTest -Root $root -IssueSink $probeIssues -JunctionCreator {
            param($path, $target)
            throw 'injected-junction-setup-failure'
        }
        Assert-Equal 'supported junction setup failure outcome' 'Failed: injected-junction-setup-failure' $probeOutcome
        Assert-Equal 'supported junction setup failure issue count' 1 $probeIssues.Count
        $counts.junctionTestOutcome = Invoke-JunctionAncestorTest -Root $root -IssueSink $issues
    }
    catch { Add-Issue "FailureModes: $($_.Exception.Message)" }
}

try {
    if ($Case -in @('AllFile', 'All')) { Invoke-AllFile }
    if ($Case -in @('FileRoot', 'All')) { Invoke-FileRoot }
    if ($Case -in @('Conservation', 'All')) { Invoke-Conservation }
    if ($Case -in @('FailureModes', 'All')) { Invoke-FailureModes }
}
finally {
    foreach ($root in @($tempRoots)) {
        if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
    }
}
$leftovers = @($tempRoots | Where-Object { Test-Path -LiteralPath $_ })
$result = [ordered]@{ status = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }; case = $Case; issueCount = $issues.Count; issues = @($issues); leftoverTempRootCount = $leftovers.Count; counts = $counts }
$result | ConvertTo-Json -Compress -Depth 10
if ($issues.Count -ne 0 -or $leftovers.Count -ne 0) { exit 1 }
