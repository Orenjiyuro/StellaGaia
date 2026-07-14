# StellaSora C2 SP-05/SP-06 Minimal Configuration And Canonical Plan

**Date:** 2026-07-14
**Status:** Task 0 implemented in this documentation change, pending read-only approval; Tasks 1/2 not started
**Baseline:** `codex/asset-corpus-integration` at `5829e16be0aac7ad5321e388d51da52a7c6bb0a0`
**Scope:** fixture-only SP-05 configuration candidates/conflicts and SP-06 canonical groups/conflicts. No fixture creation or modification, output persistence, SP-07+, C3-C6, G5, Unity, extraction, import, real assets, or forbidden-path creation.

## 1. Slicing decision

1. **One Task in the existing module/harness:** smallest apparent scope, but combines AR-I09 validation, HI-09, FT-08, HI-10, overlap detection, FT-09, and two public fragments beyond one 20–30 minute Task.
2. **A spec-amendment Task followed by two implementation Tasks (recommended):** Task 0 registers canonical proposal provenance and exact FT-09 ownership; Task 1 implements SP-05; Task 2 implements SP-06 only after Task 0 is separately approved. Each increment stays green.
3. **New module/harness:** stronger isolation, but creates another production boundary before AR-P01 publication exists.

This plan intentionally contains three Tasks because the pre-amendment AR-S02/AR-S05 shapes could not express proposed member sets, target IDs, proposed canonical IDs, overlap, or missing-member inputs. Task 0 supplies that amendment. Execute only one Task per explicit authorization; Task 2 remains blocked until Task 0 is approved and committed.

## 2. Frozen integrated universe

The complete current C1 file set contains one `UnknownInput` file and therefore zero `ConfigurationCandidate` files. AR-I09 is intake-confirmed Absent. The complete SP-04 resolved set contains one object:

```text
assetObjectId=sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11
sourceId=pc-install-primary
containerRelativePath=SourceCorpus/PcInstall/game-data.bundle
pathId=10
classId=1
objectType=Sprite
objectName=Hero
contentFingerprint=1111111111111111111111111111111111111111111111111111111111111111
private configurationDisposition=Parsed
canonicalEvidence=null
memberPlatform=Pc
```

The pathId=20 SP-03b conflict never enters SP-05 or SP-06. Rejected r5 and excluded r6 likewise never enter either universe.

## 3. SP-05 frozen contract

SP-05 subjects are the union of:

- every unique C1 file whose exact `containerKind=ConfigurationCandidate`, identified by HI-09a;
- every SP-04 resolved object whose private resolved `configurationDisposition` is non-null, identified by HI-09b.

Private null maps public `NotConfiguration` but is outside SP-05. No caller-supplied candidate list, disposition, totals, or conflict flag is accepted.

### 3.1 HI-09 and row shapes

HI-09a is prefix/domain `config-sha256:` / `C2ConfigurationFileV1`, scalar order `sourceId`, `relativePath`. HI-09b is the same prefix with domain `C2ConfigurationObjectV1`, scalar `assetObjectId`. The integrated HI-09b is:

```text
config-sha256:68c371737c3abe9a42704d555566590739c8fac1418c72add516070fc853f564
```

Every resolved candidate row is exactly:

```text
configurationCandidateId
targetKind
sourceId
containerRelativePath
assetObjectId
configurationDisposition
observationIds
evidence
```

`targetKind` is `File` or `Object`. File rows have null asset ID; object rows have non-null asset ID. Arrays are distinct Ordinal sets.

Every conflict row is exactly:

```text
configurationConflictId
configurationCandidateId
targetKind
observationIds
conflictingFields
evidence
```

HI-09c uses `C2ConfigurationConflictV1` and ordered fields `configurationCandidateId`, `targetKind`, `observationIds` set, `conflictingFields` set.

### 3.2 Resolution rules and vectors

- An object candidate copies its one SP-03b-resolved non-null disposition, accepted observation IDs, and evidence. SP-03b has already rejected disagreement, so it cannot create an SP-05 conflict.
- A file candidate combines accepted AR-I09 rows targeting its exact C1 identity. Zero rows resolves to `DiscoveredOpaque`, empty observation IDs, and evidence exactly the AR-I02 ledger path.
- One or more file rows resolve only when every `contentFingerprint` and `configurationDisposition` is exact-equal. Observation IDs/evidence union Ordinally.
- Any disagreement produces exactly one HI-09c/FT-08 and no resolved candidate.
- Unknown target, unsafe path, malformed document/row, bad HI-07, duplicate ID, or invalid disposition follows the existing FT-04/FT-05 ownership rules before SP-05.

