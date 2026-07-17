# StellaSora Phase B R7-R13 Complete Execution Plan

> **Status:** PROGRAM PLAN READY FOR REVIEW. R7 exact confirmation remains the first executable gate; R8-R13 remain blocked until their own prerequisites and exact human authorizations are satisfied.
>
> **Authority boundary:** this plan does not confirm PB-A01 through PB-A12, read a real manifest or source root, authorize a heavy operation, or permit C1/C2/extraction/staging/Unity/import/G5/merge/cleanup.
>
> **Execution cadence:** one ordinary Task per turn, 20-30 minutes maximum. Each Step is one 2-5 minute action. A command that cannot safely finish inside one ordinary Task is a Special Long-Running Operation, not an ordinary Task, and requires the separate gate defined below.

## 1. Goal And Product Path

- **Target user:** the human operator who owns the local StellaSora inputs, tool installations, storage, Unity license, evidence review, and final integration decision.
- **Scenario:** produce a frozen local source snapshot; review and, when required, match its baseline; discover and statically qualify all approved families; stage only explicit candidates; permit one focused repair attempt per family/failure class; run representative Unity validation one subject at a time; aggregate four independent G5 conclusions; then merge and clean up only after separate approval.
- **Entry:** branch `codex/asset-corpus-integration`, with the R7 package originating at `ff446c0cd55ea795e2714a5871a284f4aec584ab`, PB-A01 through PB-A12 still Pending, and no Phase B outputs. PB-A02 must bind the later exact execution HEAD that contains the reviewed package/tool bytes; it may not assume the origin commit remains the execution HEAD after docs-only commits.
- **Completion path:** R7 exact confirmation -> R8 C1 snapshot -> human baseline review and any separately authorized matching run -> separate R9 authorization and C2 discovery -> R10 static family qualification -> R11 controlled staging and RepairOnce -> R12 single-thread Unity -> R13 G5, integration, and separately authorized cleanup.
- **Success state:** the frozen input universe is conserved; every family/member has a current typed state and evidence route; the four G5 conclusions remain independent; source roots are unchanged; sensitive machine data stays local; no stage is inferred from an upstream pass; final integration and cleanup have explicit evidence and approval.

This workflow does not claim restoration of the original StellaSora Unity project and does not grant redistribution rights for source-derived assets.

## 2. Approach Choice

### Option A - Sequential evidence gates with independent heavy-operation approvals - Recommended

Use existing Phase A registries, gates, runners, fixtures, and evidence where current. Add only the missing real adapters, producer/publication contracts, lifecycle boundaries, and evidence producers. Stop after every real run for human review.

- Benefits: preserves provenance, failure ownership, source safety, and the user's exact control over every heavy action.
- Costs: more explicit review points and no automatic R8-to-R13 continuation.

### Option B - One broad Phase B authorization

Authorize snapshot, discovery, extraction, staging, Unity, and import together.

- Benefit: fewer operator prompts.
- Rejected because: it defeats PB-A11, the C2 diagnostic-only first-run rule, C5/C7 separation, RepairOnce limits, and the required merge/cleanup hard gates.

### Option C - Bulk extraction/import first

Generate a broad export, then classify what was produced.

- Benefit: superficially fast access to files.
- Rejected because: it loses all-file conservation, creates uncontrolled storage and licensing risk, and bypasses static family qualification and representative acceptance.

No implementation Task begins until the user confirms Option A or supplies a reviewed replacement.

## 3. Authority And Existing Contracts

Read these completely at the start of the relevant Task; do not silently replace them with this plan:

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

- C1 artifacts and authorization: PB-I01/PB-I02, C1-I01 through C1-I06, C1-O01/C1-O02, C1-E01; PB-SP01 through PB-SP05; PB-FT01 through PB-FT12.
- C2 discovery: AR-I01 through AR-I11, AR-P01, AR-O01 through AR-O05; SP-01 through SP-09; FT-01 through FT-15.
- C3-C6 lifecycle: LC-I01 through LC-I14; C3-O01 through C3-O04, C4-O01 through C4-O03, C5-O01 through C5-O04, C6-O01 through C6-O05; SP-30/SP-31/SP-40/SP-50/SP-51/SP-60/SP-61; LF-01 through LF-21.
- G5 consumes only a valid same-generation C6-O04 handoff and reports `CorpusSnapshotComplete`, `StructuredObjectCoverage`, `OriginalAssetBatchCoverage`, and `StellaSora2AuthoringReady` independently.

