[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$utf8 = [Text.UTF8Encoding]::new($false)
$generatedAt = '2026-07-17T02:00:00Z'
$snapshotId = 'snapshot-pc-install-001'

$c2Module = Import-Module (Join-Path $PSScriptRoot 'C2DiscoveryIntakeGate.psm1') -Force -PassThru
Import-Module (Join-Path $PSScriptRoot 'C3FamilyMembershipGate.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'C5RequirementEvidenceGate.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'C6AuthoringDecisionGate.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'C6AuthoringOutputGate.psm1') -Force
$g5Module = Import-Module (Join-Path $PSScriptRoot 'G5RootDecisionGate.psm1') -Force -PassThru

function Get-Sha256([string] $Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($utf8.GetBytes($Text))).ToLowerInvariant()
}
function ConvertTo-CanonicalJson($Value) {
    (($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
}
function ConvertFrom-CanonicalJson([string] $Text) {
    $Text | ConvertFrom-Json -Depth 100 -DateKind String
}
function Get-OrdinalRows([object[]] $Rows, [string] $Property) {
    $array = [object[]]@($Rows)
    [Array]::Sort($array, [Collections.Generic.Comparer[object]]::Create(
        [Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare([string]$left.$Property, [string]$right.$Property) }
    ))
    @($array)
}
function New-DirectInputs([Collections.Specialized.OrderedDictionary] $Specs, [hashtable] $TextById) {
    $rows = foreach ($entry in $Specs.GetEnumerator()) {
        if (-not $TextById.ContainsKey([string]$entry.Key)) { throw "Missing execution bytes: $($entry.Key)" }
        [pscustomobject][ordered]@{
            artifactId = [string]$entry.Key
            path = [string]$entry.Value
            sha256 = Get-Sha256 ([string]$TextById[[string]$entry.Key])
        }
    }
    @(Get-OrdinalRows @($rows) path)
}
function New-ExecutionArtifacts([Collections.Specialized.OrderedDictionary] $Specs, [hashtable] $TextById, [string[]] $Ids = @()) {
    $selected = if ($Ids.Count) { $Ids } else { [string[]]@($Specs.Keys) }
    @($selected | ForEach-Object {
        [pscustomobject][ordered]@{ artifactId = $_; bytes = [string]$TextById[$_] }
    })
}
function ConvertTo-Scalar([string] $Name, [string] $Value) {
    "${Name}:$($utf8.GetByteCount($Value)):${Value}`n"
}
function Get-C6HistoryInputFingerprint([object[]] $Entries) {
    $ordered = @(Get-OrdinalRows $Entries path)
    $count = [string]$ordered.Count
    $text = "LifecycleStageInputV1`nentries.count:$($utf8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $nested = "C2ArtifactEntryV1`n"
        $nested += ConvertTo-Scalar path ([string]$ordered[$index].path)
        $nested += ConvertTo-Scalar sha256 ([string]$ordered[$index].sha256)
        $text += "entries[$index]:$($utf8.GetByteCount($nested)):$nested`n"
    }
    Get-Sha256 $text
}
function Assert-Passed($Result, [string] $Stage) {
    $status = if ($Result.PSObject.Properties['gateStatus']) { $Result.gateStatus } else { $Result.status }
    if ($status -cne 'Passed') {
        $detail = if ($Result.PSObject.Properties['summary']) { $Result.summary.decision.failureAttribution } elseif ($Result.PSObject.Properties['issues']) { @($Result.issues) -join '; ' } else { $Result | ConvertTo-Json -Depth 20 -Compress }
        throw "$Stage failed: $detail"
    }
}

$lanePolicyText = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'), $utf8)
$decisionPolicyText = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json'), $utf8)
$vocabularyText = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json'), $utf8)
$laneFactSchemaText = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c2-lane-fact-package.schema.json'), $utf8)
$rootSchemaBytes = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'docs/asset-migration/schemas/root-gate-summary.schema.json'))
$lanePolicy = ConvertFrom-CanonicalJson $lanePolicyText
$decisionPolicy = ConvertFrom-CanonicalJson $decisionPolicyText
$vocabulary = ConvertFrom-CanonicalJson $vocabularyText

