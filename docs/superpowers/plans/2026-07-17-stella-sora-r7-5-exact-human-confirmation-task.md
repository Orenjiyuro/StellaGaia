# StellaSora R7.5 Exact Human Confirmation Child Task Plan

> **Status:** P0 PREPARATION ONLY; R7.5 IS NOT YET EXECUTABLE. This plan's creation does not confirm PB-A01 through PB-A12, create PB-I01, open a real manifest/source/baseline, execute R8.1, or authorize LO R8.C1-1.
>
> **HEAD rule:** committing this plan creates a new candidate execution HEAD. After P0 push, the existing R7.4 plan must be rerun read-only and return `ReadyForExactApproval` against this new exact HEAD before R7.5 may collect confirmation. The earlier R7.4 result on parent `b2f642dd901f6b040e6ad4b2ff735843fe4e071e` is historical evidence only.

## Goal, User, And Decision

- **Target user/operator:** the human who owns the local manifest/baseline identities, source-boundary decision, storage budget, trusted execution session, cancellation authority, logging policy, and retention decision.
- **Consumer:** R8.1 preflight, which may inspect runtime identities only after a current exact approval exists.
- **Decision enabled:** convert the twelve Pending PB-A rows into one conserved external PB-I01 record with twelve explicit Confirmed values bound to one exact pushed HEAD, or leave the complete set Pending/Rejected and Stop.
- **Entry:** this plan is committed and pushed; R7.4 has been rerun against this plan-containing HEAD and returned `ReadyForExactApproval`; the package still contains twelve Pending rows; no real input has been opened by R7.5.
- **Success state:** `PB-SP01: 12 = 12 Confirmed + 0 Pending + 0 Rejected`; every required value is concrete and internally consistent; PB-I01 remains external/redacted; no repository or machine-local artifact is written; R8.1 and LO R8.C1-1 remain unstarted.

## Exact Lifecycle Boundary

This Task records approval; it does not perform preflight or execution:

1. **R7.5:** receive and validate one exact twelve-row human confirmation record.
2. **R8.1:** separately authorized read-only runtime preflight validates PB-I01, C1-I01/C1-I02 identities, storage, and LO fields.
3. **LO R8.C1-1:** separately authorized one-attempt foreground snapshot operation.
4. **R8.2:** separately planned post-run output validation.

R7.5 GREEN cannot start R8.1 or the LO automatically. A relevant byte/HEAD/approval/runtime-identity change before the LO starts invalidates the unstarted approval and returns to preparation, R7.4, and R7.5 as required.

## Authority And Frozen Repository Inputs

Read completely before R7.5 execution:

- `AGENTS.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-4-post-change-revalidation-task.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r7-5-exact-human-confirmation-task.md`
- `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`

