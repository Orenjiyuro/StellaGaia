Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:C4Utf8 = [Text.UTF8Encoding]::new($false)
$script:C4Ordinal = [StringComparer]::Ordinal
$script:C4DirectInputPaths = [ordered]@{
    'C3-O01'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json'
    'C3-O02'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json'
    'C3-O03'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json'
    'C3-O04-Summary'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-summary.json'
    'C3-O04-Report'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-report.md'
    'LC-I01'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json'
    'LC-I02'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json'
    'LC-I03'='Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json'
    'LC-I06'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json'
    'LC-I07'='docs/asset-migration/schemas/c3-c6-lane-policy-registry.json'
    'LC-I08'='docs/asset-migration/schemas/status-vocabulary.json'
    'LC-I13'='docs/asset-migration/schemas/c2-lane-fact-package.schema.json'
    'LC-I14'='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-static-observation-package.json'
}

function Get-C4Sha256([string]$Text) {
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($script:C4Utf8.GetBytes($Text))).ToLowerInvariant()
}

function Get-C4OrdinalValues([object[]]$Values,[switch]$Unique) {
    $list=[Collections.Generic.List[string]]::new();$seen=[Collections.Generic.HashSet[string]]::new($script:C4Ordinal)
    foreach($value in $Values){$text=[string]$value;if(-not$Unique-or$seen.Add($text)){$list.Add($text)}}
    $list.Sort($script:C4Ordinal);[string[]]$list.ToArray()
}

function Get-C4OrdinalRows([object[]]$Rows,[string[]]$Properties) {
    $list=[Collections.Generic.List[object]]::new();foreach($row in $Rows){$list.Add($row)}
    $list.Sort([Comparison[object]]{param($a,$b)foreach($property in $Properties){$comparison=$script:C4Ordinal.Compare([string]$a.$property,[string]$b.$property);if($comparison){return $comparison}};0})
    [object[]]$list.ToArray()
}

