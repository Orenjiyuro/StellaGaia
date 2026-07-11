[CmdletBinding()]
param(
    [ValidateSet('Primitive', 'Root', 'Input', 'All')]
    [string]$Case = 'All'
)

$modulePath = Join-Path $PSScriptRoot 'SourceCorpusGate.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "Missing module: $modulePath"
}
Import-Module $modulePath -Force
$ErrorActionPreference = 'Stop'

$issues = [System.Collections.Generic.List[string]]::new()
$tempRoots = [System.Collections.Generic.List[string]]::new()

function Add-TestIssue {
    param([Parameter(Mandatory)][string]$Message)
    $issues.Add($Message)
}

function Assert-TestEqual {
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][object]$Expected,
        [AllowNull()][object]$Actual
    )
    if ($Expected -cne $Actual) {
        Add-TestIssue "$Name expected '$Expected', got '$Actual'."
    }
}

function Assert-TestBytesEqual {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][byte[]]$Expected,
        [Parameter(Mandatory)][byte[]]$Actual
    )
    $equal = $Expected.Length -eq $Actual.Length
    for ($index = 0; $equal -and $index -lt $Expected.Length; $index++) {
        $equal = $Expected[$index] -eq $Actual[$index]
    }
    if (-not $equal) {
        Add-TestIssue "$Name bytes differ."
    }
}

function Assert-TestThrows {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][scriptblock]$Action,
        [string]$ExpectedMessage
    )
    try {
        & $Action | Out-Null
        Add-TestIssue "$Name did not throw."
    }
    catch {
        if ($ExpectedMessage -and $_.Exception.Message -cne $ExpectedMessage) {
            Add-TestIssue "$Name threw '$($_.Exception.Message)', expected '$ExpectedMessage'."
        }
    }
}

function Invoke-PrimitiveTests {
    $fileSha = 'a' * 64
    $rootFingerprint = 'b' * 64
    $expectedFileBytes = [byte[]]@(
        100, 105, 114, 47, 97, 46, 116, 120, 116, 0, 51, 0
    ) + [System.Linq.Enumerable]::Repeat([byte][char]'a', 64).ToArray() + [byte[]]@(10)
    $expectedSourceBytes = [byte[]]@(
        112, 99, 45, 105, 110, 115, 116, 97, 108, 108, 0,
        80, 99, 73, 110, 115, 116, 97, 108, 108, 0
    ) + [System.Linq.Enumerable]::Repeat([byte][char]'b', 64).ToArray() + [byte[]]@(10)

    $json = '{"Exact":7}' | ConvertFrom-Json
    Assert-TestEqual 'exact JSON property' 7 (Get-ExactJsonPropertyByPath -Value $json -Path 'Exact')
    Assert-TestEqual 'case-sensitive JSON property' $null (Get-ExactJsonPropertyByPath -Value $json -Path 'exact')
    Assert-TestEqual 'missing JSON property' $null (Get-ExactJsonPropertyByPath -Value $json -Path 'Missing')
    Assert-TestEqual 'non-object JSON traversal' $null (Get-ExactJsonPropertyByPath -Value 7 -Path 'value')

    $portableRoot = Join-Path ([System.IO.Path]::GetTempPath()) 'portable-root'
    $portableFile = Join-Path $portableRoot 'dir\a.txt'
    Assert-TestEqual 'portable relative path' 'dir/a.txt' (ConvertTo-PortableRelativePath -RootPath $portableRoot -FilePath $portableFile)
    $tempFilePath = [System.IO.Path]::GetTempFileName()
    try {
        $fileSystemRoot = [System.IO.Path]::GetPathRoot($tempFilePath)
        $expectedFromFileSystemRoot = [System.IO.Path]::GetRelativePath($fileSystemRoot, $tempFilePath).Replace('\', '/')
        Assert-TestEqual 'filesystem root relative path' $expectedFromFileSystemRoot (
            ConvertTo-PortableRelativePath -RootPath $fileSystemRoot -FilePath $tempFilePath
        )
    }
    finally {
        Remove-Item -LiteralPath $tempFilePath -Force
    }
    Assert-TestThrows 'outside root rejected' {
        ConvertTo-PortableRelativePath -RootPath $portableRoot -FilePath (Join-Path ([System.IO.Path]::GetTempPath()) 'outside.txt')
    }
    Assert-TestThrows 'exact duplicate rejected' {
        Assert-UniquePortablePaths -RelativePaths @('a.txt', 'a.txt')
    } 'Duplicate normalized relative path: a.txt'
    Assert-TestThrows 'case-only collision rejected' {
        Assert-UniquePortablePaths -RelativePaths @('a.txt', 'A.txt')
    } 'Case-only relative path collision: A.txt'

    Assert-TestEqual 'lowercase SHA-256' 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' (
        Get-LowercaseSha256 -Bytes ([System.Text.Encoding]::UTF8.GetBytes('abc'))
    )
    Assert-TestBytesEqual 'canonical file record' $expectedFileBytes (
        New-CanonicalFileRecordBytes -RelativePath 'dir/a.txt' -SizeBytes 3 -Sha256 $fileSha
    )
    foreach ($invalidPath in @('', ' ', "bad`0path", "bad`rpath", "bad`npath", 'dir\a.txt', 'dir//a.txt', 'dir/', '/absolute.txt', 'C:/absolute.txt', 'https://example.test/a', './a.txt', 'dir/../a.txt')) {
        Assert-TestThrows "invalid canonical path '$invalidPath' rejected" {
            New-CanonicalFileRecordBytes -RelativePath $invalidPath -SizeBytes 3 -Sha256 $fileSha
        }
    }
    Assert-TestThrows 'negative canonical size rejected' {
        New-CanonicalFileRecordBytes -RelativePath 'a.txt' -SizeBytes -1 -Sha256 $fileSha
    }
    Assert-TestBytesEqual 'canonical source record' $expectedSourceBytes (
        New-CanonicalSourceRecordBytes -SourceId 'pc-install' -SourceKind 'PcInstall' -RootFingerprint $rootFingerprint
    )
    Assert-TestThrows 'invalid sourceId rejected' {
        New-CanonicalSourceRecordBytes -SourceId "bad`0id" -SourceKind 'PcInstall' -RootFingerprint $rootFingerprint
    } 'sourceId must be non-empty and must not contain NUL, CR, or LF.'
}

