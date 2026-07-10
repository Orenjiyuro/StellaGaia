[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$Category,
    [string]$ToolManifestPath,
    [string]$InventoryCsvPath,
    [string]$RawAssetRoot,
    [string]$InputRoot,
    [string]$ExportRoot,
    [string]$LogRoot,
    [int]$StartupTimeoutSec = 30,
    [int]$LoadTimeoutSec = 1200,
    [int]$ExportTimeoutSec = 7200
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

function Assert-SafeNameSegment {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if ($Value -notmatch '^[A-Za-z0-9_.-]+$') {
        throw "$Description must be a simple path segment. Got: $Value"
    }
}

function ConvertTo-TcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        throw 'assetRipperPort must not be null.'
    }
    if ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int] -or $Value -is [int64]) {
        $port = [int64]$Value
    }
    elseif ($Value -is [string] -and $Value -match '^\d+$') {
        $port = [int64]$Value
    }
    else {
        throw "assetRipperPort must be an integer TCP port. Got: $Value"
    }

    if ($port -lt 1 -or $port -gt 65535) {
        throw "assetRipperPort must be from 1 through 65535. Got: $Value"
    }

    return [int]$port
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

function Get-PortListenerSummary {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    $listeners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if ($listeners.Count -eq 0) {
        return $null
    }

    return ($listeners | ForEach-Object { "PID=$($_.OwningProcess) $($_.LocalAddress):$($_.LocalPort)" }) -join '; '
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

function Start-AssetRipperServer {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AssetRipperPath,
        [Parameter(Mandatory = $true)]
        [int]$Port,
        [Parameter(Mandatory = $true)]
        [string]$LogPath,
        [Parameter(Mandatory = $true)]
        [int]$TimeoutSec
    )

    $preExistingListener = Get-PortListenerSummary -Port $Port
    if ($preExistingListener) {
        throw "AssetRipper port $Port is already listening before startup: $preExistingListener"
    }

    $args = @(
        '--headless=true',
        '--port',
        [string]$Port,
        '--log=true',
        '--log-path',
        $LogPath
    )

    $process = Start-Process -FilePath $AssetRipperPath -ArgumentList (Join-WindowsProcessArguments -ArgumentList $args) -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSec)
    $url = "http://127.0.0.1:$Port"
    while ([DateTime]::UtcNow -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) {
            throw "AssetRipper exited during startup with code $($process.ExitCode). LogPath: $LogPath"
        }
        if (Test-UrlResponds -Url $url) {
            return $process
        }
        if (Get-PortListenerSummary -Port $Port) {
            return $process
        }
    }

    Stop-Process -Id $process.Id -ErrorAction SilentlyContinue
    [void]$process.WaitForExit(5000)
    throw "AssetRipper did not become available on $url within $TimeoutSec seconds. LogPath: $LogPath"
}

function Stop-AssetRipperServer {
    param(
        [AllowNull()]
        [System.Diagnostics.Process]$Process
    )

    if ($null -eq $Process) {
        return
    }

    try {
        $Process.Refresh()
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -ErrorAction SilentlyContinue
            [void]$Process.WaitForExit(10000)
        }
    }
    catch {
    }
}

function Get-FileSummary {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    if (-not (Test-Path -LiteralPath $RootPath -PathType Container)) {
        return [PSCustomObject]@{
            Count = 0
            TotalBytes = 0
            Extensions = @()
        }
    }

    $files = @(Get-ChildItem -LiteralPath $RootPath -Recurse -File -ErrorAction SilentlyContinue)
    $totalBytes = ($files | Measure-Object Length -Sum).Sum
    if ($null -eq $totalBytes) {
        $totalBytes = 0
    }

    $extensions = $files |
        Group-Object Extension |
        Sort-Object Count -Descending |
        ForEach-Object {
            $extension = if ([string]::IsNullOrWhiteSpace($_.Name)) { '<none>' } else { $_.Name }
            "${extension}:$($_.Count)"
        }

    return [PSCustomObject]@{
        Count = $files.Count
        TotalBytes = [int64]$totalBytes
        Extensions = @($extensions)
    }
}

