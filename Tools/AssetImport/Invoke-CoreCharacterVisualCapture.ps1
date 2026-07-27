[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$worktree = 'C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$unityPath = 'C:\SoftWork\Unity\Editor\Unity.exe'
$unityLength = [int64]76202416
$unitySha256 = '316507f85aeaedf602966be741e0c2c69d12d44850610fcf3a4ac0a164316ba3'
$inputRoot = Join-Path $worktree 'Extracted\DirectCharacterConsumerProof\char_14401\LO-DCP1-A02\Input'
$attemptRoot = Join-Path $worktree 'Extracted\DirectCharacterConsumerProof\char_14401\CCVC-LO1'
$buildLogPath = Join-Path $attemptRoot 'unity-build.log'
$buildResultPath = Join-Path $attemptRoot 'build-result.json'
$playerPath = Join-Path $attemptRoot 'Build\CoreCharacterVisualCapture.exe'
$playerRoot = Join-Path $attemptRoot 'Player'
$playerLogPath = Join-Path $playerRoot 'player.log'
$terminalPath = Join-Path $playerRoot 'terminal-result.json'
$orchestrationPath = Join-Path $attemptRoot 'orchestration-result.json'
$buildTimeoutMilliseconds = 1200000
$playerTimeoutMilliseconds = 1200000

$coreMembers = @(
    [pscustomobject]@{ RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; Length = [int64]4909859; Sha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' },
    [pscustomobject]@{ RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; Length = [int64]6682; Sha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' },
    [pscustomobject]@{ RelativePath = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; Length = [int64]3080984; Sha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' },
    [pscustomobject]@{ RelativePath = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; Length = [int64]37819874; Sha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' }
)
$deniedBundles = @(
    'char_14401_fx.unity3d',
    'char_14401_buff.unity3d',
    'char_14401_weapons.unity3d'
)

$result = [ordered]@{
    schemaVersion = 'ccvc-orchestration/1.0.0'
    artifactId = 'CCVC-LO1-ORCHESTRATION'
    status = 'Running'
    stage = 'Preflight'
    processStartCount = 0
    unityBuildProcessStartCount = 0
    playerProcessStartCount = 0
    unityBuildExitCode = $null
    playerExitCode = $null
    unityBuildTimedOut = $false
    playerTimedOut = $false
    inputResults = @()
    buildResultStatus = $null
    playerTerminalStatus = $null
    playerTerminalSha256 = $null
    exceptionType = $null
    exceptionMessage = $null
    nextAction = 'CoreVisualFailed'
}

function Test-NoReparsePath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Boundary
    )
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetFullPath($Boundary).TrimEnd('\')
    if (-not ($full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase))) {
        throw 'Core input path escaped its fixed boundary.'
    }
    $current = Get-Item -LiteralPath $full
    while ($null -ne $current) {
        if (($current.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Reparse paths are forbidden.'
        }
        $current = $current.Parent
    }
}

function Write-CreateNewJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Value
    )
    $json = ($Value | ConvertTo-Json -Depth 12) + "`n"
    $bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($json)
    $stream = [IO.FileStream]::new(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function ConvertTo-PortableText {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) {
        return $null
    }
    return $Value.Replace($worktree, '<WORKTREE>').
        Replace($inputRoot, '<INPUT_ROOT>').
        Replace($attemptRoot, '<ATTEMPT_ROOT>')
}

try {
    if ([IO.Directory]::Exists($attemptRoot) -or [IO.File]::Exists($attemptRoot)) {
        throw 'CCVC-LO1 attempt root already exists.'
    }
    if (-not [IO.File]::Exists($unityPath)) {
        throw 'Unity executable is missing.'
    }
    $unity = Get-Item -LiteralPath $unityPath
    if ($unity.Length -ne $unityLength -or
        $unity.VersionInfo.ProductVersion -ne '2022.3.62f2_7670c08855a9' -or
        (Get-FileHash -LiteralPath $unityPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $unitySha256) {
        throw 'Unity executable identity mismatch.'
    }
    if (-not [IO.Directory]::Exists($inputRoot)) {
        throw 'Fixed A02 input root is missing.'
    }
    Test-NoReparsePath -Path $inputRoot -Boundary $inputRoot
    $seen = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase)
    foreach ($member in $coreMembers) {
        if (-not $seen.Add($member.RelativePath)) {
            throw 'Duplicate core input selector.'
        }
        foreach ($denied in $deniedBundles) {
            if ($member.RelativePath.EndsWith($denied, [StringComparison]::OrdinalIgnoreCase)) {
                throw 'Denied FX/buff/weapons bundle entered the core set.'
            }
        }
        $path = Join-Path $inputRoot $member.RelativePath
        if (-not [IO.File]::Exists($path)) {
            throw "Core input is missing: $($member.RelativePath)"
        }
        Test-NoReparsePath -Path $path -Boundary $inputRoot
        $info = Get-Item -LiteralPath $path
        $sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($info.Length -ne $member.Length -or $sha -ne $member.Sha256) {
            throw "Core input identity mismatch: $($member.RelativePath)"
        }
        $result.inputResults += [ordered]@{
            relativePath = $member.RelativePath
            length = $info.Length
            sha256 = $sha
            status = 'Matched'
        }
    }
    $active = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -eq 'Unity' -or
        $_.ProcessName -eq 'CoreCharacterVisualCapture' -or
        $_.ProcessName -like 'AssetRipper*'
    })
    if ($active.Count -ne 0) {
        throw 'A forbidden production process is already active.'
    }

    [IO.Directory]::CreateDirectory($attemptRoot) | Out-Null
    $result.stage = 'UnityPlayerBuild'
    $buildInfo = [Diagnostics.ProcessStartInfo]::new()
    $buildInfo.FileName = $unityPath
    $buildInfo.UseShellExecute = $false
    $buildInfo.CreateNoWindow = $true
    $buildInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    foreach ($argument in @(
        '-batchmode', '-quit', '-projectPath', $worktree,
        '-executeMethod',
        'StellaGaia.Editor.CoreCharacterVisualCaptureBuilder.Build',
        '-logFile', $buildLogPath
    )) {
        $buildInfo.ArgumentList.Add($argument)
    }
    $buildProcess = [Diagnostics.Process]::new()
    $buildProcess.StartInfo = $buildInfo
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
    if ($result.unityBuildTimedOut -or $result.unityBuildExitCode -ne 0 -or
        -not [IO.File]::Exists($buildResultPath)) {
        throw 'Unity Player build failed or timed out.'
    }
    $buildResult = Get-Content -LiteralPath $buildResultPath -Raw |
        ConvertFrom-Json
    $result.buildResultStatus = $buildResult.status
    if ($buildResult.status -ne 'Passed' -or -not [IO.File]::Exists($playerPath)) {
        throw 'Builder did not publish a valid CCVC Player.'
    }

    [IO.Directory]::CreateDirectory($playerRoot) | Out-Null
    $result.stage = 'GeneratedPlayerCapture'
    $playerInfo = [Diagnostics.ProcessStartInfo]::new()
    $playerInfo.FileName = $playerPath
    $playerInfo.UseShellExecute = $false
    $playerInfo.CreateNoWindow = $true
    $playerInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $playerInfo.Environment['STELLAGAIA_CCVC_PLAYER_INPUT_ROOT'] = $inputRoot
    $playerInfo.Environment['STELLAGAIA_CCVC_PLAYER_OUTPUT_ROOT'] = $playerRoot
    foreach ($argument in @('-batchmode', '-logFile', $playerLogPath)) {
        $playerInfo.ArgumentList.Add($argument)
    }
    $playerProcess = [Diagnostics.Process]::new()
    $playerProcess.StartInfo = $playerInfo
    if (-not $playerProcess.Start()) {
        throw 'Generated CCVC Player process did not start.'
    }
    $result.processStartCount++
    $result.playerProcessStartCount++
    if (-not $playerProcess.WaitForExit($playerTimeoutMilliseconds)) {
        $result.playerTimedOut = $true
        $playerProcess.Kill($true)
        $playerProcess.WaitForExit()
    }
    $result.playerExitCode = $playerProcess.ExitCode
    if ($result.playerTimedOut -or -not [IO.File]::Exists($terminalPath)) {
        throw 'CCVC Player did not publish terminal evidence.'
    }
    $terminal = Get-Content -LiteralPath $terminalPath -Raw |
        ConvertFrom-Json
    $result.playerTerminalStatus = $terminal.status
    $result.playerTerminalSha256 = (
        Get-FileHash -LiteralPath $terminalPath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    if ($result.playerExitCode -ne 0 -or $terminal.status -ne 'Passed' -or
        $terminal.nextAction -ne 'AwaitHumanVisualAcceptance') {
        throw 'CCVC Player machine gates failed.'
    }
    $result.status = 'Passed'
    $result.stage = 'Completed'
    $result.nextAction = 'AwaitHumanVisualAcceptance'
}
catch {
    $result.status = 'Failed'
    $result.exceptionType = $_.Exception.GetType().FullName
    $result.exceptionMessage = ConvertTo-PortableText $_.Exception.Message
    $result.nextAction = 'CoreVisualFailed'
}
finally {
    if ([IO.Directory]::Exists($attemptRoot)) {
        try {
            Write-CreateNewJson -Path $orchestrationPath -Value $result
        }
        catch {
            [Console]::Error.WriteLine(
                "CCVC orchestration evidence write failed: $($_.Exception.Message)")
        }
    }
}

$result | ConvertTo-Json -Depth 12
if ($result.status -ne 'Passed') {
    exit 1
}
exit 0
