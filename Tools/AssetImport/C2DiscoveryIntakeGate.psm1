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
$script:RequiredHashes=@('548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac','acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462','c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1','b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c','9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6','8c9fdb6e50c620d1b8d8835cb6435c653b3398f5616340f5945ad643364af1ec')
$script:MissingProjectionFields=@()
$script:OutputRegistry=@(
    [pscustomobject][ordered]@{artifactId='AR-O01';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'}
    [pscustomobject][ordered]@{artifactId='AR-O02';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json'}
    [pscustomobject][ordered]@{artifactId='AR-O03';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json'}
    [pscustomobject][ordered]@{artifactId='AR-O04';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json'}
    [pscustomobject][ordered]@{artifactId='AR-O05-Report';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-report.md'}
    [pscustomobject][ordered]@{artifactId='AR-O05-Sidecar';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json'}
    [pscustomobject][ordered]@{artifactId='AR-S12';path='Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json'}
    [pscustomobject][ordered]@{artifactId='AR-O05-Summary';path='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json'}
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

function Get-C2OrdinalUnique {
    param([object[]]$Values)
    $items=[Collections.Generic.List[string]]::new();foreach($value in $Values){if(-not $items.Contains([string]$value)){$items.Add([string]$value)}};$items.Sort($script:Ordinal);[string[]]$items
}

function ConvertTo-C2JsonString {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Value)
    $builder=[Text.StringBuilder]::new();$null=$builder.Append('"')
    for($i=0;$i-lt$Value.Length;$i++){
        $code=[int][char]$Value[$i]
        switch($code){
            8{$null=$builder.Append('\b');continue};9{$null=$builder.Append('\t');continue};10{$null=$builder.Append('\n');continue};12{$null=$builder.Append('\f');continue};13{$null=$builder.Append('\r');continue};34{$null=$builder.Append('\"');continue};92{$null=$builder.Append('\\');continue}
        }
        if($code-lt32){$null=$builder.Append(('\u{0:x4}'-f$code));continue}
        if($code-ge0xD800-and$code-le0xDBFF){if($i+1-ge$Value.Length-or[int][char]$Value[$i+1]-lt0xDC00-or[int][char]$Value[$i+1]-gt0xDFFF){throw 'Invalid CT-15 Unicode scalar.'};$null=$builder.Append($Value[$i]);$i++;$null=$builder.Append($Value[$i]);continue}
        if($code-ge0xDC00-and$code-le0xDFFF){throw 'Invalid CT-15 Unicode scalar.'}
        $null=$builder.Append($Value[$i])
    }
    $null=$builder.Append('"');$builder.ToString()
}

function ConvertTo-C2JsonFragment {
    param([AllowNull()]$Value,[int]$Depth)
    if($null-eq$Value){return 'null'}
    if($Value-is[bool]){if($Value){return 'true'}else{return 'false'}}
    if($Value-is[string]){return ConvertTo-C2JsonString $Value}
    if($Value-is[byte]-or$Value-is[sbyte]-or$Value-is[int16]-or$Value-is[uint16]-or$Value-is[int32]-or$Value-is[uint32]-or$Value-is[int64]-or$Value-is[uint64]){return [Convert]::ToString($Value,[Globalization.CultureInfo]::InvariantCulture)}
    $indent='  '*$Depth;$childIndent='  '*($Depth+1)
    if($Value-is[pscustomobject]){
        $properties=@($Value.PSObject.Properties)
        if($properties.Count-eq0){return '{}'}
        $parts=[Collections.Generic.List[string]]::new();foreach($property in $properties){$parts.Add("$childIndent$(ConvertTo-C2JsonString $property.Name): $(ConvertTo-C2JsonFragment $property.Value ($Depth+1))")}
        return "{`n$($parts-join",`n")`n$indent}"
    }
    if($Value-is[Collections.IEnumerable]){
        $items=@($Value);if($items.Count-eq0){return '[]'}
        $parts=[Collections.Generic.List[string]]::new();foreach($item in $items){$parts.Add("$childIndent$(ConvertTo-C2JsonFragment $item ($Depth+1))")}
        return "[`n$($parts-join",`n")`n$indent]"
    }
    throw "Invalid CT-15 scalar type: $($Value.GetType().FullName)"
}

function ConvertTo-C2CanonicalJson {
    param([Parameter(Mandatory)][pscustomobject]$Value)
    "$(ConvertTo-C2JsonFragment $Value 0)`n"
}

function Test-C2ExactShape {
    param([AllowNull()]$Value,[string]$Names)
    $null-ne$Value-and(@($Value.PSObject.Properties.Name)-join',')-ceq$Names
}

function Test-C2OutputInputShapes {
    param([pscustomobject]$InputFact)
    $statusShape='corpus,extraction,semantics,unity,disposition';$accountingShape='recordId,subjectKind,subjectId,reasonCode,attribution,evidence'
    foreach($row in @($InputFact.toolVersions)){if(-not(Test-C2ExactShape $row 'toolName,version')){return $false}}
    foreach($row in @($InputFact.sources)){if(-not(Test-C2ExactShape $row 'sourceId,sourceKind,capturedAt,rootFingerprint')){return $false}}
    foreach($row in @($InputFact.files)){if(-not(Test-C2ExactShape $row 'snapshotId,sourceId,sourceKind,relativePath,containerKind,sizeBytes,sha256,capturedAt,parseStatus,disposition,evidence,status')-or-not(Test-C2ExactShape $row.status $statusShape)){return $false}}
    foreach($row in @($InputFact.objects)){if(-not(Test-C2ExactShape $row 'assetObjectId,sourceId,objectType,objectName,containerRelativePath,classId,serializedSizeBytes,dependencyObjectIds,toolObservations,platformVariant,configurationDisposition,evidence,status')-or-not(Test-C2ExactShape $row.status $statusShape)){return $false};foreach($tool in @($row.toolObservations)){if(-not(Test-C2ExactShape $tool 'toolName,observation')){return $false}}}
    foreach($row in @($InputFact.resolvedFileResults)){if(-not(Test-C2ExactShape $row 'sourceId,relativePath,parseStatus,observationIds,evidence')){return $false}}
    foreach($row in @($InputFact.mergedObjectCandidates)){if(-not(Test-C2ExactShape $row 'assetObjectId,correlationId,observationIds,resolutionStatus,resolvedValues,evidence')-or-not(Test-C2ExactShape $row.resolvedValues 'sourceId,objectType,objectName,containerRelativePath,pathId,classId,serializedSizeBytes,dependencyObjectIds,contentFingerprint,configurationDisposition,memberPlatform')){return $false}}
    foreach($row in @($InputFact.canonicalProposalProvenance)){if(-not(Test-C2ExactShape $row 'proposalId,observationId,canonicalEvidenceId,proposedCanonicalAssetId,matchStatus,platformScope,equivalenceFingerprint,memberObjectIds,memberFacts,missingMemberObjectIds,evidence')){return $false};foreach($fact in @($row.memberFacts)){if(-not(Test-C2ExactShape $fact 'assetObjectId,memberPlatform,contentFingerprint')){return $false}}}
    foreach($row in @($InputFact.dispatchInputFacts)){if(-not(Test-C2ExactShape $row 'assetObjectId,sp04Partition,privateConfigurationDisposition,configurationCandidateId')){return $false}}
    foreach($row in @($InputFact.fileDiscoveryConflicts)){if(-not(Test-C2ExactShape $row 'fileDiscoveryConflictId,sourceId,relativePath,observationIds,outcomes,evidence')){return $false}}
    foreach($row in @($InputFact.observationConflicts)){if(-not(Test-C2ExactShape $row 'observationConflictId,correlationId,observationIds,objectIds,conflictingFields,failureClass,evidence')){return $false}}
    foreach($row in @($InputFact.configurationCandidates)){if(-not(Test-C2ExactShape $row 'configurationCandidateId,targetKind,sourceId,containerRelativePath,assetObjectId,configurationDisposition,observationIds,evidence')){return $false}}
    foreach($row in @($InputFact.configurationConflicts)){if(-not(Test-C2ExactShape $row 'configurationConflictId,configurationCandidateId,targetKind,observationIds,conflictingFields,evidence')){return $false}}
    foreach($row in @($InputFact.canonicalGroups)){if(-not(Test-C2ExactShape $row 'canonicalAssetId,memberObjectIds,matchStatus,platformScope,equivalenceFingerprint,variantEvidence')){return $false}}
    foreach($row in @($InputFact.canonicalConflicts)){if(-not(Test-C2ExactShape $row 'canonicalConflictId,proposedCanonicalAssetIds,memberObjectIds,observationIds,conflictingFields,evidence')){return $false}}
    foreach($row in @($InputFact.dispatchRows)){if(-not(Test-C2ExactShape $row 'assetObjectId,canonicalAssetId,sourceId,familyLane,memberSelectorInputs,configurationCandidateId,dispatchStatus,evidence')){return $false};foreach($selector in @($row.memberSelectorInputs)){if(-not(Test-C2ExactShape $selector 'kind,value')){return $false}}}
    foreach($row in @($InputFact.inputFailures)+@($InputFact.inputExclusions)+@($InputFact.inputSuppressions)){if(-not(Test-C2ExactShape $row $accountingShape)){return $false}}
    $prior=$null;$paths=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($row in @($InputFact.discoveryInputs)){if(-not(Test-C2ExactShape $row 'path,sha256')-or-not(Test-C2PortablePath $row.path)-or$row.sha256-cnotmatch'^[0-9a-f]{64}$'-or-not$paths.Add([string]$row.path)-or($null-ne$prior-and$script:Ordinal.Compare($prior,[string]$row.path)-ge0)){return $false};$prior=[string]$row.path}
    if(-not(Test-C2ExactShape $InputFact.coverage 'files,containers,objects,configuration,canonical,dispatch')){return $false}
    $coverageShapes=@(
        'catalogedFileCount,catalogedBytes,catalogedContainerCount,catalogedContainerBytes,nonContainerFileCount,nonContainerFileBytes,fileDiscoverySubjectCount,fileDiscoverySubjectBytes,notAttemptedFileCount,notAttemptedFileBytes,parsedFileCount,parsedFileBytes,opaqueFileCount,opaqueFileBytes,failedFileCount,failedFileBytes,fileDiscoveryConflictFileCount,fileDiscoveryConflictFileBytes',
        'notAttemptedContainerCount,notAttemptedContainerBytes,parsedContainerCount,parsedContainerBytes,opaqueContainerCount,opaqueContainerBytes,failedContainerCount,failedContainerBytes,fileDiscoveryConflictContainerCount,fileDiscoveryConflictContainerBytes',
        'objectObservationRowCount,acceptedObjectObservationRowCount,rejectedObjectObservationRowCount,excludedObjectObservationRowCount,correlationGroupCount,enumeratedObjectCount,observationConflictObjectCount,classifiedObjectCount,unclassifiedObjectCount,unresolvedDependencyCount',
        'configurationDiscoverySubjectCount,configurationCandidateCount,configurationConflictCount,parsedConfigurationCount,discoveredOpaqueConfigurationCount,encryptedConfigurationCount,requiresRuntimeTypeConfigurationCount,likelyServerDependentConfigurationCount,notConfigurationCount',
        'canonicalizedObjectCount,canonicalConflictObjectCount,canonicalGroupCount,exactDuplicateGroupCount,platformVariantGroupCount,unresolvedCanonicalGroupCount',
        'dispatchEligibleObjectCount,assignedObjectCount,retainedForDiagnosisObjectCount,configurationOnlyObjectCount,audioObjectCount,environmentObjectCount,actorObjectCount,uiObjectCount,effectsObjectCount'
    );$coverageNames=@('files','containers','objects','configuration','canonical','dispatch');for($i=0;$i-lt6;$i++){if(-not(Test-C2ExactShape $InputFact.coverage.($coverageNames[$i]) $coverageShapes[$i])){return $false}}
    if(-not(Test-C2ExactShape $InputFact.decision 'failureAttribution,nextAllowedAction')){return $false}
    return $true
}

function Get-C2RegisteredArtifactFingerprint {
    param([Parameter(Mandatory)][ValidateSet('Discovery','Diagnostic')][string]$Kind,[Parameter(Mandatory)][ValidateSet('Passed','Failed')][string]$GateStatus,[Parameter(Mandatory)][object[]]$Entries)
    $expected=if($Kind-ceq'Discovery'){if($GateStatus-ceq'Passed'){@($script:OutputRegistry[0..6].path)}else{@($script:OutputRegistry[4..6].path)}}else{@($script:OutputRegistry[4..7].path)}
    $domain=if($Kind-ceq'Discovery'){'C2DiscoveryArtifactV1'}else{'C2DiagnosticBundleV1'}
    $seen=[Collections.Generic.HashSet[string]]::new($script:Ordinal);$ordered=[Collections.Generic.List[object]]::new()
    foreach($entry in $Entries){if($null-eq$entry-or(@($entry.PSObject.Properties.Name)-join',')-cne'path,sha256'-or-not$seen.Add([string]$entry.path)){throw "$Kind artifact entry shape/identity invalid."};$ordered.Add($entry)}
    $ordered.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.path,[string]$b.path)})
    $actual=@($ordered.path);$sortedExpected=[string[]]$expected;[Array]::Sort($sortedExpected,$script:Ordinal)
    if(($actual-join"`n")-cne($sortedExpected-join"`n")){throw "$Kind artifact child set invalid."}
    $count=[string]$ordered.Count;$text="$domain`nentries.count:$($script:Utf8.GetByteCount($count)):$count`n"
    for($i=0;$i-lt$ordered.Count;$i++){$nested=Get-C2ArtifactEntryBytes $ordered[$i].path $ordered[$i].sha256;$text+="entries[$i]:$($nested.Length):$($script:Utf8.GetString($nested))`n"}
    Get-C2Sha256 $script:Utf8.GetBytes($text)
}

function Get-C2PublicationTransactionId {
    param([string]$SnapshotId,[string]$GeneratedAt,[string]$InputFingerprint,[AllowNull()]$DiscoveryInputFingerprint,[string]$GateStatus)
    if($GeneratedAt-cnotmatch'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'-or$InputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or($null-ne$DiscoveryInputFingerprint-and$DiscoveryInputFingerprint-cnotmatch'^[0-9a-f]{64}$')-or$GateStatus-cnotin@('Passed','Failed')){throw "HI-16 input invalid: generatedAt=<$GeneratedAt> input=<$InputFingerprint> discovery=<$DiscoveryInputFingerprint> status=<$GateStatus>."}
    $text="C2PublicationTransactionV1`n"+(ConvertTo-C2ScalarLine snapshotId $SnapshotId)+(ConvertTo-C2ScalarLine generatedAt $GeneratedAt)+(ConvertTo-C2ScalarLine inputFingerprint $InputFingerprint)+(Add-C2NullableFrame discoveryInputFingerprint $DiscoveryInputFingerprint)+(ConvertTo-C2ScalarLine gateStatus $GateStatus)
    "publication-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function Invoke-C2OutputSerialization {
    [CmdletBinding()]param([Parameter(Mandatory)][pscustomobject]$InputFact)
    $inputShape='schemaVersion,generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,discoveryInputFingerprint,gateStatus,toolVersions,sources,files,objects,configurationCandidates,configurationConflicts,canonicalGroups,canonicalConflicts,sourceLedgerPath,dispatchRows,resolvedFileResults,mergedObjectCandidates,canonicalProposalProvenance,dispatchInputFacts,fileDiscoveryConflicts,observationConflicts,inputFailures,inputExclusions,inputSuppressions,discoveryInputs,coverage,failureAccounting,decision,contractChangeRequest'
    if((@($InputFact.PSObject.Properties.Name)-join',')-cne$inputShape){throw 'Output serialization input shape/order invalid.'}
    if(-not(Test-C2OutputInputShapes $InputFact)){throw 'Output serialization nested shape/order invalid.'}
    $gateStatus=[string]$InputFact.gateStatus;$discoveryFingerprint=$InputFact.discoveryInputFingerprint
    if($gateStatus-cnotin@('Passed','Failed')-or$InputFact.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$InputFact.ledgerInputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or($gateStatus-ceq'Passed'-and$discoveryFingerprint-cnotmatch'^[0-9a-f]{64}$')-or($gateStatus-ceq'Failed'-and$null-ne$discoveryFingerprint)){throw 'Output serialization identity invalid.'}
    $request=$InputFact.contractChangeRequest
    if($null-eq$request-or(@($request.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,requestId,reason,nextAllowedAction,inputFingerprint,discoveryInputFingerprint,status,missingProjectionFields,evidence'-or$request.generatedAt-cne$InputFact.generatedAt-or$request.inputFingerprint-cne$InputFact.inputFingerprint-or$request.discoveryInputFingerprint-cne$discoveryFingerprint){throw 'AR-S12 shape/identity invalid.'}
    $evidence=Get-C2OrdinalUnique @($InputFact.inputFailures|ForEach-Object{@($_.evidence)})
    $outputFailures=[Collections.Generic.List[object]]::new()
    if($gateStatus-ceq'Failed'){foreach($id in @('AR-O01','AR-O02','AR-O03','AR-O04')){$outputFailures.Add((New-C2AccountingRow outputFailures OutputArtifact $id SuppressedByGate "SuppressedByGate:$id" $evidence))}}
    $projected=if($gateStatus-ceq'Passed'){5}else{1};$outputAccounting=[pscustomobject][ordered]@{outputCandidateCount=5;projectedOutputCount=$projected;outputFailureCount=$outputFailures.Count;excludedOutputCount=0}
    if($outputAccounting.outputCandidateCount-ne$outputAccounting.projectedOutputCount+$outputAccounting.outputFailureCount+$outputAccounting.excludedOutputCount){throw 'SP-09 output conservation failed.'}
    $sidecar=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;generatedAt=$InputFact.generatedAt;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=$discoveryFingerprint;resolvedFileResults=@($InputFact.resolvedFileResults);mergedObjectCandidates=@($InputFact.mergedObjectCandidates);canonicalProposalProvenance=@($InputFact.canonicalProposalProvenance);dispatchInputFacts=@($InputFact.dispatchInputFacts);fileDiscoveryConflicts=@($InputFact.fileDiscoveryConflicts);observationConflicts=@($InputFact.observationConflicts);configurationCandidates=@($InputFact.configurationCandidates);configurationConflicts=@($InputFact.configurationConflicts);canonicalGroups=@($InputFact.canonicalGroups);canonicalConflicts=@($InputFact.canonicalConflicts);inputFailures=@($InputFact.inputFailures);inputExclusions=@($InputFact.inputExclusions);inputSuppressions=@($InputFact.inputSuppressions);outputFailures=[object[]]$outputFailures;outputExclusions=@()}
    $contract=[pscustomobject][ordered]@{schemaVersion=$request.schemaVersion;generatedAt=$request.generatedAt;requestId=$request.requestId;reason=$request.reason;nextAllowedAction=$request.nextAllowedAction;inputFingerprint=$request.inputFingerprint;discoveryInputFingerprint=$request.discoveryInputFingerprint;status=$request.status;missingProjectionFields=@($request.missingProjectionFields);evidence=@($request.evidence)}
    $ledger=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;snapshotId=$InputFact.snapshotId;generatedAt=$InputFact.generatedAt;inputFingerprint=$InputFact.inputFingerprint;toolVersions=@($InputFact.toolVersions);sources=@($InputFact.sources);files=@($InputFact.files);objects=@($InputFact.objects)}
    $configuration=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;generatedAt=$InputFact.generatedAt;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=$discoveryFingerprint;configurationCandidates=@($InputFact.configurationCandidates);configurationConflicts=@($InputFact.configurationConflicts)}
    $canonical=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;generatedAt=$InputFact.generatedAt;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=$discoveryFingerprint;canonicalGroups=@($InputFact.canonicalGroups);canonicalConflicts=@($InputFact.canonicalConflicts)}
    $dispatch=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;generatedAt=$InputFact.generatedAt;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;discoveryInputFingerprint=$discoveryFingerprint;sourceLedgerPath=$InputFact.sourceLedgerPath;rows=@($InputFact.dispatchRows)}
    $base=$InputFact.failureAccounting
    $baseShape='inputSubjectCount,acceptedInputSubjectCount,notEvaluatedInputSubjectCount,inputObservationCount,acceptedInputObservationCount,rejectedInputObservationCount,inputFailureCount,excludedInputSubjectCount,excludedInputCount,contractFailureRecordCount,fileDiscoveryConflictRecordCount,observationConflictRecordCount,configurationConflictRecordCount,canonicalConflictRecordCount,issueCount,gateStatus'
    if($null-eq$base-or(@($base.PSObject.Properties.Name)-join',')-cne$baseShape-or$base.gateStatus-cne$gateStatus-or[long]$base.issueCount-ne@($InputFact.inputFailures).Count){throw 'Input failure accounting shape/state invalid.'}
    $failureAccounting=[pscustomobject][ordered]@{inputSubjectCount=$base.inputSubjectCount;acceptedInputSubjectCount=$base.acceptedInputSubjectCount;notEvaluatedInputSubjectCount=$base.notEvaluatedInputSubjectCount;inputObservationCount=$base.inputObservationCount;acceptedInputObservationCount=$base.acceptedInputObservationCount;rejectedInputObservationCount=$base.rejectedInputObservationCount;inputFailureCount=$base.inputFailureCount;excludedInputSubjectCount=$base.excludedInputSubjectCount;excludedInputCount=$base.excludedInputCount;contractFailureRecordCount=$base.contractFailureRecordCount;fileDiscoveryConflictRecordCount=$base.fileDiscoveryConflictRecordCount;observationConflictRecordCount=$base.observationConflictRecordCount;configurationConflictRecordCount=$base.configurationConflictRecordCount;canonicalConflictRecordCount=$base.canonicalConflictRecordCount;outputCandidateCount=5;projectedOutputCount=$projected;outputFailureCount=$outputFailures.Count;excludedOutputCount=0;issueCount=$base.issueCount;gateStatus=$gateStatus}
    $report="# C2 Discovery Gate Report`nschemaVersion: $($InputFact.schemaVersion)`ngeneratedAt: $($InputFact.generatedAt)`nsnapshotId: $($InputFact.snapshotId)`noperationIdentity: C2.DiscoveryCoverage.FixtureValidation`ninputFingerprint: $($InputFact.inputFingerprint)`nledgerInputFingerprint: $($InputFact.ledgerInputFingerprint)`ndiscoveryInputFingerprint: $(if($null-eq$discoveryFingerprint){'null'}else{$discoveryFingerprint})`ngateStatus: $gateStatus`ninputSubjectCount: $($base.inputSubjectCount)`nnotEvaluatedInputSubjectCount: $($base.notEvaluatedInputSubjectCount)`ninputFailureCount: $($base.inputFailureCount)`noutputCandidateCount: 5`nprojectedOutputCount: $projected`noutputFailureCount: $($outputFailures.Count)`nissueCount: $($base.issueCount)`nfailureAttribution: $($InputFact.decision.failureAttribution)`nnextAllowedAction: $($InputFact.decision.nextAllowedAction)`n"
    $texts=@{};if($gateStatus-ceq'Passed'){$texts[$script:OutputRegistry[0].path]=ConvertTo-C2CanonicalJson $ledger;$texts[$script:OutputRegistry[1].path]=ConvertTo-C2CanonicalJson $configuration;$texts[$script:OutputRegistry[2].path]=ConvertTo-C2CanonicalJson $canonical;$texts[$script:OutputRegistry[3].path]=ConvertTo-C2CanonicalJson $dispatch}
    $texts[$script:OutputRegistry[4].path]=$report;$texts[$script:OutputRegistry[5].path]=ConvertTo-C2CanonicalJson $sidecar;$texts[$script:OutputRegistry[6].path]=ConvertTo-C2CanonicalJson $contract
    $nonSummary=[Collections.Generic.List[object]]::new();foreach($path in @($texts.Keys)){$nonSummary.Add([pscustomobject][ordered]@{path=$path;sha256=Get-C2Sha256 $script:Utf8.GetBytes([string]$texts[$path])})}
    $artifactFingerprint=Get-C2RegisteredArtifactFingerprint Discovery $gateStatus @($nonSummary)
    $childSummaries=[Collections.Generic.List[object]]::new();if($gateStatus-ceq'Passed'){foreach($index in 0..3){$path=$script:OutputRegistry[$index].path;$childSummaries.Add([pscustomobject][ordered]@{path=$path;sha256=@($nonSummary|Where-Object{$_.path -ceq $path})[0].sha256})}}
    $childReports=[Collections.Generic.List[object]]::new();foreach($index in 4..6){$path=$script:OutputRegistry[$index].path;$childReports.Add([pscustomobject][ordered]@{path=$path;sha256=@($nonSummary|Where-Object{$_.path -ceq $path})[0].sha256})}
    $childSummaries.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.path,[string]$b.path)});$childReports.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.path,[string]$b.path)})
    $summary=[pscustomobject][ordered]@{schemaVersion=$InputFact.schemaVersion;identity=[pscustomobject][ordered]@{generatedAt=$InputFact.generatedAt;snapshotId=$InputFact.snapshotId;inputFingerprint=$InputFact.inputFingerprint;ledgerInputFingerprint=$InputFact.ledgerInputFingerprint;discoveryInputFingerprint=$discoveryFingerprint;discoveryArtifactFingerprint=$artifactFingerprint};provenance=[pscustomobject][ordered]@{toolVersions=@($InputFact.toolVersions);operationIdentity='C2.DiscoveryCoverage.FixtureValidation'};directEvidence=[pscustomobject][ordered]@{discoveryInputs=@($InputFact.discoveryInputs);directChildSummaries=[object[]]$childSummaries;directChildReports=[object[]]$childReports};coverage=$InputFact.coverage;failureAccounting=$failureAccounting;decision=$InputFact.decision}
    $summaryText=ConvertTo-C2CanonicalJson $summary;$texts[$script:OutputRegistry[7].path]=$summaryText
    $summaryEntry=[pscustomobject][ordered]@{path=$script:OutputRegistry[7].path;sha256=Get-C2Sha256 $script:Utf8.GetBytes($summaryText)}
    $diagnosticEntries=@($summaryEntry)+@($childReports);$diagnosticFingerprint=Get-C2RegisteredArtifactFingerprint Diagnostic $gateStatus $diagnosticEntries
    $artifacts=[Collections.Generic.List[object]]::new();for($i=0;$i-lt$script:OutputRegistry.Count;$i++){$reg=$script:OutputRegistry[$i];$present=$texts.ContainsKey($reg.path);$artifacts.Add([pscustomobject][ordered]@{artifactId=$reg.artifactId;path=$reg.path;desiredState=if($present){'Present'}else{'Absent'};text=if($present){[string]$texts[$reg.path]}else{$null};sha256=if($present){Get-C2Sha256 $script:Utf8.GetBytes([string]$texts[$reg.path])}else{$null};index=$i})}
    [pscustomobject][ordered]@{gateStatus=$gateStatus;artifacts=[object[]]$artifacts;outputFailures=[object[]]$outputFailures;outputExclusions=@();outputAccounting=$outputAccounting;discoveryArtifactFingerprint=$artifactFingerprint;diagnosticBundleFingerprint=$diagnosticFingerprint;transactionId=Get-C2PublicationTransactionId -SnapshotId $InputFact.snapshotId -GeneratedAt $InputFact.generatedAt -InputFingerprint $InputFact.inputFingerprint -DiscoveryInputFingerprint $discoveryFingerprint -GateStatus $gateStatus}
}

