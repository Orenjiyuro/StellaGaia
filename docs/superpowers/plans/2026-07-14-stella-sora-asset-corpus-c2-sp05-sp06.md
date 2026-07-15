# StellaSora C2 SP-05/SP-06 Minimal Configuration And Canonical Plan

**Date:** 2026-07-14
**Status:** Task 0 superseded by Task 0B; Task 0B complete; Task 1/SP-05 implementation exists but its mutation oracle is BLOCKED pending Task 0C approval; Task 2/SP-06 implementation at `bd3b519` is under corrective review
**Baseline:** `codex/asset-corpus-integration` at `bd3b51980b683c1679f643ccf7243de707dc49e4`
**Scope:** fixture-only SP-05 configuration candidates/conflicts and SP-06 canonical groups/conflicts. No fixture creation or modification, output persistence, SP-07+, C3-C6, G5, Unity, extraction, import, real assets, or forbidden-path creation.

## 1. Slicing decision

1. **One Task in the existing module/harness:** smallest apparent scope, but combines AR-I09 validation, HI-09, FT-08, HI-10, overlap detection, FT-09, and two public fragments beyond one 20–30 minute Task.
2. **A spec-amendment Task followed by two implementation Tasks (recommended):** superseding Task 0B registers complete canonical proposal provenance and exact FT-05/09/10 ownership; Task 1 implemented SP-05; Task 2 implements SP-06 only after Task 0B is separately approved. Each increment stays green.
3. **New module/harness:** stronger isolation, but creates another production boundary before AR-P01 publication exists.

This plan contains sequential documentation and implementation Tasks because the pre-amendment AR-S05 shape could not carry the resolved/missing member facts required by SP-06. The original Task 0 amendment is superseded by Task 0B, which closes that provenance model. Execute only one Task per explicit authorization; Task 2 remains blocked until Task 0B is independently approved and committed.

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

The exact synthetic-present AR-I09 positive is an in-memory AR-S04 document serialized by CT-15 with top-level property order `schemaVersion,snapshotId,inputFingerprint,rows`, values `schemaVersion=1.0.0`, `snapshotId=snapshot-pc-install-001`, `inputFingerprint=` plus 64 lowercase `a` digits, and the two complete rows below. Its evidence paths are exactly `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-config.json` and `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-config.json`; the ellipses in the display table are descriptive only and never serialized. The exact UTF-8/no-BOM/LF/final-LF/two-space document is 1346 bytes with raw SHA `2dbc475a471bf96dc3c4aae3dcc51e3dd9571a33048d81104085e7ba0e84b9ae`. It has two rows in index order:

| index | ID | tool | path | content | disposition | observation | evidence |
|---:|---|---|---|---|---|---|---|
| 0 | `configuration-observation-sha256:e2eb4fc64d6e829aba513b46c3b236db1a046d8a859d067d37d9c4360fb5fda7` | ToolA/1.0.0 | `Config/table.json` | 64 `6` | Parsed | `parsed` | `.../toola-config.json` |
| 1 | `configuration-observation-sha256:33534e491e7ab8fe3912abbb3e9f2f8a7bb20af6b5962896b5d77387088f12e1` | ToolB/1.0.0 | `Config/table.json` | 64 `6` | Parsed | `parsed` | `.../toolb-config.json` |

The exact HI-09a is `config-sha256:af9d767ba7fa499898dbfb3315e54f9de3cc5dba438a6c0367619da6b3684b79`. Row shape/order is `configurationObservationId,toolName,toolVersion,sourceId,relativePath,contentFingerprint,configurationDisposition,observation,evidence`. Tests must hard-code these IDs/SHA/bytes and independently assert row indexes; they may not derive expected values with production helpers.

Every mutation below starts from that complete document, changes only the named row/value, recomputes HI-07 where its inputs remain valid, and serializes the complete mutated document with the same CT-15 rules. These literals are the harness oracle:

