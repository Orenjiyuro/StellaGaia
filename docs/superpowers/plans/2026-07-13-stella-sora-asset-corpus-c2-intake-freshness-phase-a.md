# StellaSora C2 Phase A Intake And Freshness Plan

> **Status:** APPROVED AS AMENDED. Task 1 completed and passed independent review at commit `b635059689d7a7b67ed715e8fcdf2cf8267d7664`. The former oversized Task 2 is replaced by Tasks 2A, 2B, and 2C below. Each requires separate explicit authorization. Unity, extraction, import, real assets, C3-C6, G5, and Phase B remain unauthorized.

**Goal:** Define the smallest fixture-only C2 slice that can later prove AR-I01–I11 intake and freshness against one frozen Git commit, recompute HI-13b, and fail closed without touching real assets.

**Selected sequence:** Intake/freshness precedes SP-01/SP-02. Task 1 froze the reviewed fixture authority. Task 2A adds a pure in-memory model, Task 2B adds the audited Git adapter, and Task 2C integrates fixture reads plus the complete O1/O2 and failure matrix. No Task may leave an intentional RED state for a later Task.

**Task containment rule:** This plan contains four sequential Tasks so their dependency, file boundaries, verification, and stop checkpoints can be reviewed together. Task 1 is complete. Containment does not authorize combined execution: the default remains exactly one explicitly approved Task per round. Tasks 2A, 2B, and 2C are separately reviewable, separately GREEN, and separately reversible commits.

---

## 1. Scope And Authority

Authority order is repository `AGENTS.md`, the 2026-07-10 corpus design, C0 contracts, C1 fixtures, the amended 2026-07-12 C2 discovery spec, then this narrowed plan.

This slice covers only:

- AR-I01–I11 registry presence and safe-path intake;
- required-byte and frozen-commit optional-byte freshness;
- AR-I10 completeness and AR-I11 shape/identity/fingerprint binding;
- HI-13a/HI-13b;
- FT-01, artifact-level FT-02/04, FT-03, FT-13, and FT-15;
- all five registered check subjects, with Conservation and PublicProjection explicitly NotEvaluated.

It excludes SP-01–SP-07, raw-row partition execution, FT-14 execution, AR-O01–AR-O05 publication, C3–C6, G5, canonical expansion, Phase B, real assets, Unity, extraction, import, `Extracted`, and `Assets/StellaGaia/Imported`.

The existing minimal object-gate commit and its four files remain untouched. Root `AGENTS.md` remains untracked user state.

---

## 2. Narrow Artifact Registry

This table is the sole artifact definition for the slice. Artifact stable identity is exact registry ID plus exact portable path. A present single-file content fingerprint is lowercase SHA-256 over exact raw bytes. No artifact is persisted by this slice.

