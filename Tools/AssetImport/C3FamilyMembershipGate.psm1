Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:C3Utf8 = [Text.UTF8Encoding]::new($false)
$script:C3Ordinal = [StringComparer]::Ordinal

function Get-C3Sha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C3Utf8.GetBytes($Text))).ToLowerInvariant()
}

function Get-C3OrdinalValues([object[]]$Values,[switch]$Unique) {
    $list=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal)
    foreach($value in $Values){$text=[string]$value;if(-not$Unique-or$seen.Add($text)){$list.Add($text)}}
    $list.Sort($script:C3Ordinal);[string[]]$list.ToArray()
}

function Get-C3OrdinalRows([object[]]$Rows,[string[]]$Properties) {
    $list=[Collections.Generic.List[object]]::new();foreach($row in $Rows){$list.Add($row)}
    $list.Sort([Comparison[object]]{param($a,$b)foreach($property in $Properties){$comparison=$script:C3Ordinal.Compare([string]$a.$property,[string]$b.$property);if($comparison){return $comparison}};0})
    [object[]]$list.ToArray()
}

function Test-C3JsonObjectBytesBinding([object]$Value,[string]$Bytes) {
    try{$parsed=$Bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{return $false}
    ($Value|ConvertTo-Json -Depth 100 -Compress)-ceq($parsed|ConvertTo-Json -Depth 100 -Compress)
}

function Get-C3StageInputFingerprint([object[]]$Entries) {
    $ordered=@(Get-C3OrdinalRows $Entries @('path'));$seen=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal)
    $text='LifecycleStageInputV1' + "`n" + "entries.count:$($ordered.Count)`n"
    for($index=0;$index-lt$ordered.Count;$index++){
        $entry=$ordered[$index];if((@($entry.PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or-not$seen.Add([string]$entry.path)-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'){throw 'C3 direct input contract is invalid.'}
        $nested='C2ArtifactEntryV1' + "`n" + (ConvertTo-C3ScalarLine path ([string]$entry.path)) + (ConvertTo-C3ScalarLine sha256 ([string]$entry.sha256))
        $text+="entries[$index]:$($script:C3Utf8.GetByteCount($nested)):$nested`n"
    }
    Get-C3Sha256 $text
}

function ConvertTo-C3ScalarLine([string]$Name,[string]$Value) {
    if ($null -eq $Value -or $Value.IndexOfAny([char[]]@([char]0,"`r","`n")) -ge 0) { throw "Invalid framed scalar: $Name" }
    "${Name}:$($script:C3Utf8.GetByteCount($Value)):${Value}`n"
}

function Get-C3DispatchSelectorState([object]$Dispatch) {
    $allowedKinds=@('CanonicalAssetId','ClassId','DependencyObjectId','ObjectType','PlatformVariant','ToolObservation')
    $counts=@{};foreach($kind in $allowedKinds){$counts[$kind]=0}
    $dependencies=[Collections.Generic.List[string]]::new();$pairs=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal)
    foreach($selector in @($Dispatch.memberSelectorInputs)){
        if((@($selector.PSObject.Properties.Name)-join',')-cne'kind,value'-or[string]::IsNullOrWhiteSpace([string]$selector.kind)-or[string]::IsNullOrWhiteSpace([string]$selector.value)-or$selector.kind -CNotIn $allowedKinds){return [pscustomobject]@{valid=$false;dependencyObjectIds=@()}}
        $pair="$($selector.kind)`n$($selector.value)";if(-not$pairs.Add($pair)){return [pscustomobject]@{valid=$false;dependencyObjectIds=@()}}
        $counts[[string]$selector.kind]++
        if($selector.kind-ceq'DependencyObjectId'){$dependencies.Add([string]$selector.value)}
    }
    if($counts.CanonicalAssetId-ne1-or$counts.ClassId-ne1-or$counts.ObjectType-ne1-or$counts.PlatformVariant-ne1-or$counts.ToolObservation-lt1){return [pscustomobject]@{valid=$false;dependencyObjectIds=@()}}
    $values=@($dependencies);if($values.Count-gt1){[Array]::Sort($values,$script:C3Ordinal)}
    [pscustomobject]@{valid=$true;dependencyObjectIds=$values}
}

function Test-C3OrdinalArrayEqual([object[]]$Left,[object[]]$Right) {
    $a=@($Left);$b=@($Right);if($a.Count-gt1){[Array]::Sort($a,$script:C3Ordinal)};if($b.Count-gt1){[Array]::Sort($b,$script:C3Ordinal)}
    if($a.Count-ne$b.Count){return $false};for($i=0;$i-lt$a.Count;$i++){if([string]$a[$i]-cne[string]$b[$i]){return $false}};$true
}

function Add-C3ReferenceClaim([hashtable]$Claims,[string]$FromId,[string]$ToId,[string]$FromLane,[string]$ToLane,[string]$Kind,[string]$Status,[string[]]$Evidence) {
    $key="$FromId|$ToId|$Kind"
    if(-not$Claims.ContainsKey($key)){$Claims[$key]=[pscustomobject]@{fromAssetObjectId=$FromId;toAssetObjectId=$ToId;fromLane=$FromLane;referenceKind=$Kind;statuses=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal);toLanes=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal);evidence=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal)}}
    $null=$Claims[$key].statuses.Add($Status);$null=$Claims[$key].toLanes.Add($ToLane);foreach($path in $Evidence){$null=$Claims[$key].evidence.Add([string]$path)}
}

