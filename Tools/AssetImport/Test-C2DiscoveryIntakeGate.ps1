[CmdletBinding()]
param(
    [ValidateSet('Pure','GitAdapter','Integration','FailureState','ValidatorMutations','FileFixtureIntake','FilePartitions')]
    [string]$Case = 'Pure'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'C2DiscoveryIntakeGate.psm1'
$loadedModule = Import-Module $modulePath -Force -PassThru

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
    if ($adapter.status -cne 'Passed') { throw "Git adapter positive failed: $($adapter.failureAttribution)" }
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
    if ($result.O2.status -cne 'Passed') { throw "Integration expected Passed: $($result.O1.decision.failureAttribution)" }
    $expectedCounts = [ordered]@{
        registeredArtifactCount=11; readArtifactCount=10; requiredArtifactCount=6; presentOptionalArtifactCount=4; absentOptionalArtifactCount=1
        failedRegistrySlotCount=0; acceptedArtifactCount=10; failedArtifactCount=0; contractCheckCount=5; acceptedCheckCount=3
        failedCheckCount=0; notEvaluatedCheckCount=2; inputSubjectCount=15; acceptedInputSubjectCount=13; inputFailureCount=0
        excludedInputSubjectCount=0; notEvaluatedInputSubjectCount=2; gitInspectionProcessCount=7; heavyProcessCount=0
        realAssetReadCount=0; createdExtractedCount=0; createdImportedCount=0
    }
    foreach($entry in $expectedCounts.GetEnumerator()) { if($result.O2.($entry.Key) -ne $entry.Value){throw "$($entry.Key) expected=$($entry.Value) actual=$($result.O2.($entry.Key))"} }
    if($result.O1.artifactStates.Count -ne 11 -or $result.O1.contractChecks.Count -ne 5 -or $result.O1.inputSuppressions.Count -ne 2){throw 'Integration O1 row counts invalid.'}
    if($result.O2.discoveryInputFingerprint -cnotmatch '^[0-9a-f]{64}$'){throw 'D9 missing or invalid.'}
    if($result.O2.startCommitOid -cne $result.O2.endCommitOid -or -not $result.O2.headStable){throw 'Integration HEAD stability failed.'}
    if(($result.O1.contractChecks.status -join ',') -cne 'Accepted,Accepted,Accepted,NotEvaluated,NotEvaluated'){throw 'Integration check vector invalid.'}
    $d9Entries=@($result.O1.artifactStates|Where-Object readStatus -eq Accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})
    $independentD9=Get-C2DiscoveryInputFingerprint -Entries $d9Entries
    if($independentD9 -cne $result.O2.discoveryInputFingerprint -or $independentD9 -cne 'f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab'){throw "Independent D9 mismatch: $independentD9"}
    $i08=@($result.O1.artifactStates|Where-Object artifactId -eq 'AR-I08')[0]
    if($i08.worktreeSha256 -cne 'f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a' -or $i08.commitBlobSha256 -cne $i08.worktreeSha256 -or $i08.manifestSha256 -cne $i08.worktreeSha256){throw 'AR-I08 exact binding invalid.'}
    $i10=@($result.O1.artifactStates|Where-Object artifactId -eq 'AR-I10')[0]
    if($i10.worktreeSha256 -cne '4b4b65de4a2ec12dfc1cbd09929bdc66d5aa1cf8345bd161043d694b62cb2ea8'){throw 'AR-I10 exact hash invalid.'}
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
