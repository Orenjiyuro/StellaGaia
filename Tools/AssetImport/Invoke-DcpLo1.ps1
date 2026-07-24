Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-DcpLo1 {
    param([Parameter(Mandatory)][string]$Code)
    throw [System.InvalidOperationException]::new("DCPLO1:$Code")
}

function Get-DcpLo1Sha256 {
    param([Parameter(Mandatory)][string]$LiteralPath)
    $stream = [System.IO.File]::Open(
        $LiteralPath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
        $stream.Dispose()
    }
}

function Get-DcpLo1ProductionContract {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $attemptPortableRoot = 'Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1'
    return [pscustomobject][ordered]@{
        candidateId = 'char_14401'
        sourceId = 'pc-install'
        sourceKind = 'PcInstall'
        repositoryRoot = $repositoryRoot
        runnerPortablePath = 'Tools/AssetImport/Invoke-DcpLo1.ps1'
        snapshotPortablePath = 'Extracted/DirectCharacterConsumerProof/char_14401/T1/current-input.json'
        snapshotByteCount = [int64]3231
        snapshotSha256 = '5f3ea3c73d35ed16e1296da5463f870c13cfd61ab0437335f06e86207d3dc9d9'
        sourceRootFingerprint = '24a09d655b009b39c7a54a66c6ed5a07c113ede13c529f471da6f25449fdc644'
        memberCount = 17
        inputByteCount = [int64]117082750
        toolManifestPortablePath = 'Tools/AssetImport/tool-manifest.json'
        toolManifestSha256 = '24e973ded1f9d7c97b8334c82b82e69d6dc227798441d9ffa43bb4a80ec070f9'
        assetRipperLeafName = 'AssetRipper.GUI.Free.exe'
        assetRipperProductName = 'AssetRipper.GUI.Free'
        assetRipperVersion = '1.3.14.0'
        assetRipperByteCount = [int64]124776960
        assetRipperSha256 = '11ec892dcd70b1b86f2e52db631e83e007f6103daa20a9616ecaa7a95baa9f21'
        port = 17777
        attemptPortableRoot = $attemptPortableRoot
        stagingPortableRoot = "$attemptPortableRoot/Input"
        outputPortableRoot = "$attemptPortableRoot/Output"
        logPortablePath = "$attemptPortableRoot/Logs/assetripper.log"
        terminalPortablePath = "$attemptPortableRoot/terminal-result.json"
        stagingTimeoutMilliseconds = [int64]240000
        startupTimeoutMilliseconds = [int64]30000
        loadTimeoutMilliseconds = [int64]300000
        exportTimeoutMilliseconds = [int64]1200000
        shutdownTimeoutMilliseconds = [int64]30000
        overallTimeoutMilliseconds = [int64]1800000
        maxProcessStartCount = 1
        allowedChildProcessCount = 0
        allowedChildProcessIdentities = @(
            [pscustomobject][ordered]@{
                parentRole = 'AssetRipperTopLevel'
                executableName = 'conhost.exe'
                pathAnchor = 'SystemDirectory'
                relativePath = 'conhost.exe'
                byteCount = [int64]1007616
                sha256 = '32e45de7f02912f3907083690043df4abdc4705eea28300719788eaa4a339d0b'
                productName = 'Microsoft® Windows® Operating System'
                fileVersion = '10.0.26100.8875 (WinBuild.160101.0800)'
            }
        )
    }
}

