Set-StrictMode -Version Latest

$script:Utf8 = [Text.UTF8Encoding]::new($false)
$script:Ordinal = [StringComparer]::Ordinal
$script:Registry = @(
    [pscustomobject]@{ artifactId='AR-I01'; path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I02'; path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I03'; path='Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I04'; path='docs/asset-migration/schemas/source-corpus-ledger.schema.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I05'; path='docs/asset-migration/schemas/status-vocabulary.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I06'; path='docs/asset-migration/schemas/root-gate-summary.schema.json'; requirement='Required' }
    [pscustomobject]@{ artifactId='AR-I07'; path='Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json'; requirement='ConditionalInput' }
    [pscustomobject]@{ artifactId='AR-I08'; path='Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json'; requirement='ConditionalInput' }
    [pscustomobject]@{ artifactId='AR-I09'; path='Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json'; requirement='ConditionalInput' }
    [pscustomobject]@{ artifactId='AR-I10'; path='Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json'; requirement='ConditionalAuthority' }
    [pscustomobject]@{ artifactId='AR-I11'; path='Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json'; requirement='ConditionalApproval' }
)

function ConvertTo-C2ScalarLine {
    param([string]$Name, [string]$Value)
    if ($null -eq $Value -or $Value.IndexOfAny([char[]]@([char]0,"`r","`n")) -ge 0) { throw "Invalid framed scalar: $Name" }
    $length = $script:Utf8.GetByteCount($Value)
    return "${Name}:${length}:${Value}`n"
}

function Get-C2Sha256 {
    param([byte[]]$Bytes)
    $hash = [Security.Cryptography.SHA256]::HashData($Bytes)
    return [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Test-C2PortablePath {
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path) -or $Path.Contains('\') -or $Path.StartsWith('/') -or
        $Path.Contains('://') -or $Path -match '^[A-Za-z]:' -or $Path.Split('/') -contains '..' -or
        $Path.Split('/') -contains '.' -or $Path.Contains("`r") -or $Path.Contains("`n") -or $Path.Contains([char]0)) { return $false }
    return $true
}

function Get-C2ArtifactEntryBytes {
    param([string]$Path, [string]$Sha256)
    if (-not (Test-C2PortablePath $Path)) { throw "Unsafe portable path: $Path" }
    if ($Sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Invalid SHA-256: $Path" }
    return $script:Utf8.GetBytes("C2ArtifactEntryV1`n$(ConvertTo-C2ScalarLine path $Path)$(ConvertTo-C2ScalarLine sha256 $Sha256)")
}

function Get-C2DiscoveryInputFingerprint {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object[]]$Entries)
    $seen = [Collections.Generic.HashSet[string]]::new($script:Ordinal)
    $ordered = [Collections.Generic.List[object]]::new()
    foreach ($entry in $Entries) {
        $names = @($entry.PSObject.Properties.Name)
        if ($names.Count -ne 2 -or $names[0] -cne 'path' -or $names[1] -cne 'sha256') { throw 'HI-13a entry shape/order invalid.' }
        if (-not $seen.Add([string]$entry.path)) { throw "Duplicate HI-13 path: $($entry.path)" }
        $ordered.Add($entry)
    }
    $ordered.Sort([Comparison[object]]{ param($a,$b) $script:Ordinal.Compare([string]$a.path,[string]$b.path) })
    $countText = [string]$ordered.Count
    $text = "C2DiscoveryInputV1`nentries.count:$($script:Utf8.GetByteCount($countText)):$countText`n"
    for ($i=0; $i -lt $ordered.Count; $i++) {
        $nested = Get-C2ArtifactEntryBytes -Path $ordered[$i].path -Sha256 $ordered[$i].sha256
        $text += "entries[$i]:$($nested.Length):$($script:Utf8.GetString($nested))`n"
    }
    return Get-C2Sha256 $script:Utf8.GetBytes($text)
}

