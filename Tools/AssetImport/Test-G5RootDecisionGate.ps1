[CmdletBinding()]
param([switch]$UpdateFixtures)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$modulePath = Join-Path $PSScriptRoot 'G5RootDecisionGate.psm1'
$module = Import-Module $modulePath -Force -PassThru
$utf8 = [Text.UTF8Encoding]::new($false)

$parseErrors = $null
$moduleAst = [Management.Automation.Language.Parser]::ParseFile(
    $modulePath,
    [ref] $null,
    [ref] $parseErrors
)
if ($parseErrors.Count -ne 0) {
    throw "G5 module syntax invalid: $($parseErrors[0].Message)"
}
$forbiddenCommandPattern = '^(Start-Process|Set-Content|Add-Content|Out-File|New-Item|Remove-Item|Move-Item|Copy-Item|Unity|UnityHub|Extract|ImportAsset)$'
$forbiddenCommands = @(
    $moduleAst.FindAll(
        {
            param($Node)
            $Node -is [Management.Automation.Language.CommandAst] -and
            $Node.GetCommandName() -match $forbiddenCommandPattern
        },
        $true
    )
)
if ($forbiddenCommands.Count -ne 0) {
    throw "G5 lightweight policy contains forbidden command: $($forbiddenCommands[0].Extent.Text)"
}

function Read-Bytes([string] $Path) {
    return ,([IO.File]::ReadAllBytes((Join-Path $repositoryRoot $Path)))
}

function Clone-Bytes([byte[]] $Bytes) {
    return ,([byte[]]@($Bytes))
}

$paths = [ordered]@{
    C1 = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json'
    C2 = 'Tools/AssetImport/Fixtures/RootGate/valid-c2-discovery-summary.json'
    C6 = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json'
    Schema = 'docs/asset-migration/schemas/root-gate-summary.schema.json'
    Output = 'Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-root-gate-summary.json'
}

$input = [pscustomobject][ordered]@{
    generatedAt = '2026-07-16T12:00:00Z'
    c1SummaryPath = $paths.C1
    c1SummaryBytes = Read-Bytes $paths.C1
    c2SummaryPath = $paths.C2
    c2SummaryBytes = Read-Bytes $paths.C2
    c6HandoffPath = $paths.C6
    c6HandoffBytes = Read-Bytes $paths.C6
    rootSchemaPath = $paths.Schema
    rootSchemaBytes = Read-Bytes $paths.Schema
    additionalC3C6Inputs = @()
}

function Invoke-G5($Value) {
    @($module.Invoke({ param($x) Invoke-G5RootDecisionGate -InputFact $x }, @($Value)))[0]
}

function Clone-Input($Value) {
    [pscustomobject][ordered]@{
        generatedAt = $Value.generatedAt
        c1SummaryPath = $Value.c1SummaryPath
        c1SummaryBytes = Clone-Bytes $Value.c1SummaryBytes
        c2SummaryPath = $Value.c2SummaryPath
        c2SummaryBytes = Clone-Bytes $Value.c2SummaryBytes
        c6HandoffPath = $Value.c6HandoffPath
        c6HandoffBytes = Clone-Bytes $Value.c6HandoffBytes
        rootSchemaPath = $Value.rootSchemaPath
        rootSchemaBytes = Clone-Bytes $Value.rootSchemaBytes
        additionalC3C6Inputs = @($Value.additionalC3C6Inputs)
    }
}

