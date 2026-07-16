# StellaSora Asset Corpus C3-C6 Lifecycle Qualification Design

**Date:** 2026-07-15
**Status:** Approved responsibility and input/output contract design; documentation only; implementation unauthorized
**Baseline:** `codex/asset-corpus-integration` at `d2b5247f07d776bb94214ec6c6ecde1b01f570a5`
**Scope:** C3 family construction, C4 static qualification, C5 representative/evidence assessment, C6 authoring decisions and ledger projection. No implementation, schema edit, C2 edit, C7/G4 execution, G5 implementation, Unity, extraction, import, real assets, or Phase B.

## Purpose And Architecture Decision

C3-C6 use one lifecycle spine with five strongly typed lane policies. The five lanes are not five independently interpreted gate implementations.

```text
C2 AR-O01/02/03/04/05 plus typed lane facts and policy registry
-> C3 family membership and cross-lane references
-> C4 complete member static qualification
-> C5 representative requirements and evidence assessment
-> C6 authoring decisions, authoring reuse ledger, capability projection, G5 handoff
-> G5 lightweight aggregation
```

C7/G4 is an external evidence producer only:

```text
C5 requirements
-> separately authorized C7/G4 execution
-> immutable evidence packages
-> C5 evidence reassessment
-> C6 ledger refresh
-> G5 refresh
```

This is not an architecture cycle. C7/G4 cannot change C3 family identity or membership, C4 static results, lane policy, C6 decision rules, or capability rules. It can only add a fingerprinted evidence package for an existing C5 requirement.

The four component responsibilities are exclusive:

| Component | Sole responsibility | Explicit non-responsibilities |
|---|---|---|
| C3 Family Registry Gate | Decide the single direct family parent or non-family partition for every C2 dispatch subject; record cross-lane references | No static pass/fail, representative selection, Unity evidence acceptance, or reuse decision |
| C4 Static Qualification Gate | Produce one terminal static result for every required check of every C3 family member | No family reassignment, representative selection, Unity execution, or reuse decision |
| C5 Representative Coverage And Evidence Gate | Derive risk-variant and capability-suitability requirements, deterministically select representatives, and assess immutable C7/G4 evidence | No Unity execution, family/static mutation, or reuse decision |
| C6 Authoring Decision And Ledger Gate | Validate freshness/conservation, apply frozen decisions, assemble the only authoring reuse ledger, and publish the only C3-C6 handoff to G5 | No asset inspection, child rerun, evidence generation, or G5 conclusion |

The three central registries below are authoritative. Later prose may explain them but cannot redefine artifact shapes, identities, subject universes, partitions, formulas, policy semantics, or failure ownership.

---

## Central Definition 1: Artifact Registry

### 1.1 Registry index

Phase A fixture paths use the fixed root `Tools/AssetImport/Fixtures/FamilyQualificationGate`. A future real generation root requires a separate reviewed contract. No real data may be copied into these fixture paths.

| ID | Role | Phase A portable path or authority | Producer | Consumers | Success/failure rule |
|---|---|---|---|---|---|
| LC-I01 | C2 public ledger | C2 AR-O01 registered path | C2 | C3/C4 | Required Passed locked C2 generation |
| LC-I02 | C2 configuration package | C2 AR-O02 registered path | C2 | C3/C4 | Required Passed locked C2 generation |
| LC-I03 | C2 canonical package | C2 AR-O03 registered path | C2 | C3/C4 | Required Passed locked C2 generation |
| LC-I04 | C2 dispatch | C2 AR-O04 registered path | C2 | C3 | Required Passed locked C2 generation |
| LC-I05 | C2 diagnostic summary | C2 AR-O05 registered summary | C2 | C3-C6 freshness | Must be Passed and bind LC-I01-I04 |
| LC-I06 | Typed lane-fact package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c2-lane-fact-package.json` | Pure fixture-only C2 typed projection | C3-C5 | Frozen projection is implemented and fixture-verified; it is not an SP-09 publication output, and C3 consumes it only in the reviewed fixture-only path |
| LC-I07 | Lane policy registry | `docs/asset-migration/schemas/c3-c6-lane-policy-registry.json` | C0 contract Task | C3-C6 | Runtime registry, strict JSON Schema, byte-identical positive fixture, focused negative fixtures, and executable contract validation are implemented; consumers compute its exact-byte fingerprint externally |
| LC-I08 | Status vocabulary | `docs/asset-migration/schemas/status-vocabulary.json` | C0 | C3-C6 | Required exact accepted C0 artifact |
| LC-I09 | C7/G4 evidence manifest | `Tools/AssetImport/Fixtures/FamilyQualificationGate/c7-evidence-manifest.json` | Reviewed fixture authority or future Phase B approval | C5 | Optional; absence means no evidence packages, never evidence acceptance |
| LC-I10 | C7/G4 evidence packages | paths listed exactly by LC-I09 | C7/G4 | C5 | Each package must match manifest path/SHA and requirement identity |
| LC-I11 | Decision/capability registry | `docs/asset-migration/schemas/c3-c6-decision-policy-registry.json` | C0 contract Task | C5/C6 | Runtime registry, strict JSON Schema, byte-identical positive fixture, focused negative fixtures, and executable contract validation are implemented; consumers compute its exact-byte fingerprint externally |
| LC-I12 | Repair-attempt history | `Tools/AssetImport/Fixtures/FamilyQualificationGate/repair-attempt-history.json` | Reviewed repair workflow | C6 | Required exact artifact; an empty attempts array means no attempt, absence never means zero |
| LC-I13 | Typed lane-fact schema | `docs/asset-migration/schemas/c2-lane-fact-package.schema.json` | C0/C2 contract Task | LC-I06/C3 | Contract frozen with valid and negative fixture coverage; `factContractFingerprint` is its exact-byte SHA-256; the fixture-only LC-I06 producer now consumes its exact bytes |
| C3-O01 | Family registry | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-registry.json` | C3 | C4-C6 | Passed only; suppressed on C3 contract failure |
| C3-O02 | Family-member ledger | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-member-ledger.json` | C3 | C4-C6 | Passed only; contains every LC-I04 subject exactly once |
| C3-O03 | Cross-lane reference package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-cross-lane-reference-package.json` | C3 | C4-C6 | Passed only; references never create membership |
| C3-O04 | C3 diagnostic bundle | `valid-c3-summary.json` and `valid-c3-report.md` under the fixture root | C3 | Humans/C4 freshness | Always attempted; diagnostic-only on Failed |
| C4-O01 | Member static qualification package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-member-static-qualification.json` | C4 | C5/C6 | Passed contract execution only; asset failures remain valid rows |
| C4-O02 | Family static summary | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-static-summary.json` | C4 | C5/C6 | Passed contract execution only |
| C4-O03 | C4 diagnostic bundle | `valid-c4-summary.json` and `valid-c4-report.md` | C4 | Humans/C5 freshness | Always attempted; diagnostic-only on Failed |
| C5-O01 | Representative and suitability requirement package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-representative-requirements.json` | C5 | C7/G4/C6 | Passed contract execution only; may contain missing/unavailable outcomes |
| C5-O02 | Risk and suitability evidence assessment package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-evidence-assessment.json` | C5 | C6 | Passed contract execution only |
| C5-O03 | C7 evidence request | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c7-evidence-request.json` | C5 | C7/G4 planning | Passed contract execution only; never launches C7/G4 |
| C5-O04 | C5 diagnostic bundle | `valid-c5-summary.json` and `valid-c5-report.md` | C5 | Humans/C6 freshness | Always attempted; diagnostic-only on Failed |
| C6-O01 | Authoring reuse ledger v2 | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-authoring-reuse-ledger.json` | C6 | G5 | Passed only; current C0 schema cannot represent it losslessly |
| C6-O02 | Family decision package | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-family-decision-package.json` | C6 | Humans/G5 audit | Passed only |
| C6-O03 | Capability projection | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-capability-projection.json` | C6 | G5 | Passed only |
| C6-O04 | G5 handoff | `Tools/AssetImport/Fixtures/FamilyQualificationGate/valid-c3-c6-g5-handoff.json` | C6 | G5 | Passed only; only C3-C6 input G5 may consume |
| C6-O05 | C6 diagnostic bundle | `valid-c6-summary.json` and `valid-c6-report.md` | C6 | Humans | Always attempted; diagnostic-only on Failed |

All JSON rejects additional properties. All sets are duplicate-free and Ordinal sorted. All artifact paths are slash-normalized portable paths. All JSON uses the C2 CT-15 byte format. All new lifecycle artifacts use `schemaVersion=1.0.0` except C6-O01, whose incompatible authoring-ledger shape requires `schemaVersion=2.0.0`. A stage-generated timestamp is one UTC `generatedAt` value reused in every artifact of that stage generation.

Stable artifact identity is the registry ID plus its exact portable path. Content fingerprint is SHA-256 over exact artifact bytes. Moving a file changes artifact identity; changing bytes changes content fingerprint. A diagnostic bundle is one logical output whose content fingerprint covers its summary and report path/SHA entries.

The lifecycle package prefix is exactly `schemaVersion`, `generatedAt`, `snapshotId`, `inputFingerprint`, `policySetFingerprint`, in that order. The C5/C6 support-package prefix appends `decisionPolicyFingerprint`. A phrase such as “same prefix” below always means the applicable exact sequence; no additional envelope or payload exists.

Direct input sets are exact:

- C3 reads LC-I01 through LC-I08 and LC-I13.
- C4 reads C3-O01/O02/O03 and both C3-O04 components, plus LC-I01/I02/I03/I06/I07/I08/I13.
- C5 reads C3-O01/O02/O03 and both C3-O04 components, C4-O01/O02 and both C4-O03 components, plus LC-I06/I07/I08/I11/I13. When LC-I09 is present, it and every listed LC-I10 package also participate; when absent, neither LC-I09 nor any LC-I10 package participates, selected risk representatives lacking evidence evaluate EvidenceMissing, and selected suitability representatives lacking evidence evaluate SuitabilityMissing.
- C6 reads C3-O01/O02/O03 and both C3-O04 components, C4-O01/O02 and both C4-O03 components, C5-O01/O02 and both C5-O04 components, plus LC-I07/I08/I11/I12. C5-O03 is not a decision input.

Each stage LX-HI-14 fingerprint contains every and only its direct input set. A missing extra, duplicate, or unregistered direct input is LF-01 or LF-03; it is never ignored.

### 1.2 Common typed lane-fact contract: LC-I06

Top level is exactly:

```text
schemaVersion
generatedAt
snapshotId
c2GenerationFingerprint
factContractFingerprint
inputFingerprint
rows
```

Each row is exactly:

```text
factId
assetObjectId
lane
factKind
factStatus
valueKind
stringValue
integerValue
booleanValue
idValues
evidence
```

`lane` is exactly `Audio`, `Environment`, `Actor`, `UI`, or `Effects`. `factStatus` is `Known`, `Unknown`, or `NotApplicable`. `valueKind` is `String`, `Integer`, `Boolean`, or `IdSet`.

Every key is always present. Carrier rules are exact:

- Known/String: nonempty `stringValue`; integer/boolean null; empty ID set.
- Known/Integer: nonnegative `integerValue`; string/boolean null; empty ID set.
- Known/Boolean: boolean non-null; string/integer null; empty ID set.
- Known/IdSet: nonempty Ordinal ID set; all scalar carriers null.
- Unknown or NotApplicable: every scalar carrier null and `idValues` empty.

One `(assetObjectId,factKind)` pair appears at most once. A policy-required Unknown fact prevents family assignment. NotApplicable is legal only when the policy fact definition explicitly allows it. LC-I06 is a typed projection of already discovered structured facts; it may not read raw assets, run static qualification, or infer success from path/name heuristics.

The registered fact kinds are exactly:

```text
ObjectType
ClassId
CanonicalAssetId
PlatformVariant
DependencyObjectIds
AudioEncoding
BankStructureId
EventStructureId
LoopMode
ChannelLayout
SampleRate
EnvironmentThemeId
EnvironmentModuleType
RendererType
ShaderFamilyIds
PrefabDependencyShapeId
MeshTopologyId
LightmapMode
ColliderMode
NavMeshMode
ActorRole
SkeletonId
AvatarId
AnimationSetShapeId
ControllerReferenceState
UiRouteKind
AtlasId
FontDependencyIds
TextureFormat
EffectSystemKind
AudioDependencyIds
```

Adding or renaming a fact kind requires a reviewed LC-I06 and LC-I07 contract revision. An arbitrary fact name is invalid.

#### 1.2a LC-I06 fixture-projection sub-contract

Phase A uses one pure `FixtureProjection` adapter. It creates the expected LC-I06 bytes in memory and compares them with the checked-in LC-I06 fixture. It does not write a registered C2 consumer path, alter AR-O01 through AR-O05, acquire the SP-09 publication lock, or change the eight-file SP-09 transaction. Any future published or real-generation LC-I06 requires a separate reviewed publication contract.

The adapter has exactly three byte inputs:

1. C2 AR-O04 at `Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json` from one already accepted, lock-validated C2 generation;
2. the matching C2 AR-O05 summary at `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json`;
3. LC-I13 at `docs/asset-migration/schemas/c2-lane-fact-package.schema.json`.

No AR-O01/02/03 bytes, observation document, raw asset, lane policy, filename, object name, path heuristic, Unity result, or real source is an adapter input. The accepted AR-O05 summary must be Passed and its current generation must bind AR-O04 through the existing C2 consumer-validation contract. The adapter never treats bare path existence as acceptance.

LC-I06 top-level identity is exact:

- `schemaVersion` is `1.0.0`;
- `generatedAt` and `snapshotId` equal both accepted AR-O04 and AR-O05 values;
- `c2GenerationFingerprint` equals AR-O05 `identity.discoveryArtifactFingerprint` exactly;
- `factContractFingerprint` is CT-04 SHA-256 over exact LC-I13 bytes;
- `inputFingerprint` is LX-HI-14 over exactly the three path/SHA entries above, with no fourth entry and no display constant.

The dispatch subject universe is every AR-O04 row. It partitions exactly:

```text
dispatchSubjectCount
= projectedAssignedObjectCount
 + retainedNoLaneFactObjectCount
 + configurationNoLaneFactObjectCount
```

