# StellaSora R8.1 C1 Snapshot Preflight Child Task Plan

> **Status:** P0 PREPARATION ONLY; R8.1 IS BLOCKED UNTIL R7.4 REVALIDATION AND R7.5 EXACT PB-I01 APPROVAL. This file's historical Roadmap path contains an ordinary preflight Task only. It does not run `-RefreshSnapshot`, inspect real source contents, create C1 outputs, or authorize LO R8.C1-1.
>
> **P0 boundary:** creation, validation, exact one-file commit, and push of this plan are authorized separately from execution. After P0, stop. Do not execute R8.1, obtain PB-A confirmations, or start the C1 operation in the same turn.

## Goal, User, Scenario, And Decision

- **Target user/operator:** the human owner of the local StellaSora inputs, runtime-only manifest, optional immutable baseline, storage budget, trusted execution window, cancellation authority, and retention decision.
- **Consumer:** the separately authorized operator of exactly one future `LO R8.C1-1` C1 snapshot attempt.
- **Scenario:** prove that one exact pushed repository state, one external PB-I01 approval, one runtime-only manifest identity, one baseline state, one canonical output boundary, and one long-operation record are mutually consistent before any real source enumeration or output creation.
- **Entry:** this plan is committed and pushed; R7.4 has revalidated its exact containing HEAD and all frozen bytes; R7.5 has produced one external PB-I01 record with PB-A01 through PB-A12 Confirmed against that same HEAD; the worktree contains only the two protected untracked rows.
- **Decision enabled:** emit either `ReadyForOneC1Attempt` for one separately authorized foreground LO or a typed Stop owned by PB-FT01 through PB-FT12.
- **R8.1 success state:** all repository, approval, manifest-identity/shape, baseline-state, storage, command, process, sensitive-path, and LO-record checks pass; no source file is enumerated or hashed; no C1 output/staging path is created; the Task stops before the guarded command.

## Phase Boundaries

This plan separates three lifecycle stages:

1. **R8.1 ordinary preflight:** the only executable Task defined here; maximum 30 minutes; no guarded runner invocation.
2. **LO R8.C1-1:** one separately approved foreground `-RefreshSnapshot` attempt; not an ordinary Task and not authorized by creation or execution of this plan.
3. **R8.2 post-run validation:** a later child Task that reads C1-O01/C1-O02 without reopening source content; not defined or authorized here.

R8.1 GREEN is a prerequisite, not permission to start the LO. Any change after R7.5 to the execution HEAD, package, runbook, this plan, runner, module, schema, vocabulary, preflight gates, command, versions, PB-I01, manifest identity, baseline identity, budget, output boundary, or LO fields invalidates the unstarted operation and returns to the owning preparation/revalidation/approval gate.

## Authority And Frozen Repository Inputs

Read completely before R8.1 execution:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`
- `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`
- `Tools/AssetImport/SourceCorpusGate.psm1`
- `docs/asset-migration/schemas/source-corpus-ledger.schema.json`
- `docs/asset-migration/schemas/status-vocabulary.json`
- the six preflight gate scripts listed below.

Expected committed bytes and versions:

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| R7 package | `746f66a7948f2f1bf4612ee3781ba1b239987f291f07ef8159555d82afc80203` |
| C1 runbook | `604571aa5a6b4bc05dcce35ebf9b0157bcd4cbbcd4dc7002930f228799efcb15` |
| Program Roadmap | `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
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

This plan's identity is its repository-relative path plus the exact future containing commit. R7.4 and PB-I01 must bind that pushed commit; this file cannot predeclare its own containing commit.

Protected repository invariant:

| Path | Required SHA-256 |
|---|---|
| `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md` | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

At R8.1 start and end, `git status --short` must equal exactly:

```text
?? AGENTS.md
?? docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

Require `protectedStatusEntryCount=2`, `protectedHashMismatchCount=0`, and `unexpectedStatusEntryCount=0`. Neither protected file is an input, output, evidence artifact, staging candidate, or commit candidate.

## Exact R8.1 File And Data Scope

### P0 plan creation

Create, stage, commit, and push only:

- `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`

P0 commit message:

```text
docs: add R8 C1 snapshot preflight task
```

### R8.1 repository reads

- the authority and frozen repository inputs listed above;
- Git metadata needed to prove branch, HEAD, upstream, index, and status identity;
- the two protected paths only for existence and SHA-256 checks;
- the canonical output/staging ancestor chain only for existence, volume, ownership, and reparse-point checks.

### R8.1 machine-local reads after R7.5 only

- **PB-I01:** exact external approval record identity and PB-A01 through PB-A12 values;
- **C1-I01:** runtime-only manifest identity and strict JSON shape; locally verify source IDs, selected source-kind set, absolute `rootPath` shape, availability, approved-boundary inclusion, and no network/runtime source without printing or copying paths or content;
- **C1-I02:** either the approved immutable baseline identity and strict shape or the explicit state `FirstCaptureNoBaseline`.

R8.1 may inspect path metadata needed for availability and boundary checks. It must not enumerate, read, hash, copy, transform, or record any real source file. Expanded manifest paths, `rootPath` values, source fingerprints, user/host/account/volume identifiers, and unrestricted logs remain machine-local and must not appear in Git, screenshots, shared logs, or portable evidence.

### R8.1 writes, staging, commit, and push

None. R8.1 emits a redacted result in the task response only. It creates no repository file, machine-local snapshot, output root, staging directory, baseline, or approval record.

## Central Registry References

### Artifact Registry

- **PB-I01:** external exact approval record; all twelve PB-A rows must be Confirmed against the exact execution HEAD before C1-I01 is opened.
- **PB-I02:** the committed authorization package; its containing execution HEAD must match PB-I01.
- **C1-I01:** runtime-only manifest with top level exactly `schemaVersion`, `sources`, version `1.0.0`, and source rows exactly `sourceId`, `sourceKind`, `rootPath`.
- **C1-I02:** optional machine-local immutable baseline with top level exactly `schemaVersion`, `inputFingerprint`, `sources`, version `1.0.0`, and source rows exactly `sourceId`, `sourceKind`, `rootFingerprint`.
- **C1-I03 through C1-I06:** exact runner, module, ledger schema, and vocabulary bytes frozen above.
- **C1-T01:** same-volume `.c1-staging-<32 lowercase hex GUID>`; must be absent before R8.1 and is not created here.
- **C1-O01/C1-O02:** exact future canonical ledger and summary; both must be absent before R8.1 and remain absent afterward.
- **C1-E01:** future redacted execution handoff; not created by preflight.

No Registry row is created or mutated by R8.1.

### Subject/Partition Registry

- **PB-SP01:** require `12 = 12 Confirmed + 0 Pending + 0 Rejected` before opening C1-I01.
- **PB-SP02:** every C1-I01 source row partitions into ApprovedAvailable or InvalidOrUnavailable; require `manifestSourceCount = approvedAvailableCount + invalidOrUnavailableCount` and `invalidOrUnavailableCount=0` without exposing identities or paths in portable evidence.
- **PB-SP03:** remains unevaluated because R8.1 does not enumerate source files.
- **PB-SP04:** before the LO, require `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`; C1-O01 and C1-O02 are absent.
- **PB-SP05:** record only the approved declared state `FirstCaptureNoBaseline` or `ApprovedBaselinePresent`; the actual one-capture partition remains unevaluated until R8.2.

Approved source-kind vocabulary is exactly `PcInstall`, `PcPatchOrCache`, `AndroidApk`, and `AndroidDataOrCache`. PB-I01 must freeze the exact selected subset and stable source-ID set. A locally available approved-boundary root may not be silently omitted.

### Failure Transition Table

- **PB-FT01:** any Pending/Rejected/missing/ambiguous PB-A row; Stop before C1-I01 access.
- **PB-FT02:** branch, HEAD/upstream, protected status, version, hash, plan/package identity, or approval binding mismatch.
- **PB-FT03:** manifest missing, malformed, unapproved, or leaking machine-local values.
- **PB-FT04:** unavailable root, duplicate/case-unstable identity, unapproved kind, reparse point, symlink, junction, boundary violation, or incomplete approved set.
- **PB-FT07:** pre-existing canonical output, unknown staging residue, invalid/absent budget, insufficient free space, or unapproved path.
- **PB-FT08:** reserved for interruption/publication state during the later LO; any pre-existing ambiguous state blocks R8.1.
- **PB-FT12:** unexpected process/network action, source content access, extraction, decoding, Unity, import, publication, or unauthorized write.

PB-FT05, PB-FT06, PB-FT09, PB-FT10, and PB-FT11 require a capture/output/comparison subject and therefore cannot become GREEN or be normalized during R8.1. Any evidence suggesting such a subject already exists is unexpected state and Stop.

## Frozen Operation, Output, Budget, And LO Boundary

Operation identity:

```text
C1.SourceCorpusSnapshot.Refresh
```

Canonical output root:

```text
C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1
```

The output root and every `.c1-staging-*` sibling must be absent. Existing ancestors must be owned, expected, and free of reparse points, symlinks, or junctions. Unknown/pre-existing state is preserved and classified PB-FT07; R8.1 has no cleanup authority.

Budget formula:

```text
requiredFreeSpaceBytes = max(1073741824, 2 * approvedCombinedStagedArtifactEstimateBytes)
```

PB-A06 must supply a positive integer estimate. PB-A07 must prove available output-volume free space meets the formula. R8.1 may not infer, lower, or replace the estimate.

Guarded command, review-only during R8.1:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$sourceRootManifestPath = Read-Host 'Approved absolute path to the machine-local source-root manifest'
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

Do not run that block in R8.1. No wrapper, alternate path/flag, callback, background launcher, watchdog, transcript, extra command, or retry is permitted.

Before LO R8.C1-1 can receive a separate execution authorization, one external LO record must freeze:

1. exactly one operation identity and one attempt;
2. exact execution HEAD, working directory, runner/module/schema/vocabulary/preflight-gate bytes and versions;
3. PB-I01, C1-I01, C1-I02 state/identity, approved source-kind/source-ID sets, and canonical read/write boundaries;
4. a positive integer `maximumRunDurationMinutes`, execution window, and trusted operator with foreground cancellation authority;
5. the positive integer approved estimate, required-free-space result, and maximum retained-output/storage budget;
6. allowed process set: one foreground `pwsh` runner and only the registered runner's bounded child-process contract;
7. progress/checkpoint behavior, Stop conditions, no retry, staging `finally` behavior, rollback, quarantine, retention, and unknown-state preservation;
8. expected C1-O01/C1-O02/C1-E01 classes and the sensitive-data leak policy.

If any LO field is absent or changes after R8.1, `ReadyForOneC1Attempt` is stale and the LO remains unauthorized.

## RED And Same-Task GREEN

### RED

- R7.4 is not GREEN or PB-I01 is absent, stale, mismatched, or not 12/12 Confirmed;
- execution authorization does not bind this plan's exact containing HEAD;
- any frozen repository byte/version or protected invariant differs;
- any of the six lightweight gates fails or creates an output;
- C1-I01/C1-I02 state, selected kinds/IDs, availability, boundary, or sensitive-data handling fails;
- canonical output/staging state exists or the budget/free-space/reparse policy fails;
- the LO record is incomplete, ambiguous, or permits more than one operation/attempt;
- any real source file is enumerated/read/hashed or any unexpected process/write/network action occurs.

On RED, emit the owning PB-FT ID, preserve existing state, make no repair, cleanup, retry, approval substitution, or command change, and stop.

### Same-Task GREEN

```text
R7_4=ReadyForExactApproval
PB-SP01=12=12 Confirmed+0 Pending+0 Rejected
PB-SP02=manifestSourceCount=approvedAvailableCount+0 InvalidOrUnavailable
PB-SP03=Unevaluated
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
PB-SP05=DeclaredOnly; capture comparison Unevaluated
protectedStatusEntryCount=2
protectedHashMismatchCount=0
unexpectedStatusEntryCount=0
lightweightGatePassedCount=6
canonicalOutputExists=false
stagingResidueCount=0
requiredFreeSpaceSatisfied=true
LORecordComplete=true
realSourceFileAccessCount=0
createdOutputCount=0
guardedRunnerStartCount=0
realSourceProcessCount=0
ReadyForOneC1Attempt=true
phaseBExecuted=false
```

## Task R8.1 - Exact Preflight For One C1 Operation

**Duration:** 23 minutes target; stop no later than 30 minutes.

### Step 1 - Bind execution authority and repository identity - 3 minutes

Require an exact R8.1 execution authorization naming this plan's pushed containing HEAD. Verify branch, HEAD/upstream equality, empty index, exact protected status set/hashes, exact authority bytes/versions, and absent forbidden paths. Require R7.4 GREEN evidence for the same HEAD.

### Step 2 - Validate PB-I01 and six lightweight gates - 4 minutes

Without opening C1-I01, require PB-I01 identity and `PB-SP01: 12=12+0+0` against the execution HEAD. Run exactly:

```powershell
pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case All
```

Require six Passed/zero-issue results, `createdOutputCount=0`, compatibility `childProcessCount=1`, and `heavyChildProcessCount=0`. These are synthetic/fixture gates, not real-source validation.

### Step 3 - Validate runtime identities and approved boundary - 5 minutes

Only after Step 2 GREEN, inspect C1-I01 locally without printing/copying path or contents. Validate strict shape/version, unique and case-stable source IDs, approved source-kind subset, exact PB-I01 identity sets, absolute available roots, complete approved-boundary inclusion, no network/runtime source, and safe path chains. Validate C1-I02 state/identity and strict shape when present. Do not enumerate or read source files.

### Step 4 - Validate output, storage, and sensitive-path safety - 4 minutes

Require canonical output and staging siblings absent, ancestors safe and non-reparse, approved estimate a positive integer, free space at least the frozen formula, and no unknown residue. Confirm trusted console/logging/transcription/history policy prevents portable disclosure. Do not create or clean any path.

### Step 5 - Freeze command, process, time, cancellation, and retention fields - 4 minutes

Compare the review-only guarded command verbatim. Validate all eight LO-record groups, one attempt, one foreground process, positive duration/storage bounds, operator-controlled cancellation, no retry, rollback/quarantine/retention ownership, and output/leak policy. Do not start the command.

### Step 6 - Recheck end identity, emit result, and stop - 3 minutes

Recheck HEAD/upstream, empty index, exact protected status/hashes, absent outputs/staging/forbidden paths, zero real-source access, zero guarded-runner/real-source processes, and unchanged approval/manifest/baseline/LO identities. Emit `ReadyForOneC1Attempt` or one typed Stop and stop.

## Verification, Evidence, Staging, And Stop

- **Focused verification:** exact Git/hash/version/status checks, six listed lightweight gates, local strict PB-I01/C1-I01/C1-I02 identity/shape checks, boundary/reparse/output/staging existence checks, free-space formula, and LO-record completeness review.
- **Necessary regression:** the six lightweight gates only. Do not rerun the fresh R6 completion audit because it is equivalent historical product evidence and would not validate the new local approval state.
- **Portable evidence:** containing HEAD, frozen hashes/versions, PB-A row statuses, selected source kinds and source IDs only when approved for redacted evidence, count equations, budget result without volume identity, command identity with expanded manifest path redacted, LO field presence, Stop/Ready result, and zero-operation assertions.
- **Forbidden portable evidence:** manifest/root paths, source fingerprints before capture, user/host/account/volume identifiers, local tool-install paths, unrestricted stdout/stderr, credentials, or record contents.
- **Protected-input check:** both protected paths/hashes and exact two-row status set at Task start and end.
- **Forbidden-path check:** `Extracted`, `Assets/StellaGaia/Imported`, `Library`, `Temp`, `Obj`, `Build`, `Builds`, `Logs`, and `UserSettings` are absent at R8.1 start and end.
- **R8.1 staging/commit/push list:** empty.
- **R8.1 repository write count:** zero.
- **R8.1 Stop checkpoint:** always stop after Step 6. Never continue into LO R8.C1-1 in the same Task or turn.
- **Next action after P0 plan creation:** request P0 authorization for a separate R7.4 post-change revalidation child plan; do not execute R8.1 yet.
- **Next action after R8.1 RED:** correction/reapproval at the owning R7/PB-FT gate; no automatic retry.
- **Next action after R8.1 GREEN:** wait for a separate exact LO R8.C1-1 execution authorization binding the unchanged HEAD, PB-I01 identity, Ready result, complete LO record, and one-attempt command. R8.1 GREEN alone does not execute Phase B.
