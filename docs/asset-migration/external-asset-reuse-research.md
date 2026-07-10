# External Asset Reuse Research

This note separates two questions that were previously conflated:

1. Can game assets be located, extracted, decoded, or inspected?
2. Can those assets become development-usable Unity assets for StellaGaia?

The answer to the first question is much stronger than the answer to the second. Public tooling and tutorials make asset acquisition feasible. Public long-running projects also show that original game data can be reused successfully, but the durable success pattern is a new engine, loader, mod framework, or local reconstruction layer that reads user-owned original data. It is not a guarantee that a modern Unity title can be restored as its original Unity project.

## Tool And Tutorial Evidence

| Source | What it supports | StellaGaia interpretation |
| --- | --- | --- |
| [AssetStudio](https://github.com/Perfare/AssetStudio) | Unity asset and AssetBundle inspection/export, including textures, sprites, audio, meshes, Animator, and AnimationClip assets. | Strong evidence for an independent quick extraction and preview route. It supports `ExtractedReadable`, not `DevelopmentUsable`. |
| [AssetRipper](https://github.com/AssetRipper/AssetRipper) | Unity serialized file and AssetBundle conversion into Unity-native formats, with broken-reference inspection. | Strong evidence for Unity-like reconstruction inputs and reference graph analysis. It still needs local repair and Unity validation. |
| [AssetRipper Premium Features](https://assetripper.github.io/AssetRipper/articles/PremiumFeatures.html) | Documents limits around static mesh separation, shader decompilation, prefab outlining, IL2CPP analysis, and package references. | Supports a conservative gate: AssetRipper output is reconstruction input, not original-project restoration proof. |
| [Il2CppDumper](https://github.com/Perfare/Il2CppDumper) | Generates dummy DLLs, metadata, and disassembler helper scripts from IL2CPP binaries and metadata. | Useful for MonoBehaviour/script field semantics. It does not recover the original C# project or make assets Unity-usable by itself. |
| [UABEA](https://github.com/nesrak1/UABEA) | AssetBundle editing/research workflow; its own README points extraction-only users toward AssetRipper or AssetStudio. | Useful as a research/modding tool, not the primary StellaGaia route. |
| [wwiser](https://github.com/bnnm/wwiser) | Wwise `.bnk` inspection and TXTP generation for event-like playback via vgmstream. | Stronger than direct `.wem` playback for audio semantics, but still an approximation of Wwise behavior. |
| [vgmstream](https://github.com/vgmstream/vgmstream) | Playback/decode support for many game audio formats including looped game music and Wwise media. | Supports StellaGaia audio decode and audition packs. It does not prove event semantics alone. |
| User-provided Unity extraction tutorials | AssetStudio / Unity Studio / Il2CppDumper workflows for extracting assets from Unity games, APK/IPA payloads, and AssetBundles. | They support the asset acquisition layer. They do not replace project-specific dependency closure, semantic mapping, and Unity validation. |

## Successful Reuse Patterns

| Source | Success pattern | StellaGaia lesson |
| --- | --- | --- |
| [Daggerfall Unity](https://www.dfworkshop.net/daggerfall-unity-1-0-release/) | New Unity engine/recreation that requires the user to provide local DOS Daggerfall data. | Success comes from a rebuilt control layer plus original local assets, not full original project restoration. |
| [OpenMW](https://openmw.org/faq/) | New engine for Morrowind; user supplies original game data/content. | Keep legal asset boundaries explicit and do not distribute original content. |
| [DevilutionX](https://github.com/diasurgical/devilutionX) | Reimplementation that uses user-provided original Diablo data files such as `DIABDAT.MPQ`. | Original asset reuse can be viable when the runtime/data contract is owned by the new project. |
| [OpenRCT2](https://github.com/OpenRCT2/OpenRCT2) | Open reimplementation that requires original RollerCoaster Tycoon 2 files. | Another mature example of new runtime plus original local data. |
| [Outer Wilds Mods](https://outerwildsmods.com/), [OWML](https://owml.outerwildsmods.com/), and [New Horizons](https://nh.outerwildsmods.com/) | Unity mod loader/framework/templates for custom content and modded behavior. | Unity ecosystem success depends on framework/tooling boundaries, not blind extracted-prefab import. |

## Decision For StellaGaia

- Asset acquisition feasibility is high enough to become its own gate.
- Original Unity project restoration remains out of scope.
- The target path is: locate and extract assets, cross-check them with multiple tools when useful, recover semantic context where possible, rebuild local Unity control layers, and only then ask Unity visible/audible gates whether a candidate is development-usable.
- `AssetLocated`, `ExtractedReadable`, `CrossToolVerified`, `SemanticContextRecovered`, and `UnityImportCandidate` are acquisition/reconstruction states. None of them authorize gameplay mainline work.
- `DevelopmentUsable` remains reserved for candidates with Unity visible or audible evidence and documented residual extraction issues.
