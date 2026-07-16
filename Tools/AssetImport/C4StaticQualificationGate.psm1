Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-C4Sha256([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

function Add-C4Issue([Collections.Generic.List[string]]$Issues, [string]$Issue) {
    if (-not $Issues.Contains($Issue)) { $Issues.Add($Issue) }
}

function Test-C4ExactSet([object[]]$Actual, [string[]]$Expected) {
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne $Expected[$index]) { return $false }
    }
    return $true
}

function Invoke-C4StaticQualificationKernel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object[]]$TypedFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string[]]$MemberStaticStatuses,
        [Parameter(Mandatory)][object[]]$StaticObservationRows
    )

    $issues = [Collections.Generic.List[string]]::new()
    $expectedStatuses = @('StaticPassed', 'StaticFailed', 'Unchecked')
    if (-not (Test-C4ExactSet $MemberStaticStatuses $expectedStatuses)) {
        Add-C4Issue $issues 'LC-I08 memberStaticStatus vocabulary is invalid.'
    }

    $familyById = @{}
    foreach ($family in @($FamilyRegistry.families)) {
        $familyId = [string]$family.familyId
        if ($familyById.ContainsKey($familyId)) {
            Add-C4Issue $issues 'Duplicate C3 familyId.'
        }
        else { $familyById[$familyId] = $family }
    }

    $policyByLane = @{}
    foreach ($lanePolicy in @($LanePolicyRegistry.policies)) {
        $lane = [string]$lanePolicy.lane
        if ($policyByLane.ContainsKey($lane)) {
            Add-C4Issue $issues 'Duplicate LC-I07 lane policy.'
        }
        else { $policyByLane[$lane] = $lanePolicy }
    }

    $assignedMembers = @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember' | Sort-Object assetObjectId -CaseSensitive)
    $memberIds = @{}
    foreach ($member in $assignedMembers) {
        $assetObjectId = [string]$member.assetObjectId
        if ($memberIds.ContainsKey($assetObjectId)) {
            Add-C4Issue $issues 'Duplicate C3 assigned member.'
            continue
        }
        $memberIds[$assetObjectId] = $member
        $familyId = [string]$member.familyId
        if (-not $familyById.ContainsKey($familyId)) {
            Add-C4Issue $issues 'C3 assigned member family does not resolve.'
            continue
        }
        $family = $familyById[$familyId]
        if ([string]$family.lane -cne [string]$member.lane -or [string]$family.familyKindId -cne [string]$member.familyKindId) {
            Add-C4Issue $issues 'C3 member and family identity mismatch.'
        }
        if (-not $policyByLane.ContainsKey([string]$member.lane)) {
            Add-C4Issue $issues 'C3 assigned member lane policy does not resolve.'
        }
    }

    foreach ($family in @($FamilyRegistry.families)) {
        $actual = @($assignedMembers | Where-Object familyId -CEQ ([string]$family.familyId))
        $expectedIds = @($family.memberObjectIds | Sort-Object -CaseSensitive)
        $actualIds = @($actual.assetObjectId | Sort-Object -CaseSensitive)
        if ([int]$family.memberCount -ne $actual.Count -or -not (Test-C4ExactSet $actualIds $expectedIds)) {
            Add-C4Issue $issues 'C3 family membership input is inconsistent.'
        }
    }

    $factsByKey = @{}
    foreach ($fact in $TypedFactRows) {
        $key = "$([string]$fact.assetObjectId)|$([string]$fact.factKind)"
        if ($factsByKey.ContainsKey($key)) { Add-C4Issue $issues 'Duplicate typed fact row.' }
        else { $factsByKey[$key] = $fact }
    }

    $observationByKey = @{}
    foreach ($observation in $StaticObservationRows) {
        if ((@($observation.PSObject.Properties.Name) -join ',') -cne 'assetObjectId,familyId,checkId,outcome,reasonCode,observedFingerprint,evidenceKinds,evidence') {
            Add-C4Issue $issues 'Invalid static observation row shape.'
            continue
        }
        $key = "$([string]$observation.assetObjectId)|$([string]$observation.checkId)"
        if ($observationByKey.ContainsKey($key)) { Add-C4Issue $issues 'Duplicate static observation row.' }
        else { $observationByKey[$key] = $observation }
    }

    $requiredByKey = @{}
    $requiredRows = [Collections.Generic.List[object]]::new()
    foreach ($member in $assignedMembers) {
        if (-not $policyByLane.ContainsKey([string]$member.lane)) { continue }
        $lanePolicy = $policyByLane[[string]$member.lane]
        $familyKindId = [string]$member.familyKindId
        $factDefinitionByKind = @{}
        foreach ($definition in @($lanePolicy.factDefinitions)) { $factDefinitionByKind[[string]$definition.factKind] = $definition }
        foreach ($check in @($lanePolicy.staticCheckDefinitions)) {
            if (@($check.applicableFamilyKinds) -cnotcontains $familyKindId) { continue }
            $inapplicable = $false
            $missingInput = $false
            foreach ($factKindValue in @($check.requiredFactKinds)) {
                $factKind = [string]$factKindValue
                $factKey = "$([string]$member.assetObjectId)|$factKind"
                if (-not $factsByKey.ContainsKey($factKey)) { $missingInput = $true; continue }
                $fact = $factsByKey[$factKey]
                if ([string]$fact.factStatus -ceq 'Unknown') { $missingInput = $true; continue }
                if ([string]$fact.factStatus -ceq 'NotApplicable') {
                    if (-not $factDefinitionByKind.ContainsKey($factKind) -or -not [bool]$factDefinitionByKind[$factKind].allowNotApplicable) {
                        Add-C4Issue $issues 'Forbidden NotApplicable static fact.'
                    }
                    else { $inapplicable = $true }
                }
                elseif ([string]$fact.factStatus -cne 'Known') {
                    Add-C4Issue $issues 'Invalid static fact status.'
                }
            }
            if ($inapplicable) { continue }
            $key = "$([string]$member.assetObjectId)|$([string]$check.checkId)"
            $requiredByKey[$key] = $true
            $requiredRows.Add([pscustomobject][ordered]@{ member = $member; check = $check; missingInput = $missingInput; key = $key })
        }
    }

    foreach ($key in $observationByKey.Keys) {
        if (-not $requiredByKey.ContainsKey($key)) { Add-C4Issue $issues 'Unexpected static observation row.' }
    }

    $allowedOutcomes = @('Passed', 'Failed', 'Unchecked')
    $allowedReasons = @('None', 'MissingInputFact', 'PrerequisiteFailed', 'ToolUnavailable', 'UnsupportedFormat', 'ReadFailure', 'DependencyMissing', 'ConflictDetected', 'PolicyViolation')
    $checkResults = [Collections.Generic.List[object]]::new()
    foreach ($required in $requiredRows) {
        if (-not $observationByKey.ContainsKey([string]$required.key)) {
            Add-C4Issue $issues 'Missing required static observation row.'
            continue
        }
        $observation = $observationByKey[[string]$required.key]
        $member = $required.member
        $check = $required.check
        $outcome = [string]$observation.outcome
        $reasonCode = [string]$observation.reasonCode
        if ([string]$observation.familyId -cne [string]$member.familyId) { Add-C4Issue $issues 'Static observation family does not match C3 membership.' }
        if ($allowedOutcomes -cnotcontains $outcome) { Add-C4Issue $issues 'Invalid static observation outcome.' }
        if ($allowedReasons -cnotcontains $reasonCode) { Add-C4Issue $issues 'Invalid static observation reasonCode.' }
        if ($outcome -ceq 'Passed' -and $reasonCode -cne 'None') { Add-C4Issue $issues 'Passed static observation must use reasonCode None.' }
        if (($outcome -ceq 'Failed' -or $outcome -ceq 'Unchecked') -and $reasonCode -ceq 'None') { Add-C4Issue $issues 'Non-passing static observation cannot use reasonCode None.' }
        if ([bool]$required.missingInput -and ($outcome -cne 'Unchecked' -or $reasonCode -cne 'MissingInputFact')) { Add-C4Issue $issues 'Missing static fact must produce Unchecked with MissingInputFact.' }
        $fingerprint = $observation.observedFingerprint
        if ($null -ne $fingerprint -and [string]$fingerprint -cnotmatch '^sha256:[0-9a-f]{64}$') { Add-C4Issue $issues 'Invalid observedFingerprint.' }
        if ($outcome -ceq 'Passed' -and $null -eq $fingerprint) { Add-C4Issue $issues 'Passed static observation requires observedFingerprint.' }
        $rawEvidenceKinds = @($observation.evidenceKinds)
        $evidenceKinds = @($rawEvidenceKinds | Sort-Object -CaseSensitive -Unique)
        if (-not (Test-C4ExactSet $rawEvidenceKinds $evidenceKinds)) { Add-C4Issue $issues 'Static observation evidenceKinds must be an Ordinal set.' }
        if ($outcome -ceq 'Passed') {
            $missingEvidenceKinds = @($check.requiredEvidenceKinds | Where-Object { $_ -cnotin $evidenceKinds })
            if ($missingEvidenceKinds.Count) { Add-C4Issue $issues 'Passed static observation is missing required evidence kinds.' }
        }
        if (@($observation.evidence).Count -eq 0) { Add-C4Issue $issues 'Static observation evidence is empty.' }
        $identity = "$([string]$member.assetObjectId)`n$([string]$member.familyId)`n$([string]$check.checkId)`n$outcome`n$reasonCode"
        $checkResults.Add([pscustomobject][ordered]@{
            staticCheckResultId = "static-check-sha256:$(Get-C4Sha256 $identity)"
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            lane = [string]$member.lane
            checkId = [string]$check.checkId
            outcome = $outcome
            reasonCode = $reasonCode
            observedFingerprint = $fingerprint
            evidence = @($observation.evidence | Sort-Object -CaseSensitive)
        })
    }

    if ($issues.Count) {
        return [pscustomobject][ordered]@{
            status = 'Failed'; issues = @($issues | Sort-Object -CaseSensitive)
            assignedMemberCount = $assignedMembers.Count; assignedMemberBytes = [long]0
            staticPassedCount = 0; staticPassedBytes = [long]0; staticFailedCount = 0; staticFailedBytes = [long]0; uncheckedCount = 0; uncheckedBytes = [long]0
            requiredCheckCount = $requiredRows.Count; passedCheckCount = 0; failedCheckCount = 0; uncheckedCheckCount = 0
            memberResults = @(); familyResults = @(); checkResults = @()
        }
    }

    $orderedChecks = @($checkResults | Sort-Object assetObjectId, checkId -CaseSensitive)
    $memberResults = [Collections.Generic.List[object]]::new()
    foreach ($member in $assignedMembers) {
        $checks = @($orderedChecks | Where-Object assetObjectId -CEQ ([string]$member.assetObjectId))
        $passed = @($checks | Where-Object outcome -CEQ 'Passed').Count
        $failed = @($checks | Where-Object outcome -CEQ 'Failed').Count
        $unchecked = @($checks | Where-Object outcome -CEQ 'Unchecked').Count
        $staticStatus = if ($failed) { 'StaticFailed' } elseif ($unchecked) { 'Unchecked' } else { 'StaticPassed' }
        $identity = "$([string]$member.assetObjectId)`n$([string]$member.familyId)`n$staticStatus`n$(@($checks.staticCheckResultId) -join "`n")"
        $memberResults.Add([pscustomobject][ordered]@{
            memberStaticResultId = "member-static-sha256:$(Get-C4Sha256 $identity)"
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            lane = [string]$member.lane
            serializedSizeBytes = [long]$member.serializedSizeBytes
            staticStatus = $staticStatus
            requiredCheckCount = $checks.Count
            passedCheckCount = $passed
            failedCheckCount = $failed
            uncheckedCheckCount = $unchecked
            staticCheckResultIds = @($checks.staticCheckResultId)
        })
    }

    $familyResults = [Collections.Generic.List[object]]::new()
    foreach ($family in @($FamilyRegistry.families | Sort-Object familyId -CaseSensitive)) {
        $members = @($memberResults | Where-Object familyId -CEQ ([string]$family.familyId))
        $familyChecks = @($orderedChecks | Where-Object familyId -CEQ ([string]$family.familyId))
        $familyResults.Add([pscustomobject][ordered]@{
            familyId = [string]$family.familyId
            lane = [string]$family.lane
            memberCount = $members.Count
            memberBytes = [long](($members.serializedSizeBytes | Measure-Object -Sum).Sum)
            staticPassedCount = @($members | Where-Object staticStatus -CEQ 'StaticPassed').Count
            staticPassedBytes = [long](($members | Where-Object staticStatus -CEQ 'StaticPassed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            staticFailedCount = @($members | Where-Object staticStatus -CEQ 'StaticFailed').Count
            staticFailedBytes = [long](($members | Where-Object staticStatus -CEQ 'StaticFailed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            uncheckedCount = @($members | Where-Object staticStatus -CEQ 'Unchecked').Count
            uncheckedBytes = [long](($members | Where-Object staticStatus -CEQ 'Unchecked' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            requiredCheckCount = $familyChecks.Count
            passedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Passed').Count
            failedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Failed').Count
            uncheckedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Unchecked').Count
        })
    }

    $assignedBytes = [long](($memberResults.serializedSizeBytes | Measure-Object -Sum).Sum)
    [pscustomobject][ordered]@{
        status = 'Passed'; issues = @()
        assignedMemberCount = $memberResults.Count; assignedMemberBytes = $assignedBytes
        staticPassedCount = @($memberResults | Where-Object staticStatus -CEQ 'StaticPassed').Count
        staticPassedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'StaticPassed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        staticFailedCount = @($memberResults | Where-Object staticStatus -CEQ 'StaticFailed').Count
        staticFailedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'StaticFailed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        uncheckedCount = @($memberResults | Where-Object staticStatus -CEQ 'Unchecked').Count
        uncheckedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'Unchecked' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        requiredCheckCount = $orderedChecks.Count
        passedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Passed').Count
        failedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Failed').Count
        uncheckedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Unchecked').Count
        memberResults = @($memberResults)
        familyResults = @($familyResults)
        checkResults = $orderedChecks
    }
}

Export-ModuleMember -Function Invoke-C4StaticQualificationKernel
