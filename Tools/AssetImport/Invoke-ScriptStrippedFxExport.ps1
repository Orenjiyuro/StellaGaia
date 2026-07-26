[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function New-SfxrContract {
    $members = @(
        [pscustomobject][ordered]@{ ordinal = 1; relativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; length = [int64]4909859; sha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' },
        [pscustomobject][ordered]@{ ordinal = 2; relativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; length = [int64]6682; sha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' },
        [pscustomobject][ordered]@{ ordinal = 3; relativePath = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; length = [int64]3080984; sha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' },
        [pscustomobject][ordered]@{ ordinal = 4; relativePath = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; length = [int64]37819874; sha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' },
        [pscustomobject][ordered]@{ ordinal = 5; relativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'; length = [int64]11641; sha256 = '0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048' },
        [pscustomobject][ordered]@{ ordinal = 6; relativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d'; length = [int64]3576; sha256 = '0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f' },
        [pscustomobject][ordered]@{ ordinal = 7; relativePath = 'Persistent_Store/AssetBundles/char_14401_fx.unity3d'; length = [int64]1944422; sha256 = '02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab' }
    )

    return [pscustomobject][ordered]@{
        schemaVersion = 'sfxr-script-stripped-export/1.0.0'
        artifactId = 'SFXR-LO1-char_14401'
        inputPortablePath = 'Extracted\DirectCharacterConsumerProof\char_14401\LO-DCP1-A02\Input'
        outputPortablePath = 'Extracted\ScriptStrippedFxReconstruction\char_14401\LO1'
        toolManifestPortablePath = 'Tools\AssetImport\tool-manifest.json'
        toolManifestSha256 = '24e973ded1f9d7c97b8334c82b82e69d6dc227798441d9ffa43bb4a80ec070f9'
        assetRipperLeafName = 'AssetRipper.GUI.Free.exe'
        assetRipperProductName = 'AssetRipper.GUI.Free'
        assetRipperVersion = '1.3.14.0'
        assetRipperLength = [int64]124776960
        assetRipperSha256 = '11ec892dcd70b1b86f2e52db631e83e007f6103daa20a9616ecaa7a95baa9f21'
        assetRipperPort = 17777
        startupTimeoutMilliseconds = [int64]60000
        loadTimeoutMilliseconds = [int64]600000
        exportTimeoutMilliseconds = [int64]1200000
        overallTimeoutMilliseconds = [int64]1800000
        members = $members
    }
}

function Stop-Sfxr {
    param([Parameter(Mandatory)][string] $Code)
    throw [InvalidOperationException]::new("SFXR:$Code")
}

function Get-SfxrSha256 {
    param([Parameter(Mandatory)][string] $LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-SfxrCanonicalPath {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][ValidateSet('File', 'Directory')][string] $LeafKind
    )

    if (
        [string]::IsNullOrWhiteSpace($LiteralPath) -or
        -not [IO.Path]::IsPathFullyQualified($LiteralPath) -or
        $LiteralPath -match '^[\\/]{2}'
    ) {
        Stop-Sfxr 'UnsafeLocalPath'
    }

    $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction SilentlyContinue
    if (
        $null -eq $item -or
        ($LeafKind -eq 'File' -and $item -isnot [IO.FileInfo]) -or
        ($LeafKind -eq 'Directory' -and $item -isnot [IO.DirectoryInfo])
    ) {
        Stop-Sfxr "Expected$LeafKind"
    }

    return $item.FullName
}

function Assert-SfxrNoReparseChain {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][ValidateSet('File', 'Directory')][string] $LeafKind,
        [string] $RequiredRoot
    )

    $full = Get-SfxrCanonicalPath -LiteralPath $LiteralPath -LeafKind $LeafKind
    $root = if ([string]::IsNullOrWhiteSpace($RequiredRoot)) {
        [IO.Path]::GetPathRoot($full)
    } else {
        Get-SfxrCanonicalPath -LiteralPath $RequiredRoot -LeafKind Directory
    }
    if (
        -not $full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -and
        -not $full.StartsWith($root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)
    ) {
        Stop-Sfxr 'PathOutsideRequiredRoot'
    }

    $cursor = $full
    while ($true) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Sfxr 'ReparsePointDetected'
        }
        if ($cursor.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) {
            Stop-Sfxr 'PathChainFailure'
        }
        $cursor = $parent.FullName
    }

    return $full
}

function Assert-SfxrProspectivePath {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][string] $RequiredRoot
    )

    $root = Get-SfxrCanonicalPath -LiteralPath $RequiredRoot -LeafKind Directory
    $candidate = [IO.Path]::GetFullPath($LiteralPath)
    if (-not $candidate.StartsWith($root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        Stop-Sfxr 'OutputOutsideWorktree'
    }
    $relative = [IO.Path]::GetRelativePath($root, $candidate)
    $cursor = $root
    foreach ($segment in $relative.Split([char[]]@([char]92, [char]47), [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $segment
        if (-not (Test-Path -LiteralPath $cursor)) {
            break
        }
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Sfxr 'OutputPathContainsReparsePoint'
        }
    }
}

function Test-SfxrPe {
    param([Parameter(Mandatory)][string] $LiteralPath)

    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $header = [byte[]]::new(512)
        $used = $stream.Read($header, 0, $header.Length)
        if ($used -lt 64 -or $header[0] -ne 0x4d -or $header[1] -ne 0x5a) {
            return $false
        }
        $peOffset = [BitConverter]::ToInt32($header, 60)
        return (
            $peOffset -ge 0 -and
            ($peOffset + 4) -le $used -and
            $header[$peOffset] -eq 0x50 -and
            $header[$peOffset + 1] -eq 0x45 -and
            $header[$peOffset + 2] -eq 0 -and
            $header[$peOffset + 3] -eq 0
        )
    } finally {
        $stream.Dispose()
    }
}

function Get-SfxrFileState {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][object] $Member
    )

    $item = Get-Item -LiteralPath $LiteralPath -Force
    return [pscustomobject][ordered]@{
        ordinal = [int]$Member.ordinal
        relativePath = [string]$Member.relativePath
        length = [int64]$item.Length
        sha256 = Get-SfxrSha256 -LiteralPath $item.FullName
        lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
        attributes = $item.Attributes.ToString()
    }
}

