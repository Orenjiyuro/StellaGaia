# StellaSora Phase B R7-R13 Program Roadmap

> **Status:** PROGRAM ROADMAP ONLY; NOT A DIRECTLY EXECUTABLE PLAN. Every Work Package below remains blocked until a separate child Task plan satisfies the Mandatory Task Template and receives the required authorization.
>
> **Authority boundary:** C1 uses `PersonalLocalMode`: no PB-A form or external compliance identity. R8.1 automatically locates PB-I03 at the fixed LocalAppData-relative path, proves its declared boundary equals the manifest source set, derives all remaining preflight state, and the user confirms once with `ConfirmPersonalLocalRun` immediately before the LO. This Roadmap itself does not read a real locator/manifest/source root, start a heavy operation, or permit C1/C2/extraction/staging/Unity/import/G5/merge/cleanup.
>
> **Execution cadence:** one separately written child Task per turn, 20-30 minutes maximum. Each child Task Step is one 2-5 minute action. A command that cannot safely finish inside one child Task is a Special Long-Running Operation, not an ordinary Task, and requires the separate gate defined below.

## 2026-07-18 Single Character End-to-End Restoration Gate Override

This override has priority over the completed historical Fast Feasibility Spike override and all R8-R13 work. It is the only active route until it reaches its terminal result.

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
- Reaching either budget cap requires an immediate binary terminal result and stop. No unbounded tool rotation, candidate replacement, retry, or governance expansion is permitted.

The only permitted sequence is:

1. `CERG-T0` route reset.
2. `CERG-T1` compare at most three candidates, lock exactly one character, and freeze its complete dependency/action/attack-FX universe.
3. Exact human confirmation.
4. `LO-CERG1` single-character dependency-closure extraction/staging.
5. `CERG-T2` static closure acceptance and construction of the minimal Unity validation scene/automatic validator.
6. Exact human confirmation.
7. `LO-CERG2` single-thread Unity first import/run/capture.
8. If all hard criteria are green, `CERG-T4` terminal acceptance. If and only if there is one clearly identified, fixed-scope problem repairable in one ordinary Task, run `CERG-T3` as the sole repair, obtain exact human confirmation, run `LO-CERG3` as the sole Unity revalidation, and then run `CERG-T4`.

An unrepairable problem, multiple non-closure problems, or any failure remaining after `LO-CERG3` requires `CERG-T4=ProjectFailed`.

### Candidate lock and exact-universe rules

- `CERG-T1` may compare at most three character families read-only and must select exactly one.
- `char_14401` is the preferred first candidate because Mesh/Avatar/skeleton/clip relationship evidence exists, but no attack effect or complete action-set result may be presumed.
- Before locking, the candidate must yield an exact universe covering model/SkinnedMesh, every required Material/Texture/Shader, skeleton/Avatar, the complete action clip/controller/override relationships, and every attack action's FX prefab/material/texture/shader/animation dependencies.
- Completeness must come from authoritative controller, override, prefab, event, GUID, or equivalent reference relationships. Filename, same-directory location, a single-clip sample, and subjective similarity are forbidden completeness evidence.
- After lock, the character may not be changed. If none of the at most three candidates can produce a frozen complete universe, CERG terminates `ProjectFailed` without extraction.
- “All actions” means one closed, countable, identity-bearing complete action list. Unity validation must cover every item. Any unclassified action or unresolved action reference is failure.
- Every attack effect must have an authoritative attack-action-to-FX trigger/reference relationship and must actually trigger during the corresponding Unity action. `NoEffectExpected` is allowed only when an authoritative relationship explicitly proves no effect is expected; otherwise absence is failure.

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
- The complete character is visible with reasonable scale, orientation, and hierarchy.
- No pink material, full transparency, missing faces, exploded geometry, skeleton collapse, or obvious texture misbinding.

#### D. Complete action correctness

- Every clip/state in the frozen action list plays from start to finish at least once.
- Each item records identity, duration, start/middle/end samples, and valid bones/renderer bounds.
- No freeze, exploded geometry, incorrect Avatar, obvious foot/root anomaly, or unbound curve.
- Continuous capture or equivalent per-action evidence is mandatory; a static first frame is insufficient.

#### E. Attack FX correctness

- Every attack action expected to have FX actually triggers it at the corresponding time.
- Renderer/particle/trail/material/texture/shader dependencies are complete.
- Capture before attack, peak FX, and after attack. There must be no pink, invisible, obviously misplaced, abnormally scaled, non-terminating, or missing-texture effect.

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

## 1. Goal And Product Path

- **Target user:** the human operator who owns the local StellaSora inputs, tool installations, storage, Unity license, evidence review, and final integration decision.
- **Scenario:** produce a frozen local source snapshot; review and, when required, match its baseline; discover and statically qualify all approved families; stage only explicit candidates; permit one focused repair attempt per family/failure class; run representative Unity validation one subject at a time; aggregate four independent G5 conclusions; then merge and clean up only after separate approval.
- **Entry:** branch `codex/asset-corpus-integration`, committed PersonalLocalMode package/runbook/plans, and no Phase B outputs. R8.1 derives the exact current HEAD/tool/locator/boundary/manifest/baseline/output/disk state from the fixed descriptor; the user does not transcribe it. Later stages retain their own stage-specific gates.
- **Completion path:** R7 PersonalLocalMode contract closure -> R8.1 automatic preflight -> one `ConfirmPersonalLocalRun` -> one C1 snapshot -> human first-capture baseline review -> Stop; any future matching capture requires a new independent PersonalLocalMode continuation package and is outside the current authorization -> separate R9 authorization only after C1 baseline closure -> R10 static family qualification -> R11 controlled staging and RepairOnce -> R12 single-thread Unity -> R13 in-memory G5 and final handoff -> separately authorized integration/cleanup program.
- **Success state:** the frozen input universe is conserved; every family/member has a current typed state and evidence route; the four G5 conclusions remain independent; source roots are unchanged; sensitive machine data stays local; no stage is inferred from an upstream pass; the roadmap ends with an auditable handoff to a separate integration/cleanup authorization stage.

This workflow does not claim restoration of the original StellaSora Unity project and does not grant redistribution rights for source-derived assets.

## 2. Approach Choice

### Option A - Sequential evidence gates with independent heavy-operation approvals - Recommended

Use existing Phase A registries, gates, runners, fixtures, and evidence where current. Add only the missing real adapters, producer/publication contracts, lifecycle boundaries, and evidence producers. Stop after every real run for human review.

- Benefits: preserves provenance, failure ownership, source safety, and the user's exact control over every heavy action.
- Costs: more explicit review points and no automatic R8-to-R13 continuation.

### Option B - One broad Phase B authorization

Authorize snapshot, discovery, extraction, staging, Unity, and import together.

- Benefit: fewer operator prompts.
- Rejected because: it defeats the PersonalLocalMode one-confirmation/one-attempt boundary, the C2 diagnostic-only first-run rule, C5/C7 separation, RepairOnce limits, and the required merge/cleanup hard gates.

### Option C - Bulk extraction/import first

Generate a broad export, then classify what was produced.