| vector | complete rows | bytes | raw SHA | mutated HI-07 | fallback HI-02 |
| --- | --- | ---: | --- | --- | --- |
| disposition conflict | positive row 0; row 1 disposition `Encrypted` | 1349 | `1058a874db6f283672a6595682a018c17fb1185ff6843d656473ca259231e165` | `configuration-observation-sha256:19ac3011970cff65467f033a22e5fb9873f2e259c6ea816317e4876902973cd4` | not applicable |
| content conflict | positive row 0; row 1 content 64 `7` | 1346 | `3c43c5f8709da8cac30ee15bdc84ec65c93daa772c49ac93deaf9cf71f9a2d0f` | `configuration-observation-sha256:dd1567900d725f6ce195a4c37f5e5dc21a1278f019725580d5bbe27684682693` | not applicable |
| duplicate HI-07 | positive ToolA row repeated at indexes 0 and 1 | 1346 | `752b799d2ca83cb65b8a067be5bc6d817fe735b5df43e89f693ba4ebde1e4e74` | repeated `configuration-observation-sha256:e2eb4fc64d6e829aba513b46c3b236db1a046d8a859d067d37d9c4360fb5fda7` | index 1 `raw-row-sha256:058e1ab88a89586e6daa7262da730d590f85e92603887631ea72d719b9499594` |
| unsafe path | one ToolA row, path `../table.json` | 762 | `e8e53522bf81a244b1027138cf20dd6267b3a2aa9b8ffcc0bfdbb0c22781d01a` | `configuration-observation-sha256:9d05b726a24cc38298bb2cb652ed32fdb5c64d6172fe4814364103b2e3055fcd` (identity appearance only; row is FT-04) | index 0 `raw-row-sha256:0dbbeb3bda4452f411a2e5d3481caea585364d67fe462afd4898b80303ef0c16` |
| unknown target | one ToolA row, path `Config/missing.json` | 768 | `e93104b7230ddb08651aa74152c62a191b2cf568a42f9d44511798438a999225` | `configuration-observation-sha256:9dc8c86e5eed69f4a33a9114509c02966867c8921ccf21a99633da84acd67648` | index 0 `raw-row-sha256:7cf682a99940cf6234adde0690056efa044a04b2dac2dc20f0359450c24cce11` |
| malformed row | one ToolA positive row with `toolName=""`; stored HI-07 remains the positive literal and is not recomputed | 761 | `e413a953c7b5947efb283f3e802a9f3c552f3376e4d7b8b57ef4fbf290875be1` | invalid/not derivable | index 0 `raw-row-sha256:2e113d54ada29b0d8c19d6468e9fdba1f1a67b2de9267caa7890bc10afca3ac5` |

Disposition/content conflicts use the frozen HI-09a candidate, exact two observation IDs/evidence, one HI-09c, one FT-08 AR-S10 record, and no file candidate. Duplicate, unsafe, unknown-target, and malformed-row vectors must pass their exact mutated raw SHA into the pure input and assert the listed HI-02; using the positive document SHA is a test failure. Unparseable-document ownership remains AR-I09 only.

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
- An object may occur in one canonical group only. Overlapping different proposed groups, inconsistent member sets/status/platform/equivalence evidence, or proposal targeting a missing/conflicted object produce one or more exact HI-10c/FT-09 subjects under unique ownership; no affected public object receives a canonical ID. Different observations expressing the same exact group are required agreement, not duplicates.
- Null evidence is never heuristically grouped with another object.

The pre-amendment input could express only the integrated null-evidence Unresolved vector. Task 0B freezes AR-S05 `canonicalProposalProvenance` as exactly `proposalId,observationId,canonicalEvidenceId,proposedCanonicalAssetId,matchStatus,platformScope,equivalenceFingerprint,memberObjectIds,memberFacts,missingMemberObjectIds,evidence`. A `memberFacts` row is exactly `assetObjectId,memberPlatform,contentFingerprint`. These fields never enter `resolvedValues`; provenance rows are not extra SP-08 subjects.

`memberFacts` and `missingMemberObjectIds` are disjoint, Ordinal-sorted, exhaustive partitions of `memberObjectIds`; count conservation is `memberObjectIds.Count = memberFacts.Count + missingMemberObjectIds.Count`. Nonempty missing IDs force `platformScope=Unknown`; otherwise scope derives from the complete fact set. Every accepted non-null canonical-evidence observation has exactly one provenance row and every such row maps back to exactly one such observation. Missing/multiple rows or duplicate `proposalId` are one FT-10 Conservation failure. Raw canonical-evidence shape/HI failure is FT-05. Missing members, overlap, and status/scope/content/equivalence contradictions after a valid one-to-one join are FT-09.

HI-10d V2 is `canonical-proposal-sha256:` / `C2CanonicalProposalV2`, with field order `observationId`, `canonicalEvidenceId`, nullable `proposedCanonicalAssetId`, `matchStatus`, `platformScope`, nullable `equivalenceFingerprint`, `memberObjectIds` set, `memberFacts` nested list, `missingMemberObjectIds` set, `evidence` set. Each nested item is the complete UTF-8/no-BOM `C2CanonicalMemberFactV1` record with `assetObjectId`, `memberPlatform`, `contentFingerprint`, sorted by decoded asset ID and length-framed under `memberFacts[index]`. The spec's literal tables are the focused-test oracle. Until Task 0B is approved, Task 2 may implement nothing; even Unresolved waits so one coherent model is reviewed.