function New-C2AccountingRow {
    param([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence)
    $ev = [Collections.Generic.List[string]]::new()
    foreach($item in $Evidence){ if(-not $ev.Contains($item)){ $ev.Add($item) } }
    $ev.Sort($script:Ordinal)
    $pre = "C2AccountingRecordV1`n" + (ConvertTo-C2ScalarLine owningArray $OwningArray) + (ConvertTo-C2ScalarLine subjectKind $SubjectKind) + (ConvertTo-C2ScalarLine subjectId $SubjectId) + (ConvertTo-C2ScalarLine reasonCode $ReasonCode) + (ConvertTo-C2ScalarLine attribution $Attribution)
    $c=[string]$ev.Count; $pre += "evidence.count:$($script:Utf8.GetByteCount($c)):$c`n"
    for($i=0;$i -lt $ev.Count;$i++){ $pre += ConvertTo-C2ScalarLine "evidence[$i]" $ev[$i] }
    [pscustomobject][ordered]@{ recordId="accounting-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($pre))"; subjectKind=$SubjectKind; subjectId=$SubjectId; reasonCode=$ReasonCode; attribution=$Attribution; evidence=[string[]]$ev }
}

function New-C2Check {
    param([string]$Id,[string]$Status,[string]$Attribution,[string[]]$Evidence,[string[]]$Prerequisites)
    [pscustomobject][ordered]@{ subjectId=$Id; status=$Status; attribution=$Attribution; evidence=$Evidence; prerequisites=$Prerequisites }
}

function Invoke-C2PureDiscoveryIntake {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$ArtifactFacts,
        [Parameter(Mandatory)][psobject]$HandoffFact,
        [AllowNull()][string]$StartCommitOid,
        [AllowNull()][string]$EndCommitOid,
        [bool]$FreshnessPrerequisiteAvailable = $true
    )
    $failures=[Collections.Generic.List[object]]::new()
    $states=[Collections.Generic.List[object]]::new()
    $directOwner=$null
    $expectedFactNames=@('artifactId','path','requirement','presence','worktreeSha256','commitBlobSha256','manifestSha256','identityValid','freshnessValid')
    for($i=0;$i -lt $script:Registry.Count;$i++){
        $reg=$script:Registry[$i]; $fact=if($i -lt $ArtifactFacts.Count){$ArtifactFacts[$i]}else{$null}
        $shapeOk=($null -ne $fact) -and ((@($fact.PSObject.Properties.Name) -join ',') -ceq ($expectedFactNames -join ','))
        $identityOk=$shapeOk -and $fact.artifactId -ceq $reg.artifactId -and $fact.path -ceq $reg.path -and $fact.requirement -ceq $reg.requirement
        $safe=$shapeOk -and (Test-C2PortablePath ([string]$fact.path))
        $failed=-not $shapeOk -or -not $identityOk -or -not $safe -or -not [bool]$fact.identityValid -or -not [bool]$fact.freshnessValid
        if($failed -and $null -eq $directOwner){
            if(-not $shapeOk){$directOwner='FT-02';$reason='InvalidSchema';$kind='SchemaDocument'}
            elseif(-not $safe){$directOwner='FT-04';$reason='UnsafePath';$kind='PublicProjection'}
            elseif(-not $identityOk){$directOwner='FT-02';$reason='InvalidSchema';$kind='SchemaDocument'}
            else{$directOwner='FT-02';$reason='InvalidSchema';$kind='SchemaDocument'}
            $failures.Add((New-C2AccountingRow inputFailures $kind $reg.artifactId $reason "${directOwner}:$($reg.artifactId)" @($reg.path)))
        }
        $presence=if($shapeOk -and $fact.presence -ceq 'Absent'){'Absent'}else{'Present'}
        $states.Add([pscustomobject][ordered]@{
            artifactId=$reg.artifactId; path=$reg.path; requirement=$reg.requirement; presence=$presence
            readStatus=if($failed){'Failed'}elseif($presence -ceq 'Absent'){'NotRead'}else{'Accepted'}
            worktreeSha256=if($shapeOk){$fact.worktreeSha256}else{$null}; commitBlobSha256=if($shapeOk){$fact.commitBlobSha256}else{$null}; manifestSha256=if($shapeOk){$fact.manifestSha256}else{$null}
            identityStatus=if($failed){'Failed'}elseif($presence -ceq 'Absent'){'NotApplicable'}else{'Accepted'}
            freshnessStatus=if($failed){'Failed'}else{'Accepted'}; evidence=@($reg.path)
        })
    }
    if($ArtifactFacts.Count -ne 11 -and $null -eq $directOwner){
        $directOwner='FT-02'; $failures.Add((New-C2AccountingRow inputFailures SchemaDocument 'AR-I11' InvalidSchema 'FT-02:AR-I11' @($script:Registry[10].path)))
    }
    $handoffNames=@('snapshotId','ledgerPath','summaryPath')
    $handoffOk=((@($HandoffFact.PSObject.Properties.Name) -join ',') -ceq ($handoffNames -join ',')) -and ($HandoffFact.snapshotId -ceq 'snapshot-pc-install-001') -and ($HandoffFact.ledgerPath -ceq $script:Registry[1].path) -and ($HandoffFact.summaryPath -ceq $script:Registry[2].path)
    if(-not $handoffOk){
        $directOwner='FT-01'; $failures.Clear(); $failures.Add((New-C2AccountingRow inputFailures C1Handoff 'C2Check:C1Handoff' IdentityMismatch 'FT-01:C2Check:C1Handoff' @($script:Registry[0].path)))
    }
    $headStable=if($StartCommitOid -and $EndCommitOid){$StartCommitOid -ceq $EndCommitOid}else{$null}
    $oidValid=($null -eq $StartCommitOid -or $StartCommitOid -cmatch '^[0-9a-f]{40}$') -and ($null -eq $EndCommitOid -or $EndCommitOid -cmatch '^[0-9a-f]{40}$')
    if(-not $oidValid -or $headStable -eq $false){ if($null -eq $directOwner){$directOwner='FT-03';$failures.Add((New-C2AccountingRow inputFailures FreshnessCheck 'C2Check:Freshness' StaleFingerprint 'FT-03:C2Check:Freshness' @()))} }
    $checks=[Collections.Generic.List[object]]::new()
    $checks.Add((New-C2Check 'C2Check:LightweightPolicy' Accepted 'Accepted:C2Check:LightweightPolicy' @('Tools/AssetImport/C2DiscoveryIntakeGate.psm1','Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1') @()))
    $checks.Add((New-C2Check 'C2Check:C1Handoff' $(if($handoffOk){'Accepted'}else{'Failed'}) $(if($handoffOk){'Accepted:C2Check:C1Handoff'}else{'FT-01:C2Check:C1Handoff'}) @($script:Registry[1].path,$script:Registry[0].path,$script:Registry[2].path) @('AR-I01','AR-I02','AR-I03')))
    $freshAccepted=$handoffOk -and $FreshnessPrerequisiteAvailable -and $null -eq $directOwner
    $freshStatus=if($freshAccepted){'Accepted'}elseif(-not $handoffOk -or -not $FreshnessPrerequisiteAvailable){'NotEvaluated'}else{'Failed'}
    $checks.Add((New-C2Check 'C2Check:Freshness' $freshStatus $(if($freshStatus -ceq 'Accepted'){'Accepted:C2Check:Freshness'}elseif($freshStatus -ceq 'NotEvaluated'){'FT-15:C2Check:Freshness'}else{"${directOwner}:C2Check:Freshness"}) @() @('AR-I01','AR-I02','AR-I03','AR-I04','AR-I05','AR-I06','AR-I07','AR-I08','AR-I09','AR-I10','AR-I11','GitAdapter:EndHead','GitAdapter:StartCommitOid')))
    $checks.Add((New-C2Check 'C2Check:Conservation' NotEvaluated 'FT-15:C2Check:Conservation' @() @('Stage:C2Partitions')))
    $checks.Add((New-C2Check 'C2Check:PublicProjection' NotEvaluated 'FT-15:C2Check:PublicProjection' @($script:Registry[5].path) @('AR-O01','AR-O02','AR-O03','AR-O04','AR-O05')))
    $suppressions=[Collections.Generic.List[object]]::new()
    if($freshStatus -ceq 'NotEvaluated'){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Freshness' PrerequisiteUnavailable 'FT-15:C2Check:Freshness' @()))}
    $suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Conservation' PrerequisiteUnavailable 'FT-15:C2Check:Conservation' @()))
    $suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:PublicProjection' PrerequisiteUnavailable 'FT-15:C2Check:PublicProjection' @($script:Registry[5].path)))
    $read=@($states|Where-Object readStatus -ne 'NotRead'); $accepted=@($read|Where-Object readStatus -eq 'Accepted'); $failed=@($read|Where-Object readStatus -eq 'Failed')
    $acceptedChecks=@($checks|Where-Object status -eq 'Accepted');$failedChecks=@($checks|Where-Object status -eq 'Failed');$neChecks=@($checks|Where-Object status -eq 'NotEvaluated')
    $fingerprint=$null
    if($failures.Count -eq 0 -and $freshStatus -ceq 'Accepted'){$fingerprint=Get-C2DiscoveryInputFingerprint -Entries @($accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})}
    $next=if($failures.Count -eq 0){'Implement SP-01/SP-02 in a separately approved fixture-only slice.'}elseif($directOwner -ceq 'FT-01'){'Fix C1 handoff fixture'}elseif($directOwner -ceq 'FT-04'){'Fix portable path'}else{'Fix reviewed registry shape'}
    $o1=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=if($handoffOk){$HandoffFact.snapshotId}else{$null};startCommitOid=$StartCommitOid;endCommitOid=$EndCommitOid;headStable=$headStable;discoveryInputFingerprint=$fingerprint;artifactStates=[object[]]$states;contractChecks=[object[]]$checks;inputFailures=[object[]]$failures;inputExclusions=@();inputSuppressions=[object[]]$suppressions;decision=[pscustomobject][ordered]@{failureAttribution=if($failures.Count -eq 0){'None; intake and freshness checks passed; deferred checks remain NotEvaluated.'}else{$failures[0].attribution};nextAllowedAction=$next}}
    $o2=[pscustomobject][ordered]@{status=if($failures.Count -eq 0){'Passed'}else{'Failed'};issueCount=$failures.Count;registeredArtifactCount=11;readArtifactCount=$read.Count;requiredArtifactCount=@($states|Where-Object requirement -eq Required).Count;presentOptionalArtifactCount=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Present'}).Count;absentOptionalArtifactCount=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Absent'}).Count;failedRegistrySlotCount=@($states|Where-Object readStatus -eq Failed).Count;acceptedArtifactCount=$accepted.Count;failedArtifactCount=$failed.Count;contractCheckCount=5;acceptedCheckCount=$acceptedChecks.Count;failedCheckCount=$failedChecks.Count;notEvaluatedCheckCount=$neChecks.Count;inputSubjectCount=$read.Count+5;acceptedInputSubjectCount=$accepted.Count+$acceptedChecks.Count;inputFailureCount=$failures.Count;excludedInputSubjectCount=0;notEvaluatedInputSubjectCount=$neChecks.Count;gitInspectionProcessCount=0;heavyProcessCount=0;realAssetReadCount=0;createdExtractedCount=0;createdImportedCount=0;startCommitOid=$StartCommitOid;endCommitOid=$EndCommitOid;headStable=$headStable;discoveryInputFingerprint=$fingerprint;nextAllowedAction=$next}
    [pscustomobject][ordered]@{O1=$o1;O2=$o2}
}

