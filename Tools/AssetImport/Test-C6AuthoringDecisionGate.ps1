[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$modulePath = Join-Path $PSScriptRoot 'C6AuthoringDecisionGate.psm1'
$module = Import-Module $modulePath -Force -PassThru
if ($module.ExportedFunctions.Keys -cnotcontains 'Invoke-C6AuthoringDecisionKernel') {
    throw 'C6-0 pure decision entry point is missing.'
}
$moduleAst = [Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$null, [ref]$null)
if (@($moduleAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Sort-Object' }, $true)).Count) {
    throw 'C6 decision module uses culture-sensitive Sort-Object.'
}

function Read-Fixture([string]$Name) {
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$Name") |
        ConvertFrom-Json -Depth 100 -DateKind String
}
function Clone-Value($Value) {
    $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String
}
function Canonical-Json($Value) {
    (($Value | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
}
function Get-Sha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($Text))).ToLowerInvariant()
}
function Get-OrdinalRows([object[]]$Rows, [string]$Property) {
    $array = [object[]]@($Rows)
    [Array]::Sort($array, [Collections.Generic.Comparer[object]]::Create(
        [Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare([string]$left.$Property, [string]$right.$Property) }
    ))
    @($array)
}
function Scalar([string]$Name, [string]$Value) {
    "${Name}:$([Text.Encoding]::UTF8.GetByteCount($Value)):${Value}`n"
}
function Nullable([string]$Name, $Value) {
    if ($null -eq $Value) { return "${Name}:null`n" }
    Scalar $Name ([string]$Value)
}
function Set-Frame([string]$Name, [object[]]$Values) {
    $ordered = [string[]]@($Values)
    [Array]::Sort($ordered, [StringComparer]::Ordinal)
    $count = [string]$ordered.Count
    $text = "${Name}.count:$([Text.Encoding]::UTF8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $text += Scalar "${Name}[$index]" $ordered[$index]
    }
    $text
}
function Get-RepairAttemptId($Attempt) {
    $text = "C6RepairAttemptV1`n"
    $text += Scalar familyId $Attempt.familyId
    $text += Scalar repairClass $Attempt.repairClass
    $text += Scalar attemptNumber ([string]$Attempt.attemptNumber)
    $text += Scalar inputFingerprint $Attempt.inputFingerprint
    $text += Nullable outputFingerprint $Attempt.outputFingerprint
    $text += Scalar expectedChangeMeasure $Attempt.expectedChangeMeasure
    $text += Nullable observedChange $Attempt.observedChange
    $text += Scalar outcome $Attempt.outcome
    $text += Set-Frame evidence @($Attempt.evidence)
    "repair-attempt-sha256:$(Get-Sha256 $text)"
}

$familyRegistry = Read-Fixture 'valid-family-registry.json'
$memberLedger = Read-Fixture 'valid-family-member-ledger.json'
$references = Read-Fixture 'valid-cross-lane-reference-package.json'
$memberStatic = Read-Fixture 'valid-member-static-qualification.json'
$familyStatic = Read-Fixture 'valid-family-static-summary.json'
$requirements = Read-Fixture 'valid-representative-requirements.json'
$assessments = Read-Fixture 'valid-evidence-assessment.json'
$lanePolicyPath = Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
$decisionPolicyPath = Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-decision-policy-registry.json'
$vocabularyPath = Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json'
$historyPath = Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/repair-attempt-history.json'
$lanePolicyBytes = [IO.File]::ReadAllText($lanePolicyPath, [Text.UTF8Encoding]::new($false))
$decisionPolicyBytes = [IO.File]::ReadAllText($decisionPolicyPath, [Text.UTF8Encoding]::new($false))
$vocabularyBytes = [IO.File]::ReadAllText($vocabularyPath, [Text.UTF8Encoding]::new($false))
$historyBytes = [IO.File]::ReadAllText($historyPath, [Text.UTF8Encoding]::new($false))
$lanePolicy = $lanePolicyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$decisionPolicy = $decisionPolicyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary = $vocabularyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$history = $historyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$script:C6TestBaseHistory = $history
$script:C6TestBaseHistoryBytes = $historyBytes