function Invoke-CategoryExport {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CategoryName,
        [Parameter(Mandatory = $true)]
        [object[]]$Rows,
        [Parameter(Mandatory = $true)]
        [object]$Manifest,
        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    Assert-SafeNameSegment -Value $CategoryName -Description 'Category'

    $inputPath = Get-CanonicalPath (Join-Path $InputRoot $CategoryName)
    $exportPath = Get-CanonicalPath (Join-Path $ExportRoot $CategoryName)
    $logPath = Get-CanonicalPath (Join-Path $LogRoot "assetripper-category-$CategoryName.log")
    $resultPath = Get-CanonicalPath (Join-Path $LogRoot "assetripper-category-$CategoryName-result.txt")

    Assert-PathUnderOrEqual -Path $inputPath -RootPath $InputRoot -Description 'Category input path'
    Assert-PathUnderOrEqual -Path $exportPath -RootPath $ExportRoot -Description 'Category export path'
    Assert-PathUnderOrEqual -Path $logPath -RootPath $LogRoot -Description 'Category log path'
    Assert-PathUnderOrEqual -Path $resultPath -RootPath $LogRoot -Description 'Category result path'

    [void][System.IO.Directory]::CreateDirectory($inputPath)
    [void][System.IO.Directory]::CreateDirectory($exportPath)
    Assert-NoExistingReparsePointUnderRoot -Path $inputPath -RootPath $InputRoot -Description 'Category input path'
    Assert-NoExistingReparsePointUnderRoot -Path $exportPath -RootPath $ExportRoot -Description 'Category export path'

    $stageLog = foreach ($row in $Rows) {
        Assert-SafeRelativePath -RelativePath $row.RelativePath

        $sourcePath = Get-CanonicalPath (Join-Path $RawAssetRoot $row.RelativePath)
        Assert-PathUnderOrEqual -Path $sourcePath -RootPath $RawAssetRoot -Description 'Raw source path'
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
            throw "Missing raw source file: $sourcePath"
        }

        $targetPath = Get-CanonicalPath (Join-Path $inputPath $row.RelativePath)
        Assert-PathUnderOrEqual -Path $targetPath -RootPath $inputPath -Description 'Staged target path'
        $targetDirectory = Split-Path -Parent $targetPath
        Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $inputPath -Description 'Staged target directory'
        New-Item -ItemType Directory -Force -Path $targetDirectory | Out-Null
        Assert-NoExistingReparsePointUnderRoot -Path $targetDirectory -RootPath $inputPath -Description 'Staged target directory'

        $sourceItem = Get-Item -LiteralPath $sourcePath
        $status = 'Copied'
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $targetItem = Get-Item -LiteralPath $targetPath
            if ($targetItem.Length -eq $sourceItem.Length) {
                $status = 'SkippedExistingSameLength'
            }
        }

        if ($status -ne 'SkippedExistingSameLength') {
            Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
            Assert-NoExistingReparsePointUnderRoot -Path $targetPath -RootPath $inputPath -Description 'Staged target path'
        }

        [PSCustomObject]@{
            Status = $status
            Category = $row.Category
            RelativePath = $row.RelativePath
            Length = $sourceItem.Length
        }
    }

    $stageLogPath = Get-CanonicalPath (Join-Path $LogRoot "assetripper-category-$CategoryName-stage-log.csv")
    Assert-PathUnderOrEqual -Path $stageLogPath -RootPath $LogRoot -Description 'Stage log path'
    $stageLog | Export-Csv -LiteralPath $stageLogPath -NoTypeInformation -Encoding UTF8

    $process = $null
    try {
        $process = Start-AssetRipperServer -AssetRipperPath $Manifest.assetRipper -Port $Port -LogPath $logPath -TimeoutSec $StartupTimeoutSec
        $url = "http://127.0.0.1:$Port"
        Invoke-WebRequest -Uri "$url/LoadFolder" -Method Post -Body @{ Path = $inputPath } -UseBasicParsing -TimeoutSec $LoadTimeoutSec | Out-Null
        Invoke-WebRequest -Uri "$url/Export/UnityProject" -Method Post -Body @{ Path = $exportPath; CreateSubfolder = 'false' } -UseBasicParsing -TimeoutSec $ExportTimeoutSec | Out-Null
    }
    finally {
        Stop-AssetRipperServer -Process $process
    }

    $summary = Get-FileSummary -RootPath $exportPath
    $missingWarnings = 0
    $uniqueCabCount = 0
    if (Test-Path -LiteralPath $logPath -PathType Leaf) {
        $missingWarnings = (Select-String -LiteralPath $logPath -Pattern "Dependency .*wasn't found" -CaseSensitive:$false | Measure-Object).Count
        $cabMatches = (Select-String -LiteralPath $logPath -Pattern 'CAB-[0-9a-f]{32}' -AllMatches).Matches
        $uniqueCabCount = @($cabMatches | ForEach-Object { $_.Value } | Sort-Object -Unique).Count
    }

    $status = if ($missingWarnings -gt 0) { 'ExportedWithMissingDependencies' } else { 'Exported' }
    $lines = @(
        "AssetRipper category export result",
        "GeneratedAt=$([DateTimeOffset]::Now.ToString('O'))",
        "Category=$CategoryName",
        "Status=$status",
        "Input=$inputPath",
        "Output=$exportPath",
        "InputBundleCount=$($Rows.Count)",
        "InputTotalBytes=$(($Rows | Measure-Object Length -Sum).Sum)",
        "ExportedFileCount=$($summary.Count)",
        "ExportedTotalBytes=$($summary.TotalBytes)",
        "ExportedExtensions=$($summary.Extensions -join ',')",
        "MissingDependencyWarnings=$missingWarnings",
        "UniqueMissingCabCount=$uniqueCabCount",
        "ProcessLog=$logPath"
    )
    $lines | Set-Content -LiteralPath $resultPath -Encoding UTF8

    return [PSCustomObject]@{
        Category = $CategoryName
        Status = $status
        InputBundleCount = $Rows.Count
        InputTotalBytes = ($Rows | Measure-Object Length -Sum).Sum
        ExportedFileCount = $summary.Count
        ExportedTotalBytes = $summary.TotalBytes
        MissingDependencyWarnings = $missingWarnings
        UniqueMissingCabCount = $uniqueCabCount
        ResultPath = $resultPath
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
if ([string]::IsNullOrWhiteSpace($InputRoot)) {
    $InputRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\AssetRipper\CategoryInputs'))
}
if ([string]::IsNullOrWhiteSpace($ExportRoot)) {
    $ExportRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\AssetRipper\ByCategory'))
}
if ([string]::IsNullOrWhiteSpace($LogRoot)) {
    $LogRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\Extracted\Logs'))
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$ToolManifestPath = Get-CanonicalPath $ToolManifestPath
$InventoryCsvPath = Get-CanonicalPath $InventoryCsvPath
$RawAssetRoot = Get-CanonicalPath $RawAssetRoot
$InputRoot = Get-CanonicalPath $InputRoot
$ExportRoot = Get-CanonicalPath $ExportRoot
$LogRoot = Get-CanonicalPath $LogRoot

Assert-PathUnderOrEqual -Path $InventoryCsvPath -RootPath $extractedRoot -Description 'InventoryCsvPath'
Assert-PathUnderOrEqual -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-PathUnderOrEqual -Path $InputRoot -RootPath $extractedRoot -Description 'InputRoot'
Assert-PathUnderOrEqual -Path $ExportRoot -RootPath $extractedRoot -Description 'ExportRoot'
Assert-PathUnderOrEqual -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $RawAssetRoot -RootPath $extractedRoot -Description 'RawAssetRoot'
Assert-NoExistingReparsePointUnderRoot -Path $InputRoot -RootPath $extractedRoot -Description 'InputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $ExportRoot -RootPath $extractedRoot -Description 'ExportRoot'
Assert-NoExistingReparsePointUnderRoot -Path $LogRoot -RootPath $extractedRoot -Description 'LogRoot'

if (-not (Test-Path -LiteralPath $InventoryCsvPath -PathType Leaf)) {
    throw "Missing inventory CSV: $InventoryCsvPath"
}
if (-not (Test-Path -LiteralPath $RawAssetRoot -PathType Container)) {
    throw "Missing raw asset root: $RawAssetRoot"
}

$manifest = Get-Content -LiteralPath $ToolManifestPath -Raw | ConvertFrom-Json
if ([string]::IsNullOrWhiteSpace($manifest.assetRipper) -or -not (Test-Path -LiteralPath $manifest.assetRipper -PathType Leaf)) {
    throw "Missing AssetRipper executable: $($manifest.assetRipper)"
}
$port = ConvertTo-TcpPort -Value $manifest.assetRipperPort

[void][System.IO.Directory]::CreateDirectory($InputRoot)
[void][System.IO.Directory]::CreateDirectory($ExportRoot)
[void][System.IO.Directory]::CreateDirectory($LogRoot)

$inventory = @(Import-Csv -LiteralPath $InventoryCsvPath | Where-Object { $_.Extension -eq '.unity3d' })
$results = foreach ($categoryName in $Category) {
    Assert-SafeNameSegment -Value $categoryName -Description 'Category'
    $rows = @($inventory | Where-Object { $_.Category -eq $categoryName } | Sort-Object RelativePath)
    if ($rows.Count -eq 0) {
        throw "No .unity3d rows found for category: $categoryName"
    }

    Invoke-CategoryExport -CategoryName $categoryName -Rows $rows -Manifest $manifest -Port $port
}

$results | Format-Table Category,Status,InputBundleCount,ExportedFileCount,MissingDependencyWarnings,UniqueMissingCabCount -AutoSize