The spec P1 pure vector and current integration vector are distinct authorities, not competing revisions:

- **P1 pure contract vector:** inject the spec-defined synthetic `fConfig` (`Config/table.json`, ConfigurationCandidate, 8 bytes, SHA 64 `5`, both extraction fields NotAttempted) plus `oResolved`; it must yield `2=2+0`, with fConfig DiscoveredOpaque when AR-I09 is Absent and oResolved Parsed.
- **Current audited integration vector:** actual AR-I02 has no fConfig and AR-I09 is Absent; it yields only oResolved and `1=1+0`. This does not amend or replace the spec P1 vector.

The exact synthetic-present AR-I09 positive is an in-memory AR-S04 document, UTF-8/no BOM/LF/final LF/two spaces, 1314 bytes, raw SHA `2fd0911f90c3c210d475db07e936995de9607e11542f8d27044ad1f381f6d919`. It has two rows in index order:

| index | ID | tool | path | content | disposition | observation | evidence |
|---:|---|---|---|---|---|---|---|
| 0 | `configuration-observation-sha256:e2eb4fc64d6e829aba513b46c3b236db1a046d8a859d067d37d9c4360fb5fda7` | ToolA/1.0.0 | `Config/table.json` | 64 `6` | Parsed | `parsed` | `.../toola-config.json` |
| 1 | `configuration-observation-sha256:33534e491e7ab8fe3912abbb3e9f2f8a7bb20af6b5962896b5d77387088f12e1` | ToolB/1.0.0 | `Config/table.json` | 64 `6` | Parsed | `parsed` | `.../toolb-config.json` |

The exact HI-09a is `config-sha256:af9d767ba7fa499898dbfb3315e54f9de3cc5dba438a6c0367619da6b3684b79`. Row shape/order is `configurationObservationId,toolName,toolVersion,sourceId,relativePath,contentFingerprint,configurationDisposition,observation,evidence`. Tests must hard-code these IDs/SHA/bytes and independently assert row indexes; they may not derive expected values with production helpers.

Conflict vectors mutate one field in row 1 and recompute that document's raw SHA, HI-07 and HI-02 before implementation begins: content conflict freezes `conflictingFields=[contentFingerprint]`; disposition conflict freezes `[configurationDisposition]`; both use the same HI-09a candidate, exact two observation IDs/evidence, one HI-09c, one FT-08 AR-S10 record, and no candidate row. The RED commit must contain the literal mutated raw SHA, IDs, conflict ID and accounting recordId. A missing literal is a plan-gate failure, not work deferred to GREEN. Malformed-row vectors use the mutated artifact SHA plus original row index in HI-02; unparseable-document ownership is AR-I09 only.

Integrated conservation is:

```text
configurationDiscoverySubjectCount=1
configurationCandidateCount=1
configurationConflictCount=0
1=1+0
parsedConfigurationCount=1
discoveredOpaqueConfigurationCount=0
encryptedConfigurationCount=0
requiresRuntimeTypeConfigurationCount=0
likelyServerDependentConfigurationCount=0
notConfigurationCount=0
resolved six-state sum=1
```

The integrated candidate is target `Object`, the frozen HI-09b, disposition `Parsed`, observation IDs r1+r2 Ordinal-sorted, and evidence r1/r2 Ordinal-sorted.

## 4. SP-06 frozen contract

Every SP-04 object is exactly one SP-06 subject: `Canonicalized` or `CanonicalConflict`.

Canonical group row shape is exactly:

```text
canonicalAssetId
memberObjectIds
matchStatus
platformScope
equivalenceFingerprint
variantEvidence
```

Canonical conflict row shape is exactly:

```text
canonicalConflictId
proposedCanonicalAssetIds
memberObjectIds
observationIds
conflictingFields
evidence
```

### 4.1 Grouping rules

