# StellaSora R8.1 PersonalLocalMode Automatic Preflight Task Plan

> **Status:** GOVERNANCE ONLY; R8.1 AND LO R8.C1-1 HAVE NOT RUN. R8.1 derives all preflight state locally. It has no PB-A form and no external compliance identity fields.
>
> **Human boundary:** only after R8.1 emits `ReadyForSinglePersonalLocalRun` may the user state `ConfirmPersonalLocalRun`. That one confirmation applies to one immediately following attempt. This plan never treats its own creation or R8.1 GREEN as confirmation.

## Goal, User, And Decision

- **Target user:** one local owner/operator of the machine and StellaSora inputs.
- **Decision enabled:** automatically derive whether exactly one cancellable diagnostic C1 attempt is safe to offer for confirmation.
- **Entry:** committed/pushed PersonalLocalMode governance and GREEN R7.4/R7.5 migration validation.
- **Success state:** all six PB-SP01 groups pass; a redacted derived summary is displayed; no runner/output is started; next action is one explicit confirmation or Stop.

```text
sourceReadOnly=true
fixedOutputRoot=true
attemptCount=1
foregroundCancellationAuthority=true
retryAllowed=false
C2Authorized=false
UnityAuthorized=false
extractionAuthorized=false
importAuthorized=false
```

## Exact File And Operation Scope

### Repository reads

- `AGENTS.md`;
- PersonalLocalMode package, runbook, completion roadmap, Program Roadmap, R7.4/R7.5/R8.1 plans;
- C1 runner/module/schema/vocabulary and seven lightweight test scripts;
- Git metadata for branch/HEAD/upstream/status/index/tree;
- protected files for existence/hash only.

### Machine-local reads

- runtime-only manifest shape and portable source IDs/kinds;
- baseline shape/identity state without exposing paths/fingerprints;
- source-root path metadata only: existence, reparse safety, file count and size metadata for a bounded storage estimate; no file content read or hash;
- output-volume free space and canonical ancestor metadata.

If metadata-only sizing cannot finish within the ordinary Task boundary, emit Stop. Do not start a hidden/background scan or convert it into a source-content operation.

### Writes/processes

R8.1 writes no repository or output file and does not launch the guarded runner. It may launch only the seven named lightweight test processes. Exact R8.1 staging/commit/push lists are empty.

## Frozen Repository Values

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| PersonalLocalMode package | `afb7dd58d01b2659e6b606abd32bc32708842890a6b9b418bb045c4b0e5b35b0` |
| PersonalLocalMode runbook | `b4831a1919ea04e627fc5530e1729ff3828f192a8b98ed66d785c0196a837b69` |
| Completion roadmap | `2865e1d33c5fcf82727936cb03a9d1093f40ad34f44c23ee05bfc935e89b1f58` |
| Program Roadmap | `906ac525b30a8a994d88163d1c9e00f273221e25fc18639652df569d06da6334` |
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `1b53fe277c18bb9d82277033581c747d277a7666b64f8139e78dcf499fe38280` |
| C1-I05 ledger schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| `Test-AssetCorpusContract.ps1` | `2202dfb32738eeb1397968e7d33ce6a91c1c1ae9cb1d25b218e0d09274e73f28` |
| `Test-SourceCorpusGate.ps1` | `0311107a5e099d9f74ebe8ec776d916c4139cbbae43fcdfe31875cf85af136c5` |
| `Test-SourceCorpusSnapshotFunctions.ps1` | `c7109a113685aa57a6c643a8524080d7a76a58d44a8a715f434c7b849517e1bb` |
| `Test-SourceCorpusCatalog.ps1` | `4907c69334ead448056fb99ad24a3bb9b75422ae94ed28f0c85231a9115a8c05` |
| `Test-SourceCorpusRunnerPolicy.ps1` | `3b6e13205c6dda7e2d4488a6dbba9ff06d85c58ce0e9830a291caff126107bc4` |
| `Test-SourceCorpusC0Compatibility.ps1` | `4deaed14c2a58aed63189e0f0c7e3e2e68e05b5aebdc8806ac5a06c149cf61fd` |
| `Test-SourceCorpusPersonalLocalModePolicy.ps1` | `4db581ad82f3f5b3afcf1984a070295ca6be292dad1ecf2eba3871ffc085cf10` |

This plan's own identity is its path plus containing commit; it cannot predeclare its own hash. R7.4 validates the final committed tree.

Protected status must equal exactly two untracked rows with hashes:

- `AGENTS.md`: `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d`;
- `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md`: `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b`.

## Registry, Partition, And Failure References

