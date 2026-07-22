[CmdletBinding()]
param(
    [string]$CandidateLockPath,[string]$ConfirmedF01Path,[string]$PreflightPath,[string]$ReadinessPath,[string]$ConfirmationId,
    [string]$F02TemporaryPath,[string]$F02Path,[string]$A01TemporaryPath,[string]$A01Path,[string]$H01TemporaryPath,[string]$H01Path,
    [string]$StagingInventoryTemporaryPath,[string]$StagingInventoryPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Test-CergLo1R2Freshness.ps1')
. (Join-Path $PSScriptRoot 'Invoke-CergLo1ExactStaging.ps1')

$script:CergR2AtomicRunnerPath=$PSCommandPath
function Get-CergR2AtomicRunnerImplementation {
    $i=Get-Item -LiteralPath $script:CergR2AtomicRunnerPath;$sha=Get-CergSha256Hex $i.FullName
    $id='R2RUNNER-'+(Get-CergStructuredSha256 'cerg-r2/atomic-runner-id/1' @('Tools/AssetImport/Invoke-CergLo1R2AtomicHandoff.ps1',[int64]$i.Length,$sha))
    [pscustomobject][ordered]@{implementationId=$id;role='AtomicF02A01LOHandoffRunner';portableRelativePath='Tools/AssetImport/Invoke-CergLo1R2AtomicHandoff.ps1';byteCount=[int64]$i.Length;sha256=$sha}
}
function Get-CergR2ConfirmationId {
    param([string]$ContractHeadCommit,[string]$F01Sha256,[string]$F01CheckRunId,[string]$MemberSetFingerprint,[string]$P01Sha256,[string]$RunnerImplementationId)
    'R2CONF-'+(Get-CergStructuredSha256 'cerg-r2/p01-confirmation-id/1' @($ContractHeadCommit,$F01Sha256,$F01CheckRunId,$MemberSetFingerprint,$P01Sha256,$RunnerImplementationId))
}
function Install-CergR2AtomicJson {
    param([object]$Value,[string]$TemporaryPath,[string]$FinalPath)
    if([IO.File]::Exists($TemporaryPath)-or[IO.File]::Exists($FinalPath)){throw'AtomicHandoffFailure: output temporary/final path must be initially absent.'}
    $json=ConvertTo-CergCanonicalJsonValue $Value;[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName((Get-CergFullPath $TemporaryPath)))|Out-Null
    [IO.File]::WriteAllText((Get-CergFullPath $TemporaryPath),$json,$script:CergUtf8NoBom)
    if([IO.File]::ReadAllText((Get-CergFullPath $TemporaryPath),$script:CergUtf8NoBom)-cne$json-or[IO.File]::Exists($FinalPath)){throw'AtomicHandoffFailure: temporary reopen or no-overwrite check failed.'}
    [IO.File]::Move((Get-CergFullPath $TemporaryPath),(Get-CergFullPath $FinalPath));Get-CergSha256Hex $FinalPath
}
function Assert-CergR2APlusReadiness {
    param([Parameter(Mandatory=$true)][object]$Readiness,[Parameter(Mandatory=$true)][string]$ContractHeadCommit)
    if($Readiness.schemaVersion-cne'cerg-r2-aplus-readiness/1.1.0'-or$Readiness.artifactId-cne'R2-TO04'-or$Readiness.contractHeadCommit-cne$ContractHeadCommit-or$Readiness.status-cne'Green'-or@($Readiness.failures).Count-ne0-or$Readiness.nextAction-cne'AwaitTotalControlAuditBeforeR2P01AfterHeadDomainCorrection'){throw'AtomicHandoffFailure: A+ readiness fixed state invalid.'}
    $r2=@('R2-CE01-Missing','R2-CE02-Directory','R2-CE03-Reparse','R2-CE04-ByteDrift','R2-CE05-EqualSizeHashDrift','R2-CE06-SelectorConservation','R2-CE07-IndependentDisagreement','R2-CE08-StaleRun','R2-CE09-HiddenField','R2-CE10-ProducerSplice','R2-CE11-AncestorReparse','R2-SP01-ProductionConstructor','R2-SP02-IndependentValidator','R2-SP03-StagingConsumer','R2-AT01-SelectorMutation','R2-AT02-TupleMutation','R2-AT03-EvidenceMutation','R2-AT04-TimeMutation','R2-AT05-ImplementationMutation')
    $aplus=@('R2A-CE01-ConfirmationMismatch','R2A-CE02-SourceDrift','R2A-CE03-ExpiredBeforeOpen','R2A-CE04-ForeignProcess','R2A-CE05-A01WithoutFirstOpen','R2A-CE06-HeadDomainSplice','R2A-SP01-AtomicHandoff')
    $v14=@(1..23|ForEach-Object{'T1A3-TEST{0:D2}'-f$_})+@('T1A4-TEST24','T1A4-TEST25');$expectedTests=@($r2+$aplus+$v14);$actualTests=@($Readiness.testRows)
    if($actualTests.Count-ne51-or(@($actualTests|ForEach-Object testId)-join'|')-cne($expectedTests-join'|')-or@($actualTests|Where-Object{$_.status-cne'Passed'-or[string]::IsNullOrWhiteSpace([string]$_.evidenceLocator)}).Count-ne0){throw'AtomicHandoffFailure: A+ readiness test matrix invalid.'}
    $expectedPaths=@('Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1','Tools/AssetImport/Invoke-CergLo1R2AtomicHandoff.ps1','Tools/AssetImport/New-CergLo1Preflight.ps1','Tools/AssetImport/New-CergLo1R2Freshness.ps1','Tools/AssetImport/New-CergLo1ResultGraph.ps1','Tools/AssetImport/Test-CergLo1Pipeline.ps1','Tools/AssetImport/Test-CergLo1R2AtomicHandoff.ps1','Tools/AssetImport/Test-CergLo1R2Freshness.ps1','Tools/AssetImport/Test-CergLo1R2FreshnessPipeline.ps1');$actualPaths=@($Readiness.toolRows|ForEach-Object portableRelativePath);[Array]::Sort($actualPaths,[StringComparer]::Ordinal)
    if($actualPaths.Count-ne9-or($actualPaths-join'|')-cne($expectedPaths-join'|')){throw'AtomicHandoffFailure: A+ readiness tool set invalid.'}
    $repoRoot=[IO.Directory]::GetParent([IO.Directory]::GetParent($PSScriptRoot).FullName).FullName
    foreach($row in @($Readiness.toolRows)){$leaf=[IO.Path]::Combine($repoRoot,([string]$row.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar));$item=Get-Item -LiteralPath $leaf;if([int64]$row.byteCount-ne[int64]$item.Length-or$row.sha256-cne(Get-CergSha256Hex $leaf)){throw'AtomicHandoffFailure: A+ readiness tool identity mismatch.'}}
    return $true
}
function Invoke-CergLo1R2AtomicHandoff {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$CandidateLockPath,[Parameter(Mandatory=$true)][string]$ConfirmedF01Path,[Parameter(Mandatory=$true)][string]$PreflightPath,[Parameter(Mandatory=$true)][string]$ReadinessPath,[Parameter(Mandatory=$true)][string]$ConfirmationId,
        [Parameter(Mandatory=$true)][string]$F02TemporaryPath,[Parameter(Mandatory=$true)][string]$F02Path,[Parameter(Mandatory=$true)][string]$A01TemporaryPath,[Parameter(Mandatory=$true)][string]$A01Path,[Parameter(Mandatory=$true)][string]$H01TemporaryPath,[Parameter(Mandatory=$true)][string]$H01Path,
        [Parameter(Mandatory=$true)][string]$StagingInventoryTemporaryPath,[Parameter(Mandatory=$true)][string]$StagingInventoryPath
    )
    foreach($p in @($F02TemporaryPath,$F02Path,$A01TemporaryPath,$A01Path,$H01TemporaryPath,$H01Path,$StagingInventoryTemporaryPath,$StagingInventoryPath)){if([IO.File]::Exists($p)){throw'AtomicHandoffFailure: an output leaf already exists.'}}
    $candidate=Read-CergJsonFile $CandidateLockPath;$f01=Read-CergJsonFile $ConfirmedF01Path;$p01=Read-CergJsonFile $PreflightPath;$readiness=Read-CergJsonFile $ReadinessPath
    $bindings=@($p01.sourceRootBindings|ForEach-Object{[pscustomobject]@{sourceId=$_.sourceId;privateAbsoluteReadOnlyRoot=$_.privateAbsoluteReadOnlyRoot}})
    $null=Assert-CergLo1R2FreshnessArtifact -Artifact $f01 -SourceRootBindings $bindings -Generation F01 -MaxAgeSeconds ([int]::MaxValue) -StructuralOnly
    $null=Assert-CergLo1PreflightConsumerContract -Candidate $candidate -Preflight $p01 -Freshness $f01 -FreshnessEvidencePath $ConfirmedF01Path -StagingInventoryTemporaryPath $StagingInventoryTemporaryPath -StagingInventoryPath $StagingInventoryPath
    if($p01.schemaVersion-cne'cerg-lo-cerg1-preflight/1.5.0'){throw'AtomicHandoffFailure: P01 v1.5 identity invalid.'}
    $null=Assert-CergR2APlusReadiness $readiness $p01.contractHeadCommit
    $runner=Get-CergR2AtomicRunnerImplementation;$runnerRow=@($readiness.toolRows|Where-Object{$_.portableRelativePath-ceq$runner.portableRelativePath})
    if($runnerRow.Count-ne1-or$runnerRow[0].sha256-cne$runner.sha256-or[int64]$runnerRow[0].byteCount-ne$runner.byteCount-or$readiness.contractHeadCommit-cne$p01.contractHeadCommit){throw'AtomicHandoffFailure: runner readiness binding invalid.'}
    $f01Sha=Get-CergSha256Hex $ConfirmedF01Path;$p01Sha=Get-CergSha256Hex $PreflightPath;$expectedConfirmation=Get-CergR2ConfirmationId $p01.contractHeadCommit $f01Sha $f01.checkRunId $f01.currentMemberSetFingerprint $p01Sha $runner.implementationId
    if($ConfirmationId-cne$expectedConfirmation){throw'AtomicHandoffFailure: exact confirmation identity mismatch.'}
    $r2Rows=@($readiness.testRows|Where-Object{$_.testId-like'R2-*'-and$_.testId-notlike'R2A-*'});if($r2Rows.Count-ne19-or@($r2Rows|Where-Object{$_.status-cne'Passed'}).Count){throw'AtomicHandoffFailure: R2 readiness test projection invalid.'}
    $started=[DateTimeOffset]::UtcNow.ToString('O');$candidateSha=Get-CergSha256Hex $CandidateLockPath;$packet=Invoke-CergLo1R2FreshnessProducer -Candidate $candidate -CandidateLockPath $CandidateLockPath -SourceRootBindings $bindings -ContractHeadCommit $p01.contractHeadCommit -CandidateLockSha256 $candidateSha -StartedAtUtc $started
    $validator=Get-CergR2ValidatorImplementation;$refs=@($packet.producerImplementation.implementationId,$validator.implementationId)
    function New-R2Rows([object[]]$Rows){@($Rows|ForEach-Object{[pscustomobject][ordered]@{testId=$_.testId;status='Passed';evidenceRefIds=@($refs)}})}
    $f02=Invoke-CergLo1R2FreshnessValidator -ProducerPacket $packet -SourceRootBindings $bindings -FixedCounterexamples (New-R2Rows $r2Rows[0..10]) -SuccessPathChecks (New-R2Rows $r2Rows[11..13]) -PostSuccessAttackChecks (New-R2Rows $r2Rows[14..18]) -Generation F02
    $null=Assert-CergLo1R2FreshnessArtifact -Artifact $f02 -SourceRootBindings $bindings -Generation F02 -StructuralOnly
    if($f02.currentMemberSetFingerprint-cne$f01.currentMemberSetFingerprint){throw'AtomicHandoffFailure: F02 fingerprint differs from confirmed F01.'}
    $f02Sha=Install-CergR2AtomicJson $f02 $F02TemporaryPath $F02Path
    $created=[DateTimeOffset]::UtcNow;$instance='R2INST-'+(Get-CergStructuredSha256 'cerg-r2/runner-instance-id/1' @($runner.implementationId,$f02.checkRunId,$created.ToString('O'),[int64]$PID))
    $finished=[DateTimeOffset]::Parse([string]$f02.validatorFinishedAtUtc).ToUniversalTime();if(($created-$finished).TotalMilliseconds-gt10000){throw'AtomicHandoffFailure: F02 expired before A01 installation.'}
    $a01=[pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-r2-attempt-state/1.0.0';artifactId='LO-CERG1-R2-A01';contractHeadCommit=$p01.contractHeadCommit;candidateLockSha256=$candidateSha;selectedCandidateId='char_14401';confirmedF01Sha256=$f01Sha;confirmedF01CheckRunId=$f01.checkRunId;confirmedMemberSetFingerprint=$f01.currentMemberSetFingerprint;preflightSha256=$p01Sha;confirmationId=$ConfirmationId;adjacencyF02Sha256=$f02Sha;adjacencyCheckRunId=$f02.checkRunId;adjacencyMemberSetFingerprint=$f02.currentMemberSetFingerprint;adjacencyValidatorFinishedAtUtc=$f02.validatorFinishedAtUtc;runnerImplementation=$runner;runnerInstanceId=$instance;processId=[int64]$PID;createdAtUtc=$created.ToString('O');maxFirstSourceOpenDelayMilliseconds=[int64]10000;LOUsedBeforeFirstSourceOpen=[int64]1;LOUsedAfterFirstSourceOpen=[int64]2;status='ArmedNoSourceOpen';sameRunnerOnly=$true;nextAction='SameRunnerEnterLOWrapperImmediately'}
    $a01Sha=Install-CergR2AtomicJson $a01 $A01TemporaryPath $A01Path
    $token=New-CergR2AtomicHandoffToken -RunnerInstanceId $instance -RunnerImplementationId $runner.implementationId -AdjacencyValidatorFinishedAtUtc $f02.validatorFinishedAtUtc -A01Path $A01Path -A01Sha256 $a01Sha -H01TemporaryPath $H01TemporaryPath -H01Path $H01Path -LOUsedBeforeFirstSourceOpen 1 -LOUsedAfterFirstSourceOpen 2
    $inventory=Invoke-CergLo1ExactStaging -CandidateLockPath $CandidateLockPath -PreflightPath $PreflightPath -FreshnessEvidencePath $ConfirmedF01Path -StagingInventoryTemporaryPath $StagingInventoryTemporaryPath -StagingInventoryPath $StagingInventoryPath -AtomicHandoffToken $token
    if(-not[IO.File]::Exists($H01Path)-or-not$token.firstSourceOpenObserved){throw'AtomicHandoffFailure: LO wrapper returned without H01.'}
    [pscustomobject][ordered]@{f02Sha256=$f02Sha;a01Sha256=$a01Sha;h01Sha256=Get-CergSha256Hex $H01Path;stagingInventory=$inventory}
}

if($MyInvocation.InvocationName-ne'.'){
    $required=@($CandidateLockPath,$ConfirmedF01Path,$PreflightPath,$ReadinessPath,$ConfirmationId,$F02TemporaryPath,$F02Path,$A01TemporaryPath,$A01Path,$H01TemporaryPath,$H01Path,$StagingInventoryTemporaryPath,$StagingInventoryPath);if(@($required|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count){throw'All atomic handoff arguments are required.'}
    Invoke-CergLo1R2AtomicHandoff @PSBoundParameters|ConvertTo-Json -Depth 20
}
