# StellaSora Asset Corpus C0 Contracts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze versioned, machine-readable contracts for the source corpus ledger, authoring reuse ledger, orthogonal status vocabulary, and lightweight G5 root summary without running extraction or Unity.

**Architecture:** JSON Schema Draft 2020-12 documents are the public, language-neutral contract under `docs/asset-migration/schemas`. A dependency-free PowerShell contract test reads those schemas and checked-in fixtures, validates required fields, vocabulary linkage, and count conservation, and returns a structured summary. Contract tests must only read repository files; they must not create `Extracted`, start child processes, or invoke Unity.

**Tech Stack:** JSON Schema Draft 2020-12, JSON fixtures, PowerShell 7, Git.

---

## File ownership

C0 exclusively owns these shared paths:

- `docs/asset-migration/schemas/**`
- `Tools/AssetImport/Fixtures/AssetCorpusContracts/**`
- `Tools/AssetImport/Test-AssetCorpusContract.ps1`
- this plan

C1-C6 may consume these files but must submit contract-change requests to C0 instead of modifying them directly.

## Contract names and exact vocabularies

Use schema version `1.0.0` and JSON Schema dialect `https://json-schema.org/draft/2020-12/schema`.

The vocabulary document must expose these exact arrays:

```text
corpus: Cataloged, Missing, StaleInput
extraction: NotAttempted, ExtractedReadable, CrossToolVerified, Opaque, Failed
semantics: Known, PartiallyKnown, Unknown
configurationDisposition: Parsed, DiscoveredOpaque, Encrypted, RequiresRuntimeType, LikelyServerDependent, NotConfiguration
unity: NotTested, StaticQualified, RepresentativeValidated, Rejected, UnityExecutionUnavailable
disposition: NeedsDiagnosis, UseOriginalAsset, RepairOnce, PrototypeReplacement, RetainForLater, DiagnosticOnly, Stop
familyStaticOutcome: StaticQualified, StaticRejected, NeedsDiagnosis
sourceKind: PcInstall, PcPatchOrCache, AndroidApk, AndroidDataOrCache
```

The public root summary must expose four independent conclusions and must not expose `OriginalUnityProjectRestored`:

```text
corpusSnapshotComplete
structuredObjectCoverage
originalAssetBatchCoverage
stellaSora2AuthoringReady
```

---

### Task 0: Add the lightweight contract harness and vocabulary

**Files:**

- Create: `Tools/AssetImport/Test-AssetCorpusContract.ps1`
- Create: `docs/asset-migration/schemas/status-vocabulary.json`
- Include: `docs/superpowers/plans/2026-07-10-stella-sora-asset-corpus-c0-contracts.md`

- [ ] **Step 1: Write a vocabulary-only failing contract test**

Create `Test-AssetCorpusContract.ps1` with reusable issue collection and JSON loading helpers. For this increment it must accept an optional `ContractRoot`, require and parse `status-vocabulary.json`, verify `schemaVersion=1.0.0`, verify every exact vocabulary array in **Contract names and exact vocabularies**, reject the two forbidden restoration property names, and emit `status`, `issueCount`, `issues`, `schemaCount=0`, `fixtureCount=0`, `childProcessCount=0`, and `durationMs`.

- [ ] **Step 2: Run the test and verify RED**

Run `pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1` before creating the vocabulary.

Expected: non-zero exit with `Missing contract file:` for `docs\asset-migration\schemas\status-vocabulary.json`, not a syntax or parameter-binding error.

- [ ] **Step 3: Add the exact vocabulary document**

Create `status-vocabulary.json` with schema version `1.0.0`, an ISO-8601 `generatedAt`, and the eight exact arrays in **Contract names and exact vocabularies**. Add no legacy single-ladder statuses.

- [ ] **Step 4: Run the test and verify GREEN**

Expected: `status=Passed`, `issueCount=0`, `schemaCount=0`, `fixtureCount=0`, `childProcessCount=0`, under five seconds, and no `Extracted` directory.

- [ ] **Step 5: Run static checks and commit**

Parse the PowerShell AST, parse the vocabulary JSON, run `git diff --check`, stage only the three Task 0 paths, and commit with `test: add asset corpus contract harness`.

---

### Task 1: Freeze v1 schemas and positive fixtures

**Files:**

- Modify: `Tools/AssetImport/Test-AssetCorpusContract.ps1`
- Create: `docs/asset-migration/schemas/source-corpus-ledger.schema.json`
- Create: `docs/asset-migration/schemas/authoring-reuse-ledger.schema.json`
- Create: `docs/asset-migration/schemas/root-gate-summary.schema.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-source-corpus-ledger.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-authoring-reuse-ledger.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-root-gate-summary.json`

