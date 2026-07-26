[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $PSScriptRoot '..\..'))
$unityRoot = 'C:\SoftWork\Unity\Editor'
$dotnetPath = 'C:\SoftWork\Unity\Editor\Data\NetCoreRuntime\dotnet.exe'
$compilerPath = 'C:\SoftWork\Unity\Editor\Data\DotNetSdkRoslyn\csc.dll'
$netStandardRoot = Join-Path $unityRoot 'Data\NetStandard\ref\2.1.0'
$shimRoot = Join-Path $unityRoot 'Data\NetStandard\compat\2.1.0\shims'
$unityManagedRoot = Join-Path $unityRoot 'Data\Managed\UnityEngine'
$unityEditorReference = Join-Path $unityRoot 'Data\Managed\UnityEditor.dll'
$unityEditorModuleFacade = Join-Path $unityManagedRoot 'UnityEditor.dll'
$unityEditorCoreReference = Join-Path $unityManagedRoot 'UnityEditor.CoreModule.dll'
$runtimeSource = Join-Path $projectRoot 'Assets\StellaGaia\Scripts\UDCP\DirectCharacterPlayerProofRunner.cs'
$builderSource = Join-Path $projectRoot 'Assets\StellaGaia\Editor\DirectCharacterPlayerProofBuilder.cs'
$outputRoot = Join-Path $projectRoot 'Extracted\Validation\UDCP-T3-OfflineCompile'
$runtimeAssembly = Join-Path $outputRoot 'DirectCharacterPlayerProofRunner.dll'
$builderAssembly = Join-Path $outputRoot 'DirectCharacterPlayerProofBuilder.dll'
$runtimeLog = Join-Path $outputRoot 'runtime-compiler-output.txt'
$builderLog = Join-Path $outputRoot 'builder-compiler-output.txt'
$summaryPath = Join-Path $outputRoot 'compile-result.json'

foreach ($file in @(
    $dotnetPath,
    $compilerPath,
    $unityEditorReference,
    $unityEditorModuleFacade,
    $unityEditorCoreReference,
    $runtimeSource,
    $builderSource
)) {
    if (-not [System.IO.File]::Exists($file)) {
        throw "Required offline compile file is missing: $file"
    }
}
foreach ($directory in @($netStandardRoot, $shimRoot, $unityManagedRoot)) {
    if (-not [System.IO.Directory]::Exists($directory)) {
        throw "Required offline compile directory is missing: $directory"
    }
}
[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$frameworkReferences = @(
    Get-ChildItem -LiteralPath $netStandardRoot -Filter '*.dll' -File
    Get-ChildItem -LiteralPath $shimRoot -Filter '*.dll' -File -Recurse
) | ForEach-Object { $_.FullName }
$runtimeUnityReferences = @(
    Get-ChildItem -LiteralPath $unityManagedRoot -Filter 'UnityEngine*.dll' -File
) | ForEach-Object { $_.FullName }

function Invoke-UnityOwnedCompile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$OutputAssembly,
        [Parameter(Mandatory)][string]$OutputLog,
        [Parameter(Mandatory)][string[]]$References,
        [Parameter()][string[]]$AliasedReferences = @()
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    foreach ($argument in @(
        $compilerPath,
        '-nologo',
        '-nostdlib+',
        '-target:library',
        '-langversion:9.0',
        '-nullable:disable',
        '-warn:4',
        '-warnaserror+',
        '-deterministic+',
        '-optimize+',
        "-out:$OutputAssembly"
    )) {
        $arguments.Add($argument)
    }
    foreach ($reference in $References) {
        $arguments.Add("-reference:$reference")
    }
    foreach ($aliasedReference in $AliasedReferences) {
        $arguments.Add("-reference:$aliasedReference")
    }
    $arguments.Add($Source)
    $lines = @(& $dotnetPath @arguments 2>&1 |
        ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
    $text = $lines -join [Environment]::NewLine
    [System.IO.File]::WriteAllText(
        $OutputLog,
        $text,
        [System.Text.UTF8Encoding]::new($false, $true))
    return [ordered]@{
        exitCode = $exitCode
        errorCount = [regex]::Matches(
            $text,
            '(?im)\berror\s+CS\d+\b').Count
        warningCount = [regex]::Matches(
            $text,
            '(?im)\bwarning\s+CS\d+\b').Count
        outputExists = [System.IO.File]::Exists($OutputAssembly)
    }
}

$runtimeReferences = @($frameworkReferences + $runtimeUnityReferences)
$runtimeResult = Invoke-UnityOwnedCompile `
    -Source $runtimeSource `
    -OutputAssembly $runtimeAssembly `
    -OutputLog $runtimeLog `
    -References $runtimeReferences

$builderReferences = @(
    $frameworkReferences +
    $runtimeUnityReferences +
    $unityEditorCoreReference
)
$builderAliases = @(
    "UnityEditorFacade=$unityEditorReference",
    "UnityEditorModuleFacade=$unityEditorModuleFacade"
)
$builderResult = Invoke-UnityOwnedCompile `
    -Source $builderSource `
    -OutputAssembly $builderAssembly `
    -OutputLog $builderLog `
    -References $builderReferences `
    -AliasedReferences $builderAliases

$result = [ordered]@{
    schemaVersion = 'udcp-player-offline-compile/1.0.0'
    status = if (
        $runtimeResult.exitCode -eq 0 -and
        $runtimeResult.errorCount -eq 0 -and
        $runtimeResult.warningCount -eq 0 -and
        $runtimeResult.outputExists -and
        $builderResult.exitCode -eq 0 -and
        $builderResult.errorCount -eq 0 -and
        $builderResult.warningCount -eq 0 -and
        $builderResult.outputExists
    ) { 'Passed' } else { 'Failed' }
    runtimeExitCode = $runtimeResult.exitCode
    runtimeErrorCount = $runtimeResult.errorCount
    runtimeWarningCount = $runtimeResult.warningCount
    builderExitCode = $builderResult.exitCode
    builderErrorCount = $builderResult.errorCount
    builderWarningCount = $builderResult.warningCount
    disclaimer = 'This is an offline compile preflight, not a Unity Player build or runtime validation.'
}
[System.IO.File]::WriteAllText(
    $summaryPath,
    ($result | ConvertTo-Json -Depth 5),
    [System.Text.UTF8Encoding]::new($false, $true))
if ($result.status -ne 'Passed') {
    throw (
        "UDCP-T3 offline compile failed: runtime={0}/{1}/{2}, builder={3}/{4}/{5}" -f
        $result.runtimeExitCode,
        $result.runtimeErrorCount,
        $result.runtimeWarningCount,
        $result.builderExitCode,
        $result.builderErrorCount,
        $result.builderWarningCount)
}

"UDCP-T3 offline compile GREEN: runtime=0/0/0 builder=0/0/0"
