[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1') -Force -PassThru
$moduleAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1'),[ref]$null,[ref]$null)
if(@($moduleAst.FindAll({param($node)$node-is[Management.Automation.Language.CommandAst]-and$node.GetCommandName()-ceq'Sort-Object'},$true)).Count){throw 'C4 module reintroduced culture-sensitive Sort-Object.'}
$policyBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'),[Text.UTF8Encoding]::new($false))
$policy = $policyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$vocabularyBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json'),[Text.UTF8Encoding]::new($false))
$vocabulary = $vocabularyBytes | ConvertFrom-Json -Depth 100 -DateKind String
$factSchemaBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'docs/asset-migration/schemas/c2-lane-fact-package.schema.json'),[Text.UTF8Encoding]::new($false))
$familyRegistryBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json'),[Text.UTF8Encoding]::new($false))
$familyRegistry = $familyRegistryBytes | ConvertFrom-Json -Depth 100 -DateKind String
$memberLedgerBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json'),[Text.UTF8Encoding]::new($false))
$memberLedger = $memberLedgerBytes | ConvertFrom-Json -Depth 100 -DateKind String
$crossLaneReferenceBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json'),[Text.UTF8Encoding]::new($false))
$crossLaneReferences = $crossLaneReferenceBytes | ConvertFrom-Json -Depth 100 -DateKind String
$c3SummaryBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json'),[Text.UTF8Encoding]::new($false))
$c3ReportBytes = [IO.File]::ReadAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'),[Text.UTF8Encoding]::new($false))

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function Get-FixtureFingerprint([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function Get-TestSha256([string]$Text) { (Get-FixtureFingerprint $Text).Substring(7) }
function ConvertTo-TestJson($Value) { $Value | ConvertTo-Json -Depth 100 -Compress }
function ConvertTo-TestCanonicalJson($Value) { (($Value | ConvertTo-Json -Depth 100) -replace "`r`n","`n") + "`n" }
function Get-TestOrdinalRows([object[]]$Rows,[string[]]$Properties) {
    $list=[Collections.Generic.List[object]]::new();foreach($row in $Rows){$list.Add($row)}
    $list.Sort([Comparison[object]]{param($left,$right)foreach($property in $Properties){$comparison=[StringComparer]::Ordinal.Compare([string]$left.$property,[string]$right.$property);if($comparison){return $comparison}};0})
    [object[]]$list.ToArray()
}
function ConvertTo-TestScalar([string]$Name,[string]$Value) { "${Name}:$([Text.UTF8Encoding]::new($false).GetByteCount($Value)):${Value}`n" }
function Get-TestStageInputFingerprint([object[]]$Entries) {
    $ordered=@(Get-TestOrdinalRows $Entries @('path'));$countText=[string]$ordered.Count;$text="LifecycleStageInputV1`nentries.count:$([Text.UTF8Encoding]::new($false).GetByteCount($countText)):$countText`n"
    for($index=0;$index-lt$ordered.Count;$index++){
        $nested="C2ArtifactEntryV1`n"
        $nested+=ConvertTo-TestScalar artifactId ([string]$ordered[$index].artifactId)
        $nested+=ConvertTo-TestScalar path ([string]$ordered[$index].path)
        $nested+=ConvertTo-TestScalar sha256 ([string]$ordered[$index].sha256)
        $text+="entries[$index]:$([Text.UTF8Encoding]::new($false).GetByteCount($nested)):$nested`n"
    }
    Get-TestSha256 $text
}

$assigned = @($memberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember')
$facts = [Collections.Generic.List[object]]::new()
$observations = [Collections.Generic.List[object]]::new()
foreach ($member in $assigned) {
    $lanePolicy = @($policy.policies | Where-Object lane -CEQ $member.lane)[0]
    foreach ($definition in @($lanePolicy.factDefinitions)) {
        $facts.Add([pscustomobject][ordered]@{
            assetObjectId = [string]$member.assetObjectId
            lane = [string]$member.lane
            factKind = [string]$definition.factKind
            factStatus = 'Known'
        })
    }
    foreach ($check in @($lanePolicy.staticCheckDefinitions)) {
        $outcome = 'Passed'; $reasonCode = 'None'
        if ($member.lane -ceq 'Environment' -and $check.checkId -ceq 'ColliderValidity') {
            $outcome = 'Failed'; $reasonCode = 'PolicyViolation'
        }
        elseif ($member.lane -ceq 'Actor' -and $check.checkId -ceq 'AnimationClipReadability') {
            $outcome = 'Unchecked'; $reasonCode = 'ToolUnavailable'
        }
        $failureClasses = [string[]]@(if ($outcome -ceq 'Failed') { 'ImportSettingMismatch' })
        $observations.Add([pscustomobject][ordered]@{
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            checkId = [string]$check.checkId
            outcome = $outcome
            reasonCode = $reasonCode
            observedFingerprint = if ($outcome -ceq 'Passed') { Get-TestSha256 "$($member.assetObjectId)|$($check.checkId)|fixture-evidence" } else { $null }
            failureClasses = $failureClasses
            evidenceKinds = @($check.requiredEvidenceKinds)
            evidence = @('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')
        })
    }
}

$directInputPaths=[ordered]@{
    'C3-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json'
    'C3-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json'
    'C3-O03'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json'
    'C3-O04-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json'
    'C3-O04-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
    'LC-I01'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'
    'LC-I02'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json'
    'LC-I03'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json'
    'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json'
    'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
    'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json'
    'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
    'LC-I14'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-static-observation-package.json'
}
function New-C4StaticObservationPackage($Rows) {
    [pscustomobject][ordered]@{
        schemaVersion='1.0.0'
        generatedAt='2026-07-16T03:30:00Z'
        snapshotId='snapshot-pc-install-001'
        rows=@(Get-TestOrdinalRows @($Rows) @('assetObjectId','checkId'))
    }
}
function New-C4ExecutionArtifacts(
    $FactRows=$facts,
    $ObservationRows=$observations,
    $FamilyRegistry=$familyRegistry,
    $MemberLedger=$memberLedger,
    $References=$crossLaneReferences,
    $LanePolicy=$policy,
    [string]$LaneBytes=$policyBytes,
    $Vocabulary=$vocabulary,
    [string]$VocabularyText=$vocabularyBytes
) {
    $staticPackage=New-C4StaticObservationPackage $ObservationRows
    [object[]]@(
        [pscustomobject][ordered]@{artifactId='C3-O01';bytes=ConvertTo-TestCanonicalJson $FamilyRegistry}
        [pscustomobject][ordered]@{artifactId='C3-O02';bytes=ConvertTo-TestCanonicalJson $MemberLedger}
        [pscustomobject][ordered]@{artifactId='C3-O03';bytes=ConvertTo-TestCanonicalJson $References}
        [pscustomobject][ordered]@{artifactId='C3-O04-Summary';bytes=$c3SummaryBytes}
        [pscustomobject][ordered]@{artifactId='C3-O04-Report';bytes=$c3ReportBytes}
        [pscustomobject][ordered]@{artifactId='LC-I01';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId='snapshot-pc-install-001';generatedAt='2026-07-16T02:00:00Z';inputFingerprint=('1'*64);toolVersions=@();sources=@();files=@();objects=@()})}
        [pscustomobject][ordered]@{artifactId='LC-I02';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);discoveryInputFingerprint=('2'*64);configurationCandidates=@();configurationConflicts=@()})}
        [pscustomobject][ordered]@{artifactId='LC-I03';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';inputFingerprint=('1'*64);discoveryInputFingerprint=('2'*64);canonicalGroups=@();canonicalConflicts=@()})}
        [pscustomobject][ordered]@{artifactId='LC-I06';bytes=ConvertTo-TestJson ([pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt='2026-07-16T02:00:00Z';snapshotId='snapshot-pc-install-001';c2GenerationFingerprint=('3'*64);factContractFingerprint=Get-TestSha256 $factSchemaBytes;inputFingerprint=('4'*64);rows=@($FactRows)})}
        [pscustomobject][ordered]@{artifactId='LC-I07';bytes=$LaneBytes}
        [pscustomobject][ordered]@{artifactId='LC-I08';bytes=$VocabularyText}
        [pscustomobject][ordered]@{artifactId='LC-I13';bytes=$factSchemaBytes}
        [pscustomobject][ordered]@{artifactId='LC-I14';bytes=ConvertTo-TestCanonicalJson $staticPackage}
    )
}
function New-C4DirectInputs([object[]]$ExecutionArtifacts) {
    $rows=[Collections.Generic.List[object]]::new()
    foreach($artifact in $ExecutionArtifacts){$rows.Add([pscustomobject][ordered]@{artifactId=[string]$artifact.artifactId;path=[string]$directInputPaths[[string]$artifact.artifactId];sha256=Get-TestSha256 ([string]$artifact.bytes)})}
    [object[]](Get-TestOrdinalRows $rows.ToArray() @('path'))
}
function Invoke-TestGate(
    $FactRows=$facts,
    $ObservationRows=$observations,
    $FamilyRegistry=$familyRegistry,
    $MemberLedger=$memberLedger,
    $References=$crossLaneReferences,
    $LanePolicy=$policy,
    [string]$LaneBytes=$policyBytes,
    $Vocabulary=$vocabulary,
    [string]$VocabularyText=$vocabularyBytes,
    $ExecutionArtifacts=$null,
    $DirectInputs=$null
) {
    if($null-eq$ExecutionArtifacts){$ExecutionArtifacts=New-C4ExecutionArtifacts $FactRows $ObservationRows $FamilyRegistry $MemberLedger $References $LanePolicy $LaneBytes $Vocabulary $VocabularyText}
    if($null-eq$DirectInputs){$DirectInputs=New-C4DirectInputs $ExecutionArtifacts}
    $testStage=[pscustomobject][ordered]@{generatedAt='2026-07-16T04:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C4StaticQualificationGate:1.0.0');directInputs=$DirectInputs}
    Invoke-C4StaticQualificationGate -FamilyRegistry $FamilyRegistry -FamilyMemberLedger $MemberLedger -CrossLaneReferencePackage $References -TypedFactRows @($FactRows) -LanePolicyRegistry $LanePolicy -LanePolicyBytes $LaneBytes -MemberStaticStatuses @($Vocabulary.memberStaticStatus) -StaticObservationRows @($ObservationRows) -ExecutionArtifacts $ExecutionArtifacts -Stage $testStage
}