function Test-SfxrStateEqual {
    param(
        [Parameter(Mandatory)][object] $Left,
        [Parameter(Mandatory)][object] $Right
    )

    return (
        [int64]$Left.length -eq [int64]$Right.length -and
        [string]$Left.sha256 -ceq [string]$Right.sha256 -and
        [string]$Left.lastWriteTimeUtc -ceq [string]$Right.lastWriteTimeUtc -and
        [string]$Left.attributes -ceq [string]$Right.attributes
    )
}

function Assert-SfxrNoRelatedProcesses {
    $related = @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProcessName -like 'AssetRipper*' -or
                $_.ProcessName -in @('Unity', 'UnityShaderCompiler', 'UnityCrashHandler64')
            }
    )
    if ($related.Count -ne 0) {
        Stop-Sfxr 'RelatedProcessAlreadyRunning'
    }
}

function Test-SfxrPortFree {
    param([Parameter(Mandatory)][int] $Port)
    return @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count -eq 0
}

function Test-SfxrListenerOwned {
    param(
        [Parameter(Mandatory)][int] $Port,
        [Parameter(Mandatory)][int] $ProcessId
    )

    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    return $listeners.Count -eq 1 -and [int]$listeners[0].OwningProcess -eq $ProcessId
}

function ConvertTo-SfxrWindowsArgument {
    param([Parameter(Mandatory)][AllowEmptyString()][string] $Value)

    if ($Value -notmatch '[\s"]') {
        return $Value
    }

    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') {
            $backslashCount++
            continue
        }
        if ($character -eq '"') {
            [void]$builder.Append('\', ($backslashCount * 2) + 1)
            [void]$builder.Append('"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append('\', $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount -gt 0) {
        [void]$builder.Append('\', $backslashCount * 2)
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Join-SfxrWindowsArguments {
    param([Parameter(Mandatory)][string[]] $Values)
    return (($Values | ForEach-Object { ConvertTo-SfxrWindowsArgument -Value $_ }) -join ' ')
}

function Stop-SfxrProcessTree {
    param([Parameter(Mandatory)][int] $RootProcessId)

    $all = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $childrenByParent = @{}
    foreach ($item in $all) {
        $parentId = [int]$item.ParentProcessId
        if (-not $childrenByParent.ContainsKey($parentId)) {
            $childrenByParent[$parentId] = [Collections.Generic.List[int]]::new()
        }
        $childrenByParent[$parentId].Add([int]$item.ProcessId)
    }
    $ordered = [Collections.Generic.List[int]]::new()
    $visit = $null
    $visit = {
        param([int] $Id)
        if ($childrenByParent.ContainsKey($Id)) {
            foreach ($childId in $childrenByParent[$Id]) {
                & $visit $childId
            }
        }
        $ordered.Add($Id)
    }
    & $visit $RootProcessId
    foreach ($id in $ordered) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    }
}

function Get-SfxrRemainingTimeoutSeconds {
    param(
        [Parameter(Mandatory)][Diagnostics.Stopwatch] $Stopwatch,
        [Parameter(Mandatory)][int64] $OverallTimeoutMilliseconds,
        [Parameter(Mandatory)][int64] $StageTimeoutMilliseconds
    )

    $remaining = $OverallTimeoutMilliseconds - $Stopwatch.ElapsedMilliseconds
    if ($remaining -le 0) {
        Stop-Sfxr 'OverallTimeout'
    }
    return [Math]::Max(1, [int][Math]::Ceiling(([Math]::Min($remaining, $StageTimeoutMilliseconds)) / 1000.0))
}

function Get-SfxrExtensionDistribution {
    param([Parameter(Mandatory)][string] $Root)

    $files = @()
    if (Test-Path -LiteralPath $Root -PathType Container) {
        $files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force)
    }
    foreach ($file in $files) {
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Sfxr 'ExportContainsReparsePoint'
        }
    }
    $rows = @(
        $files |
            Group-Object { if ([string]::IsNullOrWhiteSpace($_.Extension)) { '<none>' } else { $_.Extension.ToLowerInvariant() } } |
            Sort-Object Name |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    extension = [string]$_.Name
                    count = [int]$_.Count
                    bytes = [int64](($_.Group | Measure-Object Length -Sum).Sum)
                }
            }
    )
    return [pscustomobject]@{
        files = $files
        rows = $rows
        count = [int]$files.Count
        bytes = [int64](($files | Measure-Object Length -Sum).Sum)
    }
}

