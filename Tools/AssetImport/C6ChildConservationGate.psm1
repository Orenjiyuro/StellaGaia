Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:C6Ordinal = [StringComparer]::Ordinal

function Get-C6Rows([object]$Artifact, [string]$Property) {
    if ($null -eq $Artifact -or $null -eq $Artifact.PSObject.Properties[$Property]) {
        return $null
    }
    @($Artifact.$Property)
}

function Get-C6OrdinalValues([object[]]$Values) {
    $result = [Collections.Generic.List[string]]::new()
    foreach ($value in $Values) {
        $result.Add([string]$value)
    }
    $result.Sort($script:C6Ordinal)
    [string[]]$result.ToArray()
}

function Test-C6UniqueNonemptyIds([object[]]$Values) {
    $seen = [Collections.Generic.HashSet[string]]::new($script:C6Ordinal)
    foreach ($value in $Values) {
        $id = [string]$value
        if ([string]::IsNullOrWhiteSpace($id) -or -not $seen.Add($id)) {
            return $false
        }
    }
    $true
}

function Test-C6ExactSet([object[]]$Actual, [object[]]$Expected) {
    if (-not (Test-C6UniqueNonemptyIds $Actual) -or -not (Test-C6UniqueNonemptyIds $Expected) -or $Actual.Count -ne $Expected.Count) {
        return $false
    }
    $actualOrdered = @(Get-C6OrdinalValues $Actual)
    $expectedOrdered = @(Get-C6OrdinalValues $Expected)
    for ($index = 0; $index -lt $actualOrdered.Count; $index++) {
        if ($actualOrdered[$index] -cne $expectedOrdered[$index]) {
            return $false
        }
    }
    $true
}

function New-C6Map([object[]]$Rows, [string]$Property) {
    $map = [Collections.Generic.Dictionary[string, object]]::new($script:C6Ordinal)
    foreach ($row in $Rows) {
        if ($null -eq $row -or $null -eq $row.PSObject.Properties[$Property]) {
            return $null
        }
        $id = [string]$row.$Property
        if ([string]::IsNullOrWhiteSpace($id) -or $map.ContainsKey($id)) {
            return $null
        }
        $map.Add($id, $row)
    }
    $map
}

function Get-C6ByteSum([object[]]$Rows) {
    [int64]$sum = 0
    foreach ($row in $Rows) {
        $sum += [int64]$row.serializedSizeBytes
    }
    $sum
}

function Test-C6IdentityPrefix([object[]]$Artifacts) {
    $snapshotId = $null
    $policySetFingerprint = $null
    foreach ($artifact in $Artifacts) {
        if ($null -eq $artifact -or
            $null -eq $artifact.PSObject.Properties['snapshotId'] -or
            $null -eq $artifact.PSObject.Properties['policySetFingerprint']) {
            return $false
        }
        if ($null -eq $snapshotId) {
            $snapshotId = [string]$artifact.snapshotId
            $policySetFingerprint = [string]$artifact.policySetFingerprint
        }
        elseif ([string]$artifact.snapshotId -cne $snapshotId -or [string]$artifact.policySetFingerprint -cne $policySetFingerprint) {
            return $false
        }
    }
    -not [string]::IsNullOrWhiteSpace($snapshotId) -and $policySetFingerprint -cmatch '^[0-9a-f]{64}$'
}

function New-C6ChildResult(
    [string]$GateStatus,
    [AllowNull()][string]$FailureId,
    [AllowNull()][string]$SubjectKind,
    [AllowNull()][string]$SubjectId,
    [AllowNull()][string]$ReasonCode,
    [int]$FamilyCount,
    [int]$AssignedMemberCount,
    [int]$RiskRequirementCount,
    [int]$SuitabilityRequirementCount,
    [string[]]$FamilyIds,
    [string[]]$AssignedMemberIds,
    [string[]]$RiskRequirementIds,
    [string[]]$SuitabilityRequirementIds
) {
    [pscustomobject][ordered]@{
        gateStatus = $GateStatus
        failureId = $FailureId
        subjectKind = $SubjectKind
        subjectId = $SubjectId
        reasonCode = $ReasonCode
        attribution = if ($null -ne $FailureId) { "${FailureId}:$SubjectId" } else { $null }
        familyCount = $FamilyCount
        assignedMemberCount = $AssignedMemberCount
        riskRequirementCount = $RiskRequirementCount
        suitabilityRequirementCount = $SuitabilityRequirementCount
        validatedFamilyIds = $FamilyIds
        validatedAssignedMemberIds = $AssignedMemberIds
        validatedRiskRequirementIds = $RiskRequirementIds
        validatedSuitabilityRequirementIds = $SuitabilityRequirementIds
        executorLaunchCount = 0
        heavyOperationCount = 0
    }
}