$directInputSpecs = [ordered]@{
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
function Get-StageInputFingerprint([object[]]$Entries) {
    $ordered = @(Get-OrdinalRows $Entries 'path')
    $count = [string]$ordered.Count
    $text = "LifecycleStageInputV1`nentries.count:$([Text.Encoding]::UTF8.GetByteCount($count)):$count`n"
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $nested = "C2ArtifactEntryV1`n"
        $nested += Scalar path ([string]$ordered[$index].path)
        $nested += Scalar sha256 ([string]$ordered[$index].sha256)
        $text += "entries[$index]:$([Text.Encoding]::UTF8.GetByteCount($nested)):$nested`n"
    }
    Get-Sha256 $text
}
function New-ExecutionArtifacts(
    $FamilyRegistry,
    $MemberLedger,
    $References,
    $MemberStatic,
    $FamilyStatic,
    $Requirements,
    $Assessments
) {
    @(
        [pscustomobject][ordered]@{ artifactId = 'C3-O01'; bytes = Canonical-Json $FamilyRegistry }
        [pscustomobject][ordered]@{ artifactId = 'C3-O02'; bytes = Canonical-Json $MemberLedger }
        [pscustomobject][ordered]@{ artifactId = 'C3-O03'; bytes = Canonical-Json $References }
        [pscustomobject][ordered]@{ artifactId = 'C4-O01'; bytes = Canonical-Json $MemberStatic }
        [pscustomobject][ordered]@{ artifactId = 'C4-O02'; bytes = Canonical-Json $FamilyStatic }
        [pscustomobject][ordered]@{ artifactId = 'C5-O01'; bytes = Canonical-Json $Requirements }
        [pscustomobject][ordered]@{ artifactId = 'C5-O02'; bytes = Canonical-Json $Assessments }
    )
}
function New-DirectInputs($HistoryText, [object[]]$ExecutionArtifacts) {
    $executionById = @{}
    foreach ($artifact in $ExecutionArtifacts) { $executionById[[string]$artifact.artifactId] = [string]$artifact.bytes }
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($entry in $directInputSpecs.GetEnumerator()) {
        $sha = if ($entry.Key -ceq 'LC-I12') { Get-Sha256 $HistoryText } else {
            if ($executionById.ContainsKey([string]$entry.Key)) {
                Get-Sha256 $executionById[[string]$entry.Key]
            }
            else {
                (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $repositoryRoot $entry.Value)).Hash.ToLowerInvariant()
            }
        }
        $rows.Add([pscustomobject][ordered]@{ artifactId = [string]$entry.Key; path = [string]$entry.Value; sha256 = $sha })
    }
    @(Get-OrdinalRows $rows.ToArray() 'path')
}

