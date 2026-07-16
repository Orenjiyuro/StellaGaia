[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module=Import-Module (Join-Path $PSScriptRoot 'C5RequirementEvidenceGate.psm1') -Force -PassThru
if($module.ExportedFunctions.Keys-cnotcontains'Invoke-C5RequirementEvidenceGate'){throw 'C5-2 output-vector gate entry point is missing.'}
$moduleAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'C5RequirementEvidenceGate.psm1'),[ref]$null,[ref]$null)
if(@($moduleAst.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-ceq'Sort-Object'},$true)).Count){throw 'C5 module reintroduced culture-sensitive Sort-Object.'}
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
function CanonicalJson($Value){(($Value|ConvertTo-Json -Depth 100)-replace"`r`n","`n")+"`n"}
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
    $entryList=[Collections.Generic.List[object]]::new();foreach($path in $paths){$entryList.Add([pscustomobject][ordered]@{path=$path;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repositoryRoot $path)).Hash.ToLowerInvariant()})};$entryList.Sort([Comparison[object]]{param($a,$b)[StringComparer]::Ordinal.Compare([string]$a.path,[string]$b.path)});$entries=@($entryList.ToArray())
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
    $packageBytes=@($Packages|ForEach-Object{CanonicalJson $_})
    Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows $Facts -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages $Packages -EvidencePackageBytes $packageBytes
}

$base=Run-Kernel @($riskFacts) @()
if($base.status-cne'Passed'){throw "C5-0 base failed: $($base.issues -join '; ')"}
$unboundLanePolicy=Clone-Value $lanePolicy;$unboundLanePolicy.policySetVersion='9.9.9'
$unboundLane=Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows @($riskFacts) -LanePolicyRegistry $unboundLanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages @() -EvidencePackageBytes @()
if($unboundLane.status-cne'Failed'-or$unboundLane.issues-cnotcontains'LC-I07 execution object does not match accepted bytes.'){throw 'C5 LC-I07 object/bytes binding RED failed.'}
$unboundDecisionPolicy=Clone-Value $decisionPolicy;$unboundDecisionPolicy.decisionPolicyVersion='9.9.9'
$unboundDecision=Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows @($riskFacts) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $unboundDecisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages @() -EvidencePackageBytes @()
if($unboundDecision.status-cne'Failed'-or$unboundDecision.issues-cnotcontains'LC-I11 execution object does not match accepted bytes.'){throw 'C5 LC-I11 object/bytes binding RED failed.'}
$tuplePolicy=Clone-Value $lanePolicy;$tupleAxis=@($tuplePolicy.policies|Where-Object lane -CEQ Audio)[0].riskAxisDefinitions[0];[Array]::Reverse($tupleAxis.sourceFactKinds)
$tupleBytes=(($tuplePolicy|ConvertTo-Json -Depth 100)-replace"`r`n","`n")+"`n"
$tupleResult=Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows @($riskFacts) -LanePolicyRegistry $tuplePolicy -LanePolicyBytes $tupleBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages @() -EvidencePackageBytes @()
$baseAudioVariants=@($base.requirements|Where-Object{$_.familyId-ceq(@($familyRegistry.families|Where-Object lane -CEQ Audio)[0].familyId)}|ForEach-Object riskVariantId)
$tupleAudioVariants=@($tupleResult.requirements|Where-Object{$_.familyId-ceq(@($familyRegistry.families|Where-Object lane -CEQ Audio)[0].familyId)}|ForEach-Object riskVariantId)
if((@($baseAudioVariants|Sort-Object)-join',')-ceq(@($tupleAudioVariants|Sort-Object)-join',')){throw 'C5 Tuple positional identity RED failed.'}
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
$differentRiskBytes=Clone-Value $riskAcceptedPackage;$differentRiskBytes.generatedAt='2026-07-16T05:00:01Z'
$unboundEvidence=Invoke-C5RequirementEvidenceKernel -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows @($riskFacts) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages @($riskAcceptedPackage) -EvidencePackageBytes @((CanonicalJson $differentRiskBytes))
if($unboundEvidence.status-cne'Failed'-or$unboundEvidence.issues-cnotcontains'LC-I10 execution object does not match accepted bytes.'){throw 'C5 LC-I10 object/bytes binding failed.'}
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

