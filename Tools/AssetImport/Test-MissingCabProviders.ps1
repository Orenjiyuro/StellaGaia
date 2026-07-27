$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-McbrTest {
    param(
        [Parameter(Mandatory)][bool] $Condition,
        [Parameter(Mandatory)][string] $Message
    )
    if (-not $Condition) {
        throw "MCBR-T1 test failed: $Message"
    }
}

function Assert-McbrThrows {
    param(
        [Parameter(Mandatory)][scriptblock] $Action,
        [Parameter(Mandatory)][string] $Message
    )
    $threw = $false
    try {
        & $Action
    }
    catch {
        $threw = $true
    }
    Assert-McbrTest $threw $Message
}

$runnerPath = Join-Path $PSScriptRoot 'Find-MissingCabProviders.ps1'
Assert-McbrTest (Test-Path -LiteralPath $runnerPath -PathType Leaf) 'runner is missing'

$runnerText = [IO.File]::ReadAllText($runnerPath)
$forbiddenPatterns = @(
    'Start-Process',
    'AssetRipper.GUI.Free.exe',
    'Unity.exe',
    'UnityHub',
    'Invoke-WebRequest',
    'Invoke-RestMethod',
    'System.Net.Http',
    'Il2Cpp',
    'fallback'
)
foreach ($pattern in $forbiddenPatterns) {
    Assert-McbrTest (-not $runnerText.Contains($pattern, [StringComparison]::OrdinalIgnoreCase)) "forbidden token '$pattern' is present"
}
Assert-McbrTest (-not [regex]::IsMatch($runnerText, '[A-Za-z]:\\(?![^''"]*LocalApplicationData)')) 'machine absolute path is hard-coded'
Assert-McbrTest ($runnerText.Contains('[IO.FileMode]::CreateNew', [StringComparison]::Ordinal)) 'CreateNew output contract is absent'
Assert-McbrTest ($runnerText.Contains('Get-McbrValidatedSourceBoundaries', [StringComparison]::Ordinal)) 'source-boundary validator is absent'
Assert-McbrTest ($runnerText.Contains('[IO.Compression.ZipArchive]', [StringComparison]::Ordinal)) 'APK ZIP entry streaming is absent'
Assert-McbrTest ($runnerText.Contains('[IO.FileAttributes]::ReparsePoint', [StringComparison]::Ordinal)) 'reparse rejection is absent'
Assert-McbrTest ($runnerText.Contains('sourcePathLeakCount', [StringComparison]::Ordinal)) 'portable output leak accounting is absent'

$oldTestMode = $env:STELLAGAIA_MCBR_TEST_MODE
$env:STELLAGAIA_MCBR_TEST_MODE = '1'
try {
    . $runnerPath
}
finally {
    $env:STELLAGAIA_MCBR_TEST_MODE = $oldTestMode
}

$contract = Get-McbrContract
Assert-McbrTest ($contract.schemaVersion -ceq '1.0.0') 'schema version drifted'
Assert-McbrTest ($contract.logPortablePath -ceq 'Extracted/ScriptStrippedFxReconstruction/char_14401/LO1/Logs/assetripper.log') 'frozen log path drifted'
Assert-McbrTest ($contract.logSha256 -ceq '82ffafec53e6cf7c2270453b3054c43fd23022f03de9c307daf312701ee1bd61') 'frozen log SHA drifted'
Assert-McbrTest ($contract.planPortablePath -ceq 'Extracted/ScriptStrippedFxReconstruction/char_14401/T2/reconstruction-plan.json') 'frozen plan path drifted'
Assert-McbrTest ($contract.planSha256 -ceq '48124da20a27f353e5d1e836e931f74ad0180e47bfb3153c56b8ad574c3bc11f') 'frozen plan SHA drifted'
Assert-McbrTest ($contract.outputPortablePath -ceq 'Extracted/MissingCabClosureRecovery/char_14401/LO1/cab-provider-scan.json') 'output path drifted'
Assert-McbrTest ($contract.targetCabCount -eq 25) 'target CAB count drifted'
Assert-McbrTest ($contract.overallTimeoutMilliseconds -eq 1800000) '30-minute timeout is not exact'
Assert-McbrTest ($contract.overallTimeoutMilliseconds -le 1800000) 'timeout exceeds 30 minutes'
Assert-McbrTest (($contract.scanSourceKinds -join ',') -ceq 'PcInstall,AndroidApk,AndroidDataOrCache') 'scan source kinds drifted'
Assert-McbrTest ($contract.maxFileOpenCountPerCandidate -eq 1) 'single-open contract drifted'

