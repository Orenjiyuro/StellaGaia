# StellaSora C2 SP-07/SP-08 Phase A Plan

**Date:** 2026-07-15
**Status:** DRAFT FOR READ-ONLY REVIEW — SP-08 subject model and SP-07 private join amended
**Baseline:** `codex/asset-corpus-integration` at `6b8bc1b01077036394473b39f51f71e2412f0c09`
**Scope:** fixture-only SP-07 dispatch and SP-08 input accounting. No fixture/spec/schema changes, output persistence, SP-09, C3-C6, G5, Unity, extraction, import, real assets, or forbidden-path creation.

## 1. Authorization And Task Boundary

This plan contains exactly two independently authorized Tasks. A plan may contain two Tasks; execution remains one Task per user authorization and one independent commit per Task. Task 1 does not authorize Task 2. Task 2 does not authorize AR-O01-O05 persistence or SP-09.

Task 1 becomes executable only after independent approval of this amended spec/plan. Task 2 still requires the separately approved Task 1 commit.

Both Tasks modify only:

- `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`
- `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`

The implementation remains pure in-memory except for the already-approved audited Git/fixture integration path. It accepts no reader callback, arbitrary script block, process object, filesystem object, final count, final partition, or caller-supplied check verdict.

## 2. Narrow Artifact Registry

| ID | Role in this plan | Exact shape/source | Success | Failure/suppression |
| --- | --- | --- | --- | --- |
| AR-P01 | private normalized diagnostic state | exact AR-S05, including `dispatchInputFacts`; normalized diagnostic result appends `dispatchRows` after `publicObjectsWithCanonicalId`; SP-08 arrays/counts remain the registered AR-S05/AR-S11 shapes | retained in memory for focused/integration diagnostics | never a downstream-valid artifact |
| AR-O04 | future private dispatch output | exact AR-S09; no file is written in either Task | Task 1 proves a normalized in-memory AR-S09 value only when gate otherwise Passed | any InputFailure/check failure gives zero eligible rows and suppresses AR-O04 |
| AR-O05 | future diagnostic output | exact AR-S11 accounting/coverage shapes are the SP-08 projection oracle | Task 2 constructs the complete normalized accounting state in memory | persistence and atomic transaction remain SP-09/deferred |

No new artifact identity or hash is invented. AR-O04 identity is registry ID plus exact portable path `Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json`; its eventual content fingerprint is CT-04 over exact AR-S09 bytes. This plan does not serialize or write those bytes.

### 2.1 Normalized pure result extension

Append, without changing existing order:

```text
dispatchRows
```

to the existing normalized state after `publicObjectsWithCanonicalId`. A dispatch row is exactly AR-S09 row order:

```text
assetObjectId
canonicalAssetId
sourceId
familyLane
memberSelectorInputs
configurationCandidateId
dispatchStatus
evidence
```

Each selector row is exactly:

```text
kind
value
```

Task 2 does not add a second accounting object. It replaces any incrementally patched counts with the already-registered O1 arrays and O2/AR-S11 count fields derived from complete sets.

## 3. Subject/Partition Registry

### 3.1 SP-07 dispatch subjects

Universe on a globally Passed normalized run is every `publicObjectsWithCanonicalId` row, identity `assetObjectId`. On any InputFailure or failed contract check, the universe is empty even if independent SP-04/SP-06 diagnostic rows exist.

The pure input is two exact arrays joined one-to-one by object ID:

1. `publicObjectsWithCanonicalId`: complete AR-S06 object rows only; no private fields.
2. `dispatchInputFacts`: complete AR-S05 rows exactly `assetObjectId,sp04Partition,privateConfigurationDisposition,configurationCandidateId`.

Both arrays are Ordinal object-ID sorted and have the same unique ID set. The private row uses `Classified|Unclassified`; nullable disposition copies SP-04 before public null mapping; candidate ID is non-null iff disposition is non-null and must equal HI-09b. Shape, set, order, nullability, or identity mismatch is FT-10 before dispatch, produces no dispatch row, and does not create per-join accounting subjects.

Partitions are mutually exclusive and exhaustive:

```text
dispatchEligibleObjectCount
= assignedObjectCount
 + retainedForDiagnosisObjectCount
 + configurationOnlyObjectCount

assignedObjectCount
= audioObjectCount
 + environmentObjectCount
 + actorObjectCount
 + uiObjectCount
 + effectsObjectCount
```

No `unassignedObjectCount` exists. `Unassigned` is a lane used only with `RetainedForDiagnosis` or `ConfigurationOnly`.

Apply the authoritative rules in this order:

1. Non-null private configuration disposition: `ConfigurationOnly`, `Unassigned`, exact non-null HI-09b `configurationCandidateId`.
2. Otherwise SP-04 `Unclassified`: `RetainedForDiagnosis`, `Unassigned`, null candidate ID.
3. Otherwise exact case-sensitive object-type sets:
   - Audio: `AudioClip`, `AudioMixer`, `WwiseBank`, `WwiseMedia`.
   - Environment: `Scene`, `TerrainData`, `LightmapData`, `MeshRenderer`.
   - Actor: `Avatar`, `AnimationClip`, `AnimatorController`, `SkinnedMeshRenderer`.
   - UI: `Sprite`, `SpriteAtlas`, `Font`, `TMP_FontAsset`, `Canvas`.
   - Effects: `ParticleSystem`, `VisualEffect`, `TrailRenderer`.
4. Exactly one lane match: `Assigned`; any other type: `RetainedForDiagnosis`, `Unassigned`.

Path/name heuristics, case folding, aliases, multiple lanes, caller-supplied lanes/statuses, and configuration-vs-family precedence reversal are forbidden.

Selector construction is derived only from the exact public object:

- one `ObjectType` = `objectType`;
- one `ClassId` = invariant decimal `classId`;
- one `CanonicalAssetId` = `canonicalAssetId`;
- one `PlatformVariant` = `platformVariant`;
- zero or one per distinct `DependencyObjectId`;
- one per distinct tool-observation `observation` string; at least one for every resolved object.

Exact duplicate `(kind,value)` pairs collapse. Rows sort Ordinal by `kind`, then `value`. No other kind is accepted. Dispatch evidence is the exact distinct Ordinal public evidence set.

### 3.2 SP-08 accounting subjects

The universe is constructed from actual collections, never supplied totals:

1. every actually read AR-I artifact, once;
2. every raw AR-I07/08/09 row when a rows array exists, once;
3. every derived HI-11a, HI-11b, HI-09c, or HI-10c conflict, once;
4. exactly the five contract-check identities, once.

AR-I11 approval rows and canonical provenance rows are validation material, not subjects. A document-level FT-05 uses the artifact subject and creates no raw-row subjects. A row subject uses HI-03/06/07 when valid and HI-02 on row-level FT-04/05.

Partitions are `Accepted`, `InputFailure`, `InputExclusion`, `NotEvaluated`. They obey simultaneously:

```text
inputSubjectCount
= acceptedInputSubjectCount
 + inputFailureCount
 + excludedInputSubjectCount
 + notEvaluatedInputSubjectCount

inputObservationCount
= acceptedInputObservationCount
 + rejectedInputObservationCount
 + excludedInputCount

inputFailureCount
= rejectedInputObservationCount
 + contractFailureRecordCount
 + fileDiscoveryConflictRecordCount
 + observationConflictRecordCount
 + configurationConflictRecordCount
 + canonicalConflictRecordCount

excludedInputSubjectCount = excludedInputCount
issueCount = inputFailureCount
```

Each direct subject has one parent only. A conflict row is not also a rejected observation. FT-10 is one `C2Check:Conservation` failure regardless of how many formulas fail. Only checks may be `NotEvaluated`; no artifact, raw row, conflict, approval, or provenance row may be NotEvaluated or excluded.

## 4. Five Contract Checks And Failure Transitions

Checks are ordered exactly:

1. `C2Check:LightweightPolicy`
2. `C2Check:C1Handoff`
3. `C2Check:Freshness`
4. `C2Check:Conservation`
5. `C2Check:PublicProjection`

Every check row retains the existing exact O1 shape `subjectId,status,attribution,evidence,prerequisites`.

| Check | Derived prerequisite/predicate | False owner | Unavailable owner |
| --- | --- | --- | --- |
| LightweightPolicy | audited event/AST sets contain no heavy, Unity, extraction, import, native, dynamic, or real-asset operation | FT-13, one `LightweightPolicy` failure | never unavailable |
| C1Handoff | accepted AR-I01 identity/path binding to AR-I02/I03 | FT-01, one `C1Handoff` failure | never unavailable |
| Freshness | actual registered reads, seven-call Git result, blob/worktree/manifest SHA sets, HI-13b, stable HEAD | FT-03, one `FreshnessCheck` failure | FT-15 only when a prior owning shape/path failure makes the required freshness fact unavailable |
| Conservation | provenance precheck plus every applicable SP-01 through SP-08 equation from actual sets | FT-10, one `ConservationCheck` failure | FT-15 when accepted AR-I01/02/03 or a present observation document cannot be partitioned |
| PublicProjection | exact in-memory AR-S06 through AR-S12 projections, including Required AR-S12 | FT-11, one `PublicProjection` failure | FT-15 unless Conservation is Accepted and AR-I04/05/06 are accepted |

FT-15 produces one `inputSuppressions` AR-S10 row with `reasonCode=PrerequisiteUnavailable`, adds one NotEvaluated check, and adds no failure or issue. The prerequisite's own transition remains sole failure owner.

