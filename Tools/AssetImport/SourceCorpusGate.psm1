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
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Assert-UniquePortablePaths {
    param([Parameter(Mandatory)][string[]]$RelativePaths)
    $ordinal = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $ignoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $RelativePaths) {
        if (-not $ordinal.Add($path)) { throw "Duplicate normalized relative path: $path" }
        if (-not $ignoreCase.Add($path)) { throw "Case-only relative path collision: $path" }
    }
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

Export-ModuleMember -Function @(
    'Get-ExactJsonPropertyByPath',
    'ConvertTo-PortableRelativePath',
    'Get-LowercaseSha256',
    'Assert-UniquePortablePaths',
    'New-CanonicalFileRecordBytes',
    'New-CanonicalSourceRecordBytes',
    'Get-SourceRootFingerprint',
    'Get-SourceInputFingerprint'
)
