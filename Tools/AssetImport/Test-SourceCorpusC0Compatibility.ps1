[CmdletBinding()]
param(
    [ValidateSet('C0Schema', 'Handoff', 'All')]
    [string] $Case = 'All'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$issues = [System.Collections.Generic.List[string]]::new()
$verifiedNegativeFixtureCount = 0
$verifiedNestedMutationCount = 0
$childProcessCount = 0
$heavyChildProcessCount = 0
$c0SchemaCompatible = $false
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('stella-c1-c0-' + [guid]::NewGuid().ToString('N'))
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$modulePath = Join-Path $PSScriptRoot 'SourceCorpusGate.psm1'
$handoffPath = Join-Path $PSScriptRoot 'Fixtures\SourceCorpusGate\valid-c2-source-corpus-handoff.json'

function Add-Issue([string] $Message) { $issues.Add($Message) }

function Read-StrictJson {
    param([Parameter(Mandatory)][string] $Path)
    $text = [System.IO.File]::ReadAllText($Path)
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    try {
        $duplicates = [System.Collections.Generic.List[string]]::new()
        function Test-Element([System.Text.Json.JsonElement] $Element, [string] $JsonPath) {
            if ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object) {
                $names = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
                foreach ($property in $Element.EnumerateObject()) {
                    if (-not $names.Add($property.Name)) { $duplicates.Add("$JsonPath.$($property.Name)") }
                    Test-Element $property.Value "$JsonPath.$($property.Name)"
                }
            }
            elseif ($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
                $index = 0
                foreach ($item in $Element.EnumerateArray()) { Test-Element $item "$JsonPath[$index]"; $index++ }
            }
        }
        Test-Element $document.RootElement '$'
        if ($duplicates.Count -ne 0) { throw "Duplicate JSON properties: $($duplicates -join ', ')" }
        return ($text | ConvertFrom-Json -Depth 100 -DateKind String)
    }
    finally { $document.Dispose() }
}

function Test-ExactProperties {
    param([object] $Value, [string[]] $Expected)
    return $Value -is [System.Management.Automation.PSCustomObject] -and
        (($Value.PSObject.Properties.Name -join '|') -ceq ($Expected -join '|'))
}

function Test-TrueNonnegativeInteger([object] $Value) {
    return $null -ne $Value -and
        $Value.GetType() -in @([byte], [sbyte], [int16], [uint16], [int32], [uint32], [int64], [uint64]) -and
        [decimal]$Value -ge 0
}

function Get-PortablePathIssue {
    param([string] $Value, [string] $Label)
    if ([string]::IsNullOrWhiteSpace($Value)) { return "$Label must be repository-relative." }
    if ($Value.IndexOfAny([char[]]@([char]0,[char]10,[char]13)) -ge 0) { return "$Label contains forbidden control characters." }
    if ($Value.Contains('\')) { return "$Label must use forward slashes." }
    if ([System.IO.Path]::IsPathRooted($Value) -or $Value.StartsWith('//', [System.StringComparison]::Ordinal)) { return "$Label must be repository-relative." }
    if ($Value -match '^[A-Za-z][A-Za-z0-9+.-]*:') { return "$Label must not be a URI." }
    if ($Value -match '(^|/)\.{1,2}(/|$)') { return "$Label must not contain dot segments." }
    if ($Value.StartsWith('/') -or $Value.EndsWith('/') -or $Value.Contains('//')) { return "$Label is not a normalized repository path." }
    return $null
}

function Assert-SafeExistingPath {
    param([Parameter(Mandatory)][string] $Path, [ValidateSet('Any','Leaf','Container')][string] $ExpectedType = 'Any')
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $segments = [System.Collections.Generic.Stack[string]]::new()
    $cursor = $fullPath
    while ($true) {
        $segments.Push($cursor)
        $parent = [System.IO.Path]::GetDirectoryName($cursor)
        if ([string]::IsNullOrEmpty($parent) -or $parent -ceq $cursor) { break }
        $cursor = $parent
    }
    while ($segments.Count -gt 0) {
        $segment = $segments.Pop()
        $item = Get-Item -LiteralPath $segment -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0 -or -not [string]::IsNullOrEmpty([string]$item.LinkType)) {
            throw "Reparse point is forbidden: $segment"
        }
    }
    $target = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
    if ($ExpectedType -ceq 'Leaf' -and ($target -isnot [System.IO.FileInfo] -or $target.PSIsContainer)) { throw "Expected genuine file: $fullPath" }
    if ($ExpectedType -ceq 'Container' -and ($target -isnot [System.IO.DirectoryInfo] -or -not $target.PSIsContainer)) { throw "Expected genuine directory: $fullPath" }
    return $target
}

function Assert-SafeDirectoryTree {
    param([Parameter(Mandatory)][string] $Path)
    $null = Assert-SafeExistingPath -Path $Path -ExpectedType Container
    $pending = [System.Collections.Generic.Queue[string]]::new()
    $pending.Enqueue([System.IO.Path]::GetFullPath($Path))
    while ($pending.Count -gt 0) {
        $directory = $pending.Dequeue()
        foreach ($entry in @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop)) {
            $expected = if ($entry.PSIsContainer) { 'Container' } else { 'Leaf' }
            $null = Assert-SafeExistingPath -Path $entry.FullName -ExpectedType $expected
            if ($entry.PSIsContainer) { $pending.Enqueue($entry.FullName) }
        }
    }
}

function Read-SafeHandoffFixture {
    param([Parameter(Mandatory)][string] $Path, [Parameter(Mandatory)][string] $AllowedRoot)
    $root = [System.IO.Path]::GetFullPath($AllowedRoot).TrimEnd('\','/')
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $fullPath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { throw 'C2 handoff fixture path escapes its allowed root.' }
    $null = Assert-SafeExistingPath -Path $root -ExpectedType Container
    $null = Assert-SafeExistingPath -Path $fullPath -ExpectedType Leaf
    return Read-StrictJson $fullPath
}

function Test-DateTimeString([object] $Value) {
    if ($Value -isnot [string]) { return $false }
    $parsed = [datetimeoffset]::MinValue
    return [datetimeoffset]::TryParse($Value, [ref]$parsed)
}

function Test-NonemptyString([object] $Value) { return $Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value) }