function Run-Kernel(
    $FamilyRegistry = $familyRegistry,
    $MemberLedger = $memberLedger,
    $References = $references,
    $MemberStatic = $memberStatic,
    $FamilyStatic = $familyStatic,
    $Requirements = $requirements,
    $Assessments = $assessments,
    $LanePolicy = $lanePolicy,
    [string]$LaneBytes = $lanePolicyBytes,
    $DecisionPolicy = $decisionPolicy,
    [string]$DecisionBytes = $decisionPolicyBytes,
    $Vocabulary = $vocabulary,
    [string]$VocabularyText = $vocabularyBytes,
    $History = $null,
    [string]$HistoryText = '',
    $ExecutionArtifacts = $null,
    $DirectInputs = $null
) {
    if ($null -eq $ExecutionArtifacts) {
        $ExecutionArtifacts = New-ExecutionArtifacts $FamilyRegistry $MemberLedger $References $MemberStatic $FamilyStatic $Requirements $Assessments
    }
    $historyWasSupplied = $null -ne $History
    $historyTextWasSupplied = -not [string]::IsNullOrEmpty($HistoryText)
    if (-not $historyWasSupplied) { $History = Clone-Value $script:C6TestBaseHistory }
    if (-not $historyTextWasSupplied) { $HistoryText = $script:C6TestBaseHistoryBytes }
    if ($null -eq $DirectInputs) {
        $DirectInputs = New-DirectInputs $HistoryText $ExecutionArtifacts
        if (-not $historyWasSupplied -and -not $historyTextWasSupplied) {
            $History.inputFingerprint = Get-StageInputFingerprint @($DirectInputs | Where-Object artifactId -CNE 'LC-I12')
            $HistoryText = Canonical-Json $History
            $DirectInputs = New-DirectInputs $HistoryText $ExecutionArtifacts
        }
    }
    Invoke-C6AuthoringDecisionKernel `
        -FamilyRegistry $FamilyRegistry `
        -FamilyMemberLedger $MemberLedger `
        -CrossLaneReferencePackage $References `
        -MemberStaticQualification $MemberStatic `
        -FamilyStaticSummary $FamilyStatic `
        -RepresentativeRequirements $Requirements `
        -EvidenceAssessment $Assessments `
        -LanePolicyRegistry $LanePolicy `
        -LanePolicyBytes $LaneBytes `
        -DecisionPolicyRegistry $DecisionPolicy `
        -DecisionPolicyBytes $DecisionBytes `
        -StatusVocabulary $Vocabulary `
        -StatusVocabularyBytes $VocabularyText `
        -RepairAttemptHistory $History `
        -RepairAttemptHistoryBytes $HistoryText `
        -ExecutionArtifacts $ExecutionArtifacts `
        -DirectInputs $DirectInputs
}

$baseExecutionArtifacts = New-ExecutionArtifacts $familyRegistry $memberLedger $references $memberStatic $familyStatic $requirements $assessments
$baseDirectInputs = New-DirectInputs $historyBytes $baseExecutionArtifacts
$history.inputFingerprint = Get-StageInputFingerprint @($baseDirectInputs | Where-Object artifactId -CNE 'LC-I12')
$historyBytes = Canonical-Json $history
$script:C6TestBaseHistory = $history
$script:C6TestBaseHistoryBytes = $historyBytes

$result = Run-Kernel
if ($result.status -cne 'Passed') { throw "C6-0 positive result failed: $($result.issues -join '; ')" }
$shape = 'status,failureId,reasonCode,issues,policySetFingerprint,decisionPolicyFingerprint,repairHistoryFingerprint,inputFingerprint,familyDecisions,memberProjections,capabilityResults,totalFamilyCount,needsDiagnosisFamilyCount,useOriginalAssetFamilyCount,repairOnceFamilyCount,prototypeReplacementFamilyCount,retainForLaterFamilyCount,diagnosticOnlyFamilyCount,stopFamilyCount,requiredCapabilityCount,satisfiedCapabilityCount,unsatisfiedCapabilityCount,blockedCapabilityCount,executorLaunchCount,heavyOperationCount'
if ((@($result.PSObject.Properties.Name) -join ',') -cne $shape) { throw 'C6-0 result shape failed.' }
if ($result.totalFamilyCount -ne 5 -or $result.needsDiagnosisFamilyCount -ne 1 -or $result.repairOnceFamilyCount -ne 1 -or
    $result.retainForLaterFamilyCount -ne 3 -or $result.useOriginalAssetFamilyCount -ne 0 -or
    $result.prototypeReplacementFamilyCount -ne 0 -or $result.diagnosticOnlyFamilyCount -ne 0 -or $result.stopFamilyCount -ne 0) {
    throw 'SP-60 base family decision partition failed.'
}
if ($result.requiredCapabilityCount -ne 7 -or $result.satisfiedCapabilityCount -ne 0 -or
    $result.unsatisfiedCapabilityCount -ne 1 -or $result.blockedCapabilityCount -ne 6) {
    throw 'SP-61 base capability partition failed.'
}
if (@($result.memberProjections).Count -ne 5 -or @($result.memberProjections | Where-Object poolStatus -CEQ 'Isolated').Count -ne 5) {
    throw 'C6-0 authoringPoolStatus projection failed.'
}
$environmentFamily = @($familyRegistry.families | Where-Object lane -CEQ 'Environment')[0]
$environmentDecision = @($result.familyDecisions | Where-Object familyId -CEQ $environmentFamily.familyId)[0]
if ($environmentDecision.decision -cne 'RepairOnce' -or $environmentDecision.ruleId -cne 'RepairOnceRule' -or
    $environmentDecision.repairClass -cne 'ImportSettingsRepair') {
    throw 'C6 RepairOnce rule did not consume typed C4 failure/input projection.'
}
$actorDecision = @($result.familyDecisions | Where-Object { $_.familyId -ceq (@($familyRegistry.families | Where-Object lane -CEQ 'Actor')[0].familyId) })[0]
if ($actorDecision.decision -cne 'NeedsDiagnosis' -or $actorDecision.ruleId -cne 'NeedsDiagnosisRule') {
    throw 'C6 NeedsDiagnosis precedence failed.'
}

$attemptHistory = Clone-Value $history
$attempt = [pscustomobject][ordered]@{
    attemptId = 'repair-attempt-sha256:' + ('0' * 64)
    familyId = $environmentFamily.familyId
    repairClass = 'ImportSettingsRepair'
    attemptNumber = 1
    inputFingerprint = $history.inputFingerprint
    outputFingerprint = ('a' * 64)
    expectedChangeMeasure = 'FailedCheckCount'
    observedChange = 0
    outcome = 'NoImprovement'
    evidence = @('Tools/AssetImport/Test-C6AuthoringDecisionGate.ps1')
}
$attempt.attemptId = Get-RepairAttemptId $attempt
$attemptHistory.attempts = @($attempt)
$attemptHistoryText = Canonical-Json $attemptHistory
$afterAttempt = Run-Kernel -History $attemptHistory -HistoryText $attemptHistoryText
if ($afterAttempt.status -cne 'Passed') { throw "Valid LC-I12 attempt was rejected: $($afterAttempt.issues -join '; ')" }
$afterAttemptEnvironment = @($afterAttempt.familyDecisions | Where-Object familyId -CEQ $environmentFamily.familyId)[0]
if ($afterAttemptEnvironment.decision -ceq 'RepairOnce' -or $afterAttemptEnvironment.decision -cne 'Stop') {
    throw 'LC-I12 attempt did not consume the one allowed RepairOnce.'
}

$hardStopMember = Clone-Value $memberStatic
$hardStopFamily = Clone-Value $familyStatic
$failedMember = @($hardStopMember.memberResults | Where-Object familyId -CEQ $environmentFamily.familyId)[0]
$failedMember.actionableFailureClasses = @('CoreDataMissing')
@($failedMember.checkResults | Where-Object outcome -CEQ 'Failed')[0].failureClasses = @('CoreDataMissing')
@($hardStopFamily.families | Where-Object familyId -CEQ $environmentFamily.familyId)[0].actionableFailureClasses = @('CoreDataMissing')
$hardStop = Run-Kernel -MemberStatic $hardStopMember -FamilyStatic $hardStopFamily
$hardStopDecision = @($hardStop.familyDecisions | Where-Object familyId -CEQ $environmentFamily.familyId)[0]
if ($hardStop.status -cne 'Passed' -or $hardStopDecision.decision -cne 'Stop' -or $hardStopDecision.ruleId -cne 'HardStopRule') {
    throw 'HardStopRule did not precede repair evaluation.'
}

$suitabilityRejectedRequirements = Clone-Value $requirements
$suitabilityRejectedAssessments = Clone-Value $assessments
foreach ($row in @($suitabilityRejectedRequirements.capabilitySuitabilityRequirements | Where-Object capabilityId -CEQ 'PlayableBgmRoute')) {
    $row.assessmentStatus = 'SuitabilityRejected'
    $assessment = @($suitabilityRejectedAssessments.capabilitySuitabilityAssessments | Where-Object suitabilityRequirementId -CEQ $row.suitabilityRequirementId)[0]
    $assessment.assessmentStatus = 'SuitabilityRejected'
    $assessment.failureAttribution = "LF-14:$($row.suitabilityRequirementId)"
    $assessment.nextAllowedAction = 'Reject only this exact capability and route.'
}
$suitabilityRejected = Run-Kernel -Requirements $suitabilityRejectedRequirements -Assessments $suitabilityRejectedAssessments
$audioFamilyId = @($familyRegistry.families | Where-Object lane -CEQ 'Audio')[0].familyId
$baseAudioDecision = @($result.familyDecisions | Where-Object familyId -CEQ $audioFamilyId)[0]
$rejectedAudioDecision = @($suitabilityRejected.familyDecisions | Where-Object familyId -CEQ $audioFamilyId)[0]
$bgmCapability = @($suitabilityRejected.capabilityResults | Where-Object capabilityId -CEQ 'PlayableBgmRoute')[0]
$combatCapability = @($suitabilityRejected.capabilityResults | Where-Object capabilityId -CEQ 'PlayableCombatSfx')[0]
if ($suitabilityRejected.status -cne 'Passed' -or $rejectedAudioDecision.decision -cne $baseAudioDecision.decision -or
    $bgmCapability.status -cne 'Unsatisfied' -or $combatCapability.status -cne 'Blocked') {
    throw 'SP-51 suitability changed the family decision or crossed capability identity.'
}

$acceptedRequirements = Clone-Value $requirements
$acceptedAssessments = Clone-Value $assessments
foreach ($row in @($acceptedRequirements.requirements | Where-Object familyId -CEQ $audioFamilyId)) {
    $row.assessmentStatus = 'EvidenceAccepted'
    $assessment = @($acceptedAssessments.assessments | Where-Object requirementId -CEQ $row.requirementId)[0]
    $assessment.assessmentStatus = 'EvidenceAccepted'
    $assessment.evidencePackageId = "evidence-package-sha256:$((Get-Sha256 $row.requirementId))"
    $assessment.observedInputFingerprint = $assessment.expectedInputFingerprint
    $assessment.acceptedEvidenceKinds = @($row.requiredEvidenceKinds)
    $assessment.missingEvidenceKinds = @()
    $assessment.failureAttribution = $null
    $assessment.nextAllowedAction = 'Proceed with accepted evidence.'
}
foreach ($row in @($acceptedRequirements.capabilitySuitabilityRequirements | Where-Object { $_.familyId -ceq $audioFamilyId -and $_.routeKind -ceq 'OriginalAsset' })) {
    $row.assessmentStatus = 'SuitabilityAccepted'
    $assessment = @($acceptedAssessments.capabilitySuitabilityAssessments | Where-Object suitabilityRequirementId -CEQ $row.suitabilityRequirementId)[0]
    $assessment.assessmentStatus = 'SuitabilityAccepted'
    $assessment.evidencePackageId = "evidence-package-sha256:$((Get-Sha256 $row.suitabilityRequirementId))"
    $assessment.observedInputFingerprint = $assessment.expectedInputFingerprint
    $assessment.failureAttribution = $null
    $assessment.nextAllowedAction = 'Proceed with exact capability and route.'
}
$acceptedAudio = Run-Kernel -Requirements $acceptedRequirements -Assessments $acceptedAssessments
$acceptedAudioDecision = @($acceptedAudio.familyDecisions | Where-Object familyId -CEQ $audioFamilyId)[0]
$acceptedAudioMember = @($acceptedAudio.memberProjections | Where-Object familyId -CEQ $audioFamilyId)[0]
if ($acceptedAudio.status -cne 'Passed' -or $acceptedAudioDecision.decision -cne 'UseOriginalAsset' -or
    $acceptedAudioDecision.ruleId -cne 'UseOriginalAssetRule' -or $acceptedAudioMember.poolStatus -cne 'AcceptedOriginalPool' -or
    @($acceptedAudio.capabilityResults | Where-Object { $_.capabilityId -cin @('PlayableBgmRoute', 'PlayableCombatSfx') -and $_.status -ceq 'Satisfied' }).Count -ne 2) {
    throw 'UseOriginalAsset or exact Audio capability satisfaction failed.'
}

$unboundLanePolicy = Clone-Value $lanePolicy
$unboundLanePolicy.policySetVersion = '9.9.9'
if ((Run-Kernel -LanePolicy $unboundLanePolicy).status -cne 'Failed') { throw 'LC-I07 object/bytes mismatch did not fail closed.' }
$unboundDecisionPolicy = Clone-Value $decisionPolicy
$unboundDecisionPolicy.decisionPolicyVersion = '9.9.9'
if ((Run-Kernel -DecisionPolicy $unboundDecisionPolicy).status -cne 'Failed') { throw 'LC-I11 object/bytes mismatch did not fail closed.' }
$unboundHistory = Clone-Value $history
$unboundHistory.generatedAt = '2026-07-16T08:00:01Z'
if ((Run-Kernel -History $unboundHistory).status -cne 'Failed') { throw 'LC-I12 object/bytes mismatch did not fail closed.' }
$wrongHistoryFingerprint = Clone-Value $history
$wrongHistoryFingerprint.inputFingerprint = ('0' * 64)
$wrongHistoryText = Canonical-Json $wrongHistoryFingerprint
if ((Run-Kernel -History $wrongHistoryFingerprint -HistoryText $wrongHistoryText).status -cne 'Failed') { throw 'LC-I12 input freshness mismatch did not fail closed.' }
$baseExecutionArtifacts = New-ExecutionArtifacts $familyRegistry $memberLedger $references $memberStatic $familyStatic $requirements $assessments
$misorderedInputs = @(New-DirectInputs $historyBytes $baseExecutionArtifacts)
$swap = $misorderedInputs[0]; $misorderedInputs[0] = $misorderedInputs[1]; $misorderedInputs[1] = $swap
if ((Run-Kernel -ExecutionArtifacts $baseExecutionArtifacts -DirectInputs $misorderedInputs).status -cne 'Failed') { throw 'C6 misordered direct inputs did not fail closed.' }
$unboundFamilyRegistry = Clone-Value $familyRegistry
$unboundFamilyRegistry.snapshotId = 'snapshot-unbound'
$unboundChildResult = Run-Kernel -FamilyRegistry $unboundFamilyRegistry -ExecutionArtifacts $baseExecutionArtifacts -DirectInputs (New-DirectInputs $historyBytes $baseExecutionArtifacts)
if ($unboundChildResult.status -cne 'Failed' -or
    $unboundChildResult.issues -cnotcontains 'C6 execution object/bytes binding failed for C3-O01.') {
    throw 'C3-O01 object/bytes mismatch did not fail closed.'
}
$misorderedAttemptHistory = Clone-Value $attemptHistory
$misorderedAttemptHistory.attempts[0].evidence = @('z-evidence', 'a-evidence')
$misorderedAttemptHistory.attempts[0].attemptId = Get-RepairAttemptId $misorderedAttemptHistory.attempts[0]
$misorderedAttemptText = Canonical-Json $misorderedAttemptHistory
if ((Run-Kernel -History $misorderedAttemptHistory -HistoryText $misorderedAttemptText).status -cne 'Failed') { throw 'LC-I12 misordered evidence did not fail closed.' }
$badVocabulary = Clone-Value $vocabulary
$badVocabulary.capabilityStatus = @('Satisfied', 'Blocked', 'Unsatisfied')
$badVocabularyText = Canonical-Json $badVocabulary
if ((Run-Kernel -Vocabulary $badVocabulary -VocabularyText $badVocabularyText).status -cne 'Failed') { throw 'C6 capabilityStatus vocabulary order did not fail closed.' }

if ($result.executorLaunchCount -ne 0 -or $result.heavyOperationCount -ne 0) {
    throw 'C6-0 attempted Unity, C7/G4, extraction, import, or another heavy operation.'
}

"status=Passed"
"familyPartition=$($result.needsDiagnosisFamilyCount)/$($result.useOriginalAssetFamilyCount)/$($result.repairOnceFamilyCount)/$($result.prototypeReplacementFamilyCount)/$($result.retainForLaterFamilyCount)/$($result.diagnosticOnlyFamilyCount)/$($result.stopFamilyCount)"
"capabilityPartition=$($result.satisfiedCapabilityCount)/$($result.unsatisfiedCapabilityCount)/$($result.blockedCapabilityCount)"
"repairHistoryFingerprint=$($result.repairHistoryFingerprint)"
"executorLaunchCount=$($result.executorLaunchCount)"
"heavyOperationCount=$($result.heavyOperationCount)"
