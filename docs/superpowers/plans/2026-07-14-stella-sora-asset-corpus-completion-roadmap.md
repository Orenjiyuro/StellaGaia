# StellaSora Asset Corpus And Reuse Completion Roadmap

> **Status:** Approved sequencing and effort-control roadmap. This document grants no implementation, real-asset access, extraction, import, Unity, Phase B, merge, or worktree-removal authority. Each implementation slice still requires its own reviewed central contracts, 20–30 minute Task, and explicit authorization.

**Current baseline:** `codex/asset-corpus-integration` includes the LC-I07 and LC-I11 physical contract checkpoints, fixture-only C3-C6 output paths through C6-O04, root summary schema 2.0.0, and the lightweight fixture-only G5 freshness-validating aggregator. C0 and C1 Phase A are complete. C2 Phase A intake through SP-09 publication is implemented and its complete fixture-only path has passed completion verification. The post-R6 C3-C5 exact-byte authority corrections and same-generation fixture-only C2→C6→G5 harness are complete, and a fresh R6 completion audit passes at code baseline `e5effee`. The C2 Phase B fixture-to-real runbook is written, and the separate R7 package now freezes the only currently eligible Phase B request as one diagnostic real C1 snapshot under `PersonalLocalMode`: R8.1 automatically locates and validates a fixed machine-local descriptor and the user confirms once immediately before the one operation. Phase B has not executed. The authoring reuse ledger is upgraded to v2; lifecycle publication and C7/G4 Unity have not started.

## 2026-07-18 Single Character End-to-End Restoration Gate Override

This override has priority over the completed historical Fast Feasibility Spike override and all R8-R13 work. It is the only active route until it reaches its terminal result.

### Normative source, synchronization, and legacy-body rule

- `NormativeSource=docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md`. The CERG override in `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md` is a required mirror for discoverability and is not an independent authority.
- Every CERG revision must modify the normative source first and update the mirror in the same commit. The UTF-8 text from this override heading through the line immediately before `## 2026-07-18 Fast Feasibility Spike Override` must be identical in both files. Any divergence sets `CERGOverrideSynchronized=false`, authorizes no Task or LO, and requires a docs-only correction.
- All text below this override is retained historical context only. Every lower `Status`, `Current`, `Current Stop Checkpoint`, `Immediate Next Checkpoint`, `Authorized`, and `nextAction` statement—including the old FFS and R8-R13 route—is `SupersededHistoricalText` and grants no execution authority while CERG is active.
- An executor must derive the current phase, budgets, authorization, and single next action only from this top override. It must not resume a lower legacy checkpoint even when that text calls itself current or approved.

### Historical Fast Feasibility Spike closure

- The Fast Feasibility Spike is completed history: `ordinaryTaskUsed=3/3`; `spikeLOUsed=2/2`; `Character structural producer evidence=Demonstrated`; `Environment chain=NotDemonstrated`; `Audio producer evidence=Demonstrated`; `Overall=PartiallyFeasible`.
- The spike proved only structural producer evidence for Character and producer evidence for Audio. It did not validate Unity display, material/texture rendering, complete action playback, attack effects, or asset reusability.

### CERG product question and binary terminal result

The only product question is:

> 能否把一个有代表性的 StellaSora 角色作为依赖闭合的 Unity 资产还原，并证明其模型显示正常、骨骼/Avatar正常、完整动作全集正常播放、对应攻击特效正常显示？

CERG has exactly two permitted terminal results:

- `EverythingNormal`: every hard acceptance criterion in this override holds simultaneously.
- `ProjectFailed`: any hard acceptance criterion does not hold, or auditable evidence cannot be produced within the fixed budgets.

`Feasible`, `PartiallyFeasible`, `NotDemonstrated`, and `Blocked` are forbidden as CERG terminal results. If Unity, a required tool, authorization, or input remains unavailable at the budget endpoint, the result is `ProjectFailed`. That conclusion means only that this fixed route did not prove success; it must not be described as proof that the assets are intrinsically or absolutely impossible to restore.

The old FFS, R8.3, R9-R13, complete C2/C3-C7, environment, audio, other characters, and full-corpus governance remain `Suspended`. They may not run in parallel with CERG and are not CERG prerequisites.

### Fixed budgets and only permitted sequence

- `ordinaryTaskBudget=5`; `LOBudget=3`.
- After CERG-T0 completes: `ordinaryTaskUsed=1/5`; `LOUsed=0/3`.
- Docs-only corrections required by total-control audit before CERG-T1 authorization remain part of `CERG-T0` and do not consume another route Task; after this correction the counters remain `ordinaryTaskUsed=1/5`, `LOUsed=0/3`.
- Reaching either budget cap requires an immediate binary terminal result and stop. No unbounded tool rotation, candidate replacement, retry, or governance expansion is permitted.

The only permitted sequence is:

1. `CERG-T0` route reset.
2. `CERG-T1` compare at most three candidates, lock exactly one character, freeze its exact pre-extraction universe, and freeze a closed discovery-obligation list for relationships not visible in authorized historical evidence.
3. Exact human confirmation.
4. `LO-CERG1` candidate-scoped dependency-closure extraction/staging that may resolve only the frozen discovery obligations.
5. `CERG-T2` final exact-universe closure acceptance, visual-measurement contract freeze, and construction of the minimal Unity validation scene/automatic validator.
6. Exact human confirmation.
7. `LO-CERG2` single-thread Unity first import/run/capture.
8. If all hard criteria are green, `CERG-T4` terminal acceptance. If and only if there is one clearly identified, fixed-scope problem repairable in one ordinary Task, run `CERG-T3` as the sole repair, obtain exact human confirmation, run `LO-CERG3` as the sole Unity revalidation, and then run `CERG-T4`.

An unrepairable problem, multiple non-closure problems, or any failure remaining after `LO-CERG3` requires `CERG-T4=ProjectFailed`.

### Candidate lock and exact-universe rules

- `CERG-T1` may compare at most three character families read-only and must select exactly one.
- `char_14401` is the preferred first candidate because Mesh/Avatar/skeleton/clip relationship evidence exists, but no attack effect or complete action-set result may be presumed.
- Before locking, the candidate must yield an exact pre-extraction universe covering every known model/SkinnedMesh, Material/Texture/Shader, skeleton/Avatar, action clip/controller/override, and attack-FX identity plus every unresolved relationship as one finite, identity-bearing discovery obligation. Unknown open-ended scanning is not a discovery obligation.
- Final completeness must come from authoritative controller, override, prefab, event, GUID, serialized object, or equivalent ownership/reference relationships. Filename, same-directory location, a single-clip sample, and subjective similarity are forbidden completeness evidence.
- After lock, the character may not be changed. If none of the at most three candidates has both an exact known universe and a finite candidate-scoped discovery-obligation list, CERG terminates `ProjectFailed` without extraction.
- `LO-CERG1` may fill the frozen obligations but may not broaden the candidate, source boundary, relationship kinds, or selectors. Any newly encountered dependency must be attributable to a frozen authoritative edge and added to the same candidate closure; an unrelated family or open-ended corpus search is forbidden.
- After `LO-CERG1`, `CERG-T2` must freeze the final exact universe with zero unresolved or contradictory rows. Otherwise it must not build the Unity scene or request `LO-CERG2`, and `CERG-T4=ProjectFailed`.
- “All actions” means one closed, countable, identity-bearing complete action list. Unity validation must cover every item. Any unclassified action or unresolved action reference is failure.
- Every attack effect must have an authoritative attack-action-to-FX trigger/reference relationship and must actually trigger during the corresponding Unity action. `NoEffectExpected` is allowed only when an authoritative relationship explicitly proves no effect is expected; otherwise absence is failure.

### CERG-T1 authorized historical evidence and evidence states

`CERG-T1` is read-only. Its complete historical evidence allowlist is:

1. tracked repository plans, contracts, schemas, validators, and source-independent tool metadata;
2. historical C1 ledger/summary identity, count, byte, hash, and portable provenance fields, without copying any machine-private or absolute path into portable artifacts or conversation;
3. historical `LO-FFS1` file-tree identities and exported relationship metadata, including Unity `.meta` GUIDs and serialized prefab/controller/override/Animator/MonoBehaviour/manifest relationships already present in that immutable output;
4. historical FFS result/log fields only for tool identity, attempt identity, exit state, and already-recorded structural observations.

Raw source roots, PB-I03, machine-local manifests/baselines, new producer execution, AssetRipper, decode, Unity, binary interpretation beyond safe identity/enumeration, `LO-FFS2` audio content, and any write to historical output remain forbidden during `CERG-T1`.

Every candidate relationship row must have exactly one state:

- `ProvenPresent`: an authoritative owner/reference record identifies the target and relationship.
- `ProvenAbsent`: an authoritative, exhaustively enumerated owner/reference collection proves that the relationship or effect is not defined. Missing filenames, directories, exports, or observations never establish this state.
- `EvidenceUnavailableBeforeExtraction`: the authorized historical evidence does not expose the relationship, but one finite candidate-scoped selector/owner/relationship query is frozen as a `LO-CERG1` discovery obligation.
- `Contradictory`: authoritative historical records disagree on identity or relationship.

`EvidenceUnavailableBeforeExtraction` means “not visible in current evidence,” never “absent.” It is permitted at the end of `CERG-T1` only when every such row has one exact discovery obligation. `Contradictory` rejects that candidate. `ProvenAbsent` can support `NoEffectExpected` only when its exhaustive authority remains current after `LO-CERG1`; otherwise the final row fails closure.

### CERG-T2 visual-measurement and capture contract