| ID | Exact path | Requirement | Positive presence | Input/output and failure rule |
|---|---|---|---|---|
| AR-I01 | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json` | Required | Present/read | Exact registered SHA and AR-S01; FT-01/03 |
| AR-I02 | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json` | Required | Present/read | Resolved exactly from AR-I01; exact registered SHA; FT-01/03 |
| AR-I03 | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json` | Required | Present/read | Resolved exactly from AR-I01; exact registered SHA; FT-01/03 |
| AR-I04 | `docs/asset-migration/schemas/source-corpus-ledger.schema.json` | Required | Present/read | Exact registered SHA; FT-03 |
| AR-I05 | `docs/asset-migration/schemas/status-vocabulary.json` | Required | Present/read | Exact registered SHA; FT-03 |
| AR-I06 | `docs/asset-migration/schemas/root-gate-summary.schema.json` | Required | Present/read | Exact registered SHA; FT-03 |
| AR-I07 | `Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json` | Conditional | Present/read | Exact frozen-commit blob and worktree equality; AR-I10 entry; FT-03 |
| AR-I08 | `Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json` | Conditional | Absent/not read | Must be absent in worktree, frozen commit, and AR-I10 |
| AR-I09 | `Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json` | Conditional | Absent/not read | Must be absent in worktree, frozen commit, and AR-I10 |
| AR-I10 | `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json` | Conditional authority | Present/read | Exact frozen-commit blob and worktree equality; exact AR-S04a; never lists itself; FT-02/03 |
| AR-I11 | `Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json` | Conditional approval | Present/read | Exact frozen-commit blob and worktree equality; AR-I10 entry; exact AR-S04b/HI-15 and AR-I07 binding; FT-02/03 |
| O1 | Memory only | Diagnostic result | Constructed | Exact NAR-S01 below; fingerprint suppressed on any direct failure |
| O2 | Terminal only | Focused coverage | Constructed | Exact NAR-S02 below; never written to a repository path |

Positive registry vector:

```text
registered=11
present/read={AR-I01..AR-I07,AR-I10,AR-I11}=9
absent/not-read={AR-I08,AR-I09}=2
11=9+2+0 failed registry slots
```

---

## 3. Subject/Partition Registry

No unregistered subject or counter is allowed.

| ID | Universe and stable identity | Exclusive partitions | Conservation | Positive result |
|---|---|---|---|---|
| NP-01 Registry slots | all 11 AR-I identities | PresentRead, AbsentOptional, FailedSlot | `registeredArtifactCount = readArtifactCount + absentOptionalArtifactCount + failedRegistrySlotCount` | `11=9+2+0` |
| NP-02 Read artifact subjects | every PresentRead artifact, identity exact AR-I ID | AcceptedArtifact, FailedArtifact | `readArtifactCount = acceptedArtifactCount + failedArtifactCount` | `9=9+0` |
| NP-03 Contract checks | exactly the five fixed `C2Check:*` identities | AcceptedCheck, FailedCheck, NotEvaluatedCheck | `contractCheckCount = acceptedCheckCount + failedCheckCount + notEvaluatedCheckCount` | `5=3+0+2` |
| NP-04 Input-accounting subjects | NP-02 subjects plus NP-03 subjects | Accepted, InputFailure, InputExclusion, NotEvaluated | `inputSubjectCount = acceptedInputSubjectCount + inputFailureCount + excludedInputSubjectCount + notEvaluatedInputSubjectCount` | `14=12+0+0+2` |
| NP-05 Issues | direct FT-01/02/03/04/13 rows only | Issue | `issueCount = inputFailureCount`; FT-15 suppressions are not issues | `0=0` |

The five checks and positive states are exact:

| Check subject | Positive state | Positive reason |
|---|---|---|
| `C2Check:LightweightPolicy` | Accepted | complete AST/runtime audit; only exact Git adapter calls; no heavy operation or real-asset path |
| `C2Check:C1Handoff` | Accepted | AR-I01 exact shape/identity and exact AR-I02/03 paths |
| `C2Check:Freshness` | Accepted | required SHA, frozen-commit optional blobs, AR-I10/11 bindings, HI-13b, and stable HEAD all pass |
| `C2Check:Conservation` | NotEvaluated | SP-01–SP-09 are outside this slice; one FT-15 suppression, zero issues |
| `C2Check:PublicProjection` | NotEvaluated | AR-O01–AR-O05 are outside this slice; one FT-15 suppression, zero issues |

There are exactly five check rows in O1 in the displayed order. A failure changes only its direct owning subject; it never invents a sixth check. If FT-01 removes a Freshness prerequisite, Freshness is NotEvaluated under FT-15 rather than failed again.

AR-I11 approval rows are validated artifacts in this slice, not observation-accounting subjects. FT-14 and the r6 InputExclusion partition are deferred until raw-row partition execution. This prevents the intake slice from claiming that exclusion semantics have already run.

---

## 4. Failure Transition Table

Evaluation order is fixed: LightweightPolicy → C1Handoff → portable paths → required/commit freshness → AR-I10/11 shape and binding → HI-13b → end-HEAD stability → deferred-check suppressions.

| Owner | Trigger | Accounting/result | Fingerprint/result vector | Next action |
|---|---|---|---|---|
| FT-13 `C2Check:LightweightPolicy` | dynamic command, non-adapter process, forbidden Git grammar/environment, filesystem API outside audited readers, real-root/Unity/extraction/import attempt | one InputFailure + issue | O1 diagnostic returned; fingerprint null; O2 Failed | Remove unsafe operation |
| FT-01 `C2Check:C1Handoff` | AR-I01 shape, identity, or AR-I02/03 path mismatch | one InputFailure + issue; dependent Freshness FT-15 | fingerprint null | Fix C1 handoff fixture |
| FT-04 exact offending artifact | rooted, URI, escaping, dot-segment, unregistered, or case-colliding path | artifact becomes FailedArtifact; one InputFailure + issue | fingerprint null | Fix portable path |
| FT-03 `C2Check:Freshness` | required SHA mismatch; optional worktree/commit/manifest mismatch; unexpected presence/absence; start/end OID mismatch | one InputFailure + issue regardless of mismatch count | fingerprint null | Restore reviewed frozen-commit bytes and stable HEAD |
| FT-02 AR-I10 | manifest shape, identity, key set, ordering, completeness, or duplicate invalid | AR-I10 FailedArtifact; one InputFailure + issue; Freshness FT-15 because its authority prerequisite is unavailable | fingerprint null | Fix reviewed manifest |
| FT-02 AR-I11 | approval document/row shape, HI-15, AR-I07 binding, duplicate subject, or invalid approved HI-03 | AR-I11 FailedArtifact; one InputFailure + issue; Freshness FT-15; never FT-14 | fingerprint null | Fix reviewed approval artifact |
| FT-15 `C2Check:Freshness` | FT-01 prerequisite unavailable | one NotEvaluated suppression, no issue | fingerprint null because FT-01 already failed | Fix FT-01 owner |
| FT-15 `C2Check:Conservation` | SP partitions deliberately outside slice | one NotEvaluated suppression, no issue | does not change intake Passed status | Implement separately approved SP slice |
| FT-15 `C2Check:PublicProjection` | publication deliberately outside slice | one NotEvaluated suppression, no issue | does not change intake Passed status | Implement separately approved publication slice |

Multiple freshness mismatches remain one direct FT-03 check failure with distinct Ordinal-sorted evidence paths. Artifact FT-02/04 and check FT-03 must not double-own the same predicate: path safety owns before freshness; exact shape owns before semantic binding; freshness owns byte/OID mismatch.

---

## 5. Complete In-Memory And Terminal Shapes

### NAR-S01 O1 in-memory intake result

Top level is exactly, in order:

```text
schemaVersion
snapshotId
startCommitOid
endCommitOid
headStable
discoveryInputFingerprint
artifactStates
contractChecks
inputFailures
inputExclusions
inputSuppressions
decision
```

- `schemaVersion` is exactly `1.0.0`.
- `snapshotId` equals accepted AR-I01; on pre-identity FT-01 it is null.
- commit OIDs are nullable lowercase 40-hex for this repository. `startCommitOid` is null exactly when call 1 does not return one valid OID. `endCommitOid` is null exactly when the final HEAD revalidation is not launched or does not return one valid OID.
- `headStable` is nullable boolean: null unless both OIDs are non-null, true when they are exact-equal, and false when both are valid but differ.
- `discoveryInputFingerprint` is nullable lowercase-64-hex; non-null only with zero direct failures and Accepted Freshness.
- `artifactStates` has exactly 11 rows in AR-I numeric order.
- `contractChecks` has exactly five rows in the order frozen above.
- `inputFailures`, `inputExclusions`, and `inputSuppressions` use complete AR-S10 accounting rows and numeric-FT/Ordinal-subject ordering. `inputExclusions` is empty in this slice.
- `decision` is exactly `failureAttribution`, `nextAllowedAction`.

Artifact-state row is exactly:

```text
artifactId
path
requirement
presence
readStatus
worktreeSha256
commitBlobSha256
manifestSha256
identityStatus
freshnessStatus
evidence
```

Allowed values:

- `requirement`: `Required`, `ConditionalInput`, `ConditionalAuthority`, `ConditionalApproval`;
- `presence`: `Present`, `Absent`;
- `readStatus`: `Accepted`, `Failed`, `NotRead`;
- three SHA fields: nullable lowercase-64-hex; required worktree SHA is populated for every present artifact, commit/manifest SHA only where applicable;
- `identityStatus`: `Accepted`, `Failed`, `NotApplicable`;
- `freshnessStatus`: `Accepted`, `Failed`, `NotApplicable`;
- `evidence`: distinct Ordinal-sorted portable paths; absent optional rows use their registry path as the checked absence evidence.

Contract-check row is exactly:

```text
subjectId
status
attribution
evidence
prerequisites
```

`status` is `Accepted`, `Failed`, or `NotEvaluated`; `attribution` is a CT-02 string (`Accepted:<subjectId>`, exact FT attribution, or `FT-15:<subjectId>`). `evidence` is a distinct Ordinal-sorted portable path set and may be empty only where the upstream FT-15 rule permits. `prerequisites` is a distinct Ordinal-sorted CT-02 set of exact AR IDs or frozen stage/adapter IDs; it is never an open metadata field.

Decision on positive intake is exact:

```text
failureAttribution=None; intake and freshness checks passed; deferred checks remain NotEvaluated.
nextAllowedAction=Implement SP-01/SP-02 in a separately approved fixture-only slice.
```

### Complete O1 positive vector

Symbols are frozen derivations, not implementation-selected placeholders:

- `R01` through `R06` are the six literal SHA-256 values in the upstream Existing-input byte registry.
- `F07`, `F10`, and `F11` are SHA-256 over the exact raw blobs returned by Git calls 2, 4, and 5 respectively; each must also equal the audited worktree bytes, and `F07`/`F11` must equal their AR-I10 entries.
- `OID` is the exact lowercase 40-hex value returned identically by Git calls 1 and 6.
- `D9` is HI-13b over exact `(path,SHA)` pairs for AR-I01–I07, AR-I10, and AR-I11.

Positive top-level scalars/arrays are exact:

| Field | Value |
|---|---|
| schemaVersion | `1.0.0` |
| snapshotId | `snapshot-pc-install-001` |
| startCommitOid | `OID` |
| endCommitOid | `OID` |
| headStable | `true` |
| discoveryInputFingerprint | `D9` |
| inputFailures | `[]` |
| inputExclusions | `[]` |
| decision.failureAttribution | `None; intake and freshness checks passed; deferred checks remain NotEvaluated.` |
| decision.nextAllowedAction | `Implement SP-01/SP-02 in a separately approved fixture-only slice.` |

Every artifact-state field is frozen below. `[Pxx]` means a one-element evidence array containing that row's exact registry path; `null` is JSON null.

| artifactId | path | requirement | presence | readStatus | worktreeSha256 | commitBlobSha256 | manifestSha256 | identityStatus | freshnessStatus | evidence |
|---|---|---|---|---|---|---|---|---|---|---|
| AR-I01 | P01 | Required | Present | Accepted | R01 | null | null | Accepted | Accepted | `[P01]` |
| AR-I02 | P02 | Required | Present | Accepted | R02 | null | null | Accepted | Accepted | `[P02]` |
| AR-I03 | P03 | Required | Present | Accepted | R03 | null | null | Accepted | Accepted | `[P03]` |
| AR-I04 | P04 | Required | Present | Accepted | R04 | null | null | Accepted | Accepted | `[P04]` |
| AR-I05 | P05 | Required | Present | Accepted | R05 | null | null | Accepted | Accepted | `[P05]` |
| AR-I06 | P06 | Required | Present | Accepted | R06 | null | null | Accepted | Accepted | `[P06]` |
| AR-I07 | P07 | ConditionalInput | Present | Accepted | F07 | F07 | F07 | Accepted | Accepted | `[P07]` |
| AR-I08 | P08 | ConditionalInput | Absent | NotRead | null | null | null | NotApplicable | Accepted | `[P08]` |
| AR-I09 | P09 | ConditionalInput | Absent | NotRead | null | null | null | NotApplicable | Accepted | `[P09]` |
| AR-I10 | P10 | ConditionalAuthority | Present | Accepted | F10 | F10 | null | Accepted | Accepted | `[P10]` |
| AR-I11 | P11 | ConditionalApproval | Present | Accepted | F11 | F11 | F11 | Accepted | Accepted | `[P11]` |

`P01` through `P11` are the exact paths in the Narrow Artifact Registry, not aliases serialized into O1. `artifactStates` contains the literal paths and rows in AR numeric order.

All five contract-check rows are exact:

| subjectId | status | attribution | evidence | prerequisites |
|---|---|---|---|---|
| C2Check:LightweightPolicy | Accepted | `Accepted:C2Check:LightweightPolicy` | `[Tools/AssetImport/C2DiscoveryIntakeGate.psm1, Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1]` Ordinal-sorted | `[]` |
| C2Check:C1Handoff | Accepted | `Accepted:C2Check:C1Handoff` | `[Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json, Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json, Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json]` | `[AR-I01,AR-I02,AR-I03]` |
| C2Check:Freshness | Accepted | `Accepted:C2Check:Freshness` | `[Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json, Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json, Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json, Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json, Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json, Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json, Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json, Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json, docs/asset-migration/schemas/root-gate-summary.schema.json, docs/asset-migration/schemas/source-corpus-ledger.schema.json, docs/asset-migration/schemas/status-vocabulary.json]` | `[AR-I01,AR-I02,AR-I03,AR-I04,AR-I05,AR-I06,AR-I07,AR-I08,AR-I09,AR-I10,AR-I11,GitAdapter:EndHead,GitAdapter:StartCommitOid]` |
| C2Check:Conservation | NotEvaluated | `FT-15:C2Check:Conservation` | `[]` | `[Stage:C2Partitions]` |
| C2Check:PublicProjection | NotEvaluated | `FT-15:C2Check:PublicProjection` | `[P06]` | `[AR-O01,AR-O02,AR-O03,AR-O04,AR-O05]` |

Every displayed evidence/prerequisite array is already in Ordinal order and is serialized exactly as displayed. The two positive `inputSuppressions` rows are exact AR-S10 rows:

| recordId | subjectKind | subjectId | reasonCode | attribution | evidence |
|---|---|---|---|---|---|
| `accounting-sha256:6d540e7fefd265ddef57b835e7bfb8894085d609419b3ac98b2268876f006e1c` | ContractCheck | C2Check:Conservation | PrerequisiteUnavailable | `FT-15:C2Check:Conservation` | `[]` |
| `accounting-sha256:212ec1d5b7ffc164817068a9227f8c7d847dc091c517c41db4b4270236294016` | ContractCheck | C2Check:PublicProjection | PrerequisiteUnavailable | `FT-15:C2Check:PublicProjection` | `[docs/asset-migration/schemas/root-gate-summary.schema.json]` |

### NAR-S02 O2 terminal coverage

O2 is exactly, in order:

```text
status
issueCount
registeredArtifactCount
readArtifactCount
requiredArtifactCount
presentOptionalArtifactCount
absentOptionalArtifactCount
failedRegistrySlotCount
acceptedArtifactCount
failedArtifactCount
contractCheckCount
acceptedCheckCount
failedCheckCount
notEvaluatedCheckCount
inputSubjectCount
acceptedInputSubjectCount
inputFailureCount
excludedInputSubjectCount
notEvaluatedInputSubjectCount
gitInspectionProcessCount
heavyProcessCount
realAssetReadCount
createdExtractedCount
createdImportedCount
startCommitOid
endCommitOid
headStable
discoveryInputFingerprint
nextAllowedAction
```

All count fields are nonnegative integers derived from NP sets, audited readers, AST/runtime process audit, and exact before/after paths. OIDs/fingerprint follow NAR-S01. Positive O2 is frozen as:

```text
status=Passed
issueCount=0
registeredArtifactCount=11
readArtifactCount=9
requiredArtifactCount=6
presentOptionalArtifactCount=3
absentOptionalArtifactCount=2
failedRegistrySlotCount=0
acceptedArtifactCount=9
failedArtifactCount=0
contractCheckCount=5
acceptedCheckCount=3
failedCheckCount=0
notEvaluatedCheckCount=2
inputSubjectCount=14
acceptedInputSubjectCount=12
inputFailureCount=0
excludedInputSubjectCount=0
notEvaluatedInputSubjectCount=2
gitInspectionProcessCount=6
heavyProcessCount=0
realAssetReadCount=0
createdExtractedCount=0
createdImportedCount=0
startCommitOid=<frozen lowercase 40-hex OID>
endCommitOid=<same OID>
headStable=True
discoveryInputFingerprint=<independently recomputed lowercase 64-hex>
nextAllowedAction=Implement SP-01/SP-02 in a separately approved fixture-only slice.
```

O1/O2 are returned only to the test process and terminal. They are not AR-O artifacts and grant no downstream authorization.

---

## 6. P0 Pure HI-13b Unit Vector

P0 takes six in-memory `(path,sha256)` pairs from the upstream registered AR-I01–I06 values. It performs no file read, Git call, fixture validation, partitioning, or gate decision. It must produce only:

```text
7f3255b66670c61e4271c5dab89a5bd9bb5c964f7f3f3b190b94126af9ff617b
```

P0 verifies domain tags, field names, UTF-8 byte lengths, nested final LF, entry count, Ordinal sorting, and SHA-256. It has `gitInspectionProcessCount=0` because O2 is not constructed for P0. P0 cannot be cited as freshness evidence.

---

## 7. Frozen Git Adapter Contract

The adapter resolves the absolute `git.exe` path once before auditing and never invokes a shell. Every child uses `System.Diagnostics.ProcessStartInfo.ArgumentList`, redirects stdout/stderr, disables shell execution, and captures `cat-file blob` stdout as raw bytes from `StandardOutput.BaseStream` without text decoding or newline conversion.

### Child environment

For every child, create a new environment from the parent after removing every key whose name begins `GIT_`, `GCM_`, or `SSH_` under OrdinalIgnoreCase, plus exact `HOME` and `XDG_CONFIG_HOME`. Then set exactly:

```text
GIT_CONFIG_NOSYSTEM=1
GIT_CONFIG_GLOBAL=NUL
GIT_CONFIG_COUNT=0
GIT_OPTIONAL_LOCKS=0
GIT_TERMINAL_PROMPT=0
GCM_INTERACTIVE=Never
```

No parent-process environment variable is mutated. The adapter asserts before each launch that no other `GIT_*`, `GCM_*`, or `SSH_*` key remains. Repository resolution comes only from the exact `-C <repositoryRoot>` argument. Any deviation is FT-13.

### Exact positive command sequence

The positive committed vector performs exactly six child invocations, in this order:

```text
1. git.exe -C <repositoryRoot> rev-parse --verify HEAD^{commit}
2. git.exe -C <repositoryRoot> cat-file blob <startOid>:Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json
3. git.exe -C <repositoryRoot> ls-tree -z --full-tree <startOid> -- Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json
4. git.exe -C <repositoryRoot> cat-file blob <startOid>:Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json
5. git.exe -C <repositoryRoot> cat-file blob <startOid>:Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json
6. git.exe -C <repositoryRoot> rev-parse --verify HEAD^{commit}
```

Rules:

- calls 1 and 6 must exit 0 and each emit exactly one identical lowercase 40-hex OID plus one LF;
- calls 2, 4, and 5 must exit 0; their raw stdout is the exact blob byte sequence and stderr is empty;
- call 3 must exit 0 with exactly zero stdout bytes and zero stderr bytes, proving both registered optional paths are absent at the frozen commit; its two path arguments and order are fixed as displayed;
- every `<startOid>:<path>` is assembled only after the OID and exact registry path pass validation; no user-controlled revision/path text enters arguments;
- worktree absence of AR-I08/I09 is separately checked with exact paths;
- the final HEAD check occurs after all audited worktree reads, parsing, hashing, manifest/approval validation, and HI-13b computation;
- an OID change makes Freshness fail and suppresses the fingerprint even if all earlier bytes matched;
- `gitInspectionProcessCount=6`; these are allowlisted read-only inspection processes, not heavy processes; every other child increments `heavyProcessCount` and fails FT-13.

### Adapter failure ownership and actual counts

`gitInspectionProcessCount` counts allowlisted Git child processes that actually started, including a started process that exits nonzero. A rejected prelaunch request or a process-start exception does not increment it. `heavyProcessCount` counts forbidden children that actually started; a grammar/environment violation rejected before launch leaves it zero but still fails LightweightPolicy under FT-13.

There are only two Git-adapter failure owners:

1. A command, argument, environment, executable, shell mode, or target outside the exact adapter contract is solely `FT-13:C2Check:LightweightPolicy` with reason `HeavyOperationAttempted`.
2. An exact allowlisted invocation that cannot start, exits unexpectedly, emits invalid stdout/stderr, returns an invalid OID/blob/absence result, or cannot perform final HEAD revalidation is solely `FT-03:C2Check:Freshness` with reason `StaleFingerprint`. Operational unavailability means freshness is unproved; it does not create FT-13 or an artifact FT-02 row.

Shape/semantic failures discovered after valid raw blobs are obtained remain FT-02 on AR-I10 or AR-I11 as defined above. They are not adapter failures.

| Failure point | Unique owner/reason | Remaining calls | Actual `gitInspectionProcessCount` | OID/head fields | O1 check/accounting state | O2 state |
|---|---|---|---|---|---|---|
| Prelaunch contract rejection before call 1 | FT-13 / HeavyOperationAttempted | none | 0 | start=null, end=null, headStable=null | LightweightPolicy Failed; Freshness NotEvaluated FT-15; one FT-13 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1, notEvaluated includes Freshness+deferred checks; count=0 |
| Prelaunch contract rejection before call N, N=2..6 | FT-13 / HeavyOperationAttempted | none, including no final revalidation | N-1 | start=OID; end=null; headStable=null | LightweightPolicy Failed; Freshness NotEvaluated FT-15; one FT-13 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count=N-1 |
| Exact call 1 cannot start | FT-03 / StaleFingerprint | none | 0 | start=null, end=null, headStable=null | LightweightPolicy Accepted; Freshness Failed; one FT-03 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count=0 |
| Exact call 1 starts but has invalid exit/output | FT-03 / StaleFingerprint | none | 1 | start=null, end=null, headStable=null | same FT-03 vector | Failed; issue=1, inputFailure=1; count=1 |
| Exact call N cannot start, N=2..5 | FT-03 / StaleFingerprint | skip normal calls through 5; attempt call 6 once | N when final starts, N-1 when final cannot start | start=OID; end=OID/null; headStable=true/null | Freshness Failed once; one FT-03 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count as displayed |
| Exact call N starts but has invalid exit/output, N=2..5 | FT-03 / StaleFingerprint | skip normal calls through 5; attempt call 6 once | N+1 when final starts, N when final cannot start | start=OID; end=OID/null; headStable=true/null | same single FT-03 vector | Failed; issue=1, inputFailure=1; count as displayed |
| Call 6 cannot start | FT-03 / StaleFingerprint | none | 5 | start=OID, end=null, headStable=null | Freshness Failed once; one FT-03 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count=5 |
| Call 6 starts but has invalid exit/output | FT-03 / StaleFingerprint | none | 6 | start=OID, end=null, headStable=null | same single FT-03 vector | Failed; issue=1, inputFailure=1; count=6 |
| Calls 1/6 return valid but different OIDs | FT-03 / StaleFingerprint | complete | 6 | start=OID1, end=OID2, headStable=false | Freshness Failed once; one FT-03 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count=6 |
| All six Git calls valid; later AR-I10/11 shape invalid | FT-02 / InvalidSchema on exact artifact | complete | 6 | start=end=OID, headStable=true | exact artifact Failed; Freshness NotEvaluated FT-15; one FT-02 failure/issue; fingerprint null | Failed; issue=1, inputFailure=1; count=6 |

For every failure vector, `status=Failed`, `discoveryInputFingerprint=null`, and `nextAllowedAction` is the owning FT row's repair action. Counts not named in the table derive from the actual partially evaluated NP sets; tests must freeze every row of this matrix rather than asserting only the positive count.

Static probes must cover command grammar mutations, extra arguments, alternate refs, config overrides, environment injection, helper-function calls, top-level calls, dynamic commands, text-decoded blob reads, and omitted final HEAD validation.

---

## 8. Completed Task Record And Future Decomposition

### Task 1: Freeze AR-I07, AR-I10, And AR-I11

> **Completion:** COMPLETE and independently reviewed at `b635059689d7a7b67ed715e8fcdf2cf8267d7664`. Do not recreate, amend, or recommit these fixtures as part of Tasks 2A-2C.

**Historical duration:** 20–30 minutes. Execution is complete; this section remains the reviewed fixture acceptance record.

**File scope:**

- Create `Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json` (AR-I07).
- Create `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json` (AR-I10).
- Create `Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json` (AR-I11).
- Read only AR-I01, the amended C2 spec, and this plan.
- Do not modify scripts, C0/C1 contracts, minimal-slice files, or any other fixture.

**Acceptance:** exact AR-S02/04a/04b shapes; r5 complete-key/null-ID/negative-class counterexample; valid r6 HI-03; exact HI-15 approval; raw-byte SHA bindings; AR-I10 lists exactly AR-I07/11; no evidence-path reads; no forbidden directories; exact three-file commit.

#### Step 1 — Materialize AR-I07 raw rows (3–5 minutes)

**References:** AR-I07/AR-S02; SP-03a/SP-08; FT-05.

- [ ] Instantiate r1–r6 from P1 with every AR-S02 key.
- [ ] Recompute r1–r4/r6 HI-03; keep r5 `observationId=null`, `classId=-1` and HI-02 eligibility.
- [ ] Question answered: all rows have one structural shape while r5 remains semantically rejected.

#### Step 2 — Materialize AR-I11 approval (2–5 minutes)

**References:** AR-I11/AR-S04b/HI-15; SP-03a/SP-08; FT-02/FT-14.

- [ ] Add the exact AR-S04b envelope and one r6 approval row.
- [ ] Recompute HI-15 from the frozen field order and bind `observationArtifactSha256` to exact AR-I07 bytes.
- [ ] Question answered: r6 has one unique approval identity and FT-14 evidence source.

#### Step 3 — Materialize AR-I10 authority (2–5 minutes)

**References:** AR-I07/AR-I10/AR-I11; `C2Check:Freshness`; FT-03.

- [ ] Hash exact AR-I07 and AR-I11 raw bytes.
- [ ] Add exactly two Ordinal-sorted entries for AR-I07 and AR-I11; never list AR-I10.
- [ ] Question answered: no file self-authorizes and AR-I08/09 remain absent.

#### Step 4 — Run raw-byte/shape/identity verification (3–5 minutes)

**References:** AR-I07/AR-I10/AR-I11; SP-03a/SP-08; FT-02/FT-05/FT-14.

```powershell
pwsh -NoProfile -Command '$p=@("Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json","Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json","Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json"); foreach($x in $p){$b=[IO.File]::ReadAllBytes($x); if($b.Length -eq 0 -or $b[0] -eq 0xEF -or $b[-1] -ne 0x0A -or [Text.Encoding]::UTF8.GetString($b).Contains("`r")){throw "noncanonical bytes: $x"}; $null=[Text.Encoding]::UTF8.GetString($b)|ConvertFrom-Json -Depth 100; "{0} {1}" -f $x,(Get-FileHash -Algorithm SHA256 $x).Hash.ToLowerInvariant()}'
```

- [ ] Independently compare exact key sets, HI-03/HI-15 recomputations, AR-I07↔AR-I11 SHA, and both AR-I10 entries; JSON parsing alone is insufficient.

#### Step 5 — Verify boundaries and exact diff (2–5 minutes)

**References:** AR-I07/AR-I10/AR-I11; NP-01; FT-04/FT-13.

```powershell
git diff --check
git status --short
git diff --name-only
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

