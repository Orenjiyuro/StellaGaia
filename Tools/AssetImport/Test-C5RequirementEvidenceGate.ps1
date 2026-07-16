[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module=Import-Module (Join-Path $PSScriptRoot 'C5RequirementEvidenceGate.psm1') -Force -PassThru
$familyRegistry=Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json')|ConvertFrom-Json -Depth 100 -DateKind String
$memberStatic=Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json')|ConvertFrom-Json -Depth 100 -DateKind String
$lanePolicyPath=Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
$decisionPolicyPath=Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json'
$lanePolicyBytes=[IO.File]::ReadAllText($lanePolicyPath,[Text.UTF8Encoding]::new($false))
$decisionPolicyBytes=[IO.File]::ReadAllText($decisionPolicyPath,[Text.UTF8Encoding]::new($false))
$lanePolicy=$lanePolicyBytes|ConvertFrom-Json -Depth 100 -DateKind String
$decisionPolicy=$decisionPolicyBytes|ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary=Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json')|ConvertFrom-Json -Depth 100 -DateKind String

function Clone-Value($Value){$Value|ConvertTo-Json -Depth 100|ConvertFrom-Json -Depth 100 -DateKind String}
function Get-Sha256([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()}
function Scalar([string]$Name,[string]$Value){"${Name}:$([Text.Encoding]::UTF8.GetByteCount($Value)):${Value}`n"}
function SetFrame([string]$Name,[string[]]$Values){$ordered=@($Values|Sort-Object -CaseSensitive -Unique);$count=[string]$ordered.Count;$text="${Name}.count:$([Text.Encoding]::UTF8.GetByteCount($count)):$count`n";for($i=0;$i-lt$ordered.Count;$i++){$text+=Scalar "${Name}[$i]" $ordered[$i]};$text}
function ObservationFrame($Observation){"C5EvidenceObservationV1`n"+(Scalar evidenceKind $Observation.evidenceKind)+(Scalar outcome $Observation.outcome)+(Scalar contentFingerprint $Observation.contentFingerprint)+(SetFrame evidence @($Observation.evidence))}
function Update-PackageId($Package){$digests=@($Package.observations|ForEach-Object{Get-Sha256 (ObservationFrame $_)});$text="C5EvidencePackageV1`n"+(Scalar requirementId $Package.requirementId)+(Scalar requirementKind $Package.requirementKind)+(Scalar representativeAssetObjectId $Package.representativeAssetObjectId)+(Scalar executorKind $Package.executorKind)+(Scalar executionStatus $Package.executionStatus)+(Scalar inputFingerprint $Package.inputFingerprint)+(SetFrame observationDigests $digests)+(SetFrame evidencePaths @($Package.evidencePaths));$Package.evidencePackageId="evidence-package-sha256:$(Get-Sha256 $text)";$Package}
function New-Package($Requirement,[string]$Kind,[string]$Executor,[string]$ExecutionStatus,[object[]]$Observations){
    $id=if($Kind-ceq'RiskVariant'){$Requirement.requirementId}else{$Requirement.suitabilityRequirementId}
    Update-PackageId ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T05:00:00Z';evidencePackageId=('evidence-package-sha256:'+('0'*64));requirementId=$id;requirementKind=$Kind;representativeAssetObjectId=$Requirement.selectedRepresentativeAssetObjectId;executorKind=$Executor;executionStatus=$ExecutionStatus;inputFingerprint=$Requirement.expectedInputFingerprint;toolVersions=@('ImmutableFixture:1.0.0');observations=@($Observations);evidencePaths=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')})
}
function Get-StaticInputFingerprint {
    $paths=@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json','Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json','Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json','Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md')
    $entries=@($paths|ForEach-Object{[pscustomobject][ordered]@{path=$_;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repositoryRoot $_)).Hash.ToLowerInvariant()}}|Sort-Object path -CaseSensitive)
    $count=[string]$entries.Count;$text="LifecycleStageInputV1`nentries.count:$([Text.Encoding]::UTF8.GetByteCount($count)):$count`n"
    for($index=0;$index-lt$entries.Count;$index++){$nested="C2ArtifactEntryV1`n"+(Scalar path $entries[$index].path)+(Scalar sha256 $entries[$index].sha256);$text+="entries[$index]:$([Text.Encoding]::UTF8.GetByteCount($nested)):$nested`n"}
    Get-Sha256 $text
}

