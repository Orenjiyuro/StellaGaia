Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$script:C5Utf8=[Text.UTF8Encoding]::new($false)
$script:C5Ordinal=[StringComparer]::Ordinal

function Get-C5Sha256([string]$Text){[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C5Utf8.GetBytes($Text))).ToLowerInvariant()}
function ConvertTo-C5ScalarLine([string]$Name,[string]$Value){if($null-eq$Value-or$Value.IndexOfAny([char[]]@([char]0,"`r","`n"))-ge0){throw"Invalid framed scalar: $Name"};"${Name}:$($script:C5Utf8.GetByteCount($Value)):${Value}`n"}
function ConvertTo-C5NullableLine([string]$Name,[AllowNull()][object]$Value){if($null-eq$Value){return "${Name}.null:1:1`n"};"${Name}.null:1:0`n$(ConvertTo-C5ScalarLine $Name ([string]$Value))"}
function Get-C5OrdinalValues([object[]]$Values,[switch]$Unique){$list=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal);foreach($value in $Values){$text=[string]$value;if(-not$Unique-or$seen.Add($text)){$list.Add($text)}};$list.Sort($script:C5Ordinal);[string[]]$list.ToArray()}
function Add-C5SetFrame([string]$Name,[string[]]$Values){$ordered=@(Get-C5OrdinalValues $Values -Unique);$count=[string]$ordered.Count;$text="${Name}.count:$($script:C5Utf8.GetByteCount($count)):$count`n";for($i=0;$i-lt$ordered.Count;$i++){$text+=ConvertTo-C5ScalarLine "${Name}[$i]" $ordered[$i]};$text}
function Add-C5Issue([Collections.Generic.List[string]]$Issues,[string]$Issue){if(-not$Issues.Contains($Issue)){$Issues.Add($Issue)}}
function Test-C5ExactArray([object[]]$Actual,[string[]]$Expected){if($Actual.Count-ne$Expected.Count){return $false};for($i=0;$i-lt$Expected.Count;$i++){if([string]$Actual[$i]-cne$Expected[$i]){return $false}};$true}
function Get-C5OrdinalRows([object[]]$Rows,[string]$Property){$list=[Collections.Generic.List[object]]::new();foreach($row in $Rows){$list.Add($row)};$list.Sort([Comparison[object]]{param($a,$b)$script:C5Ordinal.Compare([string]$a.$Property,[string]$b.$Property)});@($list.ToArray())}
function Test-C5JsonObjectBytesBinding([object]$Value,[string]$Bytes){try{$parsed=$Bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{return $false};($Value|ConvertTo-Json -Depth 100 -Compress)-ceq($parsed|ConvertTo-Json -Depth 100 -Compress)}
function Test-C5JsonProjectionBytesBinding([object]$Value,[string]$Bytes,[string]$Property){try{$parsed=$Bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{return $false};if($null-eq$parsed.PSObject.Properties[$Property]){return $false};($Value|ConvertTo-Json -Depth 100 -Compress)-ceq($parsed.$Property|ConvertTo-Json -Depth 100 -Compress)}
function New-C5ArtifactMap([object[]]$Rows,[string]$KeyProperty){$map=[Collections.Generic.Dictionary[string,object]]::new($script:C5Ordinal);foreach($row in $Rows){if($null-eq$row-or$null-eq$row.PSObject.Properties[$KeyProperty]){return $null};$key=[string]$row.$KeyProperty;if([string]::IsNullOrWhiteSpace($key)-or$map.ContainsKey($key)){return $null};$map.Add($key,$row)};$map}
function Test-C5PortablePath([string]$Path){$null-ne$Path-and$Path.Length-gt0-and-not$Path.StartsWith('/')-and-not$Path.Contains('\')-and-not@($Path.Split('/')|Where-Object{$_-ceq''-or$_-ceq'.'-or$_-ceq'..'}).Count}

function ConvertTo-C5FactFrame([object]$Fact){
    $text="C5RiskVariantFactV1`n"
    foreach($name in @('factKind','factStatus','valueKind')){$text+=ConvertTo-C5ScalarLine $name ([string]$Fact.$name)}
    foreach($name in @('stringValue','integerValue','booleanValue')){$text+=ConvertTo-C5NullableLine $name $Fact.$name}
    $text+=Add-C5SetFrame idValues @($Fact.idValues)
    $text
}

function Get-C5RiskVariantId([string]$FamilyId,[string]$RiskAxisId,[object[]]$Facts){
    $text="C5RiskVariantV1`n"+(ConvertTo-C5ScalarLine familyId $FamilyId)+(ConvertTo-C5ScalarLine riskAxisId $RiskAxisId)
    $count=[string]$Facts.Count;$text+="sourceFacts.count:$($script:C5Utf8.GetByteCount($count)):$count`n"
    for($i=0;$i-lt$Facts.Count;$i++){$nested=ConvertTo-C5FactFrame $Facts[$i];$text+="sourceFacts[$i]:$($script:C5Utf8.GetByteCount($nested)):$nested`n"}
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
    $passedKinds=@(Get-C5OrdinalValues @($package.observations|Where-Object outcome -CEQ Passed|ForEach-Object evidenceKind|Where-Object{$_-cin$RequiredEvidenceKinds}) -Unique)
    $missingKinds=@(Get-C5OrdinalValues @($RequiredEvidenceKinds|Where-Object{$_-cnotin$passedKinds}) -Unique)
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
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$EvidencePackages,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$EvidencePackageBytes,
        [Parameter()][AllowEmptyCollection()][string[]]$EvidenceAuthorityIssues=@()
    )
    $issues=[Collections.Generic.List[string]]::new()
    foreach($issue in $EvidenceAuthorityIssues){Add-C5Issue $issues $issue}
    if(-not(Test-C5ExactArray $RepresentativeStatuses @('RepresentativeRequired','EvidenceAccepted','EvidenceMissing','EvidenceStale','UnityExecutionUnavailable','RepresentativeRejected'))){Add-C5Issue $issues 'LC-I08 representativeAssessment vocabulary is invalid.'}
    if(-not(Test-C5ExactArray $SuitabilityStatuses @('SuitabilityRequired','SuitabilityAccepted','SuitabilityMissing','SuitabilityStale','SuitabilityExecutionUnavailable','SuitabilityRejected'))){Add-C5Issue $issues 'LC-I08 capabilitySuitabilityStatus vocabulary is invalid.'}
    if($InputStaticFingerprint-cnotmatch'^[0-9a-f]{64}$'){Add-C5Issue $issues 'C4 inputStaticFingerprint is invalid.'}
    $policySetFingerprint=Get-C5Sha256 $LanePolicyBytes;$decisionPolicyFingerprint=Get-C5Sha256 $DecisionPolicyBytes
    if(-not(Test-C5JsonObjectBytesBinding $LanePolicyRegistry $LanePolicyBytes)){Add-C5Issue $issues 'LC-I07 execution object does not match accepted bytes.'}
    if(-not(Test-C5JsonObjectBytesBinding $DecisionPolicyRegistry $DecisionPolicyBytes)){Add-C5Issue $issues 'LC-I11 execution object does not match accepted bytes.'}
    if($null-ne$LanePolicyRegistry.PSObject.Properties['policySetFingerprint']){Add-C5Issue $issues 'LC-I07 must not store policySetFingerprint.'}
    if($null-ne$DecisionPolicyRegistry.PSObject.Properties['decisionPolicyFingerprint']){Add-C5Issue $issues 'LC-I11 must not store decisionPolicyFingerprint.'}
    if($EvidencePackages.Count-ne$EvidencePackageBytes.Count){Add-C5Issue $issues 'Evidence package object/bytes count mismatch.'}
    for($index=0;$index-lt[Math]::Min($EvidencePackages.Count,$EvidencePackageBytes.Count);$index++){
        if(-not(Test-C5JsonObjectBytesBinding $EvidencePackages[$index] $EvidencePackageBytes[$index])){Add-C5Issue $issues 'LC-I10 execution object does not match accepted bytes.'}
    }

    $memberById=@{};foreach($member in $MemberStaticQualification.memberResults){if($memberById.ContainsKey([string]$member.assetObjectId)){Add-C5Issue $issues 'Duplicate C4 member result.'}else{$memberById[[string]$member.assetObjectId]=$member}}
    $factByKey=@{};foreach($fact in $RiskFactRows){$key="$($fact.assetObjectId)|$($fact.factKind)";if($factByKey.ContainsKey($key)){Add-C5Issue $issues 'Duplicate risk fact.'}else{$factByKey[$key]=$fact}}
    $packageIds=@{};foreach($package in $EvidencePackages){$idProperty=$package.PSObject.Properties['evidencePackageId'];if($null-eq$idProperty){Add-C5Issue $issues 'Invalid evidence package shape.';continue};$id=[string]$idProperty.Value;if($packageIds.ContainsKey($id)){Add-C5Issue $issues 'Duplicate evidencePackageId.'}else{$packageIds[$id]=$true}}
    $laneById=@{};foreach($policy in $LanePolicyRegistry.policies){$laneById[[string]$policy.lane]=$policy}

    $requirements=[Collections.Generic.List[object]]::new();$assessments=[Collections.Generic.List[object]]::new()
    foreach($family in @(Get-C5OrdinalRows @($FamilyRegistry.families) familyId)){
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
            foreach($variantId in @(Get-C5OrdinalValues @($variants.Keys))){
                $variantMembers=@($variants[$variantId].ToArray());$candidates=@(Get-C5OrdinalValues @($variantMembers|Where-Object staticStatus -CEQ StaticPassed|ForEach-Object assetObjectId));$selected=if($candidates.Count){$candidates[0]}else{$null};$evidenceKinds=@($evidenceDefinition.requiredEvidenceKinds)
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
    foreach($family in @(Get-C5OrdinalRows @($FamilyRegistry.families) familyId)){
        $policy=$laneById[[string]$family.lane];$members=@($MemberStaticQualification.memberResults|Where-Object familyId -CEQ $family.familyId);$actorRoles=@(Get-C5OrdinalValues @($members|ForEach-Object{$key="$($_.assetObjectId)|ActorRole";if($factByKey.ContainsKey($key)){$factByKey[$key].stringValue}}) -Unique)
        foreach($capability in $DecisionPolicyRegistry.capabilities){
            if($capability.eligibleLanes-cnotcontains$family.lane-or$capability.eligibleFamilyKindIds-cnotcontains$family.familyKindId){continue}
            if(@($capability.eligibleActorRoles).Count-and-not@($actorRoles|Where-Object{$_-cin@($capability.eligibleActorRoles)}).Count){continue}
            $laneCapability=$policy.capabilityProjectionRules|Where-Object capabilityId -CEQ $capability.capabilityId|Select-Object -First 1;if($null-eq$laneCapability){Add-C5Issue $issues 'LC-I07/LC-I11 capability union mismatch.';continue}
            $routes=@(Get-C5OrdinalValues @($capability.eligibleRouteKinds|Where-Object{$_-cin@($laneCapability.requiredRouteKinds)}) -Unique)
            foreach($route in $routes){
                $candidates=@(Get-C5OrdinalValues @($members|Where-Object staticStatus -CEQ StaticPassed|ForEach-Object assetObjectId));$selected=if($candidates.Count){$candidates[0]}else{$null};$evidenceKinds=@('CapabilitySuitability')
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

    $orderedRequirements=@(Get-C5OrdinalRows @($requirements) requirementId);$orderedAssessments=@(Get-C5OrdinalRows @($assessments) assessmentId);$orderedSuitability=@(Get-C5OrdinalRows @($suitabilityRequirements) suitabilityRequirementId);$orderedSuitabilityAssessments=@(Get-C5OrdinalRows @($suitabilityAssessments) suitabilityAssessmentId)
    $knownRequirementIds=@($orderedRequirements.requirementId)+@($orderedSuitability.suitabilityRequirementId)
    foreach($package in $EvidencePackages){if($package.requirementId-cnotin$knownRequirementIds){Add-C5Issue $issues 'Evidence package does not resolve to a C5 requirement.'}}
    [pscustomobject][ordered]@{
        status=if($issues.Count){'Failed'}else{'Passed'};issues=@(Get-C5OrdinalValues @($issues) -Unique);policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint;inputStaticFingerprint=$InputStaticFingerprint
        riskVariantCount=$orderedRequirements.Count;representativeRequirementCount=$orderedRequirements.Count;representativeRequiredCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ RepresentativeRequired).Count;evidenceAcceptedCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceAccepted).Count;evidenceMissingCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceMissing).Count;evidenceStaleCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ EvidenceStale).Count;unityExecutionUnavailableCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ UnityExecutionUnavailable).Count;representativeRejectedCount=@($orderedRequirements|Where-Object assessmentStatus -CEQ RepresentativeRejected).Count
        capabilitySuitabilityRequirementCount=$orderedSuitability.Count;suitabilityRequiredCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityRequired).Count;suitabilityAcceptedCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityAccepted).Count;suitabilityMissingCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityMissing).Count;suitabilityStaleCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityStale).Count;suitabilityExecutionUnavailableCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityExecutionUnavailable).Count;suitabilityRejectedCount=@($orderedSuitability|Where-Object assessmentStatus -CEQ SuitabilityRejected).Count
        requirements=$orderedRequirements;assessments=$orderedAssessments;capabilitySuitabilityRequirements=$orderedSuitability;capabilitySuitabilityAssessments=$orderedSuitabilityAssessments;executorLaunchCount=0;heavyOperationCount=0
    }
}

