# StellaSora C2 SP-09 Journaled Publication Plan

**Date:** 2026-07-15
**Status:** Tasks 0–3 implemented through `6165be7a2b93352a94a9ae65ffb15aa1a6dcf004`; complete fixture-only verification passed at that commit
**Baseline:** `codex/asset-corpus-integration` at `6165be7a2b93352a94a9ae65ffb15aa1a6dcf004`
**Scope:** deterministic AR-O01–AR-O05 serialization, SP-09 accounting, same-volume journaled publication, crash recovery, and locked consumer validation. No C3–C6 implementation, G5 decision, schema changes, Unity, extraction, import, real assets, Phase B, or release packaging.

## 1. Authorization And Stop Boundaries

This plan contains three implementation Tasks because pure byte construction, the filesystem transaction, and production wiring have different failure owners and independent stop checkpoints. One user authorization executes one Task and creates one independent commit. Approval of this plan authorizes no implementation by itself.

Implementation record: Task 0 is `79ea93c89aed88ba7e31ffd6ecb69a0d0a1efdef`, Task 1 is `eacd57a`, Task 2 is `f8d97b8`, the complete-input-accounting correction is `8b40672`, and Task 3 is `6165be7`. At `6165be7`, every registered C2 fixture case, the minimal object gate, and the directly dependent C0/C1 regressions pass; publication tests restore the exact pre-test consumer and TEMP state. This closes C2 Phase A code implementation and fixture-only publication verification only. C2 Phase B remains unauthorized, its runbook is the next independent Task, and C3–C6 definition and implementation have not started.

Task 0 is this docs-only amendment. It modifies only:

- `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`
- `docs/superpowers/plans/2026-07-15-stella-sora-asset-corpus-c2-sp09-publication.md`

Tasks 1 and 2 modify only:

- `Tools/AssetImport/C2DiscoveryIntakeGate.psm1`
- `Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1`

Task 3 modifies only the same two scripts. Its focused natural-entry test may transiently publish the four diagnostic components, validate them, and restore the exact pre-test consumer state in harness `finally`; no registered output is staged or committed. It must not leave AR-O01 through AR-O04 because the audited integration vector is an ordinary Failed run.

Every Task stops after its own commit. Existing untracked `AGENTS.md` and `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md` remain unstaged. Never use `git add .`.

## 2. Narrow Artifact Registry

The fixed consumer transaction order is:

| Index | Artifact | Portable path | Passed | Ordinary Failed | FT-12 |
| --- | --- | --- | --- | --- | --- |
| 00 | AR-O01 | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-c2-source-corpus-ledger.json` | Present | Absent/suppressed | no new file |
| 01 | AR-O02 | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-resolved-configuration-package.json` | Present | Absent/suppressed | no new file |
| 02 | AR-O03 | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-canonical-group-package.json` | Present | Absent/suppressed | no new file |
| 03 | AR-O04 | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-object-dispatch.json` | Present | Absent/suppressed | no new file |
| 04 | AR-O05/report | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-report.md` | Present | Present diagnostic | no new file |
| 05 | AR-O05/sidecar | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-evidence.json` | Present | Present diagnostic | no new file |
| 06 | AR-S12 | `Tools/AssetImport/Fixtures/DiscoveryGate/c0-contract-change-request.json` | Present | Present diagnostic | no new file |
| 07 | AR-O05/summary | `Tools/AssetImport/Fixtures/DiscoveryGate/valid-discovery-summary.json` | Present, installed last | Present diagnostic, installed last | no new file |

AR-O05 is one logical SP-09 subject despite four physical components. Its HI-14 fingerprint covers all four. The summary JSON itself is excluded from HI-13c; HI-13c contains indexes 00–06 on Passed and 04–06 on ordinary Failed.

Operational files are not artifacts:

```text
Temp/C2DiscoveryPublication/publication.lock
Temp/C2DiscoveryPublication/active-journal.json
Temp/C2DiscoveryPublication/active-journal.json.next
Temp/C2DiscoveryPublication/transactions/<HI-16 digest suffix>/stage/00..07
Temp/C2DiscoveryPublication/transactions/<HI-16 digest suffix>/backup/00..07
Temp/C2DiscoveryPublication/transactions/<HI-16 digest suffix>/quarantine/**
```