function Test-CanonicalSourceId([object] $Value) {
    return (Test-NonemptyString $Value) -and $Value.IndexOfAny([char[]]@([char]0,[char]10,[char]13)) -lt 0
}

function Test-ActualArray([object] $Value) { return $Value -is [object[]] }

function Test-NoMachineData {
    param([AllowNull()][object] $Value, [int] $Depth = 0)
    if ($Depth -gt 64) { return $false }
    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) {
        return -not [System.IO.Path]::IsPathRooted($Value) -and $Value -cnotmatch '^[A-Za-z][A-Za-z0-9+.-]*://'
    }
    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -ceq 'rootPath' -or -not (Test-NoMachineData $property.Value ($Depth + 1))) { return $false }
        }
    }
    elseif ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) { if (-not (Test-NoMachineData $item ($Depth + 1))) { return $false } }
    }
    return $true
}

function Get-CheckedTotal {
    param([object[]] $Values)
    [decimal]$total = 0
    foreach ($value in $Values) {
        if (-not (Test-TrueNonnegativeInteger $value)) { throw 'Invalid nonnegative integer.' }
        $total += [decimal]$value
        if ($total -gt [long]::MaxValue) { throw 'Int64 total overflow.' }
    }
    return [long]$total
}

function Get-ReferencedLedgerContractIssue {
    param([object] $Ledger)
    if (-not (Test-ExactProperties $Ledger @('schemaVersion','snapshotId','generatedAt','inputFingerprint','toolVersions','sources','files','objects')) -or
        $Ledger.schemaVersion -isnot [string] -or $Ledger.schemaVersion -cne '1.0.0' -or -not (Test-NonemptyString $Ledger.snapshotId) -or
        -not (Test-DateTimeString $Ledger.generatedAt) -or $Ledger.inputFingerprint -isnot [string] -or $Ledger.inputFingerprint -cnotmatch '^[0-9a-f]{64}$') {
        return 'Referenced C1 ledger top-level contract is invalid.'
    }
    if (-not (Test-ActualArray $Ledger.toolVersions)) { return 'Referenced C1 ledger toolVersion contract is invalid.' }
    foreach ($tool in $Ledger.toolVersions) {
        if (-not (Test-ExactProperties $tool @('toolName','version')) -or -not (Test-NonemptyString $tool.toolName) -or -not (Test-NonemptyString $tool.version)) {
            return 'Referenced C1 ledger toolVersion contract is invalid.'
        }
    }
    if (-not (Test-ActualArray $Ledger.sources)) { return 'Referenced C1 ledger source contract is invalid.' }
    $sourceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($source in $Ledger.sources) {
        if (-not (Test-ExactProperties $source @('sourceId','sourceKind','capturedAt','rootFingerprint')) -or
            -not (Test-CanonicalSourceId $source.sourceId) -or -not $sourceIds.Add($source.sourceId) -or
            $source.sourceKind -isnot [string] -or $source.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
            -not (Test-DateTimeString $source.capturedAt) -or $source.capturedAt -cne $Ledger.generatedAt -or
            $source.rootFingerprint -isnot [string] -or $source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$') {
            return 'Referenced C1 ledger source contract is invalid.'
        }
    }
    if (-not (Test-ActualArray $Ledger.files)) { return 'Referenced C1 ledger file contract is invalid.' }
    $filePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $filePathsIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $statusVocabulary = @{
        corpus=@('Cataloged','Missing','StaleInput'); extraction=@('NotAttempted','ExtractedReadable','CrossToolVerified','Opaque','Failed')
        semantics=@('Known','PartiallyKnown','Unknown'); unity=@('NotTested','StaticQualified','RepresentativeValidated','Rejected','UnityExecutionUnavailable')
        disposition=@('NeedsDiagnosis','UseOriginalAsset','RepairOnce','PrototypeReplacement','RetainForLater','DiagnosticOnly','Stop')
    }
    foreach ($file in $Ledger.files) {
        if ($file -is [System.Management.Automation.PSCustomObject] -and $file.PSObject.Properties.Name -ccontains 'relativePath' -and
            ($file.relativePath -isnot [string] -or $null -ne (Get-PortablePathIssue $file.relativePath 'file.relativePath'))) {
            return 'Referenced C1 ledger file path identity contract is invalid.'
        }
        if (-not (Test-ExactProperties $file @('snapshotId','sourceId','sourceKind','relativePath','sizeBytes','sha256','capturedAt','containerKind','parseStatus','disposition','evidence','status')) -or
            $file.snapshotId -isnot [string] -or $file.snapshotId -cne $Ledger.snapshotId -or -not (Test-NonemptyString $file.sourceId) -or -not $sourceIds.Contains($file.sourceId) -or
            $file.sourceKind -isnot [string] -or $file.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
            $file.relativePath -isnot [string] -or
            -not (Test-TrueNonnegativeInteger $file.sizeBytes) -or $file.sha256 -isnot [string] -or $file.sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            -not (Test-DateTimeString $file.capturedAt) -or $file.capturedAt -cne $Ledger.generatedAt -or -not (Test-NonemptyString $file.containerKind) -or
            $file.containerKind -cnotin @('UnityBundle','UnitySerializedAsset','DirectAudio','AudioMetadata','DirectVideo','Metadata','ConfigurationCandidate','UnknownInput') -or
            $file.parseStatus -isnot [string] -or $file.parseStatus -cnotin @('NotAttempted','ExtractedReadable','CrossToolVerified','Opaque','Failed') -or
            $file.disposition -isnot [string] -or $file.disposition -cnotin $statusVocabulary.disposition -or -not (Test-ActualArray $file.evidence) -or
            -not (Test-ExactProperties $file.status @('corpus','extraction','semantics','unity','disposition'))) {
            return 'Referenced C1 ledger file contract is invalid.'
        }
        if (-not $filePaths.Add($file.relativePath) -or -not $filePathsIgnoreCase.Add($file.relativePath)) { return 'Referenced C1 ledger file path identity contract is invalid.' }
        $evidencePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $evidencePathsIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $owningSource = @($Ledger.sources | Where-Object sourceId -CEQ $file.sourceId)
        if ($owningSource.Count -ne 1 -or $owningSource[0].sourceKind -cne $file.sourceKind -or $file.status.disposition -cne $file.disposition) { return 'Referenced C1 ledger file contract is invalid.' }
        foreach ($path in $file.evidence) { if ($path -isnot [string] -or $null -ne (Get-PortablePathIssue $path 'file.evidence') -or -not $evidencePaths.Add($path) -or -not $evidencePathsIgnoreCase.Add($path)) { return 'Referenced C1 ledger file path identity contract is invalid.' } }
        foreach ($dimension in $statusVocabulary.Keys) {
            if ($file.status.$dimension -isnot [string] -or $file.status.$dimension -cnotin $statusVocabulary[$dimension]) { return 'Referenced C1 ledger file contract is invalid.' }
        }
    }
    if (-not (Test-ActualArray $Ledger.objects) -or $Ledger.objects.Count -ne 0) { return 'Referenced C1 ledger objects must be an empty array before G2.' }
    if (-not (Test-NoMachineData $Ledger)) { return 'Referenced C1 ledger contains machine-local data.' }
    return $null
}

