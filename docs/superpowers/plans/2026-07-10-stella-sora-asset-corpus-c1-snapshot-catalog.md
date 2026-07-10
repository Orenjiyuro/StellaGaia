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
~~~

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

Add the exact private-summary shape above. Make ledgerInputFingerprint equal the ledger inputFingerprint. Require sourceCount to equal ledger.sources.Count; sourceId, sourceKind, and rootFingerprint to match the ledger source row exactly; catalogedFileCount to equal ledger.files.Count; and catalogedBytes to equal the sum of ledger file sizeBytes.

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

Before evaluating negative summaries, cross-check the positive ledger and summary. Stable cross-ledger issues are Source count does not match source corpus ledger., Source identity does not match source corpus ledger for '<sourceId>'., Cataloged file count does not match source corpus ledger., and Cataloged bytes do not match source corpus ledger.

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

- [ ] **Step 11: Check scope and whitespace**

Run git diff --check and git diff --name-only. Expected: Test-SourceCorpusGate.ps1 plus exactly six SourceCorpusGate JSON fixtures; Test-Path .\Extracted remains false.

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
}

function ConvertTo-PortableRelativePath {
    param([Parameter(Mandatory)][string]$RootPath, [Parameter(Mandatory)][string]$FilePath)
}

function Get-LowercaseSha256 {
    param([Parameter(Mandatory)][byte[]]$Bytes)
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

ConvertTo-PortableRelativePath accepts host separators, emits slash-separated paths, and rejects absolute, URI, empty, dot-segment, duplicate, and case-collision inputs. Exact JSON traversal enumerates PSObject.Properties and compares Name with -ceq.

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
}
~~~

Clone and sort the file records with a comparer that calls [System.StringComparer]::Ordinal.Compare on RelativePath. Append New-CanonicalFileRecordBytes output to a MemoryStream, hash stream.ToArray(), and dispose the stream in finally.

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
}
~~~

Validate sourceId uniqueness with [System.StringComparer]::Ordinal, reject NUL/CR/LF, validate the four C0 sourceKind values, sort with an ordinal sourceId comparer, encode canonical source records, and return lowercase SHA-256.

- [ ] **Step 10: Verify aggregate and full GREEN**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case Input
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
~~~

Expected: both invocations exit 0 with status Passed and issueCount 0.

- [ ] **Step 11: Parse module and test ASTs**

Parse both PowerShell files with Parser.ParseFile. Expected error count: 0.

- [ ] **Step 12: Run the Task 0 gate regression**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
~~~

Expected: Passed with positiveFixtureCount 2, negativeFixtureCount 4, and childProcessCount 0.

- [ ] **Step 13: Check scope and side effects**

Run git diff --check and git diff --name-only. Expected changed files: SourceCorpusGate.psm1 and Test-SourceCorpusSnapshotFunctions.ps1 only. Test-Path .\Extracted must be false, and the test result must report zero leftover temp roots.

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
hidden/.catalog
empty/zero.bin
~~~

Use tiny text content and a zero-byte file. Assert all six relative paths appear exactly once, including the hidden, extensionless, unknown-extension, and zero-byte files.

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
        [object[]]$Exclusions = @()
    )
}
~~~

Enumerate every regular file without extension filtering. Do not use ErrorAction SilentlyContinue. Reject a source root or child that is a reparse point, symlink, or junction. Turn access failures, duplicate normalized paths, and case collisions into structured fatal issues.

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

- [ ] **Step 7: Verify C0 status semantics**

Assert unknown and extensionless files are Cataloged, NotAttempted, Unknown, NotTested, and RetainForLater. Confirm they increase corpus counts and bytes and do not create object rows.

- [ ] **Step 8: Verify all catalog cases**

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case AllFile
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case Conservation
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case FailureModes
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
~~~

Expected: each invocation emits status Passed and issueCount 0. All reports show leftoverTempRootCount 0.

- [ ] **Step 9: Run prior C1 regressions**

Run Test-SourceCorpusSnapshotFunctions.ps1 -Case All and Test-SourceCorpusGate.ps1. Expected: both pass with no Extracted.

- [ ] **Step 10: Parse ASTs and scan dangerous commands**

Parse SourceCorpusGate.psm1 and Test-SourceCorpusCatalog.ps1. Expected AST error count 0 and command count 0 for Start-Process, pwsh, powershell, Unity, AssetRipper, and .ps1 invocation.

- [ ] **Step 11: Check scope and whitespace**

Run git diff --check and git diff --name-only. Expected changed files: SourceCorpusGate.psm1 and Test-SourceCorpusCatalog.ps1 only. Test-Path .\Extracted must be false.

- [ ] **Step 12: Commit Task 2**

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

Reject reparse points in the repository-to-output chain. Write to a sibling temporary directory, then atomically rename only after ledger and summary validation succeeds.

Compute the expected path only after ThreadId validation:

~~~powershell
$expectedOutputRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $repositoryRoot "Extracted\Threads\$ThreadId\C1")
)
$actualOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
if (-not [string]::Equals($actualOutputRoot, $expectedOutputRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputRoot must equal $expectedOutputRoot."
}
~~~

- [ ] **Step 5: Implement portable output writing**

Write source-corpus-ledger.json and source-corpus-summary.json. The ledger must conform to the C0 schema and contain no machine path. The summary uses the C1 private contract. Both share snapshotId, generatedAt, and inputFingerprint.

- [ ] **Step 6: Test only policy and pure writer behavior in Phase A**

Use the module to write outputs below a temporary directory and validate them. Do not invoke RefreshSnapshot against real roots and do not create repository Extracted. AST-check the real runner for the explicit switch and containment call.

Run:

~~~powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case WrongOutput
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case InvalidThreadId
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case Reparse
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
~~~

Expected: the first three cases pass by observing fail-closed refusal with zero created outputs; All reports status Passed, issueCount 0, and createdOutputCount 0.

- [ ] **Step 7: Parse runner and policy-test ASTs**

Expected AST error count: 0. The runner may not contain Start-Process, Unity, AssetRipper, extraction, or decoding commands.

- [ ] **Step 8: Run all prior C1 regressions**

Run Test-SourceCorpusGate.ps1, Test-SourceCorpusSnapshotFunctions.ps1 -Case All, and Test-SourceCorpusCatalog.ps1 -Case All. Expected: all pass and Test-Path .\Extracted is false.

- [ ] **Step 9: Check scope and whitespace**

Run git diff --check and git diff --name-only. Expected changed files: New-StellaSoraSourceCorpusSnapshot.ps1 and Test-SourceCorpusRunnerPolicy.ps1 only.

- [ ] **Step 10: Commit Task 3**

Commit:

~~~powershell
git add -- Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1 Tools/AssetImport/Test-SourceCorpusRunnerPolicy.ps1
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

Run the C0 asset-corpus contract harness plus all four C1 test scripts. Expected: every command exits 0; lightweight compatibility may start only the C0 contract harness; no command runs the snapshot runner, extraction, or Unity.

- [ ] **Step 7: Parse all C1 AST and JSON files**

Expected: AST error count 0, JSON parse issue count 0, and dangerous heavy-command count 0.

- [ ] **Step 8: Check scope and side effects**

Run git diff --check and git diff --name-only. Expected changed paths are Test-SourceCorpusC0Compatibility.ps1 and valid-c2-source-corpus-handoff.json only. Test-Path .\Extracted must be false.

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
