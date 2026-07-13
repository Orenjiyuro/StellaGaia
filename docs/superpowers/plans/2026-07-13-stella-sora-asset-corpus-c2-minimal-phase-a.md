# StellaSora C2 Minimal Phase A Implementation Plan

> **Status:** This plan replaces `2026-07-13-stella-sora-asset-corpus-c2-task-0-contract.md` in full. The replaced plan is historical and must not be executed.

**Goal:** Land one minimal, synthetic, read-only C2 Phase A slice that reads the approved C1 fixture and one exact-shape observation fixture, emits a public-schema-compatible synthetic object ledger plus minimal object-count coverage, and fails closed without invoking heavy operations or touching real assets.

**Architecture:** A small PowerShell module accepts already parsed in-memory objects and performs a pure in-memory conversion; it accepts no paths and performs no file-system access. A single test harness owns an audited exact-path JSON reader, strict private fixture checks, public object compatibility checks, conservation checks, fail-closed negative cases, and static/dynamic safety proof. The implementation Task starts with focused failing assertions and reaches GREEN before its single commit; no intentionally failing test crosses the Task boundary.

**Time box:** One implementation Task, 20–30 minutes. If the Task cannot reach all-green within the time box, stop without committing implementation and report the blocker; do not split RED and GREEN across Tasks.

**Plan-only boundary:** This document is the only new plan artifact. Approval and commit of this plan do not authorize C2 implementation, asset access or extraction, Unity, `Extracted/`, `Imported/`, third-party content, or Phase B.

---

## 1. Authority And Scope

The implementation reads but does not modify:

- `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json`
- the C1 ledger referenced by that handoff
- `docs/asset-migration/schemas/source-corpus-ledger.schema.json`
- `docs/asset-migration/schemas/status-vocabulary.json`

The implementation creates only:

- `Tools/AssetImport/MinimalObjectDiscoveryGate.psm1`
- `Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1`
- `Tools/AssetImport/Fixtures/DiscoveryGate/minimal-object-observations.json`
- `Tools/AssetImport/Fixtures/DiscoveryGate/valid-minimal-object-ledger.json`

The implementation must not modify the approved C1 handoff, its referenced ledger, the public schema, or vocabulary. It must not create a private `.schema.json`. The private contract is expressed only by the positive fixture and exact-key validation in the module/test.

The pre-existing untracked root `AGENTS.md` is user state. Do not edit, stage, delete, or include it in any commit. Never use `git add .`.

## 2. Minimal Central Contract

This section is the sole contract for the first implementation slice. Broader C2 design material does not enlarge this Task.

### Artifact Registry

| ID | Artifact | Role | Rule |
|---|---|---|---|
| I1 | C1 handoff fixture | input | Existing, read-only; resolves the approved C1 ledger path. |
| I2 | C1 ledger fixture | input | Existing, read-only; supplies public ledger envelope, `sources`, and `files`. |
| I3 | `minimal-object-observations.json` | private synthetic input | New; exact top-level and row key sets; no machine paths or real-asset references. |
| R1 | `source-corpus-ledger.schema.json` | public contract | Existing, read-only; must remain byte-for-byte unchanged. |
| R2 | `status-vocabulary.json` | vocabulary contract | Existing, read-only; must remain byte-for-byte unchanged. |
| O1 | in-memory candidate ledger | provisional output | Never returned when any validation issue exists. |
| O2 | `valid-minimal-object-ledger.json` | expected synthetic ledger | New golden public ledger; contains only synthetic object data. |
| O3 | terminal coverage object | minimal evidence | Exact counters only; not a diagnostic package or publication bundle. |

The harness's read allowlist contains exactly I1, the I2 path resolved from I1, I3, R1, R2, and O2. O2 is test evidence, not converter input. Every JSON read goes through one harness-owned `Read-AllowlistedJson` function that canonicalizes the requested repository path, rejects a path outside this set before opening it, and records the successful read. The converter receives the parsed values and never receives any path or reader callback.

### Private Observation Shape

`minimal-object-observations.json` has exactly these top-level keys:

```text
schemaVersion
observations
```

Each observation has exactly these keys:

```text
assetObjectId
sourceId
containerRelativePath
classId
objectType
objectName
serializedSizeBytes
dependencyObjectIds
toolName
observation
canonicalAssetId
platformVariant
configurationDisposition
evidence
```

No extra or missing key is accepted at either level. The fixture provides explicit stable identifiers; this slice defines no derived-ID or general-purpose hash system. Values must satisfy the corresponding current public object field types and vocabulary. `sourceId` and `containerRelativePath` must identify an existing C1 file row. Evidence paths are opaque strings that must remain under `Tools/AssetImport/Fixtures/DiscoveryGate/`, must not name `Extracted` or `Imported`, and are never opened by the converter.

The converter creates each public object by copying the observation fields, wrapping `toolName` and `observation` as the single `toolObservations` entry, and assigning this fixed synthetic status object:

```json
{
  "corpus": "Cataloged",
  "extraction": "ExtractedReadable",
  "semantics": "PartiallyKnown",
  "unity": "NotTested",
  "disposition": "RetainForLater"
}
```

These literals are present in the current vocabulary. The test must read R2 and reject the output if any literal ceases to be valid; do not substitute a new literal or change the vocabulary inside this Task.

### Subject/Partition Registry

The only accounting subject is one syntactically parsed observation row from I3.

```text
observationSubjectCount
= emittedObjectCount
+ rejectedObservationCount
```

- `emittedObjectCount`: observations represented exactly once in O1/O2 by unique `assetObjectId`.
- `rejectedObservationCount`: parsed observation rows rejected before publication. Because publication is atomic, any row-level failure sets `emittedObjectCount=0` and counts every parsed row as rejected; issue details still identify only the offending rows.
- The committed positive fixture must satisfy `rejectedObservationCount = 0` and therefore `observationSubjectCount = emittedObjectCount`.
- A document-level parse failure has no parsed observation rows. It reports failure separately and emits no ledger; it must not invent subjects to make the equation look balanced.

O3 has exactly:

```text
status
issueCount
observationSubjectCount
emittedObjectCount
rejectedObservationCount
childProcessCount
realAssetReadCount
createdExtractedCount
createdImportedCount
```

On positive success: `status=Passed`, `issueCount=0`, the conservation equation holds, and all four safety counters are zero.

### Failure Transition Table

| Trigger | Result | Required proof |
|---|---|---|
| Observation JSON parse error | Fail closed | No ledger object/path is returned or created. |
| Missing or extra private field | Fail closed | The offending row is identified, all parsed rows enter the rejected partition, and no ledger is returned. |
| Duplicate `assetObjectId` | Fail closed | All duplicate identities are identified, all parsed rows enter the rejected partition, and no ledger is returned. |
| C1 source/file reference mismatch | Fail closed | No ledger is returned. |
| Any generated object incompatible with the current public object schema/vocabulary | Fail closed | No ledger is returned. |
| Any conservation mismatch | Fail closed | No ledger is returned. |
| Any attempted child process, real-asset read, Unity/extraction command, or `Extracted`/`Imported` creation | Test failure | Implementation is not committed. |

Fail closed means the result contains issues and coverage but `Ledger = $null`; the module does not write a ledger file. For any parsed batch suppressed by a row-level or generated-ledger error, `emittedObjectCount=0` and every parsed row contributes exactly once to `rejectedObservationCount`. Only the test compares a successful in-memory ledger with committed O2.

## 3. Explicitly Deferred Work

These are non-blocking for this first slice and must not be implemented or pre-frozen here:

- C3–C6 dispatch;
- complete or lossless G5 projection;
- atomic five-artifact publication;
- Phase B runbook or authorization;
- canonical duplicate/variant grouping beyond copying public-required fixture values;
- diagnostic packages without a current consumer;
- standalone private schema files;
- future derived identities, hashes, manifests, registries, or extensibility fields.

Review comments outside the five blocker classes below are recorded here for later work and do not block this Task.

## 4. Review Gate For This Plan And Task

Only these findings block approval or implementation commit:

1. data can be lost, duplicated, or escape the conservation equation;
2. the emitted object/ledger can violate the current public schema or vocabulary;
3. the plan or code can authorize or invoke a heavy operation;
4. the plan or code can read or create real asset material;
5. tests cannot prove the preceding core behavior.

Everything else is Deferred Work unless it directly demonstrates one of those five failures.

---

## Task 1: Minimal Synthetic Object Ledger RED→GREEN

**Duration:** 20–30 minutes maximum.

**Files:**

- Create: `Tools/AssetImport/MinimalObjectDiscoveryGate.psm1`
- Create: `Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/minimal-object-observations.json`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/valid-minimal-object-ledger.json`
- Read only: I1, I2, R1, R2

**Acceptance:** One command finishes GREEN; the positive case emits exactly the golden public ledger and satisfies conservation with zero rejection; all four required negative classes fail closed; static and dynamic guards show no child process, real asset access, Unity/extraction, or `Extracted`/`Imported` creation; C1/public contract files are unchanged; only the four listed Task files are staged.

### Step 1 — Establish the RED assertions (3–5 minutes)

- [ ] Create the small synthetic observation fixture with at least two unique rows so duplicate/loss detection is meaningful.
- [ ] Create `Test-MinimalObjectDiscoveryGate.ps1` with assertions for:
  - positive exact ledger equality and complete candidate-ledger validation against R1 plus vocabulary validation against R2;
  - `2 = 2 + 0` conservation for the committed positive fixture;
  - parse error returns no ledger and accounts `0 = 0 + 0`;
  - missing field, extra field, duplicate identity, C1 source mismatch, C1 file mismatch, public-schema incompatibility, and public-vocabulary incompatibility each return no ledger, set `emittedObjectCount=0`, set `rejectedObservationCount` to every parsed input row, and satisfy the conservation equation;
  - duplicate issues identify every duplicate row by row index, proving none escaped the rejected partition;
  - the public-incompatibility mutation passes the private exact-key check but violates a non-enum R1 constraint (use an absolute `containerRelativePath` or negative `serializedSizeBytes`), proving R1 rather than golden equality closes the gate;
  - every JSON read uses `Read-AllowlistedJson`; the recorded successful-read set is exactly I1, resolved I2, I3, R1, R2, and O2; rooted, `..`-escaping, and unregistered repository paths are each rejected before any read occurs;
  - the module AST contains no file read/write/enumeration API, process/native execution, Unity, or extraction call; the harness AST rejects direct file-read APIs outside `Read-AllowlistedJson` and process/native execution everywhere;
  - repository snapshots show no new `Extracted` or `Imported` before/after the run.
- [ ] Run the focused test and capture the expected failure because the converter/module and golden ledger do not yet exist:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
```

