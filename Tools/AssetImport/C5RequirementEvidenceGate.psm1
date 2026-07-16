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
function Get-C5OrdinalRows([object[]]$Rows,[string]$Property){$list=[Collections.Generic.List[object]]::new();foreach($row in $Rows){$list.Add($row)};$list.Sort([Comparison[object]]{param($a,$b)$script:C5Ordinal.Compare([string]$a.$Property,[string]$b.$Property)});@($list.ToArray())}

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

function ConvertTo-C5ObservationFrame([object]$Observation){
    "C5EvidenceObservationV1`n"+(ConvertTo-C5ScalarLine evidenceKind ([string]$Observation.evidenceKind))+(ConvertTo-C5ScalarLine outcome ([string]$Observation.outcome))+(ConvertTo-C5ScalarLine contentFingerprint ([string]$Observation.contentFingerprint))+(Add-C5SetFrame evidence @($Observation.evidence))
}

function Get-C5EvidencePackageId([object]$Package){
    $observationDigests=@($Package.observations|ForEach-Object{Get-C5Sha256 (ConvertTo-C5ObservationFrame $_)})
    $text="C5EvidencePackageV1`n"+(ConvertTo-C5ScalarLine requirementId ([string]$Package.requirementId))+(ConvertTo-C5ScalarLine requirementKind ([string]$Package.requirementKind))+(ConvertTo-C5ScalarLine representativeAssetObjectId ([string]$Package.representativeAssetObjectId))+(ConvertTo-C5ScalarLine executorKind ([string]$Package.executorKind))+(ConvertTo-C5ScalarLine executionStatus ([string]$Package.executionStatus))+(ConvertTo-C5ScalarLine inputFingerprint ([string]$Package.inputFingerprint))+(Add-C5SetFrame observationDigests $observationDigests)+(Add-C5SetFrame evidencePaths @($Package.evidencePaths))
    "evidence-package-sha256:$(Get-C5Sha256 $text)"
}