Frozen values the human accepts under PB-A08:

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| R7 package/PB-I02 | `746f66a7948f2f1bf4612ee3781ba1b239987f291f07ef8159555d82afc80203` |
| C1 runbook | `604571aa5a6b4bc05dcce35ebf9b0157bcd4cbbcd4dc7002930f228799efcb15` |
| Program Roadmap | `3cd87fc89a368ff0ddb78ae4868df4cf5fd6236e8c205b520c51643cec47bb9d` |
| R7.4 plan | `c062990081a8d5a6ce84c52ada6e3203d6469edd406adc4ce70eb83135f586e8` |
| R8.1 plan | `89b249e00d095f360e47261c1f87a6ab4d72229820f91b7cbca5a11aac410cf5` |
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
| Protected `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| Protected C2 plan | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

This plan's own identity is its repository-relative path plus its exact future containing commit. PB-A02 binds that pushed commit and branch; the plan cannot predeclare its own commit or SHA-256.

## Exact File And Evidence Scope

### P0 bootstrap

Create, stage, commit, and push only:

- `docs/superpowers/plans/2026-07-17-stella-sora-r7-5-exact-human-confirmation-task.md`

P0 commit message:

```text
docs: add R7.5 exact confirmation task
```

P0 stops after push. It does not rerun R7.4 or execute R7.5.

### R7.5 repository reads

- the seven authority documents listed above;
- Git metadata needed to bind branch, execution HEAD, upstream, and status;
- exact frozen hashes/versions already revalidated by current R7.4 evidence;
- protected pair only for existence/hash confirmation;
- forbidden paths only for absence confirmation.

### R7.5 external inputs

- one human response conforming to the twelve-row template below;
- opaque machine-local record identities, portable source IDs/kinds, numeric byte/duration values, booleans, timestamps, and policy-owner identifiers only.

Do not include expanded manifest/root/baseline paths, credentials, unrestricted logs, account/host/volume identifiers, source fingerprints, or source content. Canonical repository output root is contract-public and may be named exactly.

### R7.5 writes, staging, commit, and push

None. PB-I01 is the external human response plus operator identity, approval timestamp, and exact execution HEAD. R7.5 emits only a redacted row-status summary in the task response; no approval file is created in Git or on disk.

## Central Registry References

### Artifact Registry

- **PB-I01:** the external exact approval record created by the human response; identity is opaque operator identity plus approval timestamp plus execution HEAD.
- **PB-I02:** the committed authorization package and containing execution HEAD.
- **C1-I01:** runtime-only manifest identity; PB-A03 confirms the identity and portable selected source-kind/source-ID sets without exposing `rootPath`.
- **C1-I02:** immutable baseline identity when `ApprovedBaselinePresent`; absent when `FirstCaptureNoBaseline`.
- **C1-I03 through C1-I06:** exact frozen implementation/schema bytes accepted under PB-A08.
- **C1-T01/C1-O01/C1-O02/C1-E01:** remain absent and uncreated by R7.5.

No Registry row is added to a repository document. PB-I01 exists only as external approval evidence.

### Subject/Partition Registry

- **PB-SP01:** direct subject universe; require `12 = 12 Confirmed + 0 Pending + 0 Rejected`.
- **PB-SP02:** remains unevaluated by R7.5; PB-A03/PB-A04 declare the approved future manifest identity/set, but R8.1 performs local shape/availability validation.
- **PB-SP03:** unevaluated; no source file enumeration.
- **PB-SP04:** require pre-operation `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`.
- **PB-SP05:** only the declared state is frozen; actual capture comparison remains unevaluated until R8.2.

### Failure Transitions

- **PB-FT01:** any missing, Pending, Rejected, ambiguous, conditional, or inferred PB-A value; the whole operation remains blocked.
- **PB-FT02:** wrong HEAD/branch/upstream, stale R7.4, byte/version/protected mismatch, or approval record not bound to the exact current tree.
- **PB-FT03:** manifest identity/set missing, malformed, unapproved, or leaking machine-local values.
- **PB-FT04:** incomplete approved boundary, unavailable declared root, duplicate/case-unstable source ID, unapproved source kind, or network/runtime source declaration.
- **PB-FT07:** absent/invalid budget, failed free-space declaration, pre-existing output/staging, unsafe boundary, or unapproved path.
- **PB-FT12:** any real input access, process/network action, extraction, Unity, import, output creation, publication, or unauthorized write during R7.5.

PB-FT05/06/08/09/10/11 require later source/output/baseline subjects and cannot be resolved or normalized here.

## Exact Twelve-Row Confirmation Template

R7.5 requests one complete response, not twelve conversational round trips. Every row must say `Confirmed` and supply its required value. Placeholders, omitted values, `same as above`, conditional approval, broad `授权`, or inferred defaults are PB-FT01.

```text
PB-I01.operatorApprovalId=<opaque nonempty operator/role identifier>
PB-I01.approvalTimestampUtc=<ISO-8601 UTC timestamp>

