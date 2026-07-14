[CmdletBinding()]
param(
    [ValidateSet('Pure','GitAdapter','Integration','FailureState','ValidatorMutations')]
    [string]$Case = 'Pure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'C2DiscoveryIntakeGate.psm1'
$loadedModule = Import-Module $modulePath -Force -PassThru

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
    if ($adapter.status -cne 'Passed') { throw "Git adapter positive failed: $($adapter.failureAttribution)" }
    if ($adapter.gitInspectionProcessCount -ne 6) { throw "Git adapter call count expected=6 actual=$($adapter.gitInspectionProcessCount)" }
    if (-not $adapter.headStable -or $adapter.startCommitOid -cne $adapter.endCommitOid) { throw 'Git adapter HEAD stability failed.' }
    if ((@($adapter.commandTrace).Count) -ne 6) { throw 'Git adapter trace count invalid.' }
    if (@($adapter.commandTrace)[0].arguments[-1] -cne 'HEAD^{commit}' -or @($adapter.commandTrace)[5].arguments[-1] -cne 'HEAD^{commit}') { throw 'Git adapter HEAD grammar invalid.' }
    if (@($adapter.commandTrace)[2].stdoutByteCount -ne 0) { throw 'Optional-absence call returned bytes.' }
    foreach ($call in $adapter.commandTrace) {
        if (-not $call.environmentValid) { throw "Unsanitized child environment at call $($call.callNumber)" }
        if ($call.useShellExecute -or -not $call.redirectStandardOutput -or -not $call.redirectStandardError) { throw "Unsafe process mode at call $($call.callNumber)" }
    }
    $startFailure = Test-C2GitAdapterLifecycle -FailurePoint Call1StartFailure
    $middleFailure = Test-C2GitAdapterLifecycle -FailurePoint Call3InvalidOutput
    $finalFailure = Test-C2GitAdapterLifecycle -FailurePoint Call6InvalidOutput
    $changedHead = Test-C2GitAdapterLifecycle -FailurePoint ChangedHead
    $policyFailure = Test-C2GitAdapterLifecycle -FailurePoint PrelaunchCall2
    foreach($caseResult in @($startFailure,$middleFailure,$finalFailure,$changedHead)){
        if($caseResult.owner -cne 'FT-03' -or $caseResult.reason -cne 'StaleFingerprint' -or $null -ne $caseResult.discoveryInputFingerprint){throw "FT-03 lifecycle ownership failed: $($caseResult.case)"}
    }
    if($policyFailure.owner -cne 'FT-13' -or $policyFailure.reason -cne 'HeavyOperationAttempted' -or $policyFailure.gitInspectionProcessCount -ne 1){throw 'FT-13 prelaunch ownership/count failed.'}
    if($startFailure.gitInspectionProcessCount -ne 0 -or $null -ne $startFailure.startCommitOid -or $null -ne $startFailure.endCommitOid -or $null -ne $startFailure.headStable){throw 'Call1 start failure vector invalid.'}
    if($middleFailure.gitInspectionProcessCount -ne 4 -or -not $middleFailure.headStable){throw 'Intermediate failure/final-revalidation vector invalid.'}
    if($finalFailure.gitInspectionProcessCount -ne 6 -or $null -ne $finalFailure.endCommitOid -or $null -ne $finalFailure.headStable){throw 'Final failure vector invalid.'}
    if($changedHead.gitInspectionProcessCount -ne 6 -or $changedHead.headStable -ne $false){throw 'Changed HEAD vector invalid.'}
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
    "call6Failure=Passed"
    "changedHead=Passed"
    "prelaunchFT13=Passed"
    return
}

