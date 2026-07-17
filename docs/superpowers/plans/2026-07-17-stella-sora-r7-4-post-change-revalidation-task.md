# StellaSora R7.4 Post-Change Revalidation Child Task Plan

> **Status:** WAITING FOR SEPARATE EXECUTION AUTHORIZATION BINDING THIS PLAN'S EXACT PUSHED CONTAINING HEAD. This plan is created under the Program Roadmap P0 docs-only bootstrap exception. P0 creation does not execute R7.4, confirm PB-A01 through PB-A12, open real inputs, run R8.1, or authorize LO R8.C1-1.
>
> **Task boundary:** one read-only 21-minute revalidation. It proves that the pushed HEAD containing the amended package/runbook and R8.1 plan is internally ready for exact human approval. It creates no repository or machine-local evidence file and launches no test, runner, source, Unity, extraction, or publication process.

## Goal, User, And Decision

- **Target user/operator:** the human who will supply the external PB-I01 record and later control one C1 operation.
- **Consumer:** the R7.5 exact-approval Task and the future R8.1 preflight operator.
- **Decision enabled:** emit `ReadyForExactApproval` only if every committed pre-approval byte, version, registry row, command boundary, protected invariant, and absence condition agrees at one exact pushed HEAD.
- **Entry:** this plan's P0 commit has parent `54b7fb76ab1a93e7a682c54ea614e9aac26ace22`, is pushed to `origin/codex/asset-corpus-integration`, and is the exact HEAD named by the separate R7.4 execution authorization.
- **Success state:** R7.1's complete read-only checks pass against the new bytes; the R8 plan is present in the execution tree; PB-SP01 remains 12 Pending; PB-SP04 remains two Suppressed outputs; PB-I01 and all real inputs remain unopened/absent; result is `ReadyForExactApproval`, never an approval or execution permit.

## Authority And Frozen Values

Read completely before execution:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-1-initial-preflight-task.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-4-post-change-revalidation-task.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

