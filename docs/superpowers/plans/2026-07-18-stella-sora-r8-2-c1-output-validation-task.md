# StellaSora R8.2 C1 Output And Operational-State Validation Task Plan

> **Status:** EXECUTION PLAN ONLY. This plan does not itself open C1-O01/C1-O02, validate the completed attempt, approve a baseline, authorize C2, rerun C1, or modify any generated output.
>
> **Execution boundary:** R8.2 is one separately authorized 20–30 minute read-only Task. It validates the already completed single C1 attempt at execution HEAD `49c8cbd4700ced2b5d537dbfa15f894d319613d0`. It never reopens source-file content and never starts a producer, snapshot, extraction, Unity, import, repair, retry, or second run.

## Goal, User, And Decision

- **Target user:** the local owner who must decide whether the completed first C1 capture is a validated diagnostic candidate for R8.3 human baseline review.
- **Decision enabled:** emit `ReadyForR8.3FirstCaptureReview` only if C1-O01/C1-O02 are exact, conserved, fingerprint-valid, path-safe, free of machine-private projection, and consistent with the recorded operation state.
- **Success state:** both outputs are `ValidatedDiagnostic`; the one baseline subject is `FirstCaptureCandidate`; C2 and every downstream operation remain denied.
- **Failure state:** preserve the outputs as `Quarantined` or `Suppressed` according to PB-FT05 through PB-FT12, emit one typed Stop, and perform no cleanup or retry.

The current capture is a first capture with no approved baseline. Therefore even a GREEN R8.2 result stops for R8.3 human review and never means baseline match or C2 authorization.

## Authority And Frozen Operation Identity

Authority order:

1. repository `AGENTS.md`;
2. `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`;
3. `docs/asset-migration/source-corpus-phase-b-authorization-package.md`;
4. `docs/asset-migration/source-corpus-phase-b-runbook.md`;
5. `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md` R8.2;
6. `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`;
7. this child Task plan.

Recorded R8.1/LO identity:

```text
mode=PersonalLocalMode
operation=C1.SourceCorpusSnapshot.Refresh
executionHead=49c8cbd4700ced2b5d537dbfa15f894d319613d0
executionBranch=codex/asset-corpus-integration
derivedInputLocatorIdentitySha256=3e6e7b30496afe559157e1e08a6099e5642fee7865c6018a83e2af0cb294854f
derivedManifestIdentitySha256=7e6dfc60cf46b8a2d8ed887a88b0bf750be33f647647a8c153fc0667b7fd8ea8
declaredRootCount=3
sourceFileMetadataCount=15984
sourceByteMetadataTotal=32402761224
derivedBaselineState=FirstCaptureNoBaseline
PersonalLocalModeConfirmationCount=1
guardedRunnerStartCount=1
runnerExitCode=0
retryCount=0
```

Frozen execution bytes:

| Identity | SHA-256 |
|---|---|
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `ea863ec25d3d0d6f2595fc2a32430589f353558426bd0ce81f7c6eee5ca4befe` |
| C1-I05 ledger schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| actual-output validator | `0311107a5e099d9f74ebe8ec776d916c4139cbbae43fcdfe31875cf85af136c5` |

This plan is bound by its path plus its final containing commit. The R8.2 validation HEAD may contain this docs-only plan commit and must equal its upstream. That later docs-only HEAD does not rewrite the closed operation identity above.

## Exact Scope And Access Boundary

Read-only repository inputs:

- the authority documents listed above;
- `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`;
- `Tools/AssetImport/SourceCorpusGate.psm1`;
- `Tools/AssetImport/Test-SourceCorpusGate.ps1`;
- `docs/asset-migration/schemas/source-corpus-ledger.schema.json`;
- `docs/asset-migration/schemas/status-vocabulary.json`;
- Git HEAD/upstream/status/index/tree and protected-file hashes.

Read-only operation inputs:

- `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` as C1-O01;
- `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-summary.json` as C1-O02;
- fixed PB-I03 and its located manifest for exact end-identity hashing only, without printing paths or contents;
- process-termination and filesystem metadata needed to account for the approved output root and staging siblings.

Forbidden reads and actions:

- no source-file content open, hash, decode, extraction, or semantic inspection;
- no arbitrary machine search and no source-root discovery outside PB-I03;
- no baseline creation, mutation, approval, comparison, or relocation;
- no output rewrite, normalization, quarantine move, deletion, or cleanup;
- no runner/module writer invocation, snapshot, retry, C2, Unity, import, or publication;
- no unrestricted output dump, absolute machine path, root path, user/host/account/volume identity, or credential projection.

