[CmdletBinding()]
param(
    [Parameter()]
    [string] $ContractRoot,

    [Parameter()]
    [string] $FixtureRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$issues = [System.Collections.Generic.List[string]]::new()

function Get-ForbiddenPropertyNames {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or $Value -is [string]) {
        return
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.Name -cin @('OriginalUnityProjectRestored', 'originalUnityProjectRestored')) {
                Write-Output $property.Name
            }

            Get-ForbiddenPropertyNames -Value $property.Value
        }

        return
    }

    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ([string]$key -cin @('OriginalUnityProjectRestored', 'originalUnityProjectRestored')) {
                Write-Output ([string]$key)
            }

            Get-ForbiddenPropertyNames -Value $Value[$key]
        }

        return
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($item in $Value) {
            Get-ForbiddenPropertyNames -Value $item
        }
    }
}

function Read-JsonContractFile {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $issues.Add("Missing contract file: $Path")
        return $null
    }

    $jsonDocument = $null
    try {
        $serialized = Get-Content -LiteralPath $Path -Raw
        if ([string]::IsNullOrWhiteSpace($serialized)) {
            throw 'Contract JSON is empty.'
        }

        $jsonDocument = [System.Text.Json.JsonDocument]::Parse($serialized)
        if ($jsonDocument.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Contract JSON root must be an object.'
        }

        $value = $serialized | ConvertFrom-Json -Depth 100 -DateKind String
        if ($null -eq $value -or $value -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Contract JSON root must be an object.'
        }

        return $value
    }
    catch {
        $issues.Add("Invalid JSON contract file: $Path")
        return $null
    }
    finally {
        if ($null -ne $jsonDocument) {
            $jsonDocument.Dispose()
        }
    }
}

function Test-SchemaObjectClosure {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Node,

        [Parameter(Mandatory)]
        [string] $SchemaName,

        [Parameter(Mandatory)]
        [string] $Location
    )

    if ($null -eq $Node -or $Node -is [string]) {
        return
    }

    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $typeProperty = $Node.PSObject.Properties['type']
        if ($null -ne $typeProperty -and $typeProperty.Value -ceq 'object') {
            $additionalProperties = $Node.PSObject.Properties['additionalProperties']
            if ($null -eq $additionalProperties -or $additionalProperties.Value -ne $false) {
                $issues.Add("Schema '$SchemaName' object '$Location' does not set additionalProperties to false.")
            }
        }

        foreach ($property in $Node.PSObject.Properties) {
            Test-SchemaObjectClosure -Node $property.Value -SchemaName $SchemaName -Location "$Location.$($property.Name)"
        }

        return
    }

    if ($Node -is [System.Collections.IEnumerable]) {
        $index = 0
        foreach ($item in $Node) {
            Test-SchemaObjectClosure -Node $item -SchemaName $SchemaName -Location "$Location[$index]"
            $index++
        }
    }
}

function Test-SchemaPropertyConstraints {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Node,

        [Parameter(Mandatory)]
        [string] $SchemaName
    )

    if ($null -eq $Node -or $Node -is [string]) {
        return
    }

    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $properties = $Node.PSObject.Properties['properties']
        if ($null -ne $properties -and $properties.Value -is [System.Management.Automation.PSCustomObject]) {
            foreach ($property in $properties.Value.PSObject.Properties) {
                $definition = $property.Value
                if ($definition -is [System.Management.Automation.PSCustomObject]) {
                    if ($property.Name -cmatch '(?:Count|Bytes)$') {
                        if ((Get-PropertyByPath -Value $definition -Path 'type') -cne 'integer' -or (Get-PropertyByPath -Value $definition -Path 'minimum') -ne 0) {
                            $issues.Add("Schema '$SchemaName' property '$($property.Name)' must be a non-negative integer.")
                        }
                    }

                    if ($property.Name -cmatch '(?:Fingerprint|sha256)$') {
                        if ((Get-PropertyByPath -Value $definition -Path 'type') -cne 'string' -or (Get-PropertyByPath -Value $definition -Path 'pattern') -cne '^[0-9a-f]{64}$') {
                            $issues.Add("Schema '$SchemaName' property '$($property.Name)' must be a lowercase SHA-256 string.")
                        }
                    }

                    if ($property.Name -cmatch 'At$') {
                        if ((Get-PropertyByPath -Value $definition -Path 'type') -cne 'string' -or (Get-PropertyByPath -Value $definition -Path 'format') -cne 'date-time') {
                            $issues.Add("Schema '$SchemaName' property '$($property.Name)' must use date-time format.")
                        }
                    }
                }
            }
        }

        foreach ($property in $Node.PSObject.Properties) {
            Test-SchemaPropertyConstraints -Node $property.Value -SchemaName $SchemaName
        }

        return
    }

    if ($Node -is [System.Collections.IEnumerable]) {
        foreach ($item in $Node) {
            Test-SchemaPropertyConstraints -Node $item -SchemaName $SchemaName
        }
    }
}