function Test-C4JsonObjectBytesBinding([object]$Value,[string]$Bytes) {
    try{$parsed=$Bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{return $false}
    ($Value|ConvertTo-Json -Depth 100 -Compress)-ceq($parsed|ConvertTo-Json -Depth 100 -Compress)
}

function Test-C4JsonProjectionBytesBinding([object]$Value,[string]$Bytes,[string]$Property) {
    try{$parsed=$Bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{return $false}
    if(-not[string]::IsNullOrEmpty($Property)){
        if($null-eq$parsed.PSObject.Properties[$Property]){return $false}
        $parsed=$parsed.$Property
    }
    ($Value|ConvertTo-Json -Depth 100 -Compress)-ceq($parsed|ConvertTo-Json -Depth 100 -Compress)
}

function New-C4ArtifactMap([object[]]$Rows,[string]$KeyProperty) {
    $map=[Collections.Generic.Dictionary[string,object]]::new($script:C4Ordinal)
    foreach($row in $Rows){
        if($null-eq$row-or$null-eq$row.PSObject.Properties[$KeyProperty]){return $null}
        $key=[string]$row.$KeyProperty
        if([string]::IsNullOrWhiteSpace($key)-or$map.ContainsKey($key)){return $null}
        $map.Add($key,$row)
    }
    $map
}

function ConvertTo-C4ScalarLine([string]$Name, [string]$Value) {
    if ($null -eq $Value -or $Value.IndexOfAny([char[]]@([char]0,"`r","`n")) -ge 0) { throw "Invalid framed scalar: $Name" }
    "${Name}:$($script:C4Utf8.GetByteCount($Value)):${Value}`n"
}

function ConvertTo-C4NullableLine([string]$Name, [AllowNull()][object]$Value) {
    if ($null -eq $Value) { return "${Name}.null:1:1`n" }
    "${Name}.null:1:0`n$(ConvertTo-C4ScalarLine $Name ([string]$Value))"
}

function Add-C4SetFrame([string]$Name, [string[]]$Values) {
    $ordered = @(Get-C4OrdinalValues $Values -Unique)
    $countText = [string]$ordered.Count
    $text = "$Name.count:$($script:C4Utf8.GetByteCount($countText)):$countText`n"
    for ($index=0; $index -lt $ordered.Count; $index++) { $text += ConvertTo-C4ScalarLine "$Name[$index]" $ordered[$index] }
    $text
}

function Get-C4StaticCheckResultId([object]$Row) {
    $text = 'C4StaticCheckV1' + "`n"
    foreach ($name in @('assetObjectId','familyId','checkId','outcome','reasonCode')) { $text += ConvertTo-C4ScalarLine $name ([string]$Row.$name) }
    $text += ConvertTo-C4NullableLine observedFingerprint $Row.observedFingerprint
    $text += Add-C4SetFrame failureClasses @($Row.failureClasses)
    $text += Add-C4SetFrame availableInputKinds @($Row.availableInputKinds)
    $text += Add-C4SetFrame evidence @($Row.evidence)
    "static-check-sha256:$(Get-C4Sha256 $text)"
}

function Get-C4MemberStaticResultId([object]$Row) {
    $text = 'C4MemberStaticV1' + "`n"
    foreach ($name in @('assetObjectId','familyId','staticStatus')) { $text += ConvertTo-C4ScalarLine $name ([string]$Row.$name) }
    $text += Add-C4SetFrame actionableFailureClasses @($Row.actionableFailureClasses)
    $text += Add-C4SetFrame availableInputKinds @($Row.availableInputKinds)
    $text += Add-C4SetFrame checkResultIds @($Row.checkResultIds)
    "member-static-sha256:$(Get-C4Sha256 $text)"
}

function ConvertTo-C4CanonicalJson([object]$Value) {
    (($Value | ConvertTo-Json -Depth 100) -replace "`r`n","`n") + "`n"
}

function Get-C4StageInputFingerprint([object[]]$Entries) {
    if ($Entries.Count -ne $script:C4DirectInputPaths.Count) { throw 'C4 direct input set is invalid.' }
    $ordered = @(Get-C4OrdinalRows $Entries @('path'))
    $seen = [Collections.Generic.HashSet[string]]::new($script:C4Ordinal)
    $countText = [string]$ordered.Count
    $text = "LifecycleStageInputV1`nentries.count:$($script:C4Utf8.GetByteCount($countText)):$countText`n"
    for ($index=0; $index -lt $ordered.Count; $index++) {
        $entry = $ordered[$index]
        if ((@($entry.PSObject.Properties.Name)-join',') -cne 'artifactId,path,sha256' -or -not $script:C4DirectInputPaths.Contains([string]$entry.artifactId) -or $script:C4DirectInputPaths[[string]$entry.artifactId] -cne [string]$entry.path -or -not $seen.Add([string]$entry.path) -or $entry.sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'C4 direct input contract is invalid.' }
        $nested = "C2ArtifactEntryV1`n" + (ConvertTo-C4ScalarLine artifactId ([string]$entry.artifactId)) + (ConvertTo-C4ScalarLine path ([string]$entry.path)) + (ConvertTo-C4ScalarLine sha256 ([string]$entry.sha256))
        $text += "entries[$index]:$($script:C4Utf8.GetByteCount($nested)):$nested`n"
    }
    Get-C4Sha256 $text
}

function Get-C4InputAuthorityState(
    [object[]]$DirectInputs,
    [object[]]$ExecutionArtifacts,
    [object]$FamilyRegistry,
    [object]$FamilyMemberLedger,
    [object]$CrossLaneReferencePackage,
    [object[]]$TypedFactRows,
    [object]$LanePolicyRegistry,
    [string]$LanePolicyBytes,
    [string[]]$MemberStaticStatuses,
    [object[]]$StaticObservationRows,
    [string]$StageSnapshotId
) {
    $issues=[Collections.Generic.List[string]]::new()
    $directById=New-C4ArtifactMap $DirectInputs artifactId
    $directByPath=New-C4ArtifactMap $DirectInputs path
    $executionById=New-C4ArtifactMap $ExecutionArtifacts artifactId
    if($null-eq$directById-or$null-eq$directByPath-or$DirectInputs.Count-ne$script:C4DirectInputPaths.Count){$issues.Add('C4 direct input set is invalid.')}
    else {
        for($index=1;$index-lt$DirectInputs.Count;$index++){
            if($script:C4Ordinal.Compare([string]$DirectInputs[$index-1].path,[string]$DirectInputs[$index].path)-ge0){$issues.Add('C4 direct inputs are not Ordinal sorted.');break}
        }
        foreach($expected in $script:C4DirectInputPaths.GetEnumerator()){
            if(-not$directById.ContainsKey([string]$expected.Key)-or
                (@($directById[[string]$expected.Key].PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or
                [string]$directById[[string]$expected.Key].path-cne[string]$expected.Value-or
                [string]$directById[[string]$expected.Key].sha256-cnotmatch'^[0-9a-f]{64}$'){$issues.Add('C4 direct input set is invalid.');break}
        }
    }
    if($null-eq$executionById-or$ExecutionArtifacts.Count-ne$script:C4DirectInputPaths.Count){$issues.Add('C4 execution artifact byte set is invalid.')}
    else {
        foreach($expected in $script:C4DirectInputPaths.GetEnumerator()){
            if(-not$executionById.ContainsKey([string]$expected.Key)-or
                (@($executionById[[string]$expected.Key].PSObject.Properties.Name)-join',')-cne'artifactId,bytes'-or
                $null-eq$executionById[[string]$expected.Key].bytes){$issues.Add('C4 execution artifact byte set is invalid.');break}
        }
    }
    if(-not$issues.Count){
        foreach($expected in $script:C4DirectInputPaths.GetEnumerator()){
            $id=[string]$expected.Key;$bytes=[string]$executionById[$id].bytes
            if($id-cne'C3-O04-Report'){try{$null=$bytes|ConvertFrom-Json -Depth 100 -DateKind String}catch{$issues.Add("C4 exact bytes are not valid JSON for $id.");break}}
            if([string]$directById[$id].sha256-cne(Get-C4Sha256 $bytes)){$issues.Add("C4 exact-byte direct input hash mismatch for $id.");break}
        }
    }
    if(-not$issues.Count){
        if(-not(Test-C4JsonObjectBytesBinding $FamilyRegistry ([string]$executionById['C3-O01'].bytes))){$issues.Add('C3-O01 execution object does not match accepted bytes.')}
        elseif(-not(Test-C4JsonObjectBytesBinding $FamilyMemberLedger ([string]$executionById['C3-O02'].bytes))){$issues.Add('C3-O02 execution object does not match accepted bytes.')}
        elseif(-not(Test-C4JsonObjectBytesBinding $CrossLaneReferencePackage ([string]$executionById['C3-O03'].bytes))){$issues.Add('C3-O03 execution object does not match accepted bytes.')}
        elseif(-not(Test-C4JsonProjectionBytesBinding $TypedFactRows ([string]$executionById['LC-I06'].bytes) rows)){$issues.Add('LC-I06 execution object does not match accepted bytes.')}
        elseif([string]$executionById['LC-I07'].bytes-cne$LanePolicyBytes-or-not(Test-C4JsonObjectBytesBinding $LanePolicyRegistry ([string]$executionById['LC-I07'].bytes))){$issues.Add('LC-I07 execution object does not match accepted bytes.')}
        elseif(-not(Test-C4JsonProjectionBytesBinding $MemberStaticStatuses ([string]$executionById['LC-I08'].bytes) memberStaticStatus)){$issues.Add('LC-I08 execution vocabulary does not match accepted bytes.')}
        elseif(-not(Test-C4JsonProjectionBytesBinding $StaticObservationRows ([string]$executionById['LC-I14'].bytes) rows)){$issues.Add('LC-I14 execution object does not match accepted bytes.')}
    }
    if(-not$issues.Count){
        $c3Summary=([string]$executionById['C3-O04-Summary'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $lc1=([string]$executionById['LC-I01'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $lc2=([string]$executionById['LC-I02'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $lc3=([string]$executionById['LC-I03'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $lc6=([string]$executionById['LC-I06'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        $lc14=([string]$executionById['LC-I14'].bytes)|ConvertFrom-Json -Depth 100 -DateKind String
        foreach($c3Input in @($FamilyMemberLedger,$CrossLaneReferencePackage)){
            if($c3Input.schemaVersion-cne$FamilyRegistry.schemaVersion-or$c3Input.generatedAt-cne$FamilyRegistry.generatedAt-or$c3Input.snapshotId-cne$FamilyRegistry.snapshotId-or$c3Input.inputFingerprint-cne$FamilyRegistry.inputFingerprint-or$c3Input.policySetFingerprint-cne$FamilyRegistry.policySetFingerprint){$issues.Add('C4 C3 generation identity is invalid.');break}
        }
        if(-not$issues.Count-and($StageSnapshotId-cne[string]$FamilyRegistry.snapshotId-or$c3Summary.failureAccounting.gateStatus-cne'Passed'-or$c3Summary.schemaVersion-cne$FamilyRegistry.schemaVersion-or$c3Summary.generatedAt-cne$FamilyRegistry.generatedAt-or$c3Summary.snapshotId-cne$FamilyRegistry.snapshotId-or$c3Summary.inputFingerprint-cne$FamilyRegistry.inputFingerprint-or$c3Summary.policySetFingerprint-cne$FamilyRegistry.policySetFingerprint)){$issues.Add('C4 C3 summary generation identity is invalid.')}
        if(-not$issues.Count){
            $outputById=New-C4ArtifactMap @($c3Summary.directOutputs) artifactId
            foreach($id in @('C3-O01','C3-O02','C3-O03','C3-O04-Report')){
                if($null-eq$outputById-or$outputById.Count-ne4-or-not$outputById.ContainsKey($id)-or
                    (@($outputById[$id].PSObject.Properties.Name)-join',')-cne'artifactId,path,sha256'-or
                    [string]$outputById[$id].path-cne[string]$script:C4DirectInputPaths[$id]-or
                    [string]$outputById[$id].sha256-cne(Get-C4Sha256 ([string]$executionById[$id].bytes))){$issues.Add('C4 C3 summary does not bind the accepted C3 output bytes.');break}
            }
        }
        $snapshotMismatches=@(@($lc1,$lc2,$lc3,$lc6,$lc14)|Where-Object{$_.snapshotId-cne$StageSnapshotId})
        if(-not$issues.Count-and$snapshotMismatches.Count){$issues.Add('C4 direct input snapshot identity is invalid.')}
        if(-not$issues.Count-and((@($lc14.PSObject.Properties.Name)-join',')-cne'schemaVersion,generatedAt,snapshotId,rows'-or$lc14.schemaVersion-cne'1.0.0')){$issues.Add('LC-I14 package shape is invalid.')}
        if(-not$issues.Count){
            $rows=@($lc14.rows)
            for($index=1;$index-lt$rows.Count;$index++){
                $comparison=$script:C4Ordinal.Compare([string]$rows[$index-1].assetObjectId,[string]$rows[$index].assetObjectId)
                if($comparison-gt0-or($comparison-eq0-and$script:C4Ordinal.Compare([string]$rows[$index-1].checkId,[string]$rows[$index].checkId)-ge0)){$issues.Add('LC-I14 rows are not unique Ordinal order.');break}
            }
        }
    }
    $fingerprint=if($issues.Count){$null}else{Get-C4StageInputFingerprint $DirectInputs}
    [pscustomobject][ordered]@{valid=$issues.Count-eq0;issues=$issues.ToArray();inputFingerprint=$fingerprint}
}

function Add-C4Issue([Collections.Generic.List[string]]$Issues, [string]$Issue) {
    if (-not $Issues.Contains($Issue)) { $Issues.Add($Issue) }
}

function Test-C4ExactSet([object[]]$Actual, [string[]]$Expected) {
    if ($Actual.Count -ne $Expected.Count) { return $false }
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ([string]$Actual[$index] -cne $Expected[$index]) { return $false }
    }
    return $true
}

function Invoke-C4StaticQualificationKernel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object[]]$TypedFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][string[]]$MemberStaticStatuses,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$StaticObservationRows
    )

    $issues = [Collections.Generic.List[string]]::new()
    if(-not(Test-C4JsonObjectBytesBinding $LanePolicyRegistry $LanePolicyBytes)){Add-C4Issue $issues 'LC-I07 execution object does not match accepted bytes.'}
    $expectedStatuses = @('StaticPassed', 'StaticFailed', 'Unchecked')
    if (-not (Test-C4ExactSet $MemberStaticStatuses $expectedStatuses)) {
        Add-C4Issue $issues 'LC-I08 memberStaticStatus vocabulary is invalid.'
    }

    $familyById = @{}
    foreach ($family in @($FamilyRegistry.families)) {
        $familyId = [string]$family.familyId
        if ($familyById.ContainsKey($familyId)) {
            Add-C4Issue $issues 'Duplicate C3 familyId.'
        }
        else { $familyById[$familyId] = $family }
    }

    $policyByLane = @{}
    foreach ($lanePolicy in @($LanePolicyRegistry.policies)) {
        $lane = [string]$lanePolicy.lane
        if ($policyByLane.ContainsKey($lane)) {
            Add-C4Issue $issues 'Duplicate LC-I07 lane policy.'
        }
        else { $policyByLane[$lane] = $lanePolicy }
    }

    $assignedMembers = @(Get-C4OrdinalRows @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember') @('assetObjectId'))
    $memberIds = @{}
    foreach ($member in $assignedMembers) {
        $assetObjectId = [string]$member.assetObjectId
        if ($memberIds.ContainsKey($assetObjectId)) {
            Add-C4Issue $issues 'Duplicate C3 assigned member.'
            continue
        }
        $memberIds[$assetObjectId] = $member
        $familyId = [string]$member.familyId
        if (-not $familyById.ContainsKey($familyId)) {
            Add-C4Issue $issues 'C3 assigned member family does not resolve.'
            continue
        }
        $family = $familyById[$familyId]
        if ([string]$family.lane -cne [string]$member.lane -or [string]$family.familyKindId -cne [string]$member.familyKindId) {
            Add-C4Issue $issues 'C3 member and family identity mismatch.'
        }
        if (-not $policyByLane.ContainsKey([string]$member.lane)) {
            Add-C4Issue $issues 'C3 assigned member lane policy does not resolve.'
        }
    }

    foreach ($family in @($FamilyRegistry.families)) {
        $actual = @($assignedMembers | Where-Object familyId -CEQ ([string]$family.familyId))
        $expectedIds = @(Get-C4OrdinalValues @($family.memberObjectIds))
        $actualIds = @(Get-C4OrdinalValues @($actual.assetObjectId))
        if ([int]$family.memberCount -ne $actual.Count -or -not (Test-C4ExactSet $actualIds $expectedIds)) {
            Add-C4Issue $issues 'C3 family membership input is inconsistent.'
        }
    }

    $factsByKey = @{}
    foreach ($fact in $TypedFactRows) {
        $key = "$([string]$fact.assetObjectId)|$([string]$fact.factKind)"
        if ($factsByKey.ContainsKey($key)) { Add-C4Issue $issues 'Duplicate typed fact row.' }
        else { $factsByKey[$key] = $fact }
    }

    $observationByKey = @{}
    foreach ($observation in $StaticObservationRows) {
        if ((@($observation.PSObject.Properties.Name) -join ',') -cne 'assetObjectId,familyId,checkId,outcome,reasonCode,observedFingerprint,failureClasses,evidenceKinds,evidence') {
            Add-C4Issue $issues 'Invalid static observation row shape.'
            continue
        }
        $key = "$([string]$observation.assetObjectId)|$([string]$observation.checkId)"
        if ($observationByKey.ContainsKey($key)) { Add-C4Issue $issues 'Duplicate static observation row.' }
        else { $observationByKey[$key] = $observation }
    }

    $requiredByKey = @{}
    $requiredRows = [Collections.Generic.List[object]]::new()
    foreach ($member in $assignedMembers) {
        if (-not $policyByLane.ContainsKey([string]$member.lane)) { continue }
        $lanePolicy = $policyByLane[[string]$member.lane]
        $familyKindId = [string]$member.familyKindId
        $factDefinitionByKind = @{}
        foreach ($definition in @($lanePolicy.factDefinitions)) { $factDefinitionByKind[[string]$definition.factKind] = $definition }
        foreach ($check in @($lanePolicy.staticCheckDefinitions)) {
            if (@($check.applicableFamilyKinds) -cnotcontains $familyKindId) { continue }
            $inapplicable = $false
            $missingInput = $false
            $knownFactKinds = [Collections.Generic.List[string]]::new()
            foreach ($factKindValue in @($check.requiredFactKinds)) {
                $factKind = [string]$factKindValue
                $factKey = "$([string]$member.assetObjectId)|$factKind"
                if (-not $factsByKey.ContainsKey($factKey)) { $missingInput = $true; continue }
                $fact = $factsByKey[$factKey]
                if ([string]$fact.factStatus -ceq 'Unknown') { $missingInput = $true; continue }
                if ([string]$fact.factStatus -ceq 'NotApplicable') {
                    if (-not $factDefinitionByKind.ContainsKey($factKind) -or -not [bool]$factDefinitionByKind[$factKind].allowNotApplicable) {
                        Add-C4Issue $issues 'Forbidden NotApplicable static fact.'
                    }
                    else { $inapplicable = $true }
                }
                elseif ([string]$fact.factStatus -cne 'Known') {
                    Add-C4Issue $issues 'Invalid static fact status.'
                }
                else {
                    $knownFactKinds.Add($factKind)
                }
            }
            if ($inapplicable) { continue }
            $key = "$([string]$member.assetObjectId)|$([string]$check.checkId)"
            $requiredByKey[$key] = $true
            $requiredRows.Add([pscustomobject][ordered]@{ member = $member; check = $check; missingInput = $missingInput; knownFactKinds = @(Get-C4OrdinalValues $knownFactKinds.ToArray() -Unique); key = $key })
        }
    }

    foreach ($key in $observationByKey.Keys) {
        if (-not $requiredByKey.ContainsKey($key)) { Add-C4Issue $issues 'Unexpected static observation row.' }
    }

    $allowedOutcomes = @('Passed', 'Failed', 'Unchecked')
    $allowedReasons = @('None', 'MissingInputFact', 'PrerequisiteFailed', 'ToolUnavailable', 'UnsupportedFormat', 'ReadFailure', 'DependencyMissing', 'ConflictDetected', 'PolicyViolation')
    $allowedUncheckedReasons = @('MissingInputFact', 'PrerequisiteFailed', 'ToolUnavailable', 'UnsupportedFormat')
    $allowedFailureClasses = @('ReadFailure','MissingDependency','ShaderMismatch','MaterialMismatch','ImportSettingMismatch','ControllerMissing','DecodeFailure','SemanticUnknown','PrefabDependencyMissing','FontAtlasMissing','EffectBehaviorMissing','CoreDataMissing')
    $allowedEvidenceKinds = @('FileReadability','ObjectReadability','SerializedMetadata','DependencyGraph','PrefabYaml','MaterialShaderGraph','TextureMetadata','AudioMetadata','DecoderProbe','UnityImport','VisibleRender','AnimationPlayback','AudioPlayback','HumanListening','LoopBehavior','MaterialFidelity','UiConstruction','EffectBehavior','CapabilitySuitability')
    $checkResults = [Collections.Generic.List[object]]::new()
    foreach ($required in $requiredRows) {
        if (-not $observationByKey.ContainsKey([string]$required.key)) {
            Add-C4Issue $issues 'Missing required static observation row.'
            continue
        }
        $observation = $observationByKey[[string]$required.key]
        $member = $required.member
        $check = $required.check
        $outcome = [string]$observation.outcome
        $reasonCode = [string]$observation.reasonCode
        if ([string]$observation.familyId -cne [string]$member.familyId) { Add-C4Issue $issues 'Static observation family does not match C3 membership.' }
        if ($allowedOutcomes -cnotcontains $outcome) { Add-C4Issue $issues 'Invalid static observation outcome.' }
        if ($allowedReasons -cnotcontains $reasonCode) { Add-C4Issue $issues 'Invalid static observation reasonCode.' }
        if ($outcome -ceq 'Passed' -and $reasonCode -cne 'None') { Add-C4Issue $issues 'Passed static observation must use reasonCode None.' }
        if (($outcome -ceq 'Failed' -or $outcome -ceq 'Unchecked') -and $reasonCode -ceq 'None') { Add-C4Issue $issues 'Non-passing static observation cannot use reasonCode None.' }
        if ($outcome -ceq 'Unchecked' -and $allowedUncheckedReasons -cnotcontains $reasonCode) { Add-C4Issue $issues 'Unchecked static observation uses an invalid reasonCode.' }
        if ([bool]$required.missingInput -and ($outcome -cne 'Unchecked' -or $reasonCode -cne 'MissingInputFact')) { Add-C4Issue $issues 'Missing static fact must produce Unchecked with MissingInputFact.' }
        $fingerprint = $observation.observedFingerprint
        if ($null -ne $fingerprint -and [string]$fingerprint -cnotmatch '^[0-9a-f]{64}$') { Add-C4Issue $issues 'Invalid observedFingerprint.' }
        if ($outcome -ceq 'Passed' -and $null -eq $fingerprint) { Add-C4Issue $issues 'Passed static observation requires observedFingerprint.' }
        $rawEvidenceKinds = @($observation.evidenceKinds)
        $evidenceKinds = @(Get-C4OrdinalValues $rawEvidenceKinds -Unique)
        if (-not (Test-C4ExactSet $rawEvidenceKinds $evidenceKinds)) { Add-C4Issue $issues 'Static observation evidenceKinds must be an Ordinal set.' }
        elseif (@($evidenceKinds | Where-Object { $allowedEvidenceKinds -cnotcontains $_ }).Count) { Add-C4Issue $issues 'Static observation evidenceKinds are invalid.' }
        $rawFailureClasses = [object[]]@($observation.failureClasses)
        $failureClasses = [string[]]@(Get-C4OrdinalValues $rawFailureClasses -Unique)
        if ($null -eq $observation.failureClasses -or -not (Test-C4ExactSet $rawFailureClasses $failureClasses) -or @($failureClasses | Where-Object { $allowedFailureClasses -cnotcontains $_ }).Count) { Add-C4Issue $issues 'Static observation failureClasses are invalid.' }
        if ($outcome -ceq 'Failed' -and $failureClasses.Count -eq 0) { Add-C4Issue $issues 'Failed static observation requires failureClasses.' }
        if ($outcome -cne 'Failed' -and $failureClasses.Count -ne 0) { Add-C4Issue $issues 'Non-failed static observation forbids failureClasses.' }
        if ($outcome -ceq 'Passed') {
            $missingEvidenceKinds = @($check.requiredEvidenceKinds | Where-Object { $_ -cnotin $evidenceKinds })
            if ($missingEvidenceKinds.Count) { Add-C4Issue $issues 'Passed static observation is missing required evidence kinds.' }
        }
        $rawEvidence = @($observation.evidence)
        $orderedEvidence = @(Get-C4OrdinalValues $rawEvidence -Unique)
        if ($rawEvidence.Count -eq 0) { Add-C4Issue $issues 'Static observation evidence is empty.' }
        elseif (-not (Test-C4ExactSet $rawEvidence $orderedEvidence)) { Add-C4Issue $issues 'Static observation evidence must be an Ordinal set.' }
        $availableInputKinds = @(Get-C4OrdinalValues @($required.knownFactKinds + $evidenceKinds) -Unique)
        $identityRow = [pscustomobject][ordered]@{assetObjectId=[string]$member.assetObjectId;familyId=[string]$member.familyId;checkId=[string]$check.checkId;outcome=$outcome;reasonCode=$reasonCode;observedFingerprint=$fingerprint;failureClasses=$failureClasses;availableInputKinds=$availableInputKinds;evidence=@(Get-C4OrdinalValues @($observation.evidence))}
        $checkResults.Add([pscustomobject][ordered]@{
            staticCheckResultId = Get-C4StaticCheckResultId $identityRow
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            lane = [string]$member.lane
            checkId = [string]$check.checkId
            outcome = $outcome
            reasonCode = $reasonCode
            observedFingerprint = $fingerprint
            failureClasses = $failureClasses
            availableInputKinds = $availableInputKinds
            evidence = @(Get-C4OrdinalValues @($observation.evidence))
        })
    }

    if ($issues.Count) {
        return [pscustomobject][ordered]@{
            status = 'Failed'; issues = @(Get-C4OrdinalValues @($issues))
            assignedMemberCount = $assignedMembers.Count; assignedMemberBytes = [long]0
            staticPassedCount = 0; staticPassedBytes = [long]0; staticFailedCount = 0; staticFailedBytes = [long]0; uncheckedCount = 0; uncheckedBytes = [long]0
            requiredCheckCount = $requiredRows.Count; passedCheckCount = 0; failedCheckCount = 0; uncheckedCheckCount = 0
            memberResults = @(); familyResults = @(); checkResults = @()
        }
    }

    $orderedChecks = @(Get-C4OrdinalRows @($checkResults) @('assetObjectId','checkId'))
    $memberResults = [Collections.Generic.List[object]]::new()
    foreach ($member in $assignedMembers) {
        $checks = @($orderedChecks | Where-Object assetObjectId -CEQ ([string]$member.assetObjectId))
        $passed = @($checks | Where-Object outcome -CEQ 'Passed').Count
        $failed = @($checks | Where-Object outcome -CEQ 'Failed').Count
        $unchecked = @($checks | Where-Object outcome -CEQ 'Unchecked').Count
        $staticStatus = if ($failed) { 'StaticFailed' } elseif ($unchecked) { 'Unchecked' } else { 'StaticPassed' }
        $actionableFailureClasses = @(Get-C4OrdinalValues @($checks | Where-Object outcome -CEQ 'Failed' | ForEach-Object failureClasses | ForEach-Object { $_ }) -Unique)
        $availableInputKinds = @(Get-C4OrdinalValues @($checks | ForEach-Object availableInputKinds | ForEach-Object { $_ }) -Unique)
        $identity = [pscustomobject][ordered]@{assetObjectId=[string]$member.assetObjectId;familyId=[string]$member.familyId;staticStatus=$staticStatus;actionableFailureClasses=$actionableFailureClasses;availableInputKinds=$availableInputKinds;checkResultIds=@($checks.staticCheckResultId)}
        $memberResults.Add([pscustomobject][ordered]@{
            memberStaticResultId = Get-C4MemberStaticResultId $identity
            assetObjectId = [string]$member.assetObjectId
            familyId = [string]$member.familyId
            lane = [string]$member.lane
            serializedSizeBytes = [long]$member.serializedSizeBytes
            staticStatus = $staticStatus
            requiredCheckCount = $checks.Count
            passedCheckCount = $passed
            failedCheckCount = $failed
            uncheckedCheckCount = $unchecked
            actionableFailureClasses = $actionableFailureClasses
            availableInputKinds = $availableInputKinds
            staticCheckResultIds = @($checks.staticCheckResultId)
        })
    }

    $familyResults = [Collections.Generic.List[object]]::new()
    foreach ($family in @(Get-C4OrdinalRows @($FamilyRegistry.families) @('familyId'))) {
        $members = @($memberResults | Where-Object familyId -CEQ ([string]$family.familyId))
        $familyChecks = @($orderedChecks | Where-Object familyId -CEQ ([string]$family.familyId))
        $familyResults.Add([pscustomobject][ordered]@{
            familyId = [string]$family.familyId
            lane = [string]$family.lane
            memberCount = $members.Count
            memberBytes = [long](($members.serializedSizeBytes | Measure-Object -Sum).Sum)
            staticPassedCount = @($members | Where-Object staticStatus -CEQ 'StaticPassed').Count
            staticPassedBytes = [long](($members | Where-Object staticStatus -CEQ 'StaticPassed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            staticFailedCount = @($members | Where-Object staticStatus -CEQ 'StaticFailed').Count
            staticFailedBytes = [long](($members | Where-Object staticStatus -CEQ 'StaticFailed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            uncheckedCount = @($members | Where-Object staticStatus -CEQ 'Unchecked').Count
            uncheckedBytes = [long](($members | Where-Object staticStatus -CEQ 'Unchecked' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
            actionableFailureClasses = @(Get-C4OrdinalValues @($members | ForEach-Object actionableFailureClasses | ForEach-Object { $_ }) -Unique)
            availableInputKinds = @(Get-C4OrdinalValues @($members | ForEach-Object availableInputKinds | ForEach-Object { $_ }) -Unique)
            requiredCheckCount = $familyChecks.Count
            passedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Passed').Count
            failedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Failed').Count
            uncheckedCheckCount = @($familyChecks | Where-Object outcome -CEQ 'Unchecked').Count
        })
    }

    [long]$assignedBytes = 0
    foreach ($memberResult in $memberResults) { $assignedBytes += [long]$memberResult.serializedSizeBytes }
    [pscustomobject][ordered]@{
        status = 'Passed'; issues = @()
        assignedMemberCount = $memberResults.Count; assignedMemberBytes = $assignedBytes
        staticPassedCount = @($memberResults | Where-Object staticStatus -CEQ 'StaticPassed').Count
        staticPassedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'StaticPassed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        staticFailedCount = @($memberResults | Where-Object staticStatus -CEQ 'StaticFailed').Count
        staticFailedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'StaticFailed' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        uncheckedCount = @($memberResults | Where-Object staticStatus -CEQ 'Unchecked').Count
        uncheckedBytes = [long](($memberResults | Where-Object staticStatus -CEQ 'Unchecked' | ForEach-Object serializedSizeBytes | Measure-Object -Sum).Sum)
        requiredCheckCount = $orderedChecks.Count
        passedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Passed').Count
        failedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Failed').Count
        uncheckedCheckCount = @($orderedChecks | Where-Object outcome -CEQ 'Unchecked').Count
        memberResults = @($memberResults)
        familyResults = @($familyResults)
        checkResults = $orderedChecks
    }
}

function Get-C4AccountingId([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence) {
    $text = "LifecycleAccountingV1`n"
    foreach($pair in @(@('owningArray',$OwningArray),@('stageId','C4'),@('subjectKind',$SubjectKind),@('subjectId',$SubjectId),@('reasonCode',$ReasonCode),@('attribution',$Attribution))){$text += ConvertTo-C4ScalarLine $pair[0] $pair[1]}
    $text += Add-C4SetFrame evidence $Evidence
    "lifecycle-accounting-sha256:$(Get-C4Sha256 $text)"
}

function New-C4AccountingRow([string]$OwningArray,[string]$SubjectKind,[string]$SubjectId,[string]$ReasonCode,[string]$Attribution,[string[]]$Evidence) {
    $values = @(Get-C4OrdinalValues $Evidence -Unique)
    [pscustomobject][ordered]@{recordId=Get-C4AccountingId $OwningArray $SubjectKind $SubjectId $ReasonCode $Attribution $values;stageId='C4';subjectKind=$SubjectKind;subjectId=$SubjectId;reasonCode=$ReasonCode;attribution=$Attribution;evidence=$values}
}

function New-C4Report([object]$Stage,[string]$InputFingerprint,[string]$PolicySetFingerprint,[object]$Accounting,[object]$Decision) {
    "# C4 Lifecycle Gate Report`n"+
    "schemaVersion: 1.0.0`n"+
    "generatedAt: $($Stage.generatedAt)`n"+
    "stageId: C4`n"+
    "snapshotId: $($Stage.snapshotId)`n"+
    "inputFingerprint: $InputFingerprint`n"+
    "policySetFingerprint: $PolicySetFingerprint`n"+
    "gateStatus: $($Accounting.gateStatus)`n"+
    "inputSubjectCount: $($Accounting.inputSubjectCount)`n"+
    "inputFailureCount: $($Accounting.inputFailureCount)`n"+
    "notEvaluatedInputSubjectCount: $($Accounting.notEvaluatedInputSubjectCount)`n"+
    "outputCandidateCount: $($Accounting.outputCandidateCount)`n"+
    "projectedOutputCount: $($Accounting.projectedOutputCount)`n"+
    "outputFailureCount: $($Accounting.outputFailureCount)`n"+
    "issueCount: $($Accounting.issueCount)`n"+
    "failureAttribution: $($Decision.failureAttribution)`n"+
    "nextAllowedAction: $($Decision.nextAllowedAction)`n"
}

function Invoke-C4StaticQualificationGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$FamilyRegistry,
        [Parameter(Mandatory)][object]$FamilyMemberLedger,
        [Parameter(Mandatory)][object]$CrossLaneReferencePackage,
        [Parameter(Mandatory)][object[]]$TypedFactRows,
        [Parameter(Mandatory)][object]$LanePolicyRegistry,
        [Parameter(Mandatory)][string]$LanePolicyBytes,
        [Parameter(Mandatory)][string[]]$MemberStaticStatuses,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$StaticObservationRows,
        [Parameter(Mandatory)][object[]]$ExecutionArtifacts,
        [Parameter(Mandatory)][object]$Stage
    )
    $directInputs = @($Stage.directInputs)
    $authority = Get-C4InputAuthorityState $directInputs $ExecutionArtifacts $FamilyRegistry $FamilyMemberLedger $CrossLaneReferencePackage $TypedFactRows $LanePolicyRegistry $LanePolicyBytes $MemberStaticStatuses $StaticObservationRows ([string]$Stage.snapshotId)
    $inputFingerprint = $authority.inputFingerprint
    $policySetFingerprint = Get-C4Sha256 $LanePolicyBytes
    $prefix = [ordered]@{schemaVersion='1.0.0';generatedAt=[string]$Stage.generatedAt;snapshotId=[string]$Stage.snapshotId;inputFingerprint=$inputFingerprint;policySetFingerprint=$policySetFingerprint}
    $paths = [ordered]@{memberStaticQualification='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json';familyStaticSummary='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json';report='Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c4-report.md'}
    $assignedMembers = @($FamilyMemberLedger.rows | Where-Object parentStatus -CEQ 'AssignedFamilyMember')
    $kernel = if($authority.valid){
        Invoke-C4StaticQualificationKernel $FamilyRegistry $FamilyMemberLedger $TypedFactRows $LanePolicyRegistry $LanePolicyBytes $MemberStaticStatuses $StaticObservationRows
    } else {
        [pscustomobject][ordered]@{
            status='Failed';issues=@($authority.issues)
            assignedMemberCount=$assignedMembers.Count;assignedMemberBytes=[long]0
            staticPassedCount=0;staticPassedBytes=[long]0;staticFailedCount=0;staticFailedBytes=[long]0;uncheckedCount=0;uncheckedBytes=[long]0
            requiredCheckCount=0;passedCheckCount=0;failedCheckCount=0;uncheckedCheckCount=0
            memberResults=@();familyResults=@();checkResults=@()
        }
    }
    [long]$assignedInputBytes=0;foreach($assignedMember in $assignedMembers){$assignedInputBytes+=[long]$assignedMember.serializedSizeBytes}
    $coverage = [ordered]@{
        familyCount=@($FamilyRegistry.families).Count;memberCount=$assignedMembers.Count;memberBytes=$assignedInputBytes
        staticPassedCount=$kernel.staticPassedCount;staticPassedBytes=$kernel.staticPassedBytes;staticFailedCount=$kernel.staticFailedCount;staticFailedBytes=$kernel.staticFailedBytes;uncheckedCount=$kernel.uncheckedCount;uncheckedBytes=$kernel.uncheckedBytes
        requiredCheckCount=$kernel.requiredCheckCount;passedCheckCount=$kernel.passedCheckCount;failedCheckCount=$kernel.failedCheckCount;uncheckedCheckCount=$kernel.uncheckedCheckCount
    }

    if ($kernel.status -cne 'Passed') {
        $authorityFailure=-not$authority.valid
        $subjectId=if($authorityFailure){'C4:DirectInputs'}else{'C4:StaticConservation'}
        $reasonCode=if($authorityFailure){'PrerequisiteInvalid'}else{'StaticContractInvalid'}
        $failureCode=if($authorityFailure){'LF-01'}else{'LF-09'}
        $subjectKind=if($authorityFailure){'FreshnessCheck'}else{'ConservationCheck'}
        $attribution="${failureCode}:$subjectId"
        $evidence=if($authorityFailure){@($script:C4DirectInputPaths.Values)}else{@($paths.memberStaticQualification)}
        $failure=New-C4AccountingRow inputFailures $subjectKind $subjectId $reasonCode $attribution $evidence
        $outputFailures=@(
            New-C4AccountingRow outputFailures OutputArtifact 'C4-O01' SuppressedByGate "${failureCode}:C4-O01" @($paths.memberStaticQualification)
            New-C4AccountingRow outputFailures OutputArtifact 'C4-O02' SuppressedByGate "${failureCode}:C4-O02" @($paths.familyStaticSummary)
        )
        $nonDirectSubjectCount=$coverage.familyCount+$coverage.memberCount+$(if($authorityFailure){$StaticObservationRows.Count}else{$coverage.requiredCheckCount})+1
        $inputSubjectCount=$directInputs.Count+$nonDirectSubjectCount
        $acceptedInputSubjectCount=if($authorityFailure){0}else{$directInputs.Count+$coverage.familyCount+$coverage.memberCount+[Math]::Max(0,$coverage.requiredCheckCount-1)}
        $notEvaluatedInputSubjectCount=if($authorityFailure){$nonDirectSubjectCount}else{1}
        $accounting=[pscustomobject][ordered]@{inputSubjectCount=$inputSubjectCount;acceptedInputSubjectCount=$acceptedInputSubjectCount;inputFailureCount=1;notEvaluatedInputSubjectCount=$notEvaluatedInputSubjectCount;outputCandidateCount=3;projectedOutputCount=1;outputFailureCount=2;issueCount=1;gateStatus='Failed';inputFailures=@($failure);inputSuppressions=@();outputFailures=$outputFailures}
        $nextAllowedAction=if($authorityFailure){'Restore the exact, complete, same-generation C4 prerequisite set; no C5/C6.'}else{'Correct C4 producer; no C5/C6.'}
        $decision=[pscustomobject][ordered]@{failureAttribution=$attribution;nextAllowedAction=$nextAllowedAction}
        $report=New-C4Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
        $directOutputs=@([pscustomobject][ordered]@{artifactId='C4-O03-Report';path=$paths.report;sha256=Get-C4Sha256 $report})
        $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C4';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=[pscustomobject]$coverage;failureAccounting=$accounting;decision=$decision}
        return [pscustomobject][ordered]@{gateStatus='Failed';memberStaticQualification=$null;familyStaticSummary=$null;summary=$summary;report=$report;texts=[pscustomobject][ordered]@{memberStaticQualification=$null;familyStaticSummary=$null;summary=ConvertTo-C4CanonicalJson $summary}}
    }

    $memberRows=[Collections.Generic.List[object]]::new()
    foreach($member in @(Get-C4OrdinalRows @($kernel.memberResults) @('assetObjectId'))){
        $checks=@(Get-C4OrdinalRows @($kernel.checkResults | Where-Object assetObjectId -CEQ $member.assetObjectId) @('checkId'))
        $projectedChecks=@($checks|ForEach-Object{[pscustomobject][ordered]@{checkResultId=$_.staticCheckResultId;checkId=$_.checkId;outcome=$_.outcome;reasonCode=$_.reasonCode;observedFingerprint=$_.observedFingerprint;failureClasses=@($_.failureClasses);availableInputKinds=@($_.availableInputKinds);evidence=@($_.evidence)}})
        $uncheckedReasons=@(Get-C4OrdinalValues @($checks|Where-Object outcome -CEQ Unchecked|ForEach-Object reasonCode) -Unique)
        $failedCheck=$checks|Where-Object outcome -CEQ Failed|Select-Object -First 1
        $uncheckedCheck=$checks|Where-Object outcome -CEQ Unchecked|Select-Object -First 1
        $failureAttribution=if($member.staticStatus-ceq'StaticFailed'){"LF-08:$($failedCheck.checkId)"}elseif($member.staticStatus-ceq'Unchecked'){"LF-07:$($uncheckedCheck.checkId)"}else{'None; all required static checks passed.'}
        $nextAction=if($member.staticStatus-ceq'StaticFailed'){'Apply C6 decision rules later.'}elseif($member.staticStatus-ceq'Unchecked'){'Resolve named reason; never project Passed.'}else{'Retain as a StaticPassed C5 candidate.'}
        $memberRows.Add([pscustomobject][ordered]@{staticResultId=$member.memberStaticResultId;assetObjectId=$member.assetObjectId;familyId=$member.familyId;lane=$member.lane;requiredCheckCount=$member.requiredCheckCount;passedCheckCount=$member.passedCheckCount;failedCheckCount=$member.failedCheckCount;uncheckedCheckCount=$member.uncheckedCheckCount;staticStatus=$member.staticStatus;uncheckedReasonCodes=$uncheckedReasons;actionableFailureClasses=@($member.actionableFailureClasses);availableInputKinds=@($member.availableInputKinds);failureAttribution=$failureAttribution;nextAllowedAction=$nextAction;checkResults=$projectedChecks;evidence=@(Get-C4OrdinalValues @($checks|ForEach-Object evidence|ForEach-Object{$_}) -Unique)})
    }

    $familyRows=[Collections.Generic.List[object]]::new()
    foreach($family in @(Get-C4OrdinalRows @($kernel.familyResults) @('familyId'))){
        $members=@($memberRows|Where-Object familyId -CEQ $family.familyId)
        $staticOutcome=if($family.staticFailedCount){'StaticRejected'}elseif($family.uncheckedCount){'NeedsDiagnosis'}else{'StaticQualified'}
        $sourceMember=if($staticOutcome-ceq'StaticRejected'){$members|Where-Object staticStatus -CEQ StaticFailed|Select-Object -First 1}elseif($staticOutcome-ceq'NeedsDiagnosis'){$members|Where-Object staticStatus -CEQ Unchecked|Select-Object -First 1}else{$null}
        $failureAttribution=if($null-ne$sourceMember){$sourceMember.failureAttribution}else{'None; every family member is StaticPassed.'}
        $nextAction=if($staticOutcome-ceq'StaticRejected'){'Apply C6 decision rules later.'}elseif($staticOutcome-ceq'NeedsDiagnosis'){'Resolve unchecked member reasons before original-asset reuse.'}else{'Provide family static qualification to C5.'}
        $familyRows.Add([pscustomobject][ordered]@{familyId=$family.familyId;lane=$family.lane;memberCount=$family.memberCount;memberBytes=$family.memberBytes;staticPassedCount=$family.staticPassedCount;staticPassedBytes=$family.staticPassedBytes;staticFailedCount=$family.staticFailedCount;staticFailedBytes=$family.staticFailedBytes;uncheckedCount=$family.uncheckedCount;uncheckedBytes=$family.uncheckedBytes;staticOutcome=$staticOutcome;actionableFailureClasses=@($family.actionableFailureClasses);availableInputKinds=@($family.availableInputKinds);failureAttribution=$failureAttribution;nextAllowedAction=$nextAction;memberStaticResultIds=@(Get-C4OrdinalValues @($members.staticResultId));evidence=@(Get-C4OrdinalValues @($members|ForEach-Object evidence|ForEach-Object{$_}) -Unique)})
    }

    $memberStaticQualification=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;memberResults=$memberRows.ToArray()}
    $familyStaticSummary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;families=$familyRows.ToArray()}
    $texts=[ordered]@{memberStaticQualification=ConvertTo-C4CanonicalJson $memberStaticQualification;familyStaticSummary=ConvertTo-C4CanonicalJson $familyStaticSummary}
    $inputSubjectCount=$directInputs.Count+$coverage.familyCount+$coverage.memberCount+$coverage.requiredCheckCount+1
    $accounting=[pscustomobject][ordered]@{inputSubjectCount=$inputSubjectCount;acceptedInputSubjectCount=$inputSubjectCount;inputFailureCount=0;notEvaluatedInputSubjectCount=0;outputCandidateCount=3;projectedOutputCount=3;outputFailureCount=0;issueCount=0;gateStatus='Passed';inputFailures=@();inputSuppressions=@();outputFailures=@()}
    $decision=[pscustomobject][ordered]@{failureAttribution='None; C4 lifecycle contract passed.';nextAllowedAction='Provide the current static generation to C5.'}
    $report=New-C4Report $Stage $inputFingerprint $policySetFingerprint $accounting $decision
    $directOutputs=@(Get-C4OrdinalRows @(
        [pscustomobject][ordered]@{artifactId='C4-O01';path=$paths.memberStaticQualification;sha256=Get-C4Sha256 $texts.memberStaticQualification}
        [pscustomobject][ordered]@{artifactId='C4-O02';path=$paths.familyStaticSummary;sha256=Get-C4Sha256 $texts.familyStaticSummary}
        [pscustomobject][ordered]@{artifactId='C4-O03-Report';path=$paths.report;sha256=Get-C4Sha256 $report}
    ) @('path'))
    $summary=[pscustomobject][ordered]@{schemaVersion=$prefix.schemaVersion;generatedAt=$prefix.generatedAt;stageId='C4';snapshotId=$prefix.snapshotId;inputFingerprint=$prefix.inputFingerprint;policySetFingerprint=$prefix.policySetFingerprint;toolVersions=@($Stage.toolVersions);directInputs=$directInputs;directOutputs=$directOutputs;coverage=[pscustomobject]$coverage;failureAccounting=$accounting;decision=$decision}
    $texts.summary=ConvertTo-C4CanonicalJson $summary
    [pscustomobject][ordered]@{gateStatus='Passed';memberStaticQualification=$memberStaticQualification;familyStaticSummary=$familyStaticSummary;summary=$summary;report=$report;texts=[pscustomobject]$texts}
}

Export-ModuleMember -Function Invoke-C4StaticQualificationKernel,Invoke-C4StaticQualificationGate