- `projectedAssignedObjectCount`: `dispatchStatus=Assigned`, `familyLane` is one of the five LC-I06 lanes, and `configurationCandidateId=null`.
- `retainedNoLaneFactObjectCount`: `dispatchStatus=RetainedForDiagnosis`, `familyLane=Unassigned`, and `configurationCandidateId=null`.
- `configurationNoLaneFactObjectCount`: `dispatchStatus=ConfigurationOnly`, `familyLane=Unassigned`, and `configurationCandidateId` is non-null.

Only ProjectedAssigned subjects produce lane-fact rows. The other two partitions remain terminally accounted by AR-O04 and produce zero LC-I06 rows; `Unassigned` is never coerced to a business lane. Duplicate object IDs, any other status/lane/configuration combination, or an AR-O04 row not owned by exactly one partition is a contract failure and suppresses the complete LC-I06 package.

For each ProjectedAssigned subject, the adapter accepts exactly one `ObjectType`, one `ClassId`, one `CanonicalAssetId`, one `PlatformVariant`, zero or more `DependencyObjectId`, and one or more `ToolObservation` selector rows. Selector pairs are already duplicate-free and Ordinal sorted by AR-S09; the adapter revalidates rather than repairs them. It projects only these registered facts:

| AR-O04 selector input | LC-I06 factKind | Exact carrier |
|---|---|---|
| one ObjectType | ObjectType | Known/String, exact selector value |
| one ClassId | ClassId | Known/Integer, selector must be canonical nonnegative base-10 and parse losslessly as Int64 |
| one CanonicalAssetId | CanonicalAssetId | Known/String, exact selector value |
| one PlatformVariant | PlatformVariant | Known/String, exact selector value |
| one or more DependencyObjectId | DependencyObjectIds | one Known/IdSet row containing the distinct Ordinal selector values |

Zero DependencyObjectId selectors produce no DependencyObjectIds row because LC-I13 deliberately forbids an empty Known/IdSet. For this one fact kind, absence plus the accepted AR-O04 selector set means known empty; it is not Unknown or NotApplicable. C3 already consumes AR-O04 directly and must use that authoritative empty set when constructing references. ToolObservation remains AR-O04 evidence/selector input and has no LC-I06 factKind, so it produces no fact row.

Every projected row copies `assetObjectId`, `familyLane`, and the complete AR-O04 evidence set; uses the carrier above; computes `factId` by LX-HI-01; and is sorted Ordinal by `factId`. The adapter emits no Unknown or NotApplicable row and emits none of the remaining registered fact kinds. Missing is not silently converted into either status; later LC-I07 consumers must treat a missing required fact as unproven.

The pure adapter result is exactly `gateStatus`, nullable `package`, `subjectAccounting`, `inputFailures`, `outputsSuppressed`. Each subject-accounting row is exactly `assetObjectId`, `terminalStatus`, `factIds`, `reasonCode`, `evidence`, sorted by assetObjectId. `terminalStatus` is `AssignedFactsProjected`, `RetainedNoLaneFacts`, or `ConfigurationNoLaneFacts` on Passed. `reasonCode` equals the terminal status. Fact IDs are the subject's complete Ordinal LC-I06 ID set and are empty for both no-fact partitions.

Each inputFailures row reuses C2 AR-S10 exactly: `recordId`, `subjectKind`, `subjectId`, `reasonCode`, `attribution`, `evidence`; `recordId` is existing C2 HI-12 with owningArray `inputFailures`. SubjectKind is exactly `Artifact`, `DispatchObject`, or `ProjectionCheck`. Artifact subject IDs are AR-O04, AR-O05-Summary, or LC-I13; DispatchObject uses the exact assetObjectId; ProjectionCheck uses `LC-I06:Projection`. ReasonCode is exactly `InvalidSchema`, `IdentityMismatch`, `ConservationMismatch`, or `ProjectionInvalid`. Predicate ownership is fixed: missing/shape/schema/carrier -> InvalidSchema; accepted-generation or fingerprint mismatch -> IdentityMismatch; dispatch partition/selector/duplicate/order equation -> ConservationMismatch; fact identity/canonical bytes/fixture comparison -> ProjectionInvalid. Attribution is `LC-I06:` plus subjectId. Evidence is the distinct Ordinal set of available direct-input paths supporting that failure.

On any input identity/freshness/schema/shape failure, invalid dispatch partition, selector contradiction, carrier failure, duplicate `(assetObjectId,factKind)`, identity mismatch, nondeterministic order, or fixture-byte mismatch, `gateStatus=Failed`, `package=null`, `outputsSuppressed=true`, and one or more exact inputFailures identify the artifact, object, or output check. There is no partial package and subjectAccounting is empty on Failed. On Passed, inputFailures is empty, outputsSuppressed is false, every dispatch subject has one accounting row, the partition equation holds, and the union of accounting factIds equals LC-I06 rows exactly.

The producer Task must prove at least: all three direct inputs affect `inputFingerprint`; schema byte changes affect `factContractFingerprint`; AR-O05 fingerprint changes affect `c2GenerationFingerprint`; each of the five lanes projects without heuristics; zero/multiple required selectors fail closed; zero/one/multiple dependencies follow the rule above; RetainedForDiagnosis and ConfigurationOnly produce terminal zero-fact rows; fact IDs and canonical bytes are stable across repeated runs with identical accepted bytes; an input permutation that violates AR-S09 fails instead of being repaired; and Failed projection writes no fixture or publication state.

The common evidence-kind vocabulary is exactly:

```text
FileReadability
ObjectReadability
DependencyGraph
SerializedMetadata
DecoderProbe
PrefabYaml
MaterialShaderGraph
TextureMetadata
AudioMetadata
UnityImport
VisibleRender
AnimationPlayback
AudioPlayback
HumanListening
LoopBehavior
MaterialFidelity
UiConstruction
EffectBehavior
CapabilitySuitability
```

The common failure-class vocabulary is exactly:

```text
ReadFailure
MissingDependency
ShaderMismatch
MaterialMismatch
ImportSettingMismatch
ControllerMissing
DecodeFailure
SemanticUnknown
PrefabDependencyMissing
FontAtlasMissing
EffectBehaviorMissing
CoreDataMissing
```

The residual issue-class vocabulary is exactly:

```text
StaticFailure
UncheckedStatic
CrossLaneReferenceMissing
CrossLaneReferenceConflict
EvidenceMissing
EvidenceStale
UnityExecutionUnavailable
RepresentativeRejected
RepairPending
ReplacementBehavior
```

The route-kind vocabulary is exactly `OriginalAsset`, `PrototypeController`, `TextureOnlyRebuild`, `EffectBehaviorReconstructed`, or `DecodedAudio`. The static-check reason-code vocabulary is exactly `None`, `MissingInputFact`, `PrerequisiteFailed`, `ToolUnavailable`, `UnsupportedFormat`, `ReadFailure`, `DependencyMissing`, `ConflictDetected`, or `PolicyViolation`. Passed checks require `None`; Failed and Unchecked checks forbid `None`.

The repair expected-change-measure vocabulary is exactly `MissingDependencyCount`, `FailedCheckCount`, `ShaderMismatchCount`, `MaterialMismatchCount`, `DecodeFailureCount`, `SemanticUnknownCount`, or `VisibleIssueCount`. A repair rule selects exactly one measure. `requiredInputKinds` values resolve to registered factKind, evidenceKind, or artifact IDs; arbitrary text is invalid.

LC-I08 introduces these exact lifecycle dimensions at the first stage that directly consumes each one; `familyParentStatus` begins with C3, while later-stage dimensions remain deferred until C4, C5, or C6:

```text
familyParentStatus: AssignedFamilyMember, RetainedForDiagnosis, ConfigurationOnly
memberStaticStatus: StaticPassed, StaticFailed, Unchecked
representativeAssessment: RepresentativeRequired, EvidenceAccepted, EvidenceMissing, EvidenceStale, UnityExecutionUnavailable, RepresentativeRejected
authoringPoolStatus: AcceptedOriginalPool, AcceptedReplacementSourcePool, Isolated
capabilityStatus: Satisfied, Unsatisfied, Blocked
capabilitySuitabilityStatus: SuitabilityRequired, SuitabilityAccepted, SuitabilityMissing, SuitabilityStale, SuitabilityExecutionUnavailable, SuitabilityRejected
```

The existing `familyStaticOutcome` and `disposition` dimensions remain authoritative for family aggregates and C6 decisions. The new dimensions do not rename or overload them.

Enum-like fact allowedValues in the first policy version are exact:

| factKind | allowedValues |
|---|---|
| ObjectType | the union of the five applicableObjectTypes sets in Section 1.4 |
| PlatformVariant | Pc, Android, Unknown |
| AudioEncoding | PCM, Vorbis, Opus, ADPCM, AAC, WwiseProprietary |
| LoopMode | Looped, OneShot |
| ChannelLayout | Mono, Stereo, Multichannel |
| LightmapMode | Baked, Realtime, Mixed, Absent |
| ColliderMode | Present, Absent |
| NavMeshMode | Present, Absent |
| ActorRole | Player, Enemy, Other |
| ControllerReferenceState | Present, Missing, PrototypeRequired |
| UiRouteKind | OriginalPrefab, TextureRebuild |
| EffectSystemKind | ParticleSystem, VisualEffect, TrailRenderer, Mixed |

All other String/IdSet facts are registered stable identities and use empty allowedValues. Unknown is expressed by factStatus Unknown, never by inventing an unregistered enum value, except PlatformVariant where Unknown is already a C2 public value.

### 1.3 Strongly typed lane policy contract: LC-I07

Top level is exactly:

```text
schemaVersion
generatedAt
policySetId
policySetVersion
policies
```

For the first reviewed registry, `schemaVersion=1.0.0`, `generatedAt=2026-07-15T00:00:00Z`, `policySetId=StellaSoraLifecycleLanePolicySet`, and `policySetVersion=1.0.0`. These four values are part of the immutable versioned bytes. Reusing the same policySetId/policySetVersion with any changed byte is LF-03.

LC-I07 does not store its own fingerprint. `policySetFingerprint` in C3-C6 lifecycle outputs is CT-04 SHA-256 over the exact complete LC-I07 bytes. This removes the impossible self-referential hash while preserving exact-byte freshness. The future JSON Schema authority is `docs/asset-migration/schemas/c3-c6-lane-policy-registry.schema.json`; the positive contract fixture is `Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-c3-c6-lane-policy-registry.json` and must be byte-identical to LC-I07. Neither schema nor contract-test fixtures are lifecycle direct inputs.

There is exactly one policy row per lane. Each row is exactly:

```text
policyId
lane
policyVersion
familyKinds
factDefinitions
staticCheckDefinitions
riskAxisDefinitions
evidenceRequirementDefinitions
capabilityProjectionRules
repairRules
```

Nested rows have these exact shapes:

- family kind: `familyKindId`, `applicableObjectTypes`, `keyDimensionIds`, `memberSelectorKinds`.
- fact definition: `factKind`, `valueKind`, `requiredForFamilyKinds`, `allowedValues`, `allowNotApplicable`.
- static check definition: `checkId`, `applicableFamilyKinds`, `requiredFactKinds`, `outcomeOnMissingFact`, `requiredEvidenceKinds`.
- risk axis definition: `riskAxisId`, `applicableFamilyKinds`, `sourceFactKinds`, `variantEncoding`.
- evidence requirement definition: `evidenceRequirementId`, `applicableRiskAxisIds`, `requiredEvidenceKinds`, `acceptedExecutionStatuses`.
- capability projection rule: `capabilityId`, `applicableFamilyKinds`, `requiredRouteKinds`, `allowedFamilyDecisions`, `requiredEvidenceKinds`.
- repair rule: `repairClass`, `applicableFamilyKinds`, `requiredFailureClasses`, `requiredInputKinds`, `expectedChangeMeasure`, `maxAttempts`.

Every familyKindId, factKind, checkId, riskAxisId, and evidenceRequirementId reference must resolve within the same policy row. Capability IDs must resolve in LC-I11 when that separately reviewed artifact exists. Evidence kinds, failure classes, route kinds, decisions, execution statuses, and repair input kinds resolve only through the frozen global vocabularies and artifact IDs; arbitrary local spellings are invalid. Lists are nonempty where semantically required, duplicate-free, and Ordinal sorted. `variantEncoding` is exactly `Scalar`, `OrdinalIdSet`, or `Tuple`. `outcomeOnMissingFact` is `Unchecked` or `StaticFailed`; it cannot be `StaticPassed`. `maxAttempts` is exactly `1` for every RepairOnce rule.

Array order is exact: `policies` by lane; `familyKinds` by familyKindId; `factDefinitions` by factKind; `staticCheckDefinitions` by checkId; `riskAxisDefinitions` by riskAxisId; `evidenceRequirementDefinitions` by evidenceRequirementId; `capabilityProjectionRules` by capabilityId; and `repairRules` by repairClass, all Ordinal. Every collection inside a nested row is an Ordinal set except `sourceFactKinds`, whose declared order is positional. A validator rejects rather than repairs duplicate or misordered input.

For enum-like String facts, `allowedValues` is nonempty and exhaustive. For stable identity String facts and every IdSet fact, `allowedValues` is empty and the value must satisfy the registered identity type. An empty allowedValues list never permits an arbitrary enum spelling.

No policy may contain `metadata`, `payload`, an expression string, code, callback, ScriptBlock, arbitrary field path, regex selector, or executable operation.

`memberSelectorKinds` values are restricted to the C2 AR-S09 kinds `ObjectType`, `ClassId`, `CanonicalAssetId`, `PlatformVariant`, `DependencyObjectId`, and `ToolObservation`. Evidence kinds, failure classes, route kinds, and reason codes must come from the frozen vocabularies above.

### 1.4 Frozen lane policy content

The first LC-I07 version contains exactly five policy rows with `policyVersion=1.0.0`. Family-kind and applicable object-type sets are exact:

| Lane / policyId | familyKindId | applicableObjectTypes |
|---|---|---|
| Audio / AudioPolicyV1 | AudioRouteFamily | AudioClip, AudioMixer, WwiseBank, WwiseMedia |
| Environment / EnvironmentPolicyV1 | EnvironmentModuleFamily | Scene, TerrainData, LightmapData, MeshRenderer |
| Actor / ActorPolicyV1 | ActorRouteFamily | Avatar, AnimationClip, AnimatorController, SkinnedMeshRenderer |
| UI / UiPolicyV1 | UiRouteFamily | Sprite, SpriteAtlas, Font, TMP_FontAsset, Canvas |
| Effects / EffectsPolicyV1 | EffectRouteFamily | ParticleSystem, VisualEffect, TrailRenderer |

