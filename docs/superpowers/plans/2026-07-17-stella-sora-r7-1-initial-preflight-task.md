# StellaSora R7.1 Initial Package And Repository Preflight Child Task Plan

> **Status:** READY FOR SEPARATE EXECUTION AUTHORIZATION. This file was prepared under the Program Roadmap P0 docs-only bootstrap exception. Its creation does not authorize this Task, R7.2, PB-A01-PB-A12 confirmation, real manifest/source access, or R8.
>
> **Task boundary:** one read-only 20-25 minute Task with six 2-5 minute Steps. It creates no repository, source, manifest, baseline, output, log, cache, approval, or evidence file. Its only result is a conversation handoff of `RED/BLOCKED` or `GREEN/READY_FOR_R7_2_PLANNING`.

## Goal, User, And Decision

- **Target user/operator:** the human reviewer controlling the fixed implementation worktree and later Phase B approval.
- **Consumer:** the future R7.2 child-plan author and reviewer.
- **Decision enabled:** determine whether the committed R7 package, runbook, Roadmap, C1 tool/schema bytes, branch/upstream state, protected files, and forbidden paths are internally consistent enough to plan R7.2.
- **Entry:** the exact containing commit of this child plan, as reported by the P0 completion handoff, must equal `origin/codex/asset-corpus-integration` before execution authorization.
- **Success state:** all frozen values below match, PB-SP01 remains exactly `12 Pending`, no real/private input is opened, no file changes, and the only next action is to request a separate P0 docs-only authorization to create the R7.2 child plan.

GREEN does not mean Phase B is approved. It does not confirm PB-A01-PB-A12 and does not authorize R7.2 or R8.

## Authority And Frozen Values

Read these repository authorities completely before executing the Steps:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

The expected bytes at plan creation are:

| Identity | Path or version | Expected value |
|---|---|---|
| R7 package | `docs/asset-migration/source-corpus-phase-b-authorization-package.md` | SHA-256 `aec619685d1c6ca79ede953794f32a168e0c4774b901fc0ff747758aa991017f` |
| C1 runbook | `docs/asset-migration/source-corpus-phase-b-runbook.md` | SHA-256 `c80f45edb661a011d4934526c439b2fca36fc9a16e130e2239eb8ae0b494d1c9` |
| Program Roadmap | `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md` | SHA-256 `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
| PowerShell | runtime | `7.6.0` |
| Git | runtime | `2.53.0.windows.2` |
| C1-I03 | `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1` | SHA-256 `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 | `Tools/AssetImport/SourceCorpusGate.psm1` | SHA-256 `1b53fe277c18bb9d82277033581c747d277a7666b64f8139e78dcf499fe38280` |
| C1 test authority | `Tools/AssetImport/Test-SourceCorpusGate.ps1` | SHA-256 `0311107a5e099d9f74ebe8ec776d916c4139cbbae43fcdfe31875cf85af136c5` |
| C1-I05 | `docs/asset-migration/schemas/source-corpus-ledger.schema.json` | SHA-256 `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 | `docs/asset-migration/schemas/status-vocabulary.json` | SHA-256 `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |

Any mismatch is RED under PB-FT02. Do not update an expected value during this Task.

## Exact File Scope

### P0 bootstrap file created and committed before execution

- `docs/superpowers/plans/2026-07-17-stella-sora-r7-1-initial-preflight-task.md`

P0 exact staging list is only that file. P0 stops after its commit/push and does not execute this Task.

