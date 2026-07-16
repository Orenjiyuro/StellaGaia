[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C4StaticQualificationGate.psm1') -Force -PassThru
$policy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json') | ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json') | ConvertFrom-Json -Depth 100 -DateKind String
$familyRegistry = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json') | ConvertFrom-Json -Depth 100 -DateKind String
$memberLedger = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json') | ConvertFrom-Json -Depth 100 -DateKind String

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function Get-FixtureFingerprint([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
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
        $observations.Add([pscustomobject][ordered]@{
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            checkId = [string]$check.checkId
            outcome = $outcome
            reasonCode = $reasonCode
            observedFingerprint = if ($outcome -ceq 'Passed') { Get-FixtureFingerprint "$($member.assetObjectId)|$($check.checkId)|fixture-evidence" } else { $null }
            evidenceKinds = @($check.requiredEvidenceKinds)
            evidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/c4-walking-skeleton')
        })
    }
}

function Run-Kernel($FactRows, $ObservationRows) {
    Invoke-C4StaticQualificationKernel `
        -FamilyRegistry $familyRegistry `
        -FamilyMemberLedger $memberLedger `
        -TypedFactRows $FactRows `
        -LanePolicyRegistry $policy `
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
}
foreach ($familyResult in $result.familyResults) {
    if ($familyResult.memberCount -ne ($familyResult.staticPassedCount + $familyResult.staticFailedCount + $familyResult.uncheckedCount)) { throw 'C4-0 family member conservation failed.' }
}
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
$actorObservation.outcome = 'Unchecked'; $actorObservation.reasonCode = 'MissingInputFact'; $actorObservation.observedFingerprint = $null
$unknownResult = Run-Kernel $unknownFacts $unknownRows
if ($unknownResult.status -cne 'Passed' -or @($unknownResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' })[0].outcome -cne 'Unchecked') { throw 'Missing fact did not remain explicit Unchecked.' }

$notApplicableFacts = @(Clone-Value $facts)
$naFact = @($notApplicableFacts | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.factKind -ceq 'AnimationSetShapeId' })[0]
$naFact.factStatus = 'NotApplicable'
$notApplicableRows = @($observations | Where-Object { -not ($_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability') })
$notApplicableResult = Run-Kernel $notApplicableFacts $notApplicableRows
if ($notApplicableResult.status -cne 'Passed' -or $notApplicableResult.requiredCheckCount -ne 35 -or @($notApplicableResult.checkResults | Where-Object { $_.assetObjectId -ceq $actor.assetObjectId -and $_.checkId -ceq 'AnimationClipReadability' }).Count) { throw 'Policy-allowed NotApplicable check was not excluded.' }

$repeat = Run-Kernel @($facts) @($observations)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C4-0 determinism failed.' }
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C4-0 touched C2 publication state.' }

'status=Passed'
'assignedMemberCount=5'
'memberPartition=3/1/1'
'memberBytePartition=1000/200/300'
'requiredCheckPartition=34/1/1'
'laneCheckCount=36'
'publicationWriteCount=0'