$evidence = Read-McbrFrozenEvidence -Contract $contract
Assert-McbrTest ($evidence.targetCabIds.Count -eq 25) 'frozen log did not yield exactly 25 unique CAB IDs'
Assert-McbrTest ((@($evidence.targetCabIds | Sort-Object -Unique).Count) -eq 25) 'CAB IDs are not unique'
Assert-McbrTest ($evidence.unresolvedRequiredGuidCount -eq 940) 'unresolved reference count drifted'
Assert-McbrTest ($evidence.unresolvedClassificationTotal -eq 940) 'unresolved classification does not conserve 940'
Assert-McbrTest ($evidence.placeholderGuid -ceq '0000000deadbeef15deadf00d0000000') 'placeholder GUID drifted'
$expectedClassification = [ordered]@{
    Shader = 304
    Texture = 485
    Mesh = 129
    AnimationClip = 20
    Material = 1
    Controller = 1
}
foreach ($name in $expectedClassification.Keys) {
    Assert-McbrTest ($evidence.unresolvedClassification[$name] -eq $expectedClassification[$name]) "unresolved $name count drifted"
}

$cabA = 'CAB-0123456789abcdef0123456789abcdef'
$cabB = 'CAB-fedcba9876543210fedcba9876543210'
$payload = [Text.Encoding]::ASCII.GetBytes("UnityFS`0prefix-$cabA-middle-archive:/$cabB-tail")
$stream = [IO.MemoryStream]::new($payload, $false)
try {
    $scan = Find-McbrCabTokensInStream -Stream $stream -ChunkSize 7 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $stream.Dispose()
}
Assert-McbrTest ($scan.byteCount -eq $payload.Length) 'chunk scanner byte accounting drifted'
Assert-McbrTest ($scan.matches.Count -eq 2) 'chunk scanner missed or duplicated a cross-chunk CAB'
Assert-McbrTest ($scan.hasUnityBundleHeader) 'Unity bundle header was not detected'
$first = $scan.matches | Where-Object cabId -CEQ $cabA.ToLowerInvariant()
$second = $scan.matches | Where-Object cabId -CEQ $cabB.ToLowerInvariant()
Assert-McbrTest ($null -ne $first -and $first.disposition -ceq 'ProviderCandidate') 'provider candidate classification failed'
Assert-McbrTest ($null -ne $second -and $second.disposition -ceq 'DependencyOnlyReference') 'dependency-only classification failed'

$plainPayload = [Text.Encoding]::ASCII.GetBytes("plain-$cabA")
$plainStream = [IO.MemoryStream]::new($plainPayload, $false)
try {
    $plainScan = Find-McbrCabTokensInStream -Stream $plainStream -ChunkSize 5 -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
}
finally {
    $plainStream.Dispose()
}
Assert-McbrTest ($plainScan.matches.Count -eq 1 -and $plainScan.matches[0].disposition -ceq 'Ambiguous') 'plain string occurrence was promoted to provider evidence'

