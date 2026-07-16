[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C3FamilyMembershipGate.psm1') -Force -PassThru
$policy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json') | ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json') | ConvertFrom-Json -Depth 100 -DateKind String

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function New-ObjectId([char]$Value) { "sha256:$([string]$Value * 64)" }
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
}
$facts.Add((New-Fact $objects.Actor Actor DependencyObjectIds $null @($objects.Environment)))

function Run-Kernel($Rows,$Facts) {
    Invoke-C3FamilyMembershipKernel -DispatchRows $Rows -TypedFactRows $Facts -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus)
}

$result = Run-Kernel @($dispatchRows) @($facts)
if ($result.status -cne 'Passed') { throw "C3-0 positive result failed: $($result.issues -join '; ')" }
if ($result.dispatchEligibleObjectCount -ne 7 -or $result.assignedFamilyMemberCount -ne 5 -or $result.retainedForDiagnosisObjectCount -ne 1 -or $result.configurationOnlyObjectCount -ne 1) { throw 'SP-30 partition conservation failed.' }
if ($result.memberRows.Count -ne 7 -or @($result.memberRows.assetObjectId | Sort-Object -Unique).Count -ne 7) { throw 'C3-0 direct-parent identity conservation failed.' }
if (@($result.memberRows | Where-Object parentStatus -ceq AssignedFamilyMember).Count -ne 5 -or @($result.memberRows | Where-Object parentStatus -ceq RetainedForDiagnosis).Count -ne 1 -or @($result.memberRows | Where-Object parentStatus -ceq ConfigurationOnly).Count -ne 1) { throw 'C3-0 parent status partition failed.' }
if ($result.families.Count -ne 5 -or ($result.families.memberCount | Measure-Object -Sum).Sum -ne 5) { throw 'C3-0 family member conservation failed.' }
if ($result.crossLaneReferences.Count -ne 1 -or $result.crossLaneReferences[0].fromAssetObjectId -cne $objects.Actor -or $result.crossLaneReferences[0].toAssetObjectId -cne $objects.Environment) { throw 'SP-31 cross-lane reference projection failed.' }
if (@($result.memberRows | Where-Object assetObjectId -cin @($objects.Actor,$objects.Environment) | Where-Object parentStatus -cne AssignedFamilyMember).Count) { throw 'Cross-lane reference changed direct membership.' }

$unknownFacts = @(Clone-Value $facts)
$unknown = @($unknownFacts | Where-Object { $_.assetObjectId -ceq $objects.Actor -and $_.factKind -ceq 'SkeletonId' })[0]
$unknown.factStatus = 'Unknown'; $unknown.valueKind = 'String'; $unknown.stringValue = $null
$unknownResult = Run-Kernel @($dispatchRows) $unknownFacts
if ($unknownResult.status -cne 'Passed' -or $unknownResult.assignedFamilyMemberCount -ne 4 -or $unknownResult.retainedForDiagnosisObjectCount -ne 2 -or @($unknownResult.memberRows | Where-Object assetObjectId -ceq $objects.Actor)[0].parentStatus -cne 'RetainedForDiagnosis') { throw 'LF-04 Unknown family key behavior failed.' }

$duplicateRows = @(Clone-Value $dispatchRows) + @((Clone-Value $dispatchRows[0]))
$duplicateResult = Run-Kernel $duplicateRows @($facts)
if ($duplicateResult.status -cne 'Failed' -or $duplicateResult.issues -cnotcontains 'Duplicate dispatch assetObjectId.') { throw 'LF-05 duplicate dispatch fail-closed behavior failed.' }

$repeat = Run-Kernel @($dispatchRows) @($facts)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C3-0 determinism failed.' }

