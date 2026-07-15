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
    $dependencyIds=@($Row.dependencyLocators|ForEach-Object{Get-C2ObjectId $_})
    $canonicalDigest=if($null -eq $Row.canonicalEvidence){$null}else{Get-C2CanonicalEvidenceId $Row.canonicalEvidence}
    $text="C2ObjectObservationV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $Row.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$Row.pathId))+(ConvertTo-C2ScalarLine classId ([string]$Row.classId))+(ConvertTo-C2ScalarLine serializedSizeBytes ([string]$Row.serializedSizeBytes))+(ConvertTo-C2ScalarLine objectType $Row.objectType)+(ConvertTo-C2ScalarLine objectName $Row.objectName)+(Add-C2SetFrame dependencyLocatorIds $dependencyIds)+(ConvertTo-C2ScalarLine contentFingerprint $Row.contentFingerprint)+(Add-C2NullableFrame configurationDisposition $Row.configurationDisposition)+(Add-C2NullableFrame canonicalEvidenceDigest $canonicalDigest)+(ConvertTo-C2ScalarLine correlationId $Row.correlationEvidence.correlationId)+(Add-C2SetFrame evidence @($Row.evidence))
    "observation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2CanonicalEvidenceId {
    param($Evidence)
    $text="C2CanonicalEvidenceV2`n"+(ConvertTo-C2ScalarLine memberPlatform $Evidence.memberPlatform)+(ConvertTo-C2ScalarLine matchStatus $Evidence.proposedMatchStatus)+(Add-C2NullableFrame equivalenceFingerprint $Evidence.proposedEquivalenceFingerprint)+(Add-C2NullableFrame proposedCanonicalAssetId $Evidence.proposedCanonicalAssetId)+(Add-C2SetFrame memberObjectIds @($Evidence.memberObjectIds))+(Add-C2SetFrame evidence @($Evidence.evidence))
    "canonical-evidence-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2FileDiscoveryObservationId {
    param($Row)
    $text="C2FileDiscoveryObservationV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine relativePath $Row.relativePath)+(ConvertTo-C2ScalarLine outcome $Row.outcome)+(Add-C2SetFrame evidence @($Row.evidence))
    "file-discovery-observation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2RawRowId {
    param([string]$ArtifactPath,[string]$ArtifactSha256,[int]$RowIndex)
    $text="C2RawRowV1`n"+(ConvertTo-C2ScalarLine artifactPath $ArtifactPath)+(ConvertTo-C2ScalarLine artifactSha256 $ArtifactSha256)+(ConvertTo-C2ScalarLine rowIndex ([string]$RowIndex))
    "raw-row-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2ExactCorrelationId {
    param($Row)
    $text="C2CorrelationExactLocatorV1`n"+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $Row.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$Row.pathId))
    "correlation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2ObjectId {
    param($Row)
    $text="C2ObjectIdentityV1`n"+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $Row.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$Row.pathId))+(ConvertTo-C2ScalarLine classId ([string]$Row.classId))
    "sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2LocatorId {
    param($Row)
    $text="C2ToolLocatorV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $Row.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$Row.pathId))+(ConvertTo-C2ScalarLine classId ([string]$Row.classId))
    "locator-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Get-C2ObservationConflictId {
    param([string]$CorrelationId,[string[]]$ObservationIds,[string[]]$ObjectIds,[string[]]$Fields,[string]$FailureClass)
    $text="C2ObservationConflictV1`n"+(ConvertTo-C2ScalarLine correlationId $CorrelationId)+(Add-C2SetFrame observationIds $ObservationIds)+(Add-C2SetFrame derivedAssetObjectIds $ObjectIds)+(Add-C2SetFrame conflictingFields $Fields)+(ConvertTo-C2ScalarLine failureClass $FailureClass)
    "observation-conflict-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Test-C2OrdinalPortableSet {
    param($Values,[bool]$NonEmpty=$false)
    try{$items=@($Values);if($NonEmpty -and $items.Count -eq 0){return $false};$prior=$null;for($i=0;$i-lt$items.Count;$i++){if($items[$i] -isnot [string] -or -not(Test-C2PortablePath $items[$i]) -or ($i -gt 0 -and $script:Ordinal.Compare($prior,$items[$i]) -ge 0)){return $false};$prior=$items[$i]};return $true}catch{return $false}
}

function Test-C2ObjectObservationRow {
    param($Row)
    try{
        if($null -eq $Row -or (@($Row.PSObject.Properties.Name)-join ',') -cne 'observationId,toolName,toolVersion,sourceId,containerRelativePath,pathId,classId,serializedSizeBytes,objectType,objectName,dependencyLocators,contentFingerprint,configurationDisposition,canonicalEvidence,correlationEvidence,evidence'){return $false}
        foreach($name in @('toolName','toolVersion','sourceId','objectType','objectName')){if($Row.$name -isnot [string] -or [string]::IsNullOrEmpty($Row.$name)){return $false}}
        $parsedPathId=[long]0;$parsedClass=[long]0;$parsedSize=[long]0
        if(-not(Test-C2PortablePath $Row.containerRelativePath) -or -not[long]::TryParse([string]$Row.pathId,[Globalization.NumberStyles]::AllowLeadingSign,[Globalization.CultureInfo]::InvariantCulture,[ref]$parsedPathId) -or [string]$parsedPathId -cne [string]$Row.pathId -or -not[long]::TryParse([string]$Row.classId,[ref]$parsedClass) -or $parsedClass -lt 0 -or -not[long]::TryParse([string]$Row.serializedSizeBytes,[ref]$parsedSize) -or $parsedSize -lt 0 -or $Row.contentFingerprint -cnotmatch '^[0-9a-f]{64}$'){return $false}
        if($null -ne $Row.configurationDisposition -and $Row.configurationDisposition -cnotin @('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration')){return $false}
        if(-not(Test-C2OrdinalPortableSet $Row.evidence $true)){return $false}
        $dependencyIds=[Collections.Generic.List[string]]::new();foreach($dependency in @($Row.dependencyLocators)){if((@($dependency.PSObject.Properties.Name)-join ',') -cne 'sourceId,containerRelativePath,pathId,classId' -or [string]::IsNullOrEmpty($dependency.sourceId) -or -not(Test-C2PortablePath $dependency.containerRelativePath)){return $false};$dp=[long]0;$dc=[long]0;if(-not[long]::TryParse([string]$dependency.pathId,[Globalization.NumberStyles]::AllowLeadingSign,[Globalization.CultureInfo]::InvariantCulture,[ref]$dp) -or [string]$dp -cne [string]$dependency.pathId -or -not[long]::TryParse([string]$dependency.classId,[ref]$dc) -or $dc-lt 0){return $false};$oidText="C2ObjectIdentityV1`n"+(ConvertTo-C2ScalarLine sourceId $dependency.sourceId)+(ConvertTo-C2ScalarLine containerRelativePath $dependency.containerRelativePath)+(ConvertTo-C2ScalarLine pathId ([string]$dependency.pathId))+(ConvertTo-C2ScalarLine classId ([string]$dependency.classId));$dependencyIds.Add("sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($oidText))")};for($i=1;$i-lt$dependencyIds.Count;$i++){if($script:Ordinal.Compare($dependencyIds[$i-1],$dependencyIds[$i])-ge 0){return $false}}
        if($null -ne $Row.canonicalEvidence){if((@($Row.canonicalEvidence.PSObject.Properties.Name)-join ',') -cne 'memberPlatform,proposedMatchStatus,proposedEquivalenceFingerprint,proposedCanonicalAssetId,memberObjectIds,evidence' -or $Row.canonicalEvidence.memberPlatform -cnotin @('Pc','Android','Unknown') -or $Row.canonicalEvidence.proposedMatchStatus -cnotin @('ExactDuplicate','ConfirmedVariant','Unresolved') -or -not(Test-C2OrdinalPortableSet $Row.canonicalEvidence.evidence $true)){return $false};$members=@(Get-C2OrdinalUnique @($Row.canonicalEvidence.memberObjectIds));if($members.Count-ne@($Row.canonicalEvidence.memberObjectIds).Count-or@($members|Where-Object{$_-cnotmatch'^sha256:[0-9a-f]{64}$'}).Count){return $false};if($Row.canonicalEvidence.proposedMatchStatus -ceq 'Unresolved'){if($null-ne$Row.canonicalEvidence.proposedEquivalenceFingerprint-or$null-ne$Row.canonicalEvidence.proposedCanonicalAssetId-or$members.Count-ne0){return $false}}elseif($Row.canonicalEvidence.proposedEquivalenceFingerprint -cnotmatch '^[0-9a-f]{64}$'-or$Row.canonicalEvidence.proposedCanonicalAssetId-cnotmatch'^canonical-sha256:[0-9a-f]{64}$'-or$members.Count-lt2-or$members-cnotcontains(Get-C2ObjectId $Row)){return $false}}
        if($null -eq $Row.correlationEvidence -or (@($Row.correlationEvidence.PSObject.Properties.Name)-join ',') -cne 'correlationId,method,evidence' -or -not(Test-C2OrdinalPortableSet $Row.correlationEvidence.evidence $true)){return $false}
        if($Row.correlationEvidence.method -ceq 'ExactLocator'){if($Row.correlationEvidence.correlationId -cne (Get-C2ExactCorrelationId $Row)){return $false}}elseif($Row.correlationEvidence.method -cne 'ToolMapping' -or $Row.correlationEvidence.correlationId -cnotmatch '^correlation-sha256:[0-9a-f]{64}$'){return $false}
        return $Row.observationId -is [string] -and $Row.observationId -ceq (Get-C2ObservationId $Row)
    }catch{return $false}
}

