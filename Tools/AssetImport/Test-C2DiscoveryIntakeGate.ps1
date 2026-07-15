[CmdletBinding()]
param(
    [ValidateSet('Pure','GitAdapter','Integration','FailureState','ValidatorMutations','FileFixtureIntake','FilePartitions','ObjectObservationPartitions','ObjectMergeProjection','ConfigurationPartitions','CanonicalPartitions','DispatchPartitions','InputAccounting','OutputSerialization','PublicationTransaction')]
    [string]$Case = 'Pure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'C2DiscoveryIntakeGate.psm1'
$loadedModule = Import-Module $modulePath -Force -PassThru

if($Case -ceq 'PublicationTransaction'){
    $repositoryRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
    function Run-PublicationVector([string]$vector){$loadedModule.Invoke({param($root,$name)Test-C2PublicationTransactionVector -RepositoryRoot $root -Vector $name},@($repositoryRoot,$vector))[0]}
    $results=@{};foreach($vector in @('EmptyPassed','PriorReplacement','OrdinaryFailed','PrePreparedOrphan','CrashAfterBackup','CrashAfterInstall','BothJournalForms','CommittedCleanup','UnknownRecoveryBytes','LockContention','LockOpen','Stage05Write','JournalPreparedReplace','Backup02Move','Install04Move','Install07Move','Verify06Hash','Rollback01Restore','RecoveryAmbiguous')){$results[$vector]=Run-PublicationVector $vector;if(-not$results[$vector].sandboxRemoved){throw"publication sandbox leaked: $vector"}}
    $empty=$results.EmptyPassed;if($empty.status-cne'Committed'-or$empty.outputAccounting.projectedOutputCount-ne5-or$empty.outputAccounting.outputFailureCount-ne0-or@($empty.consumerStates|Where-Object present).Count-ne8-or@($empty.consumerStates|Where-Object{$_.sha256-cne$_.desiredSha256}).Count-ne0-or$empty.journalPresent-or$empty.nextJournalPresent-or$empty.transactionDirectoryCount-ne0-or-not$empty.lockFilePresent){throw'empty Passed publication vector failed.'}
    $replacement=$results.PriorReplacement;if($replacement.status-cne'Committed'-or@($replacement.consumerStates|Where-Object{$_.sha256-cne$_.desiredSha256-or$_.sha256-ceq$_.priorSha256}).Count-ne0-or$replacement.transactionDirectoryCount-ne0){throw'complete prior replacement vector failed.'}
    $ordinary=$results.OrdinaryFailed;if($ordinary.status-cne'Committed'-or$ordinary.outputAccounting.projectedOutputCount-ne1-or$ordinary.outputAccounting.outputFailureCount-ne4-or(@($ordinary.consumerStates.present)-join',')-cne'False,False,False,False,True,True,True,True'-or@($ordinary.consumerStates|Where-Object{$_.present-and$_.sha256-cne$_.desiredSha256}).Count){throw'ordinary Failed diagnostic publication vector failed.'}
    $orphan=$results.PrePreparedOrphan;if($orphan.status-cne'Committed'-or$orphan.transactionDirectoryCount-ne0-or@($orphan.consumerStates|Where-Object present).Count-ne8){throw'pre-Prepared stage-only orphan cleanup failed.'}
    foreach($vector in @('CrashAfterBackup','CrashAfterInstall','BothJournalForms')){$result=$results[$vector];if($result.status-cne'Committed'-or$result.recoveryPriorRestored-cne$true-or@($result.consumerStates|Where-Object{$_.sha256-cne$_.desiredSha256}).Count-ne0-or$result.journalPresent-or$result.nextJournalPresent-or$result.transactionDirectoryCount-ne0){throw"crash recovery vector failed: $vector"}}
    $committed=$results.CommittedCleanup;if($committed.status-cne'Committed'-or$committed.committedCleanupRecovered-cne$true-or@($committed.consumerStates|Where-Object{$_.sha256-cne$_.desiredSha256}).Count-ne0-or$committed.journalPresent-or$committed.nextJournalPresent-or$committed.transactionDirectoryCount-ne0){throw'Committed cleanup recovery failed.'}
    foreach($vector in @('LockContention','LockOpen','Stage05Write','JournalPreparedReplace')){$result=$results[$vector];if($result.status-cne'Failed'-or$result.outputAccounting.projectedOutputCount-ne0-or$result.outputAccounting.outputFailureCount-ne5-or$result.outputFailureCount-ne5-or@($result.consumerStates|Where-Object{(-not$_.present)-or$_.sha256-cne$_.priorSha256}).Count-ne0-or$result.journalPresent-or$result.nextJournalPresent-or$result.transactionDirectoryCount-ne0){throw"early FT-12 vector failed: $vector"}}
    foreach($vector in @('Backup02Move','Install04Move','Install07Move','Verify06Hash')){$result=$results[$vector];if($result.status-cne'Failed'-or$result.outputAccounting.projectedOutputCount-ne0-or$result.outputAccounting.outputFailureCount-ne5-or@($result.consumerStates|Where-Object{(-not$_.present)-or$_.sha256-cne$_.priorSha256}).Count-ne0-or$result.journalPresent-or$result.nextJournalPresent-or$result.transactionDirectoryCount-ne0-or$result.quarantined){throw"rollback restoration vector failed: $vector"}}
    foreach($vector in @('Rollback01Restore','RecoveryAmbiguous','UnknownRecoveryBytes')){$result=$results[$vector];if($result.status-cne'Failed'-or-not$result.quarantined-or@($result.consumerStates|Where-Object present).Count-ne0-or$result.journalPresent-or$result.nextJournalPresent-or$result.transactionDirectoryCount-ne1){throw"quarantine vector failed: $vector"}}
    $journal=$results.Rollback01Restore;if($journal.quarantineJournalPhase-cne'Quarantined'-or$journal.journalTopShape-cne'schemaVersion,transactionId,phase,gateStatus,generatedAt,expectedPaths,entries'-or$journal.journalEntryShape-cne'artifactId,path,desiredState,stagedSha256,priorState,priorSha256,backupRelativePath,installState'-or$journal.journalExpectedPaths-cne'Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-report.md,Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json,Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json'){throw'journal exact shape/order failed.'}
    'status=Passed';'emptyPassed=5/5/0/0';'ordinaryFailed=5/1/4/0';'ft12=5/0/5/0';'faultPointCount=9';'recoveryVectorCount=7';'sandboxLeakCount=0';return
}

if($Case -ceq 'OutputSerialization'){
    function Invoke-Output($value){$loadedModule.Invoke({param($x)try{Invoke-C2OutputSerialization $x}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}},@($value))[0]}
    function Clone-OutputInput($value){$value|ConvertTo-Json -Depth 50|ConvertFrom-Json -Depth 50 -DateKind String}
    $generatedAt='2026-07-15T00:00:00Z';$snapshotId='snapshot-pc-install-001';$inputFingerprint=('a'*64-join'');$ledgerFingerprint=('d'*64-join'');$discoveryFingerprint='f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab'
    $objectId='sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11';$canonicalId='canonical-sha256:1111111111111111111111111111111111111111111111111111111111111111';$observationId='observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180'
    $toolVersions=@([pscustomobject][ordered]@{toolName='ToolA';version='1.0.0'})
    $status=[pscustomobject][ordered]@{corpus='Cataloged';extraction='ExtractedReadable';semantics='Known';unity='NotTested';disposition='RetainForLater'}
    $sources=@([pscustomobject][ordered]@{sourceId='pc-install-primary';sourceKind='PcInstall';capturedAt=$generatedAt;rootFingerprint=('c'*64-join'')})
    $files=@([pscustomobject][ordered]@{snapshotId=$snapshotId;sourceId='pc-install-primary';sourceKind='PcInstall';relativePath='SourceCorpus/PcInstall/game-data.bundle';containerKind='Bundle';sizeBytes=100;sha256=('2'*64-join'');capturedAt=$generatedAt;parseStatus='Parsed';disposition='RetainForLater';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json');status=$status})
    $objects=@([pscustomobject][ordered]@{assetObjectId=$objectId;sourceId='pc-install-primary';objectType='Sprite';objectName='Hero';containerRelativePath='SourceCorpus/PcInstall/game-data.bundle';classId=1;serializedSizeBytes=100;dependencyObjectIds=@();toolObservations=@([pscustomobject][ordered]@{toolName='ToolA';observation="version=1.0.0;observationId=$observationId;resolution=SingleTool"});platformVariant='Pc';configurationDisposition='NotConfiguration';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json');status=$status})
    $canonicalGroups=@([pscustomobject][ordered]@{canonicalAssetId=$canonicalId;memberObjectIds=@($objectId);matchStatus='Unresolved';platformScope='PcOnly';equivalenceFingerprint=$null;variantEvidence=@()})
    $dispatchRows=@([pscustomobject][ordered]@{assetObjectId=$objectId;canonicalAssetId=$canonicalId;sourceId='pc-install-primary';familyLane='UI';memberSelectorInputs=@([pscustomobject][ordered]@{kind='ObjectType';value='Sprite'});configurationCandidateId=$null;dispatchStatus='Assigned';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json')})
    $coverage=[pscustomobject][ordered]@{
        files=[pscustomobject][ordered]@{catalogedFileCount=1;catalogedBytes=100;catalogedContainerCount=1;catalogedContainerBytes=100;nonContainerFileCount=0;nonContainerFileBytes=0;fileDiscoverySubjectCount=1;fileDiscoverySubjectBytes=100;notAttemptedFileCount=0;notAttemptedFileBytes=0;parsedFileCount=1;parsedFileBytes=100;opaqueFileCount=0;opaqueFileBytes=0;failedFileCount=0;failedFileBytes=0;fileDiscoveryConflictFileCount=0;fileDiscoveryConflictFileBytes=0}
        containers=[pscustomobject][ordered]@{notAttemptedContainerCount=0;notAttemptedContainerBytes=0;parsedContainerCount=1;parsedContainerBytes=100;opaqueContainerCount=0;opaqueContainerBytes=0;failedContainerCount=0;failedContainerBytes=0;fileDiscoveryConflictContainerCount=0;fileDiscoveryConflictContainerBytes=0}
        objects=[pscustomobject][ordered]@{objectObservationRowCount=1;acceptedObjectObservationRowCount=1;rejectedObjectObservationRowCount=0;excludedObjectObservationRowCount=0;correlationGroupCount=1;enumeratedObjectCount=1;observationConflictObjectCount=0;classifiedObjectCount=1;unclassifiedObjectCount=0;unresolvedDependencyCount=0}
        configuration=[pscustomobject][ordered]@{configurationDiscoverySubjectCount=0;configurationCandidateCount=0;configurationConflictCount=0;parsedConfigurationCount=0;discoveredOpaqueConfigurationCount=0;encryptedConfigurationCount=0;requiresRuntimeTypeConfigurationCount=0;likelyServerDependentConfigurationCount=0;notConfigurationCount=1}
        canonical=[pscustomobject][ordered]@{canonicalizedObjectCount=1;canonicalConflictObjectCount=0;canonicalGroupCount=1;exactDuplicateGroupCount=0;platformVariantGroupCount=0;unresolvedCanonicalGroupCount=1}
        dispatch=[pscustomobject][ordered]@{dispatchEligibleObjectCount=1;assignedObjectCount=1;retainedForDiagnosisObjectCount=0;configurationOnlyObjectCount=0;audioObjectCount=0;environmentObjectCount=0;actorObjectCount=0;uiObjectCount=1;effectsObjectCount=0}
    }
    $missingProjectionFields=@(
        'structuredObjectCoverage.catalogedContainerCount','structuredObjectCoverage.catalogedContainerBytes','structuredObjectCoverage.nonContainerFileCount','structuredObjectCoverage.nonContainerFileBytes','structuredObjectCoverage.fileDiscoverySubjectCount','structuredObjectCoverage.fileDiscoverySubjectBytes','structuredObjectCoverage.notAttemptedFileCount','structuredObjectCoverage.notAttemptedFileBytes','structuredObjectCoverage.parsedFileCount','structuredObjectCoverage.parsedFileBytes','structuredObjectCoverage.opaqueFileCount','structuredObjectCoverage.opaqueFileBytes','structuredObjectCoverage.failedFileCount','structuredObjectCoverage.failedFileBytes','structuredObjectCoverage.fileDiscoveryConflictFileCount','structuredObjectCoverage.fileDiscoveryConflictFileBytes',
        'structuredObjectCoverage.notAttemptedContainerCount','structuredObjectCoverage.notAttemptedContainerBytes','structuredObjectCoverage.opaqueContainerCount','structuredObjectCoverage.opaqueContainerBytes','structuredObjectCoverage.failedContainerCount','structuredObjectCoverage.failedContainerBytes','structuredObjectCoverage.fileDiscoveryConflictContainerCount','structuredObjectCoverage.fileDiscoveryConflictContainerBytes','structuredObjectCoverage.objectObservationRowCount','structuredObjectCoverage.acceptedObjectObservationRowCount','structuredObjectCoverage.rejectedObjectObservationRowCount','structuredObjectCoverage.excludedObjectObservationRowCount','structuredObjectCoverage.correlationGroupCount','structuredObjectCoverage.observationConflictObjectCount','structuredObjectCoverage.unresolvedDependencyCount',
        'structuredObjectCoverage.configurationConflictCount','structuredObjectCoverage.discoveredOpaqueConfigurationCount','structuredObjectCoverage.encryptedConfigurationCount','structuredObjectCoverage.requiresRuntimeTypeConfigurationCount','structuredObjectCoverage.likelyServerDependentConfigurationCount','structuredObjectCoverage.notConfigurationCount','structuredObjectCoverage.canonicalizedObjectCount','structuredObjectCoverage.canonicalGroupCount','structuredObjectCoverage.canonicalConflictObjectCount','structuredObjectCoverage.exactDuplicateGroupCount','structuredObjectCoverage.platformVariantGroupCount','structuredObjectCoverage.unresolvedCanonicalGroupCount','structuredObjectCoverage.dispatchEligibleObjectCount','structuredObjectCoverage.assignedObjectCount','structuredObjectCoverage.retainedForDiagnosisObjectCount','structuredObjectCoverage.configurationOnlyObjectCount','structuredObjectCoverage.audioObjectCount','structuredObjectCoverage.environmentObjectCount','structuredObjectCoverage.actorObjectCount','structuredObjectCoverage.uiObjectCount','structuredObjectCoverage.effectsObjectCount','identity.discoveryInputFingerprint','identity.discoveryArtifactFingerprint','failureAccounting'
    )
    $discoveryInputs=@(
        [pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json';sha256=('1'*64-join'')},
        [pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json';sha256=('1'*64-join'')},
        [pscustomobject][ordered]@{path='docs/asset-migration/schemas/root-gate-summary.schema.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='docs/asset-migration/schemas/source-corpus-ledger.schema.json';sha256=('1'*64-join'')},[pscustomobject][ordered]@{path='docs/asset-migration/schemas/status-vocabulary.json';sha256=('1'*64-join'')}
    )
    function New-Contract($fingerprint){[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$generatedAt;requestId='C0ContractChange:C2StructuredCoverage:1.0.0';reason='Current root-gate-summary schema cannot losslessly represent mandatory C2 structured coverage partitions.';nextAllowedAction='Continue C3-C6 Phase A; C0 must resolve this request before G5 can pass.';inputFingerprint=$inputFingerprint;discoveryInputFingerprint=$fingerprint;status='Required';missingProjectionFields=$missingProjectionFields;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json','docs/asset-migration/schemas/root-gate-summary.schema.json')}}
    $passedAccounting=[pscustomobject][ordered]@{inputSubjectCount=21;acceptedInputSubjectCount=21;notEvaluatedInputSubjectCount=0;inputObservationCount=6;acceptedInputObservationCount=6;rejectedInputObservationCount=0;inputFailureCount=0;excludedInputSubjectCount=0;excludedInputCount=0;contractFailureRecordCount=0;fileDiscoveryConflictRecordCount=0;observationConflictRecordCount=0;configurationConflictRecordCount=0;canonicalConflictRecordCount=0;issueCount=0;gateStatus='Passed'}
    $passedDecision=[pscustomobject][ordered]@{failureAttribution='None; C2 registry-derived gates passed.';nextAllowedAction='Provide C2 outputs to C3-C6 Phase A; C0/G5 remains blocked by AR-S12.'}
    $base=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$generatedAt;snapshotId=$snapshotId;inputFingerprint=$inputFingerprint;ledgerInputFingerprint=$ledgerFingerprint;discoveryInputFingerprint=$discoveryFingerprint;gateStatus='Passed';toolVersions=$toolVersions;sources=$sources;files=$files;objects=$objects;configurationCandidates=@();configurationConflicts=@();canonicalGroups=$canonicalGroups;canonicalConflicts=@();sourceLedgerPath='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json';dispatchRows=$dispatchRows;resolvedFileResults=@();mergedObjectCandidates=@();canonicalProposalProvenance=@();dispatchInputFacts=@();fileDiscoveryConflicts=@();observationConflicts=@();inputFailures=@();inputExclusions=@();inputSuppressions=@();discoveryInputs=$discoveryInputs;coverage=$coverage;failureAccounting=$passedAccounting;decision=$passedDecision;contractChangeRequest=(New-Contract $discoveryFingerprint)}
    $passed=Invoke-Output $base
    if($passed.outputAccounting.outputCandidateCount-ne5-or$passed.outputAccounting.projectedOutputCount-ne5-or$passed.outputAccounting.outputFailureCount-ne0-or$passed.outputAccounting.excludedOutputCount-ne0){throw'Passed SP-09 conservation failed.'}
    if(($passed.artifacts.desiredState-join',')-cne'Present,Present,Present,Present,Present,Present,Present,Present'-or($passed.artifacts.index-join',')-cne'0,1,2,3,4,5,6,7'){throw'Passed desired state/order failed.'}
    if($passed.transactionId-cne'publication-sha256:5a882381d1c8d0577e2c385f707e495b5bb07123daca5ed12c32b147a6c01cf2'){throw"Passed HI-16 mismatch: $($passed.transactionId)"}
    if($passed.discoveryArtifactFingerprint-cne'0959abd47c89bf7c7a13ff980fcc38fc183c700bc1faec928bb54ccfbdc5f0f1'-or$passed.diagnosticBundleFingerprint-cne'a33aaf89c83b8156f06c560e5f9806ffd945a0e33a5593b7516720239b0fbcf1'){throw "Passed HI-13c/HI-14 literal mismatch: $($passed.discoveryArtifactFingerprint),$($passed.diagnosticBundleFingerprint)"}
    if(($passed.artifacts.sha256-join',')-cne'e2f3cb01cd005a7f046d4cdd61a6df873d3406e0d40f0695792d71d04f9f0441,f7a1df2e1123315aa2d028e6c834378c35bacaa54940995eed44581f299a1f41,a2158b021996031dcb5569fb7c19715c545c5ae1eceb92eed41f9b6cad65c576,3af8afe7ad4a2644ec84356b713a523e733be076f6d3b68067c34cb2f1c67e23,491ff027abd238a7a8ff53af635c6794a5bcb4d3dd54de3eabf57a996c0d2b2b,29fdc5f42906ab14a7a3af2c836f4667c56bb5c425e904665c087c33bee80f93,a54aac3f13e0058ac63826a48535859e59d7e7cccac9d32d9e8bff85b721a03f,5c4ad958a2fcd09c367467ebf0cc442a68991275794a71f39ab2d8ac7c92cec6'){throw "Passed CT-15 literal SHA set mismatch: $($passed.artifacts.sha256-join',')"}
    $r5='raw-row-sha256:f1343fa48a1a370cf061818de05aa529ae846cebfb5b92360a29c2f0cd4280d6';$conflict='observation-conflict-sha256:a008931eff217b62b8d15ee99a06b095c4a68cfa01231abf0c0f2025d209a82d'
    $failedInput=Clone-OutputInput $base;$failedInput.discoveryInputFingerprint=$null;$failedInput.gateStatus='Failed';$failedInput.inputFailures=@([pscustomobject][ordered]@{recordId='accounting-sha256:bb230135c98c6a67dbddad28cda99d0280161a4e5db2f0e3e0e197928e3d52b6';subjectKind='ObjectObservation';subjectId=$r5;reasonCode='InvalidObservation';attribution="FT-05:$r5";evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')},[pscustomobject][ordered]@{recordId='accounting-sha256:fc9d5f9fceb8366a2f09580834f7d450246d015095706c97524cdc0adffe213b';subjectKind='ObservationConflict';subjectId=$conflict;reasonCode='ConflictDetected';attribution="FT-07:$conflict";evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json','Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json')});$failedInput.observationConflicts=@([pscustomobject][ordered]@{observationConflictId=$conflict;correlationId='correlation-sha256:1111111111111111111111111111111111111111111111111111111111111111';observationIds=@($observationId);objectIds=@($objectId);conflictingFields=@('contentFingerprint');failureClass='MaterialConflict';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json','Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json')});$failedInput.failureAccounting=[pscustomobject][ordered]@{inputSubjectCount=24;acceptedInputSubjectCount=21;notEvaluatedInputSubjectCount=0;inputObservationCount=8;acceptedInputObservationCount=6;rejectedInputObservationCount=1;inputFailureCount=2;excludedInputSubjectCount=1;excludedInputCount=1;contractFailureRecordCount=0;fileDiscoveryConflictRecordCount=0;observationConflictRecordCount=1;configurationConflictRecordCount=0;canonicalConflictRecordCount=0;issueCount=2;gateStatus='Failed'};$failedInput.decision=[pscustomobject][ordered]@{failureAttribution="FT-05:$r5;FT-07:$conflict";nextAllowedAction='Correct invalid observation rows and resolve observation conflicts.'};$failedInput.contractChangeRequest=New-Contract $null
    $failed=Invoke-Output $failedInput
    if($failed.outputAccounting.outputCandidateCount-ne5-or$failed.outputAccounting.projectedOutputCount-ne1-or$failed.outputAccounting.outputFailureCount-ne4-or$failed.outputAccounting.excludedOutputCount-ne0){throw'Failed SP-09 conservation failed.'}
    if(($failed.artifacts.desiredState-join',')-cne'Absent,Absent,Absent,Absent,Present,Present,Present,Present'){throw'Failed desired state failed.'}
    if(($failed.outputFailures.recordId-join',')-cne'accounting-sha256:9f1138f02085b330db3fb53ec2e65e548c4cdb92b3127eddeab4122121217be3,accounting-sha256:546edc1d608856e62a1a0b99b5f580c06ef330e20708c52d5ce3bf9419878eda,accounting-sha256:b569af8a77bbd095f11d564f181afc34d3f67d2e0f5f703d59ed583570282df4,accounting-sha256:d1576932c592de68a24745fe2c6539d461398b1df33e31b7be68577d92835a65'){throw"SuppressedByGate identities failed: $($failed.outputFailures.recordId-join',')"}
    if($failed.transactionId-cne'publication-sha256:900e21ceb48919fd34e0e6fc16cb68f7f66206280a4e2664b67a64a335cf9c8b'){throw"Failed HI-16 mismatch: $($failed.transactionId)"}
    if($failed.discoveryArtifactFingerprint-cne'bea0b2989bd65556f653bd9982ad51e1abf27ba48c8c37f62543646e96d0612b'-or$failed.diagnosticBundleFingerprint-cne'8a8f9220832eaf7f38452e1f3e6415f5406cdc56c97f4a86dda628512d103a66'){throw "Failed HI-13c/HI-14 literal mismatch: $($failed.discoveryArtifactFingerprint),$($failed.diagnosticBundleFingerprint)"}
    if(($failed.artifacts.sha256-join',')-cne',,,,8e2d107230493b00207fbe15d9b7d3c20e6b8c1866729ba37469f3457f6c6a59,946ee75054fe711a55f15920ff03283730809a5d3b11c2d0db363f6b5b22bbb8,8d75b7de2d8af4cb5663789f7013c099e40b1cde1a732e7270b94947ebeec0e0,46a79a3f963d232e1429af7c8ef005aaa79aebcac20c82568fa9a2b3388fe19e'){throw "Failed CT-15 literal SHA set mismatch: $($failed.artifacts.sha256-join',')"}
    if($failed.artifacts[4].text-cnotmatch'(?m)^discoveryInputFingerprint: null$'){throw'Failed report null projection failed.'}
    $passedReport="# C2 Discovery Gate Report`nschemaVersion: 1.0.0`ngeneratedAt: 2026-07-15T00:00:00Z`nsnapshotId: snapshot-pc-install-001`noperationIdentity: C2DiscoveryIntakeGate`ninputFingerprint: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`nledgerInputFingerprint: dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd`ndiscoveryInputFingerprint: f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab`ngateStatus: Passed`ninputSubjectCount: 21`nnotEvaluatedInputSubjectCount: 0`ninputFailureCount: 0`noutputCandidateCount: 5`nprojectedOutputCount: 5`noutputFailureCount: 0`nissueCount: 0`nfailureAttribution: None; C2 registry-derived gates passed.`nnextAllowedAction: Provide C2 outputs to C3-C6 Phase A; C0/G5 remains blocked by AR-S12.`n"
    $failedReport="# C2 Discovery Gate Report`nschemaVersion: 1.0.0`ngeneratedAt: 2026-07-15T00:00:00Z`nsnapshotId: snapshot-pc-install-001`noperationIdentity: C2DiscoveryIntakeGate`ninputFingerprint: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa`nledgerInputFingerprint: dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd`ndiscoveryInputFingerprint: null`ngateStatus: Failed`ninputSubjectCount: 24`nnotEvaluatedInputSubjectCount: 0`ninputFailureCount: 2`noutputCandidateCount: 5`nprojectedOutputCount: 1`noutputFailureCount: 4`nissueCount: 2`nfailureAttribution: FT-05:raw-row-sha256:f1343fa48a1a370cf061818de05aa529ae846cebfb5b92360a29c2f0cd4280d6;FT-07:observation-conflict-sha256:a008931eff217b62b8d15ee99a06b095c4a68cfa01231abf0c0f2025d209a82d`nnextAllowedAction: Correct invalid observation rows and resolve observation conflicts.`n"
    if($passed.artifacts[4].text-cne$passedReport-or$failed.artifacts[4].text-cne$failedReport){throw'Exact report bytes mismatch.'}
    foreach($result in @($passed,$failed)){foreach($artifact in @($result.artifacts|Where-Object{$_.desiredState -ceq 'Present'})){if(-not$artifact.text.EndsWith("`n")-or$artifact.text.EndsWith("`n`n")-or$artifact.text.Contains("`r")-or$artifact.sha256-cnotmatch'^[0-9a-f]{64}$'){throw"CT-15 bytes failed: $($artifact.path)"}}}
    $expectedArtifactShape='artifactId,path,desiredState,text,sha256,index';if(@($passed.artifacts|Where-Object{(@($_.PSObject.Properties.Name)-join',')-cne$expectedArtifactShape}).Count){throw'Artifact exact shape failed.'}
    $passedJson=@{};foreach($index in @(0,1,2,3,5,6,7)){$passedJson[$index]=$passed.artifacts[$index].text|ConvertFrom-Json -Depth 50 -DateKind String};$failedJson=@{};foreach($index in @(5,6,7)){$failedJson[$index]=$failed.artifacts[$index].text|ConvertFrom-Json -Depth 50 -DateKind String}
    $topOrders=@{0='schemaVersion,snapshotId,generatedAt,inputFingerprint,toolVersions,sources,files,objects';1='schemaVersion,generatedAt,snapshotId,inputFingerprint,discoveryInputFingerprint,configurationCandidates,configurationConflicts';2='schemaVersion,generatedAt,snapshotId,inputFingerprint,discoveryInputFingerprint,canonicalGroups,canonicalConflicts';3='schemaVersion,generatedAt,snapshotId,inputFingerprint,discoveryInputFingerprint,sourceLedgerPath,rows';5='schemaVersion,generatedAt,snapshotId,inputFingerprint,discoveryInputFingerprint,resolvedFileResults,mergedObjectCandidates,canonicalProposalProvenance,dispatchInputFacts,fileDiscoveryConflicts,observationConflicts,configurationCandidates,configurationConflicts,canonicalGroups,canonicalConflicts,inputFailures,inputExclusions,inputSuppressions,outputFailures,outputExclusions';6='schemaVersion,generatedAt,requestId,reason,nextAllowedAction,inputFingerprint,discoveryInputFingerprint,status,missingProjectionFields,evidence';7='schemaVersion,identity,provenance,directEvidence,coverage,failureAccounting,decision'}
    foreach($index in $topOrders.Keys){if((@($passedJson[$index].PSObject.Properties.Name)-join',')-cne$topOrders[$index]){throw"Passed AR-S top shape mismatch index=$index"}};foreach($index in @(5,6,7)){if((@($failedJson[$index].PSObject.Properties.Name)-join',')-cne$topOrders[$index]){throw"Failed AR-S top shape mismatch index=$index"}}
    if((@($passedJson[7].identity.PSObject.Properties.Name)-join',')-cne'generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,discoveryInputFingerprint,discoveryArtifactFingerprint'-or(@($passedJson[7].provenance.PSObject.Properties.Name)-join',')-cne'toolVersions,operationIdentity'-or(@($passedJson[7].directEvidence.PSObject.Properties.Name)-join',')-cne'discoveryInputs,directChildSummaries,directChildReports'-or(@($passedJson[7].coverage.PSObject.Properties.Name)-join',')-cne'files,containers,objects,configuration,canonical,dispatch'-or(@($passedJson[7].failureAccounting.PSObject.Properties.Name)-join',')-cne'inputSubjectCount,acceptedInputSubjectCount,notEvaluatedInputSubjectCount,inputObservationCount,acceptedInputObservationCount,rejectedInputObservationCount,inputFailureCount,excludedInputSubjectCount,excludedInputCount,contractFailureRecordCount,fileDiscoveryConflictRecordCount,observationConflictRecordCount,configurationConflictRecordCount,canonicalConflictRecordCount,outputCandidateCount,projectedOutputCount,outputFailureCount,excludedOutputCount,issueCount,gateStatus'-or(@($passedJson[7].decision.PSObject.Properties.Name)-join',')-cne'failureAttribution,nextAllowedAction'){throw'AR-S11 nested exact shape failed.'}
    $expectedChildSummaries='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json';$expectedChildReports='Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json,Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-report.md'
    if(($passedJson[7].directEvidence.directChildSummaries.path-join',')-cne$expectedChildSummaries-or($passedJson[7].directEvidence.directChildReports.path-join',')-cne$expectedChildReports-or@($failedJson[7].directEvidence.directChildSummaries).Count-ne0-or($failedJson[7].directEvidence.directChildReports.path-join',')-cne$expectedChildReports){throw'AR-S11 direct child Ordinal sets failed.'}
    $badExtra=Clone-OutputInput $base;$badExtra|Add-Member unexpected $true;$threw=$false;try{Invoke-Output $badExtra}catch{$threw=$true};if(-not$threw){throw'extra input field did not fail closed.'}
    $badMissing=Clone-OutputInput $base;$badMissing.PSObject.Properties.Remove('coverage');$threw=$false;try{Invoke-Output $badMissing}catch{$threw=$true};if(-not$threw){throw'missing input field did not fail closed.'}
    $badOrder=Clone-OutputInput $base;$ordered=[ordered]@{};foreach($name in @($badOrder.PSObject.Properties.Name|Select-Object -Skip 1)){$ordered[$name]=$badOrder.$name};$ordered.schemaVersion=$badOrder.schemaVersion;$threw=$false;try{Invoke-Output ([pscustomobject]$ordered)}catch{$threw=$true};if(-not$threw){throw'reordered input field did not fail closed.'}
    $threw=$false;try{$loadedModule.Invoke({ConvertTo-C2CanonicalJson ([pscustomobject][ordered]@{bad=1.5})})}catch{$threw=$true};if(-not$threw){throw'invalid CT-15 scalar did not fail closed.'}
    $badNested=Clone-OutputInput $base;$badNested.sources[0]|Add-Member unexpected $true;$threw=$false;try{Invoke-Output $badNested}catch{$threw=$true};if(-not$threw){throw'extra nested output field did not fail closed.'}
    $badContract=Clone-OutputInput $base;$badContract.contractChangeRequest.PSObject.Properties.Remove('status');$threw=$false;try{Invoke-Output $badContract}catch{$threw=$true};if(-not$threw){throw'missing AR-S12 field did not fail closed.'}
    $diagnostic=@($failed.artifacts|Where-Object{$_.index -in (4..7)}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}});$duplicate=@($diagnostic)+@($diagnostic[0]);$threw=$false;try{$loadedModule.Invoke({param($x)Get-C2RegisteredArtifactFingerprint Diagnostic Failed $x},@($duplicate))}catch{$threw=$true};if(-not$threw){throw'duplicate output identity did not fail closed.'}
    $selfIncluded=@($failed.artifacts|Where-Object{$_.index -in (4..7)}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}});$threw=$false;try{$loadedModule.Invoke({param($x)Get-C2RegisteredArtifactFingerprint Discovery Failed $x},@($selfIncluded))}catch{$threw=$true};if(-not$threw){throw'summary self-inclusion did not fail closed.'}
    $wrongChildren=@($diagnostic|Select-Object -First 3);$threw=$false;try{$loadedModule.Invoke({param($x)Get-C2RegisteredArtifactFingerprint Diagnostic Failed $x},@($wrongChildren))}catch{$threw=$true};if(-not$threw){throw'wrong diagnostic child set did not fail closed.'}
    'status=Passed';"passedDiscoveryArtifactFingerprint=$($passed.discoveryArtifactFingerprint)";"passedDiagnosticBundleFingerprint=$($passed.diagnosticBundleFingerprint)";"failedDiscoveryArtifactFingerprint=$($failed.discoveryArtifactFingerprint)";"failedDiagnosticBundleFingerprint=$($failed.diagnosticBundleFingerprint)";"passedArtifactSha256=$($passed.artifacts.sha256-join',')";"failedArtifactSha256=$($failed.artifacts.sha256-join',')";return
}

if($Case -ceq 'InputAccounting'){
    $artifactStates=@('AR-I01','AR-I02','AR-I03','AR-I04','AR-I05','AR-I06','AR-I07','AR-I08','AR-I10','AR-I11')|ForEach-Object{[pscustomobject][ordered]@{artifactId=$_;readStatus='Accepted'}}
    $rawIds=@(
        'observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180',
        'observation-sha256:7a213fdda2a2eeecce2908215747a70211903ba19f2721984cf05375dfd8d98a',
        'observation-sha256:6d653ff6e6e7b582843a2b8084364f14f32db83c6cbbba67cca6e1b738f63e2e',
        'observation-sha256:546997444cbe327e4d9dd073c4dc067721557d559861b76a93262556209e8b77',
        'raw-row-sha256:f1343fa48a1a370cf061818de05aa529ae846cebfb5b92360a29c2f0cd4280d6',
        'observation-sha256:6ceeb8491c944325c2a038a56793b3fe062b41a694201e11b4f20302ea13c7e6',
        'file-discovery-observation-sha256:195be146f0f08df54c160fbccf1c790bc1fbd535b6626976e1981344031b3e80',
        'file-discovery-observation-sha256:19e7158715bf0dd0807da34dddfa744b9d205a3d3e1273ea5185f217b426b5c4'
    )
    $rawSubjects=[Collections.Generic.List[object]]::new();for($i=0;$i-lt6;$i++){$rawSubjects.Add([pscustomobject][ordered]@{subjectKind='ObjectObservation';subjectId=$rawIds[$i];partition=@('Accepted','Accepted','Accepted','Accepted','InputFailure','InputExclusion')[$i]})}
    $rawSubjects.Add([pscustomobject][ordered]@{subjectKind='FileDiscoveryObservation';subjectId=$rawIds[6];partition='Accepted'})
    $rawSubjects.Add([pscustomobject][ordered]@{subjectKind='FileDiscoveryObservation';subjectId=$rawIds[7];partition='Accepted'})
    $conflictId='observation-conflict-sha256:a008931eff217b62b8d15ee99a06b095c4a68cfa01231abf0c0f2025d209a82d'
    $conflicts=@([pscustomobject][ordered]@{subjectKind='ObservationConflict';subjectId=$conflictId})
    $failures=@(
        [pscustomobject][ordered]@{recordId='accounting-sha256:bb230135c98c6a67dbddad28cda99d0280161a4e5db2f0e3e0e197928e3d52b6';subjectKind='ObjectObservation';subjectId=$rawIds[4];reasonCode='InvalidObservation';attribution="FT-05:$($rawIds[4])";evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')},
        [pscustomobject][ordered]@{recordId='accounting-sha256:fc9d5f9fceb8366a2f09580834f7d450246d015095706c97524cdc0adffe213b';subjectKind='ObservationConflict';subjectId=$conflictId;reasonCode='ConflictDetected';attribution="FT-07:$conflictId";evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json','Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json')}
    )
    $exclusions=@([pscustomobject][ordered]@{recordId='accounting-sha256:c7d038334823aee236a7d9871671cef610453a73780b7b38176c19dca533c3d1';subjectKind='ObjectObservation';subjectId=$rawIds[5];reasonCode='ApprovedInputExclusion';attribution="FT-14:$($rawIds[5])";evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r6-exclusion-approval.md','Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json','Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')})
    $runtimeFacts=[pscustomobject][ordered]@{heavyProcessCount=0;realAssetReadCount=0;createdExtractedCount=0;createdImportedCount=0;astViolationCount=0;startCommitOid=('1'*40);endCommitOid=('1'*40);headStable=$true}
    $stageSets=@(
        [pscustomobject][ordered]@{stageId='SP-01';universeIds=@('f1');partitionIds=@('f1')},
        [pscustomobject][ordered]@{stageId='SP-02';universeIds=@('f1');partitionIds=@('f1')},
        [pscustomobject][ordered]@{stageId='SP-03';universeIds=@($rawIds);partitionIds=@($rawIds)},
        [pscustomobject][ordered]@{stageId='SP-04';universeIds=@('o1');partitionIds=@('o1')},
        [pscustomobject][ordered]@{stageId='SP-05';universeIds=@('c1');partitionIds=@('c1')},
        [pscustomobject][ordered]@{stageId='SP-06';universeIds=@('o1');partitionIds=@('o1')},
        [pscustomobject][ordered]@{stageId='SP-07';universeIds=@();partitionIds=@()}
    )
    $missingProjectionFields=@(
        'structuredObjectCoverage.catalogedContainerCount','structuredObjectCoverage.catalogedContainerBytes','structuredObjectCoverage.nonContainerFileCount','structuredObjectCoverage.nonContainerFileBytes','structuredObjectCoverage.fileDiscoverySubjectCount','structuredObjectCoverage.fileDiscoverySubjectBytes','structuredObjectCoverage.notAttemptedFileCount','structuredObjectCoverage.notAttemptedFileBytes','structuredObjectCoverage.parsedFileCount','structuredObjectCoverage.parsedFileBytes','structuredObjectCoverage.opaqueFileCount','structuredObjectCoverage.opaqueFileBytes','structuredObjectCoverage.failedFileCount','structuredObjectCoverage.failedFileBytes','structuredObjectCoverage.fileDiscoveryConflictFileCount','structuredObjectCoverage.fileDiscoveryConflictFileBytes',
        'structuredObjectCoverage.notAttemptedContainerCount','structuredObjectCoverage.notAttemptedContainerBytes','structuredObjectCoverage.opaqueContainerCount','structuredObjectCoverage.opaqueContainerBytes','structuredObjectCoverage.failedContainerCount','structuredObjectCoverage.failedContainerBytes','structuredObjectCoverage.fileDiscoveryConflictContainerCount','structuredObjectCoverage.fileDiscoveryConflictContainerBytes','structuredObjectCoverage.objectObservationRowCount','structuredObjectCoverage.acceptedObjectObservationRowCount','structuredObjectCoverage.rejectedObjectObservationRowCount','structuredObjectCoverage.excludedObjectObservationRowCount','structuredObjectCoverage.correlationGroupCount','structuredObjectCoverage.observationConflictObjectCount','structuredObjectCoverage.unresolvedDependencyCount',
        'structuredObjectCoverage.configurationConflictCount','structuredObjectCoverage.discoveredOpaqueConfigurationCount','structuredObjectCoverage.encryptedConfigurationCount','structuredObjectCoverage.requiresRuntimeTypeConfigurationCount','structuredObjectCoverage.likelyServerDependentConfigurationCount','structuredObjectCoverage.notConfigurationCount','structuredObjectCoverage.canonicalizedObjectCount','structuredObjectCoverage.canonicalGroupCount','structuredObjectCoverage.canonicalConflictObjectCount','structuredObjectCoverage.exactDuplicateGroupCount','structuredObjectCoverage.platformVariantGroupCount','structuredObjectCoverage.unresolvedCanonicalGroupCount','structuredObjectCoverage.dispatchEligibleObjectCount','structuredObjectCoverage.assignedObjectCount','structuredObjectCoverage.retainedForDiagnosisObjectCount','structuredObjectCoverage.configurationOnlyObjectCount','structuredObjectCoverage.audioObjectCount','structuredObjectCoverage.environmentObjectCount','structuredObjectCoverage.actorObjectCount','structuredObjectCoverage.uiObjectCount','structuredObjectCoverage.effectsObjectCount','identity.discoveryInputFingerprint','identity.discoveryArtifactFingerprint','failureAccounting'
    )
    $contractChange=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-15T00:00:00Z';requestId='C0ContractChange:C2StructuredCoverage:1.0.0';reason='Current root-gate-summary schema cannot losslessly represent mandatory C2 structured coverage partitions.';nextAllowedAction='Continue C3-C6 Phase A; C0 must resolve this request before G5 can pass.';inputFingerprint=('a'*64);discoveryInputFingerprint=('b'*64);status='Required';missingProjectionFields=$missingProjectionFields;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json','docs/asset-migration/schemas/root-gate-summary.schema.json')}
    $input=[pscustomobject][ordered]@{artifactStates=@($artifactStates);rawObservationSubjects=@($rawSubjects);conflictSubjects=@($conflicts);inputFailures=@($failures);inputExclusions=@($exclusions);runtimeFacts=$runtimeFacts;contractChangeRequest=$contractChange;stageConservationSets=@($stageSets);discoveryInputFingerprint=('b'*64)}
    $result=$loadedModule.Invoke({param($x)Invoke-C2InputAccounting $x},@($input))[0]
    $a=$result.failureAccounting
    if($a.inputSubjectCount-ne24-or$a.acceptedInputSubjectCount-ne21-or$a.inputFailureCount-ne2-or$a.excludedInputSubjectCount-ne1-or$a.notEvaluatedInputSubjectCount-ne0){throw 'SP-08 exact subject partition failed'}
    if($a.inputObservationCount-ne8-or$a.acceptedInputObservationCount-ne6-or$a.rejectedInputObservationCount-ne1-or$a.excludedInputCount-ne1){throw 'SP-08 observation conservation failed'}
    if($a.contractFailureRecordCount-ne0-or$a.fileDiscoveryConflictRecordCount-ne0-or$a.observationConflictRecordCount-ne1-or$a.configurationConflictRecordCount-ne0-or$a.canonicalConflictRecordCount-ne0){throw 'SP-08 failure conservation failed'}
    if(($result.contractChecks.status-join',')-cne'Accepted,Accepted,Accepted,Accepted,Accepted'){throw 'SP-08 five-check positive vector failed'}
    if(($result.contractChecks.subjectId-join',')-cne'C2Check:LightweightPolicy,C2Check:C1Handoff,C2Check:Freshness,C2Check:Conservation,C2Check:PublicProjection'){throw 'SP-08 five-check identity/order failed'}
    if((@($a.PSObject.Properties.Name)-join',')-cne'inputSubjectCount,acceptedInputSubjectCount,notEvaluatedInputSubjectCount,inputObservationCount,acceptedInputObservationCount,rejectedInputObservationCount,inputFailureCount,excludedInputSubjectCount,excludedInputCount,contractFailureRecordCount,fileDiscoveryConflictRecordCount,observationConflictRecordCount,configurationConflictRecordCount,canonicalConflictRecordCount,issueCount,gateStatus'){throw 'SP-08 failureAccounting exact shape failed'}
    foreach($row in @($result.contractChecks)){if((@($row.PSObject.Properties.Name)-join',')-cne'subjectId,status,attribution,evidence,prerequisites'){throw 'SP-08 check exact row shape failed'}}
    foreach($row in @($result.inputFailures)+@($result.inputExclusions)){if((@($row.PSObject.Properties.Name)-join',')-cne'recordId,subjectKind,subjectId,reasonCode,attribution,evidence'-or$row.recordId-cnotmatch'^accounting-sha256:[0-9a-f]{64}$'){throw 'SP-08 accounting exact row shape failed'}}
    if(($rawSubjects.subjectId-join',')-cne($rawIds-join',')){throw 'SP-08 exact raw subject identities failed'}
    foreach($row in $rawSubjects){if((@($row.PSObject.Properties.Name)-join',')-cne'subjectKind,subjectId,partition'){throw 'SP-08 exact raw subject row shape failed'}}
    if(@($rawSubjects|Where-Object subjectId -ceq $conflictId).Count-ne0){throw 'SP-08 duplicate conflict ownership failed'}
    if($null-ne$result.discoveryInputFingerprint){throw 'SP-08 negative integration fingerprint not suppressed'}
    function CloneAccounting($x){$x|ConvertTo-Json -Depth 40|ConvertFrom-Json -Depth 40 -DateKind String}
    function RunAccounting($x){$loadedModule.Invoke({param($v)Invoke-C2InputAccounting $v},@($x))[0]}
    $twoEquation=CloneAccounting $input;$twoEquation.stageConservationSets[0].partitionIds=@();$twoEquation.stageConservationSets[1].partitionIds=@('f1','f1');$ft10=RunAccounting $twoEquation
    $ft10row=@($ft10.inputFailures|Where-Object subjectId -ceq 'C2Check:Conservation');if($ft10row.Count-ne1-or$ft10row[0].recordId-cne'accounting-sha256:99b22592adff48c273bdc79844085fdd2052dc5bc18766d8a6d8249cb7967985'-or$ft10.failureAccounting.issueCount-ne3-or($ft10.contractChecks.status-join',')-cne'Accepted,Accepted,Accepted,Failed,NotEvaluated'-or@($ft10.inputSuppressions|Where-Object subjectId -ceq 'C2Check:PublicProjection').Count-ne1){throw 'FT-10 unique multi-equation ownership failed'}
    $clean=CloneAccounting $input;$clean.rawObservationSubjects=@($clean.rawObservationSubjects|Where-Object partition -ceq 'Accepted');$clean.conflictSubjects=@();$clean.inputFailures=@();$clean.inputExclusions=@();$clean.stageConservationSets[2].universeIds=@($clean.rawObservationSubjects.subjectId);$clean.stageConservationSets[2].partitionIds=@($clean.rawObservationSubjects.subjectId)
    $badProjection=CloneAccounting $clean;$badProjection.contractChangeRequest.status='NotRequired';$ft11=RunAccounting $badProjection
    if($ft11.inputFailures.Count-ne1-or$ft11.inputFailures[0].recordId-cne'accounting-sha256:2dd259cfa7c46d5dd0f49d28b41780214c6eea81274beaaee7457573a35d79b2'-or$ft11.inputFailures[0].attribution-cne'FT-11:C2Check:PublicProjection'-or($ft11.inputFailures[0].evidence-join',')-cne'Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json,docs/asset-migration/schemas/root-gate-summary.schema.json'-or($ft11.contractChecks.status-join',')-cne'Accepted,Accepted,Accepted,Accepted,Failed'-or$null-ne$ft11.discoveryInputFingerprint){throw 'FT-11 exact projection failure failed'}
    $freshnessUnavailable=CloneAccounting $clean;$i10=@($freshnessUnavailable.artifactStates|Where-Object artifactId -ceq 'AR-I10')[0];$i10.readStatus='Failed';$freshnessUnavailable.inputFailures=@([pscustomobject][ordered]@{recordId='accounting-sha256:c989486a5acfb0aca2daa0d30cd101e5fe444b5bc18b239042025d81c97c1d6c';subjectKind='ExpectedInputManifest';subjectId='AR-I10';reasonCode='InvalidSchema';attribution='FT-02:AR-I10';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json')});$ft15=RunAccounting $freshnessUnavailable
    if($ft15.inputFailures.Count-ne1-or$ft15.failureAccounting.issueCount-ne1-or$ft15.inputSuppressions.Count-ne1-or$ft15.inputSuppressions[0].recordId-cne'accounting-sha256:3b9db7f410d8f0d7e52f90d5cd7c4a1ea6b1c14710b014d97f5f8be2f97c662c'-or($ft15.contractChecks.status-join',')-cne'Accepted,Accepted,NotEvaluated,Accepted,Accepted'-or$ft15.failureAccounting.notEvaluatedInputSubjectCount-ne1){throw "FT-15 unique ownership/issue accounting failed failures=$($ft15.inputFailures.Count) issues=$($ft15.failureAccounting.issueCount) suppressions=$($ft15.inputSuppressions.Count) checks=$($ft15.contractChecks.status-join',') notEvaluated=$($ft15.failureAccounting.notEvaluatedInputSubjectCount)"}
    $unparseable=CloneAccounting $clean;$i08=@($unparseable.artifactStates|Where-Object artifactId -ceq 'AR-I08')[0];$i08.readStatus='Failed';$unparseable.rawObservationSubjects=@($unparseable.rawObservationSubjects|Where-Object subjectKind -cne 'FileDiscoveryObservation');$unparseable.stageConservationSets[2].universeIds=@($unparseable.rawObservationSubjects.subjectId);$unparseable.stageConservationSets[2].partitionIds=@($unparseable.rawObservationSubjects.subjectId);$unparseable.inputFailures=@([pscustomobject][ordered]@{recordId='accounting-sha256:d48e97294f293a31e9feb36b9f0946b5ebd46c2911d176c704c9f30465485f31';subjectKind='ObservationDocument';subjectId='AR-I08';reasonCode='InvalidObservation';attribution='FT-05:AR-I08';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json')});$documentFailure=RunAccounting $unparseable
    if($documentFailure.failureAccounting.inputObservationCount-ne4-or$documentFailure.inputFailures.Count-ne1-or$documentFailure.inputFailures[0].subjectId-cne'AR-I08'-or($documentFailure.contractChecks.status-join',')-cne'Accepted,Accepted,Accepted,NotEvaluated,NotEvaluated'){throw 'AR-I08 document-level ownership failed'}
    $extraCheck=CloneAccounting $clean;$extraCheck|Add-Member -NotePropertyName unexpectedCheck -NotePropertyValue ([pscustomobject]@{subjectId='C2Check:Unexpected'});$sixth=RunAccounting $extraCheck
    if($sixth.contractChecks.Count-ne5-or@($sixth.inputFailures|Where-Object subjectId -ceq 'C2Check:Conservation').Count-ne1-or$sixth.failureAccounting.contractFailureRecordCount-ne1){throw 'implicit sixth check fail-closed failed'}
    'status=Passed';return
}

if($Case -ceq 'DispatchPartitions'){
    $objectId='sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11'
    $toolObservation='version=1.0.0;observationId=observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180;resolution=SingleTool'
    $public=[pscustomobject][ordered]@{assetObjectId=$objectId;canonicalAssetId=$objectId;sourceId='pc-install-primary';objectType='Sprite';objectName='Hero';containerRelativePath='SourceCorpus/PcInstall/game-data.bundle';classId=1;serializedSizeBytes=100;dependencyObjectIds=@();toolObservations=@([pscustomobject][ordered]@{toolName='ToolA';observation=$toolObservation});platformVariant='Pc';configurationDisposition='NotConfiguration';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json');status=[pscustomobject][ordered]@{corpus='Cataloged';extraction='ExtractedReadable';semantics='Known';unity='NotTested';disposition='RetainForLater'}}
    $fact=[pscustomobject][ordered]@{assetObjectId=$objectId;sp04Partition='Classified';privateConfigurationDisposition=$null;configurationCandidateId=$null}
    $input=[pscustomobject]@{publicObjectsWithCanonicalId=@($public);dispatchInputFacts=@($fact);inputFailures=@();contractChecks=@()}
    $result=$loadedModule.Invoke({param($x)Invoke-C2DispatchPartitions $x},@($input))[0]
    if($result.dispatchRows.Count-ne1){throw 'SP-07 base row missing'}
    $row=$result.dispatchRows[0]
    if((@($row.PSObject.Properties.Name)-join',')-cne'assetObjectId,canonicalAssetId,sourceId,familyLane,memberSelectorInputs,configurationCandidateId,dispatchStatus,evidence'){throw 'SP-07 dispatch row exact shape failed'}
    if($row.familyLane-cne'UI'-or$row.dispatchStatus-cne'Assigned'-or$null-ne$row.configurationCandidateId){throw 'SP-07 base precedence failed'}
    $expectedSelectors=@("CanonicalAssetId=$objectId",'ClassId=1','ObjectType=Sprite','PlatformVariant=Pc',"ToolObservation=$toolObservation")
    $actualSelectors=@($row.memberSelectorInputs|ForEach-Object{"$($_.kind)=$($_.value)"})
    if(($actualSelectors-join'|')-cne($expectedSelectors-join'|')){throw "SP-07 base selector set/order failed: $($actualSelectors-join'|')"}
    if($result.coverage.dispatchEligibleObjectCount-ne1-or$result.coverage.assignedObjectCount-ne1-or$result.coverage.uiObjectCount-ne1){throw 'SP-07 base conservation failed'}
    function CloneDispatch($x){$x|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30}
    function RunDispatch($objects,$facts,$failures=@(),$checks=@()){$loadedModule.Invoke({param($x)Invoke-C2DispatchPartitions $x},@([pscustomobject]@{publicObjectsWithCanonicalId=@($objects);dispatchInputFacts=@($facts);inputFailures=@($failures);contractChecks=@($checks)}))[0]}
    $vectors=@(
        [pscustomobject]@{id='1';type='AudioClip';partition='Classified';disposition=$null;status='Assigned';lane='Audio'},
        [pscustomobject]@{id='2';type='AudioMixer';partition='Classified';disposition=$null;status='Assigned';lane='Audio'},
        [pscustomobject]@{id='3';type='Scene';partition='Classified';disposition=$null;status='Assigned';lane='Environment'},
        [pscustomobject]@{id='4';type='Avatar';partition='Classified';disposition=$null;status='Assigned';lane='Actor'},
        [pscustomobject]@{id='5';type='Sprite';partition='Classified';disposition=$null;status='Assigned';lane='UI'},
        [pscustomobject]@{id='6';type='ParticleSystem';partition='Classified';disposition=$null;status='Assigned';lane='Effects'},
        [pscustomobject]@{id='7';type='VisualEffect';partition='Classified';disposition=$null;status='Assigned';lane='Effects'},
        [pscustomobject]@{id='8';type='DefinitelyUnknown';partition='Classified';disposition=$null;status='RetainedForDiagnosis';lane='Unassigned'},
        [pscustomobject]@{id='9';type='Sprite';partition='Unclassified';disposition=$null;status='RetainedForDiagnosis';lane='Unassigned'},
        [pscustomobject]@{id='a';type='Sprite';partition='Classified';disposition='Parsed';status='ConfigurationOnly';lane='Unassigned'},
        [pscustomobject]@{id='b';type='sprite';partition='Classified';disposition=$null;status='RetainedForDiagnosis';lane='Unassigned'}
    )
    $aggregateObjects=[Collections.Generic.List[object]]::new();$aggregateFacts=[Collections.Generic.List[object]]::new()
    foreach($vector in $vectors){
        $o=CloneDispatch $public;$f=CloneDispatch $fact;$id='sha256:'+([string]$vector.id*64);$o.assetObjectId=$id;$o.canonicalAssetId=$id;$o.objectType=$vector.type;$f.assetObjectId=$id;$f.sp04Partition=$vector.partition;$f.privateConfigurationDisposition=$vector.disposition;$f.configurationCandidateId=if($vector.id-ceq'a'){'config-sha256:c79fe7f3b8e8c92c21d833160899a15d44cead595b9e6a9037216a2b3ed13ab7'}else{$null};$aggregateObjects.Add($o);$aggregateFacts.Add($f)
    }
    $aggregate=RunDispatch $aggregateObjects $aggregateFacts
    for($i=0;$i-lt$vectors.Count;$i++){if($aggregate.dispatchRows[$i].dispatchStatus-cne$vectors[$i].status-or$aggregate.dispatchRows[$i].familyLane-cne$vectors[$i].lane){throw "SP-07 lane vector failed: $($vectors[$i].type)/$($vectors[$i].partition)/$($vectors[$i].disposition)"}}
    $c=$aggregate.coverage
    if($c.dispatchEligibleObjectCount-ne11-or$c.assignedObjectCount-ne7-or$c.retainedForDiagnosisObjectCount-ne3-or$c.configurationOnlyObjectCount-ne1-or$c.audioObjectCount-ne2-or$c.environmentObjectCount-ne1-or$c.actorObjectCount-ne1-or$c.uiObjectCount-ne1-or$c.effectsObjectCount-ne2){throw 'SP-07 aggregate conservation failed'}
    $configFact=CloneDispatch $fact;$configFact.privateConfigurationDisposition='Parsed';$configFact.configurationCandidateId='config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564';$config=RunDispatch @($public) @($configFact);if($config.dispatchRows[0].dispatchStatus-cne'ConfigurationOnly'-or$config.dispatchRows[0].familyLane-cne'Unassigned'-or$config.dispatchRows[0].configurationCandidateId-cne$configFact.configurationCandidateId){throw 'SP-07 configuration precedence/binding failed'}
    $dedupeObject=CloneDispatch $public;$dependency='sha256:'+('d'*64);$dedupeObject.dependencyObjectIds=@($dependency,$dependency);$dedupeObject.toolObservations=@($public.toolObservations[0],$public.toolObservations[0]);$dedupe=RunDispatch @($dedupeObject) @($fact);$pairs=@($dedupe.dispatchRows[0].memberSelectorInputs|ForEach-Object{"$($_.kind)=$($_.value)"});if(@($pairs|Where-Object{$_-ceq"DependencyObjectId=$dependency"}).Count-ne1-or@($pairs|Where-Object{$_-ceq"ToolObservation=$toolObservation"}).Count-ne1){throw 'SP-07 selector dedupe failed'}
    $priorFailure=[pscustomobject]@{subjectId='AR-I07'};$suppressed=RunDispatch @($public) @($fact) @($priorFailure);if(-not$suppressed.outputsSuppressed-or$suppressed.dispatchRows.Count-ne0-or($suppressed.coverage.PSObject.Properties.Value|Measure-Object -Sum).Sum-ne0){throw 'SP-07 pre-existing failure suppression failed'}
    $failedCheck=[pscustomobject]@{status='Failed'};$checkSuppressed=RunDispatch @($public) @($fact) @() @($failedCheck);if(-not$checkSuppressed.outputsSuppressed-or$checkSuppressed.dispatchRows.Count-ne0){throw 'SP-07 failed-check suppression failed'}
    foreach($badFact in @(
        @(),
        @($fact,$fact),
        @([pscustomobject][ordered]@{assetObjectId=('sha256:'+('f'*64));sp04Partition='Classified';privateConfigurationDisposition=$null;configurationCandidateId=$null}),
        @([pscustomobject][ordered]@{assetObjectId=$objectId;sp04Partition='Classified';privateConfigurationDisposition='Parsed';configurationCandidateId='config-sha256:'+('0'*64)})
    )){$badJoin=RunDispatch @($public) $badFact;if($badJoin.inputFailures.Count-ne1-or$badJoin.inputFailures[0].attribution-cne'FT-10:C2Check:Conservation'-or$badJoin.inputFailures[0].evidence[0]-cne'Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json'-or$badJoin.dispatchRows.Count-ne0-or-not$badJoin.outputsSuppressed){throw 'SP-07 exact private join fail-closed failed'}}
    'status=Passed';return
}

if($Case -ceq 'CanonicalPartitions'){
    $objectId='sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11'
    $core=[pscustomobject][ordered]@{assetObjectId=$objectId;sourceId='pc-install-primary';objectType='Sprite';objectName='Hero';containerRelativePath='SourceCorpus/PcInstall/game-data.bundle';classId=1;serializedSizeBytes=100;dependencyObjectIds=@();toolObservations=@();platformVariant='Pc';configurationDisposition='Parsed';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json');status=[pscustomobject][ordered]@{corpus='Cataloged';extraction='CrossToolVerified';semantics='Known';unity='NotTested';disposition='RetainForLater'}}
    $input=[pscustomobject]@{publicObjectCores=@($core);canonicalProposalProvenance=@();acceptedNonNullCanonicalEvidenceObservationIds=@()}
    $result=$loadedModule.Invoke({param($x)Invoke-C2CanonicalPartitions $x},@($input))[0]
    if($result.canonicalGroups.Count-ne1-or$result.canonicalGroups[0].canonicalAssetId-cne$objectId-or$result.canonicalGroups[0].matchStatus-cne'Unresolved'-or$null-ne$result.canonicalGroups[0].equivalenceFingerprint){throw 'integrated Unresolved group failed'}
    if($result.coverage.canonicalizedObjectCount-ne1-or$result.coverage.canonicalConflictObjectCount-ne0-or$result.coverage.canonicalGroupCount-ne1-or$result.coverage.exactDuplicateGroupCount-ne0-or$result.coverage.platformVariantGroupCount-ne0-or$result.coverage.unresolvedCanonicalGroupCount-ne1){throw 'SP-06 conservation failed'}
    if((@($result.canonicalGroups[0].PSObject.Properties.Name)-join',')-cne'canonicalAssetId,memberObjectIds,matchStatus,platformScope,equivalenceFingerprint,variantEvidence'){throw 'canonical group exact shape failed'}
    if((@($result.publicObjectsWithCanonicalId[0].PSObject.Properties.Name)-join',')-cne'assetObjectId,canonicalAssetId,sourceId,objectType,objectName,containerRelativePath,classId,serializedSizeBytes,dependencyObjectIds,toolObservations,platformVariant,configurationDisposition,evidence,status'){throw 'canonical public join exact shape failed'}
    function Clone($x){$x|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30};function RunCanonical($x){$loadedModule.Invoke({param($v)Invoke-C2CanonicalPartitions $v},@($x))[0]};function ProposalId($x){[string](@($loadedModule.Invoke({param($v)Get-C2CanonicalProposalId $v},@($x)))[0])}
    $a='sha256:'+('a'*64);$b='sha256:'+('b'*64);$e='observation-sha256:'+('e'*64);$f='observation-sha256:'+('f'*64);$aid='canonical-sha256:843086f47eb4de699ad9d586f4692993fb1bbe0f68b1487b32aa1cd5b7eeff3c';$evE='Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/canonical-e.json';$evF='Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/canonical-f.json'
    $oa=Clone $core;$oa.assetObjectId=$a;$oa.platformVariant='Pc';$ob=Clone $core;$ob.assetObjectId=$b;$ob.platformVariant='Pc'
    $facts=@([pscustomobject][ordered]@{assetObjectId=$a;memberPlatform='Pc';contentFingerprint='1'*64},[pscustomobject][ordered]@{assetObjectId=$b;memberPlatform='Pc';contentFingerprint='1'*64})
    $pe=[pscustomobject][ordered]@{proposalId='canonical-proposal-sha256:3e94ad5cd6c7dfbc0b844c4cc9d6a45c89cb743a90f3fd613ac861b6f9cf075e';observationId=$e;canonicalEvidenceId='canonical-evidence-sha256:db79daf694e7124465b9ab59f11e5c83099708887ccbb8165d4082d96f72b635';proposedCanonicalAssetId=$aid;matchStatus='ExactDuplicate';platformScope='PcOnly';equivalenceFingerprint='1'*64;memberObjectIds=@($a,$b);memberFacts=$facts;missingMemberObjectIds=@();evidence=@($evE)}
    $pf=Clone $pe;$pf.proposalId='canonical-proposal-sha256:07596af8c1ccced882613599bf6b2f4e47efa7baed7e8b5a96bbfaa8001e83ee';$pf.observationId=$f;$pf.canonicalEvidenceId='canonical-evidence-sha256:84d251cfa1e7737a37cfba8044aa0a9b5b6ae445d006486f6085e27bdaf1b6d3';$pf.evidence=@($evF)
    $exact=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa,$ob);canonicalProposalProvenance=@($pe,$pf);acceptedNonNullCanonicalEvidenceObservationIds=@($e,$f)});if($exact.canonicalGroups.Count-ne1-or$exact.canonicalGroups[0].canonicalAssetId-cne$aid-or$exact.canonicalGroups[0].matchStatus-cne'ExactDuplicate'-or$exact.publicObjectsWithCanonicalId.Count-ne2-or$exact.inputFailures.Count){throw "ExactDuplicate exact vector failed groups=$($exact.canonicalGroups.Count) conflicts=$($exact.canonicalConflicts.Count) fields=$($exact.canonicalConflicts.conflictingFields-join',') failures=$($exact.inputFailures.attribution-join',')"}
    $duplicate=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa,$ob);canonicalProposalProvenance=@($pe,$pe);acceptedNonNullCanonicalEvidenceObservationIds=@($e)});if($duplicate.inputFailures.Count-ne1-or$duplicate.inputFailures[0].attribution-cne'FT-10:C2Check:Conservation'-or$duplicate.inputFailures[0].recordId-cne'accounting-sha256:99b22592adff48c273bdc79844085fdd2052dc5bc18766d8a6d8249cb7967985'-or$duplicate.canonicalGroups.Count-ne0-or-not$duplicate.outputsSuppressed){throw 'FT-10 duplicate provenance failed'}
    $sameObservationDifferentProposal=Clone $pf;$sameObservationDifferentProposal.observationId=$e;$sameObservationDifferentProposal.proposalId=ProposalId $sameObservationDifferentProposal;$oneToOne=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa,$ob);canonicalProposalProvenance=@($pe,$sameObservationDifferentProposal);acceptedNonNullCanonicalEvidenceObservationIds=@($e)});if($oneToOne.inputFailures.Count-ne1-or$oneToOne.inputFailures[0].attribution-cne'FT-10:C2Check:Conservation'-or$oneToOne.canonicalGroups.Count-ne0){throw 'FT-10 one-observation/two-proposal bypass failed'}
    foreach($mutation in @([pscustomobject]@{field='matchStatus';value='DefinitelyInvalid'},[pscustomobject]@{field='platformScope';value='DefinitelyInvalid'},[pscustomobject]@{field='observationId';value='bad'},[pscustomobject]@{field='canonicalEvidenceId';value='bad'},[pscustomobject]@{field='proposedCanonicalAssetId';value='bad'},[pscustomobject]@{field='equivalenceFingerprint';value='bad'})){$invalid=Clone $pe;$invalid.($mutation.field)=$mutation.value;$invalid.proposalId=ProposalId $invalid;$invalidResult=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa,$ob);canonicalProposalProvenance=@($invalid);acceptedNonNullCanonicalEvidenceObservationIds=@($invalid.observationId)});if($invalidResult.inputFailures.Count-ne1-or$invalidResult.inputFailures[0].attribution-cne'FT-10:C2Check:Conservation'-or$invalidResult.canonicalGroups.Count-ne0){throw "canonical provenance semantic validation failed: $($mutation.field)"}}
    $missing=Clone $pe;$missing.proposalId='canonical-proposal-sha256:24f936f959f9cff908eaf79b2159bcf55e5879be3a2a1e276c9d3c123bde9cc6';$missing.platformScope='Unknown';$missing.memberFacts=@($facts[0]);$missing.missingMemberObjectIds=@($b);$missingResult=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa);canonicalProposalProvenance=@($missing);acceptedNonNullCanonicalEvidenceObservationIds=@($e)});if($missingResult.canonicalConflicts.Count-ne1-or$missingResult.canonicalConflicts[0].canonicalConflictId-cne'canonical-conflict-sha256:2bdbd0bd8082a99d1665216df74581f06dc752254bb03f63c5262650c807b499'-or($missingResult.canonicalConflicts[0].conflictingFields-join',')-cne'missingMemberObjectIds,proposedCanonicalAssetId'-or$missingResult.inputFailures[0].recordId-cne'accounting-sha256:14cf5beeae126026d50ebbde74287d6df7da711a44570affbbc589dc2eda7fc8'){throw 'FT-09 missing exact vector failed'}
    $c='sha256:'+('c'*64);$bid='canonical-sha256:0942c13e4665a597883b01a50826348ce4443e1cbe3c676d74c24ab81c3a4ad3';$pc=Clone $pf;$pc.proposalId='canonical-proposal-sha256:966b0d84c34ecfde8c42c64f892601d3f6ec44e8c0530cf0c935fc4f8f2b73d5';$pc.canonicalEvidenceId='canonical-evidence-sha256:e879808a21e1683270df2417aba026e455f6ec5c1b16f5f58f7aed3ffb3eee16';$pc.proposedCanonicalAssetId=$bid;$pc.memberObjectIds=@($b,$c);$pc.memberFacts=@([pscustomobject][ordered]@{assetObjectId=$b;memberPlatform='Pc';contentFingerprint='1'*64},[pscustomobject][ordered]@{assetObjectId=$c;memberPlatform='Pc';contentFingerprint='1'*64});$overlap=RunCanonical ([pscustomobject]@{publicObjectCores=@($oa,$ob);canonicalProposalProvenance=@($pe,$pc);acceptedNonNullCanonicalEvidenceObservationIds=@($e,$f)});if($overlap.canonicalConflicts.Count-ne1-or$overlap.canonicalConflicts[0].canonicalConflictId-cne'canonical-conflict-sha256:6d27bbe91cbcdcf600269fa6e7f9f8566c47bb072bb389948352908de8b5df84'-or($overlap.canonicalConflicts[0].conflictingFields-join',')-cne'memberObjectIds'-or$overlap.inputFailures[0].recordId-cne'accounting-sha256:b96c96d4eb5a03e06798d939a37b102dac4a578495f2c4fb1275078e6ef58a77'){throw 'FT-09 overlap exact vector failed'}
    $d='sha256:'+('d'*64);$variantId='canonical-sha256:0daa9f57bb5628818d732ec67ff39f74839a47a4a668c0465bd6f4f0a7e0dc85';$variantEq='1bbf97948d5f9111ae0e5000a7420a367632e52f434c9cdf15ecae33dfa5bbe1';$oc=Clone $core;$oc.assetObjectId=$c;$oc.platformVariant='Pc';$od=Clone $core;$od.assetObjectId=$d;$od.platformVariant='Android';$variantFacts=@([pscustomobject][ordered]@{assetObjectId=$c;memberPlatform='Pc';contentFingerprint='2'*64},[pscustomobject][ordered]@{assetObjectId=$d;memberPlatform='Android';contentFingerprint='3'*64});$ve=[pscustomobject][ordered]@{proposalId='canonical-proposal-sha256:bcfd8bd495f025e7499ca30ab49c5026030b47b6ebf4826dd46fb629ccaf56f6';observationId=$e;canonicalEvidenceId='canonical-evidence-sha256:8f15fd3e611ba21a1edcd7dbde908459200c3b6cdde21010da9f2b41bbe507e2';proposedCanonicalAssetId=$variantId;matchStatus='ConfirmedVariant';platformScope='CrossPlatformVariant';equivalenceFingerprint=$variantEq;memberObjectIds=@($c,$d);memberFacts=$variantFacts;missingMemberObjectIds=@();evidence=@($evE)};$vf=Clone $ve;$vf.proposalId='canonical-proposal-sha256:66cae93bc4f8b1c7abc575cd7a771928a693fed0498b75ba2abb05f656f514f7';$vf.observationId=$f;$vf.canonicalEvidenceId='canonical-evidence-sha256:144a9217b5fdd1b299e9ad4adb69296ba8ac7eb001eb837bf4dc8c9dc2418fcc';$vf.evidence=@($evF);$variant=RunCanonical ([pscustomobject]@{publicObjectCores=@($oc,$od);canonicalProposalProvenance=@($ve,$vf);acceptedNonNullCanonicalEvidenceObservationIds=@($e,$f)});if($variant.canonicalGroups.Count-ne1-or$variant.canonicalGroups[0].canonicalAssetId-cne$variantId-or$variant.canonicalGroups[0].matchStatus-cne'ConfirmedVariant'-or$variant.canonicalGroups[0].equivalenceFingerprint-cne$variantEq-or$variant.canonicalGroups[0].variantEvidence.Count-ne2){throw 'ConfirmedVariant exact positive failed'}
    function AssertCanonicalConflict($left,$right,$field,$conflictId,$recordId){$r=RunCanonical ([pscustomobject]@{publicObjectCores=@($oc,$od);canonicalProposalProvenance=@($left,$right);acceptedNonNullCanonicalEvidenceObservationIds=@($e,$f)});if($r.canonicalConflicts.Count-ne1-or($r.canonicalConflicts[0].conflictingFields-join',')-cne$field-or$r.canonicalConflicts[0].canonicalConflictId-cne$conflictId-or$r.inputFailures[0].recordId-cne$recordId-or$r.publicObjectsWithCanonicalId.Count-ne0){throw "canonical conflict exact vector failed: $field"}}
    $x=Clone $vf;$x.matchStatus='ExactDuplicate';$x.canonicalEvidenceId='canonical-evidence-sha256:90a0887f725603c21dfa4049678a04639b68f8b16e3afa93fe7b114db8c5b8b1';$x.proposalId='canonical-proposal-sha256:108c28464128860401c75cd3eb6ab4592223fc74608bef384bb04ebba36831be';AssertCanonicalConflict $ve $x 'matchStatus' 'canonical-conflict-sha256:781d9a95c17b2b13e3d7dc238cbc8e617f6eb3c0055cdbcdef7024d7f9aa67b5' 'accounting-sha256:3a270d9e610aa9ebe108a56d5c58ce3f284e7f70ad6e2e6d207b7d2f39c1b5bc'
    $x=Clone $vf;$x.platformScope='PcOnly';$x.proposalId='canonical-proposal-sha256:27297e10a70d134a863e991f6ef3b72023f1ff413300a5a1fc1d63326be3f4d7';AssertCanonicalConflict $ve $x 'platformScope' 'canonical-conflict-sha256:cb87382ad9e3e0c4df42bc295b042face94d7c73219cc8165e63279504f29776' 'accounting-sha256:2a5ab596f6edacec595bea75857596b7e850dfe5cf2c98841bc71800b035506f'
    $l=Clone $ve;$r=Clone $vf;$l.memberFacts[1].memberPlatform='Pc';$r.memberFacts[1].memberPlatform='Pc';$l.proposalId='canonical-proposal-sha256:85cda06cc648f7e9a93f90daf3e13af0c257c4ed7a66c0f81d373a2f568a52b5';$r.proposalId='canonical-proposal-sha256:a568f81cf6cb9d8633cf6c29bb7d482985b705c00a222389c450bb4e174615a3';AssertCanonicalConflict $l $r 'memberPlatform' 'canonical-conflict-sha256:b45a6162ea16bda2d7c717d451de5c565296b9ce16edb676930a9b4e16b9b694' 'accounting-sha256:a2f3cf79107d4422fd7f75bddcad234e5d079a03f8a52f99ea970736ae7bc103'
    foreach($platformCase in @([pscustomobject]@{first='Pc';second='Unknown'},[pscustomobject]@{first='Android';second='Unknown'})){$l=Clone $ve;$r=Clone $vf;$l.memberFacts[0].memberPlatform=$platformCase.first;$l.memberFacts[1].memberPlatform=$platformCase.second;$r.memberFacts[0].memberPlatform=$platformCase.first;$r.memberFacts[1].memberPlatform=$platformCase.second;$l.proposalId=ProposalId $l;$r.proposalId=ProposalId $r;$invalidPlatforms=RunCanonical ([pscustomobject]@{publicObjectCores=@($oc,$od);canonicalProposalProvenance=@($l,$r);acceptedNonNullCanonicalEvidenceObservationIds=@($e,$f)});if($invalidPlatforms.canonicalConflicts.Count-ne1-or($invalidPlatforms.canonicalConflicts[0].conflictingFields-join',')-cne'memberPlatform'-or$invalidPlatforms.canonicalGroups.Count-ne0){throw "ConfirmedVariant exact Pc+Android requirement failed: $($platformCase.first)+$($platformCase.second)"}}
    $l=Clone $ve;$r=Clone $vf;$l.memberFacts[1].contentFingerprint='2'*64;$r.memberFacts[1].contentFingerprint='2'*64;$l.proposalId='canonical-proposal-sha256:bc9d70965fdcb648125ba539315bb94a47550d67ee93c05047bfec264e42a1c2';$r.proposalId='canonical-proposal-sha256:46270f39c430a93693a51b3afd36f0c02971a37066eaf5fbefc683fb4368b922';AssertCanonicalConflict $l $r 'contentFingerprint' 'canonical-conflict-sha256:bffc1ab94aa94f182dbae0e02c4a6eb1edd3e2cdce821390df9ab315131c6a12' 'accounting-sha256:0ca4f829ad7b7e71132e055f329c1f6351b2fb934d09cce992a6de1f73928c89'
    $l=Clone $ve;$r=Clone $vf;$l.equivalenceFingerprint='4'*64;$r.equivalenceFingerprint='4'*64;$l.canonicalEvidenceId='canonical-evidence-sha256:6cfb8bca2b02e4b2554c285564971a9a846fc1ec2c69b7b84c9e108db3212940';$r.canonicalEvidenceId='canonical-evidence-sha256:0fada0662bd211eebc3bffc40412decf0dc3dea2a6d08097109515957c4be6ff';$l.proposalId='canonical-proposal-sha256:10c64a41328e703261b7ffe287b241e412c0a4e4d5bbca70d6317b1e901fb5ab';$r.proposalId='canonical-proposal-sha256:f63fde95393413889917bc20d5a9bf91947ad8b819b6882a95b5269e198e26b5';AssertCanonicalConflict $l $r 'equivalenceFingerprint' 'canonical-conflict-sha256:36e974feaf687441fdcd12bede62c5461ad3ce2b3cf843a40858279c5a2f1cbe' 'accounting-sha256:7c5158ff25a6da20c94656196b201a0a07044865c4e3b33ccfa8612a452c33b7'
    $l=Clone $ve;$r=Clone $vf;$l.proposedCanonicalAssetId='canonical-sha256:'+('0'*64);$r.proposedCanonicalAssetId='canonical-sha256:'+('0'*64);$l.canonicalEvidenceId='canonical-evidence-sha256:11c27cb661a4eb487c400793f88b52c3016325975c02ba039309dfd2d907c1ab';$r.canonicalEvidenceId='canonical-evidence-sha256:e04a71d31b56392af6066e2e0c5ff1bf567fb6a8bd3dd5d4010de5e0bf633901';$l.proposalId='canonical-proposal-sha256:a026a213892f22f9b735733aaf2a3d033ecc8aca42a6e105eead8bc7d4ec00a5';$r.proposalId='canonical-proposal-sha256:71a3ab805daec59781a2df792ac25699fd57d3845d8730c3570e0d423b7ed272';AssertCanonicalConflict $l $r 'proposedCanonicalAssetId' 'canonical-conflict-sha256:9e90ab6ccc6053632f98f1394ee626344ccc5d40206975ba84c66528397e3d22' 'accounting-sha256:5022d9b9231dfa748eefb232045b00ae209148748e5d2d44c54085c06fbf0dda'
    "status=Passed";return
}

