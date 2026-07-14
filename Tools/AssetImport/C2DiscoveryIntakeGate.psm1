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
$script:RequiredHashes=@('548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac','acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462','c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1','b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c','88314c4c150563cab2f08c4a0692bc012b0c8e6f403d5cf2a355cf1688831444','45a094d25b2e221f46f4f4948c0dae188d3a9a77aa520243f02fd8242038c449')

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

function Get-C2OrdinalUnique {
    param([object[]]$Values)
    $items=[Collections.Generic.List[string]]::new();foreach($value in $Values){if(-not $items.Contains([string]$value)){$items.Add([string]$value)}};$items.Sort($script:Ordinal);[string[]]$items
}

function Invoke-C2PureDiscoveryIntake {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object[]]$ArtifactFacts,
        [Parameter(Mandatory)][psobject]$HandoffFact,
        [AllowNull()][string]$StartCommitOid,
        [AllowNull()][string]$EndCommitOid,
        [bool]$FreshnessPrerequisiteAvailable = $true,
        [object[]]$ValidationFindings = @()
    )
    $failures=[Collections.Generic.List[object]]::new()
    $states=[Collections.Generic.List[object]]::new()
    $directOwner=$null
    $freshnessEvidence=[Collections.Generic.List[string]]::new()
    $artifactPrerequisiteFailed=$false
    $expectedFactNames=@('artifactId','path','requirement','presence','worktreeSha256','commitBlobSha256','manifestSha256')
    for($i=0;$i -lt $script:Registry.Count;$i++){
        $reg=$script:Registry[$i]; $fact=if($i -lt $ArtifactFacts.Count){$ArtifactFacts[$i]}else{$null}
        $shapeOk=($null -ne $fact) -and ((@($fact.PSObject.Properties.Name) -join ',') -ceq ($expectedFactNames -join ','))
        $identityOk=$shapeOk -and $fact.artifactId -ceq $reg.artifactId -and $fact.path -ceq $reg.path -and $fact.requirement -ceq $reg.requirement
        $safe=$shapeOk -and (Test-C2PortablePath ([string]$fact.path))
        $presence=if($shapeOk -and $fact.presence -ceq 'Absent'){'Absent'}else{'Present'}
        $requiredAbsent=$shapeOk -and $reg.requirement -ceq 'Required' -and $presence -ceq 'Absent'
        $finding=@($ValidationFindings|Where-Object artifactId -eq $reg.artifactId|Select-Object -First 1)
        $identityFailure=-not $shapeOk -or -not $identityOk -or $finding.Count -gt 0
        $pathFailure=$shapeOk -and -not $safe
        $shaOk=$shapeOk -and ($presence -eq 'Absent' -or $fact.worktreeSha256 -cmatch '^[0-9a-f]{64}$')
        if($i -lt 6){$shaOk=$shaOk -and $fact.worktreeSha256 -ceq $script:RequiredHashes[$i]}
        elseif($i -in @(6,7,10)){$shaOk=$shaOk -and $fact.worktreeSha256 -ceq $fact.commitBlobSha256 -and $fact.worktreeSha256 -ceq $fact.manifestSha256}
        elseif($i -eq 9){$shaOk=$shaOk -and $fact.worktreeSha256 -ceq $fact.commitBlobSha256}
        $freshnessFailure=$requiredAbsent -or ($shapeOk -and $identityOk -and $safe -and $finding.Count -eq 0 -and -not $shaOk)
        $failed=$identityFailure -or $pathFailure -or $freshnessFailure
        if($pathFailure){
            if($null -eq $directOwner){$directOwner='FT-04'}
            $failures.Add((New-C2AccountingRow inputFailures PublicProjection $reg.artifactId UnsafePath "FT-04:$($reg.artifactId)" @($reg.path)))
            $artifactPrerequisiteFailed=$true
        }elseif($identityFailure){
            if($null -eq $directOwner){$directOwner='FT-02'}
            $owner=if($finding.Count){$finding[0].transition}else{'FT-02'};$why=if($finding.Count){$finding[0].reason}else{'InvalidSchema'}
            $failures.Add((New-C2AccountingRow inputFailures SchemaDocument $reg.artifactId $why "${owner}:$($reg.artifactId)" @($reg.path)))
            $artifactPrerequisiteFailed=$true
        }elseif($freshnessFailure){
            if(-not $freshnessEvidence.Contains($reg.path)){$freshnessEvidence.Add($reg.path)}
        }
        $states.Add([pscustomobject][ordered]@{
            artifactId=$reg.artifactId; path=$reg.path; requirement=$reg.requirement; presence=$presence
            readStatus=if($failed){'Failed'}elseif($presence -ceq 'Absent'){'NotRead'}else{'Accepted'}
            worktreeSha256=if($shapeOk){$fact.worktreeSha256}else{$null}; commitBlobSha256=if($shapeOk){$fact.commitBlobSha256}else{$null}; manifestSha256=if($shapeOk){$fact.manifestSha256}else{$null}
            identityStatus=if($failed){'Failed'}elseif($presence -ceq 'Absent'){'NotApplicable'}else{'Accepted'}
            freshnessStatus=if($failed){'Failed'}else{'Accepted'}; evidence=@($reg.path)
        })
    }
    if($ArtifactFacts.Count -ne 11){
        if($null -eq $directOwner){$directOwner='FT-02'}
        $artifactPrerequisiteFailed=$true
        if($ArtifactFacts.Count -gt $script:Registry.Count -and -not @($failures|Where-Object{$_.subjectId -ceq 'AR-I10'}).Count){
            $failures.Add((New-C2AccountingRow inputFailures RegistryShape 'AR-I10' UnexpectedRegistrySlot 'FT-02:AR-I10' @($script:Registry[9].path)))
        }
    }
    $handoffNames=@('snapshotId','ledgerPath','summaryPath')
    $handoffOk=((@($HandoffFact.PSObject.Properties.Name) -join ',') -ceq ($handoffNames -join ',')) -and ($HandoffFact.snapshotId -ceq 'snapshot-pc-install-001') -and ($HandoffFact.ledgerPath -ceq $script:Registry[1].path) -and ($HandoffFact.summaryPath -ceq $script:Registry[2].path)
    if(-not $handoffOk){
        if($null -eq $directOwner){$directOwner='FT-01'}
        $failures.Add((New-C2AccountingRow inputFailures C1Handoff 'C2Check:C1Handoff' IdentityMismatch 'FT-01:C2Check:C1Handoff' @($script:Registry[0].path)))
    }
    $startOidValid=$null -ne $StartCommitOid -and $StartCommitOid -cmatch '^[0-9a-f]{40}$'
    $endOidValid=$null -ne $EndCommitOid -and $EndCommitOid -cmatch '^[0-9a-f]{40}$'
    $headStable=if($startOidValid -and $endOidValid){$StartCommitOid -ceq $EndCommitOid}else{$null}
    if(-not $startOidValid){$freshnessEvidence.Add('GitAdapter:StartCommitOid')}
    if(-not $endOidValid -or $headStable -eq $false){$freshnessEvidence.Add('GitAdapter:EndHead')}
    if($freshnessEvidence.Count -gt 0){
        if($null -eq $directOwner){$directOwner='FT-03'}
        $failures.Add((New-C2AccountingRow inputFailures FreshnessCheck 'C2Check:Freshness' StaleFingerprint 'FT-03:C2Check:Freshness' ([string[]]$freshnessEvidence)))
    }
    $checks=[Collections.Generic.List[object]]::new()
    $checks.Add((New-C2Check 'C2Check:LightweightPolicy' Accepted 'Accepted:C2Check:LightweightPolicy' @('Tools/AssetImport/C2DiscoveryIntakeGate.psm1','Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1') @()))
    $checks.Add((New-C2Check 'C2Check:C1Handoff' $(if($handoffOk){'Accepted'}else{'Failed'}) $(if($handoffOk){'Accepted:C2Check:C1Handoff'}else{'FT-01:C2Check:C1Handoff'}) @($script:Registry[1].path,$script:Registry[0].path,$script:Registry[2].path) @('AR-I01','AR-I02','AR-I03')))
    $freshAccepted=$handoffOk -and $FreshnessPrerequisiteAvailable -and -not $artifactPrerequisiteFailed -and $freshnessEvidence.Count -eq 0
    $freshStatus=if($freshAccepted){'Accepted'}elseif(-not $handoffOk -or -not $FreshnessPrerequisiteAvailable -or $artifactPrerequisiteFailed){'NotEvaluated'}else{'Failed'}
    $checks.Add((New-C2Check 'C2Check:Freshness' $freshStatus $(if($freshStatus -ceq 'Accepted'){'Accepted:C2Check:Freshness'}elseif($freshStatus -ceq 'NotEvaluated'){'FT-15:C2Check:Freshness'}else{'FT-03:C2Check:Freshness'}) (Get-C2OrdinalUnique @($script:Registry.path)) @('AR-I01','AR-I02','AR-I03','AR-I04','AR-I05','AR-I06','AR-I07','AR-I08','AR-I09','AR-I10','AR-I11','GitAdapter:EndHead','GitAdapter:StartCommitOid')))
    $checks.Add((New-C2Check 'C2Check:Conservation' NotEvaluated 'FT-15:C2Check:Conservation' @() @('Stage:C2Partitions')))
    $checks.Add((New-C2Check 'C2Check:PublicProjection' NotEvaluated 'FT-15:C2Check:PublicProjection' @($script:Registry[5].path) @('AR-O01','AR-O02','AR-O03','AR-O04','AR-O05')))
    $suppressions=[Collections.Generic.List[object]]::new()
    if($freshStatus -ceq 'NotEvaluated'){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Freshness' PrerequisiteUnavailable 'FT-15:C2Check:Freshness' @()))}
    $suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Conservation' PrerequisiteUnavailable 'FT-15:C2Check:Conservation' @()))
    $suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:PublicProjection' PrerequisiteUnavailable 'FT-15:C2Check:PublicProjection' @($script:Registry[5].path)))
    $read=@($states|Where-Object presence -eq 'Present'); $accepted=@($read|Where-Object readStatus -eq 'Accepted'); $failed=@($read|Where-Object readStatus -eq 'Failed')
    $acceptedChecks=@($checks|Where-Object status -eq 'Accepted');$failedChecks=@($checks|Where-Object status -eq 'Failed');$neChecks=@($checks|Where-Object status -eq 'NotEvaluated')
    $fingerprint=$null
    if($failures.Count -eq 0 -and $freshStatus -ceq 'Accepted'){$fingerprint=Get-C2DiscoveryInputFingerprint -Entries @($accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})}
    $next=if($failures.Count -eq 0){'Implement SP-01/SP-02 in a separately approved fixture-only slice.'}elseif($directOwner -ceq 'FT-01'){'Fix C1 handoff fixture'}elseif($directOwner -ceq 'FT-04'){'Fix portable path'}else{'Fix reviewed registry shape'}
    $o1=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=if($handoffOk){$HandoffFact.snapshotId}else{$null};startCommitOid=$StartCommitOid;endCommitOid=$EndCommitOid;headStable=$headStable;discoveryInputFingerprint=$fingerprint;artifactStates=[object[]]$states;contractChecks=[object[]]$checks;inputFailures=[object[]]$failures;inputExclusions=@();inputSuppressions=[object[]]$suppressions;decision=[pscustomobject][ordered]@{failureAttribution=if($failures.Count -eq 0){'None; intake and freshness checks passed; deferred checks remain NotEvaluated.'}else{$failures[0].attribution};nextAllowedAction=$next}}
    $failedSlots=@($states|Where-Object readStatus -eq Failed).Count
    $inputSubjects=$read.Count+5
    $o2=[pscustomobject][ordered]@{status=if($failures.Count -eq 0){'Passed'}else{'Failed'};issueCount=$failures.Count;registeredArtifactCount=11;readArtifactCount=$read.Count;requiredArtifactCount=@($states|Where-Object requirement -eq Required).Count;presentOptionalArtifactCount=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Present'}).Count;absentOptionalArtifactCount=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Absent'}).Count;failedRegistrySlotCount=$failedSlots;acceptedArtifactCount=$accepted.Count;failedArtifactCount=$failed.Count;contractCheckCount=5;acceptedCheckCount=$acceptedChecks.Count;failedCheckCount=$failedChecks.Count;notEvaluatedCheckCount=$neChecks.Count;inputSubjectCount=$inputSubjects;acceptedInputSubjectCount=$accepted.Count+$acceptedChecks.Count;inputFailureCount=$failures.Count;excludedInputSubjectCount=0;notEvaluatedInputSubjectCount=$neChecks.Count;gitInspectionProcessCount=0;heavyProcessCount=0;realAssetReadCount=0;createdExtractedCount=0;createdImportedCount=0;startCommitOid=$StartCommitOid;endCommitOid=$EndCommitOid;headStable=$headStable;discoveryInputFingerprint=$fingerprint;nextAllowedAction=$next}
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
    [pscustomobject][ordered]@{callNumber=$CallNumber;started=$true;prelaunchRejected=$false;arguments=$Arguments;exitCode=$exitCode;stdoutBytes=$bytes;stderr=$stderr;environmentValid=$true;useShellExecute=$false;redirectStandardOutput=$true;redirectStandardError=$true;rawBlobCapture=$RawBlobCapture;stdoutByteCount=$bytes.Length}
}