function Test-SchemaRequiredSet {
    param(
        [Parameter(Mandatory)]
        [object] $Schema,

        [Parameter(Mandatory)]
        [string] $SchemaName,

        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string[]] $Expected
    )

    $actualValue = Get-PropertyByPath -Value $Schema -Path $Path
    $actual = @($actualValue)
    $matches = $actual.Count -eq $Expected.Count
    if ($matches) {
        foreach ($name in $Expected) {
            if ($name -cnotin $actual) {
                $matches = $false
                break
            }
        }
    }

    if (-not $matches) {
        $issues.Add("Schema '$SchemaName' required set '$Path' does not match the contract.")
    }
}

function Test-SchemaEnum {
    param(
        [Parameter(Mandatory)]
        [object] $Schema,

        [Parameter(Mandatory)]
        [string] $SchemaName,

        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $VocabularyDimension
    )

    if ($null -eq $vocabulary) {
        return
    }

    $vocabularyProperty = $vocabulary.PSObject.Properties[$VocabularyDimension]
    if ($null -eq $vocabularyProperty) {
        return
    }

    $actual = @(Get-PropertyByPath -Value $Schema -Path $Path)
    $expected = @($vocabularyProperty.Value)
    $matches = $actual.Count -eq $expected.Count
    if ($matches) {
        for ($index = 0; $index -lt $expected.Count; $index++) {
            if ($actual[$index] -cne $expected[$index]) {
                $matches = $false
                break
            }
        }
    }

    if (-not $matches) {
        $issues.Add("Schema '$SchemaName' enum '$Path' does not match vocabulary '$VocabularyDimension'.")
    }
}

function Get-PropertyByPath {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [string] $Path
    )

    $current = $Value
    foreach ($segment in $Path.Split('.')) {
        if ($null -eq $current -or $current -isnot [System.Management.Automation.PSCustomObject]) {
            return $null
        }

        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            return $null
        }

        $current = $property.Value
    }

    return $current
}

function Test-IsIntegerValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value
    )

    return (
        $Value -is [sbyte] -or
        $Value -is [byte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
    )
}

function Test-JsonPrimitiveEquals {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Left,

        [Parameter()]
        [AllowNull()]
        [object] $Right
    )

    if ($null -eq $Left -or $null -eq $Right) {
        return $null -eq $Left -and $null -eq $Right
    }

    if ($Left -is [string] -or $Right -is [string]) {
        return $Left -is [string] -and $Right -is [string] -and $Left -ceq $Right
    }

    return $Left -eq $Right
}

function Add-FixtureSchemaIssue {
    param(
        [Parameter(Mandatory)]
        [string] $FixtureName,

        [Parameter(Mandatory)]
        [string] $InstancePath,

        [Parameter(Mandatory)]
        [string] $Keyword,

        [Parameter(Mandatory)]
        [string] $Detail
    )

    $issues.Add("Fixture '$FixtureName' at '$InstancePath' failed schema keyword '$Keyword': $Detail.")
}

function Resolve-LocalSchemaReference {
    param(
        [Parameter(Mandatory)]
        [object] $RootSchema,

        [Parameter(Mandatory)]
        [string] $Reference
    )

    if (-not $Reference.StartsWith('#/', [System.StringComparison]::Ordinal)) {
        return $null
    }

    $current = $RootSchema
    foreach ($encodedSegment in $Reference.Substring(2).Split('/')) {
        if ($null -eq $current -or $current -isnot [System.Management.Automation.PSCustomObject]) {
            return $null
        }

        $segment = $encodedSegment.Replace('~1', '/').Replace('~0', '~')
        $property = $current.PSObject.Properties[$segment]
        if ($null -eq $property) {
            return $null
        }

        $current = $property.Value
    }

    return $current
}

