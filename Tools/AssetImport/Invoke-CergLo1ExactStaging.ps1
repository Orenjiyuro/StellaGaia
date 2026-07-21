[CmdletBinding()]
param(
    [string]$CandidateLockPath,
    [string]$PreflightPath,
    [string]$StagingInventoryTemporaryPath,
    [string]$StagingInventoryPath,
    [string]$FreshnessEvidencePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CergStagingImplementationRole = 'ExactLeafStagingWrapper'
$script:CergStagingImplementationVersion = 'CERG-LO1-EXACT-STAGING/3'
$script:CergUtf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:CergOrdinal = [System.StringComparer]::Ordinal
. (Join-Path $PSScriptRoot 'New-CergLo1Preflight.ps1')

function ConvertTo-CergPortablePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $value = $Path.Normalize([System.Text.NormalizationForm]::FormC).Replace('\', '/')
    if ([string]::IsNullOrWhiteSpace($value) -or
        [System.IO.Path]::IsPathRooted($value) -or
        $value.StartsWith('/') -or
        $value.EndsWith('/') -or
        $value.Contains('//') -or
        $value.IndexOfAny([char[]]'*?[]{}') -ge 0) {
        throw "Path must be one exact portable relative leaf: $Path"
    }

    $segments = @($value.Split('/'))
    if ($segments.Count -eq 0 -or @($segments | Where-Object { $_ -in @('', '.', '..') }).Count -ne 0) {
        throw "Path escapes or is not an exact portable relative leaf: $Path"
    }
    return $value
}

function Get-CergFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-CergPathContained {
    param(
        [Parameter(Mandatory = $true)][string]$Leaf,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $rootFull = (Get-CergFullPath -Path $Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $leafFull = Get-CergFullPath -Path $Leaf
    return $leafFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-CergNoReparsePoint {
    param(
        [Parameter(Mandatory = $true)][string]$Leaf,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-CergPathContained -Leaf $Leaf -Root $Root)) {
        throw "$Label escapes its registered root."
    }

    $rootFull = (Get-CergFullPath -Path $Root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $leafFull = Get-CergFullPath -Path $Leaf
    $relative = $leafFull.Substring($rootFull.Length + 1)
    $current = $rootFull
    foreach ($segment in $relative.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
        $current = [System.IO.Path]::Combine($current, $segment)
        if (-not [System.IO.File]::Exists($current) -and -not [System.IO.Directory]::Exists($current)) {
            break
        }
        $attributes = [System.IO.File]::GetAttributes($current)
        if (($attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Label contains a reparse point."
        }
    }
}

function Get-CergSha256Hex {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    $stream = [System.IO.File]::Open($LiteralPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([System.Convert]::ToHexString($sha.ComputeHash($stream))).ToLowerInvariant() }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function ConvertTo-CergCanonicalJsonValue {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) {
        $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormC)
        if ($normalized.Contains([char]0)) { throw 'Canonical strings must not contain U+0000.' }
        return [System.Text.Json.JsonSerializer]::Serialize([object]$normalized, [string], [System.Text.Json.JsonSerializerOptions]::new())
    }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64]) {
        return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [decimal] -or $Value -is [double] -or $Value -is [single]) {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { throw 'Canonical numbers must be finite.' }
        return $number.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant()
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $Value.Keys) {
            $parts.Add((ConvertTo-CergCanonicalJsonValue ([string]$key)) + ':' + (ConvertTo-CergCanonicalJsonValue $Value[$key]))
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [pscustomobject]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($property in $Value.PSObject.Properties) {
            $parts.Add((ConvertTo-CergCanonicalJsonValue $property.Name) + ':' + (ConvertTo-CergCanonicalJsonValue $property.Value))
        }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $Value) { $parts.Add((ConvertTo-CergCanonicalJsonValue $item)) }
        return '[' + ($parts -join ',') + ']'
    }
    throw "Unsupported canonical JSON value type: $($Value.GetType().FullName)"
}

function Get-CergStructuredSha256 {
    param(
        [Parameter(Mandatory = $true)][string]$DomainTag,
        [Parameter(Mandatory = $true)][object]$Payload
    )
    $json = ConvertTo-CergCanonicalJsonValue @($DomainTag, $Payload)
    $bytes = $script:CergUtf8NoBom.GetBytes($json)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return ([System.Convert]::ToHexString($sha.ComputeHash($bytes))).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-CergOrdinalSet {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Values,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $result = [string[]]@($Values | ForEach-Object { ([string]$_).Normalize([System.Text.NormalizationForm]::FormC) })
    [System.Array]::Sort($result, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $result.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($result[$i])) { throw "$Label contains a null or empty identity." }
        if ($i -gt 0 -and $result[$i] -ceq $result[$i - 1]) { throw "$Label contains a duplicate identity: $($result[$i])" }
    }
    return $result
}

function Read-CergJsonFile {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    if (-not [System.IO.File]::Exists($LiteralPath)) { throw "Required JSON leaf is missing: $LiteralPath" }
    return [System.IO.File]::ReadAllText((Get-CergFullPath $LiteralPath), $script:CergUtf8NoBom) | ConvertFrom-Json -Depth 100 -DateKind String
}

function Copy-CergLeafWithHash {
    param(
        [Parameter(Mandatory = $true)][string]$SourceLeaf,
        [Parameter(Mandatory = $true)][string]$DestinationLeaf,
        [Parameter(Mandatory = $true)][long]$ExpectedBytes,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )

    if ([System.IO.Directory]::Exists($SourceLeaf) -or -not [System.IO.File]::Exists($SourceLeaf)) {
        throw 'Registered source member must resolve to one existing file leaf.'
    }
    if ([System.IO.File]::Exists($DestinationLeaf) -or [System.IO.Directory]::Exists($DestinationLeaf)) {
        throw 'A staging destination may not pre-exist.'
    }
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($DestinationLeaf)) | Out-Null

    $source = [System.IO.File]::Open($SourceLeaf, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
    try {
        $destination = [System.IO.File]::Open($DestinationLeaf, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try {
                $buffer = [byte[]]::new(1MB)
                [long]$count = 0
                while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $destination.Write($buffer, 0, $read)
                    [void]$sha.TransformBlock($buffer, 0, $read, $null, 0)
                    $count += $read
                    if ($count -gt $ExpectedBytes) { throw 'Source member exceeds its registered byte count.' }
                }
                [void]$sha.TransformFinalBlock([byte[]]::new(0), 0, 0)
                $digest = ([System.Convert]::ToHexString($sha.Hash)).ToLowerInvariant()
                if ($count -ne $ExpectedBytes -or $digest -cne $ExpectedSha256) {
                    throw 'Source member byte count or SHA-256 does not match the registered tuple.'
                }
                return [pscustomobject][ordered]@{ byteCount = $count; sha256 = $digest }
            }
            finally { $sha.Dispose() }
        }
        finally { $destination.Dispose() }
    }
    catch {
        if ([System.IO.File]::Exists($DestinationLeaf)) { [System.IO.File]::Delete($DestinationLeaf) }
        throw
    }
    finally { $source.Dispose() }
}

