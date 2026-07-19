[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1ResultGraph.ps1')

$script:CergTestImplementationRole = 'FixtureContractTest'
$script:CergTestImplementationVersion = 'CERG-T1A-PIPELINE-TEST/1'

function Write-CergFixtureJson {
    param([string]$Path, [object]$Value, [switch]$Canonical)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Path)) | Out-Null
    $text = if ($Canonical) { ConvertTo-CergCanonicalJsonValue $Value } else { $Value | ConvertTo-Json -Depth 100 }
    [System.IO.File]::WriteAllText($Path, $text, $script:CergUtf8NoBom)
}

function Write-CergFixtureBytes {
    param([string]$Path, [byte[]]$Bytes)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Path)) | Out-Null
    [System.IO.File]::WriteAllBytes($Path, $Bytes)
}

function New-CergFixtureSubject {
    param([string]$Kind, [string]$Name, [string[]]$Origins, [string[]]$EvidenceRefs)
    $row = [pscustomobject][ordered]@{
        subjectId = ''
        candidateId = 'char_14401'
        subjectKind = $Kind
        authorityIdentity = "Synthetic:$Kind`:$Name"
        unityGuid = $(if ($Kind -in @('Model','Mesh','Material','Texture','Shader','Avatar','Controller','OverrideController','ActionClip','FXPrefab')) { ('a' * 32) } else { $null })
        serializedFileId = $(if ($Kind -in @('GameObject','Renderer','StateMachine','ActionState','AttackAction','Motion','BlendTree','BlendParameter','BlendBranch','AnimationEvent','FXObject','FXComponent','Bone','Skeleton','Timeline','Weapon','Combo','ReferencedObject')) { [int64](1000 + $Name.GetHashCode([System.StringComparison]::Ordinal) -band 0x7fffffff) } else { $null })
        sourceObjectId = $(if ($Kind -in @('GameObject','Renderer','StateMachine','ActionState','AttackAction','Motion','BlendTree','BlendParameter','BlendBranch','AnimationEvent','FXObject','FXComponent','Bone','Skeleton','Timeline','Weapon','Combo','ReferencedObject')) { "obj-$Name" } else { $null })
        portableRelativePath = "Synthetic/Output/$Kind-$Name.asset"
        contentSha256 = ('1' * 64)
        unityTypeName = $Kind
        rendererKind = $(if ($Kind -ceq 'Renderer') { 'SkinnedMeshRenderer' } else { $null })
        componentClass = $(if ($Kind -ceq 'FXComponent') { 'ParticleSystem' } else { $null })
        blendTreeType = $(if ($Kind -ceq 'BlendTree') { 'OneD' } else { $null })
        parameterName = $(if ($Kind -ceq 'BlendParameter') { 'Speed' } else { $null })
        evidenceRefIds = @(Get-CergSortedStrings $EvidenceRefs)
        originObligationIds = @(Get-CergSortedStrings $Origins)
    }
    $row.subjectId = Get-CergSubjectId $row
    return $row
}

function New-CergFixtureEvidence {
    param([string]$Name, [string[]]$Origins, [switch]$Baseline)
    $row = [pscustomobject][ordered]@{
        evidenceId = ''
        inputArtifactId = $(if ($Baseline) { 'T1V22-I04' } else { 'LO1-D01' })
        evidenceClass = $(if ($Baseline) { 'LOFFS1WholeFile' } else { 'LO1SerializedDiscovery' })
        portableRelativePath = "Synthetic/Output/$Name.asset"
        byteCount = [int64](100 + $Name.Length)
        sha256 = ('2' * 64)
        locatorKind = $(if ($Baseline) { 'WholeFileIdentity' } else { 'SerializedPropertyPath' })
        locator = $(if ($Baseline) { "Synthetic/WholeFile/$Name" } else { "Synthetic/Serialized/$Name" })
        originObligationIds = @(Get-CergSortedStrings $Origins)
    }
    $row.evidenceId = Get-CergEvidenceId $row
    return $row
}