function ConvertTo-DcpLo1AbsolutePath {
    param(
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][string]$PortablePath
    )
    if (
        [string]::IsNullOrWhiteSpace($PortablePath) -or
        $PortablePath.Contains('\') -or
        [System.IO.Path]::IsPathRooted($PortablePath) -or
        $PortablePath -match '(^|/)\.{1,2}(/|$)'
    ) {
        Stop-DcpLo1 'PortablePathInvalid'
    }
    $absolute = [System.IO.Path]::GetFullPath(
        (Join-Path $Contract.repositoryRoot $PortablePath.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
    )
    $root = [System.IO.Path]::GetFullPath([string]$Contract.repositoryRoot).TrimEnd('\', '/')
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        Stop-DcpLo1 'PortablePathEscape'
    }
    return $absolute
}

function Test-DcpLo1Contained {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Leaf
    )
    $canonicalRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $canonicalLeaf = [System.IO.Path]::GetFullPath($Leaf)
    return $canonicalLeaf.StartsWith(
        $canonicalRoot + [System.IO.Path]::DirectorySeparatorChar,
        [System.StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-DcpLo1NoReparseChain {
    param(
        [Parameter(Mandatory)][string]$AbsolutePath,
        [Parameter(Mandatory)][ValidateSet('File', 'Directory')][string]$LeafKind,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $fullPath = [System.IO.Path]::GetFullPath($AbsolutePath)
    $volumeRoot = [System.IO.Path]::GetPathRoot($fullPath)
    $cursor = $volumeRoot
    $rootItem = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($null -eq $rootItem -or ($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
        Stop-DcpLo1 $FailureCode
    }
    $segments = @($fullPath.Substring($volumeRoot.Length).Trim('\', '/') -split '[\\/]' | Where-Object { $_ })
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $cursor = Join-Path $cursor $segments[$index]
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -eq $item -or ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            Stop-DcpLo1 $FailureCode
        }
        $isLeaf = $index -eq ($segments.Count - 1)
        if (-not $isLeaf -and -not $item.PSIsContainer) {
            Stop-DcpLo1 $FailureCode
        }
        if ($isLeaf) {
            if ($LeafKind -ceq 'File' -and ($item.PSIsContainer -or $item -isnot [System.IO.FileInfo])) {
                Stop-DcpLo1 $FailureCode
            }
            if ($LeafKind -ceq 'Directory' -and (-not $item.PSIsContainer -or $item -isnot [System.IO.DirectoryInfo])) {
                Stop-DcpLo1 $FailureCode
            }
        }
    }
}

function Get-DcpLo1SourceRootFingerprint {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$CanonicalSourceRoot
    )
    $payload = ConvertTo-Json -Compress -InputObject (
        [string[]]@(
            'dcp/source-root/1',
            $SourceId,
            $CanonicalSourceRoot.Normalize([System.Text.NormalizationForm]::FormC)
        )
    )
    $bytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($payload)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Get-DcpLo1ExactPropertyNames {
    param([AllowNull()][object]$Value)
    if ($Value -isnot [System.Management.Automation.PSCustomObject]) { return '' }
    return (@($Value.PSObject.Properties.Name) | Sort-Object) -join ','
}

function Test-DcpLo1JsonArrayProperty {
    param(
        [Parameter(Mandatory)][string]$JsonText,
        [Parameter(Mandatory)][string[]]$PropertyPath
    )
    $document = $null
    try {
        $document = [System.Text.Json.JsonDocument]::Parse($JsonText)
        $element = $document.RootElement
        foreach ($propertyName in $PropertyPath) {
            if ($element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { return $false }
            $element = $element.GetProperty($propertyName)
        }
        return $element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $document) { $document.Dispose() }
    }
}

function Get-DcpLo1CanonicalLocalSourceLeaf {
    param(
        [Parameter(Mandatory)][object]$Value,
        [Parameter(Mandatory)][string]$SourceKind,
        [Parameter(Mandatory)][string]$FailureCode
    )
    if (
        $Value -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$Value) -or
        -not [System.IO.Path]::IsPathFullyQualified([string]$Value) -or
        [string]$Value -match '^[\\/]{2}'
    ) {
        Stop-DcpLo1 $FailureCode
    }
    $full = [System.IO.Path]::GetFullPath([string]$Value)
    $expectedLeafKind = if ($SourceKind -ceq 'AndroidApk') { 'File' } else { 'Directory' }
    Assert-DcpLo1NoReparseChain -AbsolutePath $full -LeafKind $expectedLeafKind -FailureCode $FailureCode
    $item = Get-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
    if (
        $null -eq $item -or
        ($expectedLeafKind -ceq 'File' -and ($item -isnot [System.IO.FileInfo] -or $item.PSIsContainer)) -or
        ($expectedLeafKind -ceq 'Directory' -and ($item -isnot [System.IO.DirectoryInfo] -or -not $item.PSIsContainer))
    ) {
        Stop-DcpLo1 $FailureCode
    }
    $canonical = $item.FullName.Normalize([System.Text.NormalizationForm]::FormC)
    if (
        $expectedLeafKind -ceq 'Directory' -and
        -not $canonical.Equals([System.IO.Path]::GetPathRoot($canonical), [System.StringComparison]::OrdinalIgnoreCase)
    ) {
        $canonical = $canonical.TrimEnd('\', '/')
    }
    return $canonical
}

function Get-DcpLo1ValidatedSourceRows {
    param(
        [Parameter(Mandatory)][object[]]$Rows,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $allowedKinds = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    $byId = [System.Collections.Generic.Dictionary[string,object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $Rows) {
        if (
            (Get-DcpLo1ExactPropertyNames $row) -cne 'rootPath,sourceId,sourceKind' -or
            $row.sourceId -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$row.sourceId) -or
            [string]$row.sourceId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
            $row.sourceKind -isnot [string] -or $allowedKinds -cnotcontains [string]$row.sourceKind
        ) {
            Stop-DcpLo1 $FailureCode
        }
        $canonicalRoot = Get-DcpLo1CanonicalLocalSourceLeaf `
            -Value $row.rootPath `
            -SourceKind ([string]$row.sourceKind) `
            -FailureCode $FailureCode
        if ($byId.ContainsKey([string]$row.sourceId)) { Stop-DcpLo1 $FailureCode }
        $byId.Add([string]$row.sourceId, [pscustomobject][ordered]@{
            sourceId = [string]$row.sourceId
            sourceKind = [string]$row.sourceKind
            canonicalRoot = $canonicalRoot
        })
    }
    if ($byId.Count -eq 0) { Stop-DcpLo1 $FailureCode }
    return $byId
}

function Resolve-DcpLo1SourceRootFromLocator {
    param(
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][string]$LocatorPath
    )
    Assert-DcpLo1NoReparseChain -AbsolutePath $locatorPath -LeafKind File -FailureCode 'SourceBindingFailure'
    try {
        $locatorRaw = [System.IO.File]::ReadAllText($locatorPath)
        $locator = $locatorRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    if (
        (Get-DcpLo1ExactPropertyNames $locator) -cne 'baseline,manifestPath,schemaVersion,sourceBoundary' -or
        $locator.schemaVersion -cne '1.0.0' -or
        $locator.manifestPath -isnot [string] -or
        (Get-DcpLo1ExactPropertyNames $locator.baseline) -cne 'disposition,path' -or
        (Get-DcpLo1ExactPropertyNames $locator.sourceBoundary) -cne 'schemaVersion,sources' -or
        $locator.sourceBoundary.schemaVersion -cne '1.0.0' -or
        -not (Test-DcpLo1JsonArrayProperty -JsonText $locatorRaw -PropertyPath @('sourceBoundary', 'sources')) -or
        @($locator.sourceBoundary.sources).Count -eq 0
    ) {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    if ($locator.baseline.disposition -ceq 'Absent') {
        if ($null -ne $locator.baseline.path) { Stop-DcpLo1 'SourceBindingFailure' }
    }
    elseif ($locator.baseline.disposition -ceq 'Present') {
        if (
            $locator.baseline.path -isnot [string] -or
            -not [System.IO.Path]::IsPathFullyQualified([string]$locator.baseline.path) -or
            [string]$locator.baseline.path -match '^[\\/]{2}'
        ) {
            Stop-DcpLo1 'SourceBindingFailure'
        }
        Assert-DcpLo1NoReparseChain -AbsolutePath ([string]$locator.baseline.path) -LeafKind File -FailureCode 'SourceBindingFailure'
    }
    else {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    $manifestPath = [string]$locator.manifestPath
    if (-not [System.IO.Path]::IsPathFullyQualified($manifestPath) -or $manifestPath -match '^[\\/]{2}') {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    Assert-DcpLo1NoReparseChain -AbsolutePath $manifestPath -LeafKind File -FailureCode 'SourceBindingFailure'
    try {
        $manifestRaw = [System.IO.File]::ReadAllText($manifestPath)
        $manifest = $manifestRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    if (
        (Get-DcpLo1ExactPropertyNames $manifest) -cne 'schemaVersion,sources' -or
        $manifest.schemaVersion -cne '1.0.0' -or
        -not (Test-DcpLo1JsonArrayProperty -JsonText $manifestRaw -PropertyPath @('sources')) -or
        @($manifest.sources).Count -eq 0
    ) {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    $boundary = Get-DcpLo1ValidatedSourceRows -Rows @($locator.sourceBoundary.sources) -FailureCode 'SourceBindingFailure'
    $manifestRows = Get-DcpLo1ValidatedSourceRows -Rows @($manifest.sources) -FailureCode 'SourceBindingFailure'
    if ($boundary.Count -ne $manifestRows.Count) { Stop-DcpLo1 'SourceBindingFailure' }
    foreach ($sourceId in $boundary.Keys) {
        if (-not $manifestRows.ContainsKey($sourceId)) { Stop-DcpLo1 'SourceBindingFailure' }
        $left = $boundary[$sourceId]
        $right = $manifestRows[$sourceId]
        if (
            $left.sourceId -cne $right.sourceId -or
            $left.sourceKind -cne $right.sourceKind -or
            -not $left.canonicalRoot.Equals($right.canonicalRoot, [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            Stop-DcpLo1 'SourceBindingFailure'
        }
    }
    if (-not $manifestRows.ContainsKey([string]$Contract.sourceId)) { Stop-DcpLo1 'SourceBindingFailure' }
    $selected = $manifestRows[[string]$Contract.sourceId]
    if ($selected.sourceId -cne $Contract.sourceId -or $selected.sourceKind -cne $Contract.sourceKind) {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    $canonical = [string]$selected.canonicalRoot
    if ((Get-DcpLo1SourceRootFingerprint -SourceId $Contract.sourceId -CanonicalSourceRoot $canonical) -cne $Contract.sourceRootFingerprint) {
        Stop-DcpLo1 'SourceBindingFailure'
    }
    return $canonical
}

function Resolve-DcpLo1SourceRoot {
    param([Parameter(Mandatory)][object]$Contract)
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) { Stop-DcpLo1 'SourceBindingFailure' }
    $locatorPath = Join-Path $localAppData 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
    return Resolve-DcpLo1SourceRootFromLocator -Contract $Contract -LocatorPath $locatorPath
}

function Assert-DcpLo1PeIdentity {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][object]$Contract
    )
    Assert-DcpLo1NoReparseChain -AbsolutePath $LiteralPath -LeafKind File -FailureCode 'ToolIdentityFailure'
    $item = Get-Item -LiteralPath $LiteralPath -Force
    if (
        $item.Name -cne $Contract.assetRipperLeafName -or
        $item.VersionInfo.ProductName -cne $Contract.assetRipperProductName -or
        $item.VersionInfo.FileVersion -cne $Contract.assetRipperVersion -or
        [int64]$item.Length -ne [int64]$Contract.assetRipperByteCount -or
        (Get-DcpLo1Sha256 $item.FullName) -cne $Contract.assetRipperSha256
    ) {
        Stop-DcpLo1 'ToolIdentityFailure'
    }
    $stream = [System.IO.File]::Open($item.FullName, 'Open', 'Read', 'Read')
    try {
        if ($stream.Length -lt 68 -or $stream.ReadByte() -ne 0x4d -or $stream.ReadByte() -ne 0x5a) {
            Stop-DcpLo1 'ToolIdentityFailure'
        }
        $stream.Position = 0x3c
        $offsetBytes = [byte[]]::new(4)
        if ($stream.Read($offsetBytes, 0, 4) -ne 4) { Stop-DcpLo1 'ToolIdentityFailure' }
        $peOffset = [System.BitConverter]::ToInt32($offsetBytes, 0)
        if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 4)) { Stop-DcpLo1 'ToolIdentityFailure' }
        $stream.Position = $peOffset
        $signature = [byte[]]::new(4)
        if (
            $stream.Read($signature, 0, 4) -ne 4 -or
            $signature[0] -ne 0x50 -or $signature[1] -ne 0x45 -or
            $signature[2] -ne 0 -or $signature[3] -ne 0
        ) {
            Stop-DcpLo1 'ToolIdentityFailure'
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Resolve-DcpLo1AssetRipper {
    param([Parameter(Mandatory)][object]$Contract)
    $manifestPath = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.toolManifestPortablePath
    Assert-DcpLo1NoReparseChain -AbsolutePath $manifestPath -LeafKind File -FailureCode 'ToolIdentityFailure'
    if (
        -not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
        (Get-DcpLo1Sha256 $manifestPath) -cne $Contract.toolManifestSha256
    ) {
        Stop-DcpLo1 'ToolIdentityFailure'
    }
    try {
        $manifest = [System.IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -Depth 20
    }
    catch {
        Stop-DcpLo1 'ToolIdentityFailure'
    }
    if (
        [string]::IsNullOrWhiteSpace([string]$manifest.assetRipper) -or
        [int]$manifest.assetRipperPort -ne [int]$Contract.port
    ) {
        Stop-DcpLo1 'ToolIdentityFailure'
    }
    $assetRipperPath = [System.IO.Path]::GetFullPath([string]$manifest.assetRipper)
    Assert-DcpLo1PeIdentity -LiteralPath $assetRipperPath -Contract $Contract
    return $assetRipperPath
}

function Read-DcpLo1Snapshot {
    param([Parameter(Mandatory)][object]$Contract)
    $path = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.snapshotPortablePath
    Assert-DcpLo1NoReparseChain -AbsolutePath $path -LeafKind File -FailureCode 'SnapshotIdentityFailure'
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (
        $null -eq $item -or $item -isnot [System.IO.FileInfo] -or
        [int64]$item.Length -ne [int64]$Contract.snapshotByteCount -or
        (Get-DcpLo1Sha256 $path) -cne $Contract.snapshotSha256
    ) {
        Stop-DcpLo1 'SnapshotIdentityFailure'
    }
    try {
        $snapshot = [System.IO.File]::ReadAllText($path) | ConvertFrom-Json -Depth 20 -DateKind String
    }
    catch {
        Stop-DcpLo1 'SnapshotIdentityFailure'
    }
    if (
        (Get-DcpLo1ExactPropertyNames $snapshot) -cne 'candidateId,inputBytes,memberCount,members,schemaVersion,sourceRootFingerprint,status' -or
        $snapshot.schemaVersion -cne 'dcp-source-snapshot/1.0.0' -or
        $snapshot.candidateId -cne $Contract.candidateId -or
        $snapshot.sourceRootFingerprint -cne $Contract.sourceRootFingerprint -or
        $snapshot.status -cne 'SnapshotComplete' -or
        [int]$snapshot.memberCount -ne [int]$Contract.memberCount -or
        [int64]$snapshot.inputBytes -ne [int64]$Contract.inputByteCount -or
        @($snapshot.members).Count -ne [int]$Contract.memberCount
    ) {
        Stop-DcpLo1 'SnapshotIdentityFailure'
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $sum = 0L
    foreach ($member in @($snapshot.members)) {
        if (
            (Get-DcpLo1ExactPropertyNames $member) -cne 'length,relativePath,sha256' -or
            $member.relativePath -isnot [string] -or
            $member.relativePath.Contains('\') -or
            [System.IO.Path]::IsPathRooted([string]$member.relativePath) -or
            [string]$member.relativePath -match '(^|/)\.{1,2}(/|$)' -or
            -not $seen.Add([string]$member.relativePath) -or
            [int64]$member.length -lt 0 -or
            [string]$member.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            [int64]$member.length -gt ([int64]::MaxValue - $sum)
        ) {
            Stop-DcpLo1 'SnapshotIdentityFailure'
        }
        $sum += [int64]$member.length
    }
    if ($sum -ne [int64]$Contract.inputByteCount) { Stop-DcpLo1 'SnapshotIdentityFailure' }
    return $snapshot
}

function Assert-DcpLo1Deadline {
    param(
        [Parameter(Mandatory)][scriptblock]$Clock,
        [Parameter(Mandatory)][long]$StartedAt,
        [Parameter(Mandatory)][long]$LimitMilliseconds,
        [Parameter(Mandatory)][string]$FailureCode
    )
    $now = [int64](& $Clock)
    if ($now -lt $StartedAt -or ($now - $StartedAt) -gt $LimitMilliseconds) {
        Stop-DcpLo1 $FailureCode
    }
}

function Copy-DcpLo1Members {
    param(
        [Parameter(Mandatory)][object]$Snapshot,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][object]$Metrics,
        [Parameter(Mandatory)][scriptblock]$Clock,
        [Parameter(Mandatory)][long]$OperationStartedAt,
        [Parameter(Mandatory)][object]$Contract
    )
    $metadata = [System.Collections.Generic.List[object]]::new()
    $metadataTotal = 0L
    foreach ($member in @($Snapshot.members)) {
        $relative = [string]$member.relativePath
        $sourceLeaf = [System.IO.Path]::GetFullPath(
            (Join-Path $SourceRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        )
        if (-not (Test-DcpLo1Contained -Root $SourceRoot -Leaf $sourceLeaf)) {
            Stop-DcpLo1 'StagingMemberMismatch'
        }
        Assert-DcpLo1NoReparseChain -AbsolutePath $sourceLeaf -LeafKind File -FailureCode 'StagingMemberMismatch'
        $item = Get-Item -LiteralPath $sourceLeaf -Force
        if ([int64]$item.Length -ne [int64]$member.length) { Stop-DcpLo1 'StagingMemberMismatch' }
        $metadataTotal += [int64]$item.Length
        $metadata.Add([pscustomobject][ordered]@{
            member = $member
            sourceLeaf = $sourceLeaf
            destinationLeaf = [System.IO.Path]::GetFullPath(
                (Join-Path $StagingRoot $relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
            )
        })
    }
    if ($metadata.Count -ne [int]$Contract.memberCount -or $metadataTotal -ne [int64]$Contract.inputByteCount) {
        Stop-DcpLo1 'StagingConservationFailure'
    }
    [System.IO.Directory]::CreateDirectory($StagingRoot) | Out-Null
    $stagingStartedAt = [int64](& $Clock)
    $buffer = [byte[]]::new(1048576)
    foreach ($row in $metadata) {
        Assert-DcpLo1Deadline -Clock $Clock -StartedAt $OperationStartedAt -LimitMilliseconds $Contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
        Assert-DcpLo1Deadline -Clock $Clock -StartedAt $stagingStartedAt -LimitMilliseconds $Contract.stagingTimeoutMilliseconds -FailureCode 'StagingTimeout'
        if (-not (Test-DcpLo1Contained -Root $StagingRoot -Leaf $row.destinationLeaf)) {
            Stop-DcpLo1 'StagingMemberMismatch'
        }
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($row.destinationLeaf)) | Out-Null
        if (Test-Path -LiteralPath $row.destinationLeaf) { Stop-DcpLo1 'StagingMemberMismatch' }
        $sourceStream = $null
        $destinationStream = $null
        $hash = $null
        try {
            $sourceStream = [System.IO.File]::Open($row.sourceLeaf, 'Open', 'Read', 'Read')
            $Metrics.sourceContentOpenCount++
            if ([int64]$sourceStream.Length -ne [int64]$row.member.length) {
                Stop-DcpLo1 'StagingMemberMismatch'
            }
            $destinationStream = [System.IO.File]::Open($row.destinationLeaf, 'CreateNew', 'Write', 'None')
            $hash = [System.Security.Cryptography.IncrementalHash]::CreateHash(
                [System.Security.Cryptography.HashAlgorithmName]::SHA256
            )
            $count = 0L
            while (($read = $sourceStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $destinationStream.Write($buffer, 0, $read)
                $hash.AppendData($buffer, 0, $read)
                $count += $read
                if ($count -gt [int64]$row.member.length) { Stop-DcpLo1 'StagingMemberMismatch' }
                Assert-DcpLo1Deadline -Clock $Clock -StartedAt $OperationStartedAt -LimitMilliseconds $Contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
            }
            $destinationStream.Flush($true)
            $digest = [System.Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
            if (
                $count -ne [int64]$row.member.length -or
                $digest -cne [string]$row.member.sha256 -or
                $sourceStream.Position -ne [int64]$row.member.length -or
                $sourceStream.Length -ne [int64]$row.member.length
            ) {
                Stop-DcpLo1 'StagingMemberMismatch'
            }
            $Metrics.stagedMemberCount++
            $Metrics.stagedBytes += $count
        }
        finally {
            if ($null -ne $hash) { $hash.Dispose() }
            if ($null -ne $destinationStream) { $destinationStream.Dispose() }
            if ($null -ne $sourceStream) { $sourceStream.Dispose() }
        }
    }
    if (
        $Metrics.sourceContentOpenCount -ne [int]$Contract.memberCount -or
        $Metrics.stagedMemberCount -ne [int]$Contract.memberCount -or
        $Metrics.stagedBytes -ne [int64]$Contract.inputByteCount
    ) {
        Stop-DcpLo1 'StagingConservationFailure'
    }
}

function Assert-DcpLo1Staging {
    param(
        [Parameter(Mandatory)][object]$Snapshot,
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][object]$Contract
    )
    Assert-DcpLo1NoReparseChain -AbsolutePath $StagingRoot -LeafKind Directory -FailureCode 'StagingIntegrityFailure'
    $leaves = @(Get-ChildItem -LiteralPath $StagingRoot -Recurse -File -Force)
    if ($leaves.Count -ne [int]$Contract.memberCount) { Stop-DcpLo1 'StagingIntegrityFailure' }
    $expected = @{}
    foreach ($member in @($Snapshot.members)) { $expected[[string]$member.relativePath] = $member }
    $sum = 0L
    foreach ($leaf in $leaves) {
        Assert-DcpLo1NoReparseChain -AbsolutePath $leaf.FullName -LeafKind File -FailureCode 'StagingIntegrityFailure'
        $relative = [System.IO.Path]::GetRelativePath($StagingRoot, $leaf.FullName).Replace('\', '/')
        if (-not $expected.ContainsKey($relative)) { Stop-DcpLo1 'StagingIntegrityFailure' }
        $member = $expected[$relative]
        if (
            [int64]$leaf.Length -ne [int64]$member.length -or
            (Get-DcpLo1Sha256 $leaf.FullName) -cne [string]$member.sha256
        ) {
            Stop-DcpLo1 'StagingIntegrityFailure'
        }
        $sum += [int64]$leaf.Length
    }
    if ($sum -ne [int64]$Contract.inputByteCount) { Stop-DcpLo1 'StagingIntegrityFailure' }
}

function Get-DcpLo1StagingInventoryIdentity {
    param([Parameter(Mandatory)][object]$Snapshot)
    $rows = @(
        foreach ($member in @($Snapshot.members)) {
            ,@([string]$member.relativePath, [int64]$member.length, [string]$member.sha256)
        }
    )
    $payload = ConvertTo-Json -Compress -Depth 5 -InputObject (
        ,@('dcp/lo1/staging-inventory/1', $rows)
    )
    $bytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($payload)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Assert-DcpLo1ExportedProject {
    param([Parameter(Mandatory)][string]$OutputRoot)
    Assert-DcpLo1NoReparseChain -AbsolutePath $OutputRoot -LeafKind Directory -FailureCode 'OutputMissingOrInvalid'
    $projectRoot = Join-Path $OutputRoot 'ExportedProject'
    $assetsRoot = Join-Path $projectRoot 'Assets'
    foreach ($required in @(
        $projectRoot,
        $assetsRoot,
        (Join-Path $projectRoot 'Packages'),
        (Join-Path $projectRoot 'ProjectSettings')
    )) {
        Assert-DcpLo1NoReparseChain -AbsolutePath $required -LeafKind Directory -FailureCode 'OutputMissingOrInvalid'
    }
    $entries = @(Get-ChildItem -LiteralPath $OutputRoot -Recurse -Force)
    foreach ($entry in $entries) {
        if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            Stop-DcpLo1 'OutputMissingOrInvalid'
        }
    }
    $files = @($entries | Where-Object { $_ -is [System.IO.FileInfo] })
    $assetPayloads = @(Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -Force |
        Where-Object { $_.Extension -ine '.meta' })
    if ($assetPayloads.Count -eq 0) { Stop-DcpLo1 'OutputMissingOrInvalid' }
    $bytes = 0L
    foreach ($file in $files) { $bytes += [int64]$file.Length }
    return [pscustomobject][ordered]@{
        outputFileCount = $files.Count
        outputBytes = $bytes
    }
}

function Test-DcpLo1PortFree {
    param([Parameter(Mandatory)][int]$Port)
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    return $listeners.Count -eq 0
}

function Get-DcpLo1ChildProcessRecords {
    param([Parameter(Mandatory)][int]$ParentProcessId)
    try {
        return @(
            Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentProcessId" -ErrorAction Stop |
                ForEach-Object {
                    [pscustomobject][ordered]@{
                        processId = [int]$_.ProcessId
                        parentProcessId = [int]$_.ParentProcessId
                        executablePath = [string]$_.ExecutablePath
                    }
                }
        )
    }
    catch {
        Stop-DcpLo1 'ChildProcessInspectionFailure'
    }
}

function Get-DcpLo1ChildProcessIdentity {
    param(
        [Parameter(Mandatory)][object]$ChildRecord,
        [Parameter(Mandatory)][int]$ExpectedParentProcessId,
        [Parameter(Mandatory)][string]$AssetRipperPath
    )
    if (
        [int]$ChildRecord.parentProcessId -ne $ExpectedParentProcessId -or
        [string]::IsNullOrWhiteSpace([string]$ChildRecord.executablePath)
    ) {
        Stop-DcpLo1 'ChildProcessInspectionFailure'
    }
    $executablePath = [System.IO.Path]::GetFullPath([string]$ChildRecord.executablePath)
    if (
        -not [System.IO.Path]::IsPathFullyQualified($executablePath) -or
        $executablePath -match '^[\\/]{2}'
    ) {
        Stop-DcpLo1 'ChildProcessInspectionFailure'
    }
    Assert-DcpLo1NoReparseChain -AbsolutePath $executablePath -LeafKind File -FailureCode 'ChildProcessInspectionFailure'
    $anchors = [ordered]@{
        AssetRipperDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($AssetRipperPath))
        SystemDirectory = [Environment]::SystemDirectory
        WindowsDirectory = [Environment]::GetFolderPath('Windows')
        ProgramFiles = [Environment]::GetFolderPath('ProgramFiles')
        ProgramFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
        LocalApplicationData = [Environment]::GetFolderPath('LocalApplicationData')
    }
    $pathAnchor = $null
    $relativePath = $null
    foreach ($entry in $anchors.GetEnumerator()) {
        if (
            -not [string]::IsNullOrWhiteSpace([string]$entry.Value) -and
            (Test-DcpLo1Contained -Root ([string]$entry.Value) -Leaf $executablePath)
        ) {
            $pathAnchor = [string]$entry.Key
            $relativePath = [System.IO.Path]::GetRelativePath([string]$entry.Value, $executablePath).Replace('\', '/')
            break
        }
    }
    if ($null -eq $pathAnchor -or [string]::IsNullOrWhiteSpace($relativePath)) {
        Stop-DcpLo1 'ChildProcessInspectionFailure'
    }
    $item = Get-Item -LiteralPath $executablePath -Force
    return [pscustomobject][ordered]@{
        processId = [int]$ChildRecord.processId
        parentProcessId = [int]$ChildRecord.parentProcessId
        parentRole = 'AssetRipperTopLevel'
        executableName = [string]$item.Name
        pathAnchor = $pathAnchor
        relativePath = $relativePath
        byteCount = [int64]$item.Length
        sha256 = Get-DcpLo1Sha256 $item.FullName
        productName = [string]$item.VersionInfo.ProductName
        fileVersion = [string]$item.VersionInfo.FileVersion
    }
}

function Test-DcpLo1ChildProcessIdentityAllowed {
    param(
        [Parameter(Mandatory)][object]$Identity,
        [Parameter(Mandatory)][object[]]$Whitelist
    )
    foreach ($allowed in $Whitelist) {
        if (
            $Identity.parentRole -ceq $allowed.parentRole -and
            $Identity.executableName -ceq $allowed.executableName -and
            $Identity.pathAnchor -ceq $allowed.pathAnchor -and
            $Identity.relativePath -ceq $allowed.relativePath -and
            [int64]$Identity.byteCount -eq [int64]$allowed.byteCount -and
            $Identity.sha256 -ceq $allowed.sha256 -and
            $Identity.productName -ceq $allowed.productName -and
            $Identity.fileVersion -ceq $allowed.fileVersion
        ) {
            return $true
        }
    }
    return $false
}

function Update-DcpLo1ChildProcessEvidence {
    param(
        [Parameter(Mandatory)][object]$Process,
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[int]]$UnauthorizedChildren
    )
    foreach ($record in @(Get-DcpLo1ChildProcessRecords -ParentProcessId $Process.Id)) {
        try {
            $identity = Get-DcpLo1ChildProcessIdentity `
                -ChildRecord $record `
                -ExpectedParentProcessId $Process.Id `
                -AssetRipperPath $Context.assetRipperPath
        }
        catch {
            if ([string]$_.Exception.Message -ceq 'DCPLO1:ChildProcessInspectionFailure') { throw }
            Stop-DcpLo1 'ChildProcessInspectionFailure'
        }
        if (-not $Context.processFacts.observedChildProcessIds.Add([int]$identity.processId)) {
            continue
        }
        $Context.processFacts.childProcessIdentities.Add($identity)
        if (-not (Test-DcpLo1ChildProcessIdentityAllowed `
            -Identity $identity `
            -Whitelist @($Context.contract.allowedChildProcessIdentities))) {
            [void]$UnauthorizedChildren.Add([int]$identity.processId)
        }
    }
}

function Assert-DcpLo1ListenerOwned {
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][int]$ProcessId
    )
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) { return $false }
    foreach ($listener in $listeners) {
        if ([int]$listener.OwningProcess -ne $ProcessId) {
            Stop-DcpLo1 'ListenerOwnershipFailure'
        }
    }
    return $true
}

function Assert-DcpLo1ProcessBoundary {
    param(
        [Parameter(Mandatory)][object]$Process,
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[int]]$UnauthorizedChildren
    )
    if ($Process.HasExited) { Stop-DcpLo1 'AssetRipperExitedUnexpectedly' }
    Update-DcpLo1ChildProcessEvidence -Process $Process -Context $Context -UnauthorizedChildren $UnauthorizedChildren
    if ($UnauthorizedChildren.Count -gt [int]$Context.contract.allowedChildProcessCount) {
        Stop-DcpLo1 'UnexpectedChildProcess'
    }
    if (-not (Assert-DcpLo1ListenerOwned -Port $Context.contract.port -ProcessId $Process.Id)) {
        Stop-DcpLo1 'ListenerOwnershipFailure'
    }
}

function Set-DcpLo1HttpStatusOrFail {
    param(
        [Parameter(Mandatory)][object]$ProcessFacts,
        [Parameter(Mandatory)][ValidateSet('Load', 'Export')][string]$StageName,
        [Parameter(Mandatory)][int]$StatusCode,
        [Parameter(Mandatory)][bool]$IsSuccessStatusCode
    )
    if ($StageName -ceq 'Load') {
        $ProcessFacts.loadHttpStatus = $StatusCode
    }
    else {
        $ProcessFacts.exportHttpStatus = $StatusCode
    }
    if (-not $IsSuccessStatusCode) { Stop-DcpLo1 "AssetRipper$($StageName)Failure" }
}

function Test-DcpLo1HttpPreservedFailure {
    param([Parameter(Mandatory)][string]$Message)
    return $Message -cmatch '^DCPLO1:(OverallTimeout|ChildProcessInspectionFailure|UnexpectedChildProcess|ListenerOwnershipFailure|AssetRipperExitedUnexpectedly|CleanupIncomplete|AssetRipper(Load|Export)(Timeout|Failure))$'
}

function Invoke-DcpLo1HttpPost {
    param(
        [Parameter(Mandatory)][object]$Process,
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Body,
        [Parameter(Mandatory)][ValidateSet('Load', 'Export')][string]$StageName,
        [Parameter(Mandatory)][long]$StageTimeoutMilliseconds,
        [Parameter(Mandatory)][System.Collections.Generic.HashSet[int]]$UnauthorizedChildren
    )
    $client = [System.Net.Http.HttpClient]::new()
    $content = $null
    try {
        $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
        $pairs = [System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]]::new()
        foreach ($key in $Body.Keys) {
            $pairs.Add([System.Collections.Generic.KeyValuePair[string,string]]::new([string]$key, [string]$Body[$key]))
        }
        $content = [System.Net.Http.FormUrlEncodedContent]::new($pairs)
        $task = $client.PostAsync($Uri, $content)
        $stageStartedAt = [int64](& $Context.clock)
        while (-not $task.Wait(100)) {
            Assert-DcpLo1Deadline -Clock $Context.clock -StartedAt $Context.operationStartedAt -LimitMilliseconds $Context.contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
            Assert-DcpLo1Deadline -Clock $Context.clock -StartedAt $stageStartedAt -LimitMilliseconds $StageTimeoutMilliseconds -FailureCode "AssetRipper$($StageName)Timeout"
            Assert-DcpLo1ProcessBoundary -Process $Process -Context $Context -UnauthorizedChildren $UnauthorizedChildren
        }
        $response = $task.GetAwaiter().GetResult()
        try {
            $statusCode = [int]$response.StatusCode
            Set-DcpLo1HttpStatusOrFail `
                -ProcessFacts $Context.processFacts `
                -StageName $StageName `
                -StatusCode $statusCode `
                -IsSuccessStatusCode ([bool]$response.IsSuccessStatusCode)
        }
        finally {
            $response.Dispose()
        }
        Assert-DcpLo1ProcessBoundary -Process $Process -Context $Context -UnauthorizedChildren $UnauthorizedChildren
        return $statusCode
    }
    catch {
        $message = [string]$_.Exception.Message
        if (Test-DcpLo1HttpPreservedFailure -Message $message) {
            throw
        }
        Stop-DcpLo1 "AssetRipper$($StageName)Failure"
    }
    finally {
        if ($null -ne $content) { $content.Dispose() }
        $client.Dispose()
    }
}

