# StellaSora C2 SP-01/SP-02 Minimal File Partition Plan

**Date:** 2026-07-14
**Status:** Proposed; read-only review required before execution
**Baseline:** `codex/asset-corpus-integration` at `ec5cb9df114639de471a1b82fe8050b7affa3acf`
**Scope:** fixture-only C1 file classification and file-discovery partitioning. No real StellaSora assets, extraction, Unity, import, C3-C6, G5, SP-03-SP-09, AR-O01-AR-O05 publication, canonical work, or Phase B.

This plan contains two Tasks. That is intentional: Task 1 atomically makes AR-I08 reviewed authority available without breaking the intake gate; Task 2 implements SP-01/SP-02. Execution remains one Task per explicit authorization, and neither Task may leave an intentional RED state.

## 1. Frozen inputs and identities

### 1.1 Complete C1 file universe

AR-I02 is the sole C1 file authority. Its complete `files` array has exactly one row:

| file alias | stable subject | sourceId | relativePath | containerKind | sizeBytes | sha256 | incoming parseStatus | incoming status.extraction |
|---|---|---|---|---|---:|---|---|---|
| `fUnknown` | `(pc-install-primary, SourceCorpus/PcInstall/game-data.bundle)` | `pc-install-primary` | `SourceCorpus/PcInstall/game-data.bundle` | `UnknownInput` | 4096 | `cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc` | `NotAttempted` | `NotAttempted` |

No synthetic C1 file may be added in this slice. Subject identity is the exact `(sourceId, normalized relativePath)` pair. Duplicate identity, OrdinalIgnoreCase path collision, unsafe path, or unequal incoming `parseStatus`/`status.extraction` fails closed before partitioning.

### 1.2 SP-01 partition

The complete mapping rule is frozen:

- `DirectMedia`, `Metadata`, and `ConfigurationCandidate` are `NonContainer`.
- Every other registered `containerKind`, including `UnknownInput`, is `Container`.
- A missing, null, or empty `containerKind` is an AR-I02 schema failure under FT-02.
- Every valid nonempty value other than the three exact NonContainer values is Container. An unfamiliar nonempty value is not a failure and must not be maintained as an allowlist.

Exact positive partition:

```text
files={fUnknown}
Container={fUnknown}
NonContainer={}
catalogedFileCount=1=1+0
catalogedBytes=4096=4096+0
```

### 1.3 Exact AR-I08 positive fixture

Create `Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json` as UTF-8 without BOM, LF-only, final LF, two-space JSON indentation, and exact top-level/row key order from AR-S03. It contains exactly these Ordinal row identities:

| fileDiscoveryObservationId | toolName | toolVersion | sourceId | relativePath | outcome | evidence |
|---|---|---|---|---|---|---|
| `file-discovery-observation-sha256:195be146f0f08df54c160fbccf1c790bc1fbd535b6626976e1981344031b3e80` | `ToolA` | `1.0.0` | `pc-install-primary` | `SourceCorpus/PcInstall/game-data.bundle` | `Readable` | `[Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-file-readable.json]` |
| `file-discovery-observation-sha256:19e7158715bf0dd0807da34dddfa744b9d205a3d3e1273ea5185f217b426b5c4` | `ToolB` | `1.0.0` | `pc-install-primary` | `SourceCorpus/PcInstall/game-data.bundle` | `Readable` | `[Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-file-readable.json]` |

The fixture is exactly 1090 UTF-8 bytes and has raw SHA-256:

```text
f1733a10236714e62404660083827091a7884f6ee0b1c7342d7737f6dd84c82a
```

Evidence values are identity-only portable paths. This slice must not read, create, or require files at those evidence paths.

AR-I10 becomes a three-entry Ordinal path-sorted manifest: AR-I11, AR-I08, AR-I07. With the exact existing AR-I07/AR-I11 hashes and the AR-I08 hash above, its frozen raw SHA-256 is:

```text
4b4b65de4a2ec12dfc1cbd09929bdc66d5aa1cf8345bd161043d694b62cb2ea8
```

The ten-artifact HI-13b D9 becomes:

```text
f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab
```

The Git adapter command sequence is updated atomically to seven calls:

1. `git -C <root> rev-parse --verify HEAD^{commit}`
2. `git -C <root> cat-file blob <OID>:Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json`
3. `git -C <root> cat-file blob <OID>:Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json`
4. `git -C <root> ls-tree -z --full-tree <OID> -- Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json`
5. `git -C <root> cat-file blob <OID>:Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json`
6. `git -C <root> cat-file blob <OID>:Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json`
7. `git -C <root> rev-parse --verify HEAD^{commit}`

Calls 2, 3, 5, and 6 capture raw blob bytes. All existing environment sanitization, fixed-OID use, final HEAD revalidation, failure ownership, and actual call-count rules remain unchanged except for the frozen call numbers/counts above.

## 2. SP-02 partition and public projection

Every SP-01 file is exactly one SP-02 subject. Its observation universe is the union of accepted AR-I08 rows and implied `Readable` observations derived from accepted AR-I07 rows targeting that file.

An AR-I07 row targets a C1 file only when its exact `sourceId` and normalized `containerRelativePath` equal the C1 `(sourceId, relativePath)` identity. Unsafe paths, OrdinalIgnoreCase collisions, or a target absent from the complete C1 universe fail closed; they never create a file subject. Only accepted AR-I07 rows participate: in the frozen fixture r1-r4 are accepted, r5 is rejected, and r6 is excluded, so r5/r6 create no implied file observation.

Each accepted AR-I07 row is converted to an HI-06 record using its exact `toolName`, `toolVersion`, `sourceId`, `containerRelativePath` as `relativePath`, literal outcome `Readable`, and exact evidence set. Its original HI-03 ID is not reused as the file observation ID. The frozen implied set is:

| source row | implied HI-06 observationId | tool | outcome | evidence |
|---|---|---|---|---|
| r1 | `file-discovery-observation-sha256:7e376293c4338ca5f1c3290bcc72a4284c2834168c3e90654684e447682296af` | ToolA/1.0.0 | Readable | `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json` |
| r2 | `file-discovery-observation-sha256:b3ad54ba72e4e84b28806d843d151d38251fa3933a232f6cdeb835e9dbb5d12e` | ToolB/1.0.0 | Readable | `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r2.json` |
| r3 | `file-discovery-observation-sha256:1ea91d9700ae77e85b8e0572aff00a5dd9382366ad32c7f268aac84a8ce22000` | ToolA/1.0.0 | Readable | `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json` |
| r4 | `file-discovery-observation-sha256:7a7046aadf670dca9633baf2b2bd044e19b824601b88011ef8f258d621310aa3` | ToolB/1.0.0 | Readable | `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json` |

After combining AR-I07-implied and AR-I08-explicit records, deduplicate exact `(toolName, toolVersion, outcome, observationId)` tuples. No looser tool/outcome or evidence-based deduplication is allowed. Observation IDs and the distinct evidence union are separately sorted with `StringComparer.Ordinal`.

| accepted observations for one file | SP-02 state | public `parseStatus` | public `status.extraction` | conflict row |
|---|---|---|---|---|
| zero | `NotAttempted` | `NotAttempted` | `NotAttempted` | none |
| one or more, all `Readable`, one distinct tool | `Parsed` | `ExtractedReadable` | `ExtractedReadable` | none |
| one or more, all `Readable`, at least two distinct tools | `Parsed` | `CrossToolVerified` | `CrossToolVerified` | none |
| one or more, all `Opaque` | `Opaque` | `Opaque` | `Opaque` | none |
| one or more, all `Failed` | `Failed` | `Failed` | `Failed` | none |
| more than one distinct outcome | `FileDiscoveryConflict` | no projection | no projection | exact HI-11a/FT-06 |

For every resolved file row, `parseStatus` and `status.extraction` are written from one derived value and must be exact-equal. No caller-supplied final state or public extraction value is accepted.

### 2.1 Frozen conservation

For counts and bytes independently:

```text
catalogedFile = catalogedContainer + nonContainerFile
fileDiscoverySubject = NotAttempted + Parsed + Opaque + Failed + FileDiscoveryConflict
catalogedContainer = notAttemptedContainer + parsedContainer + opaqueContainer + failedContainer + fileDiscoveryConflictContainer
```