If a real operation cannot be expressed by these rows, the owning Task is a contract-change Task and stops for review. Operational scripts may not invent a second artifact, partition, failure, or decision model.

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

An atomic source scan, producer run, extraction, decode, publication, or Unity invocation that may exceed 20 minutes is an `LO`, not a normal Task. Before each LO, an external exact approval must freeze:

1. one operation/subject identity and one attempt only;
2. exact executable/script bytes, version, SHA-256, arguments, working directory, and allowed child processes;
3. immutable input identities and approved read/write roots;
4. positive integer maximum duration and operator-controlled foreground cancellation;
5. positive integer output/storage budget and required free-space formula;
6. progress evidence or a 20-minute operator checkpoint without starting a second process;
7. stop, partial-output, rollback, quarantine, retention, and no-retry behavior;
8. expected portable/private/diagnostic outputs and leak policy.

If the operation cannot expose bounded progress or safe cancellation, first implement a reviewed resumable/chunked runner contract in an ordinary Task. The agent may report at 20-minute checkpoints but may not broaden the authorization or start a concurrent replacement process.

### 4.5 Universal stop conditions

Stop on changed HEAD/input/tool bytes, unapproved path/process/network activity, missing registry row, invalid/stale evidence, conservation failure, sensitive leak, reparse point, collision, pre-existing unknown output, insufficient storage, partial publication, rollback/quarantine ambiguity, source mutation, or any need to weaken an expected result after seeing actual data.

## 5. Program Checkpoints

Every Task reports:

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

### Task R7.1 - Revalidate the committed authorization package

**Duration:** 20-25 minutes.
**Files:** read-only `docs/asset-migration/source-corpus-phase-b-authorization-package.md`, `docs/asset-migration/source-corpus-phase-b-runbook.md`, current tool/schema paths registered as C1-I03 through C1-I06; no files changed.
**Acceptance:** package commit, branch/upstream, frozen hashes, versions, protected hashes, and absent forbidden paths agree; no source or manifest read occurs.
**Evidence:** `git status --short --branch`, `git rev-parse HEAD`, `git rev-parse @{upstream}`, version output, exact file hashes, path-absence checks.

Steps:

1. Recheck branch, HEAD/upstream, and protected hashes - 3 minutes.
2. Recompute C1-I03 through C1-I06 hashes and tool versions - 4 minutes.
3. Recheck the package's registry/partition/failure conservation - 5 minutes.
4. Verify no output or forbidden path exists - 3 minutes.
5. Record exact mismatches or readiness and stop - 3 minutes.

### Task R7.2 - Obtain exact human confirmation of PB-A01 through PB-A12

**Duration:** 20-30 minutes.
**Files:** none changed; PB-I01 remains external and redacted.
**Acceptance:** `PB-SP01: 12 = 12 Confirmed + 0 Pending + 0 Rejected`; no source/manifest content is accessed; R8 is not started.
**Evidence:** external approval identity plus a portable row-status summary with no machine paths.

The human must confirm exactly:

1. PB-A01 - one diagnostic C1 `-RefreshSnapshot` attempt and no other operation.
2. PB-A02 - exact package/execution HEAD and branch.
3. PB-A03 - locally reviewed runtime-manifest identity and exact selected source-kind/source-ID sets.
4. PB-A04 - all available roots in the approved boundary are included; no network/runtime source.
5. PB-A05 - exactly `FirstCaptureNoBaseline` or `ApprovedBaselinePresent` plus immutable baseline identity.
6. PB-A06 - positive integer `approvedCombinedStagedArtifactEstimateBytes`.
7. PB-A07 - free space satisfies `max(1 GiB, 2 * estimate)` and staging/output boundaries are absent and safe.
8. PB-A08 - exact PowerShell/Git versions and every frozen SHA-256.
9. PB-A09 - canonical C1 output root and no-reparse/no-alternate-root policy.
10. PB-A10 - guarded command verbatim, without wrapper, extra flag/command, or retry.
11. PB-A11 - first capture and every nonmatching result Stop; all downstream stages remain unauthorized.
12. PB-A12 - operator identity, positive integer maximum duration, execution window, cancellation authority, sensitive-logging policy, and retention owner.

