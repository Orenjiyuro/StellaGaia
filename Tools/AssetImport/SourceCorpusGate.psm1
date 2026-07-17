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
    $rootIsFile = $rootItem -is [System.IO.FileInfo] -and -not $rootItem.PSIsContainer
    $rootIsDirectory = $rootItem -is [System.IO.DirectoryInfo] -and $rootItem.PSIsContainer
    if (-not $rootIsFile -and -not $rootIsDirectory) {
        throw 'Source root is not a regular file or directory.'
    }
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
        if ($rootIsFile) {
            if (-not $item.FullName.Equals($rootItem.FullName, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "File path is outside source root: $($item.FullName)"
            }
            $relativePath = $rootItem.Name.Replace('\', '/')
            if (
                [string]::IsNullOrWhiteSpace($relativePath) -or
                [System.IO.Path]::IsPathRooted($relativePath) -or
                $relativePath -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
                $relativePath -match '(^|/)\.{1,2}(/|$)'
            ) {
                throw "Invalid portable relative path: $relativePath"
            }
        }
        else {
            $relativePath = ConvertTo-PortableRelativePath -RootPath $rootItem.FullName -FilePath $item.FullName
            $parent = $item.Directory
            while ($null -ne $parent) {
                if ($parent.FullName.Equals($rootItem.FullName, [System.StringComparison]::OrdinalIgnoreCase)) { break }
                Assert-NoReparsePoint -Attributes $parent.Attributes -Label $parent.FullName
                $parent = $parent.Parent
            }
            if ($null -eq $parent) { throw "File path is outside source root: $($item.FullName)" }
        }
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

function Assert-C1OutputPathPolicy {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$ThreadId,
        [object[]]$ExistingPathAttributes = @()
    )
    if ($ThreadId -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') { throw "Invalid ThreadId: $ThreadId" }
    $expected = [System.IO.Path]::GetFullPath((Join-Path $RepositoryRoot "Extracted\Threads\$ThreadId\C1"))
    $actual = [System.IO.Path]::GetFullPath($OutputRoot)
    if (-not $actual.Equals($expected, [System.StringComparison]::OrdinalIgnoreCase)) { throw "OutputRoot must equal $expected." }
    foreach ($item in @($ExistingPathAttributes)) {
        if ($null -eq $item -or @($item.PSObject.Properties | Where-Object Name -CEQ 'path').Count -ne 1 -or
            @($item.PSObject.Properties | Where-Object Name -CEQ 'attributes').Count -ne 1 -or
            $item.path -isnot [string] -or [string]::IsNullOrWhiteSpace($item.path) -or
            $null -eq $item.attributes -or $item.attributes.GetType() -ne [System.IO.FileAttributes]) {
            throw 'Invalid existing path attribute record.'
        }
        Assert-NoReparsePoint -Attributes $item.attributes -Label $item.path
    }
    return $expected
}

function New-SourceCorpusSummary {
    param([Parameter(Mandatory)][object]$Ledger,[Parameter(Mandatory)][string]$LedgerPath,[Parameter(Mandatory)][object[]]$SourceTotals,[object[]]$Exclusions=@())
    if ($LedgerPath -match '\\' -or [System.IO.Path]::IsPathRooted($LedgerPath) -or $LedgerPath -match '(^|/)\.\.?(\/|$)') { throw 'LedgerPath must be portable.' }
    foreach ($name in @('schemaVersion','generatedAt','snapshotId','inputFingerprint','sources','files')) {
        if (@($Ledger.PSObject.Properties | Where-Object Name -CEQ $name).Count -ne 1) { throw "Ledger is missing required property: $name" }
    }
    if ($Ledger.schemaVersion -isnot [string] -or $Ledger.schemaVersion -cne '1.0.0' -or $Ledger.snapshotId -isnot [string] -or
        $Ledger.generatedAt -isnot [string] -or $Ledger.inputFingerprint -isnot [string] -or $Ledger.inputFingerprint -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid ledger identity.' }
    $catalogedBytes=Get-CheckedInt64Total -Values @($Ledger.files|ForEach-Object {
        if ($null -eq $_.sizeBytes -or $_.sizeBytes.GetType() -notin @([byte],[sbyte],[int16],[uint16],[int32],[uint32],[int64],[uint64])) { throw 'Invalid ledger file sizeBytes.' }; $_.sizeBytes
    })
    $validatedExclusions=@($Exclusions)
    $excludedBytes=Get-CheckedInt64Total -Values @($validatedExclusions|ForEach-Object {
        if ($null -eq $_.sizeBytes -or $_.sizeBytes.GetType() -notin @([byte],[sbyte],[int16],[uint16],[int32],[uint32],[int64],[uint64])) { throw 'Invalid exclusion sizeBytes.' }; $_.sizeBytes
    })
    foreach($row in $SourceTotals){
        $names=@($row.PSObject.Properties.Name); if(($names|Sort-Object)-join ',' -cne 'capturedAt,rootFingerprint,sourceBytes,sourceFileCount,sourceId,sourceKind'){throw 'Invalid source total row.'}
        if($row.sourceId -isnot [string] -or $row.sourceKind -isnot [string] -or $row.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
           $row.capturedAt -isnot [string] -or $row.capturedAt -cne $Ledger.generatedAt -or $row.rootFingerprint -isnot [string] -or $row.rootFingerprint -cnotmatch '^[0-9a-f]{64}$' -or
           $null -eq $row.sourceFileCount -or $row.sourceFileCount.GetType() -notin @([byte],[sbyte],[int16],[uint16],[int32],[uint32],[int64],[uint64]) -or
           $null -eq $row.sourceBytes -or $row.sourceBytes.GetType() -notin @([byte],[sbyte],[int16],[uint16],[int32],[uint32],[int64],[uint64])){throw 'Invalid source total row.'}
    }
    $ledgerSources=@($Ledger.sources)
    if($ledgerSources.Count -ne $SourceTotals.Count){throw 'Source count does not match source corpus ledger.'}
    $ledgerIds=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $totalIds=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach($row in $ledgerSources){
        if($row -isnot [System.Management.Automation.PSCustomObject] -or
           ((@($row.PSObject.Properties.Name)|Sort-Object)-join ',') -cne 'capturedAt,rootFingerprint,sourceId,sourceKind' -or
           $row.sourceId -isnot [string] -or [string]::IsNullOrWhiteSpace($row.sourceId) -or -not $ledgerIds.Add($row.sourceId) -or
           $row.sourceKind -isnot [string] -or $row.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
           $row.capturedAt -isnot [string] -or $row.rootFingerprint -isnot [string] -or $row.rootFingerprint -cnotmatch '^[0-9a-f]{64}$'){
            throw 'Invalid ledger source row.'
        }
    }
    foreach($row in $SourceTotals){
        if(-not $totalIds.Add($row.sourceId)){throw 'Invalid or duplicate source total sourceId.'}
        $match=@($ledgerSources|Where-Object{$_.sourceId -ceq $row.sourceId})
        if($match.Count -ne 1 -or $match[0].sourceKind -cne $row.sourceKind -or $match[0].rootFingerprint -cne $row.rootFingerprint -or $match[0].capturedAt -cne $row.capturedAt){throw "Source identity does not match source corpus ledger for '$($row.sourceId)'."}
    }
    $sourceFileCount=Get-CheckedInt64Total -Values @($SourceTotals|ForEach-Object sourceFileCount)
    $sourceBytes=Get-CheckedInt64Total -Values @($SourceTotals|ForEach-Object sourceBytes)
    if($sourceFileCount -ne @($Ledger.files).Count+@($validatedExclusions).Count){throw 'Source file conservation failed.'}
    if($sourceBytes -ne $catalogedBytes+$excludedBytes){throw 'Source byte conservation failed.'}
    $summarySources=@($SourceTotals|ForEach-Object{[pscustomobject][ordered]@{sourceId=$_.sourceId;sourceKind=$_.sourceKind;rootFingerprint=$_.rootFingerprint;sourceFileCount=[long]$_.sourceFileCount;sourceBytes=[long]$_.sourceBytes}})
    [pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$Ledger.generatedAt;snapshotId=$Ledger.snapshotId;inputFingerprint=$Ledger.inputFingerprint;ledgerInputFingerprint=$Ledger.inputFingerprint;ledgerPath=$LedgerPath;toolVersions=@([pscustomobject]@{toolName='source-corpus-gate';version='1.0.0'});operationIdentity='C1.SourceCorpusSnapshot.Refresh';directChildSummaries=@($LedgerPath);directChildReports=@();failureAttribution='None; snapshot generation completed without a recorded failure.';nextAllowedAction='Provide the portable ledger and summary to C2 discovery.';sourceCount=@($Ledger.sources).Count;sourceFileCount=$sourceFileCount;catalogedFileCount=@($Ledger.files).Count;explicitlyExcludedFileCount=@($validatedExclusions).Count;sourceBytes=$sourceBytes;catalogedBytes=$catalogedBytes;explicitlyExcludedBytes=$excludedBytes;sources=$summarySources;exclusions=@($validatedExclusions)}
}

function Assert-ExactObjectProperties {
    param([object]$Value,[string[]]$Expected,[string]$Label)
    if($Value -isnot [System.Management.Automation.PSCustomObject] -or ((@($Value.PSObject.Properties.Name)|Sort-Object)-join ',') -cne (($Expected|Sort-Object)-join ',')){throw "Invalid $Label schema."}
}
function Assert-PortableOutputPathValue {
    param([string]$Value,[string]$Label)
    if([string]::IsNullOrWhiteSpace($Value) -or $Value.Contains('\') -or [System.IO.Path]::IsPathRooted($Value) -or $Value -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or $Value -match '(^|/)\.\.?(\/|$)'){throw "Invalid portable path in $Label."}
}
function Assert-NoMachineData {
    param([AllowNull()][object]$Value,[string]$Label='output',[int]$Depth=0)
    if($Depth -gt 64){throw "Portable output nesting is too deep or cyclic in $Label."}
    if($null -eq $Value){return}
    if($Value -is [string]){if([System.IO.Path]::IsPathRooted($Value) -or $Value -match '^[A-Za-z][A-Za-z0-9+.-]*://'){throw "Machine path is forbidden in $Label."};return}
    if($Value -is [System.Collections.DictionaryEntry]){if($Value.Key -isnot [string]){throw "Non-string dictionary key is forbidden in $Label."};if($Value.Key -ceq 'rootPath'){throw 'rootPath is forbidden in portable outputs.'};Assert-NoMachineData -Value $Value.Value -Label "$Label.$($Value.Key)" -Depth ($Depth+1);return}
    if($Value -is [System.Collections.IDictionary]){foreach($key in $Value.Keys){if($key -isnot [string]){throw "Non-string dictionary key is forbidden in $Label."};if($key -ceq 'rootPath'){throw 'rootPath is forbidden in portable outputs.'};Assert-NoMachineData -Value $Value[$key] -Label "$Label.$key" -Depth ($Depth+1)};return}
    if($Value -is [System.Management.Automation.PSCustomObject]){foreach($p in $Value.PSObject.Properties){if($p.Name -ceq 'rootPath'){throw 'rootPath is forbidden in portable outputs.'};Assert-NoMachineData -Value $p.Value -Label "$Label.$($p.Name)" -Depth ($Depth+1)};return}
    if($Value -is [System.Collections.IEnumerable]){foreach($item in $Value){Assert-NoMachineData -Value $item -Label $Label -Depth ($Depth+1)};return}
    if($Value -is [bool] -or $Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or $Value -is [int32] -or $Value -is [uint32] -or $Value -is [int64] -or $Value -is [uint64] -or $Value -is [single] -or $Value -is [double] -or $Value -is [decimal] -or $Value -is [datetime] -or $Value -is [datetimeoffset]){return}
    throw "Unsupported complex portable output value in $Label."
}
function Assert-SourceCorpusWriterContracts {
    param([object]$Ledger,[object]$Summary)
    Assert-ExactObjectProperties $Ledger @('schemaVersion','snapshotId','generatedAt','inputFingerprint','toolVersions','sources','files','objects') 'ledger'
    if($Ledger.schemaVersion -isnot [string] -or $Ledger.schemaVersion -cne '1.0.0' -or $Ledger.snapshotId -isnot [string] -or [string]::IsNullOrWhiteSpace($Ledger.snapshotId) -or $Ledger.generatedAt -isnot [string] -or $Ledger.inputFingerprint -isnot [string] -or $Ledger.inputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or $Ledger.toolVersions -isnot [object[]] -or $Ledger.sources -isnot [object[]] -or $Ledger.files -isnot [object[]] -or $Ledger.objects -isnot [object[]] -or $Ledger.objects.Count -ne 0){throw 'Invalid ledger contract.'}
    $parsed=[datetimeoffset]::MinValue;if(-not[datetimeoffset]::TryParse($Ledger.generatedAt,[ref]$parsed)){throw 'Invalid ledger generatedAt.'}
    foreach($tool in $Ledger.toolVersions){Assert-ExactObjectProperties $tool @('toolName','version') 'ledger tool version';if($tool.toolName -isnot [string] -or $tool.version -isnot [string]){throw 'Invalid ledger tool version.'}}
    foreach($source in $Ledger.sources){Assert-ExactObjectProperties $source @('sourceId','sourceKind','capturedAt','rootFingerprint') 'ledger source';$sourceDate=[datetimeoffset]::MinValue;if($source.sourceId -isnot [string] -or [string]::IsNullOrWhiteSpace($source.sourceId) -or $source.sourceKind -isnot [string] -or $source.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or $source.capturedAt -isnot [string] -or $source.capturedAt -cne $Ledger.generatedAt -or -not[datetimeoffset]::TryParse($source.capturedAt,[ref]$sourceDate) -or $source.rootFingerprint -isnot [string] -or $source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$'){throw 'Invalid ledger source contract.'}}
    foreach($file in $Ledger.files){
        Assert-ExactObjectProperties $file @('snapshotId','sourceId','sourceKind','relativePath','sizeBytes','sha256','capturedAt','containerKind','parseStatus','disposition','evidence','status') 'ledger file'
        if($file.snapshotId -isnot [string] -or $file.snapshotId -cne $Ledger.snapshotId -or $file.sourceId -isnot [string] -or $file.sourceKind -isnot [string] -or $file.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or $file.sha256 -isnot [string] -or $file.sha256 -cnotmatch '^[0-9a-f]{64}$' -or $file.capturedAt -isnot [string] -or $file.capturedAt -cne $Ledger.generatedAt -or $file.parseStatus -cnotin @('NotAttempted','ExtractedReadable','CrossToolVerified','Opaque','Failed') -or $file.disposition -cnotin @('NeedsDiagnosis','UseOriginalAsset','RepairOnce','PrototypeReplacement','RetainForLater','DiagnosticOnly','Stop') -or $file.evidence -isnot [object[]]){throw 'Invalid ledger file contract.'}
        foreach($evidencePath in $file.evidence){if($evidencePath -isnot [string]){throw 'Ledger evidence entries must be portable strings.'};Assert-PortableOutputPathValue $evidencePath 'ledger evidence'}
        Assert-PortableOutputPathValue $file.relativePath 'ledger file'
        Assert-ExactObjectProperties $file.status @('corpus','extraction','semantics','unity','disposition') 'ledger file status'
    }
    Assert-ExactObjectProperties $Summary @('schemaVersion','generatedAt','snapshotId','inputFingerprint','ledgerInputFingerprint','ledgerPath','toolVersions','operationIdentity','directChildSummaries','directChildReports','failureAttribution','nextAllowedAction','sourceCount','sourceFileCount','catalogedFileCount','explicitlyExcludedFileCount','sourceBytes','catalogedBytes','explicitlyExcludedBytes','sources','exclusions') 'summary'
    Assert-NoMachineData $Ledger 'ledger';Assert-NoMachineData $Summary 'summary';Assert-PortableOutputPathValue $Summary.ledgerPath 'summary ledgerPath'
    if($Summary.directChildSummaries -isnot [object[]] -or $Summary.directChildSummaries.Count-ne 1 -or $Summary.directChildSummaries[0] -cne $Summary.ledgerPath -or $Summary.directChildReports -isnot [object[]] -or $Summary.directChildReports.Count-ne 0){throw 'Invalid summary child paths.'}
    foreach($p in $Summary.directChildSummaries){Assert-PortableOutputPathValue $p 'summary direct child'}
    $sourceTotals=@($Summary.sources|ForEach-Object{$summarySource=$_;Assert-ExactObjectProperties $summarySource @('sourceId','sourceKind','rootFingerprint','sourceFileCount','sourceBytes') 'summary source';$ls=@($Ledger.sources|Where-Object{$_.sourceId -ceq $summarySource.sourceId});[pscustomobject]@{sourceId=$summarySource.sourceId;sourceKind=$summarySource.sourceKind;capturedAt=if($ls.Count-eq 1){$ls[0].capturedAt}else{$Ledger.generatedAt};rootFingerprint=$summarySource.rootFingerprint;sourceFileCount=$summarySource.sourceFileCount;sourceBytes=$summarySource.sourceBytes}})
    foreach($e in @($Summary.exclusions)){Assert-ExactObjectProperties $e @('sourceId','relativePath','sizeBytes','reason') 'summary exclusion';Assert-PortableOutputPathValue $e.relativePath 'summary exclusion'}
    $expected=New-SourceCorpusSummary -Ledger $Ledger -LedgerPath $Summary.ledgerPath -SourceTotals $sourceTotals -Exclusions @($Summary.exclusions)
    $actualNode=[System.Text.Json.Nodes.JsonNode]::Parse(($Summary|ConvertTo-Json -Depth 100 -Compress));$expectedNode=[System.Text.Json.Nodes.JsonNode]::Parse(($expected|ConvertTo-Json -Depth 100 -Compress))
    if(-not[System.Text.Json.Nodes.JsonNode]::DeepEquals($actualNode,$expectedNode)){throw 'Summary does not match ledger and frozen contract.'}
}

function Assert-GenuineDirectoryAtExactPath {
    param([string]$Path,[string]$Expected)
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    $actualFull=([System.IO.Path]::GetFullPath($item.FullName)).TrimEnd('\','/');$expectedFull=([System.IO.Path]::GetFullPath($Expected)).TrimEnd('\','/')
    if($item -isnot [System.IO.DirectoryInfo] -or -not $item.PSIsContainer -or -not $actualFull.Equals($expectedFull,[System.StringComparison]::OrdinalIgnoreCase)){throw "Directory is not the expected genuine path: $Expected"}
    Assert-NoReparsePoint -Attributes $item.Attributes -Label $item.FullName
    Assert-NoReparsePointPathChain -Path $item.FullName
}

function Write-SourceCorpusOutputs {
    param([Parameter(Mandatory)][string]$OutputRoot,[Parameter(Mandatory)][object]$Ledger,[Parameter(Mandatory)][object]$Summary)
    Assert-SourceCorpusWriterContracts -Ledger $Ledger -Summary $Summary
    $output=[System.IO.Path]::GetFullPath($OutputRoot); $parent=Split-Path -Parent $output
    if(Test-Path -LiteralPath $output){throw "OutputRoot already exists: $output"}
    $existing=$parent
    while(-not(Test-Path -LiteralPath $existing -PathType Container)){$next=Split-Path -Parent $existing;if($next -eq $existing){throw 'Output parent has no existing directory ancestor.'};$existing=$next}
    Assert-NoReparsePointPathChain -Path $existing
    if(-not(Test-Path -LiteralPath $parent -PathType Container)){[System.IO.Directory]::CreateDirectory($parent)|Out-Null}
    Assert-NoReparsePointPathChain -Path $parent
    $staging=Join-Path $parent ('.c1-staging-'+[guid]::NewGuid().ToString('N'))
    $published=$false
    try{
        [System.IO.Directory]::CreateDirectory($staging)|Out-Null
        # Path APIs cannot make validation, writes, and rename one atomic operation against a malicious path-swap; revalidate every publication phase and fail closed.
        Assert-GenuineDirectoryAtExactPath -Path $staging -Expected $staging
        $ledgerPath=Join-Path $staging 'source-corpus-ledger.json';$summaryPath=Join-Path $staging 'source-corpus-summary.json'
        Assert-NoReparsePointPathChain -Path $parent;Assert-GenuineDirectoryAtExactPath -Path $staging -Expected $staging
        [System.IO.File]::WriteAllText($ledgerPath,($Ledger|ConvertTo-Json -Depth 100),[System.Text.UTF8Encoding]::new($false))
        Assert-NoReparsePointPathChain -Path $parent;Assert-GenuineDirectoryAtExactPath -Path $staging -Expected $staging
        [System.IO.File]::WriteAllText($summaryPath,($Summary|ConvertTo-Json -Depth 100),[System.Text.UTF8Encoding]::new($false))
        Assert-NoReparsePointPathChain -Path $parent;Assert-GenuineDirectoryAtExactPath -Path $staging -Expected $staging
        if(Test-Path -LiteralPath $output){throw "OutputRoot already exists: $output"}
        Move-Item -LiteralPath $staging -Destination $output -ErrorAction Stop
        $published=$true
        Assert-GenuineDirectoryAtExactPath -Path $output -Expected $output
        [pscustomobject][ordered]@{ledgerPath=Join-Path $output 'source-corpus-ledger.json';summaryPath=Join-Path $output 'source-corpus-summary.json'}
    }catch{if($published -and (Test-Path -LiteralPath $output)){Remove-Item -LiteralPath $output -Recurse -Force};throw}
    finally{if(Test-Path -LiteralPath $staging){Remove-Item -LiteralPath $staging -Recurse -Force}}
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
    'Get-SourceContainerKind',
    'Get-CheckedInt64Total',
    'Assert-C1OutputPathPolicy',
    'New-SourceCorpusSummary',
    'Write-SourceCorpusOutputs'
)