function Get-ReferencedSummaryContractIssue {
    param([object] $Summary, [object] $Ledger)
    $top = @('schemaVersion','generatedAt','snapshotId','inputFingerprint','ledgerInputFingerprint','ledgerPath','toolVersions','operationIdentity','directChildSummaries','directChildReports','failureAttribution','nextAllowedAction','sourceCount','sourceFileCount','catalogedFileCount','explicitlyExcludedFileCount','sourceBytes','catalogedBytes','explicitlyExcludedBytes','sources','exclusions')
    if (-not (Test-ExactProperties $Summary $top) -or $Summary.schemaVersion -isnot [string] -or $Summary.schemaVersion -cne '1.0.0' -or
        -not (Test-DateTimeString $Summary.generatedAt) -or -not (Test-NonemptyString $Summary.snapshotId) -or
        $Summary.inputFingerprint -isnot [string] -or $Summary.inputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or
        $Summary.ledgerInputFingerprint -isnot [string] -or $Summary.ledgerInputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or
        $Summary.ledgerPath -isnot [string] -or $null -ne (Get-PortablePathIssue $Summary.ledgerPath 'summary.ledgerPath')) {
        return 'Referenced C1 summary top-level contract is invalid.'
    }
    if (-not (Test-ActualArray $Summary.toolVersions)) { return 'Referenced C1 summary toolVersion contract is invalid.' }
    foreach ($tool in $Summary.toolVersions) { if (-not (Test-ExactProperties $tool @('toolName','version')) -or -not (Test-NonemptyString $tool.toolName) -or -not (Test-NonemptyString $tool.version)) { return 'Referenced C1 summary toolVersion contract is invalid.' } }
    if (-not (Test-ActualArray $Summary.directChildSummaries) -or -not (Test-ActualArray $Summary.directChildReports)) { return 'Referenced C1 summary child path arrays are invalid.' }
    foreach ($path in @($Summary.directChildSummaries) + @($Summary.directChildReports)) { if ($path -isnot [string] -or $null -ne (Get-PortablePathIssue $path 'summary child path')) { return 'Referenced C1 summary child path arrays are invalid.' } }
    if ($Summary.directChildSummaries.Count -ne 1 -or $Summary.directChildSummaries[0] -cne $Summary.ledgerPath -or $Summary.directChildReports.Count -ne 0) { return 'Referenced C1 summary child path arrays are invalid.' }
    foreach ($name in @('operationIdentity','failureAttribution','nextAllowedAction')) { if (-not (Test-NonemptyString $Summary.$name)) { return 'Referenced C1 summary narrative contract is invalid.' } }
    foreach ($name in @('sourceCount','sourceFileCount','catalogedFileCount','explicitlyExcludedFileCount','sourceBytes','catalogedBytes','explicitlyExcludedBytes')) { if (-not (Test-TrueNonnegativeInteger $Summary.$name)) { return 'Referenced C1 summary count contract is invalid.' } }
    if (-not (Test-ActualArray $Summary.sources)) { return 'Referenced C1 summary source contract is invalid.' }
    $summarySourceIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($source in $Summary.sources) {
        if (-not (Test-ExactProperties $source @('sourceId','sourceKind','rootFingerprint','sourceFileCount','sourceBytes')) -or -not (Test-CanonicalSourceId $source.sourceId) -or -not $summarySourceIds.Add($source.sourceId) -or
            $source.sourceKind -isnot [string] -or $source.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
            $source.rootFingerprint -isnot [string] -or $source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$' -or
            -not (Test-TrueNonnegativeInteger $source.sourceFileCount) -or -not (Test-TrueNonnegativeInteger $source.sourceBytes)) { return 'Referenced C1 summary source contract is invalid.' }
    }
    if (-not (Test-ActualArray $Summary.exclusions)) { return 'Referenced C1 summary exclusion contract is invalid.' }
    $exclusionKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $exclusionKeysIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $catalogKeysIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $Ledger.files) { $null = $catalogKeysIgnoreCase.Add($file.sourceId + [char]0 + $file.relativePath) }
    foreach ($exclusion in $Summary.exclusions) {
        if (-not (Test-ExactProperties $exclusion @('sourceId','relativePath','sizeBytes','reason')) -or -not (Test-CanonicalSourceId $exclusion.sourceId) -or
            $exclusion.relativePath -isnot [string] -or $null -ne (Get-PortablePathIssue $exclusion.relativePath 'summary exclusion') -or
            -not (Test-TrueNonnegativeInteger $exclusion.sizeBytes) -or -not (Test-NonemptyString $exclusion.reason)) { return 'Referenced C1 summary exclusion contract is invalid.' }
        $key = $exclusion.sourceId + [char]0 + $exclusion.relativePath
        if (-not $summarySourceIds.Contains($exclusion.sourceId) -or -not $exclusionKeys.Add($key) -or -not $exclusionKeysIgnoreCase.Add($key) -or $catalogKeysIgnoreCase.Contains($key)) { return 'Referenced C1 summary exclusion identity contract is invalid.' }
    }
    if (-not (Test-NoMachineData $Summary)) { return 'Referenced C1 summary contains machine-local data.' }
    try {
        $ledgerFileBytes = Get-CheckedTotal @($Ledger.files | ForEach-Object sizeBytes)
        $summarySourceFiles = Get-CheckedTotal @($Summary.sources | ForEach-Object sourceFileCount)
        $summarySourceBytes = Get-CheckedTotal @($Summary.sources | ForEach-Object sourceBytes)
        $excludedBytes = Get-CheckedTotal @($Summary.exclusions | ForEach-Object sizeBytes)
        $conservedFileCount = Get-CheckedTotal @($Summary.catalogedFileCount, $Summary.explicitlyExcludedFileCount)
        $conservedBytes = Get-CheckedTotal @($Summary.catalogedBytes, $Summary.explicitlyExcludedBytes)
    }
    catch { return 'Referenced C1 summary count contract is invalid.' }
    if ($Summary.snapshotId -cne $Ledger.snapshotId -or $Summary.inputFingerprint -cne $Ledger.inputFingerprint -or $Summary.ledgerInputFingerprint -cne $Ledger.inputFingerprint -or $Summary.generatedAt -cne $Ledger.generatedAt) { return 'Referenced C1 ledger and summary identities disagree.' }
    if ([long]$Summary.sourceCount -ne $Ledger.sources.Count -or [long]$Summary.sourceCount -ne $Summary.sources.Count -or [long]$Summary.catalogedFileCount -ne $Ledger.files.Count -or [long]$Summary.catalogedBytes -ne $ledgerFileBytes -or
        [long]$Summary.sourceFileCount -ne $summarySourceFiles -or [long]$Summary.sourceBytes -ne $summarySourceBytes -or
        [long]$Summary.explicitlyExcludedFileCount -ne $Summary.exclusions.Count -or [long]$Summary.explicitlyExcludedBytes -ne $excludedBytes -or
        [long]$Summary.sourceFileCount -ne $conservedFileCount -or [long]$Summary.sourceBytes -ne $conservedBytes) { return 'Referenced C1 summary conservation contract is invalid.' }
    foreach ($source in $Summary.sources) {
        $ledgerSource = @($Ledger.sources | Where-Object sourceId -CEQ $source.sourceId)
        if ($ledgerSource.Count -ne 1 -or $ledgerSource[0].sourceKind -cne $source.sourceKind -or $ledgerSource[0].rootFingerprint -cne $source.rootFingerprint) { return 'Referenced C1 summary source identity contract is invalid.' }
        $fileCount = @($Ledger.files | Where-Object sourceId -CEQ $source.sourceId).Count
        $fileBytes = Get-CheckedTotal @($Ledger.files | Where-Object sourceId -CEQ $source.sourceId | ForEach-Object sizeBytes)
        $sourceExclusions = @($Summary.exclusions | Where-Object sourceId -CEQ $source.sourceId)
        $sourceExcludedBytes = Get-CheckedTotal @($sourceExclusions | ForEach-Object sizeBytes)
        $conservedSourceFiles = Get-CheckedTotal @($fileCount, $sourceExclusions.Count)
        $conservedSourceBytes = Get-CheckedTotal @($fileBytes, $sourceExcludedBytes)
        if ([long]$source.sourceFileCount -ne $conservedSourceFiles -or [long]$source.sourceBytes -ne $conservedSourceBytes) { return 'Referenced C1 summary per-source conservation contract is invalid.' }
    }
    return $null
}

