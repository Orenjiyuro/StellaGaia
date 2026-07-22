[CmdletBinding()]
param(
    [string]$CandidateLockPath,
    [string]$PreflightPath,
    [string]$AttemptStatePath,
    [string]$StagingInventoryPath,
    [string]$OutputRoot,
    [string]$ResultTemporaryPath,
    [string]$ResultPath,
    [string]$FreshnessEvidencePath,
    [string]$FirstSourceOpenReceiptPath,
    [string]$AdjacencyFreshnessPath,
    [string]$ReadinessPath,
    [string]$ReplayPreflightPath,
    [string]$ReplayConfirmationId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')

$script:CergGraphImplementationRole = 'R01GraphProducer'
$script:CergGraphImplementationVersion = 'CERG-LO1-R01-PRODUCER/7'
$script:CergGraphImplementationPath = $PSCommandPath
$script:CergSubjectKinds = @('CandidateFamilyAnchor','Model','GameObject','Renderer','Mesh','Material','Texture','Shader','Skeleton','Bone','Avatar','Controller','OverrideController','StateMachine','ActionState','AttackAction','Motion','BlendTree','BlendParameter','BlendBranch','ActionClip','AnimationEvent','FXPrefab','FXObject','FXComponent','Weapon','Combo','Timeline','ReferencedObject')
$script:CergRelationshipKinds = @('AnchorOwnsModel','ModelContainsRenderer','RendererUsesMesh','RendererUsesMaterial','RendererUsesSkeleton','SkeletonContainsBone','AvatarUsesSkeleton','AnchorOwnsActionClip','ActionClipBindsSkeleton','ControllerOwnsStateMachine','StateMachineContainsStateMachine','StateMachineContainsState','StateUsesMotion','BlendTreeUsesParameter','BlendTreeContainsBranch','BlendBranchUsesMotion','MotionUsesClip','OverrideMapsClip','ActionHasAnimationEvent','AttackTriggersFX','FXPrefabContainsObject','FXObjectContainsObject','FXObjectHasComponent','FXComponentReferencesSubject','MaterialUsesTexture','MaterialUsesShader','TimelineUsesAction','WeaponUsesAction','ComboUsesAction','SerializedObjectReference')
$script:CergEvidenceStates = @('ProvenPresent','ProvenAbsent','EvidenceUnavailableBeforeExtraction','Contradictory')
$script:CergObligationStatuses = @('Resolved','MissingDependency','ContradictoryDependency','ToolFailure','LimitExceeded','OutputIntegrityFailure')
$script:CergAuthorityKinds = @('Controller','OverrideController','Prefab','AnimationEvent','SerializedObject')
$script:CergBaselineRelationshipKinds = @('AnchorOwnsModel','ModelContainsRenderer','RendererUsesMesh','RendererUsesSkeleton','AvatarUsesSkeleton','AnchorOwnsActionClip','ActionClipBindsSkeleton')

function Get-CergSortedRows {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Rows,
        [Parameter(Mandatory = $true)][scriptblock]$Key
    )
    $result = [object[]]@($Rows)
    $comparer = [System.Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{
        param($left, $right)
        return [string]::CompareOrdinal([string](& $Key $left), [string](& $Key $right))
    })
    [System.Array]::Sort($result, $comparer)
    return $result
}

function Get-CergSortedStrings {
    param([AllowEmptyCollection()][object[]]$Values)
    $result = [string[]]@($Values | ForEach-Object { ([string]$_).Normalize([System.Text.NormalizationForm]::FormC) })
    [System.Array]::Sort($result, [System.StringComparer]::Ordinal)
    for ($i = 1; $i -lt $result.Count; $i++) {
        if ($result[$i] -ceq $result[$i - 1]) { throw "Duplicate set value: $($result[$i])" }
    }
    return $result
}

function Assert-CergExactProperties {
    param(
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $actual = @($Row.PSObject.Properties.Name)
    if ($actual.Count -ne $Names.Count) { throw "$Label has an invalid property count." }
    for ($i = 0; $i -lt $Names.Count; $i++) {
        if ($actual[$i] -cne $Names[$i]) { throw "$Label property order/shape is invalid at $($Names[$i])." }
    }
}

function Assert-CergRequiredProperties {
    param([object]$Value,[string[]]$Names,[string]$Label)
    foreach ($name in $Names) {
        if ($null -eq $Value.PSObject.Properties[$name]) { throw "$Label is missing required property $name." }
    }
}

function Get-CergR01BudgetSnapshot {
    param([Parameter(Mandatory = $true)][object]$Attempt)

    if ($Attempt.schemaVersion -ceq 'cerg-lo-cerg1-r2-attempt-state/1.0.0') {
        Assert-CergRequiredProperties $Attempt @('artifactId','LOUsedBeforeFirstSourceOpen','LOUsedAfterFirstSourceOpen','status') 'R2 attempt budget source'
        if ($Attempt.artifactId -cne 'LO-CERG1-R2-A01' -or
            $Attempt.status -cne 'ArmedNoSourceOpen' -or
            [int64]$Attempt.LOUsedBeforeFirstSourceOpen -ne 1 -or
            [int64]$Attempt.LOUsedAfterFirstSourceOpen -ne 2) {
            throw 'R2 attempt LO counter transition is invalid.'
        }
        return [pscustomobject][ordered]@{
            ordinaryTaskUsed = 5
            ordinaryTaskBudget = 7
            LOUsed = [int64]$Attempt.LOUsedAfterFirstSourceOpen
            LOBudget = 3
        }
    }

    if ($Attempt.schemaVersion -ceq 'cerg-lo-cerg1-attempt-state/1.1.0' -and
        $Attempt.artifactId -ceq 'LO-CERG1-A01' -and
        $Attempt.status -ceq 'StartedNoResult' -and
        [int64]$Attempt.attemptCount -eq 1) {
        return [pscustomobject][ordered]@{
            ordinaryTaskUsed = 4
            ordinaryTaskBudget = 7
            LOUsed = 1
            LOBudget = 3
        }
    }

    throw 'Attempt cannot project an R01 budget snapshot.'
}

function Get-CergReplayOutputSnapshot {
    param([Parameter(Mandatory = $true)][object[]]$OutputFiles)
    $rows = @(Get-CergSortedRows @($OutputFiles | ForEach-Object {
        [pscustomobject][ordered]@{
            portableRelativePath = [string]$_.portableRelativePath
            byteCount = [int64]$_.byteCount
            sha256 = [string]$_.sha256
        }
    }) { param($row) $row.portableRelativePath })
    return [pscustomobject][ordered]@{
        memberCount = [int64]$rows.Count
        byteCount = [int64](($rows | Measure-Object byteCount -Sum).Sum)
        fingerprintDomain = 'cerg-r2/p04-discovery-output-member-set/1'
        memberSetFingerprint = Get-CergStructuredSha256 'cerg-r2/p04-discovery-output-member-set/1' @($rows)
    }
}

function Assert-CergR01ReplayPreflight {
    param(
        [Parameter(Mandatory = $true)][object]$Replay,
        [Parameter(Mandatory = $true)][string]$ReplayPath,
        [Parameter(Mandatory = $true)][string]$ConfirmationId,
        [Parameter(Mandatory = $true)][object]$Candidate,
        [Parameter(Mandatory = $true)][string]$CandidatePath,
        [Parameter(Mandatory = $true)][string]$PreflightPath,
        [Parameter(Mandatory = $true)][string]$FreshnessEvidencePath,
        [Parameter(Mandatory = $true)][string]$ReadinessPath,
        [Parameter(Mandatory = $true)][string]$AdjacencyFreshnessPath,
        [Parameter(Mandatory = $true)][string]$AttemptStatePath,
        [Parameter(Mandatory = $true)][string]$FirstSourceOpenReceiptPath,
        [Parameter(Mandatory = $true)][string]$StagingInventoryPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$ResultTemporaryPath,
        [Parameter(Mandatory = $true)][string]$ResultPath
    )

    Assert-CergExactProperties $Replay @('schemaVersion','artifactId','contractHeadCommit','createdAtUtc','selectedCandidateId','supersededReplayPreflight','upstreamBindings','implementationBinding','discoveryInputSnapshot','resultOutput','confirmationDomain','status','consumableForTG02','nextAction') 'P04 replay preflight'
    if ($Replay.schemaVersion -cne 'cerg-lo-cerg1-r01-replay-preflight/1.1.0' -or
        $Replay.artifactId -cne 'LO-CERG1-P04' -or
        $Replay.selectedCandidateId -cne $Candidate.selectedCandidateId -or
        $Replay.confirmationDomain -cne 'cerg-r2/p04-confirmation-id/1' -or
        $Replay.status -cne 'AwaitingExactHumanConfirmation' -or
        [bool]$Replay.consumableForTG02 -or
        $Replay.nextAction -cne 'ExactP04Confirmation') {
        throw 'P04 replay preflight fixed fields are invalid.'
    }
    if ([string]$Replay.contractHeadCommit -cnotmatch '^[0-9a-f]{40}$') { throw 'P04 contract HEAD is invalid.' }

    Assert-CergExactProperties $Replay.supersededReplayPreflight @('artifactId','privateAbsolutePath','byteCount','sha256','auditDisposition','consumableForTG02') 'P04 superseded P03'
    $p03Path = Get-CergFullPath ([string]$Replay.supersededReplayPreflight.privateAbsolutePath)
    if ($Replay.supersededReplayPreflight.artifactId -cne 'LO-CERG1-P03' -or
        $Replay.supersededReplayPreflight.auditDisposition -cne 'SupersededHistorical' -or
        [bool]$Replay.supersededReplayPreflight.consumableForTG02 -or
        -not [IO.File]::Exists($p03Path) -or
        [int64]$Replay.supersededReplayPreflight.byteCount -ne [IO.FileInfo]::new($p03Path).Length -or
        $Replay.supersededReplayPreflight.sha256 -cne (Get-CergSha256Hex $p03Path)) {
        throw 'P04 superseded P03 identity is invalid.'
    }

    Assert-CergExactProperties $Replay.implementationBinding @('artifactId','implementationRole','implementationVersion','portableTrackedPath','byteCount','sha256') 'P04 TG02 binding'
    $implementationPath = Get-CergFullPath $script:CergGraphImplementationPath
    if ($Replay.implementationBinding.artifactId -cne 'T1V22-TG02' -or
        $Replay.implementationBinding.implementationRole -cne 'R01GraphProducer' -or
        $Replay.implementationBinding.implementationVersion -cne $script:CergGraphImplementationVersion -or
        $Replay.implementationBinding.portableTrackedPath -cne 'Tools/AssetImport/New-CergLo1ResultGraph.ps1' -or
        [int64]$Replay.implementationBinding.byteCount -ne [IO.FileInfo]::new($implementationPath).Length -or
        $Replay.implementationBinding.sha256 -cne (Get-CergSha256Hex $implementationPath)) {
        throw 'P04 TG02 implementation identity is stale or spliced.'
    }

    $expectedPaths = [ordered]@{
        'CERG-T1V22-O01' = $CandidatePath
        'LO-CERG1-P02' = $PreflightPath
        'LO-CERG1-R2-F01' = $FreshnessEvidencePath
        'R2-TO07' = $ReadinessPath
        'LO-CERG1-R2-F02' = $AdjacencyFreshnessPath
        'LO-CERG1-R2-A01' = $AttemptStatePath
        'LO-CERG1-R2-H01' = $FirstSourceOpenReceiptPath
        'LO-CERG1-SI01' = $StagingInventoryPath
    }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in @($Replay.upstreamBindings)) {
        Assert-CergExactProperties $row @('artifactId','privateAbsolutePath','byteCount','sha256') 'P04 upstream binding'
        $id = [string]$row.artifactId
        if (-not $seen.Add($id) -or -not $expectedPaths.Contains($id)) { throw 'P04 upstream artifact set is invalid.' }
        $expectedPath = Get-CergFullPath ([string]$expectedPaths[$id])
        if ((Get-CergFullPath ([string]$row.privateAbsolutePath)) -cne $expectedPath -or
            -not [IO.File]::Exists($expectedPath) -or
            [int64]$row.byteCount -ne [IO.FileInfo]::new($expectedPath).Length -or
            $row.sha256 -cne (Get-CergSha256Hex $expectedPath)) { throw 'P04 upstream identity is stale or spliced.' }
    }
    if ($seen.Count -ne $expectedPaths.Count) { throw 'P04 upstream artifact set is incomplete.' }

    Assert-CergExactProperties $Replay.discoveryInputSnapshot @('privateAbsoluteRoot','accessMode','memberCount','byteCount','fingerprintDomain','memberSetFingerprint') 'P04 discovery snapshot'
    if ((Get-CergFullPath ([string]$Replay.discoveryInputSnapshot.privateAbsoluteRoot)) -cne (Get-CergFullPath $OutputRoot) -or
        $Replay.discoveryInputSnapshot.accessMode -cne 'ReadOnlyExistingAssetRipperOutput' -or
        $Replay.discoveryInputSnapshot.fingerprintDomain -cne 'cerg-r2/p04-discovery-output-member-set/1') { throw 'P04 discovery input binding is invalid.' }

    Assert-CergExactProperties $Replay.resultOutput @('portableRoot','privateAbsoluteRoot','temporaryPrivateAbsolutePath','finalPrivateAbsolutePath','mustBeInitiallyAbsent','noOverwrite') 'P04 result output'
    if ((Get-CergFullPath ([string]$Replay.resultOutput.temporaryPrivateAbsolutePath)) -cne (Get-CergFullPath $ResultTemporaryPath) -or
        (Get-CergFullPath ([string]$Replay.resultOutput.finalPrivateAbsolutePath)) -cne (Get-CergFullPath $ResultPath) -or
        -not [bool]$Replay.resultOutput.mustBeInitiallyAbsent -or -not [bool]$Replay.resultOutput.noOverwrite) { throw 'P04 result output binding is invalid.' }

    $expectedConfirmation = 'P04CONF-' + (Get-CergStructuredSha256 'cerg-r2/p04-confirmation-id/1' @(
        (Get-CergSha256Hex $ReplayPath),
        [string]$Replay.implementationBinding.sha256,
        [string]$Replay.discoveryInputSnapshot.memberSetFingerprint,
        [string]$Replay.resultOutput.portableRoot
    ))
    if ($ConfirmationId -cne $expectedConfirmation) { throw 'P04 exact confirmation identity does not recompute.' }
    return $true
}

