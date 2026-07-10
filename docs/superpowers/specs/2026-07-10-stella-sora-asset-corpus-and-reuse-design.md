# StellaSora Complete Asset Corpus And Reuse Design

**Date:** 2026-07-10
**Status:** Approved design; documents and gates only
**Scope:** Local StellaSora PC install, existing PC patch/cache data, provided Android APK, and provided Android DATA/cache

## Purpose

Design a verifiable workflow for recovering a complete local snapshot of StellaSora source data and turning qualified original assets into an authoring pool for a new `StellaSora2` Unity project.

The design separates two questions that must never be conflated:

1. Did the workflow account for every byte and file in the agreed local input snapshot?
2. Which recovered assets are proven usable for StellaSora2 authoring?

The first question is answered by a source corpus ledger. The second is answered by an authoring reuse ledger and family-specific Unity evidence. Neither result claims restoration of the original StellaSora Unity project.

## Decisions

- Use a dual-ledger, layered-gate architecture.
- Define completeness against a frozen local snapshot, not against unknown CDN or server-side content.
- Include the PC install, existing PC patch/cache data, Android APK, and provided Android DATA/cache as normal sources.
- Inventory all source files without an extension allowlist.
- Discover and classify every configuration candidate; parsing is best effort rather than a global hard gate.
- Run static checks against every cataloged asset member, then run Unity against representative samples from homogeneous risk families.
- Report corpus completeness, structured object coverage, original-asset reuse coverage, and StellaSora2 authoring readiness separately.
- Keep extraction output under `Extracted`. Only explicitly accepted batches may be staged under `Assets/StellaGaia`.
- Keep gameplay implementation, asset extraction, Unity execution, and bulk import outside this design-document change.

## Relationship To The 2026-06-02 Design

This design supersedes the asset scope, first-milestone definition, batch-expansion rule, and overall completion criteria in `docs/superpowers/specs/2026-06-02-unity-asset-migration-design.md`.

It preserves these earlier decisions:

- The source install is read-only.
- Generated extraction output is separate from final Unity content.
- Unity `2022.3.62f2` remains the compatibility baseline unless later evidence changes it.
- Extracted third-party assets are not approved for public redistribution.
- Missing shaders, controllers, prefab behavior, and Wwise semantics may require a new local control layer.

The old representative validation scene becomes a G4 witness step. It is no longer evidence that the complete input corpus was recovered. The old exclusion of `.arcx`, `.arch`, script, and table containers is removed for discovery: those inputs must be cataloged and classified, although successful semantic parsing is not guaranteed.

## Evidence Interpretation

Public evidence is used in two distinct roles.

Direct Unity extraction and repair workflows, including AssetRipper, AssetStudio, Il2CppDumper, UABEA, Risk of Rain 2 modding workflows, Valheim asset-development workflows, wwiser, and vgmstream, support the feasibility of locating, exporting, decoding, repairing, and reusing game assets. They also show that package repair, Unity-version matching, shader replacement, dependency repair, and new authoring control layers are normal parts of the process.

Daggerfall Unity, OpenMW, DevilutionX, OpenRCT2, and ScummVM are architectural analogies. They support the model of user-owned source data plus a new runtime or control layer, but they are not direct proof that a modern Unity/IL2CPP project can be restored.

Tool capability or tutorial existence never grants a local StellaSora asset a passing status. Local manifests and current evidence remain authoritative for local acceptance.

## Input Boundary

The frozen input snapshot contains only data already present locally at capture time:

- `C:\SoftGame\YostarGames\StellaSora_CN`, including existing patch and cache data below that source boundary.
- The provided Android APK.
- The provided Android DATA/cache payload.

Runtime network capture, CDN enumeration, account-specific downloads, and server-side configuration retrieval are excluded. Their absence must be stated as an input-boundary limitation rather than interpreted as a failed local snapshot.

Every source root receives a stable `sourceId`, source kind, capture timestamp, and root fingerprint. Absolute local paths remain in machine-local evidence; portable ledgers use `sourceId` plus relative paths.

## Gate Architecture

