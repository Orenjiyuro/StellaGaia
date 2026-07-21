[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$script:R2ValidatorPath=$PSCommandPath
$script:R2ValidatorUtf8=[Text.UTF8Encoding]::new($false)

function ConvertTo-CergR2ValidatorJson {
    param([AllowNull()][object]$Value)
    if($null-eq$Value){return 'null'};if($Value-is[string]){return [Text.Json.JsonSerializer]::Serialize([object]$Value.Normalize([Text.NormalizationForm]::FormC),[string],[Text.Json.JsonSerializerOptions]::new())}
    if($Value-is[bool]){return $(if($Value){'true'}else{'false'})};if($Value-is[int]-or$Value-is[long]){return [Convert]::ToString($Value,[Globalization.CultureInfo]::InvariantCulture)}
    if($Value-is[Collections.IDictionary]){$p=[Collections.Generic.List[string]]::new();foreach($k in $Value.Keys){$p.Add((ConvertTo-CergR2ValidatorJson ([string]$k))+':'+(ConvertTo-CergR2ValidatorJson $Value[$k]))};return '{'+($p-join',')+'}'}
    if($Value-is[pscustomobject]){$p=[Collections.Generic.List[string]]::new();foreach($x in $Value.PSObject.Properties){$p.Add((ConvertTo-CergR2ValidatorJson $x.Name)+':'+(ConvertTo-CergR2ValidatorJson $x.Value))};return ('{'+($p-join',')+'}')}
    if($Value-is[Collections.IEnumerable]){$p=[Collections.Generic.List[string]]::new();foreach($x in $Value){$p.Add((ConvertTo-CergR2ValidatorJson $x))};return ('['+($p-join',')+']')}
    throw "Unsupported validator JSON type $($Value.GetType().FullName)"
}
function Get-CergR2ValidatorSha {param([string]$Domain,[object]$Payload);$b=$script:R2ValidatorUtf8.GetBytes((ConvertTo-CergR2ValidatorJson @($Domain,$Payload)));return([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($b))).ToLowerInvariant()}
function Get-CergR2ValidatorFileHash {param([string]$Path);$s=[IO.File]::Open($Path,'Open','Read','Read');try{$h=[Security.Cryptography.SHA256]::Create();try{return([Convert]::ToHexString($h.ComputeHash($s))).ToLowerInvariant()}finally{$h.Dispose()}}finally{$s.Dispose()}}
function Get-CergR2ValidatorImplementation {
    $i=[IO.FileInfo]::new($script:R2ValidatorPath);$sha=Get-CergR2ValidatorFileHash $script:R2ValidatorPath;$id='R2I-'+(Get-CergR2ValidatorSha 'cerg-r2/implementation-id/1' @('IndependentValidator','Tools/AssetImport/Test-CergLo1R2Freshness.ps1',[int64]$i.Length,$sha))
    return [pscustomobject][ordered]@{implementationId=$id;role='IndependentValidator';portableRelativePath='Tools/AssetImport/Test-CergLo1R2Freshness.ps1';byteCount=[int64]$i.Length;sha256=$sha}
}
function Get-CergR2ValidatorRootMap {param([object[]]$Bindings);$m=@{};foreach($b in $Bindings){$id=[string]$b.sourceId;$r=[IO.Path]::GetFullPath([string]$b.privateAbsoluteReadOnlyRoot).TrimEnd('\','/');if(-not[IO.Directory]::Exists($r)-or$m.ContainsKey($id)){throw'Validator source binding invalid.'};$m[$id]=$r};return $m}
function Invoke-CergLo1R2FreshnessValidator {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$ProducerPacket,[Parameter(Mandatory=$true)][object[]]$SourceRootBindings,[Parameter(Mandatory=$true)][object[]]$FixedCounterexamples,[Parameter(Mandatory=$true)][object[]]$SuccessPathChecks,[Parameter(Mandatory=$true)][object[]]$PostSuccessAttackChecks)
    if($ProducerPacket.schemaVersion-cne'cerg-r2-producer-packet/1.0.0'-or@($ProducerPacket.sourceSelectors).Count-ne17){throw'Producer packet schema/count invalid.'}
    $implementation=Get-CergR2ValidatorImplementation;if($implementation.sha256-ceq$ProducerPacket.producerImplementation.sha256-or$implementation.portableRelativePath-ceq$ProducerPacket.producerImplementation.portableRelativePath){throw'Producer and validator are not independent identities.'}
    $roots=Get-CergR2ValidatorRootMap $SourceRootBindings;$rows=[Collections.Generic.List[object]]::new()
    foreach($selector in @($ProducerPacket.sourceSelectors)){
        $checkId='R2C-'+(Get-CergR2ValidatorSha 'cerg-r2/leaf-check-id/1' @($ProducerPacket.checkRunId,$implementation.implementationId,$selector.selectorId))
        $exists=$false;$kind='Missing';$reparse=$null;$count=$null;$hash=$null;$green=$false
        if($roots.ContainsKey([string]$selector.sourceId)){
            $root=$roots[[string]$selector.sourceId];$leaf=[IO.Path]::GetFullPath([IO.Path]::Combine($root,([string]$selector.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar)))
            if($leaf.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){
                $exists=[IO.File]::Exists($leaf)
                if($exists){$before=[IO.FileInfo]::new($leaf);$attr=$before.Attributes;$kind=$(if(($attr-band[IO.FileAttributes]::Directory)-eq0){'RegularFile'}else{'Other'});$reparse=(($attr-band[IO.FileAttributes]::ReparsePoint)-ne0)
                    if($kind-ceq'RegularFile'-and-not$reparse){$count=[int64]$before.Length;$stamp=$before.LastWriteTimeUtc;$stream=[IO.File]::Open($leaf,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);try{$sha=[Security.Cryptography.SHA256]::Create();try{$hash=([Convert]::ToHexString($sha.ComputeHash($stream))).ToLowerInvariant()}finally{$sha.Dispose()}}finally{$stream.Dispose()};$after=[IO.FileInfo]::new($leaf);$green=($after.Length-eq$count-and$after.LastWriteTimeUtc-eq$stamp)}
                }
            }
        }
        $rows.Add([pscustomobject][ordered]@{checkId=$checkId;implementationId=$implementation.implementationId;selectorId=$selector.selectorId;checkedAtUtc=[DateTimeOffset]::UtcNow.ToString('O');exists=$exists;fileKind=$kind;isReparsePoint=$reparse;observedByteCount=$count;observedSha256=$hash;status=$(if($green){'Green'}else{'FailedClosed'})})
    }
    $producerBy=@{};foreach($r in @($ProducerPacket.producerRows)){$producerBy[[string]$r.selectorId]=$r}
    $agree=$true;$members=[Collections.Generic.List[object]]::new()
    foreach($r in @($rows)){$p=$producerBy[[string]$r.selectorId];if($null -eq $p -or $p.status -cne 'Green' -or $r.status -cne 'Green' -or $p.exists -ne $r.exists -or $p.fileKind -cne $r.fileKind -or $p.isReparsePoint -ne $r.isReparsePoint -or ([int64]$p.observedByteCount) -ne ([int64]$r.observedByteCount) -or $p.observedSha256 -cne $r.observedSha256){$agree=$false;continue};$s=@($ProducerPacket.sourceSelectors|Where-Object selectorId -CEQ $r.selectorId)[0];$mid='R2M-'+(Get-CergR2ValidatorSha 'cerg-r2/current-member-id/1' @($s.sourceId,$s.portableRelativePath,[int64]$r.observedByteCount,$r.observedSha256));$members.Add([pscustomobject][ordered]@{memberId=$mid;selectorId=$s.selectorId;sourceId=$s.sourceId;portableRelativePath=$s.portableRelativePath;byteCount=[int64]$r.observedByteCount;sha256=$r.observedSha256})}
    $testRows=@($FixedCounterexamples)+@($SuccessPathChecks)+@($PostSuccessAttackChecks);$testsGreen=($testRows.Count -eq 18 -and @($testRows|Where-Object status -cne 'Passed').Count -eq 0)
    $green=($agree -and $members.Count -eq 17 -and $testsGreen)
    $sorted=[object[]]@($members);[Array]::Sort($sorted,[Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{param($a,$b)[string]::CompareOrdinal([string]$a.memberId,[string]$b.memberId)}))
    $fingerprint=$(if($green){Get-CergR2ValidatorSha 'cerg-r2/current-source-member-set/1' @($sorted)}else{$null})
    $allCheckIds=@(@($ProducerPacket.producerRows|ForEach-Object checkId)+@($rows|ForEach-Object checkId));[Array]::Sort($allCheckIds,[StringComparer]::Ordinal)
    $implementationIds=@([string]$ProducerPacket.producerImplementation.implementationId,[string]$implementation.implementationId);[Array]::Sort($implementationIds,[StringComparer]::Ordinal)
    $fixedIds=@($FixedCounterexamples|ForEach-Object testId);$successIds=@($SuccessPathChecks|ForEach-Object testId);$attackIds=@($PostSuccessAttackChecks|ForEach-Object testId)
    $claims=@('All17LeavesExist','All17LeavesRegular','All17LeavesNonReparse','All17SizesObserved','All17HashesObserved','ProducerValidatorAgree','FreshnessRunComplete','ConstructorConsumerSchemaExact','CounterexamplesPassed','PostSuccessAttackPassed')|ForEach-Object{
        $refs=switch($_){
            {$_-in@('All17LeavesExist','All17LeavesRegular','All17LeavesNonReparse','All17SizesObserved','All17HashesObserved','ProducerValidatorAgree')}{$allCheckIds;break}
            'FreshnessRunComplete'{@($implementationIds+$allCheckIds);break}
            'ConstructorConsumerSchemaExact'{@($implementationIds+$successIds);break}
            'CounterexamplesPassed'{@($implementationIds+$fixedIds);break}
            'PostSuccessAttackPassed'{@($implementationIds+$attackIds);break}
        }
        [pscustomobject][ordered]@{claimId=$_;status=$(if($green){'Green'}else{'FailedClosed'});evidenceRefIds=$(if($green){$refs}else{@()})}
    }
    return [pscustomobject][ordered]@{schemaVersion='cerg-lo-cerg1-r2-freshness/1.0.0';artifactId='LO-CERG1-R2-F01';contractHeadCommit=$ProducerPacket.contractHeadCommit;candidateLockSha256=$ProducerPacket.candidateLockSha256;checkRunId=$ProducerPacket.checkRunId;producerImplementation=$ProducerPacket.producerImplementation;validatorImplementation=$implementation;startedAtUtc=$ProducerPacket.startedAtUtc;producerFinishedAtUtc=$ProducerPacket.producerFinishedAtUtc;validatorFinishedAtUtc=[DateTimeOffset]::UtcNow.ToString('O');sourceSelectors=@($ProducerPacket.sourceSelectors);producerRows=@($ProducerPacket.producerRows);validatorRows=@($rows);currentMembers=$(if($green){$sorted}else{@()});currentMemberSetFingerprint=$fingerprint;fixedCounterexamples=@($FixedCounterexamples);successPathChecks=@($SuccessPathChecks);postSuccessAttackChecks=@($PostSuccessAttackChecks);greenClaims=@($claims);status=$(if($green){'Green'}else{'FailedClosed'});nextAction=$(if($green){'RequestExactHumanConfirmationForR2'}else{'ReturnToTotalControlAudit_NoLO'})}
}

function Assert-CergLo1R2FreshnessArtifact {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Artifact,[Parameter(Mandatory=$true)][object[]]$SourceRootBindings,[int]$MaxAgeSeconds=300)
    $top=@('schemaVersion','artifactId','contractHeadCommit','candidateLockSha256','checkRunId','producerImplementation','validatorImplementation','startedAtUtc','producerFinishedAtUtc','validatorFinishedAtUtc','sourceSelectors','producerRows','validatorRows','currentMembers','currentMemberSetFingerprint','fixedCounterexamples','successPathChecks','postSuccessAttackChecks','greenClaims','status','nextAction')
    if((@($Artifact.PSObject.Properties.Name)-join'|')-cne($top-join'|')){throw'Freshness artifact fields/order invalid.'}
    if($Artifact.schemaVersion-cne'cerg-lo-cerg1-r2-freshness/1.0.0'-or$Artifact.artifactId-cne'LO-CERG1-R2-F01'-or$Artifact.status-cne'Green'-or$Artifact.nextAction-cne'RequestExactHumanConfirmationForR2'){throw'Freshness artifact fixed state invalid.'}
    if($Artifact.producerImplementation.role-cne'Producer'-or$Artifact.validatorImplementation.role-cne'IndependentValidator'-or$Artifact.producerImplementation.sha256-ceq$Artifact.validatorImplementation.sha256-or$Artifact.producerImplementation.portableRelativePath-ceq$Artifact.validatorImplementation.portableRelativePath){throw'Freshness implementation independence invalid.'}
    $finished=[DateTimeOffset]::Parse([string]$Artifact.validatorFinishedAtUtc).ToUniversalTime()
    if(([DateTimeOffset]::UtcNow-$finished).TotalSeconds -gt $MaxAgeSeconds -or $finished -lt [DateTimeOffset]::Parse([string]$Artifact.producerFinishedAtUtc).ToUniversalTime()){throw'Freshness run is stale or time order invalid.'}
    if(@($Artifact.sourceSelectors).Count-ne17-or@($Artifact.producerRows).Count-ne17-or@($Artifact.validatorRows).Count-ne17-or@($Artifact.currentMembers).Count-ne17){throw'Freshness 17-row conservation invalid.'}
    $selectorById=@{};foreach($selector in @($Artifact.sourceSelectors)){$expectedSelectorId='R2S-'+(Get-CergR2ValidatorSha 'cerg-r2/source-selector-id/1' @($selector.sourceId,$selector.portableRelativePath));if($selector.selectorId-cne$expectedSelectorId-or$selectorById.ContainsKey([string]$selector.selectorId)){throw'Source selector identity invalid or duplicate.'};$selectorById[[string]$selector.selectorId]=$selector}
    $validIds=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $null=$validIds.Add([string]$Artifact.producerImplementation.implementationId);$null=$validIds.Add([string]$Artifact.validatorImplementation.implementationId)
    foreach($r in @($Artifact.producerRows)+@($Artifact.validatorRows)){if($r.status -cne 'Green' -or -not $validIds.Add([string]$r.checkId)){throw'Freshness check row invalid or duplicate.'}}
    $expectedFixed=@('R2-CE01-Missing','R2-CE02-Directory','R2-CE03-Reparse','R2-CE04-ByteDrift','R2-CE05-EqualSizeHashDrift','R2-CE06-SelectorConservation','R2-CE07-IndependentDisagreement','R2-CE08-StaleRun','R2-CE09-HiddenField','R2-CE10-ProducerSplice')
    $expectedSuccess=@('R2-SP01-ProductionConstructor','R2-SP02-IndependentValidator','R2-SP03-StagingConsumer')
    $expectedAttack=@('R2-AT01-SelectorMutation','R2-AT02-TupleMutation','R2-AT03-EvidenceMutation','R2-AT04-TimeMutation','R2-AT05-ImplementationMutation')
    foreach($pair in @(@($Artifact.fixedCounterexamples,$expectedFixed),@($Artifact.successPathChecks,$expectedSuccess),@($Artifact.postSuccessAttackChecks,$expectedAttack))){
        $actual=@($pair[0]);$expected=@($pair[1]);if((@($actual|ForEach-Object testId)-join'|') -cne ($expected-join'|') -or @($actual|Where-Object status -cne 'Passed').Count -ne 0){throw'Freshness test partition invalid.'}
        foreach($r in $actual){$null=$validIds.Add([string]$r.testId);$refs=@($r.evidenceRefIds);if($refs.Count-ne2-or-not($refs -contains [string]$Artifact.producerImplementation.implementationId)-or-not($refs -contains [string]$Artifact.validatorImplementation.implementationId)){throw'Test row lacks the exact independent implementation evidence pair.'}}
    }
    $expectedClaims=@('All17LeavesExist','All17LeavesRegular','All17LeavesNonReparse','All17SizesObserved','All17HashesObserved','ProducerValidatorAgree','FreshnessRunComplete','ConstructorConsumerSchemaExact','CounterexamplesPassed','PostSuccessAttackPassed')
    if((@($Artifact.greenClaims|ForEach-Object claimId)-join'|')-cne($expectedClaims-join'|')){throw'Green claim identities invalid.'}
    foreach($claim in @($Artifact.greenClaims)){if($claim.status -cne 'Green' -or @($claim.evidenceRefIds).Count -lt 2){throw'Green claim lacks direct evidence.'};foreach($id in @($claim.evidenceRefIds)){if(-not $validIds.Contains([string]$id)){throw'Green claim evidence does not resolve.'}}}
    $roots=Get-CergR2ValidatorRootMap $SourceRootBindings;$members=[object[]]@($Artifact.currentMembers)
    foreach($member in $members){
        if(-not$selectorById.ContainsKey([string]$member.selectorId)){throw'Current member selector reference missing.'};$selector=$selectorById[[string]$member.selectorId];if($member.sourceId-cne$selector.sourceId-or$member.portableRelativePath-cne$selector.portableRelativePath){throw'Current member selector tuple differs.'}
        if(-not$roots.ContainsKey([string]$member.sourceId)){throw'Current member source binding missing.'}
        $root=$roots[[string]$member.sourceId];$leaf=[IO.Path]::GetFullPath([IO.Path]::Combine($root,([string]$member.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar)))
        if(-not $leaf.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($leaf)){throw'Current member leaf missing.'}
        $attr=[IO.File]::GetAttributes($leaf);if(($attr-band[IO.FileAttributes]::Directory)-ne0-or($attr-band[IO.FileAttributes]::ReparsePoint)-ne0){throw'Current member is not a regular non-reparse leaf.'}
        $sha=Get-CergR2ValidatorFileHash $leaf;$len=[IO.FileInfo]::new($leaf).Length
        if(([int64]$member.byteCount) -ne $len -or $member.sha256 -cne $sha){throw'Current member identity changed.'}
        $mid='R2M-'+(Get-CergR2ValidatorSha 'cerg-r2/current-member-id/1' @($member.sourceId,$member.portableRelativePath,[int64]$member.byteCount,$member.sha256));if($member.memberId-cne$mid){throw'Current member ID invalid.'}
    }
    $sorted=[object[]]@($members);[Array]::Sort($sorted,[Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{param($a,$b)[string]::CompareOrdinal([string]$a.memberId,[string]$b.memberId)}))
    if($Artifact.currentMemberSetFingerprint-cne(Get-CergR2ValidatorSha 'cerg-r2/current-source-member-set/1' @($sorted))){throw'Current member-set fingerprint invalid.'}
    return $true
}