- [ ] Expected diff is exactly the three fixture paths; both path checks are `False`; root `AGENTS.md` remains untracked.

#### Step 6 — Exact commit gate (2–5 minutes)

**References:** AR-I07/AR-I10/AR-I11; NP-01/NP-02; FT-03.

```powershell
git add -- Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json
git diff --cached --check
git diff --cached --name-only
```

- [ ] Commit only after a separate explicit human confirmation of the exact cached three-file diff.

**Completed checkpoint:** The reviewed Task 1 report and commit are the prerequisite for Task 2A. Do not recreate these fixtures or begin Task 2A without its separate authorization.

### Reference: Former Task 2 Checklist — Superseded, Do Not Execute

> This checklist is retained only as the complete acceptance inventory for the intake/freshness slice. It is not one executable Task. Its requirements are redistributed across Tasks 2A, 2B, and 2C below so each increment can finish GREEN within 20–30 minutes.

**Historical combined estimate:** 20–30 minutes was not credible for this acceptance surface; this mismatch is why the combined Task is superseded.

**File scope:**

- Create `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`.
- Create `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`.
- Read only AR-I01–I11 according to the Narrow Artifact Registry.
- Do not modify any fixture, schema, vocabulary, plan, spec, minimal-slice file, or user state.

**Acceptance:** P0 pure unit vector; exact complete O1/O2 positive vector; all failure-matrix rows including actual Git call count/nullability; complete module/harness AST; exact six-call positive trace; zero heavy/real-asset/created-directory counters; exact two-file commit.

