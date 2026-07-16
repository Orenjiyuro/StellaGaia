Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$script:C5Utf8=[Text.UTF8Encoding]::new($false)
$script:C5Ordinal=[StringComparer]::Ordinal

function Get-C5Sha256([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C5Utf8.GetBytes($Text))).ToLowerInvariant()}
function ConvertTo-C5ScalarLine([string]$Name,[string]$Value){if($null-eq$Value-or$Value.IndexOfAny([char[]]@([char]0,"`r","`n"))-ge0){throw"Invalid framed scalar: $Name"};"${Name}:$($script:C5Utf8.GetByteCount($Value)):${Value}`n"}
function ConvertTo-C5NullableLine([string]$Name,[AllowNull()][object]$Value){if($null-eq$Value){return "${Name}.null:1:1`n"};"${Name}.null:1:0`n$(ConvertTo-C5ScalarLine $Name ([string]$Value))"}
function Add-C5SetFrame([string]$Name,[string[]]$Values){$ordered=@($Values|Sort-Object -CaseSensitive -Unique);$count=[string]$ordered.Count;$text="${Name}.count:$($script:C5Utf8.GetByteCount($count)):$count`n";for($i=0;$i-lt$ordered.Count;$i++){$text+=ConvertTo-C5ScalarLine "${Name}[$i]" $ordered[$i]};$text}
function Add-C5Issue([Collections.Generic.List[string]]$Issues,[string]$Issue){if(-not$Issues.Contains($Issue)){$Issues.Add($Issue)}}
function Test-C5ExactArray([object[]]$Actual,[string[]]$Expected){if($Actual.Count-ne$Expected.Count){return $false};for($i=0;$i-lt$Expected.Count;$i++){if([string]$Actual[$i]-cne$Expected[$i]){return $false}};$true}

function ConvertTo-C5FactFrame([object]$Fact){
    $text="C5RiskVariantFactV1`n"
    foreach($name in @('factKind','factStatus','valueKind')){$text+=ConvertTo-C5ScalarLine $name ([string]$Fact.$name)}
    foreach($name in @('stringValue','integerValue','booleanValue')){$text+=ConvertTo-C5NullableLine $name $Fact.$name}
    $text+=Add-C5SetFrame idValues @($Fact.idValues)
    $text
}

function Get-C5RiskVariantId([string]$FamilyId,[string]$RiskAxisId,[object[]]$Facts){
    $ordered=@($Facts|Sort-Object factKind -CaseSensitive);$text="C5RiskVariantV1`n"+(ConvertTo-C5ScalarLine familyId $FamilyId)+(ConvertTo-C5ScalarLine riskAxisId $RiskAxisId)
    $count=[string]$ordered.Count;$text+="sourceFacts.count:$($script:C5Utf8.GetByteCount($count)):$count`n"
    for($i=0;$i-lt$ordered.Count;$i++){$nested=ConvertTo-C5FactFrame $ordered[$i];$text+="sourceFacts[$i]:$($script:C5Utf8.GetByteCount($nested)):$nested`n"}
    Get-C5Sha256 $text
}

function Get-C5RequirementId([string]$FamilyId,[string]$RiskAxisId,[string]$RiskVariantId,[string[]]$Candidates,[string[]]$EvidenceKinds){
    $text="C5RepresentativeRequirementV1`n"+(ConvertTo-C5ScalarLine familyId $FamilyId)+(ConvertTo-C5ScalarLine riskAxisId $RiskAxisId)+(ConvertTo-C5ScalarLine riskVariantId $RiskVariantId)+(Add-C5SetFrame candidateMemberIds $Candidates)+(Add-C5SetFrame requiredEvidenceKinds $EvidenceKinds)
    "representative-requirement-sha256:$(Get-C5Sha256 $text)"
}

function Get-C5SuitabilityRequirementId([string]$DecisionFingerprint,[string]$FamilyId,[string]$CapabilityId,[string]$RouteKind,[string[]]$Candidates,[AllowNull()][object]$Selected,[string[]]$EvidenceKinds){
    $text="C5CapabilitySuitabilityRequirementV1`n"+(ConvertTo-C5ScalarLine decisionPolicyFingerprint $DecisionFingerprint)+(ConvertTo-C5ScalarLine familyId $FamilyId)+(ConvertTo-C5ScalarLine capabilityId $CapabilityId)+(ConvertTo-C5ScalarLine routeKind $RouteKind)+(Add-C5SetFrame candidateMemberIds $Candidates)+(ConvertTo-C5NullableLine selectedRepresentativeAssetObjectId $Selected)+(Add-C5SetFrame requiredEvidenceKinds $EvidenceKinds)
    "capability-suitability-requirement-sha256:$(Get-C5Sha256 $text)"
}