$riskFacts=[Collections.Generic.List[object]]::new()
foreach($family in $familyRegistry.families){
    $member=@($memberStatic.memberResults|Where-Object familyId -CEQ $family.familyId)[0]
    foreach($key in $family.familyKey){
        $value=if($family.lane-ceq'Actor'-and$key.dimensionId-ceq'ActorRole'){'Player'}else{$key.stringValue}
        $riskFacts.Add([pscustomobject][ordered]@{assetObjectId=$member.assetObjectId;familyId=$family.familyId;factKind=$key.dimensionId;factStatus=$key.factStatus;valueKind=$key.valueKind;stringValue=$value;integerValue=$key.integerValue;booleanValue=$key.booleanValue;idValues=@($key.idValues)})
    }
    $riskFacts.Add([pscustomobject][ordered]@{assetObjectId=$member.assetObjectId;familyId=$family.familyId;factKind='PlatformVariant';factStatus='Known';valueKind='String';stringValue='Pc';integerValue=$null;booleanValue=$null;idValues=@()})
}
$inputStaticFingerprint=Get-StaticInputFingerprint

function Run-Kernel($Facts,$Packages){
    Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows $Facts -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages $Packages
}

$base=Run-Kernel @($riskFacts) @()
if($base.status-cne'Passed'){throw "C5-0 base failed: $($base.issues -join '; ')"}
if($base.policySetFingerprint-cne'7fdde7cb9d709be5e11fb3391053b8f0cb3e26348d481bc8d6cc26d904b69862'){throw 'LC-I07 external exact-byte fingerprint failed.'}
if($base.decisionPolicyFingerprint-cne'82831d240952746c3207d47e8cd6f8ee22edfcbf2044def0cdb0a2767e3fef4a'){throw 'LC-I11 external exact-byte fingerprint failed.'}
if($base.riskVariantCount-ne21-or$base.representativeRequirementCount-ne21-or$base.representativeRequiredCount-ne9-or$base.evidenceMissingCount-ne12-or$base.evidenceAcceptedCount-ne0-or$base.unityExecutionUnavailableCount-ne0){throw "SP-50 no-package partition failed: risk=$($base.riskVariantCount) required=$($base.representativeRequiredCount) missing=$($base.evidenceMissingCount)."}
if($base.capabilitySuitabilityRequirementCount-ne11-or$base.suitabilityRequiredCount-ne3-or$base.suitabilityMissingCount-ne8-or$base.suitabilityAcceptedCount-ne0-or$base.suitabilityExecutionUnavailableCount-ne0){throw 'SP-51 no-package partition failed.'}
if($base.representativeRequirementCount-ne($base.representativeRequiredCount+$base.evidenceAcceptedCount+$base.evidenceMissingCount+$base.evidenceStaleCount+$base.unityExecutionUnavailableCount+$base.representativeRejectedCount)){throw 'SP-50 conservation failed.'}
if($base.capabilitySuitabilityRequirementCount-ne($base.suitabilityRequiredCount+$base.suitabilityAcceptedCount+$base.suitabilityMissingCount+$base.suitabilityStaleCount+$base.suitabilityExecutionUnavailableCount+$base.suitabilityRejectedCount)){throw 'SP-51 conservation failed.'}
$requirementShape='requirementId,familyId,lane,riskAxisId,riskVariantId,candidateMemberIds,selectedRepresentativeAssetObjectId,selectionRule,requiredEvidenceKinds,expectedInputFingerprint,assessmentStatus,evidence'
$assessmentShape='assessmentId,requirementId,familyId,representativeAssetObjectId,assessmentStatus,evidencePackageId,expectedInputFingerprint,observedInputFingerprint,acceptedEvidenceKinds,missingEvidenceKinds,failureAttribution,nextAllowedAction,evidence'
$suitabilityRequirementShape='suitabilityRequirementId,familyId,capabilityId,routeKind,candidateMemberIds,selectedRepresentativeAssetObjectId,selectionRule,requiredEvidenceKinds,expectedInputFingerprint,assessmentStatus,evidence'
$suitabilityAssessmentShape='suitabilityAssessmentId,suitabilityRequirementId,familyId,capabilityId,routeKind,representativeAssetObjectId,assessmentStatus,evidencePackageId,expectedInputFingerprint,observedInputFingerprint,failureAttribution,nextAllowedAction,evidence'
foreach($row in $base.requirements){if((@($row.PSObject.Properties.Name)-join',')-cne$requirementShape-or$row.requirementId-cnotmatch'^representative-requirement-sha256:[0-9a-f]{64}$'-or$row.expectedInputFingerprint-cnotmatch'^[0-9a-f]{64}$'){throw 'Risk requirement shape or identity failed.'}}
foreach($row in $base.assessments){if((@($row.PSObject.Properties.Name)-join',')-cne$assessmentShape-or$row.assessmentId-cnotmatch'^evidence-assessment-sha256:[0-9a-f]{64}$'){throw 'Risk assessment shape or identity failed.'}}
foreach($row in $base.capabilitySuitabilityRequirements){if((@($row.PSObject.Properties.Name)-join',')-cne$suitabilityRequirementShape-or$row.suitabilityRequirementId-cnotmatch'^capability-suitability-requirement-sha256:[0-9a-f]{64}$'){throw 'Suitability requirement shape or identity failed.'}}
foreach($row in $base.capabilitySuitabilityAssessments){if((@($row.PSObject.Properties.Name)-join',')-cne$suitabilityAssessmentShape-or$row.suitabilityAssessmentId-cnotmatch'^capability-suitability-assessment-sha256:[0-9a-f]{64}$'){throw 'Suitability assessment shape or identity failed.'}}
foreach($requirement in $base.requirements){if($null-ne$requirement.selectedRepresentativeAssetObjectId-and@($memberStatic.memberResults|Where-Object{$_.assetObjectId-ceq$requirement.selectedRepresentativeAssetObjectId-and$_.familyId-ceq$requirement.familyId-and$_.staticStatus-ceq'StaticPassed'}).Count-ne1){throw 'Risk representative selection escaped StaticPassed family membership.'}}
foreach($requirement in $base.capabilitySuitabilityRequirements){if(($requirement.requiredEvidenceKinds-join',')-cne'CapabilitySuitability'){throw 'Capability suitability evidence kind is not strongly typed.'}}