Any failure gives `gateStatus=Failed`, null discovery fingerprint, no downstream authorization, and SP-07 `0=0+0+0`. Independently evaluable diagnostic partitions remain retained. This plan does not implement FT-12/SP-09 persistence.

## 5. Frozen Pure Vectors

### 5.1 SP-07 exact positive matrix

Use one base public object with:

```text
assetObjectId=sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11
canonicalAssetId=same value
sourceId=pc-install-primary
objectType=Sprite
classId=1
dependencyObjectIds=[]
toolObservations=[{toolName=ToolA,observation=version=1.0.0;observationId=observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180;resolution=SingleTool}]
platformVariant=Pc
configurationDisposition=NotConfiguration
evidence=[Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r1.json]
```

Its separately registered exact `dispatchInputFacts` row is:

```text
assetObjectId=sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11
sp04Partition=Classified
privateConfigurationDisposition=null
configurationCandidateId=null
```

Its exact selector sequence is:

```text
CanonicalAssetId=<object ID>
ClassId=1
ObjectType=Sprite
PlatformVariant=Pc
ToolObservation=version=1.0.0;observationId=observation-sha256:4854cc54de709e7419a003802f29f602da1ce4aeaddc3fef1085bbebe57e0180;resolution=SingleTool
```

Ordinal kind order above is authoritative. Expected row is `Assigned/UI`, null candidate ID.

The focused matrix clones only named fields:

| Vector | Mutation | Expected |
| --- | --- | --- |
| Audio | objectType=`AudioClip` | Assigned/Audio |
| Environment | objectType=`Scene` | Assigned/Environment |
| Actor | objectType=`Avatar` | Assigned/Actor |
| UI | base Sprite | Assigned/UI |
| Effects | objectType=`ParticleSystem` | Assigned/Effects |
| Unknown type | objectType=`DefinitelyUnknown` | RetainedForDiagnosis/Unassigned |
| Unclassified precedence | sp04Partition=`Unclassified`, objectType=`Sprite` | RetainedForDiagnosis/Unassigned |
| Configuration precedence | private configuration disposition=`Parsed`, objectType=`Sprite` | ConfigurationOnly/Unassigned, `configurationCandidateId=config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564` |
| Case sensitivity | objectType=`sprite` | RetainedForDiagnosis/Unassigned |
| Dependency/tool dedupe | duplicate dependency ID and duplicate observation text | one selector for each pair |

The eleven-row aggregate (five lanes, unknown, unclassified, configuration, case, plus two additional Audio/Effects representatives) must hard-code `11=7 Assigned+3 RetainedForDiagnosis+1 ConfigurationOnly` and `7=2 Audio+1 Environment+1 Actor+1 UI+2 Effects`. Expected values are literals in the harness, never generated with production mapping helpers.

### 5.2 SP-07 suppression vector

Inject the same normalized objects plus one pre-existing InputFailure. Expected:

```text
dispatchEligibleObjectCount=0
assignedObjectCount=0
retainedForDiagnosisObjectCount=0
configurationOnlyObjectCount=0
all five lane counts=0
dispatchRows=[]
outputsSuppressed=true
```

### 5.3 SP-08 amended audited integration vector

The amended authoritative model includes every actually read artifact. AR-I08 is read for SP-02 and is therefore an SP-08 subject. Negative raw rows and conflicts do not make Conservation/PublicProjection unavailable when their partitions and diagnostic/private projections are exact. All five checks are Accepted in this vector:

```text
read artifact subjects=10: AR-I01..AR-I08, AR-I10, AR-I11
raw observation subjects=6: r1..r6
contract checks=5
derived conflict subjects=1: gConflict (HI-11b)
inputSubjectCount=22
acceptedInputSubjectCount=19: 10 artifacts + 4 accepted rows + 5 checks
inputFailureCount=2: r5 + gConflict
excludedInputSubjectCount=1: r6
notEvaluatedInputSubjectCount=0
22=19+2+1+0

inputObservationCount=6
acceptedInputObservationCount=4
rejectedInputObservationCount=1
excludedInputCount=1
6=4+1+1

contractFailureRecordCount=0
fileDiscoveryConflictRecordCount=0
observationConflictRecordCount=1
configurationConflictRecordCount=0
canonicalConflictRecordCount=0
2=1+0+0+1+0+0
issueCount=2
```

The pre-amendment implementation currently reports:

```text
inputSubjectCount=22
acceptedInputSubjectCount=17
inputFailureCount=2
excludedInputSubjectCount=1
notEvaluatedInputSubjectCount=2
```

Task 2 must change those two NotEvaluated checks to Accepted only after deriving their predicates from complete actual sets; it may not overwrite counts. The overall gate remains Failed because two direct InputFailures exist, and SP-07 remains suppressed with zero eligible objects.

### 5.4 SP-08 failure vectors