#### Step 1 — Establish RED model assertions (3–5 minutes)

**References:** O1/O2; NP-01–NP-05; FT-01/FT-02/FT-03/FT-04/FT-13/FT-15.

- [ ] Encode NP-01–NP-05 conservation, all 11 artifact rows, all five check rows, both FT-15 suppressions, and O2 field order/counts.
- [ ] Add P0 as a no-I/O HI-13b unit vector.
- [ ] Run the focused command; RED may be caused only by the absent module.

#### Step 2 — Establish Git/safety RED probes (3–5 minutes)

**References:** AR-I07–AR-I11/O2; `C2Check:LightweightPolicy`/`C2Check:Freshness`; FT-03/FT-13.

- [ ] Freeze the six positive ArgumentList arrays, sanitized child environment, raw BaseStream blob capture, and end-HEAD position.
- [ ] Add every adapter failure-matrix row, including start failures, intermediate short-circuit/final revalidation, mismatch, FT-13 prelaunch rejection, actual call counts, and nullable fields.
- [ ] Add whole-module/harness helper/top-level/dynamic/file/process probes.

#### Step 3 — Implement pure registry/intake validator (3–5 minutes)

**References:** AR-I01–AR-I11/O1; NP-01–NP-05; FT-01/FT-02/FT-04/FT-15.

