[CmdletBinding()]
param(
    [string]$ToolManifestPath
)

$ErrorActionPreference = 'Stop'

function Get-CanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-IsPathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CandidatePath,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $candidate = Get-CanonicalPath $CandidatePath
    $root = Get-CanonicalPath $RootPath
    $trimmedCandidate = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    if ([string]::Equals($trimmedCandidate, $trimmedRoot, $comparison)) {
        return $true
    }

    $rootWithSeparator = $trimmedRoot + [System.IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($rootWithSeparator, $comparison)
}

function Assert-PathUnderOrEqual {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-IsPathUnderOrEqual -CandidatePath $Path -RootPath $RootPath)) {
        throw "$Description must stay under $RootPath. Got: $Path"
    }
}

function Assert-NoExistingReparsePointUnderRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    $candidate = Get-CanonicalPath $Path
    $root = Get-CanonicalPath $RootPath
    Assert-PathUnderOrEqual -Path $candidate -RootPath $root -Description $Description

    $comparison = [System.StringComparison]::OrdinalIgnoreCase
    $trimmedRoot = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $trimmedCandidate = $candidate.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)

    $pathsToCheck = @($trimmedRoot)
    if (-not [string]::Equals($trimmedRoot, $trimmedCandidate, $comparison)) {
        $rootWithSeparator = $trimmedRoot + [System.IO.Path]::DirectorySeparatorChar
        $relativePath = $trimmedCandidate.Substring($rootWithSeparator.Length)
        $currentPath = $trimmedRoot
        foreach ($segment in $relativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
            if ([string]::IsNullOrWhiteSpace($segment)) {
                continue
            }

            $currentPath = Join-Path $currentPath $segment
            $pathsToCheck += $currentPath
        }
    }

    foreach ($pathToCheck in $pathsToCheck) {
        if (-not (Test-Path -LiteralPath $pathToCheck)) {
            break
        }

        $item = Get-Item -LiteralPath $pathToCheck -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Description must not include symlinks, junctions, or reparse points. Reparse point: $($item.FullName)"
        }
    }
}

function ConvertTo-TcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        throw "assetRipperPort must be an integer TCP port from 1 through 65535. Got: <null>"
    }

    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int] -or $Value -is [int64]) {
        $port = [int64]$Value
    }
    elseif ($Value -is [string] -and $Value -match '^\d+$') {
        $port = [int64]$Value
    }
    else {
        throw "assetRipperPort must be an integer TCP port from 1 through 65535. Got: $Value"
    }

    if ($port -lt 1 -or $port -gt 65535) {
        throw "assetRipperPort must be an integer TCP port from 1 through 65535. Got: $Value"
    }

    return [int]$port
}

function Get-PortListenerSummary {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) {
        return $null
    }

    return ($listeners | ForEach-Object {
        "PID=$($_.OwningProcess) $($_.LocalAddress):$($_.LocalPort)"
    }) -join '; '
}

function Test-UrlResponds {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
        return $response.StatusCode -ge 100 -and $response.StatusCode -lt 600
    }
    catch {
        return $false
    }
}

function Get-ProcessStatusText {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process
    )

    try {
        $Process.Refresh()
        if ($Process.HasExited) {
            return "exited with code $($Process.ExitCode)"
        }

        return 'running'
    }
    catch {
        return "unknown: $($_.Exception.Message)"
    }
}

function ConvertTo-WindowsProcessArgument {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append('"')
    $backslashCount = 0
    foreach ($character in $Argument.ToCharArray()) {
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

function Join-WindowsProcessArguments {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList
    )

    return (($ArgumentList | ForEach-Object { ConvertTo-WindowsProcessArgument -Argument $_ }) -join ' ')
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$logRoot = Get-CanonicalPath (Join-Path $extractedRoot 'Logs')
$logPath = Get-CanonicalPath (Join-Path $logRoot 'assetripper-sample.log')

Assert-PathUnderOrEqual -Path $logRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-PathUnderOrEqual -Path $logPath -RootPath $logRoot -Description 'LogPath'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $logRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $logPath -RootPath $logRoot -Description 'LogPath'

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace([string]$manifest.assetRipper) -or -not (Test-Path -LiteralPath $manifest.assetRipper -PathType Leaf)) {
    throw "Missing AssetRipper executable: $($manifest.assetRipper)"
}
$assetRipperPort = ConvertTo-TcpPort -Value $manifest.assetRipperPort

$logRootInfo = [System.IO.Directory]::CreateDirectory($logRoot)
$logRoot = $logRootInfo.FullName
$logPath = Get-CanonicalPath (Join-Path $logRoot 'assetripper-sample.log')
Assert-NoExistingReparsePointUnderRoot -Path $logRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $logPath -RootPath $logRoot -Description 'LogPath'

$url = "http://127.0.0.1:$assetRipperPort"
$preExistingListener = Get-PortListenerSummary -Port $assetRipperPort
if ($preExistingListener) {
    throw "AssetRipper port $assetRipperPort is already listening before startup: $preExistingListener. LogPath: $logPath"
}

$assetRipperArgs = @(
    '--headless=true',
    '--port',
    [string]$assetRipperPort,
    '--log=true',
    '--log-path',
    $logPath
)

$argumentLine = Join-WindowsProcessArguments -ArgumentList $assetRipperArgs
$process = Start-Process -FilePath $manifest.assetRipper -ArgumentList $argumentLine -WindowStyle Hidden -PassThru

$deadline = [DateTime]::UtcNow.AddSeconds(15)
$urlResponded = $false
$portListening = $false
$listenerSummary = $null
while ([DateTime]::UtcNow -lt $deadline) {
    Start-Sleep -Milliseconds 500
    $process.Refresh()
    if ($process.HasExited) {
        break
    }

    $urlResponded = Test-UrlResponds -Url $url
    $listenerSummary = Get-PortListenerSummary -Port $assetRipperPort
    $portListening = -not [string]::IsNullOrWhiteSpace($listenerSummary)
    if ($urlResponded -or $portListening) {
        break
    }
}

$process.Refresh()
if ($process.HasExited -or (-not $urlResponded -and -not $portListening)) {
    $status = Get-ProcessStatusText -Process $process
    $listenerText = if ($listenerSummary) { $listenerSummary } else { 'none' }
    if (-not $process.HasExited) {
        Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
        [void]$process.WaitForExit(5000)
        $status = Get-ProcessStatusText -Process $process
    }
    throw "AssetRipper startup failed or port $assetRipperPort did not become available within 15 seconds. ProcessId: $($process.Id). ProcessStatus: $status. UrlResponded: $urlResponded. PortListening: $portListening. Listeners: $listenerText. LogPath: $logPath"
}

[PSCustomObject]@{
    ProcessId = $process.Id
    Url = $url
    LogPath = $logPath
} | Format-List
