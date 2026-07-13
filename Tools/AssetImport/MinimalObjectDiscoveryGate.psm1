Set-StrictMode -Version Latest

function Test-ExactPropertySet {
    param(
        [Parameter(Mandatory)] [object] $Value,
        [Parameter(Mandatory)] [string[]] $Expected,
        [Parameter(Mandatory)] [string] $Location,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[string]] $Issues
    )

    $actual = @($Value.PSObject.Properties.Name)
    foreach ($name in $Expected) {
        if ($name -notin $actual) {
            $Issues.Add("MissingField:$Location.$name")
        }
    }
    foreach ($name in $actual) {
        if ($name -notin $Expected) {
            $Issues.Add("ExtraField:$Location.$name")
        }
    }
}

function Test-NonEmptyString {
    param([object] $Value)
    return $Value -is [string] -and -not [string]::IsNullOrWhiteSpace($Value)
}

function Test-NonNegativeInteger {
    param([object] $Value)
    return ($Value -is [int] -or $Value -is [long]) -and $Value -ge 0
}

function Test-RepositoryPath {
    param([object] $Value)
    if (-not (Test-NonEmptyString $Value)) { return $false }
    return $Value -match '^(?![A-Za-z][A-Za-z0-9+.-]*:)(?![\\/])(?!\.{1,2}(?:[\\/]|$))(?!.*[\\/]\.{1,2}(?:[\\/]|$)).+$'
}

function Test-InVocabulary {
    param([object] $Vocabulary, [string] $Dimension, [object] $Value)
    $property = $Vocabulary.PSObject.Properties[$Dimension]
    return $null -ne $property -and $Value -in @($property.Value)
}

function New-GateResult {
    param(
        [object] $Ledger,
        [AllowEmptyCollection()] [System.Collections.Generic.List[string]] $Issues,
        [int] $SubjectCount
    )

    $failed = $Issues.Count -gt 0
    $emitted = if ($failed) { 0 } else { $SubjectCount }
    $rejected = if ($failed) { $SubjectCount } else { 0 }
    return [pscustomobject][ordered]@{
        Ledger = if ($failed) { $null } else { $Ledger }
        Issues = @($Issues)
        Coverage = [pscustomobject][ordered]@{
            observationSubjectCount = $SubjectCount
            emittedObjectCount = $emitted
            rejectedObservationCount = $rejected
        }
    }
}

