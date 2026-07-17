[CmdletBinding()]
param(
    [Parameter()]
    [string] $RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskIssues = [System.Collections.Generic.List[string]]::new()

function Add-PolicyIssue {
    param(
        [Parameter(Mandatory)]
        [string] $Message
    )

    $taskIssues.Add($Message)
}

function Read-PolicyDocument {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $taskPath = Join-Path $RepositoryRoot $RelativePath
    if (-not (Test-Path -LiteralPath $taskPath -PathType Leaf)) {
        Add-PolicyIssue "Missing PersonalLocalMode governance document: $RelativePath"
        return ''
    }

    return Get-Content -LiteralPath $taskPath -Raw
}

function Assert-ContainsLiteral {
    param(
        [Parameter(Mandatory)]
        [string] $DocumentName,

        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [string] $Expected
    )

    if ($Text.IndexOf($Expected, [System.StringComparison]::Ordinal) -lt 0) {
        Add-PolicyIssue "$DocumentName is missing required PersonalLocalMode literal: $Expected"
    }
}

function Assert-DoesNotMatch {
    param(
        [Parameter(Mandatory)]
        [string] $DocumentName,

        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string] $Description
    )

    if ([regex]::IsMatch($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
        Add-PolicyIssue "$DocumentName retains forbidden $Description."
    }
}

if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}
else {
    $RepositoryRoot = [System.IO.Path]::GetFullPath($RepositoryRoot)
}

$taskDocuments = [ordered]@{
    Package = 'docs/asset-migration/source-corpus-phase-b-authorization-package.md'
    Runbook = 'docs/asset-migration/source-corpus-phase-b-runbook.md'
    CompletionRoadmap = 'docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md'
    ProgramRoadmap = 'docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md'
    R74 = 'docs/superpowers/plans/2026-07-17-stella-sora-r7-4-post-change-revalidation-task.md'
    R75 = 'docs/superpowers/plans/2026-07-17-stella-sora-r7-5-exact-human-confirmation-task.md'
    R81 = 'docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md'
}

$taskText = [ordered]@{}
foreach ($taskEntry in $taskDocuments.GetEnumerator()) {
    $taskText[$taskEntry.Key] = Read-PolicyDocument -RelativePath $taskEntry.Value
    Assert-ContainsLiteral -DocumentName $taskEntry.Key -Text $taskText[$taskEntry.Key] -Expected 'PersonalLocalMode'
}

foreach ($taskName in @('Package', 'R74', 'R75', 'R81')) {
    Assert-DoesNotMatch -DocumentName $taskName -Text $taskText[$taskName] -Pattern '(?m)^\| PB-A(?:0[1-9]|1[0-2]) \|' -Description 'PB-A01-through-PB-A12 form row'
    Assert-DoesNotMatch -DocumentName $taskName -Text $taskText[$taskName] -Pattern '(?i)operatorApprovalId|approvalTimestampUtc|trustedOperatorId|sensitiveLoggingPolicyId|evidenceRetentionOwnerId|external exact approval' -Description 'external compliance identity field'
    Assert-DoesNotMatch -DocumentName $taskName -Text $taskText[$taskName] -Pattern '12\s*=\s*12\s+Confirmed' -Description 'twelve-row human confirmation conservation'
}

Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected '| PB-I01 | PersonalLocalMode derived preflight state |'
Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected 'PersonalLocalModeConfirmationCount=1'
Assert-ContainsLiteral -DocumentName 'R75' -Text $taskText.R75 -Expected 'humanFormFieldCount=0'
Assert-ContainsLiteral -DocumentName 'R75' -Text $taskText.R75 -Expected 'nextAction=RunR8.1AutomaticPreflight'

foreach ($taskLiteral in @(
    'derivedHead=',
    'derivedToolHashMismatchCount=',
    'derivedManifestSourceSet=',
    'derivedBaselineState=',
    'derivedOutputBoundaryState=',
    'derivedRequiredFreeSpaceBytes=',
    'ReadyForSinglePersonalLocalRun'
)) {
    Assert-ContainsLiteral -DocumentName 'R81' -Text $taskText.R81 -Expected $taskLiteral
}

foreach ($taskName in @('Package', 'Runbook', 'ProgramRoadmap', 'R81')) {
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected 'ConfirmPersonalLocalRun'
}

$taskSafetyText = @(
    $taskText.Package,
    $taskText.Runbook,
    $taskText.ProgramRoadmap,
    $taskText.R75,
    $taskText.R81
) -join "`n"

foreach ($taskLiteral in @(
    'sourceReadOnly=true',
    'fixedOutputRoot=true',
    'attemptCount=1',
    'foregroundCancellationAuthority=true',
    'retryAllowed=false',
    'C2Authorized=false',
    'UnityAuthorized=false',
    'extractionAuthorized=false',
    'importAuthorized=false'
)) {
    Assert-ContainsLiteral -DocumentName 'PersonalLocalMode active governance set' -Text $taskSafetyText -Expected $taskLiteral
}

$taskResult = [pscustomobject][ordered]@{
    status = if ($taskIssues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $taskIssues.Count
    issues = $taskIssues.ToArray()
    checkedDocumentCount = $taskDocuments.Count
    realInputAccessCount = 0
    processLaunchCount = 0
    createdOutputCount = 0
}

$taskResult | ConvertTo-Json -Compress -Depth 10
if ($taskIssues.Count -ne 0) {
    exit 1
}
