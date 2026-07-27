$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Stop-Mcbr {
    param([Parameter(Mandatory)][string] $Code)
    throw [InvalidOperationException]::new("MCBR:$Code")
}

function Get-McbrSha256 {
    param([Parameter(Mandatory)][string] $LiteralPath)
    $stream = [IO.File]::Open(
        $LiteralPath,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::Read
    )
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
        $stream.Dispose()
    }
}

function Get-McbrContract {
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        artifactId = 'MCBR-LO1-CabProviderScan'
        repositoryRoot = $repositoryRoot
        logPortablePath = 'Extracted/ScriptStrippedFxReconstruction/char_14401/LO1/Logs/assetripper.log'
        logSha256 = '82ffafec53e6cf7c2270453b3054c43fd23022f03de9c307daf312701ee1bd61'
        planPortablePath = 'Extracted/ScriptStrippedFxReconstruction/char_14401/T2/reconstruction-plan.json'
        planSha256 = '48124da20a27f353e5d1e836e931f74ad0180e47bfb3153c56b8ad574c3bc11f'
        outputPortablePath = 'Extracted/MissingCabClosureRecovery/char_14401/LO1/cab-provider-scan.json'
        targetCabCount = 25
        placeholderGuid = '0000000deadbeef15deadf00d0000000'
        unresolvedRequiredGuidCount = 940
        unresolvedClassification = [ordered]@{
            Shader = 304
            Texture = 485
            Mesh = 129
            AnimationClip = 20
            Material = 1
            Controller = 1
        }
        scanSourceKinds = @('PcInstall', 'AndroidApk', 'AndroidDataOrCache')
        registrySourceKinds = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
        candidateExtensions = @('.unity3d', '.bundle', '.assetbundle', '.ab')
        cabPattern = 'CAB-[0-9a-fA-F]{32}'
        chunkSize = 65536
        overlapByteCount = 96
        overallTimeoutMilliseconds = 1800000
        maxFileOpenCountPerCandidate = 1
        allowedDecisions = @(
            'AllProvidersUniquelyIdentified',
            'PartialProvidersIdentified',
            'AmbiguousProviderCandidates',
            'BlockedScanCap',
            'BlockedSourceBoundary'
        )
        occurrenceDispositions = @('ProviderCandidate', 'DependencyOnlyReference', 'Ambiguous')
        matchPropertyNames = @(
            'cabId', 'disposition', 'sourceId', 'sourceKind', 'relativePath',
            'archiveEntry', 'offset', 'fileLength', 'fileSha256', 'entryLength',
            'entrySha256', 'evidence'
        )
        cabAccountingPropertyNames = @(
            'cabId', 'disposition', 'totalOccurrences', 'providerCandidateCount',
            'uniqueProviderCandidateCount', 'dependencyOnlyReferenceCount', 'ambiguousCount'
        )
        failureTransitions = [ordered]@{
            FrozenEvidenceMismatch = 'SuppressOutput'
            OutputAlreadyExists = 'SuppressOutput'
            SourceBoundary = 'BlockedSourceBoundary'
            SourceIdentityDrift = 'BlockedSourceBoundary'
            ScanCap = 'BlockedScanCap'
        }
        nextAction = 'AwaitMCBRLO1Audit'
    }
}

