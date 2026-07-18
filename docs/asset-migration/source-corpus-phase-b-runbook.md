# StellaSora C1 Phase B PersonalLocalMode Runbook

## Status And Scope

This runbook uses `PersonalLocalMode`. It is for one local owner running one guarded diagnostic C1 snapshot on their own machine and data. It has no PB-A01-through-PB-A12 form and no external compliance identity record.

R8.1 automatically locates the fixed PersonalLocalMode descriptor beneath LocalAppData and derives the current HEAD, tool hashes, locator/manifest shape, declared source-boundary equality, baseline state, output boundary, and disk budget. After a GREEN summary, the user supplies one explicit `ConfirmPersonalLocalRun`. No snapshot has been run by this document.

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

Corpus completeness means every file inside the selected local roots is later cataloged or explicitly excluded. It does not claim object/structured coverage, restoration of an original Unity project, or remote/server completeness.

## R8.1 Automatic Preflight

Do not request human form fields. Derive every check below from current local state and emit only a redacted summary.

### Repository, contract, and policy gates

The operational entrypoint internally runs these exact checks from the fixed implementation worktree. They remain listed for auditability, not as a second manual pass:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
$PSVersionTable.PSVersion.ToString()
git --version
Get-FileHash -Algorithm SHA256 -LiteralPath @(
    '.\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1',
    '.\Tools\AssetImport\SourceCorpusGate.psm1',
    '.\Tools\AssetImport\Test-SourceCorpusGate.ps1',
    '.\docs\asset-migration\schemas\source-corpus-ledger.schema.json',
    '.\docs\asset-migration\schemas\status-vocabulary.json',
    '.\docs\asset-migration\schemas\personal-local-mode-input-locator.schema.json',
    '.\Tools\AssetImport\Test-SourceCorpusPersonalLocalModePolicy.ps1'
)
pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case All
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusPersonalLocalModePolicy.ps1
```

Run R8.1 only through the shared C1-I04 implementation:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
Import-Module .\Tools\AssetImport\SourceCorpusGate.psm1 -Force
$preflightState = Invoke-SourceCorpusPersonalLocalModePreflight -Stage AutomaticPreflight -RepositoryRoot (Get-Location).Path -ThreadId $threadId
$preflightState | ConvertTo-Json -Depth 10
```

The result is redacted. Retain its exact returned values for the later final comparison; if that exact state is unavailable, rerun R8.1. Do not replace the function with an inline locator parser, copied source-kind list, or separate filesystem walker.

Require seven Passed results. The compatibility gate must retain `childProcessCount=1` and `heavyChildProcessCount=0`; runner policy must return its expected synthetic created-output accounting and leave repository outputs absent; the PersonalLocalMode test must report zero real-input access, process launches, and created outputs.

The accepted worktree status set is exactly:

```text
?? AGENTS.md
?? docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

Required hashes are `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` and `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b`. Missing, extra, modified, staged, tracked, conflicted, or differently hashed state is PB-FT02.

### Fixed machine-local locator

R8.1 derives exactly one path and never prompts or searches the machine:

```powershell
$inputLocatorPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
```

The locator is PB-I03. It must already exist, remain outside Git, and validate against `docs/asset-migration/schemas/personal-local-mode-input-locator.schema.json`. R8.1 never creates, repairs, relocates, or prints it. Top level is exactly `schemaVersion`, `manifestPath`, `baseline`, `sourceBoundary`; version is `1.0.0`. `baseline` is exactly `disposition`, `path`; `sourceBoundary` is exactly `schemaVersion`, `sources`.

`Absent` baseline requires null path. `Present` requires one absolute local path. Missing LocalAppData, missing/malformed locator, unknown fields, relative/network locator targets, or locator-byte drift is PB-FT03 and Stops.

### Runtime-only manifest and declared source set

Read the manifest only from PB-I03 `manifestPath`, without printing its path, contents, or `rootPath` values. Require:

- top level exactly `schemaVersion`, `sources` and version `1.0.0`;
- each row exactly `sourceId`, `sourceKind`, `rootPath`;
- nonempty source set; IDs unique under `OrdinalIgnoreCase` with stable exact case;
- kinds only from `PcInstall`, `PcPatchOrCache`, `AndroidApk`, `AndroidDataOrCache`;
- every root absolute, local, available, read-only for the operation, and inside the intended local boundary;
- PB-I03 `sourceBoundary.sources` has the same row shape and defines the complete intended boundary for this operation;
- boundary and manifest sets are equal in both directions by exact ID case, exact kind, and normalized reparse-safe path (`OrdinalIgnoreCase` for identity lookup/path comparison, `Ordinal` for displayed ID case and kind);
- no network/runtime-download source;
- no reparse point, symlink, or junction in relevant path chains.

Require both conservations:

```text
boundarySourceCount = boundaryMatchedCount + boundaryMissingOrMismatchedCount
manifestSourceCount = manifestMatchedCount + manifestExtraOrMismatchedCount
boundaryMissingOrMismatchedCount=0
manifestExtraOrMismatchedCount=0
```

This validates completeness relative to the explicit PB-I03 boundary; R8.1 does not scan arbitrary machine locations for undeclared installations. Derive redacted `derivedInputLocatorState=LocatedAndValid`, `derivedSourceBoundaryState=ExactSetMatch`, and `derivedManifestSourceSet` containing portable source IDs/kinds only. Do not enumerate or read source files during preflight.

### Baseline state

Use PB-I03 `baseline` and derive exactly one:

- `FirstCaptureNoBaseline`; or
- `ApprovedBaselinePresent` after strictly validating the immutable baseline shape: top level exactly `schemaVersion`, `inputFingerprint`, `sources`; each source exactly `sourceId`, `sourceKind`, `rootFingerprint`; no `rootPath`.

Do not expose baseline paths or fingerprints. First capture and every mismatch later Stop.

### Fixed output boundary and disk budget

The only output root is:

```text
C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1
```

Require it and all `.c1-staging-*` siblings absent. Existing ancestors must be expected, genuine directories without reparse points. Preserve unknown state; do not clean it.

Derive a positive conservative estimate for the complete ledger/summary, staging, and retained diagnostic margin from manifest metadata and contract bounds without enumerating source contents. If a safe positive estimate cannot be derived, Stop. Then compute:

```text
requiredFreeSpaceBytes = max(1073741824, 2 * derivedEstimatedOutputBytes)
```

Read current available space on the output volume and require it at least `requiredFreeSpaceBytes`.

### Derived result

R8.1 emits:

```text
mode=PersonalLocalMode
derivedHead=<current HEAD equal to upstream>
derivedToolHashMismatchCount=0
derivedInputLocatorState=LocatedAndValid
derivedSourceBoundaryState=ExactSetMatch
derivedManifestSourceSet=<redacted portable IDs/kinds>
derivedBaselineState=<FirstCaptureNoBaseline|ApprovedBaselinePresent>
derivedOutputBoundaryState=AbsentAndSafe
derivedRequiredFreeSpaceBytes=<positive integer>
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

