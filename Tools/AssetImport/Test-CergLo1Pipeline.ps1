[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1ResultGraph.ps1')

$script:CergTestImplementationRole = 'FixtureContractTest'
$script:CergTestImplementationVersion = 'CERG-T1A-PIPELINE-TEST/2'

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
        subjectId=''; candidateId='char_14401'; subjectKind=$Kind; authorityIdentity="Synthetic:$Kind`:$Name"
        unityGuid=$(if ($Kind -in @('Model','Mesh','Material','Texture','Shader','Avatar','Controller','OverrideController','ActionClip')) { ('a' * 32) } else { $null })
        serializedFileId=$(if ($Kind -in @('GameObject','Renderer','StateMachine','ActionState','AttackAction','Motion','BlendTree','BlendParameter','BlendBranch','AnimationEvent','FXObject','FXComponent','Bone','Skeleton','Timeline','Weapon','Combo','ReferencedObject')) { [int64](1000 + $Name.GetHashCode([System.StringComparison]::Ordinal) -band 0x7fffffff) } else { $null })
        sourceObjectId=$(if ($Kind -in @('GameObject','Renderer','StateMachine','ActionState','AttackAction','Motion','BlendTree','BlendParameter','BlendBranch','AnimationEvent','FXObject','FXComponent','Bone','Skeleton','Timeline','Weapon','Combo','ReferencedObject')) { "obj-$Name" } else { $null })
        portableRelativePath="Synthetic/Baseline/$Kind-$Name.asset"; contentSha256=('1' * 64); unityTypeName=$Kind
        rendererKind=$(if ($Kind -ceq 'Renderer') { 'SkinnedMeshRenderer' } else { $null })
        componentClass=$(if ($Kind -ceq 'FXComponent') { 'ParticleSystem' } else { $null })
        blendTreeType=$(if ($Kind -ceq 'BlendTree') { 'OneD' } else { $null })
        parameterName=$(if ($Kind -ceq 'BlendParameter') { 'Speed' } else { $null })
        evidenceRefIds=@(Get-CergSortedStrings $EvidenceRefs); originObligationIds=@(Get-CergSortedStrings $Origins)
    }
    $row.subjectId = Get-CergSubjectId $row
    return $row
}

function New-CergFixtureEvidence {
    param([string]$Name)
    $row = [pscustomobject][ordered]@{
        evidenceId=''; inputArtifactId='T1V22-I04'; evidenceClass='LOFFS1WholeFile'; portableRelativePath="Synthetic/Baseline/$Name.asset"
        byteCount=[int64](100 + $Name.Length); sha256=('2' * 64); locatorKind='WholeFileIdentity'; locator="Synthetic/WholeFile/$Name"; originObligationIds=@()
    }
    $row.evidenceId = Get-CergEvidenceId $row
    return $row
}

function New-CergFixtureRelationship {
    param([string]$Kind, [object]$Source, [object]$Target, [int]$Slot, [object]$Evidence)
    $row = [pscustomobject][ordered]@{
        relationshipId=''; candidateId='char_14401'; slotOrdinal=$Slot; sourceSubjectId=$Source.subjectId; relationshipKind=$Kind; targetSubjectId=$Target.subjectId
        state='ProvenPresent'; authorityKind=$null; authorityScopeId=$null; authorityScopeFingerprint=$null; serializedPropertyPath=$null
        overrideSourceClipSubjectId=$null; blendChildOrdinal=$null; blendThreshold=$null; blendPositionX=$null; blendPositionY=$null
        childTimeScale=$null; childCycleOffset=$null; childMirror=$null; directBlendParameterSubjectId=$null; blendParameterValues=@()
        eventTime=$null; eventFunctionName=$null; evidenceRefIds=@($Evidence.evidenceId); conflictingTargetSubjectIds=@(); obligationId=$null; originObligationIds=@()
    }
    $row.relationshipId = Get-CergRelationshipId $row
    return $row
}