Before requesting `LO-CERG2`, `CERG-T2` must freeze one exact, reviewable validation contract and its repository-relative asset/scene/script/output paths. The contract must assign concrete values—not placeholders—to all of the following:

- Unity/editor identity, render pipeline, color space, quality tier, anti-aliasing, background, lighting transforms/intensities/shadows, ground plane, and deterministic time-step settings;
- camera projection, FOV or orthographic size, near/far planes, target derived from finite combined renderer bounds, distance/framing formula, front/left/right/back rotations, close-up framing, and fixed root transform/canonical pose;
- capture width, height, aspect ratio, pixel format, exact lossless still format, video container/codec or lossless frame sequence, frame rate, action pre/post padding, file naming, ordering, and SHA-256 inventory;
- numeric bounds-occupancy interval, minimum border margin, zero-clipping rule, scale and facing tolerances, root/foot drift tolerances, finite bone/renderer-bounds thresholds, and per-action start/middle/end sample times;
- attack-FX trigger-time tolerance, peak-frame selection rule, allowed FX bounds relative to character bounds, post-action disappearance/retention rule, and material/texture/shader identity assertions.

Every phrase such as “reasonable scale,” “obvious misbinding,” “obvious anomaly,” “misplaced,” or “abnormal scale” must map to at least one frozen numeric or structural assertion and one visible capture. A subjective label alone cannot pass a criterion. Numeric/structural checks are necessary but not sufficient: total control may still reject visible corruption, but it may not accept `EverythingNormal` without the frozen measurements and required captures.

### `EverythingNormal` hard acceptance criteria

#### A. Dependency closure

- Model, every renderer/Mesh/Material/Texture/Shader, skeleton/Avatar, complete action list, controller/override, and attack FX are fully resolved.
- `requiredMissingReferenceCount=0`.

#### B. Unity import/runtime integrity

- Use the Unity project at the repository root; do not create another project copy.
- Zero missing scripts, shaders, materials, textures, or bones.
- Zero import errors, exceptions, NaN/Inf transforms, or animation-binding failures.
- Exact asset, scene, and script paths are frozen only by the later `CERG-T2`; CERG-T0 authorizes none of them.

#### C. Model visible correctness

- Capture at least front, left, right, back, and close-up views.
- The complete character is visible and its scale, orientation, framing, hierarchy, and renderer bounds satisfy the CERG-T2 contract.
- No pink material, full transparency, missing faces, exploded geometry, skeleton collapse, or obvious texture misbinding.

#### D. Complete action correctness

- Every clip/state in the frozen action list plays from start to finish at least once.
- Each item records identity, duration, start/middle/end samples, and valid bones/renderer bounds.
- No freeze, exploded geometry, incorrect Avatar, foot/root tolerance violation, or unbound curve.
- Continuous capture or equivalent per-action evidence is mandatory; a static first frame is insufficient.

#### E. Attack FX correctness

- Every attack action expected to have FX actually triggers it at the corresponding time.
- Renderer/particle/trail/material/texture/shader dependencies are complete.
- Capture before attack, peak FX, and after attack. There must be no pink, invisible, placement/bounds-tolerance violation, abnormal scale under the frozen rule, non-terminating, or missing-texture effect.

#### F. Independent acceptance

- The implementation task produces evidence only and may not relax the meaning of “normal”.
- Total control independently inspects Unity logs, per-action structured results, screenshots, and continuous capture before accepting `EverythingNormal`.
- Any criterion lacking visible or structured evidence requires `ProjectFailed`; producer `exit=0` cannot substitute for correct visible/runtime behavior.

### Authorization boundary

- `CERG-T0` modifies only these roadmaps. It authorizes no real source access, extraction, staging, `Assets/StellaGaia/Imported`, Unity, cache, scene, script, process, or `Extracted` write.
- `CERG-T1` remains read-only and must stop at the exact human confirmation for `LO-CERG1`.
- `LO-CERG1`, `LO-CERG2`, and `LO-CERG3` each require separate exact authorization. Unity is single-threaded, with no background retry or package download.
- Each LO permits one attempt. `LO-CERG3` is the only possible Unity revalidation and requires a total-control-approved single repair cause first.
- Source remains permanently read-only; portable and private paths remain separate; absolute source paths must not enter the repository or conversation.
- On completion of CERG-T0, the only next action is `AwaitTotalControlAuditBeforeCERG-T1`.

## 2026-07-18 Fast Feasibility Spike Override