function Get-C2FileDiscoveryConflictId {
    param([string]$SourceId,[string]$RelativePath,[string[]]$ObservationIds,[string[]]$Outcomes)
    $text="C2FileDiscoveryConflictV1`n"+(ConvertTo-C2ScalarLine sourceId $SourceId)+(ConvertTo-C2ScalarLine relativePath $RelativePath)+(Add-C2SetFrame observationIds $ObservationIds)+(Add-C2SetFrame outcomes $Outcomes)
    "file-discovery-conflict-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Invoke-C2FileDiscoveryPartitions {
    [CmdletBinding()]param([Parameter(Mandatory)][psobject]$InputFact)
    $failures=[Collections.Generic.List[object]]::new();$subjects=[Collections.Generic.List[object]]::new();$resolved=[Collections.Generic.List[object]]::new();$conflicts=[Collections.Generic.List[object]]::new()
    $files=@($InputFact.c1Files);$identity=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($file in $files){
        $key="$($file.sourceId)`n$($file.relativePath)";$validKind=$file.containerKind -is [string] -and -not [string]::IsNullOrEmpty($file.containerKind)
        $valid=$file.sourceId -is [string] -and -not [string]::IsNullOrEmpty($file.sourceId) -and (Test-C2PortablePath ([string]$file.relativePath)) -and $validKind -and [long]$file.sizeBytes -ge 0 -and $file.parseStatus -ceq $file.status.extraction
        if(-not $valid -or $identity.ContainsKey($key)){$failures.Add((New-C2AccountingRow inputFailures C1Ledger AR-I02 InvalidSchema 'FT-02:AR-I02' @($script:Registry[1].path)));continue}
        $identity.Add($key,$file)
    }
    $observations=[Collections.Generic.Dictionary[string,Collections.Generic.List[object]]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($key in $identity.Keys){$observations[$key]=[Collections.Generic.List[object]]::new()}
    foreach($wrapper in @($InputFact.objectObservationArtifact.acceptedRows)){
        $row=$wrapper.observation;$key="$($row.sourceId)`n$($row.containerRelativePath)"
        if(-not $identity.ContainsKey($key)){
            $rawId=Get-C2RawRowId $InputFact.objectObservationArtifact.artifactPath $InputFact.objectObservationArtifact.artifactSha256 ([int]$wrapper.rowIndex)
            $failures.Add((New-C2AccountingRow inputFailures ObjectObservation $rawId InvalidObservation "FT-05:$rawId" @($InputFact.objectObservationArtifact.artifactPath)));continue
        }
        $derived=[pscustomobject][ordered]@{fileDiscoveryObservationId=$null;toolName=$row.toolName;toolVersion=$row.toolVersion;sourceId=$row.sourceId;relativePath=$row.containerRelativePath;outcome='Readable';evidence=@($row.evidence)}
        $derived.fileDiscoveryObservationId=Get-C2FileDiscoveryObservationId $derived;$observations[$key].Add($derived)
    }
    $artifact=$InputFact.fileDiscoveryArtifact
    if($artifact.documentReadStatus -ceq 'Unparseable'){$failures.Add((New-C2AccountingRow inputFailures ObservationDocument AR-I08 InvalidObservation 'FT-05:AR-I08' @($script:Registry[7].path)))}
    elseif($artifact.documentReadStatus -ceq 'Parsed'){
        $rows=@($artifact.document.rows)
        for($i=0;$i -lt $rows.Count;$i++){
            $row=$rows[$i];$rawId=Get-C2RawRowId $artifact.artifactPath $artifact.artifactSha256 $i;$names=@($row.PSObject.Properties.Name)-join ','
            $valid=$names -ceq 'fileDiscoveryObservationId,toolName,toolVersion,sourceId,relativePath,outcome,evidence' -and $row.outcome -cin @('Readable','Opaque','Failed') -and @($row.evidence).Count -gt 0 -and (Test-C2PortablePath ([string]$row.relativePath)) -and $row.fileDiscoveryObservationId -ceq (Get-C2FileDiscoveryObservationId $row)
            $key="$($row.sourceId)`n$($row.relativePath)"
            if(-not $valid -or -not $identity.ContainsKey($key)){$reason=if(-not(Test-C2PortablePath ([string]$row.relativePath))){'UnsafePath'}else{'InvalidObservation'};$owner=if($reason -ceq 'UnsafePath'){'FT-04'}else{'FT-05'};$failures.Add((New-C2AccountingRow inputFailures FileDiscoveryObservation $rawId $reason "${owner}:$rawId" @($artifact.artifactPath)));continue}
            $observations[$key].Add($row)
        }
    }elseif($artifact.documentReadStatus -cne 'Absent'){$failures.Add((New-C2AccountingRow inputFailures ObservationDocument AR-I08 InvalidObservation 'FT-05:AR-I08' @($script:Registry[7].path)))}
    $orderedKeys=[string[]]@($identity.Keys);[Array]::Sort($orderedKeys,$script:Ordinal)
    foreach($key in $orderedKeys){
        $file=$identity[$key];$unique=[ordered]@{}
        foreach($row in $observations[$key]){$tuple="$($row.toolName)`n$($row.toolVersion)`n$($row.outcome)`n$($row.fileDiscoveryObservationId)";if(-not $unique.Contains($tuple)){$unique[$tuple]=$row}}
        $rows=@($unique.Values);$ids=@(Get-C2OrdinalUnique @($rows|ForEach-Object{$_.fileDiscoveryObservationId}));$outcomes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{$_.outcome}));$evidence=@(Get-C2OrdinalUnique @($rows|ForEach-Object{$_.evidence}));$tools=@(Get-C2OrdinalUnique @($rows|ForEach-Object{"$($_.toolName)`n$($_.toolVersion)"}))
        $private=if($rows.Count -eq 0){'NotAttempted'}elseif($outcomes.Count -gt 1){'FileDiscoveryConflict'}elseif($outcomes[0] -ceq 'Readable'){'Parsed'}else{$outcomes[0]}
        $public=if($private -ceq 'Parsed'){if($tools.Count -gt 1){'CrossToolVerified'}else{'ExtractedReadable'}}elseif($private -ceq 'FileDiscoveryConflict'){$null}else{$private}
        $partition=if($file.containerKind -cin @('DirectMedia','Metadata','ConfigurationCandidate')){'NonContainer'}else{'Container'}
        if($private -ceq 'FileDiscoveryConflict'){
            $conflictId=Get-C2FileDiscoveryConflictId $file.sourceId $file.relativePath $ids $outcomes
            $conflicts.Add([pscustomobject][ordered]@{fileDiscoveryConflictId=$conflictId;sourceId=$file.sourceId;relativePath=$file.relativePath;observationIds=[string[]]$ids;outcomes=[string[]]$outcomes;evidence=[string[]]$evidence})
            $failures.Add((New-C2AccountingRow inputFailures FileDiscoveryConflict $conflictId ConflictDetected "FT-06:$conflictId" $evidence))
        }else{$resolved.Add([pscustomobject][ordered]@{sourceId=$file.sourceId;relativePath=$file.relativePath;parseStatus=$public;observationIds=[string[]]$ids;evidence=[string[]]$evidence})}
        $subjects.Add([pscustomobject][ordered]@{sourceId=$file.sourceId;relativePath=$file.relativePath;containerKind=$file.containerKind;sizeBytes=[long]$file.sizeBytes;sp01Partition=$partition;sp02Partition=$private;observationIds=[string[]]$ids;evidence=[string[]]$evidence;publicExtraction=$public})
    }
    function Sum-Bytes($Rows){$items=@($Rows);if($items.Count -eq 0){return [long]0};[long](($items|Measure-Object sizeBytes -Sum).Sum)}
    $containers=@($subjects|Where-Object sp01Partition -eq Container);$nonContainers=@($subjects|Where-Object sp01Partition -eq NonContainer)
    $coverage=[ordered]@{catalogedFileCount=$subjects.Count;catalogedBytes=(Sum-Bytes $subjects);catalogedContainerCount=$containers.Count;catalogedContainerBytes=(Sum-Bytes $containers);nonContainerFileCount=$nonContainers.Count;nonContainerFileBytes=(Sum-Bytes $nonContainers);fileDiscoverySubjectCount=$subjects.Count;fileDiscoverySubjectBytes=(Sum-Bytes $subjects)}
    foreach($pair in @(@('NotAttempted','notAttempted'),@('Parsed','parsed'),@('Opaque','opaque'),@('Failed','failed'),@('FileDiscoveryConflict','fileDiscoveryConflict'))){$all=@($subjects|Where-Object sp02Partition -eq $pair[0]);$con=@($all|Where-Object sp01Partition -eq Container);$coverage["$($pair[1])FileCount"]=$all.Count;$coverage["$($pair[1])FileBytes"]=Sum-Bytes $all;$coverage["$($pair[1])ContainerCount"]=$con.Count;$coverage["$($pair[1])ContainerBytes"]=Sum-Bytes $con}
    $orderedCoverage=[ordered]@{};foreach($name in @('catalogedFileCount','catalogedBytes','catalogedContainerCount','catalogedContainerBytes','nonContainerFileCount','nonContainerFileBytes','fileDiscoverySubjectCount','fileDiscoverySubjectBytes','notAttemptedFileCount','notAttemptedFileBytes','parsedFileCount','parsedFileBytes','opaqueFileCount','opaqueFileBytes','failedFileCount','failedFileBytes','fileDiscoveryConflictFileCount','fileDiscoveryConflictFileBytes','notAttemptedContainerCount','notAttemptedContainerBytes','parsedContainerCount','parsedContainerBytes','opaqueContainerCount','opaqueContainerBytes','failedContainerCount','failedContainerBytes','fileDiscoveryConflictContainerCount','fileDiscoveryConflictContainerBytes')){$orderedCoverage[$name]=[long]$coverage[$name]}
    $failed=$failures.Count -gt 0
    [pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=if($failed){$null}else{$InputFact.discoveryInputFingerprint};fileSubjects=[object[]]$subjects;resolvedFileResults=[object[]]$resolved;fileDiscoveryConflicts=[object[]]$conflicts;inputFailures=[object[]]$failures;coverage=[pscustomobject]$orderedCoverage;gateStatus=if($failed){'Failed'}else{'Passed'};outputsSuppressed=$failed}
}

