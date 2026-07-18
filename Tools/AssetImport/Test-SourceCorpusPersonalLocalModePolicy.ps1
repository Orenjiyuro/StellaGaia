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
        [AllowEmptyString()]
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
        [AllowEmptyString()]
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

function Test-ExactPropertySet {
    param(
        [Parameter(Mandatory)]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string[]] $ExpectedNames
    )

    $actualNames = @($InputObject.PSObject.Properties.Name | Sort-Object)
    $expectedSorted = @($ExpectedNames | Sort-Object)
    return @(Compare-Object -ReferenceObject $expectedSorted -DifferenceObject $actualNames).Count -eq 0
}

function Assert-ExactRegistryIds {
    param(
        [Parameter(Mandatory)]
        [string] $RegistryName,

        [Parameter(Mandatory)]
        [string] $Text,

        [Parameter(Mandatory)]
        [string] $Pattern,

        [Parameter(Mandatory)]
        [string[]] $ExpectedIds
    )

    $actualIds = @([regex]::Matches($Text, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline) | ForEach-Object { $_.Groups[1].Value })
    $delta = @(Compare-Object -ReferenceObject @($ExpectedIds | Sort-Object) -DifferenceObject @($actualIds | Sort-Object))
    $duplicates = @($actualIds | Group-Object | Where-Object { $_.Count -ne 1 })
    if ($delta.Count -ne 0 -or $duplicates.Count -ne 0 -or $actualIds.Count -ne $ExpectedIds.Count) {
        Add-PolicyIssue "$RegistryName IDs are not exact, unique, and complete."
    }
}

