[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$SampleRoot,
    [string]$OutputRoot,
    [string]$LogRoot
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

function Assert-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing $Name`: $Path"
    }
}

function Get-RelativeDirectoryPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [Parameter(Mandatory = $true)]
        [string]$DirectoryPath
    )

    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $directory = (Get-CanonicalPath $DirectoryPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([string]::Equals($root, $directory, [System.StringComparison]::OrdinalIgnoreCase)) {
        return ''
    }

    $rootWithSeparator = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $directory.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Directory path must stay under $root. Got: $directory"
    }

    return $directory.Substring($rootWithSeparator.Length)
}

function Invoke-ExternalProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
        [Parameter(Mandatory = $true)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$LogRoot
    )

    $stdoutPath = Join-Path $LogRoot ([System.IO.Path]::GetRandomFileName())
    $stderrPath = Join-Path $LogRoot ([System.IO.Path]::GetRandomFileName())
    $exitCode = -1
    $stdout = ''
    $stderr = ''

    try {
        & $FilePath @ArgumentList 1> $stdoutPath 2> $stderrPath
        $exitCode = $LASTEXITCODE

        if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
            $stdoutContent = Get-Content -LiteralPath $stdoutPath -Raw
            $stdout = if ($null -eq $stdoutContent) { '' } else { [string]$stdoutContent }
        }
        if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            $stderrContent = Get-Content -LiteralPath $stderrPath -Raw
            $stderr = if ($null -eq $stderrContent) { '' } else { [string]$stderrContent }
        }
    }
    finally {
        if (Test-Path -LiteralPath $stdoutPath -PathType Leaf) {
            Remove-Item -LiteralPath $stdoutPath -Force
        }
        if (Test-Path -LiteralPath $stderrPath -PathType Leaf) {
            Remove-Item -LiteralPath $stderrPath -Force
        }
    }

    return [PSCustomObject]@{
        Description = $Description
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($SampleRoot)) {
    $SampleRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Samples\Audio'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\DecodedAudio'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$audioSamplesRoot = Get-CanonicalPath (Join-Path $extractedRoot 'Samples\Audio')

$ToolManifestPath = Get-CanonicalPath $ToolManifestPath
$SampleRoot = Get-CanonicalPath $SampleRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $SampleRoot -RootPath $audioSamplesRoot -Description 'SampleRoot'
Assert-PathUnderOrEqual -Path $SampleRoot -RootPath $extractedRoot -Description 'SampleRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $SampleRoot -RootPath $extractedRoot -Description 'SampleRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

$toolManifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
Assert-ToolPath -Name 'vgmstream-cli' -Path $toolManifest.vgmstreamCli
Assert-ToolPath -Name 'ffmpeg' -Path $toolManifest.ffmpeg
Assert-ToolPath -Name 'ffprobe' -Path $toolManifest.ffprobe

$outputRootInfo = [System.IO.Directory]::CreateDirectory($OutputRoot)
$logRootInfo = [System.IO.Directory]::CreateDirectory($LogRoot)
$OutputRoot = $outputRootInfo.FullName
$LogRoot = $logRootInfo.FullName
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

$wemFiles = @(Get-ChildItem -LiteralPath $SampleRoot -Recurse -File -Filter '*.wem' -ErrorAction SilentlyContinue)
if ($wemFiles.Count -eq 0) {
    throw "No .wem files found under $SampleRoot. Run Copy-StellaSoraSamples.ps1 first."
}

$decodeLog = foreach ($wem in $wemFiles) {
    Assert-PathUnderOrEqual -Path $wem.FullName -RootPath $SampleRoot -Description 'WEM source path'
    Assert-NoExistingReparsePointUnderRoot -Path $wem.FullName -RootPath $SampleRoot -Description 'WEM source path'

    $relativeDirectory = Get-RelativeDirectoryPath -RootPath $SampleRoot -DirectoryPath $wem.DirectoryName

    $targetDirectory = Get-CanonicalPath (Join-Path $OutputRoot $relativeDirectory)
    Assert-PathUnderOrEqual -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
    Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'

    $wavPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).wav")
    $oggPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).ogg")
    $metadataPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).ffprobe.json")
    Assert-PathUnderOrEqual -Path $wavPath -RootPath $OutputRoot -Description 'WAV output path'
    Assert-PathUnderOrEqual -Path $oggPath -RootPath $OutputRoot -Description 'OGG output path'
    Assert-PathUnderOrEqual -Path $metadataPath -RootPath $OutputRoot -Description 'ffprobe metadata path'
    Assert-NoExistingReparsePointUnderRoot -Path $wavPath -RootPath $OutputRoot -Description 'WAV output path'
    Assert-NoExistingReparsePointUnderRoot -Path $oggPath -RootPath $OutputRoot -Description 'OGG output path'
    Assert-NoExistingReparsePointUnderRoot -Path $metadataPath -RootPath $OutputRoot -Description 'ffprobe metadata path'

    $decodeExitCode = -1
    $transcodeExitCode = -1
    $ffprobeExitCode = -1
    $decodeStdout = ''
    $decodeStderr = ''
    $transcodeStdout = ''
    $transcodeStderr = ''
    $ffprobeStdout = ''
    $ffprobeStderr = ''
    $errorMessage = $null

    try {
        $decode = Invoke-ExternalProcess -FilePath $toolManifest.vgmstreamCli -ArgumentList @('-i', '-o', $wavPath, $wem.FullName) -Description "Decode $($wem.FullName)" -LogRoot $LogRoot
        $decodeExitCode = $decode.ExitCode
        $decodeStdout = $decode.Stdout
        $decodeStderr = $decode.Stderr
        if ($decodeExitCode -ne 0) {
            throw "$($decode.Description) failed with exit code $decodeExitCode. stderr: $decodeStderr"
        }
        Assert-NoExistingReparsePointUnderRoot -Path $wavPath -RootPath $OutputRoot -Description 'WAV output path'

        $transcode = Invoke-ExternalProcess -FilePath $toolManifest.ffmpeg -ArgumentList @('-y', '-hide_banner', '-loglevel', 'error', '-i', $wavPath, '-c:a', 'libvorbis', '-q:a', '5', $oggPath) -Description "Transcode $wavPath" -LogRoot $LogRoot
        $transcodeExitCode = $transcode.ExitCode
        $transcodeStdout = $transcode.Stdout
        $transcodeStderr = $transcode.Stderr
        if ($transcodeExitCode -ne 0) {
            throw "$($transcode.Description) failed with exit code $transcodeExitCode. stderr: $transcodeStderr"
        }
        Assert-NoExistingReparsePointUnderRoot -Path $oggPath -RootPath $OutputRoot -Description 'OGG output path'

        $ffprobe = Invoke-ExternalProcess -FilePath $toolManifest.ffprobe -ArgumentList @('-v', 'error', '-show_format', '-show_streams', '-of', 'json', $oggPath) -Description "ffprobe $oggPath" -LogRoot $LogRoot
        $ffprobeExitCode = $ffprobe.ExitCode
        $ffprobeStdout = $ffprobe.Stdout
        $ffprobeStderr = $ffprobe.Stderr
        if ($ffprobeExitCode -ne 0) {
            throw "$($ffprobe.Description) failed with exit code $ffprobeExitCode. stderr: $ffprobeStderr"
        }
        Assert-NoExistingReparsePointUnderRoot -Path $metadataPath -RootPath $OutputRoot -Description 'ffprobe metadata path'
        $ffprobeStdout | Set-Content -LiteralPath $metadataPath -Encoding UTF8
        Assert-NoExistingReparsePointUnderRoot -Path $metadataPath -RootPath $OutputRoot -Description 'ffprobe metadata path'
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    $decodedWav = Test-Path -LiteralPath $wavPath -PathType Leaf
    $transcodedOgg = Test-Path -LiteralPath $oggPath -PathType Leaf
    $metadataWritten = Test-Path -LiteralPath $metadataPath -PathType Leaf

    [PSCustomObject]@{
        SourcePath = $wem.FullName
        WavPath = $wavPath
        OggPath = $oggPath
        MetadataPath = $metadataPath
        DecodeExitCode = $decodeExitCode
        TranscodeExitCode = $transcodeExitCode
        FfprobeExitCode = $ffprobeExitCode
        DecodedWav = $decodedWav
        TranscodedOgg = $transcodedOgg
        MetadataWritten = $metadataWritten
        WavLength = if ($decodedWav) { (Get-Item -LiteralPath $wavPath).Length } else { 0 }
        OggLength = if ($transcodedOgg) { (Get-Item -LiteralPath $oggPath).Length } else { 0 }
        MetadataLength = if ($metadataWritten) { (Get-Item -LiteralPath $metadataPath).Length } else { 0 }
        DecodeStdout = $decodeStdout
        DecodeStderr = $decodeStderr
        TranscodeStdout = $transcodeStdout
        TranscodeStderr = $transcodeStderr
        FfprobeStdout = $ffprobeStdout
        FfprobeStderr = $ffprobeStderr
        Error = $errorMessage
    }
}

$jsonPath = Join-Path $LogRoot 'wem-decode-log.json'
$decodeLog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
$decodeLog | Format-Table SourcePath,DecodedWav,TranscodedOgg,MetadataWritten,WavLength,OggLength,MetadataLength,DecodeExitCode,TranscodeExitCode,FfprobeExitCode -AutoSize

$failed = $decodeLog | Where-Object {
    $_.DecodeExitCode -ne 0 `
        -or $_.TranscodeExitCode -ne 0 `
        -or $_.FfprobeExitCode -ne 0 `
        -or -not $_.DecodedWav `
        -or -not $_.TranscodedOgg `
        -or -not $_.MetadataWritten `
        -or $_.WavLength -le 0 `
        -or $_.OggLength -le 0 `
        -or $_.MetadataLength -le 0
}

if ($failed) {
    $failureDetails = ($failed | ForEach-Object {
        "$($_.SourcePath) decode=$($_.DecodeExitCode) transcode=$($_.TranscodeExitCode) ffprobe=$($_.FfprobeExitCode) error=$($_.Error)"
    }) -join '; '
    throw "One or more .wem files failed to decode or transcode. See $jsonPath. Failures: $failureDetails"
}

Write-Host "WEM decode and transcode log written to $jsonPath"