function Invoke-DcpLo1AssetRipperProcess {
    param([Parameter(Mandatory)][object]$Context)
    $process = $null
    $listenerOwned = $false
    $unauthorizedChildren = [System.Collections.Generic.HashSet[int]]::new()
    try {
        $arguments = @(
            '--headless=true',
            '--port', [string]$Context.contract.port,
            '--log=true',
            '--log-path', $Context.logPath
        )
        try {
            $process = Start-Process -FilePath $Context.assetRipperPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
        }
        catch {
            Stop-DcpLo1 'AssetRipperStartFailure'
        }
        $Context.processFacts.processStartCount = 1
        $startupStartedAt = [int64](& $Context.clock)
        while (-not $listenerOwned) {
            Assert-DcpLo1Deadline -Clock $Context.clock -StartedAt $Context.operationStartedAt -LimitMilliseconds $Context.contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
            Assert-DcpLo1Deadline -Clock $Context.clock -StartedAt $startupStartedAt -LimitMilliseconds $Context.contract.startupTimeoutMilliseconds -FailureCode 'AssetRipperStartFailure'
            if ($process.HasExited) { Stop-DcpLo1 'AssetRipperStartFailure' }
            Update-DcpLo1ChildProcessEvidence -Process $process -Context $Context -UnauthorizedChildren $unauthorizedChildren
            if ($unauthorizedChildren.Count -gt [int]$Context.contract.allowedChildProcessCount) {
                Stop-DcpLo1 'UnexpectedChildProcess'
            }
            $listenerOwned = Assert-DcpLo1ListenerOwned -Port $Context.contract.port -ProcessId $process.Id
            if (-not $listenerOwned) { Start-Sleep -Milliseconds 100 }
        }
        $Context.processFacts.listenerOwnedDuringRun = $true
        $baseUrl = "http://127.0.0.1:$($Context.contract.port)"
        $Context.processFacts.loadHttpStatus = Invoke-DcpLo1HttpPost -Process $process -Context $Context -Uri "$baseUrl/LoadFolder" -Body @{
            Path = $Context.stagingRoot
        } -StageName Load -StageTimeoutMilliseconds $Context.contract.loadTimeoutMilliseconds -UnauthorizedChildren $unauthorizedChildren
        $Context.processFacts.exportHttpStatus = Invoke-DcpLo1HttpPost -Process $process -Context $Context -Uri "$baseUrl/Export/UnityProject" -Body @{
            Path = $Context.outputRoot
            CreateSubfolder = 'false'
        } -StageName Export -StageTimeoutMilliseconds $Context.contract.exportTimeoutMilliseconds -UnauthorizedChildren $unauthorizedChildren
    }
    finally {
        $Context.processFacts.unauthorizedChildProcessCount = $unauthorizedChildren.Count
        if ($null -ne $process) {
            $Context.processFacts.shutdownAttempted = $true
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
                [void]$process.WaitForExit([int]$Context.contract.shutdownTimeoutMilliseconds)
            }
            $Context.processFacts.shutdownProcessExited = [bool]$process.HasExited
            $Context.processFacts.listenerAbsentAfterShutdown = Test-DcpLo1PortFree -Port $Context.contract.port
            if (
                -not $Context.processFacts.shutdownProcessExited -or
                -not $Context.processFacts.listenerAbsentAfterShutdown
            ) {
                Stop-DcpLo1 'CleanupIncomplete'
            }
        }
    }
    $diagnosticCount = 0
    if (Test-Path -LiteralPath $Context.logPath -PathType Leaf) {
        $diagnosticCount = @(
            Select-String -LiteralPath $Context.logPath -Pattern "Dependency .*wasn't found" -CaseSensitive:$false
        ).Count
    }
    return [pscustomobject][ordered]@{
        listenerOwned = $listenerOwned
        unauthorizedChildProcessCount = $unauthorizedChildren.Count
        classification = if ($diagnosticCount -gt 0) { 'ExportedWithDiagnostics' } else { 'Exported' }
    }
}