function Test-PersonalLocalInputContract {
    param(
        [Parameter(Mandatory)]
        [object] $Locator,

        [Parameter(Mandatory)]
        [object] $Manifest
    )

    $issues = [System.Collections.Generic.List[string]]::new()
    $approvedKinds = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    $absoluteLocalPathPattern = '^(?:[A-Za-z]:[\\/]|\\\\)'

    if (-not (Test-ExactPropertySet -InputObject $Locator -ExpectedNames @('schemaVersion', 'manifestPath', 'baseline', 'sourceBoundary'))) {
        $issues.Add('locator shape')
        return $issues.ToArray()
    }
    if ($Locator.schemaVersion -cne '1.0.0' -or $Locator.manifestPath -notmatch $absoluteLocalPathPattern) {
        $issues.Add('locator identity')
    }
    if (-not (Test-ExactPropertySet -InputObject $Locator.baseline -ExpectedNames @('disposition', 'path'))) {
        $issues.Add('baseline shape')
    }
    elseif (($Locator.baseline.disposition -ceq 'Absent' -and $null -ne $Locator.baseline.path) -or
        ($Locator.baseline.disposition -ceq 'Present' -and ($Locator.baseline.path -notmatch $absoluteLocalPathPattern)) -or
        @('Absent', 'Present') -cnotcontains $Locator.baseline.disposition) {
        $issues.Add('baseline disposition')
    }
    if (-not (Test-ExactPropertySet -InputObject $Locator.sourceBoundary -ExpectedNames @('schemaVersion', 'sources')) -or
        $Locator.sourceBoundary.schemaVersion -cne '1.0.0' -or @($Locator.sourceBoundary.sources).Count -eq 0) {
        $issues.Add('source boundary shape')
        return $issues.ToArray()
    }
    if (-not (Test-ExactPropertySet -InputObject $Manifest -ExpectedNames @('schemaVersion', 'sources')) -or
        $Manifest.schemaVersion -cne '1.0.0') {
        $issues.Add('manifest shape')
        return $issues.ToArray()
    }

    $boundaryRows = @{}
    foreach ($row in @($Locator.sourceBoundary.sources)) {
        if (-not (Test-ExactPropertySet -InputObject $row -ExpectedNames @('sourceId', 'sourceKind', 'rootPath')) -or
            [string]::IsNullOrWhiteSpace($row.sourceId) -or $approvedKinds -cnotcontains $row.sourceKind -or
            $row.rootPath -notmatch $absoluteLocalPathPattern) {
            $issues.Add('invalid boundary row')
            continue
        }
        $key = $row.sourceId.ToLowerInvariant()
        if ($boundaryRows.ContainsKey($key)) {
            $issues.Add('duplicate boundary sourceId')
        }
        else {
            $boundaryRows[$key] = $row
        }
    }

    $manifestRows = @{}
    foreach ($row in @($Manifest.sources)) {
        if (-not (Test-ExactPropertySet -InputObject $row -ExpectedNames @('sourceId', 'sourceKind', 'rootPath')) -or
            [string]::IsNullOrWhiteSpace($row.sourceId) -or $approvedKinds -cnotcontains $row.sourceKind -or
            $row.rootPath -notmatch $absoluteLocalPathPattern) {
            $issues.Add('invalid manifest row')
            continue
        }
        $key = $row.sourceId.ToLowerInvariant()
        if ($manifestRows.ContainsKey($key)) {
            $issues.Add('duplicate manifest sourceId')
        }
        else {
            $manifestRows[$key] = $row
        }
    }

    foreach ($key in $boundaryRows.Keys) {
        if (-not $manifestRows.ContainsKey($key)) {
            $issues.Add('manifest omission')
            continue
        }
        $boundaryRow = $boundaryRows[$key]
        $manifestRow = $manifestRows[$key]
        if ($boundaryRow.sourceId -cne $manifestRow.sourceId -or
            $boundaryRow.sourceKind -cne $manifestRow.sourceKind -or
            -not [string]::Equals($boundaryRow.rootPath, $manifestRow.rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            $issues.Add('boundary/manifest mismatch')
        }
    }
    foreach ($key in $manifestRows.Keys) {
        if (-not $boundaryRows.ContainsKey($key)) {
            $issues.Add('extra manifest source')
        }
    }

    return $issues.ToArray()
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
    LocatorSchema = 'docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json'
}

$taskText = [ordered]@{}
foreach ($taskEntry in $taskDocuments.GetEnumerator()) {
    $taskText[$taskEntry.Key] = Read-PolicyDocument -RelativePath $taskEntry.Value
    Assert-ContainsLiteral -DocumentName $taskEntry.Key -Text $taskText[$taskEntry.Key] -Expected 'PersonalLocalMode'
}

foreach ($taskName in @('Package', 'Runbook', 'R81')) {
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected "[Environment]::GetFolderPath('LocalApplicationData')"
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
    Assert-DoesNotMatch -DocumentName $taskName -Text $taskText[$taskName] -Pattern '(?i)Read-Host' -Description 'interactive manifest-path prompt'
}

Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected '| PB-I03 | Fixed machine-local input locator and source boundary registry |'
Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected '| PB-SP06 manifest rows |'
Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected 'boundarySourceCount = boundaryMatchedCount + boundaryMissingOrMismatchedCount'
Assert-ContainsLiteral -DocumentName 'Package' -Text $taskText.Package -Expected 'manifestSourceCount = manifestMatchedCount + manifestExtraOrMismatchedCount'

Assert-ExactRegistryIds -RegistryName 'Artifact Registry' -Text $taskText.Package -Pattern '^\| ((?:PB-I0[1-3]|C1-(?:I0[1-6]|T01|O0[1-2]|E01))) \|' -ExpectedIds @(
    'PB-I01', 'PB-I02', 'PB-I03',
    'C1-I01', 'C1-I02', 'C1-I03', 'C1-I04', 'C1-I05', 'C1-I06',
    'C1-T01', 'C1-O01', 'C1-O02', 'C1-E01'
)
Assert-ExactRegistryIds -RegistryName 'Subject/Partition Registry' -Text $taskText.Package -Pattern '^\| (PB-SP0[1-6]) ' -ExpectedIds @(
    'PB-SP01', 'PB-SP02', 'PB-SP03', 'PB-SP04', 'PB-SP05', 'PB-SP06'
)
Assert-ExactRegistryIds -RegistryName 'Failure Transition Table' -Text $taskText.Package -Pattern '^\| (PB-FT(?:0[1-9]|1[0-2])) ' -ExpectedIds @(
    'PB-FT01', 'PB-FT02', 'PB-FT03', 'PB-FT04', 'PB-FT05', 'PB-FT06',
    'PB-FT07', 'PB-FT08', 'PB-FT09', 'PB-FT10', 'PB-FT11', 'PB-FT12'
)

Assert-DoesNotMatch -DocumentName 'CompletionRoadmap' -Text $taskText.CompletionRoadmap -Pattern '(?i)twelve exact human confirmations|PB-A01\s+(?:through|to|-)\s*PB-A12 confirmation rows' -Description 'active twelve-confirmation authorization semantics'
Assert-DoesNotMatch -DocumentName 'ProgramRoadmap' -Text $taskText.ProgramRoadmap -Pattern '(?i)12/12-equivalent confirmation|LO R8\.C1-2|Work Package R8\.4 - Authorize a matching run' -Description 'legacy R8 second-run/external-approval lifecycle'

if (-not [string]::IsNullOrWhiteSpace($taskText.LocatorSchema)) {
    try {
        $locatorSchema = $taskText.LocatorSchema | ConvertFrom-Json
        if (-not (Test-ExactPropertySet -InputObject $locatorSchema.properties -ExpectedNames @('schemaVersion', 'manifestPath', 'baseline', 'sourceBoundary'))) {
            Add-PolicyIssue 'LocatorSchema does not freeze the exact top-level locator shape.'
        }
        if ($locatorSchema.additionalProperties -ne $false) {
            Add-PolicyIssue 'LocatorSchema must reject unknown top-level properties.'
        }
        if (@(Compare-Object -ReferenceObject @('baseline', 'manifestPath', 'schemaVersion', 'sourceBoundary') -DifferenceObject @($locatorSchema.required | Sort-Object)).Count -ne 0) {
            Add-PolicyIssue 'LocatorSchema does not require every top-level locator field exactly once.'
        }
        if (-not (Test-ExactPropertySet -InputObject $locatorSchema.properties.baseline.properties -ExpectedNames @('disposition', 'path')) -or
            $locatorSchema.properties.baseline.additionalProperties -ne $false) {
            Add-PolicyIssue 'LocatorSchema does not freeze the baseline object.'
        }
        if (-not (Test-ExactPropertySet -InputObject $locatorSchema.properties.sourceBoundary.properties -ExpectedNames @('schemaVersion', 'sources')) -or
            $locatorSchema.properties.sourceBoundary.additionalProperties -ne $false) {
            Add-PolicyIssue 'LocatorSchema does not freeze the sourceBoundary object.'
        }
        if (-not (Test-ExactPropertySet -InputObject $locatorSchema.'$defs'.sourceRow.properties -ExpectedNames @('sourceId', 'sourceKind', 'rootPath')) -or
            $locatorSchema.'$defs'.sourceRow.additionalProperties -ne $false) {
            Add-PolicyIssue 'LocatorSchema does not freeze exact source rows.'
        }
    }
    catch {
        Add-PolicyIssue "LocatorSchema is not valid JSON: $($_.Exception.Message)"
    }
}

$locatorSchemaHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepositoryRoot $taskDocuments.LocatorSchema)).Hash.ToLowerInvariant()
$policyTestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $PSCommandPath).Hash.ToLowerInvariant()
$preflightModuleHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $RepositoryRoot 'Tools/AssetImport/SourceCorpusGate.psm1')).Hash.ToLowerInvariant()
foreach ($taskName in @('Package', 'R74', 'R75', 'R81')) {
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected $locatorSchemaHash
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected $policyTestHash
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected $preflightModuleHash
}
foreach ($taskName in @('Package', 'Runbook', 'R74', 'R81')) {
    Assert-ContainsLiteral -DocumentName $taskName -Text $taskText[$taskName] -Expected 'Invoke-SourceCorpusPersonalLocalModePreflight'
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
    'derivedInputLocatorState=',
    'derivedSourceBoundaryState=',
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

$positiveLocator = [pscustomobject][ordered]@{
    schemaVersion = '1.0.0'
    manifestPath = 'C:\Local\source-root-manifest.json'
    baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
    sourceBoundary = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        sources = @(
            [pscustomobject][ordered]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; rootPath = 'C:\Games\StellaSora' },
            [pscustomobject][ordered]@{ sourceId = 'android-data'; sourceKind = 'AndroidDataOrCache'; rootPath = 'D:\Android\StellaSora' }
        )
    }
}
$positiveManifest = [pscustomobject][ordered]@{
    schemaVersion = '1.0.0'
    sources = @($positiveLocator.sourceBoundary.sources)
}

