[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$ValidationRoot,
    [string[]]$EditorScriptPath = @('Assets\StellaGaia\Editor\ActorPrototypeControllerBuilder.cs'),
    [string[]]$SupportScriptPath = @(),
    [switch]$AllStellaGaiaScripts,
    [switch]$NoThrow
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsPathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$CandidatePath,
        [Parameter(Mandatory = $true)][string]$RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $candidate = (Get-CanonicalPath $CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    return $candidate.Equals($root, $comparison) -or $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must stay under $RootPath. Got: $Path"
    }
}

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return Get-CanonicalPath $Path
    }

    return Get-CanonicalPath (Join-Path $RepoRoot $Path)
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-LatestDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $Path -Directory | Sort-Object -Property Name | Select-Object -Last 1
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($ValidationRoot)) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\UnityEditorScriptCompilePreflight'
}

$ToolManifestPath = Resolve-RepoPath -RepoRoot $repoRoot -Path $ToolManifestPath
$ValidationRoot = Resolve-RepoPath -RepoRoot $repoRoot -Path $ValidationRoot
$scratchRoot = Join-Path $ValidationRoot 'Scratch'
$summaryPath = Join-Path $ValidationRoot 'unity-editor-script-compile-preflight-summary.json'
$outputTextPath = Join-Path $ValidationRoot 'unity-editor-script-compile-preflight-output.txt'
$outputAssemblyPath = Join-Path $scratchRoot 'UnityEditorScriptCompilePreflight.dll'

Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $ValidationRoot -RootPath $extractedRoot -Description 'ValidationRoot'
[void][System.IO.Directory]::CreateDirectory($scratchRoot)

$issues = [System.Collections.Generic.List[string]]::new()
$missingInputs = [System.Collections.Generic.List[string]]::new()
$resolvedScripts = [System.Collections.Generic.List[string]]::new()
$scriptInputs = [System.Collections.Generic.List[string]]::new()
if ($AllStellaGaiaScripts) {
    $stellaGaiaRoot = Join-Path $repoRoot 'Assets\StellaGaia'
    if (Test-Path -LiteralPath $stellaGaiaRoot -PathType Container) {
        foreach ($script in Get-ChildItem -LiteralPath $stellaGaiaRoot -Filter '*.cs' -Recurse) {
            $scriptInputs.Add($script.FullName) | Out-Null
        }
    }
} else {
    foreach ($scriptPath in @($EditorScriptPath)) {
        $scriptInputs.Add($scriptPath) | Out-Null
    }
    foreach ($scriptPath in @($SupportScriptPath)) {
        $scriptInputs.Add($scriptPath) | Out-Null
    }
}

$seenScripts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($scriptPath in @($scriptInputs)) {
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        continue
    }

    $resolved = Resolve-RepoPath -RepoRoot $repoRoot -Path $scriptPath
    Assert-PathUnderOrEqual -Path $resolved -RootPath $repoRoot -Description 'EditorScriptPath'
    if (-not $seenScripts.Add($resolved)) {
        continue
    }

    if (Test-Path -LiteralPath $resolved -PathType Leaf) {
        $resolvedScripts.Add($resolved) | Out-Null
    } else {
        $missingInputs.Add($resolved) | Out-Null
    }
}

if ($resolvedScripts.Count -eq 0) {
    $issues.Add('No editor scripts were available for compile preflight.') | Out-Null
}
foreach ($missing in $missingInputs) {
    $issues.Add("Missing editor script: $missing") | Out-Null
}

$toolManifest = Read-JsonFile -Path $ToolManifestPath
$unityManagedRoot = $null
if ($null -ne $toolManifest -and -not [string]::IsNullOrWhiteSpace([string]$toolManifest.unityEditor)) {
    $unityEditorPath = Get-CanonicalPath ([string]$toolManifest.unityEditor)
    $unityManagedRoot = Join-Path (Split-Path -Parent $unityEditorPath) 'Data\Managed'
}

$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$sdkRoot = Get-LatestDirectory -Path 'C:\Program Files\dotnet\sdk'
$netRefRoot = Get-LatestDirectory -Path 'C:\Program Files\dotnet\packs\Microsoft.NETCore.App.Ref'
$netRefPath = if ($null -ne $netRefRoot) { Join-Path $netRefRoot.FullName 'ref\net8.0' } else { $null }
$cscPath = if ($null -ne $sdkRoot) { Join-Path $sdkRoot.FullName 'Roslyn\bincore\csc.dll' } else { $null }
$unityEnginePath = if ($null -ne $unityManagedRoot) { Join-Path $unityManagedRoot 'UnityEngine.dll' } else { $null }
$unityEditorPath = if ($null -ne $unityManagedRoot) { Join-Path $unityManagedRoot 'UnityEditor.dll' } else { $null }

