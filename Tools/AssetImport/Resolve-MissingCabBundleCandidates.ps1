[CmdletBinding()]
param(
    [string]$Name = 'Environment009A05AndroidVariant',
    [string]$MissingCabLogPath,
    [string]$CabIndexCsvPath,
    [string]$OutputRoot,
    [int]$MaxCabFanoutForAction = 50,
    [int]$MaxSelectedCandidates = 40
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
    $candidate = (Get-CanonicalPath $CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $root = (Get-CanonicalPath $RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    if ([string]::Equals($candidate, $root, $comparison)) {
        return $true
    }

    return $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, $comparison)
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

function Add-RecordToMap {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Map,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [object]$Record
    )

    if (-not $Map.ContainsKey($Key)) {
        $Map[$Key] = New-Object System.Collections.Generic.List[object]
    }

    $Map[$Key].Add($Record) | Out-Null
}

function Get-UniqueStrings {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Values
    )

    return @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Sort-Object -Unique)
}

if ([string]::IsNullOrWhiteSpace($MissingCabLogPath)) {
    $MissingCabLogPath = Join-Path $PSScriptRoot "..\..\Extracted\Logs\assetripper-folder-$Name.log"
}
if ([string]::IsNullOrWhiteSpace($CabIndexCsvPath)) {
    $CabIndexCsvPath = Join-Path $PSScriptRoot '..\..\Extracted\DependencyIndex\assetbundle-cab-index.csv'
}
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\..\Extracted\Validation\MissingCabResolution'
}

$repoRoot = Get-CanonicalPath (Join-Path $PSScriptRoot '..\..')
$extractedRoot = Get-CanonicalPath (Join-Path $repoRoot 'Extracted')
$MissingCabLogPath = Get-CanonicalPath $MissingCabLogPath
$CabIndexCsvPath = Get-CanonicalPath $CabIndexCsvPath
$OutputRoot = Get-CanonicalPath $OutputRoot

Assert-SafeNameSegment -Value $Name -Description 'Name'
Assert-PathUnderOrEqual -Path $MissingCabLogPath -RootPath $extractedRoot -Description 'MissingCabLogPath'
Assert-PathUnderOrEqual -Path $CabIndexCsvPath -RootPath $extractedRoot -Description 'CabIndexCsvPath'
Assert-PathUnderOrEqual -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'
Assert-NoExistingReparsePointUnderRoot -Path $extractedRoot -RootPath $repoRoot -Description 'Extracted'
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

if (-not (Test-Path -LiteralPath $MissingCabLogPath -PathType Leaf)) {
    throw "Missing CAB log: $MissingCabLogPath"
}
if (-not (Test-Path -LiteralPath $CabIndexCsvPath -PathType Leaf)) {
    throw "Missing CAB index CSV: $CabIndexCsvPath"
}

[void][System.IO.Directory]::CreateDirectory($OutputRoot)
Assert-NoExistingReparsePointUnderRoot -Path $OutputRoot -RootPath $extractedRoot -Description 'OutputRoot'

$missingCabIds = @(Select-String -LiteralPath $MissingCabLogPath -Pattern 'CAB-[0-9a-f]{32}' -AllMatches |
    ForEach-Object { $_.Matches.Value } |
    Sort-Object -Unique)

if ($missingCabIds.Count -eq 0) {
    throw "No missing CAB ids found in $MissingCabLogPath"
}

$indexRows = @(Import-Csv -LiteralPath $CabIndexCsvPath)
$indexByCab = @{}
$candidateByPath = @{}
foreach ($row in $indexRows) {
    Add-RecordToMap -Map $indexByCab -Key ([string]$row.CabId) -Record $row
    Add-RecordToMap -Map $candidateByPath -Key ([string]$row.RelativePath) -Record $row
}

