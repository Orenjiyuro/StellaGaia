[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$modulePath = Join-Path $PSScriptRoot 'C6ChildConservationGate.psm1'
$module = Import-Module $modulePath -Force -PassThru
if ($module.ExportedFunctions.Keys -cnotcontains 'Test-C6ChildRowConservation') {
    throw 'C6 child-conservation entry point is missing.'
}
$moduleAst = [Management.Automation.Language.Parser]::ParseFile($modulePath, [ref]$null, [ref]$null)
if (@($moduleAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -ceq 'Sort-Object' }, $true)).Count) {
    throw 'C6 child-conservation module uses culture-sensitive Sort-Object.'
}

function Read-Fixture([string]$Name) {
    Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot "Tools/AssetImport/Fixtures/FamilyQualificationGate/$Name") |
        ConvertFrom-Json -Depth 100 -DateKind String
}

function Clone-Value($Value) {
    $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String
}

$familyRegistry = Read-Fixture 'valid-family-registry.json'
$memberLedger = Read-Fixture 'valid-family-member-ledger.json'
$memberStatic = Read-Fixture 'valid-member-static-qualification.json'
$familyStatic = Read-Fixture 'valid-family-static-summary.json'
$requirements = Read-Fixture 'valid-representative-requirements.json'
$assessments = Read-Fixture 'valid-evidence-assessment.json'

function Run-Gate(
    $FamilyRegistry = $familyRegistry,
    $MemberLedger = $memberLedger,
    $MemberStatic = $memberStatic,
    $FamilyStatic = $familyStatic,
    $Requirements = $requirements,
    $Assessments = $assessments
) {
    Test-C6ChildRowConservation `
        -FamilyRegistry $FamilyRegistry `
        -FamilyMemberLedger $MemberLedger `
        -MemberStaticQualification $MemberStatic `
        -FamilyStaticSummary $FamilyStatic `
        -RepresentativeRequirements $Requirements `
        -EvidenceAssessment $Assessments
}

function Assert-Failure($Result, [string]$FailureId, [string]$SubjectId) {
    if ($Result.gateStatus -cne 'Failed' -or $Result.failureId -cne $FailureId -or
        $Result.subjectId -cne $SubjectId -or $Result.reasonCode -cne $(if ($FailureId -ceq 'LF-18') { 'CapabilityProjectionInvalid' } else { 'ConservationMismatch' }) -or
        $Result.attribution -cne "${FailureId}:$SubjectId") {
        throw "Expected $FailureId on $SubjectId; got $($Result | ConvertTo-Json -Compress -Depth 10)"
    }
}

$passed = Run-Gate
$shape = 'gateStatus,failureId,subjectKind,subjectId,reasonCode,attribution,familyCount,assignedMemberCount,riskRequirementCount,suitabilityRequirementCount,validatedFamilyIds,validatedAssignedMemberIds,validatedRiskRequirementIds,validatedSuitabilityRequirementIds,executorLaunchCount,heavyOperationCount'
if ((@($passed.PSObject.Properties.Name) -join ',') -cne $shape -or $passed.gateStatus -cne 'Passed') {
    throw 'C6 child-conservation Passed result shape failed.'
}
if ($passed.familyCount -ne 5 -or $passed.assignedMemberCount -ne 5 -or
    $passed.riskRequirementCount -ne 21 -or $passed.suitabilityRequirementCount -ne 11) {
    throw 'C6 child-conservation subject counts failed.'
}
if ($passed.validatedFamilyIds.Count -ne 5 -or $passed.validatedAssignedMemberIds.Count -ne 5 -or
    $passed.validatedRiskRequirementIds.Count -ne 21 -or $passed.validatedSuitabilityRequirementIds.Count -ne 11) {
    throw 'C6 validated subject universes are incomplete.'
}
foreach ($values in @(
    @($passed.validatedFamilyIds),
    @($passed.validatedAssignedMemberIds),
    @($passed.validatedRiskRequirementIds),
    @($passed.validatedSuitabilityRequirementIds)
)) {
    for ($index = 1; $index -lt $values.Count; $index++) {
        if ([StringComparer]::Ordinal.Compare([string]$values[$index - 1], [string]$values[$index]) -ge 0) {
            throw 'C6 validated subject universe is not unique Ordinal order.'
        }
    }
}
if ($passed.executorLaunchCount -ne 0 -or $passed.heavyOperationCount -ne 0) {
    throw 'C6 child-conservation attempted a heavy operation.'
}

$wrongSnapshot = Clone-Value $memberStatic
$wrongSnapshot.snapshotId = 'snapshot-other'
Assert-Failure (Run-Gate -MemberStatic $wrongSnapshot) 'LF-16' 'C6:ChildGenerationIdentity'

$wrongDecisionGeneration = Clone-Value $assessments
$wrongDecisionGeneration.decisionPolicyFingerprint = ('0' * 64)
Assert-Failure (Run-Gate -Assessments $wrongDecisionGeneration) 'LF-16' 'C6:ChildGenerationIdentity'

$duplicateFamily = Clone-Value $familyRegistry
$duplicateFamily.families = @($duplicateFamily.families) + @($duplicateFamily.families[0])
Assert-Failure (Run-Gate -FamilyRegistry $duplicateFamily) 'LF-16' 'C6:FamilyUniverse'