function Get-C2ApprovalId {
    param($Approval)
    $text="C2ExclusionApprovalV1`n"+(ConvertTo-C2ScalarLine subjectKind $Approval.subjectKind)+(ConvertTo-C2ScalarLine subjectId $Approval.subjectId)+(ConvertTo-C2ScalarLine reasonCode $Approval.reasonCode)+(ConvertTo-C2ScalarLine reason $Approval.reason)+(ConvertTo-C2ScalarLine approvedBy $Approval.approvedBy)+(ConvertTo-C2ScalarLine approvedAt $Approval.approvedAt)+(Add-C2SetFrame evidence @($Approval.evidence))
    "exclusion-approval-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Invoke-C2ObjectObservationPartitions {
    [CmdletBinding()]param([Parameter(Mandatory)][psobject]$InputFact)
    $subjects=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[object]]::new();$exclusions=[Collections.Generic.List[object]]::new();$acceptedRows=[Collections.Generic.List[object]]::new();$merged=[Collections.Generic.List[object]]::new();$conflicts=[Collections.Generic.List[object]]::new();$public=[Collections.Generic.List[object]]::new()
    $artifact=$InputFact.objectObservationArtifact;$approvalArtifact=$InputFact.exclusionApprovalArtifact
    if($artifact.documentReadStatus -cne 'Parsed' -or $null -eq $artifact.document -or $null -eq $artifact.document.rows){
        $failures.Add((New-C2AccountingRow inputFailures ObservationDocument AR-I07 InvalidObservation 'FT-05:AR-I07' @($script:Registry[6].path)))
    }else{
        $approvalValid=$approvalArtifact.documentReadStatus -ceq 'Parsed' -and $null -ne $approvalArtifact.document -and $approvalArtifact.document.observationArtifactPath -ceq $artifact.artifactPath -and $approvalArtifact.document.observationArtifactSha256 -ceq $artifact.artifactSha256
        $approvals=if($approvalValid){@($approvalArtifact.document.approvals)}else{@()}
        if($approvalValid){foreach($approval in $approvals){if((@($approval.PSObject.Properties.Name)-join ',') -cne 'approvalId,subjectKind,subjectId,reasonCode,reason,approvedBy,approvedAt,evidence' -or $approval.approvalId -cne (Get-C2ApprovalId $approval) -or $approval.subjectKind -cne 'ObjectObservation' -or $approval.reasonCode -cne 'ApprovedInputExclusion' -or @($approval.evidence).Count -eq 0){$approvalValid=$false;break}}}
        if(-not $approvalValid){$failures.Add((New-C2AccountingRow inputFailures ExclusionApprovalDocument AR-I11 InvalidSchema 'FT-02:AR-I11' @($script:Registry[10].path)));$approvals=@()}
        $rows=@($artifact.document.rows)
        for($i=0;$i -lt $rows.Count;$i++){
            $row=$rows[$i];$rawId=Get-C2RawRowId $artifact.artifactPath $artifact.artifactSha256 $i;$names=@($row.PSObject.Properties.Name)-join ','
            $portable=$false;try{$portable=(Test-C2PortablePath ([string]$row.containerRelativePath))}catch{}
            $valid=Test-C2ObjectObservationRow $row
            if(-not $valid){$owner=if(-not $portable){'FT-04'}else{'FT-05'};$reason=if($owner -ceq 'FT-04'){'UnsafePath'}else{'InvalidObservation'};$failures.Add((New-C2AccountingRow inputFailures ObjectObservation $rawId $reason "${owner}:$rawId" @($artifact.artifactPath)));$subjects.Add([pscustomobject][ordered]@{rowIndex=$i;subjectId=$rawId;observationId=$null;partition='RejectedObservation';evidence=[string[]]@($artifact.artifactPath)});continue}
            $matches=@($approvals|Where-Object subjectId -ceq $row.observationId)
            if($matches.Count -gt 1){$failures.Add((New-C2AccountingRow inputFailures ExclusionApprovalDocument AR-I11 InvalidSchema 'FT-02:AR-I11' @($script:Registry[10].path)));$matches=@()}
            if($matches.Count -eq 1){$evidence=Get-C2OrdinalUnique @(@($row.evidence)+@($matches[0].evidence));$exclusions.Add((New-C2AccountingRow inputExclusions ObjectObservation $row.observationId ApprovedInputExclusion "FT-14:$($row.observationId)" $evidence));$partition='ExcludedObservation'}else{$evidence=Get-C2OrdinalUnique @($row.evidence);$partition='AcceptedObservation'}
            $subjects.Add([pscustomobject][ordered]@{rowIndex=$i;subjectId=$row.observationId;observationId=$row.observationId;partition=$partition;evidence=[string[]]$evidence})
            if($partition -ceq 'AcceptedObservation'){$acceptedRows.Add($row)}
        }
        if($approvalValid){$validIds=@($subjects|Where-Object{$null-ne$_.observationId}|ForEach-Object observationId);foreach($approval in $approvals){if($approval.subjectId -cnotin $validIds){if(-not @($failures|Where-Object attribution -eq 'FT-02:AR-I11')){$failures.Add((New-C2AccountingRow inputFailures ExclusionApprovalDocument AR-I11 InvalidSchema 'FT-02:AR-I11' @($script:Registry[10].path)))}}}}
    }
    $mappedCorrelationIds=@(Get-C2OrdinalUnique @($acceptedRows|Where-Object{$_.correlationEvidence.method-ceq'ToolMapping'}|ForEach-Object{$_.correlationEvidence.correlationId}));foreach($mappedId in $mappedCorrelationIds){$mappedRows=@($acceptedRows|Where-Object{$_.correlationEvidence.correlationId-ceq$mappedId});$locatorIds=@(Get-C2OrdinalUnique @($mappedRows|ForEach-Object{Get-C2LocatorId $_}));$mappedText="C2CorrelationToolMappingV1`n"+(Add-C2SetFrame locatorIds $locatorIds);$expected="correlation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($mappedText))";if($mappedId-cne$expected){foreach($row in $mappedRows){$index=[Array]::IndexOf(@($artifact.document.rows),$row);$rawId=Get-C2RawRowId $artifact.artifactPath $artifact.artifactSha256 $index;$subject=@($subjects|Where-Object observationId -ceq $row.observationId)[0];$subject.subjectId=$rawId;$subject.observationId=$null;$subject.partition='RejectedObservation';$subject.evidence=[string[]]@($artifact.artifactPath);$failures.Add((New-C2AccountingRow inputFailures ObjectObservation $rawId InvalidObservation "FT-05:$rawId" @($artifact.artifactPath)));$null=$acceptedRows.Remove($row)}}}
    $groups=[ordered]@{};foreach($row in $acceptedRows){$id=[string]$row.correlationEvidence.correlationId;if(-not $groups.Contains($id)){$groups[$id]=[Collections.Generic.List[object]]::new()};$groups[$id].Add($row)}
    $groupIds=[string[]]@($groups.Keys);[Array]::Sort($groupIds,$script:Ordinal)
    foreach($correlationId in $groupIds){
        $rows=@($groups[$correlationId]);$ids=@(Get-C2OrdinalUnique @($rows.observationId));$objectIds=@(Get-C2OrdinalUnique @($rows|ForEach-Object{Get-C2ObjectId $_}));$fields=[Collections.Generic.List[string]]::new()
        if($objectIds.Count -gt 1){foreach($name in @('sourceId','containerRelativePath','pathId','classId')){if(@(Get-C2OrdinalUnique @($rows.$name)).Count-gt 1){$fields.Add($name)}};$failureClass='IdentityConflict'}else{
            foreach($name in @('objectType','objectName','serializedSizeBytes','contentFingerprint','configurationDisposition')){if(@(Get-C2OrdinalUnique @($rows|ForEach-Object{if($null-eq$_.$name){'<null>'}else{[string]$_.$name}})).Count-gt 1){$fields.Add($name)}}
            $depShapes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{(@($_.dependencyLocators|ForEach-Object{Get-C2ObjectId $_})-join ',')}));if($depShapes.Count-gt 1){$fields.Add('dependencyObjectIds')}
            $canonicalShapes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{if($null-eq$_.canonicalEvidence){'<null>'}else{$_.canonicalEvidence|ConvertTo-Json -Depth 20 -Compress}}));if($canonicalShapes.Count-gt 1){$fields.Add('canonicalEvidence')}
            $platforms=@(Get-C2OrdinalUnique @($rows|ForEach-Object{$sourceId=$_.sourceId;$kind=@($InputFact.sourceKinds|Where-Object sourceId -ceq $sourceId).sourceKind;if($kind -cin @('PcInstall','PcPatchOrCache')){'Pc'}elseif($kind -cin @('AndroidApk','AndroidDataOrCache')){'Android'}else{'Invalid'}}));if($platforms.Count-gt 1-or$platforms[0]-ceq'Invalid'){$fields.Add('memberPlatform')};$failureClass='MaterialConflict'
        }
        $evidence=Get-C2OrdinalUnique @($rows|ForEach-Object{@($_.evidence)+@($_.correlationEvidence.evidence)+$(if($null-ne$_.canonicalEvidence){@($_.canonicalEvidence.evidence)}else{@()})})
        if($fields.Count-gt 0){$fieldSet=Get-C2OrdinalUnique $fields;$conflictId=Get-C2ObservationConflictId $correlationId $ids $objectIds $fieldSet $failureClass;$conflicts.Add([pscustomobject][ordered]@{observationConflictId=$conflictId;correlationId=$correlationId;observationIds=[string[]]$ids;derivedAssetObjectIds=[string[]]$objectIds;conflictingFields=[string[]]$fieldSet;failureClass=$failureClass;evidence=[string[]]$evidence});$failures.Add((New-C2AccountingRow inputFailures ObservationConflict $conflictId ConflictDetected "FT-07:$conflictId" $evidence));continue}
        $first=$rows[0];$dependencyIds=@(Get-C2OrdinalUnique @($first.dependencyLocators|ForEach-Object{Get-C2ObjectId $_}));$platform=if(@($InputFact.sourceKinds|Where-Object sourceId -ceq $first.sourceId).sourceKind -cin @('PcInstall','PcPatchOrCache')){'Pc'}else{'Android'};$resolution=if(@(Get-C2OrdinalUnique @($rows|ForEach-Object{"$($_.toolName)`n$($_.toolVersion)"})).Count-gt 1){'Agreed'}else{'SingleTool'}
        $values=[pscustomobject][ordered]@{sourceId=$first.sourceId;objectType=$first.objectType;objectName=$first.objectName;containerRelativePath=$first.containerRelativePath;pathId=$first.pathId;classId=[long]$first.classId;serializedSizeBytes=[long]$first.serializedSizeBytes;dependencyObjectIds=[string[]]$dependencyIds;contentFingerprint=$first.contentFingerprint;configurationDisposition=$first.configurationDisposition;memberPlatform=$platform}
        $objectId=$objectIds[0];$merged.Add([pscustomobject][ordered]@{assetObjectId=$objectId;correlationId=$correlationId;observationIds=[string[]]$ids;resolutionStatus=$resolution;resolvedValues=$values;evidence=[string[]]$evidence})
    }
    $resolvedSet=[string[]]@($merged|ForEach-Object assetObjectId);[Array]::Sort($resolvedSet,$script:Ordinal);$unresolvedDependencyCount=0
    foreach($item in $merged){$rows=@($acceptedRows|Where-Object{$_.observationId -cin $item.observationIds});$first=$rows[0];$toolRows=[Collections.Generic.List[object]]::new();$orderedRows=[Collections.Generic.List[object]]::new();foreach($row in $rows){$orderedRows.Add($row)};$orderedRows.Sort([Comparison[object]]{param($a,$b)$ak="$($a.toolName)`n$($a.toolVersion)`n$($a.observationId)";$bk="$($b.toolName)`n$($b.toolVersion)`n$($b.observationId)";$script:Ordinal.Compare($ak,$bk)});foreach($row in $orderedRows){$toolRows.Add([pscustomobject][ordered]@{toolName=$row.toolName;observation="version=$($row.toolVersion);observationId=$($row.observationId);resolution=$($item.resolutionStatus)"})};$unresolved=@($item.resolvedValues.dependencyObjectIds|Where-Object{$_-ceq$item.assetObjectId-or$_-cnotin$resolvedSet});$unresolvedDependencyCount+=$unresolved.Count;$config=if($null-eq$item.resolvedValues.configurationDisposition){'NotConfiguration'}else{$item.resolvedValues.configurationDisposition};$semantics=if($item.resolvedValues.objectType-ceq'Unknown'){'Unknown'}elseif($item.resolvedValues.objectName-cne'Unknown'-and$unresolved.Count-eq 0-and$config-cin@('Parsed','NotConfiguration')){'Known'}else{'PartiallyKnown'};$partition=if($semantics-ceq'Unknown'){'Unclassified'}else{'Classified'};$status=[pscustomobject][ordered]@{corpus='Cataloged';extraction=if($item.resolutionStatus-ceq'Agreed'){'CrossToolVerified'}else{'ExtractedReadable'};semantics=$semantics;unity='NotTested';disposition='RetainForLater'};$public.Add([pscustomobject][ordered]@{assetObjectId=$item.assetObjectId;sourceId=$item.resolvedValues.sourceId;objectType=$item.resolvedValues.objectType;objectName=$item.resolvedValues.objectName;containerRelativePath=$item.resolvedValues.containerRelativePath;classId=$item.resolvedValues.classId;serializedSizeBytes=$item.resolvedValues.serializedSizeBytes;dependencyObjectIds=$item.resolvedValues.dependencyObjectIds;toolObservations=[object[]]$toolRows;platformVariant=$item.resolvedValues.memberPlatform;configurationDisposition=$config;evidence=$item.evidence;status=$status;sp04Partition=$partition})}
    $provenance=[Collections.Generic.List[object]]::new();foreach($row in @($acceptedRows|Where-Object{$null-ne$_.canonicalEvidence})){$memberIds=@(Get-C2OrdinalUnique @($row.canonicalEvidence.memberObjectIds));$facts=[Collections.Generic.List[object]]::new();$missing=[Collections.Generic.List[string]]::new();foreach($memberId in $memberIds){$resolved=@($merged|Where-Object assetObjectId -ceq $memberId);if($resolved.Count-eq1){$facts.Add([pscustomobject][ordered]@{assetObjectId=$memberId;memberPlatform=$resolved[0].resolvedValues.memberPlatform;contentFingerprint=$resolved[0].resolvedValues.contentFingerprint})}else{$missing.Add($memberId)}};$platforms=@(Get-C2OrdinalUnique @($facts|ForEach-Object memberPlatform));$scope=if($missing.Count){'Unknown'}elseif($platforms.Count-eq1-and$platforms[0]-ceq'Pc'){'PcOnly'}elseif($platforms.Count-eq1-and$platforms[0]-ceq'Android'){'AndroidOnly'}elseif($row.canonicalEvidence.proposedMatchStatus-ceq'ExactDuplicate'){'CrossPlatformIdentical'}else{'CrossPlatformVariant'};$evidence=@(Get-C2OrdinalUnique @(@($row.evidence)+@($row.canonicalEvidence.evidence)));$p=[pscustomobject][ordered]@{proposalId='';observationId=$row.observationId;canonicalEvidenceId=(Get-C2CanonicalEvidenceId $row.canonicalEvidence);proposedCanonicalAssetId=$row.canonicalEvidence.proposedCanonicalAssetId;matchStatus=$row.canonicalEvidence.proposedMatchStatus;platformScope=$scope;equivalenceFingerprint=$row.canonicalEvidence.proposedEquivalenceFingerprint;memberObjectIds=[string[]]$memberIds;memberFacts=[object[]]$facts;missingMemberObjectIds=[string[]]$missing;evidence=[string[]]$evidence};$p.proposalId=Get-C2CanonicalProposalId $p;$provenance.Add($p)}
    $accepted=@($subjects|Where-Object partition -eq AcceptedObservation).Count;$rejected=@($subjects|Where-Object partition -eq RejectedObservation).Count;$excluded=@($subjects|Where-Object partition -eq ExcludedObservation).Count;$failed=$failures.Count -gt 0
    $coverage=[pscustomobject][ordered]@{objectObservationRowCount=$subjects.Count;acceptedObjectObservationRowCount=$accepted;rejectedObjectObservationRowCount=$rejected;excludedObjectObservationRowCount=$excluded;correlationGroupCount=$groupIds.Count;enumeratedObjectCount=$merged.Count;observationConflictObjectCount=$conflicts.Count;classifiedObjectCount=@($public|Where-Object sp04Partition -eq Classified).Count;unclassifiedObjectCount=@($public|Where-Object sp04Partition -eq Unclassified).Count;unresolvedDependencyCount=$unresolvedDependencyCount;observationConflictRecordCount=$conflicts.Count;inputFailureCount=$failures.Count;excludedInputCount=$exclusions.Count;issueCount=$failures.Count}
    [pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=if($failed){$null}else{$InputFact.discoveryInputFingerprint};observationSubjects=[object[]]$subjects;mergedObjects=[object[]]$merged;observationConflicts=[object[]]$conflicts;publicObjectCores=[object[]]$public;canonicalProposalProvenance=[object[]]$provenance;inputFailures=[object[]]$failures;inputExclusions=[object[]]$exclusions;coverage=$coverage;gateStatus=if($failed){'Failed'}else{'Passed'};outputsSuppressed=$failed}
}