function Write-SfxrTerminal {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][object] $Terminal,
        [Parameter(Mandatory)][string] $PrivateInputRoot,
        [Parameter(Mandatory)][string] $PrivateToolPath
    )

    $json = $Terminal | ConvertTo-Json -Depth 100
    $leakCount = [regex]::Matches($json, '(?i)(?:[A-Z]:[\\/]|[\\/]{2}[^\\/])').Count
    if ($json.Contains($PrivateInputRoot, [StringComparison]::OrdinalIgnoreCase)) {
        $leakCount++
    }
    if ($json.Contains($PrivateToolPath, [StringComparison]::OrdinalIgnoreCase)) {
        $leakCount++
    }
    if ($leakCount -ne 0) {
        Stop-Sfxr 'PortableResultPathLeak'
    }

    $Terminal.sourcePathLeakCount = 0
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes(($Terminal | ConvertTo-Json -Depth 100) + [Environment]::NewLine)
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

$contract = New-SfxrContract
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$inputRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $contract.inputPortablePath))
$attemptRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot $contract.outputPortablePath))
$toolManifestPath = [IO.Path]::GetFullPath((Join-Path $repoRoot $contract.toolManifestPortablePath))
$stagingRoot = Join-Path $attemptRoot 'Input'
$exportRoot = Join-Path $attemptRoot 'Export'
$logsRoot = Join-Path $attemptRoot 'Logs'
$processLogPath = Join-Path $logsRoot 'assetripper.log'
$terminalPath = Join-Path $attemptRoot 'terminal-result.json'

