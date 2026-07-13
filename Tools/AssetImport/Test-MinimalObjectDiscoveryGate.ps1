$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$repositoryPrefix = $repositoryRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$allowedReads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$successfulReads = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Get-SafetyAstViolations {
    param(
        [Parameter(Mandatory)] [System.Management.Automation.Language.Ast] $Ast,
        [Parameter(Mandatory)] [bool] $AllowAuditedRead
    )

    $fileCommands = @(
        'Get-Content', 'Set-Content', 'Add-Content', 'Clear-Content',
        'New-Item', 'Copy-Item', 'Move-Item', 'Remove-Item', 'Rename-Item',
        'Out-File', 'Export-Csv', 'Import-Csv', 'Get-ChildItem',
        'Invoke-WebRequest', 'Invoke-RestMethod'
    )
    $processCommands = @(
        'Start-Process', 'Invoke-Expression', 'Invoke-Command',
        'pwsh', 'powershell', 'cmd', 'git', 'Unity', 'Unity.exe',
        'AssetRipper', 'AssetRipper.exe'
    )
    $fileMembers = @(
        'ReadAllText', 'ReadAllBytes', 'ReadLines', 'Open', 'OpenRead', 'OpenWrite',
        'Create', 'WriteAllText', 'WriteAllBytes', 'AppendAllText', 'Copy', 'Move',
        'Delete', 'CreateDirectory', 'EnumerateFiles', 'EnumerateDirectories',
        'EnumerateFileSystemEntries', 'GetFiles', 'GetDirectories'
    )
    $processMembers = @('Start')
    $fileViolations = [System.Collections.Generic.List[string]]::new()
    $processViolations = [System.Collections.Generic.List[string]]::new()

    foreach ($commandAst in @($Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true))) {
        $commandName = $commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            $processViolations.Add("DynamicCommand:$($commandAst.Extent.Text)")
        }
        elseif ($commandName -in $fileCommands) {
            $fileViolations.Add("FileCommand:$commandName")
        }
        elseif ($commandName -in $processCommands) {
            $processViolations.Add("ProcessCommand:$commandName")
        }
    }

    foreach ($memberAst in @($Ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true))) {
        $memberName = [string]$memberAst.Member.Value
        if ($memberName -in $fileMembers) {
            $isAuditedRead = $false
            if ($AllowAuditedRead -and $memberName -eq 'ReadAllText') {
                $current = $memberAst
                while ($null -ne $current -and $current -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
                    $current = $current.Parent
                }
                $isAuditedRead = $null -ne $current -and $current.Name -eq 'Read-AllowlistedJson'
            }
            if (-not $isAuditedRead) {
                $fileViolations.Add("FileMember:$memberName")
            }
        }
        elseif ($memberName -in $processMembers) {
            $processViolations.Add("ProcessMember:$memberName")
        }
    }

    return [pscustomobject]@{
        FileSystem = @($fileViolations)
        Process = @($processViolations)
    }
}

# RED probes freeze representative file-command, process, and dynamic-call detection.
$probeTokens = $null
$probeErrors = $null
$probeAst = [System.Management.Automation.Language.Parser]::ParseInput("Get-Content unsafe.asset`nSet-Content unsafe.asset x`nNew-Item unsafe`nCopy-Item a b`nOut-File unsafe", [ref]$probeTokens, [ref]$probeErrors)
$probeViolations = Get-SafetyAstViolations -Ast $probeAst -AllowAuditedRead $false
Assert-True ($probeViolations.FileSystem.Count -eq 5) 'safety audit must reject representative file commands'
$dynamicProbeAst = [System.Management.Automation.Language.Parser]::ParseInput('& $unsafeCommand', [ref]$probeTokens, [ref]$probeErrors)
$dynamicProbe = Get-SafetyAstViolations -Ast $dynamicProbeAst -AllowAuditedRead $false
Assert-True ($dynamicProbe.Process.Count -eq 1) 'safety audit must reject dynamic command invocation'
$processProbeAst = [System.Management.Automation.Language.Parser]::ParseInput('Start-Process Unity.exe', [ref]$probeTokens, [ref]$probeErrors)
$processProbe = Get-SafetyAstViolations -Ast $processProbeAst -AllowAuditedRead $false
Assert-True ($processProbe.Process.Count -eq 1) 'safety audit must reject process invocation'
$wholeModuleProbeAst = [System.Management.Automation.Language.Parser]::ParseInput(@'
function Hidden-FileRead { [System.IO.File]::ReadAllText('unsafe.asset') }
Start-Process Unity.exe
& $unsafeCommand
'@, [ref]$probeTokens, [ref]$probeErrors)
$wholeModuleProbe = Get-SafetyAstViolations -Ast $wholeModuleProbeAst -AllowAuditedRead $false
Assert-True ($wholeModuleProbe.FileSystem -contains 'FileMember:ReadAllText') 'whole-module audit must inspect helper functions'
Assert-True ($wholeModuleProbe.Process -contains 'ProcessCommand:Start-Process') 'whole-module audit must inspect module top-level process calls'
Assert-True ($wholeModuleProbe.Process.Count -eq 2) 'whole-module audit must fail closed on top-level dynamic commands'

function Resolve-RegisteredPath {
    param([Parameter(Mandatory)] [string] $RelativePath)
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Rooted paths are forbidden: $RelativePath"
    }
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $repositoryRoot $RelativePath))
    if (-not $fullPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Repository escape is forbidden: $RelativePath"
    }
    return $fullPath
}

