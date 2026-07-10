using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using UnityEditor;
using UnityEditor.Animations;
using UnityEngine;

namespace StellaGaia.EditorTools
{
    public static class ActorPrototypeControllerBuilder
    {
        private const string ControlledAssetRoot = "Assets/StellaGaia/Imported/ControlledCandidates/";
        private const int ScreenshotSize = 512;
        private const float VisiblePixelThreshold = 0.002f;
        private const float MagentaPixelWarningThreshold = 0.2f;
        private static readonly Color BackgroundColor = new Color(0.075f, 0.075f, 0.075f, 1f);

        [MenuItem("StellaGaia/Build Actor Prototype Controllers")]
        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string projectRoot = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            string specPath = ResolveProjectRelativePath(projectRoot, GetArg(args, "-stellaGaiaActorPrototypeControllerSpec", Path.Combine("Extracted", "Validation", "ActorPrototypeControllerRebuildPlan", "actor-prototype-controller-spec.json")));
            string outputDirectory = ResolveProjectRelativePath(projectRoot, GetArg(args, "-stellaGaiaActorPrototypeControllerBuildOutput", Path.Combine("Extracted", "Validation", "ActorPrototypeControllerBuild")));
            bool overwrite = string.Equals(GetArg(args, "-stellaGaiaActorPrototypeControllerOverwrite", "false"), "true", StringComparison.OrdinalIgnoreCase);

            AssertOutputDirectorySafe(projectRoot, outputDirectory);

            if (string.IsNullOrWhiteSpace(specPath) || !File.Exists(specPath))
            {
                throw new InvalidOperationException($"Missing actor prototype controller spec: {specPath}");
            }

            Directory.CreateDirectory(outputDirectory);

            var report = new ActorPrototypeControllerBuildReport
            {
                generatedAt = DateTimeOffset.Now.ToString("O"),
                specPath = Path.GetFullPath(specPath),
                outputDirectory = Path.GetFullPath(outputDirectory),
                overwrite = overwrite,
                actors = new List<ActorPrototypeControllerBuildResult>()
            };

            foreach (ActorPrototypeControllerSpec spec in ReadSpecs(specPath))
            {
                report.actors.Add(BuildActor(projectRoot, outputDirectory, spec, overwrite));
            }

            Summarize(report);

            string jsonPath = Path.Combine(outputDirectory, "unity-actor-prototype-controller-build.json");
            string textPath = Path.Combine(outputDirectory, "unity-actor-prototype-controller-build.txt");
            File.WriteAllText(jsonPath, JsonUtility.ToJson(report, true));
            File.WriteAllLines(textPath, BuildTextReport(report));
            Debug.Log($"Wrote actor prototype controller build report to {jsonPath}");

            if (report.criticalIssueCount > 0)
            {
                throw new InvalidOperationException($"Actor prototype controller build found {report.criticalIssueCount} critical issue(s). See {jsonPath}");
            }
        }