function Write-DcpLo1TerminalResult {
    param(
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][object]$Result
    )
    $path = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.terminalPortablePath
    $temporary = $path + '.tmp'
    if ((Test-Path -LiteralPath $path) -or (Test-Path -LiteralPath $temporary)) {
        Stop-DcpLo1 'TerminalResultAlreadyExists'
    }
    $json = $Result | ConvertTo-Json -Depth 10 -Compress
    if ($json -match '[A-Za-z]:\\') { Stop-DcpLo1 'PrivatePathLeak' }
    $bytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($json)
    $stream = [System.IO.File]::Open($temporary, 'CreateNew', 'Write', 'None')
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
    [System.IO.File]::Move($temporary, $path, $false)
}

function Invoke-DcpLo1Core {
    param(
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][scriptblock]$SourceRootResolver,
        [Parameter(Mandatory)][scriptblock]$AssetRipperResolver,
        [Parameter(Mandatory)][scriptblock]$PortProbe,
        [Parameter(Mandatory)][scriptblock]$ProcessAdapter,
        [Parameter(Mandatory)][scriptblock]$Clock
    )
    $attemptRoot = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.attemptPortableRoot
    $stagingRoot = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.stagingPortableRoot
    $outputRoot = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.outputPortableRoot
    $logPath = ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.logPortablePath
    if (Test-Path -LiteralPath $attemptRoot) { Stop-DcpLo1 'AttemptAlreadyExists' }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($logPath)) | Out-Null
    $operationStartedAt = [int64](& $Clock)
    $runnerPath = if ($Contract.PSObject.Properties.Name -ccontains 'runnerIdentityPath') {
        [string]$Contract.runnerIdentityPath
    }
    else {
        ConvertTo-DcpLo1AbsolutePath -Contract $Contract -PortablePath $Contract.runnerPortablePath
    }
    Assert-DcpLo1NoReparseChain -AbsolutePath $runnerPath -LeafKind File -FailureCode 'RunnerIdentityFailure'
    $runnerSha256 = Get-DcpLo1Sha256 $runnerPath
    $metrics = [pscustomobject][ordered]@{
        sourceContentOpenCount = 0
        stagedMemberCount = 0
        stagedBytes = 0L
        outputFileCount = 0
        outputBytes = 0L
    }
    $processFacts = [pscustomobject][ordered]@{
        processStartCount = 0
        unauthorizedChildProcessCount = 0
        listenerOwnedDuringRun = $false
        loadHttpStatus = $null
        exportHttpStatus = $null
        shutdownAttempted = $false
        shutdownProcessExited = $false
        listenerAbsentAfterShutdown = $false
        observedChildProcessIds = [System.Collections.Generic.HashSet[int]]::new()
        childProcessIdentities = [System.Collections.Generic.List[object]]::new()
    }
    $classification = 'UnexpectedFailure'
    $status = 'Failed'
    $stagingInventoryIdentity = $null
    try {
        $snapshot = Read-DcpLo1Snapshot -Contract $Contract
        $sourceRoot = & $SourceRootResolver $Contract
        $assetRipperPath = & $AssetRipperResolver $Contract
        if (-not (& $PortProbe $Contract.port)) { Stop-DcpLo1 'PortOccupied' }
        Assert-DcpLo1Deadline -Clock $Clock -StartedAt $operationStartedAt -LimitMilliseconds $Contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
        Copy-DcpLo1Members -Snapshot $snapshot -SourceRoot $sourceRoot -StagingRoot $stagingRoot -Metrics $metrics -Clock $Clock -OperationStartedAt $operationStartedAt -Contract $Contract
        Assert-DcpLo1Staging -Snapshot $snapshot -StagingRoot $stagingRoot -Contract $Contract
        $stagingInventoryIdentity = Get-DcpLo1StagingInventoryIdentity -Snapshot $snapshot
        [System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
        $processResult = & $ProcessAdapter ([pscustomobject][ordered]@{
            contract = $Contract
            assetRipperPath = $assetRipperPath
            stagingRoot = $stagingRoot
            outputRoot = $outputRoot
            logPath = $logPath
            operationStartedAt = $operationStartedAt
            clock = $Clock
            processFacts = $processFacts
        })
        if ([int]$processFacts.processStartCount -ne 1) { Stop-DcpLo1 'AssetRipperStartFailure' }
        if (-not [bool]$processResult.listenerOwned) { Stop-DcpLo1 'ListenerOwnershipFailure' }
        if ([int]$processResult.unauthorizedChildProcessCount -gt [int]$Contract.allowedChildProcessCount) {
            Stop-DcpLo1 'UnexpectedChildProcess'
        }
        $processFacts.unauthorizedChildProcessCount = [int]$processResult.unauthorizedChildProcessCount
        $outputFacts = Assert-DcpLo1ExportedProject -OutputRoot $outputRoot
        $metrics.outputFileCount = [int]$outputFacts.outputFileCount
        $metrics.outputBytes = [int64]$outputFacts.outputBytes
        $classification = [string]$processResult.classification
        if ($classification -cnotin @('Exported', 'ExportedWithDiagnostics')) {
            Stop-DcpLo1 'OutputMissingOrInvalid'
        }
        Assert-DcpLo1Deadline -Clock $Clock -StartedAt $operationStartedAt -LimitMilliseconds $Contract.overallTimeoutMilliseconds -FailureCode 'OverallTimeout'
        $status = $classification
    }
    catch {
        $message = [string]$_.Exception.Message
        $classification = if ($message -cmatch '^DCPLO1:([A-Za-z0-9]+)$') { $Matches[1] } else { 'UnexpectedFailure' }
    }
    $elapsed = [int64](& $Clock) - $operationStartedAt
    if ($elapsed -lt 0) { $elapsed = 0 }
    $result = [pscustomobject][ordered]@{
        schemaVersion = 'dcp-lo1-terminal-result/1.0.0'
        status = $status
        classification = $classification
        candidateId = $Contract.candidateId
        runnerSha256 = $runnerSha256
        snapshotSha256 = $Contract.snapshotSha256
        toolManifestSha256 = $Contract.toolManifestSha256
        assetRipperSha256 = $Contract.assetRipperSha256
        sourceRootFingerprint = $Contract.sourceRootFingerprint
        stagingInventoryIdentity = $stagingInventoryIdentity
        processStartCount = $processFacts.processStartCount
        unauthorizedChildProcessCount = $processFacts.unauthorizedChildProcessCount
        childProcessIdentities = $processFacts.childProcessIdentities.ToArray()
        sourceContentOpenCount = $metrics.sourceContentOpenCount
        stagedMemberCount = $metrics.stagedMemberCount
        stagedBytes = $metrics.stagedBytes
        outputFileCount = $metrics.outputFileCount
        outputBytes = $metrics.outputBytes
        loadHttpStatus = $processFacts.loadHttpStatus
        exportHttpStatus = $processFacts.exportHttpStatus
        listenerOwnedDuringRun = $processFacts.listenerOwnedDuringRun
        shutdownAttempted = $processFacts.shutdownAttempted
        shutdownProcessExited = $processFacts.shutdownProcessExited
        listenerAbsentAfterShutdown = $processFacts.listenerAbsentAfterShutdown
        evidencePreserved = $true
        stagingPresent = (Test-Path -LiteralPath $stagingRoot)
        outputPresent = (Test-Path -LiteralPath $outputRoot)
        portableLogPath = $Contract.logPortablePath
        elapsedMilliseconds = $elapsed
        roleAcceptanceClaimed = $false
        nextAction = 'AwaitDcpLo1Audit'
    }
    Write-DcpLo1TerminalResult -Contract $Contract -Result $result
    return $result
}