function Get-C5ExpectedInputFingerprint([string]$PolicyFingerprint,[string]$DecisionFingerprint,[string]$RequirementId,[string]$RequirementKind,[AllowNull()][object]$Representative,[string]$InputStaticFingerprint,[string[]]$EvidenceKinds){
    $text="C5EvidenceRequirementInputV1`n"+(ConvertTo-C5ScalarLine policySetFingerprint $PolicyFingerprint)+(ConvertTo-C5ScalarLine decisionPolicyFingerprint $DecisionFingerprint)+(ConvertTo-C5ScalarLine requirementId $RequirementId)+(ConvertTo-C5ScalarLine requirementKind $RequirementKind)+(ConvertTo-C5NullableLine representativeAssetObjectId $Representative)+(ConvertTo-C5ScalarLine inputStaticFingerprint $InputStaticFingerprint)+(Add-C5SetFrame requiredEvidenceKinds $EvidenceKinds)
    Get-C5Sha256 $text
}

function Get-C5AssessmentId([string]$RequirementId,[AllowNull()][object]$Representative,[string]$Status,[AllowNull()][object]$PackageId,[string]$Expected,[AllowNull()][object]$Observed){
    $text="C5EvidenceAssessmentV1`n"+(ConvertTo-C5ScalarLine requirementId $RequirementId)+(ConvertTo-C5NullableLine representativeAssetObjectId $Representative)+(ConvertTo-C5ScalarLine assessmentStatus $Status)+(ConvertTo-C5NullableLine evidencePackageId $PackageId)+(ConvertTo-C5ScalarLine expectedInputFingerprint $Expected)+(ConvertTo-C5NullableLine observedInputFingerprint $Observed)
    "evidence-assessment-sha256:$(Get-C5Sha256 $text)"
}

function Get-C5SuitabilityAssessmentId([string]$RequirementId,[string]$Status,[AllowNull()][object]$PackageId,[string]$Expected,[AllowNull()][object]$Observed){
    $text="C5CapabilitySuitabilityAssessmentV1`n"+(ConvertTo-C5ScalarLine suitabilityRequirementId $RequirementId)+(ConvertTo-C5ScalarLine assessmentStatus $Status)+(ConvertTo-C5NullableLine evidencePackageId $PackageId)+(ConvertTo-C5ScalarLine expectedInputFingerprint $Expected)+(ConvertTo-C5NullableLine observedInputFingerprint $Observed)
    "capability-suitability-assessment-sha256:$(Get-C5Sha256 $text)"
}

