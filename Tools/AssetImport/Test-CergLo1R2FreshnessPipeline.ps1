[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Test-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')
. (Join-Path $PSScriptRoot 'New-CergLo1ResultGraph.ps1')

$ids=@('R2-CE01-Missing','R2-CE02-Directory','R2-CE03-Reparse','R2-CE04-ByteDrift','R2-CE05-EqualSizeHashDrift','R2-CE06-SelectorConservation','R2-CE07-IndependentDisagreement','R2-CE08-StaleRun','R2-CE09-HiddenField','R2-CE10-ProducerSplice','R2-SP01-ProductionConstructor','R2-SP02-IndependentValidator','R2-SP03-StagingConsumer','R2-AT01-SelectorMutation','R2-AT02-TupleMutation','R2-AT03-EvidenceMutation','R2-AT04-TimeMutation','R2-AT05-ImplementationMutation')
$results=[Collections.Generic.List[object]]::new()
function Add-R2Result {param([string]$Id,[scriptblock]$Body);try{&$Body;$results.Add([pscustomobject][ordered]@{testId=$Id;status='Passed';evidenceLocator="SyntheticFixture/$Id/Assertions"})}catch{throw ($Id+' failed: '+$_.Exception.Message+' STACK '+$_.ScriptStackTrace)}}
function Test-R2Throws {param([scriptblock]$Body);$threw=$false;try{&$Body|Out-Null}catch{$threw=$true};if(-not $threw){throw 'Expected failed-closed exception.'}}
function Copy-R2Object {param([object]$Value);return(($Value|ConvertTo-Json -Depth 100 -Compress)|ConvertFrom-Json -DateKind String)}

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
    function New-Packet {param([object]$C=$candidate,[string]$Started=[DateTimeOffset]::UtcNow.ToString('O'));Invoke-CergLo1R2FreshnessProducer -Candidate $C -CandidateLockPath $candidatePath -SourceRootBindings $bindings -ContractHeadCommit $head -CandidateLockSha256 $lockSha -StartedAtUtc $Started}
    $validPacket=New-Packet
    $validatorImpl=Get-CergR2ValidatorImplementation
    function New-TestRows {param([string[]]$Names);return @($Names|ForEach-Object{[pscustomobject][ordered]@{testId=$_;status='Passed';evidenceRefIds=@($validPacket.producerImplementation.implementationId,$validatorImpl.implementationId)}})}
    $fixedRows=New-TestRows $ids[0..9];$successRows=New-TestRows $ids[10..12];$attackRows=New-TestRows $ids[13..17]

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
    $freshPath=Join-Path $fixtureRoot 'freshness.json';$preflightPath=Join-Path $fixtureRoot 'preflight.json';$attemptRoot=Join-Path $fixtureRoot 'R2Attempt'
    [IO.File]::WriteAllText($freshPath,($validArtifact|ConvertTo-Json -Depth 100 -Compress),[Text.UTF8Encoding]::new($false))
    $freshSha=(Get-FileHash -Algorithm SHA256 -LiteralPath $freshPath).Hash.ToLowerInvariant()
    $planRows=@($validArtifact.currentMembers|ForEach-Object{[pscustomobject][ordered]@{sourceMemberRefId=$_.memberId;sourceId=$_.sourceId;sourcePortableRelativePath=$_.portableRelativePath;stagingPortableRelativePath=('Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input/'+$_.sourceId+'/'+$_.portableRelativePath);byteCount=[int64]$_.byteCount;sha256=$_.sha256}}|Sort-Object stagingPortableRelativePath -CaseSensitive)
    $totalBytes=[int64](($planRows|Measure-Object byteCount -Sum).Sum);$memberIds=@($planRows|ForEach-Object sourceMemberRefId)
    $definition=[pscustomobject][ordered]@{
        schemaVersion='cerg-lo-cerg1-preflight-definition/1.1.0';artifactId='LO-CERG1-P01-DEFINITION';candidateLockSha256=$lockSha
        freshnessEvidenceSha256=$freshSha;freshnessCheckRunId=$validArtifact.checkRunId;freshnessValidatorFinishedAtUtc=$validArtifact.validatorFinishedAtUtc
        contractHeadCommit=$head;selectedCandidateId='char_14401';createdAt=[DateTimeOffset]::UtcNow.ToString('O')
        sourceRootBindings=@([pscustomobject][ordered]@{sourceId='synthetic';privateAbsoluteReadOnlyRoot=$root;rootFingerprint=('f'*64)});implementationBindings=@()
        operation=[pscustomobject][ordered]@{operationId='R2-OP01';obligationRefIds=@('R2-OB01');implementationRefIds=@();inputMemberRefIds=$memberIds;expectedSubjectKinds=@();expectedRelationshipKinds=@();sourceReadMaxFiles=17;sourceReadMaxBytes=$totalBytes;maxDurationSeconds=60;maxResultRows=1;maxOutputFiles=100;maxOutputBytes=$totalBytes;stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Output';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Work'}
        aggregateLimits=[pscustomobject][ordered]@{sourceReadMaxFiles=17;sourceReadMaxBytes=$totalBytes;maxDurationSeconds=60;maxResultRows=1;maxOutputFiles=100;maxOutputBytes=$totalBytes}
        stagingPlan=[pscustomobject][ordered]@{stagingInputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Input';stagingInventoryTemporaryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/staging-inventory.json.tmp';stagingInventoryPath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/staging-inventory.json';workPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Work';outputPortablePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/Output';memberRows=$planRows;memberCount=17;byteCount=$totalBytes;memberSetFingerprint=(Get-CergPreflightStructuredSha256 'cerg-lo1/staging-member-set/1' @($planRows))}
        status='Green';nextAction='RequestExactHumanConfirmationForLOCERG1'
    }
    $r2Preflight=New-CergLo1R2PreflightObject -Definition $definition -Freshness $validArtifact -FreshnessEvidencePath $freshPath -AttemptPrivateAbsoluteRoot $attemptRoot
    [IO.File]::WriteAllText($preflightPath,(ConvertTo-CergPreflightCanonicalJson $r2Preflight),[Text.UTF8Encoding]::new($false))
    Add-R2Result $ids[7] {$x=Copy-R2Object $validArtifact;$x.validatorFinishedAtUtc=[DateTimeOffset]::UtcNow.AddHours(-1).ToString('O');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[8] {$x=Copy-R2Object $validArtifact;$x|Add-Member -NotePropertyName fixtureHidden -NotePropertyValue $true;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[9] {$x=Copy-R2Object (New-Packet);$x.sourceSelectors[0].selectorId='R2S-spliced';$a=Invoke-CergLo1R2FreshnessValidator $x $bindings $fixedRows $successRows $attackRows;if($a.status-cne'FailedClosed'){throw'Producer splice accepted.'}}
    Add-R2Result $ids[10] {if((New-Packet).status-cne'ProducerGreen'){throw'Production constructor not Green.'}}
    Add-R2Result $ids[11] {if($validArtifact.status-cne'Green'-or@($validArtifact.currentMembers).Count-ne17){throw'Independent validator not Green.'}}
    Add-R2Result $ids[12] {
        $inventoryTemp=$r2Preflight.stagingPlan.stagingInventoryTemporaryPrivateAbsolutePath;$inventory=$r2Preflight.stagingPlan.stagingInventoryPrivateAbsolutePath
        $result=Invoke-CergLo1ExactStaging -CandidateLockPath $candidatePath -PreflightPath $preflightPath -FreshnessEvidencePath $freshPath -StagingInventoryTemporaryPath $inventoryTemp -StagingInventoryPath $inventory
        $attempt=[pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-attempt-state/1.1.0';artifactId='LO-CERG1-A01';candidateLockSha256=$lockSha;preflightSha256=(Get-CergR2ValidatorFileHash $preflightPath);contractHeadCommit=$head;selectedCandidateId='char_14401';attemptCount=1;status='StartedNoResult'}
        $null=Assert-CergUpstreamBindings -Candidate $candidate -Preflight $r2Preflight -Freshness $validArtifact -FreshnessEvidencePath $freshPath -Attempt $attempt -Staging $result -CandidatePath $candidatePath -PreflightPath $preflightPath -StagingInventoryPath $inventory -OutputRoot $r2Preflight.stagingPlan.outputPrivateAbsolutePath
        if($result.status-cne'Complete'-or$result.memberCount-ne17-or-not(Assert-CergLo1R2FreshnessArtifact $validArtifact $bindings)){throw'Production staging/result-graph consumers rejected valid R2 chain.'}
    }
    Add-R2Result $ids[13] {$x=Copy-R2Object $validArtifact;$x.sourceSelectors[0].portableRelativePath='leaf/mutated.bin';Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[14] {$x=Copy-R2Object $validArtifact;$x.currentMembers[0].byteCount=[int64]$x.currentMembers[0].byteCount+1;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[15] {
        $claimMutation=Copy-R2Object $validArtifact;$claimMutation.greenClaims[0].evidenceRefIds=@('missing');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $claimMutation $bindings}
        $testMutation=Copy-R2Object $validArtifact;$testMutation.fixedCounterexamples[0].evidenceRefIds=@('missing');Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $testMutation $bindings}
    }
    Add-R2Result $ids[16] {$x=Copy-R2Object $validArtifact;$x.validatorFinishedAtUtc='2000-01-01T00:00:00.0000000Z';Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $x $bindings}}
    Add-R2Result $ids[17] {
        $implementationMutation=Copy-R2Object $validArtifact;$implementationMutation.validatorImplementation.sha256=$implementationMutation.producerImplementation.sha256;Test-R2Throws {Assert-CergLo1R2FreshnessArtifact $implementationMutation $bindings}
        $candidateBindingMutation=Copy-R2Object $r2Preflight;$candidateBindingMutation.candidateLockSha256=('0'*64);Test-R2Throws {Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $candidateBindingMutation -Freshness $validArtifact -FreshnessEvidencePath $freshPath}
        $contractBindingMutation=Copy-R2Object $r2Preflight;$contractBindingMutation.contractHeadCommit=('f'*40);Test-R2Throws {Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $contractBindingMutation -Freshness $validArtifact -FreshnessEvidencePath $freshPath}
    }
    if($results.Count -ne 18 -or @($results|Where-Object status -cne 'Passed').Count -ne 0){throw 'R2 test conservation failed.'}
    [pscustomobject][ordered]@{total=18;passed=18;failed=0;testRows=@($results)}|ConvertTo-Json -Depth 8
}
finally{
    $full=[IO.Path]::GetFullPath($fixtureRoot)
    if($full.StartsWith($tempBase+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-and[IO.Directory]::Exists($full)){Remove-Item -LiteralPath $full -Recurse -Force}
}