        private static ActorPrototypeControllerBuildResult BuildActor(string projectRoot, string outputDirectory, ActorPrototypeControllerSpec spec, bool overwrite)
        {
            var result = new ActorPrototypeControllerBuildResult
            {
                id = spec.id,
                sourceCategory = spec.sourceCategory,
                repairMode = spec.repairMode,
                targetPrefab = spec.targetPrefab,
                generatedController = spec.generatedController,
                generatedPrefab = spec.generatedPrefab,
                avatarTarget = spec.avatarTarget,
                stateResults = new List<ActorPrototypeStateBuildResult>()
            };

            try
            {
                AssertControlledAssetPath(spec.targetPrefab, "target prefab");
                AssertControlledAssetPath(spec.generatedController, "generated controller");
                AssertControlledAssetPath(spec.generatedPrefab, "generated prefab");
                AssertControlledAssetPath(spec.avatarTarget, "avatar");
                AssertSafeGeneratedFullPath(projectRoot, spec.generatedController);
                AssertSafeGeneratedFullPath(projectRoot, spec.generatedPrefab);

                if (!overwrite && (File.Exists(GetProjectFullPath(projectRoot, spec.generatedController)) || File.Exists(GetProjectFullPath(projectRoot, spec.generatedPrefab))))
                {
                    result.status = "OutputExists";
                    result.error = "generated-controller-or-prefab-already-exists";
                    result.criticalIssueCount++;
                    return result;
                }

                EnsureAssetDirectory(projectRoot, spec.generatedController);
                EnsureAssetDirectory(projectRoot, spec.generatedPrefab);
                AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);

                GameObject sourcePrefab = AssetDatabase.LoadAssetAtPath<GameObject>(spec.targetPrefab);
                if (sourcePrefab == null)
                {
                    result.status = "MissingTargetPrefab";
                    result.error = "assetdatabase-load-target-prefab-null";
                    result.criticalIssueCount++;
                    return result;
                }

                result.loadedTargetPrefab = true;

                Avatar avatar = AssetDatabase.LoadAssetAtPath<Avatar>(spec.avatarTarget);
                if (avatar == null)
                {
                    result.status = "MissingAvatar";
                    result.error = "assetdatabase-load-avatar-null";
                    result.criticalIssueCount++;
                    return result;
                }

                result.loadedAvatar = true;

                var loadedStates = new List<LoadedState>();
                var stateNames = new HashSet<string>(StringComparer.Ordinal);
                foreach (ActorPrototypeStateSpec state in spec.states ?? Array.Empty<ActorPrototypeStateSpec>())
                {
                    ActorPrototypeStateBuildResult stateResult = LoadState(state, stateNames);
                    result.stateResults.Add(stateResult);
                    if (stateResult.loadedClip)
                    {
                        loadedStates.Add(new LoadedState { spec = state, clip = stateResult.clip });
                    }
                    else if (state.required)
                    {
                        result.requiredClipFailureCount++;
                    }
                }

                if (result.requiredClipFailureCount > 0)
                {
                    result.status = "MissingRequiredClips";
                    result.error = "one-or-more-required-clips-missing";
                    result.criticalIssueCount += result.requiredClipFailureCount;
                    return result;
                }

                if (loadedStates.Count == 0)
                {
                    result.status = "NoLoadedStates";
                    result.error = "no-animation-clips-loaded";
                    result.criticalIssueCount++;
                    return result;
                }

                if (overwrite)
                {
                    DeleteGeneratedAssetIfExists(spec.generatedPrefab);
                    DeleteGeneratedAssetIfExists(spec.generatedController);
                    AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
                }

                AnimatorController controller = CreateController(spec.generatedController, loadedStates, result);
                result.createdController = controller != null;
                if (controller == null)
                {
                    result.status = "ControllerCreateFailed";
                    result.error = "animator-controller-create-null";
                    result.criticalIssueCount++;
                    return result;
                }

                GameObject generatedPrefab = CreatePrefabVariant(sourcePrefab, avatar, controller, spec.generatedPrefab, result);
                result.createdPrefab = generatedPrefab != null;
                if (generatedPrefab == null)
                {
                    result.status = "PrefabCreateFailed";
                    result.error = "prefab-save-null";
                    result.criticalIssueCount++;
                    return result;
                }

                InspectGeneratedPrefab(spec, result);
                ValidateGeneratedActorVisuals(outputDirectory, spec, loadedStates, result);
                result.status = result.criticalIssueCount == 0 ? "PrototypeControllerBuilt" : "PrototypeControllerBuiltWithIssues";
                AssetDatabase.SaveAssets();
                AssetDatabase.Refresh(ImportAssetOptions.ForceUpdate);
                return result;
            }
            catch (Exception ex)
            {
                result.status = "BuildException";
                result.error = ex.GetType().Name + ": " + ex.Message;
                result.criticalIssueCount++;
                return result;
            }
        }

        private static ActorPrototypeStateBuildResult LoadState(ActorPrototypeStateSpec state, HashSet<string> stateNames)
        {
            var result = new ActorPrototypeStateBuildResult
            {
                group = state.group,
                stateName = state.stateName,
                required = state.required,
                targetClip = state.targetClip
            };

            if (string.IsNullOrWhiteSpace(state.stateName) || !stateNames.Add(state.stateName))
            {
                result.status = "InvalidStateName";
                result.error = "missing-or-duplicate-state-name";
                return result;
            }

            AssertControlledAssetPath(state.targetClip, "target clip");
            AnimationClip clip = AssetDatabase.LoadAssetAtPath<AnimationClip>(state.targetClip);
            if (clip == null)
            {
                result.status = state.required ? "MissingRequiredClip" : "MissingOptionalClip";
                result.error = "assetdatabase-load-animationclip-null";
                return result;
            }

            result.status = "ClipLoaded";
            result.loadedClip = true;
            result.clip = clip;
            result.lengthSeconds = clip.length;
            result.frameRate = clip.frameRate;
            result.wrapMode = clip.wrapMode.ToString();
            return result;
        }

        private static AnimatorController CreateController(string controllerPath, List<LoadedState> loadedStates, ActorPrototypeControllerBuildResult result)
        {
            AnimatorController controller = AnimatorController.CreateAnimatorControllerAtPath(controllerPath);
            if (controller == null)
            {
                return null;
            }

            controller.AddParameter("PrototypeSpeed", AnimatorControllerParameterType.Float);

            AnimatorStateMachine stateMachine = controller.layers[0].stateMachine;
            AnimatorState defaultState = null;
            foreach (LoadedState loadedState in loadedStates)
            {
                AnimatorState state = stateMachine.AddState(loadedState.spec.stateName);
                state.motion = loadedState.clip;
                state.speed = 1f;
                result.createdStateCount++;

                string triggerName = "To" + loadedState.spec.stateName;
                controller.AddParameter(triggerName, AnimatorControllerParameterType.Trigger);
                AnimatorStateTransition transition = stateMachine.AddAnyStateTransition(state);
                transition.hasExitTime = false;
                transition.duration = 0.05f;
                transition.canTransitionToSelf = false;
                transition.AddCondition(AnimatorConditionMode.If, 0f, triggerName);

                if (defaultState == null || string.Equals(loadedState.spec.group, "idle", StringComparison.OrdinalIgnoreCase))
                {
                    defaultState = state;
                }
            }

            if (defaultState != null)
            {
                stateMachine.defaultState = defaultState;
            }

            return controller;
        }

        private static GameObject CreatePrefabVariant(GameObject sourcePrefab, Avatar avatar, AnimatorController controller, string generatedPrefabPath, ActorPrototypeControllerBuildResult result)
        {
            GameObject instance = PrefabUtility.InstantiatePrefab(sourcePrefab) as GameObject;
            if (instance == null)
            {
                return null;
            }

            try
            {
                Animator animator = instance.GetComponentInChildren<Animator>(true);
                if (animator == null)
                {
                    result.missingAnimatorCount++;
                    result.criticalIssueCount++;
                    return null;
                }

                animator.avatar = avatar;
                animator.runtimeAnimatorController = controller;
                animator.applyRootMotion = false;

                return PrefabUtility.SaveAsPrefabAsset(instance, generatedPrefabPath);
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(instance);
            }
        }

        private static void InspectGeneratedPrefab(ActorPrototypeControllerSpec spec, ActorPrototypeControllerBuildResult result)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(spec.generatedPrefab);
            AnimatorController controller = AssetDatabase.LoadAssetAtPath<AnimatorController>(spec.generatedController);
            if (prefab == null || controller == null)
            {
                result.criticalIssueCount++;
                result.error = "generated-prefab-or-controller-not-loadable";
                return;
            }

            Renderer[] renderers = prefab.GetComponentsInChildren<Renderer>(true);
            ParticleSystem[] particleSystems = prefab.GetComponentsInChildren<ParticleSystem>(true);
            Animator[] animators = prefab.GetComponentsInChildren<Animator>(true);

            result.rendererCount = renderers.Length;
            result.particleSystemCount = particleSystems.Length;
            result.animatorCount = animators.Length;

            if (renderers.Length == 0 && particleSystems.Length == 0)
            {
                result.noRenderableComponent = true;
                result.criticalIssueCount++;
            }

            foreach (Renderer renderer in renderers)
            {
                if (renderer is SkinnedMeshRenderer skinnedMeshRenderer && skinnedMeshRenderer.sharedMesh == null)
                {
                    result.missingMeshCount++;
                }
                else if (renderer is MeshRenderer)
                {
                    MeshFilter meshFilter = renderer.GetComponent<MeshFilter>();
                    if (meshFilter == null || meshFilter.sharedMesh == null)
                    {
                        result.missingMeshCount++;
                    }
                }

                foreach (Material material in renderer.sharedMaterials)
                {
                    if (material == null)
                    {
                        result.missingMaterialSlotCount++;
                        continue;
                    }

                    if (material.shader == null || material.shader.name.IndexOf("Hidden/InternalErrorShader", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        result.brokenShaderCount++;
                    }
                }
            }

            bool hasBoundController = false;
            foreach (Animator animator in animators)
            {
                if (animator.runtimeAnimatorController == controller)
                {
                    hasBoundController = true;
                }

                if (animator.avatar == null)
                {
                    result.missingAvatarBindingCount++;
                }
            }

            result.generatedControllerBound = hasBoundController;
            if (animators.Length == 0)
            {
                result.missingAnimatorCount++;
            }

            if (!hasBoundController)
            {
                result.missingControllerBindingCount++;
            }

            result.criticalIssueCount += result.missingMeshCount + result.missingMaterialSlotCount + result.brokenShaderCount + result.missingAnimatorCount + result.missingAvatarBindingCount + result.missingControllerBindingCount;
        }

        private static void ValidateGeneratedActorVisuals(string outputDirectory, ActorPrototypeControllerSpec spec, List<LoadedState> loadedStates, ActorPrototypeControllerBuildResult result)
        {
            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(spec.generatedPrefab);
            if (prefab == null)
            {
                result.criticalIssueCount++;
                result.error = "generated-prefab-not-loadable-for-visual-validation";
                return;
            }

            string screenshotDirectory = Path.Combine(outputDirectory, "screenshots", SanitizeFileName(spec.id));
            Directory.CreateDirectory(screenshotDirectory);
            result.screenshotDirectory = screenshotDirectory;

            foreach (LoadedState loadedState in loadedStates)
            {
                ActorPrototypeStateBuildResult stateResult = FindStateResult(result, loadedState.spec.stateName);
                if (stateResult == null)
                {
                    continue;
                }

                GameObject instance = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
                if (instance == null)
                {
                    stateResult.renderError = "prefab-instantiate-null";
                    if (stateResult.required)
                    {
                        result.criticalIssueCount++;
                    }
                    continue;
                }

                try
                {
                    instance.name = spec.id + "_" + loadedState.spec.stateName + "_Preview";
                    instance.SetActive(true);
                    instance.transform.position = Vector3.zero;
                    instance.transform.rotation = Quaternion.identity;
                    instance.transform.localScale = Vector3.one;

                    float sampleTime = loadedState.clip.length > 0f ? Mathf.Clamp(loadedState.clip.length * 0.5f, 0f, loadedState.clip.length) : 0f;
                    loadedState.clip.SampleAnimation(instance, sampleTime);
                    stateResult.sampledAnimation = true;
                    stateResult.sampleTimeSeconds = sampleTime;
                    result.animationSampleCount++;

                    string screenshotPath = Path.Combine(screenshotDirectory, SanitizeFileName(loadedState.spec.stateName) + ".png");
                    stateResult.screenshotPath = screenshotPath;
                    stateResult.renderedScreenshot = TryRenderGameObject(instance, screenshotPath, out stateResult.nonBackgroundPixelRatio, out stateResult.magentaPixelRatio, out stateResult.renderError);
                    stateResult.visibleScreenshot = stateResult.renderedScreenshot && stateResult.nonBackgroundPixelRatio >= VisiblePixelThreshold;
                    if (stateResult.renderedScreenshot)
                    {
                        result.renderedScreenshotCount++;
                    }

                    if (stateResult.visibleScreenshot)
                    {
                        result.visibleScreenshotCount++;
                    }
                    else if (stateResult.required)
                    {
                        result.criticalIssueCount++;
                    }

                    if (stateResult.magentaPixelRatio > MagentaPixelWarningThreshold)
                    {
                        result.magentaScreenshotCount++;
                        if (stateResult.required)
                        {
                            result.criticalIssueCount++;
                        }
                    }
                }
                catch (Exception ex)
                {
                    stateResult.renderError = ex.GetType().Name + ": " + ex.Message;
                    if (stateResult.required)
                    {
                        result.criticalIssueCount++;
                    }
                }
                finally
                {
                    UnityEngine.Object.DestroyImmediate(instance);
                }
            }

            if (result.visibleScreenshotCount == 0)
            {
                result.noVisibleAnimationSample = true;
                result.criticalIssueCount++;
            }
        }

        private static ActorPrototypeStateBuildResult FindStateResult(ActorPrototypeControllerBuildResult result, string stateName)
        {
            foreach (ActorPrototypeStateBuildResult stateResult in result.stateResults)
            {
                if (string.Equals(stateResult.stateName, stateName, StringComparison.Ordinal))
                {
                    return stateResult;
                }
            }

            return null;
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
                string candidatePath = path + ".view" + i.ToString(CultureInfo.InvariantCulture) + ".png";
                temporaryPaths.Add(candidatePath);
                Camera camera = CreateCamera(bounds, directions[i]);
                try
                {
                    bool candidateRendered = RenderCamera(camera, candidatePath, out float candidateNonBackgroundRatio, out float candidateMagentaRatio, out string candidateError);
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
            GameObject cameraObject = new GameObject("StellaGaiaActorPrototypeValidationCamera");
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
            GameObject lightObject = new GameObject("StellaGaiaActorPrototypeValidationLight");
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

        private static List<ActorPrototypeControllerSpec> ReadSpecs(string path)
        {
            string json = File.ReadAllText(path).TrimStart('\uFEFF').Trim();
            if (json.StartsWith("[", StringComparison.Ordinal))
            {
                json = "{\"items\":" + json + "}";
            }

            ActorPrototypeControllerSpecList wrapper = JsonUtility.FromJson<ActorPrototypeControllerSpecList>(json);
            if (wrapper == null || wrapper.items == null || wrapper.items.Count == 0)
            {
                throw new InvalidOperationException($"No actor prototype controller specs in {path}");
            }

            return wrapper.items;
        }

        private static void Summarize(ActorPrototypeControllerBuildReport report)
        {
            report.actorCount = report.actors.Count;
            foreach (ActorPrototypeControllerBuildResult actor in report.actors)
            {
                if (actor.loadedTargetPrefab)
                {
                    report.loadedTargetPrefabCount++;
                }

                if (actor.loadedAvatar)
                {
                    report.loadedAvatarCount++;
                }

                if (actor.createdController)
                {
                    report.createdControllerCount++;
                }

                if (actor.createdPrefab)
                {
                    report.createdPrefabCount++;
                }

                report.animationSampleCount += actor.animationSampleCount;
                report.renderedScreenshotCount += actor.renderedScreenshotCount;
                report.visibleScreenshotCount += actor.visibleScreenshotCount;
                report.magentaScreenshotCount += actor.magentaScreenshotCount;

                if (actor.criticalIssueCount == 0 && actor.createdController && actor.createdPrefab && actor.visibleScreenshotCount > 0)
                {
                    report.successfulActorCount++;
                }

                report.criticalIssueCount += actor.criticalIssueCount;
            }
        }

        private static IEnumerable<string> BuildTextReport(ActorPrototypeControllerBuildReport report)
        {
            yield return "StellaGaia actor prototype controller build";
            yield return "GeneratedAt=" + report.generatedAt;
            yield return "SpecPath=" + report.specPath;
            yield return "OutputDirectory=" + report.outputDirectory;
            yield return "Overwrite=" + report.overwrite;
            yield return "ActorCount=" + report.actorCount.ToString(CultureInfo.InvariantCulture);
            yield return "LoadedTargetPrefabCount=" + report.loadedTargetPrefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "LoadedAvatarCount=" + report.loadedAvatarCount.ToString(CultureInfo.InvariantCulture);
            yield return "CreatedControllerCount=" + report.createdControllerCount.ToString(CultureInfo.InvariantCulture);
            yield return "CreatedPrefabCount=" + report.createdPrefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "AnimationSampleCount=" + report.animationSampleCount.ToString(CultureInfo.InvariantCulture);
            yield return "RenderedScreenshotCount=" + report.renderedScreenshotCount.ToString(CultureInfo.InvariantCulture);
            yield return "VisibleScreenshotCount=" + report.visibleScreenshotCount.ToString(CultureInfo.InvariantCulture);
            yield return "MagentaScreenshotCount=" + report.magentaScreenshotCount.ToString(CultureInfo.InvariantCulture);
            yield return "SuccessfulActorCount=" + report.successfulActorCount.ToString(CultureInfo.InvariantCulture);
            yield return "CriticalIssueCount=" + report.criticalIssueCount.ToString(CultureInfo.InvariantCulture);

            foreach (ActorPrototypeControllerBuildResult actor in report.actors)
            {
                yield return string.Format(
                    CultureInfo.InvariantCulture,
                    "ACTOR id={0} status={1} prefabLoaded={2} avatarLoaded={3} controllerCreated={4} prefabCreated={5} states={6} renderers={7} particles={8} animators={9} boundController={10} visibleScreenshots={11} criticalIssues={12} generatedPrefab={13}",
                    actor.id,
                    actor.status,
                    actor.loadedTargetPrefab,
                    actor.loadedAvatar,
                    actor.createdController,
                    actor.createdPrefab,
                    actor.createdStateCount,
                    actor.rendererCount,
                    actor.particleSystemCount,
                    actor.animatorCount,
                    actor.generatedControllerBound,
                    actor.visibleScreenshotCount,
                    actor.criticalIssueCount,
                    actor.generatedPrefab);
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

            foreach (string segment in assetPath.Split('/'))
            {
                if (string.IsNullOrWhiteSpace(segment) || segment == "." || segment == "..")
                {
                    throw new InvalidOperationException($"{description} contains an unsafe path segment: {assetPath}");
                }
            }
        }

        private static void AssertSafeGeneratedFullPath(string projectRoot, string assetPath)
        {
            string controlledRoot = Path.GetFullPath(Path.Combine(projectRoot, ControlledAssetRoot.Replace('/', Path.DirectorySeparatorChar)));
            string fullPath = GetProjectFullPath(projectRoot, assetPath);
            if (!IsPathUnderOrEqual(fullPath, controlledRoot))
            {
                throw new InvalidOperationException($"Generated asset path escaped controlled root: {assetPath}");
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
            string fullPath = GetProjectFullPath(projectRoot, assetPath);
            string directory = Path.GetDirectoryName(fullPath);
            if (string.IsNullOrWhiteSpace(directory))
            {
                throw new InvalidOperationException($"Cannot resolve asset directory: {assetPath}");
            }

            Directory.CreateDirectory(directory);
        }

        private static void DeleteGeneratedAssetIfExists(string assetPath)
        {
            if (AssetDatabase.LoadAssetAtPath<UnityEngine.Object>(assetPath) != null)
            {
                if (!AssetDatabase.DeleteAsset(assetPath))
                {
                    throw new InvalidOperationException($"Failed to delete existing generated asset: {assetPath}");
                }
            }
        }

        private static bool IsPathUnderOrEqual(string candidatePath, string rootPath)
        {
            string candidate = Path.GetFullPath(candidatePath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            string root = Path.GetFullPath(rootPath).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            return candidate.Equals(root, StringComparison.OrdinalIgnoreCase) || candidate.StartsWith(root + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase);
        }

        private sealed class LoadedState
        {
            public ActorPrototypeStateSpec spec;
            public AnimationClip clip;
        }

        [Serializable]
        private sealed class ActorPrototypeControllerSpecList
        {
            public List<ActorPrototypeControllerSpec> items;
        }

        [Serializable]
        private sealed class ActorPrototypeControllerSpec
        {
            public string id;
            public string sourceCategory;
            public string repairMode;
            public string sourcePrefab;
            public string targetPrefab;
            public string generatedController;
            public string generatedPrefab;
            public string avatarSource;
            public string avatarTarget;
            public string originalController;
            public bool originalControllerHasPlaceholder;
            public ActorPrototypeStateSpec[] states;
            public string note;
        }

        [Serializable]
        private sealed class ActorPrototypeStateSpec
        {
            public string group;
            public string stateName;
            public bool required;
            public string sourceClip;
            public string targetClip;
            public string clipGuid;
        }

        [Serializable]
        private sealed class ActorPrototypeControllerBuildReport
        {
            public string generatedAt;
            public string specPath;
            public string outputDirectory;
            public bool overwrite;
            public int actorCount;
            public int loadedTargetPrefabCount;
            public int loadedAvatarCount;
            public int createdControllerCount;
            public int createdPrefabCount;
            public int animationSampleCount;
            public int renderedScreenshotCount;
            public int visibleScreenshotCount;
            public int magentaScreenshotCount;
            public int successfulActorCount;
            public int criticalIssueCount;
            public List<ActorPrototypeControllerBuildResult> actors;
        }

        [Serializable]
        private sealed class ActorPrototypeControllerBuildResult
        {
            public string id;
            public string sourceCategory;
            public string repairMode;
            public string targetPrefab;
            public string generatedController;
            public string generatedPrefab;
            public string avatarTarget;
            public string status;
            public string error;
            public bool loadedTargetPrefab;
            public bool loadedAvatar;
            public bool createdController;
            public bool createdPrefab;
            public int createdStateCount;
            public int animationSampleCount;
            public int renderedScreenshotCount;
            public int visibleScreenshotCount;
            public int magentaScreenshotCount;
            public int requiredClipFailureCount;
            public int rendererCount;
            public int particleSystemCount;
            public int animatorCount;
            public int missingMeshCount;
            public int missingMaterialSlotCount;
            public int brokenShaderCount;
            public int missingAnimatorCount;
            public int missingAvatarBindingCount;
            public int missingControllerBindingCount;
            public bool noRenderableComponent;
            public bool noVisibleAnimationSample;
            public bool generatedControllerBound;
            public string screenshotDirectory;
            public int criticalIssueCount;
            public List<ActorPrototypeStateBuildResult> stateResults;
        }

        [Serializable]
        private sealed class ActorPrototypeStateBuildResult
        {
            public string group;
            public string stateName;
            public bool required;
            public string targetClip;
            public string status;
            public string error;
            public bool loadedClip;
            public float lengthSeconds;
            public float frameRate;
            public string wrapMode;
            public bool sampledAnimation;
            public float sampleTimeSeconds;
            public string screenshotPath;
            public bool renderedScreenshot;
            public bool visibleScreenshot;
            public float nonBackgroundPixelRatio;
            public float magentaPixelRatio;
            public string renderError;

            [NonSerialized]
            public AnimationClip clip;
        }
    }
}