The positive fixture yields:

```text
file subjects: 1=0+1+0+0+0
file bytes:    4096=0+4096+0+0+0
containers:    1=0+1+0+0+0
container bytes: 4096=0+4096+0+0+0
NonContainer count/bytes: 0/0
projection: fUnknown Parsed/CrossToolVerified/CrossToolVerified
```

The focused pure matrix also freezes one-subject vectors for NotAttempted, Parsed/ExtractedReadable, Parsed/CrossToolVerified, Opaque, Failed, and FileDiscoveryConflict. Every vector must satisfy the count and byte equations; the conflict vector has one conflict subject, one FT-06 InputFailure/issue, zero resolved file rows, and zero projected public rows.

The exact premises for those vectors are:

| vector | accepted AR-I07 input | accepted AR-I08 input | expected state/projection |
|---|---|---|---|
| NotAttempted | empty | empty | NotAttempted/NotAttempted |
| Parsed single-tool | empty | exact ToolA Readable row | Parsed/ExtractedReadable |
| Parsed cross-tool | implied r1+r2 | empty | Parsed/CrossToolVerified |
| Opaque | empty | one valid ToolA Opaque row | Opaque/Opaque |
| Failed | empty | one valid ToolA Failed row | Failed/Failed |
| Conflict | implied r1 | one valid ToolA Opaque row | FileDiscoveryConflict/no projection |

The integrated positive uses implied r1-r4 plus both exact AR-I08 rows. Its exact Ordinal observation-ID set is:

```text
file-discovery-observation-sha256:195be146f0f08df54c160fbccf1c790bc1fbd535b6626976e1981344031b3e80
file-discovery-observation-sha256:19e7158715bf0dd0807da34dddfa744b9d205a3d3e1273ea5185f217b426b5c4
file-discovery-observation-sha256:1ea91d9700ae77e85b8e0572aff00a5dd9382366ad32c7f268aac84a8ce22000
file-discovery-observation-sha256:7a7046aadf670dca9633baf2b2bd044e19b824601b88011ef8f258d621310aa3
file-discovery-observation-sha256:7e376293c4338ca5f1c3290bcc72a4284c2834168c3e90654684e447682296af
file-discovery-observation-sha256:b3ad54ba72e4e84b28806d843d151d38251fa3933a232f6cdeb835e9dbb5d12e
```

Its exact evidence union is `[Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json, Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r2.json, Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json, Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json, Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-file-readable.json, Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-file-readable.json]`. The result is Parsed with `CrossToolVerified` written to both public extraction fields.

## 3. Pure model result contract

The pure SP-01/SP-02 function accepts one in-memory input object, exactly in order:

```text
snapshotId
inputFingerprint
discoveryInputFingerprint
c1Files
acceptedObjectObservations
fileDiscoveryArtifact
```

`snapshotId`, `inputFingerprint`, and `discoveryInputFingerprint` are already-audited scalar facts. `c1Files` is the complete AR-I02 `files` array with its exact C1 row shape and original order; the model independently rejects duplicate/case-colliding identities and derives its own Ordinal subject order. `acceptedObjectObservations` contains complete AR-S02 rows only after upstream AR-I07/AR-I11 validation: for the integrated vector it is exactly r1-r4, while rejected r5 and excluded r6 are absent. This boundary does not accept caller-supplied `accepted=true` flags.

`fileDiscoveryArtifact` is exactly:

```text
artifactPath
artifactSha256
documentReadStatus
document
```

`artifactPath` is the exact AR-I08 registry path; `artifactSha256` is its audited raw SHA. `documentReadStatus` is the audited parser fact `Parsed`, `Unparseable`, or `Absent`. With `Parsed`, `document` is the parsed AR-S03 candidate including its raw row order, and row validation/HI-02→HI-06 transition occurs inside the pure model. With `Unparseable`, `document` is null and the artifact-level FT-05 vector applies. For the NotAttempted and other no-AR-I08 pure vectors, use `artifactPath` as the registry path, `artifactSha256=null`, `documentReadStatus=Absent`, and `document=null`; `Absent` is permitted only for an intake-confirmed optional absence.

The function accepts no final partitions, acceptance booleans, counts, byte totals, public extraction values, filesystem paths/readers beyond the inert registered identity strings above, or process objects.