Any failure maps to PB-FT01 through PB-FT12 and produces Stop, not a prompt to waive the check.

## Single Human Confirmation

Only after displaying the complete redacted GREEN result may the user state exactly:

```text
ConfirmPersonalLocalRun
```

This is the only human authorization in PersonalLocalMode. It has `PersonalLocalModeConfirmationCount=1`, applies to the displayed state and next one attempt, and is consumed when the foreground runner starts. It carries no operator/compliance identity fields.

Immediately before start, call `Invoke-SourceCorpusPersonalLocalModePreflight -Stage FinalRecheck -ExpectedState $preflightState` in the same foreground control chain. It rechecks HEAD/upstream/status, protected and registered hashes, PB-I03/manifest exact identities, boundary equality, baseline, source metadata, output/staging absence, free space, and safety state through the same implementation used by R8.1. Require `FinalRecheckPassed`; drift or an internal error invalidates the confirmation and returns to R8.1. No hand-written recheck is permitted.

## Trusted Local Execution Boundary

PB-I03 and the manifest path are not printed, but the resolved manifest argument may be visible to local process inspection. Disable or control transcription, shared logging, and history according to local policy. If that is unacceptable, Stop; do not invent a wrapper.

## Guarded Command

Run only after the single confirmation and final identity recheck:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$inputLocatorPath = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'StellaGaia\PhaseB\personal-local-mode-inputs.json'
$inputLocator = Get-Content -Raw -LiteralPath $inputLocatorPath | ConvertFrom-Json
$sourceRootManifestPath = [string] $inputLocator.manifestPath
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

One foreground `pwsh` process, one attempt. The user retains foreground cancellation authority. No wrapper, extra flag/command, background launcher, watchdog, automatic retry, C2, extraction, decoding, Unity, or import.

## Stop, Rollback, And Isolation

Stop on missing/malformed/changed PB-I03, boundary/manifest mismatch, invalid baseline disposition, missing/unavailable declared roots, changed identities, access/hash errors, mutation, collisions, reparse paths, count/byte mismatch, schema failure, pre-existing/partial output, staging residue, insufficient disk, unexpected process/network behavior, or any need to weaken validation.

Only known attempt-owned staging and the just-published output owned by the same caught writer failure may be cleaned by the runner. Preserve source roots, pre-existing output, unknown residue, and quarantined state. One Stop ends the attempt; a new run requires a fresh R8.1 and a new single confirmation.

## Post-Run Boundary

R8.2 validates C1-O01/C1-O02 schemas, fingerprints, counts/bytes, source immutability, sensitive projection, end identities, and filesystem delta without reopening source content. First capture remains `Stop`/candidate baseline. A later exact baseline match may produce `Review`, never automatic C2 authorization.

Portable evidence may include source IDs/kinds, relative paths, hashes, counts, bytes, canonical output, versions, derived preflight summary, `PersonalLocalModeConfirmationCount=1`, and Stop/Review. Never include expanded manifest/root paths, credentials, host/account/volume identities, or unrestricted logs.
