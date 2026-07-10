[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$BankRoot,
    [string[]]$BankName,
    [string]$OutputRoot,
    [string]$LogRoot,
    [int]$MaxMediaPerBank = 0
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

function Assert-NoExistingReparsePointUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$Description
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

function Invoke-ExternalProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][string[]]$ArgumentList,
        [Parameter(Mandatory = $true)][string]$LogRoot
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
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

function Get-BankChunks {
    param([Parameter(Mandatory = $true)][byte[]]$Bytes)

    $chunks = [System.Collections.Generic.List[object]]::new()
    $position = 0
    while ($position -le $Bytes.Length - 8) {
        $chunkId = [System.Text.Encoding]::ASCII.GetString($Bytes, $position, 4)
        $size = [System.BitConverter]::ToUInt32($Bytes, $position + 4)
        $dataStart = $position + 8
        $dataEnd = [Math]::Min($dataStart + [int64]$size, $Bytes.Length)

        $chunks.Add([PSCustomObject]@{
            Id = $chunkId
            Size = [int64]$size
            DataStart = [int64]$dataStart
            DataEnd = [int64]$dataEnd
        }) | Out-Null

        $next = $dataEnd
        if ($next -le $position) {
            break
        }
        $position = [int]$next
    }

    return @($chunks)
}

function Get-DidxEntries {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Bytes,
        [Parameter(Mandatory = $true)]$DidxChunk
    )

    $entries = [System.Collections.Generic.List[object]]::new()
    for ($position = [int64]$DidxChunk.DataStart; $position -le [int64]$DidxChunk.DataEnd - 12; $position += 12) {
        $entries.Add([PSCustomObject]@{
            MediaId = [uint32][System.BitConverter]::ToUInt32($Bytes, [int]$position)
            Offset = [uint32][System.BitConverter]::ToUInt32($Bytes, [int]($position + 4))
            Size = [uint32][System.BitConverter]::ToUInt32($Bytes, [int]($position + 8))
        }) | Out-Null
    }

    return @($entries)
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
if ([string]::IsNullOrWhiteSpace($BankRoot)) {
    $BankRoot = Join-Path $extractedRoot 'RawAssets\Persistent_Store\SoundBanks'
}
if ($null -eq $BankName -or $BankName.Count -eq 0) {
    $BankName = @('Impact.bnk', 'Monster_10001.bnk', 'Character_Common.bnk')
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $extractedRoot 'DecodedAudio\BankMedia'
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = Join-Path $extractedRoot 'Logs'
}

$ToolManifestPath = Get-CanonicalPath $ToolManifestPath
$BankRoot = Get-CanonicalPath $BankRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $ToolManifestPath -RootPath $repoRoot -Description 'ToolManifestPath'
Assert-PathUnderOrEqual -Path $BankRoot -RootPath $extractedRoot -Description 'BankRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $BankRoot -RootPath $extractedRoot -Description 'BankRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

if (-not (Test-Path -LiteralPath $ToolManifestPath -PathType Leaf)) {
    throw "Missing tool manifest: $ToolManifestPath"
}
if (-not (Test-Path -LiteralPath $BankRoot -PathType Container)) {
    throw "Missing bank root: $BankRoot"
}

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.vgmstreamCli) -or -not (Test-Path -LiteralPath $manifest.vgmstreamCli -PathType Leaf)) {
    throw "Missing vgmstream-cli: $($manifest.vgmstreamCli)"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)
[void][System.IO.Directory]::CreateDirectory($LogRoot)