function ConvertTo-C3FactFrame([object]$Fact) {
    $text = 'C3FamilyKeyDimensionV1' + "`n"
    foreach ($name in @('factKind','factStatus','valueKind')) { $text += ConvertTo-C3ScalarLine $name ([string]$Fact.$name) }
    foreach ($name in @('stringValue','integerValue','booleanValue')) {
        $value = $Fact.$name
        $text += if ($null -eq $value) { "$name:null`n" } else { ConvertTo-C3ScalarLine $name ([string]$value).ToLowerInvariant() }
    }
    $values = @($Fact.idValues); if ($values.Count -gt 1) { [Array]::Sort($values,$script:C3Ordinal) }
    $text += "idValues.count:$($values.Count)`n"
    for ($index=0;$index-lt$values.Count;$index++) { $text += ConvertTo-C3ScalarLine "idValues[$index]" $values[$index] }
    $text
}

function New-C3FamilyIdentity([object]$Policy,[object]$FamilyKind,[object[]]$KeyFacts,[string]$PolicySetFingerprint) {
    $keyText = 'C3FamilyKeyV1' + "`n"
    $keyText += ConvertTo-C3ScalarLine lane ([string]$Policy.lane)
    $keyText += ConvertTo-C3ScalarLine familyKindId ([string]$FamilyKind.familyKindId)
    $keyText += ConvertTo-C3ScalarLine policyId ([string]$Policy.policyId)
    $keyText += ConvertTo-C3ScalarLine policyVersion ([string]$Policy.policyVersion)
    $keyText += "dimensions.count:$($KeyFacts.Count)`n"
    for ($index=0;$index-lt$KeyFacts.Count;$index++) {
        $frame = ConvertTo-C3FactFrame $KeyFacts[$index]
        $keyText += "dimensions[$index]:$($script:C3Utf8.GetByteCount($frame)):$frame`n"
    }
    $keyFingerprint = Get-C3Sha256 $keyText
    $familyText = 'C3FamilyV1' + "`n" + (ConvertTo-C3ScalarLine policySetFingerprint $PolicySetFingerprint) + (ConvertTo-C3ScalarLine familyKeyFingerprint $keyFingerprint)
    [pscustomobject][ordered]@{familyKeyFingerprint=$keyFingerprint;familyId="family-sha256:$(Get-C3Sha256 $familyText)"}
}

