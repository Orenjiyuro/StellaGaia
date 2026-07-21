[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'New-CergLo1Preflight.ps1')

$script:R2ProducerPath = $PSCommandPath
$script:R2Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Get-CergR2ProducerFileSha256 {
    param([Parameter(Mandatory = $true)][string]$LiteralPath)
    $stream = [System.IO.File]::Open($LiteralPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try { return ([Convert]::ToHexString($sha.ComputeHash($stream))).ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

function Get-CergR2ProducerStructuredSha256 {
    param([string]$DomainTag,[object]$Payload)
    $bytes=$script:R2Utf8NoBom.GetBytes((ConvertTo-CergPreflightCanonicalJson @($DomainTag,$Payload)))
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

function Get-CergR2ProducerImplementation {
    $item=[IO.FileInfo]::new($script:R2ProducerPath)
    $sha=Get-CergR2ProducerFileSha256 $script:R2ProducerPath
    $id='R2I-'+(Get-CergR2ProducerStructuredSha256 'cerg-r2/implementation-id/1' @('Producer','Tools/AssetImport/New-CergLo1R2Freshness.ps1',[int64]$item.Length,$sha))
    return [pscustomobject][ordered]@{implementationId=$id;role='Producer';portableRelativePath='Tools/AssetImport/New-CergLo1R2Freshness.ps1';byteCount=[int64]$item.Length;sha256=$sha}
}

function Get-CergR2ProducerSelectors {
    param([Parameter(Mandatory=$true)][object]$Candidate)
    $rows=[System.Collections.Generic.List[object]]::new()
    $seen=[System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach($member in @($Candidate.sourceMembers)){
        $sourceId=[string]$member.sourceId
        $path=([string]$member.portableRelativePath).Normalize([Text.NormalizationForm]::FormC).Replace('\','/')
        if([string]::IsNullOrWhiteSpace($sourceId)-or[string]::IsNullOrWhiteSpace($path)-or[IO.Path]::IsPathRooted($path)-or$path.IndexOfAny([char[]]'*?[]{}')-ge0-or$path.Split('/')-contains'..'){throw 'R2 selector is not one exact portable leaf.'}
        $key=$sourceId+[char]31+$path
        if(-not$seen.Add($key)){throw 'R2 selector is duplicated.'}
        $selectorId='R2S-'+(Get-CergR2ProducerStructuredSha256 'cerg-r2/source-selector-id/1' @($sourceId,$path))
        $rows.Add([pscustomobject][ordered]@{selectorId=$selectorId;sourceId=$sourceId;portableRelativePath=$path})
    }
    if($rows.Count-ne17){throw 'R2 requires exactly 17 source selectors.'}
    $array=[object[]]@($rows);[Array]::Sort($array,[System.Collections.Generic.Comparer[object]]::Create([System.Comparison[object]]{param($a,$b)[string]::CompareOrdinal([string]$a.selectorId,[string]$b.selectorId)}))
    return $array
}

function Get-CergR2ProducerRootMap {
    param([Parameter(Mandatory=$true)][object[]]$SourceRootBindings)
    $map=@{}
    foreach($binding in $SourceRootBindings){
        $id=[string]$binding.sourceId;$root=[string]$binding.privateAbsoluteReadOnlyRoot
        if([string]::IsNullOrWhiteSpace($id)-or-not[IO.Path]::IsPathRooted($root)-or$root.IndexOfAny([char[]]'*?[]{}')-ge0){throw 'R2 source root binding is invalid.'}
        $full=[IO.Path]::GetFullPath($root).TrimEnd('\','/')
        if(-not[IO.Directory]::Exists($full)-or$map.ContainsKey($id)){throw 'R2 source root binding is missing or duplicated.'}
        $map[$id]=$full
    }
    return $map
}

function Test-CergR2ProducerAncestorChain {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Leaf)
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\','/');$parent=[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Leaf))
    $rootAttributes=[IO.File]::GetAttributes($rootFull)
    if(($rootAttributes-band[IO.FileAttributes]::Directory)-eq0-or($rootAttributes-band[IO.FileAttributes]::ReparsePoint)-ne0){return $false}
    $relative=[IO.Path]::GetRelativePath($rootFull,$parent)
    if($relative-ceq'.'){return $true}
    $current=$rootFull
    foreach($segment in $relative.Split([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries)){
        $current=[IO.Path]::Combine($current,$segment)
        if(-not[IO.Directory]::Exists($current)){return $false}
        $attributes=[IO.File]::GetAttributes($current)
        if(($attributes-band[IO.FileAttributes]::Directory)-eq0-or($attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){return $false}
    }
    return $true
}

function Invoke-CergLo1R2FreshnessProducer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][object]$Candidate,
        [Parameter(Mandatory=$true)][string]$CandidateLockPath,
        [Parameter(Mandatory=$true)][object[]]$SourceRootBindings,
        [Parameter(Mandatory=$true)][string]$ContractHeadCommit,
        [Parameter(Mandatory=$true)][string]$CandidateLockSha256,
        [Parameter(Mandatory=$true)][string]$StartedAtUtc
    )
    if(-not[IO.File]::Exists($CandidateLockPath)-or(Get-CergR2ProducerFileSha256 $CandidateLockPath)-cne$CandidateLockSha256){throw'R2 candidate lock raw identity is missing or stale.'}
    $candidateFromDisk=[IO.File]::ReadAllText([IO.Path]::GetFullPath($CandidateLockPath),[Text.Encoding]::UTF8)|ConvertFrom-Json -Depth 100 -DateKind String
    if((ConvertTo-CergPreflightCanonicalJson $Candidate)-cne(ConvertTo-CergPreflightCanonicalJson $candidateFromDisk)){throw'R2 candidate object is spliced from candidate lock bytes.'}
    if($Candidate.schemaVersion-cne'cerg-t1-candidate-lock/2.2.0'-or$Candidate.artifactId-cne'CERG-T1V22-O01'-or$Candidate.status-cne'Passed'-or$Candidate.selectedCandidateId-cne'char_14401'-or$ContractHeadCommit-notmatch'^[0-9a-f]{40}$'-or$CandidateLockSha256-notmatch'^[0-9a-f]{64}$'){throw'R2 candidate/contract identity is invalid.'}
    $started=[DateTimeOffset]::Parse($StartedAtUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::AssumeUniversal).ToUniversalTime().ToString('O')
    $implementation=Get-CergR2ProducerImplementation
    $runId='R2RUN-'+(Get-CergR2ProducerStructuredSha256 'cerg-r2/check-run-id/1' @($ContractHeadCommit,$CandidateLockSha256,$started))
    $selectors=@(Get-CergR2ProducerSelectors $Candidate);$roots=Get-CergR2ProducerRootMap $SourceRootBindings
    $checks=[System.Collections.Generic.List[object]]::new()
    foreach($selector in $selectors){
        $checkId='R2C-'+(Get-CergR2ProducerStructuredSha256 'cerg-r2/leaf-check-id/1' @($runId,$implementation.implementationId,$selector.selectorId))
        $exists=$false;$kind='Missing';$reparse=$null;$count=$null;$hash=$null;$green=$false
        if($roots.ContainsKey([string]$selector.sourceId)){
            $root=[string]$roots[[string]$selector.sourceId]
            $leaf=[IO.Path]::GetFullPath([IO.Path]::Combine($root,([string]$selector.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar)))
            if($leaf.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)-and(Test-CergR2ProducerAncestorChain -Root $root -Leaf $leaf)){
                $exists=[IO.File]::Exists($leaf)
                if($exists){
                    $before=[IO.FileInfo]::new($leaf);$kind=$(if(($before.Attributes-band[IO.FileAttributes]::Directory)-eq0){'RegularFile'}else{'Other'})
                    $reparse=(($before.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0)
                    if($kind-ceq'RegularFile'-and-not$reparse){
                        $count=[int64]$before.Length;$hash=(Get-FileHash -Algorithm SHA256 -LiteralPath $leaf).Hash.ToLowerInvariant()
                        $after=[IO.FileInfo]::new($leaf)
                        $green=$after.Length-eq$count-and$after.LastWriteTimeUtc-eq$before.LastWriteTimeUtc
                    }
                }
            }
        }
        $checks.Add([pscustomobject][ordered]@{checkId=$checkId;implementationId=$implementation.implementationId;selectorId=$selector.selectorId;checkedAtUtc=[DateTimeOffset]::UtcNow.ToString('O');exists=$exists;fileKind=$kind;isReparsePoint=$reparse;observedByteCount=$count;observedSha256=$hash;status=$(if($green){'Green'}else{'FailedClosed'})})
    }
    $allGreen=@($checks|Where-Object status -cne 'Green').Count-eq0
    return [pscustomobject][ordered]@{schemaVersion='cerg-r2-producer-packet/1.0.0';contractHeadCommit=$ContractHeadCommit;candidateLockSha256=$CandidateLockSha256;checkRunId=$runId;producerImplementation=$implementation;startedAtUtc=$started;producerFinishedAtUtc=[DateTimeOffset]::UtcNow.ToString('O');sourceSelectors=$selectors;producerRows=@($checks);status=$(if($allGreen){'ProducerGreen'}else{'FailedClosed'})}
}