$decodeRows = [System.Collections.Generic.List[object]]::new()
foreach ($bankNameEntry in $BankName) {
    if ([string]::IsNullOrWhiteSpace($bankNameEntry)) {
        continue
    }
    if ([System.IO.Path]::IsPathRooted($bankNameEntry) -or $bankNameEntry.Contains([System.IO.Path]::DirectorySeparatorChar) -or $bankNameEntry.Contains([System.IO.Path]::AltDirectorySeparatorChar)) {
        throw "BankName entries must be plain file names under BankRoot. Got: $bankNameEntry"
    }

    $bankPath = Get-CanonicalPath (Join-Path $BankRoot $bankNameEntry)
    Assert-PathUnderOrEqual -Path $bankPath -RootPath $BankRoot -Description 'Bank path'
    if (-not (Test-Path -LiteralPath $bankPath -PathType Leaf)) {
        throw "Missing bank: $bankPath"
    }

    $bankBaseName = [System.IO.Path]::GetFileNameWithoutExtension($bankNameEntry)
    $bankOutputRoot = Get-CanonicalPath (Join-Path $OutputRoot $bankBaseName)
    Assert-PathUnderOrEqual -Path $bankOutputRoot -RootPath $OutputRoot -Description 'Bank output root'
    [void][System.IO.Directory]::CreateDirectory($bankOutputRoot)
    Assert-NoExistingReparsePointUnderRoot -Path $bankOutputRoot -RootPath $OutputRoot -Description 'Bank output root'

    $bytes = [System.IO.File]::ReadAllBytes($bankPath)
    $chunks = Get-BankChunks -Bytes $bytes
    $didx = @($chunks | Where-Object { $_.Id -eq 'DIDX' } | Select-Object -First 1)
    $data = @($chunks | Where-Object { $_.Id -eq 'DATA' } | Select-Object -First 1)
    if ($didx.Count -eq 0 -or $data.Count -eq 0) {
        $decodeRows.Add([PSCustomObject]@{
            Status = 'SkippedNoDidxData'
            Bank = $bankNameEntry
            MediaId = ''
            WemPath = ''
            WavPath = ''
            MediaSize = 0
            DecodeExitCode = 0
            Error = ''
        }) | Out-Null
        continue
    }

    $entries = @(Get-DidxEntries -Bytes $bytes -DidxChunk $didx[0])
    if ($MaxMediaPerBank -gt 0) {
        $entries = @($entries | Select-Object -First $MaxMediaPerBank)
    }

    foreach ($entry in $entries) {
        $mediaStart = [int64]$data[0].DataStart + [int64]$entry.Offset
        $mediaEnd = $mediaStart + [int64]$entry.Size
        $wemPath = Get-CanonicalPath (Join-Path $bankOutputRoot ("{0}.wem" -f $entry.MediaId))
        $wavPath = Get-CanonicalPath (Join-Path $bankOutputRoot ("{0}.wav" -f $entry.MediaId))
        Assert-PathUnderOrEqual -Path $wemPath -RootPath $bankOutputRoot -Description 'Bank WEM output path'
        Assert-PathUnderOrEqual -Path $wavPath -RootPath $bankOutputRoot -Description 'Bank WAV output path'

        $status = 'Decoded'
        $exitCode = 0
        $stderr = ''
        if ($mediaStart -lt [int64]$data[0].DataStart -or $mediaEnd -gt [int64]$data[0].DataEnd) {
            $status = 'FailedInvalidMediaRange'
        } else {
            if (-not (Test-Path -LiteralPath $wemPath -PathType Leaf)) {
                $mediaBytes = New-Object byte[] ([int]$entry.Size)
                [System.Array]::Copy($bytes, [int]$mediaStart, $mediaBytes, 0, [int]$entry.Size)
                [System.IO.File]::WriteAllBytes($wemPath, $mediaBytes)
            }

            if (Test-Path -LiteralPath $wavPath -PathType Leaf) {
                $existingWav = Get-Item -LiteralPath $wavPath
                if ($existingWav.Length -gt 44) {
                    $status = 'SkippedExistingWav'
                }
            }

            if ($status -ne 'SkippedExistingWav') {
                $decode = Invoke-ExternalProcess -FilePath $manifest.vgmstreamCli -ArgumentList @('-i', '-o', $wavPath, $wemPath) -LogRoot $LogRoot
                $exitCode = $decode.ExitCode
                $stderr = $decode.Stderr.Trim()
                if ($decode.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
                    $status = 'FailedDecode'
                }
            }
        }

        $decodeRows.Add([PSCustomObject]@{
            Status = $status
            Bank = $bankNameEntry
            MediaId = [int64]$entry.MediaId
            WemPath = $wemPath
            WavPath = $wavPath
            MediaSize = [int64]$entry.Size
            DecodeExitCode = $exitCode
            Error = $stderr
        }) | Out-Null
    }
}

$csvLogPath = Get-CanonicalPath (Join-Path $LogRoot 'bank-media-decode-log.csv')
$jsonLogPath = Get-CanonicalPath (Join-Path $LogRoot 'bank-media-decode-log.json')
Assert-PathUnderOrEqual -Path $csvLogPath -RootPath $LogRoot -Description 'CSV log path'
Assert-PathUnderOrEqual -Path $jsonLogPath -RootPath $LogRoot -Description 'JSON log path'

$decodeRows | Export-Csv -LiteralPath $csvLogPath -NoTypeInformation -Encoding UTF8
$decodeRows | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonLogPath -Encoding UTF8

$summary = [PSCustomObject]@{
    BankRoot = $BankRoot
    OutputRoot = $OutputRoot
    BankCount = @($BankName).Count
    MediaCount = $decodeRows.Count
    DecodedCount = @($decodeRows | Where-Object { $_.Status -eq 'Decoded' -or $_.Status -eq 'SkippedExistingWav' }).Count
    FailedCount = @($decodeRows | Where-Object { $_.Status -like 'Failed*' }).Count
    CsvLogPath = $csvLogPath
    JsonLogPath = $jsonLogPath
    ByStatus = @($decodeRows | Group-Object Status | Sort-Object Name | ForEach-Object {
        [PSCustomObject]@{
            Status = $_.Name
            Count = $_.Count
        }
    })
    ByBank = @($decodeRows | Group-Object Bank | Sort-Object Name | ForEach-Object {
        [PSCustomObject]@{
            Bank = $_.Name
            Count = $_.Count
            FailedCount = @($_.Group | Where-Object { $_.Status -like 'Failed*' }).Count
        }
    })
}

$summary