$attemptCreated = $false
$process = $null
$processStartCount = 0
$assetRipperExitCode = $null
$timedOut = $false
$listenerOwned = $false
$listenerAbsentAfterShutdown = $null
$relatedProcessCountAfterShutdown = $null
$loadHttpStatus = $null
$exportHttpStatus = $null
$inputUnchanged = $false
$preStates = @()
$failureCode = $null
$failureStage = $null
$exceptionType = $null
$stopwatch = [Diagnostics.Stopwatch]::new()
$stage = 'Preflight'
$assetRipperPath = ''

try {
    if (Test-Path -LiteralPath $attemptRoot) {
        Stop-Sfxr 'AttemptRootAlreadyExists'
    }
    Assert-SfxrProspectivePath -LiteralPath $attemptRoot -RequiredRoot $repoRoot
    $inputRoot = Assert-SfxrNoReparseChain -LiteralPath $inputRoot -LeafKind Directory -RequiredRoot $repoRoot
    $toolManifestPath = Assert-SfxrNoReparseChain -LiteralPath $toolManifestPath -LeafKind File -RequiredRoot $repoRoot
    if ((Get-SfxrSha256 -LiteralPath $toolManifestPath) -cne $contract.toolManifestSha256) {
        Stop-Sfxr 'ToolManifestIdentityMismatch'
    }

    $manifest = [IO.File]::ReadAllText($toolManifestPath) | ConvertFrom-Json -Depth 20
    if (
        [string]::IsNullOrWhiteSpace([string]$manifest.assetRipper) -or
        [int]$manifest.assetRipperPort -ne [int]$contract.assetRipperPort
    ) {
        Stop-Sfxr 'ToolManifestContractMismatch'
    }
    $assetRipperPath = Assert-SfxrNoReparseChain -LiteralPath ([string]$manifest.assetRipper) -LeafKind File
    $tool = Get-Item -LiteralPath $assetRipperPath -Force
    if (
        $tool.Name -cne $contract.assetRipperLeafName -or
        $tool.VersionInfo.ProductName -cne $contract.assetRipperProductName -or
        $tool.VersionInfo.FileVersion -cne $contract.assetRipperVersion -or
        [int64]$tool.Length -ne [int64]$contract.assetRipperLength -or
        (Get-SfxrSha256 -LiteralPath $assetRipperPath) -cne $contract.assetRipperSha256 -or
        -not (Test-SfxrPe -LiteralPath $assetRipperPath)
    ) {
        Stop-Sfxr 'AssetRipperIdentityMismatch'
    }

    Assert-SfxrNoRelatedProcesses
    if (-not (Test-SfxrPortFree -Port $contract.assetRipperPort)) {
        Stop-Sfxr 'AssetRipperPortOccupied'
    }

    foreach ($member in $contract.members) {
        $memberPath = [IO.Path]::GetFullPath((Join-Path $inputRoot $member.relativePath))
        $memberPath = Assert-SfxrNoReparseChain -LiteralPath $memberPath -LeafKind File -RequiredRoot $inputRoot
        $state = Get-SfxrFileState -LiteralPath $memberPath -Member $member
        if ([int64]$state.length -ne [int64]$member.length -or [string]$state.sha256 -cne [string]$member.sha256) {
            Stop-Sfxr 'InputIdentityMismatch'
        }
        $preStates += $state
    }
    if ($preStates.Count -ne 7) {
        Stop-Sfxr 'InputAccountingMismatch'
    }

    [void][IO.Directory]::CreateDirectory($attemptRoot)
    $attemptCreated = $true
    [void][IO.Directory]::CreateDirectory($stagingRoot)
    [void][IO.Directory]::CreateDirectory($exportRoot)
    [void][IO.Directory]::CreateDirectory($logsRoot)
    [void](Assert-SfxrNoReparseChain -LiteralPath $attemptRoot -LeafKind Directory -RequiredRoot $repoRoot)
    [void](Assert-SfxrNoReparseChain -LiteralPath $stagingRoot -LeafKind Directory -RequiredRoot $attemptRoot)
    [void](Assert-SfxrNoReparseChain -LiteralPath $exportRoot -LeafKind Directory -RequiredRoot $attemptRoot)
    [void](Assert-SfxrNoReparseChain -LiteralPath $logsRoot -LeafKind Directory -RequiredRoot $attemptRoot)

    $stage = 'Staging'
    foreach ($member in $contract.members) {
        $sourcePath = Join-Path $inputRoot $member.relativePath
        $destinationPath = Join-Path $stagingRoot ([IO.Path]::GetFileName($member.relativePath))
        [IO.File]::Copy($sourcePath, $destinationPath, $false)
        $destination = Get-Item -LiteralPath $destinationPath -Force
        if (
            [int64]$destination.Length -ne [int64]$member.length -or
            (Get-SfxrSha256 -LiteralPath $destinationPath) -cne [string]$member.sha256
        ) {
            Stop-Sfxr 'StagingIdentityMismatch'
        }
    }

    $stage = 'ProcessStart'
    $arguments = Join-SfxrWindowsArguments -Values @(
        '--headless=true',
        '--port',
        [string]$contract.assetRipperPort,
        '--log=true',
        '--log-path',
        $processLogPath
    )
    $stopwatch.Start()
    $process = Start-Process -FilePath $assetRipperPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if ($null -eq $process) {
        Stop-Sfxr 'AssetRipperStartFailure'
    }
    $processStartCount++

    $stage = 'Startup'
    $startupDeadline = [DateTime]::UtcNow.AddMilliseconds($contract.startupTimeoutMilliseconds)
    while ([DateTime]::UtcNow -lt $startupDeadline) {
        if ($stopwatch.ElapsedMilliseconds -ge $contract.overallTimeoutMilliseconds) {
            $timedOut = $true
            Stop-Sfxr 'OverallTimeout'
        }
        $process.Refresh()
        if ($process.HasExited) {
            $assetRipperExitCode = $process.ExitCode
            Stop-Sfxr 'AssetRipperExitedBeforeListener'
        }
        if (Test-SfxrListenerOwned -Port $contract.assetRipperPort -ProcessId $process.Id) {
            $listenerOwned = $true
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $listenerOwned) {
        $timedOut = $true
        Stop-Sfxr 'StartupTimeout'
    }

    $baseUrl = "http://127.0.0.1:$($contract.assetRipperPort)"
    $stage = 'Load'
    try {
        $loadResponse = Invoke-WebRequest `
            -Uri "$baseUrl/LoadFolder" `
            -Method Post `
            -Body @{ Path = $stagingRoot } `
            -UseBasicParsing `
            -TimeoutSec (Get-SfxrRemainingTimeoutSeconds -Stopwatch $stopwatch -OverallTimeoutMilliseconds $contract.overallTimeoutMilliseconds -StageTimeoutMilliseconds $contract.loadTimeoutMilliseconds)
        $loadHttpStatus = [int]$loadResponse.StatusCode
        if ($loadHttpStatus -lt 200 -or $loadHttpStatus -ge 300) {
            Stop-Sfxr 'LoadHttpFailure'
        }
    } catch {
        if ($_.Exception.Message -like 'SFXR:*') { throw }
        if ($_.Exception -is [TimeoutException] -or $_.Exception.Message -match '(?i)timed out|timeout') {
            $timedOut = $true
            Stop-Sfxr 'LoadTimeout'
        }
        if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
            $loadHttpStatus = [int]$_.Exception.Response.StatusCode
        }
        Stop-Sfxr 'LoadHttpFailure'
    }

    $stage = 'Export'
    try {
        $exportResponse = Invoke-WebRequest `
            -Uri "$baseUrl/Export/UnityProject" `
            -Method Post `
            -Body @{ Path = $exportRoot; CreateSubfolder = 'false' } `
            -UseBasicParsing `
            -TimeoutSec (Get-SfxrRemainingTimeoutSeconds -Stopwatch $stopwatch -OverallTimeoutMilliseconds $contract.overallTimeoutMilliseconds -StageTimeoutMilliseconds $contract.exportTimeoutMilliseconds)
        $exportHttpStatus = [int]$exportResponse.StatusCode
        if ($exportHttpStatus -lt 200 -or $exportHttpStatus -ge 300) {
            Stop-Sfxr 'ExportHttpFailure'
        }
    } catch {
        if ($_.Exception.Message -like 'SFXR:*') { throw }
        if ($_.Exception -is [TimeoutException] -or $_.Exception.Message -match '(?i)timed out|timeout') {
            $timedOut = $true
            Stop-Sfxr 'ExportTimeout'
        }
        if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
            $exportHttpStatus = [int]$_.Exception.Response.StatusCode
        }
        Stop-Sfxr 'ExportHttpFailure'
    }
} catch {
    $failureStage = $stage
    $exceptionType = $_.Exception.GetType().FullName
    $message = $_.Exception.Message
    $failureCode = if ($message.StartsWith('SFXR:', [StringComparison]::Ordinal)) {
        $message.Substring(5)
    } else {
        'UnclassifiedRunnerFailure'
    }
} finally {
    if ($null -ne $process) {
        Stop-SfxrProcessTree -RootProcessId $process.Id
        [void]$process.WaitForExit(10000)
        $process.Refresh()
        if ($process.HasExited) {
            $assetRipperExitCode = $process.ExitCode
        }
    }
    $listenerAbsentAfterShutdown = Test-SfxrPortFree -Port $contract.assetRipperPort
    $relatedProcessCountAfterShutdown = @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProcessName -like 'AssetRipper*' -or
                $_.ProcessName -in @('Unity', 'UnityShaderCompiler', 'UnityCrashHandler64')
            }
    ).Count
    if ($stopwatch.IsRunning) {
        $stopwatch.Stop()
    }
}