function ConvertTo-C5CanonicalJson([object]$Value){(($Value|ConvertTo-Json -Depth 100)-replace"`r`n","`n")+"`n"}

function Get-C5ArtifactSetFingerprint([object[]]$Entries){
    $ordered=@(Get-C5OrdinalRows $Entries path);$count=[string]$ordered.Count;$text="LifecycleStageInputV1`nentries.count:$($script:C5Utf8.GetByteCount($count)):$count`n"
    for($index=0;$index-lt$ordered.Count;$index++){$nested="C2ArtifactEntryV1`n"+(ConvertTo-C5ScalarLine artifactId ([string]$ordered[$index].artifactId))+(ConvertTo-C5ScalarLine path ([string]$ordered[$index].path))+(ConvertTo-C5ScalarLine sha256 ([string]$ordered[$index].sha256));$text+="entries[$index]:$($script:C5Utf8.GetByteCount($nested)):$nested`n"}
    Get-C5Sha256 $text
}

function Get-C5BaseDirectInputSpecs {
    [ordered]@{
        'C3-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json';'C3-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json';'C3-O03'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json';'C3-O04-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json';'C3-O04-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
        'C4-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json';'C4-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json';'C4-O03-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json';'C4-O03-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'
        'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json';'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json';'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json';'LC-I11'='docs/asset-migration/schemas/c3-c6-decision-policy-registry.json';'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
    }
}