function ConvertTo-MinimalObjectLedger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Handoff,
        [Parameter(Mandatory)] [object] $C1Ledger,
        [Parameter(Mandatory)] [object] $ObservationDocument,
        [Parameter(Mandatory)] [object] $LedgerSchema,
        [Parameter(Mandatory)] [object] $Vocabulary
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $topKeys = @('schemaVersion', 'observations')
    Test-ExactPropertySet -Value $ObservationDocument -Expected $topKeys -Location '$' -Issues $issues

    if ($null -eq $ObservationDocument.PSObject.Properties['observations']) {
        return New-GateResult -Ledger $null -Issues $issues -SubjectCount 0
    }

    $observations = @($ObservationDocument.observations)
    $subjectCount = $observations.Count
    if ($ObservationDocument.observations -isnot [System.Array]) {
        $issues.Add('InvalidType:$.observations')
    }
    if ($ObservationDocument.schemaVersion -ne '1.0.0') {
        $issues.Add('InvalidPrivateSchemaVersion')
    }

    if ($Handoff.snapshotId -ne $C1Ledger.snapshotId) { $issues.Add('C1SnapshotMismatch') }
    if ($Handoff.inputFingerprint -ne $C1Ledger.inputFingerprint) { $issues.Add('C1FingerprintMismatch') }
    if ([int]$Handoff.sourceCount -ne @($C1Ledger.sources).Count) { $issues.Add('C1SourceCountMismatch') }
    if ([int]$Handoff.fileCount -ne @($C1Ledger.files).Count) { $issues.Add('C1FileCountMismatch') }
    if ([int]$Handoff.objectCount -ne @($C1Ledger.objects).Count) { $issues.Add('C1ObjectCountMismatch') }

    $rowKeys = @(
        'assetObjectId', 'sourceId', 'containerRelativePath', 'classId',
        'objectType', 'objectName', 'serializedSizeBytes', 'dependencyObjectIds',
        'toolName', 'observation', 'canonicalAssetId', 'platformVariant',
        'configurationDisposition', 'evidence'
    )
    $identityRows = @{}
    $candidateObjects = [System.Collections.Generic.List[object]]::new()

    for ($index = 0; $index -lt $observations.Count; $index++) {
        $row = $observations[$index]
        $location = "row[$index]"
        $before = $issues.Count
        Test-ExactPropertySet -Value $row -Expected $rowKeys -Location $location -Issues $issues

        $hasAllFields = $true
        foreach ($key in $rowKeys) {
            if ($null -eq $row.PSObject.Properties[$key]) { $hasAllFields = $false }
        }
        if (-not $hasAllFields) { continue }

        if (-not (Test-NonEmptyString $row.assetObjectId)) { $issues.Add("InvalidValue:$location.assetObjectId") }
        if (-not (Test-NonEmptyString $row.sourceId)) { $issues.Add("InvalidValue:$location.sourceId") }
        if (-not (Test-RepositoryPath $row.containerRelativePath)) { $issues.Add("PublicSchema:$location.containerRelativePath") }
        if (-not (Test-NonNegativeInteger $row.classId)) { $issues.Add("PublicSchema:$location.classId") }
        if (-not (Test-NonEmptyString $row.objectType)) { $issues.Add("InvalidValue:$location.objectType") }
        if (-not (Test-NonEmptyString $row.objectName)) { $issues.Add("InvalidValue:$location.objectName") }
        if (-not (Test-NonNegativeInteger $row.serializedSizeBytes)) { $issues.Add("PublicSchema:$location.serializedSizeBytes") }
        if ($row.dependencyObjectIds -isnot [System.Array]) { $issues.Add("PublicSchema:$location.dependencyObjectIds") }
        if (-not (Test-NonEmptyString $row.toolName)) { $issues.Add("InvalidValue:$location.toolName") }
        if (-not (Test-NonEmptyString $row.observation)) { $issues.Add("InvalidValue:$location.observation") }
        if (-not (Test-NonEmptyString $row.canonicalAssetId)) { $issues.Add("InvalidValue:$location.canonicalAssetId") }
        if (-not (Test-NonEmptyString $row.platformVariant)) { $issues.Add("InvalidValue:$location.platformVariant") }
        if (-not (Test-InVocabulary $Vocabulary 'configurationDisposition' $row.configurationDisposition)) {
            $issues.Add("PublicVocabulary:$location.configurationDisposition")
        }
        if ($row.evidence -isnot [System.Array]) { $issues.Add("PublicSchema:$location.evidence") }

        foreach ($dependency in @($row.dependencyObjectIds)) {
            if (-not (Test-NonEmptyString $dependency)) { $issues.Add("InvalidValue:$location.dependencyObjectIds") }
        }
        foreach ($evidencePath in @($row.evidence)) {
            if (-not (Test-RepositoryPath $evidencePath) -or
                -not $evidencePath.StartsWith('Tools/AssetImport/Fixtures/DiscoveryGate/', [System.StringComparison]::Ordinal) -or
                $evidencePath -match '(^|[\\/])(Extracted|Imported)([\\/]|$)') {
                $issues.Add("UnsafeEvidence:$location.evidence")
            }
        }

        if (-not $identityRows.ContainsKey([string]$row.assetObjectId)) {
            $identityRows[[string]$row.assetObjectId] = [System.Collections.Generic.List[int]]::new()
        }
        $identityRows[[string]$row.assetObjectId].Add($index)

        if (-not (@($C1Ledger.sources).sourceId -contains $row.sourceId)) {
            $issues.Add("C1SourceMismatch:$location")
        }
        $matchingFile = @($C1Ledger.files | Where-Object {
            $_.sourceId -eq $row.sourceId -and $_.relativePath -eq $row.containerRelativePath
        })
        if ($matchingFile.Count -ne 1) {
            $issues.Add("C1FileMismatch:$location")
        }

        if ($issues.Count -eq $before) {
            $candidateObjects.Add([pscustomobject][ordered]@{
                assetObjectId = $row.assetObjectId
                sourceId = $row.sourceId
                containerRelativePath = $row.containerRelativePath
                classId = $row.classId
                objectType = $row.objectType
                objectName = $row.objectName
                serializedSizeBytes = $row.serializedSizeBytes
                dependencyObjectIds = @($row.dependencyObjectIds)
                toolObservations = @([pscustomobject][ordered]@{
                    toolName = $row.toolName
                    observation = $row.observation
                })
                canonicalAssetId = $row.canonicalAssetId
                platformVariant = $row.platformVariant
                configurationDisposition = $row.configurationDisposition
                evidence = @($row.evidence)
                status = [pscustomobject][ordered]@{
                    corpus = 'Cataloged'
                    extraction = 'ExtractedReadable'
                    semantics = 'PartiallyKnown'
                    unity = 'NotTested'
                    disposition = 'RetainForLater'
                }
            })
        }
    }

    foreach ($entry in $identityRows.GetEnumerator()) {
        if ($entry.Value.Count -gt 1) {
            foreach ($rowIndex in $entry.Value) {
                $issues.Add("DuplicateAssetObjectId:row[$rowIndex]:$($entry.Key)")
            }
        }
    }

    $fixedStatus = @{
        corpus = 'Cataloged'
        extraction = 'ExtractedReadable'
        semantics = 'PartiallyKnown'
        unity = 'NotTested'
        disposition = 'RetainForLater'
    }
    foreach ($dimension in $fixedStatus.Keys) {
        if (-not (Test-InVocabulary $Vocabulary $dimension $fixedStatus[$dimension])) {
            $issues.Add("PublicVocabulary:status.$dimension")
        }
    }

    $ledger = [pscustomobject][ordered]@{
        schemaVersion = $C1Ledger.schemaVersion
        snapshotId = $C1Ledger.snapshotId
        generatedAt = $C1Ledger.generatedAt
        inputFingerprint = $C1Ledger.inputFingerprint
        toolVersions = @($C1Ledger.toolVersions)
        sources = @($C1Ledger.sources)
        files = @($C1Ledger.files)
        objects = @($candidateObjects)
    }

    try {
        $candidateJson = $ledger | ConvertTo-Json -Depth 100
        $schemaJson = $LedgerSchema | ConvertTo-Json -Depth 100
        if (-not (Test-Json -Json $candidateJson -Schema $schemaJson -ErrorAction Stop)) {
            $issues.Add('PublicSchema:CandidateLedger')
        }
    }
    catch {
        $issues.Add('PublicSchema:CandidateLedger')
    }

    if ($candidateObjects.Count -ne $subjectCount) {
        $issues.Add("ConservationCandidateMismatch:${subjectCount}:$($candidateObjects.Count)")
    }

    return New-GateResult -Ledger $ledger -Issues $issues -SubjectCount $subjectCount
}

Export-ModuleMember -Function ConvertTo-MinimalObjectLedger
