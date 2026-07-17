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
- runner/module/schema/vocabulary, PB-I03 locator schema, and seven lightweight test scripts;
- Git metadata, protected hashes, and forbidden-path existence.

Writes/staging/commit/push: none. Runtime manifest, baseline, source roots/content, and output content are excluded.

## Frozen Values

| Identity | Expected version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| PersonalLocalMode package | `6eb87d15d733865b008e10180a7c319b939853f8dffb6f29461c0ecefdc7c3b0` |
| PersonalLocalMode runbook | `ab233818bef470ea0ee1ff00e6d0b2aed3bc002fa530b7ae5019932c7e677a6b` |
| Completion roadmap | `06357b2ea581132618405096bdb0c2290a191505afecb98c02894ee1d659e5ed` |
| Program Roadmap | `4932acb748bcd7565bdbca1f89343ba7df8d998493ea436ecb9b19a173c6d8d1` |
| R8.1 plan | `5112ad7201a8b5ad1da9a2a32ff736fc44b0fa51cd541f7aa83badc49ba66f36` |
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `04907242ad793f1e3aa07c49925f4ecc59091f241b381c0bb0917bc439d94f07` |
| C1-I05 schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| PB-I03 locator schema | `85a736a5b04be3b5d6a7f27cbaf645a3dafe252c0b17b1d3b48f0ff4d77f463e` |
| PersonalLocalMode policy test | `2e507defc1e4e17af2595bdcca6d5f26e5c73687e44085997a9dd7086ea4c43a` |

This plan and R7.5 are bound by their paths plus the final containing commit; no self-hash is predeclared.

Protected status is exactly the two known untracked rows with hashes `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` and `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b`.

## Registry, Partition, And Failure Checks

- PB-I01 is PersonalLocalMode derived preflight state with no compliance identity fields.
- PB-I02/PB-I03 and C1-I01 through C1-I06, C1-T01, C1-O01/C1-O02, C1-E01 appear exactly once.
- PB-I03 uses `[Environment]::GetFolderPath('LocalApplicationData')` plus `StellaGaia\PhaseB\personal-local-mode-inputs.json`, validates against the registered schema, and contains the complete declared source boundary; no `Read-Host` or arbitrary machine search remains.
- PB-SP01 through PB-SP06 appear exactly once; PB-SP01 has six derived groups and remains unevaluated before R8.1. PB-SP02/PB-SP06 prove boundary/manifest set equality in both directions.
- PB-FT01 through PB-FT12 appear exactly once.
- package/runbook/Roadmaps/R7.5/R8.1 contain no twelve-row human form.
- R8.1 owns automatic HEAD/tool/locator/boundary/manifest/baseline/output/disk derivation.
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
locatorContractIssueCount=0
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

Hash package/runbook/Roadmaps/R8 plan/tool/schema/locator-schema/policy test and compare to the table. Do not invoke scripts.

### Step 3 - Validate Registry/Partition/Failure and migration shape - 5 minutes

Count exact rows, prove PB-I01 derived semantics and PB-I03 fixed locator/source-boundary semantics, prove removal of the form/external identity fields, and cross-check automatic derivation plus one-confirmation boundary.

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
