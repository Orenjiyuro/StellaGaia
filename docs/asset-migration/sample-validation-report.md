# Sample Validation Report

## Scope

First-pass Unity asset migration validation for StellaSora samples.

This gate covers the fixed sample copy, Wwise `.wem` decode/transcode, ffprobe metadata output, Unity validation scene creation, source-install safety check, and AssetRipper starter availability check.

## Source Safety

This workflow used read-only source install access by design:

```text
C:\SoftGame\YostarGames\StellaSora_CN
```

The final guard checks found no generated `Extracted`, `Assets`, or `Tools` directory under the source install:

```text
Extracted=False
Assets=False
Tools=False
```

## Results

- Copied samples: 10
- Decoded WAV files: 2
- Transcoded OGG files: 2
- ffprobe JSON files: 2
- Validation scene created: true
- AssetRipper starter verified URL: `http://127.0.0.1:17777`
- AssetRipper sample export: not recorded unless `Extracted\Logs\assetripper-export-result.txt` exists

The AssetRipper GUI sample export remains a manual/operator step. This report does not claim AssetRipper export completed because `Extracted\Logs\assetripper-export-result.txt` was absent during this gate.

## Batch Decision

Do not start bulk migration yet.

Bulk migration should only start after the Unity validation scene opens without blocking compile errors and loads the copied samples in Unity play mode, and/or after the manual AssetRipper sample export is recorded in `Extracted\Logs\assetripper-export-result.txt`.

Before expanding the batch, confirm:

- The Unity validation scene opens and loads representative copied AssetBundle samples.
- The two transcoded OGG files are imported under `Assets\StellaGaia\Audio`.
- If using AssetRipper for expansion, sample export files exist under `Extracted\AssetRipper\Samples` and the export result is recorded.
- No files are written under `C:\SoftGame\YostarGames\StellaSora_CN`.
