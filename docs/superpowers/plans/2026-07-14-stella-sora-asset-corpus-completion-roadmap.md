# StellaSora Asset Corpus And Reuse Completion Roadmap

> **Status:** Approved sequencing and effort-control roadmap. This document grants no implementation, real-asset access, extraction, import, Unity, Phase B, merge, or worktree-removal authority. Each implementation slice still requires its own reviewed central contracts, 20–30 minute Task, and explicit authorization.

**Current baseline:** `codex/asset-corpus-integration` includes the LC-I07 implementation checkpoint at `54c1d17a727725e28f11fc1b93299ff63bf729e3` and the logical LC-I11 closure recorded below. C0 and C1 Phase A are complete. C2 Phase A intake through SP-09 publication is implemented and its complete fixture-only path has passed completion verification. The C2 Phase B fixture-to-real runbook is written, but Phase B remains unauthorized. C3–C6 responsibilities and input/output contracts are defined, and the prerequisite LC-I06/LC-I07 fixture-only contracts are implemented; C3–C6 implementation, G5 integration, Phase B execution, and C7/G4 Unity have not started.

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

LC-I11 logical-closure checkpoint: the decision registry stores no self-fingerprint; C5/C6 compute CT-04 SHA-256 over its exact accepted bytes. The first-version identity, hard-stop set, replacement rules, seven capability rows, LC-I07 union constraint, decision-to-route mapping, and C5 capability-suitability requirements are exact. BGM and combat-SFX identity requires separate C5 `CapabilitySuitability` evidence and is never inferred from LoopMode, filenames, paths, or generic playback. Physical LC-I11 artifacts and all C3-C6 implementation remain absent.

### R5 — C0 Contract Change And Lightweight G5

Resolve the exact C2/C3–C6 projection gap through one reviewed C0 contract change. Implement G5 as a freshness-validating aggregator only; it must not refresh snapshots, extraction, static gates, or Unity.

### R6 — Phase A Completion Audit

Independently rerun the complete C0–C6 fixture matrix and fixed counterexamples, verify all public/private projections and failure vectors, verify the natural gate entry path, inspect commit scope/worktree state, and confirm no forbidden artifacts. Only a clean Phase A audit may produce a Phase B authorization request.

## 5. Phase B And Real Evidence Sequence

### R7 — Explicit Phase B Authorization Package

The request must identify exact operations, approved local source kinds, external runtime-only manifest, output roots, storage estimate, tool versions/hashes, stop conditions, rollback/quarantine behavior, and expected evidence. It must not embed machine-local source paths in portable artifacts.

Before C1 execution, separately review whether a human-approved immutable first capture may become the baseline after byte revalidation. Until a runbook amendment is approved, the current C1 runbook and its first-capture `Stop` rule remain authoritative.

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

LC-I13 is frozen as a strict typed lane-fact schema with a valid six-carrier fixture, schema-byte fingerprint binding, duplicate subject/kind rejection, and negative carrier coverage. The pure LC-I06 fixture-only producer is implemented against the frozen three-input sub-contract. LC-I07 has one closed logical and physical contract. LC-I11 now has a closed logical contract using an external exact-byte fingerprint and C5 strong typed capability-suitability evidence; no physical LC-I11 artifact exists yet.

The next normal Task is **implement the closed LC-I11 registry, strict JSON Schema, byte-identical positive fixture, focused negative fixtures, and executable contract validator** as a separate fixture-only 20-30 minute checkpoint. LC-I12, the required vocabulary dimensions, authoring reuse ledger v2, any LC-I06 publication integration, C2 Phase B execution, real assets, extraction, Unity, import, C3-C6 implementation, G5, and release work remain unauthorized.