- Benefit: superficially fast access to files.
- Rejected because: it loses all-file conservation, creates uncontrolled storage and licensing risk, and bypasses static family qualification and representative acceptance.

No child implementation Task begins until the user confirms Option A or supplies a reviewed replacement.

## 3. Authority And Existing Contracts

Read these completely at the start of the relevant child Task; do not silently replace them with this roadmap:

- `AGENTS.md`
- `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`
- `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`
- `docs/superpowers/specs/2026-07-15-stella-sora-asset-corpus-c3-c6-design.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/c2-discovery-phase-b-runbook.md`
- `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md`
- `docs/superpowers/specs/2026-06-02-unity-asset-migration-design.md`
- `docs/adr/0001-unity-first-sample-gated-asset-migration.md`

The central definitions remain authoritative:

- C1 artifacts and authorization: PB-I01 through PB-I03, C1-I01 through C1-I06, C1-O01/C1-O02, C1-E01; PB-SP01 through PB-SP06; PB-FT01 through PB-FT12.
- C2 discovery: AR-I01 through AR-I11, AR-P01, AR-O01 through AR-O05; SP-01 through SP-09; FT-01 through FT-15.
- C3-C6 lifecycle: LC-I01 through LC-I14; C3-O01 through C3-O04, C4-O01 through C4-O03, C5-O01 through C5-O04, C6-O01 through C6-O05; SP-30/SP-31/SP-40/SP-50/SP-51/SP-60/SP-61; LF-01 through LF-21.
- G5 consumes only a valid same-generation C6-O04 handoff and reports `CorpusSnapshotComplete`, `StructuredObjectCoverage`, `OriginalAssetBatchCoverage`, and `StellaSora2AuthoringReady` independently.

If a real operation cannot be expressed by these rows, the owning Work Package first produces a contract-change child Task and stops for review. Operational scripts may not invent a second artifact, partition, failure, or decision model.

## 4. Global Hard Gates

### 4.1 Protected repository state

These untracked files are protected and must remain byte-identical unless the user personally supplies a new instruction that explicitly supersedes this protection:

- `AGENTS.md`, SHA-256 `397D256DA9E5C126667BC39B427AFF31BE7DBBDB1E83F1A90AD6F7AB8C34FD6D`.
- `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md`, SHA-256 `11ED3A2D7D933087D564E388991C45E5887600682DBC4ED9446E6117D4A5247B`.

The current C1 runbook's clean-worktree requirement conflicts with the requirement to retain these two untracked paths. R8 is blocked until one exact, reviewed disposition is approved:

1. amend the runbook/package to permit exactly these two paths with the frozen hashes and no other change; or
2. the user, not the implementation agent, moves or otherwise dispositions them outside the worktree and supplies clean-state evidence.

They are never an implicit dirty-state waiver.

### 4.2 Forbidden operations before their stage

- Before R8 authorization: no real manifest/root read and no source enumeration.
- Before R9 authorization: no observation producer, extraction, decode, AssetRipper, or real C2 publication.
- Before R11 authorization: no controlled staging or write beneath `Assets/StellaGaia/Imported`.
- Before R12 authorization: no Unity process, project import, or Unity cache creation.
- Before R13 integration authorization: no merge, tag, release, publication, branch deletion, or worktree removal.
- At every stage: no source-root write, network/runtime capture, credential exposure, arbitrary callback, unregistered child process, or automatic retry.

### 4.3 Sensitive and machine-local boundary

Absolute source/manifest/tool paths, user/host/account identifiers, local locks/journals/staging roots, unrestricted stdout/stderr, and approval records containing them remain machine-local. Portable evidence may contain only registered source IDs/kinds, portable relative paths, counts, bytes, hashes, tool identities/versions, dispositions, failure attribution, and next actions.

### 4.4 Special Long-Running Operation Gate

An atomic source scan, producer run, extraction, decode, publication, or Unity invocation that may exceed 20 minutes is an `LO`, not a normal child Task. Before each LO, its owning stage authorization must freeze:

1. one operation/subject identity and one attempt only;
2. exact executable/script bytes, version, SHA-256, arguments, working directory, and allowed child processes;
3. immutable input identities and approved read/write roots;
4. positive integer maximum duration and operator-controlled foreground cancellation;
5. positive integer output/storage budget and required free-space formula;
6. progress evidence or a 20-minute operator checkpoint without starting a second process;
7. stop, partial-output, rollback, quarantine, retention, and no-retry behavior;
8. expected portable/private/diagnostic outputs and leak policy.

For LO R8.C1-1, the owning authorization is the displayed current R8.1 GREEN state plus one exact `ConfirmPersonalLocalRun`; no external identity/form is created. Later stages use their separate packages. If an operation cannot expose bounded progress or safe cancellation, first implement a reviewed resumable/chunked runner contract in an ordinary child Task. The agent may report at 20-minute checkpoints but may not broaden the authorization or start a concurrent replacement process.

### 4.5 Universal stop conditions

Stop on changed HEAD/input/tool bytes, unapproved path/process/network activity, missing registry row, invalid/stale evidence, conservation failure, sensitive leak, reparse point, collision, pre-existing unknown output, insufficient storage, partial publication, rollback/quarantine ambiguity, source mutation, or any need to weaken an expected result after seeing actual data.

### 4.6 Mandatory child Task plan gate

Every numbered item below is a non-executable Work Package. Before any non-bootstrap repository write, real-input read, execution command, LO, merge, or cleanup, create one child Task plan that satisfies `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md` section 7 and includes all of:

1. target user/consumer and the one decision enabled;
2. exact files created, modified, and read-only;
3. exact Artifact Registry, Subject/Partition, and Failure Transition references;
4. 20-30 minute duration and complete 2-5 minute Steps;
5. RED cause and same-Task GREEN condition;
6. focused command, necessary regression, protected-input check, forbidden-path check, and exact staging list;
7. exact stage/commit/push list when Git changes are authorized;
8. stop checkpoint and one classified next action.

#### P0 docs-only bootstrap exception

Creating or revising the child Task plan that will govern a Work Package is the only bootstrap exception to the requirement for a pre-existing child plan. It is permitted only when the user explicitly authorizes one exact plan path and docs-only purpose, and all of these conditions hold:

1. the exact file scope is one named child Task plan; a separately named Roadmap-governance correction may use the same one-file rule when the user explicitly requests that correction;
2. repository authority docs and named implementation paths may be inspected read-only to write the plan; no package, runbook, tool, schema, fixture, code, source, manifest, machine-local evidence, or generated output is changed, and no real manifest/source/evidence content is opened;
3. no stage operation, test with heavy side effects, real-input command, LO, Unity, extraction, import, publication, merge, or cleanup runs;
4. the new plan itself satisfies the Mandatory Task Template before it is accepted;
5. protected hashes, forbidden paths, `git diff --check`, exact staging list, commit/parent, and upstream equality are verified;
6. only the named plan file is staged, committed, and pushed, then the bootstrap action stops.

P0 authorizes preparation of governance, not execution of the Work Package described by the plan. Any package/runbook/code change described by that plan still requires the plan's own authorization.

### 4.7 Stage-specific execution lifecycle and HEAD binding