function Invoke-C2GitProtocol {
    param([string]$RepositoryRoot,[AllowNull()][scriptblock]$Transport,[AllowNull()][string]$GitExecutable,[AllowNull()][scriptblock]$BeforeFinalHead)
    $trace=[Collections.Generic.List[object]]::new();$start=$null;$end=$null;$owner=$null;$reason=$null;$validation=$null
    $paths=@($script:Registry[6].path,$script:Registry[7].path,$script:Registry[8].path,$script:Registry[9].path,$script:Registry[10].path)
    function Invoke-ProtocolCall([int]$Number,[string[]]$Arguments,[bool]$Raw){
        if($null -ne $Transport){$response=@($Transport.Invoke($Number,$Arguments,$Raw))[0]}
        else{try{$response=Invoke-C2GitChild $GitExecutable $Arguments $Number $Raw}catch{$response=[pscustomobject]@{callNumber=$Number;started=$false;prelaunchRejected=$false;exitCode=$null;stdoutBytes=[byte[]]@();stderr=$_.Exception.Message}}}
        if($response.started){$null=$trace.Add($response)}
        return $response
    }
    $c1=Invoke-ProtocolCall 1 @('-C',$RepositoryRoot,'rev-parse','--verify','HEAD^{commit}') $false
    if($c1.prelaunchRejected){$owner='FT-13';$reason='HeavyOperationAttempted'}
    elseif(-not $c1.started -or $c1.exitCode -ne 0 -or $c1.stderr.Length -ne 0 -or $script:Utf8.GetString($c1.stdoutBytes) -cnotmatch "^[0-9a-f]{40}`n$"){$owner='FT-03';$reason='StaleFingerprint'}
    else{$start=$script:Utf8.GetString($c1.stdoutBytes).Substring(0,40)}
    $calls=@()
    if($null -eq $owner){
        $calls=@(
            @(2,@('-C',$RepositoryRoot,'cat-file','blob',"${start}:$($paths[0])"),$true),
            @(3,@('-C',$RepositoryRoot,'cat-file','blob',"${start}:$($paths[1])"),$true),
            @(4,@('-C',$RepositoryRoot,'ls-tree','-z','--full-tree',$start,'--',$paths[2]),$false),
            @(5,@('-C',$RepositoryRoot,'cat-file','blob',"${start}:$($paths[3])"),$true),
            @(6,@('-C',$RepositoryRoot,'cat-file','blob',"${start}:$($paths[4])"),$true)
        )
        foreach($spec in $calls){
            $c=Invoke-ProtocolCall $spec[0] $spec[1] $spec[2]
            $valid=$c.started -and $c.exitCode -eq 0 -and $c.stderr.Length -eq 0 -and ($spec[0] -ne 4 -or $c.stdoutBytes.Length -eq 0)
            if($c.prelaunchRejected){$owner='FT-13';$reason='HeavyOperationAttempted';break}
            if(-not $valid){$owner='FT-03';$reason='StaleFingerprint';break}
        }
    }
    if($null -eq $owner -and $null -ne $BeforeFinalHead){
        try{$validation=@($BeforeFinalHead.Invoke([pscustomobject]@{trace=[object[]]$trace}))[0]}catch{$validation=[pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';message=$_.Exception.Message}}
        if($validation.status -cne 'Passed'){$owner=$validation.owner;$reason=$validation.reason}
    }
    if($null -ne $start -and $owner -ne 'FT-13'){
        $c7=Invoke-ProtocolCall 7 @('-C',$RepositoryRoot,'rev-parse','--verify','HEAD^{commit}') $false
        if($c7.prelaunchRejected){$owner='FT-13';$reason='HeavyOperationAttempted'}
        elseif($c7.started -and $c7.exitCode -eq 0 -and $c7.stderr.Length -eq 0 -and $script:Utf8.GetString($c7.stdoutBytes) -cmatch "^[0-9a-f]{40}`n$"){$end=$script:Utf8.GetString($c7.stdoutBytes).Substring(0,40);if($start -cne $end){$owner='FT-03';$reason='StaleFingerprint'}}
        else{$owner='FT-03';$reason='StaleFingerprint'}
    }
    $stable=if($null -ne $start -and $null -ne $end){$start -ceq $end}else{$null}
    [pscustomobject][ordered]@{status=if($null -eq $owner){'Passed'}else{'Failed'};owner=$owner;reason=$reason;failureAttribution=if($owner){"${owner}:C2Check:$(if($owner -eq 'FT-13'){'LightweightPolicy'}else{'Freshness'})"}else{$null};startCommitOid=$start;endCommitOid=$end;headStable=$stable;discoveryInputFingerprint=$null;gitInspectionProcessCount=$trace.Count;heavyProcessCount=0;commandTrace=[object[]]$trace;validation=$validation}
}

function Invoke-C2GitFreshnessAdapter {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot)
    $gitExecutable=(Get-Command git.exe -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
    if(-not [IO.Path]::IsPathFullyQualified($gitExecutable)){throw 'FT-13: git executable is not absolute.'}
    Invoke-C2GitProtocol -RepositoryRoot $RepositoryRoot -Transport $null -GitExecutable $gitExecutable
}

function Test-C2GitAdapterLifecycle {
    [CmdletBinding()]param([Parameter(Mandatory)][ValidateSet('Call1StartFailure','Call3InvalidOutput','Call7InvalidOutput','ChangedHead','PrelaunchCall2')][string]$FailurePoint)
    $oid1='1111111111111111111111111111111111111111';$oid2='2222222222222222222222222222222222222222'
    $fakeTransport={param($number,$arguments,$raw)
        if($FailurePoint -eq 'PrelaunchCall2' -and $number -eq 2){return [pscustomobject]@{callNumber=$number;started=$false;prelaunchRejected=$true;exitCode=$null;stdoutBytes=[byte[]]@();stderr=''} }
        if($FailurePoint -eq 'Call1StartFailure' -and $number -eq 1){return [pscustomobject]@{callNumber=$number;started=$false;prelaunchRejected=$false;exitCode=$null;stdoutBytes=[byte[]]@();stderr='start failure'} }
        $text=if($number -in @(1,7)){if($FailurePoint -eq 'ChangedHead' -and $number -eq 7){"$oid2`n"}else{"$oid1`n"}}elseif($number -eq 4){''}else{'blob'}
        $exit=if(($FailurePoint -eq 'Call3InvalidOutput' -and $number -eq 3)-or($FailurePoint -eq 'Call7InvalidOutput' -and $number -eq 7)){1}else{0}
        $encoding=[Text.UTF8Encoding]::new($false)
        [pscustomobject]@{callNumber=$number;started=$true;prelaunchRejected=$false;exitCode=$exit;stdoutBytes=$encoding.GetBytes($text);stderr='';arguments=$arguments;environmentValid=$true;useShellExecute=$false;redirectStandardOutput=$true;redirectStandardError=$true;rawBlobCapture=$raw;stdoutByteCount=$encoding.GetByteCount($text)}
    }.GetNewClosure()
    $r=Invoke-C2GitProtocol 'C:\repo' $fakeTransport
    [pscustomobject][ordered]@{case=$FailurePoint;owner=$r.owner;reason=$r.reason;gitInspectionProcessCount=$r.gitInspectionProcessCount;startCommitOid=$r.startCommitOid;endCommitOid=$r.endCommitOid;headStable=$r.headStable;discoveryInputFingerprint=$r.discoveryInputFingerprint}
}

function Read-C2AuditedArtifactBytes {
    param([string]$RepositoryRoot,[string]$PortablePath)
    $registered=@($script:Registry.path)
    if($registered -cnotcontains $PortablePath){throw "FT-13: unregistered read rejected: $PortablePath"}
    if(-not (Test-C2PortablePath $PortablePath)){throw "FT-04: unsafe registered path: $PortablePath"}
    $root=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    $full=[IO.Path]::GetFullPath([IO.Path]::Combine($RepositoryRoot,$PortablePath.Replace('/',[IO.Path]::DirectorySeparatorChar)))
    if(-not $full.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw "FT-13: read escaped repository root: $PortablePath"}
    return [IO.File]::ReadAllBytes($full)
}

function New-C2FailedIntakeResult {
    param([string]$Owner,[string]$Reason,[AllowNull()]$StartOid,[AllowNull()]$EndOid,$HeadStable,[int]$GitCount,[int]$HeavyCount,[string]$SubjectId='C2Check:Freshness',[AllowNull()][string]$RepositoryRoot)
    $subjectKind=if($Owner -eq 'FT-13'){'LightweightPolicy'}elseif($Owner -eq 'FT-01'){'C1Handoff'}elseif($Owner -eq 'FT-02'){'SchemaDocument'}else{'FreshnessCheck'}
    if($Owner -eq 'FT-13'){$SubjectId='C2Check:LightweightPolicy'}elseif($Owner -eq 'FT-01'){$SubjectId='C2Check:C1Handoff'}
    $failure=New-C2AccountingRow inputFailures $subjectKind $SubjectId $Reason "${Owner}:$SubjectId" @()
    $states=foreach($reg in $script:Registry){$present=$false;if($RepositoryRoot){$present=[IO.File]::Exists([IO.Path]::Combine($RepositoryRoot,$reg.path.Replace('/',[IO.Path]::DirectorySeparatorChar)))};[pscustomobject][ordered]@{artifactId=$reg.artifactId;path=$reg.path;requirement=$reg.requirement;presence=if($present){'Present'}else{'Absent'};readStatus='NotRead';worktreeSha256=$null;commitBlobSha256=$null;manifestSha256=$null;identityStatus='NotApplicable';freshnessStatus='Failed';evidence=@($reg.path)}}
    $lightStatus=if($Owner -eq 'FT-13'){'Failed'}else{'Accepted'};$handoffStatus=if($Owner -eq 'FT-01'){'Failed'}else{'Accepted'}
    $freshStatus=if($Owner -in @('FT-13','FT-01','FT-02')){'NotEvaluated'}elseif($Owner -eq 'FT-03'){'Failed'}else{'NotEvaluated'}
    $checks=@(
        (New-C2Check 'C2Check:LightweightPolicy' $lightStatus $(if($lightStatus -eq 'Failed'){'FT-13:C2Check:LightweightPolicy'}else{'Accepted:C2Check:LightweightPolicy'}) @() @()),
        (New-C2Check 'C2Check:C1Handoff' $handoffStatus $(if($handoffStatus -eq 'Failed'){'FT-01:C2Check:C1Handoff'}else{'Accepted:C2Check:C1Handoff'}) @() @('AR-I01','AR-I02','AR-I03')),
        (New-C2Check 'C2Check:Freshness' $freshStatus $(if($freshStatus -eq 'Failed'){'FT-03:C2Check:Freshness'}else{'FT-15:C2Check:Freshness'}) @() @('GitAdapter:StartCommitOid','GitAdapter:EndHead')),
        (New-C2Check 'C2Check:Conservation' NotEvaluated 'FT-15:C2Check:Conservation' @() @('Stage:C2Partitions')),
        (New-C2Check 'C2Check:PublicProjection' NotEvaluated 'FT-15:C2Check:PublicProjection' @($script:Registry[5].path) @('AR-O01','AR-O02','AR-O03','AR-O04','AR-O05'))
    )
    $suppressions=[Collections.Generic.List[object]]::new()
    foreach($check in $checks|Where-Object status -eq NotEvaluated){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck $check.subjectId PrerequisiteUnavailable "FT-15:$($check.subjectId)" $check.evidence))}
    $acceptedChecks=@($checks|Where-Object status -eq Accepted).Count;$failedChecks=@($checks|Where-Object status -eq Failed).Count;$notEvaluated=@($checks|Where-Object status -eq NotEvaluated).Count
    $next=if($Owner -eq 'FT-13'){'Remove unsafe operation'}elseif($Owner -eq 'FT-01'){'Fix C1 handoff fixture'}elseif($Owner -eq 'FT-02'){'Fix reviewed registry shape'}else{'Restore reviewed frozen-commit bytes and stable HEAD'}
    $o1=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$null;startCommitOid=$StartOid;endCommitOid=$EndOid;headStable=$HeadStable;discoveryInputFingerprint=$null;artifactStates=[object[]]$states;contractChecks=[object[]]$checks;inputFailures=@($failure);inputExclusions=@();inputSuppressions=[object[]]$suppressions;decision=[pscustomobject][ordered]@{failureAttribution=$failure.attribution;nextAllowedAction=$next}}
    $presentSlots=@($states|Where-Object presence -eq Present).Count;$absentOptional=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Absent'}).Count
    $o2=[pscustomobject][ordered]@{status='Failed';issueCount=1;registeredArtifactCount=11;readArtifactCount=0;requiredArtifactCount=6;presentOptionalArtifactCount=@($states|Where-Object{$_.requirement -ne 'Required' -and $_.presence -eq 'Present'}).Count;absentOptionalArtifactCount=$absentOptional;failedRegistrySlotCount=$presentSlots;acceptedArtifactCount=0;failedArtifactCount=0;contractCheckCount=5;acceptedCheckCount=$acceptedChecks;failedCheckCount=$failedChecks;notEvaluatedCheckCount=$notEvaluated;inputSubjectCount=5;acceptedInputSubjectCount=$acceptedChecks;inputFailureCount=1;excludedInputSubjectCount=0;notEvaluatedInputSubjectCount=$notEvaluated;gitInspectionProcessCount=$GitCount;heavyProcessCount=$HeavyCount;realAssetReadCount=0;createdExtractedCount=0;createdImportedCount=0;startCommitOid=$StartOid;endCommitOid=$EndOid;headStable=$HeadStable;discoveryInputFingerprint=$null;nextAllowedAction=$next}
    [pscustomobject][ordered]@{O1=$o1;O2=$o2}
}