### R7.1 execution read-only files

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- this child Task plan
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`
- `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`
- `Tools/AssetImport/SourceCorpusGate.psm1`
- `Tools/AssetImport/Test-SourceCorpusGate.ps1`
- `docs/asset-migration/schemas/source-corpus-ledger.schema.json`
- `docs/asset-migration/schemas/status-vocabulary.json`
- Git metadata required by the listed read-only commands.

### R7.1 files created, modified, staged, committed, or pushed

None. The exact R7.1 staging list is empty.

### Explicitly excluded inputs and paths

- PB-I01 approval record content other than the package's current `Pending` table.
- C1-I01 runtime-only manifest identity, path, or content.
- C1-I02 baseline identity, path, or content.
- Every real StellaSora root, file, directory entry, fingerprint, or source byte.
- C1-O01/C1-O02 and all `Extracted`, import, Unity, publication, temporary, cache, log, build, quarantine, and staging outputs.

Do not use `Test-Path`, `Get-Item`, `Get-ChildItem`, `Resolve-Path`, `Get-Content`, `Get-FileHash`, or another API against an actual manifest, baseline, or source root.

## Referenced Central Definitions

### Artifact Registry

- **PB-I02:** verify package path, bytes, and containing execution-HEAD policy.
- **C1-I03 through C1-I06:** verify the registered runner, module, schema, and vocabulary bytes only; do not invoke them.
- **C1-O01/C1-O02:** verify their canonical repository-relative output root is absent; do not create or validate content.
- **PB-I01, C1-I01, C1-I02, C1-E01:** confirm they are not created, copied, opened, or claimed by this Task.

### Subject/Partition Registry

- **PB-SP01:** the complete direct subject universe for this Task. Expected state is `12 = 0 Confirmed + 12 Pending + 0 Rejected`.
- **PB-SP04:** physical pre-execution output state is `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`, represented by absence of C1-O01/C1-O02 and their canonical root.
- **PB-SP02, PB-SP03, PB-SP05:** intentionally not enumerated or evaluated because the runtime manifest, sources, files, and baseline are out of scope.

### Failure Transitions

- **PB-FT01:** a Pending/Rejected approval row keeps Phase B blocked; this is the expected current state, not permission to correct or confirm a row.
- **PB-FT02:** branch, HEAD/upstream, protected state, runtime version, package/runbook/Roadmap, tool, test, schema, or vocabulary mismatch.
- **PB-FT07:** pre-existing canonical C1 output, staging residue, or another forbidden/unknown output path; preserve it and request ownership review.
- **PB-FT12:** any real input access, unexpected process, network operation, extraction, Unity, import, publication, or unauthorized write.

No other Failure Transition owns a direct R7.1 subject. Do not infer source, baseline, conservation, or writer failures without running their later authorized operations.

## RED And GREEN

### RED/BLOCKED

Any one of these is RED:

- branch is not `codex/asset-corpus-integration`;
- HEAD differs from upstream or from the exact child-plan-containing commit authorized for execution;
- Git status contains anything except the two protected untracked files;
- a protected hash differs;
- a frozen authority/tool/schema hash or runtime version differs;
- PB-A row count/state is not exactly twelve Pending rows;
- C1-O01/C1-O02 or another forbidden path exists;
- a source/manifest/baseline is opened or a process/write outside the listed commands occurs.

RED result:

```text
status=BLOCKED
phaseBExecuted=false
nextAction=Classify the single owning PB-FT transition and request the smallest correction or reviewed package change. Do not continue to R7.2 automatically.
```

### GREEN/READY_FOR_R7_2_PLANNING

GREEN requires all of:

```text
branch=codex/asset-corpus-integration
headEqualsAuthorizedContainingCommit=true
headEqualsUpstream=true
trackedChangeCount=0
protectedUntrackedCount=2
protectedHashMismatchCount=0
frozenHashMismatchCount=0
runtimeVersionMismatchCount=0
PB-SP01=12=0+12+0
PB-SP04=2=0+2+0
forbiddenPathCount=0
realInputAccessCount=0
processLaunchCount=0
repositoryWriteCount=0
phaseBExecuted=false
```

GREEN result:

```text
status=READY_FOR_R7_2_PLANNING
nextAction=Request separate P0 docs-only authorization for one exact R7.2 child-plan path; do not execute R7.2.
```

## Task R7.1 - Initial Package And Repository Preflight

**Duration:** 22 minutes target; stop no later than 25 minutes.

### Step 1 - Verify exact Git and protected starting state - 3 minutes

Run from the fixed implementation worktree:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
```

Require the branch, exact authorized child-plan-containing commit, upstream equality, zero tracked changes, and exactly the two protected untracked paths. Do not fetch, pull, switch, reset, clean, stash, add, commit, or push.

### Step 2 - Verify runtime and C1 implementation bytes - 4 minutes

Run:

```powershell
$PSVersionTable.PSVersion.ToString()
git --version
Get-FileHash -Algorithm SHA256 -LiteralPath @(
    'Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1',
    'Tools/AssetImport/SourceCorpusGate.psm1',
    'Tools/AssetImport/Test-SourceCorpusGate.ps1',
    'docs/asset-migration/schemas/source-corpus-ledger.schema.json',
    'docs/asset-migration/schemas/status-vocabulary.json'
)
```