Task 0B from-zero literals are frozen as follows:

| vector | HI-10a/10b | e HI-04 / HI-10d V2 | f HI-04 / HI-10d V2 |
|---|---|---|---|
| ExactDuplicate A | `canonical-sha256:843086f47eb4de699ad9d586f4692993fb1bbe0f68b1487b32aa1cd5b7eeff3c` | `canonical-evidence-sha256:db79daf694e7124465b9ab59f11e5c83099708887ccbb8165d4082d96f72b635` / `canonical-proposal-sha256:3e94ad5cd6c7dfbc0b844c4cc9d6a45c89cb743a90f3fd613ac861b6f9cf075e` | `canonical-evidence-sha256:84d251cfa1e7737a37cfba8044aa0a9b5b6ae445d006486f6085e27bdaf1b6d3` / `canonical-proposal-sha256:07596af8c1ccced882613599bf6b2f4e47efa7baed7e8b5a96bbfaa8001e83ee` |
| ConfirmedVariant | HI-10b `1bbf97948d5f9111ae0e5000a7420a367632e52f434c9cdf15ecae33dfa5bbe1`; HI-10a `canonical-sha256:0daa9f57bb5628818d732ec67ff39f74839a47a4a668c0465bd6f4f0a7e0dc85` | `canonical-evidence-sha256:8f15fd3e611ba21a1edcd7dbde908459200c3b6cdde21010da9f2b41bbe507e2` / `canonical-proposal-sha256:bcfd8bd495f025e7499ca30ab49c5026030b47b6ebf4826dd46fb629ccaf56f6` | `canonical-evidence-sha256:144a9217b5fdd1b299e9ad4adb69296ba8ac7eb001eb837bf4dc8c9dc2418fcc` / `canonical-proposal-sha256:66cae93bc4f8b1c7abc575cd7a771928a693fed0498b75ba2abb05f656f514f7` |

Overlap B HI-10a is `canonical-sha256:0942c13e4665a597883b01a50826348ce4443e1cbe3c676d74c24ab81c3a4ad3`; B/f HI-04/HI-10d are `canonical-evidence-sha256:e879808a21e1683270df2417aba026e455f6ec5c1b16f5f58f7aed3ffb3eee16` / `canonical-proposal-sha256:966b0d84c34ecfde8c42c64f892601d3f6ec44e8c0530cf0c935fc4f8f2b73d5`. Missing-b/e has fact a, missing b, `platformScope=Unknown`, raw proposed A, Unknown-scope HI-10a `canonical-sha256:2deebf8783219024da05851d8e639a2f9a2b5a3b944c96d8187ab7c8b0e441c8`, HI-10d `canonical-proposal-sha256:24f936f959f9cff908eaf79b2159bcf55e5879be3a2a1e276c9d3c123bde9cc6`, and one FT-09 subject owning both missing-member and proposed-ID mismatch.

FT-09 conflict/accounting pairs are overlap `6d27bbe91cbcdcf600269fa6e7f9f8566c47bb072bb389948352908de8b5df84` / `b96c96d4eb5a03e06798d939a37b102dac4a578495f2c4fb1275078e6ef58a77`; missing `2bdbd0bd8082a99d1665216df74581f06dc752254bb03f63c5262650c807b499` / `14cf5beeae126026d50ebbde74287d6df7da711a44570affbbc589dc2eda7fc8`; status `781d9a95c17b2b13e3d7dc238cbc8e617f6eb3c0055cdbcdef7024d7f9aa67b5` / `3a270d9e610aa9ebe108a56d5c58ce3f284e7f70ad6e2e6d207b7d2f39c1b5bc`; scope `cb87382ad9e3e0c4df42bc295b042face94d7c73219cc8165e63279504f29776` / `2a5ab596f6edacec595bea75857596b7e850dfe5cf2c98841bc71800b035506f`; same-platform `b45a6162ea16bda2d7c717d451de5c565296b9ce16edb676930a9b4e16b9b694` / `a2f3cf79107d4422fd7f75bddcad234e5d079a03f8a52f99ea970736ae7bc103`; same-content `bffc1ab94aa94f182dbae0e02c4a6eb1edd3e2cdce821390df9ab315131c6a12` / `0ca4f829ad7b7e71132e055f329c1f6351b2fb934d09cce992a6de1f73928c89`; bad-equivalence `36e974feaf687441fdcd12bede62c5461ad3ce2b3cf843a40858279c5a2f1cbe` / `7c5158ff25a6da20c94656196b201a0a07044865c4e3b33ccfa8612a452c33b7`; wrong-proposed-ID `9e90ab6ccc6053632f98f1394ee626344ccc5d40206975ba84c66528397e3d22` / `5022d9b9231dfa748eefb232045b00ae209148748e5d2d44c54085c06fbf0dda`, with the respective `canonical-conflict-sha256:` / `accounting-sha256:` prefixes. Status mismatch changes only f `matchStatus=ExactDuplicate`; scope mismatch changes only f provenance `platformScope=PcOnly`; all other fields remain the ConfirmedVariant positive values. Repeating e's exact provenance row is the sole duplicate counterexample and produces FT-10 record `accounting-sha256:99b22592adff48c273bdc79844085fdd2052dc5bc18766d8a6d8249cb7967985`, not HI-10c/FT-09.