function Invoke-C3FamilyMembershipKernel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$DispatchRows,
        [Parameter(Mandatory)][object[]]$TypedFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][string[]]$FamilyParentStatuses,
        [Parameter(Mandatory)][object[]]$LedgerObjects,
        [Parameter(Mandatory)][object[]]$ConfigurationCandidates
    )

    $issues = [Collections.Generic.List[string]]::new()
    if (($FamilyParentStatuses -join ',') -cne 'AssignedFamilyMember,RetainedForDiagnosis,ConfigurationOnly') { $issues.Add('C3 family-parent vocabulary is invalid.') }
    if(-not(Test-C3JsonObjectBytesBinding $LanePolicyRegistry $LanePolicyBytes)){$issues.Add('LC-I07 execution object does not match accepted bytes.')}
    if ((@($LanePolicyRegistry.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,policySetId,policySetVersion,policies' -or $LanePolicyRegistry.schemaVersion -cne '1.0.0' -or $LanePolicyRegistry.generatedAt-cne'2026-07-15T00:00:00Z' -or $LanePolicyRegistry.policySetId-cne'StellaSoraLifecycleLanePolicySet' -or $LanePolicyRegistry.policySetVersion-cne'1.0.0') { $issues.Add('LC-I07 registry shape is invalid.') }
    $policySetFingerprint = Get-C3Sha256 $LanePolicyBytes
    if($policySetFingerprint-cne'7fdde7cb9d709be5e11fb3391053b8f0cb3e26348d481bc8d6cc26d904b69862'){$issues.Add('LC-I07 registry fingerprint is invalid.')}

    $dispatchById = @{}
    foreach ($row in $DispatchRows) {
        $id = [string]$row.assetObjectId
        if ([string]::IsNullOrWhiteSpace($id) -or $dispatchById.ContainsKey($id)) { $issues.Add('Duplicate dispatch assetObjectId.'); continue }
        $dispatchById[$id] = $row
    }
    if ($issues.Count) { return [pscustomobject][ordered]@{status='Failed';issues=$issues.ToArray();families=@();memberRows=@();crossLaneReferences=@();dispatchEligibleObjectCount=$DispatchRows.Count;assignedFamilyMemberCount=0;retainedForDiagnosisObjectCount=0;configurationOnlyObjectCount=0} }

    $factsByObject = @{}
    foreach ($fact in $TypedFactRows) {
        $objectId = [string]$fact.assetObjectId
        if (-not $factsByObject.ContainsKey($objectId)) { $factsByObject[$objectId] = [Collections.Generic.List[object]]::new() }
        if (@($factsByObject[$objectId] | Where-Object factKind -CEQ $fact.factKind).Count) { $issues.Add("Duplicate typed fact '$objectId/$($fact.factKind)'."); continue }
        $factsByObject[$objectId].Add($fact)
    }
    if ($issues.Count) { return [pscustomobject][ordered]@{status='Failed';issues=$issues.ToArray();families=@();memberRows=@();crossLaneReferences=@();dispatchEligibleObjectCount=$DispatchRows.Count;assignedFamilyMemberCount=0;retainedForDiagnosisObjectCount=0;configurationOnlyObjectCount=0} }

    $familyMap = @{}
    $memberRows = [Collections.Generic.List[object]]::new()
    foreach ($dispatch in @(Get-C3OrdinalRows $DispatchRows @('assetObjectId'))) {
        $objectId = [string]$dispatch.assetObjectId
        $parentStatus = $null; $familyId = $null; $familyKindId = $null
        if ($dispatch.dispatchStatus -ceq 'ConfigurationOnly' -and $dispatch.familyLane -ceq 'Unassigned' -and $null -ne $dispatch.configurationCandidateId) {
            $parentStatus = 'ConfigurationOnly'
        }
        elseif ($dispatch.dispatchStatus -ceq 'RetainedForDiagnosis' -and $dispatch.familyLane -ceq 'Unassigned' -and $null -eq $dispatch.configurationCandidateId) {
            $parentStatus = 'RetainedForDiagnosis'
        }
        elseif ($dispatch.dispatchStatus -ceq 'Assigned') {
            $policies = @($LanePolicyRegistry.policies | Where-Object lane -CEQ $dispatch.familyLane)
            if ($policies.Count -eq 1 -and @($policies[0].familyKinds).Count -eq 1) {
                $policy = $policies[0]; $familyKind = $policy.familyKinds[0]; $keyFacts = [Collections.Generic.List[object]]::new(); $keyValid = $true
                foreach ($dimension in @($familyKind.keyDimensionIds)) {
                    $matches = if ($factsByObject.ContainsKey($objectId)) { @($factsByObject[$objectId] | Where-Object factKind -CEQ $dimension) } else { @() }
                    $definition = @($policy.factDefinitions | Where-Object factKind -CEQ $dimension)
                    if ($matches.Count -ne 1 -or $definition.Count -ne 1 -or ($matches[0].factStatus -cne 'Known' -and -not ($matches[0].factStatus -ceq 'NotApplicable' -and $definition[0].allowNotApplicable -eq $true))) { $keyValid=$false; break }
                    $keyFacts.Add($matches[0])
                }
                if($keyValid){
                    $selectorState=Get-C3DispatchSelectorState $dispatch
                    foreach($definition in @($policy.factDefinitions|Where-Object{$_.requiredForFamilyKinds-ccontains$familyKind.familyKindId-and$_.factKind -CNotIn @($familyKind.keyDimensionIds)})){
                        $matches=@(if($factsByObject.ContainsKey($objectId)){$factsByObject[$objectId]|Where-Object factKind -CEQ $definition.factKind})
                        if($definition.factKind-ceq'DependencyObjectIds'){
                            if(-not$selectorState.valid-or($matches.Count-eq0-and@($selectorState.dependencyObjectIds).Count-ne0)-or($matches.Count-eq1-and($matches[0].factStatus-cne'Known'-or$matches[0].valueKind-cne'IdSet'-or-not(Test-C3OrdinalArrayEqual @($matches[0].idValues) @($selectorState.dependencyObjectIds))))-or$matches.Count-gt1){$keyValid=$false;break}
                        }
                        elseif($matches.Count-ne1-or$matches[0].factStatus-cne'Known'){$keyValid=$false;break}
                    }
                }
                if ($keyValid) {
                    $identity = New-C3FamilyIdentity $policy $familyKind $keyFacts.ToArray() $policySetFingerprint
                    $familyId=$identity.familyId;$familyKindId=[string]$familyKind.familyKindId;$parentStatus='AssignedFamilyMember'
                    if (-not $familyMap.ContainsKey($familyId)) { $familyMap[$familyId]=[pscustomobject][ordered]@{familyId=$familyId;lane=[string]$policy.lane;familyKindId=$familyKindId;familyKeyFingerprint=$identity.familyKeyFingerprint;memberObjectIds=[Collections.Generic.List[string]]::new()} }
                    $familyMap[$familyId].memberObjectIds.Add($objectId)
                }
            }
            if ($null -eq $parentStatus) { $parentStatus='RetainedForDiagnosis' }
        }
        else { $issues.Add("Invalid dispatch terminal state: '$objectId'."); continue }
        $memberRows.Add([pscustomobject][ordered]@{assetObjectId=$objectId;parentStatus=$parentStatus;familyId=$familyId;familyKindId=$familyKindId;configurationCandidateId=if($parentStatus-ceq'ConfigurationOnly'){$dispatch.configurationCandidateId}else{$null}})
    }
    if ($issues.Count -or $memberRows.Count -ne $DispatchRows.Count) { return [pscustomobject][ordered]@{status='Failed';issues=$issues.ToArray();families=@();memberRows=$memberRows.ToArray();crossLaneReferences=@();dispatchEligibleObjectCount=$DispatchRows.Count;assignedFamilyMemberCount=0;retainedForDiagnosisObjectCount=0;configurationOnlyObjectCount=0} }

    $families = [Collections.Generic.List[object]]::new()
    foreach ($family in @(Get-C3OrdinalRows @($familyMap.Values) @('familyId'))) {
        $ids=@($family.memberObjectIds);if($ids.Count-gt1){[Array]::Sort($ids,$script:C3Ordinal)}
        $families.Add([pscustomobject][ordered]@{familyId=$family.familyId;lane=$family.lane;familyKindId=$family.familyKindId;familyKeyFingerprint=$family.familyKeyFingerprint;memberCount=$ids.Count;memberObjectIds=$ids})
    }
    $ledgerById=@{};foreach($row in $LedgerObjects){$id=[string]$row.assetObjectId;if(-not$ledgerById.ContainsKey($id)){$ledgerById[$id]=[Collections.Generic.List[object]]::new()};$ledgerById[$id].Add($row)}
    $configurationById=@{};foreach($row in $ConfigurationCandidates){$id=[string]$row.configurationCandidateId;if(-not$configurationById.ContainsKey($id)){$configurationById[$id]=[Collections.Generic.List[object]]::new()};$configurationById[$id].Add($row)}
    $claims=@{}
    foreach($source in $LedgerObjects){
        $fromId=[string]$source.assetObjectId;$fromLane=if($dispatchById.ContainsKey($fromId)){[string]$dispatchById[$fromId].familyLane}else{'Unassigned'}
        foreach($toId in @($source.dependencyObjectIds)){
            $targetCount=if($ledgerById.ContainsKey([string]$toId)){$ledgerById[[string]$toId].Count}else{0};$toLane=if($dispatchById.ContainsKey([string]$toId)){[string]$dispatchById[[string]$toId].familyLane}else{'Unassigned'};$status=if($targetCount-eq1){'Resolved'}elseif($targetCount-eq0){'Missing'}else{'Conflict'}
            Add-C3ReferenceClaim $claims $fromId ([string]$toId) $fromLane $toLane Dependency $status @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json')
        }
    }
    foreach($fact in $TypedFactRows){
        if($fact.factStatus-cne'Known'){continue};$kind=$null;$targets=@();$identityTarget=$false
        switch([string]$fact.factKind){
            'AudioDependencyIds'{$kind='AudioCoupling';$targets=@($fact.idValues)}
            'ShaderFamilyIds'{$kind='ShaderCoupling';$targets=@($fact.idValues|Where-Object{$_ -cmatch'^shader-family-sha256:[0-9a-f]{64}$'});$identityTarget=$true}
            'FontDependencyIds'{$kind='AtlasFontCoupling';$targets=@($fact.idValues)}
            'AtlasId'{$kind='AtlasFontCoupling';$targets=@([string]$fact.stringValue|Where-Object{$_ -cmatch'^atlas-sha256:[0-9a-f]{64}$'});$identityTarget=$true}
        }
        if($null-eq$kind){continue};$fromId=[string]$fact.assetObjectId;$fromLane=if($dispatchById.ContainsKey($fromId)){[string]$dispatchById[$fromId].familyLane}else{'Unassigned'}
        foreach($toId in $targets){
            if([string]::IsNullOrWhiteSpace([string]$toId)){continue}
            if($identityTarget){$status='Resolved';$toLane='Unassigned'}else{$targetCount=if($ledgerById.ContainsKey([string]$toId)){$ledgerById[[string]$toId].Count}else{0};$toLane=if($dispatchById.ContainsKey([string]$toId)){[string]$dispatchById[[string]$toId].familyLane}else{'Unassigned'};$status=if($targetCount-eq1){'Resolved'}elseif($targetCount-eq0){'Missing'}else{'Conflict'}}
            Add-C3ReferenceClaim $claims $fromId ([string]$toId) $fromLane $toLane $kind $status @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json')
        }
    }
    foreach($from in $DispatchRows){
        if($null-eq$from.configurationCandidateId){continue};$candidateId=[string]$from.configurationCandidateId;$targets=@(if($configurationById.ContainsKey($candidateId)){$configurationById[$candidateId]})
        if($targets.Count-eq0){$toId=[string]$from.assetObjectId;$status='Missing'}
        else{
            $targetIds=@(Get-C3OrdinalValues @($targets|ForEach-Object assetObjectId|Where-Object{$null-ne$_}) -Unique)
            if($targetIds.Count-ne1){$issues.Add("Non-unique configuration coupling target: '$candidateId'.");continue}
            $toId=[string]$targetIds[0];$status=if($targets.Count-eq1){'Resolved'}else{'Conflict'}
        }
        $toLane=if($dispatchById.ContainsKey($toId)){[string]$dispatchById[$toId].familyLane}else{'Unassigned'}
        Add-C3ReferenceClaim $claims ([string]$from.assetObjectId) $toId ([string]$from.familyLane) $toLane ConfigurationCoupling $status @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json')
    }
    $references=[Collections.Generic.List[object]]::new()
    foreach($claim in $claims.Values){
        $statuses=@($claim.statuses);$lanes=@($claim.toLanes);$evidence=@($claim.evidence);if($evidence.Count-gt1){[Array]::Sort($evidence,$script:C3Ordinal)}
        $resolution=if($statuses.Count-ne1-or$lanes.Count-ne1-or$statuses[0]-ceq'Conflict'){'Conflict'}else{$statuses[0]}
        $toLane=if($lanes.Count-eq1){$lanes[0]}else{'Unassigned'}
        $references.Add([pscustomobject][ordered]@{fromAssetObjectId=$claim.fromAssetObjectId;toAssetObjectId=$claim.toAssetObjectId;fromLane=$claim.fromLane;toLane=$toLane;referenceKind=$claim.referenceKind;resolutionStatus=$resolution;evidence=$evidence})
    }
    $references.Sort([Comparison[object]]{param($a,$b)$script:C3Ordinal.Compare("$($a.fromAssetObjectId)|$($a.toAssetObjectId)|$($a.referenceKind)","$($b.fromAssetObjectId)|$($b.toAssetObjectId)|$($b.referenceKind)")})
    $assigned=@($memberRows|Where-Object parentStatus -CEQ AssignedFamilyMember).Count;$retained=@($memberRows|Where-Object parentStatus -CEQ RetainedForDiagnosis).Count;$configuration=@($memberRows|Where-Object parentStatus -CEQ ConfigurationOnly).Count
    if ($DispatchRows.Count -ne $assigned+$retained+$configuration -or $assigned -ne (($families.memberCount|Measure-Object -Sum).Sum)) { $issues.Add('C3 family membership conservation failed.') }
    [pscustomobject][ordered]@{status=if($issues.Count){'Failed'}else{'Passed'};issues=$issues.ToArray();families=$families.ToArray();memberRows=$memberRows.ToArray();crossLaneReferences=$references.ToArray();dispatchEligibleObjectCount=$DispatchRows.Count;assignedFamilyMemberCount=$assigned;retainedForDiagnosisObjectCount=$retained;configurationOnlyObjectCount=$configuration}
}

function ConvertTo-C3CanonicalJson([object]$Value) {
    (($Value | ConvertTo-Json -Depth 100) -replace "`r`n","`n") + "`n"
}

function ConvertTo-C3NullableLine([string]$Name,[AllowNull()][object]$Value) {
    if ($null -eq $Value) { return "${Name}:null`n" }
    ConvertTo-C3ScalarLine $Name ([string]$Value)
}

function Get-C3MemberRecordId([object]$Row) {
    $text='C3FamilyMemberV1' + "`n" + (ConvertTo-C3ScalarLine assetObjectId $Row.assetObjectId) + (ConvertTo-C3ScalarLine parentStatus $Row.parentStatus) + (ConvertTo-C3NullableLine familyId $Row.familyId) + (ConvertTo-C3NullableLine configurationCandidateId $Row.configurationCandidateId)
    "family-member-sha256:$(Get-C3Sha256 $text)"
}

function Get-C3ReferenceId([object]$Row) {
    $text='C3CrossLaneReferenceV1' + "`n"
    foreach($name in @('fromAssetObjectId','toAssetObjectId','fromLane','toLane','referenceKind')){$text+=ConvertTo-C3ScalarLine $name ([string]$Row.$name)}
    "cross-lane-reference-sha256:$(Get-C3Sha256 $text)"
}

function Get-C3AccountingId([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence) {
    $values=@($Evidence);if($values.Count-gt1){[Array]::Sort($values,$script:C3Ordinal)}
    $text='LifecycleAccountingV1' + "`n"
    foreach($pair in @(@('owningArray',$OwningArray),@('stageId','C3'),@('subjectKind',$SubjectKind),@('subjectId',$SubjectId),@('reasonCode',$ReasonCode),@('attribution',$Attribution))){$text+=ConvertTo-C3ScalarLine $pair[0] $pair[1]}
    $text+="evidence.count:$($values.Count)`n";for($i=0;$i-lt$values.Count;$i++){$text+=ConvertTo-C3ScalarLine "evidence[$i]" $values[$i]}
    "lifecycle-accounting-sha256:$(Get-C3Sha256 $text)"
}

function New-C3AccountingRow([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence) {
    $values=@($Evidence);if($values.Count-gt1){[Array]::Sort($values,$script:C3Ordinal)}
    [pscustomobject][ordered]@{recordId=Get-C3AccountingId $OwningArray $SubjectKind $SubjectId $ReasonCode $Attribution $values;stageId='C3';subjectKind=$SubjectKind;subjectId=$SubjectId;reasonCode=$ReasonCode;attribution=$Attribution;evidence=$values}
}

function New-C3Report([object]$Stage,[string]$InputFingerprint,[string]$PolicySetFingerprint,[object]$Accounting,[object]$Decision) {
    "# C3 Lifecycle Gate Report`n"+
    "schemaVersion: 1.0.0`n"+
    "generatedAt: $($Stage.generatedAt)`n"+
    "stageId: C3`n"+
    "snapshotId: $($Stage.snapshotId)`n"+
    "inputFingerprint: $InputFingerprint`n"+
    "policySetFingerprint: $PolicySetFingerprint`n"+
    "gateStatus: $($Accounting.gateStatus)`n"+
    "inputSubjectCount: $($Accounting.inputSubjectCount)`n"+
    "inputFailureCount: $($Accounting.inputFailureCount)`n"+
    "notEvaluatedInputSubjectCount: $($Accounting.notEvaluatedInputSubjectCount)`n"+
    "outputCandidateCount: $($Accounting.outputCandidateCount)`n"+
    "projectedOutputCount: $($Accounting.projectedOutputCount)`n"+
    "outputFailureCount: $($Accounting.outputFailureCount)`n"+
    "issueCount: $($Accounting.issueCount)`n"+
    "failureAttribution: $($Decision.failureAttribution)`n"+
    "nextAllowedAction: $($Decision.nextAllowedAction)`n"
}

function Invoke-C3FamilyMembershipGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$DispatchRows,
        [Parameter(Mandatory)][object[]]$TypedFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][string[]]$FamilyParentStatuses,
        [Parameter(Mandatory)][object[]]$LedgerObjects,
        [Parameter(Mandatory)][object[]]$ConfigurationCandidates,
        [Parameter(Mandatory)][object]$Stage
    )
    $kernel=Invoke-C3FamilyMembershipKernel $DispatchRows $TypedFactRows $LanePolicyRegistry $LanePolicyBytes $FamilyParentStatuses $LedgerObjects $ConfigurationCandidates
    $policySetFingerprint=Get-C3Sha256 $LanePolicyBytes
    $directInputs=@(Get-C3OrdinalRows $Stage.directInputs @('path'));$inputFingerprint=Get-C3StageInputFingerprint $directInputs
    $paths=[ordered]@{familyRegistry='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json';familyMemberLedger='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json';crossLaneReferencePackage='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json';report='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'}
    $ledgerById=@{};foreach($row in $LedgerObjects){$ledgerById[[string]$row.assetObjectId]=$row}
    $prefix=[ordered]@{schemaVersion='1.0.0';generatedAt=[string]$Stage.generatedAt;snapshotId=[string]$Stage.snapshotId;inputFingerprint=$inputFingerprint;policySetFingerprint=$policySetFingerprint}
    $coverage=[ordered]@{dispatchEligibleObjectCount=$DispatchRows.Count;dispatchEligibleObjectBytes=0;assignedFamilyMemberCount=0;assignedFamilyMemberBytes=0;retainedForDiagnosisObjectCount=0;retainedForDiagnosisObjectBytes=0;configurationOnlyObjectCount=0;configurationOnlyObjectBytes=0;familyCount=0;referenceCount=0;resolvedReferenceCount=0;missingReferenceCount=0;conflictReferenceCount=0}
    foreach($dispatch in $DispatchRows){if($ledgerById.ContainsKey([string]$dispatch.assetObjectId)){$coverage.dispatchEligibleObjectBytes += [long]$ledgerById[[string]$dispatch.assetObjectId].serializedSizeBytes}}

    if($kernel.status-cne'Passed'){
        $failureId='LF-05';$subjectKind='ConservationCheck';$subjectId='C3:MembershipConservation';$reasonCode='ConservationMismatch';$nextAction='Correct C3 producer; no C4-C6.';$evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json')
        if(@($kernel.issues|Where-Object{$_-like'Duplicate typed fact*'}).Count){$failureId='LF-02';$subjectKind='Artifact';$subjectId='LC-I06';$reasonCode='InvalidTypedFact';$nextAction='Correct typed projection contract/fixture.';$evidence=@('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json')}
        elseif(@($kernel.issues|Where-Object{$_-like'LC-I07*'}).Count){$failureId='LF-03';$subjectKind='Artifact';$subjectId='LC-I07';$reasonCode='InvalidPolicy';$nextAction='Correct reviewed policy artifact.';$evidence=@('docs/asset-migration/schemas/c3-c6-lane-policy-registry.json')}
        $attribution="$failureId`:$subjectId";$failure=New-C3AccountingRow inputFailures $subjectKind $subjectId $reasonCode $attribution $evidence
        $outputFailures=[Collections.Generic.List[object]]::new();foreach($entry in @(@('C3-O01',$paths.familyRegistry),@('C3-O02',$paths.familyMemberLedger),@('C3-O03',$paths.crossLaneReferencePackage))){$outputFailures.Add((New-C3AccountingRow outputFailures OutputArtifact $entry[0] SuppressedByGate "$failureId`:$($entry[0])" @($entry[1])))}
        $accounting=[pscustomobject][ordered]@{inputSubjectCount=$directInputs.Count+$DispatchRows.Count+1;acceptedInputSubjectCount=$directInputs.Count;inputFailureCount=1;notEvaluatedInputSubjectCount=$DispatchRows.Count;outputCandidateCount=4;projectedOutputCount=1;outputFailureCount=3;issueCount=1;gateStatus='Failed';inputFailures=@($failure);inputSuppressions=@();outputFailures=$outputFailures.ToArray()}
        $decision=[pscustomobject][ordered]@{failureAttribution=$attribution;nextAllowedAction=$nextAction}
        $report=New-C3Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
        $directOutputs=@([pscustomobject][ordered]@{artifactId='C3-O04-Report';path=$paths.report;sha256=Get-C3Sha256 $report})
        $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C3';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=[pscustomobject]$coverage;failureAccounting=$accounting;decision=$decision}
        return [pscustomobject][ordered]@{gateStatus='Failed';familyRegistry=$null;familyMemberLedger=$null;crossLaneReferencePackage=$null;summary=$summary;report=$report;texts=[pscustomobject][ordered]@{familyRegistry=$null;familyMemberLedger=$null;crossLaneReferencePackage=$null;summary=ConvertTo-C3CanonicalJson $summary}}
    }

    $referenceRows=[Collections.Generic.List[object]]::new()
    foreach($reference in @($kernel.crossLaneReferences)){
        $base=[pscustomobject][ordered]@{fromAssetObjectId=$reference.fromAssetObjectId;toAssetObjectId=$reference.toAssetObjectId;fromLane=$reference.fromLane;toLane=$reference.toLane;referenceKind=$reference.referenceKind}
        $referenceRows.Add([pscustomobject][ordered]@{referenceId=Get-C3ReferenceId $base;fromAssetObjectId=$base.fromAssetObjectId;toAssetObjectId=$base.toAssetObjectId;fromLane=$base.fromLane;toLane=$base.toLane;referenceKind=$base.referenceKind;resolutionStatus=$reference.resolutionStatus;evidence=@($reference.evidence)})
    }
    $referenceRows.Sort([Comparison[object]]{param($a,$b)$script:C3Ordinal.Compare([string]$a.referenceId,[string]$b.referenceId)})
    $referenceIdsByObject=@{};foreach($reference in $referenceRows){foreach($id in @($reference.fromAssetObjectId,$reference.toAssetObjectId)){if(-not$referenceIdsByObject.ContainsKey($id)){$referenceIdsByObject[$id]=[Collections.Generic.List[string]]::new()};$referenceIdsByObject[$id].Add($reference.referenceId)}}

    $memberRows=[Collections.Generic.List[object]]::new()
    foreach($member in @($kernel.memberRows)){
        $dispatch=@($DispatchRows|Where-Object assetObjectId -CEQ $member.assetObjectId)[0];$ledger=if($ledgerById.ContainsKey($member.assetObjectId)){$ledgerById[$member.assetObjectId]}else{$null};$policy=if($member.parentStatus-ceq'AssignedFamilyMember'){@($LanePolicyRegistry.policies|Where-Object lane -CEQ $dispatch.familyLane)[0]}else{$null};$deps=@(if($null-ne$ledger){$ledger.dependencyObjectIds});if($deps.Count-gt1){[Array]::Sort($deps,$script:C3Ordinal)};$refs=@(if($referenceIdsByObject.ContainsKey($member.assetObjectId)){$referenceIdsByObject[$member.assetObjectId]});if($refs.Count-gt1){[Array]::Sort($refs,$script:C3Ordinal)}
        $row=[pscustomobject][ordered]@{assetObjectId=$member.assetObjectId;parentStatus=$member.parentStatus;familyId=$member.familyId;configurationCandidateId=$member.configurationCandidateId}
        $memberRows.Add([pscustomobject][ordered]@{memberRecordId=Get-C3MemberRecordId $row;assetObjectId=$member.assetObjectId;canonicalAssetId=$dispatch.canonicalAssetId;lane=$dispatch.familyLane;parentStatus=$member.parentStatus;familyId=$member.familyId;familyKindId=$member.familyKindId;serializedSizeBytes=if($null-ne$ledger){[long]$ledger.serializedSizeBytes}else{0};configurationCandidateId=$member.configurationCandidateId;dependencyObjectIds=$deps;crossLaneReferenceIds=$refs;policyId=if($null-ne$policy){$policy.policyId}else{$null};policyVersion=if($null-ne$policy){$policy.policyVersion}else{$null};evidence=@($dispatch.evidence)})
    }
    $memberRows.Sort([Comparison[object]]{param($a,$b)$script:C3Ordinal.Compare([string]$a.assetObjectId,[string]$b.assetObjectId)})

    $familyRows=[Collections.Generic.List[object]]::new()
    foreach($family in @($kernel.families)){
        $policy=@($LanePolicyRegistry.policies|Where-Object lane -CEQ $family.lane)[0];$members=@($memberRows|Where-Object familyId -CEQ $family.familyId);$first=$members[0];$keyRows=[Collections.Generic.List[object]]::new()
        foreach($dimension in @($policy.familyKinds[0].keyDimensionIds)){$fact=@($TypedFactRows|Where-Object{$_.assetObjectId-ceq$first.assetObjectId-and$_.factKind-ceq$dimension})[0];$keyRows.Add([pscustomobject][ordered]@{dimensionId=$dimension;factStatus=$fact.factStatus;valueKind=$fact.valueKind;stringValue=$fact.stringValue;integerValue=$fact.integerValue;booleanValue=$fact.booleanValue;idValues=@($fact.idValues)})}
        $refs=[string[]]@(Get-C3OrdinalValues @($members|ForEach-Object crossLaneReferenceIds|ForEach-Object{$_}) -Unique);$evidence=[string[]]@(Get-C3OrdinalValues @($members|ForEach-Object evidence|ForEach-Object{$_}) -Unique)
        $familyRows.Add([pscustomobject][ordered]@{familyId=$family.familyId;lane=$family.lane;familyKindId=$family.familyKindId;policyId=$policy.policyId;policyVersion=$policy.policyVersion;familyKeyFingerprint=$family.familyKeyFingerprint;familyKey=$keyRows.ToArray();memberCount=$members.Count;memberBytes=($members.serializedSizeBytes|Measure-Object -Sum).Sum;memberObjectIds=@($members.assetObjectId);crossLaneReferenceIds=$refs;riskDimensionIds=@($policy.riskAxisDefinitions.riskAxisId);evidence=$evidence})
    }
    $familyRows.Sort([Comparison[object]]{param($a,$b)$script:C3Ordinal.Compare([string]$a.familyId,[string]$b.familyId)})

    $familyRegistry=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;families=$familyRows.ToArray()}
    $familyMemberLedger=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;rows=$memberRows.ToArray()}
    $crossLaneReferencePackage=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;rows=$referenceRows.ToArray()}
    $texts=[ordered]@{familyRegistry=ConvertTo-C3CanonicalJson $familyRegistry;familyMemberLedger=ConvertTo-C3CanonicalJson $familyMemberLedger;crossLaneReferencePackage=ConvertTo-C3CanonicalJson $crossLaneReferencePackage}
    foreach($member in $memberRows){$bytes=[long]$member.serializedSizeBytes;switch($member.parentStatus){'AssignedFamilyMember'{$coverage.assignedFamilyMemberCount++;$coverage.assignedFamilyMemberBytes+=$bytes};'RetainedForDiagnosis'{$coverage.retainedForDiagnosisObjectCount++;$coverage.retainedForDiagnosisObjectBytes+=$bytes};'ConfigurationOnly'{$coverage.configurationOnlyObjectCount++;$coverage.configurationOnlyObjectBytes+=$bytes}}};$coverage.familyCount=$familyRows.Count;$coverage.referenceCount=$referenceRows.Count;$coverage.resolvedReferenceCount=@($referenceRows|Where-Object resolutionStatus -CEQ Resolved).Count;$coverage.missingReferenceCount=@($referenceRows|Where-Object resolutionStatus -CEQ Missing).Count;$coverage.conflictReferenceCount=@($referenceRows|Where-Object resolutionStatus -CEQ Conflict).Count
    $accounting=[pscustomobject][ordered]@{inputSubjectCount=$directInputs.Count+$DispatchRows.Count+$referenceRows.Count+4;acceptedInputSubjectCount=$directInputs.Count+$DispatchRows.Count+$referenceRows.Count+4;inputFailureCount=0;notEvaluatedInputSubjectCount=0;outputCandidateCount=4;projectedOutputCount=4;outputFailureCount=0;issueCount=0;gateStatus='Passed';inputFailures=@();inputSuppressions=@();outputFailures=@()}
    $decision=[pscustomobject][ordered]@{failureAttribution='None; C3 lifecycle contract passed.';nextAllowedAction='Provide the current family generation to C4.'}
    $report=New-C3Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
    $directOutputs=@(Get-C3OrdinalRows @([pscustomobject][ordered]@{artifactId='C3-O01';path=$paths.familyRegistry;sha256=Get-C3Sha256 $texts.familyRegistry},[pscustomobject][ordered]@{artifactId='C3-O02';path=$paths.familyMemberLedger;sha256=Get-C3Sha256 $texts.familyMemberLedger},[pscustomobject][ordered]@{artifactId='C3-O03';path=$paths.crossLaneReferencePackage;sha256=Get-C3Sha256 $texts.crossLaneReferencePackage},[pscustomobject][ordered]@{artifactId='C3-O04-Report';path=$paths.report;sha256=Get-C3Sha256 $report}) @('path'))
    $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C3';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=[pscustomobject]$coverage;failureAccounting=$accounting;decision=$decision};$texts.summary=ConvertTo-C3CanonicalJson $summary
    [pscustomobject][ordered]@{gateStatus='Passed';familyRegistry=$familyRegistry;familyMemberLedger=$familyMemberLedger;crossLaneReferencePackage=$crossLaneReferencePackage;summary=$summary;report=$report;texts=[pscustomobject]$texts}
}

Export-ModuleMember -Function Invoke-C3FamilyMembershipKernel,Invoke-C3FamilyMembershipGate