R8.2 writes, staging, commit, and push lists are exactly empty.

## Central Definition 1: Artifact Registry Projection

R8.2 uses the package registry without inventing a parallel model:

| ID | R8.2 validation and success identity | Failure handling |
|---|---|---|
| PB-I01 | recorded R8.1 redacted state and exact identities above | any missing/stale identity is PB-FT01/PB-FT02 |
| PB-I03 | fixed locator bytes, hashed locally without path projection | changed/malformed identity is PB-FT03 |
| C1-I01 | manifest bytes located only through PB-I03 and hashed locally | changed/malformed identity is PB-FT03/PB-FT04 |
| C1-I03–C1-I06 | frozen runner/module/schema/vocabulary bytes | mismatch is PB-FT02 |
| C1-T01 | no `.c1-staging-*` sibling remains | residue is PB-FT08 and is preserved |
| C1-O01 | exact output path, strict JSON object, schema 1.0.0, content SHA-256 computed during R8.2 | invalid output is non-consumable `Q` under PB-FT09 |
| C1-O02 | exact output path, exact writer-contract summary, content SHA-256 computed during R8.2 | invalid output is non-consumable `Q` under PB-FT09 |
| C1-E01 | in-memory redacted R8.2 handoff with the exact shape below | no portable/private path or unrestricted log is retained |

Exact C1-E01 R8.2 shape:

```text
status
mode
operation
executionHead
validationHead
ledgerSha256
summarySha256
snapshotId
inputFingerprint
sourceCount
sourceFileCount
catalogedFileCount
explicitlyExcludedFileCount
sourceBytes
catalogedBytes
explicitlyExcludedBytes
schemaIssueCount
fingerprintIssueCount
conservationIssueCount
sensitiveProjectionIssueCount
filesystemDeltaIssueCount
endIdentityIssueCount
sourceImmutabilityState
PersonalLocalModeConfirmationCount
guardedRunnerStartCount
runnerExitCode
retryCount
PBSP03
PBSP04
PBSP05
failureType
C2Authorized
UnityAuthorized
extractionAuthorized
importAuthorized
nextAction
```

No expanded path, per-file row, source root, host/user identity, or unrestricted validator output belongs in C1-E01.

## Central Definition 2: Subject/Partition Conservation

- **PB-SP03 source files:** the complete declared source-file universe is partitioned into `Cataloged` and `ExplicitlyExcluded`. Require both:

```text
sourceFileCount = catalogedFileCount + explicitlyExcludedFileCount
sourceBytes = catalogedBytes + explicitlyExcludedBytes
```

  Every ledger file belongs to exactly one registered source, every `(sourceId, relativePath)` is unique under the frozen contract, and every per-source count/byte total independently conserves.

- **PB-SP04 output artifacts:** exactly C1-O01 and C1-O02. GREEN requires:

```text
2 = 2 ValidatedDiagnostic + 0 Suppressed + 0 Quarantined
```

  Any post-write schema/fingerprint/identity/projection failure instead requires:

```text
2 = 0 ValidatedDiagnostic + 0 Suppressed + 2 Quarantined
```

- **PB-SP05 baseline state:** exactly one subject. The recorded state is `FirstCaptureNoBaseline`; GREEN R8.2 therefore requires:

```text
1 = 0 ApprovedMatch + 1 FirstCaptureCandidate + 0 MismatchOrInvalid
```

  R8.2 does not approve or create the baseline.

- **PB-SP02/PB-SP06:** use the recorded R8.1 `3=3+0` boundary/manifest result and require unchanged locator/manifest identities. R8.2 does not rebuild these universes or reopen source content.

## Central Definition 3: Failure Transitions

