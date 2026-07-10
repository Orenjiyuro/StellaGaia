[CmdletBinding()]
param(
    [Parameter()]
    [string] $SummaryPath,

    [Parameter()]
    [string] $LedgerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$issues = [System.Collections.Generic.List[string]]::new()
$fixtureRoot = Join-Path $PSScriptRoot 'Fixtures\SourceCorpusGate'
if ([string]::IsNullOrWhiteSpace($SummaryPath)) {
    $SummaryPath = Join-Path $fixtureRoot 'valid-source-corpus-summary.json'
}
if ([string]::IsNullOrWhiteSpace($LedgerPath)) {
    $LedgerPath = Join-Path $fixtureRoot 'valid-c1-source-corpus-ledger.json'
}

function Read-StrictJsonObject {
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $IssueList.Add("Missing contract file: $Path")
        return $null
    }

    $document = $null
    try {
        $text = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw 'Contract JSON is empty.'
        }
        $document = [System.Text.Json.JsonDocument]::Parse($text)
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Contract JSON root must be an object.'
        }
        $value = $text | ConvertFrom-Json -Depth 100 -DateKind String
        if ($value -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Contract JSON root must be an object.'
        }
        return $value
    }
    catch {
        $IssueList.Add("Invalid JSON contract file: $Path")
        return $null
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Get-PropertyValue {
    param(
        [Parameter()][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Name
    )

    if ($null -eq $Value -or $Value -isnot [System.Management.Automation.PSCustomObject]) {
        return $null
    }
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Test-ExactProperties {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string[]] $Expected,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    if ($Value -isnot [System.Management.Automation.PSCustomObject]) {
        $IssueList.Add("$Location must be an object.")
        return $false
    }
    $actual = @($Value.PSObject.Properties.Name)
    foreach ($name in $Expected) {
        if ($name -cnotin $actual) {
            $IssueList.Add("$Location is missing required property '$name'.")
        }
    }
    foreach ($name in $actual) {
        if ($name -cnotin $Expected) {
            $IssueList.Add("$Location contains unexpected property '$name'.")
        }
    }
    return $actual.Count -eq $Expected.Count -and @($Expected | Where-Object { $_ -cnotin $actual }).Count -eq 0
}

function Test-IsJsonInteger {
    param([Parameter()][AllowNull()][object] $Value)

    return (
        $Value -is [sbyte] -or $Value -is [byte] -or
        $Value -is [int16] -or $Value -is [uint16] -or
        $Value -is [int32] -or $Value -is [uint32] -or
        $Value -is [int64] -or $Value -is [uint64]
    )
}

function Test-StringProperty {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList,
        [Parameter()][switch] $AllowEmpty,
        [Parameter()][string] $Pattern,
        [Parameter()][string[]] $AllowedValues
    )

    $property = if ($null -eq $Value) { $null } else { $Value.PSObject.Properties[$Name] }
    $propertyValue = $null
    if ($null -ne $property) { $propertyValue = $property.Value }
    if ($propertyValue -isnot [string] -or (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($propertyValue))) {
        $stringRequirement = if ($AllowEmpty) { 'a string' } else { 'a non-empty string' }
        $IssueList.Add("$Location property '$Name' must be $stringRequirement.")
        return $false
    }
    if (-not [string]::IsNullOrEmpty($Pattern) -and $propertyValue -cnotmatch $Pattern) {
        $IssueList.Add("$Location property '$Name' has an invalid value.")
        return $false
    }
    if ($null -ne $AllowedValues -and $propertyValue -cnotin $AllowedValues) {
        $IssueList.Add("$Location property '$Name' has an invalid value.")
        return $false
    }
    return $true
}

function Test-IntegerProperty {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $propertyValue = Get-PropertyValue -Value $Value -Name $Name
    if (-not (Test-IsJsonInteger -Value $propertyValue) -or [decimal]$propertyValue -lt 0) {
        $IssueList.Add("$Location property '$Name' must be a non-negative JSON integer.")
        return $false
    }
    return $true
}

function Test-ArrayProperty {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $property = if ($null -eq $Value) { $null } else { $Value.PSObject.Properties[$Name] }
    $propertyValue = $null
    if ($null -ne $property) { $propertyValue = $property.Value }
    if ($propertyValue -isnot [System.Array]) {
        $IssueList.Add("$Location property '$Name' must be a JSON array.")
        return $false
    }
    return $true
}

function Test-PortablePathString {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value) -or
        $Value -cmatch '^[A-Za-z][A-Za-z0-9+.-]*:' -or
        $Value -cmatch '^[\\/]' -or
        $Value -cmatch '(^|[\\/])\.{1,2}([\\/]|$)') {
        $IssueList.Add("$Location must be a portable non-empty path string.")
        return $false
    }
    return $true
}