Positive/conflict disjointness is structural: A/e+A/f have the same proposed ID, exact-equal status/scope/equivalence/member IDs/member facts, empty missing sets, and distinct observation/proposal IDs, so they form one ExactDuplicate group. Overlap introduces different A/B proposed IDs sharing b; missing introduces a nonempty missing set; each variant mismatch changes exactly its named member-fact/equivalence predicate. None of those negative sets equals either positive set. The duplicate-provenance set repeats e's identical proposal and observation IDs and is rejected by FT-10 before SP-06, so it cannot also produce FT-09.

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

The pure input extends only with parsed in-memory `c1Files`, `fileConfigurationArtifact` (`artifactPath`, `artifactSha256`, `documentReadStatus`, `document`), and—only after Task 0B approval—the registered `canonicalProposalProvenance`. AR-I09 Absent is explicit and carries null SHA/document. No reader, callback, script block, process object, final partition, or count is accepted.

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

## 6. Task 0 — Register Canonical Proposal Provenance (Superseded by Task 0B)

**Exact files:** modify only the C2 spec and this plan. No scripts or fixtures.

### Steps

The original amendment omitted resolved/missing member facts and incorrectly treated two observations agreeing on one ExactDuplicate proposal as a duplicate conflict. Its HI-10d V1 and duplicateProposal FT-09 literals are obsolete and must not be implemented.

## 6A. Task 0B — Close Canonical Proposal Provenance (20–30 minutes)

**Exact files:** this C2 spec and this plan only.

1. Register the complete provenance/memberFacts shape and exhaustive member conservation.
2. Upgrade HI-10d to V2 with directly nested member-fact records.
3. Freeze one-to-one production conservation and FT-05/09/10 ownership.
4. Recompute every positive and negative literal from zero; prove A/e+A/f agreement is disjoint from all conflicts.
5. Commit the two documents and stop for read-only approval.

**Stop checkpoint:** Task 2 remains BLOCKED until Task 0B is independently approved.

## 6B. Task 0C — Close AR-I09 Mutation Byte Authority (docs-only)

**Exact file:** this plan only. No scripts, fixtures, schemas, or specs.

Task 0C replaces the unreproducible 1314-byte positive claim with the complete CT-15 document identity and freezes every mutation's byte count, raw SHA, HI-07, and applicable HI-02 in Section 3.2. It does not change AR-S04, HI-02, HI-07, HI-09, FT-04, FT-05, or FT-08 semantics. After independent approval, the existing SP-05 harness must use these literals and may not reuse the positive artifact SHA for a mutated document.

**Stop checkpoint:** commit this document alone and stop for read-only review; do not resume implementation corrections in the same Task.

## 7. Task 1 — SP-05 Configuration Partition (Complete at `12e89c8`)

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

## 8. Task 2 — SP-06 Canonical Partition (BLOCKED pending Task 0B approval; 20–30 minutes after approval)

**Exact files:** modify only the same two scripts. No fixture or document changes.

### Steps

1. **RED: integrated Unresolved (2–5 min).** Add `-Case CanonicalPartitions`; assert exact one-member group, self canonical ID, null equivalence, and 1=1+0 / 1=0+0+1.
2. **Implement HI-10a groups (2–5 min).** Derive Unresolved, ExactDuplicate, and ConfirmedVariant with exact set ordering and independent variant digest.
3. **Conservation/conflict matrix (2–5 min).** Assert duplicate/missing/multiple provenance ownership by FT-10 before grouping; then freeze overlap, missing member, status/scope/platform/content/equivalence/proposed-ID mismatches under FT-09.
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

Both scripts must parse with zero syntax errors and the pure path AST audit must report zero filesystem/process/native/dynamic/Unity/extraction/import violations. Stage only the currently authorized exact files with explicit paths; never use `git add .`. `AGENTS.md` and unrelated plan documents remain unstaged unless separately authorized. Both forbidden paths remain `False`.

Task 0C is the only authorized change now. Commit exactly this plan and stop for read-only review; do not resume SP-05/SP-06 implementation corrections until Task 0C is separately approved.