`Temp/` is already ignored by `.gitignore`; no ignore-file change is permitted. The directory leaf is exactly the 64 lowercase-hex suffix, never the full prefixed HI-16, because `:` is invalid in a Windows directory name.

## 3. Subject/Partition Registry

The SP-09 universe is always `{AR-O01,AR-O02,AR-O03,AR-O04,AR-O05}`. Partitions are mutually exclusive:

```text
outputCandidateCount
= projectedOutputCount
 + outputFailureCount
 + excludedOutputCount

outputCandidateCount=5
excludedOutputCount=0
```

Exact vectors:

```text
Passed:          5=5+0+0
Ordinary Failed: 5=1+4+0
FT-12:           5=0+5+0
```

AR-O05 is ProjectedOutput only after all four diagnostic components commit and validate as one generation. On ordinary Failed, AR-O01–AR-O04 each own one persisted `SuppressedByGate` output failure; they are not also absent subjects or exclusions. On FT-12, AR-O01–AR-O05 each own one terminal-only `ProjectionInvalid` row; no persisted row exists because AR-O05 failed.

## 4. Failure Transition Table

| Vector | Unique owner | Required state | Accounting/output |
| --- | --- | --- | --- |
| CT-15 or registered output shape invalid before journal | FT-12 publication transaction | no consumer path touched | terminal `0/5/0` |
| lock open/acquire failure | FT-12 publication transaction | no journal or consumer mutation | terminal `0/5/0` |
| stage write/flush/hash/readback failure | FT-12 failing AR-O identity | rollback stage only | terminal `0/5/0` |
| journal `.next` write/flush/replace failure | FT-12 publication transaction | recover using exact hashes | restored prior generation or quarantine; terminal `0/5/0` |
| backup/install/verify failure | FT-12 exact failing AR-O identity | `RollingBack` | restored prior generation or quarantine; terminal `0/5/0` |
| ambiguous or unknown recovery bytes | FT-12 publication transaction | `Quarantined`, no consumer paths | terminal `0/5/0` |
| ordinary upstream InputFailure with successful diagnostic transaction | upstream FT remains owner | AR-O01–04 absent, diagnostic committed | persisted `1/4/0`; no additional issue |
| consumer observes missing/hash-mismatched child under Passed summary | FT-12 stale/partial generation | reject entire generation | no downstream authorization |

Fault injection is private and enum-only. Allowed focused fault points are exactly `LockOpen`, `Stage05Write`, `JournalPreparedReplace`, `Backup02Move`, `Install04Move`, `Install07Move`, `Verify06Hash`, `Rollback01Restore`, and `RecoveryAmbiguous`. No ScriptBlock, callback, process object, filesystem object, or arbitrary path is accepted.

## 5. Frozen Serialization And Publication Vectors

### 5.1 Passed pure vector

Use a synthetic fully Passed normalized state with the same accepted AR-I identities, snapshot and fingerprints as the audited fixture, but remove r5, r6 approval/exclusion, and gConflict and retain one resolved object. The private focused clock fact is exactly `2026-07-15T00:00:00Z`; it is enum-selected and is not a callback. The public entry instead captures one actual UTC `generatedAt` ending `Z` and propagates it unchanged through every output. The pure vector must construct all eight registered outputs in memory. Expected SP-09 is `5/5/0/0`; every `outputFailures/outputExclusions` array is empty.

Exact HI-16 inputs and results are:

```text
snapshotId=snapshot-pc-install-001
generatedAt=2026-07-15T00:00:00Z
inputFingerprint=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
Passed discoveryInputFingerprint=8a2e24d787415e8f71546126ca4748fff240c91a1657c89a3e0d7ec93daa69a9
Passed transactionId=publication-sha256:5a882381d1c8d0577e2c385f707e495b5bb07123daca5ed12c32b147a6c01cf2
Failed discoveryInputFingerprint=null
Failed transactionId=publication-sha256:900e21ceb48919fd34e0e6fc16cb68f7f66206280a4e2664b67a64a335cf9c8b
```

The nullable fingerprint contract is uniform across every diagnostic component. AR-S05 sidecar, AR-S11 `identity`, and AR-S12 always contain `discoveryInputFingerprint` in their registered property position. Passed stores the non-null CT-04 value above; ordinary Failed stores JSON null. Missing and empty-string forms are invalid. The report projects the same state as the 64-hex value on Passed or the lowercase literal `null` on ordinary Failed. AR-S11 `identity.discoveryArtifactFingerprint` remains a non-null CT-04 value after either Passed or ordinary-Failed diagnostic serialization succeeds.