- [ ] Accept parsed values plus audited byte/OID facts only; accept no path/callback/process object.
- [ ] Build all 11 artifact states and five check rows with first-owner FT ordering.
- [ ] Construct O1 exactly and suppress its fingerprint on every direct failure.

#### Step 4 — Implement HI-13 and Git adapter (3–5 minutes)

**References:** AR-I01–AR-I11/HI-13/O1/O2; NP-01/NP-02/NP-05; FT-03/FT-13.

- [ ] Implement exact HI-13a/b framing with Ordinal sorting and verify P0.
- [ ] Implement only the frozen environment and six-command grammar; record launched-process count.
- [ ] Hash raw commit blobs/worktree bytes, validate AR-I10/11, then perform final HEAD revalidation.

#### Step 5 — Reach GREEN and verify matrices (3–5 minutes)

**References:** O1/O2; NP-01–NP-05; every narrowed Failure Transition row.

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1
```

- [ ] Require exact O1 artifact/check/suppression vectors, exact O2 positive output, every failure vector, `gitInspectionProcessCount=6`, and all four safety counters zero.

#### Step 6 — Completion and exact commit gate (3–5 minutes)

**References:** Former combined intake script artifacts/O2; NP-01–NP-05; FT-13.

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1
git diff --check
git status --short
git diff --name-only -- Tools/AssetImport
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

- [ ] Verify fixtures/contracts/docs/minimal slice unchanged and the diff contains exactly two scripts.
- [ ] Stage the two exact paths, run cached check/name verification, and commit only after separate explicit confirmation.

**Historical checkpoint:** Do not execute or commit this former combined Task. Use the three checkpoints below.

### Task 2A: Pure Intake Model And HI-13

**Duration:** 20–30 minutes. Requires separate explicit authorization.

**File scope:**

- Create `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`.
- Create `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`.
- Read no repository artifact at runtime and launch no process in this Task.
- Do not modify Task 1 fixtures, C0/C1 artifacts, schemas, vocabulary, plans, specs, minimal-slice files, or user state.

**Acceptance:** P0 produces the registered HI-13b digest from six injected in-memory pairs; the pure validator builds all 11 artifact-state slots, five contract-check slots, NP-01–NP-05 partitions, and O1/O2 from injected accepted/failure facts; representative FT-01/02/04/15 vectors fail closed; the focused test finishes GREEN with zero filesystem/process operations.

#### Step 1 — RED for P0 framing (2–5 minutes)

- [ ] Assert domain tags, byte lengths, final LF, Ordinal ordering, and exact P0 digest.
- [ ] Run the focused test; RED may be caused only by the absent pure implementation.

#### Step 2 — Implement pure HI-13 and registry slots (3–5 minutes)

- [ ] Accept only parsed/in-memory values; accept no path, callback, process, or filesystem object.
- [ ] Build exact AR-I01–I11 slot identities and reject missing, duplicate, or reordered registry identities.

#### Step 3 — Implement pure NP/O1/O2 derivation (5 minutes)

- [ ] Derive NP-01–NP-05 sets and conservation from injected facts.
- [ ] Construct the registered O1/O2 field order and suppress the fingerprint on a direct failure.

#### Step 4 — GREEN and safety proof (3–5 minutes)

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case Pure
```