# C2: serialize one coherent Passed generation. This is the only seed fixture;
# all later lifecycle artifacts are produced by the current gate implementations.
$objectId = 'sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11'
$canonicalId = 'canonical-sha256:1111111111111111111111111111111111111111111111111111111111111111'
$configurationObjectId = 'sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
$configurationCanonicalId = 'canonical-sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
$configurationCandidateId = 'config-sha256:9999999999999999999999999999999999999999999999999999999999999999'
$observationId = 'observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180'
$inputFingerprint = 'a' * 64
$ledgerFingerprint = 'd' * 64
$discoveryFingerprint = '96b09428bc1f08b74a85c5b7fb489b4a2fb8242cc3e1a7623b6f855e15dee56b'
$evidencePath = 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json'
$toolObservation = "version=1.0.0;observationId=$observationId;resolution=SingleTool"
$status = [pscustomobject][ordered]@{ corpus = 'Cataloged'; extraction = 'ExtractedReadable'; semantics = 'Known'; unity = 'NotTested'; disposition = 'RetainForLater' }
$source = [pscustomobject][ordered]@{ sourceId = 'pc-install-primary'; sourceKind = 'PcInstall'; capturedAt = $generatedAt; rootFingerprint = 'c' * 64 }
$file = [pscustomobject][ordered]@{ snapshotId = $snapshotId; sourceId = 'pc-install-primary'; sourceKind = 'PcInstall'; relativePath = 'SourceCorpus/PcInstall/game-data.bundle'; containerKind = 'Bundle'; sizeBytes = 100; sha256 = '2' * 64; capturedAt = $generatedAt; parseStatus = 'Parsed'; disposition = 'RetainForLater'; evidence = @($evidencePath); status = $status }
$object = [pscustomobject][ordered]@{ assetObjectId = $objectId; sourceId = 'pc-install-primary'; objectType = 'Sprite'; objectName = 'Hero'; containerRelativePath = 'SourceCorpus/PcInstall/game-data.bundle'; classId = 1; serializedSizeBytes = 100; dependencyObjectIds = @(); toolObservations = @([pscustomobject][ordered]@{ toolName = 'ToolA'; observation = $toolObservation }); platformVariant = 'Pc'; configurationDisposition = 'NotConfiguration'; evidence = @($evidencePath); status = $status }
$configurationStatus = [pscustomobject][ordered]@{ corpus = 'Cataloged'; extraction = 'ExtractedReadable'; semantics = 'Known'; unity = 'NotTested'; disposition = 'RetainForLater' }
$configurationObject = [pscustomobject][ordered]@{ assetObjectId = $configurationObjectId; sourceId = 'pc-install-primary'; objectType = 'MonoBehaviour'; objectName = 'Configuration'; containerRelativePath = 'SourceCorpus/PcInstall/game-data.bundle'; classId = 114; serializedSizeBytes = 50; dependencyObjectIds = @(); toolObservations = @([pscustomobject][ordered]@{ toolName = 'ToolA'; observation = $toolObservation }); platformVariant = 'Pc'; configurationDisposition = 'Parsed'; evidence = @($evidencePath); status = $configurationStatus }
$canonicalGroup = [pscustomobject][ordered]@{ canonicalAssetId = $canonicalId; memberObjectIds = @($objectId); matchStatus = 'Unresolved'; platformScope = 'PcOnly'; equivalenceFingerprint = $null; variantEvidence = @() }
$configurationCanonicalGroup = [pscustomobject][ordered]@{ canonicalAssetId = $configurationCanonicalId; memberObjectIds = @($configurationObjectId); matchStatus = 'Unresolved'; platformScope = 'PcOnly'; equivalenceFingerprint = $null; variantEvidence = @() }
$dispatchRow = [pscustomobject][ordered]@{
    assetObjectId = $objectId
    canonicalAssetId = $canonicalId
    sourceId = 'pc-install-primary'
    familyLane = 'UI'
    memberSelectorInputs = @(
        [pscustomobject][ordered]@{ kind = 'CanonicalAssetId'; value = $canonicalId }
        [pscustomobject][ordered]@{ kind = 'ClassId'; value = '1' }
        [pscustomobject][ordered]@{ kind = 'ObjectType'; value = 'Sprite' }
        [pscustomobject][ordered]@{ kind = 'PlatformVariant'; value = 'Pc' }
        [pscustomobject][ordered]@{ kind = 'ToolObservation'; value = $toolObservation }
    )
    configurationCandidateId = $null
    dispatchStatus = 'Assigned'
    evidence = @($evidencePath)
}
$configurationDispatchRow = [pscustomobject][ordered]@{
    assetObjectId = $configurationObjectId
    canonicalAssetId = $configurationCanonicalId
    sourceId = 'pc-install-primary'
    familyLane = 'Unassigned'
    memberSelectorInputs = @(
        [pscustomobject][ordered]@{ kind = 'CanonicalAssetId'; value = $configurationCanonicalId }
        [pscustomobject][ordered]@{ kind = 'ClassId'; value = '114' }
        [pscustomobject][ordered]@{ kind = 'ObjectType'; value = 'MonoBehaviour' }
        [pscustomobject][ordered]@{ kind = 'PlatformVariant'; value = 'Pc' }
        [pscustomobject][ordered]@{ kind = 'ToolObservation'; value = $toolObservation }
    )
    configurationCandidateId = $configurationCandidateId
    dispatchStatus = 'ConfigurationOnly'
    evidence = @($evidencePath)
}
$configurationCandidate = [pscustomobject][ordered]@{ configurationCandidateId = $configurationCandidateId; targetKind = 'Object'; sourceId = 'pc-install-primary'; containerRelativePath = 'SourceCorpus/PcInstall/game-data.bundle'; assetObjectId = $configurationObjectId; configurationDisposition = 'Parsed'; observationIds = @($observationId); evidence = @($evidencePath) }
$coverage = [pscustomobject][ordered]@{
    files = [pscustomobject][ordered]@{ catalogedFileCount = 1; catalogedBytes = 100; catalogedContainerCount = 1; catalogedContainerBytes = 100; nonContainerFileCount = 0; nonContainerFileBytes = 0; fileDiscoverySubjectCount = 1; fileDiscoverySubjectBytes = 100; notAttemptedFileCount = 0; notAttemptedFileBytes = 0; parsedFileCount = 1; parsedFileBytes = 100; opaqueFileCount = 0; opaqueFileBytes = 0; failedFileCount = 0; failedFileBytes = 0; fileDiscoveryConflictFileCount = 0; fileDiscoveryConflictFileBytes = 0 }
    containers = [pscustomobject][ordered]@{ notAttemptedContainerCount = 0; notAttemptedContainerBytes = 0; parsedContainerCount = 1; parsedContainerBytes = 100; opaqueContainerCount = 0; opaqueContainerBytes = 0; failedContainerCount = 0; failedContainerBytes = 0; fileDiscoveryConflictContainerCount = 0; fileDiscoveryConflictContainerBytes = 0 }
    objects = [pscustomobject][ordered]@{ objectObservationRowCount = 2; acceptedObjectObservationRowCount = 2; rejectedObjectObservationRowCount = 0; excludedObjectObservationRowCount = 0; correlationGroupCount = 2; enumeratedObjectCount = 2; observationConflictObjectCount = 0; classifiedObjectCount = 2; unclassifiedObjectCount = 0; unresolvedDependencyCount = 0 }
    configuration = [pscustomobject][ordered]@{ configurationDiscoverySubjectCount = 1; configurationCandidateCount = 1; configurationConflictCount = 0; parsedConfigurationCount = 1; discoveredOpaqueConfigurationCount = 0; encryptedConfigurationCount = 0; requiresRuntimeTypeConfigurationCount = 0; likelyServerDependentConfigurationCount = 0; notConfigurationCount = 1 }
    canonical = [pscustomobject][ordered]@{ canonicalizedObjectCount = 2; canonicalConflictObjectCount = 0; canonicalGroupCount = 2; exactDuplicateGroupCount = 0; platformVariantGroupCount = 0; unresolvedCanonicalGroupCount = 2 }
    dispatch = [pscustomobject][ordered]@{ dispatchEligibleObjectCount = 2; assignedObjectCount = 1; retainedForDiagnosisObjectCount = 0; configurationOnlyObjectCount = 1; audioObjectCount = 0; environmentObjectCount = 0; actorObjectCount = 0; uiObjectCount = 1; effectsObjectCount = 0 }
}
$discoveryInputs = @(
    'Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json',
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json',
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json',
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json',
    'docs/asset-migration/schemas/root-gate-summary.schema.json',
    'docs/asset-migration/schemas/source-corpus-ledger.schema.json',
    'docs/asset-migration/schemas/status-vocabulary.json'
) | ForEach-Object { [pscustomobject][ordered]@{ path = $_; sha256 = '1' * 64 } }
$contractChange = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; generatedAt = $generatedAt; requestId = 'C0ContractChange:C2StructuredCoverage:1.0.0'; reason = 'Root gate summary schema 2.0.0 losslessly represents mandatory C2 structured coverage partitions.'; nextAllowedAction = 'Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.'; inputFingerprint = $inputFingerprint; discoveryInputFingerprint = $discoveryFingerprint; status = 'Resolved'; missingProjectionFields = @(); evidence = @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json','docs/asset-migration/schemas/root-gate-summary.schema.json') }
$failureAccounting = [pscustomobject][ordered]@{ inputSubjectCount = 21; acceptedInputSubjectCount = 21; notEvaluatedInputSubjectCount = 0; inputObservationCount = 6; acceptedInputObservationCount = 6; rejectedInputObservationCount = 0; inputFailureCount = 0; excludedInputSubjectCount = 0; excludedInputCount = 0; contractFailureRecordCount = 0; fileDiscoveryConflictRecordCount = 0; observationConflictRecordCount = 0; configurationConflictRecordCount = 0; canonicalConflictRecordCount = 0; issueCount = 0; gateStatus = 'Passed' }
$decision = [pscustomobject][ordered]@{ failureAttribution = 'None; C2 registry-derived gates passed.'; nextAllowedAction = 'Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.' }
$c2Input = [pscustomobject][ordered]@{
    schemaVersion = '1.0.0'; generatedAt = $generatedAt; snapshotId = $snapshotId; inputFingerprint = $inputFingerprint; ledgerInputFingerprint = $ledgerFingerprint; discoveryInputFingerprint = $discoveryFingerprint; gateStatus = 'Passed'
    toolVersions = @([pscustomobject][ordered]@{ toolName = 'ToolA'; version = '1.0.0' }); sources = @($source); files = @($file); objects = @($object, $configurationObject)
    configurationCandidates = @($configurationCandidate); configurationConflicts = @(); canonicalGroups = @($canonicalGroup, $configurationCanonicalGroup); canonicalConflicts = @()
    sourceLedgerPath = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'; dispatchRows = @($dispatchRow, $configurationDispatchRow)
    resolvedFileResults = @(); mergedObjectCandidates = @(); canonicalProposalProvenance = @(); dispatchInputFacts = @(); fileDiscoveryConflicts = @(); observationConflicts = @()
    inputFailures = @(); inputExclusions = @(); inputSuppressions = @(); discoveryInputs = @($discoveryInputs); coverage = $coverage; failureAccounting = $failureAccounting; decision = $decision; contractChangeRequest = $contractChange
}
$c2 = @($c2Module.Invoke({ param($value) Invoke-C2OutputSerialization $value }, @($c2Input)))[0]
if ($c2.outputAccounting.projectedOutputCount -ne 5 -or @($c2.artifacts | Where-Object desiredState -CEQ Present).Count -ne 8) { throw 'C2 output generation did not publish a complete in-memory set.' }
$c2TextById = @{
    'LC-I01' = [string]$c2.artifacts[0].text
    'LC-I02' = [string]$c2.artifacts[1].text
    'LC-I03' = [string]$c2.artifacts[2].text
    'LC-I04' = [string]$c2.artifacts[3].text
    'LC-I05' = [string]$c2.artifacts[7].text
}
$c2Ledger = ConvertFrom-CanonicalJson $c2TextById['LC-I01']
$c2Configuration = ConvertFrom-CanonicalJson $c2TextById['LC-I02']
$c2Dispatch = ConvertFrom-CanonicalJson $c2TextById['LC-I04']
$c2Summary = ConvertFrom-CanonicalJson $c2TextById['LC-I05']