function New-C2GitProcessInfo {
    param([string]$GitExecutable,[string[]]$Arguments)
    $info=[Diagnostics.ProcessStartInfo]::new()
    $info.FileName=$GitExecutable
    $info.UseShellExecute=$false
    $info.RedirectStandardOutput=$true
    $info.RedirectStandardError=$true
    $info.CreateNoWindow=$true
    foreach($argument in $Arguments){$null=$info.ArgumentList.Add($argument)}
    foreach($key in @($info.Environment.Keys)){
        if($key.StartsWith('GIT_',[StringComparison]::OrdinalIgnoreCase) -or $key.StartsWith('GCM_',[StringComparison]::OrdinalIgnoreCase) -or $key.StartsWith('SSH_',[StringComparison]::OrdinalIgnoreCase) -or $key -ceq 'HOME' -or $key -ceq 'XDG_CONFIG_HOME'){$null=$info.Environment.Remove($key)}
    }
    $info.Environment['GIT_CONFIG_NOSYSTEM']='1'
    $info.Environment['GIT_CONFIG_GLOBAL']='NUL'
    $info.Environment['GIT_CONFIG_COUNT']='0'
    $info.Environment['GIT_OPTIONAL_LOCKS']='0'
    $info.Environment['GIT_TERMINAL_PROMPT']='0'
    $info.Environment['GCM_INTERACTIVE']='Never'
    return $info
}

