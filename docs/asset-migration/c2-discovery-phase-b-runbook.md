# StellaSora C2 Phase B Fixture-To-Real Discovery Runbook

## Status And Scope

This is an instructions-only, fail-closed bridge from the completed C2 Phase A fixture implementation to a future real C2 discovery run. It does not authorize real source access, extraction, observation generation, publication, C3-C6, G5, Unity, import, or Phase B execution.

C2 Phase A intake through SP-09 publication is implemented and fixture-only verified through `6165be7a2b93352a94a9ae65ffb15aa1a6dcf004`. That verification proves the registered contracts, partitions, failure accounting, deterministic serialization, publication transaction, recovery, and locked-consumer behavior against committed fixtures and synthetic TEMP roots. It does not prove that a real input adapter or real observation producer exists.

This runbook may be used to prepare a separate Phase B authorization package. It must not be cited as the authorization itself.

## Current Hard Block

The current public entry `Invoke-C2DiscoveryIntakeGate` is fixture-only:

- AR-I01 through AR-I11 resolve to registered repository fixture and schema paths.
- The current C1 Phase B runner publishes `source-corpus-ledger.json` and `source-corpus-summary.json`, but no reviewed real C1-to-C2 AR-I01 handoff producer is implemented.
- Conditional observation authority is bound to exact blobs in one frozen Git commit.
- AR-O01 through AR-O05 publish to `Tools/AssetImport/Fixtures/DiscoveryGate` consumer paths.
- The publication transaction operates beneath `Temp/C2DiscoveryPublication` and validates the registered fixture generation.
- The lightweight-policy contract forbids real-asset reads, extraction, Unity, import, and creation of `Extracted` or `Assets/StellaGaia/Imported`.

Therefore there is currently no approved command that can consume a real C1 handoff, generate real AR-I07/08/09 observations, or publish a real C2 generation. Running the existing public entry validates the committed fixture generation only.

Do not work around this block by:

- copying real ledgers, observations, extracted objects, or evidence into `Tools/AssetImport/Fixtures`;
- editing fixture paths, expected-input manifests, registered hashes, or Git blobs to point at machine-local inputs;
- placing real data in tracked files or using a fixture commit as a real-data approval mechanism;
- invoking private test seams, mutators, alternate roots, callbacks, or fault injectors as an operational entry;
- calling extraction or third-party tools directly before their exact operations and outputs are approved;
- treating a Passed fixture result as evidence that real C2 discovery ran.

Any real execution remains `BLOCKED` until the adapter and producer requirements below are implemented, independently reviewed, fixture-tested, and explicitly authorized.

## Authority And Contract Order

Before preparing a Phase B request, read the current versions of these materials completely:

1. repository `AGENTS.md`;
2. `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`;
3. `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`;
4. `docs/asset-migration/source-corpus-phase-b-runbook.md`;
5. the current C2 SP-09 publication plan and completion roadmap;
6. the reviewed future real-input adapter/producer contract and its exact commit.

The three C2 central registries remain authoritative. A Phase B adapter may parameterize machine-local input and output locations, but it may not redefine artifact shapes, identities, partitions, conservation equations, failure ownership, output vectors, or publication semantics.

If a real-path requirement cannot be represented without changing a registry row, stop and request a reviewed C2 contract change. Do not encode a second model only in an operational script or local manifest.

## Required Future Phase B Components

All components in this section are currently absent unless a later reviewed commit explicitly supplies them. Their absence is `Stop`, not permission to improvise.

### Real-input adapter

The adapter must:

- accept an explicitly approved, machine-local C1 artifact root without copying machine paths into portable artifacts;
- require a separately reviewed real C1-to-C2 handoff producer and contract; absence of AR-I01 is `Stop`;
- read the resulting approved C1 handoff, ledger, and summary as immutable inputs;
- prove exact C1 snapshot identity, input fingerprint, source/file/byte conservation, and baseline approval before observation work;
- map real input artifacts to AR-I01 through AR-I06 without weakening their schemas or freshness rules;
- accept real AR-I07/08/09 observation documents from a separate staging root under `Extracted`, never from tracked fixture paths;
- bind real observation inputs and any AR-I11 exclusions to a reviewed, immutable Phase B authority manifest that cannot bless its own just-read bytes;
- freeze start and end operation identities and reject input mutation during the run;
- expose no arbitrary reader, writer, callback, process object, filesystem object, or alternate unreviewed output root.

