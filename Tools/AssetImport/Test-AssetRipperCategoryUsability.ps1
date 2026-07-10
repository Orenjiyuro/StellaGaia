[CmdletBinding()]
param(
    [string[]]$Category = @(
        'EffectArt',
        'UiOrItemArt',
        'NpcOrStoryArt',
        'EnemyArt',
        'CharacterArt'
    ),
    [string]$ManifestPath,
    [string]$ExportRoot,
    [string]$ValidationRoot,
    [string]$AssetListPath,
    [int]$SampleLimit = 12,
    [switch]$SkipUnity
)

$ErrorActionPreference = 'Stop'

$Category = @(
    foreach ($name in $Category) {
        foreach ($part in ([string]$name -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed) {
                $trimmed
            }
        }
    }
)

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$extractedRoot = Join-Path $repoRoot 'Extracted'
if (-not $ExportRoot) {
    $ExportRoot = Join-Path $extractedRoot 'AssetRipper\ByCategory'
}
if (-not $ValidationRoot) {
    $ValidationRoot = Join-Path $extractedRoot 'Validation\CategoryUsability'
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$unityEditor = [string]$manifest.unityEditor
$sourceInstall = [string]$manifest.sourceInstall

function Resolve-FullPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathInside {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Child,
        [Parameter(Mandatory = $true)]
        [string]$Parent
    )

    $childFull = (Resolve-FullPath -Path $Child).TrimEnd('\', '/')
    $parentFull = (Resolve-FullPath -Path $Parent).TrimEnd('\', '/')
    return $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-UnderExtracted {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-PathInside -Child $Path -Parent $extractedRoot)) {
        throw "$Label must stay under Extracted: $Path"
    }
}

function Assert-NotUnderSourceInstall {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if ($sourceInstall -and (Test-PathInside -Child $Path -Parent $sourceInstall)) {
        throw "$Label must not be written under source install: $Path"
    }
}

function Read-CategoryResult {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $path = Join-Path $extractedRoot "Logs\assetripper-category-$Name-result.txt"
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $folderResultPath = Join-Path $extractedRoot "Logs\assetripper-folder-$Name-result.txt"
        if (Test-Path -LiteralPath $folderResultPath -PathType Leaf) {
            $path = $folderResultPath
        }
    }
    $values = [ordered]@{
        Path = $path
        Exists = (Test-Path -LiteralPath $path -PathType Leaf)
    }

    if (-not $values.Exists) {
        return [PSCustomObject]$values
    }

    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^([^=]+)=(.*)$') {
            $values[$Matches[1]] = $Matches[2]
        }
    }

    return [PSCustomObject]$values
}

function Get-IntValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object -or -not ($Object.PSObject.Properties.Name -contains $Name)) {
        return 0
    }

    $value = [string]$Object.$Name
    $parsed = 0
    if ([int]::TryParse($value, [ref]$parsed)) {
        return $parsed
    }

    return 0
}