function New-TestFileRecord {
    param(
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][string]$FilePath
    )
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    return [pscustomobject]@{
        relativePath = ConvertTo-PortableRelativePath -RootPath $RootPath -FilePath $FilePath
        sizeBytes = [long]$bytes.Length
        sha256 = Get-LowercaseSha256 -Bytes $bytes
    }
}

function Invoke-RootTests {
    $rootOne = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-root-{0}" -f [guid]::NewGuid().ToString('N'))
    $rootTwo = Join-Path ([System.IO.Path]::GetTempPath()) ("stella-c1-root-{0}" -f [guid]::NewGuid().ToString('N'))
    $tempRoots.Add($rootOne)
    $tempRoots.Add($rootTwo)
    try {
        [System.IO.Directory]::CreateDirectory((Join-Path $rootOne 'sub')) | Out-Null
        [System.IO.Directory]::CreateDirectory((Join-Path $rootTwo 'sub')) | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $rootOne 'a.txt'), [byte[]]@(65))
        [System.IO.File]::WriteAllBytes((Join-Path $rootOne 'sub\b.txt'), [byte[]]@(66, 67))
        [System.IO.File]::WriteAllBytes((Join-Path $rootTwo 'sub\b.txt'), [byte[]]@(66, 67))
        [System.IO.File]::WriteAllBytes((Join-Path $rootTwo 'a.txt'), [byte[]]@(65))

        $filesOne = @(
            New-TestFileRecord -RootPath $rootOne -FilePath (Join-Path $rootOne 'a.txt')
            New-TestFileRecord -RootPath $rootOne -FilePath (Join-Path $rootOne 'sub\b.txt')
        )
        $filesTwo = @(
            New-TestFileRecord -RootPath $rootTwo -FilePath (Join-Path $rootTwo 'sub\b.txt')
            New-TestFileRecord -RootPath $rootTwo -FilePath (Join-Path $rootTwo 'a.txt')
        )
        $fingerprintOne = Get-SourceRootFingerprint -Files $filesOne
        $fingerprintTwo = Get-SourceRootFingerprint -Files $filesTwo
        Assert-TestEqual 'root fingerprint order independence' $fingerprintOne $fingerprintTwo
        Assert-TestEqual 'exact root fingerprint' '89c79f0dec017674d6e71a2064bd9fc709ee862787c716628a4c22294822ffdc' $fingerprintOne

        [System.IO.File]::WriteAllBytes((Join-Path $rootTwo 'a.txt'), [byte[]]@(90))
        $mutatedFiles = @(
            New-TestFileRecord -RootPath $rootTwo -FilePath (Join-Path $rootTwo 'sub\b.txt')
            New-TestFileRecord -RootPath $rootTwo -FilePath (Join-Path $rootTwo 'a.txt')
        )
        $mutatedFingerprint = Get-SourceRootFingerprint -Files $mutatedFiles
        if ($mutatedFingerprint -ceq $fingerprintOne) {
            Add-TestIssue 'one-byte mutation did not change root fingerprint.'
        }
        foreach ($invalidFile in @(
            [pscustomobject]@{ relativePath = "bad`0path"; sizeBytes = 1L; sha256 = 'a' * 64 },
            [pscustomobject]@{ relativePath = 'dir\a.txt'; sizeBytes = 1L; sha256 = 'a' * 64 },
            [pscustomobject]@{ relativePath = 'a.txt'; sizeBytes = -1L; sha256 = 'a' * 64 }
        )) {
            Assert-TestThrows 'invalid root file record rejected' {
                Get-SourceRootFingerprint -Files @($invalidFile)
            }
        }
    }
    finally {
        foreach ($root in @($rootOne, $rootTwo)) {
            if (Test-Path -LiteralPath $root) {
                Remove-Item -LiteralPath $root -Recurse -Force
            }
        }
    }
}