Each policy contains exactly the dimensions, checks, axes, projections, and repair classes below. Adding an ID requires a policy version and fingerprint change plus contract review.

Policy rows sort by lane Ordinally. Within a risk-axis definition, `sourceFactKinds` is a duplicate-free list that preserves declared order because Tuple encoding is positional. All other ID collections described as sets are Ordinal sorted.

| Lane | Family key dimensions | Static check requirements | Representative risk axes | Capability projection | Allowed repair classes |
|---|---|---|---|---|---|
| Audio | ObjectType, AudioEncoding, BankStructureId, EventStructureId, LoopMode, ChannelLayout, SampleRate | MediaReadability, DecodeOutcome, BankProvenance, EventRelationship, LoopValidity, ChannelLayoutValidity, DependencyClosure | Encoding, BankEventStructure, LoopRoute, ChannelLayout | PlayableBgmRoute, PlayableCombatSfx | AudioDecodeRepair, AudioSemanticRepair |
| Environment | ObjectType, EnvironmentThemeId, EnvironmentModuleType, RendererType, ShaderFamilyIds, PrefabDependencyShapeId, MeshTopologyId, LightmapMode, ColliderMode, NavMeshMode | MeshReadability, MaterialDependencyClosure, ShaderDependencyClosure, TextureDependencyClosure, PrefabDependencyClosure, LightmapValidity, ColliderValidity, NavMeshValidity | ThemeModule, RendererShaderCombination, PrefabDependencyShape, PhysicsNavigationShape | RecognizableEnvironmentOrMapModules | DependencyClosureRepair, MaterialMappingRepair, ImportSettingsRepair |
| Actor | ObjectType, ActorRole, SkeletonId, AvatarId, RendererType, ShaderFamilyIds, AnimationSetShapeId, ControllerReferenceState | MeshReadability, SkeletonClosure, AvatarClosure, AnimationClipReadability, MaterialDependencyClosure, TextureDependencyClosure, ControllerReferenceClassification, DependencyClosure | ActorRole, SkeletonAvatar, RendererShaderCombination, AnimationSetShape, ControllerRoute | PlayerModelSkeletonAnimationSet, EnemyModelSkeletonAnimationSet | DependencyClosureRepair, MaterialMappingRepair, PrototypeControllerRepair |
| UI | ObjectType, UiRouteKind, AtlasId, FontDependencyIds, ShaderFamilyIds, PrefabDependencyShapeId, TextureFormat | TextureReadability, SpriteAtlasClosure, FontDependencyClosure, MaterialDependencyClosure, PrefabDependencyClosure, UiRouteValidity | UiRoute, AtlasFontCombination, PrefabDependencyRisk, TextureFormat | ReusableUiGraphicsAndConstructionRoute | DependencyClosureRepair, TextureOnlyRebuild, FontAtlasRepair |
| Effects | ObjectType, EffectSystemKind, RendererType, ShaderFamilyIds, PrefabDependencyShapeId, AudioDependencyIds | EffectSystemReadability, MeshDependencyClosure, MaterialDependencyClosure, ShaderDependencyClosure, TextureDependencyClosure, AudioDependencyClosure, PrefabDependencyClosure | EffectSystem, RendererShaderCombination, PrefabDependencyShape, AudioCoupling | CombatEffectRoute | DependencyClosureRepair, MaterialMappingRepair, EffectBehaviorReconstruction |

`ActorRole` allowed values are `Player`, `Enemy`, and `Other`. `UiRouteKind` allowed values are `OriginalPrefab` and `TextureRebuild`. An `Other` actor family cannot satisfy either required actor capability. A texture rebuild or reconstructed effect may satisfy authoring readiness only through a C6 PrototypeReplacement rule; it can never be counted as UseOriginalAsset coverage.

#### 1.4a Exact LC-I07 registry rows

The following tables are the only first-version registry content. They close the nested references that the summary table above intentionally names but does not expand. The common `memberSelectorKinds` set for every family kind is exactly `CanonicalAssetId`, `ClassId`, `DependencyObjectId`, `ObjectType`, `PlatformVariant`, `ToolObservation`. Each policy has exactly one family kind:

| Lane | policyId | familyKindId | applicableObjectTypes | keyDimensionIds |
|---|---|---|---|---|
| Actor | ActorPolicyV1 | ActorRouteFamily | AnimationClip, AnimatorController, Avatar, SkinnedMeshRenderer | ActorRole, AnimationSetShapeId, AvatarId, ControllerReferenceState, ObjectType, RendererType, ShaderFamilyIds, SkeletonId |
| Audio | AudioPolicyV1 | AudioRouteFamily | AudioClip, AudioMixer, WwiseBank, WwiseMedia | AudioEncoding, BankStructureId, ChannelLayout, EventStructureId, LoopMode, ObjectType, SampleRate |
| Effects | EffectsPolicyV1 | EffectRouteFamily | ParticleSystem, TrailRenderer, VisualEffect | AudioDependencyIds, EffectSystemKind, ObjectType, PrefabDependencyShapeId, RendererType, ShaderFamilyIds |
| Environment | EnvironmentPolicyV1 | EnvironmentModuleFamily | LightmapData, MeshRenderer, Scene, TerrainData | ColliderMode, EnvironmentModuleType, EnvironmentThemeId, LightmapMode, MeshTopologyId, NavMeshMode, ObjectType, PrefabDependencyShapeId, RendererType, ShaderFamilyIds |
| UI | UiPolicyV1 | UiRouteFamily | Canvas, Font, Sprite, SpriteAtlas, TMP_FontAsset | AtlasId, FontDependencyIds, ObjectType, PrefabDependencyShapeId, ShaderFamilyIds, TextureFormat, UiRouteKind |

Every fact definition has `requiredForFamilyKinds` equal to the lane's singleton familyKindId. `DependencyObjectIds` and `PlatformVariant` are required support facts but are not family-key dimensions. A required support fact must be Known before assignment; the Section 1.2a zero-dependency rule supplies the exact known-empty DependencyObjectIds value from AR-O04. In the table below, each entry is `factKind/valueKind/allowNotApplicable`. `allowedValues` is the exact ObjectType set above or the exact enum set in Section 1.2 when one exists; every other String/IdSet and every Integer has empty `allowedValues`.

| Lane | Exact factDefinitions in factKind order |
|---|---|
| Actor | ActorRole/String/false; AnimationSetShapeId/String/true; AvatarId/String/true; ControllerReferenceState/String/true; DependencyObjectIds/IdSet/false; ObjectType/String/false; PlatformVariant/String/false; RendererType/String/true; ShaderFamilyIds/IdSet/true; SkeletonId/String/true |
| Audio | AudioEncoding/String/true; BankStructureId/String/true; ChannelLayout/String/true; DependencyObjectIds/IdSet/false; EventStructureId/String/true; LoopMode/String/true; ObjectType/String/false; PlatformVariant/String/false; SampleRate/Integer/true |
| Effects | AudioDependencyIds/IdSet/true; DependencyObjectIds/IdSet/false; EffectSystemKind/String/false; ObjectType/String/false; PlatformVariant/String/false; PrefabDependencyShapeId/String/true; RendererType/String/true; ShaderFamilyIds/IdSet/true |
| Environment | ColliderMode/String/true; DependencyObjectIds/IdSet/false; EnvironmentModuleType/String/false; EnvironmentThemeId/String/false; LightmapMode/String/true; MeshTopologyId/String/true; NavMeshMode/String/true; ObjectType/String/false; PlatformVariant/String/false; PrefabDependencyShapeId/String/true; RendererType/String/true; ShaderFamilyIds/IdSet/true |
| UI | AtlasId/String/true; DependencyObjectIds/IdSet/false; FontDependencyIds/IdSet/true; ObjectType/String/false; PlatformVariant/String/false; PrefabDependencyShapeId/String/true; ShaderFamilyIds/IdSet/true; TextureFormat/String/true; UiRouteKind/String/false |

Stable-identity carriers are lexically exact even though their producer-owned derivation is outside LC-I07. String identities are lowercase hex with these prefixes: `AnimationSetShapeId=animation-set-shape-sha256:`, `AtlasId=atlas-sha256:`, `AvatarId=avatar-sha256:`, `BankStructureId=bank-structure-sha256:`, `EnvironmentModuleType=environment-module-type-sha256:`, `EnvironmentThemeId=environment-theme-sha256:`, `EventStructureId=event-structure-sha256:`, `MeshTopologyId=mesh-topology-sha256:`, `PrefabDependencyShapeId=prefab-dependency-shape-sha256:`, `RendererType=renderer-type-sha256:`, `SkeletonId=skeleton-sha256:`, and `TextureFormat=texture-format-sha256:`, each followed by exactly 64 lowercase hex digits. DependencyObjectIds, AudioDependencyIds, and FontDependencyIds contain `sha256:` object IDs; ShaderFamilyIds contains `shader-family-sha256:` IDs. A future producer for any currently absent fact must separately freeze its derivation framing before emission; LC-I07 never derives these identities.

For the LC-I06 zero-dependency case, absent `DependencyObjectIds` plus the accepted AR-O04 selector set is the authoritative known-empty support value from Section 1.2a; it is not Unknown, NotApplicable, or a missing fact. Required facts gate family assignment: Known is accepted; policy-allowed NotApplicable is accepted only for a key dimension; Unknown, missing, a forbidden NotApplicable, or NotApplicable on a support fact retains the object for diagnosis. A key dimension retains its NotApplicable status/carriers in the family key.

Every static check below has `applicableFamilyKinds` equal to its lane's singleton familyKindId and `outcomeOnMissingFact=Unchecked`. For one assigned member, a definition is a required check exactly when none of its required facts is NotApplicable. If any required fact is policy-allowed NotApplicable, that check is inapplicable to that member: no check row is emitted and it is absent from requiredCheckCount. If a required fact is unexpectedly missing/Unknown after C3, the check is required and emits Unchecked with MissingInputFact. All requiredEvidenceKinds are conjunctive; absence of any required evidence prevents Passed. The compact columns are the exact `requiredFactKinds` and `requiredEvidenceKinds` Ordinal sets.

| Lane | checkId | requiredFactKinds | requiredEvidenceKinds |
|---|---|---|---|
| Actor | AnimationClipReadability | AnimationSetShapeId | FileReadability, ObjectReadability, SerializedMetadata |
| Actor | AvatarClosure | AvatarId, SkeletonId | DependencyGraph, SerializedMetadata |
| Actor | ControllerReferenceClassification | ControllerReferenceState | SerializedMetadata |
| Actor | DependencyClosure | DependencyObjectIds | DependencyGraph |
| Actor | MaterialDependencyClosure | RendererType, ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| Actor | MeshReadability | RendererType | FileReadability, ObjectReadability |
| Actor | SkeletonClosure | SkeletonId | DependencyGraph, SerializedMetadata |
| Actor | TextureDependencyClosure | ShaderFamilyIds | DependencyGraph, TextureMetadata |
| Audio | BankProvenance | BankStructureId | SerializedMetadata |
| Audio | ChannelLayoutValidity | ChannelLayout, SampleRate | AudioMetadata |
| Audio | DecodeOutcome | AudioEncoding | DecoderProbe |
| Audio | DependencyClosure | DependencyObjectIds | DependencyGraph |
| Audio | EventRelationship | BankStructureId, EventStructureId | DependencyGraph, SerializedMetadata |
| Audio | LoopValidity | LoopMode | AudioMetadata, LoopBehavior |
| Audio | MediaReadability | ObjectType | FileReadability, ObjectReadability |
| Effects | AudioDependencyClosure | AudioDependencyIds | AudioMetadata, DependencyGraph |
| Effects | EffectSystemReadability | EffectSystemKind | FileReadability, ObjectReadability, SerializedMetadata |
| Effects | MaterialDependencyClosure | RendererType, ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| Effects | MeshDependencyClosure | RendererType | DependencyGraph, ObjectReadability |
| Effects | PrefabDependencyClosure | PrefabDependencyShapeId | DependencyGraph, PrefabYaml |
| Effects | ShaderDependencyClosure | ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| Effects | TextureDependencyClosure | ShaderFamilyIds | DependencyGraph, TextureMetadata |
| Environment | ColliderValidity | ColliderMode | SerializedMetadata |
| Environment | LightmapValidity | LightmapMode | SerializedMetadata |
| Environment | MaterialDependencyClosure | RendererType, ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| Environment | MeshReadability | MeshTopologyId, ObjectType | FileReadability, ObjectReadability |
| Environment | NavMeshValidity | NavMeshMode | SerializedMetadata |
| Environment | PrefabDependencyClosure | PrefabDependencyShapeId | DependencyGraph, PrefabYaml |
| Environment | ShaderDependencyClosure | ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| Environment | TextureDependencyClosure | ShaderFamilyIds | DependencyGraph, TextureMetadata |
| UI | FontDependencyClosure | FontDependencyIds | DependencyGraph, SerializedMetadata |
| UI | MaterialDependencyClosure | ShaderFamilyIds | DependencyGraph, MaterialShaderGraph |
| UI | PrefabDependencyClosure | PrefabDependencyShapeId | DependencyGraph, PrefabYaml |
| UI | SpriteAtlasClosure | AtlasId | DependencyGraph, TextureMetadata |
| UI | TextureReadability | TextureFormat | FileReadability, ObjectReadability, TextureMetadata |
| UI | UiRouteValidity | UiRouteKind | SerializedMetadata |

All first-version risk axes use `variantEncoding=Tuple`; `sourceFactKinds` below is the exact positional list and is not sorted by a producer. PlatformVariant is included in every tuple so a representative on one platform never silently covers another platform variant. A member contributes a risk variant exactly when every source fact is Known. A policy-allowed NotApplicable source makes that axis inapplicable to that member and emits no variant; Unknown, missing, or forbidden NotApplicable is a contract/assignment contradiction and never creates a sentinel variant.