- `mode=FastFeasibilitySpike`; `ordinaryTaskBudget=3`; `ordinaryTaskUsed=1`; `spikeLOBudget=2`; `spikeLOUsed=0` (reported as `ordinaryTaskUsed=1/3`, `spikeLOUsed=0/2`). The historical C1 snapshot LO belongs to the superseded route, is not counted in this spike, and its quarantined C1-O01/C1-O02 outputs remain immutable diagnostic history.
- The only permitted sequence is `FFS-T1 -> LO-FFS1 (character + environment; shared bundle/AssetRipper route) -> FFS-T2 (read-only acceptance) -> LO-FFS2 (WEM/BNK) -> FFS-T3 (read-only acceptance and forced overall conclusion)`.
- The spike freezes only three vertical samples: (1) character model plus skeleton/avatar/bone hierarchy plus animation clip; (2) environment Mesh plus Material plus Texture and at least one binding chain; (3) WEM decode/playability plus BNK membership/provenance.
- Character is Demonstrated only when the same candidate family exports at least one Mesh or SkinnedMesh, one auditable skeleton/avatar/bone hierarchy, and one AnimationClip whose relationship to that skeleton candidate is proven. A complete controller is not required.
- Environment is Demonstrated only when the same candidate slice exports at least one Mesh, Material, and Texture and proves at least one Mesh-to-Material-to-Texture binding or deterministic rebind. A complete room is not required.
- Audio is Demonstrated only when one WEM decodes into probeable/playable media and its BNK membership/provenance is auditable. Complete Wwise event semantics and Unity playback are not required.
- The forced overall conclusion is exactly one of: `Feasible` for 3/3 Demonstrated; `PartiallyFeasible` for 1-2/3 Demonstrated with no global safety issue invalidating the proven domains; `NotDemonstrated` when both spike LOs complete with 0/3 Demonstrated; or `Blocked` only when an LO cannot safely begin/finish or an input, tool, or authorization boundary cannot be satisfied and therefore execution evidence is insufficient. An ordinary sample failure is not `Blocked`.
- Reaching either total budget cap requires an immediate forced conclusion and stop; no additional Task, LO, tool rotation, or governance expansion is permitted.
- Suspended and not prerequisites for this spike: the old R8.3 baseline route, first-capture correction, complete R9-R13 route, full C2/C3-C7 processing, Unity full-project restoration, import, publication, and merge. This override grants no LO, extraction, decode, Unity, import, publication, or merge authority.

## 1. Program Goal And Definition Of Done

The product program aims to support a local Unity Hades-like prototype using qualified StellaSora source material. This asset-corpus project is the evidence and authoring-pool gate for that product; it does not implement gameplay and does not claim restoration of the original StellaSora Unity project.

The project is complete only when the approved local PC, Android APK, and Android DATA/cache boundary has:

1. a frozen, byte-accounted source corpus ledger;
2. measured structured discovery coverage with opaque and failed inputs retained;
3. canonical object/platform-variant and configuration dispositions where evidence permits;
4. complete static family accounting for every discovered member;
5. representative Unity evidence for every material import-risk variant in an accepted family;
6. an authoring reuse ledger that isolates unchecked and rejected members from the accepted pool;
7. a lightweight G5 result that independently reports `CorpusSnapshotComplete`, `StructuredObjectCoverage`, `OriginalAssetBatchCoverage`, and `StellaSora2AuthoringReady`.

`StellaSora2AuthoringReady=true` additionally requires at least one accepted route for environment/map modules, a player model/skeleton/animation set, an enemy model/skeleton/animation set, combat effects, UI graphics plus a local construction route, BGM, and combat SFX.

## 2. Authority And No-Waste Rules

Authority remains repository `AGENTS.md`, the approved 2026-07-10 corpus/reuse design, current approved component specs, then the current Task plan. Historical June sample-migration plans and superseded C2 plans are evidence/history, not executable authority.

- Reuse existing equivalent evidence after verifying content fingerprints; do not repeat extraction, screenshots, previews, or Unity runs merely to populate a new checklist.
- Contract work must answer a current consumer or safety question. Do not freeze an output package that has no approved consumer.
- One Task is 20–30 minutes; one Step is 2–5 minutes. Every Task finishes GREEN and reversible.
- One implementation agent writes in this worktree at a time, followed by specification review and quality review.
- Real roots, extraction, Unity, controlled staging, Phase B, merge, and worktree deletion remain separate human gates.

## 3. Completed Baseline

| Stage | Result | Status |
|---|---|---|
| Historical toolchain/sample evidence | Tooling, selected candidates, repair experiments, static/manual evidence, and focused Unity gates exist | Preserve and later re-index; do not treat as current G3/G4 automatically |
| C0 Phase A | Public ledgers, vocabulary, root-summary contracts, positive/negative contract tests | Complete |
| C1 Phase A | Deterministic G0 fingerprints, all-file G1 catalog, guarded runner, C2 handoff, Phase B runbook | Complete |
| C2 minimal slice | Two synthetic objects project to the existing public ledger with conservation and safety proof | Complete |
| C2 intake fixture authority | AR-I07, AR-I10, and AR-I11 frozen and reviewed | Complete at `b635059` |

## 4. Remaining Phase A Sequence

### R1 — Complete C2 Intake/Freshness — Complete