function Get-C5PackageAssessment([string]$RequirementId,[string]$RequirementKind,[AllowNull()][object]$Representative,[string]$Expected,[string[]]$RequiredEvidenceKinds,[object[]]$Packages,[string]$RequiredStatus,[string]$MissingStatus,[string]$StaleStatus,[string]$UnavailableStatus,[string]$AcceptedStatus,[string]$RejectedStatus,[Collections.Generic.List[string]]$Issues){
    if($null-eq$Representative){return [pscustomobject]@{status=$RequiredStatus;package=$null;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}}
    $matching=@($Packages|Where-Object requirementId -CEQ $RequirementId)
    if($matching.Count-eq0){return [pscustomobject]@{status=$MissingStatus;package=$null;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}}
    if($matching.Count-ne1){Add-C5Issue $Issues 'Duplicate evidence package requirementId.';return [pscustomobject]@{status=$MissingStatus;package=$null;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}}
    $package=$matching[0]
    $missingResult=[pscustomobject]@{status=$MissingStatus;package=$package;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}
    if((@($package.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,evidencePackageId,requirementId,requirementKind,representativeAssetObjectId,executorKind,executionStatus,inputFingerprint,toolVersions,observations,evidencePaths'){Add-C5Issue $Issues 'Invalid evidence package shape.';return $missingResult}
    if($package.requirementKind-cne$RequirementKind-or$package.representativeAssetObjectId-cne$Representative-or$package.executorKind-cnotin@('C7Unity','G4Unity','StaticHumanReview','AudioListening','ExternalDecoder')-or$package.executionStatus-cnotin@('Completed','Unavailable','Failed')-or$package.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'){Add-C5Issue $Issues 'Evidence package identity mismatch.';return $missingResult}
    foreach($observation in @($package.observations)){
        if((@($observation.PSObject.Properties.Name)-join',')-cne'evidenceKind,outcome,contentFingerprint,evidence'-or$observation.outcome-cnotin@('Passed','Rejected','Inconclusive')-or$observation.contentFingerprint-cnotmatch'^[0-9a-f]{64}$'){Add-C5Issue $Issues 'Invalid evidence observation.';return $missingResult}
    }
    if($package.evidencePackageId-cne(Get-C5EvidencePackageId $package)){Add-C5Issue $Issues 'Evidence package identity mismatch.';return $missingResult}
    if($package.executionStatus-ceq'Unavailable'){
        if($package.executorKind-cnotin@('C7Unity','G4Unity')-or@($package.observations).Count-ne0){Add-C5Issue $Issues 'Invalid unavailable evidence package.';return $missingResult}
        if($package.inputFingerprint-cne$Expected){return [pscustomobject]@{status=$StaleStatus;package=$package;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}}
        return [pscustomobject]@{status=$UnavailableStatus;package=$package;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}
    }
    if($RequirementKind-ceq'CapabilitySuitability'-and(@($package.observations).Count-ne1-or$package.observations[0].evidenceKind-cne'CapabilitySuitability')){Add-C5Issue $Issues 'Capability suitability package identity mismatch.';return $missingResult}
    if($package.inputFingerprint-cne$Expected){return [pscustomobject]@{status=$StaleStatus;package=$package;acceptedEvidenceKinds=@();missingEvidenceKinds=@($RequiredEvidenceKinds)}}
    $passedKinds=@($package.observations|Where-Object outcome -CEQ Passed|ForEach-Object evidenceKind|Where-Object{$_-cin$RequiredEvidenceKinds}|Sort-Object -CaseSensitive -Unique)
    $missingKinds=@($RequiredEvidenceKinds|Where-Object{$_-cnotin$passedKinds}|Sort-Object -CaseSensitive -Unique)
    if(@($package.observations|Where-Object outcome -CEQ Rejected).Count){return [pscustomobject]@{status=$RejectedStatus;package=$package;acceptedEvidenceKinds=$passedKinds;missingEvidenceKinds=$missingKinds}}
    if($package.executionStatus-ceq'Completed'-and$missingKinds.Count-eq0){return [pscustomobject]@{status=$AcceptedStatus;package=$package;acceptedEvidenceKinds=$passedKinds;missingEvidenceKinds=@()}}
    [pscustomobject]@{status=$MissingStatus;package=$package;acceptedEvidenceKinds=$passedKinds;missingEvidenceKinds=$missingKinds}
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
                $state=Get-C5PackageAssessment $requirementId RiskVariant $selected $expected $evidenceKinds $EvidencePackages RepresentativeRequired EvidenceMissing EvidenceStale UnityExecutionUnavailable EvidenceAccepted RepresentativeRejected $issues;$package=$state.package
                $requirements.Add([pscustomobject][ordered]@{requirementId=$requirementId;familyId=$family.familyId;lane=$family.lane;riskAxisId=$axis.riskAxisId;riskVariantId=$variantId;candidateMemberIds=$candidates;selectedRepresentativeAssetObjectId=$selected;selectionRule='OrdinalFirstStaticPassed';requiredEvidenceKinds=$evidenceKinds;expectedInputFingerprint=$expected;assessmentStatus=$state.status;evidence=@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json')})
                $failure=switch -CaseSensitive($state.status){'RepresentativeRequired'{"LF-10:$requirementId"};'EvidenceMissing'{"LF-11:$requirementId"};'EvidenceStale'{"LF-12:$requirementId"};'UnityExecutionUnavailable'{"LF-13:$requirementId"};'RepresentativeRejected'{"LF-14:$requirementId"};default{$null}}
                $next=switch -CaseSensitive($state.status){'RepresentativeRequired'{'Resolve C4/C3 facts; no fake representative.'};'EvidenceMissing'{'Emit C7 request; no execution.'};'EvidenceStale'{'Request fresh evidence only.'};'UnityExecutionUnavailable'{'Preserve Unity unavailability; do not project rejection.'};'RepresentativeRejected'{'Defer diagnosis/repair/replacement/stop to C6.'};default{'Proceed with accepted evidence.'}}
                $packageId=if($null-ne$package){$package.evidencePackageId}else{$null};$observed=if($null-ne$package){$package.inputFingerprint}else{$null}
                $assessmentId=Get-C5AssessmentId $requirementId $selected $state.status $packageId $expected $observed
                $assessments.Add([pscustomobject][ordered]@{assessmentId=$assessmentId;requirementId=$requirementId;familyId=$family.familyId;representativeAssetObjectId=$selected;assessmentStatus=$state.status;evidencePackageId=$packageId;expectedInputFingerprint=$expected;observedInputFingerprint=$observed;acceptedEvidenceKinds=@($state.acceptedEvidenceKinds);missingEvidenceKinds=@($state.missingEvidenceKinds);failureAttribution=$failure;nextAllowedAction=$next;evidence=if($null-ne$package){@($package.evidencePaths)}else{@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json')}})
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
                $state=Get-C5PackageAssessment $requirementId CapabilitySuitability $selected $expected $evidenceKinds $EvidencePackages SuitabilityRequired SuitabilityMissing SuitabilityStale SuitabilityExecutionUnavailable SuitabilityAccepted SuitabilityRejected $issues;$package=$state.package
                $suitabilityRequirements.Add([pscustomobject][ordered]@{suitabilityRequirementId=$requirementId;familyId=$family.familyId;capabilityId=$capability.capabilityId;routeKind=$route;candidateMemberIds=$candidates;selectedRepresentativeAssetObjectId=$selected;selectionRule='OrdinalFirstStaticPassed';requiredEvidenceKinds=$evidenceKinds;expectedInputFingerprint=$expected;assessmentStatus=$state.status;evidence=@('docs/asset-migration/schemas/c3-c6-decision-policy-registry.json')})
                $failure=switch -CaseSensitive($state.status){'SuitabilityRequired'{"LF-10:$requirementId"};'SuitabilityMissing'{"LF-11:$requirementId"};'SuitabilityStale'{"LF-12:$requirementId"};'SuitabilityExecutionUnavailable'{"LF-13:$requirementId"};'SuitabilityRejected'{"LF-14:$requirementId"};default{$null}}
                $next=switch -CaseSensitive($state.status){'SuitabilityRequired'{'Resolve C4/C3 facts; no fake representative.'};'SuitabilityMissing'{'Emit capability-specific C7 request; no execution.'};'SuitabilityStale'{'Request fresh capability-specific evidence only.'};'SuitabilityExecutionUnavailable'{'Preserve route-specific Unity unavailability.'};'SuitabilityRejected'{'Reject only this exact capability and route.'};default{'Proceed with exact capability and route.'}}
                $packageId=if($null-ne$package){$package.evidencePackageId}else{$null};$observed=if($null-ne$package){$package.inputFingerprint}else{$null};$assessmentId=Get-C5SuitabilityAssessmentId $requirementId $state.status $packageId $expected $observed
                $suitabilityAssessments.Add([pscustomobject][ordered]@{suitabilityAssessmentId=$assessmentId;suitabilityRequirementId=$requirementId;familyId=$family.familyId;capabilityId=$capability.capabilityId;routeKind=$route;representativeAssetObjectId=$selected;assessmentStatus=$state.status;evidencePackageId=$packageId;expectedInputFingerprint=$expected;observedInputFingerprint=$observed;failureAttribution=$failure;nextAllowedAction=$next;evidence=if($null-ne$package){@($package.evidencePaths)}else{@('docs/asset-migration/schemas/c3-c6-decision-policy-registry.json')}})
            }
        }
    }

    $orderedRequirements=@($requirements|Sort-Object requirementId -CaseSensitive);$orderedAssessments=@($assessments|Sort-Object assessmentId -CaseSensitive);$orderedSuitability=@($suitabilityRequirements|Sort-Object suitabilityRequirementId -CaseSensitive);$orderedSuitabilityAssessments=@($suitabilityAssessments|Sort-Object suitabilityAssessmentId -CaseSensitive)
    $knownRequirementIds=@($orderedRequirements.requirementId)+@($orderedSuitability.suitabilityRequirementId)
    foreach($package in $EvidencePackages){if($package.requirementId-cnotin$knownRequirementIds){Add-C5Issue $issues 'Evidence package does not resolve to a C5 requirement.'}}
    [pscustomobject][ordered]@{
        status=if($issues.Count){'Failed'}else{'Passed'};issues=@($issues|Sort-Object -CaseSensitive);policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint;inputStaticFingerprint=$InputStaticFingerprint
        riskVariantCount=$orderedRequirements.Count;representativeRequirementCount=$orderedRequirements.Count;representativeRequiredCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ RepresentativeRequired).Count;evidenceAcceptedCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceAccepted).Count;evidenceMissingCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceMissing).Count;evidenceStaleCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceStale).Count;unityExecutionUnavailableCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ UnityExecutionUnavailable).Count;representativeRejectedCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ RepresentativeRejected).Count
        capabilitySuitabilityRequirementCount=$orderedSuitability.Count;suitabilityRequiredCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityRequired).Count;suitabilityAcceptedCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityAccepted).Count;suitabilityMissingCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityMissing).Count;suitabilityStaleCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityStale).Count;suitabilityExecutionUnavailableCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityExecutionUnavailable).Count;suitabilityRejectedCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityRejected).Count
        requirements=$orderedRequirements;assessments=$orderedAssessments;capabilitySuitabilityRequirements=$orderedSuitability;capabilitySuitabilityAssessments=$orderedSuitabilityAssessments;executorLaunchCount=0;heavyOperationCount=0
    }
}

