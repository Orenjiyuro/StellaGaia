Set-StrictMode -Version Latest

$script:C3Utf8 = [Text.UTF8Encoding]::new($false)
$script:C3Ordinal = [StringComparer]::Ordinal

function Get-C3Sha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C3Utf8.GetBytes($Text))).ToLowerInvariant()
}

function ConvertTo-C3ScalarLine([string]$Name,[string]$Value) {
    if ($null -eq $Value -or $Value.IndexOfAny([char[]]@([char]0,"`r","`n")) -ge 0) { throw "Invalid framed scalar: $Name" }
    "${Name}:$($script:C3Utf8.GetByteCount($Value)):${Value}`n"
}

function ConvertTo-C3FactFrame([object]$Fact) {
    $text = 'C3FamilyKeyDimensionV1' + "`n"
    foreach ($name in @('factKind','factStatus','valueKind')) { $text += ConvertTo-C3ScalarLine $name ([string]$Fact.$name) }
    foreach ($name in @('stringValue','integerValue','booleanValue')) {
        $value = $Fact.$name
        $text += if ($null -eq $value) { "$name:null`n" } else { ConvertTo-C3ScalarLine $name ([string]$value).ToLowerInvariant() }
    }
    $values = [string[]]@($Fact.idValues); [Array]::Sort($values,$script:C3Ordinal)
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
        [Parameter(Mandatory)][string[]]$FamilyParentStatuses
    )

    $issues = [Collections.Generic.List[string]]::new()
    if (($FamilyParentStatuses -join ',') -cne 'AssignedFamilyMember,RetainedForDiagnosis,ConfigurationOnly') { $issues.Add('C3 family-parent vocabulary is invalid.') }
    if ((@($LanePolicyRegistry.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,policySetId,policySetVersion,policies' -or $LanePolicyRegistry.schemaVersion -cne '1.0.0') { $issues.Add('LC-I07 registry shape is invalid.') }
    $policyBytes = $script:C3Utf8.GetBytes((($LanePolicyRegistry | ConvertTo-Json -Depth 100) -replace "`r`n","`n") + "`n")
    $policySetFingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($policyBytes)).ToLowerInvariant()

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
    foreach ($dispatch in @($DispatchRows | Sort-Object assetObjectId -CaseSensitive)) {
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
    foreach ($family in @($familyMap.Values | Sort-Object familyId -CaseSensitive)) {
        $ids=[string[]]@($family.memberObjectIds);[Array]::Sort($ids,$script:C3Ordinal)
        $families.Add([pscustomobject][ordered]@{familyId=$family.familyId;lane=$family.lane;familyKindId=$family.familyKindId;familyKeyFingerprint=$family.familyKeyFingerprint;memberCount=$ids.Count;memberObjectIds=$ids})
    }
    $references=[Collections.Generic.List[object]]::new();$seenReferences=[Collections.Generic.HashSet[string]]::new($script:C3Ordinal)
    foreach ($from in @($memberRows | Where-Object parentStatus -CEQ AssignedFamilyMember)) {
        foreach ($fact in @(if($factsByObject.ContainsKey($from.assetObjectId)){$factsByObject[$from.assetObjectId]|Where-Object factKind -CEQ DependencyObjectIds}else{@()})) {
            foreach ($toId in @($fact.idValues)) {
                if (-not $dispatchById.ContainsKey([string]$toId)) { continue }
                $to = @($memberRows | Where-Object assetObjectId -CEQ $toId)[0]
                $fromDispatch=$dispatchById[$from.assetObjectId];$toDispatch=$dispatchById[[string]$toId]
                if ($to.parentStatus -ceq 'AssignedFamilyMember' -and $fromDispatch.familyLane -cne $toDispatch.familyLane) {
                    $key="$($from.assetObjectId)|$toId|Dependency";if($seenReferences.Add($key)){$references.Add([pscustomobject][ordered]@{fromAssetObjectId=$from.assetObjectId;toAssetObjectId=[string]$toId;fromLane=[string]$fromDispatch.familyLane;toLane=[string]$toDispatch.familyLane;referenceKind='Dependency'})}
                }
            }
        }
    }
    $references.Sort([Comparison[object]]{param($a,$b)$script:C3Ordinal.Compare("$($a.fromAssetObjectId)|$($a.toAssetObjectId)|$($a.referenceKind)","$($b.fromAssetObjectId)|$($b.toAssetObjectId)|$($b.referenceKind)")})
    $assigned=@($memberRows|Where-Object parentStatus -CEQ AssignedFamilyMember).Count;$retained=@($memberRows|Where-Object parentStatus -CEQ RetainedForDiagnosis).Count;$configuration=@($memberRows|Where-Object parentStatus -CEQ ConfigurationOnly).Count
    if ($DispatchRows.Count -ne $assigned+$retained+$configuration -or $assigned -ne (($families.memberCount|Measure-Object -Sum).Sum)) { $issues.Add('C3 family membership conservation failed.') }
    [pscustomobject][ordered]@{status=if($issues.Count){'Failed'}else{'Passed'};issues=$issues.ToArray();families=$families.ToArray();memberRows=$memberRows.ToArray();crossLaneReferences=$references.ToArray();dispatchEligibleObjectCount=$DispatchRows.Count;assignedFamilyMemberCount=$assigned;retainedForDiagnosisObjectCount=$retained;configurationOnlyObjectCount=$configuration}
}

Export-ModuleMember -Function Invoke-C3FamilyMembershipKernel
