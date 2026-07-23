# StellaSora Phase B R7-R13 Program Roadmap

> **Status:** PROGRAM ROADMAP ONLY; NOT A DIRECTLY EXECUTABLE PLAN. Every Work Package below remains blocked until a separate child Task plan satisfies the Mandatory Task Template and receives the required authorization.
>
> **Authority boundary:** C1 uses `PersonalLocalMode`: no PB-A form or external compliance identity. R8.1 automatically locates PB-I03 at the fixed LocalAppData-relative path, proves its declared boundary equals the manifest source set, derives all remaining preflight state, and the user confirms once with `ConfirmPersonalLocalRun` immediately before the LO. This Roadmap itself does not read a real locator/manifest/source root, start a heavy operation, or permit C1/C2/extraction/staging/Unity/import/G5/merge/cleanup.
>
> **Execution cadence:** one separately written child Task per turn, 20-30 minutes maximum. Each child Task Step is one 2-5 minute action. A command that cannot safely finish inside one child Task is a Special Long-Running Operation, not an ordinary Task, and requires the separate gate defined below.

## 2026-07-18 Single Character End-to-End Restoration Gate Override

This override has priority over the completed historical Fast Feasibility Spike override and all R8-R13 work. It is the only active route until it reaches its terminal result.

### Normative source, synchronization, and legacy-body rule

- `NormativeSource=docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md`. The CERG override in `docs/superpowers/plans/2026-07-17-stella-sora-phase-b-r7-r13-complete-execution.md` is a required mirror for discoverability and is not an independent authority.
- Every CERG revision must modify the normative source first and update the mirror in the same commit. The UTF-8 text from this override heading through the line immediately before `## 2026-07-18 Fast Feasibility Spike Override` must be identical in both files. Any divergence sets `CERGOverrideSynchronized=false`, authorizes no Task or LO, and requires a docs-only correction.
- All text below this override is retained historical context only. Every lower `Status`, `Current`, `Current Stop Checkpoint`, `Immediate Next Checkpoint`, `Authorized`, and `nextAction` statement—including the old FFS and R8-R13 route—is `SupersededHistoricalText` and grants no execution authority while CERG is active.
- An executor must derive the current phase, budgets, authorization, and single next action only from this top override. It must not resume a lower legacy checkpoint even when that text calls itself current or approved.

### 2026-07-22 Missing Base AnimatorController Recovery Route

This subsection is the only active route after the user authorization `授权恢复路线`. It supersedes the earlier fixed-route stop only for the bounded work defined here. The completed route remains `FixedRouteFailed — MissingBaseAnimatorController`; that statement is not evidence that `char_14401` is intrinsically unrestorable. Existing R1/R2 artifacts, partial staging, P01-P06, D01, and terminal records remain immutable history and may be read only as explicitly listed below.

#### Scope, budgets, and sequence

- Historical CERG accounting remains `ordinaryTaskUsed=7/7`, `LOUsed=2/3`. This recovery has an independently authorized `recoveryOrdinaryTaskBudget=5`, `recoveryOrdinaryTaskUsed=1/5` after this docs-only T0, `recoveryLOBudget=1`, `recoveryLOUsed=0/1`, and a distinct one-shot `locatorReadAllowanceBudget=1`, `locatorReadAllowanceUsed=0/1`. The locator allowance is not an LO: after audited T1A, total control must separately authorize the exact TO01, root, implementations, arguments, selectors, four opens, and `NoLO=true`; it is irreversibly consumed `0→1` by atomic no-overwrite MBACR-A00 installation before any source open. A crash, cancellation, or interruption after A00 installation receives no refund or retry. The remaining global LO is consumed only on the first source-member open by the exact confirmed R3 extraction; it then makes global `LOUsed=3/3`. No fallback tool, second candidate family, or additional source search is implied.
- The only sequence is `MBACR-T0 contract → MBACR-T1A locator tools/fixtures → total-control audit → MBACR-T1B bounded read-only locator and lock → total-control audit → MBACR-T2 R3 preflight → exact human confirmation → LO-MBACR1 one R3 extraction → MBACR-T3 TG02/R01 replay and acceptance`.
- This T0 changes only the two synchronized roadmaps. It authorizes no source read, locator run, tool edit, Extracted write, staging, AssetRipper, TG02 replay, Unity, or LO.
- MBACR-T1A may implement/test one read-only locator and its independent validator using synthetic fixtures only, publish TO01 after the tool commit, and stop for audit. It cannot read source or publish A00/L01. MBACR-T1B may run only after the separate exact authorization `ConfirmExactMBACRLocatorRead TO01=<64-lowercase-hex> SourceId=pc-install RootFingerprint=<64-lowercase-hex> Producer=<implementationId> Validator=<implementationId> ArgumentsFingerprint=<64-lowercase-hex> Selectors=MBACR-S01,MBACR-S02 MaxTotalSourceOpens=4 NoLO=true`. Before any read, the producer must atomically install A00; that installation consumes the allowance even if no later open occurs. Only the same foreground invocation may then open each selector once as producer and once as independent validator, atomically publish L01, and stop for audit. This does not consume or authorize the remaining LO. T1B cannot edit tools, stage, copy, export, decode, invoke AssetRipper, or read any other source member.
- MBACR-T2 may consume only an audited `ControllerLocated` L01, revalidate the complete expanded member set immediately, and publish one no-overwrite R3 P01. It does not consume an LO. Exact confirmation is separate.
- LO-MBACR1 is one foreground attempt using the confirmed R3 P01. It stages and exports the complete expanded input set to a wholly new R3 root. It may not reuse or merge R1/R2 staging or Output and may not retry.
- MBACR-T3 runs TG02 once against immutable R3 D01, writes one no-overwrite R3 R01, and accepts recovery only when all eleven obligations are Resolved, `requiredMissingReferenceCount=0`, at least one Controller and AnimatorState exist, all four OverrideControllers resolve their base Controller, and the action/attack-FX graph closes. It never starts Unity. Success has sole next action `AwaitExplicitCERGT2AuthorizationAfterRecoveredR01`; any other outcome is `RecoveryRouteFailed` with scope `ThisBoundedControllerRecoveryDidNotCloseR01_NotIntrinsicAssetImpossibility`.

#### Canonical encoding

`CJ` means compact JSON encoded as UTF-8 without BOM: strings are NFC and case-preserved, JSON object properties use the order stated in each shape, integers use base-10 JSON numbers, null is JSON `null`, and arrays use the explicit order below. SHA-256 is over the exact CJ bytes and is lowercase hexadecimal. Every set is sorted by `StringComparer.Ordinal` and rejects duplicates before hashing.

#### Artifact Registry

| ID | Portable path and exact shape | Success/failure rule |
|---|---|---|
| `MBACR-I01` | `Extracted/CERG/SingleCharacter/LO-CERG1-R2/R01-P06/result.json`; fixed identity `1171925` bytes / `8a1a9826966666c426605a3bf0c4c8f1c62101a9d36bd65d9456732c38b2a92c` | Read-only evidence: `Unresolved`, zero obligation results, first direct error `The immutable attack anchor is not reachable from any serialized AnimatorState.` |
| `MBACR-I02` | C1 ledger `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json`; fixed identity `11792761` bytes / `4f28737b77aaf94dcd79272d37f9041144e913e9222f90f311236cb8f6a14fe8` | Supplies only the two selector tuples below; it is not freshness proof. |
| `MBACR-TO01` | `Extracted/CERG/SingleCharacter/Recovery-BaseController/tooling-readiness.json`; shape `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}` | Schema/ID `cerg-mbacr-tooling-readiness/1.0.0` / `MBACR-TO01`; temporary sibling adds `.tmp`; post-tool-commit canonical reopen and atomic no-overwrite install. It contains exactly two distinct tool rows and fourteen Passed fixture rows. |
| `MBACR-A00` | `Extracted/CERG/SingleCharacter/Recovery-BaseController/T1/locator-attempt.json`; shape `{schemaVersion,artifactId,contractHeadCommit,to01Sha256,locatorAuthorization,sourceRootBinding,producerBinding,validatorBinding,selectorPlan,allowanceUsedBeforeInstall,allowanceUsedAfterInstall,status,nextAction}` | Schema/ID `cerg-mbacr-locator-attempt/1.0.0` / `MBACR-A00`; temporary sibling adds `.tmp`; canonical reopen and atomic no-overwrite install before every source open. Its installation fixes `0→1`, status `ArmedNoSourceOpen`, and nextAction `RunExactFourLocatorOpens`; existing/invalid A00 forbids all opens and retry. |
| `MBACR-L01` | `Extracted/CERG/SingleCharacter/Recovery-BaseController/T1/controller-location.json`; shape `{schemaVersion,artifactId,contractHeadCommit,inputArtifactRefs,locatorAttemptRef,locatorAuthorization,sourceRootBinding,selectorRows,locationRows,openRows,openCounts,partitions,limits,producerBinding,validatorBinding,status,failures,nextAction}` | Schema/ID `cerg-mbacr-controller-location/1.0.0` / `MBACR-L01`; temporary sibling adds `.tmp`; canonical reopen and atomic no-overwrite install. Failed L01 is diagnostic only and never authorizes T2/LO. |
| `MBACR-P01` | `Extracted/CERG/SingleCharacter/LO-CERG1-R3/preflight.json`; shape `{schemaVersion,artifactId,candidateLockSha256,l01Sha256,baseMemberSetFingerprint,additionMemberSetFingerprint,expandedMemberSetFingerprint,candidateContractHeadCommit,locatorContractHeadCommit,contractHeadCommit,selectedCandidateId,createdAt,sourceRootBindings,implementationBindings,operation,aggregateLimits,stagingPlan,status,nextAction}` | Schema/ID `cerg-mbacr-r3-preflight/1.0.0` / `MBACR-P01`. Machine-private absolute paths occur only in this ignored artifact and never enter Git or conversation. The production constructor and an implementation-independent validator must each freshly reopen and validate every expanded member immediately before a canonical no-overwrite Green install; otherwise P01 is suppressed. |
| `MBACR-F02/A01/H01` | New R3 leaves `freshness-adjacency.json`, `attempt-state.json`, and `first-source-open.json` with the exact shapes below | All initially absent and no-overwrite. F02 is generated after confirmation by the same foreground runner; A01 installation consumes no LO; H01 is installed on the first source-member open within 10 seconds of `F02.validatorFinishedAtUtc`, changing global `LOUsed 2→3`. |
| `MBACR-SI01/D01` | New root `Extracted/CERG/SingleCharacter/LO-CERG1-R3/`; staging inventory `staging-inventory.json`, new `Input`, `Work`, and `Output` | Initially absent; no R1/R2 path may be passed, copied, or merged. Failure preserves exact partial state and suppresses R01. |
| `MBACR-R01` | `Extracted/CERG/SingleCharacter/LO-CERG1-R3/R01/result.json`; existing `cerg-lo-cerg1-result/1.4.0` shape plus diagnostics from the bound TG02 version | Initially absent and no-overwrite. It is consumable only under the complete MBACR-T3 success predicate above. |

For A00 and L01, `sourceRootBinding` is exactly `{sourceId,privateAbsoluteReadOnlyRoot,rootFingerprint}` with sourceId `pc-install`; the canonical absolute root and every ancestor through the volume root must be directories and non-reparse, and `rootFingerprint=sha256(CJ(["mbacr/source-root/1",sourceId,canonicalPrivateAbsoluteReadOnlyRoot]))`. The absolute root remains only in ignored machine artifacts. `producerBinding` and `validatorBinding` each have `{artifactId,implementationId,role,portableTrackedPath,implementationVersion,byteCount,sha256,runtimeProduct,runtimeVersion,runtimeByteCount,runtimeSha256,sourceRootBinding,orderedArgumentTokens}`; `implementationId="MBACRIMP-"+sha256(CJ(["mbacr/locator-implementation/1",artifactId,role,portableTrackedPath,implementationVersion,byteCount,sha256,runtimeProduct,runtimeVersion,runtimeByteCount,runtimeSha256]))`. Their tracked paths, code hashes, implementations, and argument arrays must differ. `orderedArgumentTokensFingerprint=sha256(CJ(["mbacr/locator-arguments/1",producerBinding.orderedArgumentTokens,validatorBinding.orderedArgumentTokens]))`. A00 `selectorPlan` is exactly the two `{selectorId,sourceId,portableRelativePath}` rows below in selector order. A00's authorization and all bindings must equal TO01/current bytes before installation; its final path and `.tmp` must both be absent before creation.

`inputArtifactRefs` rows are `{artifactId,portableRelativePath,byteCount,sha256}` sorted by artifactId. `locatorAuthorization` is exactly `{authorizationId,to01Sha256,sourceId,rootFingerprint,producerImplementationId,validatorImplementationId,orderedArgumentTokensFingerprint,selectorIds,maxProducerSourceOpens,maxValidatorSourceOpens,maxTotalSourceOpens,noLO}` with sourceId `pc-install`, root/implementation/argument values equal the adjacent bindings, selector IDs exactly `["MBACR-S01","MBACR-S02"]`, integer limits `2/2/4`, JSON boolean `true`, and `authorizationId="MBACRLOC-"+sha256(CJ(["mbacr/locator-authorization/2",to01Sha256,sourceId,rootFingerprint,producerImplementationId,validatorImplementationId,orderedArgumentTokensFingerprint,selectorIds,maxProducerSourceOpens,maxValidatorSourceOpens,maxTotalSourceOpens,noLO]))`; every field must match the separately supplied exact user authorization before A00 installation or any open. `selectorRows` are exactly `{selectorId,sourceId,portableRelativePath,ledgerByteCount,ledgerSha256,currentByteCount,currentSha256,status}` in the fixed selector order below. Status is exactly one of `Located`, `NotLocated`, or `InvalidCurrentLeaf`; current fields are a non-negative JSON integer and 64 lowercase hexadecimal characters for Located/NotLocated, and both JSON null for InvalidCurrentLeaf. `locationRows` contain exactly one row per distinct parsed `AnimatorController` object and zero rows for a selector with none; therefore one selector may own multiple rows, but it contributes only one source member to the addition set. Each row is `{locationId,selectorId,currentByteCount,currentSha256,serializedTypeName,serializedObjectId,objectName,proofKind,proofLocator,status}` sorted by `locationId`, and its current tuple must equal its owning selector row. `currentByteCount` is a non-negative JSON integer; `currentSha256` is exactly 64 lowercase hexadecimal characters; `serializedTypeName`, `proofKind`, and `status` are respectively the literals `AnimatorController`, `ParsedSerializedObject`, and `Located`. `serializedObjectId` is a nonzero signed-64-bit base-10 string matching `^-?[1-9][0-9]*$`, with no plus sign or leading zero. `objectName` and `proofLocator.serializedFileName` are NFC strings; `proofLocator` is the exact object `{serializedFileName,serializedFileOrdinal,objectOrdinal}`, whose two ordinals are non-negative JSON integers and whose file name uses `/`, is relative, and contains no empty, `.` or `..` segment. `locationId="CTRLLOC-"+sha256(CJ(["mbacr/controller-location/2",selectorId,currentByteCount,currentSha256,serializedTypeName,serializedObjectId,objectName,proofKind,proofLocator,status]))`; duplicate IDs or duplicate `(selectorId,serializedFileOrdinal,serializedObjectId)` tuples fail closed. `partitions={selectorCount,locatedCount,notLocatedCount,invalidCurrentLeafCount,controllerLocationCount}` uses JSON integers and equals the selector-status counts plus `|locationRows|`: `locatedCount` is the number of Located selector rows, never the number of Controllers, each Located selector owns at least one location row, each other selector owns none, and `controllerLocationCount=|locationRows|≥locatedCount`. `limits={maxFilesRead,maxBytesRead,maxDurationSeconds,maxResultRows,maxChildProcesses}` contains JSON integers. `producerBinding` and `validatorBinding` use the exact A00 binding shape above and must byte-for-byte equal A00 after canonical reopen. `locatorAttemptRef={artifactId,portableRelativePath,byteCount,sha256}` must identify immutable MBACR-A00. `openRows` are exactly `{openId,openOrdinal,implementationArtifactId,implementationId,selectorId,sourceId,portableRelativePath,openedAtUtc,byteCount,sha256}` in fixed order `(TG01,S01),(TG01,S02),(TG02,S01),(TG02,S02)` with ordinals `1..4`; each byte/SHA tuple equals its selector row, each timestamp is canonical UTC RFC3339, and `openId="MBACROPEN-"+sha256(CJ(["mbacr/locator-open/1",locatorAttemptRef.sha256,openOrdinal,implementationId,selectorId,sourceId,portableRelativePath,byteCount,sha256]))`. `openCounts={producer,validator,total}` is exactly `{2,2,4}` and equals the rows. `failures` rows are exactly `{failureId,selectorId,reasonCode,detailCode}` sorted by `failureId`; `selectorId` is one selector ID or JSON null for artifact-global failure, `reasonCode` is in `[InputIdentityFailure,ParserFailure,LimitExceeded,ConservationFailure,ProducerValidatorDisagreement,OutputIntegrityFailure]`, and `detailCode` is in `[LocatorAuthorizationMissingOrMismatch,AttemptReuseOrInterruption,WrongRoot,ArgumentTamper,OpenSequenceMismatch,MissingLeaf,NonRegularLeaf,LeafReparse,AncestorReparse,UnreadableLeaf,ByteCountMismatch,Sha256Mismatch,MalformedSerializedContainer,DuplicateControllerIdentity,ProducerValidatorMismatch,FilesReadExceeded,BytesReadExceeded,DurationExceeded,ResultRowsExceeded,ChildProcessObserved,SelectorCoverageMismatch,PartitionMismatch,ArtifactInstallFailure]`. Free text and unknown fields are forbidden. `failureId="MBACRF-"+sha256(CJ(["mbacr/failure/2",selectorId,reasonCode,detailCode]))`; duplicate triples fail closed. L01 status is `ControllerLocated` only when A00/reference/authorization/root/bindings/arguments reopen exactly, `openCounts={2,2,4}` and all four ordered open rows conserve, `locatedCount∈{1,2}`, `controllerLocationCount≥locatedCount`, failures is empty, and nextAction is `AwaitTotalControlAuditBeforeMBACRT2`; otherwise status is `Failed`, failures is nonempty, and nextAction is `RecoveryRouteFailed`.

P01 `sourceRootBindings={sourceId,privateAbsoluteReadOnlyRoot,rootFingerprint}`. Each `implementationBindings` row is `{artifactId,implementationId,implementationRole,implementationVersion,pathKind,portableTrackedPath,privateAbsoluteLeafPath,implementationByteCount,implementationSha256,runtimePrivateAbsoluteLeafPath,runtimeByteCount,runtimeSha256,orderedArgumentTokens}`. The binding set is exactly the four duplicate-free IDs `LO1-IA01/AssetRipperExecutable`, `LO1-IF01/AssetRipperFolderInvoker`, `T1V22-TG01/ExactLeafStagingWrapper`, and `T1V22-TG02/R01GraphProducer`; the three tracked paths are respectively null, `Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1`, `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, and `Tools/AssetImport/New-CergLo1ResultGraph.ps1`, while IA01 is the independently verified machine-private AssetRipper `1.3.14.0` PE leaf. `operation={operationId,obligationRefIds,implementationRefIds,inputMemberRefIds,expectedSubjectKinds,expectedRelationshipKinds,sourceReadMaxFiles,sourceReadMaxBytes,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,stagingInputPortablePath,outputPortablePath,workPortablePath}` is exactly one operation; its implementation references equal all four binding IDs once, its input references equal every expanded member once, and its obligation references equal the eleven candidate obligations once. Its frozen caps are `sourceReadMaxFiles=expandedCount`, `sourceReadMaxBytes=sum(expanded member byteCount)`, `maxDurationSeconds=1800`, `maxResultRows=200000`, `maxOutputFiles=10000`, and `maxOutputBytes=2147483648`; `aggregateLimits` equals those six values exactly and grants no second allowance. `stagingPlan={attemptPrivateAbsoluteRoot,stagingInputPortablePath,stagingInputPrivateAbsolutePath,stagingInventoryTemporaryPath,stagingInventoryTemporaryPrivateAbsolutePath,stagingInventoryPath,stagingInventoryPrivateAbsolutePath,workPortablePath,workPrivateAbsolutePath,outputPortablePath,outputPrivateAbsolutePath,memberRows,memberCount,byteCount,memberSetFingerprint}` with `memberRows={sourceMemberRefId,sourceId,sourcePortableRelativePath,stagingPortableRelativePath,byteCount,sha256}` sorted by sourceMemberRefId. P01 status/nextAction are exactly `Green/RequestExactHumanConfirmationForMBACRLO1`; any failed predicate suppresses P01 rather than publishing false Green.

F02 shape is `{schemaVersion,artifactId,contractHeadCommit,preflightSha256,checkRunId,validatorStartedAtUtc,validatorFinishedAtUtc,memberRows,memberCount,byteCount,memberSetFingerprint,status,failures,nextAction}`; each member row has the exact P01 staging member-row shape and order. A01 shape is `{schemaVersion,artifactId,contractHeadCommit,l01Sha256,preflightSha256,f02Sha256,confirmationId,runnerBinding,runnerInstanceId,processId,createdAtUtc,maxFirstSourceOpenDelayMilliseconds,LOUsedBeforeFirstSourceOpen,LOUsedAfterFirstSourceOpen,status,sameRunnerOnly,nextAction}`, where `runnerBinding={implementationId,role,portableRelativePath,byteCount,sha256}` and `confirmationId="MBACRCONF-"+sha256(CJ(["mbacr/r3-confirmation/1",contractHeadCommit,preflightSha256,l01Sha256,expandedMemberSetFingerprint,runnerBinding.implementationId]))`. H01 shape is `{schemaVersion,artifactId,a01Sha256,runnerImplementationId,runnerInstanceId,processId,sourceMemberId,validatorFinishedAtUtc,firstSourceOpenedAtUtc,elapsedMilliseconds,LOUsedBeforeFirstSourceOpen,LOUsedAfterFirstSourceOpen,status,nextAction}`. SI01 shape is `{schemaVersion,artifactId,l01Sha256,preflightSha256,selectedCandidateId,memberRows,memberCount,byteCount,memberSetFingerprint,status}` using the same exact member-row shape. F02/A01/H01/SI01 schemas and artifact IDs are respectively `cerg-mbacr-r3-adjacency/1.0.0` / `MBACR-F02`, `cerg-mbacr-r3-attempt/1.0.0` / `MBACR-A01`, `cerg-mbacr-r3-first-open/1.0.0` / `MBACR-H01`, and `cerg-mbacr-r3-staging/1.0.0` / `MBACR-SI01`. Their status values are respectively `Green`, `ArmedNoSourceOpen`, `FirstSourceOpenObserved`, and `Complete` only when every stated binding and conservation predicate holds.

Member-set fingerprints use `sha256(CJ([domain, rows]))`, where each row is `[sourceId,portableRelativePath,byteCount,sha256]` sorted Ordinal by `(sourceId,portableRelativePath)`. Domains are `mbacr/base-member-set/1`, `mbacr/addition-member-set/1`, and `mbacr/expanded-member-set/1`. The base set is exactly the seventeen current R2 F02 members. The addition set contains exactly one current member tuple for each selector having one or more `locationRows`, never one tuple per Controller. The expanded set is their duplicate-free union; therefore `additionCount=locatedCount∈{1,2}`, `expandedCount=17+locatedCount`, and a multi-Controller bundle still increases expandedCount by one.

#### Subject/Partition Registry

The locator candidate universe is exactly these two immutable C1 selectors, and no path prefix, directory enumeration, glob, sibling, Android member, FX actor-common member, or other corpus member is authorized:

| selectorId | sourceId | portableRelativePath | ledgerByteCount | ledgerSha256 |
|---|---|---|---:|---|
| `MBACR-S01` | `pc-install` | `Persistent_Store/AssetBundles/actor_common.unity3d` | 10821270 | `8c485e107b27b5ff6862c79c61ba683eae7c46ed5fdd8afb203e8ff7de6dcf64` |
| `MBACR-S02` | `pc-install` | `xtlr_Data/StreamingAssets/InstallResource/actor_common.unity3d` | 10777435 | `d66c4c505e3e577319dc776f76ac5a471487181b4fa9396e57bc2308639464fb` |

Each selector belongs to exactly one partition: `Located` when a fresh exact leaf is regular, non-reparse through its entire ancestor chain, independently size/SHA verified, and an independent serialized-object parser proves at least one `AnimatorController`; `NotLocated` when the fresh leaf is valid but contains no parsed AnimatorController; or `InvalidCurrentLeaf` when existence/type/reparse/read/identity validation cannot complete. `selectorCount=locatedCount+notLocatedCount+invalidCurrentLeafCount=2`; the partitions are disjoint, while `controllerLocationCount=sum(per-selector parsed AnimatorController count)`. Identity drift from the C1 ledger is recorded as current byte/SHA evidence and is not itself asset failure, but producer and validator must agree on the current tuple and complete ordered Controller rows. Zero Located selectors fails closed; the one or two Located selector members are all included exactly once in the addition set—there is no subjective winner selection.

TO01 `toolRows={artifactId,role,portableTrackedPath,implementationVersion,byteCount,sha256}` are exactly `MBACR-TG01/ControllerLocatorProducer` and `MBACR-TG02/ControllerLocatorValidator`, sorted by artifactId and bound to different tracked paths/hashes. `testRows={testId,status,evidenceLocator}` are exactly the ordered IDs `MBACR-CE01-FilenameOnly`, `MBACR-CE02-RawStringOnly`, `MBACR-CE03-MissingLeaf`, `MBACR-CE04-AncestorReparse`, `MBACR-CE05-DuplicateObject`, `MBACR-CE06-ParserDisagreement`, `MBACR-CE07-LimitExceeded`, `MBACR-CE08-MultipleControllersOneSelector`, `MBACR-CE09-NonCanonicalFailureRejected`, `MBACR-CE10-LocatorReadWithoutAllowance`, `MBACR-CE11-WrongRoot`, `MBACR-CE12-ArgumentTamper`, `MBACR-CE13-AttemptReuseOrInterruption`, `MBACR-SP01-ParsedController`, all Passed. CE08 proves two Controllers in one selector yield two location rows, `locatedCount=1`, and one addition member; CE09 proves free-text/unknown/duplicate failure identities are rejected; CE10 proves source opening without the exact one-shot authorization is rejected; CE11/CE12 reject a self-consistent wrong root or changed ordered arguments; CE13 proves A00 remains consuming and non-reusable after interruption. TO01 Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeMBACRT1B`; Failed TO01 has at least one canonical L01-style failure row and never authorizes source read.

The only locator limits are `maxFilesRead=2`, `maxBytesRead=33554432`, `maxDurationSeconds=600`, `maxResultRows=32`, `maxChildProcesses=0`. The separately authorized locator allowance fixes `maxProducerSourceOpens=2`, `maxValidatorSourceOpens=2`, and `maxTotalSourceOpens=4`; each selector is opened once by the producer and once by an implementation-independent validator. The byte cap applies separately to each implementation and neither may read a source root or parent directory. A00 and L01 both bind the exact source ID/root fingerprint, tool/runtime identities, and complete ordered argument arrays; L01 additionally binds A00's SHA and the four actual opens. No locator open may be recorded as an R3 H01 open, and only a later confirmed R3 runner can consume the remaining LO.

#### Failure Transition Table

| ID | Exact condition | Artifact vector and accounting | Sole next action |
|---|---|---|---|
| `MBACR-FT01` | T0 mirror divergence, invalid contract, or commit failure | No locator/tool/output; recovery remains `0/5,0/1` if commit absent | `CorrectMBACRContract` |
| `MBACR-FT02` | T1A tool, independence, fixture, commit, or TO01 publication failure | Failed/absent TO01 only; `2/5,0/1`; no source read/L01 | `RecoveryRouteFailed` |
| `MBACR-FT03` | Exact locator-read authorization is absent/mismatched; A00 install fails | A00 absent; no source open; `3/5,0/1`, locator allowance remains `0/1`; no L01/P01 | `RecoveryRouteFailed` |
| `MBACR-FT03A` | A00 installs, then the invocation crashes/is interrupted, A00 is reused, any open is absent/extra/out of order, root/arguments/bindings drift, locator exceeds a limit, reads outside S01/S02, uses filename/string-only proof, producer/validator disagree, any selector is Invalid, `locatedCount=0`, conservation fails, or L01 publication fails | Preserve immutable A00 and any absent/Failed L01 exactly; `3/5,0/1`, locator allowance `1/1`; no retry/P01 | `RecoveryRouteFailed` |
| `MBACR-FT04` | R3 preflight cannot freshly validate all 17 base plus all Located additions, implementation/private-path binding fails, or exact confirmation is absent/mismatched | P01 absent or Failed diagnostic; `4/5,0/1`; no A01/source open | `RecoveryRouteFailed` |
| `MBACR-FT05` | Confirmed LO fails, is interrupted, exceeds limits, or does not produce complete immutable D01 | Preserve R3 A01/SI01/partial state; `4/5,1/1`, global `3/3`; no retry/R01 | `RecoveryRouteFailed` |
| `MBACR-FT06` | TG02 cannot produce a complete R01, or Controller/AnimatorState/override/action/FX/eleven-obligation closure fails | Immutable diagnostic R01; `5/5,1/1`; no Unity | `RecoveryRouteFailed` |
| `MBACR-FT07` | R01 satisfies every MBACR-T3 success predicate | Immutable Closed R01; `5/5,1/1`; Unity still denied | `AwaitExplicitCERGT2AuthorizationAfterRecoveredR01` |

Fixed counterexamples: a filename containing `actor_common` without a parsed AnimatorController is `NotLocated`; a raw `AnimatorController` byte string without a serialized-object identity is `NotLocated`; a self-consistent stale/foreign tuple, ancestor junction, duplicate selector/location, producer-only Green, partial selector coverage, or an addition not equal to all Located rows fails closed. R3 may never read a root/glob, reuse R2 Output, omit one of the seventeen base members, or treat AssetRipper exit zero as R01 closure.

After this T0 commit, the sole next action is `AwaitTotalControlAuditBeforeMBACRT1A`.

### Historical Fast Feasibility Spike closure

- The Fast Feasibility Spike is completed history: `ordinaryTaskUsed=3/3`; `spikeLOUsed=2/2`; `Character structural producer evidence=Demonstrated`; `Environment chain=NotDemonstrated`; `Audio producer evidence=Demonstrated`; `Overall=PartiallyFeasible`.
- The spike proved only structural producer evidence for Character and producer evidence for Audio. It did not validate Unity display, material/texture rendering, complete action playback, attack effects, or asset reusability.

### CERG product question and binary terminal result

The only product question is:

> 能否把一个有代表性的 StellaSora 角色作为依赖闭合的 Unity 资产还原，并证明其模型显示正常、骨骼/Avatar正常、完整动作全集正常播放、对应攻击特效正常显示？

CERG has exactly two permitted terminal results:

- `EverythingNormal`: every hard acceptance criterion in this override holds simultaneously.
- `ProjectFailed`: any hard acceptance criterion does not hold, or auditable evidence cannot be produced within the fixed budgets.

`Feasible`, `PartiallyFeasible`, `NotDemonstrated`, and `Blocked` are forbidden as CERG terminal results. If Unity, a required tool, authorization, or input remains unavailable at the budget endpoint, the result is `ProjectFailed`. That conclusion means only that this fixed route did not prove success; it must not be described as proof that the assets are intrinsically or absolutely impossible to restore.

The old FFS, R8.3, R9-R13, complete C2/C3-C7, environment, audio, other characters, and full-corpus governance remain `Suspended`. They may not run in parallel with CERG and are not CERG prerequisites.

### Fixed budgets and only permitted sequence

- `ordinaryTaskBudget=7`; `LOBudget=3`. The ordinary budget is expanded exactly once from six to seven solely for the user-authorized `CERG-Contract-Recovery-1`; no other correction, audit, or retry may infer another expansion.
- `CERG-T0` completed at `ordinaryTaskUsed=1/7`; CERG-T1A consumed the second slot, CERG-T1B consumed the third, and `CERG-Contract-Recovery-1` consumes the fourth, so current counters are `ordinaryTaskUsed=4/7`, `LOUsed=0/3`. The historical T1-v1 evaluation and its purported T4 conclusion are both `InvalidatedByContractDefect` and consumed no valid route slot. TO01/TO02/TO03/TO04 corrections and the non-artifact T1B digest/binding diagnostics consume no additional slot. The original LO-CERG1 P01/A01 false-green attempt is explicitly invalidated below: its physical attempt remains recorded, but because it opened zero source members its budgeted `LOUsed` is explicitly restored to `0/3`, never implicitly refunded.
- Reaching either budget cap requires an immediate binary terminal result and stop. No unbounded tool rotation, candidate replacement, retry, or governance expansion is permitted.

The only permitted sequence is:

1. `CERG-T0` route reset completed.
2. The historical `CERG-T1-v1` empty evaluation and resulting T4 conclusion are `InvalidatedByContractDefect`; neither is counted.
3. TO01, TO02, and TO03 are independently rejected tooling-readiness history. This docs-only correction registers the separately authorized in-slot CERG-T1A4 correction and TO04 generation without changing the counters.
4. `CERG-T1A` remains consumed exactly once at `ordinaryTaskUsed=2/6`, `LOUsed=0/3`. TO01, TO02, and TO03 are immutable `RejectedByTotalControlAudit` history; corrected TG02/TG03 v4 and TO04 are the sole total-control-approved readiness generation.
5. `CERG-T1B` consumed the third ordinary slot, and the corrected same-slot execution locked only `char_14401` in audited T01/O01. Its earlier digest/binding diagnostics remain non-artifact history.
6. The original LO-CERG1 P01/A01 reached `PreflightFalseGreenContractDefect` before any source-member open. `CERG-Contract-Recovery-1` consumes the fourth ordinary slot, repairs only the production/consumer contract, preserves the original bytes, and stops for total-control audit.
7. Only after that audit may total control separately authorize one `ReplacementLOCERG1Attempt`. Its v1.4 P01 binds private source roots, exact registered leaves, attempt-owned private staging paths, tool identities, arguments, limits, and outputs; exact human confirmation binds the new digest. No automatic authorization follows this recovery Task.
8. The replacement `LO-CERG1` performs the sole candidate-scoped dependency-closure extraction/staging attempt and may resolve only the frozen discovery obligations. Whether it succeeds, fails, or is interrupted, no second replacement or LO-CERG1 retry exists.
9. `CERG-T2` performs final exact-universe closure acceptance, freezes the visual-measurement contract, and constructs the minimal Unity validation scene/automatic validator; completion sets `ordinaryTaskUsed=5/7`.
10. After exact human confirmation, `LO-CERG2` performs the single-thread Unity first import/run/capture.
11. If LO-CERG2 is all green, or has zero/multiple/unbounded/unrepairable causes, proceed directly to `CERG-T4`. If and only if LO-CERG2 exposes exactly one total-control-approved, fixed-scope cause repairable by one ordinary Task, `CERG-T3` performs that sole repair and completes at `ordinaryTaskUsed=6/7`; it cannot change the character, source universe, acceptance criteria, or repair more than that cause.
12. After exact human confirmation, `LO-CERG3` performs the sole Unity revalidation of the complete A-F matrix. It is one attempt, not a retry of LO-CERG2, and consumes the third and final LO slot.
13. `CERG-T4` is the final ordinary Task. The normal no-repair path terminates at `ordinaryTaskUsed=6/7`, `LOUsed=2/3`; the single-cause repair path terminates at `ordinaryTaskUsed=7/7`, `LOUsed=3/3`. It returns `EverythingNormal` only when the applicable LO2 or LO3 evidence proves all hard criteria green; otherwise it returns route-scoped `ProjectFailed`.

The invalid T1-v1/T4 artifacts do not consume the repair slot. `CERG-T3 → exact human confirmation → LO-CERG3 → CERG-T4` is reachable exactly once under the single-cause predicate above. Any LO3 failure, any second cause, or any attempted scope expansion routes directly to `CERG-T4=ProjectFailed`; no further fix or Unity attempt exists.

### Candidate lock and exact-universe rules

- The historical allowance to compare at most three families is superseded. `CERG-T1B` evaluates exactly one family, `char_14401`, and candidate rotation is forbidden.
- `char_14401` has the fixed Mesh/Avatar/skeleton/clip baseline defined below, but no attack effect or complete action-set result may be presumed.
- Before locking, the candidate must yield an exact pre-extraction universe covering every identity already visible for model/SkinnedMesh, Material/Texture/Shader, skeleton/Avatar, controller/nested-state-machine/Motion/BlendTree/clip, and attack-FX-prefab/component, plus every unavailable relationship as one finite identity-bearing discovery obligation over exact C1 SourceMembers. Corrected TG01/TG02 implementation identities are frozen by total-control-approved TO04 before candidate evaluation; private AssetRipper/runtime identity, arguments, and execution/output limits belong only to the later immediate preflight. A source root alone is never an input selector.
- Final completeness must come from authoritative controller, override, prefab, event, GUID, serialized object, or equivalent ownership/reference relationships. Filename, same-directory location, a single-clip sample, and subjective similarity are forbidden completeness evidence.
- After lock, the character may not be changed. This reopened v2.2 route evaluates only `char_14401`; an empty or prohibited C1 projection means no candidate was evaluated and is a contract/input failure, never `ProjectFailed`. If a nonempty projection exposes contradictory authority or an obligation that cannot be bounded, T1-v2.2 suppresses the lock and returns to total-control audit; it does not emit a terminal conclusion.
- `LO-CERG1` may fill the frozen obligations but may not broaden the candidate, source boundary, relationship kinds, or selectors. A newly encountered dependency outside the registered member set is recorded as an unresolved external identity but is not read; an unrelated family or open-ended corpus search is forbidden, and CERG-T2 closure cannot pass while it remains unresolved.
- After `LO-CERG1`, `CERG-T2` must freeze the final exact universe with zero unresolved or contradictory rows. Otherwise it must not build the Unity scene or request `LO-CERG2`, and `CERG-T4=ProjectFailed`.
- “All actions” means one closed, countable, identity-bearing traversal of every nested StateMachine state, Motion, recursive BlendTree child, parameter branch, and leaf ActionClip. Unity validation must cover every state and every branch-to-leaf route. Any unclassified state/Motion/branch/clip or unresolved reference is failure.
- Every attack effect must have an authoritative attack-action-to-FX trigger/reference relationship and must actually trigger during the corresponding Unity action. `NoEffectExpected` is allowed only when an authoritative relationship explicitly proves no effect is expected; otherwise absence is failure.

### CERG-T1 authorized historical evidence and evidence states

`CERG-T1A` and its in-slot `CERG-T1A3`/`CERG-T1A4` corrections may use only tracked plans/contracts/tool metadata and synthetic fixtures; none can read C1/FFS candidate evidence. `CERG-T1B` keeps every source and historical-evidence input read-only; its only machine-local writes are non-overwriting T1V22-T01/T1V22-O01. T1B's complete historical evidence allowlist is:

1. tracked repository plans, contracts, and source-independent tool metadata;
2. historical C1 ledger/summary identity, count, byte, hash, and portable provenance fields, without copying any machine-private or absolute path into portable artifacts or conversation;
3. historical `LO-FFS1` file-tree identities and exported relationship metadata, including Unity `.meta` GUIDs and serialized prefab/controller/override/Animator/MonoBehaviour/manifest relationships already present in that immutable output;
4. historical FFS result/log fields only for tool identity, attempt identity, exit state, and already-recorded structural observations.

Raw source roots, PB-I03, machine-local manifests/baselines, producer execution against source or historical assets, AssetRipper, decode, Unity, binary interpretation beyond safe identity/enumeration, `LO-FFS2` audio content, and any write to historical output remain forbidden during T1A/T1A3/T1A4/T1B. TG02/TG03 may execute only against synthetic fixture bytes during T1A3/T1A4; T1B executes no producer.

Every candidate relationship row must have exactly one state:

- `ProvenPresent`: an authoritative owner/reference record identifies the target and relationship.
- `ProvenAbsent`: an authoritative, exhaustively enumerated owner/reference collection proves that the relationship or effect is not defined. Missing filenames, directories, exports, or observations never establish this state.
- `EvidenceUnavailableBeforeExtraction`: the authorized historical evidence does not expose the relationship, but one finite candidate-scoped selector/owner/relationship query is frozen as a `LO-CERG1` discovery obligation.
- `Contradictory`: authoritative historical records disagree on identity or relationship.

`EvidenceUnavailableBeforeExtraction` means “not visible in current evidence,” never “absent.” It is permitted at the end of `CERG-T1` only when every such row has one exact discovery obligation. `Contradictory` rejects that candidate. `ProvenAbsent` can support `NoEffectExpected` only when its exhaustive authority remains current after `LO-CERG1`; otherwise the final row fails closure.

### Rebuilt CERG-T1-v2.2 central contract

This v2.2 section is the sole executable CERG-T1A/T1A3/T1A4/T1B contract. It supersedes every later v2.1, v2.0, and v1 section in full; those sections and artifacts remain immutable history. The current counters are `ordinaryTaskUsed=2/6`, `LOUsed=0/3`; the newest dated subsection controls readiness artifacts and next action.

#### 2026-07-19 T1A total-control rejection and TO02 correction

This subsection supersedes only the v2.2 T1A tooling/readiness rows, tests, transitions, and every later statement that could treat TO01 as approved. All candidate/T1B/LO rules remain unchanged except that every readiness consumer must bind total-control-approved TO02, never TO01. This is a correction inside the already consumed T1A slot: `ordinaryTaskUsed=2/6`, `LOUsed=0/3`; it cannot read candidate evidence or authorize T1B, preflight, or an LO.

**Artifact Registry.** Existing `T1V22-TO01` at `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness.json` is immutable historical evidence: `2509` bytes, raw SHA-256 `d1f5cd91e37f5a3b562d9f5e990f0c6f94fa3624b5bc83b8e8b1522d7756f6bb`, bound commit `1f9e0e9c9a7826a6927bb61bc36547475111fc72`, `auditDisposition=RejectedByTotalControlAudit`, `consumableForT1B=false`, and reason set `[AttackClosureIncomplete,GraphProducerCapabilityMissing,SourceMemberBijectionMissing,UpstreamFreshnessValidationMissing]` in that Ordinal order. It is never removed, replaced, refreshed, or treated as Failed producer output.

- `T1V22-TOT02` is the initially absent, non-consumable temporary leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v2.json.tmp`.
- `T1V22-TO02` is the initially absent, immutable final leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v2.json`, schema/ID `cerg-t1v22-tooling-readiness/1.1.0` / `T1V22-TO02`. Top-level fields in order are `schemaVersion`, `artifactId`, `contractHeadCommit`, `priorReadiness`, `toolRows`, `testRows`, `partitions`, `status`, `failures`, `nextAction`.
- `priorReadiness={artifactId,portableRelativePath,byteCount,sha256,auditDisposition,auditReasonCodes,consumableForT1B}` must equal the frozen TO01 identity/disposition above. `toolRows` retains the prior exact row shape/order but binds corrected TG01/TG02/TG03 committed bytes and versions `CERG-LO1-EXACT-STAGING/2`, `CERG-LO1-R01-PRODUCER/2`, and `CERG-T1A-PIPELINE-TEST/2`.
- `testRows` retains `{testId,testClass,status,evidenceLocator}` and is exactly this order: `T1A2-TEST01/ExactLeafAllow`, `T1A2-TEST02/RootDirectoryReject`, `T1A2-TEST03/PathEscapeReject`, `T1A2-TEST04/SizeHashReject`, `T1A2-TEST05/StagingBijection`, `T1A2-TEST06/InterruptedVector`, `T1A2-TEST07/SourceMemberBijectionReject`, `T1A2-TEST08/DirectUnityYamlGraph`, `T1A2-TEST09/MissingGraphReject`, `T1A2-TEST10/PartialDiagnosticReject`, `T1A2-TEST11/AttackWithoutFXReject`, `T1A2-TEST12/ControllerBlendClosureReject`, `T1A2-TEST13/FXMaterialClosureReject`, `T1A2-TEST14/StaleSplicedInputReject`, `T1A2-TEST15/CanonicalDeterminism`.
- `partitions={passedCount,failedCount,totalCount}` fixes `totalCount=15=passedCount+failedCount`. TO02 `failures` reuses complete `TO01Failure` rows/reason enums/sort, but IDs use `T1A2F-` plus `sha256(CJ(["cerg-t1a/to02-failure-id/1",startingCorrectionHeadCommit,reasonCode,ownerId,testId,prerequisiteId,evidenceLocator]))`. Green fixes `15/0/15`, `failures=[]`, and `nextAction=AwaitTotalControlAuditBeforeCERGT1B`; Failed fixes all fifteen Passed/Failed rows, at least one failure, and `nextAction=ReturnToTotalControlAuditForT1A2`.
- TOT02 is written completely, reopened and byte/schema/identity validated, then installed once to absent TO02 by same-directory atomic no-overwrite rename. A successful install leaves TOT02 absent. TO01 is read-only throughout.

**Subject/Partition Registry.** TG01 must prove `CandidateSourceMemberIds = PlanSourceMemberRefIds = SI01SourceMemberRefIds = RecursiveStagedLeafSourceMemberIds` as duplicate-free sets, with each SourceMember tuple byte-identical to exactly one plan row and exactly one staged leaf; path, count, and byte/hash bijections must also hold before SI01. Operation `inputMemberRefIds` equals the same set. A duplicate, omission, extra, tuple mismatch, or one member copied twice is `SourceMemberBijectionFailure` and can never publish SI01.

TG02 production discovery input is only recursive D01 Unity serialized text and `.meta` leaves. It must directly parse Unity YAML document headers (`--- !u!<classId> &<fileId>`), type roots, exact serialized property paths, local/external `{fileID,guid,type}` references, and `.meta` GUID ownership from controller/override-controller, prefab, animation, material, mesh/avatar, and referenced serialized assets. `*.cerggraph.json`, synthetic graph declarations, the two historical Measure scripts, filenames alone, and producer exit state are never graph inputs and cannot contribute a Closed row.

Every parsed YAML document belongs to exactly one typed subject or `ReferencedObject`; every serialized reference belongs to exactly one typed relationship or `SerializedObjectReference`; every controller/state-machine child/state/Motion/recursive BlendTree branch/parameter/leaf clip, every renderer mesh/material/skeleton/avatar binding, every material texture/shader binding, and every FX prefab object/component/serialized reference is exhaustively scoped and counted. Each ActionState/AttackAction has one or more `StateUsesMotion` paths and every path terminates at an ActionClip. Each AttackAction has exactly one authoritative outcome: at least one `AttackTriggersFX` path produced from its clip AnimationEvent object reference, or one exhaustive current ProvenAbsent row supporting `NoEffectExpected`; missing observation is neither. Each FXPrefab has objects, each FXObject has complete child/component slots, and each FXComponent reference slot resolves. Any per-owner omission makes R01 Unresolved.

TG02 validates before reading D01: exact schema/artifact IDs for O01/P01/A01/SI01; equal selected candidate and contract HEAD; P01 `candidateLockSha256=rawSha256(O01)`; A01 binds those same candidate/preflight hashes; SI01 binds those same hashes and candidate; `attemptCount=1`; and O01 SourceMembers, P01 input/staging rows, SI01 rows/count/bytes/fingerprint are mutually byte-conserving. Stale/spliced/malformed upstream inputs suppress Closed regardless of downstream graph content.

**Failure Transition Table.** `T1A2-FT01` is a pre-corrective-commit implementation/test failure: starting corrective HEAD and rejected TO01 remain, TG01-TG03 remain at their prior committed bytes, TOT02/TO02/T01/O01/LO artifacts are absent, counters remain `2/6,0/3`, and only `ReturnToTotalControlAuditForT1A2` is allowed. `T1A2-FT02` is corrected-tool commit plus canonical Green TO02: TO01 remains rejected history, TG01-TG03 and TO02 are present, TOT02/T01/O01/LO artifacts absent, counters remain `2/6,0/3`, and only `AwaitTotalControlAuditBeforeCERGT1B` is allowed. `T1A2-FT03` is corrected-tool commit present but TO02 unavailable: preserve that commit and observed TOT02/TO02 state, deny T1B, and return to total control. No state overwrites TO01 or creates candidate/preflight/LO output.

Fixed counterexamples are executable: duplicate-one/omit-one SourceMember; directory/root/glob/path escape; interrupted partial staging; missing Unity graph; a prebuilt `.cerggraph.json`; AttackAction without FX/authoritative absence; state or BlendTree branch without clip; FX object/component/reference omission; Material without Texture or Shader; stale candidate hash, stale preflight hash, spliced A01/SI01, wrong schema/artifact ID; and identical logical YAML documents created/enumerated in different order. Only all fifteen Passed may publish Green TO02. `ApprovedForCERGT1B=false` until total control separately approves the exact TO02 SHA and corrective HEAD.

#### 2026-07-20 TO02 total-control rejection and TO03 correction contract

This subsection supersedes the 2026-07-19 TO02 correction and every later readiness, T1B, O01, preflight, U1, version, test-count, transition, recovery, or next-action statement that names TO01 or TO02 as consumable. TO01 and TO02 remain immutable history; no byte is deleted, overwritten, refreshed, or reclassified as producer failure. This docs-only Task changes only the two mirrored routes, consumes no additional ordinary Task or LO, keeps `ordinaryTaskUsed=2/6`, `LOUsed=0/3`, and fixes `ApprovedForCERGT1B=false`.

**Artifact Registry.** `T1V22-TO02` is frozen rejected history at `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v2.json`: `3690` bytes, raw SHA-256 `aa61dec2e0db2a09c59a80235bbf154c68f2a09d3531e6dbe4c101175999d4f4`, bound commit `8fff83f89fa99ad883dd5ab250d2222d1174537e`, `auditDisposition=RejectedByTotalControlAudit`, `consumableForT1B=false`, and Ordinal `auditReasonCodes=[AnimationEventElementBindingIncorrect,BlendTreeMetadataNotParsed,ExternalTextureLeafUnsupported,OutputObligationAttributionOverbroad,PrefabRolePartitionMissing,RecursiveAttackBlendTraversalMissing]`. Its embedded Green status records producer output only and grants no authority after this independent rejection.

- `T1V22-TG01` remains the exact committed `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, `19684` bytes, raw SHA-256 `b68b73588816d3cf1e921c84244ab54f8664daaff10abacfc175e541f84599dd`, role/version `ExactLeafStagingWrapper/CERG-LO1-EXACT-STAGING/2`. CERG-T1A3 must not modify it.
- The TO02-bound TG02/TG03 bytes and versions remain rejected historical tool evidence. CERG-T1A3 may modify only `Tools/AssetImport/New-CergLo1ResultGraph.ps1` and `Tools/AssetImport/Test-CergLo1Pipeline.ps1`; successful replacements have versions `R01GraphProducer/CERG-LO1-R01-PRODUCER/3` and `FixtureContractTest/CERG-T1A-PIPELINE-TEST/3`.
- `T1V22-TOT03` is the initially absent, non-consumable temporary leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v3.json.tmp`. `T1V22-TO03` is the initially absent, immutable success-only final leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v3.json`, schema/ID `cerg-t1v22-tooling-readiness/1.2.0` / `T1V22-TO03`. Neither may exist during this docs-only Task.
- TO03 top-level fields in order are `schemaVersion`, `artifactId`, `contractHeadCommit`, `priorReadiness`, `toolRows`, `testRows`, `partitions`, `status`, `failures`, `nextAction`. `priorReadiness={artifactId,portableRelativePath,byteCount,sha256,contractHeadCommit,auditDisposition,auditReasonCodes,consumableForT1B}` is exactly the frozen TO02 row above. `toolRows={artifactId,implementationRole,implementationVersion,portableRelativePath,byteCount,sha256}` is exactly `[T1V22-TG01,T1V22-TG02,T1V22-TG03]`: TG01 must equal the frozen bytes above and TG02/TG03 bind the post-correction committed bytes. `contractHeadCommit` is that exact post-correction tool HEAD.
- TO03 is Green-only: `status=Green`, `failures=[]`, `partitions={passedCount:23,failedCount:0,totalCount:23}`, and `nextAction=AwaitTotalControlAuditBeforeCERGT1B`. A failed, incomplete, skipped, reordered, or prerequisite-suppressed matrix produces no TOT03/TO03 and no tool commit; there is no Failed TO03 form.
- TO03 bytes are exactly `CJ(TO03)` under the existing v2.2 canonical encoding: NFC strings, invariant finite numbers, ordered object properties as declared, ordered arrays as frozen, UTF-8 without BOM or trailing newline, and lowercase raw SHA-256. Every Passed row uses `evidenceLocator="SyntheticFixture/<testId>/Assertions"`. After the corrective tool commit fixes HEAD and tool hashes, T1A3 writes complete bytes only to absent TOT03, reopens and recomputes every identity/partition, then performs one same-directory atomic no-overwrite rename to absent TO03; success leaves TOT03 absent. Direct TO03 writes, overwrite, partial consumption, or publication before the tool commit are invalid.

TO03 `testRows={testId,testClass,status,evidenceLocator}` is exactly this order, each once and Passed: `T1A3-TEST01/ExactLeafAllow`, `T1A3-TEST02/RootDirectoryReject`, `T1A3-TEST03/PathEscapeReject`, `T1A3-TEST04/SizeHashReject`, `T1A3-TEST05/StagingBijection`, `T1A3-TEST06/InterruptedVector`, `T1A3-TEST07/SourceMemberBijectionReject`, `T1A3-TEST08/DirectUnityYamlGraph`, `T1A3-TEST09/MissingGraphReject`, `T1A3-TEST10/PartialDiagnosticReject`, `T1A3-TEST11/AttackWithoutFXReject`, `T1A3-TEST12/ControllerBlendClosureReject`, `T1A3-TEST13/FXMaterialClosureReject`, `T1A3-TEST14/StaleSplicedInputReject`, `T1A3-TEST15/CanonicalDeterminism`, `T1A3-TEST16/MultiEventElementBinding`, `T1A3-TEST17/BlendTreeOneDMetadata`, `T1A3-TEST18/BlendTreeTwoDMetadata`, `T1A3-TEST19/BlendTreeDirectMetadata`, `T1A3-TEST20/RecursiveAttackBlendFX`, `T1A3-TEST21/AssetRipperPngMetaMaterialShader`, `T1A3-TEST22/PrefabRolePartitionAndAttribution`, `T1A3-TEST23/AttackAnchorClassification`.

**Subject/Partition Registry.** TG02 v3 first inventories every D01 leaf and its `.meta` identity, then parses ownership in ordered passes; a filename never determines an attack relationship.

- Future O01 adds `attackAnchors` immediately after `toolingReadiness`. `AttackAnchor={attackAnchorId,candidateId,clipSubjectRefId,portableRelativePath,byteCount,sha256,unityGuid,serializedFileId,evidenceRefIds,authorityKind}`; the array contains exactly one row, every field is nonempty, and clipSubjectRefId resolves an O01 ActionClip with the same GUID/fileID/path/hash. `attackAnchorId="ATK-"+sha256(CJ(["cerg-t1/attack-anchor/1",candidateId,portableRelativePath,byteCount,sha256,unityGuid,serializedFileId]))`. `authorityKind` is exactly `ImmutableFFSAttackClip`; an optional serialized state tag is direct classification evidence and never creates an AttackAnchor row.
- The mandatory immutable anchor is the exact LO-FFS1 member `Extracted/FastFeasibilitySpike/LO-FFS1/Export/CharacterEnvironment/ExportedProject/Assets/assetbundles/actor/character/14401/animations/144_Attack.anim`, `33178294` bytes, raw SHA-256 `a85a80965ff5836354bb2856f8bf7b2aead9da01fe33458dc253d7ea6f625dfc`, plus its paired `.meta`, `249` bytes, raw SHA-256 `4a32d200a2547455bea1c606db53314fef08ba39011c3b057a8afb23f0983099`; T1B must freeze its exact GUID/fileID ActionClip identity and evidence refs without reading any source. Missing, stale, nonresolving, or tuple-mismatched mandatory anchor suppresses O01; TG02 treats a stale/missing anchor as Unresolved even if another heuristic appears attack-like.
- TG02 initially classifies every serialized AnimatorState as ActionState, computes its complete recursive leaf-clip set, and then promotes it to AttackAction if at least one leaf exactly equals a valid O01 attack anchor. It may additionally promote a state only when that same serialized state authoritatively contains the exact case-sensitive field/value `m_Tag: Attack`, recorded with its property locator. State names, clip names, filenames, directories, subjective semantics, or the presence of an event/FX reference cannot classify a state and cannot bootstrap their own attack authority. A state with contradictory anchor/tag evidence is Unresolved.
- Each `AnimationClip.m_Events` list element is one identity-bearing event block. Its ordinal, exact finite decimal `time`, `functionName`, and `objectReferenceParameter` are read from that same block; missing/duplicate fields, cross-element reuse, or a first-function fallback is invalid. `AnimationEvent` identity includes clip GUID/fileID plus event ordinal. `ActionHasAnimationEvent.eventTime/eventFunctionName` and attack-FX evidence must originate from that same element.
- Each `BlendTree.m_Childs` element is one branch block. The producer reads from that same block its child ordinal, `m_Motion`, `m_Threshold`, `m_Position.{x,y}`, `m_TimeScale`, `m_CycleOffset`, `m_Mirror`, `m_DirectBlendParameter`, and every applicable Direct parameter identity/value. OneD requires threshold and forbids 2D/Direct fields; Simple/Freeform 2D requires X/Y and forbids threshold/Direct fields; Direct requires its parameter identity/vector and forbids threshold/position. An absent `m_TimeScale`, `m_CycleOffset`, or `m_Mirror` may respectively encode only Unity defaults `1`, `0`, or `false`, with locator `<child-block-path>/<field>:AbsentUsesUnityDefault/v1` in the same serialized evidence; no other missing field receives a default. The ordinal is never a threshold.
- Attack traversal starts at every AttackAction `StateUsesMotion` target and recursively follows Motion→ActionClip and BlendTree→every contiguous BlendBranch→Motion/BlendTree with cycle detection. Every reachable attack leaf clip is enumerated and its own event blocks are evaluated. A missing leaf, cycle, unclassified branch, or attack leaf without an authoritative FX outcome keeps R01 Unresolved.
- Asset-backed references are partitioned as `YamlDocumentSubjects ⊎ ExternalLeafSubjects`; the sets are disjoint and cover every nonzero resolved GUID reference. A `.png`, `.tga`, `.jpg`, `.jpeg`, `.psd`, or `.exr` leaf with its exact `.meta` GUID/importer becomes one Texture subject; a `.shader` or `.shadergraph` leaf with its exact `.meta` becomes one Shader subject. Their subject/evidence identity binds portable path, raw bytes/SHA, meta bytes/SHA, GUID, importer kind, and no fabricated YAML document. Material→Texture/Shader resolves by GUID to either partition. Missing/duplicate GUID ownership or unsupported referenced leaf type is unresolved, never a synthetic ReferencedObject.
- Prefab GUIDs partition exactly as `AttackReferencedFXPrefabs ⊎ NonFXPrefabs = AllPrefabGuids`. `AttackReferencedFXPrefabs` is derived only from object references in event blocks reachable from an AttackAction leaf. Only that set creates FXPrefab, FXObject, `FXPrefabContainsObject`, `FXObjectContainsObject`, and FX component closure rows. GameObjects in NonFXPrefabs remain GameObject subjects and cannot enter an FX relationship. A prefab in both roles, an unresolved event target, or any filename/directory-based promotion is invalid.
- For each output member, `obligationRefIds` equals the duplicate-free Ordinal union of originObligationIds from only the evidence, scope, subject, and relationship rows whose authoritative locator is that member or its exact paired `.meta`; `subjectRefIds` follows the same ownership rule. One controller, clip, prefab, material, or other member may legitimately carry multiple distinct obligation IDs, and that exact multi-obligation union is required. Forbidden states are a duplicate ID, an ID outside the derived union, a missing derived ID, attribution without an authoritative locator, or any stored-versus-derived union mismatch; the mere presence of multiple valid IDs is never multiply owned or failure. Blanket attribution to all eleven obligations is forbidden. Every non-support output member must own at least one typed row; an unattributed or mismatched locator is `OutputIntegrityFailure`.

**Failure Transition Table.** `T1A3-FT00` is this docs-only registration: ending HEAD changes only the two mirrored routes; TG01-TG03, TO01/TO02, candidate and LO state remain unchanged; TOT03/TO03 are absent; counters remain `2/6,0/3`; only `AwaitTotalControlAuditBeforeCERGT1A3` is allowed. `T1A3-FT01` is a separately authorized implementation/test failure before commit: TG02/TG03 roll back to the audited starting HEAD, TG01 and TO01/TO02 remain, TOT03/TO03 and every T1B/LO artifact are absent, counters remain `2/6,0/3`, and only `ReturnToTotalControlAuditForCERGT1A3` is allowed. `T1A3-FT02` is corrected TG02/TG03 commit plus canonical Green TO03: TG01 and rejected TO01/TO02 remain immutable, TOT03 and downstream artifacts are absent, counters remain `2/6,0/3`, and only `AwaitTotalControlAuditBeforeCERGT1B` is allowed. `T1A3-FT03` is corrected tool commit present but TO03 unavailable/malformed: preserve that commit and exact observed TOT03/TO03 state, deny T1B, and return to total control; no automatic retry or recovery is authorized.

Fixed counterexamples execute from zero and assert exact row values, not only Closed/counts: two or more events with different time/function/FX references and reordered elements; OneD thresholds distinct from ordinals; 2D positions; Direct parameter identities/values; nondefault timeScale/cycleOffset/mirror; nested and cyclic BlendTrees; an untagged attack state classified only through the valid frozen anchor and closed through AttackAction→BlendTree→nested BlendTree→leaf clip→event→FX; missing and stale anchor variants that must remain Unresolved; real `.mat` GUID references to `.png + .png.meta` and `.shader + .shader.meta`; one model prefab plus one attack-FX prefab in the same output; missing/duplicate external GUID ownership; and one controller/prefab carrying several legitimate obligation IDs whose stored set must equal the exact derived union while duplicate, extra, missing, or locatorless IDs fail. Any semantic mismatch suppresses TO03. `ApprovedForCERGT1B=false` until total control separately approves the exact TO03 SHA and corrective tool HEAD.

#### 2026-07-20 TO03 total-control rejection and TO04 correction contract

This subsection supersedes the TO03 correction and every statement anywhere in this override that could treat TO03, TG02/TG03 v3, a twenty-three-test matrix, or a TO03-based `U1` as consumable. TO01, TO02, and TO03 remain immutable rejected history; no byte is deleted, overwritten, refreshed, or reclassified as producer failure. This docs-only Task changes only the two mirrored routes, consumes no additional ordinary Task or LO, keeps `ordinaryTaskUsed=2/6`, `LOUsed=0/3`, fixes `ApprovedForCERGT1B=false`, and authorizes no tool implementation or fixture execution.

**Artifact Registry.** `T1V22-TO03` is frozen rejected history at `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v3.json`: `4985` bytes, raw SHA-256 `9ffad0ff3bfa28480439e82f004b2f3913b2137d963559e7fdbfee48b2d91c74`, bound commit `644a5fe6f2eba6d4e3338ce08257cb85a6819990`, `auditDisposition=RejectedByTotalControlAudit`, `consumableForT1B=false`, and Ordinal `auditReasonCodes=[BlendTreeTypeMissingOrUnknownAccepted]`. Its embedded Green status records producer output only and grants no authority after this independent rejection.

- `T1V22-TG01` remains the exact committed `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, `19684` bytes, raw SHA-256 `b68b73588816d3cf1e921c84244ab54f8664daaff10abacfc175e541f84599dd`, role/version `ExactLeafStagingWrapper/CERG-LO1-EXACT-STAGING/2`; CERG-T1A4 must not modify it.
- The TO03-bound TG02/TG03 bytes remain rejected historical tool evidence: TG02 is `93212` bytes with raw SHA-256 `70f6156f669698e51e49a64d7dd2f64745baa5a0dab73a84bac41ffcf75b9e5a`, and TG03 is `62814` bytes with raw SHA-256 `249baf8ab4b90c2bf6efa31f6a36678bcf7302ce096e75891d661650336f4554`. CERG-T1A4 may modify only those two tracked paths; successful replacements have versions `R01GraphProducer/CERG-LO1-R01-PRODUCER/4` and `FixtureContractTest/CERG-T1A-PIPELINE-TEST/4`.
- `T1V22-TOT04` is the initially absent, non-consumable temporary leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v4.json.tmp`. `T1V22-TO04` is the initially absent, immutable success-only final leaf `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness-v4.json`, schema/ID `cerg-t1v22-tooling-readiness/1.3.0` / `T1V22-TO04`. Neither may exist during this docs-only Task.
- TO04 top-level fields in order are `schemaVersion`, `artifactId`, `contractHeadCommit`, `priorReadiness`, `toolRows`, `testRows`, `partitions`, `status`, `failures`, `nextAction`. `priorReadiness={artifactId,portableRelativePath,byteCount,sha256,contractHeadCommit,auditDisposition,auditReasonCodes,consumableForT1B}` equals the frozen TO03 row above. `toolRows={artifactId,implementationRole,implementationVersion,portableRelativePath,byteCount,sha256}` is exactly `[T1V22-TG01,T1V22-TG02,T1V22-TG03]`, binding TG01 above and the post-correction committed TG02/TG03 v4 bytes. `contractHeadCommit` is that exact post-correction tool HEAD.
- TO04 is Green-only: `status=Green`, `failures=[]`, `partitions={passedCount:24,failedCount:0,totalCount:24}`, and `nextAction=AwaitTotalControlAuditBeforeCERGT1B`. Any failed, incomplete, skipped, reordered, or prerequisite-suppressed matrix produces no TOT04/TO04 and no tool commit; there is no Failed TO04 form.
- TO04 bytes are exactly `CJ(TO04)` under the existing v2.2 canonical encoding. Test rows retain the exact TO03 `T1A3-TEST01` through `T1A3-TEST23` identity/class/order and append exactly `T1A4-TEST24/BlendTreeTypeEnumStrict`; every row is Passed with `evidenceLocator="SyntheticFixture/<testId>/Assertions"`. After the corrective tool commit fixes HEAD and tool hashes, T1A4 writes complete bytes only to absent TOT04, reopens and recomputes every identity and partition, and performs one same-directory atomic no-overwrite rename to absent TO04; success leaves TOT04 absent. Direct TO04 writes, overwrite, partial consumption, publication before the tool commit, or modification of TO03 is invalid.

**Subject/Partition Registry.** The complete serialized BlendTree-document universe partitions exactly as `BlendTreeDocuments = ValidBlendTreeTypeDocuments ⊎ InvalidBlendTreeTypeDocuments`. The valid set further partitions exactly as `ValidBlendTreeTypeDocuments = OneD(0) ⊎ SimpleDirectional2D(1) ⊎ FreeformDirectional2D(2) ⊎ FreeformCartesian2D(3) ⊎ Direct(4)`; counts over those five mutually exclusive kinds must sum to the complete valid set.

- Every BlendTree document must contain exactly one case-sensitive `m_BlendType` scalar. After YAML structural whitespace is removed, its complete scalar bytes must be exactly one ASCII digit `0`, `1`, `2`, `3`, or `4`; the mapping is exactly the five partitions above.
- Missing, duplicate, empty, `null`/`~`, quoted, signed, leading-zero, decimal, exponent, nonnumeric, negative, or greater-than-four `m_BlendType` is `BlendTreeTypeInvalid`. It may not create a typed BlendTree subject, may not default to OneD or any other kind, and makes direct discovery and R01 Unresolved with `consumableForT2=false`, nonzero `requiredMissingReferenceCount`, and `nextAction=RunCERGT4ForLOCERG1Unresolved`.
- `m_TimeScale`, `m_CycleOffset`, and `m_Mirror` remain the only BlendTree child fields allowed to use the three explicitly frozen Unity defaults. No subject kind, enum, parameter, threshold, position, Direct identity/value, motion, branch, or reference may be inferred from a missing or unsupported scalar.
- T1A4's fixed `BlendTreeTypeEnumStrict` fixture executes from zero and asserts exact semantic values for all five valid mappings plus at least these invalid variants: missing field, duplicate field, malformed `1.0`, and unknown `5`. Every invalid variant must produce the exact Unresolved/non-consumable/zero-typed-BlendTree vector above; a Closed result, a OneD subject, or a zero missing-reference count fails the fixture and suppresses TO04.

**Failure Transition Table.** `T1A4-FT00` is this docs-only registration: ending HEAD changes only the two mirrored routes; TG01-TG03 and TO01-TO03 remain byte-identical; TOT04/TO04, T01/O01, preflight, LO, and Unity artifacts are absent; counters remain `2/6,0/3`; only `AwaitTotalControlAuditBeforeCERGT1A4` is allowed. `T1A4-FT01` is a separately authorized implementation/test failure before commit: TG02/TG03 roll back to the audited T1A4 starting HEAD, TG01 and TO01-TO03 remain unchanged, TOT04/TO04 and every downstream artifact are absent, counters remain `2/6,0/3`, and only `ReturnToTotalControlAuditForCERGT1A4` is allowed. `T1A4-FT02` is a corrected TG02/TG03 commit plus canonical Green TO04: rejected TO01-TO03 remain immutable, TOT04 and downstream artifacts are absent, counters remain `2/6,0/3`, and only `AwaitTotalControlAuditBeforeCERGT1B` is allowed. `T1A4-FT03` is corrected tool commit present but TO04 unavailable, malformed, or not atomically installed: preserve that commit and the exact observed TOT04/TO04 state, deny T1B, and return to total control; no automatic retry or recovery is authorized.

Fixed counterexamples are authoritative: `m_BlendType: 5`, a missing field, a duplicate `0` plus `1`, or malformed `1.0` must never produce Closed, `consumableForT2=true`, a OneD default, or `requiredMissingReferenceCount=0`. Null/empty/unknown values and any attempt to use filename, surrounding tree fields, child thresholds, or an existing test expectation as a type default have the same invalid disposition. For current execution, every later `U1`, tooling-readiness consumer, freshness rule, candidate-lock shape, T1B transition, and preflight prerequisite means committed TG01 plus total-control-approved TG02/TG03 v4 and TO04 with `testCount=passedCount=24`; TO03 is never an input. `ApprovedForCERGT1B=false` until total control separately approves the exact TO04 SHA and corrective tool HEAD.

This docs-only TO04 registration authorizes no TG02/TG03 implementation, fixture execution, TO04 publication, T1B, candidate evidence read, T01/O01, preflight, source read, AssetRipper, Unity, or LO. The sole next action is `AwaitTotalControlAuditBeforeCERGT1A4`.

#### 2026-07-20 T1B finite runtime-attachment binding correction

This subsection supersedes only the v2.2 rules that require every AnimationClip Transform path to resolve inside the selected base-model skeleton before extraction, the one-to-one `ResolveSkeletonAvatar` unavailable-row equation, and the associated T1B transitions/counterexamples. It does not weaken the final dependency, Unity, action, or FX gates. The prior same-HEAD digest diagnosis remains non-consuming history: I04 is still exactly `2037` files, `646020410` bytes, and `df205c3b2eaffe6cf02894277c661b4b43d2ac61122d7dc4a3ecd4c0ac40d48b`; no historical identity is refreshed.

**Artifact Registry.** This docs-only correction creates no CERG artifact. T1V22-T01, T1V22-O01, every preflight/LO/T4 artifact, Imported output, Unity cache, and source write remain absent. The interrupted candidate evaluation has the non-artifact control state `CandidateStatus=PendingFiniteAttachmentDiscovery`; it is neither Passed nor Failed, cannot authorize preflight or T4, cannot change candidate, and consumes no additional Task or LO. Counters remain `ordinaryTaskUsed=3/6`, `LOUsed=0/3`.

- After total-control audit of this exact synchronized override and a separate authorization, the same CERG-T1B slot may be re-executed at the corrected contract HEAD. Only that re-execution may create the already registered no-overwrite T1V22-T01/T1V22-O01. It must revalidate I01-I04, TO04, the seven baseline subjects, the revised binding partitions below, every fingerprint/conservation rule, and all other Passed predicates; this docs-only commit itself is never a candidate lock.
- A future Passed O01 remains schema `cerg-t1-candidate-lock/2.2.0`. For source subject `SUB-fb2b023a90d2091c964c104c586207f3aab3d11a3107f6030424989d995abab5`, the fixed ProvenPresent `ActionClipBindsSkeleton` slot 1 edge means only the complete `DeformBoneBinding` partition defined below. It must not claim that the two runtime attachments already exist. The exact `ResolveSkeletonAvatar` discovery obligation instead owns `ActionClipBindsSkeleton` slots 2 and 3, relationship IDs `REL-88ee5d6446ecc5a41939705806d5ea68a6f13c7669e227af42fbf53f85efe31c` and `REL-a147596cc649bcfe57b6dfc87797f45a55b155ee59db81397dd8bef5e04989e7`. Both have `state=EvidenceUnavailableBeforeExtraction`; target, authority scope, conflicts, and every specialized GraphRelationship field are null; their respective direct evidence locators are exactly `AnimationClip.TransformPath:Root/Weapon02_01` and `AnimationClip.TransformPath:Root/Weapon03_01`. Both rows reference the same obligation and are resolved only to the final composed Skeleton subject after extraction.
- The `ResolveSkeletonAvatar` obligation's `allowedMemberRefIds` is exactly this seven-member Ordinal set and no other member: `C1F-13fcbd36e84837b3f264543d73935b7b888b7a56b6bdec802f1fe19afea5ed67`, `C1F-92cc93af5531f10f3d1e737aad2d4eb63899b4d56d587d89a4c0d64668b317c1`, `C1F-aa3678193d8244a6c4d1c8959c014e8e826605fb226eef0b12ed15b0c65c8b1e`, `C1F-ad2d3e059b232d1a08d28ad36ac4855691a12eb891c40638b09410c8d5a84f23`, `C1F-e94e28674cd1b44a6d19dffa9690717016bdc7eac45316a8bbf795dc43e942d3`, `C1F-ec19f226c8a1eed6a749f566854c32ef955afef5a06ee67fc12c6e8c36b4dcc8`, and `C1F-f221a64f401a01b8a3fbcc3ae3551764bd3d397df9269ae393bf6de59e00b3d9`. These are exactly the two `char_14401` main bundles, two models bundles, two FX bundles, and one weapons bundle already frozen in the seventeen-member candidate universe. A directory, root, prefix, glob, other member, or dynamically discovered selector is forbidden.
- That obligation is exactly `OBL-8f5f94e066b21f54d3925afa8aecc1a6300bc78a8b54153e0a6db067bc3c0d84`, recomputed by the existing obligation formula from `candidateId=char_14401`, `obligationKind=ResolveSkeletonAvatar`, `ownerIdentity=RuntimeAttachmentBindingSet:UnityGuid:16b6b13783e73d648a6faff48a4e3361:[Root/Weapon02_01,Root/Weapon03_01]`, the seven allowed member IDs above, `requiredRelationshipKinds=[ActionClipBindsSkeleton,SerializedObjectReference]`, and `requiredSubjectKinds=[GameObject,Skeleton]`, with each set in Ordinal order. Its dispositions remain `ResolvedByLOCERG1` and `UnresolvedForCERGT2`. Any other owner, ID, kind set, or member set suppresses O01.

**Subject/Partition Registry.** The fixed attack clip's `262` distinct nonempty serialized Transform-path universe partitions exactly as `TransformBindingPaths = DeformBoneBindingPaths ⊎ ResolvedNonDeformModelBindingPaths ⊎ RuntimeAttachmentBindingPaths`, with exact conservation `262=109+151+2`. Membership is authority-derived, never filename- or same-name-derived.

- `DeformClosureTransformPaths` is the complete distinct prefab Transform-path closure of the selected SkinnedMeshRenderer `a99d9cb8935099d4db6bde95d5ddf839:137041608817324026`: all `102` distinct nonzero `m_Bones[*].fileID` slots, `m_RootBone.fileID=4904400124545405`, and every Transform ancestor through the selected model root. The result is exactly `110` distinct Transform identities/paths including the empty relative model-root path. Every nonempty path resolves exactly once in Avatar `1031627e0cce26240a72299bc74e2939`; duplicate, missing, conflicting, or non-Avatar resolution suppresses O01.
- `DeformBoneBindingPaths = TransformBindingPaths ∩ DeformClosureTransformPaths` and contains exactly `109` paths. Every row must resolve to its exact deform-closure Transform; the empty relative model-root path belongs to the model closure but is not a nonempty serialized clip path and therefore is not counted in the `262`-path clip universe.
- `ResolvedNonDeformModelBindingPaths = (TransformBindingPaths ∩ SelectedModelTransformPaths) \ DeformClosureTransformPaths` and contains exactly `151` paths. Every row already resolves by exact full relative path to one selected-model Transform but is not a selected-renderer deform bone. These rows are present evidence, not attachment obligations; a basename-only or ambiguous match is invalid.
- `RuntimeAttachmentBindingPaths` is exactly the two-element Ordinal set `[Root/Weapon02_01,Root/Weapon03_01]`, as directly serialized by ActionClip `16b6b13783e73d648a6faff48a4e3361`. Neither path is in the deform closure. The deeper model paths ending in the same leaf names are distinct identities and may not satisfy, alias, rename, or discharge either row. A third non-deform Transform path, a changed spelling/case, an empty identity, or an unbounded attachment family suppresses O01 and returns to audit rather than broadening discovery.
- The relationship/obligation conservation equation is revised only as follows: ten discovery obligations still own exactly one unavailable relationship each; `ResolveSkeletonAvatar` owns exactly the two ordered runtime-attachment rows above. Therefore `discoveryObligationCount=11`, `EvidenceUnavailableBeforeExtractionCount=12`, and each unavailable row has exactly one obligation while one obligation may own multiple rows only for this frozen two-row exception. All other obligation kinds remain one-to-one. The partitions and summary must encode these exact counts; the former `obligationCount=unavailableCount=11` equation is superseded.
- LO-CERG1 closes each attachment row only by producing an authoritative candidate-local subject plus serialized prefab/composition/ownership relationships from the exact seven allowed members that create the exact final relative path under the selected Animator root. Same leaf name, directory proximity, a standalone weapon prefab, an FX event alone, or producer exit zero is insufficient. Both stored rows, their evidence, and the derived `ResolveSkeletonAvatar` result must be conserved into R01.

**Failure Transition Table.** `T1B-ATT-FT00` is this docs-only correction: only the two synchronized routes change; T01/O01 and every downstream artifact remain absent; tools/readiness/history/protected files remain byte-identical; counters remain `3/6,0/3`; and only `AwaitTotalControlAuditBeforeCorrectedCERGT1B` is allowed. `T1B-ATT-FT01` is a separately authorized corrected T1B whose I01-I04/tooling/deform/attachment/member/graph/partition/safety/output predicate fails: T01 is rolled back, O01/downstream artifacts are absent, the character remains `char_14401`, counters remain `3/6,0/3`, and only `ReturnToTotalControlAuditForT1B` is allowed. `T1B-ATT-FT02` requires every predicate plus the exact two finite attachment obligations: O01 may then be Passed and locked, but the attachment rows remain explicitly unavailable and non-consumable as proof of restoration; counters remain `3/6,0/3`, and only `AwaitTotalControlAuditBeforeLOCERG1Preflight` is allowed.

- LO-CERG1 R01 cannot be Closed unless both exact runtime paths resolve through authoritative final-composition relationships within the frozen seven-member boundary. Missing one, name-only matching, ambiguous ownership, an external member, or failure to reconstruct the exact hierarchy makes R01 Unresolved and cannot reach CERG-T2/Unity.
- CERG-T2 must materialize both exact paths in the final combined character hierarchy, bind their authoritative weapon/attachment objects, and freeze validator evidence for them. Before any action playback in LO-CERG2 or LO-CERG3, the validator must instantiate the required weapon objects, confirm both exact Transform paths, execute the necessary `Animator.Rebind`, and record the post-Rebind binding result. Failure at any of those steps is a hard failure routed to the applicable CERG-T4 `ProjectFailed`; it is not waived as an expected attachment.

Fixed counterexamples are authoritative: accepting either deeper same-name model node at T1B; classifying a selected renderer bone as an attachment; treating any of the `151` already resolved non-deform paths as unavailable; allowing a third unknown Transform path; violating `262=109+151+2`; resolving an attachment from a filename or event without final composition; closing R01 with only one path; building the Unity scene without both exact paths; or playing animation without the required post-instantiation `Animator.Rebind` must fail the applicable gate. Conversely, the exact two unavailable attachment paths with all `110` deform-closure transforms and all `151` resolved non-deform model paths proven must not reject `char_14401` before LO-CERG1.

#### 2026-07-20 T1B unavailable specialized-field correction

This subsection supersedes only the specialized-field non-null rule for `OverrideMapsClip`, `ActionHasAnimationEvent`, and `FXComponentReferencesSubject` while a relationship has `state=EvidenceUnavailableBeforeExtraction`, plus the corresponding LO-CERG1 resolution semantics. It does not change the frozen candidate, input identities, eleven discovery obligations, twelve unavailable relationships, attachment partitions, TO04/tool identities, hard acceptance criteria, or budgets. The rolled-back T1B draft is non-consuming diagnostic history and is not an artifact or candidate decision; counters remain `ordinaryTaskUsed=3/6`, `LOUsed=0/3`.

**Artifact Registry.** This docs-only correction creates no CERG artifact. T1V22-T01, T1V22-O01, preflight, LO-CERG1, Imported output, and Unity/cache paths remain absent. After total-control audit and separate authorization, corrected CERG-T1B may re-run only inside the already consumed T1B slot and may create the existing no-overwrite T1V22-T01/T1V22-O01; it may not start preflight or any LO. The only current next action is `AwaitTotalControlAuditBeforeCorrectedCERGT1B`.

**Subject/Partition Registry.** The specialized-field rule is state-dependent and exact:

- For an `EvidenceUnavailableBeforeExtraction` relationship of kind `OverrideMapsClip`, `ActionHasAnimationEvent`, or `FXComponentReferencesSubject`, `targetSubjectId`, `authorityScopeId`, `authorityScopeFingerprint`, `serializedPropertyPath`, `overrideSourceClipSubjectId`, `eventTime`, and `eventFunctionName` are all JSON `null`; every other inapplicable specialized field is also null. The row remains uniquely located by its candidate/source/kind/slot identity, nonempty direct owner `evidenceRefIds`, non-null `obligationId`, and the exact referenced `DiscoveryObligation`. These rows record a finite discovery requirement, not a fabricated source clip, event block, or serialized property.
- LO-CERG1 resolves an unavailable `OverrideMapsClip` only by creating a new `ProvenPresent` relationship whose real `targetSubjectId` identifies the replacement ActionClip and whose non-null `overrideSourceClipSubjectId` identifies the source ActionClip serialized by the discovered OverrideController authority.
- LO-CERG1 resolves an unavailable `ActionHasAnimationEvent` only by creating a new `ProvenPresent` relationship whose real `targetSubjectId` identifies the AnimationEvent and whose non-null `eventTime` and `eventFunctionName` come from the same discovered serialized event block. Pairing a time and function from different blocks is forbidden.
- LO-CERG1 resolves an unavailable `FXComponentReferencesSubject` only by creating a new `ProvenPresent` relationship whose real typed `targetSubjectId` and non-null `serializedPropertyPath` come from the same discovered serialized FX-component reference slot.
- Each LO-created row has the applicable exhaustive authority scope, nonempty LO evidence, the resolving obligation in `originObligationIds`, and no `obligationId`. Its `relationshipId` is recomputed under the registered v2.2 relationship-ID formula after inserting the real discovered specialized values and must differ from the upstream unavailable relationship ID. The logical source/kind/slot may be conserved, but T1V22-O01 bytes and its unavailable row remain immutable; R01 contains the new current `ProvenPresent` row rather than mutating, copying as current, or reusing the unavailable row ID. The corresponding `obligationResults.relationshipRefIds` references the new ID, and bidirectional origin conservation remains mandatory.
- A Closed R01 contains no current `EvidenceUnavailableBeforeExtraction` row. For each of these three kinds, every resolved obligation must reference the newly computed ProvenPresent row with all real specialized fields required above; placeholder strings, inferred values, null discovered fields, or an upstream unavailable ID make the obligation Unresolved.

The global specialized-field sentence below is therefore state-aware: `serializedPropertyPath` retains its existing rule for `SerializedObjectReference`, is non-null for a ProvenPresent `FXComponentReferencesSubject`, and is null for an unavailable `FXComponentReferencesSubject`; `overrideSourceClipSubjectId` is non-null for a ProvenPresent `OverrideMapsClip` and null for an unavailable one; and `eventTime` plus `eventFunctionName` are non-null for a ProvenPresent `ActionHasAnimationEvent` and null for an unavailable one. Every other relationship kind/state retains its existing contract.

**Failure Transition Table.** `T1B-FIELD-FT00` is this docs-only correction: only the two synchronized routes change; T01/O01 and all downstream artifacts remain absent; TO04, TG01-TG03, history, protected files, counts, partitions, and counters remain unchanged; only `AwaitTotalControlAuditBeforeCorrectedCERGT1B` is allowed. `T1B-FIELD-FT01` is a separately authorized corrected T1B with any non-null unavailable specialized field, missing owner evidence/obligation, fabricated discovered value, or other candidate predicate failure: T01 is rolled back, O01/downstream artifacts are absent, the candidate remains `char_14401`, counters remain `3/6,0/3`, and only `ReturnToTotalControlAuditForT1B` is allowed. `T1B-FIELD-FT02` permits the existing Passed O01 only when all candidate predicates pass and all twelve unavailable rows use the corrected null-field representation; it remains non-consumable as restoration proof and stops at `AwaitTotalControlAuditBeforeLOCERG1Preflight`. At LO-CERG1, reuse or mutation of an unavailable relationship ID, missing real specialized data, cross-block event pairing, or a placeholder property/source-clip identity forces the applicable obligation and R01 to Unresolved and cannot authorize T2.

Fixed counterexamples are authoritative: an unavailable override row carrying a guessed source clip, an unavailable event row carrying `0` or the first function in a clip, and an unavailable FX reference row carrying a guessed property path must suppress O01. The same rows with all specialized fields null, exact owner evidence, and the exact obligation are legal pending rows but are never ProvenPresent. Conversely, an R01 that merely preserves those nulls, reuses the O01 relationship ID, joins event fields from different blocks, or inserts any placeholder cannot claim resolution; only newly identified ProvenPresent rows with actual same-authority serialized values and newly recomputed IDs can close the obligations.


#### 2026-07-21 LO-CERG1 preflight false-green contract recovery

This newest subsection is the sole authority for LO-CERG1 preflight production, TG01 consumption, the original P01/A01 disposition, recovery accounting, and next action. Conflicting earlier P01 fields, TG01 identity, attempt interpretation, counters, and retry text are superseded. Candidate O01, its eleven obligations/twelve unavailable relationships, source-member universe, and hard acceptance criteria are unchanged.

**Artifact Registry and defect evidence.**

- Original `LO1-P01` at `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json` is immutable: `15584` bytes, raw SHA-256 `23f0fd29a07963c7bc9f11171d888c9ae2dac9d9d6581a896fff0142e5705f21`. Original `LO1-A01` at `Extracted/CERG/SingleCharacter/LO-CERG1/attempt-state.json` is immutable: `551` bytes, raw SHA-256 `3cfaa6c538b46cc726f49b04cdef24e3442e2872063ccbbf1230a78dfcdba8cd`. Both are non-consumable `PreflightFalseGreenContractDefect` evidence; neither may be deleted, overwritten, refreshed, repaired in place, or used by a replacement.
- Original P01 declared Green without `stagingInputPrivateAbsolutePath` or the other TG01-required private paths. A01 was installed, then TG01 rejected before opening any SourceMember; SD01/SIT01/SI01/WD01/D01/R01 remained absent. This is not an asset-content, dependency, candidate, extraction, or Unity failure and cannot itself produce `ProjectFailed`.
- The only future replacement namespace is the initially absent `Extracted/CERG/SingleCharacter/LO-CERG1-R1`. Its PT01/P01, AT01/A01, SD01/SIT01/SI01/WD01/D01/R01 are new leaves under that root and may not alias, overwrite, rename, or import the original P01/A01.
- `LO1-IP01` is `Tools/AssetImport/New-CergLo1Preflight.ps1`, `17591` bytes, SHA-256 `ae674bf964077ddadd660bc861f10d6d827729d2aae4e12b3ba120d543744b97`. Corrected TG01 is `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, `ExactLeafStagingWrapper/CERG-LO1-EXACT-STAGING/3`, `19968` bytes, SHA-256 `012ebb76ab2eb433a37b6a62f30eb53b66be2e26f9a87fe74c6acbcc61e26b73`. Corrected TG02 is `Tools/AssetImport/New-CergLo1ResultGraph.ps1`, `R01GraphProducer/CERG-LO1-R01-PRODUCER/5`, `94071` bytes, SHA-256 `00b8690509760379c1c62f37f0ae89d761c8a0a2cb76b81224f6b915be345152`; it accepts only P01 v1.4 and emits `cerg-lo-cerg1-result/1.3.0`. Focused test `Tools/AssetImport/Test-CergLo1PreflightContract.ps1` is `6162` bytes, SHA-256 `b9dbff4ae974b51bde8a70e4ea4569da4774b11b61e15a033765567ff25c34f1`. Corrected TG03 `Tools/AssetImport/Test-CergLo1Pipeline.ps1` is `CERG-T1A-PIPELINE-TEST/5`, `73451` bytes, SHA-256 `7cb28e027421ddc17c9939cc550124ef5547a4014d2e5dfe8ec7cdaf14f2be4e`. TO04 remains immutable history for its bound bytes and does not approve these changed bytes; total control must audit this recovery commit and all five identities before replacement.

**P01 v1.4 producer/consumer contract.** Replacement P01 is exactly `cerg-lo-cerg1-preflight/1.4.0` / `LO-CERG1-P01` with ordered top-level fields `schemaVersion,artifactId,candidateLockSha256,contractHeadCommit,selectedCandidateId,createdAt,sourceRootBindings,implementationBindings,operation,aggregateLimits,stagingPlan,status,nextAction` and fixed `Green` / `RequestExactHumanConfirmationForLOCERG1`.

- Production starts with one in-memory `cerg-lo-cerg1-preflight-definition/1.0.0` / `LO-CERG1-P01-DEFINITION`. Its `stagingPlan` contains only `stagingInputPortablePath,stagingInventoryTemporaryPath,stagingInventoryPath,workPortablePath,outputPortablePath,memberRows,memberCount,byteCount,memberSetFingerprint`; hidden fixture/caller fields are forbidden. `New-CergLo1PreflightObject` alone adds private paths.
- Final `stagingPlan` is exactly, in order, `attemptPrivateAbsoluteRoot,stagingInputPortablePath,stagingInputPrivateAbsolutePath,stagingInventoryTemporaryPath,stagingInventoryTemporaryPrivateAbsolutePath,stagingInventoryPath,stagingInventoryPrivateAbsolutePath,workPortablePath,workPrivateAbsolutePath,outputPortablePath,outputPrivateAbsolutePath,memberRows,memberCount,byteCount,memberSetFingerprint`.
- `attemptPrivateAbsoluteRoot` is one normalized, selector-free, machine-private absolute R1 root. The constructor alone derives distinct contained descendants `Input`, `staging-inventory.json.tmp`, `staging-inventory.json`, `Work`, and `Output`; callers cannot supply them independently. They cannot overlap a source root. Portable operation/staging mappings, operation/aggregate limits, candidate/operation/plan member-ID sets, rows/count/bytes/fingerprint, and TG01 inventory arguments must match exactly.
- Missing, extra, reordered, null, relative, selector-bearing, escaping, overlapping, duplicate, mismatched, or independently supplied consumer-required data is `PreflightConsumerContractFailure`. Before PT01/P01 installation, the complete production object and candidate pass `Assert-CergLo1PreflightConsumerContract`. After atomic no-overwrite installation, reopened P01 passes the same function with exact TG01 arguments. Immediately before A01 creation it passes again. TG01 calls it before creating Input/Work/Output/inventory or opening a SourceMember. Therefore a consumer-incomplete P01 cannot create A01.
- The focused end-to-end test constructs P01 only through the production constructor, passes the object directly into the TG01 precondition without creating an attempt directory, and removes each of the six private root/path fields to prove rejection. Its definition fixture has no production-undeclared field. The pipeline has exactly twenty-five tests: its positive chain is `v1.4 P01 → TG01 SI01 → TG02 R01 v1.3`, and TEST25 removes each private field in turn and requires both TG01 and TG02 to reject before any new result. Every graph fixture uses the production constructor and real TG01 synthetic staging; no hand-built v1.3 P01 or SI01 is allowed.

**Budget and replacement conservation.** `CERG-Contract-Recovery-1` consumes one newly authorized ordinary Task: `ordinaryTaskUsed=4/7`, `ordinaryTaskBudget=7`. The added slot is only for this recovery. Original A01 permanently records `physicalLOAttemptCount=1`; `PreflightFalseGreenContractDefect` explicitly records `invalidatedPhysicalLOAttemptCount=1` and restores `budgetedLOUsed=0/3` because `sourceMembersOpened=0`. This named one-time correction is the only refund and may not be inferred elsewhere.

Only after total-control audit may one separately authorized `ReplacementLOCERG1Attempt` exist. Its start records `physicalLOAttemptCount=2`, `replacementAttemptOrdinal=1`, and `budgetedLOUsed=1/3`. It is not automatic and is not a retry of original bytes. Success, failure, cancellation, interruption, or preflight exhaustion consumes the unique replacement authority; no second replacement, repeat publication, implicit refund, tool rotation, or boundary expansion is allowed. LO-CERG2 and conditional LO-CERG3 retain the other two LO slots.

**Failure Transition Table.**

- `CR1-FT00/PreflightFalseGreenContractDefect`: immutable original P01/A01 present; original data/output/R01 absent; zero source opens and no AssetRipper/Unity; nonterminal/non-asset disposition; counters `4/7,0/3`.
- `CR1-FT01/RecoveryImplementationFailed`: before commit, roll back only this Task's tracked changes; retain original evidence and create no replacement; stop without replacement authority.
- `CR1-FT02/RecoveryReadyForAudit`: synchronized overrides, the five identities above, focused `8/8 Passed`, regression `25/25 Passed`, syntax and `git diff --check` Green, unchanged original/protected hashes, and no replacement/source/producer/Unity output. Counters are `4/7,0/3`; sole next action `AwaitTotalControlAuditBeforeAnyReplacementLO`.
- `CR1-FT03/ReplacementPreflightRejected`: after a later exact authorization, any construction/schema/identity/freshness/install/reopen/confirmation failure leaves replacement A01/data/output absent, exhausts replacement authority, forbids automatic retry, and permits only binary-failure handling.
- `CR1-FT04/ReplacementAttemptStarted`: only audited v1.4 P01 plus exact confirmation may atomically install replacement A01 before source open. Valid R01 continues to T2; absent valid R01 follows the existing failure route with no further replacement.

Fixed counterexamples include old P01 plus a fixture-hidden field, TG02 accepting or fixtures hand-building P01 v1.3, independently supplied descendants, any missing private field, relative/glob/escape, source overlap, operation/aggregate mismatch, member omission/duplication, CLI/P01 inventory mismatch, TG02 SI01/output paths differing from v1.4 P01, A01 before reopened validation, original overwrite, zero-source defect treated as asset failure, and automatic R1 start/retry. This recovery Task reads no source, starts no LO/AssetRipper/Unity, creates no replacement artifact, and changes no Extracted byte.

#### 2026-07-21 CERG-T4 replacement-preflight false-green terminal closure

This newest subsection is the sole authority for the consumed replacement attempt and the CERG terminal result. It supersedes every earlier T4 schema, cause enum, counter row, sequence continuation, and next action that conflicts with this observed state. The replacement attempt is consumed exactly once at `LOUsed=1/3`; it cannot be retried, refunded, renamed as another preflight, or continued into T2 or Unity.

**Artifact Registry.** The replacement P01 and A01 remain immutable inputs. `LO1-R1-P01` is `Extracted/CERG/SingleCharacter/LO-CERG1-R1/preflight.json`, `16617` bytes, SHA-256 `aff9ac999f01523956e9c2608b890f88d6d19ad0045646635673dd07e2565627`. `LO1-R1-A01` is `Extracted/CERG/SingleCharacter/LO-CERG1-R1/attempt-state.json`, `551` bytes, SHA-256 `4d632844de778b4e3801f12bb0dfa7e63261b70805cb7cee80270e51fd43a849`. Neither may be deleted, overwritten, refreshed, or reclassified.

- `T4-T01` is the initially absent temporary leaf `Extracted/CERG/SingleCharacter/T4/terminal-result.json.tmp`. It is never consumable and is absent after a successful install.
- `T4-O01` is the initially absent immutable final leaf `Extracted/CERG/SingleCharacter/T4/terminal-result.json`. Its schema/ID are `cerg-terminal-result/1.2.0` / `CERG-T4-O01`. Top-level fields, in order, are `schemaVersion`, `artifactId`, `contractHeadCommit`, `terminalContractOverrideSha256`, `terminalResult`, `terminalCause`, `terminalReason`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `candidateId`, `upstreamArtifactRefs`, `failureEvidence`, `evidenceRefIds`, `retainedState`, `claimScope`, `nextAction`.
- Fixed terminal values are `terminalResult=ProjectFailed`, `terminalCause=ReplacementPreflightFalseGreen`, `terminalReason="ReplacementPreflightFalseGreen / stale source-member identities; fixed route failed before extraction."`, `ordinaryTaskUsed=5`, `ordinaryTaskBudget=7`, `LOUsed=1`, `LOBudget=3`, `candidateId=char_14401`, `claimScope=ThisFixedRouteDidNotProveSuccess_NotIntrinsicAssetImpossibility`, and `nextAction=StopCERG`. `contractHeadCommit` is the committed synchronized-route HEAD that defines this subsection; `terminalContractOverrideSha256` is the raw SHA-256 of the heading-bounded normative override at that HEAD.
- `upstreamArtifactRefs={artifactId,portableRelativePath,byteCount,sha256}` is exactly the two rows for `LO1-R1-A01` and `LO1-R1-P01` above, sorted Ordinal by `artifactId`. No source absolute path, source byte, or unrestricted log is projected.
- `failureEvidence` is one Ordinal-sorted array of a closed tagged union. `SourceMemberLengthMismatch={evidenceId,evidenceKind,portableRelativePath,expectedByteCount,observedByteCount,firstFailure}`; `SourceMemberDriftAggregate={evidenceId,evidenceKind,evaluatedMemberCount,driftedMemberCount,preexistingBeforeP01Creation}`; `StagedLeafIdentity={evidenceId,evidenceKind,portableRelativePath,byteCount,sha256}`; `ArtifactAbsence={evidenceId,evidenceKind,artifactId,portableRelativePath}`; and `ExecutionSuppression={evidenceId,evidenceKind,assetRipperStarted,tg02Started,unityStarted}`. No other shape or evidence kind is legal.
- The exact mismatch rows are `InstallResource/char_14401.unity3d`, expected `268605`, observed `268634`, `firstFailure=true`; and `InstallResource/char_14401_animations.unity3d`, expected `54450761`, observed `54889767`, `firstFailure=false`. The aggregate row fixes `evaluatedMemberCount=17`, `driftedMemberCount=8`, and `preexistingBeforeP01Creation=true`. This means P01 was false Green when published; it does not describe a mutation after confirmation.
- The exact five `StagedLeafIdentity` rows are under portable prefix `pc-install/Persistent_Store/AssetBundles/`: `char_14401_animations.unity3d|37819874|8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d`, `char_14401_fx.unity3d|1944422|02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab`, `char_14401_models.unity3d|3080984|66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7`, `char_14401_timeline.unity3d|4341943|22cafed7bb84fec59a0b2f4ccf0687ff9434ad38e7a21de9041ca313565d0228`, and `char_14401.unity3d|259486|c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b`. Their conservation is `stagedLeafCount=5`, `stagedBytes=47446709`.
- `ArtifactAbsence` has exactly three rows for `LO1-R1-SI01/Extracted/CERG/SingleCharacter/LO-CERG1-R1/staging-inventory.json`, `LO1-R1-D01/Extracted/CERG/SingleCharacter/LO-CERG1-R1/Output`, and `LO1-R1-R01/Extracted/CERG/SingleCharacter/LO-CERG1-R1/result.json`. The single `ExecutionSuppression` row fixes all three booleans false. `evidenceRefIds` equals the complete duplicate-free set of every `failureEvidence[*].evidenceId`, sorted Ordinal; no evidence row may be omitted or referenced twice.
- `retainedState={preflightDisposition,attemptDisposition,partialStagingDisposition,stagingInventoryDisposition,workDisposition,outputDisposition,resultDisposition,retryDisposition}` is exactly `FalseGreenImmutable`, `ConsumedNoResultImmutable`, `PreserveReadOnly`, `Absent`, `Absent`, `Absent`, `Absent`, `Forbidden`. T4 creates no source, staging, inventory, Work, Output, R01, Imported, cache, scene, script, or Unity process.
- T4 writes complete canonical JSON to absent T4-T01, reopens and validates schema, field order, identities, partitions, counters, hashes, and the exact reason, then atomically installs it by same-directory no-overwrite rename to absent T4-O01. Direct final writes, overwrite, cleanup, or partial consumption are forbidden.

**Subject/Partition Registry.** The audited replacement member universe partitions exactly as `ReplacementSourceMembers = FreshAtAudit ⊎ DriftedAtAudit`, with `17=9+8`. The staging plan partitions exactly as `ReplacementSourceMembers = RetainedStagedMembers ⊎ UnstagedMembers`, with `17=5+12`; the five retained rows and `47446709` bytes above are identity-correct but do not constitute SI01 or dependency closure. The two partitions answer different questions and may not be conflated. The candidate remains exactly `char_14401`; there is no candidate rotation, asset rejection, dependency verdict, action verdict, FX verdict, or Unity verdict.

**Failure Transition Table.** `T4-RPF-FT01` triggers only from the exact immutable P01/A01 plus the audited false-Green vector above. It produces exactly one valid T4-O01, leaves T4-T01 absent, preserves P01/A01/partial staging, keeps SI01/Work/Output/R01/T2/Imported/Unity/T3/LO3 absent, records `5/7,1/3`, and has the sole next action `StopCERG`. Failure before the T4 commit/install rolls back only this Task's docs/T4 temporary bytes and returns to total control without changing P01/A01/staging or authorizing a retry. A committed T4 contract with unavailable/malformed T4-O01 preserves the exact temporary/final state and returns to total control; it never fabricates success, retries LO, or starts downstream work.

Fixed counterexamples are authoritative: changing the terminal reason to source mutation after confirmation; reporting the first mismatch as `_animations`; treating five staged leaves as SI01; refunding LOUsed; starting another replacement, T2, AssetRipper, TG02, Unity, or cleanup; or claiming the character is intrinsically unrestorable invalidates T4-O01. This T4 result is solely the fixed-route statement that success was not proven before extraction because the replacement preflight was false Green.

#### 2026-07-21 real-world freshness recovery admission gate

This subsection records a recovery gate only. It does not invalidate, overwrite, or reinterpret T4-O01; it grants no R2 implementation, source read, preflight execution, A01, LO, AssetRipper, TG02, Unity, cleanup, or budget change. `StopCERG` remains in force until the user explicitly authorizes a named recovery Task.

**Normative invariant.** Every field whose value is `Green` must reference at least one check row produced by a just-completed real check whose inputs, implementation identity, observed values, time, and result can be independently recomputed. A Green field with an empty, stale, synthetic-only, producer-self-attested, or non-resolving evidence reference is invalid and fails closed.

**Executable schema.** A future R2 freshness artifact is `cerg-lo-cerg1-r2-freshness/1.0.0` / `LO-CERG1-R2-F01` at `Extracted/CERG/SingleCharacter/LO-CERG1-R2/freshness.json`; its temporary leaf is the same path plus `.tmp`. Both are initially absent. Its top-level shape is exactly:

The authorized implementation paths are fixed: `R2-TG01=Tools/AssetImport/New-CergLo1R2Freshness.ps1` (real-check producer), `R2-TG02=Tools/AssetImport/Test-CergLo1R2Freshness.ps1` (independent real-check validator), and `R2-TG03=Tools/AssetImport/Test-CergLo1R2FreshnessPipeline.ps1` (synthetic/adversarial harness). Integration may modify only `Tools/AssetImport/New-CergLo1Preflight.ps1`, `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, and `Tools/AssetImport/New-CergLo1ResultGraph.ps1` to add the v1.5 freshness/input-set binding while retaining v1.4 regression compatibility. The implementation Task reads no real source and creates no R2 F01/P01/A01/staging.

`R2-TO01` is the initially absent immutable readiness artifact `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness.json`; its temporary leaf adds `.tmp`. Schema/ID are `cerg-r2-tooling-readiness/1.0.0` / `R2-TO01` and its exact shape is `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}`. `toolRows={artifactId,role,portableRelativePath,byteCount,sha256}` contains TG01-TG03 plus the three modified integration tools, sorted by artifactId. `testRows={testId,status,evidenceLocator}` is exactly the 18 ordered IDs frozen below, all Passed with a nonempty synthetic locator. Green fixes `status=Green`, `failures=[]`, `nextAction=AwaitTotalControlAuditBeforeR2FreshnessRun`. It is published only after the tool commit by temporary reopen plus atomic no-overwrite install. This authorized Task records `recoveryImplementationTaskUsed=1/1` without altering terminal CERG counters or consuming an LO.

~~~text
{schemaVersion,artifactId,contractHeadCommit,candidateLockSha256,checkRunId,
 producerImplementation,validatorImplementation,startedAtUtc,producerFinishedAtUtc,
 validatorFinishedAtUtc,sourceSelectors,producerRows,validatorRows,currentMembers,
 currentMemberSetFingerprint,fixedCounterexamples,successPathChecks,postSuccessAttackChecks,
 greenClaims,status,nextAction}
Implementation={implementationId,role,portableRelativePath,byteCount,sha256}
SourceSelector={selectorId,sourceId,portableRelativePath}
LeafCheck={checkId,implementationId,selectorId,checkedAtUtc,exists,fileKind,isReparsePoint,
 observedByteCount,observedSha256,status}
CurrentMember={memberId,selectorId,sourceId,portableRelativePath,byteCount,sha256}
TestRow={testId,status,evidenceRefIds}
GreenClaim={claimId,status,evidenceRefIds}
~~~

Only `fileKind=RegularFile`, `isReparsePoint=false`, lowercase 64-hex `observedSha256`, and JSON integer byte counts are valid. `producerImplementation.role=Producer`; `validatorImplementation.role=IndependentValidator`; paths and SHA-256 values must differ, and the implementations may not share leaf enumeration/stat/reparse/hash decision code. The validator must open and hash the real leaf independently; reading producer JSON, trusting producer exit zero, or reusing a producer helper is not validation.

**Sets, identity, and conservation.** `sourceSelectors` is exactly the duplicate-free 17-row projection of audited T1V22-O01 `sourceMembers[*].{sourceId,portableRelativePath}`; no old size or hash is a success predicate. `selectorId="R2S-"+sha256(CJ(["cerg-r2/source-selector-id/1",sourceId,portableRelativePath]))`; `implementationId="R2I-"+sha256(CJ(["cerg-r2/implementation-id/1",role,portableRelativePath,byteCount,sha256]))`; `checkRunId="R2RUN-"+sha256(CJ(["cerg-r2/check-run-id/1",contractHeadCommit,candidateLockSha256,startedAtUtc]))`; and `checkId="R2C-"+sha256(CJ(["cerg-r2/leaf-check-id/1",checkRunId,implementationId,selectorId]))`. Each selector has exactly one Producer row and one IndependentValidator row, so `|producerRows|=|validatorRows|=17`, both selector-ID sets equal `sourceSelectors`, and every row performs all five real checks: existence, regular file, non-reparse, byte count, and SHA-256. Producer and validator observed tuples must be byte-identical per selector. A current member ID is `"R2M-"+sha256(CJ(["cerg-r2/current-member-id/1",sourceId,portableRelativePath,byteCount,sha256]))`; the set fingerprint is `sha256(CJ(["cerg-r2/current-source-member-set/1", sorted Ordinal [memberId,sourceId,portableRelativePath,byteCount,sha256] rows]))`. All formulas use the already frozen v2.2 `CJ`: UTF-8 without BOM, NFC strings, JSON integers, explicit nulls, array order as written, Ordinal sorting where stated, no insignificant whitespace, and lowercase SHA-256. Changed identity at the same selector creates a new CurrentMember and is not candidate failure. Missing, non-regular, reparse, unreadable, unstable-during-hash, duplicate, omitted, extra, or producer/validator-disagreeing selectors fail closed and suppress CurrentMembers, the fingerprint, Green, P01, and A01.

**Freshness adjacency.** The validator run is the final operation before A01 construction: no source-dependent operation, artifact reuse, tool rotation, sleep, or unrelated check may intervene. A01 may be atomically installed only when all 17 validator rows were completed in the same foreground `checkRunId`, `A01.createdAtUtc-validatorFinishedAtUtc <= 10 seconds`, the freshness artifact raw SHA-256 is bound by A01, and an immediate final reopen confirms all 17 selector paths still resolve as regular non-reparse leaves with the recorded byte counts. Any violation discards authorization, leaves A01 absent, and requires a newly authorized freshness run; hours-old or prior-attempt evidence is never reusable.

**Mandatory execution order.**

1. Fixed counterexamples first: missing leaf, directory, reparse point, byte drift, hash drift with equal size, duplicate/omitted selector, producer/validator disagreement, stale `checkRunId`, fixture-only hidden field, and producer output splice.
2. Successful path second: the production constructor creates the complete object, the independent validator consumes it, and the future staging consumer consumes those exact bytes; fixtures may not add a field absent from the production schema.
3. Audit-style attack last: independently mutate one selector, one observed tuple, one evidence reference, one timestamp, and one implementation binding in turn; every mutation must turn the result into failed-closed before publication.

The ordered test IDs are exact: `fixedCounterexamples=[R2-CE01-Missing,R2-CE02-Directory,R2-CE03-Reparse,R2-CE04-ByteDrift,R2-CE05-EqualSizeHashDrift,R2-CE06-SelectorConservation,R2-CE07-IndependentDisagreement,R2-CE08-StaleRun,R2-CE09-HiddenField,R2-CE10-ProducerSplice]`; `successPathChecks=[R2-SP01-ProductionConstructor,R2-SP02-IndependentValidator,R2-SP03-StagingConsumer]`; and `postSuccessAttackChecks=[R2-AT01-SelectorMutation,R2-AT02-TupleMutation,R2-AT03-EvidenceMutation,R2-AT04-TimeMutation,R2-AT05-ImplementationMutation]`. Every TestRow is `Passed` only when its direct evidence refs resolve to the actual run. Every `evidenceRefId` resolves exactly once to an implementation, leaf-check, or TestRow identity, and reverse reference sets must match. `greenClaims` is exactly `[All17LeavesExist,All17LeavesRegular,All17LeavesNonReparse,All17SizesObserved,All17HashesObserved,ProducerValidatorAgree,FreshnessRunComplete,ConstructorConsumerSchemaExact,CounterexamplesPassed,PostSuccessAttackPassed]`; every row has `status=Green` and at least two direct refs where both implementations are relevant. `FreshnessRunComplete` means only that F01 was just produced; the 10-second `FreshnessAdjacent` decision belongs exclusively to the later A01 guard and cannot be pre-claimed by F01. Green is valid only when all check/test/claim references resolve bidirectionally and all equations hold.

**State table.**

| State | Required evidence | Output vector | Only next action |
|---|---|---|---|
| `RecoveryGateRecorded` | This synchronized contract commit | R2 tools/F01/P01/A01 absent; T4/R1 unchanged | `StopCERGUntilExplicitRecoveryAuthorization` |
| `RecoveryImplementationRejected` | Any tool, schema, independence, counterexample, production-chain, or self-attack failure | No committed recovery tools; R2 F01/P01/A01 absent | `ReturnToTotalControlAudit` |
| `RecoveryImplementationReady` | Independent producer/validator plus all synthetic and adversarial tests Green | Tool-readiness artifact only; source unread; R2 F01/P01/A01 absent | `AwaitTotalControlAuditBeforeR2FreshnessRun` |
| `R2FreshnessFailedClosed` | Any real leaf/check/freshness/evidence/conservation failure | Diagnostic F01 allowed; P01/A01/staging absent; R1 isolated | `ReturnToTotalControlAudit_NoLO` |
| `R2FreshnessGreen` | All 17 current rows, independent agreement, fixed counterexamples, success chain, post-success attack, and direct Green evidence | Immutable F01 plus current-set fingerprint; A01/staging absent | `RequestExactHumanConfirmationForR2` |
| `R2AttemptStarted` | Exact confirmation plus the same-run 10-second adjacency and final reopen | New R2 A01 before first source copy; R1 remains isolated | `ExecuteOnlyTheSeparatelyAuthorizedR2LO` |

No state in this subsection itself authorizes the final row. A future R2 must use the new namespace only; R1 and its five retained staged leaves remain permanently isolated and may never be read as R2 input or copied into R2.

#### 2026-07-21 R2 readiness audit correction

This correction is inside the same already-consumed recovery implementation Task and changes no CERG terminal counter or LO counter. It supersedes only the prior R2 readiness-generation, test-count, and next-action statements. It authorizes no real source read, F01, P01, A01, staging, R2 LO, AssetRipper, TG02 runtime extraction, or Unity.

`R2-TO01` remains immutable rejected history at `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness.json`: `3864` bytes, raw SHA-256 `ae88d9868972092d9806bbb52f5525f4ec57c5f07030adc19058298e78410d15`, bound commit `241f4d4da9bff58f3e49b36de91e86ff6fbd93c1`, `auditDisposition=RejectedByTotalControlAudit`, `consumableForR2FreshnessRun=false`, and Ordinal `auditReasonCodes=[AncestorReparseUnchecked,V14RegressionIncomplete]`. It is never deleted, overwritten, refreshed, or used as Green authority.

`R2-TOT02` is the initially absent temporary leaf `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v2.json.tmp`. `R2-TO02` is the initially absent immutable final leaf `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v2.json`, schema/ID `cerg-r2-tooling-readiness/1.1.0` / `R2-TO02`. Its exact top-level shape is `{schemaVersion,artifactId,contractHeadCommit,priorReadiness,toolRows,testRows,status,failures,nextAction}`; `priorReadiness={artifactId,portableRelativePath,byteCount,sha256,auditDisposition,auditReasonCodes}` binds the frozen R2-TO01 tuple above. `toolRows` contains the six prior R2/integration tools plus `Tools/AssetImport/Test-CergLo1Pipeline.ps1`, sorted Ordinal by `artifactId`, and binds post-correction committed bytes.

The R2 matrix is exactly 19 rows: the prior ordered 18 IDs plus `R2-CE11-AncestorReparse` immediately after `R2-CE10-ProducerSplice`. CE11 must independently prove producer rejection, validator rejection, and final-reopen rejection when a lexical root-contained parent directory is replaced by a junction to outside the registered root. The v1.4 compatibility matrix is exactly 25 further rows in this order: `T1A3-TEST01` through `T1A3-TEST23`, then `T1A4-TEST24`, `T1A4-TEST25`. R2-TO02 therefore has exactly 44 `testRows={testId,status,evidenceLocator}`, all Passed with nonempty direct locators; omitting either matrix, accepting a fixed candidate SHA placeholder, checking only the leaf reparse bit, or relying on a prior process result suppresses Green.

Green R2-TO02 fixes `status=Green`, `failures=[]`, and `nextAction=AwaitTotalControlAuditBeforeR2FreshnessRun`. It is created only after the correction commit, reopened, independently rechecks all seven tool identities plus the exact 19/19 and 25/25 matrices, and is atomically installed by same-directory no-overwrite rename. Any failure leaves R2-TO02 absent and returns to total control. `recoveryImplementationTaskUsed=1/1`, `ordinaryTaskUsed=5/7`, and `LOUsed=1/3` remain unchanged.

#### 2026-07-22 R2 A01 adjacency A+ contract correction

This subsection supersedes every earlier R2 statement that measures freshness only to A01 installation or permits A01 and LO to run in different process/tool invocations. A+ is the only permitted handoff: independently audited P01 v1.5, exact human confirmation, one foreground runner, immutable F02, immutable A01, and immediate entry into the exact-leaf LO wrapper. This implementation Task may modify only the two synchronized routes, R2 freshness validator, exact staging wrapper, the new atomic runner, and synthetic tests. It must not read any real source leaf or create real P01, F02, A01, H01, staging, LO, AssetRipper, or Unity output. Counters remain `ordinaryTaskUsed=5/7`, `LOUsed=1/3`.

**Artifact Registry.** The confirmed immutable F01 remains `Extracted/CERG/SingleCharacter/LO-CERG1-R2/freshness.json`, raw SHA-256 `c42b1e5b91ff4d9dcb50ca2658d44aa7e503ede322b76ecf448dda5f0bb9257a`, `checkRunId=R2RUN-30af96a77ad2b8c455abe6be0ce03927bcf45d42e53fa27a9d12f15025ff92dd`, and `currentMemberSetFingerprint=b4b80b2da7169e600219156accfbe286fcfd9293f1220d1b579b8ca9f0e4918c`. It is not rewritten. Future P01 is the independently produced and audited `cerg-lo-cerg1-preflight/1.5.0` / `LO-CERG1-P01` at `Extracted/CERG/SingleCharacter/LO-CERG1-R2/preflight.json`; it binds F01 raw SHA/run/fingerprint, the candidate/contract identities, exact 17 current members, exact root bindings, six private attempt paths, limits, and staging bijection. P01 creation and audit are a separate checkpoint before confirmation and before the A+ runner.

The exact confirmation is `confirmationId="R2CONF-"+sha256(CJ(["cerg-r2/p01-confirmation-id/1",contractHeadCommit,F01RawSha256,F01CheckRunId,F01MemberSetFingerprint,P01RawSha256,runnerImplementationId]))`. It confirms those bytes and identities only; it does not consume an LO or authorize a different runner.

The A+ runner is `Tools/AssetImport/Invoke-CergLo1R2AtomicHandoff.ps1`. Its identity is `runnerImplementationId="R2RUNNER-"+sha256(CJ(["cerg-r2/atomic-runner-id/1",portableRelativePath,byteCount,rawSha256]))`. Its synthetic contract test is `Tools/AssetImport/Test-CergLo1R2AtomicHandoff.ps1`. The runner alone may create these initially absent, no-overwrite leaves:

- `F02-TMP=Extracted/CERG/SingleCharacter/LO-CERG1-R2/freshness-adjacency.json.tmp`; `F02=.../freshness-adjacency.json`, schema/ID `cerg-lo-cerg1-r2-adjacency-freshness/1.0.0` / `LO-CERG1-R2-F02`. Its exact field order and conservation rules equal F01 except for this schema/ID, a new checkRunId and timestamps, and `nextAction=SameRunnerInstallA01AndEnterLOWrapperImmediately`.
- `A01-TMP=.../attempt-state.json.tmp`; `A01=.../attempt-state.json`, schema/ID `cerg-lo-cerg1-r2-attempt-state/1.0.0` / `LO-CERG1-R2-A01`. Its exact ordered fields are `{schemaVersion,artifactId,contractHeadCommit,candidateLockSha256,selectedCandidateId,confirmedF01Sha256,confirmedF01CheckRunId,confirmedMemberSetFingerprint,preflightSha256,confirmationId,adjacencyF02Sha256,adjacencyCheckRunId,adjacencyMemberSetFingerprint,adjacencyValidatorFinishedAtUtc,runnerImplementation,runnerInstanceId,processId,createdAtUtc,maxFirstSourceOpenDelayMilliseconds,LOUsedBeforeFirstSourceOpen,LOUsedAfterFirstSourceOpen,status,sameRunnerOnly,nextAction}`. Green installation fixes `maxFirstSourceOpenDelayMilliseconds=10000`, `LOUsedBeforeFirstSourceOpen=1`, `LOUsedAfterFirstSourceOpen=2`, `status=ArmedNoSourceOpen`, `sameRunnerOnly=true`, and `nextAction=SameRunnerEnterLOWrapperImmediately`.
- `H01-TMP=.../first-source-open.json.tmp`; `H01=.../first-source-open.json`, schema/ID `cerg-lo-cerg1-r2-first-source-open/1.0.0` / `LO-CERG1-R2-H01`. Its exact ordered fields are `{schemaVersion,artifactId,a01Sha256,runnerImplementationId,runnerInstanceId,processId,sourceMemberId,adjacencyValidatorFinishedAtUtc,firstSourceOpenedAtUtc,elapsedMilliseconds,LOUsedBeforeFirstSourceOpen,LOUsedAfterFirstSourceOpen,status,nextAction}`. It is created only after the operating system has successfully opened the first registered source-member leaf.

`runnerInstanceId="R2INST-"+sha256(CJ(["cerg-r2/runner-instance-id/1",runnerImplementationId,F02CheckRunId,instanceCreatedAtUtc,processId]))`. Every temporary artifact is written completely, reopened, canonically revalidated, and moved once by same-directory atomic no-overwrite rename. Final artifacts are never direct-written, overwritten, repaired, or reused.

`R2-TO03` is the post-tool-commit readiness artifact `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v3.json`, with temporary leaf plus `.tmp`, schema/ID `cerg-r2-aplus-readiness/1.0.0` / `R2-TO03`. It binds the committed identities of the producer, independent validator, P01 constructor/validator, staging wrapper, result graph producer, R2 pipeline, v1.4 pipeline, A+ runner, and A+ test. Its testRows are exactly 50 Passed rows: the existing ordered 19 R2 rows, the six ordered A+ rows `R2A-CE01-ConfirmationMismatch,R2A-CE02-SourceDrift,R2A-CE03-ExpiredBeforeOpen,R2A-CE04-ForeignProcess,R2A-CE05-A01WithoutFirstOpen,R2A-SP01-AtomicHandoff`, and the existing ordered 25 v1.4 rows. Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeR2P01`. R2-TO01 remains rejected history and R2-TO02 remains approved implementation history; neither is modified.

**Subject/Partition Registry and conservation.** F02 independently executes the same producer and independent-validator checks against every one of the 17 current leaves: existence, regular-file kind, full ancestor-chain and leaf non-reparse, size, and SHA-256. `F02.currentMemberSetFingerprint` must exactly equal the confirmed F01 fingerprint. No cached F01 observation, P01 tuple, or fixture assertion counts as an F02 check. A disagreement, omission, extra member, changed tuple, unknown selector, or non-Green direct check suppresses A01.

The first-open state partitions exactly as `NotOpened ⊎ OpenedWithinDeadline ⊎ OpenedAfterDeadline`. `NotOpened` has no H01 and leaves `LOUsed=1`; A01 installation alone never consumes an LO. `OpenedWithinDeadline` requires the same runner object identity, process ID, runner instance ID, A01 raw SHA, and `0 <= H01.elapsedMilliseconds <= 10000`; it creates H01 with `status=FirstSourceOpenObserved`, `nextAction=ContinueOnlySameForegroundLOInvocation`, and changes `LOUsed` from 1 to 2. `OpenedAfterDeadline` has physically consumed the LO at source open, creates H01 with `status=FirstSourceOpenAfterDeadline`, `nextAction=FailClosedNoReuse`, records `LOUsed=2`, and immediately fails closed before destination creation or copying. The three partitions are mutually exclusive and exhaustive.

The deadline is exactly `F02.validatorFinishedAtUtc -> operating-system successful File.Open of the first registered source-member leaf`; A01 installation time is not the endpoint. After A01 atomic installation the same foreground runner must, with no sleep, yield, prompt, background dispatch, process boundary, tool substitution, or unrelated operation, directly invoke `Invoke-CergLo1ExactStaging.ps1`. The runner passes an in-memory single-use unforgeable token; staging verifies token object identity, process ID, runner identity, A01 raw SHA, and deadline immediately before use. H01 is written from the first-open callback before the destination file is created. A01 without a matching H01 is permanently non-consumable and can never authorize a later invocation.

**Failure Transition Table.** These transitions are exhaustive:

| State | Trigger | Required artifacts/counters | Only next action |
|---|---|---|---|
| `APlusImplementationReady` | R2-TO03 binds committed tools and 50/50 tests | No real P01/F02/A01/H01; `LOUsed=1/3` | `AwaitTotalControlAuditBeforeR2P01` |
| `P01NotAuditedOrConfirmationMismatch` | P01 missing/unapproved, any binding mismatch, or confirmation identity mismatch | F02/A01/H01/Input absent; `LOUsed=1/3` | `ReturnToTotalControl_NoLO` |
| `F02FailedClosed` | Any of 17 current-leaf checks, conservation, independent agreement, or F01 fingerprint equality fails | Diagnostic F02 temp/final may remain; A01/H01/Input absent; `LOUsed=1/3` | `ReturnToTotalControl_NoLO` |
| `A01Unavailable` | F02 publication or A01 construction/install/reopen fails | Preserve exact temp/final state; H01/Input absent; `LOUsed=1/3` | `ReturnToTotalControl_NoLO` |
| `A01InstalledNoOpen` | runner interruption, foreign process/tool, token failure, or no successful source open | F02+A01 retained, H01 absent, no copied leaf; `LOUsed=1/3`; A01 permanently unusable | `ReturnToTotalControl_NoReuse` |
| `FirstOpenAfterDeadline` | first registered leaf opens after 10000 ms | F02+A01+Failed H01 retained, destination not created; `LOUsed=2/3` | `ReturnToTotalControl_NoRetry` |
| `FirstOpenWithinDeadline` | same runner/process opens first registered leaf within 10000 ms | F02+A01+Green H01; `LOUsed=2/3`; staging continues in the same invocation | `ContinueOnlySameForegroundLOInvocation` |
| `PostOpenFailure` | H01 publication, copy/hash, later staging, or downstream LO fails after first open | Preserve H01 temp/final and all partial state; `LOUsed=2/3` | `ReturnToTotalControl_NoRetry` |

Fixed counterexamples must prove exact confirmation rejection, source drift before F02, late first open with consumed-failure H01, foreign-process token rejection, A01-without-open non-consumption, and successful same-runner F02→A01→first open→staging. Tests must call the production constructors and consumer chain and may not add hidden schema fields. Current implementation success creates only committed tools and R2-TO03; it does not authorize or create P01. The sole next action after this Task is `AwaitTotalControlAuditBeforeR2P01`.

#### 2026-07-22 R2 P01 three-domain HEAD correction

This correction supersedes only the A+ statements that treat Candidate, F01, P01 execution, F02, A01, or readiness `contractHeadCommit` values as one equality domain. It authorizes only synchronized routes, the P01 constructor/validator, A+ runner, ResultGraph consumer, necessary synthetic tests, and an immutable R2-TO04 readiness artifact. It authorizes no real P01/F02/A01/H01, source read, staging, LO, AssetRipper, or Unity. Counters remain `ordinaryTaskUsed=5/7`, `LOUsed=1/3`.

**Artifact Registry.** R2-TO03 remains immutable rejected history at `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v3.json`: `8023` bytes, raw SHA-256 `bb41bfe9f2bd1cbc937474bf2e8a8a6a95cd8501ca44d7e16c31b06baa859837`, bound commit `4bed8c6b86f3bdc3887bea081bca9293954ea882`, `auditDisposition=RejectedByTotalControlAudit`, `consumableForR2P01=false`, and `auditReasonCodes=[ThreeHeadDomainsConflated]`. Its bytes are never deleted, overwritten, refreshed, or reclassified as producer failure.

Future P01 remains schema/ID `cerg-lo-cerg1-preflight/1.5.0` / `LO-CERG1-P01`, but its exact top-level field order is now `{schemaVersion,artifactId,candidateLockSha256,freshnessEvidenceSha256,freshnessCheckRunId,freshnessValidatorFinishedAtUtc,candidateContractHeadCommit,freshnessContractHeadCommit,contractHeadCommit,selectedCandidateId,createdAt,sourceRootBindings,implementationBindings,operation,aggregateLimits,stagingPlan,status,nextAction}`. `candidateContractHeadCommit` must equal the exact Candidate artifact's `contractHeadCommit`; `freshnessContractHeadCommit` must equal immutable F01's `contractHeadCommit`; and P01 `contractHeadCommit` is exclusively the current A+ execution contract HEAD and must equal approved R2-TO04 `contractHeadCommit`. `candidateLockSha256`, `freshnessEvidenceSha256`, `freshnessCheckRunId`, `freshnessValidatorFinishedAtUtc`, the 17 CurrentMember tuples/fingerprint, private path derivation, staging bijection, and limits retain their existing exact rules. Missing, null, copied-across-domain, stale, or additional HEAD fields suppress P01.

F02 and A01 `contractHeadCommit` must equal P01 execution `contractHeadCommit`; neither may copy Candidate or F01 HEAD. ResultGraph receives and reopens exact Candidate, F01, P01, R2-TO04, F02, A01, H01, and SI01 inputs. It validates these equalities independently: `Candidate.contractHeadCommit == P01.candidateContractHeadCommit`; `F01.contractHeadCommit == P01.freshnessContractHeadCommit`; and `P01.contractHeadCommit == R2-TO04.contractHeadCommit == F02.contractHeadCommit == A01.contractHeadCommit`. No cross-domain equality assertion is permitted. All raw SHA, checkRunId, member fingerprint, confirmation, runner, first-open, and staging bindings remain mandatory.

`R2-TOT04` is the initially absent temporary leaf `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v4.json.tmp`; `R2-TO04` is the initially absent immutable final leaf `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v4.json`, schema/ID `cerg-r2-aplus-readiness/1.1.0` / `R2-TO04`. Its exact top-level shape remains `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}`. It binds post-correction committed identities for the same nine A+ tools, sorted by artifactId. Its testRows are exactly 51 Passed rows in order: the prior 19 R2 rows; `R2A-CE01` through `R2A-CE05`; `R2A-CE06-HeadDomainSplice`; `R2A-SP01-AtomicHandoff`; then the prior 25 v1.4 rows. Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeR2P01AfterHeadDomainCorrection`. Publication is post-commit, canonical reopen, same-directory atomic no-overwrite rename; any failure suppresses R2-TO04.

**Subject/Partition Registry and conservation.** The logical HEAD universe partitions exactly as `CandidateHeadDomain ⊎ FreshnessHeadDomain ⊎ ExecutionHeadDomain`. These are semantic domains, not an assertion that their 40-hex values must differ. Candidate contributes exactly one candidate HEAD; F01 contributes exactly one freshness HEAD; approved R2-TO04 contributes exactly one execution HEAD. P01 projects all three once into their named fields. F02 and A01 each project only the execution HEAD. ResultGraph consumes all three domains without merging or dropping one. Thus `P01HeadFieldCount=3`, `CandidateDomainProjectionCount=1`, `FreshnessDomainProjectionCount=1`, and `ExecutionDomainProjectionCount=1`; duplicate, missing, renamed, or cross-domain substitution is `HeadDomainSplice`.

**Failure Transition Table.** `HEAD-FT00` is this implementation Task: only authorized tools/routes and post-commit R2-TO04 may change; all real R2 execution artifacts stay absent and counters stay `5/7,1/3`. `HEAD-FT01` is any constructor/schema/domain/test failure before commit: suppress tool commit and R2-TO04 and return to total control. `HEAD-FT02` is a valid tool commit plus canonical Green R2-TO04: R2-TO03 remains rejected/immutable, real P01 and all downstream artifacts remain absent, and only `AwaitTotalControlAuditBeforeR2P01AfterHeadDomainCorrection` is allowed. `HEAD-FT03` is committed tools with unavailable/malformed R2-TO04: preserve the commit and exact temporary/final state, deny P01, and return to total control without automatic retry. Any later domain mismatch suppresses the next artifact: constructor mismatch suppresses P01; readiness/confirmation mismatch suppresses F02; F02/A01 mismatch suppresses H01/staging; ResultGraph mismatch suppresses R01 and T2 authority.

The fixed synthetic success uses three distinct 40-hex values and must complete the entire production-consumer chain `P01→F02→A01→H01→staging→ResultGraph`. `R2A-CE06-HeadDomainSplice` independently mutates Candidate HEAD, F01 HEAD, all three P01 HEAD fields, F02 HEAD, and readiness HEAD; every mutation must fail closed. A test that merely observes a field, accepts a shared placeholder HEAD, or omits ResultGraph consumption cannot be Passed. The sole next action after this Task is `AwaitTotalControlAuditBeforeR2P01AfterHeadDomainCorrection`.

#### 2026-07-22 R2 P02 Ordinal preflight replacement correction

This newest subsection supersedes every earlier R2 statement that permits P01/v1.5, R2-TO04, the P01 confirmation domain, culture-sensitive staging-row order, or implicit constructor sorting to authorize F02 or any later artifact. This Task changes only the synchronized routes and the nine registered R2 tools/tests, then publishes one post-commit readiness artifact. It does not read a real source leaf and does not create real P02, F02, A01, H01, Input, staging inventory, Work, Output, R01, AssetRipper, or Unity state. Counters remain `ordinaryTaskUsed=5/7`, `LOUsed=1/3`.

**Artifact Registry.** The real rejected P01 is permanently retained at `Extracted/CERG/SingleCharacter/LO-CERG1-R2/preflight.json`: exactly `16907` bytes, raw SHA-256 `75b595c614ca864777f075f138a6c33bb686b47a08d1894edb5a1c9326671963`, schema/ID `cerg-lo-cerg1-preflight/1.5.0` / `LO-CERG1-P01`, `auditDisposition=RejectedByIndependentAudit`, `reasonCode=CultureSensitiveStagingRowOrdering`, `consumable=false`, stored fingerprint `6dc3f28c1590579b6b6b6275e0136a54fe617ada4ec8e0c0b4a50e392d1aff60`, and required Ordinal fingerprint `d6ec7bcde7e3fa1ccb228eb6e5ef024ee79d203ec1863fa9c83c80e2ea34e5eb`. It is historical evidence only and is never edited, deleted, overwritten, renamed, repaired, or consumed.

R2-TO04 remains byte-immutable rejected readiness at `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v4.json`: exactly `8180` bytes, raw SHA-256 `ed3c55b72cf72e353f56d2b1a73fae116df10c3248728e761877d922c2deeb76`, schema/ID `cerg-r2-aplus-readiness/1.1.0` / `R2-TO04`, `auditDisposition=RejectedByIndependentAudit`, `reasonCode=OrdinalOrderingCounterexampleAbsent`, and `consumableForR2P02=false`. Its bytes are never rewritten or reclassified as a tool failure.

The replacement temporary/final leaves are `Extracted/CERG/SingleCharacter/LO-CERG1-R2/preflight-ordinal.json.tmp` and `Extracted/CERG/SingleCharacter/LO-CERG1-R2/preflight-ordinal.json`. The final artifact is schema/ID `cerg-lo-cerg1-preflight/1.6.0` / `LO-CERG1-P02`; both leaves are initially absent, same-directory temporary publication is canonical UTF-8 without BOM, reopen-validated, atomically moved once with no overwrite, and final bytes are immutable. P02 has the exact ordered top-level shape `{schemaVersion,artifactId,candidateLockSha256,freshnessEvidenceSha256,freshnessCheckRunId,freshnessValidatorFinishedAtUtc,candidateContractHeadCommit,freshnessContractHeadCommit,contractHeadCommit,selectedCandidateId,createdAt,sourceRootBindings,implementationBindings,operation,aggregateLimits,stagingPlan,status,nextAction}`. Its nested root, implementation, operation, aggregate-limit, staging-plan, and member-row shapes and all private-path derivations are exactly the v1.5 shapes already frozen above; fixed values change only to the P02 schema/ID and `nextAction=RequestExactHumanConfirmationForR2P02`. The in-memory definition is schema/ID `cerg-lo-cerg1-preflight-definition/1.2.0` / `LO-CERG1-P02-DEFINITION`; it has the same exact field order as the prior three-domain definition and is never itself published.

P02 preserves without reinterpretation the immutable Candidate raw SHA and candidate HEAD, F01 raw SHA/checkRunId/validator timestamp/current-member fingerprint and freshness HEAD, approved readiness execution HEAD, exactly 17 CurrentMember tuples, six constructor-derived private attempt paths, one-to-one staging destinations, four implementation bindings, eleven obligations, and the fixed positive limits. `candidateContractHeadCommit=Candidate.contractHeadCommit`, `freshnessContractHeadCommit=F01.contractHeadCommit`, and `contractHeadCommit=R2-TO05.contractHeadCommit`; no cross-domain equality is implied.

`R2-TOT05=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v5.json.tmp` and `R2-TO05=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v5.json`. R2-TO05 schema/ID is `cerg-r2-aplus-readiness/1.2.0` / `R2-TO05`; its exact shape is `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}`. `toolRows` contains exactly the same nine tool paths as R2-TO04, one row each, sorted by `artifactId` with `StringComparer.Ordinal`, and binds the post-correction commit, byte count, and raw SHA-256. `testRows` is exactly 52 Passed rows in fixed order: the 19 R2 rows; `R2A-CE01-ConfirmationMismatch`, `R2A-CE02-SourceDrift`, `R2A-CE03-ExpiredBeforeOpen`, `R2A-CE04-ForeignProcess`, `R2A-CE05-A01WithoutFirstOpen`, `R2A-CE06-HeadDomainSplice`, `R2A-CE07-OrdinalOrdering`, `R2A-SP01-AtomicHandoff`; then the 25 v1.4 rows. Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeR2P02Generation`. Publication occurs only after the tool/route commit, uses canonical reopen and atomic no-overwrite installation, and never creates P02.

**Identity encoding and Ordinal rules.** Every set/list order that is contract-critical uses an explicit `[System.StringComparer]::Ordinal` or an object comparer whose sole key comparison is `[string]::CompareOrdinal`; `Sort-Object`, current culture, invariant culture, `-CaseSensitive`, filesystem enumeration order, or a caller-provided order is not equivalent. P02 `stagingPlan.memberRows` is strictly ordered by `stagingPortableRelativePath`. The constructor independently copies the received array, sorts that copy with `StringComparer.Ordinal`, compares every actual position to the copy, and rejects any mismatch before creating P02; it never sorts or repairs caller input. The consumer repeats the same comparison after reopening P02 and before any F02/A01/output action. Only after that order check does each side recompute `memberSetFingerprint=sha256(CJ(["cerg-lo1/staging-member-set/1",memberRows]))`. A culture-ordered array with a self-consistent fingerprint is invalid.

The replacement confirmation remains prefixed `R2CONF-` but its digest is exactly `sha256(CJ(["cerg-r2/p02-confirmation-id/1",contractHeadCommit,F01Sha256,F01CheckRunId,MemberSetFingerprint,P02Sha256,RunnerImplementationId]))`. The A+ runner, exact staging wrapper with an A+ token, R2 ResultGraph path, A01 `preflightSha256`, and confirmation recomputation accept only P02/v1.6 and R2-TO05. P01/v1.5, R2-TO04, `cerg-r2/p01-confirmation-id/1`, a P01 SHA substituted for P02 SHA, or a legacy non-R2 attempt object must suppress F02 and all later outputs. Historical v1.4 P01 remains accepted only by its non-R2 regression path and can never carry an A+ token.

**Subject/Partition Registry and conservation.** `R2PreflightHistory = RejectedP01` and `R2PreflightFuture = AbsentP02 ⊎ ValidP02 ⊎ RejectedP02`; only `ValidP02` is consumable, and no artifact may belong to two partitions. For valid P02, `|F01.currentMembers|=|P02.stagingPlan.memberRows|=|P02.operation.inputMemberRefIds|=17`; their member-ID sets are equal, duplicate-free, and every member tuple maps to exactly one distinct Ordinal-positioned staging destination. `P02.memberCount=17`, `P02.byteCount=sum(F01.currentMembers.byteCount)`, `sourceReadMaxFiles=17`, and `sourceReadMaxBytes=P02.byteCount`. The six private paths partition as one attempt root plus exactly five distinct constructor-derived descendants: Input, temporary inventory, final inventory, Work, and Output. HEAD conservation remains exactly one Candidate domain, one F01 domain, and one R2-TO05 execution domain.

**Failure Transition Table.** `ORD-FT00` is this implementation Task: rejected P01 and R2-TO04 remain immutable; only the nine tools, synchronized routes, and post-commit R2-TO05 may change; all real P02/downstream paths remain absent and counters stay `5/7,1/3`. `ORD-FT01` is any implementation, schema, Ordinal, fixed-counterexample, regression, mirror, or pre-commit failure: roll back only this Task's tracked changes, suppress its commit and R2-TO05, preserve P01/R2-TO04, and return to total control. `ORD-FT02` is a committed correction plus canonical Green R2-TO05: preserve rejected history, keep P02 and downstream absent, and allow only `AwaitTotalControlAuditBeforeR2P02Generation`. `ORD-FT03` is a valid commit with missing/malformed/unavailable R2-TO05: preserve the commit and exact temporary/final readiness state, deny P02, and return to total control without automatic retry. `ORD-FT04` is any later non-Ordinal/self-consistent-order, schema, identity, HEAD, F01, bijection, limit, tool, path, or no-overwrite mismatch: suppress P02 and every downstream artifact. `ORD-FT05` is any use of rejected P01/R2-TO04/old confirmation: suppress F02/A01/H01/Input/R01 and return to total control without consuming another LO. No transition edits or replaces rejected P01.

`R2A-CE07-OrdinalOrdering` must construct a culture-sorted member-row array, recompute a matching fingerprint, and prove both constructor and reopened consumer reject it. Its positive arm runs the same source rows under at least two different `CurrentCulture` values and proves byte-identical Ordinal order and fingerprint. `R2A-SP01-AtomicHandoff` must complete the production-consumer synthetic chain `P02→F02→A01→H01→staging→ResultGraph`; old P01 and old confirmation vectors must produce zero downstream artifacts. The sole next action after this Task is `AwaitTotalControlAuditBeforeR2P02Generation`.

#### 2026-07-22 R2 P02 implementation-binding conservation correction

This newest subsection supersedes the preceding P02 subsection only where it permits R2-TO05, fewer than four execution bindings, an operation/reference mismatch, or readiness-free execution identity validation. The prior Ordinal, three-HEAD-domain, freshness, path, limit, no-overwrite, and P02/v1.6 rules remain unchanged. This is the same corrective Task and consumes no additional ordinary Task or LO: `ordinaryTaskUsed=5/7`, `LOUsed=1/3`. It reads no real source leaf and creates no real P02, F02, A01, H01, Input, staging inventory, Work, Output, R01, AssetRipper, or Unity state.

**Artifact Registry.** R2-TO05 is immutable rejected history at `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v5.json`: exactly `8257` bytes, raw SHA-256 `d48d7f6051a39fac6e48f46503946a424750b8d92c1a1094756d5c9275e5011a`, schema/ID `cerg-r2-aplus-readiness/1.2.0` / `R2-TO05`, bound commit `9784f1e359212cd29bb937ebcf5277f10b68d8c6`, `auditDisposition=RejectedByIndependentAudit`, `reasonCode=ImplementationBindingCoverageAbsent`, and `consumableForR2P02=false`. It is never edited, deleted, overwritten, refreshed, or accepted because its embedded tests were Green.

`R2-TOT06=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v6.json.tmp` and `R2-TO06=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v6.json`. R2-TO06 is initially absent, immutable after one canonical reopen-validated atomic no-overwrite installation, and has schema/ID `cerg-r2-aplus-readiness/1.3.0` / `R2-TO06`. Its exact shape remains `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}`. `toolRows` contains the previous nine paths in their existing artifact-ID order and appends `R2-A-T10/Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1`; all ten rows bind the post-correction commit's actual byte count and raw SHA-256. `testRows` contains exactly 53 Passed rows: the fixed 19 R2 rows; the nine A+ rows in order `R2A-CE01` through `R2A-CE07`, `R2A-CE08-ImplementationBindings`, `R2A-SP01-AtomicHandoff`; then the fixed 25 v1.4 rows. Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeR2P02Generation`.

**Implementation Registry and conservation.** A valid P02 definition and reopened P02 contain exactly four `implementationBindings`, no more and no fewer. Each row has the exact ordered shape `{artifactId,implementationId,implementationRole,implementationVersion,pathKind,portableTrackedPath,privateAbsoluteLeafPath,implementationByteCount,implementationSha256,runtimePrivateAbsoluteLeafPath,runtimeByteCount,runtimeSha256,orderedArgumentTokens}` and `orderedArgumentTokens=[]`. The four artifact identities are exactly:

- `LO1-IA01`: role/version `AssetRipperExecutable/1.3.14.0`, `pathKind=Private`, `portableTrackedPath=null`, one selector-free private absolute implementation leaf, and that same leaf as its runtime.
- `LO1-IF01`: role/version `AssetRipperFolderInvoker/CERG-LO1-ASSETRIPPER-FOLDER-INVOKER/1`, `pathKind=Tracked`, exact path `Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1`, `privateAbsoluteLeafPath=null`, and one selector-free private absolute PowerShell runtime leaf.
- `T1V22-TG01`: role/version `ExactLeafStagingWrapper/CERG-LO1-EXACT-STAGING/3`, `pathKind=Tracked`, exact path `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1`, `privateAbsoluteLeafPath=null`, and one selector-free private absolute PowerShell runtime leaf.
- `T1V22-TG02`: role/version `R01GraphProducer/CERG-LO1-R01-PRODUCER/5`, `pathKind=Tracked`, exact path `Tools/AssetImport/New-CergLo1ResultGraph.ps1`, `privateAbsoluteLeafPath=null`, and one selector-free private absolute PowerShell runtime leaf.

For every row, constructor and reopened consumer independently open the declared implementation and runtime leaves, recompute byte count and lowercase raw SHA-256, and require `implementationId="IMP-"+sha256(CJ(["cerg-lo1/implementation-id/1",implementationRole,implementationVersion,implementationByteCount,implementationSha256,runtimeByteCount,runtimeSha256,orderedArgumentTokens]))`. The three tracked implementations must each resolve to exactly one R2-TO06 `toolRows` path with identical bytes and SHA; the private AssetRipper row must be self-runtime-identical. The duplicate-free `implementationBindings[*].implementationId` set and `operation.implementationRefIds` set must be exactly equal in both directions, with both arrays already `StringComparer.Ordinal` sorted. Empty, missing, extra, duplicate, unknown-role, wrong-version, wrong-path-kind, path-spliced, byte/hash-tampered, runtime-spliced, readiness-stale, or reference-mismatched rows fail closed before P02 creation.

The A+ handoff reopens Candidate, F01, P02, and R2-TO06, first validates the complete readiness matrix and all ten tracked tool identities, then invokes the same independent P02 consumer with R2-TO06 supplied. It must therefore re-open and re-hash all four implementation/runtime bindings and repeat readiness/bijection validation before confirmation recomputation or F02 creation. ResultGraph repeats the P02 consumer check with R2-TO06 before accepting the chain. No stored P02 binding, stored readiness row, constructor success, or self-consistent implementation ID can substitute for a current real-leaf check.

**Subject/Partition Registry and Failure Transition Table.** `P02ImplementationUniverse = RequiredFourBindings = PrivateExecutable(LO1-IA01) ⊎ TrackedFolderInvoker(LO1-IF01) ⊎ TrackedStagingWrapper(T1V22-TG01) ⊎ TrackedGraphProducer(T1V22-TG02)` and `RequiredFourBindingIds = operation.implementationRefIds`; all partitions are disjoint singletons. `BIND-FT00` is this correction: preserve R2-TO05 bytes, modify only synchronized routes and the authorized implementation/tests, and keep real P02/downstream absent. `BIND-FT01` is any pre-commit implementation, matrix, mirror, or regression failure: suppress commit and R2-TO06 and return to total control. `BIND-FT02` is a valid correction commit plus canonical Green R2-TO06: keep P02/downstream absent and allow only `AwaitTotalControlAuditBeforeR2P02Generation`. `BIND-FT03` is a valid commit with unavailable, malformed, or non-atomically installed R2-TO06: preserve the commit and exact readiness state, deny P02, and return to total control without automatic retry. `BIND-FT04` is any later binding/readiness/ref/actual-leaf mismatch: suppress P02 at construction, or suppress F02/A01/ResultGraph at consumption, without consuming another LO.

`R2A-CE08-ImplementationBindings` must prove failure for empty bindings, one missing binding, duplicate binding, implementation hash tampering, operation-reference omission/mismatch, readiness-row identity tampering, and a reopened P02 binding splice before any handoff output. Its positive arm and `R2A-SP01` must use the production four-row shape and complete `P02→F02→A01→H01→staging→ResultGraph` synthetic chain. Fixture-only hidden bindings or empty arrays are forbidden. The sole next action after this Task is `AwaitTotalControlAuditBeforeR2P02Generation`.

#### 2026-07-22 R2 P02 runtime and AssetRipper identity correction

This newest subsection supersedes the preceding binding subsection only where it permits R2-TO06, accepts a caller-selected runtime leaf, treats arbitrary bytes named `.exe` as AssetRipper, uses folder-invoker v1, or permits the later invoker to select an executable independently of P02. All four-binding, Ordinal, HEAD-domain, freshness, path, limit, confirmation, and no-overwrite requirements remain. This is the same corrective Task; counters remain `ordinaryTaskUsed=5/7`, `LOUsed=1/3`. It does not read a real source leaf and creates no real P02, F02, A01, H01, Input, staging inventory, Work, Output, R01, AssetRipper process, or Unity state.

**Artifact Registry.** R2-TO06 is immutable rejected history at `Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v6.json`: exactly `8627` bytes, raw SHA-256 `d68a155f5c6ef4a883f8cc5881c2923cf097946a8b0862616d61880507ab153e`, schema/ID `cerg-r2-aplus-readiness/1.3.0` / `R2-TO06`, bound commit `25737613e3e31381f4af2fd83f13fc88f19a3cfb`, `auditDisposition=RejectedByIndependentAudit`, `reasonCode=RuntimeIdentityNotAuthoritative`, and `consumableForR2P02=false`. Its bytes and the earlier R2-TO05 bytes remain unchanged.

`R2-TOT07=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v7.json.tmp` and `R2-TO07=Extracted/CERG/SingleCharacter/Recovery-R2/tooling-readiness-v7.json`. R2-TO07 is initially absent, immutable after one canonical reopen-validated atomic no-overwrite installation, and has schema/ID `cerg-r2-aplus-readiness/1.4.0` / `R2-TO07`. Its exact shape remains `{schemaVersion,artifactId,contractHeadCommit,toolRows,testRows,status,failures,nextAction}`. The same ten tool paths bind the post-correction commit; `LO1-IF01` is now `AssetRipperFolderInvoker/CERG-LO1-ASSETRIPPER-FOLDER-INVOKER/2`. `testRows` contains exactly 55 Passed rows: the fixed 19 R2 rows; the fixed A+ rows through `R2A-CE08-ImplementationBindings`, then `R2A-CE09-RuntimeSelfConsistentSplice`, `R2A-CE10-FakeAssetRipperExecutable`, and `R2A-SP01-AtomicHandoff`; then the fixed 25 v1.4 rows. Green fixes `failures=[]` and `nextAction=AwaitTotalControlAuditBeforeR2P02Generation`.

**Runtime and executable identity gates.** For each tracked implementation `LO1-IF01`, `T1V22-TG01`, and `T1V22-TG02`, `runtimePrivateAbsoluteLeafPath` must equal the canonical absolute executable path returned for the currently executing PowerShell process by `Process.GetCurrentProcess().MainModule.FileName`, compared with Windows `OrdinalIgnoreCase`. Constructor, reopened P02 consumer, A+ handoff, staging consumer, and ResultGraph independently re-open that exact runtime leaf and recompute its byte count and SHA before accepting the stored structured implementation ID. A copy, hard-coded alternate runtime, script leaf, same-byte leaf at another path, or any self-consistent replacement is invalid even when every stored size, SHA, ID, and operation ref is recomputed.

`LO1-IA01` remains self-runtime-identical, but a matching filename/hash tuple is insufficient. The exact opened leaf must be a regular Windows PE with DOS `MZ`, a valid in-range PE header and `PE\0\0` signature; case-sensitive leaf name `AssetRipper.GUI.Free.exe`; case-sensitive product name `AssetRipper.GUI.Free`; and file version `1.3.14.0`. Its current byte count, SHA, and structured implementation ID are still independently recomputed. Missing version resources, malformed PE, a text file, renamed unrelated executable, wrong product/version, or self-consistent replacement fails closed before P02 creation.

Folder invoker v2 makes `PreflightPath` mandatory, requires one Green P02/v1.6 under the controlled Extracted root, invokes the complete four-binding validator on that reopened P02, selects exactly its sole IA01 `privateAbsoluteLeafPath`, and requires the existing private tool-manifest path to canonicalize to the same leaf. `Start-AssetRipperServer` receives only that P02-derived path. A manifest-only path, caller-selected executable, P01, missing IA01, or manifest/P02 mismatch cannot launch AssetRipper. No private absolute path or private executable identity is projected into tracked docs/readiness.

**Failure transitions and fixed counterexamples.** `RUNTIME-FT00` preserves R2-TO06 and modifies only the synchronized routes plus authorized tools/tests; P02/downstream remain absent. `RUNTIME-FT01` suppresses commit and R2-TO07 on any pre-commit test, identity, mirror, or regression failure. `RUNTIME-FT02` is a valid correction commit plus canonical Green R2-TO07 and permits only `AwaitTotalControlAuditBeforeR2P02Generation`. `RUNTIME-FT03` preserves a valid commit but denies P02 if R2-TO07 is absent, malformed, or non-atomically installed. `RUNTIME-FT04` suppresses P02 or the next downstream artifact on any later runtime/PE/product/version/manifest/P02-path mismatch without consuming another LO.

`R2A-CE09-RuntimeSelfConsistentSplice` substitutes another existing leaf for one tracked runtime, recomputes runtime bytes, SHA, implementation ID, binding order, and the complete operation-ref set, and must still fail. `R2A-CE10-FakeAssetRipperExecutable` writes ordinary text bytes to a leaf named `AssetRipper.GUI.Free.exe`, recomputes both implementation/runtime identities, implementation ID, binding order, and refs, and must still fail. Positive fixtures use the locally installed real AssetRipper identity without launching it. The sole next action after this Task is `AwaitTotalControlAuditBeforeR2P02Generation`.

#### V2.2 Artifact Registry

| ID | Exact path or byte range | Complete role and schema | Success/failure vector |
|---|---|---|---|
| `T1V22-I01` | Normative roadmap bytes from this override heading through the byte immediately before the historical FFS heading | Raw UTF-8 contract input | Required; raw-byte SHA-256 |
| `T1V22-I02` | Mirror roadmap over the identical heading-bounded range | Raw UTF-8 mirror input | Required and byte-identical to I01 |
| `T1V22-I03` | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` | Read-only complete file: `11792761` bytes, raw SHA-256 `4f28737b77aaf94dcd79272d37f9041144e913e9222f90f311236cb8f6a14fe8`, singleton member-set fingerprint `8e9defe851714dc9443756c7d95d7ee259eeacc1b820e6306ba1f11a0b77d586`; public projection is only `sources[*].{sourceId,sourceKind,rootFingerprint}` and `files[*].{sourceId,relativePath,sizeBytes,sha256,containerKind}` | Missing, stale, malformed, or nonconserving projection suppresses O01 |
| `T1V22-I04` | `Extracted/FastFeasibilitySpike/LO-FFS1` | Read-only recursive identity set: `2037` files, `646020410` bytes, v2.2 input-member-set fingerprint `df205c3b2eaffe6cf02894277c661b4b43d2ac61122d7dc4a3ecd4c0ac40d48b`; includes the eight fixed safe baseline evidence members below | Mutation or missing baseline member suppresses O01 |
| `T1V22-H01` | `Extracted/CERG/SingleCharacter/T1/candidate-lock.json` | Historical v1 artifact; exactly `7767` bytes, SHA-256 `5d71f0f8c3dbde8038076b49a944b5c58f4883ef4b65865129be50f69406bdff` | Immutable, non-consumable, never overwritten |
| `T1V22-TG01` | `Tools/AssetImport/Invoke-CergLo1ExactStaging.ps1` | Future T1A-created tracked `ExactLeafStagingWrapper`; complete implementation bytes | Green only: newly implemented, fixture-tested, committed, and identity-bound by TO01; Failed: rolled back and absent from the T1A ending HEAD |
| `T1V22-TG02` | `Tools/AssetImport/New-CergLo1ResultGraph.ps1` | Future T1A-created tracked `R01GraphProducer/CERG-LO1-R01-PRODUCER/1`; complete R01 implementation bytes | Green only: newly implemented, fixture-tested, committed, and identity-bound by TO01; Failed: rolled back and absent from the T1A ending HEAD |
| `T1V22-TG03` | `Tools/AssetImport/Test-CergLo1Pipeline.ps1` | Future T1A-created tracked fixture-only contract test for TG01/TG02 | Green only: committed with TG01/TG02 after all ten Passed; Failed: rolled back, while TO01 still carries all ten diagnostic test rows |
| `T1V22-TOT01` | `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness.json.tmp` | Temporary canonical TO01 bytes, either Green or Failed | Initially absent; validated before atomic install; absent after success; never consumable and retained only as exact observed bytes after a failed or interrupted publication |
| `T1V22-TO01` | `Extracted/CERG/SingleCharacter/T1-v2/tooling-readiness.json` | `cerg-t1v22-tooling-readiness/1.0.0`; mutually exclusive Green/Failed T1A readiness record | Initially absent and never overwritten. Green binds three committed tool rows and post-tool-commit HEAD; Failed binds `toolRows=[]`, all ten diagnostic rows, and the T1A starting contract HEAD; Failed or unavailable TO01 can never authorize T1B |
| `T1V22-T01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json.tmp` | Future T1B-only temporary canonical O01 bytes | Initially absent; atomically installed or same-Task rolled back |
| `T1V22-O01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json` | Future T1B-only `cerg-t1-candidate-lock/2.2.0`; sole Passed lock | Never overwritten; every failure suppresses it |
| `LO1-IF01` | `Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1` | Sole `AssetRipperFolderInvoker`: `14528` bytes, raw SHA-256 `29362d475b989a2855e44f60d60686ef4152066e0579ff026dbc9818112c2381` | Checked-out bytes/runtime/arguments must match P01 |
| `LO1-IA01` | Machine-private exact AssetRipper executable leaf frozen in P01 | Sole `AssetRipperExecutable` bytes/version/arguments | Missing, directory-valued, stale, or package-download-dependent identity makes preflight fail |
| `LO1-PT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json.tmp` | Temporary canonical P01 bytes | Same-preflight atomic install or rollback |
| `LO1-P01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json` | `cerg-lo-cerg1-preflight/1.3.0`; Green-only machine-private preflight binding the actual staging wrapper, folder invoker, AssetRipper, runtime, and sole R01 producer bytes | Only Green can be confirmed; never committed or quoted with private paths |
| `LO1-F01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight-failure.json` | `cerg-lo-cerg1-preflight-failure/1.2.0`; bounded preflight failure | Present only when the single preflight window is exhausted; P01/A01/staging/Output/R01 absent |
| `LO1-AT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/attempt-state.json.tmp` | Temporary A01 bytes | Installed before the first source-member open |
| `LO1-A01` | `Extracted/CERG/SingleCharacter/LO-CERG1/attempt-state.json` | `cerg-lo-cerg1-attempt-state/1.1.0`; immutable one-attempt sentinel | Present for every begun LO; without a valid R01 it deterministically proves `InterruptedNoResult` |
| `LO1-SD01` | `Extracted/CERG/SingleCharacter/LO-CERG1/Input` | Fresh attempt-owned staging tree; each leaf is copied only from one registered SourceMember | May be partial after interruption; never a real-source resolver base |
| `LO1-SIT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json.tmp` | Temporary canonical SI01 bytes written only after all staged leaves exist | Atomically installed or retained/rolled back under the exact interruption vector |
| `LO1-SI01` | `Extracted/CERG/SingleCharacter/LO-CERG1/staging-inventory.json` | `cerg-lo-cerg1-staging-inventory/1.0.0`; immutable complete bidirectional staging inventory | Required before AssetRipper starts and referenced byte-for-byte by R01 |
| `LO1-WD01` | `Extracted/CERG/SingleCharacter/LO-CERG1/Work` | Attempt-owned private work/log tree for the fixed wrapper and tools | May be partial; never a downstream input and never committed |
| `LO1-D01` | `Extracted/CERG/SingleCharacter/LO-CERG1/Output` | Candidate-scoped output tree | May be partial; never consumable without Closed R01 |
| `LO1-RT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/lo-result.json.tmp` | Temporary canonical R01 bytes | Same-attempt atomic install or rollback |
| `LO1-R01` | `Extracted/CERG/SingleCharacter/LO-CERG1/lo-result.json` | `cerg-lo-cerg1-result/1.2.0`; complete staging/output inventories plus lossless discovered Unity graph | Closed alone authorizes T2; Unresolved routes only to T4 |
| `T3-T01` | `Extracted/CERG/SingleCharacter/T3/repair-record.json.tmp` | Temporary canonical T3-O01 bytes | Same-Task atomic install or rollback |
| `T3-O01` | `Extracted/CERG/SingleCharacter/T3/repair-record.json` | `cerg-single-cause-repair/1.0.0`; one approved cause and exact before/after member identities | Present only after one bounded repair is statically Green |
| `T3-F01` | `Extracted/CERG/SingleCharacter/T3/repair-failure.json` | `cerg-single-cause-repair-failure/1.0.0`; exact inability to complete the approved single repair | Present only when T3 consumes its Task without Green O01; routes only to T4 |
| `LO3-A01` | `Extracted/CERG/SingleCharacter/LO-CERG3/attempt-state.json` | `cerg-lo-cerg3-attempt-state/1.0.0`; immutable sole-revalidation sentinel | Installed before Unity revalidation starts |
| `LO3-D01` | `Extracted/CERG/SingleCharacter/LO-CERG3/Evidence` | Complete logs, structured results, stills, and continuous capture from the revalidation | Never consumable without valid LO3-R01 |
| `LO3-R01` | `Extracted/CERG/SingleCharacter/LO-CERG3/unity-result.json` | `cerg-lo-cerg3-unity-result/1.0.0`; complete A-F revalidation result bound to T3-O01 | AllGreen or Failed; always routes only to T4 |
| `T4-T01` | `Extracted/CERG/SingleCharacter/T4/terminal-result.json.tmp` | Temporary canonical O01 bytes | Same-Task atomic install or rollback |
| `T4-O01` | `Extracted/CERG/SingleCharacter/T4/terminal-result.json` | `cerg-terminal-result/1.1.0`; sole terminal record | Exactly one immutable binary result |

Apart from the registered TO03 correction artifacts above, there are no other v2.2, tooling, preflight, LO-CERG1, repair, revalidation, or early-terminal artifacts or implementation roles. TO01/TO02 are rejected immutable history. Only after total control approves the exact Green TO03 SHA and corrective tool HEAD may a separately authorized `CERG-T1B` read the allowlisted C1/FFS evidence and create T01/O01; it may not modify TG01-TG03 or TO01-TO03 or accept a machine-local substitute. Missing, failed, or unaudited TO03 suppresses T1B and O01. A01 is created before any source read or staging/Work/Output member; therefore `A01 absent` means the LO attempt never began, while `A01 present and valid R01 absent` has exactly one meaning and transition.

#### Canonical bytes, identities, and exact input hashes

- `CJ(x)` is canonical JSON encoded as UTF-8 without BOM or trailing newline: every string is NFC and case-preserved; object fields use the declared order; arrays use the declared semantics; integers are base-10 JSON integers; finite decimals are shortest base-10 strings without exponent or redundant trailing zero; only required JSON escaping is used. Missing, `null`, `""`, `[]`, and `0` are distinct; unknown fields/enums and U+0000 are invalid.
- `Ordinal` means case-sensitive .NET `StringComparer.Ordinal` comparison of UTF-16 code units after NFC. A set is a duplicate-free array sorted by its stated Ordinal tuple key; a list preserves order and duplicates only where explicitly permitted. Array boundaries and counts are encoded by JSON itself. Every structured digest is lowercase `sha256(CJ([domainTag,payload]))`; raw SHA-256 is used only where explicitly stated.
- Canonical array keys are: input artifacts by artifactId; TO01 `toolRows` in the exact TG01,TG02,TG03 order; TO01 `testRows` in the exact T1A-TEST01 through T1A-TEST10 order frozen below; TO01 `failures` by failureId; evidence by evidenceId; source roots by sourceId; source/excluded members by `(sourceId,portableRelativePath)`; authority scopes by authorityScopeId; subjects by `(candidateId,subjectKind,subjectId)`; relationships by `(candidateId,sourceSubjectId,relationshipKind,slotOrdinal,relationshipId)`; obligations/results by obligationId; operations by operationId; output members by portableRelativePath; T4 upstream refs by artifactId. Every `*RefIds`, origin, conflict, enumerated-slot, expected-kind, and parameter-value set sorts Ordinal by its sole ID or declared tuple; argumentTokens alone preserves execution order. Duplicate rows or keys are invalid.
- `memberId="C1F-"+sha256(CJ(["cerg-t1v22/member-id/1",sourceId,path,sizeBytes,sha256,containerKind,memberClass]))`; `evidenceId="EVI-"+sha256(CJ(["cerg-t1v22/evidence-id/1",inputArtifactId,evidenceClass,path,byteCount,sha256,locatorKind,locator,originObligationIds]))`; `subjectId="SUB-"+sha256(CJ(["cerg-t1v22/subject-id/1",candidateId,subjectKind,authorityIdentity]))`.
- `authorityScopeId="SCP-"+sha256(CJ(["cerg-t1v22/authority-scope-id/1",candidateId,authorityKind,ownerSubjectId,scopeLocator]))`; `authorityScopeFingerprint=sha256(CJ(["cerg-t1v22/authority-scope/1",candidateId,authorityKind,ownerSubjectId,scopeLocator,true,enumeratedSlotIds,evidenceRefIds]))`.
- `relationshipId="REL-"+sha256(CJ(["cerg-t1v22/relationship-id/1",candidateId,sourceSubjectId,relationshipKind,slotOrdinal,authorityScopeId,serializedPropertyPath,overrideSourceClipSubjectId,blendChildOrdinal,eventTime,eventFunctionName]))`; `obligationId="OBL-"+sha256(CJ(["cerg-t1v22/obligation-id/1",candidateId,obligationKind,ownerIdentity,allowedMemberRefIds,requiredRelationshipKinds,requiredSubjectKinds]))`.
- `implementationId="IMP-"+sha256(CJ(["cerg-lo1/implementation-id/1",implementationRole,implementationVersion,implementationByteCount,implementationSha256,runtimeByteCount,runtimeSha256,orderedArgumentTokens]))`; `operationId="OP-"+sha256(CJ(["cerg-lo1/operation-id/3",obligationRefIds,implementationRefIds,inputMemberRefIds,sourceReadMaxFiles,sourceReadMaxBytes,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,stagingInputPortablePath,outputPortablePath,workPortablePath]))`; `failureId="FAIL-"+sha256(CJ(["cerg/failure-id/2",transitionId,upstreamArtifactSha256,reasonCode]))`.
- A TO01 failure row uses `failureId="T1AF-"+sha256(CJ(["cerg-t1a/to01-failure-id/1",startingContractHeadCommit,reasonCode,ownerId,testId,prerequisiteId,evidenceLocator]))`; inapplicable `testId` and `prerequisiteId` are encoded as JSON `null`, never missing or empty. This TO01-specific ID is not the later generic `FAIL-` identity.
- I01/I02 `sha256` is the raw heading-bounded byte SHA; I03 `sha256` is the raw complete-ledger SHA; I04 `sha256` equals its directory member-set fingerprint. Every singleton encodes a two-element outer array whose second element is a one-row array: exact bytes are `CJ(["cerg-t1v22/input-member-set/1",[[portableRelativePath,byteCount,rawSha256]]])`; flattening either bracket level is invalid. I03 therefore hashes to exactly `8e9defe851714dc9443756c7d95d7ee259eeacc1b820e6306ba1f11a0b77d586`. For I04, every path is the exact NFC worktree-repository-relative portable path beginning `Extracted/FastFeasibilitySpike/LO-FFS1/`; rows sort by `StringComparer.Ordinal` on that complete path before encoding as the second-element array and hash to exactly `df205c3b2eaffe6cf02894277c661b4b43d2ac61122d7dc4a3ecd4c0ac40d48b`. Culture/case-sensitive sorting, I04-root-relative paths, or a flattened payload is invalid. I01/I02/I03 have `memberCount=1`; I04 has `memberCount=2037`, `byteCount=646020410`. No projection hash may replace a registered raw hash.
- `sourceMemberSetFingerprint=sha256(CJ(["cerg-t1v22/candidate-source-member-set/1",rows]))`; `candidateLexicalSetFingerprint=sha256(CJ(["cerg-t1v22/candidate-lexical-set/1",rows]))`; `baselineEvidenceSetFingerprint=sha256(CJ(["cerg-t1v22/baseline-evidence-set/1",rows]))`. In all three, `rows` is one array sorted Ordinal by `(sourceId,path)`, `(sourceId,path)`, or `fullPortablePath` respectively; row fields and their order are frozen below. These v2.2 domain tags intentionally invalidate the erroneous v2.1 fingerprints.
- O01 freshness binds the corrective tool HEAD, equal I01/I02 raw hashes, all I01-I04 hashes/member-set fingerprints, raw TO03 SHA, every corrected TG01-TG03 raw SHA from TO03, the two candidate fingerprints, and the baseline fingerprint. Any byte, membership, sort, test result, or HEAD change suppresses consumption; nothing is refreshed in place.

#### Deterministic C1 partition and frozen member tuples

The exact case-sensitive predicate is `sourceId == "pc-install"` and either (a) `containerKind == "UnityBundle"` and `relativePath` matches `^(Persistent_Store/AssetBundles|xtlr_Data/StreamingAssets/InstallResource)/char_14401(?:_[a-z0-9_]+)?\.unity3d$`, or (b) `relativePath == "Persistent_Store/SoundBanks/Japanese/Character_14401.bnk"`. Branch (a) is `Included3D`; branch (b) is `ExcludedAudio`. It yields `18` rows and `118064722` bytes. The lexical row shape is `[sourceId,path,sizeBytes,sha256,containerKind,disposition]`, true-Ordinal fingerprint `b99090872543f94d4a9b598b6293d83ced216cf3b03f90993e8ef2634b3e3b52` under the v2.2 tag above. The sole excluded row is `pc-install|Persistent_Store/SoundBanks/Japanese/Character_14401.bnk|1421918|2515da864ba6364c1344546f5fead95fdba21f52ede1e45d75a2e918ac83b6df|AudioMetadata`. `char_2d_14401` never matches.

O01 `sourceMembers` equals exactly these seventeen true-Ordinal rows. Each has `sourceId=pc-install`, `containerKind=UnityBundle`; the fingerprint row shape is `[sourceId,path,sizeBytes,sha256,containerKind,memberClass]`:

| Ordinal | Portable relative path | Bytes | SHA-256 | Class |
|---:|---|---:|---|---|
| 1 | `Persistent_Store/AssetBundles/char_14401.unity3d` | 259486 | `c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b` | OtherCandidateDependency |
| 2 | `Persistent_Store/AssetBundles/char_14401_animations.unity3d` | 37819874 | `8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d` | Animation |
| 3 | `Persistent_Store/AssetBundles/char_14401_fx.unity3d` | 1944422 | `02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab` | FX |
| 4 | `Persistent_Store/AssetBundles/char_14401_models.unity3d` | 3080984 | `66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7` | Model |
| 5 | `Persistent_Store/AssetBundles/char_14401_timeline.unity3d` | 4341943 | `22cafed7bb84fec59a0b2f4ccf0687ff9434ad38e7a21de9041ca313565d0228` | Timeline |
| 6 | `xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d` | 268605 | `0ba4bb19cbd6aa934e77517aee55df98be6601da8fb2ac7f65c27015ded049e7` | OtherCandidateDependency |
| 7 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d` | 54450761 | `cd46d53c25efc4a730029039d2cb5fc24c610056f736b8e5feec148cfd5db83c` | Animation |
| 8 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d` | 3573 | `72786cf23ad38898e5fee639412bec7ea59b2e9236e4ec622ace2c1ca1707605` | OtherCandidateDependency |
| 9 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d` | 35045 | `341f48a8082fd80ba153d0918379e1ab9dcd895938a7c50fd284858684dcc4aa` | Combo |
| 10 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d` | 27721 | `57faf217acb60502b9f955d949438f832bfc3d94337ad7253eb7723495c8dcb5` | Combo |
| 11 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d` | 3956 | `de1aa4e4f2f2de24f8ab5994c8be5bfd0f2fc903888c3168159fd2531c2a5397` | OtherCandidateDependency |
| 12 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d` | 1997681 | `14f0046fa7397d07c73f2994c3fb53abb649e140bf38592e899005c3033de3bc` | FX |
| 13 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d` | 6660 | `8128c13e92c8e1db8c9fe242b11d748c96953d73df24a91650cf38c9eba61e21` | Material |
| 14 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d` | 3078427 | `8c16df97fd2facbcc6ee94b5b46d5d4ebe46ec2948b3a2453684f3ac5a249427` | Model |
| 15 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d` | 4909859 | `cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd` | Texture |
| 16 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d` | 4402166 | `63c240049add3dbc0511827c66b36aab32a369fffc8b6f8bb17b23b34af1b6a6` | Timeline |
| 17 | `xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d` | 11641 | `0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048` | Weapon |

Thus `CandidateLexicalRows=SourceMembers ⊎ ExcludedSourceMembers`, `18=17+1`; included bytes are `116642804`; source-member fingerprint is `457e881475347f6a1ce76b3ba8e3bc02fb609802d429a1096335ab07f2a2b7dd` under the v2.2 tag. A count, byte, SHA length/value, class, order, or fingerprint mismatch suppresses O01.

The baseline is exactly the following eight LO-FFS1 tuples: `baselineEvidenceMemberCount=8`, `baselineEvidenceBytes=35016725`, and v2.2 domain-tagged true-Ordinal fingerprint `902b758b81b046e068117840d3fc0e59eca85b9136c204965ecee9c376206b2c`.

| Ordinal suffix under `Extracted/FastFeasibilitySpike/LO-FFS1/Export/CharacterEnvironment/ExportedProject/Assets/assetbundles/actor/character/14401/` | Bytes | Raw SHA-256 |
|---|---:|---|
| `animations/144_Attack.anim` | 33178294 | `a85a80965ff5836354bb2856f8bf7b2aead9da01fe33458dc253d7ea6f625dfc` |
| `animations/144_Attack.anim.meta` | 249 | `4a32d200a2547455bea1c606db53314fef08ba39011c3b057a8afb23f0983099` |
| `models/14401.prefab` | 355383 | `3fdc57bf91c18ab84457d2cb9df5b2409c0dd2148227c38f9ac70c3261c7d9b8` |
| `models/14401.prefab.meta` | 308 | `7463d2fc4fda69280da2635ade2473fee159b3b464d6ff9c6a3783f95d951f10` |
| `models/14401Avatar.asset` | 171334 | `ca0eec8927df86df5cf5292a9bf5350b28ca67777a76ad7884f97c35de0fa6db` |
| `models/14401Avatar.asset.meta` | 245 | `c28cbb20080b4140ec2982fbc46b3cabbbc8a38c9792eefd18414fd00b25950b` |
| `models/body.asset` | 1310667 | `c39b57e771dbe333a516b80b4a49e7eb63a2ded42156b47113cdeff5a71834e3` |
| `models/body.asset.meta` | 245 | `4c2fc644c1d1f68063cd3977abaa19266d467dfbc3c06b77f9648894aa8efb2d` |

#### Lossless Subject/Partition Registry

All T1 baseline and LO1 discovered graph rows use these exact shapes. Nullable specialized fields are always present and `null` when inapplicable; all reference arrays are sorted duplicate-free sets.

- `EvidenceItem={evidenceId,inputArtifactId,evidenceClass,portableRelativePath,byteCount,sha256,locatorKind,locator,originObligationIds}`. Permitted class/locator pairs are `C1SourceProjection/C1SourceId`, `C1FileProjection/C1FileTuple`, `LOFFS1WholeFile/WholeFileIdentity`, `UnityMeta/UnityGuidRecord`, `SerializedRelationship/YamlObjectPath`, `LO1OutputWholeFile/WholeFileIdentity`, `LO1SerializedDiscovery/SerializedPropertyPath`, and `LO1ToolRun/StructuredRunField`. T1 baseline rows have `originObligationIds=[]`; every LO1-created row has a nonempty origin set. Paths and locators are portable and contain no absolute/private root, user, host, credential, or unrestricted log text. C1/FFS provenance can prove an identity or present locator but never exhaustive absence.
- `AuthorityScope={authorityScopeId,candidateId,authorityKind,ownerSubjectId,scopeLocator,isExhaustive,enumeratedSlotIds,evidenceRefIds,originObligationIds,authorityScopeFingerprint}`. `authorityKind` is `Controller`, `OverrideController`, `Prefab`, `AnimationEvent`, or `SerializedObject`; `isExhaustive` is exactly `true`; `enumeratedSlotIds` is the complete finite authority-owned slot set, never a sample; the fingerprint uses the formula above.
- `GraphSubject={subjectId,candidateId,subjectKind,authorityIdentity,unityGuid,serializedFileId,sourceObjectId,portableRelativePath,contentSha256,unityTypeName,rendererKind,componentClass,blendTreeType,parameterName,evidenceRefIds,originObligationIds}`. Kinds are `CandidateFamilyAnchor`, `Model`, `GameObject`, `Renderer`, `Mesh`, `Material`, `Texture`, `Shader`, `Skeleton`, `Bone`, `Avatar`, `Controller`, `OverrideController`, `StateMachine`, `ActionState`, `AttackAction`, `Motion`, `BlendTree`, `BlendParameter`, `BlendBranch`, `ActionClip`, `AnimationEvent`, `FXPrefab`, `FXObject`, `FXComponent`, `Weapon`, `Combo`, `Timeline`, or `ReferencedObject`. `rendererKind` is non-null exactly for Renderer and is `MeshRenderer`, `SkinnedMeshRenderer`, `ParticleSystemRenderer`, `TrailRenderer`, or `OtherRenderer`. `componentClass` is non-null exactly for FXComponent and is `ParticleSystem`, `TrailRenderer`, `Renderer`, `Animator`, `Transform`, or `OtherSerializedFXComponent`. `blendTreeType` is non-null exactly for BlendTree and is `OneD`, `SimpleDirectional2D`, `FreeformDirectional2D`, `FreeformCartesian2D`, or `Direct`; `parameterName` is non-null exactly for BlendParameter.
- `GraphRelationship={relationshipId,candidateId,slotOrdinal,sourceSubjectId,relationshipKind,targetSubjectId,state,authorityKind,authorityScopeId,authorityScopeFingerprint,serializedPropertyPath,overrideSourceClipSubjectId,blendChildOrdinal,blendThreshold,blendPositionX,blendPositionY,childTimeScale,childCycleOffset,childMirror,directBlendParameterSubjectId,blendParameterValues,eventTime,eventFunctionName,evidenceRefIds,conflictingTargetSubjectIds,obligationId,originObligationIds}`. `blendParameterValues` rows are exactly `{parameterSubjectId,value}` sorted by parameterSubjectId.
- Relationship kinds are `AnchorOwnsModel`, `ModelContainsRenderer`, `RendererUsesMesh`, `RendererUsesMaterial`, `RendererUsesSkeleton`, `SkeletonContainsBone`, `AvatarUsesSkeleton`, `AnchorOwnsActionClip`, `ActionClipBindsSkeleton`, `ControllerOwnsStateMachine`, `StateMachineContainsStateMachine`, `StateMachineContainsState`, `StateUsesMotion`, `BlendTreeUsesParameter`, `BlendTreeContainsBranch`, `BlendBranchUsesMotion`, `MotionUsesClip`, `OverrideMapsClip`, `ActionHasAnimationEvent`, `AttackTriggersFX`, `FXPrefabContainsObject`, `FXObjectContainsObject`, `FXObjectHasComponent`, `FXComponentReferencesSubject`, `MaterialUsesTexture`, `MaterialUsesShader`, `TimelineUsesAction`, `WeaponUsesAction`, `ComboUsesAction`, or `SerializedObjectReference`.
- Source→target kind pairs are closed by those names: Anchor→Model/ActionClip; Model→Renderer; Renderer→Mesh/Material/Skeleton; Skeleton→Bone; Avatar→Skeleton; Controller→StateMachine; StateMachine→StateMachine/ActionState/AttackAction; ActionState/AttackAction→Motion/BlendTree and →AnimationEvent; BlendTree→BlendParameter/BlendBranch; BlendBranch→Motion/BlendTree; Motion→ActionClip; OverrideController→ActionClip with a separate source-clip identity; AttackAction→FXPrefab; FXPrefab→FXObject; FXObject→FXObject/FXComponent/Renderer; FXComponent→any typed subject; Material→Texture/Shader; Timeline/Weapon/Combo→ActionState/AttackAction. `SerializedObjectReference` may target any typed candidate subject but never replaces a more specific relationship kind.
- `BlendTreeContainsBranch` is BlendTree→BlendBranch and freezes `blendChildOrdinal`, child timing/mirror, and exactly the applicable OneD threshold, 2D position, or Direct parameter plus the complete parameter-value vector. `BlendBranchUsesMotion` is BlendBranch→Motion/BlendTree. Traversal recursively accounts for every nested StateMachine and every branch until every leaf terminates in ActionClip; child ordinals are unique and contiguous per tree.
- `slotOrdinal` is a positive integer unique for `(candidateId,sourceSubjectId,relationshipKind)`. The blend fields are non-null exactly for `BlendTreeContainsBranch`. `serializedPropertyPath` is non-null exactly for `SerializedObjectReference` or a ProvenPresent `FXComponentReferencesSubject`; `overrideSourceClipSubjectId` is non-null exactly for a ProvenPresent `OverrideMapsClip`; `eventTime` and `eventFunctionName` are non-null exactly for a ProvenPresent `ActionHasAnimationEvent`. An `EvidenceUnavailableBeforeExtraction` row of any of those three latter kinds instead has its kind-specific fields null under the latest state-specific correction above. Every other specialized field is null. Every referenced subject and parameter is candidate-local.
- FX closure is `FXPrefab→FXObject→nested FXObject→FXComponent`; every object child and component slot has an ordinal, and every serialized object-reference property is one `FXComponentReferencesSubject` row with exact property path and typed target, using ReferencedObject when no narrower kind applies. Renderer, ParticleSystem, and TrailRenderer identities cannot be collapsed into prose or component counts.
- A `ProvenPresent` row has one target, nonempty evidence, no conflicts, and null obligation; its scope pair is either both null for the seven fixed T1 baseline edges or both non-null and resolves to the exhaustive current AuthorityScope in R01. A `ProvenAbsent` row has no target/conflicts/obligation, nonempty evidence, and one non-null AuthorityScope whose owner, authority kind, fingerprint, and complete enumerated slots match the row. `NoEffectExpected` is legal only for a ProvenAbsent `AttackTriggersFX` row backed by such a complete current scope. An unavailable row has no target/scope/conflicts, one obligation, nonempty owner evidence, and state `EvidenceUnavailableBeforeExtraction`; a Contradictory row has at least two sorted distinct targets/evidence and no scope/obligation. Closed R01 requires a non-null exhaustive scope for every completeness-bearing collection other than the seven carried baseline edges.
- `DiscoveryObligation={obligationId,candidateId,obligationKind,ownerIdentity,allowedMemberRefIds,requiredRelationshipKinds,requiredSubjectKinds,successDisposition,failureDisposition}`. Exactly one row exists for each of: `ResolveBaseController`, `EnumerateControllerGraph`, `EnumerateOverrideMap`, `EnumerateCompleteActionUniverse`, `EnumerateAnimationEvents`, `ResolveAttackFXTriggers`, `EnumerateFXPrefabComponents`, `ResolveRendererMaterialTextureShader`, `ResolveSkeletonAvatar`, `ResolveTimelineWeaponsCombos`, `ResolveReferencedDependencies`. Each maps one-to-one to one unavailable relationship; `deadbeef` belongs to ResolveBaseController.

A Passed O01 contains the exact seven baseline subjects `CandidateFamilyAnchor(PortableFamilyKey:char_14401)`, `Model(UnityGuid:a99d9cb8935099d4db6bde95d5ddf839)`, `Renderer(YamlObject:a99d9cb8935099d4db6bde95d5ddf839:137041608817324026; rendererKind=SkinnedMeshRenderer)`, `Mesh(UnityGuid:8ad84e37c5826394f9d018c69933e209)`, `Skeleton(SkeletonBinding:a99d9cb8935099d4db6bde95d5ddf839:137041608817324026:4904400124545405)`, `Avatar(UnityGuid:1031627e0cce26240a72299bc74e2939)`, and `ActionClip(UnityGuid:16b6b13783e73d648a6faff48a4e3361)`. It also contains exactly the ProvenPresent edges `AnchorOwnsModel`, `ModelContainsRenderer`, `RendererUsesMesh`, `RendererUsesSkeleton`, `AvatarUsesSkeleton`, `AnchorOwnsActionClip`, and `ActionClipBindsSkeleton`, all with direct nonempty locators covering all eight baseline members. Anchor-only, disconnected, filename-derived, or prose-only output is suppressed.

Universes and partitions are exact: `CandidateLexicalRows=SourceMembers ⊎ ExcludedSourceMembers`; `Subjects=⊎ subjectKind`; `Relationships=ProvenPresent ⊎ ProvenAbsent ⊎ EvidenceUnavailableBeforeExtraction ⊎ Contradictory`; `Obligations=⊎ obligationKind`; `AuthorityScopes=⊎ authorityKind`. Required equations include `18=17+1`, byte conservation, `subjectCount=ΣsubjectKindCounts`, `relationshipCount=ΣstateCounts`, `authorityScopeCount=ΣauthorityKindCounts`, and `obligationCount=unavailableCount=11`. Every row belongs to exactly one candidate and direct parent partition; every reference resolves exactly once.

The replacement T1A tooling gate is a complete ordinary Task and precedes candidate evaluation by a mandatory audit stop. TO01 top-level fields, in order, are `schemaVersion`, `artifactId`, `contractHeadCommit`, `toolRows`, `testRows`, `partitions`, `status`, `failures`, `nextAction`. `toolRows={artifactId,implementationRole,implementationVersion,portableRelativePath,byteCount,sha256}` and, when nonempty, is exactly `[T1V22-TG01,T1V22-TG02,T1V22-TG03]` in that order. `testRows={testId,testClass,status,evidenceLocator}` is exactly this ordered identity/class list: `T1A-TEST01/ExactLeafAllow`, `T1A-TEST02/RootDirectoryReject`, `T1A-TEST03/PathEscapeReject`, `T1A-TEST04/SizeHashReject`, `T1A-TEST05/StagingBijection`, `T1A-TEST06/InterruptedVector`, `T1A-TEST07/CompleteR01Graph`, `T1A-TEST08/MissingGraphReject`, `T1A-TEST09/PartialDiagnosticReject`, `T1A-TEST10/CanonicalDeterminism`. Each appears once; status is `Passed` or `Failed`. A test that ran uses its nonempty stable fixture evidence locator. A test not run because a prerequisite failed is still `Failed` and uses `PrerequisiteFailure/<prerequisiteId>/<reasonCode>`, where `prerequisiteId` is one TG artifact ID or an earlier testId and `reasonCode=FixturePrerequisiteFailed`; `Skipped`, `NotRun`, empty locator, omission, or any other order is invalid. `partitions={passedCount,failedCount,totalCount}` conserves `totalCount=10=passedCount+failedCount` in both outcomes.

`failures` is an array of complete rows, never an array of strings. `TO01Failure={failureId,reasonCode,ownerId,testId,prerequisiteId,evidenceLocator}`. `reasonCode` is exactly `ImplementationUnavailable`, `HarnessUnavailable`, `FixtureAssertionFailed`, `FixturePrerequisiteFailed`, `ToolCommitFailed`, or `PreCommitCanonicalizationFailed`; `ownerId` is exactly one of `T1V22-TG01`, `T1V22-TG02`, `T1V22-TG03`, `T1A-TEST01` through `T1A-TEST10`, `GitToolCommit`, `T1V22-TOT01`, or `T1V22-TO01`. For a fixture assertion or prerequisite failure, `ownerId=testId` and `testId` is non-null; `prerequisiteId` is non-null exactly for `FixturePrerequisiteFailed`; otherwise `testId` and `prerequisiteId` are JSON `null`. Every locator is nonempty, stable, portable, and redacted. Every Failed test row has exactly one failure row with the same testId and evidenceLocator; other gate failures have null testId. Rows are duplicate-free and sorted Ordinal by failureId, and every ID exactly recomputes under the TO01-specific formula above. Green fixes `failures=[]`; Failed requires at least one row.

Green TO01 requires `contractHeadCommit` equal to the post-tool-commit HEAD; the exact three ordered tool rows with their committed identities; all ten ordered test rows Passed; `passedCount=10`, `failedCount=0`, `status=Green`, `failures=[]`; and `nextAction=AwaitTotalControlAuditBeforeCERGT1B`. Failed TO01 requires `contractHeadCommit` equal to the T1A starting contract HEAD; `toolRows=[]`; all ten ordered test rows present, with every unrun row encoded as the prerequisite Failed form above; at least one complete failure row; `status=Failed`; and `nextAction=ReturnToTotalControlAuditForT1A`. On Failed, every T1A-created TG01-TG03 worktree byte is rolled back, no tool commit exists, the ending Git HEAD equals the starting contract HEAD, T01/O01 and every candidate/LO artifact are absent, and no C1/FFS candidate evidence was read. Green and Failed are mutually exclusive: post-commit tool identity is forbidden in Failed, while an empty/uncommitted tool identity is forbidden in Green. Both outcomes stop for total-control audit. Green is readiness evidence, not T1B authority; Failed can never authorize T1B. T1B authorization must bind the exact raw Green TO01 SHA, its post-tool-commit `contractHeadCommit`, all TG01-TG03 identities, and an explicit total-control disposition `ApprovedForCERGT1B`; TO01 and O01 then bind that same post-tool-commit HEAD.

For either outcome, a new T1A requires TOT01 and TO01 absent before its first write. After the applicable HEAD is fixed, T1A writes the complete canonical bytes only to TOT01, reopens and validates those raw bytes, and performs one no-overwrite atomic install to TO01. Successful installation leaves TOT01 absent and the immutable TO01 byte-identical to the validated temporary bytes. A pre-existing TO01, replacement of TO01, direct write to TO01, or consumption of TOT01 is forbidden. If Failed publication cannot install before any tool commit, transition T1A-FT04 records the exact observed TOT01/TO01 state and no tool or downstream artifact exists. If the tool commit already exists and Green TO01 is absent, malformed, stale, or cannot be atomically installed for any reason, transition T1A-FT03 applies: the committed tools remain immutable, no Failed TO01 may be fabricated, and T1B remains denied.

#### Complete T1V22-O01 shape and Passed rule

O01 top-level fields, in order, are `schemaVersion`, `artifactId`, `contractHeadCommit`, `normativeOverrideSha256`, `mirrorOverrideSha256`, `status`, `consumableForLoCerg1Preflight`, `selectedCandidateId`, `priorInvalidation`, `inputArtifacts`, `toolingReadiness`, `attackAnchors`, `evidenceItems`, `candidate`, `sourceRoots`, `sourceMembers`, `excludedSourceMembers`, `authorityScopes`, `subjects`, `relationships`, `discoveryObligations`, `partitions`, `failures`, `summary`, `nextAction`.

- Fixed values are `cerg-t1-candidate-lock/2.2.0`, `CERG-T1V22-O01`, `Passed`, `true`, `char_14401`, `failures=[]`, and `PrepareLOCERG1PreflightThenRequestExactHumanConfirmation`. `priorInvalidation={historicalArtifactId,portableRelativePath,byteCount,sha256,disposition,consumed,terminal}` records H01 as `InvalidatedByContractDefect,false,false`.
- `inputArtifacts={artifactId,portableRelativePath,byteCount,sha256,memberCount,memberSetFingerprint}` covers I01-I04 once. `toolingReadiness={artifactId,portableRelativePath,byteCount,sha256,toolRefIds,testCount,passedCount,auditDisposition,approvedToolingSha256}` binds TO03 plus corrected TG01-TG03 with `testCount=passedCount=23`, `auditDisposition=ApprovedForCERGT1B`, and `approvedToolingSha256` equal to TO03's raw SHA. `SourceRoot={sourceId,sourceKind,rootFingerprint,evidenceRefIds}`; `SourceMember={memberId,candidateId,sourceId,portableRelativePath,sizeBytes,sha256,containerKind,memberClass,evidenceRefIds}`; `ExcludedSourceMember={sourceId,portableRelativePath,sizeBytes,sha256,containerKind,exclusionReason,evidenceRefIds}`.
- `candidate={candidateId,comparisonOrdinal,familyIdentityKind,familyIdentityValue,disposition,memberRefIds,candidateLexicalCount,candidateLexicalBytes,candidateLexicalSetFingerprint,candidateSourceMemberCount,candidateSourceMemberBytes,candidateSourceMemberSetFingerprint,baselineEvidenceRefIds,baselineEvidenceMemberCount,baselineEvidenceBytes,baselineEvidenceSetFingerprint,rejectionFailureIds}` uses the frozen tuples/fingerprints with `comparisonOrdinal=1`, `familyIdentityKind=PortableFamilyKey`, `familyIdentityValue=char_14401`, `disposition=Locked`, and `rejectionFailureIds=[]`.
- `partitions={evidenceClassCounts,memberClassCounts,subjectKindCounts,evidenceStateCounts,obligationKindCounts,authorityKindCounts,evidenceItemCount,attackAnchorCount,sourceRootCount,sourceMemberCount,excludedSourceMemberCount,authorityScopeCount,subjectCount,relationshipCount,discoveryObligationCount}` contains every enum including zero. `summary={candidateCount,lockedCount,rejectedCount,evidenceItemCount,attackAnchorCount,sourceRootCount,sourceMemberCount,excludedSourceMemberCount,authorityScopeCount,subjectCount,relationshipCount,discoveryObligationCount,failureCount}` fixes `candidateCount=1`, `lockedCount=1`, `rejectedCount=0`, `attackAnchorCount=1`, `sourceRootCount=1`, `sourceMemberCount=17`, `excludedSourceMemberCount=1`, `authorityScopeCount=0`, `discoveryObligationCount=11`, and `failureCount=0`; evidence/subject/relationship counts derive from their arrays.
- Every tuple, graph, evidence, partition, fingerprint, and freshness predicate must hold simultaneously. A failure rolls back T01, suppresses O01, authorizes nothing, and returns to audit; v2.2 has no Failed candidate-lock artifact.

#### LO-CERG1 exact-leaf-to-staging preflight contract

P01 top-level fields are `schemaVersion`, `artifactId`, `candidateLockSha256`, `contractHeadCommit`, `selectedCandidateId`, `createdAt`, `sourceRootBindings`, `implementationBindings`, `operation`, `aggregateLimits`, `stagingPlan`, `status`, `nextAction`. Fixed values are `cerg-lo-cerg1-preflight/1.3.0`, `LO-CERG1-P01`, `char_14401`, `Green`, and `RequestExactHumanConfirmationForLOCERG1`.

- `sourceRootBindings={sourceId,privateAbsoluteReadOnlyRoot,rootFingerprint}` maps one-to-one to SourceRoots. A root is only a private resolver base used by the staging wrapper one exact member at a time. It is never the AssetRipper or graph-producer input, working directory, enumerated path, conversation/repository value, glob base, prefix selector, or recursive selector.
- `implementationBindings={artifactId,implementationId,implementationRole,implementationVersion,pathKind,portableTrackedPath,privateAbsoluteLeafPath,implementationByteCount,implementationSha256,runtimePrivateAbsoluteLeafPath,runtimeByteCount,runtimeSha256,orderedArgumentTokens}` contains exactly T1V22-TG01/T1V22-TG02/LO1-IF01/LO1-IA01 mapped one-to-one to `ExactLeafStagingWrapper`, `R01GraphProducer`, `AssetRipperFolderInvoker`, and `AssetRipperExecutable`. `pathKind` is `Tracked` for the first three and `Private` for IA01; exactly the applicable path field is non-null. TG01/TG02 identities equal approved TO03 byte-for-byte, so preflight can neither substitute nor create them. Every path is an existing non-directory leaf; every byte count is positive and every SHA is the raw SHA-256 of the exact executable/script bytes. Runtime identity is required even when it is PowerShell; for a self-hosted executable its runtime leaf equals itself. A runtime identity alone never satisfies an implementation role.
- The folder invoker is exactly repository leaf `Tools/AssetImport/Invoke-AssetRipperFolderExport.ps1`, `14528` bytes, raw SHA-256 `29362d475b989a2855e44f60d60686ef4152066e0579ff026dbc9818112c2381`; preflight must still bind the actual checked-out leaf and runtime bytes. The sole graph producer has role/version `R01GraphProducer/CERG-LO1-R01-PRODUCER/3` and is the only implementation permitted to create LO1-RT01/R01. `Measure-UnityExportReferenceGraph.ps1` (`14854` bytes, SHA-256 `e29bcce06551ecc68bb8fbe921a15209e0472438067565910583817424be4ef9`) and `Measure-ActorControllerRecovery.ps1` (`13435` bytes, SHA-256 `ccf7fef5fd243742bdc84b0cb9ab0e1c9ea3a38f58f3b198808334bb8387c1de`) are partial diagnostics and are forbidden as the sole or substitute R01 producer.
- `operation={operationId,obligationRefIds,implementationRefIds,inputMemberRefIds,expectedSubjectKinds,expectedRelationshipKinds,sourceReadMaxFiles,sourceReadMaxBytes,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,stagingInputPortablePath,outputPortablePath,workPortablePath}` is exactly one pipeline operation. Its obligation set equals all eleven O01 obligations once, its input set equals all seventeen SourceMembers once, and its implementation set equals the four bindings once. `sourceReadMaxFiles=17`, `sourceReadMaxBytes=116642804`; the expected-kind sets are the exact unions required by the eleven obligations. Every other cap is one positive frozen integer. `aggregateLimits` equals this sole operation's limits, not a second source allowance.
- `stagingPlan={stagingInputPortablePath,stagingInventoryTemporaryPath,stagingInventoryPath,workPortablePath,outputPortablePath,memberRows,memberCount,byteCount,memberSetFingerprint}` freezes SD01/SIT01/SI01/WD01/D01 exactly. Each `memberRows={sourceMemberRefId,sourceId,sourcePortableRelativePath,stagingPortableRelativePath,byteCount,sha256}` maps one SourceMember to exactly `Extracted/CERG/SingleCharacter/LO-CERG1/Input/<sourceId>/<sourcePortableRelativePath>`; all seventeen rows are present once, with `memberCount=17`, `byteCount=116642804`, and `memberSetFingerprint=sha256(CJ(["cerg-lo1/staging-member-set/1",memberRows]))` under Ordinal `stagingPortableRelativePath` order.
- The exact staging wrapper is the only implementation allowed to resolve a true source path. For each frozen member, it joins `privateAbsoluteReadOnlyRoot + sourcePortableRelativePath`, proves strict containment without enumerating the root or parent, opens that one leaf once, hashes while copying, enforces the exact per-member bytes/SHA, and creates only its frozen staging leaf. No real root/parent, directory selector, basename-only selector, glob, wildcard, prefix, regex, recursive flag, response file, or shell expansion may be passed to AssetRipper, the graph producer, or any child process.
- The wrapper rescans only SD01 after all copies, requires bidirectional equality `SourceMembers ↔ stagingPlan.memberRows ↔ recursive SD01 leaves`, writes SIT01, validates its canonical bytes, and atomically installs SI01. Only then may the fixed folder invoker call AssetRipper with exactly the SD01 directory as `InputPath`, D01 as its export root, and WD01 as its private log/work root. AssetRipper may enumerate SD01 but must never receive or enumerate a real source root or parent. The graph producer consumes only O01, P01, A01, SI01, recursive D01, and frozen safe baseline evidence; it must generate the complete R01 schema below and may not open true source.
- `orderedArgumentTokens` is frozen separately for every implementation and may contain only literal options plus the role-appropriate exact placeholders `{SOURCE_MEMBER:<memberId>}`, `{STAGING_INPUT}`, `{STAGING_INVENTORY}`, `{OUTPUT_ROOT}`, `{WORK_ROOT}`, `{CANDIDATE_LOCK}`, `{PREFLIGHT}`, `{ATTEMPT_STATE}`, and `{RESULT_TEMP}`. Every placeholder required by its role appears exactly once. Fully expanded tokens, working directory, all implementation/runtime bytes and SHAs, limits, the absence of A01/SD01/SIT01/SI01/WD01/D01/RT01/R01, one-attempt/no-retry behavior, cancellation semantics, and complete P01 SHA are bound by exact human confirmation.

F01 has exactly `schemaVersion`, `artifactId`, `candidateLockSha256`, `contractHeadCommit`, `selectedCandidateId`, `transitionId`, `failureId`, `reasonCode`, `preflightAttemptCount`, `LOAttemptCount`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `status`, `consumableForLoCerg1`, `nextAction`. Fixed values are `schemaVersion=cerg-lo-cerg1-preflight-failure/1.2.0`, `artifactId=LO-CERG1-F01`, `selectedCandidateId=char_14401`, `transitionId=LO1-PF02`, `preflightAttemptCount=1`, `LOAttemptCount=0`, `ordinaryTaskUsed=3`, `ordinaryTaskBudget=6`, `LOUsed=0`, `LOBudget=3`, `status=PreflightExhausted`, `consumableForLoCerg1=false`, and `nextAction=RunCERGT4ForPreflightExhaustion`. Reason is one of `SourceBindingMismatch`, `ImplementationIdentityMissingOrMismatch`, `GraphProducerCapabilityMissing`, `OperationConservationFailure`, `ExactLeafOrStagingBoundaryFailure`, `LimitOrOutputInvalid`, or `PreexistingAttemptState`.

A01 has exactly `schemaVersion`, `artifactId`, `candidateLockSha256`, `preflightSha256`, `contractHeadCommit`, `selectedCandidateId`, `attemptCount`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `status`, `consumableForT2`, `nextAction`. Fixed values are `schemaVersion=cerg-lo-cerg1-attempt-state/1.1.0`, `artifactId=LO-CERG1-A01`, `selectedCandidateId=char_14401`, `attemptCount=1`, `ordinaryTaskUsed=3`, `ordinaryTaskBudget=6`, `LOUsed=1`, `LOBudget=3`, `status=StartedNoResult`, `consumableForT2=false`, and `nextAction=IfNoValidLO1R01RunCERGT4ForLOCERG1Interrupted`. A01 is atomically installed before the first source read or SD01/WD01/D01 member and never changed. A valid R01 takes precedence; otherwise A01 plus the exact observable states of SD01/SIT01/SI01/WD01/D01 is the complete interruption vector and a retry is forbidden.

#### LO1-R01 exact-universe closure result

R01 top-level fields, in order, are `schemaVersion`, `artifactId`, `candidateLockSha256`, `preflightSha256`, `attemptStateSha256`, `stagingInventorySha256`, `contractHeadCommit`, `selectedCandidateId`, `attemptCount`, `status`, `consumableForT2`, `stagingMembers`, `evidenceItems`, `authorityScopes`, `subjects`, `relationships`, `obligationResults`, `outputMembers`, `partitions`, `closure`, `summary`, `nextAction`.

- `obligationResults={obligationId,status,subjectRefIds,relationshipRefIds,evidenceRefIds,authorityScopeRefIds}` contains every frozen obligation exactly once; status is `Resolved`, `MissingDependency`, `ContradictoryDependency`, `ToolFailure`, `LimitExceeded`, or `OutputIntegrityFailure`. Each reference resolves inside R01.
- `stagingInventorySha256` is the raw SI01 hash. `stagingMembers` is byte-for-byte the canonical SI01 `memberRows` array; it has exactly seventeen rows and bidirectionally equals O01 SourceMembers and recursive SD01 leaves by member ID, source identity, staging path, bytes, and SHA. `outputMembers={portableRelativePath,byteCount,sha256,subjectRefIds,obligationRefIds}` inventories every recursive D01 member exactly once; paths sort Ordinal and every reference resolves. `partitions={evidenceClassCounts,authorityKindCounts,subjectKindCounts,evidenceStateCounts,obligationStatusCounts,evidenceItemCount,authorityScopeCount,subjectCount,relationshipCount,obligationResultCount,stagingMemberCount,outputMemberCount}` contains every enum including zero and fixes `stagingMemberCount=17`.
- Origin conservation is bidirectional: for every non-baseline evidence/scope/subject/relationship row, `originObligationIds` is nonempty and equals exactly the set of obligationResults that reference that row; baseline-carried rows alone have `[]` and must equal O01 baseline rows byte-for-byte. Every obligationResult's four reference sets equal exactly the rows bearing its obligation ID. Therefore resolved IDs cannot be asserted without their graph/evidence.
- `closure={requiredMissingReferenceCount,unclassifiedSubjectCount,unclassifiedRelationshipCount,contradictoryRelationshipCount,evidenceUnavailableCount,unresolvedObligationCount,unresolvedExternalIdentityCount,stagingMismatchCount,graphFingerprint}`. `graphFingerprint=sha256(CJ(["cerg-lo1/exact-universe/2",stagingMembers,evidenceItems,authorityScopes,subjects,relationships,obligationResults,outputMembers]))` over their frozen canonical sorts.
- `summary={obligationCount,resolvedCount,unresolvedCount,stagingMemberCount,stagingBytes,outputMemberCount,outputBytes,attemptCount,ordinaryTaskUsed,ordinaryTaskBudget,LOUsed,LOBudget}` conserves `obligationCount=11=resolvedCount+unresolvedCount`, `stagingMemberCount=17`, and `stagingBytes=116642804`; it fixes `attemptCount=1`, `ordinaryTaskUsed=3`, `ordinaryTaskBudget=6`, `LOUsed=1`, and `LOBudget=3`.
- `Closed` requires `consumableForT2=true`, exact SI01 identity and staging conservation, all eleven statuses Resolved; every closure count zero; all IDs/locators/scopes resolve; the recursive controller/state/motion/BlendTree branch-to-clip graph, override map, events, attack-to-FX expectations, nested FX object/components/references, all Renderers/materials/textures/shaders, skeleton/Avatar, timeline/weapons/combos, and referenced dependencies are exhaustively partitioned. It uses `nextAction=RunCERGT2`. T2 must reconstruct the exact universe from O01+SI01+R01+D01 only; prose or process exit cannot supply a missing row.
- Any nonzero closure count or non-Resolved obligation makes `status=Unresolved`, `consumableForT2=false`, and `nextAction=RunCERGT4ForLOCERG1Unresolved`. R01 remains an audit artifact. If no valid R01 exists after A01, the unique state is `InterruptedNoResult`; no synthetic resolved IDs are permitted.

#### V2.2 Failure Transition Table

`U1` below is an exact vector shorthand, not an omitted artifact: committed TG01+corrected TG02+TG03, total-control-approved Green TO03, and Passed O01. Every row containing `U1` retains those exact immutable identities. A later-stage “complete vector” also retains every successful upstream preflight/result named in its trigger; the row explicitly states all stage-local present/absent artifacts and no unlisted downstream-consumable artifact may exist.

| ID | Exact trigger | Complete artifact vector | Counters | Only next action |
|---|---|---|---|---|
| `T1A-FT01` | TG01-TG03 implementation, fixture testing, or pre-commit readiness cannot become Green, and canonical Failed TO01 installs successfully | Ending HEAD equals T1A starting contract HEAD; TG01-TG03 rolled back and uncommitted; TOT01 absent; TO01=`Failed` with that starting HEAD, `toolRows=[]`, all ten ordered test rows and at least one complete failure row; T01/O01, candidate reads, and every LO artifact absent | `2/6,0/3` | `ReturnToTotalControlAuditForT1A` |
| `T1A-FT02` | TG01-TG03 are committed, every tooling test is Green, and canonical Green TO01 installs and revalidates | Committed TG01-TG03+Green TO01 present; TOT01, T01/O01, and every LO artifact absent | `2/6,0/3` | `AwaitTotalControlAuditBeforeCERGT1B` |
| `T1A-FT03` | `ToolCommitPresentButTO01Unavailable`: the tool commit exists but TOT01/TO01 write, validation, atomic install, or final reopen is interrupted or fails, or TO01 is absent/malformed/stale | Committed TG01-TG03 retained unchanged at the post-tool-commit HEAD; TOT01 is absent/partial/complete exactly as observed; TO01 is absent or retained non-consumable bytes and never overwritten; T01/O01, candidate reads, and every LO artifact absent | `2/6,0/3` | `ReturnToTotalControlForToolCommitPresentButTO01Unavailable` |
| `T1A-FT04` | Before any tool commit, canonical Failed TO01 cannot be atomically installed or revalidated | Ending HEAD equals T1A starting contract HEAD; TG01-TG03 rolled back; TOT01 is absent/partial/complete exactly as observed; TO01 is absent or retained non-consumable bytes; T01/O01, candidate reads, and every LO artifact absent | `2/6,0/3` | `ReturnToTotalControlForFailedTO01Unavailable` |
| `T1B-FT01` | Exact TO03 is approved but any candidate contract/input/hash/member/baseline/graph/partition/safety/output predicate fails | Committed TG01+corrected TG02/TG03+approved Green TO03 present; T01 rolled back; O01 and every LO artifact absent | `3/6,0/3` | `ReturnToTotalControlAuditForT1B` |
| `T1B-FT02` | Approved tooling and every candidate Passed predicate hold | `U1`; no preflight/LO artifact | `3/6,0/3` | `PrepareLOCERG1Preflight` |
| `LO1-PF01` | Every implementation/runtime identity, exact-leaf-to-staging plan, operation, producer capability, and limit rule is Green | U1+P01 present; F01/A01/SD01/SIT01/SI01/WD01/D01/R01 absent | `3/6,0/3` | `RequestExactHumanConfirmationForLOCERG1` |
| `LO1-PF02` | Single preflight window exhausts without Green | U1+F01 present; PT01 rolled back; P01/A01/SD01/SIT01/SI01/WD01/D01/R01 absent | `3/6,0/3` | `RunCERGT4ForPreflightExhaustion` |
| `LO1-RT00` | Confirmed LO begins | U1+P01+A01 present before source read; SD01/SIT01/SI01/WD01/D01 absent or attempt-owned partial as permitted; R01 absent | `3/6,1/3` | `FinishSameAttemptOrTreatAsInterruptedNoResult` |
| `LO1-RT01` | One attempt publishes a Closed graph/result | U1+P01+A01+complete SD01+SI01+WD01+D01+Closed R01 present; SIT01 rolled back; F01 absent | `3/6,1/3` | `RunCERGT2` |
| `LO1-RT02` | One attempt publishes a valid Unresolved result, including a controlled staging/export/producer/closure failure | U1+P01+A01 plus the exact retained SD01/SIT01/SI01/WD01/D01 states and Unresolved R01 present; F01 absent | `3/6,1/3` | `RunCERGT4ForLOCERG1Unresolved` |
| `LO1-RT03` | A01 exists and no valid R01 exists when the foreground invocation ends, is cancelled/interrupted, or the process/host is next observed inactive | U1+P01+A01 present; R01 absent; each of SD01/SIT01/SI01/WD01/D01 is absent, partial, or complete exactly as observed and retained read-only | `3/6,1/3` | `RunCERGT4ForLOCERG1Interrupted` |
| `T2-FT01` | CERG-T2 cannot prove exact closure or construct/freeze the validator | T2 failure evidence only; Unity/T3/LO3 artifacts absent | `4/6,1/3` | `RunCERGT4ForT2ClosureFailure` |
| `LO2-RT01` | First Unity result proves every A-F criterion Green | Complete LO2 evidence/result; T3/LO3 absent | `4/6,2/3` | `RunCERGT4ForEverythingNormal` |
| `LO2-RT02` | First Unity result has exactly one fixed-scope, one-Task-repairable cause and total control approves its exact identity/scope | Complete LO2 evidence/result; T3/LO3 absent | `4/6,2/3` | `RunCERGT3ForApprovedSingleCause` |
| `LO2-RT03` | First Unity result has zero actionable, multiple, unbounded, contradictory, or unrepairable failure causes | Complete LO2 evidence/result; T3/LO3 absent | `4/6,2/3` | `RunCERGT4ForUnityValidationFailure` |
| `T3-RT01` | The one approved cause is repaired within its frozen member whitelist and all T3 static checks are Green | T3-O01 present; T3-F01 absent; LO3 absent | `5/6,2/3` | `RequestExactHumanConfirmationForLOCERG3` |
| `T3-RT02` | The single repair cannot become Green in its one Task, discovers another cause, or expands scope | T3-F01 present; T3-O01/LO3 absent | `5/6,2/3` | `RunCERGT4ForRepairFailure` |
| `LO3-RT00` | Confirmed sole Unity revalidation begins | LO3-A01 present; LO3-D01 absent or partial; LO3-R01 absent | `5/6,3/3` | `FinishSameAttemptOrTreatAsFailedRevalidation` |
| `LO3-RT01` | Complete revalidation proves every A-F criterion Green | LO3-A01+complete LO3-D01+LO3-R01=`AllGreen` | `5/6,3/3` | `RunCERGT4ForEverythingNormal` |
| `LO3-RT02` | Any criterion fails, evidence is incomplete, invocation is interrupted, or valid AllGreen R01 is absent | Exact retained LO3-A01/D01/R01 state; no retry | `5/6,3/3` | `RunCERGT4ForUnityValidationFailure` |
| `T4-FT01` | T4 consumes LO1-F01 | `ProjectFailed/PreflightExhausted` | `4/6,0/3` | `StopCERG` |
| `T4-FT02` | T4 consumes Unresolved LO1-R01 or interrupted LO1-A01 | `ProjectFailed/LOCERG1Unresolved` or `LOCERG1Interrupted` | `4/6,1/3` | `StopCERG` |
| `T4-FT03` | T4 consumes T2 failure or LO2-RT03 | `ProjectFailed/T2ClosureFailed` or `UnityValidationFailed` | `5/6`, actual LO count | `StopCERG` |
| `T4-FT04` | T4 consumes T3-F01 or LO3-RT02 | `ProjectFailed/RepairFailed` or `UnityRevalidationFailed` | `6/6`, actual LO count | `StopCERG` |
| `T4-FT05` | T4 consumes valid AllGreen LO2-R01 or LO3-R01 and all A-F evidence is independently accepted | `EverythingNormal/AllCriteriaGreen` | `5/6,2/3` or `6/6,3/3` | `StopCERG` |

T1A-FT03 preserves the tool commit but grants no T1B or other downstream authority. No recovery is automatic. Total control may separately authorize at most one `SameHeadTO01PublicationRecovery` continuation, which consumes no additional ordinary Task or LO and keeps counters `2/6,0/3`, only when TO01 is absent, the checked-out HEAD equals the exact retained post-tool-commit HEAD, and all three tool bytes still match that commit. The confirmation binds the observed TOT01 state and may authorize removal/recreation of TOT01 only; it may not delete, replace, or overwrite TO01. The recovery may only rerun the same ten fixtures in their frozen order and publish Green TO01 through TOT01; it may not modify tools or any tracked byte, create a commit, read C1/FFS/candidate evidence, or create T01/O01/preflight/LO artifacts. Success reaches T1A-FT02 and still stops for audit. Failure remains T1A-FT03 and no second recovery exists. If any TO01 bytes already exist but are invalid, same-HEAD recovery is denied because TO01 is never overwritten; only total-control contract correction may decide that state. T1A-FT04 has no recovery or rerun authority under this contract.

T3-O01 has exactly `schemaVersion`, `artifactId`, `t2ContractSha256`, `lo2ResultSha256`, `approvedCause`, `modifiedMembers`, `staticChecks`, `status`, `nextAction`. `approvedCause={causeId,causeKind,evidenceRefIds,repairableMemberPaths}` has one cause and a nonempty exact whitelist. `modifiedMembers={portableRelativePath,beforeSha256,afterSha256}` equals that whitelist exactly; `staticChecks={checkId,status,evidenceRefIds}` is complete and all Green. Fixed status/action are `AppliedAndStaticGreen` and `RequestExactHumanConfirmationForLOCERG3`. T3-F01 has the same upstream/cause identity plus `failureReason`, `modifiedMemberState`, `status=RepairFailed`, and `nextAction=RunCERGT4ForRepairFailure`; it cannot authorize LO3.

LO3-R01 has exactly `schemaVersion`, `artifactId`, `t2ContractSha256`, `lo2ResultSha256`, `t3RepairSha256`, `attemptStateSha256`, `attemptCount`, `status`, `criteriaResults`, `logMembers`, `actionResults`, `captureMembers`, `failures`, `nextAction`. `attemptCount=1`; every array uses the complete identity-bearing schema frozen by T2 for LO2 and repeats the full A-F matrix, not only the repaired symptom. AllGreen requires every criterion/action/FX/log/capture predicate Green, `failures=[]`, and `nextAction=RunCERGT4ForEverythingNormal`; otherwise status is Failed and next action is `RunCERGT4ForUnityValidationFailure`. Missing R01 after A01 is equivalent to Failed and never authorizes another attempt.

T4-O01 has exactly `schemaVersion`, `artifactId`, `contractHeadCommit`, `terminalResult`, `terminalCause`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `upstreamArtifactRefs`, `evidenceRefIds`, `claimScope`, `nextAction`; schema/ID are `cerg-terminal-result/1.1.0`/`CERG-T4-O01`. `upstreamArtifactRefs={artifactId,portableRelativePath,byteCount,sha256}` sorts by artifactId; `evidenceRefIds` is a nonempty sorted duplicate-free set resolving in those artifacts. Refs equal the exact triggering transition artifacts. `ordinaryTaskBudget=6` and `LOBudget=3` always; the normal no-repair terminal is `ordinaryTaskUsed=5`, the repair-path terminal is `ordinaryTaskUsed=6`, and early terminals use exactly the counter in their T4 transition row. `terminalCause` is `PreflightExhausted`, `LOCERG1Unresolved`, `LOCERG1Interrupted`, `T2ClosureFailed`, `UnityValidationFailed`, `RepairFailed`, `UnityRevalidationFailed`, or `AllCriteriaGreen`; ProjectFailed scope is `ThisFixedRouteDidNotProveSuccess_NotIntrinsicAssetImpossibility`, EverythingNormal scope is `AllCERGHardCriteriaProven`, and next action is always `StopCERG`. No transition uses “may”; a failed gate produces zero downstream-consumable artifacts.

#### Fixed v2.2 counterexamples and authorization stop

| Case | Counterexample | Required result |
|---|---|---|
| `V22-DR01` | I03 flattens the singleton row to produce `a5d3e9da…`, I04 uses culture sorting to produce `6946c5de…`, either uses a root-relative path, or weapons SHA is not the frozen 64 hex | T1B-FT01; O01 absent; only `8e9defe8…`/`df205c3b…` are valid |
| `V22-DR02` | A true source root/parent/glob/recursive selector reaches any tool, AssetRipper receives anything except SD01, a SourceMember/staging row is absent/repeated, or source maxFiles/maxBytes differ from `17/116642804` | LO1-PF02 before LO, or Unresolved R01 after A01; never Closed |
| `V22-DR03` | A Passed lock lacks any of the seven baseline subjects/edges/direct evidence rows | T1B-FT01; O01 absent |
| `V22-DR04` | One obligation is omitted/repeated or is referenced by zero/multiple operations | LO1-PF02; F01 only |
| `V22-DR05` | R01 marks eleven IDs Resolved but omits SI01/staging conservation, graph rows, authority locators, origin conservation, or graph fingerprint | R01 invalid; LO1-RT03; then T4-FT02 |
| `V22-DR06` | A BlendTree branch omits ordinal/parameter value/threshold/position/direct parameter or fails to terminate in a Clip | R01 Unresolved; T4-FT02 |
| `V22-DR07` | FX component count is present but nested FXObjects, Renderer/ParticleSystem/TrailRenderer, property paths, or typed references are absent | R01 Unresolved; T4-FT02 |
| `V22-DR08` | `NoEffectExpected` is based on missing observation or a nonexhaustive/stale scope | ProvenAbsent invalid; R01 Unresolved; T4-FT02 |
| `V22-DR09` | A01 exists, D01 is partial or absent, and no valid R01 exists | LO1-RT03 exactly; no retry; T4-FT02 |
| `V22-DR10` | Null/empty/missing/unknown, duplicate/misorder, stale hash, or simultaneous partition equations disagree | Producing gate fails; no consumable downstream artifact |
| `V22-DR11` | Green TO01 has an empty/uncommitted/stale tool row or a non-post-commit HEAD; or Failed TO01 has any tool row, a non-starting HEAD, fewer than ten test rows, `Skipped`/`NotRun`, or an empty prerequisite-failure locator | The claimed TO01 state is invalid. T1A-FT01 may publish only the canonical Failed vector with rolled-back tools, `toolRows=[]`, ten Passed/Failed rows, starting HEAD, and no T1B/O01/preflight authority |
| `V22-DR12` | Either historical partial Measure script or producer exit=0 is offered instead of TG02 plus a complete recomputable R01 graph | Tooling test `PartialDiagnosticReject` fails or R01 is Unresolved/invalid; never Closed |
| `V22-DR13` | Copy/hash/export/producer is cancelled or interrupted after A01 with any partial Input/Work/Output state and no valid R01 | Preserve the exact five-tree/file state under LO1-RT03; no retry; T4-FT02 |
| `V22-DR14` | Historical invalid T1-v1 or invalid T4 is counted, causing T1A to report `3/6` or T1B to report `4/6` | Counter conservation fails; T1A must report `2/6` and T1B `3/6` |
| `V22-DR15` | LO2 has exactly one approved bounded cause but executor skips T3/LO3 and declares ProjectFailed | Reject transition; only LO2-RT02→T3-RT01→LO3 is legal |
| `V22-DR16` | LO2 exposes two causes, or T3 discovers a second cause, and executor repairs both or starts another Unity run | Direct T4 ProjectFailed; no scope expansion or fourth LO |
| `V22-DR17` | LO3 validates only the repaired symptom instead of replaying the complete A-F/action/FX matrix | LO3-R01 invalid/Failed; T4-FT04 |
| `V22-DR18` | Green TO01 is used to start candidate review before total control approves its exact SHA/HEAD, or T1A reads C1/FFS or creates T01/O01 | T1A has violated its boundary; T01 rolled back/O01 absent; return to audit and do not infer candidate outcome |
| `V22-DR19` | One ordinary Task implements/tests TG01-TG03 and also evaluates the candidate or publishes O01 | Invalid Task aggregation; T1A must stop at TO01 and separately authorized T1B alone may publish O01 |
| `V22-DR20` | TG01-TG03 commit succeeds, but TOT01/TO01 publication is interrupted, TO01 is missing, or final TO01 bytes fail validation | T1A-FT03=`ToolCommitPresentButTO01Unavailable`; preserve the exact tool commit and observed temp/final bytes, deny T1B, and return to total control; never fabricate Failed TO01 or roll back the committed tools |
| `V22-DR21` | TO01 tool rows or test rows are reordered; failures are strings, use an unknown reasonCode, are unsorted/duplicate, omit a required field/null, or have a non-recomputing failureId | TO01 is noncanonical and non-consumable; Green cannot authorize T1B, and a pre-commit Failed attempt must use T1A-FT01 or FT04 according to publication state |
| `V22-DR22` | Same-head recovery changes a tool, uses another HEAD, reads candidate evidence, overwrites an existing invalid TO01, skips/reorders a fixture, or is attempted twice | Recovery denied or remains T1A-FT03; committed tools are preserved, T1B/O01/preflight remain absent, and total control is the only next authority |

This docs-only TO03 registration authorizes no TG02/TG03 implementation, TO03 publication, T1B, candidate evidence read, T01/O01, preflight, source read, AssetRipper, Unity, or LO. The sole next action is `AwaitTotalControlAuditBeforeCERGT1A3`.

### Historical superseded CERG-T1-v2.1 central contract

Everything in this v2.1 section is retained only as `SupersededHistoricalText`. Its erroneous member SHA/order/fingerprints and incomplete graph/preflight/result rules are non-executable and cannot authorize or validate any artifact.

### Rebuilt CERG-T1-v2.1 central contract

Historical status: this section formerly declared itself the sole executable CERG-T1 contract. V2.2 now supersedes that declaration and every rule below; the text is retained only to audit the prior design and grants no authority.

#### V2.1 Artifact Registry

| ID | Exact path or byte range | Shape and role | Success/failure vector |
|---|---|---|---|
| `T1V21-I01` | Normative roadmap bytes from this CERG override heading through the byte immediately before the historical FFS heading | Direct UTF-8 contract input | Required; raw-byte SHA-256 |
| `T1V21-I02` | Mirror roadmap over the identical heading-bounded range | Direct mirror input | Required and byte-identical to I01 |
| `T1V21-I03` | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` | Read-only complete-file identity plus only `sources[*].{sourceId,sourceKind,rootFingerprint}` and `files[*].{sourceId,relativePath,sizeBytes,sha256,containerKind}` projections | Missing/stale/malformed projection suppresses T1V21-O01 |
| `T1V21-I04` | `Extracted/FastFeasibilitySpike/LO-FFS1` | Read-only recursive file identities plus the eight fixed baseline evidence members and their safe Unity GUID/YAML relationship locators below | Mutation or missing baseline member suppresses T1V21-O01 |
| `T1V21-H01` | `Extracted/CERG/SingleCharacter/T1/candidate-lock.json` | Historical v1 artifact, exactly `7767` bytes and SHA-256 `5d71f0f8c3dbde8038076b49a944b5c58f4883ef4b65865129be50f69406bdff` | Immutable, non-consumable, never overwritten |
| `T1V21-T01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json.tmp` | Temporary canonical T1V21-O01 bytes | Must be absent initially; atomically installed or same-Task rolled back |
| `T1V21-O01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json` | Schema `cerg-t1-candidate-lock/2.1.0`; sole Passed candidate lock | Never overwritten; malformed/failed execution produces no file |
| `LO1-PT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json.tmp` | Private temporary preflight bytes | Same-preflight atomic install or rollback |
| `LO1-P01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json` | Schema `cerg-lo-cerg1-preflight/1.1.0`; Green-only private preflight | Created only when every check and conservation formula is Green |
| `LO1-F01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight-failure.json` | Schema `cerg-lo-cerg1-preflight-failure/1.0.0`; non-consumable bounded-preflight failure | Created exactly when the one preflight attempt is exhausted; LO1-P01/LO1-R01 absent |
| `LO1-D01` | `Extracted/CERG/SingleCharacter/LO-CERG1/Output` | Candidate-scoped extracted/staged output tree; every recursive member is inventoried by LO1-R01 | Absent before confirmation; never a valid downstream input without Closed LO1-R01 |
| `LO1-R01` | `Extracted/CERG/SingleCharacter/LO-CERG1/lo-result.json` | Schema `cerg-lo-cerg1-result/1.0.0`; one-attempt obligation/result manifest | `Closed` authorizes T2; `Unresolved` is non-consumable and routes only to T4 |
| `T4-T01` | `Extracted/CERG/SingleCharacter/T4/terminal-result.json.tmp` | Temporary canonical T4-O01 bytes | Same-Task atomic install or rollback |
| `T4-O01` | `Extracted/CERG/SingleCharacter/T4/terminal-result.json` | Schema `cerg-terminal-result/1.0.0`; sole CERG terminal record | Exactly one immutable `EverythingNormal` or `ProjectFailed` record |

There are no other T1-v2.1, preflight, LO-CERG1 result, or early-terminal artifacts. T1-v2.1 remains manual direct-evidence review: no producer, validator, schema file, fixture, mutation matrix, or diagnostic output is authorized.

#### Canonical bytes, identities, and input fingerprints

- `CJ(x)` is JSON encoded as UTF-8 without BOM, with NFC strings, exact declared field order, no insignificant whitespace or trailing newline, lowercase hexadecimal hashes, and required JSON escaping only. Integers are base-10 JSON integers. Missing, JSON `null`, empty string, empty array, and zero are distinct; unknown fields and unknown enum values are invalid. Identity strings forbid U+0000.
- Sets are encoded as duplicate-free JSON arrays sorted by the declared Ordinal keys; lists preserve declared order. Array length is represented by the JSON array itself. No separator exists outside JSON syntax.
- Every structured digest is lowercase `sha256(CJ([domainTag,payload]))`; the ASCII domain/version tag is the first array element. Raw-byte hashes are used only where explicitly stated.
- `memberId="C1F-"+sha256(CJ(["cerg-t1v2/member-id/1",sourceId,portableRelativePath,sizeBytes,sha256,containerKind,memberClass]))`.
- `evidenceId="EVI-"+sha256(CJ(["cerg-t1v2/evidence-id/1",inputArtifactId,evidenceClass,portableRelativePath,byteCount,sha256,locatorKind,locator]))`.
- `subjectId="SUB-"+sha256(CJ(["cerg-t1v2/subject-id/1",candidateId,subjectKind,authorityIdentity]))`.
- `relationshipId="REL-"+sha256(CJ(["cerg-t1v2/relationship-id/1",candidateId,ownerSubjectId,relationshipKind,targetIdentity,evidenceState,obligationId]))`.
- `obligationId="OBL-"+sha256(CJ(["cerg-t1v2/obligation-id/1",candidateId,obligationKind,ownerIdentity,sortedAllowedMemberRefIds,sortedRequiredRelationshipKinds,sortedRequiredSubjectKinds]))`.
- `operationId="OP-"+sha256(CJ(["cerg-lo1/operation-id/1",sortedObligationRefIds,toolId,toolVersion,toolExecutableSha256,sortedInputMemberRefIds,argumentTokens,sortedExpectedSubjectKinds,sortedExpectedRelationshipKinds,maxFilesRead,maxBytesRead,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,outputPortableRelativePath,allowedChildProcessCount]))`.
- `failureId="FAIL-"+sha256(CJ(["cerg/failure-id/1",transitionId,upstreamArtifactSha256,reasonCode]))`.
- `memberSetFingerprint=sha256(CJ(["cerg-t1v2/input-member-set/1",sorted [[portableRelativePath,byteCount,sha256],...]]))`. Input member tuples sort Ordinal by portableRelativePath; candidate lexical/source tuples sort Ordinal by `(sourceId,path)`; baseline tuples sort Ordinal by fullPortablePath. I01 and I02 each use their one heading-bounded byte-range tuple; I03 uses its one complete-ledger-file tuple; I04 uses every recursive file tuple under LO-FFS1.
- `inputArtifacts.sha256` is the raw heading-range hash for I01/I02, the raw complete-file hash for I03, and exactly `memberSetFingerprint` for directory input I04. I01/I02/I03 have `memberCount=1`; I04 has its recursive member count. Every `inputArtifacts.memberSetFingerprint` uses the domain-tagged formula above.
- T1V21-O01 freshness requires the same HEAD, equal I01/I02 hashes, all I01-I04 raw/set hashes, the candidate member fingerprint, and baseline evidence fingerprint. Any change suppresses consumption and requires new authorization; no artifact is refreshed in place.

#### Deterministic C1 candidate partition

The C1 lexical predicate is exactly: `sourceId == "pc-install"` and either (a) `containerKind == "UnityBundle"` with `relativePath` matching the case-sensitive regex `^(Persistent_Store/AssetBundles|xtlr_Data/StreamingAssets/InstallResource)/char_14401(?:_[a-z0-9_]+)?\.unity3d$`, or (b) `relativePath == "Persistent_Store/SoundBanks/Japanese/Character_14401.bnk"`. The fingerprint disposition is exactly `Included3D` for branch (a) and `ExcludedAudio` for branch (b). This yields exactly `candidateLexicalCount=18`, `candidateLexicalBytes=118064722`, and `candidateLexicalSetFingerprint=f7e2a814f5ee64e9515f7a653319f092fd24941025f3d932aa07c0e0846867bb` under `sha256(CJ(["cerg-t1v2/candidate-lexical-set/1", sorted [sourceId,path,sizeBytes,sha256,containerKind,disposition] rows]))`.

The sole audio row is represented once in `excludedSourceMembers` with `exclusionReason=AudioOutsideCERG`: `pc-install|Persistent_Store/SoundBanks/Japanese/Character_14401.bnk|1421918|2515da864ba6364c1344546f5fead95fdba21f52ede1e45d75a2e918ac83b6df|AudioMetadata`. Any basename `char_2d_14401.unity3d` is excluded by the predicate and is never a SourceMember. Thus `CandidateLexicalRows = SourceMembers ⊎ ExcludedSourceMembers`, `18=17+1`, and 2D/audio can never enter LO-CERG1 input.

T1V21-O01 `sourceMembers` must equal these seventeen tuples exactly, with no omission, addition, reclassification, or duplicate:

| Portable relative path | Bytes | SHA-256 | Class |
|---|---:|---|---|
| `Persistent_Store/AssetBundles/char_14401_animations.unity3d` | 37819874 | `8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d` | Animation |
| `Persistent_Store/AssetBundles/char_14401_fx.unity3d` | 1944422 | `02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab` | FX |
| `Persistent_Store/AssetBundles/char_14401_models.unity3d` | 3080984 | `66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7` | Model |
| `Persistent_Store/AssetBundles/char_14401_timeline.unity3d` | 4341943 | `22cafed7bb84fec59a0b2f4ccf0687ff9434ad38e7a21de9041ca313565d0228` | Timeline |
| `Persistent_Store/AssetBundles/char_14401.unity3d` | 259486 | `c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b` | OtherCandidateDependency |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d` | 54450761 | `cd46d53c25efc4a730029039d2cb5fc24c610056f736b8e5feec148cfd5db83c` | Animation |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d` | 3573 | `72786cf23ad38898e5fee639412bec7ea59b2e9236e4ec622ace2c1ca1707605` | OtherCandidateDependency |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d` | 27721 | `57faf217acb60502b9f955d949438f832bfc3d94337ad7253eb7723495c8dcb5` | Combo |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d` | 35045 | `341f48a8082fd80ba153d0918379e1ab9dcd895938a7c50fd284858684dcc4aa` | Combo |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d` | 3956 | `de1aa4e4f2f2de24f8ab5994c8be5bfd0f2fc903888c3168159fd2531c2a5397` | OtherCandidateDependency |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d` | 1997681 | `14f0046fa7397d07c73f2994c3fb53abb649e140bf38592e899005c3033de3bc` | FX |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d` | 6660 | `8128c13e92c8e1db8c9fe242b11d748c96953d73df24a91650cf38c9eba61e21` | Material |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d` | 3078427 | `8c16df97fd2facbcc6ee94b5b46d5d4ebe46ec2948b3a2453684f3ac5a249427` | Model |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d` | 4909859 | `cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd` | Texture |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d` | 4402166 | `63c240049add3dbc0511827c66b36aab32a369fffc8b6f8bb17b23b34af1b6a6` | Timeline |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d` | 11641 | `0dde241f4a63641dd8e1014a6accd14debefcc725e1ba294e5c96ac94048` | Weapon |
| `xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d` | 268605 | `0ba4bb19cbd6aa934e77517aee55df98be6601da8fb2ac7f65c27015ded049e7` | OtherCandidateDependency |

Every row has `sourceId=pc-install` and `containerKind=UnityBundle`. The fixed included set has `candidateSourceMemberCount=17`, `candidateSourceMemberBytes=116642804`, and `candidateSourceMemberSetFingerprint=b78a51a1fff1cf22b9ba13f84f6ed2d47c9233195968f482ac024d1fa83eb922`, computed as `sha256(CJ(["cerg-t1v2/candidate-source-member-set/1", sorted [sourceId,path,sizeBytes,sha256,containerKind,memberClass] rows]))`.

#### Mandatory structural baseline and Subject/Partition Registry

The baseline evidence set is exactly eight immutable LO-FFS1 members under `Extracted/FastFeasibilitySpike/LO-FFS1/Export/CharacterEnvironment/ExportedProject/Assets/assetbundles/actor/character/14401/`:

| Suffix | Bytes | SHA-256 |
|---|---:|---|
| `animations/144_Attack.anim` | 33178294 | `a85a80965ff5836354bb2856f8bf7b2aead9da01fe33458dc253d7ea6f625dfc` |
| `animations/144_Attack.anim.meta` | 249 | `4a32d200a2547455bea1c606db53314fef08ba39011c3b057a8afb23f0983099` |
| `models/14401.prefab` | 355383 | `3fdc57bf91c18ab84457d2cb9df5b2409c0dd2148227c38f9ac70c3261c7d9b8` |
| `models/14401.prefab.meta` | 308 | `7463d2fc4fda69280da2635ade2473fee159b3b464d6ff9c6a3783f95d951f10` |
| `models/14401Avatar.asset` | 171334 | `ca0eec8927df86df5cf5292a9bf5350b28ca67777a76ad7884f97c35de0fa6db` |
| `models/14401Avatar.asset.meta` | 245 | `c28cbb20080b4140ec2982fbc46b3cabbbc8a38c9792eefd18414fd00b25950b` |
| `models/body.asset` | 1310667 | `c39b57e771dbe333a516b80b4a49e7eb63a2ded42156b47113cdeff5a71834e3` |
| `models/body.asset.meta` | 245 | `4c2fc644c1d1f68063cd3977abaa19266d467dfbc3c06b77f9648894aa8efb2d` |

Their full-path tuple set has `baselineEvidenceMemberCount=8`, `baselineEvidenceBytes=35016725`, and `baselineEvidenceSetFingerprint=0e1e9825f7fe942fbbaeb7b558e3d70d638d62b09e6e27b0b5f9a6a34b0a360f` under `sha256(CJ(["cerg-t1v2/baseline-evidence-set/1", sorted [fullPortablePath,byteCount,sha256] rows]))`.

A Passed T1V21-O01 contains these seven exact mandatory KnownSubjects, in addition to any directly evidenced optional subjects:

| Kind | Exact authorityIdentity |
|---|---|
| CandidateFamilyAnchor | `PortableFamilyKey:char_14401` |
| Model | `UnityGuid:a99d9cb8935099d4db6bde95d5ddf839` |
| SkinnedMesh | `YamlObject:a99d9cb8935099d4db6bde95d5ddf839:137041608817324026` |
| Mesh | `UnityGuid:8ad84e37c5826394f9d018c69933e209` |
| Skeleton | `SkeletonBinding:a99d9cb8935099d4db6bde95d5ddf839:137041608817324026:4904400124545405` |
| Avatar | `UnityGuid:1031627e0cce26240a72299bc74e2939` |
| ActionClip | `UnityGuid:16b6b13783e73d648a6faff48a4e3361` |

The mandatory ProvenPresent relationship set is exactly: `AnchorOwnsModel`, `ModelContainsSkinnedMesh`, `SkinnedMeshUsesMesh`, `SkinnedMeshUsesSkeleton`, `AvatarUsesSkeleton`, `AnchorOwnsActionClip`, and `ActionClipBindsSkeleton`. The last relationship requires a direct serialized locator proving the selected clip's complete non-empty binding-path set resolves inside the selected model skeleton transform-path set; a shared filename is invalid evidence. Every mandatory subject and relationship has non-empty `evidenceRefIds`; their union is exactly `candidate.baselineEvidenceRefIds` and contains all eight fixed WholeFileIdentity rows plus the UnityGuid/YamlObjectPath locators needed for the seven relationships. Independently, `candidate.baselineEvidenceSetFingerprint` is exactly the fixed eight-member raw-file tuple fingerprint above. Anchor-only, missing-kind, disconnected, or prose-only baseline output is invalid and suppressed.

The Subject Registry row shapes are:

- `EvidenceItem={evidenceId,inputArtifactId,evidenceClass,portableRelativePath,byteCount,sha256,locatorKind,locator}`; permitted pairs are `C1SourceProjection/C1SourceId`, `C1FileProjection/C1FileTuple`, `LOFFS1WholeFile/WholeFileIdentity`, `UnityMeta/UnityGuidRecord`, and `SerializedRelationship/YamlObjectPath`.
- `SourceRoot={sourceId,sourceKind,rootFingerprint,evidenceRefIds}`; only `pc-install` is referenced by SourceMembers.
- `SourceMember={memberId,candidateId,sourceId,portableRelativePath,sizeBytes,sha256,containerKind,memberClass,evidenceRefIds}`; rows equal the fixed seventeen-row table.
- `ExcludedSourceMember={sourceId,portableRelativePath,sizeBytes,sha256,containerKind,exclusionReason,evidenceRefIds}`; exactly the one BNK row exists.
- `KnownSubject={subjectId,candidateId,subjectKind,authorityIdentity,memberRefIds,evidenceRefIds}`; kinds are `CandidateFamilyAnchor`, `Model`, `Mesh`, `SkinnedMesh`, `Skeleton`, `Avatar`, `Controller`, `StateMachine`, `State`, `Motion`, `BlendTree`, `ActionClip`, `AnimationEvent`, `AttackAction`, `FXPrefab`, `FXComponent`, `Material`, `Texture`, `Shader`, `Weapon`, `Combo`, or `Timeline`.
- `Relationship={relationshipId,candidateId,ownerSubjectId,relationshipKind,targetIdentity,evidenceState,evidenceRefIds,obligationId}`; state is `ProvenPresent`, `ProvenAbsent`, `EvidenceUnavailableBeforeExtraction`, or `Contradictory`. `relationshipKind` is closed to `AnchorOwnsModel`, `ModelContainsSkinnedMesh`, `SkinnedMeshUsesMesh`, `SkinnedMeshUsesSkeleton`, `AvatarUsesSkeleton`, `AnchorOwnsActionClip`, `ActionClipBindsSkeleton`, `ControllerToStateMachine`, `StateMachineToState`, `StateToNestedStateMachine`, `StateToMotion`, `BlendTreeToChildMotion`, `BlendTreeParameterBranchToLeafClip`, `OverrideSourceToReplacementClip`, `ActionToAnimationEvent`, `AttackActionToFXTrigger`, `FXTriggerToPrefab`, `FXPrefabToSerializedComponent`, `FXComponentToAssetReference`, `RendererToMaterial`, `MaterialToTexture`, `MaterialToShader`, `TimelineToAction`, `WeaponToAction`, `ComboToAction`, or `SerializedObjectReference`. An unavailable target is exactly `Unresolved:<obligationKind>`.
- `DiscoveryObligation={obligationId,candidateId,obligationKind,ownerIdentity,allowedMemberRefIds,requiredRelationshipKinds,requiredSubjectKinds,successDisposition,failureDisposition}`; member/kind arrays are non-empty, sorted, duplicate-free, and candidate-local.

A Passed lock has exactly one obligation for each of these eleven kinds: `ResolveBaseController`, `EnumerateControllerGraph`, `EnumerateOverrideMap`, `EnumerateCompleteActionUniverse`, `EnumerateAnimationEvents`, `ResolveAttackFXTriggers`, `EnumerateFXPrefabComponents`, `ResolveRendererMaterialTextureShader`, `ResolveSkeletonAvatar`, `ResolveTimelineWeaponsCombos`, and `ResolveReferencedDependencies`. Thus `discoveryObligationCount=11`; each maps one-to-one onto one `EvidenceUnavailableBeforeExtraction` relationship and every allowed member is one of the fixed seventeen SourceMembers. The `deadbeef` Controller reference is owned by `ResolveBaseController`, never by absence or rejection.

Partitions are mutually exclusive and exhaustive: `CandidateLexicalRows=SourceMembers ⊎ ExcludedSourceMembers`; evidence items partition by evidenceClass; KnownSubjects partition by subjectKind; relationships partition by evidenceState; and obligations partition by obligationKind. Required conservation includes `18=17+1`, `sourceMemberBytes+excludedSourceMemberBytes=118064722`, `knownSubjectCount=sum(subjectKindCounts)`, `relationshipCount=sum(evidenceStateCounts)`, and `discoveryObligationCount=EvidenceUnavailableBeforeExtractionCount=11`.

#### Complete T1V21-O01 shape and Passed rule

T1V21-O01 has exactly these mandatory top-level fields in order: `schemaVersion`, `artifactId`, `contractHeadCommit`, `normativeOverrideSha256`, `mirrorOverrideSha256`, `status`, `consumableForLoCerg1Preflight`, `selectedCandidateId`, `priorInvalidation`, `inputArtifacts`, `evidenceItems`, `candidate`, `sourceRoots`, `sourceMembers`, `excludedSourceMembers`, `knownSubjects`, `relationships`, `discoveryObligations`, `partitions`, `failures`, `summary`, `nextAction`.

- Fixed values are `schemaVersion=cerg-t1-candidate-lock/2.1.0`, `artifactId=CERG-T1V21-O01`, `status=Passed`, `consumableForLoCerg1Preflight=true`, `selectedCandidateId=char_14401`, `failures=[]`, and `nextAction=PrepareLOCERG1PreflightThenRequestExactHumanConfirmation`.
- `priorInvalidation={historicalArtifactId,portableRelativePath,byteCount,sha256,disposition,consumed,terminal}` freezes H01 with `InvalidatedByContractDefect,false,false`.
- `inputArtifacts={artifactId,portableRelativePath,byteCount,sha256,memberCount,memberSetFingerprint}` covers I01-I04 exactly once.
- `candidate={candidateId,comparisonOrdinal,familyIdentityKind,familyIdentityValue,disposition,memberRefIds,candidateLexicalCount,candidateLexicalBytes,candidateLexicalSetFingerprint,candidateSourceMemberCount,candidateSourceMemberBytes,candidateSourceMemberSetFingerprint,baselineEvidenceRefIds,baselineEvidenceMemberCount,baselineEvidenceBytes,baselineEvidenceSetFingerprint,rejectionFailureIds}`; fixed values are `comparisonOrdinal=1`, `PortableFamilyKey`, `char_14401`, `Locked`, exact fingerprints/counts above, and `rejectionFailureIds=[]`.
- `partitions={evidenceClassCounts,memberClassCounts,subjectKindCounts,evidenceStateCounts,obligationKindCounts,evidenceItemCount,sourceRootCount,sourceMemberCount,excludedSourceMemberCount,knownSubjectCount,relationshipCount,discoveryObligationCount}`; all enum keys exist including zero.
- `summary={candidateCount,lockedCount,rejectedCount,evidenceItemCount,sourceRootCount,sourceMemberCount,excludedSourceMemberCount,knownSubjectCount,relationshipCount,discoveryObligationCount,failureCount}`; fixed values are `candidateCount=1`, `lockedCount=1`, `rejectedCount=0`, `sourceRootCount=1`, `sourceMemberCount=17`, `excludedSourceMemberCount=1`, `discoveryObligationCount=11`, and `failureCount=0`; the other three counts derive exactly from their arrays.
- Any tuple/fingerprint mismatch, missing mandatory baseline subject/relationship/evidence, missing/duplicate obligation kind, unsafe projection, contradiction, or failed conservation suppresses T1V21-O01 and authorizes no preflight. T1-v2.1 has no Failed candidate-lock artifact.

#### LO-CERG1 preflight-operation conservation

LO1-P01 has exactly: `schemaVersion`, `artifactId`, `candidateLockSha256`, `contractHeadCommit`, `selectedCandidateId`, `createdAt`, `sourceRootBindings`, `operations`, `aggregateLimits`, `outputRoot`, `status`, `nextAction`. Fixed values include `cerg-lo-cerg1-preflight/1.1.0`, `LO-CERG1-P01`, `char_14401`, `Green`, `Extracted/CERG/SingleCharacter/LO-CERG1/Output`, and `RequestExactHumanConfirmationForLOCERG1`.

- `sourceRootBindings={sourceId,privateAbsoluteReadOnlyRoot,rootFingerprint}` maps one-to-one to the candidate lock SourceRoots and never enters tracked content or conversation.
- `operations={operationId,obligationRefIds,toolId,toolVersion,privateToolExecutablePath,toolExecutableSha256,inputMemberRefIds,argumentTokens,workingDirectory,expectedSubjectKinds,expectedRelationshipKinds,maxFilesRead,maxBytesRead,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,outputPortableRelativePath,allowedChildProcessCount}`. Obligation/member/expected-kind arrays are non-empty, sorted, and duplicate-free; arguments preserve order; every max is positive and child-process count is non-negative.
- Let `D` be all eleven candidate-lock obligation IDs. The multiset concatenation of every `operations[*].obligationRefIds` must equal `D` exactly once: `D = ⊎ operations[*].obligationRefIds` and `|D| = Σ|operation.obligationRefIds| = 11`. Empty refs, omission, repetition, or unknown refs suppress Green.
- For each operation, `inputMemberRefIds` equals the set union of `allowedMemberRefIds` for its referenced obligations; expected subject/relationship kinds equal the corresponding unions. No input outside the fixed seventeen members is legal. Operation outputs are distinct descendant leaves of LO1-D01.
- `aggregateLimits={maxFilesRead,maxBytesRead,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes}` equals the operation sums. Green additionally requires exact member size/hash, exact tool path/version/SHA, expanded arguments, absent output/temp, and all conservation formulas. Exact confirmation binds the complete LO1-P01 SHA, operation IDs, limits, one-attempt/no-retry/cancellation/rollback rules.

LO1-F01 has exactly `schemaVersion`, `artifactId`, `candidateLockSha256`, `contractHeadCommit`, `selectedCandidateId`, `transitionId`, `failureId`, `reasonCode`, `preflightAttemptCount`, `LOAttemptCount`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `status`, `consumableForLoCerg1`, `nextAction`. Fixed failure values are `schemaVersion=cerg-lo-cerg1-preflight-failure/1.0.0`, `artifactId=LO-CERG1-F01`, `selectedCandidateId=char_14401`, `transitionId=LO1-PF02`, `preflightAttemptCount=1`, `LOAttemptCount=0`, `ordinaryTaskUsed=3`, `ordinaryTaskBudget=5`, `LOUsed=0`, `LOBudget=3`, `status=PreflightExhausted`, `consumableForLoCerg1=false`, and `nextAction=RunCERGT4ForPreflightExhaustion`. `reasonCode` is exactly `SourceBindingMismatch`, `ToolIdentityMismatch`, `OperationConservationFailure`, `LimitOrOutputInvalid`, or `PreexistingOutputState`. It contains no private path or unrestricted tool text.

LO1-R01 has exactly `schemaVersion`, `artifactId`, `candidateLockSha256`, `preflightSha256`, `attemptCount`, `status`, `resolvedObligationIds`, `unresolvedObligations`, `outputMembers`, `summary`, `nextAction`.

- Fixed values include `schemaVersion=cerg-lo-cerg1-result/1.0.0` and `artifactId=LO-CERG1-R01`; `status` is `Closed` or `Unresolved`.
- `resolvedObligationIds` and `unresolvedObligations` partition all eleven obligations exactly. An unresolved row is `{obligationId,reasonCode,evidenceRefIds}`, where `reasonCode` is `MissingDependency`, `ContradictoryDependency`, `ToolFailure`, `LimitExceeded`, or `OutputIntegrityFailure`. `outputMembers={portableRelativePath,byteCount,sha256,subjectKinds,obligationRefIds}` inventories every LO1-D01 file; both arrays are non-empty, sorted, and duplicate-free.
- `summary={obligationCount,resolvedCount,unresolvedCount,outputMemberCount,outputBytes,attemptCount,ordinaryTaskUsed,ordinaryTaskBudget,LOUsed,LOBudget}`; conservation is `11=resolvedCount+unresolvedCount`, with integer values `attemptCount=1`, `ordinaryTaskUsed=3`, `ordinaryTaskBudget=5`, `LOUsed=1`, and `LOBudget=3`.
- `Closed` requires `resolvedCount=11`, `unresolvedCount=0`, and `nextAction=RunCERGT2`. `Unresolved` requires at least one unresolved row, is non-consumable, and uses `nextAction=RunCERGT4ForLOCERG1Unresolved`.

T4-O01 has exactly `schemaVersion`, `artifactId`, `contractHeadCommit`, `terminalResult`, `terminalCause`, `ordinaryTaskUsed`, `ordinaryTaskBudget`, `LOUsed`, `LOBudget`, `upstreamArtifactRefs`, `evidenceRefIds`, `claimScope`, `nextAction`. Fixed identity values are `schemaVersion=cerg-terminal-result/1.0.0` and `artifactId=CERG-T4-O01`; every counter field is a JSON integer; `terminalResult` is `EverythingNormal` or `ProjectFailed`. `upstreamArtifactRefs` rows are exactly `{artifactId,portableRelativePath,byteCount,sha256}` sorted by artifactId; early failure contains exactly the triggering LO1-F01 or LO1-R01 row. `evidenceRefIds` is a sorted duplicate-free list of stable failure/evidence/obligation IDs from those referenced artifacts and is non-empty. `terminalCause` is `PreflightExhausted`, `LOCERG1Unresolved`, `T2ClosureFailed`, `UnityValidationFailed`, or `AllCriteriaGreen`; `claimScope` is exactly `ThisFixedRouteDidNotProveSuccess_NotIntrinsicAssetImpossibility` for ProjectFailed and `AllCERGHardCriteriaProven` for EverythingNormal; `nextAction=StopCERG`. Early preflight/LO1 terminal records use integers `ordinaryTaskUsed=4`, `ordinaryTaskBudget=5`, `LOBudget=3`, and respectively `LOUsed=0` or `1`; the successful Unity route reaches T4 with `ordinaryTaskUsed=5`.

#### V2.1 Failure Transition Table

| ID | Exact trigger | Artifact vector | Counters after trigger | Only next action |
|---|---|---|---|---|
| `T1V21-FT01` | An authorized T1-v2.1 execution reaches a contract/input/hash/selector/baseline/partition/safety/output-state failure | T1V21-T01 rolled back; T1V21-O01, LO1-P01/F01/R01 absent | `3/5,0/3` | `ReturnToTotalControlAuditForT1V21` |
| `T1V21-FT02` | Every v2.1 Passed predicate holds | Immutable T1V21-O01 only | `3/5,0/3` | `PrepareLOCERG1Preflight` |
| `LO1-PF01` | All preflight checks and obligation-operation conservation hold | LO1-P01 present; LO1-F01/R01 absent | `3/5,0/3` | `RequestExactHumanConfirmationForLOCERG1` |
| `LO1-PF02` | The single bounded preflight attempt cannot become Green | LO1-PT01 rolled back; LO1-P01/R01 absent; LO1-F01 present | `3/5,0/3` | `RunCERGT4ForPreflightExhaustion` |
| `LO1-RT01` | One authorized LO resolves all eleven obligations | LO1-D01 inventoried; LO1-R01=`Closed`; LO1-F01 absent | `3/5,1/3` | `RunCERGT2` |
| `LO1-RT02` | One authorized LO leaves one or more obligations unresolved/contradictory or violates closure | LO1-D01 retained for audit; LO1-R01=`Unresolved`; no consumable closure | `3/5,1/3` | `RunCERGT4ForLOCERG1Unresolved` |
| `T4-FT01` | T4 consumes valid LO1-F01 | T4-O01=`ProjectFailed/PreflightExhausted` | `4/5,0/3` | `StopCERG` |
| `T4-FT02` | T4 consumes Unresolved LO1-R01 | T4-O01=`ProjectFailed/LOCERG1Unresolved` | `4/5,1/3` | `StopCERG` |
| `T4-FT03` | Later T2/LO2 evidence fails a hard criterion | T4-O01=`ProjectFailed/T2ClosureFailed` or `UnityValidationFailed` | `5/5`, actual LO count | `StopCERG` |
| `T4-FT04` | All A-F criteria have complete evidence | T4-O01=`EverythingNormal/AllCriteriaGreen` | `5/5,2/3` | `StopCERG` |

A failed gate never creates a downstream-consumable artifact. Preflight failure consumes no LO attempt; LO1-R01 always consumes exactly one. The spare third LO budget remains unused because T3/LO-CERG3 are unreachable and unauthorized.

#### Fixed v2.1 counterexamples

| Case | Counterexample | Required result |
|---|---|---|
| `V21-DR01` | Executor selects a subset/superset of the seventeen tuples, includes the BNK, or includes any `char_2d_14401` bundle | T1V21-FT01; no candidate lock |
| `V21-DR02` | Counts are 17 but one size/hash/class differs, or the domain tag/fingerprint encoding differs | T1V21-FT01; no candidate lock |
| `V21-DR03` | Output contains only CandidateFamilyAnchor plus obligations | Missing mandatory baseline subjects/relations/evidence; T1V21-FT01 |
| `V21-DR04` | A mandatory subject exists but the seven ProvenPresent edges are disconnected, prose-only, or filename-derived | T1V21-FT01 |
| `V21-DR05` | One of eleven obligations is omitted, repeated, or referenced by zero operations | LO1-PF02; LO1-F01 only; LO denied |
| `V21-DR06` | All eleven IDs appear but an operation has empty refs, extra member, or expected-kind union mismatch | LO1-PF02; LO1-F01 only; LO denied |
| `V21-DR07` | Preflight cannot become Green | Exact LO1-F01 vector, then T4-FT01; never an in-memory indefinite state |
| `V21-DR08` | LO-CERG1 returns 10 resolved and 1 unresolved | LO1-R01 Unresolved with `11=10+1`, then T4-FT02 |
| `V21-DR09` | Historical v1 artifact/T4 or superseded v2.0 text is cited as current authority | Reject citation; `InvalidatedByContractDefect` remains non-terminal |
| `V21-DR10` | I01/I02 hash entire files, I03 hashes a projection, or I04 hashes raw concatenated bytes | Fingerprint mismatch under the frozen I01-I04 rules; T1V21-FT01 |

This docs-only correction authorizes no T1-v2.1 artifact, preflight, LO, T4, producer, or Unity execution. Its sole next action is `AwaitTotalControlAuditBeforeCERGT1V2`.

### Historical invalidated T1-v1 and superseded CERG-T1-v2.0 contract

#### Invalidated historical decision

- The immutable historical file `Extracted/CERG/SingleCharacter/T1/candidate-lock.json` remains preserved at `byteCount=7767`, `sha256=5d71f0f8c3dbde8038076b49a944b5c58f4883ef4b65865129be50f69406bdff`. It is `HistoricalT1V1Artifact`, is never deleted or overwritten, and is not consumable by any LO.
- The T4 conclusion derived from that file is `InvalidatedByContractDefect`, `consumed=false`, `terminal=false`, because T1-v1 required exact source leaves, tool SHA, arguments, and output limits while forbidding the C1 member projection and local preflight needed to produce them. Its `subjects=[]`, `relationships=[]`, and `loOperations=[]` therefore prove that no candidate was evaluated; they do not prove candidate failure.
- `InvalidatedByContractDefect` is a historical decision disposition, not a third CERG terminal result. It changes no asset fact, consumes no T4 Task, and cannot be cited as `ProjectFailed`. The only current counters are `ordinaryTaskUsed=2/5`, `LOUsed=0/3`.
- The unresolved OverrideController reference recorded as `deadbeef` is `EvidenceUnavailableBeforeExtraction`. It freezes a bounded `ResolveBaseController` discovery obligation; it is neither `ProvenAbsent` nor candidate-rejection evidence.

The following v2.0 definitions are superseded historical text. Only the earlier rebuilt v2.1 section is executable; nothing below this notice can authorize a candidate lock, preflight, LO, T4, overwrite, cleanup, or rerun.

#### T1-v2 Artifact Registry

| ID | Path or byte range | Required shape and role | Rule |
|---|---|---|---|
| `T1V2-I01` | Normative CERG override heading-bounded bytes | UTF-8 contract bytes and whole-byte SHA-256 | Required direct input |
| `T1V2-I02` | Mirror CERG override over the identical byte range | Byte-for-byte mirror of T1V2-I01 | Divergence suppresses all T1-v2 output |
| `T1V2-I03` | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` | Read-only C1 ledger. Permitted projection is `sources[*].{sourceId,sourceKind,rootFingerprint}` and candidate-related `files[*].{sourceId,relativePath,sizeBytes,sha256}` | No captured time, absolute/private root, object content, or unrestricted observation may be projected |
| `T1V2-I04` | `Extracted/FastFeasibilitySpike/LO-FFS1` | Read-only historical Mesh/Avatar/skeleton/clip and serialized relationship evidence, limited to the already-authorized safe metadata classes | Used to classify known relationships, never to assert unseen completeness |
| `T1V2-H01` | `Extracted/CERG/SingleCharacter/T1/candidate-lock.json` | Immutable v1 artifact with the exact identity frozen above | Historical-only; must remain byte-identical and is never an input authority for candidate rejection |
| `T1V2-T01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json.tmp` | Temporary canonical bytes with exactly the T1V2-O01 shape | Must be absent at start; never consumable; atomically renamed or rolled back in the same Task |
| `T1V2-O01` | `Extracted/CERG/SingleCharacter/T1-v2/candidate-lock.json` | Sole v2 candidate lock, schema `cerg-t1-candidate-lock/2.0.0` | Must be absent at start and never overwritten; only `Passed` may proceed to preflight |
| `LO1-PT01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json.tmp` | Machine-private temporary preflight bytes | Must be absent at start; rolled back if any preflight check is not Green |
| `LO1-P01` | `Extracted/CERG/SingleCharacter/LO-CERG1/preflight.json` | Machine-private, read-only preflight record, schema `cerg-lo-cerg1-preflight/1.0.0` | Not a T1-v2 output; created only by separate authorization immediately before confirmation and never committed or quoted with private paths |

No v2 candidate-lock producer, validator, schema file, fixture, mutation matrix, or diagnostic artifact is authorized. T1-v2 manually projects direct registered evidence into T1V2-O01, and total control reproduces the decision from the cited raw ledger/relationship locators. This contract correction creates none of the registered artifacts.

#### T1-v2 identity, Subject Registry, and partitions

- All hashes are lowercase SHA-256. Text is UTF-8 NFC and identity fields forbid U+0000. Portable paths use `/`, are relative, contain no scheme/root/`.`/`..` segment, and compare by ordinal UTF-8 byte order. Integers are base-10 JSON integers; JSON objects use the declared field order and arrays use the sort keys below. Identity tuples encode each declared field in order as UTF-8 text separated by one U+0000 byte. A member-set fingerprint sorts rows by portable path then hashes the concatenation of `portableRelativePath`, decimal `byteCount`, and lowercase `sha256` tuples; an empty member set is forbidden for a required input.
- `memberId = "C1F-" + sha256("C1File\0" + sourceId + "\0" + relativePath + "\0" + sizeBytes + "\0" + sha256)`. `subjectId = "SUB-" + sha256(candidateId + "\0" + subjectKind + "\0" + authorityIdentity)`. `relationshipId = "REL-" + sha256(ownerSubjectId + "\0" + relationshipKind + "\0" + targetIdentity)`. `obligationId = "OBL-" + sha256(candidateId + "\0" + obligationKind + "\0" + sortedMemberIds + "\0" + ownerIdentity)`, where `sortedMemberIds` is the ordinal-sorted member-ID list joined by U+0000.
- `CandidateFamily` has exactly one permitted identity in v2: `candidateId=char_14401`, `familyIdentityKind=PortableFamilyKey`, `familyIdentityValue=char_14401`. Candidate rotation is forbidden by this reopen correction.
- `EvidenceItem` rows have exactly `evidenceId`, `inputArtifactId`, `evidenceClass`, `portableRelativePath`, `byteCount`, `sha256`, `locatorKind`, `locator`. `evidenceClass`/`locatorKind` is closed to `C1SourceProjection/C1SourceId`, `C1FileProjection/C1FileTuple`, `LOFFS1WholeFile/WholeFileIdentity`, `UnityMeta/UnityGuidRecord`, or `SerializedRelationship/YamlObjectPath`. Each ID is `"EVI-" + sha256(inputArtifactId + "\0" + evidenceClass + "\0" + portableRelativePath + "\0" + locator)`; every reference resolves exactly once.
- `SourceRoot` rows have exactly `sourceId`, `sourceKind`, `rootFingerprint`, `evidenceRefIds`. `sourceKind` is `PcInstall`, `PcPatchOrCache`, `AndroidApk`, or `AndroidDataOrCache`; each row cites exactly one matching `C1SourceProjection/C1SourceId` evidence item and contains no private root path.
- `SourceMember` rows are exact C1 file projections with fields `memberId`, `candidateId`, `sourceId`, `portableRelativePath`, `sizeBytes`, `sha256`, `memberClass`, `evidenceRefIds`. `portableRelativePath` is the C1 `relativePath`; `memberClass` is exactly `Model`, `Animation`, `FX`, `Material`, `Texture`, `Timeline`, `Weapon`, `Combo`, `Controller`, or `OtherCandidateDependency`. The class and path only delimit inputs; neither proves semantic completeness. Each row cites exactly one matching `C1FileProjection/C1FileTuple` evidence item.
- `KnownSubject` rows have exactly `subjectId`, `candidateId`, `subjectKind`, `authorityIdentity`, `memberRefIds`, `evidenceRefIds`. `subjectKind` is `CandidateFamilyAnchor`, `Model`, `Mesh`, `SkinnedMesh`, `Skeleton`, `Avatar`, `Controller`, `StateMachine`, `State`, `Motion`, `BlendTree`, `ActionClip`, `AnimationEvent`, `AttackAction`, `FXPrefab`, `FXComponent`, `Material`, `Texture`, `Shader`, `Weapon`, `Combo`, or `Timeline`. Exactly one `CandidateFamilyAnchor` with `authorityIdentity=char_14401` is mandatory so an unavailable owner can be represented without inventing an asset identity.
- `Relationship` rows have exactly `relationshipId`, `candidateId`, `ownerSubjectId`, `relationshipKind`, `targetIdentity`, `evidenceState`, `evidenceRefIds`, `obligationId`. `evidenceState` is `ProvenPresent`, `ProvenAbsent`, `EvidenceUnavailableBeforeExtraction`, or `Contradictory`; `obligationId` is non-null exactly for `EvidenceUnavailableBeforeExtraction`. When the target is not yet identifiable, `targetIdentity` is exactly `Unresolved:<obligationKind>` and cannot be mistaken for an asset ID.
- `DiscoveryObligation` rows have exactly `obligationId`, `candidateId`, `obligationKind`, `ownerIdentity`, `allowedMemberRefIds`, `requiredRelationshipKinds`, `requiredSubjectKinds`, `successDisposition`, `failureDisposition`. `obligationKind` is `ResolveBaseController`, `EnumerateControllerGraph`, `EnumerateOverrideMap`, `EnumerateCompleteActionUniverse`, `EnumerateAnimationEvents`, `ResolveAttackFXTriggers`, `EnumerateFXPrefabComponents`, `ResolveRendererMaterialTextureShader`, `ResolveSkeletonAvatar`, `ResolveTimelineWeaponsCombos`, or `ResolveReferencedDependencies`. `successDisposition=ResolvedByLOCERG1`; `failureDisposition=UnresolvedForCERGT2`.
- `relationshipKind` is closed to `ModelToMesh`, `SkinnedMeshToSkeleton`, `SkeletonToAvatar`, `StateMachineToState`, `StateToMotion`, `StateToNestedStateMachine`, `BlendTreeToChildMotion`, `BlendTreeParameterBranchToLeafClip`, `ControllerToStateMachine`, `OverrideSourceToReplacementClip`, `ActionToAnimationEvent`, `AttackActionToFXTrigger`, `FXTriggerToPrefab`, `FXPrefabToSerializedComponent`, `FXComponentToAssetReference`, `RendererToMaterial`, `MaterialToTexture`, `MaterialToShader`, `TimelineToAction`, `WeaponToAction`, `ComboToAction`, or `SerializedObjectReference`.
- Partition conservation is mandatory: every evidence item belongs to exactly one evidence class; every SourceMember resolves to exactly one SourceRoot and belongs to exactly one `memberClass`; every known subject belongs to exactly one `subjectKind`; every relationship belongs to exactly one evidence state; every `EvidenceUnavailableBeforeExtraction` relationship maps one-to-one to one obligation; no other relationship maps to an obligation. `evidenceItemCount=sum(evidenceClassCounts)`, `sourceRootCount=count(sourceRoots)`, `candidateMemberCount=sum(memberClassCounts)`, `knownSubjectCount=sum(subjectKindCounts)`, `relationshipCount=sum(evidenceStateCounts)`, and `discoveryObligationCount=EvidenceUnavailableBeforeExtractionCount`.

Candidate-related C1 membership must be a finite, directly reviewed row set for `char_14401`. Exact path tokens or known authoritative references may locate rows for review, but filename/directory similarity cannot establish ownership or completeness. Every included row keeps its exact C1 path, byte count, and SHA; a source root, glob, directory, or unbounded search is never serialized as a SourceMember.

#### Complete T1V2-O01 shape and lock rule

T1V2-O01 has exactly these mandatory top-level fields in this order: `schemaVersion`, `artifactId`, `contractHeadCommit`, `normativeOverrideSha256`, `mirrorOverrideSha256`, `status`, `consumableForLoCerg1Preflight`, `selectedCandidateId`, `priorInvalidation`, `inputArtifacts`, `evidenceItems`, `candidate`, `sourceRoots`, `sourceMembers`, `knownSubjects`, `relationships`, `discoveryObligations`, `partitions`, `failures`, `summary`, `nextAction`.

- Fixed values are `schemaVersion=cerg-t1-candidate-lock/2.0.0`, `artifactId=CERG-T1V2-O01`, `status=Passed`, `consumableForLoCerg1Preflight=true`, and `selectedCandidateId=char_14401`. `contractHeadCommit` is 40 lowercase hex. Both override hashes are equal 64-character lowercase hex.
- `priorInvalidation` has exactly `historicalArtifactId`, `portableRelativePath`, `byteCount`, `sha256`, `disposition`, `consumed`, `terminal`; its fixed values are the T1V2-H01 identity above, `InvalidatedByContractDefect`, `false`, and `false`.
- `inputArtifacts` rows have exactly `artifactId`, `portableRelativePath`, `byteCount`, `sha256`, `memberCount`, `memberSetFingerprint`; rows cover T1V2-I01 through T1V2-I04 exactly once and are ordered by `artifactId`.
- `evidenceItems` uses the exact EvidenceItem shape above and sorts by `evidenceId`. `candidate` has exactly `candidateId`, `comparisonOrdinal`, `familyIdentityKind`, `familyIdentityValue`, `disposition`, `memberRefIds`, `baselineEvidenceRefIds`, `rejectionFailureIds`; v2 fixes `comparisonOrdinal=1`, `disposition=Locked`, and `rejectionFailureIds=[]`.
- `sourceRoots`, `sourceMembers`, `knownSubjects`, `relationships`, and `discoveryObligations` use the exact row shapes above and sort by `sourceId` or their primary ID. The candidate's `memberRefIds` equals the complete SourceMember ID set, and the SourceRoot set equals the distinct roots referenced by those members. `partitions` has exactly `evidenceClassCounts`, `memberClassCounts`, `subjectKindCounts`, `evidenceStateCounts`, `evidenceItemCount`, `sourceRootCount`, `candidateMemberCount`, `knownSubjectCount`, `relationshipCount`, `discoveryObligationCount`, with every enum key present including zero counts.
- `failures` rows have exactly `failureId`, `transitionId`, `ownerKind`, `ownerId`, `redactedReasonCode`, `evidenceRefIds`; a published Passed artifact fixes `failures=[]`. `summary` has exactly `candidateCount`, `lockedCount`, `rejectedCount`, `evidenceItemCount`, `sourceRootCount`, `sourceMemberCount`, `knownSubjectCount`, `relationshipCount`, `discoveryObligationCount`, `failureCount`, with fixed `candidateCount=1`, `lockedCount=1`, `rejectedCount=0`, `failureCount=0`, and `sourceMemberCount=partitions.candidateMemberCount`.
- `nextAction` is exactly `PrepareLOCERG1PreflightThenRequestExactHumanConfirmation`. Any failed lock predicate, malformed record, suppressed execution, contradiction, unbounded obligation, or unevaluated execution produces no T1V2-O01 and no terminal conclusion; T1-v2 has no diagnostic `Failed` artifact.

`char_14401` is Locked only when: (1) at least one nonempty exact C1 SourceMember set is projected; (2) the immutable historical evidence proves the existing Mesh/Avatar/skeleton/clip structural baseline; (3) every candidate-associated C1 model, animation, FX, material, texture, timeline, weapon, and combo row found by the finite direct review is included with size/hash; (4) every unknown Controller, complete-action, animation-event, attack-FX, serialized-component, renderer/material/texture/shader, weapon/combo/timeline, and referenced-dependency relationship is represented as `EvidenceUnavailableBeforeExtraction` with exactly one bounded obligation over listed SourceMembers; and (5) there is no contradictory authoritative identity. Lock means “eligible for bounded discovery,” not “dependency closure or Unity correctness proven.”

The missing base Controller, full nested StateMachine/Motion/BlendTree/clip traversal, and attack-action-to-FX graph are mandatory discovery obligations when they are not visible historically. They cannot be converted to `ProvenAbsent`, `NoEffectExpected`, or candidate rejection merely because FFS did not extract or expose them.

#### LO-CERG1 immediate preflight contract

Tool executable path/SHA, expanded arguments, private source-root bindings, and execution/output caps are deliberately absent from T1V2-O01. They are frozen only in LO1-P01 after a Passed v2 lock and under separate read-only preflight authorization immediately adjacent to the proposed LO.

LO1-P01 has exactly: `schemaVersion`, `artifactId`, `candidateLockSha256`, `contractHeadCommit`, `selectedCandidateId`, `createdAt`, `sourceRootBindings`, `operations`, `aggregateLimits`, `outputRoot`, `status`, `nextAction`.

- Fixed values are `schemaVersion=cerg-lo-cerg1-preflight/1.0.0`, `artifactId=LO-CERG1-P01`, `selectedCandidateId=char_14401`, `status=Green`, and `nextAction=RequestExactHumanConfirmationForLOCERG1`.
- `sourceRootBindings` rows have exactly `sourceId`, `privateAbsoluteReadOnlyRoot`, `rootFingerprint`. Rows correspond one-to-one with T1V2-O01 SourceRoots and must match their fingerprints. This machine-private field never enters tracked content or conversation.
- `operations` rows have exactly `operationId`, `obligationRefIds`, `toolId`, `toolVersion`, `privateToolExecutablePath`, `toolExecutableSha256`, `inputMemberRefIds`, `argumentTokens`, `workingDirectory`, `maxFilesRead`, `maxBytesRead`, `maxDurationSeconds`, `maxResultRows`, `maxOutputFiles`, `maxOutputBytes`, `outputPortableRelativePath`, `allowedChildProcessCount`. Each of the six `max*` fields is a positive integer; `allowedChildProcessCount` is a non-negative integer; every input member resolves to one exact T1V2-O01 SourceMember; no root/glob/directory/pattern input is allowed.
- `aggregateLimits` has exactly `maxFilesRead`, `maxBytesRead`, `maxDurationSeconds`, `maxResultRows`, `maxOutputFiles`, `maxOutputBytes`, each equal to the sum of its operation values. `outputRoot` is exactly `Extracted/CERG/SingleCharacter/LO-CERG1`; every operation output is a distinct descendant leaf of that root. `allowedChildProcessCount` is zero unless one named tool requires one fixed child.
- `Green` requires all registered leaves to exist under their private read-only roots and match C1 size/hash, the tool executable to match its SHA, outputs/temp to be absent, and every operation/aggregate cap to validate. Any `NotReady` condition suppresses LO1-P01, rolls back LO1-PT01 in the same preflight attempt, and yields `CorrectPreflightWithoutReadingAssetsOrDenyLOCERG1` only as an in-memory decision.
- The exact human confirmation binds the LO1-P01 SHA-256, candidate-lock SHA-256, all operation IDs, aggregate limits, output root, one-attempt/no-retry rule, cancellation, and rollback. Any changed input/tool/argument/limit/output invalidates the preflight. Preparing or failing preflight consumes no LO attempt; extraction begins only after confirmation.

#### T1-v2 Failure Transition Table

| ID | Trigger | Candidate/result | LO state | Required next action |
|---|---|---|---|---|
| `T1V2-FT01` | Override mirror mismatch, input hash mutation, unsafe/private projection, malformed field/ID/path/hash, conservation failure, or pre-existing v2 temp/output | No T1V2-O01; no terminal result | denied | Correct contract/input/output state and rerun only with authorization |
| `T1V2-FT02` | C1 cannot be read under the registered projection, or projected candidate members are empty so no actual candidate evaluation occurred | No T1V2-O01; `InvalidContractExecution`, not candidate rejection | denied | Return to total-control audit; never run T4 from this state |
| `T1V2-FT03` | An exact projected C1 member identity contradicts another authoritative identity | No T1V2-O01; no terminal result | denied | Return the exact contradiction to total-control audit |
| `T1V2-FT04` | A required unknown relationship cannot be bounded to the finite registered SourceMember set by one discovery obligation | No T1V2-O01; no terminal result | denied | Return the exact unbounded relationship to total-control audit |
| `T1V2-FT05` | Relationship is unavailable historically but has one finite exact obligation, including `deadbeef` base Controller | Candidate remains eligible; state is `EvidenceUnavailableBeforeExtraction` | preflight may proceed after Passed lock | Resolve only in LO-CERG1 |
| `T1V2-FT06` | Every lock predicate, identity, partition, and freshness check holds | Exactly `char_14401=Locked`; canonical Passed artifact | preflight pending | Prepare LO1-P01, then request exact confirmation |
| `LO1-PF01` | Tool/root/member/argument/cap/output binding is absent, stale, mismatched, root-only, or unbounded | Passed candidate lock remains unchanged; no candidate rejection | preflight `NotReady`; LO attempt not started | Correct within separately authorized preflight window or deny LO; no source scan/candidate switch |
| `LO1-PF02` | Green preflight and exact confirmation match byte-for-byte | Candidate lock unchanged | one LO-CERG1 attempt authorized | Execute only registered operations and stop |

If preflight cannot become Green within its separately authorized bounded window, or required discovery remains unresolved after the single LO-CERG1 attempt, the route may reach a genuine `ProjectFailed` only through the later evidence-producing CERG-T4. Neither state retroactively changes T1-v2 into candidate non-evaluation.

#### Fixed v2 counterexamples

| Case | Input | Required result |
|---|---|---|
| `T1V2-DR01` | `subjects=[]`, `relationships=[]`, and `discoveryObligations=[]` because C1 projection was forbidden or skipped | T1V2-FT02; no artifact and no ProjectFailed conclusion |
| `T1V2-DR02` | C1 row for `char_14401` has exact portable relative path, size, and SHA | Permitted SourceMember projection; no source-content read required |
| `T1V2-DR03` | OverrideController contains `deadbeef` while the base Controller is absent from FFS export | `EvidenceUnavailableBeforeExtraction` plus one `ResolveBaseController` obligation; never `ProvenAbsent` or automatic rejection |
| `T1V2-DR04` | T1V2-O01 omits tool path/SHA/arguments | Valid by design; those fields belong only to LO1-P01 |
| `T1V2-DR05` | LO1-P01 names a source root/glob or omits exact member size/hash or any positive file/byte/time/result/output cap | LO1-PF01; LO denied, candidate lock preserved |
| `T1V2-DR06` | Filename/directory similarity is used to claim complete action or FX closure | Malformed evidence claim under T1V2-FT01; no lock from that claim |
| `T1V2-DR07` | A finite C1 member list and structural baseline exist; Controller/action/FX relations are unknown but each has one bounded obligation | `char_14401=Locked`; proceed only to preflight |
| `T1V2-DR08` | LO-CERG1 discovers a dependency outside the registered member set | Record unresolved external identity, do not read it or broaden scope; CERG-T2 closure cannot pass |
| `T1V2-DR09` | T1-v1 artifact or its derived T4 conclusion is offered as current failure authority | Reject the citation as `InvalidatedByContractDefect`; preserve the bytes only as history |

This docs-only correction authorizes no T1-v2 artifact generation or preflight. Its only next action is `AwaitTotalControlAuditBeforeCERGT1V2`.

### Historical CERG-T1-v1 central contract

The definitions in this historical section produced T1V2-H01 but are invalidated and non-executable. They are preserved verbatim except for this status notice and cannot authorize candidate rejection, T4, LO, overwrite, cleanup, or rerun.

#### T1 Artifact Registry

| ID | Path or byte range | Required shape and role | Success/failure rule |
|---|---|---|---|
| `T1-I01` | Normative roadmap bytes from the CERG override heading through the byte before the historical FFS heading | UTF-8 contract bytes; required direct input | Must exist, decode as UTF-8, and hash exactly to `normativeOverrideSha256`; mismatch suppresses T1 output |
| `T1-I02` | Mirrored roadmap over the identical heading-bounded byte range | UTF-8 mirror bytes; required direct input | Must be byte-identical to T1-I01; divergence suppresses T1 output |
| `T1-I03` | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-ledger.json` | Historical C1 ledger. Whole-file identity is recorded; the only content projection is `sources[*].{sourceId,sourceKind,rootFingerprint}` plus per-`sourceId` counts and byte sums derived solely from `files[*].{sourceId,sizeBytes}` | Required and read-only; every other member, including captured times, paths, object rows, observations, and private values, is neither projected nor serialized |
| `T1-I04` | `Extracted/Threads/019f4a24-5ca0-7002-9dc2-4a0e42ad3cbe/C1/source-corpus-summary.json` | Historical C1 summary used only as whole-file identity: portable relative path, byte count, and SHA-256 | Required and read-only; no JSON member or value is parsed or projected by T1 |
| `T1-I05` | `Extracted/FastFeasibilitySpike/LO-FFS1` | Immutable historical evidence set. Every recursive file is enumerated and hashed as `WholeFileIdentity`; content parsing is limited to `.meta`, `.prefab`, `.controller`, `.overrideController`, `.anim`, `.asset`, `.mat`, `Packages/manifest.json`, and `Logs/*-result.txt` members | Required root and read-only; reparse points, member mutation, or a member outside this root suppresses T1 output. No other member content is opened or interpreted |
| `T1-T01` | `Extracted/CERG/SingleCharacter/T1/candidate-lock.json.tmp` | Temporary bytes with exactly the T1-O01 shape | Must be absent at start; created only after the manual contract review and sensitive-data scan; never consumable; removed by same-Task rollback or atomically renamed to T1-O01 |
| `T1-O01` | `Extracted/CERG/SingleCharacter/T1/candidate-lock.json` | Sole frozen T1 result, schema `cerg-t1-candidate-lock/1.1.0`; a manual direct-evidence index, not producer output | Must be absent at start and is never overwritten. `Passed` is consumable only under the LO rule below; `Failed` is diagnostic-only; contract/input/safety failures suppress it entirely |

There are no other T1 inputs, intermediate files, outputs, summaries, locks, journals, diagnostics, schemas, producers, validators, or test artifacts. T1 manually assembles the one candidate-lock evidence index from direct registered evidence locators; no executable is claimed as semantic authority. Total control reproduces the decision by opening those exact historical evidence members and checking their recorded hashes/locators. T1 may create the parent directories for T1-T01/T1-O01 only. A pre-existing T1-T01 or T1-O01 is a stop condition and grants no overwrite, cleanup, or rerun authority.

#### Complete T1-O01 shape

T1-O01 is one JSON object with exactly these top-level fields in this order; every field is mandatory: `schemaVersion`, `artifactId`, `contractHeadCommit`, `normativeOverrideSha256`, `mirrorOverrideSha256`, `derivationMethod`, `evidenceSetFingerprint`, `status`, `consumableForLoCerg1`, `selectedCandidateId`, `inputArtifacts`, `evidenceItems`, `sourceRoots`, `candidates`, `subjects`, `relationships`, `loOperations`, `loCerg1Limits`, `failures`, `summary`, `nextAction`.

- `schemaVersion` is exactly `cerg-t1-candidate-lock/1.1.0`; `artifactId` is exactly `CERG-T1-O01`; `contractHeadCommit` is exactly 40 lowercase hexadecimal characters; `derivationMethod` is exactly `ManualDirectEvidenceReview/1`.
- `normativeOverrideSha256`, `mirrorOverrideSha256`, and `evidenceSetFingerprint` are 64 lowercase hexadecimal characters. The first two must be equal.
- `status` is exactly `Passed` or `Failed`. `consumableForLoCerg1` is a JSON boolean. `selectedCandidateId` is a candidate ID or JSON `null`.
- `nextAction` is exactly `RequestExactHumanConfirmationForLOCERG1` for `Passed`, or `RunCERGT4ProjectFailedWithoutLOCERG1` for `Failed`.
- `inputArtifacts` rows have exactly: `artifactId`, `portableRelativePath`, `byteCount`, `sha256`, `memberCount`, `memberSetFingerprint`. Rows exist exactly once for T1-I01 through T1-I05. T1-I01 through T1-I04 use `memberCount=1`; every row derives `memberSetFingerprint` by the tuple formula below, and T1-I05 uses its recursively enumerated file count.
- `evidenceItems` contains only evidence directly cited by a source-root, subject, relationship, LO-operation, or failure row. Rows have exactly: `evidenceId`, `inputArtifactId`, `evidenceClass`, `portableRelativePath`, `byteCount`, `sha256`, `locatorKind`, `locator`. `evidenceClass` is `C1SafeProjection`, `FileTreeIdentity`, `UnityMeta`, `SerializedRelationship`, `Manifest`, or `FFSRunRecord`; `locatorKind` is `C1SourceProjection`, `YamlObjectPath`, `UnityGuidRecord`, `ManifestEntry`, `Utf8LineRange`, or `WholeFileIdentity`. For `WholeFileIdentity`, bytes/hash identify the complete file; otherwise they identify the canonical bytes of exactly the selected safe projection. The path is repository-relative with `/` separators. The locator is a non-empty portable string and never contains an absolute path, user/host name, credential, or unrestricted log text.
- Evidence class/input/locator combinations are closed: `C1SafeProjection` uses T1-I03/`C1SourceProjection`; `FileTreeIdentity` uses T1-I05/`WholeFileIdentity`; `UnityMeta` uses T1-I05/`UnityGuidRecord`; `SerializedRelationship` uses T1-I05/`YamlObjectPath`; `Manifest` uses T1-I05/`ManifestEntry`; `FFSRunRecord` uses T1-I05/`Utf8LineRange`. Every other combination is invalid. An FFS line range may project only registered tool identity, attempt identity, exit state, and the already-recorded structural observation code; unrestricted line text is never serialized.
- `sourceRoots` rows have exactly: `sourceId`, `sourceKind`, `rootFingerprint`, `sourceFileCount`, `sourceBytes`, `ledgerEvidenceId`. `sourceId` is a non-empty portable NFC identifier containing no path/private value; `sourceKind` is `PcInstall`, `PcPatchOrCache`, `AndroidApk`, or `AndroidDataOrCache`; `rootFingerprint` is a SHA-256; counts are non-negative integers. Each row is the canonical safe projection `CJ({sourceId,sourceKind,rootFingerprint,sourceFileCount,sourceBytes})`; `ledgerEvidenceId` resolves to its one `C1SafeProjection`/`C1SourceProjection` evidence row whose `locator` equals `sourceId`. No filesystem root path is present.
- `candidates` rows have exactly: `candidateId`, `comparisonOrdinal`, `familyId`, `familyIdentityKind`, `familyIdentityValue`, `disposition`, `rejectionFailureIds`. `comparisonOrdinal` is an integer 1 through 3; `familyId` and `familyIdentityValue` are non-empty portable NFC strings containing no path/private value; `familyIdentityKind` is `UnityGuid`, `SourceObjectId`, or `PortableFamilyKey`; `disposition` is `Locked` or `Rejected`. `rejectionFailureIds` is empty exactly for `Locked`, and for `Rejected` resolves exactly to all and only candidate-owned T1-FT07/08/09 rows.
- `subjects` rows have exactly: `subjectId`, `candidateId`, `subjectKind`, `unityGuid`, `serializedFileId`, `sourceObjectId`, `portableRelativePath`, `contentSha256`, `unityTypeName`, `componentClass`, `blendTreeType`, `parameterName`, `evidenceRefIds`. `subjectKind` is exactly one of `Model`, `SkinnedMesh`, `Renderer`, `Mesh`, `Material`, `Texture`, `Shader`, `Skeleton`, `Bone`, `Avatar`, `ActionClip`, `Controller`, `OverrideController`, `StateMachine`, `ActionState`, `AttackAction`, `Motion`, `BlendTree`, `BlendParameter`, `FXPrefab`, `FXObject`, `FXComponent`, `FXMaterial`, `FXTexture`, `FXShader`, `FXAnimation`, or `ReferencedObject`. Identity fields not applicable to the subject are JSON `null`; at least one of `unityGuid`, `serializedFileId`, `sourceObjectId`, `portableRelativePath`, or `contentSha256` is non-null. `evidenceRefIds` is non-empty. Every controller state is represented exactly once as `ActionState` or `AttackAction`, never both; that partition is the identity-bearing complete action-state list.
- `unityTypeName` is non-null exactly for `FXComponent` and `ReferencedObject`. `componentClass` is non-null only for `FXComponent` and is `ParticleSystem`, `TrailRenderer`, `Renderer`, `Animator`, `Transform`, or `OtherSerializedFXComponent`, so an uncommon serialized component is retained rather than dropped. `ReferencedObject` losslessly retains any serialized object-reference target not covered by a more specific kind. `blendTreeType` is non-null exactly for `BlendTree` and is `OneD`, `SimpleDirectional2D`, `FreeformDirectional2D`, `FreeformCartesian2D`, or `Direct`. `parameterName` is non-null exactly for `BlendParameter`. All inapplicable specialized fields are JSON null.
- A non-null `serializedFileId` is a canonical signed base-10 integer string; non-null `sourceObjectId` is a non-empty portable NFC identifier; non-null `portableRelativePath` is a portable path; non-null `contentSha256` is a SHA-256. Each identity tuple is unique inside its candidate.
- `relationships` rows have exactly: `relationshipId`, `candidateId`, `slotOrdinal`, `sourceSubjectId`, `relationshipKind`, `targetSubjectId`, `state`, `authorityKind`, `authorityScopeId`, `authorityScopeFingerprint`, `serializedPropertyPath`, `overrideSourceClipSubjectId`, `blendChildOrdinal`, `blendThreshold`, `blendPositionX`, `blendPositionY`, `childTimeScale`, `childCycleOffset`, `childMirror`, `directBlendParameterSubjectId`, `evidenceRefIds`, `conflictingTargetSubjectIds`, `loOperationId`. `relationshipKind` is exactly one of `ModelUsesRenderer`, `RendererUsesMesh`, `RendererUsesMaterial`, `MaterialUsesTexture`, `MaterialUsesShader`, `ModelUsesSkeleton`, `SkeletonContainsBone`, `AvatarUsesSkeleton`, `ControllerOwnsStateMachine`, `StateMachineContainsStateMachine`, `StateMachineContainsState`, `StateUsesMotion`, `BlendTreeUsesParameter`, `BlendTreeContainsMotion`, `MotionUsesClip`, `OverrideMapsClip`, `AttackTriggersFX`, `FXPrefabContainsObject`, `FXObjectContainsObject`, `FXObjectContainsComponent`, or `FXComponentReferencesSubject`. `authorityKind` is `Controller`, `OverrideController`, `Prefab`, `Event`, or `SerializedObject`; C1 and FFS rows may support provenance but can never be a relationship authority or prove exhaustive absence.
- `state` is `ProvenPresent`, `ProvenAbsent`, `EvidenceUnavailableBeforeExtraction`, or `Contradictory`; `slotOrdinal` is a positive integer unique for `(candidateId,sourceSubjectId,relationshipKind)`. `authorityScopeId` is a non-empty portable NFC string or null; `authorityScopeFingerprint` is a SHA-256 or null; they are null or non-null together. Every source, target, conflicting target, override-source-clip, direct-blend-parameter, authority-container, and owner subject reference resolves inside the row's candidate; cross-candidate references are invalid.
- Present relationship source→target kinds are closed: `ModelUsesRenderer` is Model/SkinnedMesh→Renderer; `RendererUsesMesh` is Renderer→Mesh; `RendererUsesMaterial` is Renderer→Material/FXMaterial; `MaterialUsesTexture` is Material/FXMaterial→Texture/FXTexture; `MaterialUsesShader` is Material/FXMaterial→Shader/FXShader; `ModelUsesSkeleton` is Model/SkinnedMesh→Skeleton; `SkeletonContainsBone` is Skeleton→Bone; `AvatarUsesSkeleton` is Avatar→Skeleton; `ControllerOwnsStateMachine` is Controller→StateMachine; both StateMachine containment kinds are StateMachine→StateMachine or ActionState/AttackAction as named; `StateUsesMotion` is ActionState/AttackAction→Motion/BlendTree; `BlendTreeUsesParameter` is BlendTree→BlendParameter; `BlendTreeContainsMotion` is BlendTree→Motion/BlendTree; `MotionUsesClip` is Motion→ActionClip; `OverrideMapsClip` is OverrideController→ActionClip and also names one ActionClip `overrideSourceClipSubjectId`; `AttackTriggersFX` is AttackAction→FXPrefab; FX object-tree relationships are FXPrefab→FXObject, FXObject→FXObject, and FXObject→FXComponent; `FXComponentReferencesSubject` is FXComponent→any typed candidate subject, using `ReferencedObject` when no specific kind applies.
- Authority pairs are closed: the eight model/renderer/material/skeleton/avatar relationships use `SerializedObject`; controller/state-machine/Motion/BlendTree/clip relationships use `Controller` or `SerializedObject`; `OverrideMapsClip` uses `OverrideController` or `SerializedObject`; `AttackTriggersFX` uses `Controller`, `Event`, `Prefab`, or `SerializedObject`; and all four FX object/component relationships use `Prefab` or `SerializedObject`. Any other pair is invalid. `ProvenAbsent` additionally forbids a non-container authority and requires a scope fingerprint over the complete enumerated owner collection.
- `serializedPropertyPath` is non-null exactly for `FXComponentReferencesSubject` and identifies the exact serialized object-reference property. `overrideSourceClipSubjectId` is non-null exactly for `OverrideMapsClip`. The eight blend-child fields are non-null only for `BlendTreeContainsMotion`: `blendChildOrdinal`, `childTimeScale`, `childCycleOffset`, and `childMirror` are always present; `OneD` additionally requires only `blendThreshold`; a 2D tree requires only `blendPositionX` and `blendPositionY`; `Direct` requires only `directBlendParameterSubjectId`. Decimal values are finite canonical base-10 strings without exponent or trailing zero; `childMirror` is boolean. All inapplicable specialized fields are JSON null.
- A `ProvenPresent` relationship has one non-null target, non-empty evidence, empty conflicts, null `loOperationId`, and an optional scope pair. A `ProvenAbsent` relationship has null target, non-empty evidence, empty conflicts, null `loOperationId`, and non-null exhaustive `authorityScopeId` plus `authorityScopeFingerprint`. An `EvidenceUnavailableBeforeExtraction` relationship has null target, non-empty evidence identifying the owner/container, empty conflicts, exactly one non-null `loOperationId`, and a null scope pair. A `Contradictory` relationship has null target, at least two distinct sorted conflicting targets, at least two evidence refs, null `loOperationId`, and a null scope pair.
- `loOperations` is the complete LO-CERG1 operation registry, not merely an output-row cap. Rows have exactly: `loOperationId`, `candidateId`, `purpose`, `relationshipId`, `ownerSubjectId`, `queryKind`, `authorityContainerSubjectId`, `serializedType`, `propertyPath`, `readMembers`, `toolEvidenceRefIds`, `toolId`, `toolVersion`, `toolSha256`, `operationKind`, `argumentTemplate`, `allowedChildProcessCount`, `outputPortablePath`, `expectedSubjectKinds`, `expectedRelationshipKinds`, `maxFilesRead`, `maxBytesRead`, `maxDurationSeconds`, `maxResultRows`, `maxOutputFiles`, `maxOutputBytes`, `terminalStates`. `purpose` is `StageKnownMember` or `ResolveUnavailableRelationship`; the former has null `relationshipId`, while the latter resolves exactly one unavailable relationship. `queryKind` is `StageKnownMember`, `ResolveGuid`, `EnumerateControllerGraph`, `EnumerateBlendTree`, `EnumerateOverrideMap`, `EnumerateAnimationEvents`, `EnumerateSerializedObjectReferences`, `ResolveMaterialDependencies`, `ResolveFXDependencies`, or `EnumerateFXComponents`.
- Each `readMembers` row has exactly: `sourceId`, `sourceMemberPortablePath`, `sourceMemberByteCount`, `sourceMemberSha256`, `leafSelectorKind`, `leafSelectorValue`. It identifies one existing member relative to the privately resolved source root, with known positive byte count and SHA-256. `leafSelectorKind` is `WholeMember`, `UnityGuid`, `SerializedFileId`, `YamlObjectPath`, or `ArchiveEntry`; `leafSelectorValue` is null only for `WholeMember` and otherwise is one exact non-empty selector. A root, directory, wildcard, prefix, regex, recursive selector, filename guess, or member lacking known size/hash is invalid and rejects the candidate.
- `toolEvidenceRefIds` is a sorted non-empty set resolving only Manifest, FFSRunRecord, or FileTreeIdentity evidence rows whose combined direct fields prove the exact tool ID/version/SHA; no unreferenced tool claim is allowed. `toolId`, `toolVersion`, and `toolSha256` identify that one registered tool; `operationKind` is one exact non-empty portable operation name. `argumentTemplate` is an ordered non-empty token array containing only literals plus `{ROOT:<sourceId>}`, `{MEMBER:<ordinal>}`, and `{OUTPUT}` placeholders. Each row authorizes exactly one foreground invocation; `allowedChildProcessCount` is a non-negative integer. `outputPortablePath` is one unique strict child of `Extracted/CERG/SingleCharacter/LO-CERG1/`; no two operations overlap. Every max field is a positive integer. `maxFilesRead` equals the number of `readMembers`; `maxBytesRead` equals their byte-count sum; the tool may open no other member and may not enumerate the containing root. Resolution expected-kind arrays are sorted, duplicate-free, and non-empty; staging expected-kind arrays are `[]`. `terminalStates` is exactly `["ProvenPresent","ProvenAbsent","Contradictory"]` for resolution and `["ProvenPresent","Contradictory"]` for staging.
- `authorityContainerSubjectId` is non-null and candidate-local. It is Controller for `EnumerateControllerGraph`, BlendTree for `EnumerateBlendTree`, OverrideController for `EnumerateOverrideMap`, ActionClip/FXAnimation for `EnumerateAnimationEvents`, Material/FXMaterial for `ResolveMaterialDependencies`, AttackAction/FXPrefab/FXComponent for `ResolveFXDependencies`, FXPrefab for `EnumerateFXComponents`, and equals `ownerSubjectId` for `StageKnownMember`; `ResolveGuid` and `EnumerateSerializedObjectReferences` may use any candidate-local owner. `serializedType` and `propertyPath` are non-null exactly for `EnumerateSerializedObjectReferences` and null otherwise.
- `loCerg1Limits` has exactly: `attemptCount`, `maxOperationCount`, `maxFilesRead`, `maxBytesRead`, `maxDurationSeconds`, `outputRoot`, `maxOutputFiles`, `maxOutputBytes`. For Passed, `attemptCount=1`, `outputRoot` is exactly `Extracted/CERG/SingleCharacter/LO-CERG1`, and every maximum equals the sum of the corresponding operation maxima except `maxOperationCount=|loOperations|`. For Failed, `attemptCount=0`, every maximum is zero, and `outputRoot` remains the same inert portable value. Every actual LO read, tool invocation, child process, output, and elapsed second must be attributable to these rows. If any exact member, leaf selector, tool bytes, arguments, or bound cannot be frozen before lock, the candidate is Rejected; an entire source root can never substitute.
- `failures` rows have exactly: `failureId`, `transitionId`, `candidateId`, `evidenceRefIds`. `candidateId` is non-null exactly for T1-FT07/08/09 and JSON null exactly for T1-FT10. `transitionId` is T1-FT07, T1-FT08, T1-FT09, or T1-FT10 only. Candidate-owned failure evidence is non-empty and points directly to the rejection evidence; gate-owned T1-FT10 evidence is empty. T1-FT01 through T1-FT06 and T1-FT11/12 suppress output and therefore never appear; T1-FT13 is success and never appears as a failure row.
- `summary` has exactly: `sourceRootCount`, `candidateCount`, `lockedCount`, `rejectedCount`, `subjectCount`, `relationshipCount`, `provenPresentCount`, `provenAbsentCount`, `evidenceUnavailableCount`, `contradictoryCount`, `loOperationCount`, `evidenceItemCount`, `failureCount`. Every value is a non-negative integer derived from the arrays, never hand-entered.

Unknown fields and unknown enum values are invalid. All arrays are present; an empty array is `[]`. Empty strings are forbidden. JSON `null`, empty array, zero, and missing are distinct; missing is always invalid.

#### Identity, canonical bytes, sorting, and freshness

- Strings are Unicode NFC. Portable paths use `/`, preserve case, contain no drive/UNC prefix, `.` or `..` segment, or trailing slash. Unity GUIDs are 32 lowercase hexadecimal characters; SHA-256 values are 64 lowercase hexadecimal characters. Integers use JSON base-10 integer encoding.
- Canonical JSON uses UTF-8 without BOM, LF only, the field order specified above, no insignificant whitespace, and JSON escaping only for control characters, `"`, and `\`. Arrays use the sorting rules below and reject duplicates.
- Every derived digest hashes one canonical JSON array whose first element is the exact ASCII domain/version tag below; the tag is inside the hashed bytes. `memberSetFingerprint = sha256(CJ(["cerg-t1/member-set/1", sorted [[portableRelativePath,byteCount,sha256],...]]))`; T1-I01/I02 contain their single registered override byte-range tuple, T1-I03/I04 contain their single complete-file tuple, and T1-I05 contains every recursive member tuple. `inputArtifacts.sha256` equals the registered byte-range SHA for T1-I01/I02, complete-file SHA for T1-I03/I04, and `memberSetFingerprint` for T1-I05.
- `evidenceId = "t1e:" + sha256(CJ(["cerg-t1/evidence-id/1",inputArtifactId,portableRelativePath,sha256,locatorKind,locator]))`.
- `candidateId = "t1c:" + sha256(CJ(["cerg-t1/candidate-id/1",familyIdentityKind,familyIdentityValue]))`.
- `subjectId = "t1s:" + sha256(CJ(["cerg-t1/subject-id/1",candidateId,subjectKind,unityGuid,serializedFileId,sourceObjectId,portableRelativePath,contentSha256,unityTypeName,componentClass,blendTreeType,parameterName]))`.
- `authorityScopeFingerprint = sha256(CJ(["cerg-t1/authority-scope/1",candidateId,authorityKind,authorityScopeId,sorted evidenceRefIds]))`.
- `relationshipId = "t1r:" + sha256(CJ(["cerg-t1/relationship-id/1",candidateId,slotOrdinal,sourceSubjectId,relationshipKind,authorityScopeId,serializedPropertyPath,overrideSourceClipSubjectId,blendChildOrdinal]))`.
- `loOperationId = "t1o:" + sha256(CJ(["cerg-t1/lo-operation-id/1",candidateId,purpose,relationshipId,ownerSubjectId,queryKind,authorityContainerSubjectId,serializedType,propertyPath,readMembers,toolEvidenceRefIds,toolId,toolVersion,toolSha256,operationKind,argumentTemplate,allowedChildProcessCount,outputPortablePath,expectedSubjectKinds,expectedRelationshipKinds,maxFilesRead,maxBytesRead,maxDurationSeconds,maxResultRows,maxOutputFiles,maxOutputBytes,terminalStates]))`.
- `failureId = "t1f:" + sha256(CJ(["cerg-t1/failure-id/1",transitionId,candidateId,evidenceRefIds]))`.
- `evidenceSetFingerprint = sha256(CJ(["cerg-t1/evidence-set/1", evidenceItems projected in their frozen sort order to [evidenceId,inputArtifactId,evidenceClass,portableRelativePath,byteCount,sha256,locatorKind,locator]]))`. Raw registered byte-range and whole-file SHA-256 values hash exactly those bytes without a domain prefix and are never reused as a structured digest. The T1-O01 content fingerprint is the lowercase SHA-256 of its complete canonical bytes and is reported externally with the exact human-confirmation request; it is not embedded recursively in T1-O01.
- Sort `inputArtifacts` by `artifactId`; `evidenceItems` by `(portableRelativePath,locatorKind,locator,evidenceId)`; `sourceRoots` by `sourceId`; `candidates` by `(comparisonOrdinal,candidateId)`; `subjects` by `(candidateId,subjectKind,subjectId)`; `relationships` by `(candidateId,sourceSubjectId,relationshipKind,slotOrdinal,relationshipId)`; `loOperations` by `(candidateId,purpose,relationshipId,ownerSubjectId,loOperationId)`; failures by `(transitionId,candidateId,failureId)`. `readMembers` sort by `(sourceId,sourceMemberPortablePath,leafSelectorKind,leafSelectorValue)`; expected-kind and referenced-ID arrays use Ordinal ascending order; `argumentTemplate` preserves execution order. In every nullable sort position, JSON null sorts before strings. Duplicates are forbidden.
- T1-O01 is fresh only while `contractHeadCommit`, both override hashes, every input hash/member-set fingerprint, and the complete evidence-set fingerprint still match. Any change makes it non-consumable and requires a separately authorized T1 rerun; no field may be refreshed in place.

#### T1 Subject/Partition Registry

- Eligible candidate families are derived only from candidate-local Unity GUID, source-object, or evidence-backed portable family-key evidence in T1-I05. Evaluation order is deterministic: an evidence-backed `char_14401` family is first; all remaining eligible identities use Ordinal `(familyIdentityKind,familyIdentityValue)`. Evaluated candidates are the contiguous prefix of that order ending at the first Locked candidate or at ordinal 3; skipping an earlier eligible identity is T1-FT11.
- Candidate universe `C` contains 0 through 3 evaluated families, has contiguous `comparisonOrdinal=1..|C|`, and is unique by `familyId`, exact identity, and Unicode-NFC Ordinal-ignore-case `(familyIdentityKind,familyIdentityValue)`. It partitions exactly as `C = Locked ⊎ Rejected`. `|Locked|=1` for `Passed`; `|Locked|=0` for `Failed`; more than one Locked is invalid and suppresses T1-O01.
- Source-root universe `U` is the non-empty set of all `sourceRoots` rows and equals exactly the identity-unique T1-I03 source projection. Each source row has exactly one ledger evidence row, every `readMembers.sourceId` belongs to U, and unused U rows remain present. A U row grants no directory enumeration authority. Zero or duplicate source IDs, or a source-kind/root-fingerprint/count/byte disagreement, suppresses output.
- Subject universe `S` is all `subjects` rows and partitions by the twenty-seven `subjectKind` values above. The action-state sub-universe partitions exactly as `ActionStates = ActionState ⊎ AttackAction`; FX components partition exactly by the six `componentClass` values. Every subject belongs to exactly one candidate and one kind; cross-candidate subject reuse is forbidden even when byte identities match.
- Relationship universe `R` is all `relationships` rows and partitions exactly as `R = ProvenPresent ⊎ ProvenAbsent ⊎ EvidenceUnavailableBeforeExtraction ⊎ Contradictory`.
- Required relationship slots are exactly the union of every authority-explicit serialized reference slot and these semantic anchors: Model/SkinnedMesh to renderer and skeleton; each Renderer to its mesh and every material slot; each Material/FXMaterial to its shader and every texture property; Skeleton to every declared bone; Avatar to skeleton; each Controller to every top-level StateMachine; every StateMachine to every nested StateMachine and state; every `ActionState`/`AttackAction` to exactly one Motion or BlendTree; every BlendTree to all parameter subjects and every ordered child Motion/BlendTree; every leaf Motion to exactly one ActionClip; OverrideController to every source→replacement clip entry; every AttackAction to its FX expectation; every FXPrefab through its complete recursive FXObject hierarchy to every serialized Component; and every FXComponent to every serialized object-reference target. A not-yet-enumerable anchor is one `EvidenceUnavailableBeforeExtraction` row with one bounded `ResolveUnavailableRelationship` operation whose expected kinds freeze the only rows it may materialize.
- Controller/state-machine and BlendTree graphs must be finite and acyclic. Recursive traversal from every Controller must account for every nested state and every BlendTree child until all leaves terminate in ActionClip; zero-child states, unclassified Motions, missing parameter branches, or an unreachable listed leaf fail closure. Each FXPrefab's FXObject hierarchy and component collection must be exhaustively fingerprinted, and each `FXComponent` must enumerate every serialized object-reference property, including ParticleSystem, TrailRenderer, Renderer, Animator, Transform, and uncommon component types represented as `OtherSerializedFXComponent`; unknown targets remain typed `ReferencedObject` rows rather than disappearing.
- The T1 frozen universe is the exact closure-request universe—not a claim that pre-extraction bytes already reveal every final target. `ProvenAbsent` means an identified authority scope was exhaustively read and proves zero matching reference; “the allowlisted evidence does not expose it” is always `EvidenceUnavailableBeforeExtraction` with an exact operation. If neither exhaustive absence nor an exact member/leaf/tool/argument/read/output/time-bounded operation can be represented, the candidate is Rejected under T1-FT08/09.
- LO-operation universe `O` partitions exactly as `O = StageKnownMember ⊎ ResolveUnavailableRelationship`. Resolve operations are in a one-to-one, onto mapping with `EvidenceUnavailableBeforeExtraction`; staging operations account for every already-known source member that LO-CERG1 will read or stage. Every exact `(sourceId,sourceMemberPortablePath,leafSelectorKind,leafSelectorValue)` tuple belongs to exactly one O row; therefore no read can disappear, duplicate, or broaden at runtime.
- Evidence universe `E` is all and only directly cited `evidenceItems`. Every E row occurs in at least one source-root, subject, relationship, LO-operation `toolEvidenceRefIds`, or failure evidence field, and every such reference resolves to exactly one E row. Unreferenced historical material remains in immutable inputs and is not copied into the minimal candidate-lock.
- Failure universe `F` is all `failures` and partitions by exactly one `transitionId`. A candidate rejection failure belongs to that candidate only; a gate-level failure has `candidateId=null`; the same failure identity may not appear twice.
- `subjects`, `relationships`, and `loOperations` contain rows only for the sole Locked candidate; earlier Rejected candidates are represented only by their candidate/failure/evidence rows. For Failed, all three arrays are `[]`. A candidate may be Locked only when it has at least one Model or SkinnedMesh, Skeleton, Avatar, ActionClip, Controller, StateMachine, Motion or BlendTree, and a complete action/attack anchor; contains no Contradictory relationship; every unavailable relationship has its exact Resolve operation; every planned known-member read has its exact Stage operation; every subject and relationship evidence reference resolves; the recursive Motion/BlendTree and FXComponent closures above hold; `loCerg1Limits` conserves every operation cap; and all candidate-local rules hold. Every known AttackAction has exactly one `AttackTriggersFX` slot. If no AttackAction is yet visible, an exact controller-graph operation must expect `AttackAction` and `AttackTriggersFX`; an authoritative resolved `ProvenAbsent` may still establish `NoEffectExpected`. CERG-T2 final closure requires at least one action state, at least one AttackAction, every Motion leaf and parameter branch resolved, and every FX component/reference resolved after all operations finish.
- Candidate-owned pre-freeze rejection may serialize its candidate row and failure row without serializing the malformed/unclassifiable subject, relationship, or LO operation that caused rejection; every row that is serialized must remain schema-valid and conserved.
- For `Passed`, `selectedCandidateId` equals the sole Locked candidate ID; for `Failed`, it is null. A Passed artifact may contain only candidate-owned rejection failures for other candidates and no T1-FT10; a Failed artifact contains exactly one gate-owned T1-FT10 plus all evaluated candidates' rejection failures.
- Gate-owned suppressors take precedence and produce no T1-O01; if several match, the lowest numeric transition ID is the sole externally reported cause. Within one otherwise valid candidate, rejection precedence is T1-FT07, then T1-FT08, then T1-FT09; the first offending row in frozen sort order produces exactly one failure row, evaluation of that candidate stops, and cascading failures are suppressed. T1-FT10 is emitted only after all zero-to-three candidate outcomes are conserved; otherwise T1-FT13 alone is the success transition.
- T1-O01 is `Passed` exactly when `candidateCount = lockedCount + rejectedCount`, `lockedCount=1`, all global conservation rules hold, and no gate-level failure exists. It is `Failed` exactly when either no candidate can be evaluated or 1 through 3 candidates were validly evaluated and all are Rejected, all serialized-row conservation rules still hold, and the only next action is the CERG-T4 ProjectFailed record without LO-CERG1.

#### T1 Failure Transition Table

| ID | Failure condition and stable owner | Candidate accounting | T1-T01 / T1-O01 vector | LO-CERG1 | Only next action |
|---|---|---|---|---|---|
| `T1-FT01` | Override missing, invalid UTF-8, mirror divergence, or HEAD/hash mismatch; gate-owned | none | absent / suppressed | denied | `CorrectCERGT1ContractAndReaudit` |
| `T1-FT02` | Required input absent, reparse point, outside allowed root, unreadable, or unsafe member class; gate-owned | none | absent / suppressed | denied | `RestoreOrAuthorizeExactInputThenRerunCERGT1` |
| `T1-FT03` | Input/evidence bytes or membership mutate during T1, or the C1 source projection disagrees with its file aggregation; gate-owned | none | removed / suppressed | denied | `RerunCERGT1FromFreshInputs` |
| `T1-FT04` | Absolute/private path, user/host/credential, or unrestricted log text reaches an in-memory projection; gate-owned | never serialized | absent / suppressed | denied | `CorrectSensitiveProjectionThenRerunCERGT1` |
| `T1-FT05` | Unknown/missing field or enum, invalid ID/hash/path, incompatible evidence-class/locator or relationship/authority pair, unresolved evidence reference, duplicate or misordered row; gate-owned | none | removed / suppressed | denied | `CorrectCERGT1ContractOrManualRecord` |
| `T1-FT06` | Any candidate/subject/relationship/LO-operation/evidence/failure conservation formula or `loCerg1Limits` sum fails; gate-owned | none | removed / suppressed | denied | `CorrectCERGT1ContractOrManualRecord` |
| `T1-FT07` | Authoritative relationship records contradict; candidate-owned | candidate becomes Rejected; one failure row | may continue / final artifact determined after candidate evaluation | denied for that candidate | `EvaluateNextCandidateOrFinalizeFailed` |
| `T1-FT08` | Any LO read lacks one exact member/leaf/size/hash, uses a root/directory/pattern selector, lacks exact tool/version/hash/arguments/output boundary, exceeds or omits a positive file/byte/time/result/output cap, or maps an unavailable relationship to zero/multiple operations; candidate-owned | candidate becomes Rejected; one failure row | may continue / final artifact determined after candidate evaluation | denied for that candidate | `EvaluateNextCandidateOrFinalizeFailed` |
| `T1-FT09` | Candidate lacks the required model/skeleton/avatar/controller minimum, finite recursive StateMachine→State→Motion→BlendTree→Clip closure, complete BlendTree parameter branches, attack anchor, or FXPrefab→all FXObjects→all Components→all serialized references closure; candidate-owned | candidate becomes Rejected; one failure row | may continue / final artifact determined after candidate evaluation | denied for that candidate | `EvaluateNextCandidateOrFinalizeFailed` |
| `T1-FT10` | Zero candidates can be evaluated, or all 1-3 validly evaluated candidates are Rejected | `locked=0`; all evaluated rows Rejected | canonical temp / diagnostic-only Failed T1-O01 | denied | `RunCERGT4ProjectFailedWithoutLOCERG1` |
| `T1-FT11` | Multiple Locked candidates, more than three evaluated candidates, duplicate candidate identity, or selector broadening after lock; gate-owned | invalid | removed / suppressed | denied | `CorrectCERGT1ContractOrManualRecord` |
| `T1-FT12` | Pre-existing temp/output, atomic install failure, canonical-byte mismatch, or final content-hash failure; gate-owned | none | retained only if pre-existing, otherwise same-Task temp rollback / suppressed | denied | `ResolveExactT1OutputStateBeforeRerun` |
| `T1-FT13` | All Passed predicates and conservation formulas hold | exactly one Locked | canonical temp / immutable Passed T1-O01 | pending exact human confirmation only | `RequestExactHumanConfirmationForLOCERG1` |

A failed or suppressed transition never creates an LO-consumable artifact. Candidate-level T1-FT07/08/09 failures may coexist with a final Passed artifact only when a different single candidate is Locked; their failure rows remain visible and counted.

#### Projection, LO consumption, and fixed counterexamples

- T1-O01 is machine-local but portable-by-content: it contains only registered IDs, relative paths, counts, byte sizes, hashes, typed dispositions, and redacted failure identities. Private values remain solely in their immutable historical inputs and are represented only by content fingerprints.
- `LO-CERG1Authorized` is never stored as true. Exact human confirmation may authorize LO-CERG1 only when T1-O01 is Passed, `consumableForLoCerg1=true`, one candidate is Locked, the output content hash and every freshness binding are revalidated, and T1-T01 is absent. The confirmation must name every `loOperationId`; each exact read-member tuple and its privately resolved read-only root; exact tool executable path plus ID/version/SHA; the fully expanded argument tokens; child-process cap; per-operation and aggregate file/byte/time/result/output limits; output paths; cancellation, rollback, and no-retry rule. Any mismatch denies the LO; a confirmation of a root without its exact member list is invalid. Private root/tool paths are never serialized into T1-O01 or repository content.
- `consumableForLoCerg1` must equal `(status == "Passed")`; human confirmation remains a separate necessary condition and cannot repair a Failed, stale, malformed, or suppressed T1 result.

T1 has no executable test matrix. Total control reviews the candidate-lock and its exact raw evidence locators directly. These fixed rejection examples are manual contract assertions, not requirements for a producer, schema, validator, fixture, or test artifact:

| Case | Direct-review counterexample | Required result |
|---|---|---|
| `T1-DR01` | An operation names only a source root/directory/pattern, or omits member size/hash, leaf selector, tool hash, arguments, or any file/byte/time/output cap | Candidate Rejected under T1-FT08; LO denied |
| `T1-DR02` | A nested StateMachine, BlendTree child/parameter branch, or Motion leaf is unlisted or does not terminate in an ActionClip | Candidate Rejected under T1-FT09; LO denied |
| `T1-DR03` | An FXPrefab omits an FXObject/serialized Component, or an FXComponent omits an object-reference property/typed target | Candidate Rejected under T1-FT09; LO denied |
| `T1-DR04` | Attack FX is unseen and has neither exhaustive authoritative `ProvenAbsent` nor one exact bounded Resolve operation | Candidate Rejected under T1-FT08; LO denied; `NoEffectExpected` forbidden |
| `T1-DR05` | C1/FFS prose is claimed as authority for `ProvenAbsent`/`NoEffectExpected` | Malformed T1-O01 suppressed under T1-FT05; LO denied |
| `T1-DR06` | Any required field is null/empty/missing/unknown, any ID/hash is stale, rows duplicate/misorder, or a partition/summary/limit sum disagrees | T1-O01 suppressed under T1-FT03/05/06; LO denied |
| `T1-DR07` | All one-to-three candidates are Rejected | Diagnostic-only Failed T1-O01 under T1-FT10; LO denied; CERG-T4 ProjectFailed |
| `T1-DR08` | Exactly one candidate is Locked with complete direct evidence, recursive action/FX closure, exact LO members/tools/bounds, and all sums/freshness valid | Passed T1-O01 under T1-FT13; LO still denied pending exact human confirmation |
| `T1-DR09` | A Passed T1-O01 has absent/stale confirmation or confirmation names a root/tool/output without the exact registered member/operation vector | T1-O01 remains non-authorizing; LO denied |

Review must inspect the referenced evidence bytes, not only field presence. It must check null/empty/missing/unknown, zero/one/many, duplicate/order/case conflict, stale hashes, all partition equations together, and the complete failed-output vector. This direct review is the only T1 verification; adding executable governance requires a separate future contract change and is not a CERG-T1 prerequisite.

### CERG-T2 visual-measurement and capture contract

Before requesting `LO-CERG2`, `CERG-T2` must freeze one exact, reviewable validation contract and its repository-relative asset/scene/script/output paths. The contract must assign concrete values—not placeholders—to all of the following:

- Unity/editor identity, render pipeline, color space, quality tier, anti-aliasing, background, lighting transforms/intensities/shadows, ground plane, and deterministic time-step settings;
- camera projection, FOV or orthographic size, near/far planes, target derived from finite combined renderer bounds, distance/framing formula, front/left/right/back rotations, close-up framing, and fixed root transform/canonical pose;
- capture width, height, aspect ratio, pixel format, exact lossless still format, video container/codec or lossless frame sequence, frame rate, action pre/post padding, file naming, ordering, and SHA-256 inventory;
- numeric bounds-occupancy interval, minimum border margin, zero-clipping rule, scale and facing tolerances, root/foot drift tolerances, finite bone/renderer-bounds thresholds, and per-action start/middle/end sample times;
- one exact controller traversal schedule that names every nested StateMachine path, state, Motion/BlendTree path, parameter name/value vector for every branch, expected leaf clip, transition setup, and start-to-finish capture interval;
- attack-FX trigger-time tolerance, peak-frame selection rule, allowed FX bounds relative to character bounds, post-action disappearance/retention rule, and material/texture/shader identity assertions.

Every phrase such as “reasonable scale,” “obvious misbinding,” “obvious anomaly,” “misplaced,” or “abnormal scale” must map to at least one frozen numeric or structural assertion and one visible capture. A subjective label alone cannot pass a criterion. Numeric/structural checks are necessary but not sufficient: total control may still reject visible corruption, but it may not accept `EverythingNormal` without the frozen measurements and required captures.

### `EverythingNormal` hard acceptance criteria

#### A. Dependency closure

- Model, every renderer/Mesh/Material/Texture/Shader, skeleton/Avatar, controller/override source→replacement mapping, recursive StateMachine/Motion/BlendTree/parameter/clip graph, and attack FX prefab/object/component/reference graph are fully resolved.
- `requiredMissingReferenceCount=0`.

#### B. Unity import/runtime integrity

- Use the Unity project at the repository root; do not create another project copy.
- Zero missing scripts, shaders, materials, textures, or bones.
- Zero import errors, exceptions, NaN/Inf transforms, or animation-binding failures.
- Exact asset, scene, and script paths are frozen only by the later `CERG-T2`; CERG-T0 authorizes none of them.

#### C. Model visible correctness

- Capture at least front, left, right, back, and close-up views.
- The complete character is visible and its scale, orientation, framing, hierarchy, and renderer bounds satisfy the CERG-T2 contract.
- No pink material, full transparency, missing faces, exploded geometry, skeleton collapse, or obvious texture misbinding.

#### D. Complete action correctness

- Every state and every BlendTree parameter branch reaches and plays its expected leaf clip from start to finish at least once; every nested StateMachine/Motion/BlendTree identity is covered by the traversal schedule.
- Each item records identity, duration, start/middle/end samples, and valid bones/renderer bounds.
- No freeze, exploded geometry, incorrect Avatar, foot/root tolerance violation, or unbound curve.
- Continuous capture or equivalent per-action evidence is mandatory; a static first frame is insufficient.

#### E. Attack FX correctness

- Every attack action expected to have FX actually triggers it at the corresponding time.
- Every FXPrefab object hierarchy and serialized component—including ParticleSystem, TrailRenderer, Renderer, Animator, Transform, and retained uncommon FXComponent types—and every typed serialized object-reference target/material/texture/shader/mesh/animation dependency is present and complete.
- Capture before attack, peak FX, and after attack. There must be no pink, invisible, placement/bounds-tolerance violation, abnormal scale under the frozen rule, non-terminating, or missing-texture effect.

#### F. Independent acceptance

- The implementation task produces evidence only and may not relax the meaning of “normal”.
- Total control independently inspects Unity logs, per-action structured results, screenshots, and continuous capture before accepting `EverythingNormal`.
- Any criterion lacking visible or structured evidence requires `ProjectFailed`; producer `exit=0` cannot substitute for correct visible/runtime behavior.

### Authorization boundary

- `CERG-T0` modifies only these roadmaps. It authorizes no real source access, extraction, staging, `Assets/StellaGaia/Imported`, Unity, cache, scene, script, process, or `Extracted` write.
- Future `CERG-T1A3` is an in-slot corrective Task limited to TG02/TG03 and the twenty-three TO03 synthetic fixtures without source/AssetRipper/Unity. TG01 and TO01/TO02 are immutable. Only a fully Green matrix may commit TG02/TG03 and atomically publish Green TO03 through TOT03; any pre-commit failure rolls TG02/TG03 back and publishes no readiness artifact. It may not read C1/FFS candidate evidence or create T01/O01 and must stop for total-control audit.
- Future `CERG-T1B` is a separate ordinary Task authorized only after total control approves the exact Green TO03 SHA and corrective tool HEAD. It may only perform the allowlisted read-only C1/FFS candidate evaluation and non-overwriting T01/O01 publication; it cannot change TG01-TG03 or TO01-TO03 and must stop before separately authorized LO1-P01 preflight.
- Only `LO-CERG1`, `LO-CERG2`, and conditionally `LO-CERG3` may receive separate exact authorization. Unity is single-threaded, with no background retry or package download.
- Each reachable LO permits one attempt. T3/LO3 are authorized only by LO2-RT02 plus exact total-control approval of one cause; they cannot change candidate/source scope, relax acceptance, repeat extraction, download packages, or create another repair/revalidation opportunity.
- Source remains permanently read-only; portable and private paths remain separate; absolute source paths must not enter the repository or conversation.
- After this contract correction, the only next action is `AwaitTotalControlAuditBeforeCERGT1A3`.

## 2026-07-18 Fast Feasibility Spike Override

- `mode=FastFeasibilitySpike`; `ordinaryTaskBudget=3`; `ordinaryTaskUsed=1`; `spikeLOBudget=2`; `spikeLOUsed=0` (reported as `ordinaryTaskUsed=1/3`, `spikeLOUsed=0/2`). The historical C1 snapshot LO belongs to the superseded route, is not counted in this spike, and its quarantined C1-O01/C1-O02 outputs remain immutable diagnostic history.
- The only permitted sequence is `FFS-T1 -> LO-FFS1 (character + environment; shared bundle/AssetRipper route) -> FFS-T2 (read-only acceptance) -> LO-FFS2 (WEM/BNK) -> FFS-T3 (read-only acceptance and forced overall conclusion)`.
- The spike freezes only three vertical samples: (1) character model plus skeleton/avatar/bone hierarchy plus animation clip; (2) environment Mesh plus Material plus Texture and at least one binding chain; (3) WEM decode/playability plus BNK membership/provenance.
- Character is Demonstrated only when the same candidate family exports at least one Mesh or SkinnedMesh, one auditable skeleton/avatar/bone hierarchy, and one AnimationClip whose relationship to that skeleton candidate is proven. A complete controller is not required.
- Environment is Demonstrated only when the same candidate slice exports at least one Mesh, Material, and Texture and proves at least one Mesh-to-Material-to-Texture binding or deterministic rebind. A complete room is not required.
- Audio is Demonstrated only when one WEM decodes into probeable/playable media and its BNK membership/provenance is auditable. Complete Wwise event semantics and Unity playback are not required.
- The forced overall conclusion is exactly one of: `Feasible` for 3/3 Demonstrated; `PartiallyFeasible` for 1-2/3 Demonstrated with no global safety issue invalidating the proven domains; `NotDemonstrated` when both spike LOs complete with 0/3 Demonstrated; or `Blocked` only when an LO cannot safely begin/finish or an input, tool, or authorization boundary cannot be satisfied and therefore execution evidence is insufficient. An ordinary sample failure is not `Blocked`.
- Reaching either total budget cap requires an immediate forced conclusion and stop; no additional Task, LO, tool rotation, or governance expansion is permitted.
- Suspended and not prerequisites for this spike: the old R8.3 baseline route, first-capture correction, complete R9-R13 route, full C2/C3-C7 processing, Unity full-project restoration, import, publication, and merge. This override grants no LO, extraction, decode, Unity, import, publication, or merge authority.

## 1. Goal And Product Path

- **Target user:** the human operator who owns the local StellaSora inputs, tool installations, storage, Unity license, evidence review, and final integration decision.
- **Scenario:** produce a frozen local source snapshot; review and, when required, match its baseline; discover and statically qualify all approved families; stage only explicit candidates; permit one focused repair attempt per family/failure class; run representative Unity validation one subject at a time; aggregate four independent G5 conclusions; then merge and clean up only after separate approval.
- **Entry:** branch `codex/asset-corpus-integration`, committed PersonalLocalMode package/runbook/plans, and no Phase B outputs. R8.1 derives the exact current HEAD/tool/locator/boundary/manifest/baseline/output/disk state from the fixed descriptor; the user does not transcribe it. Later stages retain their own stage-specific gates.
- **Completion path:** R7 PersonalLocalMode contract closure -> R8.1 automatic preflight -> one `ConfirmPersonalLocalRun` -> one C1 snapshot -> human first-capture baseline review -> Stop; any future matching capture requires a new independent PersonalLocalMode continuation package and is outside the current authorization -> separate R9 authorization only after C1 baseline closure -> R10 static family qualification -> R11 controlled staging and RepairOnce -> R12 single-thread Unity -> R13 in-memory G5 and final handoff -> separately authorized integration/cleanup program.
- **Success state:** the frozen input universe is conserved; every family/member has a current typed state and evidence route; the four G5 conclusions remain independent; source roots are unchanged; sensitive machine data stays local; no stage is inferred from an upstream pass; the roadmap ends with an auditable handoff to a separate integration/cleanup authorization stage.

This workflow does not claim restoration of the original StellaSora Unity project and does not grant redistribution rights for source-derived assets.

## 2. Approach Choice

### Option A - Sequential evidence gates with independent heavy-operation approvals - Recommended

Use existing Phase A registries, gates, runners, fixtures, and evidence where current. Add only the missing real adapters, producer/publication contracts, lifecycle boundaries, and evidence producers. Stop after every real run for human review.

- Benefits: preserves provenance, failure ownership, source safety, and the user's exact control over every heavy action.
- Costs: more explicit review points and no automatic R8-to-R13 continuation.

### Option B - One broad Phase B authorization

Authorize snapshot, discovery, extraction, staging, Unity, and import together.

- Benefit: fewer operator prompts.
- Rejected because: it defeats the PersonalLocalMode one-confirmation/one-attempt boundary, the C2 diagnostic-only first-run rule, C5/C7 separation, RepairOnce limits, and the required merge/cleanup hard gates.

### Option C - Bulk extraction/import first

Generate a broad export, then classify what was produced.

- Benefit: superficially fast access to files.
- Rejected because: it loses all-file conservation, creates uncontrolled storage and licensing risk, and bypasses static family qualification and representative acceptance.

No child implementation Task begins until the user confirms Option A or supplies a reviewed replacement.

## 3. Authority And Existing Contracts

Read these completely at the start of the relevant child Task; do not silently replace them with this roadmap:

- `AGENTS.md`
- `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`
- `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`
- `docs/superpowers/specs/2026-07-15-stella-sora-asset-corpus-c3-c6-design.md`
- `docs/asset-migration/source-corpus-phase-b-runbook.md`
- `docs/asset-migration/source-corpus-phase-b-authorization-package.md`
- `docs/asset-migration/c2-discovery-phase-b-runbook.md`
- `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md`
- `docs/superpowers/specs/2026-06-02-unity-asset-migration-design.md`
- `docs/adr/0001-unity-first-sample-gated-asset-migration.md`

The central definitions remain authoritative:

- C1 artifacts and authorization: PB-I01 through PB-I03, C1-I01 through C1-I06, C1-O01/C1-O02, C1-E01; PB-SP01 through PB-SP06; PB-FT01 through PB-FT12.
- C2 discovery: AR-I01 through AR-I11, AR-P01, AR-O01 through AR-O05; SP-01 through SP-09; FT-01 through FT-15.
- C3-C6 lifecycle: LC-I01 through LC-I14; C3-O01 through C3-O04, C4-O01 through C4-O03, C5-O01 through C5-O04, C6-O01 through C6-O05; SP-30/SP-31/SP-40/SP-50/SP-51/SP-60/SP-61; LF-01 through LF-21.
- G5 consumes only a valid same-generation C6-O04 handoff and reports `CorpusSnapshotComplete`, `StructuredObjectCoverage`, `OriginalAssetBatchCoverage`, and `StellaSora2AuthoringReady` independently.

If a real operation cannot be expressed by these rows, the owning Work Package first produces a contract-change child Task and stops for review. Operational scripts may not invent a second artifact, partition, failure, or decision model.

## 4. Global Hard Gates

### 4.1 Protected repository state

These untracked files are protected and must remain byte-identical unless the user personally supplies a new instruction that explicitly supersedes this protection:

- `AGENTS.md`, SHA-256 `397D256DA9E5C126667BC39B427AFF31BE7DBBDB1E83F1A90AD6F7AB8C34FD6D`.
- `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md`, SHA-256 `11ED3A2D7D933087D564E388991C45E5887600682DBC4ED9446E6117D4A5247B`.

The current C1 runbook's clean-worktree requirement conflicts with the requirement to retain these two untracked paths. R8 is blocked until one exact, reviewed disposition is approved:

1. amend the runbook/package to permit exactly these two paths with the frozen hashes and no other change; or
2. the user, not the implementation agent, moves or otherwise dispositions them outside the worktree and supplies clean-state evidence.

They are never an implicit dirty-state waiver.

### 4.2 Forbidden operations before their stage

- Before R8 authorization: no real manifest/root read and no source enumeration.
- Before R9 authorization: no observation producer, extraction, decode, AssetRipper, or real C2 publication.
- Before R11 authorization: no controlled staging or write beneath `Assets/StellaGaia/Imported`.
- Before R12 authorization: no Unity process, project import, or Unity cache creation.
- Before R13 integration authorization: no merge, tag, release, publication, branch deletion, or worktree removal.
- At every stage: no source-root write, network/runtime capture, credential exposure, arbitrary callback, unregistered child process, or automatic retry.

### 4.3 Sensitive and machine-local boundary

Absolute source/manifest/tool paths, user/host/account identifiers, local locks/journals/staging roots, unrestricted stdout/stderr, and approval records containing them remain machine-local. Portable evidence may contain only registered source IDs/kinds, portable relative paths, counts, bytes, hashes, tool identities/versions, dispositions, failure attribution, and next actions.

### 4.4 Special Long-Running Operation Gate

An atomic source scan, producer run, extraction, decode, publication, or Unity invocation that may exceed 20 minutes is an `LO`, not a normal child Task. Before each LO, its owning stage authorization must freeze:

1. one operation/subject identity and one attempt only;
2. exact executable/script bytes, version, SHA-256, arguments, working directory, and allowed child processes;
3. immutable input identities and approved read/write roots;
4. positive integer maximum duration and operator-controlled foreground cancellation;
5. positive integer output/storage budget and required free-space formula;
6. progress evidence or a 20-minute operator checkpoint without starting a second process;
7. stop, partial-output, rollback, quarantine, retention, and no-retry behavior;
8. expected portable/private/diagnostic outputs and leak policy.

For LO R8.C1-1, the owning authorization is the displayed current R8.1 GREEN state plus one exact `ConfirmPersonalLocalRun`; no external identity/form is created. Later stages use their separate packages. If an operation cannot expose bounded progress or safe cancellation, first implement a reviewed resumable/chunked runner contract in an ordinary child Task. The agent may report at 20-minute checkpoints but may not broaden the authorization or start a concurrent replacement process.

### 4.5 Universal stop conditions

Stop on changed HEAD/input/tool bytes, unapproved path/process/network activity, missing registry row, invalid/stale evidence, conservation failure, sensitive leak, reparse point, collision, pre-existing unknown output, insufficient storage, partial publication, rollback/quarantine ambiguity, source mutation, or any need to weaken an expected result after seeing actual data.

### 4.6 Mandatory child Task plan gate

Every numbered item below is a non-executable Work Package. Before any non-bootstrap repository write, real-input read, execution command, LO, merge, or cleanup, create one child Task plan that satisfies `docs/superpowers/plans/2026-07-14-stella-sora-asset-corpus-completion-roadmap.md` section 7 and includes all of:

1. target user/consumer and the one decision enabled;
2. exact files created, modified, and read-only;
3. exact Artifact Registry, Subject/Partition, and Failure Transition references;
4. 20-30 minute duration and complete 2-5 minute Steps;
5. RED cause and same-Task GREEN condition;
6. focused command, necessary regression, protected-input check, forbidden-path check, and exact staging list;
7. exact stage/commit/push list when Git changes are authorized;
8. stop checkpoint and one classified next action.

#### P0 docs-only bootstrap exception

Creating or revising the child Task plan that will govern a Work Package is the only bootstrap exception to the requirement for a pre-existing child plan. It is permitted only when the user explicitly authorizes one exact plan path and docs-only purpose, and all of these conditions hold:

1. the exact file scope is one named child Task plan; a separately named Roadmap-governance correction may use the same one-file rule when the user explicitly requests that correction;
2. repository authority docs and named implementation paths may be inspected read-only to write the plan; no package, runbook, tool, schema, fixture, code, source, manifest, machine-local evidence, or generated output is changed, and no real manifest/source/evidence content is opened;
3. no stage operation, test with heavy side effects, real-input command, LO, Unity, extraction, import, publication, merge, or cleanup runs;
4. the new plan itself satisfies the Mandatory Task Template before it is accepted;
5. protected hashes, forbidden paths, `git diff --check`, exact staging list, commit/parent, and upstream equality are verified;
6. only the named plan file is staged, committed, and pushed, then the bootstrap action stops.

P0 authorizes preparation of governance, not execution of the Work Package described by the plan. Any package/runbook/code change described by that plan still requires the plan's own authorization.

### 4.7 Stage-specific execution lifecycle and HEAD binding

Each real or state-changing stage has its own execution HEAD and frozen-byte set. R8 C1 uses PersonalLocalMode; later stages use the stage-specific approval named by their contracts. The lifecycle is:

1. **Prepared:** child plan and all relevant contract/tool/schema bytes are committed and pushed.
2. **Ready:** R8.1 derives a GREEN state; for other stages, the stage-specific approval binds the exact state.
3. **Confirmed/Started:** R8 accepts one `ConfirmPersonalLocalRun` only after GREEN and revalidates immediately before the one foreground attempt. Any mismatch returns to preflight without starting.
4. **Running:** a relevant HEAD/input/tool mutation during the operation invalidates the run and Stops under the owning failure transition.
5. **Closed:** after the operation ends and post-run identity/evidence checks pass, the consumed confirmation/result becomes immutable historical evidence for that completed operation.

Later docs-only child plans or later-stage commits do not retroactively invalidate a Closed result. They change the candidate state for the next operation. PB-I01 is the automatically derived R8.1 state, not an external identity record. R9 through R13 retain their named stage-specific packages/approvals. A Work Package description is never execution authority by itself.

## 5. Program Checkpoints

Every child Task reports:

- start/end HEAD and branch;
- exact files read and changed;
- registry rows evaluated;
- command/process identities, or `none`;
- conservation and failure vector;
- created/retained/quarantined paths;
- protected-file hashes and forbidden-path state;
- `Stop`, `Review`, or the single next authorization request.

Passing one checkpoint never authorizes the next stage.

---

## 6. R7 - Exact Phase B Authorization Closure

### Work Package R7.1 - Initial package and repository preflight

**Target child Task duration:** 20-25 minutes.
**Files:** read-only `docs/asset-migration/source-corpus-phase-b-authorization-package.md`, `docs/asset-migration/source-corpus-phase-b-runbook.md`, current tool/schema paths registered as C1-I03 through C1-I06; no files changed.
**Acceptance:** package commit, branch/upstream, frozen hashes, versions, protected hashes, and absent forbidden paths agree; no source or manifest read occurs.
**Evidence:** `git status --short --branch`, `git rev-parse HEAD`, `git rev-parse @{upstream}`, version output, exact file hashes, path-absence checks.

Steps:

1. Recheck branch, HEAD/upstream, and protected hashes - 3 minutes.
2. Recompute C1-I03 through C1-I06 hashes and tool versions - 4 minutes.
3. Recheck the package's registry/partition/failure conservation - 5 minutes.
4. Verify no output or forbidden path exists - 3 minutes.
5. Cross-check package/runbook bytes and PersonalLocalMode state - 4 minutes.
6. Record exact mismatches or readiness and stop - 3 minutes.

### Work Package R7.2 - Resolve the protected-untracked/clean-run conflict and LO contract

**Target child Task duration:** 20-30 minutes.
**Files if amendment is selected:** only `docs/asset-migration/source-corpus-phase-b-runbook.md` and `docs/asset-migration/source-corpus-phase-b-authorization-package.md`; protected files remain unchanged. If user-managed disposition is selected, repository files are unchanged.
**Acceptance:** the chosen disposition is explicit, preserves or externally dispositions the protected pair, permits no third dirty path, and freezes the LO rules for R8.
**Verification:** `git diff --check`, exact hashes/status, and package/runbook cross-reference review.

Steps:

1. Present the two dispositions and their consequences - 3 minutes.
2. Receive exact user choice; otherwise Stop - 2 minutes.
3. Apply only the selected docs amendment or verify user-managed evidence - 5 minutes.
4. Validate the LO duration/budget/cancellation/retention contract - 5 minutes.
5. Mark any earlier derived preflight state stale if a relevant byte changed - 3 minutes.
6. Stop before approval or execution - 2 minutes.

### Work Package R7.3 - Create the executable R8 child Task plan and commit all pre-approval bytes

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/superpowers/plans/2026-07-17-stella-sora-r8-c1-snapshot-execution-task.md`; include only the R7.2 package/runbook changes when that disposition was selected; protected files remain unstaged.
**Acceptance:** the R8 child plan satisfies the Mandatory Task Template, includes automatic derivation and the exact one-confirmation LO boundary, and the file set is committed/pushed before R7.4.
**Verification:** child-plan template audit, `git diff --cached --check`, exact cached name list, commit/parent, upstream equality, protected hashes, and forbidden-path absence.

Steps:

1. Write the one-operation R8 child Task plan from frozen contracts - 5 minutes.
2. Audit exact files, registries, RED/GREEN, Steps, commands, staging, and stop - 5 minutes.
3. Run protected-input and forbidden-path checks - 3 minutes.
4. Stage only the enumerated docs files and run cached diff check - 3 minutes.
5. Commit and push the docs-only pre-approval state - 4 minutes.
6. Record the new HEAD and stop - 2 minutes.

### Work Package R7.4 - Post-change revalidation of the exact execution HEAD

**Target child Task duration:** 20-25 minutes.
**Files:** all package/runbook/child-plan/tool/schema bytes read-only; no files changed.
**Acceptance:** reruns every R7.1 check against the new pushed HEAD, proves the R8 child plan is present, and validates PersonalLocalMode Registry/Partition/Failure conservation without reading real inputs.
**Evidence:** branch/HEAD/upstream, all frozen hashes, package conservation, protected hashes, forbidden paths, and zero source/process activity.

Steps:

1. Recheck branch, HEAD/upstream, and exact commit tree - 3 minutes.
2. Recompute every package/tool/schema/child-plan hash - 5 minutes.
3. Revalidate registry/partition/failure and command identities - 5 minutes.
4. Recheck protected and forbidden-path state - 3 minutes.
5. Confirm no stale derived state is carried across changed bytes - 3 minutes.
6. Emit `ReadyForPersonalLocalModeValidation` or Stop - 2 minutes.

### Work Package R7.5 - Validate PersonalLocalMode migration

**Target child Task duration:** 20-30 minutes.
**Files:** package/runbook/Roadmaps/R7.4/R7.5/R8.1, PB-I03 locator schema, and PersonalLocalMode policy test read-only; no runtime record or real input.
**Acceptance:** no human form/external compliance fields remain; PB-I01 is derived state; PB-I03 and PB-SP02/PB-SP06 close input location and boundary equality; `PB-SP01: 6 = 0 Passed + 6 Failed` before R8.1 evaluation; all safety invariants and one-confirmation boundary are conserved.
**Evidence:** focused policy-test result, hashes/status, zero-source/process/output declaration.

Steps:

1. Bind current HEAD and active governance bytes - 3 minutes.
2. Prove PB form/external identity removal - 4 minutes.
3. Validate PB-I01/PB-I03 derived-state and locator shapes plus PB-SP01 conservation - 5 minutes.
4. Validate automatic HEAD/tool/locator/boundary/manifest/baseline/output/disk responsibilities - 4 minutes.
5. Validate source-read-only, one-run, cancellation, no-retry, and downstream denials - 4 minutes.
6. Run the focused policy test and emit `ReadyForR8.1AutomaticPreflight` or Stop - 3 minutes.

**R8 state invalidation rule:** any relevant change before LO start makes PB-I01 and `ConfirmPersonalLocalRun` stale. Rerun R8.1; never ask the user to repair a form. Mutation during the operation invalidates the run. After R8.2 closes it, later plans do not retroactively erase the result.

**R7 checkpoint:** proceed only to R8.1 automatic preflight. No human confirmation is requested during R7.5.

---

## 7. R8 - Real C1 Snapshot And Baseline Review

### Work Package R8.1 - Exact preflight for one C1 operation

**Target child Task duration:** 20-30 minutes.
**Files:** repository read-only plus automatically located PB-I03, local C1-I01/C1-I02 shape/identity, and filesystem metadata; no prompt, arbitrary machine search, source-file content read, or hidden/background scan.
**Acceptance:** automatically derive and pass all six PB-SP01 groups; emit `ReadyForSinglePersonalLocalRun`; exact guarded command remains unrun.
**Evidence:** redacted derived-state summary and zero-heavy-process/output declaration.

Steps:

1. Revalidate repository and protected state - 3 minutes.
2. Derive HEAD, versions, tool/schema/policy hashes, and seven lightweight gates - 4 minutes.
3. Locate/validate PB-I03 and prove PB-SP02/PB-SP06 boundary/manifest equality - 5 minutes.
4. Derive baseline, fixed output boundary, and disk-space state - 4 minutes.
5. Derive source-read-only/one-attempt/cancellation/no-retry/downstream flags - 4 minutes.
6. Produce `ReadyForSinglePersonalLocalRun` or Stop - 3 minutes.

### LO R8.C1-1 - One guarded C1 snapshot attempt

**Not an ordinary child Task.** After R8.1 GREEN, display the redacted state and require exactly one `ConfirmPersonalLocalRun`. Recheck current state, then use one foreground runner process for one attempt. No retry, C2, extraction, Unity, or import.

### Work Package R8.2 - Validate C1 outputs and operational state

**Target child Task duration:** 20-30 minutes.
**Files:** read-only C1-O01/C1-O02 and private/redacted C1 evidence beneath the approved output root; no source content reopened.
**Acceptance:** schemas, source/file/byte conservation, fingerprints, end HEAD/input identities, no sensitive leak, and explained filesystem delta all pass; otherwise Stop.
**Evidence:** C1 validation summary, failure owner, retained/quarantine inventory, source-immutability proof.

Steps:

1. Verify process termination and end identities - 3 minutes.
2. Validate C1-O01/C1-O02 shape and fingerprints - 5 minutes.
3. Prove source/file/byte conservation - 5 minutes.
4. Scan portable outputs for forbidden machine data - 4 minutes.
5. Compare approved pre/post operational state - 4 minutes.
6. Emit Stop or baseline-review candidate - 3 minutes.

### Work Package R8.3 - Human baseline decision

**Target child Task duration:** 20-30 minutes.
**Files:** no repository change; immutable baseline and approval records remain machine-local.
**Acceptance:** first capture always Stops; the human either rejects it or freezes it as a candidate baseline with exact identity. No C2 authorization results.
**Evidence:** redacted decision record referencing snapshot/input fingerprints and conservation result.

Steps:

1. Review completeness/conservation and residual issues - 5 minutes.
2. Review source-kind/source-ID coverage without paths - 4 minutes.
3. Review failure/quarantine and sensitive-leak results - 4 minutes.
4. Reject or freeze immutable candidate baseline - 4 minutes.
5. Record next action and stop - 3 minutes.

### Work Package R8.4 - Close first-capture review and hand off future baseline matching

**Target child Task duration:** 20-25 minutes.
**Files:** no repository change unless a separate documentation child Task is authorized.
**Acceptance:** the first-capture decision, conservation, immutability, and no-leak result are frozen; C1-E01 remains diagnostic and `C2Authorized=false`. The current package cannot start a second attempt. If baseline matching is required, prepare a new independent PersonalLocalMode continuation package/plan in a later Task, recompute all state, and stop for its own single-confirmation boundary.
**Evidence:** redacted first-capture handoff identity, explicit `C2Authorized=false`, and either `nextAction=Stop` or `nextAction=PrepareIndependentBaselineMatchCycle`.

**R8 checkpoint:** wait for a separate R9 contract/implementation authorization. C1 success alone is insufficient.

---

## 8. R9 - Real C2 Discovery

Current state is `BLOCKED`: no reviewed real C1-to-C2 adapter, real observation-producer set, or real publication-root contract exists.

### Work Package R9.1 - Freeze the real C2 contract change

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c2-real-discovery-contract.md`, `docs/asset-migration/schemas/c2-real-discovery-authority.schema.json`; modify only `docs/asset-migration/c2-discovery-phase-b-runbook.md` and, only if a registry row truly changes, `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`.
**Acceptance:** exact C1-E01-to-AR mapping, producer row schema, real staging/publication transaction, portable/private boundary, storage, failure ownership, and eight physical SP-09 consumer paths are reviewed.
**Verification:** schema parse/tests, registry-reference review, `git diff --check`; no real data read.

Steps:

1. Map C1-E01 to AR-I01 through AR-I06 - 5 minutes.
2. Freeze producer-manifest fields for AR-I07/08/09 and AR-I11 - 5 minutes.
3. Freeze real stage/backup/quarantine/lock/journal/consumer roots - 5 minutes.
4. Map every new failure to one FT row or request a registry change - 4 minutes.
5. Validate portable/private and conservation contracts - 4 minutes.
6. Stop for contract review - 2 minutes.

### Work Package R9.2 - Implement and fixture-test the real adapter shell

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; fixture changes require a separately enumerated exact list and may never contain real data.
**Acceptance:** fixture-only adapter validates C1 identity, immutable inputs, authority manifest, path boundaries, and calls the existing C2 registered model without changing its semantics.
**Verification:** all new adapter cases plus the complete existing C2/C1/minimal regression matrix; no real path or heavy process.

Each increment stops after one cohesive adapter capability and one passing regression set.

### Work Package R9.3 - Implement one approved observation producer row

**Target child Task duration:** one 20-30 minute child Task per producer row/capability.
**Files:** exactly the `implementationPath`, `testPath`, and fixture paths frozen in the approved producer row from R9.1; if any is absent, the child Task is blocked.
**Acceptance:** exact tool/version/hash, allowed source kinds/selectors, child process count, row shape, timeout/cancellation, terminal accounting, rollback/quarantine, and no-Unity assertion pass on synthetic fixtures.
**Verification:** producer-specific fixtures/fault vectors and C2 conservation regression.

Repeat R9.3 only after explicitly naming the next producer row. Never batch multiple tools under one child Task.

### Work Package R9.4 - Implement the real SP-09 publisher and locked consumer

**Target child Task duration:** 20-30 minutes per transaction increment.
**Files:** modify `Tools/AssetImport/C2RealDiscoveryAdapter.psm1`, `Tools/AssetImport/Invoke-C2RealDiscovery.ps1`, `Tools/AssetImport/Test-C2RealDiscoveryAdapter.ps1`; no fixture consumer path becomes a real root.
**Acceptance:** same-volume stage/backup/quarantine/lock/journal semantics, fixed eight-path order, summary-last commit, exact rollback/recovery, and locked-consumer fingerprints pass injected fault vectors.
**Verification:** transaction/fault suite, complete C2 suite, and no TEMP/output leak.

### Work Package R9.5 - Independent completion audit and exact C2 authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c2-real-discovery-authorization-package.md`; all implementation/spec/runbook paths read-only.
**Acceptance:** fresh audit covers adapter, every producer, SP-01 through SP-09, FT-01 through FT-15, output vectors, rollback/recovery, and forbidden operations; the package freezes one diagnostic operation and all LO fields.
**Evidence:** audit command/result matrix, fixture-tree digest, exact hashes, zero real outputs.

### Work Package R9.6 - Obtain separate exact authorization for one C2 discovery

**Target child Task duration:** 20-30 minutes.
**Files:** none changed; external approval only.
**Acceptance:** exact C1 artifact/baseline identities, adapter/producer hashes, source kinds/selectors, staging/publication roots, counts/bytes/storage, duration/cancellation, output classes, stop/rollback/quarantine/retention, and explicit no-Unity/no-downstream boundaries are Confirmed.
**Evidence:** redacted approval-row conservation, exact command identity, and one R9 LO record with no source path or content.

### LO R9.C2-1 - First real C2 discovery

Run one approved producer sequence and one publication transaction. The first real run is diagnostic-only even if Passed. No retries or C3-C6 execution.

### Work Package R9.7 - Validate and review real C2

**Target child Task duration:** 20-30 minutes.
**Files:** real C2 artifacts read-only; no source reopen.
**Acceptance:** simultaneous SP-01 through SP-09 conservation, correct output vector (`5/5/0`, `1/4/0`, or FT-12 `0/5/0` as applicable), locked consumer acceptance, stable end identities, and fully explained filesystem delta.
**Evidence:** redacted diagnostic summary and human `Stop`/`Review` decision.

**R9 checkpoint:** wait for explicit R10 authorization. C2 Passed does not authorize lifecycle publication or extraction.

---

## 9. R10 - Static Family Qualification

### Work Package R10.1 - Freeze real C3-C6 lifecycle and LC-I14 aggregation contracts

**Target child Task duration:** 20-30 minutes per contract increment.
**Files:** create `docs/asset-migration/c3-c6-real-lifecycle-contract.md`; modify only `docs/superpowers/specs/2026-07-15-stella-sora-asset-corpus-c3-c6-design.md` when reviewed central registry rows must change.
**Acceptance:** freezes real LC-I06 publication; real C3-C6 generation roots; lane-private static fragment Artifact Registry rows and schemas; one deterministic LC-I14 aggregator; duplicate-subject/check rejection; Ordinal `(assetObjectId,checkId)` sorting; shared snapshot/generation/fingerprint conservation; transaction, locked-consumer, suppression, rollback, and quarantine semantics; and exact later R11/R12 refresh-generation/carry-forward rules. Fixture paths remain fixture-only. G5 publication is explicitly excluded.
**Verification:** Artifact/Partition/Failure cross-reference, fixed counterexamples for missing/duplicate/misordered/mixed-generation fragments, portable/private review, schema tests, and `git diff --check`.

No real lifecycle implementation or run is authorized by R10.1.

### Work Package R10.2 - Implement and fixture-test the LC-I06 producer/publisher

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `Tools/AssetImport/C3C6RealLifecycleAdapter.psm1`, `Tools/AssetImport/Invoke-C3C6RealLifecycle.ps1`, and `Tools/AssetImport/Test-C3C6RealLifecycleAdapter.ps1`; any fixture files require an exact child-plan list and synthetic data only.
**Acceptance:** fixture inputs produce one schema-valid, deterministic LC-I06 generation with exact source/object identities, typed references, direct-input hashes, transaction state, and locked-consumer validation; real inputs remain blocked.
**Verification:** producer/publisher happy path, stale/mutated/missing/duplicate input vectors, rollback/recovery, exact hashes, and complete existing C3-C6 fixture regression.

### Work Package R10.3 - Implement and fixture-test lane-private fragment producers

**Target child Task duration:** one 20-30 minute child Task per lane producer capability.
**Files:** create `Tools/AssetImport/C4StaticObservationProducer.psm1` and `Tools/AssetImport/Test-C4StaticObservationProducer.ps1`; exact synthetic fixtures are enumerated per child Task.
**Acceptance:** each registered lane producer emits only its registered private fragment type; every assigned check is terminally accounted; producer/tool/input fingerprints and shared generation identity are exact; no LC-I14 or C4 output is emitted.
**Verification:** Actor/Audio/Effects/Environment/UI fixture vectors, duplicate-within-lane, missing prerequisite, tool-unavailable, deterministic ordering, and forbidden process/path tests.

### Work Package R10.4 - Implement and fixture-test the LC-I14 aggregator, transaction, and locked consumer

**Target child Task duration:** 20-30 minutes per transaction increment.
**Files:** create `Tools/AssetImport/C4StaticObservationPublication.psm1` and `Tools/AssetImport/Test-C4StaticObservationPublication.ps1`; synthetic fault fixtures require exact enumeration.
**Acceptance:** registered lane fragments aggregate into exactly one LC-I14 package; rows are globally unique and Ordinal sorted; shared snapshot/generation/fingerprints conserve; stage/journal/backup/quarantine/summary-last publication and locked consumption are fail-closed.
**Verification:** missing-lane, duplicate-cross-lane, misordered, contradictory, mixed-generation, install/rollback/recovery/quarantine, partial-publication, and locked-consumer fault vectors.

### Work Package R10.5 - Implement and fixture-test real C3-C6 publication transactions

**Target child Task duration:** 20-30 minutes per stage publisher increment.
**Files:** create `Tools/AssetImport/C3C6LifecyclePublication.psm1` and `Tools/AssetImport/Test-C3C6LifecyclePublication.ps1`; modify `Tools/AssetImport/Invoke-C3C6RealLifecycle.ps1` only as enumerated by the child Task.
**Acceptance:** C3, C4, C5, and C6 each publish as separate registered stages with exact generation binding, fixed output order, locked consumers, downstream suppression, rollback/recovery, and no cross-stage atomic shortcut. A later refresh may reference or carry forward unchanged prior-stage bytes only through the exact R10.1 contract; it may never mutate an accepted generation in place or silently relabel old bytes with a new generation identity.
**Verification:** stage-by-stage success/failure vectors, stale direct inputs, partial stage install, downstream suppression, recovery/quarantine, and same-generation C2-C6-G5 fixture harness.

### Work Package R10.6 - Independent real-lifecycle completion audit

**Target child Task duration:** 20-30 minutes.
**Files:** all R10.1-R10.5 contracts/code/tests/fixtures read-only; no real inputs or lifecycle outputs.
**Acceptance:** fresh audit covers LC-I06 producer/publisher, every lane fragment producer, LC-I14 aggregation/transaction/locked consumer, separate C3-C6 publishers, registered failure vectors, no-heavy fixture boundary, output suppression, and state restoration.
**Evidence:** audit matrix, fixture-tree digest before/after, exact implementation hashes, zero real-output declaration, and any blocking gap.

### Work Package R10.7 - Prepare the exact R10 authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create `docs/asset-migration/c3-c6-real-lifecycle-authorization-package.md`; implementation/contracts remain read-only.
**Acceptance:** package freezes one diagnostic real lifecycle generation: exact stage-specific execution HEAD, accepted C2 generation, adapter/producer/publisher hashes, observation selectors, real roots, generation identity, counts/bytes/storage, LO rows, duration/cancellation, process limits, transaction/rollback/quarantine/retention, portable/private outputs, and explicit no-staging/no-Unity/no-G5-publication boundaries.
**Verification:** authorization Artifact/Partition/Failure conservation, exact hash/command list, protected/forbidden checks, and all rows Pending before human action.

### Work Package R10.8 - Obtain exact R10 human approval

**Target child Task duration:** 20-30 minutes.
**Files:** none changed; approval remains external and redacted.
**Acceptance:** every R10 authorization row is Confirmed against the current pushed stage-specific HEAD; no real evidence read or lifecycle process starts.
**Evidence:** approval-row conservation, approval identity, frozen-byte list, and explicit one-generation/no-retry boundary.

Any relevant byte or execution-HEAD change before the first authorized R10 operation starts voids the unstarted R10 approval and returns to R10.7/R10.8. After the approved lifecycle generation and its post-run checks close, that R10 approval becomes historical evidence under section 4.7.

### Work Package R10.9 - Re-index existing evidence before acquiring anything

**Target child Task duration:** 20-30 minutes.
**Files:** read-only approved existing summaries/reports and accepted real C2 generation; the child plan must name one registered/private coverage-inventory output or specify no output.
**Acceptance:** every candidate evidence item is classified `Current`, `Stale`, `Missing`, or `Contradictory` by fingerprint; no tool is rerun merely because the lifecycle model changed.
**Evidence:** registered/private coverage inventory and explicit reacquisition reasons; it is not LC-I14 and cannot be consumed by C4.

### Work Package R10.10 - Publish real LC-I06 typed lane facts

**Target child Task duration:** 20-30 minutes per approved adapter increment or authorized LO.
**Files:** accepted real C2 inputs read-only; write only the approved real LC-I06 transaction/generation paths using R10.2 bytes.
**Acceptance:** Actor, Audio, Effects, Environment, and UI facts preserve source/object identities, typed references, configuration disposition, and cross-lane provenance; locked consumer accepts one complete LC-I06 generation.
**Verification:** schema/fingerprint/conservation, start/end identities, transaction state, no-leak, and source-immutability checks.

### Work Package R10.11 - Run and publish C3 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted LC-I06 and registered C3 inputs read-only; write only C3-O01 through C3-O04 using the R10.5 C3 publisher.
**Acceptance:** SP-30 dispatch and SP-31 dependency partitions conserve counts/bytes; C3 outputs form one locked generation; conflicts/missing references remain visible; no C4 output exists.
**Verification:** C3 gate, locked consumer, generation fingerprints, C4-output suppression, and transaction rollback tests.

### Work Package R10.12 - Produce one registered real lane-private static fragment

**Target child Task duration:** one 20-30 minute child Task or authorized LO per lane in this fixed order: Actor, Audio, Effects, Environment, UI.
**Files:** accepted C3 generation and only approved current lane evidence read-only; write only the registered lane-private fragment path using R10.3 producer bytes.
**Acceptance:** every assigned check has one terminal Passed/Failed/Unchecked row; lane counts conserve; shared identities match; no LC-I14, C4 output, or Unity process is created.
**Verification:** lane validator, fragment schema/hash, process/output budget, start/end identities, and forbidden-path/process checks.

### Work Package R10.13 - Aggregate and publish exactly one LC-I14

**Target child Task duration:** 20-30 minutes.
**Files:** all accepted lane-private fragments read-only; write only the approved LC-I14 transaction/generation paths using R10.4 bytes.
**Acceptance:** all lanes are terminal; rows are globally unique and Ordinal sorted; counts/checks/fingerprints conserve; any invalid fragment suppresses LC-I14 and all downstream-valid output and enters the registered diagnostic/quarantine transition.
**Verification:** aggregator validation, exact LC-I14 schema/hash, locked consumer, start/end identities, rollback/quarantine, and downstream-output absence.

### Work Package R10.14 - Publish C4 only

**Target child Task duration:** 20-30 minutes.
**Files:** the accepted LC-I14 plus the other twelve registered C4 inputs read-only; write only C4-O01 through C4-O03 using the R10.5 C4 publisher.
**Acceptance:** all thirteen direct inputs match; SP-40 conserves; C4 generation is complete and locked; no C5 output is created.
**Verification:** C4 gate, direct-input hash frame, same-generation/freshness, locked consumer, and C5-output suppression.

### Work Package R10.15 - Derive and publish C5 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted C3/C4 generation and registered C5 inputs read-only; write only C5-O01 through C5-O04 using the R10.5 C5 publisher.
**Acceptance:** SP-50/SP-51 conserve; C5-O03 is an evidence request list only; no C6 output, Unity process, or acceptance inference occurs.
**Verification:** C5 gates, same-generation/freshness, locked consumer, missing-evidence vectors, and C6-output suppression.

### Work Package R10.16 - Publish provisional C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted C3-C5 generation/current repair history read-only; write only C6-O01 through C6-O05 using the R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; decision precedence is honored; missing evidence remains visible; no `UseOriginalAsset` without required evidence; locked C6-O04 is eligible only for later review.
**Verification:** C6 gates, same-generation harness, locked consumer, start/end identities, and diagnostic-only R10 closeout.

**R10 checkpoint:** human reviews family/static failures and explicitly chooses R11 candidates. Static qualification does not authorize staging.

---

## 10. R11 - Controlled Staging And RepairOnce

### Work Package R11.1 - Freeze the staging whitelist and repair authorization

**Target child Task duration:** 20-30 minutes.
**Files:** create a machine-local immutable staging authorization record; repository docs change only under a separately enumerated docs child Task.
**Acceptance:** exact family/member IDs, source artifact fingerprints, operation/tool hashes, target relative paths, total count/bytes, storage, license/redistribution boundary, rollback/quarantine, and one repair class per family are approved.
**Evidence:** redacted whitelist summary and `unlistedMemberCount=0`.

### Work Package R11.2 - Preflight one controlled staging batch

**Target child Task duration:** 20-30 minutes.
**Files:** approved source artifacts read-only; approved `Extracted` staging root and `Assets/StellaGaia/Imported` target remain absent until the LO begins.
**Acceptance:** all whitelist hashes, dependency closure, target collisions, reparse safety, storage, and rollback plan pass; exact existing staging script hash is approved or a separate implementation child Task is required.
**Evidence:** zero-write preflight and exact LO command.

### LO R11.STAGE-n - One whitelisted staging batch

Stage only the named members. No complete export, unlisted dependency, source mutation, or automatic repair. Validate every copied byte and retain the transaction record.

### Work Package R11.3 - Validate the staged batch

**Target child Task duration:** 20-30 minutes.
**Files:** staged outputs and transaction evidence read-only.
**Acceptance:** expected/actual count/bytes/hashes and relative paths match; no extra file exists; rollback remains possible; redistribution state is explicit.
**Evidence:** batch manifest, conservation result, source-immutability proof.

### Work Package R11.4 - Authorize one RepairOnce attempt

**Target child Task duration:** 20-30 minutes per family/repair class.
**Files:** machine-local LC-I12 record plus exact existing repair script/inputs/outputs; code changes require a separate exact implementation child Task.
**Acceptance:** one concrete failure attribution, explicit inputs, measurable expected change, approved tool/hash/command/output, and `attemptCountBefore=0`.
**Evidence:** immutable RepairOnce authorization; no operation yet.

### LO R11.REPAIR-n - One focused repair attempt

Execute exactly one repair for one family/repair class. Never repeat the same class automatically. Record actual outputs and attempt outcome in LC-I12.

### Work Package R11.5 - Produce new-generation lane fragments after RepairOnce

**Target child Task duration:** one 20-30 minute child Task per required lane/family projection.
**Files:** repaired family inputs, prior accepted lane evidence, and prior fragment hashes read-only; write only one registered new-generation lane-private fragment per child Task and append the immutable LC-I12 result for the changed family.
**Acceptance:** changed checks have measurable before/after results; every check is terminally accounted; every fragment used by the next LC-I14 binds the new intended generation. Unchanged facts are recomputed or carried forward only through the exact audited R10.1/R10.5 rule with prior-byte hashes; old-generation fragments are never mixed or relabeled. No LC-I14 or C4-C6 output is created.
**Verification:** lane producer/static gate, carry-forward authority and prior-byte hash when applicable, fragment schema/fingerprint/conservation, LC-I12 max-attempt validation, and LC-I14/C4-C6 output absence.

### Work Package R11.6 - Re-aggregate and publish exactly one LC-I14

**Target child Task duration:** 20-30 minutes.
**Files:** all accepted new-generation lane fragments read-only; write only a new LC-I14 generation using the audited R10.4 aggregator/publisher bytes.
**Acceptance:** all lanes share the same new lifecycle generation; rows are unique and Ordinal sorted; checks/fingerprints and any registered carry-forward links conserve; aggregation failure suppresses LC-I14 and every downstream output.
**Verification:** LC-I14 aggregator/locked consumer, changed-versus-unchanged fragment identity check, duplicate/mixed-generation vectors, rollback/quarantine, and C4-C6 output absence.

### Work Package R11.7 - Re-publish C4 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted replacement LC-I14 and the other twelve C4 inputs read-only; write only C4-O01 through C4-O03 using the audited R10.5 C4 publisher.
**Acceptance:** SP-40 conserves; changed-family before/after static outcome is explicit; C4 generation locks successfully; no C5/C6 output is created.
**Verification:** C4 gate, direct-input hashes, same-generation/freshness, locked consumer, and C5/C6 output absence.

### Work Package R11.8 - Re-publish C5 only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C4 and registered C5 inputs read-only; write only C5-O01 through C5-O04 using the audited R10.5 C5 publisher.
**Acceptance:** SP-50/SP-51 conserve; repair-related evidence requests and assessment states are current; no C6 output or Unity process occurs.
**Verification:** C5 gates, same-generation/freshness, locked consumer, and C6-output suppression.

### Work Package R11.9 - Re-publish C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C3-C5 generation and LC-I12 history read-only; write only C6-O01 through C6-O05 using the audited R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; failed/no-improvement RepairOnce results become `PrototypeReplacement` or `Stop` according to precedence; no further repair is authorized.
**Verification:** C6 gates, RepairOnce history, same-generation harness, locked consumer, and final R11 decision diff.

**R11 checkpoint:** wait for exact R12 Unity authorization. Staged files and C5-O03 do not authorize Unity.

---

## 11. R12 - Single-Thread Representative Unity Validation

### Work Package R12.1 - Freeze Unity environment and unavailability semantics

**Target child Task duration:** 20-30 minutes.
**Files:** read-only `ProjectSettings/ProjectVersion.txt`, `Packages/manifest.json`, approved tool metadata, and C5-O03; no Unity launch.
**Acceptance:** exact Unity version/editor SHA-256, license/seat/operator, project root, cache/output budget, network-disabled policy, allowed child processes, and foreground cancellation are approved. If unavailable, emit `UnityExecutionUnavailable`, never asset rejection.
**Evidence:** redacted environment capability record.

### Work Package R12.2 - Implement/review the C7/G4 evidence producer contract

**Target child Task duration:** 20-30 minutes per increment.
**Files:** create `docs/asset-migration/c7-g4-unity-evidence-contract.md`; implementation/test paths must be enumerated in a child plan before code changes.
**Acceptance:** C5-O03 request -> one representative queue item -> immutable LC-I09/LC-I10 evidence package is exact for Actor, Audio, Effects, Environment, and UI; no evidence may be reused across incompatible routes.
**Verification:** fixture-only queue/evidence/failure tests and no Unity launch.

### Work Package R12.3 - Freeze the single-thread queue and one-item authorizations

**Target child Task duration:** 20-30 minutes.
**Files:** machine-local immutable queue/approval records; C5-O03 read-only.
**Acceptance:** deterministic queue, one active item maximum, representative selection reason, required observation checklist, exact project/write boundaries, and one LO record per item.
**Evidence:** `activeUnityItemCount=0` before execution and complete queue conservation.

### LO R12.UNITY-n - Validate one representative only

Launch one approved Unity foreground process for one representative requirement. No parallel editor, background retry, package download, or next queue item. Capture the lane-required visible/audible/log/dependency evidence and immutable process/tool/input identities.

### Work Package R12.4 - Validate one LC-I10 evidence package

**Target child Task duration:** 20-30 minutes per representative.
**Files:** the single representative's logs, screenshots, structured LC-I10 package, queue item, and tool/process identities are read-only; no C5/C6 lifecycle output is changed.
**Acceptance:** LC-I10 is current, requirement-specific, attributable, immutable, and free of sensitive paths; Unity execution failure is distinguished from asset evidence failure; the package is frozen for later C5 consumption without assigning a C5 assessment or C6 decision here.
**Evidence:** validated/frozen LC-I10 identity and one requirement-level validation result; explicit `C5Written=false`, `C6Written=false`.

### Work Package R12.5 - Assess evidence and publish C5 only after the approved queue

**Target child Task duration:** 20-30 minutes.
**Files:** all validated/frozen LC-I10 packages, accepted C3/C4 generation, and registered C5 policy inputs read-only; write only C5-O01 through C5-O04 using the audited R10.5 C5 publisher.
**Acceptance:** all requested representative evidence is terminally assessed; SP-50/SP-51 conserve; capability suitability remains independent; generation binding or prior-stage carry-forward follows the exact audited R10.1/R10.5 rule with no in-place mutation or silent relabeling; no C6 output is created.
**Verification:** C5 gates, LC-I09/LC-I10 authority/freshness, same-generation checks, locked consumer, and C6-output suppression.

### Work Package R12.6 - Publish C6 decisions only

**Target child Task duration:** 20-30 minutes.
**Files:** accepted refreshed C3-C5 generation and repair history read-only; write only C6-O01 through C6-O05 using the audited R10.5 C6 publisher.
**Acceptance:** SP-60/SP-61 conserve; only families satisfying static plus representative requirements may become `UseOriginalAsset`; Unity unavailability remains distinct from asset rejection; no G5 execution or publication occurs.
**Verification:** C6 gates, same-generation harness, decision precedence, locked consumer, and G5-process/output absence.

**R12 checkpoint:** wait for exact R13 G5 authorization. Unity evidence does not directly set a root conclusion.

---

## 12. R13 - In-Memory G5 And Final Handoff

### Work Package R13.0 - Freeze the G5 execution mode

**Target child Task duration:** 20-30 minutes.
**Files:** read-only G5 module/tests, root summary schema, C3-C6 design, and accepted C6-O04; no output root is created.
**Acceptance:** choose exactly one mode before R13.1:

1. `InMemoryOnly` - the current authorized mode and default; G5 returns an in-memory root summary with zero publication activity.
2. `PersistentPublicationRequested` - blocked until a separate contract-change child Task freezes G5 output Artifact Registry rows, schemas, root/generation identity, writer/transaction, Failure Transitions, publication/rollback/quarantine rules, locked consumer, fixed counterexamples, and publication fault tests.

The R10 lifecycle contract does not authorize G5 publication. Merely defining publication order or a filesystem root is insufficient. If the persistent contract is not completely reviewed and committed before its exact approval, R13.1 must use `InMemoryOnly`.

**Verification:** mode declaration, current G5 code-path audit, zero-publication fixture tests, and, only for a future persistent mode, the complete new contract/fault matrix.

### Work Package R13.1 - Validate final same-generation inputs and run in-memory G5

**Target child Task duration:** 20-30 minutes.
**Files:** read-only accepted C1/C2/C6-O04 generation, G5 module/tests, and root schema; no G5 summary/report file or output root is written in `InMemoryOnly` mode.
**Acceptance:** G5 reads only a valid Passed C6-O04 handoff, verifies direct child fingerprints/conservation, returns four independent in-memory conclusions, performs zero executor/heavy/publication activity, and makes no restoration or readiness overclaim.
**Verification:** G5 validator, same-generation harness, root schema, fixed counterexamples, output-root absence, and process/write observation.

Steps:

1. Freeze accepted generation identities - 3 minutes.
2. Validate C6-O04 and direct-child fingerprints - 5 minutes.
3. Run lightweight in-memory G5 only; no heavy child or writer process - 3 minutes.
4. Validate the four independent conclusions - 5 minutes.
5. Review residual issues, failure owners, and next actions - 4 minutes.
6. Stop for human acceptance - 2 minutes.

### Work Package R13.2 - Final completion audit and handoff

**Target child Task duration:** 20-30 minutes.
**Files:** repository/evidence read-only; create or modify only an exact final handoff file named in a separate docs authorization.
**Acceptance:** audit covers registries, all conservation equations, fixed failure vectors, stale-input handling, source immutability, retained/quarantined outputs, redistribution constraints, user entry/success path, G5 mode, and the four independent conclusions.
**Evidence:** final audit matrix and list of unresolved families/capabilities; `integrationExecuted=false`, `cleanupExecuted=false`.

### Work Package R13.3 - Prepare the separate integration/cleanup authorization package

**Target child Task duration:** 20-30 minutes.
**Files:** create only an exact integration/cleanup authorization-package path named by its child Task plan; repository, remote refs, worktrees, retained evidence, and source workspace remain read-only.
**Acceptance:** the package must freeze, rather than placeholder, all of:

1. exact reviewed commit range and source/destination refs;
2. one concrete integration mechanism and operator;
3. exact commands/API operations, conflict-file list/policy, and abort/rollback method;
4. required CI/tests and observable success evidence;
5. source-derived binary inclusion/redistribution decision;
6. dirty source-workspace non-interference rule;
7. post-integration ref/ancestry verification;
8. separate cleanup targets, protected-file disposition, retained/quarantine decisions, and recoverability proof.

The dirty source workspace `C:\SoftWork\Git\StellaGaia` remains read-only and is not switched, reset, staged, or merged by this roadmap.

**Verification:** package completeness audit, read-only ref/worktree inventory, protected hashes, and `integrationExecuted=false`/`cleanupExecuted=false`.

### Actual integration and cleanup boundary

Actual merge/integration, worktree removal, parent cleanup, branch deletion, tag, release, publication, or distribution are outside this Program Roadmap. They require a new Superpowers strict-mode plan created from the accepted R13.3 package, with separate integration authorization followed by separate cleanup authorization. No R13 success state implies those actions.

The later plan may not use `git worktree prune`, `git reset --hard`, broad recursive deletion, or an extra worktree without new explicit authority. If no safe concrete integration method can be frozen, stop and hand integration to the user.

## 13. Phase Exit Matrix

| Phase | Required input | Success evidence | Does not authorize | Next exact gate |
|---|---|---|---|---|
| R7 | committed PersonalLocalMode governance | protected-state resolution + R8 plan + post-change revalidation + mode policy GREEN | real input or R8 command | R8.1 automatic preflight |
| R8 | GREEN derived state + one `ConfirmPersonalLocalRun` | conserved one-attempt snapshot + human first-capture baseline decision; any match requires an independent future cycle | C2 | baseline closure, then separate R9 contract and run approvals |
| R9 | accepted C1 + real adapter/producers/publisher | diagnostic real C2 review with SP-01..09 conserved | static/extraction/Unity | R10 lifecycle approval |
| R10 | accepted real C2 + implemented/audited lifecycle + exact R10 approval | LC-I06 -> C3-only -> lane fragments -> one LC-I14 -> C4-only -> C5-only -> provisional C6 | staging/repair/Unity/G5 publication | R11 whitelist approval |
| R11 | exact whitelist and repair cause | conserved staged batch + at most one repair/class -> lane fragment -> LC-I14 -> C4-only -> C5-only -> C6-only | Unity | R12 environment/item approvals |
| R12 | C5 requests + Unity capability | frozen LC-I10 packages -> C5-only assessment -> C6-only decisions | G5 conclusion/integration | R13 G5 approval |
| R13 | accepted same-generation C6-O04 | independent in-memory G5 conclusions + final audit + integration/cleanup authorization package | merge/cleanup/publication | new independent integration plan and approval |

## 14. Verification Before Any Completion Claim

At minimum, the owning child Task must run and read:

```powershell
git status --short --branch
git rev-parse HEAD
git rev-parse '@{upstream}'
git diff --check
Get-FileHash -Algorithm SHA256 -LiteralPath .\AGENTS.md
Get-FileHash -Algorithm SHA256 -LiteralPath .\docs\superpowers\plans\2026-07-14-stella-sora-asset-corpus-c2-sp03-sp04.md
```

Then run only the stage-specific lightweight validators explicitly authorized for that child Task. Heavy tests or producers require their own LO when they exceed the ordinary child Task boundary. Verify these paths according to stage authority rather than deleting them:

```text
Extracted
Assets/StellaGaia/Imported
Library
Temp
Obj
Build
Builds
Logs
UserSettings
```

Before their authorized stage they must be absent. After creation they must be registered, owned, bounded, and fully accounted; an unexpected existing path is Stop and preserve-for-review, not cleanup permission.

## 15. Current Stop Checkpoint

```text
currentPhase=R7-PersonalLocalModeMigration
mode=PersonalLocalMode
humanFormFieldCount=0
PB-SP01=6 Unevaluated until R8.1
R8ThroughR13Authorized=false
realSourceAccessed=false
phaseBExecuted=false
nextAction=Complete PersonalLocalMode governance/test migration, then run R7.4/R7.5 validation and R8.1 automatic preflight. Request `ConfirmPersonalLocalRun` only after GREEN and immediately before LO.
```