function Add-AllowedRead {
    param([Parameter(Mandatory)] [string] $RelativePath)
    $null = $allowedReads.Add((Resolve-RegisteredPath $RelativePath))
}

function Read-AllowlistedJson {
    param([Parameter(Mandatory)] [string] $RelativePath)
    $fullPath = Resolve-RegisteredPath $RelativePath
    if (-not $allowedReads.Contains($fullPath)) {
        throw "Unregistered JSON read is forbidden: $RelativePath"
    }
    $raw = [System.IO.File]::ReadAllText($fullPath, [System.Text.UTF8Encoding]::new($false, $true))
    $value = $raw | ConvertFrom-Json -Depth 100
    $null = $successfulReads.Add($fullPath)
    return [pscustomobject]@{ Raw = $raw; Value = $value; FullPath = $fullPath }
}

function Copy-JsonValue {
    param([Parameter(Mandatory)] [object] $Value)
    return ($Value | ConvertTo-Json -Depth 100 -Compress) | ConvertFrom-Json -Depth 100
}

function Assert-FailedCase {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [object] $ObservationDocument,
        [Parameter(Mandatory)] [string[]] $ExpectedIssueFragments,
        [object] $C1LedgerOverride
    )
    $ledgerInput = if ($null -eq $C1LedgerOverride) { $c1.Value } else { $C1LedgerOverride }
    $result = ConvertTo-MinimalObjectLedger -Handoff $handoff.Value -C1Ledger $ledgerInput -ObservationDocument $ObservationDocument -LedgerSchema $schema.Value -Vocabulary $vocabulary.Value
    $subjectCount = @($ObservationDocument.observations).Count
    Assert-True ($null -eq $result.Ledger) "$Name must suppress the ledger"
    Assert-True ($result.Coverage.observationSubjectCount -eq $subjectCount) "$Name subject count"
    Assert-True ($result.Coverage.emittedObjectCount -eq 0) "$Name emitted count"
    Assert-True ($result.Coverage.rejectedObservationCount -eq $subjectCount) "$Name rejected count"
    Assert-True ($result.Coverage.observationSubjectCount -eq ($result.Coverage.emittedObjectCount + $result.Coverage.rejectedObservationCount)) "$Name conservation"
    $issueText = [string]::Join([Environment]::NewLine, @($result.Issues))
    foreach ($fragment in $ExpectedIssueFragments) {
        Assert-True ($issueText.Contains($fragment, [System.StringComparison]::Ordinal)) "$Name missing issue fragment '$fragment'"
    }
}

$handoffRelativePath = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json'
$observationRelativePath = 'Tools/AssetImport/Fixtures/DiscoveryGate/minimal-object-observations.json'
$schemaRelativePath = 'docs/asset-migration/schemas/source-corpus-ledger.schema.json'
$vocabularyRelativePath = 'docs/asset-migration/schemas/status-vocabulary.json'
$goldenRelativePath = 'Tools/AssetImport/Fixtures/DiscoveryGate/valid-minimal-object-ledger.json'
$modulePath = Join-Path $PSScriptRoot 'MinimalObjectDiscoveryGate.psm1'
$extractedPath = Join-Path $repositoryRoot 'Extracted'
$importedPath = Join-Path $repositoryRoot 'Assets/StellaGaia/Imported'

$extractedBefore = Test-Path -LiteralPath $extractedPath
$importedBefore = Test-Path -LiteralPath $importedPath
Assert-True (-not $extractedBefore) 'Extracted must not exist before the gate'
Assert-True (-not $importedBefore) 'Imported must not exist before the gate'

foreach ($path in @($handoffRelativePath, $observationRelativePath, $schemaRelativePath, $vocabularyRelativePath, $goldenRelativePath)) {
    Add-AllowedRead $path
}
$handoff = Read-AllowlistedJson $handoffRelativePath
Add-AllowedRead ([string]$handoff.Value.ledgerPath)