$laneProjection = @($c2Module.Invoke(
    { param($dispatch, $summary, $schema) Invoke-C2TypedLaneFactProjection -DispatchBytes $dispatch -SummaryBytes $summary -SchemaBytes $schema },
    @($utf8.GetBytes($c2TextById['LC-I04']), $utf8.GetBytes($c2TextById['LC-I05']), $utf8.GetBytes($laneFactSchemaText))
))[0]
Assert-Passed $laneProjection 'LC-I06'
$laneFactText = [string]@($c2Module.Invoke({ param($value) ConvertTo-C2CanonicalJson $value }, @($laneProjection.package)))[0]
$laneFacts = $laneProjection.package
if ($laneFacts.rows.Count -ne 4 -or $laneProjection.subjectAccounting.Count -ne 2) { throw 'LC-I06 did not project the exact two-subject generation.' }

$c3Specs = [ordered]@{
    'LC-I01' = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'
    'LC-I02' = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json'
    'LC-I03' = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json'
    'LC-I04' = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json'
    'LC-I05' = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json'
    'LC-I06' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json'
    'LC-I07' = 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
    'LC-I08' = 'docs/asset-migration/schemas/status-vocabulary.json'
    'LC-I13' = 'docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
}
$c3Texts = @{} + $c2TextById
$c3Texts['LC-I06'] = $laneFactText; $c3Texts['LC-I07'] = $lanePolicyText; $c3Texts['LC-I08'] = $vocabularyText; $c3Texts['LC-I13'] = $laneFactSchemaText
$c3Inputs = New-DirectInputs $c3Specs $c3Texts
$c3 = Invoke-C3FamilyMembershipGate -DispatchRows @($c2Dispatch.rows) -TypedFactRows @($laneFacts.rows) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyText -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects @($c2Ledger.objects) -ConfigurationCandidates @($c2Configuration.configurationCandidates) -ExecutionArtifacts (New-ExecutionArtifacts $c3Specs $c3Texts) -Stage ([pscustomobject][ordered]@{ generatedAt = $generatedAt; snapshotId = $snapshotId; toolVersions = @('SameGenerationHarness:1.0.0'); directInputs = $c3Inputs })
Assert-Passed $c3 'C3'
if ($c3.summary.coverage.dispatchEligibleObjectCount -ne 2 -or $c3.summary.coverage.assignedFamilyMemberCount -ne 0 -or $c3.summary.coverage.retainedForDiagnosisObjectCount -ne 1 -or $c3.summary.coverage.configurationOnlyObjectCount -ne 1 -or $c3.familyRegistry.families.Count -ne 0) { throw 'C3 did not conserve the key-incomplete and configuration-only same-generation subjects.' }