### Observation producers

Every producer must have a reviewed manifest row containing:

- stable tool and operation identity;
- exact executable or script path and SHA-256;
- tool version and acquisition provenance;
- permitted input source kinds and file/container selectors;
- exact output artifact and row type: AR-I07, AR-I08, or AR-I09;
- deterministic identity/fingerprint rules used by the registered C2 contract;
- permitted child processes and expected process count;
- read boundary, write boundary, maximum output estimate, timeout, and cancellation behavior;
- failure, partial-output, retry, rollback, and quarantine behavior;
- license and redistribution restrictions;
- explicit confirmation that Unity and import are not invoked.

A producer may emit an observation or an explicit opaque/failed result. It may not silently omit an attempted subject, convert a failure to success, assign a canonical group without registered evidence, or write directly to C2 consumer outputs.

### Real publication root

A reviewed contract change must freeze a real C2 generation root under the approved `Extracted` boundary. It must define:

- exact portable and machine-local path mapping;
- same-volume stage, backup, quarantine, lock, and journal locations;
- the eight physical SP-09 consumer paths in fixed transaction order;
- collision and pre-existing-generation rules;
- consumer lock and generation-fingerprint validation;
- retention and cleanup rules for failed, restored, and quarantined transactions;
- how real generations remain separate from tracked fixtures and `Assets/StellaGaia/Imported`.

The current fixture consumer paths are never a valid real publication root.

## Phase B Authorization Package

The human approval request must identify all of the following exactly. A missing item is `Stop`.

- target repository, worktree, branch, base commit, and HEAD commit;
- the reviewed real-input adapter commit and SHA-256;
- the approved C1 artifact root identity, snapshot ID, and redacted baseline-comparison result;
- the machine-local C1 manifest and baseline record identities without disclosing their paths or contents in portable evidence;
- every observation producer, version, hash, allowed operation, and child-process expectation;
- approved source kinds and selectors, without portable machine source paths;
- approved real observation staging root and real C2 generation root;
- expected input count/bytes and conservative staged/publication storage estimate;
- maximum run duration, cancellation mechanism, and operator identity;
- all expected portable artifacts, private artifacts, diagnostic artifacts, and machine-local operational files;
- exact stop, rollback, quarantine, cleanup, and evidence-retention rules;
- confirmation that no Unity, import, C3-C6, G5, or `Assets/StellaGaia/Imported` operation is authorized;
- confirmation that a first real run is diagnostic-only and cannot authorize downstream work without separate review.

Approval must quote the exact command generated by the reviewed future adapter documentation. Broad permission such as “run C2,” “continue Phase B,” or “use the assets” is insufficient.

## Machine-Local And Portable Boundaries

Machine-local only:

- absolute source-root and manifest paths;
- account, host, volume, and user identifiers;
- local tool-install paths;
- TEMP, stage, backup, quarantine, lock, and journal paths;
- unrestricted tool stdout/stderr that may reveal local paths;
- the human approval record if it contains local paths or sensitive fingerprints.

Portable artifacts may contain only registered source IDs, source kinds, portable relative paths, registered identities, counts, byte counts, hashes, tool names/versions, dispositions, evidence paths, failure attribution, and next actions permitted by the C2 contract.

Never place absolute source paths, manifest paths, credentials, tokens, account identifiers, or unrestricted console logs in Git, AR-O01 through AR-O05, review screenshots, or handoff text.

## Preparation Procedure

These steps prepare evidence for authorization. They do not access real sources or execute Phase B.

### 1. Verify the Phase A baseline