Each real or state-changing stage has its own execution HEAD and frozen-byte set. R8 C1 uses PersonalLocalMode; later stages use the stage-specific approval named by their contracts. The lifecycle is:

1. **Prepared:** child plan and all relevant contract/tool/schema bytes are committed and pushed.
2. **Ready:** R8.1 derives a GREEN state; for other stages, the stage-specific approval binds the exact state.
3. **Confirmed/Started:** R8 accepts one `ConfirmPersonalLocalRun` only after GREEN and revalidates immediately before the one foreground attempt. Any mismatch returns to preflight without starting.
4. **Running:** a relevant HEAD/input/tool mutation during the operation invalidates the run and Stops under the owning failure transition.
5. **Closed:** after the operation ends and post-run identity/evidence checks pass, the consumed confirmation/result becomes immutable historical evidence for that completed operation.

Later docs-only child plans or later-stage commits do not retroactively invalidate a Closed result. They change the candidate state for the next operation. PB-I01 is the automatically derived R8.1 state, not an external identity record. R9 through R13 retain their named stage-specific packages/approvals. A Work Package description is never execution authority by itself.

## 5. Program Checkpoints

Every child Task reports:

- start/end HEAD and branch;
- exact files read and changed;
- registry rows evaluated;
- command/process identities, or `none`;
- conservation and failure vector;
- created/retained/quarantined paths;
- protected-file hashes and forbidden-path state;
- `Stop`, `Review`, or the single next authorization request.

Passing one checkpoint never authorizes the next stage.

---

## 6. R7 - Exact Phase B Authorization Closure

### Work Package R7.1 - Initial package and repository preflight

**Target child Task duration:** 20-25 minutes.
**Files:** read-only `docs/asset-migration/source-corpus-phase-b-authorization-package.md`, `docs/asset-migration/source-corpus-phase-b-runbook.md`, current tool/schema paths registered as C1-I03 through C1-I06; no files changed.
**Acceptance:** package commit, branch/upstream, frozen hashes, versions, protected hashes, and absent forbidden paths agree; no source or manifest read occurs.
**Evidence:** `git status --short --branch`, `git rev-parse HEAD`, `git rev-parse @{upstream}`, version output, exact file hashes, path-absence checks.

Steps:

1. Recheck branch, HEAD/upstream, and protected hashes - 3 minutes.
2. Recompute C1-I03 through C1-I06 hashes and tool versions - 4 minutes.
3. Recheck the package's registry/partition/failure conservation - 5 minutes.
4. Verify no output or forbidden path exists - 3 minutes.
5. Cross-check package/runbook bytes and PersonalLocalMode state - 4 minutes.
6. Record exact mismatches or readiness and stop - 3 minutes.

### Work Package R7.2 - Resolve the protected-untracked/clean-run conflict and LO contract

**Target child Task duration:** 20-30 minutes.
**Files if amendment is selected:** only `docs/asset-migration/source-corpus-phase-b-runbook.md` and `docs/asset-migration/source-corpus-phase-b-authorization-package.md`; protected files remain unchanged. If user-managed disposition is selected, repository files are unchanged.
**Acceptance:** the chosen disposition is explicit, preserves or externally dispositions the protected pair, permits no third dirty path, and freezes the LO rules for R8.
**Verification:** `git diff --check`, exact hashes/status, and package/runbook cross-reference review.

Steps:

1. Present the two dispositions and their consequences - 3 minutes.
2. Receive exact user choice; otherwise Stop - 2 minutes.
3. Apply only the selected docs amendment or verify user-managed evidence - 5 minutes.
4. Validate the LO duration/budget/cancellation/retention contract - 5 minutes.
5. Mark any earlier derived preflight state stale if a relevant byte changed - 3 minutes.
6. Stop before approval or execution - 2 minutes.