function Test-JsonSchemaSubset {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [object] $Schema,

        [Parameter(Mandatory)]
        [object] $RootSchema,

        [Parameter(Mandatory)]
        [string] $FixtureName,

        [Parameter(Mandatory)]
        [string] $InstancePath,

        [Parameter()]
        [switch] $SkipCurrentRequired
    )

    $referenceProperty = $Schema.PSObject.Properties['$ref']
    if ($null -ne $referenceProperty) {
        $resolvedSchema = Resolve-LocalSchemaReference -RootSchema $RootSchema -Reference ([string]$referenceProperty.Value)
        if ($null -eq $resolvedSchema) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword '$ref' -Detail "unresolved local reference '$($referenceProperty.Value)'"
            return
        }

        Test-JsonSchemaSubset -Value $Value -Schema $resolvedSchema -RootSchema $RootSchema -FixtureName $FixtureName -InstancePath $InstancePath
        return
    }

    $typeProperty = $Schema.PSObject.Properties['type']
    if ($null -ne $typeProperty) {
        $expectedType = [string]$typeProperty.Value
        $typeMatches = switch ($expectedType) {
            'object' { $Value -is [System.Management.Automation.PSCustomObject]; break }
            'array' { $Value -is [System.Array] -or $Value -is [System.Collections.IList]; break }
            'string' { $Value -is [string]; break }
            'integer' { Test-IsIntegerValue -Value $Value; break }
            'boolean' { $Value -is [bool]; break }
            default { $false; break }
        }

        if (-not $typeMatches) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'type' -Detail "expected $expectedType"
            return
        }
    }

    $constProperty = $Schema.PSObject.Properties['const']
    if ($null -ne $constProperty -and -not (Test-JsonPrimitiveEquals -Left $Value -Right $constProperty.Value)) {
        Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'const' -Detail "value does not equal the schema constant"
    }

    $enumProperty = $Schema.PSObject.Properties['enum']
    if ($null -ne $enumProperty) {
        $enumMatches = $false
        foreach ($allowedValue in @($enumProperty.Value)) {
            if (Test-JsonPrimitiveEquals -Left $Value -Right $allowedValue) {
                $enumMatches = $true
                break
            }
        }

        if (-not $enumMatches) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'enum' -Detail "value is not in the allowed set"
        }
    }

    if ($Value -is [string]) {
        $minLengthProperty = $Schema.PSObject.Properties['minLength']
        if ($null -ne $minLengthProperty -and $Value.Length -lt [int]$minLengthProperty.Value) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'minLength' -Detail "length is less than $($minLengthProperty.Value)"
        }

        $patternProperty = $Schema.PSObject.Properties['pattern']
        if ($null -ne $patternProperty -and -not [System.Text.RegularExpressions.Regex]::IsMatch($Value, [string]$patternProperty.Value, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'pattern' -Detail "value does not match '$($patternProperty.Value)'"
        }

        $formatProperty = $Schema.PSObject.Properties['format']
        if ($null -ne $formatProperty -and $formatProperty.Value -ceq 'date-time') {
            $parsedDateTime = [System.DateTimeOffset]::MinValue
            $hasIsoShape = $Value -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
            $isDateTime = $hasIsoShape -and [System.DateTimeOffset]::TryParse(
                $Value,
                [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind,
                [ref]$parsedDateTime
            )
            if (-not $isDateTime) {
                Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'format' -Detail "value is not a date-time"
            }
        }
    }

    if (Test-IsIntegerValue -Value $Value) {
        $minimumProperty = $Schema.PSObject.Properties['minimum']
        if ($null -ne $minimumProperty -and $Value -lt $minimumProperty.Value) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'minimum' -Detail "value is less than $($minimumProperty.Value)"
        }
    }

    if ($Value -is [System.Management.Automation.PSCustomObject]) {
        $requiredProperty = $Schema.PSObject.Properties['required']
        if (-not $SkipCurrentRequired -and $null -ne $requiredProperty) {
            foreach ($requiredName in @($requiredProperty.Value)) {
                if ($null -eq $Value.PSObject.Properties[[string]$requiredName]) {
                    Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'required' -Detail "missing property '$requiredName'"
                }
            }
        }

        $propertiesProperty = $Schema.PSObject.Properties['properties']
        if ($null -ne $propertiesProperty) {
            foreach ($schemaProperty in $propertiesProperty.Value.PSObject.Properties) {
                $instanceProperty = $Value.PSObject.Properties[$schemaProperty.Name]
                if ($null -ne $instanceProperty) {
                    Test-JsonSchemaSubset -Value $instanceProperty.Value -Schema $schemaProperty.Value -RootSchema $RootSchema -FixtureName $FixtureName -InstancePath "$InstancePath.$($schemaProperty.Name)"
                }
            }

            $additionalProperties = $Schema.PSObject.Properties['additionalProperties']
            if ($null -ne $additionalProperties -and $additionalProperties.Value -eq $false) {
                $allowedNames = @($propertiesProperty.Value.PSObject.Properties.Name)
                foreach ($instanceProperty in $Value.PSObject.Properties) {
                    if ($instanceProperty.Name -cnotin $allowedNames) {
                        Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath "$InstancePath.$($instanceProperty.Name)" -Keyword 'additionalProperties' -Detail "property is not allowed"
                    }
                }
            }
        }
    }

    if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) {
        $items = @($Value)
        $minItemsProperty = $Schema.PSObject.Properties['minItems']
        if ($null -ne $minItemsProperty -and $items.Count -lt [int]$minItemsProperty.Value) {
            Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'minItems' -Detail "item count is less than $($minItemsProperty.Value)"
        }

        $uniqueItemsProperty = $Schema.PSObject.Properties['uniqueItems']
        if ($null -ne $uniqueItemsProperty -and $uniqueItemsProperty.Value -eq $true) {
            $seenItems = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            foreach ($item in $items) {
                $serializedItem = $item | ConvertTo-Json -Depth 100 -Compress
                if (-not $seenItems.Add($serializedItem)) {
                    Add-FixtureSchemaIssue -FixtureName $FixtureName -InstancePath $InstancePath -Keyword 'uniqueItems' -Detail "array contains duplicate items"
                    break
                }
            }
        }

        $itemsProperty = $Schema.PSObject.Properties['items']
        if ($null -ne $itemsProperty) {
            for ($index = 0; $index -lt $items.Count; $index++) {
                Test-JsonSchemaSubset -Value $items[$index] -Schema $itemsProperty.Value -RootSchema $RootSchema -FixtureName $FixtureName -InstancePath "$InstancePath[$index]"
            }
        }
    }
}

