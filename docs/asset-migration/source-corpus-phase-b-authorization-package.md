# StellaSora R7 Phase B Exact Authorization Package

## Status And Decision Boundary

**Status:** Prepared for exact human review. This document is not an authorization and does not record that Phase B ran.

**Reviewed code baseline:** `c36b254f6d2fe78d6e45c947a9e90fa5514a84a7` on `codex/asset-corpus-integration`.

**Only operation eligible for later authorization:** one guarded, diagnostic C1 frozen-local-snapshot capture under the existing C1 runner contract. The exact Git commit containing this package must be supplied in the external approval record and must be the execution HEAD.

This package does not authorize C2 discovery, a real C1-to-C2 adapter, observation producers, C2 publication, C3-C6 lifecycle publication, G5, C7/G4, Unity, extraction, decoding, import, staging into `Assets/StellaGaia/Imported`, source modification, a retry, or a second run.

The current C2 real run remains `BLOCKED`: no reviewed real-input adapter, observation-producer set, or real publication-root contract exists. The existing fixture entry and fixture publication paths are never valid real-data entry points.

## Target User And Completion Path

- **Target user:** the human operator who owns the local StellaSora inputs and can approve their runtime-only identities, storage budget, and one guarded command.
- **Scenario:** freeze and byte-account the already-local PC, patch/cache, Android APK, and Android DATA/cache boundary without reading network or server content.
- **Entry:** an exact external approval record satisfying PB-A01 through PB-A12 below, followed by the guarded C1 command from the fixed worktree and execution HEAD.
- **Path:** preflight -> guarded capture -> contract validation -> baseline comparison or first-capture review -> stop.
- **R7 success state:** this package is committed and reviewed, while no Phase B operation has run.
- **Future C1 success state:** both C1 artifacts validate, all file/count/byte equations hold, start/end identities match, and the result stops for human review. A first capture remains a baseline candidate only; it never proceeds to C2.

## Authority Order

1. repository `AGENTS.md`;
2. `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`;
3. current C1/C2 and lifecycle central contracts;
4. `docs/asset-migration/source-corpus-phase-b-runbook.md`;
5. `docs/asset-migration/c2-discovery-phase-b-runbook.md`;
6. this package;
7. the exact external human approval record.

The current C1 runbook's first-capture `Stop` rule remains authoritative. An approval may permit one capture; it cannot waive validation, promote the first capture retroactively, or authorize a downstream stage.

---

## Central Definition 1: Artifact Registry

All portable paths use forward slashes. SHA-256 values are lowercase hexadecimal over exact bytes. Machine-local paths and expanded runtime values remain outside Git and portable handoff evidence.

