# StellaGaia Asset Migration

StellaGaia uses a Unity-first, sample-gated workflow to evaluate whether selected StellaSora assets can be migrated into a local fan prototype without modifying the installed StellaSora client.

## Language

**Source Install**:
The local installed StellaSora client used only as a read-only source of files.
_Avoid_: source project, original workspace, live dependency

**Target Workspace**:
The StellaGaia repository root where Unity project files, scripts, documentation, and approved imported assets live.
_Avoid_: extracted copy, migration clone

**Extracted Workspace**:
A git-ignored intermediate area under the Target Workspace for copied samples, converted audio, logs, and tool exports.
_Avoid_: final assets, imported assets, source mirror

**Sample Manifest**:
The checked-in list of representative source-relative files chosen for the first migration gate.
_Avoid_: batch list, full asset catalog

**Copied Sample**:
A file copied from the Source Install into the Extracted Workspace with source mapping and hash logs.
_Avoid_: imported asset, accepted asset

**Raw Asset Copy**:
A source resource copied into the Extracted Workspace while preserving its source-relative path.
_Avoid_: imported asset, reconstructed asset, accepted asset

**Asset Acquisition Gate**:
A read-only gate that records whether StellaSora files, bundles, decoded media, AssetRipper exports, and optional external-tool routes are sufficient to support Unity import triage. It can raise confidence that assets can be located and extracted, but it cannot grant **Development-Usable Asset** status.
_Avoid_: original asset reuse gate, Unity acceptance, gameplay approval

**AssetLocated**:
A status meaning the source package, bundle, or data file is present and indexed.
_Avoid_: extracted asset, usable asset

**ExtractedReadable**:
A status meaning a tool can read or export the asset data into an inspectable form.
_Avoid_: imported asset, visible proof

**CrossToolVerified**:
A status meaning two or more evidence routes, such as inventory plus decode report or AssetRipper export plus reference graph, agree enough to continue reconstruction.
_Avoid_: original fidelity proof, Unity pass

**SemanticContextRecovered**:
A status meaning script fields, Wwise bank/event hints, names, or bundle provenance improve the meaning of an extracted asset.
_Avoid_: final gameplay semantics, complete source recovery

**UnityImportCandidate**:
A status meaning the extracted/reconstructed candidate is ready for focused Unity import triage.
_Avoid_: Development-Usable Asset, accepted prefab, gameplay-ready content

**ReconstructedPrototypeAsset**:
A locally rebuilt Unity-facing asset such as a prototype Animator Controller, UI Canvas prefab, or room-module assembly that uses extracted StellaSora media as inputs.
_Avoid_: original project asset, original prefab recovery

**Android Install Payload**:
The local Android package/cache input under the Target Workspace, currently `Android/`, containing APK, DATA cache, optional OBB, split APKs, or asset packs for read-only dependency comparison.
_Avoid_: final Unity assets, source install, batch import

**Android Package Intake**:
A read-only scan that checks whether the Android Install Payload contains Unity data, AssetBundles, Addressables catalog evidence, Wwise banks, or cache files that may help close missing dependencies.
_Avoid_: extraction pass, acceptance gate, import proof

**Android/PC Bundle Comparison**:
A read-only comparison between Android and PC Unity bundle names, paths, sizes, and categories used to choose focused dependency-closure slices.
_Avoid_: dependency closure, visible validation, accepted asset

**Focused Variant Slice**:
A small staged set of Android and PC bundles chosen from comparison evidence for AssetRipper export and missing dependency measurement.
_Avoid_: batch expansion, category migration, accepted room

**CAB Set-Cover Closure**:
A dependency repair attempt that chooses bundles from a CAB index to cover missing CAB ids reported by AssetRipper.
_Avoid_: complete dependency graph, proof of usability, batch expansion

**Unity Export Reference Graph**:
A static scan of an AssetRipper-exported Unity project that maps `.meta` GUIDs and YAML references in prefabs, scenes, materials, animation clips, controllers, and related text assets.
_Avoid_: visible validation, dependency closure, render proof

