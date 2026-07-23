[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:MbacrProducerUtf8 = [Text.UTF8Encoding]::new($false)
$script:MbacrProducerPath = $PSCommandPath

function ConvertTo-MbacrProducerCanonicalJson {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [string]) { return [Text.Json.JsonSerializer]::Serialize([object](([string]$Value).Normalize([Text.NormalizationForm]::FormC)),[string],[Text.Json.JsonSerializerOptions]::new()) }
    if ($Value -is [bool]) { return $(if ($Value) { 'true' } else { 'false' }) }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64]) { return [Convert]::ToString($Value,[Globalization.CultureInfo]::InvariantCulture) }
    if ($Value -is [Collections.IDictionary]) {
        $parts=[Collections.Generic.List[string]]::new(); foreach($key in $Value.Keys){$parts.Add((ConvertTo-MbacrProducerCanonicalJson ([string]$key))+':'+(ConvertTo-MbacrProducerCanonicalJson $Value[$key]))}; return '{'+($parts -join ',')+'}'
    }
    if ($Value -is [pscustomobject]) {
        $parts=[Collections.Generic.List[string]]::new(); foreach($property in $Value.PSObject.Properties){$parts.Add((ConvertTo-MbacrProducerCanonicalJson $property.Name)+':'+(ConvertTo-MbacrProducerCanonicalJson $property.Value))}; return '{'+($parts -join ',')+'}'
    }
    if ($Value -is [Collections.IEnumerable]) {
        $parts=[Collections.Generic.List[string]]::new(); foreach($item in $Value){$parts.Add((ConvertTo-MbacrProducerCanonicalJson $item))}; return '['+($parts -join ',')+']'
    }
    throw "Unsupported canonical JSON type: $($Value.GetType().FullName)"
}

function Get-MbacrProducerStructuredHash {
    param([string]$Domain,[object]$Payload)
    $bytes=$script:MbacrProducerUtf8.GetBytes((ConvertTo-MbacrProducerCanonicalJson @($Domain,$Payload)))
    return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}
function Get-MbacrProducerCanonicalHash {param([object]$Value);return([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:MbacrProducerUtf8.GetBytes((ConvertTo-MbacrProducerCanonicalJson $Value))))).ToLowerInvariant()}

function Get-MbacrProducerFileHash {
    param([string]$Path)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try { $sha=[Security.Cryptography.SHA256]::Create(); try { return ([Convert]::ToHexString($sha.ComputeHash($stream))).ToLowerInvariant() } finally { $sha.Dispose() } } finally { $stream.Dispose() }
}