| Failure | Stable R8.2 condition | Output vector and next action |
|---|---|---|
| PB-FT01 | recorded R8.1/LO handoff missing or stale | preserve outputs; `Stop`, no validation claim |
| PB-FT02 | validation HEAD/upstream/protected state or frozen repository byte mismatch | preserve outputs; `Stop` |
| PB-FT03 | PB-I03/manifest end identity missing, malformed, changed, or leaked | preserve outputs; `Stop` |
| PB-FT04 | recorded source set cannot be attributed uniquely | preserve outputs; `Stop` |
| PB-FT05 | recorded LO source access/hash failure | `S,S`; not applicable to an exit-0 output unless contradictory evidence appears |
| PB-FT06 | any global or per-source file/byte/fingerprint conservation failure | `Q,Q`; preserve outputs; `Stop` |
| PB-FT07 | output is outside the fixed root or another unexpected output exists | `Q,Q`; preserve all state; `Stop` |
| PB-FT08 | staging residue, partial move, or unexplained filesystem delta | `Q,Q`; preserve residue; `Stop` |
| PB-FT09 | JSON/schema/writer-contract/fingerprint/identity/sensitive-projection failure | `Q,Q`; preserve outputs; `Stop` |
| PB-FT10 | baseline claims conflict with `FirstCaptureNoBaseline` | `Q,Q`; preserve outputs; `Stop` |
| PB-FT11 | all output checks pass and no baseline exists | `D,D` plus `FirstCaptureCandidate`; `ReadyForR8.3FirstCaptureReview` |
| PB-FT12 | unexpected process/network/source write/extraction/Unity/import or source immutability cannot be supported without reopening source content | preserve non-sensitive evidence; `Stop` |

No failure authorizes cleanup, expected-value edits, a retry, C2, or another stage.

## Validation Semantics And Fixed Counterexamples

### Shape, fingerprint, and summary authority

Run the existing actual-output gate against the fixed C1 files:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = Join-Path (Get-Location).Path "Extracted\Threads\$threadId\C1"
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1 `
    -LedgerPath (Join-Path $outputRoot 'source-corpus-ledger.json') `
    -SummaryPath (Join-Path $outputRoot 'source-corpus-summary.json')
