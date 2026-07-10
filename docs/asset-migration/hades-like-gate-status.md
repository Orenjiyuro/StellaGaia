# Hades-Like Gate Status

## Current Gate

The active objective is to build a local Unity Hades-like fan prototype using StellaSora assets where assets can be made development-usable.

The root gate is original asset reuse. If StellaSora assets cannot be restored into recognizable, Unity-usable content, the Hades-like project should not proceed beyond isolated tool and repair experiments. This is not a full migration approval. It is a gate tracker for deciding when to continue, repair, replace, or reject each major asset category.

Asset acquisition is now tracked as a separate lower-level gate. `Tools\AssetImport\Test-AssetAcquisitionGate.ps1` validates that local files, AssetRipper exports, decoded audio, Android comparison inputs, and external-tool routes are sufficient to support Unity import triage. That gate can report `AssetAcquisitionEvidenceReady`, but it explicitly cannot grant `DevelopmentUsable` or gameplay-mainline approval.

Current optimism: cautiously positive for asset acquisition and for a minimum single-asset visual slice, but still not project-green. The best evidence is one textured character candidate, one textured enemy candidate, one repaired combat effect candidate, a five-prefab EnvironmentArt module slice whose static references can now be closed, and a small set of statically readable reward/card UI candidates. The module route now also has a hand-reviewed semantic-material texture rebind with 8 exact texture matches plus 3 manual material mappings, 11 of 12 semantic materials with diffuse textures, 0 generic renderer material slots, and a clean static reference graph. A material review pack now exposes 25 texture previews for the 11 bound environment materials; the one remaining unbound material, `Roguelike_Battle_009_A_04_background01`, is intentionally not forced because its best texture candidates conflict and it needs visible fidelity review. The selected reward/card art improves the vertical-slice inventory from "unselected" to "candidate selected", and now has an offline visual review pack for four selected textures. A texture-only prototype rebuild dry run reports 4 accepted original Texture2D candidates, 0 issues, and a clean controlled-staging plan, so UI/reward remains salvageable through a rebuilt local UI route. Those 4 accepted textures and 4 `.meta` files are now staged under `Assets/StellaGaia/Imported/ControlledCandidates/ui_reward/PrototypeRebuild/Textures`, with a post-apply dry run reporting 0 overwrite risk and 0 GUID conflict. `Assets\StellaGaia\Editor\UiRewardPrototypeBuilder.cs` now compiles in the offline Unity editor script preflight and is prepared to generate simple reward/card prefab prototypes plus screenshots from those staged textures. It is still not Unity-visible or development-usable because the selected original prefabs retain placeholder dependency risks and the rebuilt route has not been executed/rendered in Unity. `Tools\AssetImport\Test-UnityFocusedValidationReadiness.ps1` now reports `ReadyForUnityFocusedValidation`, with actor, environment, UI/reward, and audio offline prerequisites ready for a focused Unity validation run; this means the next decisive asset-reuse evidence is real Unity execution plus manifest reruns, not more static staging. The offline manual-review aggregate currently reports 37 review rows across audio, UI/reward, and environment preview packs: 29 visual preview rows reviewed/accepted, 8 rows still `NotReviewed`, and 0 rejected. This is useful candidate-screening evidence, not asset acceptance. Actor animation-controller reuse is mixed: Android/PC actor variant evidence found no Android animation bundles for the selected `char_14401` and `mons_10001tuboshu` candidates, so Android currently does not improve the blocked Animator Override Controller path; however, both selected actors have resolved Avatars and complete core exported `.anim` clips for idle, move, attack, hurt, and death, so a local prototype Animator Controller rebuild is statically plausible. The Unity-side validation scripts now pass an offline compile preflight across all 7 StellaGaia C# scripts, which removes one tooling risk but is still not Unity import, animation playback, audio playback, or visibility evidence. The current Unity visible validation attempt is blocked by the local Unity license, not by a resource import error. The main risk remains room/map reuse, actor animation-controller repair, unfinished audio/prefab manual review, and visible fidelity. If Unity visible validation cannot show recognizable environment modules after license activation, the StellaSora-asset-driven Hades-like goal should not advance.

## Phase 0 Baseline

Status: Passed.

Evidence:

- `Tools\AssetImport\Test-AssetToolchain.ps1` verified Unity `2022.3.62f2` and required tools.
- `Tools\AssetImport\Test-AssetAcceptanceManifest.ps1` verifies the asset acceptance manifest, root gate status, and referenced evidence paths.
- `Tools\AssetImport\Test-AssetAcquisitionGate.ps1` verifies the asset acquisition manifest, evidence paths, source safety, and tool-route policy. It can support Unity import triage but cannot approve `DevelopmentUsable` status.
- `Tools\AssetImport\Test-MinimumVerticalSliceAssets.ps1` verifies the minimum asset set required before gameplay mainline work can start, and now surfaces the focused environment-module, audio, actor-controller, and rebuilt UI/reward sub-gate statuses as explicit blockers.
- `Tools\AssetImport\Test-UnityFocusedValidationReadiness.ps1` checks the offline prerequisites for the focused Unity validation run without starting Unity. Current status is `ReadyForUnityFocusedValidation`, which means the next evidence must come from `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity` after Unity licensing is active.
- `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1` aggregates asset acquisition, the focused environment, controlled import, actor prototype controller, UI/reward, audio, Unity focused validation readiness, offline manual review, minimum vertical-slice, asset acceptance, and source-safety gates into the root original-asset reuse decision. Its summary now includes gate interpretation, post-Unity manifest rerun policy, and per-lane triage decisions.
- `Tools\AssetImport\Test-EnvironmentModuleReuseGate.ps1` verifies the current Rebind04 environment-module gate with static metrics by default, and runs the Unity screenshot gate when called with `-RunUnity`.
- `Tools\AssetImport\New-EnvironmentModuleMaterialReviewPack.ps1` generates checkerboard-backed texture previews, an HTML review page, and a material-review TSV for Rebind04 environment-module material bindings under ignored `Extracted\Validation\EnvironmentModuleMaterialReviewPack`.
- `Tools\AssetImport\Test-MinimumAudioSelection.ps1` verifies the selected decoded WAV candidates with ffprobe.
- `Tools\AssetImport\Test-ControlledImportCandidateGate.ps1` verifies the current player/enemy/effect single-asset candidate evidence and keeps them blocked until controlled Unity project import proof exists.
- `Tools\AssetImport\Measure-AndroidActorVariantEvidence.ps1` verifies whether Android bundle variants can help the selected player/enemy actor controller blockers before attempting more actor extraction.
- `Tools\AssetImport\Measure-ActorAnimationRebuildReadiness.ps1` verifies whether the selected player/enemy exported Avatar and core `.anim` clips are sufficient for a prototype controller rebuild route.
- `Tools\AssetImport\New-ActorPrototypeControllerRebuildPlan.ps1` creates a dry-run staging plan for selected actor prefab, Avatar, core clips, and planned generated prototype controller paths without copying assets.
- `Tools\AssetImport\Copy-ActorPrototypeControllerSourceAssets.ps1` audits that dry-run source plan and can explicitly stage those actor source assets with `-Apply`; by default it writes only an ignored dry-run report.
- `Tools\AssetImport\Test-ActorPrototypeControllerRebuildGate.ps1` chains actor readiness, source staging preflight, optional explicit source staging, and optional Unity builder execution into one actor repair gate. By default it performs only dry-run evidence gathering.
- `Tools\AssetImport\Test-UnityEditorScriptCompilePreflight.ps1` performs an offline Roslyn compile preflight for Unity validation scripts before a Unity license-backed run. It can compile a focused script list or all StellaGaia C# scripts with `-AllStellaGaiaScripts`, and writes only under `Extracted\Validation\UnityEditorScriptCompilePreflight`.
- `Assets\StellaGaia\Editor\ActorPrototypeControllerBuilder.cs` is the Unity-side builder for that dry-run spec. It only runs when explicitly invoked, writes its report under `Extracted\Validation\ActorPrototypeControllerBuild`, and limits generated assets to `Assets/StellaGaia/Imported/ControlledCandidates`. It is not a Unity validation pass by itself.
- `Tools\AssetImport\Convert-WwiseBankMedia.ps1` extracts and decodes focused Wwise `.bnk` DIDX/DATA media into ignored bank-media WAV output.
- `Tools\AssetImport\Test-AudioReuseGate.ps1` writes the selected minimum audio list by default and, when called with `-RunUnity`, asks Unity to decode the selected external WAVs as `AudioClip` objects without copying the WAV files into `Assets/`.
- `Tools\AssetImport\New-MinimumAudioAuditionPack.ps1` generates short OGG previews, waveform PNGs, an HTML audition page, and a listening-review TSV for the selected minimum audio candidates under ignored `Extracted\Validation\MinimumAudioAuditionPack`.
- `Tools\AssetImport\Test-MinimumUiRewardSelection.ps1` verifies selected reward/drop/card art candidates for static file readability and records prefab placeholder warnings.
- `Tools\AssetImport\Test-UiRewardReuseGate.ps1` writes the selected UI/reward Unity asset list by default and, when called with `-RunUnity`, validates only those selected reward/drop/card assets instead of the full `UiOrItemArt` category.
- `Tools\AssetImport\New-MinimumUiRewardVisualReviewPack.ps1` generates checkerboard-backed PNG previews, an HTML review page, and a visual-review TSV for selected UI/reward texture candidates under ignored `Extracted\Validation\MinimumUiRewardVisualReviewPack`.
- `Tools\AssetImport\Test-UiRewardPrefabStaticRiskGate.ps1` classifies the selected UI/reward prefab candidates by static YAML/meta risk, so missing-FX drop prefabs and high-risk UI panel prefabs are not treated as the same class of blocker.
- `Tools\AssetImport\New-UiRewardPrototypeRebuildPlan.ps1` creates a dry-run plan for rebuilding simple local Unity reward/card UI from accepted original Texture2D candidates while keeping the original high-risk UI/drop prefabs blocked.
- `Tools\AssetImport\Copy-UiRewardPrototypeSourceTextures.ps1` audits and explicitly stages the accepted UI/reward Texture2D candidates into `Assets/StellaGaia/Imported/ControlledCandidates/ui_reward/PrototypeRebuild/Textures`; by default it performs only a dry run.
- `Assets\StellaGaia\Editor\UiRewardPrototypeBuilder.cs` is the Unity-side builder for staged UI/reward textures. It configures the staged textures as sprites, generates simple local reward/card prefabs under the controlled generated path, renders screenshot evidence under `Extracted\Validation\UiRewardPrototypeBuild`, and keeps the original high-risk UI/drop prefabs rejected unless separately proven.
- `Tools\AssetImport\Test-UiRewardPrototypeBuildGate.ps1` is the focused gate for the rebuilt UI/reward route. By default it verifies the rebuild plan, staged textures, builder compile preflight, and source safety; with `-RunUnity` it executes `UiRewardPrototypeBuilder` and requires generated prefab screenshot evidence before acceptance.
- `Tools\AssetImport\Test-OfflineManualReviewGate.ps1` reads the selected audio listening TSV, UI/reward visual TSV, and environment material TSV, then writes a single ignored manual-review gate summary under `Extracted\Validation\OfflineManualReviewGate`; it does not count manual preview review as Unity import/render/playback evidence.
- `Tools\AssetImport\Copy-ControlledImportCandidates.ps1` turns the controlled player/enemy/effect copy-plan CSV into a dry-run or explicit `-Apply` copy operation. By default it writes only under `Extracted\Validation\ControlledImportCopy` and does not create `Assets/StellaGaia/Imported/ControlledCandidates`.
- `Extracted/` outputs remain ignored by Git.
- `C:\SoftGame\YostarGames\StellaSora_CN` has no generated `Extracted`, `Assets`, or `Tools` directories.

## Phase 1 Dependency Closure

Status: In progress; room sample closure attempted.

Current blocker:

- Completed visual categories still have missing dependency warnings.
- `EnvironmentArt` full category export has not been accepted.
- `EnvironmentRoomSample009WithCommon` can export Unity scene/prefab structures, but still has 6,864 missing dependency warnings and 263 unique missing CAB ids.
- CAB-focused expansion, GUID slicing, and Rebind02 validation found a clean five-prefab semantic-material module slice, but the best complete room sample remains `VisibleBroken`, so StellaSora room/map assets are not accepted for the Hades-like room loop.

Environment room closure attempts:

| Attempt | Input | Result |
| --- | --- | --- |
| EnvironmentRoomSample009A01 | `roguelike_battle_009_a_01*` plus `level_common_*_009` | Imported and visible, but 17,280 sampled critical issues and mostly magenta prefab screenshots |
| EnvironmentRoomSample009Full | full `roguelike_battle_009*` room family | Imported and visible, but 21,547 sampled critical issues across prefab and scene samples |
| EnvironmentRoomSample009WithCommon | full `roguelike_battle_009*` plus all `level_common_*roguelike_battle*` bundles | Improved to 12,459 sampled critical issues after material repair, but scenes still miss mesh/material references |
| EnvironmentRoomSample009CabFocused | `009WithCommon` plus CAB-index-selected 009/environment candidates | Exported 45,325 files, but missing CAB warnings increased to 7,135 and full material repair exceeded 25 minutes without a report |
| EnvironmentRoom009A1GuidClosure | GUID closure slice rooted at `Roguelike_Battle_009_A1.prefab` | Imported and visible, but still 1,258 critical issues and a broken pink-strip screenshot |
| EnvironmentRoom009Floor01GuidClosure | GUID closure slice rooted at `Roguelike_Battle_009_A_01_Floor01.prefab` | Imported, visible after multi-view validation, 0 critical issues, but only proves one grey/fallback floor geometry module |
| EnvironmentRoom009Building01GuidClosure | GUID closure slice rooted at `Roguelike_Battle_009_A_01_Building01.prefab` | Imported, visible, 0 critical issues, but only proves one grey/fallback environment geometry module |
| EnvironmentRoom009FloorBuildingGuidClosure | GUID closure slice rooted at `Floor01` plus `Building01` | Imported, 2 visible samples, 0 critical issues, 0 missing dependency warnings; 12 generic `Lit_*` slots reassigned to 009 semantic materials, but texture restoration remains 0 |
| Environment009ModuleSalvageSet01SemanticMaterialRebind02 | Five-prefab module slice with semantic material rebind | Static-only repair: 12 semantic material files copied, 33 renderer material slots patched, 0 missing/deadbeef/placeholder references, 0 generic renderer material slots; 40 texture placeholders sanitized, so Unity visible validation and texture fidelity are still unproven |
| Environment009ModuleSalvageSet01SemanticMaterialTextureRebind03 | Rebind02 plus exact texture matches from `env_roguelike_2_texture-*` | Static-only repair: texture-only export produced 1,264 PNGs with 0 missing dependencies; 8 of 12 semantic materials got exact texture matches, 21 texture files copied, 29 material texture properties patched, 0 missing/deadbeef/placeholder references, 0 generic renderer material slots; Unity visible validation is still required |
| Environment009ModuleSalvageSet01WeakTextureCandidates01 | Non-mutating weak texture candidate report for the 4 Rebind03-unbound materials | 4/4 remaining materials have review candidates; `Door01`, `Window01_glass`, and `Light01` look plausible from name/context/image evidence; `background01` remains ambiguous and must not be auto-bound |
| Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04 | Rebind03 strategy plus a small reviewed manual texture mapping manifest | Static-only repair: 12 semantic materials processed, 8 exact texture matches, 3 manually mapped materials, 11 diffuse-bound materials, 25 texture files copied, 36 material texture properties patched, 117/117 YAML refs existing, 0 missing/deadbeef/placeholder refs, 0 generic renderer material slots, 5/5 static renderable root candidates; material review pack generated 25 previews; `background01` remains intentionally unbound because generic outdoor background and A04 glass-like candidates conflict; Unity visible validation is still required |

CAB index evidence:

- `New-AssetBundleCabIndex.ps1` indexed 5,613 CAB ids from `Extracted\RawAssets`.
- All 263 unique missing CAB ids from `EnvironmentRoomSample009WithCommon` had at least one raw bundle string match.
- Directly expanding by CAB string matches is not a closed dependency graph; it can introduce more missing CABs.

Android intake evidence:

- `Tools\AssetImport\Test-AndroidUnityPackageIntake.ps1 -InputRoot Android` reports `PotentialUsefulness=High` and `GateDecision=ProceedToDependencyComparison`.
- The Android input contains 1 APK, 12 Unity data entries, 2 Unity player libraries, 4,380 AssetBundle indicators, 1 Addressables/catalog indicator, 122 Wwise bank entries, 578 WEM entries, and 179 asset/cache candidates.
- APK-level inspection found 4,209 `.unity3d` entries and roguelike-related install resources including `env_roguelike_1_*`, `env_roguelike_2_*`, and `env_breakout_roguelike_*`.
- `Android\DATA\files\Persistent_Store\AssetBundles` contains local cache bundles that can be compared against PC raw assets.
- `Android\OBB` was present but follow-up filesystem inspection found it empty; no `.obb` payload is currently contributing assets.

Android/PC bundle comparison evidence:

- `Tools\AssetImport\Compare-AndroidPcUnityBundles.ps1` compared 8,522 PC `.unity3d` records with 4,380 Android `.unity3d` records.
- For the roguelike/environment target pattern, 1,816 base names were compared: 1,089 appear in both PC and Android, 727 are PC-only, and 0 are Android-only.
- 226 target environment base names exist on both platforms but have different lengths. Examples include `env_roguelike_2_fx`, `roguelike_battle_009_a_05_assets`, `roguelike_battle_009_a_05_mir_assets`, `roguelike_battle_009_b_07_mir_assets`, and `roguelike_battle_009_c_02_mir_assets`.
- This means Android is useful for platform-variant diagnosis, but it did not directly provide Android-only bundle names for the blocked `009` room dependency set.

Android actor variant evidence:

- `Tools\AssetImport\Measure-AndroidActorVariantEvidence.ps1` reads the Android/PC bundle comparison and the minimum vertical-slice manifest, then writes `Extracted\Validation\AndroidActorVariantEvidence\android-actor-variant-summary.json`, a status CSV, and a Markdown report.
- Current result: `candidateCount=2`, `lowControllerHelpCount=2`, and `investigationCandidateCount=0`.
- `player_character` (`char_14401`) has Android records for small main/material/config/combo/weapon/buff bundles, but `char_14401_models`, `char_14401_textures`, `char_14401_animations`, `char_14401_fx`, and `char_14401_timeline` are PC-only in the current comparison evidence. Decision: `LowAndroidHelpForControllerRecovery`.
- `enemy` (`mons_10001tuboshu`) has Android records for model/material/texture/fx/config/combo bundles, including a different-length texture bundle, but `mons_10001tuboshu_animations` is PC-only. Decision: `TextureVariantOnlyNoControllerHelp`.
- Interpretation: Android remains useful for enemy texture comparison and general package diagnostics, but it does not currently raise the odds of recovering the selected actor Animator Override Controllers. Actor controller recovery should now focus on PC animation bundle provenance, AssetRipper export limits, or rebuilding a Unity controller from recovered animation clips.

External Android packaging references:

- Unity documents APK expansion files as the Android asset-splitting mechanism: core assets stay in the APK, while additional assets such as StreamingAssets and later-scene assets can be placed in expansion files. Source: [Unity 2022.3 APK expansion files](https://docs.unity.cn/Manual/android-OBBsupport.html).
- Unity also documents that Android AssetBundles can be packaged in StreamingAssets, custom asset packs, or downloaded from a CDN, and downloaded bundles are commonly stored in cache or `Application.persistentDataPath`. Source: [Unity AssetBundle platform considerations](https://docs.unity3d.com/jp/current/Manual/assetbundles-platforms.html).
- Unity Addressables uses catalogs to resolve physical bundle locations, and remote catalogs can replace or supplement the built-in local catalog when content updates are used. Source: [Unity Addressables remote content distribution](https://docs.unity.cn/Packages/com.unity.addressables%401.19/manual/RemoteContentDistribution.html).
- Wwise Unity documentation notes that Android OBB files can contain StreamingAssets, including SoundBanks, when split application binary support is used. Source: [Wwise Unity OBB files](https://documentation.help/Wwise-Unity/pg__loadbankobb.html).
- AssetRipper's official GitHub README identifies the tool as extracting Unity serialized files and asset bundles into native Unity-engine formats, with support varying by Unity version. Source: [AssetRipper GitHub](https://github.com/AssetRipper/AssetRipper).

Interpretation for this project: providing APK, OBB, and Android DATA/cache was the right move and does raise diagnostic odds because it can expose platform-specific bundles, catalogs, cached downloads, and SoundBanks that are absent from a PC install snapshot. It does not guarantee dependency closure. For the current `009` room target, local Android evidence did not provide Android-only target bundle names and did not reduce the missing CAB set in the first focused variant export.

Focused Android/PC variant slice evidence:

- `Environment009A05AndroidPcVariant` staged 8 PC files and 8 Android files for selected `009`/`env_roguelike_2` same-name variant candidates.
- `Environment009A05AndroidVariant` exported 2,333 files with 52 missing dependency warnings and 42 unique missing CAB ids.
- `Environment009A05PcVariant` exported 2,333 files with 52 missing dependency warnings and 42 unique missing CAB ids.
- `Environment009A05CombinedVariant` exported 4,585 files with 104 missing dependency warnings and the same 42 unique missing CAB ids.
- Static CAB comparison found 42 common missing CAB ids, 0 Android-only missing CAB ids, and 0 PC-only missing CAB ids.
- Unity visible validation for `Environment009A05AndroidVariant` did not run because Unity batchmode reported `No valid Unity Editor license found`; this is a validation environment blocker, not a visual pass or fail.

Direct missing-CAB candidate closure evidence:

- `Resolve-MissingCabBundleCandidates.ps1 -Name Environment009A05AndroidVariant` found all 42 missing CAB ids in the PC raw CAB index.
- The CAB ids are fragmented: 3,077 candidate bundles match at least one missing CAB; greedy set-cover selected 36 bundles, totaling 243,705,308 bytes, to cover 37 low-fanout CAB ids.
- `Environment009A05AndroidCabClosure` staged the 8-file Android variant plus the 36 selected PC candidates, for 44 input bundles and 258,159,780 bytes.
- AssetRipper export got worse: missing dependency warnings increased from 52 to 390, and unique missing CAB ids increased from 42 to 101.
- The closure attempt resolved 23 original CAB ids but left 19 original CAB ids and introduced 82 new CAB ids.

Unity export reference graph evidence:

- `Measure-UnityExportReferenceGraph.ps1` scanned the exported Unity YAML/.meta reference graph for `Environment009A05AndroidVariant`, `Environment009A05AndroidCabClosure`, and `EffectArt`.
- After excluding Unity built-in resource GUIDs (`e000` default resources and `f000` `unity_builtin_extra`), the Android environment slice has 0 ordinary missing Unity GUID references, but 1,183 `deadbeef/deadf00d` placeholder references across 64 source assets.
- The CAB closure export has 0 ordinary missing Unity GUID references, but placeholder references increased to 3,278 across 329 source assets.
- `EffectArt` control scan has 187 placeholder references across 19,968 YAML references, much lower than the environment slice, and already has one repaired single-asset reuse candidate.
- This shifts the environment blocker from "find normal Unity GUID files" to "explain and repair AssetRipper placeholder references or prove they are not required by visible validation."

Placeholder context evidence:

- `Measure-UnityPlaceholderReferenceContext.ps1` classifies the placeholders by YAML field and likely dependency kind.
- `Environment009A05AndroidVariant` placeholders are concentrated in material dependencies (510), animation bindings (322), and mesh dependencies (320).
- `Environment009A05AndroidCabClosure` got worse across material dependencies (1,449), mesh dependencies (789), shader/texture dependencies (645), animation bindings (322), timeline bindings (28), and other scene/behavior references (45).
- CAB closure introduced broken scene-level data such as renderer material arrays, mesh fields, lighting settings, reflection, occlusion, and Wwise/timeline references.
- This means the room/map blocker is not a simple shader or missing material issue. Complete room reuse requires object/path-id provenance or a different extraction/export strategy.

Environment module salvage evidence:

- `Find-UnityExportSalvageCandidates.ps1` scans exported prefabs for no ordinary missing GUIDs, no zero GUIDs, no placeholder GUIDs, and static renderer/mesh evidence.
- `Environment009A05AndroidVariant` contains 195 static renderable salvage candidates out of 224 scanned environment prefabs.
- `Environment009A05AndroidCabClosure` contains 1,119 static renderable salvage candidates out of 1,155 scanned environment prefabs.
- Top `009` candidates include `Roguelike_Battle_009_A_01_Building01.prefab`, `Roguelike_Battle_009_A_06_Floor01.prefab`, `Roguelike_Battle_009_A_05_door01.prefab`, `Roguelike_2_Battle_009_MainWall.prefab`, multiple `FarBuilding` prefabs, and 009 props.
- Manual static spot-check for `Roguelike_Battle_009_A_01_Building01.prefab` found 11 renderer components, 11 mesh references, 11 material arrays, 22 existing GUID references, 0 placeholder references, and 0 missing GUID references.
- This does not accept complete room reuse, but it makes module salvage a viable next test path once Unity visible validation can run.

Module salvage slice evidence:

- `Environment009ModuleSalvageSet01GuidClosure` was created under `Extracted\AssetRipper\EnvironmentModuleSlices`.
- Root modules: 009 building, floor, main wall, door, and commodity/prop prefabs.
- GUID closure copied 41 assets.
- Static reference graph reports 69 YAML GUID references: 66 existing, 0 ordinary missing GUIDs, 0 zero GUIDs, and 3 placeholder refs.
- All 3 placeholders are `m_Shader` refs in `Assets/Material/Lit_6.mat`, `Lit_7.mat`, and `Lit_9.mat`.
- Root prefab salvage scan reports 5 of 5 static renderable candidates.
- Offline shader fallback repair replaced those 3 material shader placeholder refs with a local fallback shader inside the ignored slice.
- Post-repair static reference graph reports 69 of 69 YAML GUID references as existing, with 0 ordinary missing GUIDs, 0 zero GUIDs, and 0 placeholder refs.
- Post-repair placeholder context reports 0 placeholder references, direct `rg "deadbeef|deadf00d"` found no remaining placeholder text under the repaired slice `Assets` folder, and root prefab salvage scan still reports 5 of 5 static renderable candidates.
- `Measure-UnitySemanticMaterialCandidates.ps1` compared the same module slice against 956 semantic materials from `EnvironmentRoomSample009CabFocused`.
- The scan found 33 renderer material slots, all 33 currently generic `Lit_*`, with 33 semantic material candidate slots and 12 unique candidate materials.
- 29 of those candidate slots still use materials with placeholder texture refs, so this improves material identity repair prospects but does not restore texture fidelity.
- `Apply-UnitySemanticMaterialCandidatesOffline.ps1 -Name Environment009ModuleSalvageSet01SemanticMaterialRebind02` created a semantic-material-rebound slice from that candidate set.
- The rebind copied 12 semantic materials, patched 33 renderer material slots across 5 prefabs, sanitized 40 placeholder texture refs, and sanitized 12 placeholder shader refs.
- Post-rebind validation reports 81 of 81 YAML GUID references as existing, 0 ordinary missing GUID refs, 0 placeholder refs, 0 generic renderer material slots, and 5 of 5 static renderable root candidates.
- This is the cleanest EnvironmentArt module route so far, but it still needs Unity visible validation and material/texture fidelity review before it can support gameplay rooms.

Next allowed action:

- Continue EnvironmentArt only with smaller GUID-closure room/module slices, better material mapping, or Android/PC dependency comparison. Do not run another broad environment export unless it directly targets missing mesh/material references.
- Use Android input as a dependency comparison source for the currently blocked room/map gate. It improves diagnostic odds, but current comparison does not show direct Android-only missing bundles for room `009`.
- The first focused same-name variant export did not reduce the missing CAB set. Do not expand this same-name variant strategy blindly.
- The direct CAB set-cover attempt also failed by causing dependency expansion. Do not add more bundles simply because they contain missing CAB ids.
- The next Android-based attempt must use stronger graph evidence, such as object/path-id ownership, root scene/prefab object closure, or placeholder provenance. If that cannot be built, complete StellaSora room reuse remains low-confidence.
- If placeholder provenance cannot identify real mesh/material targets, stop attempting complete StellaSora scene reuse and continue only with module salvage or replacement rooms.
- The next allowed EnvironmentArt Unity test should validate a small static renderable module set, not another full scene.
- The next concrete module test target is `Environment009ModuleSalvageSet01GuidClosure`.
- Before treating that module set as visually representative, use `Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04` rather than the older semantic-material-only or exact-only slices, and explicitly mark the result as static texture-rebind evidence unless Unity screenshots prove recognizable fidelity.
- `Tools\AssetImport\New-EnvironmentModuleMaterialReviewPack.ps1` generated `Extracted\Validation\EnvironmentModuleMaterialReviewPack\Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04\environment-module-material-review-pack.html` and `environment-module-material-review.tsv`: 12 materials, 11 bound materials, 1 unbound material, 3 manually bound materials, 25 texture bindings, 25 texture previews, 5 static prefab candidates, and 0 issues.
- `docs\asset-migration\manual-preview-review-report.md` records contact-sheet review of the generated offline previews. The UI/reward textures and Rebind04 environment material previews are non-empty and reviewable; this remains preview evidence only, not Unity sprite/UI/module rendering evidence.
- `Tools\AssetImport\Test-OfflineManualReviewGate.ps1` currently reports `gateStatus=ManualReviewInProgress`, `totalRowCount=37`, `reviewedRowCount=29`, `notReviewedRowCount=8`, `acceptedRowCount=29`, `rejectedRowCount=0`, and `issueCount=0` across the audio, UI/reward, and environment review TSVs. The reviewed rows are only offline visual preview confirmations: 25 environment material texture previews and 4 UI/reward Texture2D previews. The 5 audio rows and 3 UI prefab rows remain unreviewed.
- `Tools\AssetImport\Test-UiRewardPrefabStaticRiskGate.ps1` currently reports `gateStatus=HighRiskDependencyClosureRequired`, `prefabCount=3`, `lowRiskPrefabCount=0`, `highRiskPrefabCount=1`, `visualMissingPrefabCount=2`, and `issueCount=0`. The two selected drop prefabs have no renderer tokens and their visible output depends on missing `idleFx`/`takeEffectFx` prefab references. `VampireFateCardSelectPanel.prefab` has 238 renderer tokens but 79 deadbeef references concentrated in font/material/sprite/Wwise fields, so it is not a safe runtime import candidate without focused dependency closure and Unity-visible validation.
- The focused command for the next environment gate is `Tools\AssetImport\Test-EnvironmentModuleReuseGate.ps1 -RunUnity`. Without `-RunUnity`, the same script only confirms the static Rebind04 readiness state and writes `Extracted\Validation\EnvironmentModuleReuseGate\Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04\environment-module-reuse-gate-summary.json`.
- The Rebind03/Rebind04 Unity visible validation path currently fails at editor licensing: `No valid Unity Editor license found`. This is an environment blocker, not a resource rejection.
- Use `Environment009ModuleSalvageSet01WeakTextureCandidates01` only as a manual review input. Do not auto-bind the ambiguous `background01` candidates; follow-up review confirmed the material is used by four `commodity01` renderers, so a wrong bind would create false fidelity evidence.
- The next Unity test must explicitly distinguish three outcomes for that module set: recognizable original-looking module, fallback-only geometry that is acceptable only as a temporary prototype module, or unrecognizable/broken output that rejects this environment route.
- Do not batch import EnvironmentArt into `Assets/StellaGaia`.

## Phase 2 Visual Repair

Status: In progress.

`EffectArt` material fallback repair result:

| Metric | Before Repair | After Repair |
| --- | ---: | ---: |
| Visible samples | 6 | 6 |
| Sample critical issues | 50 | 11 |
| Broken/pink shaders | 38 | 0 |
| Max sampled magenta pixel ratio | non-zero | 0 |

`CharacterArt` material fallback repair result:

| Metric | Before Repair | After Repair |
| --- | ---: | ---: |
| Visible samples | 4 | 4 |
| Sample critical issues | 118 | 31 |
| Broken/pink shaders | 87 | 0 |
| Zero-critical visible sampled prefabs | 0 | 1 |

`EnemyArt` material fallback repair result:

| Metric | Before Repair | After Repair |
| --- | ---: | ---: |
| Visible samples | 5 | 5 |
| Sample critical issues | 97 | 22 |
| Broken/pink shaders | 75 | 0 |
| Zero-critical visible sampled prefabs | 0 | 3 |

`EnvironmentRoomSample009WithCommon` material fallback repair result:

| Metric | Before Repair | After Repair |
| --- | ---: | ---: |
| Visible samples | 20 | 20 |
| Sample critical issues | 12,540 | 12,459 |
| Broken/pink shaders | 81 | 0 |
| Scene missing meshes | 1,783 | 1,783 |
| Scene missing material slots | 2,484 | 2,484 |

Latest texture restoration pass:

| Category | Texture-Restored Materials | Inferred Main Textures | Single-Asset Reuse Evidence |
| --- | ---: | ---: | --- |
| EffectArt | 93 | 1 | `fx_drop_note_red_bullet.prefab` is a repaired single-asset combat effect candidate with 0 post-repair validation issues |
| CharacterArt | 1,958 | 194 | `14401_fx_battle_0.prefab` is textured, visible, and has 0 sampled critical issues |
| EnemyArt | 942 | 7 | `10001TuBoShu_Actor.prefab` is textured, visible, and has 0 sampled critical issues |
| EnvironmentArt | 8 exact-texture semantic materials for tested module slice | 0 | `Environment009ModuleSalvageSet01SemanticMaterialTextureRebind03` is statically clean as a five-prefab module slice with semantic material reassignment and partial exact texture binding, but still has no post-rebind Unity visible pass |

Branch decision:

- Continue repairing `EffectArt`; the fallback shader path is viable.
- Treat `fx_drop_note_red_bullet.prefab` as a repaired single-asset combat effect candidate only. It required one renderer material-slot repair to assign `fx_drop_note_red.mat`, so it is not evidence that raw `EffectArt` exports are clean.
- Continue repairing `CharacterArt`; one textured character sample is a single-asset reuse candidate, but the category is not batch-ready.
- Continue repairing `EnemyArt`; one textured monster Actor sample is a single-asset reuse candidate, but the category is not batch-ready.
- Continue EnvironmentArt only at module-slice level; the Rebind03 five-prefab module slice is statically clean and has partial exact texture binding, but no complete room/map or post-rebind Unity visible pass is accepted.
- Do not batch expand `EffectArt`; category-level missing dependencies and missing material slots remain.
- Do not batch expand `CharacterArt`; missing dependencies, missing material slots, and missing Animator Controllers remain.
- Do not batch expand `EnemyArt`; missing dependencies, missing material slots, and missing Animator Controllers remain.
- Do not use `EnvironmentArt` room samples for gameplay rooms yet; shader repair works mechanically but does not restore the missing room geometry/material references.
- Do not apply the repair blindly to UI or NPC categories until one dry-run and one visual validation are recorded per category.

## Phase 3 Audio

Status: Media extraction passed, focused bank-media SFX decode passed, audition pack ready, event mapping/listening review pending.

Evidence:

- 6,040 decoded WAV files.
- 0 decode failures.
- Focused bank-media decode extracted 328 embedded Wwise media files from `Impact.bnk`, `Monster_10001.bnk`, and `Character_Common.bnk`, with 0 decode failures.
- The minimum SFX candidates now come from `Character_Common.bnk`, `Impact.bnk`, and `Monster_10001.bnk` instead of the earlier weak `Music_*` numeric candidates.
- `Tools\AssetImport\New-MinimumAudioAuditionPack.ps1` generated an ignored audition pack at `Extracted\Validation\MinimumAudioAuditionPack`: 5 OGG previews, 5 waveform PNGs, `minimum-audio-audition-pack.html`, and `minimum-audio-listening-review.tsv`, with 0 issues.
- `Tools\AssetImport\Test-MinimumAudioSemanticHints.ps1` reports `SemanticHintsReadyNeedsListeningAndUnityPlayback`, `selectionCount=5`, `mediaIndexedCount=4`, `roleHintCount=5`, and `issueCount=0`. This proves the four numeric BGM/SFX media candidates are indexed by their expected Wwise banks and have role keyword hints, but it is still not manual listening, Wwise event recovery, or Unity playback proof.
- `Tools\AssetImport\Test-AudioReuseGate.ps1` reports `auditionPack.status=ReadyForManualListening`, `previewCount=5`, `waveformCount=5`, and still keeps `canSatisfyMinimumAudio=false` until Unity playback and listening/event semantics are confirmed.

Branch decision:

- Use WAV media for prototype audio if Wwise event mapping is incomplete.
- Treat bank-name evidence as candidate selection only; attack/hit/death meanings still require manual listening or Wwise event mapping, and Unity playback remains required.
- Use the audition pack to perform manual review without copying WAVs into `Assets/`; do not treat generated previews as Unity playback proof.

## Phase 4 Gameplay Prototype

Status: Paused by original asset reuse gate.

Branch decision:

- Do not start the Hades-like gameplay main line until original asset reuse has positive evidence for the minimum visual slice.
- Placeholder rooms or placeholder actors are allowed only for isolated mechanics experiments, not as proof that the StellaSora asset-driven project is viable.
- Current positive evidence covers one character, one enemy, one repaired combat effect, and one small five-prefab environment module slice with semantic materials plus exact/manual texture binding and offline material previews. It does not yet cover a usable StellaSora room/map with Unity-visible fidelity, UI/items/cards, or NPC/story art.

## Phase 5 Asset Vertical Slice

Status: Not started.

The minimum asset set is now tracked in:

```text
docs\asset-migration\minimum-vertical-slice-assets.json
```

Validation:

```text
Tools\AssetImport\Test-MinimumVerticalSliceAssets.ps1
Tools\AssetImport\Test-ControlledImportCandidateGate.ps1
Tools\AssetImport\Copy-ControlledImportCandidates.ps1
```

Current result:

| Metric | Value |
| --- | --- |
| Readiness | `NotReady` |
| Can start gameplay mainline | `false` |
| Required asset entries | 8 |
| Blocking entries | 8 |

Blocking entries:

- `player_character`: `14401_fx_battle_0.prefab` is a textured single-asset reuse candidate, but still needs controlled import proof before gameplay mainline work.
- `enemy`: `10001TuBoShu_Actor.prefab` is a textured single-asset reuse candidate, but still needs controlled import proof before gameplay mainline work.
- `combat_effect`: `fx_drop_note_red_bullet.prefab` is a repaired single-asset combat effect candidate, but still needs controlled import proof before gameplay mainline work.
- `room_or_map`: Rebind04 now has static reference closure, a material review pack, and contact-sheet review confirming non-empty texture previews, but remains blocked until Unity visible validation and fidelity review pass.
- `combat_music`: one long decoded WAV is selected and ffprobe-readable; an OGG preview and waveform are generated for listening review, but Unity playback and loop behavior are not validated.
- `combat_sfx`: three bank-media WAVs are selected and ffprobe-readable from combat-relevant banks; OGG previews and waveforms are generated for listening review, but attack/hit/death semantics still need listening or Wwise event mapping, and Unity playback is not validated.
- `reward_item_art`: selected drop/health candidates are statically readable or present as prefabs; the health texture has an offline checkerboard preview and is staged for the rebuilt UI/reward prototype route, but selected drop prefabs still have placeholder references and no Unity visible pass.
- `upgrade_card_art`: selected fate-card textures are statically readable, have offline checkerboard previews, and are staged for the rebuilt UI/reward prototype route, but the matching card UI prefab is only a dependency-closure candidate and no Unity visible pass exists.
- Minimum vertical-slice tracking now includes `Tools\AssetImport\Test-UiRewardPrototypeBuildGate.ps1` and reports the rebuilt UI/reward route as `StaticReadyNeedsUnityPrototypeBuild`; this keeps reward/item/card requirements blocked until Unity generated-prefab screenshot evidence exists.

Controlled import copy-plan evidence:

- Default dry-run plan from `Extracted\Validation\ControlledImportCandidateGate` selected 3 candidates, planned 3 asset files plus 3 `.meta` files, with 0 missing source files, 0 missing meta GUIDs, 0 duplicate GUIDs, 0 target collisions, 0 project GUID conflicts, 0 overwrite risk, and `canApply=true`.
- Focused `combat_effect` closure dry-run from `Extracted\Validation\ControlledImportCandidateGate\Runs\Closure-combat_effect` selected 1 candidate, planned 15 asset files plus 15 `.meta` files, with 0 missing source files, 0 missing meta GUIDs, 0 duplicate GUIDs, 0 target collisions, 0 project GUID conflicts, 0 overwrite risk, and `canApply=true`.
- The focused `combat_effect` closure has been staged into `Assets/StellaGaia/Imported/ControlledCandidates/combat_effect` only. The apply summary at `Extracted\Validation\ControlledImportCopy\Closure-combat_effect-all\controlled-import-copy-apply-summary.json` records `appliedAssetCount=15`, `plannedMetaCount=15`, `projectGuidConflictCount=0`, and `targetOverwriteRiskCount=0`.
- A post-apply dry-run of the same focused closure reports `existingTargetFileCount=15`, `existingTargetMetaCount=15`, and `targetOverwriteRiskCount=0`, so the staging step is idempotent for the current file contents.
- `Tools\AssetImport\Test-ControlledImportCandidateGate.ps1` now audits controlled staging per candidate. The current default gate reports `staticReadyCount=3`, `stagedRootReadyCount=1`, `stagedAssetCount=1`, `stagedMetaCount=1`, and `staticIssueCount=0`.
- The default three-candidate plan now sees only one existing target, the staged `combat_effect` root prefab. `player_character` and `enemy` are not staged because their full dependency closures are not accepted yet.
- Formal actor closure diagnostics:
  - `player_character` closure resolves 68 assets with 0 ordinary missing GUIDs and no asset-count limit hit, but fails static validation with 6 `deadbeef/deadf00d` placeholder references. The placeholders are in `Char_14401_AC.overrideController` plus five material files (`face_lod.mat`, `item.mat`, `face.mat`, `cloth.mat`, `cloth_in.mat`). The material placeholders are in auxiliary texture slots such as `_MaskMap` or `_MatCapMap`; the sampled main diffuse/BaseMap texture refs are present, but the actor is not accepted for staging because the animation controller placeholder remains unresolved.
  - `enemy` closure resolves 15 assets with 0 ordinary missing GUIDs and no asset-count limit hit, but fails static validation with 2 `deadbeef/deadf00d` placeholder references. The placeholders are in `Mon_10001TuBoShu_AC.overrideController` and `Monster_MarmotSoldier_Green.mat`; the material's `_MainTex` exists, but the override controller has missing base controller/original clip placeholders.
- Actor controller recovery evidence:
  - `Tools\AssetImport\Measure-ActorControllerRecovery.ps1` writes `Extracted\Validation\ActorControllerRecovery\actor-controller-recovery-summary.json` and a Markdown report.
  - Current result: `candidateCount=2`, `recoverableCandidateCount=0`.
  - `player_character`: actor root has 0 local `.controller` files, 4 local `.overrideController` files, and 4 local override controller placeholders; the broader `CharacterArt` export has 126 scanned override controllers and all 126 have placeholder base controller refs.
  - `enemy`: actor root has 0 local `.controller` files, 6 local `.overrideController` files, and 6 local override controller placeholders; the broader `EnemyArt` export has 259 scanned override controllers and all 259 have placeholder base controller refs.
  - Interpretation: actor animation-controller repair is not a simple matter of adding one missing local controller from the same export. It likely requires an alternate extraction path, original controller provenance, or rebuilding a new Unity controller from recovered animation clips.
- Actor animation rebuild readiness evidence:
  - `Tools\AssetImport\Measure-ActorAnimationRebuildReadiness.ps1` writes `Extracted\Validation\ActorAnimationRebuildReadiness\actor-animation-rebuild-readiness-summary.json`, `actor-animation-core-clips.csv`, and a Markdown report.
  - Current result: `candidateCount=2`, `staticReadyForPrototypeControllerRebuildCount=2`, and `notReadyCount=0`.
  - `player_character`: prefab has an Animator, its Avatar GUID resolves to `Assets/assetbundles/actor/character/14401/models/14401Avatar.asset`, and the export contains 122 `.anim` files. Required core clips are present and contain no placeholder refs: `144_Idle.anim`, `144_Run.anim`, `144_Attack.anim`, `144_HurtA1.anim`, and `144_Die.anim`; optional `144_Dodge.anim` is also present.
  - `enemy`: prefab has an Animator, its Avatar GUID resolves to `Assets/assetbundles/actor/monster/10001tuboshu/models/10001TuBoShuAvatar.asset`, and the export contains 64 `.anim` files. Required core clips are present and contain no placeholder refs: `10001TuBoShu_Idle.anim`, `10001TuBoShu_Run.anim`, `10001TuBoShu_Attack.anim`, `10001TuBoShu_Hurt.anim`, and `10001TuBoShu_Die.anim`; optional `10001TuBoShu_Skill1.anim` is also present.
  - Interpretation: this supports a local prototype controller rebuild using original exported clips and Avatars, but it does not mean the original Animator Controller was recovered or that animation playback has passed Unity validation.
- Actor prototype controller rebuild plan evidence:
  - `Tools\AssetImport\New-ActorPrototypeControllerRebuildPlan.ps1` writes `Extracted\Validation\ActorPrototypeControllerRebuildPlan\actor-prototype-controller-rebuild-plan-summary.json`, `actor-prototype-controller-source-assets.csv`, `actor-prototype-controller-spec.json`, and a Markdown report.
  - Current dry-run result: `selectedCandidateCount=2`, `plannedSourceAssetCount=16`, `plannedControllerSpecCount=2`, `canStageSourceAssets=true`, and `issueCount=0`.
  - Planned source assets are only the two root prefabs, their resolved Avatars, and six core/optional clips per actor. The known bad original `.overrideController` assets are intentionally excluded from this staging plan.
  - Planned generated assets are `player_character_Prototype.controller`, `player_character_Prototype.prefab`, `enemy_Prototype.controller`, and `enemy_Prototype.prefab` under `Assets/StellaGaia/Imported/ControlledCandidates/<candidate>/PrototypeControllerRebuild`.
  - Interpretation: source staging is now planned and copy-safety clean, but not applied. A later Unity Editor builder must create the generated controllers/prefabs and validate playback before either actor can be accepted as development-usable.
- Actor prototype controller builder evidence:
  - `Tools\AssetImport\Test-ActorPrototypeControllerRebuildGate.ps1` now aggregates the actor rebuild route. After explicit source staging, current status is `SourceStagedNeedsUnityPrototypeBuild`: `runUnity=false`, `candidateCount=2`, `StaticReadyForPrototypeControllerRebuildCount=2`, `plannedSourceAssetCount=16`, `canStageSourceAssets=true`, source copy `canApply=true`, `existingTargetFileCount=16`, `existingTargetMetaCount=16`, `sourceStaged=true`, compile preflight `CompilePassed`, and `issueCount=0`.
  - `Tools\AssetImport\Test-UnityEditorScriptCompilePreflight.ps1` compiles `Assets\StellaGaia\Editor\ActorPrototypeControllerBuilder.cs` with the local Unity `UnityEngine.dll` and `UnityEditor.dll` facade references plus .NET reference assemblies. Current result: `CompilePassed`, 1 script, 20 warnings, 0 errors, and 0 issues. The warnings are JSON/spec DTO fields that Unity fills during deserialization.
  - `Tools\AssetImport\Test-ActorPrototypeControllerRebuildGate.ps1 -ApplySourceStaging` copied 16 planned actor source assets, totaling 67,633,706 bytes, into `Assets/StellaGaia/Imported/ControlledCandidates/<candidate>/PrototypeControllerRebuild`.
  - This means the actor source prefab/Avatar/clip staging operation is complete for the selected player/enemy repair route, but generated controllers/prefabs have not been created by Unity yet.
  - `Assets\StellaGaia\Editor\ActorPrototypeControllerBuilder.cs` reads `Extracted\Validation\ActorPrototypeControllerRebuildPlan\actor-prototype-controller-spec.json`, loads the staged target prefab, Avatar, and target clips, then creates a local `AnimatorController` plus generated prefab for each actor.
  - The builder now also samples the original exported clips on the generated actor prefab, renders per-state screenshots under `Extracted\Validation\ActorPrototypeControllerRebuildGate\SelectedActors\screenshots`, and records `animationSampleCount`, `renderedScreenshotCount`, `visibleScreenshotCount`, `magentaScreenshotCount`, plus per-state non-background and magenta pixel ratios in the Unity JSON report.
  - The builder intentionally creates trigger-driven prototype states from original exported clips. It does not recover or reuse the broken original `.overrideController`, so any successful result must remain classified as a repair/downgrade.
  - Safety defaults: it refuses target/generated asset paths outside the controlled candidate asset root, refuses output reports outside `Extracted\Validation`, and refuses to overwrite generated controller/prefab assets unless called with `-stellaGaiaActorPrototypeControllerOverwrite true`.
  - Current status: source staging is complete and builder script exists but has not been executed, because Unity license-backed validation is still pending. This is not evidence that either actor is Unity-visible, animated, or development-usable.
- This is controlled staging and copy-safety evidence only. It does not prove Unity import, visible fidelity, animation readiness, audio playback, UI usability, or permission to start gameplay mainline work.
- Root Unity script compile preflight:
  - `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1` now runs `Tools\AssetImport\Test-UnityEditorScriptCompilePreflight.ps1 -AllStellaGaiaScripts -NoThrow` before aggregating the resource gates.
  - Current result: `CompilePassed`, `scriptCount=7`, `warningCount=38`, `errorCount=0`, and `issueCount=0`.
  - This proves the current StellaGaia Unity validation scripts are not blocked by obvious C# compile errors in the offline preflight context. It does not prove that Unity can import, render, animate, or play any extracted asset.

Minimum acceptance target:

- One usable StellaSora character. `14401_fx_battle_0.prefab` is the current textured candidate.
- One usable StellaSora enemy. `10001TuBoShu_Actor.prefab` is the current textured candidate.
- One usable StellaSora combat effect with acceptable visual fidelity. `fx_drop_note_red_bullet.prefab` is the current repaired candidate.
- Controlled player/enemy/effect candidate proof. Current static gate: `Tools\AssetImport\Test-ControlledImportCandidateGate.ps1` reports 3 of 3 candidates static-ready in `DirectOnly` copy-plan mode, with clean root prefab evidence and no direct deadbeef/missing references. A focused closure diagnostic for `combat_effect` (`-CopyPlanMode Closure -CandidateId combat_effect`) resolves 15 assets with 0 missing/deadbeef references and has been staged into the controlled import directory. Character and enemy closure are not accepted yet because both still have `deadbeef/deadf00d` placeholders in Animator Override Controller and material auxiliary texture references; `canClearCandidateBlockingStatus=false` until controlled Unity project import proof exists.
- Prototype controller rebuild option. `Tools\AssetImport\Test-ActorPrototypeControllerRebuildGate.ps1` now reports the selected player/enemy as `SourceStagedNeedsUnityPrototypeBuild`, with clean actor readiness, complete controlled source staging, and a Unity-side builder that passes offline compile preflight. The next actor repair route still needs Unity license-backed builder execution with visible sampled-animation screenshots before it can count as actor reuse evidence. That route must be marked as a repair/downgrade, not original controller recovery.
- One usable room/map solution. Current StellaSora `EnvironmentArt` room samples are visible but not development-usable; only a small five-prefab module slice with semantic materials, exact/manual texture binding, and offline material previews is statically clean.
- One music track and three SFX clips. Current candidates are listed in `docs\asset-migration\minimum-audio-selection.json`; they are selected but not Unity-playback validated.
- Reward/drop visuals and upgrade-card visuals. Current candidates are listed in `docs\asset-migration\minimum-ui-reward-selection.json`; they are selected and statically readable. `Tools\AssetImport\New-MinimumUiRewardVisualReviewPack.ps1` now produces `Extracted\Validation\MinimumUiRewardVisualReviewPack\minimum-ui-reward-visual-review-pack.html` and `minimum-ui-reward-visual-review.tsv`, with 4 texture previews and 3 prefab dependency-risk entries. Contact-sheet review confirms the four texture previews are non-empty and visually readable, but they are still not Unity-visible or development-usable. `Tools\AssetImport\Test-UiRewardPrefabStaticRiskGate.ps1` classifies the selected prefabs as 2 visual-missing drop prefabs and 1 high-risk UI prefab. `Tools\AssetImport\New-UiRewardPrototypeRebuildPlan.ps1` now reports `TextureSourcePlanReadyNeedsControlledStaging`, 4 accepted Texture2D candidates, 3 required accepted roles, 1 optional accepted role, `canStageSourceTextures=true`, and 0 issues. `Tools\AssetImport\Copy-UiRewardPrototypeSourceTextures.ps1 -Apply` staged the 4 accepted Texture2D assets plus 4 `.meta` files into the controlled candidate route; a post-apply dry run reports `existingTargetFileCount=4`, `existingTargetMetaCount=4`, `targetOverwriteRiskCount=0`, and `projectGuidConflictCount=0`. `Assets\StellaGaia\Editor\UiRewardPrototypeBuilder.cs` compile preflight reports `CompilePassed`. `Tools\AssetImport\Test-UiRewardPrototypeBuildGate.ps1` now reports `StaticReadyNeedsUnityPrototypeBuild`, with `sourceTexturesStaged=true` and 0 issues, so the next UI/reward step is Unity execution/rendering, not more static file collection. The practical vertical-slice route should build simple reward/card UI from these staged Texture2D candidates unless Unity validation proves the original prefabs render. The focused selected-asset gate is `Tools\AssetImport\Test-UiRewardReuseGate.ps1 -RunUnity`; the focused rebuilt-route gate is `Tools\AssetImport\Test-UiRewardPrototypeBuildGate.ps1 -RunUnity`.
- Combat music and SFX. Current candidates are listed in `docs\asset-migration\minimum-audio-selection.json`; they are ffprobe-readable and selected from stronger bank-media evidence. `Tools\AssetImport\Test-MinimumAudioSemanticHints.ps1` confirms 4 numeric media candidates are indexed by their expected source banks and records role keyword hints. `Tools\AssetImport\New-MinimumAudioAuditionPack.ps1` now produces `Extracted\Validation\MinimumAudioAuditionPack\minimum-audio-audition-pack.html` and `minimum-audio-listening-review.tsv` for manual review, but the candidates are still not Unity-playback or listening/event-mapping confirmed. The focused audio gate is `Tools\AssetImport\Test-AudioReuseGate.ps1 -RunUnity`.
- Root original-asset reuse. The aggregate command is `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1`; after Unity licensing is active, use `Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity` to run all focused Unity gates together, including actor prototype controller build/screenshots, environment module fidelity, selected UI/reward visibility, and audio playback/listening gates.
- Offline manual review aggregate. `Tools\AssetImport\Test-OfflineManualReviewGate.ps1` has moved to `ManualReviewInProgress`: offline visual previews are reviewed, but audio listening and prefab-visible review are still missing. Even if all rows are confirmed, Unity focused validation remains required before any asset is development-usable.

## Phase 6 Controlled Batch Expansion

Status: Blocked.

Reason:

- No visual category is category-ready for blind batch expansion.