| Lane | riskAxisId | sourceFactKinds in positional order |
|---|---|---|
| Actor | ActorRole | ActorRole, PlatformVariant |
| Actor | AnimationSetShape | AnimationSetShapeId, PlatformVariant |
| Actor | ControllerRoute | ControllerReferenceState, PlatformVariant |
| Actor | RendererShaderCombination | RendererType, ShaderFamilyIds, PlatformVariant |
| Actor | SkeletonAvatar | SkeletonId, AvatarId, PlatformVariant |
| Audio | BankEventStructure | BankStructureId, EventStructureId, PlatformVariant |
| Audio | ChannelLayout | ChannelLayout, SampleRate, PlatformVariant |
| Audio | Encoding | AudioEncoding, PlatformVariant |
| Audio | LoopRoute | LoopMode, PlatformVariant |
| Effects | AudioCoupling | AudioDependencyIds, PlatformVariant |
| Effects | EffectSystem | EffectSystemKind, PlatformVariant |
| Effects | PrefabDependencyShape | PrefabDependencyShapeId, PlatformVariant |
| Effects | RendererShaderCombination | RendererType, ShaderFamilyIds, PlatformVariant |
| Environment | PhysicsNavigationShape | ColliderMode, NavMeshMode, PlatformVariant |
| Environment | PrefabDependencyShape | PrefabDependencyShapeId, PlatformVariant |
| Environment | RendererShaderCombination | RendererType, ShaderFamilyIds, PlatformVariant |
| Environment | ThemeModule | EnvironmentThemeId, EnvironmentModuleType, PlatformVariant |
| UI | AtlasFontCombination | AtlasId, FontDependencyIds, PlatformVariant |
| UI | PrefabDependencyRisk | PrefabDependencyShapeId, ShaderFamilyIds, PlatformVariant |
| UI | TextureFormat | TextureFormat, PlatformVariant |
| UI | UiRoute | UiRouteKind, PlatformVariant |

Each policy has exactly one evidence requirement row. `acceptedExecutionStatuses` is exactly `Completed`; Unavailable and Failed can produce C5 assessment states but can never satisfy a requirement.

| Lane | evidenceRequirementId | applicableRiskAxisIds | requiredEvidenceKinds |
|---|---|---|---|
| Actor | ActorRouteEvidence | ActorRole, AnimationSetShape, ControllerRoute, RendererShaderCombination, SkeletonAvatar | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender |
| Audio | AudioRouteEvidence | BankEventStructure, ChannelLayout, Encoding, LoopRoute | AudioPlayback, HumanListening, LoopBehavior |
| Effects | EffectRouteEvidence | AudioCoupling, EffectSystem, PrefabDependencyShape, RendererShaderCombination | AudioPlayback, EffectBehavior, MaterialFidelity, UnityImport, VisibleRender |
| Environment | EnvironmentRouteEvidence | PhysicsNavigationShape, PrefabDependencyShape, RendererShaderCombination, ThemeModule | MaterialFidelity, UnityImport, VisibleRender |
| UI | UiRouteEvidence | AtlasFontCombination, PrefabDependencyRisk, TextureFormat, UiRoute | MaterialFidelity, UiConstruction, UnityImport, VisibleRender |

Capability rules below have the lane's singleton `applicableFamilyKinds`. ActorRole eligibility remains an LC-I11 predicate, so the two Actor candidates do not authorize Other. A single current routeKind must be a member of `requiredRouteKinds`; the set is an allowed-route disjunction, not a requirement to materialize every route. The current decision must be a member of allowedFamilyDecisions and every requiredEvidenceKind is conjunctive. No RepairOnce, NeedsDiagnosis, RetainForLater, DiagnosticOnly, or Stop row can satisfy a capability.

| Lane | capabilityId | requiredRouteKinds | allowedFamilyDecisions | requiredEvidenceKinds |
|---|---|---|---|---|
| Actor | EnemyModelSkeletonAnimationSet | OriginalAsset, PrototypeController | PrototypeReplacement, UseOriginalAsset | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender |
| Actor | PlayerModelSkeletonAnimationSet | OriginalAsset, PrototypeController | PrototypeReplacement, UseOriginalAsset | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender |
| Audio | PlayableBgmRoute | DecodedAudio, OriginalAsset | PrototypeReplacement, UseOriginalAsset | AudioPlayback, HumanListening, LoopBehavior |
| Audio | PlayableCombatSfx | DecodedAudio, OriginalAsset | PrototypeReplacement, UseOriginalAsset | AudioPlayback, HumanListening |
| Effects | CombatEffectRoute | EffectBehaviorReconstructed, OriginalAsset | PrototypeReplacement, UseOriginalAsset | EffectBehavior, MaterialFidelity, UnityImport, VisibleRender |
| Environment | RecognizableEnvironmentOrMapModules | OriginalAsset | UseOriginalAsset | MaterialFidelity, UnityImport, VisibleRender |
| UI | ReusableUiGraphicsAndConstructionRoute | OriginalAsset, TextureOnlyRebuild | PrototypeReplacement, UseOriginalAsset | MaterialFidelity, UiConstruction, UnityImport, VisibleRender |

Repair rules are only candidates for the C6 RepairOnceRule. A repairClass spelling that resembles a replacement route does not authorize PrototypeReplacement; LC-I11 must define a separate exact replacement rule. Every row has the lane's singleton `applicableFamilyKinds` and `maxAttempts=1`. A rule matches failure classes only when the current actionable failure-class set is nonempty and is a subset of requiredFailureClasses; requiredInputKinds are conjunctive. Mixed failures outside the set do not partially match, and two matching rules remain LF-17.

| Lane | repairClass | requiredFailureClasses | requiredInputKinds | expectedChangeMeasure |
|---|---|---|---|---|
| Actor | DependencyClosureRepair | MissingDependency, PrefabDependencyMissing | DependencyGraph, DependencyObjectIds, PrefabDependencyShapeId | MissingDependencyCount |
| Actor | MaterialMappingRepair | MaterialMismatch, ShaderMismatch | MaterialShaderGraph, RendererType, ShaderFamilyIds | FailedCheckCount |
| Actor | PrototypeControllerRepair | ControllerMissing | ControllerReferenceState, SerializedMetadata | FailedCheckCount |
| Audio | AudioDecodeRepair | DecodeFailure | AudioEncoding, DecoderProbe | DecodeFailureCount |
| Audio | AudioSemanticRepair | SemanticUnknown | EventStructureId, SerializedMetadata | SemanticUnknownCount |
| Effects | DependencyClosureRepair | MissingDependency, PrefabDependencyMissing | DependencyGraph, DependencyObjectIds, PrefabDependencyShapeId | MissingDependencyCount |
| Effects | EffectBehaviorReconstruction | EffectBehaviorMissing | EffectBehavior, PrefabYaml | VisibleIssueCount |
| Effects | MaterialMappingRepair | MaterialMismatch, ShaderMismatch | MaterialShaderGraph, RendererType, ShaderFamilyIds | FailedCheckCount |
| Environment | DependencyClosureRepair | MissingDependency, PrefabDependencyMissing | DependencyGraph, DependencyObjectIds, PrefabDependencyShapeId | MissingDependencyCount |
| Environment | ImportSettingsRepair | ImportSettingMismatch | SerializedMetadata, TextureMetadata | FailedCheckCount |
| Environment | MaterialMappingRepair | MaterialMismatch, ShaderMismatch | MaterialShaderGraph, RendererType, ShaderFamilyIds | FailedCheckCount |
| UI | DependencyClosureRepair | MissingDependency, PrefabDependencyMissing | DependencyGraph, DependencyObjectIds, PrefabDependencyShapeId | MissingDependencyCount |
| UI | FontAtlasRepair | FontAtlasMissing | FontDependencyIds, SerializedMetadata | MissingDependencyCount |
| UI | TextureOnlyRebuild | ImportSettingMismatch, ReadFailure | TextureFormat, TextureMetadata | FailedCheckCount |

The implementation Task must reject at least these LF-03 vectors: stored `policySetFingerprint` or any other additional property; wrong top-level constant; missing/duplicate/misordered lane; changed bytes with reused policySetId/policySetVersion; missing/duplicate/misordered nested row or set; reordered Tuple sourceFactKinds; unresolved fact/family/risk/capability/input ID; an enum with empty or extra allowedValues; NotApplicable where the exact row forbids it; `StaticPassed` on missing fact; accepted execution status other than Completed; `maxAttempts` other than one; and any metadata, payload, expression, regex, callback, ScriptBlock, or executable operation. The Passed vector must also prove exact-byte equality between LC-I07 and its positive fixture and must compute, never read, policySetFingerprint.

### 1.5 C3 output shapes

**C3-O01 family registry** top level is exactly:

```text
schemaVersion, generatedAt, snapshotId, inputFingerprint, policySetFingerprint, families
```

Each family row is exactly:

```text
familyId
lane
familyKindId
policyId
policyVersion
familyKeyFingerprint
familyKey
memberCount
memberBytes
memberObjectIds
crossLaneReferenceIds
riskDimensionIds
evidence
```

Each `familyKey` row is exactly `dimensionId`, `factStatus`, `valueKind`, `stringValue`, `integerValue`, `booleanValue`, `idValues`, using the LC-I06 carrier rules. Family keys sort by `dimensionId`. Members and references are Ordinal ID sets.

**C3-O02 family-member ledger** top level uses the same five identity/freshness prefix fields and `rows`. Each row is exactly:

```text
memberRecordId
assetObjectId
canonicalAssetId
lane
parentStatus
familyId
familyKindId
serializedSizeBytes
configurationCandidateId
dependencyObjectIds
crossLaneReferenceIds
policyId
policyVersion
evidence
```

`parentStatus` is `AssignedFamilyMember`, `RetainedForDiagnosis`, or `ConfigurationOnly`. `familyId/familyKindId` are non-null only for AssignedFamilyMember. `configurationCandidateId` is non-null exactly for ConfigurationOnly. Every LC-I04 row appears once.

**C3-O03 cross-lane reference package** uses the same five-field prefix and `rows`. Each row is exactly:

```text
referenceId
fromAssetObjectId
toAssetObjectId
fromLane
toLane
referenceKind
resolutionStatus
evidence
```

`referenceKind` is `Dependency`, `AudioCoupling`, `ShaderCoupling`, `AtlasFontCoupling`, or `ConfigurationCoupling`. `resolutionStatus` is `Resolved`, `Missing`, or `Conflict`. A reference never appears in a family member set and never changes either object's direct parent.

### 1.6 C4 output shapes

**C4-O01 member static qualification** top level is exactly:

```text
schemaVersion, generatedAt, snapshotId, inputFingerprint, policySetFingerprint, memberResults
```

Each member result is exactly:

```text
staticResultId
assetObjectId
familyId
lane
requiredCheckCount
passedCheckCount
failedCheckCount
uncheckedCheckCount
staticStatus
uncheckedReasonCodes
failureAttribution
nextAllowedAction
checkResults
evidence
```

Each check result is exactly:

```text
checkResultId
checkId
outcome
reasonCode
observedFingerprint
evidence
```

`outcome` is `Passed`, `Failed`, or `Unchecked`. `observedFingerprint` is non-null only when evidence bytes were actually read. `uncheckedReasonCodes` values are `MissingInputFact`, `PrerequisiteFailed`, `ToolUnavailable`, `UnsupportedFormat`, or `EvidenceUnavailable`. Unchecked is never Passed.

`staticStatus` is `StaticPassed` only when every required check Passed, `StaticFailed` when at least one required check Failed, and `Unchecked` otherwise. These member-level terms are deliberately distinct from the existing family-level `familyStaticOutcome` vocabulary.

**C4-O02 family static summary** has exact prefix fields and `families`. Each row is exactly:

```text
familyId
lane
memberCount
memberBytes
staticPassedCount
staticPassedBytes
staticFailedCount
staticFailedBytes
uncheckedCount
uncheckedBytes
staticOutcome
failureAttribution
nextAllowedAction
memberStaticResultIds
evidence
```

Family `staticOutcome` is StaticQualified only when every member is StaticPassed, StaticRejected when at least one member is StaticFailed, and NeedsDiagnosis otherwise. Family counts and bytes derive from member results; they are never caller-supplied totals.

### 1.7 C5 input and output shapes

LC-I09 top level is exactly `schemaVersion`, `generatedAt`, `inputFingerprint`, `entries`. Each entry is exactly `path`, `sha256`, `evidencePackageId`, `requirementId`. Paths and identities are unique and Ordinal sorted. Every requirementId resolves to exactly one C5-O01 risk-variant or capability-suitability requirement; cross-array duplicates are invalid.

Each LC-I10 package is exactly:

```text
schemaVersion
generatedAt
evidencePackageId
requirementId
requirementKind
representativeAssetObjectId
executorKind
executionStatus
inputFingerprint
toolVersions
observations
evidencePaths
```

`requirementKind` is `RiskVariant` or `CapabilitySuitability` and must match the unique C5-O01 requirement owning requirementId. `inputFingerprint` must equal that requirement's expectedInputFingerprint exactly. `executorKind` is `C7Unity`, `G4Unity`, `StaticHumanReview`, `AudioListening`, or `ExternalDecoder`. `executionStatus` is `Completed`, `Unavailable`, or `Failed`. Each observation is exactly `evidenceKind`, `outcome`, `contentFingerprint`, `evidence`, where outcome is `Passed`, `Rejected`, or `Inconclusive`. A CapabilitySuitability package has exactly one observation and its evidenceKind is exactly `CapabilitySuitability`; its requirement identity, not a filename or media property, binds the evidence to one capability and route. C5 reads packages; it never launches the executor.

**C5-O01 representative requirements** uses the C5/C6 support-package prefix and then exactly:

```text
requirements
capabilitySuitabilityRequirements
```

Each requirement is exactly:

```text
requirementId
familyId
lane
riskAxisId
riskVariantId
candidateMemberIds
selectedRepresentativeAssetObjectId
selectionRule
requiredEvidenceKinds
expectedInputFingerprint
assessmentStatus
evidence
```

`selectionRule` is exactly `OrdinalFirstStaticPassed`. Candidate members are C4 StaticPassed members matching the risk variant. The selected representative is the Ordinal-first candidate or null when the candidate set is empty.

Each capability-suitability requirement is exactly:

```text
suitabilityRequirementId
familyId
capabilityId
routeKind
candidateMemberIds
selectedRepresentativeAssetObjectId
selectionRule
requiredEvidenceKinds
expectedInputFingerprint
assessmentStatus
evidence
```

C5 derives exactly one such requirement for every `(familyId,capabilityId,routeKind)` admitted by the current LC-I11 lane, family-kind, ActorRole, route, and LC-I07-union constraints. `requiredEvidenceKinds` is exactly the singleton `CapabilitySuitability`. Candidate members are the family's C4 StaticPassed members and selection is `OrdinalFirstStaticPassed`. For both requirement kinds, expectedInputFingerprint is LX-HI-21 after requirement identity and representative selection are fixed. C5 never derives capability suitability from LoopMode, object name, path, filename, object type, generic playback, or another proxy. In particular, BGM and combat-SFX identity is established only by separate capability-specific suitability requirements and matching evidence packages.