function Add-C2SetFrame {
    param([string]$Name,[object[]]$Values)
    $items=[Collections.Generic.List[string]]::new();foreach($v in $Values){if(-not $items.Contains([string]$v)){$items.Add([string]$v)}};$items.Sort($script:Ordinal)
    $count=[string]$items.Count;$text="${Name}.count:$($script:Utf8.GetByteCount($count)):$count`n";for($i=0;$i -lt $items.Count;$i++){$text+=ConvertTo-C2ScalarLine "${Name}[$i]" $items[$i]};$text
}

function Add-C2NullableFrame {
    param([string]$Name,$Value)
    if($null -eq $Value){return "${Name}.null:1:1`n"}
    "${Name}.null:1:0`n$(ConvertTo-C2ScalarLine $Name ([string]$Value))"
}

function Get-C2ObservationId {
    param($Row)
    $dependencyIds=@($Row.dependencyLocators|ForEach-Object{$_.locatorId})
    $canonicalDigest=if($null -eq $Row.canonicalEvidence){$null}else{[string]$Row.canonicalEvidence.digest}
    $text="C2ObjectObservationV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $Row.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$Row.pathId))+(ConvertTo-C2ScalarLine classId ([string]$Row.classId))+(ConvertTo-C2ScalarLine serializedSizeBytes ([string]$Row.serializedSizeBytes))+(ConvertTo-C2ScalarLine objectType $Row.objectType)+(ConvertTo-C2ScalarLine objectName $Row.objectName)+(Add-C2SetFrame dependencyLocatorIds $dependencyIds)+(ConvertTo-C2ScalarLine contentFingerprint $Row.contentFingerprint)+(Add-C2NullableFrame configurationDisposition $Row.configurationDisposition)+(Add-C2NullableFrame canonicalEvidenceDigest $canonicalDigest)+(ConvertTo-C2ScalarLine correlationId $Row.correlationEvidence.correlationId)+(Add-C2SetFrame evidence @($Row.evidence))
    "observation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2FileDiscoveryObservationId {
    param($Row)
    $text="C2FileDiscoveryObservationV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine relativePath $Row.relativePath)+(ConvertTo-C2ScalarLine outcome $Row.outcome)+(Add-C2SetFrame evidence @($Row.evidence))
    "file-discovery-observation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2ApprovalId {
    param($Approval)
    $text="C2ExclusionApprovalV1`n"+(ConvertTo-C2ScalarLine subjectKind $Approval.subjectKind)+(ConvertTo-C2ScalarLine subjectId $Approval.subjectId)+(ConvertTo-C2ScalarLine reasonCode $Approval.reasonCode)+(ConvertTo-C2ScalarLine reason $Approval.reason)+(ConvertTo-C2ScalarLine approvedBy $Approval.approvedBy)+(ConvertTo-C2ScalarLine approvedAt $Approval.approvedAt)+(Add-C2SetFrame evidence @($Approval.evidence))
    "exclusion-approval-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Test-C2SchemaNode {
    param([AllowNull()]$Node,[psobject]$Definitions)
    $pending=[Collections.Generic.Stack[object]]::new();$pending.Push($Node)
    while($pending.Count -gt 0){
        $current=$pending.Pop()
        if($null -eq $current -or $current -isnot [pscustomobject]){return $false}
        $names=@($current.PSObject.Properties.Name)
        if(@($names|Where-Object{$_ -in @('type','$ref','enum','const','oneOf','anyOf','allOf')}).Count -eq 0){return $false}
        if($names -contains 'type'){
            $allowedTypes=@('array','boolean','integer','null','number','object','string');$declaredTypes=@($current.type)
            if($declaredTypes.Count -eq 0){return $false}
            foreach($declaredType in $declaredTypes){if($declaredType -isnot [string] -or $allowedTypes -cnotcontains $declaredType){return $false}}
        }
        if($names -contains 'enum' -and @($current.enum).Count -eq 0){return $false}
        if($names -contains 'additionalProperties' -and $current.additionalProperties -isnot [bool]){return $false}
        foreach($integerKeyword in @('minItems','minLength')){
            if($names -contains $integerKeyword -and ($current.$integerKeyword -isnot [int] -and $current.$integerKeyword -isnot [long] -or [long]$current.$integerKeyword -lt 0)){return $false}
        }
        if($names -contains 'minimum' -and $current.minimum -isnot [byte] -and $current.minimum -isnot [sbyte] -and $current.minimum -isnot [short] -and $current.minimum -isnot [ushort] -and $current.minimum -isnot [int] -and $current.minimum -isnot [uint] -and $current.minimum -isnot [long] -and $current.minimum -isnot [ulong] -and $current.minimum -isnot [float] -and $current.minimum -isnot [double] -and $current.minimum -isnot [decimal]){return $false}
        if($names -contains 'uniqueItems' -and $current.uniqueItems -isnot [bool]){return $false}
        if($names -contains 'format' -and ($current.format -isnot [string] -or [string]::IsNullOrEmpty($current.format))){return $false}
        if($names -contains 'pattern'){
            if($current.pattern -isnot [string]){return $false}
            try{$null=[regex]::new($current.pattern)}catch{return $false}
        }
        if($names -contains '$ref'){
            $reference=[string]$current.'$ref';$definitionName=if($reference.Length -gt 8){$reference.Substring(8)}else{''}
            if($reference -cnotmatch '^#/\$defs/[^/]+$' -or @($Definitions.PSObject.Properties.Name) -cnotcontains $definitionName){return $false}
        }
        if($names -contains 'required'){
            $required=@($current.required);$seen=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
            if($required.Count -eq 0 -or $null -eq $current.properties -or $current.properties -isnot [pscustomobject]){return $false}
            foreach($requiredName in $required){if($requiredName -isnot [string] -or -not $seen.Add($requiredName) -or @($current.properties.PSObject.Properties.Name) -cnotcontains $requiredName){return $false}}
        }
        if($names -contains 'properties'){
            if($null -eq $current.properties -or $current.properties -isnot [pscustomobject]){return $false}
            foreach($property in $current.properties.PSObject.Properties){$pending.Push($property.Value)}
        }
        if($names -contains 'items'){$pending.Push($current.items)}
        foreach($keyword in @('oneOf','anyOf','allOf')){if($names -contains $keyword){$options=@($current.$keyword);if($options.Count -eq 0){return $false};foreach($option in $options){$pending.Push($option)}}}
    }
    return $true
}