**Deadbeef Placeholder GUID**:
An AssetRipper-exported YAML reference containing marker-like GUID text such as `deadbeef` or `deadf00d`. It is treated as an extraction/reconstruction warning until a Unity visible test proves the referenced object is not required.
_Avoid_: normal missing bundle, accepted reference

**Placeholder Reference Context**:
A static classification of **Deadbeef Placeholder GUID** occurrences by YAML property, Unity fileID, source extension, and likely dependency kind such as material, mesh, texture, animation, timeline, lighting, or Wwise binding.
_Avoid_: repair proof, visual proof, dependency closure

**Static Renderable Salvage Candidate**:
An exported prefab or asset with no ordinary missing GUIDs, no zero GUIDs, no **Deadbeef Placeholder GUID** references, and static evidence of renderable geometry or renderer components. It still requires Unity visible validation before it can become a **Development-Usable Asset**.
_Avoid_: visible pass, accepted room module, batch-ready asset

**Environment Module Salvage**:
The strategy of rebuilding a room from small **Static Renderable Salvage Candidate** prefabs when full StellaSora scenes remain broken.
_Avoid_: full room reuse, original scene recovery, gameplay-ready map

**Module Salvage Slice**:
A small extracted Unity project under the **Extracted Workspace** that contains a curated set of environment module prefabs and their GUID dependencies for focused validation.
_Avoid_: final room scene, accepted environment pack, batch import

**Unity Built-in Resource GUID**:
Unity-reserved YAML references such as `0000000000000000e000000000000000` and `0000000000000000f000000000000000`, used for Unity default resources and `unity_builtin_extra`.
_Avoid_: missing extracted asset, CAB dependency

**Decoded Audio Sample**:
A Wwise `.wem` sample converted into Unity-readable audio for validation.
_Avoid_: music mapping, bank event

**Decoded Audio Collection**:
The full set of inventoried Wwise `.wem` files decoded into project-local Unity-readable WAV files.
_Avoid_: Wwise event map, final audio implementation

**Minimum Audio Selection Manifest**:
The checked-in list of decoded WAV candidates selected for the first combat audio proof, including one BGM candidate, three SFX candidates, and optional voice. It proves file availability and media readability only when paired with ffprobe validation; Wwise event meaning and Unity playback still require separate validation.
_Avoid_: final audio mix, Wwise event mapping, Unity playback pass

**Bank Media Decode**:
A focused extraction of Wwise media embedded inside `.bnk` `DIDX`/`DATA` chunks into project-local WEM/WAV files under the **Extracted Workspace**. It can improve SFX candidate selection by tying a media file to a semantic bank such as `Impact.bnk`, but it is not complete Wwise event mapping or audible validation.
_Avoid_: event reconstruction, final SFX mapping, Unity playback pass

**Minimum UI Reward Selection Manifest**:
The checked-in list of StellaSora UI, drop, reward, and upgrade-card art candidates selected from an AssetRipper export for the first vertical-slice art proof. It proves only file existence, static PNG readability, and known prefab placeholder/script risks; Unity visible validation and dependency repair are still required before these candidates can satisfy **Development-Usable Asset**.
_Avoid_: accepted reward art, imported card UI, visible sprite pass

**Sample Validation Scene**:
The Unity scene used to check whether copied samples and imported audio can load in the project.
_Avoid_: final gameplay scene, import proof

**Imported Unity Asset**:
A Unity-readable asset stored under `Assets/StellaGaia/` and accepted for project use.
_Avoid_: copied sample, extracted file

**Visible Sample**:
A visual sample that has been observed in Unity with its critical dependencies present.
_Avoid_: loaded bundle, export success

**Visible Smoke Test**:
A repeatable Unity render check that produces a non-empty screenshot for representative exported assets.
_Avoid_: import log, bundle load, file count

**Development-Usable Asset**:
An asset that Unity can import and reference for prototype development, with visible or audible evidence and known extraction issues documented.
_Avoid_: raw copy, exported candidate, assumed-ready asset