Frozen repository bytes and versions:

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| R7 package/PB-I02 | `746f66a7948f2f1bf4612ee3781ba1b239987f291f07ef8159555d82afc80203` |
| C1 runbook | `604571aa5a6b4bc05dcce35ebf9b0157bcd4cbbcd4dc7002930f228799efcb15` |
| Program Roadmap | `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
| R8.1 child plan | `89b249e00d095f360e47261c1f87a6ab4d72229820f91b7cbca5a11aac410cf5` |
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `1b53fe277c18bb9d82277033581c747d277a7666b64f8139e78dcf499fe38280` |
| C1-I05 ledger schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 status vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| `Test-AssetCorpusContract.ps1` | `2202dfb32738eeb1397968e7d33ce6a91c1c1ae9cb1d25b218e0d09274e73f28` |
| `Test-SourceCorpusGate.ps1` | `0311107a5e099d9f74ebe8ec776d916c4139cbbae43fcdfe31875cf85af136c5` |
| `Test-SourceCorpusSnapshotFunctions.ps1` | `c7109a113685aa57a6c643a8524080d7a76a58d44a8a715f434c7b849517e1bb` |
| `Test-SourceCorpusCatalog.ps1` | `4907c69334ead448056fb99ad24a3bb9b75422ae94ed28f0c85231a9115a8c05` |
| `Test-SourceCorpusRunnerPolicy.ps1` | `3b6e13205c6dda7e2d4488a6dbba9ff06d85c58ce0e9830a291caff126107bc4` |
| `Test-SourceCorpusC0Compatibility.ps1` | `4deaed14c2a58aed63189e0f0c7e3e2e68e05b5aebdc8806ac5a06c149cf61fd` |

This R7.4 plan's own identity is its repository-relative path plus its exact future containing commit; it cannot predeclare its own SHA or containing commit. Execution authorization must bind the exact pushed commit reported by P0. Any mismatch is PB-FT02 and Stop.

Protected paths and hashes:

| Path | Required SHA-256 |
|---|---|
| `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md` | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

The complete accepted `git status --short` set at R7.4 start and end is exactly those two `??` rows and no others.

## Exact File And Operation Scope

### P0 bootstrap

Create, stage, commit, and push only:

- `docs/superpowers/plans/2026-07-17-stella-sora-r7-4-post-change-revalidation-task.md`

P0 commit message:

```text
docs: add R7.4 post-change revalidation task
```

P0 stops after push. It does not perform the revalidation defined below.

### R7.4 read-only paths

- the seven authority documents listed above;
- `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`;
- `Tools/AssetImport/SourceCorpusGate.psm1`;
- the six frozen test scripts listed in the table;
- `docs/asset-migration/schemas/source-corpus-ledger.schema.json`;
- `docs/asset-migration/schemas/status-vocabulary.json`;
- Git metadata for identity/tree/status checks;
- the protected pair only for existence/hash verification;
- the nine forbidden paths only for existence checks.

### R7.4 excluded paths and operations

- PB-I01 external record content, except proving no approval predates the current bytes;
- C1-I01 manifest identity/path/content and C1-I02 baseline identity/path/content;
- any real StellaSora root, directory entry, source byte, fingerprint, or machine-local `rootPath`;
- C1-O01/C1-O02/C1-E01 content;
- every runner/test invocation, source scan, snapshot, output/staging creation, Unity, extraction, import, publication, network action, merge, or cleanup.

### R7.4 writes, staging, commit, and push

None. The exact execution staging/commit/push lists are empty. The only output is a conversation result.

## Central Registry References

### Artifact Registry

- **PB-I02:** verify the package path, exact committed bytes, protected-worktree exception, and execution-HEAD policy.
- **PB-I01:** must be absent/unclaimed for the new byte set; any earlier approval is stale and cannot be carried forward.
- **C1-I01/C1-I02:** remain unopened and unevaluated.
- **C1-I03 through C1-I06:** verify exact registered paths and bytes only; do not invoke them.
- **C1-T01/C1-O01/C1-O02:** require canonical staging/output state absent; do not create or inspect content.
- **C1-E01:** remains absent; R7.4 produces no execution handoff.

The R8.1 plan is a governance input contained in the exact execution tree, not a new C1 Artifact Registry row.

### Subject/Partition Registry

- **PB-SP01:** require `12 = 0 Confirmed + 12 Pending + 0 Rejected`.
- **PB-SP04:** require `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`, evidenced only by absent C1-O01/C1-O02 root.
- **PB-SP02/PB-SP03/PB-SP05:** intentionally unevaluated because manifest, sources, source files, and baseline are out of scope.

### Failure Transitions

- **PB-FT01:** twelve Pending approvals are the expected state; any claim of approval blocks R7.4 until a current-byte approval workflow is reviewed.
- **PB-FT02:** wrong branch/HEAD/upstream/tree, unexpected status, protected mismatch, version/hash mismatch, missing/duplicate registry row, stale approval, or command/plan disagreement.
- **PB-FT07:** pre-existing canonical output/staging or another forbidden/unknown path; preserve and stop.
- **PB-FT12:** real input access, process launch, network action, extraction, Unity, import, publication, or unauthorized write.

No other PB-FT row owns a direct R7.4 subject. Do not infer manifest, source, writer, baseline, or output validation results.

## Required Contract Cross-Checks

The package, runbook, Roadmap, and R8 plan must agree on all of these without byte changes:

1. operation identity is exactly `C1.SourceCorpusSnapshot.Refresh`;
2. approved source kinds are exactly `PcInstall`, `PcPatchOrCache`, `AndroidApk`, and `AndroidDataOrCache`;
3. runtime manifest C1-I01 remains machine-local and has exact schema version/shape rules;
4. canonical output root is exactly `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1` beneath the fixed worktree;
5. output and `.c1-staging-*` state are absent before operation and unknown state is never cleaned by preflight;
6. budget is a positive approved estimate with `requiredFreeSpaceBytes=max(1073741824,2*estimate)`;
7. only the verbatim foreground `pwsh ... -RefreshSnapshot` command is eligible for later authorization;
8. one operation, one attempt, positive duration/storage, foreground cancellation, no retry, rollback/quarantine/retention, sensitive-log policy, and no downstream stage are frozen before LO;
9. R8.1 is ordinary preflight only; LO R8.C1-1 and R8.2 are independent later stages;
10. first capture and baseline mismatch always Stop; C2 remains unauthorized.

Any contradiction is PB-FT02. Do not amend a contract inside this Task.

## RED And Same-Task GREEN

### RED/BLOCKED

- execution authorization does not bind this plan's exact pushed containing HEAD;
- branch is not `codex/asset-corpus-integration`, HEAD differs from upstream, or P0 parent is not the frozen R8-plan commit;
- status differs from the exact protected two-row set or either protected hash differs;
- any frozen byte/version differs or a required path/row is missing/duplicated;
- PB-SP01 is not exactly twelve Pending or PB-SP04 is not exactly two Suppressed outputs;
- a current PB-I01 approval is claimed before this revalidation closes;
- package/runbook/Roadmap/R8-plan command, budget, sensitive-data, LO, Stop, or downstream boundaries disagree;
- any forbidden path exists or excluded input/process/write occurs.

On RED, report one owning PB-FT transition, preserve state, and stop. Do not repair, edit expected values, run tests, clean paths, or continue to R7.5.

### Same-Task GREEN

```text
branch=codex/asset-corpus-integration
headEqualsAuthorizedContainingCommit=true
headEqualsUpstream=true
R8PlanPresentInHead=true
trackedChangeCount=0
protectedStatusEntryCount=2
protectedHashMismatchCount=0
unexpectedStatusEntryCount=0
frozenHashMismatchCount=0
runtimeVersionMismatchCount=0
registryMissingOrDuplicateCount=0
contractContradictionCount=0
PB-SP01=12=0 Confirmed+12 Pending+0 Rejected
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
forbiddenPathCount=0
realInputAccessCount=0
processLaunchCount=0
repositoryWriteCount=0
phaseBExecuted=false
status=ReadyForExactApproval
```

## Task R7.4 - Revalidate The Exact Pushed Execution HEAD

**Duration:** 21 minutes target; stop no later than 25 minutes.

### Step 1 - Bind exact HEAD, upstream, tree, and protected state - 3 minutes

Run `git status --short --branch`, `git branch --show-current`, `git rev-parse HEAD`, `git rev-parse '@{upstream}'`, and `git diff --cached --name-only`. Require the exact authorized plan-containing HEAD, upstream equality, empty index, exact two protected status rows, and no tracked changes. Verify this plan's commit parent is `54b7fb76ab1a93e7a682c54ea614e9aac26ace22` and the R8 plan exists in the HEAD tree.

### Step 2 - Recompute every frozen byte and runtime version - 5 minutes

Run PowerShell/Git version checks and SHA-256 checks for the package, runbook, Roadmap, R8 plan, runner, module, six test scripts, schema, vocabulary, and protected pair. Compare only to the frozen table. Do not invoke any script/module or update a hash.

### Step 3 - Revalidate Registry, Partition, Failure, and command identities - 5 minutes

Read the package/runbook/Roadmap/R8 plan. Require each Artifact row PB-I01/PB-I02, C1-I01 through C1-I06, C1-T01, C1-O01/C1-O02, and C1-E01 once; PB-SP01 through PB-SP05 once; PB-FT01 through PB-FT12 once; PB-A01 through PB-A12 once and all Pending. Perform all ten contract cross-checks above and require no contradiction.

### Step 4 - Recheck protected and forbidden/output state - 3 minutes

Recompute protected hashes. Check only existence of `Extracted`, `Assets/StellaGaia/Imported`, `Library`, `Temp`, `Obj`, `Build`, `Builds`, `Logs`, and `UserSettings`; require all absent. Preserve any unexpected path and Stop.

### Step 5 - Prove approval freshness boundary - 3 minutes

Confirm the current package still declares every PB-A row Pending and no PB-I01 identity is claimed for the new HEAD. Record that only a future R7.5 approval may bind this exact pushed byte set; no earlier approval survives a relevant byte change. Do not access an external approval record, manifest, or baseline.

### Step 6 - Repeat end identity, emit one result, and stop - 2 minutes

Repeat HEAD/upstream/status/index checks. Require no state change. Emit the GREEN vector or one typed RED result with the owning PB-FT row, then stop before R7.5 or R8.1.

## Verification, Evidence, Staging, And Stop

- **Focused commands:** read-only Git identity/tree/status/index, version output, exact SHA-256 checks, structural row counts, contract cross-reference review, and nine-path existence checks.
- **Necessary regression:** no test runner. R7.4 verifies exact previously audited bytes and newly committed governance consistency; R8.1 later runs the six lightweight freshness gates. Repeating them here would not answer a new R7.4 question.
- **Protected-input check:** exact two status rows and frozen SHA-256 values at Task start/end.
- **Forbidden-path check:** the exact nine-path set above, all absent.
- **Portable evidence:** exact HEAD/upstream, hashes/versions, row counts/partition equations, contradiction count, protected counts, forbidden count, and zero-operation assertions; never machine-local paths/content.
- **R7.4 staging/commit/push list:** empty.
- **R7.4 repository write count:** zero.
- **Stop checkpoint:** always stop after Step 6; GREEN is readiness for approval, not approval.
- **Next action on RED:** smallest correction or reviewed contract change under the owning PB-FT row.
- **Next action on GREEN:** request P0 docs-only authorization for a separate R7.5 exact-human-confirmation child Task plan. Do not confirm PB-A rows or execute R8.1 automatically.
