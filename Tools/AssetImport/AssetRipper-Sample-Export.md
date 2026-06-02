# AssetRipper Sample Export

1. Run `powershell -ExecutionPolicy Bypass -File .\Tools\AssetImport\Start-AssetRipperSample.ps1`.
2. Open `http://127.0.0.1:17777`.
3. Load the sample AssetBundle files from `C:\SoftWork\Git\StellaGaia\Extracted\Samples\AssetBundle`.
4. Export to `C:\SoftWork\Git\StellaGaia\Extracted\AssetRipper\Samples`.
5. Confirm the export contains a Unity-style `Assets` directory or extracted asset files.
6. Record the result in `C:\SoftWork\Git\StellaGaia\Extracted\Logs\assetripper-export-result.txt`.
7. Stop only the returned `ProcessId` after export, for example `Stop-Process -Id <ProcessId>`, after confirming it is the AssetRipper process you started.

Success criteria:

- AssetRipper opens on port `17777`.
- At least one copied `.unity3d` sample loads without a fatal error.
- Exported files are written under `Extracted\AssetRipper\Samples`.
- No file is written under `C:\SoftGame\YostarGames\StellaSora_CN`.