| ID | Artifact and identity | Exact shape or content authority | Success/failure rule |
|---|---|---|---|
| PB-I01 | External exact approval record; identity is the operator plus approval timestamp plus execution HEAD | PB-A01 through PB-A12, recorded outside this package; no source path is portable | All rows Confirmed before any source access; otherwise Stop with no output |
| PB-I02 | This package; identity is its portable path plus containing commit | `docs/asset-migration/source-corpus-phase-b-authorization-package.md` | Execution HEAD must be the exact reviewed containing commit |
| C1-I01 | Runtime-only source-root manifest; identity is its machine-local approved record identity, never its portable path | Top level exactly `schemaVersion`, `sources`; version `1.0.0`; each source exactly `sourceId`, `sourceKind`, `rootPath` | Required, externally approved, strictly parsed; never copied to Git or portable output |
| C1-I02 | Machine-local immutable baseline record | Top level exactly `schemaVersion`, `inputFingerprint`, `sources`; version `1.0.0`; each source exactly `sourceId`, `sourceKind`, `rootFingerprint`; no `rootPath` | Required for a Proceed comparison; absence on first capture produces diagnostic Stop |
| C1-I03 | Guarded runner | `Tools/AssetImport/New-StellaSoraSourceCorpusSnapshot.ps1`; exact SHA below | Required exact bytes; mismatch stops before source access |
| C1-I04 | Snapshot/catalog module | `Tools/AssetImport/SourceCorpusGate.psm1`; exact SHA below | Required exact bytes; mismatch stops before source access |
| C1-I05 | Public ledger schema | `docs/asset-migration/schemas/source-corpus-ledger.schema.json`; exact accepted C0 bytes | Required exact bytes; schema mismatch suppresses downstream use |
| C1-I06 | Status vocabulary | `docs/asset-migration/schemas/status-vocabulary.json`; exact accepted C0 bytes | Required exact bytes; vocabulary mismatch suppresses downstream use |
| C1-T01 | Same-volume staging directory | one sibling named `.c1-staging-<32 lowercase hex GUID>` beneath the canonical C1 parent | Temporary only; runner removes it in `finally`; residue is Stop and is never silently reused |
| C1-O01 | Portable source corpus ledger | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json`; top level exactly `schemaVersion`, `snapshotId`, `generatedAt`, `inputFingerprint`, `toolVersions`, `sources`, `files`, `objects` | Written only as part of the two-file canonical output root; `objects=[]`; invalid or partial output is non-consumable |
| C1-O02 | Private portable C1 summary | same root, `source-corpus-summary.json`; top level exactly `schemaVersion`, `generatedAt`, `snapshotId`, `inputFingerprint`, `ledgerInputFingerprint`, `ledgerPath`, `toolVersions`, `operationIdentity`, `directChildSummaries`, `directChildReports`, `failureAttribution`, `nextAllowedAction`, `sourceCount`, `sourceFileCount`, `catalogedFileCount`, `explicitlyExcludedFileCount`, `sourceBytes`, `catalogedBytes`, `explicitlyExcludedBytes`, `sources`, `exclusions` | Must bind C1-O01 and all conservation totals; invalid or stale output is non-consumable |
| C1-E01 | Redacted execution handoff | external review record containing only the evidence checklist below | Never contains expanded manifest/root/tool-install paths, unrestricted logs, credentials, account or host identifiers |

### Exact JSON Subshapes

- C1-I01 source row is exactly string `sourceId`, exact source-kind `sourceKind`, and fully qualified string `rootPath`. No additional property is accepted.
- C1-I02 source row is exactly string `sourceId`, exact source-kind `sourceKind`, and lowercase-64-hex `rootFingerprint`. No additional property is accepted.
- C1-O01 tool-version row is exactly `toolName`, `version`. Source row is exactly `sourceId`, `sourceKind`, `capturedAt`, `rootFingerprint`. File row is exactly `snapshotId`, `sourceId`, `sourceKind`, `relativePath`, `sizeBytes`, `sha256`, `capturedAt`, `containerKind`, `parseStatus`, `disposition`, `evidence`, `status`; nested `status` is exactly `corpus`, `extraction`, `semantics`, `unity`, `disposition`. The object list is exactly empty for C1.
- C1-O02 tool-version rows use the same exact shape. Source-summary row is exactly `sourceId`, `sourceKind`, `rootFingerprint`, `sourceFileCount`, `sourceBytes`. Exclusion row is exactly `sourceId`, `relativePath`, `sizeBytes`, `reason`. Direct-child arrays contain portable paths only.
- Counts are nonnegative integers, byte totals are nonnegative 64-bit integers, hashes are lowercase 64-hex, timestamps are valid ISO-8601, and portable paths reject roots, URIs, dot segments, duplicates, and case-only collisions.

The operation identity is exactly `C1.SourceCorpusSnapshot.Refresh`. File fingerprints hash exact file bytes. Root and aggregate fingerprints use the frozen C1 canonical NUL/LF framing and Ordinal ordering. Any source/file/path/content change propagates through the root fingerprint, aggregate input fingerprint, C1-O01, C1-O02, and PB-SP05 baseline result; no stale artifact remains valid by existence alone.

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

Any version or byte change requires a new R7 package commit and renewed exact approval. The Windows build is evidence only, not a portable source identity.

### Exact Protected Untracked Worktree Exception

This exception is part of PB-I02's pre-execution repository invariant. At C1 preflight and at the final end-state check, `git status --short` must contain exactly these two Ordinal-compared rows and no others:

```text
?? AGENTS.md
?? docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

The accepted protected entries are:

| Repository-relative path | Required SHA-256 |
|---|---|
| `AGENTS.md` | `397d256da9e5c126667bc39b427aff31be7dbbdb1e83f1a90ad6f7ab8c34fd6d` |
| `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md` | `11ed3a2d7d933087d564e388991c45e5887600682dbc4ed9446e6117d4a5247b` |