- [ ] Require exact positive output plus representative FT-01/02/04/15 vectors.
- [ ] Parse the complete module/harness AST and require zero filesystem/process invocation.

#### Step 5 — Narrow commit gate (2–5 minutes)

- [ ] Verify only the two scripts changed; run `git diff --check`; verify both forbidden directories remain absent.
- [ ] Stage the two exact paths only and commit only after review.

**Stop checkpoint:** Report the Task 2A commit, P0 digest, pure O1/O2 vector, representative failures, AST evidence, exact two-file scope, and forbidden-directory state. Stop; do not begin Task 2B.

### Task 2B: Audited Git Freshness Adapter

**Duration:** 20–30 minutes. Prerequisite is an independently reviewed Task 2A commit. Requires separate explicit authorization.

**File scope:** modify only the same module and focused test. All fixture and contract files remain read-only.

**Acceptance:** implement only the frozen Git executable resolution, sanitized environment, ArgumentList grammar, raw blob capture, exact positive six-call trace, actual launched-process counting, and start/end HEAD equality. Exact adapter failures map only to FT-03 or FT-13. The full focused suite remains GREEN.

#### Steps

1. **RED adapter grammar probes (3–5 minutes):** freeze exact commands, environment, raw-byte capture, and prelaunch rejections.
2. **Implement adapter (5 minutes):** no shell, no text-decoded blob read, no mutable parent environment.
3. **Freeze lifecycle failures (5 minutes):** cover start failure, one intermediate failure with final revalidation, final failure, and changed HEAD; derive actual call counts/nullability.
4. **GREEN (3–5 minutes):** run `Test-C2DiscoveryIntakeGate.ps1 -Case GitAdapter`, then the complete focused script.
5. **Narrow commit (2–5 minutes):** exact two-file diff, `diff --check`, forbidden-directory and protected-input checks.