function Get-C2ConfigurationObservationId {param($Row)$text="C2FileConfigurationObservationV1`n"+(ConvertTo-C2ScalarLine toolName $Row.toolName)+(ConvertTo-C2ScalarLine toolVersion $Row.toolVersion)+(ConvertTo-C2ScalarLine sourceId $Row.sourceId)+(ConvertTo-C2ScalarLine relativePath $Row.relativePath)+(ConvertTo-C2ScalarLine contentFingerprint $Row.contentFingerprint)+(ConvertTo-C2ScalarLine configurationDisposition $Row.configurationDisposition)+(ConvertTo-C2ScalarLine observation $Row.observation)+(Add-C2SetFrame evidence @($Row.evidence));"configuration-observation-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"}
function Get-C2ConfigurationFileId {param($File)$text="C2ConfigurationFileV1`n"+(ConvertTo-C2ScalarLine sourceId $File.sourceId)+(ConvertTo-C2ScalarLine relativePath $File.relativePath);"config-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"}
function Get-C2ConfigurationObjectId {param([string]$ObjectId)$text="C2ConfigurationObjectV1`n"+(ConvertTo-C2ScalarLine assetObjectId $ObjectId);"config-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"}
function Get-C2ConfigurationConflictId {param($CandidateId,[string]$TargetKind,[string[]]$ObservationIds,[string[]]$Fields)$text="C2ConfigurationConflictV1`n"+(ConvertTo-C2ScalarLine configurationCandidateId $CandidateId)+(ConvertTo-C2ScalarLine targetKind $TargetKind)+(Add-C2SetFrame observationIds $ObservationIds)+(Add-C2SetFrame conflictingFields $Fields);"configuration-conflict-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"}

