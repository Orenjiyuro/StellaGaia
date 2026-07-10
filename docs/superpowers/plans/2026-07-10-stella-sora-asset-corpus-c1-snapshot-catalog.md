# StellaSora C1 Source Snapshot And Corpus Catalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Implement C1 Phase A contracts and tests for a deterministic G0 input snapshot and extension-agnostic G1 source corpus catalog without reading the real StellaSora source roots.

**Architecture:** C1 owns a private source-corpus summary, a pure PowerShell module, a lightweight read-only gate, and an explicitly guarded snapshot runner. Portable ledgers remain conformant to the C0 source-corpus-ledger schema; machine-local absolute paths stay in runtime input and ignored Extracted evidence. Phase A exercises only checked-in JSON vectors and temporary synthetic roots, while Phase B alone may refresh the real local snapshot.

**Tech Stack:** PowerShell 7, JSON, SHA-256, the C0 JSON Schema Draft 2020-12 contracts, Git.

---

## Next Three Tasks

1. **Task 0:** Freeze the C1 private summary and fixture contract, then add a lightweight read-only RED harness.
2. **Task 1:** Implement deterministic G0 file, root, and aggregate input fingerprints against temporary synthetic roots.
3. **Task 2:** Implement the G1 all-file catalog and count/byte conservation without extension filtering.

Do not begin C2 implementation until Task 0 freezes the C1 summary fields. C2 may develop against C1 fixtures after Task 0, but real C1-to-C2 integration waits for Task 4.

## Ownership And Safety Boundary

C1 owns only these new paths:

- Tools/AssetImport/SourceCorpusGate.psm1
- Tools/AssetImport/Test-SourceCorpusGate.ps1
- Tools/AssetImport/Test-SourceCorpusSnapshotFunctions.ps1
- Tools/AssetImport/Test-SourceCorpusCatalog.ps1
- Tools/AssetImport/Test-SourceCorpusRunnerPolicy.ps1
- Tools/AssetImport/Test-SourceCorpusC0Compatibility.ps1
- Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1
- Tools/AssetImport/Fixtures/SourceCorpusGate/**
- docs/asset-migration/source-corpus-phase-b-runbook.md
- this plan

C1 must not modify:

- docs/asset-migration/schemas/**
- Tools/AssetImport/Test-AssetCorpusContract.ps1
- Tools/AssetImport/New-StellaSoraAssetInventory.ps1
- Tools/AssetImport/Test-AndroidUnityPackageIntake.ps1
- Tools/AssetImport/tool-manifest.json
- shared root gates, CONTEXT.md, total status documents, Unity files, or imported assets

The historical inventory remains a five-extension classification report and is not G1 evidence. Android intake remains a diagnostic scanner and is not a source-completeness gate. Any C0 schema gap becomes a handoff contract-change request; C1 never edits shared schemas directly.

Phase A must not:

- read C:\SoftGame\YostarGames\StellaSora_CN;
- invent or persist APK or Android DATA/cache paths;
- create repository Extracted content;
- run Unity, AssetRipper, extraction, decoding, or another heavy child process;
- commit third-party or synthetic binary assets.

All synthetic source trees are created below [System.IO.Path]::GetTempPath(), use tiny text payloads, and are removed in finally blocks.

## Frozen Data Contracts

### Runtime source-root input

The runner accepts a machine-local JSON file with this exact shape:

~~~json
{
  "schemaVersion": "1.0.0",
  "sources": [
    {
      "sourceId": "pc-install",
      "sourceKind": "PcInstall",
      "rootPath": "C:\\machine-local\\source"
    }
  ]
}
~~~

rootPath is runtime-only. It is never copied into the portable ledger or C1 portable summary. sourceId is unique and case-sensitive. sourceKind is exactly one of PcInstall, PcPatchOrCache, AndroidApk, or AndroidDataOrCache.

### C1 private portable summary

The summary uses exact-case fields and rejects extra properties:

~~~json
{
  "schemaVersion": "1.0.0",
  "generatedAt": "2026-07-10T12:00:00+08:00",
  "snapshotId": "snapshot-pc-install-001",
  "inputFingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "ledgerInputFingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "ledgerPath": "Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json",
  "toolVersions": [
    {
      "toolName": "source-corpus-gate",
      "version": "1.0.0"
    }
  ],
  "operationIdentity": "C1.SourceCorpusGate.FixtureValidation",
  "directChildSummaries": [
    "Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json"
  ],
  "directChildReports": [],
  "failureAttribution": "None; the positive fixture intentionally contains no failures.",
  "nextAllowedAction": "Implement deterministic G0 fingerprints against temporary synthetic roots.",
  "sourceCount": 1,
  "sourceFileCount": 1,
  "catalogedFileCount": 1,
  "explicitlyExcludedFileCount": 0,
  "sourceBytes": 4096,
  "catalogedBytes": 4096,
  "explicitlyExcludedBytes": 0,
  "sources": [
    {
      "sourceId": "pc-install-primary",
      "sourceKind": "PcInstall",
      "rootFingerprint": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
      "sourceFileCount": 1,
      "sourceBytes": 4096
    }
  ],
  "exclusions": []
}
~~~

The summary, not the C0 portable ledger, owns count and exclusion conservation. Every exclusion requires sourceId, relativePath, sizeBytes, and a non-empty reason. Phase A fixtures default to zero exclusions, but negative fixtures prove both count and byte formulas:

~~~text
sourceFileCount = catalogedFileCount + explicitlyExcludedFileCount
sourceBytes = catalogedBytes + explicitlyExcludedBytes
sourceFileCount = sum(sources[*].sourceFileCount)
sourceBytes = sum(sources[*].sourceBytes)
explicitlyExcludedFileCount = exclusions.Count
explicitlyExcludedBytes = sum(exclusions[*].sizeBytes)
~~~

For every sourceId, the source row totals must equal that source's ledger file rows plus that source's exclusion rows. The summary source IDs/kinds/root fingerprints must match the ledger sources exactly; no missing or extra source row is permitted.

### Canonical fingerprint encoding

Normalize portable relative paths to forward slashes. Reject absolute paths, URI schemes, empty paths, dot or dot-dot segments, duplicate normalized paths, and case-only collisions. Reject sourceId values containing NUL, CR, or LF before canonical encoding.

For each file, compute lowercase SHA-256 over its bytes. Encode one canonical file record as UTF-8 without BOM:

~~~text
relativePath + NUL + sizeBytes(base-10 invariant) + NUL + sha256 + LF
~~~

Sort file records by normalized relativePath using ordinal comparison. rootFingerprint is lowercase SHA-256 over the concatenated canonical file-record bytes.

Encode one canonical source record as UTF-8 without BOM:

~~~text
sourceId + NUL + sourceKind + NUL + rootFingerprint + LF
~~~

Sort source records by sourceId using ordinal comparison. inputFingerprint is lowercase SHA-256 over the concatenated canonical source-record bytes.

One run-level UTC generatedAt value supplies every capturedAt field. Do not call the clock separately per source or file.

### Default G1 status

Unknown, extensionless, opaque, or not-yet-parsed files remain visible. Before G2:

~~~text
Corpus=Cataloged
Extraction=NotAttempted
Semantics=Unknown
Unity=NotTested
Disposition=RetainForLater
~~~

containerKind may describe a known direct format or UnknownInput, but it must not imply parsing success. The C0 ledger objects array stays empty until C2.

---

### Task 0: Freeze C1 Summary Fixtures And Lightweight Gate

**Files:**

- Create: Tools/AssetImport/Test-SourceCorpusGate.ps1
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-source-count-conservation.json
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-source-byte-conservation.json
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-ledger-fingerprint.json
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-unreasoned-exclusion.json
- Read: docs/asset-migration/schemas/source-corpus-ledger.schema.json

- [ ] **Step 1: Add the summary-first failing harness**

Create Test-SourceCorpusGate.ps1 with optional SummaryPath and LedgerPath parameters. Default LedgerPath points to the not-yet-created C1 G1 positive ledger. Default SummaryPath points to the not-yet-created C1 valid summary.

The result object is:

~~~powershell
[pscustomobject][ordered]@{
    status                      = 'Failed'
    issueCount                  = $issues.Count
    issues                      = $issues.ToArray()
    sourceCount                 = 0
    sourceFileCount             = 0
    catalogedFileCount          = 0
    explicitlyExcludedFileCount = 0
    sourceBytes                 = 0
    catalogedBytes              = 0
    explicitlyExcludedBytes     = 0
    positiveFixtureCount        = 0
    negativeFixtureCount        = 0
    childProcessCount           = 0
    durationMs                  = $stopwatch.ElapsedMilliseconds
}
~~~

It must parse JSON strictly with JsonDocument.Parse plus ConvertFrom-Json -Depth 100 -DateKind String, emit one compressed JSON line, and throw only after emitting JSON when issues exist.

- [ ] **Step 2: Run RED**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
~~~

Expected: exit 1; stdout parses as JSON; first issue starts with Missing contract file: and ends with valid-source-corpus-summary.json; childProcessCount is 0; no Extracted directory is created.

- [ ] **Step 3: Add a dedicated C1 positive ledger**

Create valid-c1-source-corpus-ledger.json with one PcInstall source and one file. Use the same run-level generatedAt value for source/file capturedAt, parseStatus NotAttempted, Cataloged/NotAttempted/Unknown/NotTested/RetainForLater status, no object rows, and no machine path. Keep the existing C0 schema exact: do not add C1 summary fields to the ledger.

- [ ] **Step 4: Add the matching private summary**

Add the exact private-summary shape above. Make ledgerInputFingerprint equal the ledger inputFingerprint. Require sourceCount to equal ledger.sources.Count; sourceId, sourceKind, and rootFingerprint to match the ledger source row exactly; catalogedFileCount to equal ledger.files.Count; catalogedBytes to equal the sum of ledger file sizeBytes; summary sourceFileCount/sourceBytes to equal the sums of per-source totals; exclusions count/bytes to equal the exclusions array; and each source row's totals to equal its own ledger rows plus its own exclusions.

- [ ] **Step 5: Add four one-rule negative summaries**

Each negative vector changes one rule only:

- invalid-source-count-conservation: sourceFileCount differs from cataloged plus excluded.
- invalid-source-byte-conservation: sourceBytes differs from cataloged plus excluded.
- invalid-ledger-fingerprint: ledgerInputFingerprint differs from inputFingerprint.
- invalid-unreasoned-exclusion: one exclusion has an empty reason.

Stable designated issues are:

~~~text
Source file conservation failed.
Source byte conservation failed.
Source corpus ledger input fingerprint is stale.
Explicit exclusion requires a non-empty reason for '<sourceId>/<relativePath>'.
~~~

- [ ] **Step 6: Require cross-ledger and exact negative outcomes**

Before evaluating negative summaries, cross-check the positive ledger and summary. Stable cross-ledger issues are Source count does not match source corpus ledger., Source identity does not match source corpus ledger for '<sourceId>'., Cataloged file count does not match source corpus ledger., Cataloged bytes do not match source corpus ledger., Source totals do not equal per-source totals., Exclusion totals do not match the exclusion rows., and Per-source conservation failed for '<sourceId>'.

Load each negative fixture into an isolated issue list. A fixture passes only when its actual list exactly equals its one designated issue. Missing expected issues, structural issues, or unexpected extra issues fail the overall gate. Count only exact-verified negative fixtures.

- [ ] **Step 7: Verify GREEN**

Run:

~~~powershell
$result = pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1 | ConvertFrom-Json
$result | Format-List
~~~

Expected: Passed; issueCount 0; sourceCount 1; positiveFixtureCount 2; negativeFixtureCount 4; childProcessCount 0; under five seconds; no Extracted.

- [ ] **Step 8: Parse the harness AST**

Run:

~~~powershell
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\Tools\AssetImport\Test-SourceCorpusGate.ps1), [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw ($errors | Out-String) }
~~~

Expected: no output and exit 0.

- [ ] **Step 9: Strictly parse all six Task 0 JSON fixtures**

Run:

~~~powershell
Get-ChildItem .\Tools\AssetImport\Fixtures\SourceCorpusGate\*.json | ForEach-Object {
    $text = Get-Content -LiteralPath $_.FullName -Raw
    $null = $text | ConvertFrom-Json -Depth 100 -DateKind String
    $document = [System.Text.Json.JsonDocument]::Parse($text)
    $document.Dispose()
}
~~~

Expected: exit 0 with no parser errors.

- [ ] **Step 10: Check dangerous commands**

Use the Step 8 AST and fail when a CommandAst resolves to Start-Process, pwsh, powershell, Unity, AssetRipper, or a .ps1 path. Expected dangerous command count: 0.

~~~powershell
$danger = @($ast.FindAll({
    param($node)
    if ($node -isnot [System.Management.Automation.Language.CommandAst]) { return $false }
    $name = $node.GetCommandName()
    return $name -in @('Start-Process', 'pwsh', 'powershell', 'Unity', 'AssetRipper') -or
        ($null -ne $name -and $name -like '*.ps1')
}, $true))
if ($danger.Count -ne 0) { throw ($danger.Extent.Text -join [Environment]::NewLine) }
~~~

- [ ] **Step 11: Check scope and whitespace**

Run git diff --check and git diff --name-only. Expected: Test-SourceCorpusGate.ps1 plus exactly six SourceCorpusGate JSON fixtures; Test-Path .\Extracted remains false.

~~~powershell
git diff --check
$changed = @(git diff --name-only)
if ($changed.Count -ne 7) { throw "Expected 7 Task 0 paths, got $($changed.Count)." }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 0 created Extracted.' }
~~~

- [ ] **Step 12: Commit Task 0**

Commit:

~~~powershell
git add -- Tools/AssetImport/Test-SourceCorpusGate.ps1 Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-source-count-conservation.json Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-source-byte-conservation.json Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-ledger-fingerprint.json Tools/AssetImport/Fixtures/SourceCorpusGate/invalid-unreasoned-exclusion.json
git commit -m "test: freeze source corpus gate contract"
~~~

**Out-of-scope assertion:** no source-root enumeration, hashing, output writing, C0 schema edit, or child process is introduced in Task 0.

---

### Task 1: Implement Deterministic G0 Fingerprints

**Files:**

- Create: Tools/AssetImport/SourceCorpusGate.psm1
- Create: Tools/AssetImport/Test-SourceCorpusSnapshotFunctions.ps1

- [ ] **Step 1: Write canonical-record RED tests**

In Test-SourceCorpusSnapshotFunctions.ps1, accept Case with Primitive, Root, Input, or All. Import the module after asserting it is missing. Define expected UTF-8 byte sequences for one file record and one source record, including literal NUL separators and LF termination.

~~~powershell
[CmdletBinding()]
param([ValidateSet('Primitive', 'Root', 'Input', 'All')][string]$Case = 'All')

$modulePath = Join-Path $PSScriptRoot 'SourceCorpusGate.psm1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "Missing module: $modulePath"
}
Import-Module $modulePath -Force
~~~

- [ ] **Step 2: Run RED**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case Primitive
~~~

Expected: exit 1 with Missing module: ...SourceCorpusGate.psm1 and no parser or parameter-binding error.

- [ ] **Step 3: Implement exact JSON and path primitives**

Implement and export these exact functions:

~~~powershell
function Get-ExactJsonPropertyByPath {
    param([AllowNull()][object]$Value, [Parameter(Mandatory)][string]$Path)
    $current = $Value
    foreach ($segment in $Path.Split('.')) {
        if ($current -isnot [System.Management.Automation.PSCustomObject]) { return $null }
        $match = @($current.PSObject.Properties | Where-Object Name -CEQ $segment)
        if ($match.Count -ne 1) { return $null }
        $current = $match[0].Value
    }
    return $current
}

function ConvertTo-PortableRelativePath {
    param([Parameter(Mandatory)][string]$RootPath, [Parameter(Mandatory)][string]$FilePath)
    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\', '/')
    $file = [System.IO.Path]::GetFullPath($FilePath)
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $file.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "File path is outside source root: $FilePath"
    }
    $relative = [System.IO.Path]::GetRelativePath($root, $file).Replace('\', '/')
    if (
        [string]::IsNullOrWhiteSpace($relative) -or
        [System.IO.Path]::IsPathRooted($relative) -or
        $relative -match '^[A-Za-z][A-Za-z0-9+.-]*:' -or
        $relative -match '(^|/)\.{1,2}(/|$)'
    ) {
        throw "Invalid portable relative path: $relative"
    }
    return $relative
}

function Get-LowercaseSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
    return [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Assert-UniquePortablePaths {
    param([Parameter(Mandatory)][string[]]$RelativePaths)
    $ordinal = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $ignoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($path in $RelativePaths) {
        if (-not $ordinal.Add($path)) { throw "Duplicate normalized relative path: $path" }
        if (-not $ignoreCase.Add($path)) { throw "Case-only relative path collision: $path" }
    }
}

function New-CanonicalFileRecordBytes {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][long]$SizeBytes,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$Sha256
    )
    $sizeText = $SizeBytes.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $record = $RelativePath + [char]0 + $sizeText + [char]0 + $Sha256 + [char]10
    return [System.Text.UTF8Encoding]::new($false, $true).GetBytes($record)
}

function New-CanonicalSourceRecordBytes {
    param(
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourceKind,
        [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{64}$')][string]$RootFingerprint
    )
    if ([string]::IsNullOrWhiteSpace($SourceId) -or $SourceId -match "[\x00\r\n]") {
        throw 'sourceId must be non-empty and must not contain NUL, CR, or LF.'
    }
    $record = $SourceId + [char]0 + $SourceKind + [char]0 + $RootFingerprint + [char]10
    return [System.Text.UTF8Encoding]::new($false, $true).GetBytes($record)
}
~~~

ConvertTo-PortableRelativePath validates one root/file pair. Assert-UniquePortablePaths performs collection-level duplicate and case-only collision checks without hidden mutable state. Exact JSON traversal enumerates PSObject.Properties and compares Name with -ceq.

- [ ] **Step 4: Verify primitive GREEN**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case Primitive
~~~

Expected: one compressed JSON line with status Passed, case Primitive, issueCount 0, and no temp paths left behind.

- [ ] **Step 5: Write root fingerprint RED tests**

Create two temporary roots with the same two tiny text files created in opposite order. Assert equal root fingerprints and exact expected SHA-256. Modify one byte and assert a different fingerprint. Wrap creation and cleanup in try/finally.

- [ ] **Step 6: Implement file and root hashing**

Add and export:

~~~powershell
function Get-SourceRootFingerprint {
    param([Parameter(Mandatory)][object[]]$Files)
    $ordered = [object[]]$Files.Clone()
    $comparison = [System.Comparison[object]]{
        param($left, $right)
        [System.StringComparer]::Ordinal.Compare(
            [string]$left.relativePath,
            [string]$right.relativePath
        )
    }
    [System.Array]::Sort($ordered, $comparison)
    Assert-UniquePortablePaths -RelativePaths @($ordered | ForEach-Object relativePath)
    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($file in $ordered) {
            $record = New-CanonicalFileRecordBytes -RelativePath $file.relativePath -SizeBytes $file.sizeBytes -Sha256 $file.sha256
            $stream.Write($record, 0, $record.Length)
        }
        return Get-LowercaseSha256 -Bytes $stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}
~~~

- [ ] **Step 7: Verify root fingerprint GREEN**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case Root
~~~

Expected: status Passed, case Root, issueCount 0; the one-byte mutation changes the root fingerprint.

- [ ] **Step 8: Write aggregate input fingerprint RED tests**

Create two source descriptions in opposite order. Assert equal inputFingerprint after sourceId ordinal sorting. Assert duplicate sourceId, sourceId containing NUL/CR/LF, invalid sourceKind, and root fingerprint with non-lowercase hex fail.

- [ ] **Step 9: Implement aggregate fingerprint**

Add and export:

~~~powershell
function Get-SourceInputFingerprint {
    param([Parameter(Mandatory)][object[]]$Sources)
    $allowedKinds = @('PcInstall', 'PcPatchOrCache', 'AndroidApk', 'AndroidDataOrCache')
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($source in $Sources) {
        if (
            [string]::IsNullOrWhiteSpace([string]$source.sourceId) -or
            [string]$source.sourceId -match "[\x00\r\n]" -or
            -not $seen.Add([string]$source.sourceId)
        ) {
            throw "Invalid or duplicate sourceId: $($source.sourceId)"
        }
        if ([string]$source.sourceKind -cnotin $allowedKinds) {
            throw "Unsupported sourceKind: $($source.sourceKind)"
        }
        if ([string]$source.rootFingerprint -cnotmatch '^[0-9a-f]{64}$') {
            throw "Invalid rootFingerprint for sourceId '$($source.sourceId)'."
        }
    }
    $ordered = [object[]]$Sources.Clone()
    $comparison = [System.Comparison[object]]{
        param($left, $right)
        [System.StringComparer]::Ordinal.Compare([string]$left.sourceId, [string]$right.sourceId)
    }
    [System.Array]::Sort($ordered, $comparison)
    $stream = [System.IO.MemoryStream]::new()
    try {
        foreach ($source in $ordered) {
            $record = New-CanonicalSourceRecordBytes -SourceId $source.sourceId -SourceKind $source.sourceKind -RootFingerprint $source.rootFingerprint
            $stream.Write($record, 0, $record.Length)
        }
        return Get-LowercaseSha256 -Bytes $stream.ToArray()
    }
    finally {
        $stream.Dispose()
    }
}
~~~

- [ ] **Step 10: Verify aggregate and full GREEN**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case Input
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
~~~

Expected: both invocations exit 0 with status Passed and issueCount 0.

- [ ] **Step 11: Parse module and test ASTs**

Run:

~~~powershell
foreach ($path in @(
    '.\Tools\AssetImport\SourceCorpusGate.psm1',
    '.\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1'
)) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -ne 0) { throw ($errors | Out-String) }
}
~~~

Expected: exit 0 with no AST errors.

- [ ] **Step 12: Run the Task 0 gate regression**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
~~~

Expected: Passed with positiveFixtureCount 2, negativeFixtureCount 4, and childProcessCount 0.

- [ ] **Step 13: Check scope and side effects**

Run git diff --check and git diff --name-only. Expected changed files: SourceCorpusGate.psm1 and Test-SourceCorpusSnapshotFunctions.ps1 only. Test-Path .\Extracted must be false, and the test result must report zero leftover temp roots.

~~~powershell
git diff --check
$changed = @(git diff --name-only)
if ($changed.Count -ne 2) { throw "Expected 2 Task 1 paths, got $($changed.Count)." }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 1 created Extracted.' }
~~~

- [ ] **Step 14: Commit Task 1**

Commit:

~~~powershell
git add -- Tools/AssetImport/SourceCorpusGate.psm1 Tools/AssetImport/Test-SourceCorpusSnapshotFunctions.ps1
git commit -m "feat: add deterministic source snapshot fingerprints"
~~~

**Out-of-scope assertion:** Task 1 does not enumerate real roots, write a portable ledger, or add the Phase B runner.

---

### Task 2: Implement G1 All-File Catalog And Conservation

**Files:**

- Modify: Tools/AssetImport/SourceCorpusGate.psm1
- Create: Tools/AssetImport/Test-SourceCorpusCatalog.ps1

- [ ] **Step 1: Write extension-agnostic RED tests**

Create a temporary source root containing:

~~~text
known/data.unity3d
unknown/payload.arcx
unknown/metadata.arch
unknown/README
hidden/hidden.dat
empty/zero.bin
~~~

Use tiny text content and a zero-byte file. After creating hidden/hidden.dat, set the real Windows Hidden attribute:

~~~powershell
$hiddenPath = Join-Path $root 'hidden\hidden.dat'
[System.IO.File]::WriteAllText($hiddenPath, 'hidden')
$attributes = [System.IO.File]::GetAttributes($hiddenPath)
[System.IO.File]::SetAttributes($hiddenPath, $attributes -bor [System.IO.FileAttributes]::Hidden)
~~~

Assert all six relative paths appear exactly once, including the Hidden-attribute, extensionless, unknown-extension, and zero-byte files. The production enumerator must use -Force.

Test-SourceCorpusCatalog.ps1 accepts Case with AllFile, Conservation, FailureModes, or All and always removes its unique temp root in finally.

- [ ] **Step 2: Run RED**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case AllFile
~~~

Expected: exit 1 because New-SourceCorpusCatalog is not exported; temp-root setup and cleanup both succeed.

- [ ] **Step 3: Implement fail-closed enumeration**

Add and export:

~~~powershell
function New-SourceCorpusCatalog {
    param(
        [Parameter(Mandatory)][string]$SnapshotId,
        [Parameter(Mandatory)][string]$SourceId,
        [Parameter(Mandatory)][string]$SourceKind,
        [Parameter(Mandatory)][string]$RootPath,
        [Parameter(Mandatory)][datetimeoffset]$CapturedAt,
        [object[]]$Exclusions = @(),
        [scriptblock]$FileEnumerator = {
            param($path)
            Get-ChildItem -LiteralPath $path -Recurse -File -Force -ErrorAction Stop
        }
    )
    $rootItem = Get-Item -LiteralPath $RootPath -Force -ErrorAction Stop
    Assert-NoReparsePoint -Attributes $rootItem.Attributes -Label 'Source root'
    try {
        $items = @(& $FileEnumerator $rootItem.FullName)
    }
    catch {
        throw "Source enumeration failed: $($_.Exception.Message)"
    }

    $portablePaths = [System.Collections.Generic.List[string]]::new()
    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $items) {
        Assert-NoReparsePoint -Attributes $item.Attributes -Label $item.FullName
        $relativePath = ConvertTo-PortableRelativePath -RootPath $rootItem.FullName -FilePath $item.FullName
        $portablePaths.Add($relativePath)
        $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
        $status = [pscustomobject][ordered]@{
            corpus = 'Cataloged'
            extraction = 'NotAttempted'
            semantics = 'Unknown'
            unity = 'NotTested'
            disposition = 'RetainForLater'
        }
        $rows.Add([pscustomobject][ordered]@{
            snapshotId = $SnapshotId
            sourceId = $SourceId
            sourceKind = $SourceKind
            relativePath = $relativePath
            sizeBytes = [long]$bytes.Length
            sha256 = Get-LowercaseSha256 -Bytes $bytes
            capturedAt = $CapturedAt.ToUniversalTime().ToString('O')
            containerKind = Get-SourceContainerKind -RelativePath $relativePath
            parseStatus = 'NotAttempted'
            disposition = 'RetainForLater'
            evidence = @()
            status = $status
        })
    }
    Assert-UniquePortablePaths -RelativePaths $portablePaths.ToArray()
    $validatedExclusions = Assert-ValidSourceExclusions -Exclusions $Exclusions -SourceId $SourceId
    return [pscustomobject][ordered]@{
        files = $rows.ToArray()
        exclusions = $validatedExclusions
        catalogedFileCount = $rows.Count
        catalogedBytes = [long](($rows | Measure-Object sizeBytes -Sum).Sum)
        explicitlyExcludedFileCount = $validatedExclusions.Count
        explicitlyExcludedBytes = [long](($validatedExclusions | Measure-Object sizeBytes -Sum).Sum)
    }
}

function Assert-NoReparsePoint {
    param([System.IO.FileAttributes]$Attributes, [Parameter(Mandatory)][string]$Label)
    if (($Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "$Label is a reparse point."
    }
}

function Assert-ValidSourceExclusions {
    param([object[]]$Exclusions, [Parameter(Mandatory)][string]$SourceId)
    foreach ($exclusion in $Exclusions) {
        if (
            [string]$exclusion.sourceId -cne $SourceId -or
            [string]::IsNullOrWhiteSpace([string]$exclusion.relativePath) -or
            [long]$exclusion.sizeBytes -lt 0 -or
            [string]::IsNullOrWhiteSpace([string]$exclusion.reason)
        ) {
            throw "Invalid explicit exclusion for sourceId '$SourceId'."
        }
    }
    return @($Exclusions)
}

function Get-SourceContainerKind {
    param([Parameter(Mandatory)][string]$RelativePath)
    switch ([System.IO.Path]::GetExtension($RelativePath).ToLowerInvariant()) {
        '.unity3d' { return 'UnityBundle' }
        '.bundle' { return 'UnityBundle' }
        '.assets' { return 'UnitySerializedAsset' }
        '.wem' { return 'DirectAudio' }
        '.bnk' { return 'AudioMetadata' }
        '.mp4' { return 'DirectVideo' }
        '.srt' { return 'Metadata' }
        '.json' { return 'ConfigurationCandidate' }
        default { return 'UnknownInput' }
    }
}
~~~

Get-SourceContainerKind is a pure classifier; its default is UnknownInput and it never changes parseStatus. Enumerate every regular file without extension filtering. Do not use ErrorAction SilentlyContinue. Reject a source root or child that is a reparse point, symlink, or junction. Turn access failures, duplicate normalized paths, and case collisions into structured fatal issues.

- [ ] **Step 4: Emit C0-compatible file rows**

For each file emit snapshotId, sourceId, sourceKind, normalized relativePath, sizeBytes, lowercase sha256, the run-level capturedAt, containerKind, parseStatus, disposition, evidence, and orthogonal status. Keep objects empty.

The default status object is exactly:

~~~powershell
[pscustomobject][ordered]@{
    corpus = 'Cataloged'
    extraction = 'NotAttempted'
    semantics = 'Unknown'
    unity = 'NotTested'
    disposition = 'RetainForLater'
}
~~~

- [ ] **Step 5: Add conservation RED tests**

Assert the generated private summary satisfies both count and byte formulas. Mutate cataloged count, cataloged bytes, and an exclusion reason independently and confirm the lightweight gate rejects each.

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case Conservation
~~~

Expected RED: exit 1 because exclusion/conservation support is not implemented; the failure identifies the missing behavior.

- [ ] **Step 6: Implement exclusions**

Support explicit exclusions only when sourceId, normalized relativePath, non-negative sizeBytes, and non-empty reason are supplied:

~~~powershell
[pscustomobject][ordered]@{
    sourceId = 'pc-install'
    relativePath = 'known/explicitly-excluded.bin'
    sizeBytes = 3
    reason = 'Fixture-only explicit exclusion.'
}
~~~

Phase A catalog generation uses no exclusions. Never silently convert an access or reparse error into an exclusion.

- [ ] **Step 7: Define exact failure-mode tests**

In the FailureModes case:

- pass a FileEnumerator that throws [System.UnauthorizedAccessException]::new('denied-fixture') and require Source enumeration failed: denied-fixture;
- call Assert-NoReparsePoint with ReparsePoint for labels Source root and child-link and require the respective stable reparse issue;
- pass @('a/b.bin', 'a/b.bin') to Assert-UniquePortablePaths and require Duplicate normalized relative path: a/b.bin;
- pass @('A/b.bin', 'a/b.bin') and require Case-only relative path collision: a/b.bin;
- verify every failure leaves leftoverTempRootCount 0.

- [ ] **Step 8: Verify C0 status semantics**

Assert unknown and extensionless files are Cataloged, NotAttempted, Unknown, NotTested, and RetainForLater. Confirm they increase corpus counts and bytes and do not create object rows.

- [ ] **Step 9: Verify all catalog cases**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case AllFile
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case Conservation
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case FailureModes
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
~~~

Expected: each invocation emits status Passed and issueCount 0. All reports show leftoverTempRootCount 0.

- [ ] **Step 10: Run prior C1 regressions**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 2 regression created Extracted.' }
~~~

Expected: both scripts emit status Passed and the final assertion exits 0.

- [ ] **Step 11: Parse ASTs and scan dangerous commands**

Run:

~~~powershell
foreach ($path in @(
    '.\Tools\AssetImport\SourceCorpusGate.psm1',
    '.\Tools\AssetImport\Test-SourceCorpusCatalog.ps1'
)) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw ($errors | Out-String) }
    $danger = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -in @('Start-Process', 'pwsh', 'powershell', 'Unity', 'AssetRipper')
    }, $true))
    if ($danger.Count -ne 0) { throw ($danger.Extent.Text -join [Environment]::NewLine) }
}
~~~

Expected AST error count 0 and dangerous-command count 0.

- [ ] **Step 12: Check scope and whitespace**

Run:

~~~powershell
git diff --check
$changed = @(git diff --name-only)
if ($changed.Count -ne 2) { throw "Expected 2 Task 2 paths, got $($changed.Count)." }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 2 created Extracted.' }
~~~

Expected: exit 0; changed files are SourceCorpusGate.psm1 and Test-SourceCorpusCatalog.ps1 only.

- [ ] **Step 13: Commit Task 2**

Commit:

~~~powershell
git add -- Tools/AssetImport/SourceCorpusGate.psm1 Tools/AssetImport/Test-SourceCorpusCatalog.ps1
git commit -m "feat: catalog every source file"
~~~

**Out-of-scope assertion:** Task 2 classifies no Unity objects, launches no extraction tool, and does not inspect the real PC or Android inputs.

---

### Task 3: Add The Explicitly Guarded Snapshot Runner

**Files:**

- Create: Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1
- Create: Tools/AssetImport/Test-SourceCorpusRunnerPolicy.ps1
- Modify: Tools/AssetImport/SourceCorpusGate.psm1

- [ ] **Step 1: Write fail-closed CLI RED tests**

Create Test-SourceCorpusRunnerPolicy.ps1 with Case values MissingRefresh, WrongOutput, InvalidThreadId, Reparse, or All. Require SourceRootManifestPath, OutputRoot, ThreadId, and the explicit RefreshSnapshot switch. Without RefreshSnapshot the script must emit a structured refusal and create no directory.

- [ ] **Step 2: Run RED**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case MissingRefresh
~~~

Expected: exit 1 because New-StellaSoraSourceCorpusSnapshot.ps1 is missing. Confirm repository Extracted remains absent.

- [ ] **Step 3: Implement runtime manifest validation**

Start the runner with this exact parameter contract:

~~~powershell
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceRootManifestPath,
    [Parameter(Mandatory)][string]$OutputRoot,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')][string]$ThreadId,
    [switch]$RefreshSnapshot
)
if (-not $RefreshSnapshot) {
    throw 'RefreshSnapshot is required; no source roots were read and no output was created.'
}
~~~

Require schemaVersion 1.0.0 and exact-case sourceId, sourceKind, rootPath fields. Allow absolute rootPath only in this runtime input. Reject ThreadId values containing separators, dot segments, uppercase hex, or any non-GUID shape before joining paths. Never copy rootPath into portable outputs.

- [ ] **Step 4: Implement output containment**

Canonicalize OutputRoot and require it to equal:

~~~powershell
Join-Path $repositoryRoot "Extracted\Threads\$ThreadId\C1"
~~~

Add and export a pure policy function. The runner supplies real existing-chain attributes; the policy test supplies synthetic attribute records, so Phase A never creates repository Extracted:

~~~powershell
function Assert-C1OutputPathPolicy {
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$ThreadId,
        [object[]]$ExistingPathAttributes = @()
    )
    if ($ThreadId -cnotmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
        throw "Invalid ThreadId: $ThreadId"
    }
    $expected = [System.IO.Path]::GetFullPath(
        (Join-Path $RepositoryRoot "Extracted\Threads\$ThreadId\C1")
    )
    $actual = [System.IO.Path]::GetFullPath($OutputRoot)
    if (-not [string]::Equals($actual, $expected, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "OutputRoot must equal $expected."
    }
    foreach ($item in $ExistingPathAttributes) {
        Assert-NoReparsePoint -Attributes $item.attributes -Label $item.path
    }
    return $expected
}
~~~

The runner enumerates only currently existing repository/output ancestors with Get-Item -Force -ErrorAction Stop and passes their path/attributes to Assert-C1OutputPathPolicy before creating anything.

- [ ] **Step 5: Implement portable output writing**

Write source-corpus-ledger.json and source-corpus-summary.json. The ledger must conform to the C0 schema and contain no machine path. The summary uses the C1 private contract. Both share snapshotId, generatedAt, and inputFingerprint.

Add and export the pure writer used by temp tests and by the guarded runner:

~~~powershell
function New-SourceCorpusSummary {
    param(
        [Parameter(Mandatory)][object]$Ledger,
        [Parameter(Mandatory)][string]$LedgerPath,
        [Parameter(Mandatory)][object[]]$SourceTotals,
        [object[]]$Exclusions = @()
    )
    $catalogedBytes = [long](($Ledger.files | Measure-Object sizeBytes -Sum).Sum)
    $excludedBytes = [long](($Exclusions | Measure-Object sizeBytes -Sum).Sum)
    $sourceFileCount = [long](($SourceTotals | Measure-Object sourceFileCount -Sum).Sum)
    $sourceBytes = [long](($SourceTotals | Measure-Object sourceBytes -Sum).Sum)
    if ($sourceFileCount -ne @($Ledger.files).Count + @($Exclusions).Count) {
        throw 'Source file conservation failed.'
    }
    if ($sourceBytes -ne $catalogedBytes + $excludedBytes) {
        throw 'Source byte conservation failed.'
    }
    return [pscustomobject][ordered]@{
        schemaVersion = '1.0.0'
        generatedAt = $Ledger.generatedAt
        snapshotId = $Ledger.snapshotId
        inputFingerprint = $Ledger.inputFingerprint
        ledgerInputFingerprint = $Ledger.inputFingerprint
        ledgerPath = $LedgerPath
        toolVersions = @([pscustomobject]@{ toolName = 'source-corpus-gate'; version = '1.0.0' })
        operationIdentity = 'C1.SourceCorpusSnapshot.Refresh'
        directChildSummaries = @($LedgerPath)
        directChildReports = @()
        failureAttribution = 'None; snapshot generation completed without a recorded failure.'
        nextAllowedAction = 'Provide the portable ledger and summary to C2 discovery.'
        sourceCount = @($Ledger.sources).Count
        sourceFileCount = $sourceFileCount
        catalogedFileCount = @($Ledger.files).Count
        explicitlyExcludedFileCount = @($Exclusions).Count
        sourceBytes = $sourceBytes
        catalogedBytes = $catalogedBytes
        explicitlyExcludedBytes = $excludedBytes
        sources = $SourceTotals
        exclusions = @($Exclusions)
    }
}

function Write-SourceCorpusOutputs {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][object]$Ledger,
        [Parameter(Mandatory)][object]$Summary
    )
    $parent = Split-Path -Parent $OutputRoot
    $staging = Join-Path $parent ('.c1-staging-' + [guid]::NewGuid().ToString('N'))
    try {
        $null = [System.IO.Directory]::CreateDirectory($staging)
        $ledgerPath = Join-Path $staging 'source-corpus-ledger.json'
        $summaryPath = Join-Path $staging 'source-corpus-summary.json'
        $Ledger | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $ledgerPath -Encoding utf8NoBOM
        $Summary | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
        if (Test-Path -LiteralPath $OutputRoot) { throw "OutputRoot already exists: $OutputRoot" }
        Move-Item -LiteralPath $staging -Destination $OutputRoot
        return [pscustomobject][ordered]@{
            ledgerPath = Join-Path $OutputRoot 'source-corpus-ledger.json'
            summaryPath = Join-Path $OutputRoot 'source-corpus-summary.json'
        }
    }
    finally {
        if (Test-Path -LiteralPath $staging) {
            Remove-Item -LiteralPath $staging -Recurse -Force
        }
    }
}
~~~

After importing SourceCorpusGate.psm1, the runner body is:

~~~powershell
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$existingAttributes = [System.Collections.Generic.List[object]]::new()
$cursor = $repositoryRoot
foreach ($segment in @('Extracted', 'Threads', $ThreadId, 'C1')) {
    $cursor = Join-Path $cursor $segment
    if (Test-Path -LiteralPath $cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        $existingAttributes.Add([pscustomobject]@{ path = $item.FullName; attributes = $item.Attributes })
    }
}
$validatedOutput = Assert-C1OutputPathPolicy -RepositoryRoot $repositoryRoot -OutputRoot $OutputRoot -ThreadId $ThreadId -ExistingPathAttributes $existingAttributes.ToArray()

$manifestText = Get-Content -LiteralPath $SourceRootManifestPath -Raw -ErrorAction Stop
$manifestDocument = [System.Text.Json.JsonDocument]::Parse($manifestText)
try {
    $manifest = $manifestText | ConvertFrom-Json -Depth 100 -DateKind String
}
finally {
    $manifestDocument.Dispose()
}
if ([string]$manifest.schemaVersion -cne '1.0.0' -or @($manifest.sources).Count -eq 0) {
    throw 'Source-root manifest must use schemaVersion 1.0.0 and contain sources.'
}

$generatedAt = [datetimeoffset]::UtcNow
$snapshotId = 'snapshot-' + $generatedAt.ToString('yyyyMMddTHHmmssZ')
$sourceRows = [System.Collections.Generic.List[object]]::new()
$fileRows = [System.Collections.Generic.List[object]]::new()
$allExclusions = [System.Collections.Generic.List[object]]::new()
foreach ($source in @($manifest.sources)) {
    $catalog = New-SourceCorpusCatalog -SnapshotId $snapshotId -SourceId $source.sourceId -SourceKind $source.sourceKind -RootPath $source.rootPath -CapturedAt $generatedAt
    foreach ($row in $catalog.files) { $fileRows.Add($row) }
    foreach ($row in $catalog.exclusions) { $allExclusions.Add($row) }
    $rootFingerprint = Get-SourceRootFingerprint -Files $catalog.files
    $sourceRows.Add([pscustomobject][ordered]@{
        sourceId = [string]$source.sourceId
        sourceKind = [string]$source.sourceKind
        capturedAt = $generatedAt.ToString('O')
        rootFingerprint = $rootFingerprint
        sourceFileCount = $catalog.catalogedFileCount + $catalog.explicitlyExcludedFileCount
        sourceBytes = $catalog.catalogedBytes + $catalog.explicitlyExcludedBytes
    })
}
$inputFingerprint = Get-SourceInputFingerprint -Sources $sourceRows.ToArray()
$portableLedgerPath = "Extracted/Threads/$ThreadId/C1/source-corpus-ledger.json"
$ledger = [pscustomobject][ordered]@{
    schemaVersion = '1.0.0'
    snapshotId = $snapshotId
    generatedAt = $generatedAt.ToString('O')
    inputFingerprint = $inputFingerprint
    toolVersions = @([pscustomobject]@{ toolName = 'New-StellaSoraSourceCorpusSnapshot'; version = '1.0.0' })
    sources = @($sourceRows | ForEach-Object {
        [pscustomobject][ordered]@{
            sourceId = $_.sourceId
            sourceKind = $_.sourceKind
            capturedAt = $_.capturedAt
            rootFingerprint = $_.rootFingerprint
        }
    })
    files = $fileRows.ToArray()
    objects = @()
}
$summary = New-SourceCorpusSummary -Ledger $ledger -LedgerPath $portableLedgerPath -SourceTotals $sourceRows.ToArray() -Exclusions $allExclusions.ToArray()
$null = Write-SourceCorpusOutputs -OutputRoot $validatedOutput -Ledger $ledger -Summary $summary
~~~

New-SourceCorpusSummary receives no machine root path and returns only the frozen private-summary fields.

- [ ] **Step 6: Test only policy and pure writer behavior in Phase A**

Use Write-SourceCorpusOutputs below a temporary directory and validate both JSON files. Use Assert-C1OutputPathPolicy with synthetic reparse attributes to test containment. Do not invoke RefreshSnapshot against real roots and do not create repository Extracted. AST-check the real runner for the explicit switch and calls to both module functions.

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case WrongOutput
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case InvalidThreadId
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case Reparse
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
~~~

Expected: the first three cases pass by observing fail-closed refusal with zero created outputs; All reports status Passed, issueCount 0, and createdOutputCount 0.

- [ ] **Step 7: Parse runner and policy-test ASTs**

Run:

~~~powershell
foreach ($path in @(
    '.\Tools\AssetImport\SourceCorpusGate.psm1',
    '.\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1',
    '.\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1'
)) {
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $path), [ref]$tokens, [ref]$errors)
    if ($errors.Count -ne 0) { throw ($errors | Out-String) }
    $forbiddenText = @($ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -in @('Start-Process', 'Unity', 'AssetRipper', 'ffmpeg', 'vgmstream-cli')
    }, $true))
    if ($forbiddenText.Count -ne 0) { throw ($forbiddenText.Extent.Text -join [Environment]::NewLine) }
}
~~~

Expected AST error count 0 and forbidden heavy-command count 0.

- [ ] **Step 8: Run all prior C1 regressions**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 3 created Extracted.' }
~~~

Expected: all three scripts pass and the final assertion exits 0.

- [ ] **Step 9: Check scope and whitespace**

Run:

~~~powershell
git diff --check
$changed = @(git diff --name-only)
if ($changed.Count -ne 3) { throw "Expected 3 Task 3 paths, got $($changed.Count)." }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 3 created Extracted.' }
~~~

Expected: exit 0 with the three declared Task 3 paths only.

- [ ] **Step 10: Commit Task 3**

Commit:

~~~powershell
git add -- Tools/AssetImport/SourceCorpusGate.psm1 Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1 Tools/AssetImport/Test-SourceCorpusRunnerPolicy.ps1
git commit -m "feat: add guarded source snapshot runner"
~~~

**Out-of-scope assertion:** Phase A does not provide an approved real SourceRootManifestPath and therefore must not execute RefreshSnapshot.

---

### Task 4: Verify C0 Compatibility And Freeze The C2 Handoff

**Files:**

- Create: Tools/AssetImport/Test-SourceCorpusC0Compatibility.ps1
- Create: Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json

- [ ] **Step 1: Add a C0 compatibility RED test**

Generate a C1 ledger from a temp root, create a temporary copy of the C0 AssetCorpusContracts fixture directory, replace only valid-source-corpus-ledger.json, and invoke the C0 contract harness. Expect the first RED to identify any C0 schema incompatibility.

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case C0Schema
~~~

Expected RED: exit 1 because the compatibility test or handoff fixture is missing; no real roots or repository Extracted are accessed.

- [ ] **Step 2: Resolve only C1-owned incompatibilities**

Fix C1 output field names, types, paths, statuses, or additional properties. If the public schema itself is insufficient, stop and write a handoff contract-change request; do not edit docs/asset-migration/schemas.

Expected GREEN command:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case C0Schema
~~~

Expected: status Passed, c0SchemaCompatible true, childProcessCount 1 for the explicitly tested lightweight C0 harness, and heavyChildProcessCount 0.

- [ ] **Step 3: Freeze the C2 handoff fixture**

The handoff fixture contains exact-case repository-relative ledgerPath and summaryPath, snapshotId, inputFingerprint, sourceCount, fileCount, fileBytes, and objectCount 0. It contains no machine root paths.

~~~json
{
  "schemaVersion": "1.0.0",
  "ledgerPath": "Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json",
  "summaryPath": "Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json",
  "snapshotId": "snapshot-pc-install-001",
  "inputFingerprint": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "sourceCount": 1,
  "fileCount": 1,
  "fileBytes": 4096,
  "objectCount": 0
}
~~~

- [ ] **Step 4: Verify stale and path failures**

Wrong inputFingerprint, absolute path, URI path, dot-segment path, and nonzero objectCount without G2 evidence must each fail with one stable designated issue.

- [ ] **Step 5: Run handoff negative cases**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case Handoff
~~~

Expected: status Passed and each isolated negative vector produces exactly one designated issue.

- [ ] **Step 6: Run the complete Phase A C0/C1 suite**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case All
~~~

Expected: every command exits 0; compatibility may start only the lightweight C0 contract harness; no command runs RefreshSnapshot, extraction, or Unity.

- [ ] **Step 7: Parse all C1 AST and JSON files**

Run Parser.ParseFile over every Tools/AssetImport/SourceCorpusGate*.psm1 and Test-SourceCorpus*.ps1 file, then strictly parse every C0/C1 JSON with ConvertFrom-Json -Depth 100 -DateKind String and JsonDocument.Parse.

~~~powershell
$jsonIssues = 0
Get-ChildItem .\Tools\AssetImport\Fixtures\AssetCorpusContracts\*.json, .\Tools\AssetImport\Fixtures\SourceCorpusGate\*.json | ForEach-Object {
    try {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $null = $text | ConvertFrom-Json -Depth 100 -DateKind String
        $document = [System.Text.Json.JsonDocument]::Parse($text)
        $document.Dispose()
    }
    catch { $jsonIssues++ }
}
if ($jsonIssues -ne 0) { throw "$jsonIssues JSON files failed strict parsing." }
~~~

Expected: AST error count 0, JSON issue count 0, and dangerous heavy-command count 0.

- [ ] **Step 8: Check scope and side effects**

Run:

~~~powershell
git diff --check
$changed = @(git diff --name-only)
if ($changed.Count -ne 2) { throw "Expected 2 Task 4 paths, got $($changed.Count)." }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 4 created Extracted.' }
~~~

Expected: exit 0 with Test-SourceCorpusC0Compatibility.ps1 and valid-c2-source-corpus-handoff.json only.

- [ ] **Step 9: Commit Task 4**

Commit:

~~~powershell
git add -- Tools/AssetImport/Test-SourceCorpusC0Compatibility.ps1 Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json
git commit -m "test: freeze C1 to C2 corpus handoff"
~~~

**Out-of-scope assertion:** this task does not implement C2 object discovery or merge any real output.

---

### Task 5: Write The Phase B Snapshot Runbook

**Files:**

- Create: docs/asset-migration/source-corpus-phase-b-runbook.md

- [ ] **Step 1: Document the exact preconditions**

Require Phase A C0, C1, and C2 contract gates to pass; require an approved machine-local source-root manifest containing the actual PC, patch/cache, APK, and Android DATA/cache roots that are locally available; require the C1 worktree to be clean.

- [ ] **Step 2: Document the guarded command**

Use the current implementation thread identifier and canonical output:

~~~powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$sourceRootManifestPath = Read-Host 'Approved absolute path to the machine-local source-root manifest'
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
~~~

State explicitly that this command is Phase B only and is not run while writing or implementing the Phase A plan.

- [ ] **Step 3: Document stop conditions**

Stop on a missing root, changed fingerprint, access error, reparse point, path collision, conservation mismatch, schema mismatch, or any output outside the C1 artifact root. Do not continue to C2 real extraction after a stop.

- [ ] **Step 4: Document handoff evidence**

Record branch, worktree, base/head SHA, source IDs and kinds, snapshotId, inputFingerprint, per-source fingerprints, counts, bytes, exclusions, artifact root, exact command, duration, blockers, and C2 integration recommendation. Never copy machine root paths into the portable ledger or Git.

- [ ] **Step 5: Verify and commit**

Scan the runbook for accidental real machine paths beyond the canonical worktree/output path, unresolved template tokens, claims that Phase B ran, and forbidden restoration language. Run git diff --check and stage only the runbook.

Commit:

~~~powershell
git add -- docs/asset-migration/source-corpus-phase-b-runbook.md
git commit -m "docs: add source corpus phase B runbook"
~~~

**Out-of-scope assertion:** Task 5 writes instructions only; it does not run the guarded command.

---

## Task Review Protocol

For every implementation Task:

1. Use one fresh implementer subagent as the only writer in the worktree.
2. Require explicit RED evidence before production code.
3. Require the implementer to commit and self-review.
4. Run an independent specification review.
5. Only after specification approval, run an independent code-quality review.
6. Fix Critical and Important findings with the same implementer and repeat the relevant review.
7. Run fresh controller verification and stop at the Task checkpoint.

## Plan Self-Review Checklist

- The first three tasks are C1 contract, G0 fingerprints, and G1 all-file catalog in dependency order.
- Portable output follows the existing C0 schema; C1 count fields live only in the C1 private summary.
- The fingerprint byte encoding, separators, sorting, time source, and casing are unambiguous.
- Unknown, extensionless, hidden, and zero-byte files cannot disappear behind an extension filter.
- Access errors and reparse points fail closed instead of being hidden by SilentlyContinue.
- Machine absolute paths stay out of portable output and Git.
- Lightweight gates never launch the runner, extraction, or Unity.
- Phase A tests use temp roots and remove them in finally.
- C2 receives a frozen fixture interface before real integration.
- Phase B requires explicit human-provided runtime roots and RefreshSnapshot.
- No Task modifies the historical five-extension inventory, Android intake, C0 schemas, shared root gates, Unity files, or third-party assets.