function New-CergStagingFixture {
    param(
        [string]$CaseRoot,
        [int]$MemberCount = 1,
        [switch]$BadSecondHash,
        [switch]$DirectoryMember,
        [switch]$EscapeMember,
        [switch]$DuplicateDestination,
        [switch]$DuplicateSourceMember
    )
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
        $members.Add([pscustomobject][ordered]@{ memberId=$memberId; candidateId='char_14401'; sourceId='fixture-source'; portableRelativePath=$relative; sizeBytes=[int64]$bytes.Length; sha256=$sha; containerKind='UnityBundle'; memberClass='Model'; evidenceRefIds=@() })
        $planRefId = if ($DuplicateSourceMember -and $i -eq 2) { 'C1F-SYNTH-1' } else { $memberId }
        $destinationName = if ($DuplicateDestination) { 'member.bin' } else { "member-$i.bin" }
        $planRows.Add([pscustomobject][ordered]@{ sourceMemberRefId=$planRefId; sourceId='fixture-source'; sourcePortableRelativePath=$relative; stagingPortableRelativePath="Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture-source/bundle/$destinationName"; byteCount=[int64]$bytes.Length; sha256=$sha })
    }
    $stagingRoot = Join-Path $CaseRoot 'Run\Input'
    $planFingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($planRows)
    $candidate = [pscustomobject][ordered]@{ status='Passed'; selectedCandidateId='char_14401'; contractHeadCommit=('a'*40); sourceMembers=@($members); evidenceItems=@(); authorityScopes=@(); subjects=@(); relationships=@(); discoveryObligations=@() }
    $preflight = [pscustomobject][ordered]@{
        status='Green'; selectedCandidateId='char_14401'
        sourceRootBindings=@([pscustomobject][ordered]@{ sourceId='fixture-source'; privateAbsoluteReadOnlyRoot=$sourceRoot; rootFingerprint='synthetic' })
        operation=[pscustomobject][ordered]@{ inputMemberRefIds=@($members | ForEach-Object memberId); sourceReadMaxFiles=$MemberCount; sourceReadMaxBytes=[int64](($members|Measure-Object sizeBytes -Sum).Sum); expectedSubjectKinds=@(); expectedRelationshipKinds=@() }
        stagingPlan=[pscustomobject][ordered]@{ stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input'; stagingInputPrivateAbsolutePath=$stagingRoot; memberRows=@($planRows); memberCount=$MemberCount; byteCount=[int64](($members|Measure-Object sizeBytes -Sum).Sum); memberSetFingerprint=$planFingerprint }
    }
    $candidatePath = Join-Path $CaseRoot 'candidate.json'; $preflightPath = Join-Path $CaseRoot 'preflight.json'
    Write-CergFixtureJson $candidatePath $candidate -Canonical; Write-CergFixtureJson $preflightPath $preflight -Canonical
    return [pscustomobject]@{ CandidatePath=$candidatePath; PreflightPath=$preflightPath; StagingRoot=$stagingRoot; InventoryTemp=(Join-Path $CaseRoot 'Run\staging-inventory.json.tmp'); Inventory=(Join-Path $CaseRoot 'Run\staging-inventory.json') }
}

function Write-CergUnityYamlFixture {
    param([string]$Path, [string]$Guid, [string]$Text)
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($Path)) | Out-Null
    [System.IO.File]::WriteAllText($Path, ($Text.TrimStart() + "`n"), $script:CergUtf8NoBom)
    [System.IO.File]::WriteAllText(($Path + '.meta'), "fileFormatVersion: 2`nguid: $Guid`n", $script:CergUtf8NoBom)
}