PB-A01=Confirmed; operation=C1.SourceCorpusSnapshot.Refresh; attemptCount=1; diagnosticOnly=true
PB-A02=Confirmed; branch=codex/asset-corpus-integration; executionHead=<exact pushed R7.5-plan-containing HEAD>
PB-A03=Confirmed; manifestRecordId=<opaque nonempty identity>; selectedSourceKinds=[<exact subset of PcInstall,PcPatchOrCache,AndroidApk,AndroidDataOrCache>]; sourceIds=[<exact stable portable IDs>]
PB-A04=Confirmed; allAvailableApprovedBoundaryRootsIncluded=true; networkOrRuntimeSourceCount=0
PB-A05=Confirmed; baselineState=<FirstCaptureNoBaseline|ApprovedBaselinePresent>; baselineRecordId=<None or opaque immutable identity>
PB-A06=Confirmed; approvedCombinedStagedArtifactEstimateBytes=<positive integer>
PB-A07=Confirmed; requiredFreeSpaceBytes=<max(1073741824,2*PB-A06)>; availableFreeSpaceBytes=<integer >= required>; canonicalOutputExists=false; stagingResidueCount=0; unsafeReparseOrAlternateBoundaryCount=0
PB-A08=Confirmed; PowerShell=7.6.0; Git=2.53.0.windows.2; frozenHashMismatchCount=0; acceptedFrozenSet=<the complete table in this plan plus this plan-containing commit tree>
PB-A09=Confirmed; canonicalOutputRoot=C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1; alternateOutputAllowed=false; reparseAllowed=false
PB-A10=Confirmed; guardedCommandAcceptedVerbatim=true; wrapperAllowed=false; extraFlagOrCommandAllowed=false; retryAllowed=false
PB-A11=Confirmed; firstCaptureStops=true; nonmatchingOrInvalidBaselineStops=true; C2AndDownstreamAuthorized=false
PB-A12=Confirmed; trustedOperatorId=<opaque nonempty identity>; maximumRunDurationMinutes=<positive integer>; executionWindowUtc=<bounded ISO-8601 interval>; foregroundCancellationAuthority=true; sensitiveLoggingPolicyId=<opaque nonempty identity>; evidenceRetentionOwnerId=<opaque nonempty identity>; maximumRetainedOutputBytes=<positive integer>
```

For PB-A05, `FirstCaptureNoBaseline` requires `baselineRecordId=None`; `ApprovedBaselinePresent` requires a nonempty opaque immutable identity. Do not provide a path. `selectedSourceKinds` must be a nonempty exact subset of the four approved kinds with no duplicates. `sourceIds` must be nonempty, unique under `OrdinalIgnoreCase`, and preserve exact spelling/case.

PB-A10 accepts this exact command block without executing it:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$sourceRootManifestPath = Read-Host 'Approved absolute path to the machine-local source-root manifest'
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

PB-A12 supplies the R8 long-operation duration/cancellation/logging/retention fields but does not execute the LO. R8.1 must still validate the complete LO record, exact boundaries, process set, budget, and current runtime identities before a separate one-attempt LO authorization can be considered.

## RED And Same-Task GREEN

### RED/BLOCKED

- R7.4 is not current and GREEN for the exact R7.5-plan-containing HEAD;
- the human response omits any row/value, uses an invalid type/range/set, contains a Pending/Rejected/conditional value, or exposes forbidden machine-local data;
- PB-A02 differs from current branch/HEAD/upstream;
- PB-A03/PB-A04 source kinds/IDs/boundary declarations are empty, duplicate, incomplete, or network/runtime-inclusive;
- PB-A05 baseline state/identity pairing is invalid;
- PB-A06/PB-A07/PB-A12 numeric values are not positive integers or violate the formula/bounds;
- PB-A08/PB-A09/PB-A10 differs from exact frozen bytes, output root, or guarded command policy;
- PB-A11 authorizes downstream work or weakens a Stop;
- repository/protected/forbidden state changes or any excluded access/process/write occurs.

On RED, do not partially accept the record, carry forward confirmed rows, infer missing values, edit the package, or start R8. The complete PB-SP01 state remains blocked until one full replacement response passes.

### Same-Task GREEN

```text
approvalRecordIdentityPresent=true
approvalHeadEqualsCurrentHead=true
approvalHeadEqualsUpstream=true
R7_4=ReadyForExactApproval@currentHead
PB-SP01=12=12 Confirmed+0 Pending+0 Rejected
PB-SP02=DeclaredOnly; R8.1 validation Pending
PB-SP03=Unevaluated
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
PB-SP05=DeclaredOnly; capture comparison Unevaluated
approvalValueIssueCount=0
sensitiveLeakCount=0
repositoryWriteCount=0
realInputAccessCount=0
processLaunchCount=0
phaseBExecuted=false
status=ExactApprovalRecorded
```

## Task R7.5 - Obtain Exact Human Confirmation

**Duration:** 23 minutes target; stop no later than 30 minutes.

### Step 1 - Bind current HEAD and fresh R7.4 evidence - 3 minutes

Verify branch, HEAD/upstream equality, exact protected status/hashes, empty index, forbidden-path absence, and R7.4 `ReadyForExactApproval` for this exact HEAD. Require the package still has twelve Pending rows before receiving PB-I01. Do not open any runtime record.

### Step 2 - Confirm PB-A01 and PB-A02 - 3 minutes

Receive PB-I01 operator identity/timestamp. Require exactly one diagnostic operation/attempt and exact current branch/HEAD. A broad or inherited authorization is PB-FT01/02.

### Step 3 - Confirm PB-A03 through PB-A05 without paths/content - 5 minutes

Validate the opaque manifest identity, exact selected source-kind and stable source-ID sets, complete/no-network boundary declaration, and exact baseline state/identity pairing. Reject any expanded path, fingerprint, content, or missing set value.

### Step 4 - Confirm PB-A06 and PB-A07 numeric budget/boundary declarations - 4 minutes

Validate positive integer estimate, exact required-space formula, sufficient integer available space, absent output/staging, and zero unsafe boundary count. Do not inspect the output volume or create/delete paths in R7.5; R8.1 later validates the declaration locally.

### Step 5 - Confirm PB-A08 through PB-A10 exact bytes, root, and command - 4 minutes

Require exact versions, zero frozen-hash mismatch, acceptance of the complete frozen set/current tree, exact canonical output root, no alternate/reparse policy, and verbatim guarded-command restrictions. Do not recompute the frozen implementation set or execute a runner; current R7.4 evidence owns byte verification. Step 1's protected-file identity check remains required.

### Step 6 - Confirm PB-A11/PB-A12, prove conservation, and stop - 4 minutes

Validate all Stop/downstream boundaries and concrete operator, duration, window, cancellation, logging, retention, and retained-output budget values. Prove `12=12+0+0`, emit only a redacted status summary, recheck repository identity/state, and stop before R8.1.

## Verification, Evidence, Staging, And Stop

- **Focused verification:** exact current Git/protected/forbidden identity, current R7.4 evidence identity, strict parsing of one twelve-row response, type/set/formula/consistency validation, PB-SP01 conservation, and sensitive-leak review.
- **Necessary regression:** no test runner. R7.5 validates human approval data; R7.4 owns byte evidence and R8.1 owns the six runtime freshness gates.
- **Portable evidence:** approval operator role/opaque ID, timestamp, execution HEAD, twelve row statuses, selected portable kinds/IDs, numeric budget/duration results, policy identity presence, zero-leak/zero-operation assertions, and no machine paths except the canonical contract-public output root.
- **Protected-input check:** exact two protected status rows/hashes at start/end.
- **Forbidden-path check:** `Extracted`, `Assets/StellaGaia/Imported`, `Library`, `Temp`, `Obj`, `Build`, `Builds`, `Logs`, and `UserSettings` remain absent.
- **R7.5 staging/commit/push list:** empty.
- **R7.5 repository write count:** zero.
- **Stop checkpoint:** always stop after Step 6. Never continue into R8.1 or LO R8.C1-1 in the same Task.
- **Next action on RED:** replace the complete external response or return to the owning R7/PB-FT correction gate.
- **Next action on GREEN:** request separate execution authorization for R8.1 against the unchanged exact HEAD and PB-I01 identity. R8.1, not R7.5, performs local runtime preflight.
