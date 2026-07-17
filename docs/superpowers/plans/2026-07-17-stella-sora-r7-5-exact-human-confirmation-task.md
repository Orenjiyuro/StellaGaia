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
- `Tools/AssetImport/Test-SourceCorpusPersonalLocalModePolicy.ps1`;
- Git/protected/forbidden metadata.

The focused test may run. Runtime manifest, baseline, source roots/content, production runner/module, and output content remain unopened/uninvoked. R7.5 writes/stages/commits/pushes nothing.

## Frozen Values

| Identity | SHA-256 |
|---|---|
| Package | `afb7dd58d01b2659e6b606abd32bc32708842890a6b9b418bb045c4b0e5b35b0` |
| Runbook | `b4831a1919ea04e627fc5530e1729ff3828f192a8b98ed66d785c0196a837b69` |
| Completion roadmap | `2865e1d33c5fcf82727936cb03a9d1093f40ad34f44c23ee05bfc935e89b1f58` |
| Program Roadmap | `906ac525b30a8a994d88163d1c9e00f273221e25fc18639652df569d06da6334` |
| R7.4 plan | `9b0712c42c2c856c05be16b703abc8c1d0a1a5c00e93bdf8046b07f4c03d343a` |
| R8.1 plan | `7bf6a1649176cb232f800487148081ab44af696bda960ea319a9603eec272002` |
| Policy test | `4db581ad82f3f5b3afcf1984a070295ca6be292dad1ecf2eba3871ffc085cf10` |

This plan is bound by path plus final containing commit and cannot predeclare its own hash.

## Registry, Partition, Failure, And Confirmation Boundary

- **PB-I01:** R8.1 in-memory/redacted derived preflight state; no user identity/timestamp/compliance fields.
- **PB-I02/C1-I01 through C1-I06/C1-T01/C1-O01/C1-O02/C1-E01:** package definitions remain unique.
- **PB-SP01:** six automatic preflight groups, unevaluated before R8.1; later require `6=6 Passed+0 Failed`.
- **PB-SP02 through PB-SP05:** unchanged source/output/baseline conservation semantics.
- **PB-FT01 through PB-FT12:** all failures remain typed; none can be waived by confirmation.
- **Confirmation:** `ConfirmPersonalLocalRun`, exactly once after R8.1 GREEN and before one LO; no form fields.

## RED And GREEN

RED: stale R7.4; wrong HEAD/status/hash; old form/external identity residue; missing derived responsibility; missing safety invariant; more than one confirmation; focused test failure; protected/forbidden drift; real input/process/output.

GREEN:

```text
mode=PersonalLocalMode
humanFormFieldCount=0
externalComplianceIdentityFieldCount=0
derivedPreflightGroupCount=6
PersonalLocalModeConfirmationCount=1
policyTestStatus=Passed
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

Require R8.1 ownership of HEAD, hashes, manifest/source set, baseline, fixed output boundary, metadata-only disk estimate, and free-space validation.

### Step 4 - Validate Registry/Partition/Failure conservation - 4 minutes

Require unique rows, PB-I01 derived shape, six PB-SP01 groups, unchanged PB-SP02–05, and complete PB-FT table.

### Step 5 - Validate one-confirmation and safety boundary - 4 minutes

Require `ConfirmPersonalLocalRun` only after GREEN; one attempt, source read-only, cancellable foreground process, no retry, and downstream denials.

### Step 6 - Run focused policy test and stop - 3 minutes

Run `pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusPersonalLocalModePolicy.ps1`. Require Passed with zero real-input/process/output counts. Emit GREEN/Stop and do not start R8.1.

## Verification And Stop

- focused test plus Git/hash/protected/forbidden checks;
- no C1 functional regression here; production code is unchanged and R8.1 later runs seven lightweight gates;
- exact staging/commit/push lists: empty;
- GREEN next action: separately run R8.1 automatic preflight;
- no human confirmation is requested during R7.5.