function Get-C2PublicationChildPath {
    param([string]$Root,[string]$RelativePath)
    $rootFull=[IO.Path]::GetFullPath($Root);$candidate=[IO.Path]::GetFullPath([IO.Path]::Combine($rootFull,$RelativePath.Replace('/',[IO.Path]::DirectorySeparatorChar)))
    if(-not$candidate.StartsWith($rootFull.TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'Publication path escaped its registered root.'}
    $candidate
}

function Write-C2DurableFile {
    param([string]$SandboxRoot,[string]$Path,[byte[]]$Bytes)
    $null=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,$Path));$parent=[IO.Path]::GetDirectoryName($Path);$null=[IO.Directory]::CreateDirectory($parent)
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Create,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$stream.Write($Bytes,0,$Bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
}

function Get-C2PublicationFileSha {
    param([string]$SandboxRoot,[string]$Path)
    $null=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,$Path));if(-not[IO.File]::Exists($Path)){return $null};Get-C2Sha256 ([IO.File]::ReadAllBytes($Path))
}

function Remove-C2PublicationPath {
    param([string]$SandboxRoot,[string]$Path)
    $null=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,$Path));if([IO.File]::Exists($Path)){[IO.File]::Delete($Path)}elseif([IO.Directory]::Exists($Path)){[IO.Directory]::Delete($Path,$true)}
}

function Move-C2PublicationFile {
    param([string]$SandboxRoot,[string]$Source,[string]$Destination)
    $null=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,$Source));$null=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,$Destination));$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination));[IO.File]::Move($Source,$Destination,$true)
}

function New-C2PublicationFailureResult {
    param([string]$TransactionId,[bool]$Quarantined,[bool]$LockFilePresent,[string]$Reason='ProjectionInvalid')
    $rows=[Collections.Generic.List[object]]::new();foreach($id in @('AR-O01','AR-O02','AR-O03','AR-O04','AR-O05')){$rows.Add((New-C2AccountingRow outputFailures OutputArtifact $id $Reason "FT-12:$id" @()))}
    [pscustomobject][ordered]@{status='Failed';outputAccounting=[pscustomobject][ordered]@{outputCandidateCount=5;projectedOutputCount=0;outputFailureCount=5;excludedOutputCount=0};outputFailures=[object[]]$rows;quarantined=$Quarantined;lockFilePresent=$LockFilePresent;transactionId=$TransactionId}
}

function Test-C2SerializedPublicationResult {
    param([pscustomobject]$Result)
    try{
        if(-not(Test-C2ExactShape $Result 'gateStatus,artifacts,outputFailures,outputExclusions,outputAccounting,discoveryArtifactFingerprint,diagnosticBundleFingerprint,transactionId')-or$Result.gateStatus-cnotin@('Passed','Failed')-or$Result.transactionId-cnotmatch'^publication-sha256:[0-9a-f]{64}$'-or@($Result.artifacts).Count-ne8){return $false}
        $expectedStates=if($Result.gateStatus-ceq'Passed'){@('Present')*8}else{@('Absent')*4+@('Present')*4}
        for($i=0;$i-lt8;$i++){$row=$Result.artifacts[$i];$reg=$script:OutputRegistry[$i];if(-not(Test-C2ExactShape $row 'artifactId,path,desiredState,text,sha256,index')-or$row.artifactId-cne$reg.artifactId-or$row.path-cne$reg.path-or$row.index-ne$i-or$row.desiredState-cne$expectedStates[$i]){return $false};if($row.desiredState-ceq'Present'){if($row.text-isnot[string]-or-not$row.text.EndsWith("`n")-or$row.text.Contains("`r")-or$row.sha256-cne(Get-C2Sha256 $script:Utf8.GetBytes([string]$row.text))){return $false};if($row.path.EndsWith('.json')){$parsed=$row.text|ConvertFrom-Json -Depth 100 -DateKind String;if((ConvertTo-C2CanonicalJson $parsed)-cne$row.text){return $false}}}elseif($null-ne$row.text-or$null-ne$row.sha256){return $false}}
        $a=$Result.outputAccounting;if(-not(Test-C2ExactShape $a 'outputCandidateCount,projectedOutputCount,outputFailureCount,excludedOutputCount')-or$a.outputCandidateCount-ne5-or$a.excludedOutputCount-ne0-or$a.outputCandidateCount-ne$a.projectedOutputCount+$a.outputFailureCount+$a.excludedOutputCount-or$a.outputFailureCount-ne@($Result.outputFailures).Count-or@($Result.outputExclusions).Count-ne$a.excludedOutputCount){return $false}
        $expectedFailureIds=@(if($Result.gateStatus-ceq'Failed'){'AR-O01','AR-O02','AR-O03','AR-O04'});if(@($Result.outputFailures).Count-ne$expectedFailureIds.Count){return $false};for($i=0;$i-lt$expectedFailureIds.Count;$i++){$row=$Result.outputFailures[$i];$expected=if($null-ne$row-and(Test-C2ExactShape $row 'recordId,subjectKind,subjectId,reasonCode,attribution,evidence')){New-C2AccountingRow outputFailures OutputArtifact $expectedFailureIds[$i] SuppressedByGate "SuppressedByGate:$($expectedFailureIds[$i])" @($row.evidence)}else{$null};if($null-eq$expected-or$row.recordId-cne$expected.recordId-or$row.subjectKind-cne'OutputArtifact'-or$row.subjectId-cne$expectedFailureIds[$i]-or$row.reasonCode-cne'SuppressedByGate'-or$row.attribution-cne"SuppressedByGate:$($expectedFailureIds[$i])"){return $false}}
        $summary=$Result.artifacts[7].text|ConvertFrom-Json -Depth 100 -DateKind String;$failureShape='inputSubjectCount,acceptedInputSubjectCount,notEvaluatedInputSubjectCount,inputObservationCount,acceptedInputObservationCount,rejectedInputObservationCount,inputFailureCount,excludedInputSubjectCount,excludedInputCount,contractFailureRecordCount,fileDiscoveryConflictRecordCount,observationConflictRecordCount,configurationConflictRecordCount,canonicalConflictRecordCount,outputCandidateCount,projectedOutputCount,outputFailureCount,excludedOutputCount,issueCount,gateStatus'
        if(-not(Test-C2ExactShape $summary 'schemaVersion,identity,provenance,directEvidence,coverage,failureAccounting,decision')-or-not(Test-C2ExactShape $summary.identity 'generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,discoveryInputFingerprint,discoveryArtifactFingerprint')-or-not(Test-C2ExactShape $summary.provenance 'toolVersions,operationIdentity')-or-not(Test-C2ExactShape $summary.directEvidence 'discoveryInputs,directChildSummaries,directChildReports')-or-not(Test-C2ExactShape $summary.failureAccounting $failureShape)-or-not(Test-C2ExactShape $summary.decision 'failureAttribution,nextAllowedAction')-or$summary.provenance.operationIdentity-cne'C2.DiscoveryCoverage.FixtureValidation'-or$summary.failureAccounting.gateStatus-cne$Result.gateStatus-or$summary.failureAccounting.outputFailureCount-ne$a.outputFailureCount){return $false}
        $expectedSummaries=[Collections.Generic.List[object]]::new();if($Result.gateStatus-ceq'Passed'){foreach($artifact in $Result.artifacts[0..3]){$expectedSummaries.Add([pscustomobject][ordered]@{path=$artifact.path;sha256=$artifact.sha256})}};$expectedReports=[Collections.Generic.List[object]]::new();foreach($artifact in $Result.artifacts[4..6]){$expectedReports.Add([pscustomobject][ordered]@{path=$artifact.path;sha256=$artifact.sha256})};foreach($rows in @($expectedSummaries,$expectedReports)){$rows.Sort([Comparison[object]]{param($x,$y)$script:Ordinal.Compare([string]$x.path,[string]$y.path)})};if((ConvertTo-C2CanonicalJson @($summary.directEvidence.directChildSummaries))-cne(ConvertTo-C2CanonicalJson @($expectedSummaries))-or(ConvertTo-C2CanonicalJson @($summary.directEvidence.directChildReports))-cne(ConvertTo-C2CanonicalJson @($expectedReports))){return $false}
        $discoveryEntries=@($Result.artifacts|Where-Object{$_.index-lt7-and$_.desiredState-ceq'Present'}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}});$diagnosticEntries=@($Result.artifacts|Where-Object{$_.index-in@(4,5,6,7)}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}})
        if($Result.discoveryArtifactFingerprint-cne(Get-C2RegisteredArtifactFingerprint Discovery $Result.gateStatus $discoveryEntries)-or$Result.diagnosticBundleFingerprint-cne(Get-C2RegisteredArtifactFingerprint Diagnostic $Result.gateStatus $diagnosticEntries)-or$summary.identity.discoveryArtifactFingerprint-cne$Result.discoveryArtifactFingerprint){return $false}
        $expectedTransaction=Get-C2PublicationTransactionId $summary.identity.snapshotId $summary.identity.generatedAt $summary.identity.inputFingerprint $summary.identity.discoveryInputFingerprint $Result.gateStatus;if($Result.transactionId-cne$expectedTransaction){return $false}
        return $true
    }catch{return $false}
}

function Read-C2RegisteredPublicationState {
    param([string]$ConsumerRoot)
    try{
        $present=@();for($i=0;$i-lt8;$i++){$path=Get-C2PublicationChildPath $ConsumerRoot $script:OutputRegistry[$i].path;$present+=,[IO.File]::Exists($path)}
        if(@($present|Where-Object{$_}).Count-eq0){return [pscustomobject][ordered]@{state='Empty';result=$null}}
        $gateStatus=if(($present-join',')-ceq'False,False,False,False,True,True,True,True'){'Failed'}elseif(@($present|Where-Object{-not$_}).Count-eq0){'Passed'}else{return [pscustomobject][ordered]@{state='Invalid';result=$null}}
        $artifacts=[Collections.Generic.List[object]]::new();for($i=0;$i-lt8;$i++){$reg=$script:OutputRegistry[$i];$path=Get-C2PublicationChildPath $ConsumerRoot $reg.path;$text=if($present[$i]){$script:Utf8.GetString([IO.File]::ReadAllBytes($path))}else{$null};$artifacts.Add([pscustomobject][ordered]@{artifactId=$reg.artifactId;path=$reg.path;desiredState=if($present[$i]){'Present'}else{'Absent'};text=$text;sha256=if($present[$i]){Get-C2Sha256 $script:Utf8.GetBytes($text)}else{$null};index=$i})}
        $summary=$artifacts[7].text|ConvertFrom-Json -Depth 100 -DateKind String;$sidecar=$artifacts[5].text|ConvertFrom-Json -Depth 100 -DateKind String;$projected=if($gateStatus-ceq'Passed'){5}else{1};$outputFailures=@($sidecar.outputFailures);$outputExclusions=@($sidecar.outputExclusions)
        $diagnosticEntries=@($artifacts|Where-Object{$_.index-in@(4,5,6,7)}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}});$result=[pscustomobject][ordered]@{gateStatus=$gateStatus;artifacts=[object[]]$artifacts;outputFailures=$outputFailures;outputExclusions=$outputExclusions;outputAccounting=[pscustomobject][ordered]@{outputCandidateCount=5;projectedOutputCount=$projected;outputFailureCount=$outputFailures.Count;excludedOutputCount=$outputExclusions.Count};discoveryArtifactFingerprint=$summary.identity.discoveryArtifactFingerprint;diagnosticBundleFingerprint=Get-C2RegisteredArtifactFingerprint Diagnostic $gateStatus $diagnosticEntries;transactionId=Get-C2PublicationTransactionId $summary.identity.snapshotId $summary.identity.generatedAt $summary.identity.inputFingerprint $summary.identity.discoveryInputFingerprint $gateStatus}
        if(-not(Test-C2SerializedPublicationResult $result)){return [pscustomobject][ordered]@{state='Invalid';result=$null}};[pscustomobject][ordered]@{state='Valid';result=$result}
    }catch{[pscustomobject][ordered]@{state='Invalid';result=$null}}
}