### Work Package R7.3 - Create the executable R8 child Task plan and commit all pre-approval bytes

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`; include only the R7.2 package/runbook changes when that disposition was selected; protected files remain unstaged.
**Acceptance:** the R8 child plan satisfies the Mandatory Task Template, includes automatic derivation and the exact one-confirmation LO boundary, and the file set is committed/pushed before R7.4.
**Verification:** child-plan template audit, `git diff --cached --check`, exact cached name list, commit/parent, upstream equality, protected hashes, and forbidden-path absence.

Steps:

1. Write the one-operation R8 child Task plan from frozen contracts - 5 minutes.
2. Audit exact files, registries, RED/GREEN, Steps, commands, staging, and stop - 5 minutes.
3. Run protected-input and forbidden-path checks - 3 minutes.
4. Stage only the enumerated docs files and run cached diff check - 3 minutes.
5. Commit and push the docs-only pre-approval state - 4 minutes.
6. Record the new HEAD and stop - 2 minutes.

### Work Package R7.4 - Post-change revalidation of the exact execution HEAD

**Target child Task duration:** 20-25 minutes.
**Files:** all package/runbook/child-plan/tool/schema bytes read-only; no files changed.
**Acceptance:** reruns every R7.1 check against the new pushed HEAD, proves the R8 child plan is present, and validates PersonalLocalMode Registry/Partition/Failure conservation without reading real inputs.
**Evidence:** branch/HEAD/upstream, all frozen hashes, package conservation, protected hashes, forbidden paths, and zero source/process activity.

Steps:

1. Recheck branch, HEAD/upstream, and exact commit tree - 3 minutes.
2. Recompute every package/tool/schema/child-plan hash - 5 minutes.
3. Revalidate registry/partition/failure and command identities - 5 minutes.
4. Recheck protected and forbidden-path state - 3 minutes.
5. Confirm no stale derived state is carried across changed bytes - 3 minutes.
6. Emit `ReadyForPersonalLocalModeValidation` or Stop - 2 minutes.

### Work Package R7.5 - Validate PersonalLocalMode migration

**Target child Task duration:** 20-30 minutes.
**Files:** package/runbook/Roadmaps/R7.4/R7.5/R8.1, PB-I03 locator schema, and PersonalLocalMode policy test read-only; no runtime record or real input.
**Acceptance:** no human form/external compliance fields remain; PB-I01 is derived state; PB-I03 and PB-SP02/PB-SP06 close input location and boundary equality; `PB-SP01: 6 = 0 Passed + 6 Failed` before R8.1 evaluation; all safety invariants and one-confirmation boundary are conserved.
**Evidence:** focused policy-test result, hashes/status, zero-source/process/output declaration.

Steps:

1. Bind current HEAD and active governance bytes - 3 minutes.
2. Prove PB form/external identity removal - 4 minutes.
3. Validate PB-I01/PB-I03 derived-state and locator shapes plus PB-SP01 conservation - 5 minutes.
4. Validate automatic HEAD/tool/locator/boundary/manifest/baseline/output/disk responsibilities - 4 minutes.
5. Validate source-read-only, one-run, cancellation, no-retry, and downstream denials - 4 minutes.
6. Run the focused policy test and emit `ReadyForR8.1AutomaticPreflight` or Stop - 3 minutes.

**R8 state invalidation rule:** any relevant change before LO start makes PB-I01 and `ConfirmPersonalLocalRun` stale. Rerun R8.1; never ask the user to repair a form. Mutation during the operation invalidates the run. After R8.2 closes it, later plans do not retroactively erase the result.

**R7 checkpoint:** proceed only to R8.1 automatic preflight. No human confirmation is requested during R7.5.

---

## 7. R8 - Real C1 Snapshot And Baseline Review

### Work Package R8.1 - Exact preflight for one C1 operation

**Target child Task duration:** 20-30 minutes.
**Files:** repository read-only plus automatically located PB-I03, local C1-I01/C1-I02 shape/identity, and filesystem metadata; no prompt, arbitrary machine search, source-file content read, or hidden/background scan.
**Acceptance:** automatically derive and pass all six PB-SP01 groups; emit `ReadyForSinglePersonalLocalRun`; exact guarded command remains unrun.
**Evidence:** redacted derived-state summary and zero-heavy-process/output declaration.

Steps:

1. Revalidate repository and protected state - 3 minutes.
2. Derive HEAD, versions, tool/schema/policy hashes, and seven lightweight gates - 4 minutes.
3. Locate/validate PB-I03 and prove PB-SP02/PB-SP06 boundary/manifest equality - 5 minutes.
4. Derive baseline, fixed output boundary, and disk-space state - 4 minutes.
5. Derive source-read-only/one-attempt/cancellation/no-retry/downstream flags - 4 minutes.
6. Produce `ReadyForSinglePersonalLocalRun` or Stop - 3 minutes.

### LO R8.C1-1 - One guarded C1 snapshot attempt

**Not an ordinary child Task.** After R8.1 GREEN, display the redacted state and require exactly one `ConfirmPersonalLocalRun`. Recheck current state, then use one foreground runner process for one attempt. No retry, C2, extraction, Unity, or import.

### Work Package R8.2 - Validate C1 outputs and operational state

**Target child Task duration:** 20-30 minutes.
**Files:** read-only C1-O01/C1-O02 and private/redacted C1 evidence beneath the approved output root; no source content reopened.
**Acceptance:** schemas, source/file/byte conservation, fingerprints, end HEAD/input identities, no sensitive leak, and explained filesystem delta all pass; otherwise Stop.
**Evidence:** C1 validation summary, failure owner, retained/quarantine inventory, source-immutability proof.

Steps:

1. Verify process termination and end identities - 3 minutes.
2. Validate C1-O01/C1-O02 shape and fingerprints - 5 minutes.
3. Prove source/file/byte conservation - 5 minutes.
4. Scan portable outputs for forbidden machine data - 4 minutes.
5. Compare approved pre/post operational state - 4 minutes.
6. Emit Stop or baseline-review candidate - 3 minutes.

### Work Package R8.3 - Human baseline decision

**Target child Task duration:** 20-30 minutes.
**Files:** no repository change; immutable baseline and approval records remain machine-local.
**Acceptance:** first capture always Stops; the human either rejects it or freezes it as a candidate baseline with exact identity. No C2 authorization results.
**Evidence:** redacted decision record referencing snapshot/input fingerprints and conservation result.

Steps:

1. Review completeness/conservation and residual issues - 5 minutes.
2. Review source-kind/source-ID coverage without paths - 4 minutes.
3. Review failure/quarantine and sensitive-leak results - 4 minutes.
4. Reject or freeze immutable candidate baseline - 4 minutes.
5. Record next action and stop - 3 minutes.

### Work Package R8.4 - Close first-capture review and hand off future baseline matching

**Target child Task duration:** 20-25 minutes.
**Files:** no repository change unless a separate documentation child Task is authorized.
**Acceptance:** the first-capture decision, conservation, immutability, and no-leak result are frozen; C1-E01 remains diagnostic and `C2Authorized=false`. The current package cannot start a second attempt. If baseline matching is required, prepare a new independent PersonalLocalMode continuation package/plan in a later Task, recompute all state, and stop for its own single-confirmation boundary.
**Evidence:** redacted first-capture handoff identity, explicit `C2Authorized=false`, and either `nextAction=Stop` or `nextAction=PrepareIndependentBaselineMatchCycle`.

**R8 checkpoint:** wait for a separate R9 contract/implementation authorization. C1 success alone is insufficient.

---

## 8. R9 - Real C2 Discovery

Current state is `BLOCKED`: no reviewed real C1-to-C2 adapter, real observation-producer set, or real publication-root contract exists.

### Work Package R9.1 - Freeze the real C2 contract change

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c2-real-discovery-contract.md`, `docs/asset-migration/schemas/c2-real-discovery-authority.schema.json`; modify only `docs/asset-migration/c2-discovery-phase-b-runbook.md` and, only if a registry row truly changes, `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`.
**Acceptance:** exact C1-E01-to-AR mapping, producer row schema, real staging/publication transaction, portable/private boundary, storage, failure ownership, and eight physical SP-09 consumer paths are reviewed.
**Verification:** schema parse/tests, registry-reference review, `git diff --check`; no real data read.

Steps:

1. Map C1-E01 to AR-I01 through AR-I06 - 5 minutes.
2. Freeze producer-manifest fields for AR-I07/08/09 and AR-I11 - 5 minutes.
3. Freeze real stage/backup/quarantine/lock/journal/consumer roots - 5 minutes.
4. Map every new failure to one FT row or request a registry change - 4 minutes.
5. Validate portable/private and conservation contracts - 4 minutes.
6. Stop for contract review - 2 minutes.

### Work Package R9.2 - Implement and fixture-test the real adapter shell

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; fixture changes require a separately enumerated exact list and may never contain real data.
**Acceptance:** fixture-only adapter validates C1 identity, immutable inputs, authority manifest, path boundaries, and calls the existing C2 registered model without changing its semantics.
**Verification:** all new adapter cases plus the complete existing C2/C1/minimal regression matrix; no real path or heavy process.

Each increment stops after one cohesive adapter capability and one passing regression set.

### Work Package R9.3 - Implement one approved observation producer row

**Target child Task duration:** one 20-30 minute child Task per producer row/capability.
**Files:** exactly the `implementationPath`, `testPath`, and fixture paths frozen in the approved producer row from R9.1; if any is absent, the child Task is blocked.
**Acceptance:** exact tool/version/hash, allowed source kinds/selectors, child process count, row shape, timeout/cancellation, terminal accounting, rollback/quarantine, and no-Unity assertion pass on synthetic fixtures.
**Verification:** producer-specific fixtures/fault vectors and C2 conservation regression.

Repeat R9.3 only after explicitly naming the next producer row. Never batch multiple tools under one child Task.

### Work Package R9.4 - Implement the real SP-09 publisher and locked consumer

**Target child Task duration:** 20-30 minutes per transaction increment.
**Files:** modify `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; no fixture consumer path becomes a real root.
**Acceptance:** same-volume stage/backup/quarantine/lock/journal semantics, fixed eight-path order, summary-last commit, exact rollback/recovery, and locked-consumer fingerprints pass injected fault vectors.
**Verification:** transaction/fault suite, complete C2 suite, and no TEMP/output leak.

### Work Package R9.5 - Independent completion audit and exact C2 authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c2-real-discovery-authorization-package.md`; all implementation/spec/runbook paths read-only.
**Acceptance:** fresh audit covers adapter, every producer, SP-01 through SP-09, FT-01 through FT-15, output vectors, rollback/recovery, and forbidden operations; the package freezes one diagnostic operation and all LO fields.
**Evidence:** audit command/result matrix, fixture-tree digest, exact hashes, zero real outputs.