$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('mcbr-t1-' + [Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tempRoot) | Out-Null
try {
    $pcRoot = Join-Path $tempRoot 'pc'
    $androidRoot = Join-Path $tempRoot 'android-data'
    [IO.Directory]::CreateDirectory($pcRoot) | Out-Null
    [IO.Directory]::CreateDirectory($androidRoot) | Out-Null
    $apkPath = Join-Path $tempRoot 'game.apk'
    $apkFile = [IO.File]::Open($apkPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    try {
        $archive = [IO.Compression.ZipArchive]::new($apkFile, [IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            $entry = $archive.CreateEntry('assets/bundles/provider.unity3d')
            $entryStream = $entry.Open()
            try {
                $entryBytes = [Text.Encoding]::ASCII.GetBytes("UnityFS`0$($cabA)")
                $entryStream.Write($entryBytes, 0, $entryBytes.Length)
            }
            finally {
                $entryStream.Dispose()
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $apkFile.Dispose()
    }

    $manifestPath = Join-Path $tempRoot 'manifest.json'
    $sources = @(
        [pscustomobject][ordered]@{ sourceId = 'pc'; sourceKind = 'PcInstall'; rootPath = $pcRoot },
        [pscustomobject][ordered]@{ sourceId = 'apk'; sourceKind = 'AndroidApk'; rootPath = $apkPath },
        [pscustomobject][ordered]@{ sourceId = 'android'; sourceKind = 'AndroidDataOrCache'; rootPath = $androidRoot }
    )
    $manifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $locatorPath = Join-Path $tempRoot 'locator.json'
    $locator = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        manifestPath = $manifestPath
        baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
        sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources }
    }
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    $boundaries = Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds
    Assert-McbrTest ($boundaries.Count -eq 3) 'three-way source boundary did not validate'
    Assert-McbrTest ((@($boundaries | Where-Object sourceKind -CEQ 'AndroidApk').Count) -eq 1) 'APK boundary is absent'

    $apkBytes = [IO.File]::ReadAllBytes($apkPath)
    $apkScan = Find-McbrCabTokensInApkBytes `
        -Bytes $apkBytes `
        -SourceId 'apk' `
        -RelativePath 'game.apk' `
        -ChunkSize 5 `
        -DeadlineUtc ([DateTimeOffset]::UtcNow.AddMinutes(1))
    Assert-McbrTest ($apkScan.archiveEntryCount -eq 1) 'APK entry stream was not scanned'
    Assert-McbrTest ($apkScan.matches.Count -eq 1) 'APK CAB match accounting drifted'
    Assert-McbrTest ($apkScan.matches[0].archiveEntry -ceq 'assets/bundles/provider.unity3d') 'APK entry path was not portable'
    Assert-McbrTest ($apkScan.matches[0].disposition -ceq 'ProviderCandidate') 'APK provider evidence classification failed'

    $mismatch = $locator | ConvertTo-Json -Depth 8 | ConvertFrom-Json -Depth 8
    $mismatch.sourceBoundary.sources[0].rootPath = $androidRoot
    [IO.File]::WriteAllText($locatorPath, ($mismatch | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'bidirectional mismatch was accepted'

    $singleManifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $sources[0] }
    [IO.File]::WriteAllText($manifestPath, ($singleManifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'single-object sources masquerading as an array was accepted'

    [IO.File]::WriteAllText($manifestPath, ($manifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $junctionPath = Join-Path $tempRoot 'reparse-pc'
    New-Item -ItemType Junction -Path $junctionPath -Target $pcRoot | Out-Null
    $reparseSources = @(
        [pscustomobject][ordered]@{ sourceId = 'pc'; sourceKind = 'PcInstall'; rootPath = $junctionPath },
        $sources[1],
        $sources[2]
    )
    $reparseManifest = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $reparseSources }
    $reparseLocator = [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        manifestPath = $manifestPath
        baseline = [pscustomobject][ordered]@{ disposition = 'Absent'; path = $null }
        sourceBoundary = [pscustomobject][ordered]@{ schemaVersion = '1.0.0'; sources = $reparseSources }
    }
    [IO.File]::WriteAllText($manifestPath, ($reparseManifest | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($locatorPath, ($reparseLocator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'reparse source root was accepted'

    $locator.manifestPath = '//server/share/manifest.json'
    [IO.File]::WriteAllText($locatorPath, ($locator | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Assert-McbrThrows { Get-McbrValidatedSourceBoundaries -LocatorPath $locatorPath -ScanSourceKinds $contract.scanSourceKinds } 'network manifest path was accepted'

    $outPath = Join-Path $tempRoot 'result.json'
    $terminal = New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence
    Write-McbrJsonCreateNew -LiteralPath $outPath -Value $terminal
    Assert-McbrThrows { Write-McbrJsonCreateNew -LiteralPath $outPath -Value $terminal } 'existing output was overwritten'
    $portableJson = [IO.File]::ReadAllText($outPath)
    Assert-McbrTest (-not $portableJson.Contains($tempRoot, [StringComparison]::OrdinalIgnoreCase)) 'portable JSON leaked a synthetic absolute path'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

$terminalKeys = @((New-McbrTerminalResult -Contract $contract -Head ('0' * 40) -Evidence $evidence).PSObject.Properties.Name)
$expectedTerminalKeys = @(
    'schemaVersion', 'artifactId', 'status', 'decision', 'head',
    'elapsedMilliseconds', 'timeoutMilliseconds', 'sourceBoundaryValidated',
    'scanCompleted', 'sourceScanLOUsed', 'targetCabCount', 'targetCabIds',
    'scannedSourceCount', 'scannedFileCount', 'scannedArchiveEntryCount',
    'scannedBytes', 'fileOpenCount', 'cabAccounting', 'matches',
    'inputEvidence', 'sourcePathLeakCount', 'sourceUnchanged', 'blockers',
    'nextAction'
)
Assert-McbrTest (($terminalKeys -join ',') -ceq ($expectedTerminalKeys -join ',')) 'terminal artifact registry shape drifted'
$decisions = @(
    'AllProvidersUniquelyIdentified',
    'PartialProvidersIdentified',
    'AmbiguousProviderCandidates',
    'BlockedScanCap',
    'BlockedSourceBoundary'
)
Assert-McbrTest (($contract.allowedDecisions -join ',') -ceq ($decisions -join ',')) 'decision registry drifted'
Assert-McbrTest (($contract.occurrenceDispositions -join ',') -ceq 'ProviderCandidate,DependencyOnlyReference,Ambiguous') 'occurrence partition drifted'
Assert-McbrTest (($contract.matchPropertyNames -join ',') -ceq 'cabId,disposition,sourceId,sourceKind,relativePath,archiveEntry,offset,fileLength,fileSha256,entryLength,entrySha256,evidence') 'match artifact schema drifted'
Assert-McbrTest (($contract.cabAccountingPropertyNames -join ',') -ceq 'cabId,disposition,totalOccurrences,providerCandidateCount,uniqueProviderCandidateCount,dependencyOnlyReferenceCount,ambiguousCount') 'CAB accounting schema drifted'
Assert-McbrTest ($contract.failureTransitions.FrozenEvidenceMismatch -ceq 'SuppressOutput') 'evidence failure output was not suppressed'
Assert-McbrTest ($contract.failureTransitions.SourceBoundary -ceq 'BlockedSourceBoundary') 'boundary failure transition drifted'
Assert-McbrTest ($contract.failureTransitions.ScanCap -ceq 'BlockedScanCap') 'timeout failure transition drifted'
Assert-McbrTest ($runnerText.Contains('provider + dependencyOnly + ambiguous -eq totalOccurrences', [StringComparison]::Ordinal)) 'occurrence conservation formula is absent'
Assert-McbrTest ($runnerText.Contains('matched + unmatched -eq targetCabCount', [StringComparison]::Ordinal)) 'CAB conservation formula is absent'
Assert-McbrTest ($runnerText.Contains('BlockedSourceBoundary', [StringComparison]::Ordinal)) 'boundary failure transition is absent'
Assert-McbrTest ($runnerText.Contains('BlockedScanCap', [StringComparison]::Ordinal)) 'scan-cap failure transition is absent'

$allUnique = @(1..25 | ForEach-Object { [pscustomobject]@{ disposition = 'UniqueProviderCandidate' } })
$oneMissing = @($allUnique | Select-Object -First 24) + @([pscustomobject]@{ disposition = 'Unmatched' })
$oneAmbiguous = @($allUnique | Select-Object -First 24) + @([pscustomobject]@{ disposition = 'Ambiguous' })
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $allUnique -TargetCabCount 25) -ceq 'AllProvidersUniquelyIdentified') '25/25 unique decision drifted'
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $oneMissing -TargetCabCount 25) -ceq 'PartialProvidersIdentified') 'partial decision drifted'
Assert-McbrTest ((Get-McbrDecisionFromAccounting -Accounting $oneAmbiguous -TargetCabCount 25) -ceq 'AmbiguousProviderCandidates') 'ambiguous decision drifted'
Assert-McbrThrows { Get-McbrDecisionFromAccounting -Accounting @() -TargetCabCount 25 } 'zero-row accounting was accepted'

Write-Output 'MCBR-T1 focused tests passed: cabIds=25 unresolved=940 chunkBoundary=GREEN apkStream=GREEN sourceBoundary=GREEN createNew=GREEN'
