[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CergPreflightUtf8NoBom = [System.Text.UTF8Encoding]::new($false)

function ConvertTo-CergPreflightCanonicalJson {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) {
        $normalized = $Value.Normalize([System.Text.NormalizationForm]::FormC)
        if ($normalized.Contains([char]0)) { throw 'Canonical strings must not contain U+0000.' }
        return [System.Text.Json.JsonSerializer]::Serialize([object]$normalized, [string], [System.Text.Json.JsonSerializerOptions]::new())
    }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64]) {
        return [System.Convert]::ToString($Value, [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($Value -is [decimal] -or $Value -is [double] -or $Value -is [single]) {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number)) { throw 'Canonical numbers must be finite.' }
        return $number.ToString('R', [System.Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant()
    }
    if ($Value -is [System.Collections.IDictionary]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($key in $Value.Keys) { $parts.Add((ConvertTo-CergPreflightCanonicalJson ([string]$key)) + ':' + (ConvertTo-CergPreflightCanonicalJson $Value[$key])) }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [pscustomobject]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($property in $Value.PSObject.Properties) { $parts.Add((ConvertTo-CergPreflightCanonicalJson $property.Name) + ':' + (ConvertTo-CergPreflightCanonicalJson $property.Value)) }
        return '{' + ($parts -join ',') + '}'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $parts = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $Value) { $parts.Add((ConvertTo-CergPreflightCanonicalJson $item)) }
        return '[' + ($parts -join ',') + ']'
    }
    throw "Unsupported canonical JSON value type: $($Value.GetType().FullName)"
}

function Get-CergPreflightStructuredSha256 {
    param([Parameter(Mandatory = $true)][string]$DomainTag, [Parameter(Mandatory = $true)][object]$Payload)
    $bytes = $script:CergPreflightUtf8NoBom.GetBytes((ConvertTo-CergPreflightCanonicalJson @($DomainTag, $Payload)))
    return ([System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

function Assert-CergPreflightExactProperties {
    param([AllowNull()][object]$Value, [string[]]$Names, [string]$Label)
    if ($null -eq $Value) { throw "PreflightConsumerContractFailure: $Label is null." }
    $actual = @($Value.PSObject.Properties.Name)
    if (($actual -join '|') -cne ($Names -join '|')) {
        throw "PreflightConsumerContractFailure: $Label fields/order differ; expected $($Names -join ',')."
    }
}

function Get-CergPreflightAbsolutePath {
    param([AllowNull()][object]$Value, [string]$Label)
    $path = [string]$Value
    if ([string]::IsNullOrWhiteSpace($path) -or -not [System.IO.Path]::IsPathRooted($path) -or $path.IndexOfAny([char[]]'*?[]{}') -ge 0) {
        throw "PreflightConsumerContractFailure: $Label must be one selector-free private absolute path."
    }
    return [System.IO.Path]::GetFullPath($path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Test-CergPreflightContainedPath {
    param([string]$Leaf, [string]$Root)
    return $Leaf.StartsWith($Root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-CergPreflightSortedIds {
    param([object[]]$Values, [string]$Label)
    $ids = [string[]]@($Values | ForEach-Object { ([string]$_).Normalize([System.Text.NormalizationForm]::FormC) })
    [System.Array]::Sort($ids, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $ids.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($ids[$i]) -or ($i -gt 0 -and $ids[$i] -ceq $ids[$i - 1])) {
            throw "PreflightConsumerContractFailure: $Label contains an empty or Duplicate identity."
        }
    }
    return $ids
}

function Get-CergPreflightOrdinalSortedStrings {
    param([object[]]$Values)
    $result = [string[]]@($Values | ForEach-Object { [string]$_ })
    [System.Array]::Sort($result, [System.StringComparer]::Ordinal)
    return $result
}

function Assert-CergPreflightOrdinalMemberRows {
    param([object[]]$Rows, [string]$Label)
    $actual = [object[]]@($Rows)
    $sorted = [object[]]@($actual)
    [System.Array]::Sort($sorted, [System.Collections.Generic.Comparer[object]]::Create(
        [System.Comparison[object]]{ param($left, $right) [string]::CompareOrdinal([string]$left.stagingPortableRelativePath, [string]$right.stagingPortableRelativePath) }
    ))
    for ($i = 0; $i -lt $actual.Count; $i++) {
        if ([string]$actual[$i].stagingPortableRelativePath -cne [string]$sorted[$i].stagingPortableRelativePath) {
            throw "PreflightConsumerContractFailure: $Label must already be StringComparer.Ordinal sorted; constructors may not repair its order."
        }
    }
}

function Assert-CergPreflightOrdinalStringList {
    param([object[]]$Values, [string]$Label)
    $actual = [string[]]@($Values | ForEach-Object { [string]$_ })
    $sorted = [string[]]@($actual)
    [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
    for ($i = 0; $i -lt $actual.Count; $i++) {
        if ($actual[$i] -cne $sorted[$i] -or ($i -gt 0 -and $actual[$i] -ceq $actual[$i - 1])) {
            throw "PreflightConsumerContractFailure: $Label must be duplicate-free and StringComparer.Ordinal sorted."
        }
    }
}

function Assert-CergPreflightP02Ordering {
    param([object]$Value, [string]$Label)
    Assert-CergPreflightOrdinalMemberRows @($Value.stagingPlan.memberRows) "$Label.stagingPlan.memberRows"
    Assert-CergPreflightOrdinalStringList @($Value.sourceRootBindings | ForEach-Object sourceId) "$Label.sourceRootBindings"
    Assert-CergPreflightOrdinalStringList @($Value.implementationBindings | ForEach-Object implementationId) "$Label.implementationBindings"
    Assert-CergPreflightOrdinalStringList @($Value.operation.obligationRefIds) "$Label.operation.obligationRefIds"
    Assert-CergPreflightOrdinalStringList @($Value.operation.implementationRefIds) "$Label.operation.implementationRefIds"
    Assert-CergPreflightOrdinalStringList @($Value.operation.inputMemberRefIds) "$Label.operation.inputMemberRefIds"
    Assert-CergPreflightOrdinalStringList @($Value.operation.expectedSubjectKinds) "$Label.operation.expectedSubjectKinds"
    Assert-CergPreflightOrdinalStringList @($Value.operation.expectedRelationshipKinds) "$Label.operation.expectedRelationshipKinds"
}

function Assert-CergLo1PreflightConsumerContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][object]$Candidate,
        [Parameter(Mandatory = $true)][object]$Preflight,
        [AllowNull()][object]$Freshness,
        [string]$FreshnessEvidencePath,
        [string]$StagingInventoryTemporaryPath,
        [string]$StagingInventoryPath
    )

    $isR2P02 = $Preflight.schemaVersion -ceq 'cerg-lo-cerg1-preflight/1.6.0'
    $topFields = if($isR2P02){@('schemaVersion','artifactId','candidateLockSha256','freshnessEvidenceSha256','freshnessCheckRunId','freshnessValidatorFinishedAtUtc','candidateContractHeadCommit','freshnessContractHeadCommit','contractHeadCommit','selectedCandidateId','createdAt','sourceRootBindings','implementationBindings','operation','aggregateLimits','stagingPlan','status','nextAction')}else{@('schemaVersion','artifactId','candidateLockSha256','contractHeadCommit','selectedCandidateId','createdAt','sourceRootBindings','implementationBindings','operation','aggregateLimits','stagingPlan','status','nextAction')}
    $stagingFields = @('attemptPrivateAbsoluteRoot','stagingInputPortablePath','stagingInputPrivateAbsolutePath','stagingInventoryTemporaryPath','stagingInventoryTemporaryPrivateAbsolutePath','stagingInventoryPath','stagingInventoryPrivateAbsolutePath','workPortablePath','workPrivateAbsolutePath','outputPortablePath','outputPrivateAbsolutePath','memberRows','memberCount','byteCount','memberSetFingerprint')
    $operationFields = @('operationId','obligationRefIds','implementationRefIds','inputMemberRefIds','expectedSubjectKinds','expectedRelationshipKinds','sourceReadMaxFiles','sourceReadMaxBytes','maxDurationSeconds','maxResultRows','maxOutputFiles','maxOutputBytes','stagingInputPortablePath','outputPortablePath','workPortablePath')
    $aggregateFields = @('sourceReadMaxFiles','sourceReadMaxBytes','maxDurationSeconds','maxResultRows','maxOutputFiles','maxOutputBytes')
    $memberFields = @('sourceMemberRefId','sourceId','sourcePortableRelativePath','stagingPortableRelativePath','byteCount','sha256')
    $rootBindingFields = @('sourceId','privateAbsoluteReadOnlyRoot','rootFingerprint')
    $implementationFields = @('artifactId','implementationId','implementationRole','implementationVersion','pathKind','portableTrackedPath','privateAbsoluteLeafPath','implementationByteCount','implementationSha256','runtimePrivateAbsoluteLeafPath','runtimeByteCount','runtimeSha256','orderedArgumentTokens')

    Assert-CergPreflightExactProperties $Preflight $topFields 'P01'
    Assert-CergPreflightExactProperties $Preflight.stagingPlan $stagingFields 'P01.stagingPlan'
    Assert-CergPreflightExactProperties $Preflight.operation $operationFields 'P01.operation'
    Assert-CergPreflightExactProperties $Preflight.aggregateLimits $aggregateFields 'P01.aggregateLimits'
    foreach ($row in @($Preflight.stagingPlan.memberRows)) { Assert-CergPreflightExactProperties $row $memberFields 'P01.stagingPlan.memberRows[]' }
    foreach ($row in @($Preflight.sourceRootBindings)) { Assert-CergPreflightExactProperties $row $rootBindingFields 'P01.sourceRootBindings[]' }
    foreach ($row in @($Preflight.implementationBindings)) { Assert-CergPreflightExactProperties $row $implementationFields 'P01.implementationBindings[]' }

    $identityValid = ($Preflight.schemaVersion -ceq 'cerg-lo-cerg1-preflight/1.4.0' -and $Preflight.artifactId -ceq 'LO-CERG1-P01' -and $Preflight.nextAction -ceq 'RequestExactHumanConfirmationForLOCERG1') -or
        ($isR2P02 -and $Preflight.artifactId -ceq 'LO-CERG1-P02' -and $Preflight.nextAction -ceq 'RequestExactHumanConfirmationForR2P02')
    if (-not $identityValid -or $Preflight.status -cne 'Green') {
        throw 'PreflightConsumerContractFailure: P01 fixed identity/status fields are invalid.'
    }
    if ($Candidate.status -cne 'Passed' -or $Candidate.selectedCandidateId -cne $Preflight.selectedCandidateId) {
        throw 'PreflightConsumerContractFailure: candidate/P01 status or identity does not match.'
    }

    $attemptRoot = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.attemptPrivateAbsoluteRoot 'attemptPrivateAbsoluteRoot'
    $privatePaths = [ordered]@{
        stagingInput = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.stagingInputPrivateAbsolutePath 'stagingInputPrivateAbsolutePath'
        inventoryTemporary = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath 'stagingInventoryTemporaryPrivateAbsolutePath'
        inventory = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.stagingInventoryPrivateAbsolutePath 'stagingInventoryPrivateAbsolutePath'
        work = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.workPrivateAbsolutePath 'workPrivateAbsolutePath'
        output = Get-CergPreflightAbsolutePath $Preflight.stagingPlan.outputPrivateAbsolutePath 'outputPrivateAbsolutePath'
    }
    $distinct = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $privatePaths.GetEnumerator()) {
        if (-not (Test-CergPreflightContainedPath $entry.Value $attemptRoot) -or -not $distinct.Add($entry.Value)) {
            throw 'PreflightConsumerContractFailure: private staging paths must be distinct descendants of attemptPrivateAbsoluteRoot.'
        }
    }
    $derivedPrivatePaths = @{
        stagingInput = [System.IO.Path]::Combine($attemptRoot, 'Input')
        inventoryTemporary = [System.IO.Path]::Combine($attemptRoot, 'staging-inventory.json.tmp')
        inventory = [System.IO.Path]::Combine($attemptRoot, 'staging-inventory.json')
        work = [System.IO.Path]::Combine($attemptRoot, 'Work')
        output = [System.IO.Path]::Combine($attemptRoot, 'Output')
    }
    foreach ($name in $privatePaths.Keys) {
        if ($privatePaths[$name] -cne $derivedPrivatePaths[$name]) { throw "PreflightConsumerContractFailure: $name is not the constructor-derived private path." }
    }
    foreach ($binding in @($Preflight.sourceRootBindings)) {
        $sourceRoot = Get-CergPreflightAbsolutePath $binding.privateAbsoluteReadOnlyRoot 'sourceRootBindings.privateAbsoluteReadOnlyRoot'
        if ((Test-CergPreflightContainedPath $attemptRoot $sourceRoot) -or (Test-CergPreflightContainedPath $sourceRoot $attemptRoot) -or $sourceRoot -ceq $attemptRoot) {
            throw 'PreflightConsumerContractFailure: attempt-owned staging and source roots overlap.'
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($StagingInventoryTemporaryPath) -and
        (Get-CergPreflightAbsolutePath $StagingInventoryTemporaryPath 'StagingInventoryTemporaryPath') -cne $privatePaths.inventoryTemporary) {
        throw 'PreflightConsumerContractFailure: TG01 temporary inventory argument differs from P01.'
    }
    if (-not [string]::IsNullOrWhiteSpace($StagingInventoryPath) -and
        (Get-CergPreflightAbsolutePath $StagingInventoryPath 'StagingInventoryPath') -cne $privatePaths.inventory) {
        throw 'PreflightConsumerContractFailure: TG01 final inventory argument differs from P01.'
    }

    $portablePairs = @(
        @($Preflight.operation.stagingInputPortablePath, $Preflight.stagingPlan.stagingInputPortablePath),
        @($Preflight.operation.workPortablePath, $Preflight.stagingPlan.workPortablePath),
        @($Preflight.operation.outputPortablePath, $Preflight.stagingPlan.outputPortablePath)
    )
    foreach ($pair in $portablePairs) { if ([string]$pair[0] -cne [string]$pair[1]) { throw 'PreflightConsumerContractFailure: operation/staging portable path mapping differs.' } }
    foreach ($name in $aggregateFields) { if ([int64]$Preflight.operation.$name -ne [int64]$Preflight.aggregateLimits.$name) { throw "PreflightConsumerContractFailure: operation/aggregate limit $name differs." } }

    if($isR2P02){
        if($null-eq$Freshness-or$Freshness.schemaVersion-cne'cerg-lo-cerg1-r2-freshness/1.0.0'-or$Freshness.artifactId-cne'LO-CERG1-R2-F01'-or$Freshness.status-cne'Green'){throw'PreflightConsumerContractFailure: R2 freshness artifact is missing or non-Green.'}
        if($Preflight.freshnessCheckRunId-cne$Freshness.checkRunId-or$Preflight.freshnessValidatorFinishedAtUtc-cne$Freshness.validatorFinishedAtUtc){throw'PreflightConsumerContractFailure: R2 freshness binding fields differ.'}
        if($Preflight.candidateLockSha256-cne$Freshness.candidateLockSha256-or$Preflight.candidateContractHeadCommit-cne$Candidate.contractHeadCommit-or$Preflight.freshnessContractHeadCommit-cne$Freshness.contractHeadCommit){throw 'PreflightConsumerContractFailure: R2 candidate/freshness HEAD domains or candidate binding differ.'}
        if([string]::IsNullOrWhiteSpace($FreshnessEvidencePath)-or-not[IO.File]::Exists($FreshnessEvidencePath)){throw'PreflightConsumerContractFailure: R2 freshness artifact path is required.'}
        $freshHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $FreshnessEvidencePath).Hash.ToLowerInvariant()
        if($Preflight.freshnessEvidenceSha256-cne$freshHash){throw'PreflightConsumerContractFailure: R2 freshness raw SHA differs.'}
        $candidateSelectors=@(Get-CergPreflightOrdinalSortedStrings @($Candidate.sourceMembers|ForEach-Object{"$($_.sourceId)$([char]31)$($_.portableRelativePath)"}))
        $freshSelectors=@(Get-CergPreflightOrdinalSortedStrings @($Freshness.currentMembers|ForEach-Object{"$($_.sourceId)$([char]31)$($_.portableRelativePath)"}))
        if(($candidateSelectors-join'|')-cne($freshSelectors-join'|')){throw'PreflightConsumerContractFailure: R2 freshness selectors differ from the locked candidate.'}
        $members=@($Freshness.currentMembers|ForEach-Object{[pscustomobject]@{memberId=$_.memberId;sourceId=$_.sourceId;portableRelativePath=$_.portableRelativePath;sizeBytes=[int64]$_.byteCount;sha256=$_.sha256}})
    } else {
        $members = @($Candidate.sourceMembers)
    }
    $rows = @($Preflight.stagingPlan.memberRows)
    if($isR2P02){ Assert-CergPreflightP02Ordering $Preflight 'P02' }
    if ($members.Count -eq 0 -or $rows.Count -ne $members.Count -or [int64]$Preflight.stagingPlan.memberCount -ne $members.Count) {
        throw 'PreflightConsumerContractFailure: SourceMember/staging row cardinality differs.'
    }
    $memberIds = @(Get-CergPreflightSortedIds @($members | ForEach-Object memberId) 'candidate SourceMembers')
    $rowIds = @(Get-CergPreflightSortedIds @($rows | ForEach-Object sourceMemberRefId) 'staging rows')
    $operationIds = @(Get-CergPreflightSortedIds @($Preflight.operation.inputMemberRefIds) 'operation inputs')
    if (($memberIds -join '|') -cne ($rowIds -join '|') -or ($memberIds -join '|') -cne ($operationIds -join '|')) {
        throw 'PreflightConsumerContractFailure: SourceMember IDs are not conserved exactly once.'
    }
    $memberById = @{}
    foreach ($member in $members) { $memberById[[string]$member.memberId] = $member }
    $stagingDestinations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($row in $rows) {
        $member = $memberById[[string]$row.sourceMemberRefId]
        if ($null -eq $member -or $member.sourceId -cne $row.sourceId -or $member.portableRelativePath -cne $row.sourcePortableRelativePath -or
            [int64]$member.sizeBytes -ne [int64]$row.byteCount -or $member.sha256 -cne $row.sha256 -or
            -not $stagingDestinations.Add([string]$row.stagingPortableRelativePath)) {
            throw 'PreflightConsumerContractFailure: staging row does not bijectively conserve its SourceMember tuple/destination.'
        }
    }
    $candidateSourceIds = @(Get-CergPreflightSortedIds @($members | ForEach-Object sourceId | Select-Object -Unique) 'candidate source IDs')
    $bindingSourceIds = @(Get-CergPreflightSortedIds @($Preflight.sourceRootBindings | ForEach-Object sourceId) 'source-root binding IDs')
    if (($candidateSourceIds -join '|') -cne ($bindingSourceIds -join '|')) { throw 'PreflightConsumerContractFailure: source-root bindings do not equal candidate source IDs.' }
    $memberBytes = [int64](($members | Measure-Object sizeBytes -Sum).Sum)
    if ([int64]$Preflight.stagingPlan.byteCount -ne $memberBytes -or [int64]$Preflight.operation.sourceReadMaxFiles -ne $members.Count -or
        [int64]$Preflight.operation.sourceReadMaxBytes -ne $memberBytes) {
        throw 'PreflightConsumerContractFailure: member count/bytes and read limits differ.'
    }
    if ($Preflight.stagingPlan.memberSetFingerprint -cne (Get-CergPreflightStructuredSha256 'cerg-lo1/staging-member-set/1' @($rows))) {
        throw 'PreflightConsumerContractFailure: staging member-set fingerprint differs.'
    }
    return $true
}

function New-CergLo1R2OrdinalPreflightObject {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Definition,[Parameter(Mandatory=$true)][object]$Candidate,[Parameter(Mandatory=$true)][object]$Freshness,[Parameter(Mandatory=$true)][object]$Readiness,[Parameter(Mandatory=$true)][string]$FreshnessEvidencePath,[Parameter(Mandatory=$true)][string]$AttemptPrivateAbsoluteRoot)
    $fields=@('schemaVersion','artifactId','candidateLockSha256','freshnessEvidenceSha256','freshnessCheckRunId','freshnessValidatorFinishedAtUtc','candidateContractHeadCommit','freshnessContractHeadCommit','contractHeadCommit','selectedCandidateId','createdAt','sourceRootBindings','implementationBindings','operation','aggregateLimits','stagingPlan','status','nextAction')
    Assert-CergPreflightExactProperties $Definition $fields 'R2 P02 definition'
    if($Definition.schemaVersion-cne'cerg-lo-cerg1-preflight-definition/1.2.0'-or$Definition.artifactId-cne'LO-CERG1-P02-DEFINITION'){throw 'PreflightConsumerContractFailure: R2 P02 definition identity invalid.'}
    if($Candidate.schemaVersion-cne'cerg-t1-candidate-lock/2.2.0'-or$Candidate.artifactId-cne'CERG-T1V22-O01'-or$Candidate.status-cne'Passed'){throw 'PreflightConsumerContractFailure: R2 candidate identity invalid.'}
    if($Freshness.schemaVersion-cne'cerg-lo-cerg1-r2-freshness/1.0.0'-or$Freshness.artifactId-cne'LO-CERG1-R2-F01'-or$Freshness.status-cne'Green'){throw 'PreflightConsumerContractFailure: R2 freshness identity invalid.'}
    if($Readiness.schemaVersion-cne'cerg-r2-aplus-readiness/1.2.0'-or$Readiness.artifactId-cne'R2-TO05'-or$Readiness.status-cne'Green'){throw 'PreflightConsumerContractFailure: R2 readiness identity invalid.'}
    if($Definition.candidateLockSha256-cne$Freshness.candidateLockSha256-or$Definition.candidateContractHeadCommit-cne$Candidate.contractHeadCommit-or$Definition.freshnessContractHeadCommit-cne$Freshness.contractHeadCommit-or$Definition.contractHeadCommit-cne$Readiness.contractHeadCommit){throw 'PreflightConsumerContractFailure: R2 definition HEAD domain is stale or spliced.'}
    foreach($headValue in @($Definition.candidateContractHeadCommit,$Definition.freshnessContractHeadCommit,$Definition.contractHeadCommit)){if([string]$headValue-cnotmatch'^[0-9a-f]{40}$'){throw 'PreflightConsumerContractFailure: R2 HEAD domain must be lowercase 40-hex.'}}
    $freshnessRawSha=(Get-FileHash -Algorithm SHA256 -LiteralPath $FreshnessEvidencePath).Hash.ToLowerInvariant()
    if($Definition.selectedCandidateId-cne$Candidate.selectedCandidateId-or$Definition.freshnessCheckRunId-cne$Freshness.checkRunId-or$Definition.freshnessValidatorFinishedAtUtc-cne$Freshness.validatorFinishedAtUtc-or[string]::IsNullOrWhiteSpace($FreshnessEvidencePath)-or-not[IO.File]::Exists($FreshnessEvidencePath)-or$Definition.freshnessEvidenceSha256-cne$freshnessRawSha){throw 'PreflightConsumerContractFailure: R2 candidate or raw freshness evidence binding is stale or spliced.'}
    $root=Get-CergPreflightAbsolutePath $AttemptPrivateAbsoluteRoot 'AttemptPrivateAbsoluteRoot'
    Assert-CergPreflightP02Ordering $Definition 'P02 definition'
    if($Definition.stagingPlan.memberSetFingerprint-cne(Get-CergPreflightStructuredSha256 'cerg-lo1/staging-member-set/1' @($Definition.stagingPlan.memberRows))){throw 'PreflightConsumerContractFailure: P02 definition member fingerprint invalid.'}
    $p=[pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight/1.6.0';artifactId='LO-CERG1-P02';candidateLockSha256=$Definition.candidateLockSha256
        freshnessEvidenceSha256=$Definition.freshnessEvidenceSha256;freshnessCheckRunId=$Definition.freshnessCheckRunId;freshnessValidatorFinishedAtUtc=$Definition.freshnessValidatorFinishedAtUtc
        candidateContractHeadCommit=$Definition.candidateContractHeadCommit;freshnessContractHeadCommit=$Definition.freshnessContractHeadCommit;contractHeadCommit=$Definition.contractHeadCommit;selectedCandidateId=$Definition.selectedCandidateId;createdAt=$Definition.createdAt
        sourceRootBindings=@($Definition.sourceRootBindings);implementationBindings=@($Definition.implementationBindings);operation=$Definition.operation;aggregateLimits=$Definition.aggregateLimits
        stagingPlan=[pscustomobject][ordered]@{
            attemptPrivateAbsoluteRoot=$root;stagingInputPortablePath=$Definition.stagingPlan.stagingInputPortablePath;stagingInputPrivateAbsolutePath=[IO.Path]::Combine($root,'Input')
            stagingInventoryTemporaryPath=$Definition.stagingPlan.stagingInventoryTemporaryPath;stagingInventoryTemporaryPrivateAbsolutePath=[IO.Path]::Combine($root,'staging-inventory.json.tmp')
            stagingInventoryPath=$Definition.stagingPlan.stagingInventoryPath;stagingInventoryPrivateAbsolutePath=[IO.Path]::Combine($root,'staging-inventory.json')
            workPortablePath=$Definition.stagingPlan.workPortablePath;workPrivateAbsolutePath=[IO.Path]::Combine($root,'Work');outputPortablePath=$Definition.stagingPlan.outputPortablePath;outputPrivateAbsolutePath=[IO.Path]::Combine($root,'Output')
            memberRows=@($Definition.stagingPlan.memberRows);memberCount=[int64]$Definition.stagingPlan.memberCount;byteCount=[int64]$Definition.stagingPlan.byteCount;memberSetFingerprint=$Definition.stagingPlan.memberSetFingerprint
        }
        status=$Definition.status;nextAction=$Definition.nextAction
    }
    return $p
}

function New-CergLo1R2PreflightObject {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Definition,[Parameter(Mandatory=$true)][object]$Candidate,[Parameter(Mandatory=$true)][object]$Freshness,[Parameter(Mandatory=$true)][object]$Readiness,[Parameter(Mandatory=$true)][string]$FreshnessEvidencePath,[Parameter(Mandatory=$true)][string]$AttemptPrivateAbsoluteRoot)
    throw 'PreflightConsumerContractFailure: rejected P01/v1.5 construction is permanently disabled; use the audited P02/v1.6 constructor.'
}

function New-CergLo1PreflightObject {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Definition, [Parameter(Mandatory = $true)][string]$AttemptPrivateAbsoluteRoot)

    $definitionFields = @('schemaVersion','artifactId','candidateLockSha256','contractHeadCommit','selectedCandidateId','createdAt','sourceRootBindings','implementationBindings','operation','aggregateLimits','stagingPlan','status','nextAction')
    $definitionStagingFields = @('stagingInputPortablePath','stagingInventoryTemporaryPath','stagingInventoryPath','workPortablePath','outputPortablePath','memberRows','memberCount','byteCount','memberSetFingerprint')
    Assert-CergPreflightExactProperties $Definition $definitionFields 'P01 definition'
    Assert-CergPreflightExactProperties $Definition.stagingPlan $definitionStagingFields 'P01 definition stagingPlan'
    if ($Definition.schemaVersion -cne 'cerg-lo-cerg1-preflight-definition/1.0.0' -or $Definition.artifactId -cne 'LO-CERG1-P01-DEFINITION') {
        throw 'PreflightConsumerContractFailure: production P01 definition identity is invalid.'
    }
    $attemptRoot = Get-CergPreflightAbsolutePath $AttemptPrivateAbsoluteRoot 'AttemptPrivateAbsoluteRoot'
    $preflight = [pscustomobject][ordered]@{
        schemaVersion = 'cerg-lo-cerg1-preflight/1.4.0'
        artifactId = 'LO-CERG1-P01'
        candidateLockSha256 = $Definition.candidateLockSha256
        contractHeadCommit = $Definition.contractHeadCommit
        selectedCandidateId = $Definition.selectedCandidateId
        createdAt = $Definition.createdAt
        sourceRootBindings = @($Definition.sourceRootBindings)
        implementationBindings = @($Definition.implementationBindings)
        operation = $Definition.operation
        aggregateLimits = $Definition.aggregateLimits
        stagingPlan = [pscustomobject][ordered]@{
            attemptPrivateAbsoluteRoot = $attemptRoot
            stagingInputPortablePath = $Definition.stagingPlan.stagingInputPortablePath
            stagingInputPrivateAbsolutePath = [System.IO.Path]::Combine($attemptRoot, 'Input')
            stagingInventoryTemporaryPath = $Definition.stagingPlan.stagingInventoryTemporaryPath
            stagingInventoryTemporaryPrivateAbsolutePath = [System.IO.Path]::Combine($attemptRoot, 'staging-inventory.json.tmp')
            stagingInventoryPath = $Definition.stagingPlan.stagingInventoryPath
            stagingInventoryPrivateAbsolutePath = [System.IO.Path]::Combine($attemptRoot, 'staging-inventory.json')
            workPortablePath = $Definition.stagingPlan.workPortablePath
            workPrivateAbsolutePath = [System.IO.Path]::Combine($attemptRoot, 'Work')
            outputPortablePath = $Definition.stagingPlan.outputPortablePath
            outputPrivateAbsolutePath = [System.IO.Path]::Combine($attemptRoot, 'Output')
            memberRows = @($Definition.stagingPlan.memberRows)
            memberCount = [int64]$Definition.stagingPlan.memberCount
            byteCount = [int64]$Definition.stagingPlan.byteCount
            memberSetFingerprint = $Definition.stagingPlan.memberSetFingerprint
        }
        status = $Definition.status
        nextAction = $Definition.nextAction
    }
    return $preflight
}
