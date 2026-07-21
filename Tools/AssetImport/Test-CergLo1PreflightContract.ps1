[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'New-CergLo1Preflight.ps1')
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')

function Assert-CergPreflightFixture {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('cerg-preflight-contract-' + [guid]::NewGuid().ToString('N'))
$passed = [System.Collections.Generic.List[string]]::new()
try {
    $attemptRoot = Join-Path $scratch 'Attempt'
    $sourceRoot = Join-Path $scratch 'Source'
    $member = [pscustomobject][ordered]@{
        memberId = 'C1F-SYNTH-1'; candidateId = 'char_14401'; sourceId = 'fixture-source'
        portableRelativePath = 'bundle/member.bin'; sizeBytes = [int64]9; sha256 = ('1' * 64)
    }
    $candidate = [pscustomobject][ordered]@{
        status = 'Passed'; selectedCandidateId = 'char_14401'; sourceMembers = @($member)
    }
    $memberRow = [pscustomobject][ordered]@{
        sourceMemberRefId = 'C1F-SYNTH-1'; sourceId = 'fixture-source'
        sourcePortableRelativePath = 'bundle/member.bin'
        stagingPortableRelativePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture-source/bundle/member.bin'
        byteCount = [int64]9; sha256 = ('1' * 64)
    }
    $definition = [pscustomobject][ordered]@{
        schemaVersion = 'cerg-lo-cerg1-preflight-definition/1.0.0'
        artifactId = 'LO-CERG1-P01-DEFINITION'
        candidateLockSha256 = ('2' * 64)
        contractHeadCommit = ('3' * 40)
        selectedCandidateId = 'char_14401'
        createdAt = '2026-07-21T00:00:00Z'
        sourceRootBindings = @([pscustomobject][ordered]@{ sourceId = 'fixture-source'; privateAbsoluteReadOnlyRoot = $sourceRoot; rootFingerprint = ('4' * 64) })
        implementationBindings = @()
        operation = [pscustomobject][ordered]@{
            operationId = 'LO1-OP01'; obligationRefIds = @('LO1-OB01'); implementationRefIds = @()
            inputMemberRefIds = @('C1F-SYNTH-1'); expectedSubjectKinds = @(); expectedRelationshipKinds = @()
            sourceReadMaxFiles = 1; sourceReadMaxBytes = [int64]9; maxDurationSeconds = 1
            maxResultRows = 1; maxOutputFiles = 1; maxOutputBytes = [int64]9
            stagingInputPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Input'
            outputPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Output'
            workPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Work'
        }
        aggregateLimits = [pscustomobject][ordered]@{
            sourceReadMaxFiles = 1; sourceReadMaxBytes = [int64]9; maxDurationSeconds = 1
            maxResultRows = 1; maxOutputFiles = 1; maxOutputBytes = [int64]9
        }
        stagingPlan = [pscustomobject][ordered]@{
            stagingInputPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Input'
            stagingInventoryTemporaryPath = 'Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json.tmp'
            stagingInventoryPath = 'Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json'
            workPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Work'
            outputPortablePath = 'Extracted/CERG/SingleCharacter/LO-CERG1/Output'
            memberRows = @($memberRow); memberCount = 1; byteCount = [int64]9
            memberSetFingerprint = Get-CergPreflightStructuredSha256 'cerg-lo1/staging-member-set/1' @($memberRow)
        }
        status = 'Green'
        nextAction = 'RequestExactHumanConfirmationForLOCERG1'
    }

    $preflight = New-CergLo1PreflightObject -Definition $definition -AttemptPrivateAbsoluteRoot $attemptRoot
    $null = Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $preflight `
        -StagingInventoryTemporaryPath $preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath `
        -StagingInventoryPath $preflight.stagingPlan.stagingInventoryPrivateAbsolutePath
    Assert-CergPreflightFixture (-not [System.IO.Directory]::Exists($attemptRoot)) 'Contract validation created the attempt root.'
    $passed.Add('PRODUCTION-OBJECT-ENTERS-TG01-PRECONDITION')

    $expectedStagingFields = @(
        'attemptPrivateAbsoluteRoot','stagingInputPortablePath','stagingInputPrivateAbsolutePath',
        'stagingInventoryTemporaryPath','stagingInventoryTemporaryPrivateAbsolutePath',
        'stagingInventoryPath','stagingInventoryPrivateAbsolutePath','workPortablePath',
        'workPrivateAbsolutePath','outputPortablePath','outputPrivateAbsolutePath',
        'memberRows','memberCount','byteCount','memberSetFingerprint'
    )
    Assert-CergPreflightFixture ((@($preflight.stagingPlan.PSObject.Properties.Name) -join '|') -ceq ($expectedStagingFields -join '|')) 'Production stagingPlan has hidden, missing, or reordered fields.'
    $passed.Add('NO-HIDDEN-PRODUCTION-SCHEMA-FIELDS')

    foreach ($field in @('attemptPrivateAbsoluteRoot','stagingInputPrivateAbsolutePath','stagingInventoryTemporaryPrivateAbsolutePath','stagingInventoryPrivateAbsolutePath','workPrivateAbsolutePath','outputPrivateAbsolutePath')) {
        $mutation = ConvertTo-CergPreflightCanonicalJson $preflight | ConvertFrom-Json -Depth 100
        $mutation.stagingPlan.PSObject.Properties.Remove($field)
        $message = ''
        try { Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $mutation } catch { $message = $_.Exception.Message }
        Assert-CergPreflightFixture ($message -clike 'PreflightConsumerContractFailure:*') "Missing $field was not rejected by the pre-A01 gate."
        Assert-CergPreflightFixture (-not [System.IO.Directory]::Exists($attemptRoot)) "Missing $field created attempt state."
        $passed.Add("MISSING-$field-REJECTED")
    }

    [pscustomobject][ordered]@{
        schemaVersion = 'cerg-lo1-preflight-contract-test/1.0.0'
        testCount = $passed.Count
        passedCount = $passed.Count
        status = 'Passed'
        tests = @($passed)
    } | ConvertTo-Json -Depth 10
}
finally {
    if ([System.IO.Directory]::Exists($scratch)) { [System.IO.Directory]::Delete($scratch, $true) }
}