- **PB-I01:** in-memory/redacted PersonalLocalMode derived state; no operator identity or approval timestamp.
- **PB-I02:** current package bytes/containing HEAD.
- **C1-I01/C1-I02:** locally parsed manifest and baseline state.
- **C1-I03 through C1-I06:** automatically hashed tool/schema inputs.
- **C1-T01/C1-O01/C1-O02:** must remain absent throughout R8.1.
- **PB-SP01:** six groups; require `6 = 6 Passed + 0 Failed`.
- **PB-SP02:** manifest source set; require all ApprovedAvailable.
- **PB-SP03/PB-SP05:** not evaluated beyond metadata/baseline declaration in R8.1.
- **PB-SP04:** require `2 = 0 ValidatedDiagnostic + 2 Suppressed + 0 Quarantined`.
- **PB-FT01 through PB-FT12:** use the package table; a failed/stale group Stops and cannot be waived.

## Exact Automatic Derivation

R8.1 derives:

1. `derivedHead` and branch from Git; HEAD must equal upstream and index must be empty.
2. `derivedToolHashMismatchCount` from current versions and registered bytes.
3. `derivedManifestSourceSet` from strict C1-I01 parsing, portable IDs/kinds, local availability, complete boundary inclusion, and no network/runtime source.
4. `derivedBaselineState` as `FirstCaptureNoBaseline` or validated `ApprovedBaselinePresent`.
5. `derivedOutputBoundaryState` from fixed-root/staging absence and reparse-safe ancestors.
6. `derivedEstimatedOutputBytes` using bounded read-only file metadata count/size, without opening or hashing source files.
7. `derivedRequiredFreeSpaceBytes=max(1073741824,2*derivedEstimatedOutputBytes)` and current available output-volume space.
8. all safety flags, exact command identity, allowed foreground process, and no-retry/downstream denials.

The fixed output root is:

```text
C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1
```

## RED And GREEN

RED includes any HEAD/status/hash/version mismatch; malformed/unavailable/incomplete manifest set; unsafe path; invalid baseline; pre-existing output/staging; insufficient space; metadata sizing timeout; sensitive leak; unexpected process/write/network action; or weakened safety flag.

GREEN is exactly:

```text
mode=PersonalLocalMode
derivedHead=<current HEAD equal to upstream>
derivedToolHashMismatchCount=0
derivedManifestSourceSet=<redacted nonempty portable IDs/kinds>
derivedBaselineState=<FirstCaptureNoBaseline|ApprovedBaselinePresent>
derivedOutputBoundaryState=AbsentAndSafe
derivedRequiredFreeSpaceBytes=<positive integer>
availableFreeSpaceSatisfied=true
PB-SP01=6=6 Passed+0 Failed
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
sourceContentReadCount=0
createdOutputCount=0
guardedRunnerStartCount=0
sourceReadOnly=true
fixedOutputRoot=true
attemptCount=1
foregroundCancellationAuthority=true
retryAllowed=false
C2Authorized=false
UnityAuthorized=false
extractionAuthorized=false
importAuthorized=false
result=ReadyForSinglePersonalLocalRun
```

## Task R8.1 - Automatic Preflight

**Duration:** 24 minutes target; stop no later than 30 minutes.

### Step 1 - Derive repository, protected, version, and hash state - 4 minutes

Run Git/version/hash checks and require the exact frozen values and protected status. No user transcription.

### Step 2 - Run seven lightweight gates - 4 minutes

Run exactly the seven commands listed in the runbook. Require Passed results and no repository output/residue.

### Step 3 - Derive manifest shape and source set - 5 minutes

Strictly parse C1-I01 locally, validate portable ID/kind set, availability, complete local boundary, and safe path chains. Do not print paths or read source contents.

### Step 4 - Derive baseline, output boundary, and disk state - 5 minutes

Validate baseline state, fixed output/staging absence, ancestor safety, bounded metadata-only size estimate, formula, and available space. Stop on timeout.

### Step 5 - Derive process and safety state - 3 minutes

Require one cancellable foreground attempt, exact command, source read-only, no retry, and all downstream denials.

### Step 6 - Emit redacted result and stop - 3 minutes

Recheck HEAD/status/output absence, emit RED or `ReadyForSinglePersonalLocalRun`, and stop. Do not request confirmation inside R8.1 execution until the final result is visible.

## Single Confirmation And LO Boundary

After GREEN, the only accepted confirmation is:

```text
ConfirmPersonalLocalRun
```

It has `PersonalLocalModeConfirmationCount=1`, no form fields, and applies only to the displayed state and next attempt. Immediately recheck HEAD/status/output/disk/safety. If unchanged, start the exact guarded command from the runbook as one foreground process. The confirmation is consumed at start. No automatic retry.

## Verification And Stop

- focused verification: current hashes/state, seven gates, strict local shape/set checks, metadata-only budget, and safety vector;
- R8.1 staging/commit/push list: empty;
- protected/forbidden checks: exact protected pair; `Extracted`, imported assets, Unity/cache/build/log paths absent;
- Stop after R8.1 result; never start LO in the same ordinary Task;
- GREEN next action: wait for one `ConfirmPersonalLocalRun`;
- LO completion next action: separately planned R8.2, never C2.