function Get-HandoffIssues {
    param([object] $Handoff, [string] $FixtureRepositoryRoot = $repositoryRoot)
    $found = [System.Collections.Generic.List[string]]::new()
    $expected = @('schemaVersion','ledgerPath','summaryPath','snapshotId','inputFingerprint','sourceCount','fileCount','fileBytes','objectCount')
    if (-not (Test-ExactProperties $Handoff $expected)) { $found.Add('Invalid C2 handoff property contract.'); return $found.ToArray() }
    if ($Handoff.schemaVersion -isnot [string] -or $Handoff.schemaVersion -cne '1.0.0') { $found.Add('Invalid C2 handoff schemaVersion.'); return $found.ToArray() }
    foreach ($label in @('ledgerPath', 'summaryPath')) {
        if ($Handoff.$label -isnot [string]) { $found.Add("$label must be repository-relative."); return $found.ToArray() }
        $pathIssue = Get-PortablePathIssue -Value $Handoff.$label -Label $label
        if ($null -ne $pathIssue) { $found.Add($pathIssue); return $found.ToArray() }
    }
    if ($Handoff.ledgerPath -cne 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json' -or
        $Handoff.summaryPath -cne 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json') {
        $found.Add('C2 handoff paths do not match the frozen C1 fixtures.'); return $found.ToArray()
    }
    if ($Handoff.snapshotId -isnot [string] -or [string]::IsNullOrWhiteSpace($Handoff.snapshotId) -or
        $Handoff.inputFingerprint -isnot [string] -or $Handoff.inputFingerprint -cnotmatch '^[0-9a-f]{64}$') {
        $found.Add('Invalid C2 handoff identity.'); return $found.ToArray()
    }
    foreach ($name in @('sourceCount','fileCount','fileBytes','objectCount')) {
        if (-not (Test-TrueNonnegativeInteger $Handoff.$name)) { $found.Add("$name must be a nonnegative integer."); return $found.ToArray() }
    }
    if ([long]$Handoff.objectCount -ne 0) { $found.Add('objectCount must be 0 without G2 evidence.'); return $found.ToArray() }

    $fixtureRoot = [System.IO.Path]::GetFullPath($FixtureRepositoryRoot)
    $ledgerFullPath = [System.IO.Path]::GetFullPath((Join-Path $fixtureRoot $Handoff.ledgerPath))
    $summaryFullPath = [System.IO.Path]::GetFullPath((Join-Path $fixtureRoot $Handoff.summaryPath))
    try { $null = Assert-SafeExistingPath -Path $fixtureRoot -ExpectedType Container }
    catch { $found.Add('Referenced C1 fixture path is unsafe.'); return $found.ToArray() }
    foreach ($resolved in @($ledgerFullPath, $summaryFullPath)) {
        $prefix = $fixtureRoot.TrimEnd('\','/') + [System.IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { $found.Add('C2 handoff path escapes the repository.'); return $found.ToArray() }
        try { $null = Assert-SafeExistingPath -Path $resolved -ExpectedType Leaf }
        catch { $found.Add('Referenced C1 fixture path is unsafe.'); return $found.ToArray() }
    }
    try { $ledger = Read-StrictJson $ledgerFullPath; $summary = Read-StrictJson $summaryFullPath }
    catch { $found.Add("Referenced C1 fixture is invalid JSON: $($_.Exception.Message)"); return $found.ToArray() }
    $ledgerContractIssue = Get-ReferencedLedgerContractIssue $ledger
    if ($null -ne $ledgerContractIssue) { $found.Add($ledgerContractIssue); return $found.ToArray() }
    $summaryContractIssue = Get-ReferencedSummaryContractIssue -Summary $summary -Ledger $ledger
    if ($null -ne $summaryContractIssue) { $found.Add($summaryContractIssue); return $found.ToArray() }
    if ($summary.ledgerPath -cne $Handoff.ledgerPath -or $ledger.snapshotId -cne $summary.snapshotId -or
        $ledger.inputFingerprint -cne $summary.inputFingerprint -or $summary.ledgerInputFingerprint -cne $ledger.inputFingerprint) {
        $found.Add('Referenced C1 ledger and summary identities disagree.'); return $found.ToArray()
    }
    if ($Handoff.inputFingerprint -cne $ledger.inputFingerprint) { $found.Add('Handoff input fingerprint is stale.') }
    if ($Handoff.snapshotId -cne $ledger.snapshotId) { $found.Add('Handoff snapshotId is stale.') }
    $fileBytes = [long]0
    foreach ($file in @($ledger.files)) { $fileBytes = [long]([decimal]$fileBytes + [decimal]$file.sizeBytes) }
    if ([long]$Handoff.sourceCount -ne @($ledger.sources).Count -or [long]$Handoff.sourceCount -ne [long]$summary.sourceCount) { $found.Add('Handoff sourceCount is stale.') }
    if ([long]$Handoff.fileCount -ne @($ledger.files).Count -or [long]$Handoff.fileCount -ne [long]$summary.catalogedFileCount) { $found.Add('Handoff fileCount is stale.') }
    if ([long]$Handoff.fileBytes -ne $fileBytes -or [long]$Handoff.fileBytes -ne [long]$summary.catalogedBytes) { $found.Add('Handoff fileBytes is stale.') }
    if ([long]$Handoff.objectCount -ne @($ledger.objects).Count) { $found.Add('Handoff objectCount is stale.') }
    return $found.ToArray()
}

function Invoke-C0SchemaCompatibility {
    Import-Module $modulePath -Force
    $sourceRoot = Join-Path $tempRoot 'source'
    [System.IO.Directory]::CreateDirectory($sourceRoot) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $sourceRoot 'alpha.bin'), 'alpha', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $sourceRoot 'beta.unknown'), 'beta', [System.Text.UTF8Encoding]::new($false))
    $capturedAt = [datetimeoffset]'2026-07-10T04:00:00Z'
    $catalog = New-SourceCorpusCatalog -SnapshotId 'snapshot-c0-compatibility' -SourceId 'synthetic-source' -SourceKind 'PcInstall' -RootPath $sourceRoot -CapturedAt $capturedAt
    $rootFingerprint = Get-SourceRootFingerprint -Files @($catalog.files)
    $sourceRow = [pscustomobject][ordered]@{ sourceId='synthetic-source'; sourceKind='PcInstall'; capturedAt=$capturedAt.ToUniversalTime().ToString('O'); rootFingerprint=$rootFingerprint }
    $inputFingerprint = Get-SourceInputFingerprint -Sources @($sourceRow)
    $ledger = [pscustomobject][ordered]@{
        schemaVersion='1.0.0'; snapshotId='snapshot-c0-compatibility'; generatedAt=$capturedAt.ToUniversalTime().ToString('O')
        inputFingerprint=$inputFingerprint; toolVersions=@([pscustomobject][ordered]@{toolName='source-corpus-gate';version='1.0.0'})
        sources=@($sourceRow); files=@($catalog.files); objects=@()
    }
    $ledgerText = $ledger | ConvertTo-Json -Depth 100
    $generatedPath = Join-Path $tempRoot 'generated-ledger.json'
    [System.IO.File]::WriteAllText($generatedPath, $ledgerText, [System.Text.UTF8Encoding]::new($false))
    $null = Read-StrictJson $generatedPath
    if ($ledgerText -match '(?i)rootPath|stella-c1-c0-|[A-Z]:\\|file://') { throw 'Generated C1 ledger leaked machine-local data.' }

    $fixtureCopy = Join-Path $tempRoot 'AssetCorpusContracts'
    $checkedInFixtureRoot = Join-Path $PSScriptRoot 'Fixtures\AssetCorpusContracts'
    $null = Assert-SafeExistingPath -Path $repositoryRoot -ExpectedType Container
    Assert-SafeDirectoryTree -Path $checkedInFixtureRoot
    $null = Assert-SafeExistingPath -Path $tempRoot -ExpectedType Container
    if ($IsWindows) {
        $copyProbeSource = Join-Path $tempRoot 'copy-source-probe'; $copyProbeOutside = Join-Path $tempRoot 'copy-source-outside'; $copyProbeDestination = Join-Path $tempRoot 'copy-probe-destination'
        [System.IO.Directory]::CreateDirectory($copyProbeSource) | Out-Null; [System.IO.Directory]::CreateDirectory($copyProbeOutside) | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $copyProbeOutside 'outside-secret.txt'), 'must-not-copy', [System.Text.UTF8Encoding]::new($false))
        try { $null = New-Item -ItemType Junction -Path (Join-Path $copyProbeSource 'linked') -Target $copyProbeOutside -ErrorAction Stop }
        catch { throw "Junction setup failed on supported Windows: $($_.Exception.Message)" }
        $rejected = $false
        try { Assert-SafeDirectoryTree -Path $copyProbeSource }
        catch { $rejected = $true }
        if (-not $rejected -or [System.IO.Directory]::Exists($copyProbeDestination)) { throw 'Copy-source junction was not rejected before copy.' }
        $script:verifiedNestedMutationCount++
    }
    Copy-Item -LiteralPath $checkedInFixtureRoot -Destination $fixtureCopy -Recurse -Force
    Assert-SafeDirectoryTree -Path $fixtureCopy
    [System.IO.File]::WriteAllText((Join-Path $fixtureCopy 'valid-source-corpus-ledger.json'), $ledgerText, [System.Text.UTF8Encoding]::new($false))
    $null = Assert-SafeExistingPath -Path (Join-Path $fixtureCopy 'valid-source-corpus-ledger.json') -ExpectedType Leaf
    $contractRoot = Join-Path $repositoryRoot 'docs\asset-migration\schemas'
    $harnessPath = Join-Path $PSScriptRoot 'Test-AssetCorpusContract.ps1'
    $stdoutPath = Join-Path $tempRoot 'c0.stdout.txt'; $stderrPath = Join-Path $tempRoot 'c0.stderr.txt'
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $process.StartInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    foreach ($argument in @('-NoProfile','-File',$harnessPath,'-ContractRoot',$contractRoot,'-FixtureRoot',$fixtureCopy)) { $null = $process.StartInfo.ArgumentList.Add($argument) }
    $process.StartInfo.UseShellExecute = $false; $process.StartInfo.RedirectStandardOutput = $true; $process.StartInfo.RedirectStandardError = $true
    $null = $process.Start(); $script:childProcessCount++
    $stdout = $process.StandardOutput.ReadToEnd(); $stderr = $process.StandardError.ReadToEnd(); $process.WaitForExit()
    [System.IO.File]::WriteAllText($stdoutPath, $stdout, [System.Text.UTF8Encoding]::new($false)); [System.IO.File]::WriteAllText($stderrPath, $stderr, [System.Text.UTF8Encoding]::new($false))
    if ($process.ExitCode -ne 0) { throw "C0 contract harness exited $($process.ExitCode): $($stderr.Trim()) $($stdout.Trim())" }
    $lines = @($stdout -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -ne 1) { throw "C0 contract harness emitted $($lines.Count) stdout lines." }
    $childResultPath = Join-Path $tempRoot 'c0-result.json'; [System.IO.File]::WriteAllText($childResultPath, $lines[0], [System.Text.UTF8Encoding]::new($false))
    $childResult = Read-StrictJson $childResultPath
    if ($childResult.status -cne 'Passed' -or [int]$childResult.issueCount -ne 0) { throw 'C0 contract harness did not report Passed with zero issues.' }
    $script:c0SchemaCompatible = $true
}