Its reusable result is exactly, in order:

```text
schemaVersion
snapshotId
inputFingerprint
discoveryInputFingerprint
fileSubjects
resolvedFileResults
fileDiscoveryConflicts
inputFailures
coverage
gateStatus
outputsSuppressed
```

`fileSubjects` has one row per C1 file in `(sourceId, relativePath)` Ordinal order and exact shape:

```text
sourceId
relativePath
containerKind
sizeBytes
sp01Partition
sp02Partition
observationIds
evidence
publicExtraction
```

`sp01Partition` is `Container` or `NonContainer`; `sp02Partition` is one of the five SP-02 states. `publicExtraction` is the derived public enum or null for conflict. `observationIds` and `evidence` are distinct Ordinal arrays.

`resolvedFileResults` uses the exact AR-S05 shape and order:

```text
sourceId
relativePath
parseStatus
observationIds
evidence
```

Here `parseStatus` is the derived public extraction enum, not the private SP-02 state. A conflict produces no resolved row.

`fileDiscoveryConflicts` uses the exact AR-S05/HI-11a shape and order:

```text
fileDiscoveryConflictId
sourceId
relativePath
observationIds
outcomes
evidence
```

`inputFailures` contains complete AR-S10 rows. `gateStatus` is `Passed` or `Failed`; `outputsSuppressed` is boolean and is true exactly when `gateStatus=Failed` in this slice.

`coverage` is exactly the following 28 unsigned integral CT-06 fields, in order; every value is derived from the actual file-subject sets and file sizes:

```text
catalogedFileCount
catalogedBytes
catalogedContainerCount
catalogedContainerBytes
nonContainerFileCount
nonContainerFileBytes
fileDiscoverySubjectCount
fileDiscoverySubjectBytes
notAttemptedFileCount
notAttemptedFileBytes
parsedFileCount
parsedFileBytes
opaqueFileCount
opaqueFileBytes
failedFileCount
failedFileBytes
fileDiscoveryConflictFileCount
fileDiscoveryConflictFileBytes
notAttemptedContainerCount
notAttemptedContainerBytes
parsedContainerCount
parsedContainerBytes
opaqueContainerCount
opaqueContainerBytes
failedContainerCount
failedContainerBytes
fileDiscoveryConflictContainerCount
fileDiscoveryConflictContainerBytes
```

The integrated positive is frozen field-by-field:

```text
schemaVersion=1.0.0
snapshotId=snapshot-pc-install-001
inputFingerprint=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
discoveryInputFingerprint=f2360d25078bfd90ca88a85ea1e801cb583841d3ef4cfbad0c8c92d2d0ba3eab
fileSubjects.count=1
fileSubjects[0].sourceId=pc-install-primary
fileSubjects[0].relativePath=SourceCorpus/PcInstall/game-data.bundle
fileSubjects[0].containerKind=UnknownInput
fileSubjects[0].sizeBytes=4096
fileSubjects[0].sp01Partition=Container
fileSubjects[0].sp02Partition=Parsed
fileSubjects[0].observationIds=<the exact six-ID Ordinal list above>
fileSubjects[0].evidence=<the exact six-path Ordinal union above>
fileSubjects[0].publicExtraction=CrossToolVerified
resolvedFileResults.count=1
resolvedFileResults[0].sourceId=pc-install-primary
resolvedFileResults[0].relativePath=SourceCorpus/PcInstall/game-data.bundle
resolvedFileResults[0].parseStatus=CrossToolVerified
resolvedFileResults[0].observationIds=<the same exact six-ID list>
resolvedFileResults[0].evidence=<the same exact six-path union>
fileDiscoveryConflicts=[]
inputFailures=[]
gateStatus=Passed
outputsSuppressed=false
```

Its exact `coverage` values, in the field order frozen above, are:

```text
catalogedFileCount=1
catalogedBytes=4096
catalogedContainerCount=1
catalogedContainerBytes=4096
nonContainerFileCount=0
nonContainerFileBytes=0
fileDiscoverySubjectCount=1
fileDiscoverySubjectBytes=4096
notAttemptedFileCount=0
notAttemptedFileBytes=0
parsedFileCount=1
parsedFileBytes=4096
opaqueFileCount=0
opaqueFileBytes=0
failedFileCount=0
failedFileBytes=0
fileDiscoveryConflictFileCount=0
fileDiscoveryConflictFileBytes=0
notAttemptedContainerCount=0
notAttemptedContainerBytes=0
parsedContainerCount=1
parsedContainerBytes=4096
opaqueContainerCount=0
opaqueContainerBytes=0
failedContainerCount=0
failedContainerBytes=0
fileDiscoveryConflictContainerCount=0
fileDiscoveryConflictContainerBytes=0
```

`resolvedFileResults` and `fileDiscoveryConflicts` are passed unchanged as the SP-01/SP-02 fragment of future AR-P01. Future AR-O01 clones the exact C1 file row and changes only `parseStatus` and `status.extraction` to the single `resolvedFileResults.parseStatus`; no alternate private object or test-only projection is permitted. This slice does not persist AR-P01 or AR-O01.

## 4. Fail-closed and suppression contract

The following are direct failures, never warnings or inferred defaults:

- invalid/missing/duplicate/case-colliding C1 subject or missing/null/empty `containerKind`: FT-02 on AR-I02; an unfamiliar nonempty kind remains Container;
- unsafe C1 or AR-I08 portable path: FT-04 on the exact artifact/row subject;
- invalid AR-I08 row shape, outcome, HI-06, empty evidence, duplicate observation ID, or unknown C1 target: FT-05 on the HI-02 fallback row identity;
- unequal incoming or projected `parseStatus` and `status.extraction`: FT-02 on the exact file subject;
- multiple distinct outcomes for one subject: one HI-11a FileDiscoveryConflict owned by FT-06.

Any direct failure sets gate status `Failed`, suppresses `discoveryInputFingerprint`, suppresses every AR-O01-AR-O04/public file projection, and leaves downstream authorization empty. Independent evaluable subjects still complete, but a conflict never also produces a resolved file row. Counts and failure rows derive from actual sets; fixed fallback totals are forbidden.

### 4.1 HI-02 fallback and unique ownership

HI-02 is exact SHA-256 framing with prefix `raw-row-sha256:` and domain line `C2RawRowV1`. Its complete scalar field order is `artifactPath`, `artifactSha256`, `rowIndex`; `rowIndex` is the zero-based decimal index and HI-02 exists only after a rows array and index exist.

For the frozen AR-I08 raw SHA and row index 0, the exact framed bytes are 197 UTF-8 bytes and the vector is:

```text
raw-row-sha256:10f281f84d8fdd9bec32a4854bfe7c2d1a1316c655fdcc63bb2f1346c1d2e39c
```

Row-level FT-04 is one AR-S10 `inputFailures` row with `subjectKind=FileDiscoveryObservation`, the HI-02 `subjectId`, `reasonCode=UnsafePath`, `attribution=FT-04:<HI-02>`, and evidence exactly `[Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json]`; the unsafe value itself is never persisted into CT-07 evidence. Row-level FT-05 uses the same subject kind/HI-02 identity, `reasonCode=InvalidObservation`, `attribution=FT-05:<HI-02>`, and the same exact evidence array.

If JSON parsing fails or top-level/rows shape prevents a stable row index, there is no HI-02 subject. Exactly one document-level FT-05 row replaces AR-I08's Accepted artifact state: `subjectKind=ObservationDocument`, `subjectId=AR-I08`, `reasonCode=InvalidObservation`, `attribution=FT-05:AR-I08`, evidence exactly the AR-I08 registry path. Document and row ownership are mutually exclusive; one malformed input is never counted as both an artifact failure and a raw-row failure.

## 5. Task 1 — Materialize AR-I08 Authority And Intake Binding (20-30 minutes)

**Files, exact scope:**

- create `Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json`;
- modify `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json`;
- modify `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`;
- modify `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`.

No other fixture, contract, schema, vocabulary, doc, or gate may change.

### Steps

