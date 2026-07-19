[CmdletBinding()]
param(
    [string]$CandidateLockPath,
    [string]$PreflightPath,
    [string]$AttemptStatePath,
    [string]$StagingInventoryPath,
    [string]$OutputRoot,
    [string]$ResultTemporaryPath,
    [string]$ResultPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')

$script:CergGraphImplementationRole = 'R01GraphProducer'
$script:CergGraphImplementationVersion = 'CERG-LO1-R01-PRODUCER/1'
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
            }
            if ($row.relationshipKind -eq 'FXComponentReferencesSubject' -and [string]::IsNullOrWhiteSpace([string]$row.serializedPropertyPath)) { throw 'FX reference property path is required.' }
        } catch { $Errors.Add('InvalidRelationship:' + [string]$row.relationshipId) }
    }

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
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'Motion' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'MotionUsesClip' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('MotionWithoutClip:' + [string]$subject.subjectId) }
    }
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'FXPrefab' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'FXPrefabContainsObject' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('FXPrefabWithoutObject:' + [string]$subject.subjectId) }
    }
    foreach ($subject in @($Subjects | Where-Object { $_.subjectKind -ceq 'FXObject' })) {
        if (@($Relationships | Where-Object { $_.sourceSubjectId -ceq $subject.subjectId -and $_.relationshipKind -ceq 'FXObjectHasComponent' -and $_.state -ceq 'ProvenPresent' }).Count -eq 0) { $Errors.Add('FXObjectWithoutComponent:' + [string]$subject.subjectId) }
    }

    foreach ($member in $OutputMembers) {
        foreach ($id in @($member.subjectRefIds)) { if (-not $subjectById.ContainsKey([string]$id)) { $Errors.Add('OutputSubjectReferenceMissing') } }
        foreach ($id in @($member.obligationRefIds)) { if (-not $obligationById.ContainsKey([string]$id)) { $Errors.Add('OutputObligationReferenceMissing') } }
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
        [Parameter(Mandatory = $true)][string]$ResultPath
    )

    if ([System.IO.File]::Exists($ResultTemporaryPath) -or [System.IO.File]::Exists($ResultPath)) { throw 'R01 temporary/final paths must be initially absent.' }
    $candidate = Read-CergJsonFile $CandidateLockPath
    $preflight = Read-CergJsonFile $PreflightPath
    $attempt = Read-CergJsonFile $AttemptStatePath
    $staging = Read-CergJsonFile $StagingInventoryPath
    if ($candidate.status -cne 'Passed' -or $preflight.status -cne 'Green' -or $attempt.status -cne 'StartedNoResult' -or $staging.status -cne 'Complete') { throw 'R01 inputs are not in their consumable state.' }

    $outputFull = Get-CergFullPath $OutputRoot
    if (-not [System.IO.Directory]::Exists($outputFull)) { [System.IO.Directory]::CreateDirectory($outputFull) | Out-Null }
    $outputFiles = [System.Collections.Generic.List[object]]::new()
    foreach ($leaf in [System.IO.Directory]::EnumerateFiles($outputFull, '*', [System.IO.SearchOption]::AllDirectories)) {
        Assert-CergNoReparsePoint -Leaf $leaf -Root $outputFull -Label 'Output member'
        $relative = (Get-CergFullPath $leaf).Substring($outputFull.TrimEnd('\','/').Length + 1).Replace('\','/')
        $outputFiles.Add([pscustomobject]@{ fullPath = $leaf; portableRelativePath = ConvertTo-CergPortablePath $relative; byteCount = [System.IO.FileInfo]::new($leaf).Length; sha256 = Get-CergSha256Hex $leaf })
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

    $diagnosticsRejected = $false
    $fragments = @($outputFiles | Where-Object { $_.portableRelativePath.EndsWith('.cerggraph.json', [System.StringComparison]::Ordinal) } | ForEach-Object { $_ } )
    foreach ($file in (Get-CergSortedRows $fragments { param($x) $x.portableRelativePath })) {
        try {
            $fragment = Read-CergJsonFile $file.fullPath
            Assert-CergExactProperties $fragment @('schemaVersion','artifactId','producerRole','evidenceItems','authorityScopes','subjects','relationships','obligationResults','outputBindings') 'DiscoveryFragment'
            if ($fragment.schemaVersion -cne 'cerg-lo1-discovery-fragment/1.0.0' -or $fragment.producerRole -cne 'R01GraphProducerDiscovery') { throw 'Partial or foreign diagnostic fragment is forbidden.' }
            foreach ($row in @($fragment.evidenceItems)) { Add-CergUniqueRow $evidence $evidenceIds $row 'evidenceId' 'EvidenceItem' }
            foreach ($row in @($fragment.authorityScopes)) { Add-CergUniqueRow $scopes $scopeIds $row 'authorityScopeId' 'AuthorityScope' }
            foreach ($row in @($fragment.subjects)) { Add-CergUniqueRow $subjects $subjectIds $row 'subjectId' 'GraphSubject' }
            foreach ($row in @($fragment.relationships)) { Add-CergUniqueRow $relationships $relationshipIds $row 'relationshipId' 'GraphRelationship' }
            foreach ($row in @($fragment.obligationResults)) { Add-CergUniqueRow $obligationResults $obligationIds $row 'obligationId' 'ObligationResult' }
            foreach ($binding in @($fragment.outputBindings)) {
                $path = ConvertTo-CergPortablePath ([string]$binding.portableRelativePath)
                if ($bindings.ContainsKey($path)) { throw 'Duplicate output binding.' }
                $bindings[$path] = [pscustomobject]@{ subjectRefIds = @(Get-CergSortedStrings @($binding.subjectRefIds)); obligationRefIds = @(Get-CergSortedStrings @($binding.obligationRefIds)) }
            }
        } catch {
            Write-Verbose ('Discovery fragment rejected: ' + $_.Exception.Message)
            $diagnosticsRejected = $true
        }
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
    if ($fragments.Count -eq 0) { $errors.Add('MissingCompleteDiscoveryGraph') }
    if ($diagnosticsRejected) { $errors.Add('PartialOrMalformedDiagnosticRejected') }
    if ($obligationSorted.Count -eq 0) { $errors.Add('MissingObligationResults') }
    $outputByteCount = [int64](($outputFiles | Measure-Object -Property byteCount -Sum).Sum)
    if ($preflight.operation.PSObject.Properties['maxOutputFiles'] -and $outputFiles.Count -gt [int64]$preflight.operation.maxOutputFiles) { $errors.Add('OutputFileLimitExceeded') }
    if ($preflight.operation.PSObject.Properties['maxOutputBytes'] -and $outputByteCount -gt [int64]$preflight.operation.maxOutputBytes) { $errors.Add('OutputByteLimitExceeded') }
    $resultRowCount = $evidenceSorted.Count + $scopesSorted.Count + $subjectsSorted.Count + $relationshipsSorted.Count + $obligationSorted.Count + $outputMembers.Count
    if ($preflight.operation.PSObject.Properties['maxResultRows'] -and $resultRowCount -gt [int64]$preflight.operation.maxResultRows) { $errors.Add('ResultRowLimitExceeded') }
    Test-CergGraphModel -Candidate $candidate -Preflight $preflight -EvidenceItems $evidenceSorted -AuthorityScopes $scopesSorted -Subjects $subjectsSorted -Relationships $relationshipsSorted -ObligationResults $obligationSorted -OutputMembers @($outputMembers) -Errors $errors

    $stagingMembers = @($staging.memberRows)
    if ($stagingMembers.Count -ne @($candidate.sourceMembers).Count -or [int64]$staging.memberCount -ne $stagingMembers.Count) { $errors.Add('StagingConservationMismatch') }
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
        schemaVersion = 'cerg-lo-cerg1-result/1.2.0'
        artifactId = 'LO-CERG1-R01'
        candidateLockSha256 = Get-CergSha256Hex $CandidateLockPath
        preflightSha256 = Get-CergSha256Hex $PreflightPath
        attemptStateSha256 = Get-CergSha256Hex $AttemptStatePath
        stagingInventorySha256 = Get-CergSha256Hex $StagingInventoryPath
        contractHeadCommit = [string]$candidate.contractHeadCommit
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
            ordinaryTaskUsed = 3
            ordinaryTaskBudget = 6
            LOUsed = 1
            LOBudget = 3
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