function Invoke-C2ConfigurationPartitions {
    [CmdletBinding()]param([Parameter(Mandatory)][psobject]$InputFact)
    $candidates=[Collections.Generic.List[object]]::new();$conflicts=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[object]]::new();$files=@($InputFact.c1Files|Where-Object containerKind -ceq ConfigurationCandidate);$artifact=$InputFact.fileConfigurationArtifact;$rowsByTarget=[ordered]@{};$seenIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
    if($artifact.documentReadStatus-ceq'Parsed'){
        if($null-eq$artifact.document-or(@($artifact.document.PSObject.Properties.Name)-join',')-cne'rows'-or$null-eq$artifact.document.rows){$failures.Add((New-C2AccountingRow inputFailures ObservationDocument AR-I09 InvalidObservation 'FT-05:AR-I09' @($script:Registry[8].path)))}
        else{for($i=0;$i-lt@($artifact.document.rows).Count;$i++){
            $row=@($artifact.document.rows)[$i];$rawId=Get-C2RawRowId $artifact.artifactPath $artifact.artifactSha256 $i;$valid=$false;$portable=$false
            try{$portable=Test-C2PortablePath ([string]$row.relativePath);$valid=(@($row.PSObject.Properties.Name)-join',')-ceq'configurationObservationId,toolName,toolVersion,sourceId,relativePath,contentFingerprint,configurationDisposition,observation,evidence'-and-not[string]::IsNullOrEmpty($row.toolName)-and-not[string]::IsNullOrEmpty($row.toolVersion)-and-not[string]::IsNullOrEmpty($row.sourceId)-and$portable-and$row.contentFingerprint-cmatch'^[0-9a-f]{64}$'-and$row.configurationDisposition-cin@('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration')-and-not[string]::IsNullOrEmpty($row.observation)-and(Test-C2OrdinalPortableSet $row.evidence $true)-and$row.configurationObservationId-ceq(Get-C2ConfigurationObservationId $row)-and$seenIds.Add([string]$row.configurationObservationId)}catch{$valid=$false}
            [object[]]$file=@();if($valid){$file=@($files|Where-Object{$_.sourceId-ceq$row.sourceId-and$_.relativePath-ceq$row.relativePath})}
            if(-not$valid-or$file.Count-ne1){$hasPath=$null-ne$row-and$row.PSObject.Properties.Name-ccontains'relativePath'-and-not[string]::IsNullOrEmpty([string]$row.relativePath);$owner=if($hasPath-and-not$portable){'FT-04'}else{'FT-05'};$reason=if($owner-ceq'FT-04'){'UnsafePath'}elseif($valid){'UnknownTarget'}else{'InvalidObservation'};$failures.Add((New-C2AccountingRow inputFailures FileConfigurationObservation $rawId $reason "${owner}:$rawId" @($artifact.artifactPath)));continue}
            $key="$($row.sourceId)`n$($row.relativePath)";if(-not$rowsByTarget.Contains($key)){$rowsByTarget[$key]=[Collections.Generic.List[object]]::new()};$rowsByTarget[$key].Add($row)
        }}
    }elseif($artifact.documentReadStatus-cne'Absent'){$failures.Add((New-C2AccountingRow inputFailures ObservationDocument AR-I09 InvalidObservation 'FT-05:AR-I09' @($script:Registry[8].path)))}
    foreach($file in $files){$id=Get-C2ConfigurationFileId $file;$key="$($file.sourceId)`n$($file.relativePath)";$rows=@(if($rowsByTarget.Contains($key)){$rowsByTarget[$key]});$obs=@(Get-C2OrdinalUnique @($rows|ForEach-Object configurationObservationId));$evidence=if($rows.Count){@(Get-C2OrdinalUnique @($rows|ForEach-Object evidence))}else{@($script:Registry[1].path)};$content=@(Get-C2OrdinalUnique @($rows|ForEach-Object contentFingerprint));$dispositions=@(Get-C2OrdinalUnique @($rows|ForEach-Object configurationDisposition));$fields=@();if($content.Count-gt1){$fields+='contentFingerprint'};if($dispositions.Count-gt1){$fields+='configurationDisposition'};if($fields.Count){$cid=Get-C2ConfigurationConflictId $id File $obs $fields;$conflicts.Add([pscustomobject][ordered]@{configurationConflictId=$cid;configurationCandidateId=$id;targetKind='File';observationIds=[string[]]$obs;conflictingFields=[string[]]$fields;evidence=[string[]]$evidence});$failures.Add((New-C2AccountingRow inputFailures ConfigurationConflict $cid ConflictDetected "FT-08:$cid" $evidence))}else{$disposition=if($rows.Count){$dispositions[0]}else{'DiscoveredOpaque'};$candidates.Add([pscustomobject][ordered]@{configurationCandidateId=$id;targetKind='File';sourceId=$file.sourceId;containerRelativePath=$file.relativePath;assetObjectId=$null;configurationDisposition=$disposition;observationIds=[string[]]$obs;evidence=[string[]]$evidence})}}
    foreach($object in @($InputFact.mergedObjects|Where-Object{$null-ne$_.resolvedValues.configurationDisposition})){$id=Get-C2ConfigurationObjectId $object.assetObjectId;$candidates.Add([pscustomobject][ordered]@{configurationCandidateId=$id;targetKind='Object';sourceId=$object.resolvedValues.sourceId;containerRelativePath=$object.resolvedValues.containerRelativePath;assetObjectId=$object.assetObjectId;configurationDisposition=$object.resolvedValues.configurationDisposition;observationIds=[string[]]$object.observationIds;evidence=[string[]]$object.evidence})}
    $states=@('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration');$coverage=[ordered]@{configurationDiscoverySubjectCount=$candidates.Count+$conflicts.Count;configurationCandidateCount=$candidates.Count;configurationConflictCount=$conflicts.Count};foreach($state in $states){$name=if($state-ceq'RequiresRuntimeType'){'requiresRuntimeType'}elseif($state-ceq'LikelyServerDependent'){'likelyServerDependent'}elseif($state-ceq'DiscoveredOpaque'){'discoveredOpaque'}elseif($state-ceq'NotConfiguration'){'notConfiguration'}else{$state.ToLowerInvariant()};$coverage["${name}ConfigurationCount"]=@($candidates|Where-Object configurationDisposition -ceq $state).Count};$failed=$failures.Count-gt0
    [pscustomobject][ordered]@{configurationCandidates=[object[]]$candidates;configurationConflicts=[object[]]$conflicts;inputFailures=[object[]]$failures;coverage=[pscustomobject]$coverage;gateStatus=if($failed){'Failed'}else{'Passed'};outputsSuppressed=$failed}
}