function Test-C2PublishedDiscoveryGeneration {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot)
    $repository=[IO.Path]::GetFullPath($RepositoryRoot);$operational=Get-C2PublicationChildPath $repository 'Temp/C2DiscoveryPublication';$null=[IO.Directory]::CreateDirectory($operational);$lockPath=[IO.Path]::Combine($operational,'publication.lock');$lock=$null
    try{$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);$state=Read-C2RegisteredPublicationState $repository;if($state.state-cne'Valid'){return [pscustomobject][ordered]@{status='Rejected';reason='PartialStaleOrHashMismatch';gateStatus=$null;transactionId=$null}};if($state.result.gateStatus-cne'Passed'){return [pscustomobject][ordered]@{status='Rejected';reason='GateFailed';gateStatus=$state.result.gateStatus;transactionId=$state.result.transactionId}};[pscustomobject][ordered]@{status='Accepted';reason=$null;gateStatus='Passed';transactionId=$state.result.transactionId}}catch{[pscustomobject][ordered]@{status='Rejected';reason='LockUnavailable';gateStatus=$null;transactionId=$null}}finally{if($null-ne$lock){$lock.Dispose()}}
}

function Test-C2PublishedGenerationVector {
    param([string]$RepositoryRoot,[ValidateSet('Passed','Failed','Partial','HashMismatch')][string]$Vector)
    $repository=[IO.Path]::GetFullPath($RepositoryRoot);$testRoot=Get-C2PublicationChildPath $repository "Temp/C2PublishedGenerationTests/$Vector";if([IO.Directory]::Exists($testRoot)){[IO.Directory]::Delete($testRoot,$true)};$null=[IO.Directory]::CreateDirectory($testRoot)
    try{$gate=if($Vector-ceq'Failed'){'Failed'}else{'Passed'};$serialized=New-C2PublicationTestSerialization $gate;foreach($artifact in @($serialized.artifacts|Where-Object desiredState -ceq Present)){$path=Get-C2PublicationChildPath $testRoot $artifact.path;Write-C2DurableFile $testRoot $path $script:Utf8.GetBytes([string]$artifact.text)};if($Vector-ceq'Partial'){Remove-C2PublicationPath $testRoot (Get-C2PublicationChildPath $testRoot $script:OutputRegistry[3].path)}elseif($Vector-ceq'HashMismatch'){Write-C2DurableFile $testRoot (Get-C2PublicationChildPath $testRoot $script:OutputRegistry[0].path) $script:Utf8.GetBytes("tampered`n")};Test-C2PublishedDiscoveryGeneration $testRoot}finally{if([IO.Directory]::Exists($testRoot)){[IO.Directory]::Delete($testRoot,$true)};$parent=[IO.Path]::GetDirectoryName($testRoot);if([IO.Directory]::Exists($parent)-and@([IO.Directory]::GetFileSystemEntries($parent)).Count-eq0){[IO.Directory]::Delete($parent)}}
}

function Write-C2PublicationJournal {
    param([string]$SandboxRoot,[string]$OperationalRoot,[pscustomobject]$Journal,[bool]$FailReplace=$false)
    $active=Get-C2PublicationChildPath $SandboxRoot ([IO.Path]::GetRelativePath($SandboxRoot,[IO.Path]::Combine($OperationalRoot,'active-journal.json')));$next="$active.next";$bytes=$script:Utf8.GetBytes((ConvertTo-C2CanonicalJson $Journal));Write-C2DurableFile $SandboxRoot $next $bytes
    if($FailReplace){throw 'Injected JournalPreparedReplace.'};Move-C2PublicationFile $SandboxRoot $next $active
}

function Read-C2PublicationJournal {
    param([string]$SandboxRoot,[string]$Path)
    try{$bytes=[IO.File]::ReadAllBytes($Path);$text=$script:Utf8.GetString($bytes);$journal=$text|ConvertFrom-Json -Depth 100 -DateKind String;if((ConvertTo-C2CanonicalJson $journal)-cne$text-or-not(Test-C2ExactShape $journal 'schemaVersion,transactionId,phase,gateStatus,generatedAt,expectedPaths,entries')-or$journal.schemaVersion-cne'1.0.0'-or$journal.transactionId-cnotmatch'^publication-sha256:[0-9a-f]{64}$'-or$journal.phase-cnotin@('Prepared','BackingUp','Installing','Verifying','Committed','RollingBack','Quarantined')-or$journal.gateStatus-cnotin@('Passed','Failed')-or$journal.generatedAt-cnotmatch'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'-or(@($journal.expectedPaths)-join"`n")-cne(@($script:OutputRegistry.path)-join"`n")-or@($journal.entries).Count-ne8){return $null};for($i=0;$i-lt8;$i++){$entry=$journal.entries[$i];$reg=$script:OutputRegistry[$i];if(-not(Test-C2ExactShape $entry 'artifactId,path,desiredState,stagedSha256,priorState,priorSha256,backupRelativePath,installState')-or$entry.artifactId-cne$reg.artifactId-or$entry.path-cne$reg.path-or$entry.desiredState-cnotin@('Present','Absent')-or$entry.priorState-cnotin@('Present','Absent')-or$entry.installState-cnotin@('Pending','BackedUp','Installed','Verified','Restored','Quarantined')-or($entry.desiredState-ceq'Present'-and$entry.stagedSha256-cnotmatch'^[0-9a-f]{64}$')-or($entry.desiredState-ceq'Absent'-and$null-ne$entry.stagedSha256)-or($entry.priorState-ceq'Present'-and($entry.priorSha256-cnotmatch'^[0-9a-f]{64}$'-or$entry.backupRelativePath-cne('backup/{0:d2}'-f$i)))-or($entry.priorState-ceq'Absent'-and($null-ne$entry.priorSha256-or$null-ne$entry.backupRelativePath))){return $null}};return $journal}catch{return $null}
}

function Test-C2PublicationJournalsCompatible {
    param([pscustomobject]$First,[pscustomobject]$Second)
    if($First.transactionId-cne$Second.transactionId-or$First.gateStatus-cne$Second.gateStatus-or$First.generatedAt-cne$Second.generatedAt-or(@($First.expectedPaths)-join"`n")-cne(@($Second.expectedPaths)-join"`n")){return $false};for($i=0;$i-lt8;$i++){foreach($name in @('artifactId','path','desiredState','stagedSha256','priorState','priorSha256','backupRelativePath')){if($First.entries[$i].$name-cne$Second.entries[$i].$name){return $false}}};return $true
}

function Invoke-C2PublicationQuarantine {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot,[pscustomobject]$Journal,[string]$TransactionRoot)
    $quarantine=[IO.Path]::Combine($TransactionRoot,'quarantine');$null=[IO.Directory]::CreateDirectory($quarantine)
    for($i=0;$i-lt8;$i++){$entry=$Journal.entries[$i];$consumer=Get-C2PublicationChildPath $ConsumerRoot $entry.path;$stage=[IO.Path]::Combine($TransactionRoot,'stage',('{0:d2}'-f$i));$backup=[IO.Path]::Combine($TransactionRoot,'backup',('{0:d2}'-f$i));foreach($pair in @(@($consumer,"consumer-$('{0:d2}'-f$i)"),@($stage,"stage-$('{0:d2}'-f$i)"),@($backup,"backup-$('{0:d2}'-f$i)"))){if([IO.File]::Exists($pair[0])){Move-C2PublicationFile $SandboxRoot $pair[0] ([IO.Path]::Combine($quarantine,$pair[1]))}};$entry.installState='Quarantined'}
    $Journal.phase='Quarantined';Write-C2DurableFile $SandboxRoot ([IO.Path]::Combine($quarantine,'journal.json')) $script:Utf8.GetBytes((ConvertTo-C2CanonicalJson $Journal))
    foreach($path in @([IO.Path]::Combine($OperationalRoot,'active-journal.json'),[IO.Path]::Combine($OperationalRoot,'active-journal.json.next'))){if([IO.File]::Exists($path)){Move-C2PublicationFile $SandboxRoot $path ([IO.Path]::Combine($quarantine,[IO.Path]::GetFileName($path)))}}
}

function Invoke-C2PublicationUnknownQuarantine {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot)
    $transaction=[IO.Path]::Combine($OperationalRoot,'transactions',('0'*64));$quarantine=[IO.Path]::Combine($transaction,'quarantine');$null=[IO.Directory]::CreateDirectory($quarantine)
    for($i=0;$i-lt8;$i++){$consumer=Get-C2PublicationChildPath $ConsumerRoot $script:OutputRegistry[$i].path;if([IO.File]::Exists($consumer)){Move-C2PublicationFile $SandboxRoot $consumer ([IO.Path]::Combine($quarantine,"consumer-$('{0:d2}'-f$i)"))}}
    foreach($path in @([IO.Path]::Combine($OperationalRoot,'active-journal.json'),[IO.Path]::Combine($OperationalRoot,'active-journal.json.next'))){if([IO.File]::Exists($path)){Move-C2PublicationFile $SandboxRoot $path ([IO.Path]::Combine($quarantine,[IO.Path]::GetFileName($path)))}}
}

function Invoke-C2PublicationRollback {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot,[pscustomobject]$Journal,[string]$TransactionRoot,[bool]$FailRestore01=$false)
    try{
        $Journal.phase='RollingBack';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $Journal
        for($i=0;$i-lt8;$i++){$entry=$Journal.entries[$i];$consumer=Get-C2PublicationChildPath $ConsumerRoot $entry.path;$backup=[IO.Path]::Combine($TransactionRoot,'backup',('{0:d2}'-f$i));$consumerSha=Get-C2PublicationFileSha $SandboxRoot $consumer;$backupSha=Get-C2PublicationFileSha $SandboxRoot $backup
            if($entry.priorState-ceq'Present'){
                if($consumerSha-ceq$entry.priorSha256){$entry.installState='Restored';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $Journal;continue}
                if($null-ne$consumerSha){if($consumerSha-cne$entry.stagedSha256){throw 'Unknown consumer bytes during rollback.'};Remove-C2PublicationPath $SandboxRoot $consumer}
                if($backupSha-cne$entry.priorSha256){throw 'Prior backup unavailable during rollback.'};if($FailRestore01-and$i-eq1){throw 'Injected Rollback01Restore.'};Move-C2PublicationFile $SandboxRoot $backup $consumer;$entry.installState='Restored';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $Journal
            }else{if($null-ne$consumerSha){if($consumerSha-cne$entry.stagedSha256){throw 'Unknown absent-prior consumer bytes.'};Remove-C2PublicationPath $SandboxRoot $consumer};$entry.installState='Restored';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $Journal}
        }
        foreach($entry in @($Journal.entries)){if($entry.priorState-ceq'Present'-and(Get-C2PublicationFileSha $SandboxRoot (Get-C2PublicationChildPath $ConsumerRoot $entry.path))-cne$entry.priorSha256){throw 'Rollback verification failed.'};if($entry.priorState-ceq'Absent'-and[IO.File]::Exists((Get-C2PublicationChildPath $ConsumerRoot $entry.path))){throw 'Rollback absence verification failed.'}}
        Remove-C2PublicationPath $SandboxRoot $TransactionRoot;Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json'));Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json.next'));return $true
    }catch{Invoke-C2PublicationQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot $Journal $TransactionRoot;return $false}
}

function Invoke-C2PublicationRecovery {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot)
    $active=[IO.Path]::Combine($OperationalRoot,'active-journal.json');$next="$active.next";$activeExists=[IO.File]::Exists($active);$nextExists=[IO.File]::Exists($next);$journal=$null
    if($activeExists-and$nextExists){$activeJournal=Read-C2PublicationJournal $SandboxRoot $active;$nextJournal=Read-C2PublicationJournal $SandboxRoot $next;if($null-eq$activeJournal-or$null-eq$nextJournal-or-not(Test-C2PublicationJournalsCompatible $activeJournal $nextJournal)){$known=if($null-ne$activeJournal){$activeJournal}else{$nextJournal};if($null-ne$known){$knownTransaction=[IO.Path]::Combine($OperationalRoot,'transactions',$known.transactionId.Substring('publication-sha256:'.Length));if(-not[IO.Directory]::Exists($knownTransaction)){$null=[IO.Directory]::CreateDirectory($knownTransaction)};Invoke-C2PublicationQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot $known $knownTransaction}else{Invoke-C2PublicationUnknownQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot};return $false};$journal=$nextJournal}
    elseif($activeExists){$journal=Read-C2PublicationJournal $SandboxRoot $active}elseif($nextExists){$journal=Read-C2PublicationJournal $SandboxRoot $next}
    if(($activeExists-or$nextExists)-and$null-eq$journal){Invoke-C2PublicationUnknownQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot;return $false}
    if($null-ne$journal){$digest=$journal.transactionId.Substring('publication-sha256:'.Length);$transaction=[IO.Path]::Combine($OperationalRoot,'transactions',$digest);$transactions=[IO.Path]::Combine($OperationalRoot,'transactions');if([IO.Directory]::Exists($transactions)){foreach($directory in @([IO.Directory]::GetDirectories($transactions))){if([IO.Path]::GetFullPath($directory)-cne[IO.Path]::GetFullPath($transaction)){if(-not[IO.Directory]::Exists($transaction)){$null=[IO.Directory]::CreateDirectory($transaction)};Invoke-C2PublicationQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot $journal $transaction;return $false}}}
        if($journal.phase-ceq'Committed'){$valid=$true;foreach($entry in @($journal.entries)){$consumer=Get-C2PublicationChildPath $ConsumerRoot $entry.path;if($entry.desiredState-ceq'Present'){if((Get-C2PublicationFileSha $SandboxRoot $consumer)-cne$entry.stagedSha256){$valid=$false}}elseif([IO.File]::Exists($consumer)){$valid=$false}};if(-not$valid){if(-not[IO.Directory]::Exists($transaction)){$null=[IO.Directory]::CreateDirectory($transaction)};Invoke-C2PublicationQuarantine $SandboxRoot $OperationalRoot $ConsumerRoot $journal $transaction;return $false};if([IO.Directory]::Exists($transaction)){Remove-C2PublicationPath $SandboxRoot $transaction};Remove-C2PublicationPath $SandboxRoot $active;Remove-C2PublicationPath $SandboxRoot $next;return $true}
        if(-not[IO.Directory]::Exists($transaction)){return $false};return Invoke-C2PublicationRollback $SandboxRoot $OperationalRoot $ConsumerRoot $journal $transaction}
    $transactions=[IO.Path]::Combine($OperationalRoot,'transactions');if(-not[IO.Directory]::Exists($transactions)){return $true}
    foreach($directory in @([IO.Directory]::GetDirectories($transactions))){$children=@([IO.Directory]::GetDirectories($directory)|ForEach-Object{[IO.Path]::GetFileName($_)});$files=@([IO.Directory]::GetFiles($directory));$stage=[IO.Path]::Combine($directory,'stage');$stageOnly=$files.Count-eq0-and@($children|Where-Object{$_-cne'stage'}).Count-eq0-and[IO.Directory]::Exists($stage)
        if($stageOnly){Remove-C2PublicationPath $SandboxRoot $directory}else{for($i=0;$i-lt8;$i++){$consumer=Get-C2PublicationChildPath $ConsumerRoot $script:OutputRegistry[$i].path;if([IO.File]::Exists($consumer)){$quarantine=[IO.Path]::Combine($directory,'quarantine');$null=[IO.Directory]::CreateDirectory($quarantine);Move-C2PublicationFile $SandboxRoot $consumer ([IO.Path]::Combine($quarantine,"consumer-$('{0:d2}'-f$i)"))}};return $false}}
    return $true
}

function Invoke-C2PublicationTransactionCore {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot,[pscustomobject]$SerializedResult,[string]$FaultPoint='')
    if($FaultPoint-cnotin@('','LockOpen','Stage05Write','JournalPreparedReplace','Backup02Move','Install04Move','Install07Move','Verify06Hash','Rollback01Restore','RecoveryAmbiguous')){throw 'Unsupported publication fault point.'}
    if(-not(Test-C2SerializedPublicationResult $SerializedResult)){return New-C2PublicationFailureResult $SerializedResult.transactionId $false $false}
    $null=[IO.Directory]::CreateDirectory($OperationalRoot);$null=[IO.Directory]::CreateDirectory($ConsumerRoot);$lockPath=[IO.Path]::Combine($OperationalRoot,'publication.lock')
    if($FaultPoint-ceq'LockOpen'){return New-C2PublicationFailureResult $SerializedResult.transactionId $false ([IO.File]::Exists($lockPath))}
    $lock=$null;try{$lock=[IO.File]::Open($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{return New-C2PublicationFailureResult $SerializedResult.transactionId $false ([IO.File]::Exists($lockPath))}
    $transaction=$null
    try{
        if($FaultPoint-ceq'RecoveryAmbiguous'){$orphan=[IO.Path]::Combine($OperationalRoot,'transactions',('e'*64),'backup');$null=[IO.Directory]::CreateDirectory($orphan);Write-C2DurableFile $SandboxRoot ([IO.Path]::Combine($orphan,'00')) $script:Utf8.GetBytes('unknown')}
        if(-not(Invoke-C2PublicationRecovery $SandboxRoot $OperationalRoot $ConsumerRoot)){return New-C2PublicationFailureResult $SerializedResult.transactionId $true $true}
        $priorState=Read-C2RegisteredPublicationState $ConsumerRoot;if($priorState.state-ceq'Invalid'){return New-C2PublicationFailureResult $SerializedResult.transactionId $false $true 'PriorGenerationInvalid'}
        $digest=$SerializedResult.transactionId.Substring('publication-sha256:'.Length);$transaction=[IO.Path]::Combine($OperationalRoot,'transactions',$digest);$stage=[IO.Path]::Combine($transaction,'stage');$backup=[IO.Path]::Combine($transaction,'backup');$null=[IO.Directory]::CreateDirectory($stage);$null=[IO.Directory]::CreateDirectory($backup)
        $entries=[Collections.Generic.List[object]]::new()
        for($i=0;$i-lt8;$i++){$artifact=$SerializedResult.artifacts[$i];$consumer=Get-C2PublicationChildPath $ConsumerRoot $artifact.path;$priorSha=Get-C2PublicationFileSha $SandboxRoot $consumer;$priorPresent=$null-ne$priorSha;if($artifact.desiredState-ceq'Present'){if($FaultPoint-ceq'Stage05Write'-and$i-eq5){throw 'Injected Stage05Write.'};$stageFile=[IO.Path]::Combine($stage,('{0:d2}'-f$i));Write-C2DurableFile $SandboxRoot $stageFile $script:Utf8.GetBytes([string]$artifact.text);if((Get-C2PublicationFileSha $SandboxRoot $stageFile)-cne$artifact.sha256){throw 'Stage readback mismatch.'}}
            $entries.Add([pscustomobject][ordered]@{artifactId=$artifact.artifactId;path=$artifact.path;desiredState=$artifact.desiredState;stagedSha256=$artifact.sha256;priorState=if($priorPresent){'Present'}else{'Absent'};priorSha256=$priorSha;backupRelativePath=if($priorPresent){'backup/{0:d2}'-f$i}else{$null};installState='Pending'})}
        $summary=$SerializedResult.artifacts[7].text|ConvertFrom-Json -Depth 100 -DateKind String;$journal=[pscustomobject][ordered]@{schemaVersion='1.0.0';transactionId=$SerializedResult.transactionId;phase='Prepared';gateStatus=$SerializedResult.gateStatus;generatedAt=$summary.identity.generatedAt;expectedPaths=@($script:OutputRegistry.path);entries=[object[]]$entries};$journalWritten=$false
        try{
            Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal ($FaultPoint-ceq'JournalPreparedReplace');$journalWritten=$true;$journal.phase='BackingUp';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal
            for($i=0;$i-lt8;$i++){$entry=$journal.entries[$i];if($entry.priorState-ceq'Present'){if($FaultPoint-ceq'Backup02Move'-and$i-eq2){throw 'Injected Backup02Move.'};$consumer=Get-C2PublicationChildPath $ConsumerRoot $entry.path;$backupFile=[IO.Path]::Combine($transaction,'backup',('{0:d2}'-f$i));Move-C2PublicationFile $SandboxRoot $consumer $backupFile;$entry.installState='BackedUp';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal}}
            $journal.phase='Installing';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal
            foreach($i in @(0,1,2,3,4,5,6,7)){if(($FaultPoint-ceq'Install04Move'-and$i-eq4)-or($FaultPoint-ceq'Install07Move'-and$i-eq7)){throw "Injected Install$('{0:d2}'-f$i)Move."};$entry=$journal.entries[$i];if($entry.desiredState-ceq'Present'){Move-C2PublicationFile $SandboxRoot ([IO.Path]::Combine($stage,('{0:d2}'-f$i))) (Get-C2PublicationChildPath $ConsumerRoot $entry.path)};$entry.installState='Installed';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal}
            $journal.phase='Verifying';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal
            for($i=0;$i-lt8;$i++){$entry=$journal.entries[$i];if(($FaultPoint-ceq'Verify06Hash'-and$i-eq6)-or($FaultPoint-ceq'Rollback01Restore'-and$i-eq7)){throw 'Injected verification failure.'};$consumer=Get-C2PublicationChildPath $ConsumerRoot $entry.path;if($entry.desiredState-ceq'Present'){if((Get-C2PublicationFileSha $SandboxRoot $consumer)-cne$entry.stagedSha256){throw 'Installed hash mismatch.'}}elseif([IO.File]::Exists($consumer)){throw 'Desired-absent consumer exists.'};$entry.installState='Verified';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal}
            $journal.phase='Committed';Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal;Remove-C2PublicationPath $SandboxRoot $transaction;$transactions=[IO.Path]::Combine($OperationalRoot,'transactions');if([IO.Directory]::Exists($transactions)-and@([IO.Directory]::GetFileSystemEntries($transactions)).Count-eq0){Remove-C2PublicationPath $SandboxRoot $transactions};Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json'));Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json.next'))
            return [pscustomobject][ordered]@{status='Committed';outputAccounting=$SerializedResult.outputAccounting;outputFailures=@($SerializedResult.outputFailures);quarantined=$false;lockFilePresent=$true;transactionId=$SerializedResult.transactionId}
        }catch{if($journalWritten){$restored=Invoke-C2PublicationRollback $SandboxRoot $OperationalRoot $ConsumerRoot $journal $transaction ($FaultPoint-ceq'Rollback01Restore');return New-C2PublicationFailureResult $SerializedResult.transactionId (-not$restored) $true};Remove-C2PublicationPath $SandboxRoot $transaction;Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json.next'));return New-C2PublicationFailureResult $SerializedResult.transactionId $false $true}
    }catch{if($null-ne$transaction-and[IO.Directory]::Exists($transaction)){Remove-C2PublicationPath $SandboxRoot $transaction};Remove-C2PublicationPath $SandboxRoot ([IO.Path]::Combine($OperationalRoot,'active-journal.json.next'));return New-C2PublicationFailureResult $SerializedResult.transactionId $false $true}finally{$lock.Dispose()}
}