Steps:

1. Bind PB-I01 to package commit and PB-A01/PB-A02 - 3 minutes.
2. Record PB-A03 through PB-A05 without paths/content - 5 minutes.
3. Record PB-A06/PB-A07 numeric budget and boundary declarations - 4 minutes.
4. Confirm PB-A08 through PB-A10 exact bytes/command - 4 minutes.
5. Confirm PB-A11/PB-A12 stop/operator policy - 4 minutes.
6. Prove PB-SP01 conservation and stop - 3 minutes.

### Task R7.3 - Resolve the protected-untracked/clean-run conflict and LO contract

**Duration:** 20-30 minutes.
**Files if amendment is selected:** only `docs/asset-migration/source-corpus-phase-b-runbook.md` and `docs/asset-migration/source-corpus-phase-b-authorization-package.md`; protected files remain unchanged. If user-managed disposition is selected, repository files are unchanged.
**Acceptance:** the chosen disposition is explicit, preserves or externally dispositions the protected pair, permits no third dirty path, and freezes the LO rules for R8.
**Verification:** `git diff --check`, exact hashes/status, and package/runbook cross-reference review.

Steps:

1. Present the two dispositions and their consequences - 3 minutes.
2. Receive exact user choice; otherwise Stop - 2 minutes.
3. Apply only the selected docs amendment or verify user-managed evidence - 5 minutes.
4. Validate the LO duration/budget/cancellation/retention contract - 5 minutes.
5. Diff-check, exact-stage/commit/push only if separately requested - 5 minutes.
6. Stop with R8 still unexecuted - 2 minutes.

**R7 checkpoint:** wait for a separately reviewed R8 execution authorization. A broad statement such as `授权 Phase B` is insufficient.

---

## 7. R8 - Real C1 Snapshot And Baseline Review

### Task R8.1 - Exact preflight for one C1 operation

**Duration:** 20-30 minutes.
**Files:** repository read-only; machine-local PB-I01/C1-I01/C1-I02 identities are reviewed without copying them into Git.
**Acceptance:** PB-SP01 is 12/12 Confirmed; package/HEAD/tools/manifest/baseline/output/budget/LO approval all match; exact guarded command is frozen but not run.
**Evidence:** redacted preflight checklist and zero-process declaration.

Steps:

1. Revalidate repository and protected state - 3 minutes.
2. Validate PB-I01 identity and all twelve statuses - 4 minutes.
3. Locally validate runtime manifest shape/identity and approved source set - 5 minutes.
4. Validate baseline state and output/storage safety - 4 minutes.
5. Freeze command/process/time/cancellation values - 4 minutes.
6. Produce `ReadyForOneC1Attempt` or Stop - 3 minutes.

### LO R8.C1-1 - One guarded C1 snapshot attempt

**Not an ordinary Task.** Run only under the R8 LO record. Use the committed guarded runner as one foreground process. No retry, C2, extraction, Unity, or import. Preserve failure evidence without improvising cleanup.

### Task R8.2 - Validate C1 outputs and operational state

**Duration:** 20-30 minutes.
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

### Task R8.3 - Human baseline decision

**Duration:** 20-30 minutes.
**Files:** no repository change; immutable baseline and approval records remain machine-local.
**Acceptance:** first capture always Stops; the human either rejects it or freezes it as a candidate baseline with exact identity. No C2 authorization results.
**Evidence:** redacted decision record referencing snapshot/input fingerprints and conservation result.

Steps:

1. Review completeness/conservation and residual issues - 5 minutes.
2. Review source-kind/source-ID coverage without paths - 4 minutes.
3. Review failure/quarantine and sensitive-leak results - 4 minutes.
4. Reject or freeze immutable candidate baseline - 4 minutes.
5. Record next action and stop - 3 minutes.

### Task R8.4 - Authorize a matching run when baseline proof is required

**Duration:** 20-30 minutes.
**Files:** none changed; new external approval only.
**Acceptance:** one new exact PB-I01-like approval binds the approved baseline identity and a fresh operation identity; no reuse of the first approval.
**Evidence:** 12/12-equivalent confirmation and new LO record.

### LO R8.C1-2 - One baseline-matching C1 snapshot attempt

**Conditional and separately authorized.** Repeat R8.1/R8.2 controls. A mismatch Stops. A match produces `Review`, never automatic R9 authorization.

### Task R8.5 - Close C1 baseline review

**Duration:** 20-25 minutes.
**Files:** no repository change unless a separate documentation Task is authorized.
**Acceptance:** exact snapshot/baseline match, conservation, immutability, and no-leak result are human accepted; C1-E01 is frozen for a future adapter.
**Evidence:** redacted C1 handoff identity and explicit statement `C2Authorized=false`.

**R8 checkpoint:** wait for a separate R9 contract/implementation authorization. C1 success alone is insufficient.

---

## 8. R9 - Real C2 Discovery

Current state is `BLOCKED`: no reviewed real C1-to-C2 adapter, real observation-producer set, or real publication-root contract exists.

### Task R9.1 - Freeze the real C2 contract change

**Duration:** 20-30 minutes.
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

### Task R9.2 - Implement and fixture-test the real adapter shell

**Duration:** 20-30 minutes per increment.
**Files:** create `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; fixture changes require a separately enumerated exact list and may never contain real data.
**Acceptance:** fixture-only adapter validates C1 identity, immutable inputs, authority manifest, path boundaries, and calls the existing C2 registered model without changing its semantics.
**Verification:** all new adapter cases plus the complete existing C2/C1/minimal regression matrix; no real path or heavy process.

Each increment stops after one cohesive adapter capability and one passing regression set.

### Task R9.3 - Implement one approved observation producer row

**Duration:** one 20-30 minute Task per producer row/capability.
**Files:** exactly the `implementationPath`, `testPath`, and fixture paths frozen in the approved producer row from R9.1; if any is absent, this Task is blocked.
**Acceptance:** exact tool/version/hash, allowed source kinds/selectors, child process count, row shape, timeout/cancellation, terminal accounting, rollback/quarantine, and no-Unity assertion pass on synthetic fixtures.
**Verification:** producer-specific fixtures/fault vectors and C2 conservation regression.

Repeat R9.3 only after explicitly naming the next producer row. Never batch multiple tools under one Task.

### Task R9.4 - Implement the real SP-09 publisher and locked consumer

**Duration:** 20-30 minutes per transaction increment.
**Files:** modify `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; no fixture consumer path becomes a real root.
**Acceptance:** same-volume stage/backup/quarantine/lock/journal semantics, fixed eight-path order, summary-last commit, exact rollback/recovery, and locked-consumer fingerprints pass injected fault vectors.
**Verification:** transaction/fault suite, complete C2 suite, and no TEMP/output leak.

### Task R9.5 - Independent completion audit and exact C2 authorization package

**Duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c2-real-discovery-authorization-package.md`; all implementation/spec/runbook paths read-only.
**Acceptance:** fresh audit covers adapter, every producer, SP-01 through SP-09, FT-01 through FT-15, output vectors, rollback/recovery, and forbidden operations; the package freezes one diagnostic operation and all LO fields.
**Evidence:** audit command/result matrix, fixture-tree digest, exact hashes, zero real outputs.

### Task R9.6 - Obtain separate exact authorization for one C2 discovery

**Duration:** 20-30 minutes.
**Files:** none changed; external approval only.
**Acceptance:** exact C1 artifact/baseline identities, adapter/producer hashes, source kinds/selectors, staging/publication roots, counts/bytes/storage, duration/cancellation, output classes, stop/rollback/quarantine/retention, and explicit no-Unity/no-downstream boundaries are Confirmed.
**Evidence:** redacted approval-row conservation, exact command identity, and one R9 LO record with no source path or content.

### LO R9.C2-1 - First real C2 discovery

Run one approved producer sequence and one publication transaction. The first real run is diagnostic-only even if Passed. No retries or C3-C6 execution.

### Task R9.7 - Validate and review real C2

**Duration:** 20-30 minutes.
**Files:** real C2 artifacts read-only; no source reopen.
**Acceptance:** simultaneous SP-01 through SP-09 conservation, correct output vector (`5/5/0`, `1/4/0`, or FT-12 `0/5/0` as applicable), locked consumer acceptance, stable end identities, and fully explained filesystem delta.
**Evidence:** redacted diagnostic summary and human `Stop`/`Review` decision.

**R9 checkpoint:** wait for explicit R10 authorization. C2 Passed does not authorize lifecycle publication or extraction.

---

## 9. R10 - Static Family Qualification

### Task R10.1 - Freeze real lifecycle publication and LC-I06/LC-I14 producers

**Duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c3-c6-real-lifecycle-contract.md`; modify only `docs/superpowers/specs/2026-07-15-stella-sora-asset-corpus-c3-c6-design.md` if required by a reviewed contract gap.
**Acceptance:** real typed lane-fact publication, static observation publication, generation roots, provenance, freshness, and C3-C6/G5 publication order are exact; fixture paths remain fixture-only.
**Verification:** registry cross-reference, portable/private review, `git diff --check`.

### Task R10.2 - Re-index existing evidence before acquiring anything

**Duration:** 20-30 minutes.
**Files:** read-only existing summaries/reports and real C2 generation; output only to the approved real lifecycle staging root after separate non-heavy write authorization.
**Acceptance:** every candidate evidence item is classified `Current`, `Stale`, `Missing`, or `Contradictory` by fingerprint; no tool is rerun merely because the lifecycle model changed.
**Evidence:** LC-I14 coverage inventory and explicit reacquisition reasons.

### Task R10.3 - Publish real LC-I06 typed lane facts

**Duration:** 20-30 minutes per lane adapter increment.
**Files:** exact adapter/test paths frozen by R10.1; if they are not enumerated, Stop.
**Acceptance:** Actor, Audio, Effects, Environment, and UI facts preserve source/object identities, typed references, configuration disposition, and cross-lane provenance without reading unapproved bytes.
**Verification:** schema/fingerprint/conservation tests plus fixture regressions.

### Task R10.4 - Run C3 family membership and dependency qualification

**Duration:** 20-30 minutes.
**Files:** real LC-I06 and C3 outputs under the approved lifecycle root; existing C3 module is read-only unless an independently reviewed bug fix is authorized.
**Acceptance:** SP-30 dispatch and SP-31 dependency partitions conserve counts/bytes; C3-O01 through C3-O04 are one generation; conflicts/missing references remain visible.
**Verification:** C3 locked consumer and generation fingerprints.

### Task R10.5 - Qualify one static lane

**Duration:** one 20-30 minute Task per lane in this fixed order: Actor, Audio, Effects, Environment, UI.
**Files:** read-only C3 generation and only the approved lane-specific current evidence; write the lane's LC-I14/C4 staging artifacts beneath the R10.1 root.
**Acceptance:** every SP-40 member is exactly `StaticPassed`, `StaticFailed`, or `Unchecked`; `memberCount = passed + failed + unchecked`; bytes/checks conserve; no Unity process occurs.
**Verification:** lane-specific static validators and C4 contract checks.

Do not combine lanes to fit a schedule. A missing producer or expensive new observation becomes a separate contract/LO request.

### Task R10.6 - Aggregate C4 and derive C5 requirements only

**Duration:** 20-30 minutes.
**Files:** read-only completed lane generations; write C4-O01 through C4-O03 and C5-O01 through C5-O04 beneath the approved lifecycle root.
**Acceptance:** SP-40/SP-50/SP-51 conserve; C5-O03 is an evidence request list only; no Unity or acceptance inference occurs.
**Verification:** C4/C5 gates, same-generation and stale-input checks.