**Original Asset Reuse Gate**:
The decision gate that proves extracted StellaSora media still carries its recognizable original mesh, texture, audio, or effect data in Unity. This gate rejects white models, pink shaders, empty particles, missing-room fragments, and bundle-load-only evidence.
If this gate cannot be passed for the minimum visual slice, the Hades-like project does not advance beyond extraction tooling and repair experiments.
_Avoid_: import success, fallback-only proof, placeholder readiness

**Single-Asset Reuse Candidate**:
One specific exported prefab, scene, texture, or audio clip that has direct Unity evidence for recognizable reuse, while its wider category remains blocked from batch expansion.
_Avoid_: category pass, batch-approved asset, final content pack

**Semantic Material Reassignment**:
A repair step that replaces generic AssetRipper fallback materials such as `Lit_116` with better-named materials exported in the same project, such as `Roguelike_2_Battle_009_Building01`. This can recover material identity and color parameters, but it is not texture restoration unless a real texture binding is also restored.
_Avoid_: texture fidelity, original shader recovery, final material

**Semantic Material Candidate**:
A scored, static candidate material from a larger AssetRipper export that may replace a generic `Lit_*` material slot in a module slice. It is only a repair candidate until applied and revalidated; if its texture fields still contain **Deadbeef Placeholder GUID** references, it does not restore original texture fidelity.
_Avoid_: repaired material, accepted material, texture proof

**Offline Semantic Material Rebind**:
A static repair step that copies scored **Semantic Material Candidate** files into an ignored module slice, sanitizes placeholder shader or texture references, and rewrites prefab renderer material slots away from generic `Lit_*` materials. It can improve material identity and color parameters, but it does not recover original texture fidelity when placeholders are cleared to empty texture refs.
_Avoid_: texture restoration, visible pass, final material import

**Offline Semantic Material Texture Rebind**:
A static repair step that copies original texture assets from a focused AssetRipper texture export into an ignored module slice, then binds only exact material-name to texture-base matches back into semantic materials. It is stronger than clearing texture placeholders, but it is still not a **Visible Sample** or a **Development-Usable Asset** until Unity renders the result recognizably.
_Avoid_: complete room fidelity, guessed texture match, visible pass

**Manual Texture Mapping Manifest**:
A small reviewed CSV that records human-approved texture bindings for materials where exact material-name matching is insufficient. It can be used to generate an auditable follow-up **Offline Semantic Material Texture Rebind**, but each row remains a repair hypothesis until Unity visible validation and fidelity review confirm the result.
_Avoid_: auto-binding rule, texture proof, accepted material

**Offline Fallback Shader Repair**:
A static repair step inside an ignored AssetRipper export or module slice that replaces **Deadbeef Placeholder GUID** shader references with a local fallback shader asset so Unity YAML references are no longer broken. It is not original shader recovery, texture restoration, or visible validation.
_Avoid_: original material fidelity, render proof, accepted shader

**Rejected Asset**:
An extracted or exported asset that remains invisible, unreadable, or unusable after the planned dependency, repair, and Unity validation attempts for its category.
_Avoid_: temporarily broken asset, unvalidated candidate

**Asset Acceptance Manifest**:
The record that assigns each candidate asset or category a gate status such as pending export, repair candidate, development usable, or rejected.
_Avoid_: inventory list, copy log

**Minimum Vertical Slice Asset Manifest**:
The checked-in record of the exact StellaSora-derived assets needed before the Hades-like gameplay mainline can start: player, enemy, effect, room/module solution, combat music, combat SFX, reward item visuals, and upgrade card visuals. It can list candidates and blockers, but it does not grant gameplay approval unless all required entries and the **Original Asset Reuse Gate** pass.
_Avoid_: gameplay task list, placeholder asset list, batch import permission

**Extraction Bug**:
A defect introduced or exposed by extraction/import, such as missing scripts, broken material or mesh references, pink shaders, unreadable media, or invisible representative prefabs.
_Avoid_: gameplay tuning issue, design difference