1. **RED: exact fixture/hash vector (2-5 min).** Add `-Case FileFixtureIntake`; assert the frozen HI-06 IDs, raw AR-I08/AR-I10 hashes, D9, registry presence, and seven-call trace before materialization.
2. **Materialize fixture authority (2-5 min).** Create exact AR-I08 and update AR-I10 only as frozen above.
3. **Update audited intake/Git sequence (2-5 min).** Read AR-I08 only through the fixed-OID blob and audited worktree reader; keep AR-I09 absent; bind AR-I08 worktree/blob/manifest SHA.
4. **Update O1/O2 derivation (2-5 min).** Positive intake has 10 read artifacts, one absent optional, seven Git calls, stable HEAD, exact D9; all counts derive from states/events.
5. **Failure vectors (2-5 min).** Freeze call 3, call 4, manifest-binding, AR-I08 shape, and final-call failures with exact owner, nullable OIDs/headStable, actual call count, artifact states, and fingerprint suppression.
6. **GREEN and checkpoint (2-5 min).** Run focused command and exact cached-scope checks.

**Focused command:**

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case FileFixtureIntake
```

**Required regression:** all existing `Pure`, `GitAdapter`, `FailureState`, `ValidatorMutations`, and `Integration` cases plus `Test-MinimalObjectDiscoveryGate.ps1`.

**Acceptance:** exact two fixture hashes and D9; exactly seven Git calls/four raw blobs; AR-I08 Accepted, AR-I09 Absent/NotRead; zero real-asset reads/heavy processes/created forbidden paths; cached scope exactly four files.

**Stop checkpoint:** commit Task 1 independently and stop. Do not implement SP-01/SP-02 until separately authorized.

## 6. Task 2 — Pure SP-01/SP-02 And Integrated Projection (20-30 minutes)

**Files, exact scope:**

- modify `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`;
- modify `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`.

No fixture or document changes are allowed in Task 2.

### Steps

1. **RED: complete C1 universe/SP-01 (2-5 min).** Add `-Case FilePartitions`; inject the exact AR-I02 file array and assert subject identity, arbitrary-nonempty-kind classification, Container/NonContainer sets, and count/byte conservation.
2. **Implement pure SP-01 (2-5 min).** Accept parsed in-memory rows only; reject caller-supplied totals/final partitions; use Ordinal identity/path rules.
3. **RED: six SP-02 vectors (2-5 min).** Freeze each vector's exact accepted AR-I07/AR-I08 premises, NotAttempted, both Parsed projections, Opaque, Failed, and FileDiscoveryConflict with exact rows/counts/bytes.
4. **Implement pure SP-02 and HI-11a (2-5 min).** Derive AR-I07 implied HI-06 rows, exact four-tuple deduplication, outcomes, Ordinal observation/evidence sets, conflicts, and public extraction from accepted facts.
5. **Projection/fail-closed vectors (2-5 min).** Assert complete result/row/coverage shape, dual-field equality, unknown target, duplicate/case collision, HI-02 row fallback, document-level AR-I08 ownership, FT-06 single ownership, and zero public output on every failure.
6. **Integrate and GREEN (2-5 min).** Feed the already-audited AR-I02/AR-I08 parsed values into the pure model; do not add filesystem/process entry points or change O1/O2 top-level shape.

**Focused command:**

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case FilePartitions
```

**Required regression:** all six intake focused cases including `FileFixtureIntake`, followed by:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
```

**Acceptance:** exact C1 universe; arbitrary nonempty kind maps Container; all SP-01/SP-02 count and byte equations; six state/projection vectors with frozen AR-I07/08 premises; integrated six-ID/evidence union projects `CrossToolVerified` to both public fields; exact pure result/AR-S05/coverage shapes; HI-02 and document ownership vectors; all failures suppress outputs; module/harness AST safety counts zero; cached scope exactly two scripts.

**Stop checkpoint:** commit Task 2 independently and stop. SP-03+, output publication, Unity, extraction, real assets, C3-C6, G5, and Phase B remain unauthorized.

## 7. Common completion checks

Run only after the authorized Task is GREEN:

```powershell
git diff --check
git status --short
git diff --name-only
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

Stage only the Task's exact file list; never use `git add .`. `AGENTS.md` remains untracked and unstaged. Both forbidden paths must remain `False`. Submit the resulting commit for read-only review and do not begin the next Task without new confirmation.