| Gate | Responsibility | Required output |
| --- | --- | --- |
| G0 Input Snapshot | Freeze source roots, capture times, source kinds, and fingerprints. | `InputSnapshotFrozen` |
| G1 Corpus Coverage | Inventory every source file without extension filtering and classify each file as a container, direct media, metadata, configuration candidate, or opaque input. | `CorpusCatalogComplete` |
| G2 Extraction And Discovery | Enumerate objects from parseable containers, record tool observations, classify configuration candidates, and group PC/Android duplicates or variants. | `ExtractionCoverageKnown` |
| G3 Asset Family Static | Run full static checks for every member of every asset family. | Per-family `StaticQualified`, `StaticRejected`, or `NeedsDiagnosis` counts |
| G4 Representative Unity | Validate samples that cover every material import-risk variant within a reusable family. | Per-family `RepresentativeValidated` evidence |
| G5 Root Decision | Read current summaries and both ledgers without implicitly rerunning extraction or Unity. | Independent corpus, coverage, and authoring conclusions |

Gate dependencies are one-way. G5 aggregates; it does not refresh G0-G4. Heavy work requires an explicit command mode such as `-RefreshSnapshot`, `-RunExtraction`, or `-RunUnity`.

## Root Conclusions

G5 publishes independent conclusions rather than one overloaded `Go` flag.

### CorpusSnapshotComplete

`CorpusSnapshotComplete=true` means every file and byte in the frozen local source roots is represented by a ledger row with a matching size and hash, and every file has a declared parse or disposition state.

It does not mean every opaque container has been semantically parsed. Opaque inputs remain part of the complete byte/file snapshot and are reflected in structured-coverage metrics.

### StructuredObjectCoverage

`StructuredObjectCoverage` reports:

- Parsed container count and bytes.
- Opaque or failed container count and bytes.
- Enumerated Unity object count.
- Classified object count.
- Unclassified object count.
- Configuration-candidate discovery and parse counts.

This metric prevents an opaque 10 GB container from disappearing behind a file-level completeness claim.

### OriginalAssetBatchCoverage

`OriginalAssetBatchCoverage` reports `BatchReusable / total` counts and bytes for every asset family. Only 100 percent coverage may be described as all original assets being development-usable. Partial percentages must remain visible even when the minimum StellaSora2 capability set is ready.

### StellaSora2AuthoringReady

`StellaSora2AuthoringReady=true` requires at least one original-asset batch for each required capability:

- Recognizable environment or map modules.
- A player model, Avatar or skeleton, and usable animation set.
- An enemy model, Avatar or skeleton, and usable animation set.
- A combat effect route.
- Reusable UI graphics and a local UI construction route.
- A playable BGM route.
- Playable combat SFX.

All unchecked or failed members must be isolated from the accepted pool. This status means a trustworthy original-asset authoring pool exists; it does not mean every original asset is usable.

`OriginalUnityProjectRestored` is not a valid goal or status.

## Source Corpus Ledger

The source corpus ledger contains one row per source file and, where parsing succeeds, one row per contained object.

File-level fields:

- `snapshotId`
- `sourceId`
- `sourceKind`: `PcInstall`, `PcPatchOrCache`, `AndroidApk`, or `AndroidDataOrCache`
- `relativePath`
- `sizeBytes`
- `sha256`
- `capturedAt`
- `containerKind`
- `parseStatus`
- `disposition`
- `evidence`

Object-level fields:

- `assetObjectId`, derived from source, container, Unity `pathId`, and class identity
- `containerRelativePath`
- `classId`
- `objectType`
- `objectName`
- `serializedSizeBytes`
- `dependencyObjectIds`
- `toolObservations`
- `canonicalAssetId`
- `platformVariant`
- `configurationDisposition`
- `evidence`

An unrecognized file is allowed only when it is explicitly represented as opaque. A missing ledger row is never allowed.

## Canonical Assets And Platform Variants

PC and Android are peer source inputs at the corpus level. Android is not globally `DiagnosticInputOnly`.

Content-identical objects share a `canonicalAssetId`. Platform-specific texture encodings, shaders, audio encodings, or serialized variants link to the same canonical group while retaining separate source-object rows.

An Android-only object may become a canonical authoring source after format conversion, dependency analysis, and family validation. An individual object may be assigned `DiagnosticOnly` when it is useful only for comparison, but that is an object disposition rather than a source-wide status.

## Configuration Discovery

Configuration discovery is mandatory. Successful parsing of every candidate is not.

Candidate types include:

- Unity `TextAsset`, `ScriptableObject`, and serialized `MonoBehaviour` data.
- JSON, CSV, XML, protobuf-like, MessagePack-like, or other structured payloads.
- `.arcx`, `.arch`, Addressables catalogs, localization data, and table-like binary containers.
- IL2CPP metadata and dummy assemblies that can explain serialized field layouts.