function Test-RequiredProperties {
    param(
        [Parameter(Mandatory)]
        [object] $Value,

        [Parameter(Mandatory)]
        [string[]] $RequiredProperties,

        [Parameter(Mandatory)]
        [string] $FixtureName
    )

    foreach ($requiredProperty in $RequiredProperties) {
        if ($null -eq $Value.PSObject.Properties[$requiredProperty]) {
            $issues.Add("Fixture '$FixtureName' is missing required property '$requiredProperty'.")
        }
    }
}

function Test-FixtureVocabularyValue {
    param(
        [Parameter()]
        [AllowNull()]
        [object] $Value,

        [Parameter(Mandatory)]
        [string] $Dimension,

        [Parameter(Mandatory)]
        [string] $VocabularyDimension,

        [Parameter(Mandatory)]
        [string] $FixtureName
    )

    if ($null -eq $Value -or $null -eq $vocabulary) {
        return
    }

    $vocabularyProperty = $vocabulary.PSObject.Properties[$VocabularyDimension]
    if ($Value -isnot [string] -or $null -eq $vocabularyProperty -or $Value -cnotin @($vocabularyProperty.Value)) {
        $issues.Add("Fixture '$FixtureName' uses unsupported $Dimension status '$Value'.")
    }
}

function Get-NegativeFixtureSemanticIssues {
    param(
        [Parameter(Mandatory)]
        [object] $Fixture,

        [Parameter(Mandatory)]
        [string] $Rule
    )

    $fixtureIssues = [System.Collections.Generic.List[string]]::new()

    switch ($Rule) {
        'SourceFileConservation' {
            $sourceFileCount = Get-PropertyByPath -Value $Fixture -Path 'sourceFileCount'
            $catalogedFileCount = Get-PropertyByPath -Value $Fixture -Path 'catalogedFileCount'
            $explicitlyExcludedFileCount = Get-PropertyByPath -Value $Fixture -Path 'explicitlyExcludedFileCount'
            if ($sourceFileCount -ne ($catalogedFileCount + $explicitlyExcludedFileCount)) {
                $fixtureIssues.Add('Source file conservation failed.')
            }
        }
        'FamilyConservation' {
            $family = Get-PropertyByPath -Value $Fixture -Path 'family'
            $familyId = Get-PropertyByPath -Value $family -Path 'familyId'
            $memberCount = Get-PropertyByPath -Value $family -Path 'memberCount'
            $staticPassedCount = Get-PropertyByPath -Value $family -Path 'staticPassedCount'
            $staticFailedCount = Get-PropertyByPath -Value $family -Path 'staticFailedCount'
            $uncheckedCount = Get-PropertyByPath -Value $family -Path 'uncheckedCount'
            if ($memberCount -ne ($staticPassedCount + $staticFailedCount + $uncheckedCount)) {
                $fixtureIssues.Add("Asset family member conservation failed for '$familyId'.")
            }
        }
        'RepairOnceAttribution' {
            $family = Get-PropertyByPath -Value $Fixture -Path 'family'
            $familyId = Get-PropertyByPath -Value $family -Path 'familyId'
            $decision = Get-PropertyByPath -Value $family -Path 'decision'
            $failureAttribution = Get-PropertyByPath -Value $family -Path 'failureAttribution'
            $hasFailureAttribution = $null -ne $failureAttribution -and @($failureAttribution).Count -gt 0
            if ($decision -ceq 'RepairOnce' -and -not $hasFailureAttribution) {
                $fixtureIssues.Add("RepairOnce requires non-empty failureAttribution for '$familyId'.")
            }
        }
        'StaleFingerprint' {
            $directChildFingerprint = Get-PropertyByPath -Value $Fixture -Path 'directChildFingerprint'
            $downstreamInputFingerprint = Get-PropertyByPath -Value $Fixture -Path 'downstreamSummary.inputFingerprint'
            if ($downstreamInputFingerprint -cne $directChildFingerprint) {
                $fixtureIssues.Add('Downstream summary input fingerprint is stale.')
            }
        }
        'OriginalProjectRestored' {
            foreach ($forbiddenPropertyName in @(Get-ForbiddenPropertyNames -Value $Fixture)) {
                $fixtureIssues.Add("Forbidden original project restoration property found in '$forbiddenPropertyName'.")
            }
        }
        default {
            throw "Unsupported negative fixture rule '$Rule'."
        }
    }

    return $fixtureIssues.ToArray()
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if ([string]::IsNullOrWhiteSpace($ContractRoot)) {
    $ContractRoot = Join-Path $repositoryRoot 'docs\asset-migration\schemas'
}
elseif (-not [System.IO.Path]::IsPathRooted($ContractRoot)) {
    $ContractRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $ContractRoot))
}
else {
    $ContractRoot = [System.IO.Path]::GetFullPath($ContractRoot)
}

if ([string]::IsNullOrWhiteSpace($FixtureRoot)) {
    $FixtureRoot = Join-Path $repositoryRoot 'Tools\AssetImport\Fixtures\AssetCorpusContracts'
}
elseif (-not [System.IO.Path]::IsPathRooted($FixtureRoot)) {
    $FixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $FixtureRoot))
}
else {
    $FixtureRoot = [System.IO.Path]::GetFullPath($FixtureRoot)
}

