[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Test-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')
. (Join-Path $PSScriptRoot 'New-CergLo1ResultGraph.ps1')

$ids=@('R2-CE01-Missing','R2-CE02-Directory','R2-CE03-Reparse','R2-CE04-ByteDrift','R2-CE05-EqualSizeHashDrift','R2-CE06-SelectorConservation','R2-CE07-IndependentDisagreement','R2-CE08-StaleRun','R2-CE09-HiddenField','R2-CE10-ProducerSplice','R2-CE11-AncestorReparse','R2-SP01-ProductionConstructor','R2-SP02-IndependentValidator','R2-SP03-StagingConsumer','R2-AT01-SelectorMutation','R2-AT02-TupleMutation','R2-AT03-EvidenceMutation','R2-AT04-TimeMutation','R2-AT05-ImplementationMutation')
$results=[Collections.Generic.List[object]]::new()
function Add-R2Result {param([string]$Id,[scriptblock]$Body);try{&$Body;$results.Add([pscustomobject][ordered]@{testId=$Id;status='Passed';evidenceLocator="SyntheticFixture/$Id/Assertions"})}catch{throw ($Id+' failed: '+$_.Exception.Message+' STACK '+$_.ScriptStackTrace)}}
function Test-R2Throws {param([scriptblock]$Body);$threw=$false;try{&$Body|Out-Null}catch{$threw=$true};if(-not $threw){throw 'Expected failed-closed exception.'}}
function Copy-R2Object {param([object]$Value);return(($Value|ConvertTo-Json -Depth 100 -Compress)|ConvertFrom-Json -DateKind String)}
function Get-R2OrdinalPlanRows {param([object[]]$Members);$rows=[object[]]@($Members|ForEach-Object{[pscustomobject][ordered]@{sourceMemberRefId=$_.memberId;sourceId=$_.sourceId;sourcePortableRelativePath=$_.portableRelativePath;stagingPortableRelativePath=('Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input/'+$_.sourceId+'/'+$_.portableRelativePath);byteCount=[int64]$_.byteCount;sha256=$_.sha256}});[Array]::Sort($rows,[Collections.Generic.Comparer[object]]::Create([Comparison[object]]{param($a,$b)[string]::CompareOrdinal([string]$a.stagingPortableRelativePath,[string]$b.stagingPortableRelativePath)}));return $rows}
function New-R2PipelineImplementationBindings([string]$FixtureRoot){
    $repoRoot=[IO.Directory]::GetParent([IO.Directory]::GetParent($PSScriptRoot).FullName).FullName;$runtime=(Get-Process -Id $PID).Path;$privateTool=Join-Path $FixtureRoot 'PrivateTool\AssetRipper.GUI.Free.exe';[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($privateTool))|Out-Null;[IO.File]::WriteAllBytes($privateTool,[Text.Encoding]::UTF8.GetBytes('synthetic-private-assetripper-1.3.14.0'))
    $specs=@([pscustomobject]@{artifactId='LO1-IA01';role='AssetRipperExecutable';version='1.3.14.0';kind='Private';portable=$null;path=$privateTool;runtime=$privateTool},[pscustomobject]@{artifactId='LO1-IF01';role='AssetRipperFolderInvoker';version='CERG-LO1-ASSETRIPPER-FOLDER-INVOKER/1';kind='Tracked';portable='Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1';path=(Join-Path $repoRoot 'Tools\AssetImport\Invoke-AssetRipperFolderExport.ps1');runtime=$runtime},[pscustomobject]@{artifactId='T1V22-TG01';role='ExactLeafStagingWrapper';version='CERG-LO1-EXACT-STAGING/3';kind='Tracked';portable='Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1';path=(Join-Path $repoRoot 'Tools\AssetImport\Invoke-CergLo1ExactStaging.ps1');runtime=$runtime},[pscustomobject]@{artifactId='T1V22-TG02';role='R01GraphProducer';version='CERG-LO1-R01-PRODUCER/5';kind='Tracked';portable='Tools/AssetImport/New-CergLo1ResultGraph.ps1';path=(Join-Path $repoRoot 'Tools\AssetImport\New-CergLo1ResultGraph.ps1');runtime=$runtime})
    $rows=[object[]]@($specs|ForEach-Object{$ii=Get-Item -LiteralPath $_.path;$ri=Get-Item -LiteralPath $_.runtime;$is=Get-CergSha256Hex $ii.FullName;$rs=Get-CergSha256Hex $ri.FullName;$id='IMP-'+(Get-CergStructuredSha256 'cerg-lo1/implementation-id/1' @($_.role,$_.version,[int64]$ii.Length,$is,[int64]$ri.Length,$rs,@()));[pscustomobject][ordered]@{artifactId=$_.artifactId;implementationId=$id;implementationRole=$_.role;implementationVersion=$_.version;pathKind=$_.kind;portableTrackedPath=$_.portable;privateAbsoluteLeafPath=$(if($_.kind-ceq'Private'){$ii.FullName}else{$null});implementationByteCount=[int64]$ii.Length;implementationSha256=$is;runtimePrivateAbsoluteLeafPath=$ri.FullName;runtimeByteCount=[int64]$ri.Length;runtimeSha256=$rs;orderedArgumentTokens=@()}});[Array]::Sort($rows,[Collections.Generic.Comparer[object]]::Create([Comparison[object]]{param($a,$b)[string]::CompareOrdinal([string]$a.implementationId,[string]$b.implementationId)}));[pscustomobject]@{Rows=$rows;RefIds=[string[]]@($rows|ForEach-Object implementationId);RepoRoot=$repoRoot}
}

$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/')
$fixtureRoot=Join-Path $tempBase ('cerg-r2-fixture-'+[guid]::NewGuid().ToString('N'))
$root=Join-Path $fixtureRoot 'Source'
[IO.Directory]::CreateDirectory($root)|Out-Null
try{
    $members=[Collections.Generic.List[object]]::new()
    for($i=0;$i-lt17;$i++){
        $rel=('leaf/{0:D2}.bin'-f$i);$leaf=Join-Path $root $rel.Replace('/','\');[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($leaf))|Out-Null
        [IO.File]::WriteAllBytes($leaf,[Text.Encoding]::UTF8.GetBytes(('fixture-{0:D2}-payload'-f$i)))
        $members.Add([pscustomobject][ordered]@{memberId=('OLD-{0:D2}'-f$i);sourceId='synthetic';portableRelativePath=$rel;sizeBytes=[int64]([IO.FileInfo]::new($leaf).Length);sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $leaf).Hash.ToLowerInvariant()})
    }
    $head='0123456789012345678901234567890123456789'
    $candidate=[pscustomobject][ordered]@{schemaVersion='cerg-t1-candidate-lock/2.2.0';artifactId='CERG-T1V22-O01';contractHeadCommit=$head;status='Passed';selectedCandidateId='char_14401';attackAnchors=@();sourceMembers=@($members);discoveryObligations=@()}
    $bindings=@([pscustomobject][ordered]@{sourceId='synthetic';privateAbsoluteReadOnlyRoot=$root})
    $candidatePath=Join-Path $fixtureRoot 'candidate.json'
    [IO.File]::WriteAllText($candidatePath,($candidate|ConvertTo-Json -Depth 100 -Compress),[Text.UTF8Encoding]::new($false))
    $lockSha=Get-CergR2ValidatorFileHash $candidatePath
    function New-Packet {param([object]$C=$candidate,[string]$Started=[DateTimeOffset]::UtcNow.ToString('O'),[string]$Path=$candidatePath,[string]$CandidateSha=$lockSha);Invoke-CergLo1R2FreshnessProducer -Candidate $C -CandidateLockPath $Path -SourceRootBindings $bindings -ContractHeadCommit $head -CandidateLockSha256 $CandidateSha -StartedAtUtc $Started}
    $validPacket=New-Packet
    $validatorImpl=Get-CergR2ValidatorImplementation
    function New-TestRows {param([string[]]$Names);return @($Names|ForEach-Object{[pscustomobject][ordered]@{testId=$_;status='Passed';evidenceRefIds=@($validPacket.producerImplementation.implementationId,$validatorImpl.implementationId)}})}
    $fixedRows=New-TestRows $ids[0..10];$successRows=New-TestRows $ids[11..13];$attackRows=New-TestRows $ids[14..18]

    Add-R2Result $ids[0] {
        $p=Join-Path $root 'leaf\00.bin';$bytes=[IO.File]::ReadAllBytes($p);[IO.File]::Delete($p);try{if((New-Packet).status-cne'FailedClosed'){throw'Missing leaf was accepted.'}}finally{[IO.File]::WriteAllBytes($p,$bytes)}
    }
    Add-R2Result $ids[1] {
        $p=Join-Path $root 'leaf\01.bin';$bytes=[IO.File]::ReadAllBytes($p);[IO.File]::Delete($p);[IO.Directory]::CreateDirectory($p)|Out-Null;try{if((New-Packet).status-cne'FailedClosed'){throw'Directory was accepted.'}}finally{[IO.Directory]::Delete($p);[IO.File]::WriteAllBytes($p,$bytes)}
    }
    Add-R2Result $ids[2] {
        $p=Join-Path $root 'leaf\02.bin';$target=Join-Path $root 'leaf\02-target';$bytes=[IO.File]::ReadAllBytes($p);[IO.File]::Delete($p);[IO.Directory]::CreateDirectory($target)|Out-Null
        try{New-Item -ItemType Junction -Path $p -Target $target|Out-Null;if((New-Packet).status-cne'FailedClosed'){throw'Reparse leaf was accepted.'}}
        finally{if([IO.Directory]::Exists($p)){(Get-Item -LiteralPath $p -Force).Delete()};if([IO.Directory]::Exists($target)){[IO.Directory]::Delete($target)};[IO.File]::WriteAllBytes($p,$bytes)}
    }
    Add-R2Result $ids[3] {
        $packet=New-Packet;$p=Join-Path $root 'leaf\03.bin';$old=[IO.File]::ReadAllBytes($p);try{[IO.File]::WriteAllBytes($p,$old+[byte]1);$a=Invoke-CergLo1R2FreshnessValidator $packet $bindings $fixedRows $successRows $attackRows;if($a.status-cne'FailedClosed'){throw'Byte drift was accepted.'}}finally{[IO.File]::WriteAllBytes($p,$old)}
    }
    Add-R2Result $ids[4] {
        $packet=New-Packet;$p=Join-Path $root 'leaf\04.bin';$old=[IO.File]::ReadAllBytes($p);$changed=[byte[]]$old.Clone();$changed[0]=$changed[0]-bxor1;try{[IO.File]::WriteAllBytes($p,$changed);$a=Invoke-CergLo1R2FreshnessValidator $packet $bindings $fixedRows $successRows $attackRows;if($a.status-cne'FailedClosed'){throw'Equal-size hash drift was accepted.'}}finally{[IO.File]::WriteAllBytes($p,$old)}
    }
    Add-R2Result $ids[5] {
        $bad=Copy-R2Object $candidate;$bad.sourceMembers[16].sourceId=$bad.sourceMembers[0].sourceId;$bad.sourceMembers[16].portableRelativePath=$bad.sourceMembers[0].portableRelativePath;Test-R2Throws {New-Packet $bad}
    }
    Add-R2Result $ids[6] {
        $packet=Copy-R2Object (New-Packet);$packet.producerRows[0].observedSha256=('0'*64);$a=Invoke-CergLo1R2FreshnessValidator $packet $bindings $fixedRows $successRows $attackRows;if($a.status-cne'FailedClosed'){throw'Producer/validator disagreement accepted.'}
    }
    $validArtifact=Invoke-CergLo1R2FreshnessValidator (New-Packet) $bindings $fixedRows $successRows $attackRows
    $freshPath=Join-Path $fixtureRoot 'freshness.json';$preflightPath=Join-Path $fixtureRoot 'preflight-ordinal.json';$attemptRoot=Join-Path $fixtureRoot 'R2Attempt'
    [IO.File]::WriteAllText($freshPath,($validArtifact|ConvertTo-Json -Depth 100 -Compress),[Text.UTF8Encoding]::new($false))
    $freshSha=(Get-FileHash -Algorithm SHA256 -LiteralPath $freshPath).Hash.ToLowerInvariant()
    $planRows=@(Get-R2OrdinalPlanRows $validArtifact.currentMembers)
    $totalBytes=[int64](($planRows|Measure-Object byteCount -Sum).Sum);$memberIds=[string[]]@($planRows|ForEach-Object sourceMemberRefId);[Array]::Sort($memberIds,[StringComparer]::Ordinal)
    $implementations=New-R2PipelineImplementationBindings $fixtureRoot
    $definition=[pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight-definition/1.2.0';artifactId='LO-CERG1-P02-DEFINITION';candidateLockSha256=$lockSha
        freshnessEvidenceSha256=$freshSha;freshnessCheckRunId=$validArtifact.checkRunId;freshnessValidatorFinishedAtUtc=$validArtifact.validatorFinishedAtUtc
        candidateContractHeadCommit=$candidate.contractHeadCommit;freshnessContractHeadCommit=$validArtifact.contractHeadCommit;contractHeadCommit=$head;selectedCandidateId='char_14401';createdAt=[DateTimeOffset]::UtcNow.ToString('O')
        sourceRootBindings=@([pscustomobject][ordered]@{sourceId='synthetic';privateAbsoluteReadOnlyRoot=$root;rootFingerprint=('f'*64)});implementationBindings=@($implementations.Rows)
        operation=[pscustomobject][ordered]@{operationId='R2-OP01';obligationRefIds=@('R2-OB01');implementationRefIds=@($implementations.RefIds);inputMemberRefIds=$memberIds;expectedSubjectKinds=@();expectedRelationshipKinds=@();sourceReadMaxFiles=17;sourceReadMaxBytes=$totalBytes;maxDurationSeconds=60;maxResultRows=1;maxOutputFiles=100;maxOutputBytes=$totalBytes;stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Output';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Work'}
        aggregateLimits=[pscustomobject][ordered]@{sourceReadMaxFiles=17;sourceReadMaxBytes=$totalBytes;maxDurationSeconds=60;maxResultRows=1;maxOutputFiles=100;maxOutputBytes=$totalBytes}
        stagingPlan=[pscustomobject][ordered]@{stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input';stagingInventoryTemporaryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/staging-inventory.json.tmp';stagingInventoryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/staging-inventory.json';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Work';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Output';memberRows=$planRows;memberCount=17;byteCount=$totalBytes;memberSetFingerprint=(Get-CergPreflightStructuredSha256 'cerg-lo1/staging-member-set/1' @($planRows))}
        status='Green';nextAction='RequestExactHumanConfirmationForR2P02'
    }
    $readyRows=@($implementations.Rows|Where-Object pathKind -CEQ 'Tracked'|ForEach-Object{[pscustomobject][ordered]@{portableRelativePath=$_.portableTrackedPath;byteCount=[int64]$_.implementationByteCount;sha256=$_.implementationSha256}})
    $readiness=[pscustomobject][ordered]@{schemaVersion='cerg-r2-aplus-readiness/1.3.0';artifactId='R2-TO06';contractHeadCommit=$head;toolRows=$readyRows;status='Green'}
    $r2Preflight=New-CergLo1R2OrdinalPreflightObject -Definition $definition -Candidate $candidate -Freshness $validArtifact -Readiness $readiness -FreshnessEvidencePath $freshPath -AttemptPrivateAbsoluteRoot $attemptRoot
    [IO.File]::WriteAllText($preflightPath,(ConvertTo-CergPreflightCanonicalJson $r2Preflight),[Text.UTF8Encoding]::new($false))
    Add-R2Result $ids[7] {$x=Copy-R2Object $validArtifact;$x.validatorFinishedAtUtc=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[8] {$x=Copy-R2Object $validArtifact;$x|Add-Member -NotePropertyName fixtureHidden -NotePropertyValue $true;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[9] {$x=Copy-R2Object (New-Packet);$x.sourceSelectors[0].selectorId='R2S-spliced';$a=Invoke-CergLo1R2FreshnessValidator $x $bindings $fixedRows $successRows $attackRows;if($a.status-cne'FailedClosed'){throw'Producer splice accepted.'}}
    Add-R2Result $ids[10] {
        $chain=Join-Path $root 'chain';$outside=Join-Path $fixtureRoot 'outside-chain';[IO.Directory]::CreateDirectory($chain)|Out-Null
        $chainLeaf=Join-Path $chain '05.bin';[IO.File]::WriteAllBytes($chainLeaf,[IO.File]::ReadAllBytes((Join-Path $root 'leaf\05.bin')))
        $chainCandidate=Copy-R2Object $candidate;$chainCandidate.sourceMembers[5].portableRelativePath='chain/05.bin';$chainCandidate.sourceMembers[5].sizeBytes=[int64]([IO.FileInfo]::new($chainLeaf).Length);$chainCandidate.sourceMembers[5].sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $chainLeaf).Hash.ToLowerInvariant()
        $chainCandidatePath=Join-Path $fixtureRoot 'ancestor-candidate.json';[IO.File]::WriteAllText($chainCandidatePath,($chainCandidate|ConvertTo-Json -Depth 100 -Compress),[Text.UTF8Encoding]::new($false));$chainSha=Get-CergR2ValidatorFileHash $chainCandidatePath
        $greenPacket=New-Packet -C $chainCandidate -Path $chainCandidatePath -CandidateSha $chainSha;$greenArtifact=Invoke-CergLo1R2FreshnessValidator $greenPacket $bindings $fixedRows $successRows $attackRows
        [IO.Directory]::CreateDirectory($outside)|Out-Null;[IO.File]::WriteAllBytes((Join-Path $outside '05.bin'),[IO.File]::ReadAllBytes($chainLeaf));[IO.File]::Delete($chainLeaf);[IO.Directory]::Delete($chain);New-Item -ItemType Junction -Path $chain -Target $outside|Out-Null
        try{
            if((New-Packet -C $chainCandidate -Path $chainCandidatePath -CandidateSha $chainSha).status-cne'FailedClosed'){throw'Producer accepted an ancestor junction.'}
            $validatorPacket=New-Packet -C $chainCandidate -Path $chainCandidatePath -CandidateSha $chainSha;$validatorArtifact=Invoke-CergLo1R2FreshnessValidator $validatorPacket $bindings $fixedRows $successRows $attackRows;if($validatorArtifact.status-cne'FailedClosed'){throw'Independent validator accepted an ancestor junction.'}
            Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $greenArtifact $bindings}
        }finally{if([IO.Directory]::Exists($chain)){(Get-Item -LiteralPath $chain -Force).Delete()};if([IO.Directory]::Exists($outside)){Remove-Item -LiteralPath $outside -Recurse -Force}}
    }
    Add-R2Result $ids[11] {if((New-Packet).status-cne'ProducerGreen'){throw'Production constructor not Green.'}}
    Add-R2Result $ids[12] {if($validArtifact.status-cne'Green'-or@($validArtifact.currentMembers).Count-ne17){throw'Independent validator not Green.'}}
    Add-R2Result $ids[13] {
        $inventoryTemp=$r2Preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath;$inventory=$r2Preflight.stagingPlan.stagingInventoryPrivateAbsolutePath
        [IO.Directory]::CreateDirectory($attemptRoot)|Out-Null
        $a01Path=Join-Path $attemptRoot 'attempt-state.json';[IO.File]::WriteAllText($a01Path,'{}',[Text.UTF8Encoding]::new($false));$a01Sha=Get-CergSha256Hex $a01Path;$h01Temp=Join-Path $attemptRoot 'first-source-open.json.tmp';$h01=Join-Path $attemptRoot 'first-source-open.json'
        $token=New-CergR2AtomicHandoffToken -RunnerInstanceId 'R2INST-fixture' -RunnerImplementationId 'R2RUNNER-fixture' -AdjacencyValidatorFinishedAtUtc ([DateTimeOffset]::UtcNow.ToString('O')) -A01Path $a01Path -A01Sha256 $a01Sha -H01TemporaryPath $h01Temp -H01Path $h01
        $result=Invoke-CergLo1ExactStaging -CandidateLockPath $candidatePath -PreflightPath $preflightPath -FreshnessEvidencePath $freshPath -StagingInventoryTemporaryPath $inventoryTemp -StagingInventoryPath $inventory -AtomicHandoffToken $token
        if($result.status-cne'Complete'-or$result.memberCount-ne17-or-not[IO.File]::Exists($h01)-or-not(Assert-CergLo1R2FreshnessArtifact $validArtifact $bindings)){throw'Production P02 staging consumer rejected valid R2 chain.'}
    }
    Add-R2Result $ids[14] {$x=Copy-R2Object $validArtifact;$x.sourceSelectors[0].portableRelativePath='leaf/mutated.bin';Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[15] {$x=Copy-R2Object $validArtifact;$x.currentMembers[0].byteCount=[int64]$x.currentMembers[0].byteCount+1;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[16] {
        $claimMutation=Copy-R2Object $validArtifact;$claimMutation.greenClaims[0].evidenceRefIds=@('missing');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $claimMutation $bindings}
        $testMutation=Copy-R2Object $validArtifact;$testMutation.fixedCounterexamples[0].evidenceRefIds=@('missing');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $testMutation $bindings}
    }
    Add-R2Result $ids[17] {$x=Copy-R2Object $validArtifact;$x.validatorFinishedAtUtc='2000-01-01T00:00:00.0000000Z';Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[18] {
        $implementationMutation=Copy-R2Object $validArtifact;$implementationMutation.validatorImplementation.sha256=$implementationMutation.producerImplementation.sha256;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $implementationMutation $bindings}
        $candidateBindingMutation=Copy-R2Object $r2Preflight;$candidateBindingMutation.candidateLockSha256=('0'*64);Test-R2Throws {Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $candidateBindingMutation -Freshness $validArtifact -FreshnessEvidencePath $freshPath}
        $contractBindingMutation=Copy-R2Object $r2Preflight;$contractBindingMutation.freshnessContractHeadCommit=('f'*40);Test-R2Throws {Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $contractBindingMutation -Freshness $validArtifact -FreshnessEvidencePath $freshPath}
    }
    if($results.Count -ne 19 -or @($results|Where-Object status -cne 'Passed').Count -ne 0){throw 'R2 test conservation failed.'}
    [pscustomobject][ordered]@{total=19;passed=19;failed=0;testRows=@($results)}|ConvertTo-Json -Depth 8
}
finally{
    $full=[IO.Path]::GetFullPath($fixtureRoot)
    if($full.StartsWith($tempBase+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-and[IO.Directory]::Exists($full)){Remove-Item -LiteralPath $full -Recurse -Force}
}
