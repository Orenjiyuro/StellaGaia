# StellaSora C1 Phase B Frozen Local Snapshot Operational Runbook

## Status And Scope

This is an instructions-only operational runbook for C1 Phase B. Phase B has **not** run during Phase A implementation or review. No snapshot artifacts, fingerprints, counts, or byte totals are asserted to exist by this document.

The operation captures a **frozen local snapshot** of the explicitly approved, locally available source boundary. The term corpus completeness means every file within those approved local roots is cataloged or explicitly excluded with a reason. It does not mean structured or object coverage, restoration of an original project, or completeness of remote server or CDN content.

This runbook does not implement object discovery and does not authorize C2 extraction.

## Preconditions

Do not run the guarded command unless every item below is true.

- Run these read-only Phase A C0/C1/C2 contract gates from the intended C1 worktree:

  ```powershell
  pwsh -NoProfile -File .\Tools\AssetImport\Test-AssetCorpusContract.ps1
  pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1
  pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusSnapshotFunctions.ps1 -Case All
  pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusCatalog.ps1 -Case All
  pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusRunnerPolicy.ps1 -Case All
  pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusC0Compatibility.ps1 -Case All
  ```

- Each gate must emit a one-line `Passed` result with zero issues. The compatibility gate must report `childProcessCount = 1` and `heavyChildProcessCount = 0`; the runner-policy gate must report `createdOutputCount = 0`.
- Confirm this is the intended C1 branch and worktree. Run `git status --short --branch`; it must identify the intended branch and show no working-tree changes before Phase B.
- Confirm the current repository state, PowerShell version, and tool versions are the reviewed versions intended for the run. Record the base and HEAD SHAs. Run the following read-only commands and compare every value with the reviewed approval record; stop on any mismatch:

  ```powershell
  git rev-parse HEAD
  $PSVersionTable.PSVersion.ToString()
  Get-FileHash -Algorithm SHA256 -LiteralPath .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1
  Get-FileHash -Algorithm SHA256 -LiteralPath .\Tools\AssetImport\SourceCorpusGate.psm1
  ```

- An explicitly human-approved, machine-local source-root manifest must exist outside Git. It must contain the actual locally available roots within the approved boundary for `PcInstall`, `PcPatchOrCache`, `AndroidApk`, and `AndroidDataOrCache`, as applicable.
- The manifest must use schema version `1.0.0`, exact approved `sourceId` values, exact allowed `sourceKind` values, and an absolute runtime-only `rootPath` for every source. Source IDs must be unique under `OrdinalIgnoreCase` comparison; after approval, their exact spelling and case must remain stable for identity and handoff.
- The manifest path and all `rootPath` values are machine-local operational evidence, not portable secrets. Never copy their expanded values into portable ledgers, shared logs, screenshots, handoff text, or Git.
- The canonical output root must not exist before the run. Its parent and output path chains must contain no reparse points, symlinks, or junctions.
- Every approved source path chain must contain no reparse points, symlinks, or junctions.
- An approved estimate of the combined staged ledger and summary size must be available before the run. If no approved estimate exists, stop. Available free space must be at least the greater of 1 GiB or twice that approved estimate.

## Trusted Local Execution Boundary

The guarded command necessarily displays the manifest path in the trusted interactive console and may expose it transiently to local process inspection. Run only on a trusted local host and session where PowerShell transcription, command-history capture, and shared command logging are disabled or controlled according to approved local policy. Never paste or capture expanded manifest or source `rootPath` values in shared logs, screenshots, handoff evidence, portable artifacts, or Git.

If approved policy forbids local console or process-command-line visibility of the manifest path, stop and obtain an approved runner-contract change. Do not improvise a different invocation or weaken the guard.

## Local Manifest Inspection Before The Command

Inspect the manifest locally without printing, logging, or copying its path or root values. Confirm its exact top-level schema version and `sources` shape, then verify every source's approved identity, kind, absolute path, availability, and boundary approval. Record human approval outside portable artifacts.

Do not edit the runner, weaken path checks, relocate output, or bypass manifest and output policy to make a source pass.

## Disk Space Preflight

