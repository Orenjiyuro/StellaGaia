# StellaSora R7.5 PersonalLocalMode Migration Validation Plan

> **Status:** GOVERNANCE VALIDATION ONLY. The historical path is retained for roadmap continuity, but R7.5 no longer collects a human form or external compliance identity. It validates the migration and stops before R8.1.

## Goal And Decision

- **Target user:** one local owner/operator.
- **Decision enabled:** prove that the active governance set implements PersonalLocalMode consistently and that the focused policy test is GREEN.
- **Entry:** R7.4 returned `ReadyForPersonalLocalModeValidation` on the current exact HEAD.
- **Success state:** no old form/external identity fields; PB-I01 is derived state; R8.1 owns automatic checks; one confirmation remains immediately before LO; no real input/process/output.

```text
humanFormFieldCount=0
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

## Exact Scope

Read-only active governance:

- PersonalLocalMode package/runbook;
- completion roadmap and Program Roadmap;
- R7.4, this R7.5 path, and R8.1 plan;
- `docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json`;
- `Tools/AssetImport/SourceCorpusGate.psm1` reusable preflight/final-recheck implementation;
- `Tools/AssetImport/Test-SourceCorpusPersonalLocalModePolicy.ps1`;
- Git/protected/forbidden metadata.

The focused test may run. Runtime manifest, baseline, source roots/content, production runner/module, and output content remain unopened/uninvoked. R7.5 writes/stages/commits/pushes nothing.

## Frozen Values

| Identity | SHA-256 |
|---|---|
| Package | `eb433e072bb8a4c56181b65587411a063cf8e7de9363c34f1b984a3d5313b534` |
| Runbook | `e16ac550b61b0c7f90fe87e4a37827c04a644f1e2f7f4518317bc0eea4eb4c89` |
| Completion roadmap | `06357b2ea581132618405096bdb0c2290a191505afecb98c02894ee1d659e5ed` |
| Program Roadmap | `4932acb748bcd7565bdbca1f89343ba7df8d998493ea436ecb9b19a173c6d8d1` |
| R7.4 plan | `7b2005b7f4366fe5825dd701bb792f197b1cbaaefb31c3c9862bff46728a74e8` |
| R8.1 plan | `f298fd0a9f569dcbce600462c354a31d0c989b802559bafd896da4f601497af6` |
| Locator schema | `85a736a5b04be3b5d6a7f27cbaf645a3dafe252c0b17b1d3b48f0ff4d77f463e` |
| C1-I04 module | `ea863ec25d3d0d6f2595fc2a32430589f353558426bd0ce81f7c6eee5ca4befe` |
| Policy test | `507efb1c395cd3a82638ee7d6763b29c0275ab142a685378af8090cd86d9ad69` |

This plan is bound by path plus final containing commit and cannot predeclare its own hash.

## Registry, Partition, Failure, And Confirmation Boundary

- **PB-I01:** R8.1 in-memory/redacted derived preflight state; no user identity/timestamp/compliance fields.
- **PB-I02/PB-I03/C1-I01 through C1-I06/C1-T01/C1-O01/C1-O02/C1-E01:** package definitions remain unique. PB-I03 automatically resolves from LocalAppData and freezes the complete declared source boundary; no prompt remains.
- **PB-SP01:** six automatic preflight groups, unevaluated before R8.1; later require `6=6 Passed+0 Failed`.
- **PB-SP02/PB-SP06:** boundary and manifest rows conserve independently and require exact bidirectional equality. PB-SP03 through PB-SP05 retain source-file/output/baseline semantics.
- **PB-FT01 through PB-FT12:** all failures remain typed; none can be waived by confirmation.
- **Confirmation:** `ConfirmPersonalLocalRun`, exactly once after R8.1 GREEN and before one LO; no form fields.
- **Shared implementation:** R8.1 and the final recheck both invoke C1-I04 `Invoke-SourceCorpusPersonalLocalModePreflight`; five synthetic vectors guard schema-derived vocabulary, APK file roots, boundary mismatch, final-state drift, and zero output.

## RED And GREEN

RED: stale R7.4; wrong HEAD/status/hash; old form/external identity residue; missing fixed locator/schema/boundary definition; interactive path prompt; missing bidirectional set conservation; missing derived responsibility; legacy second-run authorization; missing safety invariant; more than one confirmation; focused test failure; protected/forbidden drift; real input/process/output.

GREEN:

```text
mode=PersonalLocalMode
humanFormFieldCount=0
externalComplianceIdentityFieldCount=0
derivedPreflightGroupCount=6
fixedInputLocatorContractCount=1
sourceBoundaryConservationCount=2
PersonalLocalModeConfirmationCount=1
policyTestStatus=Passed
policySemanticVectorCount=7
realInputAccessCount=0
productionProcessLaunchCount=0
createdOutputCount=0
phaseBExecuted=false
status=ReadyForR8.1AutomaticPreflight
nextAction=RunR8.1AutomaticPreflight
```

## Task R7.5 - Validate Migration

**Duration:** 23 minutes target; stop no later than 30 minutes.

### Step 1 - Bind current R7.4 result and governance bytes - 3 minutes

Verify current HEAD/upstream/status, protected state, frozen hashes, and R7.4 GREEN identity.

### Step 2 - Prove form and external identity removal - 4 minutes

Require zero old rows/identity fields in package/R7.4/R7.5/R8.1 and no substitute multi-field approval form.

### Step 3 - Validate automatic derivation ownership - 5 minutes

Require R8.1 ownership of HEAD, hashes, fixed PB-I03 location/schema, declared boundary/manifest equality, baseline, fixed output boundary, metadata-only disk estimate, and free-space validation.

### Step 4 - Validate Registry/Partition/Failure conservation - 4 minutes

Require unique rows, PB-I01 derived shape, PB-I03 exact shape/location, six PB-SP01 groups, PB-SP02/PB-SP06 bidirectional conservation, unchanged PB-SP03–05, and complete PB-FT table.

### Step 5 - Validate one-confirmation and safety boundary - 4 minutes

Require `ConfirmPersonalLocalRun` only after GREEN; one attempt, source read-only, cancellable foreground process, no retry, and downstream denials.

### Step 6 - Run focused policy test and stop - 3 minutes

Run `pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusPersonalLocalModePolicy.ps1`. Require Passed with all seven locator/boundary semantic vectors and zero real-input/process/output counts. Emit GREEN/Stop and do not start R8.1.

## Verification And Stop

- focused test plus Git/hash/protected/forbidden checks;
- no C1 functional regression here; production code is unchanged and R8.1 later runs seven lightweight gates;
- exact staging/commit/push lists: empty;
- GREEN next action: separately run R8.1 automatic preflight;
- no human confirmation is requested during R7.5.
