# StellaSora Phase B PersonalLocalMode Authorization Package

## Status And Decision Boundary

**Mode:** `PersonalLocalMode`.

**Status:** governance prepared; no real preflight or Phase B operation has run.

PersonalLocalMode is for one local owner operating on their own machine and data. It removes the PB-A01-through-PB-A12 human form and all PB-I01 external compliance identity fields. R8.1 automatically locates one fixed machine-local descriptor beneath LocalAppData, then derives and validates the current repository, tool, manifest, baseline, declared source boundary, output, and storage state directly. The user supplies only one explicit `ConfirmPersonalLocalRun` immediately before the actual long-running operation.

The only eligible operation remains one diagnostic `C1.SourceCorpusSnapshot.Refresh` attempt. This package does not authorize C2, Unity, extraction, decoding, import, staging, publication, a retry, or a second run.

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
PersonalLocalModeConfirmationCount=1
```

## Target User And Completion Path

- **Target user:** the local owner/operator of the StellaSora inputs and machine.
- **Scenario:** derive a complete, current preflight locally; show a redacted summary; receive one explicit confirmation; run one cancellable diagnostic C1 snapshot; stop for human review.
- **Entry:** committed PersonalLocalMode governance followed by a GREEN R8.1 derived preflight.
- **Path:** R7.5 mode validation -> R8.1 automatic preflight -> one `ConfirmPersonalLocalRun` -> one LO R8.C1-1 attempt -> R8.2 validation -> Stop/Review.
- **Success state:** one validated snapshot attempt with conserved counts/bytes, unchanged source roots, fixed output, no sensitive leak, and no downstream operation.

## Authority Order

1. repository `AGENTS.md`;
2. `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`;
3. current C1/C2 and lifecycle central contracts;
4. `docs/asset-migration/source-corpus-phase-b-runbook.md`;
5. this PersonalLocalMode package;
6. the current R7.5 and R8.1 child Task plans.

No conversation message can waive a failed derived check or expand the operation boundary.

---

## Central Definition 1: Artifact Registry

All portable paths use forward slashes. SHA-256 values are lowercase hexadecimal over exact bytes. Expanded machine-local paths remain outside Git and portable evidence.

| ID | Artifact and identity | Exact shape or content authority | Success/failure rule |
|---|---|---|---|
| PB-I01 | PersonalLocalMode derived preflight state | R8.1 in-memory/redacted state with `mode`, `derivedHead`, `derivedBranch`, `derivedToolHashMismatchCount`, `derivedInputLocatorState`, `derivedSourceBoundaryState`, `derivedManifestSourceSet`, `derivedBaselineState`, `derivedOutputBoundaryState`, `derivedRequiredFreeSpaceBytes`, `derivedAvailableFreeSpaceBytes`, safety flags, and `result`; no operator identity or approval timestamp | Recomputed from current local state; every check must pass before the single confirmation is accepted |
| PB-I02 | This package; identity is path plus containing commit | `docs/asset-migration/source-corpus-phase-b-authorization-package.md` | R8.1 derives its exact current bytes and containing HEAD |
| PB-I03 | Fixed machine-local input locator and source boundary registry | Automatically located at `[Environment]::GetFolderPath('LocalApplicationData')` plus `StellaGaia\PhaseB\personal-local-mode-inputs.json`; exact shape is `docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json`; top level exactly `schemaVersion`, `manifestPath`, `baseline`, `sourceBoundary`; its fixed path plus exact bytes is its private identity | Missing, malformed, changed, non-local, sensitive projection, or boundary ambiguity Stops; exact bytes and paths remain machine-local |
| C1-I01 | Runtime-only source-root manifest | Located only through PB-I03 `manifestPath`; top level exactly `schemaVersion`, `sources`; version `1.0.0`; each source exactly `sourceId`, `sourceKind`, `rootPath` | R8.1 strictly parses locally and proves exact set equality with PB-I03 `sourceBoundary.sources`; never copied to Git or portable output |
| C1-I02 | Machine-local immutable baseline record | PB-I03 `baseline` is exactly `disposition`, `path`; `Absent` requires null path; `Present` requires an absolute local path to a record whose top level is exactly `schemaVersion`, `inputFingerprint`, `sources`; version `1.0.0`; each source exactly `sourceId`, `sourceKind`, `rootFingerprint`; no `rootPath` | R8.1 derives `FirstCaptureNoBaseline` or validates the located immutable baseline; inconsistent disposition/path Stops |
| C1-I03 | Guarded runner | `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`; exact SHA below | Current bytes derived automatically; mismatch stops before source enumeration |
| C1-I04 | Snapshot/catalog module | `Tools/AssetImport/SourceCorpusGate.psm1`; exact SHA below | Current bytes derived automatically; mismatch stops |
| C1-I05 | Public ledger schema | `docs/asset-migration/schemas/source-corpus-ledger.schema.json`; exact SHA below | Current bytes derived automatically; mismatch stops |
| C1-I06 | Status vocabulary | `docs/asset-migration/schemas/status-vocabulary.json`; exact SHA below | Current bytes derived automatically; mismatch stops |
| C1-T01 | Same-volume staging directory | one sibling `.c1-staging-<32 lowercase hex GUID>` beneath the canonical C1 parent | Must be absent before the run; known attempt-owned staging is removed in `finally`; unknown residue is preserved and stops |
| C1-O01 | Portable source corpus ledger | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` with the frozen C1 schema | Written only by the one confirmed operation; invalid/partial output is non-consumable |
| C1-O02 | Private portable C1 summary | same root, `source-corpus-summary.json`, bound to C1-O01 and conservation totals | Invalid/stale output is non-consumable |
| C1-E01 | Redacted execution handoff | derived state, one-confirmation count, command identity, counts/bytes, failures, and next action | Never contains expanded manifest/root paths, credentials, host/account identifiers, or unrestricted logs |