$vocabularyPath = [System.IO.Path]::GetFullPath((Join-Path $ContractRoot 'status-vocabulary.json'))
$vocabulary = $null
$serializedVocabulary = $null
$generatedAtText = ''

if (-not (Test-Path -LiteralPath $vocabularyPath -PathType Leaf)) {
    $issues.Add("Missing contract file: $vocabularyPath")
}
else {
    $jsonDocument = $null
    try {
        $serializedVocabulary = Get-Content -LiteralPath $vocabularyPath -Raw
        if ([string]::IsNullOrWhiteSpace($serializedVocabulary)) {
            throw 'Vocabulary JSON is empty.'
        }

        $jsonDocument = [System.Text.Json.JsonDocument]::Parse($serializedVocabulary)
        if ($jsonDocument.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Vocabulary JSON root must be an object.'
        }

        $generatedAtElement = [System.Text.Json.JsonElement]::new()
        if (
            $jsonDocument.RootElement.TryGetProperty('generatedAt', [ref]$generatedAtElement) -and
            $generatedAtElement.ValueKind -eq [System.Text.Json.JsonValueKind]::String
        ) {
            $generatedAtText = $generatedAtElement.GetString()
        }

        $vocabulary = $serializedVocabulary | ConvertFrom-Json
        if ($null -eq $vocabulary -or $vocabulary -isnot [System.Management.Automation.PSCustomObject]) {
            throw 'Vocabulary JSON root must be an object.'
        }
    }
    catch {
        $issues.Add("Invalid JSON contract file: $vocabularyPath")
        $vocabulary = $null
    }
    finally {
        if ($null -ne $jsonDocument) {
            $jsonDocument.Dispose()
        }
    }
}

if ($null -ne $vocabulary) {
    $schemaVersionProperty = $vocabulary.PSObject.Properties['schemaVersion']
    if ($null -eq $schemaVersionProperty -or $schemaVersionProperty.Value -isnot [string] -or $schemaVersionProperty.Value -cne '1.0.0') {
        $issues.Add('schemaVersion must be exactly 1.0.0')
    }

    $parsedGeneratedAt = [System.DateTimeOffset]::MinValue
    $hasIsoShape = $generatedAtText -cmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'
    $canParseGeneratedAt = $hasIsoShape -and [System.DateTimeOffset]::TryParse(
        $generatedAtText,
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsedGeneratedAt
    )
    if (-not $canParseGeneratedAt) {
        $issues.Add('generatedAt must be a valid ISO-8601 timestamp')
    }

    $expectedArrays = [ordered]@{
        corpus                   = @('Cataloged', 'Missing', 'StaleInput')
        extraction               = @('NotAttempted', 'ExtractedReadable', 'CrossToolVerified', 'Opaque', 'Failed')
        semantics                = @('Known', 'PartiallyKnown', 'Unknown')
        configurationDisposition = @('Parsed', 'DiscoveredOpaque', 'Encrypted', 'RequiresRuntimeType', 'LikelyServerDependent', 'NotConfiguration')
        unity                    = @('NotTested', 'StaticQualified', 'RepresentativeValidated', 'Rejected', 'UnityExecutionUnavailable')
        disposition              = @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')
        familyStaticOutcome      = @('StaticQualified', 'StaticRejected', 'NeedsDiagnosis')
        sourceKind               = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    }

    $expectedPropertyNames = @('schemaVersion', 'generatedAt') + @($expectedArrays.Keys)
    $actualPropertyNames = @($vocabulary.PSObject.Properties.Name)
    $missingPropertyNames = @($expectedPropertyNames | Where-Object { $_ -cnotin $actualPropertyNames })
    $unexpectedPropertyNames = @($actualPropertyNames | Where-Object { $_ -cnotin $expectedPropertyNames })
    if ($missingPropertyNames.Count -gt 0 -or $unexpectedPropertyNames.Count -gt 0) {
        $issues.Add('Vocabulary document properties do not match the contract')
    }

    foreach ($entry in $expectedArrays.GetEnumerator()) {
        $property = $vocabulary.PSObject.Properties[$entry.Key]
        $matches = $null -ne $property

        if ($matches) {
            $actual = @($property.Value)
            $expected = @($entry.Value)
            $matches = $actual.Count -eq $expected.Count

            if ($matches) {
                for ($index = 0; $index -lt $expected.Count; $index++) {
                    if ($actual[$index] -isnot [string] -or $actual[$index] -cne $expected[$index]) {
                        $matches = $false
                        break
                    }
                }
            }
        }

        if (-not $matches) {
            $issues.Add("Vocabulary array '$($entry.Key)' does not match the contract")
        }
    }

    foreach ($forbiddenPropertyName in @(Get-ForbiddenPropertyNames -Value $vocabulary)) {
        $issues.Add("Forbidden original project restoration property found in '$forbiddenPropertyName'.")
    }
}