Each candidate receives exactly one current disposition:

- `Parsed`
- `DiscoveredOpaque`
- `Encrypted`
- `RequiresRuntimeType`
- `LikelyServerDependent`
- `NotConfiguration`

Unparsed candidates do not block `CorpusSnapshotComplete`. They block `OriginalConfigurationRecovered` and remain visible in `StructuredObjectCoverage`. Rebuilt StellaSora2 gameplay tables must be named as new project data and never counted as recovered original configuration.

## Authoring Reuse Ledger

The authoring reuse ledger records family-level qualification and evidence.

Required fields:

- `familyId`
- `category`
- `memberSelector`
- `memberCount`
- `staticPassedCount`
- `staticFailedCount`
- `uncheckedCount`
- `representativeAssetIds`
- `representativeSelectionReason`
- `unityEvidence`
- `residualIssues`
- `failureAttribution`
- `decision`
- `nextAllowedAction`
- `generatedAt`
- `inputFingerprint`
- `toolVersions`
- `directGateSummary`
- `directGateReport`

Family membership is based on shared import risk, not only directory or broad art category. Relevant grouping dimensions include skeleton, Avatar, Shader family, renderer type, prefab dependency structure, texture compression, audio encoding, bank/event structure, and UI atlas/font dependencies.

## Orthogonal Status Dimensions

Status is represented across independent dimensions. It is not one ordered ladder.

Example:

```text
Corpus=Cataloged
Extraction=CrossToolVerified
Semantics=Unknown
Unity=NotTested
Disposition=RetainForLater
```

Required dimensions:

- Corpus: `Cataloged`, `Missing`, or `StaleInput`
- Extraction: `NotAttempted`, `ExtractedReadable`, `CrossToolVerified`, `Opaque`, or `Failed`
- Semantics: `Known`, `PartiallyKnown`, `Unknown`, or a configuration disposition
- Unity: `NotTested`, `StaticQualified`, `RepresentativeValidated`, `Rejected`, or `UnityExecutionUnavailable`
- Disposition: `NeedsDiagnosis`, `UseOriginalAsset`, `RepairOnce`, `PrototypeReplacement`, `RetainForLater`, `DiagnosticOnly`, or `Stop`

This replaces the current practice of assigning unlike states such as `DiagnosticInputOnly` and `DevelopmentUsable` ranks on one scale.

## Asset Family Acceptance

### Environment And Maps

Static checks cover Scene, Prefab, Mesh, Material, Texture, Lightmap, Collider, NavMesh, and dependency closure. Representative samples cover map theme, module type, and Shader combination. Unity evidence must show recognizable original content, intact primary meshes, non-magenta materials, and modules that can be placed in a new scene.

Scene layout, environment art, and gameplay room configuration are reported separately. A usable module does not prove recovery of a complete original room.

### Characters And Enemies

Static checks cover models, skeletons, Avatars, AnimationClips, materials, textures, and original controller references. Representatives cover each skeleton and rendering combination. Where corresponding clips exist, Unity evidence covers idle, move, attack, hit, and death.

A new prototype controller is valid authoring infrastructure but is never labeled as the recovered original Animator Controller.

### Effects

Static checks cover ParticleSystem, VFX, Trail, Mesh, Material, Shader, texture, and audio references. Representatives cover particle, mesh, trail, and Shader combinations. When original Shader behavior cannot be recovered, retained original media plus rebuilt behavior is labeled `EffectBehaviorReconstructed`.

### UI

Static checks cover Texture, Sprite, Atlas, Font, Material, Prefab, animation, and script references. Representatives cover atlas, font, prefab-risk, and texture-only rebuild routes. Reusable graphics and recovered original UI behavior are separate conclusions.

### Audio

Static checks cover every WEM and BNK, media ID, bank provenance, decode outcome, and loop hint. Representatives cover BGM, SFX, voice, loop, and event structures. Unity playback and human listening are required for authoring acceptance. wwiser/TXTP evidence is used when available to strengthen event semantics.

### Video, Subtitles, And Localization

These sources remain part of corpus completeness and receive format and relationship checks. They do not block the initial required StellaSora2 authoring capability set unless a later product requirement promotes them.

## Failure Decisions