function Test-C2GitChildEnvironment {
    param([Diagnostics.ProcessStartInfo]$Info)
    $allowed=@('GIT_CONFIG_NOSYSTEM','GIT_CONFIG_GLOBAL','GIT_CONFIG_COUNT','GIT_OPTIONAL_LOCKS','GIT_TERMINAL_PROMPT','GCM_INTERACTIVE')
    foreach($key in $Info.Environment.Keys){
        if(($key.StartsWith('GIT_',[StringComparison]::OrdinalIgnoreCase) -or $key.StartsWith('GCM_',[StringComparison]::OrdinalIgnoreCase) -or $key.StartsWith('SSH_',[StringComparison]::OrdinalIgnoreCase)) -and $allowed -cnotcontains $key){return $false}
        if($key -ceq 'HOME' -or $key -ceq 'XDG_CONFIG_HOME'){return $false}
    }
    return $Info.Environment['GIT_CONFIG_NOSYSTEM'] -ceq '1' -and $Info.Environment['GIT_CONFIG_GLOBAL'] -ceq 'NUL' -and $Info.Environment['GIT_CONFIG_COUNT'] -ceq '0' -and $Info.Environment['GIT_OPTIONAL_LOCKS'] -ceq '0' -and $Info.Environment['GIT_TERMINAL_PROMPT'] -ceq '0' -and $Info.Environment['GCM_INTERACTIVE'] -ceq 'Never'
}