function New-CergFixtureScope {
    param([string]$Kind, [object]$Owner, [object]$Evidence, [string]$ObligationId)
    $row = [pscustomobject][ordered]@{
        authorityScopeId = ''
        candidateId = 'char_14401'
        authorityKind = $Kind
        ownerSubjectId = $Owner.subjectId
        scopeLocator = "Synthetic/Scope/$Kind"
        isExhaustive = $true
        enumeratedSlotIds = @("$Kind-slot-1")
        evidenceRefIds = @($Evidence.evidenceId)
        originObligationIds = @($ObligationId)
        authorityScopeFingerprint = ''
    }
    $row.authorityScopeId = Get-CergAuthorityScopeId $row
    $row.authorityScopeFingerprint = Get-CergAuthorityScopeFingerprint $row
    return $row
}

function New-CergFixtureRelationship {
    param(
        [string]$Kind,
        [object]$Source,
        [AllowNull()][object]$Target,
        [int]$Slot,
        [object]$Evidence,
        [string[]]$Origins,
        [AllowNull()][object]$Scope,
        [switch]$Blend,
        [switch]$FxReference,
        [switch]$Override,
        [switch]$Event
    )
    $row = [pscustomobject][ordered]@{
        relationshipId = ''
        candidateId = 'char_14401'
        slotOrdinal = $Slot
        sourceSubjectId = $Source.subjectId
        relationshipKind = $Kind
        targetSubjectId = $(if ($null -eq $Target) { $null } else { $Target.subjectId })
        state = 'ProvenPresent'
        authorityKind = $(if ($null -eq $Scope) { $null } else { $Scope.authorityKind })
        authorityScopeId = $(if ($null -eq $Scope) { $null } else { $Scope.authorityScopeId })
        authorityScopeFingerprint = $(if ($null -eq $Scope) { $null } else { $Scope.authorityScopeFingerprint })
        serializedPropertyPath = $(if ($FxReference) { 'm_Materials.Array.data[0]' } else { $null })
        overrideSourceClipSubjectId = $(if ($Override) { $Target.subjectId } else { $null })
        blendChildOrdinal = $(if ($Blend) { 0 } else { $null })
        blendThreshold = $(if ($Blend) { [decimal]0 } else { $null })
        blendPositionX = $null
        blendPositionY = $null
        childTimeScale = $(if ($Blend) { [decimal]1 } else { $null })
        childCycleOffset = $(if ($Blend) { [decimal]0 } else { $null })
        childMirror = $(if ($Blend) { $false } else { $null })
        directBlendParameterSubjectId = $null
        blendParameterValues = @()
        eventTime = $(if ($Event) { [decimal]0.5 } else { $null })
        eventFunctionName = $(if ($Event) { 'SyntheticAttackEvent' } else { $null })
        evidenceRefIds = @($Evidence.evidenceId)
        conflictingTargetSubjectIds = @()
        obligationId = $null
        originObligationIds = @(Get-CergSortedStrings $Origins)
    }
    $row.relationshipId = Get-CergRelationshipId $row
    return $row
}