function Test-DateTimeProperty {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Value,
        [Parameter(Mandatory)][string] $Name,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $propertyValue = Get-PropertyValue -Value $Value -Name $Name
    $parsed = [datetimeoffset]::MinValue
    $hasIsoShape = $propertyValue -is [string] -and $propertyValue -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
    $isDateTime = $hasIsoShape -and [datetimeoffset]::TryParse(
        $propertyValue,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
    if (-not $isDateTime) {
        $IssueList.Add("$Location property '$Name' must be a valid date-time string.")
        return $false
    }
    return $true
}

function Get-IntegerSum {
    param(
        [Parameter()][object[]] $Rows,
        [Parameter(Mandatory)][string] $Property
    )

    [long] $sum = 0
    foreach ($row in @($Rows)) {
        $sum += [long](Get-PropertyValue -Value $row -Name $Property)
    }
    return $sum
}

function Test-SummaryStructure {
    param(
        [Parameter(Mandatory)][object] $Summary,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $summaryProperties = @(
        'schemaVersion', 'generatedAt', 'snapshotId', 'inputFingerprint',
        'ledgerInputFingerprint', 'ledgerPath', 'toolVersions', 'operationIdentity',
        'directChildSummaries', 'directChildReports', 'failureAttribution',
        'nextAllowedAction', 'sourceCount', 'sourceFileCount', 'catalogedFileCount',
        'explicitlyExcludedFileCount', 'sourceBytes', 'catalogedBytes',
        'explicitlyExcludedBytes', 'sources', 'exclusions'
    )
    $isValid = Test-ExactProperties -Value $Summary -Expected $summaryProperties -Location 'Source corpus summary' -IssueList $IssueList
    if (-not $isValid) { return $false }

    $isValid = (Test-StringProperty -Value $Summary -Name 'schemaVersion' -Location 'Source corpus summary' -IssueList $IssueList -AllowedValues @('1.0.0')) -and $isValid
    $isValid = (Test-DateTimeProperty -Value $Summary -Name 'generatedAt' -Location 'Source corpus summary' -IssueList $IssueList) -and $isValid
    foreach ($name in @('snapshotId', 'operationIdentity', 'failureAttribution', 'nextAllowedAction')) {
        $isValid = (Test-StringProperty -Value $Summary -Name $name -Location 'Source corpus summary' -IssueList $IssueList) -and $isValid
    }
    foreach ($name in @('inputFingerprint', 'ledgerInputFingerprint')) {
        $isValid = (Test-StringProperty -Value $Summary -Name $name -Location 'Source corpus summary' -IssueList $IssueList -Pattern '^[0-9a-f]{64}$') -and $isValid
    }
    $isValid = (Test-PortablePathString -Value (Get-PropertyValue -Value $Summary -Name 'ledgerPath') -Location "Source corpus summary property 'ledgerPath'" -IssueList $IssueList) -and $isValid
    foreach ($name in @('sourceCount', 'sourceFileCount', 'catalogedFileCount', 'explicitlyExcludedFileCount', 'sourceBytes', 'catalogedBytes', 'explicitlyExcludedBytes')) {
        $isValid = (Test-IntegerProperty -Value $Summary -Name $name -Location 'Source corpus summary' -IssueList $IssueList) -and $isValid
    }
    foreach ($name in @('toolVersions', 'directChildSummaries', 'directChildReports', 'sources', 'exclusions')) {
        $isValid = (Test-ArrayProperty -Value $Summary -Name $name -Location 'Source corpus summary' -IssueList $IssueList) -and $isValid
    }
    if (-not $isValid) { return $false }

    foreach ($toolVersion in $Summary.PSObject.Properties['toolVersions'].Value) {
        $rowValid = Test-ExactProperties -Value $toolVersion -Expected @('toolName', 'version') -Location 'Source corpus summary tool version row' -IssueList $IssueList
        if ($rowValid) {
            $rowValid = (Test-StringProperty -Value $toolVersion -Name 'toolName' -Location 'Source corpus summary tool version row' -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $toolVersion -Name 'version' -Location 'Source corpus summary tool version row' -IssueList $IssueList) -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    foreach ($name in @('directChildSummaries', 'directChildReports')) {
        $index = 0
        foreach ($path in $Summary.PSObject.Properties[$name].Value) {
            $isValid = (Test-PortablePathString -Value $path -Location "Source corpus summary property '$name' item $index" -IssueList $IssueList) -and $isValid
            $index++
        }
    }
    foreach ($source in $Summary.PSObject.Properties['sources'].Value) {
        $rowValid = Test-ExactProperties -Value $source -Expected @('sourceId', 'sourceKind', 'rootFingerprint', 'sourceFileCount', 'sourceBytes') -Location 'Source corpus summary source row' -IssueList $IssueList
        if ($rowValid) {
            $rowValid = (Test-StringProperty -Value $source -Name 'sourceId' -Location 'Source corpus summary source row' -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $source -Name 'sourceKind' -Location 'Source corpus summary source row' -IssueList $IssueList -AllowedValues @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')) -and $rowValid
            $rowValid = (Test-StringProperty -Value $source -Name 'rootFingerprint' -Location 'Source corpus summary source row' -IssueList $IssueList -Pattern '^[0-9a-f]{64}$') -and $rowValid
            $rowValid = (Test-IntegerProperty -Value $source -Name 'sourceFileCount' -Location 'Source corpus summary source row' -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-IntegerProperty -Value $source -Name 'sourceBytes' -Location 'Source corpus summary source row' -IssueList $IssueList) -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    foreach ($exclusion in $Summary.PSObject.Properties['exclusions'].Value) {
        $rowValid = Test-ExactProperties -Value $exclusion -Expected @('sourceId', 'relativePath', 'sizeBytes', 'reason') -Location 'Source corpus summary exclusion row' -IssueList $IssueList
        if ($rowValid) {
            $rowValid = (Test-StringProperty -Value $exclusion -Name 'sourceId' -Location 'Source corpus summary exclusion row' -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-PortablePathString -Value (Get-PropertyValue -Value $exclusion -Name 'relativePath') -Location "Source corpus summary exclusion row property 'relativePath'" -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-IntegerProperty -Value $exclusion -Name 'sizeBytes' -Location 'Source corpus summary exclusion row' -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $exclusion -Name 'reason' -Location 'Source corpus summary exclusion row' -IssueList $IssueList -AllowEmpty) -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    return $isValid
}

function Test-StatusStructure {
    param(
        [Parameter(Mandatory)][AllowNull()][object] $Status,
        [Parameter(Mandatory)][string] $Location,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $isValid = Test-ExactProperties -Value $Status -Expected @('corpus', 'extraction', 'semantics', 'unity', 'disposition') -Location $Location -IssueList $IssueList
    if (-not $isValid) { return $false }
    $isValid = (Test-StringProperty -Value $Status -Name 'corpus' -Location $Location -IssueList $IssueList -AllowedValues @('Cataloged', 'Missing', 'StaleInput')) -and $isValid
    $isValid = (Test-StringProperty -Value $Status -Name 'extraction' -Location $Location -IssueList $IssueList -AllowedValues @('NotAttempted', 'ExtractedReadable', 'CrossToolVerified', 'Opaque', 'Failed')) -and $isValid
    $isValid = (Test-StringProperty -Value $Status -Name 'semantics' -Location $Location -IssueList $IssueList -AllowedValues @('Known', 'PartiallyKnown', 'Unknown')) -and $isValid
    $isValid = (Test-StringProperty -Value $Status -Name 'unity' -Location $Location -IssueList $IssueList -AllowedValues @('NotTested', 'StaticQualified', 'RepresentativeValidated', 'Rejected', 'UnityExecutionUnavailable')) -and $isValid
    $isValid = (Test-StringProperty -Value $Status -Name 'disposition' -Location $Location -IssueList $IssueList -AllowedValues @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')) -and $isValid
    return $isValid
}

function Test-LedgerStructure {
    param(
        [Parameter(Mandatory)][object] $Ledger,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.List[string]] $IssueList
    )

    $location = 'Source corpus ledger'
    $isValid = Test-ExactProperties -Value $Ledger -Expected @('schemaVersion', 'snapshotId', 'generatedAt', 'inputFingerprint', 'toolVersions', 'sources', 'files', 'objects') -Location $location -IssueList $IssueList
    if (-not $isValid) { return $false }
    $isValid = (Test-StringProperty -Value $Ledger -Name 'schemaVersion' -Location $location -IssueList $IssueList -AllowedValues @('1.0.0')) -and $isValid
    $isValid = (Test-StringProperty -Value $Ledger -Name 'snapshotId' -Location $location -IssueList $IssueList) -and $isValid
    $isValid = (Test-DateTimeProperty -Value $Ledger -Name 'generatedAt' -Location $location -IssueList $IssueList) -and $isValid
    $isValid = (Test-StringProperty -Value $Ledger -Name 'inputFingerprint' -Location $location -IssueList $IssueList -Pattern '^[0-9a-f]{64}$') -and $isValid
    foreach ($name in @('toolVersions', 'sources', 'files', 'objects')) {
        $isValid = (Test-ArrayProperty -Value $Ledger -Name $name -Location $location -IssueList $IssueList) -and $isValid
    }
    if (-not $isValid) { return $false }

    foreach ($toolVersion in $Ledger.PSObject.Properties['toolVersions'].Value) {
        $rowLocation = 'Source corpus ledger tool version row'
        $rowValid = Test-ExactProperties -Value $toolVersion -Expected @('toolName', 'version') -Location $rowLocation -IssueList $IssueList
        if ($rowValid) {
            $rowValid = (Test-StringProperty -Value $toolVersion -Name 'toolName' -Location $rowLocation -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $toolVersion -Name 'version' -Location $rowLocation -IssueList $IssueList) -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    foreach ($source in $Ledger.PSObject.Properties['sources'].Value) {
        $rowLocation = 'Source corpus ledger source row'
        $rowValid = Test-ExactProperties -Value $source -Expected @('sourceId', 'sourceKind', 'capturedAt', 'rootFingerprint') -Location $rowLocation -IssueList $IssueList
        if ($rowValid) {
            $rowValid = (Test-StringProperty -Value $source -Name 'sourceId' -Location $rowLocation -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $source -Name 'sourceKind' -Location $rowLocation -IssueList $IssueList -AllowedValues @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')) -and $rowValid
            $rowValid = (Test-DateTimeProperty -Value $source -Name 'capturedAt' -Location $rowLocation -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $source -Name 'rootFingerprint' -Location $rowLocation -IssueList $IssueList -Pattern '^[0-9a-f]{64}$') -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    foreach ($file in $Ledger.PSObject.Properties['files'].Value) {
        $rowLocation = 'Source corpus ledger file row'
        $rowValid = Test-ExactProperties -Value $file -Expected @('snapshotId', 'sourceId', 'sourceKind', 'relativePath', 'sizeBytes', 'sha256', 'capturedAt', 'containerKind', 'parseStatus', 'disposition', 'evidence', 'status') -Location $rowLocation -IssueList $IssueList
        if ($rowValid) {
            foreach ($name in @('snapshotId', 'sourceId', 'containerKind')) {
                $rowValid = (Test-StringProperty -Value $file -Name $name -Location $rowLocation -IssueList $IssueList) -and $rowValid
            }
            $rowValid = (Test-StringProperty -Value $file -Name 'sourceKind' -Location $rowLocation -IssueList $IssueList -AllowedValues @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')) -and $rowValid
            $rowValid = (Test-PortablePathString -Value (Get-PropertyValue -Value $file -Name 'relativePath') -Location "$rowLocation property 'relativePath'" -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-IntegerProperty -Value $file -Name 'sizeBytes' -Location $rowLocation -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $file -Name 'sha256' -Location $rowLocation -IssueList $IssueList -Pattern '^[0-9a-f]{64}$') -and $rowValid
            $rowValid = (Test-DateTimeProperty -Value $file -Name 'capturedAt' -Location $rowLocation -IssueList $IssueList) -and $rowValid
            $rowValid = (Test-StringProperty -Value $file -Name 'parseStatus' -Location $rowLocation -IssueList $IssueList -AllowedValues @('NotAttempted', 'ExtractedReadable', 'CrossToolVerified', 'Opaque', 'Failed')) -and $rowValid
            $rowValid = (Test-StringProperty -Value $file -Name 'disposition' -Location $rowLocation -IssueList $IssueList -AllowedValues @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')) -and $rowValid
            $evidenceValid = Test-ArrayProperty -Value $file -Name 'evidence' -Location $rowLocation -IssueList $IssueList
            if ($evidenceValid) {
                $evidenceIndex = 0
                foreach ($path in $file.PSObject.Properties['evidence'].Value) {
                    $evidenceValid = (Test-PortablePathString -Value $path -Location "$rowLocation evidence item $evidenceIndex" -IssueList $IssueList) -and $evidenceValid
                    $evidenceIndex++
                }
            }
            $rowValid = $evidenceValid -and $rowValid
            $rowValid = (Test-StatusStructure -Status (Get-PropertyValue -Value $file -Name 'status') -Location "$rowLocation status" -IssueList $IssueList) -and $rowValid
        }
        $isValid = $rowValid -and $isValid
    }
    if ($Ledger.PSObject.Properties['objects'].Value.Count -ne 0) {
        $IssueList.Add('Source corpus ledger Task 0 fixture must contain zero object rows.')
        $isValid = $false
    }
    return $isValid
}

function Get-SummarySemanticIssues {
    param(
        [Parameter(Mandatory)][object] $Summary
    )

    $localIssues = [System.Collections.Generic.List[string]]::new()
    $sources = @(Get-PropertyValue -Value $Summary -Name 'sources')
    $exclusions = @(Get-PropertyValue -Value $Summary -Name 'exclusions')

    if ([long](Get-PropertyValue -Value $Summary -Name 'sourceFileCount') -ne
        [long](Get-PropertyValue -Value $Summary -Name 'catalogedFileCount') + [long](Get-PropertyValue -Value $Summary -Name 'explicitlyExcludedFileCount')) {
        $localIssues.Add('Source file conservation failed.')
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'sourceBytes') -ne
        [long](Get-PropertyValue -Value $Summary -Name 'catalogedBytes') + [long](Get-PropertyValue -Value $Summary -Name 'explicitlyExcludedBytes')) {
        $localIssues.Add('Source byte conservation failed.')
    }
    if ([string](Get-PropertyValue -Value $Summary -Name 'ledgerInputFingerprint') -cne [string](Get-PropertyValue -Value $Summary -Name 'inputFingerprint')) {
        $localIssues.Add('Source corpus ledger input fingerprint is stale.')
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'sourceFileCount') -ne (Get-IntegerSum -Rows $sources -Property 'sourceFileCount') -or
        [long](Get-PropertyValue -Value $Summary -Name 'sourceBytes') -ne (Get-IntegerSum -Rows $sources -Property 'sourceBytes')) {
        $localIssues.Add('Source totals do not equal per-source totals.')
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'explicitlyExcludedFileCount') -ne $exclusions.Count -or
        [long](Get-PropertyValue -Value $Summary -Name 'explicitlyExcludedBytes') -ne (Get-IntegerSum -Rows $exclusions -Property 'sizeBytes')) {
        $localIssues.Add('Exclusion totals do not match the exclusion rows.')
    }
    foreach ($exclusion in $exclusions) {
        if ([string]::IsNullOrWhiteSpace([string](Get-PropertyValue -Value $exclusion -Name 'reason'))) {
            $localIssues.Add("Explicit exclusion requires a non-empty reason for '$([string](Get-PropertyValue -Value $exclusion -Name 'sourceId'))/$([string](Get-PropertyValue -Value $exclusion -Name 'relativePath'))'.")
        }
    }
    return $localIssues.ToArray()
}

function Get-CrossLedgerIssues {
    param(
        [Parameter(Mandatory)][object] $Summary,
        [Parameter(Mandatory)][object] $Ledger
    )

    $localIssues = [System.Collections.Generic.List[string]]::new()
    $summarySources = @(Get-PropertyValue -Value $Summary -Name 'sources')
    $ledgerSources = @(Get-PropertyValue -Value $Ledger -Name 'sources')
    $ledgerFiles = @(Get-PropertyValue -Value $Ledger -Name 'files')
    $exclusions = @(Get-PropertyValue -Value $Summary -Name 'exclusions')

    if ([string](Get-PropertyValue -Value $Summary -Name 'ledgerInputFingerprint') -cne [string](Get-PropertyValue -Value $Ledger -Name 'inputFingerprint')) {
        $localIssues.Add('Source corpus ledger input fingerprint is stale.')
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'sourceCount') -ne $ledgerSources.Count -or $summarySources.Count -ne $ledgerSources.Count) {
        $localIssues.Add('Source count does not match source corpus ledger.')
    }
    foreach ($ledgerSource in $ledgerSources) {
        $sourceId = [string](Get-PropertyValue -Value $ledgerSource -Name 'sourceId')
        $matches = @($summarySources | Where-Object { [string](Get-PropertyValue -Value $_ -Name 'sourceId') -ceq $sourceId })
        if ($matches.Count -ne 1 -or
            [string](Get-PropertyValue -Value $matches[0] -Name 'sourceKind') -cne [string](Get-PropertyValue -Value $ledgerSource -Name 'sourceKind') -or
            [string](Get-PropertyValue -Value $matches[0] -Name 'rootFingerprint') -cne [string](Get-PropertyValue -Value $ledgerSource -Name 'rootFingerprint')) {
            $localIssues.Add("Source identity does not match source corpus ledger for '$sourceId'.")
        }
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'catalogedFileCount') -ne $ledgerFiles.Count) {
        $localIssues.Add('Cataloged file count does not match source corpus ledger.')
    }
    if ([long](Get-PropertyValue -Value $Summary -Name 'catalogedBytes') -ne (Get-IntegerSum -Rows $ledgerFiles -Property 'sizeBytes')) {
        $localIssues.Add('Cataloged bytes do not match source corpus ledger.')
    }
    foreach ($summarySource in $summarySources) {
        $sourceId = [string](Get-PropertyValue -Value $summarySource -Name 'sourceId')
        $sourceFiles = @($ledgerFiles | Where-Object { [string](Get-PropertyValue -Value $_ -Name 'sourceId') -ceq $sourceId })
        $sourceExclusions = @($exclusions | Where-Object { [string](Get-PropertyValue -Value $_ -Name 'sourceId') -ceq $sourceId })
        if ([long](Get-PropertyValue -Value $summarySource -Name 'sourceFileCount') -ne $sourceFiles.Count + $sourceExclusions.Count -or
            [long](Get-PropertyValue -Value $summarySource -Name 'sourceBytes') -ne (Get-IntegerSum -Rows $sourceFiles -Property 'sizeBytes') + (Get-IntegerSum -Rows $sourceExclusions -Property 'sizeBytes')) {
            $localIssues.Add("Per-source conservation failed for '$sourceId'.")
        }
    }
    return $localIssues.ToArray()
}

$summary = $null
$ledger = $null
$summaryStructureValid = $false
$ledgerStructureValid = $false
$positiveFixtureCount = 0
$negativeFixtureCount = 0

try {
    $summary = Read-StrictJsonObject -Path $SummaryPath -IssueList $issues
    $ledger = Read-StrictJsonObject -Path $LedgerPath -IssueList $issues

    if ($null -ne $summary -and $null -ne $ledger) {
        $structureIssues = [System.Collections.Generic.List[string]]::new()
        $summaryStructureValid = Test-SummaryStructure -Summary $summary -IssueList $structureIssues
        $ledgerStructureValid = Test-LedgerStructure -Ledger $ledger -IssueList $structureIssues
        foreach ($issue in $structureIssues) { $issues.Add($issue) }
        if ($summaryStructureValid) {
            foreach ($issue in @(Get-SummarySemanticIssues -Summary $summary)) { $issues.Add($issue) }
        }
        if ($summaryStructureValid -and $ledgerStructureValid) {
            foreach ($issue in @(Get-CrossLedgerIssues -Summary $summary -Ledger $ledger)) { $issues.Add($issue) }
        }
        if ($summaryStructureValid -and $ledgerStructureValid -and $issues.Count -eq 0) {
            $positiveFixtureCount = 2
        }

        $negativeContracts = @(
            [pscustomobject]@{ Name = 'invalid-source-count-conservation.json'; Expected = 'Source file conservation failed.' },
            [pscustomobject]@{ Name = 'invalid-source-byte-conservation.json'; Expected = 'Source byte conservation failed.' },
            [pscustomobject]@{ Name = 'invalid-ledger-fingerprint.json'; Expected = 'Source corpus ledger input fingerprint is stale.' },
            [pscustomobject]@{ Name = 'invalid-unreasoned-exclusion.json'; Expected = "Explicit exclusion requires a non-empty reason for 'pc-install-primary/SourceCorpus/PcInstall/ignored.tmp'." }
        )
        foreach ($contract in $negativeContracts) {
            $fixturePath = Join-Path $fixtureRoot $contract.Name
            $fixtureIssues = [System.Collections.Generic.List[string]]::new()
            $fixture = Read-StrictJsonObject -Path $fixturePath -IssueList $fixtureIssues
            if ($null -ne $fixture) {
                $fixtureStructureValid = Test-SummaryStructure -Summary $fixture -IssueList $fixtureIssues
                if ($fixtureStructureValid) {
                    foreach ($semanticIssue in @(Get-SummarySemanticIssues -Summary $fixture)) {
                        $fixtureIssues.Add($semanticIssue)
                    }
                }
            }
            if ($fixtureIssues.Count -eq 1 -and $fixtureIssues[0] -ceq $contract.Expected) {
                $negativeFixtureCount++
            }
            else {
                $expectedText = ConvertTo-Json -InputObject @($contract.Expected) -Compress
                $actualText = ConvertTo-Json -InputObject ([object[]]$fixtureIssues.ToArray()) -Compress
                $issues.Add("Negative fixture '$($contract.Name)' did not produce exactly its expected issues. Expected: $expectedText; Actual: $actualText.")
            }
        }
    }
}
catch {
    $issues.Add('Unexpected source corpus gate validation failure.')
    $summaryStructureValid = $false
}

$stopwatch.Stop()
$result = [pscustomobject][ordered]@{
    status = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $issues.Count
    issues = $issues.ToArray()
    sourceCount = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'sourceCount') }
    sourceFileCount = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'sourceFileCount') }
    catalogedFileCount = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'catalogedFileCount') }
    explicitlyExcludedFileCount = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'explicitlyExcludedFileCount') }
    sourceBytes = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'sourceBytes') }
    catalogedBytes = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'catalogedBytes') }
    explicitlyExcludedBytes = if (-not $summaryStructureValid) { 0 } else { [long](Get-PropertyValue -Value $summary -Name 'explicitlyExcludedBytes') }
    positiveFixtureCount = $positiveFixtureCount
    negativeFixtureCount = $negativeFixtureCount
    childProcessCount = 0
    durationMs = $stopwatch.ElapsedMilliseconds
}

Write-Output ($result | ConvertTo-Json -Depth 10 -Compress)
if ($issues.Count -gt 0) {
    throw "Source corpus gate validation failed with $($issues.Count) issue(s)."
}
