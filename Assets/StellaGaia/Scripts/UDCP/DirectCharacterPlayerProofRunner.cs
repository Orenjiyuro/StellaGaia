using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace StellaGaia.UDCP
{
    public static class DirectCharacterPlayerProofRunner
    {
        private const string RequiredUnityVersion = "2022.3.62f2";
        private const string InputRootEnvironmentVariable =
            "STELLAGAIA_UDCP_PLAYER_INPUT_ROOT";
        private const string OutputRootEnvironmentVariable =
            "STELLAGAIA_UDCP_PLAYER_OUTPUT_ROOT";
        private const string ExpectedInputRelativePath =
            "Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1-A02/Input";
        private const string TerminalFileName = "terminal-result.json";
        private const string AnimationFrameDirectory = "animation-frames";
        private const string FxFrameDirectory = "fx-frames";
        private const string AttackCombinationFileName = "attack-combination.png";
        private const string FullAnimationLogicalName = "char_14401_animations.unity3d";
        private const int AuthorizedMemberCount = 17;
        private const int EffectiveBundleCount = 12;
        private const int ScreenshotWidth = 512;
        private const int ScreenshotHeight = 512;
        private const int CharacterLayer = 30;
        private const int FxLayer = 31;
        private const int MinimumForegroundPixels = 64;
        private const int MinimumBrightnessRange = 4;
        private const int MinimumDistinctColorBins = 2;
        private const int ForegroundDifferenceSquared = 64;
        private const float MotionEpsilon = 0.00001f;
        private const string NotApplicable = "<not-applicable>";

        private static readonly AuthorizedMember[] AuthorizedMembers =
        {
            new AuthorizedMember("Persistent_Store/AssetBundles/char_14401.unity3d", 259486L, "c42c73aa168af6a430999c0ae240ebb85c9764d75014f5961e1647dad51f413b"),
            new AuthorizedMember("Persistent_Store/AssetBundles/char_14401_animations.unity3d", 37819874L, "8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d"),
            new AuthorizedMember("Persistent_Store/AssetBundles/char_14401_fx.unity3d", 1944422L, "02db4eaf46f9663c8c8949aec8ca49dcdc280a7bca3f3bd49741fde6bc4f57ab"),
            new AuthorizedMember("Persistent_Store/AssetBundles/char_14401_models.unity3d", 3080984L, "66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7"),
            new AuthorizedMember("Persistent_Store/AssetBundles/char_14401_timeline.unity3d", 4341943L, "22cafed7bb84fec59a0b2f4ccf0687ff9434ad38e7a21de9041ca313565d0228"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d", 268634L, "f288167adbc49837d977e81aa4c76fba136e50c2533cd86577248bbe8f0902f7"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d", 54889767L, "50f48caaefa85c371ff53de88f5165d974b5898de4a64ac6d4ca73a989f98a4c"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d", 3576L, "0c24970f1992fbc118a8a0c4002cc9c5612d9507fd1d798fe8d7c2fc89e7591f"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d", 35134L, "e5c4ef03fa7c9b8c31de99f15e2fe296c8014c99657c5f4f62187d81e079ba47"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d", 27828L, "6005f95be7a3e66a87a5549fde3728f60a234ea6cc8763fdbc95c49962be22e0"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d", 3956L, "de1aa4e4f2f2de24f8ab5994c8be5bfd0f2fc903888c3168159fd2531c2a5397"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d", 1998022L, "409358d533ffe6a00d04494232b454e07c1d7a6db070990c9b2a3641472b80ec"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d", 6682L, "8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d", 3078427L, "8c16df97fd2facbcc6ee94b5b46d5d4ebe46ec2948b3a2453684f3ac5a249427"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d", 4909859L, "cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d", 4402515L, "6e6b8cb2bfd82f93b2651a46fc1f367ed21076fe53f34bf00a8adf3b09cce5e1"),
            new AuthorizedMember("xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d", 11641L, "0dde241f4a63641dd8e1014a6accd14debef3befcc725e1ba294e5c96ac94048")
        };

        private static readonly string[] FxLogicalNames =
        {
            "char_14401_fx.unity3d",
            "char_14401_buff.unity3d",
            "char_14401_weapons.unity3d"
        };

        private static readonly string[] AttackTokens =
        {
            "attack", "atk", "hit", "slash", "impact",
            "skill", "projectile", "bullet", "weapon"
        };

        private static readonly float[] SimulationTimes =
        {
            0.10f, 0.25f, 0.50f, 1.00f, 2.00f
        };

        private static bool hasRun;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void AutoRun()
        {
            if (hasRun)
            {
                return;
            }
            hasRun = true;
            RunProof();
        }

        private static void RunProof()
        {
            var report = CreateReport();
            var loadedBundles = new List<LoadedBundle>();
            var instantiatedObjects = new List<GameObject>();
            string inputRoot = null;
            string outputRoot = null;
            int exitCode = 1;
            try
            {
                report.stage = "PathGate";
                inputRoot = ResolveInputRoot();
                outputRoot = ResolveOutputRoot(inputRoot);
                PrepareOutput(outputRoot);
                report.stage = "MemberValidation";
                List<ValidatedMember> members =
                    ValidateAuthorizedMembers(inputRoot, report);
                report.stage = "EffectiveSelection";
                List<EffectiveBundle> effective = BuildEffectiveBundles(members);
                RecordEffectiveBundles(effective, report);
                report.stage = "BundleLoad";
                LoadEffectiveBundles(effective, loadedBundles, report);
                report.stage = "ModelValidation";
                GameObject character =
                    InstantiateAndValidateCharacter(loadedBundles, instantiatedObjects, report);
                report.stage = "AnimationValidation";
                ProofSelection selection =
                    ValidateAllAnimations(loadedBundles, character, outputRoot, report);
                report.stage = "FxValidation";
                ValidateAllFx(loadedBundles, outputRoot, report, selection);
                report.stage = "AttackCombination";
                CaptureAttackCombination(
                    character,
                    outputRoot,
                    instantiatedObjects,
                    report,
                    selection);
                if (!(report.modelConsumerProofPassed &&
                      report.animationConsumerProofPassed &&
                      report.battleFxConsumerProofPassed &&
                      report.screenshotProofPassed))
                {
                    throw new InvalidDataException("Player consumer proof gate failed.");
                }
                report.status = "Passed";
                report.nextAction = "AwaitUDCPFinalAudit";
                exitCode = 0;
            }
            catch (Exception exception)
            {
                CaptureFailure(report, exception, inputRoot, outputRoot);
                exitCode = 1;
            }
            finally
            {
                Cleanup(instantiatedObjects, loadedBundles, report, inputRoot, outputRoot, ref exitCode);
                WriteTerminalAndQuit(report, inputRoot, outputRoot, exitCode);
            }
        }

        private static PlayerReport CreateReport()
        {
            return new PlayerReport
            {
                schemaVersion = "player-proof/1.0.0",
                status = "Running",
                unityVersion = Application.unityVersion,
                expectedUnityVersion = RequiredUnityVersion,
                authorizedMemberCount = AuthorizedMemberCount,
                memberResults = new List<MemberResult>(),
                effectiveBundles = new List<EffectiveBundleResult>(),
                bundleResults = new List<BundleResult>(),
                animationResults = new List<AnimationResult>(),
                fxResults = new List<FxResult>(),
                contextBundle = NotApplicable,
                contextAsset = NotApplicable,
                contextObject = NotApplicable,
                failureBundle = NotApplicable,
                failureAsset = NotApplicable,
                failureObject = NotApplicable,
                exitCode = 1,
                nextAction = "AwaitUDCPFinalAudit"
            };
        }

        private static string ResolveInputRoot()
        {
            if (!string.Equals(
                    Application.unityVersion,
                    RequiredUnityVersion,
                    StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    $"Player Unity version must be {RequiredUnityVersion}.");
            }
            string supplied =
                Environment.GetEnvironmentVariable(InputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(supplied) ||
                !Path.IsPathRooted(supplied) ||
                IsUncOrDevicePath(supplied))
            {
                throw new InvalidOperationException(
                    $"{InputRootEnvironmentVariable} must be an absolute local path.");
            }
            string normalized = NormalizeDirectoryPath(supplied);
            string expectedSuffix = ExpectedInputRelativePath.Replace(
                '/', Path.DirectorySeparatorChar);
            if (!normalized.EndsWith(
                    expectedSuffix,
                    StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException(
                    $"Input root must end with {ExpectedInputRelativePath}.");
            }
            AssertNoReparsePath(normalized, true);
            return normalized;
        }

        private static string ResolveOutputRoot(string inputRoot)
        {
            string supplied =
                Environment.GetEnvironmentVariable(OutputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(supplied) ||
                !Path.IsPathRooted(supplied) ||
                IsUncOrDevicePath(supplied))
            {
                throw new InvalidOperationException(
                    $"{OutputRootEnvironmentVariable} must be an absolute local path.");
            }
            string normalized = NormalizeDirectoryPath(supplied);
            AssertExistingAncestorsNoReparse(normalized);
            if (PathsEqual(normalized, inputRoot) ||
                IsSameOrDescendant(normalized, inputRoot) ||
                IsSameOrDescendant(inputRoot, normalized))
            {
                throw new InvalidOperationException("Input/output roots must be disjoint.");
            }
            return normalized;
        }

        private static void PrepareOutput(string outputRoot)
        {
            Directory.CreateDirectory(outputRoot);
            AssertNoReparsePath(outputRoot, true);
            AssertCreateNewTargetAvailable(outputRoot, TerminalFileName);
            AssertCreateNewTargetAvailable(outputRoot, AttackCombinationFileName);
            CreateEvidenceDirectory(outputRoot, AnimationFrameDirectory);
            CreateEvidenceDirectory(outputRoot, FxFrameDirectory);
        }

        private static void CreateEvidenceDirectory(string outputRoot, string relativePath)
        {
            string fullPath = GetOutputPath(outputRoot, relativePath);
            if (Directory.Exists(fullPath) || File.Exists(fullPath))
            {
                throw new IOException($"Evidence directory already exists: {relativePath}");
            }
            Directory.CreateDirectory(fullPath);
            AssertNoReparsePath(fullPath, true);
        }

        private static List<ValidatedMember> ValidateAuthorizedMembers(
            string inputRoot,
            PlayerReport report)
        {
            if (AuthorizedMembers.Length != AuthorizedMemberCount)
            {
                throw new InvalidDataException("Authorized member count drifted.");
            }
            var validated = new List<ValidatedMember>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            long totalBytes = 0;
            foreach (AuthorizedMember expected in AuthorizedMembers)
            {
                SetContext(report, expected.relativePath, NotApplicable, NotApplicable);
                if (!seen.Add(expected.relativePath))
                {
                    throw new InvalidDataException("Duplicate authorized member.");
                }
                string absolutePath = Path.GetFullPath(Path.Combine(
                    inputRoot,
                    expected.relativePath.Replace(
                        '/', Path.DirectorySeparatorChar)));
                if (!IsSameOrDescendant(absolutePath, inputRoot))
                {
                    throw new InvalidDataException("Member escaped input root.");
                }
                AssertNoReparsePath(absolutePath, false);
                var fileInfo = new FileInfo(absolutePath);
                if (fileInfo.Length != expected.expectedLength)
                {
                    throw new InvalidDataException(
                        $"Member length mismatch: {expected.relativePath}.");
                }
                string actualSha256 = ComputeSha256(absolutePath);
                if (!string.Equals(
                        actualSha256,
                        expected.expectedSha256,
                        StringComparison.Ordinal))
                {
                    throw new InvalidDataException(
                        $"Member SHA-256 mismatch: {expected.relativePath}.");
                }
                totalBytes += fileInfo.Length;
                report.memberResults.Add(new MemberResult
                {
                    relativePath = expected.relativePath,
                    length = fileInfo.Length,
                    sha256 = actualSha256,
                    status = "Validated"
                });
                validated.Add(new ValidatedMember
                {
                    relativePath = expected.relativePath,
                    absolutePath = absolutePath
                });
            }
            report.inputByteCount = totalBytes;
            if (totalBytes != 117082750L)
            {
                throw new InvalidDataException("Input byte conservation failed.");
            }
            return validated;
        }

        private static List<EffectiveBundle> BuildEffectiveBundles(
            List<ValidatedMember> members)
        {
            var selected = new Dictionary<string, EffectiveBundle>(StringComparer.Ordinal);
            var logicalOrder = new List<string>();
            foreach (ValidatedMember member in members)
            {
                string logicalName = Path.GetFileName(member.relativePath);
                int priority = member.relativePath.StartsWith(
                    "Persistent_Store/AssetBundles/",
                    StringComparison.Ordinal) ? 0 : 1;
                var candidate = new EffectiveBundle
                {
                    logicalName = logicalName,
                    relativePath = member.relativePath,
                    absolutePath = member.absolutePath,
                    disposition = priority == 0 ? "Override" : "Baseline",
                    priority = priority
                };
                if (!selected.TryGetValue(logicalName, out EffectiveBundle existing))
                {
                    selected.Add(logicalName, candidate);
                    logicalOrder.Add(logicalName);
                }
                else if (priority < existing.priority)
                {
                    selected[logicalName] = candidate;
                }
            }
            var effective = new List<EffectiveBundle>();
            foreach (string logicalName in logicalOrder)
            {
                effective.Add(selected[logicalName]);
            }
            if (effective.Count != EffectiveBundleCount)
            {
                throw new InvalidDataException(
                    $"Expected {EffectiveBundleCount} effective bundles.");
            }
            return effective;
        }

        private static void RecordEffectiveBundles(
            List<EffectiveBundle> effective,
            PlayerReport report)
        {
            report.effectiveBundleCount = effective.Count;
            report.shadowedMemberCount =
                AuthorizedMemberCount - report.effectiveBundleCount;
            foreach (EffectiveBundle bundle in effective)
            {
                report.effectiveBundles.Add(new EffectiveBundleResult
                {
                    logicalName = bundle.logicalName,
                    relativePath = bundle.relativePath,
                    disposition = bundle.disposition
                });
            }
        }

        private static void LoadEffectiveBundles(
            List<EffectiveBundle> effective,
            List<LoadedBundle> loaded,
            PlayerReport report)
        {
            foreach (EffectiveBundle descriptor in effective)
            {
                SetContext(report, descriptor.relativePath, NotApplicable, NotApplicable);
                var result = new BundleResult
                {
                    logicalName = descriptor.logicalName,
                    relativePath = descriptor.relativePath,
                    status = "Loading"
                };
                report.bundleResults.Add(result);
                AssetBundle bundle = AssetBundle.LoadFromFile(descriptor.absolutePath);
                if (bundle == null)
                {
                    result.status = "Failed";
                    throw new InvalidDataException(
                        $"Player returned null for {descriptor.relativePath}.");
                }
                result.assetCount = bundle.GetAllAssetNames().Length;
                result.status = "Loaded";
                loaded.Add(new LoadedBundle
                {
                    descriptor = descriptor,
                    bundle = bundle
                });
            }
            if (loaded.Count != EffectiveBundleCount)
            {
                throw new InvalidDataException("Loaded bundle conservation failed.");
            }
        }

        private static GameObject InstantiateAndValidateCharacter(
            List<LoadedBundle> bundles,
            List<GameObject> instantiated,
            PlayerReport report)
        {
            GameObject prefab = null;
            LoadedBundle source = null;
            foreach (LoadedBundle bundle in bundles)
            {
                if (!IsCharacterBundle(bundle.descriptor.logicalName))
                {
                    continue;
                }
                GameObject[] candidates = bundle.bundle.LoadAllAssets<GameObject>();
                Array.Sort(candidates, CompareGameObjects);
                foreach (GameObject candidate in candidates)
                {
                    if (candidate.GetComponentsInChildren<SkinnedMeshRenderer>(true).Length > 0)
                    {
                        prefab = candidate;
                        source = bundle;
                        break;
                    }
                }
                if (prefab != null)
                {
                    break;
                }
            }
            if (prefab == null)
            {
                throw new InvalidDataException("No skinned character prefab was found.");
            }
            GameObject character = UnityEngine.Object.Instantiate(prefab);
            character.name = prefab.name;
            character.SetActive(true);
            instantiated.Add(character);
            SetContext(
                report,
                source.descriptor.relativePath,
                prefab.name,
                GetHierarchyPath(character.transform));

            SkinnedMeshRenderer[] renderers =
                character.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            var textureIds = new HashSet<int>();
            int meshCount = 0;
            int rootBoneCount = 0;
            int boneCount = 0;
            int materialCount = 0;
            int supportedShaderCount = 0;
            foreach (SkinnedMeshRenderer renderer in renderers)
            {
                if (renderer.sharedMesh == null ||
                    renderer.sharedMesh.vertexCount <= 0)
                {
                    throw new InvalidDataException("Character Mesh is missing.");
                }
                meshCount++;
                if (renderer.rootBone == null)
                {
                    throw new InvalidDataException("Character rootBone is missing.");
                }
                rootBoneCount++;
                if (renderer.bones == null || renderer.bones.Length == 0)
                {
                    throw new InvalidDataException("Character bones are missing.");
                }
                foreach (Transform bone in renderer.bones)
                {
                    if (bone == null || !IsFinite(bone))
                    {
                        throw new InvalidDataException("Character bone is null or non-finite.");
                    }
                    boneCount++;
                }
                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    throw new InvalidDataException("Character Material is missing.");
                }
                foreach (Material material in materials)
                {
                    ValidateMaterial(material, "Character");
                    materialCount++;
                    supportedShaderCount++;
                    foreach (string propertyName in material.GetTexturePropertyNames())
                    {
                        Texture texture = material.GetTexture(propertyName);
                        if (texture != null)
                        {
                            textureIds.Add(texture.GetInstanceID());
                        }
                    }
                }
            }
            if (textureIds.Count == 0 ||
                materialCount != supportedShaderCount)
            {
                throw new InvalidDataException(
                    "Character Material/Texture/Shader conservation failed.");
            }
            ValidateFinitePoseAndBounds(character);
            report.modelBundle = source.descriptor.relativePath;
            report.modelAsset = prefab.name;
            report.skinnedMeshRendererCount = renderers.Length;
            report.meshCount = meshCount;
            report.rootBoneCount = rootBoneCount;
            report.boneCount = boneCount;
            report.materialCount = materialCount;
            report.supportedCharacterShaderCount = supportedShaderCount;
            report.textureCount = textureIds.Count;
            report.modelConsumerProofPassed = true;
            return character;
        }

        private static ProofSelection ValidateAllAnimations(
            List<LoadedBundle> bundles,
            GameObject character,
            string outputRoot,
            PlayerReport report)
        {
            LoadedBundle source = null;
            foreach (LoadedBundle bundle in bundles)
            {
                if (string.Equals(
                        bundle.descriptor.logicalName,
                        FullAnimationLogicalName,
                        StringComparison.Ordinal))
                {
                    if (source != null)
                    {
                        throw new InvalidDataException(
                            "Multiple effective animation bundles were selected.");
                    }
                    source = bundle;
                }
            }
            if (source == null)
            {
                throw new InvalidDataException("Effective animation bundle is missing.");
            }

            AnimationClip[] clips = source.bundle.LoadAllAssets<AnimationClip>();
            Array.Sort(clips, CompareAnimationClips);
            report.totalAnimationClipCount = clips.Length;
            var selection = new ProofSelection
            {
                baseline = new PoseSnapshot(character)
            };
            int resultIndex = 0;
            foreach (AnimationClip clip in clips)
            {
                if (clip == null || clip.length <= 0f)
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
                var result = new AnimationResult
                {
                    bundle = source.descriptor.relativePath,
                    clip = clip.name,
                    length = clip.length,
                    isAttack = isAttack,
                    status = "Running"
                };
                report.animationResults.Add(result);
                SetContext(report, result.bundle, result.clip, character.name);
                try
                {
                    ValidateAnimation(
                        character,
                        clip,
                        selection.baseline,
                        outputRoot,
                        resultIndex,
                        result);
                    result.status = "Passed";
                    report.passedAnimationCount++;
                    if (isAttack && selection.attackClip == null)
                    {
                        selection.attackClip = clip;
                        selection.attackClipTime = result.frameTime;
                    }
                }
                catch (Exception exception)
                {
                    result.status = "Failed";
                    result.exceptionType = exception.GetType().FullName;
                    result.exceptionMessage =
                        SanitizePortableText(exception.Message, outputRoot);
                    result.exceptionStack =
                        SanitizePortableText(exception.StackTrace, outputRoot);
                    report.failedAnimationCount++;
                }
                finally
                {
                    selection.baseline.RestoreBaselinePose();
                }
                resultIndex++;
            }
            if (report.totalAnimationClipCount !=
                report.eligibleAnimationCount + report.ineligibleAnimationCount)
            {
                throw new InvalidDataException(
                    "Animation universe conservation failed.");
            }
            if (report.eligibleAnimationCount !=
                report.passedAnimationCount + report.failedAnimationCount)
            {
                throw new InvalidDataException(
                    "Animation result conservation failed.");
            }
            if (report.eligibleAnimationCount == 0 ||
                report.failedAnimationCount != 0)
            {
                throw new InvalidDataException(
                    "All eligible animations did not pass.");
            }
            if (report.eligibleAttackAnimationCount == 0 ||
                selection.attackClip == null)
            {
                throw new InvalidDataException(
                    "Attack animation subset is empty.");
            }
            report.animationConsumerProofPassed = true;
            return selection;
        }

        private static void ValidateAnimation(
            GameObject character,
            AnimationClip clip,
            PoseSnapshot baseline,
            string outputRoot,
            int resultIndex,
            AnimationResult result)
        {
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
            FrameCapture best = null;
            float bestTime = 0f;
            foreach (float sampleTime in sampleTimes)
            {
                baseline.RestoreBaselinePose();
                clip.SampleAnimation(
                    character,
                    Mathf.Clamp(sampleTime, 0f, clip.length));
                ValidateFinitePoseAndBounds(character);
                result.maximumBoneChange = Mathf.Max(
                    result.maximumBoneChange,
                    baseline.MaximumDifference());
                result.sampleCount++;
                FrameCapture capture =
                    CaptureSingleObjectFrame(character, CharacterLayer);
                if (best == null ||
                    capture.visibility.foregroundPixelCount >
                    best.visibility.foregroundPixelCount)
                {
                    best = capture;
                    bestTime = sampleTime;
                }
            }
            if (result.maximumBoneChange <= MotionEpsilon)
            {
                throw new InvalidDataException(
                    "Animation produced no measurable character transform change.");
            }
            result.classification = "RuntimeMotion";
            RequireVisibility($"animation {clip.name}", best.visibility);
            string relativePath =
                $"{AnimationFrameDirectory}/animation-{resultIndex:D4}.png";
            WriteBytesCreateNew(outputRoot, relativePath, best.png);
            RecordFrame(result, relativePath, bestTime, best);
        }

        private static void ValidateAllFx(
            List<LoadedBundle> bundles,
            string outputRoot,
            PlayerReport report,
            ProofSelection selection)
        {
            var candidates = new List<FxCandidate>();
            foreach (LoadedBundle bundle in bundles)
            {
                if (!IsFxBundle(bundle.descriptor.logicalName))
                {
                    continue;
                }
                GameObject[] prefabs = bundle.bundle.LoadAllAssets<GameObject>();
                Array.Sort(prefabs, CompareGameObjects);
                foreach (GameObject prefab in prefabs)
                {
                    candidates.Add(new FxCandidate
                    {
                        source = bundle,
                        prefab = prefab
                    });
                }
            }
            candidates.Sort(CompareFxCandidates);
            int resultIndex = 0;
            foreach (FxCandidate candidate in candidates)
            {
                report.discoveredFxCount++;
                if (!HasVisualComponents(candidate.prefab))
                {
                    report.ineligibleFxCount++;
                    continue;
                }
                report.eligibleFxCount++;
                bool isAttack = ContainsAttackToken(
                    candidate.source.descriptor.logicalName + "/" +
                    candidate.prefab.name);
                if (isAttack)
                {
                    report.eligibleAttackFxCount++;
                }
                var result = new FxResult
                {
                    bundle = candidate.source.descriptor.relativePath,
                    prefab = candidate.prefab.name,
                    isAttack = isAttack,
                    status = "Running",
                    samples = new List<FxSampleResult>()
                };
                report.fxResults.Add(result);
                SetContext(report, result.bundle, result.prefab, result.prefab);
                GameObject instance = null;
                try
                {
                    instance = UnityEngine.Object.Instantiate(candidate.prefab);
                    instance.name = candidate.prefab.name;
                    instance.SetActive(true);
                    ValidateFxMaterials(instance, result);
                    SimulateAndCaptureFx(
                        instance,
                        outputRoot,
                        resultIndex,
                        result);
                    result.status = "Passed";
                    report.passedFxCount++;
                    if (isAttack)
                    {
                        report.passedAttackFxCount++;
                        if (selection.attackFxPrefab == null)
                        {
                            selection.attackFxPrefab = candidate.prefab;
                            selection.attackFxBundle =
                                candidate.source.descriptor.relativePath;
                            selection.attackFxSimulationTime =
                                result.frameTime;
                        }
                    }
                }
                catch (Exception exception)
                {
                    result.status = "Failed";
                    result.exceptionType = exception.GetType().FullName;
                    result.exceptionMessage =
                        SanitizePortableText(exception.Message, outputRoot);
                    result.exceptionStack =
                        SanitizePortableText(exception.StackTrace, outputRoot);
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
            if (report.discoveredFxCount !=
                report.eligibleFxCount + report.ineligibleFxCount)
            {
                throw new InvalidDataException("FX universe conservation failed.");
            }
            if (report.eligibleFxCount !=
                report.passedFxCount + report.failedFxCount)
            {
                throw new InvalidDataException("FX result conservation failed.");
            }
            if (report.eligibleAttackFxCount !=
                report.passedAttackFxCount + report.failedAttackFxCount)
            {
                throw new InvalidDataException(
                    "Attack FX subset conservation failed.");
            }
            if (report.eligibleFxCount == 0 ||
                report.failedFxCount != 0)
            {
                throw new InvalidDataException("All eligible FX did not pass.");
            }
            if (report.eligibleAttackFxCount == 0 ||
                report.failedAttackFxCount != 0 ||
                report.passedAttackFxCount != report.eligibleAttackFxCount ||
                selection.attackFxPrefab == null)
            {
                throw new InvalidDataException(
                    "Attack FX subset did not pass in full.");
            }
            report.battleFxConsumerProofPassed = true;
        }

        private static void ValidateFxMaterials(
            GameObject instance,
            FxResult result)
        {
            Renderer[] renderers =
                instance.GetComponentsInChildren<Renderer>(true);
            ParticleSystem[] particleSystems =
                instance.GetComponentsInChildren<ParticleSystem>(true);
            result.rendererCount = renderers.Length;
            result.particleSystemCount = particleSystems.Length;
            foreach (Renderer renderer in renderers)
            {
                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    throw new InvalidDataException("FX Renderer Material is missing.");
                }
                foreach (Material material in materials)
                {
                    ValidateMaterial(material, "FX");
                    result.materialCount++;
                    result.supportedShaderCount++;
                }
            }
        }

        private static void ValidateMaterial(Material material, string subject)
        {
            if (material == null)
            {
                throw new InvalidDataException($"{subject} Material is null.");
            }
            Shader shader = material.shader;
            if (shader == null)
            {
                throw new InvalidDataException($"{subject} shader is null.");
            }
            if (!shader.isSupported)
            {
                throw new InvalidDataException(
                    $"{subject} shader is unsupported: {shader.name}.");
            }
            if (string.Equals(
                    shader.name,
                    "Hidden/InternalErrorShader",
                    StringComparison.Ordinal))
            {
                throw new InvalidDataException(
                    $"{subject} uses Hidden/InternalErrorShader.");
            }
        }

        private static void SimulateAndCaptureFx(
            GameObject instance,
            string outputRoot,
            int resultIndex,
            FxResult result)
        {
            ParticleSystem[] systems =
                instance.GetComponentsInChildren<ParticleSystem>(true);
            for (int index = 0; index < systems.Length; index++)
            {
                systems[index].useAutoRandomSeed = false;
                systems[index].randomSeed =
                    unchecked((uint)(144010000 + resultIndex * 257 + index));
            }
            FrameCapture best = null;
            float bestTime = 0f;
            foreach (float simulationTime in SimulationTimes)
            {
                foreach (ParticleSystem system in systems)
                {
                    system.Simulate(simulationTime, true, true, true);
                }
                int particleCount = 0;
                foreach (ParticleSystem system in systems)
                {
                    particleCount += system.particleCount;
                }
                int activeRendererCount = 0;
                int finiteNonZeroBoundsCount = 0;
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
                            "FX Renderer bounds are non-finite.");
                    }
                    if (renderer.bounds.size.sqrMagnitude > 0.00000001f)
                    {
                        finiteNonZeroBoundsCount++;
                    }
                }
                var sample = new FxSampleResult
                {
                    simulationTime = simulationTime,
                    particleCount = particleCount,
                    activeRendererCount = activeRendererCount,
                    finiteNonZeroBoundsCount = finiteNonZeroBoundsCount
                };
                result.samples.Add(sample);
                if (activeRendererCount == 0 ||
                    finiteNonZeroBoundsCount == 0)
                {
                    continue;
                }
                FrameCapture capture =
                    CaptureSingleObjectFrame(instance, FxLayer);
                sample.foregroundPixelCount =
                    capture.visibility.foregroundPixelCount;
                sample.brightnessRange = capture.visibility.brightnessRange;
                sample.distinctColorCount =
                    capture.visibility.distinctColorCount;
                if (!VisibilityPasses(capture.visibility))
                {
                    continue;
                }
                sample.visible = true;
                result.visibleSampleCount++;
                if (best == null ||
                    capture.visibility.foregroundPixelCount >
                    best.visibility.foregroundPixelCount)
                {
                    best = capture;
                    bestTime = simulationTime;
                }
            }
            if (best == null)
            {
                throw new InvalidDataException(
                    "FX produced no visible finite-bounds sample.");
            }
            string relativePath =
                $"{FxFrameDirectory}/fx-{resultIndex:D4}.png";
            WriteBytesCreateNew(outputRoot, relativePath, best.png);
            RecordFrame(result, relativePath, bestTime, best);
        }

        private static void CaptureAttackCombination(
            GameObject character,
            string outputRoot,
            List<GameObject> instantiated,
            PlayerReport report,
            ProofSelection selection)
        {
            selection.baseline.RestoreBaselinePose();
            selection.attackClip.SampleAnimation(
                character,
                selection.attackClipTime);
            ValidateFinitePoseAndBounds(character);
            GameObject fx =
                UnityEngine.Object.Instantiate(selection.attackFxPrefab);
            fx.name = selection.attackFxPrefab.name;
            fx.SetActive(true);
            fx.transform.position = CalculateBounds(character).center;
            instantiated.Add(fx);
            SetContext(
                report,
                selection.attackFxBundle,
                selection.attackClip.name + " + " +
                selection.attackFxPrefab.name,
                GetHierarchyPath(fx.transform));
            ParticleSystem[] systems =
                fx.GetComponentsInChildren<ParticleSystem>(true);
            for (int index = 0; index < systems.Length; index++)
            {
                systems[index].useAutoRandomSeed = false;
                systems[index].randomSeed =
                    unchecked((uint)(144019000 + index));
                systems[index].Simulate(
                    selection.attackFxSimulationTime,
                    true,
                    true,
                    true);
            }
            CompositeCapture capture = CaptureComposite(character, fx);
            report.characterForegroundPixelCount =
                capture.character.foregroundPixelCount;
            report.characterBrightnessRange =
                capture.character.brightnessRange;
            report.characterDistinctColorCount =
                capture.character.distinctColorCount;
            report.fxForegroundPixelCount =
                capture.fx.foregroundPixelCount;
            report.fxBrightnessRange =
                capture.fx.brightnessRange;
            report.fxDistinctColorCount =
                capture.fx.distinctColorCount;
            report.compositeForegroundPixelCount =
                capture.composite.foregroundPixelCount;
            report.compositeBrightnessRange =
                capture.composite.brightnessRange;
            report.compositeDistinctColorCount =
                capture.composite.distinctColorCount;
            RequireVisibility("attack character", capture.character);
            RequireVisibility("attack FX", capture.fx);
            RequireVisibility("attack composite", capture.composite);
            WriteBytesCreateNew(
                outputRoot,
                AttackCombinationFileName,
                capture.png);
            report.attackCombinationRelativePath =
                AttackCombinationFileName;
            report.attackCombinationByteCount = capture.png.LongLength;
            report.attackCombinationSha256 = ComputeSha256(capture.png);
            report.screenshotProofPassed = true;
        }

        private static FrameCapture CaptureSingleObjectFrame(
            GameObject root,
            int layer)
        {
            SetLayerRecursively(root, layer);
            Bounds bounds = CalculateBounds(root);
            RenderRig rig = CreateRenderRig(bounds);
            try
            {
                Color32[] baseline =
                    RenderPixels(rig.camera, rig.light, rig.texture, 0);
                Color32[] rendered = RenderPixels(
                    rig.camera,
                    rig.light,
                    rig.texture,
                    1 << layer);
                byte[] png = rig.texture.EncodeToPNG();
                if (png == null || png.Length == 0)
                {
                    throw new InvalidDataException("Frame PNG is empty.");
                }
                return new FrameCapture
                {
                    png = png,
                    visibility = AnalyzeVisibility(baseline, rendered)
                };
            }
            finally
            {
                DestroyRenderRig(rig);
            }
        }

        private static CompositeCapture CaptureComposite(
            GameObject character,
            GameObject fx)
        {
            SetLayerRecursively(character, CharacterLayer);
            SetLayerRecursively(fx, FxLayer);
            Bounds bounds = CalculateBounds(character);
            EncapsulateRenderers(fx, ref bounds);
            RenderRig rig = CreateRenderRig(bounds);
            try
            {
                Color32[] baseline =
                    RenderPixels(rig.camera, rig.light, rig.texture, 0);
                Color32[] characterPixels = RenderPixels(
                    rig.camera,
                    rig.light,
                    rig.texture,
                    1 << CharacterLayer);
                Color32[] fxPixels = RenderPixels(
                    rig.camera,
                    rig.light,
                    rig.texture,
                    1 << FxLayer);
                Color32[] compositePixels = RenderPixels(
                    rig.camera,
                    rig.light,
                    rig.texture,
                    (1 << CharacterLayer) | (1 << FxLayer));
                byte[] png = rig.texture.EncodeToPNG();
                if (png == null || png.Length == 0)
                {
                    throw new InvalidDataException(
                        "Attack combination PNG is empty.");
                }
                return new CompositeCapture
                {
                    png = png,
                    character = AnalyzeVisibility(baseline, characterPixels),
                    fx = AnalyzeVisibility(baseline, fxPixels),
                    composite = AnalyzeVisibility(baseline, compositePixels)
                };
            }
            finally
            {
                DestroyRenderRig(rig);
            }
        }

        private static RenderRig CreateRenderRig(Bounds bounds)
        {
            if (!IsFinite(bounds) ||
                bounds.size.sqrMagnitude <= 0.00000001f)
            {
                throw new InvalidDataException(
                    "Render bounds are not finite and nonzero.");
            }
            var cameraObject = new GameObject("UDCP-Player-Camera");
            var lightObject = new GameObject("UDCP-Player-Light");
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
                bounds.center +
                new Vector3(radius * 0.45f, radius * 0.25f, -radius * 4f);
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
            renderTexture.antiAliasing = 1;
            renderTexture.Create();
            camera.targetTexture = renderTexture;
            var texture = new Texture2D(
                ScreenshotWidth,
                ScreenshotHeight,
                TextureFormat.RGB24,
                false,
                true);
            return new RenderRig
            {
                cameraObject = cameraObject,
                lightObject = lightObject,
                camera = camera,
                light = light,
                renderTexture = renderTexture,
                texture = texture,
                previousRenderTexture = RenderTexture.active
            };
        }

        private static Color32[] RenderPixels(
            Camera camera,
            Light light,
            Texture2D texture,
            int cullingMask)
        {
            camera.cullingMask = cullingMask;
            light.cullingMask = cullingMask;
            RenderTexture.active = camera.targetTexture;
            camera.Render();
            texture.ReadPixels(
                new Rect(0, 0, ScreenshotWidth, ScreenshotHeight),
                0,
                0,
                false);
            texture.Apply(false, false);
            return texture.GetPixels32();
        }

        private static void DestroyRenderRig(RenderRig rig)
        {
            rig.camera.targetTexture = null;
            RenderTexture.active = rig.previousRenderTexture;
            if (rig.renderTexture.IsCreated())
            {
                rig.renderTexture.Release();
            }
            UnityEngine.Object.DestroyImmediate(rig.texture);
            UnityEngine.Object.DestroyImmediate(rig.renderTexture);
            UnityEngine.Object.DestroyImmediate(rig.cameraObject);
            UnityEngine.Object.DestroyImmediate(rig.lightObject);
        }

        private static VisibilityMetrics AnalyzeVisibility(
            Color32[] baseline,
            Color32[] rendered)
        {
            if (baseline == null ||
                rendered == null ||
                baseline.Length != rendered.Length)
            {
                throw new InvalidDataException(
                    "Visibility pixel accounting mismatch.");
            }
            int foregroundPixelCount = 0;
            int minimumBrightness = 255;
            int maximumBrightness = 0;
            var colors = new HashSet<int>();
            for (int index = 0; index < rendered.Length; index++)
            {
                int red = rendered[index].r - baseline[index].r;
                int green = rendered[index].g - baseline[index].g;
                int blue = rendered[index].b - baseline[index].b;
                if (red * red + green * green + blue * blue <=
                    ForegroundDifferenceSquared)
                {
                    continue;
                }
                foregroundPixelCount++;
                int brightness =
                    ((77 * rendered[index].r) +
                     (150 * rendered[index].g) +
                     (29 * rendered[index].b)) >> 8;
                minimumBrightness = Math.Min(minimumBrightness, brightness);
                maximumBrightness = Math.Max(maximumBrightness, brightness);
                colors.Add(
                    ((rendered[index].r >> 4) << 8) |
                    ((rendered[index].g >> 4) << 4) |
                    (rendered[index].b >> 4));
            }
            return new VisibilityMetrics
            {
                foregroundPixelCount = foregroundPixelCount,
                brightnessRange = foregroundPixelCount == 0
                    ? 0
                    : maximumBrightness - minimumBrightness,
                distinctColorCount = colors.Count
            };
        }

        private static bool VisibilityPasses(VisibilityMetrics metrics)
        {
            return metrics.foregroundPixelCount >= MinimumForegroundPixels &&
                   metrics.brightnessRange >= MinimumBrightnessRange &&
                   metrics.distinctColorCount >= MinimumDistinctColorBins;
        }

        private static void RequireVisibility(
            string subject,
            VisibilityMetrics metrics)
        {
            if (!VisibilityPasses(metrics))
            {
                throw new InvalidDataException(
                    $"{subject} did not satisfy deterministic visibility gates.");
            }
        }

        private static void ValidateFinitePoseAndBounds(GameObject root)
        {
            foreach (Transform transform in
                     root.GetComponentsInChildren<Transform>(true))
            {
                if (!IsFinite(transform))
                {
                    throw new InvalidDataException(
                        $"Non-finite Transform: {GetHierarchyPath(transform)}.");
                }
            }
            foreach (Renderer renderer in
                     root.GetComponentsInChildren<Renderer>(true))
            {
                if (!IsFinite(renderer.bounds))
                {
                    throw new InvalidDataException(
                        $"Non-finite Renderer bounds: {GetHierarchyPath(renderer.transform)}.");
                }
            }
        }

        private static Bounds CalculateBounds(GameObject root)
        {
            Renderer[] renderers =
                root.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0)
            {
                throw new InvalidDataException("Object has no Renderer bounds.");
            }
            Bounds bounds = renderers[0].bounds;
            for (int index = 1; index < renderers.Length; index++)
            {
                bounds.Encapsulate(renderers[index].bounds);
            }
            return bounds;
        }

        private static void EncapsulateRenderers(
            GameObject root,
            ref Bounds bounds)
        {
            foreach (Renderer renderer in
                     root.GetComponentsInChildren<Renderer>(true))
            {
                bounds.Encapsulate(renderer.bounds);
            }
        }

        private static void SetLayerRecursively(GameObject root, int layer)
        {
            root.layer = layer;
            foreach (Transform child in root.transform)
            {
                SetLayerRecursively(child.gameObject, layer);
            }
        }

        private static bool IsCharacterBundle(string logicalName)
        {
            return string.Equals(
                       logicalName,
                       "char_14401.unity3d",
                       StringComparison.Ordinal) ||
                   string.Equals(
                       logicalName,
                       "char_14401_models.unity3d",
                       StringComparison.Ordinal);
        }

        private static bool IsFxBundle(string logicalName)
        {
            foreach (string expected in FxLogicalNames)
            {
                if (string.Equals(
                        logicalName,
                        expected,
                        StringComparison.Ordinal))
                {
                    return true;
                }
            }
            return false;
        }

        private static bool HasVisualComponents(GameObject prefab)
        {
            return prefab != null &&
                   (prefab.GetComponentsInChildren<Renderer>(true).Length > 0 ||
                    prefab.GetComponentsInChildren<ParticleSystem>(true).Length > 0);
        }

        private static bool ContainsAttackToken(string value)
        {
            foreach (string token in AttackTokens)
            {
                if (value.IndexOf(
                        token,
                        StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static int CompareGameObjects(GameObject left, GameObject right)
        {
            return string.CompareOrdinal(left.name, right.name);
        }

        private static int CompareAnimationClips(
            AnimationClip left,
            AnimationClip right)
        {
            int name = string.CompareOrdinal(left.name, right.name);
            return name != 0 ? name : left.length.CompareTo(right.length);
        }

        private static int CompareFxCandidates(
            FxCandidate left,
            FxCandidate right)
        {
            int bundle = string.CompareOrdinal(
                left.source.descriptor.relativePath,
                right.source.descriptor.relativePath);
            return bundle != 0
                ? bundle
                : string.CompareOrdinal(left.prefab.name, right.prefab.name);
        }

        private static void Cleanup(
            List<GameObject> instantiated,
            List<LoadedBundle> loaded,
            PlayerReport report,
            string inputRoot,
            string outputRoot,
            ref int exitCode)
        {
            try
            {
                for (int index = instantiated.Count - 1; index >= 0; index--)
                {
                    if (instantiated[index] != null)
                    {
                        UnityEngine.Object.DestroyImmediate(instantiated[index]);
                    }
                }
                for (int index = loaded.Count - 1; index >= 0; index--)
                {
                    if (loaded[index].bundle != null)
                    {
                        loaded[index].bundle.Unload(true);
                    }
                }
            }
            catch (Exception exception)
            {
                CaptureFailure(report, exception, inputRoot, outputRoot);
                exitCode = 2;
            }
        }

        private static void CaptureFailure(
            PlayerReport report,
            Exception exception,
            string inputRoot,
            string outputRoot)
        {
            report.status = "Failed";
            report.failureStage = report.stage;
            report.failureBundle = report.contextBundle ?? NotApplicable;
            report.failureAsset = report.contextAsset ?? NotApplicable;
            report.failureObject = report.contextObject ?? NotApplicable;
            report.exceptionType = exception.GetType().FullName;
            report.exceptionMessage = SanitizePortableText(
                exception.Message,
                inputRoot,
                outputRoot);
            report.exceptionStack = SanitizePortableText(
                exception.StackTrace,
                inputRoot,
                outputRoot);
        }

        private static void WriteTerminalAndQuit(
            PlayerReport report,
            string inputRoot,
            string outputRoot,
            int exitCode)
        {
            report.stage = "TerminalWrite";
            report.exitCode = exitCode;
            try
            {
                if (string.IsNullOrEmpty(outputRoot))
                {
                    throw new InvalidOperationException(
                        "Safe output root was not established.");
                }
                byte[] json = new UTF8Encoding(false, true).GetBytes(
                    JsonUtility.ToJson(report, true));
                WriteBytesCreateNew(outputRoot, TerminalFileName, json);
            }
            catch (Exception exception)
            {
                exitCode = 3;
                report.exitCode = exitCode;
                CaptureFailure(report, exception, inputRoot, outputRoot);
                Debug.LogError(JsonUtility.ToJson(report, true));
            }
            Application.Quit(exitCode);
        }

        private static void SetContext(
            PlayerReport report,
            string bundle,
            string asset,
            string objectPath)
        {
            report.contextBundle = bundle ?? NotApplicable;
            report.contextAsset = asset ?? NotApplicable;
            report.contextObject = objectPath ?? NotApplicable;
        }

        private static string ComputeSha256(string path)
        {
            using (var algorithm = SHA256.Create())
            using (var stream = new FileStream(
                path,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read))
            {
                return ToLowerHex(algorithm.ComputeHash(stream));
            }
        }

        private static string ComputeSha256(byte[] bytes)
        {
            using (var algorithm = SHA256.Create())
            {
                return ToLowerHex(algorithm.ComputeHash(bytes));
            }
        }

        private static string ToLowerHex(byte[] bytes)
        {
            var builder = new StringBuilder(bytes.Length * 2);
            foreach (byte value in bytes)
            {
                builder.Append(value.ToString("x2"));
            }
            return builder.ToString();
        }

        private static void WriteBytesCreateNew(
            string outputRoot,
            string relativePath,
            byte[] bytes)
        {
            string outputPath = GetOutputPath(outputRoot, relativePath);
            using (var stream = new FileStream(
                outputPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None))
            {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
            }
        }

        private static void AssertCreateNewTargetAvailable(
            string outputRoot,
            string relativePath)
        {
            string path = GetOutputPath(outputRoot, relativePath);
            if (File.Exists(path) || Directory.Exists(path))
            {
                throw new IOException(
                    $"CreateNew target exists: {relativePath}.");
            }
        }

        private static string GetOutputPath(
            string outputRoot,
            string relativePath)
        {
            string path = Path.GetFullPath(Path.Combine(
                outputRoot,
                relativePath.Replace('/', Path.DirectorySeparatorChar)));
            if (!IsSameOrDescendant(path, outputRoot))
            {
                throw new InvalidOperationException(
                    "Evidence path escaped output root.");
            }
            return path;
        }

        private static void RecordFrame(
            AnimationResult result,
            string relativePath,
            float time,
            FrameCapture capture)
        {
            result.frameRelativePath = relativePath;
            result.frameTime = time;
            result.frameByteCount = capture.png.LongLength;
            result.frameSha256 = ComputeSha256(capture.png);
            result.foregroundPixelCount =
                capture.visibility.foregroundPixelCount;
            result.brightnessRange = capture.visibility.brightnessRange;
            result.distinctColorCount =
                capture.visibility.distinctColorCount;
        }

        private static void RecordFrame(
            FxResult result,
            string relativePath,
            float time,
            FrameCapture capture)
        {
            result.frameRelativePath = relativePath;
            result.frameTime = time;
            result.frameByteCount = capture.png.LongLength;
            result.frameSha256 = ComputeSha256(capture.png);
            result.foregroundPixelCount =
                capture.visibility.foregroundPixelCount;
            result.brightnessRange = capture.visibility.brightnessRange;
            result.distinctColorCount =
                capture.visibility.distinctColorCount;
        }

        private static bool IsFinite(Transform transform)
        {
            return IsFinite(transform.localPosition) &&
                   IsFinite(transform.localRotation) &&
                   IsFinite(transform.localScale);
        }

        private static bool IsFinite(Vector3 value)
        {
            return IsFinite(value.x) &&
                   IsFinite(value.y) &&
                   IsFinite(value.z);
        }

        private static bool IsFinite(Quaternion value)
        {
            return IsFinite(value.x) &&
                   IsFinite(value.y) &&
                   IsFinite(value.z) &&
                   IsFinite(value.w);
        }

        private static bool IsFinite(Bounds value)
        {
            return IsFinite(value.center) && IsFinite(value.extents);
        }

        private static bool IsFinite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }

        private static string GetHierarchyPath(Transform transform)
        {
            var parts = new List<string>();
            Transform cursor = transform;
            while (cursor != null)
            {
                parts.Add(cursor.name);
                cursor = cursor.parent;
            }
            parts.Reverse();
            return string.Join("/", parts);
        }

        private static bool IsUncOrDevicePath(string path)
        {
            return path.Length >= 2 &&
                   IsDirectorySeparator(path[0]) &&
                   IsDirectorySeparator(path[1]);
        }

        private static bool IsDirectorySeparator(char value)
        {
            return value == Path.DirectorySeparatorChar ||
                   value == Path.AltDirectorySeparatorChar;
        }

        private static string NormalizeDirectoryPath(string path)
        {
            string fullPath = Path.GetFullPath(path);
            string root = Path.GetPathRoot(fullPath);
            if (!string.Equals(
                    fullPath,
                    root,
                    StringComparison.OrdinalIgnoreCase))
            {
                fullPath = fullPath.TrimEnd(
                    Path.DirectorySeparatorChar,
                    Path.AltDirectorySeparatorChar);
            }
            return fullPath;
        }

        private static bool PathsEqual(string left, string right)
        {
            return string.Equals(
                NormalizeDirectoryPath(left),
                NormalizeDirectoryPath(right),
                StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsSameOrDescendant(
            string candidate,
            string ancestor)
        {
            string normalizedCandidate = Path.GetFullPath(candidate);
            string normalizedAncestor = NormalizeDirectoryPath(ancestor);
            return string.Equals(
                       normalizedCandidate,
                       normalizedAncestor,
                       StringComparison.OrdinalIgnoreCase) ||
                   normalizedCandidate.StartsWith(
                       normalizedAncestor + Path.DirectorySeparatorChar,
                       StringComparison.OrdinalIgnoreCase);
        }

        private static void AssertExistingAncestorsNoReparse(string fullPath)
        {
            string root = Path.GetPathRoot(fullPath);
            if (string.IsNullOrEmpty(root))
            {
                throw new InvalidOperationException(
                    "Path has no local volume root.");
            }
            string cursor = root;
            AssertEntryNoReparse(cursor);
            string remainder = fullPath.Substring(root.Length);
            string[] parts = remainder.Split(
                new[]
                {
                    Path.DirectorySeparatorChar,
                    Path.AltDirectorySeparatorChar
                },
                StringSplitOptions.RemoveEmptyEntries);
            foreach (string part in parts)
            {
                cursor = Path.Combine(cursor, part);
                if (!Directory.Exists(cursor) && !File.Exists(cursor))
                {
                    break;
                }
                AssertEntryNoReparse(cursor);
            }
        }

        private static void AssertNoReparsePath(
            string fullPath,
            bool expectDirectory)
        {
            AssertExistingAncestorsNoReparse(fullPath);
            if (expectDirectory && !Directory.Exists(fullPath))
            {
                throw new DirectoryNotFoundException(
                    "Expected directory does not exist.");
            }
            if (!expectDirectory && !File.Exists(fullPath))
            {
                throw new FileNotFoundException(
                    "Expected file does not exist.");
            }
            AssertEntryNoReparse(fullPath);
        }

        private static void AssertEntryNoReparse(string path)
        {
            if ((File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException(
                    "Reparse path component is forbidden.");
            }
        }

        private static string SanitizePortableText(
            string value,
            string outputRoot)
        {
            return SanitizePortableText(value, null, outputRoot);
        }

        private static string SanitizePortableText(
            string value,
            string inputRoot,
            string outputRoot)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }
            string sanitized = value;
            if (!string.IsNullOrEmpty(inputRoot))
            {
                sanitized = sanitized.Replace(inputRoot, "<INPUT_ROOT>");
            }
            if (!string.IsNullOrEmpty(outputRoot))
            {
                sanitized = sanitized.Replace(outputRoot, "<OUTPUT_ROOT>");
            }
            string[] lines = sanitized.Replace("\r\n", "\n").Split('\n');
            for (int lineIndex = 0; lineIndex < lines.Length; lineIndex++)
            {
                for (int index = 0; index + 2 < lines[lineIndex].Length; index++)
                {
                    if ((char.IsLetter(lines[lineIndex][index]) &&
                         lines[lineIndex][index + 1] == ':' &&
                         IsDirectorySeparator(lines[lineIndex][index + 2])) ||
                        (IsDirectorySeparator(lines[lineIndex][index]) &&
                         IsDirectorySeparator(lines[lineIndex][index + 1])))
                    {
                        lines[lineIndex] =
                            lines[lineIndex].Substring(0, index) +
                            "<ABSOLUTE_PATH>";
                        break;
                    }
                }
            }
            return string.Join("\n", lines);
        }

        private sealed class PoseSnapshot
        {
            private readonly Transform[] transforms;
            private readonly Vector3[] positions;
            private readonly Quaternion[] rotations;
            private readonly Vector3[] scales;

            public PoseSnapshot(GameObject character)
            {
                transforms =
                    character.GetComponentsInChildren<Transform>(true);
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
                        Vector3.Distance(
                            positions[index],
                            transforms[index].localPosition),
                        Quaternion.Angle(
                            rotations[index],
                            transforms[index].localRotation),
                        Vector3.Distance(
                            scales[index],
                            transforms[index].localScale));
                }
                return maximum;
            }
        }

        private sealed class ProofSelection
        {
            public PoseSnapshot baseline;
            public AnimationClip attackClip;
            public float attackClipTime;
            public GameObject attackFxPrefab;
            public string attackFxBundle;
            public float attackFxSimulationTime;
        }

        private sealed class RenderRig
        {
            public GameObject cameraObject;
            public GameObject lightObject;
            public Camera camera;
            public Light light;
            public RenderTexture renderTexture;
            public Texture2D texture;
            public RenderTexture previousRenderTexture;
        }

        private sealed class FrameCapture
        {
            public byte[] png;
            public VisibilityMetrics visibility;
        }

        private sealed class CompositeCapture
        {
            public byte[] png;
            public VisibilityMetrics character;
            public VisibilityMetrics fx;
            public VisibilityMetrics composite;
        }

        private sealed class VisibilityMetrics
        {
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
        }

        private sealed class AuthorizedMember
        {
            public AuthorizedMember(
                string relativePath,
                long expectedLength,
                string expectedSha256)
            {
                this.relativePath = relativePath;
                this.expectedLength = expectedLength;
                this.expectedSha256 = expectedSha256;
            }

            public readonly string relativePath;
            public readonly long expectedLength;
            public readonly string expectedSha256;
        }

        private sealed class ValidatedMember
        {
            public string relativePath;
            public string absolutePath;
        }

        private sealed class EffectiveBundle
        {
            public string logicalName;
            public string relativePath;
            public string absolutePath;
            public string disposition;
            public int priority;
        }

        private sealed class LoadedBundle
        {
            public EffectiveBundle descriptor;
            public AssetBundle bundle;
        }

        private sealed class FxCandidate
        {
            public LoadedBundle source;
            public GameObject prefab;
        }

        [Serializable]
        private sealed class PlayerReport
        {
            public string schemaVersion;
            public string status;
            public string stage;
            public string unityVersion;
            public string expectedUnityVersion;
            public int authorizedMemberCount;
            public long inputByteCount;
            public int effectiveBundleCount;
            public int shadowedMemberCount;
            public List<MemberResult> memberResults;
            public List<EffectiveBundleResult> effectiveBundles;
            public List<BundleResult> bundleResults;

            public bool modelConsumerProofPassed;
            public string modelBundle;
            public string modelAsset;
            public int skinnedMeshRendererCount;
            public int meshCount;
            public int rootBoneCount;
            public int boneCount;
            public int materialCount;
            public int supportedCharacterShaderCount;
            public int textureCount;

            public bool animationConsumerProofPassed;
            public int totalAnimationClipCount;
            public int ineligibleAnimationCount;
            public int eligibleAnimationCount;
            public int passedAnimationCount;
            public int failedAnimationCount;
            public int eligibleAttackAnimationCount;
            public List<AnimationResult> animationResults;

            public bool battleFxConsumerProofPassed;
            public int discoveredFxCount;
            public int ineligibleFxCount;
            public int eligibleFxCount;
            public int passedFxCount;
            public int failedFxCount;
            public int eligibleAttackFxCount;
            public int passedAttackFxCount;
            public int failedAttackFxCount;
            public List<FxResult> fxResults;

            public bool screenshotProofPassed;
            public string attackCombinationRelativePath;
            public long attackCombinationByteCount;
            public string attackCombinationSha256;
            public int characterForegroundPixelCount;
            public int characterBrightnessRange;
            public int characterDistinctColorCount;
            public int fxForegroundPixelCount;
            public int fxBrightnessRange;
            public int fxDistinctColorCount;
            public int compositeForegroundPixelCount;
            public int compositeBrightnessRange;
            public int compositeDistinctColorCount;

            public string contextBundle;
            public string contextAsset;
            public string contextObject;
            public string failureStage;
            public string failureBundle;
            public string failureAsset;
            public string failureObject;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
            public int exitCode;
            public string nextAction;
        }

        [Serializable]
        private sealed class MemberResult
        {
            public string relativePath;
            public long length;
            public string sha256;
            public string status;
        }

        [Serializable]
        private sealed class EffectiveBundleResult
        {
            public string logicalName;
            public string relativePath;
            public string disposition;
        }

        [Serializable]
        private sealed class BundleResult
        {
            public string logicalName;
            public string relativePath;
            public string status;
            public int assetCount;
        }

        [Serializable]
        private sealed class AnimationResult
        {
            public string bundle;
            public string clip;
            public float length;
            public bool isAttack;
            public string classification;
            public int sampleCount;
            public float maximumBoneChange;
            public string frameRelativePath;
            public float frameTime;
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
        private sealed class FxResult
        {
            public string bundle;
            public string prefab;
            public bool isAttack;
            public int rendererCount;
            public int particleSystemCount;
            public int materialCount;
            public int supportedShaderCount;
            public int visibleSampleCount;
            public string frameRelativePath;
            public float frameTime;
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