From the intended implementation worktree, run every current `Test-C2DiscoveryIntakeGate.ps1` ValidateSet case and the directly dependent C0/C1/minimal regressions. Require all test processes to exit zero and inspect every reported state.

In particular, require:

- complete terminal input accounting and the five registered contract checks;
- canonical provenance validation for status, platform scope, equivalence, member platform/content facts, missing members, and overlap;
- SP-07 dispatch conservation with no missing or duplicate object;
- Passed `5=5+0+0`, ordinary Failed `5=1+4+0`, and FT-12 `5=0+5+0`;
- successful rollback/recovery, no half-published consumer generation, and no TEMP sandbox leak;
- zero real-asset reads, heavy operations, Unity/import attempts, and forbidden-path creation.

### 2. Verify repository and path safety

Record `git status --short --branch`, `git rev-parse HEAD`, PowerShell version, and exact hashes of the future adapter and producer files. Stop on an unexpected worktree change, commit mismatch, path collision, reparse point, symlink, junction, or pre-existing unreviewed generation.

Do not inspect or delete a source-unknown `Extracted`, publication, backup, or quarantine path. Preserve it and request ownership review.

### 3. Review the C1 handoff without source access

Use only the approved C1 portable artifacts and redacted baseline result during preparation. Confirm that the future adapter will require:

- exact snapshot and input identity agreement across handoff, ledger, and summary;
- accepted C1 schemas and registered status vocabulary;
- file and byte conservation;
- an approved baseline comparison;
- no machine-path leakage;
- no implicit refresh of the C1 snapshot.

Any missing or stale C1 prerequisite keeps C2 Phase B blocked.

### 4. Review producer coverage

Construct a prospective coverage table from the C1 ledger without opening real source files. Every C1 file subject must have exactly one planned route:

- one or more approved observation producers;
- explicit `NotAttempted` pending a later authorization; or
- an approved exclusion represented by the registered C2 exclusion contract.

The plan must account for every file and byte. It must not claim object, configuration, or canonical coverage before producers run.

### 5. Review storage and transaction capacity

Require approved numeric estimates for observation staging, diagnostic evidence, and one complete publication generation plus backup/quarantine margin. Free space must satisfy the stricter future adapter contract. Do not infer or lower the estimate during execution.

### 6. Freeze the command and request approval

Only a reviewed future adapter may supply the guarded command. Record it in redacted form with exact flags and canonical C1/C2 artifact roots while omitting machine-local manifest and source paths.

If no reviewed command exists, the result of this preparation procedure is:

```text
status=BLOCKED
nextAction=Implement and independently review the C2 real-input adapter, observation-producer contracts, and real publication-root contract.
```

## Future Guarded Execution Sequence

This section defines ordering for a future separately authorized run. It is not executable until every required component and exact command has been reviewed.

1. Acquire the real C2 operation lock before reading inputs or creating stage paths.
2. Recover, restore, or quarantine any prior transaction using exact journal and content hashes. Ambiguity is FT-12 and `Stop`.
3. Revalidate repository HEAD, adapter/producer hashes, approval identity, C1 baseline result, free space, and empty approved staging boundary.
4. Read the approved C1 portable artifacts and freeze their exact bytes and fingerprints.
5. Run only the approved producers in manifest order. Write observations and evidence to the approved real staging root.
6. Account for every attempted input and producer outcome. Preserve opaque and failed subjects; do not retry without a new reasoned authorization.
7. Build and independently validate the immutable real-input authority manifest and any exclusion approvals.
8. Invoke the reviewed real-input adapter. It must execute the same registered AR/SP/FT model as Phase A without reading tracked fixtures as real evidence.
9. Stage all desired outputs, validate shapes and fingerprints, then publish through the reviewed SP-09 transaction with summary last.
10. Use the locked consumer validator to read the published generation. Failed, partial, stale, or hash-mismatched generations are diagnostic-only or rejected.
11. Revalidate end HEAD and all frozen input identities. Any change invalidates the run.
12. Compare final filesystem state with the approved pre-run snapshot and record retained diagnostics or quarantine paths.

