[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$unityRoot = 'C:\SoftWork\Unity\Editor'
$dotnetPath = Join-Path $unityRoot 'Data\NetCoreRuntime\dotnet.exe'
$compilerPath = Join-Path $unityRoot 'Data\DotNetSdkRoslyn\csc.dll'
$netStandard = Join-Path $unityRoot 'Data\NetStandard\ref\2.1.0'
$shims = Join-Path $unityRoot 'Data\NetStandard\compat\2.1.0\shims'
$unityManaged = Join-Path $unityRoot 'Data\Managed\UnityEngine'
$unityEditor = Join-Path $unityRoot 'Data\Managed\UnityEditor.dll'
$unityEditorFacade = Join-Path $unityManaged 'UnityEditor.dll'
$unityEditorCore = Join-Path $unityManaged 'UnityEditor.CoreModule.dll'
$runtimeSource = Join-Path $root 'Assets\StellaGaia\Scripts\CCVC\CoreCharacterVisualCaptureRunner.cs'
$builderSource = Join-Path $root 'Assets\StellaGaia\Editor\CoreCharacterVisualCaptureBuilder.cs'
$outputRoot = Join-Path $root 'Extracted\Validation\CCVC-T1-OfflineCompile'
$runtimeDll = Join-Path $outputRoot 'CoreCharacterVisualCaptureRunner.dll'
$builderDll = Join-Path $outputRoot 'CoreCharacterVisualCaptureBuilder.dll'
$runtimeLog = Join-Path $outputRoot 'runtime-compiler-output.txt'
$builderLog = Join-Path $outputRoot 'builder-compiler-output.txt'
$summaryPath = Join-Path $outputRoot 'compile-result.json'

foreach ($file in @(
    $dotnetPath, $compilerPath, $unityEditor, $unityEditorFacade,
    $unityEditorCore, $runtimeSource, $builderSource
)) {
    if (-not [IO.File]::Exists($file)) {
        throw "Offline compile input missing: $file"
    }
}
foreach ($directory in @($netStandard, $shims, $unityManaged)) {
    if (-not [IO.Directory]::Exists($directory)) {
        throw "Offline compile reference directory missing: $directory"
    }
}
if ([IO.Directory]::Exists($outputRoot)) {
    throw 'CCVC offline compile output already exists.'
}
[IO.Directory]::CreateDirectory($outputRoot) | Out-Null

$framework = @(
    Get-ChildItem -LiteralPath $netStandard -Filter '*.dll' -File
    Get-ChildItem -LiteralPath $shims -Filter '*.dll' -File -Recurse
) | ForEach-Object { $_.FullName }
$runtimeUnity = @(
    Get-ChildItem -LiteralPath $unityManaged -Filter 'UnityEngine*.dll' -File
) | ForEach-Object { $_.FullName }

function Invoke-Compile {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Output,
        [Parameter(Mandatory)][string]$Log,
        [Parameter(Mandatory)][string[]]$References,
        [string[]]$Aliases = @()
    )
    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($value in @(
        $compilerPath, '-nologo', '-nostdlib+', '-target:library',
        '-langversion:9.0', '-nullable:disable', '-warn:4',
        '-warnaserror+', '-deterministic+', '-optimize+', "-out:$Output"
    )) {
        $arguments.Add($value)
    }
    foreach ($reference in $References) {
        $arguments.Add("-reference:$reference")
    }
    foreach ($alias in $Aliases) {
        $arguments.Add("-reference:$alias")
    }
    $arguments.Add($Source)
    $lines = @(& $dotnetPath @arguments 2>&1 |
        ForEach-Object { $_.ToString() })
    $exit = $LASTEXITCODE
    $text = $lines -join [Environment]::NewLine
    [IO.File]::WriteAllText(
        $Log,
        $text,
        [Text.UTF8Encoding]::new($false, $true))
    return [ordered]@{
        exitCode = $exit
        errorCount = [regex]::Matches(
            $text, '(?im)\berror\s+CS\d+\b').Count
        warningCount = [regex]::Matches(
            $text, '(?im)\bwarning\s+CS\d+\b').Count
        outputExists = [IO.File]::Exists($Output)
    }
}

$runtimeResult = Invoke-Compile `
    -Source $runtimeSource `
    -Output $runtimeDll `
    -Log $runtimeLog `
    -References @($framework + $runtimeUnity)
$builderResult = Invoke-Compile `
    -Source $builderSource `
    -Output $builderDll `
    -Log $builderLog `
    -References @($framework + $runtimeUnity + $unityEditorCore) `
    -Aliases @(
        "UnityEditorFacade=$unityEditor",
        "UnityEditorModuleFacade=$unityEditorFacade"
    )

$passed = (
    $runtimeResult.exitCode -eq 0 -and
    $runtimeResult.errorCount -eq 0 -and
    $runtimeResult.warningCount -eq 0 -and
    $runtimeResult.outputExists -and
    $builderResult.exitCode -eq 0 -and
    $builderResult.errorCount -eq 0 -and
    $builderResult.warningCount -eq 0 -and
    $builderResult.outputExists
)
$summary = [ordered]@{
    schemaVersion = 'ccvc-offline-compile/1.0.0'
    status = if ($passed) { 'Passed' } else { 'Failed' }
    runtimeExitCode = $runtimeResult.exitCode
    runtimeErrorCount = $runtimeResult.errorCount
    runtimeWarningCount = $runtimeResult.warningCount
    builderExitCode = $builderResult.exitCode
    builderErrorCount = $builderResult.errorCount
    builderWarningCount = $builderResult.warningCount
    disclaimer = 'This is not a Unity Player build or runtime validation.'
}
[IO.File]::WriteAllText(
    $summaryPath,
    (($summary | ConvertTo-Json -Depth 5) + "`n"),
    [Text.UTF8Encoding]::new($false, $true))
if (-not $passed) {
    throw (
        'CCVC offline compile failed: runtime={0}/{1}/{2}, builder={3}/{4}/{5}' -f
        $runtimeResult.exitCode,
        $runtimeResult.errorCount,
        $runtimeResult.warningCount,
        $builderResult.exitCode,
        $builderResult.errorCount,
        $builderResult.warningCount)
}

'CCVC offline compile GREEN: runtime=0/0/0 builder=0/0/0'