if (-not $attemptCreated) {
    if ([string]::IsNullOrWhiteSpace($failureCode)) {
        $failureCode = 'PreflightFailure'
    }
    Write-Error "SFXR preflight stopped safely: $failureCode"
    exit 1
}

$postStates = @()
try {
    foreach ($member in $contract.members) {
        $memberPath = Join-Path $inputRoot $member.relativePath
        $postStates += Get-SfxrFileState -LiteralPath $memberPath -Member $member
    }
    $inputUnchanged = $postStates.Count -eq $preStates.Count
    for ($index = 0; $inputUnchanged -and $index -lt $preStates.Count; $index++) {
        if (-not (Test-SfxrStateEqual -Left $preStates[$index] -Right $postStates[$index])) {
            $inputUnchanged = $false
        }
    }
} catch {
    $inputUnchanged = $false
    if ([string]::IsNullOrWhiteSpace($failureCode)) {
        $failureCode = 'PostInputIdentityFailure'
        $failureStage = 'PostInputIdentity'
        $exceptionType = $_.Exception.GetType().FullName
    }
}
if (-not $inputUnchanged -and [string]::IsNullOrWhiteSpace($failureCode)) {
    $failureCode = 'InputChangedDuringOperation'
    $failureStage = 'PostInputIdentity'
    $exceptionType = 'System.IO.IOException'
}
if (
    ($listenerAbsentAfterShutdown -eq $false -or [int]$relatedProcessCountAfterShutdown -ne 0) -and
    [string]::IsNullOrWhiteSpace($failureCode)
) {
    $failureCode = 'CleanupIncomplete'
    $failureStage = 'Cleanup'
    $exceptionType = 'System.InvalidOperationException'
}

