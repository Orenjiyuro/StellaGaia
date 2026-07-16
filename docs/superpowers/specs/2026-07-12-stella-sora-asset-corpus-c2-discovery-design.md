# StellaSora Asset Corpus C2 Discovery Design

**Date:** 2026-07-12
**Status:** SP-01 through SP-08 implemented through `c40a6b7fe1dc8368945d9fc802c166fa12c9d587`; SP-09 implementation is BLOCKED pending approval of the publication amendment and plan
**Authority order:** repository `AGENTS.md`, the 2026-07-10 corpus design, C0 contracts, C1 handoff, then this C2 spec

## Scope And Authorization

C2 Phase A freezes G2 object/configuration discovery contracts using committed fixtures and temporary synthetic data. It must not read machine-local game roots, run extraction tools, create repository `Extracted`, start Unity, import assets, or authorize Phase B.

The overall order is C2 Phase A, C3-C6 Phase A, C0 Phase A integration/G5, then a separate human Phase B authorization request. C1 Phase B is not the next overall action. A first real C1 capture remains `Stop`.

The three registries below are the only authoritative definitions. Later explanatory sections only reference registry row IDs and may not redefine shapes, partitions, formulas, or failure behavior.

---

## Central Definition 1: Artifact Registry

### Registry index

| ID | Role | Portable path | Producer | Consumers | Success/failure rule |
| --- | --- | --- | --- | --- | --- |
| AR-I01 | Input | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json` | C1 | C2 intake | Required; failure follows FT-01 |
| AR-I02 | Input | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c1-source-corpus-ledger.json` | C1 | C2 intake/projection | Required; failure follows FT-01/02 |
| AR-I03 | Input | `Tools/AssetImport/Fixtures/SourceCorpusGate/valid-source-corpus-summary.json` | C1 | C2 freshness/conservation | Required; failure follows FT-01/03 |
| AR-I04 | Input schema | `docs/asset-migration/schemas/source-corpus-ledger.schema.json` | C0 | C2 public projection | Required exact bytes; failure follows FT-02 |
| AR-I05 | Input vocabulary | `docs/asset-migration/schemas/status-vocabulary.json` | C0 | All C2 validators | Required exact bytes; failure follows FT-02 |
| AR-I06 | Input schema | `docs/asset-migration/schemas/root-gate-summary.schema.json` | C0 | G5 projection check | Required exact bytes; failure follows FT-02/11 |
| AR-I07 | Optional run input | `Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json` | C2 fixture author | SP-03/SP-04 | Omitted means empty set; if present exact AR-S02 shape |
| AR-I08 | Optional run input | `Tools/AssetImport/Fixtures/DiscoveryGate/file-discovery-observations.json` | C2 fixture author | SP-02 | Omitted means empty set; if present exact AR-S03 shape |
| AR-I09 | Optional run input | `Tools/AssetImport/Fixtures/DiscoveryGate/file-configuration-observations.json` | C2 fixture author | SP-05 | Omitted means empty set; if present exact AR-S04 shape |
| AR-I10 | Conditional expected-input manifest | `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json` | reviewed C2 fixture commit | C2 freshness | Required iff any AR-I07-I09 or AR-I11 is present; exact AR-S04a shape; expected manifest bytes come from the same Git commit blob |
| AR-I11 | Conditional exclusion approvals | `Tools/AssetImport/Fixtures/DiscoveryGate/approved-discovery-input-exclusions.json` | human-reviewed C2 fixture commit | FT-14/SP-03a | Required iff any raw observation is excluded; exact AR-S04b shape; binds every approval to the exact AR-I07 blob and approved HI-03 subject |
| AR-P01 | Private intermediate | TEMP only; never committed as output | C2 intake | All validators | Exact AR-S05 shape; deleted in `finally` |
| AR-O01 | Public output | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json` | C2 projection | C3-C6, C0 | Written only on Passed; otherwise suppressed |
| AR-O02 | Private output | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json` | SP-05 | C3-C6, summary | Written only on Passed; otherwise suppressed |
| AR-O03 | Private output | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json` | SP-06 | C3-C6, summary | Written only on Passed; otherwise suppressed |
| AR-O04 | Private output | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json` | SP-07 | C3-C6 | Written only on Passed; otherwise suppressed |
| AR-O05 | Diagnostic output | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json`; `valid-discovery-report.md`; `valid-discovery-evidence.json`; `c0-contract-change-request.json` in the same directory | C2 gate | Humans, acquisition gate, C0 | Atomic quadruple; every run must attempt it; atomic failure follows FT-12; never authorizes downstream when Failed |

### Existing-input byte registry

These SHA-256 values are over exact repository file bytes as of this design commit. A mismatch is FT-03, not an invitation to update expected values silently.

| ID | SHA-256 |
| --- | --- |
| AR-I01 | `548803c8dc13e4538008207b5e8f0ecb37620bd65d26056d47f9a35616f97bac` |
| AR-I02 | `acb47d05af73235baa6cb3ceccc8639287b8cf38a907292fc0281e7a189db462` |
| AR-I03 | `c626562bc0e5b13d11417d407deb53eb403496b3953faa131f38aafcc50215e1` |
| AR-I04 | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| AR-I05 | `421f00383bde66256b15d71e65b8789c5e8d8474422a376efd441054c798ff47` |
| AR-I06 | `45a094d25b2e221f46f4f4948c0dae188d3a9a77aa520243f02fd8242038c449` |

AR-I07 through AR-I09 and AR-I11 have no self-asserted expected SHA. When any is present, AR-I10 is mandatory and its expected bytes are read from the exact commit OID frozen at run start; an absent/untracked manifest or worktree bytes differing from that commit blob is FT-03. Each present optional input must be a blob in that same commit and must match both its AR-I10 entry and its exact commit-blob SHA-256. AR-I10 must list every and only the present AR-I07-I09 and AR-I11 paths. The producer must re-resolve HEAD at run end and require the same commit OID; a changed HEAD is FT-03 and suppresses every output. Thus the committed reviewed manifest is the external freshness authority; a file cannot bless its own just-read bytes.

### Complete shapes

All JSON objects reject additional properties. All arrays preserve declared order; sets use the Hash Registry ordering rule. Every field below uses the Common Type/Vocabulary Registry; no untyped value is permitted.

For every artifact, stable artifact identity is its registry ID plus exact portable path; moving a file creates a different artifact identity. Single-file content fingerprint is CT-04 SHA-256 over exact bytes. Multi-file AR-O05 content fingerprint is HI-14 over its four component path/SHA entries. Every JSON artifact has CT-01 schemaVersion unless a committed C0 schema document defines its own JSON-Schema version fields.

### Common Type/Vocabulary Registry

| ID | Definition |
| --- | --- |
| CT-01 | `schemaVersion` is exactly string `1.0.0`. |
| CT-02 | identity/name/reason/attribution/operation strings are nonempty UTF-8 scalar strings with no NUL/CR/LF; `operationIdentity` is exactly `C2.DiscoveryCoverage.FixtureValidation`. |
| CT-03 | input timestamp is valid ISO-8601 text with `Z` or explicit offset; C2-created `generatedAt` is UTC text ending `Z`, with one run-level value. Copied C1 `capturedAt` retains its exact accepted input text. |
| CT-04 | SHA-256 is exactly 64 lowercase hex; content fingerprint hashes exact content bytes. |
| CT-05 | portable path is nonempty, repository-relative, slash-normalized, non-URI, no root/dot segments; path sets are OrdinalIgnoreCase unique and Ordinal sorted. |
| CT-06 | count is a nonnegative 32-bit integer; byte count is a nonnegative 64-bit integer; class ID is nonnegative 32-bit; path ID is invariant signed-64-bit decimal text. |
| CT-07 | evidence is a CT-05 path set; it is nonempty except where a row explicitly permits empty evidence. |
| CT-08 | tool version row exactly `toolName`, `version`, both CT-02; arrays are Ordinal `(toolName,version)` sorted, duplicate pairs collapse, same-name/different-version fails. |
| CT-09 | source kind exactly `PcInstall`, `PcPatchOrCache`, `AndroidApk`, `AndroidDataOrCache`; member platform exactly `Pc`, `Android`, `Unknown`; platform scope exactly `PcOnly`, `AndroidOnly`, `CrossPlatformIdentical`, `CrossPlatformVariant`, `Unknown`. |
| CT-10 | configuration disposition exactly `Parsed`, `DiscoveredOpaque`, `Encrypted`, `RequiresRuntimeType`, `LikelyServerDependent`, `NotConfiguration`. |
| CT-11 | match status exactly `ExactDuplicate`, `ConfirmedVariant`, `Unresolved`; resolution status exactly `SingleTool`, `Agreed`; failure class exactly `IdentityConflict`, `MaterialConflict`; target kind exactly `File`, `Object`. |
| CT-12 | public status vocabularies are read from AR-I05 and must equal the C0 schema enums; no alias/case folding. |
| CT-13 | all summary coverage/failure fields are CT-06 counts except fields ending `Bytes`, which are CT-06 byte counts; `gateStatus` is `Passed` or `Failed`; decision strings are CT-02. |
| CT-14 | nullable is allowed only where stated. Missing differs from null; empty string differs from both and is invalid wherever CT-02 applies. |
| CT-15 | Every C2-produced JSON file uses the property order declared by its AR-S shape recursively, UTF-8 without BOM, two ASCII spaces per indentation level, LF only, no trailing spaces, and exactly one final LF. Separators are comma+LF between array/object members and colon+one space between property name and value. Strings use JSON double quotes, escape quotation mark/backslash and U+0000-U+001F with the shortest JSON escape (`\b`, `\t`, `\n`, `\f`, `\r` where applicable, otherwise lowercase `\u00xx`), and emit every other Unicode scalar directly without normalization or optional escaping. Integers use CT-06 decimal form; booleans/null are lowercase JSON literals. Empty object/array is `{}`/`[]` on one line. No serializer-dependent property order, CRLF, BOM, compact form, alternate indentation, or terminal-newline choice is permitted. |

**AR-S01 C1 handoff:** top level exactly `schemaVersion`, `ledgerPath`, `summaryPath`, `snapshotId`, `inputFingerprint`, `sourceCount`, `fileCount`, `fileBytes`, `objectCount`. Types are string/string/string/string/lowercase-64-hex/nonnegative-integer/nonnegative-integer/nonnegative-64-bit-integer/nonnegative-integer. Paths are portable. Phase A requires `objectCount=0`.

**AR-S01a C1 ledger input:** AR-I02 uses the complete AR-S06 public-ledger shape and CT types. Its objects list must be empty; both file extraction fields must be equal; every handoff identity/count/byte value must match AR-I01 and AR-I03.

**AR-S01b C1 summary input:** top level exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `snapshotId/operationIdentity/failureAttribution/nextAllowedAction`, CT-04 `inputFingerprint/ledgerInputFingerprint`, CT-05 `ledgerPath`, CT-08 `toolVersions`, CT-05 lists `directChildSummaries/directChildReports`, CT-06 counts `sourceCount/sourceFileCount/catalogedFileCount/explicitlyExcludedFileCount`, CT-06 byte counts `sourceBytes/catalogedBytes/explicitlyExcludedBytes`, and lists `sources/exclusions`. Source-summary row exactly CT-02 `sourceId`, CT-09 `sourceKind`, CT-04 `rootFingerprint`, CT-06 `sourceFileCount/sourceBytes`. Exclusion row exactly CT-02 `sourceId/reason`, CT-05 `relativePath`, CT-06 `sizeBytes`.

**AR-S01c C0 schema/vocabulary inputs:** AR-I04, AR-I05, and AR-I06 are immutable exact-byte artifacts identified by registry path and registered SHA. C2 parses their committed JSON but never reserializes or partially fingerprints them; any byte change is FT-03 and requires explicit registry review. Their semantic nested shapes remain owned by C0 and are consumed in full, not copied into a C2 payload.

**AR-S02 object-observation document:** top level exactly `schemaVersion` (CT-01), `snapshotId` (CT-02), `inputFingerprint` (CT-04), `rows` (list). Every raw row, including a rejected counterexample, has exactly the same key set: nullable `observationId`, `toolName`, `toolVersion`, `sourceId`, `containerRelativePath`, `pathId`, `classId`, `serializedSizeBytes`, `objectType`, `objectName`, `dependencyLocators`, `contentFingerprint`, nullable `configurationDisposition`, nullable `canonicalEvidence`, `correlationEvidence`, and `evidence`. Missing or extra keys are FT-05; no committed counterexample relies on a missing key.

- A row eligible for acceptance has non-null `observationId` (HI-03), CT-02 `toolName/toolVersion/sourceId/objectType/objectName`, CT-05 `containerRelativePath`, CT-06 `pathId/classId/serializedSizeBytes`, a valid dependency-locator list, CT-04 `contentFingerprint`, CT-10/CT-14 `configurationDisposition`, valid nullable canonical evidence, valid correlation evidence, and CT-07 `evidence`. Its `observationId` must recompute exactly from the remaining accepted fields.
- A row whose values prevent HI-03 derivation must retain every raw-row key and set `observationId` to null. It is identified for FT-05 by HI-02. A non-null but non-recomputable or mismatched `observationId` is also FT-05. Null is forbidden once every HI-03 input is valid.

- `rawRowId` is never stored in AR-I07. HI-02 is computed only after reading exact artifact bytes when a row cannot produce HI-03.
- `pathId` is invariant signed-64-bit decimal text; `classId` and sizes are nonnegative integers.
- dependency locators exactly contain `sourceId`, `containerRelativePath`, `pathId`, `classId`, are unique and Ordinal-sorted by derived object ID.
- `configurationDisposition` is null or one AR-I05 value.
- `canonicalEvidence` is null or exactly `memberPlatform` (CT-09), `proposedMatchStatus` (CT-11), nullable `proposedEquivalenceFingerprint` (CT-04/CT-14; null only for Unresolved), nullable `proposedCanonicalAssetId`, Ordinal `memberObjectIds` set, and nonempty CT-07 `evidence`. Unresolved requires null proposed canonical ID and an empty member set. ExactDuplicate/ConfirmedVariant require a non-null proposed canonical ID and at least two member IDs including the row's derived HI-08. At raw-row validation, that ID is validated only as a canonical HI string and bound by HI-04; it cannot yet be recomputed as HI-10a because complete member platforms/content/missing status do not exist until the AR-S05 provenance join. Raw shape/vocabulary/HI-04 failure is FT-05. HI-10a recomputation and status/scope/content/equivalence/proposed-ID contradictions are SP-06/FT-09 after the one-to-one FT-10 precheck. These fields are raw proposal provenance; they are not copied into `resolvedValues`.
- `correlationEvidence` is exactly `correlationId` (HI-05), `method` (`ExactLocator` or `ToolMapping`), `evidence` (nonempty CT-07).
- evidence arrays are portable, distinct, Ordinal-sorted.

**AR-S03 file-discovery-observation document:** top level exactly CT-01 `schemaVersion`, CT-02 `snapshotId`, CT-04 `inputFingerprint`, list `rows`. Each valid row exactly HI-06 `fileDiscoveryObservationId`, CT-02 `toolName/toolVersion/sourceId`, CT-05 `relativePath`, `outcome` (`Readable`, `Opaque`, `Failed`), nonempty CT-07 `evidence`. `rawRowId` is fallback-only and never stored.

**AR-S04 file-configuration-observation document:** top level exactly CT-01 `schemaVersion`, CT-02 `snapshotId`, CT-04 `inputFingerprint`, list `rows`. Each valid row exactly HI-07 `configurationObservationId`, CT-02 `toolName/toolVersion/sourceId/observation`, CT-05 `relativePath`, CT-04 `contentFingerprint`, CT-10 `configurationDisposition`, nonempty CT-07 `evidence`. `rawRowId` is fallback-only and never stored.

**AR-S04a expected-input manifest (AR-I10):** top level exactly CT-01 `schemaVersion`, CT-02 `snapshotId`, CT-04 `inputFingerprint`, and list `entries`. Snapshot/input identity equals AR-I01. Each entry is exactly CT-05 `path`, CT-04 `sha256`; paths are restricted to AR-I07, AR-I08, AR-I09, and AR-I11 registry paths, are distinct and Ordinal-sorted, and the list is nonempty. Entries equal the complete set of those optional artifacts present in the exact commit OID frozen at run start. The manifest never lists itself.

**AR-S04b exclusion approvals (AR-I11):** top level exactly CT-01 `schemaVersion`, CT-02 `snapshotId`, CT-04 `inputFingerprint`, CT-05 `observationArtifactPath`, CT-04 `observationArtifactSha256`, and list `approvals`. Snapshot/input identity equals AR-I01. `observationArtifactPath` is exactly AR-I07 and `observationArtifactSha256` equals both AR-I07's AR-I10 entry and exact frozen-commit blob SHA. The artifact stable identity is `AR-I11` plus its exact registry path; its content fingerprint is CT-04 SHA-256 over exact AR-I11 bytes and is itself bound by AR-I10 and the same frozen commit.

Each approval row is exactly HI-15 `approvalId`, CT-02 `subjectKind/subjectId/reasonCode/reason/approvedBy`, CT-03 `approvedAt`, and nonempty CT-07 `evidence`. `subjectKind` is exactly `ObjectObservation`; `subjectId` is the non-null, independently recomputed HI-03 of one structurally and semantically valid AR-I07 row; `reasonCode` is exactly `ApprovedInputExclusion`. Approval rows are unique by `subjectId` and Ordinal sorted by `subjectId`. An approval for a missing, rejected, duplicate-approved, or HI-03-mismatched row is FT-02 on AR-I11, never FT-14. Approval evidence is opaque and never opened by C2.

**AR-S05 private workset:** top level exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `snapshotId`, CT-04 `inputFingerprint`, nullable CT-04 `discoveryInputFingerprint`, and list fields `resolvedFileResults`, `mergedObjectCandidates`, `canonicalProposalProvenance`, `dispatchInputFacts`, `fileDiscoveryConflicts`, `observationConflicts`, `configurationCandidates`, `configurationConflicts`, `canonicalGroups`, `canonicalConflicts`, `inputFailures`, `inputExclusions`, `inputSuppressions`, `outputFailures`, `outputExclusions`. `discoveryInputFingerprint` is present and non-null on Passed and is present with JSON null on ordinary Failed; it is never missing or empty.

- resolved file row: exactly CT-02 `sourceId`, CT-05 `relativePath`, public extraction enum `parseStatus`, Ordinal HI-ID set `observationIds`, CT-07 `evidence`.
- merged object row: exactly HI `assetObjectId/correlationId`, Ordinal HI-ID set `observationIds`, CT-11 `resolutionStatus`, object `resolvedValues`, CT-07 `evidence`. `resolvedValues` exactly CT-02 `sourceId/objectType/objectName`, CT-05 `containerRelativePath`, CT-06 `pathId/classId/serializedSizeBytes`, Ordinal HI-ID set `dependencyObjectIds`, CT-04 `contentFingerprint`, nullable CT-10 `configurationDisposition`, CT-09 `memberPlatform`.
- canonical proposal provenance row: exactly HI `proposalId/observationId/canonicalEvidenceId`, nullable HI `proposedCanonicalAssetId`, CT-11 `matchStatus`, CT-09 `platformScope`, nullable CT-04 `equivalenceFingerprint`, Ordinal HI-ID set `memberObjectIds`, list `memberFacts`, Ordinal HI-ID set `missingMemberObjectIds`, and CT-07 `evidence`, in that order. Each `memberFacts` row is exactly HI `assetObjectId`, CT-09 `memberPlatform`, CT-04 `contentFingerprint`, in that order. Member facts are unique and Ordinal-sorted by `assetObjectId`; missing IDs are distinct and Ordinal-sorted. The two ID sets are disjoint and exhaustive: `memberObjectIds = memberFacts.assetObjectId ∪ missingMemberObjectIds`, so `memberObjectIds.Count = memberFacts.Count + missingMemberObjectIds.Count`. `matchStatus`, nullable equivalence, proposed canonical ID, member IDs, and evidence copy the accepted canonical evidence; member facts and missing IDs derive only by exact join against the complete SP-04 resolved-object set. When `missingMemberObjectIds` is nonempty, `platformScope` is exactly `Unknown`; no scope may be inferred from the resolved subset. Otherwise scope derives uniquely from all member facts: only Pc → `PcOnly`, only Android → `AndroidOnly`, Pc+Android with ExactDuplicate → `CrossPlatformIdentical`, Pc+Android with ConfirmedVariant → `CrossPlatformVariant`; any other platform/status combination is an FT-09 contradiction. It is fingerprinted private validation material, is not an additional SP-08 subject, and sorts by `proposalId`.

There is exactly one provenance row for every accepted AR-I07 observation with non-null canonical evidence, and none for accepted observations with null canonical evidence. Formally, `nonNullCanonicalEvidenceAcceptedObservationIds = canonicalProposalProvenance.observationId`, with both sides duplicate-free, and `canonicalProposalProvenance.Count = acceptedNonNullCanonicalEvidenceObservationCount`. A missing row, multiple rows for one observation, or duplicate `proposalId` violates only `C2Check:Conservation` under FT-10. It is not FT-05 because the raw observation has already passed AR-S02/HI-03/HI-04, and it is not FT-09 because no canonical grouping decision is yet valid. Raw canonical-evidence shape, vocabulary, or HI-04/HI-03 mismatch remains FT-05 on its raw AR-I07 row. Valid one-to-one provenance whose joined facts expose missing members, overlap, or status/scope/content/equivalence contradiction proceeds to SP-06 and FT-09.
- dispatch input fact row: exactly HI `assetObjectId`, CT-02 `sp04Partition`, nullable CT-10 `privateConfigurationDisposition`, and nullable HI `configurationCandidateId`, in that order. `sp04Partition` is exactly `Classified` or `Unclassified`. There is exactly one row per SP-04 resolved object and rows sort Ordinal by `assetObjectId`. On a run otherwise eligible for SP-07, its ID set equals the complete conflict-free `publicObjectsWithCanonicalId.assetObjectId` set; an earlier canonical conflict keeps SP-07's universe empty and does not create a second join failure. `privateConfigurationDisposition` copies the nullable SP-04 resolved value, never the public null-to-`NotConfiguration` projection. `configurationCandidateId` is non-null exactly when the private disposition is non-null and then equals HI-09b for that object; otherwise it is null. On an otherwise eligible run, any missing, duplicate, extra, out-of-order, or inconsistent join row is the single FT-10 Conservation failure, never a new SP-08 subject.
- file conflict row: exactly HI `fileDiscoveryConflictId`, CT-02 `sourceId`, CT-05 `relativePath`, Ordinal HI-ID set `observationIds`, Ordinal set `outcomes` from AR-S03 vocabulary, CT-07 `evidence`.
- object conflict row: exactly HI `observationConflictId/correlationId`, Ordinal HI-ID sets `observationIds/derivedAssetObjectIds`, Ordinal CT-02 set `conflictingFields`, CT-11 `failureClass`, CT-07 `evidence`.
- configuration candidate: exactly HI `configurationCandidateId`, CT-11 `targetKind`, CT-02 `sourceId`, CT-05 `containerRelativePath`, nullable HI `assetObjectId`, CT-10 `configurationDisposition`, Ordinal HI-ID set `observationIds`, CT-07 `evidence`. File target has null asset ID; object target is non-null.
- configuration conflict: exactly HI `configurationConflictId/configurationCandidateId`, CT-11 `targetKind`, Ordinal HI-ID set `observationIds`, Ordinal CT-02 set `conflictingFields`, CT-07 `evidence`.
- canonical group: exactly HI `canonicalAssetId`, Ordinal HI-ID set `memberObjectIds`, CT-11 `matchStatus`, CT-09 `platformScope`, nullable CT-04 `equivalenceFingerprint` (null only for Unresolved), CT-07 `variantEvidence` (empty only for ExactDuplicate or Unresolved).
- canonical conflict: exactly HI `canonicalConflictId`, Ordinal HI-ID sets `proposedCanonicalAssetIds/memberObjectIds/observationIds`, Ordinal CT-02 set `conflictingFields`, CT-07 `evidence`.
- accounting rows follow AR-S10.

**AR-S06 C2 public ledger (AR-O01):** top level exactly `schemaVersion`, `snapshotId`, `generatedAt`, `inputFingerprint`, `toolVersions`, `sources`, `files`, `objects`.

- tool-version row is CT-08;
- source row exactly CT-02 `sourceId`, CT-09 `sourceKind`, CT-03 input `capturedAt`, CT-04 `rootFingerprint`;
- file row exactly CT-02 `snapshotId/sourceId/containerKind`, CT-09 `sourceKind`, CT-05 `relativePath`, CT-06 `sizeBytes`, CT-04 `sha256`, CT-03 input `capturedAt`, CT-12 extraction enum `parseStatus`, CT-12 disposition `disposition`, CT-07 `evidence`, nested `status`;
- object row exactly HI `assetObjectId/canonicalAssetId`, CT-02 `sourceId/objectType/objectName`, CT-05 `containerRelativePath`, CT-06 `classId/serializedSizeBytes`, Ordinal HI-ID set `dependencyObjectIds`, list `toolObservations`, CT-09 `platformVariant`, CT-10 `configurationDisposition`, CT-07 `evidence`, nested `status`;
- tool-observation row exactly CT-02 `toolName/observation`, with observation text fixed by SP-04;
- status exactly CT-12 `corpus/extraction/semantics/unity/disposition`.

C1 `schemaVersion/snapshotId/inputFingerprint` and source rows remain exact. File rows preserve all C1 values except `parseStatus` and `status.extraction`, which must be equal and derive from SP-02. Objects sort by `assetObjectId`; nested sets sort Ordinally. Public status projection is fixed in SP-04. `generatedAt` equals AR-O05; tool versions are the Ordinal-sorted union, with same-name/different-version rejected.

**AR-S07 configuration package (AR-O02):** exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `snapshotId`, CT-04 `inputFingerprint/discoveryInputFingerprint`, and lists `configurationCandidates/configurationConflicts` using AR-S05 row shapes. Passed output has empty conflicts; arrays sort by stable ID.

**AR-S08 canonical package (AR-O03):** exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `snapshotId`, CT-04 `inputFingerprint/discoveryInputFingerprint`, and lists `canonicalGroups/canonicalConflicts` using AR-S05 row shapes. Passed output has empty conflicts; arrays sort by stable ID.

**AR-S09 dispatch (AR-O04):** exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `snapshotId`, CT-04 `inputFingerprint/discoveryInputFingerprint`, CT-05 `sourceLedgerPath`, list `rows`. Each row exactly HI `assetObjectId/canonicalAssetId`, CT-02 `sourceId`, `familyLane`, `memberSelectorInputs`, nullable HI `configurationCandidateId`, `dispatchStatus`, CT-07 `evidence`. Lane is `Audio`, `Environment`, `Actor`, `UI`, `Effects`, or `Unassigned`; status is `Assigned`, `RetainedForDiagnosis`, or `ConfigurationOnly`; rows sort by object ID.

`memberSelectorInputs` is a distinct list of objects, each exactly `kind`, `value`. Kind is `ObjectType`, `ClassId`, `CanonicalAssetId`, `PlatformVariant`, `DependencyObjectId`, or `ToolObservation`; value is CT-02 text, with integers serialized invariantly. Sort Ordinal by kind then value. No map, arbitrary metadata, or nested payload is allowed.

**AR-S10 accounting row:** exactly HI-12 `recordId`, CT-02 `subjectKind/subjectId/reasonCode/attribution`, CT-07 `evidence`. Subject kinds and reasons come only from FT; evidence may be empty for `PrerequisiteUnavailable` or terminal writer failure with no persisted path. One subject appears in at most one accounting array.

**AR-S11 diagnostic bundle (AR-O05):**

- JSON top level exactly `schemaVersion`, `identity`, `provenance`, `directEvidence`, `coverage`, `failureAccounting`, `decision`.
- identity exactly CT-03 `generatedAt`, CT-02 `snapshotId`, CT-04 `inputFingerprint/ledgerInputFingerprint`, nullable CT-04 `discoveryInputFingerprint`, and CT-04 `discoveryArtifactFingerprint`, in that order. `discoveryInputFingerprint` is present and non-null on Passed and is present with JSON null on ordinary Failed; it is never missing or empty. `discoveryArtifactFingerprint` remains non-null for either successfully constructed diagnostic generation because it hashes the current run's actually produced non-summary artifacts.
- provenance exactly CT-08 list `toolVersions`, CT-02 constant `operationIdentity` from CT-02.
- directEvidence exactly lists `discoveryInputs`, `directChildSummaries`, `directChildReports`; every entry exactly CT-05 `path`, CT-04 `sha256`; each list is Ordinal path sorted and paths are unique across all three. `discoveryInputs` is every actually read AR-I artifact. On Passed, child summaries are exactly AR-O01-O04 and child reports are exactly report, sidecar, and AR-S12; on ordinary Failed, child summaries are empty and child reports are those same three diagnostic components.
- coverage exactly nested:
  - `files`: `catalogedFileCount`, `catalogedBytes`, `catalogedContainerCount`, `catalogedContainerBytes`, `nonContainerFileCount`, `nonContainerFileBytes`, `fileDiscoverySubjectCount`, `fileDiscoverySubjectBytes`, `notAttemptedFileCount`, `notAttemptedFileBytes`, `parsedFileCount`, `parsedFileBytes`, `opaqueFileCount`, `opaqueFileBytes`, `failedFileCount`, `failedFileBytes`, `fileDiscoveryConflictFileCount`, `fileDiscoveryConflictFileBytes`;
  - `containers`: `notAttemptedContainerCount`, `notAttemptedContainerBytes`, `parsedContainerCount`, `parsedContainerBytes`, `opaqueContainerCount`, `opaqueContainerBytes`, `failedContainerCount`, `failedContainerBytes`, `fileDiscoveryConflictContainerCount`, `fileDiscoveryConflictContainerBytes`;
  - `objects`: `objectObservationRowCount`, `acceptedObjectObservationRowCount`, `rejectedObjectObservationRowCount`, `excludedObjectObservationRowCount`, `correlationGroupCount`, `enumeratedObjectCount`, `observationConflictObjectCount`, `classifiedObjectCount`, `unclassifiedObjectCount`, `unresolvedDependencyCount`;
  - `configuration`: `configurationDiscoverySubjectCount`, `configurationCandidateCount`, `configurationConflictCount`, `parsedConfigurationCount`, `discoveredOpaqueConfigurationCount`, `encryptedConfigurationCount`, `requiresRuntimeTypeConfigurationCount`, `likelyServerDependentConfigurationCount`, `notConfigurationCount`;
  - `canonical`: `canonicalizedObjectCount`, `canonicalConflictObjectCount`, `canonicalGroupCount`, `exactDuplicateGroupCount`, `platformVariantGroupCount`, `unresolvedCanonicalGroupCount`;
  - `dispatch`: `dispatchEligibleObjectCount`, `assignedObjectCount`, `retainedForDiagnosisObjectCount`, `configurationOnlyObjectCount`, `audioObjectCount`, `environmentObjectCount`, `actorObjectCount`, `uiObjectCount`, `effectsObjectCount`.
- failureAccounting exactly `inputSubjectCount`, `acceptedInputSubjectCount`, `notEvaluatedInputSubjectCount`, `inputObservationCount`, `acceptedInputObservationCount`, `rejectedInputObservationCount`, `inputFailureCount`, `excludedInputSubjectCount`, `excludedInputCount`, `contractFailureRecordCount`, `fileDiscoveryConflictRecordCount`, `observationConflictRecordCount`, `configurationConflictRecordCount`, `canonicalConflictRecordCount`, `outputCandidateCount`, `projectedOutputCount`, `outputFailureCount`, `excludedOutputCount`, `issueCount`, `gateStatus`.
- decision exactly CT-02 `failureAttribution`, `nextAllowedAction`.
- report is the exact UTF-8-without-BOM, LF-only template below, with exactly one final LF. Each placeholder is replaced by the corresponding pre-artifact-fingerprint JSON scalar rendered as CT-02/CT-04/CT-06 text; the nullable `identity.discoveryInputFingerprint` placeholder renders its 64-hex CT-04 value on Passed and the lowercase literal `null` on ordinary Failed. Placeholder braces are not emitted. The two decision values cannot contain LF by CT-02. The report never contains `discoveryArtifactFingerprint` and no additional heading, whitespace, field, or localization is allowed.

```text
# C2 Discovery Gate Report
schemaVersion: {schemaVersion}
generatedAt: {identity.generatedAt}
snapshotId: {identity.snapshotId}
operationIdentity: {provenance.operationIdentity}
inputFingerprint: {identity.inputFingerprint}
ledgerInputFingerprint: {identity.ledgerInputFingerprint}
discoveryInputFingerprint: {identity.discoveryInputFingerprint}
gateStatus: {failureAccounting.gateStatus}
inputSubjectCount: {failureAccounting.inputSubjectCount}
notEvaluatedInputSubjectCount: {failureAccounting.notEvaluatedInputSubjectCount}
inputFailureCount: {failureAccounting.inputFailureCount}
outputCandidateCount: {failureAccounting.outputCandidateCount}
projectedOutputCount: {failureAccounting.projectedOutputCount}
outputFailureCount: {failureAccounting.outputFailureCount}
issueCount: {failureAccounting.issueCount}
failureAttribution: {decision.failureAttribution}
nextAllowedAction: {decision.nextAllowedAction}
```
- diagnostic sidecar is AR-S05.

**AR-S12 C0 contract-change component of AR-O05:** top level exactly CT-01 `schemaVersion`, CT-03 `generatedAt`, CT-02 `requestId/reason/nextAllowedAction`, CT-04 `inputFingerprint`, nullable CT-04 `discoveryInputFingerprint`, `status`, and lists `missingProjectionFields/evidence`, in that order. `discoveryInputFingerprint` is present and non-null on Passed and is present with JSON null on ordinary Failed; it is never missing or empty.

For the registered AR-I06 hash, values are fixed: `requestId=C0ContractChange:C2StructuredCoverage:1.0.0`; `status=Required`; `reason=Current root-gate-summary schema cannot losslessly represent mandatory C2 structured coverage partitions.`; `nextAllowedAction=Continue C3-C6 Phase A; C0 must resolve this request before G5 can pass.` Evidence is exactly the Ordinal-sorted paths of AR-I06 and AR-O05 summary. `missingProjectionFields` is a duplicate-free list with exactly the following members in the displayed order:

```text
structuredObjectCoverage.catalogedContainerCount
structuredObjectCoverage.catalogedContainerBytes
structuredObjectCoverage.nonContainerFileCount
structuredObjectCoverage.nonContainerFileBytes
structuredObjectCoverage.fileDiscoverySubjectCount
structuredObjectCoverage.fileDiscoverySubjectBytes
structuredObjectCoverage.notAttemptedFileCount
structuredObjectCoverage.notAttemptedFileBytes
structuredObjectCoverage.parsedFileCount
structuredObjectCoverage.parsedFileBytes
structuredObjectCoverage.opaqueFileCount
structuredObjectCoverage.opaqueFileBytes
structuredObjectCoverage.failedFileCount
structuredObjectCoverage.failedFileBytes
structuredObjectCoverage.fileDiscoveryConflictFileCount
structuredObjectCoverage.fileDiscoveryConflictFileBytes
structuredObjectCoverage.notAttemptedContainerCount
structuredObjectCoverage.notAttemptedContainerBytes
structuredObjectCoverage.opaqueContainerCount
structuredObjectCoverage.opaqueContainerBytes
structuredObjectCoverage.failedContainerCount
structuredObjectCoverage.failedContainerBytes
structuredObjectCoverage.fileDiscoveryConflictContainerCount
structuredObjectCoverage.fileDiscoveryConflictContainerBytes
structuredObjectCoverage.objectObservationRowCount
structuredObjectCoverage.acceptedObjectObservationRowCount
structuredObjectCoverage.rejectedObjectObservationRowCount
structuredObjectCoverage.excludedObjectObservationRowCount
structuredObjectCoverage.correlationGroupCount
structuredObjectCoverage.observationConflictObjectCount
structuredObjectCoverage.unresolvedDependencyCount
structuredObjectCoverage.configurationConflictCount
structuredObjectCoverage.discoveredOpaqueConfigurationCount
structuredObjectCoverage.encryptedConfigurationCount
structuredObjectCoverage.requiresRuntimeTypeConfigurationCount
structuredObjectCoverage.likelyServerDependentConfigurationCount
structuredObjectCoverage.notConfigurationCount
structuredObjectCoverage.canonicalizedObjectCount
structuredObjectCoverage.canonicalGroupCount
structuredObjectCoverage.canonicalConflictObjectCount
structuredObjectCoverage.exactDuplicateGroupCount
structuredObjectCoverage.platformVariantGroupCount
structuredObjectCoverage.unresolvedCanonicalGroupCount
structuredObjectCoverage.dispatchEligibleObjectCount
structuredObjectCoverage.assignedObjectCount
structuredObjectCoverage.retainedForDiagnosisObjectCount
structuredObjectCoverage.configurationOnlyObjectCount
structuredObjectCoverage.audioObjectCount
structuredObjectCoverage.environmentObjectCount
structuredObjectCoverage.actorObjectCount
structuredObjectCoverage.uiObjectCount
structuredObjectCoverage.effectsObjectCount
identity.discoveryInputFingerprint
identity.discoveryArtifactFingerprint
failureAccounting
```

A later reviewed AR-I06 hash may produce `NotRequired` only after a registry revision freezes a new exact field list. Summary JSON, report, sidecar, and AR-S12 are atomic AR-O05.

### Success, suppression, and freshness

All eight files represented by AR-O01 through AR-O05 are one publication transaction. The producer first serializes, hashes, and validates AR-O01 through AR-O04 plus all four AR-O05 components in a TEMP generation directory; no consumer path is touched during staging. It then acquires the gate publication lock and replaces the complete generation with a journaled publisher that must either expose all eight new files or restore/quarantine every changed consumer path before releasing the lock. Consumers must acquire the same lock and accept AR-O01 through AR-O04 only after reading a Passed AR-O05 summary whose fingerprints match the same generation. Thus partial files and files from a Failed/stale summary are never consumable.

On Passed, the complete generation is published. On ordinary Failed, the staged generation contains only the four AR-O05 components; AR-O01 through AR-O04 consumer paths are removed or quarantined in the same transaction and are each represented once in `outputFailures`. On any downstream file write, validation, replacement, rollback, or lock failure, no new generation is exposed: the publisher restores the prior complete generation when possible, otherwise quarantines every AR-O01 through AR-O05 consumer path and reports FT-12 terminally. A prior generation is historical evidence only and cannot satisfy the current run because its summary fingerprint is stale. On AR-O05 persistence failure, the five logical output-failure rows are emitted only to the terminal because their owning diagnostic artifact could not be persisted. No output exclusion is allowed.

`discoveryInputFingerprint` hashes every actually read artifact among AR-I01 through AR-I11, including AR-I10 whenever optional inputs exist and AR-I11 whenever exclusions exist. P0 is only the six-entry AR-I01-I06 HI-13b unit vector and omits AR-I07 through AR-I11. `discoveryArtifactFingerprint` hashes exactly the non-summary artifacts actually produced in the current run: on Passed, AR-O01 through AR-O04 plus report, sidecar, and AR-S12; on ordinary Failed, only report, sidecar, and AR-S12. It never reads suppressed or stale AR-O01-O04 bytes and never hashes the summary JSON itself. On AR-O05 atomic failure no summary exists and no discoveryArtifactFingerprint is claimed. Any add/remove/path/content change changes the relevant fingerprint. G5 projection that cannot preserve a mandatory C2 value requires AR-S12 status Required; missing/non-exact request triggers FT-11.

### SP-09 publication transaction subregistry

SP-09 is a journaled in-place publication. The eight consumer paths, in fixed transaction order, are AR-O01, AR-O02, AR-O03, AR-O04, AR-O05 report, AR-O05 sidecar, AR-S12, and AR-O05 summary. The summary is always installed and verified last. A consumer must acquire the same publication lock before reading the summary or any child; a Passed summary is consumable only when every named child exists and its exact SHA participates in the summary's current fingerprints. A Failed summary is diagnostic-only and never authorizes AR-O01 through AR-O04.

Operational state is confined to the already-ignored repository-relative root `Temp/C2DiscoveryPublication/`. The lock is `Temp/C2DiscoveryPublication/publication.lock` and is acquired by opening or creating it with read/write access and `FileShare.None`; lock acquisition failure is FT-12 and is never bypassed by deleting the lock path. The active journal is `Temp/C2DiscoveryPublication/active-journal.json`. Transaction data is under `Temp/C2DiscoveryPublication/transactions/<digest>/` with exact children `stage`, `backup`, and `quarantine`, where `<digest>` is the 64 lowercase-hex suffix of the full HI-16 and therefore contains no Windows-invalid prefix colon. The journal retains the complete prefixed HI-16. These paths are machine-local operational state, never evidence paths, never input/output artifacts, and never committed.

HI-16 uses HI-01 with nullable `discoveryInputFingerprint`. A pre-existing transaction directory for the same HI-16 is reusable only when its journal bytes validate exactly against the same transaction facts; any other collision is FT-12.

The active journal uses CT-15 bytes and has exact top-level order:

```text
schemaVersion
transactionId
phase
gateStatus
generatedAt
expectedPaths
entries
```

`phase` is exactly `Prepared`, `BackingUp`, `Installing`, `Verifying`, `Committed`, `RollingBack`, or `Quarantined`. `expectedPaths` is the complete fixed eight-path list in transaction order. Each entry has exact order:

```text
artifactId
path
desiredState
stagedSha256
priorState
priorSha256
backupRelativePath
installState
```

`desiredState` is `Present` or `Absent`; `priorState` is `Present` or `Absent`; `installState` is `Pending`, `BackedUp`, `Installed`, `Verified`, `Restored`, or `Quarantined`. `stagedSha256` is CT-04 exactly when desired state is Present and otherwise null. `priorSha256` and `backupRelativePath` are non-null exactly when prior state is Present. Backup paths are transaction-relative `backup/00` through `backup/07` in entry order. Entries are always eight rows and preserve transaction order.

Journal replacement is itself transactional: serialize to `active-journal.json.next`, flush file content to stable storage, then replace the active journal when it exists or rename the new file when it does not. A `.next` write/flush/replace failure is FT-12. Recovery ignores no file: if both journal forms exist, exact journal validation and consumer/stage/backup hashes determine the one valid newest state; ambiguity quarantines the complete known generation.

At lock acquisition, the producer scans `transactions` before reading or creating the active journal. At most one directory may match the journal's HI-16 digest. A transaction directory without either journal form is a pre-Prepared orphan and may be deleted only when it contains `stage` alone and no consumer, backup, or quarantine state could have changed; any other orphan or extra transaction directory is ambiguous and is quarantined under its own digest before FT-12 is returned. No orphan is silently ignored.

The only legal producer sequence while holding the lock is:

1. Recover or quarantine any active journal before creating a new transaction.
2. Serialize all desired files into `stage`, verify CT-15/registered shapes, and compute exact SHA values. Passed stages eight files. Ordinary Failed stages only report, sidecar, AR-S12, and summary; AR-O01 through AR-O04 entries have desired state Absent and four `SuppressedByGate` rows already present in the staged diagnostic state.
3. Write phase `Prepared`; record the exact pre-transaction state and hashes of all eight consumer paths.
4. Set `BackingUp`; move every prior Present consumer path to its numbered backup, persisting the journal around each move.
5. Set `Installing`; install desired Present children in transaction order except summary. Desired Absent paths remain absent. Install summary last.
6. Set `Verifying`; reread every desired Present consumer byte and require its staged SHA, require every desired Absent path absent, then validate all cross-artifact fingerprints and the SP-09 equation.
7. Set `Committed`; only then delete stage, backups, journal forms, and the transaction directory. The lock file may remain empty after its handle closes.

Any caught failure before `Committed` first enters `RollingBack`. Recovery and rollback derive state from journal plus exact hashes, not from the last recorded phase alone: staged SHA at a consumer path means installed; prior SHA at a consumer path means restored; prior SHA at its backup means backed up. Rollback removes a verified staged generation and restores every prior Present path. If every prior state is restored exactly, the failed attempt reports FT-12 terminally and leaves the prior generation historical and consumer-invalid for the failed run. Any missing, extra, or unknown byte makes restoration unprovable: move every extant consumer/stage/backup/journal component into the transaction quarantine, set `Quarantined`, retain quarantine for diagnosis, and expose no consumer path. No best-effort partial generation is allowed.

Output accounting is derived only after transaction outcome. Passed is `5=5+0+0`. Ordinary Failed with a successfully committed diagnostic is `5=1+4+0`; AR-O05 is the sole ProjectedOutput and AR-O01 through AR-O04 each have one `SuppressedByGate` row. FT-12 is `5=0+5+0`; because AR-O05 did not commit, all five `ProjectionInvalid` rows are terminal-only and no persisted artifact may claim them. Output exclusions are always empty.

The public `Invoke-C2DiscoveryIntakeGate` entry always uses the registered consumer paths and attempts SP-09; it exposes no arbitrary writer callback, filesystem object, fault injector, or alternate public output root. Focused tests may call a private enum-only seam rooted at `Temp/C2DiscoveryPublicationTests/<case>` and must remove a fully restored sandbox in `finally`. Production and test publisher code paths are otherwise identical. No test may touch `Extracted`, `Assets/StellaGaia/Imported`, Unity, real assets, or third-party tools.

---

## Hash And Identity Registry

### HI-01 framed byte encoding

All derived hashes use this encoding. Text is Unicode scalar values encoded UTF-8 without BOM, normalization, or case folding. Text values may not contain NUL, CR, or LF. Integers are invariant base-10 ASCII with no plus sign or leading zero except `0`.

The byte stream is ASCII domain tag plus LF, followed by fields in declared order. A scalar field is:

```text
fieldName:byteLength:value\n
```

A nullable field first emits `fieldName.null:1:0\n` for non-null or `fieldName.null:1:1\n` for null; a null emits no value field. Empty string is non-null with byte length zero. Missing required fields are invalid.

A list/set with decimal item count `C` first emits `fieldName.count:D:C\n`, where `D` is the UTF-8 byte length of the decimal text `C`; it then emits each item as `fieldName[index]:byteLength:value\n`. Sets reject duplicates under their declared comparison and sort before indexing; lists preserve declared order. Nested records are encoded independently with their own domain tag and included as item bytes. The stream has a final LF because every field/item line has LF. SHA-256 output is lowercase hex. Each ID uses its declared prefix.

### Identity rows

| ID | Prefix/domain | Ordered fields |
| --- | --- | --- |
| HI-02 raw row fallback | `raw-row-sha256:` / `C2RawRowV1` | `artifactPath`, `artifactSha256`, `rowIndex`. It applies only after a rows array and row index exist. If document parsing fails before rows exist, the corresponding AR-I07/08/09 registry artifact ID remains the sole SP-08 subject and becomes the accounting subject ID. |
| HI-03 object observation | `observation-sha256:` / `C2ObjectObservationV1` | `toolName`, `toolVersion`, `sourceId`, `containerRelativePath`, `pathId`, `classId`, `serializedSizeBytes`, `objectType`, `objectName`, `dependencyLocatorIds` set, `contentFingerprint`, nullable `configurationDisposition`, nullable `canonicalEvidenceDigest`, `correlationId`, `evidence` set |
| HI-04 canonical evidence | `canonical-evidence-sha256:` / `C2CanonicalEvidenceV2` | `memberPlatform`, `matchStatus`, nullable `equivalenceFingerprint`, nullable `proposedCanonicalAssetId`, `memberObjectIds` set, `evidence` set |
| HI-05a locator | `locator-sha256:` / `C2ToolLocatorV1` | `toolName`, `toolVersion`, `sourceId`, `containerRelativePath`, `pathId`, `classId` |
| HI-05b exact correlation | `correlation-sha256:` / `C2CorrelationExactLocatorV1` | `sourceId`, `containerRelativePath`, `pathId` |
| HI-05c mapped correlation | `correlation-sha256:` / `C2CorrelationToolMappingV1` | `locatorIds` set, Ordinal unique/sorted/count encoded |
| HI-06 file discovery observation | `file-discovery-observation-sha256:` / `C2FileDiscoveryObservationV1` | `toolName`, `toolVersion`, `sourceId`, `relativePath`, `outcome`, `evidence` set |
| HI-07 file config observation | `configuration-observation-sha256:` / `C2FileConfigurationObservationV1` | `toolName`, `toolVersion`, `sourceId`, `relativePath`, `contentFingerprint`, `configurationDisposition`, `observation`, `evidence` set |
| HI-08 object | `sha256:` / `C2ObjectIdentityV1` | `sourceId`, `containerRelativePath`, `pathId`, `classId` |
| HI-09a file configuration candidate | `config-sha256:` / `C2ConfigurationFileV1` | `sourceId`, `relativePath` |
| HI-09b object configuration candidate | `config-sha256:` / `C2ConfigurationObjectV1` | `assetObjectId` |
| HI-09c configuration conflict | `configuration-conflict-sha256:` / `C2ConfigurationConflictV1` | `configurationCandidateId`, `targetKind`, `observationIds` set, `conflictingFields` set |
| HI-10a confirmed canonical group | `canonical-sha256:` / `C2CanonicalGroupV1` | `matchStatus`, `platformScope`, `equivalenceFingerprint`, `memberObjectIds` set; Unresolved instead uses its sole object ID directly |
| HI-10b variant equivalence | no prefix / `C2VariantEquivalenceV1` | `contentFingerprints` distinct Ordinal-sorted set with count |
| HI-10c canonical conflict | `canonical-conflict-sha256:` / `C2CanonicalConflictV1` | `proposedCanonicalAssetIds`, `memberObjectIds`, `observationIds`, `conflictingFields`; each distinct Ordinal-sorted set separately named/count encoded |
| HI-10d canonical proposal provenance | `canonical-proposal-sha256:` / `C2CanonicalProposalV2` | `observationId`, `canonicalEvidenceId`, nullable `proposedCanonicalAssetId`, `matchStatus`, `platformScope`, nullable `equivalenceFingerprint`, `memberObjectIds` set, `memberFacts` nested-record list, `missingMemberObjectIds` set, `evidence` set |
| HI-11a file discovery conflict | `file-discovery-conflict-sha256:` / `C2FileDiscoveryConflictV1` | `sourceId`, `relativePath`, `observationIds` set, `outcomes` set |
| HI-11b object observation conflict | `observation-conflict-sha256:` / `C2ObservationConflictV1` | `correlationId`, `observationIds`, `derivedAssetObjectIds`, `conflictingFields` sets, `failureClass` |
| HI-12 accounting | `accounting-sha256:` / `C2AccountingRecordV1` | `owningArray`, `subjectKind`, `subjectId`, `reasonCode`, `attribution`, `evidence` set |
| HI-13a artifact entry | nested/no prefix / `C2ArtifactEntryV1` | portable path, exact lowercase SHA-256 |
| HI-13b input artifact-set fingerprint | no prefix / `C2DiscoveryInputV1` | `entries` distinct set of HI-13a byte records sorted by their decoded portable path, with count |
| HI-13c output artifact-set fingerprint | no prefix / `C2DiscoveryArtifactV1` | same entry encoding/order/count as HI-13b for the current run's actually produced non-summary artifacts: Passed has AR-O01-O04+report+sidecar+AR-S12; ordinary Failed has report+sidecar+AR-S12 |
| HI-14 diagnostic bundle fingerprint | no prefix / `C2DiagnosticBundleV1` | `entries` set encoded exactly as HI-13b, containing summary JSON, report, sidecar, and AR-S12 component |
| HI-15 exclusion approval | `exclusion-approval-sha256:` / `C2ExclusionApprovalV1` | `subjectKind`, `subjectId`, `reasonCode`, `reason`, `approvedBy`, `approvedAt`, `evidence` set |
| HI-16 publication transaction | `publication-sha256:` / `C2PublicationTransactionV1` | `snapshotId`, `generatedAt`, `inputFingerprint`, nullable `discoveryInputFingerprint`, `gateStatus` |

For HI-13a the literal scalar field names are `path` then `sha256`. For HI-13b/HI-13c the literal set field name is `entries`; nested item labels are `entries[0]`, `entries[1]`, and so on after Ordinal path sorting. The nested HI-13a record includes its `C2ArtifactEntryV1` domain line and final LF inside the item's encoded byte length; the outer item adds its own final LF. These literal names and boundaries produce the registered P0 digest and no alternative labels are allowed. PowerShell `Sort-Object` is forbidden for this ordering because it is culture-sensitive; implementations must use `System.StringComparer.Ordinal` or an equivalent ordinal comparator.

For HI-10d V2, each `memberFacts` item is the complete nested byte record `C2CanonicalMemberFactV1\n`, then scalar fields `assetObjectId`, `memberPlatform`, `contentFingerprint` in that order using HI-01. Rows sort Ordinally by decoded `assetObjectId`. The outer list emits `memberFacts.count:D:C\n`, then each complete nested record as `memberFacts[index]:byteLength:<nested-bytes>\n`; `byteLength` includes the nested domain line and its nested final LF, while the outer item contributes its own final LF. No member-fact digest or serializer byte sequence is used. `memberObjectIds` and `missingMemberObjectIds` use their literal field names and normal HI-01 set framing. This is the only HI-10d V2 preimage.

No other identity or nested digest is permitted without adding a registry row.

---

## Central Definition 2: Subject/Partition Registry

| ID | Universe and stable identity | Mutually exclusive partitions | Conservation | Storage / projection / consumer |
| --- | --- | --- | --- | --- |
| SP-01 C1 files | every AR-I02 file; `(sourceId, normalized relativePath)` | Container, NonContainer | `catalogedFileCount = catalogedContainerCount + nonContainerFileCount`; same for bytes | AR-I02; AR-O01; G5. `DirectMedia`, `Metadata`, `ConfigurationCandidate` are NonContainer; every other kind including `UnknownInput` is Container. |
| SP-02 file discovery subjects | every SP-01 file | NotAttempted, Parsed, Opaque, Failed, FileDiscoveryConflict | `fileDiscoverySubjectCount = notAttemptedFileCount + parsedFileCount + opaqueFileCount + failedFileCount + fileDiscoveryConflictFileCount`; same equation for bytes. Container-filtered equation replaces `File` with `Container` in every term. | AR-P01; successful status projects to both public extraction fields; conflict follows FT-06. |
| SP-03a object-observation row subjects | every exact-key AR-I07 raw row, identity HI-02 until all HI-03 inputs validate and HI-03 thereafter | AcceptedObservation, RejectedObservation, ExcludedObservation | `objectObservationRowCount = acceptedObjectObservationRowCount + rejectedObjectObservationRowCount + excludedObjectObservationRowCount` | AR-P01/SP-08. Rejected rows use HI-02. Excluded rows must first be valid HI-03 rows and then match exactly one valid AR-I11 approval. Excluding one row never excludes its correlation group; grouping uses only accepted rows. |
| SP-03b correlation-group subjects | every distinct correlation ID formed from accepted SP-03a rows | ResolvedObject, ObservationConflict | `correlationGroupCount = enumeratedObjectCount + observationConflictObjectCount` | AR-P01; only ResolvedObject reaches SP-04. |
| SP-04 resolved objects | every merged object ID HI-08 | Classified, Unclassified | `enumeratedObjectCount = classifiedObjectCount + unclassifiedObjectCount` | AR-P01 → AR-O01. Public status: corpus `Cataloged`; extraction `ExtractedReadable` for SingleTool or `CrossToolVerified` for Agreed; semantics Unknown iff type Unknown, Known iff known name+all deps resolved+config Parsed/NotConfiguration, else PartiallyKnown; unity `NotTested`; disposition `RetainForLater`. Tool observations and evidence are distinct Ordinal-sorted projections. |
| SP-05 configuration subjects | every unique HI-09a C1 `ConfigurationCandidate` file plus every SP-04 resolved object whose single resolved configuration disposition is non-null, identified by HI-09b | ResolvedConfiguration, ConfigurationConflict | `configurationDiscoverySubjectCount = configurationCandidateCount + configurationConflictCount`; resolved six-state sum equals candidate count | AR-P01 → AR-O02. SP-03b conflicts never enter this universe. Multiple file observations agree only when both contentFingerprint and configurationDisposition are exact-equal; otherwise ConfigurationConflict. Zero-observation C1 file becomes `DiscoveredOpaque` with empty observation IDs and AR-I02 path evidence. Private null maps public `NotConfiguration` and is outside this universe. |
| SP-06 canonical subjects | every SP-04 object | Canonicalized, CanonicalConflict | `enumeratedObjectCount = canonicalizedObjectCount + canonicalConflictObjectCount`; `canonicalGroupCount = exactDuplicateGroupCount + platformVariantGroupCount + unresolvedCanonicalGroupCount` | AR-P01 → AR-O03/public object. Null canonical evidence deterministically creates a one-member `Unresolved` group using object ID as canonical ID. ExactDuplicate requires >=2 IDs/same content; ConfirmedVariant requires Pc+Android/distinct content/evidence; overlaps follow FT-09. |
| SP-07 dispatch subjects | every SP-04 object when gate otherwise Passed | Assigned, RetainedForDiagnosis, ConfigurationOnly | `dispatchEligibleObjectCount = assignedObjectCount + retainedForDiagnosisObjectCount + configurationOnlyObjectCount`; assigned lane sum equals assigned count | AR-O04 → C3-C6. On any failure eligible count is zero and AR-O04 suppressed. |
| SP-08 input accounting subjects | every actually read AR-I01-I11 artifact; every raw observation row from AR-I07/08/09 only; derived conflict identities; and exactly the five contract-check identities in the subregistry below | Accepted, InputFailure, InputExclusion, NotEvaluated | `inputSubjectCount = acceptedInputSubjectCount + inputFailureCount + excludedInputSubjectCount + notEvaluatedInputSubjectCount`; observation subset: `inputObservationCount = acceptedInputObservationCount + rejectedInputObservationCount + excludedInputCount`; `inputFailureCount = rejectedInputObservationCount + contractFailureRecordCount + fileDiscoveryConflictRecordCount + observationConflictRecordCount + configurationConflictRecordCount + canonicalConflictRecordCount`; one direct parent only | AR-P01/AR-O05. AR-I11 approval rows and AR-S05 canonical provenance rows are validation material and are **not independent accounting subjects**. Provenance one-to-one/count/uniqueness is owned once by `C2Check:Conservation`, not once per provenance row. `excludedInputSubjectCount=excludedInputCount`; NotEvaluated is allowed only for a contract check under FT-15. Exclusion only valid for a semantically valid HI-03 raw observation with exactly one AR-I11 approval; core artifacts/checks/conflicts/approval/provenance rows cannot be excluded. Row-level FT-04/05 is a rejected observation; artifact/check-level FT-01..05/10/11/13 is a contract failure. An unparseable AR-I07/08/09 changes that one artifact subject from Accepted to InputFailure under its registry ID; it never creates a second fallback subject. |
| SP-09 output subjects | exactly AR-O01..AR-O05 | ProjectedOutput, OutputFailure, OutputExclusion | `outputCandidateCount=5 = projectedOutputCount + outputFailureCount + excludedOutputCount`; excluded output always 0 | Passed 5/0/0; ordinary Failed with AR-O05 diagnostic 1/4/0; FT-12 AR-O05 atomic failure 0/5/0. |

### SP-02 file-discovery partition subregistry

For each file, combine accepted AR-I08 rows with implied `Readable` observations from accepted AR-I07 rows targeting that file. Deduplicate exact `(toolName,toolVersion,outcome,observationId)` tuples; sort observation IDs Ordinally; evidence is their distinct Ordinal path union.

- zero observations → NotAttempted, public extraction `NotAttempted`, empty observation IDs/evidence;
- one or more observations all `Readable` → Parsed; one distinct tool projects `ExtractedReadable`, two or more distinct tools project `CrossToolVerified`;
- one or more all `Opaque` → Opaque/public `Opaque`;
- one or more all `Failed` → Failed/public `Failed`;
- more than one distinct outcome → FileDiscoveryConflict/FT-06 and no resolved file row.

The same derived extraction value is written to both public `parseStatus` and `status.extraction`; inequality is FT-02.

### SP-03b object-merge subregistry

Within one correlation group, every accepted row must derive the same HI-08 identity fields `sourceId/containerRelativePath/pathId/classId`; disagreement is `IdentityConflict`. After identity agrees, the following material values must be Ordinal/exact-equal: `objectType`, `objectName`, `serializedSizeBytes`, complete dependency-locator set, `contentFingerprint`, nullable `configurationDisposition`, nullable canonical-evidence object, and member platform derived from source kind. Any disagreement is `MaterialConflict` and follows FT-07.

Only `observationIds`, tool-observation rows, and evidence paths are unioned. With one accepted row resolution is SingleTool; with two or more distinct toolName/version pairs and complete agreement it is Agreed. No configuration or canonical disagreement is deferred past SP-03b. Therefore every merged SP-04 object has one exact resolvedValues object.

### SP-04 public projection subregistry

- Public scalar/object fields copy the one AR-P01 resolved value. Public `configurationDisposition` is the resolved CT-10 value, or `NotConfiguration` when private value is null. Member platform derives only from source kind: PC kinds → Pc, Android kinds → Android.
- `objectType` is unknown only when it is Ordinal-equal to `Unknown`; `objectName` is known only when CT-02 and not Ordinal-equal to `Unknown`.
- A dependency is resolved only when its HI-08 ID occurs in the complete SP-04 resolved-object ID set; self-dependency and IDs in SP-03b conflicts are unresolved.
- Semantics is `Unknown` iff object type is unknown; otherwise `Known` iff name is known, every dependency resolves, and configuration is `Parsed` or `NotConfiguration`; otherwise `PartiallyKnown`.
- SP-04 partition is `Classified` iff projected semantics is `Known` or `PartiallyKnown`; it is `Unclassified` iff semantics is `Unknown`. No other input affects this partition.
- For each accepted observation sorted by toolName/toolVersion/observationId, public `toolObservations` row is exactly `toolName` and `observation`. The observation text concatenates `version=`, exact version, `;observationId=`, exact ID, `;resolution=`, and merged resolution status, with no whitespace.
- Public evidence is the distinct Ordinal-sorted union of observation, correlation, dependency, configuration, and canonical evidence. Empty evidence fails FT-11.
- Canonical ID comes only from SP-06. Public `platformVariant` equals the resolved CT-09 member platform exactly, never group platform scope. Corpus is `Cataloged`; extraction is `ExtractedReadable` for SingleTool or `CrossToolVerified` for Agreed; Unity is `NotTested`; disposition is `RetainForLater`.

### SP-06 canonical-proposal provenance subregistry

SP-06 consumes only the complete SP-04 resolved-object set and the complete AR-S05 `canonicalProposalProvenance`; it never reads AR-I07 again or an unregistered field from `resolvedValues`. Before grouping, FT-10 enforces the one-to-one formula registered above. A valid provenance row then supplies every grouping fact without reversing a hash: its observation and HI-04 are already accepted, its member facts/missing IDs are an exact exhaustive join, and its HI-10d V2 recomputes. Different member observations may and normally do produce different proposal IDs while expressing one exact-equal canonical proposal.

Null canonical evidence creates no provenance row and deterministically yields one-member Unresolved. ExactDuplicate requires at least two members, identical content fingerprints, and `PcOnly`, `AndroidOnly`, or `CrossPlatformIdentical` scope derived from member facts. ConfirmedVariant requires Pc+Android, at least two distinct content fingerprints, `CrossPlatformVariant`, nonempty evidence, and equivalence fingerprint equal to HI-10b. All provenance rows naming one proposed canonical ID must agree exactly on proposed ID, match status, platform scope, equivalence fingerprint, member IDs, member facts, and missing IDs. Agreement by e/f for group A is a positive, not a duplicate. A missing member, overlap between different proposed IDs, or status/scope/content/equivalence contradiction is FT-09. Missing/multiple provenance for one observation or duplicate proposal ID is FT-10. All affected objects become CanonicalConflict only for FT-09 and never also Canonicalized.

The frozen vectors use object IDs `sha256:` plus 64 `a`, `b`, `c`, and `d` digits; observation IDs `observation-sha256:` plus 64 `e` and `f` digits; evidence `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/canonical-e.json` and `canonical-f.json`. ExactDuplicate A has members a/b, Pc/Pc, content/equivalence 64 `1`, scope PcOnly. ExactDuplicate B has b/c with the same facts. ConfirmedVariant has c/d, Pc/Android, content 64 `2`/64 `3`, scope CrossPlatformVariant.

From-zero HI-10 results are: A `canonical-sha256:843086f47eb4de699ad9d586f4692993fb1bbe0f68b1487b32aa1cd5b7eeff3c`; B `canonical-sha256:0942c13e4665a597883b01a50826348ce4443e1cbe3c676d74c24ab81c3a4ad3`; variant HI-10b `1bbf97948d5f9111ae0e5000a7420a367632e52f434c9cdf15ecae33dfa5bbe1`; variant HI-10a `canonical-sha256:0daa9f57bb5628818d732ec67ff39f74839a47a4a668c0465bd6f4f0a7e0dc85`.

Complete positive provenance rows are:

| vector/observation | memberFacts (`id/platform/content`) | HI-04 V2 | HI-10d V2 proposalId |
|---|---|---|---|
| ExactDuplicate A/e | a/Pc/1, b/Pc/1 | `canonical-evidence-sha256:db79daf694e7124465b9ab59f11e5c83099708887ccbb8165d4082d96f72b635` | `canonical-proposal-sha256:3e94ad5cd6c7dfbc0b844c4cc9d6a45c89cb743a90f3fd613ac861b6f9cf075e` |
| ExactDuplicate A/f | a/Pc/1, b/Pc/1 | `canonical-evidence-sha256:84d251cfa1e7737a37cfba8044aa0a9b5b6ae445d006486f6085e27bdaf1b6d3` | `canonical-proposal-sha256:07596af8c1ccced882613599bf6b2f4e47efa7baed7e8b5a96bbfaa8001e83ee` |
| ConfirmedVariant/e | c/Pc/2, d/Android/3 | `canonical-evidence-sha256:8f15fd3e611ba21a1edcd7dbde908459200c3b6cdde21010da9f2b41bbe507e2` | `canonical-proposal-sha256:bcfd8bd495f025e7499ca30ab49c5026030b47b6ebf4826dd46fb629ccaf56f6` |
| ConfirmedVariant/f | c/Pc/2, d/Android/3 | `canonical-evidence-sha256:144a9217b5fdd1b299e9ad4adb69296ba8ac7eb001eb837bf4dc8c9dc2418fcc` | `canonical-proposal-sha256:66cae93bc4f8b1c7abc575cd7a771928a693fed0498b75ba2abb05f656f514f7` |

Every positive row has empty `missingMemberObjectIds`; the two A rows are exact-equal after excluding observation-specific identity/evidence and therefore form one valid agreement. B/f uses HI-04 `canonical-evidence-sha256:e879808a21e1683270df2417aba026e455f6ec5c1b16f5f58f7aed3ffb3eee16` and HI-10d V2 `canonical-proposal-sha256:966b0d84c34ecfde8c42c64f892601d3f6ec44e8c0530cf0c935fc4f8f2b73d5`. Missing-b/e has only fact a, missing set `[b]`, `platformScope=Unknown`, and HI-10d V2 `canonical-proposal-sha256:24f936f959f9cff908eaf79b2159bcf55e5879be3a2a1e276c9d3c123bde9cc6`. HI-10a over ExactDuplicate/Unknown/64 `1`/members a+b is `canonical-sha256:2deebf8783219024da05851d8e639a2f9a2b5a3b944c96d8187ab7c8b0e441c8`, while its raw proposed ID remains A/PcOnly; the same FT-09 subject therefore owns both `missingMemberObjectIds` and `proposedCanonicalAssetId` contradictions.

The exact FT-09 vectors, all recomputed under the unchanged HI-10c framing, are:

| vector | proposed IDs | members | observations | conflictingFields | canonicalConflictId | FT-09 recordId |
|---|---|---|---|---|---|---|
| overlap A/B | A,B | a,b,c | e,f | `memberObjectIds` | `canonical-conflict-sha256:6d27bbe91cbcdcf600269fa6e7f9f8566c47bb072bb389948352908de8b5df84` | `accounting-sha256:b96c96d4eb5a03e06798d939a37b102dac4a578495f2c4fb1275078e6ef58a77` |
| missing b | A | a,b | e | `missingMemberObjectIds,proposedCanonicalAssetId` | `canonical-conflict-sha256:2bdbd0bd8082a99d1665216df74581f06dc752254bb03f63c5262650c807b499` | `accounting-sha256:14cf5beeae126026d50ebbde74287d6df7da711a44570affbbc589dc2eda7fc8` |
| variant status mismatch | variant | c,d | e,f | `matchStatus` | `canonical-conflict-sha256:781d9a95c17b2b13e3d7dc238cbc8e617f6eb3c0055cdbcdef7024d7f9aa67b5` | `accounting-sha256:3a270d9e610aa9ebe108a56d5c58ce3f284e7f70ad6e2e6d207b7d2f39c1b5bc` |
| variant scope mismatch | variant | c,d | e,f | `platformScope` | `canonical-conflict-sha256:cb87382ad9e3e0c4df42bc295b042face94d7c73219cc8165e63279504f29776` | `accounting-sha256:2a5ab596f6edacec595bea75857596b7e850dfe5cf2c98841bc71800b035506f` |
| variant same platform | variant | c,d | e,f | `memberPlatform` | `canonical-conflict-sha256:b45a6162ea16bda2d7c717d451de5c565296b9ce16edb676930a9b4e16b9b694` | `accounting-sha256:a2f3cf79107d4422fd7f75bddcad234e5d079a03f8a52f99ea970736ae7bc103` |
| variant same content | variant | c,d | e,f | `contentFingerprint` | `canonical-conflict-sha256:bffc1ab94aa94f182dbae0e02c4a6eb1edd3e2cdce821390df9ab315131c6a12` | `accounting-sha256:0ca4f829ad7b7e71132e055f329c1f6351b2fb934d09cce992a6de1f73928c89` |
| variant bad HI-10b | variant | c,d | e,f | `equivalenceFingerprint` | `canonical-conflict-sha256:36e974feaf687441fdcd12bede62c5461ad3ce2b3cf843a40858279c5a2f1cbe` | `accounting-sha256:7c5158ff25a6da20c94656196b201a0a07044865c4e3b33ccfa8612a452c33b7` |
| variant wrong proposed ID | 64 `0` canonical ID | c,d | e,f | `proposedCanonicalAssetId` | `canonical-conflict-sha256:9e90ab6ccc6053632f98f1394ee626344ccc5d40206975ba84c66528397e3d22` | `accounting-sha256:5022d9b9231dfa748eefb232045b00ae209148748e5d2d44c54085c06fbf0dda` |

Every mismatch is an exact one-field mutation from the ConfirmedVariant positive unless explicitly stated otherwise. Status mismatch keeps e fully positive and changes only f `matchStatus` from `ConfirmedVariant` to `ExactDuplicate`; f retains `platformScope=CrossPlatformVariant`, equivalence, proposed ID, member IDs/facts, empty missing set, and evidence. Scope mismatch keeps e fully positive and changes only f provenance `platformScope` from `CrossPlatformVariant` to `PcOnly`; f raw canonical evidence and HI-04 remain the positive f values, and every other provenance field remains positive. Their HI-10d V2 values are respectively status e positive / f `108c28464128860401c75cd3eb6ab4592223fc74608bef384bb04ebba36831be`, and scope e positive / f `27297e10a70d134a863e991f6ef3b72023f1ff413300a5a1fc1d63326be3f4d7`, with `canonical-proposal-sha256:` prefix. Status-mismatch f HI-04 V2 is `canonical-evidence-sha256:90a0887f725603c21dfa4049678a04639b68f8b16e3afa93fe7b114db8c5b8b1`; scope f reuses the positive f HI-04.

The remaining exact mutations/pairs are: same-platform changes only d `memberPlatform` Android→Pc, yielding HI-10d V2 `85cda06cc648f7e9a93f90daf3e13af0c257c4ed7a66c0f81d373a2f568a52b5` / `a568f81cf6cb9d8633cf6c29bb7d482985b705c00a222389c450bb4e174615a3`; same-content changes only d content 64 `3`→64 `2`, yielding `bc9d70965fdcb648125ba539315bb94a47550d67ee93c05047bfec264e42a1c2` / `46270f39c430a93693a51b3afd36f0c02971a37066eaf5fbefc683fb4368b922`; bad-equivalence changes only both raw/provenance equivalence values to 64 `4`, yielding `10c64a41328e703261b7ffe287b241e412c0a4e4d5bbca70d6317b1e901fb5ab` / `f63fde95393413889917bc20d5a9bf91947ad8b819b6882a95b5269e198e26b5`; wrong-proposed-ID changes only both raw/provenance proposed IDs to `canonical-sha256:` plus 64 `0`, yielding `a026a213892f22f9b735733aaf2a3d033ecc8aca42a6e105eead8bc7d4ec00a5` / `71a3ab805daec59781a2df792ac25699fd57d3845d8730c3570e0d423b7ed272`, all with `canonical-proposal-sha256:` prefix. Bad-equivalence HI-04 V2 values are `canonical-evidence-sha256:6cfb8bca2b02e4b2554c285564971a9a846fc1ec2c69b7b84c9e108db3212940` / `canonical-evidence-sha256:0fada0662bd211eebc3bffc40412decf0dc3dea2a6d08097109515957c4be6ff`; wrong-proposed-ID HI-04 V2 values are `canonical-evidence-sha256:11c27cb661a4eb487c400793f88b52c3016325975c02ba039309dfd2d907c1ab` / `canonical-evidence-sha256:e04a71d31b56392af6066e2e0c5ff1bf567fb6a8bd3dd5d4010de5e0bf633901`.

Each FT-09 vector produces one AR-S10 CanonicalConflict row with its direct evidence union. There is no `duplicateProposal` FT-09 vector. Repeating the same provenance row for observation e is instead the FT-10 counterexample: subject `C2Check:Conservation`, evidence exactly `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json`, record `accounting-sha256:99b22592adff48c273bdc79844085fdd2052dc5bc18766d8a6d8249cb7967985`. It creates no HI-10c conflict and no canonical group.

### SP-07 dispatch partition subregistry

SP-07 consumes an exact one-to-one join of `publicObjectsWithCanonicalId` and AR-S05 `dispatchInputFacts` by `assetObjectId`. It does not read `sp04Partition` or private configuration disposition from AR-S06, and neither private field may be added to a public object. The join must satisfy the dispatch-input conservation rule above before any precedence rule is evaluated.

Evaluate rules in this fixed order:

1. Non-null private configuration disposition → `ConfigurationOnly`, lane `Unassigned`, non-null HI-09 candidate ID.
2. Otherwise, Unclassified SP-04 object → `RetainedForDiagnosis`, lane `Unassigned`, null configuration candidate ID.
3. Otherwise map exact Ordinal object type: Audio lane `{AudioClip,AudioMixer,WwiseBank,WwiseMedia}`; Environment `{Scene,TerrainData,LightmapData,MeshRenderer}`; Actor `{Avatar,AnimationClip,AnimatorController,SkinnedMeshRenderer}`; UI `{Sprite,SpriteAtlas,Font,TMP_FontAsset,Canvas}`; Effects `{ParticleSystem,VisualEffect,TrailRenderer}`.
4. A type in exactly one set → `Assigned` with that lane and null configuration candidate ID. Any other type → `RetainedForDiagnosis`, `Unassigned`, null candidate ID.

The sets are disjoint and case-sensitive. Every dispatch row has exactly one `ObjectType`, one `ClassId`, one `CanonicalAssetId`, and one `PlatformVariant` selector copied from the corresponding public object; exactly one `DependencyObjectId` selector for each distinct public dependency ID (zero allowed); and exactly one `ToolObservation` selector for each distinct public tool-observation `observation` string (one or more for every resolved object). Duplicate `(kind,value)` pairs collapse before the AR-S09 Ordinal sort. No other selector is permitted. Dispatch evidence is the object's public evidence. No heuristic based on path or name is allowed.

### SP-08 contract-check subregistry

Every run contains exactly these five contract-check subjects, independent of how many artifacts or observation rows are present:

| Subject ID | Accepted predicate | Failure transition |
| --- | --- | --- |
| `C2Check:C1Handoff` | AR-I01 has AR-S01 shape; its snapshot/source-ledger/summary identities and safe portable paths resolve exactly to AR-I02/AR-I03 | FT-01 replaces Accepted with one InputFailure |
| `C2Check:Freshness` | AR-I01-I06 match the Existing-input byte registry; when optional inputs exist, the run freezes one commit OID, AR-I10 matches its exact blob, every present AR-I07-I09/AR-I11 path/SHA matches both AR-I10 and its same-commit blob, HI-13b over every read artifact recomputes exactly, and end-of-run HEAD equals the frozen OID | FT-03 replaces Accepted with one InputFailure |
| `C2Check:Conservation` | Canonical provenance satisfies its one-to-one/count/uniqueness and member-fact partition invariants before SP-06 grouping, then every applicable SP equation and byte analogue holds after all direct subjects are partitioned | FT-10 replaces Accepted with one InputFailure |
| `C2Check:PublicProjection` | Public/private projections obey AR-S06 through AR-S12, including the exact Required AR-S12 component for AR-I06 | FT-11 replaces Accepted with one InputFailure |
| `C2Check:LightweightPolicy` | The run reads fixtures/TEMP only and invokes no extraction, Unity, import, heavy child, or third-party asset operation | FT-13 replaces Accepted with one InputFailure |

Each check contributes exactly one SP-08 subject: Accepted when its predicate is evaluated and holds, InputFailure when evaluated and false, or NotEvaluated under FT-15 when a named prerequisite below is unavailable. A check never contributes two states, is never excluded, and is counted once even if its predicate exposes multiple details. Schema/vocabulary validation is intrinsic to the corresponding AR-I02/AR-I04/AR-I05/AR-I06 artifact subject; FT-02 changes that artifact subject from Accepted to InputFailure and does not create or change a contract-check subject. Artifact- or row-specific FT-04/FT-05 likewise change only their registered direct subject. No sixth implicit schema, policy, or projection check is allowed.

### Public/root projection rule

Every private partition above either projects to the named public/output artifact, remains in fingerprinted AR-O02/O03/O05 coverage, or appears in AR-S12. For the registered AR-I06, a valid Required AR-S12 is the successful third projection outcome: C2 may pass and C3-C6 may consume its outputs, while C0/G5 remains blocked. Missing, stale, or non-exact AR-S12 content triggers FT-11. C2 never folds NotAttempted into opaque/failed or edits C0 schemas itself.

---

## Central Definition 3: Failure Transition Table

All failure IDs use HI-12 with the stable subject shown. Every row creates exactly one accounting record per failing direct subject. `gateStatus=Failed`; `failureAttribution` names stage+subject without machine path; `nextAllowedAction` is the table value. Downstream authorization is always none.

### Evaluation, short-circuit, and ownership order

The gate evaluates stages in this fixed order and completes all independent direct subjects whose prerequisites exist: (1) FT-13 lightweight-policy preflight; (2) FT-01 C1 handoff identity/path; (3) FT-04 portable-path safety for non-handoff artifacts/rows; (4) FT-03 exact-byte freshness; (5) FT-02 schema/vocabulary validation; (6) FT-05 raw-row validation and FT-14 exclusions; (7) FT-06 through FT-08 conflicts plus construction of canonical provenance from accepted rows; (8) the FT-10 canonical-provenance precheck; (9) FT-09 canonical conflict derivation only when that precheck passes; (10) final FT-10 SP conservation on the same single check subject; (11) FT-11 public projection; (12) output staging/publication FT-12. The precheck and final equations are one evaluation of `C2Check:Conservation`, never two accounting subjects or rows. An earlier InputFailure does not suppress an independent subject or accepted-row derivation whose prerequisites still exist. A contract check whose prerequisites do not exist follows FT-15 NotEvaluated; it is never called Accepted or failed. Any InputFailure prevents downstream output and causes the ordinary Failed diagnostic transaction after all evaluable fixture-only stages complete.

For one direct subject, the first applicable transition in that order owns it exclusively. In particular, unsafe paths in AR-I01 are FT-01 rather than FT-04; a content mismatch is FT-03 and semantic/schema validation of those stale bytes is not attempted; FT-02 applies only after exact registered bytes pass freshness; and FT-10/FT-11 never fire merely because a prerequisite is unavailable. Different direct subjects discovered in the same stage each receive one row. The five contract checks are evaluated in order `LightweightPolicy`, `C1Handoff`, `Freshness`, `Conservation`, `PublicProjection`; the Conservation result is finalized only after its precheck and all enabled partition equations complete. LightweightPolicy and C1Handoff have no prerequisite; Freshness requires only each actually read artifact's bytes and registry row; Conservation requires accepted AR-I01/02/03 plus every present AR-I07/08/09 parsed far enough to partition its artifact and rows. A failed canonical-provenance precheck prevents SP-06 partitioning and FT-09 derivation: canonical groups/conflicts/public join are empty, canonical coverage counts are zero, no object is claimed in an SP-06 success/conflict partition, and the resulting unmet SP-06 equation remains part of the same single Failed Conservation check rather than creating another failure. PublicProjection requires Accepted Conservation and accepted AR-I04/05/06. A missing prerequisite produces one FT-15 row for that check with evidence equal to the distinct available paths of the missing/failing prerequisites, or empty when the required path itself is unavailable. This order is the only source of direct-failure ownership and supersedes incidental validator exception order.

| ID | Stage/failure | Stable subject / reason | Accounting effect | Output vector AR-O01..O05 | Next action |
| --- | --- | --- | --- | --- | --- |
| FT-01 | C1 handoff missing/shape/path mismatch | `C2Check:C1Handoff` / `InvalidSchema`, `UnsafePath`, or `IdentityMismatch` | contract failure + issue | F,F,F,F,D | Fix C1 handoff; no C3-C6/Phase B |
| FT-02 | Ledger/schema/vocabulary/approval invalid | exact registry artifact ID AR-I02, AR-I04, AR-I05, AR-I06, or AR-I11 / `InvalidSchema` | contract failure + issue | F,F,F,F,D | Fix the reviewed contract or approval artifact |
| FT-03 | Any required input content/hash/fingerprint stale | `C2Check:Freshness` / `StaleFingerprint` | contract failure + issue | F,F,F,F,D | Regenerate approved fixture evidence |
| FT-04 | Unsafe path or machine-path leakage | offending artifact/row fallback ID / `UnsafePath` | row subject: rejected observation + input failure + issue; artifact subject: contract failure + input failure + issue | F,F,F,F,D | Remove leakage and rerun |
| FT-05 | Malformed raw observation | HI-02 row ID; if parsing fails before rows exist, exact AR-I07/08/09 registry artifact ID / `InvalidObservation` | row: rejected observation + input failure + issue; whole document: contract failure + input failure + issue | F,F,F,F,D | Correct fixture row/artifact |
| FT-06 | File outcomes conflict | file conflict HI-11 / `ConflictDetected` | one file conflict record + input failure + issue | F,F,F,F,D | Diagnose tool results |
| FT-07 | Object identity/material conflict | observation conflict HI-11 / `ConflictDetected` | one observation conflict + input failure + issue | F,F,F,F,D | Diagnose tool mapping/results |
| FT-08 | Configuration conflict | configuration conflict HI-09 / `ConflictDetected` | one configuration conflict + input failure + issue | F,F,F,F,D | Resolve disposition evidence |
| FT-09 | Canonical overlap/evidence conflict | canonical conflict HI-10 / `ConflictDetected` | one canonical conflict + input failure + issue | F,F,F,F,D | Resolve grouping evidence |
| FT-10 | Any SP conservation equation or canonical-provenance one-to-one/count/uniqueness invariant fails | `C2Check:Conservation` / `ConservationMismatch` | one contract failure + issue regardless of how many invariant details fail | F,F,F,F,D | Correct producer/validator; do not attempt canonical grouping |
| FT-11 | Required AR-S12 missing, stale, or non-exact | `C2Check:PublicProjection` / `ProjectionInvalid` | contract failure + issue | F,F,F,F,D | Regenerate exact AR-S12; C0/G5 remains blocked |
| FT-12 | Output staging/write/hash/validation/publish-lock/replacement/rollback/quarantine failure | failing AR-O ID or publication transaction / `ProjectionInvalid` | any failure before a diagnostic can persist creates five logical terminal-reported rows; an ordinary gate failure with a successfully published diagnostic creates four suppressed output rows | F,F,F,F,F and 0/5/0 for transaction failure; F,F,F,F,D only for an ordinary non-FT-12 failure | Repair publisher/output path; no downstream |
| FT-13 | Lightweight gate attempts extraction/Unity/heavy child | `C2Check:LightweightPolicy` / `HeavyOperationAttempted` | contract failure + issue | F,F,F,F,D | Remove heavy invocation |
| FT-14 | Approved valid observation exclusion | accepted-shape row HI-03 / `ApprovedInputExclusion` | input exclusion, not failure; requires one exact AR-I11 HI-15 approval bound to the current AR-I07 blob | Does not fail alone; remains in SP formulas | Human review; never hide excluded subject |
| FT-15 | Contract check prerequisite unavailable | exact affected `C2Check:*` ID / `PrerequisiteUnavailable` | one `inputSuppressions` row + NotEvaluated; not a failure or issue | Does not determine vector; the prerequisite failure already does | Resolve the prerequisite's owning failure |

`F` means failed/suppressed and is represented in persisted `outputFailures` when AR-O05 exists, otherwise by FT-12 terminal-only logical rows; `D` means diagnostic-only AR-O05. A failed transition never yields a downstream-valid artifact even if a stale file exists on disk.

### Failure accounting subregistry

For every persisted accounting row, `owningArray` is literal `inputFailures`, `inputExclusions`, `inputSuppressions`, or `outputFailures`. `attribution` is the literal FT ID, literal `:`, then exact `subjectId`. Evidence is the distinct Ordinal-sorted set of directly implicated portable artifact paths; it is empty only for FT-15 with no available prerequisite path or terminal-only AR-O05 write failure. These rules are part of HI-12.

| FT | owningArray / subjectKind | subjectId | evidence source |
| --- | --- | --- | --- |
| FT-01 | inputFailures / C1Handoff | `C2Check:C1Handoff` | AR-I01 |
| FT-02 | inputFailures / C1Ledger, SchemaDocument, or ExclusionApprovalDocument | exact registry artifact ID | failing AR-I02/I04/I05/I06/I11 path |
| FT-03 | inputFailures / FreshnessCheck | `C2Check:Freshness` | every mismatched registry path |
| FT-04 row | inputFailures / matching raw observation kind | HI-02 row ID | offending path; counts once as `rejectedInputObservationCount` |
| FT-04 artifact | inputFailures / PublicProjection | exact artifact ID | offending path; counts once as `contractFailureRecordCount` |
| FT-05 row | inputFailures / ObjectObservation, FileDiscoveryObservation, or FileConfigurationObservation | HI-02 row fallback ID | containing observation artifact path |
| FT-05 document | inputFailures / ObservationDocument | exact AR-I07, AR-I08, or AR-I09 registry artifact ID | containing observation artifact path; replaces that artifact subject's Accepted state, counts once as `contractFailureRecordCount`, and creates no raw-row subject |
| FT-06 | inputFailures / FileDiscoveryConflict | HI-11a ID | union of conflict evidence |
| FT-07 | inputFailures / ObservationConflict | HI-11b ID | union of conflict evidence |
| FT-08 | inputFailures / ConfigurationConflict | HI-09c ID | union of conflict evidence |
| FT-09 | inputFailures / CanonicalConflict | HI-10c ID | union of conflict evidence |
| FT-10 | inputFailures / ConservationCheck | `C2Check:Conservation` | AR-O05 sidecar path |
| FT-11 | inputFailures / PublicProjection | `C2Check:PublicProjection` | AR-I06 and AR-S12 paths |
| FT-12 transaction | terminal-only / OutputArtifact | each of AR-O01 through AR-O05 | directly failing TEMP/output/lock path when available; otherwise empty because persistence is unavailable |
| FT-13 | inputFailures / LightweightPolicy | `C2Check:LightweightPolicy` | invoked script path |
| FT-14 | inputExclusions / ObjectObservation | excluded row HI-03 | exact distinct Ordinal-sorted union of AR-I07 path, AR-I11 path, and the matched approval row's `evidence`; no raw observation evidence is added implicitly |
| FT-15 | inputSuppressions / ContractCheck | exact affected `C2Check:*` ID | available prerequisite evidence, possibly empty; counts once as `notEvaluatedInputSubjectCount` |

`reasonCode` is exactly the reason shown in the parent FT row. When an FT row lists several reasons, choose by fixed predicate order: schema/shape → `InvalidSchema`; path → `UnsafePath`; identity → `IdentityMismatch`. No row may be attributed to two FT transitions for the same direct failure.

Derived output-failure rows use only `SuppressedByGate`. On any ordinary FT-01..11/13 failure, AR-O01..04 each gets `SuppressedByGate`, attribution `SuppressedByGate:` plus its AR ID, and evidence equal to the union of all direct failure evidence. FT-12 never publishes AR-O05 and therefore its five logical `ProjectionInvalid` rows are terminal-only; it cannot truthfully persist derived suppression rows.

`issueCount` equals the number of inputFailures plus the number of outputFailures whose reason is neither suppression reason. Output suppression never creates an extra issue. For multiple direct failures, sort rows by numeric FT ID then Ordinal subjectId. `decision.failureAttribution` is their attribution strings joined by literal `;` in that order; `decision.nextAllowedAction` is the parent-table next action of the first row. With no direct failure, attribution is `None; C2 registry-derived gates passed.` and next action is `Provide C2 outputs to C3-C6 Phase A; C0/G5 remains blocked by AR-S12.`

---

## Registry-Derived Positive Seed And Fixed Counterexamples

### P0 positive seed

P0 is a pure HI-13b unit vector, not a gate run, partition seed, artifact-read claim, or authorization result. Its input is exactly the six registered `(portable path, exact SHA-256)` pairs for AR-I01 through AR-I06. AR-I07 through AR-I11 do not participate. The unit test encodes those six already-known pairs in memory, sorts them with `System.StringComparer.Ordinal`, and must produce:

```text
discoveryInputFingerprint=5735b77581382fadec024ce5abc805f28542349241d479050788f08545a91bfd
```

P0 asserts only HI-13a/HI-13b byte framing, nesting, ordering, and digest output. It has no file, byte, observation, contract-check, failure, output-vector, or gate-status counters. No implementation may cite P0 as proof that AR-I01-I06 were read, fresh, schema-valid, conserved, projected, or safe. Hardcoded repeated-character output hashes remain forbidden.

### Mandatory counterexample matrix

**P1 simultaneous-set fixture:** this is the AR-I07 counterexample document, AR-I11 exclusion approval artifact, and AR-I10 manifest. AR-I10 contains exactly AR-I07 and AR-I11 with their exact frozen-commit blob SHA-256 values; all three are tracked in the same reviewed commit. Aliases below name rows, while HI IDs are recomputed from their exact fields. Every row has the complete AR-S02 key set. Common values are `schemaVersion=1.0.0`, C1 snapshot/fingerprint from AR-I02, `sourceId=pc-install-primary`, `containerRelativePath=SourceCorpus/PcInstall/game-data.bundle`, `toolVersion=1.0.0`, `serializedSizeBytes=100`, empty dependency list, `configurationDisposition=Parsed`, null canonical evidence, ExactLocator correlation, and one evidence path made by concatenating literal `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/`, the row alias, and literal `.json`.

| Alias | toolName | pathId | classId | objectType | objectName | contentFingerprint | Expected raw partition |
| --- | --- | --- | --- | --- | --- | --- | --- |
| r1 | ToolA | 10 | 1 | Sprite | Hero | 64 `1` hex digits | Accepted |
| r2 | ToolB | 10 | 1 | Sprite | Hero | 64 `1` hex digits | Accepted; agrees with r1 |
| r3 | ToolA | 20 | 1 | Sprite | Conflict | 64 `2` hex digits | Accepted |
| r4 | ToolB | 20 | 1 | Mesh | Conflict | 64 `2` hex digits | Accepted; material conflict with r3 |
| r5 | ToolA | 30 | -1 | Sprite | Rejected | 64 `3` hex digits | FT-05 Rejected; complete key set and null `observationId`, but CT-06-invalid classId |
| r6 | ToolA | 40 | 1 | Sprite | Excluded | 64 `4` hex digits | FT-14 Excluded |

Rows r1-r4 and r6 have non-null independently recomputed HI-03 values. Row r5 has every AR-S02 key, `observationId=null`, and uses HI-02 after its negative `classId` prevents HI-03 acceptance. AR-I11 contains exactly one approval for r6: `subjectKind=ObjectObservation`, `subjectId=<r6 HI-03>`, `reasonCode=ApprovedInputExclusion`, `reason=Reserved synthetic exclusion counterexample.`, `approvedBy=C2FixtureReview`, `approvedAt=2026-07-12T00:00:00Z`, and `evidence=[Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r6-exclusion-approval.md]`. Its `approvalId` is the exact HI-15 digest of those fields. The resulting FT-14 accounting evidence is exactly the Ordinal-sorted set of the AR-I07 path, AR-I11 path, and that approval evidence path.

The P1 file set also includes `fUnknown` (the AR-I02 UnknownInput row, 4096 bytes) and a synthetic `fConfig` row with the same source/snapshot, `relativePath=Config/table.json`, `containerKind=ConfigurationCandidate`, `sizeBytes=8`, SHA-256 of 64 `5` digits, both extraction fields NotAttempted, empty evidence, and standard C1 status. The two accepted claims r1/r2 form one target and agree on Parsed. Their canonical evidence is null.

The required instantiated partitions are:

```text
SP-01: files={fUnknown,fConfig}; Container={fUnknown}; NonContainer={fConfig}; 2=1+1; 4104=4096+8
SP-02: subjects={fUnknown,fConfig}; NotAttempted={fConfig}; Parsed={fUnknown:CrossToolVerified}; other partitions empty; 2=1+1+0+0+0; container counts 1=0+1+0+0+0 and bytes 4096=0+4096+0+0+0
SP-03a: rows={r1,r2,r3,r4,r5,r6}; Accepted={r1,r2,r3,r4}; Rejected={r5}; Excluded={r6}; 6=4+1+1
SP-03b: groups={gResolved,gConflict}; Resolved={gResolved}; Conflict={gConflict}; 2=1+1
SP-04: objects={oResolved}; Classified={oResolved}; Unclassified={}; 1=1+0
SP-05: targets={fConfig,oResolved}; Candidates={fConfig:DiscoveredOpaque,oResolved:Parsed}; Conflicts={}; 2=2+0; 2=1+1+0+0+0+0
SP-06: subjects={oResolved}; Canonicalized={oResolved}; Conflicts={}; groups={oResolved:Unresolved}; 1=1+0; 1=0+0+1
SP-07: gate Failed, eligible={}; Assigned/Retained/ConfigurationOnly={}; 0=0+0+0
SP-08: base subjects=10 read artifacts (AR-I01-I08+AR-I10+AR-I11)+8 raw rows (AR-I07 r1-r6 plus both accepted AR-I08 rows)+5 contract checks; derived conflict subject={gConflict}; total=24; Accepted=21 (10 artifacts+4 accepted AR-I07 rows+2 accepted AR-I08 rows+5 checks); Failure={r5,gConflict}; Excluded={r6}; NotEvaluated={}; 24=21+2+1+0; observations 8=6+1+1; failures 2=1+0+0+1+0+0. The accepted AR-I08 subjects are `file-discovery-observation-sha256:195be146f0f08df54c160fbccf1c790bc1fbd535b6626976e1981344031b3e80` with evidence `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toola-file-readable.json` and `file-discovery-observation-sha256:19e7158715bf0dd0807da34dddfa744b9d205a3d3e1273ea5185f217b426b5c4` with evidence `Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/toolb-file-readable.json`. SP-02 may merge both observations into one file result, but SP-08 accounts for their distinct raw identities independently. Conservation and PublicProjection are Accepted because all negative direct subjects are fully partitioned and their diagnostic/private projections are exact; a negative row or conflict is not by itself an unavailable prerequisite.
SP-09: ordinary Failed; Projected={AR-O05}; Failure={AR-O01,AR-O02,AR-O03,AR-O04}; Exclusion={}; 5=1+4+0
```

**Canonical collision fixture:** ExactDuplicate group A has member IDs `sha256:` plus 64 `a` digits and `sha256:` plus 64 `b` digits; group B uses 64 `c` and 64 `d` digits. Both have `matchStatus=ExactDuplicate`, `platformScope=PcOnly`, and equivalence fingerprint of 64 `1` digits. HI-10a must produce different canonical IDs because it encodes the member sets. Removing `memberObjectIds` from the preimage must make this counterexample fail.

**FT output vectors:** FT-01 through FT-11 and FT-13 are exactly `F,F,F,F,D` with 1/4/0 when the diagnostic transaction succeeds. Any FT-12 transaction failure is `F,F,F,F,F` with 0/5/0 and terminal-only logical accounting. FT-14 alone remains Passed only when every SP equation includes the exclusion. FT-15 never determines a vector; its prerequisite's owning failure does.

| Case | Registry derivation and expected transition |
| --- | --- |
| null/empty/missing/unknown/unsupported | Null canonical evidence → SP-06 Unresolved; private null configuration → public NotConfiguration/outside SP-05; missing required field → FT-05; unknown container kind → SP-01 Container; unsupported vocabulary → FT-02 |
| zero/one/many, duplicate/order/case | Zero observation config file → SP-05 DiscoveredOpaque; one canonical member → Unresolved; ExactDuplicate requires >=2; duplicate IDs/path case collision → FT-02/05; shuffled sets produce same HI digest |
| tool agreement/conflict | Single tool → resolved readable; multiple identical → Agreed/CrossToolVerified; differing file/object/config/canonical results → FT-06/07/08/09 exactly once |
| canonical overlap | Each object belongs to one group or one conflict, never both; overlap → FT-09; all SP-06 formulas remain true |
| stale child | Change/add/remove any AR-I entry → input fingerprint changes/FT-03; current staged AR-O01-O04/report/sidecar hash mismatch → FT-12 before publish; post-publish mutation makes the generation consumer-invalid and requires quarantine/rerun, never FT-03 |
| dual extraction contradiction | schema-valid unequal `parseStatus` and `status.extraction` → FT-02; never two partitions |
| malformed raw row | HI-02 from file SHA+row index supplies accounting identity; unparseable document uses artifact identity; FT-05 |
| every failure stage | FT-01..11/13 ordinary vector and FT-12 transaction vector are checked exactly; FT-15 accounting is checked separately; downstream-valid output count is zero on Failed |
| simultaneous conservation | One constructed fixture must satisfy SP-01 through SP-09 formulas together; mutations break exactly the designated parent formula |
| heavy invocation | Any extraction/Unity/real-root process attempt → FT-13 and zero downstream authorization |

Keyword scans are not acceptance evidence. Design review must instantiate the sets above and recompute identities, partitions, output vectors, and formulas from scratch.

---

## Planned Implementation Decomposition

An implementation plan **may contain two or more sequential Tasks** when it must freeze their dependency, file boundaries, verification, and stop checkpoints together. Plan containment is not execution authorization: only one Task may be authorized and executed per review round unless the user explicitly grants continuous multi-Task execution. Every Task remains 20–30 minutes, every Step 2–5 minutes, and every Step cites the Artifact, Subject, and Failure IDs it exercises.

The authoritative sequence is:

1. Freeze AR-I07, AR-I10, and AR-I11 fixture authority in one reviewed commit; no harness or implementation.
2. Implement AR-I01–I11 intake/freshness, HI-13, O1/O2, and the frozen Git adapter; no SP-01/SP-02.
3. Implement SP-01/SP-02 in a separately approved fixture-only Task.
4. Implement SP-03/SP-04 object resolution and public projection.
5. Implement SP-05 configuration discovery.
6. Implement SP-06 canonical grouping.
7. Implement SP-07 dispatch and SP-08 accounting; complete through `c40a6b7fe1dc8368945d9fc802c166fa12c9d587`.
8. Implement SP-09 deterministic output construction, journaled publication/recovery, and locked consumer validation through the separately reviewed SP-09 plan.
9. Write the C2 Phase B runbook without executing it.

SP-09 remains `BLOCKED` until its publication amendment and plan pass independent read-only review. Approval then authorizes only the specifically named SP-09 Task; it never authorizes C3-C6, G5, Unity, extraction, import, real assets, or Phase B.