$ledgerObjects = @($dispatchRows | ForEach-Object -Begin {$n=0} -Process {
    $n++;$objectId=$_.assetObjectId
    [pscustomobject][ordered]@{assetObjectId=$objectId;serializedSizeBytes=100*$n;dependencyObjectIds=@($facts | Where-Object { $_.assetObjectId -ceq $objectId -and $_.factKind -ceq 'DependencyObjectIds' } | ForEach-Object idValues | ForEach-Object {$_});evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')}
})
$directInputs = @(
    [pscustomobject][ordered]@{artifactId='LC-I01';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json';sha256=('1'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I02';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json';sha256=('2'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I03';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json';sha256=('3'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I04';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json';sha256=('4'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I05';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json';sha256=('5'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I06';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json';sha256=('6'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I07';path='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json';sha256=('7'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I08';path='docs/asset-migration/schemas/status-vocabulary.json';sha256=('8'*64)},
    [pscustomobject][ordered]@{artifactId='LC-I13';path='docs/asset-migration/schemas/c2-lane-fact-package.schema.json';sha256=('9'*64)}
)
$stage = [pscustomobject][ordered]@{generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C3FamilyMembershipGate:1.0.0');directInputs=$directInputs}
try{$gate = Invoke-C3FamilyMembershipGate -DispatchRows @($dispatchRows) -TypedFactRows @($facts) -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -Stage $stage}catch{throw "$($_.Exception.Message) $($_.ScriptStackTrace)"}
if ($gate.gateStatus -cne 'Passed' -or (@($gate.PSObject.Properties.Name)-join',') -cne 'gateStatus,familyRegistry,familyMemberLedger,crossLaneReferencePackage,summary,report,texts') { throw 'C3-1 Passed result vector shape failed.' }
if ($gate.summary.failureAccounting.outputCandidateCount -ne 4 -or $gate.summary.failureAccounting.projectedOutputCount -ne 4 -or $gate.summary.failureAccounting.outputFailureCount -ne 0 -or $gate.summary.directOutputs.Count -ne 4) { throw 'C3-1 Passed output conservation failed.' }
if ((@($gate.familyRegistry.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,families' -or (@($gate.familyMemberLedger.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,rows' -or (@($gate.crossLaneReferencePackage.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,rows') { throw 'C3-1 success artifact top-level shape failed.' }
if ((@($gate.summary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision') { throw 'C3-1 summary top-level shape failed.' }
if ($gate.familyRegistry.families.Count -ne 5 -or $gate.familyMemberLedger.rows.Count -ne 7 -or $gate.crossLaneReferencePackage.rows.Count -ne 1) { throw 'C3-1 success artifact counts failed.' }
if($gate.summary.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$gate.summary.inputFingerprint-ceq('a'*64)-or$gate.summary.coverage.dispatchEligibleObjectBytes-ne2800-or$gate.summary.coverage.assignedFamilyMemberBytes-ne1500-or$gate.summary.coverage.referenceCount-ne1-or$gate.summary.coverage.resolvedReferenceCount-ne1){throw'C3-1 computed fingerprint/byte/reference coverage failed.'}
$familyShape='familyId,lane,familyKindId,policyId,policyVersion,familyKeyFingerprint,familyKey,memberCount,memberBytes,memberObjectIds,crossLaneReferenceIds,riskDimensionIds,evidence';$keyShape='dimensionId,factStatus,valueKind,stringValue,integerValue,booleanValue,idValues';foreach($family in $gate.familyRegistry.families){if((@($family.PSObject.Properties.Name)-join',')-cne$familyShape){throw'C3-O01 family row shape failed.'};foreach($key in $family.familyKey){if((@($key.PSObject.Properties.Name)-join',')-cne$keyShape){throw'C3-O01 family key shape failed.'}}}
$memberShape='memberRecordId,assetObjectId,canonicalAssetId,lane,parentStatus,familyId,familyKindId,serializedSizeBytes,configurationCandidateId,dependencyObjectIds,crossLaneReferenceIds,policyId,policyVersion,evidence';foreach($member in $gate.familyMemberLedger.rows){if((@($member.PSObject.Properties.Name)-join',')-cne$memberShape){throw'C3-O02 member row shape failed.'}}
$referenceShape='referenceId,fromAssetObjectId,toAssetObjectId,fromLane,toLane,referenceKind,resolutionStatus,evidence';foreach($reference in $gate.crossLaneReferencePackage.rows){if((@($reference.PSObject.Properties.Name)-join',')-cne$referenceShape){throw'C3-O03 reference row shape failed.'}}
$accountingShape='inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,notEvaluatedInputSubjectCount,outputCandidateCount,projectedOutputCount,outputFailureCount,issueCount,gateStatus,inputFailures,inputSuppressions,outputFailures';$coverageShape='dispatchEligibleObjectCount,dispatchEligibleObjectBytes,assignedFamilyMemberCount,assignedFamilyMemberBytes,retainedForDiagnosisObjectCount,retainedForDiagnosisObjectBytes,configurationOnlyObjectCount,configurationOnlyObjectBytes,familyCount,referenceCount,resolvedReferenceCount,missingReferenceCount,conflictReferenceCount';if((@($gate.summary.failureAccounting.PSObject.Properties.Name)-join',')-cne$accountingShape-or(@($gate.summary.coverage.PSObject.Properties.Name)-join',')-cne$coverageShape){throw'C3-O04 accounting/coverage shape failed.'}
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

$failedGate = Invoke-C3FamilyMembershipGate -DispatchRows $duplicateRows -TypedFactRows @($facts) -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -Stage $stage
if ($failedGate.gateStatus -cne 'Failed' -or $null-ne$failedGate.familyRegistry -or $null-ne$failedGate.familyMemberLedger -or $null-ne$failedGate.crossLaneReferencePackage -or $failedGate.summary.failureAccounting.projectedOutputCount-ne1 -or $failedGate.summary.failureAccounting.outputFailureCount-ne3 -or $failedGate.summary.directOutputs.Count-ne1 -or $failedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-05:C3:MembershipConservation') { throw 'C3-1 Failed diagnostic-only vector failed.' }
$duplicateFacts=@(Clone-Value $facts)+@((Clone-Value $facts[0]));$typedFailure=Invoke-C3FamilyMembershipGate -DispatchRows @($dispatchRows) -TypedFactRows $duplicateFacts -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -Stage $stage;if($typedFailure.gateStatus-cne'Failed'-or$typedFailure.summary.failureAccounting.inputFailures[0].attribution-cne'LF-02:LC-I06'-or$typedFailure.summary.failureAccounting.projectedOutputCount-ne1){throw'C3-1 LF-02 diagnostic-only vector failed.'}
$badPolicy=Clone-Value $policy;$badPolicy.policySetVersion='1.0.1';$policyFailure=Invoke-C3FamilyMembershipGate -DispatchRows @($dispatchRows) -TypedFactRows @($facts) -LanePolicyRegistry $badPolicy -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -Stage $stage;if($policyFailure.gateStatus-cne'Failed'-or$policyFailure.summary.failureAccounting.inputFailures[0].attribution-cne'LF-03:LC-I07'-or$policyFailure.summary.failureAccounting.projectedOutputCount-ne1){throw'C3-1 LF-03 diagnostic-only vector failed.'}
$missingFacts=Clone-Value $facts;$dependency=@($missingFacts|Where-Object{$_.assetObjectId-ceq$objects.Actor-and$_.factKind-ceq'DependencyObjectIds'})[0];$dependency.idValues=@($dependency.idValues,"sha256:$('9'*64)")|Sort-Object -CaseSensitive;$missingGate=Invoke-C3FamilyMembershipGate -DispatchRows @($dispatchRows) -TypedFactRows $missingFacts -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus) -LedgerObjects $ledgerObjects -Stage $stage;if($missingGate.gateStatus-cne'Passed'-or$missingGate.crossLaneReferencePackage.rows.Count-ne2-or$missingGate.summary.coverage.missingReferenceCount-ne1-or@($missingGate.familyMemberLedger.rows|Where-Object parentStatus -CEQ AssignedFamilyMember).Count-ne5){throw'SP-31 Missing reference partition failed.'}
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C3-0 touched C2 publication state.' }

'status=Passed'
'dispatchEligibleObjectCount=7'
'assignedFamilyMemberCount=5'
'retainedForDiagnosisObjectCount=1'
'configurationOnlyObjectCount=1'
'familyCount=5'
'crossLaneReferenceCount=1'
'passedOutputVector=4/4/0'
'failedOutputVector=4/1/3'
'publicationWriteCount=0'
