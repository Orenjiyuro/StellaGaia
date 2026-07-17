# StellaSora R7.2 Clean-Worktree Resolution Child Task Plan

> **Status:** WAITING FOR SEPARATE EXECUTION AUTHORIZATION WITH AN EXACT DISPOSITION. This plan was created under the Program Roadmap P0 docs-only bootstrap exception. Its creation does not execute R7.2, change the package/runbook, disposition protected files, confirm PB-A01-PB-A12, or authorize R8.
>
> **Required execution authorization:** the human must bind the exact child-plan-containing HEAD and state exactly `Disposition=A` or `Disposition=B`. A bare `授权`, broad Phase B permission, or an omitted disposition is RED and does not start the Task.

## Goal, User, And Decision

- **Target user/operator:** the human owner of the two protected untracked files and the later C1 Phase B approval.
- **Consumer:** the R7.3 child-plan author, who needs one unambiguous clean-worktree contract before preparing the R8 execution child plan.
- **Decision enabled:** resolve the conflict between the C1 runbook's zero-change precondition and the required protection of two known untracked files, without touching real inputs or executing Phase B.
- **Entry:** R7.1 completed GREEN at commit `a77a1d340eb9b94a00f247847cde99dc328b903e`; execution must instead bind this R7.2 plan's exact containing commit and matching upstream.
- **Success state:** exactly one disposition is selected and satisfied, no source/manifest/baseline/output is accessed, the R8 long-operation policy remains Pending but structurally intact, and the Task stops for R7.3 planning.

## Disposition Choice

### Disposition A - Narrow package/runbook amendment - Recommended

Retain both protected untracked files byte-identically. Modify exactly the R7 package and C1 runbook so the Phase B preflight accepts one exact worktree-status set:

```text
?? AGENTS.md
?? docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

The amendment freezes both paths and hashes, requires zero other status rows, maps any absence/addition/hash mismatch to PB-FT02, and preserves the rule that neither file may be staged, committed, edited, deleted, moved, or treated as Phase B evidence.

- **Benefit:** honors the existing protection contract without requiring user filesystem action.
- **Cost:** changes PB-I02/runbook bytes, so R7.3 must later commit them with the R8 child plan, R7.4 must revalidate the new HEAD/hashes, and R7.5 must obtain a fresh exact approval.

### Disposition B - User-managed external disposition

Before Task execution, the user personally moves or otherwise dispositions both protected files outside this worktree and supplies an exact external statement that the action was intentional. The implementation agent performs read-only verification only.

- **Benefit:** preserves the runbook's literal zero-change precondition without a package/runbook amendment.
- **Cost:** requires user action outside this Task. The agent may not move, delete, rename, copy, overwrite, or otherwise disposition either file.

If Disposition B is authorized while either protected path is still present, the result is RED/BLOCKED; do not fall back to A automatically.

## Authority And Frozen Inputs

Read completely before execution:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-1-initial-preflight-task.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

Expected pre-execution bytes:

| Identity | Expected SHA-256 |
|---|---|
| R7 package | `aec619685d1c6ca79ede953794f32a168e0c4774b901fc0ff747758aa991017f` |
| C1 runbook | `c80f45edb661a011d4934526c439b2fca36fc9a16e130e2239eb8ae0b494d1c9` |
| Program Roadmap | `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
| R7.1 child plan | `b1e6d351c337fadc55a184fb7be03a8a048858f4d6c67991eb8d5949c3b23360` |
| Protected `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| Protected C2 plan | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

R7.1's accepted result is:

```text
status=READY_FOR_R7_2_PLANNING
PB-SP01=12=0 Confirmed+12 Pending+0 Rejected
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
trackedChangeCount=0
protectedUntrackedCount=2
forbiddenPathCount=0
realInputAccessCount=0
repositoryWriteCount=0
phaseBExecuted=false
```

Any authority hash, branch, containing HEAD, upstream, or R7.1 evidence mismatch is PB-FT02 and RED.

## Exact File Scope

### P0 bootstrap file

- Create and commit only `docs/superpowers/plans/2026-07-17-stella-sora-r7-2-clean-worktree-resolution-task.md`.

P0 stops after this plan is pushed. It does not execute either disposition.

### R7.2 read-only files for both dispositions

- the five authority files listed above;
- Git metadata required by the listed read-only checks;
- the two protected paths only as permitted below;
- no runtime manifest, baseline, source root, or Phase B output.

### R7.2 modified files under Disposition A only

- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

No other tracked or untracked path may change. Both protected paths remain read-only and byte-identical.

### R7.2 modified files under Disposition B

None. The user's already-completed external disposition is observed but not performed by the agent.

### R7.2 staging, commit, and push lists

Empty for both dispositions. R7.2 leaves any authorized A-path docs changes unstaged for the separately planned R7.3 commit. R7.2 never stages or commits the protected files.

## Referenced Central Definitions

### Artifact Registry

- **PB-I02:** owns the authorization package bytes and, under Disposition A, the exact protected-worktree precondition embedded in those bytes.
- **PB-I01:** remains absent/Pending; R7.2 does not create or update an approval record.
- **C1-I01/C1-I02:** runtime manifest and baseline remain unopened.
- **C1-I03 through C1-I06:** remain unchanged and are not invoked.
- **C1-O01/C1-O02/C1-E01:** remain absent; no execution handoff is produced.

Disposition A adds no Artifact Registry row. The protected worktree is a PB-I02 pre-execution invariant, not a Phase B input or portable artifact.

### Subject/Partition Registry

- **PB-SP01:** must remain `12 = 0 Confirmed + 12 Pending + 0 Rejected`.
- **PB-SP04:** must remain `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`.
- **PB-SP02/PB-SP03/PB-SP05:** remain unevaluated because manifest, source files, and baseline are out of scope.

The exact worktree status is a set-equality precondition, not a new subject partition: A requires the two exact protected rows and no others; B requires an empty status set. PB-FT02 owns any mismatch.

### Failure Transitions

- **PB-FT01:** PB-A01-PB-A12 remain Pending; no confirmation occurs.
- **PB-FT02:** missing/ambiguous disposition, wrong branch/HEAD/upstream, authority/protected hash mismatch, wrong worktree-status set, or unexpected file change.
- **PB-FT07:** forbidden/pre-existing C1 output or staging state; preserve it and stop.
- **PB-FT12:** any manifest/source/baseline access, unexpected process/network action, extraction, Unity, import, publication, or unauthorized write.

## Exact Disposition A Amendment Contract

If and only if the execution authorization states `Disposition=A`, make these semantic changes without changing any other policy:

1. In PB-I02 package content, add a section named `Exact Protected Untracked Worktree Exception`.
2. Freeze the two repository-relative paths and lowercase SHA-256 values from this plan.
3. Define the accepted start/end `git status --short` set as exactly the two `??` rows above, with Ordinal path comparison and zero additional rows.
4. State that the exception applies only to C1 preflight status; it does not make either file an input, output, approval, evidence artifact, staging candidate, or commit candidate.
5. State that missing, extra, renamed, modified, staged, tracked, conflicted, or differently hashed rows are PB-FT02 and Stop before source access.
6. Update the package preflight/acceptance evidence to record `protectedStatusEntryCount=2`, `unexpectedStatusEntryCount=0`, and both hash matches without copying file contents.
7. Replace the runbook's literal zero-change sentence with the exact two-row exception and PB-FT02 ownership; retain zero tolerance for every other worktree change.
8. Do not change PB-A statuses, tool/schema hashes, source kinds, command, output root, budgets, writer policy, or downstream boundaries.

Run `git diff --check` and inspect the complete two-file diff. Do not stage or commit it.

## RED And GREEN

### Common RED conditions

- authorization does not state exactly A or B;
- containing HEAD/upstream or authority bytes mismatch;
- R7.1 GREEN evidence cannot be reproduced from repository state;
- PB-SP01 or PB-SP04 changes;
- a forbidden path exists;
- any real/private input is opened;
- a file outside the selected disposition's exact scope changes.

### Disposition A GREEN

```text
selectedDisposition=A
packageModified=true
runbookModified=true
otherTrackedChangeCount=0
protectedStatusEntryCount=2
protectedHashMismatchCount=0
unexpectedStatusEntryCount=0
PB-SP01=12=0+12+0
PB-SP04=2=0+2+0
diffCheckPassed=true
stagedPathCount=0
phaseBExecuted=false
nextAction=Request P0 authorization for the exact R7.3 child-plan path.
```

### Disposition B GREEN

```text
selectedDisposition=B
packageModified=false
runbookModified=false
trackedChangeCount=0
worktreeStatusEntryCount=0
userDispositionEvidencePresent=true
PB-SP01=12=0+12+0
PB-SP04=2=0+2+0
stagedPathCount=0
phaseBExecuted=false
nextAction=Request P0 authorization for the exact R7.3 child-plan path.
```

## Task R7.2 - Resolve The Protected-Untracked/Clean-Worktree Conflict

**Duration:** 24 minutes target; stop no later than 30 minutes.

### Step 1 - Bind HEAD and one exact disposition - 3 minutes

Run read-only Git checks and compare the containing commit with the authorization:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
```

