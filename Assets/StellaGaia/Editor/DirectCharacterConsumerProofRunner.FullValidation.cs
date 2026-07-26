using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.Editor
{
    public static partial class DirectCharacterConsumerProofRunner
    {
        private const string FullValidationFramesDirectory = "full-validation-frames";
        private const float MotionEpsilon = 0.00001f;
        private static readonly float[] SimulationTimes = { 0.10f, 0.25f, 0.50f, 1.00f, 2.00f };
        private static readonly string[] FullFxLogicalNames =
        {
            "char_14401_fx.unity3d",
            "char_14401_buff.unity3d",
            "char_14401_weapons.unity3d"
        };

        private static void PrepareFullValidationOutput(string outputRoot)
        {
            string framesPath = GetOutputPath(outputRoot, FullValidationFramesDirectory);
            if (Directory.Exists(framesPath) || File.Exists(framesPath))
            {
                throw new IOException("Full-validation frame path already exists.");
            }
            Directory.CreateDirectory(framesPath);
            AssertNoReparsePath(framesPath, true);
        }

        private static FullValidationSelection ValidateAllAnimations(
            List<LoadedBundle> bundles,
            GameObject character,
            string outputRoot,
            TerminalReport report)
        {
            var selection = new FullValidationSelection
            {
                baseline = new PoseSnapshot(character)
            };
            var ordered = new List<AnimationCandidate>();
            foreach (LoadedBundle source in bundles)
            {
                AnimationClip[] clips = source.bundle.LoadAllAssets<AnimationClip>();
                Array.Sort(clips, CompareAnimationClips);
                foreach (AnimationClip clip in clips)
                {
                    ordered.Add(new AnimationCandidate
                    {
                        source = source,
                        clip = clip
                    });
                }
            }
            ordered.Sort(CompareAnimationCandidates);

            int resultIndex = 0;
            foreach (AnimationCandidate candidate in ordered)
            {
                AnimationClip clip = candidate.clip;
                report.discoveredAnimationCount++;
                EditorCurveBinding[] bindings = AnimationUtility.GetCurveBindings(clip);
                var transformBindings = new List<EditorCurveBinding>();
                foreach (EditorCurveBinding binding in bindings)
                {
                    if (binding.type == typeof(Transform))
                    {
                        transformBindings.Add(binding);
                    }
                }
                if (clip.length <= 0f || transformBindings.Count == 0)
                {
                    report.ineligibleAnimationCount++;
                    continue;
                }

                report.eligibleAnimationCount++;
                bool isAttack = ContainsAttackToken(clip.name);
                if (isAttack)
                {
                    report.eligibleAttackAnimationCount++;
                }
                var result = new AnimationValidationResult
                {
                    bundle = candidate.source.descriptor.relativePath,
                    clip = clip.name,
                    length = clip.length,
                    transformBindingCount = transformBindings.Count,
                    isAttack = isAttack,
                    status = "Running"
                };
                report.animationResults.Add(result);
                SetContext(report, result.bundle, result.clip, GetHierarchyPath(character.transform));

                try
                {
                    ValidateAnimationClip(
                        character,
                        clip,
                        transformBindings,
                        selection.baseline,
                        outputRoot,
                        resultIndex,
                        result);
                    result.status = "Passed";
                    report.passedAnimationCount++;
                    if (isAttack && selection.attackClip == null)
                    {
                        selection.attackClip = clip;
                        selection.attackAnimationBundle = result.bundle;
                    }
                }
                catch (Exception exception)
                {
                    result.status = "Failed";
                    result.exceptionType = exception.GetType().FullName;
                    result.exceptionMessage = SanitizePortableText(exception.Message, null, outputRoot);
                    result.exceptionStack = SanitizePortableText(exception.StackTrace, null, outputRoot);
                    report.failedAnimationCount++;
                }
                finally
                {
                    selection.baseline.RestoreBaselinePose();
                }
                resultIndex++;
            }

            if (report.eligibleAnimationCount != report.passedAnimationCount + report.failedAnimationCount)
            {
                throw new InvalidDataException("Animation eligibility conservation failed.");
            }
            if (report.eligibleAnimationCount == 0)
            {
                throw new InvalidDataException("No eligible AnimationClip was found.");
            }
            if (report.failedAnimationCount != 0)
            {
                throw new InvalidDataException("At least one eligible AnimationClip failed validation.");
            }
            if (report.eligibleAttackAnimationCount == 0 || selection.attackClip == null)
            {
                throw new InvalidDataException("Attack AnimationClip subset is empty.");
            }

            AnimationValidationResult representative = report.animationResults[0];
            report.animationBundle = representative.bundle;
            report.animationAsset = representative.clip;
            report.bindingPath = representative.firstResolvedBindingPath;
            report.resolvedBindingCount = representative.resolvedBindingCount;
            report.numericChangeMagnitude = representative.maximumBoneChange;
            report.animationClipEvaluatedCount = report.eligibleAnimationCount;
            report.animationConsumerProofPassed = true;
            return selection;
        }

        private static void ValidateAnimationClip(
            GameObject character,
            AnimationClip clip,
            List<EditorCurveBinding> transformBindings,
            PoseSnapshot baseline,
            string outputRoot,
            int resultIndex,
            AnimationValidationResult result)
        {
            var uniquePaths = new List<string>();
            var seenPaths = new HashSet<string>(StringComparer.Ordinal);
            bool hasNonConstantCurve = false;
            foreach (EditorCurveBinding binding in transformBindings)
            {
                if (seenPaths.Add(binding.path))
                {
                    uniquePaths.Add(binding.path);
                }
                AnimationCurve curve = AnimationUtility.GetEditorCurve(clip, binding);
                if (curve != null && !IsConstantCurve(curve))
                {
                    hasNonConstantCurve = true;
                }
            }
            uniquePaths.Sort(StringComparer.Ordinal);

            foreach (string path in uniquePaths)
            {
                Transform resolved = string.IsNullOrEmpty(path)
                    ? character.transform
                    : character.transform.Find(path);
                if (resolved == null || !resolved.IsChildOf(character.transform))
                {
                    throw new InvalidDataException(
                        $"AllTransformBindingsResolved failed for '{path}'.");
                }
                result.resolvedBindingCount++;
                if (result.firstResolvedBindingPath == null)
                {
                    result.firstResolvedBindingPath = path;
                }
            }
            if (result.resolvedBindingCount != uniquePaths.Count)
            {
                throw new InvalidDataException("AllTransformBindingsResolved conservation failed.");
            }

            float lastFrameTime = Mathf.Max(
                0f,
                clip.length - (1f / Mathf.Max(1f, clip.frameRate)));
            float[] sampleTimes =
            {
                0f,
                clip.length * 0.25f,
                clip.length * 0.50f,
                clip.length * 0.75f,
                lastFrameTime
            };

            byte[] bestPng = null;
            VisibilityMetrics bestVisibility = null;
            float bestTime = 0f;
            for (int sampleIndex = 0; sampleIndex < sampleTimes.Length; sampleIndex++)
            {
                baseline.RestoreBaselinePose();
                float sampleTime = Mathf.Clamp(sampleTimes[sampleIndex], 0f, clip.length);
                clip.SampleAnimation(character, sampleTime);
                ValidateFinitePoseAndBounds(character);
                float change = baseline.MaximumDifference();
                result.maximumBoneChange = Mathf.Max(result.maximumBoneChange, change);
                result.sampleCount++;

                FrameCapture capture = CaptureSingleObjectFrame(character, CharacterProofLayer);
                if (bestVisibility == null ||
                    capture.visibility.foregroundPixelCount > bestVisibility.foregroundPixelCount)
                {
                    bestPng = capture.png;
                    bestVisibility = capture.visibility;
                    bestTime = sampleTime;
                }
            }

            if (hasNonConstantCurve)
            {
                if (result.maximumBoneChange <= MotionEpsilon)
                {
                    throw new InvalidDataException(
                        "Nonconstant Transform curves produced no measurable bone change.");
                }
                result.classification = "NonConstantMotion";
            }
            else
            {
                result.classification = "ConstantPose";
            }

            RequireVisibility($"animation '{clip.name}'", bestVisibility);
            string relativePath =
                $"{FullValidationFramesDirectory}/animation-{resultIndex:D4}.png";
            WriteBytesCreateNew(outputRoot, relativePath, bestPng);
            result.visibleFrameTime = bestTime;
            result.frameRelativePath = relativePath;
            result.frameByteCount = bestPng.LongLength;
            result.frameSha256 = ComputeSha256(bestPng);
            result.foregroundPixelCount = bestVisibility.foregroundPixelCount;
            result.brightnessRange = bestVisibility.brightnessRange;
            result.distinctColorCount = bestVisibility.distinctColorCount;
        }

        private static bool IsConstantCurve(AnimationCurve curve)
        {
            if (curve.length <= 1)
            {
                return true;
            }
            float first = curve.keys[0].value;
            Keyframe[] keys = curve.keys;
            for (int index = 0; index < keys.Length; index++)
            {
                Keyframe key = keys[index];
                if (!IsFinite(key.value) || Mathf.Abs(key.value - first) > MotionEpsilon)
                {
                    return false;
                }
                if ((IsFinite(key.inTangent) && Mathf.Abs(key.inTangent) > MotionEpsilon) ||
                    (IsFinite(key.outTangent) && Mathf.Abs(key.outTangent) > MotionEpsilon))
                {
                    return false;
                }
                if (index + 1 < keys.Length)
                {
                    float midpoint = (key.time + keys[index + 1].time) * 0.5f;
                    float midpointValue = curve.Evaluate(midpoint);
                    if (!IsFinite(midpointValue) ||
                        Mathf.Abs(midpointValue - first) > MotionEpsilon)
                    {
                        return false;
                    }
                }
            }
            return true;
        }

        private static void ValidateFinitePoseAndBounds(GameObject character)
        {
            foreach (Transform transform in character.GetComponentsInChildren<Transform>(true))
            {
                if (!IsFinite(transform))
                {
                    throw new InvalidDataException(
                        $"Non-finite bone transform: {GetHierarchyPath(transform)}.");
                }
            }
            foreach (Renderer renderer in character.GetComponentsInChildren<Renderer>(true))
            {
                if (!IsFinite(renderer.bounds))
                {
                    throw new InvalidDataException(
                        $"Non-finite Renderer bounds: {GetHierarchyPath(renderer.transform)}.");
                }
            }
        }

        private static void ValidateAllVisualEffects(
            List<LoadedBundle> bundles,
            string outputRoot,
            TerminalReport report,
            FullValidationSelection selection)
        {
            var ordered = new List<FxCandidate>();
            foreach (LoadedBundle source in bundles)
            {
                if (!IsFullFxBundle(source.descriptor.logicalName))
                {
                    continue;
                }
                GameObject[] prefabs = source.bundle.LoadAllAssets<GameObject>();
                Array.Sort(prefabs, CompareGameObjects);
                foreach (GameObject prefab in prefabs)
                {
                    ordered.Add(new FxCandidate
                    {
                        source = source,
                        prefab = prefab
                    });
                }
            }
            ordered.Sort(CompareFxCandidates);

            int resultIndex = 0;
            foreach (FxCandidate candidate in ordered)
            {
                GameObject prefab = candidate.prefab;
                report.discoveredFxCount++;
                if (!HasVisualComponents(prefab))
                {
                    report.ineligibleFxCount++;
                    continue;
                }

                report.eligibleFxCount++;
                bool isAttack = ContainsAttackToken(
                    candidate.source.descriptor.logicalName + "/" + prefab.name);
                if (isAttack)
                {
                    report.eligibleAttackFxCount++;
                }
                var result = new FxValidationResult
                {
                    bundle = candidate.source.descriptor.relativePath,
                    prefab = prefab.name,
                    isAttack = isAttack,
                    status = "Running",
                    samples = new List<FxSampleResult>()
                };
                report.fxResults.Add(result);
                SetContext(report, result.bundle, result.prefab, result.prefab);
                GameObject instance = null;
                try
                {
                    instance = UnityEngine.Object.Instantiate(prefab);
                    instance.name = prefab.name;
                    instance.SetActive(true);
                    ValidateFxMaterials(instance, result);
                    SimulateAndCaptureFx(instance, outputRoot, resultIndex, result);
                    result.status = "Passed";
                    report.passedFxCount++;
                    if (isAttack)
                    {
                        report.passedAttackFxCount++;
                        if (selection.attackFxPrefab == null)
                        {
                            selection.attackFxPrefab = prefab;
                            selection.attackFxBundle = result.bundle;
                        }
                    }
                }
                catch (Exception exception)
                {
                    result.status = "Failed";
                    result.exceptionType = exception.GetType().FullName;
                    result.exceptionMessage = SanitizePortableText(exception.Message, null, outputRoot);
                    result.exceptionStack = SanitizePortableText(exception.StackTrace, null, outputRoot);
                    report.failedFxCount++;
                    if (isAttack)
                    {
                        report.failedAttackFxCount++;
                    }
                }
                finally
                {
                    if (instance != null)
                    {
                        UnityEngine.Object.DestroyImmediate(instance);
                    }
                }
                resultIndex++;
            }

            if (report.eligibleFxCount != report.passedFxCount + report.failedFxCount)
            {
                throw new InvalidDataException("FX eligibility conservation failed.");
            }
            if (report.eligibleAttackFxCount !=
                report.passedAttackFxCount + report.failedAttackFxCount)
            {
                throw new InvalidDataException("Attack FX subset conservation failed.");
            }
            if (report.eligibleFxCount == 0)
            {
                throw new InvalidDataException("No eligible visual FX prefab was found.");
            }
            if (report.failedFxCount != 0)
            {
                throw new InvalidDataException("At least one eligible visual FX prefab failed.");
            }
            if (report.eligibleAttackFxCount == 0 || selection.attackFxPrefab == null)
            {
                throw new InvalidDataException("Attack FX subset is empty.");
            }
            if (report.failedAttackFxCount != 0 ||
                report.passedAttackFxCount != report.eligibleAttackFxCount)
            {
                throw new InvalidDataException("Attack FX subset did not pass in full.");
            }

            FxValidationResult representative = report.fxResults[0];
            report.battleFxBundle = representative.bundle;
            report.battleFxAsset = representative.prefab;
            report.battleFxObject = representative.prefab;
            report.particleSystemCount = representative.particleSystemCount;
            report.liveParticleCount = representative.maximumParticleCount;
            report.fxRendererCount = representative.rendererCount;
            report.activeFxRendererCount = representative.activeRendererCount;
            report.validFxMaterialCount = representative.materialCount;
            report.supportedFxShaderCount = representative.supportedShaderCount;
            report.finiteNonZeroFxBoundsCount = representative.finiteNonZeroBoundsCount;
            report.qualifyingFxRendererCount = representative.qualifyingRendererCount;
            report.battleFxConsumerProofPassed = true;
        }

        private static void ValidateFxMaterials(GameObject instance, FxValidationResult result)
        {
            Renderer[] renderers = instance.GetComponentsInChildren<Renderer>(true);
            ParticleSystem[] particleSystems =
                instance.GetComponentsInChildren<ParticleSystem>(true);
            result.rendererCount = renderers.Length;
            result.particleSystemCount = particleSystems.Length;
            foreach (Renderer renderer in renderers)
            {
                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    throw new InvalidDataException(
                        $"Renderer has no material: {GetHierarchyPath(renderer.transform)}.");
                }
                foreach (Material material in materials)
                {
                    if (material == null)
                    {
                        throw new InvalidDataException("FX Renderer has an empty material slot.");
                    }
                    result.materialCount++;
                    Shader shader = material.shader;
                    if (shader == null ||
                        !shader.isSupported ||
                        string.Equals(
                            shader.name,
                            "Hidden/InternalErrorShader",
                            StringComparison.Ordinal))
                    {
                        throw new InvalidDataException(
                            $"FX material uses an unsupported shader: {material.name}.");
                    }
                    result.supportedShaderCount++;
                }
            }
        }

        private static void SimulateAndCaptureFx(
            GameObject instance,
            string outputRoot,
            int resultIndex,
            FxValidationResult result)
        {
            ParticleSystem[] particleSystems =
                instance.GetComponentsInChildren<ParticleSystem>(true);
            for (int index = 0; index < particleSystems.Length; index++)
            {
                particleSystems[index].useAutoRandomSeed = false;
                particleSystems[index].randomSeed =
                    unchecked((uint)(144010000 + (resultIndex * 257) + index));
            }

            FrameCapture bestCapture = null;
            float bestTime = 0f;
            foreach (float simulationTime in SimulationTimes)
            {
                foreach (ParticleSystem particleSystem in particleSystems)
                {
                    particleSystem.Simulate(simulationTime, true, true, true);
                }

                int particleCount = 0;
                foreach (ParticleSystem particleSystem in particleSystems)
                {
                    particleCount += particleSystem.particleCount;
                }
                result.maximumParticleCount =
                    Math.Max(result.maximumParticleCount, particleCount);

                int activeRendererCount = 0;
                int finiteNonZeroBoundsCount = 0;
                int qualifyingRendererCount = 0;
                foreach (Renderer renderer in
                         instance.GetComponentsInChildren<Renderer>(true))
                {
                    if (!renderer.enabled || !renderer.gameObject.activeInHierarchy)
                    {
                        continue;
                    }
                    activeRendererCount++;
                    if (!IsFinite(renderer.bounds))
                    {
                        throw new InvalidDataException(
                            $"FX Renderer bounds are non-finite: {GetHierarchyPath(renderer.transform)}.");
                    }
                    bool nonZero = renderer.bounds.size.sqrMagnitude > 0.00000001f;
                    if (nonZero)
                    {
                        finiteNonZeroBoundsCount++;
                        qualifyingRendererCount++;
                    }
                }
                result.activeRendererCount =
                    Math.Max(result.activeRendererCount, activeRendererCount);
                result.finiteNonZeroBoundsCount =
                    Math.Max(result.finiteNonZeroBoundsCount, finiteNonZeroBoundsCount);
                result.qualifyingRendererCount =
                    Math.Max(result.qualifyingRendererCount, qualifyingRendererCount);

                var sample = new FxSampleResult
                {
                    simulationTime = simulationTime,
                    particleCount = particleCount,
                    activeRendererCount = activeRendererCount,
                    finiteNonZeroBoundsCount = finiteNonZeroBoundsCount
                };
                result.samples.Add(sample);
                if (activeRendererCount == 0 || finiteNonZeroBoundsCount == 0)
                {
                    continue;
                }

                FrameCapture capture = CaptureSingleObjectFrame(instance, FxProofLayer);
                sample.foregroundPixelCount = capture.visibility.foregroundPixelCount;
                sample.brightnessRange = capture.visibility.brightnessRange;
                sample.distinctColorCount = capture.visibility.distinctColorCount;
                if (!VisibilityPasses(capture.visibility))
                {
                    continue;
                }
                sample.visible = true;
                result.visibleSampleCount++;
                if (bestCapture == null ||
                    capture.visibility.foregroundPixelCount >
                    bestCapture.visibility.foregroundPixelCount)
                {
                    bestCapture = capture;
                    bestTime = simulationTime;
                }
            }

            if (bestCapture == null)
            {
                throw new InvalidDataException(
                    "FX produced no sample with visible pixels and finite nonzero Renderer bounds.");
            }
            RequireVisibility($"FX '{instance.name}'", bestCapture.visibility);
            string relativePath = $"{FullValidationFramesDirectory}/fx-{resultIndex:D4}.png";
            WriteBytesCreateNew(outputRoot, relativePath, bestCapture.png);
            result.visibleFrameTime = bestTime;
            result.frameRelativePath = relativePath;
            result.frameByteCount = bestCapture.png.LongLength;
            result.frameSha256 = ComputeSha256(bestCapture.png);
            result.foregroundPixelCount = bestCapture.visibility.foregroundPixelCount;
            result.brightnessRange = bestCapture.visibility.brightnessRange;
            result.distinctColorCount = bestCapture.visibility.distinctColorCount;
        }

        private static void CaptureAttackCombination(
            GameObject character,
            string outputRoot,
            List<GameObject> instantiated,
            TerminalReport report,
            FullValidationSelection selection)
        {
            if (selection.attackClip == null || selection.attackFxPrefab == null)
            {
                throw new InvalidDataException("Attack animation/FX selection is incomplete.");
            }
            selection.baseline.RestoreBaselinePose();
            selection.attackClip.SampleAnimation(character, selection.attackClip.length * 0.50f);
            ValidateFinitePoseAndBounds(character);

            GameObject attackFx = UnityEngine.Object.Instantiate(selection.attackFxPrefab);
            attackFx.name = selection.attackFxPrefab.name;
            attackFx.SetActive(true);
            attackFx.transform.position = CalculateBounds(character).center;
            instantiated.Add(attackFx);
            ParticleSystem[] particleSystems =
                attackFx.GetComponentsInChildren<ParticleSystem>(true);
            for (int index = 0; index < particleSystems.Length; index++)
            {
                particleSystems[index].useAutoRandomSeed = false;
                particleSystems[index].randomSeed = unchecked((uint)(144019000 + index));
                particleSystems[index].Simulate(1f, true, true, true);
            }

            SetContext(
                report,
                selection.attackFxBundle,
                selection.attackClip.name + " + " + selection.attackFxPrefab.name,
                GetHierarchyPath(attackFx.transform));
            CaptureDeterministicScreenshot(
                character, attackFx, outputRoot, instantiated, report);
            report.attackCombinationRelativePath = report.screenshotRelativePath;
            report.attackCombinationByteCount = report.screenshotByteCount;
            report.attackCombinationSha256 = report.screenshotSha256;
        }

        private static FrameCapture CaptureSingleObjectFrame(GameObject root, int layer)
        {
            SetLayerRecursively(root, layer);
            Bounds bounds = CalculateBounds(root);
            if (!IsFinite(bounds) || bounds.size.sqrMagnitude <= 0.00000001f)
            {
                throw new InvalidDataException("Visible object bounds are not finite and nonzero.");
            }

            var cameraObject = new GameObject("UDCP-FullValidation-Camera");
            var lightObject = new GameObject("UDCP-FullValidation-Light");
            Camera camera = cameraObject.AddComponent<Camera>();
            Light light = lightObject.AddComponent<Light>();
            float radius = Mathf.Max(1f, bounds.extents.magnitude);
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.08f, 0.08f, 0.10f, 1f);
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.fieldOfView = 30f;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = radius * 20f;
            camera.transform.position =
                bounds.center + new Vector3(radius * 0.45f, radius * 0.25f, -radius * 4f);
            camera.transform.LookAt(bounds.center, Vector3.up);
            light.type = LightType.Directional;
            light.color = Color.white;
            light.intensity = 1f;
            light.shadows = LightShadows.None;
            light.transform.rotation = Quaternion.Euler(35f, -35f, 0f);

            var renderTexture = new RenderTexture(
                ScreenshotWidth,
                ScreenshotHeight,
                24,
                RenderTextureFormat.ARGB32,
                RenderTextureReadWrite.Linear);
            var pixels = new Texture2D(
                ScreenshotWidth,
                ScreenshotHeight,
                TextureFormat.RGB24,
                false,
                true);
            RenderTexture previous = RenderTexture.active;
            try
            {
                renderTexture.antiAliasing = 1;
                renderTexture.Create();
                camera.targetTexture = renderTexture;
                RenderTexture.active = renderTexture;
                Color32[] baseline = RenderPixels(camera, light, pixels, 0);
                Color32[] rendered = RenderPixels(camera, light, pixels, 1 << layer);
                byte[] png = pixels.EncodeToPNG();
                if (png == null || png.Length == 0)
                {
                    throw new InvalidDataException("Validation frame PNG is empty.");
                }
                return new FrameCapture
                {
                    png = png,
                    visibility = AnalyzeVisibility(baseline, rendered)
                };
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = previous;
                if (renderTexture.IsCreated())
                {
                    renderTexture.Release();
                }
                UnityEngine.Object.DestroyImmediate(pixels);
                UnityEngine.Object.DestroyImmediate(renderTexture);
                UnityEngine.Object.DestroyImmediate(cameraObject);
                UnityEngine.Object.DestroyImmediate(lightObject);
            }
        }

        private static bool VisibilityPasses(VisibilityMetrics metrics)
        {
            return metrics.foregroundPixelCount >= MinimumForegroundPixels &&
                   metrics.brightnessRange >= MinimumBrightnessRange &&
                   metrics.distinctColorCount >= MinimumDistinctColorBins;
        }

        private static bool HasVisualComponents(GameObject prefab)
        {
            return prefab != null &&
                   (prefab.GetComponentsInChildren<Renderer>(true).Length > 0 ||
                    prefab.GetComponentsInChildren<ParticleSystem>(true).Length > 0);
        }

        private static bool IsFullFxBundle(string logicalName)
        {
            foreach (string expected in FullFxLogicalNames)
            {
                if (string.Equals(logicalName, expected, StringComparison.Ordinal))
                {
                    return true;
                }
            }
            return false;
        }

        private static int CompareAnimationClips(AnimationClip left, AnimationClip right)
        {
            int name = string.CompareOrdinal(left.name, right.name);
            return name != 0 ? name : left.length.CompareTo(right.length);
        }

        private static int CompareAnimationCandidates(
            AnimationCandidate left,
            AnimationCandidate right)
        {
            int bundle = string.CompareOrdinal(
                left.source.descriptor.relativePath,
                right.source.descriptor.relativePath);
            return bundle != 0 ? bundle : CompareAnimationClips(left.clip, right.clip);
        }

        private static int CompareGameObjects(GameObject left, GameObject right)
        {
            return string.CompareOrdinal(left.name, right.name);
        }

        private static int CompareFxCandidates(FxCandidate left, FxCandidate right)
        {
            int bundle = string.CompareOrdinal(
                left.source.descriptor.relativePath,
                right.source.descriptor.relativePath);
            return bundle != 0 ? bundle : CompareGameObjects(left.prefab, right.prefab);
        }

        private sealed class PoseSnapshot
        {
            private readonly Transform[] transforms;
            private readonly Vector3[] positions;
            private readonly Quaternion[] rotations;
            private readonly Vector3[] scales;

            public PoseSnapshot(GameObject character)
            {
                transforms = character.GetComponentsInChildren<Transform>(true);
                positions = new Vector3[transforms.Length];
                rotations = new Quaternion[transforms.Length];
                scales = new Vector3[transforms.Length];
                for (int index = 0; index < transforms.Length; index++)
                {
                    positions[index] = transforms[index].localPosition;
                    rotations[index] = transforms[index].localRotation;
                    scales[index] = transforms[index].localScale;
                }
            }

            public void RestoreBaselinePose()
            {
                for (int index = 0; index < transforms.Length; index++)
                {
                    transforms[index].localPosition = positions[index];
                    transforms[index].localRotation = rotations[index];
                    transforms[index].localScale = scales[index];
                }
            }

            public float MaximumDifference()
            {
                float maximum = 0f;
                for (int index = 0; index < transforms.Length; index++)
                {
                    maximum = Mathf.Max(
                        maximum,
                        Vector3.Distance(positions[index], transforms[index].localPosition),
                        Quaternion.Angle(rotations[index], transforms[index].localRotation),
                        Vector3.Distance(scales[index], transforms[index].localScale));
                }
                return maximum;
            }
        }

        private sealed class FullValidationSelection
        {
            public PoseSnapshot baseline;
            public AnimationClip attackClip;
            public string attackAnimationBundle;
            public GameObject attackFxPrefab;
            public string attackFxBundle;
        }

        private sealed class AnimationCandidate
        {
            public LoadedBundle source;
            public AnimationClip clip;
        }

        private sealed class FxCandidate
        {
            public LoadedBundle source;
            public GameObject prefab;
        }

        private sealed class FrameCapture
        {
            public byte[] png;
            public VisibilityMetrics visibility;
        }

        [Serializable]
        private sealed class AnimationValidationResult
        {
            public string bundle;
            public string clip;
            public float length;
            public bool isAttack;
            public int transformBindingCount;
            public int resolvedBindingCount;
            public string firstResolvedBindingPath;
            public string classification;
            public int sampleCount;
            public float maximumBoneChange;
            public float visibleFrameTime;
            public string frameRelativePath;
            public long frameByteCount;
            public string frameSha256;
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
            public string status;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
        }

        [Serializable]
        private sealed class FxValidationResult
        {
            public string bundle;
            public string prefab;
            public bool isAttack;
            public int particleSystemCount;
            public int rendererCount;
            public int materialCount;
            public int supportedShaderCount;
            public int maximumParticleCount;
            public int activeRendererCount;
            public int finiteNonZeroBoundsCount;
            public int qualifyingRendererCount;
            public int visibleSampleCount;
            public float visibleFrameTime;
            public string frameRelativePath;
            public long frameByteCount;
            public string frameSha256;
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
            public List<FxSampleResult> samples;
            public string status;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
        }

        [Serializable]
        private sealed class FxSampleResult
        {
            public float simulationTime;
            public int particleCount;
            public int activeRendererCount;
            public int finiteNonZeroBoundsCount;
            public bool visible;
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
        }
    }
}