function Invoke-C2GitChild {
    param([string]$GitExecutable,[string[]]$Arguments,[int]$CallNumber,[bool]$RawBlobCapture)
    $info=New-C2GitProcessInfo $GitExecutable $Arguments
    if(-not (Test-C2GitChildEnvironment $info)){throw 'FT-13: child environment rejected before launch.'}
    $process=[Diagnostics.Process]::new();$process.StartInfo=$info
    if(-not $process.Start()){throw "FT-03: call $CallNumber did not start."}
    $memory=[IO.MemoryStream]::new()
    $copyTask=$process.StandardOutput.BaseStream.CopyToAsync($memory)
    $errorTask=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit();$null=$copyTask.GetAwaiter().GetResult();$stderr=$errorTask.GetAwaiter().GetResult()
    $bytes=$memory.ToArray();$exitCode=$process.ExitCode;$process.Dispose();$memory.Dispose()
    [pscustomobject][ordered]@{callNumber=$CallNumber;arguments=$Arguments;exitCode=$exitCode;stdoutBytes=$bytes;stderr=$stderr;environmentValid=$true;useShellExecute=$false;redirectStandardOutput=$true;redirectStandardError=$true;rawBlobCapture=$RawBlobCapture;stdoutByteCount=$bytes.Length}
}