### Frozen Tool And Contract Bytes

| Item | Version or SHA-256 |
|---|---|
| PowerShell | `7.6.0` |
| Git | `2.53.0.windows.2` |
| C1-I03 runner | `8bfef5d423bd3343d361ff215007df6a9f4bcbcf166e85a8fc1bc1ec12a27d41` |
| C1-I04 module | `1b53fe277c18bb9d82277033581c747d277a7666b64f8139e78dcf499fe38280` |
| `Test-SourceCorpusGate.ps1` | `0311107a5e099d9f74ebe8ec776d916c4139cbbae43fcdfe31875cf85af136c5` |
| C1-I05 ledger schema | `b7b3265531bbd548f7f6d0e11a7b8151870044d79578fb88b373dc3479c8e95c` |
| C1-I06 vocabulary | `9d845b2290cc606de755b2b4cc0fb877e58bc4f3964a55bec01a6ec17d8468e6` |
| PB-I03 locator schema | `85a736a5b04be3b5d6a7f27cbaf645a3dafe252c0b17b1d3b48f0ff4d77f463e` |
| PersonalLocalMode policy test | `2e507defc1e4e17af2595bdcca6d5f26e5c73687e44085997a9dd7086ea4c43a` |

Any registered byte/version mismatch is PB-FT02. R8.1 computes the current values; the user does not transcribe hashes.

### Exact Protected Untracked Worktree Exception

At R8.1 start/end and immediately before LO start, `git status --short` must contain exactly:

```text
?? AGENTS.md
?? docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

| Repository-relative path | Required SHA-256 |
|---|---|
| `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md` | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

Missing, extra, changed, staged, tracked, conflicted, or differently hashed state is PB-FT02. Neither file is a Phase B input/output/evidence artifact or staging candidate.

### Fixed Local Input Locator And Approved Source-Kind Vocabulary

R8.1 derives the locator without a prompt:

```powershell
$inputLocatorPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
```

PB-I03 is runtime-only and never created or repaired by R8.1. Its exact schema is the registered locator schema above. `sourceBoundary.sources` is the complete intended local source boundary for this operation; the contract makes no claim about unspecified StellaSora installations elsewhere on the machine. Each boundary row and manifest row has exactly `sourceId`, `sourceKind`, `rootPath`.

R8.1 compares IDs with `OrdinalIgnoreCase`, requires the same exact ID case in both artifacts, compares `sourceKind` with `Ordinal`, and compares fully qualified normalized Windows paths with `OrdinalIgnoreCase` after reparse-safe resolution. Duplicate IDs in either set Stop. The two source sets must be equal in both directions:

```text
boundarySourceCount = boundaryMatchedCount + boundaryMissingOrMismatchedCount
manifestSourceCount = manifestMatchedCount + manifestExtraOrMismatchedCount
boundaryMissingOrMismatchedCount=0
manifestExtraOrMismatchedCount=0
```

This proves completeness relative to the explicitly declared PB-I03 boundary without scanning arbitrary machine locations.

```text
PcInstall
PcPatchOrCache
AndroidApk
AndroidDataOrCache
```

R8.1 derives the exact manifest source-kind/source-ID set. Duplicate IDs under `OrdinalIgnoreCase`, case drift, unavailable declared roots, boundary/manifest omission or surplus, unapproved kinds, or network/runtime sources Stop.

---

## Central Definition 2: Subject/Partition Registry

| ID | Universe and identity | Mutually exclusive partitions | Conservation and consumer |
|---|---|---|---|
| PB-SP01 PersonalLocalMode preflight groups | exactly HeadAndBytes, ManifestAndSourceSet, BaselineState, OutputBoundary, DiskBudget, SafetyAndProcess | Passed, Failed | `6 = passed + failed`; single confirmation requires `6 = 6 + 0` |
| PB-SP02 source-boundary rows | every PB-I03 `sourceBoundary.sources` row by exact `sourceId` | BoundaryMatched, BoundaryMissingOrMismatched | `boundarySourceCount = boundaryMatchedCount + boundaryMissingOrMismatchedCount`; require mismatch zero |
| PB-SP03 source files | every later file under roots whose PB-SP02/PB-SP06 rows match and whose availability/path-safety checks pass | Cataloged, ExplicitlyExcluded | evaluated only during LO; counts and bytes conserve |
| PB-SP04 output artifacts | exactly C1-O01 and C1-O02 | ValidatedDiagnostic, Suppressed, Quarantined | before LO `2 = 0 + 2 + 0`; no result authorizes C2 |
| PB-SP05 baseline state | one capture comparison | ApprovedMatch, FirstCaptureCandidate, MismatchOrInvalid | only R8.2 evaluates; first capture/mismatch Stops |
| PB-SP06 manifest rows | every C1-I01 `sources` row by exact `sourceId` | ManifestMatched, ManifestExtraOrMismatched | `manifestSourceCount = manifestMatchedCount + manifestExtraOrMismatchedCount`; require mismatch zero |

Portable projection is lossless. Machine paths remain local; portable artifacts contain only source IDs/kinds, relative paths, hashes, counts, bytes, dispositions, and approved evidence.

---

## Central Definition 3: Failure Transition Table

Output vectors use `D` for validated diagnostic, `S` for suppressed/absent, and `Q` for quarantined/non-consumable.

| ID | Failure and stable subject | C1-O01/O02 vector | Isolation and next action |
|---|---|---|---|
| PB-FT01 | Any PersonalLocalMode derived preflight group Failed/stale, or `ConfirmPersonalLocalRun` absent at LO boundary | `S,S` | Recompute R8.1; never request a form or infer pass |
| PB-FT02 | Branch/HEAD/protected state/version/hash mismatch | `S,S` | Preserve repository state; update governance only through review |
| PB-FT03 | PB-I03 missing/malformed/changed, locator schema failure, invalid manifest/baseline locator, manifest/baseline missing or malformed, or sensitive projection | `S,S` | Preserve machine-local inputs outside Git; correct locally and rerun R8.1 |
| PB-FT04 | PB-SP02/PB-SP06 set mismatch, missing declared root, duplicate identity, case drift, kind/path mismatch, collision, reparse point, symlink, junction, or boundary violation | `S,S` | No output; correct PB-I03/C1-I01 owning prerequisite |
| PB-FT05 | Source access/read/hash/mutation error during LO | `S,S` | Remove only known attempt-owned staging; preserve ambiguity |
| PB-FT06 | Count/byte conservation or portable projection mismatch | `S,S` | Reject before publication; no expected-value edits |
| PB-FT07 | Pre-existing output/staging, insufficient disk, or unapproved path | `S,S` | Preserve unknown state; no cleanup authority |
| PB-FT08 | Output write/move/interruption | `S,S` if rollback proven, otherwise `Q,Q` | Attempt-owned rollback only; ambiguous state retained |
| PB-FT09 | Post-write schema/fingerprint/identity validation failure | `Q,Q` | Preserve diagnostic output; no retry |
| PB-FT10 | Baseline mismatch/invalid comparison | `Q,Q` | Redacted failure only; Stop |
| PB-FT11 | No baseline on first capture | `D,D` plus FirstCaptureCandidate | Stop for human review; no retroactive C2 permission |
| PB-FT12 | Unexpected process/network/extraction/Unity/import/source write | `S,S` or `Q,Q` | Stop immediately; preserve non-sensitive evidence |

Only known attempt-owned staging and a just-published output owned by the same caught writer failure may be cleaned automatically. Source roots, pre-existing output, unknown residue, and quarantined state are never deleted.

## PersonalLocalMode Automatic Preflight And Single Confirmation

R8.1 derives all of these without a human form:

1. current branch, HEAD/upstream, worktree/protected state, versions, and registered hashes;
2. fixed PB-I03 location/schema, strict runtime manifest shape, and exact bidirectional equality between the declared boundary and manifest source set;
3. baseline disposition/path consistency and state (`FirstCaptureNoBaseline` or validated `ApprovedBaselinePresent`);
4. fixed canonical output/staging boundary and reparse safety;
5. positive estimated output bytes, available space, and `requiredFreeSpaceBytes=max(1073741824,2*estimate)`;
6. source-read-only, one-attempt, cancellable foreground process, no-retry, and downstream-denial flags.

R8.1 emits a redacted `ReadyForSinglePersonalLocalRun` summary. Only then may the user state exactly `ConfirmPersonalLocalRun`. That single confirmation:

- applies only to the displayed current derived state and next one attempt;
- is consumed when the foreground runner starts;
- becomes stale on any derived-state change;
- is not an identity/compliance record and contains no form fields;
- cannot waive a failed check or authorize another stage.

Immediately before process start, recheck HEAD/status, output/staging absence, available space, and safety flags. Any drift returns to R8.1 without consuming a new operation attempt.

## Exact Operation, Output Root, And Command

```text
operation=C1.SourceCorpusSnapshot.Refresh
canonicalOutputRoot=C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1
```

The root must not exist before the run. Existing ancestors and source path chains must contain no reparse point, symlink, or junction.

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$inputLocatorPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
$inputLocator = Get-Content -Raw -LiteralPath $inputLocatorPath | ConvertFrom-Json
$sourceRootManifestPath = [string] $inputLocator.manifestPath
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

No wrapper, alternate path/flag, callback, background launcher, watchdog, extra command, shell transcription, or retry is allowed.

## Runtime-Only And Sensitive-Path Boundary

- Inspect PB-I03, C1-I01, and optional C1-I02 locally without printing/copying their paths, exact bytes, or `rootPath` values.
- Disable/control transcription, shared command logging, and history capture.
- Credentials, host/account/user/volume identifiers, expanded manifest/root paths, local tool-install paths, and unrestricted stdout/stderr remain local.
- Network capture, downloads, CDN/server enumeration, and account-specific acquisition are excluded.

## Required Preflight And Evidence

Run the lightweight gates from the runbook, including `Test-SourceCorpusPersonalLocalModePolicy.ps1`. Do not rerun the completed R6 audit merely to recreate equivalent evidence.

C1-E01 records only derived/redacted state, `PersonalLocalModeConfirmationCount=1`, locator/boundary validation status, start/end identity, versions/hashes, source IDs/kinds, times, counts/bytes, canonical output, command identity, gate results, failure owner, and explicit downstream denials. PB-I03 identity/bytes and all machine-local paths remain private.

## Current Decision

```text
mode=PersonalLocalMode
humanFormFieldCount=0
derivedPreflightRequired=true
PersonalLocalModeConfirmationCount=0
authorizedOperationCount=0
phaseBExecuted=false
nextAction=Validate mode migration at R7.5, then run R8.1 automatic preflight
```