### Task R10.7 - Produce provisional C6 decisions

**Duration:** 20-30 minutes.
**Files:** read-only C3-C5/current repair history; write C6-O01 through C6-O05 beneath the approved lifecycle root.
**Acceptance:** SP-60/SP-61 conserve; decision precedence is honored; missing evidence stays `NeedsDiagnosis`, `RetainForLater`, `DiagnosticOnly`, or `Stop`; no `UseOriginalAsset` without required evidence.
**Verification:** C6 gates and same-generation C2-C6-G5 fixture regression.

**R10 checkpoint:** human reviews family/static failures and explicitly chooses R11 candidates. Static qualification does not authorize staging.

---

## 10. R11 - Controlled Staging And RepairOnce

### Task R11.1 - Freeze the staging whitelist and repair authorization

**Duration:** 20-30 minutes.
**Files:** create a machine-local immutable staging authorization record; repository docs change only under a separately enumerated docs Task.
**Acceptance:** exact family/member IDs, source artifact fingerprints, operation/tool hashes, target relative paths, total count/bytes, storage, license/redistribution boundary, rollback/quarantine, and one repair class per family are approved.
**Evidence:** redacted whitelist summary and `unlistedMemberCount=0`.

### Task R11.2 - Preflight one controlled staging batch

**Duration:** 20-30 minutes.
**Files:** approved source artifacts read-only; approved `Extracted` staging root and `Assets/StellaGaia/Imported` target remain absent until the LO begins.
**Acceptance:** all whitelist hashes, dependency closure, target collisions, reparse safety, storage, and rollback plan pass; exact existing staging script hash is approved or a separate implementation Task is required.
**Evidence:** zero-write preflight and exact LO command.

### LO R11.STAGE-n - One whitelisted staging batch

Stage only the named members. No complete export, unlisted dependency, source mutation, or automatic repair. Validate every copied byte and retain the transaction record.

### Task R11.3 - Validate the staged batch

**Duration:** 20-30 minutes.
**Files:** staged outputs and transaction evidence read-only.
**Acceptance:** expected/actual count/bytes/hashes and relative paths match; no extra file exists; rollback remains possible; redistribution state is explicit.
**Evidence:** batch manifest, conservation result, source-immutability proof.

### Task R11.4 - Authorize one RepairOnce attempt

**Duration:** 20-30 minutes per family/repair class.
**Files:** machine-local LC-I12 record plus exact existing repair script/inputs/outputs; code changes require a separate exact implementation Task.
**Acceptance:** one concrete failure attribution, explicit inputs, measurable expected change, approved tool/hash/command/output, and `attemptCountBefore=0`.
**Evidence:** immutable RepairOnce authorization; no operation yet.

### LO R11.REPAIR-n - One focused repair attempt

Execute exactly one repair for one family/repair class. Never repeat the same class automatically. Record actual outputs and attempt outcome in LC-I12.

### Task R11.5 - Requalify changed families and refresh C5/C6

**Duration:** 20-30 minutes per changed family.
**Files:** only changed-family static evidence and lifecycle outputs.
**Acceptance:** measurable before/after comparison exists; no improvement or repeated failure moves to `PrototypeReplacement` or `Stop`; C5 remains an evidence-request producer and does not run Unity.
**Verification:** lane static gate, RepairOnce history validation, C5/C6 same-generation checks.

**R11 checkpoint:** wait for exact R12 Unity authorization. Staged files and C5-O03 do not authorize Unity.

---

## 11. R12 - Single-Thread Representative Unity Validation

### Task R12.1 - Freeze Unity environment and unavailability semantics

