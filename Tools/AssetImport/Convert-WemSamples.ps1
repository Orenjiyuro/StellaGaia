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
        [string]$Description
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$Description failed with exit code $($process.ExitCode)."
    }

    return $process.ExitCode
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

$toolManifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
Assert-ToolPath -Name 'vgmstream-cli' -Path $toolManifest.vgmstreamCli
Assert-ToolPath -Name 'ffmpeg' -Path $toolManifest.ffmpeg
Assert-ToolPath -Name 'ffprobe' -Path $toolManifest.ffprobe

$outputRootInfo = [System.IO.Directory]::CreateDirectory($OutputRoot)
$logRootInfo = [System.IO.Directory]::CreateDirectory($LogRoot)
$OutputRoot = $outputRootInfo.FullName
$LogRoot = $logRootInfo.FullName

$wemFiles = @(Get-ChildItem -LiteralPath $SampleRoot -Recurse -File -Filter '*.wem' -ErrorAction SilentlyContinue)
if ($wemFiles.Count -eq 0) {
    throw "No .wem files found under $SampleRoot. Run Copy-StellaSoraSamples.ps1 first."
}

$decodeLog = foreach ($wem in $wemFiles) {
    Assert-PathUnderOrEqual -Path $wem.FullName -RootPath $SampleRoot -Description 'WEM source path'

    $relativeDirectory = Get-RelativeDirectoryPath -RootPath $SampleRoot -DirectoryPath $wem.DirectoryName

    $targetDirectory = Get-CanonicalPath (Join-Path $OutputRoot $relativeDirectory)
    Assert-PathUnderOrEqual -Path $targetDirectory -RootPath $OutputRoot -Description 'Target directory'
    New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null

    $wavPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).wav")
    $oggPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).ogg")
    $metadataPath = Get-CanonicalPath (Join-Path $targetDirectory "$($wem.BaseName).ffprobe.json")
    Assert-PathUnderOrEqual -Path $wavPath -RootPath $OutputRoot -Description 'WAV output path'
    Assert-PathUnderOrEqual -Path $oggPath -RootPath $OutputRoot -Description 'OGG output path'
    Assert-PathUnderOrEqual -Path $metadataPath -RootPath $OutputRoot -Description 'ffprobe metadata path'

    $decodeExitCode = -1
    $transcodeExitCode = -1
    $ffprobeExitCode = -1
    $errorMessage = $null

    try {
        $decodeExitCode = Invoke-ExternalProcess -FilePath $toolManifest.vgmstreamCli -ArgumentList @('-i', '-o', $wavPath, $wem.FullName) -Description "Decode $($wem.FullName)"
        $transcodeExitCode = Invoke-ExternalProcess -FilePath $toolManifest.ffmpeg -ArgumentList @('-y', '-hide_banner', '-loglevel', 'error', '-i', $wavPath, '-c:a', 'libvorbis', '-q:a', '5', $oggPath) -Description "Transcode $wavPath"

        $ffprobeJson = & $toolManifest.ffprobe -v error -show_format -show_streams -of json $oggPath
        $ffprobeExitCode = $LASTEXITCODE
        if ($ffprobeExitCode -ne 0) {
            throw "ffprobe $oggPath failed with exit code $ffprobeExitCode."
        }
        $ffprobeJson | Set-Content -LiteralPath $metadataPath -Encoding UTF8
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
    throw "One or more .wem files failed to decode or transcode. See $jsonPath"
}

Write-Host "WEM decode and transcode log written to $jsonPath"