Risk-variant `assessmentStatus` is exactly one of:

```text
RepresentativeRequired
EvidenceAccepted
EvidenceMissing
EvidenceStale
UnityExecutionUnavailable
RepresentativeRejected
```

RepresentativeRequired means the requirement exists but has no selectable StaticPassed candidate. EvidenceMissing means a representative was selected but no matching package exists. UnityExecutionUnavailable requires an exact matching Unavailable C7/G4 package; it is not asset rejection.

Capability-suitability `assessmentStatus` is exactly `SuitabilityRequired`, `SuitabilityAccepted`, `SuitabilityMissing`, `SuitabilityStale`, `SuitabilityExecutionUnavailable`, or `SuitabilityRejected`. These map one-for-one to the same package/freshness conditions, but remain a distinct status dimension so a rejected BGM route cannot reject the same asset as combat SFX or as a generic representative.

**C5-O02 evidence assessment** uses the C5/C6 support-package prefix followed by `assessments`, `capabilitySuitabilityAssessments`. Each risk assessment row is exactly:

```text
assessmentId
requirementId
familyId
representativeAssetObjectId
assessmentStatus
evidencePackageId
expectedInputFingerprint
observedInputFingerprint
acceptedEvidenceKinds
missingEvidenceKinds
failureAttribution
nextAllowedAction
evidence
```

Package and observed fingerprints are nullable only when no package exists. EvidenceAccepted requires exact freshness and every required evidence kind Passed. Any Rejected observation produces RepresentativeRejected. Inconclusive or incomplete evidence produces EvidenceMissing, not acceptance.

Each capability-suitability assessment row is exactly:

```text
suitabilityAssessmentId
suitabilityRequirementId
familyId
capabilityId
routeKind
representativeAssetObjectId
assessmentStatus
evidencePackageId
expectedInputFingerprint
observedInputFingerprint
failureAttribution
nextAllowedAction
evidence
```

SuitabilityAccepted requires one exact fresh Completed LC-I10 package for the suitabilityRequirementId with a Passed `CapabilitySuitability` observation. Rejected maps only to SuitabilityRejected for that exact capabilityId/routeKind. Inconclusive or incomplete evidence maps to SuitabilityMissing. A suitability assessment never changes the risk assessment for the same representative and never supplies another capability or route.

**C5-O03 C7 request** uses the C5/C6 support-package prefix followed by `requests`. Each row is exactly `requirementId`, `requirementKind`, `familyId`, `lane`, `capabilityId`, `routeKind`, `representativeAssetObjectId`, `requiredEvidenceKinds`, `reasonCode`, `priority`, `evidence`. `requirementKind` is `RiskVariant` or `CapabilitySuitability`. `capabilityId` and `routeKind` are non-null exactly for CapabilitySuitability. `reasonCode` is `EvidenceMissing`, `EvidenceStale`, `UnityExecutionUnavailable`, `SuitabilityMissing`, `SuitabilityStale`, or `SuitabilityExecutionUnavailable`; priority is `RequiredCapability`, `Coverage`, or `Diagnostic`. It is an instruction artifact, not execution authorization.

### 1.8 C6 decision policy and output shapes

LC-I11 top level is exactly:

```text
schemaVersion
generatedAt
decisionPolicyId
decisionPolicyVersion
hardStopFailureClasses
diagnosticOnlyFamilyKinds
replacementRules
capabilities
```

For the first reviewed registry, `schemaVersion=1.0.0`, `generatedAt=2026-07-16T00:00:00Z`, `decisionPolicyId=StellaSoraAuthoringDecisionPolicy`, and `decisionPolicyVersion=1.0.0`. LC-I11 does not store its own fingerprint. `decisionPolicyFingerprint` in C5/C6 outputs is CT-04 SHA-256 over the exact complete LC-I11 bytes. Reusing the same decisionPolicyId/decisionPolicyVersion with any changed byte is LF-03.

The future JSON Schema authority is `docs/asset-migration/schemas/c3-c6-decision-policy-registry.schema.json`; the positive contract fixture is `Tools/AssetImport/Fixtures/AssetCorpusContracts/valid-c3-c6-decision-policy-registry.json` and must be byte-identical to LC-I11. Neither schema nor contract-test fixtures are lifecycle direct inputs.

`hardStopFailureClasses` is exactly the singleton `CoreDataMissing`. `diagnosticOnlyFamilyKinds` is exactly empty in version 1.0.0. ReadFailure is not globally hard-stop because a reviewed UI texture-only route may retain readable original media after a different failed dependency route; every other failure class is governed by the exact repair/replacement/terminal rules rather than an inferred global rank.

Each replacement rule is exactly `replacementRuleId`, `lane`, `familyKindIds`, `requiredFailureClasses`, `requiredStaticCheckIds`, `requiredAcceptedEvidenceKinds`, `routeKind`, `capabilityIds`. The current actionable failure-class set must be nonempty and a subset of requiredFailureClasses. Every named static check must be Passed and every named evidence kind must occur in an EvidenceAccepted C5 risk assessment. Capability suitability does not choose the family decision; it gates only the later capability projection. Two matching replacement rules remain LF-17.

The exact replacement rules, sorted Ordinal by replacementRuleId, are:

| replacementRuleId | lane / familyKindIds | requiredFailureClasses | requiredStaticCheckIds | requiredAcceptedEvidenceKinds | routeKind | capabilityIds |
|---|---|---|---|---|---|---|
| ActorPrototypeControllerReplacement | Actor / ActorRouteFamily | ControllerMissing | AnimationClipReadability, AvatarClosure, ControllerReferenceClassification, DependencyClosure, MaterialDependencyClosure, MeshReadability, SkeletonClosure, TextureDependencyClosure | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender | PrototypeController | EnemyModelSkeletonAnimationSet, PlayerModelSkeletonAnimationSet |
| AudioDecodedRouteReplacement | Audio / AudioRouteFamily | SemanticUnknown | ChannelLayoutValidity, DecodeOutcome, LoopValidity, MediaReadability | AudioPlayback, HumanListening | DecodedAudio | PlayableBgmRoute, PlayableCombatSfx |
| EffectBehaviorReconstructionReplacement | Effects / EffectRouteFamily | EffectBehaviorMissing | AudioDependencyClosure, EffectSystemReadability, MaterialDependencyClosure, MeshDependencyClosure, PrefabDependencyClosure, ShaderDependencyClosure, TextureDependencyClosure | EffectBehavior, MaterialFidelity, UnityImport, VisibleRender | EffectBehaviorReconstructed | CombatEffectRoute |
| UiTextureOnlyRebuildReplacement | UI / UiRouteFamily | FontAtlasMissing, PrefabDependencyMissing | TextureReadability | MaterialFidelity, UiConstruction, UnityImport, VisibleRender | TextureOnlyRebuild | ReusableUiGraphicsAndConstructionRoute |

Every ID referenced by a replacement rule must resolve exactly in LC-I07 or the LC-I11 capability set. Lists are duplicate-free and Ordinal sorted. The rule table is declarative data only; metadata, payload, expression, callback, arbitrary predicate, regex, ScriptBlock, and executable operation are forbidden.

Each capability row is exactly:

```text
capabilityId
required
eligibleLanes
eligibleFamilyKindIds
eligibleActorRoles
eligibleRouteKinds
allowedFamilyDecisions
requiredAcceptedEvidenceKinds
```

Every capability row has `required=true`. `eligibleActorRoles` is `Enemy` only for EnemyModelSkeletonAnimationSet, `Player` only for PlayerModelSkeletonAnimationSet, and empty for the other five capabilities. An empty eligibleActorRoles set means ActorRole is not an eligibility dimension; it never means any ActorRole for an Actor capability.

The required capability IDs are exactly:

```text
RecognizableEnvironmentOrMapModules
PlayerModelSkeletonAnimationSet
EnemyModelSkeletonAnimationSet
CombatEffectRoute
ReusableUiGraphicsAndConstructionRoute
PlayableBgmRoute
PlayableCombatSfx
```

The set of `(capabilityId,lane,familyKindId,routeKind)` candidates in LC-I11 must equal the duplicate-free union of all LC-I07 capabilityProjectionRules. LC-I11 adds global required/decision/evidence predicates but cannot add, remove, or remap a lane contribution. Any mismatch is LF-03 before C6 decision evaluation.

The exact capability rows, sorted Ordinal by capabilityId, are:

| capabilityId | eligibleLanes | eligibleFamilyKindIds | eligibleActorRoles | eligibleRouteKinds | allowedFamilyDecisions | requiredAcceptedEvidenceKinds |
|---|---|---|---|---|---|---|
| CombatEffectRoute | Effects | EffectRouteFamily | empty | EffectBehaviorReconstructed, OriginalAsset | PrototypeReplacement, UseOriginalAsset | EffectBehavior, MaterialFidelity, UnityImport, VisibleRender |
| EnemyModelSkeletonAnimationSet | Actor | ActorRouteFamily | Enemy | OriginalAsset, PrototypeController | PrototypeReplacement, UseOriginalAsset | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender |
| PlayableBgmRoute | Audio | AudioRouteFamily | empty | DecodedAudio, OriginalAsset | PrototypeReplacement, UseOriginalAsset | AudioPlayback, HumanListening, LoopBehavior |
| PlayableCombatSfx | Audio | AudioRouteFamily | empty | DecodedAudio, OriginalAsset | PrototypeReplacement, UseOriginalAsset | AudioPlayback, HumanListening |
| PlayerModelSkeletonAnimationSet | Actor | ActorRouteFamily | Player | OriginalAsset, PrototypeController | PrototypeReplacement, UseOriginalAsset | AnimationPlayback, MaterialFidelity, UnityImport, VisibleRender |
| RecognizableEnvironmentOrMapModules | Environment | EnvironmentModuleFamily | empty | OriginalAsset | UseOriginalAsset | MaterialFidelity, UnityImport, VisibleRender |
| ReusableUiGraphicsAndConstructionRoute | UI | UiRouteFamily | empty | OriginalAsset, TextureOnlyRebuild | PrototypeReplacement, UseOriginalAsset | MaterialFidelity, UiConstruction, UnityImport, VisibleRender |

For each exact candidate tuple, C5 owns a separate capability-suitability requirement. C6 may satisfy the tuple only when that exact requirement is SuitabilityAccepted and the family/route also satisfies the row's decision and requiredAcceptedEvidenceKinds. LoopMode and LoopBehavior are technical facts/evidence only: neither identifies BGM or combat SFX. A BGM suitability result cannot satisfy PlayableCombatSfx, and vice versa, even when the same representative and route are used.

Decision-to-route projection is exact: UseOriginalAsset projects only `OriginalAsset`; PrototypeReplacement projects only the routeKind of its single matching replacement rule. A decision cannot choose another eligibleRouteKind merely because that route appears in the capability row. Thus `(PrototypeReplacement,OriginalAsset)` and `(UseOriginalAsset,DecodedAudio|PrototypeController|TextureOnlyRebuild|EffectBehaviorReconstructed)` are invalid transitions.

Array order is exact: replacementRules by replacementRuleId and capabilities by capabilityId, both Ordinal. Every nested collection is a duplicate-free Ordinal set. The physical-contract Task must reject at least: stored decisionPolicyFingerprint or any additional top-level property; wrong immutable constant; changed bytes with reused ID/version; non-singleton or wrong hard-stop set; nonempty diagnostic-only set; missing/duplicate/misordered replacement or capability row; unresolved family/check/failure/evidence/route/capability ID; any LC-I07 candidate-union loss or addition; a decision-to-route mismatch; suitability evidence reused across capability, route, family, or requirement; and any metadata, payload, expression, callback, regex, ScriptBlock, or executable operation. Passed validation must byte-compare LC-I11 with its positive fixture and compute, never read, decisionPolicyFingerprint.

**C6-O01 authoring reuse ledger v2** top level is exactly:

```text
schemaVersion
generatedAt
snapshotId
inputFingerprint
policySetFingerprint
decisionPolicyFingerprint
toolVersions
sourceArtifacts
families
members
coverage
capabilities
```

Each source artifact is exactly `artifactId`, `path`, `sha256`.

The sourceArtifacts set is exactly C3-O01/O02/O03 plus the C3-O04 summary/report, C4-O01/O02 plus the C4-O03 summary/report, C5-O01/O02 plus the C5-O04 summary/report, LC-I07, LC-I08, LC-I11, and LC-I12. C5-O03 is an instruction output and is not a decision input. Paths are distinct and Ordinal sorted.

Each family row is exactly:

```text
familyId
lane
familyKindId
familyKeyFingerprint
memberSelector
memberCount
memberBytes
staticPassedCount
staticFailedCount
uncheckedCount
representativeRequirementCount
evidenceAcceptedCount
evidenceMissingCount
evidenceStaleCount
unityExecutionUnavailableCount
representativeRejectedCount
staticOutcome
decision
repairClass
replacementRouteKind
failureAttribution
nextAllowedAction
acceptedEvidenceAssessmentIds
residualIssueIds
qualifiedMemberIds
isolatedMemberIds
directGateSummaries
directGateReports
inputFingerprint
```

`memberSelector` is an exact copy of the C3 familyKey rows and is bound by `familyKeyFingerprint`; it is not a free-form selector string. For a family row, `repairClass` is non-null exactly for RepairOnce and `replacementRouteKind` is non-null exactly for PrototypeReplacement. `qualifiedMemberIds` and `isolatedMemberIds` are disjoint, duplicate-free, and their union equals the family member set. UseOriginalAsset qualifies every member. PrototypeReplacement qualifies only the original-media C4 StaticPassed members named by its exact replacement rule. Every other decision qualifies no member. Accepted evidence and residual issue IDs must resolve exactly in C5-O02 and C6-O02 respectively.

Each member row is exactly:

```text
assetObjectId
familyId
lane
serializedSizeBytes
staticStatus
representativeRequirementIds
disposition
poolStatus
failureAttribution
evidence
```

`poolStatus` is `AcceptedOriginalPool`, `AcceptedReplacementSourcePool`, or `Isolated`. StaticFailed and Unchecked members are always Isolated. AcceptedReplacementSourcePool means original media is qualified but runtime behavior is explicitly reconstructed; it is not UseOriginalAsset coverage.

Member `disposition` equals its direct family decision exactly. PoolStatus expresses member isolation without inventing a second decision vocabulary.

Coverage is exactly:

```text
dispatchEligibleObjectCount
dispatchEligibleObjectBytes
assignedFamilyMemberCount
assignedFamilyMemberBytes
retainedForDiagnosisObjectCount
retainedForDiagnosisObjectBytes
configurationOnlyObjectCount
configurationOnlyObjectBytes
totalFamilyCount
reusableFamilyCount
totalMemberCount
reusableMemberCount
isolatedMemberCount
totalBytes
reusableBytes
isolatedBytes
```

Each capability row is exactly `capabilityId`, `status`, `satisfyingFamilyIds`, `routeKinds`, `suitabilityAssessmentIds`, `failureAttribution`, `evidence`. The capability identity resolves to exactly one LC-I11 row. Every suitabilityAssessmentId resolves to a SuitabilityAccepted C5-O02 row for the same capability, one projected routeKind, and one satisfying family. Status is `Satisfied`, `Unsatisfied`, or `Blocked`.

**C6-O02 family decision package** uses the C6 support-package prefix followed by `decisions`, `issues`. Each decision row is exactly `decisionId`, `familyId`, `decision`, `repairClass`, `replacementRouteKind`, `ruleId`, `inputStaticFingerprint`, `inputEvidenceFingerprint`, `repairHistoryFingerprint`, `failureAttribution`, `nextAllowedAction`, `evidence`.

`ruleId` is exactly one of `DiagnosticOnlyRule`, `HardStopRule`, `NeedsDiagnosisRule`, `RepairOnceRule`, `PrototypeReplacementRule`, `UseOriginalAssetRule`, `RetainForLaterRule`, or `TerminalStopRule`, matching the first applicable C6 Decision Precedence row. `acceptedEvidenceAssessmentIds` contains every and only the family's C5-O02 EvidenceAccepted assessment IDs. It never contains missing, stale, unavailable, rejected, or merely required assessment IDs.

Each issue row is exactly `issueId`, `familyId`, `issueClass`, `subjectIds`, `failureAttribution`, `evidence`. `issueClass` uses the residual issue-class vocabulary. Issue IDs are unique and Ordinal sorted; a residualIssueId in C6-O01 resolves to exactly one issue row.

**C6-O03 capability projection** uses the C6 support-package prefix followed by `capabilities`, with the exact C6-O01 capability rows.

**C6-O04 G5 handoff** top level is exactly:

```text
schemaVersion
generatedAt
snapshotId
inputFingerprint
authoringReuseLedgerPath
authoringReuseLedgerSha256
familyDecisionPackagePath
familyDecisionPackageSha256
capabilityProjectionPath
capabilityProjectionSha256
familyConstructionCoverage
originalAssetBatchCoverage
stellaSora2AuthoringReady
failureAttribution
nextAllowedAction
```

`stellaSora2AuthoringReady` is exactly `value`, `requiredCapabilityIds`, `satisfiedCapabilityIds`, `unsatisfiedCapabilityIds`, `blockedCapabilityIds`, `isolatedMemberCount`. `value` is true if and only if every one of the seven required capability IDs is Satisfied and every member not admitted to an accepted pool is Isolated. G5 may validate and copy these values; it may not reinterpret C3-C5 evidence or recalculate family decisions.

The exact `originalAssetBatchCoverage` shape is `reusableFamilyCount`, `totalFamilyCount`, `reusableMemberCount`, `totalMemberCount`, `reusableBytes`, `totalBytes`, in that order. No replacement-pool count is folded into a reusable field.

The exact `familyConstructionCoverage` shape is `dispatchEligibleObjectCount`, `dispatchEligibleObjectBytes`, `assignedFamilyMemberCount`, `assignedFamilyMemberBytes`, `retainedForDiagnosisObjectCount`, `retainedForDiagnosisObjectBytes`, `configurationOnlyObjectCount`, `configurationOnlyObjectBytes`, in that order. These values copy the current conserved C3 generation through C6; G5 never reconstructs them by reading C3.

### 1.9 Repair-attempt history: LC-I12

Top level is exactly:

```text
schemaVersion
generatedAt
inputFingerprint
attempts
```

Each attempt row is exactly:

```text
attemptId
familyId
repairClass
attemptNumber
inputFingerprint
outputFingerprint
expectedChangeMeasure
observedChange
outcome
evidence
```

`attemptNumber` is exactly `1`; `outcome` is `Improved`, `NoImprovement`, or `Failed`. `outputFingerprint` is non-null only when an output was produced. One family/repairClass pair has at most one row. C6 may emit RepairOnce only when no matching row exists. A matching attempt with any outcome makes RepairOnce ineligible; the family is reevaluated for UseOriginalAsset, PrototypeReplacement, NeedsDiagnosis, RetainForLater, DiagnosticOnly, or Stop using current evidence.

`expectedChangeMeasure` uses the frozen measure vocabulary. `observedChange` is a nullable nonnegative integer measuring reduction in the selected issue count: Improved requires a value greater than zero, NoImprovement requires zero, and Failed requires null. The row inputFingerprint binds the exact pre-repair family decision inputs; a row for another fingerprint is retained as history but does not masquerade as the current attempt result. The one-attempt limit is by familyId/repairClass across history, not reset by a fingerprint change.

### 1.10 Diagnostic summary and report contract

Every C3-O04/C4-O03 JSON summary is exactly:

```text
schemaVersion
generatedAt
stageId
snapshotId
inputFingerprint
policySetFingerprint
toolVersions
directInputs
directOutputs
coverage
failureAccounting
decision
```

C5-O04/C6-O05 use the same shape but insert `decisionPolicyFingerprint` immediately after `policySetFingerprint`. It is computed from accepted LC-I11 bytes and is never copied from LC-I11.

Each direct input/output is exactly `artifactId`, `path`, `sha256`. Failure accounting is exactly `inputSubjectCount`, `acceptedInputSubjectCount`, `inputFailureCount`, `notEvaluatedInputSubjectCount`, `outputCandidateCount`, `projectedOutputCount`, `outputFailureCount`, `issueCount`, `gateStatus`, `inputFailures`, `inputSuppressions`, `outputFailures`, in that order. Decision is exactly `failureAttribution`, `nextAllowedAction`.

`stageId` is exactly `C3`, `C4`, `C5`, or `C6`; `gateStatus` is `Passed` or `Failed`. Accounting `subjectKind` is exactly `Artifact`, `FreshnessCheck`, `PolicyCheck`, `TypedFact`, `DispatchObject`, `Family`, `FamilyMember`, `CrossLaneReference`, `StaticCheck`, `RepresentativeRequirement`, `EvidencePackage`, `Capability`, `ConservationCheck`, `ProjectionCheck`, `LightweightPolicy`, or `OutputArtifact`.

`directOutputs` contains every actually produced non-summary physical file and excludes the summary JSON itself. On Passed it contains all success artifact files plus the report; on contract Failed it contains only the diagnostic report. Summary identity and the report entry form the external LX-HI-15 diagnostic bundle; no summary self-hash is embedded in the summary.

Each accounting row is exactly:

```text
recordId
stageId
subjectKind
subjectId
reasonCode
attribution
evidence
```

One direct subject appears in at most one input accounting array. `attribution` is the LF ID, literal `:`, then the stable subject ID. An input suppression uses reason `PrerequisiteUnavailable` and does not increment inputFailureCount or issueCount. A success output suppressed by a contract-failed gate uses reason `SuppressedByGate` and does not add another issue. `issueCount` equals inputFailureCount plus output failures whose reason is not SuppressedByGate. Rows sort by numeric LF ID then Ordinal subjectId.

For LX-HI-17, `owningArray` is the containing array name (`inputFailures`, `inputSuppressions`, or `outputFailures`) and is not duplicated as a stored property.

Coverage keys are stage-specific and exact:

- C3: `dispatchEligibleObjectCount`, `dispatchEligibleObjectBytes`, `assignedFamilyMemberCount`, `assignedFamilyMemberBytes`, `retainedForDiagnosisObjectCount`, `retainedForDiagnosisObjectBytes`, `configurationOnlyObjectCount`, `configurationOnlyObjectBytes`, `familyCount`, `referenceCount`, `resolvedReferenceCount`, `missingReferenceCount`, `conflictReferenceCount`.
- C4: `familyCount`, `memberCount`, `memberBytes`, `staticPassedCount`, `staticPassedBytes`, `staticFailedCount`, `staticFailedBytes`, `uncheckedCount`, `uncheckedBytes`, `requiredCheckCount`, `passedCheckCount`, `failedCheckCount`, `uncheckedCheckCount`.
- C5: `familyCount`, `riskVariantCount`, `representativeRequirementCount`, `representativeRequiredCount`, `evidenceAcceptedCount`, `evidenceMissingCount`, `evidenceStaleCount`, `unityExecutionUnavailableCount`, `representativeRejectedCount`, `capabilitySuitabilityRequirementCount`, `suitabilityRequiredCount`, `suitabilityAcceptedCount`, `suitabilityMissingCount`, `suitabilityStaleCount`, `suitabilityExecutionUnavailableCount`, `suitabilityRejectedCount`, `c7RequestCount`.
- C6: `dispatchEligibleObjectCount`, `dispatchEligibleObjectBytes`, `assignedFamilyMemberCount`, `assignedFamilyMemberBytes`, `retainedForDiagnosisObjectCount`, `retainedForDiagnosisObjectBytes`, `configurationOnlyObjectCount`, `configurationOnlyObjectBytes`, `totalFamilyCount`, `needsDiagnosisFamilyCount`, `useOriginalAssetFamilyCount`, `repairOnceFamilyCount`, `prototypeReplacementFamilyCount`, `retainForLaterFamilyCount`, `diagnosticOnlyFamilyCount`, `stopFamilyCount`, `totalMemberCount`, `totalMemberBytes`, `acceptedOriginalPoolMemberCount`, `acceptedOriginalPoolMemberBytes`, `acceptedReplacementSourcePoolMemberCount`, `acceptedReplacementSourcePoolMemberBytes`, `isolatedMemberCount`, `isolatedMemberBytes`, `requiredCapabilityCount`, `satisfiedCapabilityCount`, `unsatisfiedCapabilityCount`, `blockedCapabilityCount`.

The report is UTF-8 without BOM, LF-only, exactly one final LF, and the exact template below. Placeholders use the corresponding JSON scalar and are not emitted literally.

```text
# {stageId} Lifecycle Gate Report
schemaVersion: {schemaVersion}
generatedAt: {generatedAt}
stageId: {stageId}
snapshotId: {snapshotId}
inputFingerprint: {inputFingerprint}
policySetFingerprint: {policySetFingerprint}
gateStatus: {failureAccounting.gateStatus}
inputSubjectCount: {failureAccounting.inputSubjectCount}
inputFailureCount: {failureAccounting.inputFailureCount}
notEvaluatedInputSubjectCount: {failureAccounting.notEvaluatedInputSubjectCount}
outputCandidateCount: {failureAccounting.outputCandidateCount}
projectedOutputCount: {failureAccounting.projectedOutputCount}
outputFailureCount: {failureAccounting.outputFailureCount}
issueCount: {failureAccounting.issueCount}
failureAttribution: {decision.failureAttribution}
nextAllowedAction: {decision.nextAllowedAction}
```

The report is never a machine consumer. Its content fingerprint remains part of the diagnostic bundle fingerprint.

### 1.11 Current schema gaps and required contract-change requests

The current `authoring-reuse-ledger.schema.json` cannot represent member identities, bytes, representative partitions, pool isolation, capability projection, policy fingerprints, or complete direct input fingerprints. C6-O01 cannot be projected losslessly into it. A C0 contract change to authoring reuse ledger v2 is required before C6 implementation.

The current published C2 output set still does not include LC-I06. LC-I13 freezes the package schema and carrier invariants, and the reviewed pure fixture-only C2 typed-fact projection now produces and verifies LC-I06 without changing SP-09. Any published or real-generation LC-I06 still requires a separate reviewed publication contract. LC-I12 remains required only before C6 RepairOnce evaluation, authoring reuse ledger v2 only before C6 output implementation, and each remaining lifecycle vocabulary dimension only when its direct stage consumer begins.

LC-I07's logical and physical registry contract is complete: its non-self-referential fingerprint boundary, exact first-version identity, five policy rows, nested reference sets, NotApplicable/check/axis semantics, capability predicates, repair predicates, ordering, and LF-03 vectors are frozen in the registry and strict JSON Schema. The positive fixture is byte-identical to the registry, focused negative fixtures prove the key fail-closed rules, and the executable contract validator verifies exact-byte formatting, fingerprint, reference closure, row conservation, and capability coverage. This fixture-only completion does not start C3 or authorize publication integration, Phase B, real assets, extraction, import, or Unity.

LC-I11's logical and physical registry contract is complete: it stores no decisionPolicyFingerprint; C5/C6 compute the fingerprint over exact accepted LC-I11 bytes. Its immutable identity, singleton hard-stop set, empty diagnostic-only set, four replacement rules, seven capability rows, exact 13-tuple LC-I07 union, and C5 capability-suitability boundary are frozen in the registry and strict JSON Schema. The positive fixture is byte-identical, focused negative fixtures prove key fail-closed rules, and the executable validator verifies canonical bytes, SHA-256 `82831d240952746c3207d47e8cd6f8ee22edfcbf2044def0cdb0a2767e3fef4a`, reference closure, route/capability matching, and tuple conservation. This fixture-only completion does not start C3/C5 or authorize publication integration, Phase B, real assets, extraction, import, or Unity.

The status vocabulary now contains the exact `familyParentStatus` dimension consumed by C3 and `memberStaticStatus` dimension consumed by the C4-0 walking skeleton. The exact `representativeAssessment`, `capabilitySuitabilityStatus`, `authoringPoolStatus`, and `capabilityStatus` dimensions remain deferred until their direct C5 or C6 consumer begins; component-local aliases are forbidden.

These gaps are explicit contract-change requests. They do not authorize edits to C0/C2 in this design Task.

---

## Hash And Identity Registry

All derived IDs use the exact C2 HI-01 framed UTF-8 byte encoding, including domain line, byte lengths, nullable markers, list/set counts, Ordinal sorting, final LF, SHA-256 lowercase hex, and no Unicode normalization or case folding. Nested rows are encoded as complete independently framed records. No serializer bytes or concatenated delimiter string may substitute for HI-01.