$cabResolutionRows = New-Object System.Collections.Generic.List[object]
$resolvedCabIds = New-Object System.Collections.Generic.HashSet[string]
$actionableCabIds = New-Object System.Collections.Generic.HashSet[string]
foreach ($cab in $missingCabIds) {
    $matches = @()
    if ($indexByCab.ContainsKey($cab)) {
        $matches = @($indexByCab[$cab].ToArray())
    }

    if ($matches.Count -gt 0) {
        $resolvedCabIds.Add($cab) | Out-Null
    }
    if ($matches.Count -gt 0 -and $matches.Count -le $MaxCabFanoutForAction) {
        $actionableCabIds.Add($cab) | Out-Null
    }

    $cabResolutionRows.Add([PSCustomObject]@{
        CabId = $cab
        Status = if ($matches.Count -gt 0) { 'Resolved' } else { 'Unresolved' }
        CandidateBundleFanout = $matches.Count
        Actionable = $matches.Count -gt 0 -and $matches.Count -le $MaxCabFanoutForAction
        Categories = ((Get-UniqueStrings -Values @($matches | Select-Object -ExpandProperty Category)) -join ';')
        ExampleRelativePaths = ((Get-UniqueStrings -Values @($matches | Select-Object -ExpandProperty RelativePath) | Select-Object -First 20) -join ';')
    }) | Out-Null
}

$missingCabSet = @{}
foreach ($cab in $missingCabIds) {
    $missingCabSet[$cab] = $true
}

$candidateRows = New-Object System.Collections.Generic.List[object]
foreach ($relativePath in $candidateByPath.Keys) {
    $rows = @($candidateByPath[$relativePath].ToArray())
    $matchedCabs = @(Get-UniqueStrings -Values @($rows | Where-Object { $missingCabSet.ContainsKey([string]$_.CabId) } | Select-Object -ExpandProperty CabId))
    if ($matchedCabs.Count -eq 0) {
        continue
    }

    $rareMatched = @($matchedCabs | Where-Object { $actionableCabIds.Contains([string]$_) })
    $first = $rows[0]
    $candidateRows.Add([PSCustomObject]@{
        RelativePath = $relativePath
        Category = [string]$first.Category
        Length = [int64]$first.Length
        MatchedMissingCabCount = $matchedCabs.Count
        ActionableMatchedCabCount = $rareMatched.Count
        MatchedMissingCabs = ($matchedCabs -join ';')
        ActionableMatchedCabs = ($rareMatched -join ';')
    }) | Out-Null
}

$candidateRowsArray = @($candidateRows.ToArray())
$selectedRows = New-Object System.Collections.Generic.List[object]
$uncovered = New-Object System.Collections.Generic.HashSet[string]
foreach ($cab in $actionableCabIds) {
    $uncovered.Add($cab) | Out-Null
}