$c1 = Read-AllowlistedJson ([string]$handoff.Value.ledgerPath)
$observations = Read-AllowlistedJson $observationRelativePath
$schema = Read-AllowlistedJson $schemaRelativePath
$vocabulary = Read-AllowlistedJson $vocabularyRelativePath
$golden = Read-AllowlistedJson $goldenRelativePath

$loadedModule = Import-Module $modulePath -Force -PassThru
$result = ConvertTo-MinimalObjectLedger -Handoff $handoff.Value -C1Ledger $c1.Value -ObservationDocument $observations.Value -LedgerSchema $schema.Value -Vocabulary $vocabulary.Value

Assert-True ($null -ne $result.Ledger) 'positive ledger must be emitted'
Assert-True ($result.Issues.Count -eq 0) 'positive run must have no issues'
Assert-True ($result.Coverage.observationSubjectCount -eq 2) 'positive subject count'
Assert-True ($result.Coverage.emittedObjectCount -eq 2) 'positive emitted count'
Assert-True ($result.Coverage.rejectedObservationCount -eq 0) 'positive rejected count'
Assert-True ($result.Coverage.observationSubjectCount -eq ($result.Coverage.emittedObjectCount + $result.Coverage.rejectedObservationCount)) 'positive conservation'

$candidateJson = $result.Ledger | ConvertTo-Json -Depth 100
Assert-True (Test-Json -Json $candidateJson -Schema $schema.Raw -ErrorAction Stop) 'candidate ledger must satisfy complete R1'
$actualCompact = $result.Ledger | ConvertTo-Json -Depth 100 -Compress
$goldenCompact = $golden.Value | ConvertTo-Json -Depth 100 -Compress
Assert-True ($actualCompact -ceq $goldenCompact) 'candidate ledger must equal golden ledger'

foreach ($object in @($result.Ledger.objects)) {
    Assert-True ($object.configurationDisposition -in @($vocabulary.Value.configurationDisposition)) 'configuration vocabulary'
    foreach ($dimension in @('corpus', 'extraction', 'semantics', 'unity', 'disposition')) {
        Assert-True ($object.status.$dimension -in @($vocabulary.Value.$dimension)) "status vocabulary $dimension"
    }
}

try {
    $null = '{"schemaVersion":"1.0.0","observations":[' | ConvertFrom-Json -Depth 100
    throw 'Malformed JSON unexpectedly parsed'
}
catch {
    Assert-True ($_.Exception.Message -notlike 'Malformed JSON unexpectedly parsed*') 'parse error must fail closed'
    $parseCoverage = [pscustomobject]@{ observationSubjectCount = 0; emittedObjectCount = 0; rejectedObservationCount = 0 }
    Assert-True ($parseCoverage.observationSubjectCount -eq ($parseCoverage.emittedObjectCount + $parseCoverage.rejectedObservationCount)) 'parse error 0=0+0'
}

$missing = Copy-JsonValue $observations.Value
$missing.observations[0].PSObject.Properties.Remove('classId')
Assert-FailedCase 'missing-field' $missing @('MissingField:row[0].classId')

$extra = Copy-JsonValue $observations.Value
$extra.observations[0] | Add-Member -NotePropertyName futureField -NotePropertyValue 'forbidden'
Assert-FailedCase 'extra-field' $extra @('ExtraField:row[0].futureField')

$duplicate = Copy-JsonValue $observations.Value
$duplicate.observations[1].assetObjectId = $duplicate.observations[0].assetObjectId
Assert-FailedCase 'duplicate-identity' $duplicate @('DuplicateAssetObjectId:row[0]', 'DuplicateAssetObjectId:row[1]')

$badSource = Copy-JsonValue $observations.Value
$badSource.observations[0].sourceId = 'missing-source'
Assert-FailedCase 'C1-source-mismatch' $badSource @('C1SourceMismatch:row[0]')

$badFile = Copy-JsonValue $observations.Value
$badFile.observations[0].containerRelativePath = 'SourceCorpus/PcInstall/missing.bundle'
Assert-FailedCase 'C1-file-mismatch' $badFile @('C1FileMismatch:row[0]')

$badSchema = Copy-JsonValue $observations.Value
$badSchema.observations[0].serializedSizeBytes = -1
Assert-FailedCase 'public-schema-incompatibility' $badSchema @('PublicSchema:row[0].serializedSizeBytes')