function Invoke-Handoff {
    $positive = Read-SafeHandoffFixture -Path $handoffPath -AllowedRoot $repositoryRoot
    $positiveIssues = @(Get-HandoffIssues $positive)
    if ($positiveIssues.Count -ne 0) { throw "Positive C2 handoff failed: $($positiveIssues -join ' | ')" }
    $vectors = @(
        @{ Name='wrong inputFingerprint'; Issue='Handoff input fingerprint is stale.'; Mutate={ param($v) $v.inputFingerprint='dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd' } },
        @{ Name='absolute path'; Issue='ledgerPath must be repository-relative.'; Mutate={ param($v) $v.ledgerPath='C:/machine/private.json' } },
        @{ Name='URI path'; Issue='summaryPath must not be a URI.'; Mutate={ param($v) $v.summaryPath='https://example.invalid/private.json' } },
        @{ Name='dot-segment path'; Issue='ledgerPath must not contain dot segments.'; Mutate={ param($v) $v.ledgerPath='Tools/../private.json' } },
        @{ Name='nonzero objectCount'; Issue='objectCount must be 0 without G2 evidence.'; Mutate={ param($v) $v.objectCount=1 } }
    )
    foreach ($vector in $vectors) {
        $copy = (($positive | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -Depth 100 -DateKind String)
        & $vector.Mutate $copy
        $actual = @(Get-HandoffIssues $copy)
        if ($actual.Count -eq 1 -and $actual[0] -ceq $vector.Issue) { $script:verifiedNegativeFixtureCount++ }
        else { throw "Negative vector '$($vector.Name)' mismatch. Expected [$($vector.Issue)]; actual [$($actual -join ' | ')]." }
    }

    $mirrorRoot = Join-Path $tempRoot 'handoff-mirror'
    $mirrorFixtureRoot = Join-Path $mirrorRoot 'Tools\AssetImport\Fixtures\SourceCorpusGate'
    [System.IO.Directory]::CreateDirectory($mirrorFixtureRoot) | Out-Null
    $realFixtureRoot = Join-Path $PSScriptRoot 'Fixtures\SourceCorpusGate'
    foreach ($name in @('valid-c1-source-corpus-ledger.json','valid-source-corpus-summary.json')) {
        Copy-Item -LiteralPath (Join-Path $realFixtureRoot $name) -Destination (Join-Path $mirrorFixtureRoot $name) -Force
    }
    $nestedVectors = @(
        @{ Name='missing file status'; Target='ledger'; Issue='Referenced C1 ledger file contract is invalid.'; Mutate={ param($v) $v.files[0].PSObject.Properties.Remove('status') } },
        @{ Name='string sizeBytes'; Target='ledger'; Issue='Referenced C1 ledger file contract is invalid.'; Mutate={ param($v) $v.files[0].sizeBytes='4096' } },
        @{ Name='fraction sizeBytes'; Target='ledger'; Issue='Referenced C1 ledger file contract is invalid.'; Mutate={ param($v) $v.files[0].sizeBytes=4096.5 } },
        @{ Name='invalid disposition vocabulary'; Target='ledger'; Issue='Referenced C1 ledger file contract is invalid.'; Mutate={ param($v) $v.files[0].disposition='Invented' } },
        @{ Name='invalid status vocabulary'; Target='ledger'; Issue='Referenced C1 ledger file contract is invalid.'; Mutate={ param($v) $v.files[0].status.corpus='Invented' } },
        @{ Name='malformed source'; Target='ledger'; Issue='Referenced C1 ledger source contract is invalid.'; Mutate={ param($v) $v.sources[0].rootFingerprint='UPPER' } },
        @{ Name='malformed toolVersion'; Target='ledger'; Issue='Referenced C1 ledger toolVersion contract is invalid.'; Mutate={ param($v) $v.toolVersions[0].version='' } },
        @{ Name='malformed summary source'; Target='summary'; Issue='Referenced C1 summary source contract is invalid.'; Mutate={ param($v) $v.sources[0].sourceBytes='4096' } },
        @{ Name='scalar directChildSummaries'; Target='summary'; Issue='Referenced C1 summary child path arrays are invalid.'; Mutate={ param($v) $v.directChildSummaries=$v.directChildSummaries[0] } },
        @{ Name='scalar directChildReports'; Target='summary'; Issue='Referenced C1 summary child path arrays are invalid.'; Mutate={ param($v) $v.directChildReports='report.json' } },
        @{ Name='control character path'; Target='ledger'; Issue='Referenced C1 ledger file path identity contract is invalid.'; Mutate={ param($v) $v.files[0].relativePath="bad`npath.bin" } },
        @{ Name='double slash path'; Target='ledger'; Issue='Referenced C1 ledger file path identity contract is invalid.'; Mutate={ param($v) $v.files[0].relativePath='bad//path.bin' } },
        @{ Name='trailing slash path'; Target='ledger'; Issue='Referenced C1 ledger file path identity contract is invalid.'; Mutate={ param($v) $v.files[0].relativePath='bad/path/' } },
        @{ Name='duplicate ledger path'; Target='ledger'; Issue='Referenced C1 ledger file path identity contract is invalid.'; Mutate={ param($v) $v.files += (($v.files[0] | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -Depth 100 -DateKind String) } },
        @{ Name='case-colliding ledger path'; Target='ledger'; Issue='Referenced C1 ledger file path identity contract is invalid.'; Mutate={ param($v) $copy=(($v.files[0]|ConvertTo-Json -Depth 100 -Compress)|ConvertFrom-Json -Depth 100 -DateKind String);$copy.relativePath=$copy.relativePath.ToUpperInvariant();$v.files += $copy } },
        @{ Name='sourceId control character'; Target='ledger'; Issue='Referenced C1 ledger source contract is invalid.'; Mutate={ param($v) $v.sources[0].sourceId="bad`rsource" } },
        @{ Name='duplicate source identity'; Target='ledger'; Issue='Referenced C1 ledger source contract is invalid.'; Mutate={ param($v) $v.sources += (($v.sources[0]|ConvertTo-Json -Depth 100 -Compress)|ConvertFrom-Json -Depth 100 -DateKind String) } },
        @{ Name='unknown exclusion source'; Target='summary'; Issue='Referenced C1 summary exclusion identity contract is invalid.'; Mutate={ param($v) $v.exclusions=@([pscustomobject][ordered]@{sourceId='unknown';relativePath='excluded.bin';sizeBytes=0;reason='test'}) } },
        @{ Name='duplicate exclusion path'; Target='summary'; Issue='Referenced C1 summary exclusion identity contract is invalid.'; Mutate={ param($v) $e=[pscustomobject][ordered]@{sourceId='pc-install-primary';relativePath='excluded.bin';sizeBytes=0;reason='test'};$v.exclusions=@($e,(($e|ConvertTo-Json -Compress)|ConvertFrom-Json -DateKind String)) } },
        @{ Name='case-colliding exclusion path'; Target='summary'; Issue='Referenced C1 summary exclusion identity contract is invalid.'; Mutate={ param($v) $v.exclusions=@([pscustomobject][ordered]@{sourceId='pc-install-primary';relativePath='excluded.bin';sizeBytes=0;reason='test'},[pscustomobject][ordered]@{sourceId='pc-install-primary';relativePath='EXCLUDED.BIN';sizeBytes=0;reason='test'}) } },
        @{ Name='exclusion overlap'; Target='summary'; Issue='Referenced C1 summary exclusion identity contract is invalid.'; Mutate={ param($v) $v.exclusions=@([pscustomobject][ordered]@{sourceId='pc-install-primary';relativePath='SourceCorpus/PcInstall/game-data.bundle';sizeBytes=0;reason='test'}) } }
    )
    foreach ($vector in $nestedVectors) {
        foreach ($name in @('valid-c1-source-corpus-ledger.json','valid-source-corpus-summary.json')) {
            Copy-Item -LiteralPath (Join-Path $realFixtureRoot $name) -Destination (Join-Path $mirrorFixtureRoot $name) -Force
        }
        $targetName = if ($vector.Target -ceq 'ledger') { 'valid-c1-source-corpus-ledger.json' } else { 'valid-source-corpus-summary.json' }
        $targetPath = Join-Path $mirrorFixtureRoot $targetName
        $mutated = Read-StrictJson $targetPath
        & $vector.Mutate $mutated
        [System.IO.File]::WriteAllText($targetPath, ($mutated | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
        $actual = @(Get-HandoffIssues -Handoff $positive -FixtureRepositoryRoot $mirrorRoot)
        if ($actual.Count -ne 1 -or $actual[0] -cne $vector.Issue) {
            throw "Nested vector '$($vector.Name)' mismatch. Expected [$($vector.Issue)]; actual [$($actual -join ' | ')]."
        }
        $script:verifiedNestedMutationCount++
    }

    if ($IsWindows) {
        $outsideRoot = Join-Path $tempRoot 'junction-outside'
        $junctionMirror = Join-Path $tempRoot 'junction-mirror'
        $outsideFixtures = Join-Path $outsideRoot 'Tools\AssetImport\Fixtures\SourceCorpusGate'
        $junctionParent = Join-Path $junctionMirror 'Tools\AssetImport\Fixtures'
        [System.IO.Directory]::CreateDirectory($outsideFixtures) | Out-Null
        [System.IO.Directory]::CreateDirectory($junctionParent) | Out-Null
        foreach ($name in @('valid-c1-source-corpus-ledger.json','valid-source-corpus-summary.json')) { Copy-Item -LiteralPath (Join-Path $realFixtureRoot $name) -Destination (Join-Path $outsideFixtures $name) -Force }
        try { $null = New-Item -ItemType Junction -Path (Join-Path $junctionParent 'SourceCorpusGate') -Target $outsideFixtures -ErrorAction Stop }
        catch { throw "Junction setup failed on supported Windows: $($_.Exception.Message)" }
        $junctionIssues = @(Get-HandoffIssues -Handoff $positive -FixtureRepositoryRoot $junctionMirror)
        if ($junctionIssues.Count -ne 1 -or $junctionIssues[0] -cne 'Referenced C1 fixture path is unsafe.') { throw "Referenced junction probe mismatch: $($junctionIssues -join ' | ')" }
        $script:verifiedNestedMutationCount++

        $handoffOutside = Join-Path $tempRoot 'handoff-outside'
        $handoffMirror = Join-Path $tempRoot 'handoff-junction-mirror'
        $handoffOutsideFixture = Join-Path $handoffOutside 'SourceCorpusGate'
        $handoffMirrorParent = Join-Path $handoffMirror 'Tools\AssetImport\Fixtures'
        [System.IO.Directory]::CreateDirectory($handoffOutsideFixture) | Out-Null
        [System.IO.Directory]::CreateDirectory($handoffMirrorParent) | Out-Null
        $outsideHandoffPath = Join-Path $handoffOutsideFixture 'valid-c2-source-corpus-handoff.json'
        [System.IO.File]::WriteAllText($outsideHandoffPath, ($positive | ConvertTo-Json -Depth 100), [System.Text.UTF8Encoding]::new($false))
        try { $null = New-Item -ItemType Junction -Path (Join-Path $handoffMirrorParent 'SourceCorpusGate') -Target $handoffOutsideFixture -ErrorAction Stop }
        catch { throw "Handoff junction setup failed on supported Windows: $($_.Exception.Message)" }
        $handoffThroughJunction = Join-Path $handoffMirror 'Tools\AssetImport\Fixtures\SourceCorpusGate\valid-c2-source-corpus-handoff.json'
        $junctionRejected = $false
        try { $null = Read-SafeHandoffFixture -Path $handoffThroughJunction -AllowedRoot $handoffMirror }
        catch { $junctionRejected = $true }
        if (-not $junctionRejected) { throw 'Handoff fixture ancestor junction was read instead of rejected.' }
        $script:verifiedNestedMutationCount++

        $leafMirror = Join-Path $tempRoot 'handoff-leaf-mirror'
        $leafParent = Join-Path $leafMirror 'Tools\AssetImport\Fixtures\SourceCorpusGate'
        [System.IO.Directory]::CreateDirectory($leafParent) | Out-Null
        $leafPath = Join-Path $leafParent 'valid-c2-source-corpus-handoff.json'
        $leafCreated = $false
        try { $null = New-Item -ItemType SymbolicLink -Path $leafPath -Target $outsideHandoffPath -ErrorAction Stop; $leafCreated = $true }
        catch { $leafCreated = $false }
        if ($leafCreated) {
            $leafRejected = $false
            try { $null = Read-SafeHandoffFixture -Path $leafPath -AllowedRoot $leafMirror }
            catch { $leafRejected = $true }
            if (-not $leafRejected) { throw 'Direct handoff fixture symlink was read instead of rejected.' }
        }
    }
}

try {
    [System.IO.Directory]::CreateDirectory($tempRoot) | Out-Null
    if ($Case -in @('C0Schema','All')) { Invoke-C0SchemaCompatibility }
    if ($Case -in @('Handoff','All')) { Invoke-Handoff }
}
catch { Add-Issue $_.Exception.Message }
finally {
    if ([System.IO.Directory]::Exists($tempRoot)) { Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$leftoverTempRootCount = if ([System.IO.Directory]::Exists($tempRoot)) { 1 } else { 0 }
if ($leftoverTempRootCount -ne 0) { Add-Issue "Temporary root was not removed: $tempRoot" }
$stopwatch.Stop()
$result = [pscustomobject][ordered]@{
    status = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $issues.Count
    issues = $issues.ToArray()
    c0SchemaCompatible = $c0SchemaCompatible
    verifiedNegativeFixtureCount = $verifiedNegativeFixtureCount
    verifiedNestedMutationCount = $verifiedNestedMutationCount
    childProcessCount = $childProcessCount
    heavyChildProcessCount = $heavyChildProcessCount
    leftoverTempRootCount = $leftoverTempRootCount
    durationMs = $stopwatch.ElapsedMilliseconds
}
Write-Output ($result | ConvertTo-Json -Depth 10 -Compress)
if ($issues.Count -ne 0) { throw "C1 C0 compatibility validation failed with $($issues.Count) issue(s)." }
