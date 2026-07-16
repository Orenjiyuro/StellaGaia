[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$module = Import-Module (Join-Path $PSScriptRoot 'C3FamilyMembershipGate.psm1') -Force -PassThru
$policy = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/c3-c6-lane-policy-registry.json') | ConvertFrom-Json -Depth 100 -DateKind String
$vocabulary = Get-Content -Raw -LiteralPath (Join-Path $repositoryRoot 'docs/asset-migration/schemas/status-vocabulary.json') | ConvertFrom-Json -Depth 100 -DateKind String

function Clone-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100 -DateKind String }
function New-ObjectId([char]$Value) { "sha256:$([string]$Value * 64)" }
function New-Fact([string]$ObjectId,[string]$Lane,[string]$Kind,[string]$Value,[string[]]$IdValues=@()) {
    $seed = [Text.Encoding]::UTF8.GetBytes("$ObjectId|$Lane|$Kind")
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($seed)).ToLowerInvariant()
    [pscustomobject][ordered]@{
        factId = "lane-fact-sha256:$hash"
        assetObjectId = $ObjectId
        lane = $Lane
        factKind = $Kind
        factStatus = 'Known'
        valueKind = if ($IdValues.Count) { 'IdSet' } else { 'String' }
        stringValue = if ($IdValues.Count) { $null } else { $Value }
        integerValue = $null
        booleanValue = $null
        idValues = [string[]]$IdValues
        evidence = @('Tools/AssetImport/Fixtures/FamilyQualificationGate/c3-walking-skeleton')
    }
}

$lanes = @('Audio','Environment','Actor','UI','Effects')
$objects = [ordered]@{}
$dispatchRows = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $lanes.Count; $index++) {
    $lane = $lanes[$index]
    $id = New-ObjectId ([char](97 + $index))
    $objects[$lane] = $id
    $dispatchRows.Add([pscustomobject][ordered]@{
        assetObjectId = $id
        canonicalAssetId = "canonical-sha256:$([string]([char](102 + $index)) * 64)"
        sourceId = 'pc-install-primary'
        familyLane = $lane
        memberSelectorInputs = @()
        configurationCandidateId = $null
        dispatchStatus = 'Assigned'
        evidence = @('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')
    })
}
$retainedId = "sha256:$('e' * 63)f"
$configurationId = New-ObjectId 'f'
$dispatchRows.Add([pscustomobject][ordered]@{assetObjectId=$retainedId;canonicalAssetId="canonical-sha256:$('e' * 63)f";sourceId='pc-install-primary';familyLane='Unassigned';memberSelectorInputs=@();configurationCandidateId=$null;dispatchStatus='RetainedForDiagnosis';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')})
$dispatchRows.Add([pscustomobject][ordered]@{assetObjectId=$configurationId;canonicalAssetId="canonical-sha256:$('f' * 64)";sourceId='pc-install-primary';familyLane='Unassigned';memberSelectorInputs=@();configurationCandidateId="config-sha256:$('9' * 64)";dispatchStatus='ConfigurationOnly';evidence=@('Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json')})

$facts = [Collections.Generic.List[object]]::new()
foreach ($lanePolicy in @($policy.policies)) {
    $objectId = [string]$objects[[string]$lanePolicy.lane]
    foreach ($dimension in @($lanePolicy.familyKinds[0].keyDimensionIds)) {
        $facts.Add((New-Fact $objectId $lanePolicy.lane $dimension "$($lanePolicy.lane)-$dimension"))
    }
}
$facts.Add((New-Fact $objects.Actor Actor DependencyObjectIds $null @($objects.Environment)))

function Run-Kernel($Rows,$Facts) {
    Invoke-C3FamilyMembershipKernel -DispatchRows $Rows -TypedFactRows $Facts -LanePolicyRegistry $policy -FamilyParentStatuses @($vocabulary.familyParentStatus)
}

$result = Run-Kernel @($dispatchRows) @($facts)
if ($result.status -cne 'Passed') { throw "C3-0 positive result failed: $($result.issues -join '; ')" }
if ($result.dispatchEligibleObjectCount -ne 7 -or $result.assignedFamilyMemberCount -ne 5 -or $result.retainedForDiagnosisObjectCount -ne 1 -or $result.configurationOnlyObjectCount -ne 1) { throw 'SP-30 partition conservation failed.' }
if ($result.memberRows.Count -ne 7 -or @($result.memberRows.assetObjectId | Sort-Object -Unique).Count -ne 7) { throw 'C3-0 direct-parent identity conservation failed.' }
if (@($result.memberRows | Where-Object parentStatus -ceq AssignedFamilyMember).Count -ne 5 -or @($result.memberRows | Where-Object parentStatus -ceq RetainedForDiagnosis).Count -ne 1 -or @($result.memberRows | Where-Object parentStatus -ceq ConfigurationOnly).Count -ne 1) { throw 'C3-0 parent status partition failed.' }
if ($result.families.Count -ne 5 -or ($result.families.memberCount | Measure-Object -Sum).Sum -ne 5) { throw 'C3-0 family member conservation failed.' }
if ($result.crossLaneReferences.Count -ne 1 -or $result.crossLaneReferences[0].fromAssetObjectId -cne $objects.Actor -or $result.crossLaneReferences[0].toAssetObjectId -cne $objects.Environment) { throw 'SP-31 cross-lane reference projection failed.' }
if (@($result.memberRows | Where-Object assetObjectId -cin @($objects.Actor,$objects.Environment) | Where-Object parentStatus -cne AssignedFamilyMember).Count) { throw 'Cross-lane reference changed direct membership.' }

$unknownFacts = @(Clone-Value $facts)
$unknown = @($unknownFacts | Where-Object { $_.assetObjectId -ceq $objects.Actor -and $_.factKind -ceq 'SkeletonId' })[0]
$unknown.factStatus = 'Unknown'; $unknown.valueKind = 'String'; $unknown.stringValue = $null
$unknownResult = Run-Kernel @($dispatchRows) $unknownFacts
if ($unknownResult.status -cne 'Passed' -or $unknownResult.assignedFamilyMemberCount -ne 4 -or $unknownResult.retainedForDiagnosisObjectCount -ne 2 -or @($unknownResult.memberRows | Where-Object assetObjectId -ceq $objects.Actor)[0].parentStatus -cne 'RetainedForDiagnosis') { throw 'LF-04 Unknown family key behavior failed.' }

$duplicateRows = @(Clone-Value $dispatchRows) + @((Clone-Value $dispatchRows[0]))
$duplicateResult = Run-Kernel $duplicateRows @($facts)
if ($duplicateResult.status -cne 'Failed' -or $duplicateResult.issues -cnotcontains 'Duplicate dispatch assetObjectId.') { throw 'LF-05 duplicate dispatch fail-closed behavior failed.' }

$repeat = Run-Kernel @($dispatchRows) @($facts)
if (($result | ConvertTo-Json -Depth 100) -cne ($repeat | ConvertTo-Json -Depth 100)) { throw 'C3-0 determinism failed.' }
if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'Temp/C2DiscoveryPublication')) { throw 'C3-0 touched C2 publication state.' }

'status=Passed'
'dispatchEligibleObjectCount=7'
'assignedFamilyMemberCount=5'
'retainedForDiagnosisObjectCount=1'
'configurationOnlyObjectCount=1'
'familyCount=5'
'crossLaneReferenceCount=1'
'publicationWriteCount=0'