Set the planned canonical output root and perform this read-only disk check before invoking the runner:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$repositoryRoot = (git rev-parse --show-toplevel).Trim()
$outputRoot = Join-Path $repositoryRoot "Extracted\Threads\$threadId\C1"
if (-not (Test-Path -LiteralPath Variable:approvedCombinedStagedArtifactEstimateBytes)) { throw 'Stop: approved staged-artifact estimate is absent.' }
try { [decimal] $approvedEstimateBytes = $approvedCombinedStagedArtifactEstimateBytes } catch { throw 'Stop: approved staged-artifact estimate is invalid.' }
if ($approvedEstimateBytes -le 0) { throw 'Stop: approved staged-artifact estimate is invalid.' }
$availableFreeSpace = [System.IO.DriveInfo]::new([System.IO.Path]::GetPathRoot($outputRoot)).AvailableFreeSpace
$requiredFreeSpace = [Math]::Max([decimal] 1GB, [decimal] 2 * $approvedEstimateBytes)
if ($availableFreeSpace -lt $requiredFreeSpace) { throw 'Stop: insufficient approved free-space margin.' }
```

`$approvedCombinedStagedArtifactEstimateBytes` must be the approved numeric estimate recorded outside Git. Do not infer it during the run. Stop if it is absent, invalid, or the check fails.

## Guarded Phase B Command

The following is the only guarded Phase B invocation described by this runbook:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$sourceRootManifestPath = Read-Host 'Approved absolute path to the machine-local source-root manifest'
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

This command is Phase B only. It requires the explicitly human-approved manifest and must **not** run during Phase A plan implementation or review. Do not execute it merely to validate this document.

## Stop Conditions

Stop immediately on any of these conditions:

- a missing source root;
- a changed, unexpected, or unapproved fingerprint;
- any access, enumeration, read, or hash error;
- a reparse point, symlink, or junction anywhere in a relevant path chain;
- a duplicate identity, case collision, relative-path collision, or path-boundary violation;
- a file mutation detected while reading or hashing;
- a file-count or byte-conservation mismatch;
- a runtime manifest, portable ledger, private summary, or handoff schema/contract mismatch;
- an output collision, a pre-existing output root, or output outside the canonical C1 artifact root;
- partial output, staging residue, or an interrupted publication;
- any unexpected child process, heavy process, Unity launch, decoding, extraction, or object-discovery behavior.

On stop, preserve the non-sensitive evidence and exact error without weakening checks or repeatedly retrying. Do not continue into real C2 extraction. Request diagnosis and renewed human approval before any later attempt.

## Conditional Success Observation

If a future approved run exits successfully, expect exactly these portable files beneath the canonical C1 artifact root:

- `source-corpus-ledger.json`
- `source-corpus-summary.json`

After that future run, in the same PowerShell session where `$outputRoot` was set, validate the actual generated ledger and summary against the frozen C1 contract:

```powershell
$ledgerPath = Join-Path $outputRoot 'source-corpus-ledger.json'
$summaryPath = Join-Path $outputRoot 'source-corpus-summary.json'
pwsh -NoProfile -File .\Tools\AssetImport\Test-SourceCorpusGate.ps1 -SummaryPath $summaryPath -LedgerPath $ledgerPath
```

This command must emit a one-line `Passed` result with zero issues. Separately rerun the remaining Phase A precondition gates as regression and compatibility checks. Those gates use committed fixtures or synthetic roots; they do not validate the actual generated artifacts. A successful C1 snapshot does not automatically start or authorize C2.

Before any C2 recommendation, an approved baseline record conforming to the frozen contract below must exist. A missing baseline is `Stop`, whether this is the first capture or a later run. For a later run with an approved baseline, compare the produced per-source `rootFingerprint` values and aggregate `inputFingerprint` with that baseline. The runner does not perform this baseline comparison.

The baseline is a machine-local JSON object outside Git with exactly these required fields:

- `schemaVersion`: the string `1.0.0`;
- `inputFingerprint`: the expected aggregate fingerprint string;
- `sources`: an array in which every item contains exactly the string fields `sourceId`, `sourceKind`, and `rootFingerprint`.

The baseline must not contain `rootPath` or any other machine path. Within the baseline and, separately, within the current generated ledger, every `sourceId` must be unique under `OrdinalIgnoreCase`. Compare them manually as follows, without printing paths or fingerprints:

1. Strictly parse both JSON documents and verify the baseline shape above. Any missing, additional, null, or incorrectly typed field is `Stop`.
2. Verify `sourceId` uniqueness under `OrdinalIgnoreCase` independently in the baseline and current source arrays. Any collision is `Stop`.
3. Compare the baseline and current `sourceId` sets under `OrdinalIgnoreCase`. They must be exactly equal, with no missing or additional source. Otherwise the result is `Stop`.
4. Pair each baseline source with its current source by `OrdinalIgnoreCase` `sourceId`. For every pair, compare the exact `sourceId` spelling and case, `sourceKind`, and `rootFingerprint` using Ordinal case-sensitive equality. Any mismatch is `Stop`.
5. Compare baseline and current aggregate `inputFingerprint` using Ordinal case-sensitive equality. Any mismatch is `Stop`.

Record only a redacted comparison result with `status` set to `Passed` or `Failed` and `issueCount` set to a non-negative integer. Do not record source paths, manifest paths, fingerprints, source IDs, or field values in that result. A `Failed` result or nonzero `issueCount` is `Stop`.

For a first capture with no approved baseline, the outcome after capture and contract validation remains `Stop`. A human must review and explicitly approve the newly generated fingerprints, then use that capture result to generate and freeze a machine-local, outside-Git baseline that conforms to the contract above. That approval does not retroactively permit the first capture to proceed to C2. Only a subsequent approved run that passes the complete baseline comparison algorithm may receive a `Proceed` recommendation.

## Handoff Evidence Checklist

Record the following after a future run or stop:

- branch name and intended worktree identity;
- base SHA and HEAD SHA;
- source IDs and source kinds, never source root paths;
- `snapshotId` and `inputFingerprint`;
- each source's `rootFingerprint` associated only with its source ID and kind;
- per-source and aggregate file counts and byte totals;
- cataloged and explicitly excluded file counts and bytes;
- every exclusion's portable relative path and reason;
- canonical artifact root, which is approved to record;
- the exact guarded command in redacted form, retaining variable names, flags, and the canonical output/worktree path while redacting or omitting only the expanded manifest path and source `rootPath` values;
- start time, end time, and duration;
- PowerShell version, plus the SHA-256 hashes of `New-StellaSoraSourceCorpusSnapshot.ps1` and `SourceCorpusGate.psm1`;
- blockers, errors, and stop conditions encountered;
- a `Proceed` or `Stop` recommendation for C2 integration, with supporting gate, freshness, and conservation evidence.

Machine absolute source-root and manifest paths remain machine-local evidence only. They must never appear in the portable ledger, portable summary, handoff fixture, review notes committed to Git, or any other portable artifact.

## C2 Integration Decision

Recommend C2 integration only after the C0, C1, and C2 contract gates pass and the future snapshot's freshness, strict schemas, fingerprints, and count/byte conservation are verified. Otherwise the decision is `Stop`.

This runbook adds no object-discovery implementation. Corpus completeness and structured/object coverage are separate claims: the former concerns all files inside the approved frozen local snapshot boundary; the latter remains future C2 work.