function New-C2PublicationTestSerialization {
    param([ValidateSet('Passed','Failed')][string]$GateStatus,[string]$GeneratedAt='2026-07-15T00:00:00Z')
    $generatedAt=$GeneratedAt;$snapshotId='snapshot-pc-install-001';$inputFingerprint='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';$discoveryInputFingerprint=if($GateStatus-ceq'Passed'){'96b09428bc1f08b74a85c5b7fb489b4a2fb8242cc3e1a7623b6f855e15dee56b'}else{$null}
    $failures=if($GateStatus-ceq'Passed'){@()}else{@('AR-O01','AR-O02','AR-O03','AR-O04')|ForEach-Object{New-C2AccountingRow outputFailures OutputArtifact $_ SuppressedByGate "SuppressedByGate:$_" @()}};$projected=if($GateStatus-ceq'Passed'){5}else{1}
    $texts=@{};for($i=0;$i-lt7;$i++){if($GateStatus-ceq'Passed'-or$i-ge4){$texts[$script:OutputRegistry[$i].path]=if($i-eq4){"report-$GateStatus-$generatedAt`n"}elseif($i-eq5){ConvertTo-C2CanonicalJson ([pscustomobject][ordered]@{generatedAt=$generatedAt;outputFailures=@($failures);outputExclusions=@()})}else{ConvertTo-C2CanonicalJson ([pscustomobject][ordered]@{artifactId=$script:OutputRegistry[$i].artifactId;gateStatus=$GateStatus;generatedAt=$generatedAt;index=$i})}}}
    $nonSummary=@($texts.Keys|ForEach-Object{[pscustomobject][ordered]@{path=$_;sha256=Get-C2Sha256 $script:Utf8.GetBytes([string]$texts[$_])}});$discoveryArtifactFingerprint=Get-C2RegisteredArtifactFingerprint Discovery $GateStatus $nonSummary
    $childSummaries=[Collections.Generic.List[object]]::new();if($GateStatus-ceq'Passed'){foreach($i in 0..3){$path=$script:OutputRegistry[$i].path;$childSummaries.Add([pscustomobject][ordered]@{path=$path;sha256=@($nonSummary|Where-Object path -ceq $path)[0].sha256})}};$childReports=[Collections.Generic.List[object]]::new();foreach($i in 4..6){$path=$script:OutputRegistry[$i].path;$childReports.Add([pscustomobject][ordered]@{path=$path;sha256=@($nonSummary|Where-Object path -ceq $path)[0].sha256})};foreach($rows in @($childSummaries,$childReports)){$rows.Sort([Comparison[object]]{param($x,$y)$script:Ordinal.Compare([string]$x.path,[string]$y.path)})}
    $failureAccounting=[pscustomobject][ordered]@{inputSubjectCount=0;acceptedInputSubjectCount=0;notEvaluatedInputSubjectCount=0;inputObservationCount=0;acceptedInputObservationCount=0;rejectedInputObservationCount=0;inputFailureCount=0;excludedInputSubjectCount=0;excludedInputCount=0;contractFailureRecordCount=0;fileDiscoveryConflictRecordCount=0;observationConflictRecordCount=0;configurationConflictRecordCount=0;canonicalConflictRecordCount=0;outputCandidateCount=5;projectedOutputCount=$projected;outputFailureCount=@($failures).Count;excludedOutputCount=0;issueCount=0;gateStatus=$GateStatus}
    $summary=[pscustomobject][ordered]@{schemaVersion='1.0.0';identity=[pscustomobject][ordered]@{generatedAt=$generatedAt;snapshotId=$snapshotId;inputFingerprint=$inputFingerprint;ledgerInputFingerprint='dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';discoveryInputFingerprint=$discoveryInputFingerprint;discoveryArtifactFingerprint=$discoveryArtifactFingerprint};provenance=[pscustomobject][ordered]@{toolVersions=@();operationIdentity='C2.DiscoveryCoverage.FixtureValidation'};directEvidence=[pscustomobject][ordered]@{discoveryInputs=@();directChildSummaries=[object[]]$childSummaries;directChildReports=[object[]]$childReports};coverage=[pscustomobject][ordered]@{files=[pscustomobject]@{};containers=[pscustomobject]@{};objects=[pscustomobject]@{};configuration=[pscustomobject]@{};canonical=[pscustomobject]@{};dispatch=[pscustomobject]@{}};failureAccounting=$failureAccounting;decision=[pscustomobject][ordered]@{failureAttribution='TestVector';nextAllowedAction='None'}};$texts[$script:OutputRegistry[7].path]=ConvertTo-C2CanonicalJson $summary
    $artifacts=[Collections.Generic.List[object]]::new();for($i=0;$i-lt8;$i++){$present=$texts.ContainsKey($script:OutputRegistry[$i].path);$text=if($present){[string]$texts[$script:OutputRegistry[$i].path]}else{$null};$artifacts.Add([pscustomobject][ordered]@{artifactId=$script:OutputRegistry[$i].artifactId;path=$script:OutputRegistry[$i].path;desiredState=if($present){'Present'}else{'Absent'};text=$text;sha256=if($present){Get-C2Sha256 $script:Utf8.GetBytes($text)}else{$null};index=$i})}
    $diagnosticEntries=@($artifacts|Where-Object{$_.index-in@(4,5,6,7)}|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}})
    [pscustomobject][ordered]@{gateStatus=$GateStatus;artifacts=[object[]]$artifacts;outputFailures=@($failures);outputExclusions=@();outputAccounting=[pscustomobject][ordered]@{outputCandidateCount=5;projectedOutputCount=$projected;outputFailureCount=@($failures).Count;excludedOutputCount=0};discoveryArtifactFingerprint=$discoveryArtifactFingerprint;diagnosticBundleFingerprint=Get-C2RegisteredArtifactFingerprint Diagnostic $GateStatus $diagnosticEntries;transactionId=Get-C2PublicationTransactionId $snapshotId $generatedAt $inputFingerprint $discoveryInputFingerprint $GateStatus}
}

function Initialize-C2PublicationRecoveryState {
    param([string]$SandboxRoot,[string]$OperationalRoot,[string]$ConsumerRoot,[pscustomobject]$SerializedResult,[ValidateSet('AfterBackup','AfterInstall','UnknownConsumer')][string]$Mode)
    $digest=$SerializedResult.transactionId.Substring('publication-sha256:'.Length);$transaction=[IO.Path]::Combine($OperationalRoot,'transactions',$digest);$stage=[IO.Path]::Combine($transaction,'stage');$backup=[IO.Path]::Combine($transaction,'backup');$null=[IO.Directory]::CreateDirectory($stage);$null=[IO.Directory]::CreateDirectory($backup);$entries=[Collections.Generic.List[object]]::new()
    for($i=0;$i-lt8;$i++){$artifact=$SerializedResult.artifacts[$i];$consumer=Get-C2PublicationChildPath $ConsumerRoot $artifact.path;$priorSha=Get-C2PublicationFileSha $SandboxRoot $consumer;$stageFile=[IO.Path]::Combine($stage,('{0:d2}'-f$i));Write-C2DurableFile $SandboxRoot $stageFile $script:Utf8.GetBytes([string]$artifact.text);$backupFile=[IO.Path]::Combine($backup,('{0:d2}'-f$i));Move-C2PublicationFile $SandboxRoot $consumer $backupFile;$entries.Add([pscustomobject][ordered]@{artifactId=$artifact.artifactId;path=$artifact.path;desiredState='Present';stagedSha256=$artifact.sha256;priorState='Present';priorSha256=$priorSha;backupRelativePath='backup/{0:d2}'-f$i;installState='BackedUp'})}
    $phase='BackingUp';if($Mode-cin@('AfterInstall','UnknownConsumer')){$phase='Installing';for($i=0;$i-le4;$i++){Move-C2PublicationFile $SandboxRoot ([IO.Path]::Combine($stage,('{0:d2}'-f$i))) (Get-C2PublicationChildPath $ConsumerRoot $SerializedResult.artifacts[$i].path);$entries[$i].installState='Installed'}}
    $summary=$SerializedResult.artifacts[7].text|ConvertFrom-Json -Depth 100 -DateKind String;$journal=[pscustomobject][ordered]@{schemaVersion='1.0.0';transactionId=$SerializedResult.transactionId;phase=$phase;gateStatus=$SerializedResult.gateStatus;generatedAt=$summary.identity.generatedAt;expectedPaths=@($script:OutputRegistry.path);entries=[object[]]$entries};Write-C2PublicationJournal $SandboxRoot $OperationalRoot $journal
    if($Mode-ceq'UnknownConsumer'){Write-C2DurableFile $SandboxRoot (Get-C2PublicationChildPath $ConsumerRoot $SerializedResult.artifacts[0].path) $script:Utf8.GetBytes('unknown-consumer-bytes')}
}