function Test-C6ChildRowConservation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object]$MemberStaticQualification,
        [Parameter(Mandatory)][object]$FamilyStaticSummary,
        [Parameter(Mandatory)][object]$RepresentativeRequirements,
        [Parameter(Mandatory)][object]$EvidenceAssessment
    )

    $families = Get-C6Rows $FamilyRegistry 'families'
    $memberRows = Get-C6Rows $FamilyMemberLedger 'rows'
    $staticMembers = Get-C6Rows $MemberStaticQualification 'memberResults'
    $staticFamilies = Get-C6Rows $FamilyStaticSummary 'families'
    $riskRequirements = Get-C6Rows $RepresentativeRequirements 'requirements'
    $suitabilityRequirements = Get-C6Rows $RepresentativeRequirements 'capabilitySuitabilityRequirements'
    $riskAssessments = Get-C6Rows $EvidenceAssessment 'assessments'
    $suitabilityAssessments = Get-C6Rows $EvidenceAssessment 'capabilitySuitabilityAssessments'

    $familyCount = if ($null -ne $families) { $families.Count } else { 0 }
    $assignedMembers = if ($null -ne $memberRows) { @($memberRows | Where-Object parentStatus -CEQ 'AssignedFamilyMember') } else { @() }
    $assignedMemberCount = $assignedMembers.Count
    $riskRequirementCount = if ($null -ne $riskRequirements) { $riskRequirements.Count } else { 0 }
    $suitabilityRequirementCount = if ($null -ne $suitabilityRequirements) { $suitabilityRequirements.Count } else { 0 }

    function Fail-C6Child([string]$FailureId, [string]$SubjectKind, [string]$SubjectId) {
        $reasonCode = if ($FailureId -ceq 'LF-18') { 'CapabilityProjectionInvalid' } else { 'ConservationMismatch' }
        New-C6ChildResult 'Failed' $FailureId $SubjectKind $SubjectId $reasonCode `
            $familyCount $assignedMemberCount $riskRequirementCount $suitabilityRequirementCount @() @() @() @()
    }

    if ($null -eq $families -or $null -eq $memberRows -or $null -eq $staticMembers -or $null -eq $staticFamilies -or
        $null -eq $riskRequirements -or $null -eq $suitabilityRequirements -or $null -eq $riskAssessments -or $null -eq $suitabilityAssessments -or
        -not (Test-C6IdentityPrefix @($FamilyRegistry, $FamilyMemberLedger, $MemberStaticQualification, $FamilyStaticSummary, $RepresentativeRequirements, $EvidenceAssessment)) -or
        $null -eq $RepresentativeRequirements.PSObject.Properties['decisionPolicyFingerprint'] -or
        $null -eq $EvidenceAssessment.PSObject.Properties['decisionPolicyFingerprint'] -or
        [string]$RepresentativeRequirements.decisionPolicyFingerprint -cne [string]$EvidenceAssessment.decisionPolicyFingerprint) {
        return Fail-C6Child 'LF-16' 'FreshnessCheck' 'C6:ChildGenerationIdentity'
    }

    $familyById = New-C6Map $families 'familyId'
    $staticFamilyById = New-C6Map $staticFamilies 'familyId'
    if ($null -eq $familyById -or $null -eq $staticFamilyById -or
        -not (Test-C6ExactSet @($families.familyId) @($staticFamilies.familyId))) {
        return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:FamilyUniverse'
    }

    $memberById = New-C6Map $memberRows 'assetObjectId'
    $memberRecordById = New-C6Map $memberRows 'memberRecordId'
    $assignedById = New-C6Map $assignedMembers 'assetObjectId'
    $staticMemberById = New-C6Map $staticMembers 'assetObjectId'
    $staticResultById = New-C6Map $staticMembers 'staticResultId'
    if ($null -eq $memberById -or $null -eq $memberRecordById -or $null -eq $assignedById -or
        $null -eq $staticMemberById -or $null -eq $staticResultById -or
        -not (Test-C6ExactSet @($assignedMembers.assetObjectId) @($staticMembers.assetObjectId))) {
        return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:MemberUniverse'
    }

    foreach ($family in $families) {
        $familyId = [string]$family.familyId
        $familyMembers = @($assignedMembers | Where-Object familyId -CEQ $familyId)
        $familyStaticMembers = @($staticMembers | Where-Object familyId -CEQ $familyId)
        $staticFamily = $staticFamilyById[$familyId]
        if (-not (Test-C6ExactSet @($family.memberObjectIds) @($familyMembers.assetObjectId)) -or
            [int64]$family.memberCount -ne $familyMembers.Count -or
            [int64]$family.memberBytes -ne (Get-C6ByteSum $familyMembers) -or
            $familyMembers.Count -ne $familyStaticMembers.Count -or
            [string]$staticFamily.lane -cne [string]$family.lane -or
            [int64]$staticFamily.memberCount -ne $familyMembers.Count -or
            [int64]$staticFamily.memberBytes -ne [int64]$family.memberBytes -or
            -not (Test-C6ExactSet @($staticFamily.memberStaticResultIds) @($familyStaticMembers.staticResultId))) {
            return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:MemberUniverse'
        }

        $passed = @($familyStaticMembers | Where-Object staticStatus -CEQ 'StaticPassed')
        $failed = @($familyStaticMembers | Where-Object staticStatus -CEQ 'StaticFailed')
        $unchecked = @($familyStaticMembers | Where-Object staticStatus -CEQ 'Unchecked')
        $passedBytes = Get-C6ByteSum @($familyMembers | Where-Object { $staticMemberById[[string]$_.assetObjectId].staticStatus -ceq 'StaticPassed' })
        $failedBytes = Get-C6ByteSum @($familyMembers | Where-Object { $staticMemberById[[string]$_.assetObjectId].staticStatus -ceq 'StaticFailed' })
        $uncheckedBytes = Get-C6ByteSum @($familyMembers | Where-Object { $staticMemberById[[string]$_.assetObjectId].staticStatus -ceq 'Unchecked' })
        if ($familyMembers.Count -ne ($passed.Count + $failed.Count + $unchecked.Count) -or
            [int64]$staticFamily.staticPassedCount -ne $passed.Count -or
            [int64]$staticFamily.staticFailedCount -ne $failed.Count -or
            [int64]$staticFamily.uncheckedCount -ne $unchecked.Count -or
            [int64]$staticFamily.staticPassedBytes -ne $passedBytes -or
            [int64]$staticFamily.staticFailedBytes -ne $failedBytes -or
            [int64]$staticFamily.uncheckedBytes -ne $uncheckedBytes) {
            return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:MemberUniverse'
        }

        foreach ($member in $familyMembers) {
            $staticMember = $staticMemberById[[string]$member.assetObjectId]
            if ([string]$member.familyId -cne $familyId -or [string]$member.lane -cne [string]$family.lane -or
                [string]$member.familyKindId -cne [string]$family.familyKindId -or
                [string]$staticMember.familyId -cne $familyId -or [string]$staticMember.lane -cne [string]$family.lane) {
                return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:MemberUniverse'
            }
        }
    }

    $riskRequirementById = New-C6Map $riskRequirements 'requirementId'
    $riskAssessmentById = New-C6Map $riskAssessments 'assessmentId'
    $riskAssessmentByRequirement = New-C6Map $riskAssessments 'requirementId'
    if ($null -eq $riskRequirementById -or $null -eq $riskAssessmentById -or $null -eq $riskAssessmentByRequirement -or
        -not (Test-C6ExactSet @($riskRequirements.requirementId) @($riskAssessments.requirementId))) {
        return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
    }
    foreach ($requirement in $riskRequirements) {
        $requirementId = [string]$requirement.requirementId
        if (-not $familyById.ContainsKey([string]$requirement.familyId)) {
            return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
        }
        $candidates = @($requirement.candidateMemberIds)
        if (($candidates.Count -gt 0 -and -not (Test-C6UniqueNonemptyIds $candidates)) -or
            ($candidates.Count -eq 0 -and $null -ne $requirement.selectedRepresentativeAssetObjectId) -or
            ($candidates.Count -gt 0 -and [string]$requirement.selectedRepresentativeAssetObjectId -cne @(Get-C6OrdinalValues $candidates)[0])) {
            return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
        }
        foreach ($candidateId in $candidates) {
            if (-not $staticMemberById.ContainsKey([string]$candidateId)) {
                return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
            }
            $candidate = $staticMemberById[[string]$candidateId]
            if ([string]$candidate.familyId -cne [string]$requirement.familyId -or [string]$candidate.staticStatus -cne 'StaticPassed') {
                return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
            }
        }
        $assessment = $riskAssessmentByRequirement[$requirementId]
        if ([string]$assessment.familyId -cne [string]$requirement.familyId -or
            [string]$assessment.representativeAssetObjectId -cne [string]$requirement.selectedRepresentativeAssetObjectId -or
            [string]$assessment.assessmentStatus -cne [string]$requirement.assessmentStatus -or
            [string]$assessment.expectedInputFingerprint -cne [string]$requirement.expectedInputFingerprint) {
            return Fail-C6Child 'LF-16' 'ConservationCheck' 'C6:RiskAssessmentUniverse'
        }
    }

    $suitabilityRequirementById = New-C6Map $suitabilityRequirements 'suitabilityRequirementId'
    $suitabilityAssessmentById = New-C6Map $suitabilityAssessments 'suitabilityAssessmentId'
    $suitabilityAssessmentByRequirement = New-C6Map $suitabilityAssessments 'suitabilityRequirementId'
    if ($null -eq $suitabilityRequirementById -or $null -eq $suitabilityAssessmentById -or $null -eq $suitabilityAssessmentByRequirement -or
        -not (Test-C6ExactSet @($suitabilityRequirements.suitabilityRequirementId) @($suitabilityAssessments.suitabilityRequirementId))) {
        return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
    }
    foreach ($requirement in $suitabilityRequirements) {
        $requirementId = [string]$requirement.suitabilityRequirementId
        if (-not $familyById.ContainsKey([string]$requirement.familyId)) {
            return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
        }
        $candidates = @($requirement.candidateMemberIds)
        if (($candidates.Count -gt 0 -and -not (Test-C6UniqueNonemptyIds $candidates)) -or
            ($candidates.Count -eq 0 -and $null -ne $requirement.selectedRepresentativeAssetObjectId) -or
            ($candidates.Count -gt 0 -and [string]$requirement.selectedRepresentativeAssetObjectId -cne @(Get-C6OrdinalValues $candidates)[0])) {
            return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
        }
        foreach ($candidateId in $candidates) {
            if (-not $staticMemberById.ContainsKey([string]$candidateId)) {
                return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
            }
            $candidate = $staticMemberById[[string]$candidateId]
            if ([string]$candidate.familyId -cne [string]$requirement.familyId -or [string]$candidate.staticStatus -cne 'StaticPassed') {
                return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
            }
        }
        $assessment = $suitabilityAssessmentByRequirement[$requirementId]
        if ([string]$assessment.familyId -cne [string]$requirement.familyId -or
            [string]$assessment.capabilityId -cne [string]$requirement.capabilityId -or
            [string]$assessment.routeKind -cne [string]$requirement.routeKind -or
            [string]$assessment.representativeAssetObjectId -cne [string]$requirement.selectedRepresentativeAssetObjectId -or
            [string]$assessment.assessmentStatus -cne [string]$requirement.assessmentStatus -or
            [string]$assessment.expectedInputFingerprint -cne [string]$requirement.expectedInputFingerprint) {
            return Fail-C6Child 'LF-18' 'ConservationCheck' 'C6:SuitabilityAssessmentUniverse'
        }
    }

    New-C6ChildResult 'Passed' $null $null $null $null `
        $familyCount $assignedMemberCount $riskRequirementCount $suitabilityRequirementCount `
        @(Get-C6OrdinalValues @($families.familyId)) `
        @(Get-C6OrdinalValues @($assignedMembers.assetObjectId)) `
        @(Get-C6OrdinalValues @($riskRequirements.requirementId)) `
        @(Get-C6OrdinalValues @($suitabilityRequirements.suitabilityRequirementId))
}

Export-ModuleMember -Function Test-C6ChildRowConservation