The accepted invariant is `protectedStatusEntryCount=2`, `protectedHashMismatchCount=0`, and `unexpectedStatusEntryCount=0`. A missing, extra, renamed, modified, staged, tracked, conflicted, or differently hashed row is PB-FT02 and Stop before source access. Comparison of the status-row set and paths is Ordinal; hashes compare lowercase hexadecimal values after validation.

This narrow exception applies only to C1 repository preflight. Neither protected file is a Phase B input, output, approval, evidence artifact, staging candidate, or commit candidate. The files must not be edited, deleted, moved, copied, staged, committed, or used to waive any other worktree change. Portable evidence may record their repository-relative paths, required/observed hashes, and the three counts above, but never their contents.

### Approved Source-Kind Vocabulary

The only source kinds that may appear are:

```text
PcInstall
PcPatchOrCache
AndroidApk
AndroidDataOrCache
```

The approval record must list the exact selected subset and exact stable `sourceId` set. A locally available root inside the approved boundary may not be silently omitted. Duplicate source IDs under `OrdinalIgnoreCase`, changed spelling/case, an unapproved kind, or any network/runtime-download source is Stop.

---

## Central Definition 2: Subject/Partition Registry

| ID | Universe and identity | Mutually exclusive partitions | Conservation and consumer |
|---|---|---|---|
| PB-SP01 approval rows | PB-A01 through PB-A12 by row ID | Confirmed, Pending, Rejected | `12 = confirmed + pending + rejected`; execution requires `12 = 12 + 0 + 0` |
| PB-SP02 manifest sources | every C1-I01 `sources` row by exact `sourceId` | ApprovedAvailable, InvalidOrUnavailable | `manifestSourceCount = approvedAvailableCount + invalidOrUnavailableCount`; execution requires invalid count zero |
| PB-SP03 source files | every file found under every ApprovedAvailable root by `(sourceId, portable relativePath)` | Cataloged, ExplicitlyExcluded | `sourceFileCount = catalogedFileCount + explicitlyExcludedFileCount`; same equation for bytes; every exclusion has a nonempty reason |
| PB-SP04 output artifacts | exactly C1-O01 and C1-O02 by artifact ID | ValidatedDiagnostic, Suppressed, Quarantined | `2 = validatedDiagnostic + suppressed + quarantined`; no partition authorizes C2 automatically |
| PB-SP05 baseline state | exactly one capture comparison by snapshot/input identity | ApprovedMatch, FirstCaptureCandidate, MismatchOrInvalid | `1 = approvedMatch + firstCaptureCandidate + mismatchOrInvalid`; only ApprovedMatch may support a later, separately reviewed C2 recommendation |

For each source ID, the source row count and bytes equal that source's ledger file rows plus exclusion rows. C1-O01 and C1-O02 must share exact snapshot, input fingerprint, source identities, counts, and bytes. Missing, null, empty, and unmatched are distinct and are never normalized into success.

Portable projection is lossless: source paths remain only in C1-I01; portable ledgers contain source IDs, kinds, relative paths, hashes, counts, and contract-approved evidence. A machine path in C1-O01, C1-O02, or C1-E01 is a projection failure and Stop.

---

## Central Definition 3: Failure Transition Table

Output vectors use `D` for a complete validated diagnostic capture, `S` for suppressed/absent, and `Q` for retained but quarantined/non-consumable. Every failure stops the operation and authorizes no retry or downstream stage.