function Write-ValidatorScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    $editorDir = Join-Path $ProjectPath 'Assets\Editor'
    Assert-UnderExtracted -Path $editorDir -Label 'Temporary validator directory'
    Assert-NotUnderSourceInstall -Path $editorDir -Label 'Temporary validator directory'
    New-Item -ItemType Directory -Force -Path $editorDir | Out-Null

    $validatorPath = Join-Path $editorDir 'StellaGaiaExportUsabilityValidator.cs'
    $validatorSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace StellaGaia.ExportValidation
{
    public static class ExportedAssetUsabilityValidator
    {
        private const int ScreenshotSize = 512;
        private const float VisiblePixelThreshold = 0.002f;
        private static readonly Color BackgroundColor = new Color(0.075f, 0.075f, 0.075f, 1f);

        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string category = GetArg(args, "-stellaGaiaValidationCategory", "UnknownCategory");
            string outputDir = GetArg(args, "-stellaGaiaValidationOutput", Path.Combine(ProjectRoot(), "StellaGaiaValidation"));
            int sampleLimit = ParseInt(GetArg(args, "-stellaGaiaValidationSampleLimit", "12"), 12);
            string selectedAssetListPath = GetArg(args, "-stellaGaiaValidationAssetList", "");

            Directory.CreateDirectory(outputDir);
            string screenshotDir = Path.Combine(outputDir, "screenshots");
            Directory.CreateDirectory(screenshotDir);

            var report = new UsabilityReport
            {
                category = category,
                generatedAt = DateTimeOffset.Now.ToString("O"),
                projectPath = ProjectRoot(),
                sampleLimit = sampleLimit,
                screenshotsDirectory = screenshotDir,
                samples = new List<SampleResult>()
            };

            string[] prefabPaths = FindAssetPaths("t:Prefab");
            string[] scenePaths = FindAssetPaths("t:Scene");
            string[] texturePaths = FindAssetPaths("t:Texture2D");
            string[] audioPaths = FindAssetPaths("t:AudioClip");
            string[] materialPaths = FindAssetPaths("t:Material");
            string[] animationPaths = FindAssetPaths("t:AnimationClip");

            report.assetCounts = new AssetCounts
            {
                prefabs = prefabPaths.Length,
                scenes = scenePaths.Length,
                textures = texturePaths.Length,
                audioClips = audioPaths.Length,
                materials = materialPaths.Length,
                animationClips = animationPaths.Length
            };

            string[] selectedAssetPaths = ReadAssetList(selectedAssetListPath);
            if (selectedAssetPaths.Length > 0)
            {
                foreach (string path in selectedAssetPaths)
                {
                    report.samples.Add(ValidateAssetPath(path, screenshotDir));
                }
            }
            else
            {
                foreach (string path in SelectRepresentative(prefabPaths, sampleLimit))
                {
                    report.samples.Add(ValidatePrefab(path, screenshotDir));
                }

                foreach (string path in SelectRepresentative(scenePaths, sampleLimit))
                {
                    report.samples.Add(ValidateScene(path, screenshotDir));
                }

                if (CountVisible(report.samples) == 0)
                {
                    foreach (string path in SelectRepresentative(texturePaths, sampleLimit))
                    {
                        report.samples.Add(ValidateTexture(path, screenshotDir));
                    }
                }

                foreach (string path in SelectRepresentative(audioPaths, Math.Min(sampleLimit, 8)))
                {
                    report.samples.Add(ValidateAudio(path));
                }
            }

            Summarize(report);
            string reportPath = Path.Combine(outputDir, "validation.json");
            File.WriteAllText(reportPath, JsonUtility.ToJson(report, true));
            Debug.Log("StellaGaia category usability validation wrote " + reportPath);
        }

        private static string[] ReadAssetList(string assetListPath)
        {
            if (string.IsNullOrWhiteSpace(assetListPath) || !File.Exists(assetListPath))
            {
                return Array.Empty<string>();
            }

            var paths = new List<string>();
            foreach (string rawLine in File.ReadAllLines(assetListPath))
            {
                string line = rawLine.Trim();
                if (line.Length == 0 || line.StartsWith("#", StringComparison.Ordinal))
                {
                    continue;
                }

                paths.Add(line.Replace('\\', '/'));
            }

            return paths.ToArray();
        }

        private static SampleResult ValidateAssetPath(string path, string screenshotDir)
        {
            string extension = Path.GetExtension(path).ToLowerInvariant();
            switch (extension)
            {
                case ".prefab":
                    return ValidatePrefab(path, screenshotDir);
                case ".unity":
                    return ValidateScene(path, screenshotDir);
                case ".png":
                case ".jpg":
                case ".jpeg":
                case ".tga":
                case ".psd":
                    return ValidateTexture(path, screenshotDir);
                case ".wav":
                case ".ogg":
                case ".mp3":
                    return ValidateAudio(path);
                default:
                    var result = NewSample("Unsupported", path);
                    result.criticalIssueCount++;
                    result.error = "unsupported-selected-asset-extension";
                    return result;
            }
        }

        private static SampleResult ValidatePrefab(string path, string screenshotDir)
        {
            var result = NewSample("Prefab", path);
            GameObject asset = AssetDatabase.LoadAssetAtPath<GameObject>(path);
            if (asset == null)
            {
                result.criticalIssueCount++;
                result.error = "prefab-load-failed";
                return result;
            }

            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            GameObject instance = null;
            try
            {
                instance = PrefabUtility.InstantiatePrefab(asset) as GameObject;
                if (instance == null)
                {
                    result.criticalIssueCount++;
                    result.error = "prefab-instantiate-failed";
                    return result;
                }

                HashSet<GameObject> initiallyActiveObjects = CaptureInitiallyActiveObjects(instance);
                ActivateHierarchy(instance);
                SimulateParticles(instance);
                InspectGameObject(instance, result, initiallyActiveObjects);
                string screenshotPath = Path.Combine(screenshotDir, SafeFileName(path) + ".png");
                result.screenshot = screenshotPath;
                result.rendered = TryRenderGameObject(instance, screenshotPath, out result.nonBackgroundPixelRatio, out result.magentaPixelRatio, out result.renderError);
                result.visible = result.rendered && result.nonBackgroundPixelRatio >= VisiblePixelThreshold;
                if (result.magentaPixelRatio > 0.2f)
                {
                    result.criticalIssueCount++;
                }
            }
            catch (Exception ex)
            {
                result.criticalIssueCount++;
                result.error = ex.GetType().Name + ": " + ex.Message;
            }
            finally
            {
                if (instance != null)
                {
                    UnityEngine.Object.DestroyImmediate(instance);
                }
            }

            return result;
        }

        private static SampleResult ValidateScene(string path, string screenshotDir)
        {
            var result = NewSample("Scene", path);
            GameObject validationRoot = null;
            try
            {
                UnityEngine.SceneManagement.Scene scene = EditorSceneManager.OpenScene(path, OpenSceneMode.Single);
                GameObject[] roots = scene.GetRootGameObjects();
                if (roots == null || roots.Length == 0)
                {
                    result.criticalIssueCount++;
                    result.error = "scene-empty";
                    return result;
                }

                validationRoot = new GameObject("StellaGaiaValidationSceneRoot");
                foreach (GameObject root in roots)
                {
                    if (root != null && root != validationRoot)
                    {
                        root.transform.SetParent(validationRoot.transform, true);
                    }
                }

                HashSet<GameObject> initiallyActiveObjects = CaptureInitiallyActiveObjects(validationRoot);
                ActivateHierarchy(validationRoot);
                SimulateParticles(validationRoot);
                InspectGameObject(validationRoot, result, initiallyActiveObjects);
                string screenshotPath = Path.Combine(screenshotDir, SafeFileName(path) + ".png");
                result.screenshot = screenshotPath;
                result.rendered = TryRenderGameObject(validationRoot, screenshotPath, out result.nonBackgroundPixelRatio, out result.magentaPixelRatio, out result.renderError);
                result.visible = result.rendered && result.nonBackgroundPixelRatio >= VisiblePixelThreshold;
                if (result.magentaPixelRatio > 0.2f)
                {
                    result.criticalIssueCount++;
                }
            }
            catch (Exception ex)
            {
                result.criticalIssueCount++;
                result.error = ex.GetType().Name + ": " + ex.Message;
            }
            finally
            {
                if (validationRoot != null)
                {
                    UnityEngine.Object.DestroyImmediate(validationRoot);
                }
            }

            return result;
        }

        private static SampleResult ValidateTexture(string path, string screenshotDir)
        {
            var result = NewSample("Texture2D", path);
            Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
            if (texture == null)
            {
                result.criticalIssueCount++;
                result.error = "texture-load-failed";
                return result;
            }

            result.textureWidth = texture.width;
            result.textureHeight = texture.height;
            string screenshotPath = Path.Combine(screenshotDir, SafeFileName(path) + ".png");
            result.screenshot = screenshotPath;
            result.rendered = TryRenderTexture(texture, screenshotPath, out result.nonBackgroundPixelRatio, out result.magentaPixelRatio, out result.renderError);
            result.visible = result.rendered && result.nonBackgroundPixelRatio >= VisiblePixelThreshold;
            if (result.magentaPixelRatio > 0.2f)
            {
                result.criticalIssueCount++;
            }

            return result;
        }

        private static SampleResult ValidateAudio(string path)
        {
            var result = NewSample("AudioClip", path);
            AudioClip clip = AssetDatabase.LoadAssetAtPath<AudioClip>(path);
            if (clip == null)
            {
                result.criticalIssueCount++;
                result.error = "audio-load-failed";
                return result;
            }

            result.audioLengthSeconds = clip.length;
            result.audioFrequency = clip.frequency;
            result.audioChannels = clip.channels;
            result.audibleCandidate = clip.length > 0f && clip.frequency > 0 && clip.channels > 0;
            return result;
        }

        private static void InspectGameObject(GameObject root, SampleResult result, HashSet<GameObject> initiallyActiveObjects)
        {
            GameObject[] objects = root.GetComponentsInChildren<Transform>(true).ConvertAll(t => t.gameObject);
            foreach (GameObject obj in objects)
            {
                int missingScripts = GameObjectUtility.GetMonoBehavioursWithMissingScriptCount(obj);
                if (missingScripts <= 0)
                {
                    continue;
                }

                result.missingScriptCount += missingScripts;
                if (WasInitiallyActive(obj, initiallyActiveObjects))
                {
                    result.activeMissingScriptCount += missingScripts;
                    AddIssueDetail(result, "active:missing-script:" + HierarchyPath(obj) + ":count=" + missingScripts);
                }
                else
                {
                    result.inactiveMissingScriptCount += missingScripts;
                    AddIssueDetail(result, "inactive:missing-script:" + HierarchyPath(obj) + ":count=" + missingScripts);
                }
            }

            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            result.rendererCount = renderers.Length;
            foreach (Renderer renderer in renderers)
            {
                bool rendererWasActive = WasInitiallyActive(renderer.gameObject, initiallyActiveObjects) && renderer.enabled;
                if (rendererWasActive)
                {
                    result.activeRendererCount++;
                }
                else
                {
                    result.inactiveRendererCount++;
                }

                if (renderer is SkinnedMeshRenderer skinned && skinned.sharedMesh == null)
                {
                    result.missingMeshCount++;
                    if (rendererWasActive)
                    {
                        result.activeMissingMeshCount++;
                        AddIssueDetail(result, "active:missing-skinned-mesh:" + HierarchyPath(renderer.gameObject));
                    }
                    else
                    {
                        result.inactiveMissingMeshCount++;
                        AddIssueDetail(result, "inactive:missing-skinned-mesh:" + HierarchyPath(renderer.gameObject));
                    }
                }

                MeshFilter meshFilter = renderer.GetComponent<MeshFilter>();
                if (meshFilter != null && meshFilter.sharedMesh == null)
                {
                    result.missingMeshCount++;
                    if (rendererWasActive)
                    {
                        result.activeMissingMeshCount++;
                        AddIssueDetail(result, "active:missing-mesh-filter-mesh:" + HierarchyPath(renderer.gameObject));
                    }
                    else
                    {
                        result.inactiveMissingMeshCount++;
                        AddIssueDetail(result, "inactive:missing-mesh-filter-mesh:" + HierarchyPath(renderer.gameObject));
                    }
                }

                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    result.missingMaterialSlotCount++;
                    if (rendererWasActive)
                    {
                        result.activeMissingMaterialSlotCount++;
                        AddIssueDetail(result, "active:empty-materials:" + HierarchyPath(renderer.gameObject));
                    }
                    else
                    {
                        result.inactiveMissingMaterialSlotCount++;
                        AddIssueDetail(result, "inactive:empty-materials:" + HierarchyPath(renderer.gameObject));
                    }
                }
                else
                {
                    foreach (Material material in materials)
                    {
                        if (material == null)
                        {
                            result.missingMaterialSlotCount++;
                            if (rendererWasActive)
                            {
                                result.activeMissingMaterialSlotCount++;
                                AddIssueDetail(result, "active:null-material-slot:" + HierarchyPath(renderer.gameObject));
                            }
                            else
                            {
                                result.inactiveMissingMaterialSlotCount++;
                                AddIssueDetail(result, "inactive:null-material-slot:" + HierarchyPath(renderer.gameObject));
                            }
                        }
                        else if (material.shader == null || material.shader.name == "Hidden/InternalErrorShader")
                        {
                            result.pinkOrBrokenShaderCount++;
                            if (rendererWasActive)
                            {
                                result.activePinkOrBrokenShaderCount++;
                                AddIssueDetail(result, "active:broken-shader:" + HierarchyPath(renderer.gameObject) + ":" + material.name);
                            }
                            else
                            {
                                result.inactivePinkOrBrokenShaderCount++;
                                AddIssueDetail(result, "inactive:broken-shader:" + HierarchyPath(renderer.gameObject) + ":" + material.name);
                            }
                        }
                    }
                }
            }

            foreach (SpriteRenderer spriteRenderer in root.GetComponentsInChildren<SpriteRenderer>(true))
            {
                if (spriteRenderer.sprite == null)
                {
                    result.nullSpriteCount++;
                    if (WasInitiallyActive(spriteRenderer.gameObject, initiallyActiveObjects))
                    {
                        result.activeNullSpriteCount++;
                        AddIssueDetail(result, "active:null-sprite:" + HierarchyPath(spriteRenderer.gameObject));
                    }
                    else
                    {
                        result.inactiveNullSpriteCount++;
                        AddIssueDetail(result, "inactive:null-sprite:" + HierarchyPath(spriteRenderer.gameObject));
                    }
                }
            }

            foreach (Animator animator in root.GetComponentsInChildren<Animator>(true))
            {
                if (animator.runtimeAnimatorController == null)
                {
                    result.missingAnimatorControllerCount++;
                    if (WasInitiallyActive(animator.gameObject, initiallyActiveObjects))
                    {
                        result.activeMissingAnimatorControllerCount++;
                        AddIssueDetail(result, "active:missing-animator-controller:" + HierarchyPath(animator.gameObject));
                    }
                    else
                    {
                        result.inactiveMissingAnimatorControllerCount++;
                        AddIssueDetail(result, "inactive:missing-animator-controller:" + HierarchyPath(animator.gameObject));
                    }
                }
            }

            result.particleSystemCount = root.GetComponentsInChildren<ParticleSystem>(true).Length;
            result.criticalIssueCount += result.activeMissingScriptCount;
            result.criticalIssueCount += result.activeMissingMeshCount;
            result.criticalIssueCount += result.activeMissingMaterialSlotCount;
            result.criticalIssueCount += result.activePinkOrBrokenShaderCount;
            result.knownIssueCount += result.inactiveMissingScriptCount;
            result.knownIssueCount += result.inactiveMissingMeshCount;
            result.knownIssueCount += result.inactiveMissingMaterialSlotCount;
            result.knownIssueCount += result.inactivePinkOrBrokenShaderCount;
            result.knownIssueCount += result.missingAnimatorControllerCount;
            result.knownIssueCount += result.nullSpriteCount;
        }

        private static bool TryRenderGameObject(GameObject root, string path, out float nonBackgroundRatio, out float magentaRatio, out string error)
        {
            nonBackgroundRatio = 0f;
            magentaRatio = 0f;
            error = "";

            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(false);
            if (renderers.Length == 0)
            {
                error = "no-enabled-renderers";
                return false;
            }

            Bounds bounds = new Bounds(root.transform.position, Vector3.one);
            bool hasBounds = false;
            foreach (Renderer renderer in renderers)
            {
                if (!renderer.enabled)
                {
                    continue;
                }

                if (!hasBounds)
                {
                    bounds = renderer.bounds;
                    hasBounds = true;
                }
                else
                {
                    bounds.Encapsulate(renderer.bounds);
                }
            }

            if (!hasBounds)
            {
                error = "no-renderer-bounds";
                return false;
            }

            Light light = CreateLight();
            try
            {
                return RenderBestCameraView(bounds, path, out nonBackgroundRatio, out magentaRatio, out error);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(light.gameObject);
            }
        }

        private static bool TryRenderTexture(Texture texture, string path, out float nonBackgroundRatio, out float magentaRatio, out string error)
        {
            nonBackgroundRatio = 0f;
            magentaRatio = 0f;
            error = "";

            EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            GameObject quad = GameObject.CreatePrimitive(PrimitiveType.Quad);
            Shader shader = Shader.Find("Unlit/Texture");
            if (shader == null)
            {
                shader = Shader.Find("Sprites/Default");
            }

            if (shader == null)
            {
                error = "missing-unlit-shader";
                UnityEngine.Object.DestroyImmediate(quad);
                return false;
            }

            Material material = new Material(shader);
            material.mainTexture = texture;
            quad.GetComponent<Renderer>().sharedMaterial = material;
            Camera camera = new GameObject("StellaGaiaValidationCamera").AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = BackgroundColor;
            camera.orthographic = true;
            camera.orthographicSize = 0.75f;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = 20f;
            camera.transform.position = new Vector3(0f, 0f, -3f);
            camera.transform.LookAt(Vector3.zero);

            try
            {
                return RenderCamera(camera, path, out nonBackgroundRatio, out magentaRatio, out error);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(material);
                UnityEngine.Object.DestroyImmediate(quad);
                UnityEngine.Object.DestroyImmediate(camera.gameObject);
            }
        }

        private static bool RenderBestCameraView(Bounds bounds, string path, out float nonBackgroundRatio, out float magentaRatio, out string error)
        {
            nonBackgroundRatio = 0f;
            magentaRatio = 0f;
            error = "";

            Vector3[] directions =
            {
                new Vector3(0f, 0f, -1f),
                new Vector3(0f, 1f, 0f),
                new Vector3(0f, -1f, 0f),
                new Vector3(1f, 1f, -1f),
                new Vector3(-1f, 1f, -1f)
            };

            bool rendered = false;
            string bestPath = "";
            string lastError = "";
            float bestNonBackgroundRatio = -1f;
            float bestMagentaRatio = 0f;
            var temporaryPaths = new List<string>();

            for (int i = 0; i < directions.Length; i++)
            {
                string candidatePath = path + ".view" + i + ".png";
                temporaryPaths.Add(candidatePath);
                Camera camera = CreateCamera(bounds, directions[i]);
                try
                {
                    float candidateNonBackgroundRatio;
                    float candidateMagentaRatio;
                    string candidateError;
                    bool candidateRendered = RenderCamera(camera, candidatePath, out candidateNonBackgroundRatio, out candidateMagentaRatio, out candidateError);
                    if (!candidateRendered)
                    {
                        lastError = candidateError;
                        continue;
                    }

                    rendered = true;
                    if (candidateNonBackgroundRatio > bestNonBackgroundRatio)
                    {
                        bestNonBackgroundRatio = candidateNonBackgroundRatio;
                        bestMagentaRatio = candidateMagentaRatio;
                        bestPath = candidatePath;
                    }
                }
                finally
                {
                    UnityEngine.Object.DestroyImmediate(camera.gameObject);
                }
            }

            if (!rendered || string.IsNullOrEmpty(bestPath))
            {
                error = string.IsNullOrEmpty(lastError) ? "all-camera-views-failed" : lastError;
                return false;
            }

            File.Copy(bestPath, path, true);
            foreach (string temporaryPath in temporaryPaths)
            {
                if (!temporaryPath.Equals(bestPath, StringComparison.OrdinalIgnoreCase) && File.Exists(temporaryPath))
                {
                    File.Delete(temporaryPath);
                }
            }
            if (File.Exists(bestPath))
            {
                File.Delete(bestPath);
            }

            nonBackgroundRatio = bestNonBackgroundRatio;
            magentaRatio = bestMagentaRatio;
            return true;
        }

        private static Camera CreateCamera(Bounds bounds, Vector3 direction)
        {
            GameObject cameraObject = new GameObject("StellaGaiaValidationCamera");
            Camera camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = BackgroundColor;
            camera.orthographic = true;
            float extent = Mathf.Max(bounds.extents.x, bounds.extents.y, bounds.extents.z);
            camera.orthographicSize = Mathf.Max(extent * 1.35f, 0.5f);
            float distance = Mathf.Max(extent * 4f, 4f);
            Vector3 center = bounds.center;
            camera.transform.position = center + direction.normalized * distance;
            camera.transform.LookAt(center);
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = distance + Mathf.Max(extent * 8f, 100f);
            return camera;
        }

        private static Light CreateLight()
        {
            GameObject lightObject = new GameObject("StellaGaiaValidationLight");
            Light light = lightObject.AddComponent<Light>();
            light.type = LightType.Directional;
            light.intensity = 1.5f;
            light.transform.rotation = Quaternion.Euler(45f, -35f, 0f);
            return light;
        }

        private static bool RenderCamera(Camera camera, string path, out float nonBackgroundRatio, out float magentaRatio, out string error)
        {
            nonBackgroundRatio = 0f;
            magentaRatio = 0f;
            error = "";
            RenderTexture renderTexture = new RenderTexture(ScreenshotSize, ScreenshotSize, 24, RenderTextureFormat.ARGB32);
            Texture2D image = new Texture2D(ScreenshotSize, ScreenshotSize, TextureFormat.RGBA32, false);
            RenderTexture previousActive = RenderTexture.active;

            try
            {
                camera.targetTexture = renderTexture;
                RenderTexture.active = renderTexture;
                camera.Render();
                image.ReadPixels(new Rect(0, 0, ScreenshotSize, ScreenshotSize), 0, 0);
                image.Apply();
                AnalyzeImage(image, out nonBackgroundRatio, out magentaRatio);
                File.WriteAllBytes(path, image.EncodeToPNG());
                return true;
            }
            catch (Exception ex)
            {
                error = ex.GetType().Name + ": " + ex.Message;
                return false;
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = previousActive;
                renderTexture.Release();
                UnityEngine.Object.DestroyImmediate(renderTexture);
                UnityEngine.Object.DestroyImmediate(image);
            }
        }

        private static void AnalyzeImage(Texture2D image, out float nonBackgroundRatio, out float magentaRatio)
        {
            Color32[] pixels = image.GetPixels32();
            int nonBackground = 0;
            int magenta = 0;
            byte bgR = (byte)Mathf.RoundToInt(BackgroundColor.r * 255f);
            byte bgG = (byte)Mathf.RoundToInt(BackgroundColor.g * 255f);
            byte bgB = (byte)Mathf.RoundToInt(BackgroundColor.b * 255f);

            foreach (Color32 pixel in pixels)
            {
                int delta = Math.Abs(pixel.r - bgR) + Math.Abs(pixel.g - bgG) + Math.Abs(pixel.b - bgB);
                if (delta > 18 && pixel.a > 8)
                {
                    nonBackground++;
                }

                if (pixel.r > 190 && pixel.g < 90 && pixel.b > 190 && pixel.a > 128)
                {
                    magenta++;
                }
            }

            nonBackgroundRatio = pixels.Length == 0 ? 0f : (float)nonBackground / pixels.Length;
            magentaRatio = pixels.Length == 0 ? 0f : (float)magenta / pixels.Length;
        }

        private static void SimulateParticles(GameObject root)
        {
            foreach (ParticleSystem particleSystem in root.GetComponentsInChildren<ParticleSystem>(true))
            {
                particleSystem.Simulate(1.0f, true, true, true);
                particleSystem.Play(true);
            }
        }

        private static HashSet<GameObject> CaptureInitiallyActiveObjects(GameObject root)
        {
            var activeObjects = new HashSet<GameObject>();
            foreach (Transform transform in root.GetComponentsInChildren<Transform>(true))
            {
                if (transform.gameObject.activeInHierarchy)
                {
                    activeObjects.Add(transform.gameObject);
                }
            }

            return activeObjects;
        }

        private static bool WasInitiallyActive(GameObject obj, HashSet<GameObject> initiallyActiveObjects)
        {
            return initiallyActiveObjects == null || initiallyActiveObjects.Contains(obj);
        }

        private static void AddIssueDetail(SampleResult result, string detail)
        {
            if (result.issueDetails == null)
            {
                result.issueDetails = new List<string>();
            }

            if (result.issueDetails.Count < 64)
            {
                result.issueDetails.Add(detail);
            }
        }

        private static string HierarchyPath(GameObject obj)
        {
            var parts = new List<string>();
            Transform current = obj.transform;
            while (current != null)
            {
                parts.Add(current.name);
                current = current.parent;
            }

            parts.Reverse();
            return string.Join("/", parts.ToArray());
        }

        private static void ActivateHierarchy(GameObject root)
        {
            foreach (Transform transform in root.GetComponentsInChildren<Transform>(true))
            {
                transform.gameObject.SetActive(true);
            }
        }

        private static void Summarize(UsabilityReport report)
        {
            report.sampleCount = report.samples.Count;
            foreach (SampleResult sample in report.samples)
            {
                report.criticalIssueCount += sample.criticalIssueCount;
                report.knownIssueCount += sample.knownIssueCount;
                if (sample.rendered)
                {
                    report.renderAttemptCount++;
                }
                if (sample.visible)
                {
                    report.visibleSampleCount++;
                }
                if (sample.audibleCandidate)
                {
                    report.audibleCandidateCount++;
                }
            }

            if (report.visibleSampleCount > 0)
            {
                report.status = report.criticalIssueCount > 0 || report.knownIssueCount > 0 ? "UsableWithKnownIssues" : "Usable";
            }
            else if (report.audibleCandidateCount > 0)
            {
                report.status = "ImportOnly";
            }
            else
            {
                report.status = "NotUsableYet";
            }
        }

        private static string[] FindAssetPaths(string filter)
        {
            string[] guids = AssetDatabase.FindAssets(filter, new[] { "Assets" });
            var paths = new List<string>(guids.Length);
            foreach (string guid in guids)
            {
                paths.Add(AssetDatabase.GUIDToAssetPath(guid));
            }
            paths.Sort(StringComparer.OrdinalIgnoreCase);
            return paths.ToArray();
        }

        private static IEnumerable<string> SelectRepresentative(string[] paths, int limit)
        {
            if (paths == null || paths.Length == 0 || limit <= 0)
            {
                yield break;
            }

            if (paths.Length <= limit)
            {
                foreach (string path in paths)
                {
                    yield return path;
                }
                yield break;
            }

            var used = new HashSet<int>();
            for (int i = 0; i < limit; i++)
            {
                int index = limit == 1 ? 0 : Mathf.RoundToInt(i * (paths.Length - 1) / (float)(limit - 1));
                if (used.Add(index))
                {
                    yield return paths[index];
                }
            }
        }

        private static SampleResult NewSample(string kind, string path)
        {
            return new SampleResult
            {
                kind = kind,
                path = path,
                issueDetails = new List<string>()
            };
        }

        private static string SafeFileName(string path)
        {
            char[] chars = path.ToCharArray();
            for (int i = 0; i < chars.Length; i++)
            {
                if (!char.IsLetterOrDigit(chars[i]))
                {
                    chars[i] = '_';
                }
            }

            string value = new string(chars);
            if (value.Length > 160)
            {
                value = value.Substring(value.Length - 160);
            }

            return value;
        }

        private static int CountVisible(List<SampleResult> samples)
        {
            int count = 0;
            foreach (SampleResult sample in samples)
            {
                if (sample.visible)
                {
                    count++;
                }
            }

            return count;
        }

        private static string ProjectRoot()
        {
            return Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
        }

        private static string GetArg(string[] args, string name, string fallback)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] == name)
                {
                    return args[i + 1];
                }
            }

            return fallback;
        }

        private static int ParseInt(string value, int fallback)
        {
            int parsed;
            return int.TryParse(value, out parsed) ? parsed : fallback;
        }
    }

    [Serializable]
    public class UsabilityReport
    {
        public string category;
        public string generatedAt;
        public string projectPath;
        public int sampleLimit;
        public string screenshotsDirectory;
        public AssetCounts assetCounts;
        public int sampleCount;
        public int renderAttemptCount;
        public int visibleSampleCount;
        public int audibleCandidateCount;
        public int criticalIssueCount;
        public int knownIssueCount;
        public string status;
        public List<SampleResult> samples;
    }

    [Serializable]
    public class AssetCounts
    {
        public int prefabs;
        public int scenes;
        public int textures;
        public int audioClips;
        public int materials;
        public int animationClips;
    }

    [Serializable]
    public class SampleResult
    {
        public string kind;
        public string path;
        public string screenshot;
        public bool rendered;
        public bool visible;
        public bool audibleCandidate;
        public float nonBackgroundPixelRatio;
        public float magentaPixelRatio;
        public string renderError;
        public string error;
        public List<string> issueDetails;
        public int rendererCount;
        public int activeRendererCount;
        public int inactiveRendererCount;
        public int particleSystemCount;
        public int missingScriptCount;
        public int activeMissingScriptCount;
        public int inactiveMissingScriptCount;
        public int missingMeshCount;
        public int activeMissingMeshCount;
        public int inactiveMissingMeshCount;
        public int missingMaterialSlotCount;
        public int activeMissingMaterialSlotCount;
        public int inactiveMissingMaterialSlotCount;
        public int pinkOrBrokenShaderCount;
        public int activePinkOrBrokenShaderCount;
        public int inactivePinkOrBrokenShaderCount;
        public int missingAnimatorControllerCount;
        public int activeMissingAnimatorControllerCount;
        public int inactiveMissingAnimatorControllerCount;
        public int nullSpriteCount;
        public int activeNullSpriteCount;
        public int inactiveNullSpriteCount;
        public int criticalIssueCount;
        public int knownIssueCount;
        public int textureWidth;
        public int textureHeight;
        public float audioLengthSeconds;
        public int audioFrequency;
        public int audioChannels;
    }

    internal static class ComponentConversionExtensions
    {
        public static GameObject[] ConvertAll(this Transform[] transforms, Func<Transform, GameObject> converter)
        {
            var objects = new GameObject[transforms.Length];
            for (int i = 0; i < transforms.Length; i++)
            {
                objects[i] = converter(transforms[i]);
            }

            return objects;
        }
    }
}
'@

    Set-Content -LiteralPath $validatorPath -Value $validatorSource -Encoding UTF8
    return $validatorPath
}