$schemaContracts = @(
    [pscustomobject]@{
        Name = 'source-corpus-ledger.schema.json'
        Id = 'https://stellagaia.dev/schemas/source-corpus-ledger.schema.json'
        Required = @('schemaVersion', 'snapshotId', 'generatedAt', 'inputFingerprint', 'toolVersions', 'sources', 'files', 'objects')
    },
    [pscustomobject]@{
        Name = 'authoring-reuse-ledger.schema.json'
        Id = 'https://stellagaia.dev/schemas/authoring-reuse-ledger.schema.json'
        Required = @('schemaVersion', 'generatedAt', 'inputFingerprint', 'toolVersions', 'families')
    },
    [pscustomobject]@{
        Name = 'root-gate-summary.schema.json'
        Id = 'https://stellagaia.dev/schemas/root-gate-summary.schema.json'
        Required = @('schemaVersion', 'generatedAt', 'inputFingerprint', 'toolVersions', 'directGateSummaries', 'directGateReports', 'corpusSnapshotComplete', 'structuredObjectCoverage', 'originalAssetBatchCoverage', 'stellaSora2AuthoringReady')
    }
)

$fixtureContracts = @(
    [pscustomobject]@{
        Name = 'valid-source-corpus-ledger.json'
        SchemaName = 'source-corpus-ledger.schema.json'
    },
    [pscustomobject]@{
        Name = 'valid-authoring-reuse-ledger.json'
        SchemaName = 'authoring-reuse-ledger.schema.json'
    },
    [pscustomobject]@{
        Name = 'valid-root-gate-summary.json'
        SchemaName = 'root-gate-summary.schema.json'
    }
)

$negativeFixtureContracts = @(
    [pscustomobject]@{
        Name = 'invalid-source-file-conservation.json'
        Rule = 'SourceFileConservation'
        ExpectedIssue = 'Source file conservation failed.'
    },
    [pscustomobject]@{
        Name = 'invalid-family-conservation.json'
        Rule = 'FamilyConservation'
        ExpectedIssue = "Asset family member conservation failed for 'family.invalid-conservation'."
    },
    [pscustomobject]@{
        Name = 'invalid-repair-once-attribution.json'
        Rule = 'RepairOnceAttribution'
        ExpectedIssue = "RepairOnce requires non-empty failureAttribution for 'family.invalid-repair-once'."
    },
    [pscustomobject]@{
        Name = 'invalid-stale-fingerprint.json'
        Rule = 'StaleFingerprint'
        ExpectedIssue = 'Downstream summary input fingerprint is stale.'
    },
    [pscustomobject]@{
        Name = 'invalid-original-project-restored.json'
        Rule = 'OriginalProjectRestored'
        ExpectedIssue = "Forbidden original project restoration property found in 'originalUnityProjectRestored'."
    }
)

$schemas = @{}
foreach ($contract in $schemaContracts) {
    $schemaPath = [System.IO.Path]::GetFullPath((Join-Path $ContractRoot $contract.Name))
    $schema = Read-JsonContractFile -Path $schemaPath
    if ($null -eq $schema) {
        continue
    }

    $schemas[$contract.Name] = $schema
    $dialect = $schema.PSObject.Properties['$schema']
    if ($null -eq $dialect -or $dialect.Value -cne 'https://json-schema.org/draft/2020-12/schema') {
        $issues.Add("Schema '$($contract.Name)' does not declare JSON Schema Draft 2020-12.")
    }

    $id = $schema.PSObject.Properties['$id']
    if ($null -eq $id -or $id.Value -cne $contract.Id) {
        $issues.Add("Schema '$($contract.Name)' does not declare its contract id.")
    }

    $title = $schema.PSObject.Properties['title']
    if ($null -eq $title -or $title.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($title.Value)) {
        $issues.Add("Schema '$($contract.Name)' has no title.")
    }

    $type = $schema.PSObject.Properties['type']
    if ($null -eq $type -or $type.Value -cne 'object') {
        $issues.Add("Schema '$($contract.Name)' root type is not object.")
    }

    $required = $schema.PSObject.Properties['required']
    if ($null -eq $required -or @($required.Value).Count -eq 0) {
        $issues.Add("Schema '$($contract.Name)' has no required properties.")
    }
    else {
        foreach ($requiredProperty in $contract.Required) {
            if ($requiredProperty -cnotin @($required.Value)) {
                $issues.Add("Schema '$($contract.Name)' does not require root property '$requiredProperty'.")
            }
        }
    }

    $additionalProperties = $schema.PSObject.Properties['additionalProperties']
    if ($null -eq $additionalProperties -or $additionalProperties.Value -ne $false) {
        $issues.Add("Schema '$($contract.Name)' root does not set additionalProperties to false.")
    }

    $schemaVersion = Get-PropertyByPath -Value $schema -Path 'properties.schemaVersion.const'
    if ($schemaVersion -cne '1.0.0') {
        $issues.Add("Schema '$($contract.Name)' does not freeze schemaVersion 1.0.0.")
    }

    Test-SchemaObjectClosure -Node $schema -SchemaName $contract.Name -Location '$'
    Test-SchemaPropertyConstraints -Node $schema -SchemaName $contract.Name
    foreach ($forbiddenPropertyName in @(Get-ForbiddenPropertyNames -Value $schema)) {
        $issues.Add("Forbidden original project restoration property found in '$forbiddenPropertyName'.")
    }
}