$semanticVectors = [ordered]@{
    Positive = @($positiveLocator, $positiveManifest)
    MissingSource = @($positiveLocator, ([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @($positiveManifest.sources[0]) }))
    ExtraSource = @($positiveLocator, ([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @($positiveManifest.sources + [pscustomobject][ordered]@{ sourceId = 'extra'; sourceKind = 'AndroidApk'; rootPath = 'E:\Extra' }) }))
    KindMismatch = @($positiveLocator, ([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @([pscustomobject][ordered]@{ sourceId = 'pc-install'; sourceKind = 'PcPatchOrCache'; rootPath = 'C:\Games\StellaSora' }, $positiveManifest.sources[1]) }))
    PathMismatch = @($positiveLocator, ([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @([pscustomobject][ordered]@{ sourceId = 'pc-install'; sourceKind = 'PcInstall'; rootPath = 'C:\Games\Other' }, $positiveManifest.sources[1]) }))
    DuplicateId = @(([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; manifestPath = 'C:\Local\source-root-manifest.json'; baseline = $positiveLocator.baseline; sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @($positiveLocator.sourceBoundary.sources + [pscustomobject][ordered]@{ sourceId = 'PC-INSTALL'; sourceKind = 'PcInstall'; rootPath = 'C:\Games\StellaSora' }) } }), $positiveManifest)
    InvalidBaseline = @(([pscustomobject][ordered]@{ schemaVersion = '1.0.0'; manifestPath = 'C:\Local\source-root-manifest.json'; baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = 'C:\Local\baseline.json' }; sourceBoundary = $positiveLocator.sourceBoundary }), $positiveManifest)
}

