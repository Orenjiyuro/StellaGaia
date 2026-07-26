[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = [System.IO.Path]::GetFullPath(
    (Join-Path -Path $PSScriptRoot -ChildPath '..\..'))
$unityEditorRoot = 'C:\SoftWork\Unity\Editor'
$dotnetPath = 'C:\SoftWork\Unity\Editor\Data\NetCoreRuntime\dotnet.exe'
$compilerPath = 'C:\SoftWork\Unity\Editor\Data\DotNetSdkRoslyn\csc.dll'
$netStandardReferenceRoot = Join-Path $unityEditorRoot 'Data\NetStandard\ref\2.1.0'
$netStandardShimRoot = Join-Path $unityEditorRoot 'Data\NetStandard\compat\2.1.0\shims'
$unityEngineReferenceRoot = Join-Path $unityEditorRoot 'Data\Managed\UnityEngine'
$unityEditorReference = Join-Path $unityEditorRoot 'Data\Managed\UnityEditor.dll'
$unityEditorModuleFacade = Join-Path $unityEditorRoot 'Data\Managed\UnityEngine\UnityEditor.dll'
$unityEditorCoreReference = Join-Path $unityEditorRoot 'Data\Managed\UnityEngine\UnityEditor.CoreModule.dll'
$runnerPath = Join-Path $projectRoot 'Assets\StellaGaia\Editor\DirectCharacterConsumerProofRunner.cs'
$fullValidationPath = Join-Path $projectRoot 'Assets\StellaGaia\Editor\DirectCharacterConsumerProofRunner.FullValidation.cs'
$outputRoot = Join-Path $projectRoot 'Extracted\Validation\UDCP-T2-OfflineCompile'
$assemblyPath = Join-Path $outputRoot 'DirectCharacterConsumerProofRunner.dll'
$compilerOutputPath = Join-Path $outputRoot 'compiler-output.txt'
$summaryPath = Join-Path $outputRoot 'compile-result.json'

foreach ($requiredFile in @(
    $dotnetPath,
    $compilerPath,
    $unityEditorReference,
    $unityEditorModuleFacade,
    $unityEditorCoreReference,
    $runnerPath,
    $fullValidationPath
)) {
    if (-not [System.IO.File]::Exists($requiredFile)) {
        throw "Required offline compile file is missing: $requiredFile"
    }
}
foreach ($requiredDirectory in @(
    $netStandardReferenceRoot,
    $netStandardShimRoot,
    $unityEngineReferenceRoot
)) {
    if (-not [System.IO.Directory]::Exists($requiredDirectory)) {
        throw "Required offline compile directory is missing: $requiredDirectory"
    }
}

[System.IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$referencePaths = [System.Collections.Generic.List[string]]::new()
foreach ($reference in @(
    Get-ChildItem -LiteralPath $netStandardReferenceRoot -Filter '*.dll' -File
    Get-ChildItem -LiteralPath $netStandardShimRoot -Filter '*.dll' -File -Recurse
    Get-ChildItem -LiteralPath $unityEngineReferenceRoot -Filter '*.dll' -File |
        Where-Object {
            $_.Name -notin @('UnityEditor.dll', 'UnityEditor.CoreModule.dll')
        }
)) {
    $referencePaths.Add($reference.FullName)
}
$referencePaths.Add($unityEditorCoreReference)

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
    "-out:$assemblyPath"
)) {
    $arguments.Add($argument)
}
foreach ($referencePath in $referencePaths) {
    $arguments.Add("-reference:$referencePath")
}
$arguments.Add("-reference:UnityEditorFacade=$unityEditorReference")
$arguments.Add("-reference:UnityEditorModuleFacade=$unityEditorModuleFacade")
$arguments.Add($runnerPath)
$arguments.Add($fullValidationPath)

$compilerLines = @(& $dotnetPath @arguments 2>&1 | ForEach-Object { $_.ToString() })
$compilerExitCode = $LASTEXITCODE
$compilerText = $compilerLines -join [Environment]::NewLine
[System.IO.File]::WriteAllText(
    $compilerOutputPath,
    $compilerText,
    [System.Text.UTF8Encoding]::new($false, $true))

$warningCount = [regex]::Matches(
    $compilerText,
    '(?im)\bwarning\s+CS\d+\b').Count
$errorCount = [regex]::Matches(
    $compilerText,
    '(?im)\berror\s+CS\d+\b').Count
$result = [ordered]@{
    schemaVersion = 'udcp-offline-compile/1.0.0'
    status = if (
        $compilerExitCode -eq 0 -and
        $warningCount -eq 0 -and
        $errorCount -eq 0 -and
        [System.IO.File]::Exists($assemblyPath)
    ) { 'Passed' } else { 'Failed' }
    compilerExitCode = $compilerExitCode
    warningCount = $warningCount
    errorCount = $errorCount
    sourceCount = 2
    unityEngineModuleReferenceCount = (
        Get-ChildItem -LiteralPath $unityEngineReferenceRoot -Filter '*.dll' -File
    ).Count
    disclaimer = 'This is an offline compile preflight, not a Unity import, render, or asset usability pass.'
}
$resultJson = $result | ConvertTo-Json -Depth 4
[System.IO.File]::WriteAllText(
    $summaryPath,
    $resultJson,
    [System.Text.UTF8Encoding]::new($false, $true))

if ($result.status -ne 'Passed') {
    throw (
        "UDCP-T2 offline compile failed: exit={0} errors={1} warnings={2}. See {3}" -f
        $compilerExitCode,
        $errorCount,
        $warningCount,
        $compilerOutputPath)
}

"UDCP-T2 offline compile GREEN: exit=0 errors=0 warnings=0 sources=2"