### Work Package R9.6 - Obtain separate exact authorization for one C2 discovery

**Target child Task duration:** 20-30 minutes.
**Files:** none changed; external approval only.
**Acceptance:** exact C1 artifact/baseline identities, adapter/producer hashes, source kinds/selectors, staging/publication roots, counts/bytes/storage, duration/cancellation, output classes, stop/rollback/quarantine/retention, and explicit no-Unity/no-downstream boundaries are Confirmed.
**Evidence:** redacted approval-row conservation, exact command identity, and one R9 LO record with no source path or content.

### LO R9.C2-1 - First real C2 discovery

Run one approved producer sequence and one publication transaction. The first real run is diagnostic-only even if Passed. No retries or C3-C6 execution.

### Work Package R9.7 - Validate and review real C2

**Target child Task duration:** 20-30 minutes.
**Files:** real C2 artifacts read-only; no source reopen.
**Acceptance:** simultaneous SP-01 through SP-09 conservation, correct output vector (`5/5/0`, `1/4/0`, or FT-12 `0/5/0` as applicable), locked consumer acceptance, stable end identities, and fully explained filesystem delta.
**Evidence:** redacted diagnostic summary and human `Stop`/`Review` decision.

**R9 checkpoint:** wait for explicit R10 authorization. C2 Passed does not authorize lifecycle publication or extraction.

---

## 9. R10 - Static Family Qualification

### Work Package R10.1 - Freeze real C3-C6 lifecycle and LC-I14 aggregation contracts

**Target child Task duration:** 20-30 minutes per contract increment.
**Files:** create `docs/asset-migration/c3-c6-real-lifecycle-contract.md`; modify only `docs/superpowers/specs/2026-07-15-stella-sora-asset-corpus-c3-c6-design.md` when reviewed central registry rows must change.
**Acceptance:** freezes real LC-I06 publication; real C3-C6 generation roots; lane-private static fragment Artifact Registry rows and schemas; one deterministic LC-I14 aggregator; duplicate-subject/check rejection; Ordinal `(assetObjectId,checkId)` sorting; shared snapshot/generation/fingerprint conservation; transaction, locked-consumer, suppression, rollback, and quarantine semantics; and exact later R11/R12 refresh-generation/carry-forward rules. Fixture paths remain fixture-only. G5 publication is explicitly excluded.
**Verification:** Artifact/Partition/Failure cross-reference, fixed counterexamples for missing/duplicate/misordered/mixed-generation fragments, portable/private review, schema tests, and `git diff --check`.

No real lifecycle implementation or run is authorized by R10.1.

### Work Package R10.2 - Implement and fixture-test the LC-I06 producer/publisher

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `Tools/AssetImport/C3C6RealLifecycleAdapter.psm1`, `Tools/AssetImport/Invoke-C3C6RealLifecycle.ps1`, and `Tools/AssetImport/Test-C3C6RealLifecycleAdapter.ps1`; any fixture files require an exact child-plan list and synthetic data only.
**Acceptance:** fixture inputs produce one schema-valid, deterministic LC-I06 generation with exact source/object identities, typed references, direct-input hashes, transaction state, and locked-consumer validation; real inputs remain blocked.
**Verification:** producer/publisher happy path, stale/mutated/missing/duplicate input vectors, rollback/recovery, exact hashes, and complete existing C3-C6 fixture regression.

### Work Package R10.3 - Implement and fixture-test lane-private fragment producers

**Target child Task duration:** one 20-30 minute child Task per lane producer capability.
**Files:** create `Tools/AssetImport/C4StaticObservationProducer.psm1` and `Tools/AssetImport/Test-C4StaticObservationProducer.ps1`; exact synthetic fixtures are enumerated per child Task.
**Acceptance:** each registered lane producer emits only its registered private fragment type; every assigned check is terminally accounted; producer/tool/input fingerprints and shared generation identity are exact; no LC-I14 or C4 output is emitted.
**Verification:** Actor/Audio/Effects/Environment/UI fixture vectors, duplicate-within-lane, missing prerequisite, tool-unavailable, deterministic ordering, and forbidden process/path tests.

### Work Package R10.4 - Implement and fixture-test the LC-I14 aggregator, transaction, and locked consumer

**Target child Task duration:** 20-30 minutes per transaction increment.
**Files:** create `Tools/AssetImport/C4StaticObservationPublication.psm1` and `Tools/AssetImport/Test-C4StaticObservationPublication.ps1`; synthetic fault fixtures require exact enumeration.
**Acceptance:** registered lane fragments aggregate into exactly one LC-I14 package; rows are globally unique and Ordinal sorted; shared snapshot/generation/fingerprints conserve; stage/journal/backup/quarantine/summary-last publication and locked consumption are fail-closed.
**Verification:** missing-lane, duplicate-cross-lane, misordered, contradictory, mixed-generation, install/rollback/recovery/quarantine, partial-publication, and locked-consumer fault vectors.

### Work Package R10.5 - Implement and fixture-test real C3-C6 publication transactions

**Target child Task duration:** 20-30 minutes per stage publisher increment.
**Files:** create `Tools/AssetImport/C3C6LifecyclePublication.psm1` and `Tools/AssetImport/Test-C3C6LifecyclePublication.ps1`; modify `Tools/AssetImport/Invoke-C3C6RealLifecycle.ps1` only as enumerated by the child Task.
**Acceptance:** C3, C4, C5, and C6 each publish as separate registered stages with exact generation binding, fixed output order, locked consumers, downstream suppression, rollback/recovery, and no cross-stage atomic shortcut. A later refresh may reference or carry forward unchanged prior-stage bytes only through the exact R10.1 contract; it may never mutate an accepted generation in place or silently relabel old bytes with a new generation identity.
**Verification:** stage-by-stage success/failure vectors, stale direct inputs, partial stage install, downstream suppression, recovery/quarantine, and same-generation C2-C6-G5 fixture harness.

### Work Package R10.6 - Independent real-lifecycle completion audit

**Target child Task duration:** 20-30 minutes.
**Files:** all R10.1-R10.5 contracts/code/tests/fixtures read-only; no real inputs or lifecycle outputs.
**Acceptance:** fresh audit covers LC-I06 producer/publisher, every lane fragment producer, LC-I14 aggregation/transaction/locked consumer, separate C3-C6 publishers, registered failure vectors, no-heavy fixture boundary, output suppression, and state restoration.
**Evidence:** audit matrix, fixture-tree digest before/after, exact implementation hashes, zero real-output declaration, and any blocking gap.