$directInputSpecs=[ordered]@{
    'C3-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json';'C3-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json';'C3-O03'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json';'C3-O04-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json';'C3-O04-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
    'C4-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json';'C4-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json';'C4-O03-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json';'C4-O03-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'
    'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json';'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json';'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json';'LC-I11'='docs/asset-migration/schemas/c3-c6-decision-policy-registry.json';'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
}
$directInputs=@($directInputSpecs.GetEnumerator()|ForEach-Object{[pscustomobject][ordered]@{artifactId=[string]$_.Key;path=[string]$_.Value;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repositoryRoot $_.Value)).Hash.ToLowerInvariant()}})
$stage=[pscustomobject][ordered]@{generatedAt='2026-07-16T06:00:00Z';snapshotId=$familyRegistry.snapshotId;toolVersions=@('C5RequirementEvidenceGate:1.0.0');directInputs=$directInputs}
function New-EvidenceAuthority($Packages,[string]$RequirementGenerationFingerprint){
    $packageBytes=@($Packages|ForEach-Object{CanonicalJson $_})
    $entryList=[Collections.Generic.List[object]]::new()
    for($index=0;$index-lt$Packages.Count;$index++){
        $package=$Packages[$index];$suffix=([string]$package.evidencePackageId).Substring('evidence-package-sha256:'.Length)
        $entryList.Add([pscustomobject][ordered]@{path="Tools/AssetImport/Fixtures/FamilyQualificationGate/Evidence/$suffix.json";sha256=Get-Sha256 $packageBytes[$index];evidencePackageId=$package.evidencePackageId;requirementId=$package.requirementId})
    }
    $entryList.Sort([Comparison[object]]{param($a,$b)[StringComparer]::Ordinal.Compare([string]$a.path,[string]$b.path)})
    $manifest=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T05:30:00Z';inputFingerprint=$RequirementGenerationFingerprint;entries=@($entryList.ToArray())}
    $manifestBytes=CanonicalJson $manifest
    $authorityStage=Clone-Value $stage
    $authorityStage.directInputs=@($authorityStage.directInputs)+@([pscustomobject][ordered]@{artifactId='LC-I09';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/c7-evidence-manifest.json';sha256=Get-Sha256 $manifestBytes})+@($manifest.entries|ForEach-Object{[pscustomobject][ordered]@{artifactId='LC-I10';path=$_.path;sha256=$_.sha256}})
    [pscustomobject]@{manifest=$manifest;manifestBytes=$manifestBytes;packages=$Packages;packageBytes=$packageBytes;stage=$authorityStage}
}
function Run-Gate($Packages,$StageValue=$stage,$Manifest=$null,$ManifestBytes=$null,$PackageBytes=$null){
    if($null-eq$PackageBytes){$PackageBytes=@($Packages|ForEach-Object{CanonicalJson $_})}
    Invoke-C5RequirementEvidenceGate -FamilyRegistry $familyRegistry -MemberStaticQualification $memberStatic -RiskFactRows @($riskFacts) -LanePolicyRegistry $lanePolicy -LanePolicyBytes $lanePolicyBytes -DecisionPolicyRegistry $decisionPolicy -DecisionPolicyBytes $decisionPolicyBytes -RepresentativeStatuses @($vocabulary.representativeAssessment) -SuitabilityStatuses @($vocabulary.capabilitySuitabilityStatus) -EvidenceManifest $Manifest -EvidenceManifestBytes $ManifestBytes -EvidencePackages $Packages -EvidencePackageBytes $PackageBytes -Stage $StageValue
}
$gate=Run-Gate @()
if($gate.gateStatus-cne'Passed'-or(@($gate.PSObject.Properties.Name)-join',')-cne'gateStatus,representativeRequirements,evidenceAssessment,c7EvidenceRequest,summary,report,texts,executorLaunchCount,heavyOperationCount'){throw 'C5-2 Passed result vector shape failed.'}
if($gate.summary.failureAccounting.outputCandidateCount-ne4-or$gate.summary.failureAccounting.projectedOutputCount-ne4-or$gate.summary.failureAccounting.outputFailureCount-ne0-or$gate.summary.directOutputs.Count-ne4){throw 'C5-2 Passed output conservation failed.'}
$supportPrefix='schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint'
if((@($gate.representativeRequirements.PSObject.Properties.Name)-join',')-cne"$supportPrefix,requirements,capabilitySuitabilityRequirements"-or(@($gate.evidenceAssessment.PSObject.Properties.Name)-join',')-cne"$supportPrefix,assessments,capabilitySuitabilityAssessments"-or(@($gate.c7EvidenceRequest.PSObject.Properties.Name)-join',')-cne"$supportPrefix,requests"){throw 'C5 success artifact top-level shape failed.'}
if((@($gate.summary.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision'){throw 'C5-O04 summary top-level shape failed.'}
$coverageShape='familyCount,riskVariantCount,representativeRequirementCount,representativeRequiredCount,evidenceAcceptedCount,evidenceMissingCount,evidenceStaleCount,unityExecutionUnavailableCount,representativeRejectedCount,capabilitySuitabilityRequirementCount,suitabilityRequiredCount,suitabilityAcceptedCount,suitabilityMissingCount,suitabilityStaleCount,suitabilityExecutionUnavailableCount,suitabilityRejectedCount,c7RequestCount'
$accountingShape='inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,notEvaluatedInputSubjectCount,outputCandidateCount,projectedOutputCount,outputFailureCount,issueCount,gateStatus,inputFailures,inputSuppressions,outputFailures'
if((@($gate.summary.coverage.PSObject.Properties.Name)-join',')-cne$coverageShape-or(@($gate.summary.failureAccounting.PSObject.Properties.Name)-join',')-cne$accountingShape){throw 'C5-O04 coverage/accounting shape failed.'}
if($gate.representativeRequirements.requirements.Count-ne21-or$gate.representativeRequirements.capabilitySuitabilityRequirements.Count-ne11-or$gate.evidenceAssessment.assessments.Count-ne21-or$gate.evidenceAssessment.capabilitySuitabilityAssessments.Count-ne11-or$gate.c7EvidenceRequest.requests.Count-ne20){throw 'C5 success artifact subject counts failed.'}
if($gate.summary.coverage.representativeRequirementCount-ne($gate.summary.coverage.representativeRequiredCount+$gate.summary.coverage.evidenceAcceptedCount+$gate.summary.coverage.evidenceMissingCount+$gate.summary.coverage.evidenceStaleCount+$gate.summary.coverage.unityExecutionUnavailableCount+$gate.summary.coverage.representativeRejectedCount)){throw 'C5-O04 SP-50 conservation failed.'}
if($gate.summary.coverage.capabilitySuitabilityRequirementCount-ne($gate.summary.coverage.suitabilityRequiredCount+$gate.summary.coverage.suitabilityAcceptedCount+$gate.summary.coverage.suitabilityMissingCount+$gate.summary.coverage.suitabilityStaleCount+$gate.summary.coverage.suitabilityExecutionUnavailableCount+$gate.summary.coverage.suitabilityRejectedCount)){throw 'C5-O04 SP-51 conservation failed.'}
$requestShape='requirementId,requirementKind,familyId,lane,capabilityId,routeKind,representativeAssetObjectId,requiredEvidenceKinds,reasonCode,priority,evidence'
foreach($request in $gate.c7EvidenceRequest.requests){if((@($request.PSObject.Properties.Name)-join',')-cne$requestShape-or$request.reasonCode -CNotIn @('EvidenceMissing','EvidenceStale','UnityExecutionUnavailable','SuitabilityMissing','SuitabilityStale','SuitabilityExecutionUnavailable')){throw 'C5-O03 request shape or reason failed.'};if($request.requirementKind-ceq'RiskVariant'-and($null-ne$request.capabilityId-or$null-ne$request.routeKind-or$request.priority-cne'Coverage')){throw 'C5-O03 risk request typing failed.'};if($request.requirementKind-ceq'CapabilitySuitability'-and($null-eq$request.capabilityId-or$null-eq$request.routeKind-or$request.priority-cne'RequiredCapability')){throw 'C5-O03 suitability request typing failed.'}}
if($gate.summary.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$gate.summary.policySetFingerprint-cne'7fdde7cb9d709be5e11fb3391053b8f0cb3e26348d481bc8d6cc26d904b69862'-or$gate.summary.decisionPolicyFingerprint-cne'82831d240952746c3207d47e8cd6f8ee22edfcbf2044def0cdb0a2767e3fef4a'){throw 'C5 exact-byte input/policy fingerprints failed.'}
$authority=New-EvidenceAuthority @($riskAcceptedPackage) $gate.summary.inputFingerprint
$authorityGate=Run-Gate $authority.packages $authority.stage $authority.manifest $authority.manifestBytes $authority.packageBytes
if($authorityGate.gateStatus-cne'Passed'-or$authorityGate.summary.directInputs.Count-ne16-or$authorityGate.summary.inputFingerprint-ceq$gate.summary.inputFingerprint-or$authorityGate.summary.coverage.evidenceAcceptedCount-ne1-or$authorityGate.summary.coverage.evidenceMissingCount-ne11){throw 'LC-I09/LC-I10 authority did not produce one exact accepted evidence result.'}
$newGenerationPackage=Clone-Value $riskAcceptedPackage;$newGenerationPackage.generatedAt='2026-07-16T05:00:02Z'
$newAuthority=New-EvidenceAuthority @($newGenerationPackage) $gate.summary.inputFingerprint
$newGenerationGate=Run-Gate $newAuthority.packages $newAuthority.stage $newAuthority.manifest $newAuthority.manifestBytes $newAuthority.packageBytes
if($newGenerationGate.gateStatus-cne'Passed'-or$newGenerationGate.summary.coverage.evidenceAcceptedCount-ne1-or$newGenerationGate.summary.inputFingerprint-ceq$authorityGate.summary.inputFingerprint){throw 'LC-I10 exact-byte generation change did not refresh C5 inputFingerprint.'}
$wrongManifestFingerprint=Clone-Value $authority.manifest;$wrongManifestFingerprint.inputFingerprint=('0'*64);$wrongManifestBytes=CanonicalJson $wrongManifestFingerprint
$wrongManifestStage=Clone-Value $authority.stage;@($wrongManifestStage.directInputs|Where-Object artifactId -CEQ 'LC-I09')[0].sha256=Get-Sha256 $wrongManifestBytes
$wrongManifestGate=Run-Gate $authority.packages $wrongManifestStage $wrongManifestFingerprint $wrongManifestBytes $authority.packageBytes
if($wrongManifestGate.gateStatus-cne'Failed'-or$wrongManifestGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-15:C5:EvidenceContract'){throw 'LC-I09 stale requirement-generation fingerprint did not fail closed.'}
$unboundManifest=Clone-Value $authority.manifest;$unboundManifest.generatedAt='2026-07-16T05:30:01Z'
$unboundManifestGate=Run-Gate $authority.packages $authority.stage $unboundManifest $authority.manifestBytes $authority.packageBytes
if($unboundManifestGate.gateStatus-cne'Failed'){throw 'LC-I09 object/bytes mismatch did not fail closed.'}
$wrongManifestDirectStage=Clone-Value $authority.stage;@($wrongManifestDirectStage.directInputs|Where-Object artifactId -CEQ 'LC-I09')[0].sha256=('0'*64)
$wrongManifestDirectGate=Run-Gate $authority.packages $wrongManifestDirectStage $authority.manifest $authority.manifestBytes $authority.packageBytes
if($wrongManifestDirectGate.gateStatus-cne'Failed'){throw 'LC-I09 direct-input SHA mismatch did not fail closed.'}
$wrongEntrySha=Clone-Value $authority.manifest;$wrongEntrySha.entries[0].sha256=('0'*64);$wrongEntryBytes=CanonicalJson $wrongEntrySha
$wrongEntryStage=Clone-Value $authority.stage;@($wrongEntryStage.directInputs|Where-Object artifactId -CEQ 'LC-I09')[0].sha256=Get-Sha256 $wrongEntryBytes
$wrongEntryGate=Run-Gate $authority.packages $wrongEntryStage $wrongEntrySha $wrongEntryBytes $authority.packageBytes
if($wrongEntryGate.gateStatus-cne'Failed'){throw 'LC-I09 package SHA mismatch did not fail closed.'}
$missingPackageInputStage=Clone-Value $authority.stage;$missingPackageInputStage.directInputs=@($missingPackageInputStage.directInputs|Where-Object artifactId -CNE 'LC-I10')
$missingPackageInputGate=Run-Gate $authority.packages $missingPackageInputStage $authority.manifest $authority.manifestBytes $authority.packageBytes
if($missingPackageInputGate.gateStatus-cne'Failed'){throw 'Missing LC-I10 direct input did not fail closed.'}
$orphanPackageGate=Run-Gate @($riskAcceptedPackage)
if($orphanPackageGate.gateStatus-cne'Failed'){throw 'LC-I10 package without LC-I09 authority did not fail closed.'}
if((@($gate.representativeRequirements.requirements.requirementId|Sort-Object)-join',')-cne(@($base.requirements.requirementId|Sort-Object)-join',')){throw 'C5 gate changed kernel requirement identities.'}
if($gate.report.Contains("`r")-or-not$gate.report.EndsWith("`n")-or$gate.report.EndsWith("`n`n")){throw 'C5 report byte format failed.'}
$outputTextById=@{'C5-O01'=$gate.texts.representativeRequirements;'C5-O02'=$gate.texts.evidenceAssessment;'C5-O03'=$gate.texts.c7EvidenceRequest;'C5-O04-Report'=$gate.report}
foreach($output in $gate.summary.directOutputs){if($output.sha256-cne(Get-Sha256 $outputTextById[$output.artifactId])){throw "C5 direct output hash mismatch: $($output.artifactId)"}}
$artifactShape='artifactId,path,sha256';foreach($entry in @($gate.summary.directInputs)+@($gate.summary.directOutputs)){if((@($entry.PSObject.Properties.Name)-join',')-cne$artifactShape){throw 'C5 direct artifact row shape failed.'}}
for($index=1;$index-lt$gate.summary.directInputs.Count;$index++){if([StringComparer]::Ordinal.Compare([string]$gate.summary.directInputs[$index-1].path,[string]$gate.summary.directInputs[$index].path)-ge0){throw 'C5 direct inputs are not Ordinal sorted.'}}
$changedStage=Clone-Value $stage;$changedStage.directInputs[0].sha256=('0'*64);$changedGate=Run-Gate @() $changedStage
if($changedGate.gateStatus-cne'Passed'-or$changedGate.summary.inputFingerprint-ceq$gate.summary.inputFingerprint){throw 'LX-HI-14 C5 direct-input mutation sensitivity failed.'}
$missingInputStage=Clone-Value $stage;$missingInputStage.directInputs=@($missingInputStage.directInputs|Select-Object -Skip 1);$rejected=$false;try{Run-Gate @() $missingInputStage|Out-Null}catch{$rejected=$_.Exception.Message-ceq'C5 direct input set is invalid.'};if(-not$rejected){throw 'C5 missing direct input was not rejected.'}
$fixturePayloads=[ordered]@{'valid-representative-requirements.json'=$gate.texts.representativeRequirements;'valid-evidence-assessment.json'=$gate.texts.evidenceAssessment;'valid-c7-evidence-request.json'=$gate.texts.c7EvidenceRequest;'valid-c5-summary.json'=$gate.texts.summary;'valid-c5-report.md'=$gate.report}
if($UpdateFixtures){$utf8=[Text.UTF8Encoding]::new($false);foreach($name in $fixturePayloads.Keys){[IO.File]::WriteAllText((Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"),$fixturePayloads[$name],$utf8)};'fixtures=Updated';return}
foreach($name in $fixturePayloads.Keys){$path=Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name";if(-not(Test-Path -LiteralPath $path)){throw "C5-2 expected fixture missing: $name"};if([IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false))-cne$fixturePayloads[$name]){throw "C5-2 fixture bytes mismatch: $name"}}
$failedGate=Run-Gate @($unknownPackage)
if($failedGate.gateStatus-cne'Failed'-or$null-ne$failedGate.representativeRequirements-or$null-ne$failedGate.evidenceAssessment-or$null-ne$failedGate.c7EvidenceRequest-or$failedGate.summary.failureAccounting.outputCandidateCount-ne4-or$failedGate.summary.failureAccounting.projectedOutputCount-ne1-or$failedGate.summary.failureAccounting.outputFailureCount-ne3-or$failedGate.summary.failureAccounting.issueCount-ne1-or$failedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-15:C5:EvidenceContract'-or$failedGate.summary.directOutputs.Count-ne1){throw 'C5-2 LF-15 diagnostic-only vector failed.'}
$accountingRowShape='recordId,stageId,subjectKind,subjectId,reasonCode,attribution,evidence';if((@($failedGate.summary.failureAccounting.inputFailures[0].PSObject.Properties.Name)-join',')-cne$accountingRowShape-or$failedGate.summary.failureAccounting.inputFailures[0].subjectKind-cne'ConservationCheck'){throw 'C5 LF-15 accounting row shape failed.'};foreach($failure in $failedGate.summary.failureAccounting.outputFailures){if((@($failure.PSObject.Properties.Name)-join',')-cne$accountingRowShape-or$failure.reasonCode-cne'SuppressedByGate'){throw 'C5 suppressed output accounting failed.'}}
if($gate.executorLaunchCount-ne0-or$gate.heavyOperationCount-ne0-or$failedGate.executorLaunchCount-ne0-or$failedGate.heavyOperationCount-ne0){throw 'C5-2 attempted C7/G4 or a heavy operation.'}
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
'c7RequestCount=20'
'passedOutputVector=4/4/0'
'failedOutputVector=4/1/3'
'executorLaunchCount=0'
'publicationWriteCount=0'