function Get-CergFixtureObligations {
    $definitions = @(
        @('LO1-OB01','ResolveBaseController','Controller','ControllerOwnsStateMachine'),
        @('LO1-OB02','EnumerateControllerGraph','StateMachine','StateMachineContainsState'),
        @('LO1-OB03','EnumerateOverrideMap','OverrideController','OverrideMapsClip'),
        @('LO1-OB04','EnumerateCompleteActionUniverse','BlendTree','BlendTreeContainsBranch'),
        @('LO1-OB05','EnumerateAnimationEvents','AnimationEvent','ActionHasAnimationEvent'),
        @('LO1-OB06','ResolveAttackFXTriggers','FXPrefab','AttackTriggersFX'),
        @('LO1-OB07','EnumerateFXPrefabComponents','FXComponent','FXObjectHasComponent'),
        @('LO1-OB08','ResolveRendererMaterialTextureShader','Material','MaterialUsesTexture'),
        @('LO1-OB09','ResolveSkeletonAvatar','Skeleton','SkeletonContainsBone'),
        @('LO1-OB10','ResolveTimelineWeaponsCombos','Weapon','WeaponUsesAction'),
        @('LO1-OB11','ResolveReferencedDependencies','FXComponent','FXComponentReferencesSubject')
    )
    return @($definitions | ForEach-Object { [pscustomobject][ordered]@{ obligationId=$_[0]; obligationKind=$_[1]; requiredSubjectKinds=@($_[2]); requiredRelationshipKinds=@($_[3]) } })
}

function Get-CergBaselineGraph {
    $evidence = New-CergFixtureEvidence 'char-14401-structural'
    $subjects = @{}
    foreach ($kind in @('CandidateFamilyAnchor','Model','Renderer','Mesh','Material','Texture','Shader','Skeleton','Bone','Avatar','ActionClip')) { $subjects[$kind] = New-CergFixtureSubject $kind 'baseline' @() @($evidence.evidenceId) }
    $relationships = @(
        New-CergFixtureRelationship 'AnchorOwnsModel' $subjects.CandidateFamilyAnchor $subjects.Model 1 $evidence
        New-CergFixtureRelationship 'ModelContainsRenderer' $subjects.Model $subjects.Renderer 1 $evidence
        New-CergFixtureRelationship 'RendererUsesMesh' $subjects.Renderer $subjects.Mesh 1 $evidence
        New-CergFixtureRelationship 'RendererUsesMaterial' $subjects.Renderer $subjects.Material 1 $evidence
        New-CergFixtureRelationship 'RendererUsesSkeleton' $subjects.Renderer $subjects.Skeleton 1 $evidence
        New-CergFixtureRelationship 'MaterialUsesTexture' $subjects.Material $subjects.Texture 1 $evidence
        New-CergFixtureRelationship 'MaterialUsesShader' $subjects.Material $subjects.Shader 1 $evidence
        New-CergFixtureRelationship 'SkeletonContainsBone' $subjects.Skeleton $subjects.Bone 1 $evidence
        New-CergFixtureRelationship 'AvatarUsesSkeleton' $subjects.Avatar $subjects.Skeleton 1 $evidence
        New-CergFixtureRelationship 'AnchorOwnsActionClip' $subjects.CandidateFamilyAnchor $subjects.ActionClip 1 $evidence
        New-CergFixtureRelationship 'ActionClipBindsSkeleton' $subjects.ActionClip $subjects.Skeleton 1 $evidence
    )
    return [pscustomobject]@{ Evidence=$evidence; Subjects=@($subjects.Values); Relationships=$relationships }
}