function ConvertTo-McbrAbsolutePath {
    param(
        [Parameter(Mandatory)][object] $Contract,
        [Parameter(Mandatory)][string] $PortablePath
    )
    if (
        [string]::IsNullOrWhiteSpace($PortablePath) -or
        $PortablePath.Contains('\') -or
        [IO.Path]::IsPathRooted($PortablePath) -or
        $PortablePath -match '(^|/)\.{1,2}(/|$)'
    ) {
        Stop-Mcbr 'PortablePathInvalid'
    }
    $root = [IO.Path]::GetFullPath([string]$Contract.repositoryRoot).TrimEnd('\', '/')
    $absolute = [IO.Path]::GetFullPath(
        (Join-Path $root $PortablePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    )
    if (-not $absolute.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Mcbr 'PortablePathEscape'
    }
    return $absolute
}

function Get-McbrExactPropertyNames {
    param([AllowNull()][object] $Value)
    if ($Value -isnot [Management.Automation.PSCustomObject]) {
        return ''
    }
    return (@($Value.PSObject.Properties.Name) | Sort-Object) -join ','
}

function Test-McbrJsonArrayProperty {
    param(
        [Parameter(Mandatory)][string] $JsonText,
        [Parameter(Mandatory)][string[]] $PropertyPath
    )
    $document = $null
    try {
        $document = [Text.Json.JsonDocument]::Parse($JsonText)
        $element = $document.RootElement
        foreach ($name in $PropertyPath) {
            if ($element.ValueKind -ne [Text.Json.JsonValueKind]::Object) {
                return $false
            }
            $next = [Text.Json.JsonElement]::new()
            if (-not $element.TryGetProperty($name, [ref]$next)) {
                return $false
            }
            $element = $next
        }
        return $element.ValueKind -eq [Text.Json.JsonValueKind]::Array
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Assert-McbrDeadline {
    param([Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc)
    if ([DateTimeOffset]::UtcNow -ge $DeadlineUtc) {
        Stop-Mcbr 'ScanCap'
    }
}

function Assert-McbrLocalNoReparseChain {
    param(
        [Parameter(Mandatory)][string] $AbsolutePath,
        [Parameter(Mandatory)][ValidateSet('File', 'Directory')][string] $LeafKind
    )
    if (
        [string]::IsNullOrWhiteSpace($AbsolutePath) -or
        -not [IO.Path]::IsPathFullyQualified($AbsolutePath) -or
        $AbsolutePath -match '^[\\/]{2}'
    ) {
        Stop-Mcbr 'SourceBoundary'
    }
    $full = [IO.Path]::GetFullPath($AbsolutePath)
    $volumeRoot = [IO.Path]::GetPathRoot($full)
    if ([string]::IsNullOrWhiteSpace($volumeRoot)) {
        Stop-Mcbr 'SourceBoundary'
    }
    $cursor = $volumeRoot
    $rootItem = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    if ($null -eq $rootItem -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Stop-Mcbr 'SourceBoundary'
    }
    $segments = @($full.Substring($volumeRoot.Length).Trim('\', '/') -split '[\\/]' | Where-Object { $_ })
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $cursor = Join-Path $cursor $segments[$index]
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        if ($null -eq $item -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Stop-Mcbr 'SourceBoundary'
        }
        $isLeaf = $index -eq ($segments.Count - 1)
        if (-not $isLeaf -and -not $item.PSIsContainer) {
            Stop-Mcbr 'SourceBoundary'
        }
        if ($isLeaf) {
            if ($LeafKind -ceq 'File' -and ($item.PSIsContainer -or $item -isnot [IO.FileInfo])) {
                Stop-Mcbr 'SourceBoundary'
            }
            if ($LeafKind -ceq 'Directory' -and (-not $item.PSIsContainer -or $item -isnot [IO.DirectoryInfo])) {
                Stop-Mcbr 'SourceBoundary'
            }
        }
    }
}

function Get-McbrCanonicalSourceRows {
    param(
        [Parameter(Mandatory)][object[]] $Rows,
        [Parameter(Mandatory)][string[]] $RegistrySourceKinds,
        [DateTimeOffset] $DeadlineUtc = [DateTimeOffset]::MaxValue
    )
    $byId = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $Rows) {
        Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
        if (
            (Get-McbrExactPropertyNames $row) -cne 'rootPath,sourceId,sourceKind' -or
            $row.sourceId -isnot [string] -or
            [string]$row.sourceId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
            $row.sourceKind -isnot [string] -or
            $RegistrySourceKinds -cnotcontains [string]$row.sourceKind -or
            $row.rootPath -isnot [string]
        ) {
            Stop-Mcbr 'SourceBoundary'
        }
        $leafKind = if ([string]$row.sourceKind -ceq 'AndroidApk') { 'File' } else { 'Directory' }
        Assert-McbrLocalNoReparseChain -AbsolutePath ([string]$row.rootPath) -LeafKind $leafKind
        $item = Get-Item -LiteralPath ([string]$row.rootPath) -Force
        $canonical = $item.FullName.Normalize([Text.NormalizationForm]::FormC)
        if ($leafKind -ceq 'Directory' -and -not $canonical.Equals([IO.Path]::GetPathRoot($canonical), [StringComparison]::OrdinalIgnoreCase)) {
            $canonical = $canonical.TrimEnd('\', '/')
        }
        if ($byId.ContainsKey([string]$row.sourceId)) {
            Stop-Mcbr 'SourceBoundary'
        }
        $byId.Add([string]$row.sourceId, [pscustomobject][ordered]@{
            sourceId = [string]$row.sourceId
            sourceKind = [string]$row.sourceKind
            canonicalRoot = $canonical
        })
    }
    if ($byId.Count -eq 0) {
        Stop-Mcbr 'SourceBoundary'
    }
    return $byId
}

function Get-McbrValidatedSourceBoundaries {
    param(
        [Parameter(Mandatory)][string] $LocatorPath,
        [Parameter(Mandatory)][string[]] $ScanSourceKinds,
        [DateTimeOffset] $DeadlineUtc = [DateTimeOffset]::MaxValue
    )
    Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
    Assert-McbrLocalNoReparseChain -AbsolutePath $LocatorPath -LeafKind File
    try {
        $locatorRaw = [IO.File]::ReadAllText($LocatorPath)
        $locator = $locatorRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-Mcbr 'SourceBoundary'
    }
    if (
        (Get-McbrExactPropertyNames $locator) -cne 'baseline,manifestPath,schemaVersion,sourceBoundary' -or
        $locator.schemaVersion -cne '1.0.0' -or
        $locator.manifestPath -isnot [string] -or
        (Get-McbrExactPropertyNames $locator.baseline) -cne 'disposition,path' -or
        (Get-McbrExactPropertyNames $locator.sourceBoundary) -cne 'schemaVersion,sources' -or
        $locator.sourceBoundary.schemaVersion -cne '1.0.0' -or
        -not (Test-McbrJsonArrayProperty -JsonText $locatorRaw -PropertyPath @('sourceBoundary', 'sources')) -or
        @($locator.sourceBoundary.sources).Count -eq 0
    ) {
        Stop-Mcbr 'SourceBoundary'
    }
    if ($locator.baseline.disposition -ceq 'Absent') {
        if ($null -ne $locator.baseline.path) {
            Stop-Mcbr 'SourceBoundary'
        }
    }
    elseif ($locator.baseline.disposition -ceq 'Present') {
        if ($locator.baseline.path -isnot [string]) {
            Stop-Mcbr 'SourceBoundary'
        }
        Assert-McbrLocalNoReparseChain -AbsolutePath ([string]$locator.baseline.path) -LeafKind File
    }
    else {
        Stop-Mcbr 'SourceBoundary'
    }

    $manifestPath = [string]$locator.manifestPath
    if (-not [IO.Path]::IsPathFullyQualified($manifestPath) -or $manifestPath -match '^[\\/]{2}') {
        Stop-Mcbr 'SourceBoundary'
    }
    Assert-McbrLocalNoReparseChain -AbsolutePath $manifestPath -LeafKind File
    try {
        $manifestRaw = [IO.File]::ReadAllText($manifestPath)
        $manifest = $manifestRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-Mcbr 'SourceBoundary'
    }
    if (
        (Get-McbrExactPropertyNames $manifest) -cne 'schemaVersion,sources' -or
        $manifest.schemaVersion -cne '1.0.0' -or
        -not (Test-McbrJsonArrayProperty -JsonText $manifestRaw -PropertyPath @('sources')) -or
        @($manifest.sources).Count -eq 0
    ) {
        Stop-Mcbr 'SourceBoundary'
    }

    $contract = Get-McbrContract
    $left = Get-McbrCanonicalSourceRows `
        -Rows @($locator.sourceBoundary.sources) `
        -RegistrySourceKinds $contract.registrySourceKinds `
        -DeadlineUtc $DeadlineUtc
    $right = Get-McbrCanonicalSourceRows `
        -Rows @($manifest.sources) `
        -RegistrySourceKinds $contract.registrySourceKinds `
        -DeadlineUtc $DeadlineUtc
    if ($left.Count -ne $right.Count) {
        Stop-Mcbr 'SourceBoundary'
    }
    foreach ($sourceId in $left.Keys) {
        Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
        if (-not $right.ContainsKey($sourceId)) {
            Stop-Mcbr 'SourceBoundary'
        }
        $a = $left[$sourceId]
        $b = $right[$sourceId]
        if (
            $a.sourceId -cne $b.sourceId -or
            $a.sourceKind -cne $b.sourceKind -or
            -not $a.canonicalRoot.Equals($b.canonicalRoot, [StringComparison]::OrdinalIgnoreCase)
        ) {
            Stop-Mcbr 'SourceBoundary'
        }
    }
    $selected = @(
        foreach ($row in $right.Values) {
            if ($ScanSourceKinds -ccontains [string]$row.sourceKind) {
                $row
            }
        }
    )
    if ($selected.Count -eq 0) {
        Stop-Mcbr 'SourceBoundary'
    }
    return @($selected | Sort-Object sourceId)
}

function Read-McbrFrozenEvidence {
    param(
        [Parameter(Mandatory)][object] $Contract,
        [DateTimeOffset] $DeadlineUtc = [DateTimeOffset]::MaxValue
    )
    Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
    $logPath = ConvertTo-McbrAbsolutePath -Contract $Contract -PortablePath $Contract.logPortablePath
    $planPath = ConvertTo-McbrAbsolutePath -Contract $Contract -PortablePath $Contract.planPortablePath
    if (
        -not (Test-Path -LiteralPath $logPath -PathType Leaf) -or
        -not (Test-Path -LiteralPath $planPath -PathType Leaf) -or
        (Get-McbrSha256 -LiteralPath $logPath) -cne $Contract.logSha256 -or
        (Get-McbrSha256 -LiteralPath $planPath) -cne $Contract.planSha256
    ) {
        Stop-Mcbr 'FrozenEvidenceMismatch'
    }
    Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
    $logText = [IO.File]::ReadAllText($logPath)
    $targetCabIds = @(
        [regex]::Matches($logText, $Contract.cabPattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase) |
            ForEach-Object { $_.Value.ToLowerInvariant() } |
            Sort-Object -Unique
    )
    if ($targetCabIds.Count -ne $Contract.targetCabCount) {
        Stop-Mcbr 'FrozenEvidenceMismatch'
    }
    try {
        $plan = [IO.File]::ReadAllText($planPath) | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-Mcbr 'FrozenEvidenceMismatch'
    }
    $references = @($plan.unresolvedReferences)
    $uniqueGuids = @($references.guid | Sort-Object -Unique)
    $uniqueReasons = @($references.reason | Sort-Object -Unique)
    $classificationTotal = [int](($Contract.unresolvedClassification.Values | Measure-Object -Sum).Sum)
    if (
        [int]$plan.unresolvedRequiredGuidCount -ne $Contract.unresolvedRequiredGuidCount -or
        $references.Count -ne $Contract.unresolvedRequiredGuidCount -or
        $uniqueGuids.Count -ne 1 -or
        [string]$uniqueGuids[0] -cne $Contract.placeholderGuid -or
        $uniqueReasons.Count -ne 1 -or
        [string]$uniqueReasons[0] -cne 'DeadbeefPlaceholder' -or
        $classificationTotal -ne $Contract.unresolvedRequiredGuidCount
    ) {
        Stop-Mcbr 'FrozenEvidenceMismatch'
    }
    Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
    return [pscustomobject][ordered]@{
        logSha256 = $Contract.logSha256
        planSha256 = $Contract.planSha256
        targetCabIds = [string[]]$targetCabIds
        unresolvedRequiredGuidCount = $Contract.unresolvedRequiredGuidCount
        unresolvedClassification = $Contract.unresolvedClassification
        unresolvedClassificationTotal = $classificationTotal
        placeholderGuid = $Contract.placeholderGuid
    }
}

function Find-McbrCabTokensInStream {
    param(
        [Parameter(Mandatory)][IO.Stream] $Stream,
        [Parameter(Mandatory)][ValidateRange(1, 1048576)][int] $ChunkSize,
        [Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc
    )
    if (-not $Stream.CanRead) {
        Stop-Mcbr 'UnreadableStream'
    }
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    $buffer = [byte[]]::new($ChunkSize)
    $carry = [byte[]]::new(0)
    $prefix = [Collections.Generic.List[byte]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $rawMatches = [Collections.Generic.List[object]]::new()
    [int64]$processed = 0
    try {
        while ($true) {
            Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
            $read = $Stream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) {
                break
            }
            $hash.AppendData($buffer, 0, $read)
            for ($index = 0; $index -lt $read -and $prefix.Count -lt 8; $index++) {
                $prefix.Add($buffer[$index])
            }
            $combined = [byte[]]::new($carry.Length + $read)
            if ($carry.Length -gt 0) {
                [Array]::Copy($carry, 0, $combined, 0, $carry.Length)
            }
            [Array]::Copy($buffer, 0, $combined, $carry.Length, $read)
            $text = [Text.Encoding]::ASCII.GetString($combined)
            $baseOffset = $processed - $carry.Length
            foreach ($match in [regex]::Matches($text, 'CAB-[0-9a-fA-F]{32}', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                [int64]$absoluteOffset = $baseOffset + $match.Index
                $cabId = $match.Value.ToLowerInvariant()
                $identity = "$absoluteOffset`0$cabId"
                if ($seen.Add($identity)) {
                    $contextStart = [Math]::Max(0, $match.Index - 32)
                    $contextLength = $match.Index - $contextStart
                    $preceding = if ($contextLength -gt 0) { $text.Substring($contextStart, $contextLength) } else { '' }
                    $rawMatches.Add([pscustomobject][ordered]@{
                        cabId = $cabId
                        offset = $absoluteOffset
                        archiveReference = $preceding.EndsWith('archive:/', [StringComparison]::OrdinalIgnoreCase)
                    })
                }
            }
            $processed += $read
            $keep = [Math]::Min(96, $combined.Length)
            $carry = [byte[]]::new($keep)
            if ($keep -gt 0) {
                [Array]::Copy($combined, $combined.Length - $keep, $carry, 0, $keep)
            }
        }
        $header = [Text.Encoding]::ASCII.GetString($prefix.ToArray())
        $hasUnityBundleHeader = (
            $header.StartsWith('UnityFS', [StringComparison]::Ordinal) -or
            $header.StartsWith('UnityRaw', [StringComparison]::Ordinal) -or
            $header.StartsWith('UnityWeb', [StringComparison]::Ordinal)
        )
        $ordered = @($rawMatches | Sort-Object offset)
        $providerCandidateAssigned = $false
        $matches = @(
            foreach ($row in $ordered) {
                $disposition = 'Ambiguous'
                $evidence = 'AsciiCabTokenOnly'
                if ($row.archiveReference) {
                    $disposition = 'DependencyOnlyReference'
                    $evidence = 'ArchiveReferencePrefix'
                }
                elseif ($hasUnityBundleHeader -and -not $providerCandidateAssigned) {
                    $disposition = 'ProviderCandidate'
                    $evidence = 'UnityBundleHeaderAndFirstNonDependencyCabIdentity'
                    $providerCandidateAssigned = $true
                }
                [pscustomobject][ordered]@{
                    cabId = $row.cabId
                    offset = [int64]$row.offset
                    disposition = $disposition
                    evidence = $evidence
                }
            }
        )
        return [pscustomobject][ordered]@{
            byteCount = $processed
            sha256 = [Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
            hasUnityBundleHeader = $hasUnityBundleHeader
            matches = $matches
        }
    }
    finally {
        $hash.Dispose()
    }
}

function Test-McbrCandidateAssetPath {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string[]] $CandidateExtensions
    )
    return $CandidateExtensions -ccontains [IO.Path]::GetExtension($Path).ToLowerInvariant()
}

function Get-McbrPortableRelativePath {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Path
    )
    $relative = [IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
    if ([IO.Path]::IsPathRooted($relative) -or $relative -eq '..' -or $relative.StartsWith('../', [StringComparison]::Ordinal)) {
        Stop-Mcbr 'SourceBoundary'
    }
    return $relative
}

function Get-McbrDirectoryCandidateFiles {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string[]] $CandidateExtensions,
        [Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc
    )
    $stack = [Collections.Generic.Stack[string]]::new()
    $stack.Push($Root)
    $files = [Collections.Generic.List[IO.FileInfo]]::new()
    while ($stack.Count -gt 0) {
        Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
        $directory = $stack.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Stop-Mcbr 'SourceBoundary'
            }
            if ($item -is [IO.DirectoryInfo]) {
                $stack.Push($item.FullName)
            }
            elseif ($item -is [IO.FileInfo] -and (Test-McbrCandidateAssetPath -Path $item.Name -CandidateExtensions $CandidateExtensions)) {
                $files.Add($item)
            }
        }
    }
    return @($files | Sort-Object FullName)
}

function Find-McbrCabTokensInApkBytes {
    param(
        [Parameter(Mandatory)][byte[]] $Bytes,
        [Parameter(Mandatory)][string] $SourceId,
        [Parameter(Mandatory)][string] $RelativePath,
        [Parameter(Mandatory)][int] $ChunkSize,
        [Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc
    )
    $memory = [IO.MemoryStream]::new($Bytes, $false)
    $archive = $null
    try {
        $archive = [IO.Compression.ZipArchive]::new($memory, [IO.Compression.ZipArchiveMode]::Read, $true)
        $entries = @(
            $archive.Entries |
                Where-Object {
                    -not [string]::IsNullOrEmpty($_.Name) -and
                    (Test-McbrCandidateAssetPath -Path $_.FullName -CandidateExtensions (Get-McbrContract).candidateExtensions)
                } |
                Sort-Object FullName
        )
        $matches = [Collections.Generic.List[object]]::new()
        foreach ($entry in $entries) {
            Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
            if (
                [IO.Path]::IsPathRooted($entry.FullName) -or
                $entry.FullName -match '(^|/)\.{1,2}(/|$)' -or
                $entry.FullName.Contains('\')
            ) {
                Stop-Mcbr 'SourceBoundary'
            }
            $entryStream = $entry.Open()
            try {
                $scan = Find-McbrCabTokensInStream -Stream $entryStream -ChunkSize $ChunkSize -DeadlineUtc $DeadlineUtc
            }
            finally {
                $entryStream.Dispose()
            }
            foreach ($match in $scan.matches) {
                $matches.Add([pscustomobject][ordered]@{
                    cabId = $match.cabId
                    disposition = $match.disposition
                    sourceId = $SourceId
                    sourceKind = 'AndroidApk'
                    relativePath = $RelativePath
                    archiveEntry = $entry.FullName
                    offset = [int64]$match.offset
                    fileLength = [int64]$Bytes.Length
                    fileSha256 = ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))).ToLowerInvariant()
                    entryLength = [int64]$entry.Length
                    entrySha256 = $scan.sha256
                    evidence = $match.evidence
                })
            }
        }
        return [pscustomobject][ordered]@{
            archiveEntryCount = $entries.Count
            matches = @($matches)
        }
    }
    catch [IO.InvalidDataException] {
        Stop-Mcbr 'SourceBoundary'
    }
    finally {
        if ($null -ne $archive) {
            $archive.Dispose()
        }
        $memory.Dispose()
    }
}

function Read-McbrFileBytesOnce {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc
    )
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $memory = [IO.MemoryStream]::new()
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    $buffer = [byte[]]::new(65536)
    try {
        while ($true) {
            Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if ($read -eq 0) {
                break
            }
            $hash.AppendData($buffer, 0, $read)
            $memory.Write($buffer, 0, $read)
        }
        return [pscustomobject][ordered]@{
            bytes = $memory.ToArray()
            sha256 = [Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
        }
    }
    finally {
        $hash.Dispose()
        $memory.Dispose()
        $stream.Dispose()
    }
}

function New-McbrScanState {
    return [pscustomobject][ordered]@{
        sourceBoundaryValidated = $false
        scanCompleted = $false
        sourceScanLOUsed = 0
        scannedSourceCount = 0
        scannedFileCount = 0
        scannedArchiveEntryCount = 0
        scannedBytes = [int64]0
        fileOpenCount = 0
        sourceUnchanged = $true
        matches = [Collections.Generic.List[object]]::new()
    }
}

function Invoke-McbrBoundaryScan {
    param(
        [Parameter(Mandatory)][object] $Contract,
        [Parameter(Mandatory)][object[]] $Boundaries,
        [Parameter(Mandatory)][object] $State,
        [Parameter(Mandatory)][DateTimeOffset] $DeadlineUtc
    )
    $target = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($cabId in $script:McbrEvidence.targetCabIds) {
        [void]$target.Add($cabId)
    }
    $State.sourceScanLOUsed = 1
    foreach ($source in $Boundaries) {
        Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
        $State.scannedSourceCount++
        if ($source.sourceKind -ceq 'AndroidApk') {
            $pre = Get-Item -LiteralPath $source.canonicalRoot -Force
            $preLength = [int64]$pre.Length
            $preTime = $pre.LastWriteTimeUtc
            $preAttributes = [int]$pre.Attributes
            $file = Read-McbrFileBytesOnce -LiteralPath $pre.FullName -DeadlineUtc $DeadlineUtc
            $State.fileOpenCount++
            $State.scannedFileCount++
            $State.scannedBytes += $file.bytes.Length
            $apk = Find-McbrCabTokensInApkBytes `
                -Bytes $file.bytes `
                -SourceId $source.sourceId `
                -RelativePath $pre.Name `
                -ChunkSize $Contract.chunkSize `
                -DeadlineUtc $DeadlineUtc
            $State.scannedArchiveEntryCount += $apk.archiveEntryCount
            foreach ($match in $apk.matches) {
                if ($target.Contains($match.cabId)) {
                    $State.matches.Add($match)
                }
            }
            $post = Get-Item -LiteralPath $pre.FullName -Force
            if ([int64]$post.Length -ne $preLength -or $post.LastWriteTimeUtc -ne $preTime -or [int]$post.Attributes -ne $preAttributes) {
                $State.sourceUnchanged = $false
            }
            continue
        }

        $files = Get-McbrDirectoryCandidateFiles `
            -Root $source.canonicalRoot `
            -CandidateExtensions $Contract.candidateExtensions `
            -DeadlineUtc $DeadlineUtc
        foreach ($fileInfo in $files) {
            Assert-McbrDeadline -DeadlineUtc $DeadlineUtc
            $preLength = [int64]$fileInfo.Length
            $preTime = $fileInfo.LastWriteTimeUtc
            $preAttributes = [int]$fileInfo.Attributes
            $stream = [IO.File]::Open($fileInfo.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
            try {
                $scan = Find-McbrCabTokensInStream -Stream $stream -ChunkSize $Contract.chunkSize -DeadlineUtc $DeadlineUtc
            }
            finally {
                $stream.Dispose()
            }
            $State.fileOpenCount++
            $State.scannedFileCount++
            $State.scannedBytes += $scan.byteCount
            $relativePath = Get-McbrPortableRelativePath -Root $source.canonicalRoot -Path $fileInfo.FullName
            foreach ($match in $scan.matches) {
                if ($target.Contains($match.cabId)) {
                    $State.matches.Add([pscustomobject][ordered]@{
                        cabId = $match.cabId
                        disposition = $match.disposition
                        sourceId = $source.sourceId
                        sourceKind = $source.sourceKind
                        relativePath = $relativePath
                        archiveEntry = $null
                        offset = [int64]$match.offset
                        fileLength = [int64]$scan.byteCount
                        fileSha256 = $scan.sha256
                        entryLength = $null
                        entrySha256 = $null
                        evidence = $match.evidence
                    })
                }
            }
            $post = Get-Item -LiteralPath $fileInfo.FullName -Force
            if ([int64]$post.Length -ne $preLength -or $post.LastWriteTimeUtc -ne $preTime -or [int]$post.Attributes -ne $preAttributes) {
                $State.sourceUnchanged = $false
            }
        }
    }
    $State.scanCompleted = $true
}

function Get-McbrCabAccounting {
    param(
        [Parameter(Mandatory)][string[]] $TargetCabIds,
        [Parameter(Mandatory)][object[]] $Matches
    )
    $rows = @(
        foreach ($cabId in $TargetCabIds) {
            $cabMatches = @($Matches | Where-Object cabId -CEQ $cabId)
            $provider = @($cabMatches | Where-Object disposition -CEQ 'ProviderCandidate')
            $dependencyOnly = @($cabMatches | Where-Object disposition -CEQ 'DependencyOnlyReference')
            $ambiguous = @($cabMatches | Where-Object disposition -CEQ 'Ambiguous')
            $providerIdentities = @(
                $provider |
                    ForEach-Object { "$($_.sourceId)`0$($_.relativePath)`0$($_.archiveEntry)" } |
                    Sort-Object -Unique
            )
            $disposition = if ($providerIdentities.Count -eq 1 -and $ambiguous.Count -eq 0) {
                'UniqueProviderCandidate'
            }
            elseif ($providerIdentities.Count -gt 1 -or $ambiguous.Count -gt 0) {
                'Ambiguous'
            }
            elseif ($dependencyOnly.Count -gt 0) {
                'DependencyOnly'
            }
            else {
                'Unmatched'
            }
            [pscustomobject][ordered]@{
                cabId = $cabId
                disposition = $disposition
                totalOccurrences = $cabMatches.Count
                providerCandidateCount = $provider.Count
                uniqueProviderCandidateCount = $providerIdentities.Count
                dependencyOnlyReferenceCount = $dependencyOnly.Count
                ambiguousCount = $ambiguous.Count
            }
        }
    )
    # Frozen partitions: provider + dependencyOnly + ambiguous -eq totalOccurrences.
    foreach ($row in $rows) {
        $provider = [int]$row.providerCandidateCount
        $dependencyOnly = [int]$row.dependencyOnlyReferenceCount
        $ambiguous = [int]$row.ambiguousCount
        if (-not ($provider + $dependencyOnly + $ambiguous -eq [int]$row.totalOccurrences)) {
            Stop-Mcbr 'AccountingInvariant'
        }
    }
    # Frozen target conservation: matched + unmatched -eq targetCabCount.
    $matched = @($rows | Where-Object disposition -CNE 'Unmatched').Count
    $unmatched = @($rows | Where-Object disposition -CEQ 'Unmatched').Count
    if (-not ($matched + $unmatched -eq $TargetCabIds.Count)) {
        Stop-Mcbr 'AccountingInvariant'
    }
    return $rows
}

function Get-McbrDecisionFromAccounting {
    param(
        [Parameter(Mandatory)][object[]] $Accounting,
        [Parameter(Mandatory)][int] $TargetCabCount
    )
    if ($Accounting.Count -ne $TargetCabCount) {
        Stop-Mcbr 'AccountingInvariant'
    }
    $unique = @($Accounting | Where-Object disposition -CEQ 'UniqueProviderCandidate').Count
    $ambiguous = @($Accounting | Where-Object disposition -CEQ 'Ambiguous').Count
    if ($unique -eq $TargetCabCount) {
        return 'AllProvidersUniquelyIdentified'
    }
    if ($ambiguous -gt 0) {
        return 'AmbiguousProviderCandidates'
    }
    return 'PartialProvidersIdentified'
}

function New-McbrTerminalResult {
    param(
        [Parameter(Mandatory)][object] $Contract,
        [Parameter(Mandatory)][string] $Head,
        [Parameter(Mandatory)][object] $Evidence
    )
    return [pscustomobject][ordered]@{
        schemaVersion = $Contract.schemaVersion
        artifactId = $Contract.artifactId
        status = 'Pending'
        decision = $null
        head = $Head
        elapsedMilliseconds = [int64]0
        timeoutMilliseconds = [int64]$Contract.overallTimeoutMilliseconds
        sourceBoundaryValidated = $false
        scanCompleted = $false
        sourceScanLOUsed = 0
        targetCabCount = $Contract.targetCabCount
        targetCabIds = [string[]]$Evidence.targetCabIds
        scannedSourceCount = 0
        scannedFileCount = 0
        scannedArchiveEntryCount = 0
        scannedBytes = [int64]0
        fileOpenCount = 0
        cabAccounting = @()
        matches = @()
        inputEvidence = [pscustomobject][ordered]@{
            logSha256 = $Evidence.logSha256
            planSha256 = $Evidence.planSha256
            unresolvedRequiredGuidCount = $Evidence.unresolvedRequiredGuidCount
            unresolvedClassification = $Evidence.unresolvedClassification
            unresolvedClassificationTotal = $Evidence.unresolvedClassificationTotal
            placeholderGuid = $Evidence.placeholderGuid
        }
        sourcePathLeakCount = 0
        sourceUnchanged = $true
        blockers = @()
        nextAction = $Contract.nextAction
    }
}

function Write-McbrJsonCreateNew {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][object] $Value
    )
    $json = $Value | ConvertTo-Json -Depth 20
    $leakCount = [regex]::Matches($json, '(?i)(?:[a-z]:[\\/]|\\\\[^\\])').Count
    if ($leakCount -ne 0) {
        Stop-Mcbr 'PortableOutputLeak'
    }
    $parent = Split-Path -Parent $LiteralPath
    [IO.Directory]::CreateDirectory($parent) | Out-Null
    $stream = [IO.File]::Open(
        $LiteralPath,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + "`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function Get-McbrProductionLocatorPath {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        Stop-Mcbr 'SourceBoundary'
    }
    return Join-Path $localAppData 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
}

function Invoke-McbrProductionScan {
    $contract = Get-McbrContract
    $outputPath = ConvertTo-McbrAbsolutePath -Contract $contract -PortablePath $contract.outputPortablePath
    if (Test-Path -LiteralPath $outputPath) {
        Stop-Mcbr 'OutputAlreadyExists'
    }
    $outputRoot = Split-Path -Parent $outputPath
    if (Test-Path -LiteralPath $outputRoot) {
        Stop-Mcbr 'OutputRootAlreadyExists'
    }
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $deadline = [DateTimeOffset]::UtcNow.AddMilliseconds($contract.overallTimeoutMilliseconds)
    $script:McbrEvidence = Read-McbrFrozenEvidence -Contract $contract -DeadlineUtc $deadline
    $head = (& git -C $contract.repositoryRoot rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0 -or $head -cnotmatch '^[0-9a-f]{40}$') {
        Stop-Mcbr 'HeadIdentityFailure'
    }
    $terminal = New-McbrTerminalResult -Contract $contract -Head $head -Evidence $script:McbrEvidence
    $state = New-McbrScanState
    try {
        $boundaries = Get-McbrValidatedSourceBoundaries `
            -LocatorPath (Get-McbrProductionLocatorPath) `
            -ScanSourceKinds $contract.scanSourceKinds `
            -DeadlineUtc $deadline
        $state.sourceBoundaryValidated = $true
        Invoke-McbrBoundaryScan `
            -Contract $contract `
            -Boundaries $boundaries `
            -State $state `
            -DeadlineUtc $deadline
        if (-not $state.sourceUnchanged) {
            Stop-Mcbr 'SourceIdentityDrift'
        }
        $accounting = Get-McbrCabAccounting `
            -TargetCabIds $script:McbrEvidence.targetCabIds `
            -Matches @($state.matches)
        $terminal.decision = Get-McbrDecisionFromAccounting `
            -Accounting $accounting `
            -TargetCabCount $contract.targetCabCount
        if ($terminal.decision -ceq 'AllProvidersUniquelyIdentified') {
            $terminal.status = 'Completed'
        }
        elseif ($terminal.decision -ceq 'AmbiguousProviderCandidates') {
            $terminal.status = 'Blocked'
            $terminal.blockers = @('ProviderCandidateAmbiguity')
        }
        else {
            $terminal.status = 'Blocked'
            $terminal.blockers = @('ProviderCoverageIncomplete')
        }
        $terminal.cabAccounting = $accounting
        $terminal.matches = @($state.matches | Sort-Object cabId, sourceId, relativePath, archiveEntry, offset)
    }
    catch {
        $code = if ($_.Exception.Message -match '^MCBR:(.+)$') { $Matches[1] } else { 'UnclassifiedFailure' }
        if ($code -ceq 'ScanCap') {
            $terminal.decision = 'BlockedScanCap'
            $terminal.status = 'Blocked'
            $terminal.blockers = @('OverallTimeout')
            $terminal.cabAccounting = Get-McbrCabAccounting `
                -TargetCabIds $script:McbrEvidence.targetCabIds `
                -Matches @($state.matches)
            $terminal.matches = @($state.matches | Sort-Object cabId, sourceId, relativePath, archiveEntry, offset)
        }
        elseif ($code -in @('SourceBoundary', 'SourceIdentityDrift')) {
            $terminal.decision = 'BlockedSourceBoundary'
            $terminal.status = 'Blocked'
            $terminal.blockers = @($code)
        }
        else {
            throw
        }
    }
    finally {
        $stopwatch.Stop()
    }
    $terminal.elapsedMilliseconds = [int64]$stopwatch.ElapsedMilliseconds
    $terminal.sourceBoundaryValidated = [bool]$state.sourceBoundaryValidated
    $terminal.scanCompleted = [bool]$state.scanCompleted
    $terminal.sourceScanLOUsed = [int]$state.sourceScanLOUsed
    $terminal.scannedSourceCount = [int]$state.scannedSourceCount
    $terminal.scannedFileCount = [int]$state.scannedFileCount
    $terminal.scannedArchiveEntryCount = [int]$state.scannedArchiveEntryCount
    $terminal.scannedBytes = [int64]$state.scannedBytes
    $terminal.fileOpenCount = [int]$state.fileOpenCount
    $terminal.sourceUnchanged = [bool]$state.sourceUnchanged
    $terminal.sourcePathLeakCount = 0
    Write-McbrJsonCreateNew -LiteralPath $outputPath -Value $terminal
}

if ($env:STELLAGAIA_MCBR_TEST_MODE -cne '1') {
    Invoke-McbrProductionScan
}
