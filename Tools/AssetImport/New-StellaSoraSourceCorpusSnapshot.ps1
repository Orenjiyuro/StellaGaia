[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRootManifestPath,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')][string]$ThreadId,
    [switch]$RefreshSnapshot
)
if (-not $RefreshSnapshot) {
    throw 'RefreshSnapshot is required; no source roots were read and no output was created.'
}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'SourceCorpusGate.psm1') -Force
$repositoryRoot=[System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$existingAttributes=[System.Collections.Generic.List[object]]::new()
$root=[System.IO.Path]::GetPathRoot($repositoryRoot);$cursor=$root
foreach($segment in @($repositoryRoot.Substring($root.Length).Trim('\','/') -split '[\\/]'|Where-Object{$_})){
    $cursor=Join-Path $cursor $segment
    $item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
    $existingAttributes.Add([pscustomobject]@{path=$item.FullName;attributes=$item.Attributes})
}
$cursor=$repositoryRoot
foreach($segment in @('Extracted','Threads',$ThreadId,'C1')){
    $cursor=Join-Path $cursor $segment
    if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force -ErrorAction Stop;$existingAttributes.Add([pscustomobject]@{path=$item.FullName;attributes=$item.Attributes})}
}
$validatedOutput=Assert-C1OutputPathPolicy -RepositoryRoot $repositoryRoot -OutputRoot $OutputRoot -ThreadId $ThreadId -ExistingPathAttributes $existingAttributes.ToArray()

$manifestText=Get-Content -LiteralPath $SourceRootManifestPath -Raw -ErrorAction Stop
$manifestDocument=[System.Text.Json.JsonDocument]::Parse($manifestText)
try{
    $rootElement=$manifestDocument.RootElement
    if($rootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object){throw 'Source-root manifest must be an object.'}
    $rootNames=@($rootElement.EnumerateObject()|ForEach-Object Name)
    if(($rootNames|Sort-Object)-join ',' -cne 'schemaVersion,sources'){throw 'Source-root manifest properties are invalid.'}
    $sourcesElement=$rootElement.GetProperty('sources')
    if($sourcesElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or $sourcesElement.GetArrayLength() -eq 0){throw 'Source-root manifest must use schemaVersion 1.0.0 and contain sources.'}
    foreach($sourceElement in $sourcesElement.EnumerateArray()){
        if($sourceElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object -or
           ((@($sourceElement.EnumerateObject()|ForEach-Object Name)|Sort-Object)-join ',') -cne 'rootPath,sourceId,sourceKind'){
            throw 'Invalid source-root manifest source row.'
        }
        foreach($name in @('sourceId','sourceKind','rootPath')){if($sourceElement.GetProperty($name).ValueKind -ne [System.Text.Json.JsonValueKind]::String){throw 'Invalid source-root manifest source row.'}}
    }
    $manifest=$manifestText|ConvertFrom-Json -Depth 100 -DateKind String
}finally{$manifestDocument.Dispose()}
if($manifest -isnot [System.Management.Automation.PSCustomObject] -or
   (@($manifest.PSObject.Properties.Name|Sort-Object)-join ',') -cne 'schemaVersion,sources' -or
   $manifest.schemaVersion -isnot [string] -or $manifest.schemaVersion -cne '1.0.0' -or
   $manifest.sources -isnot [object[]] -or $manifest.sources.Count -eq 0){throw 'Source-root manifest must use schemaVersion 1.0.0 and contain sources.'}
$seen=[System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach($source in $manifest.sources){
    if($source -isnot [System.Management.Automation.PSCustomObject] -or (@($source.PSObject.Properties.Name|Sort-Object)-join ',') -cne 'rootPath,sourceId,sourceKind' -or
       $source.sourceId -isnot [string] -or [string]::IsNullOrWhiteSpace($source.sourceId) -or $source.sourceId -match '[\x00\r\n]' -or -not $seen.Add($source.sourceId) -or
       $source.sourceKind -isnot [string] -or $source.sourceKind -cnotin @('PcInstall','PcPatchOrCache','AndroidApk','AndroidDataOrCache') -or
       $source.rootPath -isnot [string] -or [string]::IsNullOrWhiteSpace($source.rootPath) -or -not [System.IO.Path]::IsPathFullyQualified($source.rootPath)){
        throw 'Invalid source-root manifest source row.'
    }
}
$generatedAt=[datetimeoffset]::UtcNow;$snapshotId='snapshot-'+$generatedAt.ToString('yyyyMMddTHHmmssZ')
$sourceRows=[System.Collections.Generic.List[object]]::new();$fileRows=[System.Collections.Generic.List[object]]::new();$allExclusions=[System.Collections.Generic.List[object]]::new()
foreach($source in $manifest.sources){
    $catalog=New-SourceCorpusCatalog -SnapshotId $snapshotId -SourceId $source.sourceId -SourceKind $source.sourceKind -RootPath $source.rootPath -CapturedAt $generatedAt
    foreach($row in $catalog.files){$fileRows.Add($row)};foreach($row in $catalog.exclusions){$allExclusions.Add($row)}
    $rootFingerprint=Get-SourceRootFingerprint -Files $catalog.files
    $sourceRows.Add([pscustomobject][ordered]@{sourceId=$source.sourceId;sourceKind=$source.sourceKind;capturedAt=$generatedAt.ToString('O');rootFingerprint=$rootFingerprint;sourceFileCount=Get-CheckedInt64Total -Values @($catalog.catalogedFileCount,$catalog.explicitlyExcludedFileCount);sourceBytes=Get-CheckedInt64Total -Values @($catalog.catalogedBytes,$catalog.explicitlyExcludedBytes)})
}
$inputFingerprint=Get-SourceInputFingerprint -Sources $sourceRows.ToArray();$portableLedgerPath="Extracted/Threads/$ThreadId/C1/source-corpus-ledger.json"
$ledger=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$snapshotId;generatedAt=$generatedAt.ToString('O');inputFingerprint=$inputFingerprint;toolVersions=@([pscustomobject]@{toolName='New-StellaSoraSourceCorpusSnapshot';version='1.0.0'});sources=@($sourceRows|ForEach-Object{[pscustomobject][ordered]@{sourceId=$_.sourceId;sourceKind=$_.sourceKind;capturedAt=$_.capturedAt;rootFingerprint=$_.rootFingerprint}});files=$fileRows.ToArray();objects=@()}
$summary=New-SourceCorpusSummary -Ledger $ledger -LedgerPath $portableLedgerPath -SourceTotals $sourceRows.ToArray() -Exclusions $allExclusions.ToArray()
Write-SourceCorpusOutputs -OutputRoot $validatedOutput -Ledger $ledger -Summary $summary