| ID | Prefix / domain | Ordered fields |
|---|---|---|
| LX-HI-01 typed fact | `lane-fact-sha256:` / `C3LaneFactV1` | assetObjectId, lane, factKind, factStatus, valueKind, nullable stringValue, nullable integerValue, nullable booleanValue, idValues set, evidence set |
| LX-HI-02 family key | no prefix / `C3FamilyKeyV1` | lane, familyKindId, policyId, policyVersion, dimension rows sorted by dimensionId |
| LX-HI-03 family | `family-sha256:` / `C3FamilyV1` | policySetFingerprint, familyKeyFingerprint |
| LX-HI-04 member record | `family-member-sha256:` / `C3FamilyMemberV1` | assetObjectId, parentStatus, nullable familyId, nullable configurationCandidateId |
| LX-HI-05 cross-lane reference | `cross-lane-reference-sha256:` / `C3CrossLaneReferenceV1` | fromAssetObjectId, toAssetObjectId, fromLane, toLane, referenceKind |
| LX-HI-06 static check result | `static-check-sha256:` / `C4StaticCheckV1` | assetObjectId, familyId, checkId, outcome, reasonCode, nullable observedFingerprint, evidence set |
| LX-HI-07 member static result | `member-static-sha256:` / `C4MemberStaticV1` | assetObjectId, familyId, staticStatus, checkResultIds set |
| LX-HI-08 risk variant | no prefix / `C5RiskVariantV1` | familyId, riskAxisId, source fact rows |
| LX-HI-09 representative requirement | `representative-requirement-sha256:` / `C5RepresentativeRequirementV1` | familyId, riskAxisId, riskVariantId, candidateMemberIds set, requiredEvidenceKinds set |
| LX-HI-10 evidence package | `evidence-package-sha256:` / `C5EvidencePackageV1` | requirementId, requirementKind, representativeAssetObjectId, executorKind, executionStatus, inputFingerprint, observation digests set, evidencePaths set |
| LX-HI-11 evidence assessment | `evidence-assessment-sha256:` / `C5EvidenceAssessmentV1` | requirementId, nullable representativeAssetObjectId, assessmentStatus, nullable evidencePackageId, expectedInputFingerprint, nullable observedInputFingerprint |
| LX-HI-12 family decision | `family-decision-sha256:` / `C6FamilyDecisionV1` | familyId, decisionPolicyFingerprint, ruleId, decision, nullable repairClass, nullable replacementRouteKind, inputStaticFingerprint, inputEvidenceFingerprint, repairHistoryFingerprint |
| LX-HI-13 capability projection | `capability-projection-sha256:` / `C6CapabilityProjectionV1` | capabilityId, decisionPolicyFingerprint, status, satisfyingFamilyIds set, routeKinds set, suitabilityAssessmentIds set, evidence set |
| LX-HI-14 stage input | no prefix / `LifecycleStageInputV1` | artifact entries encoded exactly as C2 HI-13a and sorted by portable path |
| LX-HI-15 diagnostic bundle | no prefix / `LifecycleDiagnosticBundleV1` | summary/report path-SHA entries sorted by portable path |
| LX-HI-16 repair attempt | `repair-attempt-sha256:` / `C6RepairAttemptV1` | familyId, repairClass, attemptNumber, inputFingerprint, nullable outputFingerprint, expectedChangeMeasure, observedChange, outcome, evidence set |
| LX-HI-17 accounting row | `lifecycle-accounting-sha256:` / `LifecycleAccountingV1` | owningArray, stageId, subjectKind, subjectId, reasonCode, attribution, evidence set |
| LX-HI-18 residual issue | `residual-issue-sha256:` / `C6ResidualIssueV1` | familyId, issueClass, subjectIds set, failureAttribution, evidence set |
| LX-HI-19 capability suitability requirement | `capability-suitability-requirement-sha256:` / `C5CapabilitySuitabilityRequirementV1` | decisionPolicyFingerprint, familyId, capabilityId, routeKind, candidateMemberIds set, nullable selectedRepresentativeAssetObjectId, requiredEvidenceKinds set |
| LX-HI-20 capability suitability assessment | `capability-suitability-assessment-sha256:` / `C5CapabilitySuitabilityAssessmentV1` | suitabilityRequirementId, assessmentStatus, nullable evidencePackageId, expectedInputFingerprint, nullable observedInputFingerprint |
| LX-HI-21 evidence requirement input | no prefix / `C5EvidenceRequirementInputV1` | policySetFingerprint, decisionPolicyFingerprint, requirementId, requirementKind, nullable representativeAssetObjectId, inputStaticFingerprint, requiredEvidenceKinds set |

`factContractFingerprint`, `policySetFingerprint`, and `decisionPolicyFingerprint` are CT-04 SHA-256 over the exact bytes of LC-I13, LC-I07, and LC-I11 respectively. LC-I07 does not contain policySetFingerprint and LC-I11 does not contain decisionPolicyFingerprint; consumers compute both externally from the complete accepted registry bytes. Content changes always change the fingerprint even when version text is unchanged; version reuse with different bytes is invalid.

`inputStaticFingerprint` is LX-HI-14 over the exact current C4-O01, C4-O02, and C4-O03 summary/report artifact set for the generation. `inputEvidenceFingerprint` is LX-HI-14 over the exact current C5-O01, C5-O02, and C5-O04 summary/report artifact set. `repairHistoryFingerprint` is CT-04 SHA-256 over the exact LC-I12 bytes; the exact empty-attempts artifact therefore has a real non-null fingerprint. These three fingerprints are calculated from registered bytes and cannot be display constants.

LX-HI-21 is computed once per C5-O01 requirement after representative selection. Its inputStaticFingerprint is the exact current C4 generation defined above. A null representative remains a distinct framed null. LC-I10 copies this digest as inputFingerprint and C5-O02 copies it as expectedInputFingerprint; observedInputFingerprint is the package value when a package exists. Any policy byte, requirement identity/type, representative, static generation, or required-evidence change therefore makes old evidence stale without reading a filename or display field.

Each LC-I10 observation digest is the independently framed record `C5EvidenceObservationV1` over evidenceKind, outcome, contentFingerprint, and evidence set, in that order. LX-HI-10 sorts those complete nested records by their lowercase SHA-256. No unregistered observation digest is allowed.

---

## Central Definition 2: Subject/Partition Registry

### SP-30 C3 dispatch subjects

Universe: every LC-I04 dispatch row, stable identity `assetObjectId`.

Partitions:

```text
dispatchEligibleObjectCount
= assignedFamilyMemberCount
 + retainedForDiagnosisObjectCount
 + configurationOnlyObjectCount
```

The same equation applies to `serializedSizeBytes` joined exactly from LC-I01.

- AssignedFamilyMember requires exactly one lane policy, one family kind, every required support fact Known, every required family-key fact Known or policy-allowed NotApplicable, and one LX-HI-03 family.
- RetainedForDiagnosis covers Unassigned dispatch, missing/Unknown key facts, zero/multiple family kinds, unresolved policy identity, or unresolved family-key contradiction.
- ConfigurationOnly copies the C2 configuration-only partition and never enters a family.

Every subject has one direct parent. A dependency or cross-lane reference never adds another membership. Family membership conservation is:

```text
assignedFamilyMemberCount = sum(family.memberCount)
assignedFamilyMemberBytes = sum(family.memberBytes)
```

Member ID sets of different families are disjoint. Their union equals the AssignedFamilyMember set.

### SP-31 C3 dependency reference subjects

Universe: every distinct `(fromAssetObjectId,toAssetObjectId,referenceKind)` derived from LC-I01 dependencies and typed coupling facts. Partitions are Resolved, Missing, Conflict.

```text
referenceCount = resolvedReferenceCount + missingReferenceCount + conflictReferenceCount
```

Reference accounting is independent of membership accounting.

### SP-40 C4 family member subjects

Universe: every C3 AssignedFamilyMember. Partitions are StaticPassed, StaticFailed, Unchecked.

For every family:

```text
family.memberCount
= staticPassedCount
 + staticFailedCount
 + uncheckedCount

family.memberBytes
= staticPassedBytes
 + staticFailedBytes
 + uncheckedBytes
```

Every policy-required check also has exactly one Passed, Failed, or Unchecked row:

```text
requiredCheckCount = passedCheckCount + failedCheckCount + uncheckedCheckCount
```

An asset failure is a valid qualification outcome, not a C4 contract failure. C4 gateStatus remains Passed when every subject is terminal and every formula holds, even if some members are StaticFailed or Unchecked.

### SP-50 C5 representative requirement subjects

Universe: one LX-HI-09 requirement for every distinct `(familyId,riskAxisId,riskVariantId)` required by LC-I07. Partitions are exactly:

```text
representativeRequirementCount
= representativeRequiredCount
 + evidenceAcceptedCount
 + evidenceMissingCount
 + evidenceStaleCount
 + unityExecutionUnavailableCount
 + representativeRejectedCount
```

The selected representative, when non-null, belongs to the same family, is C4 StaticPassed, and matches the risk variant. One representative may satisfy several requirements only through separate requirement/assessment rows; it is never counted as one merged requirement.

Evidence absence, staleness, Unity unavailability, or representative rejection is a valid C5 assessment outcome, not a C5 contract failure. C5 never writes EvidenceAccepted without exact package freshness and complete required Passed evidence kinds.

### SP-51 C5 capability-suitability subjects

Universe: one LX-HI-19 requirement for every LC-I11-admitted `(familyId,capabilityId,routeKind)` tuple. Partitions are exactly:

```text
capabilitySuitabilityRequirementCount
= suitabilityRequiredCount
 + suitabilityAcceptedCount
 + suitabilityMissingCount
 + suitabilityStaleCount
 + suitabilityExecutionUnavailableCount
 + suitabilityRejectedCount
```

The family must match the capability's lane/family kind and, for Actor capabilities, its exact ActorRole. The route must be in both LC-I07 and LC-I11 for that capability. Every subject has one LX-HI-20 assessment. SuitabilityAccepted requires exact fresh Passed `CapabilitySuitability` evidence for that subject; evidence for another capability, route, family, or requirement is nonmatching. Missing, stale, unavailable, and rejected suitability are valid C5 outcomes and produce C7 requests where applicable; they never become inferred success.

### SP-60 C6 family decision subjects

Universe: every C3 family. Partitions are the seven existing disposition values:

```text
totalFamilyCount
= needsDiagnosisFamilyCount
 + useOriginalAssetFamilyCount
 + repairOnceFamilyCount
 + prototypeReplacementFamilyCount
 + retainForLaterFamilyCount
 + diagnosticOnlyFamilyCount
 + stopFamilyCount
```

The member universe is every C3 AssignedFamilyMember. Pool partitions are:

```text
totalMemberCount
= acceptedOriginalPoolMemberCount
 + acceptedReplacementSourcePoolMemberCount
 + isolatedMemberCount
```

and the same equation holds for bytes.

Only members of a UseOriginalAsset family may be AcceptedOriginalPool. A PrototypeReplacement family may contribute only C4 StaticPassed original-media members explicitly named by a replacement rule to AcceptedReplacementSourcePool. StaticFailed and Unchecked members are always Isolated.

OriginalAssetBatchCoverage is exact:

```text
reusableFamilyCount = useOriginalAssetFamilyCount
reusableMemberCount = members in UseOriginalAsset families
reusableBytes = bytes of members in UseOriginalAsset families
```

PrototypeReplacement never increases those reusable counts.

### SP-61 C6 capability subjects

Universe: the seven required LC-I11 capability IDs. Partitions are Satisfied, Unsatisfied, Blocked.

```text
requiredCapabilityCount
= satisfiedCapabilityCount
 + unsatisfiedCapabilityCount
 + blockedCapabilityCount
```

Satisfied requires at least one exact matching capability rule, a qualifying family/route, all rule-required evidence accepted, the exact C5 capability/route suitability assessment SuitabilityAccepted, and only an allowed family decision. RepairOnce, NeedsDiagnosis, RetainForLater, DiagnosticOnly, and Stop never satisfy a capability.

PrototypeReplacement may satisfy only a rule whose `allowedFamilyDecisions` explicitly includes it and whose original source members are in AcceptedReplacementSourcePool. Thus authoring readiness can be true while OriginalAssetBatchCoverage is less than 100 percent; the two conclusions remain independent.

Capability status is exact: Satisfied follows the rule above; Blocked means at least one policy-eligible family exists but its current decision/evidence state is NeedsDiagnosis, RepairOnce, PrototypeReplacement without accepted required route evidence, RetainForLater, SuitabilityRequired, SuitabilityMissing, SuitabilityStale, or SuitabilityExecutionUnavailable; Unsatisfied means no policy-eligible family/route exists, every eligible family is DiagnosticOnly or Stop, or every otherwise eligible exact route has SuitabilityRejected.

```text
StellaSora2AuthoringReady
= all seven required capabilities Satisfied
 + every StaticFailed/Unchecked/nonaccepted member Isolated
```

This is a boolean predicate, not an arithmetic replacement for coverage.

---

## C6 Decision Precedence

C6 applies one deterministic rule in this exact order after all inputs are fresh and conserved:

1. `DiagnosticOnlyRule`: family kind listed in `diagnosticOnlyFamilyKinds` -> DiagnosticOnly.
2. `HardStopRule`: any LC-I11 hard-stop failure class -> Stop.
3. `NeedsDiagnosisRule`: missing, conflicting, or non-unique failure attribution or decision input -> NeedsDiagnosis.
4. `RepairOnceRule`: exactly one eligible repair rule, required inputs present, measurable expected change defined, and no matching LC-I12 attempt row -> RepairOnce.
5. `PrototypeReplacementRule`: exactly one eligible replacement rule, a nonempty actionable failure-class set within the rule, every named original-media static check Passed, and every required replacement-route evidence kind accepted -> PrototypeReplacement.
6. `UseOriginalAssetRule`: every member StaticPassed, every C5 risk-variant requirement EvidenceAccepted, no missing/stale/unavailable/rejected risk requirement, and no unresolved C3 reference -> UseOriginalAsset.
7. `RetainForLaterRule`: every member StaticPassed but at least one risk-variant requirement is EvidenceMissing, EvidenceStale, or UnityExecutionUnavailable -> RetainForLater.
8. `TerminalStopRule`: any remaining valid terminal asset outcome -> Stop.

Two matching repair/replacement/decision rules are a contract conflict, not a tie to be broken by order. RepairOnce can be emitted only before the one allowed attempt. The same failure after that attempt evaluates again without RepairOnce eligibility.

SP-51 capability-suitability outcomes never change the family decision selected above. They affect only SP-61: a reusable or replacement family may remain valid while one capability/route is Blocked or Unsatisfied. This prevents a CombatSfx suitability rejection from turning an otherwise reusable BGM family into an asset-level rejection.