function Invoke-CergLo1ExactStaging {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CandidateLockPath,
        [Parameter(Mandatory = $true)][string]$PreflightPath,
        [Parameter(Mandatory = $true)][string]$StagingInventoryTemporaryPath,
        [Parameter(Mandatory = $true)][string]$StagingInventoryPath,
        [string]$FreshnessEvidencePath
    )

    if ([System.IO.File]::Exists($StagingInventoryTemporaryPath) -or [System.IO.File]::Exists($StagingInventoryPath)) {
        throw 'Staging inventory temporary/final output must both be initially absent.'
    }
    $candidate = Read-CergJsonFile -LiteralPath $CandidateLockPath
    $preflight = Read-CergJsonFile -LiteralPath $PreflightPath
    if ($preflight.candidateLockSha256 -cne (Get-CergSha256Hex -LiteralPath $CandidateLockPath)) { throw 'PreflightConsumerContractFailure: P01 candidate lock raw SHA is stale or spliced.' }
    $freshness = if(-not[string]::IsNullOrWhiteSpace($FreshnessEvidencePath)){Read-CergJsonFile -LiteralPath $FreshnessEvidencePath}else{$null}
    $null = Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $preflight -Freshness $freshness -FreshnessEvidencePath $FreshnessEvidencePath -StagingInventoryTemporaryPath $StagingInventoryTemporaryPath -StagingInventoryPath $StagingInventoryPath
    if ($candidate.status -cne 'Passed' -or $preflight.status -cne 'Green') { throw 'Candidate lock and preflight must be consumable.' }
    if ($candidate.selectedCandidateId -cne $preflight.selectedCandidateId) { throw 'Candidate identity mismatch.' }

    $sourceMembers = if($preflight.schemaVersion -ceq 'cerg-lo-cerg1-preflight/1.5.0'){@($freshness.currentMembers|ForEach-Object{[pscustomobject]@{memberId=$_.memberId;sourceId=$_.sourceId;portableRelativePath=$_.portableRelativePath;sizeBytes=[int64]$_.byteCount;sha256=$_.sha256}})}else{@($candidate.sourceMembers)}
    $rootBindings = @($preflight.sourceRootBindings)
    $planRows = @($preflight.stagingPlan.memberRows)
    if ($sourceMembers.Count -eq 0 -or $sourceMembers.Count -ne $planRows.Count) { throw 'Source-member/staging-plan cardinality mismatch.' }
    $sourceMemberIds = @(Get-CergOrdinalSet @($sourceMembers | ForEach-Object { $_.memberId }) 'Candidate SourceMembers')
    $planSourceMemberIds = @(Get-CergOrdinalSet @($planRows | ForEach-Object { $_.sourceMemberRefId }) 'Staging plan SourceMember references')
    $operationSourceMemberIds = @(Get-CergOrdinalSet @($preflight.operation.inputMemberRefIds) 'Operation input SourceMember references')
    $sourceSetBytes = ConvertTo-CergCanonicalJsonValue $sourceMemberIds
    if ((ConvertTo-CergCanonicalJsonValue $planSourceMemberIds) -cne $sourceSetBytes -or
        (ConvertTo-CergCanonicalJsonValue $operationSourceMemberIds) -cne $sourceSetBytes) {
        throw 'SourceMemberBijectionFailure: candidate, operation, and staging-plan member-ID sets differ.'
    }
    if ([int64]$preflight.operation.sourceReadMaxFiles -ne $sourceMembers.Count) { throw 'sourceReadMaxFiles must equal the exact member count.' }
    $expectedBytes = ($sourceMembers | Measure-Object -Property sizeBytes -Sum).Sum
    if ([int64]$preflight.operation.sourceReadMaxBytes -ne [int64]$expectedBytes) { throw 'sourceReadMaxBytes must equal the exact member byte sum.' }

    $memberById = @{}
    foreach ($member in $sourceMembers) {
        if ($memberById.ContainsKey([string]$member.memberId)) { throw 'Duplicate source member identity.' }
        $memberById[[string]$member.memberId] = $member
    }
    $rootById = @{}
    foreach ($binding in $rootBindings) {
        if ($rootById.ContainsKey([string]$binding.sourceId)) { throw 'Duplicate source root binding.' }
        $root = Get-CergFullPath ([string]$binding.privateAbsoluteReadOnlyRoot)
        if (-not [System.IO.Directory]::Exists($root)) { throw 'A source root binding must be an existing directory.' }
        if (($binding.privateAbsoluteReadOnlyRoot.IndexOfAny([char[]]'*?[]{}')) -ge 0) { throw 'Source root bindings may not contain selectors.' }
        $rootById[[string]$binding.sourceId] = $root
    }

    $stagingRoot = Get-CergFullPath ([string]$preflight.stagingPlan.stagingInputPrivateAbsolutePath)
    if ([System.IO.Directory]::Exists($stagingRoot) -or [System.IO.File]::Exists($stagingRoot)) { throw 'Staging root must be fresh and initially absent.' }
    [System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null

    $inventoryRows = [System.Collections.Generic.List[object]]::new()
    $orderedPlanRows = [object[]]@($planRows)
    $planComparer = [System.Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{
        param($left, $right)
        return [string]::CompareOrdinal([string]$left.stagingPortableRelativePath, [string]$right.stagingPortableRelativePath)
    })
    [System.Array]::Sort($orderedPlanRows, $planComparer)
    $stagingPrefix = (ConvertTo-CergPortablePath ([string]$preflight.stagingPlan.stagingInputPortablePath)).TrimEnd('/') + '/'
    foreach ($row in $orderedPlanRows) {
        $memberId = [string]$row.sourceMemberRefId
        if (-not $memberById.ContainsKey($memberId)) { throw 'Staging row references an unknown source member.' }
        $member = $memberById[$memberId]
        if ($member.sourceId -cne $row.sourceId -or $member.portableRelativePath -cne $row.sourcePortableRelativePath -or
            [int64]$member.sizeBytes -ne [int64]$row.byteCount -or $member.sha256 -cne $row.sha256) {
            throw 'Staging row is not byte-identical to its SourceMember tuple.'
        }
        if (-not $rootById.ContainsKey([string]$row.sourceId)) { throw 'No exact root binding exists for a source member.' }

        $sourceRelative = ConvertTo-CergPortablePath ([string]$row.sourcePortableRelativePath)
        $stagingPortable = ConvertTo-CergPortablePath ([string]$row.stagingPortableRelativePath)
        $sourceLeaf = Get-CergFullPath ([System.IO.Path]::Combine($rootById[[string]$row.sourceId], $sourceRelative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
        if (-not $stagingPortable.StartsWith($stagingPrefix, [System.StringComparison]::Ordinal)) { throw 'Staging leaf is outside the frozen portable staging root.' }
        $stagingRelative = $stagingPortable.Substring($stagingPrefix.Length)
        $stagingLeaf = Get-CergFullPath ([System.IO.Path]::Combine($stagingRoot, $stagingRelative.Replace('/', [System.IO.Path]::DirectorySeparatorChar)))
        Assert-CergNoReparsePoint -Leaf $sourceLeaf -Root $rootById[[string]$row.sourceId] -Label 'Source member'
        if (-not (Test-CergPathContained -Leaf $stagingLeaf -Root $stagingRoot)) { throw 'Staging leaf escapes its attempt-owned root.' }
        $copied = Copy-CergLeafWithHash -SourceLeaf $sourceLeaf -DestinationLeaf $stagingLeaf -ExpectedBytes ([int64]$row.byteCount) -ExpectedSha256 ([string]$row.sha256)
        $inventoryRows.Add([pscustomobject][ordered]@{
            sourceMemberRefId = $memberId
            sourceId = [string]$row.sourceId
            sourcePortableRelativePath = $sourceRelative
            stagingPortableRelativePath = $stagingPortable
            byteCount = [int64]$copied.byteCount
            sha256 = [string]$copied.sha256
        })
    }

    $actualLeaves = @([System.IO.Directory]::EnumerateFiles($stagingRoot, '*', [System.IO.SearchOption]::AllDirectories) | ForEach-Object {
        $full = Get-CergFullPath $_
        $relative = $full.Substring($stagingRoot.TrimEnd('\', '/').Length + 1).Replace('\', '/')
        [pscustomobject]@{ path = $stagingPrefix + $relative; byteCount = [System.IO.FileInfo]::new($full).Length; sha256 = Get-CergSha256Hex $full }
    })
    $actualComparer = [System.Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{
        param($left, $right)
        return [string]::CompareOrdinal([string]$left.path, [string]$right.path)
    })
    [System.Array]::Sort($actualLeaves, $actualComparer)
    if ($actualLeaves.Count -ne $inventoryRows.Count) { throw 'Staging bijection failed: unexpected or missing leaf.' }
    for ($i = 0; $i -lt $inventoryRows.Count; $i++) {
        if ($actualLeaves[$i].path -cne $inventoryRows[$i].stagingPortableRelativePath -or
            [int64]$actualLeaves[$i].byteCount -ne [int64]$inventoryRows[$i].byteCount -or
            $actualLeaves[$i].sha256 -cne $inventoryRows[$i].sha256) {
            throw 'Staging bijection failed: staged identity mismatch.'
        }
    }
    $inventorySourceMemberIds = @(Get-CergOrdinalSet @($inventoryRows | ForEach-Object { $_.sourceMemberRefId }) 'Staging inventory SourceMember references')
    if ((ConvertTo-CergCanonicalJsonValue $inventorySourceMemberIds) -cne $sourceSetBytes) {
        throw 'SourceMemberBijectionFailure: staged inventory does not conserve every SourceMember exactly once.'
    }

    $fingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($inventoryRows)
    if ($preflight.stagingPlan.memberSetFingerprint -cne $fingerprint) { throw 'Staging member-set fingerprint mismatch.' }
    $inventory = [pscustomobject][ordered]@{
        schemaVersion = 'cerg-lo-cerg1-staging-inventory/1.0.0'
        artifactId = 'LO-CERG1-SI01'
        candidateLockSha256 = Get-CergSha256Hex $CandidateLockPath
        preflightSha256 = Get-CergSha256Hex $PreflightPath
        selectedCandidateId = [string]$candidate.selectedCandidateId
        memberRows = @($inventoryRows)
        memberCount = $inventoryRows.Count
        byteCount = [int64](($inventoryRows | Measure-Object -Property byteCount -Sum).Sum)
        memberSetFingerprint = $fingerprint
        status = 'Complete'
    }
    $canonical = ConvertTo-CergCanonicalJsonValue $inventory
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName((Get-CergFullPath $StagingInventoryTemporaryPath))) | Out-Null
    [System.IO.File]::WriteAllText((Get-CergFullPath $StagingInventoryTemporaryPath), $canonical, $script:CergUtf8NoBom)
    $reopened = [System.IO.File]::ReadAllText((Get-CergFullPath $StagingInventoryTemporaryPath), $script:CergUtf8NoBom)
    if ($reopened -cne $canonical) { throw 'Staging inventory temporary bytes failed canonical reopen validation.' }
    if ([System.IO.File]::Exists($StagingInventoryPath)) { throw 'Staging inventory final path may not be overwritten.' }
    [System.IO.File]::Move((Get-CergFullPath $StagingInventoryTemporaryPath), (Get-CergFullPath $StagingInventoryPath))
    return $inventory
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($CandidateLockPath) -or [string]::IsNullOrWhiteSpace($PreflightPath) -or
        [string]::IsNullOrWhiteSpace($StagingInventoryTemporaryPath) -or [string]::IsNullOrWhiteSpace($StagingInventoryPath)) {
        throw 'CandidateLockPath, PreflightPath, StagingInventoryTemporaryPath, and StagingInventoryPath are required.'
    }
    Invoke-CergLo1ExactStaging @PSBoundParameters | ConvertTo-Json -Depth 10
}