if($Case -ceq 'ConfigurationPartitions'){
    function RunConfig($x){try{$loadedModule.Invoke({param($v)try{Invoke-C2ConfigurationPartitions $v}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}},@($x))[0]}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}};function ConfigId($r){[string](@($loadedModule.Invoke({param($v)Get-C2ConfigurationObservationId $v},@($r)))[0])}
    $objectId='sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11';$merged=[pscustomobject][ordered]@{assetObjectId=$objectId;correlationId='correlation-sha256:a7341b5f0406ce9a824900156f5a811710ffd819589dcece01d95976761720d1';observationIds=@('observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180','observation-sha256:7a213fdda2a2eeecce2908215747a70211903ba19f2721984cf05375dfd8d98a');resolutionStatus='Agreed';resolvedValues=[pscustomobject][ordered]@{sourceId='pc-install-primary';objectType='Sprite';objectName='Hero';containerRelativePath='SourceCorpus/PcInstall/game-data.bundle';pathId='10';classId=1;serializedSizeBytes=100;dependencyObjectIds=@();contentFingerprint='1'*64;configurationDisposition='Parsed';memberPlatform='Pc'};evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json','Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r2.json')}
    $f=[pscustomobject]@{sourceId='pc-install-primary';relativePath='Config/table.json';containerKind='ConfigurationCandidate'};$rowA=[pscustomobject][ordered]@{configurationObservationId='configuration-observation-sha256:e2eb4fc64d6e829aba513b46c3b236db1a046d8a859d067d37d9c4360fb5fda7';toolName='ToolA';toolVersion='1.0.0';sourceId='pc-install-primary';relativePath='Config/table.json';contentFingerprint='6'*64;configurationDisposition='Parsed';observation='parsed';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-config.json')};$rowB=$rowA|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$rowB.toolName='ToolB';$rowB.evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-config.json');$rowB.configurationObservationId='configuration-observation-sha256:33534e491e7ab8fe3912abbb3e9f2f8a7bb20af6b5962896b5d77387088f12e1'
    function InputConfig($files,$status,$rows,$sha){if([string]::IsNullOrEmpty($sha)){$sha='2dbc475a471bf96dc3c4aae3dcc51e3dd9571a33048d81104085e7ba0e84b9ae'};[pscustomobject]@{c1Files=@($files);mergedObjects=@($merged);fileConfigurationArtifact=[pscustomobject]@{artifactPath='Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json';artifactSha256=$sha;documentReadStatus=$status;document=if($status-eq'Parsed'){[pscustomobject]@{rows=@($rows)}}else{$null}}}}
    $integration=RunConfig (InputConfig @() Absent @());if($integration.configurationCandidates.Count-ne1-or$integration.configurationCandidates[0].configurationCandidateId-cne'config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564'-or$integration.coverage.configurationDiscoverySubjectCount-ne1-or$integration.coverage.parsedConfigurationCount-ne1){throw 'integrated object configuration vector failed'}
    $p1Absent=RunConfig (InputConfig @($f) Absent @());if($p1Absent.configurationCandidates.Count-ne2-or@($p1Absent.configurationCandidates|Where-Object configurationDisposition -eq DiscoveredOpaque).Count-ne1){throw 'P1 absent fConfig vector failed'}
    $present=RunConfig (InputConfig @($f) Parsed @($rowA,$rowB));$fileCandidate=@($present.configurationCandidates|Where-Object targetKind -eq File)[0];if($fileCandidate.configurationCandidateId-cne'config-sha256:af9d767ba7fa499898dbfb3315e54f9de3cc5dba438a6c0367619da6b3684b79'-or$fileCandidate.configurationDisposition-cne'Parsed'-or$fileCandidate.observationIds.Count-ne2-or$present.coverage.configurationDiscoverySubjectCount-ne2-or$present.coverage.configurationCandidateCount-ne2){throw 'P1 exact AR-I09 positive failed'}
    $bad=$rowB|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$bad.configurationDisposition='Encrypted';$bad.configurationObservationId=ConfigId $bad;$conflict=RunConfig (InputConfig @($f) Parsed @($rowA,$bad) '1058a874db6f283672a6595682a018c17fb1185ff6843d656473ca259231e165');if($conflict.configurationConflicts.Count-ne1-or($conflict.configurationConflicts[0].conflictingFields-join',')-cne'configurationDisposition'-or$conflict.inputFailures[0].attribution-notlike'FT-08:*'-or-not$conflict.outputsSuppressed){throw 'FT-08 disposition conflict failed'}
    $content=$rowB|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$content.contentFingerprint='7'*64;$content.configurationObservationId=ConfigId $content;$contentConflict=RunConfig (InputConfig @($f) Parsed @($rowA,$content) '3c43c5f8709da8cac30ee15bdc84ec65c93daa772c49ac93deaf9cf71f9a2d0f');if($contentConflict.configurationConflicts.Count-ne1-or($contentConflict.configurationConflicts[0].conflictingFields-join',')-cne'contentFingerprint'-or$contentConflict.configurationCandidates.Count-ne1-or$contentConflict.inputFailures.Count-ne1){throw 'FT-08 content conflict failed'}
    $duplicate=RunConfig (InputConfig @($f) Parsed @($rowA,$rowA) '752b799d2ca83cb65b8a067be5bc6d817fe735b5df43e89f693ba4ebde1e4e74');if(@($duplicate.inputFailures|Where-Object attribution -like 'FT-05:*').Count-ne1-or$duplicate.configurationCandidates.Count-ne2-or$duplicate.inputFailures[0].subjectId-cne'raw-row-sha256:058e1ab88a89586e6daa7262da730d590f85e92603887631ea72d719b9499594'){throw 'duplicate HI-07 fail-closed failed'}
    $unsafe=$rowA|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$unsafe.relativePath='../table.json';$unsafe.configurationObservationId=ConfigId $unsafe;$unsafeResult=RunConfig (InputConfig @($f) Parsed @($unsafe) 'e8e53522bf81a244b1027138cf20dd6267b3a2aa9b8ffcc0bfdbb0c22781d01a');if(@($unsafeResult.inputFailures|Where-Object attribution -like 'FT-04:*').Count-ne1-or$unsafeResult.inputFailures[0].subjectId-cne'raw-row-sha256:0dbbeb3bda4452f411a2e5d3481caea585364d67fe462afd4898b80303ef0c16'){throw 'unsafe AR-I09 row failed'}
    $unknown=$rowA|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$unknown.relativePath='Config/missing.json';$unknown.configurationObservationId=ConfigId $unknown;$unknownResult=RunConfig (InputConfig @($f) Parsed @($unknown) 'e93104b7230ddb08651aa74152c62a191b2cf568a42f9d44511798438a999225');if(@($unknownResult.inputFailures|Where-Object reasonCode -eq 'UnknownTarget').Count-ne1-or$unknownResult.inputFailures[0].subjectId-cne'raw-row-sha256:7cf682a99940cf6234adde0690056efa044a04b2dac2dc20f0359450c24cce11'){throw 'unknown AR-I09 target failed'}
    $malformed=$rowA|ConvertTo-Json -Depth 10|ConvertFrom-Json -Depth 10;$malformed.toolName='';$malformedResult=RunConfig (InputConfig @($f) Parsed @($malformed) 'e413a953c7b5947efb283f3e802a9f3c552f3376e4d7b8b57ef4fbf290875be1');if(@($malformedResult.inputFailures|Where-Object attribution -like 'FT-05:*').Count-ne1-or$malformedResult.inputFailures[0].subjectId-cne'raw-row-sha256:2e113d54ada29b0d8c19d6468e9fdba1f1a67b2de9267caa7890bc10afca3ac5'){throw 'malformed AR-I09 row failed'}
    $documentInput=InputConfig @($f) Parsed @();$documentInput.fileConfigurationArtifact.document=[pscustomobject]@{wrong=@()};$documentResult=RunConfig $documentInput;if($documentResult.inputFailures.Count-ne1-or$documentResult.inputFailures[0].attribution-cne'FT-05:AR-I09'){throw 'malformed AR-I09 document failed'}
    if((@($integration.configurationCandidates[0].PSObject.Properties.Name)-join',')-cne'configurationCandidateId,targetKind,sourceId,containerRelativePath,assetObjectId,configurationDisposition,observationIds,evidence'-or(@($conflict.configurationConflicts[0].PSObject.Properties.Name)-join',')-cne'configurationConflictId,configurationCandidateId,targetKind,observationIds,conflictingFields,evidence'){throw 'SP-05 exact row shape failed'}
    if($conflict.configurationConflicts[0].configurationConflictId-cne'configuration-conflict-sha256:812c6ce06a6ffca2bdb3641c21364beced5353f85d9529d333c23206cb86d5df'-or$conflict.inputFailures[0].recordId-cne'accounting-sha256:9c7773a3417894a7cd4bd85dbf5762aa97968735c66a909d07fbf0e1eba8453e'){throw 'FT-08 disposition exact identity failed'}
    if($content.configurationObservationId-cne'configuration-observation-sha256:dd1567900d725f6ce195a4c37f5e5dc21a1278f019725580d5bbe27684682693'-or$contentConflict.configurationConflicts[0].configurationConflictId-cne'configuration-conflict-sha256:ca94deb28ebf38c44be15185627abc7d99413514789bec0d5a8a310f31b652c4'-or$contentConflict.inputFailures[0].recordId-cne'accounting-sha256:bc0e9b34dd7287a2ec3948e21eaee736af3edfc431ee21fe48368053a6a625dd'){throw 'FT-08 content exact identity failed'}
    "status=Passed";"integrationConfigurationCount=$($integration.coverage.configurationCandidateCount)";"p1ConfigurationSubjectCount=$($present.coverage.configurationDiscoverySubjectCount)";"p1ConfigurationCandidateCount=$($present.coverage.configurationCandidateCount)";"configurationConflictCount=$($conflict.coverage.configurationConflictCount)";return
}

