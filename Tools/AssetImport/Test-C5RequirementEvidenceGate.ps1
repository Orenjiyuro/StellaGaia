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
    [pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T05:00:00Z';evidencePackageId="evidence-package-sha256:$(Get-Sha256 $riskRequirement.requirementId)";requirementId=$riskRequirement.requirementId;requirementKind='RiskVariant';representativeAssetObjectId=$riskRequirement.selectedRepresentativeAssetObjectId;executorKind='C7Unity';executionStatus='Unavailable';inputFingerprint=$riskRequirement.expectedInputFingerprint;toolVersions=@('FixtureUnavailable:1.0.0');observations=@();evidencePaths=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')},
    [pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T05:00:00Z';evidencePackageId="evidence-package-sha256:$(Get-Sha256 $suitabilityRequirement.suitabilityRequirementId)";requirementId=$suitabilityRequirement.suitabilityRequirementId;requirementKind='CapabilitySuitability';representativeAssetObjectId=$suitabilityRequirement.selectedRepresentativeAssetObjectId;executorKind='G4Unity';executionStatus='Unavailable';inputFingerprint=$suitabilityRequirement.expectedInputFingerprint;toolVersions=@('FixtureUnavailable:1.0.0');observations=@();evidencePaths=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')}
)
$unavailable=Run-Kernel @($riskFacts) $packages
if($unavailable.status-cne'Passed'-or$unavailable.unityExecutionUnavailableCount-ne1-or$unavailable.evidenceMissingCount-ne11-or$unavailable.suitabilityExecutionUnavailableCount-ne1-or$unavailable.suitabilityMissingCount-ne7){throw 'Unavailable package partition failed.'}
if(@($unavailable.assessments|Where-Object assessmentStatus -CEQ EvidenceAccepted).Count-or@($unavailable.capabilitySuitabilityAssessments|Where-Object assessmentStatus -CEQ SuitabilityAccepted).Count){throw 'C5-0 fabricated acceptance.'}
if($unavailable.executorLaunchCount-ne0-or$unavailable.heavyOperationCount-ne0){throw 'C5-0 attempted an executor or heavy operation.'}
$completedPackages=Clone-Value $packages;$completedPackages[0].executionStatus='Completed';$completedPackages[0].observations=@([pscustomobject][ordered]@{evidenceKind='VisibleRender';outcome='Passed';contentFingerprint=('a'*64);evidence=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')})
$completed=Run-Kernel @($riskFacts) $completedPackages
if($completed.status-cne'Failed'-or$completed.issues-cnotcontains'C5-0 accepts only exact Unavailable evidence packages.'-or$completed.evidenceAcceptedCount-ne0){throw 'Completed package was not fail-closed in C5-0.'}
$repeat=Run-Kernel @($riskFacts) @();if(($base|ConvertTo-Json -Depth 100)-cne($repeat|ConvertTo-Json -Depth 100)){throw 'C5-0 determinism failed.'}
if(Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')){throw 'C5-0 touched publication state.'}

'status=Passed'
'riskVariantCount=21'
'representativePartition=9/12/0/0/0/0'
'capabilitySuitabilityPartition=3/8/0/0/0/0'
'unavailableRiskCount=1'
'unavailableSuitabilityCount=1'
'audioSuitabilityRequirementCount=4'
'executorLaunchCount=0'
'publicationWriteCount=0'