function New-CergUnityGraphFixture {
    param([string]$CaseRoot, [switch]$ReverseWriteOrder)
    $outputRoot = Join-Path $CaseRoot 'Output'
    [System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null
    $g = [ordered]@{ controller=('c'*32); anim=('a'*32); prefab=('f'*32); material=('d'*32); resources=('e'*32); override=('b'*32); gameplay=('9'*32) }
    $controller = @'
--- !u!91 &1
AnimatorController:
  m_Name: HeroController
  m_StateMachine: {fileID: 2}
--- !u!1107 &2
AnimatorStateMachine:
  m_Name: RootStateMachine
  m_State: {fileID: 3}
  m_State: {fileID: 4}
  m_StateMachine: {fileID: 20}
--- !u!1102 &3
AnimatorState:
  m_Name: Locomotion
  m_Tag: Normal
  m_Motion: {fileID: 5}
--- !u!1102 &4
AnimatorState:
  m_Name: Attack01
  m_Tag: Attack
  m_Motion: {fileID: 75, guid: __ANIM__, type: 3}
--- !u!206 &5
BlendTree:
  m_Name: LocomotionBlend
  m_BlendType: 0
  m_BlendParameter: Speed
  m_Motion: {fileID: 6}
--- !u!206 &6
BlendTree:
  m_Name: DirectionBlend
  m_BlendType: 0
  m_BlendParameter: Direction
  m_Motion: {fileID: 74, guid: __ANIM__, type: 3}
--- !u!1107 &20
AnimatorStateMachine:
  m_Name: NestedStateMachine
  m_State: {fileID: 21}
--- !u!1102 &21
AnimatorState:
  m_Name: NestedIdle
  m_Tag: Normal
  m_Motion: {fileID: 74, guid: __ANIM__, type: 3}
'@.Replace('__ANIM__', $g.anim)
    $anim = @'
--- !u!74 &74
AnimationClip:
  m_Name: Idle
--- !u!74 &75
AnimationClip:
  m_Name: Attack01
  m_Events:
  - time: 0.5
    functionName: SpawnAttackFx
    objectReferenceParameter: {fileID: 100100000, guid: __PREFAB__, type: 3}
'@.Replace('__PREFAB__', $g.prefab)
    $prefab = @'
--- !u!1 &100
GameObject:
  m_Name: AttackFxRoot
  m_Component: {fileID: 101}
  m_Component: {fileID: 102}
  m_Component: {fileID: 103}
--- !u!4 &101
Transform:
  m_Name: RootTransform
  m_GameObject: {fileID: 100}
  m_Father: {fileID: 0}
--- !u!198 &102
ParticleSystem:
  m_Name: Particles
  m_GameObject: {fileID: 100}
  m_Material: {fileID: 21, guid: __MATERIAL__, type: 2}
--- !u!199 &103
ParticleSystemRenderer:
  m_Name: ParticleRenderer
  m_GameObject: {fileID: 100}
  m_Materials: {fileID: 21, guid: __MATERIAL__, type: 2}
--- !u!1 &110
GameObject:
  m_Name: AttackTrail
  m_Component: {fileID: 111}
  m_Component: {fileID: 112}
--- !u!4 &111
Transform:
  m_Name: TrailTransform
  m_GameObject: {fileID: 110}
  m_Father: {fileID: 101}
--- !u!96 &112
TrailRenderer:
  m_Name: Trail
  m_GameObject: {fileID: 110}
  m_Material: {fileID: 21, guid: __MATERIAL__, type: 2}
'@.Replace('__MATERIAL__', $g.material)
    $material = @'
--- !u!21 &21
Material:
  m_Name: AttackFxMaterial
  m_Shader: {fileID: 48, guid: __RESOURCES__, type: 3}
  m_Texture: {fileID: 28, guid: __RESOURCES__, type: 3}
'@.Replace('__RESOURCES__', $g.resources)
    $resources = @'
--- !u!48 &48
Shader:
  m_Name: StellaFxShader
--- !u!28 &28
Texture2D:
  m_Name: StellaFxTexture
--- !u!43 &43
Mesh:
  m_Name: CharacterMesh
--- !u!137 &137
SkinnedMeshRenderer:
  m_Name: CharacterRenderer
  m_Mesh: {fileID: 43}
  m_Materials: {fileID: 21, guid: __MATERIAL__, type: 2}
  m_RootBone: {fileID: 500}
--- !u!5000 &500
Skeleton:
  m_Name: CharacterSkeleton
  m_Bone: {fileID: 501}
--- !u!5001 &501
Bone:
  m_Name: RootBone
--- !u!90 &90
Avatar:
  m_Name: CharacterAvatar
  m_Skeleton: {fileID: 500}
'@.Replace('__MATERIAL__', $g.material)
    $override = @'
--- !u!221 &221
AnimatorOverrideController:
  m_Name: HeroOverride
  m_Controller: {fileID: 1, guid: __CONTROLLER__, type: 2}
  m_OriginalClip: {fileID: 74, guid: __ANIM__, type: 3}
  m_OverrideClip: {fileID: 75, guid: __ANIM__, type: 3}
'@.Replace('__CONTROLLER__', $g.controller).Replace('__ANIM__', $g.anim)
    $gameplay = @'
--- !u!114 &600
TimelineAsset:
  m_Name: CharacterTimeline
  m_Action: {fileID: 3, guid: __CONTROLLER__, type: 2}
--- !u!114 &601
Weapon:
  m_Name: CharacterWeapon
  m_Action: {fileID: 4, guid: __CONTROLLER__, type: 2}
--- !u!114 &602
Combo:
  m_Name: CharacterCombo
  m_Action: {fileID: 4, guid: __CONTROLLER__, type: 2}
'@.Replace('__CONTROLLER__', $g.controller)
    $assets = @(
        [pscustomobject]@{Path='Controller/Hero.controller';Guid=$g.controller;Text=$controller},
        [pscustomobject]@{Path='Animations/Hero.anim';Guid=$g.anim;Text=$anim},
        [pscustomobject]@{Path='FX/Attack.prefab';Guid=$g.prefab;Text=$prefab},
        [pscustomobject]@{Path='Materials/Attack.mat';Guid=$g.material;Text=$material},
        [pscustomobject]@{Path='Models/Resources.asset';Guid=$g.resources;Text=$resources},
        [pscustomobject]@{Path='Controller/Hero.overrideController';Guid=$g.override;Text=$override},
        [pscustomobject]@{Path='Gameplay/Character.asset';Guid=$g.gameplay;Text=$gameplay}
    )
    if ($ReverseWriteOrder) { [array]::Reverse($assets) }
    foreach ($asset in $assets) { Write-CergUnityYamlFixture (Join-Path $outputRoot $asset.Path) $asset.Guid $asset.Text }

    $baseline = Get-CergBaselineGraph
    $obligations = @(Get-CergFixtureObligations)
    $stageRow = [pscustomobject][ordered]@{ sourceMemberRefId='C1F-SYNTH-1'; sourceId='fixture'; sourcePortableRelativePath='bundle.bin'; stagingPortableRelativePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture/bundle.bin'; byteCount=[int64]1; sha256=('3'*64) }
    $stageFingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($stageRow)
    $candidate = [pscustomobject][ordered]@{
        schemaVersion='cerg-t1-candidate-lock/2.2.0'; artifactId='CERG-T1V22-O01'; contractHeadCommit=('a'*40); selectedCandidateId='char_14401'; status='Passed'
        sourceMembers=@([pscustomobject][ordered]@{memberId='C1F-SYNTH-1';candidateId='char_14401';sourceId='fixture';portableRelativePath='bundle.bin';sizeBytes=[int64]1;sha256=('3'*64);containerKind='UnityBundle';memberClass='Model';evidenceRefIds=@()})
        evidenceItems=@($baseline.Evidence); authorityScopes=@(); subjects=@($baseline.Subjects); relationships=@($baseline.Relationships); discoveryObligations=$obligations
    }
    $candidatePath = Join-Path $CaseRoot 'candidate.json'
    Write-CergFixtureJson $candidatePath $candidate -Canonical
    $candidateSha = Get-CergSha256Hex $candidatePath
    $expectedSubjectKinds = @(Get-CergSortedStrings @($obligations | ForEach-Object requiredSubjectKinds | Select-Object -Unique))
    $expectedRelationshipKinds = @(Get-CergSortedStrings @($obligations | ForEach-Object requiredRelationshipKinds | Select-Object -Unique))
    $preflight = [pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight/1.3.0'; artifactId='LO-CERG1-P01'; candidateLockSha256=$candidateSha; contractHeadCommit=('a'*40); selectedCandidateId='char_14401'
        operation=[pscustomobject][ordered]@{inputMemberRefIds=@('C1F-SYNTH-1');expectedSubjectKinds=$expectedSubjectKinds;expectedRelationshipKinds=$expectedRelationshipKinds;maxOutputFiles=100;maxOutputBytes=1000000;maxResultRows=5000}
        stagingPlan=[pscustomobject][ordered]@{memberRows=@($stageRow);memberCount=1;byteCount=[int64]1;memberSetFingerprint=$stageFingerprint}; status='Green'
    }
    $preflightPath = Join-Path $CaseRoot 'preflight.json'
    Write-CergFixtureJson $preflightPath $preflight -Canonical
    $preflightSha = Get-CergSha256Hex $preflightPath
    $attempt = [pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-attempt-state/1.1.0';artifactId='LO-CERG1-A01';candidateLockSha256=$candidateSha;preflightSha256=$preflightSha;contractHeadCommit=('a'*40);selectedCandidateId='char_14401';attemptCount=1;status='StartedNoResult'}
    $staging = [pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-staging-inventory/1.0.0';artifactId='LO-CERG1-SI01';candidateLockSha256=$candidateSha;preflightSha256=$preflightSha;selectedCandidateId='char_14401';memberRows=@($stageRow);memberCount=1;byteCount=[int64]1;memberSetFingerprint=$stageFingerprint;status='Complete'}
    $attemptPath=Join-Path $CaseRoot 'attempt.json';$stagingPath=Join-Path $CaseRoot 'staging.json'
    Write-CergFixtureJson $attemptPath $attempt -Canonical; Write-CergFixtureJson $stagingPath $staging -Canonical
    return [pscustomobject]@{CandidatePath=$candidatePath;PreflightPath=$preflightPath;AttemptPath=$attemptPath;StagingPath=$stagingPath;OutputRoot=$outputRoot;ResultTemp=(Join-Path $CaseRoot 'lo-result.json.tmp');Result=(Join-Path $CaseRoot 'lo-result.json')}
}

function Invoke-CergGraphFixture { param([object]$Fixture) New-CergLo1ResultGraph $Fixture.CandidatePath $Fixture.PreflightPath $Fixture.AttemptPath $Fixture.StagingPath $Fixture.OutputRoot $Fixture.ResultTemp $Fixture.Result }
function Assert-CergFixture { param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message} }
function Remove-CergFixtureLine { param([string]$Path,[string]$Pattern) $text=[System.IO.File]::ReadAllText($Path,$script:CergUtf8NoBom);$next=[regex]::Replace($text,$Pattern,'');if($next-ceq$text){throw "Fixture mutation matched no bytes: $Pattern"};[System.IO.File]::WriteAllText($Path,$next,$script:CergUtf8NoBom) }

$testDefinitions = @(
    @('T1A2-TEST01','ExactLeafAllow'),
    @('T1A2-TEST02','RootDirectoryReject'),
    @('T1A2-TEST03','PathEscapeReject'),
    @('T1A2-TEST04','SizeHashReject'),
    @('T1A2-TEST05','StagingBijection'),
    @('T1A2-TEST06','InterruptedVector'),
    @('T1A2-TEST07','SourceMemberBijectionReject'),
    @('T1A2-TEST08','DirectUnityYamlGraph'),
    @('T1A2-TEST09','MissingGraphReject'),
    @('T1A2-TEST10','PartialDiagnosticReject'),
    @('T1A2-TEST11','AttackWithoutFXReject'),
    @('T1A2-TEST12','ControllerBlendClosureReject'),
    @('T1A2-TEST13','FXMaterialClosureReject'),
    @('T1A2-TEST14','StaleSplicedInputReject'),
    @('T1A2-TEST15','CanonicalDeterminism')
)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cerg-t1a2-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
try {
    foreach($definition in $testDefinitions){
        $testId=$definition[0];$testClass=$definition[1];$caseRoot=Join-Path $fixtureRoot $testId
        [System.IO.Directory]::CreateDirectory($caseRoot)|Out-Null
        try {
            switch($testId){
                'T1A2-TEST01' { $f=New-CergStagingFixture $caseRoot; $r=Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory; Assert-CergFixture ($r.status -ceq 'Complete' -and [System.IO.File]::Exists($f.Inventory) -and -not [System.IO.File]::Exists($f.InventoryTemp)) 'Exact leaf staging did not complete.' }
                'T1A2-TEST02' { $f=New-CergStagingFixture $caseRoot -DirectoryMember; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Directory source selector was not rejected.' }
                'T1A2-TEST03' { $f=New-CergStagingFixture $caseRoot -EscapeMember; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Path escape was not rejected.' }
                'T1A2-TEST04' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Size/hash mismatch was not rejected.' }
                'T1A2-TEST05' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -DuplicateDestination; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Non-bijective staging destination was not rejected.' }
                'T1A2-TEST06' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{};$leaves=@(if([System.IO.Directory]::Exists($f.StagingRoot)){[System.IO.Directory]::EnumerateFiles($f.StagingRoot,'*',[System.IO.SearchOption]::AllDirectories)}else{@()});Assert-CergFixture ($leaves.Count -eq 1 -and -not [System.IO.File]::Exists($f.Inventory)) 'Interrupted vector did not retain exact partial staging/no inventory state.' }
                'T1A2-TEST07' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -DuplicateSourceMember; $rejected=$false;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$rejected=$true};Assert-CergFixture $rejected 'Duplicate-one/omit-one SourceMember plan was accepted.' }
                'T1A2-TEST08' { $f=New-CergUnityGraphFixture $caseRoot; $r=Invoke-CergGraphFixture $f; Assert-CergFixture ($r.status -ceq 'Closed' -and $r.consumableForT2 -and $r.obligationResults.Count -eq 11 -and $r.closure.requiredMissingReferenceCount -eq 0) 'Direct Unity YAML graph did not close.' }
                'T1A2-TEST09' { $f=New-CergUnityGraphFixture $caseRoot;foreach($leaf in @([System.IO.Directory]::EnumerateFiles($f.OutputRoot,'*',[System.IO.SearchOption]::AllDirectories))){[System.IO.File]::Delete($leaf)};Write-CergFixtureBytes (Join-Path $f.OutputRoot 'body.bin') ([byte[]](1,2,3));$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) 'Missing direct Unity graph was accepted.' }
                'T1A2-TEST10' { $f=New-CergUnityGraphFixture $caseRoot;Write-CergFixtureJson (Join-Path $f.OutputRoot 'forbidden.cerggraph.json') ([pscustomobject]@{status='synthetic'}) -Canonical;$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) 'Prebuilt diagnostic graph was accepted as production discovery.' }
                'T1A2-TEST11' { $f=New-CergUnityGraphFixture $caseRoot;Remove-CergFixtureLine (Join-Path $f.OutputRoot 'Animations\Hero.anim') '(?m)^\s*objectReferenceParameter:.*\r?\n';$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) 'AttackAction without authoritative FX was accepted.' }
                'T1A2-TEST12' {
                    $variants=@(
                        @('EmptyNestedStateMachine','(?m)^\s*m_State: \{fileID: 21\}\r?\n'),
                        @('MissingNestedBlendParameter','(?m)^\s*m_BlendParameter: Direction\r?\n'),
                        @('MissingBlendLeaf','(?m)^\s*m_Motion: \{fileID: 74, guid: [0-9a-f]{32}, type: 3\}\r?\n'),
                        @('AttackWithoutMotion','(?m)^\s*m_Motion: \{fileID: 75, guid: [0-9a-f]{32}, type: 3\}\r?\n')
                    )
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);Remove-CergFixtureLine (Join-Path $f.OutputRoot 'Controller\Hero.controller') $variant[1];$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) ("Incomplete controller/BlendTree variant was accepted: " + $variant[0])}
                }
                'T1A2-TEST13' {
                    $variants=@(
                        @('MaterialWithoutTexture','Materials\Attack.mat','(?m)^\s*m_Texture:.*\r?\n'),
                        @('MaterialWithoutShader','Materials\Attack.mat','(?m)^\s*m_Shader:.*\r?\n'),
                        @('FXObjectWithoutComponents','FX\Attack.prefab','(?m)^\s*m_Component: \{fileID: 111\}\r?\n|^\s*m_Component: \{fileID: 112\}\r?\n'),
                        @('FXComponentWithoutReference','FX\Attack.prefab','(?m)^\s*m_Material: \{fileID: 21, guid: [0-9a-f]{32}, type: 2\}\r?\n'),
                        @('RendererWithoutMaterial','FX\Attack.prefab','(?m)^\s*m_Materials: \{fileID: 21, guid: [0-9a-f]{32}, type: 2\}\r?\n')
                    )
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);Remove-CergFixtureLine (Join-Path $f.OutputRoot $variant[1]) $variant[2];$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status -ceq 'Unresolved' -and -not $r.consumableForT2) ("Incomplete FX/material variant was accepted: " + $variant[0])}
                }
                'T1A2-TEST14' {
                    $variants=@(
                        @('WrongCandidateSchema','Candidate','schemaVersion','cerg-t1-candidate-lock/0.0.0'),
                        @('WrongCandidateArtifact','Candidate','artifactId','SPLICED-O01'),
                        @('WrongPreflightSchema','Preflight','schemaVersion','cerg-lo-cerg1-preflight/0.0.0'),
                        @('WrongPreflightArtifact','Preflight','artifactId','SPLICED-P01'),
                        @('StaleCandidateHash','Preflight','candidateLockSha256',('f'*64)),
                        @('StalePreflightHash','Attempt','preflightSha256',('f'*64)),
                        @('SplicedAttemptCandidate','Attempt','candidateLockSha256',('f'*64)),
                        @('SplicedInventoryCandidate','Staging','candidateLockSha256',('f'*64)),
                        @('SplicedInventoryPreflight','Staging','preflightSha256',('f'*64)),
                        @('WrongAttemptArtifact','Attempt','artifactId','SPLICED-A01'),
                        @('WrongInventoryArtifact','Staging','artifactId','SPLICED-SI01')
                    )
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);$path=switch($variant[1]){'Candidate'{$f.CandidatePath}'Preflight'{$f.PreflightPath}'Attempt'{$f.AttemptPath}'Staging'{$f.StagingPath}};$row=Read-CergJsonFile $path;$row.($variant[2])=$variant[3];Write-CergFixtureJson $path $row -Canonical;$rejected=$false;try{Invoke-CergGraphFixture $f|Out-Null}catch{$rejected=$true};Assert-CergFixture ($rejected -and -not [System.IO.File]::Exists($f.Result)) ("Stale/spliced variant was accepted: " + $variant[0])}
                }
                'T1A2-TEST15' { $a=New-CergUnityGraphFixture (Join-Path $caseRoot 'A');$b=New-CergUnityGraphFixture (Join-Path $caseRoot 'B') -ReverseWriteOrder;Invoke-CergGraphFixture $a|Out-Null;Invoke-CergGraphFixture $b|Out-Null;Assert-CergFixture (([System.IO.File]::ReadAllBytes($a.Result) -join ',') -ceq ([System.IO.File]::ReadAllBytes($b.Result) -join ',')) 'Canonical R01 bytes changed for identical logical Unity inputs.' }
            }
            $rows.Add([pscustomobject][ordered]@{testId=$testId;testClass=$testClass;status='Passed';evidenceLocator="SyntheticFixture/$testId/Assertions"})
        } catch {
            Write-Verbose ("$testId fixture failed: " + $_.Exception.Message)
            $rows.Add([pscustomobject][ordered]@{testId=$testId;testClass=$testClass;status='Failed';evidenceLocator="SyntheticFixture/$testId/FixtureAssertionFailed"})
        }
    }
} finally {
    if([System.IO.Directory]::Exists($fixtureRoot)){[System.IO.Directory]::Delete($fixtureRoot,$true)}
}

$result=[pscustomobject][ordered]@{schemaVersion='cerg-t1a-fixture-result/1.1.0';testRows=@($rows);partitions=[pscustomobject][ordered]@{passedCount=@($rows|Where-Object status -CEQ 'Passed').Count;failedCount=@($rows|Where-Object status -CEQ 'Failed').Count;totalCount=$rows.Count}}
$result | ConvertTo-Json -Depth 10
if($result.partitions.failedCount -ne 0){exit 1}
