[CmdletBinding()]
param(
    [string]$ToolManifestPath,
    [string]$InventoryCsvPath,
    [string]$RawAssetRoot,
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

function Assert-SafeRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw 'Inventory relative path must not be empty.'
    }
    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Inventory relative path must not be rooted: $RelativePath"
    }
    foreach ($segment in $RelativePath.Split([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)) {
        if ([string]::IsNullOrWhiteSpace($segment) -or $segment -eq '.' -or $segment -eq '..') {
            throw "Inventory relative path contains an unsafe segment: $RelativePath"
        }
    }
}

function Invoke-ExternalProcess {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,
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
        ExitCode = $exitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

if ([string]::IsNullOrWhiteSpace($ToolManifestPath)) {
    $ToolManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}
if ([string]::IsNullOrWhiteSpace($InventoryCsvPath)) {
    $InventoryCsvPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Inventory\asset-inventory.csv'))
}
if ([string]::IsNullOrWhiteSpace($RawAssetRoot)) {
    $RawAssetRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\RawAssets'))
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\DecodedAudio\Full'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$ToolManifestPath = Get-CanonicalPath $ToolManifestPath
$InventoryCsvPath = Get-CanonicalPath $InventoryCsvPath
$RawAssetRoot = Get-CanonicalPath $RawAssetRoot
$OutputRoot = Get-CanonicalPath $OutputRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $InventoryCsvPath -RootPath $extractedRoot -Description 'InventoryCsvPath'
Assert-PathUnderOrEqual -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.vgmstreamCli) -or -not (Test-Path -LiteralPath $manifest.vgmstreamCli -PathType Leaf)) {
    throw "Missing vgmstream-cli: $($manifest.vgmstreamCli)"
}
if (-not (Test-Path -LiteralPath $InventoryCsvPath -PathType Leaf)) {
    throw "Missing inventory CSV: $InventoryCsvPath"
}
if (-not (Test-Path -LiteralPath $RawAssetRoot -PathType Container)) {
    throw "Missing raw asset root: $RawAssetRoot"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)
[void][System.IO.Directory]::CreateDirectory($LogRoot)

$wemRows = @(Import-Csv -LiteralPath $InventoryCsvPath | Where-Object { $_.Extension -eq '.wem' } | Sort-Object RelativePath)
if ($wemRows.Count -eq 0) {
    throw 'No WEM rows found in inventory.'
}

$decodeLog = foreach ($row in $wemRows) {
    Assert-SafeRelativePath -RelativePath $row.RelativePath

    $sourcePath = Get-CanonicalPath (Join-Path $RawAssetRoot $row.RelativePath)
    Assert-PathUnderOrEqual -Path $sourcePath -RootPath $RawAssetRoot -Description 'WEM source path'
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing WEM source file: $sourcePath"
    }

    $relativeOutputPath = [System.IO.Path]::ChangeExtension($row.RelativePath, '.wav')
    $wavPath = Get-CanonicalPath (Join-Path $OutputRoot $relativeOutputPath)
    Assert-PathUnderOrEqual -Path $wavPath -RootPath $OutputRoot -Description 'WAV output path'
    $wavDirectory = Split-Path -Parent $wavPath
    Assert-PathUnderOrEqual -Path $wavDirectory -RootPath $OutputRoot -Description 'WAV output directory'
    Assert-NoExistingReparsePointUnderRoot -Path $wavDirectory -RootPath $OutputRoot -Description 'WAV output directory'
    New-Item -ItemType Directory -Force -Path $wavDirectory | Out-Null
    Assert-NoExistingReparsePointUnderRoot -Path $wavDirectory -RootPath $OutputRoot -Description 'WAV output directory'

    $sourceItem = Get-Item -LiteralPath $sourcePath
    $status = 'Decoded'
    $exitCode = 0
    $stderr = ''

    if (Test-Path -LiteralPath $wavPath -PathType Leaf) {
        $existing = Get-Item -LiteralPath $wavPath
        if ($existing.Length -gt 44) {
            $status = 'SkippedExistingWav'
        }
    }

    if ($status -ne 'SkippedExistingWav') {
        $decode = Invoke-ExternalProcess -FilePath $manifest.vgmstreamCli -ArgumentList @('-i', '-o', $wavPath, $sourcePath) -LogRoot $LogRoot
        $exitCode = $decode.ExitCode
        $stderr = $decode.Stderr.Trim()
        if ($decode.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $wavPath -PathType Leaf)) {
            $status = 'Failed'
        }
    }

    $targetLength = if (Test-Path -LiteralPath $wavPath -PathType Leaf) { (Get-Item -LiteralPath $wavPath).Length } else { 0 }
    [PSCustomObject]@{
        Status = $status
        Category = $row.Category
        RelativePath = $row.RelativePath
        SourcePath = $sourcePath
        WavPath = $wavPath
        SourceLength = $sourceItem.Length
        WavLength = $targetLength
        DecodeExitCode = $exitCode
        Error = $stderr
    }
}

$csvLogPath = Get-CanonicalPath (Join-Path $LogRoot 'full-wem-decode-log.csv')
$jsonLogPath = Get-CanonicalPath (Join-Path $LogRoot 'full-wem-decode-log.json')
Assert-PathUnderOrEqual -Path $csvLogPath -RootPath $LogRoot -Description 'CSV log path'
Assert-PathUnderOrEqual -Path $jsonLogPath -RootPath $LogRoot -Description 'JSON log path'

$decodeLog | Export-Csv -LiteralPath $csvLogPath -NoTypeInformation -Encoding UTF8
$decodeLog | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $jsonLogPath -Encoding UTF8

$decodeLog |
    Group-Object Status |
    Sort-Object Count -Descending |
    Select-Object Count,Name |
    Format-Table -AutoSize

Write-Host "Decoded audio output root: $OutputRoot"
Write-Host "Full WEM decode log written to $csvLogPath"