function Test-C2SchemaDocument {
    param($Schema)
    if($Schema.type -cne 'object' -or $Schema.additionalProperties -ne $false -or $null -eq $Schema.properties -or $Schema.properties -isnot [pscustomobject] -or $null -eq $Schema.'$defs' -or $Schema.'$defs' -isnot [pscustomobject] -or @($Schema.'$defs'.PSObject.Properties).Count -eq 0 -or [string]$Schema.'$schema' -cnotmatch '^https://json-schema.org/' -or [string]$Schema.'$id' -cnotmatch '^https://'){return $false}
    if(-not(Test-C2SchemaNode $Schema $Schema.'$defs')){return $false}
    foreach($definition in $Schema.'$defs'.PSObject.Properties){if(-not(Test-C2SchemaNode $definition.Value $Schema.'$defs')){return $false}}
    return $true
}

function Test-C2FixtureContracts {
    param($Documents,$Hashes)
    $top=[ordered]@{
        'AR-I01'='schemaVersion,ledgerPath,summaryPath,snapshotId,inputFingerprint,sourceCount,fileCount,fileBytes,objectCount'
        'AR-I02'='schemaVersion,snapshotId,generatedAt,inputFingerprint,toolVersions,sources,files,objects'
        'AR-I03'='schemaVersion,generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,ledgerPath,toolVersions,operationIdentity,directChildSummaries,directChildReports,failureAttribution,nextAllowedAction,sourceCount,sourceFileCount,catalogedFileCount,explicitlyExcludedFileCount,sourceBytes,catalogedBytes,explicitlyExcludedBytes,sources,exclusions'
        'AR-I04'='$schema,$id,title,type,required,additionalProperties,properties,$defs'
        'AR-I05'='schemaVersion,generatedAt,corpus,extraction,semantics,configurationDisposition,unity,disposition,familyStaticOutcome,sourceKind'
        'AR-I06'='$schema,$id,title,type,required,additionalProperties,properties,$defs'
        'AR-I07'='schemaVersion,snapshotId,inputFingerprint,rows'
        'AR-I08'='schemaVersion,snapshotId,inputFingerprint,rows'
        'AR-I10'='schemaVersion,snapshotId,inputFingerprint,entries'
        'AR-I11'='schemaVersion,snapshotId,inputFingerprint,observationArtifactPath,observationArtifactSha256,approvals'
    }
    foreach($id in $top.Keys){if((@($Documents[$id].PSObject.Properties.Name)-join ',') -cne $top[$id]){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message="$id top-level shape"}}}
    foreach($id in @('AR-I04','AR-I06')){if(-not(Test-C2SchemaDocument $Documents[$id])){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message="$id schema document semantics"}}}
    try{$ledgerJson=$Documents['AR-I02']|ConvertTo-Json -Depth 100 -Compress;$ledgerSchema=$Documents['AR-I04']|ConvertTo-Json -Depth 100 -Compress;if(-not($ledgerJson|Test-Json -Schema $ledgerSchema -ErrorAction Stop)){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I02';message='ledger schema'}}}catch{return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I02';message="ledger schema: $($_.Exception.Message)"}}
    $expectedVocabulary=[ordered]@{corpus='Cataloged,Missing,StaleInput';extraction='NotAttempted,ExtractedReadable,CrossToolVerified,Opaque,Failed';semantics='Known,PartiallyKnown,Unknown';configurationDisposition='Parsed,DiscoveredOpaque,Encrypted,RequiresRuntimeType,LikelyServerDependent,NotConfiguration';unity='NotTested,StaticQualified,RepresentativeValidated,Rejected,UnityExecutionUnavailable';disposition='NeedsDiagnosis,UseOriginalAsset,RepairOnce,PrototypeReplacement,RetainForLater,DiagnosticOnly,Stop';familyStaticOutcome='StaticQualified,StaticRejected,NeedsDiagnosis';sourceKind='PcInstall,PcPatchOrCache,AndroidApk,AndroidDataOrCache'}
    foreach($name in $expectedVocabulary.Keys){if((@($Documents['AR-I05'].$name)-join ',') -cne $expectedVocabulary[$name]){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I05';message="vocabulary $name"}}}
    $snapshot=$Documents['AR-I01'].snapshotId;$fingerprint=$Documents['AR-I01'].inputFingerprint
    if($snapshot -cne 'snapshot-pc-install-001' -or $Documents['AR-I01'].ledgerPath -cne $script:Registry[1].path -or $Documents['AR-I01'].summaryPath -cne $script:Registry[2].path){return [pscustomobject]@{status='Failed';owner='FT-01';reason='IdentityMismatch';subjectId='C2Check:C1Handoff';message='handoff identity'}}
    foreach($id in @('AR-I02','AR-I03','AR-I07','AR-I08','AR-I10','AR-I11')){if($Documents[$id].snapshotId -cne $snapshot){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message='snapshot mismatch'}}}
    foreach($id in @('AR-I02','AR-I03','AR-I07','AR-I08','AR-I10','AR-I11')){if($Documents[$id].inputFingerprint -cne $fingerprint){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message='input fingerprint mismatch'}}}
    $rowKeys='observationId,toolName,toolVersion,sourceId,containerRelativePath,pathId,classId,serializedSizeBytes,objectType,objectName,dependencyLocators,contentFingerprint,configurationDisposition,canonicalEvidence,correlationEvidence,evidence';$rows=@($Documents['AR-I07'].rows)
    if($rows.Count -ne 6){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I07';message='row count'}}
    for($i=0;$i -lt 6;$i++){
        if((@($rows[$i].PSObject.Properties.Name)-join ',') -cne $rowKeys){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I07';message='row shape'}}
        if($i -eq 4){if($null -ne $rows[$i].observationId -or [int]$rows[$i].classId -ge 0){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I07';message='r5 counterexample'}}}
        elseif($rows[$i].observationId -cne (Get-C2ObservationId $rows[$i])){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I07';message="HI-03 row $i"}}
    }
    $fileRowKeys='fileDiscoveryObservationId,toolName,toolVersion,sourceId,relativePath,outcome,evidence';$fileRows=@($Documents['AR-I08'].rows)
    if($fileRows.Count -ne 2){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I08';message='file row count'}}
    foreach($row in $fileRows){if((@($row.PSObject.Properties.Name)-join ',') -cne $fileRowKeys -or $row.outcome -cnotin @('Readable','Opaque','Failed') -or @($row.evidence).Count -eq 0 -or $row.fileDiscoveryObservationId -cne (Get-C2FileDiscoveryObservationId $row)){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I08';message='file observation shape/HI-06'}}}
    $entries=@($Documents['AR-I10'].entries);if($entries.Count -ne 3 -or (@($entries[0].PSObject.Properties.Name)-join ',') -cne 'path,sha256' -or (@($entries[1].PSObject.Properties.Name)-join ',') -cne 'path,sha256' -or (@($entries[2].PSObject.Properties.Name)-join ',') -cne 'path,sha256' -or $entries[0].path -cne $script:Registry[10].path -or $entries[0].sha256 -cne $Hashes['AR-I11'] -or $entries[1].path -cne $script:Registry[7].path -or $entries[1].sha256 -cne $Hashes['AR-I08'] -or $entries[2].path -cne $script:Registry[6].path -or $entries[2].sha256 -cne $Hashes['AR-I07']){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I10';message='manifest shape/binding'}}
    if($Documents['AR-I11'].observationArtifactPath -cne $script:Registry[6].path -or $Documents['AR-I11'].observationArtifactSha256 -cne $Hashes['AR-I07']){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I11';message='approval artifact binding'}}
    $approvals=@($Documents['AR-I11'].approvals);if($approvals.Count -ne 1){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I11';message='approval count'}};$approval=$approvals[0]
    if((@($approval.PSObject.Properties.Name)-join ',') -cne 'approvalId,subjectKind,subjectId,reasonCode,reason,approvedBy,approvedAt,evidence' -or $approval.subjectId -cne $rows[5].observationId -or $approval.approvalId -cne (Get-C2ApprovalId $approval)){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I11';message='HI-15/subject binding'}}
    [pscustomobject]@{status='Passed';owner=$null;reason=$null;subjectId=$null;message=$null}
}

function Invoke-C2DiscoveryIntakeGateInternal {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepositoryRoot,[AllowNull()][scriptblock]$GitTransport,[AllowNull()][scriptblock]$FixtureMutator)
    $requiredHashes=@(
        '548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac',
        'acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462',
        'c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1',
        'b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c',
        '88314c4c150563cab2f08c4a0692bc012b0c8e6f403d5cf2a355cf1688831444',
        '45a094d25b2e221f46f4f4948c0dae188d3a9a77aa520243f02fd8242038c449'
    )
    $gitExecutable=if($null -eq $GitTransport){(Get-Command git.exe -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source}else{$null}
    if($null -eq $GitTransport -and -not [IO.Path]::IsPathFullyQualified($gitExecutable)){return New-C2FailedIntakeResult FT-13 HeavyOperationAttempted $null $null $null 0 0}
    $context=[ordered]@{facts=$null;handoff=$null;events=[Collections.Generic.List[object]]::new();extractedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Extracted'));importedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Assets','StellaGaia','Imported'))}
    $registry=$script:Registry;$utf8=$script:Utf8;$fixtureValidator=${function:Test-C2FixtureContracts};$fixtureMutation=$FixtureMutator
    $hashBytes={param([byte[]]$value)[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($value)).ToLowerInvariant()}.GetNewClosure()
    $validation={param($bundle)
        try{
            $traceRows=@($bundle.trace)
            foreach($absentIndex in @(8)){
                $candidate=[IO.Path]::Combine($RepositoryRoot,$registry[$absentIndex].path.Replace('/',[IO.Path]::DirectorySeparatorChar))
                $null=$context.events.Add([pscustomobject]@{kind='RegisteredPathProbe';path=$registry[$absentIndex].path})
                if([IO.File]::Exists($candidate)){return [pscustomobject]@{status='Failed';owner='FT-03';reason='StaleFingerprint';message="unexpected worktree presence: $($registry[$absentIndex].artifactId)"}}
            }
            $bytes=[ordered]@{};foreach($index in @(0,1,2,3,4,5,6,7,9,10)){$bytes[$registry[$index].artifactId]=[IO.File]::ReadAllBytes([IO.Path]::Combine($RepositoryRoot,$registry[$index].path.Replace('/',[IO.Path]::DirectorySeparatorChar)));$null=$context.events.Add([pscustomobject]@{kind='RegisteredArtifactRead';path=$registry[$index].path})}
            $hashes=[ordered]@{};foreach($key in $bytes.Keys){$hashes[$key]=@($hashBytes.Invoke([byte[]]$bytes[$key]))[0]}
            $context.facts=for($i=0;$i -lt 11;$i++){$present=$i -notin @(8);$id=$registry[$i].artifactId;$sha=if($present){$hashes[$id]}else{$null};[pscustomobject][ordered]@{artifactId=$id;path=$registry[$i].path;requirement=$registry[$i].requirement;presence=if($present){'Present'}else{'Absent'};worktreeSha256=$sha;commitBlobSha256=if($i -in @(6,7,9,10)){$sha}else{$null};manifestSha256=if($i -in @(6,7,10)){$sha}else{$null}}}
            $context.handoff=[pscustomobject][ordered]@{snapshotId='snapshot-pc-install-001';ledgerPath=$registry[1].path;summaryPath=$registry[2].path}
            for($i=0;$i -lt 6;$i++){if($hashes["AR-I{0:d2}" -f ($i+1)] -cne $requiredHashes[$i]){return [pscustomobject]@{status='Failed';owner='FT-03';reason='StaleFingerprint';message='required hash mismatch'}}}
            $c2=@($traceRows|Where-Object callNumber -eq 2)[0];$c3=@($traceRows|Where-Object callNumber -eq 3)[0];$c5=@($traceRows|Where-Object callNumber -eq 5)[0];$c6=@($traceRows|Where-Object callNumber -eq 6)[0]
            if($hashes['AR-I07'] -cne @($hashBytes.Invoke([byte[]]$c2.stdoutBytes))[0] -or $hashes['AR-I08'] -cne @($hashBytes.Invoke([byte[]]$c3.stdoutBytes))[0] -or $hashes['AR-I10'] -cne @($hashBytes.Invoke([byte[]]$c5.stdoutBytes))[0] -or $hashes['AR-I11'] -cne @($hashBytes.Invoke([byte[]]$c6.stdoutBytes))[0]){return [pscustomobject]@{status='Failed';owner='FT-03';reason='StaleFingerprint';message='blob mismatch'}}
            $documents=[ordered]@{};foreach($id in $bytes.Keys){$documents[$id]=$utf8.GetString($bytes[$id])|ConvertFrom-Json -Depth 100 -DateKind String}
            if($null -ne $fixtureMutation){$null=$fixtureMutation.Invoke([pscustomobject]@{documents=$documents})}
            $contractResult=@($fixtureValidator.Invoke($documents,$hashes))[0]
            if($contractResult.status -ne 'Passed'){return $contractResult}
            [pscustomobject]@{status='Passed';owner=$null;reason=$null}
        }catch{[pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';message="$($_.Exception.Message) $($_.ScriptStackTrace)"}}
    }.GetNewClosure()
    $protocol=Invoke-C2GitProtocol -RepositoryRoot $RepositoryRoot -Transport $GitTransport -GitExecutable $gitExecutable -BeforeFinalHead $validation
    if($protocol.status -ne 'Passed'){
        $subject=if($null -ne $protocol.validation -and $protocol.validation.PSObject.Properties['subjectId'] -and $protocol.validation.subjectId){$protocol.validation.subjectId}elseif($protocol.owner -eq 'FT-02'){'AR-I10'}else{'C2Check:Freshness'}
        if($null -ne $context.facts){
            $findings=@();if($subject -match '^AR-I\d\d$'){$findings=@([pscustomobject][ordered]@{artifactId=$subject;transition=$protocol.owner;reason=$protocol.reason;evidence=@($script:Registry|Where-Object artifactId -eq $subject|ForEach-Object path)})}
            $failedResult=Invoke-C2PureDiscoveryIntake $context.facts $context.handoff $protocol.startCommitOid $protocol.endCommitOid -ValidationFindings $findings
            $failedResult.O2.gitInspectionProcessCount=$protocol.gitInspectionProcessCount
            $failedResult.O2.realAssetReadCount=@($context.events|Where-Object kind -eq RealAssetRead).Count
            return $failedResult
        }
        return New-C2FailedIntakeResult $protocol.owner $protocol.reason $protocol.startCommitOid $protocol.endCommitOid $protocol.headStable $protocol.gitInspectionProcessCount $protocol.heavyProcessCount $subject $RepositoryRoot
    }
    $result=Invoke-C2PureDiscoveryIntake $context.facts $context.handoff $protocol.startCommitOid $protocol.endCommitOid
    $result.O2.gitInspectionProcessCount=$protocol.gitInspectionProcessCount
    $result.O2.realAssetReadCount=@($context.events|Where-Object kind -eq RealAssetRead).Count
    $result.O2.createdExtractedCount=[int](-not $context.extractedBefore -and [IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Extracted')))
    $result.O2.createdImportedCount=[int](-not $context.importedBefore -and [IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Assets','StellaGaia','Imported')))
    return $result
}

function Invoke-C2DiscoveryIntakeGate {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot)
    Invoke-C2DiscoveryIntakeGateInternal -RepositoryRoot $RepositoryRoot -GitTransport $null -FixtureMutator $null
}

function Test-C2InjectedGateVector {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][ValidateSet('Call1StartFailure','Call3InvalidOutput','LedgerNestedInvalid','VocabularyInvalid','RootSchemaInvalid','RootSchemaRequiredInvalid','RootSchemaPropertyInvalid','RootSchemaDefInvalid','RootSchemaMinimumInvalid','ManifestShapeInvalid','ObservationHI03Invalid','ApprovalHI15Invalid')][string]$Vector)
    $transport=$null;$mutation=$null;$encoding=[Text.UTF8Encoding]::new($false);$oid='1111111111111111111111111111111111111111'
    if($Vector -eq 'Call1StartFailure'){$transport={param($number,$arguments,$raw)[pscustomobject]@{callNumber=$number;started=$false;prelaunchRejected=$false;exitCode=$null;stdoutBytes=[byte[]]@();stderr='start failure'}}.GetNewClosure()}
    elseif($Vector -eq 'Call3InvalidOutput'){$transport={param($number,$arguments,$raw)$text=if($number -in @(1,7)){"$oid`n"}elseif($number -eq 4){''}else{'blob'};$exit=if($number -eq 3){1}else{0};[pscustomobject]@{callNumber=$number;started=$true;prelaunchRejected=$false;exitCode=$exit;stdoutBytes=$encoding.GetBytes($text);stderr='';arguments=$arguments;environmentValid=$true;useShellExecute=$false;redirectStandardOutput=$true;redirectStandardError=$true;rawBlobCapture=$raw;stdoutByteCount=$encoding.GetByteCount($text)}}.GetNewClosure()}
    else{
        $mutation=switch($Vector){
            'LedgerNestedInvalid' {{param($bundle)$bundle.documents['AR-I02'].files=$null}}
            'VocabularyInvalid' {{param($bundle)$bundle.documents['AR-I05'].corpus=@('DefinitelyUnsupported')}}
            'RootSchemaInvalid' {{param($bundle)$bundle.documents['AR-I06'].properties=$null}}
            'RootSchemaRequiredInvalid' {{param($bundle)$bundle.documents['AR-I06'].required=@('DefinitelyMissing')}}
            'RootSchemaPropertyInvalid' {{param($bundle)$first=@($bundle.documents['AR-I06'].properties.PSObject.Properties)[0];$first.Value=$null}}
            'RootSchemaDefInvalid' {{param($bundle)$first=@($bundle.documents['AR-I06'].'$defs'.PSObject.Properties)[0];$first.Value=$null}}
            'RootSchemaMinimumInvalid' {{param($bundle)$bundle.documents['AR-I06'].properties.corpusSnapshotComplete.properties.catalogedFileCount.minimum='definitely-not-a-number'}}
            'ManifestShapeInvalid' {{param($bundle)$bundle.documents['AR-I10'].PSObject.Properties.Remove('entries')}}
            'ObservationHI03Invalid' {{param($bundle)$bundle.documents['AR-I07'].rows[5].observationId='observation-sha256:0000000000000000000000000000000000000000000000000000000000000000'}}
            'ApprovalHI15Invalid' {{param($bundle)$bundle.documents['AR-I11'].approvals[0].approvalId='exclusion-approval-sha256:0000000000000000000000000000000000000000000000000000000000000000'}}
        }
    }
    Invoke-C2DiscoveryIntakeGateInternal -RepositoryRoot $RepositoryRoot -GitTransport $transport -FixtureMutator $mutation
}

Export-ModuleMember -Function Get-C2DiscoveryInputFingerprint,Invoke-C2PureDiscoveryIntake,Invoke-C2GitFreshnessAdapter,Test-C2GitAdapterLifecycle,Invoke-C2DiscoveryIntakeGate