$missingC4Family = Clone-Value $familyStatic
$missingC4Family.families = @($missingC4Family.families | Select-Object -Skip 1)
Assert-Failure (Run-Gate -FamilyStatic $missingC4Family) 'LF-16' 'C6:FamilyUniverse'

$duplicateMember = Clone-Value $memberLedger
$duplicateMember.rows = @($duplicateMember.rows) + @($duplicateMember.rows[0])
Assert-Failure (Run-Gate -MemberLedger $duplicateMember) 'LF-16' 'C6:MemberUniverse'

$missingStaticMember = Clone-Value $memberStatic
$missingStaticMember.memberResults = @($missingStaticMember.memberResults | Select-Object -Skip 1)
Assert-Failure (Run-Gate -MemberStatic $missingStaticMember) 'LF-16' 'C6:MemberUniverse'

$wrongFamilyMember = Clone-Value $memberStatic
$wrongFamilyMember.memberResults[0].familyId = $wrongFamilyMember.memberResults[1].familyId
Assert-Failure (Run-Gate -MemberStatic $wrongFamilyMember) 'LF-16' 'C6:MemberUniverse'

$missingRiskRequirement = Clone-Value $requirements
$missingRiskRequirement.requirements = @($missingRiskRequirement.requirements | Select-Object -Skip 1)
Assert-Failure (Run-Gate -Requirements $missingRiskRequirement) 'LF-16' 'C6:RiskAssessmentUniverse'

$duplicateRiskRequirement = Clone-Value $requirements
$duplicateRiskRequirement.requirements = @($duplicateRiskRequirement.requirements) + @($duplicateRiskRequirement.requirements[0])
Assert-Failure (Run-Gate -Requirements $duplicateRiskRequirement) 'LF-16' 'C6:RiskAssessmentUniverse'

$missingRiskAssessment = Clone-Value $assessments
$missingRiskAssessment.assessments = @($missingRiskAssessment.assessments | Select-Object -Skip 1)
Assert-Failure (Run-Gate -Assessments $missingRiskAssessment) 'LF-16' 'C6:RiskAssessmentUniverse'

$duplicateRiskAssessment = Clone-Value $assessments
$duplicateRiskAssessment.assessments = @($duplicateRiskAssessment.assessments) + @($duplicateRiskAssessment.assessments[0])
Assert-Failure (Run-Gate -Assessments $duplicateRiskAssessment) 'LF-16' 'C6:RiskAssessmentUniverse'

$wrongRiskFamily = Clone-Value $assessments
$wrongRiskFamily.assessments[0].familyId = $familyRegistry.families[0].familyId
Assert-Failure (Run-Gate -Assessments $wrongRiskFamily) 'LF-16' 'C6:RiskAssessmentUniverse'

$missingSuitabilityRequirement = Clone-Value $requirements
$missingSuitabilityRequirement.capabilitySuitabilityRequirements = @($missingSuitabilityRequirement.capabilitySuitabilityRequirements | Select-Object -Skip 1)
Assert-Failure (Run-Gate -Requirements $missingSuitabilityRequirement) 'LF-18' 'C6:SuitabilityAssessmentUniverse'

$duplicateSuitabilityRequirement = Clone-Value $requirements
$duplicateSuitabilityRequirement.capabilitySuitabilityRequirements = @($duplicateSuitabilityRequirement.capabilitySuitabilityRequirements) + @($duplicateSuitabilityRequirement.capabilitySuitabilityRequirements[0])
Assert-Failure (Run-Gate -Requirements $duplicateSuitabilityRequirement) 'LF-18' 'C6:SuitabilityAssessmentUniverse'

$missingSuitabilityAssessment = Clone-Value $assessments
$missingSuitabilityAssessment.capabilitySuitabilityAssessments = @($missingSuitabilityAssessment.capabilitySuitabilityAssessments | Select-Object -Skip 1)
Assert-Failure (Run-Gate -Assessments $missingSuitabilityAssessment) 'LF-18' 'C6:SuitabilityAssessmentUniverse'

$duplicateSuitabilityAssessment = Clone-Value $assessments
$duplicateSuitabilityAssessment.capabilitySuitabilityAssessments = @($duplicateSuitabilityAssessment.capabilitySuitabilityAssessments) + @($duplicateSuitabilityAssessment.capabilitySuitabilityAssessments[0])
Assert-Failure (Run-Gate -Assessments $duplicateSuitabilityAssessment) 'LF-18' 'C6:SuitabilityAssessmentUniverse'

$wrongSuitabilityRoute = Clone-Value $assessments
$wrongSuitabilityRoute.capabilitySuitabilityAssessments[0].routeKind = 'DecodedAudio'
Assert-Failure (Run-Gate -Assessments $wrongSuitabilityRoute) 'LF-18' 'C6:SuitabilityAssessmentUniverse'

"status=Passed"
"familyCount=$($passed.familyCount)"
"assignedMemberCount=$($passed.assignedMemberCount)"
"riskRequirementCount=$($passed.riskRequirementCount)"
"suitabilityRequirementCount=$($passed.suitabilityRequirementCount)"
"executorLaunchCount=$($passed.executorLaunchCount)"
"heavyOperationCount=$($passed.heavyOperationCount)"