function New-CergStagingFixture {
    param([string]$CaseRoot, [int]$MemberCount = 1, [switch]$BadSecondHash, [switch]$DirectoryMember, [switch]$EscapeMember, [switch]$DuplicateDestination)
    $sourceRoot = Join-Path $CaseRoot 'Source'
    [System.IO.Directory]::CreateDirectory($sourceRoot) | Out-Null
    $members = [System.Collections.Generic.List[object]]::new()
    $planRows = [System.Collections.Generic.List[object]]::new()
    for ($i = 1; $i -le $MemberCount; $i++) {
        $relative = "bundle/member-$i.bin"
        $bytes = [byte[]](1..(8 + $i) | ForEach-Object { [byte](($_ + $i) % 255) })
        $leaf = Join-Path $sourceRoot $relative
        if ($DirectoryMember -and $i -eq 1) { [System.IO.Directory]::CreateDirectory($leaf) | Out-Null } else { Write-CergFixtureBytes $leaf $bytes }
        $sha = if ($DirectoryMember -and $i -eq 1) { ('0' * 64) } else { Get-CergSha256Hex $leaf }
        if ($BadSecondHash -and $i -eq 2) { $sha = ('f' * 64) }
        if ($EscapeMember -and $i -eq 1) { $relative = '../escape.bin'; Write-CergFixtureBytes (Join-Path $CaseRoot 'escape.bin') $bytes; $sha = Get-CergSha256Hex (Join-Path $CaseRoot 'escape.bin') }
        $memberId = "C1F-SYNTH-$i"
        $member = [pscustomobject][ordered]@{ memberId=$memberId; candidateId='char_14401'; sourceId='fixture-source'; portableRelativePath=$relative; sizeBytes=[int64]$bytes.Length; sha256=$sha; containerKind='UnityBundle'; memberClass='Model'; evidenceRefIds=@() }
        $members.Add($member)
        $destinationName = if ($DuplicateDestination) { 'member.bin' } else { "member-$i.bin" }
        $planRows.Add([pscustomobject][ordered]@{ sourceMemberRefId=$memberId; sourceId='fixture-source'; sourcePortableRelativePath=$relative; stagingPortableRelativePath="Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture-source/bundle/$destinationName"; byteCount=[int64]$bytes.Length; sha256=$sha })
    }
    $stagingRoot = Join-Path $CaseRoot 'Run\Input'
    $planFingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($planRows)
    $candidate = [pscustomobject][ordered]@{ status='Passed'; selectedCandidateId='char_14401'; contractHeadCommit=('a'*40); sourceMembers=@($members); evidenceItems=@(); authorityScopes=@(); subjects=@(); relationships=@(); discoveryObligations=@() }
    $preflight = [pscustomobject][ordered]@{
        status='Green'; selectedCandidateId='char_14401'
        sourceRootBindings=@([pscustomobject][ordered]@{ sourceId='fixture-source'; privateAbsoluteReadOnlyRoot=$sourceRoot; rootFingerprint='synthetic' })
        operation=[pscustomobject][ordered]@{ sourceReadMaxFiles=$MemberCount; sourceReadMaxBytes=[int64](($members|Measure-Object sizeBytes -Sum).Sum); expectedSubjectKinds=@(); expectedRelationshipKinds=@() }
        stagingPlan=[pscustomobject][ordered]@{ stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input'; stagingInputPrivateAbsolutePath=$stagingRoot; memberRows=@($planRows); memberCount=$MemberCount; byteCount=[int64](($members|Measure-Object sizeBytes -Sum).Sum); memberSetFingerprint=$planFingerprint }
    }
    $candidatePath = Join-Path $CaseRoot 'candidate.json'; $preflightPath = Join-Path $CaseRoot 'preflight.json'
    Write-CergFixtureJson $candidatePath $candidate -Canonical; Write-CergFixtureJson $preflightPath $preflight -Canonical
    return [pscustomobject]@{ Candidate=$candidate; Preflight=$preflight; CandidatePath=$candidatePath; PreflightPath=$preflightPath; StagingRoot=$stagingRoot; InventoryTemp=(Join-Path $CaseRoot 'Run\staging-inventory.json.tmp'); Inventory=(Join-Path $CaseRoot 'Run\staging-inventory.json') }
}

function New-CergCompleteGraphFixture {
    param([string]$CaseRoot, [switch]$ReverseArrays)
    $outputRoot = Join-Path $CaseRoot 'Output'; [System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $obligations = 1..11 | ForEach-Object { [pscustomobject][ordered]@{ obligationId=('OBL-SYNTH-{0:D2}' -f $_); obligationKind=('Synthetic{0:D2}' -f $_) } }
    $baselineEvidence = New-CergFixtureEvidence 'baseline' @() -Baseline
    $discoveryEvidence = [System.Collections.Generic.List[object]]::new()
    foreach ($obligation in $obligations) { $discoveryEvidence.Add((New-CergFixtureEvidence $obligation.obligationId @($obligation.obligationId))) }
    $primaryEvidence = $discoveryEvidence[0]; $primaryObligation = $obligations[0].obligationId

    $subjectsByKind = @{}
    foreach ($kind in $script:CergSubjectKinds) {
        $isBaseline = $kind -in @('CandidateFamilyAnchor','Model','Renderer','Mesh','Skeleton','Avatar','ActionClip')
        if ($isBaseline) {
            $subjectsByKind[$kind] = New-CergFixtureSubject -Kind $kind -Name 'primary' -Origins @() -EvidenceRefs @($baselineEvidence.evidenceId)
        } else {
            $subjectsByKind[$kind] = New-CergFixtureSubject -Kind $kind -Name 'primary' -Origins @($primaryObligation) -EvidenceRefs @($primaryEvidence.evidenceId)
        }
    }
    $subjectsByKind['StateMachineNested'] = New-CergFixtureSubject 'StateMachine' 'nested' @($primaryObligation) @($primaryEvidence.evidenceId)
    $subjectsByKind['FXObjectNested'] = New-CergFixtureSubject 'FXObject' 'nested' @($primaryObligation) @($primaryEvidence.evidenceId)

    $scopes = @(
        New-CergFixtureScope 'Controller' $subjectsByKind.Controller $primaryEvidence $primaryObligation
        New-CergFixtureScope 'OverrideController' $subjectsByKind.OverrideController $primaryEvidence $primaryObligation
        New-CergFixtureScope 'Prefab' $subjectsByKind.FXPrefab $primaryEvidence $primaryObligation
        New-CergFixtureScope 'AnimationEvent' $subjectsByKind.AnimationEvent $primaryEvidence $primaryObligation
        New-CergFixtureScope 'SerializedObject' $subjectsByKind.ReferencedObject $primaryEvidence $primaryObligation
    )
    $scope = @{ Controller=$scopes[0]; OverrideController=$scopes[1]; Prefab=$scopes[2]; AnimationEvent=$scopes[3]; SerializedObject=$scopes[4] }
    $relationships = [System.Collections.Generic.List[object]]::new()
    function AddRel($kind,$source,$target,$slot,$authority,[hashtable]$switches) {
        $baseline = $kind -in $script:CergBaselineRelationshipKinds
        $params = @{ Kind=$kind; Source=$source; Target=$target; Slot=$slot; Evidence=$primaryEvidence; Origins=@($primaryObligation); Scope=$scope[$authority] }
        if ($baseline) { $params.Evidence=$baselineEvidence; $params.Origins=@(); $params.Scope=$null }
        foreach($key in $switches.Keys){$params[$key]=$switches[$key]}
        $relationships.Add((New-CergFixtureRelationship @params))
    }
    AddRel 'AnchorOwnsModel' $subjectsByKind.CandidateFamilyAnchor $subjectsByKind.Model 1 'Controller' @{}
    AddRel 'ModelContainsRenderer' $subjectsByKind.Model $subjectsByKind.Renderer 1 'Controller' @{}
    AddRel 'RendererUsesMesh' $subjectsByKind.Renderer $subjectsByKind.Mesh 1 'Controller' @{}
    AddRel 'RendererUsesMaterial' $subjectsByKind.Renderer $subjectsByKind.Material 1 'SerializedObject' @{}
    AddRel 'RendererUsesSkeleton' $subjectsByKind.Renderer $subjectsByKind.Skeleton 1 'Controller' @{}
    AddRel 'SkeletonContainsBone' $subjectsByKind.Skeleton $subjectsByKind.Bone 1 'SerializedObject' @{}
    AddRel 'AvatarUsesSkeleton' $subjectsByKind.Avatar $subjectsByKind.Skeleton 1 'Controller' @{}
    AddRel 'AnchorOwnsActionClip' $subjectsByKind.CandidateFamilyAnchor $subjectsByKind.ActionClip 1 'Controller' @{}
    AddRel 'ActionClipBindsSkeleton' $subjectsByKind.ActionClip $subjectsByKind.Skeleton 1 'Controller' @{}
    AddRel 'ControllerOwnsStateMachine' $subjectsByKind.Controller $subjectsByKind.StateMachine 1 'Controller' @{}
    AddRel 'StateMachineContainsStateMachine' $subjectsByKind.StateMachine $subjectsByKind.StateMachineNested 1 'Controller' @{}
    AddRel 'StateMachineContainsState' $subjectsByKind.StateMachine $subjectsByKind.ActionState 1 'Controller' @{}
    AddRel 'StateMachineContainsState' $subjectsByKind.StateMachine $subjectsByKind.AttackAction 2 'Controller' @{}
    AddRel 'StateUsesMotion' $subjectsByKind.ActionState $subjectsByKind.Motion 1 'Controller' @{}
    AddRel 'StateUsesMotion' $subjectsByKind.AttackAction $subjectsByKind.Motion 1 'Controller' @{}
    AddRel 'StateUsesMotion' $subjectsByKind.ActionState $subjectsByKind.BlendTree 2 'Controller' @{}
    AddRel 'BlendTreeUsesParameter' $subjectsByKind.BlendTree $subjectsByKind.BlendParameter 1 'Controller' @{}
    AddRel 'BlendTreeContainsBranch' $subjectsByKind.BlendTree $subjectsByKind.BlendBranch 1 'Controller' @{Blend=$true}
    AddRel 'BlendBranchUsesMotion' $subjectsByKind.BlendBranch $subjectsByKind.Motion 1 'Controller' @{}
    AddRel 'MotionUsesClip' $subjectsByKind.Motion $subjectsByKind.ActionClip 1 'Controller' @{}
    AddRel 'OverrideMapsClip' $subjectsByKind.OverrideController $subjectsByKind.ActionClip 1 'OverrideController' @{Override=$true}
    AddRel 'ActionHasAnimationEvent' $subjectsByKind.AttackAction $subjectsByKind.AnimationEvent 1 'AnimationEvent' @{Event=$true}
    AddRel 'AttackTriggersFX' $subjectsByKind.AttackAction $subjectsByKind.FXPrefab 1 'AnimationEvent' @{}
    AddRel 'FXPrefabContainsObject' $subjectsByKind.FXPrefab $subjectsByKind.FXObject 1 'Prefab' @{}
    AddRel 'FXObjectContainsObject' $subjectsByKind.FXObject $subjectsByKind.FXObjectNested 1 'Prefab' @{}
    AddRel 'FXObjectHasComponent' $subjectsByKind.FXObject $subjectsByKind.FXComponent 1 'Prefab' @{}
    AddRel 'FXObjectHasComponent' $subjectsByKind.FXObjectNested $subjectsByKind.FXComponent 1 'Prefab' @{}
    AddRel 'FXComponentReferencesSubject' $subjectsByKind.FXComponent $subjectsByKind.Texture 1 'SerializedObject' @{FxReference=$true}
    AddRel 'MaterialUsesTexture' $subjectsByKind.Material $subjectsByKind.Texture 1 'SerializedObject' @{}
    AddRel 'MaterialUsesShader' $subjectsByKind.Material $subjectsByKind.Shader 1 'SerializedObject' @{}
    AddRel 'TimelineUsesAction' $subjectsByKind.Timeline $subjectsByKind.ActionState 1 'SerializedObject' @{}
    AddRel 'WeaponUsesAction' $subjectsByKind.Weapon $subjectsByKind.AttackAction 1 'SerializedObject' @{}
    AddRel 'ComboUsesAction' $subjectsByKind.Combo $subjectsByKind.AttackAction 1 'SerializedObject' @{}
    AddRel 'SerializedObjectReference' $subjectsByKind.FXComponent $subjectsByKind.Mesh 1 'SerializedObject' @{FxReference=$true}

    for ($i=1; $i -lt $obligations.Count; $i++) {
        $obligation=$obligations[$i];$evidenceRow=$discoveryEvidence[$i]
        $extra=New-CergFixtureSubject -Kind 'ReferencedObject' -Name ("obligation-{0:D2}" -f ($i+1)) -Origins @($obligation.obligationId) -EvidenceRefs @($evidenceRow.evidenceId)
        $subjectsByKind["ReferencedObject-$i"]=$extra
        $extraScope=New-CergFixtureScope 'SerializedObject' $extra $evidenceRow $obligation.obligationId
        $scopes += $extraScope
        $relationships.Add((New-CergFixtureRelationship -Kind 'SerializedObjectReference' -Source $subjectsByKind.FXComponent -Target $extra -Slot ($i+1) -Evidence $evidenceRow -Origins @($obligation.obligationId) -Scope $extraScope -FxReference))
    }

    $allSubjects = @($subjectsByKind.Values)
    $results = [System.Collections.Generic.List[object]]::new()
    foreach ($obligation in $obligations) {
        $ev = @($discoveryEvidence | Where-Object { $obligation.obligationId -cin @($_.originObligationIds) } | ForEach-Object evidenceId)
        $subjectRefs=@($allSubjects|Where-Object{$obligation.obligationId -cin @($_.originObligationIds)}|ForEach-Object subjectId|Sort-Object)
        $relationshipRefs=@($relationships|Where-Object{$obligation.obligationId -cin @($_.originObligationIds)}|ForEach-Object relationshipId|Sort-Object)
        $scopeRefs=@($scopes|Where-Object{$obligation.obligationId -cin @($_.originObligationIds)}|ForEach-Object authorityScopeId|Sort-Object)
        $results.Add([pscustomobject][ordered]@{ obligationId=$obligation.obligationId; status='Resolved'; subjectRefIds=$subjectRefs; relationshipRefIds=$relationshipRefs; evidenceRefIds=@($ev); authorityScopeRefIds=$scopeRefs })
    }
    $fragmentPath = Join-Path $outputRoot 'graph.cerggraph.json'
    $binding = [pscustomobject][ordered]@{ portableRelativePath='graph.cerggraph.json'; subjectRefIds=@($allSubjects|ForEach-Object subjectId|Sort-Object); obligationRefIds=@($obligations|ForEach-Object obligationId|Sort-Object) }
    $fragment = [pscustomobject][ordered]@{ schemaVersion='cerg-lo1-discovery-fragment/1.0.0'; artifactId='SYNTHETIC-DISCOVERY'; producerRole='R01GraphProducerDiscovery'; evidenceItems=@($discoveryEvidence); authorityScopes=@($scopes); subjects=@($allSubjects|Where-Object{@($_.originObligationIds).Count-gt 0}); relationships=@($relationships|Where-Object{@($_.originObligationIds).Count-gt 0}); obligationResults=@($results); outputBindings=@($binding) }
    if ($ReverseArrays) { $fragment.evidenceItems=@($fragment.evidenceItems)[($fragment.evidenceItems.Count-1)..0]; $fragment.subjects=@($fragment.subjects)[($fragment.subjects.Count-1)..0]; $fragment.relationships=@($fragment.relationships)[($fragment.relationships.Count-1)..0]; $fragment.obligationResults=@($fragment.obligationResults)[($fragment.obligationResults.Count-1)..0] }
    Write-CergFixtureJson $fragmentPath $fragment -Canonical

    $candidate = [pscustomobject][ordered]@{ status='Passed'; selectedCandidateId='char_14401'; contractHeadCommit=('a'*40); sourceMembers=@([pscustomobject][ordered]@{memberId='C1F-SYNTH-1';candidateId='char_14401';sourceId='fixture';portableRelativePath='bundle.bin';sizeBytes=1;sha256=('3'*64);containerKind='UnityBundle';memberClass='Model';evidenceRefIds=@()}); evidenceItems=@($baselineEvidence); authorityScopes=@(); subjects=@($allSubjects|Where-Object{@($_.originObligationIds).Count-eq 0}); relationships=@($relationships|Where-Object{@($_.originObligationIds).Count-eq 0}); discoveryObligations=@($obligations) }
    $preflight = [pscustomobject][ordered]@{ status='Green'; selectedCandidateId='char_14401'; operation=[pscustomobject][ordered]@{ expectedSubjectKinds=@($script:CergSubjectKinds); expectedRelationshipKinds=@($script:CergRelationshipKinds) } }
    $attempt = [pscustomobject][ordered]@{ status='StartedNoResult' }
    $stageRow=[pscustomobject][ordered]@{sourceMemberRefId='C1F-SYNTH-1';sourceId='fixture';sourcePortableRelativePath='bundle.bin';stagingPortableRelativePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture/bundle.bin';byteCount=1;sha256=('3'*64)}
    $staging=[pscustomobject][ordered]@{status='Complete';memberRows=@($stageRow);memberCount=1;byteCount=1;memberSetFingerprint='synthetic'}
    foreach($pair in @(@('candidate.json',$candidate),@('preflight.json',$preflight),@('attempt.json',$attempt),@('staging.json',$staging))){Write-CergFixtureJson (Join-Path $CaseRoot $pair[0]) $pair[1] -Canonical}
    return [pscustomobject]@{ CandidatePath=(Join-Path $CaseRoot 'candidate.json');PreflightPath=(Join-Path $CaseRoot 'preflight.json');AttemptPath=(Join-Path $CaseRoot 'attempt.json');StagingPath=(Join-Path $CaseRoot 'staging.json');OutputRoot=$outputRoot;ResultTemp=(Join-Path $CaseRoot 'lo-result.json.tmp');Result=(Join-Path $CaseRoot 'lo-result.json') }
}

function Assert-CergFixture { param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message} }

$testDefinitions = @(
    @('T1A-TEST01','ExactLeafAllow'),@('T1A-TEST02','RootDirectoryReject'),@('T1A-TEST03','PathEscapeReject'),@('T1A-TEST04','SizeHashReject'),@('T1A-TEST05','StagingBijection'),@('T1A-TEST06','InterruptedVector'),@('T1A-TEST07','CompleteR01Graph'),@('T1A-TEST08','MissingGraphReject'),@('T1A-TEST09','PartialDiagnosticReject'),@('T1A-TEST10','CanonicalDeterminism')
)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cerg-t1a-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
try {
    for($index=0;$index-lt$testDefinitions.Count;$index++){
        $testId=$testDefinitions[$index][0];$testClass=$testDefinitions[$index][1];$caseRoot=Join-Path $fixtureRoot $testId
        [System.IO.Directory]::CreateDirectory($caseRoot)|Out-Null
        try {
            switch($testId){
                'T1A-TEST01' { $f=New-CergStagingFixture $caseRoot; $r=Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory; Assert-CergFixture ($r.status -ceq 'Complete' -and [System.IO.File]::Exists($f.Inventory) -and -not [System.IO.File]::Exists($f.InventoryTemp)) 'Exact leaf staging did not complete.' }
                'T1A-TEST02' { $f=New-CergStagingFixture $caseRoot -DirectoryMember; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Directory source selector was not rejected.' }
                'T1A-TEST03' { $f=New-CergStagingFixture $caseRoot -EscapeMember; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Path escape was not rejected.' }
                'T1A-TEST04' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Size/hash mismatch was not rejected.' }
                'T1A-TEST05' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -DuplicateDestination; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Non-bijective staging plan was not rejected.' }
                'T1A-TEST06' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{};$leaves=@(if([System.IO.Directory]::Exists($f.StagingRoot)){[System.IO.Directory]::EnumerateFiles($f.StagingRoot,'*',[System.IO.SearchOption]::AllDirectories)}else{@()});Assert-CergFixture ($leaves.Count -eq 1 -and -not [System.IO.File]::Exists($f.Inventory)) 'Interrupted vector did not retain exact partial staging/no inventory state.' }
                'T1A-TEST07' { $f=New-CergCompleteGraphFixture $caseRoot; $r=New-CergLo1ResultGraph $f.CandidatePath $f.PreflightPath $f.AttemptPath $f.StagingPath $f.OutputRoot $f.ResultTemp $f.Result; Assert-CergFixture ($r.status -ceq 'Closed' -and $r.consumableForT2 -and $r.obligationResults.Count -eq 11 -and $r.closure.requiredMissingReferenceCount -eq 0) 'Complete graph did not close.' }
                'T1A-TEST08' { $f=New-CergCompleteGraphFixture $caseRoot; [System.IO.File]::Delete((Join-Path $f.OutputRoot 'graph.cerggraph.json')); Write-CergFixtureBytes (Join-Path $f.OutputRoot 'body.asset') ([byte[]](1,2,3)); $r=New-CergLo1ResultGraph $f.CandidatePath $f.PreflightPath $f.AttemptPath $f.StagingPath $f.OutputRoot $f.ResultTemp $f.Result; Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) 'Missing graph was accepted.' }
                'T1A-TEST09' { $f=New-CergCompleteGraphFixture $caseRoot; $path=Join-Path $f.OutputRoot 'graph.cerggraph.json'; $g=Read-CergJsonFile $path; $g.producerRole='Measure-UnityExportReferenceGraph'; Write-CergFixtureJson $path $g -Canonical; $r=New-CergLo1ResultGraph $f.CandidatePath $f.PreflightPath $f.AttemptPath $f.StagingPath $f.OutputRoot $f.ResultTemp $f.Result; Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) 'Partial diagnostic was accepted as complete R01 evidence.' }
                'T1A-TEST10' { $a=New-CergCompleteGraphFixture (Join-Path $caseRoot 'A');$b=New-CergCompleteGraphFixture (Join-Path $caseRoot 'B');New-CergLo1ResultGraph $a.CandidatePath $a.PreflightPath $a.AttemptPath $a.StagingPath $a.OutputRoot $a.ResultTemp $a.Result|Out-Null;New-CergLo1ResultGraph $b.CandidatePath $b.PreflightPath $b.AttemptPath $b.StagingPath $b.OutputRoot $b.ResultTemp $b.Result|Out-Null;Assert-CergFixture (([System.IO.File]::ReadAllBytes($a.Result) -join ',') -ceq ([System.IO.File]::ReadAllBytes($b.Result) -join ',')) 'Canonical R01 bytes changed for identical logical inputs.' }
            }
            $rows.Add([pscustomobject][ordered]@{testId=$testId;testClass=$testClass;status='Passed';evidenceLocator="SyntheticFixture/$testId/Assertions"})
        } catch {
            $rows.Add([pscustomobject][ordered]@{testId=$testId;testClass=$testClass;status='Failed';evidenceLocator="SyntheticFixture/$testId/FixtureAssertionFailed"})
        }
    }
} finally {
    if([System.IO.Directory]::Exists($fixtureRoot)){[System.IO.Directory]::Delete($fixtureRoot,$true)}
}

$result=[pscustomobject][ordered]@{schemaVersion='cerg-t1a-fixture-result/1.0.0';testRows=@($rows);partitions=[pscustomobject][ordered]@{passedCount=@($rows|Where-Object status -CEQ 'Passed').Count;failedCount=@($rows|Where-Object status -CEQ 'Failed').Count;totalCount=$rows.Count}}
$result | ConvertTo-Json -Depth 10
if($result.partitions.failedCount -ne 0){exit 1}
