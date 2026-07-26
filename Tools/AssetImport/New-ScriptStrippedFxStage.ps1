[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-SfxrT2Sha256 {
    param([Parameter(Mandatory)][string] $LiteralPath)
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-SfxrT2PortablePath {
    param(
        [Parameter(Mandatory)][string] $Root,
        [Parameter(Mandatory)][string] $Path
    )
    $relative = [IO.Path]::GetRelativePath($Root, $Path).Replace('\', '/')
    if ([IO.Path]::IsPathRooted($relative) -or $relative -eq '..' -or $relative.StartsWith('../', [StringComparison]::Ordinal)) {
        throw 'SFXR-T2 path escaped its required root.'
    }
    return $relative
}

function Assert-SfxrT2NoReparse {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][string] $RequiredRoot
    )
    $root = (Get-Item -LiteralPath $RequiredRoot -Force).FullName
    $full = (Get-Item -LiteralPath $LiteralPath -Force).FullName
    if (-not ($full.Equals($root, [StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($root.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase))) {
        throw 'SFXR-T2 path is outside its required root.'
    }
    $cursor = $full
    while ($true) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'SFXR-T2 encountered a reparse point.'
        }
        if ($cursor.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) {
            throw 'SFXR-T2 path chain is incomplete.'
        }
        $cursor = $parent.FullName
    }
}

function Test-SfxrT2TextAsset {
    param([Parameter(Mandatory)][string] $LiteralPath)
    return [IO.Path]::GetExtension($LiteralPath).ToLowerInvariant() -in @(
        '.anim',
        '.asset',
        '.controller',
        '.mat',
        '.overridecontroller',
        '.playable',
        '.prefab',
        '.txt',
        '.json'
    )
}

function Get-SfxrT2DocumentMatches {
    param([Parameter(Mandatory)][string] $Text)
    return @(
        [regex]::Matches(
            $Text,
            '(?ms)^--- !u!(?<classId>\d+) &(?<fileId>-?\d+)[^\r\n]*(?:\r?\n|$).*?(?=^--- !u!|\z)')
    )
}

function Remove-SfxrT2MonoBehaviours {
    param([Parameter(Mandatory)][string] $Text)

    $documents = Get-SfxrT2DocumentMatches -Text $Text
    $monoDocuments = @($documents | Where-Object { $_.Groups['classId'].Value -ceq '114' })
    if ($monoDocuments.Count -eq 0) {
        return [pscustomobject]@{
            status = 'Unchanged'
            text = $Text
            strippedFileIds = @()
            componentEntriesRemoved = 0
            danglingFileIds = @()
        }
    }

    $strippedIds = @($monoDocuments | ForEach-Object { $_.Groups['fileId'].Value })
    if (@($strippedIds | Sort-Object -Unique).Count -ne $strippedIds.Count) {
        return [pscustomobject]@{
            status = 'Ambiguous'
            text = $null
            strippedFileIds = $strippedIds
            componentEntriesRemoved = 0
            danglingFileIds = $strippedIds
        }
    }

    $builder = [Text.StringBuilder]::new($Text)
    foreach ($document in @($monoDocuments | Sort-Object Index -Descending)) {
        [void]$builder.Remove($document.Index, $document.Length)
    }
    $rewritten = $builder.ToString()
    $removedEntries = 0
    foreach ($fileId in $strippedIds) {
        $escaped = [regex]::Escape($fileId)
        $componentPattern = "(?m)^[ \t]*-[ \t]+component:[ \t]*\{fileID:[ \t]*$escaped\}[ \t]*(?:\r?\n|$)"
        $componentMatches = [regex]::Matches($rewritten, $componentPattern)
        $gameObjectComponentMatchCount = 0
        foreach ($gameObjectDocument in @(Get-SfxrT2DocumentMatches -Text $rewritten | Where-Object {
            $_.Groups['classId'].Value -ceq '1'
        })) {
            if (
                $gameObjectDocument.Value -match '(?m)^\s*m_Component:\s*$' -and
                [regex]::IsMatch($gameObjectDocument.Value, $componentPattern)
            ) {
                $gameObjectComponentMatchCount++
            }
        }
        $sourceDocument = @($monoDocuments | Where-Object { $_.Groups['fileId'].Value -ceq $fileId })[0].Value
        $gameObjectMatch = [regex]::Match($sourceDocument, '(?m)^\s*m_GameObject:\s*\{fileID:\s*(-?\d+)\}')
        $requiresComponentEntry = $gameObjectMatch.Success -and $gameObjectMatch.Groups[1].Value -cne '0'
        if (
            $componentMatches.Count -ne $gameObjectComponentMatchCount -or
            ($requiresComponentEntry -and $gameObjectComponentMatchCount -ne 1) -or
            (-not $requiresComponentEntry -and $gameObjectComponentMatchCount -gt 1)
        ) {
            return [pscustomobject]@{
                status = 'Ambiguous'
                text = $null
                strippedFileIds = $strippedIds
                componentEntriesRemoved = $removedEntries
                danglingFileIds = @($fileId)
            }
        }
        if ($componentMatches.Count -eq 1) {
            $rewritten = [regex]::Replace($rewritten, $componentPattern, '', 1)
            $removedEntries++
        }
    }

    $dangling = @()
    foreach ($fileId in $strippedIds) {
        if ([regex]::IsMatch($rewritten, "\{fileID:\s*$([regex]::Escape($fileId))(?=[,}])")) {
            $dangling += $fileId
        }
    }
    if ($dangling.Count -gt 0) {
        return [pscustomobject]@{
            status = 'Ambiguous'
            text = $null
            strippedFileIds = $strippedIds
            componentEntriesRemoved = $removedEntries
            danglingFileIds = @($dangling | Sort-Object -Unique)
        }
    }

    return [pscustomobject]@{
        status = 'Stripped'
        text = $rewritten
        strippedFileIds = $strippedIds
        componentEntriesRemoved = $removedEntries
        danglingFileIds = @()
    }
}

function New-SfxrT2CoreResult {
    return [pscustomobject][ordered]@{
        decision = 'BlockedExportIdentityDrift'
        blockers = @()
        modelSeedCount = 0
        animationSeedCount = 0
        fxSeedCount = 0
        totalSeedCount = 0
        attackAnimationCandidateCount = 0
        attackFxCandidateCount = 0
        guidMappingCount = 0
        duplicateGuidCount = 0
        builtinReferenceCount = 0
        builtinGuidsUsed = @()
        excludedScriptReferenceCount = 0
        unresolvedRequiredGuidCount = 0
        unresolvedReferences = @()
        closureAssetCount = 0
        closureTotalBytes = [int64]0
        closureRows = @()
        dependencyEdges = @()
        monoBehaviourDocumentCount = 0
        strippedMonoBehaviourDocumentCount = 0
        componentEntriesRemoved = 0
        danglingStrippedFileIdCount = 0
        particleSystemDocumentCount = 0
        stagedParticleSystemDocumentCount = 0
        rendererDocumentCount = 0
        stagedRendererDocumentCount = 0
        stagedMonoBehaviourDocumentCount = 0
        stagedScriptReferenceCount = 0
        generatedScriptFileCount = 0
        retainedGuidReferenceCount = 0
        retainedGuidResolvedCount = 0
        outputReparseCount = 0
        stripRows = @()
    }
}

function Invoke-SfxrStageCore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $AssetsRoot,
        [Parameter(Mandatory)][string] $StagedRoot
    )

    $result = New-SfxrT2CoreResult
    $assetsItem = Get-Item -LiteralPath $AssetsRoot -Force
    if ($assetsItem -isnot [IO.DirectoryInfo]) {
        $result.blockers = @('AssetsRootMissing')
        return $result
    }
    Assert-SfxrT2NoReparse -LiteralPath $assetsItem.FullName -RequiredRoot $assetsItem.FullName
    if (Test-Path -LiteralPath $StagedRoot) {
        $result.blockers = @('StagedRootAlreadyExists')
        return $result
    }

    $builtinAllowlist = @(
        '0000000000000000d000000000000000',
        '0000000000000000e000000000000000',
        '0000000000000000f000000000000000'
    )
    $rendererClassIds = @('23', '25', '96', '120', '137', '199', '212')
    $metaFiles = @(Get-ChildItem -LiteralPath $AssetsRoot -Recurse -File -Filter '*.meta' -Force)
    $guidMap = @{}
    $duplicateGuids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($metaFile in $metaFiles) {
        Assert-SfxrT2NoReparse -LiteralPath $metaFile.FullName -RequiredRoot $AssetsRoot
        $metaText = [IO.File]::ReadAllText($metaFile.FullName)
        $guidMatches = [regex]::Matches($metaText, '(?im)^guid:\s*([0-9a-f]{32})\s*$')
        if ($guidMatches.Count -ne 1) {
            $result.blockers = @('MalformedMetaGuid')
            return $result
        }
        $guid = $guidMatches[0].Groups[1].Value.ToLowerInvariant()
        $assetPath = $metaFile.FullName.Substring(0, $metaFile.FullName.Length - 5)
        if ($guidMap.ContainsKey($guid)) {
            [void]$duplicateGuids.Add($guid)
        } else {
            $guidMap[$guid] = [pscustomobject]@{
                guid = $guid
                assetPath = $assetPath
                metaPath = $metaFile.FullName
                relativePath = Get-SfxrT2PortablePath -Root $AssetsRoot -Path $assetPath
                isFile = Test-Path -LiteralPath $assetPath -PathType Leaf
            }
        }
    }
    $result.guidMappingCount = $guidMap.Count
    $result.duplicateGuidCount = $duplicateGuids.Count
    if ($duplicateGuids.Count -gt 0) {
        $result.decision = 'BlockedExportIdentityDrift'
        $result.blockers = @('DuplicateGuid')
        return $result
    }

    $modelRelative = 'assetbundles/actor/character/14401/models/14401.prefab'
    $animationDirectory = Join-Path $AssetsRoot 'assetbundles\actor\character\14401\animations'
    $fxDirectory = Join-Path $AssetsRoot 'assetbundles\actor\character\14401\fx'
    $modelPath = Join-Path $AssetsRoot $modelRelative
    $animations = @(Get-ChildItem -LiteralPath $animationDirectory -File -Filter '*.anim' -Force | Sort-Object Name)
    $fxPrefabs = @(Get-ChildItem -LiteralPath $fxDirectory -File -Filter '*.prefab' -Force | Sort-Object Name)
    $result.modelSeedCount = if (Test-Path -LiteralPath $modelPath -PathType Leaf) { 1 } else { 0 }
    $result.animationSeedCount = $animations.Count
    $result.fxSeedCount = $fxPrefabs.Count
    $result.totalSeedCount = $result.modelSeedCount + $result.animationSeedCount + $result.fxSeedCount
    $result.attackAnimationCandidateCount = @($animations | Where-Object { $_.BaseName -match '(?i)attack' }).Count
    $result.attackFxCandidateCount = @($fxPrefabs | Where-Object { $_.BaseName -match '(?i)attack' }).Count
    if ($result.modelSeedCount -ne 1 -or $result.animationSeedCount -ne 61 -or $result.fxSeedCount -ne 95) {
        $result.decision = 'BlockedExportIdentityDrift'
        $result.blockers = @('SeedConservationFailure')
        return $result
    }

    $seedPaths = @($modelPath) + @($animations.FullName) + @($fxPrefabs.FullName)
    foreach ($seedPath in $seedPaths) {
        if (-not (Test-Path -LiteralPath ($seedPath + '.meta') -PathType Leaf)) {
            $result.decision = 'BlockedExportIdentityDrift'
            $result.blockers = @('SeedMetaMissing')
            return $result
        }
    }

    $queue = [Collections.Generic.Queue[string]]::new()
    foreach ($seedPath in $seedPaths) {
        $queue.Enqueue((Get-SfxrT2PortablePath -Root $AssetsRoot -Path $seedPath))
    }
    $closure = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
    $edges = [Collections.Generic.List[object]]::new()
    $unresolved = [Collections.Generic.List[object]]::new()
    $builtinUsed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $excludedScriptReferences = 0
    $monoCount = 0
    $particleCount = 0
    $rendererCount = 0

    while ($queue.Count -gt 0) {
        $relative = $queue.Dequeue()
        if ($closure.ContainsKey($relative)) {
            continue
        }
        $assetPath = [IO.Path]::GetFullPath((Join-Path $AssetsRoot $relative))
        if (-not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
            $unresolved.Add([pscustomobject]@{ from = $relative; guid = $null; reason = 'AssetMissing' })
            continue
        }
        Assert-SfxrT2NoReparse -LiteralPath $assetPath -RequiredRoot $AssetsRoot
        $extension = [IO.Path]::GetExtension($assetPath).ToLowerInvariant()
        if ($extension -in @('.cs', '.asmdef')) {
            $unresolved.Add([pscustomobject]@{ from = $relative; guid = $null; reason = 'GeneratedScriptDependencyForbidden' })
            continue
        }
        $assetItem = Get-Item -LiteralPath $assetPath -Force
        $closure[$relative] = [pscustomobject]@{
            relativePath = $relative
            length = [int64]$assetItem.Length
            sha256 = Get-SfxrT2Sha256 -LiteralPath $assetPath
            extension = $extension
        }
        if (-not (Test-SfxrT2TextAsset -LiteralPath $assetPath)) {
            continue
        }

        $text = [IO.File]::ReadAllText($assetPath)
        $documents = Get-SfxrT2DocumentMatches -Text $text
        $monoCount += @($documents | Where-Object { $_.Groups['classId'].Value -ceq '114' }).Count
        $particleCount += @($documents | Where-Object { $_.Groups['classId'].Value -ceq '198' }).Count
        $rendererCount += @($documents | Where-Object { $_.Groups['classId'].Value -in $rendererClassIds }).Count

        $lines = $text -split '(?<=\n)'
        $currentClassId = ''
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $line = $lines[$lineIndex]
            $header = [regex]::Match($line, '^--- !u!(\d+) &-?\d+')
            if ($header.Success) {
                $currentClassId = $header.Groups[1].Value
            }
            $guidMatches = [regex]::Matches($line, '(?i)guid:\s*([0-9a-f]{32})')
            foreach ($guidMatch in $guidMatches) {
                $guid = $guidMatch.Groups[1].Value.ToLowerInvariant()
                if ($currentClassId -ceq '114' -and $line -match '^\s*m_Script:') {
                    $excludedScriptReferences++
                    continue
                }
                if ($guid.Contains('deadbeef', [StringComparison]::OrdinalIgnoreCase)) {
                    $unresolved.Add([pscustomobject]@{ from = $relative; guid = $guid; reason = 'DeadbeefPlaceholder'; line = $lineIndex + 1 })
                    continue
                }
                if ($builtinAllowlist -contains $guid) {
                    [void]$builtinUsed.Add($guid)
                    $edges.Add([pscustomobject]@{ from = $relative; guid = $guid; to = $null; disposition = 'BuiltinAllowlist' })
                    continue
                }
                if (-not $guidMap.ContainsKey($guid) -or -not $guidMap[$guid].isFile) {
                    $unresolved.Add([pscustomobject]@{ from = $relative; guid = $guid; reason = 'GuidNotResolved'; line = $lineIndex + 1 })
                    continue
                }
                $target = $guidMap[$guid]
                if ([IO.Path]::GetExtension($target.assetPath).ToLowerInvariant() -in @('.cs', '.asmdef')) {
                    $unresolved.Add([pscustomobject]@{ from = $relative; guid = $guid; reason = 'GeneratedScriptDependencyForbidden'; line = $lineIndex + 1 })
                    continue
                }
                $edges.Add([pscustomobject]@{ from = $relative; guid = $guid; to = $target.relativePath; disposition = 'Resolved' })
                $queue.Enqueue([string]$target.relativePath)
            }
        }
    }

    $result.builtinReferenceCount = @($edges | Where-Object { $_.disposition -ceq 'BuiltinAllowlist' }).Count
    $result.builtinGuidsUsed = @($builtinUsed | Sort-Object)
    $result.excludedScriptReferenceCount = $excludedScriptReferences
    $result.unresolvedRequiredGuidCount = $unresolved.Count
    $result.unresolvedReferences = @($unresolved)
    $result.dependencyEdges = @($edges | Sort-Object from, guid, to -Unique)
    $result.closureAssetCount = $closure.Count
    $result.closureTotalBytes = [int64](($closure.Values | Measure-Object length -Sum).Sum)
    $result.closureRows = @($closure.Values | Sort-Object relativePath)
    $result.monoBehaviourDocumentCount = $monoCount
    $result.particleSystemDocumentCount = $particleCount
    $result.rendererDocumentCount = $rendererCount
    if ($unresolved.Count -gt 0) {
        $result.decision = 'BlockedRequiredVisualDependency'
        $result.blockers = @('UnresolvedRequiredGuid')
        return $result
    }

    $temporaryStage = $StagedRoot + '.tmp-' + [Guid]::NewGuid().ToString('N')
    [IO.Directory]::CreateDirectory($temporaryStage) | Out-Null
    $stripRows = [Collections.Generic.List[object]]::new()
    $strippedCount = 0
    $componentEntriesRemoved = 0
    $danglingCount = 0
    $ambiguous = $false
    try {
        foreach ($row in @($closure.Values | Sort-Object relativePath)) {
            $sourcePath = Join-Path $AssetsRoot $row.relativePath.Replace('/', '\')
            $destinationPath = Join-Path $temporaryStage $row.relativePath.Replace('/', '\')
            [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destinationPath)) | Out-Null
            if (Test-SfxrT2TextAsset -LiteralPath $sourcePath) {
                $sourceText = [IO.File]::ReadAllText($sourcePath)
                $rewrite = Remove-SfxrT2MonoBehaviours -Text $sourceText
                if ($rewrite.status -ceq 'Ambiguous') {
                    $ambiguous = $true
                    $danglingCount += @($rewrite.danglingFileIds).Count
                    break
                }
                [IO.File]::WriteAllText($destinationPath, $rewrite.text, [Text.UTF8Encoding]::new($false))
                $strippedCount += @($rewrite.strippedFileIds).Count
                $componentEntriesRemoved += [int]$rewrite.componentEntriesRemoved
                if (@($rewrite.strippedFileIds).Count -gt 0) {
                    $stripRows.Add([pscustomobject]@{
                        relativePath = [string]$row.relativePath
                        strippedFileIds = @($rewrite.strippedFileIds)
                        componentEntriesRemoved = [int]$rewrite.componentEntriesRemoved
                    })
                }
            } else {
                [IO.File]::Copy($sourcePath, $destinationPath, $false)
            }
            [IO.File]::Copy($sourcePath + '.meta', $destinationPath + '.meta', $false)
        }
        if ($ambiguous) {
            $result.decision = 'BlockedAmbiguousYamlRewrite'
            $result.blockers = @('RetainedDocumentReferencesStrippedFileId')
            $result.danglingStrippedFileIdCount = $danglingCount
            return $result
        }

        $stagedFiles = @(Get-ChildItem -LiteralPath $temporaryStage -Recurse -File -Force)
        $stagedMonoCount = 0
        $stagedScriptCount = 0
        $stagedParticleCount = 0
        $stagedRendererCount = 0
        $generatedScriptCount = @($stagedFiles | Where-Object { $_.Extension.ToLowerInvariant() -in @('.cs', '.asmdef') }).Count
        foreach ($file in $stagedFiles) {
            if (-not (Test-SfxrT2TextAsset -LiteralPath $file.FullName)) {
                continue
            }
            $text = [IO.File]::ReadAllText($file.FullName)
            $documents = Get-SfxrT2DocumentMatches -Text $text
            $stagedMonoCount += @($documents | Where-Object { $_.Groups['classId'].Value -ceq '114' }).Count
            $stagedParticleCount += @($documents | Where-Object { $_.Groups['classId'].Value -ceq '198' }).Count
            $stagedRendererCount += @($documents | Where-Object { $_.Groups['classId'].Value -in $rendererClassIds }).Count
            $stagedScriptCount += [regex]::Matches($text, '(?m)^\s*m_Script:').Count
        }
        $result.strippedMonoBehaviourDocumentCount = $strippedCount
        $result.componentEntriesRemoved = $componentEntriesRemoved
        $result.danglingStrippedFileIdCount = 0
        $result.stagedMonoBehaviourDocumentCount = $stagedMonoCount
        $result.stagedScriptReferenceCount = $stagedScriptCount
        $result.generatedScriptFileCount = $generatedScriptCount
        $result.stagedParticleSystemDocumentCount = $stagedParticleCount
        $result.stagedRendererDocumentCount = $stagedRendererCount
        $result.stripRows = @($stripRows)
        if (
            $stagedMonoCount -ne 0 -or
            $stagedScriptCount -ne 0 -or
            $generatedScriptCount -ne 0 -or
            $stagedParticleCount -ne $particleCount -or
            $stagedRendererCount -ne $rendererCount
        ) {
            $result.decision = 'BlockedAmbiguousYamlRewrite'
            $result.blockers = @('StagedConservationFailure')
            return $result
        }

        $stagedMeta = @{}
        foreach ($metaFile in @(Get-ChildItem -LiteralPath $temporaryStage -Recurse -File -Filter '*.meta' -Force)) {
            $match = [regex]::Match([IO.File]::ReadAllText($metaFile.FullName), '(?im)^guid:\s*([0-9a-f]{32})\s*$')
            if ($match.Success) {
                $stagedMeta[$match.Groups[1].Value.ToLowerInvariant()] = $true
            }
        }
        $retainedGuidCount = 0
        $retainedResolvedCount = 0
        foreach ($file in $stagedFiles) {
            if (-not (Test-SfxrT2TextAsset -LiteralPath $file.FullName)) {
                continue
            }
            $text = [IO.File]::ReadAllText($file.FullName)
            foreach ($match in [regex]::Matches($text, '(?i)guid:\s*([0-9a-f]{32})')) {
                $guid = $match.Groups[1].Value.ToLowerInvariant()
                $retainedGuidCount++
                if ($builtinAllowlist -contains $guid -or $stagedMeta.ContainsKey($guid)) {
                    $retainedResolvedCount++
                }
            }
        }
        $result.retainedGuidReferenceCount = $retainedGuidCount
        $result.retainedGuidResolvedCount = $retainedResolvedCount
        if ($retainedResolvedCount -ne $retainedGuidCount) {
            $result.decision = 'BlockedRequiredVisualDependency'
            $result.blockers = @('StagedGuidResolutionFailure')
            return $result
        }

        [IO.Directory]::Move($temporaryStage, $StagedRoot)
        $result.outputReparseCount = @(
            Get-ChildItem -LiteralPath $StagedRoot -Recurse -Force |
                Where-Object { ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 }
        ).Count
        if ($result.outputReparseCount -ne 0) {
            $result.decision = 'BlockedExportIdentityDrift'
            $result.blockers = @('OutputReparsePoint')
            return $result
        }
        $result.decision = 'ReadyForScriptStrippedUnityStaging'
        $result.blockers = @()
        return $result
    } finally {
        if (Test-Path -LiteralPath $temporaryStage) {
            Remove-Item -LiteralPath $temporaryStage -Recurse -Force
        }
        if ($result.decision -cne 'ReadyForScriptStrippedUnityStaging' -and (Test-Path -LiteralPath $StagedRoot)) {
            Remove-Item -LiteralPath $StagedRoot -Recurse -Force
        }
    }
}