function Test-UnityLog {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{
            Exists = $false
            CriticalLogIssueCount = 1
            CriticalLogIssues = @('missing-unity-log')
        }
    }

    $patterns = @(
        'error CS\d+',
        'Scripts have compiler errors',
        'Aborting batchmode due to failure',
        'Fatal error',
        'executeMethod method .* could not be found',
        'executeMethod method .* couldn''t be found',
        'Asset import failed'
    )

    $issues = New-Object System.Collections.Generic.List[string]
    foreach ($line in Get-Content -LiteralPath $Path) {
        foreach ($pattern in $patterns) {
            if ($line -match $pattern) {
                $issues.Add($line)
                break
            }
        }
    }

    return [PSCustomObject]@{
        Exists = $true
        CriticalLogIssueCount = $issues.Count
        CriticalLogIssues = @($issues | Select-Object -First 20)
    }
}

function Invoke-UnityEditor {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $process = Start-Process -FilePath $unityEditor -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    return $process.ExitCode
}

function Invoke-CategoryValidation {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $categoryOutput = Join-Path $ValidationRoot $Name
    Assert-UnderExtracted -Path $categoryOutput -Label 'Category validation output'
    Assert-NotUnderSourceInstall -Path $categoryOutput -Label 'Category validation output'
    New-Item -ItemType Directory -Force -Path $categoryOutput | Out-Null

    $categoryResult = Read-CategoryResult -Name $Name
    $projectPath = Join-Path $ExportRoot "$Name\ExportedProject"
    $projectVersionPath = Join-Path $projectPath 'ProjectSettings\ProjectVersion.txt'
    $validationJsonPath = Join-Path $categoryOutput 'validation.json'
    $unityLogPath = Join-Path $categoryOutput 'unity-import-and-validation.log'

    $base = [ordered]@{
        Category = $Name
        ProjectPath = $projectPath
        ValidationJson = $validationJsonPath
        UnityLog = $unityLogPath
        AssetRipperStatus = if ($categoryResult.PSObject.Properties.Name -contains 'Status') { $categoryResult.Status } else { 'Unknown' }
        MissingDependencyWarnings = Get-IntValue -Object $categoryResult -Name 'MissingDependencyWarnings'
        UniqueMissingCabCount = Get-IntValue -Object $categoryResult -Name 'UniqueMissingCabCount'
        UnityExitCode = $null
        ImportStatus = 'Pending'
        VisibleSampleCount = 0
        AudibleCandidateCount = 0
        CriticalIssueCount = 0
        CriticalLogIssueCount = 0
        UsabilityStatus = 'Pending'
        AllowBatchExpansion = $false
        Notes = ''
    }

    if (-not (Test-Path -LiteralPath $projectPath -PathType Container) -or -not (Test-Path -LiteralPath $projectVersionPath -PathType Leaf)) {
        $base.Notes = 'Missing AssetRipper exported Unity project; visual validation cannot run.'
        return [PSCustomObject]$base
    }

    Assert-UnderExtracted -Path $projectPath -Label 'AssetRipper exported project'
    Assert-NotUnderSourceInstall -Path $projectPath -Label 'AssetRipper exported project'

    if (-not $SkipUnity) {
        Write-ValidatorScript -ProjectPath $projectPath | Out-Null
        $arguments = @(
            '-batchmode',
            '-quit',
            '-projectPath', $projectPath,
            '-executeMethod', 'StellaGaia.ExportValidation.ExportedAssetUsabilityValidator.Run',
            '-logFile', $unityLogPath,
            '-stellaGaiaValidationOutput', $categoryOutput,
            '-stellaGaiaValidationCategory', $Name,
            '-stellaGaiaValidationSampleLimit', ([string]$SampleLimit)
        )
        if (-not [string]::IsNullOrWhiteSpace($AssetListPath)) {
            $arguments += @('-stellaGaiaValidationAssetList', $AssetListPath)
        }

        $base.UnityExitCode = Invoke-UnityEditor -Arguments $arguments
        if ($null -eq $base.UnityExitCode -and (Test-Path -LiteralPath $validationJsonPath -PathType Leaf)) {
            $base.UnityExitCode = 0
        }

        if (-not (Test-Path -LiteralPath $validationJsonPath -PathType Leaf)) {
            $base.UnityExitCode = Invoke-UnityEditor -Arguments $arguments
            if ($null -eq $base.UnityExitCode -and (Test-Path -LiteralPath $validationJsonPath -PathType Leaf)) {
                $base.UnityExitCode = 0
            }
        }
    } else {
        $base.UnityExitCode = 0
        $base.Notes = 'Unity execution skipped by -SkipUnity.'
    }

    $logResult = Test-UnityLog -Path $unityLogPath
    $base.CriticalLogIssueCount = $logResult.CriticalLogIssueCount

    if ($base.UnityExitCode -eq 0 -and $base.CriticalLogIssueCount -eq 0) {
        $base.ImportStatus = 'Imported'
    } else {
        $base.ImportStatus = 'ImportFailed'
    }

    if (Test-Path -LiteralPath $validationJsonPath -PathType Leaf) {
        $validation = Get-Content -LiteralPath $validationJsonPath -Raw | ConvertFrom-Json
        $base.VisibleSampleCount = [int]$validation.visibleSampleCount
        $base.AudibleCandidateCount = [int]$validation.audibleCandidateCount
        $base.CriticalIssueCount = [int]$validation.criticalIssueCount
    }

    if ($base.ImportStatus -ne 'Imported') {
        $base.UsabilityStatus = 'NotUsableYet'
        if (-not $base.Notes) {
            $base.Notes = 'Unity import or validator execution failed.'
        }
    } elseif ($base.VisibleSampleCount -gt 0) {
        if ($base.MissingDependencyWarnings -gt 0 -or $base.CriticalIssueCount -gt 0) {
            $base.UsabilityStatus = 'UsableWithKnownIssues'
            $base.Notes = 'Representative visual samples rendered, but dependency or extraction issues remain.'
        } else {
            $base.UsabilityStatus = 'Usable'
            $base.AllowBatchExpansion = $true
            $base.Notes = 'Representative visual samples rendered with no critical sampled issues.'
        }
    } elseif ($base.AudibleCandidateCount -gt 0) {
        $base.UsabilityStatus = 'ImportOnly'
        $base.Notes = 'Only audio/import evidence was produced; no visual sample passed.'
    } else {
        $base.UsabilityStatus = 'NotUsableYet'
        $base.Notes = 'No representative visible sample rendered.'
    }

    return [PSCustomObject]$base
}

