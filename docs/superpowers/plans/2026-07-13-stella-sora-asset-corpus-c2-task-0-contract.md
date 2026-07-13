# StellaSora C2 Task 0 Contract Gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze AR-S01, AR-S01a, AR-S01b, AR-S01c, AR-S02, and AR-S04a through exact-shape fixture validation, validate the committed C1 intake, and land a fixture-only read-only RED→GREEN harness without standalone C2 private schema files.

**Architecture:** C2 Task 0 is delivered as three independently GREEN slices. Task 0A freezes the two-row AR-I07, AR-I10, isolated negatives, and structural harness; after its commit the fixtures are current-HEAD blobs. Task 0B extends the harness with full C1/C0 intake. Task 0C adds HEAD freshness and dynamic read-only proof. No slice imports or creates a production C2 module. This plan must be independently approved and committed in its own plan-only commit before Task 0A starts.

**Tech Stack:** PowerShell 7, `System.Text.Json`, SHA-256, Git blob bytes, checked-in JSON fixtures.

---

## Authority And Scope

Read completely before implementation:

- `AGENTS.md`
- `docs/superpowers/specs/2026-07-12-stella-sora-asset-corpus-c2-discovery-design.md`
- `docs/superpowers/specs/2026-07-10-stella-sora-asset-corpus-and-reuse-design.md`
- AR-I01 through AR-I06 at their Artifact Registry paths

Task 0 creates exactly:

- `Tools/AssetImport/Test-DiscoveryGateContract.ps1`
- `Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json`
- `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json`
- `Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json`
- `Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json`

Task 0 creates no `.schema.json`, module, AR-I08, AR-I09, AR-P01, AR-O01–AR-O05, `Extracted`, binary asset, or third-party content. It does not edit C0/C1 files. The untracked repository `AGENTS.md` is pre-existing user state: never stage, modify, delete, or count it as Task output.

## Frozen Task 0 Contract

- AR-S01, AR-S01a, AR-S01b, and AR-S01c are validated against committed C1/C0 inputs.
- AR-S02 and AR-S04a are frozen by the positive AR-I07/AR-I10 fixtures.
- The positive AR-I07 contains two valid observations. Row 0 is `r1` with empty dependencies and null canonical evidence. Row 1 has one complete dependency locator and one complete non-null canonical evidence object, so every AR-S02 nested exact shape is instantiated by positive fixture data. The P1 simultaneous failure/conservation corpus is not Task 0 output.
- `invalid-object-observation.json` copies the positive document and removes only `rows[0].classId`; expected issue string is literal `FT-05:`, its HI-02 fallback ID over the negative file's exact SHA and row index 0, and literal `:InvalidObservation`.
- `invalid-machine-path.json` copies the positive document and changes only `rows[0].evidence[0]` to `C:/machine/evidence.json`; expected issue string is literal `FT-04:`, that file's HI-02 fallback ID at row index 0, and literal `:UnsafePath`.
- Both negative files are harness-only mutation vectors. They are not AR-I07–AR-I09 runtime artifacts, never appear in AR-I10 or HI-13b, and never enter SP-08.
- AR-I10 contains exactly the AR-I07 portable path and exact lowercase SHA-256 of committed AR-I07 bytes.
- The harness is read-only: `childProcessCount` measures Git blob-reader processes, `heavyChildProcessCount=0`, `createdRepositoryPathCount=0`, and no repository path is written while it runs.

---

### Task 0A: Freeze Exact Fixtures And Structural RED→GREEN Harness

**Files:**