function Assert-CergUpstreamBindings {
    param([object]$Candidate,[object]$Preflight,[AllowNull()][object]$Freshness,[string]$FreshnessEvidencePath,[AllowNull()][object]$AdjacencyFreshness,[string]$AdjacencyFreshnessPath,[AllowNull()][object]$Readiness,[string]$ReadinessPath,[object]$Attempt,[object]$Staging,[string]$CandidatePath,[string]$PreflightPath,[string]$AttemptStatePath,[string]$FirstSourceOpenReceiptPath,[string]$StagingInventoryPath,[string]$OutputRoot,[AllowNull()][object]$ReplayPreflight)
    Assert-CergRequiredProperties $Candidate @('schemaVersion','artifactId','contractHeadCommit','selectedCandidateId','status','attackAnchors','sourceMembers','discoveryObligations') 'Candidate lock'
    Assert-CergRequiredProperties $Preflight @('schemaVersion','artifactId','candidateLockSha256','contractHeadCommit','selectedCandidateId','operation','stagingPlan','status') 'Preflight'
    $isR2Attempt=$Attempt.schemaVersion-ceq'cerg-lo-cerg1-r2-attempt-state/1.0.0'
    if($isR2Attempt){Assert-CergRequiredProperties $Attempt @('schemaVersion','artifactId','contractHeadCommit','candidateLockSha256','selectedCandidateId','confirmedF01Sha256','confirmedF01CheckRunId','confirmedMemberSetFingerprint','preflightSha256','confirmationId','adjacencyF02Sha256','adjacencyCheckRunId','adjacencyMemberSetFingerprint','adjacencyValidatorFinishedAtUtc','runnerImplementation','runnerInstanceId','processId','maxFirstSourceOpenDelayMilliseconds','LOUsedBeforeFirstSourceOpen','LOUsedAfterFirstSourceOpen','status','sameRunnerOnly','nextAction') 'R2 attempt state'}else{Assert-CergRequiredProperties $Attempt @('schemaVersion','artifactId','candidateLockSha256','preflightSha256','contractHeadCommit','selectedCandidateId','attemptCount','status') 'Attempt state'}
    Assert-CergRequiredProperties $Staging @('schemaVersion','artifactId','candidateLockSha256','preflightSha256','selectedCandidateId','memberRows','memberCount','byteCount','memberSetFingerprint','status') 'Staging inventory'
    if ($Candidate.schemaVersion -cne 'cerg-t1-candidate-lock/2.2.0' -or $Candidate.artifactId -cne 'CERG-T1V22-O01' -or $Candidate.status -cne 'Passed') { throw 'Candidate lock schema, artifact ID, or status is invalid.' }
    if ($isR2Attempt -and $null -ne $ReplayPreflight) {
        # The P04 validator has already rebound the current TG02 bytes and every immutable upstream.
        # The remaining checks below independently conserve P02/F01/A01/H01/SI01 identities and tuples.
    } else {
        $null=Assert-CergLo1PreflightConsumerContract -Candidate $Candidate -Preflight $Preflight -Freshness $Freshness -Readiness $Readiness -FreshnessEvidencePath $FreshnessEvidencePath -StagingInventoryPath $StagingInventoryPath
    }
    $preflightIdentityValid=($Preflight.schemaVersion-ceq'cerg-lo-cerg1-preflight/1.4.0'-and$Preflight.artifactId-ceq'LO-CERG1-P01')-or($Preflight.schemaVersion-ceq'cerg-lo-cerg1-preflight/1.6.0'-and$Preflight.artifactId-ceq'LO-CERG1-P02')
    if (-not$preflightIdentityValid -or $Preflight.status -cne 'Green' -or ($isR2Attempt -and $Preflight.schemaVersion -cne 'cerg-lo-cerg1-preflight/1.6.0') -or (-not$isR2Attempt -and $Preflight.schemaVersion -ceq 'cerg-lo-cerg1-preflight/1.6.0')) { throw 'Preflight schema, artifact ID, or status is invalid.' }
    if ((Get-CergFullPath $OutputRoot) -cne (Get-CergFullPath ([string]$Preflight.stagingPlan.outputPrivateAbsolutePath))) { throw 'ResultGraph output root differs from the v1.4 P01 private output binding.' }
    if($isR2Attempt){
        if($Attempt.artifactId-cne'LO-CERG1-R2-A01'-or$Attempt.status-cne'ArmedNoSourceOpen'-or-not[bool]$Attempt.sameRunnerOnly-or[int64]$Attempt.maxFirstSourceOpenDelayMilliseconds-ne10000-or[int64]$Attempt.LOUsedBeforeFirstSourceOpen-ne1-or[int64]$Attempt.LOUsedAfterFirstSourceOpen-ne2-or$Attempt.nextAction-cne'SameRunnerEnterLOWrapperImmediately'){throw'R2 attempt-state fixed fields are invalid.'}
        if([string]::IsNullOrWhiteSpace($AttemptStatePath)-or[string]::IsNullOrWhiteSpace($FirstSourceOpenReceiptPath)-or[string]::IsNullOrWhiteSpace($AdjacencyFreshnessPath)-or[string]::IsNullOrWhiteSpace($ReadinessPath)-or$null-eq$AdjacencyFreshness-or$null-eq$Readiness){throw'R2 attempt requires exact A01, H01, F02, and readiness inputs.'}
        $h01=Read-CergJsonFile $FirstSourceOpenReceiptPath
        Assert-CergExactProperties $h01 @('schemaVersion','artifactId','a01Sha256','runnerImplementationId','runnerInstanceId','processId','sourceMemberId','adjacencyValidatorFinishedAtUtc','firstSourceOpenedAtUtc','elapsedMilliseconds','LOUsedBeforeFirstSourceOpen','LOUsedAfterFirstSourceOpen','status','nextAction') 'R2 first-source-open receipt'
        if($h01.schemaVersion-cne'cerg-lo-cerg1-r2-first-source-open/1.0.0'-or$h01.artifactId-cne'LO-CERG1-R2-H01'-or$h01.a01Sha256-cne(Get-CergSha256Hex $AttemptStatePath)-or$h01.runnerImplementationId-cne$Attempt.runnerImplementation.implementationId-or$h01.runnerInstanceId-cne$Attempt.runnerInstanceId-or[int64]$h01.processId-ne[int64]$Attempt.processId-or$h01.adjacencyValidatorFinishedAtUtc-cne$Attempt.adjacencyValidatorFinishedAtUtc-or[int64]$h01.elapsedMilliseconds-lt0-or[int64]$h01.elapsedMilliseconds-gt10000-or[int64]$h01.LOUsedBeforeFirstSourceOpen-ne1-or[int64]$h01.LOUsedAfterFirstSourceOpen-ne2-or$h01.status-cne'FirstSourceOpenObserved'-or$h01.nextAction-cne'ContinueOnlySameForegroundLOInvocation'){throw'R2 first-source-open receipt is stale, late, foreign, or non-consumable.'}
        if($AdjacencyFreshness.schemaVersion-cne'cerg-lo-cerg1-r2-adjacency-freshness/1.0.0'-or$AdjacencyFreshness.artifactId-cne'LO-CERG1-R2-F02'-or$AdjacencyFreshness.status-cne'Green'-or$Attempt.adjacencyF02Sha256-cne(Get-CergSha256Hex $AdjacencyFreshnessPath)-or$Attempt.adjacencyCheckRunId-cne$AdjacencyFreshness.checkRunId-or$Attempt.adjacencyMemberSetFingerprint-cne$AdjacencyFreshness.currentMemberSetFingerprint-or$Attempt.adjacencyValidatorFinishedAtUtc-cne$AdjacencyFreshness.validatorFinishedAtUtc){throw'R2 F02 identity or A01 binding is stale or spliced.'}
        if($Readiness.schemaVersion-cne'cerg-r2-aplus-readiness/1.4.0'-or$Readiness.artifactId-cne'R2-TO07'-or$Readiness.status-cne'Green'){throw'R2 readiness identity is invalid.'}
        $f01Hash=Get-CergSha256Hex $FreshnessEvidencePath;$p01Hash=Get-CergSha256Hex $PreflightPath
        if($Attempt.confirmedF01Sha256-cne$f01Hash-or$Attempt.confirmedF01CheckRunId-cne$Freshness.checkRunId-or$Attempt.confirmedMemberSetFingerprint-cne$Freshness.currentMemberSetFingerprint-or$Attempt.preflightSha256-cne$p01Hash-or$Attempt.adjacencyMemberSetFingerprint-cne$Freshness.currentMemberSetFingerprint){throw'R2 A01 F01/P01/F02 binding is stale or spliced.'}
        $expectedConfirmation='R2CONF-'+(Get-CergStructuredSha256 'cerg-r2/p02-confirmation-id/1' @($Attempt.contractHeadCommit,$f01Hash,$Freshness.checkRunId,$Freshness.currentMemberSetFingerprint,$p01Hash,$Attempt.runnerImplementation.implementationId));if($Attempt.confirmationId-cne$expectedConfirmation){throw'R2 A01 P02 confirmation identity does not recompute.'}
    }elseif($Attempt.schemaVersion-cne'cerg-lo-cerg1-attempt-state/1.1.0'-or$Attempt.artifactId-cne'LO-CERG1-A01'-or$Attempt.status-cne'StartedNoResult'-or[int64]$Attempt.attemptCount-ne1){throw'Attempt-state schema, artifact ID, attempt count, or status is invalid.'}
    if ($Staging.schemaVersion -cne 'cerg-lo-cerg1-staging-inventory/1.0.0' -or $Staging.artifactId -cne 'LO-CERG1-SI01' -or $Staging.status -cne 'Complete') { throw 'Staging-inventory schema, artifact ID, or status is invalid.' }
    $candidateHash=Get-CergSha256Hex $CandidatePath;$preflightHash=Get-CergSha256Hex $PreflightPath
    if ($Preflight.candidateLockSha256 -cne $candidateHash -or $Attempt.candidateLockSha256 -cne $candidateHash -or $Staging.candidateLockSha256 -cne $candidateHash) { throw 'Candidate lock freshness binding is stale or spliced.' }
    if ($Attempt.preflightSha256 -cne $preflightHash -or $Staging.preflightSha256 -cne $preflightHash) { throw 'Preflight freshness binding is stale or spliced.' }
    if($isR2Attempt){
        if($Candidate.contractHeadCommit-cne$Preflight.candidateContractHeadCommit-or$Freshness.contractHeadCommit-cne$Preflight.freshnessContractHeadCommit-or$Preflight.contractHeadCommit-cne$Attempt.contractHeadCommit-or$Preflight.contractHeadCommit-cne$AdjacencyFreshness.contractHeadCommit-or$Preflight.contractHeadCommit-cne$Readiness.contractHeadCommit){throw'R2 candidate, freshness, or execution HEAD domain is stale or spliced.'}
    }elseif($Candidate.contractHeadCommit-cne$Preflight.contractHeadCommit-or$Candidate.contractHeadCommit-cne$Attempt.contractHeadCommit){throw'Contract HEAD binding is stale or spliced.'}
    if ($Candidate.selectedCandidateId -cne $Preflight.selectedCandidateId -or $Candidate.selectedCandidateId -cne $Attempt.selectedCandidateId -or $Candidate.selectedCandidateId -cne $Staging.selectedCandidateId) { throw 'Selected-candidate binding is stale or spliced.' }
    $candidateRows=if($Preflight.schemaVersion-ceq'cerg-lo-cerg1-preflight/1.6.0'){@($Freshness.currentMembers|ForEach-Object{[pscustomobject]@{memberId=$_.memberId;sourceId=$_.sourceId;portableRelativePath=$_.portableRelativePath;sizeBytes=[int64]$_.byteCount;sha256=$_.sha256}})}else{@($Candidate.sourceMembers)};$planRows=@($Preflight.stagingPlan.memberRows);$stagingRows=@($Staging.memberRows)
    $candidateIds=@(Get-CergSortedStrings @($candidateRows|ForEach-Object memberId));$planIds=@(Get-CergSortedStrings @($planRows|ForEach-Object sourceMemberRefId));$stagingIds=@(Get-CergSortedStrings @($stagingRows|ForEach-Object sourceMemberRefId));$operationIds=@(Get-CergSortedStrings @($Preflight.operation.inputMemberRefIds))
    $expected=ConvertTo-CergCanonicalJsonValue $candidateIds
    if((ConvertTo-CergCanonicalJsonValue $planIds)-cne$expected -or (ConvertTo-CergCanonicalJsonValue $stagingIds)-cne$expected -or (ConvertTo-CergCanonicalJsonValue $operationIds)-cne$expected){throw 'Upstream SourceMember bijection is stale or spliced.'}
    if($isR2Attempt-and([string]$h01.sourceMemberId-cne[string]$planRows[0].sourceMemberRefId)){throw'R2 H01 does not identify the first staging-plan source member.'}
    $candidateById=@{};foreach($row in $candidateRows){if($candidateById.ContainsKey([string]$row.memberId)){throw 'Duplicate candidate SourceMember.'};$candidateById[[string]$row.memberId]=$row}
    $planById=@{};foreach($row in $planRows){if($planById.ContainsKey([string]$row.sourceMemberRefId)){throw 'Duplicate plan SourceMember.'};$planById[[string]$row.sourceMemberRefId]=$row}
    foreach($row in $stagingRows){$id=[string]$row.sourceMemberRefId;$member=$candidateById[$id];$plan=$planById[$id];if($null-eq$member-or$null-eq$plan){throw 'Staging row references unknown member.'};if($row.sourceId-cne$member.sourceId-or$row.sourcePortableRelativePath-cne$member.portableRelativePath-or[int64]$row.byteCount-ne[int64]$member.sizeBytes-or$row.sha256-cne$member.sha256-or(ConvertTo-CergCanonicalJsonValue $row)-cne(ConvertTo-CergCanonicalJsonValue $plan)){throw 'Source/plan/staging tuple is stale or spliced.'}}
    if([int64]$Staging.memberCount-ne$candidateRows.Count-or[int64]$Staging.byteCount-ne[int64](($candidateRows|Measure-Object sizeBytes -Sum).Sum)){throw 'Staging inventory totals are stale or spliced.'}
    $fingerprint=Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($stagingRows)
    if($Staging.memberSetFingerprint-cne$fingerprint-or$Preflight.stagingPlan.memberSetFingerprint-cne$fingerprint){throw 'Staging member-set fingerprint is stale or spliced.'}
}