Expected RED: non-zero exit for missing implementation/output only. If the test fails for syntax, fixture ambiguity, or inability to inspect safety, fix the test before proceeding.

### Step 2 — Implement the minimal pure converter (5 minutes)

- [ ] Create `MinimalObjectDiscoveryGate.psm1` with one exported conversion entry point that accepts only the five already parsed in-memory contract/input objects; it accepts no filesystem path or callback.
- [ ] In the harness, read I1/resolved I2/I3/R1/R2/O2 only through `Read-AllowlistedJson`; treat observation evidence as opaque and never open it.
- [ ] Reject unknown/missing fields, duplicates, bad C1 references, invalid public values, and conservation mismatch before exposing a ledger.
- [ ] Build the ledger entirely in memory by preserving the C1 envelope/sources/files and replacing `objects` with the converted synthetic rows.
- [ ] In the module, do not read, write, or enumerate the filesystem; invoke processes or native commands; enumerate asset directories; or create output directories/files.

### Step 3 — Freeze the positive output and reach GREEN (3–5 minutes)

- [ ] Add `valid-minimal-object-ledger.json` as the exact expected successful output.
- [ ] Validate the entire candidate ledger with PowerShell 7's `Test-Json -SchemaFile <R1> -ErrorAction Stop`, which has been checked against the existing C1 ledger, and separately check all emitted vocabulary values against R2; an exact golden-file comparison alone is not sufficient.
- [ ] Construct O3 in the harness from asserted results and the audited-reader/process/static-safety evidence. `realAssetReadCount` and `childProcessCount` must not be values self-reported by the converter.
- [ ] Re-run the focused test.

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
```

Expected GREEN terminal evidence includes:

```text
status=Passed
issueCount=0
observationSubjectCount=2
emittedObjectCount=2
rejectedObservationCount=0
childProcessCount=0
realAssetReadCount=0
createdExtractedCount=0
createdImportedCount=0
```

### Step 4 — Completion verification and narrow commit (5 minutes)

- [ ] Run the focused test once more only if files changed after the prior GREEN run.
- [ ] Verify formatting and scope:

```powershell
git diff --check
git status --short
git diff --name-only -- Tools/AssetImport
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Imported
```

Expected: `git diff --check` succeeds; only the four Task files are new; both path checks are `False`; root `AGENTS.md` remains untracked and unstaged.

- [ ] Verify protected inputs are unchanged relative to Task-start HEAD:

```powershell
git diff --exit-code HEAD -- Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json docs/asset-migration/schemas/source-corpus-ledger.schema.json docs/asset-migration/schemas/status-vocabulary.json
```

- [ ] Stage exact paths only:

```powershell
git add -- Tools/AssetImport/MinimalObjectDiscoveryGate.psm1 Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1 Tools/AssetImport/Fixtures/DiscoveryGate/minimal-object-observations.json Tools/AssetImport/Fixtures/DiscoveryGate/valid-minimal-object-ledger.json
git diff --cached --check
git diff --cached --name-only
```

- [ ] Commit only after all checks are GREEN:

```powershell
git commit -m "feat: add minimal synthetic C2 object gate"
```

**Stop checkpoint:** Report the commit, four changed files, test output, conservation counters, safety counters, and Deferred Work. Do not begin dispatch, G5, publication, canonical grouping, diagnostics, Phase B, Unity, extraction, or real-asset work.

---

## 5. Plan Completion Verification

Before committing this plan revision:

```powershell
git diff --check
git diff --name-only
git status --short
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Imported
```

The expected plan-only diff contains exactly this plan plus the superseded marker in the old plan. `AGENTS.md` remains untracked and unstaged. Both forbidden-directory checks are `False`.

Stage and commit the two plan paths explicitly; never use `git add .`:

```powershell
git add -- docs/superpowers/plans/2026-07-13-stella-sora-asset-corpus-c2-task-0-contract.md docs/superpowers/plans/2026-07-13-stella-sora-asset-corpus-c2-minimal-phase-a.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: reset C2 Phase A to minimal synthetic slice"
```

This plan commit authorizes no implementation. Stop after reporting it.