- Create: `Tools/AssetImport/Test-DiscoveryGateContract.ps1`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json`
- Create: `Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json`

- [ ] **Step 1: Capture the pre-existing worktree baseline**

Run:

```powershell
[string[]]$baseline = @(git status --porcelain=v1)
if ($baseline -notcontains '?? AGENTS.md') { throw 'Expected pre-existing untracked AGENTS.md.' }
if ($baseline | Where-Object { $_ -ne '?? AGENTS.md' }) {
    throw "Unexpected pre-Task state:`n$($baseline -join "`n")"
}
if (Test-Path -LiteralPath .\Extracted) { throw 'Extracted exists before Task 0.' }
```

Expected: exit 0. Save the output in the Task evidence.

- [ ] **Step 2: Write the self-contained RED harness**

Create `Test-DiscoveryGateContract.ps1` with parameters `FixtureRoot` and `Case`. Freeze the allowed case names immediately as `Structural`, `C1Ledger`, `C1Summary`, `C0Inputs`, `Freshness`, `Safety`, and `All`; a directly requested branch not yet implemented forms its issue by concatenating literal `Missing validator branch: `, the exact case name, and literal `.` rather than causing parameter binding failure. `All` is incrementally extended only in the RED edit that introduces a branch: 0A commits `Structural`; 0B adds `C1Ledger`, then `C1Summary`, then `C0Inputs`; 0C adds `Freshness`, then `Safety`. Each slice commits with its current `All` GREEN; 0C freezes the final six-branch order. It must define these local functions, not import a C2 module:

```powershell
function Read-StrictJson([string]$Path)
function Assert-ExactProperties([object]$Value,[string[]]$Expected,[string]$Subject)
function Assert-PortablePath([string]$Value,[string]$Subject)
function Get-ExactSha256([string]$Path)
function Get-HeadBlobBytes([string]$RepositoryRoot,[string]$PortablePath)
function Get-PositiveIssues([string]$RepositoryRoot,[string]$FixtureRoot)
function Get-NegativeIssues([string]$Path,[string]$ExpectedCode)
```

The terminal result is exactly:

```powershell
[pscustomobject][ordered]@{
    status = if ($issues.Count -eq 0) { 'Passed' } else { 'Failed' }
    issueCount = $issues.Count
    issues = $issues.ToArray()
    verifiedC1ArtifactCount = $verifiedC1ArtifactCount
    positiveFixtureCount = $positiveFixtureCount
    negativeFixtureCount = $negativeFixtureCount
    childProcessCount = $childProcessCount
    heavyChildProcessCount = 0
    createdRepositoryPathCount = $createdRepositoryPathCount
    durationMs = $stopwatch.ElapsedMilliseconds
}
```

Serialize one compressed JSON line, then exit 1 when issues exist. A missing fixture issue is formed by concatenating literal `Missing contract artifact: `, its Artifact Registry portable path, and literal `.`.

- [ ] **Step 3: Run RED before creating fixtures**

```powershell
$raw = & pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case Structural 2>&1
$exit = $LASTEXITCODE
$result = $raw[-1] | ConvertFrom-Json
if ($exit -ne 1) { throw "Expected RED exit 1, got $exit." }
if ($result.status -cne 'Failed' -or $result.issueCount -ne 1) { throw 'Expected exactly one RED issue.' }
[string[]]$expectedIssues = @('Missing contract artifact: Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json.')
if (Compare-Object @($result.issues) $expectedIssues -SyncWindow 0) { throw "Unexpected RED issues: $($result.issues -join ';')" }
if ($result.heavyChildProcessCount -ne 0 -or $result.createdRepositoryPathCount -ne 0) { throw 'RED harness caused a side effect.' }
if (Test-Path -LiteralPath .\Extracted) { throw 'RED created Extracted.' }
```

Expected: all assertions pass. This is the required RED evidence.

- [ ] **Step 4: Add the valid two-row AR-I07 fixture**

Create canonical CT-15 JSON with exact top-level order `schemaVersion`, `snapshotId`, `inputFingerprint`, `rows`. Copy snapshot/input identity from AR-I01. Row 0 is valid `r1` from the approved spec: ToolA/1.0.0, `pc-install-primary`, `SourceCorpus/PcInstall/game-data.bundle`, pathId `10`, classId `1`, size `100`, Sprite/Hero, empty dependencies, 64 lowercase `1` content hex, Parsed configuration, null canonical evidence, ExactLocator correlation, and portable evidence. Row 1 uses pathId `11`, classId `1`, Sprite/HeroDependency, one dependency locator targeting pathId `10`/classId `1`, and canonical evidence `{memberPlatform: Pc, proposedMatchStatus: ExactDuplicate, proposedEquivalenceFingerprint: 64 lowercase 2 hex digits, evidence: [portable path]}`. Compute both HI-03 observation IDs, the dependency HI-08 ID, HI-04 digest, and HI-05 correlation IDs using the approved literal encodings before writing; never invent repeated-character derived IDs.

- [ ] **Step 5: Generate AR-I10 from exact AR-I07 bytes**

Use a temporary PowerShell object only to generate the manifest; do not add a generator script:

```powershell
$path = 'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json'
$sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
$handoff = Get-Content Tools/AssetImport/Fixtures/SourceCorpusGate/valid-c2-source-corpus-handoff.json -Raw | ConvertFrom-Json
$manifest = [ordered]@{
    schemaVersion = '1.0.0'
    snapshotId = [string]$handoff.snapshotId
    inputFingerprint = [string]$handoff.inputFingerprint
    entries = @([ordered]@{ path = $path; sha256 = $sha })
}
$text = $manifest | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText(
    'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
    ($text.Replace("`r`n","`n").TrimEnd("`r","`n") + "`n"),
    [Text.UTF8Encoding]::new($false)
)
```

- [ ] **Step 6: Add the two isolated negative fixtures**

Generate each from the parsed positive document and change one property only. Preserve CT-15 property order/encoding. Confirm mechanically:

```powershell
$positive = Get-Content Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json -Raw | ConvertFrom-Json -Depth 100
$missing = Get-Content Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json -Raw | ConvertFrom-Json -Depth 100
$unsafe = Get-Content Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json -Raw | ConvertFrom-Json -Depth 100
if ($missing.rows[0].PSObject.Properties.Name -ccontains 'classId') { throw 'Missing-field fixture still has classId.' }
if ($unsafe.rows[0].evidence[0] -cne 'C:/machine/evidence.json') { throw 'Unsafe-path mutation is not exact.' }
if (@($missing.rows).Count -ne 2 -or @($unsafe.rows).Count -ne 2) { throw 'Negative fixture must preserve both positive rows.' }
$positiveRow1 = $positive.rows[1] | ConvertTo-Json -Depth 100 -Compress
if (($missing.rows[1] | ConvertTo-Json -Depth 100 -Compress) -cne $positiveRow1) { throw 'Missing-field fixture changed row 1.' }
if (($unsafe.rows[1] | ConvertTo-Json -Depth 100 -Compress) -cne $positiveRow1) { throw 'Unsafe-path fixture changed row 1.' }
```

- [ ] **Step 7: Implement and run the Structural case (AR-S02, AR-S04a, HI-02/03/04/05/08; FT-04/05)**

Implement only fixture parsing, complete positive nested exact-shape/identity validation, negative one-mutation comparison, and exact HI-02 negative issues. Run:

```powershell
$result = pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case Structural | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $result.status -cne 'Passed' -or $result.issueCount -ne 0) { throw ($result | ConvertTo-Json -Depth 20) }
if ($result.positiveFixtureCount -ne 2 -or $result.negativeFixtureCount -ne 2) { throw 'Structural fixture counts are incorrect.' }
```

Expected: GREEN without consulting Git HEAD freshness or C1 intake.

- [ ] **Step 8: Commit Task 0A and rerun Structural GREEN**

Verify the exact five Task paths after excluding baseline `AGENTS.md`, then:

```powershell
[string[]]$actual = @(git status --porcelain=v1 | Where-Object { $_ -ne '?? AGENTS.md' } | ForEach-Object { $_.Substring(3).Replace('\','/') } | Sort-Object)
[string[]]$expected = @(
    'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json',
    'Tools/AssetImport/Test-DiscoveryGateContract.ps1'
) | Sort-Object
if (Compare-Object $actual $expected) { throw "Unexpected Task 0A paths:`n$(git status --short)" }
git diff --check
git add -- Tools/AssetImport/Test-DiscoveryGateContract.ps1 Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json
git commit -m "test: freeze C2 discovery fixture contracts"
pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case Structural
if ($LASTEXITCODE -ne 0) { throw 'Task 0A post-commit Structural verification failed.' }
pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case All
if ($LASTEXITCODE -ne 0) { throw 'Task 0A current All aggregation failed.' }
```

Expected: Task 0A is independently GREEN. Stop for its spec/quality checkpoint before Task 0B.

---

### Task 0B: Freeze C1 And C0 Intake

**Files:**

- Modify: `Tools/AssetImport/Test-DiscoveryGateContract.ps1`

Use this command after each 0B RED or GREEN edit, substituting the exact case and expected status/issue described by that step:

```powershell
$lines = @(& pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case $caseName 2>&1)
$exitCode = $LASTEXITCODE
$result = $lines[-1] | ConvertFrom-Json
if ($exitCode -ne $expectedExit -or $result.status -cne $expectedStatus) { throw ($lines -join "`n") }
if (Compare-Object @($result.issues) $expectedIssues -SyncWindow 0) { throw "Unexpected issues: $($result.issues -join ';')" }
```

- [ ] **Step 1: Add C1 ledger RED assertions (AR-S01, AR-S01a, AR-S06; FT-01/02)**

Add `-Case C1Ledger` tests first and run them before the validator branch exists. Expected exact RED issue: `Missing validator branch: C1Ledger.`
In the same RED edit, append `C1Ledger` to `All` after `Structural`; both the direct case and `All` must be RED until the branch is implemented.

- [ ] **Step 2: Validate AR-I01 handoff and AR-I02 ledger, then run C1Ledger GREEN**

Freeze exact top-level property order/sets. For every source, file, status, tool-version, and object row in AR-I02, assert the complete AR-S06 nested property set and CT type/domain. Assert sources/files/toolVersions are in their declared Ordinal order, objects is empty, `parseStatus=status.extraction`, paths are portable, and every vocabulary value exists in AR-I05. Cross-check AR-I01 snapshot/fingerprint/count/bytes/objectCount=0 and ledger path against AR-I02.

- [ ] **Step 3: Add AR-I03 RED assertions (AR-S01b, SP-01; FT-01/03/10)**

Add `-Case C1Summary` and require exact RED `Missing validator branch: C1Summary.`
In the same RED edit append it to `All` after `C1Ledger`.

- [ ] **Step 4: Validate AR-I03 summary and C1 conservation, then run C1Summary GREEN**

Assert exact summary/source/exclusion property sets and CT types. Cross-check AR-I01 summary path, snapshot, fingerprint, source/file/byte counts; cross-check every source ID/kind/root fingerprint; recompute all C1 count/byte equations and reject machine paths.

- [ ] **Step 5: Add immutable-C0 RED assertions (AR-S01c, AR-I04/05/06; FT-02/03)**

Add `-Case C0Inputs` and require exact RED `Missing validator branch: C0Inputs.`
In the same RED edit append it to `All` after `C1Summary`.

- [ ] **Step 6: Validate immutable C0 inputs, then run C0Inputs GREEN**

Strictly parse all three JSON documents and compare exact file SHA-256 to the six-value Existing-input byte registry. Assert their registry paths are the only C0 inputs read; never reserialize them for freshness.

- [ ] **Step 7: Run Task 0B GREEN, verify scope, and commit**

Run `C1Ledger`, `C1Summary`, and `C0Inputs` separately and require status Passed, issueCount 0, and actual per-run verified counts `2`, `1`, and `3` respectively. Then run the current four-branch `All` and require status Passed, issueCount 0, and aggregate `verifiedC1ArtifactCount=6`. Excluding baseline `AGENTS.md`, require the only changed path to be the harness, then:

```powershell
git add -- Tools/AssetImport/Test-DiscoveryGateContract.ps1
git commit -m "test: freeze C2 C1 intake contract"
```

Rerun the three direct cases and the current four-branch `All` after commit. Expected: Task 0B independently GREEN. Stop for its checkpoint.

---

### Task 0C: Freeze HEAD Freshness And Read-Only Evidence

**Files:**

- Modify: `Tools/AssetImport/Test-DiscoveryGateContract.ps1`

- [ ] **Step 1: Re-run Structural regression (AR-S02, HI-03/04/05/08; FT-04/05)**

Assert top-level, row, dependency-locator, canonical-evidence, correlation-evidence, and evidence exact property sets. Validate null/non-null branches, CT types, Ordinal uniqueness/sorting, and portable paths. Independently recompute both observation IDs and every nested derived ID from literal bytes and require exact equality.

- [ ] **Step 2: Add HEAD-freshness RED mutation (AR-S04a, HI-13a; FT-03)**

In the same RED edit append `Freshness` to `All` after `C0Inputs`. In TEMP, copy the committed fixture set, mutate the AR-I07 copy, and require exactly `FT-03:C2Check:Freshness:StaleFingerprint`. Do not modify repository fixtures.

- [ ] **Step 3: Validate AR-I10 and committed authority, then run Freshness GREEN**

Use `System.Diagnostics.Process` with redirected `StandardOutput.BaseStream` to read exact `git show` bytes and increment `childProcessCount` once per Git process. Require: AR-I10 itself is tracked and its worktree bytes equal its current-HEAD blob; AR-I07 is tracked in the same HEAD; AR-I07 worktree bytes equal its HEAD blob; AR-I10 contains every/only AR-I07; and manifest SHA equals both AR-I07 worktree and HEAD-blob SHA. Test the raw-byte reader against AR-I01's registered SHA before using it for optional inputs.

- [ ] **Step 4: Re-run isolated negative ownership (HI-02, FT-04/05; outside SP-08)**

For each negative, compute HI-02 from that negative file's exact SHA, portable path, and row index 0. Require the complete issue array to equal exactly one row containing that subject and the designated reason. Normalize the complete two-row negative and positive documents to ordered trees; prove every top-level value and row 1 are identical and row 0 differs only by one removed `classId` property or one changed evidence scalar. Confirm neither negative path occurs in AR-I10.

- [ ] **Step 5: Parse AST and prove the harness is read-only**

```powershell
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\Tools\AssetImport\Test-DiscoveryGateContract.ps1), [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$forbiddenCommands = @(
    'Set-Content','Add-Content','Out-File','New-Item','Remove-Item','Move-Item','Copy-Item',
    'Rename-Item','Start-Process','Unity','AssetRipper','RefreshSnapshot'
)
$danger = @($ast.FindAll({
    param($node)
    $node -is [Management.Automation.Language.CommandAst] -and
    $node.GetCommandName() -in $forbiddenCommands
}, $true))
if ($danger.Count) { throw ($danger.Extent.Text -join "`n") }
$writes = @($ast.FindAll({
    param($node)
    ($node -is [Management.Automation.Language.RedirectionAst]) -or
    ($node -is [Management.Automation.Language.InvokeMemberExpressionAst] -and
     $node.Member.Value -match '^(Write|WriteAll|Create|Delete|Move|Copy|Replace|SetAttributes)')
}, $true))
if ($writes.Count) { throw ($writes.Extent.Text -join "`n") }
```

Use this external verifier to wrap the Safety RED, pre-commit All GREEN, and post-commit All GREEN runs:

```powershell
function Get-RepositoryFileSnapshot([string]$RepositoryRoot) {
    $root = [IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/')
    [string[]]$rows = @(Get-ChildItem -LiteralPath $root -Recurse -File -Force | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/')
        if ($relative -ceq '.git' -or $relative.StartsWith('.git/',[StringComparison]::Ordinal)) { return }
        $sha = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $relative + '|' + $sha
    })
    [Array]::Sort($rows,[StringComparer]::Ordinal)
    return ,$rows
}
function Invoke-ReadOnlyHarnessProbe([scriptblock]$Run) {
    $root = (Resolve-Path '.').Path
    [string[]]$beforeFiles = @(Get-RepositoryFileSnapshot $root)
    [string[]]$beforeStatus = @(git status --porcelain=v1)
    [object[]]$output = @(& $Run)
    $exitCode = $LASTEXITCODE
    [string[]]$afterFiles = @(Get-RepositoryFileSnapshot $root)
    [string[]]$afterStatus = @(git status --porcelain=v1)
    if (Compare-Object $beforeFiles $afterFiles -SyncWindow 0) { throw 'Harness changed repository file paths or bytes.' }
    if (Compare-Object $beforeStatus $afterStatus -SyncWindow 0) { throw 'Harness changed repository status.' }
    return [pscustomobject]@{ Output = $output; ExitCode = $exitCode }
}
```

This includes tracked files, all five Task files, the plan, and untracked `AGENTS.md`; it does not trust harness-reported counters. Expected: zero parser errors, zero write-capable invocations, and byte-identical repository snapshots. Literal names used by the AST test itself are not command invocations.

- [ ] **Step 6: Run Safety RED, implement the branch, and run Safety GREEN**

In the same RED edit append `Safety` to `All` after `Freshness`, freezing the final six-branch order. First run the missing Safety branch through the wrapper:

```powershell
$probe = Invoke-ReadOnlyHarnessProbe { & pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case Safety }
$result = $probe.Output[-1] | ConvertFrom-Json
if ($probe.ExitCode -ne 1 -or $result.issueCount -ne 1 -or $result.issues[0] -cne 'Missing validator branch: Safety.') { throw ($probe.Output -join "`n") }
```

Then implement Safety to report measured Git `childProcessCount`, `heavyChildProcessCount=0`, and `createdRepositoryPathCount=0`; rerun:

```powershell
$probe = Invoke-ReadOnlyHarnessProbe { & pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case Safety }
$result = $probe.Output[-1] | ConvertFrom-Json
if ($probe.ExitCode -ne 0 -or $result.status -cne 'Passed' -or $result.issueCount -ne 0) { throw ($probe.Output -join "`n") }
if ($result.heavyChildProcessCount -ne 0 -or $result.createdRepositoryPathCount -ne 0) { throw 'Safety counters failed.' }
```

- [ ] **Step 7: Run complete pre-commit GREEN through the read-only wrapper and verify exact changed paths**

Because Task 0A already committed AR-I07/AR-I10, `-Case All` must now be GREEN before the Task 0C commit:

```powershell
$probe = Invoke-ReadOnlyHarnessProbe { & pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case All }
$result = $probe.Output[-1] | ConvertFrom-Json
if ($probe.ExitCode -ne 0 -or $result.status -cne 'Passed' -or $result.issueCount -ne 0) { throw ($probe.Output -join "`n") }
```

Then verify the only changed path after excluding baseline `AGENTS.md` is `Tools/AssetImport/Test-DiscoveryGateContract.ps1`.

```powershell
[string[]]$actual = @(git status --porcelain=v1 | Where-Object { $_ -ne '?? AGENTS.md' } | ForEach-Object { $_.Substring(3).Replace('\','/') } | Sort-Object)
[string[]]$expected = @('Tools/AssetImport/Test-DiscoveryGateContract.ps1')
if (Compare-Object $actual $expected) { throw "Unexpected Task 0 paths:`n$(git status --short)" }
git diff --check
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 0 created Extracted.' }
```

- [ ] **Step 8: Commit only Task 0C harness change**

```powershell
git add -- Tools/AssetImport/Test-DiscoveryGateContract.ps1
git commit -m "test: freeze C2 discovery freshness gate"
```

Do not stage `AGENTS.md` or this already-committed plan.

- [ ] **Step 9: Run post-commit GREEN verification through the wrapper**

```powershell
$probe = Invoke-ReadOnlyHarnessProbe { & pwsh -NoProfile -File .\Tools\AssetImport\Test-DiscoveryGateContract.ps1 -Case All }
$result = $probe.Output[-1] | ConvertFrom-Json
if ($probe.ExitCode -ne 0) { throw 'Task 0 gate failed after commit.' }
if ($result.status -cne 'Passed' -or $result.issueCount -ne 0) { throw ($result | ConvertTo-Json -Depth 20) }
if ($result.verifiedC1ArtifactCount -ne 6) { throw 'C1 intake count is not six.' }
if ($result.positiveFixtureCount -ne 2 -or $result.negativeFixtureCount -ne 2) { throw 'Fixture counts are incorrect.' }
if ($result.childProcessCount -lt 1 -or $result.heavyChildProcessCount -ne 0 -or $result.createdRepositoryPathCount -ne 0) { throw 'Task 0 process/safety accounting is incorrect.' }
git diff --check HEAD^ HEAD
[string[]]$committed = @(git diff --name-only HEAD^ HEAD | Sort-Object)
[string[]]$expectedCommitted = @('Tools/AssetImport/Test-DiscoveryGateContract.ps1')
if (Compare-Object $committed $expectedCommitted) { throw 'Task 0 commit paths are not exact.' }
[string[]]$task0Range = @(git diff --name-only HEAD~3 HEAD | Sort-Object)
[string[]]$expectedRange = @(
    'Tools/AssetImport/Fixtures/DiscoveryGate/expected-discovery-inputs.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/invalid-machine-path.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/invalid-object-observation.json',
    'Tools/AssetImport/Fixtures/DiscoveryGate/object-observations.json',
    'Tools/AssetImport/Test-DiscoveryGateContract.ps1'
) | Sort-Object
if (Compare-Object $task0Range $expectedRange) { throw 'Combined Task 0 paths are not exact.' }
if (git diff --cached --name-only) { throw 'Index is not clean.' }
[string[]]$remaining = @(git status --porcelain=v1)
if ($remaining.Count -ne 1 -or $remaining[0] -ne '?? AGENTS.md') { throw "Unexpected final worktree:`n$($remaining -join "`n")" }
if (Test-Path -LiteralPath .\Extracted) { throw 'Task 0 created Extracted.' }
```

Expected: GREEN, exact counts, zero side effects, and exactly three independently GREEN Task 0 slice commits. If GREEN fails, amend only the failing slice commit after restoring its RED→GREEN evidence.

**Stop condition:** after independent specification review, independent quality review, and fresh controller verification approve this commit, stop. Do not begin hashing/intake production code or Task 1.
