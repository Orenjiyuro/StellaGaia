Set-StrictMode -Version Latest

$script:Utf8 = [Text.UTF8Encoding]::new($false)
$script:Ordinal = [StringComparer]::Ordinal
$script:Registry = @(
    [pscustomobject][ordered]@{ artifactId = 'G5-I01'; path = 'Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json' }
    [pscustomobject][ordered]@{ artifactId = 'G5-I02'; path = 'Tools/AssetImport/Fixtures/RootGate/valid-c2-discovery-summary.json' }
    [pscustomobject][ordered]@{ artifactId = 'G5-I03'; path = 'Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json' }
    [pscustomobject][ordered]@{ artifactId = 'G5-I04'; path = 'docs/asset-migration/schemas/root-gate-summary.schema.json' }
)

function Get-G5Sha256 {
    param([byte[]] $Bytes)
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes)).ToLowerInvariant()
}

function ConvertTo-G5ScalarLine {
    param([string] $Name, [string] $Value)
    $length = $script:Utf8.GetByteCount($Value)
    "$Name`:$length`:$Value`n"
}

function Get-G5ArtifactEntryBytes {
    param([string] $Path, [string] $Sha256)
    $text = "G5ArtifactEntryV1`n"
    $text += ConvertTo-G5ScalarLine path $Path
    $text += ConvertTo-G5ScalarLine sha256 $Sha256
    $script:Utf8.GetBytes($text)
}

function Get-G5InputFingerprint {
    param([object[]] $Entries)
    $rows = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach ($entry in @($Entries)) {
        if ($entry.path -isnot [string] -or [string]::IsNullOrEmpty($entry.path) -or $entry.sha256 -cnotmatch '^[0-9a-f]{64}$' -or -not $seen.Add($entry.path)) {
            throw 'G5 input fingerprint entry invalid.'
        }
        $rows.Add($entry)
    }
    $rows.Sort([Comparison[object]]{ param($a, $b) $script:Ordinal.Compare([string]$a.path, [string]$b.path) })
    $text = "G5InputSetV1`nentries:$($rows.Count)`n"
    for ($index = 0; $index -lt $rows.Count; $index++) {
        $bytes = Get-G5ArtifactEntryBytes $rows[$index].path $rows[$index].sha256
        $text += "entries[$index]:$($bytes.Length):"
        $text += $script:Utf8.GetString($bytes)
        $text += "`n"
    }
    Get-G5Sha256 $script:Utf8.GetBytes($text)
}

function Test-G5ExactShape {
    param([AllowNull()] $Value, [string] $Shape)
    $null -ne $Value -and (@($Value.PSObject.Properties.Name) -join ',') -ceq $Shape
}

function ConvertFrom-G5JsonBytes {
    param([byte[]] $Bytes)
    if ($null -eq $Bytes -or $Bytes.Length -eq 0) { throw 'Empty JSON bytes.' }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { throw 'BOM forbidden.' }
    $text = $script:Utf8.GetString($Bytes)
    if ($text.Contains("`r") -or -not $text.EndsWith("`n") -or $text.EndsWith("`n`n")) { throw 'JSON bytes must use LF and exactly one final LF.' }
    $text | ConvertFrom-Json -Depth 100 -DateKind String
}

function New-G5InputSubjects {
    param([hashtable] $Hashes, [int] $FailedIndex = -1, [string] $ReasonCode = 'None')
    $rows = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $script:Registry.Count; $index++) {
        $status = if ($FailedIndex -eq -2) { 'NotEvaluated' } elseif ($FailedIndex -lt 0 -or $index -lt $FailedIndex) { 'Accepted' } elseif ($index -eq $FailedIndex) { 'InputFailure' } else { 'NotEvaluated' }
        $rows.Add([pscustomobject][ordered]@{
            artifactId = $script:Registry[$index].artifactId
            path = $script:Registry[$index].path
            sha256 = $Hashes[$script:Registry[$index].artifactId]
            terminalStatus = $status
            reasonCode = if ($index -eq $FailedIndex) { $ReasonCode } else { 'None' }
        })
    }
    [object[]]$rows
}

