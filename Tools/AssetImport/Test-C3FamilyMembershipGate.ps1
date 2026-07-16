[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C3FamilyMembershipGate.psm1') -Force -PassThru
$moduleAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'C3FamilyMembershipGate.psm1'),[ref]$null,[ref]$null)
if(@($moduleAst.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-ceq'Sort-Object'},$true)).Count){throw 'C3 module reintroduced culture-sensitive Sort-Object.'}
$policyBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'),[Text.UTF8Encoding]::new($false))
$policy = $policyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$vocabularyBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json'),[Text.UTF8Encoding]::new($false))
$vocabulary = $vocabularyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$factSchemaBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c2-lane-fact-package.schema.json'),[Text.UTF8Encoding]::new($false))

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function New-ObjectId([char]$Value) { "sha256:$([string]$Value * 64)" }
function Get-TestSha256([string]$Text) { [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.UTF8Encoding]::new($false).GetBytes($Text))).ToLowerInvariant() }
function ConvertTo-TestJson($Value) { $Value | ConvertTo-Json -Depth 100 -Compress }
function ConvertTo-TestCanonicalJson($Value) { (($Value | ConvertTo-Json -Depth 100) -replace "`r`n","`n") + "`n" }
function Get-TestOrdinalRows([object[]]$Rows,[string]$Property) {
    $list=[Collections.Generic.List[object]]::new()
    foreach($row in $Rows){$list.Add($row)}
    $list.Sort([Comparison[object]]{param($left,$right)[StringComparer]::Ordinal.Compare([string]$left.$Property,[string]$right.$Property)})
    [object[]]$list.ToArray()
}
function ConvertTo-TestScalar([string]$Name,[string]$Value) {
    "${Name}:$([Text.UTF8Encoding]::new($false).GetByteCount($Value)):${Value}`n"
}
function Get-TestStageInputFingerprint([object[]]$Entries) {
    $ordered=@(Get-TestOrdinalRows $Entries path)
    $text="LifecycleStageInputV1`nentries.count:$($ordered.Count)`n"
    for($index=0;$index-lt$ordered.Count;$index++){
        $nested="C2ArtifactEntryV1`n"
        $nested+=ConvertTo-TestScalar artifactId ([string]$ordered[$index].artifactId)
        $nested+=ConvertTo-TestScalar path ([string]$ordered[$index].path)
        $nested+=ConvertTo-TestScalar sha256 ([string]$ordered[$index].sha256)
        $text+="entries[$index]:$([Text.UTF8Encoding]::new($false).GetByteCount($nested)):$nested`n"
    }
    Get-TestSha256 $text
}
function New-Fact([string]$ObjectId,[string]$Lane,[string]$Kind,[string]$Value,[string[]]$IdValues=@()) {
    $seed = [Text.Encoding]::UTF8.GetBytes("$ObjectId|$Lane|$Kind")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($seed)).ToLowerInvariant()
    [pscustomobject][ordered]@{
        factId = "lane-fact-sha256:$hash"
        assetObjectId = $ObjectId
        lane = $Lane
        factKind = $Kind
        factStatus = 'Known'
        valueKind = if ($IdValues.Count) { 'IdSet' } else { 'String' }
        stringValue = if ($IdValues.Count) { $null } else { $Value }
        integerValue = $null
        booleanValue = $null
        idValues = [string[]]$IdValues
        evidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/c3-walking-skeleton')
    }
}