function Test-C2PublicationTransactionVector {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][ValidateSet('EmptyPassed','PriorReplacement','UnknownPrior','OrdinaryFailed','PrePreparedOrphan','CrashAfterBackup','CrashAfterInstall','BothJournalForms','CommittedCleanup','UnknownRecoveryBytes','LockContention','LockOpen','Stage05Write','JournalPreparedReplace','Backup02Move','Install04Move','Install07Move','Verify06Hash','Rollback01Restore','RecoveryAmbiguous')][string]$Vector)
    $repository=[IO.Path]::GetFullPath($RepositoryRoot);$testBase=Get-C2PublicationChildPath $repository "Temp/C2DiscoveryPublicationTests/$Vector";if([IO.Directory]::Exists($testBase)){[IO.Directory]::Delete($testBase,$true)};$operational=[IO.Path]::Combine($testBase,'operation');$consumer=[IO.Path]::Combine($testBase,'consumers');$null=[IO.Directory]::CreateDirectory($operational);$null=[IO.Directory]::CreateDirectory($consumer)
    $snapshot=$null
    try{
        $gate=if($Vector-ceq'OrdinaryFailed'){'Failed'}else{'Passed'};$serialized=New-C2PublicationTestSerialization $gate;$prior=@{};$recoveryPriorRestored=$null;$committedCleanupRecovered=$null
        if($Vector-cnotin@('EmptyPassed','PrePreparedOrphan','RecoveryAmbiguous')){$priorSerialization=New-C2PublicationTestSerialization Passed '2026-07-15T00:00:01Z';for($i=0;$i-lt8;$i++){$path=Get-C2PublicationChildPath $consumer $script:OutputRegistry[$i].path;$bytes=$script:Utf8.GetBytes([string]$priorSerialization.artifacts[$i].text);Write-C2DurableFile $testBase $path $bytes;$prior[$i]=Get-C2Sha256 $bytes}}
        if($Vector-ceq'UnknownPrior'){$path=Get-C2PublicationChildPath $consumer $script:OutputRegistry[0].path;$bytes=$script:Utf8.GetBytes("unknown-prior`n");Write-C2DurableFile $testBase $path $bytes;$prior[0]=Get-C2Sha256 $bytes}
        if($Vector-ceq'PrePreparedOrphan'){$orphan=[IO.Path]::Combine($operational,'transactions',('e'*64),'stage');$null=[IO.Directory]::CreateDirectory($orphan);Write-C2DurableFile $testBase ([IO.Path]::Combine($orphan,'00')) $script:Utf8.GetBytes('orphan')}
        if($Vector-cin@('CrashAfterBackup','CrashAfterInstall','BothJournalForms','CommittedCleanup','UnknownRecoveryBytes')){$mode=if($Vector-cin@('CrashAfterBackup','BothJournalForms')){'AfterBackup'}elseif($Vector-ceq'UnknownRecoveryBytes'){'UnknownConsumer'}else{'AfterInstall'};Initialize-C2PublicationRecoveryState $testBase $operational $consumer $serialized $mode;$active=[IO.Path]::Combine($operational,'active-journal.json')
            if($Vector-ceq'BothJournalForms'){Write-C2DurableFile $testBase "$active.next" ([IO.File]::ReadAllBytes($active))}
            if($Vector-ceq'CommittedCleanup'){$journal=Read-C2PublicationJournal $testBase $active;$digest=$serialized.transactionId.Substring('publication-sha256:'.Length);$transaction=[IO.Path]::Combine($operational,'transactions',$digest);for($i=5;$i-lt8;$i++){Move-C2PublicationFile $testBase ([IO.Path]::Combine($transaction,'stage',('{0:d2}'-f$i))) (Get-C2PublicationChildPath $consumer $script:OutputRegistry[$i].path)};foreach($entry in @($journal.entries)){$entry.installState='Verified'};$journal.phase='Committed';Write-C2PublicationJournal $testBase $operational $journal}
            $held=[IO.File]::Open([IO.Path]::Combine($operational,'publication.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$recovered=Invoke-C2PublicationRecovery $testBase $operational $consumer}finally{$held.Dispose()};$recoveryPriorRestored=$recovered-and@(0..7|Where-Object{(Get-C2PublicationFileSha $testBase (Get-C2PublicationChildPath $consumer $script:OutputRegistry[$_].path))-cne$prior[$_]}).Count-eq0;$committedCleanupRecovered=$Vector-ceq'CommittedCleanup'-and$recovered-and@(0..7|Where-Object{(Get-C2PublicationFileSha $testBase (Get-C2PublicationChildPath $consumer $script:OutputRegistry[$_].path))-cne$serialized.artifacts[$_].sha256}).Count-eq0
            if($Vector-ceq'CommittedCleanup'-and$recovered){$result=[pscustomobject][ordered]@{status='Committed';outputAccounting=$serialized.outputAccounting;outputFailures=@();quarantined=$false}}elseif($recovered){$result=Invoke-C2PublicationTransactionCore $testBase $operational $consumer $serialized ''}else{$result=New-C2PublicationFailureResult $serialized.transactionId $true $true}}
        elseif($Vector-ceq'LockContention'){$null=[IO.Directory]::CreateDirectory($operational);$held=[IO.File]::Open([IO.Path]::Combine($operational,'publication.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$result=Invoke-C2PublicationTransactionCore $testBase $operational $consumer $serialized ''}finally{$held.Dispose()}}else{$fault=if($Vector-cin@('EmptyPassed','PriorReplacement','UnknownPrior','OrdinaryFailed','PrePreparedOrphan')){''}else{$Vector};$result=Invoke-C2PublicationTransactionCore $testBase $operational $consumer $serialized $fault}
        $states=[Collections.Generic.List[object]]::new();for($i=0;$i-lt8;$i++){$path=Get-C2PublicationChildPath $consumer $script:OutputRegistry[$i].path;$states.Add([pscustomobject][ordered]@{index=$i;present=[IO.File]::Exists($path);sha256=Get-C2PublicationFileSha $testBase $path;priorSha256=$prior[$i];desiredSha256=$serialized.artifacts[$i].sha256})}
        $transactionRoot=[IO.Path]::Combine($operational,'transactions');$transactionDirectories=if([IO.Directory]::Exists($transactionRoot)){@([IO.Directory]::GetDirectories($transactionRoot)).Count}else{0};$quarantineJournal=$null;if($transactionDirectories){$candidate=@([IO.Directory]::GetFiles($transactionRoot,'journal.json',[IO.SearchOption]::AllDirectories));if($candidate.Count-eq1){$quarantineJournal=Read-C2PublicationJournal $testBase $candidate[0];if($null-eq$quarantineJournal){$text=$script:Utf8.GetString([IO.File]::ReadAllBytes($candidate[0]));$quarantineJournal=$text|ConvertFrom-Json -Depth 100 -DateKind String}}}
        $snapshot=[pscustomobject][ordered]@{vector=$Vector;status=$result.status;outputAccounting=$result.outputAccounting;outputFailureCount=@($result.outputFailures).Count;consumerStates=[object[]]$states;journalPresent=[IO.File]::Exists([IO.Path]::Combine($operational,'active-journal.json'));nextJournalPresent=[IO.File]::Exists([IO.Path]::Combine($operational,'active-journal.json.next'));transactionDirectoryCount=$transactionDirectories;quarantined=$result.quarantined;lockFilePresent=[IO.File]::Exists([IO.Path]::Combine($operational,'publication.lock'));recoveryPriorRestored=$recoveryPriorRestored;committedCleanupRecovered=$committedCleanupRecovered;quarantineJournalPhase=if($null-ne$quarantineJournal){$quarantineJournal.phase}else{$null};journalTopShape=if($null-ne$quarantineJournal){@($quarantineJournal.PSObject.Properties.Name)-join','}else{$null};journalEntryShape=if($null-ne$quarantineJournal){@($quarantineJournal.entries[0].PSObject.Properties.Name)-join','}else{$null};journalExpectedPaths=if($null-ne$quarantineJournal){@($quarantineJournal.expectedPaths)-join','}else{$null}}
    }finally{if([IO.Directory]::Exists($testBase)){[IO.Directory]::Delete($testBase,$true)};$testsRoot=[IO.Path]::GetDirectoryName($testBase);if([IO.Directory]::Exists($testsRoot)-and@([IO.Directory]::GetFileSystemEntries($testsRoot)).Count-eq0){[IO.Directory]::Delete($testsRoot)}}
    $snapshot|Add-Member -NotePropertyName sandboxRemoved -NotePropertyValue (-not[IO.Directory]::Exists($testBase));$snapshot
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
    $states=@('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration');$coverage=[ordered]@{configurationDiscoverySubjectCount=$candidates.Count+$conflicts.Count;configurationCandidateCount=$candidates.Count;configurationConflictCount=$conflicts.Count};foreach($state in $states){$property=if($state-ceq'NotConfiguration'){'notConfigurationCount'}else{$name=if($state-ceq'RequiresRuntimeType'){'requiresRuntimeType'}elseif($state-ceq'LikelyServerDependent'){'likelyServerDependent'}elseif($state-ceq'DiscoveredOpaque'){'discoveredOpaque'}else{$state.ToLowerInvariant()};"${name}ConfigurationCount"};$coverage[$property]=@($candidates|Where-Object configurationDisposition -ceq $state).Count};$failed=$failures.Count-gt0
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

function Get-C2LifecycleStageInputFingerprint {
    param([Parameter(Mandatory)][object[]]$Entries)
    $ordered=[Collections.Generic.List[object]]::new();$seen=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach($entry in $Entries){if(-not(Test-C2ExactShape $entry 'path,sha256')-or-not(Test-C2PortablePath $entry.path)-or$entry.sha256-cnotmatch'^[0-9a-f]{64}$'-or-not$seen.Add([string]$entry.path)){throw 'Invalid lifecycle input entry.'};$ordered.Add($entry)}
    $ordered.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.path,[string]$b.path)})
    $count=[string]$ordered.Count;$text="LifecycleStageInputV1`nentries.count:$($script:Utf8.GetByteCount($count)):$count`n"
    for($i=0;$i-lt$ordered.Count;$i++){$nested=Get-C2ArtifactEntryBytes $ordered[$i].path $ordered[$i].sha256;$text+="entries[$i]:$($nested.Length):$($script:Utf8.GetString($nested))`n"}
    Get-C2Sha256 $script:Utf8.GetBytes($text)
}

function Get-C2LaneFactId {
    param([Parameter(Mandatory)][pscustomobject]$Row)
    $booleanText=if($null-eq$Row.booleanValue){$null}elseif($Row.booleanValue){'true'}else{'false'}
    $text="C3LaneFactV1`n"+(ConvertTo-C2ScalarLine assetObjectId $Row.assetObjectId)+(ConvertTo-C2ScalarLine lane $Row.lane)+(ConvertTo-C2ScalarLine factKind $Row.factKind)+(ConvertTo-C2ScalarLine factStatus $Row.factStatus)+(ConvertTo-C2ScalarLine valueKind $Row.valueKind)+(Add-C2NullableFrame stringValue $Row.stringValue)+(Add-C2NullableFrame integerValue $Row.integerValue)+(Add-C2NullableFrame booleanValue $booleanText)+(Add-C2SetFrame idValues @($Row.idValues))+(Add-C2SetFrame evidence @($Row.evidence))
    "lane-fact-sha256:$(Get-C2Sha256 $script:Utf8.GetBytes($text))"
}

function New-C2LaneFactFailureResult {
    param([string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string[]]$Evidence)
    $row=New-C2AccountingRow inputFailures $SubjectKind $SubjectId $ReasonCode "LC-I06:$SubjectId" $Evidence
    [pscustomobject][ordered]@{gateStatus='Failed';package=$null;subjectAccounting=@();inputFailures=[object[]]@($row);outputsSuppressed=$true}
}

function New-C2LaneFactRow {
    param([string]$AssetObjectId,[string]$Lane,[string]$FactKind,[string]$ValueKind,$Value,[string[]]$IdValues,[string[]]$Evidence)
    $row=[pscustomobject][ordered]@{factId='';assetObjectId=$AssetObjectId;lane=$Lane;factKind=$FactKind;factStatus='Known';valueKind=$ValueKind;stringValue=if($ValueKind-ceq'String'){[string]$Value}else{$null};integerValue=if($ValueKind-ceq'Integer'){[long]$Value}else{$null};booleanValue=if($ValueKind-ceq'Boolean'){[bool]$Value}else{$null};idValues=if($ValueKind-ceq'IdSet'){[string[]](Get-C2OrdinalUnique $IdValues)}else{,[string[]]@()};evidence=[string[]](Get-C2OrdinalUnique $Evidence)}
    $row.factId=Get-C2LaneFactId $row;$row
}

function Invoke-C2TypedLaneFactProjection {
    [CmdletBinding()]param(
        [Parameter(Mandatory)][byte[]]$DispatchBytes,
        [Parameter(Mandatory)][byte[]]$SummaryBytes,
        [Parameter(Mandatory)][byte[]]$SchemaBytes
    )
    $dispatchPath='Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json';$summaryPath='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json';$schemaPath='docs/asset-migration/schemas/c2-lane-fact-package.schema.json';$strictUtf8=[Text.UTF8Encoding]::new($false,$true)
    try{$dispatchText=$strictUtf8.GetString($DispatchBytes);$dispatch=$dispatchText|ConvertFrom-Json -Depth 100 -DateKind String;if((ConvertTo-C2CanonicalJson $dispatch)-cne$dispatchText){throw 'dispatch canonical bytes'}}catch{return New-C2LaneFactFailureResult Artifact AR-O04 InvalidSchema @($dispatchPath)}
    try{$summaryText=$strictUtf8.GetString($SummaryBytes);$summary=$summaryText|ConvertFrom-Json -Depth 100 -DateKind String;if((ConvertTo-C2CanonicalJson $summary)-cne$summaryText){throw 'summary canonical bytes'}}catch{return New-C2LaneFactFailureResult Artifact AR-O05-Summary InvalidSchema @($summaryPath)}
    try{$schemaText=$strictUtf8.GetString($SchemaBytes);$schema=$schemaText|ConvertFrom-Json -Depth 100 -DateKind String;$required=@($schema.properties.rows.items.required);if($schema.'$id'-cne'https://stellagaia.dev/schemas/c2-lane-fact-package.schema.json'-or$schema.properties.schemaVersion.const-cne'1.0.0'-or$required.Count-ne11-or@($schema.properties.rows.items.oneOf).Count-ne6){throw 'schema contract'}}catch{return New-C2LaneFactFailureResult Artifact LC-I13 InvalidSchema @($schemaPath)}
    if(-not(Test-C2ExactShape $dispatch 'schemaVersion,generatedAt,snapshotId,inputFingerprint,discoveryInputFingerprint,sourceLedgerPath,rows')-or$dispatch.schemaVersion-cne'1.0.0'-or$dispatch.generatedAt-cnotmatch'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'-or[string]::IsNullOrWhiteSpace([string]$dispatch.snapshotId)-or$dispatch.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$dispatch.discoveryInputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or-not(Test-C2PortablePath $dispatch.sourceLedgerPath)) {return New-C2LaneFactFailureResult Artifact AR-O04 InvalidSchema @($dispatchPath)}
    if(-not(Test-C2ExactShape $summary 'schemaVersion,identity,provenance,directEvidence,coverage,failureAccounting,decision')-or$summary.schemaVersion-cne'1.0.0'-or-not(Test-C2ExactShape $summary.identity 'generatedAt,snapshotId,inputFingerprint,ledgerInputFingerprint,discoveryInputFingerprint,discoveryArtifactFingerprint')-or$summary.failureAccounting.gateStatus-cne'Passed'-or$summary.identity.discoveryArtifactFingerprint-cnotmatch'^[0-9a-f]{64}$') {return New-C2LaneFactFailureResult Artifact AR-O05-Summary InvalidSchema @($summaryPath)}
    if($dispatch.generatedAt-cne$summary.identity.generatedAt-or$dispatch.snapshotId-cne$summary.identity.snapshotId-or$dispatch.inputFingerprint-cne$summary.identity.inputFingerprint-or$dispatch.discoveryInputFingerprint-cne$summary.identity.discoveryInputFingerprint){return New-C2LaneFactFailureResult Artifact AR-O05-Summary IdentityMismatch @($dispatchPath,$summaryPath)}
    $entries=@([pscustomobject][ordered]@{path=$dispatchPath;sha256=Get-C2Sha256 $DispatchBytes},[pscustomobject][ordered]@{path=$summaryPath;sha256=Get-C2Sha256 $SummaryBytes},[pscustomobject][ordered]@{path=$schemaPath;sha256=Get-C2Sha256 $SchemaBytes});$inputFingerprint=Get-C2LifecycleStageInputFingerprint $entries;$factContractFingerprint=Get-C2Sha256 $SchemaBytes
    $facts=[Collections.Generic.List[object]]::new();$accounting=[Collections.Generic.List[object]]::new();$seenObjects=[Collections.Generic.HashSet[string]]::new($script:Ordinal);$previousObject=$null
    foreach($row in @($dispatch.rows)){
        $objectId=if($null-ne$row){[string]$row.assetObjectId}else{''};if(-not(Test-C2ExactShape $row 'assetObjectId,canonicalAssetId,sourceId,familyLane,memberSelectorInputs,configurationCandidateId,dispatchStatus,evidence')-or$objectId-cnotmatch'^sha256:[0-9a-f]{64}$'-or-not$seenObjects.Add($objectId)-or($null-ne$previousObject-and$script:Ordinal.Compare($previousObject,$objectId)-ge0)-or-not(Test-C2OrdinalPortableSet @($row.evidence) $true)){return New-C2LaneFactFailureResult DispatchObject $(if($objectId){$objectId}else{'LC-I06:Projection'}) ConservationMismatch @($dispatchPath)};$previousObject=$objectId
        $terminal=$null;$factIds=@();if($row.dispatchStatus-ceq'Assigned'-and$row.familyLane-cin@('Audio','Environment','Actor','UI','Effects')-and$null-eq$row.configurationCandidateId){$terminal='AssignedFactsProjected'}elseif($row.dispatchStatus-ceq'RetainedForDiagnosis'-and$row.familyLane-ceq'Unassigned'-and$null-eq$row.configurationCandidateId){$terminal='RetainedNoLaneFacts'}elseif($row.dispatchStatus-ceq'ConfigurationOnly'-and$row.familyLane-ceq'Unassigned'-and$null-ne$row.configurationCandidateId){$terminal='ConfigurationNoLaneFacts'}else{return New-C2LaneFactFailureResult DispatchObject $objectId ConservationMismatch @($dispatchPath)}
        if($terminal-ceq'AssignedFactsProjected'){
            $selectors=@($row.memberSelectorInputs);$selectorKeys=[Collections.Generic.List[string]]::new();$selectorSeen=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($selector in $selectors){if(-not(Test-C2ExactShape $selector 'kind,value')-or[string]::IsNullOrWhiteSpace([string]$selector.kind)-or[string]::IsNullOrWhiteSpace([string]$selector.value)){return New-C2LaneFactFailureResult DispatchObject $objectId InvalidSchema @($dispatchPath)};$key="$($selector.kind)`n$($selector.value)";if(-not$selectorSeen.Add($key)) {return New-C2LaneFactFailureResult DispatchObject $objectId ConservationMismatch @($dispatchPath)};$selectorKeys.Add($key)};$orderedKeys=@($selectorKeys|Sort-Object -CaseSensitive);if(($selectorKeys-join"`n")-cne($orderedKeys-join"`n")){return New-C2LaneFactFailureResult DispatchObject $objectId ConservationMismatch @($dispatchPath)}
            foreach($kind in @('ObjectType','ClassId','CanonicalAssetId','PlatformVariant')){if(@($selectors|Where-Object{$_.kind-ceq$kind}).Count-ne1){return New-C2LaneFactFailureResult DispatchObject $objectId ConservationMismatch @($dispatchPath)}};if(@($selectors|Where-Object{$_.kind-ceq'ToolObservation'}).Count-lt1-or@($selectors|Where-Object{$_.kind-cnotin@('ObjectType','ClassId','CanonicalAssetId','PlatformVariant','DependencyObjectId','ToolObservation')}).Count){return New-C2LaneFactFailureResult DispatchObject $objectId ConservationMismatch @($dispatchPath)}
            $classText=[string]@($selectors|Where-Object{$_.kind-ceq'ClassId'})[0].value;$classValue=0L;if($classText-cnotmatch'^(0|[1-9][0-9]*)$'-or-not[long]::TryParse($classText,[Globalization.NumberStyles]::None,[Globalization.CultureInfo]::InvariantCulture,[ref]$classValue)){return New-C2LaneFactFailureResult DispatchObject $objectId InvalidSchema @($dispatchPath)}
            $newFacts=[Collections.Generic.List[object]]::new();$newFacts.Add((New-C2LaneFactRow $objectId $row.familyLane ObjectType String ([string]@($selectors|Where-Object{$_.kind-ceq'ObjectType'})[0].value) @() @($row.evidence)));$newFacts.Add((New-C2LaneFactRow $objectId $row.familyLane ClassId Integer $classValue @() @($row.evidence)));$newFacts.Add((New-C2LaneFactRow $objectId $row.familyLane CanonicalAssetId String ([string]@($selectors|Where-Object{$_.kind-ceq'CanonicalAssetId'})[0].value) @() @($row.evidence)));$newFacts.Add((New-C2LaneFactRow $objectId $row.familyLane PlatformVariant String ([string]@($selectors|Where-Object{$_.kind-ceq'PlatformVariant'})[0].value) @() @($row.evidence)));$dependencies=@($selectors|Where-Object{$_.kind-ceq'DependencyObjectId'}|ForEach-Object{$_.value});if($dependencies.Count){if(@($dependencies|Where-Object{$_-cnotmatch'^sha256:[0-9a-f]{64}$'}).Count){return New-C2LaneFactFailureResult DispatchObject $objectId InvalidSchema @($dispatchPath)};$newFacts.Add((New-C2LaneFactRow $objectId $row.familyLane DependencyObjectIds IdSet $null $dependencies @($row.evidence)))}
            foreach($fact in $newFacts){$facts.Add($fact)};$factIds=@($newFacts|ForEach-Object factId|Sort-Object -CaseSensitive)
        }
        $accounting.Add([pscustomobject][ordered]@{assetObjectId=$objectId;terminalStatus=$terminal;factIds=[string[]]$factIds;reasonCode=$terminal;evidence=[string[]](Get-C2OrdinalUnique @($row.evidence))})
    }
    $facts.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.factId,[string]$b.factId)});$factIds=@($facts|ForEach-Object{$_.factId});$accountingFactIds=@($accounting|ForEach-Object{@($_.factIds)}|ForEach-Object{$_}|Sort-Object -CaseSensitive);if(@(Get-C2OrdinalUnique $factIds).Count-ne$facts.Count-or($accountingFactIds-join"`n")-cne($factIds-join"`n")){return New-C2LaneFactFailureResult ProjectionCheck 'LC-I06:Projection' ProjectionInvalid @($dispatchPath,$summaryPath,$schemaPath)}
    $package=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$dispatch.generatedAt;snapshotId=$dispatch.snapshotId;c2GenerationFingerprint=$summary.identity.discoveryArtifactFingerprint;factContractFingerprint=$factContractFingerprint;inputFingerprint=$inputFingerprint;rows=[object[]]$facts}
    [pscustomobject][ordered]@{gateStatus='Passed';package=$package;subjectAccounting=[object[]]$accounting;inputFailures=@();outputsSuppressed=$false}
}