| ID | Failure and stable subject | C1-O01/O02 vector | Rollback, isolation, and next action |
|---|---|---|---|
| PB-FT01 | Any PB-A row Pending/Rejected | `S,S` | Do not access manifest or sources; obtain a new exact approval record |
| PB-FT02 | Branch, execution HEAD, protected state, tool version, or registered SHA mismatch | `S,S` | Preserve repository state; prepare a new reviewed package if bytes changed |
| PB-FT03 | Runtime manifest missing, malformed, unapproved, or leaking sensitive values | `S,S` | Preserve the manifest outside Git; correct and reapprove it |
| PB-FT04 | Missing/unavailable root, duplicate identity, path collision, reparse point, symlink, junction, or boundary violation | `S,S` | No output root may be created; correct the exact owning prerequisite |
| PB-FT05 | Source access, enumeration, read, hash, or mutation error | `S,S` | Runner removes its known staging directory in `finally`; any residue is retained and treated as quarantined evidence |
| PB-FT06 | File/count/byte conservation or portable projection mismatch before publication | `S,S` | The writer contract rejects the generation before canonical output; do not edit expected values or retry |
| PB-FT07 | Pre-existing canonical output root, staging residue, insufficient disk, or unapproved path | `S,S` | Do not delete or reuse source-unknown state; request ownership/capacity review |
| PB-FT08 | Output write, move, internal post-move check, or interruption | `S,S` when the writer proves its rollback; otherwise `Q,Q` | The writer removes its just-published output on a caught internal failure and removes staging in `finally`; if absence cannot be proved, retain the ambiguous state for diagnosis |
| PB-FT09 | Post-write schema, fingerprint, identity, or gate validation failure | `Q,Q` | Preserve the complete output root in place as diagnostic-only; no automatic deletion, movement, repair, or retry |
| PB-FT10 | Approved baseline mismatch or invalid comparison | `Q,Q` | Record only redacted Failed/issueCount evidence; renewed review required |
| PB-FT11 | No approved baseline on first capture | `D,D` plus FirstCaptureCandidate | Stop after validation; human may review and separately freeze an outside-Git baseline; no retroactive C2 permission |
| PB-FT12 | Unexpected child/heavy process, network access, extraction, decoding, Unity, import, or source/output-boundary write | `S,S` or `Q,Q` according to whether canonical bytes exist | Stop immediately, preserve non-sensitive evidence, diagnose before any new authorization |

A known staging path created by the runner and a just-published canonical output owned by the same caught writer attempt are the only states it may clean automatically. Source roots, a pre-existing output root, unknown staging residue, a successfully returned output later rejected by external validation, and any ambiguous/quarantined state are never deleted by this authorization.

---

## Exact Operation And Output Roots

The only approved output root pattern is exactly:

```text
C:\SoftWork\WT\StellaGaia\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\Extracted\Threads\019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe\C1
```

It must not exist before the run. Every existing ancestor and source path chain must be free of reparse points, symlinks, and junctions. No output may be written to tracked fixtures, the source roots, `Assets/StellaGaia/Imported`, or another thread root.

The exact guarded command pattern is:

```powershell
$threadId = '019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe'
$outputRoot = "C:\SoftWork\WT\StellaGaia\$threadId\Extracted\Threads\$threadId\C1"
$sourceRootManifestPath = Read-Host 'Approved absolute path to the machine-local source-root manifest'
pwsh -NoProfile -File .\Tools\AssetImport\New-StellaSoraSourceCorpusSnapshot.ps1 -SourceRootManifestPath $sourceRootManifestPath -OutputRoot $outputRoot -ThreadId $threadId -RefreshSnapshot
```

No alternate flags, path, wrapper, callback, private seam, additional command, shell logging, transcription, or implicit retry is authorized. The manifest path may be visible in the trusted interactive console and local process inspection; if that violates local policy, stop and request a runner-contract change.

## Runtime-Only Manifest And Sensitive-Path Handling

- Inspect C1-I01 locally without printing or copying its path, `rootPath` values, contents, or fingerprints into shared logs, screenshots, Git, or this package.
- Disable or control PowerShell transcription, shared command logging, and command-history capture according to the approved local policy.
- Portable evidence may contain only approved source IDs/kinds, relative paths, counts, bytes, hashes, dispositions, contract-approved evidence paths, and redacted results.
- Credentials, tokens, account/host/user/volume identifiers, local tool-install paths, expanded manifest/root paths, and unrestricted stdout/stderr are machine-local only.
- Runtime network capture, CDN enumeration, downloads, server-side configuration retrieval, and account-specific acquisition are outside the source boundary.

## Disk Budget

The exact numeric `approvedCombinedStagedArtifactEstimateBytes` is PB-A06 and must be supplied by the human approval record without reading sources during R7. It must be a positive integer.

```text
requiredFreeSpaceBytes = max(1073741824, 2 * approvedCombinedStagedArtifactEstimateBytes)
```

Immediately before execution, available free space on the output volume must be at least `requiredFreeSpaceBytes`. The estimate covers the complete ledger and summary, staging, and retained diagnostic margin. An absent/invalid estimate, failed check, pre-existing output, or unknown residue is PB-FT07. The operator may not infer, lower, or replace the budget during the run.