while ($uncovered.Count -gt 0 -and $selectedRows.Count -lt $MaxSelectedCandidates) {
    $best = $null
    $bestCover = @()
    foreach ($candidate in $candidateRowsArray) {
        $candidateCabIds = @(([string]$candidate.ActionableMatchedCabs).Split(';') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $cover = @($candidateCabIds | Where-Object { $uncovered.Contains([string]$_) })
        if ($cover.Count -eq 0) {
            continue
        }
        if ($null -eq $best -or
            $cover.Count -gt $bestCover.Count -or
            ($cover.Count -eq $bestCover.Count -and [int64]$candidate.Length -lt [int64]$best.Length)) {
            $best = $candidate
            $bestCover = $cover
        }
    }

    if ($null -eq $best) {
        break
    }

    $selectedRows.Add([PSCustomObject]@{
        RelativePath = $best.RelativePath
        Category = $best.Category
        Length = $best.Length
        CoveredCabCount = $bestCover.Count
        CoveredCabs = ($bestCover -join ';')
        MatchedMissingCabCount = $best.MatchedMissingCabCount
        MatchedMissingCabs = $best.MatchedMissingCabs
    }) | Out-Null

    foreach ($cab in $bestCover) {
        $uncovered.Remove([string]$cab) | Out-Null
    }
}

$candidateRowsSorted = @($candidateRowsArray | Sort-Object @{Expression = 'ActionableMatchedCabCount'; Descending = $true}, @{Expression = 'MatchedMissingCabCount'; Descending = $true}, @{Expression = 'Length'; Descending = $false}, RelativePath)
$selectedRowsArray = @($selectedRows.ToArray())

$cabResolutionCsvPath = Get-CanonicalPath (Join-Path $OutputRoot "$Name-cab-resolution.csv")
$candidateCsvPath = Get-CanonicalPath (Join-Path $OutputRoot "$Name-candidate-bundles.csv")
$selectedCsvPath = Get-CanonicalPath (Join-Path $OutputRoot "$Name-greedy-selected-bundles.csv")
$summaryJsonPath = Get-CanonicalPath (Join-Path $OutputRoot "$Name-summary.json")
$markdownPath = Get-CanonicalPath (Join-Path $OutputRoot "$Name-report.md")
foreach ($path in @($cabResolutionCsvPath, $candidateCsvPath, $selectedCsvPath, $summaryJsonPath, $markdownPath)) {
    Assert-PathUnderOrEqual -Path $path -RootPath $OutputRoot -Description 'Output file'
}

$cabResolutionRows | Export-Csv -LiteralPath $cabResolutionCsvPath -NoTypeInformation -Encoding UTF8
$candidateRowsSorted | Export-Csv -LiteralPath $candidateCsvPath -NoTypeInformation -Encoding UTF8
$selectedRowsArray | Export-Csv -LiteralPath $selectedCsvPath -NoTypeInformation -Encoding UTF8

$summary = [ordered]@{
    GeneratedAt = [DateTimeOffset]::Now.ToString('O')
    Name = $Name
    MissingCabLogPath = $MissingCabLogPath
    CabIndexCsvPath = $CabIndexCsvPath
    MissingCabCount = $missingCabIds.Count
    ResolvedCabCount = $resolvedCabIds.Count
    UnresolvedCabCount = $missingCabIds.Count - $resolvedCabIds.Count
    ActionableCabCount = $actionableCabIds.Count
    MaxCabFanoutForAction = $MaxCabFanoutForAction
    CandidateBundleCount = $candidateRowsArray.Count
    SelectedBundleCount = $selectedRowsArray.Count
    SelectedCoveredCabCount = @($selectedRowsArray | ForEach-Object { ([string]$_.CoveredCabs).Split(';') } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique).Count
    UncoveredActionableCabCount = $uncovered.Count
    CabResolutionCsv = $cabResolutionCsvPath
    CandidateBundleCsv = $candidateCsvPath
    GreedySelectedBundleCsv = $selectedCsvPath
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $summaryJsonPath -Encoding UTF8

$markdown = @(
    '# Missing CAB Bundle Candidate Report',
    '',
    "Generated: $($summary.GeneratedAt)",
    '',
    '| Metric | Count |',
    '| --- | ---: |',
    "| Missing CAB ids | $($summary.MissingCabCount) |",
    "| Resolved CAB ids | $($summary.ResolvedCabCount) |",
    "| Unresolved CAB ids | $($summary.UnresolvedCabCount) |",
    "| Actionable CAB ids \(fanout <= $MaxCabFanoutForAction\) | $($summary.ActionableCabCount) |",
    "| Candidate bundles | $($summary.CandidateBundleCount) |",
    "| Greedy selected bundles | $($summary.SelectedBundleCount) |",
    "| Greedy covered CAB ids | $($summary.SelectedCoveredCabCount) |",
    "| Uncovered actionable CAB ids | $($summary.UncoveredActionableCabCount) |",
    '',
    '## Top Candidate Bundles',
    '',
    '| Relative path | Category | Length | Actionable CABs | Matched CABs |',
    '| --- | --- | ---: | ---: | ---: |'
)
foreach ($row in ($candidateRowsSorted | Select-Object -First 30)) {
    $markdown += "| ``$($row.RelativePath)`` | $($row.Category) | $($row.Length) | $($row.ActionableMatchedCabCount) | $($row.MatchedMissingCabCount) |"
}
$markdown += @(
    '',
    '## Greedy Selected Bundles',
    '',
    '| Relative path | Category | Length | Covered CABs |',
    '| --- | --- | ---: | ---: |'
)
foreach ($row in $selectedRowsArray) {
    $markdown += "| ``$($row.RelativePath)`` | $($row.Category) | $($row.Length) | $($row.CoveredCabCount) |"
}
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

[PSCustomObject]@{
    Name = $Name
    MissingCabCount = $summary.MissingCabCount
    ResolvedCabCount = $summary.ResolvedCabCount
    UnresolvedCabCount = $summary.UnresolvedCabCount
    ActionableCabCount = $summary.ActionableCabCount
    CandidateBundleCount = $summary.CandidateBundleCount
    SelectedBundleCount = $summary.SelectedBundleCount
    SelectedCoveredCabCount = $summary.SelectedCoveredCabCount
    UncoveredActionableCabCount = $summary.UncoveredActionableCabCount
    Summary = $summaryJsonPath
} | Format-List