function ConvertTo-C5CanonicalJson([object]$Value){(($Value|ConvertTo-Json -Depth 100)-replace"`r`n","`n")+"`n"}

function Get-C5ArtifactSetFingerprint([object[]]$Entries){
    $ordered=@(Get-C5OrdinalRows $Entries path);$count=[string]$ordered.Count;$text="LifecycleStageInputV1`nentries.count:$($script:C5Utf8.GetByteCount($count)):$count`n"
    for($index=0;$index-lt$ordered.Count;$index++){$nested="C2ArtifactEntryV1`n"+(ConvertTo-C5ScalarLine path ([string]$ordered[$index].path))+(ConvertTo-C5ScalarLine sha256 ([string]$ordered[$index].sha256));$text+="entries[$index]:$($script:C5Utf8.GetByteCount($nested)):$nested`n"}
    Get-C5Sha256 $text
}

function Get-C5StageInputFingerprint([object[]]$Entries){
    $expected=[ordered]@{
        'C3-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json';'C3-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json';'C3-O03'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json';'C3-O04-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json';'C3-O04-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
        'C4-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json';'C4-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json';'C4-O03-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json';'C4-O03-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'
        'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json';'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json';'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json';'LC-I11'='docs/asset-migration/schemas/c3-c6-decision-policy-registry.json';'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
    }
    if($Entries.Count-ne$expected.Count){throw 'C5 direct input set is invalid.'}
    $seen=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal)
    foreach($entry in $Entries){if((@($entry.PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or-not$expected.Contains([string]$entry.artifactId)-or$expected[[string]$entry.artifactId]-cne[string]$entry.path-or-not$seen.Add([string]$entry.path)-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'){throw 'C5 direct input contract is invalid.'}}
    Get-C5ArtifactSetFingerprint $Entries
}

function Get-C5AccountingId([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence){
    $text="LifecycleAccountingV1`n";foreach($pair in @(@('owningArray',$OwningArray),@('stageId','C5'),@('subjectKind',$SubjectKind),@('subjectId',$SubjectId),@('reasonCode',$ReasonCode),@('attribution',$Attribution))){$text+=ConvertTo-C5ScalarLine $pair[0] $pair[1]};$text+=Add-C5SetFrame evidence $Evidence
    "lifecycle-accounting-sha256:$(Get-C5Sha256 $text)"
}

function New-C5AccountingRow([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence){
    $values=@($Evidence|Sort-Object -CaseSensitive -Unique)
    [pscustomobject][ordered]@{recordId=Get-C5AccountingId $OwningArray $SubjectKind $SubjectId $ReasonCode $Attribution $values;stageId='C5';subjectKind=$SubjectKind;subjectId=$SubjectId;reasonCode=$ReasonCode;attribution=$Attribution;evidence=$values}
}

function New-C5Report([object]$Stage,[string]$InputFingerprint,[string]$PolicySetFingerprint,[object]$Accounting,[object]$Decision){
    "# C5 Lifecycle Gate Report`n"+"schemaVersion: 1.0.0`n"+"generatedAt: $($Stage.generatedAt)`n"+"stageId: C5`n"+"snapshotId: $($Stage.snapshotId)`n"+"inputFingerprint: $InputFingerprint`n"+"policySetFingerprint: $PolicySetFingerprint`n"+"gateStatus: $($Accounting.gateStatus)`n"+"inputSubjectCount: $($Accounting.inputSubjectCount)`n"+"inputFailureCount: $($Accounting.inputFailureCount)`n"+"notEvaluatedInputSubjectCount: $($Accounting.notEvaluatedInputSubjectCount)`n"+"outputCandidateCount: $($Accounting.outputCandidateCount)`n"+"projectedOutputCount: $($Accounting.projectedOutputCount)`n"+"outputFailureCount: $($Accounting.outputFailureCount)`n"+"issueCount: $($Accounting.issueCount)`n"+"failureAttribution: $($Decision.failureAttribution)`n"+"nextAllowedAction: $($Decision.nextAllowedAction)`n"
}

function Invoke-C5RequirementEvidenceGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,[Parameter(Mandatory)][object]$MemberStaticQualification,[Parameter(Mandatory)][object[]]$RiskFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,[Parameter(Mandatory)][string]$LanePolicyBytes,[Parameter(Mandatory)][object]$DecisionPolicyRegistry,[Parameter(Mandatory)][string]$DecisionPolicyBytes,
        [Parameter(Mandatory)][string[]]$RepresentativeStatuses,[Parameter(Mandatory)][string[]]$SuitabilityStatuses,[Parameter(Mandatory)][AllowEmptyCollection()][object[]]$EvidencePackages,[Parameter(Mandatory)][object]$Stage
    )
    $directInputs=@(Get-C5OrdinalRows $Stage.directInputs path);$inputFingerprint=Get-C5StageInputFingerprint $directInputs
    $policySetFingerprint=Get-C5Sha256 $LanePolicyBytes;$decisionPolicyFingerprint=Get-C5Sha256 $DecisionPolicyBytes
    if($Stage.snapshotId-cne$FamilyRegistry.snapshotId-or$Stage.snapshotId-cne$MemberStaticQualification.snapshotId-or$FamilyRegistry.policySetFingerprint-cne$policySetFingerprint-or$MemberStaticQualification.policySetFingerprint-cne$policySetFingerprint){throw 'C5 prerequisite generation identity is invalid.'}
    $c4Entries=@($directInputs|Where-Object artifactId -CIn @('C4-O01','C4-O02','C4-O03-Summary','C4-O03-Report'))
    $inputStaticFingerprint=Get-C5ArtifactSetFingerprint $c4Entries
    $kernel=Invoke-C5RequirementEvidenceKernel -FamilyRegistry $FamilyRegistry -MemberStaticQualification $MemberStaticQualification -RiskFactRows $RiskFactRows -LanePolicyRegistry $LanePolicyRegistry -LanePolicyBytes $LanePolicyBytes -DecisionPolicyRegistry $DecisionPolicyRegistry -DecisionPolicyBytes $DecisionPolicyBytes -RepresentativeStatuses $RepresentativeStatuses -SuitabilityStatuses $SuitabilityStatuses -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages $EvidencePackages
    $prefix=[ordered]@{schemaVersion='1.0.0';generatedAt=[string]$Stage.generatedAt;snapshotId=[string]$Stage.snapshotId;inputFingerprint=$inputFingerprint;policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint}
    $paths=[ordered]@{requirements='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-representative-requirements.json';assessments='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json';requests='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c7-evidence-request.json';report='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-report.md'}
    $familyLane=@{};foreach($family in $FamilyRegistry.families){$familyLane[[string]$family.familyId]=[string]$family.lane}
    $requests=[Collections.Generic.List[object]]::new()
    foreach($assessment in @($kernel.assessments|Where-Object assessmentStatus -CIn @('EvidenceMissing','EvidenceStale','UnityExecutionUnavailable'))){$requirement=@($kernel.requirements|Where-Object requirementId -CEQ $assessment.requirementId)[0];$requests.Add([pscustomobject][ordered]@{requirementId=$requirement.requirementId;requirementKind='RiskVariant';familyId=$requirement.familyId;lane=$requirement.lane;capabilityId=$null;routeKind=$null;representativeAssetObjectId=$requirement.selectedRepresentativeAssetObjectId;requiredEvidenceKinds=@($requirement.requiredEvidenceKinds);reasonCode=$assessment.assessmentStatus;priority='Coverage';evidence=@($assessment.evidence)})}
    foreach($assessment in @($kernel.capabilitySuitabilityAssessments|Where-Object assessmentStatus -CIn @('SuitabilityMissing','SuitabilityStale','SuitabilityExecutionUnavailable'))){$requirement=@($kernel.capabilitySuitabilityRequirements|Where-Object suitabilityRequirementId -CEQ $assessment.suitabilityRequirementId)[0];$requests.Add([pscustomobject][ordered]@{requirementId=$requirement.suitabilityRequirementId;requirementKind='CapabilitySuitability';familyId=$requirement.familyId;lane=$familyLane[[string]$requirement.familyId];capabilityId=$requirement.capabilityId;routeKind=$requirement.routeKind;representativeAssetObjectId=$requirement.selectedRepresentativeAssetObjectId;requiredEvidenceKinds=@($requirement.requiredEvidenceKinds);reasonCode=$assessment.assessmentStatus;priority='RequiredCapability';evidence=@($assessment.evidence)})}
    $orderedRequests=@($requests|Sort-Object requirementId -CaseSensitive)
    $coverage=[pscustomobject][ordered]@{familyCount=@($FamilyRegistry.families).Count;riskVariantCount=$kernel.riskVariantCount;representativeRequirementCount=$kernel.representativeRequirementCount;representativeRequiredCount=$kernel.representativeRequiredCount;evidenceAcceptedCount=$kernel.evidenceAcceptedCount;evidenceMissingCount=$kernel.evidenceMissingCount;evidenceStaleCount=$kernel.evidenceStaleCount;unityExecutionUnavailableCount=$kernel.unityExecutionUnavailableCount;representativeRejectedCount=$kernel.representativeRejectedCount;capabilitySuitabilityRequirementCount=$kernel.capabilitySuitabilityRequirementCount;suitabilityRequiredCount=$kernel.suitabilityRequiredCount;suitabilityAcceptedCount=$kernel.suitabilityAcceptedCount;suitabilityMissingCount=$kernel.suitabilityMissingCount;suitabilityStaleCount=$kernel.suitabilityStaleCount;suitabilityExecutionUnavailableCount=$kernel.suitabilityExecutionUnavailableCount;suitabilityRejectedCount=$kernel.suitabilityRejectedCount;c7RequestCount=$orderedRequests.Count}
    $inputSubjectCount=$directInputs.Count+$coverage.familyCount+$coverage.representativeRequirementCount+$coverage.capabilitySuitabilityRequirementCount+$EvidencePackages.Count+2
    if($kernel.status-cne'Passed'){
        $subjectId='C5:EvidenceContract';$attribution="LF-15:$subjectId";$evidence=@($EvidencePackages|ForEach-Object evidencePaths|ForEach-Object{$_}|Sort-Object -CaseSensitive -Unique);if(-not$evidence.Count){$evidence=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')}
        $failure=New-C5AccountingRow inputFailures ConservationCheck $subjectId EvidenceContractInvalid $attribution $evidence
        $outputFailures=@(New-C5AccountingRow outputFailures OutputArtifact 'C5-O01' SuppressedByGate 'LF-15:C5-O01' @($paths.requirements);New-C5AccountingRow outputFailures OutputArtifact 'C5-O02' SuppressedByGate 'LF-15:C5-O02' @($paths.assessments);New-C5AccountingRow outputFailures OutputArtifact 'C5-O03' SuppressedByGate 'LF-15:C5-O03' @($paths.requests))
        $accounting=[pscustomobject][ordered]@{inputSubjectCount=$inputSubjectCount;acceptedInputSubjectCount=[Math]::Max(0,$inputSubjectCount-2);inputFailureCount=1;notEvaluatedInputSubjectCount=1;outputCandidateCount=4;projectedOutputCount=1;outputFailureCount=3;issueCount=1;gateStatus='Failed';inputFailures=@($failure);inputSuppressions=@();outputFailures=$outputFailures}
        $decision=[pscustomobject][ordered]@{failureAttribution=$attribution;nextAllowedAction='Correct evidence authority/producer.'};$report=New-C5Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
        $directOutputs=@([pscustomobject][ordered]@{artifactId='C5-O04-Report';path=$paths.report;sha256=Get-C5Sha256 $report})
        $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C5';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;decisionPolicyFingerprint=$prefix.decisionPolicyFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=$coverage;failureAccounting=$accounting;decision=$decision}
        return [pscustomobject][ordered]@{gateStatus='Failed';representativeRequirements=$null;evidenceAssessment=$null;c7EvidenceRequest=$null;summary=$summary;report=$report;texts=[pscustomobject][ordered]@{representativeRequirements=$null;evidenceAssessment=$null;c7EvidenceRequest=$null;summary=ConvertTo-C5CanonicalJson $summary};executorLaunchCount=$kernel.executorLaunchCount;heavyOperationCount=$kernel.heavyOperationCount}
    }
    $representativeRequirements=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;decisionPolicyFingerprint=$prefix.decisionPolicyFingerprint;requirements=@($kernel.requirements);capabilitySuitabilityRequirements=@($kernel.capabilitySuitabilityRequirements)}
    $evidenceAssessment=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;decisionPolicyFingerprint=$prefix.decisionPolicyFingerprint;assessments=@($kernel.assessments);capabilitySuitabilityAssessments=@($kernel.capabilitySuitabilityAssessments)}
    $c7EvidenceRequest=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;decisionPolicyFingerprint=$prefix.decisionPolicyFingerprint;requests=$orderedRequests}
    $texts=[ordered]@{representativeRequirements=ConvertTo-C5CanonicalJson $representativeRequirements;evidenceAssessment=ConvertTo-C5CanonicalJson $evidenceAssessment;c7EvidenceRequest=ConvertTo-C5CanonicalJson $c7EvidenceRequest}
    $accounting=[pscustomobject][ordered]@{inputSubjectCount=$inputSubjectCount;acceptedInputSubjectCount=$inputSubjectCount;inputFailureCount=0;notEvaluatedInputSubjectCount=0;outputCandidateCount=4;projectedOutputCount=4;outputFailureCount=0;issueCount=0;gateStatus='Passed';inputFailures=@();inputSuppressions=@();outputFailures=@()}
    $decision=[pscustomobject][ordered]@{failureAttribution='None; C5 lifecycle contract passed.';nextAllowedAction='Provide the current requirement and assessment generation to C6; C7 requests remain separately authorized.'};$report=New-C5Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
    $directOutputs=@(Get-C5OrdinalRows @([pscustomobject][ordered]@{artifactId='C5-O01';path=$paths.requirements;sha256=Get-C5Sha256 $texts.representativeRequirements},[pscustomobject][ordered]@{artifactId='C5-O02';path=$paths.assessments;sha256=Get-C5Sha256 $texts.evidenceAssessment},[pscustomobject][ordered]@{artifactId='C5-O03';path=$paths.requests;sha256=Get-C5Sha256 $texts.c7EvidenceRequest},[pscustomobject][ordered]@{artifactId='C5-O04-Report';path=$paths.report;sha256=Get-C5Sha256 $report}) path)
    $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C5';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;decisionPolicyFingerprint=$prefix.decisionPolicyFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=$coverage;failureAccounting=$accounting;decision=$decision};$texts.summary=ConvertTo-C5CanonicalJson $summary
    [pscustomobject][ordered]@{gateStatus='Passed';representativeRequirements=$representativeRequirements;evidenceAssessment=$evidenceAssessment;c7EvidenceRequest=$c7EvidenceRequest;summary=$summary;report=$report;texts=[pscustomobject]$texts;executorLaunchCount=$kernel.executorLaunchCount;heavyOperationCount=$kernel.heavyOperationCount}
}

Export-ModuleMember -Function Invoke-C5RequirementEvidenceKernel,Invoke-C5RequirementEvidenceGate
