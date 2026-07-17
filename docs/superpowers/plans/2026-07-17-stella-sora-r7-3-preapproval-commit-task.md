# StellaSora R7.3 Preapproval Commit Child Task Plan

> **Status:** WAITING FOR SEPARATE EXECUTION AUTHORIZATION BINDING THIS PLAN'S EXACT CONTAINING HEAD. This plan was created under the Program Roadmap P0 docs-only bootstrap exception. Its creation does not stage or commit the pending authorization-package/runbook changes, create the R8 child plan, confirm PB-A01 through PB-A12, read a real manifest/source/baseline, or execute Phase B.
>
> **Narrow purpose:** close the already reviewed R7.2 Disposition A documentation bytes in one exact commit. This is a bootstrap-safe split of Program Roadmap Work Package R7.3; it does not claim that the remaining R8 child-plan preparation portion of that Work Package is complete.

## Goal, User, And Decision

- **Target user/operator:** the human who selected `Disposition=A` and will later review the exact R8 C1 execution HEAD.
- **Consumer:** the later R8 child-plan author and R7.4 revalidator, who need the protected-worktree exception committed and pushed before preparing the remaining pre-approval bytes.
- **Decision enabled:** determine whether the two exact R7.2 documentation amendments can be committed without including either protected untracked file or any unrelated byte.
- **Entry:** branch `codex/asset-corpus-integration`; this plan's containing HEAD equals its upstream; the only tracked worktree modifications are the frozen package and runbook bytes below; the two protected untracked files have their frozen hashes; the staging area is empty; all forbidden paths are absent.
- **Success state:** one pushed commit whose parent is this plan's authorized containing HEAD changes exactly the package and runbook to the frozen hashes, while PB-A01 through PB-A12 remain Pending, protected files remain untracked and byte-identical, and Phase B remains unexecuted.

## Authority And Frozen Inputs

Read completely before execution:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-2-clean-worktree-resolution-task.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-3-preapproval-commit-task.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

The execution authorization must name R7.3 and bind the exact commit containing this plan. A broad `授权`, earlier `Disposition=A`, R8 permission, or permission bound to any other HEAD is RED.

Expected pre-execution bytes and state:

| Identity | Expected SHA-256/state |
|---|---|
| R7 package working-tree bytes | `746f66a7948f2f1bf4612ee3781ba1b239987f291f07ef8159555d82afc80203` |
| C1 runbook working-tree bytes | `604571aa5a6b4bc05dcce35ebf9b0157bcd4cbbcd4dc7002930f228799efcb15` |
| Program Roadmap | `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
| R7.2 child plan | `65dd53a5bc14551e60439c9618bb65ca0bf49e18fb2427d1a57b7f4eee5bceb9` |
| Protected `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| Protected C2 plan | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |
| Staged path count | `0` |
| Unstaged tracked path set | exactly the package and runbook |
| Protected untracked path set | exactly the two protected paths |
| Forbidden path count | `0` |

The expected two-file patch is 37 insertions and one deletion. Semantically it adds the exact two-row protected-untracked exception to PB-I02/package and the C1 runbook, assigns every mismatch to PB-FT02, records the three protected-status counts, and changes no approval status, tool/schema identity, source kind, command, output root, budget, writer, or downstream boundary.

Any byte, status-set, branch, containing-HEAD, upstream, or semantic mismatch is PB-FT02 and RED. Do not repair it inside this Task.

## Exact File Scope

### P0 bootstrap creation

- Create, stage, commit, and push only `docs/superpowers/plans/2026-07-17-stella-sora-r7-3-preapproval-commit-task.md`.

P0 stops after this plan is pushed. It leaves the package and runbook unstaged and does not execute R7.3.

### R7.3 read-only files

- the six authority files listed above;
- Git metadata required by the listed checks;
- the two protected paths only for existence and SHA-256 verification, never content capture;
- the nine forbidden paths only for existence checks.

No runtime manifest, baseline, source root, machine-local `rootPath`, real source, C1 output, or Phase B evidence may be opened.

### R7.3 content edits

None. The two documentation files must already equal the frozen working-tree hashes. This Task only stages and commits those exact existing bytes.

### R7.3 exact staging, commit, and push list

Stage and commit exactly:

- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

Commit message:

```text
docs: close phase B R7 preapproval bytes
```

Push only the resulting current branch commit to its configured upstream. Never stage the child plan during R7.3 because P0 has already committed it. Never stage either protected untracked file.

## Referenced Central Definitions

### Artifact Registry

- **PB-I02:** owns the authorization-package bytes and the exact protected-worktree precondition being committed.
- **PB-I01:** remains absent/Pending; no approval record is created or changed.
- **C1-I01/C1-I02:** runtime manifest and baseline remain unopened.
- **C1-I03 through C1-I06:** tool/schema bytes remain unchanged and are not invoked.
- **C1-O01/C1-O02/C1-E01:** remain absent; no snapshot, output, or execution evidence is produced.

No Artifact Registry row is added. The protected pair remains a PB-I02 repository invariant, not a Phase B artifact.

### Subject/Partition Registry

- **PB-SP01:** must remain `12 = 0 Confirmed + 12 Pending + 0 Rejected`.
- **PB-SP04:** must remain `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`.
- **PB-SP02/PB-SP03/PB-SP05:** remain unevaluated because real inputs and outputs are out of scope.

The exact two protected status rows are a set-equality precondition, not a new partition.

### Failure Transitions