function Get-SfxrT2TreeIdentity {
    param([Parameter(Mandatory)][string] $Root)

    $rows = @(
        Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    relativePath = Get-SfxrT2PortablePath -Root $Root -Path $_.FullName
                    length = [int64]$_.Length
                    sha256 = Get-SfxrT2Sha256 -LiteralPath $_.FullName
                }
            } |
            Sort-Object relativePath
    )
    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append("sfxr-export-tree/1`n")
    foreach ($row in $rows) {
        [void]$builder.Append($row.relativePath)
        [void]$builder.Append([char]0)
        [void]$builder.Append([string]$row.length)
        [void]$builder.Append([char]0)
        [void]$builder.Append($row.sha256)
        [void]$builder.Append("`n")
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($builder.ToString())
    return [pscustomobject][ordered]@{
        algorithm = 'sha256'
        encoding = 'utf8-no-bom'
        domain = 'sfxr-export-tree/1'
        ordering = 'relativePath-ordinal'
        rowEncoding = 'relativePath NUL decimalLength NUL lowercaseSha256 LF'
        fileCount = $rows.Count
        byteCount = [int64](($rows | Measure-Object length -Sum).Sum)
        fingerprint = ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
    }
}

function Write-SfxrT2JsonCreateNew {
    param(
        [Parameter(Mandatory)][string] $LiteralPath,
        [Parameter(Mandatory)][object] $Value
    )
    $json = $Value | ConvertTo-Json -Depth 100
    if ([regex]::Matches($json, '(?i)(?:[A-Z]:[\\/]|[\\/]{2}[^\\/])').Count -ne 0) {
        throw 'SFXR-T2 portable JSON contains an absolute path.'
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

if ($env:STELLAGAIA_SFXR_T2_DEFINITIONS_ONLY -ceq '1') {
    return
}

$contract = [pscustomobject][ordered]@{
    requiredHead = 'a1108b5a10244fe05958c04571efe9a9fd163f60'
    terminalSha256 = 'ab797c994e896d7ff8e914bdaff3bda14ef7c8cb7299f85857b3ceea8abbb94b'
    logSha256 = '82ffafec53e6cf7c2270453b3054c43fd23022f03de9c307daf312701ee1bd61'
    expectedExportFileCount = 1966
    expectedExportBytes = [int64]414098635
    expectedAnimationSeedCount = 61
    expectedFxSeedCount = 95
}
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$lo1Root = Join-Path $repoRoot 'Extracted\ScriptStrippedFxReconstruction\char_14401\LO1'
$terminalInput = Join-Path $lo1Root 'terminal-result.json'
$logInput = Join-Path $lo1Root 'Logs\assetripper.log'
$exportRoot = Join-Path $lo1Root 'Export'
$assetsRoot = Join-Path $exportRoot 'ExportedProject\Assets'
$t2Root = Join-Path $repoRoot 'Extracted\ScriptStrippedFxReconstruction\char_14401\T2'
$stagedRoot = Join-Path $t2Root 'StagedAssets'
$planPath = Join-Path $t2Root 'reconstruction-plan.json'
$terminalPath = Join-Path $t2Root 'terminal-result.json'

if (
    (git -C $repoRoot rev-parse HEAD).Trim() -cne $contract.requiredHead -or
    (git -C $repoRoot rev-parse '@{upstream}').Trim() -cne $contract.requiredHead
) {
    throw 'SFXR-T2 Git baseline mismatch.'
}
if (Test-Path -LiteralPath $t2Root) {
    throw 'SFXR-T2 output root already exists.'
}
if (
    (Get-SfxrT2Sha256 -LiteralPath $terminalInput) -cne $contract.terminalSha256 -or
    (Get-SfxrT2Sha256 -LiteralPath $logInput) -cne $contract.logSha256
) {
    throw 'SFXR-T2 fixed evidence identity mismatch.'
}
if (@(Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.ProcessName -like 'AssetRipper*' -or
    $_.ProcessName -in @('Unity', 'UnityShaderCompiler', 'UnityCrashHandler64')
}).Count -ne 0) {
    throw 'SFXR-T2 forbidden process is running.'
}

$preTree = Get-SfxrT2TreeIdentity -Root $exportRoot
if (
    $preTree.fileCount -ne $contract.expectedExportFileCount -or
    $preTree.byteCount -ne $contract.expectedExportBytes
) {
    throw 'SFXR-T2 Export identity count mismatch.'
}

[IO.Directory]::CreateDirectory($t2Root) | Out-Null
$core = Invoke-SfxrStageCore -AssetsRoot $assetsRoot -StagedRoot $stagedRoot
$postTree = Get-SfxrT2TreeIdentity -Root $exportRoot
if ($postTree.fingerprint -cne $preTree.fingerprint) {
    if (Test-Path -LiteralPath $stagedRoot) {
        Remove-Item -LiteralPath $stagedRoot -Recurse -Force
    }
    $core.decision = 'BlockedExportIdentityDrift'
    $core.blockers = @('ExportTreeChangedDuringOperation')
}

$plan = [pscustomobject][ordered]@{
    schemaVersion = 'sfxr-reconstruction-plan/1.0.0'
    artifactId = 'SFXR-T2-PLAN-char_14401'
    head = $contract.requiredHead
    inputEvidence = [pscustomobject][ordered]@{
        terminalRelativePath = 'Extracted/ScriptStrippedFxReconstruction/char_14401/LO1/terminal-result.json'
        terminalSha256 = $contract.terminalSha256
        logRelativePath = 'Extracted/ScriptStrippedFxReconstruction/char_14401/LO1/Logs/assetripper.log'
        logSha256 = $contract.logSha256
    }
    exportTreeBefore = $preTree
    exportTreeAfter = $postTree
    exportUnchanged = $preTree.fingerprint -ceq $postTree.fingerprint
    seedAccounting = [pscustomobject][ordered]@{
        model = $core.modelSeedCount
        animations = $core.animationSeedCount
        fxPrefabs = $core.fxSeedCount
        total = $core.totalSeedCount
    }
    attackCandidates = [pscustomobject][ordered]@{
        animations = $core.attackAnimationCandidateCount
        fxPrefabs = $core.attackFxCandidateCount
    }
    guidMappingCount = $core.guidMappingCount
    duplicateGuidCount = $core.duplicateGuidCount
    builtinReferenceCount = $core.builtinReferenceCount
    builtinGuidsUsed = @($core.builtinGuidsUsed)
    excludedScriptReferenceCount = $core.excludedScriptReferenceCount
    unresolvedRequiredGuidCount = $core.unresolvedRequiredGuidCount
    unresolvedReferences = @($core.unresolvedReferences)
    closureAssetCount = $core.closureAssetCount
    closureTotalBytes = $core.closureTotalBytes
    closureRows = @($core.closureRows)
    dependencyEdges = @($core.dependencyEdges)
    stripRows = @($core.stripRows)
    validationCounts = [pscustomobject][ordered]@{
        monoBehaviourDocuments = $core.monoBehaviourDocumentCount
        strippedMonoBehaviourDocuments = $core.strippedMonoBehaviourDocumentCount
        stagedMonoBehaviourDocuments = $core.stagedMonoBehaviourDocumentCount
        stagedScriptReferences = $core.stagedScriptReferenceCount
        generatedScriptFiles = $core.generatedScriptFileCount
        danglingStrippedFileIds = $core.danglingStrippedFileIdCount
        particleSystemDocuments = $core.particleSystemDocumentCount
        stagedParticleSystemDocuments = $core.stagedParticleSystemDocumentCount
        rendererDocuments = $core.rendererDocumentCount
        stagedRendererDocuments = $core.stagedRendererDocumentCount
        componentEntriesRemoved = $core.componentEntriesRemoved
        retainedGuidReferences = $core.retainedGuidReferenceCount
        retainedGuidReferencesResolved = $core.retainedGuidResolvedCount
    }
    outputReparseCount = $core.outputReparseCount
    sourcePathLeakCount = 0
    decision = $core.decision
    blockers = @($core.blockers)
    nextAction = 'AwaitSFXRT2TotalControlAudit'
}
Write-SfxrT2JsonCreateNew -LiteralPath $planPath -Value $plan

$terminal = [pscustomobject][ordered]@{
    schemaVersion = 'sfxr-stage-terminal/1.0.0'
    artifactId = 'SFXR-T2-TERMINAL-char_14401'
    status = if ($core.decision -ceq 'ReadyForScriptStrippedUnityStaging') { 'Ready' } else { 'Blocked' }
    decision = $core.decision
    planRelativePath = 'reconstruction-plan.json'
    planSha256 = Get-SfxrT2Sha256 -LiteralPath $planPath
    exportUnchanged = $preTree.fingerprint -ceq $postTree.fingerprint
    modelSeedCount = $core.modelSeedCount
    animationSeedCount = $core.animationSeedCount
    fxSeedCount = $core.fxSeedCount
    closureAssetCount = $core.closureAssetCount
    monoBehaviourDocumentCount = $core.monoBehaviourDocumentCount
    stagedMonoBehaviourDocumentCount = $core.stagedMonoBehaviourDocumentCount
    stagedScriptReferenceCount = $core.stagedScriptReferenceCount
    generatedScriptFileCount = $core.generatedScriptFileCount
    danglingStrippedFileIdCount = $core.danglingStrippedFileIdCount
    unresolvedRequiredGuidCount = $core.unresolvedRequiredGuidCount
    outputReparseCount = $core.outputReparseCount
    sourcePathLeakCount = 0
    blockers = @($core.blockers)
    nextAction = 'AwaitSFXRT2TotalControlAudit'
}
Write-SfxrT2JsonCreateNew -LiteralPath $terminalPath -Value $terminal
$terminal | ConvertTo-Json -Depth 20
if ($terminal.status -ceq 'Blocked') {
    exit 1
}
exit 0
