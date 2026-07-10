# Unity-First Sample-Gated Asset Migration

StellaGaia uses Unity as the target engine and keeps the StellaSora install as a read-only source because the observed source asset version is Unity `2022.3.62f2` and Unity preserves the most compatible import path for AssetBundle, audio, scene, material, and prefab reconstruction work. The migration must pass representative Unity sample validation before any batch expansion, because copied files or loaded bundles can still be missing materials, dependencies, effects, controllers, or visible scene objects.

## Considered Options

- Unity-first migration: chosen for compatibility with observed Unity asset metadata and local editor availability.
- Cocos port first: rejected for this phase because it would add conversion risk before proving source assets can be reconstructed.
- Bulk extraction first: rejected because it can create large, ambiguous output without proving that samples are usable in the target Unity project.

## Consequences

- Visual categories remain partial until they are observed in Unity or reconstructed from recorded AssetRipper sample exports.
- Batch expansion is allowed only for categories that pass the sample validation gate.
- The Source Install remains read-only throughout the workflow.