```

Require `status=Passed`, `positiveFixtureCount=2`, `negativeFixtureCount=4`, and `childProcessCount=0`. Then load both JSON documents once with duplicate-property-safe parsing and invoke the C1-I04 writer-contract validator in module scope, read-only, to independently prove exact shapes, portable paths, source/input fingerprints, summary recomputation, and machine-data exclusion. Do not call `Write-SourceCorpusOutputs`.

### Recorded preflight and operation closure

Require:

```text
sourceCount=3
sourceFileCount=15984
sourceBytes=32402761224
PersonalLocalModeConfirmationCount=1
guardedRunnerStartCount=1
runnerExitCode=0
retryCount=0
```

Require C1-O01 and C1-O02 to share exact `snapshotId`, `generatedAt`, and `inputFingerprint`; recompute every source root fingerprint from ledger rows and the input fingerprint from ledger source rows using C1-I04 canonical byte framing. No source root is reopened.

### Downstream-denial and first-capture semantics

The first-capture baseline state controls the next action. C1-O01/C1-O02 must not be consumable as C2 authorization. Any `nextAllowedAction`, status, or projection that tells a consumer to proceed to C2 before R8.3 baseline review is a PB-FT09 contract contradiction and produces `Q,Q`, even if the generic Phase-A writer validator accepts that string. R8.2 may not hide or override the contradiction only in C1-E01.

GREEN requires the effective next action to be exactly `ReadyForR8.3FirstCaptureReview`, with all downstream flags false.

### Source-immutability boundary

R8.2 may prove only `NoObservedSourceWrite` from all of the following together:

1. frozen C1-I03/C1-I04 bytes and their reviewed read-only source boundary;
2. one exit-0 foreground runner, no retry, and no unexpected process/network action;
3. exact locator/manifest end identities unchanged from R8.1;
4. ledger/summary count and byte totals equal the immediate preflight metadata totals;
5. no output or transaction path exists outside the approved C1 root.

This is not a cryptographic post-run re-hash of source roots. If the Task cannot support `NoObservedSourceWrite` without claiming stronger evidence or reopening source content, emit PB-FT12 `SourceImmutabilityUnprovable` and Stop.

Fixed counterexamples that must fail closed during the actual Task:

- missing/extra/duplicate/unknown JSON properties;
- duplicate or case-conflicting source IDs and `(sourceId, relativePath)` rows;
- null/empty/missing/unknown enum or identity values;
- stale root/input fingerprint after one ledger-row mutation;
- global conservation passing while one per-source partition fails;
- summary and ledger with different snapshot, time, fingerprint, count, or byte totals;
- rooted/UNC/file-URI path, `rootPath`, credential-like field, host/user/volume identity, or unrestricted log text in either portable output;
- output directory containing anything other than the two registered files, or any `.c1-staging-*` residue;
- unchanged bytes paired with a C2-authorizing `nextAllowedAction` during first capture;
- any attempt to infer `ApprovedMatch` from file existence or exit code.

## RED And GREEN

RED is any typed failure above, any need to reopen source content, or any requirement to weaken validation after seeing output.

GREEN is exactly:

```text
status=ReadyForR8.3FirstCaptureReview
mode=PersonalLocalMode
schemaIssueCount=0
fingerprintIssueCount=0
conservationIssueCount=0
sensitiveProjectionIssueCount=0
filesystemDeltaIssueCount=0
endIdentityIssueCount=0
sourceCount=3
sourceFileCount=15984
sourceBytes=32402761224
sourceImmutabilityState=NoObservedSourceWrite
PersonalLocalModeConfirmationCount=1
guardedRunnerStartCount=1
runnerExitCode=0
retryCount=0
PB-SP03=15984 Cataloged+ExplicitlyExcluded with exact count/byte conservation
PB-SP04=2=2 ValidatedDiagnostic+0 Suppressed+0 Quarantined
PB-SP05=1=0 ApprovedMatch+1 FirstCaptureCandidate+0 MismatchOrInvalid
C2Authorized=false
UnityAuthorized=false
extractionAuthorized=false
importAuthorized=false
nextAction=RunSeparatelyAuthorizedR8.3FirstCaptureReview
```

## Task R8.2 - Validate Completed C1 Attempt

**Duration:** 24 minutes target; stop no later than 30 minutes.

### Step 1 - Bind operation and validation identities - 3 minutes

Verify validation branch/HEAD/upstream, protected hashes, empty index, frozen execution bytes, completed foreground process identity, and the exact recorded R8.1/LO state. Confirm the approved C1 root and its two named files exist without opening their contents. Stop on any mismatch.

### Step 2 - Validate C1-O01/C1-O02 shape and fingerprints - 5 minutes

Run `Test-SourceCorpusGate.ps1` once against the actual fixed files. Strictly parse both files, compute their content SHA-256 identities, invoke the C1-I04 writer-contract validator read-only, and require exact schema/summary/fingerprint closure. Preserve all output on failure.

### Step 3 - Prove count/byte and source conservation - 5 minutes

Recompute global and per-source PB-SP03 partitions from C1-O01/C1-O02 only. Compare the result to the recorded preflight `3 / 15984 / 32402761224` state and require exact snapshot/time/input-fingerprint agreement. Do not reopen source roots.

### Step 4 - Validate sensitive projection and downstream denial - 4 minutes

Recursively reject machine paths, private identifiers, `rootPath`, credentials, unrestricted logs, and any C2-authorizing next action. Emit only portable counts, hashes, source IDs/kinds, issue counts, and typed status.

### Step 5 - Explain filesystem delta and operational state - 4 minutes

Require exactly the approved C1 directory and two registered output files, no staging sibling, no imported assets/Unity/cache/build/log paths, unchanged locator/manifest identities, one consumed confirmation, one runner start, exit 0, and zero retries. Derive `NoObservedSourceWrite` only under the bounded definition above.

### Step 6 - Emit one redacted result and stop - 3 minutes

Emit the exact C1-E01 R8.2 shape. GREEN stops at `ReadyForR8.3FirstCaptureReview`; otherwise emit one PB-FT typed Stop. Do not start R8.3, create a baseline, request another confirmation, or authorize C2.

## Verification, Git Boundary, And Stop

Required verification during R8.2:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
git diff --check
Get-FileHash -Algorithm SHA256 -LiteralPath @(
    '.\AGENTS.md',
    '.\docs\superpowers\plans\2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md',
    '.\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1',
    '.\Tools\AssetImport\SourceCorpusGate.psm1',
    '.\Tools\AssetImport\Test-SourceCorpusGate.ps1',
    '.\docs\asset-migration\schemas\source-corpus-ledger.schema.json',
    '.\docs\asset-migration\schemas\status-vocabulary.json'
)
```

The fixed PB-I03 and located manifest are hashed locally without path/content projection. `Extracted` is now an expected, attempt-owned R8 artifact root; all other pre-R9 forbidden paths remain absent. The R8.2 Task stages, commits, pushes, writes, deletes, moves, and cleanup actions are all empty.

Stop after the result. A GREEN R8.2 permits only a separately authorized R8.3 first-capture human review. A RED R8.2 preserves all evidence for correction/review. Neither result authorizes C2, a retry, or a second C1 run.