### Work Package R10.7 - Prepare the exact R10 authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c3-c6-real-lifecycle-authorization-package.md`; implementation/contracts remain read-only.
**Acceptance:** package freezes one diagnostic real lifecycle generation: exact stage-specific execution HEAD, accepted C2 generation, adapter/producer/publisher hashes, observation selectors, real roots, generation identity, counts/bytes/storage, LO rows, duration/cancellation, process limits, transaction/rollback/quarantine/retention, portable/private outputs, and explicit no-staging/no-Unity/no-G5-publication boundaries.
**Verification:** authorization Artifact/Partition/Failure conservation, exact hash/command list, protected/forbidden checks, and all rows Pending before human action.

### Work Package R10.8 - Obtain exact R10 human approval

**Target child Task duration:** 20-30 minutes.
**Files:** none changed; approval remains external and redacted.
**Acceptance:** every R10 authorization row is Confirmed against the current pushed stage-specific HEAD; no real evidence read or lifecycle process starts.
**Evidence:** approval-row conservation, approval identity, frozen-byte list, and explicit one-generation/no-retry boundary.

Any relevant byte or execution-HEAD change before the first authorized R10 operation starts voids the unstarted R10 approval and returns to R10.7/R10.8. After the approved lifecycle generation and its post-run checks close, that R10 approval becomes historical evidence under section 4.7.

### Work Package R10.9 - Re-index existing evidence before acquiring anything

**Target child Task duration:** 20-30 minutes.
**Files:** read-only approved existing summaries/reports and accepted real C2 generation; the child plan must name one registered/private coverage-inventory output or specify no output.
**Acceptance:** every candidate evidence item is classified `Current`, `Stale`, `Missing`, or `Contradictory` by fingerprint; no tool is rerun merely because the lifecycle model changed.
**Evidence:** registered/private coverage inventory and explicit reacquisition reasons; it is not LC-I14 and cannot be consumed by C4.

### Work Package R10.10 - Publish real LC-I06 typed lane facts

**Target child Task duration:** 20-30 minutes per approved adapter increment or authorized LO.
**Files:** accepted real C2 inputs read-only; write only the approved real LC-I06 transaction/generation paths using R10.2 bytes.
**Acceptance:** Actor, Audio, Effects, Environment, and UI facts preserve source/object identities, typed references, configuration disposition, and cross-lane provenance; locked consumer accepts one complete LC-I06 generation.
**Verification:** schema/fingerprint/conservation, start/end identities, transaction state, no-leak, and source-immutability checks.

### Work Package R10.11 - Run and publish C3 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted LC-I06 and registered C3 inputs read-only; write only C3-O01 through C3-O04 using the R10.5 C3 publisher.
**Acceptance:** SP-30 dispatch and SP-31 dependency partitions conserve counts/bytes; C3 outputs form one locked generation; conflicts/missing references remain visible; no C4 output exists.
**Verification:** C3 gate, locked consumer, generation fingerprints, C4-output suppression, and transaction rollback tests.

### Work Package R10.12 - Produce one registered real lane-private static fragment

**Target child Task duration:** one 20-30 minute child Task or authorized LO per lane in this fixed order: Actor, Audio, Effects, Environment, UI.
**Files:** accepted C3 generation and only approved current lane evidence read-only; write only the registered lane-private fragment path using R10.3 producer bytes.
**Acceptance:** every assigned check has one terminal Passed/Failed/Unchecked row; lane counts conserve; shared identities match; no LC-I14, C4 output, or Unity process is created.
**Verification:** lane validator, fragment schema/hash, process/output budget, start/end identities, and forbidden-path/process checks.

### Work Package R10.13 - Aggregate and publish exactly one LC-I14

**Target child Task duration:** 20-30 minutes.
**Files:** all accepted lane-private fragments read-only; write only the approved LC-I14 transaction/generation paths using R10.4 bytes.
**Acceptance:** all lanes are terminal; rows are globally unique and Ordinal sorted; counts/checks/fingerprints conserve; any invalid fragment suppresses LC-I14 and all downstream-valid output and enters the registered diagnostic/quarantine transition.
**Verification:** aggregator validation, exact LC-I14 schema/hash, locked consumer, start/end identities, rollback/quarantine, and downstream-output absence.

### Work Package R10.14 - Publish C4 only

**Target child Task duration:** 20-30 minutes.
**Files:** the accepted LC-I14 plus the other twelve registered C4 inputs read-only; write only C4-O01 through C4-O03 using the R10.5 C4 publisher.
**Acceptance:** all thirteen direct inputs match; SP-40 conserves; C4 generation is complete and locked; no C5 output is created.
**Verification:** C4 gate, direct-input hash frame, same-generation/freshness, locked consumer, and C5-output suppression.

### Work Package R10.15 - Derive and publish C5 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted C3/C4 generation and registered C5 inputs read-only; write only C5-O01 through C5-O04 using the R10.5 C5 publisher.
**Acceptance:** SP-50/SP-51 conserve; C5-O03 is an evidence request list only; no C6 output, Unity process, or acceptance inference occurs.
**Verification:** C5 gates, same-generation/freshness, locked consumer, missing-evidence vectors, and C6-output suppression.

### Work Package R10.16 - Publish provisional C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted C3-C5 generation/current repair history read-only; write only C6-O01 through C6-O05 using the R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; decision precedence is honored; missing evidence remains visible; no `UseOriginalAsset` without required evidence; locked C6-O04 is eligible only for later review.
**Verification:** C6 gates, same-generation harness, locked consumer, start/end identities, and diagnostic-only R10 closeout.

**R10 checkpoint:** human reviews family/static failures and explicitly chooses R11 candidates. Static qualification does not authorize staging.

---

## 10. R11 - Controlled Staging And RepairOnce

### Work Package R11.1 - Freeze the staging whitelist and repair authorization

**Target child Task duration:** 20-30 minutes.
**Files:** create a machine-local immutable staging authorization record; repository docs change only under a separately enumerated docs child Task.
**Acceptance:** exact family/member IDs, source artifact fingerprints, operation/tool hashes, target relative paths, total count/bytes, storage, license/redistribution boundary, rollback/quarantine, and one repair class per family are approved.
**Evidence:** redacted whitelist summary and `unlistedMemberCount=0`.

### Work Package R11.2 - Preflight one controlled staging batch

**Target child Task duration:** 20-30 minutes.
**Files:** approved source artifacts read-only; approved `Extracted` staging root and `Assets/StellaGaia/Imported` target remain absent until the LO begins.
**Acceptance:** all whitelist hashes, dependency closure, target collisions, reparse safety, storage, and rollback plan pass; exact existing staging script hash is approved or a separate implementation child Task is required.
**Evidence:** zero-write preflight and exact LO command.

### LO R11.STAGE-n - One whitelisted staging batch

Stage only the named members. No complete export, unlisted dependency, source mutation, or automatic repair. Validate every copied byte and retain the transaction record.

### Work Package R11.3 - Validate the staged batch

**Target child Task duration:** 20-30 minutes.
**Files:** staged outputs and transaction evidence read-only.
**Acceptance:** expected/actual count/bytes/hashes and relative paths match; no extra file exists; rollback remains possible; redistribution state is explicit.
**Evidence:** batch manifest, conservation result, source-immutability proof.