foreach ($vector in $semanticVectors.GetEnumerator()) {
    $vectorIssues = @(Test-PersonalLocalInputContract -Locator $vector.Value[0] -Manifest $vector.Value[1])
    if ($vector.Key -ceq 'Positive' -and $vectorIssues.Count -ne 0) {
        Add-PolicyIssue "Positive locator semantic vector failed: $($vectorIssues -join ', ')"
    }
    elseif ($vector.Key -cne 'Positive' -and $vectorIssues.Count -eq 0) {
        Add-PolicyIssue "Negative locator semantic vector unexpectedly passed: $($vector.Key)"
    }
}

$preflightModulePath = Join-Path $RepositoryRoot 'Tools/AssetImport/SourceCorpusGate.psm1'
$preflightModule = Import-Module $preflightModulePath -Force -PassThru
$requiredPreflightCommands = @(
    'Get-SourceCorpusPersonalLocalModeDerivedState',
    'Compare-SourceCorpusPersonalLocalModeDerivedState',
    'Invoke-SourceCorpusPersonalLocalModePreflight'
)
$missingPreflightCommands = @($requiredPreflightCommands | Where-Object {
    $null -eq (Get-Command -Name $_ -Module $preflightModule.Name -ErrorAction SilentlyContinue)
})
foreach ($missingCommand in $missingPreflightCommands) {
    Add-PolicyIssue "SourceCorpusGate is missing reusable PersonalLocalMode command: $missingCommand"
}