**UsableWithKnownIssues**:
A validation status for assets that show visible or audible evidence in Unity but still have documented missing dependencies or non-blocking extraction issues.
_Avoid_: fully accepted, batch-cleared

**AssetRipper Export**:
A manual tool export from copied AssetBundle samples into the Extracted Workspace for inspection and reconstruction.
_Avoid_: automatic import, batch migration

**Source Safety Guard**:
A verification step that confirms the workflow did not create migration output inside the Source Install.
_Avoid_: backup, rollback

**Batch Expansion**:
The controlled increase from representative samples to larger naming groups after the validation gate passes.
_Avoid_: full dump, mirror, blind import

**Gameplay Config Tables**:
The table-driven gameplay data for room pools, rewards, enemy waves, drops, and upgrade cards used by the Hades-like prototype.
_Avoid_: hard-coded gameplay constants, extracted asset inventory

## Relationships

- A **Sample Manifest** selects one or more **Copied Samples** from the **Source Install**.
- A **Copied Sample** belongs in the **Extracted Workspace**, not in final Unity content.
- A **Raw Asset Copy** can include many candidate files, but it is not accepted Unity content.
- An **Asset Acquisition Gate** can establish `AssetLocated`, `ExtractedReadable`, `CrossToolVerified`, `SemanticContextRecovered`, or `UnityImportCandidate`, but it never grants **Development-Usable Asset** status.
- A **UnityImportCandidate** is allowed to enter focused Unity triage; it is still blocked from gameplay mainline until the **Original Asset Reuse Gate** and manifests pass.
- A **ReconstructedPrototypeAsset** can be a valid local fan-prototype route when original controllers, prefabs, or Wwise event behavior cannot be fully recovered, but it must be named as reconstruction rather than original-project restoration.
- An **Android Install Payload** can support dependency comparison only after **Android Package Intake** reports useful Unity content indicators; it is not itself accepted content.
- An **Android Package Intake** result can raise the confidence of dependency repair, but it does not satisfy the **Original Asset Reuse Gate** without Unity import and visible validation.
- An **Android/PC Bundle Comparison** can choose focused export candidates, but it does not prove that Android closes missing dependencies until an AssetRipper export and Unity visible validation pass.
- A **Focused Variant Slice** can falsify a repair direction if its missing dependency set does not improve; it is not a failure of the full objective by itself.
- A **CAB Set-Cover Closure** can locate missing CAB ids, but it is unsafe to expand blindly because selected bundles can introduce more missing dependencies than they resolve.
- A **Unity Export Reference Graph** can show whether a repair attempt reduces missing YAML references, but it cannot prove visibility or original asset fidelity.
- A **Deadbeef Placeholder GUID** is stronger evidence of export reconstruction risk than a normal Unity built-in reference; it should not be counted as a missing Android/PC bundle name without additional object-level provenance.
- A **Placeholder Reference Context** turns placeholder counts into repair strategy: material-only placeholders may be repair candidates, while mesh, animation, scene lighting, timeline, or mixed placeholders imply higher reuse risk.
- A **Static Renderable Salvage Candidate** can justify a focused Unity visible test, but it does not prove normal visibility, texture fidelity, or gameplay usability.
- **Environment Module Salvage** is a fallback route for local prototype room construction; it does not satisfy the stricter goal of direct complete StellaSora scene reuse.
- A **Module Salvage Slice** is the right unit for the next EnvironmentArt gate because it is small enough to diagnose transitive material, mesh, and shader issues without full-scene noise.
- A **Unity Built-in Resource GUID** is not a dependency gap and should be excluded from missing-reference counts.
- A **Decoded Audio Sample** can become an **Imported Unity Asset** only after Unity imports it successfully.
- A **Decoded Audio Collection** proves audio media extraction, not bank/event meaning.
- A **Minimum Audio Selection Manifest** can move audio from unselected media to selected candidates, but it does not pass audio usability until Unity playback and semantic role confirmation are recorded.
- A **Bank Media Decode** can provide stronger SFX candidates than standalone numeric WEM guesses, but bank-name evidence remains weaker than Wwise event metadata or manual listening.
- A **Minimum UI Reward Selection Manifest** can move UI/reward/card art from unselected to selected candidates, but it does not pass visual usability until Unity visible validation proves the selected sprites or prefabs render recognizably.
- A **Visible Sample** is stronger evidence than a loaded AssetBundle and is required before related **Batch Expansion**.
- A **Visible Smoke Test** can support **Development-Usable Asset** status, but it does not remove documented **Extraction Bug** findings.
- An **Original Asset Reuse Gate** is stricter than a **Visible Smoke Test** because the rendered result must show recognizable original content, not only geometry, fallback color, or a non-empty screenshot.
- A **Single-Asset Reuse Candidate** can unblock focused reconstruction for that exact asset, but it does not authorize **Batch Expansion** for the category.
- **Semantic Material Reassignment** is stronger than grey fallback rendering because it restores named material identity, but it is still weaker than original material fidelity when texture bindings remain unresolved.
- A **Semantic Material Candidate** can justify a focused repair attempt, but it is weaker than **Semantic Material Reassignment** and cannot pass the **Original Asset Reuse Gate** while texture placeholders remain.
- **Offline Semantic Material Rebind** is stronger than a candidate scan because it rewrites a module slice and can be checked by the **Unity Export Reference Graph**, but it is still not a **Development-Usable Asset** without Unity visible validation and fidelity review.
- **Offline Semantic Material Texture Rebind** is stronger than **Offline Semantic Material Rebind** when exact texture matches are restored, but it still cannot pass the **Original Asset Reuse Gate** without Unity visible validation and fidelity review.
- A **Manual Texture Mapping Manifest** can improve **Offline Semantic Material Texture Rebind** coverage, but it increases review responsibility because wrong texture assignments can make an asset look non-original even when the reference graph is clean.
- **Offline Fallback Shader Repair** can make a **Module Salvage Slice** statically reference-closed, but the slice still needs Unity visible validation and fidelity review before it can pass the **Original Asset Reuse Gate**.
- **UsableWithKnownIssues** is not permission for blind **Batch Expansion**; it is permission to keep reconstructing with the known issues visible.
- A **Rejected Asset** is only assigned after stronger repair attempts have failed; missing first-pass visibility is not enough.
- An **Asset Acceptance Manifest** is stronger than an inventory because it records gate status, evidence paths, and the next allowed action.
- A **Minimum Vertical Slice Asset Manifest** is stronger than a feature plan because it ties the gameplay start decision to concrete accepted or blocked assets; if it reports `canStartGameplayMainline=false`, mainline gameplay implementation remains paused.
- An **AssetRipper Export** can inform reconstruction, but it is not itself an **Imported Unity Asset**.
- **Gameplay Config Tables** describe the prototype's rebuilt gameplay loop; they do not come from StellaSora extraction logs.
- A **Source Safety Guard** must pass before any migration milestone can be accepted.

## Example dialogue

> **Dev:** "The character AssetBundle loaded in the Sample Validation Scene. Can we expand `char_*` now?"
> **Domain expert:** "No. It is only a Copied Sample until a Visible Sample is observed or an AssetRipper Export proves the reconstructable assets exist."

## Flagged ambiguities

- "Asset loaded" was used to mean both **Copied Sample** availability and **Visible Sample** acceptance. Resolved: loading a bundle is not enough to pass visual migration.
- "Import" was used for copying source files and Unity-ready project assets. Resolved: copied files stay in the **Extracted Workspace**; **Imported Unity Assets** live under `Assets/StellaGaia/`.
- "Batch migration" was used before the validation gate. Resolved: **Batch Expansion** is blocked until the Unity sample gate records accepted categories.
- "Transferred" was used for both raw file copy and usable Unity import. Resolved: **Raw Asset Copy** means files are under the project; **Imported Unity Asset** means Unity can use them.