function Test-C2ContractChangeRequest {
    param([AllowNull()]$Request)
    try{
        if($null-eq$Request-or(@($Request.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,requestId,reason,nextAllowedAction,inputFingerprint,discoveryInputFingerprint,status,missingProjectionFields,evidence'){return $false}
        if($Request.schemaVersion-cne'1.0.0'-or$Request.generatedAt-cnotmatch'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$'-or$Request.requestId-cne'C0ContractChange:C2StructuredCoverage:1.0.0'-or$Request.reason-cne'Root gate summary schema 2.0.0 losslessly represents mandatory C2 structured coverage partitions.'-or$Request.nextAllowedAction-cne'Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.'-or$Request.inputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$Request.discoveryInputFingerprint-cnotmatch'^[0-9a-f]{64}$'-or$Request.status-cne'Resolved'){return $false}
        if((@($Request.missingProjectionFields)-join"`n")-cne($script:MissingProjectionFields-join"`n")){return $false}
        $expectedEvidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json','docs/asset-migration/schemas/root-gate-summary.schema.json');[Array]::Sort($expectedEvidence,$script:Ordinal)
        if((@($Request.evidence)-join"`n")-cne($expectedEvidence-join"`n")){return $false}
        return $true
    }catch{return $false}
}

function Test-C2ConservationStages {
    param([object[]]$Stages)
    $expected=[ordered]@{
        'SP-01'=[ordered]@{'Files'=@('Container','NonContainer')}
        'SP-02'=[ordered]@{'Files'=@('NotAttempted','Parsed','Opaque','Failed','Conflict');'Containers'=@('NotAttempted','Parsed','Opaque','Failed','Conflict')}
        'SP-03a'=[ordered]@{'Observations'=@('Accepted','Rejected','Excluded')}
        'SP-03b'=[ordered]@{'CorrelationGroups'=@('Resolved','Conflict')}
        'SP-04'=[ordered]@{'Objects'=@('Classified','Unclassified')}
        'SP-05'=[ordered]@{'Targets'=@('Candidates','Conflicts');'Disposition'=@('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration')}
        'SP-06'=[ordered]@{'Objects'=@('Canonicalized','Conflicts');'Groups'=@('ExactDuplicate','CrossPlatformVariant','Unresolved')}
        'SP-07'=[ordered]@{'Dispatch'=@('Assigned','RetainedForDiagnosis','ConfigurationOnly');'Lanes'=@('Audio','Environment','Actor','UI','Effects','Unassigned')}
    }
    if(@($Stages).Count-ne$expected.Count){return $false}
    $stageIndex=0
    foreach($stageName in $expected.Keys){
        $stage=$Stages[$stageIndex++]
        if(-not(Test-C2ExactShape $stage 'stageId,equations')-or$stage.stageId-cne$stageName-or@($stage.equations).Count-ne$expected[$stageName].Count){return $false}
        $equationIndex=0
        foreach($equationName in $expected[$stageName].Keys){
            $equation=$stage.equations[$equationIndex++]
            if(-not(Test-C2ExactShape $equation 'equationId,universe,partitions')-or$equation.equationId-cne$equationName-or@($equation.partitions).Count-ne$expected[$stageName][$equationName].Count){return $false}
            $universe=[Collections.Generic.Dictionary[string,long]]::new($script:Ordinal)
            foreach($member in @($equation.universe)){if(-not(Test-C2ExactShape $member 'id,sizeBytes')-or$member.id-isnot[string]-or[string]::IsNullOrEmpty($member.id)-or$member.sizeBytes-isnot[long]-or[long]$member.sizeBytes-lt0-or$universe.ContainsKey($member.id)){return $false};$universe.Add($member.id,[long]$member.sizeBytes)}
            $seen=[Collections.Generic.HashSet[string]]::new($script:Ordinal);$partitionIndex=0;$partitionBytes=[long]0
            foreach($partitionName in $expected[$stageName][$equationName]){
                $partition=$equation.partitions[$partitionIndex++]
                if(-not(Test-C2ExactShape $partition 'name,members')-or$partition.name-cne$partitionName){return $false}
                foreach($member in @($partition.members)){if(-not(Test-C2ExactShape $member 'id,sizeBytes')-or-not$universe.ContainsKey([string]$member.id)-or[long]$member.sizeBytes-ne$universe[[string]$member.id]-or-not$seen.Add([string]$member.id)){return $false};$partitionBytes+=[long]$member.sizeBytes}
            }
            $universeBytes=[long]0;foreach($value in $universe.Values){$universeBytes+=$value}
            if($seen.Count-ne$universe.Count-or$partitionBytes-ne$universeBytes){return $false}
        }
    }
    return $true
}

function New-C2StageMember {param([string]$Id,[long]$SizeBytes=0)[pscustomobject][ordered]@{id=$Id;sizeBytes=$SizeBytes}}
function New-C2StagePartition {param([string]$Name,[object[]]$Members)[pscustomobject][ordered]@{name=$Name;members=[object[]]@($Members)}}
function New-C2StageEquation {param([string]$EquationId,[object[]]$Universe,[object[]]$Partitions)[pscustomobject][ordered]@{equationId=$EquationId;universe=[object[]]@($Universe);partitions=[object[]]@($Partitions)}}
function New-C2Stage {param([string]$StageId,[object[]]$Equations)[pscustomobject][ordered]@{stageId=$StageId;equations=[object[]]@($Equations)}}
function Select-C2CoverageFields {param([psobject]$Source,[string[]]$Names)$result=[ordered]@{};foreach($name in $Names){$result[$name]=[long]$Source.$name};[pscustomobject]$result}

function Test-C2PublicProjectionFact {
    param([AllowNull()]$Fact,[AllowNull()]$ContractChangeRequest,[object[]]$Stages)
    if($null-eq$Fact-or-not(Test-C2ExactShape $Fact 'toolVersions,sources,files,objects,configurationCandidates,configurationConflicts,canonicalGroups,canonicalConflicts,dispatchRows,resolvedFileResults,mergedObjectCandidates,canonicalProposalProvenance,dispatchInputFacts,fileDiscoveryConflicts,observationConflicts,inputFailures,inputExclusions,inputSuppressions,discoveryInputs,coverage,decision')){return $false}
    $probe=[pscustomobject]@{toolVersions=@($Fact.toolVersions);sources=@($Fact.sources);files=@($Fact.files);objects=@($Fact.objects);configurationCandidates=@($Fact.configurationCandidates);configurationConflicts=@($Fact.configurationConflicts);canonicalGroups=@($Fact.canonicalGroups);canonicalConflicts=@($Fact.canonicalConflicts);dispatchRows=@($Fact.dispatchRows);resolvedFileResults=@($Fact.resolvedFileResults);mergedObjectCandidates=@($Fact.mergedObjectCandidates);canonicalProposalProvenance=@($Fact.canonicalProposalProvenance);dispatchInputFacts=@($Fact.dispatchInputFacts);fileDiscoveryConflicts=@($Fact.fileDiscoveryConflicts);observationConflicts=@($Fact.observationConflicts);inputFailures=@($Fact.inputFailures);inputExclusions=@($Fact.inputExclusions);inputSuppressions=@($Fact.inputSuppressions);discoveryInputs=@($Fact.discoveryInputs);coverage=$Fact.coverage;decision=$Fact.decision}
    if(-not(Test-C2OutputInputShapes $probe)-or-not(Test-C2ContractChangeRequest $ContractChangeRequest)){return $false}
    try{$derivedFingerprint=Get-C2DiscoveryInputFingerprint -Entries @($Fact.discoveryInputs)}catch{return $false};if($derivedFingerprint-cne$ContractChangeRequest.discoveryInputFingerprint){return $false}
    $fileKeys=@($Fact.files|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"});$resolvedKeys=@($Fact.resolvedFileResults|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"})
    if(@(Get-C2OrdinalUnique $fileKeys).Count-ne$fileKeys.Count-or@(Get-C2OrdinalUnique $resolvedKeys).Count-ne$resolvedKeys.Count){return $false}
    foreach($row in @($Fact.resolvedFileResults)){if($fileKeys-cnotcontains"$($row.sourceId)`n$($row.relativePath)"){return $false}}
    if([long]$Fact.coverage.files.catalogedFileCount-ne@($Fact.files).Count-or[long]$Fact.coverage.objects.enumeratedObjectCount-ne@($Fact.objects).Count-or[long]$Fact.coverage.configuration.configurationCandidateCount-ne@($Fact.configurationCandidates).Count-or[long]$Fact.coverage.configuration.configurationConflictCount-ne@($Fact.configurationConflicts).Count-or[long]$Fact.coverage.canonical.canonicalGroupCount-ne@($Fact.canonicalGroups).Count-or[long]$Fact.coverage.canonical.canonicalConflictObjectCount-ne@($Fact.canonicalConflicts).Count-or[long]$Fact.coverage.dispatch.dispatchEligibleObjectCount-ne@($Fact.dispatchRows).Count){return $false}
    function Get-PartitionIds([string]$stageId,[string]$equationId,[string]$partitionName){@($Stages|Where-Object stageId -ceq $stageId)[0].equations|Where-Object equationId -ceq $equationId|ForEach-Object partitions|Where-Object name -ceq $partitionName|ForEach-Object members|ForEach-Object id}
    $containerIds=@($Fact.files|Where-Object{$_.containerKind-cnotin@('DirectMedia','Metadata','ConfigurationCandidate')}|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"});$nonContainerIds=@($Fact.files|Where-Object{$_.containerKind-cin@('DirectMedia','Metadata','ConfigurationCandidate')}|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"})
    $actualContainer=@(Get-C2OrdinalUnique @(Get-PartitionIds 'SP-01' 'Files' 'Container'));$expectedContainer=@(Get-C2OrdinalUnique $containerIds);$actualNonContainer=@(Get-C2OrdinalUnique @(Get-PartitionIds 'SP-01' 'Files' 'NonContainer'));$expectedNonContainer=@(Get-C2OrdinalUnique $nonContainerIds)
    if(($actualContainer-join"`n")-cne($expectedContainer-join"`n")-or($actualNonContainer-join"`n")-cne($expectedNonContainer-join"`n")){return $false}
    foreach($status in @('NotAttempted','Parsed','Opaque','Failed','Conflict')){$actual=@(Get-C2OrdinalUnique @(Get-PartitionIds 'SP-02' 'Files' $status));$expectedStatus=if($status-ceq'Parsed'){@(Get-C2OrdinalUnique @($Fact.resolvedFileResults|Where-Object parseStatus -cin @('Parsed','ExtractedReadable','CrossToolVerified')|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"}))}elseif($status-ceq'Conflict'){@(Get-C2OrdinalUnique @($Fact.fileDiscoveryConflicts|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"}))}else{@(Get-C2OrdinalUnique @($Fact.resolvedFileResults|Where-Object parseStatus -ceq $status|ForEach-Object{"$($_.sourceId)`n$($_.relativePath)"}))};if(($actual-join"`n")-cne($expectedStatus-join"`n")){return $false}}
    return $true
}