$c3OutputTexts = @{
    'C3-O01' = $c3.texts.familyRegistry; 'C3-O02' = $c3.texts.familyMemberLedger; 'C3-O03' = $c3.texts.crossLaneReferencePackage
    'C3-O04-Summary' = $c3.texts.summary; 'C3-O04-Report' = $c3.report
}
$emptyObservationPackage = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; generatedAt = $generatedAt; snapshotId = $snapshotId; rows = @() }
$c4Specs = [ordered]@{
    'C3-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json'; 'C3-O02' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json'; 'C3-O03' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json'; 'C3-O04-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json'; 'C3-O04-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
    'LC-I01' = $c3Specs['LC-I01']; 'LC-I02' = $c3Specs['LC-I02']; 'LC-I03' = $c3Specs['LC-I03']; 'LC-I06' = $c3Specs['LC-I06']; 'LC-I07' = $c3Specs['LC-I07']; 'LC-I08' = $c3Specs['LC-I08']; 'LC-I13' = $c3Specs['LC-I13']
    'LC-I14' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-static-observation-package.json'
}
$c4Texts = @{} + $c3Texts + $c3OutputTexts
$c4Texts['LC-I14'] = ConvertTo-CanonicalJson $emptyObservationPackage
$c4Inputs = New-DirectInputs $c4Specs $c4Texts
$c4 = Invoke-C4StaticQualificationGate -FamilyRegistry $c3.familyRegistry -FamilyMemberLedger $c3.familyMemberLedger -CrossLaneReferencePackage $c3.crossLaneReferencePackage -TypedFactRows @($laneFacts.rows) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyText -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @() -ExecutionArtifacts (New-ExecutionArtifacts $c4Specs $c4Texts) -Stage ([pscustomobject][ordered]@{ generatedAt = $generatedAt; snapshotId = $snapshotId; toolVersions = @('SameGenerationHarness:1.0.0'); directInputs = $c4Inputs })
Assert-Passed $c4 'C4'
if ($c4.summary.coverage.memberCount -ne 0 -or $c4.memberStaticQualification.memberResults.Count -ne 0) { throw 'C4 invented members outside the C3 family universe.' }