The first separately authorized real run is diagnostic-only even if the gate reports Passed. It must stop for human review and cannot authorize C3-C6, G5, Unity, import, or another Phase B operation.

## Stop Conditions

Stop immediately on any of these conditions:

- a missing, stale, unapproved, or schema-invalid C1 prerequisite;
- a changed HEAD, adapter, producer, manifest, source fingerprint, or frozen input during the run;
- a source, staging, output, backup, journal, or quarantine path outside the approved boundary;
- a reparse point, symlink, junction, case collision, identity collision, or unsafe relative path;
- an unregistered tool, child process, network operation, runtime download, Unity launch, or import attempt;
- a producer shape, identity, fingerprint, coverage, or terminal-accounting failure;
- missing, duplicate, overlapping, or contradictory canonical provenance;
- missing or duplicate dispatch subjects;
- any SP conservation or byte-conservation mismatch;
- an invalid AR-S12 projection or public/private information loss;
- an output shape, CT-15 serialization, child hash, HI-13c, HI-14, or HI-16 mismatch;
- lock, stage, journal, backup, install, verification, rollback, recovery, or quarantine failure;
- a partial consumer generation or failure to restore the exact pre-run state;
- creation or modification of `Assets/StellaGaia/Imported`, Unity caches, tracked fixtures, or source roots;
- any need to weaken validation, edit expected values after reading results, or modify implementation during the run.

Do not continue to a later stage after a stop. Preserve non-sensitive evidence, identify the single owning FT transition when possible, and request a minimal correction Task or renewed special authorization.

## Conditional Success Review

A future run is eligible for human review only when all of these are true:

- C1 identity, freshness, schema, and conservation checks pass;
- every producer and adapter identity matches the approval package;
- every actual input and observation has terminal SP-08 accounting;
- SP-01 through SP-09 conservation equations hold simultaneously;
- all required public/private projections are lossless and the exact AR-S12 state matches the registered AR-I06 contract;
- the publication transaction commits one complete generation and the locked consumer accepts it;
- the end HEAD and frozen input identities match their start values;
- no source, fixture, forbidden path, Unity cache, or unapproved output was modified;
- pre-run and post-run operational state differences are completely explained by approved retained evidence;
- the run produces a diagnostic-only recommendation of `Review`, never automatic downstream authorization.

If any condition fails, the recommendation is `Stop`.

## Handoff Evidence Checklist

Record only approved, non-sensitive evidence:

- worktree, branch, base SHA, start HEAD, and end HEAD;
- approval package identity and reviewed adapter/producer hashes;
- C1 snapshot ID, source IDs/kinds, aggregate counts/bytes, and redacted baseline result;
- C2 operation identity, start/end time, duration, and PowerShell version;
- producer outcomes by stable subject and tool identity;
- observation, exclusion, conflict, and contract-check counts;
- every SP-01 through SP-09 conservation result;
- gate status, issue count, output vector, failure attribution, and next allowed action;
- discovery input, artifact-set, diagnostic-bundle, and transaction fingerprints permitted by policy;
- real C2 artifact root identity without machine source paths;
- rollback, recovery, cleanup, and quarantine results;
- explicit statements that Unity, import, C3-C6, G5, and downstream authorization did not occur;
- final recommendation: `Stop` or `Review`.

Do not record absolute source/manifest/tool-install paths, credentials, account data, unrestricted logs, or source content in portable evidence.

## Decision And Next Action

At the current repository state, the only valid result is:

```text
status=BLOCKED
reason=The implemented C2 public entry and publication paths are fixture-only; no reviewed real-input adapter, observation-producer set, or real publication-root contract exists.
nextAction=Implement those components in separate Phase A Tasks, verify them with fixtures and fault vectors, then request exact human authorization for one diagnostic-only C2 Phase B run.
```

This runbook does not authorize that implementation Task or the later Phase B run.