Execute the amended intake plan in three separately authorized increments:

1. Task 2A: pure in-memory registry/HI-13/O1/O2 model;
2. Task 2B: audited Git freshness adapter;
3. Task 2C: reviewed fixture integration and complete matrix.

Acceptance: all three commits independently GREEN; no real assets, extraction, Unity, import, or forbidden directory creation.

Completion record: implemented and retained in the verified C2 fixture-only matrix through `6165be7`.

### R2 — Complete C2 Partitions And Projection — Complete Through SP-09

Write and approve one narrow plan before implementation, then execute one Task per slice:

1. SP-01/SP-02 file/container and discovery partitions;
2. SP-03/SP-04 raw observation accounting, object resolution, conflicts, and public ledger projection;
3. SP-05 configuration discovery;
4. SP-06 canonical/variant grouping;
5. SP-07 dispatch;
6. minimal consumer-required C2 outputs and a C2 Phase B runbook.

Do not make the full atomic multi-artifact publisher a prerequisite until at least two approved consumers require the publication transaction. A simpler current-consumer output may be used only if the central registries and failure suppression remain lossless.

Completion record: SP-01 through SP-09, including canonical provenance, dispatch, complete input accounting, deterministic serialization, journaled publication/recovery, and diagnostic publication wiring, are implemented through `6165be7` and pass the complete fixture-only verification matrix. The fixture-to-real runbook was added at `d2b5247`; it is planning evidence only and grants no real-source or Phase B execution authority. This record does not include real assets, extraction, Unity, Phase B, C3–C6 implementation, or G5.

### R3 — Define C3–C6 Before Implementing Them — Complete

Current authority names C3–C6 but does not assign complete ownership, artifact boundaries, or acceptance criteria. This is a blocking roadmap gap, not permission to infer meanings from old scripts.

A docs-only Task must freeze:

- which component owns shared family construction and the authoring reuse ledger;
- how `Audio`, `Environment`, `Actor`, `UI`, and `Effects` dispatch lanes map to C3–C6;
- each lane's subject universe, static partitions, representative-selection inputs, output/failure vector, and G5 projection;
- how existing evidence is fingerprinted, accepted, marked stale, or rejected without repeating equivalent work.

No C3–C6 implementation begins until that definition passes independent review.

Completion record: `2026-07-15-stella-sora-asset-corpus-c3-c6-design.md` freezes the lifecycle spine, strong Audio/Environment/Actor/UI/Effects policies, C3–C6 direct inputs and outputs, conservation partitions, identities/fingerprints, failure vectors, C7/G4 evidence boundary, C6-only G5 handoff, and fixed counterexamples. It also records the exact C0/C2 contract gaps. This docs-only completion does not authorize implementation, Phase B, Unity, extraction, or real assets.

### R4 — C3–C6 Fixture-Only Family Gates

Implement the reviewed component map one small lane/risk-family Task at a time. Each Task must prove full member conservation, fail-closed static qualification, representative selection, and lossless authoring-ledger projection using fixture or already-reviewed evidence only.

Enabling checkpoint: the pure LC-I06 adapter now projects only the five approved structured AR-O04 selector facts, binds the exact AR-O04/AR-O05/LC-I13 bytes, terminally accounts Assigned/RetainedForDiagnosis/ConfigurationOnly subjects, and byte-compares a checked-in schema-valid fixture. Focused five-lane, mutation, determinism, conservation, C2 safety, and minimal-object regressions pass. This does not publish LC-I06, start C3, or authorize Phase B, real assets, extraction, import, or Unity.

LC-I07 implementation checkpoint: the non-self-referential first-version registry now exists with exactly five strongly typed lane policies, a strict JSON Schema, a byte-identical positive fixture, four focused semantic negative fixtures, and executable contract validation. Focused contract, minimal-object, C2 pure, and LC-I06 projection regressions pass. C3 implementation, LC-I06 publication integration, Phase B, real assets, extraction, import, and Unity remain unauthorized.

LC-I11 implementation checkpoint: the non-self-referential first-version registry now exists with a strict JSON Schema, byte-identical positive fixture, five focused semantic negative fixtures, and executable validation. Its exact-byte SHA-256 is `82831d240952746c3207d47e8cd6f8ee22edfcbf2044def0cdb0a2767e3fef4a`; the validator proves the hard-stop/diagnostic-only sets, four replacement rules, seven capabilities, reference closure, route matching, and exact LC-I07 13-tuple union. BGM and combat-SFX identity still requires separate C5 `CapabilitySuitability` evidence and is never inferred from LoopMode, filenames, paths, or generic playback.