$c4OutputTexts = @{
    'C4-O01' = $c4.texts.memberStaticQualification; 'C4-O02' = $c4.texts.familyStaticSummary
    'C4-O03-Summary' = $c4.texts.summary; 'C4-O03-Report' = $c4.report
}
$c5Specs = [ordered]@{
    'C3-O01' = $c4Specs['C3-O01']; 'C3-O02' = $c4Specs['C3-O02']; 'C3-O03' = $c4Specs['C3-O03']; 'C3-O04-Summary' = $c4Specs['C3-O04-Summary']; 'C3-O04-Report' = $c4Specs['C3-O04-Report']
    'C4-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json'; 'C4-O02' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json'; 'C4-O03-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json'; 'C4-O03-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'
    'LC-I06' = $c3Specs['LC-I06']; 'LC-I07' = $c3Specs['LC-I07']; 'LC-I08' = $c3Specs['LC-I08']; 'LC-I11' = 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json'; 'LC-I13' = $c3Specs['LC-I13']
}
$c5Texts = @{} + $c3Texts + $c3OutputTexts + $c4OutputTexts
$c5Texts['LC-I11'] = $decisionPolicyText
$c5Inputs = New-DirectInputs $c5Specs $c5Texts
$c5 = Invoke-C5RequirementEvidenceGate -FamilyRegistry $c3.familyRegistry -MemberStaticQualification $c4.memberStaticQualification -RiskFactRows @($laneFacts.rows) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyText -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyText -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -EvidencePackages @() -EvidencePackageBytes @() -ExecutionArtifacts (New-ExecutionArtifacts $c5Specs $c5Texts) -Stage ([pscustomobject][ordered]@{ generatedAt = $generatedAt; snapshotId = $snapshotId; toolVersions = @('SameGenerationHarness:1.0.0'); directInputs = $c5Inputs })
Assert-Passed $c5 'C5'
if ($c5.summary.coverage.familyCount -ne 0 -or $c5.summary.coverage.representativeRequirementCount -ne 0 -or $c5.summary.coverage.capabilitySuitabilityRequirementCount -ne 0) { throw 'C5 invented requirements outside the same-generation family universe.' }