$lanes = @('Audio','Environment','Actor','UI','Effects')
$objects = [ordered]@{}
$dispatchRows = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $lanes.Count; $index++) {
    $lane = $lanes[$index]
    $id = New-ObjectId ([char](97 + $index))
    $objects[$lane] = $id
    $dispatchRows.Add([pscustomobject][ordered]@{
        assetObjectId = $id
        canonicalAssetId = "canonical-sha256:$([string]([char](102 + $index)) * 64)"
        sourceId = 'pc-install-primary'
        familyLane = $lane
        memberSelectorInputs = @()
        configurationCandidateId = $null
        dispatchStatus = 'Assigned'
        evidence = @('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')
    })
}
for($index=0;$index-lt$lanes.Count;$index++){
    $lane=$lanes[$index];$row=$dispatchRows[$index];$selectors=[Collections.Generic.List[object]]::new()
    $selectors.Add([pscustomobject][ordered]@{kind='CanonicalAssetId';value=$row.canonicalAssetId})
    $selectors.Add([pscustomobject][ordered]@{kind='ClassId';value=[string](100+$index)})
    if($lane-ceq'Actor'){$selectors.Add([pscustomobject][ordered]@{kind='DependencyObjectId';value=$objects.Environment})}
    $objectType=@($policy.policies|Where-Object lane -CEQ $lane)[0].familyKinds[0].applicableObjectTypes[0]
    $selectors.Add([pscustomobject][ordered]@{kind='ObjectType';value=$objectType})
    $selectors.Add([pscustomobject][ordered]@{kind='PlatformVariant';value='Pc'})
    $selectors.Add([pscustomobject][ordered]@{kind='ToolObservation';value="fixture-$lane"})
    $row.memberSelectorInputs=$selectors.ToArray()
}
$retainedId = "sha256:$('e' * 63)f"
$configurationId = New-ObjectId 'f'
$dispatchRows.Add([pscustomobject][ordered]@{assetObjectId=$retainedId;canonicalAssetId="canonical-sha256:$('e' * 63)f";sourceId='pc-install-primary';familyLane='Unassigned';memberSelectorInputs=@();configurationCandidateId=$null;dispatchStatus='RetainedForDiagnosis';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')})
$dispatchRows.Add([pscustomobject][ordered]@{assetObjectId=$configurationId;canonicalAssetId="canonical-sha256:$('f' * 64)";sourceId='pc-install-primary';familyLane='Unassigned';memberSelectorInputs=@();configurationCandidateId="config-sha256:$('9' * 64)";dispatchStatus='ConfigurationOnly';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')})

$facts = [Collections.Generic.List[object]]::new()
foreach ($lanePolicy in @($policy.policies)) {
    $objectId = [string]$objects[[string]$lanePolicy.lane]
    foreach ($dimension in @($lanePolicy.familyKinds[0].keyDimensionIds)) {
        $facts.Add((New-Fact $objectId $lanePolicy.lane $dimension "$($lanePolicy.lane)-$dimension"))
    }
    $facts.Add((New-Fact $objectId $lanePolicy.lane PlatformVariant Pc))
}
$facts.Add((New-Fact $objects.Actor Actor DependencyObjectIds $null @($objects.Environment)))

$ledgerObjects = @($dispatchRows | ForEach-Object -Begin {$n=0} -Process {
    $n++;$objectId=$_.assetObjectId
    [pscustomobject][ordered]@{assetObjectId=$objectId;serializedSizeBytes=100*$n;dependencyObjectIds=@($facts | Where-Object { $_.assetObjectId -ceq $objectId -and $_.factKind -ceq 'DependencyObjectIds' } | ForEach-Object idValues | ForEach-Object {$_});evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')}
})
$configurationCandidates=@([pscustomobject][ordered]@{configurationCandidateId="config-sha256:$('9' * 64)";assetObjectId=$configurationId;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json')})

$directInputPaths=[ordered]@{
    'LC-I01'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'
    'LC-I02'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json'
    'LC-I03'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json'
    'LC-I04'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json'
    'LC-I05'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json'
    'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json'
    'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
    'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json'
    'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
}
function New-C3ExecutionArtifacts(
    $Rows=$dispatchRows,
    $Facts=$facts,
    $LedgerRows=$ledgerObjects,
    $ConfigurationRows=$configurationCandidates,
    $LanePolicy=$policy,
    [string]$LaneBytes=$policyBytes,
    $Vocabulary=$vocabulary,
    [string]$VocabularyText=$vocabularyBytes
) {
    $artifacts=[Collections.Generic.List[object]]::new()
    foreach($artifact in @(
        [pscustomobject][ordered]@{artifactId='LC-I01';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId='snapshot-pc-install-001';generatedAt='2026-07-16T02:00:00Z';inputFingerprint=('1'*64);toolVersions=@('fixture');sources=@();files=@();objects=@($LedgerRows)})}
        [pscustomobject][ordered]@{artifactId='LC-I02';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);discoveryInputFingerprint=('2'*64);configurationCandidates=@($ConfigurationRows);configurationConflicts=@()})}
        [pscustomobject][ordered]@{artifactId='LC-I03';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);discoveryInputFingerprint=('2'*64);canonicalGroups=@();canonicalConflicts=@()})}
        [pscustomobject][ordered]@{artifactId='LC-I04';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);discoveryInputFingerprint=('2'*64);sourceLedgerPath=$directInputPaths['LC-I01'];rows=@($Rows)})}
        [pscustomobject][ordered]@{artifactId='LC-I06';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';c2GenerationFingerprint=('3'*64);factContractFingerprint=Get-TestSha256 $factSchemaBytes;inputFingerprint=('4'*64);rows=@($Facts)})}
        [pscustomobject][ordered]@{artifactId='LC-I07';bytes=$LaneBytes}
        [pscustomobject][ordered]@{artifactId='LC-I08';bytes=$VocabularyText}
        [pscustomobject][ordered]@{artifactId='LC-I13';bytes=$factSchemaBytes}
    )){$artifacts.Add($artifact)}
    $artifactById=@{};foreach($artifact in $artifacts){$artifactById[[string]$artifact.artifactId]=$artifact}
    $childSummaries=[Collections.Generic.List[object]]::new()
    foreach($id in @('LC-I01','LC-I02','LC-I03','LC-I04')){
        $childSummaries.Add([pscustomobject][ordered]@{path=[string]$directInputPaths[$id];sha256=Get-TestSha256 ([string]$artifactById[$id].bytes)})
    }
    $childSummaries=[object[]](Get-TestOrdinalRows $childSummaries.ToArray() path)
    $summary=[pscustomobject][ordered]@{
        schemaVersion='1.0.0'
        identity=[pscustomobject][ordered]@{generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);ledgerInputFingerprint=('5'*64);discoveryInputFingerprint=('2'*64);discoveryArtifactFingerprint=('3'*64)}
        provenance=[pscustomobject][ordered]@{toolVersions=@([pscustomobject][ordered]@{toolName='c2-discovery-gate';version='1.0.0'});operationIdentity='C2.DiscoveryCoverage.FixtureValidation'}
        directEvidence=[pscustomobject][ordered]@{
            discoveryInputs=@()
            directChildSummaries=$childSummaries
            directChildReports=@(
                [pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json';sha256=('6'*64)}
                [pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json';sha256=('7'*64)}
                [pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-report.md';sha256=('8'*64)}
            )
        }
        coverage=[pscustomobject][ordered]@{
            files=[pscustomobject][ordered]@{catalogedFileCount=0;catalogedBytes=0;catalogedContainerCount=0;catalogedContainerBytes=0;nonContainerFileCount=0;nonContainerFileBytes=0;fileDiscoverySubjectCount=0;fileDiscoverySubjectBytes=0;notAttemptedFileCount=0;notAttemptedFileBytes=0;parsedFileCount=0;parsedFileBytes=0;opaqueFileCount=0;opaqueFileBytes=0;failedFileCount=0;failedFileBytes=0;fileDiscoveryConflictFileCount=0;fileDiscoveryConflictFileBytes=0}
            containers=[pscustomobject][ordered]@{notAttemptedContainerCount=0;notAttemptedContainerBytes=0;parsedContainerCount=0;parsedContainerBytes=0;opaqueContainerCount=0;opaqueContainerBytes=0;failedContainerCount=0;failedContainerBytes=0;fileDiscoveryConflictContainerCount=0;fileDiscoveryConflictContainerBytes=0}
            objects=[pscustomobject][ordered]@{objectObservationRowCount=0;acceptedObjectObservationRowCount=0;rejectedObjectObservationRowCount=0;excludedObjectObservationRowCount=0;correlationGroupCount=0;enumeratedObjectCount=$Rows.Count;observationConflictObjectCount=0;classifiedObjectCount=$Rows.Count;unclassifiedObjectCount=0;unresolvedDependencyCount=0}
            configuration=[pscustomobject][ordered]@{configurationDiscoverySubjectCount=$ConfigurationRows.Count;configurationCandidateCount=$ConfigurationRows.Count;configurationConflictCount=0;parsedConfigurationCount=0;discoveredOpaqueConfigurationCount=0;encryptedConfigurationCount=0;requiresRuntimeTypeConfigurationCount=0;likelyServerDependentConfigurationCount=0;notConfigurationCount=0}
            canonical=[pscustomobject][ordered]@{canonicalizedObjectCount=$Rows.Count;canonicalConflictObjectCount=0;canonicalGroupCount=$Rows.Count;exactDuplicateGroupCount=0;platformVariantGroupCount=0;unresolvedCanonicalGroupCount=$Rows.Count}
            dispatch=[pscustomobject][ordered]@{dispatchEligibleObjectCount=$Rows.Count;assignedObjectCount=@($Rows|Where-Object dispatchStatus -CEQ Assigned).Count;retainedForDiagnosisObjectCount=@($Rows|Where-Object dispatchStatus -CEQ RetainedForDiagnosis).Count;configurationOnlyObjectCount=@($Rows|Where-Object dispatchStatus -CEQ ConfigurationOnly).Count;audioObjectCount=@($Rows|Where-Object familyLane -CEQ Audio).Count;environmentObjectCount=@($Rows|Where-Object familyLane -CEQ Environment).Count;actorObjectCount=@($Rows|Where-Object familyLane -CEQ Actor).Count;uiObjectCount=@($Rows|Where-Object familyLane -CEQ UI).Count;effectsObjectCount=@($Rows|Where-Object familyLane -CEQ Effects).Count}
        }
        failureAccounting=[pscustomobject][ordered]@{inputSubjectCount=0;acceptedInputSubjectCount=0;notEvaluatedInputSubjectCount=0;inputObservationCount=0;acceptedInputObservationCount=0;rejectedInputObservationCount=0;inputFailureCount=0;excludedInputSubjectCount=0;excludedInputCount=0;contractFailureRecordCount=0;fileDiscoveryConflictRecordCount=0;observationConflictRecordCount=0;configurationConflictRecordCount=0;canonicalConflictRecordCount=0;outputCandidateCount=5;projectedOutputCount=5;outputFailureCount=0;excludedOutputCount=0;issueCount=0;gateStatus='Passed'}
        decision=[pscustomobject][ordered]@{failureAttribution='None; C2 registry-derived gates passed.';nextAllowedAction='Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.'}
    }
    $artifacts.Add([pscustomobject][ordered]@{artifactId='LC-I05';bytes=ConvertTo-TestCanonicalJson $summary})
    [object[]]$artifacts.ToArray()
}
function New-C3DirectInputs([object[]]$ExecutionArtifacts) {
    $rows=[Collections.Generic.List[object]]::new()
    foreach($artifact in $ExecutionArtifacts){
        $rows.Add([pscustomobject][ordered]@{artifactId=[string]$artifact.artifactId;path=[string]$directInputPaths[[string]$artifact.artifactId];sha256=Get-TestSha256 ([string]$artifact.bytes)})
    }
    [object[]](Get-TestOrdinalRows $rows.ToArray() path)
}
function Invoke-TestGate(
    $Rows=$dispatchRows,
    $Facts=$facts,
    $LedgerRows=$ledgerObjects,
    $ConfigurationRows=$configurationCandidates,
    $LanePolicy=$policy,
    [string]$LaneBytes=$policyBytes,
    $Vocabulary=$vocabulary,
    [string]$VocabularyText=$vocabularyBytes,
    $ExecutionArtifacts=$null,
    $DirectInputs=$null
) {
    if($null-eq$ExecutionArtifacts){$ExecutionArtifacts=New-C3ExecutionArtifacts $Rows $Facts $LedgerRows $ConfigurationRows $LanePolicy $LaneBytes $Vocabulary $VocabularyText}
    if($null-eq$DirectInputs){$DirectInputs=New-C3DirectInputs $ExecutionArtifacts}
    $testStage=[pscustomobject][ordered]@{generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C3FamilyMembershipGate:1.0.0');directInputs=$DirectInputs}
    Invoke-C3FamilyMembershipGate -DispatchRows @($Rows) -TypedFactRows @($Facts) -LanePolicyRegistry $LanePolicy -LanePolicyBytes $LaneBytes -FamilyParentStatuses @($Vocabulary.familyParentStatus) -LedgerObjects $LedgerRows -ConfigurationCandidates $ConfigurationRows -ExecutionArtifacts $ExecutionArtifacts -Stage $testStage
}

function Run-Kernel($Rows,$Facts,$LedgerRows=$ledgerObjects,$ConfigurationRows=$configurationCandidates) {
    Invoke-C3FamilyMembershipKernel -DispatchRows $Rows -TypedFactRows $Facts -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $LedgerRows -ConfigurationCandidates $ConfigurationRows
}

$result = Run-Kernel @($dispatchRows) @($facts)
if ($result.status -cne 'Passed') { throw "C3-0 positive result failed: $($result.issues -join '; ')" }
if ($result.dispatchEligibleObjectCount -ne 7 -or $result.assignedFamilyMemberCount -ne 5 -or $result.retainedForDiagnosisObjectCount -ne 1 -or $result.configurationOnlyObjectCount -ne 1) { throw 'SP-30 partition conservation failed.' }
if ($result.memberRows.Count -ne 7 -or @($result.memberRows.assetObjectId | Sort-Object -Unique).Count -ne 7) { throw 'C3-0 direct-parent identity conservation failed.' }
if (@($result.memberRows | Where-Object parentStatus -ceq AssignedFamilyMember).Count -ne 5 -or @($result.memberRows | Where-Object parentStatus -ceq RetainedForDiagnosis).Count -ne 1 -or @($result.memberRows | Where-Object parentStatus -ceq ConfigurationOnly).Count -ne 1) { throw 'C3-0 parent status partition failed.' }
if ($result.families.Count -ne 5 -or ($result.families.memberCount | Measure-Object -Sum).Sum -ne 5) { throw 'C3-0 family member conservation failed.' }
if ($result.crossLaneReferences.Count -ne 2 -or @($result.crossLaneReferences|Where-Object referenceKind -CEQ Dependency).Count-ne1-or@($result.crossLaneReferences|Where-Object referenceKind -CEQ ConfigurationCoupling).Count-ne1) { throw "SP-31 reference-universe projection failed: count=$($result.crossLaneReferences.Count) kinds=$($result.crossLaneReferences.referenceKind -join ',') statuses=$($result.crossLaneReferences.resolutionStatus -join ',')." }
$dependencyReference=@($result.crossLaneReferences|Where-Object referenceKind -CEQ Dependency)[0]
if($dependencyReference.fromAssetObjectId-cne$objects.Actor-or$dependencyReference.toAssetObjectId-cne$objects.Environment-or$dependencyReference.resolutionStatus-cne'Resolved'){throw 'SP-31 LC-I01 dependency projection failed.'}
if (@($result.memberRows | Where-Object assetObjectId -cin @($objects.Actor,$objects.Environment) | Where-Object parentStatus -cne AssignedFamilyMember).Count) { throw 'Cross-lane reference changed direct membership.' }

$missingSupportFacts = @(Clone-Value $facts | Where-Object { -not ($_.assetObjectId -ceq $objects.Audio -and $_.factKind -ceq 'PlatformVariant') })
$missingSupportResult = Run-Kernel @($dispatchRows) $missingSupportFacts
if ($missingSupportResult.status -cne 'Passed' -or $missingSupportResult.assignedFamilyMemberCount -ne 4 -or $missingSupportResult.retainedForDiagnosisObjectCount -ne 2 -or @($missingSupportResult.memberRows | Where-Object assetObjectId -ceq $objects.Audio)[0].parentStatus -cne 'RetainedForDiagnosis') { throw 'LF-04 missing required support fact behavior failed.' }

$invalidZeroDependencyRows=Clone-Value $dispatchRows
$invalidAudio=@($invalidZeroDependencyRows|Where-Object assetObjectId -CEQ $objects.Audio)[0]
$invalidAudio.memberSelectorInputs=@($invalidAudio.memberSelectorInputs|Where-Object kind -CNE ToolObservation)
$invalidZeroDependencyResult=Run-Kernel $invalidZeroDependencyRows @($facts)
if($invalidZeroDependencyResult.status-cne'Passed'-or@($invalidZeroDependencyResult.memberRows|Where-Object assetObjectId -CEQ $objects.Audio)[0].parentStatus-cne'RetainedForDiagnosis'){throw 'LF-04 authoritative known-empty dependency selector behavior failed.'}

$notApplicableSupportFacts=Clone-Value $facts
$notApplicablePlatform=@($notApplicableSupportFacts|Where-Object{$_.assetObjectId-ceq$objects.UI-and$_.factKind-ceq'PlatformVariant'})[0]
$notApplicablePlatform.factStatus='NotApplicable';$notApplicablePlatform.stringValue=$null
$notApplicableSupportResult=Run-Kernel @($dispatchRows) $notApplicableSupportFacts
if(@($notApplicableSupportResult.memberRows|Where-Object assetObjectId -CEQ $objects.UI)[0].parentStatus-cne'RetainedForDiagnosis'){throw 'LF-04 support fact NotApplicable behavior failed.'}

$couplingFacts=Clone-Value $facts
foreach($change in @(
    @($objects.Effects,'AudioDependencyIds',@($objects.Audio)),
    @($objects.Environment,'ShaderFamilyIds',@("shader-family-sha256:$('7'*64)")),
    @($objects.UI,'FontDependencyIds',@($objects.Actor))
)){
    $fact=@($couplingFacts|Where-Object{$_.assetObjectId-ceq$change[0]-and$_.factKind-ceq$change[1]})[0]
    $fact.factStatus='Known';$fact.valueKind='IdSet';$fact.stringValue=$null;$fact.integerValue=$null;$fact.booleanValue=$null;$fact.idValues=[string[]]$change[2]
}
$atlasFact=@($couplingFacts|Where-Object{$_.assetObjectId-ceq$objects.UI-and$_.factKind-ceq'AtlasId'})[0]
$atlasFact.factStatus='Known';$atlasFact.valueKind='String';$atlasFact.stringValue="atlas-sha256:$('8'*64)";$atlasFact.idValues=@()
$couplingResult=Run-Kernel @($dispatchRows) $couplingFacts
$expectedKinds='AtlasFontCoupling,AudioCoupling,ConfigurationCoupling,Dependency,ShaderCoupling'
if($couplingResult.status-cne'Passed'-or$couplingResult.assignedFamilyMemberCount-ne5-or$couplingResult.crossLaneReferences.Count-ne6-or(@($couplingResult.crossLaneReferences.referenceKind|Sort-Object -Unique)-join',')-cne$expectedKinds-or@($couplingResult.crossLaneReferences|Where-Object resolutionStatus -CNE Resolved).Count){throw 'SP-31 typed coupling reference universe failed.'}

$conflictLedger=@(Clone-Value $ledgerObjects)+@((Clone-Value @($ledgerObjects|Where-Object assetObjectId -CEQ $objects.Environment)[0]))
$conflictResult=Run-Kernel @($dispatchRows) @($facts) $conflictLedger
if($conflictResult.status-cne'Passed'-or$conflictResult.crossLaneReferences.Count-ne2-or@($conflictResult.crossLaneReferences|Where-Object resolutionStatus -CEQ Conflict).Count-ne1){throw 'LF-06 uniquely attributable reference Conflict partition failed.'}
foreach($vector in @($result,$couplingResult,$conflictResult)){
    $resolved=@($vector.crossLaneReferences|Where-Object resolutionStatus -CEQ Resolved).Count;$missing=@($vector.crossLaneReferences|Where-Object resolutionStatus -CEQ Missing).Count;$conflict=@($vector.crossLaneReferences|Where-Object resolutionStatus -CEQ Conflict).Count
    if($vector.crossLaneReferences.Count-ne$resolved+$missing+$conflict){throw 'SP-31 reference partition conservation failed.'}
}

$unknownFacts = @(Clone-Value $facts)
$unknown = @($unknownFacts | Where-Object { $_.assetObjectId -ceq $objects.Actor -and $_.factKind -ceq 'SkeletonId' })[0]
$unknown.factStatus = 'Unknown'; $unknown.valueKind = 'String'; $unknown.stringValue = $null
$unknownResult = Run-Kernel @($dispatchRows) $unknownFacts
if ($unknownResult.status -cne 'Passed' -or $unknownResult.assignedFamilyMemberCount -ne 4 -or $unknownResult.retainedForDiagnosisObjectCount -ne 2 -or @($unknownResult.memberRows | Where-Object assetObjectId -ceq $objects.Actor)[0].parentStatus -cne 'RetainedForDiagnosis') { throw 'LF-04 Unknown family key behavior failed.' }

$duplicateRows = @(Clone-Value $dispatchRows) + @((Clone-Value $dispatchRows[0]))
$duplicateResult = Run-Kernel $duplicateRows @($facts)
if ($duplicateResult.status -cne 'Failed' -or $duplicateResult.issues -cnotcontains 'Duplicate dispatch assetObjectId.') { throw 'LF-05 duplicate dispatch fail-closed behavior failed.' }

$unboundPolicy=Clone-Value $policy;$unboundPolicy.policySetVersion='9.9.9'
$unboundResult=Invoke-C3FamilyMembershipKernel -DispatchRows @($dispatchRows) -TypedFactRows @($facts) -LanePolicyRegistry $unboundPolicy -LanePolicyBytes $policyBytes -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -ConfigurationCandidates $configurationCandidates
if($unboundResult.status-cne'Failed'-or$unboundResult.issues-cnotcontains'LC-I07 execution object does not match accepted bytes.'){throw 'C3 LC-I07 object/bytes binding RED failed.'}

$repeat = Run-Kernel @($dispatchRows) @($facts)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C3-0 determinism failed.' }

$executionArtifacts=New-C3ExecutionArtifacts
$directInputs=New-C3DirectInputs $executionArtifacts
$stage = [pscustomobject][ordered]@{generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C3FamilyMembershipGate:1.0.0');directInputs=$directInputs}
try{$gate = Invoke-C3FamilyMembershipGate -DispatchRows @($dispatchRows) -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -ConfigurationCandidates $configurationCandidates -ExecutionArtifacts $executionArtifacts -Stage $stage}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}
if ($gate.gateStatus -cne 'Passed' -or (@($gate.PSObject.Properties.Name)-join',') -cne 'gateStatus,familyRegistry,familyMemberLedger,crossLaneReferencePackage,summary,report,texts') { throw 'C3-1 Passed result vector shape failed.' }
if ($gate.summary.failureAccounting.outputCandidateCount -ne 4 -or $gate.summary.failureAccounting.projectedOutputCount -ne 4 -or $gate.summary.failureAccounting.outputFailureCount -ne 0 -or $gate.summary.directOutputs.Count -ne 4) { throw 'C3-1 Passed output conservation failed.' }
if ((@($gate.familyRegistry.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,families' -or (@($gate.familyMemberLedger.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,rows' -or (@($gate.crossLaneReferencePackage.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,rows') { throw 'C3-1 success artifact top-level shape failed.' }
if ((@($gate.summary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision') { throw 'C3-1 summary top-level shape failed.' }
if ($gate.familyRegistry.families.Count -ne 5 -or $gate.familyMemberLedger.rows.Count -ne 7 -or $gate.crossLaneReferencePackage.rows.Count -ne 2) { throw 'C3-1 success artifact counts failed.' }
if($gate.summary.inputFingerprint-cne(Get-TestStageInputFingerprint $directInputs)-or$gate.summary.coverage.dispatchEligibleObjectBytes-ne2800-or$gate.summary.coverage.assignedFamilyMemberBytes-ne1500-or$gate.summary.coverage.referenceCount-ne2-or$gate.summary.coverage.resolvedReferenceCount-ne2){throw'C3-1 artifactId-bound fingerprint/byte/reference coverage failed.'}
$familyShape='familyId,lane,familyKindId,policyId,policyVersion,familyKeyFingerprint,familyKey,memberCount,memberBytes,memberObjectIds,crossLaneReferenceIds,riskDimensionIds,evidence';$keyShape='dimensionId,factStatus,valueKind,stringValue,integerValue,booleanValue,idValues';foreach($family in $gate.familyRegistry.families){if((@($family.PSObject.Properties.Name)-join',')-cne$familyShape){throw'C3-O01 family row shape failed.'};foreach($key in $family.familyKey){if((@($key.PSObject.Properties.Name)-join',')-cne$keyShape){throw'C3-O01 family key shape failed.'}}}
$memberShape='memberRecordId,assetObjectId,canonicalAssetId,lane,parentStatus,familyId,familyKindId,serializedSizeBytes,configurationCandidateId,dependencyObjectIds,crossLaneReferenceIds,policyId,policyVersion,evidence';foreach($member in $gate.familyMemberLedger.rows){if((@($member.PSObject.Properties.Name)-join',')-cne$memberShape){throw'C3-O02 member row shape failed.'}}
$referenceShape='referenceId,fromAssetObjectId,toAssetObjectId,fromLane,toLane,referenceKind,resolutionStatus,evidence';foreach($reference in $gate.crossLaneReferencePackage.rows){if((@($reference.PSObject.Properties.Name)-join',')-cne$referenceShape){throw'C3-O03 reference row shape failed.'}}
$accountingShape='inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,notEvaluatedInputSubjectCount,outputCandidateCount,projectedOutputCount,outputFailureCount,issueCount,gateStatus,inputFailures,inputSuppressions,outputFailures';$coverageShape='dispatchEligibleObjectCount,dispatchEligibleObjectBytes,assignedFamilyMemberCount,assignedFamilyMemberBytes,retainedForDiagnosisObjectCount,retainedForDiagnosisObjectBytes,configurationOnlyObjectCount,configurationOnlyObjectBytes,familyCount,referenceCount,resolvedReferenceCount,missingReferenceCount,conflictReferenceCount';if((@($gate.summary.failureAccounting.PSObject.Properties.Name)-join',')-cne$accountingShape-or(@($gate.summary.coverage.PSObject.Properties.Name)-join',')-cne$coverageShape){throw'C3-O04 accounting/coverage shape failed.'}
function Assert-LC-I05Rejected($Summary,[string]$Label){
    $mutatedArtifacts=Clone-Value $executionArtifacts
    @($mutatedArtifacts|Where-Object artifactId -CEQ 'LC-I05')[0].bytes=ConvertTo-TestCanonicalJson $Summary
    $mutatedInputs=New-C3DirectInputs $mutatedArtifacts
    $rejected=Invoke-TestGate -ExecutionArtifacts $mutatedArtifacts -DirectInputs $mutatedInputs
    if($rejected.gateStatus-cne'Failed'-or$rejected.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C3:DirectInputs'-or$rejected.summary.failureAccounting.projectedOutputCount-ne1-or$rejected.summary.failureAccounting.outputFailureCount-ne3){throw "C3 LC-I05 $Label did not fail closed."}
}
$acceptedC2Summary=([string]@($executionArtifacts|Where-Object artifactId -CEQ 'LC-I05')[0].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
$simplifiedSummary=[pscustomobject][ordered]@{schemaVersion='2.0.0';stageId='C2';snapshotId='snapshot-pc-install-001';gateStatus='Passed';inputFingerprint=('1'*64);directOutputs=@()}
Assert-LC-I05Rejected $simplifiedSummary 'simplified shape'
$failedC2Summary=Clone-Value $acceptedC2Summary;$failedC2Summary.failureAccounting.gateStatus='Failed';$failedC2Summary.failureAccounting.projectedOutputCount=1;$failedC2Summary.failureAccounting.outputFailureCount=4;$failedC2Summary.failureAccounting.issueCount=1
Assert-LC-I05Rejected $failedC2Summary 'Failed generation'
$missingChildSummary=Clone-Value $acceptedC2Summary;$missingChildSummary.directEvidence.directChildSummaries=@($missingChildSummary.directEvidence.directChildSummaries|Select-Object -Skip 1)
Assert-LC-I05Rejected $missingChildSummary 'missing child'
$detachedChildSummary=Clone-Value $acceptedC2Summary;$detachedChildSummary.directEvidence.directChildSummaries[0].sha256=('0'*64)
Assert-LC-I05Rejected $detachedChildSummary 'detached child SHA'
$staleIdentitySummary=Clone-Value $acceptedC2Summary;$staleIdentitySummary.identity.discoveryInputFingerprint=('9'*64)
Assert-LC-I05Rejected $staleIdentitySummary 'stale identity'
$malformedSummary=Clone-Value $acceptedC2Summary;$malformedSummary.directEvidence.PSObject.Properties.Remove('directChildReports')
Assert-LC-I05Rejected $malformedSummary 'malformed directEvidence'
$fixturePayloads=[ordered]@{'valid-family-registry.json'=$gate.texts.familyRegistry;'valid-family-member-ledger.json'=$gate.texts.familyMemberLedger;'valid-cross-lane-reference-package.json'=$gate.texts.crossLaneReferencePackage;'valid-c3-summary.json'=$gate.texts.summary;'valid-c3-report.md'=$gate.report}
if($UpdateFixtures){$utf8=[Text.UTF8Encoding]::new($false);foreach($name in $fixturePayloads.Keys){[IO.File]::WriteAllText((Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"),$fixturePayloads[$name],$utf8)};'fixtures=Updated';return}
foreach ($entry in @(
    @('valid-family-registry.json','familyRegistry'),
    @('valid-family-member-ledger.json','familyMemberLedger'),
    @('valid-cross-lane-reference-package.json','crossLaneReferencePackage'),
    @('valid-c3-summary.json','summary'),
    @('valid-c3-report.md','report')
)) {
    $path=Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$($entry[0])"
    if (-not (Test-Path -LiteralPath $path)) { throw "C3-1 expected fixture missing: $($entry[0])" }
    $actual=if($entry[1]-ceq'report'){$gate.report}else{$gate.texts.($entry[1])}
    if ([IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false)) -cne $actual) { throw "C3-1 fixture bytes mismatch: $($entry[0])" }
}

$failedGate = Invoke-TestGate -Rows $duplicateRows
if ($failedGate.gateStatus -cne 'Failed' -or $null-ne$failedGate.familyRegistry -or $null-ne$failedGate.familyMemberLedger -or $null-ne$failedGate.crossLaneReferencePackage -or $failedGate.summary.failureAccounting.projectedOutputCount-ne1 -or $failedGate.summary.failureAccounting.outputFailureCount-ne3 -or $failedGate.summary.directOutputs.Count-ne1 -or $failedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-05:C3:MembershipConservation') { throw 'C3-1 Failed diagnostic-only vector failed.' }
$duplicateFacts=@(Clone-Value $facts)+@((Clone-Value $facts[0]));$typedFailure=Invoke-TestGate -Facts $duplicateFacts;if($typedFailure.gateStatus-cne'Failed'-or$typedFailure.summary.failureAccounting.inputFailures[0].attribution-cne'LF-02:LC-I06'-or$typedFailure.summary.failureAccounting.projectedOutputCount-ne1){throw'C3-1 LF-02 diagnostic-only vector failed.'}
$badPolicy=Clone-Value $policy;$badPolicy.policySetVersion='1.0.1';$badPolicyBytes=ConvertTo-TestJson $badPolicy;$policyFailure=Invoke-TestGate -LanePolicy $badPolicy -LaneBytes $badPolicyBytes;if($policyFailure.gateStatus-cne'Failed'-or$policyFailure.summary.failureAccounting.inputFailures[0].attribution-cne'LF-03:LC-I07'-or$policyFailure.summary.failureAccounting.projectedOutputCount-ne1){throw'C3-1 LF-03 diagnostic-only vector failed.'}
$missingLedger=Clone-Value $ledgerObjects;$actorLedger=@($missingLedger|Where-Object assetObjectId -CEQ $objects.Actor)[0];$actorLedger.dependencyObjectIds=@($actorLedger.dependencyObjectIds,"sha256:$('9'*64)")|Sort-Object -CaseSensitive;$missingGate=Invoke-TestGate -LedgerRows $missingLedger;if($missingGate.gateStatus-cne'Passed'-or$missingGate.crossLaneReferencePackage.rows.Count-ne3-or$missingGate.summary.coverage.missingReferenceCount-ne1-or@($missingGate.familyMemberLedger.rows|Where-Object parentStatus -CEQ AssignedFamilyMember).Count-ne5){throw'SP-31 Missing reference partition failed.'}
$wrongShaInputs=Clone-Value $directInputs;@($wrongShaInputs|Where-Object artifactId -CEQ 'LC-I01')[0].sha256=('0'*64)
$wrongShaGate=Invoke-TestGate -ExecutionArtifacts $executionArtifacts -DirectInputs $wrongShaInputs
if($wrongShaGate.gateStatus-cne'Failed'-or$wrongShaGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C3:DirectInputs'){throw'C3 exact-byte direct input SHA mismatch did not fail closed.'}
$unboundLedger=Clone-Value $ledgerObjects;@($unboundLedger|Where-Object assetObjectId -CEQ $objects.Audio)[0].serializedSizeBytes++
$unboundLedgerGate=Invoke-TestGate -LedgerRows $unboundLedger -ExecutionArtifacts $executionArtifacts -DirectInputs $directInputs
if($unboundLedgerGate.gateStatus-cne'Failed'-or$unboundLedgerGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C3:DirectInputs'){throw'C3 execution object/bytes mismatch did not fail closed.'}
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C3-0 touched C2 publication state.' }

'status=Passed'
'dispatchEligibleObjectCount=7'
'assignedFamilyMemberCount=5'
'retainedForDiagnosisObjectCount=1'
'configurationOnlyObjectCount=1'
'familyCount=5'
'crossLaneReferenceCount=2'
'passedOutputVector=4/4/0'
'failedOutputVector=4/1/3'
'publicationWriteCount=0'
