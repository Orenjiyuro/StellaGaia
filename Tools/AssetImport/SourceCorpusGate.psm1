function Get-ExactJsonPropertyByPath {
    param([AllowNull()][object]$Value, [Parameter(Mandatory)][string]$Path)
    $current = $Value
    foreach ($segment in $Path.Split('.')) {
        if ($current -isnot [System.Management.Automation.PSCustomObject]) { return $null }
        $match = @($current.PSObject.Properties | Where-Object Name -CEQ $segment)
        if ($match.Count -ne 1) { return $null }
        $current = $match[0].Value
    }
    return $current
}

function ConvertTo-PortableRelativePath {
    param([Parameter(Mandatory)][string]$RootPath, [Parameter(Mandatory)][string]$FilePath)
    $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
    $fileSystemRoot = [System.IO.Path]::GetPathRoot($fullRoot)
    $root = if ($fullRoot.Equals($fileSystemRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $fileSystemRoot
    }
    else {
        $fullRoot.TrimEnd('\', '/')
    }
    $file = [System.IO.Path]::GetFullPath($FilePath)
    $prefix = if ($root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $root
    }
    else {
        $root + [System.IO.Path]::DirectorySeparatorChar
    }
    if (-not $file.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File path is outside source root: $FilePath"
    }
    $relative = [System.IO.Path]::GetRelativePath($root, $file).Replace('\', '/')
    if (
        [string]::IsNullOrWhiteSpace($relative) -or
        [System.IO.Path]::IsPathRooted($relative) -or
        $relative -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
        $relative -match '(^|/)\.{1,2}(/|$)'
    ) {
        throw "Invalid portable relative path: $relative"
    }
    return $relative
}

function Get-LowercaseSha256 {
    param([Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$Bytes)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Assert-UniquePortablePaths {
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$RelativePaths)
    $ordinal = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $ignoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $RelativePaths) {
        if (-not $ordinal.Add($path)) { throw "Duplicate normalized relative path: $path" }
        if (-not $ignoreCase.Add($path)) { throw "Case-only relative path collision: $path" }
    }
}

function Assert-CanonicalCatalogMetadata {
    param([string]$SnapshotId, [string]$SourceId, [string]$SourceKind)
    if ([string]::IsNullOrWhiteSpace($SnapshotId) -or $SnapshotId -match "[\x00\r\n]") {
        throw 'Invalid snapshotId.'
    }
    if ([string]::IsNullOrWhiteSpace($SourceId) -or $SourceId -match "[\x00\r\n]") {
        throw 'Invalid sourceId.'
    }
    if ($SourceKind -cnotin @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')) {
        throw "Unsupported sourceKind: $SourceKind"
    }
}

function Assert-NoReparsePointPathChain {
    param([Parameter(Mandatory)][string]$Path)
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $current = [System.IO.Path]::GetPathRoot($fullPath)
    $rootItem = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    Assert-NoReparsePoint -Attributes $rootItem.Attributes -Label $rootItem.FullName.TrimEnd('\', '/')
    $remainder = $fullPath.Substring($current.Length).Trim('\', '/')
    foreach ($segment in @($remainder -split '[\\/]' | Where-Object { $_ })) {
        $current = Join-Path $current $segment
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        Assert-NoReparsePoint -Attributes $item.Attributes -Label $item.FullName
    }
}

function Get-StreamedFileRecord {
    param([Parameter(Mandatory)][System.IO.FileInfo]$File)
    # Frozen local roots are trusted; FileShare.Read blocks cooperating writers, but path validation and open cannot atomically prevent a malicious path-swap TOCTOU.
    $stream = [System.IO.FileStream]::new(
        $File.FullName,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read
    )
    $hash = [System.Security.Cryptography.SHA256]::Create()
    try {
        $sizeBytes = $stream.Length
        $hashBytes = $hash.ComputeHash($stream)
        if ($stream.Position -ne $sizeBytes) { throw "File changed while hashing: $($File.FullName)" }
        return [pscustomobject][ordered]@{
            sizeBytes = [long]$sizeBytes
            sha256 = [System.Convert]::ToHexString($hashBytes).ToLowerInvariant()
        }
    }
    finally {
        $hash.Dispose()
        $stream.Dispose()
    }
}

function Get-CheckedInt64Total {
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Values)
    $total = 0L
    foreach ($value in $Values) {
        $number = [long]$value
        if ($number -lt 0 -or $number -gt ([long]::MaxValue - $total)) { throw 'Int64 total overflow.' }
        $total += $number
    }
    return $total
}

function New-CanonicalFileRecordBytes {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][long]$SizeBytes,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$Sha256
    )
    if (
        [string]::IsNullOrWhiteSpace($RelativePath) -or
        $RelativePath -match "[\x00\r\n]" -or
        $RelativePath.Contains('\') -or
        $RelativePath.Contains('//') -or
        $RelativePath.EndsWith('/') -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
        $RelativePath -match '(^|/)\.{1,2}(/|$)'
    ) {
        throw "Invalid canonical relative path: $RelativePath"
    }
    if ($SizeBytes -lt 0) {
        throw "Invalid canonical sizeBytes: $SizeBytes"
    }
    $sizeText = $SizeBytes.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $record = $RelativePath + [char]0 + $sizeText + [char]0 + $Sha256 + [char]10
    return [System.Text.UTF8Encoding]::new($false, $true).GetBytes($record)
}

function New-CanonicalSourceRecordBytes {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourceKind,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$RootFingerprint
    )
    if ([string]::IsNullOrWhiteSpace($SourceId) -or $SourceId -match "[\x00\r\n]") {
        throw 'sourceId must be non-empty and must not contain NUL, CR, or LF.'
    }
    $record = $SourceId + [char]0 + $SourceKind + [char]0 + $RootFingerprint + [char]10
    return [System.Text.UTF8Encoding]::new($false, $true).GetBytes($record)
}

function Get-SourceRootFingerprint {
    param([Parameter(Mandatory)][object[]]$Files)
    $ordered = [object[]]$Files.Clone()
    $comparison = [System.Comparison[object]]{
        param($left, $right)
        [System.StringComparer]::Ordinal.Compare(
            [string]$left.relativePath,
            [string]$right.relativePath
        )
    }
    [System.Array]::Sort($ordered, $comparison)
    Assert-UniquePortablePaths -RelativePaths @($ordered | ForEach-Object relativePath)
    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($file in $ordered) {
            $record = New-CanonicalFileRecordBytes -RelativePath $file.relativePath -SizeBytes $file.sizeBytes -Sha256 $file.sha256
            $stream.Write($record, 0, $record.Length)
        }
        return Get-LowercaseSha256 -Bytes $stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-SourceInputFingerprint {
    param([Parameter(Mandatory)][object[]]$Sources)
    $allowedKinds = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($source in $Sources) {
        if (
            [string]::IsNullOrWhiteSpace([string]$source.sourceId) -or
            [string]$source.sourceId -match "[\x00\r\n]" -or
            -not $seen.Add([string]$source.sourceId)
        ) {
            throw "Invalid or duplicate sourceId: $($source.sourceId)"
        }
        if ([string]$source.sourceKind -cnotin $allowedKinds) {
            throw "Unsupported sourceKind: $($source.sourceKind)"
        }
        if ([string]$source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$') {
            throw "Invalid rootFingerprint for sourceId '$($source.sourceId)'."
        }
    }
    $ordered = [object[]]$Sources.Clone()
    $comparison = [System.Comparison[object]]{
        param($left, $right)
        [System.StringComparer]::Ordinal.Compare([string]$left.sourceId, [string]$right.sourceId)
    }
    [System.Array]::Sort($ordered, $comparison)
    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($source in $ordered) {
            $record = New-CanonicalSourceRecordBytes -SourceId $source.sourceId -SourceKind $source.sourceKind -RootFingerprint $source.rootFingerprint
            $stream.Write($record, 0, $record.Length)
        }
        return Get-LowercaseSha256 -Bytes $stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}

function Assert-NoReparsePoint {
    param([System.IO.FileAttributes]$Attributes, [Parameter(Mandatory)][string]$Label)
    if (($Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label is a reparse point."
    }
}

function Get-SourceContainerKind {
    param([Parameter(Mandatory)][string]$RelativePath)
    switch ([System.IO.Path]::GetExtension($RelativePath).ToLowerInvariant()) {
        '.unity3d' { return 'UnityBundle' }
        '.bundle' { return 'UnityBundle' }
        '.assets' { return 'UnitySerializedAsset' }
        '.wem' { return 'DirectAudio' }
        '.bnk' { return 'AudioMetadata' }
        '.mp4' { return 'DirectVideo' }
        '.srt' { return 'Metadata' }
        '.json' { return 'ConfigurationCandidate' }
        default { return 'UnknownInput' }
    }
}

function Assert-ValidSourceExclusions {
    param([object[]]$Exclusions = @(), [Parameter(Mandatory)][string]$SourceId)
    foreach ($exclusion in @($Exclusions)) {
        $valid = $null -ne $exclusion
        foreach ($requiredProperty in @('sourceId', 'relativePath', 'sizeBytes', 'reason')) {
            if (@($exclusion.PSObject.Properties | Where-Object Name -CEQ $requiredProperty).Count -ne 1) {
                $valid = $false
            }
        }
        if (
            $exclusion.sourceId -isnot [string] -or
            $exclusion.relativePath -isnot [string] -or
            $exclusion.reason -isnot [string] -or
            $null -eq $exclusion.sizeBytes -or
            $exclusion.sizeBytes.GetType() -notin @(
                [byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64]
            )
        ) { $valid = $false }
        $relativePath = [string]$exclusion.relativePath
        $sizeBytes = 0L
        try { $sizeBytes = [long]$exclusion.sizeBytes }
        catch { $valid = $false }
        if (
            [string]$exclusion.sourceId -cne $SourceId -or
            [string]::IsNullOrWhiteSpace($relativePath) -or
            $relativePath -match "[\x00\r\n]" -or
            $relativePath.Contains('\') -or
            $relativePath.Contains('//') -or
            $relativePath.EndsWith('/') -or
            [System.IO.Path]::IsPathRooted($relativePath) -or
            $relativePath -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
            $relativePath -match '(^|/)\.{1,2}(/|$)' -or
            $sizeBytes -lt 0 -or
            [string]::IsNullOrWhiteSpace([string]$exclusion.reason)
        ) { $valid = $false }
        if (-not $valid) { throw "Invalid explicit exclusion for sourceId '$SourceId'." }
    }
    Assert-UniquePortablePaths -RelativePaths @($Exclusions | ForEach-Object { [string]$_.relativePath })
    return @($Exclusions)
}

function New-SourceCorpusCatalog {
    param(
        [Parameter(Mandatory)][string]$SnapshotId,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourceKind,
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][datetimeoffset]$CapturedAt,
        [object[]]$Exclusions = @(),
        [scriptblock]$FileEnumerator = {
            param($path)
            Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop
        }
    )
    Assert-CanonicalCatalogMetadata -SnapshotId $SnapshotId -SourceId $SourceId -SourceKind $SourceKind
    # Validate the trusted local root's complete reparse chain before opening files; path-based APIs cannot make validation and open one atomic operation.
    Assert-NoReparsePointPathChain -Path $RootPath
    $rootItem = Get-Item -LiteralPath $RootPath -Force -ErrorAction Stop
    Assert-NoReparsePoint -Attributes $rootItem.Attributes -Label 'Source root'
    try { $items = @(& $FileEnumerator $rootItem.FullName) }
    catch { throw "Source enumeration failed: $($_.Exception.Message)" }

    $portablePaths = [System.Collections.Generic.List[string]]::new()
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($enumeratedItem in $items) {
        $enumeratedPath = [string]$enumeratedItem.FullName
        try { $item = Get-Item -LiteralPath $enumeratedPath -Force -ErrorAction Stop }
        catch { throw "Enumerator item could not be resolved: $([System.IO.Path]::GetFileName($enumeratedPath))" }
        if ($item -isnot [System.IO.FileInfo] -or $item.PSIsContainer) {
            throw "Enumerator item is not a regular file: $([System.IO.Path]::GetFileName($enumeratedPath))"
        }
        Assert-NoReparsePoint -Attributes $item.Attributes -Label $item.FullName
        $relativePath = ConvertTo-PortableRelativePath -RootPath $rootItem.FullName -FilePath $item.FullName
        $parent = $item.Directory
        while ($null -ne $parent) {
            if ($parent.FullName.Equals($rootItem.FullName, [System.StringComparison]::OrdinalIgnoreCase)) { break }
            Assert-NoReparsePoint -Attributes $parent.Attributes -Label $parent.FullName
            $parent = $parent.Parent
        }
        if ($null -eq $parent) { throw "File path is outside source root: $($item.FullName)" }
        $portablePaths.Add($relativePath)
        $fileRecord = Get-StreamedFileRecord -File $item
        $rows.Add([pscustomobject][ordered]@{
            snapshotId = $SnapshotId
            sourceId = $SourceId
            sourceKind = $SourceKind
            relativePath = $relativePath
            sizeBytes = $fileRecord.sizeBytes
            sha256 = $fileRecord.sha256
            capturedAt = $CapturedAt.ToUniversalTime().ToString('O')
            containerKind = Get-SourceContainerKind -RelativePath $relativePath
            parseStatus = 'NotAttempted'
            disposition = 'RetainForLater'
            evidence = @()
            status = [pscustomobject][ordered]@{
                corpus = 'Cataloged'
                extraction = 'NotAttempted'
                semantics = 'Unknown'
                unity = 'NotTested'
                disposition = 'RetainForLater'
            }
        })
    }
    Assert-UniquePortablePaths -RelativePaths $portablePaths.ToArray()
    $validatedExclusions = Assert-ValidSourceExclusions -Exclusions $Exclusions -SourceId $SourceId
    $catalogedCaseInsensitive = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $portablePaths) { $catalogedCaseInsensitive.Add($path) | Out-Null }
    foreach ($exclusion in $validatedExclusions) {
        if ($catalogedCaseInsensitive.Contains([string]$exclusion.relativePath)) {
            throw "Explicit exclusion overlaps cataloged relative path: $($exclusion.relativePath)"
        }
    }
    return [pscustomobject][ordered]@{
        files = $rows.ToArray()
        exclusions = $validatedExclusions
        catalogedFileCount = $rows.Count
        catalogedBytes = Get-CheckedInt64Total -Values @($rows | ForEach-Object sizeBytes)
        explicitlyExcludedFileCount = $validatedExclusions.Count
        explicitlyExcludedBytes = Get-CheckedInt64Total -Values @($validatedExclusions | ForEach-Object sizeBytes)
    }
}

Export-ModuleMember -Function @(
    'Get-ExactJsonPropertyByPath',
    'ConvertTo-PortableRelativePath',
    'Get-LowercaseSha256',
    'Assert-UniquePortablePaths',
    'New-CanonicalFileRecordBytes',
    'New-CanonicalSourceRecordBytes',
    'Get-SourceRootFingerprint',
    'Get-SourceInputFingerprint',
    'New-SourceCorpusCatalog',
    'Assert-NoReparsePoint',
    'Assert-ValidSourceExclusions',
    'Get-SourceContainerKind'
)