$c5OutputTexts = @{
    'C5-O01' = $c5.texts.representativeRequirements; 'C5-O02' = $c5.texts.evidenceAssessment
    'C5-O04-Summary' = $c5.texts.summary; 'C5-O04-Report' = $c5.report
}
$c6Specs = [ordered]@{
    'C3-O04-Report' = $c4Specs['C3-O04-Report']; 'C3-O04-Summary' = $c4Specs['C3-O04-Summary']; 'C4-O03-Report' = $c5Specs['C4-O03-Report']; 'C4-O03-Summary' = $c5Specs['C4-O03-Summary']; 'C5-O04-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-report.md'; 'C5-O04-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-summary.json'
    'C3-O03' = $c4Specs['C3-O03']; 'C5-O02' = $c5Specs['C4-O02']; 'C3-O02' = $c4Specs['C3-O02']; 'C3-O01' = $c4Specs['C3-O01']; 'C4-O02' = $c5Specs['C4-O02']; 'C4-O01' = $c5Specs['C4-O01']; 'C5-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-representative-requirements.json'
    'LC-I11' = $c5Specs['LC-I11']; 'LC-I07' = $c3Specs['LC-I07']; 'LC-I08' = $c3Specs['LC-I08']; 'LC-I12' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/repair-attempt-history.json'
}
# C5-O02 path above is corrected here to the evidence-assessment registry path.
$c6Specs['C5-O02'] = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json'
$history = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; generatedAt = $generatedAt; inputFingerprint = '0' * 64; attempts = @() }
$c6Texts = @{} + $c3OutputTexts + $c4OutputTexts + $c5OutputTexts
$c6Texts['LC-I11'] = $decisionPolicyText; $c6Texts['LC-I07'] = $lanePolicyText; $c6Texts['LC-I08'] = $vocabularyText; $c6Texts['LC-I12'] = ConvertTo-CanonicalJson $history
$c6Inputs = New-DirectInputs $c6Specs $c6Texts
$history.inputFingerprint = Get-C6HistoryInputFingerprint @($c6Inputs | Where-Object artifactId -CNE 'LC-I12')
$c6Texts['LC-I12'] = ConvertTo-CanonicalJson $history
$c6Inputs = New-DirectInputs $c6Specs $c6Texts
$c6ExecutionIds = @('C3-O01','C3-O02','C3-O03','C4-O01','C4-O02','C5-O01','C5-O02')
$c6Decision = Invoke-C6AuthoringDecisionKernel -FamilyRegistry $c3.familyRegistry -FamilyMemberLedger $c3.familyMemberLedger -CrossLaneReferencePackage $c3.crossLaneReferencePackage -MemberStaticQualification $c4.memberStaticQualification -FamilyStaticSummary $c4.familyStaticSummary -RepresentativeRequirements $c5.representativeRequirements -EvidenceAssessment $c5.evidenceAssessment -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyText -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyText -StatusVocabulary $vocabulary -StatusVocabularyBytes $vocabularyText -RepairAttemptHistory $history -RepairAttemptHistoryBytes $c6Texts['LC-I12'] -ExecutionArtifacts (New-ExecutionArtifacts $c6Specs $c6Texts $c6ExecutionIds) -DirectInputs $c6Inputs
Assert-Passed $c6Decision 'C6 decision'
if ($c6Decision.totalFamilyCount -ne 0 -or $c6Decision.requiredCapabilityCount -ne 7 -or $c6Decision.satisfiedCapabilityCount -ne 0) { throw 'C6 same-generation empty-family decision conservation failed.' }
$c6Stage = [pscustomobject][ordered]@{ generatedAt = $generatedAt; snapshotId = $snapshotId; toolVersions = @([pscustomobject][ordered]@{ toolName = 'same-generation-harness'; version = '1.0.0' }); directInputs = $c6Inputs }
$c6 = Invoke-C6AuthoringOutputGate -DecisionResult $c6Decision -FamilyRegistry $c3.familyRegistry -FamilyMemberLedger $c3.familyMemberLedger -MemberStaticQualification $c4.memberStaticQualification -FamilyStaticSummary $c4.familyStaticSummary -RepresentativeRequirements $c5.representativeRequirements -EvidenceAssessment $c5.evidenceAssessment -C3Summary $c3.summary -Stage $c6Stage
Assert-Passed $c6 'C6 output'
if ($c6.g5Handoff.familyConstructionCoverage.dispatchEligibleObjectCount -ne 2 -or $c6.g5Handoff.familyConstructionCoverage.retainedForDiagnosisObjectCount -ne 1 -or $c6.g5Handoff.familyConstructionCoverage.configurationOnlyObjectCount -ne 1 -or $c6.g5Handoff.stellaSora2AuthoringReady.value) { throw 'C6 handoff lost the same-generation subjects or fabricated readiness.' }

