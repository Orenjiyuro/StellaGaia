Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'C6ChildConservationGate.psm1') -Force

$script:C6DecisionUtf8 = [Text.UTF8Encoding]::new($false)
$script:C6DecisionOrdinal = [StringComparer]::Ordinal
$script:C6DirectInputPaths = [ordered]@{
    'C3-O04-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
    'C3-O04-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json'
    'C4-O03-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'
    'C4-O03-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json'
    'C5-O04-Report' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-report.md'
    'C5-O04-Summary' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c5-summary.json'
    'C3-O03' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json'
    'C5-O02' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json'
    'C3-O02' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json'
    'C3-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json'
    'C4-O02' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json'
    'C4-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json'
    'C5-O01' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-representative-requirements.json'
    'LC-I11' = 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json'
    'LC-I07' = 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
    'LC-I08' = 'docs/asset-migration/schemas/status-vocabulary.json'
    'LC-I12' = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/repair-attempt-history.json'
}

function Get-C6DecisionSha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C6DecisionUtf8.GetBytes($Text))).ToLowerInvariant()
}
function ConvertTo-C6DecisionScalar([string]$Name, [string]$Value) {
    if ($null -eq $Value -or $Value.IndexOfAny([char[]]@([char]0, "`r", "`n")) -ge 0) { throw "Invalid framed scalar: $Name" }
    "${Name}:$($script:C6DecisionUtf8.GetByteCount($Value)):${Value}`n"
}
function ConvertTo-C6DecisionNullable([string]$Name, $Value) {
    if ($null -eq $Value) { return "${Name}:null`n" }
    ConvertTo-C6DecisionScalar $Name ([string]$Value)
}
function Get-C6DecisionOrdinalValues([object[]]$Values, [switch]$Unique) {
    $list = [Collections.Generic.List[string]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new($script:C6DecisionOrdinal)
    foreach ($value in $Values) {
        $text = [string]$value
        if (-not $Unique -or $seen.Add($text)) { $list.Add($text) }
    }
    $list.Sort($script:C6DecisionOrdinal)
    [string[]]$list.ToArray()
}
function Add-C6DecisionSetFrame([string]$Name, [object[]]$Values) {
    $ordered = @(Get-C6DecisionOrdinalValues $Values)
    $count = [string]$ordered.Count
    $text = "${Name}.count:$($script:C6DecisionUtf8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $text += ConvertTo-C6DecisionScalar "${Name}[$index]" $ordered[$index]
    }
    $text
}
function Get-C6DecisionOrdinalRows([object[]]$Rows, [string]$Property) {
    $list = [Collections.Generic.List[object]]::new()
    foreach ($row in $Rows) { $list.Add($row) }
    $list.Sort([Comparison[object]]{ param($left, $right) $script:C6DecisionOrdinal.Compare([string]$left.$Property, [string]$right.$Property) })
    @($list.ToArray())
}
function Test-C6DecisionExactArray([object[]]$Actual, [string[]]$Expected) {
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne $Expected[$index]) { return $false }
    }
    $true
}
function Test-C6DecisionObjectBytesBinding([object]$Value, [string]$Bytes) {
    try { $parsed = $Bytes | ConvertFrom-Json -Depth 100 -DateKind String } catch { return $false }
    ($Value | ConvertTo-Json -Depth 100 -Compress) -ceq ($parsed | ConvertTo-Json -Depth 100 -Compress)
}
function Test-C6DecisionSubset([object[]]$Subset, [object[]]$Superset) {
    foreach ($value in $Subset) {
        if ([string]$value -cnotin @($Superset)) { return $false }
    }
    $true
}
function Test-C6DecisionExactSet([object[]]$Left, [object[]]$Right) {
    $leftValues = @(Get-C6DecisionOrdinalValues $Left -Unique)
    $rightValues = @(Get-C6DecisionOrdinalValues $Right -Unique)
    if ($leftValues.Count -ne @($Left).Count -or $rightValues.Count -ne @($Right).Count -or $leftValues.Count -ne $rightValues.Count) { return $false }
    Test-C6DecisionExactArray $leftValues $rightValues
}
function Test-C6DecisionOrdinalSet([object[]]$Values, [switch]$Nonempty) {
    if ($Nonempty -and $Values.Count -eq 0) { return $false }
    $previous = $null
    foreach ($value in $Values) {
        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text) -or
            ($null -ne $previous -and $script:C6DecisionOrdinal.Compare($previous, $text) -ge 0)) {
            return $false
        }
        $previous = $text
    }
    $true
}
function New-C6DecisionMap([object[]]$Rows, [string]$Property) {
    $map = [Collections.Generic.Dictionary[string, object]]::new($script:C6DecisionOrdinal)
    foreach ($row in $Rows) {
        if ($null -eq $row -or $null -eq $row.PSObject.Properties[$Property]) { return $null }
        $id = [string]$row.$Property
        if ([string]::IsNullOrWhiteSpace($id) -or $map.ContainsKey($id)) { return $null }
        $map.Add($id, $row)
    }
    $map
}
function Get-C6StageInputFingerprint([object[]]$Entries) {
    $ordered = @(Get-C6DecisionOrdinalRows $Entries 'path')
    $count = [string]$ordered.Count
    $text = "LifecycleStageInputV1`nentries.count:$($script:C6DecisionUtf8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $nested = "C2ArtifactEntryV1`n"
        $nested += ConvertTo-C6DecisionScalar path ([string]$ordered[$index].path)
        $nested += ConvertTo-C6DecisionScalar sha256 ([string]$ordered[$index].sha256)
        $text += "entries[$index]:$($script:C6DecisionUtf8.GetByteCount($nested)):$nested`n"
    }
    Get-C6DecisionSha256 $text
}
function Get-C6RepairAttemptId([object]$Attempt) {
    $text = "C6RepairAttemptV1`n"
    $text += ConvertTo-C6DecisionScalar familyId ([string]$Attempt.familyId)
    $text += ConvertTo-C6DecisionScalar repairClass ([string]$Attempt.repairClass)
    $text += ConvertTo-C6DecisionScalar attemptNumber ([string]$Attempt.attemptNumber)
    $text += ConvertTo-C6DecisionScalar inputFingerprint ([string]$Attempt.inputFingerprint)
    $text += ConvertTo-C6DecisionNullable outputFingerprint $Attempt.outputFingerprint
    $text += ConvertTo-C6DecisionScalar expectedChangeMeasure ([string]$Attempt.expectedChangeMeasure)
    $text += ConvertTo-C6DecisionNullable observedChange $Attempt.observedChange
    $text += ConvertTo-C6DecisionScalar outcome ([string]$Attempt.outcome)
    $text += Add-C6DecisionSetFrame evidence @($Attempt.evidence)
    "repair-attempt-sha256:$(Get-C6DecisionSha256 $text)"
}
function New-C6DecisionFailure([string]$FailureId, [string]$ReasonCode, [string[]]$Issues, [string]$PolicyFingerprint, [string]$DecisionFingerprint, [string]$HistoryFingerprint, [string]$InputFingerprint) {
    [pscustomobject][ordered]@{
        status = 'Failed'; failureId = $FailureId; reasonCode = $ReasonCode; issues = $Issues
        policySetFingerprint = $PolicyFingerprint; decisionPolicyFingerprint = $DecisionFingerprint
        repairHistoryFingerprint = $HistoryFingerprint; inputFingerprint = $InputFingerprint
        familyDecisions = @(); memberProjections = @(); capabilityResults = @()
        totalFamilyCount = 0; needsDiagnosisFamilyCount = 0; useOriginalAssetFamilyCount = 0
        repairOnceFamilyCount = 0; prototypeReplacementFamilyCount = 0; retainForLaterFamilyCount = 0
        diagnosticOnlyFamilyCount = 0; stopFamilyCount = 0
        requiredCapabilityCount = 0; satisfiedCapabilityCount = 0; unsatisfiedCapabilityCount = 0; blockedCapabilityCount = 0
        executorLaunchCount = 0; heavyOperationCount = 0
    }
}

