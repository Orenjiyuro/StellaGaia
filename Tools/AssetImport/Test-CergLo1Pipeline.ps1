[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1ResultGraph.ps1')

$script:CergTestImplementationRole = 'FixtureContractTest'
$script:CergTestImplementationVersion = 'CERG-T1A-PIPELINE-TEST/5'

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
    $memberBytes = [int64](($members|Measure-Object sizeBytes -Sum).Sum)
    $definition = [pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight-definition/1.0.0'; artifactId='LO-CERG1-P01-DEFINITION'
        candidateLockSha256=('2'*64); contractHeadCommit=('a'*40); selectedCandidateId='char_14401'; createdAt='2026-07-21T00:00:00Z'
        sourceRootBindings=@([pscustomobject][ordered]@{ sourceId='fixture-source'; privateAbsoluteReadOnlyRoot=$sourceRoot; rootFingerprint=('3'*64) })
        implementationBindings=@()
        operation=[pscustomobject][ordered]@{
            operationId='LO1-OP01'; obligationRefIds=@(); implementationRefIds=@(); inputMemberRefIds=@($members | ForEach-Object memberId)
            expectedSubjectKinds=@(); expectedRelationshipKinds=@(); sourceReadMaxFiles=$MemberCount; sourceReadMaxBytes=$memberBytes
            maxDurationSeconds=1; maxResultRows=1; maxOutputFiles=1; maxOutputBytes=$memberBytes
            stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input'; outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Output'; workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Work'
        }
        aggregateLimits=[pscustomobject][ordered]@{ sourceReadMaxFiles=$MemberCount; sourceReadMaxBytes=$memberBytes; maxDurationSeconds=1; maxResultRows=1; maxOutputFiles=1; maxOutputBytes=$memberBytes }
        stagingPlan=[pscustomobject][ordered]@{
            stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Input'; stagingInventoryTemporaryPath='Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json.tmp'
            stagingInventoryPath='Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json'; workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Work'; outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1/Output'
            memberRows=@($planRows); memberCount=$MemberCount; byteCount=$memberBytes; memberSetFingerprint=$planFingerprint
        }
        status='Green'; nextAction='RequestExactHumanConfirmationForLOCERG1'
    }
    $preflight = New-CergLo1PreflightObject -Definition $definition -AttemptPrivateAbsoluteRoot (Join-Path $CaseRoot 'Run')
    $candidatePath = Join-Path $CaseRoot 'candidate.json'; $preflightPath = Join-Path $CaseRoot 'preflight.json'
    Write-CergFixtureJson $candidatePath $candidate -Canonical; Write-CergFixtureJson $preflightPath $preflight -Canonical
    return [pscustomobject]@{ CandidatePath=$candidatePath; PreflightPath=$preflightPath; StagingRoot=$stagingRoot; InventoryTemp=$preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath; Inventory=$preflight.stagingPlan.stagingInventoryPrivateAbsolutePath }
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
    param([string]$AttackGuid,[string]$AttackPath,[string]$AttackSha,[int64]$AttackBytes,[int64]$AttackFileId=75)
    $evidence = New-CergFixtureEvidence 'char-14401-structural'
    $subjects = @{}
    foreach ($kind in @('CandidateFamilyAnchor','Model','Renderer','Mesh','Material','Texture','Shader','Skeleton','Bone','Avatar','ActionClip')) { $subjects[$kind] = New-CergFixtureSubject $kind 'baseline' @() @($evidence.evidenceId) }
    $subjects.ActionClip.authorityIdentity="BaselineYamlObject:$AttackGuid`:$AttackFileId";$subjects.ActionClip.unityGuid=$AttackGuid;$subjects.ActionClip.serializedFileId=$AttackFileId;$subjects.ActionClip.sourceObjectId="$AttackGuid`:$AttackFileId";$subjects.ActionClip.portableRelativePath=$AttackPath;$subjects.ActionClip.contentSha256=$AttackSha;$subjects.ActionClip.subjectId=Get-CergSubjectId $subjects.ActionClip
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
    $preparedOutputRoot = Join-Path $CaseRoot 'PreparedOutput'
    $attemptRoot = Join-Path $CaseRoot 'Attempt'
    $outputRoot = Join-Path $attemptRoot 'Output'
    [System.IO.Directory]::CreateDirectory($preparedOutputRoot) | Out-Null
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
  m_Childs:
  - m_Motion: {fileID: 6}
    m_Threshold: 0.25
    m_TimeScale: 1.25
    m_CycleOffset: 0.125
    m_Mirror: 1
--- !u!206 &6
BlendTree:
  m_Name: DirectionBlend
  m_BlendType: 0
  m_BlendParameter: Direction
  m_Childs:
  - m_Motion: {fileID: 74, guid: __ANIM__, type: 3}
    m_Threshold: -0.75
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
    foreach ($asset in $assets) { Write-CergUnityYamlFixture (Join-Path $preparedOutputRoot $asset.Path) $asset.Guid $asset.Text }

    $attackPath='Animations/Hero.anim';$attackLeaf=Join-Path $preparedOutputRoot $attackPath;$attackSha=Get-CergSha256Hex $attackLeaf;$attackBytes=[int64]([IO.FileInfo]::new($attackLeaf).Length)
    $baseline = Get-CergBaselineGraph -AttackGuid $g.anim -AttackPath $attackPath -AttackSha $attackSha -AttackBytes $attackBytes
    $obligations = @(Get-CergFixtureObligations)
    $sourceRoot=Join-Path $CaseRoot 'Source';$sourceLeaf=Join-Path $sourceRoot 'bundle.bin';Write-CergFixtureBytes $sourceLeaf ([byte[]](3));$sourceSha=Get-CergSha256Hex $sourceLeaf
    $stageRow = [pscustomobject][ordered]@{ sourceMemberRefId='C1F-SYNTH-1'; sourceId='fixture'; sourcePortableRelativePath='bundle.bin'; stagingPortableRelativePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Input/fixture/bundle.bin'; byteCount=[int64]1; sha256=$sourceSha }
    $stageFingerprint = Get-CergStructuredSha256 -DomainTag 'cerg-lo1/staging-member-set/1' -Payload @($stageRow)
    $candidate = [pscustomobject][ordered]@{
        schemaVersion='cerg-t1-candidate-lock/2.2.0'; artifactId='CERG-T1V22-O01'; contractHeadCommit=('a'*40); selectedCandidateId='char_14401'; status='Passed'
        attackAnchors=@([pscustomobject][ordered]@{attackAnchorId='';candidateId='char_14401';clipSubjectRefId=$baseline.Subjects.Where({$_.subjectKind-ceq'ActionClip'})[0].subjectId;portableRelativePath=$attackPath;byteCount=$attackBytes;sha256=$attackSha;unityGuid=$g.anim;serializedFileId=[int64]75;evidenceRefIds=@($baseline.Evidence.evidenceId);authorityKind='ImmutableFFSAttackClip'})
        sourceMembers=@([pscustomobject][ordered]@{memberId='C1F-SYNTH-1';candidateId='char_14401';sourceId='fixture';portableRelativePath='bundle.bin';sizeBytes=[int64]1;sha256=$sourceSha;containerKind='UnityBundle';memberClass='Model';evidenceRefIds=@()})
        evidenceItems=@($baseline.Evidence); authorityScopes=@(); subjects=@($baseline.Subjects); relationships=@($baseline.Relationships); discoveryObligations=$obligations
    }
    $anchor=$candidate.attackAnchors[0];$anchorBytes=$script:CergUtf8NoBom.GetBytes((ConvertTo-CergCanonicalJsonValue @('cerg-t1/attack-anchor/1',$anchor.candidateId,$anchor.portableRelativePath,[int64]$anchor.byteCount,$anchor.sha256,$anchor.unityGuid,[int64]$anchor.serializedFileId)));$anchor.attackAnchorId='ATK-'+([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($anchorBytes)).ToLowerInvariant())
    $candidatePath = Join-Path $CaseRoot 'candidate.json'
    Write-CergFixtureJson $candidatePath $candidate -Canonical
    $candidateSha = Get-CergSha256Hex $candidatePath
    $expectedSubjectKinds = @(Get-CergSortedStrings @($obligations | ForEach-Object requiredSubjectKinds | Select-Object -Unique))
    $expectedRelationshipKinds = @(Get-CergSortedStrings @($obligations | ForEach-Object requiredRelationshipKinds | Select-Object -Unique))
    $definition = [pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight-definition/1.0.0';artifactId='LO-CERG1-P01-DEFINITION';candidateLockSha256=$candidateSha;contractHeadCommit=('a'*40);selectedCandidateId='char_14401';createdAt='2026-07-21T00:00:00Z'
        sourceRootBindings=@([pscustomobject][ordered]@{sourceId='fixture';privateAbsoluteReadOnlyRoot=$sourceRoot;rootFingerprint=('4'*64)});implementationBindings=@()
        operation=[pscustomobject][ordered]@{operationId='LO1-OP01';obligationRefIds=@($obligations|ForEach-Object obligationId);implementationRefIds=@();inputMemberRefIds=@('C1F-SYNTH-1');expectedSubjectKinds=$expectedSubjectKinds;expectedRelationshipKinds=$expectedRelationshipKinds;sourceReadMaxFiles=1;sourceReadMaxBytes=[int64]1;maxDurationSeconds=30;maxResultRows=5000;maxOutputFiles=100;maxOutputBytes=[int64]1000000;stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Input';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Output';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Work'}
        aggregateLimits=[pscustomobject][ordered]@{sourceReadMaxFiles=1;sourceReadMaxBytes=[int64]1;maxDurationSeconds=30;maxResultRows=5000;maxOutputFiles=100;maxOutputBytes=[int64]1000000}
        stagingPlan=[pscustomobject][ordered]@{stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Input';stagingInventoryTemporaryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/staging-inventory.json.tmp';stagingInventoryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/staging-inventory.json';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Work';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R1/Output';memberRows=@($stageRow);memberCount=1;byteCount=[int64]1;memberSetFingerprint=$stageFingerprint}
        status='Green';nextAction='RequestExactHumanConfirmationForLOCERG1'
    }
    $preflight=New-CergLo1PreflightObject -Definition $definition -AttemptPrivateAbsoluteRoot $attemptRoot
    $preflightPath = Join-Path $CaseRoot 'preflight.json'
    Write-CergFixtureJson $preflightPath $preflight -Canonical
    $preflightSha = Get-CergSha256Hex $preflightPath
    $attempt = [pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-attempt-state/1.1.0';artifactId='LO-CERG1-A01';candidateLockSha256=$candidateSha;preflightSha256=$preflightSha;contractHeadCommit=('a'*40);selectedCandidateId='char_14401';attemptCount=1;status='StartedNoResult'}
    $attemptPath=Join-Path $CaseRoot 'attempt.json';$stagingPath=$preflight.stagingPlan.stagingInventoryPrivateAbsolutePath
    Write-CergFixtureJson $attemptPath $attempt -Canonical
    $null=Invoke-CergLo1ExactStaging $candidatePath $preflightPath $preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath $stagingPath
    [System.IO.Directory]::Move($preparedOutputRoot,$outputRoot)
    return [pscustomobject]@{CandidatePath=$candidatePath;PreflightPath=$preflightPath;AttemptPath=$attemptPath;StagingPath=$stagingPath;OutputRoot=$outputRoot;ResultTemp=(Join-Path $CaseRoot 'lo-result.json.tmp');Result=(Join-Path $CaseRoot 'lo-result.json')}
}

function Invoke-CergGraphFixture { param([object]$Fixture) New-CergLo1ResultGraph $Fixture.CandidatePath $Fixture.PreflightPath $Fixture.AttemptPath $Fixture.StagingPath $Fixture.OutputRoot $Fixture.ResultTemp $Fixture.Result }
function Assert-CergFixture { param([bool]$Condition,[string]$Message) if(-not $Condition){throw $Message} }
function Remove-CergFixtureLine { param([string]$Path,[string]$Pattern) $text=[System.IO.File]::ReadAllText($Path,$script:CergUtf8NoBom);$next=[regex]::Replace($text,$Pattern,'');if($next-ceq$text){throw "Fixture mutation matched no bytes: $Pattern"};[System.IO.File]::WriteAllText($Path,$next,$script:CergUtf8NoBom) }
function Replace-CergFixtureText { param([string]$Path,[string]$Pattern,[string]$Replacement) $text=[IO.File]::ReadAllText($Path,$script:CergUtf8NoBom);$next=[regex]::Replace($text,$Pattern,$Replacement);if($next-ceq$text){throw "Fixture mutation matched no bytes: $Pattern"};[IO.File]::WriteAllText($Path,$next,$script:CergUtf8NoBom) }
function Update-CergFixtureBindings {
    param([object]$Fixture,[object]$Candidate)
    Write-CergFixtureJson $Fixture.CandidatePath $Candidate -Canonical;$candidateSha=Get-CergSha256Hex $Fixture.CandidatePath
    $preflight=Read-CergJsonFile $Fixture.PreflightPath;$preflight.candidateLockSha256=$candidateSha;Write-CergFixtureJson $Fixture.PreflightPath $preflight -Canonical;$preflightSha=Get-CergSha256Hex $Fixture.PreflightPath
    $attempt=Read-CergJsonFile $Fixture.AttemptPath;$attempt.candidateLockSha256=$candidateSha;$attempt.preflightSha256=$preflightSha;Write-CergFixtureJson $Fixture.AttemptPath $attempt -Canonical
    $staging=Read-CergJsonFile $Fixture.StagingPath;$staging.candidateLockSha256=$candidateSha;$staging.preflightSha256=$preflightSha;Write-CergFixtureJson $Fixture.StagingPath $staging -Canonical
}
function Sync-CergFixtureAttackAnchor {
    param([object]$Fixture)
    $candidate=Read-CergJsonFile $Fixture.CandidatePath;$anchor=$candidate.attackAnchors[0];$leaf=Join-Path $Fixture.OutputRoot $anchor.portableRelativePath;$newSha=Get-CergSha256Hex $leaf;$newBytes=[int64]([IO.FileInfo]::new($leaf).Length);$clip=@($candidate.subjects|Where-Object subjectId -CEQ $anchor.clipSubjectRefId)[0];$oldId=$clip.subjectId;$clip.contentSha256=$newSha;$clip.subjectId=Get-CergSubjectId $clip;$anchor.clipSubjectRefId=$clip.subjectId;$anchor.byteCount=$newBytes;$anchor.sha256=$newSha;$bytes=$script:CergUtf8NoBom.GetBytes((ConvertTo-CergCanonicalJsonValue @('cerg-t1/attack-anchor/1',$anchor.candidateId,$anchor.portableRelativePath,$newBytes,$newSha,$anchor.unityGuid,[int64]$anchor.serializedFileId)));$anchor.attackAnchorId='ATK-'+([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant());foreach($relationship in @($candidate.relationships)){if($relationship.sourceSubjectId-ceq$oldId){$relationship.sourceSubjectId=$clip.subjectId};if($relationship.targetSubjectId-ceq$oldId){$relationship.targetSubjectId=$clip.subjectId};$relationship.relationshipId=Get-CergRelationshipId $relationship};Update-CergFixtureBindings $Fixture $candidate
}
function Add-CergRecursiveAttackBlend {
    param([object]$Fixture,[switch]$RemoveAttackTag,[int]$BlendType=0)
    $path=Join-Path $Fixture.OutputRoot 'Controller\Hero.controller';$tagText=if($RemoveAttackTag){''}else{"  m_Tag: Attack`n"};$replacement="AnimatorState:`n  m_Name: Attack01`n${tagText}  m_Motion: {fileID: 30}"
    Replace-CergFixtureText $path 'AnimatorState:\r?\n  m_Name: Attack01\r?\n  m_Tag: Attack\r?\n  m_Motion: \{fileID: 75, guid: [0-9a-f]{32}, type: 3\}' $replacement
    $guid=(Read-CergJsonFile $Fixture.CandidatePath).attackAnchors[0].unityGuid
    $extra="`n--- !u!206 &30`nBlendTree:`n  m_Name: AttackOuter`n  m_BlendType: $BlendType`n  m_BlendParameter: AttackPhase`n  m_Childs:`n  - m_Motion: {fileID: 31}`n    m_Threshold: 0.33`n--- !u!206 &31`nBlendTree:`n  m_Name: AttackInner`n  m_BlendType: 0`n  m_BlendParameter: AttackLeaf`n  m_Childs:`n  - m_Motion: {fileID: 75, guid: $guid, type: 3}`n    m_Threshold: 0.77`n"
    [IO.File]::AppendAllText($path,$extra,$script:CergUtf8NoBom)
}
function Add-CergFixturePrefabClone {
    param([object]$Fixture,[string]$PortablePath,[string]$Guid,[string]$RootName)
    $source=Join-Path $Fixture.OutputRoot 'FX\Attack.prefab';$text=[IO.File]::ReadAllText($source,$script:CergUtf8NoBom).Replace('AttackFxRoot',$RootName)
    Write-CergUnityYamlFixture (Join-Path $Fixture.OutputRoot $PortablePath) $Guid $text
}
function Set-CergFixtureAttackEvents {
    param([object]$Fixture,[object[]]$Rows)
    $path=Join-Path $Fixture.OutputRoot 'Animations\Hero.anim';$text=[IO.File]::ReadAllText($path,$script:CergUtf8NoBom);$prefix=[regex]::Replace($text,'(?ms)^  m_Events:\r?\n.*\z','').TrimEnd("`r","`n");$lines=[System.Collections.Generic.List[string]]::new();$lines.Add($prefix);$lines.Add('  m_Events:')
    foreach($row in $Rows){$lines.Add("  - time: $($row.Time)");$lines.Add("    functionName: $($row.Function)");$lines.Add("    objectReferenceParameter: {fileID: 100100000, guid: $($row.Guid), type: 3}")}
    [IO.File]::WriteAllText($path,(($lines -join "`n")+"`n"),$script:CergUtf8NoBom);Sync-CergFixtureAttackAnchor $Fixture
}
function Get-CergFixtureSubjectByIdentity {
    param([object]$Result,[string]$Kind,[string]$Guid,[int64]$FileId)
    return @($Result.subjects|Where-Object{$_.subjectKind-ceq$Kind-and$_.unityGuid-ceq$Guid-and[int64]$_.serializedFileId-eq$FileId})
}
function Assert-CergResultUnresolved {
    param([object]$Result,[string]$Label)
    Assert-CergFixture ($Result.status-ceq'Unresolved'-and-not$Result.consumableForT2-and$Result.nextAction-ceq'RunCERGT4ForLOCERG1Unresolved'-and$Result.closure.requiredMissingReferenceCount-gt0) "$Label was not deterministically Unresolved."
}

$testDefinitions = @(
    @('T1A3-TEST01','ExactLeafAllow'),
    @('T1A3-TEST02','RootDirectoryReject'),
    @('T1A3-TEST03','PathEscapeReject'),
    @('T1A3-TEST04','SizeHashReject'),
    @('T1A3-TEST05','StagingBijection'),
    @('T1A3-TEST06','InterruptedVector'),
    @('T1A3-TEST07','SourceMemberBijectionReject'),
    @('T1A3-TEST08','DirectUnityYamlGraph'),
    @('T1A3-TEST09','MissingGraphReject'),
    @('T1A3-TEST10','PartialDiagnosticReject'),
    @('T1A3-TEST11','AttackWithoutFXReject'),
    @('T1A3-TEST12','ControllerBlendClosureReject'),
    @('T1A3-TEST13','FXMaterialClosureReject'),
    @('T1A3-TEST14','StaleSplicedInputReject'),
    @('T1A3-TEST15','CanonicalDeterminism'),
    @('T1A3-TEST16','MultiEventElementBinding'),
    @('T1A3-TEST17','BlendTreeOneDMetadata'),
    @('T1A3-TEST18','BlendTreeTwoDMetadata'),
    @('T1A3-TEST19','BlendTreeDirectMetadata'),
    @('T1A3-TEST20','RecursiveAttackBlendFX'),
    @('T1A3-TEST21','AssetRipperPngMetaMaterialShader'),
    @('T1A3-TEST22','PrefabRolePartitionAndAttribution'),
    @('T1A3-TEST23','AttackAnchorClassification'),
    @('T1A4-TEST24','BlendTreeTypeEnumStrict'),
    @('T1A4-TEST25','PreflightV14PrivatePathChain')
)
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cerg-t1a4-' + [guid]::NewGuid().ToString('N'))
[System.IO.Directory]::CreateDirectory($fixtureRoot) | Out-Null
$rows = [System.Collections.Generic.List[object]]::new()
try {
    foreach($definition in $testDefinitions){
        $testId=$definition[0];$testClass=$definition[1];$caseRoot=Join-Path $fixtureRoot $testId
        [System.IO.Directory]::CreateDirectory($caseRoot)|Out-Null
        try {
            $caseId=$testId -replace '^T1A3-','T1A2-'
            switch($caseId){
                'T1A2-TEST01' { $f=New-CergStagingFixture $caseRoot;$r=Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory;$row=$r.memberRows[0];$leaf=Join-Path $f.StagingRoot 'fixture-source\bundle\member-1.bin';Assert-CergFixture ($r.status-ceq'Complete'-and$r.memberCount-eq1-and$r.byteCount-eq9-and$row.sourceMemberRefId-ceq'C1F-SYNTH-1'-and$row.stagingPortableRelativePath-ceq'Extracted/CERG/SingleCharacter/LO-CERG1/Input/fixture-source/bundle/member-1.bin'-and$row.sha256-ceq(Get-CergSha256Hex $leaf)-and[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Exact leaf inventory tuple was not preserved.' }
                'T1A2-TEST02' { $f=New-CergStagingFixture $caseRoot -DirectoryMember;$message='';try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$message=$_.Exception.Message};$leaves=@(if([IO.Directory]::Exists($f.StagingRoot)){[IO.Directory]::EnumerateFiles($f.StagingRoot,'*',[IO.SearchOption]::AllDirectories)}else{@()});Assert-CergFixture ($message-cmatch'leaf|file'-and$leaves.Count-eq0-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Directory source rejection vector was not exact.' }
                'T1A2-TEST03' { $f=New-CergStagingFixture $caseRoot -EscapeMember;$message='';try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$message=$_.Exception.Message};Assert-CergFixture ($message-cmatch'portable|escape|relative'-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Path-escape rejection vector was not exact.' }
                'T1A2-TEST04' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash;$message='';try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$message=$_.Exception.Message};$leaves=@([IO.Directory]::EnumerateFiles($f.StagingRoot,'*',[IO.SearchOption]::AllDirectories));Assert-CergFixture ($message-cmatch'hash|SHA'-and$leaves.Count-eq1-and[IO.Path]::GetFileName($leaves[0])-ceq'member-1.bin'-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Size/hash failure did not preserve the exact one-leaf partial vector.' }
                'T1A2-TEST05' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -DuplicateDestination;$message='';try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$message=$_.Exception.Message};Assert-CergFixture ($message-cmatch'Duplicate|bijection|destination'-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Duplicate staging destination rejection was not exact.' }
                'T1A2-TEST06' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -BadSecondHash;try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{};$leaves=@([IO.Directory]::EnumerateFiles($f.StagingRoot,'*',[IO.SearchOption]::AllDirectories));Assert-CergFixture ($leaves.Count-eq1-and[IO.Path]::GetFileName($leaves[0])-ceq'member-1.bin'-and([IO.FileInfo]::new($leaves[0]).Length)-eq9-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Interrupted vector did not retain exact first leaf/no inventory state.' }
                'T1A2-TEST07' { $f=New-CergStagingFixture $caseRoot -MemberCount 2 -DuplicateSourceMember;$message='';try{Invoke-CergLo1ExactStaging $f.CandidatePath $f.PreflightPath $f.InventoryTemp $f.Inventory|Out-Null}catch{$message=$_.Exception.Message};Assert-CergFixture ($message-cmatch'Duplicate|bijection|SourceMember'-and-not[IO.File]::Exists($f.Inventory)-and-not[IO.File]::Exists($f.InventoryTemp)) 'Duplicate-one/omit-one SourceMember rejection was not exact.' }
                'T1A2-TEST08' { $f=New-CergUnityGraphFixture $caseRoot;$p=Read-CergJsonFile $f.PreflightPath;$si=Read-CergJsonFile $f.StagingPath;$r=Invoke-CergGraphFixture $f;$event=@($r.relationships|Where-Object relationshipKind -CEQ 'ActionHasAnimationEvent')[0];$attackFx=@($r.relationships|Where-Object relationshipKind -CEQ 'AttackTriggersFX')[0];Assert-CergFixture ($p.schemaVersion-ceq'cerg-lo-cerg1-preflight/1.4.0'-and$si.status-ceq'Complete'-and$r.schemaVersion-ceq'cerg-lo-cerg1-result/1.3.0'-and$r.status-ceq'Closed'-and$r.consumableForT2-and$r.obligationResults.Count-eq11-and@($r.obligationResults|Where-Object status -CEQ 'Resolved').Count-eq11-and$r.closure.requiredMissingReferenceCount-eq0-and$r.closure.unresolvedObligationCount-eq0-and$r.summary.ordinaryTaskUsed-eq4-and$r.summary.ordinaryTaskBudget-eq7-and[decimal]$event.eventTime-eq[decimal]0.5-and$event.eventFunctionName-ceq'SpawnAttackFx'-and$event.serializedPropertyPath-ceq'm_Events[0]'-and$attackFx.serializedPropertyPath-ceq'm_Events[0].objectReferenceParameter') 'v1.4 P01 to TG01 staging to ResultGraph R01 semantic chain was not exact.' }
                'T1A2-TEST09' { $f=New-CergUnityGraphFixture $caseRoot;foreach($leaf in @([IO.Directory]::EnumerateFiles($f.OutputRoot,'*',[IO.SearchOption]::AllDirectories))){[IO.File]::Delete($leaf)};Write-CergFixtureBytes (Join-Path $f.OutputRoot 'body.bin') ([byte[]](1,2,3));$r=Invoke-CergGraphFixture $f;$member=$r.outputMembers[0];Assert-CergFixture ($r.status-ceq'Unresolved'-and-not$r.consumableForT2-and$r.obligationResults.Count-eq0-and$member.portableRelativePath-ceq'body.bin'-and$member.byteCount-eq3-and$member.subjectRefIds.Count-eq0-and$member.obligationRefIds.Count-eq0-and$r.nextAction-ceq'RunCERGT4ForLOCERG1Unresolved') 'Missing direct graph vector was not exact.' }
                'T1A2-TEST10' { $f=New-CergUnityGraphFixture $caseRoot;Write-CergFixtureJson (Join-Path $f.OutputRoot 'forbidden.cerggraph.json') ([pscustomobject]@{status='synthetic'}) -Canonical;$r=Invoke-CergGraphFixture $f;$member=@($r.outputMembers|Where-Object portableRelativePath -CEQ 'forbidden.cerggraph.json')[0];Assert-CergFixture ($r.status-ceq'Unresolved'-and-not$r.consumableForT2-and$r.obligationResults.Count-eq0-and$member.subjectRefIds.Count-eq0-and$member.obligationRefIds.Count-eq0-and$r.nextAction-ceq'RunCERGT4ForLOCERG1Unresolved') 'Prebuilt diagnostic rejection vector was not exact.' }
                'T1A2-TEST11' { $f=New-CergUnityGraphFixture $caseRoot;Remove-CergFixtureLine (Join-Path $f.OutputRoot 'Animations\Hero.anim') '(?m)^\s*objectReferenceParameter:.*\r?\n';$r=Invoke-CergGraphFixture $f;Assert-CergFixture ($r.status-ceq'Unresolved'-and-not$r.consumableForT2-and@($r.relationships|Where-Object relationshipKind -CEQ 'AttackTriggersFX').Count-eq0-and@($r.obligationResults|Where-Object obligationId -CEQ 'LO1-OB06').Count-eq0-and$r.nextAction-ceq'RunCERGT4ForLOCERG1Unresolved') 'AttackAction-without-FX rejection vector was not exact.' }
                'T1A2-TEST12' {
                    $variants=@(
                        @('EmptyNestedStateMachine','(?m)^\s*m_State: \{fileID: 21\}\r?\n'),
                        @('MissingNestedBlendParameter','(?m)^\s*m_BlendParameter: Direction\r?\n'),
                        @('MissingBlendLeaf','(?m)^\s*m_Motion: \{fileID: 74, guid: [0-9a-f]{32}, type: 3\}\r?\n'),
                        @('AttackWithoutMotion','(?m)^\s*m_Motion: \{fileID: 75, guid: [0-9a-f]{32}, type: 3\}\r?\n')
                    )
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);Remove-CergFixtureLine (Join-Path $f.OutputRoot 'Controller\Hero.controller') $variant[1];$r=Invoke-CergGraphFixture $f;Assert-CergResultUnresolved $r $variant[0];if($variant[0]-ceq'EmptyNestedStateMachine'){$nested=@($r.subjects|Where-Object{$_.subjectKind-ceq'StateMachine'-and$_.serializedFileId-eq20})[0];Assert-CergFixture (@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$nested.subjectId-and$_.relationshipKind-cin@('StateMachineContainsState','StateMachineContainsStateMachine')}).Count-eq0) 'Empty nested StateMachine retained a child.'}else{Assert-CergFixture ($r.obligationResults.Count-eq0-and@($r.relationships|Where-Object relationshipKind -CEQ 'AttackTriggersFX').Count-eq0) ("Malformed controller variant retained a partial authoritative graph: "+$variant[0])}}
                }
                'T1A2-TEST13' {
                    $variants=@(
                        @('MaterialWithoutTexture','Materials\Attack.mat','(?m)^\s*m_Texture:.*\r?\n'),
                        @('MaterialWithoutShader','Materials\Attack.mat','(?m)^\s*m_Shader:.*\r?\n'),
                        @('FXObjectWithoutComponents','FX\Attack.prefab','(?m)^\s*m_Component: \{fileID: 111\}\r?\n|^\s*m_Component: \{fileID: 112\}\r?\n'),
                        @('FXComponentWithoutReference','FX\Attack.prefab','(?m)^\s*m_Material: \{fileID: 21, guid: [0-9a-f]{32}, type: 2\}\r?\n'),
                        @('RendererWithoutMaterial','FX\Attack.prefab','(?m)^\s*m_Materials: \{fileID: 21, guid: [0-9a-f]{32}, type: 2\}\r?\n')
                    )
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);Remove-CergFixtureLine (Join-Path $f.OutputRoot $variant[1]) $variant[2];$r=Invoke-CergGraphFixture $f;Assert-CergResultUnresolved $r $variant[0];$discoveredMaterial=@($r.subjects|Where-Object portableRelativePath -CEQ 'Materials/Attack.mat')[0];switch($variant[0]){'MaterialWithoutTexture'{Assert-CergFixture (@($r.relationships|Where-Object{$_.relationshipKind-ceq'MaterialUsesTexture'-and$_.sourceSubjectId-ceq$discoveredMaterial.subjectId}).Count-eq0) 'Missing texture still produced MaterialUsesTexture.'}'MaterialWithoutShader'{Assert-CergFixture (@($r.relationships|Where-Object{$_.relationshipKind-ceq'MaterialUsesShader'-and$_.sourceSubjectId-ceq$discoveredMaterial.subjectId}).Count-eq0) 'Missing shader still produced MaterialUsesShader.'}'FXObjectWithoutComponents'{Assert-CergFixture (@($r.subjects|Where-Object{$_.subjectKind-ceq'FXObject'-and$_.serializedFileId-eq110}).Count-eq1-and@($r.relationships|Where-Object{$_.relationshipKind-ceq'FXObjectHasComponent'-and$_.sourceSubjectId-ceq(@($r.subjects|Where-Object serializedFileId -EQ 110)[0].subjectId)}).Count-eq0) 'Componentless FX object retained a component relationship.'}'FXComponentWithoutReference'{Assert-CergFixture (@($r.relationships|Where-Object relationshipKind -CEQ 'FXComponentReferencesSubject').Count-eq0) 'Reference-free FX components retained a subject reference.'}'RendererWithoutMaterial'{Assert-CergFixture (@($r.relationships|Where-Object{$_.relationshipKind-ceq'RendererUsesMaterial'-and$_.sourceSubjectId-ceq(@($r.subjects|Where-Object serializedFileId -EQ 103)[0].subjectId)}).Count-eq0) 'Material-free renderer retained a material relationship.'}}}
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
                    foreach($variant in $variants){$f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);$path=switch($variant[1]){'Candidate'{$f.CandidatePath}'Preflight'{$f.PreflightPath}'Attempt'{$f.AttemptPath}'Staging'{$f.StagingPath}};$row=Read-CergJsonFile $path;$row.($variant[2])=$variant[3];Write-CergFixtureJson $path $row -Canonical;$message='';try{Invoke-CergGraphFixture $f|Out-Null}catch{$message=$_.Exception.Message};Assert-CergFixture (-not[string]::IsNullOrWhiteSpace($message)-and-not[IO.File]::Exists($f.Result)-and-not[IO.File]::Exists($f.ResultTemp)) ("Stale/spliced rejection vector was not exact: " + $variant[0])}
                }
                'T1A2-TEST15' { $a=New-CergUnityGraphFixture (Join-Path $caseRoot 'A');$b=New-CergUnityGraphFixture (Join-Path $caseRoot 'B') -ReverseWriteOrder;$ar=Invoke-CergGraphFixture $a;$br=Invoke-CergGraphFixture $b;Assert-CergFixture ($ar.closure.graphFingerprint-ceq$br.closure.graphFingerprint-and$ar.status-ceq'Closed'-and$br.status-ceq'Closed'-and$ar.summary.resolvedCount-eq11-and$br.summary.resolvedCount-eq11) 'Graph fingerprint, closure, or status changed across equivalent asset graphs with distinct private attempt roots.' }
                'T1A2-TEST16' {
                    $f=New-CergUnityGraphFixture $caseRoot;$secondGuid='8'*32;Add-CergFixturePrefabClone $f 'FX/Impact.prefab' $secondGuid 'ImpactFxRoot';$firstGuid=(Read-CergJsonFile $f.CandidatePath).attackAnchors[0].unityGuid.Replace('a','f')
                    Set-CergFixtureAttackEvents $f @([pscustomobject]@{Time='0.875';Function='SpawnImpactFx';Guid=$secondGuid},[pscustomobject]@{Time='0.125';Function='SpawnAttackFx';Guid=$firstGuid})
                    $r=Invoke-CergGraphFixture $f;$eventRels=@($r.relationships|Where-Object relationshipKind -CEQ 'ActionHasAnimationEvent'|Sort-Object slotOrdinal);$fxRels=@($r.relationships|Where-Object relationshipKind -CEQ 'AttackTriggersFX'|Sort-Object slotOrdinal)
                    Assert-CergFixture ($r.status-ceq'Closed'-and$eventRels.Count-eq2-and$fxRels.Count-eq2) 'Two-event graph did not close exactly.'
                    Assert-CergFixture ([decimal]$eventRels[0].eventTime-eq[decimal]0.875-and$eventRels[0].eventFunctionName-ceq'SpawnImpactFx'-and$eventRels[0].serializedPropertyPath-ceq'm_Events[0]') 'First event element fields were crossed.'
                    Assert-CergFixture ([decimal]$eventRels[1].eventTime-eq[decimal]0.125-and$eventRels[1].eventFunctionName-ceq'SpawnAttackFx'-and$eventRels[1].serializedPropertyPath-ceq'm_Events[1]') 'Second event element fields were crossed.'
                    $fxPaths=@($fxRels|ForEach-Object{$id=$_.targetSubjectId;@($r.subjects|Where-Object subjectId -CEQ $id)[0].portableRelativePath})
                    Assert-CergFixture ($fxPaths[0]-ceq'FX/Impact.prefab'-and$fxPaths[1]-ceq'FX/Attack.prefab'-and$eventRels[0].targetSubjectId-cne$eventRels[1].targetSubjectId) 'Event ordinals did not preserve distinct FX references.'
                }
                'T1A2-TEST17' {
                    $f=New-CergUnityGraphFixture $caseRoot;$r=Invoke-CergGraphFixture $f;$trees=@($r.subjects|Where-Object subjectKind -CEQ 'BlendTree');$outer=@($trees|Where-Object serializedFileId -EQ 5)[0];$inner=@($trees|Where-Object serializedFileId -EQ 6)[0];$outerBranch=@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$outer.subjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'})[0];$innerBranch=@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$inner.subjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'})[0]
                    Assert-CergFixture ($outer.blendTreeType-ceq'OneD'-and$inner.blendTreeType-ceq'OneD') 'OneD tree type was not parsed.'
                    Assert-CergFixture ($outerBranch.blendChildOrdinal-eq0-and[decimal]$outerBranch.blendThreshold-eq[decimal]0.25-and[decimal]$outerBranch.childTimeScale-eq[decimal]1.25-and[decimal]$outerBranch.childCycleOffset-eq[decimal]0.125-and$outerBranch.childMirror-eq$true-and@($outerBranch.blendParameterValues).Count-eq1-and[decimal]$outerBranch.blendParameterValues[0].value-eq[decimal]0.25) 'OneD nondefault branch metadata was not preserved.'
                    Assert-CergFixture ($innerBranch.blendChildOrdinal-eq0-and[decimal]$innerBranch.blendThreshold-eq[decimal]-0.75-and[decimal]$innerBranch.childTimeScale-eq[decimal]1-and[decimal]$innerBranch.childCycleOffset-eq[decimal]0-and$innerBranch.childMirror-eq$false-and$innerBranch.serializedPropertyPath-ceq'm_Childs[0]/m_TimeScale:AbsentUsesUnityDefault/v1/m_CycleOffset:AbsentUsesUnityDefault/v1/m_Mirror:AbsentUsesUnityDefault/v1') 'OneD default provenance or negative threshold was not preserved.'
                }
                'T1A2-TEST18' {
                    $f=New-CergUnityGraphFixture $caseRoot;$path=Join-Path $f.OutputRoot 'Controller\Hero.controller';Replace-CergFixtureText $path '(?m)^  m_BlendType: 0\r?\n  m_BlendParameter: Speed$' "  m_BlendType: 1`n  m_BlendParameter: Horizontal`n  m_BlendParameterY: Vertical";Replace-CergFixtureText $path '(?m)^    m_Threshold: 0\.25$' '    m_Position: {x: -0.4, y: 0.8}'
                    $r=Invoke-CergGraphFixture $f;$tree=@($r.subjects|Where-Object{$_.subjectKind-ceq'BlendTree'-and$_.serializedFileId-eq5})[0];$branch=@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$tree.subjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'})[0];$parameters=@($r.subjects|Where-Object subjectKind -CEQ 'BlendParameter'|ForEach-Object parameterName|Sort-Object)
                    Assert-CergFixture ($tree.blendTreeType-ceq'SimpleDirectional2D'-and($parameters -join ',')-ceq'Direction,Horizontal,Vertical') '2D parameter identities were not parsed exactly.'
                    $valuesByName=@{};foreach($valueRow in @($branch.blendParameterValues)){$parameter=@($r.subjects|Where-Object subjectId -CEQ $valueRow.parameterSubjectId)[0];$valuesByName[$parameter.parameterName]=[decimal]$valueRow.value};Assert-CergFixture ($null-eq$branch.blendThreshold-and[decimal]$branch.blendPositionX-eq[decimal]-0.4-and[decimal]$branch.blendPositionY-eq[decimal]0.8-and$valuesByName.Horizontal-eq[decimal]-0.4-and$valuesByName.Vertical-eq[decimal]0.8) '2D position metadata was not preserved exactly.'
                }
                'T1A2-TEST19' {
                    $f=New-CergUnityGraphFixture $caseRoot;$path=Join-Path $f.OutputRoot 'Controller\Hero.controller';Replace-CergFixtureText $path '(?m)^  m_BlendType: 0\r?\n  m_BlendParameter: Speed$' '  m_BlendType: 4';Replace-CergFixtureText $path '(?m)^    m_Threshold: 0\.25$' '    m_DirectBlendParameter: DirectOuterA';Replace-CergFixtureText $path '(?m)^    m_Mirror: 1$' "    m_Mirror: 1`n  - m_Motion: {fileID: 74, guid: $('a'*32), type: 3}`n    m_DirectBlendParameter: DirectOuterB"
                    $r=Invoke-CergGraphFixture $f;$tree=@($r.subjects|Where-Object{$_.subjectKind-ceq'BlendTree'-and$_.serializedFileId-eq5})[0];$branches=@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$tree.subjectId-and$_.relationshipKind-ceq'BlendTreeContainsBranch'}|Sort-Object blendChildOrdinal);$byId=@{};foreach($s in $r.subjects){$byId[$s.subjectId]=$s}
                    Assert-CergFixture ($tree.blendTreeType-ceq'Direct'-and$branches.Count-eq2-and$branches[0].blendChildOrdinal-eq0-and$branches[1].blendChildOrdinal-eq1) 'Direct branch ordinals were not complete.'
                    Assert-CergFixture ($byId[$branches[0].directBlendParameterSubjectId].parameterName-ceq'DirectOuterA'-and$byId[$branches[1].directBlendParameterSubjectId].parameterName-ceq'DirectOuterB') 'Direct parameter identities were not preserved.'
                    foreach($index in 0..1){$ownId=$branches[$index].directBlendParameterSubjectId;foreach($valueRow in @($branches[$index].blendParameterValues)){Assert-CergFixture (([decimal]$valueRow.value)-eq[decimal]$(if($valueRow.parameterSubjectId-ceq$ownId){1}else{0})) "Direct one-hot value was incorrect at branch $index."}};Assert-CergFixture ($null-eq$branches[0].blendThreshold-and$null-eq$branches[0].blendPositionX-and@($branches[0].blendParameterValues).Count-eq2-and@($branches[1].blendParameterValues).Count-eq2) 'Direct one-hot field partition was incorrect.'
                }
                'T1A2-TEST20' {
                    $f=New-CergUnityGraphFixture (Join-Path $caseRoot 'Nested');Add-CergRecursiveAttackBlend $f;$r=Invoke-CergGraphFixture $f;$state=@($r.subjects|Where-Object{$_.subjectKind-ceq'AttackAction'-and$_.serializedFileId-eq4})[0];$outer=@($r.subjects|Where-Object{$_.subjectKind-ceq'BlendTree'-and$_.serializedFileId-eq30})[0];$inner=@($r.subjects|Where-Object{$_.subjectKind-ceq'BlendTree'-and$_.serializedFileId-eq31})[0]
                    Assert-CergFixture ($r.status-ceq'Closed'-and@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$state.subjectId-and$_.relationshipKind-ceq'StateUsesMotion'-and$_.targetSubjectId-ceq$outer.subjectId}).Count-eq1-and@($r.relationships|Where-Object{$_.relationshipKind-ceq'BlendBranchUsesMotion'-and$_.targetSubjectId-ceq$inner.subjectId}).Count-eq1) 'Recursive attack BlendTree path did not preserve both tree levels.'
                    Assert-CergFixture (@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$state.subjectId-and$_.relationshipKind-ceq'ActionHasAnimationEvent'-and[decimal]$_.eventTime-eq[decimal]0.5-and$_.eventFunctionName-ceq'SpawnAttackFx'}).Count-eq1-and@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$state.subjectId-and$_.relationshipKind-ceq'AttackTriggersFX'}).Count-eq1) 'Recursive attack leaf did not close to its event and FX.'
                    $cycle=New-CergUnityGraphFixture (Join-Path $caseRoot 'Cycle');Add-CergRecursiveAttackBlend $cycle;Replace-CergFixtureText (Join-Path $cycle.OutputRoot 'Controller\Hero.controller') '(?m)^  - m_Motion: \{fileID: 75, guid: [0-9a-f]{32}, type: 3\}$' '  - m_Motion: {fileID: 30}';$cycleResult=Invoke-CergGraphFixture $cycle;Assert-CergResultUnresolved $cycleResult 'Cyclic attack BlendTree'
                }
                'T1A2-TEST21' {
                    $f=New-CergUnityGraphFixture $caseRoot;$textureGuid='7'*32;$shaderGuid='6'*32;$texturePath=Join-Path $f.OutputRoot 'Textures\Attack.png';$shaderPath=Join-Path $f.OutputRoot 'Shaders\Attack.shader';Write-CergFixtureBytes $texturePath ([byte[]](137,80,78,71,13,10,26,10));Write-CergFixtureBytes ($texturePath+'.meta') $script:CergUtf8NoBom.GetBytes("fileFormatVersion: 2`nguid: $textureGuid`nTextureImporter:`n  mipmaps: {}`n");Write-CergFixtureBytes $shaderPath $script:CergUtf8NoBom.GetBytes('Shader "Stella/Attack" {}');Write-CergFixtureBytes ($shaderPath+'.meta') $script:CergUtf8NoBom.GetBytes("fileFormatVersion: 2`nguid: $shaderGuid`nShaderImporter: {}`n");$materialPath=Join-Path $f.OutputRoot 'Materials\Attack.mat';Replace-CergFixtureText $materialPath '(?m)^  m_Shader:.*$' "  m_Shader: {fileID: 4800000, guid: $shaderGuid, type: 3}";Replace-CergFixtureText $materialPath '(?m)^  m_Texture:.*$' "  m_Texture: {fileID: 2800000, guid: $textureGuid, type: 3}"
                    $r=Invoke-CergGraphFixture $f;$texture=@($r.subjects|Where-Object{$_.subjectKind-ceq'Texture'-and$_.unityGuid-ceq$textureGuid})[0];$shader=@($r.subjects|Where-Object{$_.subjectKind-ceq'Shader'-and$_.unityGuid-ceq$shaderGuid})[0];$material=@($r.subjects|Where-Object{$_.subjectKind-ceq'Material'-and$_.portableRelativePath-ceq'Materials/Attack.mat'})[0]
                    Assert-CergFixture ($r.status-ceq'Closed'-and$texture.portableRelativePath-ceq'Textures/Attack.png'-and$texture.serializedFileId-eq0-and$texture.authorityIdentity-cmatch'TextureImporter'-and$texture.contentSha256-ceq(Get-CergSha256Hex $texturePath)) 'External PNG identity was not bound exactly.'
                    Assert-CergFixture ($shader.portableRelativePath-ceq'Shaders/Attack.shader'-and$shader.serializedFileId-eq0-and$shader.authorityIdentity-cmatch'ShaderImporter'-and@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$material.subjectId-and$_.relationshipKind-ceq'MaterialUsesTexture'-and$_.targetSubjectId-ceq$texture.subjectId}).Count-eq1-and@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$material.subjectId-and$_.relationshipKind-ceq'MaterialUsesShader'-and$_.targetSubjectId-ceq$shader.subjectId}).Count-eq1) 'External Material texture/shader GUID closure was not exact.'
                    $missing=New-CergUnityGraphFixture (Join-Path $caseRoot 'MissingMeta');$leaf=Join-Path $missing.OutputRoot 'Textures\Missing.png';Write-CergFixtureBytes $leaf ([byte[]](1,2,3));$badGuid='5'*32;Replace-CergFixtureText (Join-Path $missing.OutputRoot 'Materials\Attack.mat') '(?m)^  m_Texture:.*$' "  m_Texture: {fileID: 2800000, guid: $badGuid, type: 3}";$missingResult=Invoke-CergGraphFixture $missing;Assert-CergResultUnresolved $missingResult 'External texture without meta'
                    $duplicate=New-CergUnityGraphFixture (Join-Path $caseRoot 'DuplicateGuid');$first=Join-Path $duplicate.OutputRoot 'Textures\First.png';$second=Join-Path $duplicate.OutputRoot 'Textures\Second.png';$duplicateGuid='3'*32;foreach($leafPath in @($first,$second)){Write-CergFixtureBytes $leafPath ([byte[]](1,2,3));Write-CergFixtureBytes ($leafPath+'.meta') $script:CergUtf8NoBom.GetBytes("fileFormatVersion: 2`nguid: $duplicateGuid`nTextureImporter: {}`n")};$duplicateResult=Invoke-CergGraphFixture $duplicate;Assert-CergResultUnresolved $duplicateResult 'Duplicate external GUID ownership'
                    $wrongImporter=New-CergUnityGraphFixture (Join-Path $caseRoot 'WrongImporter');$leaf=Join-Path $wrongImporter.OutputRoot 'Textures\Wrong.png';$wrongGuid='2'*32;Write-CergFixtureBytes $leaf ([byte[]](1,2,3));Write-CergFixtureBytes ($leaf+'.meta') $script:CergUtf8NoBom.GetBytes("fileFormatVersion: 2`nguid: $wrongGuid`nDefaultImporter: {}`n");$wrongResult=Invoke-CergGraphFixture $wrongImporter;Assert-CergResultUnresolved $wrongResult 'External texture with mismatched importer'
                    $unsupported=New-CergUnityGraphFixture (Join-Path $caseRoot 'UnsupportedLeaf');$leaf=Join-Path $unsupported.OutputRoot 'Textures\Unsupported.bin';$unsupportedGuid='1'*32;Write-CergFixtureBytes $leaf ([byte[]](1,2,3));Write-CergFixtureBytes ($leaf+'.meta') $script:CergUtf8NoBom.GetBytes("fileFormatVersion: 2`nguid: $unsupportedGuid`nDefaultImporter: {}`n");Replace-CergFixtureText (Join-Path $unsupported.OutputRoot 'Materials\Attack.mat') '(?m)^  m_Texture:.*$' "  m_Texture: {fileID: 2800000, guid: $unsupportedGuid, type: 3}";$unsupportedResult=Invoke-CergGraphFixture $unsupported;Assert-CergResultUnresolved $unsupportedResult 'Unsupported referenced external leaf'
                }
                'T1A2-TEST22' {
                    $f=New-CergUnityGraphFixture $caseRoot;$modelGuid='4'*32;$modelText="--- !u!1 &200`nGameObject:`n  m_Name: CharacterModelRoot`n  m_Component: {fileID: 201}`n--- !u!4 &201`nTransform:`n  m_Name: CharacterModelTransform`n  m_GameObject: {fileID: 200}`n  m_Father: {fileID: 0}`n";Write-CergUnityYamlFixture (Join-Path $f.OutputRoot 'Models\Character.prefab') $modelGuid $modelText;$r=Invoke-CergGraphFixture $f;$modelObjects=@($r.subjects|Where-Object{$_.unityGuid-ceq$modelGuid});$fxObjects=@($r.subjects|Where-Object{$_.unityGuid-ceq('f'*32)})
                    Assert-CergFixture (@($modelObjects|Where-Object subjectKind -CEQ 'GameObject').Count-eq1-and@($modelObjects|Where-Object subjectKind -CEQ 'FXObject').Count-eq0-and@($r.subjects|Where-Object subjectKind -CEQ 'FXPrefab').Count-eq1-and@($fxObjects|Where-Object subjectKind -CEQ 'FXObject').Count-eq2) 'Model and attack-FX prefab partitions were polluted.'
                    Assert-CergFixture (@($r.relationships|Where-Object{$_.relationshipKind-cmatch'^FX'-and($modelObjects.subjectId -contains $_.sourceSubjectId-or$modelObjects.subjectId -contains $_.targetSubjectId)}).Count-eq0) 'Non-FX prefab entered an FX relationship.'
                    $controllerMember=@($r.outputMembers|Where-Object portableRelativePath -CEQ 'Controller/Hero.controller')[0];$expected=@('LO1-OB01','LO1-OB02','LO1-OB04','LO1-OB05','LO1-OB06','LO1-OB11');Assert-CergFixture ((ConvertTo-CergCanonicalJsonValue @($controllerMember.obligationRefIds))-ceq(ConvertTo-CergCanonicalJsonValue $expected)) 'Legitimate multi-obligation controller union was not exact.'
                    foreach($mutation in @('Duplicate','Extra','Missing','Locatorless')){$members=@((ConvertTo-CergCanonicalJsonValue @($r.outputMembers))|ConvertFrom-Json);if($mutation-ceq'Locatorless'){$members+=([pscustomobject][ordered]@{portableRelativePath='Unowned/leaf.bin';byteCount=[int64]1;sha256=('0'*64);subjectRefIds=@();obligationRefIds=@()})}else{$member=@($members|Where-Object portableRelativePath -CEQ 'Controller/Hero.controller')[0];if($mutation-ceq'Duplicate'){$member.obligationRefIds=@($member.obligationRefIds)+@($member.obligationRefIds[0])}elseif($mutation-ceq'Extra'){$member.obligationRefIds=@($member.obligationRefIds)+@('LO1-OB09')}else{$member.obligationRefIds=@($member.obligationRefIds|Select-Object -Skip 1)}};$errors=[Collections.Generic.List[string]]::new();Test-CergGraphModel (Read-CergJsonFile $f.CandidatePath) (Read-CergJsonFile $f.PreflightPath) @($r.evidenceItems) @($r.authorityScopes) @($r.subjects) @($r.relationships) @($r.obligationResults) @($members) $errors;Assert-CergFixture (@($errors|Where-Object{$_-clike'OutputAttributionFailure:*'}).Count-ge1) "Attribution mutation $mutation was not rejected."}
                }
                'T1A2-TEST23' {
                    $f=New-CergUnityGraphFixture (Join-Path $caseRoot 'AnchorPositive');Add-CergRecursiveAttackBlend $f -RemoveAttackTag;$r=Invoke-CergGraphFixture $f;$attack=@($r.subjects|Where-Object{$_.subjectKind-ceq'AttackAction'-and$_.serializedFileId-eq4})[0]
                    Assert-CergFixture ($r.status-ceq'Closed'-and$null-ne$attack-and([IO.File]::ReadAllText((Join-Path $f.OutputRoot 'Controller\Hero.controller'))-cnotmatch'm_Tag: Attack')) 'Exact attack anchor did not classify an untagged state.'
                    Assert-CergFixture (@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$attack.subjectId-and$_.relationshipKind-ceq'ActionHasAnimationEvent'-and[decimal]$_.eventTime-eq[decimal]0.5-and$_.eventFunctionName-ceq'SpawnAttackFx'}).Count-eq1-and@($r.relationships|Where-Object{$_.sourceSubjectId-ceq$attack.subjectId-and$_.relationshipKind-ceq'AttackTriggersFX'}).Count-eq1) 'Anchored recursive attack did not close to exact event/FX.'
                    $missing=New-CergUnityGraphFixture (Join-Path $caseRoot 'MissingAnchor');$candidate=Read-CergJsonFile $missing.CandidatePath;$candidate.attackAnchors=@();Update-CergFixtureBindings $missing $candidate;$missingResult=Invoke-CergGraphFixture $missing;Assert-CergResultUnresolved $missingResult 'Missing attack anchor'
                    $stale=New-CergUnityGraphFixture (Join-Path $caseRoot 'StaleAnchor');$candidate=Read-CergJsonFile $stale.CandidatePath;$candidate.attackAnchors[0].sha256='0'*64;Update-CergFixtureBindings $stale $candidate;$staleResult=Invoke-CergGraphFixture $stale;Assert-CergResultUnresolved $staleResult 'Stale attack anchor'
                    $mismatch=New-CergUnityGraphFixture (Join-Path $caseRoot 'MismatchedAnchor');$candidate=Read-CergJsonFile $mismatch.CandidatePath;$candidate.attackAnchors[0].serializedFileId=[int64]74;Update-CergFixtureBindings $mismatch $candidate;$mismatchResult=Invoke-CergGraphFixture $mismatch;Assert-CergResultUnresolved $mismatchResult 'Mismatched attack anchor'
                    $heuristic=New-CergUnityGraphFixture (Join-Path $caseRoot 'HeuristicOnly');Remove-CergFixtureLine (Join-Path $heuristic.OutputRoot 'Controller\Hero.controller') '(?m)^  m_Tag: Attack\r?\n';$candidate=Read-CergJsonFile $heuristic.CandidatePath;$anchor=$candidate.attackAnchors[0];$clip=@($candidate.subjects|Where-Object subjectId -CEQ $anchor.clipSubjectRefId)[0];$oldId=$clip.subjectId;$clip.serializedFileId=[int64]74;$clip.sourceObjectId="$($clip.unityGuid):74";$clip.authorityIdentity="BaselineYamlObject:$($clip.unityGuid):74";$clip.subjectId=Get-CergSubjectId $clip;$anchor.clipSubjectRefId=$clip.subjectId;$anchor.serializedFileId=[int64]74;$bytes=$script:CergUtf8NoBom.GetBytes((ConvertTo-CergCanonicalJsonValue @('cerg-t1/attack-anchor/1',$anchor.candidateId,$anchor.portableRelativePath,[int64]$anchor.byteCount,$anchor.sha256,$anchor.unityGuid,[int64]74)));$anchor.attackAnchorId='ATK-'+([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant());foreach($relationship in $candidate.relationships){if($relationship.sourceSubjectId-ceq$oldId){$relationship.sourceSubjectId=$clip.subjectId};if($relationship.targetSubjectId-ceq$oldId){$relationship.targetSubjectId=$clip.subjectId};$relationship.relationshipId=Get-CergRelationshipId $relationship};Update-CergFixtureBindings $heuristic $candidate;$heuristicResult=Invoke-CergGraphFixture $heuristic;Assert-CergResultUnresolved $heuristicResult 'Name/path/event-only attack heuristic';$stateFour=@($heuristicResult.subjects|Where-Object serializedFileId -EQ 4);Assert-CergFixture (@($stateFour|Where-Object subjectKind -CEQ 'ActionState').Count-eq1-and@($stateFour|Where-Object subjectKind -CEQ 'AttackAction').Count-eq0) 'State/clip name, path, or FX event self-classified an attack.'
                }
                'T1A4-TEST24' {
                    $typeNames=[ordered]@{'0'='OneD';'1'='SimpleDirectional2D';'2'='FreeformDirectional2D';'3'='FreeformCartesian2D';'4'='Direct'}
                    foreach($typeCode in @('0','1','2','3','4')){
                        $f=New-CergUnityGraphFixture (Join-Path $caseRoot "Valid$typeCode");$path=Join-Path $f.OutputRoot 'Controller\Hero.controller'
                        if($typeCode-cin@('1','2','3')){
                            Replace-CergFixtureText $path '(?m)^  m_BlendType: 0$' "  m_BlendType: $typeCode"
                            Replace-CergFixtureText $path '(?m)^  m_BlendParameter: Speed$' "  m_BlendParameter: SpeedX`n  m_BlendParameterY: SpeedY"
                            Replace-CergFixtureText $path '(?m)^  m_BlendParameter: Direction$' "  m_BlendParameter: DirectionX`n  m_BlendParameterY: DirectionY"
                            Replace-CergFixtureText $path '(?m)^    m_Threshold: 0\.25$' '    m_Position: {x: -0.25, y: 0.75}'
                            Replace-CergFixtureText $path '(?m)^    m_Threshold: -0\.75$' '    m_Position: {x: 0.5, y: -0.5}'
                        } elseif($typeCode-ceq'4') {
                            Replace-CergFixtureText $path '(?m)^  m_BlendType: 0$' '  m_BlendType: 4'
                            Remove-CergFixtureLine $path '(?m)^  m_BlendParameter: (?:Speed|Direction)\r?\n'
                            Replace-CergFixtureText $path '(?m)^    m_Threshold: 0\.25$' '    m_DirectBlendParameter: DirectOuter'
                            Replace-CergFixtureText $path '(?m)^    m_Threshold: -0\.75$' '    m_DirectBlendParameter: DirectInner'
                        }
                        $r=Invoke-CergGraphFixture $f;$trees=@($r.subjects|Where-Object subjectKind -CEQ 'BlendTree'|Sort-Object serializedFileId);$branches=@($r.relationships|Where-Object relationshipKind -CEQ 'BlendTreeContainsBranch'|Sort-Object relationshipId)
                        Assert-CergFixture ($r.status-ceq'Closed'-and$r.consumableForT2-and$r.closure.requiredMissingReferenceCount-eq0-and$trees.Count-eq2-and$trees[0].serializedFileId-eq5-and$trees[1].serializedFileId-eq6-and$trees[0].blendTreeType-ceq$typeNames[$typeCode]-and$trees[1].blendTreeType-ceq$typeNames[$typeCode]-and$branches.Count-eq2) "Valid m_BlendType $typeCode did not map exactly."
                        if($typeCode-cin@('1','2','3')){
                            $outer=@($branches|Where-Object sourceSubjectId -CEQ $trees[0].subjectId)[0];$inner=@($branches|Where-Object sourceSubjectId -CEQ $trees[1].subjectId)[0]
                            Assert-CergFixture ($null-eq$outer.blendThreshold-and[decimal]$outer.blendPositionX-eq[decimal]-0.25-and[decimal]$outer.blendPositionY-eq[decimal]0.75-and$null-eq$inner.blendThreshold-and[decimal]$inner.blendPositionX-eq[decimal]0.5-and[decimal]$inner.blendPositionY-eq[decimal]-0.5) "2D m_BlendType $typeCode lost exact branch positions."
                        } elseif($typeCode-ceq'4') {
                            $byId=@{};foreach($subject in $r.subjects){$byId[$subject.subjectId]=$subject};$directNames=@($branches|ForEach-Object{$byId[$_.directBlendParameterSubjectId].parameterName}|Sort-Object)
                            Assert-CergFixture (($directNames -join ',')-ceq'DirectInner,DirectOuter'-and@($branches|Where-Object{$null-ne$_.blendThreshold-or$null-ne$_.blendPositionX-or$null-ne$_.blendPositionY}).Count-eq0) 'Direct m_BlendType did not preserve the exact field partition.'
                        }
                    }
                    $invalidVariants=@(
                        @('Missing','(?m)^  m_Name: LocomotionBlend\r?\n  m_BlendType: 0$','  m_Name: LocomotionBlend'),
                        @('Duplicate','(?m)^  m_Name: LocomotionBlend\r?\n  m_BlendType: 0$',"  m_Name: LocomotionBlend`n  m_BlendType: 0`n  m_BlendType: 1"),
                        @('Decimal','(?m)^  m_Name: LocomotionBlend\r?\n  m_BlendType: 0$',"  m_Name: LocomotionBlend`n  m_BlendType: 1.0"),
                        @('Unknown','(?m)^  m_Name: LocomotionBlend\r?\n  m_BlendType: 0$',"  m_Name: LocomotionBlend`n  m_BlendType: 5")
                    )
                    foreach($variant in $invalidVariants){
                        $f=New-CergUnityGraphFixture (Join-Path $caseRoot $variant[0]);Replace-CergFixtureText (Join-Path $f.OutputRoot 'Controller\Hero.controller') $variant[1] $variant[2];$r=Invoke-CergGraphFixture $f
                        Assert-CergResultUnresolved $r ("Invalid m_BlendType "+$variant[0]);Assert-CergFixture (@($r.subjects|Where-Object subjectKind -CEQ 'BlendTree').Count-eq0-and@($r.relationships|Where-Object relationshipKind -CEQ 'BlendTreeContainsBranch').Count-eq0-and[IO.File]::Exists($f.Result)-and-not[IO.File]::Exists($f.ResultTemp)) ("Invalid m_BlendType "+$variant[0]+" emitted a typed or non-atomic result.")
                    }
                }
                'T1A4-TEST25' {
                    $privateFields=@('attemptPrivateAbsoluteRoot','stagingInputPrivateAbsolutePath','stagingInventoryTemporaryPrivateAbsolutePath','stagingInventoryPrivateAbsolutePath','workPrivateAbsolutePath','outputPrivateAbsolutePath')
                    $stageFixture=New-CergStagingFixture (Join-Path $caseRoot 'StagingReject');$stageFull=Read-CergJsonFile $stageFixture.PreflightPath
                    $graphFixture=New-CergUnityGraphFixture (Join-Path $caseRoot 'GraphReject');$graphFull=Read-CergJsonFile $graphFixture.PreflightPath
                    foreach($field in $privateFields){
                        $stageMutation=(ConvertTo-CergCanonicalJsonValue $stageFull)|ConvertFrom-Json -Depth 100 -DateKind String;$stageMutation.stagingPlan.PSObject.Properties.Remove($field);Write-CergFixtureJson $stageFixture.PreflightPath $stageMutation -Canonical
                        $stageMessage='';try{Invoke-CergLo1ExactStaging $stageFixture.CandidatePath $stageFixture.PreflightPath $stageFixture.InventoryTemp $stageFixture.Inventory|Out-Null}catch{$stageMessage=$_.Exception.Message}
                        Assert-CergFixture ($stageMessage-clike'PreflightConsumerContractFailure:*'-and-not[IO.Directory]::Exists($stageFixture.StagingRoot)-and-not[IO.File]::Exists($stageFixture.Inventory)) "TG01 chain accepted missing $field."

                        $graphMutation=(ConvertTo-CergCanonicalJsonValue $graphFull)|ConvertFrom-Json -Depth 100 -DateKind String;$graphMutation.stagingPlan.PSObject.Properties.Remove($field);Write-CergFixtureJson $graphFixture.PreflightPath $graphMutation -Canonical;$preflightSha=Get-CergSha256Hex $graphFixture.PreflightPath
                        $attempt=Read-CergJsonFile $graphFixture.AttemptPath;$attempt.preflightSha256=$preflightSha;Write-CergFixtureJson $graphFixture.AttemptPath $attempt -Canonical
                        $staging=Read-CergJsonFile $graphFixture.StagingPath;$staging.preflightSha256=$preflightSha;Write-CergFixtureJson $graphFixture.StagingPath $staging -Canonical
                        $graphMessage='';try{Invoke-CergGraphFixture $graphFixture|Out-Null}catch{$graphMessage=$_.Exception.Message}
                        Assert-CergFixture ($graphMessage-clike'PreflightConsumerContractFailure:*'-and-not[IO.File]::Exists($graphFixture.Result)-and-not[IO.File]::Exists($graphFixture.ResultTemp)) "ResultGraph accepted missing $field."
                    }
                }
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

$result=[pscustomobject][ordered]@{schemaVersion='cerg-t1a-fixture-result/1.3.0';testRows=@($rows);partitions=[pscustomobject][ordered]@{passedCount=@($rows|Where-Object status -CEQ 'Passed').Count;failedCount=@($rows|Where-Object status -CEQ 'Failed').Count;totalCount=$rows.Count}}
$result | ConvertTo-Json -Depth 10
if($result.partitions.failedCount -ne 0){exit 1}