---

## Central Definition 3: Failure Transition Table

Contract failures differ from valid asset/evidence outcomes. A contract failure suppresses success outputs for that stage and all downstream stages. StaticFailed, Unchecked, EvidenceMissing, EvidenceStale, UnityExecutionUnavailable, RepresentativeRejected, and non-UseOriginalAsset decisions remain valid rows when their contracts are complete.

| ID | Owner and failure | Stable subject | Accounting/result | Stage output vector | Next action |
|---|---|---|---|---|---|
| LF-01 | Any stage required input missing, Failed, stale, or hash-mismatched | exact artifact ID or stage freshness check | one contract failure | diagnostic only | Restore exact fresh prerequisite; do not rerun unrelated stages |
| LF-02 | LC-I06 typed fact shape/carrier/identity invalid | fact ID or LC-I06 artifact | one input failure | C3 diagnostic only | Correct typed projection contract/fixture |
| LF-03 | LC-I07/LC-I11 policy shape, ID reference, uniqueness, version, or fingerprint invalid | exact policy artifact | one contract failure | owning/downstream diagnostic only | Correct reviewed policy artifact |
| LF-04 | C3 zero/multiple family kind or required Unknown fact | assetObjectId | valid RetainedForDiagnosis outcome | C3 Passed outputs allowed | Add reviewed typed facts/policy revision; no inferred default |
| LF-05 | C3 duplicate membership, family-key collision, or membership conservation mismatch | C3 conservation check | one contract failure | C3 diagnostic only | Correct C3 producer; no C4-C6 |
| LF-06 | C3 cross-reference identity/conservation conflict | reference ID or reference conservation check | Conflict row if uniquely attributable; otherwise contract failure | Passed package or C3 diagnostic only | Correct reference facts/producer |
| LF-07 | C4 required check cannot execute for a declared reason | static check ID | valid Unchecked result | C4 Passed outputs allowed | Resolve named reason; never project Passed |
| LF-08 | C4 check observes asset failure | static check ID | valid Failed result and StaticFailed member | C4 Passed outputs allowed | Apply C6 decision rules later |
| LF-09 | C4 missing/duplicate check row, invalid outcome, or member/check conservation mismatch | member or C4 conservation check | one contract failure | C4 diagnostic only | Correct C4 producer; no C5/C6 |
| LF-10 | C5 no StaticPassed candidate | requirement ID | RepresentativeRequired | C5 Passed outputs allowed | Resolve C4/C3 facts; no fake representative |
| LF-11 | C5 no evidence package | requirement ID | EvidenceMissing | C5 Passed outputs allowed | Emit C7 request; no execution |
| LF-12 | C5 package stale | requirement ID | EvidenceStale | C5 Passed outputs allowed | Request fresh evidence only |
| LF-13 | C7/G4 reports unavailable | requirement ID | UnityExecutionUnavailable | C5 Passed outputs allowed | Preserve distinction from rejection |
| LF-14 | Required evidence rejects representative | requirement ID | RepresentativeRejected | C5 Passed outputs allowed | C6 decides diagnosis/repair/replacement/stop |
| LF-15 | C5 package identity/manifest mismatch, duplicate risk/suitability assessment, wrong capability/route evidence, or requirement conservation mismatch | artifact, requirement, or C5 conservation check | one contract failure | C5 diagnostic only | Correct evidence authority/producer |
| LF-16 | C6 stale child, duplicate/missing family/member, or family/member conservation mismatch | C6 freshness/conservation check | one contract failure | C6 diagnostic only | Correct exact owning input; do not rerun heavy work implicitly |
| LF-17 | C6 zero/multiple decision rule or invalid decision transition | familyId | one contract failure | C6 diagnostic only | Correct LC-I11 or source attribution |
| LF-18 | C6 capability projection contradiction or loss | capabilityId or capability conservation check | one contract failure | C6 diagnostic only | Correct capability policy/projection |
| LF-19 | Current C0 authoring ledger/root schemas cannot represent mandatory C6 state | C0 contract-change check | one contract failure until reviewed schema change | C6 diagnostic only | Complete C0 contract change before implementation |
| LF-20 | Any stage attempts child rerun, C7/G4, Unity, extraction, import, real asset access, or unapproved write | stage lightweight-policy check | one contract failure | diagnostic only | Remove heavy/unauthorized operation |
| LF-21 | Diagnostic or success output serialization/write/publication failure | exact output artifact | output failure | no consumable new generation | Restore/quarantine exact generation and repair publisher |

Reason codes are exact:

| LF | reasonCode |
|---|---|
| LF-01 | PrerequisiteInvalid |
| LF-02 | InvalidTypedFact |
| LF-03 | InvalidPolicy |
| LF-04 | MissingFamilyFact |
| LF-05 | ConservationMismatch |
| LF-06 | ReferenceConflict |
| LF-07 | StaticCheckUnavailable |
| LF-08 | StaticCheckFailed |
| LF-09 | StaticContractInvalid |
| LF-10 | RepresentativeUnavailable |
| LF-11 | EvidenceMissing |
| LF-12 | EvidenceStale |
| LF-13 | UnityExecutionUnavailable |
| LF-14 | RepresentativeRejected |
| LF-15 | EvidenceContractInvalid |
| LF-16 | ConservationMismatch |
| LF-17 | DecisionConflict |
| LF-18 | CapabilityProjectionInvalid |
| LF-19 | ContractChangeRequired |
| LF-20 | HeavyOperationAttempted |
| LF-21 | ProjectionInvalid |

`PrerequisiteUnavailable` is reserved for inputSuppressions and `SuppressedByGate` for derived outputFailures. Valid qualification outcomes LF-04, LF-06 when uniquely attributable, LF-07, LF-08, and LF-10 through LF-14 do not enter inputFailures merely because their asset/evidence outcome is non-passing.

LF-10 through LF-14 also own the parallel SP-51 outcomes for a suitabilityRequirementId: no StaticPassed candidate -> SuitabilityRequired; no package -> SuitabilityMissing; stale package -> SuitabilityStale; Unavailable execution -> SuitabilityExecutionUnavailable; Rejected CapabilitySuitability observation -> SuitabilityRejected. They reuse the same LF reasonCode and remain valid C5 rows. A package bound to the wrong capability or route is instead LF-15 and suppresses all C5 success outputs.

Logical output conservation is fixed:

```text
C3: 4 = 4 projected + 0 failed on Passed; 4 = 1 diagnostic + 3 failed on contract Failed
C4: 3 = 3 projected + 0 failed on Passed; 3 = 1 diagnostic + 2 failed on contract Failed
C5: 4 = 4 projected + 0 failed on Passed; 4 = 1 diagnostic + 3 failed on contract Failed
C6: 5 = 5 projected + 0 failed on Passed; 5 = 1 diagnostic + 4 failed on contract Failed
```

LF-21 diagnostic persistence failure yields zero consumable outputs for that stage. No stale prior success output may satisfy the current generation fingerprint.

### Evaluation order and downstream authorization

Each stage evaluates: lightweight policy -> required artifact identity/shape -> freshness -> policy identity -> direct subject partitions -> conservation -> projection -> output publication. Independent subject outcomes are completed when prerequisites exist. A missing prerequisite makes a downstream check NotEvaluated; it does not manufacture a second failure.

C4 consumes only a Passed C3 generation. C5 consumes only Passed C3 and C4 generations. C6 consumes only Passed C3, C4, and C5 generations. G5 consumes only a Passed C6-O04 handoff and never reads C3-C5 directly.

No stage implicitly refreshes a child. A C7 evidence change invalidates only C5 and C6 fingerprints; C3 and C4 remain current when their own inputs are unchanged. A policy fact/key change invalidates C3-C6. A static observation change invalidates C4-C6.

On a contract-Passed stage, diagnostic decision failureAttribution is exactly `None; {stageId} lifecycle contract passed.` NextAllowedAction is respectively: C3 `Provide the current family generation to C4.`; C4 `Provide the current static generation to C5.`; C5 `Provide the current requirement and assessment generation to C6; C7 requests remain separately authorized.`; C6 `Provide only the current C6 G5 handoff to G5.`

---

## Fixed Counterexample Matrix

Implementation plans and completion verification must instantiate these from zero; keyword scans are insufficient.

| Case | Required result |
|---|---|
| One dispatch object appears in two family keys | LF-05; no C3 success outputs |
| Cross-lane dependency points to an object in another family | one reference row; both objects retain one direct family parent |
| Required SkeletonId is Unknown | Actor object RetainedForDiagnosis; not assigned to an Unknown skeleton family |
| NotApplicable used where policy disallows it | LF-02/LF-03 contract failure |
| Same family facts arrive shuffled | same family key/family ID after Ordinal framing |
| Same policy version with changed bytes | fingerprint/version conflict; LF-03 |
| One member has Passed, Failed, and missing required checks | exactly one terminal result per check; missing check is LF-09, never inferred Unchecked |
| Tool unavailable for one static check | Unchecked with ToolUnavailable; family not StaticQualified |
| One family has three risk variants and one representative covers two | three requirement rows; two may select same object, counts remain three |
| Evidence package exists for wrong requirement | LF-15; not EvidenceAccepted |
| Evidence input fingerprint changed | EvidenceStale; C3/C4 fingerprints unchanged |
| Unity unavailable | UnityExecutionUnavailable, not RepresentativeRejected and not EvidenceMissing |
| Looped audio has no BGM suitability package | SuitabilityMissing for PlayableBgmRoute; LoopMode/LoopBehavior never supplies BGM identity |
| One audio representative has BGM suitability but no combat-SFX suitability | BGM tuple may pass; PlayableCombatSfx remains Blocked/Unsatisfied according to its own suitability partition |
| Suitability package names the right capability but wrong route | LF-15; no SuitabilityAccepted and no cross-route reuse |
| Static all pass but one required evidence missing | RetainForLater, never UseOriginalAsset |
| One hard-stop member and one good member | family Stop; both member rows retained and nonaccepted members isolated |
| Eligible replacement route uses qualified original media | PrototypeReplacement may satisfy an explicitly allowed capability but adds zero OriginalAssetBatchCoverage |
| Repair rule matches twice | LF-17; no arbitrary first rule |
| Second identical failure after one repair | RepairOnce ineligible; re-evaluate to replacement/diagnosis/stop |
| All seven capabilities satisfied but reusable coverage below 100% | AuthoringReady may be true; coverage remains partial and separately visible |
| Coverage 100% but one required capability absent | AuthoringReady false |
| G5 reads a C4 summary directly | fail policy; only C6-O04 is allowed C3-C6 input |
| C5 attempts Unity | LF-20; no success outputs |
| Failed stage leaves stale success files | consumer rejects generation by fingerprint |

Every counterexample must verify all simultaneous SP-30/SP-31/SP-40/SP-50/SP-51/SP-60/SP-61 formulas that are applicable, exact failure ownership, and the stage output vector.

---

## Freshness And Refresh Semantics

Every stage input fingerprint is LX-HI-14 over exact direct artifact bytes. Every output records direct input paths and hashes in its diagnostic summary. File existence without a matching stage fingerprint is stale.

Refresh boundaries are exact:

- C2 generation or LC-I06/LC-I07 change -> rerun C3, then C4, C5, C6.
- C3 output change -> rerun C4, C5, C6.
- C4 static evidence or output change -> rerun C4, C5, C6; C3 remains unchanged.
- LC-I09/I10 C7/G4 evidence change -> rerun C5 and C6 only.
- LC-I11 decision/capability policy change -> rerun C5, then C6; C3 and C4 remain unchanged.
- LC-I12 repair-attempt history change -> rerun C6 only.
- G5 schema/aggregation change -> rerun G5 only when C6-O04 remains current.

No refresh may launch Unity, extraction, import, or another stage unless its exact command mode and separate authorization are present.

---

## Phase A Implementation Preconditions And Sequence

The C3-0/C3-1 fixture-only path consumes LC-I06/LC-I07 and the minimal `familyParentStatus` vocabulary, proves executable family/reference conservation, and emits the complete byte-frozen C3 success and diagnostic output vectors without publication. LC-I12 is required only before C6 RepairOnce evaluation, authoring reuse ledger v2 only before C6 output implementation, and every remaining vocabulary dimension only when its direct stage consumer begins.

The later implementation sequence is:

1. C3-0 pure family-membership walking skeleton; prove the executable SP-30 core and cross-lane-reference independence without publication.
2. C3-1 family registry Task; complete SP-30/SP-31 and the C3 output vector.
3. C4-0 pure member-static walking skeleton; consume only `memberStaticStatus` and prove the executable five-lane SP-40 core without publication.
4. C4-1 static output-vector Task; complete C4-O01/O02/O03 and contract-failure semantics.
5. C5 requirement/evidence Task; prove all six risk statuses, all six suitability statuses, SP-50, and SP-51 without C7/G4 execution.
6. C6 decision/ledger Task; prove precedence, coverage/readiness independence, SP-60/SP-61, and G5-only handoff.
7. Independent C3-C6 completion audit across all fixed counterexamples.

Each Task remains 20-30 minutes with 2-5 minute Steps, exact files, RED/GREEN evidence, protected-input checks, forbidden-path checks, precise staging, one commit, and a stop checkpoint. No plan authorizes the next Task automatically.

## Acceptance Of This Design

The design is closed only when all of the following remain true under review:

- every C2 dispatch subject has one C3 direct parent and every family member appears once;
- cross-lane dependencies are references, never duplicate membership;
- every lane difference is a typed, versioned, fingerprinted policy row rather than component-local interpretation;
- every required static check has one terminal C4 outcome and Unchecked is never Passed;
- every risk variant has one C5 requirement and one of the six exact assessment states;
- every admitted family/capability/route tuple has one C5 suitability requirement and one of the six exact suitability states;
- C5 does not run Unity and C7/G4 cannot mutate C3/C4 facts;
- C6 is the sole decision/ledger owner and does not rerun or reinterpret child gates;
- OriginalAssetBatchCoverage and StellaSora2AuthoringReady are independently conserved and projected;
- G5 reads only the C6 handoff among C3-C6 artifacts;
- every current schema loss triggers an explicit contract-change request rather than silent projection;
- every contract failure has one owner, deterministic suppression, and zero downstream-valid output;
- no arbitrary metadata, payload, callback, expression, or default success path exists.

Until the required C0/C2 contract changes are approved, C3-C6 implementation status is `BLOCKED`.