**Stop checkpoint:** Report the Task 2B commit, six-call trace, sanitized-environment proof, selected failure vectors, actual process counts, protected-input state, and full focused GREEN. Stop; do not begin Task 2C.

### Task 2C: Fixture Integration And Complete Matrix

**Duration:** 20–30 minutes. Prerequisite is an independently reviewed Task 2B commit. Requires separate explicit authorization.

**File scope:** modify only the same module and focused test; read AR-I01–I11 strictly through audited readers; do not modify any input artifact.

**Acceptance:** integrate the reviewed Task 1 blobs, required-byte registry, audited worktree reads, Git facts, HI-13b, exact O1/O2 positive vector, all remaining failure-matrix rows, complete AST/runtime safety, and end-HEAD validation. Positive output has 11 registered slots, 9 reads, 2 absent optionals, 5 checks with 3 Accepted/2 NotEvaluated, six Git inspections, and all heavy/real-asset/created-directory counters zero.

#### Steps

1. **Integrate audited readers (3–5 minutes):** allow only exact registry paths and bind every read to its slot.
2. **Complete matrix (5 minutes):** add every omitted FT-02/03/04/13/15 and adapter lifecycle vector without double ownership.
3. **Exact O1/O2 GREEN (5 minutes):** assert every field, row, count, fingerprint, OID, decision, and suppression.
4. **Regression and safety (3–5 minutes):** run the complete focused test, minimal-object gate, and necessary C1 compatibility regressions.
5. **Narrow commit gate (2–5 minutes):** exact two scripts, protected inputs unchanged, `diff --check`, no forbidden artifacts, AGENTS untracked/unstaged.

**Stop checkpoint:** Report the Task 2C commit, P0/D9, complete O1/O2, full failure matrix, AST/runtime audit, regression evidence, and forbidden-directory state. Stop; SP-01/SP-02 requires a new plan and authorization.

---

## 9. Read-Only Review Gate

Review must return `APPROVED` or `BLOCKED` and verify:

- upstream AR-I11/AR-S04b/HI-15/FT-14 form one unique approval model;
- r5 has a complete raw-row key set and cannot conflict with exact-shape acceptance;
- r6 exclusion is impossible without the exact approval artifact and evidence vector;
- Narrow Artifact, Subject/Partition, and Failure Transition registries are mutually consistent;
- O1/O2 shapes and positive counts satisfy every displayed conservation equation;
- P0 is only an in-memory HI-13b vector;
- Git uses one start OID, raw blobs from that OID, exact six-call sequence, sanitized environment, and final HEAD equality;
- no fixture or implementation work has begun.