- Null canonical evidence deterministically creates one-member `Unresolved`; `canonicalAssetId` is the object ID itself, `platformScope` is the member platform, equivalence fingerprint is null, and variant evidence is empty.
- `ExactDuplicate` requires at least two distinct objects, one exact non-null equivalence fingerprint, identical content fingerprint, and agreement from every member proposal. HI-10a uses `C2CanonicalGroupV1`.
- `ConfirmedVariant` requires at least one Pc and one Android member, distinct content fingerprints, one exact equivalence fingerprint, and nonempty variant evidence. Its equivalence fingerprint is independently recomputed with `C2VariantEquivalenceV1` over the distinct Ordinal content-fingerprint set.
- An object may occur in one canonical group only. Overlapping proposals, inconsistent member sets/status/platform/equivalence evidence, duplicate proposed groups, or proposal targeting a missing/conflicted object produce one or more exact HI-10c/FT-09 subjects under unique ownership; no affected public object receives a canonical ID.
- Null evidence is never heuristically grouped with another object.

The pre-amendment input could express only the integrated null-evidence Unresolved vector. Task 0 now amends the spec: AR-S02 canonical evidence carries nullable proposed canonical ID and member IDs; amended HI-04 binds them; AR-S05 carries `canonicalProposalProvenance`; HI-10d binds each accepted observation/HI-04 proposal. These fields never enter `resolvedValues` and provenance rows are not extra SP-08 subjects.

The spec's SP-06 provenance subregistry freezes ExactDuplicate A/B and ConfirmedVariant inputs, exact HI-10b, all three HI-10a IDs, six HI-10c IDs, and six FT-09 AR-S10 recordIds. Those literal values—not production helpers—are the focused-test oracle. Until this amendment is approved, Task 2 may implement nothing; even Unresolved waits so one coherent model is reviewed.

Integrated conservation is:

```text
enumeratedObjectCount=1
canonicalizedObjectCount=1
canonicalConflictObjectCount=0
1=1+0
canonicalGroupCount=1
exactDuplicateGroupCount=0
platformVariantGroupCount=0
unresolvedCanonicalGroupCount=1
1=0+0+1
```

The integrated group is exactly:

```text
canonicalAssetId=sha256:1770763b64b209f9a6e8da91770278c9eba4cd4d3253145dd0dcd2a68abd7f11
memberObjectIds=[the same object ID]
matchStatus=Unresolved
platformScope=Pc
equivalenceFingerprint=null
variantEvidence=[]
```

SP-06 is the sole producer of public `canonicalAssetId`. It joins by exact `assetObjectId`; it never changes SP-04 `platformVariant`.

## 5. Pure result and failure/suppression contract

Extend the existing normalized result without changing existing field order; append after `publicObjectCores`:

```text
configurationCandidates
configurationConflicts
canonicalGroups
canonicalConflicts
publicObjectsWithCanonicalId
```

The pure input extends only with parsed in-memory `c1Files`, `fileConfigurationArtifact` (`artifactPath`, `artifactSha256`, `documentReadStatus`, `document`), and—only after Task 0 approval—the registered `canonicalProposalProvenance`. AR-I09 Absent is explicit and carries null SHA/document. No reader, callback, script block, process object, final partition, or count is accepted.

`publicObjectsWithCanonicalId` omits every object affected by a canonical conflict and never emits a null canonical ID. Independent earlier failures do not erase an otherwise evaluable normalized join; the diagnostic state retains it while AR-O01 publication remains suppressed. On a conflict-free normalized derivation it has the complete AR-S06 object row shape/order:

```text
assetObjectId
canonicalAssetId
sourceId
objectType
objectName
containerRelativePath
classId
serializedSizeBytes
dependencyObjectIds
toolObservations
platformVariant
configurationDisposition
evidence
status
```

The integrated positive row equals the current SP-04 public core field-for-field, inserts the frozen object ID as `canonicalAssetId` immediately after `assetObjectId`, and contains no private `sp04Partition`. Failure never emits a row with null canonical ID.

Coverage appends exactly:

```text
configurationDiscoverySubjectCount
configurationCandidateCount
configurationConflictCount
parsedConfigurationCount
discoveredOpaqueConfigurationCount
encryptedConfigurationCount
requiresRuntimeTypeConfigurationCount
likelyServerDependentConfigurationCount
notConfigurationCount
canonicalizedObjectCount
canonicalConflictObjectCount
canonicalGroupCount
exactDuplicateGroupCount
platformVariantGroupCount
unresolvedCanonicalGroupCount
```