if($Case -cin @('ObjectObservationPartitions','ObjectMergeProjection')){
    function Run($Value){try{$loadedModule.Invoke({param($x)Invoke-C2ObjectObservationPartitions $x},@($Value))[0]}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}}
    function Row($Index,$Id,$PathId,$ClassId,$Name){[pscustomobject][ordered]@{observationId=$Id;toolName='ToolA';toolVersion='1.0.0';sourceId='pc-install-primary';containerRelativePath='SourceCorpus/PcInstall/game-data.bundle';pathId=[string]$PathId;classId=$ClassId;serializedSizeBytes=100;objectType='Sprite';objectName=$Name;dependencyLocators=@();contentFingerprint=([string]$PathId)[0].ToString()*64;configurationDisposition='Parsed';canonicalEvidence=$null;correlationEvidence=[pscustomobject][ordered]@{correlationId=@('correlation-sha256:a7341b5f0406ce9a824900156f5a811710ffd819589dcece01d95976761720d1','correlation-sha256:a7341b5f0406ce9a824900156f5a811710ffd819589dcece01d95976761720d1','correlation-sha256:0d6bf1110a7fa5f2330cc074dcf371131d19a5a80074d3a1667562f59c4a0282','correlation-sha256:0d6bf1110a7fa5f2330cc074dcf371131d19a5a80074d3a1667562f59c4a0282','correlation-sha256:21a469bfa4130d38331a357835437036672cd557e5d087a1e94db54fd7892693','correlation-sha256:da12cf2912d447fb1db44cc45465001ef05f37dd0bbb7c7e5ce2be90bf92b5fb')[$Index];method='ExactLocator';evidence=@("Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r$($Index+1).json")};evidence=@("Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r$($Index+1).json")}}
    $ids=@('observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180','observation-sha256:7a213fdda2a2eeecce2908215747a70211903ba19f2721984cf05375dfd8d98a','observation-sha256:6d653ff6e6e7b582843a2b8084364f14f32db83c6cbbba67cca6e1b738f63e2e','observation-sha256:546997444cbe327e4d9dd073c4dc067721557d559861b76a93262556209e8b77',$null,'observation-sha256:6ceeb8491c944325c2a038a56793b3fe062b41a694201e11b4f20302ea13c7e6')
    $rows=@((Row 0 $ids[0] 10 1 Hero),(Row 1 $ids[1] 10 1 Hero),(Row 2 $ids[2] 20 1 Conflict),(Row 3 $ids[3] 20 1 Conflict),(Row 4 $null 30 -1 Rejected),(Row 5 $ids[5] 40 1 Excluded));$rows[1].toolName='ToolB';$rows[3].toolName='ToolB';$rows[3].objectType='Mesh';$rows[2].contentFingerprint='2'*64;$rows[3].contentFingerprint='2'*64;$rows[4].contentFingerprint='3'*64;$rows[5].contentFingerprint='4'*64
    $approval=[pscustomobject][ordered]@{approvalId='exclusion-approval-sha256:01130b91f76fa3ece824051cb5324ead761d8cd73567249beda1b80f930de1fd';subjectKind='ObjectObservation';subjectId=$ids[5];reasonCode='ApprovedInputExclusion';reason='Reserved synthetic exclusion counterexample.';approvedBy='C2FixtureReview';approvedAt='2026-07-12T00:00:00Z';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r6-exclusion-approval.md')}
    $input=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId='snapshot-pc-install-001';inputFingerprint='a'*64;discoveryInputFingerprint='f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab';sourceKinds=@([pscustomobject]@{sourceId='pc-install-primary';sourceKind='PcInstall'});objectObservationArtifact=[pscustomobject][ordered]@{artifactPath='Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json';artifactSha256='50616dd29ec968121675658ba8aa1c8ba78d038034ad3824453f64fd5050d63c';documentReadStatus='Parsed';document=[pscustomobject]@{rows=$rows}};exclusionApprovalArtifact=[pscustomobject][ordered]@{artifactPath='Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json';artifactSha256='a';documentReadStatus='Parsed';document=[pscustomobject]@{observationArtifactPath='Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json';observationArtifactSha256='50616dd29ec968121675658ba8aa1c8ba78d038034ad3824453f64fd5050d63c';approvals=@($approval)}}}
    $result=Run $input
    if((@($result.PSObject.Properties.Name)-join ',') -cne 'schemaVersion,snapshotId,inputFingerprint,discoveryInputFingerprint,observationSubjects,mergedObjects,observationConflicts,publicObjectCores,canonicalProposalProvenance,inputFailures,inputExclusions,coverage,gateStatus,outputsSuppressed'){throw 'SP03 result shape failed'}
    if(($result.observationSubjects.partition-join ',') -cne 'AcceptedObservation,AcceptedObservation,AcceptedObservation,AcceptedObservation,RejectedObservation,ExcludedObservation'){throw "SP03a partition vector failed: $($result.observationSubjects.partition-join ',')"}
    if($result.coverage.objectObservationRowCount -ne 6 -or $result.coverage.acceptedObjectObservationRowCount -ne 4 -or $result.coverage.rejectedObjectObservationRowCount -ne 1 -or $result.coverage.excludedObjectObservationRowCount -ne 1){throw 'SP03a conservation failed'}
    $expectedFailureCount=if($Case -ceq 'ObjectMergeProjection'){2}else{2};if($result.inputFailures.Count -ne $expectedFailureCount -or @($result.inputFailures|Where-Object attribution -like 'FT-05:*').Count -ne 1 -or $result.inputExclusions.Count -ne 1 -or $result.inputExclusions[0].attribution -ne "FT-14:$($ids[5])" -or -not $result.outputsSuppressed){throw 'SP03a accounting failed'}
    if($Case -ceq 'ObjectMergeProjection'){
        if($result.mergedObjects.Count -ne 1 -or $result.observationConflicts.Count -ne 1 -or $result.publicObjectCores.Count -ne 1){throw 'SP03b/SP04 implementation absent'}
        $merged=$result.mergedObjects[0];$conflict=$result.observationConflicts[0];$public=$result.publicObjectCores[0]
        if((@($merged.PSObject.Properties.Name)-join ',') -cne 'assetObjectId,correlationId,observationIds,resolutionStatus,resolvedValues,evidence' -or $merged.resolutionStatus -cne 'Agreed' -or $merged.observationIds.Count -ne 2){throw 'merged object exact shape/vector failed'}
        if((@($merged.resolvedValues.PSObject.Properties.Name)-join ',') -cne 'sourceId,objectType,objectName,containerRelativePath,pathId,classId,serializedSizeBytes,dependencyObjectIds,contentFingerprint,configurationDisposition,memberPlatform'){throw 'resolvedValues exact AR-S05 shape failed'}
        if((@($conflict.PSObject.Properties.Name)-join ',') -cne 'observationConflictId,correlationId,observationIds,derivedAssetObjectIds,conflictingFields,failureClass,evidence' -or $conflict.failureClass -cne 'MaterialConflict' -or ($conflict.conflictingFields-join ',') -cne 'objectType'){throw 'observation conflict exact shape/vector failed'}
        $ft07=@($result.inputFailures|Where-Object attribution -like 'FT-07:*')[0];if($conflict.observationConflictId -cne 'observation-conflict-sha256:a008931eff217b62b8d15ee99a06b095c4a68cfa01231abf0c0f2025d209a82d' -or $ft07.recordId -cne 'accounting-sha256:fc9d5f9fceb8366a2f09580834f7d450246d015095706c97524cdc0adffe213b'){throw 'FT-07 exact identity/accounting failed'}
        if($public.status.corpus -cne 'Cataloged' -or $public.status.extraction -cne 'CrossToolVerified' -or $public.status.semantics -cne 'Known' -or $public.status.unity -cne 'NotTested' -or $public.status.disposition -cne 'RetainForLater' -or $public.sp04Partition -cne 'Classified' -or $public.toolObservations.Count -ne 2){throw 'SP04 public projection failed'}
        if($result.coverage.correlationGroupCount -ne 2 -or $result.coverage.enumeratedObjectCount -ne 1 -or $result.coverage.observationConflictObjectCount -ne 1 -or $result.coverage.classifiedObjectCount -ne 1 -or $result.coverage.unclassifiedObjectCount -ne 0 -or $result.coverage.observationConflictRecordCount -ne 1 -or $result.coverage.inputFailureCount -ne 2 -or $result.coverage.issueCount -ne 2){throw 'SP03b/SP04 conservation/accounting failed'}
        function CloneInput($Value){$Value|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30};function ReId($Row){[string](@($loadedModule.Invoke({param($r)Get-C2ObservationId $r},@($Row)))[0])};function ReCorrelation($Row){[string](@($loadedModule.Invoke({param($r)Get-C2ExactCorrelationId $r},@($Row)))[0])}
        $identity=CloneInput $input;$identity.objectObservationArtifact.document.rows=@($identity.objectObservationArtifact.document.rows[0],$identity.objectObservationArtifact.document.rows[1]);$identity.exclusionApprovalArtifact.document.approvals=@();$identity.objectObservationArtifact.document.rows[1].classId=2;$identity.objectObservationArtifact.document.rows[1].observationId=ReId $identity.objectObservationArtifact.document.rows[1];$identityResult=Run $identity;if($identityResult.observationConflicts.Count-ne 1-or$identityResult.observationConflicts[0].failureClass-cne'IdentityConflict'-or($identityResult.observationConflicts[0].conflictingFields-join',')-cne'classId'){throw "IdentityConflict vector failed: conflicts=$($identityResult.observationConflicts.Count) failures=$($identityResult.inputFailures.attribution-join ',')"}
        foreach($vector in @([pscustomobject]@{field='none';value=$null;semantics='Known';partition='Classified'},[pscustomobject]@{field='objectName';value='Unknown';semantics='PartiallyKnown';partition='Classified'},[pscustomobject]@{field='configurationDisposition';value='DiscoveredOpaque';semantics='PartiallyKnown';partition='Classified'},[pscustomobject]@{field='objectType';value='Unknown';semantics='Unknown';partition='Unclassified'})){$one=CloneInput $input;$one.objectObservationArtifact.document.rows=@($one.objectObservationArtifact.document.rows[0]);$one.exclusionApprovalArtifact.document.approvals=@();if($vector.field-ne'none'){$one.objectObservationArtifact.document.rows[0].($vector.field)=$vector.value;$one.objectObservationArtifact.document.rows[0].observationId=ReId $one.objectObservationArtifact.document.rows[0]};$v=Run $one;if($v.publicObjectCores[0].status.semantics-cne$vector.semantics-or$v.publicObjectCores[0].sp04Partition-cne$vector.partition){throw "SP04 $($vector.field) vector failed"}}
        $deps=CloneInput $input;$target=$deps.objectObservationArtifact.document.rows[0];$dependent=CloneInput $target;$dependent.pathId='11';$dependent.objectName='Dependent';$dependent.correlationEvidence.correlationId=ReCorrelation $dependent;$dependent.dependencyLocators=@([pscustomobject][ordered]@{sourceId=$target.sourceId;containerRelativePath=$target.containerRelativePath;pathId=$target.pathId;classId=$target.classId});$dependent.observationId=ReId $dependent;$deps.objectObservationArtifact.document.rows=@($target,$dependent);$deps.exclusionApprovalArtifact.document.approvals=@();$depsResult=Run $deps;if($depsResult.coverage.enumeratedObjectCount-ne 2-or$depsResult.coverage.unresolvedDependencyCount-ne 0-or@($depsResult.publicObjectCores|Where-Object objectName -eq Dependent)[0].status.semantics-cne'Known'){throw 'complete resolved-set dependency positive failed'}
        $onlyDependent=CloneInput $deps;$onlyDependent.objectObservationArtifact.document.rows=@($onlyDependent.objectObservationArtifact.document.rows[1]);$unresolvedResult=Run $onlyDependent;if($unresolvedResult.coverage.unresolvedDependencyCount-ne 1-or$unresolvedResult.publicObjectCores[0].status.semantics-cne'PartiallyKnown'){throw 'unresolved dependency vector failed'}
        $canonical=CloneInput $input;$canonical.objectObservationArtifact.document.rows=@($canonical.objectObservationArtifact.document.rows[0]);$canonical.exclusionApprovalArtifact.document.approvals=@();$canonical.objectObservationArtifact.document.rows[0].canonicalEvidence=[pscustomobject][ordered]@{memberPlatform='Pc';proposedMatchStatus='Unresolved';proposedEquivalenceFingerprint=$null;proposedCanonicalAssetId=$null;memberObjectIds=@();evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/canonical.json')};$canonical.objectObservationArtifact.document.rows[0].observationId=ReId $canonical.objectObservationArtifact.document.rows[0];$canonicalResult=Run $canonical;if($canonicalResult.publicObjectCores[0].evidence -cnotcontains 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/canonical.json'){throw 'canonical public evidence union failed'}
        "status=Passed";"correlationGroupCount=2";"enumeratedObjectCount=1";"observationConflictObjectCount=1";"classifiedObjectCount=1";"unclassifiedObjectCount=0";"resolutionStatus=$($merged.resolutionStatus)";"semantics=$($public.status.semantics)";"conflictId=$($conflict.observationConflictId)";return
    }
    if((@($result.observationSubjects[0].PSObject.Properties.Name)-join ',') -cne 'rowIndex,subjectId,observationId,partition,evidence' -or $result.observationSubjects[4].subjectId -cne 'raw-row-sha256:f1343fa48a1a370cf061818de05aa529ae846cebfb5b92360a29c2f0cd4280d6'){throw 'SP03a exact subject contract failed'}
    if($result.inputFailures[0].recordId -cne 'accounting-sha256:bb230135c98c6a67dbddad28cda99d0280161a4e5db2f0e3e0e197928e3d52b6' -or $result.inputExclusions[0].recordId -cne 'accounting-sha256:1911ef0d4c0abc9045d95243f5f16e3df77b6d1a3885d2968b5425ab625c5f62' -or ($result.inputExclusions[0].evidence-join ',') -cne 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r6-exclusion-approval.md,Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r6.json' -or $result.gateStatus -cne 'Failed' -or $null -ne $result.discoveryInputFingerprint){throw 'SP03a exact accounting/suppression contract failed'}
    $bad=$input|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$one=$bad.exclusionApprovalArtifact.document.approvals[0];$bad.exclusionApprovalArtifact.document.approvals=@($one,$one);$duplicate=Run $bad;if(@($duplicate.inputFailures|Where-Object attribution -eq 'FT-02:AR-I11').Count -ne 1){throw "duplicate approval fail-closed failed: $($duplicate.inputFailures.attribution-join ',')"}
    $orphan=$input|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$orphan.exclusionApprovalArtifact.document.approvals[0].subjectId='observation-sha256:'+'0'*64;$orphan.exclusionApprovalArtifact.document.approvals[0].approvalId='exclusion-approval-sha256:'+'0'*64;if(@((Run $orphan).inputFailures|Where-Object attribution -eq 'FT-02:AR-I11').Count -ne 1){throw 'orphan approval fail-closed failed'}
    $nested=$input|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$nested.objectObservationArtifact.document.rows[0].correlationEvidence=$null;$nestedResult=Run $nested;if($nestedResult.observationSubjects[0].partition -ne 'RejectedObservation' -or @($nestedResult.inputFailures|Where-Object attribution -like 'FT-05:*').Count -lt 1){throw "malformed nested row structured failure failed: $($nestedResult.inputFailures.attribution-join ',')"}
    $unsafe=$input|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$unsafe.objectObservationArtifact.document.rows[0].containerRelativePath='../bad';$unsafeResult=Run $unsafe;if(@($unsafeResult.inputFailures|Where-Object attribution -like 'FT-04:*').Count -ne 1){throw "unsafe row FT-04 failed: $($unsafeResult.inputFailures.attribution-join ',')"}
    $document=$input|ConvertTo-Json -Depth 30|ConvertFrom-Json -Depth 30;$document.objectObservationArtifact.documentReadStatus='Unparseable';$document.objectObservationArtifact.document=$null;$documentResult=Run $document;if($documentResult.inputFailures.Count -ne 1 -or $documentResult.inputFailures[0].attribution -ne 'FT-05:AR-I07' -or $documentResult.observationSubjects.Count -ne 0){throw 'document-level FT-05 ownership failed'}
    "status=Passed";"objectObservationRowCount=$($result.coverage.objectObservationRowCount)";"acceptedObjectObservationRowCount=$($result.coverage.acceptedObjectObservationRowCount)";"rejectedObjectObservationRowCount=$($result.coverage.rejectedObjectObservationRowCount)";"excludedObjectObservationRowCount=$($result.coverage.excludedObjectObservationRowCount)";"inputFailureCount=$($result.coverage.inputFailureCount)";"excludedInputCount=$($result.coverage.excludedInputCount)";return
}