function Invoke-C2InputAccounting {
    [CmdletBinding()]param([Parameter(Mandatory)][psobject]$InputFact)
    $expectedInputNames='artifactStates,rawObservationSubjects,conflictSubjects,inputFailures,inputExclusions,runtimeFacts,contractChangeRequest,stageConservationSets,publicProjection,discoveryInputFingerprint'
    $inputShapeValid=(@($InputFact.PSObject.Properties.Name)-join',')-ceq$expectedInputNames
    $artifactInput=@($InputFact.artifactStates)
    $artifactStates=@($artifactInput|Where-Object readStatus -in @('Accepted','Failed'))
    $artifactShapeInvalid=$false;$artifactIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach($state in $artifactInput){
        if($null-eq$state-or-not$state.PSObject.Properties['artifactId']-or-not$state.PSObject.Properties['readStatus']-or-not@('Accepted','Failed','NotRead').Contains([string]$state.readStatus)-or-not@($script:Registry.artifactId).Contains([string]$state.artifactId)-or-not$artifactIds.Add([string]$state.artifactId)){$artifactShapeInvalid=$true}
    }
    $raw=@($InputFact.rawObservationSubjects)
    $conflicts=@($InputFact.conflictSubjects)
    $failures=[Collections.Generic.List[object]]::new();foreach($row in @($InputFact.inputFailures)){$failures.Add($row)}
    $exclusions=@($InputFact.inputExclusions)
    $suppressions=[Collections.Generic.List[object]]::new()
    $checks=[Collections.Generic.List[object]]::new()
    $runtime=$InputFact.runtimeFacts;$runtimeValid=$null-ne$runtime-and(@($runtime.PSObject.Properties.Name)-join',')-ceq'heavyProcessCount,realAssetReadCount,createdExtractedCount,createdImportedCount,astViolationCount,startCommitOid,endCommitOid,headStable'
    $lightweightAccepted=$runtimeValid-and[long]$runtime.heavyProcessCount-eq0-and[long]$runtime.realAssetReadCount-eq0-and[long]$runtime.createdExtractedCount-eq0-and[long]$runtime.createdImportedCount-eq0-and[long]$runtime.astViolationCount-eq0
    if($lightweightAccepted){$checks.Add((New-C2Check 'C2Check:LightweightPolicy' Accepted 'Accepted:C2Check:LightweightPolicy' @('Tools/AssetImport/C2DiscoveryIntakeGate.psm1','Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1') @()))}else{if(-not@($failures|Where-Object subjectId -ceq 'C2Check:LightweightPolicy')){$failures.Add((New-C2AccountingRow inputFailures LightweightPolicy 'C2Check:LightweightPolicy' HeavyOperationAttempted 'FT-13:C2Check:LightweightPolicy' @('Tools/AssetImport/C2DiscoveryIntakeGate.psm1')))};$checks.Add((New-C2Check 'C2Check:LightweightPolicy' Failed 'FT-13:C2Check:LightweightPolicy' @('Tools/AssetImport/C2DiscoveryIntakeGate.psm1') @()))}
    $handoffAccepted=@($artifactStates|Where-Object{$_.artifactId-cin@('AR-I01','AR-I02','AR-I03')-and$_.readStatus-ceq'Accepted'-and(-not$_.PSObject.Properties['identityStatus']-or$_.identityStatus-cne'Failed')}).Count-eq3
    if($handoffAccepted){$checks.Add((New-C2Check 'C2Check:C1Handoff' Accepted 'Accepted:C2Check:C1Handoff' @($script:Registry[0].path,$script:Registry[1].path,$script:Registry[2].path) @('AR-I01','AR-I02','AR-I03')))}else{if(-not@($failures|Where-Object subjectId -ceq 'C2Check:C1Handoff')){$failures.Add((New-C2AccountingRow inputFailures C1Handoff 'C2Check:C1Handoff' InvalidSchema 'FT-01:C2Check:C1Handoff' @($script:Registry[0].path)))};$checks.Add((New-C2Check 'C2Check:C1Handoff' Failed 'FT-01:C2Check:C1Handoff' @($script:Registry[0].path) @('AR-I01','AR-I02','AR-I03')))}
    $freshnessUnavailable=@($failures|Where-Object{$_.attribution-cmatch'^FT-(01|02|04):'-and$_.subjectId-cmatch'^(AR-I\d\d|C2Check:C1Handoff)$'}).Count-gt0
    $freshnessAccepted=$runtimeValid-and$runtime.startCommitOid-cmatch'^[0-9a-f]{40}$'-and$runtime.endCommitOid-cmatch'^[0-9a-f]{40}$'-and$runtime.startCommitOid-ceq$runtime.endCommitOid-and$runtime.headStable-eq$true-and@($artifactStates|Where-Object{$_.PSObject.Properties['freshnessStatus']-and$_.freshnessStatus-ceq'Failed'}).Count-eq0
    $freshnessEvidence=@($artifactStates|ForEach-Object{$id=$_.artifactId;@($script:Registry|Where-Object artifactId -ceq $id)[0].path});[Array]::Sort($freshnessEvidence,$script:Ordinal)
    $freshnessPrerequisites=Get-C2OrdinalUnique @(@($artifactStates.artifactId)+@('GitAdapter:StartCommitOid','GitAdapter:EndHead'))
    if($freshnessUnavailable){$checks.Add((New-C2Check 'C2Check:Freshness' NotEvaluated 'FT-15:C2Check:Freshness' $freshnessEvidence $freshnessPrerequisites));if(-not@($suppressions|Where-Object subjectId -ceq 'C2Check:Freshness')){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Freshness' PrerequisiteUnavailable 'FT-15:C2Check:Freshness' $freshnessEvidence))}}
    elseif($freshnessAccepted){$checks.Add((New-C2Check 'C2Check:Freshness' Accepted 'Accepted:C2Check:Freshness' $freshnessEvidence $freshnessPrerequisites))}
    else{if(-not@($failures|Where-Object subjectId -ceq 'C2Check:Freshness')){$failures.Add((New-C2AccountingRow inputFailures FreshnessCheck 'C2Check:Freshness' StaleFingerprint 'FT-03:C2Check:Freshness' $freshnessEvidence))};$checks.Add((New-C2Check 'C2Check:Freshness' Failed 'FT-03:C2Check:Freshness' $freshnessEvidence $freshnessPrerequisites))}

    $conservationAvailable=@($artifactStates|Where-Object{$_.artifactId-cin@('AR-I01','AR-I02','AR-I03')-and$_.readStatus-ceq'Accepted'}).Count-eq3-and@($artifactStates|Where-Object{$_.artifactId-cin@('AR-I07','AR-I08','AR-I09')-and$_.readStatus-ceq'Failed'}).Count-eq0
    $conservationInvalid=-not$inputShapeValid-or-not$runtimeValid-or$artifactShapeInvalid
    $stageIds=@('SP-01','SP-02','SP-03a','SP-03b','SP-04','SP-05','SP-06','SP-07');$stageSets=@($InputFact.stageConservationSets)
    if(-not(Test-C2ConservationStages $stageSets)){$conservationInvalid=$true}
    $rawKinds=@('ObjectObservation','FileDiscoveryObservation','FileConfigurationObservation');$conflictKinds=@('FileDiscoveryConflict','ObservationConflict','ConfigurationConflict','CanonicalConflict')
    $rawIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal);$expectedFailureIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal);$expectedExclusionIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal)
    foreach($row in $raw){
        $prefixValid=($row.subjectKind-ceq'ObjectObservation'-and$row.subjectId-cmatch'^(?:observation|raw-row)-sha256:[0-9a-f]{64}$')-or($row.subjectKind-ceq'FileDiscoveryObservation'-and$row.subjectId-cmatch'^(?:file-discovery-observation|raw-row)-sha256:[0-9a-f]{64}$')-or($row.subjectKind-ceq'FileConfigurationObservation'-and$row.subjectId-cmatch'^(?:configuration-observation|raw-row)-sha256:[0-9a-f]{64}$')
        if((@($row.PSObject.Properties.Name)-join',')-cne'subjectKind,subjectId,partition'-or$row.subjectKind-cnotin$rawKinds-or$row.partition-cnotin@('Accepted','InputFailure','InputExclusion')-or-not$prefixValid-or-not$rawIds.Add([string]$row.subjectId)){$conservationInvalid=$true};if($row.partition-ceq'InputFailure'){$null=$expectedFailureIds.Add([string]$row.subjectId)}elseif($row.partition-ceq'InputExclusion'){$null=$expectedExclusionIds.Add([string]$row.subjectId)}
    }
    $conflictIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($row in $conflicts){if((@($row.PSObject.Properties.Name)-join',')-cne'subjectKind,subjectId'-or$row.subjectKind-cnotin$conflictKinds-or-not$conflictIds.Add([string]$row.subjectId)-or$rawIds.Contains([string]$row.subjectId)){$conservationInvalid=$true};$null=$expectedFailureIds.Add([string]$row.subjectId)}
    foreach($state in @($artifactStates|Where-Object readStatus -ceq Failed)){$null=$expectedFailureIds.Add([string]$state.artifactId)}
    foreach($check in @($checks|Where-Object status -ceq Failed)){$null=$expectedFailureIds.Add([string]$check.subjectId)}
    $accountingShape='recordId,subjectKind,subjectId,reasonCode,attribution,evidence'
    $actualFailureIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($failure in $failures){
        $expectedRow=if($null-ne$failure-and(@($failure.PSObject.Properties.Name)-join',')-ceq$accountingShape){New-C2AccountingRow inputFailures $failure.subjectKind $failure.subjectId $failure.reasonCode $failure.attribution @($failure.evidence)}else{$null}
        if($null-eq$expectedRow-or$failure.recordId-cne$expectedRow.recordId-or(@($failure.evidence)-join"`n")-cne(@($expectedRow.evidence)-join"`n")-or-not$actualFailureIds.Add([string]$failure.subjectId)){$conservationInvalid=$true}
    }
    $actualExclusionIds=[Collections.Generic.HashSet[string]]::new($script:Ordinal);foreach($exclusion in $exclusions){
        $expectedRow=if($null-ne$exclusion-and(@($exclusion.PSObject.Properties.Name)-join',')-ceq$accountingShape){New-C2AccountingRow inputExclusions $exclusion.subjectKind $exclusion.subjectId $exclusion.reasonCode $exclusion.attribution @($exclusion.evidence)}else{$null}
        if($null-eq$expectedRow-or$exclusion.recordId-cne$expectedRow.recordId-or(@($exclusion.evidence)-join"`n")-cne(@($expectedRow.evidence)-join"`n")-or-not$actualExclusionIds.Add([string]$exclusion.subjectId)){$conservationInvalid=$true}
    }
    $expectedFailureArray=[string[]]$expectedFailureIds;[Array]::Sort($expectedFailureArray,$script:Ordinal);$actualFailureArray=[string[]]$actualFailureIds;[Array]::Sort($actualFailureArray,$script:Ordinal)
    $expectedExclusionArray=[string[]]$expectedExclusionIds;[Array]::Sort($expectedExclusionArray,$script:Ordinal);$actualExclusionArray=[string[]]$actualExclusionIds;[Array]::Sort($actualExclusionArray,$script:Ordinal)
    if(($expectedFailureArray-join"`n")-cne($actualFailureArray-join"`n")-or($expectedExclusionArray-join"`n")-cne($actualExclusionArray-join"`n")){$conservationInvalid=$true}

    $sidecarPath='Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json';$contractPath='Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json'
    if(-not$conservationAvailable){$checks.Add((New-C2Check 'C2Check:Conservation' NotEvaluated 'FT-15:C2Check:Conservation' @($sidecarPath) @('AR-I01','AR-I02','AR-I03','AR-I07','AR-I08','AR-I09')));if(-not@($suppressions|Where-Object subjectId -ceq 'C2Check:Conservation')){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:Conservation' PrerequisiteUnavailable 'FT-15:C2Check:Conservation' @($sidecarPath)))}}
    elseif($conservationInvalid){if(-not@($failures|Where-Object subjectId -ceq 'C2Check:Conservation')){$failures.Add((New-C2AccountingRow inputFailures ConservationCheck 'C2Check:Conservation' ConservationMismatch 'FT-10:C2Check:Conservation' @($sidecarPath)))};$checks.Add((New-C2Check 'C2Check:Conservation' Failed 'FT-10:C2Check:Conservation' @($sidecarPath) @($stageIds)))}
    else{$checks.Add((New-C2Check 'C2Check:Conservation' Accepted 'None' @($sidecarPath) @($stageIds)))}

    $projectionPrerequisite=@($artifactStates|Where-Object{$_.artifactId-cin@('AR-I04','AR-I05','AR-I06')-and$_.readStatus-ceq'Accepted'}).Count-eq3-and$checks[3].status-ceq'Accepted'
    if(-not$projectionPrerequisite){$checks.Add((New-C2Check 'C2Check:PublicProjection' NotEvaluated 'FT-15:C2Check:PublicProjection' @($sidecarPath) @('C2Check:Conservation','AR-I04','AR-I05','AR-I06')));if(-not@($suppressions|Where-Object subjectId -ceq 'C2Check:PublicProjection')){$suppressions.Add((New-C2AccountingRow inputSuppressions ContractCheck 'C2Check:PublicProjection' PrerequisiteUnavailable 'FT-15:C2Check:PublicProjection' @($sidecarPath)))}}
    elseif(-not(Test-C2PublicProjectionFact $InputFact.publicProjection $InputFact.contractChangeRequest $stageSets)){if(-not@($failures|Where-Object subjectId -ceq 'C2Check:PublicProjection')){$failures.Add((New-C2AccountingRow inputFailures PublicProjection 'C2Check:PublicProjection' ProjectionInvalid 'FT-11:C2Check:PublicProjection' @($contractPath,$script:Registry[5].path)))};$checks.Add((New-C2Check 'C2Check:PublicProjection' Failed 'FT-11:C2Check:PublicProjection' @($contractPath,$script:Registry[5].path) @('C2Check:Conservation','AR-I04','AR-I05','AR-I06','AR-S06','AR-S07','AR-S08','AR-S09','AR-S10','AR-S11','AR-S12')))}
    else{$checks.Add((New-C2Check 'C2Check:PublicProjection' Accepted 'None' @($contractPath,$script:Registry[5].path) @('C2Check:Conservation','AR-I04','AR-I05','AR-I06','AR-S12')))}

    $failures.Sort([Comparison[object]]{param($a,$b)$an=[int]([regex]::Match([string]$a.attribution,'^FT-(\d+)').Groups[1].Value);$bn=[int]([regex]::Match([string]$b.attribution,'^FT-(\d+)').Groups[1].Value);if($an-ne$bn){return $an.CompareTo($bn)};return $script:Ordinal.Compare([string]$a.subjectId,[string]$b.subjectId)})
    $acceptedArtifacts=@($artifactStates|Where-Object readStatus -ceq Accepted).Count;$acceptedRaw=@($raw|Where-Object partition -ceq Accepted).Count;$rejectedRaw=@($raw|Where-Object partition -ceq InputFailure).Count;$excludedRaw=@($raw|Where-Object partition -ceq InputExclusion).Count;$acceptedChecks=@($checks|Where-Object status -ceq Accepted).Count;$failedChecks=@($checks|Where-Object status -ceq Failed).Count;$notEvaluatedChecks=@($checks|Where-Object status -ceq NotEvaluated).Count
    $fileConflictCount=@($conflicts|Where-Object subjectKind -ceq FileDiscoveryConflict).Count;$observationConflictCount=@($conflicts|Where-Object subjectKind -ceq ObservationConflict).Count;$configurationConflictCount=@($conflicts|Where-Object subjectKind -ceq ConfigurationConflict).Count;$canonicalConflictCount=@($conflicts|Where-Object subjectKind -ceq CanonicalConflict).Count
    $contractFailureCount=@($failures|Where-Object{$_.subjectKind-cnotin$rawKinds-and$_.subjectKind-cnotin$conflictKinds}).Count
    $accounting=[pscustomobject][ordered]@{inputSubjectCount=$artifactStates.Count+$raw.Count+$conflicts.Count+5;acceptedInputSubjectCount=$acceptedArtifacts+$acceptedRaw+$acceptedChecks;notEvaluatedInputSubjectCount=$notEvaluatedChecks;inputObservationCount=$raw.Count;acceptedInputObservationCount=$acceptedRaw;rejectedInputObservationCount=$rejectedRaw;inputFailureCount=$failures.Count;excludedInputSubjectCount=$exclusions.Count;excludedInputCount=$excludedRaw;contractFailureRecordCount=$contractFailureCount;fileDiscoveryConflictRecordCount=$fileConflictCount;observationConflictRecordCount=$observationConflictCount;configurationConflictRecordCount=$configurationConflictCount;canonicalConflictRecordCount=$canonicalConflictCount;issueCount=$failures.Count;gateStatus=if($failures.Count){'Failed'}else{'Passed'}}
    [pscustomobject][ordered]@{contractChecks=[object[]]$checks;inputFailures=[object[]]$failures;inputExclusions=[object[]]$exclusions;inputSuppressions=[object[]]$suppressions;failureAccounting=$accounting;contractChangeRequest=$InputFact.contractChangeRequest;discoveryInputFingerprint=if($failures.Count){$null}else{$InputFact.discoveryInputFingerprint}}
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
        'AR-I05'='schemaVersion,generatedAt,corpus,extraction,semantics,configurationDisposition,unity,disposition,familyStaticOutcome,familyParentStatus,memberStaticStatus,representativeAssessment,capabilitySuitabilityStatus,authoringPoolStatus,capabilityStatus,sourceKind'
        'AR-I06'='$schema,$id,title,type,required,additionalProperties,properties,$defs'
        'AR-I07'='schemaVersion,snapshotId,inputFingerprint,rows'
        'AR-I08'='schemaVersion,snapshotId,inputFingerprint,rows'
        'AR-I10'='schemaVersion,snapshotId,inputFingerprint,entries'
        'AR-I11'='schemaVersion,snapshotId,inputFingerprint,observationArtifactPath,observationArtifactSha256,approvals'
    }
    foreach($id in $top.Keys){if((@($Documents[$id].PSObject.Properties.Name)-join ',') -cne $top[$id]){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message="$id top-level shape"}}}
    foreach($id in @('AR-I04','AR-I06')){if(-not(Test-C2SchemaDocument $Documents[$id])){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId=$id;message="$id schema document semantics"}}}
    try{$ledgerJson=$Documents['AR-I02']|ConvertTo-Json -Depth 100 -Compress;$ledgerSchema=$Documents['AR-I04']|ConvertTo-Json -Depth 100 -Compress;if(-not($ledgerJson|Test-Json -Schema $ledgerSchema -ErrorAction Stop)){return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I02';message='ledger schema'}}}catch{return [pscustomobject]@{status='Failed';owner='FT-02';reason='InvalidSchema';subjectId='AR-I02';message="ledger schema: $($_.Exception.Message)"}}
    $expectedVocabulary=[ordered]@{corpus='Cataloged,Missing,StaleInput';extraction='NotAttempted,ExtractedReadable,CrossToolVerified,Opaque,Failed';semantics='Known,PartiallyKnown,Unknown';configurationDisposition='Parsed,DiscoveredOpaque,Encrypted,RequiresRuntimeType,LikelyServerDependent,NotConfiguration';unity='NotTested,StaticQualified,RepresentativeValidated,Rejected,UnityExecutionUnavailable';disposition='NeedsDiagnosis,UseOriginalAsset,RepairOnce,PrototypeReplacement,RetainForLater,DiagnosticOnly,Stop';familyStaticOutcome='StaticQualified,StaticRejected,NeedsDiagnosis';familyParentStatus='AssignedFamilyMember,RetainedForDiagnosis,ConfigurationOnly';memberStaticStatus='StaticPassed,StaticFailed,Unchecked';representativeAssessment='RepresentativeRequired,EvidenceAccepted,EvidenceMissing,EvidenceStale,UnityExecutionUnavailable,RepresentativeRejected';capabilitySuitabilityStatus='SuitabilityRequired,SuitabilityAccepted,SuitabilityMissing,SuitabilityStale,SuitabilityExecutionUnavailable,SuitabilityRejected';authoringPoolStatus='AcceptedOriginalPool,AcceptedReplacementSourcePool,Isolated';capabilityStatus='Satisfied,Unsatisfied,Blocked';sourceKind='PcInstall,PcPatchOrCache,AndroidApk,AndroidDataOrCache'}
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
    param([Parameter(Mandatory)][string]$RepositoryRoot,[AllowNull()][scriptblock]$GitTransport,[AllowNull()][scriptblock]$FixtureMutator,[AllowNull()][string]$PublicationGeneratedAt)
    $requiredHashes=@(
        '548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac',
        'acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462',
        'c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1',
        'b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c',
        '9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6',
        '8c9fdb6e50c620d1b8d8835cb6435c653b3398f5616340f5945ad643364af1ec'
    )
    $gitExecutable=if($null -eq $GitTransport){(Get-Command git.exe -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source}else{$null}
    if($null -eq $GitTransport -and -not [IO.Path]::IsPathFullyQualified($gitExecutable)){return New-C2FailedIntakeResult FT-13 HeavyOperationAttempted $null $null $null 0 0}
    $context=[ordered]@{facts=$null;handoff=$null;c1Ledger=$null;ledgerInputFingerprint=$null;generatedAt=$null;inputFingerprint=$null;rawFileDiscoverySubjects=@();rawConfigurationSubjects=@();sp12=$null;sp03=$null;sp05=$null;sp06=$null;sp07=$null;sp07PriorFailureCount=0;events=[Collections.Generic.List[object]]::new();extractedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Extracted'));importedBefore=[IO.Directory]::Exists([IO.Path]::Combine($RepositoryRoot,'Assets','StellaGaia','Imported'))}
    $registry=$script:Registry;$utf8=$script:Utf8;$fixtureValidator=${function:Test-C2FixtureContracts};$partitioner=${function:Invoke-C2FileDiscoveryPartitions};$objectPartitioner=${function:Invoke-C2ObjectObservationPartitions};$configurationPartitioner=${function:Invoke-C2ConfigurationPartitions};$canonicalPartitioner=${function:Invoke-C2CanonicalPartitions};$dispatchPartitioner=${function:Invoke-C2DispatchPartitions};$configurationObjectId=${function:Get-C2ConfigurationObjectId};$rawRowId=${function:Get-C2RawRowId};$fixtureMutation=$FixtureMutator
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
            $documents=[ordered]@{};foreach($id in $bytes.Keys){$documents[$id]=$utf8.GetString($bytes[$id])|ConvertFrom-Json -Depth 100 -DateKind String};$context.c1Ledger=$documents['AR-I02']
            if($null -ne $fixtureMutation){$null=$fixtureMutation.Invoke([pscustomobject]@{documents=$documents})}
            $contractResult=@($fixtureValidator.Invoke($documents,$hashes))[0]
            if($contractResult.status -ne 'Passed'){return $contractResult}
            $context.generatedAt=[string]$documents['AR-I03'].generatedAt;$context.inputFingerprint=[string]$documents['AR-I01'].inputFingerprint;$context.ledgerInputFingerprint=[string]$documents['AR-I03'].ledgerInputFingerprint
            $acceptedRows=for($i=0;$i -lt 4;$i++){[pscustomobject][ordered]@{rowIndex=$i;observation=$documents['AR-I07'].rows[$i]}}
            $partitionInput=[pscustomobject][ordered]@{snapshotId=$documents['AR-I01'].snapshotId;inputFingerprint=$documents['AR-I01'].inputFingerprint;discoveryInputFingerprint=$null;c1Files=@($documents['AR-I02'].files);objectObservationArtifact=[pscustomobject][ordered]@{artifactPath=$registry[6].path;artifactSha256=$hashes['AR-I07'];acceptedRows=@($acceptedRows)};fileDiscoveryArtifact=[pscustomobject][ordered]@{artifactPath=$registry[7].path;artifactSha256=$hashes['AR-I08'];documentReadStatus='Parsed';document=$documents['AR-I08']}}
            $context.sp12=@($partitioner.Invoke($partitionInput))[0]
            if($context.sp12.gateStatus -ne 'Passed'){$first=@($context.sp12.inputFailures)[0];return [pscustomobject]@{status='Failed';owner=($first.attribution.Split(':')[0]);reason=$first.reasonCode;subjectId=$first.subjectId;message='SP-01/SP-02 failed'}}
            $rawFileSubjects=[Collections.Generic.List[object]]::new();for($i=0;$i-lt@($documents['AR-I08'].rows).Count;$i++){$row=@($documents['AR-I08'].rows)[$i];$fallback=@($rawRowId.Invoke($registry[7].path,$hashes['AR-I08'],$i))[0];$failed=@($context.sp12.inputFailures|Where-Object subjectId -ceq $fallback).Count-gt0;$rawFileSubjects.Add([pscustomobject][ordered]@{subjectKind='FileDiscoveryObservation';subjectId=if($failed){$fallback}else{$row.fileDiscoveryObservationId};partition=if($failed){'InputFailure'}else{'Accepted'}})};$context.rawFileDiscoverySubjects=[object[]]$rawFileSubjects
            $sp03Input=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$documents['AR-I01'].snapshotId;inputFingerprint=$documents['AR-I01'].inputFingerprint;discoveryInputFingerprint=$null;sourceKinds=@($documents['AR-I02'].sources|ForEach-Object{[pscustomobject][ordered]@{sourceId=$_.sourceId;sourceKind=$_.sourceKind}});objectObservationArtifact=[pscustomobject][ordered]@{artifactPath=$registry[6].path;artifactSha256=$hashes['AR-I07'];documentReadStatus='Parsed';document=$documents['AR-I07']};exclusionApprovalArtifact=[pscustomobject][ordered]@{artifactPath=$registry[10].path;artifactSha256=$hashes['AR-I11'];documentReadStatus='Parsed';document=$documents['AR-I11']}}
            $context.sp03=@($objectPartitioner.Invoke($sp03Input))[0]
            $sp05Input=[pscustomobject]@{c1Files=@($documents['AR-I02'].files);mergedObjects=@($context.sp03.mergedObjects);fileConfigurationArtifact=[pscustomobject]@{artifactPath=$registry[8].path;artifactSha256=$null;documentReadStatus='Absent';document=$null}}
            $context.sp05=@($configurationPartitioner.Invoke($sp05Input))[0]
            $context.rawConfigurationSubjects=@()
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
    if($null-ne$context.sp07){
        $rawSubjects=[Collections.Generic.List[object]]::new()
        foreach($subject in @($context.sp03.observationSubjects)){$partition=if($subject.partition-ceq'AcceptedObservation'){'Accepted'}elseif($subject.partition-ceq'RejectedObservation'){'InputFailure'}else{'InputExclusion'};$rawSubjects.Add([pscustomobject][ordered]@{subjectKind='ObjectObservation';subjectId=$subject.subjectId;partition=$partition})};foreach($subject in @($context.rawFileDiscoverySubjects)){$rawSubjects.Add($subject)};foreach($subject in @($context.rawConfigurationSubjects)){$rawSubjects.Add($subject)}
        $conflictSubjects=[Collections.Generic.List[object]]::new();foreach($row in @($context.sp12.fileDiscoveryConflicts)){$conflictSubjects.Add([pscustomobject][ordered]@{subjectKind='FileDiscoveryConflict';subjectId=$row.fileDiscoveryConflictId})};foreach($row in @($context.sp03.observationConflicts)){$conflictSubjects.Add([pscustomobject][ordered]@{subjectKind='ObservationConflict';subjectId=$row.observationConflictId})};foreach($row in @($context.sp05.configurationConflicts)){$conflictSubjects.Add([pscustomobject][ordered]@{subjectKind='ConfigurationConflict';subjectId=$row.configurationConflictId})};foreach($row in @($context.sp06.canonicalConflicts)){$conflictSubjects.Add([pscustomobject][ordered]@{subjectKind='CanonicalConflict';subjectId=$row.canonicalConflictId})}
        $fileMembers=@($context.sp12.fileSubjects|ForEach-Object{New-C2StageMember "$($_.sourceId)`n$($_.relativePath)" $_.sizeBytes});$containerMembers=@($context.sp12.fileSubjects|Where-Object sp01Partition -ceq Container|ForEach-Object{New-C2StageMember "$($_.sourceId)`n$($_.relativePath)" $_.sizeBytes});$nonContainerMembers=@($context.sp12.fileSubjects|Where-Object sp01Partition -ceq NonContainer|ForEach-Object{New-C2StageMember "$($_.sourceId)`n$($_.relativePath)" $_.sizeBytes})
        $sp01=New-C2StageEquation Files $fileMembers @((New-C2StagePartition Container $containerMembers),(New-C2StagePartition NonContainer $nonContainerMembers));$fileParts=[Collections.Generic.List[object]]::new();$containerParts=[Collections.Generic.List[object]]::new();foreach($name in @('NotAttempted','Parsed','Opaque','Failed','Conflict')){$private=if($name-ceq'Conflict'){'FileDiscoveryConflict'}else{$name};$fileParts.Add((New-C2StagePartition $name @($context.sp12.fileSubjects|Where-Object sp02Partition -ceq $private|ForEach-Object{New-C2StageMember "$($_.sourceId)`n$($_.relativePath)" $_.sizeBytes})));$containerParts.Add((New-C2StagePartition $name @($context.sp12.fileSubjects|Where-Object{$_.sp01Partition-ceq'Container'-and$_.sp02Partition-ceq$private}|ForEach-Object{New-C2StageMember "$($_.sourceId)`n$($_.relativePath)" $_.sizeBytes})))};$sp02a=New-C2StageEquation Files $fileMembers @($fileParts);$sp02b=New-C2StageEquation Containers $containerMembers @($containerParts)
        $observationMembers=@($context.sp03.observationSubjects|ForEach-Object{New-C2StageMember $_.subjectId});$sp03a=New-C2StageEquation Observations $observationMembers @((New-C2StagePartition Accepted @($context.sp03.observationSubjects|Where-Object partition -ceq AcceptedObservation|ForEach-Object{New-C2StageMember $_.subjectId})),(New-C2StagePartition Rejected @($context.sp03.observationSubjects|Where-Object partition -ceq RejectedObservation|ForEach-Object{New-C2StageMember $_.subjectId})),(New-C2StagePartition Excluded @($context.sp03.observationSubjects|Where-Object partition -ceq ExcludedObservation|ForEach-Object{New-C2StageMember $_.subjectId})))
        $resolvedGroups=@($context.sp03.mergedObjects|ForEach-Object{New-C2StageMember $_.correlationId});$conflictGroups=@($context.sp03.observationConflicts|ForEach-Object{New-C2StageMember $_.correlationId});$sp03b=New-C2StageEquation CorrelationGroups @($resolvedGroups+$conflictGroups) @((New-C2StagePartition Resolved $resolvedGroups),(New-C2StagePartition Conflict $conflictGroups))
        $objectMembers=@($context.sp03.publicObjectCores|ForEach-Object{New-C2StageMember $_.assetObjectId});$sp04=New-C2StageEquation Objects $objectMembers @((New-C2StagePartition Classified @($context.sp03.publicObjectCores|Where-Object sp04Partition -ceq Classified|ForEach-Object{New-C2StageMember $_.assetObjectId})),(New-C2StagePartition Unclassified @($context.sp03.publicObjectCores|Where-Object sp04Partition -ceq Unclassified|ForEach-Object{New-C2StageMember $_.assetObjectId})))
        $candidateMembers=@($context.sp05.configurationCandidates|ForEach-Object{New-C2StageMember $_.configurationCandidateId});$configurationConflictMembers=@($context.sp05.configurationConflicts|ForEach-Object{New-C2StageMember $_.configurationCandidateId});$sp05a=New-C2StageEquation Targets @($candidateMembers+$configurationConflictMembers) @((New-C2StagePartition Candidates $candidateMembers),(New-C2StagePartition Conflicts $configurationConflictMembers));$dispositionParts=[Collections.Generic.List[object]]::new();foreach($name in @('Parsed','DiscoveredOpaque','Encrypted','RequiresRuntimeType','LikelyServerDependent','NotConfiguration')){$dispositionParts.Add((New-C2StagePartition $name @($context.sp05.configurationCandidates|Where-Object configurationDisposition -ceq $name|ForEach-Object{New-C2StageMember $_.configurationCandidateId})))};$sp05b=New-C2StageEquation Disposition $candidateMembers @($dispositionParts)
        $canonicalMembers=@($context.sp06.publicObjectsWithCanonicalId|ForEach-Object{New-C2StageMember $_.assetObjectId});$canonicalConflictMembers=@($context.sp06.canonicalConflicts|ForEach-Object memberObjectIds|ForEach-Object{New-C2StageMember $_});$sp06a=New-C2StageEquation Objects @($canonicalMembers+$canonicalConflictMembers) @((New-C2StagePartition Canonicalized $canonicalMembers),(New-C2StagePartition Conflicts $canonicalConflictMembers));$groupMembers=@($context.sp06.canonicalGroups|ForEach-Object{New-C2StageMember $_.canonicalAssetId});$sp06b=New-C2StageEquation Groups $groupMembers @((New-C2StagePartition ExactDuplicate @($context.sp06.canonicalGroups|Where-Object matchStatus -ceq ExactDuplicate|ForEach-Object{New-C2StageMember $_.canonicalAssetId})),(New-C2StagePartition CrossPlatformVariant @($context.sp06.canonicalGroups|Where-Object matchStatus -ceq ConfirmedVariant|ForEach-Object{New-C2StageMember $_.canonicalAssetId})),(New-C2StagePartition Unresolved @($context.sp06.canonicalGroups|Where-Object matchStatus -ceq Unresolved|ForEach-Object{New-C2StageMember $_.canonicalAssetId})))
        $dispatchMembers=@();if(-not$context.sp07.outputsSuppressed){$dispatchMembers=@($context.sp07.dispatchRows|ForEach-Object{New-C2StageMember $_.assetObjectId})};$sp07a=New-C2StageEquation Dispatch $dispatchMembers @((New-C2StagePartition Assigned @($dispatchMembers|Where-Object id -in @($context.sp07.dispatchRows|Where-Object dispatchStatus -ceq Assigned|ForEach-Object assetObjectId))),(New-C2StagePartition RetainedForDiagnosis @($dispatchMembers|Where-Object id -in @($context.sp07.dispatchRows|Where-Object dispatchStatus -ceq RetainedForDiagnosis|ForEach-Object assetObjectId))),(New-C2StagePartition ConfigurationOnly @($dispatchMembers|Where-Object id -in @($context.sp07.dispatchRows|Where-Object dispatchStatus -ceq ConfigurationOnly|ForEach-Object assetObjectId))));$laneParts=[Collections.Generic.List[object]]::new();foreach($lane in @('Audio','Environment','Actor','UI','Effects','Unassigned')){$laneParts.Add((New-C2StagePartition $lane @($dispatchMembers|Where-Object id -in @($context.sp07.dispatchRows|Where-Object familyLane -ceq $lane|ForEach-Object assetObjectId))))};$sp07b=New-C2StageEquation Lanes $dispatchMembers @($laneParts)
        $stageSets=@((New-C2Stage 'SP-01' @($sp01)),(New-C2Stage 'SP-02' @($sp02a,$sp02b)),(New-C2Stage 'SP-03a' @($sp03a)),(New-C2Stage 'SP-03b' @($sp03b)),(New-C2Stage 'SP-04' @($sp04)),(New-C2Stage 'SP-05' @($sp05a,$sp05b)),(New-C2Stage 'SP-06' @($sp06a,$sp06b)),(New-C2Stage 'SP-07' @($sp07a,$sp07b)))
        $preSuppressionFingerprint=Get-C2DiscoveryInputFingerprint -Entries @($result.O1.artifactStates|Where-Object readStatus -ceq Accepted|ForEach-Object{[pscustomobject][ordered]@{path=$_.path;sha256=$_.worktreeSha256}})
        $contractChange=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$context.generatedAt;requestId='C0ContractChange:C2StructuredCoverage:1.0.0';reason='Root gate summary schema 2.0.0 losslessly represents mandatory C2 structured coverage partitions.';nextAllowedAction='Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.';inputFingerprint=$context.inputFingerprint;discoveryInputFingerprint=$preSuppressionFingerprint;status='Resolved';missingProjectionFields=[string[]]$script:MissingProjectionFields;evidence=[string[]]@('Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json','docs/asset-migration/schemas/root-gate-summary.schema.json')}
        $directFailures=@($context.sp12.inputFailures)+@($context.sp03.inputFailures)+@($context.sp05.inputFailures)+@($context.sp06.inputFailures)+@(if($context.sp07.inputFailures.Count-gt$context.sp07PriorFailureCount){$context.sp07.inputFailures|Select-Object -Skip $context.sp07PriorFailureCount})
        $runtimeFacts=[pscustomobject][ordered]@{heavyProcessCount=$result.O2.heavyProcessCount;realAssetReadCount=$result.O2.realAssetReadCount;createdExtractedCount=$result.O2.createdExtractedCount;createdImportedCount=$result.O2.createdImportedCount;astViolationCount=0;startCommitOid=$result.O2.startCommitOid;endCommitOid=$result.O2.endCommitOid;headStable=$result.O2.headStable}
        $fileCoverageNames=@('catalogedFileCount','catalogedBytes','catalogedContainerCount','catalogedContainerBytes','nonContainerFileCount','nonContainerFileBytes','fileDiscoverySubjectCount','fileDiscoverySubjectBytes','notAttemptedFileCount','notAttemptedFileBytes','parsedFileCount','parsedFileBytes','opaqueFileCount','opaqueFileBytes','failedFileCount','failedFileBytes','fileDiscoveryConflictFileCount','fileDiscoveryConflictFileBytes');$containerCoverageNames=@('notAttemptedContainerCount','notAttemptedContainerBytes','parsedContainerCount','parsedContainerBytes','opaqueContainerCount','opaqueContainerBytes','failedContainerCount','failedContainerBytes','fileDiscoveryConflictContainerCount','fileDiscoveryConflictContainerBytes');$objectCoverageNames=@('objectObservationRowCount','acceptedObjectObservationRowCount','rejectedObjectObservationRowCount','excludedObjectObservationRowCount','correlationGroupCount','enumeratedObjectCount','observationConflictObjectCount','classifiedObjectCount','unclassifiedObjectCount','unresolvedDependencyCount')
        $publicCoverage=[pscustomobject][ordered]@{files=Select-C2CoverageFields $context.sp12.coverage $fileCoverageNames;containers=Select-C2CoverageFields $context.sp12.coverage $containerCoverageNames;objects=Select-C2CoverageFields $context.sp03.coverage $objectCoverageNames;configuration=$context.sp05.coverage;canonical=$context.sp06.coverage;dispatch=$context.sp07.coverage}
        $discoveryEntries=[Collections.Generic.List[object]]::new();foreach($state in @($result.O1.artifactStates|Where-Object readStatus -ceq Accepted)){$discoveryEntries.Add([pscustomobject][ordered]@{path=$state.path;sha256=$state.worktreeSha256})};$discoveryEntries.Sort([Comparison[object]]{param($a,$b)$script:Ordinal.Compare([string]$a.path,[string]$b.path)})
        $projectedFiles=[Collections.Generic.List[object]]::new();foreach($file in @($context.c1Ledger.files)){$resolved=@($context.sp12.resolvedFileResults|Where-Object{$_.sourceId-ceq$file.sourceId-and$_.relativePath-ceq$file.relativePath})[0];$parseStatus=if($null-ne$resolved){$resolved.parseStatus}else{$null};$status=[pscustomobject][ordered]@{corpus=$file.status.corpus;extraction=$parseStatus;semantics=$file.status.semantics;unity=$file.status.unity;disposition=$file.status.disposition};$projectedFiles.Add([pscustomobject][ordered]@{snapshotId=$file.snapshotId;sourceId=$file.sourceId;sourceKind=$file.sourceKind;relativePath=$file.relativePath;containerKind=$file.containerKind;sizeBytes=[long]$file.sizeBytes;sha256=$file.sha256;capturedAt=$file.capturedAt;parseStatus=$parseStatus;disposition=$file.disposition;evidence=@($file.evidence);status=$status})}
        $projectedObjects=[Collections.Generic.List[object]]::new();foreach($object in @($context.sp06.publicObjectsWithCanonicalId)){$projectedObjects.Add([pscustomobject][ordered]@{assetObjectId=$object.assetObjectId;sourceId=$object.sourceId;objectType=$object.objectType;objectName=$object.objectName;containerRelativePath=$object.containerRelativePath;classId=[long]$object.classId;serializedSizeBytes=[long]$object.serializedSizeBytes;dependencyObjectIds=@($object.dependencyObjectIds);toolObservations=@($object.toolObservations);platformVariant=$object.platformVariant;configurationDisposition=$object.configurationDisposition;evidence=@($object.evidence);status=$object.status})}
        $projectedObservationConflicts=[Collections.Generic.List[object]]::new();foreach($conflict in @($context.sp03.observationConflicts)){$projectedObservationConflicts.Add([pscustomobject][ordered]@{observationConflictId=$conflict.observationConflictId;correlationId=$conflict.correlationId;observationIds=@($conflict.observationIds);objectIds=@($conflict.derivedAssetObjectIds);conflictingFields=@($conflict.conflictingFields);failureClass=$conflict.failureClass;evidence=@($conflict.evidence)})}
        $projection=[pscustomobject][ordered]@{toolVersions=@($context.c1Ledger.toolVersions);sources=@($context.c1Ledger.sources);files=[object[]]$projectedFiles;objects=[object[]]$projectedObjects;configurationCandidates=@($context.sp05.configurationCandidates);configurationConflicts=@($context.sp05.configurationConflicts);canonicalGroups=@($context.sp06.canonicalGroups);canonicalConflicts=@($context.sp06.canonicalConflicts);dispatchRows=@($context.sp07.dispatchRows);resolvedFileResults=@($context.sp12.resolvedFileResults);mergedObjectCandidates=@($context.sp03.mergedObjects);canonicalProposalProvenance=@($context.sp03.canonicalProposalProvenance);dispatchInputFacts=@($context.sp07.dispatchInputFacts);fileDiscoveryConflicts=@($context.sp12.fileDiscoveryConflicts);observationConflicts=[object[]]$projectedObservationConflicts;inputFailures=$directFailures;inputExclusions=@($context.sp03.inputExclusions);inputSuppressions=@();discoveryInputs=[object[]]$discoveryEntries;coverage=$publicCoverage;decision=$result.O1.decision}
        $accounting=Invoke-C2InputAccounting ([pscustomobject][ordered]@{artifactStates=@($result.O1.artifactStates);rawObservationSubjects=[object[]]$rawSubjects;conflictSubjects=[object[]]$conflictSubjects;inputFailures=$directFailures;inputExclusions=@($context.sp03.inputExclusions);runtimeFacts=$runtimeFacts;contractChangeRequest=$contractChange;stageConservationSets=$stageSets;publicProjection=$projection;discoveryInputFingerprint=$preSuppressionFingerprint})
        if($accounting.inputFailures.Count-and$context.sp07.dispatchRows.Count){$context.sp07=Invoke-C2DispatchPartitions ([pscustomobject]@{publicObjectsWithCanonicalId=@($context.sp06.publicObjectsWithCanonicalId);dispatchInputFacts=@($context.sp07.dispatchInputFacts);inputFailures=@($accounting.inputFailures);contractChecks=@($accounting.contractChecks)});$result.O1.dispatchRows=[object[]]$context.sp07.dispatchRows;foreach($p in $context.sp07.coverage.PSObject.Properties){$result.O2.($p.Name)=[int]$p.Value}}
        $result.O1.contractChecks=[object[]]$accounting.contractChecks;$result.O1.inputFailures=[object[]]$accounting.inputFailures;$result.O1.inputExclusions=[object[]]$accounting.inputExclusions;$result.O1.inputSuppressions=[object[]]$accounting.inputSuppressions;$result.O1.discoveryInputFingerprint=$accounting.discoveryInputFingerprint;$result.O1|Add-Member -NotePropertyName contractChangeRequest -NotePropertyValue $accounting.contractChangeRequest
        $fa=$accounting.failureAccounting;foreach($name in @('inputSubjectCount','acceptedInputSubjectCount','inputFailureCount','excludedInputSubjectCount','notEvaluatedInputSubjectCount','issueCount')){$result.O2.($name)=[int]$fa.$name};foreach($name in @('inputObservationCount','acceptedInputObservationCount','rejectedInputObservationCount','excludedInputCount','contractFailureRecordCount','fileDiscoveryConflictRecordCount','observationConflictRecordCount','configurationConflictRecordCount','canonicalConflictRecordCount')){$result.O2|Add-Member -NotePropertyName $name -NotePropertyValue ([int]$fa.$name)}
        $result.O2.acceptedCheckCount=@($accounting.contractChecks|Where-Object status -ceq Accepted).Count;$result.O2.failedCheckCount=@($accounting.contractChecks|Where-Object status -ceq Failed).Count;$result.O2.notEvaluatedCheckCount=@($accounting.contractChecks|Where-Object status -ceq NotEvaluated).Count;$result.O2.status=$fa.gateStatus;$result.O2.discoveryInputFingerprint=$accounting.discoveryInputFingerprint
        if($accounting.inputFailures.Count){$result.O1.decision.failureAttribution=(@($accounting.inputFailures.attribution)-join';');$result.O1.decision.nextAllowedAction=if($accounting.inputFailures[0].attribution-like'FT-05:*'){'Correct fixture row/artifact'}else{'Correct the first owning failure and rerun'}}else{$result.O1.decision.failureAttribution='None; C2 registry-derived gates passed.';$result.O1.decision.nextAllowedAction='Provide current C2 outputs and C6-O04 to the separately authorized G5 aggregator.'}
        if($null-ne$PublicationGeneratedAt){
            $publicationContract=[pscustomobject][ordered]@{schemaVersion=$accounting.contractChangeRequest.schemaVersion;generatedAt=$PublicationGeneratedAt;requestId=$accounting.contractChangeRequest.requestId;reason=$accounting.contractChangeRequest.reason;nextAllowedAction=$accounting.contractChangeRequest.nextAllowedAction;inputFingerprint=$accounting.contractChangeRequest.inputFingerprint;discoveryInputFingerprint=$accounting.discoveryInputFingerprint;status=$accounting.contractChangeRequest.status;missingProjectionFields=@($accounting.contractChangeRequest.missingProjectionFields);evidence=@($accounting.contractChangeRequest.evidence)}
            $publicationInput=[pscustomobject][ordered]@{schemaVersion='1.0.0';generatedAt=$PublicationGeneratedAt;snapshotId=$context.handoff.snapshotId;inputFingerprint=$context.inputFingerprint;ledgerInputFingerprint=$context.ledgerInputFingerprint;discoveryInputFingerprint=$accounting.discoveryInputFingerprint;gateStatus=$fa.gateStatus;toolVersions=@($projection.toolVersions);sources=@($projection.sources);files=@($projection.files);objects=@($projection.objects);configurationCandidates=@($projection.configurationCandidates);configurationConflicts=@($projection.configurationConflicts);canonicalGroups=@($projection.canonicalGroups);canonicalConflicts=@($projection.canonicalConflicts);sourceLedgerPath=$context.handoff.ledgerPath;dispatchRows=@($projection.dispatchRows);resolvedFileResults=@($projection.resolvedFileResults);mergedObjectCandidates=@($projection.mergedObjectCandidates);canonicalProposalProvenance=@($projection.canonicalProposalProvenance);dispatchInputFacts=@($projection.dispatchInputFacts);fileDiscoveryConflicts=@($projection.fileDiscoveryConflicts);observationConflicts=@($projection.observationConflicts);inputFailures=@($accounting.inputFailures);inputExclusions=@($accounting.inputExclusions);inputSuppressions=@($accounting.inputSuppressions);discoveryInputs=@($projection.discoveryInputs);coverage=$projection.coverage;failureAccounting=$fa;decision=$result.O1.decision;contractChangeRequest=$publicationContract}
            $result|Add-Member -NotePropertyName PublicationInput -NotePropertyValue $publicationInput
        }
    }
    return $result
}

function Invoke-C2DiscoveryIntakeGate {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot)
    $repository=[IO.Path]::GetFullPath($RepositoryRoot);$generatedAt=[DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ',[Globalization.CultureInfo]::InvariantCulture)
    $result=Invoke-C2DiscoveryIntakeGateInternal -RepositoryRoot $repository -GitTransport $null -FixtureMutator $null -PublicationGeneratedAt $generatedAt
    if($null-eq$result.PSObject.Properties['PublicationInput']){return $result}
    $serialized=Invoke-C2OutputSerialization $result.PublicationInput;$result.PSObject.Properties.Remove('PublicationInput');$operational=Get-C2PublicationChildPath $repository 'Temp/C2DiscoveryPublication'
    $publication=Invoke-C2PublicationTransactionCore -SandboxRoot $repository -OperationalRoot $operational -ConsumerRoot $repository -SerializedResult $serialized
    $consumerValidation=Test-C2PublishedDiscoveryGeneration -RepositoryRoot $repository
    $result|Add-Member -NotePropertyName Publication -NotePropertyValue $publication;$result|Add-Member -NotePropertyName ConsumerValidation -NotePropertyValue $consumerValidation;$result
}

function Test-C2InjectedGateVector {
    [CmdletBinding()]param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][ValidateSet('Call1StartFailure','Call3InvalidOutput','LedgerNestedInvalid','VocabularyInvalid','AuthoringPoolStatusInvalid','CapabilityStatusInvalid','RootSchemaInvalid','RootSchemaRequiredInvalid','RootSchemaPropertyInvalid','RootSchemaDefInvalid','RootSchemaMinimumInvalid','ManifestShapeInvalid','ObservationHI03Invalid','ApprovalHI15Invalid')][string]$Vector)
    $transport=$null;$mutation=$null;$encoding=[Text.UTF8Encoding]::new($false);$oid='1111111111111111111111111111111111111111'
    if($Vector -eq 'Call1StartFailure'){$transport={param($number,$arguments,$raw)[pscustomobject]@{callNumber=$number;started=$false;prelaunchRejected=$false;exitCode=$null;stdoutBytes=[byte[]]@();stderr='start failure'}}.GetNewClosure()}
    elseif($Vector -eq 'Call3InvalidOutput'){$transport={param($number,$arguments,$raw)$text=if($number -in @(1,7)){"$oid`n"}elseif($number -eq 4){''}else{'blob'};$exit=if($number -eq 3){1}else{0};[pscustomobject]@{callNumber=$number;started=$true;prelaunchRejected=$false;exitCode=$exit;stdoutBytes=$encoding.GetBytes($text);stderr='';arguments=$arguments;environmentValid=$true;useShellExecute=$false;redirectStandardOutput=$true;redirectStandardError=$true;rawBlobCapture=$raw;stdoutByteCount=$encoding.GetByteCount($text)}}.GetNewClosure()}
    else{
        $mutation=switch($Vector){
            'LedgerNestedInvalid' {{param($bundle)$bundle.documents['AR-I02'].files=$null}}
            'VocabularyInvalid' {{param($bundle)$bundle.documents['AR-I05'].corpus=@('DefinitelyUnsupported')}}
            'AuthoringPoolStatusInvalid' {{param($bundle)$bundle.documents['AR-I05'].authoringPoolStatus=@('DefinitelyUnsupported')}}
            'CapabilityStatusInvalid' {{param($bundle)$bundle.documents['AR-I05'].capabilityStatus=@('DefinitelyUnsupported')}}
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

Export-ModuleMember -Function Get-C2DiscoveryInputFingerprint,Invoke-C2PureDiscoveryIntake,Invoke-C2GitFreshnessAdapter,Test-C2GitAdapterLifecycle,Invoke-C2DiscoveryIntakeGate,Test-C2PublishedDiscoveryGeneration,Invoke-C2TypedLaneFactProjection