The harness must hard-code, not call production helpers for expected values:

- every top-level and nested property order for AR-S06 through AR-S12;
- exact CT-15 bytes and SHA-256 for all eight outputs;
- exact HI-13c and HI-14 preimages/digests;
- exact report bytes, LF behavior, and final LF;
- summary installed-last index 07;
- exact HI-16 preimage and literal transaction ID.

Literal hashes are computed from the frozen bytes during RED preparation, reviewed in the test source, and never generated by the same production serializer used for actual values.

### 5.2 Ordinary Failed integration vector

Use the audited `24=21+2+1+0` input vector. Its direct failures remain r5 FT-05 and gConflict FT-07. Expected output state:

```text
gateStatus=Failed
discoveryInputFingerprint=null
desired Present indexes={04,05,06,07}
desired Absent indexes={00,01,02,03}
outputCandidateCount=5
projectedOutputCount=1
outputFailureCount=4
excludedOutputCount=0
issueCount=2
```

For this vector, the complete exact nullability assertions are: AR-S05 `discoveryInputFingerprint=null`, AR-S11 `identity.discoveryInputFingerprint=null`, AR-S12 `discoveryInputFingerprint=null`, and the report line is exactly `discoveryInputFingerprint: null`. Every field remains present in its frozen property order. A missing field, empty string, non-CT-04 non-null value, or disagreement among these four projections is FT-11 and suppresses publication.

The four persisted output failures have exact AR-S10 shape, `reasonCode=SuppressedByGate`, attribution `SuppressedByGate:<AR-O ID>`, and evidence exactly:

```text
Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r3.json
Tools/AssetImport/Fixtures/DiscoveryGate/Evidence/r4.json
Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json
```

Their literal record IDs are:

```text
AR-O01=accounting-sha256:9f1138f02085b330db3fb53ec2e65e548c4cdb92b3127eddeab4122121217be3
AR-O02=accounting-sha256:546edc1d608856e62a1a0b99b5f580c06ef330e20708c52d5ce3bf9419878eda
AR-O03=accounting-sha256:b569af8a77bbd095f11d564f181afc34d3f67d2e0f5f703d59ed583570282df4
AR-O04=accounting-sha256:d1576932c592de68a24745fe2c6539d461398b1df33e31b7be68577d92835a65
```

They do not increase `issueCount`. HI-13c includes only report, sidecar, and AR-S12. Summary is excluded from HI-13c and included in HI-14.

### 5.3 Transaction state vectors

- Empty prior state + Passed: eight verified paths, no journal/transaction directory afterward.
- Complete prior generation + Passed replacement: exact prior bytes restored on every injected failure.
- Complete prior generation + ordinary Failed: indexes 00–03 removed, indexes 04–07 replaced, diagnostic summary last.
- Crash before Prepared: a stage-only orphan is safely removed; an orphan with backup/quarantine or unknown content is quarantined and fails FT-12.
- Crash after backup and crash after child install: next invocation recovers before preparing a new transaction.
- Unknown consumer byte during recovery: all extant transaction and consumer components quarantined; all eight consumer paths absent.
- Lock contention: second publisher returns FT-12 without modifying journal, stage, backup, quarantine, or consumers.

Every vector asserts actual bytes, hashes, journal shape/phase, move state, cleanup, output accounting, and forbidden-path non-creation.

## 6. Task 1 — Pure Output Serialization (20–30 minutes)

**Exact files:** the two scripts in Section 1.

1. **RED output shapes (2–5 min).** Add `-Case OutputSerialization`; hard-code complete Passed and ordinary-Failed AR-S06–AR-S12 objects and property order.
2. **CT-15 serializer (2–5 min).** Implement the registered deterministic JSON/report encoding without filesystem access or serializer-dependent ordering.
3. **Fingerprints (2–5 min).** Implement HI-13c, HI-14, and HI-16 with exact nested framing; freeze literal digests.
4. **SP-09 accounting (2–5 min).** Derive `5/5/0/0` and `5/1/4/0` from desired artifact sets; construct exact suppression rows.
5. **Negative shapes (2–5 min).** Reject extra/missing/reordered fields, invalid CT-15 scalar, summary self-inclusion, wrong child set, and duplicate output identity.
6. **GREEN/checkpoint (2–5 min).** Run focused case, all prior focused cases, minimal gate, AST and diff/scope checks; commit and stop.