$g5Input = [pscustomobject][ordered]@{
    generatedAt = $generatedAt
    c1SummaryPath = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json'
    c1SummaryBytes = [IO.File]::ReadAllBytes((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json'))
    c2SummaryPath = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json'
    c2SummaryBytes = $utf8.GetBytes($c2TextById['LC-I05'])
    c6HandoffPath = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json'
    c6HandoffBytes = $utf8.GetBytes($c6.texts.g5Handoff)
    rootSchemaPath = 'docs/asset-migration/schemas/root-gate-summary.schema.json'
    rootSchemaBytes = $rootSchemaBytes
    additionalC3C6Inputs = @()
}
$g5 = @($g5Module.Invoke({ param($value) Invoke-G5RootDecisionGate -InputFact $value }, @($g5Input)))[0]
Assert-Passed $g5 'G5'
if ($g5.rootSummary.familyConstructionCoverage.dispatchEligibleObjectCount -ne 2 -or $g5.rootSummary.familyConstructionCoverage.retainedForDiagnosisObjectCount -ne 1 -or $g5.rootSummary.familyConstructionCoverage.configurationOnlyObjectCount -ne 1 -or $g5.rootSummary.stellaSora2AuthoringReady.value) { throw 'G5 did not preserve the current C2/C6 generation conclusions.' }
if ($g5.heavyOperationCount -ne 0 -or $g5.executorLaunchCount -ne 0 -or $g5.publicationWriteCount -ne 0) { throw 'Same-generation harness invoked a forbidden heavy or publication operation.' }

'status=Passed'
'c2DispatchEligibleObjectCount=2'
'c3AssignedFamilyMemberCount=0'
'c3RetainedForDiagnosisObjectCount=1'
'c3ConfigurationOnlyObjectCount=1'
'c4AssignedMemberCount=0'
'c5RepresentativeRequirementCount=0'
'c6TotalFamilyCount=0'
'c6RequiredCapabilityCount=7'
'g5AuthoringReady=False'
'heavyOperationCount=0'
'publicationWriteCount=0'