`UseOriginalAsset` requires a static-qualified homogeneous family and passing representative Unity evidence.

`RepairOnce` requires a concrete failure attribution, explicit repair inputs, and a measurable expected change. Valid examples include dependency closure, material mapping, import settings, prototype controller construction, UI texture-only rebuild, or Wwise semantic recovery.

`RepairOnce` is never a default. Without a failure cause the decision is `NeedsDiagnosis`. If the same failure class remains after one focused repair, the family moves to `PrototypeReplacement` or `Stop`.

`PrototypeReplacement` means original graphics, model data, clips, or audio may remain useful while original runtime behavior is rebuilt in the new control layer.

`Stop` applies when core data is absent, an object remains unparseable, a critical Mesh or skeleton is missing, or a focused repair fails without evidence of improvement.

## Data Flow And Write Boundaries

```text
Freeze local snapshot
-> inventory every source file
-> enumerate Unity and configuration objects
-> record multi-tool observations
-> canonicalize PC and Android variants
-> build homogeneous asset families
-> run full static family checks
-> run representative Unity witnesses
-> update the authoring reuse ledger
-> aggregate the lightweight root gate
```

All extraction and generated evidence stays under `Extracted`. No tool may write into a source root. No complete AssetRipper export may be copied into the target Unity project. Controlled staging under `Assets/StellaGaia` is allowed only for an explicit family whitelist after the relevant family gate authorizes it.

## Freshness And Evidence

Every generated report includes:

- `generatedAt`
- `inputFingerprint`
- tool and tool version
- command or operation identity
- direct child summary/report paths
- input, output, failure, and exclusion counts
- failure attribution
- next allowed action

If a source fingerprint or child fingerprint changes, downstream summaries become `StaleInput`. They do not refresh automatically.

An evidence path existing on disk is insufficient. Validators must read structured evidence and verify count conservation, fingerprints, timestamps, and accepted decision vocabulary.

## Testing

### Conservation Tests

- Source file count equals cataloged file count plus explicitly excluded file count.
- Source bytes equal cataloged bytes plus explicitly excluded bytes.
- Parsed-container object count equals classified, opaque, failed, or unclassified object counts as defined by the parser contract.
- Family member count equals static passed, static failed, and unchecked counts.
- Accepted, repair, replacement, retained, diagnostic, and stopped members account for every family member.

### Contract Tests

Contract tests validate schemas, orthogonal status vocabularies, required timestamps, fingerprints, tool versions, direct reports, failure attribution, and next actions using fixtures or existing summaries. They do not invoke extraction or Unity and should complete in seconds.

### Integration Gates

Integration gates run only through explicit heavy modes. Unity execution must distinguish `UnityExecutionUnavailable` from failed asset evidence. A Unity run produces triage evidence; it does not update `StellaSora2AuthoringReady` until the authoring reuse ledger is updated and G5 is rerun.

## Migration Of Existing Gates

The later implementation plan will change documents and gate semantics in small increments:

- Replace the five-extension inventory assumption with a source snapshot and all-file corpus contract.
- Keep existing audio, environment, actor, UI, controlled-import, and minimum-slice evidence as G3/G4 child evidence where fingerprints remain current.
- Reframe `Test-AssetAcquisitionGate.ps1` as a G2 evidence validator rather than a corpus-completeness gate.
- Make the root gate aggregate current summaries without invoking every heavy child gate.
- Make policy tests read fixtures or summaries instead of rerunning the full root workflow.
- Add separate root fields for corpus completeness, structured coverage, batch coverage, and authoring readiness.
- Update `CONTEXT.md`, the external research note, the third-party review summary, acceptance manifests, and gate-status documentation to use the new language.

Existing evidence is not discarded solely because the root model changes. It must be re-indexed against the frozen snapshot and rejected only when its input fingerprint is missing, stale, or inconsistent.

## Acceptance Of This Design

This design is accepted when the documentation and gate implementation plan preserves all of these constraints:

- Local source completeness is defined against a frozen local snapshot.
- Configuration discovery is complete even when semantic parsing is incomplete.
- Every source input and asset-family member is accounted for.
- Unity validation is representative by homogeneous risk family, not one sample per broad category.
- Corpus completeness and authoring readiness remain independent.
- No root or policy check implicitly launches heavy extraction or Unity.
- No current static evidence is described as proof that StellaSora2 authoring is already ready.
- No result is described as restoration of the original StellaSora Unity project.