if ($schemas.ContainsKey('source-corpus-ledger.schema.json')) {
    $schema = $schemas['source-corpus-ledger.schema.json']
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.sources.items.required' -Expected @('sourceId', 'sourceKind', 'capturedAt', 'rootFingerprint')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.files.items.required' -Expected @('snapshotId', 'sourceId', 'sourceKind', 'relativePath', 'sizeBytes', 'sha256', 'capturedAt', 'containerKind', 'parseStatus', 'disposition', 'evidence', 'status')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.objects.items.required' -Expected @('assetObjectId', 'sourceId', 'containerRelativePath', 'classId', 'objectType', 'objectName', 'serializedSizeBytes', 'dependencyObjectIds', 'toolObservations', 'canonicalAssetId', 'platformVariant', 'configurationDisposition', 'evidence', 'status')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path '$defs.status.required' -Expected @('corpus', 'extraction', 'semantics', 'unity', 'disposition')
    Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.sources.items.properties.sourceKind.enum' -VocabularyDimension 'sourceKind'
    Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.files.items.properties.sourceKind.enum' -VocabularyDimension 'sourceKind'
    Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.files.items.properties.parseStatus.enum' -VocabularyDimension 'extraction'
    Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.files.items.properties.disposition.enum' -VocabularyDimension 'disposition'
    Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path 'properties.objects.items.properties.configurationDisposition.enum' -VocabularyDimension 'configurationDisposition'
    foreach ($dimension in @('corpus', 'extraction', 'semantics', 'unity', 'disposition')) {
        Test-SchemaEnum -Schema $schema -SchemaName 'source-corpus-ledger.schema.json' -Path "`$defs.status.properties.$dimension.enum" -VocabularyDimension $dimension
    }
}

if ($schemas.ContainsKey('authoring-reuse-ledger.schema.json')) {
    $schema = $schemas['authoring-reuse-ledger.schema.json']
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'authoring-reuse-ledger.schema.json' -Path 'properties.families.items.required' -Expected @('familyId', 'category', 'memberSelector', 'memberCount', 'staticPassedCount', 'staticFailedCount', 'uncheckedCount', 'representativeAssetIds', 'representativeSelectionReason', 'unityEvidence', 'residualIssues', 'failureAttribution', 'decision', 'nextAllowedAction', 'generatedAt', 'inputFingerprint', 'toolVersions', 'directGateSummary', 'directGateReport', 'staticOutcome')
    Test-SchemaEnum -Schema $schema -SchemaName 'authoring-reuse-ledger.schema.json' -Path 'properties.families.items.properties.decision.enum' -VocabularyDimension 'disposition'
    Test-SchemaEnum -Schema $schema -SchemaName 'authoring-reuse-ledger.schema.json' -Path 'properties.families.items.properties.staticOutcome.enum' -VocabularyDimension 'familyStaticOutcome'
}

if ($schemas.ContainsKey('root-gate-summary.schema.json')) {
    $schema = $schemas['root-gate-summary.schema.json']
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'root-gate-summary.schema.json' -Path 'properties.corpusSnapshotComplete.required' -Expected @('value', 'catalogedFileCount', 'sourceFileCount', 'catalogedBytes', 'sourceBytes')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'root-gate-summary.schema.json' -Path 'properties.structuredObjectCoverage.required' -Expected @('parsedContainerCount', 'parsedContainerBytes', 'opaqueOrFailedContainerCount', 'opaqueOrFailedContainerBytes', 'enumeratedObjectCount', 'classifiedObjectCount', 'unclassifiedObjectCount', 'configurationCandidateCount', 'configurationParsedCount')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'root-gate-summary.schema.json' -Path 'properties.originalAssetBatchCoverage.required' -Expected @('reusableFamilyCount', 'totalFamilyCount', 'reusableMemberCount', 'totalMemberCount', 'reusableBytes', 'totalBytes')
    Test-SchemaRequiredSet -Schema $schema -SchemaName 'root-gate-summary.schema.json' -Path 'properties.stellaSora2AuthoringReady.required' -Expected @('value', 'requiredCapabilities', 'satisfiedCapabilities', 'isolatedFailedMemberCount')
}