function Get-C2CanonicalGroupId {
    param([string]$MatchStatus,[string]$PlatformScope,[AllowNull()][string]$EquivalenceFingerprint,[string[]]$MemberObjectIds)
    $text="C2CanonicalGroupV1`n"+(ConvertTo-C2ScalarLine matchStatus $MatchStatus)+(ConvertTo-C2ScalarLine platformScope $PlatformScope)+(ConvertTo-C2ScalarLine equivalenceFingerprint $EquivalenceFingerprint)+(Add-C2SetFrame memberObjectIds $MemberObjectIds)
    "canonical-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}
function Get-C2VariantEquivalenceFingerprint {param([string[]]$ContentFingerprints)$text="C2VariantEquivalenceV1`n"+(Add-C2SetFrame contentFingerprints $ContentFingerprints);Get-C2Sha256 $script:Utf8.GetBytes($text)}
function Get-C2CanonicalConflictId {
    param([string[]]$ProposedCanonicalAssetIds,[string[]]$MemberObjectIds,[string[]]$ObservationIds,[string[]]$ConflictingFields)
    $text="C2CanonicalConflictV1`n"+(Add-C2SetFrame proposedCanonicalAssetIds $ProposedCanonicalAssetIds)+(Add-C2SetFrame memberObjectIds $MemberObjectIds)+(Add-C2SetFrame observationIds $ObservationIds)+(Add-C2SetFrame conflictingFields $ConflictingFields)
    "canonical-conflict-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}
function Get-C2CanonicalProposalId {
    param($Row)
    $facts=[Collections.Generic.List[object]]::new();foreach($fact in @($Row.memberFacts)){$facts.Add($fact)};$facts.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.assetObjectId,[string]$b.assetObjectId)})
    $text="C2CanonicalProposalV2`n"+(ConvertTo-C2ScalarLine observationId $Row.observationId)+(ConvertTo-C2ScalarLine canonicalEvidenceId $Row.canonicalEvidenceId)+(Add-C2NullableFrame proposedCanonicalAssetId $Row.proposedCanonicalAssetId)+(ConvertTo-C2ScalarLine matchStatus $Row.matchStatus)+(ConvertTo-C2ScalarLine platformScope $Row.platformScope)+(Add-C2NullableFrame equivalenceFingerprint $Row.equivalenceFingerprint)+(Add-C2SetFrame memberObjectIds @($Row.memberObjectIds))
    $count=[string]$facts.Count;$text+="memberFacts.count:$($script:Utf8.GetByteCount($count)):$count`n";for($i=0;$i-lt$facts.Count;$i++){$nested="C2CanonicalMemberFactV1`n"+(ConvertTo-C2ScalarLine assetObjectId $facts[$i].assetObjectId)+(ConvertTo-C2ScalarLine memberPlatform $facts[$i].memberPlatform)+(ConvertTo-C2ScalarLine contentFingerprint $facts[$i].contentFingerprint);$bytes=$script:Utf8.GetBytes($nested);$text+="memberFacts[$i]:$($bytes.Length):$nested`n"}
    $text+=(Add-C2SetFrame missingMemberObjectIds @($Row.missingMemberObjectIds))+(Add-C2SetFrame evidence @($Row.evidence));"canonical-proposal-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Invoke-C2CanonicalPartitions {
    [CmdletBinding()]param([Parameter(Mandatory)][psobject]$InputFact)
    $groups=[Collections.Generic.List[object]]::new();$conflicts=[Collections.Generic.List[object]]::new();$failures=[Collections.Generic.List[object]]::new();$public=[Collections.Generic.List[object]]::new();$objects=@($InputFact.publicObjectCores);$proposals=@($InputFact.canonicalProposalProvenance);$expected=@(Get-C2OrdinalUnique @($InputFact.acceptedNonNullCanonicalEvidenceObservationIds));$actual=@(Get-C2OrdinalUnique @($proposals|ForEach-Object observationId));$proposalIds=@(Get-C2OrdinalUnique @($proposals|ForEach-Object proposalId))
    $conservationInvalid=$expected.Count-ne$actual.Count-or$proposals.Count-ne$expected.Count-or$actual.Count-ne$proposals.Count-or(@(Compare-Object $expected $actual -SyncWindow 0).Count)-gt0-or$proposalIds.Count-ne$proposals.Count
    if($conservationInvalid){$failures.Add((New-C2AccountingRow inputFailures ConservationCheck 'C2Check:Conservation' ConservationMismatch 'FT-10:C2Check:Conservation' @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json')))}
    $valid=[Collections.Generic.List[object]]::new();if(-not$conservationInvalid){foreach($p in $proposals){$ok=$false;try{$names=@($p.PSObject.Properties.Name)-join',';$facts=@($p.memberFacts);$memberInput=@($p.memberObjectIds);$missingInput=@($p.missingMemberObjectIds);$evidenceInput=@($p.evidence);$members=@(Get-C2OrdinalUnique $memberInput);$missing=@(Get-C2OrdinalUnique $missingInput);$evidence=@(Get-C2OrdinalUnique $evidenceInput);$factIds=@(Get-C2OrdinalUnique @($facts|ForEach-Object assetObjectId));$union=@(Get-C2OrdinalUnique @($factIds+$missing));$factShape=$facts.Count-gt0-and@($facts|Where-Object{(@($_.PSObject.Properties.Name)-join',')-cne'assetObjectId,memberPlatform,contentFingerprint'-or$_.assetObjectId-cnotmatch'^sha256:[0-9a-f]{64}$'-or$_.memberPlatform-cnotin@('Pc','Android','Unknown')-or$_.contentFingerprint-cnotmatch'^[0-9a-f]{64}$'}).Count-eq0;$factsOrdered=$factIds.Count-eq$facts.Count-and($factIds-join',')-ceq(@($facts.assetObjectId)-join',');$scalarShape=$p.proposalId-cmatch'^canonical-proposal-sha256:[0-9a-f]{64}$'-and$p.observationId-cmatch'^observation-sha256:[0-9a-f]{64}$'-and$p.canonicalEvidenceId-cmatch'^canonical-evidence-sha256:[0-9a-f]{64}$'-and$p.proposedCanonicalAssetId-cmatch'^canonical-sha256:[0-9a-f]{64}$'-and$p.matchStatus-cin@('ExactDuplicate','ConfirmedVariant')-and$p.platformScope-cin@('PcOnly','AndroidOnly','CrossPlatformIdentical','CrossPlatformVariant','Unknown')-and$p.equivalenceFingerprint-cmatch'^[0-9a-f]{64}$';$setShape=$members.Count-eq$memberInput.Count-and($members-join',')-ceq($memberInput-join',')-and$missing.Count-eq$missingInput.Count-and($missing-join',')-ceq($missingInput-join',')-and$evidence.Count-eq$evidenceInput.Count-and($evidence-join',')-ceq($evidenceInput-join',')-and(Test-C2OrdinalPortableSet $evidenceInput $true);$ok=$names-ceq'proposalId,observationId,canonicalEvidenceId,proposedCanonicalAssetId,matchStatus,platformScope,equivalenceFingerprint,memberObjectIds,memberFacts,missingMemberObjectIds,evidence'-and$scalarShape-and$setShape-and$factShape-and$factsOrdered-and$members.Count-ge2-and@($facts|Where-Object assetObjectId -notin $members).Count-eq0-and@($factIds|Where-Object{$_-cin$missing}).Count-eq0-and($union-join',')-ceq($members-join',')-and$p.proposalId-ceq(Get-C2CanonicalProposalId $p)}catch{$ok=$false};if($ok){$valid.Add($p)}else{$conservationInvalid=$true;break}}}
    if($conservationInvalid-and$failures.Count-eq0){$failures.Add((New-C2AccountingRow inputFailures ConservationCheck 'C2Check:Conservation' ConservationMismatch 'FT-10:C2Check:Conservation' @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json')))}
    $conflicted=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
    if(-not$conservationInvalid){
        $byId=[ordered]@{};foreach($p in $valid){$id=[string]$p.proposedCanonicalAssetId;if(-not$byId.Contains($id)){$byId[$id]=[Collections.Generic.List[object]]::new()};$byId[$id].Add($p)}
        $objectToIds=[ordered]@{};foreach($p in $valid){foreach($member in $p.memberObjectIds){if(-not$objectToIds.Contains($member)){$objectToIds[$member]=[Collections.Generic.List[string]]::new()};if(-not$objectToIds[$member].Contains([string]$p.proposedCanonicalAssetId)){$objectToIds[$member].Add([string]$p.proposedCanonicalAssetId)}}}
        $processed=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($id in @($byId.Keys)){if($processed.Contains([string]$id)){continue};$component=[Collections.Generic.List[string]]::new();$component.Add([string]$id);for($ci=0;$ci-lt$component.Count;$ci++){$current=$component[$ci];$currentMembers=@(Get-C2OrdinalUnique @($byId[$current].memberObjectIds));foreach($member in $currentMembers){foreach($other in @($objectToIds[$member])){if(-not$component.Contains($other)){$component.Add($other)}}}};foreach($componentId in $component){$null=$processed.Add($componentId)};$rows=@($component|ForEach-Object{$byId[$_]});$members=@(Get-C2OrdinalUnique @($rows.memberObjectIds));$observations=@(Get-C2OrdinalUnique @($rows.observationId));$proposed=@(Get-C2OrdinalUnique @($rows.proposedCanonicalAssetId));$fields=[Collections.Generic.List[string]]::new();$first=$rows[0]
            $isOverlap=$proposed.Count-gt1;if($isOverlap){$fields.Add('memberObjectIds')}else{foreach($name in @('matchStatus','platformScope','equivalenceFingerprint')){if(@(Get-C2OrdinalUnique @($rows|ForEach-Object{if($null-eq$_.$name){'<null>'}else{[string]$_.$name}})).Count-gt1){$fields.Add($name)}}
            $memberShapes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{@(Get-C2OrdinalUnique @($_.memberObjectIds))-join','}));if($memberShapes.Count-gt1){$fields.Add('memberObjectIds')};$factShapes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{@($_.memberFacts|ForEach-Object{"$($_.assetObjectId)|$($_.memberPlatform)|$($_.contentFingerprint)"})-join','}));if($factShapes.Count-gt1){$fields.Add('memberFacts')};$missingShapes=@(Get-C2OrdinalUnique @($rows|ForEach-Object{@(Get-C2OrdinalUnique @($_.missingMemberObjectIds))-join','}));if($missingShapes.Count-gt1){$fields.Add('missingMemberObjectIds')}
            if(@($rows|Where-Object{@($_.missingMemberObjectIds).Count-gt0}).Count){$fields.Add('missingMemberObjectIds')}
            if(@($members|Where-Object{$objectToIds[$_].Count-gt1}).Count){$fields.Add('memberObjectIds')}
            $facts=@($first.memberFacts);$platforms=@(Get-C2OrdinalUnique @($facts.memberPlatform));$contents=@(Get-C2OrdinalUnique @($facts.contentFingerprint));$derivedScope=if(@($first.missingMemberObjectIds).Count){'Unknown'}elseif($platforms.Count-eq1-and$platforms[0]-ceq'Pc'){'PcOnly'}elseif($platforms.Count-eq1-and$platforms[0]-ceq'Android'){'AndroidOnly'}elseif($first.matchStatus-ceq'ExactDuplicate'){'CrossPlatformIdentical'}else{'CrossPlatformVariant'}
            $derivedId=Get-C2CanonicalGroupId $first.matchStatus $derivedScope $first.equivalenceFingerprint $members
            if(@($first.missingMemberObjectIds).Count){if($first.proposedCanonicalAssetId-cne$derivedId){$fields.Add('proposedCanonicalAssetId')}}elseif($first.matchStatus-ceq'ExactDuplicate'){
                if($members.Count-lt2-or$contents.Count-ne1){$fields.Add('contentFingerprint')}elseif($first.platformScope-cne$derivedScope){$fields.Add('platformScope')}elseif($first.proposedCanonicalAssetId-cne$derivedId){$fields.Add('proposedCanonicalAssetId')}
            }elseif($first.matchStatus-ceq'ConfirmedVariant'){
                $variant=Get-C2VariantEquivalenceFingerprint $contents;if(($platforms-join',')-cne'Android,Pc'){$fields.Add('memberPlatform')}elseif($contents.Count-lt2){$fields.Add('contentFingerprint')}elseif($first.equivalenceFingerprint-cne$variant){$fields.Add('equivalenceFingerprint')}elseif($first.platformScope-cne$derivedScope){$fields.Add('platformScope')}elseif($first.proposedCanonicalAssetId-cne$derivedId){$fields.Add('proposedCanonicalAssetId')}
            }}
            $fieldSet=@(Get-C2OrdinalUnique $fields);$evidence=@(Get-C2OrdinalUnique @($rows.evidence));if($fieldSet.Count){$cid=Get-C2CanonicalConflictId $proposed $members $observations $fieldSet;$conflicts.Add([pscustomobject][ordered]@{canonicalConflictId=$cid;proposedCanonicalAssetIds=[string[]]$proposed;memberObjectIds=[string[]]$members;observationIds=[string[]]$observations;conflictingFields=[string[]]$fieldSet;evidence=[string[]]$evidence});$failures.Add((New-C2AccountingRow inputFailures CanonicalConflict $cid ConflictDetected "FT-09:$cid" $evidence));foreach($m in $members){$null=$conflicted.Add($m)}}else{$groups.Add([pscustomobject][ordered]@{canonicalAssetId=$derivedId;memberObjectIds=[string[]]$members;matchStatus=$first.matchStatus;platformScope=$derivedScope;equivalenceFingerprint=$first.equivalenceFingerprint;variantEvidence=if($first.matchStatus-ceq'ConfirmedVariant'){[string[]]$evidence}else{[string[]]@()}})}}
    }
    if(-not$conservationInvalid){foreach($o in $objects){if($conflicted.Contains([string]$o.assetObjectId)){continue};$group=@($groups|Where-Object{$_.memberObjectIds-ccontains$o.assetObjectId});if($group.Count-eq0){$scope=if($o.platformVariant-cin@('Pc','Android')){$o.platformVariant}else{'Unknown'};$groups.Add([pscustomobject][ordered]@{canonicalAssetId=$o.assetObjectId;memberObjectIds=[string[]]@($o.assetObjectId);matchStatus='Unresolved';platformScope=$scope;equivalenceFingerprint=$null;variantEvidence=[string[]]@()});$canonical=$o.assetObjectId}else{$canonical=$group[0].canonicalAssetId};$public.Add([pscustomobject][ordered]@{assetObjectId=$o.assetObjectId;canonicalAssetId=$canonical;sourceId=$o.sourceId;objectType=$o.objectType;objectName=$o.objectName;containerRelativePath=$o.containerRelativePath;classId=$o.classId;serializedSizeBytes=$o.serializedSizeBytes;dependencyObjectIds=$o.dependencyObjectIds;toolObservations=$o.toolObservations;platformVariant=$o.platformVariant;configurationDisposition=$o.configurationDisposition;evidence=$o.evidence;status=$o.status})}}
    $coverage=[pscustomobject][ordered]@{canonicalizedObjectCount=$public.Count;canonicalConflictObjectCount=$conflicted.Count;canonicalGroupCount=$groups.Count;exactDuplicateGroupCount=@($groups|Where-Object matchStatus -eq ExactDuplicate).Count;platformVariantGroupCount=@($groups|Where-Object matchStatus -eq ConfirmedVariant).Count;unresolvedCanonicalGroupCount=@($groups|Where-Object matchStatus -eq Unresolved).Count};$failed=$failures.Count-gt0
    [pscustomobject][ordered]@{canonicalGroups=[object[]]$groups;canonicalConflicts=[object[]]$conflicts;publicObjectsWithCanonicalId=[object[]]$public;inputFailures=[object[]]$failures;coverage=$coverage;gateStatus=if($failed){'Failed'}else{'Passed'};outputsSuppressed=$failed}
}

function Invoke-C2DispatchPartitions {
    [CmdletBinding()]
    param([Parameter(Mandatory)][psobject]$InputFact)

    $objects=@($InputFact.publicObjectsWithCanonicalId)
    $facts=@($InputFact.dispatchInputFacts)
    $priorFailures=@($InputFact.inputFailures)
    $checks=@($InputFact.contractChecks)
    $rows=[Collections.Generic.List[object]]::new()
    $failures=[Collections.Generic.List[object]]::new()
    foreach($failure in $priorFailures){$failures.Add($failure)}
    $blocked=$priorFailures.Count -gt 0 -or @($checks|Where-Object status -cne 'Accepted').Count -gt 0
    $joinInvalid=$false
    $publicNames=@('assetObjectId','canonicalAssetId','sourceId','objectType','objectName','containerRelativePath','classId','serializedSizeBytes','dependencyObjectIds','toolObservations','platformVariant','configurationDisposition','evidence','status')
    $factNames=@('assetObjectId','sp04Partition','privateConfigurationDisposition','configurationCandidateId')

    if(-not$blocked){
        try{
            if($objects.Count-ne$facts.Count){$joinInvalid=$true}
            $lastObject=$null;$lastFact=$null
            for($i=0;$i-lt$objects.Count;$i++){
                $object=$objects[$i]
                if((@($object.PSObject.Properties.Name)-join',')-cne($publicNames-join',')){$joinInvalid=$true;break}
                $id=[string]$object.assetObjectId
                if($id-cnotmatch'^sha256:[0-9a-f]{64}$'-or[string]::IsNullOrEmpty([string]$object.canonicalAssetId)-or[string]::IsNullOrEmpty([string]$object.sourceId)-or[string]::IsNullOrEmpty([string]$object.objectType)-or($object.classId-isnot[int]-and$object.classId-isnot[long])-or$object.dependencyObjectIds-isnot[object[]]-or$object.toolObservations-isnot[object[]]-or@($object.toolObservations).Count-eq0-or$object.evidence-isnot[object[]]){$joinInvalid=$true;break}
                if($null-ne$lastObject-and$script:Ordinal.Compare($lastObject,$id)-ge0){$joinInvalid=$true;break};$lastObject=$id
                foreach($path in @($object.evidence)){if(-not(Test-C2PortablePath ([string]$path))){$joinInvalid=$true}}
                foreach($tool in @($object.toolObservations)){if((@($tool.PSObject.Properties.Name)-join',')-cne'toolName,observation'-or[string]::IsNullOrEmpty([string]$tool.toolName)-or[string]::IsNullOrEmpty([string]$tool.observation)){$joinInvalid=$true}}
            }
            for($i=0;$i-lt$facts.Count;$i++){
                $fact=$facts[$i]
                if((@($fact.PSObject.Properties.Name)-join',')-cne($factNames-join',')){$joinInvalid=$true;break}
                $id=[string]$fact.assetObjectId
                if($id-cnotmatch'^sha256:[0-9a-f]{64}$'-or$fact.sp04Partition-cnotin@('Classified','Unclassified')){$joinInvalid=$true;break}
                if($null-ne$lastFact-and$script:Ordinal.Compare($lastFact,$id)-ge0){$joinInvalid=$true;break};$lastFact=$id
                $hasDisposition=$null-ne$fact.privateConfigurationDisposition
                if($hasDisposition-ne($null-ne$fact.configurationCandidateId)){$joinInvalid=$true;break}
                if($hasDisposition-and([string]::IsNullOrEmpty([string]$fact.privateConfigurationDisposition)-or$fact.configurationCandidateId-cne(Get-C2ConfigurationObjectId $id))){$joinInvalid=$true;break}
            }
            if(-not$joinInvalid){for($i=0;$i-lt$objects.Count;$i++){if($objects[$i].assetObjectId-cne$facts[$i].assetObjectId){$joinInvalid=$true;break}}}
        }catch{$joinInvalid=$true}
        if($joinInvalid){$failures.Add((New-C2AccountingRow inputFailures ConservationCheck 'C2Check:Conservation' ConservationMismatch 'FT-10:C2Check:Conservation' @('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json')));$blocked=$true}
    }

    if(-not$blocked){
        $laneKinds=[ordered]@{
            Audio=@('AudioClip','AudioMixer','WwiseBank','WwiseMedia')
            Environment=@('Scene','TerrainData','LightmapData','MeshRenderer')
            Actor=@('Avatar','AnimationClip','AnimatorController','SkinnedMeshRenderer')
            UI=@('Sprite','SpriteAtlas','Font','TMP_FontAsset','Canvas')
            Effects=@('ParticleSystem','VisualEffect','TrailRenderer')
        }
        for($i=0;$i-lt$objects.Count;$i++){
            $object=$objects[$i];$fact=$facts[$i];$lane='Unassigned';$status='RetainedForDiagnosis'
            if($null-ne$fact.privateConfigurationDisposition){$status='ConfigurationOnly'}
            elseif($fact.sp04Partition-ceq'Classified'){
                $matches=@($laneKinds.Keys|Where-Object{$laneKinds[$_] -ccontains [string]$object.objectType})
                if($matches.Count-eq1){$lane=$matches[0];$status='Assigned'}
            }
            $selectorPairs=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
            $selectors=[Collections.Generic.List[object]]::new()
            $addSelector={param([string]$kind,[string]$value)$key="$kind`n$value";if($selectorPairs.Add($key)){$selectors.Add([pscustomobject][ordered]@{kind=$kind;value=$value})}}.GetNewClosure()
            $null=$addSelector.Invoke('ObjectType',[string]$object.objectType)
            $null=$addSelector.Invoke('ClassId',([string]::Format([Globalization.CultureInfo]::InvariantCulture,'{0}',[long]$object.classId)))
            $null=$addSelector.Invoke('CanonicalAssetId',[string]$object.canonicalAssetId)
            $null=$addSelector.Invoke('PlatformVariant',[string]$object.platformVariant)
            foreach($dependency in @($object.dependencyObjectIds)){$null=$addSelector.Invoke('DependencyObjectId',[string]$dependency)}
            foreach($tool in @($object.toolObservations)){$null=$addSelector.Invoke('ToolObservation',[string]$tool.observation)}
            $selectors.Sort([Comparison[object]]{param($a,$b)$comparison=$script:Ordinal.Compare([string]$a.kind,[string]$b.kind);if($comparison-ne0){return $comparison};return $script:Ordinal.Compare([string]$a.value,[string]$b.value)})
            $evidence=Get-C2OrdinalUnique @($object.evidence)
            $rows.Add([pscustomobject][ordered]@{assetObjectId=$object.assetObjectId;canonicalAssetId=$object.canonicalAssetId;sourceId=$object.sourceId;familyLane=$lane;memberSelectorInputs=[object[]]$selectors;configurationCandidateId=$fact.configurationCandidateId;dispatchStatus=$status;evidence=[string[]]$evidence})
        }
    }

    $coverage=[pscustomobject][ordered]@{
        dispatchEligibleObjectCount=$rows.Count
        assignedObjectCount=@($rows|Where-Object dispatchStatus -ceq Assigned).Count
        retainedForDiagnosisObjectCount=@($rows|Where-Object dispatchStatus -ceq RetainedForDiagnosis).Count
        configurationOnlyObjectCount=@($rows|Where-Object dispatchStatus -ceq ConfigurationOnly).Count
        audioObjectCount=@($rows|Where-Object familyLane -ceq Audio).Count
        environmentObjectCount=@($rows|Where-Object familyLane -ceq Environment).Count
        actorObjectCount=@($rows|Where-Object familyLane -ceq Actor).Count
        uiObjectCount=@($rows|Where-Object familyLane -ceq UI).Count
        effectsObjectCount=@($rows|Where-Object familyLane -ceq Effects).Count
    }
    [pscustomobject][ordered]@{dispatchInputFacts=[object[]]$facts;dispatchRows=[object[]]$rows;inputFailures=[object[]]$failures;coverage=$coverage;gateStatus=if($blocked){'Failed'}else{'Passed'};outputsSuppressed=$blocked}
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
    $context=[ordered]@{facts=$null;handoff=$null;sp12=$null;sp03=$null;sp05=$null;sp06=$null;sp07=$null;sp07PriorFailureCount=0;events=[Collections.Generic.List[object]]::new();extractedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Extracted'));importedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Assets','StellaGaia','Imported'))}
    $registry=$script:Registry;$utf8=$script:Utf8;$fixtureValidator=${function:Test-C2FixtureContracts};$partitioner=${function:Invoke-C2FileDiscoveryPartitions};$objectPartitioner=${function:Invoke-C2ObjectObservationPartitions};$configurationPartitioner=${function:Invoke-C2ConfigurationPartitions};$canonicalPartitioner=${function:Invoke-C2CanonicalPartitions};$dispatchPartitioner=${function:Invoke-C2DispatchPartitions};$configurationObjectId=${function:Get-C2ConfigurationObjectId};$fixtureMutation=$FixtureMutator
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
            $acceptedRows=for($i=0;$i -lt 4;$i++){[pscustomobject][ordered]@{rowIndex=$i;observation=$documents['AR-I07'].rows[$i]}}
            $partitionInput=[pscustomobject][ordered]@{snapshotId=$documents['AR-I01'].snapshotId;inputFingerprint=$documents['AR-I01'].inputFingerprint;discoveryInputFingerprint=$null;c1Files=@($documents['AR-I02'].files);objectObservationArtifact=[pscustomobject][ordered]@{artifactPath=$registry[6].path;artifactSha256=$hashes['AR-I07'];acceptedRows=@($acceptedRows)};fileDiscoveryArtifact=[pscustomobject][ordered]@{artifactPath=$registry[7].path;artifactSha256=$hashes['AR-I08'];documentReadStatus='Parsed';document=$documents['AR-I08']}}
            $context.sp12=@($partitioner.Invoke($partitionInput))[0]
            if($context.sp12.gateStatus -ne 'Passed'){$first=@($context.sp12.inputFailures)[0];return [pscustomobject]@{status='Failed';owner=($first.attribution.Split(':')[0]);reason=$first.reasonCode;subjectId=$first.subjectId;message='SP-01/SP-02 failed'}}
            $sp03Input=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$documents['AR-I01'].snapshotId;inputFingerprint=$documents['AR-I01'].inputFingerprint;discoveryInputFingerprint=$null;sourceKinds=@($documents['AR-I02'].sources|ForEach-Object{[pscustomobject][ordered]@{sourceId=$_.sourceId;sourceKind=$_.sourceKind}});objectObservationArtifact=[pscustomobject][ordered]@{artifactPath=$registry[6].path;artifactSha256=$hashes['AR-I07'];documentReadStatus='Parsed';document=$documents['AR-I07']};exclusionApprovalArtifact=[pscustomobject][ordered]@{artifactPath=$registry[10].path;artifactSha256=$hashes['AR-I11'];documentReadStatus='Parsed';document=$documents['AR-I11']}}
            $context.sp03=@($objectPartitioner.Invoke($sp03Input))[0]
            $sp05Input=[pscustomobject]@{c1Files=@($documents['AR-I02'].files);mergedObjects=@($context.sp03.mergedObjects);fileConfigurationArtifact=[pscustomobject]@{artifactPath=$registry[8].path;artifactSha256=$null;documentReadStatus='Absent';document=$null}}
            $context.sp05=@($configurationPartitioner.Invoke($sp05Input))[0]
            $acceptedIds=@($context.sp03.observationSubjects|Where-Object partition -ceq 'AcceptedObservation'|ForEach-Object observationId);$nonNullIds=@($documents['AR-I07'].rows|Where-Object{$null-ne$_.canonicalEvidence-and$_.observationId-cin$acceptedIds}|ForEach-Object observationId)
            $context.sp06=@($canonicalPartitioner.Invoke([pscustomobject]@{publicObjectCores=@($context.sp03.publicObjectCores);canonicalProposalProvenance=@($context.sp03.canonicalProposalProvenance);acceptedNonNullCanonicalEvidenceObservationIds=$nonNullIds}))[0]
            $dispatchFacts=[Collections.Generic.List[object]]::new()
            foreach($publicObject in @($context.sp06.publicObjectsWithCanonicalId)){
                $merged=@($context.sp03.mergedObjects|Where-Object assetObjectId -ceq $publicObject.assetObjectId)[0]
                $core=@($context.sp03.publicObjectCores|Where-Object assetObjectId -ceq $publicObject.assetObjectId)[0]
                $privateDisposition=$merged.resolvedValues.configurationDisposition
                $dispatchFacts.Add([pscustomobject][ordered]@{assetObjectId=$publicObject.assetObjectId;sp04Partition=$core.sp04Partition;privateConfigurationDisposition=$privateDisposition;configurationCandidateId=if($null-ne$privateDisposition){@($configurationObjectId.Invoke([string]$publicObject.assetObjectId))[0]}else{$null}})
            }
            $priorFailures=@($context.sp03.inputFailures)+@($context.sp05.inputFailures)+@($context.sp06.inputFailures);$context.sp07PriorFailureCount=$priorFailures.Count
            $context.sp07=@($dispatchPartitioner.Invoke([pscustomobject]@{publicObjectsWithCanonicalId=@($context.sp06.publicObjectsWithCanonicalId);dispatchInputFacts=[object[]]$dispatchFacts;inputFailures=$priorFailures;contractChecks=@()}))[0]
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
    if($null -ne $context.sp03){
        $result.O1.inputFailures=[object[]]@($context.sp03.inputFailures);$result.O1.inputExclusions=[object[]]@($context.sp03.inputExclusions)
        $result.O2.inputSubjectCount += [int]$context.sp03.coverage.objectObservationRowCount + [int]$context.sp03.coverage.observationConflictRecordCount
        $result.O2.acceptedInputSubjectCount += [int]$context.sp03.coverage.acceptedObjectObservationRowCount
        $result.O2.inputFailureCount += [int]$context.sp03.coverage.inputFailureCount
        $result.O2.excludedInputSubjectCount += [int]$context.sp03.coverage.excludedInputCount
        $result.O2.issueCount += [int]$context.sp03.coverage.issueCount
        $result.O2|Add-Member -NotePropertyName objectObservationRowCount -NotePropertyValue ([int]$context.sp03.coverage.objectObservationRowCount)
        $result.O2|Add-Member -NotePropertyName acceptedObjectObservationRowCount -NotePropertyValue ([int]$context.sp03.coverage.acceptedObjectObservationRowCount)
        $result.O2|Add-Member -NotePropertyName rejectedObjectObservationRowCount -NotePropertyValue ([int]$context.sp03.coverage.rejectedObjectObservationRowCount)
        $result.O2|Add-Member -NotePropertyName excludedObjectObservationRowCount -NotePropertyValue ([int]$context.sp03.coverage.excludedObjectObservationRowCount)
        $result.O1|Add-Member -NotePropertyName objectObservationSubjects -NotePropertyValue ([object[]]$context.sp03.observationSubjects);$result.O1|Add-Member -NotePropertyName mergedObjects -NotePropertyValue ([object[]]$context.sp03.mergedObjects);$result.O1|Add-Member -NotePropertyName observationConflicts -NotePropertyValue ([object[]]$context.sp03.observationConflicts);$result.O1|Add-Member -NotePropertyName publicObjectCores -NotePropertyValue ([object[]]$context.sp03.publicObjectCores)
        if($context.sp03.gateStatus -ceq 'Failed'){$result.O2.status='Failed';$result.O2.discoveryInputFingerprint=$null;$result.O1.discoveryInputFingerprint=$null;$result.O1.decision.failureAttribution=$context.sp03.inputFailures[0].attribution;$result.O1.decision.nextAllowedAction='Correct fixture observation/conflict'}
    }
    if($null-ne$context.sp05){$result.O1|Add-Member -NotePropertyName configurationCandidates -NotePropertyValue ([object[]]$context.sp05.configurationCandidates);$result.O1|Add-Member -NotePropertyName configurationConflicts -NotePropertyValue ([object[]]$context.sp05.configurationConflicts);foreach($p in $context.sp05.coverage.PSObject.Properties){$result.O2|Add-Member -NotePropertyName $p.Name -NotePropertyValue ([int]$p.Value)};if($context.sp05.inputFailures.Count){$result.O1.inputFailures=[object[]]@($result.O1.inputFailures)+[object[]]@($context.sp05.inputFailures);$result.O2.inputSubjectCount += $context.sp05.inputFailures.Count;$result.O2.inputFailureCount += $context.sp05.inputFailures.Count;$result.O2.issueCount += $context.sp05.inputFailures.Count;$result.O2.status='Failed';$result.O2.discoveryInputFingerprint=$null;$result.O1.discoveryInputFingerprint=$null;$result.O1.decision.failureAttribution=$context.sp05.inputFailures[0].attribution;$result.O1.decision.nextAllowedAction='Correct file configuration observation/conflict'}}
    if($null-ne$context.sp06){$result.O1|Add-Member -NotePropertyName canonicalGroups -NotePropertyValue ([object[]]$context.sp06.canonicalGroups);$result.O1|Add-Member -NotePropertyName canonicalConflicts -NotePropertyValue ([object[]]$context.sp06.canonicalConflicts);$result.O1|Add-Member -NotePropertyName publicObjectsWithCanonicalId -NotePropertyValue ([object[]]$context.sp06.publicObjectsWithCanonicalId);foreach($p in $context.sp06.coverage.PSObject.Properties){$result.O2|Add-Member -NotePropertyName $p.Name -NotePropertyValue ([int]$p.Value)};if($context.sp06.inputFailures.Count){$result.O1.inputFailures=[object[]]@($result.O1.inputFailures)+[object[]]@($context.sp06.inputFailures);$result.O2.inputSubjectCount += $context.sp06.inputFailures.Count;$result.O2.inputFailureCount += $context.sp06.inputFailures.Count;$result.O2.issueCount += $context.sp06.inputFailures.Count;$result.O2.status='Failed';$result.O2.discoveryInputFingerprint=$null;$result.O1.discoveryInputFingerprint=$null;$result.O1.decision.failureAttribution=$context.sp06.inputFailures[0].attribution;$result.O1.decision.nextAllowedAction='Correct canonical proposal provenance/conflict'}}
    if($null-ne$context.sp07){$result.O1|Add-Member -NotePropertyName dispatchInputFacts -NotePropertyValue ([object[]]$context.sp07.dispatchInputFacts);$result.O1|Add-Member -NotePropertyName dispatchRows -NotePropertyValue ([object[]]$context.sp07.dispatchRows);foreach($p in $context.sp07.coverage.PSObject.Properties){$result.O2|Add-Member -NotePropertyName $p.Name -NotePropertyValue ([int]$p.Value)};if($context.sp07.inputFailures.Count-gt$context.sp07PriorFailureCount){$newFailures=@($context.sp07.inputFailures|Select-Object -Skip $context.sp07PriorFailureCount);$result.O1.inputFailures=[object[]]@($result.O1.inputFailures)+[object[]]$newFailures;$result.O2.inputSubjectCount += $newFailures.Count;$result.O2.inputFailureCount += $newFailures.Count;$result.O2.issueCount += $newFailures.Count;$result.O2.status='Failed';$result.O2.discoveryInputFingerprint=$null;$result.O1.discoveryInputFingerprint=$null;$result.O1.decision.failureAttribution=$newFailures[0].attribution;$result.O1.decision.nextAllowedAction='Correct SP-07 private dispatch join'}}
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
