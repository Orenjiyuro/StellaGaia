Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:C6OutputUtf8 = [Text.UTF8Encoding]::new($false)
$script:C6OutputOrdinal = [StringComparer]::Ordinal
$script:C6OutputPaths = [ordered]@{
    Ledger = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-authoring-reuse-ledger.json'
    Decisions = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-decision-package.json'
    Capabilities = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-capability-projection.json'
    Handoff = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json'
    Report = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c6-report.md'
}

function Get-C6OutputSha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C6OutputUtf8.GetBytes($Text))).ToLowerInvariant()
}
function ConvertTo-C6OutputJson([object]$Value) {
    (($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
}
function ConvertTo-C6OutputScalar([string]$Name, [string]$Value) {
    "${Name}:$($script:C6OutputUtf8.GetByteCount($Value)):${Value}`n"
}
function ConvertTo-C6OutputNullable([string]$Name, $Value) {
    if ($null -eq $Value) { return "${Name}:null`n" }
    ConvertTo-C6OutputScalar $Name ([string]$Value)
}
function Get-C6OutputOrdinalValues([object[]]$Values, [switch]$Unique) {
    $list = [Collections.Generic.List[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new($script:C6OutputOrdinal)
    foreach ($value in $Values) {
        $text = [string]$value
        if (-not $Unique -or $seen.Add($text)) { $list.Add($text) }
    }
    $list.Sort($script:C6OutputOrdinal)
    [string[]]$list.ToArray()
}
function Get-C6OutputOrdinalRows([object[]]$Rows, [string]$Property) {
    $list = [Collections.Generic.List[object]]::new()
    foreach ($row in $Rows) { $list.Add($row) }
    $list.Sort([Comparison[object]]{ param($left, $right) $script:C6OutputOrdinal.Compare([string]$left.$Property, [string]$right.$Property) })
    @($list.ToArray())
}
function Test-C6OutputExactSet([object[]]$Expected, [object[]]$Actual) {
    $expectedSet = @(Get-C6OutputOrdinalValues $Expected -Unique)
    $actualSet = @(Get-C6OutputOrdinalValues $Actual -Unique)
    if ($expectedSet.Count -ne $Expected.Count -or $actualSet.Count -ne $Actual.Count -or $expectedSet.Count -ne $actualSet.Count) {
        return $false
    }
    for ($index = 0; $index -lt $expectedSet.Count; $index++) {
        if ($expectedSet[$index] -cne $actualSet[$index]) { return $false }
    }
    $true
}
function Add-C6OutputSetFrame([string]$Name, [object[]]$Values) {
    $ordered = @(Get-C6OutputOrdinalValues $Values -Unique)
    $count = [string]$ordered.Count
    $text = "${Name}.count:$($script:C6OutputUtf8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $text += ConvertTo-C6OutputScalar "${Name}[$index]" $ordered[$index]
    }
    $text
}
function Get-C6OutputStageFingerprint([object[]]$Entries) {
    $ordered = @(Get-C6OutputOrdinalRows $Entries 'path')
    $count = [string]$ordered.Count
    $text = "LifecycleStageInputV1`nentries.count:$($script:C6OutputUtf8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $nested = "C2ArtifactEntryV1`n"
        $nested += ConvertTo-C6OutputScalar path ([string]$ordered[$index].path)
        $nested += ConvertTo-C6OutputScalar sha256 ([string]$ordered[$index].sha256)
        $text += "entries[$index]:$($script:C6OutputUtf8.GetByteCount($nested)):$nested`n"
    }
    Get-C6OutputSha256 $text
}
function Get-C6OutputDecisionId([object]$Decision, [string]$DecisionFingerprint, [string]$StaticFingerprint, [string]$EvidenceFingerprint, [string]$HistoryFingerprint) {
    $text = "C6FamilyDecisionV1`n"
    $text += ConvertTo-C6OutputScalar familyId ([string]$Decision.familyId)
    $text += ConvertTo-C6OutputScalar decisionPolicyFingerprint $DecisionFingerprint
    $text += ConvertTo-C6OutputScalar ruleId ([string]$Decision.ruleId)
    $text += ConvertTo-C6OutputScalar decision ([string]$Decision.decision)
    $text += ConvertTo-C6OutputNullable repairClass $Decision.repairClass
    $text += ConvertTo-C6OutputNullable replacementRouteKind $Decision.replacementRouteKind
    $text += ConvertTo-C6OutputScalar inputStaticFingerprint $StaticFingerprint
    $text += ConvertTo-C6OutputScalar inputEvidenceFingerprint $EvidenceFingerprint
    $text += ConvertTo-C6OutputScalar repairHistoryFingerprint $HistoryFingerprint
    "family-decision-sha256:$(Get-C6OutputSha256 $text)"
}
function Get-C6OutputIssueId([string]$FamilyId, [string]$IssueClass, [string[]]$SubjectIds, [string]$Attribution, [string[]]$Evidence) {
    $text = "C6ResidualIssueV1`n"
    $text += ConvertTo-C6OutputScalar familyId $FamilyId
    $text += ConvertTo-C6OutputScalar issueClass $IssueClass
    $text += Add-C6OutputSetFrame subjectIds $SubjectIds
    $text += ConvertTo-C6OutputScalar failureAttribution $Attribution
    $text += Add-C6OutputSetFrame evidence $Evidence
    "residual-issue-sha256:$(Get-C6OutputSha256 $text)"
}
function Get-C6OutputAccountingId([string]$OwningArray, [string]$SubjectKind, [string]$SubjectId, [string]$ReasonCode, [string]$Attribution, [string[]]$Evidence) {
    $text = "LifecycleAccountingV1`n"
    foreach ($pair in @(@('owningArray', $OwningArray), @('stageId', 'C6'), @('subjectKind', $SubjectKind), @('subjectId', $SubjectId), @('reasonCode', $ReasonCode), @('attribution', $Attribution))) {
        $text += ConvertTo-C6OutputScalar $pair[0] $pair[1]
    }
    $text += Add-C6OutputSetFrame evidence $Evidence
    "lifecycle-accounting-sha256:$(Get-C6OutputSha256 $text)"
}
function New-C6OutputAccountingRow([string]$OwningArray, [string]$SubjectKind, [string]$SubjectId, [string]$ReasonCode, [string]$Attribution, [string[]]$Evidence) {
    $orderedEvidence = @(Get-C6OutputOrdinalValues $Evidence -Unique)
    [pscustomobject][ordered]@{
        recordId = Get-C6OutputAccountingId $OwningArray $SubjectKind $SubjectId $ReasonCode $Attribution $orderedEvidence
        stageId = 'C6'; subjectKind = $SubjectKind; subjectId = $SubjectId; reasonCode = $ReasonCode
        attribution = $Attribution; evidence = $orderedEvidence
    }
}
function New-C6OutputReport([object]$Stage, [string]$InputFingerprint, [string]$PolicyFingerprint, [object]$Accounting, [object]$Decision) {
    "# C6 Lifecycle Gate Report`n" +
    "schemaVersion: 1.0.0`n" +
    "generatedAt: $($Stage.generatedAt)`n" +
    "stageId: C6`n" +
    "snapshotId: $($Stage.snapshotId)`n" +
    "inputFingerprint: $InputFingerprint`n" +
    "policySetFingerprint: $PolicyFingerprint`n" +
    "gateStatus: $($Accounting.gateStatus)`n" +
    "inputSubjectCount: $($Accounting.inputSubjectCount)`n" +
    "inputFailureCount: $($Accounting.inputFailureCount)`n" +
    "notEvaluatedInputSubjectCount: $($Accounting.notEvaluatedInputSubjectCount)`n" +
    "outputCandidateCount: $($Accounting.outputCandidateCount)`n" +
    "projectedOutputCount: $($Accounting.projectedOutputCount)`n" +
    "outputFailureCount: $($Accounting.outputFailureCount)`n" +
    "issueCount: $($Accounting.issueCount)`n" +
    "failureAttribution: $($Decision.failureAttribution)`n" +
    "nextAllowedAction: $($Decision.nextAllowedAction)`n"
}
function Get-C6OutputDecisionAction([string]$Decision) {
    switch ($Decision) {
        'NeedsDiagnosis' { 'Resolve the named diagnostic evidence before reuse.' }
        'UseOriginalAsset' { 'Admit the qualified members to the original-asset pool.' }
        'RepairOnce' { 'Run only the named focused repair in a separately authorized Task.' }
        'PrototypeReplacement' { 'Use only the qualified original media through the named replacement route.' }
        'RetainForLater' { 'Acquire only the missing or stale representative evidence.' }
        'DiagnosticOnly' { 'Retain this family for diagnosis only.' }
        default { 'Do not admit this family to an authoring pool.' }
    }
}
function Get-C6OutputByteSum([object[]]$Rows) {
    [int64]$sum = 0
    foreach ($row in $Rows) { $sum += [int64]$row.serializedSizeBytes }
    $sum
}

function Invoke-C6AuthoringOutputGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DecisionResult,
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object]$MemberStaticQualification,
        [Parameter(Mandatory)][object]$FamilyStaticSummary,
        [Parameter(Mandatory)][object]$RepresentativeRequirements,
        [Parameter(Mandatory)][object]$EvidenceAssessment,
        [Parameter(Mandatory)][object]$C3Summary,
        [Parameter(Mandatory)][object]$Stage
    )

    $directInputs = @(Get-C6OutputOrdinalRows @($Stage.directInputs) 'path')
    $inputFingerprint = Get-C6OutputStageFingerprint $directInputs
    $staticFingerprint = Get-C6OutputStageFingerprint @($directInputs | Where-Object artifactId -CIn @('C4-O01', 'C4-O02', 'C4-O03-Summary', 'C4-O03-Report'))
    $evidenceFingerprint = Get-C6OutputStageFingerprint @($directInputs | Where-Object artifactId -CIn @('C5-O01', 'C5-O02', 'C5-O04-Summary', 'C5-O04-Report'))
    $inputSubjectCount = $directInputs.Count + @($FamilyRegistry.families).Count + @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember').Count +
        @($RepresentativeRequirements.requirements).Count + @($RepresentativeRequirements.capabilitySuitabilityRequirements).Count + @($DecisionResult.capabilityResults).Count + 3

    $projectionFailureId = $null
    $projectionReasonCode = $null
    if ($DecisionResult.status -ceq 'Passed') {
        $expectedFamilyIds = @($FamilyRegistry.families | ForEach-Object familyId)
        $decisionFamilyIds = @($DecisionResult.familyDecisions | ForEach-Object familyId)
        $expectedMembers = @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember')
        $expectedMemberIds = @($expectedMembers | ForEach-Object assetObjectId)
        $projectionMemberIds = @($DecisionResult.memberProjections | ForEach-Object assetObjectId)
        $decisionStatuses = @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')
        $poolStatuses = @('AcceptedOriginalPool', 'AcceptedReplacementSourcePool', 'Isolated')
        $capabilityStatuses = @('Satisfied', 'Unsatisfied', 'Blocked')
        $decisionCounts = @(
            [int64]$DecisionResult.needsDiagnosisFamilyCount,
            [int64]$DecisionResult.useOriginalAssetFamilyCount,
            [int64]$DecisionResult.repairOnceFamilyCount,
            [int64]$DecisionResult.prototypeReplacementFamilyCount,
            [int64]$DecisionResult.retainForLaterFamilyCount,
            [int64]$DecisionResult.diagnosticOnlyFamilyCount,
            [int64]$DecisionResult.stopFamilyCount
        )
        $actualDecisionCounts = @($decisionStatuses | ForEach-Object {
            $status = $_
            @($DecisionResult.familyDecisions | Where-Object decision -CEQ $status).Count
        })
        $capabilityIds = @($DecisionResult.capabilityResults | ForEach-Object capabilityId)
        $memberFamilyById = @{}
        foreach ($member in $expectedMembers) { $memberFamilyById[[string]$member.assetObjectId] = [string]$member.familyId }

        if (-not (Test-C6OutputExactSet $expectedFamilyIds $decisionFamilyIds) -or
            [int64]$DecisionResult.totalFamilyCount -ne $expectedFamilyIds.Count -or
            ($decisionCounts -join ',') -cne ($actualDecisionCounts -join ',') -or
            @($DecisionResult.familyDecisions | Where-Object decision -CNotIn $decisionStatuses).Count -ne 0 -or
            -not (Test-C6OutputExactSet $expectedMemberIds $projectionMemberIds) -or
            @($DecisionResult.memberProjections | Where-Object {
                $_.poolStatus -CNotIn $poolStatuses -or
                -not $memberFamilyById.ContainsKey([string]$_.assetObjectId) -or
                $memberFamilyById[[string]$_.assetObjectId] -cne [string]$_.familyId
            }).Count -ne 0) {
            $projectionFailureId = 'LF-16'
            $projectionReasonCode = 'ConservationMismatch'
        }
        elseif (@(Get-C6OutputOrdinalValues $capabilityIds -Unique).Count -ne $capabilityIds.Count -or
            [int64]$DecisionResult.requiredCapabilityCount -ne $capabilityIds.Count -or
            [int64]$DecisionResult.satisfiedCapabilityCount -ne @($DecisionResult.capabilityResults | Where-Object status -CEQ 'Satisfied').Count -or
            [int64]$DecisionResult.unsatisfiedCapabilityCount -ne @($DecisionResult.capabilityResults | Where-Object status -CEQ 'Unsatisfied').Count -or
            [int64]$DecisionResult.blockedCapabilityCount -ne @($DecisionResult.capabilityResults | Where-Object status -CEQ 'Blocked').Count -or
            @($DecisionResult.capabilityResults | Where-Object status -CNotIn $capabilityStatuses).Count -ne 0) {
            $projectionFailureId = 'LF-18'
            $projectionReasonCode = 'CapabilityProjectionInvalid'
        }
    }

    $baseCoverage = [ordered]@{
        dispatchEligibleObjectCount = [int64]$C3Summary.coverage.dispatchEligibleObjectCount
        dispatchEligibleObjectBytes = [int64]$C3Summary.coverage.dispatchEligibleObjectBytes
        assignedFamilyMemberCount = [int64]$C3Summary.coverage.assignedFamilyMemberCount
        assignedFamilyMemberBytes = [int64]$C3Summary.coverage.assignedFamilyMemberBytes
        retainedForDiagnosisObjectCount = [int64]$C3Summary.coverage.retainedForDiagnosisObjectCount
        retainedForDiagnosisObjectBytes = [int64]$C3Summary.coverage.retainedForDiagnosisObjectBytes
        configurationOnlyObjectCount = [int64]$C3Summary.coverage.configurationOnlyObjectCount
        configurationOnlyObjectBytes = [int64]$C3Summary.coverage.configurationOnlyObjectBytes
    }
    $emptyCoverage = [pscustomobject][ordered]@{
        dispatchEligibleObjectCount = $baseCoverage.dispatchEligibleObjectCount; dispatchEligibleObjectBytes = $baseCoverage.dispatchEligibleObjectBytes
        assignedFamilyMemberCount = $baseCoverage.assignedFamilyMemberCount; assignedFamilyMemberBytes = $baseCoverage.assignedFamilyMemberBytes
        retainedForDiagnosisObjectCount = $baseCoverage.retainedForDiagnosisObjectCount; retainedForDiagnosisObjectBytes = $baseCoverage.retainedForDiagnosisObjectBytes
        configurationOnlyObjectCount = $baseCoverage.configurationOnlyObjectCount; configurationOnlyObjectBytes = $baseCoverage.configurationOnlyObjectBytes
        totalFamilyCount = 0; needsDiagnosisFamilyCount = 0; useOriginalAssetFamilyCount = 0; repairOnceFamilyCount = 0
        prototypeReplacementFamilyCount = 0; retainForLaterFamilyCount = 0; diagnosticOnlyFamilyCount = 0; stopFamilyCount = 0
        totalMemberCount = 0; totalMemberBytes = 0; acceptedOriginalPoolMemberCount = 0; acceptedOriginalPoolMemberBytes = 0
        acceptedReplacementSourcePoolMemberCount = 0; acceptedReplacementSourcePoolMemberBytes = 0; isolatedMemberCount = 0; isolatedMemberBytes = 0
        requiredCapabilityCount = 0; satisfiedCapabilityCount = 0; unsatisfiedCapabilityCount = 0; blockedCapabilityCount = 0
    }

    if ($DecisionResult.status -cne 'Passed' -or $null -ne $projectionFailureId) {
        $failureId = if ($null -ne $projectionFailureId) {
            $projectionFailureId
        } elseif ([string]::IsNullOrWhiteSpace([string]$DecisionResult.failureId)) {
            'LF-16'
        } else {
            [string]$DecisionResult.failureId
        }
        $reasonCode = if ($null -ne $projectionReasonCode) {
            $projectionReasonCode
        } elseif ([string]::IsNullOrWhiteSpace([string]$DecisionResult.reasonCode)) {
            'ConservationMismatch'
        } else {
            [string]$DecisionResult.reasonCode
        }
        $subjectId = 'C6:DecisionProjection'
        $attribution = "${failureId}:$subjectId"
        $evidence = @('Tools/AssetImport/Test-C6AuthoringOutputGate.ps1')
        $failure = New-C6OutputAccountingRow inputFailures ProjectionCheck $subjectId $reasonCode $attribution $evidence
        $outputFailures = @(
            New-C6OutputAccountingRow outputFailures OutputArtifact 'C6-O01' SuppressedByGate "${failureId}:C6-O01" @($script:C6OutputPaths.Ledger)
            New-C6OutputAccountingRow outputFailures OutputArtifact 'C6-O02' SuppressedByGate "${failureId}:C6-O02" @($script:C6OutputPaths.Decisions)
            New-C6OutputAccountingRow outputFailures OutputArtifact 'C6-O03' SuppressedByGate "${failureId}:C6-O03" @($script:C6OutputPaths.Capabilities)
            New-C6OutputAccountingRow outputFailures OutputArtifact 'C6-O04' SuppressedByGate "${failureId}:C6-O04" @($script:C6OutputPaths.Handoff)
        )
        $accounting = [pscustomobject][ordered]@{
            inputSubjectCount = $inputSubjectCount; acceptedInputSubjectCount = [Math]::Max(0, $inputSubjectCount - 2)
            inputFailureCount = 1; notEvaluatedInputSubjectCount = 1
            outputCandidateCount = 5; projectedOutputCount = 1; outputFailureCount = 4; issueCount = 1; gateStatus = 'Failed'
            inputFailures = @($failure); inputSuppressions = @(); outputFailures = $outputFailures
        }
        $decision = [pscustomobject][ordered]@{ failureAttribution = $attribution; nextAllowedAction = 'Correct the exact C6 decision or projection input.' }
        $report = New-C6OutputReport $Stage $inputFingerprint ([string]$DecisionResult.policySetFingerprint) $accounting $decision
        $directOutputs = @([pscustomobject][ordered]@{ artifactId = 'C6-O05-Report'; path = $script:C6OutputPaths.Report; sha256 = Get-C6OutputSha256 $report })
        $summary = [pscustomobject][ordered]@{
            schemaVersion = '1.0.0'; generatedAt = [string]$Stage.generatedAt; stageId = 'C6'; snapshotId = [string]$Stage.snapshotId
            inputFingerprint = $inputFingerprint; policySetFingerprint = [string]$DecisionResult.policySetFingerprint
            decisionPolicyFingerprint = [string]$DecisionResult.decisionPolicyFingerprint; toolVersions = @($Stage.toolVersions)
            directInputs = $directInputs; directOutputs = $directOutputs; coverage = $emptyCoverage; failureAccounting = $accounting; decision = $decision
        }
        return [pscustomobject][ordered]@{
            gateStatus = 'Failed'; authoringReuseLedger = $null; familyDecisionPackage = $null
            capabilityProjection = $null; g5Handoff = $null; summary = $summary; report = $report
            texts = [pscustomobject][ordered]@{ authoringReuseLedger = $null; familyDecisionPackage = $null; capabilityProjection = $null; g5Handoff = $null; summary = ConvertTo-C6OutputJson $summary }
            executorLaunchCount = 0; heavyOperationCount = 0; publicationWriteCount = 0
        }
    }

    $familyById = @{}; foreach ($family in $FamilyRegistry.families) { $familyById[[string]$family.familyId] = $family }
    $memberById = @{}; foreach ($member in @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember')) { $memberById[[string]$member.assetObjectId] = $member }
    $staticByMember = @{}; foreach ($member in $MemberStaticQualification.memberResults) { $staticByMember[[string]$member.assetObjectId] = $member }
    $staticByFamily = @{}; foreach ($family in $FamilyStaticSummary.families) { $staticByFamily[[string]$family.familyId] = $family }
    $decisionByFamily = @{}; foreach ($decisionRow in $DecisionResult.familyDecisions) { $decisionByFamily[[string]$decisionRow.familyId] = $decisionRow }

    $issues = [Collections.Generic.List[object]]::new()
    $decisionRows = [Collections.Generic.List[object]]::new()
    $ledgerFamilies = [Collections.Generic.List[object]]::new()
    foreach ($family in @(Get-C6OutputOrdinalRows @($FamilyRegistry.families) 'familyId')) {
        $familyId = [string]$family.familyId
        $selectedDecision = $decisionByFamily[$familyId]
        $staticFamily = $staticByFamily[$familyId]
        $riskAssessments = @($EvidenceAssessment.assessments | Where-Object familyId -CEQ $familyId)
        $acceptedIds = @(Get-C6OutputOrdinalValues @($riskAssessments | Where-Object assessmentStatus -CEQ 'EvidenceAccepted' | ForEach-Object assessmentId) -Unique)
        $issueClass = $null
        switch ([string]$selectedDecision.decision) {
            'NeedsDiagnosis' { $issueClass = 'UncheckedStatic' }
            'RepairOnce' { $issueClass = 'RepairPending' }
            'PrototypeReplacement' { $issueClass = 'ReplacementBehavior' }
            'RetainForLater' { $issueClass = 'EvidenceMissing' }
            'Stop' { $issueClass = 'StaticFailure' }
        }
        $familyMemberIds = @(Get-C6OutputOrdinalValues @($family.memberObjectIds) -Unique)
        $issueIds = @()
        $failureAttribution = 'None; family has no residual issue.'
        if ($null -ne $issueClass) {
            $subjectIds = if ($issueClass -ceq 'EvidenceMissing') {
                @(Get-C6OutputOrdinalValues @($riskAssessments | Where-Object assessmentStatus -CNE 'EvidenceAccepted' | ForEach-Object assessmentId) -Unique)
            } else { $familyMemberIds }
            $subjectIds = @($subjectIds)
            if (-not $subjectIds.Count) { $subjectIds = @($familyId) }
            $failureAttribution = "C6:${issueClass}:$familyId"
            $issueEvidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json')
            $issueId = Get-C6OutputIssueId $familyId $issueClass $subjectIds $failureAttribution $issueEvidence
            $issues.Add([pscustomobject][ordered]@{
                issueId = $issueId; familyId = $familyId; issueClass = $issueClass; subjectIds = $subjectIds
                failureAttribution = $failureAttribution; evidence = $issueEvidence
            })
            $issueIds = @($issueId)
        }
        $nextAction = Get-C6OutputDecisionAction ([string]$selectedDecision.decision)
        $decisionId = Get-C6OutputDecisionId $selectedDecision ([string]$DecisionResult.decisionPolicyFingerprint) $staticFingerprint $evidenceFingerprint ([string]$DecisionResult.repairHistoryFingerprint)
        $decisionRows.Add([pscustomobject][ordered]@{
            decisionId = $decisionId; familyId = $familyId; decision = $selectedDecision.decision
            repairClass = $selectedDecision.repairClass; replacementRouteKind = $selectedDecision.replacementRouteKind; ruleId = $selectedDecision.ruleId
            inputStaticFingerprint = $staticFingerprint; inputEvidenceFingerprint = $evidenceFingerprint
            repairHistoryFingerprint = $DecisionResult.repairHistoryFingerprint; acceptedEvidenceAssessmentIds = $acceptedIds
            failureAttribution = $failureAttribution; nextAllowedAction = $nextAction
            evidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json', 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json')
        })
        $qualified = @(Get-C6OutputOrdinalValues @($DecisionResult.memberProjections | Where-Object { $_.familyId -ceq $familyId -and $_.poolStatus -cne 'Isolated' } | ForEach-Object assetObjectId) -Unique)
        $isolated = @(Get-C6OutputOrdinalValues @($familyMemberIds | Where-Object { $_ -cnotin $qualified }) -Unique)
        $counts = @{}; foreach ($status in @('RepresentativeRequired', 'EvidenceAccepted', 'EvidenceMissing', 'EvidenceStale', 'UnityExecutionUnavailable', 'RepresentativeRejected')) {
            $counts[$status] = @($riskAssessments | Where-Object assessmentStatus -CEQ $status).Count
        }
        $ledgerFamilies.Add([pscustomobject][ordered]@{
            familyId = $familyId; lane = $family.lane; familyKindId = $family.familyKindId; familyKeyFingerprint = $family.familyKeyFingerprint
            memberSelector = @($family.familyKey); memberCount = [int64]$family.memberCount; memberBytes = [int64]$family.memberBytes
            staticPassedCount = [int64]$staticFamily.staticPassedCount; staticFailedCount = [int64]$staticFamily.staticFailedCount; uncheckedCount = [int64]$staticFamily.uncheckedCount
            representativeRequirementCount = $riskAssessments.Count; evidenceAcceptedCount = $counts.EvidenceAccepted; evidenceMissingCount = $counts.EvidenceMissing
            evidenceStaleCount = $counts.EvidenceStale; unityExecutionUnavailableCount = $counts.UnityExecutionUnavailable; representativeRejectedCount = $counts.RepresentativeRejected
            staticOutcome = $staticFamily.staticOutcome; decision = $selectedDecision.decision; repairClass = $selectedDecision.repairClass
            replacementRouteKind = $selectedDecision.replacementRouteKind; failureAttribution = $failureAttribution; nextAllowedAction = $nextAction
            acceptedEvidenceAssessmentIds = $acceptedIds; residualIssueIds = $issueIds; qualifiedMemberIds = $qualified; isolatedMemberIds = $isolated
            directGateSummaries = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json', 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json', 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-summary.json')
            directGateReports = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md', 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md', 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-report.md')
            inputFingerprint = $inputFingerprint
        })
    }

    $ledgerMembers = [Collections.Generic.List[object]]::new()
    foreach ($projection in @(Get-C6OutputOrdinalRows @($DecisionResult.memberProjections) 'assetObjectId')) {
        $member = $memberById[[string]$projection.assetObjectId]
        $static = $staticByMember[[string]$projection.assetObjectId]
        $requirementIds = @(Get-C6OutputOrdinalValues @($RepresentativeRequirements.requirements | Where-Object familyId -CEQ $projection.familyId | ForEach-Object requirementId) -Unique)
        $attribution = if ($projection.poolStatus -ceq 'Isolated') { $ledgerFamilies | Where-Object familyId -CEQ $projection.familyId | ForEach-Object failureAttribution } else { 'None; member admitted to an accepted pool.' }
        $ledgerMembers.Add([pscustomobject][ordered]@{
            assetObjectId = $projection.assetObjectId; familyId = $projection.familyId; lane = $member.lane
            serializedSizeBytes = [int64]$member.serializedSizeBytes; staticStatus = $static.staticStatus
            representativeRequirementIds = $requirementIds; disposition = $projection.disposition; poolStatus = $projection.poolStatus
            failureAttribution = [string]$attribution; evidence = @($member.evidence)
        })
    }

    $capabilities = [Collections.Generic.List[object]]::new()
    foreach ($capability in @(Get-C6OutputOrdinalRows @($DecisionResult.capabilityResults) 'capabilityId')) {
        $attribution = if ($capability.status -ceq 'Satisfied') { 'None; capability has an accepted family and route.' } else { "C6:$($capability.status):$($capability.capabilityId)" }
        $capabilities.Add([pscustomobject][ordered]@{
            capabilityId = $capability.capabilityId; status = $capability.status
            satisfyingFamilyIds = @($capability.satisfyingFamilyIds); routeKinds = @($capability.routeKinds)
            suitabilityAssessmentIds = @($capability.suitabilityAssessmentIds); failureAttribution = $attribution
            evidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json', 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json')
        })
    }

    $originalMembers = @($ledgerMembers | Where-Object poolStatus -CEQ 'AcceptedOriginalPool')
    $replacementMembers = @($ledgerMembers | Where-Object poolStatus -CEQ 'AcceptedReplacementSourcePool')
    $isolatedMembers = @($ledgerMembers | Where-Object poolStatus -CEQ 'Isolated')
    $totalBytes = Get-C6OutputByteSum @($ledgerMembers)
    $originalBytes = Get-C6OutputByteSum $originalMembers
    $replacementBytes = Get-C6OutputByteSum $replacementMembers
    $isolatedBytes = Get-C6OutputByteSum $isolatedMembers
    $coverage = [pscustomobject][ordered]@{
        dispatchEligibleObjectCount = $baseCoverage.dispatchEligibleObjectCount; dispatchEligibleObjectBytes = $baseCoverage.dispatchEligibleObjectBytes
        assignedFamilyMemberCount = $baseCoverage.assignedFamilyMemberCount; assignedFamilyMemberBytes = $baseCoverage.assignedFamilyMemberBytes
        retainedForDiagnosisObjectCount = $baseCoverage.retainedForDiagnosisObjectCount; retainedForDiagnosisObjectBytes = $baseCoverage.retainedForDiagnosisObjectBytes
        configurationOnlyObjectCount = $baseCoverage.configurationOnlyObjectCount; configurationOnlyObjectBytes = $baseCoverage.configurationOnlyObjectBytes
        totalFamilyCount = $DecisionResult.totalFamilyCount; needsDiagnosisFamilyCount = $DecisionResult.needsDiagnosisFamilyCount
        useOriginalAssetFamilyCount = $DecisionResult.useOriginalAssetFamilyCount; repairOnceFamilyCount = $DecisionResult.repairOnceFamilyCount
        prototypeReplacementFamilyCount = $DecisionResult.prototypeReplacementFamilyCount; retainForLaterFamilyCount = $DecisionResult.retainForLaterFamilyCount
        diagnosticOnlyFamilyCount = $DecisionResult.diagnosticOnlyFamilyCount; stopFamilyCount = $DecisionResult.stopFamilyCount
        totalMemberCount = $ledgerMembers.Count; totalMemberBytes = $totalBytes
        acceptedOriginalPoolMemberCount = $originalMembers.Count; acceptedOriginalPoolMemberBytes = $originalBytes
        acceptedReplacementSourcePoolMemberCount = $replacementMembers.Count; acceptedReplacementSourcePoolMemberBytes = $replacementBytes
        isolatedMemberCount = $isolatedMembers.Count; isolatedMemberBytes = $isolatedBytes
        requiredCapabilityCount = $DecisionResult.requiredCapabilityCount; satisfiedCapabilityCount = $DecisionResult.satisfiedCapabilityCount
        unsatisfiedCapabilityCount = $DecisionResult.unsatisfiedCapabilityCount; blockedCapabilityCount = $DecisionResult.blockedCapabilityCount
    }
    $sourceArtifacts = $directInputs
    $ledger = [pscustomobject][ordered]@{
        schemaVersion = '2.0.0'; generatedAt = [string]$Stage.generatedAt; snapshotId = [string]$Stage.snapshotId
        inputFingerprint = $inputFingerprint; policySetFingerprint = [string]$DecisionResult.policySetFingerprint
        decisionPolicyFingerprint = [string]$DecisionResult.decisionPolicyFingerprint; toolVersions = @($Stage.toolVersions)
        sourceArtifacts = $sourceArtifacts; families = @($ledgerFamilies); members = @($ledgerMembers)
        coverage = [pscustomobject][ordered]@{
            dispatchEligibleObjectCount = $baseCoverage.dispatchEligibleObjectCount; dispatchEligibleObjectBytes = $baseCoverage.dispatchEligibleObjectBytes
            assignedFamilyMemberCount = $baseCoverage.assignedFamilyMemberCount; assignedFamilyMemberBytes = $baseCoverage.assignedFamilyMemberBytes
            retainedForDiagnosisObjectCount = $baseCoverage.retainedForDiagnosisObjectCount; retainedForDiagnosisObjectBytes = $baseCoverage.retainedForDiagnosisObjectBytes
            configurationOnlyObjectCount = $baseCoverage.configurationOnlyObjectCount; configurationOnlyObjectBytes = $baseCoverage.configurationOnlyObjectBytes
            totalFamilyCount = $DecisionResult.totalFamilyCount; reusableFamilyCount = $DecisionResult.useOriginalAssetFamilyCount
            totalMemberCount = $ledgerMembers.Count; reusableMemberCount = $originalMembers.Count; isolatedMemberCount = $isolatedMembers.Count
            totalBytes = $totalBytes; reusableBytes = $originalBytes; isolatedBytes = $isolatedBytes
        }
        capabilities = @($capabilities)
    }
    $decisionPackage = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'; generatedAt = [string]$Stage.generatedAt; snapshotId = [string]$Stage.snapshotId
        inputFingerprint = $inputFingerprint; policySetFingerprint = [string]$DecisionResult.policySetFingerprint
        decisionPolicyFingerprint = [string]$DecisionResult.decisionPolicyFingerprint
        decisions = @($decisionRows); issues = @(Get-C6OutputOrdinalRows @($issues) 'issueId')
    }
    $capabilityProjection = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'; generatedAt = [string]$Stage.generatedAt; snapshotId = [string]$Stage.snapshotId
        inputFingerprint = $inputFingerprint; policySetFingerprint = [string]$DecisionResult.policySetFingerprint
        decisionPolicyFingerprint = [string]$DecisionResult.decisionPolicyFingerprint; capabilities = @($capabilities)
    }
    $ledgerText = ConvertTo-C6OutputJson $ledger
    $decisionText = ConvertTo-C6OutputJson $decisionPackage
    $capabilityText = ConvertTo-C6OutputJson $capabilityProjection
    $requiredIds = @(Get-C6OutputOrdinalValues @($capabilities.capabilityId) -Unique)
    $satisfiedIds = @(Get-C6OutputOrdinalValues @($capabilities | Where-Object status -CEQ 'Satisfied' | ForEach-Object capabilityId) -Unique)
    $unsatisfiedIds = @(Get-C6OutputOrdinalValues @($capabilities | Where-Object status -CEQ 'Unsatisfied' | ForEach-Object capabilityId) -Unique)
    $blockedIds = @(Get-C6OutputOrdinalValues @($capabilities | Where-Object status -CEQ 'Blocked' | ForEach-Object capabilityId) -Unique)
    $ready = $requiredIds.Count -eq $satisfiedIds.Count -and
        $unsatisfiedIds.Count -eq 0 -and
        $blockedIds.Count -eq 0 -and
        @($ledgerMembers | Where-Object {
            $_.poolStatus -CNotIn @('AcceptedOriginalPool', 'AcceptedReplacementSourcePool') -and $_.poolStatus -cne 'Isolated'
        }).Count -eq 0 -and
        @($ledgerMembers | Where-Object { $_.staticStatus -cne 'StaticPassed' -and $_.poolStatus -cne 'Isolated' }).Count -eq 0
    $handoff = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'; generatedAt = [string]$Stage.generatedAt; snapshotId = [string]$Stage.snapshotId; inputFingerprint = $inputFingerprint
        authoringReuseLedgerPath = $script:C6OutputPaths.Ledger; authoringReuseLedgerSha256 = Get-C6OutputSha256 $ledgerText
        familyDecisionPackagePath = $script:C6OutputPaths.Decisions; familyDecisionPackageSha256 = Get-C6OutputSha256 $decisionText
        capabilityProjectionPath = $script:C6OutputPaths.Capabilities; capabilityProjectionSha256 = Get-C6OutputSha256 $capabilityText
        familyConstructionCoverage = [pscustomobject]$baseCoverage
        originalAssetBatchCoverage = [pscustomobject][ordered]@{
            reusableFamilyCount = $DecisionResult.useOriginalAssetFamilyCount; totalFamilyCount = $DecisionResult.totalFamilyCount
            reusableMemberCount = $originalMembers.Count; totalMemberCount = $ledgerMembers.Count; reusableBytes = $originalBytes; totalBytes = $totalBytes
        }
        stellaSora2AuthoringReady = [pscustomobject][ordered]@{
            value = $ready; requiredCapabilityIds = $requiredIds; satisfiedCapabilityIds = $satisfiedIds
            unsatisfiedCapabilityIds = $unsatisfiedIds; blockedCapabilityIds = $blockedIds; isolatedMemberCount = $isolatedMembers.Count
        }
        failureAttribution = 'None; C6 lifecycle contract passed.'
        nextAllowedAction = 'Provide only the current C6 G5 handoff to G5.'
    }
    $handoffText = ConvertTo-C6OutputJson $handoff
    $accounting = [pscustomobject][ordered]@{
        inputSubjectCount = $inputSubjectCount; acceptedInputSubjectCount = $inputSubjectCount; inputFailureCount = 0; notEvaluatedInputSubjectCount = 0
        outputCandidateCount = 5; projectedOutputCount = 5; outputFailureCount = 0; issueCount = 0; gateStatus = 'Passed'
        inputFailures = @(); inputSuppressions = @(); outputFailures = @()
    }
    $summaryDecision = [pscustomobject][ordered]@{ failureAttribution = 'None; C6 lifecycle contract passed.'; nextAllowedAction = 'Provide only the current C6 G5 handoff to G5.' }
    $report = New-C6OutputReport $Stage $inputFingerprint ([string]$DecisionResult.policySetFingerprint) $accounting $summaryDecision
    $directOutputs = @(Get-C6OutputOrdinalRows @(
        [pscustomobject][ordered]@{ artifactId = 'C6-O01'; path = $script:C6OutputPaths.Ledger; sha256 = Get-C6OutputSha256 $ledgerText }
        [pscustomobject][ordered]@{ artifactId = 'C6-O02'; path = $script:C6OutputPaths.Decisions; sha256 = Get-C6OutputSha256 $decisionText }
        [pscustomobject][ordered]@{ artifactId = 'C6-O03'; path = $script:C6OutputPaths.Capabilities; sha256 = Get-C6OutputSha256 $capabilityText }
        [pscustomobject][ordered]@{ artifactId = 'C6-O04'; path = $script:C6OutputPaths.Handoff; sha256 = Get-C6OutputSha256 $handoffText }
        [pscustomobject][ordered]@{ artifactId = 'C6-O05-Report'; path = $script:C6OutputPaths.Report; sha256 = Get-C6OutputSha256 $report }
    ) 'path')
    $summary = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'; generatedAt = [string]$Stage.generatedAt; stageId = 'C6'; snapshotId = [string]$Stage.snapshotId
        inputFingerprint = $inputFingerprint; policySetFingerprint = [string]$DecisionResult.policySetFingerprint
        decisionPolicyFingerprint = [string]$DecisionResult.decisionPolicyFingerprint; toolVersions = @($Stage.toolVersions)
        directInputs = $directInputs; directOutputs = $directOutputs; coverage = $coverage; failureAccounting = $accounting; decision = $summaryDecision
    }
    [pscustomobject][ordered]@{
        gateStatus = 'Passed'; authoringReuseLedger = $ledger; familyDecisionPackage = $decisionPackage
        capabilityProjection = $capabilityProjection; g5Handoff = $handoff; summary = $summary; report = $report
        texts = [pscustomobject][ordered]@{
            authoringReuseLedger = $ledgerText; familyDecisionPackage = $decisionText; capabilityProjection = $capabilityText
            g5Handoff = $handoffText; summary = ConvertTo-C6OutputJson $summary
        }
        executorLaunchCount = 0; heavyOperationCount = 0; publicationWriteCount = 0
    }
}

Export-ModuleMember -Function Invoke-C6AuthoringOutputGate