function Invoke-DcpLo1Production {
    $contract = Get-DcpLo1ProductionContract
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $clock = { [int64]$stopwatch.ElapsedMilliseconds }
    return Invoke-DcpLo1Core `
        -Contract $contract `
        -SourceRootResolver { param($boundContract) Resolve-DcpLo1SourceRoot $boundContract } `
        -AssetRipperResolver { param($boundContract) Resolve-DcpLo1AssetRipper $boundContract } `
        -PortProbe { param($port) Test-DcpLo1PortFree $port } `
        -ProcessAdapter { param($context) Invoke-DcpLo1AssetRipperProcess $context } `
        -Clock $clock
}

if ($MyInvocation.InvocationName -cne '.') {
    try {
        if ($args.Count -ne 0) { Stop-DcpLo1 'UnexpectedArguments' }
        $terminal = Invoke-DcpLo1Production
        $terminal | ConvertTo-Json -Depth 10 -Compress
        if ($terminal.status -cnotin @('Exported', 'ExportedWithDiagnostics')) { exit 1 }
    }
    catch {
        $message = [string]$_.Exception.Message
        $safeCode = if ($message -cmatch '^DCPLO1:[A-Za-z0-9]+$') { $message } else { 'DCPLO1:UnexpectedFailure' }
        [pscustomobject][ordered]@{
            status = 'Failed'
            classification = $safeCode.Substring(7)
            processStartCount = $null
            processStartCountState = 'Unknown'
            evidenceComplete = $false
            nextAction = 'AwaitDcpLo1Audit'
        } | ConvertTo-Json -Compress
        exit 1
    }
}
