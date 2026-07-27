[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Stop-Pefp {
    param(
        [Parameter(Mandatory)]
        [string]$Code,

        [string]$Detail
    )

    $message = "PEFP:$Code"
    if (-not [string]::IsNullOrWhiteSpace($Detail)) {
        $message += ":$Detail"
    }

    throw [InvalidOperationException]::new($message)
}

function Get-PefpAuthorizedInputs {
    return @(
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d'; ExpectedLength = [int64]4909859; ExpectedSha256 = 'cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d'; ExpectedLength = [int64]6682; ExpectedSha256 = '8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_models.unity3d'; ExpectedLength = [int64]3080984; ExpectedSha256 = '66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_animations.unity3d'; ExpectedLength = [int64]37819874; ExpectedSha256 = '8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d'; ExpectedLength = [int64]11641; ExpectedSha256 = '0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d'; ExpectedLength = [int64]3576; ExpectedSha256 = '0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f' }
        [pscustomobject]@{ Partition = 'SFXR'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401_fx.unity3d'; ExpectedLength = [int64]1944422; ExpectedSha256 = '02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/char_14401.unity3d'; ExpectedLength = [int64]259486; ExpectedSha256 = 'c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_water.unity3d'; ExpectedLength = [int64]29687342; ExpectedSha256 = 'e46b6016e7fee31e4fdf592ee9cf04c2c424928d160dc20c4656e2f3e9fa75d0' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/actor_common.unity3d'; ExpectedLength = [int64]10821270; ExpectedSha256 = '8c485e107b27b5ff6862c79c61ba683eae7c46ed5fdd8afb203e8ff7de6dcf64' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_misc.unity3d'; ExpectedLength = [int64]9009665; ExpectedSha256 = '26be1a7b839d6344293c1a0fad7551a53f331c45beb409362c7f5264ea21b577' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/global.unity3d'; ExpectedLength = [int64]227310; ExpectedSha256 = 'd3b70fda5eae75601e91868e2b09d2b2e8900978eea654c7aea3eb63bdfcffdc' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'xtlr_Data/StreamingAssets/InstallResource/fx_actorcommon.unity3d'; ExpectedLength = [int64]464072; ExpectedSha256 = '8b56dcb70142226a40c2819c06eab6d4a890946e0ec03ecd03690f24e2764340' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_uncollated.unity3d'; ExpectedLength = [int64]65558791; ExpectedSha256 = '65ab7ebb530d1ed2d38a82042c22d90e32732f25d599f9195b6acc69cb546e9d' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/shader.unity3d'; ExpectedLength = [int64]14421770; ExpectedSha256 = '8043bfe89e1619f4090e00014f38182077e1f521d2292aa3e223d5b1fb7c1947' }
        [pscustomobject]@{ Partition = 'Provider'; SourceId = 'pc-install'; RelativePath = 'Persistent_Store/AssetBundles/fx_actorcommon_textures_other.unity3d'; ExpectedLength = [int64]46651397; ExpectedSha256 = '92df258baf1a587cdae35eaaceabfad755d1d414d0d165b7b9762c8da1357101' }
    )
}

function Get-PefpOutputRelativeRoot {
    return 'Extracted/ProviderEnhancedFinalProof/char_14401/LO1'
}

function Get-PefpContract {
    $repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    $outputRelativeRoot = Get-PefpOutputRelativeRoot

    return [pscustomobject][ordered]@{
        schemaVersion = 'pefp-provider-enhanced-export/1.0.0'
        artifactId = 'PEFP-LO1-char_14401'
        repositoryRoot = $repositoryRoot
        outputRelativeRoot = $outputRelativeRoot
        inputRelativeRoot = "$outputRelativeRoot/Input"
        exportRelativeRoot = "$outputRelativeRoot/Output"
        logsRelativeRoot = "$outputRelativeRoot/Logs"
        terminalRelativePath = "$outputRelativeRoot/terminal-result.json"
        toolManifestRelativePath = 'Tools/AssetImport/tool-manifest.json'
        toolManifestSha256 = '24e973ded1f9d7c97b8334c82b82e69d6dc227798441d9ffa43bb4a80ec070f9'
        assetRipperLeafName = 'AssetRipper.GUI.Free.exe'
        assetRipperProductName = 'AssetRipper.GUI.Free'
        assetRipperVersion = '1.3.14.0'
        assetRipperLength = [int64]124776960
        assetRipperSha256 = '11ec892dcd70b1b86f2e52db631e83e007f6103daa20a9616ecaa7a95baa9f21'
        port = 17777
        startupTimeoutMilliseconds = [int64]60000
        loadTimeoutMilliseconds = [int64]600000
        exportTimeoutMilliseconds = [int64]1200000
        overallTimeoutMilliseconds = [int64]1800000
        shutdownTimeoutMilliseconds = [int64]60000
        authorizedInputs = @(Get-PefpAuthorizedInputs)
    }
}

function Assert-PefpPortableRelativePath {
    param([Parameter(Mandatory)][string]$RelativePath)

    if (
        [string]::IsNullOrWhiteSpace($RelativePath) -or
        [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath.Contains('\') -or
        $RelativePath -match '(^|/)\.{1,2}(/|$)' -or
        $RelativePath -match '^[\\/]{2}'
    ) {
        Stop-Pefp 'PathTraversal'
    }
}

function Assert-PefpLocalAbsolutePath {
    param([Parameter(Mandatory)][string]$Path)

    if (
        [string]::IsNullOrWhiteSpace($Path) -or
        -not [IO.Path]::IsPathFullyQualified($Path) -or
        $Path -match '^[\\/]{2}'
    ) {
        Stop-Pefp 'NetworkPathRejected'
    }
}

function Test-PefpContainedPath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$Leaf,
        [switch]$AllowEqual
    )

    $canonicalRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $canonicalLeaf = [IO.Path]::GetFullPath($Leaf)
    if ($AllowEqual -and $canonicalLeaf.Equals($canonicalRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    return $canonicalLeaf.StartsWith(
        $canonicalRoot + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Assert-PefpLeafObject {
    param(
        [Parameter(Mandatory)][AllowNull()][object]$Item,
        [Parameter(Mandatory)][string]$FailurePrefix,
        [ValidateSet('File', 'Directory')][string]$ExpectedKind = 'File'
    )

    if (
        $null -eq $Item -or
        ($Item.PSObject.Properties.Name -contains 'Exists' -and -not [bool]$Item.Exists)
    ) {
        Stop-Pefp "$($FailurePrefix)Missing"
    }
    if (([IO.FileAttributes]$Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        Stop-Pefp "$($FailurePrefix)ReparsePointRejected"
    }

    $isContainer = [bool]$Item.PSIsContainer
    if (
        ($ExpectedKind -ceq 'File' -and $isContainer) -or
        ($ExpectedKind -ceq 'Directory' -and -not $isContainer)
    ) {
        Stop-Pefp "$($FailurePrefix)RegularFileRequired"
    }
}

function Assert-PefpNoReparseChain {
    param(
        [Parameter(Mandatory)][string]$AbsolutePath,
        [Parameter(Mandatory)][ValidateSet('File', 'Directory')][string]$LeafKind,
        [Parameter(Mandatory)][string]$FailurePrefix,
        [string]$RequiredRoot
    )

    Assert-PefpLocalAbsolutePath -Path $AbsolutePath
    $fullPath = [IO.Path]::GetFullPath($AbsolutePath)
    if (-not [string]::IsNullOrWhiteSpace($RequiredRoot)) {
        Assert-PefpLocalAbsolutePath -Path $RequiredRoot
        if (-not (Test-PefpContainedPath -Root $RequiredRoot -Leaf $fullPath -AllowEqual)) {
            Stop-Pefp "$($FailurePrefix)OutsideRoot"
        }
    }

    $volumeRoot = [IO.Path]::GetPathRoot($fullPath)
    $cursor = $volumeRoot
    $rootItem = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
    Assert-PefpLeafObject -Item $rootItem -FailurePrefix $FailurePrefix -ExpectedKind Directory

    $segments = @(
        $fullPath.Substring($volumeRoot.Length).Trim('\', '/') -split '[\\/]' |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )
    for ($index = 0; $index -lt $segments.Count; $index++) {
        $cursor = Join-Path $cursor $segments[$index]
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction SilentlyContinue
        $expected = if ($index -eq ($segments.Count - 1)) { $LeafKind } else { 'Directory' }
        Assert-PefpLeafObject -Item $item -FailurePrefix $FailurePrefix -ExpectedKind $expected
    }

    return $fullPath
}

function Assert-PefpProspectiveContainedPath {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$Candidate
    )

    Assert-PefpLocalAbsolutePath -Path $RepositoryRoot
    Assert-PefpLocalAbsolutePath -Path $Candidate
    if (-not (Test-PefpContainedPath -Root $RepositoryRoot -Leaf $Candidate)) {
        Stop-Pefp 'OutputOutsideRepository'
    }

    $cursor = [IO.Path]::GetFullPath($Candidate)
    while (-not (Test-Path -LiteralPath $cursor)) {
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) {
            Stop-Pefp 'OutputParentMissing'
        }
        $cursor = $parent.FullName
    }
    [void](Assert-PefpNoReparseChain -AbsolutePath $cursor -LeafKind Directory -FailurePrefix 'OutputParent' -RequiredRoot $RepositoryRoot)
}

function Invoke-PefpPreOutputGate {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Counters
    )

    if (Test-Path -LiteralPath $OutputRoot) {
        if ([int]$Counters.SourceOpenCount -ne 0 -or [int]$Counters.ProcessStartCount -ne 0) {
            Stop-Pefp 'OutputGateCounterViolation'
        }
        Stop-Pefp 'OutputRootAlreadyExists'
    }
}

function Get-PefpSha256 {
    param([Parameter(Mandatory)][string]$LiteralPath)

    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return [Convert]::ToHexString($hash.ComputeHash($stream)).ToLowerInvariant()
    }
    finally {
        $hash.Dispose()
        $stream.Dispose()
    }
}

function New-PefpMetadataRecord {
    param(
        [Parameter(Mandatory)][object]$Item,
        [Parameter(Mandatory)][object]$AuthorizedInput
    )

    return [pscustomobject][ordered]@{
        partition = [string]$AuthorizedInput.Partition
        sourceId = [string]$AuthorizedInput.SourceId
        relativePath = [string]$AuthorizedInput.RelativePath
        expectedLength = [int64]$AuthorizedInput.ExpectedLength
        expectedSha256 = [string]$AuthorizedInput.ExpectedSha256
        length = [int64]$Item.Length
        lastWriteTimeUtc = $Item.LastWriteTimeUtc.ToString('o')
        attributes = $Item.Attributes.ToString()
    }
}

function Test-PefpMetadataRecordEqual {
    param(
        [Parameter(Mandatory)][object]$Before,
        [Parameter(Mandatory)][object]$After
    )

    return (
        $Before.partition -ceq $After.partition -and
        $Before.sourceId -ceq $After.sourceId -and
        $Before.relativePath -ceq $After.relativePath -and
        [int64]$Before.expectedLength -eq [int64]$After.expectedLength -and
        $Before.expectedSha256 -ceq $After.expectedSha256 -and
        [int64]$Before.length -eq [int64]$After.length -and
        $Before.lastWriteTimeUtc -ceq $After.lastWriteTimeUtc -and
        $Before.attributes -ceq $After.attributes
    )
}

function Test-PefpAuthorizedInputMetadata {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [object[]]$Inputs
    )

    $root = Assert-PefpNoReparseChain -AbsolutePath $SourceRoot -LeafKind Directory -FailurePrefix 'SourceRoot'
    if ($null -eq $Inputs) {
        $Inputs = @(Get-PefpAuthorizedInputs)
    }
    $inputs = @($Inputs)
    if (
        $inputs.Count -ne 16 -or
        @($inputs | Where-Object Partition -ceq 'SFXR').Count -ne 7 -or
        @($inputs | Where-Object Partition -ceq 'Provider').Count -ne 9 -or
        @($inputs.RelativePath | Sort-Object -Unique).Count -ne 16 -or
        @($inputs | Where-Object SourceId -cne 'pc-install').Count -ne 0 -or
        @($inputs | Where-Object {
            [int64]$_.ExpectedLength -le 0 -or
            [string]$_.ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$'
        }).Count -ne 0
    ) {
        Stop-Pefp 'InputPartitionInvariant'
    }

    $rows = @()
    foreach ($authorizedInput in $inputs) {
        Assert-PefpPortableRelativePath -RelativePath $authorizedInput.RelativePath
        $leaf = [IO.Path]::GetFullPath(
            (Join-Path $root $authorizedInput.RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        )
        if (-not (Test-PefpContainedPath -Root $root -Leaf $leaf)) {
            Stop-Pefp 'InputOutsideSourceRoot'
        }
        [void](Assert-PefpNoReparseChain -AbsolutePath $leaf -LeafKind File -FailurePrefix 'SourceMember' -RequiredRoot $root)
        $item = Get-Item -LiteralPath $leaf -Force
        if ($item -isnot [IO.FileInfo] -or $item.PSIsContainer) {
            Stop-Pefp 'SourceMemberRegularFileRequired'
        }
        if ([int64]$item.Length -ne [int64]$authorizedInput.ExpectedLength) {
            Stop-Pefp 'SourceMemberIdentityMismatch'
        }
        $rows += New-PefpMetadataRecord -Item $item -AuthorizedInput $authorizedInput
    }

    return $rows
}

function Test-PefpJsonArrayProperty {
    param(
        [Parameter(Mandatory)][string]$JsonText,
        [Parameter(Mandatory)][string[]]$PropertyPath
    )

    $document = $null
    try {
        $document = [Text.Json.JsonDocument]::Parse($JsonText)
        $element = $document.RootElement
        foreach ($propertyName in $PropertyPath) {
            if ($element.ValueKind -ne [Text.Json.JsonValueKind]::Object) {
                return $false
            }
            $element = $element.GetProperty($propertyName)
        }
        return $element.ValueKind -eq [Text.Json.JsonValueKind]::Array
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $document) {
            $document.Dispose()
        }
    }
}

function Get-PefpDefaultBindingData {
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    if ([string]::IsNullOrWhiteSpace($localAppData)) {
        Stop-Pefp 'SourceBindingFailure'
    }

    $locatorPath = Join-Path $localAppData 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
    [void](Assert-PefpNoReparseChain -AbsolutePath $locatorPath -LeafKind File -FailurePrefix 'SourceBinding')
    try {
        $locatorRaw = [IO.File]::ReadAllText($locatorPath)
        $locator = $locatorRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-Pefp 'SourceBindingFailure'
    }
    if (
        $locator.schemaVersion -cne '1.0.0' -or
        -not (Test-PefpJsonArrayProperty -JsonText $locatorRaw -PropertyPath @('sourceBoundary', 'sources')) -or
        @($locator.sourceBoundary.sources).Count -eq 0 -or
        $locator.manifestPath -isnot [string]
    ) {
        Stop-Pefp 'SourceBindingFailure'
    }

    if (
        $locator.baseline.disposition -ceq 'Present' -and
        (
            $locator.baseline.path -isnot [string] -or
            [string]::IsNullOrWhiteSpace([string]$locator.baseline.path)
        )
    ) {
        Stop-Pefp 'SourceBindingFailure'
    }
    if ($locator.baseline.disposition -cnotin @('Present', 'Absent')) {
        Stop-Pefp 'SourceBindingFailure'
    }

    $manifestPath = [string]$locator.manifestPath
    Assert-PefpLocalAbsolutePath -Path $manifestPath
    [void](Assert-PefpNoReparseChain -AbsolutePath $manifestPath -LeafKind File -FailurePrefix 'SourceBinding')
    try {
        $manifestRaw = [IO.File]::ReadAllText($manifestPath)
        $manifest = $manifestRaw | ConvertFrom-Json -Depth 100 -DateKind String
    }
    catch {
        Stop-Pefp 'SourceBindingFailure'
    }
    if (
        $manifest.schemaVersion -cne '1.0.0' -or
        -not (Test-PefpJsonArrayProperty -JsonText $manifestRaw -PropertyPath @('sources')) -or
        @($manifest.sources).Count -eq 0
    ) {
        Stop-Pefp 'SourceBindingFailure'
    }

    $locatorRows = @($locator.sourceBoundary.sources | ForEach-Object {
        [pscustomobject]@{
            sourceId = $_.sourceId
            sourceKind = $_.sourceKind
            path = $_.rootPath
        }
    })
    $manifestRows = @($manifest.sources | ForEach-Object {
        [pscustomobject]@{
            sourceId = $_.sourceId
            sourceKind = $_.sourceKind
            path = $_.rootPath
        }
    })
    return [pscustomobject]@{
        Baseline = $locator.baseline.disposition
        LocatorSources = $locatorRows
        ManifestSources = $manifestRows
    }
}

function Resolve-PefpPcInstallBinding {
    param(
        [scriptblock]$BindingLoader,
        [scriptblock]$PathValidator
    )

    $data = if ($null -eq $BindingLoader) {
        Get-PefpDefaultBindingData
    }
    else {
        & $BindingLoader
    }
    if (
        $null -eq $data -or
        $null -eq $data.LocatorSources -or
        $null -eq $data.ManifestSources -or
        @($data.LocatorSources).Count -eq 0 -or
        @($data.ManifestSources).Count -eq 0
    ) {
        Stop-Pefp 'SourceBindingMismatch'
    }

    $normalizedSets = @()
    foreach ($set in @(@($data.LocatorSources), @($data.ManifestSources))) {
        $byId = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $set) {
            if (
                $row.sourceId -isnot [string] -or
                [string]$row.sourceId -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$' -or
                $row.sourceKind -isnot [string] -or
                [string]$row.sourceKind -cnotin @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache') -or
                $row.path -isnot [string] -or
                $byId.ContainsKey([string]$row.sourceId)
            ) {
                Stop-Pefp 'SourceBindingMismatch'
            }
            $item = if ($null -eq $PathValidator) {
                $kind = if ([string]$row.sourceKind -ceq 'AndroidApk') { 'File' } else { 'Directory' }
                $validated = Assert-PefpNoReparseChain -AbsolutePath ([string]$row.path) -LeafKind $kind -FailurePrefix 'SourceBinding'
                Get-Item -LiteralPath $validated -Force
            }
            else {
                & $PathValidator ([string]$row.path)
            }
            if ($null -eq $item -or $null -eq $item.FullName) {
                Stop-Pefp 'SourceBindingMismatch'
            }
            $byId.Add([string]$row.sourceId, [pscustomobject]@{
                SourceId = [string]$row.sourceId
                SourceKind = [string]$row.sourceKind
                SourceRoot = [IO.Path]::GetFullPath([string]$item.FullName).TrimEnd('\', '/')
            })
        }
        $normalizedSets += ,$byId
    }

    $locatorSet = $normalizedSets[0]
    $manifestSet = $normalizedSets[1]
    if ($locatorSet.Count -ne $manifestSet.Count) {
        Stop-Pefp 'SourceBindingMismatch'
    }
    foreach ($sourceId in $locatorSet.Keys) {
        if (-not $manifestSet.ContainsKey($sourceId)) {
            Stop-Pefp 'SourceBindingMismatch'
        }
        $left = $locatorSet[$sourceId]
        $right = $manifestSet[$sourceId]
        if (
            $left.SourceId -cne $right.SourceId -or
            $left.SourceKind -cne $right.SourceKind -or
            -not $left.SourceRoot.Equals($right.SourceRoot, [StringComparison]::OrdinalIgnoreCase)
        ) {
            Stop-Pefp 'SourceBindingMismatch'
        }
    }
    if (-not $manifestSet.ContainsKey('pc-install')) {
        Stop-Pefp 'SourceBindingMismatch'
    }
    $selected = $manifestSet['pc-install']
    if ($selected.SourceId -cne 'pc-install' -or $selected.SourceKind -cne 'PcInstall') {
        Stop-Pefp 'SourceBindingMismatch'
    }
    return $selected
}

function Get-PefpToolIdentity {
    param([Parameter(Mandatory)][object]$Contract)

    $manifestPath = [IO.Path]::GetFullPath(
        (Join-Path $Contract.repositoryRoot $Contract.toolManifestRelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    )
    [void](Assert-PefpNoReparseChain -AbsolutePath $manifestPath -LeafKind File -FailurePrefix 'ToolManifest' -RequiredRoot $Contract.repositoryRoot)
    if ((Get-PefpSha256 -LiteralPath $manifestPath) -cne $Contract.toolManifestSha256) {
        Stop-Pefp 'ToolManifestIdentityMismatch'
    }
    try {
        $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json -Depth 20
    }
    catch {
        Stop-Pefp 'ToolManifestParseFailure'
    }
    if (
        $manifest.assetRipper -isnot [string] -or
        [string]::IsNullOrWhiteSpace([string]$manifest.assetRipper) -or
        [int]$manifest.assetRipperPort -ne [int]$Contract.port
    ) {
        Stop-Pefp 'ToolManifestContractMismatch'
    }

    $toolPath = Assert-PefpNoReparseChain -AbsolutePath ([string]$manifest.assetRipper) -LeafKind File -FailurePrefix 'AssetRipper'
    $tool = Get-Item -LiteralPath $toolPath -Force
    if (
        $tool.Name -cne $Contract.assetRipperLeafName -or
        $tool.VersionInfo.ProductName -cne $Contract.assetRipperProductName -or
        $tool.VersionInfo.FileVersion -cne $Contract.assetRipperVersion -or
        [int64]$tool.Length -ne [int64]$Contract.assetRipperLength -or
        (Get-PefpSha256 -LiteralPath $toolPath) -cne $Contract.assetRipperSha256
    ) {
        Stop-Pefp 'AssetRipperIdentityMismatch'
    }
    return [pscustomobject]@{
        Path = $toolPath
        Length = [int64]$tool.Length
        Sha256 = $Contract.assetRipperSha256
        ProductName = $tool.VersionInfo.ProductName
        FileVersion = $tool.VersionInfo.FileVersion
    }
}

function Copy-PefpInputOnce {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$StagingRoot,
        [Parameter(Mandatory)][object]$Before,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Counters
    )

    $sourcePath = [IO.Path]::GetFullPath(
        (Join-Path $SourceRoot $Before.relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    )
    $destinationPath = [IO.Path]::GetFullPath(
        (Join-Path $StagingRoot $Before.relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
    )
    if (
        -not (Test-PefpContainedPath -Root $SourceRoot -Leaf $sourcePath) -or
        -not (Test-PefpContainedPath -Root $StagingRoot -Leaf $destinationPath)
    ) {
        Stop-Pefp 'StagingPathEscape'
    }
    $destinationParent = [IO.Path]::GetDirectoryName($destinationPath)
    [IO.Directory]::CreateDirectory($destinationParent) | Out-Null

    $source = $null
    $destination = $null
    $hash = [Security.Cryptography.IncrementalHash]::CreateHash([Security.Cryptography.HashAlgorithmName]::SHA256)
    try {
        $source = [IO.FileStream]::new($sourcePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
        $Counters.SourceOpenCount = [int]$Counters.SourceOpenCount + 1
        if (
            [int64]$source.Length -ne [int64]$Before.expectedLength -or
            [int64]$Before.length -ne [int64]$Before.expectedLength
        ) {
            Stop-Pefp 'SourceMemberIdentityMismatch'
        }
        $destination = [IO.FileStream]::new($destinationPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $buffer = [byte[]]::new(1024 * 1024)
        $copied = [int64]0
        while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $hash.AppendData($buffer, 0, $read)
            $destination.Write($buffer, 0, $read)
            $copied += $read
        }
        $destination.Flush($true)
        if ($copied -ne [int64]$Before.expectedLength) {
            Stop-Pefp 'SourceMemberIdentityMismatch'
        }
        $sha256 = [Convert]::ToHexString($hash.GetHashAndReset()).ToLowerInvariant()
        if ($sha256 -cne [string]$Before.expectedSha256) {
            Stop-Pefp 'SourceMemberIdentityMismatch'
        }
    }
    finally {
        $hash.Dispose()
        if ($null -ne $destination) {
            $destination.Dispose()
        }
        if ($null -ne $source) {
            $source.Dispose()
        }
    }

    $destinationItem = Get-Item -LiteralPath $destinationPath -Force
    if (
        [int64]$destinationItem.Length -ne [int64]$Before.expectedLength -or
        (Get-PefpSha256 -LiteralPath $destinationPath) -cne [string]$Before.expectedSha256
    ) {
        Stop-Pefp 'SourceMemberIdentityMismatch'
    }
    return [pscustomobject][ordered]@{
        partition = $Before.partition
        sourceId = $Before.sourceId
        relativePath = $Before.relativePath
        expectedLength = [int64]$Before.expectedLength
        expectedSha256 = [string]$Before.expectedSha256
        length = [int64]$destinationItem.Length
        sha256 = $sha256
        lastWriteTimeUtcBefore = $Before.lastWriteTimeUtc
        attributesBefore = $Before.attributes
        stagingRelativePath = "Input/$($Before.relativePath)"
        stagingLength = [int64]$destinationItem.Length
        stagingSha256 = [string]$Before.expectedSha256
        lastWriteTimeUtcAfter = $null
        attributesAfter = $null
        unchanged = $false
    }
}

function Complete-PefpInputEvidence {
    param(
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][object[]]$BeforeRows,
        [Parameter(Mandatory)][object[]]$InputResults
    )

    for ($index = 0; $index -lt $BeforeRows.Count; $index++) {
        $before = $BeforeRows[$index]
        $sourcePath = [IO.Path]::GetFullPath(
            (Join-Path $SourceRoot $before.relativePath.Replace('/', [IO.Path]::DirectorySeparatorChar))
        )
        [void](Assert-PefpNoReparseChain -AbsolutePath $sourcePath -LeafKind File -FailurePrefix 'SourceMemberPost' -RequiredRoot $SourceRoot)
        $afterItem = Get-Item -LiteralPath $sourcePath -Force
        $after = New-PefpMetadataRecord -Item $afterItem -AuthorizedInput $before
        $same = Test-PefpMetadataRecordEqual -Before $before -After $after
        $InputResults[$index].lastWriteTimeUtcAfter = $after.lastWriteTimeUtc
        $InputResults[$index].attributesAfter = $after.attributes
        $InputResults[$index].unchanged = $same
        if (-not $same) {
            Stop-Pefp 'SourceIdentityChanged'
        }
    }
}

function Test-PefpPortFree {
    param([Parameter(Mandatory)][int]$Port)

    return @(
        Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    ).Count -eq 0
}

function Test-PefpListenerOwned {
    param(
        [Parameter(Mandatory)][int]$Port,
        [Parameter(Mandatory)][int]$ProcessId
    )

    $listeners = @(
        Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    )
    return (
        $listeners.Count -eq 1 -and
        [int]$listeners[0].OwningProcess -eq $ProcessId
    )
}

function Assert-PefpNoProductionProcesses {
    $related = @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                $_.ProcessName -like 'AssetRipper*' -or
                $_.ProcessName -in @('Unity', 'UnityShaderCompiler', 'UnityCrashHandler64')
            }
    )
    if ($related.Count -ne 0) {
        Stop-Pefp 'ProductionProcessAlreadyRunning'
    }
}

function Join-PefpWindowsArguments {
    param([Parameter(Mandatory)][string[]]$Values)

    return (($Values | ForEach-Object {
        if ($_ -notmatch '[\s"]') {
            $_
        }
        else {
            '"' + ($_ -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
        }
    }) -join ' ')
}

function Get-PefpRemainingMilliseconds {
    param(
        [Parameter(Mandatory)][Diagnostics.Stopwatch]$Stopwatch,
        [Parameter(Mandatory)][int64]$OverallTimeoutMilliseconds,
        [Parameter(Mandatory)][int64]$StageTimeoutMilliseconds
    )

    $remaining = $OverallTimeoutMilliseconds - $Stopwatch.ElapsedMilliseconds
    if ($remaining -le 0) {
        Stop-Pefp 'OverallTimeout'
    }
    return [int64][Math]::Min($remaining, $StageTimeoutMilliseconds)
}

function Invoke-PefpHttpPost {
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][hashtable]$Body,
        [Parameter(Mandatory)][int64]$TimeoutMilliseconds,
        [Parameter(Mandatory)][string]$StageName
    )

    $client = [Net.Http.HttpClient]::new()
    $content = $null
    try {
        $client.Timeout = [Threading.Timeout]::InfiniteTimeSpan
        $pairs = [Collections.Generic.List[Collections.Generic.KeyValuePair[string, string]]]::new()
        foreach ($key in $Body.Keys) {
            $pairs.Add([Collections.Generic.KeyValuePair[string, string]]::new([string]$key, [string]$Body[$key]))
        }
        $content = [Net.Http.FormUrlEncodedContent]::new($pairs)
        $task = $client.PostAsync($Uri, $content)
        if (-not $task.Wait([int]$TimeoutMilliseconds)) {
            Stop-Pefp "$($StageName)Timeout"
        }
        if ($task.IsFaulted) {
            throw $task.Exception.GetBaseException()
        }
        $response = $task.Result
        try {
            return [pscustomobject]@{
                StatusCode = [int]$response.StatusCode
                IsSuccess = [bool]$response.IsSuccessStatusCode
            }
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        if ($null -ne $content) {
            $content.Dispose()
        }
        $client.Dispose()
    }
}

function Stop-PefpProcessTree {
    param([Parameter(Mandatory)][int]$RootProcessId)

    $all = @(
        Get-CimInstance -ClassName Win32_Process -ErrorAction SilentlyContinue |
            Select-Object ProcessId, ParentProcessId
    )
    $ids = [Collections.Generic.List[int]]::new()
    $ids.Add($RootProcessId)
    for ($index = 0; $index -lt $ids.Count; $index++) {
        foreach ($row in $all) {
            if ([int]$row.ParentProcessId -eq $ids[$index] -and -not $ids.Contains([int]$row.ProcessId)) {
                $ids.Add([int]$row.ProcessId)
            }
        }
    }
    foreach ($id in @($ids | Sort-Object -Descending)) {
        Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
    }
}

function Get-PefpChildProcessEvidence {
    param([Parameter(Mandatory)][int]$ParentProcessId)

    return @(
        Get-CimInstance -ClassName Win32_Process -Filter "ParentProcessId=$ParentProcessId" -ErrorAction SilentlyContinue |
            Sort-Object ProcessId |
            ForEach-Object {
                [pscustomobject][ordered]@{
                    processId = [int]$_.ProcessId
                    parentProcessId = [int]$_.ParentProcessId
                    executableName = [IO.Path]::GetFileName([string]$_.ExecutablePath)
                }
            }
    )
}

function Get-PefpExportInventory {
    param([Parameter(Mandatory)][string]$OutputRoot)

    $files = @()
    if (Test-Path -LiteralPath $OutputRoot -PathType Container) {
        $files = @(Get-ChildItem -LiteralPath $OutputRoot -File -Recurse -Force)
    }
    foreach ($file in $files) {
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Stop-Pefp 'ExportReparsePointDetected'
        }
    }
    $distribution = @(
        $files |
            Group-Object {
                if ([string]::IsNullOrWhiteSpace($_.Extension)) {
                    '<none>'
                }
                else {
                    $_.Extension.ToLowerInvariant()
                }
            } |
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
        Count = [int]$files.Count
        Bytes = [int64](($files | Measure-Object Length -Sum).Sum)
        Distribution = $distribution
    }
}

function Get-PefpLogDiagnostics {
    param([Parameter(Mandatory)][string]$LogPath)

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        return [pscustomobject]@{
            MissingDependencyWarningCount = 0
            UniqueMissingCabCount = 0
            ScriptDeserializationIssueCount = 0
        }
    }
    $text = [IO.File]::ReadAllText($LogPath)
    $missing = [regex]::Matches($text, "(?im)^.*Dependency 'archive:/CAB-[0-9a-f]{32}/CAB-[0-9a-f]{32}' wasn't found.*$")
    $cabIds = @(
        [regex]::Matches(($missing.Value -join "`n"), '(?i)CAB-[0-9a-f]{32}') |
            ForEach-Object { $_.Value.ToLowerInvariant() } |
            Sort-Object -Unique
    )
    $scriptIssues = [regex]::Matches(
        $text,
        '(?im)^.*(?:script|MonoBehaviour).*(?:deserialize|deserialization|missing|failed).*$'
    )
    return [pscustomobject]@{
        MissingDependencyWarningCount = [int]$missing.Count
        UniqueMissingCabCount = [int]$cabIds.Count
        ScriptDeserializationIssueCount = [int]$scriptIssues.Count
    }
}

function Get-PefpPortableLogFacts {
    param(
        [Parameter(Mandatory)][string]$AbsolutePath,
        [Parameter(Mandatory)][string]$PortablePath
    )

    if (-not (Test-Path -LiteralPath $AbsolutePath -PathType Leaf)) {
        return [pscustomobject][ordered]@{
            relativePath = $PortablePath
            exists = $false
            length = 0
            sha256 = $null
        }
    }
    $item = Get-Item -LiteralPath $AbsolutePath -Force
    return [pscustomobject][ordered]@{
        relativePath = $PortablePath
        exists = $true
        length = [int64]$item.Length
        sha256 = Get-PefpSha256 -LiteralPath $AbsolutePath
    }
}

function ConvertTo-PefpPortableText {
    param(
        [AllowNull()][string]$Text,
        [string[]]$PrivateRoots
    )

    if ($null -eq $Text) {
        return $null
    }
    $result = $Text
    foreach ($privateRoot in $PrivateRoots) {
        if (-not [string]::IsNullOrWhiteSpace($privateRoot)) {
            $result = $result.Replace($privateRoot, '<private-path>', [StringComparison]::OrdinalIgnoreCase)
        }
    }
    $result = [regex]::Replace($result, '(?i)[A-Z]:[\\/][^\r\n''"]*', '<private-path>')
    $result = [regex]::Replace($result, '(?i)[\\/]{2}[^\\/\r\n]+[\\/][^\r\n''"]*', '<private-path>')
    return $result
}

function Write-PefpTerminal {
    param(
        [Parameter(Mandatory)][string]$LiteralPath,
        [Parameter(Mandatory)][object]$Terminal
    )

    $Terminal.sourcePathLeakCount = 0
    $json = $Terminal | ConvertTo-Json -Depth 100
    $leakCount = [regex]::Matches($json, '(?i)(?:[A-Z]:[\\/]|\\\\\\\\[^\\])').Count
    if ($leakCount -ne 0) {
        Stop-Pefp 'PortableTerminalPathLeak'
    }
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json.TrimEnd("`r", "`n") + "`n")
    $stream = [IO.FileStream]::new(
        $LiteralPath,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally {
        $stream.Dispose()
    }
}

function Get-PefpHead {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $dotGit = Join-Path $RepositoryRoot '.git'
    $gitDirectory = if (Test-Path -LiteralPath $dotGit -PathType Container) {
        $dotGit
    }
    else {
        $line = [IO.File]::ReadAllText($dotGit).Trim()
        if ($line -notmatch '^gitdir:\s*(?<path>.+)$') {
            Stop-Pefp 'GitHeadUnavailable'
        }
        [IO.Path]::GetFullPath($Matches['path'])
    }
    $headText = [IO.File]::ReadAllText((Join-Path $gitDirectory 'HEAD')).Trim()
    if ($headText -match '^[0-9a-f]{40}$') {
        return $headText
    }
    if ($headText -notmatch '^ref:\s*(?<ref>.+)$') {
        Stop-Pefp 'GitHeadUnavailable'
    }
    $refName = $Matches['ref']
    $worktreeRef = Join-Path $gitDirectory $refName
    if (Test-Path -LiteralPath $worktreeRef -PathType Leaf) {
        return [IO.File]::ReadAllText($worktreeRef).Trim()
    }
    $commonDirectory = $gitDirectory
    $commonFile = Join-Path $gitDirectory 'commondir'
    if (Test-Path -LiteralPath $commonFile -PathType Leaf) {
        $commonDirectory = [IO.Path]::GetFullPath(
            (Join-Path $gitDirectory ([IO.File]::ReadAllText($commonFile).Trim()))
        )
    }
    $commonRef = Join-Path $commonDirectory $refName
    if (Test-Path -LiteralPath $commonRef -PathType Leaf) {
        return [IO.File]::ReadAllText($commonRef).Trim()
    }
    $packedRefs = Join-Path $commonDirectory 'packed-refs'
    if (Test-Path -LiteralPath $packedRefs -PathType Leaf) {
        foreach ($line in [IO.File]::ReadAllLines($packedRefs)) {
            if ($line -match "^(?<hash>[0-9a-f]{40})\s+$([regex]::Escape($refName))$") {
                return $Matches['hash']
            }
        }
    }
    Stop-Pefp 'GitHeadUnavailable'
}

function Invoke-PefpProduction {
    $contract = Get-PefpContract
    $attemptRoot = [IO.Path]::GetFullPath(
        (Join-Path $contract.repositoryRoot $contract.outputRelativeRoot.Replace('/', [IO.Path]::DirectorySeparatorChar))
    )
    $stagingRoot = Join-Path $attemptRoot 'Input'
    $exportRoot = Join-Path $attemptRoot 'Output'
    $logsRoot = Join-Path $attemptRoot 'Logs'
    $terminalPath = Join-Path $attemptRoot 'terminal-result.json'
    $assetRipperLogPath = Join-Path $logsRoot 'assetripper.log'
    $stdoutPath = Join-Path $logsRoot 'assetripper.stdout.log'
    $stderrPath = Join-Path $logsRoot 'assetripper.stderr.log'
    $counters = [ordered]@{ SourceOpenCount = 0; ProcessStartCount = 0 }

    Invoke-PefpPreOutputGate -OutputRoot $attemptRoot -Counters $counters
    Assert-PefpProspectiveContainedPath -RepositoryRoot $contract.repositoryRoot -Candidate $attemptRoot

    [IO.Directory]::CreateDirectory($attemptRoot) | Out-Null
    [IO.Directory]::CreateDirectory($logsRoot) | Out-Null

    $stage = 'Preflight'
    $head = $null
    $status = 'Failed'
    $failureCode = $null
    $exceptionType = $null
    $exceptionMessage = $null
    $exceptionStack = $null
    $binding = $null
    $tool = $null
    $beforeRows = @()
    $inputResults = @()
    $sourceUnchanged = $false
    $sourcePostCheckFailureCode = $null
    $process = $null
    $processId = $null
    $processExitCode = $null
    $childProcesses = @()
    $loadHttpStatus = $null
    $exportHttpStatus = $null
    $timedOut = $false
    $listenerOwned = $false
    $listenerAbsentAfterShutdown = $null
    $operationWatch = [Diagnostics.Stopwatch]::StartNew()
    $exportInventory = [pscustomobject]@{ Count = 0; Bytes = [int64]0; Distribution = @() }
    $diagnostics = [pscustomobject]@{
        MissingDependencyWarningCount = 0
        UniqueMissingCabCount = 0
        ScriptDeserializationIssueCount = 0
    }

    try {
        $head = Get-PefpHead -RepositoryRoot $contract.repositoryRoot
        $binding = Resolve-PefpPcInstallBinding
        $tool = Get-PefpToolIdentity -Contract $contract
        Assert-PefpNoProductionProcesses
        if (-not (Test-PefpPortFree -Port $contract.port)) {
            Stop-Pefp 'AssetRipperPortOccupied'
        }

        $beforeRows = @(Test-PefpAuthorizedInputMetadata -SourceRoot $binding.SourceRoot)
        if ($beforeRows.Count -ne 16) {
            Stop-Pefp 'InputAccountingMismatch'
        }

        $stage = 'Staging'
        [IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
        [IO.Directory]::CreateDirectory($exportRoot) | Out-Null
        foreach ($before in $beforeRows) {
            $inputResults += Copy-PefpInputOnce `
                -SourceRoot $binding.SourceRoot `
                -StagingRoot $stagingRoot `
                -Before $before `
                -Counters $counters
        }
        if ($inputResults.Count -ne 16 -or [int]$counters.SourceOpenCount -ne 16) {
            Stop-Pefp 'StagingAccountingMismatch'
        }
        $stage = 'ProcessStart'
        $arguments = Join-PefpWindowsArguments -Values @(
            '--headless=true',
            '--port',
            [string]$contract.port,
            '--log=true',
            '--log-path',
            $assetRipperLogPath
        )
        $process = Start-Process `
            -FilePath $tool.Path `
            -ArgumentList $arguments `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -WindowStyle Hidden `
            -PassThru
        if ($null -eq $process) {
            Stop-Pefp 'AssetRipperStartFailure'
        }
        $counters.ProcessStartCount = [int]$counters.ProcessStartCount + 1
        $processId = [int]$process.Id

        $stage = 'Startup'
        $startupWatch = [Diagnostics.Stopwatch]::StartNew()
        while (-not $listenerOwned) {
            if ($operationWatch.ElapsedMilliseconds -ge $contract.overallTimeoutMilliseconds) {
                $timedOut = $true
                Stop-Pefp 'OverallTimeout'
            }
            if ($startupWatch.ElapsedMilliseconds -ge $contract.startupTimeoutMilliseconds) {
                $timedOut = $true
                Stop-Pefp 'StartupTimeout'
            }
            $process.Refresh()
            if ($process.HasExited) {
                $processExitCode = $process.ExitCode
                Stop-Pefp 'AssetRipperExitedBeforeListener'
            }
            $listenerOwned = Test-PefpListenerOwned -Port $contract.port -ProcessId $process.Id
            if (-not $listenerOwned) {
                Start-Sleep -Milliseconds 250
            }
        }
        $startupWatch.Stop()
        $childProcesses = @(Get-PefpChildProcessEvidence -ParentProcessId $process.Id)

        $baseUrl = "http://127.0.0.1:$($contract.port)"
        $stage = 'Load'
        try {
            $loadResponse = Invoke-PefpHttpPost `
                -Uri "$baseUrl/LoadFolder" `
                -Body @{ Path = $stagingRoot } `
                -TimeoutMilliseconds (Get-PefpRemainingMilliseconds `
                    -Stopwatch $operationWatch `
                    -OverallTimeoutMilliseconds $contract.overallTimeoutMilliseconds `
                    -StageTimeoutMilliseconds $contract.loadTimeoutMilliseconds) `
                -StageName 'Load'
        }
        catch {
            if ([string]$_.Exception.Message -cmatch '^PEFP:') {
                throw
            }
            Stop-Pefp 'LoadTransportFailure' ([string]$_.Exception.GetType().FullName)
        }
        $loadHttpStatus = $loadResponse.StatusCode
        if (-not $loadResponse.IsSuccess) {
            Stop-Pefp 'LoadHttpFailure'
        }

        $stage = 'Export'
        try {
            $exportResponse = Invoke-PefpHttpPost `
                -Uri "$baseUrl/Export/UnityProject" `
                -Body @{ Path = $exportRoot; CreateSubfolder = 'false' } `
                -TimeoutMilliseconds (Get-PefpRemainingMilliseconds `
                    -Stopwatch $operationWatch `
                    -OverallTimeoutMilliseconds $contract.overallTimeoutMilliseconds `
                    -StageTimeoutMilliseconds $contract.exportTimeoutMilliseconds) `
                -StageName 'Export'
        }
        catch {
            if ([string]$_.Exception.Message -cmatch '^PEFP:') {
                throw
            }
            Stop-Pefp 'ExportTransportFailure' ([string]$_.Exception.GetType().FullName)
        }
        $exportHttpStatus = $exportResponse.StatusCode
        if (-not $exportResponse.IsSuccess) {
            Stop-Pefp 'ExportHttpFailure'
        }

        $stage = 'Inventory'
        $exportInventory = Get-PefpExportInventory -OutputRoot $exportRoot
        $diagnostics = Get-PefpLogDiagnostics -LogPath $assetRipperLogPath
        $status = if (
            $diagnostics.MissingDependencyWarningCount -gt 0 -or
            $diagnostics.ScriptDeserializationIssueCount -gt 0
        ) {
            'ExportedWithDiagnostics'
        }
        else {
            'Exported'
        }
        $stage = 'Complete'
    }
    catch {
        $rawMessage = [string]$_.Exception.Message
        $failureCode = if ($rawMessage -cmatch '^PEFP:(?<code>[A-Za-z0-9]+)(?::.*)?$') {
            $Matches['code']
        }
        else {
            'RunnerException'
        }
        $exceptionType = $_.Exception.GetType().FullName
        $privateRoots = @($contract.repositoryRoot, $attemptRoot)
        if ($null -ne $binding) {
            $privateRoots += $binding.SourceRoot
        }
        if ($null -ne $tool) {
            $privateRoots += $tool.Path
        }
        $exceptionMessage = ConvertTo-PefpPortableText -Text $rawMessage -PrivateRoots $privateRoots
        $exceptionStack = ConvertTo-PefpPortableText -Text ([string]$_.ScriptStackTrace) -PrivateRoots $privateRoots
        if ($failureCode -match 'Timeout$') {
            $timedOut = $true
        }
    }
    finally {
        if ($null -ne $process) {
            try {
                if (-not $process.HasExited) {
                    Stop-PefpProcessTree -RootProcessId $process.Id
                    [void]$process.WaitForExit([int]$contract.shutdownTimeoutMilliseconds)
                }
                $process.Refresh()
                if ($process.HasExited) {
                    $processExitCode = $process.ExitCode
                }
                else {
                    Stop-Pefp 'CleanupIncomplete'
                }
            }
            catch {
                if ($null -eq $failureCode) {
                    $status = 'Failed'
                    $failureCode = 'CleanupFailure'
                    $exceptionType = $_.Exception.GetType().FullName
                    $exceptionMessage = ConvertTo-PefpPortableText -Text ([string]$_.Exception.Message) -PrivateRoots @($contract.repositoryRoot, $attemptRoot)
                    $exceptionStack = ConvertTo-PefpPortableText -Text ([string]$_.ScriptStackTrace) -PrivateRoots @($contract.repositoryRoot, $attemptRoot)
                }
            }
        }
        try {
            $listenerAbsentAfterShutdown = Test-PefpPortFree -Port $contract.port
            if (-not $listenerAbsentAfterShutdown -and $null -eq $failureCode) {
                $status = 'Failed'
                $failureCode = 'CleanupIncomplete'
                $exceptionType = 'System.InvalidOperationException'
                $exceptionMessage = 'PEFP:CleanupIncomplete:ListenerStillPresent'
                $exceptionStack = $null
            }
        }
        catch {
            $listenerAbsentAfterShutdown = $false
            if ($null -eq $failureCode) {
                $status = 'Failed'
                $failureCode = 'CleanupInspectionFailure'
                $exceptionType = $_.Exception.GetType().FullName
                $exceptionMessage = ConvertTo-PefpPortableText -Text ([string]$_.Exception.Message) -PrivateRoots @($contract.repositoryRoot, $attemptRoot)
                $exceptionStack = ConvertTo-PefpPortableText -Text ([string]$_.ScriptStackTrace) -PrivateRoots @($contract.repositoryRoot, $attemptRoot)
            }
        }

        if ($null -ne $binding -and $beforeRows.Count -eq 16 -and $inputResults.Count -eq 16) {
            try {
                Complete-PefpInputEvidence -SourceRoot $binding.SourceRoot -BeforeRows $beforeRows -InputResults $inputResults
                $sourceUnchanged = @($inputResults | Where-Object { -not $_.unchanged }).Count -eq 0
                if (-not $sourceUnchanged) {
                    Stop-Pefp 'SourceIdentityChanged'
                }
            }
            catch {
                $sourceUnchanged = $false
                $sourcePostCheckFailureCode = 'SourceIdentityChanged'
                if ($null -eq $failureCode) {
                    $status = 'Failed'
                    $failureCode = 'SourceIdentityChanged'
                    $exceptionType = $_.Exception.GetType().FullName
                    $exceptionMessage = ConvertTo-PefpPortableText -Text ([string]$_.Exception.Message) -PrivateRoots @($contract.repositoryRoot, $attemptRoot, $binding.SourceRoot)
                    $exceptionStack = ConvertTo-PefpPortableText -Text ([string]$_.ScriptStackTrace) -PrivateRoots @($contract.repositoryRoot, $attemptRoot, $binding.SourceRoot)
                }
            }
        }
        $operationWatch.Stop()
    }

    if ($null -eq $head) {
        $head = $null
    }
    if ($null -eq $failureCode -and $status -cnotin @('Exported', 'ExportedWithDiagnostics')) {
        $status = 'Failed'
        $failureCode = 'TerminalStateInvariant'
    }

    $logs = @(
        Get-PefpPortableLogFacts -AbsolutePath $assetRipperLogPath -PortablePath 'Logs/assetripper.log'
        Get-PefpPortableLogFacts -AbsolutePath $stdoutPath -PortablePath 'Logs/assetripper.stdout.log'
        Get-PefpPortableLogFacts -AbsolutePath $stderrPath -PortablePath 'Logs/assetripper.stderr.log'
    )
    $inputBytes = [int64](($inputResults | Measure-Object length -Sum).Sum)
    $terminal = [pscustomobject][ordered]@{
        schemaVersion = $contract.schemaVersion
        artifactId = $contract.artifactId
        status = $status
        stage = $stage
        head = $head
        inputResults = @($inputResults)
        inputCount = [int]$inputResults.Count
        inputBytes = $inputBytes
        sourceOpenCount = [int]$counters.SourceOpenCount
        processStartCount = [int]$counters.ProcessStartCount
        assetRipperProcessId = $processId
        assetRipperExitCode = $processExitCode
        childProcesses = @($childProcesses)
        loadHttpStatus = $loadHttpStatus
        exportHttpStatus = $exportHttpStatus
        timedOut = $timedOut
        durationMilliseconds = [int64]$operationWatch.ElapsedMilliseconds
        listenerOwned = $listenerOwned
        listenerAbsentAfterShutdown = $listenerAbsentAfterShutdown
        exportFileCount = [int]$exportInventory.Count
        exportBytes = [int64]$exportInventory.Bytes
        extensionDistribution = @($exportInventory.Distribution)
        missingDependencyWarningCount = [int]$diagnostics.MissingDependencyWarningCount
        uniqueMissingCabCount = [int]$diagnostics.UniqueMissingCabCount
        scriptDeserializationIssueCount = [int]$diagnostics.ScriptDeserializationIssueCount
        logs = $logs
        failureCode = $failureCode
        exceptionType = $exceptionType
        exceptionMessage = $exceptionMessage
        exceptionStack = $exceptionStack
        sourceUnchanged = $sourceUnchanged
        sourcePostCheckFailureCode = $sourcePostCheckFailureCode
        sourcePathLeakCount = 0
        nextAction = 'AwaitPEFPLO1Audit'
    }
    Write-PefpTerminal -LiteralPath $terminalPath -Terminal $terminal
    $terminal
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-PefpProduction
        $result | ConvertTo-Json -Depth 12 -Compress
        if ($result.status -cnotin @('Exported', 'ExportedWithDiagnostics')) {
            exit 1
        }
    }
    catch {
        [pscustomobject][ordered]@{
            status = 'RunnerLaunchFailure'
            stage = 'EntryPoint'
            failureCode = 'RunnerLaunchFailure'
            exceptionType = $_.Exception.GetType().FullName
            exceptionMessage = ConvertTo-PefpPortableText -Text ([string]$_.Exception.Message) -PrivateRoots @()
            exceptionStack = ConvertTo-PefpPortableText -Text ([string]$_.ScriptStackTrace) -PrivateRoots @()
            processStartCount = $null
            sourcePathLeakCount = 0
            nextAction = 'AwaitPEFPLO1Audit'
        } | ConvertTo-Json -Depth 8 -Compress
        exit 1
    }
}