function Get-CergUnityDocuments {
    param([string]$OutputRoot)
    $allowed=@('.controller','.overridecontroller','.prefab','.anim','.mat','.asset')
    $externalTextures=@('.png','.tga','.jpg','.jpeg','.psd','.exr')
    $externalShaders=@('.shader','.shadergraph')
    $files=@([System.IO.Directory]::EnumerateFiles($OutputRoot,'*',[System.IO.SearchOption]::AllDirectories)|ForEach-Object{
        $full=Get-CergFullPath $_;$relative=$full.Substring($OutputRoot.TrimEnd('\','/').Length+1).Replace('\','/');[pscustomobject]@{FullPath=$full;RelativePath=(ConvertTo-CergPortablePath $relative);Extension=[System.IO.Path]::GetExtension($full).ToLowerInvariant()}
    })
    if(@($files|Where-Object{$_.RelativePath.EndsWith('.cerggraph.json',[StringComparison]::Ordinal)}).Count-ne0){throw 'Prebuilt graph fragments are forbidden production input.'}
    $guidByAsset=@{};$assetByGuid=@{};$metaByAsset=@{}
    foreach($metaLeaf in [System.IO.Directory]::EnumerateFiles($OutputRoot,'*.meta',[System.IO.SearchOption]::AllDirectories)){
        $text=[System.IO.File]::ReadAllText($metaLeaf,$script:CergUtf8NoBom);$match=[regex]::Match($text,'(?m)^guid:\s*([0-9a-f]{32})\s*$');$importerMatch=[regex]::Match($text,'(?m)^(?<kind>[A-Za-z][A-Za-z0-9]*Importer):(?:\s|$)')
        if(-not$match.Success){throw 'Unity meta leaf lacks one lowercase 32-hex GUID.'}
        $asset=Get-CergFullPath ($metaLeaf.Substring(0,$metaLeaf.Length-5));$guid=$match.Groups[1].Value
        if($assetByGuid.ContainsKey($guid)){throw "Duplicate Unity GUID ownership: $guid"}
        $guidByAsset[$asset]=$guid;$assetByGuid[$guid]=$asset;$metaByAsset[$asset]=[pscustomobject]@{FullPath=(Get-CergFullPath $metaLeaf);RelativePath=(ConvertTo-CergPortablePath ((Get-CergFullPath $metaLeaf).Substring($OutputRoot.TrimEnd('\','/').Length+1).Replace('\','/')));Sha256=(Get-CergSha256Hex $metaLeaf);ByteCount=[int64]([IO.FileInfo]::new($metaLeaf).Length);ImporterKind=$(if($importerMatch.Success){$importerMatch.Groups['kind'].Value}else{$null})}
    }
    $documents=[System.Collections.Generic.List[object]]::new()
    foreach($file in @($files|Where-Object{$_.Extension-cin$allowed})){
        if(-not$guidByAsset.ContainsKey($file.FullPath)){throw "Unity serialized asset lacks matching .meta: $($file.RelativePath)"}
        $text=[System.IO.File]::ReadAllText($file.FullPath,$script:CergUtf8NoBom)
        $matches=[regex]::Matches($text,'(?ms)^--- !u!(?<classId>\d+) &(?<fileId>-?\d+)\r?\n(?<typeName>[A-Za-z_][A-Za-z0-9_]*):\r?\n(?<body>.*?)(?=^--- !u!|\z)')
        if($matches.Count-eq0){throw "Unity serialized asset has no YAML object documents: $($file.RelativePath)"}
        foreach($match in $matches){
            $nameMatch=[regex]::Match($match.Groups['body'].Value,'(?m)^\s*m_Name:\s*(.*?)\s*$')
            $tagMatch=[regex]::Match($match.Groups['body'].Value,'(?m)^\s*m_Tag:\s*(.*?)\s*$')
            $meta=$metaByAsset[$file.FullPath]
            $documents.Add([pscustomobject]@{ClassId=[int]$match.Groups['classId'].Value;FileId=[int64]$match.Groups['fileId'].Value;TypeName=$match.Groups['typeName'].Value;Body=$match.Groups['body'].Value;Name=$(if($nameMatch.Success){$nameMatch.Groups[1].Value}else{''});Tag=$(if($tagMatch.Success){$tagMatch.Groups[1].Value}else{''});FullPath=$file.FullPath;RelativePath=$file.RelativePath;Guid=$guidByAsset[$file.FullPath];Extension=$file.Extension;IsExternalLeaf=$false;MetaFullPath=$meta.FullPath;MetaRelativePath=$meta.RelativePath;MetaSha256=$meta.Sha256;MetaByteCount=$meta.ByteCount;ImporterKind=$null})
        }
    }
    foreach($file in @($files|Where-Object{$_.Extension-cin($externalTextures+$externalShaders)})){
        if(-not$guidByAsset.ContainsKey($file.FullPath)){throw "External Unity asset lacks matching .meta: $($file.RelativePath)"}
        $meta=$metaByAsset[$file.FullPath];$isTexture=$file.Extension-cin$externalTextures;$typeName=if($isTexture){'Texture2D'}else{'Shader'};$importer=if($isTexture){'TextureImporter'}else{'ShaderImporter'};if($meta.ImporterKind-cne$importer){throw "External Unity asset has mismatched importer $($meta.ImporterKind): $($file.RelativePath)"}
        $documents.Add([pscustomobject]@{ClassId=$(if($isTexture){28}else{48});FileId=[int64]0;TypeName=$typeName;Body='';Name=[IO.Path]::GetFileNameWithoutExtension($file.FullPath);Tag='';FullPath=$file.FullPath;RelativePath=$file.RelativePath;Guid=$guidByAsset[$file.FullPath];Extension=$file.Extension;IsExternalLeaf=$true;MetaFullPath=$meta.FullPath;MetaRelativePath=$meta.RelativePath;MetaSha256=$meta.Sha256;MetaByteCount=$meta.ByteCount;ImporterKind=$importer})
    }
    return @($documents)
}

function Get-CergYamlReferences {
    param([object]$Document)
    $rows=[System.Collections.Generic.List[object]]::new();$ordinalByPath=@{}
    foreach($line in ($Document.Body -split "`r?`n")){
        $m=[regex]::Match($line,'^\s*(?:-\s*)?(?<key>[A-Za-z_][A-Za-z0-9_]*):\s*(?<value>.*)$');if(-not$m.Success){continue}
        $key=$m.Groups['key'].Value;$value=$m.Groups['value'].Value
        foreach($ref in [regex]::Matches($value,'\{\s*fileID:\s*(?<file>-?\d+)(?:,\s*guid:\s*(?<guid>[0-9a-f]{32}),\s*type:\s*\d+)?\s*\}')){
            if(-not$ordinalByPath.ContainsKey($key)){$ordinalByPath[$key]=0};$ordinalByPath[$key]++
            $rows.Add([pscustomobject]@{PropertyPath=$key;Ordinal=[int]$ordinalByPath[$key];FileId=[int64]$ref.Groups['file'].Value;Guid=$(if($ref.Groups['guid'].Success){$ref.Groups['guid'].Value}else{$Document.Guid})})
        }
    }
    return @($rows)
}

function Get-CergYamlListBlocks {
    param([string]$Body,[string]$ListName)
    $lines=@($Body -split "`r?`n");$header=-1;$headerIndent=0
    for($i=0;$i-lt$lines.Count;$i++){$m=[regex]::Match($lines[$i],"^(?<indent>\s*)$([regex]::Escape($ListName)):\s*$" );if($m.Success){$header=$i;$headerIndent=$m.Groups['indent'].Value.Length;break}}
    if($header-lt0){return @()}
    $blocks=[System.Collections.Generic.List[object]]::new();$current=$null
    for($i=$header+1;$i-lt$lines.Count;$i++){
        $line=$lines[$i];if([string]::IsNullOrWhiteSpace($line)){continue};$indent=([regex]::Match($line,'^\s*').Value.Length)
        if($indent-le$headerIndent-and$line-notmatch'^\s*-'){break}
        $start=[regex]::Match($line,'^\s*-\s*(?<key>[A-Za-z_][A-Za-z0-9_]*):\s*(?<value>.*)$')
        if($start.Success){$current=[ordered]@{};$current[$start.Groups['key'].Value]=$start.Groups['value'].Value;$blocks.Add($current);continue}
        if($null-eq$current){continue};$field=[regex]::Match($line,'^\s+(?<key>[A-Za-z_][A-Za-z0-9_]*):\s*(?<value>.*)$');if($field.Success){$key=$field.Groups['key'].Value;if($current.Contains($key)){throw "$ListName element contains duplicate field $key."};$current[$key]=$field.Groups['value'].Value}
    }
    return @($blocks)
}

function ConvertTo-CergFiniteDecimal {
    param([string]$Text,[string]$Label)
    $value=[decimal]0
    if(-not[decimal]::TryParse($Text,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$value)){throw "$Label is not an invariant finite decimal."}
    return $value
}

function Get-CergReferenceFromText {
    param([string]$Text,[string]$DefaultGuid)
    $m=[regex]::Match($Text,'\{\s*fileID:\s*(?<file>-?\d+)(?:,\s*guid:\s*(?<guid>[0-9a-f]{32}),\s*type:\s*\d+)?\s*\}')
    if(-not$m.Success){throw 'Serialized reference is missing or malformed.'}
    return [pscustomobject]@{FileId=[int64]$m.Groups['file'].Value;Guid=$(if($m.Groups['guid'].Success){$m.Groups['guid'].Value}else{$DefaultGuid})}
}

function Get-CergSubjectKindFromDocument {
    param([object]$Document)
    switch($Document.TypeName){
        'AnimatorController'{'Controller'} 'AnimatorOverrideController'{'OverrideController'} 'AnimatorStateMachine'{'StateMachine'}
        'AnimatorState'{'ActionState'} 'BlendTree'{'BlendTree'} 'AnimationClip'{'ActionClip'}
        'GameObject'{'GameObject'} 'SkinnedMeshRenderer'{'Renderer'} 'MeshRenderer'{'Renderer'} 'ParticleSystemRenderer'{'Renderer'}
        'ParticleSystem'{'FXComponent'} 'TrailRenderer'{'FXComponent'} 'Transform'{'FXComponent'} 'Animator'{'FXComponent'} 'MonoBehaviour'{'FXComponent'}
        'Material'{'Material'} 'Texture2D'{'Texture'} 'Shader'{'Shader'} 'Mesh'{'Mesh'} 'Avatar'{'Avatar'} 'Skeleton'{'Skeleton'} 'Bone'{'Bone'}
        'TimelineAsset'{'Timeline'} 'Weapon'{'Weapon'} 'Combo'{'Combo'} default{'ReferencedObject'}
    }
}

function Get-CergOriginsForKind {
    param([object[]]$Obligations,[string]$SubjectKind,[string]$RelationshipKind)
    $ids=@($Obligations|Where-Object{($SubjectKind-and$SubjectKind-cin@($_.requiredSubjectKinds))-or($RelationshipKind-and$RelationshipKind-cin@($_.requiredRelationshipKinds))}|ForEach-Object obligationId)
    if($ids.Count-eq0){$ids=@($Obligations|Where-Object obligationKind -CEQ 'ResolveReferencedDependencies'|ForEach-Object obligationId)}
    return @(Get-CergSortedStrings $ids)
}

function New-CergParsedEvidence {
    param([object]$File,[string[]]$Origins)
    $row=[pscustomobject][ordered]@{evidenceId='';inputArtifactId='LO1-D01';evidenceClass='LO1SerializedDiscovery';portableRelativePath=$File.RelativePath;byteCount=[int64]([System.IO.FileInfo]::new($File.FullPath).Length);sha256=(Get-CergSha256Hex $File.FullPath);locatorKind='SerializedPropertyPath';locator=($File.RelativePath+'#UnityYaml');originObligationIds=@(Get-CergSortedStrings $Origins)}
    $row.evidenceId=Get-CergEvidenceId $row;return $row
}

function New-CergParsedSubject {
    param([string]$CandidateId,[string]$Kind,[string]$AuthorityIdentity,[AllowNull()][object]$Document,[string]$PortablePath,[string]$ContentSha,[string[]]$EvidenceRefs,[string[]]$Origins,[string]$ParameterName='')
    $rendererKind=$null;$componentClass=$null;$blendTreeType=$null
    if($Kind-ceq'Renderer'){$rendererKind=switch($Document.TypeName){'SkinnedMeshRenderer'{'SkinnedMeshRenderer'}'MeshRenderer'{'MeshRenderer'}'ParticleSystemRenderer'{'ParticleSystemRenderer'}'TrailRenderer'{'TrailRenderer'}default{'OtherRenderer'}}}
    if($Kind-ceq'FXComponent'){$componentClass=switch($Document.TypeName){'ParticleSystem'{'ParticleSystem'}'TrailRenderer'{'TrailRenderer'}'Animator'{'Animator'}'Transform'{'Transform'}default{'OtherSerializedFXComponent'}}}
    if($Kind-ceq'BlendTree'){
        $typeMatches=[regex]::Matches($Document.Body,'(?m)^[ \t]*m_BlendType:[ \t]*(?<value>.*?)[ \t]*\r?$')
        if($typeMatches.Count-ne1){throw "BlendTreeTypeInvalid: m_BlendType must occur exactly once; found $($typeMatches.Count)."}
        $typeScalar=$typeMatches[0].Groups['value'].Value
        if($typeScalar-cnotmatch'^[0-4]$'){throw "BlendTreeTypeInvalid: m_BlendType must be one ASCII digit from 0 through 4; found '$typeScalar'."}
        $blendTreeType=switch($typeScalar){
            '0'{'OneD'}
            '1'{'SimpleDirectional2D'}
            '2'{'FreeformDirectional2D'}
            '3'{'FreeformCartesian2D'}
            '4'{'Direct'}
        }
    }
    $row=[pscustomobject][ordered]@{subjectId='';candidateId=$CandidateId;subjectKind=$Kind;authorityIdentity=$AuthorityIdentity;unityGuid=$(if($null-ne$Document){$Document.Guid}else{$null});serializedFileId=$(if($null-ne$Document){[int64]$Document.FileId}else{$null});sourceObjectId=$(if($null-ne$Document){"$($Document.Guid):$($Document.FileId)"}else{$AuthorityIdentity});portableRelativePath=$PortablePath;contentSha256=$ContentSha;unityTypeName=$(if($null-ne$Document){$Document.TypeName}else{$Kind});rendererKind=$rendererKind;componentClass=$componentClass;blendTreeType=$blendTreeType;parameterName=$(if($Kind-ceq'BlendParameter'){$ParameterName}else{$null});evidenceRefIds=@(Get-CergSortedStrings $EvidenceRefs);originObligationIds=@(Get-CergSortedStrings $Origins)}
    $row.subjectId=Get-CergSubjectId $row;return $row
}

function New-CergParsedScope {
    param([string]$CandidateId,[string]$AuthorityKind,[object]$Owner,[string]$Locator,[string[]]$Slots,[string[]]$EvidenceRefs,[string[]]$Origins)
    $row=[pscustomobject][ordered]@{authorityScopeId='';candidateId=$CandidateId;authorityKind=$AuthorityKind;ownerSubjectId=$Owner.subjectId;scopeLocator=$Locator;isExhaustive=$true;enumeratedSlotIds=@(Get-CergSortedStrings $Slots);evidenceRefIds=@(Get-CergSortedStrings $EvidenceRefs);originObligationIds=@(Get-CergSortedStrings $Origins);authorityScopeFingerprint=''}
    $row.authorityScopeId=Get-CergAuthorityScopeId $row;$row.authorityScopeFingerprint=Get-CergAuthorityScopeFingerprint $row;return $row
}

function New-CergParsedRelationship {
    param([string]$CandidateId,[object]$Proposal,[object]$Scope)
    $row=[pscustomobject][ordered]@{relationshipId='';candidateId=$CandidateId;slotOrdinal=[int]$Proposal.SlotOrdinal;sourceSubjectId=$Proposal.Source.subjectId;relationshipKind=$Proposal.Kind;targetSubjectId=$(if($null-eq$Proposal.Target){$null}else{$Proposal.Target.subjectId});state=$(if($Proposal.PSObject.Properties['State']){$Proposal.State}else{'ProvenPresent'});authorityKind=$Scope.authorityKind;authorityScopeId=$Scope.authorityScopeId;authorityScopeFingerprint=$Scope.authorityScopeFingerprint;serializedPropertyPath=$Proposal.PropertyPath;overrideSourceClipSubjectId=$(if($Proposal.PSObject.Properties['OverrideSource']){$Proposal.OverrideSource.subjectId}else{$null});blendChildOrdinal=$(if($Proposal.PSObject.Properties['BlendChildOrdinal']){$Proposal.BlendChildOrdinal}else{$null});blendThreshold=$(if($Proposal.PSObject.Properties['BlendThreshold']){$Proposal.BlendThreshold}else{$null});blendPositionX=$(if($Proposal.PSObject.Properties['BlendPositionX']){$Proposal.BlendPositionX}else{$null});blendPositionY=$(if($Proposal.PSObject.Properties['BlendPositionY']){$Proposal.BlendPositionY}else{$null});childTimeScale=$(if($Proposal.PSObject.Properties['ChildTimeScale']){$Proposal.ChildTimeScale}else{$null});childCycleOffset=$(if($Proposal.PSObject.Properties['ChildCycleOffset']){$Proposal.ChildCycleOffset}else{$null});childMirror=$(if($Proposal.PSObject.Properties['ChildMirror']){$Proposal.ChildMirror}else{$null});directBlendParameterSubjectId=$(if($Proposal.PSObject.Properties['DirectBlendParameterSubjectId']){$Proposal.DirectBlendParameterSubjectId}else{$null});blendParameterValues=$(if($Proposal.PSObject.Properties['BlendParameterValues']){@($Proposal.BlendParameterValues)}else{@()});eventTime=$(if($Proposal.PSObject.Properties['EventTime']){$Proposal.EventTime}else{$null});eventFunctionName=$(if($Proposal.PSObject.Properties['EventFunctionName']){$Proposal.EventFunctionName}else{$null});evidenceRefIds=@($Proposal.Evidence.evidenceId);conflictingTargetSubjectIds=@();obligationId=$null;originObligationIds=@(Get-CergSortedStrings $Proposal.Origins)}
    $row.relationshipId=Get-CergRelationshipId $row;return $row
}

function New-CergUnityYamlGraph {
    param([string]$OutputRoot,[object]$Candidate,[object]$Preflight)
    $candidateId=[string]$Candidate.selectedCandidateId;$obligations=@($Candidate.discoveryObligations);$documents=@(Get-CergUnityDocuments $OutputRoot)
    if($documents.Count-eq0){throw 'No direct Unity documents or external asset leaves were discovered.'}
    $docByKey=@{};$externalDocByGuid=@{}
    foreach($doc in $documents){$key="$($doc.Guid):$($doc.FileId)";if($docByKey.ContainsKey($key)){throw "Duplicate Unity object identity: $key"};$docByKey[$key]=$doc;if($doc.IsExternalLeaf){$externalDocByGuid[$doc.Guid]=$doc}}

    $anchors=@($Candidate.attackAnchors)
    if($anchors.Count-ne1){throw 'Candidate lock must contain exactly one attack anchor.'}
    $anchor=$anchors[0]
    Assert-CergExactProperties $anchor @('attackAnchorId','candidateId','clipSubjectRefId','portableRelativePath','byteCount','sha256','unityGuid','serializedFileId','evidenceRefIds','authorityKind') 'AttackAnchor'
    if($anchor.candidateId-cne$candidateId-or$anchor.authorityKind-cne'ImmutableFFSAttackClip'){throw 'Attack anchor candidate or authority kind is invalid.'}
    $anchorPayload=@('cerg-t1/attack-anchor/1',$candidateId,[string]$anchor.portableRelativePath,[int64]$anchor.byteCount,[string]$anchor.sha256,[string]$anchor.unityGuid,[int64]$anchor.serializedFileId)
    $anchorJson=ConvertTo-CergCanonicalJsonValue $anchorPayload;$anchorBytes=$script:CergUtf8NoBom.GetBytes($anchorJson);$anchorExpected='ATK-'+([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($anchorBytes)).ToLowerInvariant())
    if($anchor.attackAnchorId-cne$anchorExpected){throw 'Attack anchor identity is stale.'}
    $anchorSubject=@($Candidate.subjects|Where-Object subjectId -CEQ $anchor.clipSubjectRefId)
    if($anchorSubject.Count-ne1-or$anchorSubject[0].subjectKind-cne'ActionClip'-or$anchorSubject[0].unityGuid-cne$anchor.unityGuid-or[int64]$anchorSubject[0].serializedFileId-ne[int64]$anchor.serializedFileId-or$anchorSubject[0].portableRelativePath-cne$anchor.portableRelativePath-or$anchorSubject[0].contentSha256-cne$anchor.sha256){throw 'Attack anchor does not resolve its O01 ActionClip tuple.'}
    $anchorDoc=$docByKey["$($anchor.unityGuid):$($anchor.serializedFileId)"]
    if($null-eq$anchorDoc-or$anchorDoc.TypeName-cne'AnimationClip'-or$anchorDoc.RelativePath-cne$anchor.portableRelativePath-or[int64]([IO.FileInfo]::new($anchorDoc.FullPath).Length)-ne[int64]$anchor.byteCount-or(Get-CergSha256Hex $anchorDoc.FullPath)-cne$anchor.sha256){throw 'Attack anchor is missing, stale, or mismatched in D01.'}

    function Resolve-CergMotionLeaves([object]$Document,[hashtable]$Active){
        $key="$($Document.Guid):$($Document.FileId)";if($Active.ContainsKey($key)){throw "BlendTree cycle at $key"};$next=@{};foreach($k in $Active.Keys){$next[$k]=$true};$next[$key]=$true
        if($Document.TypeName-ceq'AnimationClip'){return @($Document)}
        if($Document.TypeName-cne'BlendTree'){throw "Unclassified motion target $key"}
        $blocks=@(Get-CergYamlListBlocks $Document.Body 'm_Childs');if($blocks.Count-eq0){throw "BlendTree has no child blocks: $key"}
        $leaves=[System.Collections.Generic.List[object]]::new();foreach($block in $blocks){if(-not$block.Contains('m_Motion')){throw "BlendTree child has no m_Motion: $key"};$ref=Get-CergReferenceFromText $block['m_Motion'] $Document.Guid;$target=$docByKey["$($ref.Guid):$($ref.FileId)"];if($null-eq$target){throw "BlendTree child target is unresolved: $($ref.Guid):$($ref.FileId)"};foreach($leaf in @(Resolve-CergMotionLeaves $target $next)){$leaves.Add($leaf)}};return @($leaves)
    }
    $stateLeaves=@{};$attackStateKeys=@{};$attackLeafKeys=@{};$anchorReachableStateCount=0
    foreach($stateDoc in @($documents|Where-Object TypeName -CEQ 'AnimatorState')){
        $refs=@(Get-CergYamlReferences $stateDoc|Where-Object PropertyPath -CEQ 'm_Motion');if($refs.Count-ne1){throw "AnimatorState must have exactly one m_Motion: $($stateDoc.Guid):$($stateDoc.FileId)"};$motionDoc=$docByKey["$($refs[0].Guid):$($refs[0].FileId)"];if($null-eq$motionDoc){throw 'AnimatorState motion is unresolved.'};$leaves=@(Resolve-CergMotionLeaves $motionDoc @{});$stateKey="$($stateDoc.Guid):$($stateDoc.FileId)";$stateLeaves[$stateKey]=$leaves
        $anchorReachable=@($leaves|Where-Object{$_.Guid-ceq$anchor.unityGuid-and[int64]$_.FileId-eq[int64]$anchor.serializedFileId}).Count-gt0;$tagAttack=$stateDoc.Tag-ceq'Attack'
        if($anchorReachable){$anchorReachableStateCount++};if($anchorReachable-or$tagAttack){$attackStateKeys[$stateKey]=$true;foreach($leaf in $leaves){$attackLeafKeys["$($leaf.Guid):$($leaf.FileId)"]=$leaf}}
    }
    if($anchorReachableStateCount-lt1){throw 'The immutable attack anchor is not reachable from any serialized AnimatorState.'}
    $eventBlocksByClip=@{};$fxPrefabGuids=@{}
    foreach($entry in $attackLeafKeys.GetEnumerator()){
        $clip=$entry.Value;$blocks=@(Get-CergYamlListBlocks $clip.Body 'm_Events');$parsed=[System.Collections.Generic.List[object]]::new();$ordinal=0
        foreach($block in $blocks){foreach($required in @('time','functionName','objectReferenceParameter')){if(-not$block.Contains($required)-or[string]::IsNullOrWhiteSpace([string]$block[$required])){throw "AnimationEvent $ordinal is missing $required."}};$time=ConvertTo-CergFiniteDecimal ([string]$block['time']) "AnimationEvent[$ordinal].time";$ref=Get-CergReferenceFromText ([string]$block['objectReferenceParameter']) $clip.Guid;$prefabGroups=@($documents|Where-Object{$_.Guid-ceq$ref.Guid-and$_.Extension-ceq'.prefab'}|Group-Object FullPath);if($prefabGroups.Count-ne1){throw "AnimationEvent FX prefab GUID is unresolved or ambiguous: $($ref.Guid)"};$fxPrefabGuids[$ref.Guid]=$true;$parsed.Add([pscustomobject]@{Ordinal=$ordinal;Time=$time;FunctionName=[string]$block['functionName'];Reference=$ref;PrefabDoc=$prefabGroups[0].Group[0]});$ordinal++}
        $eventBlocksByClip[$entry.Key]=@($parsed)
    }
    $allPrefabGuids=@($documents|Where-Object Extension -CEQ '.prefab'|ForEach-Object Guid|Select-Object -Unique);foreach($guid in $fxPrefabGuids.Keys){if($guid-cnotin$allPrefabGuids){throw 'Attack FX prefab is outside the prefab partition.'}}

    $fileInfo=@{};$evidence=[System.Collections.Generic.List[object]]::new()
    foreach($group in ($documents|Group-Object FullPath)){
        $doc=$group.Group[0];$originList=[System.Collections.Generic.List[string]]::new();foreach($member in $group.Group){$memberKey="$($member.Guid):$($member.FileId)";$kind=Get-CergSubjectKindFromDocument $member;if($member.TypeName-ceq'AnimatorState'-and$attackStateKeys.ContainsKey($memberKey)){$kind='AttackAction'};if($member.TypeName-ceq'GameObject'-and$fxPrefabGuids.ContainsKey($member.Guid)){$kind='FXObject'};foreach($id in @(Get-CergOriginsForKind $obligations $kind '')){$originList.Add($id)};if($attackLeafKeys.ContainsKey($memberKey)){foreach($relationshipKind in @('ActionHasAnimationEvent','AttackTriggersFX')){foreach($id in @(Get-CergOriginsForKind $obligations '' $relationshipKind)){$originList.Add($id)}}};if($fxPrefabGuids.ContainsKey($member.Guid)){foreach($id in @(Get-CergOriginsForKind $obligations 'FXPrefab' '')){$originList.Add($id)}}};$origins=@(Get-CergSortedStrings @($originList|Select-Object -Unique));$file=[pscustomobject]@{FullPath=$doc.FullPath;RelativePath=$doc.RelativePath};$assetEv=New-CergParsedEvidence $file $origins;$metaFile=[pscustomobject]@{FullPath=$doc.MetaFullPath;RelativePath=$doc.MetaRelativePath};$metaEv=New-CergParsedEvidence $metaFile $origins;$evidence.Add($assetEv);$evidence.Add($metaEv);$fileInfo[$doc.FullPath]=[pscustomobject]@{Evidence=$assetEv;MetaEvidence=$metaEv;Sha=$assetEv.sha256;RelativePath=$doc.RelativePath;MetaRelativePath=$doc.MetaRelativePath}
    }
    $subjects=[System.Collections.Generic.List[object]]::new();$subjectByKey=@{};$externalSubjectByGuid=@{};$docBySubjectId=@{}
    foreach($doc in $documents){
        $kind=Get-CergSubjectKindFromDocument $doc;$key="$($doc.Guid):$($doc.FileId)";if($doc.TypeName-ceq'AnimatorState'-and$attackStateKeys.ContainsKey($key)){$kind='AttackAction'};if($doc.TypeName-ceq'GameObject'-and$fxPrefabGuids.ContainsKey($doc.Guid)){$kind='FXObject'};if($doc.Extension-ceq'.prefab'-and-not$fxPrefabGuids.ContainsKey($doc.Guid)-and$kind-ceq'FXComponent'){$kind='ReferencedObject'}
        $origins=Get-CergOriginsForKind $obligations $kind '';$info=$fileInfo[$doc.FullPath];$authority=if($doc.IsExternalLeaf){"ExternalLeaf:$($doc.Guid):$($doc.RelativePath):$($info.Sha):$($doc.MetaSha256):$($doc.ImporterKind)"}else{"DiscoveredYamlObject:$($doc.Guid):$($doc.FileId)"};if($kind-ceq'AttackAction'){$stateKey="$($doc.Guid):$($doc.FileId)";$anchorReached=@($stateLeaves[$stateKey]|Where-Object{$_.Guid-ceq$anchor.unityGuid-and[int64]$_.FileId-eq[int64]$anchor.serializedFileId}).Count-gt0;if($anchorReached){$authority+=':AttackAnchor:'+$anchor.attackAnchorId};if($doc.Tag-ceq'Attack'){$authority+=':AttackTag:m_Tag'}}
        $subject=New-CergParsedSubject $candidateId $kind $authority $doc $doc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) $origins
        $subjects.Add($subject);$subjectByKey[$key]=$subject;if($doc.IsExternalLeaf){$externalSubjectByGuid[$doc.Guid]=$subject};$docBySubjectId[$subject.subjectId]=$doc
    }
    $prefabByGuid=@{}
    foreach($guid in $fxPrefabGuids.Keys){$doc=@($documents|Where-Object{$_.Guid-ceq$guid-and$_.Extension-ceq'.prefab'}|Select-Object -First 1)[0];$info=$fileInfo[$doc.FullPath];$origins=Get-CergOriginsForKind $obligations 'FXPrefab' '';$subject=New-CergParsedSubject $candidateId 'FXPrefab' "AttackReferencedUnityPrefabGuid:$guid" $null $doc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) $origins;$subjects.Add($subject);$prefabByGuid[$guid]=$subject}
    $proposals=[System.Collections.Generic.List[object]]::new();$slotCounters=@{}
    function AddProposal([object]$Source,[object]$Target,[string]$Kind,[string]$PropertyPath,[string]$AuthorityKind,[object]$Evidence,[hashtable]$Extra){
        if($null-eq$Source-or$null-eq$Target){return};$key="$($Source.subjectId)|$Kind";if(-not$slotCounters.ContainsKey($key)){$slotCounters[$key]=0};$slotCounters[$key]++
        $row=[pscustomobject]@{Source=$Source;Target=$Target;Kind=$Kind;PropertyPath=$PropertyPath;AuthorityKind=$AuthorityKind;Evidence=$Evidence;SlotOrdinal=[int]$slotCounters[$key];Origins=@(Get-CergOriginsForKind $obligations '' $Kind)}
        foreach($name in $Extra.Keys){$row|Add-Member -NotePropertyName $name -NotePropertyValue $Extra[$name]};$proposals.Add($row)
    }
    $virtualCounter=0
    foreach($doc in $documents){
        $source=$subjectByKey["$($doc.Guid):$($doc.FileId)"];$info=$fileInfo[$doc.FullPath];$refs=@(Get-CergYamlReferences $doc)
        foreach($ref in $refs){
            $target=$subjectByKey["$($ref.Guid):$($ref.FileId)"];if($null-eq$target-and$externalSubjectByGuid.ContainsKey($ref.Guid)){$target=$externalSubjectByGuid[$ref.Guid]};if($null-eq$target-and$prefabByGuid.ContainsKey($ref.Guid)){$target=$prefabByGuid[$ref.Guid]}
            $deferred=($doc.TypeName-ceq'AnimatorOverrideController'-and$ref.PropertyPath-cin@('m_OriginalClip','m_OverrideClip'))-or($doc.TypeName-ceq'BlendTree'-and$ref.PropertyPath-ceq'm_Motion')-or($doc.TypeName-ceq'AnimationClip'-and$ref.PropertyPath-ceq'objectReferenceParameter')-or($doc.TypeName-ceq'Transform'-and$ref.PropertyPath-ceq'm_Father')
            if($null-eq$target-and$ref.FileId-ne0-and-not$deferred){throw "Unresolved Unity serialized reference: $($ref.Guid):$($ref.FileId) from $($doc.RelativePath)#$($doc.FileId)."}
            $proposalCountBefore=$proposals.Count
            switch($doc.TypeName){
                'AnimatorController'{if($ref.PropertyPath-ceq'm_StateMachine'){AddProposal $source $target 'ControllerOwnsStateMachine' $ref.PropertyPath 'Controller' $info.Evidence @{}}}
                'AnimatorStateMachine'{if($ref.PropertyPath-ceq'm_State'){AddProposal $source $target 'StateMachineContainsState' $ref.PropertyPath 'Controller' $info.Evidence @{}}elseif($ref.PropertyPath-ceq'm_StateMachine'){AddProposal $source $target 'StateMachineContainsStateMachine' $ref.PropertyPath 'Controller' $info.Evidence @{}}}
                'AnimatorState'{if($ref.PropertyPath-ceq'm_Motion'){if($target.subjectKind-ceq'BlendTree'){AddProposal $source $target 'StateUsesMotion' $ref.PropertyPath 'Controller' $info.Evidence @{}}else{$virtualCounter++;$origins=Get-CergOriginsForKind $obligations 'Motion' '';$motion=New-CergParsedSubject $candidateId 'Motion' "StateMotion:$($doc.Guid):$($doc.FileId):$virtualCounter" $null $doc.RelativePath $info.Sha @($info.Evidence.evidenceId) $origins;$subjects.Add($motion);AddProposal $source $motion 'StateUsesMotion' $ref.PropertyPath 'Controller' $info.Evidence @{};AddProposal $motion $target 'MotionUsesClip' 'm_Motion' 'Controller' $info.Evidence @{}}}}
                'AnimatorOverrideController'{}
                'GameObject'{if($fxPrefabGuids.ContainsKey($doc.Guid)-and$ref.PropertyPath-ceq'm_Component'-and$target.subjectKind-cin@('FXComponent','Renderer')){AddProposal $source $target 'FXObjectHasComponent' $ref.PropertyPath 'Prefab' $info.Evidence @{}}}
                'SkinnedMeshRenderer'{if($ref.PropertyPath-ceq'm_Mesh'){AddProposal $source $target 'RendererUsesMesh' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}elseif($ref.PropertyPath-ceq'm_Materials'){AddProposal $source $target 'RendererUsesMaterial' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}elseif($ref.PropertyPath-ceq'm_RootBone'){AddProposal $source $target 'RendererUsesSkeleton' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'MeshRenderer'{if($ref.PropertyPath-ceq'm_Materials'){AddProposal $source $target 'RendererUsesMaterial' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'ParticleSystemRenderer'{if($ref.PropertyPath-ceq'm_Materials'){AddProposal $source $target 'RendererUsesMaterial' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Material'{if($ref.PropertyPath-ceq'm_Shader'){AddProposal $source $target 'MaterialUsesShader' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}elseif($ref.PropertyPath-ceq'm_Texture'){AddProposal $source $target 'MaterialUsesTexture' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Avatar'{if($ref.PropertyPath-ceq'm_Skeleton'){AddProposal $source $target 'AvatarUsesSkeleton' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Skeleton'{if($ref.PropertyPath-ceq'm_Bone'){AddProposal $source $target 'SkeletonContainsBone' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'TimelineAsset'{if($ref.PropertyPath-ceq'm_Action'){AddProposal $source $target 'TimelineUsesAction' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Weapon'{if($ref.PropertyPath-ceq'm_Action'){AddProposal $source $target 'WeaponUsesAction' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Combo'{if($ref.PropertyPath-ceq'm_Action'){AddProposal $source $target 'ComboUsesAction' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
                'Transform'{}
                default{if($source.subjectKind-ceq'FXComponent'-and$ref.PropertyPath-cne'm_GameObject'-and$ref.FileId-ne0){AddProposal $source $target 'FXComponentReferencesSubject' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}}
            }
            if($ref.FileId-ne0-and$proposals.Count-eq$proposalCountBefore-and-not$deferred){AddProposal $source $target 'SerializedObjectReference' $ref.PropertyPath 'SerializedObject' $info.Evidence @{}}
        }
    }
    foreach($doc in @($documents|Where-Object TypeName -CEQ 'AnimatorOverrideController')){
        $source=$subjectByKey["$($doc.Guid):$($doc.FileId)"];$info=$fileInfo[$doc.FullPath];$refs=@(Get-CergYamlReferences $doc);$originals=@($refs|Where-Object PropertyPath -CEQ 'm_OriginalClip');$overrides=@($refs|Where-Object PropertyPath -CEQ 'm_OverrideClip')
        if($originals.Count-ne$overrides.Count){continue};for($i=0;$i-lt$originals.Count;$i++){$original=$subjectByKey["$($originals[$i].Guid):$($originals[$i].FileId)"];$target=$subjectByKey["$($overrides[$i].Guid):$($overrides[$i].FileId)"];if($null-ne$original-and$null-ne$target){AddProposal $source $target 'OverrideMapsClip' "m_Clips[$i]" 'OverrideController' $info.Evidence @{OverrideSource=$original}}}
    }
    $parameterByKey=@{}
    foreach($doc in @($documents|Where-Object TypeName -CEQ 'BlendTree')){
        $tree=$subjectByKey["$($doc.Guid):$($doc.FileId)"];$info=$fileInfo[$doc.FullPath];$blocks=@(Get-CergYamlListBlocks $doc.Body 'm_Childs');$type=[string]$tree.blendTreeType
        function Get-OrCreateBlendParameter([string]$Name,[string]$PropertyPath){if([string]::IsNullOrWhiteSpace($Name)){throw 'Blend parameter identity is empty.'};$key="$($tree.subjectId)|$Name";if(-not$parameterByKey.ContainsKey($key)){$origins=Get-CergOriginsForKind $obligations 'BlendParameter' '';$parameter=New-CergParsedSubject $candidateId 'BlendParameter' "BlendParameter:$($doc.Guid):$($doc.FileId):$Name" $null $doc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) $origins $Name;$subjects.Add($parameter);$parameterByKey[$key]=$parameter;AddProposal $tree $parameter 'BlendTreeUsesParameter' $PropertyPath 'Controller' $info.Evidence @{}};return $parameterByKey[$key]}
        $treeParameters=[System.Collections.Generic.List[object]]::new()
        if($type-ceq'OneD'){$m=[regex]::Match($doc.Body,'(?m)^\s*m_BlendParameter:\s*(\S+)\s*$');if(-not$m.Success){throw 'OneD BlendTree lacks m_BlendParameter.'};$treeParameters.Add((Get-OrCreateBlendParameter $m.Groups[1].Value 'm_BlendParameter'))}
        elseif($type-cin@('SimpleDirectional2D','FreeformDirectional2D','FreeformCartesian2D')){$mx=[regex]::Match($doc.Body,'(?m)^\s*m_BlendParameter:\s*(\S+)\s*$');$my=[regex]::Match($doc.Body,'(?m)^\s*m_BlendParameterY:\s*(\S+)\s*$');if(-not$mx.Success-or-not$my.Success){throw '2D BlendTree lacks X/Y parameters.'};$treeParameters.Add((Get-OrCreateBlendParameter $mx.Groups[1].Value 'm_BlendParameter'));$treeParameters.Add((Get-OrCreateBlendParameter $my.Groups[1].Value 'm_BlendParameterY'))}
        elseif($type-ceq'Direct'){foreach($block in $blocks){if(-not$block.Contains('m_DirectBlendParameter')-or[string]::IsNullOrWhiteSpace([string]$block['m_DirectBlendParameter'])){throw 'Direct child lacks m_DirectBlendParameter.'};$treeParameters.Add((Get-OrCreateBlendParameter ([string]$block['m_DirectBlendParameter']) 'm_DirectBlendParameter'))};$treeParameters=@(Get-CergSortedRows @($treeParameters|Sort-Object subjectId -Unique) {param($x)$x.subjectId})}
        for($child=0;$child-lt$blocks.Count;$child++){$block=$blocks[$child];$ref=Get-CergReferenceFromText ([string]$block['m_Motion']) $doc.Guid;$target=$subjectByKey["$($ref.Guid):$($ref.FileId)"];if($null-eq$target){throw 'Blend child motion target is unresolved.'};$threshold=$null;$x=$null;$y=$null;$direct=$null;$values=@()
            if($type-ceq'OneD'){if(-not$block.Contains('m_Threshold')-or$block.Contains('m_Position')-or$block.Contains('m_DirectBlendParameter')){throw 'OneD child metadata partition is invalid.'};$threshold=ConvertTo-CergFiniteDecimal ([string]$block['m_Threshold']) "m_Childs[$child].m_Threshold";$values=@([pscustomobject][ordered]@{parameterSubjectId=$treeParameters[0].subjectId;value=$threshold})}
            elseif($type-cin@('SimpleDirectional2D','FreeformDirectional2D','FreeformCartesian2D')){if(-not$block.Contains('m_Position')-or$block.Contains('m_Threshold')-or$block.Contains('m_DirectBlendParameter')){throw '2D child metadata partition is invalid.'};$pm=[regex]::Match([string]$block['m_Position'],'\{\s*x:\s*(?<x>[-+0-9.eE]+),\s*y:\s*(?<y>[-+0-9.eE]+)\s*\}');if(-not$pm.Success){throw '2D position is malformed.'};$x=ConvertTo-CergFiniteDecimal $pm.Groups['x'].Value 'm_Position.x';$y=ConvertTo-CergFiniteDecimal $pm.Groups['y'].Value 'm_Position.y';$values=@(Get-CergSortedRows @([pscustomobject][ordered]@{parameterSubjectId=$treeParameters[0].subjectId;value=$x},[pscustomobject][ordered]@{parameterSubjectId=$treeParameters[1].subjectId;value=$y}) {param($v)$v.parameterSubjectId})}
            elseif($type-ceq'Direct'){if(-not$block.Contains('m_DirectBlendParameter')-or$block.Contains('m_Threshold')-or$block.Contains('m_Position')){throw 'Direct child metadata partition is invalid.'};$direct=Get-OrCreateBlendParameter ([string]$block['m_DirectBlendParameter']) "m_Childs[$child].m_DirectBlendParameter";$values=@($treeParameters|ForEach-Object{[pscustomobject][ordered]@{parameterSubjectId=$_.subjectId;value=[decimal]$(if($_.subjectId-ceq$direct.subjectId){1}else{0})}})}
            $timeScale=if($block.Contains('m_TimeScale')){ConvertTo-CergFiniteDecimal ([string]$block['m_TimeScale']) 'm_TimeScale'}else{[decimal]1};$cycle=if($block.Contains('m_CycleOffset')){ConvertTo-CergFiniteDecimal ([string]$block['m_CycleOffset']) 'm_CycleOffset'}else{[decimal]0};$mirror=if($block.Contains('m_Mirror')){switch([string]$block['m_Mirror']){'0'{$false}'1'{$true}'false'{$false}'true'{$true}default{throw 'm_Mirror is invalid.'}}}else{$false};$defaults=@();if(-not$block.Contains('m_TimeScale')){$defaults+='m_TimeScale:AbsentUsesUnityDefault/v1'};if(-not$block.Contains('m_CycleOffset')){$defaults+='m_CycleOffset:AbsentUsesUnityDefault/v1'};if(-not$block.Contains('m_Mirror')){$defaults+='m_Mirror:AbsentUsesUnityDefault/v1'};$path="m_Childs[$child]"+$(if($defaults.Count){'/'+($defaults-join '/')}else{''})
            $origins=Get-CergOriginsForKind $obligations 'BlendBranch' '';$branch=New-CergParsedSubject $candidateId 'BlendBranch' "BlendBranch:$($doc.Guid):$($doc.FileId):$child" $null $doc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) $origins;$subjects.Add($branch);AddProposal $tree $branch 'BlendTreeContainsBranch' $path 'Controller' $info.Evidence @{BlendChildOrdinal=$child;BlendThreshold=$threshold;BlendPositionX=$x;BlendPositionY=$y;ChildTimeScale=$timeScale;ChildCycleOffset=$cycle;ChildMirror=$mirror;DirectBlendParameterSubjectId=$(if($null-ne$direct){$direct.subjectId}else{$null});BlendParameterValues=$values};if($target.subjectKind-ceq'ActionClip'){$virtualCounter++;$motion=New-CergParsedSubject $candidateId 'Motion' "BlendMotion:$($doc.Guid):$($doc.FileId):$child" $null $doc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) (Get-CergOriginsForKind $obligations 'Motion' '');$subjects.Add($motion);AddProposal $branch $motion 'BlendBranchUsesMotion' "m_Childs[$child].m_Motion" 'Controller' $info.Evidence @{};AddProposal $motion $target 'MotionUsesClip' "m_Childs[$child].m_Motion" 'Controller' $info.Evidence @{}}else{AddProposal $branch $target 'BlendBranchUsesMotion' "m_Childs[$child].m_Motion" 'Controller' $info.Evidence @{}}}
    }
    foreach($group in @($documents|Where-Object{$_.Extension-ceq'.prefab'-and$fxPrefabGuids.ContainsKey($_.Guid)}|Group-Object Guid)){
        $prefab=$prefabByGuid[$group.Name];$gameObjects=@($group.Group|Where-Object TypeName -CEQ 'GameObject');$info=$fileInfo[$group.Group[0].FullPath]
        foreach($goDoc in $gameObjects){$go=$subjectByKey["$($goDoc.Guid):$($goDoc.FileId)"];AddProposal $prefab $go 'FXPrefabContainsObject' 'm_RootObjects' 'Prefab' $info.Evidence @{}}
        $transformToObject=@{}
        foreach($transformDoc in @($group.Group|Where-Object TypeName -CEQ 'Transform')){$objectRef=@(Get-CergYamlReferences $transformDoc|Where-Object PropertyPath -CEQ 'm_GameObject'|Select-Object -First 1);if($objectRef.Count-ne0){$transformToObject["$($transformDoc.Guid):$($transformDoc.FileId)"]=$subjectByKey["$($objectRef[0].Guid):$($objectRef[0].FileId)"]}}
        foreach($transformDoc in @($group.Group|Where-Object TypeName -CEQ 'Transform')){$parentRef=@(Get-CergYamlReferences $transformDoc|Where-Object{$_.PropertyPath-ceq'm_Father'-and$_.FileId-ne0}|Select-Object -First 1);if($parentRef.Count-eq0){continue};$child=$transformToObject["$($transformDoc.Guid):$($transformDoc.FileId)"];$parent=$transformToObject["$($parentRef[0].Guid):$($parentRef[0].FileId)"];if($null-ne$child-and$null-ne$parent){AddProposal $parent $child 'FXObjectContainsObject' 'm_Father' 'Prefab' $info.Evidence @{}}}
    }
    $attackStates=@($subjects|Where-Object subjectKind -CEQ 'AttackAction');$eventSubjectByKey=@{}
    foreach($attack in $attackStates){
        $stateDoc=$docBySubjectId[$attack.subjectId];foreach($clipDoc in @($stateLeaves["$($stateDoc.Guid):$($stateDoc.FileId)"])){$clipKey="$($clipDoc.Guid):$($clipDoc.FileId)";$info=$fileInfo[$clipDoc.FullPath];foreach($block in @($eventBlocksByClip[$clipKey])){$fx=$prefabByGuid[$block.Reference.Guid];if($null-eq$fx){throw 'Attack event FX target is unresolved.'};$eventKey="${clipKey}:$($block.Ordinal)";if(-not$eventSubjectByKey.ContainsKey($eventKey)){$origins=Get-CergOriginsForKind $obligations 'AnimationEvent' '';$event=New-CergParsedSubject $candidateId 'AnimationEvent' "AnimationEvent:${clipKey}:$($block.Ordinal)" $null $clipDoc.RelativePath $info.Sha @($info.Evidence.evidenceId,$info.MetaEvidence.evidenceId) $origins;$subjects.Add($event);$eventSubjectByKey[$eventKey]=$event};$event=$eventSubjectByKey[$eventKey];AddProposal $attack $event 'ActionHasAnimationEvent' "m_Events[$($block.Ordinal)]" 'AnimationEvent' $info.Evidence @{EventTime=$block.Time;EventFunctionName=$block.FunctionName};AddProposal $attack $fx 'AttackTriggersFX' "m_Events[$($block.Ordinal)].objectReferenceParameter" 'AnimationEvent' $info.Evidence @{}}}
    }
    $scopes=[System.Collections.Generic.List[object]]::new();$relationships=[System.Collections.Generic.List[object]]::new()
    foreach($group in ($proposals|Group-Object {"$($_.Source.subjectId)|$($_.AuthorityKind)"})){
        $items=@($group.Group);$owner=$items[0].Source;$authority=$items[0].AuthorityKind;$slots=@($items|ForEach-Object{"$($_.PropertyPath)#$($_.SlotOrdinal)"});$origins=@(Get-CergSortedStrings @($items|ForEach-Object Origins|Select-Object -Unique));$evRefs=@(Get-CergSortedStrings @($items|ForEach-Object{$_.Evidence.evidenceId}|Select-Object -Unique));$scope=New-CergParsedScope $candidateId $authority $owner ($owner.portableRelativePath+'#'+$owner.serializedFileId) $slots $evRefs $origins;$scopes.Add($scope);foreach($item in $items){$relationships.Add((New-CergParsedRelationship $candidateId $item $scope))}
    }
    $results=[System.Collections.Generic.List[object]]::new()
    foreach($obligation in $obligations){$id=[string]$obligation.obligationId;$s=@($subjects|Where-Object{$id-cin@($_.originObligationIds)}|ForEach-Object subjectId);$r=@($relationships|Where-Object{$id-cin@($_.originObligationIds)}|ForEach-Object relationshipId);$e=@($evidence|Where-Object{$id-cin@($_.originObligationIds)}|ForEach-Object evidenceId);$a=@($scopes|Where-Object{$id-cin@($_.originObligationIds)}|ForEach-Object authorityScopeId);$resolved=(@($obligation.requiredSubjectKinds|Where-Object{$_-cnotin@($subjects|ForEach-Object subjectKind)}).Count-eq0-and@($obligation.requiredRelationshipKinds|Where-Object{$_-cnotin@($relationships|ForEach-Object relationshipKind)}).Count-eq0-and$s.Count-gt0-and$r.Count-gt0-and$e.Count-gt0);$results.Add([pscustomobject][ordered]@{obligationId=$id;status=$(if($resolved){'Resolved'}else{'MissingDependency'});subjectRefIds=@(Get-CergSortedStrings $s);relationshipRefIds=@(Get-CergSortedStrings $r);evidenceRefIds=@(Get-CergSortedStrings $e);authorityScopeRefIds=@(Get-CergSortedStrings $a)})}
    $bindings=@{};$evidenceById=@{};foreach($row in $evidence){$evidenceById[$row.evidenceId]=$row};$subjectById=@{};foreach($row in $subjects){$subjectById[$row.subjectId]=$row}
    foreach($file in $fileInfo.Values){foreach($path in @($file.RelativePath,$file.MetaRelativePath)){$related=@($file.RelativePath,$file.MetaRelativePath);$ownedSubjects=@($subjects|Where-Object{$_.portableRelativePath-cin$related});$ownedEvidence=@($evidence|Where-Object{$_.portableRelativePath-cin$related});$ownedScopes=@($scopes|Where-Object{$subjectById[$_.ownerSubjectId].portableRelativePath-cin$related});$ownedRelationships=@($relationships|Where-Object{($subjectById[$_.sourceSubjectId].portableRelativePath-cin$related)-or@($_.evidenceRefIds|Where-Object{$evidenceById[$_].portableRelativePath-cin$related}).Count-gt0});$originIds=@($ownedEvidence|ForEach-Object{@($_.originObligationIds)})+@($ownedSubjects|ForEach-Object{@($_.originObligationIds)})+@($ownedScopes|ForEach-Object{@($_.originObligationIds)})+@($ownedRelationships|ForEach-Object{@($_.originObligationIds)});$bindings[$path]=[pscustomobject]@{subjectRefIds=@(Get-CergSortedStrings @($ownedSubjects|ForEach-Object subjectId));obligationRefIds=@(Get-CergSortedStrings @($originIds|Select-Object -Unique))}}}
    return [pscustomobject]@{EvidenceItems=@($evidence);AuthorityScopes=@($scopes);Subjects=@($subjects);Relationships=@($relationships);ObligationResults=@($results);Bindings=$bindings}
}

function Get-CergSubjectId {
    param([object]$Row)
    return 'SUB-' + (Get-CergStructuredSha256 -DomainTag 'cerg-t1v22/subject-id/1' -Payload @($Row.candidateId, $Row.subjectKind, $Row.authorityIdentity))
}

function Get-CergEvidenceId {
    param([object]$Row)
    return 'EVI-' + (Get-CergStructuredSha256 -DomainTag 'cerg-t1v22/evidence-id/1' -Payload @($Row.inputArtifactId, $Row.evidenceClass, $Row.portableRelativePath, [int64]$Row.byteCount, $Row.sha256, $Row.locatorKind, $Row.locator, @($Row.originObligationIds)))
}

function Get-CergAuthorityScopeId {
    param([object]$Row)
    return 'SCP-' + (Get-CergStructuredSha256 -DomainTag 'cerg-t1v22/authority-scope-id/1' -Payload @($Row.candidateId, $Row.authorityKind, $Row.ownerSubjectId, $Row.scopeLocator))
}

function Get-CergAuthorityScopeFingerprint {
    param([object]$Row)
    return Get-CergStructuredSha256 -DomainTag 'cerg-t1v22/authority-scope/1' -Payload @($Row.candidateId, $Row.authorityKind, $Row.ownerSubjectId, $Row.scopeLocator, $true, @($Row.enumeratedSlotIds), @($Row.evidenceRefIds))
}

function Get-CergRelationshipId {
    param([object]$Row)
    return 'REL-' + (Get-CergStructuredSha256 -DomainTag 'cerg-t1v22/relationship-id/1' -Payload @($Row.candidateId, $Row.sourceSubjectId, $Row.relationshipKind, [int64]$Row.slotOrdinal, $Row.authorityScopeId, $Row.serializedPropertyPath, $Row.overrideSourceClipSubjectId, $Row.blendChildOrdinal, $Row.eventTime, $Row.eventFunctionName))
}

function Add-CergUniqueRow {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Rows,
        [Parameter(Mandatory = $true)][hashtable]$Ids,
        [Parameter(Mandatory = $true)][object]$Row,
        [Parameter(Mandatory = $true)][string]$IdProperty,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $id = [string]$Row.$IdProperty
    if ([string]::IsNullOrWhiteSpace($id) -or $Ids.ContainsKey($id)) { throw "$Label identity is missing or duplicated: $id" }
    $Ids[$id] = $true
    $Rows.Add($Row)
}

function Test-CergGraphModel {
    param(
        [object]$Candidate,
        [object]$Preflight,
        [object[]]$EvidenceItems,
        [object[]]$AuthorityScopes,
        [object[]]$Subjects,
        [object[]]$Relationships,
        [object[]]$ObligationResults,
        [object[]]$OutputMembers,
        [System.Collections.Generic.List[string]]$Errors
    )

    $evidenceById = @{}; foreach ($row in $EvidenceItems) { $evidenceById[[string]$row.evidenceId] = $row }
    $scopeById = @{}; foreach ($row in $AuthorityScopes) { $scopeById[[string]$row.authorityScopeId] = $row }
    $subjectById = @{}; foreach ($row in $Subjects) { $subjectById[[string]$row.subjectId] = $row }
    $relationshipById = @{}; foreach ($row in $Relationships) { $relationshipById[[string]$row.relationshipId] = $row }
    $obligationById = @{}; foreach ($row in $ObligationResults) { $obligationById[[string]$row.obligationId] = $row }
    $candidateObligationIds = Get-CergSortedStrings @($Candidate.discoveryObligations | ForEach-Object { $_.obligationId })
    $resultObligationIds = Get-CergSortedStrings @($ObligationResults | ForEach-Object { $_.obligationId })
    if ((ConvertTo-CergCanonicalJsonValue $candidateObligationIds) -cne (ConvertTo-CergCanonicalJsonValue $resultObligationIds)) { $Errors.Add('ObligationSetMismatch') }

    foreach ($row in $EvidenceItems) {
        try {
            Assert-CergExactProperties $row @('evidenceId','inputArtifactId','evidenceClass','portableRelativePath','byteCount','sha256','locatorKind','locator','originObligationIds') 'EvidenceItem'
            if ($row.evidenceId -cne (Get-CergEvidenceId $row)) { throw 'Evidence identity mismatch.' }
            [void](ConvertTo-CergPortablePath ([string]$row.portableRelativePath))
            $origins = @(Get-CergSortedStrings @($row.originObligationIds))
            if ((ConvertTo-CergCanonicalJsonValue $origins) -cne (ConvertTo-CergCanonicalJsonValue @($row.originObligationIds))) { throw 'Evidence origins are not Ordinal sorted.' }
        } catch { $Errors.Add('InvalidEvidence:' + [string]$row.evidenceId + ':' + $_.Exception.Message) }
    }
    foreach ($row in $AuthorityScopes) {
        try {
            Assert-CergExactProperties $row @('authorityScopeId','candidateId','authorityKind','ownerSubjectId','scopeLocator','isExhaustive','enumeratedSlotIds','evidenceRefIds','originObligationIds','authorityScopeFingerprint') 'AuthorityScope'
            if ($row.authorityScopeId -cne (Get-CergAuthorityScopeId $row) -or $row.authorityScopeFingerprint -cne (Get-CergAuthorityScopeFingerprint $row)) { throw 'Scope identity mismatch.' }
            if ($row.isExhaustive -ne $true -or $row.authorityKind -cnotin $script:CergAuthorityKinds) { throw 'Scope is not exhaustive or has unknown authority.' }
            if (-not $subjectById.ContainsKey([string]$row.ownerSubjectId)) { throw 'Scope owner is unresolved.' }
            foreach ($id in @($row.evidenceRefIds)) { if (-not $evidenceById.ContainsKey([string]$id)) { throw 'Scope evidence is unresolved.' } }
            [void](Get-CergSortedStrings @($row.enumeratedSlotIds)); [void](Get-CergSortedStrings @($row.evidenceRefIds)); [void](Get-CergSortedStrings @($row.originObligationIds))
        } catch { $Errors.Add('InvalidAuthorityScope:' + [string]$row.authorityScopeId) }
    }
    foreach ($row in $Subjects) {
        try {
            Assert-CergExactProperties $row @('subjectId','candidateId','subjectKind','authorityIdentity','unityGuid','serializedFileId','sourceObjectId','portableRelativePath','contentSha256','unityTypeName','rendererKind','componentClass','blendTreeType','parameterName','evidenceRefIds','originObligationIds') 'GraphSubject'
            if ($row.subjectId -cne (Get-CergSubjectId $row) -or $row.subjectKind -cnotin $script:CergSubjectKinds -or $row.candidateId -cne $Candidate.selectedCandidateId) { throw 'Subject identity/kind/candidate mismatch.' }
            foreach ($id in @($row.evidenceRefIds)) { if (-not $evidenceById.ContainsKey([string]$id)) { throw 'Subject evidence is unresolved.' } }
            if ($row.subjectKind -ceq 'Renderer' -and $row.rendererKind -cnotin @('MeshRenderer','SkinnedMeshRenderer','ParticleSystemRenderer','TrailRenderer','OtherRenderer')) { throw 'Renderer kind is invalid.' }
            if ($row.subjectKind -ceq 'FXComponent' -and $row.componentClass -cnotin @('ParticleSystem','TrailRenderer','Renderer','Animator','Transform','OtherSerializedFXComponent')) { throw 'Component class is invalid.' }
            if ($row.subjectKind -ceq 'BlendTree' -and $row.blendTreeType -cnotin @('OneD','SimpleDirectional2D','FreeformDirectional2D','FreeformCartesian2D','Direct')) { throw 'BlendTree type is invalid.' }
            if ($row.subjectKind -ceq 'BlendParameter' -and [string]::IsNullOrWhiteSpace([string]$row.parameterName)) { throw 'Blend parameter name is required.' }
        } catch { $Errors.Add('InvalidSubject:' + [string]$row.subjectId) }
    }
    foreach ($row in $Relationships) {
        try {
            Assert-CergExactProperties $row @('relationshipId','candidateId','slotOrdinal','sourceSubjectId','relationshipKind','targetSubjectId','state','authorityKind','authorityScopeId','authorityScopeFingerprint','serializedPropertyPath','overrideSourceClipSubjectId','blendChildOrdinal','blendThreshold','blendPositionX','blendPositionY','childTimeScale','childCycleOffset','childMirror','directBlendParameterSubjectId','blendParameterValues','eventTime','eventFunctionName','evidenceRefIds','conflictingTargetSubjectIds','obligationId','originObligationIds') 'GraphRelationship'
            if ($row.relationshipId -cne (Get-CergRelationshipId $row) -or [int64]$row.slotOrdinal -lt 1 -or $row.relationshipKind -cnotin $script:CergRelationshipKinds -or $row.state -cnotin $script:CergEvidenceStates) { throw 'Relationship identity or enum is invalid.' }
            if (-not $subjectById.ContainsKey([string]$row.sourceSubjectId)) { throw 'Relationship source is unresolved.' }
            if ($null -ne $row.targetSubjectId -and -not $subjectById.ContainsKey([string]$row.targetSubjectId)) { throw 'Relationship target is unresolved.' }
            foreach ($id in @($row.evidenceRefIds)) { if (-not $evidenceById.ContainsKey([string]$id)) { throw 'Relationship evidence is unresolved.' } }
            if ($null -ne $row.authorityScopeId) {
                if (-not $scopeById.ContainsKey([string]$row.authorityScopeId) -or $scopeById[[string]$row.authorityScopeId].authorityScopeFingerprint -cne $row.authorityScopeFingerprint) { throw 'Relationship authority scope is unresolved.' }
            }
            if ($row.state -ceq 'ProvenPresent' -and ($null -eq $row.targetSubjectId -or @($row.evidenceRefIds).Count -eq 0 -or @($row.conflictingTargetSubjectIds).Count -ne 0 -or $null -ne $row.obligationId)) { throw 'ProvenPresent semantics are invalid.' }
            if ($row.state -ceq 'ProvenAbsent' -and ($null -ne $row.targetSubjectId -or $null -eq $row.authorityScopeId -or @($row.evidenceRefIds).Count -eq 0)) { throw 'ProvenAbsent semantics are invalid.' }
            if ($row.state -in @('EvidenceUnavailableBeforeExtraction','Contradictory')) { throw 'Closed discovery graph may not retain unavailable or contradictory relationships.' }
            if ($row.relationshipKind -ceq 'BlendTreeContainsBranch') {
                if ($null -eq $row.blendChildOrdinal -or $null -eq $row.childTimeScale -or $null -eq $row.childCycleOffset -or $null -eq $row.childMirror) { throw 'Blend child fields are incomplete.' }
                $parameterIds=[System.Collections.Generic.List[string]]::new();foreach($valueRow in @($row.blendParameterValues)){Assert-CergExactProperties $valueRow @('parameterSubjectId','value') 'BlendParameterValue';if(-not$subjectById.ContainsKey([string]$valueRow.parameterSubjectId)-or$subjectById[[string]$valueRow.parameterSubjectId].subjectKind-cne'BlendParameter'){throw 'Blend parameter value identity is unresolved.'};[void](ConvertTo-CergFiniteDecimal ([string]$valueRow.value) 'BlendParameterValue.value');$parameterIds.Add([string]$valueRow.parameterSubjectId)};if((ConvertTo-CergCanonicalJsonValue @(Get-CergSortedStrings $parameterIds))-cne(ConvertTo-CergCanonicalJsonValue @($parameterIds))){throw 'Blend parameter values are not an Ordinal identity set.'}
                $tree=$subjectById[[string]$row.sourceSubjectId];if($tree.blendTreeType-ceq'OneD' -and ($null-eq$row.blendThreshold-or$null-ne$row.blendPositionX-or$null-ne$row.blendPositionY-or$null-ne$row.directBlendParameterSubjectId-or$parameterIds.Count-ne1)){throw 'OneD relationship field partition is invalid.'};if($tree.blendTreeType-cin@('SimpleDirectional2D','FreeformDirectional2D','FreeformCartesian2D') -and ($null-ne$row.blendThreshold-or$null-eq$row.blendPositionX-or$null-eq$row.blendPositionY-or$null-ne$row.directBlendParameterSubjectId-or$parameterIds.Count-ne2)){throw '2D relationship field partition is invalid.'};if($tree.blendTreeType-ceq'Direct' -and ($null-ne$row.blendThreshold-or$null-ne$row.blendPositionX-or$null-ne$row.blendPositionY-or[string]::IsNullOrWhiteSpace([string]$row.directBlendParameterSubjectId)-or$parameterIds.Count-eq0)){throw 'Direct relationship field partition is invalid.'}
            }
            if ($row.relationshipKind -eq 'FXComponentReferencesSubject' -and [string]::IsNullOrWhiteSpace([string]$row.serializedPropertyPath)) { throw 'FX reference property path is required.' }
        } catch { $Errors.Add('InvalidRelationship:' + [string]$row.relationshipId) }
    }

    $pairRules=@{
        AnchorOwnsModel=@(@('CandidateFamilyAnchor'),@('Model'));ModelContainsRenderer=@(@('Model'),@('Renderer'));RendererUsesMesh=@(@('Renderer'),@('Mesh'));RendererUsesMaterial=@(@('Renderer'),@('Material'));RendererUsesSkeleton=@(@('Renderer'),@('Skeleton'))
        SkeletonContainsBone=@(@('Skeleton'),@('Bone'));AvatarUsesSkeleton=@(@('Avatar'),@('Skeleton'));AnchorOwnsActionClip=@(@('CandidateFamilyAnchor'),@('ActionClip'));ActionClipBindsSkeleton=@(@('ActionClip'),@('Skeleton'))
        ControllerOwnsStateMachine=@(@('Controller'),@('StateMachine'));StateMachineContainsStateMachine=@(@('StateMachine'),@('StateMachine'));StateMachineContainsState=@(@('StateMachine'),@('ActionState','AttackAction'));StateUsesMotion=@(@('ActionState','AttackAction'),@('Motion','BlendTree'))
        BlendTreeUsesParameter=@(@('BlendTree'),@('BlendParameter'));BlendTreeContainsBranch=@(@('BlendTree'),@('BlendBranch'));BlendBranchUsesMotion=@(@('BlendBranch'),@('Motion','BlendTree'));MotionUsesClip=@(@('Motion'),@('ActionClip'));OverrideMapsClip=@(@('OverrideController'),@('ActionClip'))
        ActionHasAnimationEvent=@(@('ActionState','AttackAction'),@('AnimationEvent'));AttackTriggersFX=@(@('AttackAction'),@('FXPrefab'));FXPrefabContainsObject=@(@('FXPrefab'),@('FXObject'));FXObjectContainsObject=@(@('FXObject'),@('FXObject'));FXObjectHasComponent=@(@('FXObject'),@('FXComponent','Renderer'))
        FXComponentReferencesSubject=@(@('FXComponent'),$script:CergSubjectKinds);MaterialUsesTexture=@(@('Material'),@('Texture'));MaterialUsesShader=@(@('Material'),@('Shader'));TimelineUsesAction=@(@('Timeline'),@('ActionState','AttackAction'));WeaponUsesAction=@(@('Weapon'),@('ActionState','AttackAction'));ComboUsesAction=@(@('Combo'),@('ActionState','AttackAction'));SerializedObjectReference=@($script:CergSubjectKinds,$script:CergSubjectKinds)
    }
    foreach($row in @($Relationships|Where-Object state -CEQ 'ProvenPresent')){$source=$subjectById[[string]$row.sourceSubjectId];$target=$subjectById[[string]$row.targetSubjectId];$rule=$pairRules[[string]$row.relationshipKind];if($null-eq$rule-or$source.subjectKind-cnotin@($rule[0])-or$target.subjectKind-cnotin@($rule[1])){$Errors.Add('InvalidRelationshipKindPair:' + [string]$row.relationshipId)}}

    $slotKeys = @{}
    foreach ($row in $Relationships) {
        $key = "$($row.candidateId)`u{1f}$($row.sourceSubjectId)`u{1f}$($row.relationshipKind)`u{1f}$($row.slotOrdinal)"
        if ($slotKeys.ContainsKey($key)) { $Errors.Add('DuplicateRelationshipSlot') } else { $slotKeys[$key] = $true }
    }

    foreach ($result in $ObligationResults) {
        try {
            Assert-CergExactProperties $result @('obligationId','status','subjectRefIds','relationshipRefIds','evidenceRefIds','authorityScopeRefIds') 'ObligationResult'
            if ($result.status -cnotin $script:CergObligationStatuses) { throw 'Unknown obligation status.' }
            if ($result.status -ceq 'Resolved' -and (@($result.evidenceRefIds).Count -eq 0 -or @($result.relationshipRefIds).Count -eq 0 -or @($result.subjectRefIds).Count -eq 0)) { throw 'Resolved obligation lacks graph/evidence rows.' }
            foreach ($id in @($result.subjectRefIds)) { if (-not $subjectById.ContainsKey([string]$id)) { throw 'Obligation subject is unresolved.' } }
            foreach ($id in @($result.relationshipRefIds)) { if (-not $relationshipById.ContainsKey([string]$id)) { throw 'Obligation relationship is unresolved.' } }
            foreach ($id in @($result.evidenceRefIds)) { if (-not $evidenceById.ContainsKey([string]$id)) { throw 'Obligation evidence is unresolved.' } }
            foreach ($id in @($result.authorityScopeRefIds)) { if (-not $scopeById.ContainsKey([string]$id)) { throw 'Obligation scope is unresolved.' } }
        } catch { $Errors.Add('InvalidObligationResult:' + [string]$result.obligationId + ':' + $_.Exception.Message) }
    }

    foreach ($row in @($EvidenceItems) + @($AuthorityScopes) + @($Subjects) + @($Relationships)) {
        $origins = @($row.originObligationIds)
        foreach ($origin in $origins) {
            if (-not $obligationById.ContainsKey([string]$origin)) { $Errors.Add('UnknownOriginObligation:' + [string]$origin) }
        }
        if ($origins.Count -gt 0) {
            $id = if ($row.PSObject.Properties['evidenceId']) { $row.evidenceId } elseif ($row.PSObject.Properties['authorityScopeId']) { $row.authorityScopeId } elseif ($row.PSObject.Properties['subjectId']) { $row.subjectId } else { $row.relationshipId }
            foreach ($origin in $origins) {
                if (-not $obligationById.ContainsKey([string]$origin)) { continue }
                $result = $obligationById[[string]$origin]
                if ($null -eq $result.PSObject.Properties['subjectRefIds']) { $Errors.Add('MalformedOriginObligationResult:' + [string]$origin); continue }
                $allRefs = @($result.subjectRefIds) + @($result.relationshipRefIds) + @($result.evidenceRefIds) + @($result.authorityScopeRefIds)
                if ($id -cnotin $allRefs) { $Errors.Add('OriginConservationMismatch:' + [string]$id) }
            }
        }
    }

    foreach ($result in $ObligationResults) {
        foreach ($id in @($result.evidenceRefIds)) { if (-not $evidenceById.ContainsKey([string]$id) -or [string]$result.obligationId -cnotin @($evidenceById[[string]$id].originObligationIds)) { $Errors.Add('ReverseOriginMismatch') } }
        foreach ($id in @($result.authorityScopeRefIds)) { if (-not $scopeById.ContainsKey([string]$id) -or [string]$result.obligationId -cnotin @($scopeById[[string]$id].originObligationIds)) { $Errors.Add('ReverseOriginMismatch') } }
        foreach ($id in @($result.subjectRefIds)) { if (-not $subjectById.ContainsKey([string]$id) -or [string]$result.obligationId -cnotin @($subjectById[[string]$id].originObligationIds)) { $Errors.Add('ReverseOriginMismatch') } }
        foreach ($id in @($result.relationshipRefIds)) { if (-not $relationshipById.ContainsKey([string]$id) -or [string]$result.obligationId -cnotin @($relationshipById[[string]$id].originObligationIds)) { $Errors.Add('ReverseOriginMismatch') } }
    }

    $actualSubjectKinds = @($Subjects | ForEach-Object { $_.subjectKind } | Select-Object -Unique)
    foreach ($kind in @($Preflight.operation.expectedSubjectKinds)) { if ($kind -cnotin $actualSubjectKinds) { $Errors.Add('MissingExpectedSubjectKind:' + [string]$kind) } }
    $actualRelationshipKinds = @($Relationships | ForEach-Object { $_.relationshipKind } | Select-Object -Unique)
    foreach ($kind in @($Preflight.operation.expectedRelationshipKinds)) { if ($kind -cnotin $actualRelationshipKinds) { $Errors.Add('MissingExpectedRelationshipKind:' + [string]$kind) } }

    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -in @('ActionState','AttackAction') })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'StateUsesMotion' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('ActionWithoutMotion:' + [string]$subject.subjectId) }
    }
    function Test-CergMotionTerminatesInClip([string]$SubjectId,[hashtable]$Active){
        if($Active.ContainsKey($SubjectId)){return $false};$next=@{};foreach($key in $Active.Keys){$next[$key]=$true};$next[$SubjectId]=$true;$subject=$subjectById[$SubjectId];if($null-eq$subject){return $false}
        switch([string]$subject.subjectKind){
            'ActionClip'{return $true}
            'Motion'{$edges=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$SubjectId-and$_.relationshipKind-ceq'MotionUsesClip'-and$_.state-ceq'ProvenPresent'})}
            'BlendTree'{$edges=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$SubjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'-and$_.state-ceq'ProvenPresent'})}
            'BlendBranch'{$edges=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$SubjectId-and$_.relationshipKind-ceq'BlendBranchUsesMotion'-and$_.state-ceq'ProvenPresent'})}
            default{return $false}
        }
        if($edges.Count-eq0){return $false};foreach($edge in $edges){if(-not(Test-CergMotionTerminatesInClip ([string]$edge.targetSubjectId) $next)){return $false}};return $true
    }
    foreach($subject in @($Subjects|Where-Object{$_.subjectKind-in@('ActionState','AttackAction')})){foreach($edge in @($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'StateUsesMotion'-and$_.state-ceq'ProvenPresent'})){if(-not(Test-CergMotionTerminatesInClip ([string]$edge.targetSubjectId) @{})){$Errors.Add('NonTerminatingActionPath:' + [string]$subject.subjectId + ':' + [string]$edge.relationshipId)}}}
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'AttackAction' })) {
        $fx=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'AttackTriggersFX'})
        $present=@($fx|Where-Object state -CEQ 'ProvenPresent').Count;$absent=@($fx|Where-Object state -CEQ 'ProvenAbsent').Count
        if(($present+$absent)-eq0-or($present-gt0-and$absent-gt0)){ $Errors.Add('AttackWithoutAuthoritativeFXOutcome:' + [string]$subject.subjectId) }
        if($present-gt0-and@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'ActionHasAnimationEvent'-and$_.state-ceq'ProvenPresent'}).Count-eq0){$Errors.Add('AttackFXWithoutAnimationEvent:' + [string]$subject.subjectId)}
    }
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'Motion' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'MotionUsesClip' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('MotionWithoutClip:' + [string]$subject.subjectId) }
    }
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'FXPrefab' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'FXPrefabContainsObject' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('FXPrefabWithoutObject:' + [string]$subject.subjectId) }
    }
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'FXObject' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'FXObjectHasComponent' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('FXObjectWithoutComponent:' + [string]$subject.subjectId) }
    }
    foreach($subject in @($Subjects|Where-Object subjectKind -CEQ 'StateMachine')){if(@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-in@('StateMachineContainsState','StateMachineContainsStateMachine')}).Count-eq0){$Errors.Add('EmptyStateMachine:' + [string]$subject.subjectId)}}
    foreach($subject in @($Subjects|Where-Object subjectKind -CEQ 'BlendTree')){
        $branches=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'});$parameters=@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'BlendTreeUsesParameter'})
        if($branches.Count-eq0-or$parameters.Count-eq0){$Errors.Add('IncompleteBlendTree:' + [string]$subject.subjectId)}
        $ordinals=@($branches|ForEach-Object blendChildOrdinal|Sort-Object);for($i=0;$i-lt$ordinals.Count;$i++){if([int]$ordinals[$i]-ne$i){$Errors.Add('NonContiguousBlendTree:' + [string]$subject.subjectId);break}}
    }
    foreach($subject in @($Subjects|Where-Object subjectKind -CEQ 'BlendBranch')){if(@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'BlendBranchUsesMotion'}).Count-eq0){$Errors.Add('BlendBranchWithoutMotion:' + [string]$subject.subjectId)}}
    foreach($subject in @($Subjects|Where-Object subjectKind -CEQ 'Material')){if(@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'MaterialUsesTexture'}).Count-eq0-or@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'MaterialUsesShader'}).Count-eq0){$Errors.Add('MaterialClosureIncomplete:' + [string]$subject.subjectId)}}
    foreach($subject in @($Subjects|Where-Object subjectKind -CEQ 'Renderer')){
        if(@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'RendererUsesMaterial'}).Count-eq0){$Errors.Add('RendererWithoutMaterial:' + [string]$subject.subjectId)}
        if($subject.rendererKind-cin@('SkinnedMeshRenderer','MeshRenderer')-and@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'RendererUsesMesh'}).Count-eq0){$Errors.Add('RendererWithoutMesh:' + [string]$subject.subjectId)}
    }
    foreach($subject in @($Subjects|Where-Object{$_.subjectKind-ceq'FXComponent'-and$_.componentClass-cnotin@('Transform','Animator')})){if(@($Relationships|Where-Object{$_.sourceSubjectId-ceq$subject.subjectId-and$_.relationshipKind-ceq'FXComponentReferencesSubject'}).Count-eq0){$Errors.Add('FXComponentReferenceClosureIncomplete:' + [string]$subject.subjectId)}}

    foreach ($member in $OutputMembers) {
        foreach ($id in @($member.subjectRefIds)) { if (-not $subjectById.ContainsKey([string]$id)) { $Errors.Add('OutputSubjectReferenceMissing') } }
        foreach ($id in @($member.obligationRefIds)) { if (-not $obligationById.ContainsKey([string]$id)) { $Errors.Add('OutputObligationReferenceMissing') } }
        try {
            $storedSubjects=@(Get-CergSortedStrings @($member.subjectRefIds));$storedObligations=@(Get-CergSortedStrings @($member.obligationRefIds))
            if((ConvertTo-CergCanonicalJsonValue $storedSubjects)-cne(ConvertTo-CergCanonicalJsonValue @($member.subjectRefIds))){throw 'Output subject IDs are not a canonical set.'}
            if((ConvertTo-CergCanonicalJsonValue $storedObligations)-cne(ConvertTo-CergCanonicalJsonValue @($member.obligationRefIds))){throw 'Output obligation IDs are not a canonical set.'}
            $path=[string]$member.portableRelativePath;$paired=if($path.EndsWith('.meta',[StringComparison]::Ordinal)){$path.Substring(0,$path.Length-5)}else{$path+'.meta'};$related=@($path,$paired)
            $ownedSubjects=@($Subjects|Where-Object{$_.portableRelativePath-cin$related-and@($_.originObligationIds).Count-gt0});$ownedEvidence=@($EvidenceItems|Where-Object{$_.portableRelativePath-cin$related-and@($_.originObligationIds).Count-gt0});$ownedScopes=@($AuthorityScopes|Where-Object{$subjectById[$_.ownerSubjectId].portableRelativePath-cin$related-and@($_.originObligationIds).Count-gt0});$ownedRelationships=@($Relationships|Where-Object{@($_.originObligationIds).Count-gt0-and(($subjectById[$_.sourceSubjectId].portableRelativePath-cin$related)-or@($_.evidenceRefIds|Where-Object{$evidenceById[$_].portableRelativePath-cin$related}).Count-gt0)})
            $expectedSubjects=@(Get-CergSortedStrings @($ownedSubjects|ForEach-Object subjectId));$originIds=@($ownedEvidence|ForEach-Object{@($_.originObligationIds)})+@($ownedSubjects|ForEach-Object{@($_.originObligationIds)})+@($ownedScopes|ForEach-Object{@($_.originObligationIds)})+@($ownedRelationships|ForEach-Object{@($_.originObligationIds)});$expectedObligations=@(Get-CergSortedStrings @($originIds|Select-Object -Unique))
            if((ConvertTo-CergCanonicalJsonValue $storedSubjects)-cne(ConvertTo-CergCanonicalJsonValue $expectedSubjects)){throw 'Output subject attribution differs from the derived union.'}
            if((ConvertTo-CergCanonicalJsonValue $storedObligations)-cne(ConvertTo-CergCanonicalJsonValue $expectedObligations)){throw 'Output obligation attribution differs from the derived union.'}
            if($ownedEvidence.Count+$ownedSubjects.Count+$ownedScopes.Count+$ownedRelationships.Count-eq0){throw 'Output member has no authoritative locator.'}
        } catch { $Errors.Add('OutputAttributionFailure:' + [string]$member.portableRelativePath + ':' + $_.Exception.Message) }
    }
}