$stage = 'EvidenceCollection'
$exportSummary = [pscustomobject]@{ files = @(); rows = @(); count = 0; bytes = [int64]0 }
$logText = ''
try {
    $exportSummary = Get-SfxrExtensionDistribution -Root $exportRoot
    $logText = if (Test-Path -LiteralPath $processLogPath -PathType Leaf) {
        [IO.File]::ReadAllText($processLogPath)
    } else {
        ''
    }
} catch {
    if ([string]::IsNullOrWhiteSpace($failureCode)) {
        $failureCode = 'EvidenceCollectionFailure'
        $failureStage = 'EvidenceCollection'
        $exceptionType = $_.Exception.GetType().FullName
    }
}
$warningCount = [regex]::Matches($logText, '(?im)\bwarn(?:ing)?\b').Count
$missingDependencyWarningCount = [regex]::Matches($logText, "(?im)dependency .*wasn't found|missing dependenc").Count
$missingNames = @(
    [regex]::Matches($logText, 'CAB-[0-9a-fA-F]{32}') |
        ForEach-Object { $_.Value.ToLowerInvariant() } |
        Sort-Object -Unique
)
$scriptDeserializationIssueCount = [regex]::Matches(
    $logText,
    '(?im)(failed|error|unable).{0,120}(script|monobehaviour|deserialize|type tree)|(script|monobehaviour|deserialize|type tree).{0,120}(failed|error|unable)'
).Count