### Work Package R11.4 - Authorize one RepairOnce attempt

**Target child Task duration:** 20-30 minutes per family/repair class.
**Files:** machine-local LC-I12 record plus exact existing repair script/inputs/outputs; code changes require a separate exact implementation child Task.
**Acceptance:** one concrete failure attribution, explicit inputs, measurable expected change, approved tool/hash/command/output, and `attemptCountBefore=0`.
**Evidence:** immutable RepairOnce authorization; no operation yet.

### LO R11.REPAIR-n - One focused repair attempt

Execute exactly one repair for one family/repair class. Never repeat the same class automatically. Record actual outputs and attempt outcome in LC-I12.

### Work Package R11.5 - Produce new-generation lane fragments after RepairOnce

**Target child Task duration:** one 20-30 minute child Task per required lane/family projection.
**Files:** repaired family inputs, prior accepted lane evidence, and prior fragment hashes read-only; write only one registered new-generation lane-private fragment per child Task and append the immutable LC-I12 result for the changed family.
**Acceptance:** changed checks have measurable before/after results; every check is terminally accounted; every fragment used by the next LC-I14 binds the new intended generation. Unchanged facts are recomputed or carried forward only through the exact audited R10.1/R10.5 rule with prior-byte hashes; old-generation fragments are never mixed or relabeled. No LC-I14 or C4-C6 output is created.
**Verification:** lane producer/static gate, carry-forward authority and prior-byte hash when applicable, fragment schema/fingerprint/conservation, LC-I12 max-attempt validation, and LC-I14/C4-C6 output absence.

### Work Package R11.6 - Re-aggregate and publish exactly one LC-I14

**Target child Task duration:** 20-30 minutes.
**Files:** all accepted new-generation lane fragments read-only; write only a new LC-I14 generation using the audited R10.4 aggregator/publisher bytes.
**Acceptance:** all lanes share the same new lifecycle generation; rows are unique and Ordinal sorted; checks/fingerprints and any registered carry-forward links conserve; aggregation failure suppresses LC-I14 and every downstream output.
**Verification:** LC-I14 aggregator/locked consumer, changed-versus-unchanged fragment identity check, duplicate/mixed-generation vectors, rollback/quarantine, and C4-C6 output absence.

### Work Package R11.7 - Re-publish C4 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted replacement LC-I14 and the other twelve C4 inputs read-only; write only C4-O01 through C4-O03 using the audited R10.5 C4 publisher.
**Acceptance:** SP-40 conserves; changed-family before/after static outcome is explicit; C4 generation locks successfully; no C5/C6 output is created.
**Verification:** C4 gate, direct-input hashes, same-generation/freshness, locked consumer, and C5/C6 output absence.

### Work Package R11.8 - Re-publish C5 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C4 and registered C5 inputs read-only; write only C5-O01 through C5-O04 using the audited R10.5 C5 publisher.
**Acceptance:** SP-50/SP-51 conserve; repair-related evidence requests and assessment states are current; no C6 output or Unity process occurs.
**Verification:** C5 gates, same-generation/freshness, locked consumer, and C6-output suppression.

### Work Package R11.9 - Re-publish C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C3-C5 generation and LC-I12 history read-only; write only C6-O01 through C6-O05 using the audited R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; failed/no-improvement RepairOnce results become `PrototypeReplacement` or `Stop` according to precedence; no further repair is authorized.
**Verification:** C6 gates, RepairOnce history, same-generation harness, locked consumer, and final R11 decision diff.

**R11 checkpoint:** wait for exact R12 Unity authorization. Staged files and C5-O03 do not authorize Unity.

---

## 11. R12 - Single-Thread Representative Unity Validation

### Work Package R12.1 - Freeze Unity environment and unavailability semantics

