[CmdletBinding()]
param([ValidateSet('MissingRefresh','WrongOutput','InvalidThreadId','Reparse','All')][string]$Case='All')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$issues=[System.Collections.Generic.List[string]]::new()
$createdOutputCount=0
$temp=Join-Path ([System.IO.Path]::GetTempPath()) ('stella-c1-policy-'+[guid]::NewGuid().ToString('N'))
$runner=Join-Path $PSScriptRoot 'New-StellaSoraSourceCorpusSnapshot.ps1'
$module=Join-Path $PSScriptRoot 'SourceCorpusGate.psm1'
$repo=[System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$thread='01234567-89ab-cdef-0123-456789abcdef'
function Add-Issue([string]$Text){$issues.Add($Text)}
function Test-JsonProperties([System.Text.Json.JsonElement]$Element,[string[]]$Expected){
    if($Element.ValueKind -ne [System.Text.Json.JsonValueKind]::Object){return $false}
    return ((@($Element.EnumerateObject()|ForEach-Object Name)|Sort-Object)-join ',') -ceq (($Expected|Sort-Object)-join ',')
}
function Test-NoMachineStrings([System.Text.Json.JsonElement]$Element){
    if($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::String){$s=$Element.GetString();return -not([System.IO.Path]::IsPathRooted($s) -or $s -match '^[A-Za-z][A-Za-z0-9+.-]*://')}
    if($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Object){foreach($p in $Element.EnumerateObject()){if(-not(Test-NoMachineStrings $p.Value)){return $false}}}
    if($Element.ValueKind -eq [System.Text.Json.JsonValueKind]::Array){foreach($v in $Element.EnumerateArray()){if(-not(Test-NoMachineStrings $v)){return $false}}}
    return $true
}
function Test-SerializedPair([string]$LedgerJson,[string]$SummaryJson){
    $ld=[System.Text.Json.JsonDocument]::Parse($LedgerJson);$sd=[System.Text.Json.JsonDocument]::Parse($SummaryJson)
    try{
        $l=$ld.RootElement;$s=$sd.RootElement
        if(-not(Test-JsonProperties $l @('schemaVersion','snapshotId','generatedAt','inputFingerprint','toolVersions','sources','files','objects')) -or
           -not(Test-JsonProperties $s @('schemaVersion','generatedAt','snapshotId','inputFingerprint','ledgerInputFingerprint','ledgerPath','toolVersions','operationIdentity','directChildSummaries','directChildReports','failureAttribution','nextAllowedAction','sourceCount','sourceFileCount','catalogedFileCount','explicitlyExcludedFileCount','sourceBytes','catalogedBytes','explicitlyExcludedBytes','sources','exclusions'))){return $false}
        foreach($v in $l.GetProperty('sources').EnumerateArray()){if(-not(Test-JsonProperties $v @('sourceId','sourceKind','capturedAt','rootFingerprint'))){return $false}}
        foreach($v in $s.GetProperty('sources').EnumerateArray()){if(-not(Test-JsonProperties $v @('sourceId','sourceKind','rootFingerprint','sourceFileCount','sourceBytes'))){return $false}}
        foreach($v in $l.GetProperty('toolVersions').EnumerateArray()){if(-not(Test-JsonProperties $v @('toolName','version'))){return $false}}
        foreach($v in $s.GetProperty('toolVersions').EnumerateArray()){if(-not(Test-JsonProperties $v @('toolName','version'))){return $false}}
        foreach($v in $l.GetProperty('files').EnumerateArray()){if(-not(Test-JsonProperties $v @('snapshotId','sourceId','sourceKind','relativePath','sizeBytes','sha256','capturedAt','containerKind','parseStatus','disposition','evidence','status')) -or -not(Test-JsonProperties $v.GetProperty('status') @('corpus','extraction','semantics','unity','disposition'))){return $false}}
        if(-not(Test-NoMachineStrings $l) -or -not(Test-NoMachineStrings $s) -or $LedgerJson -match '"rootPath"' -or $SummaryJson -match '"rootPath"'){return $false}
        $lo=$LedgerJson|ConvertFrom-Json -Depth 100 -DateKind String;$so=$SummaryJson|ConvertFrom-Json -Depth 100 -DateKind String
        return $so.snapshotId -ceq $lo.snapshotId -and $so.generatedAt -ceq $lo.generatedAt -and $so.inputFingerprint -ceq $lo.inputFingerprint -and $so.ledgerInputFingerprint -ceq $lo.inputFingerprint -and $so.ledgerPath -cmatch '^Extracted/Threads/[0-9a-f-]+/C1/source-corpus-ledger\.json$'
    }finally{$ld.Dispose();$sd.Dispose()}
}
function Test-MissingRefresh {
    $manifest=Join-Path $temp 'does-not-exist.json'
    $output=Join-Path $repo "Extracted\Threads\$thread\C1"
    $stdout=Join-Path $temp 'stdout.txt'; $stderr=Join-Path $temp 'stderr.txt'
    & pwsh -NoProfile -File $runner -SourceRootManifestPath $manifest -OutputRoot $output -ThreadId $thread 1>$stdout 2>$stderr
    if($LASTEXITCODE -ne 1){Add-Issue "MissingRefresh expected exit 1, got $LASTEXITCODE."}
    $text=((Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue)+(Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue))
    if($text -notmatch [regex]::Escape('RefreshSnapshot is required; no source roots were read and no output was created.')){Add-Issue 'MissingRefresh exact refusal was absent.'}
    if(Test-Path -LiteralPath $output){Add-Issue 'MissingRefresh created output.'}
}
function Test-WrongOutput {
    Import-Module $module -Force
    try { Assert-C1OutputPathPolicy -RepositoryRoot $repo -OutputRoot (Join-Path $temp 'wrong') -ThreadId $thread | Out-Null; Add-Issue 'WrongOutput was accepted.' }
    catch { if($_.Exception.Message -cnotlike 'OutputRoot must equal *.'){Add-Issue "WrongOutput unstable refusal: $($_.Exception.Message)"} }
}
function Test-InvalidThreadId {
    Import-Module $module -Force
    foreach($bad in @('.','..','../escape','01234567-89AB-cdef-0123-456789abcdef','not-a-guid','01234567/89ab-cdef-0123-456789abcdef','01234567\89ab-cdef-0123-456789abcdef','01234567-89ab/./cdef-0123-456789abcdef','01234567-89ab/../cdef-0123-456789abcdef','01234567-89ab\.\cdef-0123-456789abcdef','01234567-89ab\..\cdef-0123-456789abcdef')){
        try { Assert-C1OutputPathPolicy -RepositoryRoot $repo -OutputRoot $temp -ThreadId $bad | Out-Null; Add-Issue "Invalid ThreadId accepted: $bad" }
        catch { if($_.Exception.Message -cne "Invalid ThreadId: $bad"){Add-Issue "InvalidThreadId unstable refusal: $($_.Exception.Message)"} }
    }
}
function Test-Reparse {
    Import-Module $module -Force
    $expected=Join-Path $repo "Extracted\Threads\$thread\C1"
    foreach($row in @(
        [pscustomobject]@{path=$repo;attributes=[System.IO.FileAttributes]::ReparsePoint},
        [pscustomobject]@{path=(Join-Path $repo 'Extracted');attributes=[System.IO.FileAttributes]::ReparsePoint}
    )){
        try { Assert-C1OutputPathPolicy -RepositoryRoot $repo -OutputRoot $expected -ThreadId $thread -ExistingPathAttributes @($row) | Out-Null; Add-Issue 'Reparse attribute was accepted.' }
        catch { if($_.Exception.Message -cnotlike '* is a reparse point.'){Add-Issue "Reparse unstable refusal: $($_.Exception.Message)"} }
    }
    try { Assert-C1OutputPathPolicy -RepositoryRoot $repo -OutputRoot $expected -ThreadId $thread -ExistingPathAttributes @([pscustomobject]@{path=$repo}) | Out-Null; Add-Issue 'Malformed attributes accepted.' }
    catch { }
}
function Test-Writer {
    Import-Module $module -Force
    $hash='a'*64; $generated='2026-07-11T00:00:00.0000000+00:00'; $snapshot='snapshot-test'
    $file=[pscustomobject][ordered]@{snapshotId=$snapshot;sourceId='pc-primary';sourceKind='PcInstall';relativePath='data.bin';sizeBytes=[long]3;sha256=$hash;capturedAt=$generated;containerKind='UnknownInput';parseStatus='NotAttempted';disposition='RetainForLater';evidence=@();status=[pscustomobject][ordered]@{corpus='Cataloged';extraction='NotAttempted';semantics='Unknown';unity='NotTested';disposition='RetainForLater'}}
    $ledger=[pscustomobject][ordered]@{schemaVersion='1.0.0';snapshotId=$snapshot;generatedAt=$generated;inputFingerprint=$hash;toolVersions=@([pscustomobject]@{toolName='test';version='1.0.0'});sources=@([pscustomobject]@{sourceId='pc-primary';sourceKind='PcInstall';capturedAt=$generated;rootFingerprint=$hash});files=@($file);objects=@()}
    $totals=@([pscustomobject]@{sourceId='pc-primary';sourceKind='PcInstall';capturedAt=$generated;rootFingerprint=$hash;sourceFileCount=[long]1;sourceBytes=[long]3})
    $summary=New-SourceCorpusSummary -Ledger $ledger -LedgerPath "Extracted/Threads/$thread/C1/source-corpus-ledger.json" -SourceTotals $totals
    $badTimestampTotals=@([pscustomobject]@{sourceId='pc-primary';sourceKind='PcInstall';capturedAt='2099-01-01T00:00:00.0000000+00:00';rootFingerprint=$hash;sourceFileCount=[long]1;sourceBytes=[long]3})
    $accepted=$false;try{New-SourceCorpusSummary -Ledger $ledger -LedgerPath "Extracted/Threads/$thread/C1/source-corpus-ledger.json" -SourceTotals $badTimestampTotals|Out-Null;$accepted=$true}catch{}
    if($accepted){Add-Issue 'Source capturedAt mismatch was accepted.'}
    foreach($mutation in @(
        @{name='sourceId';value='other-source'},
        @{name='sourceKind';value='AndroidApk'},
        @{name='rootFingerprint';value=('b'*64)}
    )){
        $badTotals=@([pscustomobject]@{sourceId=$totals[0].sourceId;sourceKind=$totals[0].sourceKind;capturedAt=$generated;rootFingerprint=$totals[0].rootFingerprint;sourceFileCount=[long]1;sourceBytes=[long]3})
        $badTotals[0].($mutation.name)=$mutation.value
        $accepted=$false;try{New-SourceCorpusSummary -Ledger $ledger -LedgerPath "Extracted/Threads/$thread/C1/source-corpus-ledger.json" -SourceTotals $badTotals|Out-Null;$accepted=$true}catch{}
        if($accepted){Add-Issue "Source identity mismatch accepted: $($mutation.name)"}
    }
    $output=Join-Path $temp 'writer/C1'; $paths=Write-SourceCorpusOutputs -OutputRoot $output -Ledger $ledger -Summary $summary
    $createdOutputCount++
    $names=@(Get-ChildItem -LiteralPath $output -File | ForEach-Object Name | Sort-Object)
    if(($names -join ',') -cne 'source-corpus-ledger.json,source-corpus-summary.json'){Add-Issue 'Writer emitted unexpected files.'}
    $ledgerJson=Get-Content -LiteralPath $paths.ledgerPath -Raw;$summaryJson=Get-Content -LiteralPath $paths.summaryPath -Raw
    if(-not(Test-SerializedPair $ledgerJson $summaryJson)){Add-Issue 'Serialized output structural validation failed.'}
    $mutatedLedger=$ledgerJson.TrimEnd() -replace '}\s*$' , ',"extra":true}'
    if(Test-SerializedPair $mutatedLedger $summaryJson){Add-Issue 'Serialized validator accepted an extra ledger property.'}
    $mutatedSummary=$summaryJson.Replace($snapshot,'snapshot-mismatch')
    if(Test-SerializedPair $ledgerJson $mutatedSummary){Add-Issue 'Serialized validator accepted mismatched identity.'}
    $ledgerObject=$ledgerJson|ConvertFrom-Json -Depth 100 -DateKind String
    $ledgerObject|Add-Member -NotePropertyName rootPath -NotePropertyValue (Join-Path $temp 'synthetic-source')
    $rootPathMutation=$ledgerObject|ConvertTo-Json -Depth 100
    if(Test-SerializedPair $rootPathMutation $summaryJson){Add-Issue 'Serialized validator accepted an injected rootPath property.'}
    $summaryObject=$summaryJson|ConvertFrom-Json -Depth 100 -DateKind String
    $summaryObject.failureAttribution=[System.IO.Path]::GetFullPath((Join-Path $temp 'synthetic-machine-path'))
    $machinePathMutation=$summaryObject|ConvertTo-Json -Depth 100
    if(Test-SerializedPair $ledgerJson $machinePathMutation){Add-Issue 'Serialized validator accepted an injected absolute machine path.'}
    foreach($invalid in @(
        [pscustomobject]@{name='evil objects';ledger=[pscustomobject]@{evil='ledger'};summary=[pscustomobject]@{evil='summary'}},
        [pscustomobject]@{name='extra ledger property';ledger=($ledgerJson|ConvertFrom-Json -Depth 100 -DateKind String);summary=$summary},
        [pscustomobject]@{name='mismatched summary identity';ledger=$ledger;summary=($summaryJson.Replace($snapshot,'snapshot-other')|ConvertFrom-Json -Depth 100 -DateKind String)},
        [pscustomobject]@{name='rootPath property';ledger=($rootPathMutation|ConvertFrom-Json -Depth 100 -DateKind String);summary=$summary},
        [pscustomobject]@{name='absolute machine path';ledger=$ledger;summary=($machinePathMutation|ConvertFrom-Json -Depth 100 -DateKind String)}
    )){
        if($invalid.name -ceq 'extra ledger property'){$invalid.ledger|Add-Member -NotePropertyName extra -NotePropertyValue $true}
        $badOutput=Join-Path $temp ('invalid-'+[guid]::NewGuid().ToString('N')+'/C1');$accepted=$false
        try{Write-SourceCorpusOutputs -OutputRoot $badOutput -Ledger $invalid.ledger -Summary $invalid.summary|Out-Null;$accepted=$true}catch{}
        if($accepted){Add-Issue "Writer accepted $($invalid.name)."}
        if(Test-Path -LiteralPath $badOutput){Add-Issue "Writer published output for $($invalid.name)."}
    }
    foreach($dictionaryMutation in @(
        [pscustomobject]@{name='nested dictionary rootPath';value=@{rootPath='portable-looking'}},
        [pscustomobject]@{name='nested dictionary absolute path';value=@{note=[System.IO.Path]::GetFullPath((Join-Path $temp 'dictionary-machine-path'))}}
    )){
        $badLedger=$ledgerJson|ConvertFrom-Json -Depth 100 -DateKind String;$badLedger.files[0].evidence=@($dictionaryMutation.value)
        $badOutput=Join-Path $temp ('dictionary-invalid-'+[guid]::NewGuid().ToString('N')+'/C1');$accepted=$false
        try{Write-SourceCorpusOutputs -OutputRoot $badOutput -Ledger $badLedger -Summary $summary|Out-Null;$accepted=$true}catch{}
        if($accepted){Add-Issue "Writer accepted $($dictionaryMutation.name)."};if(Test-Path -LiteralPath $badOutput){Add-Issue "Writer published output for $($dictionaryMutation.name)."}
    }
    $cycle=@{};$cycle.self=$cycle;$cycleSummary=$summaryJson|ConvertFrom-Json -Depth 100 -DateKind String;$cycleSummary.failureAttribution=$cycle
    $cycleOutput=Join-Path $temp 'cycle-invalid/C1';$accepted=$false;try{Write-SourceCorpusOutputs -OutputRoot $cycleOutput -Ledger $ledger -Summary $cycleSummary|Out-Null;$accepted=$true}catch{}
    if($accepted){Add-Issue 'Writer accepted cyclic dictionary data.'};if(Test-Path -LiteralPath $cycleOutput){Add-Issue 'Writer published cyclic dictionary data.'}
    $junctionTarget=Join-Path $temp 'junction-target';$junction=Join-Path $temp 'junction-parent';[System.IO.Directory]::CreateDirectory($junctionTarget)|Out-Null
    New-Item -ItemType Junction -Path $junction -Target $junctionTarget -ErrorAction Stop|Out-Null
    $junctionOutput=Join-Path $junction 'C1';$accepted=$false;try{Write-SourceCorpusOutputs -OutputRoot $junctionOutput -Ledger $ledger -Summary $summary|Out-Null;$accepted=$true}catch{}
    if($accepted){Add-Issue 'Writer accepted a junction parent.'};if(Test-Path -LiteralPath $junctionOutput){Add-Issue 'Writer published through a junction parent.'}
    $gateOut=& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-SourceCorpusGate.ps1') -SummaryPath $paths.summaryPath -LedgerPath $paths.ledgerPath
    if($LASTEXITCODE -ne 0 -or ($gateOut|ConvertFrom-Json).status -cne 'Passed'){Add-Issue 'Writer outputs violate the frozen Task 0 contract.'}
    if($summary.snapshotId -cne $ledger.snapshotId -or $summary.generatedAt -cne $ledger.generatedAt -or $summary.inputFingerprint -cne $ledger.inputFingerprint){Add-Issue 'Shared identity fields differ.'}
    try { Write-SourceCorpusOutputs -OutputRoot $output -Ledger $ledger -Summary $summary | Out-Null; Add-Issue 'Existing output was overwritten.' } catch {}
    Remove-Item -LiteralPath $output -Recurse -Force; $createdOutputCount--
}
function Assert-RunnerStructure([string]$Path){
    $tokens=$null;$errors=$null;$ast=[System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors);if($errors.Count){throw 'Runner AST has parse errors.'}
    $params=@($ast.ParamBlock.Parameters);$refresh=@($params|Where-Object{$_.Name.VariablePath.UserPath -ceq 'RefreshSnapshot'})
    if($refresh.Count-ne 1 -or $refresh[0].StaticType -ne [System.Management.Automation.SwitchParameter]){throw 'RefreshSnapshot switch contract missing.'}
    foreach($name in @('SourceRootManifestPath','OutputRoot','ThreadId')){
        $matches=@($params|Where-Object{$_.Name.VariablePath.UserPath -ceq $name});if($matches.Count-ne 1 -or $matches[0].StaticType -ne [string]){throw "Mandatory string parameter missing: $name"}
        $parameterAttributes=@($matches[0].Attributes|Where-Object{$_.TypeName.FullName -ceq 'Parameter'})
        if($parameterAttributes.Count-ne 1 -or $parameterAttributes[0].Extent.Text -cnotmatch 'Mandatory'){throw "Mandatory attribute missing: $name"}
    }
    $threadParam=@($params|Where-Object{$_.Name.VariablePath.UserPath -ceq 'ThreadId'})[0]
    $patterns=@($threadParam.Attributes|Where-Object{$_.TypeName.FullName -ceq 'ValidatePattern'})
    if($patterns.Count-ne 1 -or $patterns[0].Extent.Text -cnotmatch [regex]::Escape('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')){throw 'ThreadId ValidatePattern contract missing.'}
    $first=@($ast.EndBlock.Statements)[0];if($first -isnot [System.Management.Automation.Language.IfStatementAst] -or $first.Extent.Text -cnotmatch '^if\s*\(\s*-not\s+\$RefreshSnapshot\s*\)' -or $first.Extent.Text -cnotmatch [regex]::Escape("throw 'RefreshSnapshot is required; no source roots were read and no output was created.'")){throw 'First executable statement is not the exact refresh refusal gate.'}
    $commands=@($ast.FindAll({param($n)$n -is [System.Management.Automation.Language.CommandAst]},$true));$names=@($commands|ForEach-Object GetCommandName)
    foreach($required in @('Assert-C1OutputPathPolicy','New-SourceCorpusCatalog','Get-SourceRootFingerprint','Get-SourceInputFingerprint','New-SourceCorpusSummary','Write-SourceCorpusOutputs')){if($names -cnotcontains $required){throw "Runner command missing: $required"}}
    foreach($forbidden in @('Start-Process','Unity','AssetRipper','ffmpeg','vgmstream-cli')){if($names -contains $forbidden){throw "Forbidden command in runner: $forbidden"}}
}
function Test-RunnerAst {
    try{Assert-RunnerStructure $runner}catch{Add-Issue $_.Exception.Message}
    $decoy=Join-Path $temp 'decoy.ps1'
    $decoyText=@'
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
# Assert-C1OutputPathPolicy New-SourceCorpusCatalog Get-SourceRootFingerprint
'Get-SourceInputFingerprint New-SourceCorpusSummary Write-SourceCorpusOutputs'
'@
    [System.IO.File]::WriteAllText($decoy,$decoyText)
    $accepted=$false;$decoyDiagnostic='';try{Assert-RunnerStructure $decoy;$accepted=$true}catch{$decoyDiagnostic=$_.Exception.Message}
    if($accepted){Add-Issue 'Structural validator accepted a string/comment decoy runner.'}
    elseif($decoyDiagnostic -cnotlike 'Runner command missing:*'){Add-Issue "Decoy was rejected before actual-command validation: $decoyDiagnostic"}
    $tokens=$null;$errors=$null;$policyAst=[System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath,[ref]$tokens,[ref]$errors)
    $runnerCalls=@($policyAst.FindAll({param($n)$n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -ceq 'pwsh'},$true))
    foreach($call in $runnerCalls){if(@($call.CommandElements|Where-Object{$_.Extent.Text -ceq '-RefreshSnapshot'}).Count){Add-Issue 'Policy harness invokes RefreshSnapshot.'}}
    $moduleTokens=$null;$moduleErrors=$null;$moduleAst=[System.Management.Automation.Language.Parser]::ParseFile($module,[ref]$moduleTokens,[ref]$moduleErrors)
    $writerFunction=@($moduleAst.FindAll({param($n)$n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Write-SourceCorpusOutputs'},$true))[0]
    $writerCommands=@($writerFunction.Body.FindAll({param($n)$n -is [System.Management.Automation.Language.CommandAst]},$true));$writerMembers=@($writerFunction.Body.FindAll({param($n)$n -is [System.Management.Automation.Language.InvokeMemberExpressionAst]},$true))
    $create=@($writerMembers|Where-Object{$_.Member.Value -ceq 'CreateDirectory'});$genuine=@($writerCommands|Where-Object{$_.GetCommandName() -ceq 'Assert-GenuineDirectoryAtExactPath'});$writes=@($writerMembers|Where-Object{$_.Member.Value -ceq 'WriteAllText'});$move=@($writerCommands|Where-Object{$_.GetCommandName() -ceq 'Move-Item'})
    if($create.Count-lt 2 -or $genuine.Count-lt 5 -or $writes.Count-ne 2 -or $move.Count-ne 1 -or $genuine[0].Extent.StartOffset -lt $create[-1].Extent.StartOffset -or $genuine[0].Extent.StartOffset -gt $writes[0].Extent.StartOffset -or $genuine[-2].Extent.StartOffset -gt $move[0].Extent.StartOffset -or $genuine[-2].Extent.StartOffset -lt $writes[-1].Extent.StartOffset -or $genuine[-1].Extent.StartOffset -lt $move[0].Extent.StartOffset){Add-Issue 'Writer staging revalidation AST ordering is invalid.'}
}
try{
    $null=[System.IO.Directory]::CreateDirectory($temp)
    if($Case -in @('MissingRefresh','All')){Test-MissingRefresh}
    if($Case -in @('WrongOutput','All')){Test-WrongOutput}
    if($Case -in @('InvalidThreadId','All')){Test-InvalidThreadId}
    if($Case -in @('Reparse','All')){Test-Reparse}
    if($Case -eq 'All'){Test-Writer;Test-RunnerAst}
}catch{Add-Issue $_.Exception.Message}
finally{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Recurse -Force}}
if(Test-Path -LiteralPath (Join-Path $repo 'Extracted')){Add-Issue 'Repository Extracted exists.'}
$result=[pscustomobject][ordered]@{status=if($issues.Count-eq 0){'Passed'}else{'Failed'};issueCount=$issues.Count;issues=$issues.ToArray();createdOutputCount=$createdOutputCount}
$result|ConvertTo-Json -Compress -Depth 10
if($issues.Count){exit 1}