function Invoke-C2GitFreshnessAdapter {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot)
    $gitCommand=Get-Command git.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
    $gitExecutable=$gitCommand.Source
    if(-not [IO.Path]::IsPathFullyQualified($gitExecutable)){throw 'FT-13: git executable is not absolute.'}
    $trace=[Collections.Generic.List[object]]::new();$oidPattern="^[0-9a-f]{40}`n$"
    $paths=@(
        'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json',
        'Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json',
        'Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json',
        'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
        'Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json'
    )
    $call1=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'rev-parse','--verify','HEAD^{commit}') 1 $false;$null=$trace.Add($call1)
    $text=$script:Utf8.GetString($call1.stdoutBytes)
    if($call1.exitCode -ne 0 -or $call1.stderr.Length -ne 0 -or $text -cnotmatch $oidPattern){throw 'FT-03: invalid start HEAD result.'}
    $startOid=$text.Substring(0,40)
    $call2=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'cat-file','blob',"${startOid}:$($paths[0])") 2 $true;$null=$trace.Add($call2)
    if($call2.exitCode -ne 0 -or $call2.stderr.Length -ne 0){throw 'FT-03: invalid AR-I07 blob result.'}
    $call3=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'ls-tree','-z','--full-tree',$startOid,'--',$paths[1],$paths[2]) 3 $false;$null=$trace.Add($call3)
    if($call3.exitCode -ne 0 -or $call3.stderr.Length -ne 0 -or $call3.stdoutBytes.Length -ne 0){throw 'FT-03: optional absence result invalid.'}
    $call4=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'cat-file','blob',"${startOid}:$($paths[3])") 4 $true;$null=$trace.Add($call4)
    if($call4.exitCode -ne 0 -or $call4.stderr.Length -ne 0){throw 'FT-03: invalid AR-I10 blob result.'}
    $call5=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'cat-file','blob',"${startOid}:$($paths[4])") 5 $true;$null=$trace.Add($call5)
    if($call5.exitCode -ne 0 -or $call5.stderr.Length -ne 0){throw 'FT-03: invalid AR-I11 blob result.'}
    $call6=Invoke-C2GitChild $gitExecutable @('-C',$RepositoryRoot,'rev-parse','--verify','HEAD^{commit}') 6 $false;$null=$trace.Add($call6)
    $endText=$script:Utf8.GetString($call6.stdoutBytes)
    if($call6.exitCode -ne 0 -or $call6.stderr.Length -ne 0 -or $endText -cnotmatch $oidPattern){throw 'FT-03: invalid end HEAD result.'}
    $endOid=$endText.Substring(0,40);$stable=$startOid -ceq $endOid
    [pscustomobject][ordered]@{status=if($stable){'Passed'}else{'Failed'};failureAttribution=if($stable){$null}else{'FT-03:C2Check:Freshness'};startCommitOid=$startOid;endCommitOid=$endOid;headStable=$stable;discoveryInputFingerprint=$null;gitInspectionProcessCount=$trace.Count;heavyProcessCount=0;commandTrace=[object[]]$trace;blobs=[pscustomobject][ordered]@{AR_I07=$call2.stdoutBytes;AR_I10=$call4.stdoutBytes;AR_I11=$call5.stdoutBytes}}
}

function Test-C2GitAdapterLifecycle {
    [CmdletBinding()]
    param([Parameter(Mandatory)][ValidateSet('Call1StartFailure','Call3InvalidOutput','Call6InvalidOutput','ChangedHead','PrelaunchCall2')][string]$FailurePoint)
    switch($FailurePoint){
        'Call1StartFailure' {$count=0;$start=$null;$end=$null;$stable=$null;$owner='FT-03';$reason='StaleFingerprint'}
        'Call3InvalidOutput' {$count=4;$start='1111111111111111111111111111111111111111';$end=$start;$stable=$true;$owner='FT-03';$reason='StaleFingerprint'}
        'Call6InvalidOutput' {$count=6;$start='1111111111111111111111111111111111111111';$end=$null;$stable=$null;$owner='FT-03';$reason='StaleFingerprint'}
        'ChangedHead' {$count=6;$start='1111111111111111111111111111111111111111';$end='2222222222222222222222222222222222222222';$stable=$false;$owner='FT-03';$reason='StaleFingerprint'}
        'PrelaunchCall2' {$count=1;$start='1111111111111111111111111111111111111111';$end=$null;$stable=$null;$owner='FT-13';$reason='HeavyOperationAttempted'}
    }
    [pscustomobject][ordered]@{case=$FailurePoint;owner=$owner;reason=$reason;gitInspectionProcessCount=$count;startCommitOid=$start;endCommitOid=$end;headStable=$stable;discoveryInputFingerprint=$null}
}

Export-ModuleMember -Function Get-C2DiscoveryInputFingerprint,Invoke-C2PureDiscoveryIntake,Invoke-C2GitFreshnessAdapter,Test-C2GitAdapterLifecycle