- **PB-FT01:** owns any attempt to treat Pending PB-A rows as approved.
- **PB-FT02:** owns wrong authorization/HEAD/upstream, hash or status mismatch, unexpected path, nonempty initial staging, wrong cached set, or commit-tree mismatch.
- **PB-FT07:** owns any forbidden/pre-existing C1 output or staging state; preserve it and stop.
- **PB-FT12:** owns any real input access, unexpected process/network action, extraction, Unity, import, publication, or unauthorized write.

## RED And GREEN

### RED

- execution authorization does not bind this plan's exact containing HEAD;
- branch or upstream differs, or containing HEAD is not upstream-equal;
- either frozen document hash or exact patch meaning differs;
- initial cached path count is nonzero;
- the worktree status set is not exactly two tracked modifications plus two protected untracked rows;
- either protected hash differs or any forbidden path exists;
- `git diff --check` or `git diff --cached --check` fails;
- the cached set, commit tree, parent, or pushed upstream differs from the exact contract;
- any real/private input is opened or Phase B operation starts.

On RED, do not mutate, unstage, restore, delete, retry, or broaden scope. Preserve state, report PB-FT02/PB-FT07/PB-FT12 as applicable, and stop for correction authorization.

### Same-Task GREEN

```text
selectedDisposition=A
startHead=this plan's exactly authorized containing HEAD
commitParent=startHead
committedPathCount=2
packageSha256=746f66a7948f2f1bf4612ee3781ba1b239987f291f07ef8159555d82afc80203
runbookSha256=604571aa5a6b4bc05dcce35ebf9b0157bcd4cbbcd4dc7002930f228799efcb15
protectedStatusEntryCount=2
protectedHashMismatchCount=0
unexpectedStatusEntryCount=0
stagedPathCount=0
PB-SP01=12=0+12+0
PB-SP04=2=0+2+0
upstreamEqualsHead=true
realInputAccessCount=0
phaseBExecuted=false
```

## Task R7.3 - Commit The Frozen Disposition A Documentation Bytes

**Duration:** 22 minutes target; stop no later than 30 minutes.

### Step 1 - Bind authorization, HEAD, branch, and status - 3 minutes

Run:

```powershell
git status --short --branch
git branch --show-current
git rev-parse HEAD
git rev-parse '@{upstream}'
git diff --cached --name-only
```

Require the exact branch, exact authorized containing HEAD, upstream equality, zero cached paths, exactly two expected tracked modifications, and exactly two protected untracked rows.

### Step 2 - Verify frozen bytes and complete two-file diff - 4 minutes

Hash the package, runbook, Roadmap, R7.2 plan, this plan, and protected pair. Run `git diff --check`, `git diff --stat`, and inspect the complete two-file unstaged diff. Require the frozen hashes, 37 insertions/one deletion, and exact protected-exception semantics. Do not edit any file.

### Step 3 - Verify registry state and forbidden-path absence - 3 minutes

Confirm PB-SP01 and PB-SP04 equations from the package without changing them. Require all of these paths absent:

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

Confirm no real input, output, process, or machine-local root was accessed.

### Step 4 - Stage only the exact two files and verify the index - 4 minutes

Run exact-path `git add` commands for the package and runbook only. Then run:

```powershell
git diff --cached --check
git diff --cached --name-only
git diff --cached --stat
git diff --cached
git status --short
```

Require the cached set to equal the two-file list, the complete cached patch to equal the pre-stage reviewed patch, and both protected paths to remain untracked with no other status row.

### Step 5 - Commit and push one exact docs commit - 5 minutes

Commit with the frozen message, verify its parent is the authorized start HEAD, verify `git diff-tree --no-commit-id --name-only -r HEAD` returns exactly the two files, then push the current branch to its configured upstream. Do not amend, merge, rebase, tag, or retry with changed bytes.

### Step 6 - Verify pushed closure, report, and stop - 3 minutes

Require HEAD equals upstream, the commit tree contains the frozen package/runbook hashes, the status set contains only the two protected untracked rows, their hashes remain frozen, staged path count is zero, and forbidden paths remain absent. Report commit/parent, exact files, registries, failure vector, protected/forbidden state, and `phaseBExecuted=false`; then stop.

## Verification, Regression, And Stop

- **Focused commands:** exact Git identity/status/diff/index/tree checks, SHA-256 checks, PB-SP01/PB-SP04 structural counts, and forbidden-path existence checks listed above.
- **Necessary regression:** no test runner. This Task changes no content and invokes no executable; equality of the reviewed unstaged patch, cached patch, commit tree, frozen hashes, and pushed upstream is the relevant regression evidence.
- **Protected-input check:** both protected paths remain untracked and byte-identical before staging, after staging, and after push; contents are never recorded.
- **Forbidden-path check:** all nine listed paths remain absent before staging and after push.
- **Exact staging list:** the package and runbook only.
- **Exact commit/push list:** the package and runbook only, in one commit with parent equal to the authorized containing HEAD.
- **Stop checkpoint:** always stop after Step 6; passing this Task does not authorize any remaining R7.3 work, R7.4, PB-A confirmation, R8, or an LO.
- **Next action on RED:** correction authorization for the classified mismatch; never automatic repair or retry.
- **Next action on GREEN:** request a new P0 docs-only authorization for the exact remaining R8 preflight child-plan path. That future ordinary Task must keep C1 preflight separate from the separately approved Special Long-Running Operation and must be committed before R7.4 exact-HEAD revalidation.