**Target child Task duration:** 20-30 minutes.
**Files:** read-only `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, approved tool metadata, and C5-O03; no Unity launch.
**Acceptance:** exact Unity version/editor SHA-256, license/seat/operator, project root, cache/output budget, network-disabled policy, allowed child processes, and foreground cancellation are approved. If unavailable, emit `UnityExecutionUnavailable`, never asset rejection.
**Evidence:** redacted environment capability record.

### Work Package R12.2 - Implement/review the C7/G4 evidence producer contract

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `docs/asset-migration/c7-g4-unity-evidence-contract.md`; implementation/test paths must be enumerated in a child plan before code changes.
**Acceptance:** C5-O03 request -> one representative queue item -> immutable LC-I09/LC-I10 evidence package is exact for Actor, Audio, Effects, Environment, and UI; no evidence may be reused across incompatible routes.
**Verification:** fixture-only queue/evidence/failure tests and no Unity launch.

### Work Package R12.3 - Freeze the single-thread queue and one-item authorizations

**Target child Task duration:** 20-30 minutes.
**Files:** machine-local immutable queue/approval records; C5-O03 read-only.
**Acceptance:** deterministic queue, one active item maximum, representative selection reason, required observation checklist, exact project/write boundaries, and one LO record per item.
**Evidence:** `activeUnityItemCount=0` before execution and complete queue conservation.

### LO R12.UNITY-n - Validate one representative only

Launch one approved Unity foreground process for one representative requirement. No parallel editor, background retry, package download, or next queue item. Capture the lane-required visible/audible/log/dependency evidence and immutable process/tool/input identities.

### Work Package R12.4 - Validate one LC-I10 evidence package

**Target child Task duration:** 20-30 minutes per representative.
**Files:** the single representative's logs, screenshots, structured LC-I10 package, queue item, and tool/process identities are read-only; no C5/C6 lifecycle output is changed.
**Acceptance:** LC-I10 is current, requirement-specific, attributable, immutable, and free of sensitive paths; Unity execution failure is distinguished from asset evidence failure; the package is frozen for later C5 consumption without assigning a C5 assessment or C6 decision here.
**Evidence:** validated/frozen LC-I10 identity and one requirement-level validation result; explicit `C5Written=false`, `C6Written=false`.

### Work Package R12.5 - Assess evidence and publish C5 only after the approved queue

**Target child Task duration:** 20-30 minutes.
**Files:** all validated/frozen LC-I10 packages, accepted C3/C4 generation, and registered C5 policy inputs read-only; write only C5-O01 through C5-O04 using the audited R10.5 C5 publisher.
**Acceptance:** all requested representative evidence is terminally assessed; SP-50/SP-51 conserve; capability suitability remains independent; generation binding or prior-stage carry-forward follows the exact audited R10.1/R10.5 rule with no in-place mutation or silent relabeling; no C6 output is created.
**Verification:** C5 gates, LC-I09/LC-I10 authority/freshness, same-generation checks, locked consumer, and C6-output suppression.

### Work Package R12.6 - Publish C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C3-C5 generation and repair history read-only; write only C6-O01 through C6-O05 using the audited R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; only families satisfying static plus representative requirements may become `UseOriginalAsset`; Unity unavailability remains distinct from asset rejection; no G5 execution or publication occurs.
**Verification:** C6 gates, same-generation harness, decision precedence, locked consumer, and G5-process/output absence.

**R12 checkpoint:** wait for exact R13 G5 authorization. Unity evidence does not directly set a root conclusion.

---

## 12. R13 - In-Memory G5 And Final Handoff

### Work Package R13.0 - Freeze the G5 execution mode

**Target child Task duration:** 20-30 minutes.
**Files:** read-only G5 module/tests, root summary schema, C3-C6 design, and accepted C6-O04; no output root is created.
**Acceptance:** choose exactly one mode before R13.1:

1. `InMemoryOnly` - the current authorized mode and default; G5 returns an in-memory root summary with zero publication activity.
2. `PersistentPublicationRequested` - blocked until a separate contract-change child Task freezes G5 output Artifact Registry rows, schemas, root/generation identity, writer/transaction, Failure Transitions, publication/rollback/quarantine rules, locked consumer, fixed counterexamples, and publication fault tests.

The R10 lifecycle contract does not authorize G5 publication. Merely defining publication order or a filesystem root is insufficient. If the persistent contract is not completely reviewed and committed before its exact approval, R13.1 must use `InMemoryOnly`.

**Verification:** mode declaration, current G5 code-path audit, zero-publication fixture tests, and, only for a future persistent mode, the complete new contract/fault matrix.

### Work Package R13.1 - Validate final same-generation inputs and run in-memory G5

**Target child Task duration:** 20-30 minutes.
**Files:** read-only accepted C1/C2/C6-O04 generation, G5 module/tests, and root schema; no G5 summary/report file or output root is written in `InMemoryOnly` mode.
**Acceptance:** G5 reads only a valid Passed C6-O04 handoff, verifies direct child fingerprints/conservation, returns four independent in-memory conclusions, performs zero executor/heavy/publication activity, and makes no restoration or readiness overclaim.
**Verification:** G5 validator, same-generation harness, root schema, fixed counterexamples, output-root absence, and process/write observation.

Steps:

1. Freeze accepted generation identities - 3 minutes.
2. Validate C6-O04 and direct-child fingerprints - 5 minutes.
3. Run lightweight in-memory G5 only; no heavy child or writer process - 3 minutes.
4. Validate the four independent conclusions - 5 minutes.
5. Review residual issues, failure owners, and next actions - 4 minutes.
6. Stop for human acceptance - 2 minutes.

### Work Package R13.2 - Final completion audit and handoff

**Target child Task duration:** 20-30 minutes.
**Files:** repository/evidence read-only; create or modify only an exact final handoff file named in a separate docs authorization.
**Acceptance:** audit covers registries, all conservation equations, fixed failure vectors, stale-input handling, source immutability, retained/quarantined outputs, redistribution constraints, user entry/success path, G5 mode, and the four independent conclusions.
**Evidence:** final audit matrix and list of unresolved families/capabilities; `integrationExecuted=false`, `cleanupExecuted=false`.

### Work Package R13.3 - Prepare the separate integration/cleanup authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create only an exact integration/cleanup authorization-package path named by its child Task plan; repository, remote refs, worktrees, retained evidence, and source workspace remain read-only.
**Acceptance:** the package must freeze, rather than placeholder, all of:

1. exact reviewed commit range and source/destination refs;
2. one concrete integration mechanism and operator;
3. exact commands/API operations, conflict-file list/policy, and abort/rollback method;
4. required CI/tests and observable success evidence;
5. source-derived binary inclusion/redistribution decision;
6. dirty source-workspace non-interference rule;
7. post-integration ref/ancestry verification;
8. separate cleanup targets, protected-file disposition, retained/quarantine decisions, and recoverability proof.

The dirty source workspace `C:\SoftWork\Git\StellaGaia` remains read-only and is not switched, reset, staged, or merged by this roadmap.

**Verification:** package completeness audit, read-only ref/worktree inventory, protected hashes, and `integrationExecuted=false`/`cleanupExecuted=false`.

### Actual integration and cleanup boundary

Actual merge/integration, worktree removal, parent cleanup, branch deletion, tag, release, publication, or distribution are outside this Program Roadmap. They require a new Superpowers strict-mode plan created from the accepted R13.3 package, with separate integration authorization followed by separate cleanup authorization. No R13 success state implies those actions.

The later plan may not use `git worktree prune`, `git reset --hard`, broad recursive deletion, or an extra worktree without new explicit authority. If no safe concrete integration method can be frozen, stop and hand integration to the user.

## 13. Phase Exit Matrix

| Phase | Required input | Success evidence | Does not authorize | Next exact gate |
|---|---|---|---|---|
| R7 | committed PersonalLocalMode governance | protected-state resolution + R8 plan + post-change revalidation + mode policy GREEN | real input or R8 command | R8.1 automatic preflight |
| R8 | GREEN derived state + one `ConfirmPersonalLocalRun` | conserved one-attempt snapshot + human first-capture baseline decision; any match requires an independent future cycle | C2 | baseline closure, then separate R9 contract and run approvals |
| R9 | accepted C1 + real adapter/producers/publisher | diagnostic real C2 review with SP-01..09 conserved | static/extraction/Unity | R10 lifecycle approval |
| R10 | accepted real C2 + implemented/audited lifecycle + exact R10 approval | LC-I06 -> C3-only -> lane fragments -> one LC-I14 -> C4-only -> C5-only -> provisional C6 | staging/repair/Unity/G5 publication | R11 whitelist approval |
| R11 | exact whitelist and repair cause | conserved staged batch + at most one repair/class -> lane fragment -> LC-I14 -> C4-only -> C5-only -> C6-only | Unity | R12 environment/item approvals |
| R12 | C5 requests + Unity capability | frozen LC-I10 packages -> C5-only assessment -> C6-only decisions | G5 conclusion/integration | R13 G5 approval |
| R13 | accepted same-generation C6-O04 | independent in-memory G5 conclusions + final audit + integration/cleanup authorization package | merge/cleanup/publication | new independent integration plan and approval |

## 14. Verification Before Any Completion Claim

At minimum, the owning child Task must run and read:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
git diff --check
Get-FileHash -Algorithm SHA256 -LiteralPath .\AGENTS.md
Get-FileHash -Algorithm SHA256 -LiteralPath .\docs\superpowers\plans\2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

Then run only the stage-specific lightweight validators explicitly authorized for that child Task. Heavy tests or producers require their own LO when they exceed the ordinary child Task boundary. Verify these paths according to stage authority rather than deleting them:

```text
Extracted
Assets/StellaGaia/Imported
Library
Temp
Obj
Build
Builds
Logs
UserSettings
```

Before their authorized stage they must be absent. After creation they must be registered, owned, bounded, and fully accounted; an unexpected existing path is Stop and preserve-for-review, not cleanup permission.

## 15. Current Stop Checkpoint

```text
currentPhase=R7-PersonalLocalModeMigration
mode=PersonalLocalMode
humanFormFieldCount=0
PB-SP01=6 Unevaluated until R8.1
R8ThroughR13Authorized=false
realSourceAccessed=false
phaseBExecuted=false
nextAction=Complete PersonalLocalMode governance/test migration, then run R7.4/R7.5 validation and R8.1 automatic preflight. Request `ConfirmPersonalLocalRun` only after GREEN and immediately before LO.
```