function Get-C5BaseDirectInputs([object[]]$Entries){
    $expected=Get-C5BaseDirectInputSpecs
    $base=@($Entries|Where-Object{$_.artifactId-cne'LC-I09'-and$_.artifactId-cne'LC-I10'})
    if($base.Count-ne$expected.Count){throw 'C5 direct input set is invalid.'}
    $ids=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal)
    foreach($entry in $base){if(-not$expected.Contains([string]$entry.artifactId)-or$expected[[string]$entry.artifactId]-cne[string]$entry.path-or-not$ids.Add([string]$entry.artifactId)){throw 'C5 direct input contract is invalid.'}}
    @($base)
}

function Get-C5StageInputFingerprint([object[]]$Entries){
    $seen=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal)
    foreach($entry in $Entries){if((@($entry.PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or-not$seen.Add([string]$entry.path)-or-not(Test-C5PortablePath ([string]$entry.path))-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'){throw 'C5 direct input contract is invalid.'}}
    Get-C5BaseDirectInputs $Entries|Out-Null
    Get-C5ArtifactSetFingerprint $Entries
}

function Get-C5BaseInputAuthority {
    param(
        [object[]]$DirectInputs,[object[]]$ExecutionArtifacts,
        [object]$FamilyRegistry,[object]$MemberStaticQualification,[object[]]$RiskFactRows,
        [object]$LanePolicyRegistry,[string]$LanePolicyBytes,[object]$DecisionPolicyRegistry,[string]$DecisionPolicyBytes,
        [string[]]$RepresentativeStatuses,[string[]]$SuitabilityStatuses,[string]$StageSnapshotId
    )
    $issues=[Collections.Generic.List[string]]::new();$expected=Get-C5BaseDirectInputSpecs
    for($index=0;$index-lt$DirectInputs.Count;$index++){
        $entry=$DirectInputs[$index]
        if((@($entry.PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or-not(Test-C5PortablePath ([string]$entry.path))-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'-or($entry.artifactId-cne'LC-I09'-and$entry.artifactId-cne'LC-I10'-and-not$expected.Contains([string]$entry.artifactId))){Add-C5Issue $issues 'C5 direct input set is invalid.';break}
        if($index-gt0-and$script:C5Ordinal.Compare([string]$DirectInputs[$index-1].path,[string]$entry.path)-ge0){Add-C5Issue $issues 'C5 direct inputs are not unique Ordinal path order.';break}
    }
    $base=@($DirectInputs|Where-Object{$_.artifactId-cne'LC-I09'-and$_.artifactId-cne'LC-I10'})
    $directById=New-C5ArtifactMap $base artifactId;$executionById=New-C5ArtifactMap $ExecutionArtifacts artifactId
    if($null-eq$directById-or$base.Count-ne$expected.Count){Add-C5Issue $issues 'C5 base direct input registry is invalid.'}
    else{foreach($item in $expected.GetEnumerator()){if(-not$directById.ContainsKey([string]$item.Key)-or[string]$directById[[string]$item.Key].path-cne[string]$item.Value){Add-C5Issue $issues 'C5 base direct input registry is invalid.';break}}}
    if($null-eq$executionById-or$ExecutionArtifacts.Count-ne$expected.Count){Add-C5Issue $issues 'C5 base execution artifact set is invalid.'}
    else{foreach($item in $expected.GetEnumerator()){if(-not$executionById.ContainsKey([string]$item.Key)-or(@($executionById[[string]$item.Key].PSObject.Properties.Name)-join',')-cne'artifactId,bytes'-or$null-eq$executionById[[string]$item.Key].bytes){Add-C5Issue $issues 'C5 base execution artifact set is invalid.';break}}}
    if(-not$issues.Count){
        foreach($item in $expected.GetEnumerator()){
            $id=[string]$item.Key;$bytes=[string]$executionById[$id].bytes
            if($id-cnotlike'*-Report'){try{$null=$bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{Add-C5Issue $issues "C5 exact bytes are not valid JSON for $id.";break}}
            if([string]$directById[$id].sha256-cne(Get-C5Sha256 $bytes)){Add-C5Issue $issues "C5 exact-byte direct input hash mismatch for $id.";break}
        }
    }
    if(-not$issues.Count){
        if(-not(Test-C5JsonObjectBytesBinding $FamilyRegistry ([string]$executionById['C3-O01'].bytes))){Add-C5Issue $issues 'C3-O01 execution object does not match accepted bytes.'}
        elseif(-not(Test-C5JsonObjectBytesBinding $MemberStaticQualification ([string]$executionById['C4-O01'].bytes))){Add-C5Issue $issues 'C4-O01 execution object does not match accepted bytes.'}
        elseif(-not(Test-C5JsonProjectionBytesBinding $RiskFactRows ([string]$executionById['LC-I06'].bytes) rows)){Add-C5Issue $issues 'LC-I06 execution object does not match accepted bytes.'}
        elseif([string]$executionById['LC-I07'].bytes-cne$LanePolicyBytes-or-not(Test-C5JsonObjectBytesBinding $LanePolicyRegistry ([string]$executionById['LC-I07'].bytes))){Add-C5Issue $issues 'LC-I07 execution object does not match accepted bytes.'}
        elseif([string]$executionById['LC-I11'].bytes-cne$DecisionPolicyBytes-or-not(Test-C5JsonObjectBytesBinding $DecisionPolicyRegistry ([string]$executionById['LC-I11'].bytes))){Add-C5Issue $issues 'LC-I11 execution object does not match accepted bytes.'}
        elseif(-not(Test-C5JsonProjectionBytesBinding $RepresentativeStatuses ([string]$executionById['LC-I08'].bytes) representativeAssessment)-or-not(Test-C5JsonProjectionBytesBinding $SuitabilityStatuses ([string]$executionById['LC-I08'].bytes) capabilitySuitabilityStatus)){Add-C5Issue $issues 'LC-I08 execution vocabulary does not match accepted bytes.'}
    }
    if(-not$issues.Count){
        $c3Member=([string]$executionById['C3-O02'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $c3References=([string]$executionById['C3-O03'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $c3Summary=([string]$executionById['C3-O04-Summary'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $c4Family=([string]$executionById['C4-O02'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $c4Summary=([string]$executionById['C4-O03-Summary'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $laneFacts=([string]$executionById['LC-I06'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        foreach($c3Input in @($c3Member,$c3References)){if($c3Input.schemaVersion-cne$FamilyRegistry.schemaVersion-or$c3Input.generatedAt-cne$FamilyRegistry.generatedAt-or$c3Input.snapshotId-cne$FamilyRegistry.snapshotId-or$c3Input.inputFingerprint-cne$FamilyRegistry.inputFingerprint-or$c3Input.policySetFingerprint-cne$FamilyRegistry.policySetFingerprint){Add-C5Issue $issues 'C5 C3 generation identity is invalid.';break}}
        if(-not$issues.Count-and($c3Summary.failureAccounting.gateStatus-cne'Passed'-or$c3Summary.schemaVersion-cne$FamilyRegistry.schemaVersion-or$c3Summary.generatedAt-cne$FamilyRegistry.generatedAt-or$c3Summary.snapshotId-cne$FamilyRegistry.snapshotId-or$c3Summary.inputFingerprint-cne$FamilyRegistry.inputFingerprint-or$c3Summary.policySetFingerprint-cne$FamilyRegistry.policySetFingerprint)){Add-C5Issue $issues 'C5 C3 summary generation identity is invalid.'}
        if(-not$issues.Count-and($c4Family.schemaVersion-cne$MemberStaticQualification.schemaVersion-or$c4Family.generatedAt-cne$MemberStaticQualification.generatedAt-or$c4Family.snapshotId-cne$MemberStaticQualification.snapshotId-or$c4Family.inputFingerprint-cne$MemberStaticQualification.inputFingerprint-or$c4Family.policySetFingerprint-cne$MemberStaticQualification.policySetFingerprint)){Add-C5Issue $issues 'C5 C4 generation identity is invalid.'}
        if(-not$issues.Count-and($c4Summary.failureAccounting.gateStatus-cne'Passed'-or$c4Summary.schemaVersion-cne$MemberStaticQualification.schemaVersion-or$c4Summary.generatedAt-cne$MemberStaticQualification.generatedAt-or$c4Summary.snapshotId-cne$MemberStaticQualification.snapshotId-or$c4Summary.inputFingerprint-cne$MemberStaticQualification.inputFingerprint-or$c4Summary.policySetFingerprint-cne$MemberStaticQualification.policySetFingerprint)){Add-C5Issue $issues 'C5 C4 summary generation identity is invalid.'}
        if(-not$issues.Count-and($StageSnapshotId-cne$FamilyRegistry.snapshotId-or$StageSnapshotId-cne$MemberStaticQualification.snapshotId-or$StageSnapshotId-cne$laneFacts.snapshotId)){Add-C5Issue $issues 'C5 base input snapshot identity is invalid.'}
        $acceptedPolicyFingerprint=Get-C5Sha256 $LanePolicyBytes;$acceptedFactSchemaFingerprint=Get-C5Sha256 ([string]$executionById['LC-I13'].bytes)
        if(-not$issues.Count-and($FamilyRegistry.policySetFingerprint-cne$acceptedPolicyFingerprint-or$MemberStaticQualification.policySetFingerprint-cne$acceptedPolicyFingerprint-or$laneFacts.factContractFingerprint-cne$acceptedFactSchemaFingerprint)){Add-C5Issue $issues 'C5 base policy/schema fingerprint identity is invalid.'}
        foreach($binding in @(
            @($c3Summary,@('C3-O01','C3-O02','C3-O03','C3-O04-Report')),
            @($c4Summary,@('C4-O01','C4-O02','C4-O03-Report'))
        )){
            if($issues.Count){break};$summary=$binding[0];$ids=[string[]]$binding[1];$outputs=New-C5ArtifactMap @($summary.directOutputs) artifactId
            if($null-eq$outputs-or$outputs.Count-ne$ids.Count){Add-C5Issue $issues 'C5 child summary output registry is invalid.';break}
            foreach($id in $ids){$acceptedOutputSha=Get-C5Sha256 ([string]$executionById[$id].bytes);if(-not$outputs.ContainsKey($id)-or(@($outputs[$id].PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or[string]$outputs[$id].path-cne[string]$expected[$id]-or[string]$outputs[$id].sha256-cne$acceptedOutputSha){Add-C5Issue $issues 'C5 child summary does not bind accepted output bytes.';break}}
        }
    }
    $baseFingerprint=if($issues.Count){$null}else{Get-C5ArtifactSetFingerprint $base}
    [pscustomobject][ordered]@{valid=$issues.Count-eq0;issues=@($issues);baseInputFingerprint=$baseFingerprint}
}

function Get-C5EvidenceAuthority {
    param(
        [object[]]$DirectInputs,
        [AllowNull()][object]$Manifest,
        [AllowNull()][string]$ManifestBytes,
        [object[]]$Packages,
        [string[]]$PackageBytes,
        [string]$BaseInputFingerprint
    )
    $issues=[Collections.Generic.List[string]]::new()
    $manifestPath='Tools/AssetImport/Fixtures/FamilyQualificationGate/c7-evidence-manifest.json'
    $evidenceInputs=@($DirectInputs|Where-Object{$_.artifactId-ceq'LC-I09'-or$_.artifactId-ceq'LC-I10'})
    $manifestPresent=$null-ne$Manifest-or-not[string]::IsNullOrEmpty($ManifestBytes)
    if(-not$manifestPresent){
        if($Packages.Count-or$PackageBytes.Count-or$evidenceInputs.Count){Add-C5Issue $issues 'LC-I09 is absent but LC-I10 evidence is present.'}
        return [pscustomobject]@{issues=@($issues);manifestPath=$manifestPath}
    }
    if($null-eq$Manifest-or[string]::IsNullOrEmpty($ManifestBytes)){Add-C5Issue $issues 'LC-I09 object/bytes pair is incomplete.';return [pscustomobject]@{issues=@($issues);manifestPath=$manifestPath}}
    if(-not(Test-C5JsonObjectBytesBinding $Manifest $ManifestBytes)){Add-C5Issue $issues 'LC-I09 execution object does not match accepted bytes.'}
    $manifestInputs=@($evidenceInputs|Where-Object artifactId -CEQ 'LC-I09')
    if($manifestInputs.Count-ne1-or$manifestInputs[0].path-cne$manifestPath-or$manifestInputs[0].sha256-cne(Get-C5Sha256 $ManifestBytes)){Add-C5Issue $issues 'LC-I09 direct input path/SHA mismatch.'}
    if((@($Manifest.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,inputFingerprint,entries'-or$Manifest.schemaVersion-cne'1.0.0'-or$Manifest.generatedAt-cnotmatch'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'-or$Manifest.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'){Add-C5Issue $issues 'Invalid LC-I09 manifest shape.';return [pscustomobject]@{issues=@($issues);manifestPath=$manifestPath}}
    if($Manifest.inputFingerprint-cne$BaseInputFingerprint){Add-C5Issue $issues 'LC-I09 requirement generation fingerprint mismatch.'}
    if($Packages.Count-ne$PackageBytes.Count){Add-C5Issue $issues 'Evidence package object/bytes count mismatch.'}
    $packageById=@{}
    for($index=0;$index-lt[Math]::Min($Packages.Count,$PackageBytes.Count);$index++){
        $package=$Packages[$index];$bytes=$PackageBytes[$index]
        if(-not(Test-C5JsonObjectBytesBinding $package $bytes)){Add-C5Issue $issues 'LC-I10 execution object does not match accepted bytes.'}
        $idProperty=$package.PSObject.Properties['evidencePackageId']
        if($null-eq$idProperty){Add-C5Issue $issues 'Invalid evidence package shape.';continue}
        $id=[string]$idProperty.Value
        if($packageById.ContainsKey($id)){Add-C5Issue $issues 'Duplicate evidencePackageId.'}else{$packageById[$id]=[pscustomobject]@{package=$package;bytes=$bytes}}
    }
    $entries=@($Manifest.entries)
    if($entries.Count-ne$Packages.Count){Add-C5Issue $issues 'LC-I09 entry/package count mismatch.'}
    $paths=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal);$packageIds=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal);$requirementIds=[Collections.Generic.HashSet[string]]::new($script:C5Ordinal)
    $previousPath=$null
    foreach($entry in $entries){
        if((@($entry.PSObject.Properties.Name)-join',')-cne'path,sha256,evidencePackageId,requirementId'-or-not(Test-C5PortablePath ([string]$entry.path))-or$entry.path-ceq$manifestPath-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'-or$entry.evidencePackageId-cnotmatch'^evidence-package-sha256:[0-9a-f]{64}$'-or$entry.requirementId-cnotmatch'^(representative-requirement|capability-suitability-requirement)-sha256:[0-9a-f]{64}$'){Add-C5Issue $issues 'Invalid LC-I09 manifest entry.';continue}
        if($null-ne$previousPath-and$script:C5Ordinal.Compare($previousPath,[string]$entry.path)-ge0){Add-C5Issue $issues 'LC-I09 entries are not unique Ordinal path order.'};$previousPath=[string]$entry.path
        if(-not$paths.Add([string]$entry.path)-or-not$packageIds.Add([string]$entry.evidencePackageId)-or-not$requirementIds.Add([string]$entry.requirementId)){Add-C5Issue $issues 'LC-I09 entry identities are not unique.'}
        if(-not$packageById.ContainsKey([string]$entry.evidencePackageId)){Add-C5Issue $issues 'LC-I09 entry does not resolve to LC-I10 package.';continue}
        $document=$packageById[[string]$entry.evidencePackageId]
        if($entry.sha256-cne(Get-C5Sha256 ([string]$document.bytes))-or$entry.requirementId-cne$document.package.requirementId){Add-C5Issue $issues 'LC-I09/LC-I10 identity closure mismatch.'}
        $directPackage=@($evidenceInputs|Where-Object{$_.artifactId-ceq'LC-I10'-and$_.path-ceq$entry.path})
        if($directPackage.Count-ne1-or$directPackage[0].sha256-cne$entry.sha256){Add-C5Issue $issues 'LC-I10 direct input path/SHA mismatch.'}
    }
    if(@($evidenceInputs|Where-Object artifactId -CEQ 'LC-I10').Count-ne$entries.Count){Add-C5Issue $issues 'LC-I10 direct input count mismatch.'}
    [pscustomobject]@{issues=@($issues);manifestPath=$manifestPath}
}

function Get-C5AccountingId([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence){
    $text="LifecycleAccountingV1`n";foreach($pair in @(@('owningArray',$OwningArray),@('stageId','C5'),@('subjectKind',$SubjectKind),@('subjectId',$SubjectId),@('reasonCode',$ReasonCode),@('attribution',$Attribution))){$text+=ConvertTo-C5ScalarLine $pair[0] $pair[1]};$text+=Add-C5SetFrame evidence $Evidence
    "lifecycle-accounting-sha256:$(Get-C5Sha256 $text)"
}

function New-C5AccountingRow([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence){
    $values=@(Get-C5OrdinalValues $Evidence -Unique)
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
        [Parameter(Mandatory)][string[]]$RepresentativeStatuses,[Parameter(Mandatory)][string[]]$SuitabilityStatuses,
        [Parameter()][AllowNull()][object]$EvidenceManifest=$null,[Parameter()][AllowNull()][string]$EvidenceManifestBytes=$null,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$EvidencePackages,[Parameter(Mandatory)][AllowEmptyCollection()][string[]]$EvidencePackageBytes,
        [Parameter(Mandatory)][object[]]$ExecutionArtifacts,
        [Parameter(Mandatory)][object]$Stage
    )
    $directInputs=@($Stage.directInputs)
    $policySetFingerprint=Get-C5Sha256 $LanePolicyBytes;$decisionPolicyFingerprint=Get-C5Sha256 $DecisionPolicyBytes
    $baseAuthority=Get-C5BaseInputAuthority -DirectInputs $directInputs -ExecutionArtifacts $ExecutionArtifacts -FamilyRegistry $FamilyRegistry -MemberStaticQualification $MemberStaticQualification -RiskFactRows $RiskFactRows -LanePolicyRegistry $LanePolicyRegistry -LanePolicyBytes $LanePolicyBytes -DecisionPolicyRegistry $DecisionPolicyRegistry -DecisionPolicyBytes $DecisionPolicyBytes -RepresentativeStatuses $RepresentativeStatuses -SuitabilityStatuses $SuitabilityStatuses -StageSnapshotId ([string]$Stage.snapshotId)
    $authority=if($baseAuthority.valid){Get-C5EvidenceAuthority -DirectInputs $directInputs -Manifest $EvidenceManifest -ManifestBytes $EvidenceManifestBytes -Packages $EvidencePackages -PackageBytes $EvidencePackageBytes -BaseInputFingerprint $baseAuthority.baseInputFingerprint}else{[pscustomobject]@{issues=@();manifestPath='Tools/AssetImport/Fixtures/FamilyQualificationGate/c7-evidence-manifest.json'}}
    $inputFingerprint=if($baseAuthority.valid-and-not@($authority.issues).Count){Get-C5StageInputFingerprint $directInputs}else{$null}
    $c4Entries=@($directInputs|Where-Object artifactId -CIn @('C4-O01','C4-O02','C4-O03-Summary','C4-O03-Report'))
    $inputStaticFingerprint=if($baseAuthority.valid){Get-C5ArtifactSetFingerprint $c4Entries}else{$null}
    $kernel=if($baseAuthority.valid){
        Invoke-C5RequirementEvidenceKernel -FamilyRegistry $FamilyRegistry -MemberStaticQualification $MemberStaticQualification -RiskFactRows $RiskFactRows -LanePolicyRegistry $LanePolicyRegistry -LanePolicyBytes $LanePolicyBytes -DecisionPolicyRegistry $DecisionPolicyRegistry -DecisionPolicyBytes $DecisionPolicyBytes -RepresentativeStatuses $RepresentativeStatuses -SuitabilityStatuses $SuitabilityStatuses -InputStaticFingerprint $inputStaticFingerprint -EvidencePackages $EvidencePackages -EvidencePackageBytes $EvidencePackageBytes -EvidenceAuthorityIssues @($authority.issues)
    }else{
        [pscustomobject][ordered]@{status='Failed';issues=@($baseAuthority.issues);policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint;inputStaticFingerprint=$null;riskVariantCount=0;representativeRequirementCount=0;representativeRequiredCount=0;evidenceAcceptedCount=0;evidenceMissingCount=0;evidenceStaleCount=0;unityExecutionUnavailableCount=0;representativeRejectedCount=0;capabilitySuitabilityRequirementCount=0;suitabilityRequiredCount=0;suitabilityAcceptedCount=0;suitabilityMissingCount=0;suitabilityStaleCount=0;suitabilityExecutionUnavailableCount=0;suitabilityRejectedCount=0;requirements=@();assessments=@();capabilitySuitabilityRequirements=@();capabilitySuitabilityAssessments=@();executorLaunchCount=0;heavyOperationCount=0}
    }
    $prefix=[ordered]@{schemaVersion='1.0.0';generatedAt=[string]$Stage.generatedAt;snapshotId=[string]$Stage.snapshotId;inputFingerprint=$inputFingerprint;policySetFingerprint=$policySetFingerprint;decisionPolicyFingerprint=$decisionPolicyFingerprint}
    $paths=[ordered]@{requirements='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-representative-requirements.json';assessments='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json';requests='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c7-evidence-request.json';report='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-report.md'}
    $familyLane=@{};foreach($family in $FamilyRegistry.families){$familyLane[[string]$family.familyId]=[string]$family.lane}
    $requests=[Collections.Generic.List[object]]::new()
    foreach($assessment in @($kernel.assessments|Where-Object assessmentStatus -CIn @('EvidenceMissing','EvidenceStale','UnityExecutionUnavailable'))){$requirement=@($kernel.requirements|Where-Object requirementId -CEQ $assessment.requirementId)[0];$requests.Add([pscustomobject][ordered]@{requirementId=$requirement.requirementId;requirementKind='RiskVariant';familyId=$requirement.familyId;lane=$requirement.lane;capabilityId=$null;routeKind=$null;representativeAssetObjectId=$requirement.selectedRepresentativeAssetObjectId;requiredEvidenceKinds=@($requirement.requiredEvidenceKinds);reasonCode=$assessment.assessmentStatus;priority='Coverage';evidence=@($assessment.evidence)})}
    foreach($assessment in @($kernel.capabilitySuitabilityAssessments|Where-Object assessmentStatus -CIn @('SuitabilityMissing','SuitabilityStale','SuitabilityExecutionUnavailable'))){$requirement=@($kernel.capabilitySuitabilityRequirements|Where-Object suitabilityRequirementId -CEQ $assessment.suitabilityRequirementId)[0];$requests.Add([pscustomobject][ordered]@{requirementId=$requirement.suitabilityRequirementId;requirementKind='CapabilitySuitability';familyId=$requirement.familyId;lane=$familyLane[[string]$requirement.familyId];capabilityId=$requirement.capabilityId;routeKind=$requirement.routeKind;representativeAssetObjectId=$requirement.selectedRepresentativeAssetObjectId;requiredEvidenceKinds=@($requirement.requiredEvidenceKinds);reasonCode=$assessment.assessmentStatus;priority='RequiredCapability';evidence=@($assessment.evidence)})}
    $orderedRequests=@(Get-C5OrdinalRows @($requests) requirementId)
    $coverage=[pscustomobject][ordered]@{familyCount=@($FamilyRegistry.families).Count;riskVariantCount=$kernel.riskVariantCount;representativeRequirementCount=$kernel.representativeRequirementCount;representativeRequiredCount=$kernel.representativeRequiredCount;evidenceAcceptedCount=$kernel.evidenceAcceptedCount;evidenceMissingCount=$kernel.evidenceMissingCount;evidenceStaleCount=$kernel.evidenceStaleCount;unityExecutionUnavailableCount=$kernel.unityExecutionUnavailableCount;representativeRejectedCount=$kernel.representativeRejectedCount;capabilitySuitabilityRequirementCount=$kernel.capabilitySuitabilityRequirementCount;suitabilityRequiredCount=$kernel.suitabilityRequiredCount;suitabilityAcceptedCount=$kernel.suitabilityAcceptedCount;suitabilityMissingCount=$kernel.suitabilityMissingCount;suitabilityStaleCount=$kernel.suitabilityStaleCount;suitabilityExecutionUnavailableCount=$kernel.suitabilityExecutionUnavailableCount;suitabilityRejectedCount=$kernel.suitabilityRejectedCount;c7RequestCount=$orderedRequests.Count}
    $inputSubjectCount=$directInputs.Count+$coverage.familyCount+$coverage.representativeRequirementCount+$coverage.capabilitySuitabilityRequirementCount+$EvidencePackages.Count+2
    if($kernel.status-cne'Passed'){
        $baseFailure=-not$baseAuthority.valid;$failureCode=if($baseFailure){'LF-01'}else{'LF-15'};$subjectId=if($baseFailure){'C5:DirectInputs'}else{'C5:EvidenceContract'};$attribution="${failureCode}:$subjectId"
        $evidence=if($baseFailure){@((Get-C5BaseDirectInputSpecs).Values)}else{@(Get-C5OrdinalValues @($EvidencePackages|ForEach-Object evidencePaths|ForEach-Object{$_}) -Unique)};$evidence=@($evidence);if(-not$baseFailure-and$null-ne$EvidenceManifest){$evidence=@(Get-C5OrdinalValues (@($evidence)+@($authority.manifestPath)) -Unique)};if($evidence.Count-eq0){$evidence=@('Tools/AssetImport/Test-C5RequirementEvidenceGate.ps1')}
        $failure=New-C5AccountingRow inputFailures $(if($baseFailure){'FreshnessCheck'}else{'ConservationCheck'}) $subjectId $(if($baseFailure){'PrerequisiteInvalid'}else{'EvidenceContractInvalid'}) $attribution $evidence
        $outputFailures=@(New-C5AccountingRow outputFailures OutputArtifact 'C5-O01' SuppressedByGate "${failureCode}:C5-O01" @($paths.requirements);New-C5AccountingRow outputFailures OutputArtifact 'C5-O02' SuppressedByGate "${failureCode}:C5-O02" @($paths.assessments);New-C5AccountingRow outputFailures OutputArtifact 'C5-O03' SuppressedByGate "${failureCode}:C5-O03" @($paths.requests))
        $acceptedInputCount=if($baseFailure){0}else{[Math]::Max(0,$inputSubjectCount-2)};$notEvaluatedCount=if($baseFailure){[Math]::Max(1,$inputSubjectCount-$directInputs.Count)}else{1}
        $accounting=[pscustomobject][ordered]@{inputSubjectCount=$inputSubjectCount;acceptedInputSubjectCount=$acceptedInputCount;inputFailureCount=1;notEvaluatedInputSubjectCount=$notEvaluatedCount;outputCandidateCount=4;projectedOutputCount=1;outputFailureCount=3;issueCount=1;gateStatus='Failed';inputFailures=@($failure);inputSuppressions=@();outputFailures=$outputFailures}
        $nextAction=if($baseFailure){'Restore the exact, complete, same-generation C5 prerequisite set.'}else{'Correct evidence authority/producer.'};$decision=[pscustomobject][ordered]@{failureAttribution=$attribution;nextAllowedAction=$nextAction};$report=New-C5Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
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