$audioFamily=@($familyRegistry.families|Where-Object lane -CEQ Audio)[0]
$audioRequirements=@($base.capabilitySuitabilityRequirements|Where-Object familyId -CEQ $audioFamily.familyId)
if($audioRequirements.Count-ne4-or@($audioRequirements|Where-Object capabilityId -CEQ PlayableBgmRoute).Count-ne2-or@($audioRequirements|Where-Object capabilityId -CEQ PlayableCombatSfx).Count-ne2-or@($audioRequirements.suitabilityRequirementId|Sort-Object -Unique).Count-ne4){throw 'Audio capability/route suitability independence failed.'}
$loopMutation=Clone-Value $riskFacts;$loopFact=@($loopMutation|Where-Object{$_.familyId-ceq$audioFamily.familyId-and$_.factKind-ceq'LoopMode'})[0];$loopFact.stringValue='OneShot'
$loopResult=Run-Kernel $loopMutation @()
if((@($loopResult.capabilitySuitabilityRequirements.suitabilityRequirementId|Sort-Object)-join',')-cne(@($base.capabilitySuitabilityRequirements.suitabilityRequirementId|Sort-Object)-join',')){throw 'LoopMode changed capability-suitability identity.'}

$riskRequirement=@($base.requirements|Where-Object{$null-ne$_.selectedRepresentativeAssetObjectId})[0]
$suitabilityRequirement=@($base.capabilitySuitabilityRequirements|Where-Object{$null-ne$_.selectedRepresentativeAssetObjectId})[0]
$packages=@(
    (New-Package $riskRequirement RiskVariant C7Unity Unavailable @()),
    (New-Package $suitabilityRequirement CapabilitySuitability G4Unity Unavailable @())
)
$unavailable=Run-Kernel @($riskFacts) $packages
if($unavailable.status-cne'Passed'-or$unavailable.unityExecutionUnavailableCount-ne1-or$unavailable.evidenceMissingCount-ne11-or$unavailable.suitabilityExecutionUnavailableCount-ne1-or$unavailable.suitabilityMissingCount-ne7){throw 'Unavailable package partition failed.'}
if(@($unavailable.assessments|Where-Object assessmentStatus -CEQ EvidenceAccepted).Count-or@($unavailable.capabilitySuitabilityAssessments|Where-Object assessmentStatus -CEQ SuitabilityAccepted).Count){throw 'C5-0 fabricated acceptance.'}
if($unavailable.executorLaunchCount-ne0-or$unavailable.heavyOperationCount-ne0){throw 'C5-0 attempted an executor or heavy operation.'}
$riskPassedObservations=@($riskRequirement.requiredEvidenceKinds|ForEach-Object{[pscustomobject][ordered]@{evidenceKind=$_;outcome='Passed';contentFingerprint=('a'*64);evidence=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')}})
$riskAcceptedPackage=New-Package $riskRequirement RiskVariant StaticHumanReview Completed $riskPassedObservations
$riskAccepted=Run-Kernel @($riskFacts) @($riskAcceptedPackage)
if($riskAccepted.status-cne'Passed'-or$riskAccepted.evidenceAcceptedCount-ne1-or$riskAccepted.evidenceMissingCount-ne11-or@($riskAccepted.assessments|Where-Object assessmentStatus -CEQ EvidenceAccepted)[0].missingEvidenceKinds.Count-ne0){throw 'Fresh complete risk evidence was not accepted.'}
$riskStalePackage=Clone-Value $riskAcceptedPackage;$riskStalePackage.inputFingerprint=('b'*64);$riskStalePackage=Update-PackageId $riskStalePackage;$riskStale=Run-Kernel @($riskFacts) @($riskStalePackage)
if($riskStale.status-cne'Passed'-or$riskStale.evidenceStaleCount-ne1-or$riskStale.evidenceMissingCount-ne11-or@($riskStale.assessments|Where-Object assessmentStatus -CEQ EvidenceStale)[0].failureAttribution-cnotlike'LF-12:*'){throw 'Freshness mismatch did not produce EvidenceStale.'}
$riskRejectedPackage=Clone-Value $riskAcceptedPackage;$riskRejectedPackage.observations[0].outcome='Rejected';$riskRejectedPackage=Update-PackageId $riskRejectedPackage;$riskRejected=Run-Kernel @($riskFacts) @($riskRejectedPackage)
if($riskRejected.status-cne'Passed'-or$riskRejected.representativeRejectedCount-ne1-or$riskRejected.evidenceMissingCount-ne11-or@($riskRejected.assessments|Where-Object assessmentStatus -CEQ RepresentativeRejected)[0].failureAttribution-cnotlike'LF-14:*'){throw 'Rejected risk observation did not remain a valid RepresentativeRejected outcome.'}
$riskInconclusivePackage=Clone-Value $riskAcceptedPackage;$riskInconclusivePackage.observations[0].outcome='Inconclusive';$riskInconclusivePackage=Update-PackageId $riskInconclusivePackage;$riskInconclusive=Run-Kernel @($riskFacts) @($riskInconclusivePackage)
if($riskInconclusive.status-cne'Passed'-or$riskInconclusive.evidenceAcceptedCount-ne0-or$riskInconclusive.evidenceMissingCount-ne12){throw 'Inconclusive risk evidence was inferred as acceptance.'}

$audioBgmRequirement=@($audioRequirements|Where-Object capabilityId -CEQ PlayableBgmRoute|Sort-Object routeKind -CaseSensitive)[0]
$suitabilityObservation=[pscustomobject][ordered]@{evidenceKind='CapabilitySuitability';outcome='Passed';contentFingerprint=('c'*64);evidence=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')}
$suitabilityAcceptedPackage=New-Package $audioBgmRequirement CapabilitySuitability AudioListening Completed @($suitabilityObservation)
$suitabilityAccepted=Run-Kernel @($riskFacts) @($suitabilityAcceptedPackage)
$acceptedSuitability=@($suitabilityAccepted.capabilitySuitabilityAssessments|Where-Object assessmentStatus -CEQ SuitabilityAccepted)
if($suitabilityAccepted.status-cne'Passed'-or$suitabilityAccepted.suitabilityAcceptedCount-ne1-or$suitabilityAccepted.suitabilityMissingCount-ne7-or$acceptedSuitability.Count-ne1-or$acceptedSuitability[0].suitabilityRequirementId-cne$audioBgmRequirement.suitabilityRequirementId){throw 'Fresh capability suitability evidence was not isolated to its exact requirement.'}
if(@($suitabilityAccepted.capabilitySuitabilityAssessments|Where-Object{$_.familyId-ceq$audioFamily.familyId-and$_.assessmentStatus-ceq'SuitabilityAccepted'}).Count-ne1){throw 'BGM suitability evidence crossed a capability or route boundary.'}
$suitabilityStalePackage=Clone-Value $suitabilityAcceptedPackage;$suitabilityStalePackage.inputFingerprint=('d'*64);$suitabilityStalePackage=Update-PackageId $suitabilityStalePackage;$suitabilityStale=Run-Kernel @($riskFacts) @($suitabilityStalePackage)
if($suitabilityStale.status-cne'Passed'-or$suitabilityStale.suitabilityStaleCount-ne1-or$suitabilityStale.suitabilityMissingCount-ne7){throw 'Suitability freshness mismatch did not produce SuitabilityStale.'}
$suitabilityRejectedPackage=Clone-Value $suitabilityAcceptedPackage;$suitabilityRejectedPackage.observations[0].outcome='Rejected';$suitabilityRejectedPackage=Update-PackageId $suitabilityRejectedPackage;$suitabilityRejected=Run-Kernel @($riskFacts) @($suitabilityRejectedPackage)
if($suitabilityRejected.status-cne'Passed'-or$suitabilityRejected.suitabilityRejectedCount-ne1-or$suitabilityRejected.suitabilityMissingCount-ne7){throw 'Rejected suitability escaped its exact route outcome.'}
$suitabilityInconclusivePackage=Clone-Value $suitabilityAcceptedPackage;$suitabilityInconclusivePackage.observations[0].outcome='Inconclusive';$suitabilityInconclusivePackage=Update-PackageId $suitabilityInconclusivePackage;$suitabilityInconclusive=Run-Kernel @($riskFacts) @($suitabilityInconclusivePackage)
if($suitabilityInconclusive.status-cne'Passed'-or$suitabilityInconclusive.suitabilityAcceptedCount-ne0-or$suitabilityInconclusive.suitabilityMissingCount-ne8){throw 'Inconclusive suitability was inferred as acceptance.'}
$unknownPackage=Clone-Value $suitabilityAcceptedPackage;$unknownPackage.requirementId=('capability-suitability-requirement-sha256:'+('e'*64));$unknownPackage=Update-PackageId $unknownPackage;$identityFailure=Run-Kernel @($riskFacts) @($unknownPackage)
if($identityFailure.status-cne'Failed'-or$identityFailure.issues-cnotcontains'Evidence package does not resolve to a C5 requirement.'-or$identityFailure.suitabilityAcceptedCount-ne0){throw 'Unknown capability/route evidence did not fail as LF-15 contract evidence.'}
$wrongKindPackage=Clone-Value $suitabilityAcceptedPackage;$wrongKindPackage.observations[0].evidenceKind='VisibleRender';$wrongKindPackage=Update-PackageId $wrongKindPackage;$wrongKind=Run-Kernel @($riskFacts) @($wrongKindPackage)
if($wrongKind.status-cne'Failed'-or$wrongKind.issues-cnotcontains'Capability suitability package identity mismatch.'-or$wrongKind.suitabilityAcceptedCount-ne0){throw 'Wrong capability-suitability observation kind was reused.'}
$staleWrongKindPackage=Clone-Value $wrongKindPackage;$staleWrongKindPackage.inputFingerprint=('f'*64);$staleWrongKindPackage=Update-PackageId $staleWrongKindPackage;$staleWrongKind=Run-Kernel @($riskFacts) @($staleWrongKindPackage)
if($staleWrongKind.status-cne'Failed'-or$staleWrongKind.issues-cnotcontains'Capability suitability package identity mismatch.'-or$staleWrongKind.suitabilityStaleCount-ne0){throw 'Staleness masked an LF-15 capability evidence identity failure.'}
$repeat=Run-Kernel @($riskFacts) @();if(($base|ConvertTo-Json -Depth 100)-cne($repeat|ConvertTo-Json -Depth 100)){throw 'C5-0 determinism failed.'}
if(Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')){throw 'C5-0 touched publication state.'}

'status=Passed'
'riskVariantCount=21'
'representativePartition=9/12/0/0/0/0'
'capabilitySuitabilityPartition=3/8/0/0/0/0'
'unavailableRiskCount=1'
'unavailableSuitabilityCount=1'
'acceptedStaleRejectedRiskCount=1/1/1'
'acceptedStaleRejectedSuitabilityCount=1/1/1'
'audioSuitabilityRequirementCount=4'
'executorLaunchCount=0'
'publicationWriteCount=0'