Require exactly one authorization token: `Disposition=A` or `Disposition=B`. Missing, broad, conflicting, or multiple choices are PB-FT02 and Stop.

### Step 2 - Revalidate R7.1 evidence and authority bytes - 4 minutes

Hash the package, runbook, Roadmap, and R7.1 child plan against the frozen table. Confirm PB-SP01 is twelve Pending rows, PB-SP04 outputs are absent, and all nine forbidden paths are absent. Do not rerun C1 tests or open real inputs.

### Step 3 - Apply only the selected disposition - 5 minutes

For A:

- hash both protected files before editing docs;
- modify only the package and runbook according to the eight-point amendment contract;
- do not modify or stage either protected file.

For B:

- require both protected paths already absent because of explicit user action;
- require `git status --short` otherwise empty;
- record only the external disposition statement identity, not file contents or former external paths;
- make no repository change.

Never switch from one branch to the other after seeing a failure.

### Step 4 - Verify the R8 long-operation policy remains Pending and intact - 4 minutes

Confirm the package still requires, but does not supply or approve:

- trusted operator identity;
- positive integer `maximumRunDurationMinutes`;
- execution window and foreground cancellation authority;
- sensitive logging and evidence-retention owner;
- exact one-operation/no-retry command boundary;
- storage estimate and free-space formula.

PB-A01-PB-A12 must remain Pending. Do not fill any value or create PB-I01.

### Step 5 - Verify exact final scope and safety - 5 minutes

For A, run `git diff --check`, inspect the complete two-file diff, require exactly those two tracked modifications plus the two protected untracked rows, and recompute protected hashes.

For B, require zero tracked/untracked status rows and no repository diff.

For both, require forbidden-path count zero, C1-O01/C1-O02 absent, staged path count zero, and no source/process/output activity.

### Step 6 - Report one disposition result and stop - 3 minutes

Report start/end HEAD, selected disposition, authority hashes, exact status/diff paths, PB-SP01/PB-SP04 equations, protected/disposition evidence, forbidden paths, staged path count, and `phaseBExecuted=false`.

Stop. Do not create the R7.3 plan, stage A-path changes, commit, push, confirm PB-A rows, or start R8.

## Verification, Regression, Staging, And Stop

- **Focused commands:** read-only Git/hash/status checks, exact package-row counts, `git diff --check`, and complete selected-scope diff inspection.
- **Necessary regression:** no test runner. R7.2 changes only docs contract language; exact structural cross-reference and diff review provide the new information. R7.4 later performs the post-commit frozen-byte revalidation.
- **Protected-input check:** A requires both frozen hashes before and after; B requires user-completed absence and external disposition evidence.
- **Forbidden-path check:** `Extracted`, `Assets/StellaGaia/Imported`, `Library`, `Temp`, `Obj`, `Build`, `Builds`, `Logs`, `UserSettings` must all be absent.
- **Exact staging list:** empty.
- **Exact commit/push list:** empty.
- **Stop checkpoint:** always stop after Step 6.
- **Next action on RED:** correction or renewed disposition authorization; never automatic fallback.
- **Next action on GREEN:** P0 docs-only authorization for `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md` as the R7.3 child plan. Do not execute R7.3 automatically.