$preflightSyntheticVectorCount = 0
if ($missingPreflightCommands.Count -eq 0) {
    $syntheticRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('stella-personal-local-preflight-' + [guid]::NewGuid().ToString('N'))
    try {
        $sourceDirectory = Join-Path $syntheticRoot 'android-data'
        $apkPath = Join-Path $syntheticRoot 'client.apk'
        $manifestPath = Join-Path $syntheticRoot 'manifest.json'
        $locatorPath = Join-Path $syntheticRoot 'locator.json'
        $outputRoot = Join-Path $syntheticRoot 'output/C1'
        New-Item -ItemType Directory -Path $sourceDirectory -Force | Out-Null
        [System.IO.File]::WriteAllBytes((Join-Path $sourceDirectory 'data.bin'), [byte[]](1, 2, 3, 4))
        [System.IO.File]::WriteAllBytes($apkPath, [byte[]](5, 6, 7))

        $sources = @(
            [pscustomobject][ordered]@{ sourceId = 'android-data'; sourceKind = 'AndroidDataOrCache'; rootPath = $sourceDirectory },
            [pscustomobject][ordered]@{ sourceId = 'android-apk'; sourceKind = 'AndroidApk'; rootPath = $apkPath }
        )
        $manifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
        $locator = [pscustomobject][ordered]@{
            schemaVersion = '1.0.0'
            manifestPath = $manifestPath
            baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
            sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
        }
        [System.IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        [System.IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))

        $derivedState = Get-SourceCorpusPersonalLocalModeDerivedState `
            -InputLocatorPath $locatorPath `
            -LocatorSchemaPath (Join-Path $RepositoryRoot 'docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json') `
            -OutputRoot $outputRoot `
            -MetadataTimeoutSeconds 10
        $preflightSyntheticVectorCount++
        if ($derivedState.registeredSourceKindCount -ne 4 -or
            @($derivedState.derivedManifestSourceSet | Where-Object sourceKind -CEQ 'AndroidDataOrCache').Count -ne 1) {
            Add-PolicyIssue 'Reusable preflight does not derive source-kind vocabulary from the registered schema.'
        }
        $preflightSyntheticVectorCount++
        if ($derivedState.sourceFileMetadataCount -ne 2 -or
            $derivedState.sourceByteMetadataTotal -ne 7 -or
            @($derivedState.derivedManifestSourceSet | Where-Object sourceKind -CEQ 'AndroidApk').Count -ne 1) {
            Add-PolicyIssue 'Reusable preflight does not conserve synthetic directory and exact APK file roots.'
        }

        $comparison = Compare-SourceCorpusPersonalLocalModeDerivedState -ExpectedState $derivedState -ActualState $derivedState
        $preflightSyntheticVectorCount++
        if (-not $comparison.unchanged -or $comparison.mismatchCount -ne 0) {
            Add-PolicyIssue 'Reusable final recheck rejects an unchanged derived state.'
        }
        $driftedState = $derivedState | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $driftedState.sourceFileMetadataCount++
        $driftComparison = Compare-SourceCorpusPersonalLocalModeDerivedState -ExpectedState $derivedState -ActualState $driftedState
        if ($driftComparison.unchanged -or $driftComparison.mismatchCount -eq 0) {
            Add-PolicyIssue 'Reusable final recheck does not reject derived metadata drift.'
        }

        $mismatchedManifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = @($sources[0]) }
        [System.IO.File]::WriteAllText($manifestPath, ($mismatchedManifest | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($false))
        $preflightSyntheticVectorCount++
        $boundaryMismatchRejected = $false
        try {
            Get-SourceCorpusPersonalLocalModeDerivedState `
                -InputLocatorPath $locatorPath `
                -LocatorSchemaPath (Join-Path $RepositoryRoot 'docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json') `
                -OutputRoot $outputRoot `
                -MetadataTimeoutSeconds 10 | Out-Null
        }
        catch {
            $boundaryMismatchRejected = $true
        }
        if (-not $boundaryMismatchRejected) {
            Add-PolicyIssue 'Reusable preflight accepts a synthetic boundary/manifest mismatch.'
        }

        $preflightSyntheticVectorCount++
        if (Test-Path -LiteralPath $outputRoot) {
            Add-PolicyIssue 'Reusable preflight created its synthetic output root.'
        }
    }
    catch {
        Add-PolicyIssue "Reusable PersonalLocalMode synthetic preflight failed: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path -LiteralPath $syntheticRoot) {
            Remove-Item -LiteralPath $syntheticRoot -Recurse -Force
        }
    }
}
if ($preflightSyntheticVectorCount -ne 5) {
    Add-PolicyIssue "Reusable PersonalLocalMode preflight synthetic vector count is $preflightSyntheticVectorCount instead of 5."
}

$taskResult = [pscustomobject][ordered]@{
    status = if ($taskIssues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $taskIssues.Count
    issues = $taskIssues.ToArray()
    checkedDocumentCount = $taskDocuments.Count
    semanticVectorCount = $semanticVectors.Count
    preflightSyntheticVectorCount = $preflightSyntheticVectorCount
    registrySemanticCheckCount = 3
    realInputAccessCount = 0
    processLaunchCount = 0
    createdOutputCount = 0
}

$taskResult | ConvertTo-Json -Compress -Depth 10
if ($taskIssues.Count -ne 0) {
    exit 1
}