- FT-10: mutate two independent conservation equations in one input. Expect exactly one Conservation failure/accounting row, one issue, no second FT-10 row, PublicProjection NotEvaluated under FT-15, and SP-07 suppressed.
- FT-11: with Accepted Conservation and accepted AR-I04/05/06, mutate exactly one Required AR-S12 field. Expect one PublicProjection failure, evidence exactly AR-I06 plus AR-S12 portable paths, no dispatch rows, null fingerprint.
- FT-15: make Freshness prerequisite unavailable through an already-owned AR-I10 FT-02 shape failure. Expect Freshness NotEvaluated plus exactly one suppression, no added issue; Conservation/PublicProjection states follow their own prerequisite availability.
- Unparseable AR-I08: AR-I08 changes from Accepted artifact to one document-level InputFailure; raw AR-I08 row count is zero; no fallback row subject.
- Duplicate ownership: provide one HI-11b already represented as a conflict and assert it contributes only `observationConflictRecordCount`, never rejected observation or contract failure.
- Extra/sixth check: fail closed as FT-10 ConservationMismatch; the normalized check array still contains exactly the five registered identities and no caller row.

## 6. Task 1 — SP-07 Dispatch (READY only after amended docs approval; 20–30 minutes)

**Exact files:** the two scripts listed in Section 1.

1. **RED exact AR-S09 row (2–5 min).** Add `-Case DispatchPartitions`; hard-code the base UI row, property order, selector sequence, nullability, and evidence.
2. **Implement pure precedence (2–5 min).** Consume normalized SP-04/SP-05/SP-06 facts; derive status/lane/candidate ID without caller verdicts.
3. **Lane matrix (2–5 min).** Add all exact type sets, unknown/case/unclassified/configuration vectors and fixed aggregate counts.
4. **Selector conservation (2–5 min).** Assert required scalar selectors, dependency/tool selector counts, dedupe, Ordinal ordering, and forbidden-kind rejection.
5. **Suppression/integration (2–5 min).** Feed actual gate failure state; assert zero eligible/rows while retaining earlier diagnostic states.
6. **GREEN/checkpoint (2–5 min).** Run focused, adjacent SP-04/05/06, Integration, AST safety, diff/scope checks; commit independently and stop.

Focused command:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case DispatchPartitions
```

**Stop checkpoint:** do not start Task 2, persistence, SP-09, or C3-C6 without new authorization.

## 7. Task 2 — SP-08 Accounting (BLOCKED pending Task 1 approval; 20–30 minutes)

**Exact files:** the same two scripts. Requires independently approved Task 1 commit.

1. **RED actual-subject registry (2–5 min).** Add `-Case InputAccounting`; hard-code the 22-subject integration vector, identities, parent partitions, and all three equations.
2. **Derive complete sets (2–5 min).** Replace incremental count patching with distinct artifact/raw-row/conflict/check collections and derive every count.
3. **Five checks (2–5 min).** Freeze exact order, prerequisites, Accepted/Failed/NotEvaluated derivation and reject any implicit sixth check.
4. **FT-10/11/15 matrix (2–5 min).** Assert unique ownership, exact AR-S10 shape/evidence, one-check-one-state behavior, and issue/fingerprint effects.
5. **SP-07 coupling (2–5 min).** Evaluate SP-07 only after complete SP-08 state; any failure yields zero dispatch universe, while the amended integration is exact 22/19/2/1/0.
6. **GREEN/checkpoint (2–5 min).** Run every focused case, minimal regression, AST safety, exact scope and forbidden-path checks; commit independently and stop.

Focused command:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case InputAccounting
```

**Stop checkpoint:** SP-09/AR-O01-O05 serialization and atomic publication, AR-S12 persistence, C3-C6, G5, Unity, extraction, import, real assets, and Phase B remain deferred and unauthorized.

## 8. Common Verification

After each authorized Task:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case <new-case>
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case ObjectMergeProjection
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case ConfigurationPartitions
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case CanonicalPartitions
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case Integration
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
git diff --check
git status --short
git diff --name-only
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

Task 2 additionally runs every existing focused case. Both scripts must have zero syntax errors and AST violations for filesystem/process/native/dynamic/Unity/extraction/import operations outside the already-audited adapter/read boundary. Stage only the two explicit scripts; never use `git add .`. Existing untracked `AGENTS.md` and the SP-03/SP-04 plan remain unstaged. Both forbidden paths remain `False`.

## 9. Deferred Work

- AR-O01 through AR-O05 serialization, TEMP staging, validation, atomic publication, rollback/quarantine, and FT-12/SP-09.
- Persistent AR-S12 contract-change component and C0/G5 integration.
- C3-C6 lane consumers and authoring-reuse ledger ownership.
- Unity, extraction, import, real asset access, Phase B, and release packaging.