## Stop Conditions

In addition to PB-FT01 through PB-FT12, stop on any changed start/end HEAD, source fingerprint, manifest identity, file during hashing, canonical path, source-kind/source-ID set, schema, serialization, process set, or approval identity. Stop on any need to weaken validation, edit expected values after seeing results, modify implementation during execution, or continue after an issue.

The command runs as one foreground `pwsh` process. The approved operator must interrupt that foreground process when PB-A12 `maximumRunDurationMinutes` expires; no background launcher or watchdog is authorized. After interruption, classify staging/canonical state under PB-FT08 and do not start another process.

One stop ends the authorized attempt. A retry always requires diagnosis plus a new exact approval record.

## Required Preflight And Acceptance Evidence

Reuse the fresh R6 audit as Phase A completion evidence; do not rerun it merely to fill this package. Immediately before a future authorized run, execute the six lightweight C0/C1 gates listed in the C1 runbook and require their exact Passed/zero-issue policies. Those preflight results are freshness evidence for the later execution HEAD, not a repeat of R6 product evidence.

C1-E01 must record only:

- worktree, branch, reviewed code baseline, authorization-package commit, start HEAD, and end HEAD;
- the exact two protected repository-relative status rows, their required/observed SHA-256 values, `protectedStatusEntryCount=2`, `protectedHashMismatchCount=0`, and `unexpectedStatusEntryCount=0`;
- PowerShell/Git versions and the frozen file hashes above;
- approval identity and PB-A row statuses;
- approved source IDs/kinds, never root paths;
- start/end time and duration;
- snapshot ID, aggregate input fingerprint, per-source root fingerprints, counts, bytes, and exclusions;
- exact canonical output root and redacted guarded command;
- contract-gate results, SP equations, baseline state, issue count, and failure attribution;
- staging cleanup, quarantine, and unexpected-process results;
- explicit statements that no C2, extraction, decoding, Unity, import, C3-C6, G5, source write, or retry occurred;
- final recommendation `Stop` or `Review`, never automatic downstream authorization.

## Exact Human Confirmation Record

Every row is currently `Pending`. Approval is valid only when the human supplies an external record identifying this package commit and changes every row to `Confirmed` with the required value. A broad message such as “continue,” “run Phase B,” or “use the assets” is insufficient.

| ID | Required exact confirmation | Current state |
|---|---|---|
| PB-A01 | Authorize exactly one diagnostic C1 `-RefreshSnapshot` attempt and no other operation | Pending |
| PB-A02 | Exact authorization-package commit equals execution HEAD on `codex/asset-corpus-integration` | Pending |
| PB-A03 | Runtime-only manifest record identity has been locally reviewed; exact selected source-kind and stable source-ID sets are supplied | Pending |
| PB-A04 | Every locally available root inside the approved boundary is included and available; no network/runtime source is included | Pending |
| PB-A05 | Baseline state is exactly `FirstCaptureNoBaseline` or `ApprovedBaselinePresent`; if present, its immutable record identity is supplied | Pending |
| PB-A06 | Positive integer `approvedCombinedStagedArtifactEstimateBytes` is supplied | Pending |
| PB-A07 | Free-space check meets `max(1 GiB, 2 * estimate)` and canonical output/staging boundaries are absent and safe | Pending |
| PB-A08 | PowerShell/Git versions and every frozen SHA-256 in this package are accepted exactly | Pending |
| PB-A09 | Canonical C1 output root and the no-reparse/no-alternate-root policy are accepted exactly | Pending |
| PB-A10 | The guarded command block is approved verbatim, with no wrapper, extra flag, extra command, or retry | Pending |
| PB-A11 | First capture and every nonmatching baseline result must Stop; C2 and all downstream stages remain unauthorized | Pending |
| PB-A12 | Trusted operator identity, positive integer `maximumRunDurationMinutes`, execution window, foreground-process cancellation authority, sensitive logging policy, and evidence-retention owner are supplied outside Git | Pending |

## Current Decision

```text
status=WAITING_FOR_EXACT_HUMAN_AUTHORIZATION
authorizedOperationCount=0
phaseBExecuted=false
c2Status=BLOCKED
nextAction=Obtain an external PB-A01-through-PB-A12 confirmation record for the exact package commit before any R8 command.
```