function Test-MbacrProducerAncestorChain {
    param([string]$Root,[string]$Leaf)
    $canonicalRoot=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    $rootInfo=[IO.DirectoryInfo]::new($canonicalRoot); $rootInfo.Refresh()
    if (-not $rootInfo.Exists -or ($rootInfo.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { return $false }
    $cursor=$rootInfo.Parent
    while($null -ne $cursor){$cursor.Refresh();if(-not $cursor.Exists -or ($cursor.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){return $false};$cursor=$cursor.Parent}
    $canonicalLeaf=[IO.Path]::GetFullPath($Leaf)
    if(-not $canonicalLeaf.StartsWith($canonicalRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){return $false}
    $parent=[IO.DirectoryInfo]::new([IO.Path]::GetDirectoryName($canonicalLeaf))
    while($parent.FullName -cne $canonicalRoot){$parent.Refresh();if(-not$parent.Exists-or($parent.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){return $false};$parent=$parent.Parent;if($null-eq$parent){return $false}}
    return $true
}

function Get-MbacrProducerRootBinding {
    param([string]$SourceId,[string]$Root)
    $canonical=[IO.Path]::GetFullPath($Root).TrimEnd('\','/')
    if(-not(Test-MbacrProducerAncestorChain -Root $canonical -Leaf (Join-Path $canonical '__mbacr_probe__'))){throw 'Source root or ancestor chain is invalid/reparse.'}
    return [pscustomobject][ordered]@{sourceId=$SourceId;privateAbsoluteReadOnlyRoot=$canonical;rootFingerprint=(Get-MbacrProducerStructuredHash 'mbacr/source-root/1' @($SourceId,$canonical))}
}

function Get-MbacrProducerBinding {
    param([object]$SourceRootBinding,[string[]]$OrderedArgumentTokens)
    $file=[IO.FileInfo]::new($script:MbacrProducerPath);$sha=Get-MbacrProducerFileHash $file.FullName
    $runtime=[Diagnostics.Process]::GetCurrentProcess().MainModule.FileName;$runtimeFile=[IO.FileInfo]::new($runtime);$runtimeSha=Get-MbacrProducerFileHash $runtime
    $artifactId='MBACR-TG01';$role='ControllerLocatorProducer';$portable='Tools/AssetImport/Invoke-MbacrControllerLocator.ps1';$version='MBACR-CONTROLLER-LOCATOR/1'
    $runtimeProduct=[string]$runtimeFile.VersionInfo.ProductName;$runtimeVersion=[string]$runtimeFile.VersionInfo.FileVersion
    $id='MBACRIMP-'+(Get-MbacrProducerStructuredHash 'mbacr/locator-implementation/1' @($artifactId,$role,$portable,$version,[int64]$file.Length,$sha,$runtimeProduct,$runtimeVersion,[int64]$runtimeFile.Length,$runtimeSha))
    return [pscustomobject][ordered]@{artifactId=$artifactId;implementationId=$id;role=$role;portableTrackedPath=$portable;implementationVersion=$version;byteCount=[int64]$file.Length;sha256=$sha;runtimeProduct=$runtimeProduct;runtimeVersion=$runtimeVersion;runtimeByteCount=[int64]$runtimeFile.Length;runtimeSha256=$runtimeSha;sourceRootBinding=$SourceRootBinding;orderedArgumentTokens=@($OrderedArgumentTokens)}
}

function Test-MbacrProducerExactObject {
    param([object]$Actual,[object]$Expected)
    return (ConvertTo-MbacrProducerCanonicalJson $Actual) -ceq (ConvertTo-MbacrProducerCanonicalJson $Expected)
}

function Install-MbacrLocatorAttempt {
    param([object]$Attempt,[string]$FinalPath)
    $full=[IO.Path]::GetFullPath($FinalPath);$temp=$full+'.tmp';$parent=[IO.Path]::GetDirectoryName($full)
    [IO.Directory]::CreateDirectory($parent)|Out-Null
    if([IO.File]::Exists($full)-or[IO.File]::Exists($temp)){throw 'Locator attempt already exists or has interrupted temporary state.'}
    $bytes=$script:MbacrProducerUtf8.GetBytes((ConvertTo-MbacrProducerCanonicalJson $Attempt))
    $stream=[IO.File]::Open($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
    [IO.File]::Move($temp,$full,$false)
    $reopen=[IO.File]::ReadAllBytes($full)
    $expectedHash=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant();$actualHash=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($reopen))).ToLowerInvariant()
    if($reopen.Length-ne$bytes.Length-or$actualHash-cne$expectedHash){throw 'Locator attempt canonical reopen mismatch.'}
    return [pscustomobject]@{Path=$full;ByteCount=[int64]$reopen.Length;Sha256=(Get-MbacrProducerFileHash $full)}
}

function Assert-MbacrProducerLimits {
    param([object]$Limits)
    $expected=[pscustomobject][ordered]@{maxFilesRead=2;maxBytesRead=[int64]33554432;maxDurationSeconds=600;maxResultRows=32;maxChildProcesses=0}
    if(-not(Test-MbacrProducerExactObject $Limits $expected)){throw 'Producer locator limits do not equal the fixed contract.'}
}

function Install-MbacrProducerCanonicalArtifact {
    param([object]$Artifact,[string]$FinalPath)
    $full=[IO.Path]::GetFullPath($FinalPath);$temp=$full+'.tmp';[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($full))|Out-Null
    if([IO.File]::Exists($full)-or[IO.File]::Exists($temp)){throw 'Canonical artifact final or temporary path already exists.'}
    $bytes=$script:MbacrProducerUtf8.GetBytes((ConvertTo-MbacrProducerCanonicalJson $Artifact));$stream=[IO.File]::Open($temp,'CreateNew','Write','None')
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
    [IO.File]::Move($temp,$full,$false);$reopen=[IO.File]::ReadAllBytes($full);$sha=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($reopen))).ToLowerInvariant()
    if($reopen.Length-ne$bytes.Length-or$sha-cne([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()){throw 'Canonical artifact reopen identity mismatch.'}
    $reopened=$script:MbacrProducerUtf8.GetString($reopen)|ConvertFrom-Json -Depth 100 -DateKind String
    if(-not(Test-MbacrProducerExactObject $reopened $Artifact)){throw 'Canonical artifact reopened object mismatch.'}
    return [pscustomobject][ordered]@{Path=$full;ByteCount=[int64]$reopen.Length;Sha256=$sha;Object=$reopened}
}

function Get-MbacrProducerInputArtifactRefs {
    param([string]$RepositoryRoot,[object[]]$ExpectedRows,[string]$ReadinessPath,[string]$ReadinessSha256)
    if(@($ExpectedRows).Count-ne2){throw 'Exactly two fixed MBACR evidence registry rows are required.'}
    $expectedIds=@('MBACR-I01','MBACR-I02');$rows=[Collections.Generic.List[object]]::new()
    for($i=0;$i-lt$expectedIds.Count;$i++){$row=@($ExpectedRows)[$i];if($row.artifactId-cne$expectedIds[$i]-or(@($row.PSObject.Properties.Name)-join'|')-cne'artifactId|portableRelativePath|byteCount|sha256'){throw 'Input artifact reference shape/order mismatch.'}
        $leaf=[IO.Path]::GetFullPath((Join-Path $RepositoryRoot ([string]$row.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar)))
        if(-not[IO.File]::Exists($leaf)){throw 'Input artifact leaf is absent.'};$info=[IO.FileInfo]::new($leaf);$sha=Get-MbacrProducerFileHash $leaf
        if([int64]$row.byteCount-ne[int64]$info.Length-or$row.sha256-cne$sha){throw 'Input artifact identity mismatch.'}
        $rows.Add([pscustomobject][ordered]@{artifactId=$row.artifactId;portableRelativePath=$row.portableRelativePath;byteCount=[int64]$info.Length;sha256=$sha})
    }
    $readinessInfo=[IO.FileInfo]::new([IO.Path]::GetFullPath($ReadinessPath));if(-not$readinessInfo.Exists-or$ReadinessSha256-cne(Get-MbacrProducerFileHash $readinessInfo.FullName)){throw 'TO03 input artifact identity mismatch.'}
    $rows.Add([pscustomobject][ordered]@{artifactId='MBACR-TO03';portableRelativePath='Extracted/CERG/SingleCharacter/Recovery-BaseController/tooling-readiness-03.json';byteCount=[int64]$readinessInfo.Length;sha256=$ReadinessSha256})
    return @($rows)
}

function Get-MbacrProducerInputArtifactRegistryFingerprint {
    param([object[]]$Rows)
    $expectedIds=@('MBACR-I01','MBACR-I02')
    if(@($Rows).Count-ne$expectedIds.Count){throw 'Exactly two fixed MBACR evidence registry rows are required.'}
    $tuples=[Collections.Generic.List[object]]::new()
    for($i=0;$i-lt$expectedIds.Count;$i++){
        $row=@($Rows)[$i]
        if((@($row.PSObject.Properties.Name)-join'|')-cne'artifactId|portableRelativePath|byteCount|sha256'-or$row.artifactId-cne$expectedIds[$i]-or[string]::IsNullOrWhiteSpace([string]$row.portableRelativePath)-or[int64]$row.byteCount-lt0-or$row.sha256-notmatch'^[0-9a-f]{64}$'){throw 'Input artifact registry shape, order, or identity is invalid.'}
        $tuples.Add(@([string]$row.artifactId,[string]$row.portableRelativePath,[int64]$row.byteCount,[string]$row.sha256))
    }
    return Get-MbacrProducerStructuredHash 'mbacr/input-artifact-registry/1' @($tuples)
}

function Assert-MbacrProducerReadiness {
    param([object]$Readiness,[string]$ReadinessSha256,[object]$ProducerBinding,[object]$ValidatorBinding)
    $ids=@('MBACR-CE01-FilenameOnly','MBACR-CE02-RawStringOnly','MBACR-CE03-MissingLeaf','MBACR-CE04-AncestorReparse','MBACR-CE05-DuplicateObject','MBACR-CE06-ParserDisagreement','MBACR-CE07-LimitExceeded','MBACR-CE08-MultipleControllersOneSelector','MBACR-CE09-NonCanonicalFailureRejected','MBACR-CE10-LocatorReadWithoutAllowance','MBACR-CE11-WrongRoot','MBACR-CE12-ArgumentTamper','MBACR-CE13-AttemptReuseOrInterruption','MBACR-SP01-ParsedController')
    if((@($Readiness.PSObject.Properties.Name)-join'|')-cne'schemaVersion|artifactId|contractHeadCommit|toolRows|testRows|status|failures|nextAction'){throw 'TO03 top-level shape/order invalid.'}
    if($Readiness.schemaVersion-cne'cerg-mbacr-tooling-readiness/1.2.0'-or$Readiness.artifactId-cne'MBACR-TO03'-or$Readiness.contractHeadCommit-notmatch'^[0-9a-f]{40}$'-or$Readiness.status-cne'Green'-or@($Readiness.failures).Count-ne0-or$Readiness.nextAction-cne'AwaitTotalControlAuditBeforeMBACRT1B'){throw 'TO03 fixed state invalid.'}
    if($ReadinessSha256-cne(Get-MbacrProducerCanonicalHash $Readiness)){throw 'TO03 canonical SHA mismatch.'}
    $toolRows=@([pscustomobject][ordered]@{artifactId=$ProducerBinding.artifactId;role=$ProducerBinding.role;portableTrackedPath=$ProducerBinding.portableTrackedPath;implementationVersion=$ProducerBinding.implementationVersion;byteCount=[int64]$ProducerBinding.byteCount;sha256=$ProducerBinding.sha256},[pscustomobject][ordered]@{artifactId=$ValidatorBinding.artifactId;role=$ValidatorBinding.role;portableTrackedPath=$ValidatorBinding.portableTrackedPath;implementationVersion=$ValidatorBinding.implementationVersion;byteCount=[int64]$ValidatorBinding.byteCount;sha256=$ValidatorBinding.sha256})
    if(-not(Test-MbacrProducerExactObject @($Readiness.toolRows) $toolRows)){throw 'TO03 tool identities do not equal current committed tools.'}
    foreach($row in @($Readiness.testRows)){if((@($row.PSObject.Properties.Name)-join'|')-cne'testId|status|evidenceLocator'-or[string]::IsNullOrEmpty([string]$row.evidenceLocator)){throw 'TO03 test row shape invalid.'}}
    if((@($Readiness.testRows|ForEach-Object testId)-join'|')-cne($ids-join'|')-or@($Readiness.testRows|Where-Object status -cne 'Passed').Count-ne0){throw 'TO03 fixed test matrix is not Green.'}
}

if(-not ('MbacrProducerBinaryParser' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Collections.Generic;

public sealed class MbacrProducerController {
    public string SerializedFileName { get; set; }
    public int SerializedFileOrdinal { get; set; }
    public int ObjectOrdinal { get; set; }
    public long ObjectId { get; set; }
    public string Name { get; set; }
}

public static class MbacrProducerBinaryParser {
    sealed class Cursor {
        public readonly byte[] B; public int P; public readonly bool Little;
        public Cursor(byte[] b,int p=0,bool little=false){B=b;P=p;Little=little;}
        void Need(int n){if(n<0||P<0||P+n>B.Length)throw new InvalidDataException("Unexpected end of binary structure.");}
        public byte U8(){Need(1);return B[P++];}
        public ushort U16(){Need(2);ushort v=Little?(ushort)(B[P]|B[P+1]<<8):(ushort)(B[P]<<8|B[P+1]);P+=2;return v;}
        public uint U32(){Need(4);uint v=Little?(uint)(B[P]|B[P+1]<<8|B[P+2]<<16|B[P+3]<<24):(uint)(B[P]<<24|B[P+1]<<16|B[P+2]<<8|B[P+3]);P+=4;return v;}
        public long I64(){Need(8);ulong v=0;if(Little){for(int i=7;i>=0;i--)v=(v<<8)|B[P+i];}else{for(int i=0;i<8;i++)v=(v<<8)|B[P+i];}P+=8;return unchecked((long)v);}
        public ulong U64(){return unchecked((ulong)I64());}
        public string Z(){int s=P;while(P<B.Length&&B[P]!=0)P++;if(P>=B.Length)throw new InvalidDataException("Unterminated string.");string x=Encoding.UTF8.GetString(B,s,P-s);P++;return x;}
        public void Skip(int n){Need(n);P+=n;} public void Align4(){P=(P+3)&~3;Need(0);}
    }
    sealed class Node { public long Offset,Size; public string Name; }
    static byte[] Lz4(byte[] src,int expected){var dst=new byte[expected];int s=0,d=0;while(s<src.Length){int token=src[s++];int lit=token>>4;if(lit==15){int x;do{if(s>=src.Length)throw new InvalidDataException("LZ4 literal overflow.");x=src[s++];lit+=x;}while(x==255);}if(s+lit>src.Length||d+lit>dst.Length)throw new InvalidDataException("LZ4 literal bounds.");Buffer.BlockCopy(src,s,dst,d,lit);s+=lit;d+=lit;if(s==src.Length)break;if(s+2>src.Length)throw new InvalidDataException("LZ4 offset missing.");int off=src[s]|src[s+1]<<8;s+=2;if(off<=0||off>d)throw new InvalidDataException("LZ4 offset invalid.");int len=(token&15)+4;if((token&15)==15){int x;do{if(s>=src.Length)throw new InvalidDataException("LZ4 match overflow.");x=src[s++];len+=x;}while(x==255);}if(d+len>dst.Length)throw new InvalidDataException("LZ4 match bounds.");for(int i=0;i<len;i++)dst[d+i]=dst[d-off+i];d+=len;}if(d!=expected)throw new InvalidDataException("LZ4 size mismatch.");return dst;}
    static byte[] Decode(byte[] src,int mode,int expected){if(mode==0){if(src.Length!=expected)throw new InvalidDataException("Stored block size mismatch.");return src;}if(mode==2||mode==3)return Lz4(src,expected);throw new InvalidDataException("Unsupported UnityFS compression mode.");}
    static List<Node> OpenUnityFs(byte[] file,out byte[] data){var h=new Cursor(file);if(h.Z()!="UnityFS")throw new InvalidDataException("Not UnityFS.");uint fmt=h.U32();if(fmt<6)throw new InvalidDataException("Unsupported UnityFS format.");h.Z();h.Z();long declared=h.I64();uint cInfo=h.U32(),uInfo=h.U32(),flags=h.U32();if(declared!=file.LongLength)throw new InvalidDataException("UnityFS declared size mismatch.");if((flags&0x200)!=0)h.P=(h.P+15)&~15;int infoPos=(flags&0x80)!=0?checked(file.Length-(int)cInfo):h.P;if(infoPos<0||infoPos+cInfo>file.Length)throw new InvalidDataException("UnityFS block info bounds.");byte[] ci=new byte[cInfo];Buffer.BlockCopy(file,infoPos,ci,0,(int)cInfo);byte[] info=Decode(ci,(int)(flags&0x3f),(int)uInfo);int blockPos=(flags&0x80)!=0?h.P:checked(h.P+(int)cInfo);var r=new Cursor(info);r.Skip(16);uint bc=r.U32();var output=new MemoryStream();for(uint i=0;i<bc;i++){uint us=r.U32(),cs=r.U32();ushort bf=r.U16();if(blockPos+cs>file.Length)throw new InvalidDataException("UnityFS block bounds.");byte[] packed=new byte[cs];Buffer.BlockCopy(file,blockPos,packed,0,(int)cs);blockPos+=(int)cs;byte[] plain=Decode(packed,bf&0x3f,(int)us);output.Write(plain,0,plain.Length);}uint nc=r.U32();var nodes=new List<Node>();for(uint i=0;i<nc;i++){long o=r.I64(),n=r.I64();r.U32();string name=r.Z();if(o<0||n<0||o+n>output.Length)throw new InvalidDataException("UnityFS node bounds.");nodes.Add(new Node{Offset=o,Size=n,Name=name});}data=output.ToArray();return nodes;}
    static List<MbacrProducerController> Serialized(byte[] bytes,string name,int fileOrdinal){var be=new Cursor(bytes);uint meta=be.U32();be.U32();uint version=be.U32();be.U32();if(version<9)throw new InvalidDataException("Serialized file version unsupported.");byte endian=be.U8();be.Skip(3);long dataOffset;if(version>=22){meta=be.U32();be.I64();dataOffset=be.I64();be.I64();}else{var again=new Cursor(bytes);again.U32();again.U32();again.U32();dataOffset=again.U32();}if(meta==0||dataOffset<be.P||dataOffset>bytes.LongLength)throw new InvalidDataException("Serialized header invalid.");var m=new Cursor(bytes,be.P,endian==0);if(version>=7)m.Z();if(version>=8)m.U32();bool tree=version>=13&&m.U8()!=0;int tc=checked((int)m.U32());if(tc<0||tc>100000)throw new InvalidDataException("Serialized type count invalid.");var classes=new List<int>();for(int i=0;i<tc;i++){int cid=unchecked((int)m.U32());classes.Add(cid);if(version>=16)m.U8();if(version>=17)m.U16();if(version>=13){if((version<16&&cid<0)||cid==114)m.Skip(16);m.Skip(16);}if(tree){int nodes=checked((int)m.U32()),strings=checked((int)m.U32());int nodeSize=version>=19?32:24;m.Skip(checked(nodes*nodeSize+strings));}}if(version>=7&&version<14)m.U32();int oc=checked((int)m.U32());if(oc<0||oc>1000000)throw new InvalidDataException("Serialized object count invalid.");var seen=new HashSet<long>();var found=new List<MbacrProducerController>();for(int i=0;i<oc;i++){if(version>=14)m.Align4();long pid=version<14?unchecked((int)m.U32()):m.I64();long start=version>=22?checked((long)m.U64()):m.U32();uint size=m.U32();int type=unchecked((int)m.U32());if(version<16)m.U16();if(version<11)m.U16();if(version>=11&&version<17)m.U16();if(version==15)m.U8();if(!seen.Add(pid))throw new InvalidDataException("Duplicate serialized object ID.");if(type<0||type>=classes.Count)throw new InvalidDataException("Serialized type index invalid.");if(start<0||dataOffset+start+size>bytes.LongLength)throw new InvalidDataException("Serialized object bounds.");if(classes[type]==91)found.Add(new MbacrProducerController{SerializedFileName=name,SerializedFileOrdinal=fileOrdinal,ObjectOrdinal=i,ObjectId=pid,Name=""});}return found;}
    public static MbacrProducerController[] Parse(byte[] file){byte[] data;List<Node> nodes=OpenUnityFs(file,out data);var all=new List<MbacrProducerController>();for(int i=0;i<nodes.Count;i++){var n=nodes[i];byte[] b=new byte[n.Size];Buffer.BlockCopy(data,(int)n.Offset,b,0,(int)n.Size);try{all.AddRange(Serialized(b,n.Name,i));}catch(InvalidDataException){if(n.Name.EndsWith(".resource",StringComparison.OrdinalIgnoreCase)||n.Name.EndsWith(".resS",StringComparison.OrdinalIgnoreCase))continue;throw;}}return all.ToArray();}
}
'@
}

function Assert-MbacrProducerAttempt {
    param([object]$Attempt,[string]$AttemptSha256,[object]$RootBinding,[object]$Binding,[object[]]$SelectorRows)
    if($Attempt.schemaVersion-cne'cerg-mbacr-locator-attempt/1.2.0'-or$Attempt.artifactId-cne'MBACR-A00'-or$Attempt.status-cne'ArmedNoSourceOpen'-or$Attempt.nextAction-cne'RunExactFourLocatorOpens'-or[int]$Attempt.allowanceUsedBeforeInstall-ne0-or[int]$Attempt.allowanceUsedAfterInstall-ne1){throw 'Locator attempt fixed state invalid.'}
    if(-not(Test-MbacrProducerExactObject $Attempt.sourceRootBinding $RootBinding)-or-not(Test-MbacrProducerExactObject $Attempt.producerBinding $Binding)){throw 'Locator attempt root or producer binding mismatch.'}
    if($AttemptSha256-cne(Get-MbacrProducerCanonicalHash $Attempt)){throw 'Locator attempt canonical SHA mismatch.'}
    $expectedPlan=@($SelectorRows|ForEach-Object{[pscustomobject][ordered]@{selectorId=$_.selectorId;sourceId=$_.sourceId;portableRelativePath=$_.portableRelativePath}});if(-not(Test-MbacrProducerExactObject @($Attempt.selectorPlan) $expectedPlan)){throw 'Locator attempt selector plan mismatch.'};$SelectorIds=@($expectedPlan|ForEach-Object selectorId)
    $auth=$Attempt.locatorAuthorization
    $argsHash=Get-MbacrProducerStructuredHash 'mbacr/locator-arguments/1' @($Attempt.producerBinding.orderedArgumentTokens,$Attempt.validatorBinding.orderedArgumentTokens)
    if($auth.to03Sha256-cne$Attempt.to03Sha256-or$auth.inputArtifactRegistryFingerprint-cne$Attempt.inputArtifactRegistryFingerprint-or$auth.sourceId-cne$RootBinding.sourceId-or$auth.rootFingerprint-cne$RootBinding.rootFingerprint-or$auth.producerImplementationId-cne$Binding.implementationId-or$auth.validatorImplementationId-cne$Attempt.validatorBinding.implementationId-or$auth.orderedArgumentTokensFingerprint-cne$argsHash-or(@($auth.selectorIds)-join'|')-cne($SelectorIds-join'|')-or[int]$auth.maxProducerSourceOpens-ne2-or[int]$auth.maxValidatorSourceOpens-ne2-or[int]$auth.maxTotalSourceOpens-ne4-or-not[bool]$auth.noLO){throw 'Locator authorization mismatch.'}
    $expected='MBACRLOC-'+(Get-MbacrProducerStructuredHash 'mbacr/locator-authorization/4' @($auth.to03Sha256,$auth.inputArtifactRegistryFingerprint,$auth.sourceId,$auth.rootFingerprint,$auth.producerImplementationId,$auth.validatorImplementationId,$auth.orderedArgumentTokensFingerprint,@($auth.selectorIds),[int]$auth.maxProducerSourceOpens,[int]$auth.maxValidatorSourceOpens,[int]$auth.maxTotalSourceOpens,[bool]$auth.noLO))
    if($auth.authorizationId-cne$expected){throw 'Locator authorization ID mismatch.'}
}

function Invoke-MbacrControllerLocatorProducer {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][object]$Attempt,[Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$AttemptSha256,[Parameter(Mandatory=$true)][object[]]$SelectorRows,[Parameter(Mandatory=$true)][string]$SourceRoot,[Parameter(Mandatory=$true)][string[]]$OrderedArgumentTokens,[Parameter(Mandatory=$true)][object]$Limits)
    if(@($SelectorRows).Count-ne2){throw 'Producer requires exactly two selectors.'};Assert-MbacrProducerLimits $Limits
    $root=Get-MbacrProducerRootBinding 'pc-install' $SourceRoot;$binding=Get-MbacrProducerBinding $root $OrderedArgumentTokens
    Assert-MbacrProducerAttempt $Attempt $AttemptSha256 $root $binding $SelectorRows
    $started=[DateTimeOffset]::UtcNow;$total=[int64]0;$resultCount=0;$results=[Collections.Generic.List[object]]::new();$opens=[Collections.Generic.List[object]]::new()
    for($i=0;$i-lt2;$i++){$selector=$SelectorRows[$i];$leaf=[IO.Path]::GetFullPath((Join-Path $root.privateAbsoluteReadOnlyRoot ([string]$selector.portableRelativePath).Replace('/',[IO.Path]::DirectorySeparatorChar)));$status='InvalidCurrentLeaf';$count=$null;$hash=$null;$controllers=@();$detail=$null
        if(-not(Test-MbacrProducerAncestorChain $root.privateAbsoluteReadOnlyRoot $leaf)){$detail='AncestorReparse'}elseif(-not[IO.File]::Exists($leaf)){$detail=$(if([IO.Directory]::Exists($leaf)){'NonRegularLeaf'}else{'MissingLeaf'})}else{$info=[IO.FileInfo]::new($leaf);if(($info.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){$detail='LeafReparse'}else{$stream=[IO.File]::Open($leaf,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);try{$bytes=New-Object byte[] $stream.Length;$read=0;while($read-lt$bytes.Length){$n=$stream.Read($bytes,$read,$bytes.Length-$read);if($n-le0){throw 'Unexpected EOF'};$read+=$n}}finally{$stream.Dispose()};$count=[int64]$bytes.Length;$hash=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant();$total+=$count;if($total-gt[int64]$Limits.maxBytesRead){$detail='BytesReadExceeded'}else{try{$controllers=@([MbacrProducerBinaryParser]::Parse($bytes));$prospectiveResultCount=$resultCount+@($controllers).Count;if($prospectiveResultCount-gt[int]$Limits.maxResultRows){$controllers=@();$detail='ResultRowsExceeded'}else{$resultCount=$prospectiveResultCount;$status=$(if($controllers.Count){'Located'}else{'NotLocated'})}}catch{$detail='MalformedSerializedContainer'}};$opens.Add([pscustomobject][ordered]@{implementationArtifactId='MBACR-TG01';implementationId=$binding.implementationId;selectorId=$selector.selectorId;sourceId=$selector.sourceId;portableRelativePath=$selector.portableRelativePath;openedAtUtc=[DateTimeOffset]::UtcNow.ToString('O');byteCount=$count;sha256=$hash})}}
        $results.Add([pscustomobject][ordered]@{selectorId=$selector.selectorId;sourceId=$selector.sourceId;portableRelativePath=$selector.portableRelativePath;currentByteCount=$count;currentSha256=$hash;status=$status;detailCode=$detail;controllers=@($controllers)})
    }
    if(([DateTimeOffset]::UtcNow-$started).TotalSeconds-gt[int]$Limits.maxDurationSeconds){throw 'Producer locator duration exceeded.'}
    return [pscustomobject][ordered]@{schemaVersion='cerg-mbacr-producer-packet/1.0.0';artifactId='MBACR-PRODUCER-PACKET';attemptSha256=$AttemptSha256;rootBinding=$root;producerBinding=$binding;selectorResults=@($results);producerOpenRows=@($opens);status=$(if(@($results|Where-Object status -ceq 'InvalidCurrentLeaf').Count){'FailedClosed'}else{'Complete'})}
}

function Invoke-MbacrControllerLocatorForegroundCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][object[]]$SelectorRows,
        [Parameter(Mandatory=$true)][string[]]$ProducerOrderedArgumentTokens,
        [Parameter(Mandatory=$true)][string[]]$ValidatorOrderedArgumentTokens,
        [Parameter(Mandatory=$true)][object]$Limits,
        [Parameter(Mandatory=$true)][object[]]$InputArtifactRegistry,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRLOC-[0-9a-f]{64}$')][string]$ExactAuthorizationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactTo03Sha256,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactInputArtifactRegistryFingerprint,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactRootFingerprint,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRIMP-[0-9a-f]{64}$')][string]$ExactProducerImplementationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRIMP-[0-9a-f]{64}$')][string]$ExactValidatorImplementationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactArgumentsFingerprint
    )
    $repo=[IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/');$toolRepositoryRoot=[IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($script:MbacrProducerPath)))).TrimEnd('\','/')
    if($repo-cne$toolRepositoryRoot){throw 'RepositoryRoot does not equal the repository root containing TG01.'}
    $recoveryRel='Extracted/CERG/SingleCharacter/Recovery-BaseController';$recovery=Join-Path $repo $recoveryRel
    $readinessPath=Join-Path $recovery 'tooling-readiness-03.json';$attemptPath=Join-Path $recovery 'T1/locator-attempt.json';$resultPath=Join-Path $recovery 'T1/controller-location.json'
    if([IO.File]::Exists($attemptPath)-or[IO.File]::Exists($attemptPath+'.tmp')){throw 'MBACR-A00 final or temporary state already exists; source reads and retries are forbidden.'}
    if([IO.File]::Exists($resultPath)-or[IO.File]::Exists($resultPath+'.tmp')){throw 'MBACR-L01 final or temporary state already exists.'}
    Assert-MbacrProducerLimits $Limits;$fixedSelectors=@([pscustomobject][ordered]@{selectorId='MBACR-S01';sourceId='pc-install';portableRelativePath='Persistent_Store/AssetBundles/actor_common.unity3d';ledgerByteCount=[int64]10821270;ledgerSha256='8c485e107b27b5ff6862c79c61ba683eae7c46ed5fdd8afb203e8ff7de6dcf64'},[pscustomobject][ordered]@{selectorId='MBACR-S02';sourceId='pc-install';portableRelativePath='xtlr_Data/StreamingAssets/InstallResource/actor_common.unity3d';ledgerByteCount=[int64]10777435;ledgerSha256='d66c4c505e3e577319dc776f76ac5a471487181b4fa9396e57bc2308639464fb'})
    if(-not(Test-MbacrProducerExactObject @($SelectorRows) $fixedSelectors)){throw 'Fixed selector tuples mismatch.'}
    $validatorPath=Join-Path $toolRepositoryRoot 'Tools/AssetImport/Test-MbacrControllerLocation.ps1';if(-not[IO.File]::Exists($validatorPath)){throw 'Independent validator tool is absent.'}
    if(-not(Get-Command Get-MbacrValidatorBinding -ErrorAction SilentlyContinue)){. $validatorPath}
    if([IO.Path]::GetFullPath($script:MbacrValidatorPath)-cne[IO.Path]::GetFullPath($validatorPath)){throw 'Loaded validator path mismatch.'}
    $root=Get-MbacrProducerRootBinding 'pc-install' $SourceRoot;$producerBinding=Get-MbacrProducerBinding $root $ProducerOrderedArgumentTokens;$validatorBinding=Get-MbacrValidatorBinding $root $ValidatorOrderedArgumentTokens
    if($root.rootFingerprint-cne$ExactRootFingerprint-or$producerBinding.implementationId-cne$ExactProducerImplementationId-or$validatorBinding.implementationId-cne$ExactValidatorImplementationId){throw 'Exact root or implementation authorization mismatch.'}
    $argumentsFingerprint=Get-MbacrProducerStructuredHash 'mbacr/locator-arguments/1' @($ProducerOrderedArgumentTokens,$ValidatorOrderedArgumentTokens);if($argumentsFingerprint-cne$ExactArgumentsFingerprint){throw 'Exact argument authorization mismatch.'}
    if(-not[IO.File]::Exists($readinessPath)){throw 'MBACR-TO03 is absent.'};$readinessBytes=[IO.File]::ReadAllBytes($readinessPath);$readinessSha=([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($readinessBytes))).ToLowerInvariant();if($readinessSha-cne$ExactTo03Sha256){throw 'Exact TO03 authorization mismatch.'}
    $readiness=$script:MbacrProducerUtf8.GetString($readinessBytes)|ConvertFrom-Json -Depth 100 -DateKind String;Assert-MbacrProducerReadiness $readiness $readinessSha $producerBinding $validatorBinding
    $registryFingerprint=Get-MbacrProducerInputArtifactRegistryFingerprint $InputArtifactRegistry
    if($registryFingerprint-cne$ExactInputArtifactRegistryFingerprint){throw 'Exact input artifact registry authorization mismatch.'}
    $verifiedInputs=Get-MbacrProducerInputArtifactRefs $repo $InputArtifactRegistry $readinessPath $readinessSha
    $auth=[pscustomobject][ordered]@{authorizationId=$ExactAuthorizationId;to03Sha256=$readinessSha;inputArtifactRegistryFingerprint=$registryFingerprint;sourceId='pc-install';rootFingerprint=$root.rootFingerprint;producerImplementationId=$producerBinding.implementationId;validatorImplementationId=$validatorBinding.implementationId;orderedArgumentTokensFingerprint=$argumentsFingerprint;selectorIds=@('MBACR-S01','MBACR-S02');maxProducerSourceOpens=2;maxValidatorSourceOpens=2;maxTotalSourceOpens=4;noLO=$true}
    $calculatedAuthorizationId='MBACRLOC-'+(Get-MbacrProducerStructuredHash 'mbacr/locator-authorization/4' @($auth.to03Sha256,$auth.inputArtifactRegistryFingerprint,$auth.sourceId,$auth.rootFingerprint,$auth.producerImplementationId,$auth.validatorImplementationId,$auth.orderedArgumentTokensFingerprint,@($auth.selectorIds),2,2,4,$true));if($auth.authorizationId-cne$calculatedAuthorizationId){throw 'Exact locator authorization ID mismatch.'}
    $plan=@($SelectorRows|ForEach-Object{[pscustomobject][ordered]@{selectorId=$_.selectorId;sourceId=$_.sourceId;portableRelativePath=$_.portableRelativePath}})
    $attempt=[pscustomobject][ordered]@{schemaVersion='cerg-mbacr-locator-attempt/1.2.0';artifactId='MBACR-A00';contractHeadCommit=$readiness.contractHeadCommit;to03Sha256=$readinessSha;inputArtifactRegistryFingerprint=$registryFingerprint;locatorAuthorization=$auth;sourceRootBinding=$root;producerBinding=$producerBinding;validatorBinding=$validatorBinding;selectorPlan=$plan;allowanceUsedBeforeInstall=0;allowanceUsedAfterInstall=1;status='ArmedNoSourceOpen';nextAction='RunExactFourLocatorOpens'}
    $installedAttempt=Install-MbacrProducerCanonicalArtifact $attempt $attemptPath;$attemptSha=$installedAttempt.Sha256
    $producerPacket=Invoke-MbacrControllerLocatorProducer -Attempt $installedAttempt.Object -AttemptSha256 $attemptSha -SelectorRows $SelectorRows -SourceRoot $SourceRoot -OrderedArgumentTokens $ProducerOrderedArgumentTokens -Limits $Limits
    $synthetic=Invoke-MbacrControllerLocatorValidator -Attempt $installedAttempt.Object -AttemptSha256 $attemptSha -ProducerPacket $producerPacket -SelectorRows $SelectorRows -SourceRoot $SourceRoot -OrderedArgumentTokens $ValidatorOrderedArgumentTokens -Limits $Limits
    $formal=[pscustomobject][ordered]@{schemaVersion='cerg-mbacr-controller-location/1.2.0';artifactId='MBACR-L01';contractHeadCommit=$readiness.contractHeadCommit;inputArtifactRefs=@($verifiedInputs);locatorAttemptRef=[pscustomobject][ordered]@{artifactId='MBACR-A00';portableRelativePath="$recoveryRel/T1/locator-attempt.json";byteCount=[int64]$installedAttempt.ByteCount;sha256=$attemptSha};locatorAuthorization=$synthetic.locatorAuthorization;sourceRootBinding=$synthetic.sourceRootBinding;selectorRows=@($synthetic.selectorRows);locationRows=@($synthetic.locationRows);openRows=@($synthetic.openRows);openCounts=$synthetic.openCounts;partitions=$synthetic.partitions;limits=$synthetic.limits;producerBinding=$synthetic.producerBinding;validatorBinding=$synthetic.validatorBinding;status=$synthetic.status;failures=@($synthetic.failures);nextAction=$synthetic.nextAction}
    $installedResult=Install-MbacrProducerCanonicalArtifact $formal $resultPath
    if($installedResult.Object.artifactId-cne'MBACR-L01'-or$installedResult.Object.locatorAttemptRef.sha256-cne$attemptSha-or-not(Test-MbacrProducerExactObject $installedResult.Object $formal)){throw 'Formal MBACR-L01 reopen validation failed.'}
    return [pscustomobject][ordered]@{artifact=$installedResult.Object;path=$installedResult.Path;byteCount=$installedResult.ByteCount;sha256=$installedResult.Sha256;attemptPath=$installedAttempt.Path;attemptByteCount=$installedAttempt.ByteCount;attemptSha256=$attemptSha}
}

function Invoke-MbacrControllerLocatorForegroundRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RepositoryRoot,
        [Parameter(Mandatory=$true)][string]$SourceRoot,
        [Parameter(Mandatory=$true)][object[]]$SelectorRows,
        [Parameter(Mandatory=$true)][string[]]$ProducerOrderedArgumentTokens,
        [Parameter(Mandatory=$true)][string[]]$ValidatorOrderedArgumentTokens,
        [Parameter(Mandatory=$true)][object]$Limits,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRLOC-[0-9a-f]{64}$')][string]$ExactAuthorizationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactTo03Sha256,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactInputArtifactRegistryFingerprint,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactRootFingerprint,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRIMP-[0-9a-f]{64}$')][string]$ExactProducerImplementationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^MBACRIMP-[0-9a-f]{64}$')][string]$ExactValidatorImplementationId,
        [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ExactArgumentsFingerprint
    )
    $fixedRegistry=@(
        [pscustomobject][ordered]@{artifactId='MBACR-I01';portableRelativePath='Extracted/CERG/SingleCharacter/LO-CERG1-R2/R01-P06/result.json';byteCount=[int64]1171925;sha256='8a1a9826966666c426605a3bf0c4c8f1c62101a9d36bd65d9456732c38b2a92c'},
        [pscustomobject][ordered]@{artifactId='MBACR-I02';portableRelativePath='Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json';byteCount=[int64]11792761;sha256='4f28737b77aaf94dcd79272d37f9041144e913e9222f90f311236cb8f6a14fe8'}
    )
    return Invoke-MbacrControllerLocatorForegroundCore -RepositoryRoot $RepositoryRoot -SourceRoot $SourceRoot -SelectorRows $SelectorRows -ProducerOrderedArgumentTokens $ProducerOrderedArgumentTokens -ValidatorOrderedArgumentTokens $ValidatorOrderedArgumentTokens -Limits $Limits -InputArtifactRegistry $fixedRegistry -ExactAuthorizationId $ExactAuthorizationId -ExactTo03Sha256 $ExactTo03Sha256 -ExactInputArtifactRegistryFingerprint $ExactInputArtifactRegistryFingerprint -ExactRootFingerprint $ExactRootFingerprint -ExactProducerImplementationId $ExactProducerImplementationId -ExactValidatorImplementationId $ExactValidatorImplementationId -ExactArgumentsFingerprint $ExactArgumentsFingerprint
}