C3-0 walking-skeleton checkpoint: `familyParentStatus` is the only newly introduced lifecycle vocabulary dimension and is consumed immediately by a pure family-membership kernel. The fixture-only executable path covers all five assigned lanes plus RetainedForDiagnosis and ConfigurationOnly, proves `7 = 5 + 1 + 1`, forms five disjoint families, preserves one direct parent per dispatch subject, and projects a cross-lane dependency as one reference without duplicate membership. C3 publication and the complete C3-O01/O02/O03/O04 output vector remain a later Task.

C3-1 output-vector checkpoint: the pure gate now emits byte-frozen C3-O01 family registry, C3-O02 member ledger, C3-O03 reference package, and C3-O04 summary/report fixtures. It computes LX-HI-14 input freshness from the exact direct-input entries, conserves member counts and bytes, partitions references as Resolved/Missing/Conflict, and proves Passed `4/4/0` plus LF-02/LF-03/LF-05 diagnostic-only `4/1/3` vectors. It performs no publication and does not authorize C4 automatically.

C4-0 walking-skeleton checkpoint: `memberStaticStatus` is the only newly introduced lifecycle vocabulary dimension and is consumed immediately by a pure member-static kernel. The fixture-only executable path evaluates all 36 LC-I07 checks across the five assigned lanes, proves member and byte partitions `5 = 3 + 1 + 1` and `1500 = 1000 + 200 + 300`, preserves explicit Failed and Unchecked outcomes, requires every Passed check's complete strongly typed evidence-kind set and computed evidence fingerprint, and rejects missing, duplicate, or invalid check rows. It performs no publication and does not emit the complete C4-O01/O02/O03 vector.

C4-1 output-vector checkpoint: the pure gate now emits byte-frozen C4-O01 member static qualification, C4-O02 family static summary, and C4-O03 summary/report fixtures. It computes LX-HI-06/LX-HI-07 identities with exact HI-01 framing, computes LX-HI-14 over the exact twelve-entry direct-input set, proves Passed `3/3/0` plus LF-09 diagnostic-only `3/1/2`, and preserves LF-07/LF-08 as valid rows rather than gate failures. It performs no publication and does not authorize C5 automatically.

C5-0 walking-skeleton checkpoint: `representativeAssessment` and `capabilitySuitabilityStatus` are the only newly introduced lifecycle vocabulary dimensions and are consumed immediately by a pure no-executor kernel. The fixture path derives 21 risk requirements with `9 RepresentativeRequired + 12 EvidenceMissing` and 11 suitability requirements with `3 SuitabilityRequired + 8 SuitabilityMissing`; exact matching Unavailable packages move only their own subjects to the corresponding unavailable state. LC-I07/LC-I11 fingerprints are computed over external exact bytes, all IDs use HI-01 framing, and four Audio capability/route requirements prove that BGM and combat-SFX suitability remain independent of LoopMode. Completed packages fail closed in this slice; no EvidenceAccepted or Unity execution is projected.

C5-1 immutable-evidence checkpoint: the pure kernel now verifies framed LX-HI-10 package identity and observation shape, accepts only exact-fresh Completed packages with every required Passed evidence kind, and maps stale, rejected, and inconclusive fixtures to their exact risk and capability-suitability states. Focused fixtures prove `Accepted/Stale/Rejected = 1/1/1` independently for SP-50 and SP-51, retain Inconclusive as Missing, fail closed on unknown requirement or wrong suitability evidence kind, and prevent one BGM capability/route package from satisfying CombatSfx or another route. No C7/G4 executor, Unity, publication, or real asset is invoked.

C5-2 output-vector checkpoint: the fixture-only gate now emits byte-frozen C5-O01 requirements, C5-O02 assessments, C5-O03 instruction-only C7 requests, and the C5-O04 summary/report bundle. The no-package generation proves 21 SP-50 subjects, 11 SP-51 subjects, 20 exact missing-evidence requests, Passed `4/4/0`, and LF-15 diagnostic-only `4/1/3`; all direct inputs and hashes use explicit Ordinal framing. C5-O03 remains planning data and neither launches nor authorizes C7/G4.

C5 evidence-authority correction checkpoint: optional LC-I09 now binds the exact no-evidence C5 requirement-generation fingerprint, and every listed LC-I10 package is accepted only through matching parsed object/exact bytes, manifest path/SHA/packageId/requirementId closure, and a matching LC-I10 direct-input row. Manifest/package absence, extras, mismatches, and object/bytes divergence fail as LF-15; LC-I09 and every listed LC-I10 participate in the current C5 LX-HI-14, so an evidence-generation byte change refreshes C5 without launching C7/G4.

C3-C6 independent completion-audit checkpoint: the corrected C2 AR-I05 authority, C0/C1 compatibility, complete seventeen-case C2 matrix, and all natural C3-C6 entry points pass together. The audit verifies the currently applicable fixed counterexamples, stage conservation and failure vectors, exact-byte/Ordinal rules, unchanged fixture trees, absent registered publication outputs, and zero executor/heavy/publication activity. G5 direct-read enforcement and lifecycle stale-publication consumption remain explicitly deferred to R5 and a separately authorized publication Task.