function Get-C5PackageAssessment([string]$RequirementId,[string]$RequirementKind,[AllowNull()][object]$Representative,[string]$Expected,[object[]]$Packages,[string]$RequiredStatus,[string]$MissingStatus,[string]$UnavailableStatus,[Collections.Generic.List[string]]$Issues){
    if($null-eq$Representative){return [pscustomobject]@{status=$RequiredStatus;package=$null}}
    $matching=@($Packages|Where-Object requirementId -CEQ $RequirementId)
    if($matching.Count-eq0){return [pscustomobject]@{status=$MissingStatus;package=$null}}
    if($matching.Count-ne1){Add-C5Issue $Issues 'Duplicate evidence package requirementId.';return [pscustomobject]@{status=$MissingStatus;package=$null}}
    $package=$matching[0]
    if((@($package.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,evidencePackageId,requirementId,requirementKind,representativeAssetObjectId,executorKind,executionStatus,inputFingerprint,toolVersions,observations,evidencePaths'){Add-C5Issue $Issues 'Invalid evidence package shape.';return [pscustomobject]@{status=$MissingStatus;package=$null}}
    if($package.requirementKind-cne$RequirementKind-or$package.representativeAssetObjectId-cne$Representative-or$package.inputFingerprint-cne$Expected-or$package.evidencePackageId-cnotmatch'^evidence-package-sha256:[0-9a-f]{64}$'){Add-C5Issue $Issues 'Evidence package identity mismatch.';return [pscustomobject]@{status=$MissingStatus;package=$null}}
    if($package.executionStatus-cne'Unavailable'-or$package.executorKind-cnotin@('C7Unity','G4Unity')-or@($package.observations).Count-ne0){Add-C5Issue $Issues 'C5-0 accepts only exact Unavailable evidence packages.';return [pscustomobject]@{status=$MissingStatus;package=$null}}
    [pscustomobject]@{status=$UnavailableStatus;package=$package}
}

function Invoke-C5RequirementEvidenceKernel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$MemberStaticQualification,
        [Parameter(Mandatory)][object[]]$RiskFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][object]$DecisionPolicyRegistry,
        [Parameter(Mandatory)][string]$DecisionPolicyBytes,
        [Parameter(Mandatory)][string[]]$RepresentativeStatuses,
        [Parameter(Mandatory)][string[]]$SuitabilityStatuses,
        [Parameter(Mandatory)][string]$InputStaticFingerprint,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$EvidencePackages
    )
    $issues=[Collections.Generic.List[string]]::new()
    if(-not(Test-C5ExactArray $RepresentativeStatuses @('RepresentativeRequired','EvidenceAccepted','EvidenceMissing','EvidenceStale','UnityExecutionUnavailable','RepresentativeRejected'))){Add-C5Issue $issues 'LC-I08 representativeAssessment vocabulary is invalid.'}
    if(-not(Test-C5ExactArray $SuitabilityStatuses @('SuitabilityRequired','SuitabilityAccepted','SuitabilityMissing','SuitabilityStale','SuitabilityExecutionUnavailable','SuitabilityRejected'))){Add-C5Issue $issues 'LC-I08 capabilitySuitabilityStatus vocabulary is invalid.'}
    if($InputStaticFingerprint-cnotmatch'^[0-9a-f]{64}$'){Add-C5Issue $issues 'C4 inputStaticFingerprint is invalid.'}
    $policySetFingerprint=Get-C5Sha256 $LanePolicyBytes;$decisionPolicyFingerprint=Get-C5Sha256 $DecisionPolicyBytes
    if($null-ne$LanePolicyRegistry.PSObject.Properties['policySetFingerprint']){Add-C5Issue $issues 'LC-I07 must not store policySetFingerprint.'}
    if($null-ne$DecisionPolicyRegistry.PSObject.Properties['decisionPolicyFingerprint']){Add-C5Issue $issues 'LC-I11 must not store decisionPolicyFingerprint.'}

    $memberById=@{};foreach($member in $MemberStaticQualification.memberResults){if($memberById.ContainsKey([string]$member.assetObjectId)){Add-C5Issue $issues 'Duplicate C4 member result.'}else{$memberById[[string]$member.assetObjectId]=$member}}
    $factByKey=@{};foreach($fact in $RiskFactRows){$key="$($fact.assetObjectId)|$($fact.factKind)";if($factByKey.ContainsKey($key)){Add-C5Issue $issues 'Duplicate risk fact.'}else{$factByKey[$key]=$fact}}
    $packageIds=@{};foreach($package in $EvidencePackages){if($packageIds.ContainsKey([string]$package.evidencePackageId)){Add-C5Issue $issues 'Duplicate evidencePackageId.'}else{$packageIds[[string]$package.evidencePackageId]=$true}}
    $laneById=@{};foreach($policy in $LanePolicyRegistry.policies){$laneById[[string]$policy.lane]=$policy}

    $requirements=[Collections.Generic.List[object]]::new();$assessments=[Collections.Generic.List[object]]::new()
    foreach($family in @($FamilyRegistry.families|Sort-Object familyId -CaseSensitive)){
        if(-not$laneById.ContainsKey([string]$family.lane)){Add-C5Issue $issues 'Family lane policy is missing.';continue}
        $policy=$laneById[[string]$family.lane];$members=@($MemberStaticQualification.memberResults|Where-Object familyId -CEQ $family.familyId)
        foreach($axis in $policy.riskAxisDefinitions){
            $variants=@{}
            foreach($member in $members){
                $facts=[Collections.Generic.List[object]]::new();$inapplicable=$false
                foreach($kind in $axis.sourceFactKinds){$key="$($member.assetObjectId)|$kind";if(-not$factByKey.ContainsKey($key)){Add-C5Issue $issues 'Missing C5 risk fact.';continue};$fact=$factByKey[$key];if($fact.factStatus-ceq'NotApplicable'){$inapplicable=$true;break};if($fact.factStatus-cne'Known'){Add-C5Issue $issues 'C5 risk fact is not Known.';continue};$facts.Add($fact)}
                if($inapplicable-or$facts.Count-ne@($axis.sourceFactKinds).Count){continue}
                $variantId=Get-C5RiskVariantId $family.familyId $axis.riskAxisId $facts.ToArray()
                if(-not$variants.ContainsKey($variantId)){$variants[$variantId]=[Collections.Generic.List[object]]::new()};$variants[$variantId].Add($member)
            }
            $evidenceDefinition=$policy.evidenceRequirementDefinitions|Where-Object{$_.applicableRiskAxisIds-ccontains$axis.riskAxisId}|Select-Object -First 1
            if($null-eq$evidenceDefinition){Add-C5Issue $issues 'Risk axis evidence requirement is missing.';continue}
            foreach($variantId in @($variants.Keys|Sort-Object -CaseSensitive)){
                $variantMembers=@($variants[$variantId].ToArray());$candidates=@($variantMembers|Where-Object staticStatus -CEQ StaticPassed|ForEach-Object assetObjectId|Sort-Object -CaseSensitive);$selected=if($candidates.Count){$candidates[0]}else{$null};$evidenceKinds=@($evidenceDefinition.requiredEvidenceKinds)
                $requirementId=Get-C5RequirementId $family.familyId $axis.riskAxisId $variantId $candidates $evidenceKinds;$expected=Get-C5ExpectedInputFingerprint $policySetFingerprint $decisionPolicyFingerprint $requirementId RiskVariant $selected $InputStaticFingerprint $evidenceKinds
                $state=Get-C5PackageAssessment $requirementId RiskVariant $selected $expected $EvidencePackages RepresentativeRequired EvidenceMissing UnityExecutionUnavailable $issues;$package=$state.package
                $requirements.Add([pscustomobject][ordered]@{requirementId=$requirementId;familyId=$family.familyId;lane=$family.lane;riskAxisId=$axis.riskAxisId;riskVariantId=$variantId;candidateMemberIds=$candidates;selectedRepresentativeAssetObjectId=$selected;selectionRule='OrdinalFirstStaticPassed';requiredEvidenceKinds=$evidenceKinds;expectedInputFingerprint=$expected;assessmentStatus=$state.status;evidence=@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json')})
                $failure=if($state.status-ceq'RepresentativeRequired'){"LF-10:$requirementId"}elseif($state.status-ceq'EvidenceMissing'){"LF-11:$requirementId"}else{"LF-13:$requirementId"};$next=if($state.status-ceq'RepresentativeRequired'){'Resolve C4/C3 facts; no fake representative.'}elseif($state.status-ceq'EvidenceMissing'){'Emit C7 request; no execution.'}else{'Preserve Unity unavailability; do not project rejection.'}
                $packageId=if($null-ne$package){$package.evidencePackageId}else{$null};$observed=if($null-ne$package){$package.inputFingerprint}else{$null}
                $assessmentId=Get-C5AssessmentId $requirementId $selected $state.status $packageId $expected $observed
                $assessments.Add([pscustomobject][ordered]@{assessmentId=$assessmentId;requirementId=$requirementId;familyId=$family.familyId;representativeAssetObjectId=$selected;assessmentStatus=$state.status;evidencePackageId=$packageId;expectedInputFingerprint=$expected;observedInputFingerprint=$observed;acceptedEvidenceKinds=@();missingEvidenceKinds=$evidenceKinds;failureAttribution=$failure;nextAllowedAction=$next;evidence=if($null-ne$package){@($package.evidencePaths)}else{@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json')}})
            }
        }
    }

    $suitabilityRequirements=[Collections.Generic.List[object]]::new();$suitabilityAssessments=[Collections.Generic.List[object]]::new()
    foreach($family in @($FamilyRegistry.families|Sort-Object familyId -CaseSensitive)){
        $policy=$laneById[[string]$family.lane];$members=@($MemberStaticQualification.memberResults|Where-Object familyId -CEQ $family.familyId);$actorRoles=@($members|ForEach-Object{$key="$($_.assetObjectId)|ActorRole";if($factByKey.ContainsKey($key)){$factByKey[$key].stringValue}}|Sort-Object -CaseSensitive -Unique)
        foreach($capability in $DecisionPolicyRegistry.capabilities){
            if($capability.eligibleLanes-cnotcontains$family.lane-or$capability.eligibleFamilyKindIds-cnotcontains$family.familyKindId){continue}
            if(@($capability.eligibleActorRoles).Count-and-not@($actorRoles|Where-Object{$_-cin@($capability.eligibleActorRoles)}).Count){continue}
            $laneCapability=$policy.capabilityProjectionRules|Where-Object capabilityId -CEQ $capability.capabilityId|Select-Object -First 1;if($null-eq$laneCapability){Add-C5Issue $issues 'LC-I07/LC-I11 capability union mismatch.';continue}
            $routes=@($capability.eligibleRouteKinds|Where-Object{$_-cin@($laneCapability.requiredRouteKinds)}|Sort-Object -CaseSensitive -Unique)
            foreach($route in $routes){
                $candidates=@($members|Where-Object staticStatus -CEQ StaticPassed|ForEach-Object assetObjectId|Sort-Object -CaseSensitive);$selected=if($candidates.Count){$candidates[0]}else{$null};$evidenceKinds=@('CapabilitySuitability')
                $requirementId=Get-C5SuitabilityRequirementId $decisionPolicyFingerprint $family.familyId $capability.capabilityId $route $candidates $selected $evidenceKinds;$expected=Get-C5ExpectedInputFingerprint $policySetFingerprint $decisionPolicyFingerprint $requirementId CapabilitySuitability $selected $InputStaticFingerprint $evidenceKinds
                $state=Get-C5PackageAssessment $requirementId CapabilitySuitability $selected $expected $EvidencePackages SuitabilityRequired SuitabilityMissing SuitabilityExecutionUnavailable $issues;$package=$state.package
                $suitabilityRequirements.Add([pscustomobject][ordered]@{suitabilityRequirementId=$requirementId;familyId=$family.familyId;capabilityId=$capability.capabilityId;routeKind=$route;candidateMemberIds=$candidates;selectedRepresentativeAssetObjectId=$selected;selectionRule='OrdinalFirstStaticPassed';requiredEvidenceKinds=$evidenceKinds;expectedInputFingerprint=$expected;assessmentStatus=$state.status;evidence=@('docs/asset-migration/schemas/c3-c6-decision-policy-registry.json')})
                $failure=if($state.status-ceq'SuitabilityRequired'){"LF-10:$requirementId"}elseif($state.status-ceq'SuitabilityMissing'){"LF-11:$requirementId"}else{"LF-13:$requirementId"};$next=if($state.status-ceq'SuitabilityRequired'){'Resolve C4/C3 facts; no fake representative.'}elseif($state.status-ceq'SuitabilityMissing'){'Emit capability-specific C7 request; no execution.'}else{'Preserve route-specific Unity unavailability.'}
                $packageId=if($null-ne$package){$package.evidencePackageId}else{$null};$observed=if($null-ne$package){$package.inputFingerprint}else{$null};$assessmentId=Get-C5SuitabilityAssessmentId $requirementId $state.status $packageId $expected $observed
                $suitabilityAssessments.Add([pscustomobject][ordered]@{suitabilityAssessmentId=$assessmentId;suitabilityRequirementId=$requirementId;familyId=$family.familyId;capabilityId=$capability.capabilityId;routeKind=$route;representativeAssetObjectId=$selected;assessmentStatus=$state.status;evidencePackageId=$packageId;expectedInputFingerprint=$expected;observedInputFingerprint=$observed;failureAttribution=$failure;nextAllowedAction=$next;evidence=if($null-ne$package){@($package.evidencePaths)}else{@('docs/asset-migration/schemas/c3-c6-decision-policy-registry.json')}})
            }
        }
    }

    $orderedRequirements=@($requirements|Sort-Object requirementId -CaseSensitive);$orderedAssessments=@($assessments|Sort-Object assessmentId -CaseSensitive);$orderedSuitability=@($suitabilityRequirements|Sort-Object suitabilityRequirementId -CaseSensitive);$orderedSuitabilityAssessments=@($suitabilityAssessments|Sort-Object suitabilityAssessmentId -CaseSensitive)
    [pscustomobject][ordered]@{
        status=if($issues.Count){'Failed'}else{'Passed'};issues=@($issues|Sort-Object -CaseSensitive);policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint;inputStaticFingerprint=$InputStaticFingerprint
        riskVariantCount=$orderedRequirements.Count;representativeRequirementCount=$orderedRequirements.Count;representativeRequiredCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ RepresentativeRequired).Count;evidenceAcceptedCount=0;evidenceMissingCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceMissing).Count;evidenceStaleCount=0;unityExecutionUnavailableCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ UnityExecutionUnavailable).Count;representativeRejectedCount=0
        capabilitySuitabilityRequirementCount=$orderedSuitability.Count;suitabilityRequiredCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityRequired).Count;suitabilityAcceptedCount=0;suitabilityMissingCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityMissing).Count;suitabilityStaleCount=0;suitabilityExecutionUnavailableCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityExecutionUnavailable).Count;suitabilityRejectedCount=0
        requirements=$orderedRequirements;assessments=$orderedAssessments;capabilitySuitabilityRequirements=$orderedSuitability;capabilitySuitabilityAssessments=$orderedSuitabilityAssessments;executorLaunchCount=0;heavyOperationCount=0
    }
}

Export-ModuleMember -Function Invoke-C5RequirementEvidenceKernel
