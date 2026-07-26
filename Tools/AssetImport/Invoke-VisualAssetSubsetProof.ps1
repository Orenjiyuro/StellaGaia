[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$worktree = 'C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$unityPath = 'C:\SoftWork\Unity\Editor\Unity.exe'
$windowsSupportRoot = 'C:\SoftWork\Unity\Editor\Data\PlaybackEngines\windowsstandalonesupport'
$scenePath = Join-Path $worktree 'Assets\StellaGaia\Scenes\SampleValidation.unity'
$inputRoot = Join-Path $worktree 'Extracted\DirectCharacterConsumerProof\char_14401\LO-DCP1-A02\Input'
$attemptRoot = Join-Path $worktree 'Extracted\DirectCharacterConsumerProof\char_14401\VASP-LO1-Player'
$buildLogPath = Join-Path $attemptRoot 'unity-build.log'
$buildResultPath = Join-Path $attemptRoot 'build-result.json'
$playerPath = Join-Path $attemptRoot 'Build\VisualAssetSubsetProof.exe'
$playerOutputRoot = Join-Path $attemptRoot 'Player'
$playerLogPath = Join-Path $playerOutputRoot 'player.log'
$terminalPath = Join-Path $playerOutputRoot 'terminal-result.json'
$orchestrationResultPath = Join-Path $attemptRoot 'orchestration-result.json'
$buildTimeoutMilliseconds = 1200000
$playerTimeoutMilliseconds = 1200000

$result = [ordered]@{
    schemaVersion = 'visual-subset-orchestration/1.0.0'
    status = 'Running'
    stage = 'Preflight'
    processStartCount = 0
    unityBuildProcessStartCount = 0
    playerProcessStartCount = 0
    unityBuildExitCode = $null
    playerExitCode = $null
    unityBuildTimedOut = $false
    playerTimedOut = $false
    buildResultStatus = $null
    playerTerminalStatus = $null
    playerTerminalSha256 = $null
    exceptionType = $null
    exceptionMessage = $null
    nextAction = 'AwaitVASPFinalAudit'
}

function Write-OrchestrationResult {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Value)

    $json = $Value | ConvertTo-Json -Depth 8
    $bytes = [System.Text.UTF8Encoding]::new($false, $true).GetBytes($json)
    $stream = [System.IO.FileStream]::new(
        $orchestrationResultPath,
        [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::Write,
        [System.IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

try {
    if (-not [System.IO.File]::Exists($unityPath)) {
        throw 'Unity executable is missing.'
    }
    if (-not [System.IO.Directory]::Exists($windowsSupportRoot)) {
        throw 'Windows Standalone Build Support is missing.'
    }
    if (-not [System.IO.File]::Exists($scenePath)) {
        throw 'Fixed SampleValidation scene is missing.'
    }
    $unity = Get-Item -LiteralPath $unityPath
    if ($unity.VersionInfo.ProductVersion -ne '2022.3.62f2_7670c08855a9') {
        throw "Unity version mismatch: $($unity.VersionInfo.ProductVersion)"
    }
    if (-not [System.IO.Directory]::Exists($inputRoot)) {
        throw 'Authorized A02 input root is missing.'
    }
    if ([System.IO.Directory]::Exists($attemptRoot) -or
        [System.IO.File]::Exists($attemptRoot)) {
        throw 'VASP-LO1-Player attempt root already exists.'
    }
    $active = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq 'Unity' -or
        $_.ProcessName -eq 'VisualAssetSubsetProof' -or
        $_.ProcessName -like 'AssetRipper*'
    })
    if ($active.Count -ne 0) {
        throw 'A forbidden production process is already active.'
    }

    [System.IO.Directory]::CreateDirectory($attemptRoot) | Out-Null
    $result.stage = 'UnityPlayerBuild'
    $buildStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $buildStartInfo.FileName = $unityPath
    $buildStartInfo.UseShellExecute = $false
    $buildStartInfo.CreateNoWindow = $true
    $buildStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $buildStartInfo.ArgumentList.Add('-batchmode')
    $buildStartInfo.ArgumentList.Add('-quit')
    $buildStartInfo.ArgumentList.Add('-projectPath')
    $buildStartInfo.ArgumentList.Add($worktree)
    $buildStartInfo.ArgumentList.Add('-executeMethod')
    $buildStartInfo.ArgumentList.Add(
        'StellaGaia.Editor.VisualAssetSubsetProofBuilder.Build')
    $buildStartInfo.ArgumentList.Add('-logFile')
    $buildStartInfo.ArgumentList.Add($buildLogPath)
    $buildProcess = [System.Diagnostics.Process]::new()
    $buildProcess.StartInfo = $buildStartInfo
    if (-not $buildProcess.Start()) {
        throw 'Unity build process did not start.'
    }
    $result.processStartCount++
    $result.unityBuildProcessStartCount++
    if (-not $buildProcess.WaitForExit($buildTimeoutMilliseconds)) {
        $result.unityBuildTimedOut = $true
        $buildProcess.Kill($true)
        $buildProcess.WaitForExit()
    }
    $result.unityBuildExitCode = $buildProcess.ExitCode
    if ($result.unityBuildTimedOut -or
        $result.unityBuildExitCode -ne 0 -or
        -not [System.IO.File]::Exists($buildResultPath)) {
        throw 'Unity Player build failed or timed out.'
    }
    $buildResult = Get-Content -LiteralPath $buildResultPath -Raw |
        ConvertFrom-Json
    $result.buildResultStatus = $buildResult.status
    if ($buildResult.status -ne 'Passed' -or
        -not [System.IO.File]::Exists($playerPath)) {
        throw 'Builder did not publish a valid generated Player.'
    }

    [System.IO.Directory]::CreateDirectory($playerOutputRoot) | Out-Null
    $result.stage = 'GeneratedPlayerRun'
    $playerStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $playerStartInfo.FileName = $playerPath
    $playerStartInfo.UseShellExecute = $false
    $playerStartInfo.CreateNoWindow = $true
    $playerStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
    $playerStartInfo.Environment['STELLAGAIA_VASP_PLAYER_INPUT_ROOT'] =
        $inputRoot
    $playerStartInfo.Environment['STELLAGAIA_VASP_PLAYER_OUTPUT_ROOT'] =
        $playerOutputRoot
    $playerStartInfo.ArgumentList.Add('-batchmode')
    $playerStartInfo.ArgumentList.Add('-logFile')
    $playerStartInfo.ArgumentList.Add($playerLogPath)
    $playerProcess = [System.Diagnostics.Process]::new()
    $playerProcess.StartInfo = $playerStartInfo
    if (-not $playerProcess.Start()) {
        throw 'Generated Player process did not start.'
    }
    $result.processStartCount++
    $result.playerProcessStartCount++
    if (-not $playerProcess.WaitForExit($playerTimeoutMilliseconds)) {
        $result.playerTimedOut = $true
        $playerProcess.Kill($true)
        $playerProcess.WaitForExit()
    }
    $result.playerExitCode = $playerProcess.ExitCode
    if ($result.playerTimedOut -or
        -not [System.IO.File]::Exists($terminalPath)) {
        throw 'Generated Player failed to publish terminal evidence.'
    }
    $terminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json
    $result.playerTerminalStatus = $terminal.status
    $result.playerTerminalSha256 = (
        Get-FileHash -LiteralPath $terminalPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($result.playerExitCode -ne 0 -or $terminal.status -ne 'Passed') {
        throw 'Generated Player consumer proof failed.'
    }
    $result.status = 'Passed'
    $result.stage = 'Completed'
}
catch {
    $result.status = 'Failed'
    $result.exceptionType = $_.Exception.GetType().FullName
    $result.exceptionMessage = $_.Exception.Message
}
finally {
    if ([System.IO.Directory]::Exists($attemptRoot)) {
        try {
            Write-OrchestrationResult -Value $result
        }
        catch {
            [Console]::Error.WriteLine(
                "Failed to publish orchestration result: $($_.Exception.Message)")
        }
    }
}

$result | ConvertTo-Json -Depth 8
if ($result.status -ne 'Passed') {
    exit 1
}
exit 0