**Duration:** 20-30 minutes.
**Files:** read-only `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, approved tool metadata, and C5-O03; no Unity launch.
**Acceptance:** exact Unity version/editor SHA-256, license/seat/operator, project root, cache/output budget, network-disabled policy, allowed child processes, and foreground cancellation are approved. If unavailable, emit `UnityExecutionUnavailable`, never asset rejection.
**Evidence:** redacted environment capability record.

### Task R12.2 - Implement/review the C7/G4 evidence producer contract

**Duration:** 20-30 minutes per increment.
**Files:** create `docs/asset-migration/c7-g4-unity-evidence-contract.md`; implementation/test paths must be enumerated in a child plan before code changes.
**Acceptance:** C5-O03 request -> one representative queue item -> immutable LC-I09/LC-I10 evidence package is exact for Actor, Audio, Effects, Environment, and UI; no evidence may be reused across incompatible routes.
**Verification:** fixture-only queue/evidence/failure tests and no Unity launch.

### Task R12.3 - Freeze the single-thread queue and one-item authorizations

**Duration:** 20-30 minutes.
**Files:** machine-local immutable queue/approval records; C5-O03 read-only.
**Acceptance:** deterministic queue, one active item maximum, representative selection reason, required observation checklist, exact project/write boundaries, and one LO record per item.
**Evidence:** `activeUnityItemCount=0` before execution and complete queue conservation.

### LO R12.UNITY-n - Validate one representative only

Launch one approved Unity foreground process for one representative requirement. No parallel editor, background retry, package download, or next queue item. Capture the lane-required visible/audible/log/dependency evidence and immutable process/tool/input identities.

### Task R12.4 - Validate one LC-I10 evidence package

**Duration:** 20-30 minutes per representative.
**Files:** the single representative's logs/screenshots/structured package read-only; lifecycle outputs updated only after evidence validation.
**Acceptance:** evidence is current, requirement-specific, attributable, immutable, and free of sensitive paths; Unity execution failure is distinguished from asset evidence failure.
**Evidence:** SP-50 assessment and SP-51 capability suitability for that requirement only.

### Task R12.5 - Refresh C5/C6 after the approved queue

**Duration:** 20-30 minutes.
**Files:** read-only validated LC-I10 packages and current C3-C5 generation; write new C5/C6 generation beneath the approved lifecycle root.
**Acceptance:** all requested representative evidence is terminally accounted, capability suitability remains independent, and only families satisfying static plus representative rules may become `UseOriginalAsset`.
**Verification:** C5/C6 gates, SP-50/SP-51/SP-60/SP-61 conservation, same-generation check.

**R12 checkpoint:** wait for exact R13 G5 authorization. Unity evidence does not directly set a root conclusion.

---

## 12. R13 - G5, Integration, And Cleanup

### Task R13.1 - Validate final same-generation inputs and run G5

**Duration:** 20-30 minutes.
**Files:** read-only accepted C1/C2/C6-O04 generation and G5 contracts; write only the approved final G5 summary/report root.
**Acceptance:** G5 reads only a valid Passed C6-O04 handoff, verifies direct child fingerprints/conservation, and reports four independent conclusions without restoration or readiness overclaim.
**Verification:** G5 validator, same-generation harness, root schema, fixed counterexamples.

Steps:

1. Freeze accepted generation identities - 3 minutes.
2. Validate C6-O04 and direct-child fingerprints - 5 minutes.
3. Run lightweight G5 only; no heavy child process - 3 minutes.
4. Validate the four independent conclusions - 5 minutes.
5. Review residual issues, failure owners, and next actions - 4 minutes.
6. Stop for human acceptance - 2 minutes.

### Task R13.2 - Final completion audit and handoff

**Duration:** 20-30 minutes.
**Files:** repository/evidence read-only; create or modify only an exact final handoff file named in a separate docs authorization.
**Acceptance:** audit covers registries, all conservation equations, fixed failure vectors, stale-input handling, source immutability, retained/quarantined outputs, redistribution constraints, and user entry/success path.
**Evidence:** final audit matrix and list of unresolved families/capabilities; no merge yet.

### Task R13.3 - Obtain exact integration authorization

**Duration:** 20-30 minutes.
**Files:** none changed until approval.
**Acceptance:** user confirms reviewed final commit/range, destination ref, integration method, conflict policy, CI/tests, whether source-derived binaries may be included, and rollback owner. The dirty source workspace `C:\SoftWork\Git\StellaGaia` remains read-only and is not switched, reset, staged, or merged by this plan.
**Evidence:** external integration approval.

### Task R13.4 - Integrate through the approved clean path

**Duration:** 20-30 minutes unless the chosen remote review/CI is an external wait.
**Files:** only Git refs and exact conflict files named by the authorization; no broad staging.
**Acceptance:** destination contains the approved commit range, CI/verification passes, source workspace user changes remain untouched, and the feature branch remains recoverable until cleanup approval.
**Verification:** commit ancestry, tree/diff scope, test results, remote ref state.

If no safe clean integration path is approved, stop and hand integration to the user. Do not create an extra worktree or modify the dirty main workspace by assumption.

### Task R13.5 - Obtain separate cleanup authorization

**Duration:** 20-25 minutes.
**Files:** read-only repository/worktree/evidence state.
**Acceptance:** merged/ref reachability is proven; worktree has no unknown tracked/untracked changes; protected-file disposition is supplied by the user; retained diagnostic/quarantine/evidence paths have explicit keep/archive/delete decisions; exact removal target is resolved.
**Evidence:** cleanup checklist and explicit target paths.

### Task R13.6 - Remove the implementation worktree and empty parent only

**Duration:** 20-25 minutes.
**Files/targets:** exactly `C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe` and, only after verified empty, its intended parent as approved.
**Acceptance:** removal is explicitly authorized, exact paths are re-resolved inside the intended workspace, protected/user files have approved disposition, branch/ref remains recoverable as specified, and no source workspace or other worktree is affected.
**Verification:** `git worktree list`, path containment, ref reachability, post-removal absence. `git worktree prune`, `git reset --hard`, and broad recursive deletion are forbidden.

After cleanup, stop. Branch deletion, tag, release, publication, or source-derived artifact distribution requires another explicit authorization if desired.

## 13. Phase Exit Matrix

| Phase | Required input | Success evidence | Does not authorize | Next exact gate |
|---|---|---|---|---|
| R7 | committed package + 12 Pending rows | 12/12 Confirmed, protected-state resolution, LO contract | source read or R8 command | R8 one-operation approval |
| R8 | exact C1 approval | conserved snapshot + human baseline decision/match | C2 | R9 contract and run approvals |
| R9 | accepted C1 + real adapter/producers/publisher | diagnostic real C2 review with SP-01..09 conserved | static/extraction/Unity | R10 lifecycle approval |
| R10 | accepted real C2 | all-lane static qualification + provisional C5/C6 | staging/repair/Unity | R11 whitelist approval |
| R11 | exact whitelist and repair cause | conserved staged batch + at most one repair/class + requalification | Unity | R12 environment/item approvals |
| R12 | C5 requests + Unity capability | immutable per-representative evidence + refreshed C5/C6 | G5 conclusion/integration | R13 G5 approval |
| R13 | accepted same-generation C6-O04 | independent G5 conclusions + audit + approved integration | cleanup/publication | separate cleanup approval |

## 14. Verification Before Any Completion Claim

At minimum, the owning Task must run and read:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
git diff --check
Get-FileHash -Algorithm SHA256 -LiteralPath .\AGENTS.md
Get-FileHash -Algorithm SHA256 -LiteralPath .\docs\superpowers\plans\2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

Then run only the stage-specific lightweight validators explicitly authorized for that Task. Heavy tests or producers require their own LO when they exceed the ordinary Task boundary. Verify these paths according to stage authority rather than deleting them:

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
currentPhase=R7
R7PackageOriginCommit=ff446c0cd55ea795e2714a5871a284f4aec584ab
executionHead=Pending exact PB-A02 confirmation
PB-SP01=12 Pending
R8ThroughR13Authorized=false
realSourceAccessed=false
phaseBExecuted=false
nextAction=User reviews this program plan, confirms the sequential approach, then supplies exact PB-A01-through-PB-A12 values and the protected-untracked disposition. Do not begin R8 automatically.
```