function New-CergLo1ResultGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CandidateLockPath,
        [Parameter(Mandatory = $true)][string]$PreflightPath,
        [Parameter(Mandatory = $true)][string]$AttemptStatePath,
        [Parameter(Mandatory = $true)][string]$StagingInventoryPath,
        [Parameter(Mandatory = $true)][string]$OutputRoot,
        [Parameter(Mandatory = $true)][string]$ResultTemporaryPath,
        [Parameter(Mandatory = $true)][string]$ResultPath,
        [string]$FreshnessEvidencePath,
        [string]$FirstSourceOpenReceiptPath,
        [string]$AdjacencyFreshnessPath,
        [string]$ReadinessPath,
        [string]$ReplayPreflightPath,
        [string]$ReplayConfirmationId
    )

    if ([System.IO.File]::Exists($ResultTemporaryPath) -or [System.IO.File]::Exists($ResultPath)) { throw 'R01 temporary/final paths must be initially absent.' }
    $candidate = Read-CergJsonFile $CandidateLockPath
    $preflight = Read-CergJsonFile $PreflightPath
    $freshness = if(-not[string]::IsNullOrWhiteSpace($FreshnessEvidencePath)){Read-CergJsonFile $FreshnessEvidencePath}else{$null}
    $attempt = Read-CergJsonFile $AttemptStatePath
    $staging = Read-CergJsonFile $StagingInventoryPath
    $adjacencyFreshness=if(-not[string]::IsNullOrWhiteSpace($AdjacencyFreshnessPath)){Read-CergJsonFile $AdjacencyFreshnessPath}else{$null}
    $readiness=if(-not[string]::IsNullOrWhiteSpace($ReadinessPath)){Read-CergJsonFile $ReadinessPath}else{$null}
    $replayPreflight=if(-not[string]::IsNullOrWhiteSpace($ReplayPreflightPath)){Read-CergJsonFile $ReplayPreflightPath}else{$null}
    if ($null -ne $replayPreflight) {
        if ($attempt.schemaVersion -cne 'cerg-lo-cerg1-r2-attempt-state/1.0.0' -or [string]::IsNullOrWhiteSpace($ReplayConfirmationId)) { throw 'P04 replay is valid only for a confirmed R2 attempt.' }
        $null=Assert-CergR01ReplayPreflight -Replay $replayPreflight -ReplayPath $ReplayPreflightPath -ConfirmationId $ReplayConfirmationId -Candidate $candidate -CandidatePath $CandidateLockPath -PreflightPath $PreflightPath -FreshnessEvidencePath $FreshnessEvidencePath -ReadinessPath $ReadinessPath -AdjacencyFreshnessPath $AdjacencyFreshnessPath -AttemptStatePath $AttemptStatePath -FirstSourceOpenReceiptPath $FirstSourceOpenReceiptPath -StagingInventoryPath $StagingInventoryPath -OutputRoot $OutputRoot -ResultTemporaryPath $ResultTemporaryPath -ResultPath $ResultPath
    } elseif (-not[string]::IsNullOrWhiteSpace($ReplayConfirmationId)) { throw 'Replay confirmation requires a P04 replay preflight.' }
    Assert-CergUpstreamBindings -Candidate $candidate -Preflight $preflight -Freshness $freshness -FreshnessEvidencePath $FreshnessEvidencePath -AdjacencyFreshness $adjacencyFreshness -AdjacencyFreshnessPath $AdjacencyFreshnessPath -Readiness $readiness -ReadinessPath $ReadinessPath -Attempt $attempt -Staging $staging -CandidatePath $CandidateLockPath -PreflightPath $PreflightPath -AttemptStatePath $AttemptStatePath -FirstSourceOpenReceiptPath $FirstSourceOpenReceiptPath -StagingInventoryPath $StagingInventoryPath -OutputRoot $OutputRoot -ReplayPreflight $replayPreflight
    $budgetSnapshot = Get-CergR01BudgetSnapshot -Attempt $attempt

    $outputFull = Get-CergFullPath $OutputRoot
    if (-not [System.IO.Directory]::Exists($outputFull)) { [System.IO.Directory]::CreateDirectory($outputFull) | Out-Null }
    $outputFiles = [System.Collections.Generic.List[object]]::new()
    foreach ($leaf in [System.IO.Directory]::EnumerateFiles($outputFull, '*', [System.IO.SearchOption]::AllDirectories)) {
        Assert-CergNoReparsePoint -Leaf $leaf -Root $outputFull -Label 'Output member'
        $relative = (Get-CergFullPath $leaf).Substring($outputFull.TrimEnd('\','/').Length + 1).Replace('\','/')
        $outputFiles.Add([pscustomobject]@{ fullPath = $leaf; portableRelativePath = ConvertTo-CergPortablePath $relative; byteCount = [System.IO.FileInfo]::new($leaf).Length; sha256 = Get-CergSha256Hex $leaf })
    }
    if ($null -ne $replayPreflight) {
        $snapshot=Get-CergReplayOutputSnapshot @($outputFiles)
        if ([int64]$snapshot.memberCount -ne [int64]$replayPreflight.discoveryInputSnapshot.memberCount -or
            [int64]$snapshot.byteCount -ne [int64]$replayPreflight.discoveryInputSnapshot.byteCount -or
            $snapshot.fingerprintDomain -cne $replayPreflight.discoveryInputSnapshot.fingerprintDomain -or
            $snapshot.memberSetFingerprint -cne $replayPreflight.discoveryInputSnapshot.memberSetFingerprint) {
            throw 'P04 discovery Output identity drifted before replay.'
        }
    }

    $evidence = [System.Collections.Generic.List[object]]::new(); $evidenceIds = @{}
    $scopes = [System.Collections.Generic.List[object]]::new(); $scopeIds = @{}
    $subjects = [System.Collections.Generic.List[object]]::new(); $subjectIds = @{}
    $relationships = [System.Collections.Generic.List[object]]::new(); $relationshipIds = @{}
    $obligationResults = [System.Collections.Generic.List[object]]::new(); $obligationIds = @{}
    $bindings = @{}
    foreach ($row in @($candidate.evidenceItems)) { Add-CergUniqueRow $evidence $evidenceIds $row 'evidenceId' 'EvidenceItem' }
    foreach ($row in @($candidate.authorityScopes)) { Add-CergUniqueRow $scopes $scopeIds $row 'authorityScopeId' 'AuthorityScope' }
    foreach ($row in @($candidate.subjects)) { Add-CergUniqueRow $subjects $subjectIds $row 'subjectId' 'GraphSubject' }
    foreach ($row in @($candidate.relationships)) { Add-CergUniqueRow $relationships $relationshipIds $row 'relationshipId' 'GraphRelationship' }

    $diagnosticsRejected = $false;$discoveryLoaded=$false
    try {
        $discovery=New-CergUnityYamlGraph -OutputRoot $outputFull -Candidate $candidate -Preflight $preflight
        foreach ($row in @($discovery.EvidenceItems)) { Add-CergUniqueRow $evidence $evidenceIds $row 'evidenceId' 'EvidenceItem' }
        foreach ($row in @($discovery.AuthorityScopes)) { Add-CergUniqueRow $scopes $scopeIds $row 'authorityScopeId' 'AuthorityScope' }
        foreach ($row in @($discovery.Subjects)) { Add-CergUniqueRow $subjects $subjectIds $row 'subjectId' 'GraphSubject' }
        foreach ($row in @($discovery.Relationships)) { Add-CergUniqueRow $relationships $relationshipIds $row 'relationshipId' 'GraphRelationship' }
        foreach ($row in @($discovery.ObligationResults)) { Add-CergUniqueRow $obligationResults $obligationIds $row 'obligationId' 'ObligationResult' }
        $bindings=$discovery.Bindings;$discoveryLoaded=$true
    } catch {
        Write-Verbose ('Direct Unity YAML discovery rejected: ' + $_.Exception.Message)
        $diagnosticsRejected = $true
    }

    $evidenceSorted = @(Get-CergSortedRows @($evidence) { param($x) $x.evidenceId })
    $scopesSorted = @(Get-CergSortedRows @($scopes) { param($x) $x.authorityScopeId })
    $subjectsSorted = @(Get-CergSortedRows @($subjects) { param($x) "$($x.candidateId)`u{1f}$($x.subjectKind)`u{1f}$($x.subjectId)" })
    $relationshipsSorted = @(Get-CergSortedRows @($relationships) { param($x) "$($x.candidateId)`u{1f}$($x.sourceSubjectId)`u{1f}$($x.relationshipKind)`u{1f}$('{0:D10}' -f [int]$x.slotOrdinal)`u{1f}$($x.relationshipId)" })
    $obligationSorted = @(Get-CergSortedRows @($obligationResults) { param($x) $x.obligationId })
    $outputMembers = [System.Collections.Generic.List[object]]::new()
    foreach ($file in (Get-CergSortedRows @($outputFiles) { param($x) $x.portableRelativePath })) {
        $binding = if ($bindings.ContainsKey([string]$file.portableRelativePath)) { $bindings[[string]$file.portableRelativePath] } else { [pscustomobject]@{ subjectRefIds=@(); obligationRefIds=@() } }
        $outputMembers.Add([pscustomobject][ordered]@{
            portableRelativePath = [string]$file.portableRelativePath
            byteCount = [int64]$file.byteCount
            sha256 = [string]$file.sha256
            subjectRefIds = @($binding.subjectRefIds)
            obligationRefIds = @($binding.obligationRefIds)
        })
    }

    $errors = [System.Collections.Generic.List[string]]::new()
    if (-not $discoveryLoaded) { $errors.Add('MissingCompleteDiscoveryGraph') }
    if ($diagnosticsRejected) { $errors.Add('PartialOrMalformedDiagnosticRejected') }
    if ($obligationSorted.Count -eq 0) { $errors.Add('MissingObligationResults') }
    $outputByteCount = [int64](($outputFiles | Measure-Object -Property byteCount -Sum).Sum)
    if ($preflight.operation.PSObject.Properties['maxOutputFiles'] -and $outputFiles.Count -gt [int64]$preflight.operation.maxOutputFiles) { $errors.Add('OutputFileLimitExceeded') }
    if ($preflight.operation.PSObject.Properties['maxOutputBytes'] -and $outputByteCount -gt [int64]$preflight.operation.maxOutputBytes) { $errors.Add('OutputByteLimitExceeded') }
    $resultRowCount = $evidenceSorted.Count + $scopesSorted.Count + $subjectsSorted.Count + $relationshipsSorted.Count + $obligationSorted.Count + $outputMembers.Count
    if ($preflight.operation.PSObject.Properties['maxResultRows'] -and $resultRowCount -gt [int64]$preflight.operation.maxResultRows) { $errors.Add('ResultRowLimitExceeded') }
    Test-CergGraphModel -Candidate $candidate -Preflight $preflight -EvidenceItems $evidenceSorted -AuthorityScopes $scopesSorted -Subjects $subjectsSorted -Relationships $relationshipsSorted -ObligationResults $obligationSorted -OutputMembers @($outputMembers) -Errors $errors

    $stagingMembers = @($staging.memberRows)
    if ($stagingMembers.Count -ne [int64]$preflight.stagingPlan.memberCount -or [int64]$staging.memberCount -ne $stagingMembers.Count) { $errors.Add('StagingConservationMismatch') }
    $unresolved = @($obligationSorted | Where-Object { $_.status -cne 'Resolved' }).Count
    $contradictory = @($relationshipsSorted | Where-Object { $_.state -ceq 'Contradictory' }).Count
    $unavailable = @($relationshipsSorted | Where-Object { $_.state -ceq 'EvidenceUnavailableBeforeExtraction' }).Count
    $isClosed = $errors.Count -eq 0 -and $unresolved -eq 0 -and $obligationSorted.Count -eq 11
    if (-not $isClosed) { Write-Verbose ('R01 closure errors: ' + (@($errors) -join ', ')) }

    $evidenceClassCounts = [ordered]@{}
    foreach ($kind in @('C1SourceProjection','C1FileProjection','LOFFS1WholeFile','UnityMeta','SerializedRelationship','LO1OutputWholeFile','LO1SerializedDiscovery','LO1ToolRun')) { $evidenceClassCounts[$kind] = @($evidenceSorted | Where-Object evidenceClass -CEQ $kind).Count }
    $authorityKindCounts = [ordered]@{}; foreach ($kind in $script:CergAuthorityKinds) { $authorityKindCounts[$kind] = @($scopesSorted | Where-Object authorityKind -CEQ $kind).Count }
    $subjectKindCounts = [ordered]@{}; foreach ($kind in $script:CergSubjectKinds) { $subjectKindCounts[$kind] = @($subjectsSorted | Where-Object subjectKind -CEQ $kind).Count }
    $stateCounts = [ordered]@{}; foreach ($kind in $script:CergEvidenceStates) { $stateCounts[$kind] = @($relationshipsSorted | Where-Object state -CEQ $kind).Count }
    $statusCounts = [ordered]@{}; foreach ($kind in $script:CergObligationStatuses) { $statusCounts[$kind] = @($obligationSorted | Where-Object status -CEQ $kind).Count }
    $graphFingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/exact-universe/2' -Payload @($stagingMembers, $evidenceSorted, $scopesSorted, $subjectsSorted, $relationshipsSorted, $obligationSorted, @($outputMembers))
    $result = [pscustomobject][ordered]@{
        schemaVersion = 'cerg-lo-cerg1-result/1.3.0'
        artifactId = 'LO-CERG1-R01'
        candidateLockSha256 = Get-CergSha256Hex $CandidateLockPath
        preflightSha256 = Get-CergSha256Hex $PreflightPath
        attemptStateSha256 = Get-CergSha256Hex $AttemptStatePath
        stagingInventorySha256 = Get-CergSha256Hex $StagingInventoryPath
        contractHeadCommit = [string]$preflight.contractHeadCommit
        selectedCandidateId = [string]$candidate.selectedCandidateId
        attemptCount = 1
        status = $(if ($isClosed) { 'Closed' } else { 'Unresolved' })
        consumableForT2 = $isClosed
        stagingMembers = $stagingMembers
        evidenceItems = $evidenceSorted
        authorityScopes = $scopesSorted
        subjects = $subjectsSorted
        relationships = $relationshipsSorted
        obligationResults = $obligationSorted
        outputMembers = @($outputMembers)
        partitions = [pscustomobject][ordered]@{
            evidenceClassCounts = [pscustomobject]$evidenceClassCounts
            authorityKindCounts = [pscustomobject]$authorityKindCounts
            subjectKindCounts = [pscustomobject]$subjectKindCounts
            evidenceStateCounts = [pscustomobject]$stateCounts
            obligationStatusCounts = [pscustomobject]$statusCounts
            evidenceItemCount = $evidenceSorted.Count
            authorityScopeCount = $scopesSorted.Count
            subjectCount = $subjectsSorted.Count
            relationshipCount = $relationshipsSorted.Count
            obligationResultCount = $obligationSorted.Count
            stagingMemberCount = $stagingMembers.Count
            outputMemberCount = $outputMembers.Count
        }
        closure = [pscustomobject][ordered]@{
            requiredMissingReferenceCount = $errors.Count
            unclassifiedSubjectCount = 0
            unclassifiedRelationshipCount = 0
            contradictoryRelationshipCount = $contradictory
            evidenceUnavailableCount = $unavailable
            unresolvedObligationCount = $unresolved + $(if ($obligationSorted.Count -ne 11) { [math]::Abs(11 - $obligationSorted.Count) } else { 0 })
            unresolvedExternalIdentityCount = 0
            stagingMismatchCount = @($errors | Where-Object { $_ -eq 'StagingConservationMismatch' }).Count
            graphFingerprint = $graphFingerprint
        }
        summary = [pscustomobject][ordered]@{
            obligationCount = 11
            resolvedCount = @($obligationSorted | Where-Object status -CEQ 'Resolved').Count
            unresolvedCount = 11 - @($obligationSorted | Where-Object status -CEQ 'Resolved').Count
            stagingMemberCount = $stagingMembers.Count
            stagingBytes = [int64](($stagingMembers | Measure-Object -Property byteCount -Sum).Sum)
            outputMemberCount = $outputMembers.Count
            outputBytes = [int64](($outputMembers | Measure-Object -Property byteCount -Sum).Sum)
            attemptCount = 1
            ordinaryTaskUsed = $budgetSnapshot.ordinaryTaskUsed
            ordinaryTaskBudget = $budgetSnapshot.ordinaryTaskBudget
            LOUsed = $budgetSnapshot.LOUsed
            LOBudget = $budgetSnapshot.LOBudget
        }
        nextAction = $(if ($isClosed) { 'RunCERGT2' } else { 'RunCERGT4ForLOCERG1Unresolved' })
    }

    $canonical = ConvertTo-CergCanonicalJsonValue $result
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName((Get-CergFullPath $ResultTemporaryPath))) | Out-Null
    [System.IO.File]::WriteAllText((Get-CergFullPath $ResultTemporaryPath), $canonical, $script:CergUtf8NoBom)
    if ([System.IO.File]::ReadAllText((Get-CergFullPath $ResultTemporaryPath), $script:CergUtf8NoBom) -cne $canonical) { throw 'R01 temporary bytes failed canonical reopen validation.' }
    if ([System.IO.File]::Exists($ResultPath)) { throw 'R01 final path may not be overwritten.' }
    [System.IO.File]::Move((Get-CergFullPath $ResultTemporaryPath), (Get-CergFullPath $ResultPath))
    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    $required = @('CandidateLockPath','PreflightPath','AttemptStatePath','StagingInventoryPath','OutputRoot','ResultTemporaryPath','ResultPath')
    foreach ($name in $required) { if ([string]::IsNullOrWhiteSpace([string](Get-Variable -Name $name -ValueOnly))) { throw "$name is required." } }
    New-CergLo1ResultGraph @PSBoundParameters | ConvertTo-Json -Depth 100
}