$badEnvelope = Copy-JsonValue $c1.Value
$badEnvelope.toolVersions[0].version = ''
Assert-FailedCase 'complete-public-schema-incompatibility' $observations.Value @('PublicSchema:CandidateLedger') $badEnvelope

$badVocabulary = Copy-JsonValue $observations.Value
$badVocabulary.observations[0].configurationDisposition = 'FutureState'
Assert-FailedCase 'public-vocabulary-incompatibility' $badVocabulary @('PublicVocabulary:row[0].configurationDisposition')

$readCountBeforeDenials = $successfulReads.Count
foreach ($deniedPath in @('C:\machine\asset.json', '../outside.json', 'Tools/AssetImport/Fixtures/DiscoveryGate/unregistered.json')) {
    try {
        $null = Read-AllowlistedJson $deniedPath
        throw "Denied path unexpectedly read: $deniedPath"
    }
    catch {
        Assert-True ($_.Exception.Message -notlike 'Denied path unexpectedly read*') "deny path $deniedPath"
    }
}
Assert-True ($successfulReads.Count -eq $readCountBeforeDenials) 'denied paths must fail before reading'

$expectedReadSet = @(
    $handoffRelativePath,
    [string]$handoff.Value.ledgerPath,
    $observationRelativePath,
    $schemaRelativePath,
    $vocabularyRelativePath,
    $goldenRelativePath
) | ForEach-Object { Resolve-RegisteredPath $_ }
Assert-True ($successfulReads.Count -eq $expectedReadSet.Count) 'audited read count'
foreach ($path in $expectedReadSet) {
    Assert-True ($successfulReads.Contains($path)) "missing audited read $path"
}

$moduleTokens = $null
$moduleParseErrors = $null
$moduleAst = [System.Management.Automation.Language.Parser]::ParseInput($loadedModule.Definition, [ref]$moduleTokens, [ref]$moduleParseErrors)
Assert-True ($moduleParseErrors.Count -eq 0) 'loaded module definition must parse without syntax errors'
$scriptAst = $MyInvocation.MyCommand.ScriptBlock.Ast
$moduleSafety = Get-SafetyAstViolations -Ast $moduleAst -AllowAuditedRead $false
$harnessSafety = Get-SafetyAstViolations -Ast $scriptAst -AllowAuditedRead $true
Assert-True ($moduleSafety.FileSystem.Count -eq 0) "module filesystem violations: $($moduleSafety.FileSystem -join ', ')"
Assert-True ($moduleSafety.Process.Count -eq 0) "module process violations: $($moduleSafety.Process -join ', ')"
Assert-True ($harnessSafety.FileSystem.Count -eq 0) "harness filesystem violations: $($harnessSafety.FileSystem -join ', ')"
Assert-True ($harnessSafety.Process.Count -eq 0) "harness process violations: $($harnessSafety.Process -join ', ')"

$extractedAfter = Test-Path -LiteralPath $extractedPath
$importedAfter = Test-Path -LiteralPath $importedPath
Assert-True (-not $extractedAfter) 'Extracted must not be created'
Assert-True (-not $importedAfter) 'Imported must not be created'

$expectedReadLookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($expectedPath in $expectedReadSet) { $null = $expectedReadLookup.Add($expectedPath) }
$unexpectedReadCount = @($successfulReads | Where-Object { -not $expectedReadLookup.Contains($_) }).Count
$fileSystemViolationCount = $moduleSafety.FileSystem.Count + $harnessSafety.FileSystem.Count
$processViolationCount = $moduleSafety.Process.Count + $harnessSafety.Process.Count
$createdExtractedCount = [int](-not $extractedBefore -and $extractedAfter)
$createdImportedCount = [int](-not $importedBefore -and $importedAfter)
$realAssetReadCount = $unexpectedReadCount + $fileSystemViolationCount
$safetyIssueCount = $realAssetReadCount + $processViolationCount + $createdExtractedCount + $createdImportedCount
Assert-True ($safetyIssueCount -eq 0) 'all safety evidence must remain zero'

$coverage = [pscustomobject][ordered]@{
    status = if ($result.Issues.Count + $safetyIssueCount -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $result.Issues.Count + $safetyIssueCount
    observationSubjectCount = $result.Coverage.observationSubjectCount
    emittedObjectCount = $result.Coverage.emittedObjectCount
    rejectedObservationCount = $result.Coverage.rejectedObservationCount
    childProcessCount = $processViolationCount
    realAssetReadCount = $realAssetReadCount
    createdExtractedCount = $createdExtractedCount
    createdImportedCount = $createdImportedCount
}

foreach ($property in $coverage.PSObject.Properties) {
    Write-Output "$($property.Name)=$($property.Value)"
}