FT-08/FT-09 each create one AR-S10 row per derived conflict identity, add one SP-08 subject/failure/issue, suppress D9 and every public output, and preserve all independent actual states. Conflict subjects never also produce resolved candidates/groups. On the current integrated fixture, pre-existing r5 and FT-07 still make the overall gate Failed; SP-05/SP-06 positive normalized rows must nevertheless be derived and retained as diagnostic state because their prerequisites exist.

## 6. Task 0 — Register Canonical Proposal Provenance (20–30 minutes)

**Exact files:** modify only the C2 spec and this plan. No scripts or fixtures.

### Steps

1. **Completed:** selected expanded AR-S02 evidence + separate AR-S05 provenance over an unbound sidecar or illegal `resolvedValues` extension.
2. **Completed:** registered exact recursive shapes, HI-04 V2, HI-10d, ordering, duplicate rules, and non-subject status.
3. **Completed:** froze ExactDuplicate A/B and ConfirmedVariant inputs plus exact HI-10a/HI-10b.
4. **Completed:** froze six FT-09 inputs, HI-10c ownership/evidence, and exact AR-S10 recordIds.
5. **Completed:** froze `publicObjectsWithCanonicalId` success/failure join.
6. **Current checkpoint:** run doc consistency/diff checks, commit only these two docs, and stop for read-only approval.

**Stop checkpoint:** commit approved documentation independently. Task 2 remains blocked until this checkpoint is approved.

## 7. Task 1 — SP-05 Configuration Partition (20–30 minutes)

**Exact files:** modify only:

- `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`
- `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`

### Steps

1. **RED: exact integrated object candidate (2–5 min).** Add `-Case ConfigurationPartitions`; assert frozen HI-09b, row shape, r1/r2 sets, and 1=1+0/six-state conservation.
2. **Implement pure object/file universes (2–5 min).** Derive subjects from complete C1/SP-04 sets and reject caller totals/final states.
3. **AR-I09/HI-07 vectors (2–5 min).** Cover Absent, zero rows, agreement, exact identity, malformed row/document, unsafe/unknown target.
4. **HI-09c/FT-08 (2–5 min).** Cover both conflict classes, exact row/accounting identity, unique owner, and no resolved conflict row.
5. **Production integration (2–5 min).** Feed audited AR-I09 absence and actual SP-04 result; merge real SP-08/O1/O2 counts without fixed templates.
6. **GREEN/checkpoint (2–5 min).** Run all focused cases, minimal regression, AST safety, and exact scope checks.

**Focused command:**

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case ConfigurationPartitions
```

**Stop checkpoint:** commit Task 1 independently and stop. Do not start Task 2 without new authorization.

## 8. Task 2 — SP-06 Canonical Partition (20–30 minutes)

**Exact files:** modify only the same two scripts. No fixture or document changes.

### Steps

1. **RED: integrated Unresolved (2–5 min).** Add `-Case CanonicalPartitions`; assert exact one-member group, self canonical ID, null equivalence, and 1=1+0 / 1=0+0+1.
2. **Implement HI-10a groups (2–5 min).** Derive Unresolved, ExactDuplicate, and ConfirmedVariant with exact set ordering and independent variant digest.
3. **Conflict matrix (2–5 min).** Freeze overlaps, missing member, same-platform/content invalid variants, mismatched equivalence, and duplicate proposals.
4. **HI-10c/FT-09 (2–5 min).** Assert exact conflict/accounting shapes, stable IDs, unique ownership, and no canonical projection for affected objects.
5. **Public join/integration (2–5 min).** Join canonical IDs by object ID only; preserve platform/status; derive actual SP-08/O1/O2 counts and suppression.
6. **GREEN/checkpoint (2–5 min).** Run complete regressions, AST safety, and exact scope checks.

**Focused command:**

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case CanonicalPartitions
```

**Stop checkpoint:** commit Task 2 independently and stop. SP-07+, publication, Unity, extraction, real assets, C3-C6, G5, and Phase B remain unauthorized.

## 9. Common verification

After each authorized Task run every existing focused case, the new case, and:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
git diff --check
git status --short
git diff --name-only
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

Both scripts must parse with zero syntax errors and the pure path AST audit must report zero filesystem/process/native/dynamic/Unity/extraction/import violations. Stage only the two exact scripts with explicit paths; never use `git add .`. `AGENTS.md` and plan documents remain unstaged unless separately authorized. Both forbidden paths remain `False`.

This plan is the only authorized change now. Submit it uncommitted for read-only review and do not execute Task 1 until approved.
