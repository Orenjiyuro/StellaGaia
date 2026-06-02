# Unity Asset Migration Design

## Purpose

Build a Unity-based asset migration workflow for `StellaGaia` that extracts and imports selected StellaSora assets into this repository without damaging the installed StellaSora client.

The workflow targets a fan prototype and local development project. It does not grant permission to redistribute StellaSora assets, Hades assets, or any extracted third-party content.

## Source And Target

Source game install:

```text
C:\SoftGame\YostarGames\StellaSora_CN
```

Target workspace:

```text
C:\SoftWork\Git\StellaGaia
```

Unity compatibility baseline:

```text
Unity 2022.3.62f2
```

This version is based on the observed `UnityFS` headers in `xtlr_Data\data.unity3d` and a representative AssetBundle, both of which contain the `2022.3.62f2` version string.

## Safety Rules

The source install directory is read-only for this workflow:

- Do not write files into `C:\SoftGame\YostarGames\StellaSora_CN`.
- Do not delete, rename, patch, overwrite, or move files in the source install.
- Copy or extract into `C:\SoftWork\Git\StellaGaia` only.
- Keep generated extraction output separate from final imported Unity assets.
- Prefer small sample imports before any batch operation.
- Record extraction decisions in project files so batch work is reproducible.

## Asset Scope

The first migration pass covers representative samples from these groups:

- Player character model and animation assets from `char_*`.
- Enemy model and animation assets from `mons_*`.
- Roguelike room, environment, or map scene assets from `roguelike_*` and `env_*`.
- Combat visual effects from `fx_*`.
- In-run UI and item art from `ui_*`, `icon_*`, and related item/drop/card bundles.
- Combat sound effects and music from `.wem` and `.bnk` Wwise resources.
- Map NPC or interaction art from `npc_*`, `storyactivity_*`, or nearby naming groups when present.

The first pass does not attempt to restore full game logic from StellaSora scripts or table data. The observed `.arcx` and `.arch` script/table containers are treated as out of scope unless a separate reverse-engineering workflow is approved.

## Project Layout

Create or use a Unity project inside the repository root. The initial layout should keep source-derived files auditable:

```text
Assets/
  StellaGaia/
    Art/
      Characters/
      Enemies/
      Environments/
      Effects/
      UI/
      Items/
      NPCs/
    Audio/
      Music/
      SFX/
    Scenes/
    Scripts/
ProjectSettings/
Packages/
Tools/
  AssetImport/
Extracted/
  Samples/
  Logs/
```

`Extracted/` is an intermediate workspace for copied or converted files. Final Unity-ready assets should be placed under `Assets/StellaGaia/`.

Large generated outputs should be reviewed before committing. If the repository cannot reasonably store extracted assets, add an external artifact location or Git LFS policy before bulk import.

## Workflow

### Phase 1: Unity Project Baseline

Create a Unity project aligned to the observed asset version where possible. If the exact editor version is unavailable, use the installed Unity 2022.3 LTS version and document the difference.

Add a simple validation scene that can load one character, one enemy, one environment sample, one effect sample, and one audio sample.

### Phase 2: Sample Asset Selection

Select a small source set:

- One `char_*` bundle.
- One `mons_*` bundle.
- One `roguelike_*` or `env_*` bundle.
- One `fx_*` bundle.
- One `ui_*` or `icon_*` bundle.
- A small group of `.wem` and related `.bnk` files.

Selection should use file names and sizes only at first. Avoid opening more source data than needed for the current sample validation.

### Phase 3: Extraction And Conversion

Extract into `Extracted/Samples/` using Unity AssetBundle-compatible tooling. Preserve a log that maps each extracted file back to its source bundle.

Expected output types:

- Textures and sprites: PNG, TGA, or Unity-native imported texture assets.
- Meshes and models: FBX, OBJ, GLTF, or Unity-compatible imported meshes.
- Animation clips: Unity-compatible clips where tooling supports them.
- Audio: WAV or OGG converted from Wwise `.wem` when possible.
- Effects: extracted textures, meshes, materials, and references for manual reconstruction.

Do not assume materials, shaders, particle systems, timeline tracks, or animator controllers will survive intact. Treat them as candidates for rebuild inside Unity.

### Phase 4: Unity Import And Reconstruction

Import verified sample assets under `Assets/StellaGaia/`.

Reconstruct missing Unity-side behavior as needed:

- Materials and shader assignments.
- Animation controllers and transitions.
- Character and enemy prefab hierarchy.
- Effect prefabs and particle systems.
- Audio clips, mixers, and trigger metadata.
- UI atlas and sprite settings.

The validation scene is the first acceptance target. A sample asset is accepted only when it is visible or audible in the Unity project and has no missing critical dependencies.

### Phase 5: Batch Expansion

After samples pass validation, expand by naming group:

```text
char_*
mons_*
env_*
roguelike_*
fx_*
ui_*
icon_*
npc_*
```

Batch import should use the same extraction log format and target directory rules from the sample pass.

## Error Handling

When extraction fails:

- Leave the source install untouched.
- Record the failed source path, attempted tool, exit code, and output.
- Do not retry the same command unless it would produce new information.
- Prefer a smaller or clearer sample bundle before broadening scope.

When Unity import fails:

- Keep the extracted intermediate file.
- Record the missing dependency or import error.
- Rebuild the smallest missing dependency first.

When a resource depends on unknown scripts, shaders, or custom formats:

- Mark it as partial.
- Import the usable raw art or audio.
- Recreate behavior in project-native Unity code or prefabs.

## Validation

The first milestone is complete only when all of these are true:

- The Unity project opens without import errors severe enough to block editing.
- The validation scene contains one imported character sample.
- The validation scene contains one imported enemy sample.
- The validation scene contains one imported environment or room sample.
- One combat effect sample is visible.
- One combat sound effect or music sample plays.
- The source install directory remains unchanged by the workflow.
- Extraction logs exist for every imported sample.

## Known Risks

- Extracted assets may be incomplete because AssetBundles can reference dependencies in other bundles.
- Materials, shaders, particles, animator controllers, and timeline assets may need manual reconstruction.
- Wwise `.wem` and `.bnk` resources may lack clear event-to-file mapping.
- Some assets may be protected by custom packaging or runtime-only references.
- Bulk extracted assets may be too large for normal Git storage.
- Public redistribution of extracted assets may violate copyright or license terms.

## Approval

The approved direction is Unity-first sampled migration. The workflow should avoid direct runtime use of the original game install and should not mirror all AssetBundles into the project before sample validation.