$status = 'Failed'
$classification = if ([string]::IsNullOrWhiteSpace($failureCode)) {
    if ($exportSummary.count -eq 0) {
        $failureCode = 'EmptyExport'
        $failureStage = 'EvidenceCollection'
        'Failed'
    } elseif ($warningCount -gt 0 -or $missingDependencyWarningCount -gt 0 -or $scriptDeserializationIssueCount -gt 0) {
        $status = 'ExportedWithDiagnostics'
        'ExportedWithDiagnostics'
    } else {
        $status = 'Exported'
        'Exported'
    }
} else {
    $failureCode
}

$terminal = [pscustomobject][ordered]@{
    schemaVersion = $contract.schemaVersion
    artifactId = $contract.artifactId
    status = $status
    classification = $classification
    stage = 'TerminalWrite'
    failureStage = $failureStage
    failureCode = $failureCode
    exceptionType = $exceptionType
    exceptionMessage = $failureCode
    processStartCount = $processStartCount
    assetRipperExitCode = $assetRipperExitCode
    timedOut = $timedOut
    durationMilliseconds = [int64]$stopwatch.ElapsedMilliseconds
    listenerOwned = $listenerOwned
    listenerAbsentAfterShutdown = $listenerAbsentAfterShutdown
    relatedProcessCountAfterShutdown = $relatedProcessCountAfterShutdown
    loadHttpStatus = $loadHttpStatus
    exportHttpStatus = $exportHttpStatus
    toolManifestSha256 = $contract.toolManifestSha256
    assetRipperSha256 = $contract.assetRipperSha256
    inputMemberCount = [int]$preStates.Count
    inputTotalBytes = [int64](($preStates | Measure-Object length -Sum).Sum)
    inputResults = @($preStates | Select-Object ordinal, relativePath, length, sha256, lastWriteTimeUtc, attributes)
    inputUnchanged = $inputUnchanged
    exportFileCount = [int]$exportSummary.count
    exportTotalBytes = [int64]$exportSummary.bytes
    extensionDistribution = @($exportSummary.rows)
    warningCount = [int]$warningCount
    missingDependencyWarningCount = [int]$missingDependencyWarningCount
    uniqueMissingDependencyCount = [int]$missingNames.Count
    scriptDeserializationIssueCount = [int]$scriptDeserializationIssueCount
    processLogRelativePath = 'Logs/assetripper.log'
    exportedScriptsExecuted = $false
    exportedProjectLaunched = $false
    sourcePathLeakCount = 0
    nextAction = 'AwaitSFXRLO1Audit'
}

Write-SfxrTerminal `
    -LiteralPath $terminalPath `
    -Terminal $terminal `
    -PrivateInputRoot $inputRoot `
    -PrivateToolPath $assetRipperPath

$terminal | ConvertTo-Json -Depth 100
if ($status -eq 'Failed') {
    exit 1
}
exit 0