### R5 — Remaining Root Contract Change And Lightweight G5

The authoring reuse ledger v2 contract change is complete in C6-1. Resolve only the remaining root-summary/G5 projection gap through one reviewed C0 contract change. Implement G5 as a freshness-validating aggregator only; it must not refresh snapshots, extraction, static gates, or Unity.

Root-contract checkpoint: root summary schema 2.0.0 now preserves the complete C2 structured coverage/identity/failure-accounting projection and losslessly carries the C6-O04 family construction, original-asset coverage, and capability-readiness conclusions. Its fixture binds the exact C6-O04 bytes, the former AR-S12 request is Resolved, and the C2 AR-I06/P0/D9 authority is synchronized.

Lightweight G5 checkpoint: the fixture-only aggregator consumes exact C1 summary, Passed C2 summary, Passed C6-O04, and root-schema bytes; validates shape, shared snapshot, freshness, conservation, and lossless projection; rejects direct C3-C5 reads; and emits the schema-valid root summary in memory without refresh, executor launch, publication write, Unity, extraction, import, or real assets. The next normal Task is R6, the independent C0-C6 Phase A completion audit.

### R6 — Phase A Completion Audit

Independently rerun the complete C0–C6 fixture matrix and fixed counterexamples, verify all public/private projections and failure vectors, verify the natural gate entry path, inspect commit scope/worktree state, and confirm no forbidden artifacts. Only a clean Phase A audit may produce a Phase B authorization request.

R6 completion checkpoint: the C0 contract matrix, complete C1 fixture/snapshot/catalog/runner/compatibility paths, minimal object gate, all seventeen C2 cases, every natural C3-C6 entry point, and G5 pass together at `319a7a3`. The two C2 integration cases intentionally prove the current FT-05 diagnostic generation and return successful harness exits. Fixture-tree digests, registered-output absence, protected-file hashes, and publication/temp state are identical before and after the audit. The audited `6165be7..319a7a3` range contains no `Extracted/**`, imported assets, Unity caches, or binary asset additions. This completion is fixture-only and authorizes only preparation of the separate R7 Phase B authorization package; it does not authorize Phase B execution, local source access, extraction, import, Unity, C7/G4, lifecycle publication, or release work.

Post-audit correction status: the R6 result above remains useful component evidence but is no longer sufficient Phase B readiness evidence. Independent review found that C3-C5 base execution objects were not all bound to their registered exact bytes and that the matrix did not prove one same-generation C2→G5 chain. The C3, C4, and C5 authority corrections are complete with LF-01 fail-closed counterexamples and regenerated downstream freshness fixtures. The same-generation harness now uses current C2 serialized bytes, current LC-I06 projection, current C3-C6 outputs, and the actual registered C2 summary path at G5; its valid zero-family generation also proves empty-universe conservation without fabricating static checks, evidence, families, or readiness. R6 remains BLOCKED only until this corrected chain and the full component matrix pass one fresh independent completion audit.

Fresh R6 re-audit checkpoint: at code baseline `e5effee`, the C0 contract matrix, complete C1 gate/snapshot/catalog/runner/compatibility paths, minimal object gate, all seventeen C2 cases, C3 family membership, C4 static qualification, C5 requirement/evidence, C6 child conservation/decision/output, G5, and the same-generation C2→C6→G5 harness pass together. The C2 Integration and FileFixtureIntake cases intentionally retain their fixture diagnostic `Failed` generation while their test harnesses prove the expected accounting and exit successfully. Before/after fixture-tree digest `d0df512d4c3bfb8aab7e43b01886e259d73350823fe4cbc5b34ae7b8c3ad04e3`, protected-file hashes, registered-output absence, and publication/temp state are identical. The audited `6165be7..e5effee` range contains no forbidden paths or binary additions. R6 is therefore complete again; this authorizes only the next separate R7 authorization-package Task and does not authorize Phase B execution, local source access, real assets, extraction, import, Unity, C7/G4, lifecycle publication, or release work.

## 5. Phase B And Real Evidence Sequence

### R7 — Explicit Phase B Authorization Package

The request must identify exact operations, approved local source kinds, external runtime-only manifest, output roots, storage estimate, tool versions/hashes, stop conditions, rollback/quarantine behavior, and expected evidence. It must not embed machine-local source paths in portable artifacts.

Before C1 execution, separately review whether a human-approved immutable first capture may become the baseline after byte revalidation. Until a runbook amendment is approved, the current C1 runbook and its first-capture `Stop` rule remain authoritative.

