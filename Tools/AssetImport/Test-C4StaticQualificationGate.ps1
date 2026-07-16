[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1') -Force -PassThru
$moduleAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1'),[ref]$null,[ref]$null)
if(@($moduleAst.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-ceq'Sort-Object'},$true)).Count){throw 'C4 module reintroduced culture-sensitive Sort-Object.'}
$policyBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'),[Text.UTF8Encoding]::new($false))
$policy = $policyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json') | ConvertFrom-Json -Depth 100 -DateKind String
$familyRegistry = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json') | ConvertFrom-Json -Depth 100 -DateKind String
$memberLedger = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json') | ConvertFrom-Json -Depth 100 -DateKind String

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function Get-FixtureFingerprint([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

$assigned = @($memberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember')
$facts = [Collections.Generic.List[object]]::new()
$observations = [Collections.Generic.List[object]]::new()
foreach ($member in $assigned) {
    $lanePolicy = @($policy.policies | Where-Object lane -CEQ $member.lane)[0]
    foreach ($definition in @($lanePolicy.factDefinitions)) {
        $facts.Add([pscustomobject][ordered]@{
            assetObjectId = [string]$member.assetObjectId
            lane = [string]$member.lane
            factKind = [string]$definition.factKind
            factStatus = 'Known'
        })
    }
    foreach ($check in @($lanePolicy.staticCheckDefinitions)) {
        $outcome = 'Passed'; $reasonCode = 'None'
        if ($member.lane -ceq 'Environment' -and $check.checkId -ceq 'ColliderValidity') {
            $outcome = 'Failed'; $reasonCode = 'PolicyViolation'
        }
        elseif ($member.lane -ceq 'Actor' -and $check.checkId -ceq 'AnimationClipReadability') {
            $outcome = 'Unchecked'; $reasonCode = 'ToolUnavailable'
        }
        $observations.Add([pscustomobject][ordered]@{
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            checkId = [string]$check.checkId
            outcome = $outcome
            reasonCode = $reasonCode
            observedFingerprint = if ($outcome -ceq 'Passed') { Get-FixtureFingerprint "$($member.assetObjectId)|$($check.checkId)|fixture-evidence" } else { $null }
            evidenceKinds = @($check.requiredEvidenceKinds)
            evidence = @('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')
        })
    }
}

function Run-Kernel($FactRows, $ObservationRows) {
    Invoke-C4StaticQualificationKernel `
        -FamilyRegistry $familyRegistry `
        -FamilyMemberLedger $memberLedger `
        -TypedFactRows $FactRows `
        -LanePolicyRegistry $policy `
        -LanePolicyBytes $policyBytes `
        -MemberStaticStatuses @($vocabulary.memberStaticStatus) `
        -StaticObservationRows $ObservationRows
}

$result = Run-Kernel @($facts) @($observations)
if ($result.status -cne 'Passed') { throw "C4-0 positive result failed: $($result.issues -join '; ')" }
if ($result.assignedMemberCount -ne 5 -or $result.staticPassedCount -ne 3 -or $result.staticFailedCount -ne 1 -or $result.uncheckedCount -ne 1) { throw 'SP-40 member partition failed.' }
if ($result.assignedMemberBytes -ne 1500 -or $result.staticPassedBytes -ne 1000 -or $result.staticFailedBytes -ne 200 -or $result.uncheckedBytes -ne 300) { throw 'SP-40 member byte partition failed.' }
if ($result.requiredCheckCount -ne 36 -or $result.passedCheckCount -ne 34 -or $result.failedCheckCount -ne 1 -or $result.uncheckedCheckCount -ne 1) { throw 'SP-40 required-check partition failed.' }
if ($result.memberResults.Count -ne 5 -or @($result.memberResults.assetObjectId | Sort-Object -Unique).Count -ne 5) { throw 'C4-0 member identity conservation failed.' }
if (@($result.memberResults | Where-Object staticStatus -CEQ 'StaticPassed').Count -ne 3 -or @($result.memberResults | Where-Object staticStatus -CEQ 'StaticFailed').Count -ne 1 -or @($result.memberResults | Where-Object staticStatus -CEQ 'Unchecked').Count -ne 1) { throw 'C4-0 member status projection failed.' }
foreach ($memberResult in $result.memberResults) {
    if ($memberResult.requiredCheckCount -ne ($memberResult.passedCheckCount + $memberResult.failedCheckCount + $memberResult.uncheckedCheckCount)) { throw 'C4-0 member check conservation failed.' }
}
foreach ($familyResult in $result.familyResults) {
    if ($familyResult.memberCount -ne ($familyResult.staticPassedCount + $familyResult.staticFailedCount + $familyResult.uncheckedCount)) { throw 'C4-0 family member conservation failed.' }
}
if (@($result.checkResults | Where-Object outcome -CEQ 'Unchecked' | Where-Object reasonCode -CEQ 'None').Count) { throw 'Unchecked was projected as Passed.' }

$missingRows = @($observations | Where-Object { -not ($_.assetObjectId -ceq $assigned[0].assetObjectId -and $_.checkId -ceq @($policy.policies | Where-Object lane -CEQ $assigned[0].lane)[0].staticCheckDefinitions[0].checkId) })
$missingResult = Run-Kernel @($facts) $missingRows
if ($missingResult.status -cne 'Failed' -or $missingResult.issues -cnotcontains 'Missing required static observation row.') { throw 'LF-09 missing check fail-closed behavior failed.' }

$duplicateRows = @($observations) + @((Clone-Value $observations[0]))
$duplicateResult = Run-Kernel @($facts) $duplicateRows
if ($duplicateResult.status -cne 'Failed' -or $duplicateResult.issues -cnotcontains 'Duplicate static observation row.') { throw 'LF-09 duplicate check fail-closed behavior failed.' }

$invalidRows = @(Clone-Value $observations)
$invalidRows[0].reasonCode = 'ToolUnavailable'
$invalidResult = Run-Kernel @($facts) $invalidRows
if ($invalidResult.status -cne 'Failed' -or $invalidResult.issues -cnotcontains 'Passed static observation must use reasonCode None.') { throw 'LF-09 invalid reason fail-closed behavior failed.' }

$missingEvidenceRows = @(Clone-Value $observations)
$passedWithEvidence = @($missingEvidenceRows | Where-Object outcome -CEQ 'Passed')[0]
$passedWithEvidence.evidenceKinds = @($passedWithEvidence.evidenceKinds | Select-Object -Skip 1)
$missingEvidenceResult = Run-Kernel @($facts) $missingEvidenceRows
if ($missingEvidenceResult.status -cne 'Failed' -or $missingEvidenceResult.issues -cnotcontains 'Passed static observation is missing required evidence kinds.') { throw 'Required evidence conjunction fail-closed behavior failed.' }

$unknownFacts = @(Clone-Value $facts)
$actor = @($assigned | Where-Object lane -CEQ 'Actor')[0]
$actorFact = @($unknownFacts | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.factKind -ceq 'AnimationSetShapeId' })[0]
$actorFact.factStatus = 'Unknown'
$unknownRows = @(Clone-Value $observations)
$actorObservation = @($unknownRows | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0]
$actorObservation.outcome = 'Unchecked'; $actorObservation.reasonCode = 'MissingInputFact'; $actorObservation.observedFingerprint = $null
$unknownResult = Run-Kernel $unknownFacts $unknownRows
if ($unknownResult.status -cne 'Passed' -or @($unknownResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0].outcome -cne 'Unchecked') { throw 'Missing fact did not remain explicit Unchecked.' }

$notApplicableFacts = @(Clone-Value $facts)
$naFact = @($notApplicableFacts | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.factKind -ceq 'AnimationSetShapeId' })[0]
$naFact.factStatus = 'NotApplicable'
$notApplicableRows = @($observations | Where-Object { -not ($_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability') })
$notApplicableResult = Run-Kernel $notApplicableFacts $notApplicableRows
if ($notApplicableResult.status -cne 'Passed' -or $notApplicableResult.requiredCheckCount -ne 35 -or @($notApplicableResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' }).Count) { throw 'Policy-allowed NotApplicable check was not excluded.' }

$repeat = Run-Kernel @($facts) @($observations)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C4-0 determinism failed.' }
$unboundPolicy=Clone-Value $policy;$unboundPolicy.policySetVersion='9.9.9'
$unboundResult=Invoke-C4StaticQualificationKernel -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -TypedFactRows @($facts) -LanePolicyRegistry $unboundPolicy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations)
if($unboundResult.status-cne'Failed'-or$unboundResult.issues-cnotcontains'LC-I07 execution object does not match accepted bytes.'){throw 'C4 LC-I07 object/bytes binding RED failed.'}
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C4-0 touched C2 publication state.' }

$crossLaneReferences = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json') | ConvertFrom-Json -Depth 100 -DateKind String
$directInputs = @(
    [pscustomobject][ordered]@{artifactId='C3-O01';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json';sha256=('1'*64)},
    [pscustomobject][ordered]@{artifactId='C3-O02';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json';sha256=('2'*64)},
    [pscustomobject][ordered]@{artifactId='C3-O03';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json';sha256=('3'*64)},
    [pscustomobject][ordered]@{artifactId='C3-O04-Summary';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json';sha256=('4'*64)},
    [pscustomobject][ordered]@{artifactId='C3-O04-Report';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md';sha256=('5'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I01';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json';sha256=('6'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I02';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json';sha256=('7'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I03';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json';sha256=('8'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I06';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json';sha256=('9'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I07';path='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json';sha256=('a'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I08';path='docs/asset-migration/schemas/status-vocabulary.json';sha256=('b'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I13';path='docs/asset-migration/schemas/c2-lane-fact-package.schema.json';sha256=('c'*64)}
)
$stage = [pscustomobject][ordered]@{generatedAt='2026-07-16T04:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C4StaticQualificationGate:1.0.0');directInputs=$directInputs}
$gate = Invoke-C4StaticQualificationGate -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -CrossLaneReferencePackage $crossLaneReferences -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations) -Stage $stage
if ($gate.gateStatus -cne 'Passed' -or (@($gate.PSObject.Properties.Name)-join',') -cne 'gateStatus,memberStaticQualification,familyStaticSummary,summary,report,texts') { throw 'C4-1 Passed result vector shape failed.' }
if ($gate.summary.failureAccounting.outputCandidateCount -ne 3 -or $gate.summary.failureAccounting.projectedOutputCount -ne 3 -or $gate.summary.failureAccounting.outputFailureCount -ne 0 -or $gate.summary.directOutputs.Count -ne 3) { throw 'C4-1 Passed output conservation failed.' }
if ((@($gate.memberStaticQualification.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,memberResults' -or (@($gate.familyStaticSummary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,families') { throw 'C4 success artifact top-level shape failed.' }
if ((@($gate.summary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision') { throw 'C4-O03 summary top-level shape failed.' }
if ($gate.memberStaticQualification.memberResults.Count -ne 5 -or $gate.familyStaticSummary.families.Count -ne 5 -or $gate.summary.coverage.requiredCheckCount -ne 36) { throw 'C4-1 success artifact counts failed.' }
if($gate.summary.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$gate.summary.inputFingerprint-in@(('1'*64),('2'*64),('a'*64))){throw'C4-1 computed input fingerprint failed.'}
$memberShape='staticResultId,assetObjectId,familyId,lane,requiredCheckCount,passedCheckCount,failedCheckCount,uncheckedCheckCount,staticStatus,uncheckedReasonCodes,failureAttribution,nextAllowedAction,checkResults,evidence'
$checkShape='checkResultId,checkId,outcome,reasonCode,observedFingerprint,evidence'
foreach($memberResult in $gate.memberStaticQualification.memberResults){if((@($memberResult.PSObject.Properties.Name)-join',')-cne$memberShape){throw'C4-O01 member shape failed.'};foreach($checkResult in $memberResult.checkResults){if((@($checkResult.PSObject.Properties.Name)-join',')-cne$checkShape){throw'C4-O01 check shape failed.'}}}
$familyShape='familyId,lane,memberCount,memberBytes,staticPassedCount,staticPassedBytes,staticFailedCount,staticFailedBytes,uncheckedCount,uncheckedBytes,staticOutcome,failureAttribution,nextAllowedAction,memberStaticResultIds,evidence'
foreach($familyResult in $gate.familyStaticSummary.families){if((@($familyResult.PSObject.Properties.Name)-join',')-cne$familyShape){throw'C4-O02 family shape failed.'};if($familyResult.memberCount-ne($familyResult.staticPassedCount+$familyResult.staticFailedCount+$familyResult.uncheckedCount)){throw'C4-O02 family conservation failed.'}}
$coverageShape='familyCount,memberCount,memberBytes,staticPassedCount,staticPassedBytes,staticFailedCount,staticFailedBytes,uncheckedCount,uncheckedBytes,requiredCheckCount,passedCheckCount,failedCheckCount,uncheckedCheckCount'
$accountingShape='inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,notEvaluatedInputSubjectCount,outputCandidateCount,projectedOutputCount,outputFailureCount,issueCount,gateStatus,inputFailures,inputSuppressions,outputFailures'
if((@($gate.summary.coverage.PSObject.Properties.Name)-join',')-cne$coverageShape-or(@($gate.summary.failureAccounting.PSObject.Properties.Name)-join',')-cne$accountingShape){throw'C4-O03 coverage/accounting shape failed.'}
if($gate.summary.failureAccounting.inputFailureCount-ne0-or$gate.summary.decision.failureAttribution-cne'None; C4 lifecycle contract passed.'-or@($gate.memberStaticQualification.memberResults|Where-Object staticStatus -CEQ StaticFailed).Count-ne1-or@($gate.memberStaticQualification.memberResults|Where-Object staticStatus -CEQ Unchecked).Count-ne1){throw'LF-07/LF-08 valid outcome projection failed.'}
if($gate.report.Contains("`r")-or-not$gate.report.EndsWith("`n")-or$gate.report.EndsWith("`n`n")){throw'C4 report byte format failed.'}
$outputTextById=@{'C4-O01'=$gate.texts.memberStaticQualification;'C4-O02'=$gate.texts.familyStaticSummary;'C4-O03-Report'=$gate.report}
foreach($output in $gate.summary.directOutputs){if($output.sha256-cne(Get-FixtureFingerprint $outputTextById[$output.artifactId]).Substring(7)){throw"C4 direct output hash mismatch: $($output.artifactId)"}}
$changedStage=Clone-Value $stage;$changedStage.directInputs[0].sha256=('d'*64)
$changedGate=Invoke-C4StaticQualificationGate -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -CrossLaneReferencePackage $crossLaneReferences -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations) -Stage $changedStage
if($changedGate.gateStatus-cne'Passed'-or$changedGate.summary.inputFingerprint-ceq$gate.summary.inputFingerprint){throw'LX-HI-14 direct-input mutation sensitivity failed.'}
$missingInputStage=Clone-Value $stage;$missingInputStage.directInputs=@($missingInputStage.directInputs|Select-Object -Skip 1);$rejected=$false;try{Invoke-C4StaticQualificationGate -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -CrossLaneReferencePackage $crossLaneReferences -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations) -Stage $missingInputStage|Out-Null}catch{$rejected=$_.Exception.Message-ceq'C4 direct input set is invalid.'};if(-not$rejected){throw'C4 missing direct input was not rejected.'}

$fixturePayloads=[ordered]@{'valid-member-static-qualification.json'=$gate.texts.memberStaticQualification;'valid-family-static-summary.json'=$gate.texts.familyStaticSummary;'valid-c4-summary.json'=$gate.texts.summary;'valid-c4-report.md'=$gate.report}
if($UpdateFixtures){$utf8=[Text.UTF8Encoding]::new($false);foreach($name in $fixturePayloads.Keys){[IO.File]::WriteAllText((Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"),$fixturePayloads[$name],$utf8)};'fixtures=Updated';return}
foreach($name in $fixturePayloads.Keys){$path=Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name";if(-not(Test-Path -LiteralPath $path)){throw "C4-1 expected fixture missing: $name"};if([IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false))-cne$fixturePayloads[$name]){throw "C4-1 fixture bytes mismatch: $name"}}

$failedGate = Invoke-C4StaticQualificationGate -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -CrossLaneReferencePackage $crossLaneReferences -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows $missingRows -Stage $stage
if($failedGate.gateStatus-cne'Failed'-or$null-ne$failedGate.memberStaticQualification-or$null-ne$failedGate.familyStaticSummary-or$failedGate.summary.failureAccounting.outputCandidateCount-ne3-or$failedGate.summary.failureAccounting.projectedOutputCount-ne1-or$failedGate.summary.failureAccounting.outputFailureCount-ne2-or$failedGate.summary.failureAccounting.issueCount-ne1-or$failedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-09:C4:StaticConservation'-or$failedGate.summary.directOutputs.Count-ne1){throw'C4-1 LF-09 diagnostic-only vector failed.'}

'status=Passed'
'assignedMemberCount=5'
'memberPartition=3/1/1'
'memberBytePartition=1000/200/300'
'requiredCheckPartition=34/1/1'
'laneCheckCount=36'
'passedOutputVector=3/3/0'
'failedOutputVector=3/1/2'
'publicationWriteCount=0'
