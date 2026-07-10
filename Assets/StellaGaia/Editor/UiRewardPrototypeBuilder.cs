using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.EditorTools
{
    public static class UiRewardPrototypeBuilder
    {
        private const string ControlledAssetRoot = "Assets/StellaGaia/Imported/ControlledCandidates/";
        private const string GeneratedAssetRoot = "Assets/StellaGaia/Imported/ControlledCandidates/ui_reward/PrototypeRebuild/Generated/";
        private const int ScreenshotSize = 512;
        private const float VisiblePixelThreshold = 0.002f;
        private static readonly Color BackgroundColor = new Color(0.075f, 0.075f, 0.075f, 1f);

        [MenuItem("StellaGaia/Build UI Reward Prototype")]
        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string projectRoot = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            string specPath = ResolveProjectRelativePath(projectRoot, GetArg(args, "-stellaGaiaUiRewardPrototypeSpec", Path.Combine("Extracted", "Validation", "UiRewardPrototypeRebuildPlan", "ui-reward-prototype-rebuild-spec.json")));
            string outputDirectory = ResolveProjectRelativePath(projectRoot, GetArg(args, "-stellaGaiaUiRewardPrototypeOutput", Path.Combine("Extracted", "Validation", "UiRewardPrototypeBuild")));
            bool overwrite = string.Equals(GetArg(args, "-stellaGaiaUiRewardPrototypeOverwrite", "false"), "true", StringComparison.OrdinalIgnoreCase);

            AssertOutputDirectorySafe(projectRoot, outputDirectory);
            if (string.IsNullOrWhiteSpace(specPath) || !File.Exists(specPath))
            {
                throw new InvalidOperationException($"Missing UI reward prototype spec: {specPath}");
            }

            Directory.CreateDirectory(outputDirectory);

            var report = new UiRewardPrototypeBuildReport
            {
                generatedAt = DateTimeOffset.Now.ToString("O"),
                specPath = Path.GetFullPath(specPath),
                outputDirectory = Path.GetFullPath(outputDirectory),
                overwrite = overwrite,
                textures = new List<UiRewardTextureBuildResult>(),
                prefabs = new List<UiRewardPrefabBuildResult>()
            };

            UiRewardPrototypeSpec spec = ReadSpec(specPath);
            Dictionary<string, UiRewardTextureBuildResult> texturesByRole = ImportTextures(spec, report);
            BuildPrefabs(projectRoot, outputDirectory, spec, texturesByRole, report, overwrite);
            Summarize(report);

            string jsonPath = Path.Combine(outputDirectory, "unity-ui-reward-prototype-build.json");
            string textPath = Path.Combine(outputDirectory, "unity-ui-reward-prototype-build.txt");
            File.WriteAllText(jsonPath, JsonUtility.ToJson(report, true));
            File.WriteAllLines(textPath, BuildTextReport(report));
            Debug.Log($"Wrote UI reward prototype build report to {jsonPath}");

            if (report.criticalIssueCount > 0)
            {
                throw new InvalidOperationException($"UI reward prototype build found {report.criticalIssueCount} critical issue(s). See {jsonPath}");
            }
        }

        private static Dictionary<string, UiRewardTextureBuildResult> ImportTextures(UiRewardPrototypeSpec spec, UiRewardPrototypeBuildReport report)
        {
            var byRole = new Dictionary<string, UiRewardTextureBuildResult>(StringComparer.OrdinalIgnoreCase);
            foreach (UiRewardTextureSpec texture in spec.textureAssets ?? Array.Empty<UiRewardTextureSpec>())
            {
                var result = new UiRewardTextureBuildResult
                {
                    id = texture.id,
                    role = texture.role,
                    targetAssetPath = texture.targetAssetPath,
                    review = texture.review,
                    expectedWidth = texture.width,
                    expectedHeight = texture.height
                };
                report.textures.Add(result);

                try
                {
                    AssertControlledAssetPath(texture.targetAssetPath, "texture asset");
                    TextureImporter importer = AssetImporter.GetAtPath(texture.targetAssetPath) as TextureImporter;
                    if (importer == null)
                    {
                        result.status = "MissingTextureImporter";
                        result.error = "assetimporter-null-or-not-texture";
                        result.criticalIssueCount++;
                        continue;
                    }

                    bool changed = false;
                    if (importer.textureType != TextureImporterType.Sprite)
                    {
                        importer.textureType = TextureImporterType.Sprite;
                        changed = true;
                    }
                    if (importer.spriteImportMode != SpriteImportMode.Single)
                    {
                        importer.spriteImportMode = SpriteImportMode.Single;
                        changed = true;
                    }
                    if (importer.mipmapEnabled)
                    {
                        importer.mipmapEnabled = false;
                        changed = true;
                    }
                    if (!importer.alphaIsTransparency)
                    {
                        importer.alphaIsTransparency = true;
                        changed = true;
                    }
                    if (changed)
                    {
                        importer.SaveAndReimport();
                    }

                    Texture2D textureAsset = AssetDatabase.LoadAssetAtPath<Texture2D>(texture.targetAssetPath);
                    Sprite sprite = AssetDatabase.LoadAssetAtPath<Sprite>(texture.targetAssetPath);
                    if (textureAsset == null || sprite == null)
                    {
                        result.status = "SpriteLoadFailed";
                        result.error = "texture-or-sprite-load-null";
                        result.loadedTexture = textureAsset != null;
                        result.loadedSprite = sprite != null;
                        result.criticalIssueCount++;
                        continue;
                    }

                    result.status = "SpriteReady";
                    result.loadedTexture = true;
                    result.loadedSprite = true;
                    result.actualWidth = textureAsset.width;
                    result.actualHeight = textureAsset.height;
                    result.spriteName = sprite.name;
                    result.sprite = sprite;
                    if (!byRole.ContainsKey(texture.role))
                    {
                        byRole.Add(texture.role, result);
                    }
                }
                catch (Exception ex)
                {
                    result.status = "ImportException";
                    result.error = ex.GetType().Name + ": " + ex.Message;
                    result.criticalIssueCount++;
                }
            }

            return byRole;
        }

        private static void BuildPrefabs(string projectRoot, string outputDirectory, UiRewardPrototypeSpec spec, Dictionary<string, UiRewardTextureBuildResult> texturesByRole, UiRewardPrototypeBuildReport report, bool overwrite)
        {
            foreach (UiRewardGeneratedAssetSpec generated in spec.generatedAssets ?? Array.Empty<UiRewardGeneratedAssetSpec>())
            {
                var result = new UiRewardPrefabBuildResult
                {
                    kind = generated.kind,
                    assetPath = generated.assetPath,
                    sourceTextureRole = generated.sourceTextureRole
                };
                report.prefabs.Add(result);

                try
                {
                    AssertGeneratedAssetPath(generated.assetPath, "generated prefab");
                    EnsureAssetDirectory(projectRoot, generated.assetPath);
                    if (!overwrite && File.Exists(GetProjectFullPath(projectRoot, generated.assetPath)))
                    {
                        result.status = "OutputExists";
                        result.error = "generated-prefab-already-exists";
                        result.criticalIssueCount++;
                        continue;
                    }
                    if (overwrite)
                    {
                        DeleteGeneratedAssetIfExists(generated.assetPath);
                    }

                    GameObject root = CreatePrototypeObject(generated, texturesByRole, result);
                    if (root == null)
                    {
                        result.status = "MissingRequiredTexture";
                        result.error = "one-or-more-required-textures-missing";
                        result.criticalIssueCount++;
                        continue;
                    }

                    try
                    {
                        GameObject prefab = PrefabUtility.SaveAsPrefabAsset(root, generated.assetPath);
                        result.createdPrefab = prefab != null;
                        if (prefab == null)
                        {
                            result.status = "PrefabSaveFailed";
                            result.error = "prefabutility-save-null";
                            result.criticalIssueCount++;
                            continue;
                        }

                        InspectPrefab(prefab, result);
                        ValidatePrefabVisual(outputDirectory, generated, result);
                        result.status = result.criticalIssueCount == 0 ? "PrototypePrefabBuilt" : "PrototypePrefabBuiltWithIssues";
                    }
                    finally
                    {
                        UnityEngine.Object.DestroyImmediate(root);
                    }
                }
                catch (Exception ex)
                {
                    result.status = "BuildException";
                    result.error = ex.GetType().Name + ": " + ex.Message;
                    result.criticalIssueCount++;
                }
            }

            AssetDatabase.SaveAssets();
            AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
        }

        private static GameObject CreatePrototypeObject(UiRewardGeneratedAssetSpec generated, Dictionary<string, UiRewardTextureBuildResult> texturesByRole, UiRewardPrefabBuildResult result)
        {
            if (string.Equals(generated.kind, "RewardDropPrefab", StringComparison.OrdinalIgnoreCase))
            {
                Sprite rewardSprite = GetSprite(texturesByRole, "RewardItemTexture");
                if (rewardSprite == null)
                {
                    result.missingRequiredTextureRoleCount++;
                    return null;
                }

                GameObject root = new GameObject("RewardDropPrototype");
                AddSpriteChild(root, "RewardItemTexture", rewardSprite, Vector3.zero, 1.25f, 0);
                return root;
            }

            if (string.Equals(generated.kind, "UpgradeCardWidgetPrefab", StringComparison.OrdinalIgnoreCase))
            {
                Sprite largeArt = GetSprite(texturesByRole, "UpgradeCardLargeArt");
                Sprite icon = GetSprite(texturesByRole, "UpgradeCardIcon");
                if (largeArt == null || icon == null)
                {
                    result.missingRequiredTextureRoleCount++;
                    return null;
                }

                GameObject root = new GameObject("UpgradeCardWidgetPrototype");
                AddSpriteChild(root, "LargeArt", largeArt, Vector3.zero, 3.2f, 0);
                AddSpriteChild(root, "Icon", icon, new Vector3(-1.1f, 1.15f, -0.05f), 0.58f, 1);
                return root;
            }

            if (string.Equals(generated.kind, "UpgradeChoicePanelPrefab", StringComparison.OrdinalIgnoreCase))
            {
                Sprite largeArt = GetSprite(texturesByRole, "UpgradeCardLargeArt");
                Sprite icon = GetSprite(texturesByRole, "UpgradeCardIcon");
                Sprite pack = GetSprite(texturesByRole, "UpgradeCardPackArt");
                if (largeArt == null || icon == null)
                {
                    result.missingRequiredTextureRoleCount++;
                    return null;
                }

                GameObject root = new GameObject("UpgradeChoicePanelPrototype");
                AddCard(root, "CardA", largeArt, icon, new Vector3(-1.8f, 0f, 0f));
                AddCard(root, "CardB", largeArt, icon, new Vector3(0f, 0f, 0f));
                AddCard(root, "CardC", largeArt, icon, new Vector3(1.8f, 0f, 0f));
                if (pack != null)
                {
                    AddSpriteChild(root, "PackArt", pack, new Vector3(0f, -2.35f, -0.1f), 0.75f, 4);
                }
                return root;
            }

            result.error = "unsupported-generated-kind";
            return null;
        }

        private static void AddCard(GameObject root, string name, Sprite largeArt, Sprite icon, Vector3 position)
        {
            GameObject card = new GameObject(name);
            card.transform.SetParent(root.transform, false);
            card.transform.localPosition = position;
            AddSpriteChild(card, "LargeArt", largeArt, Vector3.zero, 2.65f, 0);
            AddSpriteChild(card, "Icon", icon, new Vector3(-0.52f, 0.95f, -0.05f), 0.35f, 1);
        }

        private static SpriteRenderer AddSpriteChild(GameObject root, string name, Sprite sprite, Vector3 position, float targetHeight, int sortingOrder)
        {
            GameObject child = new GameObject(name);
            child.transform.SetParent(root.transform, false);
            child.transform.localPosition = position;

            SpriteRenderer renderer = child.AddComponent<SpriteRenderer>();
            renderer.sprite = sprite;
            renderer.sortingOrder = sortingOrder;

            float sourceHeight = sprite.bounds.size.y;
            float scale = sourceHeight > 0.0001f ? targetHeight / sourceHeight : 1f;
            child.transform.localScale = new Vector3(scale, scale, scale);
            return renderer;
        }

        private static void InspectPrefab(GameObject prefab, UiRewardPrefabBuildResult result)
        {
            SpriteRenderer[] renderers = prefab.GetComponentsInChildren<SpriteRenderer>(true);
            result.spriteRendererCount = renderers.Length;
            foreach (SpriteRenderer renderer in renderers)
            {
                if (renderer.sprite == null)
                {
                    result.missingSpriteCount++;
                }
                else
                {
                    result.boundSpriteCount++;
                }
            }

            result.criticalIssueCount += result.missingSpriteCount;
            if (renderers.Length == 0)
            {
                result.noRenderableComponent = true;
                result.criticalIssueCount++;
            }
        }

        private static void ValidatePrefabVisual(string outputDirectory, UiRewardGeneratedAssetSpec generated, UiRewardPrefabBuildResult result)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(generated.assetPath);
            if (prefab == null)
            {
                result.error = "generated-prefab-not-loadable-for-visual-validation";
                result.criticalIssueCount++;
                return;
            }

            GameObject instance = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
            if (instance == null)
            {
                result.error = "generated-prefab-instantiate-null";
                result.criticalIssueCount++;
                return;
            }

            try
            {
                instance.transform.position = Vector3.zero;
                string screenshotDirectory = Path.Combine(outputDirectory, "screenshots");
                Directory.CreateDirectory(screenshotDirectory);
                string screenshotPath = Path.Combine(screenshotDirectory, SanitizeFileName(generated.kind) + ".png");
                result.screenshotPath = screenshotPath;
                result.renderedScreenshot = TryRenderSpriteObject(instance, screenshotPath, out result.nonBackgroundPixelRatio, out result.magentaPixelRatio, out result.renderError);
                if (result.renderedScreenshot)
                {
                    result.visibleScreenshot = result.nonBackgroundPixelRatio >= VisiblePixelThreshold;
                    if (!result.visibleScreenshot)
                    {
                        result.criticalIssueCount++;
                    }
                }
                else
                {
                    result.criticalIssueCount++;
                }
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(instance);
            }
        }

        private static bool TryRenderSpriteObject(GameObject root, string path, out float nonBackgroundRatio, out float magentaRatio, out string error)
        {
            nonBackgroundRatio = 0f;
            magentaRatio = 0f;
            error = "";
            Bounds bounds;
            if (!TryGetRendererBounds(root, out bounds))
            {
                error = "no-renderer-bounds";
                return false;
            }

            Camera camera = CreateCamera(bounds);
            try
            {
                return RenderCamera(camera, path, out nonBackgroundRatio, out magentaRatio, out error);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(camera.gameObject);
            }
        }

        private static bool TryGetRendererBounds(GameObject root, out Bounds bounds)
        {
            bounds = new Bounds(root.transform.position, Vector3.zero);
            bool found = false;
            foreach (SpriteRenderer renderer in root.GetComponentsInChildren<SpriteRenderer>(true))
            {
                if (renderer.sprite == null)
                {
                    continue;
                }

                if (!found)
                {
                    bounds = renderer.bounds;
                    found = true;
                }
                else
                {
                    bounds.Encapsulate(renderer.bounds);
                }
            }

            return found;
        }

        private static Camera CreateCamera(Bounds bounds)
        {
            GameObject cameraObject = new GameObject("StellaGaiaUiRewardPrototypeValidationCamera");
            Camera camera = cameraObject.AddComponent<Camera>();
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = BackgroundColor;
            camera.orthographic = true;
            camera.orthographicSize = Mathf.Max(bounds.extents.y * 1.2f, bounds.extents.x * 1.2f, 0.75f);
            camera.transform.position = bounds.center + new Vector3(0f, 0f, -10f);
            camera.transform.rotation = Quaternion.identity;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = 100f;
            return camera;
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

        private static Sprite GetSprite(Dictionary<string, UiRewardTextureBuildResult> texturesByRole, string role)
        {
            if (!texturesByRole.TryGetValue(role, out UiRewardTextureBuildResult result))
            {
                return null;
            }

            return result.sprite;
        }

        private static UiRewardPrototypeSpec ReadSpec(string path)
        {
            string json = File.ReadAllText(path).TrimStart('\uFEFF').Trim();
            UiRewardPrototypeSpec spec = JsonUtility.FromJson<UiRewardPrototypeSpec>(json);
            if (spec == null || spec.textureAssets == null || spec.textureAssets.Length == 0)
            {
                throw new InvalidOperationException($"No UI reward texture specs in {path}");
            }

            return spec;
        }

        private static void Summarize(UiRewardPrototypeBuildReport report)
        {
            report.textureCount = report.textures.Count;
            foreach (UiRewardTextureBuildResult texture in report.textures)
            {
                if (texture.loadedSprite)
                {
                    report.loadedSpriteCount++;
                }
                report.criticalIssueCount += texture.criticalIssueCount;
            }

            report.prefabCount = report.prefabs.Count;
            foreach (UiRewardPrefabBuildResult prefab in report.prefabs)
            {
                if (prefab.createdPrefab)
                {
                    report.createdPrefabCount++;
                }
                if (prefab.renderedScreenshot)
                {
                    report.renderedScreenshotCount++;
                }
                if (prefab.visibleScreenshot)
                {
                    report.visibleScreenshotCount++;
                }
                if (prefab.criticalIssueCount == 0 && prefab.createdPrefab && prefab.visibleScreenshot)
                {
                    report.successfulPrefabCount++;
                }
                report.criticalIssueCount += prefab.criticalIssueCount;
            }
        }

        private static IEnumerable<string> BuildTextReport(UiRewardPrototypeBuildReport report)
        {
            yield return "StellaGaia UI reward prototype build";
            yield return "GeneratedAt=" + report.generatedAt;
            yield return "SpecPath=" + report.specPath;
            yield return "OutputDirectory=" + report.outputDirectory;
            yield return "Overwrite=" + report.overwrite;
            yield return "TextureCount=" + report.textureCount.ToString(CultureInfo.InvariantCulture);
            yield return "LoadedSpriteCount=" + report.loadedSpriteCount.ToString(CultureInfo.InvariantCulture);
            yield return "PrefabCount=" + report.prefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "CreatedPrefabCount=" + report.createdPrefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "RenderedScreenshotCount=" + report.renderedScreenshotCount.ToString(CultureInfo.InvariantCulture);
            yield return "VisibleScreenshotCount=" + report.visibleScreenshotCount.ToString(CultureInfo.InvariantCulture);
            yield return "SuccessfulPrefabCount=" + report.successfulPrefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "CriticalIssueCount=" + report.criticalIssueCount.ToString(CultureInfo.InvariantCulture);

            foreach (UiRewardPrefabBuildResult prefab in report.prefabs)
            {
                yield return string.Format(
                    CultureInfo.InvariantCulture,
                    "PREFAB kind={0} status={1} created={2} renderers={3} sprites={4} visible={5} criticalIssues={6} path={7}",
                    prefab.kind,
                    prefab.status,
                    prefab.createdPrefab,
                    prefab.spriteRendererCount,
                    prefab.boundSpriteCount,
                    prefab.visibleScreenshot,
                    prefab.criticalIssueCount,
                    prefab.assetPath);
            }
        }

        private static string GetArg(string[] args, string name, string defaultValue)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] == name)
                {
                    return args[i + 1];
                }
            }

            return defaultValue;
        }

        private static string ResolveProjectRelativePath(string projectRoot, string path)
        {
            if (Path.IsPathRooted(path))
            {
                return Path.GetFullPath(path);
            }

            return Path.GetFullPath(Path.Combine(projectRoot, path));
        }

        private static void AssertControlledAssetPath(string assetPath, string description)
        {
            if (string.IsNullOrWhiteSpace(assetPath) || !assetPath.StartsWith(ControlledAssetRoot, StringComparison.Ordinal))
            {
                throw new InvalidOperationException($"{description} must stay under {ControlledAssetRoot}: {assetPath}");
            }

            AssertNoUnsafeSegments(assetPath, description);
        }

        private static void AssertGeneratedAssetPath(string assetPath, string description)
        {
            if (string.IsNullOrWhiteSpace(assetPath) || !assetPath.StartsWith(GeneratedAssetRoot, StringComparison.Ordinal))
            {
                throw new InvalidOperationException($"{description} must stay under {GeneratedAssetRoot}: {assetPath}");
            }

            AssertNoUnsafeSegments(assetPath, description);
        }

        private static void AssertNoUnsafeSegments(string assetPath, string description)
        {
            foreach (string segment in assetPath.Split('/'))
            {
                if (string.IsNullOrWhiteSpace(segment) || segment == "." || segment == "..")
                {
                    throw new InvalidOperationException($"{description} contains an unsafe path segment: {assetPath}");
                }
            }
        }

        private static void AssertOutputDirectorySafe(string projectRoot, string outputDirectory)
        {
            string outputFullPath = Path.GetFullPath(outputDirectory);
            string validationRoot = Path.GetFullPath(Path.Combine(projectRoot, "Extracted", "Validation"));
            if (!IsPathUnderOrEqual(outputFullPath, validationRoot))
            {
                throw new InvalidOperationException($"Output directory must stay under Extracted/Validation: {outputDirectory}");
            }
        }

        private static string GetProjectFullPath(string projectRoot, string assetPath)
        {
            return Path.GetFullPath(Path.Combine(projectRoot, assetPath.Replace('/', Path.DirectorySeparatorChar)));
        }

        private static void EnsureAssetDirectory(string projectRoot, string assetPath)
        {
            string directory = Path.GetDirectoryName(GetProjectFullPath(projectRoot, assetPath));
            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new InvalidOperationException($"Cannot resolve asset directory: {assetPath}");
            }

            Directory.CreateDirectory(directory);
        }

        private static void DeleteGeneratedAssetIfExists(string assetPath)
        {
            if (AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(assetPath) != null && !AssetDatabase.DeleteAsset(assetPath))
            {
                throw new InvalidOperationException($"Failed to delete existing generated asset: {assetPath}");
            }
        }

        private static bool IsPathUnderOrEqual(string candidatePath, string rootPath)
        {
            string candidate = Path.GetFullPath(candidatePath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string root = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return candidate.Equals(root, StringComparison.OrdinalIgnoreCase) || candidate.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
        }

        private static string SanitizeFileName(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return "default";
            }

            foreach (char invalid in Path.GetInvalidFileNameChars())
            {
                value = value.Replace(invalid, '_');
            }

            return value.Replace(' ', '_');
        }

        [Serializable]
        private sealed class UiRewardPrototypeSpec
        {
            public string mode;
            public string note;
            public UiRewardTextureSpec[] textureAssets;
            public UiRewardGeneratedAssetSpec[] generatedAssets;
            public UiRewardRejectedOriginalPrefabRoute rejectedOriginalPrefabRoute;
        }

        [Serializable]
        private sealed class UiRewardTextureSpec
        {
            public string id;
            public string role;
            public string targetAssetPath;
            public int width;
            public int height;
            public string review;
        }

        [Serializable]
        private sealed class UiRewardGeneratedAssetSpec
        {
            public string kind;
            public string assetPath;
            public string sourceTextureRole;
        }

        [Serializable]
        private sealed class UiRewardRejectedOriginalPrefabRoute
        {
            public string gateStatus;
            public int highRiskPrefabCount;
            public int visualMissingPrefabCount;
            public string summaryJson;
        }

        [Serializable]
        private sealed class UiRewardPrototypeBuildReport
        {
            public string generatedAt;
            public string specPath;
            public string outputDirectory;
            public bool overwrite;
            public int textureCount;
            public int loadedSpriteCount;
            public int prefabCount;
            public int createdPrefabCount;
            public int renderedScreenshotCount;
            public int visibleScreenshotCount;
            public int successfulPrefabCount;
            public int criticalIssueCount;
            public List<UiRewardTextureBuildResult> textures;
            public List<UiRewardPrefabBuildResult> prefabs;
        }

        [Serializable]
        private sealed class UiRewardTextureBuildResult
        {
            public string id;
            public string role;
            public string targetAssetPath;
            public string review;
            public int expectedWidth;
            public int expectedHeight;
            public int actualWidth;
            public int actualHeight;
            public string status;
            public string error;
            public bool loadedTexture;
            public bool loadedSprite;
            public string spriteName;
            public int criticalIssueCount;

            [NonSerialized]
            public Sprite sprite;
        }

        [Serializable]
        private sealed class UiRewardPrefabBuildResult
        {
            public string kind;
            public string assetPath;
            public string sourceTextureRole;
            public string status;
            public string error;
            public bool createdPrefab;
            public int spriteRendererCount;
            public int boundSpriteCount;
            public int missingSpriteCount;
            public int missingRequiredTextureRoleCount;
            public bool noRenderableComponent;
            public bool renderedScreenshot;
            public bool visibleScreenshot;
            public float nonBackgroundPixelRatio;
            public float magentaPixelRatio;
            public string screenshotPath;
            public string renderError;
            public int criticalIssueCount;
        }
    }
}