Focused command:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case OutputSerialization
```

**Stop:** no filesystem publisher, output fixture, lock, journal, or consumer path.

## 7. Task 2 — Journaled Publisher And Recovery (20–30 minutes)

**Exact files:** the two scripts in Section 1. Requires approved Task 1 commit.

1. **RED journal contract (2–5 min).** Add `-Case PublicationTransaction`; freeze HI-16 directory, journal/entry shape, phases, states, and fixed path order.
2. **Lock/stage (2–5 min).** Implement FileShare.None lock and CT-15 stage/write/flush/readback under fixed Temp test roots.
3. **Backup/install/verify (2–5 min).** Implement journaled eight-entry state machine with summary last and desired-Absent handling.
4. **Rollback/recovery (2–5 min).** Reconcile journal with exact consumer/stage/backup hashes; restore or quarantine without guessing.
5. **FT-12 matrix (2–5 min).** Run every enum fault point, contention, crash-resume, ambiguous-byte, and cleanup vector; assert terminal `0/5/0`.
6. **GREEN/checkpoint (2–5 min).** Run all focused/regression/AST/scope/forbidden-path checks, require empty test sandboxes, commit and stop.

Focused command:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case PublicationTransaction
```

**Stop:** do not wire the public gate or create registered outputs.

## 8. Task 3 — Production Wiring And Diagnostic Generation (20–30 minutes)

**Exact files:** the same two scripts. No registered output is staged or committed.

Requires approved Task 2 commit. Opening gate: all eight registered output paths must be absent or match an independently approved prior SP-09 generation; any source-unknown path stops the Task.

1. **RED natural entry (2–5 min).** Add `-Case PublicationIntegration`; prove the public gate reaches the same publisher with no bypass or alternate public root.
2. **Wire ordinary Failed (2–5 min).** Feed the audited 24-subject result, derive four suppression rows, serialize four diagnostic components, and publish them atomically.
3. **Locked reader (2–5 min).** Add a registered consumer validator that acquires the same lock and rejects Failed, partial, stale, or hash-mismatched generations.
4. **Real registered-path proof (2–5 min).** Snapshot all eight pre-test consumer states, run the public gate once, require AR-O01–04 absent and the four diagnostics valid, then restore every pre-test byte in harness `finally`; source-unknown pre-existing files block the vector.
5. **Fresh rerun/recovery (2–5 min).** In the same controlled vector, rerun idempotently, prove seven Git calls, stable HEAD and no Temp transaction residue except the empty lock file, then prove the post-test repository bytes equal the pre-test snapshot.
6. **GREEN/checkpoint (2–5 min).** Run all focused cases, minimal regression, AST, cached scope, and forbidden-path checks; stage exactly two scripts, commit and stop.

Focused command:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case PublicationIntegration
```

**Stop:** the committed diagnostic is Failed and authorizes no C3–C6, G5, Unity, extraction, import, real assets, or Phase B.

## 9. Common Verification

After each implementation Task:

```powershell
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case <new-case>
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case InputAccounting
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case DispatchPartitions
pwsh -NoProfile -File Tools/AssetImport/Test-C2DiscoveryIntakeGate.ps1 -Case Integration
pwsh -NoProfile -File Tools/AssetImport/Test-MinimalObjectDiscoveryGate.ps1
git diff --check
git status --short
git diff --name-only
Test-Path -LiteralPath Extracted
Test-Path -LiteralPath Assets/StellaGaia/Imported
```

Task 1 and Task 2 run every existing focused case. Task 3 additionally reruns `GitAdapter`, `FileFixtureIntake`, and every publication case under normal-user Git permissions. Both scripts require zero PowerShell syntax errors and zero unauthorized filesystem/process/native/dynamic/Unity/extraction/import AST findings. Tests must assert that every created Temp path is within the registered publication roots before cleanup.

## 10. Deferred Work

- C3–C6 consumers beyond the locked validation primitive.
- C0 schema modification and final G5 decision; AR-S12 remains Required.
- A Passed real C2 generation. The current audited fixture intentionally publishes a Failed diagnostic generation.
- Unity, extraction, import, real StellaSora assets, Phase B, release packaging, and canonical expansion.