function Invoke-InputTests {
    $pc = [pscustomobject]@{
        sourceId = 'pc-install'
        sourceKind = 'PcInstall'
        rootFingerprint = 'b' * 64
    }
    $android = [pscustomobject]@{
        sourceId = 'android-data'
        sourceKind = 'AndroidDataOrCache'
        rootFingerprint = 'c' * 64
    }
    $forward = Get-SourceInputFingerprint -Sources @($pc, $android)
    $reverse = Get-SourceInputFingerprint -Sources @($android, $pc)
    Assert-TestEqual 'input fingerprint order independence' $forward $reverse
    Assert-TestEqual 'exact input fingerprint' '500e12e5a8a6d78aed65bbefdfa91eb9545297e527794a06fd27178e6c7d81e8' $forward

    Assert-TestThrows 'duplicate sourceId rejected' {
        Get-SourceInputFingerprint -Sources @($pc, $pc)
    } 'Invalid or duplicate sourceId: pc-install'
    foreach ($invalidCharacter in @([char]0, [char]13, [char]10)) {
        $invalidSource = [pscustomobject]@{
            sourceId = 'bad' + $invalidCharacter + 'id'
            sourceKind = 'PcInstall'
            rootFingerprint = 'b' * 64
        }
        Assert-TestThrows 'invalid sourceId character rejected' {
            Get-SourceInputFingerprint -Sources @($invalidSource)
        }
    }
    $invalidKind = [pscustomobject]@{
        sourceId = 'invalid-kind'
        sourceKind = 'pcinstall'
        rootFingerprint = 'b' * 64
    }
    Assert-TestThrows 'invalid sourceKind rejected' {
        Get-SourceInputFingerprint -Sources @($invalidKind)
    } 'Unsupported sourceKind: pcinstall'
    $uppercaseFingerprint = [pscustomobject]@{
        sourceId = 'uppercase-fingerprint'
        sourceKind = 'PcInstall'
        rootFingerprint = 'B' * 64
    }
    Assert-TestThrows 'uppercase root fingerprint rejected' {
        Get-SourceInputFingerprint -Sources @($uppercaseFingerprint)
    } "Invalid rootFingerprint for sourceId 'uppercase-fingerprint'."
}

if ($Case -in @('Primitive', 'All')) {
    Invoke-PrimitiveTests
}
if ($Case -in @('Root', 'All')) {
    Invoke-RootTests
}
if ($Case -in @('Input', 'All')) {
    Invoke-InputTests
}

$leftoverTempRoots = @($tempRoots | Where-Object { Test-Path -LiteralPath $_ })
$result = [ordered]@{
    status = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    case = $Case
    issueCount = $issues.Count
    issues = @($issues)
    leftoverTempRootCount = $leftoverTempRoots.Count
    leftoverTempRoots = @($leftoverTempRoots)
}
$result | ConvertTo-Json -Compress -Depth 10
if ($issues.Count -ne 0) {
    exit 1
}