function New-G5Failure {
    param([hashtable] $Hashes, [int] $FailedIndex, [string] $ReasonCode, [string] $SubjectId)
    $evidence = if ($FailedIndex -ge 0) { @($script:Registry[$FailedIndex].path) } else { @() }
    [pscustomobject][ordered]@{
        gateStatus = 'Failed'
        rootSummary = $null
        inputSubjects = New-G5InputSubjects $Hashes $FailedIndex $ReasonCode
        inputFailures = @([pscustomobject][ordered]@{
            failureId = "G5Failure:${ReasonCode}:$SubjectId"
            subjectId = $SubjectId
            reasonCode = $ReasonCode
            evidence = $evidence
        })
        outputAccounting = [pscustomobject][ordered]@{ outputCandidateCount = 1; projectedOutputCount = 0; outputFailureCount = 1 }
        heavyOperationCount = 0
        executorLaunchCount = 0
        publicationWriteCount = 0
    }
}

function Test-G5NonNegativeIntegers {
    param($Value, [string[]] $Names)
    foreach ($name in $Names) {
        $property = $Value.PSObject.Properties[$name]
        if ($null -eq $property -or $property.Value -isnot [long] -or [long]$property.Value -lt 0) { return $false }
    }
    $true
}

function Test-G5C1Summary {
    param($Summary)
    if (-not (Test-G5ExactShape $Summary 'schemaVersion,generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,ledgerPath,toolVersions,operationIdentity,directChildSummaries,directChildReports,failureAttribution,nextAllowedAction,sourceCount,sourceFileCount,catalogedFileCount,explicitlyExcludedFileCount,sourceBytes,catalogedBytes,explicitlyExcludedBytes,sources,exclusions')) { return $false }
    if ($Summary.schemaVersion -cne '1.0.0' -or $Summary.snapshotId -isnot [string] -or [string]::IsNullOrEmpty($Summary.snapshotId) -or $Summary.inputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or $Summary.ledgerInputFingerprint -cnotmatch '^[0-9a-f]{64}$') { return $false }
    $names = @('sourceCount','sourceFileCount','catalogedFileCount','explicitlyExcludedFileCount','sourceBytes','catalogedBytes','explicitlyExcludedBytes')
    if (-not (Test-G5NonNegativeIntegers $Summary $names)) { return $false }
    if ([long]$Summary.sourceFileCount -ne [long]$Summary.catalogedFileCount + [long]$Summary.explicitlyExcludedFileCount) { return $false }
    if ([long]$Summary.sourceBytes -ne [long]$Summary.catalogedBytes + [long]$Summary.explicitlyExcludedBytes) { return $false }
    if (@($Summary.sources).Count -ne [long]$Summary.sourceCount -or @($Summary.exclusions).Count -ne [long]$Summary.explicitlyExcludedFileCount) { return $false }
    $sourceIds = [Collections.Generic.HashSet[string]]::new($script:Ordinal)
    [long]$sourceFileTotal = 0
    [long]$sourceByteTotal = 0
    foreach ($source in @($Summary.sources)) {
        if (-not (Test-G5ExactShape $source 'sourceId,sourceKind,rootFingerprint,sourceFileCount,sourceBytes')) { return $false }
        if ($source.sourceId -isnot [string] -or [string]::IsNullOrEmpty($source.sourceId) -or -not $sourceIds.Add($source.sourceId) -or $source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$') { return $false }
        if (-not (Test-G5NonNegativeIntegers $source @('sourceFileCount','sourceBytes'))) { return $false }
        $sourceFileTotal += [long]$source.sourceFileCount
        $sourceByteTotal += [long]$source.sourceBytes
    }
    [long]$excludedByteTotal = 0
    foreach ($exclusion in @($Summary.exclusions)) {
        if (-not (Test-G5ExactShape $exclusion 'sourceId,relativePath,sizeBytes,reason')) { return $false }
        if (-not $sourceIds.Contains([string]$exclusion.sourceId) -or $exclusion.relativePath -isnot [string] -or [string]::IsNullOrEmpty($exclusion.relativePath) -or $exclusion.reason -isnot [string] -or [string]::IsNullOrEmpty($exclusion.reason)) { return $false }
        if (-not (Test-G5NonNegativeIntegers $exclusion @('sizeBytes'))) { return $false }
        $excludedByteTotal += [long]$exclusion.sizeBytes
    }
    if ($sourceFileTotal -ne [long]$Summary.sourceFileCount -or $sourceByteTotal -ne [long]$Summary.sourceBytes -or $excludedByteTotal -ne [long]$Summary.explicitlyExcludedBytes) { return $false }
    $true
}

function Test-G5C2Summary {
    param($Summary)
    if (-not (Test-G5ExactShape $Summary 'schemaVersion,identity,provenance,directEvidence,coverage,failureAccounting,decision')) { return $false }
    if ($Summary.schemaVersion -cne '1.0.0' -or -not (Test-G5ExactShape $Summary.identity 'generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,discoveryInputFingerprint,discoveryArtifactFingerprint')) { return $false }
    if (
        -not (Test-G5ExactShape $Summary.provenance 'toolVersions,operationIdentity') -or
        -not (Test-G5ExactShape $Summary.directEvidence 'discoveryInputs,directChildSummaries,directChildReports') -or
        -not (Test-G5ExactShape $Summary.coverage.files 'catalogedFileCount,catalogedBytes,catalogedContainerCount,catalogedContainerBytes,nonContainerFileCount,nonContainerFileBytes,fileDiscoverySubjectCount,fileDiscoverySubjectBytes,notAttemptedFileCount,notAttemptedFileBytes,parsedFileCount,parsedFileBytes,opaqueFileCount,opaqueFileBytes,failedFileCount,failedFileBytes,fileDiscoveryConflictFileCount,fileDiscoveryConflictFileBytes') -or
        -not (Test-G5ExactShape $Summary.coverage.containers 'notAttemptedContainerCount,notAttemptedContainerBytes,parsedContainerCount,parsedContainerBytes,opaqueContainerCount,opaqueContainerBytes,failedContainerCount,failedContainerBytes,fileDiscoveryConflictContainerCount,fileDiscoveryConflictContainerBytes') -or
        -not (Test-G5ExactShape $Summary.coverage.objects 'objectObservationRowCount,acceptedObjectObservationRowCount,rejectedObjectObservationRowCount,excludedObjectObservationRowCount,correlationGroupCount,enumeratedObjectCount,observationConflictObjectCount,classifiedObjectCount,unclassifiedObjectCount,unresolvedDependencyCount') -or
        -not (Test-G5ExactShape $Summary.coverage.configuration 'configurationDiscoverySubjectCount,configurationCandidateCount,configurationConflictCount,parsedConfigurationCount,discoveredOpaqueConfigurationCount,encryptedConfigurationCount,requiresRuntimeTypeConfigurationCount,likelyServerDependentConfigurationCount,notConfigurationCount') -or
        -not (Test-G5ExactShape $Summary.coverage.canonical 'canonicalizedObjectCount,canonicalConflictObjectCount,canonicalGroupCount,exactDuplicateGroupCount,platformVariantGroupCount,unresolvedCanonicalGroupCount') -or
        -not (Test-G5ExactShape $Summary.coverage.dispatch 'dispatchEligibleObjectCount,assignedObjectCount,retainedForDiagnosisObjectCount,configurationOnlyObjectCount,audioObjectCount,environmentObjectCount,actorObjectCount,uiObjectCount,effectsObjectCount') -or
        -not (Test-G5ExactShape $Summary.failureAccounting 'inputSubjectCount,acceptedInputSubjectCount,notEvaluatedInputSubjectCount,inputObservationCount,acceptedInputObservationCount,rejectedInputObservationCount,inputFailureCount,excludedInputSubjectCount,excludedInputCount,contractFailureRecordCount,fileDiscoveryConflictRecordCount,observationConflictRecordCount,configurationConflictRecordCount,canonicalConflictRecordCount,outputCandidateCount,projectedOutputCount,outputFailureCount,excludedOutputCount,issueCount,gateStatus') -or
        -not (Test-G5ExactShape $Summary.decision 'failureAttribution,nextAllowedAction')
    ) { return $false }
    foreach ($name in @('inputFingerprint','ledgerInputFingerprint','discoveryInputFingerprint','discoveryArtifactFingerprint')) {
        if ($Summary.identity.$name -cnotmatch '^[0-9a-f]{64}$') { return $false }
    }
    if (-not (Test-G5ExactShape $Summary.coverage 'files,containers,objects,configuration,canonical,dispatch') -or $Summary.failureAccounting.gateStatus -cne 'Passed' -or [long]$Summary.failureAccounting.issueCount -ne 0) { return $false }
    $files = $Summary.coverage.files
    if ([long]$files.catalogedFileCount -ne [long]$files.catalogedContainerCount + [long]$files.nonContainerFileCount -or [long]$files.catalogedBytes -ne [long]$files.catalogedContainerBytes + [long]$files.nonContainerFileBytes) { return $false }
    if ([long]$files.fileDiscoverySubjectCount -ne [long]$files.notAttemptedFileCount + [long]$files.parsedFileCount + [long]$files.opaqueFileCount + [long]$files.failedFileCount + [long]$files.fileDiscoveryConflictFileCount) { return $false }
    if ([long]$files.fileDiscoverySubjectBytes -ne [long]$files.notAttemptedFileBytes + [long]$files.parsedFileBytes + [long]$files.opaqueFileBytes + [long]$files.failedFileBytes + [long]$files.fileDiscoveryConflictFileBytes) { return $false }
    $containers = $Summary.coverage.containers
    if ([long]$files.catalogedContainerCount -ne [long]$containers.notAttemptedContainerCount + [long]$containers.parsedContainerCount + [long]$containers.opaqueContainerCount + [long]$containers.failedContainerCount + [long]$containers.fileDiscoveryConflictContainerCount) { return $false }
    if ([long]$files.catalogedContainerBytes -ne [long]$containers.notAttemptedContainerBytes + [long]$containers.parsedContainerBytes + [long]$containers.opaqueContainerBytes + [long]$containers.failedContainerBytes + [long]$containers.fileDiscoveryConflictContainerBytes) { return $false }
    $dispatch = $Summary.coverage.dispatch
    if ([long]$dispatch.dispatchEligibleObjectCount -ne [long]$dispatch.assignedObjectCount + [long]$dispatch.retainedForDiagnosisObjectCount + [long]$dispatch.configurationOnlyObjectCount) { return $false }
    if ([long]$dispatch.assignedObjectCount -ne [long]$dispatch.audioObjectCount + [long]$dispatch.environmentObjectCount + [long]$dispatch.actorObjectCount + [long]$dispatch.uiObjectCount + [long]$dispatch.effectsObjectCount) { return $false }
    $true
}

function Test-G5C6Handoff {
    param($Handoff)
    if (-not (Test-G5ExactShape $Handoff 'schemaVersion,generatedAt,snapshotId,inputFingerprint,authoringReuseLedgerPath,authoringReuseLedgerSha256,familyDecisionPackagePath,familyDecisionPackageSha256,capabilityProjectionPath,capabilityProjectionSha256,familyConstructionCoverage,originalAssetBatchCoverage,stellaSora2AuthoringReady,failureAttribution,nextAllowedAction')) { return $false }
    if ($Handoff.schemaVersion -cne '1.0.0' -or $Handoff.inputFingerprint -cnotmatch '^[0-9a-f]{64}$' -or $Handoff.failureAttribution -cne 'None; C6 lifecycle contract passed.' -or $Handoff.nextAllowedAction -cne 'Provide only the current C6 G5 handoff to G5.') { return $false }
    $coverage = $Handoff.familyConstructionCoverage
    if ([long]$coverage.dispatchEligibleObjectCount -ne [long]$coverage.assignedFamilyMemberCount + [long]$coverage.retainedForDiagnosisObjectCount + [long]$coverage.configurationOnlyObjectCount) { return $false }
    if ([long]$coverage.dispatchEligibleObjectBytes -ne [long]$coverage.assignedFamilyMemberBytes + [long]$coverage.retainedForDiagnosisObjectBytes + [long]$coverage.configurationOnlyObjectBytes) { return $false }
    $original = $Handoff.originalAssetBatchCoverage
    if ([long]$original.reusableFamilyCount -gt [long]$original.totalFamilyCount -or [long]$original.reusableMemberCount -gt [long]$original.totalMemberCount -or [long]$original.reusableBytes -gt [long]$original.totalBytes) { return $false }
    $ready = $Handoff.stellaSora2AuthoringReady
    $required = [Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach ($id in @($ready.requiredCapabilityIds)) { if ($id -isnot [string] -or [string]::IsNullOrEmpty($id) -or -not $required.Add($id)) { return $false } }
    $seen = [Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach ($partition in @('satisfiedCapabilityIds','unsatisfiedCapabilityIds','blockedCapabilityIds')) {
        foreach ($id in @($ready.$partition)) { if (-not $required.Contains($id) -or -not $seen.Add($id)) { return $false } }
    }
    if ($seen.Count -ne $required.Count -or [bool]$ready.value -ne (@($ready.unsatisfiedCapabilityIds).Count -eq 0 -and @($ready.blockedCapabilityIds).Count -eq 0)) { return $false }
    $true
}

function ConvertTo-G5StructuredCoverage {
    param($Coverage)
    [pscustomobject][ordered]@{
        catalogedContainerCount = [long]$Coverage.files.catalogedContainerCount
        catalogedContainerBytes = [long]$Coverage.files.catalogedContainerBytes
        nonContainerFileCount = [long]$Coverage.files.nonContainerFileCount
        nonContainerFileBytes = [long]$Coverage.files.nonContainerFileBytes
        fileDiscoverySubjectCount = [long]$Coverage.files.fileDiscoverySubjectCount
        fileDiscoverySubjectBytes = [long]$Coverage.files.fileDiscoverySubjectBytes
        notAttemptedFileCount = [long]$Coverage.files.notAttemptedFileCount
        notAttemptedFileBytes = [long]$Coverage.files.notAttemptedFileBytes
        parsedFileCount = [long]$Coverage.files.parsedFileCount
        parsedFileBytes = [long]$Coverage.files.parsedFileBytes
        opaqueFileCount = [long]$Coverage.files.opaqueFileCount
        opaqueFileBytes = [long]$Coverage.files.opaqueFileBytes
        failedFileCount = [long]$Coverage.files.failedFileCount
        failedFileBytes = [long]$Coverage.files.failedFileBytes
        fileDiscoveryConflictFileCount = [long]$Coverage.files.fileDiscoveryConflictFileCount
        fileDiscoveryConflictFileBytes = [long]$Coverage.files.fileDiscoveryConflictFileBytes
        notAttemptedContainerCount = [long]$Coverage.containers.notAttemptedContainerCount
        notAttemptedContainerBytes = [long]$Coverage.containers.notAttemptedContainerBytes
        parsedContainerCount = [long]$Coverage.containers.parsedContainerCount
        parsedContainerBytes = [long]$Coverage.containers.parsedContainerBytes
        opaqueContainerCount = [long]$Coverage.containers.opaqueContainerCount
        opaqueContainerBytes = [long]$Coverage.containers.opaqueContainerBytes
        failedContainerCount = [long]$Coverage.containers.failedContainerCount
        failedContainerBytes = [long]$Coverage.containers.failedContainerBytes
        fileDiscoveryConflictContainerCount = [long]$Coverage.containers.fileDiscoveryConflictContainerCount
        fileDiscoveryConflictContainerBytes = [long]$Coverage.containers.fileDiscoveryConflictContainerBytes
        objectObservationRowCount = [long]$Coverage.objects.objectObservationRowCount
        acceptedObjectObservationRowCount = [long]$Coverage.objects.acceptedObjectObservationRowCount
        rejectedObjectObservationRowCount = [long]$Coverage.objects.rejectedObjectObservationRowCount
        excludedObjectObservationRowCount = [long]$Coverage.objects.excludedObjectObservationRowCount
        correlationGroupCount = [long]$Coverage.objects.correlationGroupCount
        enumeratedObjectCount = [long]$Coverage.objects.enumeratedObjectCount
        observationConflictObjectCount = [long]$Coverage.objects.observationConflictObjectCount
        classifiedObjectCount = [long]$Coverage.objects.classifiedObjectCount
        unclassifiedObjectCount = [long]$Coverage.objects.unclassifiedObjectCount
        unresolvedDependencyCount = [long]$Coverage.objects.unresolvedDependencyCount
        configurationCandidateCount = [long]$Coverage.configuration.configurationCandidateCount
        configurationConflictCount = [long]$Coverage.configuration.configurationConflictCount
        configurationParsedCount = [long]$Coverage.configuration.parsedConfigurationCount
        discoveredOpaqueConfigurationCount = [long]$Coverage.configuration.discoveredOpaqueConfigurationCount
        encryptedConfigurationCount = [long]$Coverage.configuration.encryptedConfigurationCount
        requiresRuntimeTypeConfigurationCount = [long]$Coverage.configuration.requiresRuntimeTypeConfigurationCount
        likelyServerDependentConfigurationCount = [long]$Coverage.configuration.likelyServerDependentConfigurationCount
        notConfigurationCount = [long]$Coverage.configuration.notConfigurationCount
        canonicalizedObjectCount = [long]$Coverage.canonical.canonicalizedObjectCount
        canonicalGroupCount = [long]$Coverage.canonical.canonicalGroupCount
        canonicalConflictObjectCount = [long]$Coverage.canonical.canonicalConflictObjectCount
        exactDuplicateGroupCount = [long]$Coverage.canonical.exactDuplicateGroupCount
        platformVariantGroupCount = [long]$Coverage.canonical.platformVariantGroupCount
        unresolvedCanonicalGroupCount = [long]$Coverage.canonical.unresolvedCanonicalGroupCount
        dispatchEligibleObjectCount = [long]$Coverage.dispatch.dispatchEligibleObjectCount
        assignedObjectCount = [long]$Coverage.dispatch.assignedObjectCount
        retainedForDiagnosisObjectCount = [long]$Coverage.dispatch.retainedForDiagnosisObjectCount
        configurationOnlyObjectCount = [long]$Coverage.dispatch.configurationOnlyObjectCount
        audioObjectCount = [long]$Coverage.dispatch.audioObjectCount
        environmentObjectCount = [long]$Coverage.dispatch.environmentObjectCount
        actorObjectCount = [long]$Coverage.dispatch.actorObjectCount
        uiObjectCount = [long]$Coverage.dispatch.uiObjectCount
        effectsObjectCount = [long]$Coverage.dispatch.effectsObjectCount
    }
}

function Invoke-G5RootDecisionGate {
    [CmdletBinding()]
    param([Parameter(Mandatory)] $InputFact)

    $hashes = @{}
    if (-not (Test-G5ExactShape $InputFact 'generatedAt,c1SummaryPath,c1SummaryBytes,c2SummaryPath,c2SummaryBytes,c6HandoffPath,c6HandoffBytes,rootSchemaPath,rootSchemaBytes,additionalC3C6Inputs')) {
        foreach ($row in $script:Registry) { $hashes[$row.artifactId] = $null }
        return New-G5Failure $hashes 0 InvalidArtifact G5Input
    }
    $bytes = [object[]]::new(4)
    $bytes[0] = $InputFact.c1SummaryBytes
    $bytes[1] = $InputFact.c2SummaryBytes
    $bytes[2] = $InputFact.c6HandoffBytes
    $bytes[3] = $InputFact.rootSchemaBytes
    $paths = @($InputFact.c1SummaryPath, $InputFact.c2SummaryPath, $InputFact.c6HandoffPath, $InputFact.rootSchemaPath)
    for ($index = 0; $index -lt 4; $index++) {
        if ($bytes[$index] -isnot [byte[]]) {
            $hashes[$script:Registry[$index].artifactId] = $null
            return New-G5Failure $hashes $index InvalidArtifact $script:Registry[$index].artifactId
        }
        $hashes[$script:Registry[$index].artifactId] = Get-G5Sha256 $bytes[$index]
        if ($paths[$index] -cne $script:Registry[$index].path) { return New-G5Failure $hashes $index InvalidArtifact $script:Registry[$index].artifactId }
    }
    if (@($InputFact.additionalC3C6Inputs).Count -ne 0) { return New-G5Failure $hashes -2 PolicyViolation G5Policy }
    if ($InputFact.generatedAt -isnot [string] -or $InputFact.generatedAt -cnotmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$') { return New-G5Failure $hashes -2 InvalidArtifact G5GeneratedAt }

    try { $c1 = ConvertFrom-G5JsonBytes $bytes[0] } catch { return New-G5Failure $hashes 0 InvalidArtifact 'G5-I01' }
    try { $c2 = ConvertFrom-G5JsonBytes $bytes[1] } catch { return New-G5Failure $hashes 1 InvalidArtifact 'G5-I02' }
    try { $c6 = ConvertFrom-G5JsonBytes $bytes[2] } catch { return New-G5Failure $hashes 2 InvalidArtifact 'G5-I03' }
    try { $null = ConvertFrom-G5JsonBytes $bytes[3]; $schemaText = $script:Utf8.GetString($bytes[3]) } catch { return New-G5Failure $hashes 3 InvalidArtifact 'G5-I04' }
    try { $c1Valid = Test-G5C1Summary $c1 } catch { $c1Valid = $false }
    if (-not $c1Valid) { return New-G5Failure $hashes 0 InvalidArtifact 'G5-I01' }
    try { $c2Valid = Test-G5C2Summary $c2 } catch { $c2Valid = $false }
    if (-not $c2Valid) { return New-G5Failure $hashes 1 ProjectionInvalid 'G5-I02' }
    try { $c6Valid = Test-G5C6Handoff $c6 } catch { $c6Valid = $false }
    if (-not $c6Valid) { return New-G5Failure $hashes 2 ProjectionInvalid 'G5-I03' }
    if ($c1.snapshotId -cne $c2.identity.snapshotId -or $c1.snapshotId -cne $c6.snapshotId) { return New-G5Failure $hashes 2 StaleFingerprint 'G5-I03' }
    if ([long]$c2.coverage.dispatch.dispatchEligibleObjectCount -ne [long]$c6.familyConstructionCoverage.dispatchEligibleObjectCount) { return New-G5Failure $hashes 2 ProjectionInvalid 'G5-I03' }

    $entries = for ($index = 0; $index -lt 4; $index++) {
        [pscustomobject][ordered]@{ path = $paths[$index]; sha256 = $hashes[$script:Registry[$index].artifactId] }
    }
    try { $inputFingerprint = Get-G5InputFingerprint $entries } catch { return New-G5Failure $hashes 0 StaleFingerprint G5InputSet }
    $directSummaryList = [Collections.Generic.List[object]]::new()
    $directSummaryList.Add([pscustomobject][ordered]@{ path = $paths[1]; sha256 = $hashes['G5-I02'] })
    $directSummaryList.Add([pscustomobject][ordered]@{ path = $paths[2]; sha256 = $hashes['G5-I03'] })
    $directSummaryList.Add([pscustomobject][ordered]@{ path = $paths[0]; sha256 = $hashes['G5-I01'] })
    $directSummaryList.Sort([Comparison[object]]{ param($a, $b) $script:Ordinal.Compare([string]$a.path, [string]$b.path) })
    $directSummaries = [object[]]$directSummaryList
    $root = [pscustomobject][ordered]@{
        schemaVersion = '2.0.0'
        generatedAt = $InputFact.generatedAt
        snapshotId = $c1.snapshotId
        inputFingerprint = $inputFingerprint
        toolVersions = @([pscustomobject][ordered]@{ toolName = 'g5-root-decision-gate'; version = '1.0.0' })
        directGateSummaries = $directSummaries
        directGateReports = @()
        corpusSnapshotComplete = [pscustomobject][ordered]@{
            value = [long]$c1.explicitlyExcludedFileCount -eq 0 -and [long]$c1.catalogedFileCount -eq [long]$c1.sourceFileCount -and [long]$c1.catalogedBytes -eq [long]$c1.sourceBytes
            catalogedFileCount = [long]$c1.catalogedFileCount
            sourceFileCount = [long]$c1.sourceFileCount
            catalogedBytes = [long]$c1.catalogedBytes
            sourceBytes = [long]$c1.sourceBytes
        }
        identity = [pscustomobject][ordered]@{
            discoveryInputFingerprint = $c2.identity.discoveryInputFingerprint
            discoveryArtifactFingerprint = $c2.identity.discoveryArtifactFingerprint
        }
        structuredObjectCoverage = ConvertTo-G5StructuredCoverage $c2.coverage
        failureAccounting = $c2.failureAccounting
        familyConstructionCoverage = $c6.familyConstructionCoverage
        originalAssetBatchCoverage = $c6.originalAssetBatchCoverage
        stellaSora2AuthoringReady = $c6.stellaSora2AuthoringReady
        failureAttribution = 'None; G5 freshness and projection contract passed.'
        nextAllowedAction = 'Run the independent C0-C6 Phase A completion audit.'
    }
    try {
        $rootText = (($root | ConvertTo-Json -Depth 100) -replace "`r`n", "`n") + "`n"
        if (-not ($rootText | Test-Json -Schema $schemaText -ErrorAction Stop)) { return New-G5Failure $hashes 3 ProjectionInvalid 'G5-O01' }
    } catch { return New-G5Failure $hashes 3 ProjectionInvalid 'G5-O01' }
    [pscustomobject][ordered]@{
        gateStatus = 'Passed'
        rootSummary = $root
        inputSubjects = New-G5InputSubjects $hashes
        inputFailures = @()
        outputAccounting = [pscustomobject][ordered]@{ outputCandidateCount = 1; projectedOutputCount = 1; outputFailureCount = 0 }
        heavyOperationCount = 0
        executorLaunchCount = 0
        publicationWriteCount = 0
    }
}

Export-ModuleMember -Function Invoke-G5RootDecisionGate