$fixtures = @{}
foreach ($contract in $fixtureContracts) {
    $fixturePath = [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $contract.Name))
    $fixture = Read-JsonContractFile -Path $fixturePath
    if ($null -eq $fixture) {
        continue
    }

    $fixtures[$contract.Name] = $fixture
    $fixtureSchema = $schemas[$contract.SchemaName]
    if ($null -ne $fixtureSchema) {
        $schemaRequired = $fixtureSchema.PSObject.Properties['required']
        if ($null -ne $schemaRequired) {
            Test-RequiredProperties -Value $fixture -RequiredProperties @($schemaRequired.Value) -FixtureName $contract.Name
        }

        Test-JsonSchemaSubset -Value $fixture -Schema $fixtureSchema -RootSchema $fixtureSchema -FixtureName $contract.Name -InstancePath '$' -SkipCurrentRequired
    }

    $schemaVersion = $fixture.PSObject.Properties['schemaVersion']
    if ($null -eq $schemaVersion -or $schemaVersion.Value -cne '1.0.0') {
        $issues.Add("Fixture '$($contract.Name)' schemaVersion must be exactly 1.0.0.")
    }

    foreach ($forbiddenPropertyName in @(Get-ForbiddenPropertyNames -Value $fixture)) {
        $issues.Add("Forbidden original project restoration property found in '$forbiddenPropertyName'.")
    }
}

$sourceFixture = $fixtures['valid-source-corpus-ledger.json']
if ($null -ne $sourceFixture) {
    foreach ($source in @(Get-PropertyByPath -Value $sourceFixture -Path 'sources')) {
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $source -Path 'sourceKind') -Dimension 'sourceKind' -VocabularyDimension 'sourceKind' -FixtureName 'valid-source-corpus-ledger.json'
    }

    foreach ($file in @(Get-PropertyByPath -Value $sourceFixture -Path 'files')) {
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $file -Path 'sourceKind') -Dimension 'sourceKind' -VocabularyDimension 'sourceKind' -FixtureName 'valid-source-corpus-ledger.json'
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $file -Path 'parseStatus') -Dimension 'extraction' -VocabularyDimension 'extraction' -FixtureName 'valid-source-corpus-ledger.json'
        foreach ($dimension in @('corpus', 'extraction', 'semantics', 'unity', 'disposition')) {
            Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $file -Path "status.$dimension") -Dimension $dimension -VocabularyDimension $dimension -FixtureName 'valid-source-corpus-ledger.json'
        }
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $file -Path 'disposition') -Dimension 'disposition' -VocabularyDimension 'disposition' -FixtureName 'valid-source-corpus-ledger.json'
    }

    foreach ($object in @(Get-PropertyByPath -Value $sourceFixture -Path 'objects')) {
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $object -Path 'configurationDisposition') -Dimension 'configurationDisposition' -VocabularyDimension 'configurationDisposition' -FixtureName 'valid-source-corpus-ledger.json'
        foreach ($dimension in @('corpus', 'extraction', 'semantics', 'unity', 'disposition')) {
            Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $object -Path "status.$dimension") -Dimension $dimension -VocabularyDimension $dimension -FixtureName 'valid-source-corpus-ledger.json'
        }
    }
}

$authoringFixture = $fixtures['valid-authoring-reuse-ledger.json']
if ($null -ne $authoringFixture) {
    foreach ($family in @(Get-PropertyByPath -Value $authoringFixture -Path 'families')) {
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $family -Path 'decision') -Dimension 'decision' -VocabularyDimension 'disposition' -FixtureName 'valid-authoring-reuse-ledger.json'
        Test-FixtureVocabularyValue -Value (Get-PropertyByPath -Value $family -Path 'staticOutcome') -Dimension 'staticOutcome' -VocabularyDimension 'familyStaticOutcome' -FixtureName 'valid-authoring-reuse-ledger.json'
    }
}

$negativeFixtures = @{}
foreach ($contract in $negativeFixtureContracts) {
    $fixturePath = [System.IO.Path]::GetFullPath((Join-Path $FixtureRoot $contract.Name))
    $fixture = Read-JsonContractFile -Path $fixturePath
    if ($null -eq $fixture) {
        continue
    }

    $negativeFixtures[$contract.Name] = $fixture
    $actualIssues = @(Get-NegativeFixtureSemanticIssues -Fixture $fixture -Rule $contract.Rule)
    $expectedIssues = @($contract.ExpectedIssue)
    $issuesMatch = $actualIssues.Count -eq $expectedIssues.Count
    if ($issuesMatch) {
        for ($index = 0; $index -lt $expectedIssues.Count; $index++) {
            if ($actualIssues[$index] -cne $expectedIssues[$index]) {
                $issuesMatch = $false
                break
            }
        }
    }

    if (-not $issuesMatch) {
        $expectedText = $expectedIssues | ConvertTo-Json -Compress
        $actualText = $actualIssues | ConvertTo-Json -Compress
        $issues.Add("Negative fixture '$($contract.Name)' did not produce exactly its expected issues. Expected: $expectedText; Actual: $actualText.")
    }
}

$stopwatch.Stop()
$result = [pscustomobject][ordered]@{
    status            = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount        = $issues.Count
    issues            = $issues.ToArray()
    schemaCount       = $schemas.Count
    fixtureCount      = $fixtures.Count
    negativeFixtureCount = $negativeFixtures.Count
    childProcessCount = 0
    durationMs        = $stopwatch.ElapsedMilliseconds
}

if ($issues.Count -gt 0) {
    Write-Output ($result | ConvertTo-Json -Depth 5 -Compress)
    throw "Asset corpus contract validation failed with $($issues.Count) issue(s)."
}

Write-Output ($result | ConvertTo-Json -Depth 5 -Compress)