if ($Case -ceq 'Integration') {
    $repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $result = Invoke-C2DiscoveryIntakeGate -RepositoryRoot $repositoryRoot
    if ($result.O2.status -cne 'Passed') { throw "Integration expected Passed: $($result.O1.decision.failureAttribution)" }
    $expectedCounts = [ordered]@{
        registeredArtifactCount=11; readArtifactCount=9; requiredArtifactCount=6; presentOptionalArtifactCount=3; absentOptionalArtifactCount=2
        failedRegistrySlotCount=0; acceptedArtifactCount=9; failedArtifactCount=0; contractCheckCount=5; acceptedCheckCount=3
        failedCheckCount=0; notEvaluatedCheckCount=2; inputSubjectCount=14; acceptedInputSubjectCount=12; inputFailureCount=0
        excludedInputSubjectCount=0; notEvaluatedInputSubjectCount=2; gitInspectionProcessCount=6; heavyProcessCount=0
        realAssetReadCount=0; createdExtractedCount=0; createdImportedCount=0
    }
    foreach($entry in $expectedCounts.GetEnumerator()) { if($result.O2.($entry.Key) -ne $entry.Value){throw "$($entry.Key) expected=$($entry.Value) actual=$($result.O2.($entry.Key))"} }
    if($result.O1.artifactStates.Count -ne 11 -or $result.O1.contractChecks.Count -ne 5 -or $result.O1.inputSuppressions.Count -ne 2){throw 'Integration O1 row counts invalid.'}
    if($result.O2.discoveryInputFingerprint -cnotmatch '^[0-9a-f]{64}$'){throw 'D9 missing or invalid.'}
    if($result.O2.startCommitOid -cne $result.O2.endCommitOid -or -not $result.O2.headStable){throw 'Integration HEAD stability failed.'}
    if(($result.O1.contractChecks.status -join ',') -cne 'Accepted,Accepted,Accepted,NotEvaluated,NotEvaluated'){throw 'Integration check vector invalid.'}
    $d9Entries=@($result.O1.artifactStates|Where-Object readStatus -eq Accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})
    $independentD9=Get-C2DiscoveryInputFingerprint -Entries $d9Entries
    if($independentD9 -cne $result.O2.discoveryInputFingerprint -or $independentD9 -cne '0e1ad045d3b4bb5ec584132b8b115ee1a38b91d9a103e8ddcd5e41231a622e3a'){throw "Independent D9 mismatch: $independentD9"}
    $artifactRowOrder='artifactId,path,requirement,presence,readStatus,worktreeSha256,commitBlobSha256,manifestSha256,identityStatus,freshnessStatus,evidence'
    foreach($row in $result.O1.artifactStates){if((@($row.PSObject.Properties.Name)-join ',') -cne $artifactRowOrder){throw "Artifact row shape invalid: $($row.artifactId)"}}
    $checkRowOrder='subjectId,status,attribution,evidence,prerequisites'
    foreach($row in $result.O1.contractChecks){if((@($row.PSObject.Properties.Name)-join ',') -cne $checkRowOrder){throw "Check row shape invalid: $($row.subjectId)"}}
    $freshness=$result.O1.contractChecks[2]
    $expectedFreshnessEvidence=@($result.O1.artifactStates.path);[Array]::Sort($expectedFreshnessEvidence,[StringComparer]::Ordinal)
    if(($freshness.evidence -join "`n") -cne ($expectedFreshnessEvidence -join "`n")){throw 'Freshness evidence vector invalid.'}
    if(($freshness.prerequisites -join ',') -cne 'AR-I01,AR-I02,AR-I03,AR-I04,AR-I05,AR-I06,AR-I07,AR-I08,AR-I09,AR-I10,AR-I11,GitAdapter:EndHead,GitAdapter:StartCommitOid'){throw 'Freshness prerequisites invalid.'}
    if($result.O1.inputSuppressions[0].recordId -cne 'accounting-sha256:6d540e7fefd265ddef57b835e7bfb8894085d609419b3ac98b2268876f006e1c' -or $result.O1.inputSuppressions[1].recordId -cne 'accounting-sha256:212ec1d5b7ffc164817068a9227f8c7d847dc091c517c41db4b4270236294016'){throw 'Integration suppression identities invalid.'}
    "status=Passed"
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
    $call1Result=Test-C2InjectedGateVector -RepositoryRoot 'C:\repo' -Vector Call1StartFailure
    if($call1Result.O2.status -cne 'Failed' -or $call1Result.O2.gitInspectionProcessCount -ne 0 -or $null -ne $call1Result.O2.startCommitOid -or $null -ne $call1Result.O2.endCommitOid -or $null -ne $call1Result.O2.headStable){throw 'Call1 Failed O1/O2 vector invalid.'}
    if($call1Result.O1.inputFailures[0].attribution -cne 'FT-03:C2Check:Freshness' -or $null -ne $call1Result.O2.discoveryInputFingerprint){throw 'Call1 failure ownership invalid.'}
    $call3Result=Test-C2InjectedGateVector -RepositoryRoot 'C:\repo' -Vector Call3InvalidOutput
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
    "intermediateFailureStatus=$($call3Result.O2.status)"
    "intermediateGitInspectionProcessCount=$($call3Result.O2.gitInspectionProcessCount)"
    "intermediateFinalHeadRevalidated=$($call3Result.O2.headStable)"
    "failureFingerprintSuppressed=$($null -eq $call3Result.O2.discoveryInputFingerprint)"
    return
}