$passed = Invoke-G5 $input
if ($passed.gateStatus -cne 'Passed' -or $null -eq $passed.rootSummary -or $passed.inputFailures.Count -ne 0) {
    throw "G5 positive failed: $($passed | ConvertTo-Json -Depth 20 -Compress)"
}
if ((@($passed.PSObject.Properties.Name) -join ',') -cne 'gateStatus,rootSummary,inputSubjects,inputFailures,outputAccounting,heavyOperationCount,executorLaunchCount,publicationWriteCount') {
    throw 'G5 result shape invalid.'
}
if (($passed.inputSubjects.terminalStatus -join ',') -cne 'Accepted,Accepted,Accepted,Accepted') {
    throw 'G5 direct input terminal accounting invalid.'
}
if ($passed.outputAccounting.outputCandidateCount -ne 1 -or $passed.outputAccounting.projectedOutputCount -ne 1 -or $passed.outputAccounting.outputFailureCount -ne 0) {
    throw 'G5 Passed output accounting invalid.'
}
if ($passed.heavyOperationCount -ne 0 -or $passed.executorLaunchCount -ne 0 -or $passed.publicationWriteCount -ne 0) {
    throw 'G5 lightweight policy counters invalid.'
}

$rootText = (($passed.rootSummary | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
if ($UpdateFixtures) {
    [IO.File]::WriteAllText((Join-Path $repositoryRoot $paths.Output), $rootText, $utf8)
}
$expectedText = [IO.File]::ReadAllText((Join-Path $repositoryRoot $paths.Output), $utf8)
if ($rootText -cne $expectedText) {
    throw 'G5 root summary exact fixture bytes mismatch.'
}
if ($passed.rootSummary.snapshotId -cne 'snapshot-pc-install-001' -or -not $passed.rootSummary.corpusSnapshotComplete.value) {
    throw 'G5 snapshot/corpus conclusion invalid.'
}
if ($passed.rootSummary.inputFingerprint -cne 'c2c39a3d8ad83dafadcb86418c65704c0cbccbfbc92e891565511b5bc31c5a95') {
    throw "G5 input fingerprint framing mismatch: $($passed.rootSummary.inputFingerprint)"
}
if (($passed.rootSummary.directGateSummaries.path -join ',') -cne 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json,Tools/AssetImport/Fixtures/RootGate/valid-c2-discovery-summary.json,Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json') {
    throw 'G5 direct summary Ordinal order invalid.'
}
if ($passed.rootSummary.familyConstructionCoverage.dispatchEligibleObjectCount -ne 7 -or $passed.rootSummary.stellaSora2AuthoringReady.value) {
    throw 'G5 C6 conclusion projection invalid.'
}

$c2Object = $utf8.GetString($input.c2SummaryBytes) | ConvertFrom-Json -Depth 100 -DateKind String
if (
    ($passed.rootSummary.identity | ConvertTo-Json -Compress) -cne
    ([pscustomobject][ordered]@{
        discoveryInputFingerprint = $c2Object.identity.discoveryInputFingerprint
        discoveryArtifactFingerprint = $c2Object.identity.discoveryArtifactFingerprint
    } | ConvertTo-Json -Compress)
) {
    throw 'G5 C2 identity projection is not lossless.'
}

$schemaJson = $utf8.GetString($input.rootSchemaBytes)
if (-not ($rootText | Test-Json -Schema $schemaJson -ErrorAction Stop)) {
    throw 'G5 output does not validate against root schema.'
}

$changedBytes = Clone-Input $input
$changedC1 = $utf8.GetString($changedBytes.c1SummaryBytes) | ConvertFrom-Json -Depth 100 -DateKind String
$changedC1.nextAllowedAction = 'Retain this fixture-only summary for the independent Phase A audit.'
$changedBytes.c1SummaryBytes = $utf8.GetBytes((($changedC1 | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n")
$changedBytesResult = Invoke-G5 $changedBytes
$originalC1Reference = @($passed.rootSummary.directGateSummaries | Where-Object path -CEQ $paths.C1)[0]
$changedC1Reference = @($changedBytesResult.rootSummary.directGateSummaries | Where-Object path -CEQ $paths.C1)[0]
if (
    $changedBytesResult.gateStatus -cne 'Passed' -or
    $changedBytesResult.rootSummary.inputFingerprint -ceq $passed.rootSummary.inputFingerprint -or
    $changedC1Reference.sha256 -ceq $originalC1Reference.sha256
) {
    throw 'G5 exact-byte fingerprint sensitivity counterexample failed.'
}

$forbidden = Clone-Input $input
$forbidden.additionalC3C6Inputs = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-summary.json')
$forbiddenResult = Invoke-G5 $forbidden
if ($forbiddenResult.gateStatus -cne 'Failed' -or $null -ne $forbiddenResult.rootSummary -or $forbiddenResult.inputFailures[0].reasonCode -cne 'PolicyViolation') {
    throw 'G5 direct C3-C5 read counterexample failed.'
}
if ($forbiddenResult.outputAccounting.projectedOutputCount -ne 0 -or $forbiddenResult.outputAccounting.outputFailureCount -ne 1 -or ($forbiddenResult.inputSubjects.terminalStatus -join ',') -cne 'NotEvaluated,NotEvaluated,NotEvaluated,NotEvaluated') {
    throw 'G5 policy failure transition invalid.'
}

$stale = Clone-Input $input
$staleC6 = $utf8.GetString($stale.c6HandoffBytes) | ConvertFrom-Json -Depth 100 -DateKind String
$staleC6.snapshotId = 'snapshot-stale'
$stale.c6HandoffBytes = $utf8.GetBytes((($staleC6 | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n")
$staleResult = Invoke-G5 $stale
if ($staleResult.gateStatus -cne 'Failed' -or $staleResult.inputFailures[0].reasonCode -cne 'StaleFingerprint' -or $null -ne $staleResult.rootSummary) {
    throw 'G5 stale snapshot counterexample failed.'
}

$malformed = Clone-Input $input
$malformedC2 = $utf8.GetString($malformed.c2SummaryBytes) | ConvertFrom-Json -Depth 100 -DateKind String
$malformedC2.coverage.PSObject.Properties.Remove('dispatch')
$malformed.c2SummaryBytes = $utf8.GetBytes((($malformedC2 | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n")
$malformedResult = Invoke-G5 $malformed
if ($malformedResult.gateStatus -cne 'Failed' -or $malformedResult.inputFailures[0].reasonCode -cne 'ProjectionInvalid' -or $null -ne $malformedResult.rootSummary) {
    throw 'G5 malformed nested input failure transition failed.'
}

$invalidCoverage = Clone-Input $input
$invalidC6 = $utf8.GetString($invalidCoverage.c6HandoffBytes) | ConvertFrom-Json -Depth 100 -DateKind String
$invalidC6.familyConstructionCoverage.dispatchEligibleObjectCount = 8
$invalidCoverage.c6HandoffBytes = $utf8.GetBytes((($invalidC6 | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n")
$invalidCoverageResult = Invoke-G5 $invalidCoverage
if ($invalidCoverageResult.gateStatus -cne 'Failed' -or $invalidCoverageResult.inputFailures[0].reasonCode -cne 'ProjectionInvalid') {
    throw 'G5 family construction conservation counterexample failed.'
}

$invalidReadiness = Clone-Input $input
$invalidC6 = $utf8.GetString($invalidReadiness.c6HandoffBytes) | ConvertFrom-Json -Depth 100 -DateKind String
$invalidC6.stellaSora2AuthoringReady.blockedCapabilityIds = @()
$invalidReadiness.c6HandoffBytes = $utf8.GetBytes((($invalidC6 | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n")
$invalidReadinessResult = Invoke-G5 $invalidReadiness
if ($invalidReadinessResult.gateStatus -cne 'Failed' -or $invalidReadinessResult.inputFailures[0].reasonCode -cne 'ProjectionInvalid') {
    throw 'G5 readiness partition counterexample failed.'
}

'status=Passed'
"inputFingerprint=$($passed.rootSummary.inputFingerprint)"
'directInputCount=4'
'outputVector=1/1/0'
'exactByteSensitivity=Passed'
'forbiddenDirectRead=Passed'
'staleSnapshot=Passed'
'malformedInputSuppression=Passed'
'familyConservation=Passed'
'readinessConservation=Passed'
'lightweightAstPolicy=Passed'
'heavyOperationCount=0'
'executorLaunchCount=0'
'publicationWriteCount=0'