if (-not (Test-Path -LiteralPath $unityEditor -PathType Leaf)) {
    throw "Missing Unity editor: $unityEditor"
}

Assert-UnderExtracted -Path $ExportRoot -Label 'Export root'
Assert-UnderExtracted -Path $ValidationRoot -Label 'Validation root'
Assert-NotUnderSourceInstall -Path $ExportRoot -Label 'Export root'
Assert-NotUnderSourceInstall -Path $ValidationRoot -Label 'Validation root'
if (-not [string]::IsNullOrWhiteSpace($AssetListPath)) {
    $AssetListPath = Resolve-FullPath -Path $AssetListPath
    Assert-UnderExtracted -Path $AssetListPath -Label 'Selected asset list'
    Assert-NotUnderSourceInstall -Path $AssetListPath -Label 'Selected asset list'
    if (-not (Test-Path -LiteralPath $AssetListPath -PathType Leaf)) {
        throw "Missing selected asset list: $AssetListPath"
    }
}

New-Item -ItemType Directory -Force -Path $ValidationRoot | Out-Null
$results = foreach ($name in $Category) {
    Invoke-CategoryValidation -Name $name
}

$summaryJson = Join-Path $extractedRoot 'Logs\asset-category-usability-summary.json'
$summaryCsv = Join-Path $extractedRoot 'Logs\asset-category-usability-summary.csv'
Assert-UnderExtracted -Path $summaryJson -Label 'Summary JSON'
Assert-UnderExtracted -Path $summaryCsv -Label 'Summary CSV'
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
$results | Export-Csv -LiteralPath $summaryCsv -NoTypeInformation -Encoding UTF8

$results | Format-Table -AutoSize Category, ImportStatus, VisibleSampleCount, CriticalIssueCount, MissingDependencyWarnings, UsabilityStatus, AllowBatchExpansion
Write-Host "Wrote category usability summary to $summaryJson"