if($Case -ceq 'FilePartitions'){
    function Clone($Value){$Value|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100}
    function Run($Value){$loadedModule.Invoke({param($x)Invoke-C2FileDiscoveryPartitions $x},@($Value))[0]}
    $path='SourceCorpus/PcInstall/game-data.bundle';$source='pc-install-primary';$ar7='Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json';$ar8='Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json'
    $file=[pscustomobject][ordered]@{sourceId=$source;relativePath=$path;containerKind='UnknownInput';sizeBytes=4096;parseStatus='NotAttempted';status=[pscustomobject]@{extraction='NotAttempted'}}
    $r1=[pscustomobject]@{toolName='ToolA';toolVersion='1.0.0';sourceId=$source;containerRelativePath=$path;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json')}
    $r2=[pscustomobject]@{toolName='ToolB';toolVersion='1.0.0';sourceId=$source;containerRelativePath=$path;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r2.json')}
    $r3=[pscustomobject]@{toolName='ToolA';toolVersion='1.0.0';sourceId=$source;containerRelativePath=$path;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json')}
    $r4=[pscustomobject]@{toolName='ToolB';toolVersion='1.0.0';sourceId=$source;containerRelativePath=$path;evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json')}
    function New-FileRow($Tool,$Outcome,$Evidence,$Id){[pscustomobject][ordered]@{fileDiscoveryObservationId=$Id;toolName=$Tool;toolVersion='1.0.0';sourceId=$source;relativePath=$path;outcome=$Outcome;evidence=@($Evidence)}}
    $toolA=New-FileRow ToolA Readable 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-file-readable.json' 'file-discovery-observation-sha256:195be146f0f08df54c160fbccf1c790bc1fbd535b6626976e1981344031b3e80'
    $toolB=New-FileRow ToolB Readable 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-file-readable.json' 'file-discovery-observation-sha256:19e7158715bf0dd0807da34dddfa744b9d205a3d3e1273ea5185f217b426b5c4'
    $opaque=New-FileRow ToolA Opaque 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/f-opaque.json' 'file-discovery-observation-sha256:8b2dfa70202ca30066a055c944b1b8d47c5f8dd628afaec24bcc7a7d317401cb'
    $failed=New-FileRow ToolA Failed 'Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/f-failed.json' 'file-discovery-observation-sha256:bb657295c846a7155565cdb57444a13f7ddcc395147f016b36ad93544623848b'
    function Input($ObjectRows,$Status,$Rows,$Sha){[pscustomobject][ordered]@{snapshotId='snapshot-pc-install-001';inputFingerprint=('a'*64);discoveryInputFingerprint='f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab';c1Files=@(Clone $file);objectObservationArtifact=[pscustomobject][ordered]@{artifactPath=$ar7;artifactSha256='50616dd29ec968121675658ba8aa1c8ba78d038034ad3824453f64fd5050d63c';acceptedRows=@($ObjectRows)};fileDiscoveryArtifact=[pscustomobject][ordered]@{artifactPath=$ar8;artifactSha256=$Sha;documentReadStatus=$Status;document=if($Status -eq 'Parsed'){[pscustomobject]@{rows=@($Rows)}}else{$null}}}}
    $wrap1=[pscustomobject][ordered]@{rowIndex=0;observation=$r1};$wrap2=[pscustomobject][ordered]@{rowIndex=1;observation=$r2};$wrap3=[pscustomobject][ordered]@{rowIndex=2;observation=$r3};$wrap4=[pscustomobject][ordered]@{rowIndex=3;observation=$r4}
    $none=Run (Input @() Absent @() $null);if($none.fileSubjects[0].sp02Partition -ne 'NotAttempted' -or $none.resolvedFileResults[0].parseStatus -ne 'NotAttempted'){throw 'NotAttempted vector failed'}
    $single=Run (Input @() Parsed @($toolA) 'dummy');if($single.fileSubjects[0].sp02Partition -ne 'Parsed' -or $single.resolvedFileResults[0].parseStatus -ne 'ExtractedReadable'){throw 'single Parsed vector failed'}
    $cross=Run (Input @($wrap1,$wrap2) Absent @() $null);if($cross.resolvedFileResults[0].parseStatus -ne 'CrossToolVerified'){throw 'cross-tool Parsed vector failed'}
    $opaqueResult=Run (Input @() Parsed @($opaque) 'ecdf3effe9c47d69cd79ac185fcd6e13e44cc0408bb75c19980b0ade28b25650');if($opaqueResult.fileSubjects[0].sp02Partition -ne 'Opaque' -or $opaqueResult.resolvedFileResults[0].parseStatus -ne 'Opaque'){throw 'Opaque vector failed'}
    $failedResult=Run (Input @() Parsed @($failed) 'e658cdcfd57b5cf40f95c70a28c8676f6308b489e132988f53ba1c37b69d8a4a');if($failedResult.fileSubjects[0].sp02Partition -ne 'Failed' -or $failedResult.resolvedFileResults[0].parseStatus -ne 'Failed'){throw 'Failed vector failed'}
    $conflict=Run (Input @($wrap1) Parsed @($opaque) 'ecdf3effe9c47d69cd79ac185fcd6e13e44cc0408bb75c19980b0ade28b25650')
    if($conflict.fileDiscoveryConflicts[0].fileDiscoveryConflictId -ne 'file-discovery-conflict-sha256:5367efe2882b3fadbaebff107f0ba8178cd441cdd48397a4307b908106935645' -or $conflict.inputFailures[0].recordId -ne 'accounting-sha256:fa159cbe41427024ebb1a3bd486a6246a240c16c2811df8c74afa392c0c3ce98' -or $conflict.resolvedFileResults.Count -ne 0 -or -not $conflict.outputsSuppressed){throw 'Conflict exact vector failed'}
    $integrated=Run (Input @($wrap1,$wrap2,$wrap3,$wrap4) Parsed @($toolA,$toolB) 'f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a')
    $resultOrder='schemaVersion,snapshotId,inputFingerprint,discoveryInputFingerprint,fileSubjects,resolvedFileResults,fileDiscoveryConflicts,inputFailures,coverage,gateStatus,outputsSuppressed';if((@($integrated.PSObject.Properties.Name)-join ',') -ne $resultOrder){throw 'SP12 result shape failed'}
    $subjectOrder='sourceId,relativePath,containerKind,sizeBytes,sp01Partition,sp02Partition,observationIds,evidence,publicExtraction';if((@($integrated.fileSubjects[0].PSObject.Properties.Name)-join ',') -ne $subjectOrder){throw 'file subject shape failed'}
    $resolvedOrder='sourceId,relativePath,parseStatus,observationIds,evidence';if((@($integrated.resolvedFileResults[0].PSObject.Properties.Name)-join ',') -ne $resolvedOrder){throw 'resolved row shape failed'}
    $coverageOrder='catalogedFileCount,catalogedBytes,catalogedContainerCount,catalogedContainerBytes,nonContainerFileCount,nonContainerFileBytes,fileDiscoverySubjectCount,fileDiscoverySubjectBytes,notAttemptedFileCount,notAttemptedFileBytes,parsedFileCount,parsedFileBytes,opaqueFileCount,opaqueFileBytes,failedFileCount,failedFileBytes,fileDiscoveryConflictFileCount,fileDiscoveryConflictFileBytes,notAttemptedContainerCount,notAttemptedContainerBytes,parsedContainerCount,parsedContainerBytes,opaqueContainerCount,opaqueContainerBytes,failedContainerCount,failedContainerBytes,fileDiscoveryConflictContainerCount,fileDiscoveryConflictContainerBytes';if((@($integrated.coverage.PSObject.Properties.Name)-join ',') -ne $coverageOrder){throw 'coverage shape failed'}
    if($integrated.fileSubjects[0].observationIds.Count -ne 6 -or $integrated.fileSubjects[0].evidence.Count -ne 6 -or $integrated.resolvedFileResults[0].parseStatus -ne 'CrossToolVerified' -or $integrated.coverage.catalogedBytes -ne 4096 -or $integrated.coverage.parsedContainerBytes -ne 4096){throw 'integrated positive vector failed'}
    $unknownInput=Input @([pscustomobject][ordered]@{rowIndex=0;observation=(Clone $r1)}) Absent @() $null;$unknownInput.objectObservationArtifact.artifactSha256='48a9fa5d4097e7050f57024e141d0b3e61fea9302dbdc628c82e377932fa9bc7';$unknownInput.objectObservationArtifact.acceptedRows[0].observation.containerRelativePath='SourceCorpus/PcInstall/missing.bundle';$unknown=Run $unknownInput
    if($unknown.inputFailures[0].subjectId -ne 'raw-row-sha256:f71bd05130b39d6bfb20c8e1348638adf82e926bf35ccbcc8c746d2e13b82946' -or $unknown.inputFailures[0].attribution -notlike 'FT-05:*' -or -not $unknown.outputsSuppressed){throw 'AR-I07 unknown-target provenance failed'}
    $unparseable=Run (Input @() Unparseable @() 'f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a');if($unparseable.inputFailures[0].subjectId -ne 'AR-I08' -or $unparseable.inputFailures.Count -ne 1){throw 'AR-I08 document ownership failed'}
    $newKind=Input @() Absent @() $null;$newKind.c1Files[0].containerKind='FutureContainer';if((Run $newKind).fileSubjects[0].sp01Partition -ne 'Container'){throw 'arbitrary kind classification failed'}
    $nonContainer=Input @() Absent @() $null;$nonContainer.c1Files[0].containerKind='DirectMedia';$nonContainerResult=Run $nonContainer;if($nonContainerResult.fileSubjects[0].sp01Partition -ne 'NonContainer' -or $nonContainerResult.coverage.nonContainerFileBytes -ne 4096){throw 'NonContainer classification failed'}
    $dual=Input @() Absent @() $null;$dual.c1Files[0].status.extraction='Opaque';$dualResult=Run $dual;if($dualResult.inputFailures[0].attribution -ne 'FT-02:AR-I02' -or -not $dualResult.outputsSuppressed){throw 'dual extraction fail-closed failed'}
    $collision=Input @() Absent @() $null;$other=Clone $collision.c1Files[0];$other.relativePath=$other.relativePath.ToUpperInvariant();$collision.c1Files=@($collision.c1Files[0],$other);$collisionResult=Run $collision;if($collisionResult.inputFailures.Count -ne 1 -or $collisionResult.inputFailures[0].attribution -ne 'FT-02:AR-I02'){throw 'case-collision fail-closed failed'}
    foreach($vector in @($none,$single,$cross,$opaqueResult,$failedResult,$conflict,$integrated)){$c=$vector.coverage;if($c.catalogedFileCount -ne ($c.catalogedContainerCount+$c.nonContainerFileCount) -or $c.catalogedBytes -ne ($c.catalogedContainerBytes+$c.nonContainerFileBytes) -or $c.fileDiscoverySubjectCount -ne ($c.notAttemptedFileCount+$c.parsedFileCount+$c.opaqueFileCount+$c.failedFileCount+$c.fileDiscoveryConflictFileCount) -or $c.fileDiscoverySubjectBytes -ne ($c.notAttemptedFileBytes+$c.parsedFileBytes+$c.opaqueFileBytes+$c.failedFileBytes+$c.fileDiscoveryConflictFileBytes) -or $c.catalogedContainerCount -ne ($c.notAttemptedContainerCount+$c.parsedContainerCount+$c.opaqueContainerCount+$c.failedContainerCount+$c.fileDiscoveryConflictContainerCount) -or $c.catalogedContainerBytes -ne ($c.notAttemptedContainerBytes+$c.parsedContainerBytes+$c.opaqueContainerBytes+$c.failedContainerBytes+$c.fileDiscoveryConflictContainerBytes)){throw 'SP-01/SP-02 conservation failed'}}
    "status=Passed";"sp01FileCount=$($integrated.coverage.catalogedFileCount)";"sp01Bytes=$($integrated.coverage.catalogedBytes)";"sp02VectorCount=6";"integratedObservationIdCount=$($integrated.fileSubjects[0].observationIds.Count)";"integratedEvidenceCount=$($integrated.fileSubjects[0].evidence.Count)";"publicExtraction=$($integrated.resolvedFileResults[0].parseStatus)";"conflictId=$($conflict.fileDiscoveryConflicts[0].fileDiscoveryConflictId)";"conflictRecordId=$($conflict.inputFailures[0].recordId)";"unknownTargetHI02=$($unknown.inputFailures[0].subjectId)";return
}

$p0Entries = @(
    [pscustomobject]@{ path = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json'; sha256 = '548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac' }
    [pscustomobject]@{ path = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json'; sha256 = 'acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462' }
    [pscustomobject]@{ path = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json'; sha256 = 'c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1' }
    [pscustomobject]@{ path = 'docs/asset-migration/schemas/source-corpus-ledger.schema.json'; sha256 = 'b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c' }
    [pscustomobject]@{ path = 'docs/asset-migration/schemas/status-vocabulary.json'; sha256 = '88314c4c150563cab2f08c4a0692bc012b0c8e6f403d5cf2a355cf1688831444' }
    [pscustomobject]@{ path = 'docs/asset-migration/schemas/root-gate-summary.schema.json'; sha256 = '45a094d25b2e221f46f4f4948c0dae188d3a9a77aa520243f02fd8242038c449' }
)

if ($Case -ceq 'GitAdapter') {
    $adapter = Invoke-C2GitFreshnessAdapter -RepositoryRoot (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    if ($adapter.status -cne 'Passed') { throw "Git adapter positive failed: attribution=$($adapter.failureAttribution) reason=$($adapter.reason) calls=$($adapter.gitInspectionProcessCount) start=$($adapter.startCommitOid) end=$($adapter.endCommitOid) stderr=$(@($adapter.commandTrace)[0].stderr)" }
    if ($adapter.gitInspectionProcessCount -ne 7) { throw "Git adapter call count expected=7 actual=$($adapter.gitInspectionProcessCount)" }
    if (-not $adapter.headStable -or $adapter.startCommitOid -cne $adapter.endCommitOid) { throw 'Git adapter HEAD stability failed.' }
    if ((@($adapter.commandTrace).Count) -ne 7) { throw 'Git adapter trace count invalid.' }
    if (@($adapter.commandTrace)[0].arguments[-1] -cne 'HEAD^{commit}' -or @($adapter.commandTrace)[6].arguments[-1] -cne 'HEAD^{commit}') { throw 'Git adapter HEAD grammar invalid.' }
    if (@($adapter.commandTrace)[3].stdoutByteCount -ne 0) { throw 'Optional-absence call returned bytes.' }
    foreach ($call in $adapter.commandTrace) {
        if (-not $call.environmentValid) { throw "Unsanitized child environment at call $($call.callNumber)" }
        if ($call.useShellExecute -or -not $call.redirectStandardOutput -or -not $call.redirectStandardError) { throw "Unsafe process mode at call $($call.callNumber)" }
    }
    $startFailure = Test-C2GitAdapterLifecycle -FailurePoint Call1StartFailure
    $middleFailure = Test-C2GitAdapterLifecycle -FailurePoint Call3InvalidOutput
    $finalFailure = Test-C2GitAdapterLifecycle -FailurePoint Call7InvalidOutput
    $changedHead = Test-C2GitAdapterLifecycle -FailurePoint ChangedHead
    $policyFailure = Test-C2GitAdapterLifecycle -FailurePoint PrelaunchCall2
    foreach($caseResult in @($startFailure,$middleFailure,$finalFailure,$changedHead)){
        if($caseResult.owner -cne 'FT-03' -or $caseResult.reason -cne 'StaleFingerprint' -or $null -ne $caseResult.discoveryInputFingerprint){throw "FT-03 lifecycle ownership failed: $($caseResult.case)"}
    }
    if($policyFailure.owner -cne 'FT-13' -or $policyFailure.reason -cne 'HeavyOperationAttempted' -or $policyFailure.gitInspectionProcessCount -ne 1){throw 'FT-13 prelaunch ownership/count failed.'}
    if($startFailure.gitInspectionProcessCount -ne 0 -or $null -ne $startFailure.startCommitOid -or $null -ne $startFailure.endCommitOid -or $null -ne $startFailure.headStable){throw 'Call1 start failure vector invalid.'}
    if($middleFailure.gitInspectionProcessCount -ne 4 -or -not $middleFailure.headStable){throw 'Intermediate failure/final-revalidation vector invalid.'}
    if($finalFailure.gitInspectionProcessCount -ne 7 -or $null -ne $finalFailure.endCommitOid -or $null -ne $finalFailure.headStable){throw 'Final failure vector invalid.'}
    if($changedHead.gitInspectionProcessCount -ne 7 -or $changedHead.headStable -ne $false){throw 'Changed HEAD vector invalid.'}
    "status=Passed"
    "gitInspectionProcessCount=$($adapter.gitInspectionProcessCount)"
    "startCommitOid=$($adapter.startCommitOid)"
    "endCommitOid=$($adapter.endCommitOid)"
    "headStable=$($adapter.headStable)"
    "commandTraceCount=$(@($adapter.commandTrace).Count)"
    "sanitizedEnvironmentCallCount=$(@($adapter.commandTrace | Where-Object environmentValid).Count)"
    "rawBlobCallCount=$(@($adapter.commandTrace | Where-Object rawBlobCapture).Count)"
    "call1StartFailure=Passed"
    "intermediateFailureFinalRevalidation=Passed"
    "call7Failure=Passed"
    "changedHead=Passed"
    "prelaunchFT13=Passed"
    return
}

if ($Case -in @('Integration','FileFixtureIntake')) {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $result = Invoke-C2DiscoveryIntakeGate -RepositoryRoot $repositoryRoot
    if ($result.O2.status -cne 'Failed' -or $result.O1.decision.failureAttribution -notlike 'FT-05:*') { throw "Integration SP-03a failure projection invalid: $($result.O1.decision.failureAttribution)" }
    $expectedCounts = [ordered]@{
        registeredArtifactCount=11; readArtifactCount=10; requiredArtifactCount=6; presentOptionalArtifactCount=4; absentOptionalArtifactCount=1
        failedRegistrySlotCount=0; acceptedArtifactCount=10; failedArtifactCount=0; contractCheckCount=5; acceptedCheckCount=5
        failedCheckCount=0; notEvaluatedCheckCount=0; inputSubjectCount=24; acceptedInputSubjectCount=21; inputFailureCount=2
        excludedInputSubjectCount=1; notEvaluatedInputSubjectCount=0; gitInspectionProcessCount=7; heavyProcessCount=0
        realAssetReadCount=0; createdExtractedCount=0; createdImportedCount=0
    }
    foreach($entry in $expectedCounts.GetEnumerator()) { if($result.O2.($entry.Key) -ne $entry.Value){throw "$($entry.Key) expected=$($entry.Value) actual=$($result.O2.($entry.Key))"} }
    if($result.O1.artifactStates.Count -ne 11 -or $result.O1.contractChecks.Count -ne 5 -or $result.O1.inputSuppressions.Count -ne 0){throw 'Integration O1 row counts invalid.'}
    if($null -ne $result.O2.discoveryInputFingerprint){throw 'D9 not suppressed by SP-03a failure.'}
    if($result.O2.startCommitOid -cne $result.O2.endCommitOid -or -not $result.O2.headStable){throw 'Integration HEAD stability failed.'}
    if(($result.O1.contractChecks.status -join ',') -cne 'Accepted,Accepted,Accepted,Accepted,Accepted'){throw 'Integration check vector invalid.'}
    $d9Entries=@($result.O1.artifactStates|Where-Object readStatus -eq Accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})
    $independentD9=Get-C2DiscoveryInputFingerprint -Entries $d9Entries
    if($independentD9 -cne 'f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab'){throw "Independent D9 mismatch: $independentD9"}
    if($result.O2.objectObservationRowCount -ne 6 -or $result.O2.acceptedObjectObservationRowCount -ne 4 -or $result.O2.rejectedObjectObservationRowCount -ne 1 -or $result.O2.excludedObjectObservationRowCount -ne 1 -or $result.O1.inputFailures.Count -ne 2 -or $result.O1.inputExclusions.Count -ne 1 -or $result.O1.mergedObjects.Count -ne 1 -or $result.O1.observationConflicts.Count -ne 1 -or $result.O1.publicObjectCores.Count -ne 1){throw 'Integrated SP-03/SP-04 accounting vector invalid'}
    if($result.O1.configurationCandidates.Count-ne1-or$result.O1.configurationConflicts.Count-ne0-or$result.O1.configurationCandidates[0].configurationCandidateId-cne'config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564'-or$result.O2.configurationDiscoverySubjectCount-ne1-or$result.O2.configurationCandidateCount-ne1-or$result.O2.configurationConflictCount-ne0-or$result.O2.parsedConfigurationCount-ne1){throw 'Integrated SP-05 vector invalid'}
    if($result.O1.dispatchInputFacts.Count-ne1-or(@($result.O1.dispatchInputFacts[0].PSObject.Properties.Name)-join',')-cne'assetObjectId,sp04Partition,privateConfigurationDisposition,configurationCandidateId'-or$result.O1.dispatchInputFacts[0].sp04Partition-cne'Classified'-or$result.O1.dispatchInputFacts[0].configurationCandidateId-cne'config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564'){throw 'Integrated SP-07 private join derivation invalid'}
    if($result.O1.dispatchRows.Count-ne0-or$result.O2.dispatchEligibleObjectCount-ne0-or$result.O2.assignedObjectCount-ne0-or$result.O2.retainedForDiagnosisObjectCount-ne0-or$result.O2.configurationOnlyObjectCount-ne0-or$result.O2.audioObjectCount-ne0-or$result.O2.environmentObjectCount-ne0-or$result.O2.actorObjectCount-ne0-or$result.O2.uiObjectCount-ne0-or$result.O2.effectsObjectCount-ne0){throw 'Integrated SP-07 failure suppression/conservation invalid'}
    $i08=@($result.O1.artifactStates|Where-Object artifactId -eq 'AR-I08')[0]
    if($i08.worktreeSha256 -cne 'f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a' -or $i08.commitBlobSha256 -cne $i08.worktreeSha256 -or $i08.manifestSha256 -cne $i08.worktreeSha256){throw 'AR-I08 exact binding invalid.'}
    $i10=@($result.O1.artifactStates|Where-Object artifactId -eq 'AR-I10')[0]
    if($i10.worktreeSha256 -cne '4b4b65de4a2ec12dfc1cbd09929bdc66d5aa1cf8345bd161043d694b62cb2ea8'){throw 'AR-I10 exact hash invalid.'}
    $artifactRowOrder='artifactId,path,requirement,presence,readStatus,worktreeSha256,commitBlobSha256,manifestSha256,identityStatus,freshnessStatus,evidence'
    foreach($row in $result.O1.artifactStates){if((@($row.PSObject.Properties.Name)-join ',') -cne $artifactRowOrder){throw "Artifact row shape invalid: $($row.artifactId)"}}
    $checkRowOrder='subjectId,status,attribution,evidence,prerequisites'
    foreach($row in $result.O1.contractChecks){if((@($row.PSObject.Properties.Name)-join ',') -cne $checkRowOrder){throw "Check row shape invalid: $($row.subjectId)"}}
    $freshness=$result.O1.contractChecks[2]
    $expectedFreshnessEvidence=[Collections.Generic.List[string]]::new();foreach($state in @($result.O1.artifactStates|Where-Object readStatus -in @('Accepted','Failed'))){$expectedFreshnessEvidence.Add([string]$state.path)};$expectedFreshnessEvidence.Sort([StringComparer]::Ordinal)
    if(($freshness.evidence -join "`n") -cne ($expectedFreshnessEvidence -join "`n")){throw 'Freshness evidence vector invalid.'}
    if(($freshness.prerequisites -join ',') -cne 'AR-I01,AR-I02,AR-I03,AR-I04,AR-I05,AR-I06,AR-I07,AR-I08,AR-I10,AR-I11,GitAdapter:EndHead,GitAdapter:StartCommitOid'){throw 'Freshness prerequisites invalid.'}
    if($result.O2.inputObservationCount-ne8-or$result.O2.acceptedInputObservationCount-ne6-or$result.O2.rejectedInputObservationCount-ne1-or$result.O2.excludedInputCount-ne1-or$result.O2.contractFailureRecordCount-ne0-or$result.O2.fileDiscoveryConflictRecordCount-ne0-or$result.O2.observationConflictRecordCount-ne1-or$result.O2.configurationConflictRecordCount-ne0-or$result.O2.canonicalConflictRecordCount-ne0){throw 'Integration SP-08 complete accounting vector invalid.'}
    "status=$($result.O2.status)"
    "issueCount=$($result.O2.issueCount)"
    "registeredArtifactCount=$($result.O2.registeredArtifactCount)"
    "readArtifactCount=$($result.O2.readArtifactCount)"
    "absentOptionalArtifactCount=$($result.O2.absentOptionalArtifactCount)"
    "acceptedArtifactCount=$($result.O2.acceptedArtifactCount)"
    "contractCheckCount=$($result.O2.contractCheckCount)"
    "acceptedCheckCount=$($result.O2.acceptedCheckCount)"
    "notEvaluatedCheckCount=$($result.O2.notEvaluatedCheckCount)"
    "inputSubjectCount=$($result.O2.inputSubjectCount)"
    "acceptedInputSubjectCount=$($result.O2.acceptedInputSubjectCount)"
    "inputFailureCount=$($result.O2.inputFailureCount)"
    "gitInspectionProcessCount=$($result.O2.gitInspectionProcessCount)"
    "heavyProcessCount=$($result.O2.heavyProcessCount)"
    "realAssetReadCount=$($result.O2.realAssetReadCount)"
    "createdExtractedCount=$($result.O2.createdExtractedCount)"
    "createdImportedCount=$($result.O2.createdImportedCount)"
    "startCommitOid=$($result.O2.startCommitOid)"
    "endCommitOid=$($result.O2.endCommitOid)"
    "headStable=$($result.O2.headStable)"
    "discoveryInputFingerprint=$($result.O2.discoveryInputFingerprint)"
    "independentD9=$independentD9"
    "artifactRowShapeCount=$($result.O1.artifactStates.Count)"
    "checkRowShapeCount=$($result.O1.contractChecks.Count)"
    return
}

if ($Case -ceq 'FailureState') {
    $oid='1111111111111111111111111111111111111111'
    $failureRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $call1Result=$loadedModule.Invoke({param($root)Test-C2InjectedGateVector -RepositoryRoot $root -Vector Call1StartFailure},@($failureRoot))[0]
    if($call1Result.O2.status -cne 'Failed' -or $call1Result.O2.gitInspectionProcessCount -ne 0 -or $null -ne $call1Result.O2.startCommitOid -or $null -ne $call1Result.O2.endCommitOid -or $null -ne $call1Result.O2.headStable){throw 'Call1 Failed O1/O2 vector invalid.'}
    if($call1Result.O1.inputFailures[0].attribution -cne 'FT-03:C2Check:Freshness' -or $null -ne $call1Result.O2.discoveryInputFingerprint){throw 'Call1 failure ownership invalid.'}
    if($call1Result.O2.failedRegistrySlotCount -ne 10 -or $call1Result.O2.absentOptionalArtifactCount -ne 1 -or @($call1Result.O1.artifactStates|Where-Object presence -eq Present).Count -ne 10 -or @($call1Result.O1.artifactStates|Where-Object readStatus -eq NotRead).Count -ne 11){throw 'Call1 artifact state derivation invalid.'}
    $call3Result=$loadedModule.Invoke({param($root)Test-C2InjectedGateVector -RepositoryRoot $root -Vector Call3InvalidOutput},@($failureRoot))[0]
    if($call3Result.O2.status -cne 'Failed' -or $call3Result.O2.gitInspectionProcessCount -ne 4 -or $call3Result.O2.startCommitOid -cne $oid -or $call3Result.O2.endCommitOid -cne $oid -or -not $call3Result.O2.headStable){throw 'Intermediate Failed O1/O2 vector invalid.'}
    if($call3Result.O1.inputFailures.Count -ne 1 -or $call3Result.O2.issueCount -ne 1 -or $null -ne $call3Result.O2.discoveryInputFingerprint){throw 'Intermediate failure accounting invalid.'}
    foreach($r in @($call1Result,$call3Result)){
        if($r.O2.contractCheckCount -ne ($r.O2.acceptedCheckCount+$r.O2.failedCheckCount+$r.O2.notEvaluatedCheckCount)){throw 'Failure NP-03 mismatch.'}
        if($r.O2.inputSubjectCount -ne ($r.O2.acceptedInputSubjectCount+$r.O2.inputFailureCount+$r.O2.excludedInputSubjectCount+$r.O2.notEvaluatedInputSubjectCount)){throw 'Failure NP-04 mismatch.'}
    }
    "status=Passed"
    "call1FailureStatus=$($call1Result.O2.status)"
    "call1GitInspectionProcessCount=$($call1Result.O2.gitInspectionProcessCount)"
    "call1HeadStable=$($call1Result.O2.headStable)"
    "call1PresentSlotCount=$(@($call1Result.O1.artifactStates|Where-Object presence -eq Present).Count)"
    "call1FailedRegistrySlotCount=$($call1Result.O2.failedRegistrySlotCount)"
    "intermediateFailureStatus=$($call3Result.O2.status)"
    "intermediateGitInspectionProcessCount=$($call3Result.O2.gitInspectionProcessCount)"
    "intermediateFinalHeadRevalidated=$($call3Result.O2.headStable)"
    "failureFingerprintSuppressed=$($null -eq $call3Result.O2.discoveryInputFingerprint)"
    return
}

if ($Case -ceq 'ValidatorMutations') {
    $repositoryRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    function Invoke-PrivateVector {param([string]$Vector)$loadedModule.Invoke({param($root,$name)Test-C2InjectedGateVector -RepositoryRoot $root -Vector $name},@($repositoryRoot,$Vector))[0]}
    $vectors=@(
        [pscustomobject]@{name='ledgerNestedSchema';subject='AR-I02';result=(Invoke-PrivateVector LedgerNestedInvalid)},
        [pscustomobject]@{name='vocabularyContent';subject='AR-I05';result=(Invoke-PrivateVector VocabularyInvalid)},
        [pscustomobject]@{name='rootSchemaSemantics';subject='AR-I06';result=(Invoke-PrivateVector RootSchemaInvalid)},
        [pscustomobject]@{name='rootSchemaRequiredBinding';subject='AR-I06';result=(Invoke-PrivateVector RootSchemaRequiredInvalid)},
        [pscustomobject]@{name='rootSchemaPropertyDefinition';subject='AR-I06';result=(Invoke-PrivateVector RootSchemaPropertyInvalid)},
        [pscustomobject]@{name='rootSchemaDefsDefinition';subject='AR-I06';result=(Invoke-PrivateVector RootSchemaDefInvalid)},
        [pscustomobject]@{name='rootSchemaMinimumType';subject='AR-I06';result=(Invoke-PrivateVector RootSchemaMinimumInvalid)},
        [pscustomobject]@{name='manifestShape';subject='AR-I10';result=(Invoke-PrivateVector ManifestShapeInvalid)},
        [pscustomobject]@{name='observationHI03';subject='AR-I07';result=(Invoke-PrivateVector ObservationHI03Invalid)},
        [pscustomobject]@{name='approvalHI15';subject='AR-I11';result=(Invoke-PrivateVector ApprovalHI15Invalid)}
    )
    foreach($vector in $vectors){
        $r=$vector.result
        if($r.O2.status -cne 'Failed' -or $r.O2.issueCount -ne 1 -or $r.O2.gitInspectionProcessCount -ne 7 -or -not $r.O2.headStable -or $null -ne $r.O2.discoveryInputFingerprint){throw "$($vector.name) failure vector invalid"}
        if($r.O1.inputFailures[0].attribution -cne "FT-02:$($vector.subject)" -or $r.O1.contractChecks[2].status -cne 'NotEvaluated'){throw "$($vector.name) ownership/suppression invalid"}
        if($r.O2.readArtifactCount -ne 10 -or $r.O2.acceptedArtifactCount -ne 9 -or $r.O2.failedArtifactCount -ne 1 -or $r.O2.failedRegistrySlotCount -ne 1 -or $r.O1.snapshotId -cne 'snapshot-pc-install-001'){throw "$($vector.name) actual artifact accounting invalid"}
        $failedArtifact=@($r.O1.artifactStates|Where-Object readStatus -eq Failed)
        if($failedArtifact.Count -ne 1 -or $failedArtifact[0].artifactId -cne $vector.subject -or $failedArtifact[0].worktreeSha256 -cnotmatch '^[0-9a-f]{64}$'){throw "$($vector.name) failed artifact state invalid"}
    }
    "status=Passed"
    "ledgerNestedSchemaMutation=Passed"
    "vocabularyContentMutation=Passed"
    "rootSchemaSemanticsMutation=Passed"
    "rootSchemaRequiredBindingMutation=Passed"
    "rootSchemaPropertyDefinitionMutation=Passed"
    "rootSchemaDefsDefinitionMutation=Passed"
    "rootSchemaMinimumTypeMutation=Passed"
    "manifestShapeMutation=Passed"
    "observationHI03Mutation=Passed"
    "approvalHI15Mutation=Passed"
    "mutationFinalHeadRevalidationCount=7"
    return
}

$actual = Get-C2DiscoveryInputFingerprint -Entries $p0Entries
$expected = '01de12cfc14c5779aaa6b2827f73ae76a5e750d2d28cc0e856f685eb5bbd4c3d'
if ($actual -cne $expected) {
    throw "P0 digest mismatch: expected=$expected actual=$actual"
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Label)
    if (($Actual -is [string]) -or ($Expected -is [string])) {
        if ([string]$Actual -cne [string]$Expected) { throw "$Label expected=<$Expected> actual=<$Actual>" }
    } elseif ($Actual -ne $Expected) { throw "$Label expected=<$Expected> actual=<$Actual>" }
}

function Copy-MemoryValue { param($Value) $Value | ConvertTo-Json -Depth 20 | ConvertFrom-Json -Depth 20 }

$paths = @(
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json',
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json',
    'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json',
    'docs/asset-migration/schemas/source-corpus-ledger.schema.json',
    'docs/asset-migration/schemas/status-vocabulary.json',
    'docs/asset-migration/schemas/root-gate-summary.schema.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json'
)
$requirements = @('Required','Required','Required','Required','Required','Required','ConditionalInput','ConditionalInput','ConditionalInput','ConditionalAuthority','ConditionalApproval')
$ids = 1..11 | ForEach-Object { 'AR-I{0:d2}' -f $_ }
$shaValues = @($p0Entries.sha256) + @(
    '50616dd29ec968121675658ba8aa1c8ba78d038034ad3824453f64fd5050d63c',
    'f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a',
    $null,
    '4b4b65de4a2ec12dfc1cbd09929bdc66d5aa1cf8345bd161043d694b62cb2ea8',
    '50510b54502e2747d3f31c9032a21ffdd2eeb24c7121c8f132b7fa3a3c562820'
)
$facts = for ($i=0; $i -lt 11; $i++) {
    $present = $i -notin @(8)
    [pscustomobject][ordered]@{
        artifactId=$ids[$i]; path=$paths[$i]; requirement=$requirements[$i]; presence=if($present){'Present'}else{'Absent'}
        worktreeSha256=if($present){$shaValues[$i]}else{$null}
        commitBlobSha256=if($i -in @(6,7,9,10)){$shaValues[$i]}else{$null}
        manifestSha256=if($i -in @(6,7,10)){$shaValues[$i]}else{$null}
    }
}
$handoff = [pscustomobject][ordered]@{ snapshotId='snapshot-pc-install-001'; ledgerPath=$paths[1]; summaryPath=$paths[2] }
$oid = '49f2426b19d27d7e3a503ff7e52c7cca5e1ef393'
$positive = Invoke-C2PureDiscoveryIntake -ArtifactFacts $facts -HandoffFact $handoff -StartCommitOid $oid -EndCommitOid $oid

$o1Order = 'schemaVersion,snapshotId,startCommitOid,endCommitOid,headStable,discoveryInputFingerprint,artifactStates,contractChecks,inputFailures,inputExclusions,inputSuppressions,decision'
$o2Order = 'status,issueCount,registeredArtifactCount,readArtifactCount,requiredArtifactCount,presentOptionalArtifactCount,absentOptionalArtifactCount,failedRegistrySlotCount,acceptedArtifactCount,failedArtifactCount,contractCheckCount,acceptedCheckCount,failedCheckCount,notEvaluatedCheckCount,inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,excludedInputSubjectCount,notEvaluatedInputSubjectCount,gitInspectionProcessCount,heavyProcessCount,realAssetReadCount,createdExtractedCount,createdImportedCount,startCommitOid,endCommitOid,headStable,discoveryInputFingerprint,nextAllowedAction'
Assert-Equal (@($positive.O1.PSObject.Properties.Name) -join ',') $o1Order 'O1 property order'
Assert-Equal (@($positive.O2.PSObject.Properties.Name) -join ',') $o2Order 'O2 property order'
Assert-Equal $positive.O2.status Passed 'positive status'
foreach($pair in @(
    @('registeredArtifactCount',11),@('readArtifactCount',10),@('requiredArtifactCount',6),@('presentOptionalArtifactCount',4),@('absentOptionalArtifactCount',1),@('failedRegistrySlotCount',0),
    @('acceptedArtifactCount',10),@('failedArtifactCount',0),@('contractCheckCount',5),@('acceptedCheckCount',3),@('failedCheckCount',0),@('notEvaluatedCheckCount',2),
    @('inputSubjectCount',15),@('acceptedInputSubjectCount',13),@('inputFailureCount',0),@('excludedInputSubjectCount',0),@('notEvaluatedInputSubjectCount',2),
    @('gitInspectionProcessCount',0),@('heavyProcessCount',0),@('realAssetReadCount',0),@('createdExtractedCount',0),@('createdImportedCount',0)
)) { Assert-Equal $positive.O2.($pair[0]) $pair[1] "positive $($pair[0])" }
Assert-Equal ($positive.O1.artifactStates.Count) 11 'artifact slot count'
Assert-Equal ($positive.O1.contractChecks.Count) 5 'check slot count'
Assert-Equal (($positive.O1.artifactStates.artifactId) -join ',') ($ids -join ',') 'artifact slot order'
Assert-Equal (($positive.O1.contractChecks.status) -join ',') 'Accepted,Accepted,Accepted,NotEvaluated,NotEvaluated' 'check states'
Assert-Equal $positive.O1.inputSuppressions[0].recordId 'accounting-sha256:6d540e7fefd265ddef57b835e7bfb8894085d609419b3ac98b2268876f006e1c' 'Conservation suppression identity'
Assert-Equal $positive.O1.inputSuppressions[1].recordId 'accounting-sha256:212ec1d5b7ffc164817068a9227f8c7d847dc091c517c41db4b4270236294016' 'Projection suppression identity'
Assert-Equal $positive.O2.registeredArtifactCount ($positive.O2.readArtifactCount+$positive.O2.absentOptionalArtifactCount+$positive.O2.failedRegistrySlotCount) 'NP-01'
Assert-Equal $positive.O2.readArtifactCount ($positive.O2.acceptedArtifactCount+$positive.O2.failedArtifactCount) 'NP-02'
Assert-Equal $positive.O2.contractCheckCount ($positive.O2.acceptedCheckCount+$positive.O2.failedCheckCount+$positive.O2.notEvaluatedCheckCount) 'NP-03'
Assert-Equal $positive.O2.inputSubjectCount ($positive.O2.acceptedInputSubjectCount+$positive.O2.inputFailureCount+$positive.O2.excludedInputSubjectCount+$positive.O2.notEvaluatedInputSubjectCount) 'NP-04'
Assert-Equal $positive.O2.issueCount $positive.O2.inputFailureCount 'NP-05'

$badHandoff = Copy-MemoryValue $handoff; $badHandoff.ledgerPath='wrong/path.json'
$ft01=Invoke-C2PureDiscoveryIntake $facts $badHandoff $oid $oid
Assert-Equal $ft01.O1.inputFailures[0].attribution 'FT-01:C2Check:C1Handoff' 'FT-01 owner'
Assert-Equal $ft01.O1.contractChecks[2].status NotEvaluated 'FT-01 freshness suppression'
Assert-Equal $ft01.O1.discoveryInputFingerprint $null 'FT-01 fingerprint suppression'

$badShape=Copy-MemoryValue $facts; $badShape[9].PSObject.Properties.Remove('manifestSha256')
$ft02=Invoke-C2PureDiscoveryIntake $badShape $handoff $oid $oid
Assert-Equal $ft02.O1.inputFailures[0].attribution 'FT-02:AR-I10' 'FT-02 owner'
Assert-Equal $ft02.O1.discoveryInputFingerprint $null 'FT-02 fingerprint suppression'

$extraFacts=@(Copy-MemoryValue $facts)+@([pscustomobject][ordered]@{artifactId='AR-I12';path='unexpected/extra.json';requirement='ConditionalInput';presence='Present';worktreeSha256=('f'*64);commitBlobSha256=$null;manifestSha256=$null})
$extraResult=Invoke-C2PureDiscoveryIntake $extraFacts $handoff $oid $oid
Assert-Equal $extraResult.O2.status Failed 'extra registry slot status'
Assert-Equal $extraResult.O2.inputFailureCount 1 'extra registry slot failure count'
Assert-Equal $extraResult.O1.inputFailures[0].attribution 'FT-02:AR-I10' 'extra registry slot owner'
Assert-Equal (@($extraResult.O1.inputFailures[0].PSObject.Properties.Name)-join ',') 'recordId,subjectKind,subjectId,reasonCode,attribution,evidence' 'extra registry slot failure shape'
Assert-Equal $extraResult.O1.inputFailures[0].subjectKind RegistryShape 'extra registry slot subject kind'
Assert-Equal $extraResult.O1.inputFailures[0].subjectId 'AR-I10' 'extra registry slot subject id'
Assert-Equal $extraResult.O1.inputFailures[0].reasonCode UnexpectedRegistrySlot 'extra registry slot reason'
Assert-Equal (@($extraResult.O1.inputFailures[0].evidence)-join ',') $paths[9] 'extra registry slot portable-path evidence'
Assert-Equal ($extraResult.O1.inputFailures[0].recordId -cmatch '^accounting-sha256:[0-9a-f]{64}$') $true 'extra registry slot record identity'
Assert-Equal $extraResult.O1.contractChecks[2].status NotEvaluated 'extra registry slot freshness suppression'
Assert-Equal $extraResult.O1.discoveryInputFingerprint $null 'extra registry slot fingerprint suppression'

$duplicateFacts=Copy-MemoryValue $facts;$duplicateFacts[1]=$duplicateFacts[0]
$duplicateResult=Invoke-C2PureDiscoveryIntake $duplicateFacts $handoff $oid $oid
Assert-Equal $duplicateResult.O2.status Failed 'duplicate registry slot status'
Assert-Equal $duplicateResult.O1.inputFailures[0].attribution 'FT-02:AR-I02' 'duplicate registry slot owner'
Assert-Equal $duplicateResult.O1.discoveryInputFingerprint $null 'duplicate registry slot fingerprint suppression'

$wrongOrderFacts=Copy-MemoryValue $facts;$swap=$wrongOrderFacts[0];$wrongOrderFacts[0]=$wrongOrderFacts[1];$wrongOrderFacts[1]=$swap
$wrongOrderResult=Invoke-C2PureDiscoveryIntake $wrongOrderFacts $handoff $oid $oid
Assert-Equal $wrongOrderResult.O2.status Failed 'wrong-order registry status'
Assert-Equal $wrongOrderResult.O2.inputFailureCount 2 'wrong-order registry failure count'
Assert-Equal (($wrongOrderResult.O1.inputFailures.attribution)-join ',') 'FT-02:AR-I01,FT-02:AR-I02' 'wrong-order registry owners'
Assert-Equal $wrongOrderResult.O1.discoveryInputFingerprint $null 'wrong-order registry fingerprint suppression'

$badPath=Copy-MemoryValue $facts; $badPath[6].path='../object-observations.json'
$ft04=Invoke-C2PureDiscoveryIntake $badPath $handoff $oid $oid
Assert-Equal $ft04.O1.inputFailures[0].attribution 'FT-04:AR-I07' 'FT-04 owner'
Assert-Equal $ft04.O1.discoveryInputFingerprint $null 'FT-04 fingerprint suppression'

$ft15=Invoke-C2PureDiscoveryIntake $facts $handoff $oid $oid -FreshnessPrerequisiteAvailable:$false
Assert-Equal $ft15.O2.issueCount 0 'FT-15 issue count'
Assert-Equal $ft15.O2.inputFailureCount 0 'FT-15 failure count'
Assert-Equal $ft15.O1.contractChecks[2].status NotEvaluated 'FT-15 freshness status'
Assert-Equal $ft15.O1.inputSuppressions.Count 3 'FT-15 suppression count'

foreach($oidVector in @(
    [pscustomobject]@{name='both missing';start=$null;end=$null;head=$null},
    [pscustomobject]@{name='start missing';start=$null;end=$oid;head=$null},
    [pscustomobject]@{name='end missing';start=$oid;end=$null;head=$null},
    [pscustomobject]@{name='start invalid';start='not-an-oid';end=$oid;head=$null},
    [pscustomobject]@{name='end invalid';start=$oid;end='not-an-oid';head=$null}
)){
    $oidResult=Invoke-C2PureDiscoveryIntake $facts $handoff $oidVector.start $oidVector.end
    Assert-Equal $oidResult.O2.status Failed "$($oidVector.name) OID status"
    Assert-Equal $oidResult.O2.issueCount 1 "$($oidVector.name) OID failure count"
    Assert-Equal $oidResult.O2.headStable $oidVector.head "$($oidVector.name) headStable"
    Assert-Equal $oidResult.O1.inputFailures[0].attribution 'FT-03:C2Check:Freshness' "$($oidVector.name) OID owner"
    Assert-Equal $oidResult.O1.contractChecks[2].status Failed "$($oidVector.name) freshness status"
    Assert-Equal $oidResult.O1.discoveryInputFingerprint $null "$($oidVector.name) fingerprint suppression"
}

$requiredAbsent=Copy-MemoryValue $facts; $requiredAbsent[0].presence='Absent';$requiredAbsent[0].worktreeSha256=$null
$requiredAbsentResult=Invoke-C2PureDiscoveryIntake $requiredAbsent $handoff $oid $oid
Assert-Equal $requiredAbsentResult.O2.status Failed 'required absence status'
Assert-Equal $requiredAbsentResult.O1.artifactStates[0].readStatus Failed 'required absence slot state'
Assert-Equal $requiredAbsentResult.O1.inputFailures[0].attribution 'FT-03:C2Check:Freshness' 'required absence owner'
Assert-Equal $requiredAbsentResult.O2.registeredArtifactCount ($requiredAbsentResult.O2.readArtifactCount+$requiredAbsentResult.O2.absentOptionalArtifactCount+$requiredAbsentResult.O2.failedRegistrySlotCount) 'required absence NP-01'
Assert-Equal $requiredAbsentResult.O2.inputSubjectCount ($requiredAbsentResult.O2.acceptedInputSubjectCount+$requiredAbsentResult.O2.inputFailureCount+$requiredAbsentResult.O2.excludedInputSubjectCount+$requiredAbsentResult.O2.notEvaluatedInputSubjectCount) 'required absence NP-04'

$freshnessFalse=Copy-MemoryValue $facts;$freshnessFalse[0].worktreeSha256='ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
$freshnessFalseResult=Invoke-C2PureDiscoveryIntake $freshnessFalse $handoff $oid $oid
Assert-Equal $freshnessFalseResult.O1.inputFailures[0].attribution 'FT-03:C2Check:Freshness' 'freshness fact owner'
Assert-Equal $freshnessFalseResult.O1.contractChecks[2].attribution 'FT-03:C2Check:Freshness' 'freshness check attribution'

$manifestShape=Copy-MemoryValue $facts;$manifestShape[9].PSObject.Properties.Remove('manifestSha256')
$manifestShapeResult=Invoke-C2PureDiscoveryIntake $manifestShape $handoff $oid $oid
Assert-Equal $manifestShapeResult.O1.contractChecks[2].status NotEvaluated 'manifest FT-15 freshness status'
Assert-Equal $manifestShapeResult.O1.contractChecks[2].attribution 'FT-15:C2Check:Freshness' 'manifest FT-15 attribution'

$twoFailures=Copy-MemoryValue $facts
$twoFindings=@([pscustomobject]@{artifactId='AR-I04';transition='FT-02';reason='InvalidSchema';evidence=@($paths[3])},[pscustomobject]@{artifactId='AR-I05';transition='FT-02';reason='InvalidSchema';evidence=@($paths[4])})
$twoFailureResult=Invoke-C2PureDiscoveryIntake $twoFailures $handoff $oid $oid -ValidationFindings $twoFindings
Assert-Equal $twoFailureResult.O1.inputFailures.Count 2 'independent failure accounting count'
Assert-Equal $twoFailureResult.O2.issueCount 2 'independent issue count'

function Get-AstViolations {
    param([Management.Automation.Language.Ast]$Ast)
    $forbiddenCommands = @('Get-Content','Set-Content','Add-Content','Clear-Content','New-Item','Copy-Item','Move-Item','Remove-Item','Out-File','Get-ChildItem','Test-Path','Get-Item','Get-FileHash','Start-Process','Invoke-Item')
    $violations=[Collections.Generic.List[string]]::new()
    foreach($command in $Ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst]},$true)){
        $name=$command.GetCommandName()
        if($null -eq $name){$violations.Add('dynamic-command')} elseif($forbiddenCommands -contains $name){$violations.Add("command:$name")}
    }
    foreach($member in $Ast.FindAll({param($n) $n -is [Management.Automation.Language.InvokeMemberExpressionAst]},$true)){
        $text=$member.Extent.Text
        if($text -match '(?i)^(\[(System\.)?IO\.|\[Diagnostics\.Process|\$process\.(Start|WaitForExit|Dispose)|\$process\.Standard(Output|Error))'){
            $parent=$member.Parent
            while($null -ne $parent -and $parent -isnot [Management.Automation.Language.FunctionDefinitionAst]){$parent=$parent.Parent}
            $allowedByFunction=@{
                'New-C2GitProcessInfo'='^\[Diagnostics\.ProcessStartInfo\]::new\(\)$'
                'Invoke-C2GitChild'='^(\[Diagnostics\.Process\]::new\(\)|\$process\.Start\(\)|\[IO\.MemoryStream\]::new\(\)|\$process\.StandardOutput\.BaseStream\.CopyToAsync\(\$memory\)|\$process\.StandardError\.ReadToEndAsync\(\)|\$process\.WaitForExit\(\)|\$process\.Dispose\(\))$'
                'Invoke-C2GitFreshnessAdapter'='^\[IO\.Path\]::IsPathFullyQualified\(\$gitExecutable\)$'
                'Read-C2AuditedArtifactBytes'='^\[IO\.Path\]::(GetFullPath|Combine)\(.+\)$|^\[IO\.File\]::ReadAllBytes\(\$full\)$'
                'New-C2FailedIntakeResult'='^\[IO\.(Path|File)\]::(Combine|Exists)\(.+\)$'
                'Invoke-C2DiscoveryIntakeGateInternal'='^\[IO\.(Path|Directory|File)\]::(IsPathFullyQualified|Combine|Exists|ReadAllBytes)\(.+\)$'
            }
            $publicationFunctions=@('Get-C2PublicationChildPath','Write-C2DurableFile','Get-C2PublicationFileSha','Remove-C2PublicationPath','Move-C2PublicationFile','Write-C2PublicationJournal','Read-C2PublicationJournal','Invoke-C2PublicationQuarantine','Invoke-C2PublicationUnknownQuarantine','Invoke-C2PublicationRollback','Invoke-C2PublicationRecovery','Invoke-C2PublicationTransactionCore','Initialize-C2PublicationRecoveryState','Test-C2PublicationTransactionVector')
            $publicationApiPattern='^\[IO\.(Path|Directory|File)\]::(GetFullPath|Combine|GetRelativePath|GetDirectoryName|CreateDirectory|Open|Exists|ReadAllBytes|Delete|Move|GetFileName|GetDirectories|GetFiles|GetFileSystemEntries)\(.+\)$'
            $registered=$null-ne$parent-and(($allowedByFunction.ContainsKey($parent.Name)-and$text-cmatch$allowedByFunction[$parent.Name])-or($parent.Name-cin$publicationFunctions-and$text-cmatch$publicationApiPattern))
            if(-not$registered){$violations.Add("api:$text")}
        }
    }
    return [string[]]$violations
}
$tokens=$null;$errors=$null
$moduleAst=[Management.Automation.Language.Parser]::ParseInput($loadedModule.Definition,[ref]$tokens,[ref]$errors)
if($errors.Count){throw "module AST syntax errors=$($errors.Count)"}
$moduleViolations=@(Get-AstViolations $moduleAst)
$harnessViolations=@(Get-AstViolations $MyInvocation.MyCommand.ScriptBlock.Ast)
if($moduleViolations.Count -or $harnessViolations.Count){throw "AST violations: module=$($moduleViolations -join '|') harness=$($harnessViolations -join '|')"}

"status=Passed"
"p0Digest=$actual"
"observationArtifactSlotCount=$($positive.O1.artifactStates.Count)"
"contractCheckCount=$($positive.O2.contractCheckCount)"
"acceptedCheckCount=$($positive.O2.acceptedCheckCount)"
"notEvaluatedCheckCount=$($positive.O2.notEvaluatedCheckCount)"
"inputSubjectCount=$($positive.O2.inputSubjectCount)"
"acceptedInputSubjectCount=$($positive.O2.acceptedInputSubjectCount)"
"inputFailureCount=$($positive.O2.inputFailureCount)"
"ft01=Passed"
"ft02=Passed"
"ft04=Passed"
"ft15=Passed"
"registryExtraSlot=Passed"
"registryDuplicateSlot=Passed"
"registryWrongOrder=Passed"
"missingAndInvalidOidMatrix=Passed"
"requiredAbsent=Passed"
"freshnessOwnership=Passed"
"manifestFreshnessSuppression=Passed"
"independentFailureAccounting=Passed"
"moduleAstViolationCount=$($moduleViolations.Count)"
"harnessAstViolationCount=$($harnessViolations.Count)"
"gitInspectionProcessCount=$($positive.O2.gitInspectionProcessCount)"
"heavyProcessCount=$($positive.O2.heavyProcessCount)"
"realAssetReadCount=$($positive.O2.realAssetReadCount)"
"createdExtractedCount=$($positive.O2.createdExtractedCount)"
"createdImportedCount=$($positive.O2.createdImportedCount)"
