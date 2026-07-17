# StellaSora R7.4 PersonalLocalMode Post-Change Revalidation Plan

> **Status:** GOVERNANCE REVALIDATION ONLY. This Task does not read real inputs, run tests/runner, request confirmation, or execute Phase B.

## Goal And Decision

- **Target user:** the local owner who needs one coherent PersonalLocalMode execution tree.
- **Decision enabled:** emit `ReadyForPersonalLocalModeValidation` only when package/runbook/Roadmaps/R8 plan/tool/schema/policy bytes and safety boundaries agree at one pushed HEAD.
- **Success state:** exact hashes/versions match; Registry/Partition/Failure rows conserve; old form/external identity fields are absent; no real input/process/output exists.

## Exact Scope

Read-only:

- PersonalLocalMode package and runbook;
- completion roadmap and Program Roadmap;
- this R7.4 plan, R7.5 plan, and R8.1 plan;
- runner/module/schema/vocabulary and seven lightweight test scripts;
- Git metadata, protected hashes, and forbidden-path existence.

Writes/staging/commit/push: none. Runtime manifest, baseline, source roots/content, and output content are excluded.

## Frozen Values

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| PersonalLocalMode package | `afb7dd58d01b2659e6b606abd32bc32708842890a6b9b418bb045c4b0e5b35b0` |
| PersonalLocalMode runbook | `b4831a1919ea04e627fc5530e1729ff3828f192a8b98ed66d785c0196a837b69` |
| Completion roadmap | `2865e1d33c5fcf82727936cb03a9d1093f40ad34f44c23ee05bfc935e89b1f58` |
| Program Roadmap | `906ac525b30a8a994d88163d1c9e00f273221e25fc18639652df569d06da6334` |
| R8.1 plan | `7bf6a1649176cb232f800487148081ab44af696bda960ea319a9603eec272002` |
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `1b53fe277c18bb9d82277033581c747d277a7666b64f8139e78dcf499fe38280` |
| C1-I05 schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| PersonalLocalMode policy test | `4db581ad82f3f5b3afcf1984a070295ca6be292dad1ecf2eba3871ffc085cf10` |

This plan and R7.5 are bound by their paths plus the final containing commit; no self-hash is predeclared.

Protected status is exactly the two known untracked rows with hashes `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` and `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b`.

## Registry, Partition, And Failure Checks

- PB-I01 is PersonalLocalMode derived preflight state with no compliance identity fields.
- PB-I02 and C1-I01 through C1-I06, C1-T01, C1-O01/C1-O02, C1-E01 appear exactly once.
- PB-SP01 through PB-SP05 appear exactly once; PB-SP01 has six derived groups and remains unevaluated before R8.1.
- PB-FT01 through PB-FT12 appear exactly once.
- package/runbook/Roadmaps/R7.5/R8.1 contain no twelve-row human form.
- R8.1 owns automatic HEAD/tool/manifest/baseline/output/disk derivation.
- `ConfirmPersonalLocalRun` occurs only after R8.1 GREEN and before one LO.

Safety invariants:

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

Any mismatch is PB-FT02. Unexpected output/staging is PB-FT07; any real input/process/write is PB-FT12.

## RED And GREEN

RED: wrong HEAD/upstream/status; hash/version mismatch; missing/duplicate row; old form/external identity residue; contract contradiction; protected mismatch; forbidden path; real input/process/write.

GREEN:

```text
mode=PersonalLocalMode
headEqualsUpstream=true
frozenHashMismatchCount=0
runtimeVersionMismatchCount=0
registryIssueCount=0
oldHumanFormReferenceCount=0
externalComplianceIdentityFieldCount=0
contractContradictionCount=0
PB-SP01=6 Unevaluated
PB-SP04=2=0 ValidatedDiagnostic+2 Suppressed+0 Quarantined
realInputAccessCount=0
processLaunchCount=0
repositoryWriteCount=0
phaseBExecuted=false
status=ReadyForPersonalLocalModeValidation
```

## Task R7.4 - Revalidate PersonalLocalMode Tree

**Duration:** 21 minutes target; stop no later than 25 minutes.

### Step 1 - Bind HEAD/tree/status - 3 minutes

Verify branch, HEAD/upstream, empty index, exact protected status, and expected active governance paths.

### Step 2 - Recompute frozen bytes and versions - 5 minutes

Hash package/runbook/Roadmaps/R8 plan/tool/schema/policy test and compare to the table. Do not invoke scripts.

### Step 3 - Validate Registry/Partition/Failure and migration shape - 5 minutes

Count exact rows, prove PB-I01 derived semantics, prove removal of the form/external identity fields, and cross-check automatic derivation plus one-confirmation boundary.

### Step 4 - Validate safety and forbidden state - 3 minutes

Require protected hashes and absence of `Extracted`, imported assets, Unity/cache/build/log paths.

### Step 5 - Validate state freshness - 3 minutes

Confirm no derived PB-I01 state or `ConfirmPersonalLocalRun` is carried across changed bytes; R8.1 must recompute.

### Step 6 - Emit result and stop - 2 minutes

Recheck identity/status and emit GREEN or one typed Stop. Do not run R7.5/R8.1.

## Verification And Stop

- focused evidence: Git/hash/version/row/cross-reference/protected/forbidden checks;
- no test runner because R7.5 owns the focused policy test;
- exact staging/commit/push lists: empty;
- GREEN next action: run R7.5 PersonalLocalMode validation;
- always stop before R8.1 or confirmation.
