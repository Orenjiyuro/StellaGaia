[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
. (Join-Path $PSScriptRoot 'Test-C6AuthoringDecisionGate.ps1')
$outputModulePath = Join-Path $PSScriptRoot 'C6AuthoringOutputGate.psm1'
$outputModule = Import-Module $outputModulePath -Force -PassThru
if ($outputModule.ExportedFunctions.Keys -cnotcontains 'Invoke-C6AuthoringOutputGate') {
    throw 'C6-1 output-vector entry point is missing.'
}
$moduleAst = [Management.Automation.Language.Parser]::ParseFile($outputModulePath, [ref]$null, [ref]$null)
if (@($moduleAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Sort-Object' }, $true)).Count) {
    throw 'C6 output module uses culture-sensitive Sort-Object.'
}

$decisionResult = Run-Kernel
$executionArtifacts = New-ExecutionArtifacts $familyRegistry $memberLedger $references $memberStatic $familyStatic $requirements $assessments
$directInputs = New-DirectInputs $historyBytes $executionArtifacts
$stage = [pscustomobject][ordered]@{
    generatedAt = '2026-07-16T10:00:00Z'
    snapshotId = $familyRegistry.snapshotId
    toolVersions = @([pscustomobject][ordered]@{ toolName = 'c6-authoring-output-gate'; version = '1.0.0' })
    directInputs = $directInputs
}
$c3Summary = Read-Fixture 'valid-c3-summary.json'

function Run-Output($Decision = $decisionResult) {
    Invoke-C6AuthoringOutputGate `
        -DecisionResult $Decision `
        -FamilyRegistry $familyRegistry `
        -FamilyMemberLedger $memberLedger `
        -MemberStaticQualification $memberStatic `
        -FamilyStaticSummary $familyStatic `
        -RepresentativeRequirements $requirements `
        -EvidenceAssessment $assessments `
        -C3Summary $c3Summary `
        -Stage $stage
}
function Assert-ExactShape($Value, [string]$Expected, [string]$Name) {
    if ((@($Value.PSObject.Properties.Name) -join ',') -cne $Expected) { throw "$Name shape failed." }
}
function Assert-Ordinal([object[]]$Rows, [string]$Property, [string]$Name) {
    for ($index = 1; $index -lt $Rows.Count; $index++) {
        if ([StringComparer]::Ordinal.Compare([string]$Rows[$index - 1].$Property, [string]$Rows[$index].$Property) -ge 0) {
            throw "$Name is not unique Ordinal order."
        }
    }
}

$gate = Run-Output
if ($gate.gateStatus -cne 'Passed') { throw 'C6-1 positive output gate failed.' }
if ($gate.summary.failureAccounting.outputCandidateCount -ne 5 -or
    $gate.summary.failureAccounting.projectedOutputCount -ne 5 -or
    $gate.summary.failureAccounting.outputFailureCount -ne 0 -or
    $gate.summary.directOutputs.Count -ne 5) {
    throw 'C6-1 Passed output conservation failed.'
}
Assert-ExactShape $gate.authoringReuseLedger 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint,toolVersions,sourceArtifacts,families,members,coverage,capabilities' 'C6-O01'
Assert-ExactShape $gate.familyDecisionPackage 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint,decisions,issues' 'C6-O02'
Assert-ExactShape $gate.capabilityProjection 'schemaVersion,generatedAt,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint,capabilities' 'C6-O03'
Assert-ExactShape $gate.g5Handoff 'schemaVersion,generatedAt,snapshotId,inputFingerprint,authoringReuseLedgerPath,authoringReuseLedgerSha256,familyDecisionPackagePath,familyDecisionPackageSha256,capabilityProjectionPath,capabilityProjectionSha256,familyConstructionCoverage,originalAssetBatchCoverage,stellaSora2AuthoringReady,failureAttribution,nextAllowedAction' 'C6-O04'
Assert-ExactShape $gate.summary 'schemaVersion,generatedAt,stageId,snapshotId,inputFingerprint,policySetFingerprint,decisionPolicyFingerprint,toolVersions,directInputs,directOutputs,coverage,failureAccounting,decision' 'C6-O05 summary'
if ($gate.authoringReuseLedger.schemaVersion -cne '2.0.0' -or
    $gate.authoringReuseLedger.sourceArtifacts.Count -ne 17 -or
    $gate.authoringReuseLedger.families.Count -ne 5 -or
    $gate.authoringReuseLedger.members.Count -ne 5 -or
    $gate.authoringReuseLedger.capabilities.Count -ne 7) {
    throw 'C6-O01 subject universe failed.'
}
Assert-Ordinal @($gate.authoringReuseLedger.sourceArtifacts) path 'C6 sourceArtifacts'
Assert-Ordinal @($gate.authoringReuseLedger.families) familyId 'C6 families'
Assert-Ordinal @($gate.authoringReuseLedger.members) assetObjectId 'C6 members'
Assert-Ordinal @($gate.authoringReuseLedger.capabilities) capabilityId 'C6 capabilities'
Assert-Ordinal @($gate.familyDecisionPackage.decisions) familyId 'C6 decisions'
Assert-Ordinal @($gate.familyDecisionPackage.issues) issueId 'C6 issues'

$coverage = $gate.summary.coverage
if ($coverage.totalFamilyCount -ne 5 -or
    $coverage.needsDiagnosisFamilyCount -ne 1 -or
    $coverage.repairOnceFamilyCount -ne 1 -or
    $coverage.retainForLaterFamilyCount -ne 3 -or
    $coverage.totalMemberCount -ne 5 -or
    $coverage.totalMemberBytes -ne 1500 -or
    $coverage.acceptedOriginalPoolMemberCount -ne 0 -or
    $coverage.acceptedReplacementSourcePoolMemberCount -ne 0 -or
    $coverage.isolatedMemberCount -ne 5 -or
    $coverage.isolatedMemberBytes -ne 1500 -or
    $coverage.requiredCapabilityCount -ne 7 -or
    $coverage.satisfiedCapabilityCount -ne 0 -or
    $coverage.unsatisfiedCapabilityCount -ne 1 -or
    $coverage.blockedCapabilityCount -ne 6) {
    throw 'SP-60/SP-61 C6 coverage failed.'
}
if ($gate.g5Handoff.originalAssetBatchCoverage.reusableFamilyCount -ne 0 -or
    $gate.g5Handoff.originalAssetBatchCoverage.reusableMemberCount -ne 0 -or
    $gate.g5Handoff.originalAssetBatchCoverage.reusableBytes -ne 0 -or
    $gate.g5Handoff.stellaSora2AuthoringReady.value -ne $false) {
    throw 'C6 base coverage/readiness projection failed.'
}
if ($gate.g5Handoff.authoringReuseLedgerSha256 -cne (Get-Sha256 $gate.texts.authoringReuseLedger) -or
    $gate.g5Handoff.familyDecisionPackageSha256 -cne (Get-Sha256 $gate.texts.familyDecisionPackage) -or
    $gate.g5Handoff.capabilityProjectionSha256 -cne (Get-Sha256 $gate.texts.capabilityProjection)) {
    throw 'C6-O04 exact-byte handoff binding failed.'
}
$outputTextById = @{
    'C6-O01' = $gate.texts.authoringReuseLedger
    'C6-O02' = $gate.texts.familyDecisionPackage
    'C6-O03' = $gate.texts.capabilityProjection
    'C6-O04' = $gate.texts.g5Handoff
    'C6-O05-Report' = $gate.report
}
foreach ($output in $gate.summary.directOutputs) {
    if ($output.sha256 -cne (Get-Sha256 $outputTextById[$output.artifactId])) { throw "C6 direct output hash mismatch: $($output.artifactId)" }
}

$allCapabilities = Clone-Value $decisionResult
foreach ($row in $allCapabilities.capabilityResults) {
    $row.status = 'Satisfied'
}
$allCapabilities.satisfiedCapabilityCount = 7
$allCapabilities.unsatisfiedCapabilityCount = 0
$allCapabilities.blockedCapabilityCount = 0
$readyPartial = Run-Output $allCapabilities
if (-not $readyPartial.g5Handoff.stellaSora2AuthoringReady.value -or
    $readyPartial.g5Handoff.originalAssetBatchCoverage.reusableFamilyCount -ne 0) {
    throw 'Authoring readiness was incorrectly coupled to OriginalAssetBatchCoverage.'
}

$fullCoverage = Clone-Value $decisionResult
foreach ($row in $fullCoverage.familyDecisions) {
    $row.decision = 'UseOriginalAsset'; $row.ruleId = 'UseOriginalAssetRule'; $row.repairClass = $null
}
foreach ($row in $fullCoverage.memberProjections) {
    $row.disposition = 'UseOriginalAsset'; $row.poolStatus = 'AcceptedOriginalPool'
}
$fullCoverage.needsDiagnosisFamilyCount = 0
$fullCoverage.useOriginalAssetFamilyCount = 5
$fullCoverage.repairOnceFamilyCount = 0
$fullCoverage.retainForLaterFamilyCount = 0
$coverageWithoutReadiness = Run-Output $fullCoverage
if ($coverageWithoutReadiness.g5Handoff.originalAssetBatchCoverage.reusableFamilyCount -ne 5 -or
    $coverageWithoutReadiness.g5Handoff.originalAssetBatchCoverage.reusableMemberCount -ne 5 -or
    $coverageWithoutReadiness.g5Handoff.stellaSora2AuthoringReady.value) {
    throw 'OriginalAssetBatchCoverage was incorrectly coupled to authoring readiness.'
}

foreach ($failureCase in @(
    @('LF-16', 'ConservationMismatch'),
    @('LF-17', 'DecisionConflict'),
    @('LF-18', 'CapabilityProjectionInvalid')
)) {
    $failedDecision = Clone-Value $decisionResult
    $failedDecision.status = 'Failed'
    $failedDecision.failureId = $failureCase[0]
    $failedDecision.reasonCode = $failureCase[1]
    $failedDecision.familyDecisions = @()
    $failedDecision.memberProjections = @()
    $failedDecision.capabilityResults = @()
    $failedGate = Run-Output $failedDecision
    if ($failedGate.gateStatus -cne 'Failed' -or
        $null -ne $failedGate.authoringReuseLedger -or
        $null -ne $failedGate.familyDecisionPackage -or
        $null -ne $failedGate.capabilityProjection -or
        $null -ne $failedGate.g5Handoff -or
        $failedGate.summary.failureAccounting.outputCandidateCount -ne 5 -or
        $failedGate.summary.failureAccounting.projectedOutputCount -ne 1 -or
        $failedGate.summary.failureAccounting.outputFailureCount -ne 4 -or
        $failedGate.summary.directOutputs.Count -ne 1) {
        throw "$($failureCase[0]) diagnostic-only vector failed."
    }
}
$missingMember = Clone-Value $decisionResult
$missingMember.memberProjections = @($missingMember.memberProjections | Select-Object -Skip 1)
$missingMemberGate = Run-Output $missingMember
if ($missingMemberGate.gateStatus -cne 'Failed' -or
    $missingMemberGate.summary.failureAccounting.inputFailures[0].attribution -cnotlike 'LF-16:*') {
    throw 'C6 output projection accepted a missing member row.'
}
$duplicateCapability = Clone-Value $decisionResult
$duplicateCapability.capabilityResults = @($duplicateCapability.capabilityResults) + @($duplicateCapability.capabilityResults[0])
$duplicateCapability.requiredCapabilityCount++
$duplicateCapabilityGate = Run-Output $duplicateCapability
if ($duplicateCapabilityGate.gateStatus -cne 'Failed' -or
    $duplicateCapabilityGate.summary.failureAccounting.inputFailures[0].attribution -cnotlike 'LF-18:*') {
    throw 'C6 output projection accepted a duplicate capability row.'
}
if ($gate.executorLaunchCount -ne 0 -or $gate.heavyOperationCount -ne 0 -or $gate.publicationWriteCount -ne 0) {
    throw 'C6-1 attempted an executor, heavy operation, or publication.'
}

$fixturePayloads = [ordered]@{
    'valid-authoring-reuse-ledger.json' = $gate.texts.authoringReuseLedger
    'valid-family-decision-package.json' = $gate.texts.familyDecisionPackage
    'valid-capability-projection.json' = $gate.texts.capabilityProjection
    'valid-c3-c6-g5-handoff.json' = $gate.texts.g5Handoff
    'valid-c6-summary.json' = $gate.texts.summary
    'valid-c6-report.md' = $gate.report
}
if ($UpdateFixtures) {
    $utf8 = [Text.UTF8Encoding]::new($false)
    foreach ($name in $fixturePayloads.Keys) {
        [IO.File]::WriteAllText((Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"), $fixturePayloads[$name], $utf8)
    }
    [IO.File]::WriteAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-authoring-reuse-ledger.json'), $gate.texts.authoringReuseLedger, $utf8)
    [IO.File]::WriteAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/repair-attempt-history.json'), $historyBytes, $utf8)
    [IO.File]::WriteAllText((Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-c3-c6-repair-attempt-history.json'), $historyBytes, $utf8)
    'fixtures=Updated'
    return
}
foreach ($name in $fixturePayloads.Keys) {
    $path = Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$name"
    if (-not (Test-Path -LiteralPath $path) -or [IO.File]::ReadAllText($path, [Text.UTF8Encoding]::new($false)) -cne $fixturePayloads[$name]) {
        throw "C6 fixture bytes are stale: $name"
    }
}
$contractLedger = Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-authoring-reuse-ledger.json'
if ([IO.File]::ReadAllText($contractLedger, [Text.UTF8Encoding]::new($false)) -cne $gate.texts.authoringReuseLedger) {
    throw 'C6 authoring ledger contract fixture is stale.'
}

'status=Passed'
'familyPartition=1/0/1/0/3/0/0'
'memberPoolPartition=0/0/5'
'capabilityPartition=0/1/6'
'passedOutputVector=5/5/0'
'failedOutputVector=5/1/4'
"authoringReady=$($gate.g5Handoff.stellaSora2AuthoringReady.value)"
"executorLaunchCount=$($gate.executorLaunchCount)"
"heavyOperationCount=$($gate.heavyOperationCount)"
"publicationWriteCount=$($gate.publicationWriteCount)"