function Invoke-C6AuthoringDecisionKernel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object]$CrossLaneReferencePackage,
        [Parameter(Mandatory)][object]$MemberStaticQualification,
        [Parameter(Mandatory)][object]$FamilyStaticSummary,
        [Parameter(Mandatory)][object]$RepresentativeRequirements,
        [Parameter(Mandatory)][object]$EvidenceAssessment,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][object]$DecisionPolicyRegistry,
        [Parameter(Mandatory)][string]$DecisionPolicyBytes,
        [Parameter(Mandatory)][object]$StatusVocabulary,
        [Parameter(Mandatory)][string]$StatusVocabularyBytes,
        [Parameter(Mandatory)][object]$RepairAttemptHistory,
        [Parameter(Mandatory)][string]$RepairAttemptHistoryBytes,
        [Parameter(Mandatory)][object[]]$ExecutionArtifacts,
        [Parameter(Mandatory)][object[]]$DirectInputs
    )

    $issues = [Collections.Generic.List[string]]::new()
    $policyFingerprint = Get-C6DecisionSha256 $LanePolicyBytes
    $decisionFingerprint = Get-C6DecisionSha256 $DecisionPolicyBytes
    $historyFingerprint = Get-C6DecisionSha256 $RepairAttemptHistoryBytes
    $inputFingerprint = ''

    $directById = New-C6DecisionMap $DirectInputs 'artifactId'
    $directByPath = New-C6DecisionMap $DirectInputs 'path'
    $executionById = New-C6DecisionMap $ExecutionArtifacts 'artifactId'
    if ($null -eq $directById -or $null -eq $directByPath -or $DirectInputs.Count -ne $script:C6DirectInputPaths.Count) {
        $issues.Add('C6 direct input set is invalid.')
    }
    else {
        for ($index = 1; $index -lt $DirectInputs.Count; $index++) {
            if ($script:C6DecisionOrdinal.Compare([string]$DirectInputs[$index - 1].path, [string]$DirectInputs[$index].path) -ge 0) {
                $issues.Add('C6 direct inputs are not Ordinal sorted.')
                break
            }
        }
        foreach ($expected in $script:C6DirectInputPaths.GetEnumerator()) {
            if (-not $directById.ContainsKey([string]$expected.Key) -or
                [string]$directById[[string]$expected.Key].path -cne [string]$expected.Value -or
                [string]$directById[[string]$expected.Key].sha256 -cnotmatch '^[0-9a-f]{64}$') {
                $issues.Add('C6 direct input set is invalid.')
                break
            }
        }
        if (-not $issues.Count) {
            $inputFingerprint = Get-C6StageInputFingerprint $DirectInputs
            $withoutHistory = @($DirectInputs | Where-Object artifactId -CNE 'LC-I12')
            $expectedHistoryInput = Get-C6StageInputFingerprint $withoutHistory
            if ([string]$RepairAttemptHistory.inputFingerprint -cne $expectedHistoryInput) {
                $issues.Add('LC-I12 inputFingerprint does not bind the exact C6 input set excluding LC-I12.')
            }
            if ([string]$directById['LC-I07'].sha256 -cne $policyFingerprint -or
                [string]$directById['LC-I11'].sha256 -cne $decisionFingerprint -or
                [string]$directById['LC-I08'].sha256 -cne (Get-C6DecisionSha256 $StatusVocabularyBytes) -or
                [string]$directById['LC-I12'].sha256 -cne $historyFingerprint) {
                $issues.Add('C6 exact-byte direct input hash mismatch.')
            }
        }
    }

    $executionObjects = [ordered]@{
        'C3-O01' = $FamilyRegistry
        'C3-O02' = $FamilyMemberLedger
        'C3-O03' = $CrossLaneReferencePackage
        'C4-O01' = $MemberStaticQualification
        'C4-O02' = $FamilyStaticSummary
        'C5-O01' = $RepresentativeRequirements
        'C5-O02' = $EvidenceAssessment
    }
    if ($null -eq $executionById -or $ExecutionArtifacts.Count -ne $executionObjects.Count -or $null -eq $directById) {
        $issues.Add('C6 execution artifact byte set is invalid.')
    }
    else {
        foreach ($entry in $executionObjects.GetEnumerator()) {
            if (-not $executionById.ContainsKey([string]$entry.Key) -or
                -not $directById.ContainsKey([string]$entry.Key) -or
                $null -eq $executionById[[string]$entry.Key].PSObject.Properties['bytes']) {
                $issues.Add('C6 execution artifact byte set is invalid.')
                break
            }
            $bytes = [string]$executionById[[string]$entry.Key].bytes
            if ([string]$directById[[string]$entry.Key].sha256 -cne (Get-C6DecisionSha256 $bytes) -or
                -not (Test-C6DecisionObjectBytesBinding $entry.Value $bytes)) {
                $issues.Add("C6 execution object/bytes binding failed for $($entry.Key).")
                break
            }
        }
    }

    if (-not (Test-C6DecisionObjectBytesBinding $LanePolicyRegistry $LanePolicyBytes)) { $issues.Add('LC-I07 execution object does not match accepted bytes.') }
    if (-not (Test-C6DecisionObjectBytesBinding $DecisionPolicyRegistry $DecisionPolicyBytes)) { $issues.Add('LC-I11 execution object does not match accepted bytes.') }
    if (-not (Test-C6DecisionObjectBytesBinding $StatusVocabulary $StatusVocabularyBytes)) { $issues.Add('LC-I08 execution object does not match accepted bytes.') }
    if (-not (Test-C6DecisionObjectBytesBinding $RepairAttemptHistory $RepairAttemptHistoryBytes)) { $issues.Add('LC-I12 execution object does not match accepted bytes.') }
    $canonicalHistory = (($RepairAttemptHistory | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
    if ($RepairAttemptHistoryBytes.Contains("`r") -or -not $RepairAttemptHistoryBytes.EndsWith("`n") -or
        $RepairAttemptHistoryBytes.EndsWith("`n`n") -or $RepairAttemptHistoryBytes -cne $canonicalHistory) {
        $issues.Add('LC-I12 bytes are not canonical UTF-8 lifecycle JSON.')
    }

    if (-not (Test-C6DecisionExactArray @($StatusVocabulary.disposition) @('NeedsDiagnosis', 'UseOriginalAsset', 'RepairOnce', 'PrototypeReplacement', 'RetainForLater', 'DiagnosticOnly', 'Stop')) -or
        -not (Test-C6DecisionExactArray @($StatusVocabulary.authoringPoolStatus) @('AcceptedOriginalPool', 'AcceptedReplacementSourcePool', 'Isolated')) -or
        -not (Test-C6DecisionExactArray @($StatusVocabulary.capabilityStatus) @('Satisfied', 'Unsatisfied', 'Blocked'))) {
        $issues.Add('LC-I08 C6 vocabulary is invalid.')
    }
    if ([string]$FamilyRegistry.policySetFingerprint -cne $policyFingerprint -or
        [string]$FamilyMemberLedger.policySetFingerprint -cne $policyFingerprint -or
        [string]$CrossLaneReferencePackage.policySetFingerprint -cne $policyFingerprint -or
        [string]$MemberStaticQualification.policySetFingerprint -cne $policyFingerprint -or
        [string]$FamilyStaticSummary.policySetFingerprint -cne $policyFingerprint -or
        [string]$RepresentativeRequirements.policySetFingerprint -cne $policyFingerprint -or
        [string]$EvidenceAssessment.policySetFingerprint -cne $policyFingerprint -or
        [string]$RepresentativeRequirements.decisionPolicyFingerprint -cne $decisionFingerprint -or
        [string]$EvidenceAssessment.decisionPolicyFingerprint -cne $decisionFingerprint) {
        $issues.Add('C6 policy fingerprint does not match child generations.')
    }
    if ([string]$FamilyMemberLedger.snapshotId -cne [string]$FamilyRegistry.snapshotId -or
        [string]$CrossLaneReferencePackage.snapshotId -cne [string]$FamilyRegistry.snapshotId -or
        [string]$CrossLaneReferencePackage.inputFingerprint -cne [string]$FamilyRegistry.inputFingerprint) {
        $issues.Add('C3 reference generation does not match the family generation.')
    }

    $child = Test-C6ChildRowConservation -FamilyRegistry $FamilyRegistry -FamilyMemberLedger $FamilyMemberLedger `
        -MemberStaticQualification $MemberStaticQualification -FamilyStaticSummary $FamilyStaticSummary `
        -RepresentativeRequirements $RepresentativeRequirements -EvidenceAssessment $EvidenceAssessment
    if ($child.gateStatus -cne 'Passed') { $issues.Add("$($child.attribution): child conservation failed.") }

    $laneByLane = New-C6DecisionMap @($LanePolicyRegistry.policies) 'lane'
    $familyById = New-C6DecisionMap @($FamilyRegistry.families) 'familyId'
    $staticFamilyById = New-C6DecisionMap @($FamilyStaticSummary.families) 'familyId'
    $memberStaticById = New-C6DecisionMap @($MemberStaticQualification.memberResults) 'assetObjectId'
    if ($null -eq $laneByLane -or $null -eq $familyById -or $null -eq $staticFamilyById -or $null -eq $memberStaticById) {
        $issues.Add('C6 decision lookup universe is invalid.')
    }

    $attemptPairs = [Collections.Generic.HashSet[string]]::new($script:C6DecisionOrdinal)
    $attemptIds = [Collections.Generic.HashSet[string]]::new($script:C6DecisionOrdinal)
    if ((@($RepairAttemptHistory.PSObject.Properties.Name) -join ',') -cne 'schemaVersion,generatedAt,inputFingerprint,attempts' -or
        $RepairAttemptHistory.schemaVersion -cne '1.0.0' -or
        $RepairAttemptHistory.generatedAt -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$') {
        $issues.Add('LC-I12 envelope is invalid.')
    }
    foreach ($attempt in @($RepairAttemptHistory.attempts)) {
        if ((@($attempt.PSObject.Properties.Name) -join ',') -cne 'attemptId,familyId,repairClass,attemptNumber,inputFingerprint,outputFingerprint,expectedChangeMeasure,observedChange,outcome,evidence' -or
            $null -eq $familyById -or -not $familyById.ContainsKey([string]$attempt.familyId)) {
            $issues.Add('LC-I12 attempt shape or family identity is invalid.'); continue
        }
        $family = $familyById[[string]$attempt.familyId]
        if ($null -eq $laneByLane -or -not $laneByLane.ContainsKey([string]$family.lane)) {
            $issues.Add('LC-I12 attempt lane policy resolution is invalid.'); continue
        }
        $policy = $laneByLane[[string]$family.lane]
        $repair = @($policy.repairRules | Where-Object { $_.repairClass -ceq [string]$attempt.repairClass -and $_.applicableFamilyKinds -ccontains [string]$family.familyKindId })
        $pair = "$($attempt.familyId)|$($attempt.repairClass)"
        $evidence = @($attempt.evidence)
        if ($repair.Count -ne 1 -or [string]$repair[0].expectedChangeMeasure -cne [string]$attempt.expectedChangeMeasure -or
            $attempt.attemptNumber -ne 1 -or [string]$attempt.attemptId -cne (Get-C6RepairAttemptId $attempt) -or
            -not $attemptIds.Add([string]$attempt.attemptId) -or -not $attemptPairs.Add($pair) -or
            -not (Test-C6DecisionOrdinalSet $evidence -Nonempty) -or
            [string]$attempt.inputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or
            ($null -ne $attempt.outputFingerprint -and [string]$attempt.outputFingerprint -cnotmatch '^[0-9a-f]{64}$') -or
            ($attempt.outcome -ceq 'Improved' -and ($null -eq $attempt.outputFingerprint -or $null -eq $attempt.observedChange -or [int64]$attempt.observedChange -le 0)) -or
            ($attempt.outcome -ceq 'NoImprovement' -and ($null -eq $attempt.outputFingerprint -or [int64]$attempt.observedChange -ne 0)) -or
            ($attempt.outcome -ceq 'Failed' -and ($null -ne $attempt.outputFingerprint -or $null -ne $attempt.observedChange)) -or
            $attempt.outcome -cnotin @('Improved', 'NoImprovement', 'Failed')) {
            $issues.Add('LC-I12 attempt semantic contract is invalid.')
        }
    }

    if ($issues.Count) {
        $failure = if (@($issues | Where-Object { $_ -like 'LF-18:*' }).Count) { 'LF-18' } elseif (@($issues | Where-Object { $_ -like 'LF-17:*' }).Count) { 'LF-17' } else { 'LF-16' }
        $reason = if ($failure -ceq 'LF-18') { 'CapabilityProjectionInvalid' } elseif ($failure -ceq 'LF-17') { 'DecisionConflict' } else { 'ConservationMismatch' }
        return New-C6DecisionFailure $failure $reason @($issues) $policyFingerprint $decisionFingerprint $historyFingerprint $inputFingerprint
    }

    foreach ($family in @($FamilyRegistry.families)) {
        $familyId = [string]$family.familyId
        $staticFamily = $staticFamilyById[$familyId]
        $members = @($MemberStaticQualification.memberResults | Where-Object familyId -CEQ $familyId)
        $memberFailureClasses = @($members | ForEach-Object actionableFailureClasses | ForEach-Object { $_ })
        $checkFailureClasses = @($members | ForEach-Object checkResults | Where-Object outcome -CEQ 'Failed' | ForEach-Object failureClasses | ForEach-Object { $_ })
        $memberInputs = @($members | ForEach-Object availableInputKinds | ForEach-Object { $_ })
        $checkInputs = @($members | ForEach-Object checkResults | ForEach-Object availableInputKinds | ForEach-Object { $_ })
        if (-not (Test-C6DecisionExactSet @($staticFamily.actionableFailureClasses) @(Get-C6DecisionOrdinalValues $memberFailureClasses -Unique)) -or
            -not (Test-C6DecisionExactSet @($staticFamily.actionableFailureClasses) @(Get-C6DecisionOrdinalValues $checkFailureClasses -Unique)) -or
            -not (Test-C6DecisionExactSet @($staticFamily.availableInputKinds) @(Get-C6DecisionOrdinalValues $memberInputs -Unique)) -or
            -not (Test-C6DecisionExactSet @($staticFamily.availableInputKinds) @(Get-C6DecisionOrdinalValues $checkInputs -Unique))) {
            return New-C6DecisionFailure 'LF-16' 'ConservationMismatch' @("LF-16:$familyId C4 typed projection mismatch.") $policyFingerprint $decisionFingerprint $historyFingerprint $inputFingerprint
        }
    }

    $familyDecisions = [Collections.Generic.List[object]]::new()
    foreach ($family in @(Get-C6DecisionOrdinalRows @($FamilyRegistry.families) 'familyId')) {
        $familyId = [string]$family.familyId
        $staticFamily = $staticFamilyById[$familyId]
        $policy = $laneByLane[[string]$family.lane]
        $failureClasses = @($staticFamily.actionableFailureClasses)
        $availableInputs = @($staticFamily.availableInputKinds)
        $riskAssessments = @($EvidenceAssessment.assessments | Where-Object familyId -CEQ $familyId)
        $acceptedRisk = @($riskAssessments | Where-Object assessmentStatus -CEQ 'EvidenceAccepted')
        $acceptedKinds = @(Get-C6DecisionOrdinalValues @($acceptedRisk | ForEach-Object acceptedEvidenceKinds | ForEach-Object { $_ }) -Unique)
        $acceptedIds = @(Get-C6DecisionOrdinalValues @($acceptedRisk | ForEach-Object assessmentId) -Unique)
        $decision = $null; $ruleId = $null; $repairClass = $null; $replacementRoute = $null

        if (@($DecisionPolicyRegistry.diagnosticOnlyFamilyKinds) -ccontains [string]$family.familyKindId) {
            $decision = 'DiagnosticOnly'; $ruleId = 'DiagnosticOnlyRule'
        }
        elseif (@($failureClasses | Where-Object { $_ -cin @($DecisionPolicyRegistry.hardStopFailureClasses) }).Count) {
            $decision = 'Stop'; $ruleId = 'HardStopRule'
        }
        elseif ($staticFamily.staticOutcome -ceq 'NeedsDiagnosis' -or
            ($staticFamily.staticOutcome -ceq 'StaticRejected' -and $failureClasses.Count -eq 0)) {
            $decision = 'NeedsDiagnosis'; $ruleId = 'NeedsDiagnosisRule'
        }
        else {
            $repairMatches = @($policy.repairRules | Where-Object {
                $_.applicableFamilyKinds -ccontains [string]$family.familyKindId -and
                $failureClasses.Count -gt 0 -and
                (Test-C6DecisionSubset $failureClasses @($_.requiredFailureClasses)) -and
                (Test-C6DecisionSubset @($_.requiredInputKinds) $availableInputs) -and
                -not $attemptPairs.Contains("$familyId|$($_.repairClass)")
            })
            if ($repairMatches.Count -gt 1) {
                return New-C6DecisionFailure 'LF-17' 'DecisionConflict' @("LF-17:$familyId multiple repair rules matched.") $policyFingerprint $decisionFingerprint $historyFingerprint $inputFingerprint
            }
            if ($repairMatches.Count -eq 1) {
                $decision = 'RepairOnce'; $ruleId = 'RepairOnceRule'; $repairClass = [string]$repairMatches[0].repairClass
            }
        }

        if ($null -eq $decision) {
            $replacementMatches = [Collections.Generic.List[object]]::new()
            foreach ($rule in @($DecisionPolicyRegistry.replacementRules)) {
                if ($rule.lane -cne [string]$family.lane -or $rule.familyKindIds -cnotcontains [string]$family.familyKindId -or
                    $failureClasses.Count -eq 0 -or -not (Test-C6DecisionSubset $failureClasses @($rule.requiredFailureClasses)) -or
                    -not (Test-C6DecisionSubset @($rule.requiredAcceptedEvidenceKinds) $acceptedKinds)) { continue }
                $checks = @($MemberStaticQualification.memberResults | Where-Object familyId -CEQ $familyId | ForEach-Object checkResults)
                $allChecksPassed = $true
                foreach ($checkId in @($rule.requiredStaticCheckIds)) {
                    $matches = @($checks | Where-Object checkId -CEQ $checkId)
                    if ($matches.Count -eq 0 -or @($matches | Where-Object outcome -CNE 'Passed').Count) { $allChecksPassed = $false; break }
                }
                if ($allChecksPassed) { $replacementMatches.Add($rule) }
            }
            if ($replacementMatches.Count -gt 1) {
                return New-C6DecisionFailure 'LF-17' 'DecisionConflict' @("LF-17:$familyId multiple replacement rules matched.") $policyFingerprint $decisionFingerprint $historyFingerprint $inputFingerprint
            }
            if ($replacementMatches.Count -eq 1) {
                $decision = 'PrototypeReplacement'; $ruleId = 'PrototypeReplacementRule'; $replacementRoute = [string]$replacementMatches[0].routeKind
            }
        }

        if ($null -eq $decision) {
            $memberIds = @($family.memberObjectIds)
            $unresolvedReferences = @($CrossLaneReferencePackage.rows | Where-Object {
                $_.fromAssetObjectId -cin $memberIds -and $_.resolutionStatus -cne 'Resolved'
            })
            $allRiskAccepted = $riskAssessments.Count -gt 0 -and @($riskAssessments | Where-Object assessmentStatus -CNE 'EvidenceAccepted').Count -eq 0
            if ($staticFamily.staticOutcome -ceq 'StaticQualified' -and $allRiskAccepted -and $unresolvedReferences.Count -eq 0) {
                $decision = 'UseOriginalAsset'; $ruleId = 'UseOriginalAssetRule'
            }
            elseif ($staticFamily.staticOutcome -ceq 'StaticQualified' -and
                @($riskAssessments | Where-Object assessmentStatus -CIn @('EvidenceMissing', 'EvidenceStale', 'UnityExecutionUnavailable')).Count) {
                $decision = 'RetainForLater'; $ruleId = 'RetainForLaterRule'
            }
            else {
                $decision = 'Stop'; $ruleId = 'TerminalStopRule'
            }
        }

        $route = if ($decision -ceq 'UseOriginalAsset') { 'OriginalAsset' } else { $replacementRoute }
        $familyDecisions.Add([pscustomobject][ordered]@{
            familyId = $familyId; decision = $decision; ruleId = $ruleId; repairClass = $repairClass
            replacementRouteKind = $replacementRoute; routeKind = $route
            acceptedEvidenceAssessmentIds = $acceptedIds; acceptedEvidenceKinds = $acceptedKinds
        })
    }

    $decisionByFamily = New-C6DecisionMap @($familyDecisions) 'familyId'
    $memberProjections = [Collections.Generic.List[object]]::new()
    foreach ($member in @(Get-C6DecisionOrdinalRows @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember') 'assetObjectId')) {
        $decision = $decisionByFamily[[string]$member.familyId]
        $static = $memberStaticById[[string]$member.assetObjectId]
        $poolStatus = 'Isolated'
        if ($decision.decision -ceq 'UseOriginalAsset' -and $static.staticStatus -ceq 'StaticPassed') {
            $poolStatus = 'AcceptedOriginalPool'
        }
        elseif ($decision.decision -ceq 'PrototypeReplacement' -and $static.staticStatus -ceq 'StaticPassed') {
            $poolStatus = 'AcceptedReplacementSourcePool'
        }
        $memberProjections.Add([pscustomobject][ordered]@{
            assetObjectId = $member.assetObjectId; familyId = $member.familyId
            disposition = $decision.decision; poolStatus = $poolStatus
        })
    }

    $capabilityResults = [Collections.Generic.List[object]]::new()
    foreach ($capability in @(Get-C6DecisionOrdinalRows @($DecisionPolicyRegistry.capabilities) 'capabilityId')) {
        $requirements = @($RepresentativeRequirements.capabilitySuitabilityRequirements | Where-Object capabilityId -CEQ $capability.capabilityId)
        $assessmentByRequirement = New-C6DecisionMap @($EvidenceAssessment.capabilitySuitabilityAssessments | Where-Object capabilityId -CEQ $capability.capabilityId) 'suitabilityRequirementId'
        $satisfyingFamilies = [Collections.Generic.List[string]]::new()
        $routes = [Collections.Generic.List[string]]::new()
        $suitabilityIds = [Collections.Generic.List[string]]::new()
        foreach ($requirement in $requirements) {
            $assessment = $assessmentByRequirement[[string]$requirement.suitabilityRequirementId]
            $familyDecision = $decisionByFamily[[string]$requirement.familyId]
            if ($null -ne $assessment -and $assessment.assessmentStatus -ceq 'SuitabilityAccepted' -and
                $familyDecision.decision -cin @($capability.allowedFamilyDecisions) -and
                $familyDecision.routeKind -ceq [string]$requirement.routeKind -and
                (Test-C6DecisionSubset @($capability.requiredAcceptedEvidenceKinds) @($familyDecision.acceptedEvidenceKinds))) {
                $satisfyingFamilies.Add([string]$requirement.familyId)
                $routes.Add([string]$requirement.routeKind)
                $suitabilityIds.Add([string]$assessment.suitabilityAssessmentId)
            }
        }
        if ($satisfyingFamilies.Count) {
            $status = 'Satisfied'
        }
        elseif ($requirements.Count -eq 0 -or
            @($requirements | Where-Object {
                $assessmentByRequirement[[string]$_.suitabilityRequirementId].assessmentStatus -cne 'SuitabilityRejected' -and
                $decisionByFamily[[string]$_.familyId].decision -cnotin @('DiagnosticOnly', 'Stop')
            }).Count -eq 0) {
            $status = 'Unsatisfied'
        }
        else {
            $status = 'Blocked'
        }
        $capabilityResults.Add([pscustomobject][ordered]@{
            capabilityId = $capability.capabilityId; status = $status
            satisfyingFamilyIds = @(Get-C6DecisionOrdinalValues @($satisfyingFamilies) -Unique)
            routeKinds = @(Get-C6DecisionOrdinalValues @($routes) -Unique)
            suitabilityAssessmentIds = @(Get-C6DecisionOrdinalValues @($suitabilityIds) -Unique)
        })
    }

    $familyArray = @($familyDecisions)
    $capabilityArray = @($capabilityResults)
    [pscustomobject][ordered]@{
        status = 'Passed'; failureId = $null; reasonCode = $null; issues = @()
        policySetFingerprint = $policyFingerprint; decisionPolicyFingerprint = $decisionFingerprint
        repairHistoryFingerprint = $historyFingerprint; inputFingerprint = $inputFingerprint
        familyDecisions = $familyArray; memberProjections = @($memberProjections); capabilityResults = $capabilityArray
        totalFamilyCount = $familyArray.Count
        needsDiagnosisFamilyCount = @($familyArray | Where-Object decision -CEQ 'NeedsDiagnosis').Count
        useOriginalAssetFamilyCount = @($familyArray | Where-Object decision -CEQ 'UseOriginalAsset').Count
        repairOnceFamilyCount = @($familyArray | Where-Object decision -CEQ 'RepairOnce').Count
        prototypeReplacementFamilyCount = @($familyArray | Where-Object decision -CEQ 'PrototypeReplacement').Count
        retainForLaterFamilyCount = @($familyArray | Where-Object decision -CEQ 'RetainForLater').Count
        diagnosticOnlyFamilyCount = @($familyArray | Where-Object decision -CEQ 'DiagnosticOnly').Count
        stopFamilyCount = @($familyArray | Where-Object decision -CEQ 'Stop').Count
        requiredCapabilityCount = $capabilityArray.Count
        satisfiedCapabilityCount = @($capabilityArray | Where-Object status -CEQ 'Satisfied').Count
        unsatisfiedCapabilityCount = @($capabilityArray | Where-Object status -CEQ 'Unsatisfied').Count
        blockedCapabilityCount = @($capabilityArray | Where-Object status -CEQ 'Blocked').Count
        executorLaunchCount = 0; heavyOperationCount = 0
    }
}

Export-ModuleMember -Function Invoke-C6AuthoringDecisionKernel