if ($Case -ceq 'ValidatorMutations') {
    $repositoryRoot=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $vectors=@(
        [pscustomobject]@{name='ledgerNestedSchema';subject='AR-I02';result=(Test-C2InjectedGateVector $repositoryRoot LedgerNestedInvalid)},
        [pscustomobject]@{name='vocabularyContent';subject='AR-I05';result=(Test-C2InjectedGateVector $repositoryRoot VocabularyInvalid)},
        [pscustomobject]@{name='manifestShape';subject='AR-I10';result=(Test-C2InjectedGateVector $repositoryRoot ManifestShapeInvalid)},
        [pscustomobject]@{name='observationHI03';subject='AR-I07';result=(Test-C2InjectedGateVector $repositoryRoot ObservationHI03Invalid)},
        [pscustomobject]@{name='approvalHI15';subject='AR-I11';result=(Test-C2InjectedGateVector $repositoryRoot ApprovalHI15Invalid)}
    )
    foreach($vector in $vectors){
        $r=$vector.result
        if($r.O2.status -cne 'Failed' -or $r.O2.issueCount -ne 1 -or $r.O2.gitInspectionProcessCount -ne 6 -or -not $r.O2.headStable -or $null -ne $r.O2.discoveryInputFingerprint){throw "$($vector.name) failure vector invalid"}
        if($r.O1.inputFailures[0].attribution -cne "FT-02:$($vector.subject)" -or $r.O1.contractChecks[2].status -cne 'NotEvaluated'){throw "$($vector.name) ownership/suppression invalid"}
    }
    "status=Passed"
    "ledgerNestedSchemaMutation=Passed"
    "vocabularyContentMutation=Passed"
    "manifestShapeMutation=Passed"
    "observationHI03Mutation=Passed"
    "approvalHI15Mutation=Passed"
    "mutationFinalHeadRevalidationCount=5"
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
    '39dfad072afb8316c47be545dbeed872e1c2f9bd6bd7b56365dd391f77ca244f',
    $null,
    $null,
    '5ddb3da1cc346ca673c6f24df7d9b7c8ea321e21416d7320f4890456b3668a3e',
    'e8e531a31fcf50891eaf9564aa0f9c86c816b883bc7f67635a21f7b7c97aa7f8'
)
$facts = for ($i=0; $i -lt 11; $i++) {
    $present = $i -notin @(7,8)
    [pscustomobject][ordered]@{
        artifactId=$ids[$i]; path=$paths[$i]; requirement=$requirements[$i]; presence=if($present){'Present'}else{'Absent'}
        worktreeSha256=if($present){$shaValues[$i]}else{$null}
        commitBlobSha256=if($i -in @(6,9,10)){$shaValues[$i]}else{$null}
        manifestSha256=if($i -in @(6,10)){$shaValues[$i]}else{$null}
        identityValid=$true; freshnessValid=$true
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
    @('registeredArtifactCount',11),@('readArtifactCount',9),@('requiredArtifactCount',6),@('presentOptionalArtifactCount',3),@('absentOptionalArtifactCount',2),@('failedRegistrySlotCount',0),
    @('acceptedArtifactCount',9),@('failedArtifactCount',0),@('contractCheckCount',5),@('acceptedCheckCount',3),@('failedCheckCount',0),@('notEvaluatedCheckCount',2),
    @('inputSubjectCount',14),@('acceptedInputSubjectCount',12),@('inputFailureCount',0),@('excludedInputSubjectCount',0),@('notEvaluatedInputSubjectCount',2),
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

$badPath=Copy-MemoryValue $facts; $badPath[6].path='../object-observations.json'
$ft04=Invoke-C2PureDiscoveryIntake $badPath $handoff $oid $oid
Assert-Equal $ft04.O1.inputFailures[0].attribution 'FT-04:AR-I07' 'FT-04 owner'
Assert-Equal $ft04.O1.discoveryInputFingerprint $null 'FT-04 fingerprint suppression'

$ft15=Invoke-C2PureDiscoveryIntake $facts $handoff $oid $oid -FreshnessPrerequisiteAvailable:$false
Assert-Equal $ft15.O2.issueCount 0 'FT-15 issue count'
Assert-Equal $ft15.O2.inputFailureCount 0 'FT-15 failure count'
Assert-Equal $ft15.O1.contractChecks[2].status NotEvaluated 'FT-15 freshness status'
Assert-Equal $ft15.O1.inputSuppressions.Count 3 'FT-15 suppression count'

$requiredAbsent=Copy-MemoryValue $facts; $requiredAbsent[0].presence='Absent';$requiredAbsent[0].worktreeSha256=$null
$requiredAbsentResult=Invoke-C2PureDiscoveryIntake $requiredAbsent $handoff $oid $oid
Assert-Equal $requiredAbsentResult.O2.status Failed 'required absence status'
Assert-Equal $requiredAbsentResult.O1.artifactStates[0].readStatus Failed 'required absence slot state'
Assert-Equal $requiredAbsentResult.O1.inputFailures[0].attribution 'FT-03:C2Check:Freshness' 'required absence owner'
Assert-Equal $requiredAbsentResult.O2.registeredArtifactCount ($requiredAbsentResult.O2.readArtifactCount+$requiredAbsentResult.O2.absentOptionalArtifactCount+$requiredAbsentResult.O2.failedRegistrySlotCount) 'required absence NP-01'
Assert-Equal $requiredAbsentResult.O2.inputSubjectCount ($requiredAbsentResult.O2.acceptedInputSubjectCount+$requiredAbsentResult.O2.inputFailureCount+$requiredAbsentResult.O2.excludedInputSubjectCount+$requiredAbsentResult.O2.notEvaluatedInputSubjectCount) 'required absence NP-04'

$freshnessFalse=Copy-MemoryValue $facts;$freshnessFalse[0].freshnessValid=$false
$freshnessFalseResult=Invoke-C2PureDiscoveryIntake $freshnessFalse $handoff $oid $oid
Assert-Equal $freshnessFalseResult.O1.inputFailures[0].attribution 'FT-03:C2Check:Freshness' 'freshness fact owner'
Assert-Equal $freshnessFalseResult.O1.contractChecks[2].attribution 'FT-03:C2Check:Freshness' 'freshness check attribution'

$manifestShape=Copy-MemoryValue $facts;$manifestShape[9].PSObject.Properties.Remove('manifestSha256')
$manifestShapeResult=Invoke-C2PureDiscoveryIntake $manifestShape $handoff $oid $oid
Assert-Equal $manifestShapeResult.O1.contractChecks[2].status NotEvaluated 'manifest FT-15 freshness status'
Assert-Equal $manifestShapeResult.O1.contractChecks[2].attribution 'FT-15:C2Check:Freshness' 'manifest FT-15 attribution'

$twoFailures=Copy-MemoryValue $facts;$twoFailures[3].identityValid=$false;$twoFailures[4].identityValid=$false
$twoFailureResult=Invoke-C2PureDiscoveryIntake $twoFailures $handoff $oid $oid
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
                'Invoke-C2DiscoveryIntakeGateInternal'='^\[IO\.(Path|Directory|File)\]::(IsPathFullyQualified|Combine|Exists|ReadAllBytes)\(.+\)$'
            }
            if($null -eq $parent -or -not $allowedByFunction.ContainsKey($parent.Name) -or $text -cnotmatch $allowedByFunction[$parent.Name]){$violations.Add("api:$text")}
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