function Run-Kernel($FactRows, $ObservationRows) {
    Invoke-C4StaticQualificationKernel `
        -FamilyRegistry $familyRegistry `
        -FamilyMemberLedger $memberLedger `
        -TypedFactRows $FactRows `
        -LanePolicyRegistry $policy `
        -LanePolicyBytes $policyBytes `
        -MemberStaticStatuses @($vocabulary.memberStaticStatus) `
        -StaticObservationRows $ObservationRows
}

$result = Run-Kernel @($facts) @($observations)
if ($result.status -cne 'Passed') { throw "C4-0 positive result failed: $($result.issues -join '; ')" }
if ($result.assignedMemberCount -ne 5 -or $result.staticPassedCount -ne 3 -or $result.staticFailedCount -ne 1 -or $result.uncheckedCount -ne 1) { throw 'SP-40 member partition failed.' }
if ($result.assignedMemberBytes -ne 1500 -or $result.staticPassedBytes -ne 1000 -or $result.staticFailedBytes -ne 200 -or $result.uncheckedBytes -ne 300) { throw 'SP-40 member byte partition failed.' }
if ($result.requiredCheckCount -ne 36 -or $result.passedCheckCount -ne 34 -or $result.failedCheckCount -ne 1 -or $result.uncheckedCheckCount -ne 1) { throw 'SP-40 required-check partition failed.' }
if ($result.memberResults.Count -ne 5 -or @($result.memberResults.assetObjectId | Sort-Object -Unique).Count -ne 5) { throw 'C4-0 member identity conservation failed.' }
if (@($result.memberResults | Where-Object staticStatus -CEQ 'StaticPassed').Count -ne 3 -or @($result.memberResults | Where-Object staticStatus -CEQ 'StaticFailed').Count -ne 1 -or @($result.memberResults | Where-Object staticStatus -CEQ 'Unchecked').Count -ne 1) { throw 'C4-0 member status projection failed.' }
foreach ($memberResult in $result.memberResults) {
    if ($memberResult.requiredCheckCount -ne ($memberResult.passedCheckCount + $memberResult.failedCheckCount + $memberResult.uncheckedCheckCount)) { throw 'C4-0 member check conservation failed.' }
    $expectedFailureClasses = if ($memberResult.staticStatus -ceq 'StaticFailed') { @('ImportSettingMismatch') } else { @() }
    if ((@($memberResult.actionableFailureClasses) -join ',') -cne ($expectedFailureClasses -join ',')) { throw 'C4-0 member actionable failure-class projection failed.' }
    $expectedInputKinds = @($result.checkResults | Where-Object assetObjectId -CEQ $memberResult.assetObjectId | ForEach-Object availableInputKinds | Sort-Object -CaseSensitive -Unique)
    if ((@($memberResult.availableInputKinds) -join ',') -cne ($expectedInputKinds -join ',')) { throw 'C4-0 member available-input projection failed.' }
}
foreach ($familyResult in $result.familyResults) {
    if ($familyResult.memberCount -ne ($familyResult.staticPassedCount + $familyResult.staticFailedCount + $familyResult.uncheckedCount)) { throw 'C4-0 family member conservation failed.' }
    $expectedFailureClasses = @($result.memberResults | Where-Object familyId -CEQ $familyResult.familyId | ForEach-Object actionableFailureClasses | Sort-Object -CaseSensitive -Unique)
    $expectedInputKinds = @($result.memberResults | Where-Object familyId -CEQ $familyResult.familyId | ForEach-Object availableInputKinds | Sort-Object -CaseSensitive -Unique)
    if ((@($familyResult.actionableFailureClasses) -join ',') -cne ($expectedFailureClasses -join ',') -or (@($familyResult.availableInputKinds) -join ',') -cne ($expectedInputKinds -join ',')) { throw 'C4-0 family typed projection conservation failed.' }
}
foreach ($checkResult in $result.checkResults) {
    if ($checkResult.outcome -ceq 'Failed' -and (@($checkResult.failureClasses) -join ',') -cne 'ImportSettingMismatch') { throw 'C4-0 failed check lost typed failure class.' }
    if ($checkResult.outcome -cne 'Failed' -and @($checkResult.failureClasses).Count) { throw 'C4-0 non-failed check gained a failure class.' }
}
$alternateFailureRows = @(Clone-Value $observations)
$alternateFailureObservation = @($alternateFailureRows | Where-Object outcome -CEQ 'Failed')[0]
$alternateFailureObservation.failureClasses = @('MaterialMismatch')
$alternateFailureResult = Run-Kernel @($facts) $alternateFailureRows
$originalFailedCheck = @($result.checkResults | Where-Object outcome -CEQ 'Failed')[0]
$alternateFailedCheck = @($alternateFailureResult.checkResults | Where-Object outcome -CEQ 'Failed')[0]
$originalFailedMember = @($result.memberResults | Where-Object staticStatus -CEQ 'StaticFailed')[0]
$alternateFailedMember = @($alternateFailureResult.memberResults | Where-Object staticStatus -CEQ 'StaticFailed')[0]
if ($alternateFailureResult.status -cne 'Passed' -or $alternateFailedCheck.staticCheckResultId -ceq $originalFailedCheck.staticCheckResultId -or $alternateFailedMember.memberStaticResultId -ceq $originalFailedMember.memberStaticResultId -or (@($alternateFailedMember.actionableFailureClasses) -join ',') -cne 'MaterialMismatch') { throw 'Typed failure-class identity sensitivity failed.' }
if (@($result.checkResults | Where-Object outcome -CEQ 'Unchecked' | Where-Object reasonCode -CEQ 'None').Count) { throw 'Unchecked was projected as Passed.' }

$missingRows = @($observations | Where-Object { -not ($_.assetObjectId -ceq $assigned[0].assetObjectId -and $_.checkId -ceq @($policy.policies | Where-Object lane -CEQ $assigned[0].lane)[0].staticCheckDefinitions[0].checkId) })
$missingResult = Run-Kernel @($facts) $missingRows
if ($missingResult.status -cne 'Failed' -or $missingResult.issues -cnotcontains 'Missing required static observation row.') { throw 'LF-09 missing check fail-closed behavior failed.' }

$duplicateRows = @($observations) + @((Clone-Value $observations[0]))
$duplicateResult = Run-Kernel @($facts) $duplicateRows
if ($duplicateResult.status -cne 'Failed' -or $duplicateResult.issues -cnotcontains 'Duplicate static observation row.') { throw 'LF-09 duplicate check fail-closed behavior failed.' }

$invalidRows = @(Clone-Value $observations)
$invalidRows[0].reasonCode = 'ToolUnavailable'
$invalidResult = Run-Kernel @($facts) $invalidRows
if ($invalidResult.status -cne 'Failed' -or $invalidResult.issues -cnotcontains 'Passed static observation must use reasonCode None.') { throw 'LF-09 invalid reason fail-closed behavior failed.' }

$missingFailureClasses = @(Clone-Value $observations)
@($missingFailureClasses | Where-Object outcome -CEQ 'Failed')[0].failureClasses = @()
$missingFailureResult = Run-Kernel @($facts) $missingFailureClasses
if ($missingFailureResult.status -cne 'Failed' -or $missingFailureResult.issues -cnotcontains 'Failed static observation requires failureClasses.') { throw 'Typed failure-class absence did not fail closed.' }

$textFailureClass = @(Clone-Value $observations)
@($textFailureClass | Where-Object outcome -CEQ 'Failed')[0].failureClasses = @('LF-08:ColliderValidity')
$textFailureResult = Run-Kernel @($facts) $textFailureClass
if ($textFailureResult.status -cne 'Failed' -or $textFailureResult.issues -cnotcontains 'Static observation failureClasses are invalid.') { throw 'Text attribution was accepted as a failure class.' }

$missingEvidenceRows = @(Clone-Value $observations)
$passedWithEvidence = @($missingEvidenceRows | Where-Object outcome -CEQ 'Passed')[0]
$passedWithEvidence.evidenceKinds = @($passedWithEvidence.evidenceKinds | Select-Object -Skip 1)
$missingEvidenceResult = Run-Kernel @($facts) $missingEvidenceRows
if ($missingEvidenceResult.status -cne 'Failed' -or $missingEvidenceResult.issues -cnotcontains 'Passed static observation is missing required evidence kinds.') { throw 'Required evidence conjunction fail-closed behavior failed.' }

$unknownFacts = @(Clone-Value $facts)
$actor = @($assigned | Where-Object lane -CEQ 'Actor')[0]
$actorFact = @($unknownFacts | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.factKind -ceq 'AnimationSetShapeId' })[0]
$actorFact.factStatus = 'Unknown'
$unknownRows = @(Clone-Value $observations)
$actorObservation = @($unknownRows | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0]
$actorObservation.outcome = 'Unchecked'; $actorObservation.reasonCode = 'MissingInputFact'; $actorObservation.observedFingerprint = $null; $actorObservation.failureClasses = @()
$unknownResult = Run-Kernel $unknownFacts $unknownRows
if ($unknownResult.status -cne 'Passed' -or @($unknownResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0].outcome -cne 'Unchecked') { throw "Missing fact did not remain explicit Unchecked: $($unknownResult.status); $($unknownResult.issues -join '; ')" }
$unknownCheck = @($unknownResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0]
if (@($unknownCheck.availableInputKinds) -ccontains 'AnimationSetShapeId' -or @($unknownCheck.availableInputKinds) -cnotcontains 'SerializedMetadata') { throw 'Unknown fact incorrectly satisfied availableInputKinds.' }

$notApplicableFacts = @(Clone-Value $facts)
$naFact = @($notApplicableFacts | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.factKind -ceq 'AnimationSetShapeId' })[0]
$naFact.factStatus = 'NotApplicable'
$notApplicableRows = @($observations | Where-Object { -not ($_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability') })
$notApplicableResult = Run-Kernel $notApplicableFacts $notApplicableRows
if ($notApplicableResult.status -cne 'Passed' -or $notApplicableResult.requiredCheckCount -ne 35 -or @($notApplicableResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' }).Count) { throw 'Policy-allowed NotApplicable check was not excluded.' }

$repeat = Run-Kernel @($facts) @($observations)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C4-0 determinism failed.' }
$unboundPolicy=Clone-Value $policy;$unboundPolicy.policySetVersion='9.9.9'
$unboundResult=Invoke-C4StaticQualificationKernel -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -TypedFactRows @($facts) -LanePolicyRegistry $unboundPolicy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations)
if($unboundResult.status-cne'Failed'-or$unboundResult.issues-cnotcontains'LC-I07 execution object does not match accepted bytes.'){throw 'C4 LC-I07 object/bytes binding RED failed.'}
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C4-0 touched C2 publication state.' }

$executionArtifacts=New-C4ExecutionArtifacts
$directInputs=New-C4DirectInputs $executionArtifacts
$stage = [pscustomobject][ordered]@{generatedAt='2026-07-16T04:00:00Z';snapshotId='snapshot-pc-install-001';toolVersions=@('C4StaticQualificationGate:1.0.0');directInputs=$directInputs}
$gate = Invoke-C4StaticQualificationGate -FamilyRegistry $familyRegistry -FamilyMemberLedger $memberLedger -CrossLaneReferencePackage $crossLaneReferences -TypedFactRows @($facts) -LanePolicyRegistry $policy -LanePolicyBytes $policyBytes -MemberStaticStatuses @($vocabulary.memberStaticStatus) -StaticObservationRows @($observations) -ExecutionArtifacts $executionArtifacts -Stage $stage
if ($gate.gateStatus -cne 'Passed' -or (@($gate.PSObject.Properties.Name)-join',') -cne 'gateStatus,memberStaticQualification,familyStaticSummary,summary,report,texts') { throw 'C4-1 Passed result vector shape failed.' }
if ($gate.summary.failureAccounting.outputCandidateCount -ne 3 -or $gate.summary.failureAccounting.projectedOutputCount -ne 3 -or $gate.summary.failureAccounting.outputFailureCount -ne 0 -or $gate.summary.directOutputs.Count -ne 3) { throw 'C4-1 Passed output conservation failed.' }
if ((@($gate.memberStaticQualification.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,memberResults' -or (@($gate.familyStaticSummary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,families') { throw 'C4 success artifact top-level shape failed.' }
if ((@($gate.summary.PSObject.Properties.Name)-join',') -cne 'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision') { throw 'C4-O03 summary top-level shape failed.' }
if ($gate.memberStaticQualification.memberResults.Count -ne 5 -or $gate.familyStaticSummary.families.Count -ne 5 -or $gate.summary.coverage.requiredCheckCount -ne 36) { throw 'C4-1 success artifact counts failed.' }
$expectedInputFingerprint=Get-TestStageInputFingerprint $directInputs
if($gate.summary.inputFingerprint-cne$expectedInputFingerprint){throw "C4-1 artifactId-bound input fingerprint failed: expected=$expectedInputFingerprint actual=$($gate.summary.inputFingerprint)"}
$memberShape='staticResultId,assetObjectId,familyId,lane,requiredCheckCount,passedCheckCount,failedCheckCount,uncheckedCheckCount,staticStatus,uncheckedReasonCodes,actionableFailureClasses,availableInputKinds,failureAttribution,nextAllowedAction,checkResults,evidence'
$checkShape='checkResultId,checkId,outcome,reasonCode,observedFingerprint,failureClasses,availableInputKinds,evidence'
foreach($memberResult in $gate.memberStaticQualification.memberResults){if((@($memberResult.PSObject.Properties.Name)-join',')-cne$memberShape){throw 'C4-O01 member shape failed.'};foreach($checkResult in $memberResult.checkResults){if((@($checkResult.PSObject.Properties.Name)-join',')-cne$checkShape){throw 'C4-O01 check shape failed.'}}}
$familyShape='familyId,lane,memberCount,memberBytes,staticPassedCount,staticPassedBytes,staticFailedCount,staticFailedBytes,uncheckedCount,uncheckedBytes,staticOutcome,actionableFailureClasses,availableInputKinds,failureAttribution,nextAllowedAction,memberStaticResultIds,evidence'
foreach($familyResult in $gate.familyStaticSummary.families){if((@($familyResult.PSObject.Properties.Name)-join',')-cne$familyShape){throw 'C4-O02 family shape failed.'};if($familyResult.memberCount-ne($familyResult.staticPassedCount+$familyResult.staticFailedCount+$familyResult.uncheckedCount)){throw 'C4-O02 family conservation failed.'}}
$coverageShape='familyCount,memberCount,memberBytes,staticPassedCount,staticPassedBytes,staticFailedCount,staticFailedBytes,uncheckedCount,uncheckedBytes,requiredCheckCount,passedCheckCount,failedCheckCount,uncheckedCheckCount'
$accountingShape='inputSubjectCount,acceptedInputSubjectCount,inputFailureCount,notEvaluatedInputSubjectCount,outputCandidateCount,projectedOutputCount,outputFailureCount,issueCount,gateStatus,inputFailures,inputSuppressions,outputFailures'
if((@($gate.summary.coverage.PSObject.Properties.Name)-join',')-cne$coverageShape-or(@($gate.summary.failureAccounting.PSObject.Properties.Name)-join',')-cne$accountingShape){throw 'C4-O03 coverage/accounting shape failed.'}
if($gate.summary.failureAccounting.inputFailureCount-ne0-or$gate.summary.decision.failureAttribution-cne'None; C4 lifecycle contract passed.'-or@($gate.memberStaticQualification.memberResults|Where-Object staticStatus -CEQ StaticFailed).Count-ne1-or@($gate.memberStaticQualification.memberResults|Where-Object staticStatus -CEQ Unchecked).Count-ne1){throw 'LF-07/LF-08 valid outcome projection failed.'}
if($gate.report.Contains("`r")-or-not$gate.report.EndsWith("`n")-or$gate.report.EndsWith("`n`n")){throw 'C4 report byte format failed.'}
$outputTextById=@{'C4-O01'=$gate.texts.memberStaticQualification;'C4-O02'=$gate.texts.familyStaticSummary;'C4-O03-Report'=$gate.report}
foreach($output in $gate.summary.directOutputs){if($output.sha256-cne(Get-FixtureFingerprint $outputTextById[$output.artifactId]).Substring(7)){throw"C4 direct output hash mismatch: $($output.artifactId)"}}
$changedInputs=Clone-Value $directInputs;@($changedInputs|Where-Object artifactId -CEQ 'C3-O01')[0].sha256=('d'*64)
$changedGate=Invoke-TestGate -ExecutionArtifacts $executionArtifacts -DirectInputs $changedInputs
if($changedGate.gateStatus-cne'Failed'-or$changedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 exact-byte SHA mutation did not fail closed.'}
$missingInputs=@($directInputs|Where-Object artifactId -CNE 'LC-I14')
$missingInputGate=Invoke-TestGate -ExecutionArtifacts $executionArtifacts -DirectInputs $missingInputs
if($missingInputGate.gateStatus-cne'Failed'-or$missingInputGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 missing LC-I14 did not fail closed.'}
$duplicateInputs=@($directInputs)+@((Clone-Value $directInputs[0]))
$duplicateInputGate=Invoke-TestGate -ExecutionArtifacts $executionArtifacts -DirectInputs $duplicateInputs
if($duplicateInputGate.gateStatus-cne'Failed'-or$duplicateInputGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 duplicate direct input did not fail closed.'}
$extraArtifacts=@($executionArtifacts)+@([pscustomobject][ordered]@{artifactId='Unexpected';bytes="{}"})
$extraInputs=@($directInputs)+@([pscustomobject][ordered]@{artifactId='Unexpected';path='Tools/AssetImport/Fixtures/FamilyQualificationGate/unexpected.json';sha256=Get-TestSha256 "{}"})
$extraInputs=@(Get-TestOrdinalRows $extraInputs @('path'))
$extraInputGate=Invoke-TestGate -ExecutionArtifacts $extraArtifacts -DirectInputs $extraInputs
if($extraInputGate.gateStatus-cne'Failed'-or$extraInputGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 extra direct input did not fail closed.'}
$misorderedInputs=@($directInputs)
[Array]::Reverse($misorderedInputs)
$misorderedInputGate=Invoke-TestGate -ExecutionArtifacts $executionArtifacts -DirectInputs $misorderedInputs
if($misorderedInputGate.gateStatus-cne'Failed'-or$misorderedInputGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 misordered direct inputs did not fail closed.'}
$unboundFamily=Clone-Value $familyRegistry;$unboundFamily.snapshotId='snapshot-unbound'
$unboundFamilyGate=Invoke-TestGate -FamilyRegistry $unboundFamily -ExecutionArtifacts $executionArtifacts -DirectInputs $directInputs
if($unboundFamilyGate.gateStatus-cne'Failed'-or$unboundFamilyGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 C3 execution object/bytes mismatch did not fail closed.'}
$unboundObservations=Clone-Value $observations;$unboundObservations[0].reasonCode='ToolUnavailable'
$unboundObservationGate=Invoke-TestGate -ObservationRows $unboundObservations -ExecutionArtifacts $executionArtifacts -DirectInputs $directInputs
if($unboundObservationGate.gateStatus-cne'Failed'-or$unboundObservationGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 LC-I14 execution object/bytes mismatch did not fail closed.'}
$misorderedObservations=@(Clone-Value $observations)
[Array]::Reverse($misorderedObservations)
$misorderedObservationArtifacts=@(Clone-Value $executionArtifacts)
$misorderedStaticPackage=New-C4StaticObservationPackage $observations
$misorderedStaticPackage.rows=$misorderedObservations
@($misorderedObservationArtifacts|Where-Object artifactId -CEQ 'LC-I14')[0].bytes=ConvertTo-TestCanonicalJson $misorderedStaticPackage
$misorderedObservationInputs=New-C4DirectInputs $misorderedObservationArtifacts
$misorderedObservationGate=Invoke-TestGate -ObservationRows $misorderedObservations -ExecutionArtifacts $misorderedObservationArtifacts -DirectInputs $misorderedObservationInputs
if($misorderedObservationGate.gateStatus-cne'Failed'-or$misorderedObservationGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 misordered LC-I14 rows did not fail closed.'}
$staleObservationArtifacts=@(Clone-Value $executionArtifacts)
$staleStaticPackage=New-C4StaticObservationPackage $observations
$staleStaticPackage.snapshotId='snapshot-stale'
@($staleObservationArtifacts|Where-Object artifactId -CEQ 'LC-I14')[0].bytes=ConvertTo-TestCanonicalJson $staleStaticPackage
$staleObservationInputs=New-C4DirectInputs $staleObservationArtifacts
$staleObservationGate=Invoke-TestGate -ExecutionArtifacts $staleObservationArtifacts -DirectInputs $staleObservationInputs
if($staleObservationGate.gateStatus-cne'Failed'-or$staleObservationGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-01:C4:DirectInputs'){throw 'C4 stale LC-I14 snapshot did not fail closed.'}

$fixturePayloads=[ordered]@{'valid-c4-static-observation-package.json'=ConvertTo-TestCanonicalJson (New-C4StaticObservationPackage $observations);'valid-member-static-qualification.json'=$gate.texts.memberStaticQualification;'valid-family-static-summary.json'=$gate.texts.familyStaticSummary;'valid-c4-summary.json'=$gate.texts.summary;'valid-c4-report.md'=$gate.report}
$contractStaticObservationPath=Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-c4-static-observation-package.json'
if($UpdateFixtures){$utf8=[Text.UTF8Encoding]::new($false);foreach($name in $fixturePayloads.Keys){[IO.File]::WriteAllText((Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"),$fixturePayloads[$name],$utf8)};[IO.File]::WriteAllText($contractStaticObservationPath,$fixturePayloads['valid-c4-static-observation-package.json'],$utf8);'fixtures=Updated';return}
foreach($name in $fixturePayloads.Keys){$path=Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name";if(-not(Test-Path -LiteralPath $path)){throw "C4-1 expected fixture missing: $name"};if([IO.File]::ReadAllText($path,[Text.UTF8Encoding]::new($false))-cne$fixturePayloads[$name]){throw "C4-1 fixture bytes mismatch: $name"}}
if(-not(Test-Path -LiteralPath $contractStaticObservationPath)-or[IO.File]::ReadAllText($contractStaticObservationPath,[Text.UTF8Encoding]::new($false))-cne$fixturePayloads['valid-c4-static-observation-package.json']){throw 'C4 LC-I14 contract/runtime fixture bytes mismatch.'}

$failedGate = Invoke-TestGate -ObservationRows $missingRows
if($failedGate.gateStatus-cne'Failed'-or$null-ne$failedGate.memberStaticQualification-or$null-ne$failedGate.familyStaticSummary-or$failedGate.summary.failureAccounting.outputCandidateCount-ne3-or$failedGate.summary.failureAccounting.projectedOutputCount-ne1-or$failedGate.summary.failureAccounting.outputFailureCount-ne2-or$failedGate.summary.failureAccounting.issueCount-ne1-or$failedGate.summary.failureAccounting.inputFailures[0].attribution-cne'LF-09:C4:StaticConservation'-or$failedGate.summary.directOutputs.Count-ne1){throw 'C4-1 LF-09 diagnostic-only vector failed.'}

'status=Passed'
'assignedMemberCount=5'
'memberPartition=3/1/1'
'memberBytePartition=1000/200/300'
'requiredCheckPartition=34/1/1'
'laneCheckCount=36'
'passedOutputVector=3/3/0'
'failedOutputVector=3/1/2'
'publicationWriteCount=0'