$unsupportedReasons = [System.Collections.Generic.List[string]]::new()
if ($null -eq $dotnet) {
    $unsupportedReasons.Add('dotnet command is not available.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace($cscPath) -or -not (Test-Path -LiteralPath $cscPath -PathType Leaf)) {
    $unsupportedReasons.Add('Roslyn csc.dll was not found in the installed .NET SDK.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace($netRefPath) -or -not (Test-Path -LiteralPath $netRefPath -PathType Container)) {
    $unsupportedReasons.Add('Microsoft.NETCore.App.Ref net8.0 reference assemblies were not found.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace($unityEnginePath) -or -not (Test-Path -LiteralPath $unityEnginePath -PathType Leaf)) {
    $unsupportedReasons.Add('UnityEngine.dll facade reference was not found.') | Out-Null
}
if ([string]::IsNullOrWhiteSpace($unityEditorPath) -or -not (Test-Path -LiteralPath $unityEditorPath -PathType Leaf)) {
    $unsupportedReasons.Add('UnityEditor.dll reference was not found.') | Out-Null
}

$status = 'PreflightInputFailed'
$exitCode = $null
$compilerOutput = @()
if ($issues.Count -eq 0 -and $unsupportedReasons.Count -gt 0) {
    $status = 'PreflightUnsupported'
    $compilerOutput = @($unsupportedReasons)
} elseif ($issues.Count -eq 0) {
    $netRefs = Get-ChildItem -LiteralPath $netRefPath -Filter '*.dll' | ForEach-Object { '-r:' + $_.FullName }
    $unityRefs = @(
        ('-r:' + $unityEnginePath),
        ('-r:' + $unityEditorPath)
    )

    $compilerArgs = @(
        $cscPath,
        '-nologo',
        '-nostdlib',
        '-target:library',
        '-langversion:latest',
        ('-out:' + $outputAssemblyPath)
    ) + $netRefs + $unityRefs + @($resolvedScripts)

    $compilerOutput = @(& $dotnet.Source @compilerArgs 2>&1 | ForEach-Object { [string]$_ })
    $exitCode = $LASTEXITCODE
    $status = if ($exitCode -eq 0) { 'CompilePassed' } else { 'CompileFailed' }
    if ($status -eq 'CompileFailed') {
        $issues.Add("Unity editor script compile preflight failed with exit code $exitCode.") | Out-Null
    }
}

$warningCount = @($compilerOutput | Where-Object { $_ -match 'warning CS\d+' }).Count
$errorCount = @($compilerOutput | Where-Object { $_ -match 'error CS\d+' }).Count
$compilerOutput | Set-Content -LiteralPath $outputTextPath -Encoding UTF8

$summary = [PSCustomObject]@{
    generatedAt = (Get-Date).ToString('O')
    validationRoot = $ValidationRoot
    status = $status
    scriptCount = $resolvedScripts.Count
    scripts = @($resolvedScripts)
    missingInputs = @($missingInputs)
    allStellaGaiaScripts = [bool]$AllStellaGaiaScripts
    dotnet = if ($null -ne $dotnet) { [string]$dotnet.Source } else { $null }
    csc = $cscPath
    netRefPath = $netRefPath
    unityManagedRoot = $unityManagedRoot
    unityEngine = $unityEnginePath
    unityEditor = $unityEditorPath
    outputAssembly = $outputAssemblyPath
    outputText = $outputTextPath
    summaryJson = $summaryPath
    exitCode = $exitCode
    warningCount = $warningCount
    errorCount = $errorCount
    unsupportedReasons = @($unsupportedReasons)
    issueCount = $issues.Count
    issues = @($issues)
    interpretation = 'This is an offline compile preflight for Unity Editor validation scripts. It is not a Unity import, render, or asset usability pass.'
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary

if (-not $NoThrow -and ($status -eq 'CompileFailed' -or $status -eq 'PreflightInputFailed')) {
    throw "Unity editor script compile preflight failed: $status."
}