Compare to the frozen table. Do not invoke the runner, module, or test script. No regression process is necessary because this Task changes no implementation and asks only whether exact previously audited bytes are still present; rerunning equivalent Phase A tests would produce no new information.

### Step 3 - Verify registered package structure and PB-SP01 conservation - 5 minutes

Read only the committed package. Confirm:

- Artifact rows PB-I01/PB-I02, C1-I01 through C1-I06, C1-T01, C1-O01/C1-O02, and C1-E01 are present exactly once.
- Partition rows PB-SP01 through PB-SP05 are present exactly once.
- Failure rows PB-FT01 through PB-FT12 are present exactly once.
- PB-A01 through PB-A12 are present exactly once and all remain Pending.
- `PB-SP01: 12 = 0 + 12 + 0`.

Focused command:

```powershell
$packagePath = 'docs/asset-migration/source-corpus-phase-b-authorization-package.md'
$approvalRows = @(Select-String -LiteralPath $packagePath -Pattern '^\| PB-A\d{2} \|')
$pendingRows = @($approvalRows | Where-Object { $_.Line -match '\| Pending \|$' })
$confirmedRows = @($approvalRows | Where-Object { $_.Line -match '\| Confirmed \|$' })
$rejectedRows = @($approvalRows | Where-Object { $_.Line -match '\| Rejected \|$' })
[pscustomobject]@{
    ApprovalRowCount = $approvalRows.Count
    PendingRowCount = $pendingRows.Count
    ConfirmedRowCount = $confirmedRows.Count
    RejectedRowCount = $rejectedRows.Count
}
```

Do not edit the package or treat Pending as approval.

### Step 4 - Verify protected hashes and forbidden/output absence - 3 minutes

Run:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath @(
    'AGENTS.md',
    'docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md'
)

foreach ($path in @(
    'Extracted',
    'Assets\StellaGaia\Imported',
    'Library',
    'Temp',
    'Obj',
    'Build',
    'Builds',
    'Logs',
    'UserSettings'
)) {
    [pscustomobject]@{ Path = $path; Exists = Test-Path -LiteralPath $path }
}
```

Require protected hashes `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` and `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b`, and every `Exists` value False. An unexpected path is preserved, never deleted.

### Step 5 - Cross-check package, runbook, Roadmap, and approval state - 4 minutes

Run:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath @(
    'docs/asset-migration/source-corpus-phase-b-authorization-package.md',
    'docs/asset-migration/source-corpus-phase-b-runbook.md',
    'docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md'
)
```

Compare to the frozen table. Confirm that:

- the Roadmap still requires R7.2 changes before R7.3 commit/push, R7.4 revalidation, and R7.5 approval;
- PB-I01 has not been claimed or created by this Task;
- C1-I01/C1-I02 and real sources were not opened;
- C1-O01/C1-O02 remain physically absent and PB-SP04 is Suppressed/Suppressed;
- no approved execution HEAD exists yet for R8.

### Step 6 - Record one result and stop - 3 minutes

Repeat `git status --short --branch` and `git rev-parse HEAD`. Require end HEAD/status to equal Step 1. Report:

- start/end HEAD and upstream;
- versions and hash comparison counts;
- PB-SP01 and PB-SP04 equations;
- protected and forbidden-path results;
- the single owning PB-FT row for any RED condition;
- `realInputAccessCount=0`, `processLaunchCount=0`, `repositoryWriteCount=0`, and `phaseBExecuted=false`.

Then stop. Do not create the R7.2 child plan in the same Task.

## Verification, Staging, And Stop Checkpoint

- **Focused command:** the read-only commands embedded in Steps 1-6.
- **Necessary regression:** exact-byte verification only; no test runner is necessary or authorized because no implementation changed and Phase A equivalent evidence is current.
- **Protected-input check:** exact two SHA-256 values in Step 4.
- **Forbidden-path check:** exact nine-path list in Step 4.
- **R7.1 staging list:** empty.
- **R7.1 commit/push list:** empty.
- **Stop checkpoint:** always stop after Step 6.
- **Next action on RED:** `correction` or `reviewed package change`, selected from the owning PB-FT row.
- **Next action on GREEN:** `normal next planning action`, specifically a separately authorized P0 docs-only child plan for R7.2. It is not Phase B, Unity, or special heavy authorization.