- [ ] **Step 1: Extend the contract test before adding schemas or fixtures**

Extend `Tools/AssetImport/Test-AssetCorpusContract.ps1` so it additionally:

1. Accept an optional `FixtureRoot` parameter in addition to the existing `ContractRoot`.
2. Require all three schemas and all three valid fixtures.
3. Parse every JSON file with `ConvertFrom-Json -Depth 100`.
4. Require each schema to declare Draft 2020-12, `$id`, `title`, `type=object`, a non-empty `required` array, and `additionalProperties=false` at the document root.
5. Require each fixture's `schemaVersion` to equal `1.0.0` and each fixture to contain every root property named by its schema's `required` array.
6. Require all status values in fixtures to belong to the checked-in vocabulary.
7. Reject any root schema or fixture property named `OriginalUnityProjectRestored` or `originalUnityProjectRestored`.
8. Inspect its own process ID and report `childProcessCount=0`; it must not call another `.ps1`, `Start-Process`, Unity, or extraction tools.
9. Return one object with `status`, `issueCount`, `issues`, `schemaCount`, `fixtureCount`, `childProcessCount`, and `durationMs`.
10. Throw after emitting JSON when `issueCount` is non-zero; otherwise emit the object.

Use these stable issue messages so later tests can assert them:

```text
Missing contract file: <path>
Invalid JSON contract file: <path>
Schema '<name>' does not declare JSON Schema Draft 2020-12.
Schema '<name>' has no required properties.
Fixture '<name>' is missing required property '<property>'.
Fixture '<name>' uses unsupported <dimension> status '<value>'.
Forbidden original project restoration property found in '<name>'.
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1
```

Expected: non-zero exit with `Missing contract file:` for `docs\asset-migration\schemas\source-corpus-ledger.schema.json`. The failure must be caused by absent schemas, not a parser error.

- [ ] **Step 3: Add the three schemas**

Create the three schemas with these exact root requirements:

```text
source-corpus-ledger:
  schemaVersion, snapshotId, generatedAt, inputFingerprint, toolVersions, sources, files, objects

authoring-reuse-ledger:
  schemaVersion, generatedAt, inputFingerprint, toolVersions, families

root-gate-summary:
  schemaVersion, generatedAt, inputFingerprint, toolVersions,
  directGateSummaries, directGateReports,
  corpusSnapshotComplete, structuredObjectCoverage,
  originalAssetBatchCoverage, stellaSora2AuthoringReady
```

The source ledger schema must define:

```text
source: sourceId, sourceKind, capturedAt, rootFingerprint
file: snapshotId, sourceId, sourceKind, relativePath, sizeBytes, sha256, capturedAt,
      containerKind, parseStatus, disposition, evidence, status
object: assetObjectId, sourceId, containerRelativePath, classId, objectType, objectName,
        serializedSizeBytes, dependencyObjectIds, toolObservations, canonicalAssetId,
        platformVariant, configurationDisposition, evidence, status
status: corpus, extraction, semantics, unity, disposition
```

The authoring ledger schema must define each family with all design-required fields:

```text
familyId, category, memberSelector, memberCount, staticPassedCount, staticFailedCount,
uncheckedCount, representativeAssetIds, representativeSelectionReason, unityEvidence,
residualIssues, failureAttribution, decision, nextAllowedAction, generatedAt,
inputFingerprint, toolVersions, directGateSummary, directGateReport, staticOutcome
```

The root schema must model:

```text
corpusSnapshotComplete: value, catalogedFileCount, sourceFileCount, catalogedBytes, sourceBytes
structuredObjectCoverage: parsedContainerCount, parsedContainerBytes,
  opaqueOrFailedContainerCount, opaqueOrFailedContainerBytes,
  enumeratedObjectCount, classifiedObjectCount, unclassifiedObjectCount,
  configurationCandidateCount, configurationParsedCount
originalAssetBatchCoverage: reusableFamilyCount, totalFamilyCount, reusableMemberCount,
  totalMemberCount, reusableBytes, totalBytes
stellaSora2AuthoringReady: value, requiredCapabilities, satisfiedCapabilities,
  isolatedFailedMemberCount
```

Every object schema must use `additionalProperties=false`. Counts and byte totals are non-negative integers. SHA-256/fingerprint strings use lowercase 64-hex patterns. Timestamps use `format: date-time`.

- [ ] **Step 4: Add minimal positive fixtures**

The source fixture must contain:

- one `PcInstall` source;
- one cataloged opaque file with a valid 64-hex hash;
- one Unity object linked to that file;
- orthogonal status dimensions using only approved vocabulary;
- source/file/object counts that can be conserved.

The authoring fixture must contain one family with:

```text
memberCount=2
staticPassedCount=1
staticFailedCount=1
uncheckedCount=0
decision=NeedsDiagnosis
staticOutcome=NeedsDiagnosis
```

The root fixture must keep conclusions independent:

```text
corpusSnapshotComplete.value=true
structuredObjectCoverage.unclassifiedObjectCount=1
originalAssetBatchCoverage.reusableMemberCount=1
originalAssetBatchCoverage.totalMemberCount=2
stellaSora2AuthoringReady.value=false
```

Use repository-relative evidence paths only. Do not create evidence files merely to satisfy a path.

- [ ] **Step 5: Run the test and verify GREEN**

Run:

```powershell
$result = pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1 | ConvertFrom-Json
$result | Format-List
```

Expected:

```text
status            : Passed
issueCount        : 0
schemaCount       : 3
fixtureCount      : 3
childProcessCount : 0
```

The command should finish in under five seconds and must not create `Extracted`.

- [ ] **Step 6: Run static checks and commit**

Run:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  (Resolve-Path .\Tools\AssetImport\Test-AssetCorpusContract.ps1),
  [ref]$tokens,
  [ref]$errors
) | Out-Null
if ($errors.Count -ne 0) { throw ($errors | Out-String) }
Get-ChildItem .\docs\asset-migration\schemas\*.json,
  .\Tools\AssetImport\Fixtures\AssetCorpusContracts\*.json |
  ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json -Depth 100 | Out-Null }
git diff --check
```

Then stage only the Task 1 files and commit:

```powershell
git add -- Tools/AssetImport/Test-AssetCorpusContract.ps1 `
  docs/asset-migration/schemas/source-corpus-ledger.schema.json `
  docs/asset-migration/schemas/authoring-reuse-ledger.schema.json `
  docs/asset-migration/schemas/root-gate-summary.schema.json `
  Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-source-corpus-ledger.json `
  Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-authoring-reuse-ledger.json `
  Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-root-gate-summary.json
git commit -m "feat: freeze asset corpus contract schemas"
```

---

### Task 2: Add negative fixtures and conservation assertions

**Files:**

- Modify: `Tools/AssetImport/Test-AssetCorpusContract.ps1`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/invalid-source-file-conservation.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/invalid-family-conservation.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/invalid-repair-once-attribution.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/invalid-stale-fingerprint.json`
- Create: `Tools/AssetImport/Fixtures/AssetCorpusContracts/invalid-original-project-restored.json`

- [ ] **Step 1: Add failing assertions before adding fixtures**

Extend the test so the five named invalid fixtures are mandatory and each must produce its designated issue. Run it before creating them.

Expected RED: `Missing contract file:` for `invalid-source-file-conservation.json`.

- [ ] **Step 2: Add the five invalid fixtures**

Each fixture changes exactly one rule:

```text
invalid-source-file-conservation:
  sourceFileCount != catalogedFileCount + explicitlyExcludedFileCount

invalid-family-conservation:
  memberCount != staticPassedCount + staticFailedCount + uncheckedCount

invalid-repair-once-attribution:
  decision=RepairOnce with empty failureAttribution

invalid-stale-fingerprint:
  downstream inputFingerprint differs from the fixture's direct child fingerprint

invalid-original-project-restored:
  adds originalUnityProjectRestored=true to a root summary
```

- [ ] **Step 3: Implement minimal negative validation**

The test must require these stable issue messages:

```text
Source file conservation failed.
Asset family member conservation failed for '<familyId>'.
RepairOnce requires non-empty failureAttribution for '<familyId>'.
Downstream summary input fingerprint is stale.
Forbidden original project restoration property found in '<name>'.
```

The valid fixtures must remain green. Negative fixtures pass only when the expected issue is detected; unexpected issues fail the test.

- [ ] **Step 4: Verify GREEN and no heavy side effects**

Run the Task 1 GREEN command again. Expected additions:

```text
negativeFixtureCount : 5
childProcessCount    : 0
```

Assert `Test-Path .\Extracted` remains false inside this clean worktree.

- [ ] **Step 5: Commit Task 2**

Run static checks, `git diff --check`, stage only the six Task 2 files, and commit:

```powershell
git commit -m "test: enforce asset corpus contract failures"
```

---

## Self-review checklist

- The plan covers the two ledgers, orthogonal status dimensions, four independent root conclusions, fixture-based contract tests, count conservation, failure attribution, fingerprint freshness, and the forbidden restoration claim.
- No step invokes extraction, Unity, AssetRipper, Wwise decoding, or source snapshot refresh.
- No step writes under the StellaSora source install.
- Every implementation step is fully specified and contains an observable verification result.
- Task 1 and Task 2 are independently testable and independently revertible.