Preparation record: `docs/asset-migration/source-corpus-phase-b-authorization-package.md` freezes the target user and path, central Artifact/Subject/Failure registries, exact C1 command/output boundary, current tool and contract hashes, the fixed LocalAppData locator and declared source-boundary contract, source-kind vocabulary, disk-budget formula, rollback/quarantine behavior, sensitive-path policy, acceptance evidence, and one-confirmation boundary. It grants no execution authority. Real C2 remains blocked by its absent reviewed adapter, producer set, and real publication-root contract. R8.1 must first derive a GREEN redacted state; only then may one `ConfirmPersonalLocalRun` apply to one immediate operation.

### R8 — Real C1 Snapshot

Run only the guarded C1 Phase B command after exact confirmation. Validate the generated ledger/summary, conservation, source fingerprints, output boundary, and baseline decision. A C1 success does not automatically start C2.

### R9 — Real C2 Discovery

Run approved extraction/observation tools without Unity. Record every tool observation, opaque/failed input, configuration candidate, canonical/variant decision, and structured coverage result under `Extracted`. Publish no downstream-valid output on a failed gate.

### R10 — G3 Full Static Family Qualification

Re-index current player, enemy, effect, environment, UI, and audio evidence first. Acquire new evidence only for missing, stale, contradictory, or newly discovered members. Account for every family member as passed, failed, unchecked, repair, replacement, retained, diagnostic, or stopped according to the approved contracts.

### R11 — Controlled Staging And RepairOnce

Stage only explicit family whitelists. Every repair requires a concrete failure attribution and measurable expected change. One focused repair without improvement moves the family to `PrototypeReplacement` or `Stop`.

### R12 — C7/G4 Representative Unity, Single-Threaded

Resolve the Unity license/environment blocker before scheduling runs. Validate representatives that cover every material import-risk variant, including visible environment/material fidelity, actor animation, effects, UI construction, and audio playback/listening. Static, preview, and compile evidence cannot substitute for Unity-visible or audible proof.

### R13 — Final G5 And Delivery

Rerun G5 against current fingerprints and both ledgers. Report the four root conclusions independently. `StellaSora2AuthoringReady` may pass only when every required capability has an accepted route and all unchecked/rejected members are isolated.

After final independent review: merge the implementation branch through normal Git, verify the shared repository and worktree are clean, then remove the implementation worktree and finally remove its empty parent directory. Never delete the worktree merely because Phase A finished.

## 6. Effort Allocation Guard

Use the following target across remaining work; it is an allocation guard, not a time estimate:

| Work | Target share |
|---|---:|
| Contract, safety, and freshness | 20% |
| Real snapshot, extraction, and discovery | 25% |
| Static family qualification and focused repair | 30% |
| Unity representative validation and controlled import | 20% |
| G5, documentation, merge, and cleanup | 5% |

At every three completed Phase A Tasks, the control thread must check the cumulative mix. If contract/docs/test work still exceeds 50% of the remaining program without resolving a named blocker or enabling a consumer, stop and rescope before adding another contract layer.

## 7. Mandatory Task Template

Every future implementation Task must state:

- target user/consumer and the decision enabled;
- exact files created/modified/read-only;
- referenced Artifact Registry, Subject/Partition rows, and Failure Transitions;
- 20–30 minute duration with 2–5 minute Steps;
- RED cause and same-Task GREEN condition;
- focused command, necessary regression, protected-input check, forbidden-path check, and exact staging list;
- stop checkpoint and whether the next action is correction, normal next Task, special authorization, Phase B, or Unity.

Plans and historical checklists do not grant execution authority.

## 8. Immediate Next Checkpoint

LC-I13 is frozen as a strict typed lane-fact schema with a valid six-carrier fixture, schema-byte fingerprint binding, duplicate subject/kind rejection, and negative carrier coverage. LC-I07 and LC-I11 each have closed logical and physical contracts. C3-0/C3-1, C4-0/C4-1, and C5-0/C5-1/C5-2 supplied their initial fixture-only paths, but independent review blocked C6 entry and identified prerequisite contract gaps.

C3-2, the policy/evidence exact-byte and Ordinal corrections, the C5 LC-I09/LC-I10 authority/freshness correction, C4 typed decision-input projection, C6 child conservation, C6-0 decision evaluation, C6-1 output generation, the independent C3-C6 fixture-only completion audit, the R5 root-summary 2.0.0 contract change, the R5 lightweight G5 aggregator, the same-generation fixture-only C2→C6→G5 harness, the corrected fresh R6 Phase A completion audit, and R7 authorization-package preparation are completed checkpoints. The current Phase B model is `PersonalLocalMode`: R8.1 automatically locates PB-I03 beneath LocalAppData and derives HEAD/tool hashes, locator/manifest shape, exact declared-boundary/source-set equality, baseline state, fixed output boundary, disk budget, and safety state. No PB-A form or external compliance identity is required. After a GREEN R8.1 result, the local user supplies exactly one `ConfirmPersonalLocalRun` before one cancellable diagnostic C1 attempt. Until that point, R8 execution, C2, real extraction, Unity, import, C7/G4, lifecycle publication, and release remain unauthorized.
