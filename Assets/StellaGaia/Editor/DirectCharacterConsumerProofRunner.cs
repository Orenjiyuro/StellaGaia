using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.Editor
{
    public static partial class DirectCharacterConsumerProofRunner
    {
        private const string InputRootEnvironmentVariable = "STELLAGAIA_UDCP_INPUT_ROOT";
        private const string OutputRootEnvironmentVariable = "STELLAGAIA_UDCP_OUTPUT_ROOT";
        private const string ExpectedInputRelativePath =
            "Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1-A02/Input";
        private const string TerminalFileName = "terminal-result.json";
        private const string ScreenshotFileName = "smoke-screenshot.png";
        private const int AuthorizedMemberCount = 17;
        private const int EffectiveBundleCount = 12;
        private const int ScreenshotWidth = 512;
        private const int ScreenshotHeight = 512;
        private const int CharacterProofLayer = 30;
        private const int FxProofLayer = 31;
        private const int MinimumForegroundPixels = 64;
        private const int MinimumBrightnessRange = 4;
        private const int MinimumDistinctColorBins = 2;
        private const int ForegroundDifferenceSquared = 64;
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

        private static readonly string[] attackTokens =
        {
            "attack", "atk", "hit", "slash", "impact", "skill", "projectile", "bullet", "weapon"
        };

        public static void RunSmoke()
        {
            RunConsumerProof(ValidationMode.Smoke);
        }

        public static void RunFullValidation()
        {
            RunConsumerProof(ValidationMode.Full);
        }

        private static void RunConsumerProof(ValidationMode mode)
        {
            var report = CreateReport(mode);
            var loadedBundles = new List<LoadedBundle>();
            var instantiatedObjects = new List<GameObject>();
            string inputRoot = null;
            string outputRoot = null;
            int exitCode = 1;

            try
            {
                report.stage = "PathGate";
                BeginStage(report, report.stage);
                outputRoot = ResolveOutputRoot();
                string expectedInputRoot = ResolveExpectedInputRoot();
                AssertSeparatedRoots(expectedInputRoot, outputRoot);
                PrepareOutputRoot(outputRoot);
                AssertEvidencePathsAvailable(outputRoot);
                if (mode == ValidationMode.Full)
                {
                    PrepareFullValidationOutput(outputRoot);
                }
                CompleteStage(report);

                report.stage = "InputIdentity";
                BeginStage(report, report.stage);
                inputRoot = ResolveAndBindInputRoot(expectedInputRoot);
                CompleteStage(report);

                report.stage = "MemberValidation";
                BeginStage(report, report.stage);
                List<ValidatedMember> validatedMembers = ValidateAuthorizedMembers(inputRoot, report);
                CompleteStage(report);

                report.stage = "EffectiveSelection";
                BeginStage(report, report.stage);
                List<EffectiveBundle> effectiveBundles = BuildEffectiveBundles(validatedMembers);
                RecordEffectiveBundles(effectiveBundles, report);
                CompleteStage(report);

                report.stage = "BundleLoad";
                BeginStage(report, report.stage);
                LoadEffectiveBundles(effectiveBundles, loadedBundles, report);
                CompleteStage(report);

                report.stage = "CharacterInstantiation";
                BeginStage(report, report.stage);
                GameObject character = InstantiateAndValidateCharacter(
                    loadedBundles, instantiatedObjects, report);
                CompleteStage(report);

                if (mode == ValidationMode.Full)
                {
                    report.stage = "FullAnimationValidation";
                    BeginStage(report, report.stage);
                    FullValidationSelection selection = ValidateAllAnimations(
                        loadedBundles, character, outputRoot, report);
                    CompleteStage(report);

                    report.stage = "FullFxValidation";
                    BeginStage(report, report.stage);
                    ValidateAllVisualEffects(
                        loadedBundles, outputRoot, report, selection);
                    CompleteStage(report);

                    report.stage = "AttackCombination";
                    BeginStage(report, report.stage);
                    CaptureAttackCombination(
                        character,
                        outputRoot,
                        instantiatedObjects,
                        report,
                        selection);
                    CompleteStage(report);
                }
                else
                {
                    report.stage = "AnimationSampling";
                    BeginStage(report, report.stage);
                    SampleBoundAnimation(loadedBundles, character, report);
                    CompleteStage(report);

                    report.stage = "AttackFxInstantiation";
                    BeginStage(report, report.stage);
                    GameObject attackFx = InstantiateAndValidateAttackFx(
                        loadedBundles, character, instantiatedObjects, report);
                    CompleteStage(report);

                    report.stage = "Screenshot";
                    BeginStage(report, report.stage);
                    CaptureDeterministicScreenshot(
                        character, attackFx, outputRoot, instantiatedObjects, report);
                    CompleteStage(report);
                }

                if (!(report.modelConsumerProofPassed &&
                      report.animationConsumerProofPassed &&
                      report.battleFxConsumerProofPassed &&
                      report.screenshotProofPassed))
                {
                    throw new InvalidDataException("Consumer proof conservation failed.");
                }

                report.status = "Passed";
                report.nextAction = mode == ValidationMode.Full
                    ? "AwaitUDCPFinalAudit"
                    : "AwaitUDCPLO1Audit";
                exitCode = 0;
            }
            catch (Exception exception)
            {
                CaptureFailure(report, exception, inputRoot, outputRoot);
                exitCode = 1;
            }
            finally
            {
                Cleanup(report, instantiatedObjects, loadedBundles, inputRoot, outputRoot, ref exitCode);
                WriteTerminalAndExit(report, inputRoot, outputRoot, exitCode);
            }
        }

        private static TerminalReport CreateReport(ValidationMode mode)
        {
            return new TerminalReport
            {
                schemaVersion = "udcp-direct-consumer-terminal/2.0.0",
                validationMode = mode.ToString(),
                status = "Running",
                unityVersion = Application.unityVersion,
                expectedInputRelativePath = ExpectedInputRelativePath,
                authorizedMemberCount = AuthorizedMemberCount,
                effectiveBundleCount = 0,
                shadowedMemberCount = 0,
                memberResults = new List<MemberResult>(),
                effectiveBundles = new List<EffectiveBundleResult>(),
                bundleResults = new List<BundleResult>(),
                stageResults = new List<StageResult>(),
                contextBundle = NotApplicable,
                contextAsset = NotApplicable,
                contextObject = NotApplicable,
                failureBundle = NotApplicable,
                failureAsset = NotApplicable,
                failureObject = NotApplicable,
                exitCode = 1,
                animationResults = new List<AnimationValidationResult>(),
                fxResults = new List<FxValidationResult>(),
                nextAction = mode == ValidationMode.Full
                    ? "AwaitUDCPFinalAudit"
                    : "AwaitUDCPLO1Audit"
            };
        }

        private static string ResolveExpectedInputRoot()
        {
            if (string.IsNullOrWhiteSpace(Application.dataPath) ||
                !Path.IsPathRooted(Application.dataPath) ||
                IsUncOrDevicePath(Application.dataPath))
            {
                throw new InvalidOperationException("Unity project Assets path is not an absolute local path.");
            }

            string projectRoot = NormalizeDirectoryPath(Path.GetDirectoryName(Application.dataPath));
            AssertNoReparsePath(projectRoot, true);
            string expected = Path.GetFullPath(Path.Combine(
                projectRoot,
                ExpectedInputRelativePath.Replace('/', Path.DirectorySeparatorChar)));
            if (!IsSameOrDescendant(expected, projectRoot))
            {
                throw new InvalidOperationException("Expected input path escapes the Unity project root.");
            }
            return expected;
        }

        private static string ResolveAndBindInputRoot(string expectedInputRoot)
        {
            string supplied = Environment.GetEnvironmentVariable(InputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(supplied))
            {
                throw new InvalidOperationException($"{InputRootEnvironmentVariable} is required.");
            }
            if (!Path.IsPathRooted(supplied) || IsUncOrDevicePath(supplied))
            {
                throw new InvalidOperationException("Input root must be an absolute local path.");
            }

            string normalized = NormalizeDirectoryPath(supplied);
            if (!PathsEqual(normalized, expectedInputRoot))
            {
                throw new InvalidOperationException(
                    $"Input root must identify project-relative {ExpectedInputRelativePath}.");
            }
            AssertNoReparsePath(normalized, true);
            return normalized;
        }

        private static string ResolveOutputRoot()
        {
            string supplied = Environment.GetEnvironmentVariable(OutputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(supplied))
            {
                throw new InvalidOperationException($"{OutputRootEnvironmentVariable} is required.");
            }
            if (!Path.IsPathRooted(supplied) || IsUncOrDevicePath(supplied))
            {
                throw new InvalidOperationException("Output root must be an absolute local path.");
            }

            string normalized = NormalizeDirectoryPath(supplied);
            AssertExistingAncestorsNoReparse(normalized);
            return normalized;
        }

        private static void PrepareOutputRoot(string outputRoot)
        {
            Directory.CreateDirectory(outputRoot);
            AssertNoReparsePath(outputRoot, true);
        }

        private static void AssertEvidencePathsAvailable(string outputRoot)
        {
            AssertCreateNewTargetAvailable(outputRoot, ScreenshotFileName);
            AssertCreateNewTargetAvailable(outputRoot, TerminalFileName);
        }

        private static void AssertCreateNewTargetAvailable(string outputRoot, string fileName)
        {
            string target = GetOutputPath(outputRoot, fileName);
            if (File.Exists(target) || Directory.Exists(target))
            {
                throw new IOException($"CreateNew evidence target already exists: {fileName}");
            }
        }

        private static List<ValidatedMember> ValidateAuthorizedMembers(
            string inputRoot,
            TerminalReport report)
        {
            if (AuthorizedMembers.Length != AuthorizedMemberCount)
            {
                throw new InvalidDataException("Authorized member accounting drifted.");
            }

            var seen = new HashSet<string>(StringComparer.Ordinal);
            var validated = new List<ValidatedMember>(AuthorizedMemberCount);
            foreach (AuthorizedMember expected in AuthorizedMembers)
            {
                SetContext(report, expected.relativePath, NotApplicable, NotApplicable);
                if (!seen.Add(expected.relativePath))
                {
                    throw new InvalidDataException(
                        $"Duplicate authorized member: {expected.relativePath}");
                }
                if (Path.IsPathRooted(expected.relativePath) ||
                    expected.relativePath.IndexOf('\\') >= 0)
                {
                    throw new InvalidDataException(
                        $"Authorized member path is not portable: {expected.relativePath}");
                }

                string absolutePath = Path.GetFullPath(Path.Combine(
                    inputRoot,
                    expected.relativePath.Replace('/', Path.DirectorySeparatorChar)));
                if (!IsSameOrDescendant(absolutePath, inputRoot))
                {
                    throw new InvalidDataException(
                        $"Authorized member escapes input root: {expected.relativePath}");
                }

                AssertNoReparsePath(absolutePath, false);
                var fileInfo = new FileInfo(absolutePath);
                var result = new MemberResult
                {
                    relativePath = expected.relativePath,
                    expectedLength = expected.expectedLength,
                    actualLength = fileInfo.Length,
                    expectedSha256 = expected.expectedSha256,
                    status = "Validating"
                };
                report.memberResults.Add(result);

                if (fileInfo.Length != expected.expectedLength)
                {
                    result.status = "LengthMismatch";
                    throw new InvalidDataException(
                        $"Length mismatch for authorized member {expected.relativePath}.");
                }

                string actualSha256 = ComputeSha256(absolutePath);
                result.actualSha256 = actualSha256;
                if (!string.Equals(
                        actualSha256,
                        expected.expectedSha256,
                        StringComparison.Ordinal))
                {
                    result.status = "Sha256Mismatch";
                    throw new InvalidDataException(
                        $"SHA-256 mismatch for authorized member {expected.relativePath}.");
                }

                result.status = "Validated";
                validated.Add(new ValidatedMember
                {
                    relativePath = expected.relativePath,
                    absolutePath = absolutePath
                });
            }
            return validated;
        }

        private static string ComputeSha256(string path)
        {
            using (var stream = new FileStream(
                path, FileMode.Open, FileAccess.Read, FileShare.Read, 1024 * 1024,
                FileOptions.SequentialScan))
            using (SHA256 algorithm = SHA256.Create())
            {
                return ToLowerHex(algorithm.ComputeHash(stream));
            }
        }

        private static string ComputeSha256(byte[] bytes)
        {
            using (SHA256 algorithm = SHA256.Create())
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

        private static List<EffectiveBundle> BuildEffectiveBundles(List<ValidatedMember> members)
        {
            var byLogicalName = new Dictionary<string, EffectiveBundle>(StringComparer.Ordinal);
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

                if (!byLogicalName.TryGetValue(logicalName, out EffectiveBundle existing))
                {
                    byLogicalName.Add(logicalName, candidate);
                    logicalOrder.Add(logicalName);
                }
                else if (priority < existing.priority)
                {
                    byLogicalName[logicalName] = candidate;
                }
            }

            var effective = new List<EffectiveBundle>(logicalOrder.Count);
            var unique = new HashSet<string>(StringComparer.Ordinal);
            foreach (string logicalName in logicalOrder)
            {
                if (!unique.Add(logicalName))
                {
                    throw new InvalidDataException(
                        $"Duplicate effective logical name: {logicalName}");
                }
                effective.Add(byLogicalName[logicalName]);
            }
            if (effective.Count != EffectiveBundleCount)
            {
                throw new InvalidDataException(
                    $"Expected {EffectiveBundleCount} effective bundles, found {effective.Count}.");
            }
            return effective;
        }

        private static void RecordEffectiveBundles(
            List<EffectiveBundle> effective,
            TerminalReport report)
        {
            report.effectiveBundleCount = effective.Count;
            report.shadowedMemberCount = AuthorizedMemberCount - effective.Count;
            foreach (EffectiveBundle descriptor in effective)
            {
                report.effectiveBundles.Add(new EffectiveBundleResult
                {
                    logicalName = descriptor.logicalName,
                    relativePath = descriptor.relativePath,
                    disposition = descriptor.disposition
                });
            }
        }

        private static void LoadEffectiveBundles(
            List<EffectiveBundle> effective,
            List<LoadedBundle> loaded,
            TerminalReport report)
        {
            foreach (EffectiveBundle descriptor in effective)
            {
                SetContext(report, descriptor.relativePath, NotApplicable, NotApplicable);
                var result = new BundleResult
                {
                    logicalName = descriptor.logicalName,
                    relativePath = descriptor.relativePath,
                    disposition = descriptor.disposition,
                    status = "Loading"
                };
                report.bundleResults.Add(result);

                AssetBundle bundle = AssetBundle.LoadFromFile(descriptor.absolutePath);
                if (bundle == null)
                {
                    result.status = "Failed";
                    throw new InvalidDataException(
                        $"Unity returned null for effective bundle {descriptor.relativePath}.");
                }

                string[] assetNames = bundle.GetAllAssetNames();
                Array.Sort(assetNames, StringComparer.Ordinal);
                result.assetCount = assetNames.Length;
                result.status = "Loaded";
                loaded.Add(new LoadedBundle
                {
                    descriptor = descriptor,
                    bundle = bundle,
                    assetNames = assetNames
                });
            }
        }

        private static GameObject InstantiateAndValidateCharacter(
            List<LoadedBundle> bundles,
            List<GameObject> instantiated,
            TerminalReport report)
        {
            GameObject prefab = null;
            LoadedBundle source = null;
            string assetName = null;
            foreach (LoadedBundle candidateBundle in bundles)
            {
                if (!IsCharacterBundle(candidateBundle.descriptor.logicalName))
                {
                    continue;
                }
                foreach (string candidateName in candidateBundle.assetNames)
                {
                    SetContext(
                        report,
                        candidateBundle.descriptor.relativePath,
                        candidateName,
                        NotApplicable);
                    GameObject candidate = candidateBundle.bundle.LoadAsset<GameObject>(candidateName);
                    if (candidate != null &&
                        candidate.GetComponentsInChildren<SkinnedMeshRenderer>(true).Length > 0)
                    {
                        prefab = candidate;
                        source = candidateBundle;
                        assetName = candidateName;
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
                throw new InvalidDataException(
                    "No character prefab with a SkinnedMeshRenderer was found.");
            }

            GameObject instance = UnityEngine.Object.Instantiate(prefab);
            instance.name = prefab.name;
            instance.SetActive(true);
            instantiated.Add(instance);
            SetContext(report, source.descriptor.relativePath, assetName, GetHierarchyPath(instance.transform));

            SkinnedMeshRenderer[] renderers =
                instance.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            var textureIds = new HashSet<int>();
            int meshCount = 0;
            int rootBoneCount = 0;
            int boneCount = 0;
            int materialCount = 0;
            int supportedCharacterShaderCount = 0;
            foreach (SkinnedMeshRenderer renderer in renderers)
            {
                SetContext(
                    report,
                    source.descriptor.relativePath,
                    assetName,
                    GetHierarchyPath(renderer.transform));
                Mesh mesh = renderer.sharedMesh;
                if (mesh == null || mesh.vertexCount <= 0)
                {
                    throw new InvalidDataException("SkinnedMeshRenderer has no usable Mesh.");
                }
                meshCount++;

                if (renderer.rootBone == null)
                {
                    throw new InvalidDataException("SkinnedMeshRenderer rootBone is missing.");
                }
                rootBoneCount++;

                Transform[] bones = renderer.bones;
                if (bones == null || bones.Length == 0)
                {
                    throw new InvalidDataException("SkinnedMeshRenderer bones are missing.");
                }
                foreach (Transform bone in bones)
                {
                    if (bone == null)
                    {
                        throw new InvalidDataException("SkinnedMeshRenderer contains a null bone.");
                    }
                    boneCount++;
                }

                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    throw new InvalidDataException("SkinnedMeshRenderer materials are missing.");
                }
                foreach (Material material in materials)
                {
                    if (material == null)
                    {
                        throw new InvalidDataException("SkinnedMeshRenderer contains a null Material.");
                    }
                    materialCount++;
                    Shader shader = material.shader;
                    if (shader == null)
                    {
                        throw new InvalidDataException("Character Material shader is null.");
                    }
                    if (!shader.isSupported)
                    {
                        throw new InvalidDataException(
                            $"Character Material shader is unsupported: {shader.name}.");
                    }
                    if (string.Equals(
                            shader.name,
                            "Hidden/InternalErrorShader",
                            StringComparison.Ordinal))
                    {
                        throw new InvalidDataException(
                            "Character Material uses Hidden/InternalErrorShader.");
                    }
                    supportedCharacterShaderCount++;
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
            if (textureIds.Count == 0)
            {
                throw new InvalidDataException("Character materials expose no Texture.");
            }

            report.modelBundle = source.descriptor.relativePath;
            report.modelAsset = assetName;
            report.modelObject = SanitizePortableText(GetHierarchyPath(instance.transform), null, null);
            report.skinnedMeshRendererCount = renderers.Length;
            report.meshCount = meshCount;
            report.rootBoneCount = rootBoneCount;
            report.boneCount = boneCount;
            report.materialCount = materialCount;
            report.supportedCharacterShaderCount = supportedCharacterShaderCount;
            report.textureCount = textureIds.Count;
            if (supportedCharacterShaderCount != materialCount)
            {
                throw new InvalidDataException(
                    "Character Material/Shader conservation failed.");
            }
            report.modelConsumerProofPassed = true;
            return instance;
        }

        private static bool IsCharacterBundle(string logicalName)
        {
            return string.Equals(logicalName, "char_14401.unity3d", StringComparison.Ordinal) ||
                   string.Equals(logicalName, "char_14401_models.unity3d", StringComparison.Ordinal);
        }

        private static void SampleBoundAnimation(
            List<LoadedBundle> bundles,
            GameObject character,
            TerminalReport report)
        {
            int evaluated = 0;
            HashSet<Transform> characterBones = CollectCharacterBones(character);
            foreach (LoadedBundle source in bundles)
            {
                foreach (string assetName in source.assetNames)
                {
                    AnimationClip clip = source.bundle.LoadAsset<AnimationClip>(assetName);
                    if (clip == null || clip.length <= 0f)
                    {
                        continue;
                    }
                    evaluated++;
                    SetContext(
                        report,
                        source.descriptor.relativePath,
                        assetName,
                        GetHierarchyPath(character.transform));
                    if (TrySampleBoundAnimation(
                            character,
                            clip,
                            characterBones,
                            out string bindingPath,
                            out float numericChangeMagnitude,
                            out int resolvedBindingCount))
                    {
                        report.animationBundle = source.descriptor.relativePath;
                        report.animationAsset = assetName;
                        report.bindingPath = bindingPath;
                        report.resolvedBindingCount = resolvedBindingCount;
                        report.numericChangeMagnitude = numericChangeMagnitude;
                        report.animationClipEvaluatedCount = evaluated;
                        report.animationConsumerProofPassed = true;
                        SetContext(
                            report,
                            source.descriptor.relativePath,
                            assetName,
                            bindingPath);
                        return;
                    }
                }
            }
            report.animationClipEvaluatedCount = evaluated;
            throw new InvalidDataException(
                "No AnimationClip proved a resolved binding path with finite numeric bone change.");
        }

        private static bool TrySampleBoundAnimation(
            GameObject character,
            AnimationClip clip,
            HashSet<Transform> characterBones,
            out string changedBindingPath,
            out float numericChangeMagnitude,
            out int resolvedBindingCount)
        {
            changedBindingPath = null;
            numericChangeMagnitude = 0f;
            resolvedBindingCount = 0;
            var paths = new List<string>();
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (EditorCurveBinding binding in AnimationUtility.GetCurveBindings(clip))
            {
                if (binding.type == typeof(Transform) && seen.Add(binding.path))
                {
                    paths.Add(binding.path);
                }
            }
            paths.Sort(StringComparer.Ordinal);

            var targets = new List<Transform>();
            var targetPaths = new List<string>();
            foreach (string bindingPath in paths)
            {
                Transform target = string.IsNullOrEmpty(bindingPath)
                    ? character.transform
                    : character.transform.Find(bindingPath);
                if (target != null && characterBones.Contains(target))
                {
                    targets.Add(target);
                    targetPaths.Add(bindingPath);
                }
            }
            resolvedBindingCount = targets.Count;
            if (targets.Count == 0)
            {
                return false;
            }

            clip.SampleAnimation(character, 0f);
            var baseline = new List<TransformState>(targets.Count);
            foreach (Transform target in targets)
            {
                if (!IsFinite(target))
                {
                    throw new InvalidDataException("Animation produced a non-finite baseline transform.");
                }
                baseline.Add(new TransformState(target));
            }

            float sampleTime = clip.length * 0.5f;
            clip.SampleAnimation(character, sampleTime);
            for (int index = 0; index < targets.Count; index++)
            {
                Transform target = targets[index];
                if (!IsFinite(target))
                {
                    throw new InvalidDataException("Animation produced a non-finite sampled transform.");
                }
                float change = baseline[index].Difference(target);
                if (change > numericChangeMagnitude)
                {
                    numericChangeMagnitude = change;
                    changedBindingPath = targetPaths[index];
                }
            }
            return numericChangeMagnitude > 0.00001f;
        }

        private static HashSet<Transform> CollectCharacterBones(GameObject character)
        {
            var characterBones = new HashSet<Transform>();
            foreach (SkinnedMeshRenderer renderer in
                     character.GetComponentsInChildren<SkinnedMeshRenderer>(true))
            {
                if (renderer.rootBone != null)
                {
                    characterBones.Add(renderer.rootBone);
                }
                foreach (Transform bone in renderer.bones)
                {
                    if (bone != null)
                    {
                        characterBones.Add(bone);
                    }
                }
            }
            if (characterBones.Count == 0)
            {
                throw new InvalidDataException(
                    "Instantiated character exposes no animation bone set.");
            }
            return characterBones;
        }

        private static GameObject InstantiateAndValidateAttackFx(
            List<LoadedBundle> bundles,
            GameObject character,
            List<GameObject> instantiated,
            TerminalReport report)
        {
            foreach (LoadedBundle source in bundles)
            {
                if (!string.Equals(
                        source.descriptor.logicalName,
                        "char_14401_fx.unity3d",
                        StringComparison.Ordinal))
                {
                    continue;
                }
                foreach (string assetName in source.assetNames)
                {
                    GameObject prefab = source.bundle.LoadAsset<GameObject>(assetName);
                    if (prefab == null ||
                        !ContainsAttackToken(assetName + "/" + prefab.name))
                    {
                        continue;
                    }

                    SetContext(
                        report,
                        source.descriptor.relativePath,
                        assetName,
                        prefab.name);
                    GameObject instance = UnityEngine.Object.Instantiate(prefab);
                    instance.name = prefab.name;
                    instance.SetActive(true);
                    instance.transform.position = CalculateBounds(character).center;
                    instantiated.Add(instance);

                    ParticleSystem[] particleSystems =
                        instance.GetComponentsInChildren<ParticleSystem>(true);
                    Renderer[] renderers = instance.GetComponentsInChildren<Renderer>(true);
                    if (particleSystems.Length == 0 || renderers.Length == 0)
                    {
                        instantiated.Remove(instance);
                        UnityEngine.Object.DestroyImmediate(instance);
                        continue;
                    }
                    for (int index = 0; index < particleSystems.Length; index++)
                    {
                        ParticleSystem particleSystem = particleSystems[index];
                        particleSystem.useAutoRandomSeed = false;
                        particleSystem.randomSeed = (uint)(1440100 + index);
                        particleSystem.Simulate(1f, true, true, true);
                    }

                    int liveParticleCount = 0;
                    foreach (ParticleSystem particleSystem in particleSystems)
                    {
                        liveParticleCount += particleSystem.particleCount;
                    }

                    int activeFxRendererCount = 0;
                    int validFxMaterialCount = 0;
                    int supportedFxShaderCount = 0;
                    int finiteNonZeroFxBoundsCount = 0;
                    int qualifyingFxRendererCount = 0;
                    foreach (ParticleSystem particleSystem in particleSystems)
                    {
                        int particleCount = particleSystem.particleCount;
                        if (particleCount <= 0)
                        {
                            continue;
                        }
                        ParticleSystemRenderer renderer =
                            particleSystem.GetComponent<ParticleSystemRenderer>();
                        if (renderer == null)
                        {
                            continue;
                        }
                        if (!renderer.enabled || !renderer.gameObject.activeInHierarchy)
                        {
                            continue;
                        }
                        activeFxRendererCount++;

                        bool finiteNonZeroBounds =
                            IsFinite(renderer.bounds) &&
                            renderer.bounds.size.sqrMagnitude > 0.00000001f;
                        if (finiteNonZeroBounds)
                        {
                            finiteNonZeroFxBoundsCount++;
                        }

                        bool hasSupportedMaterial = false;
                        foreach (Material material in renderer.sharedMaterials)
                        {
                            if (material == null)
                            {
                                continue;
                            }
                            validFxMaterialCount++;
                            Shader shader = material.shader;
                            if (shader != null && shader.isSupported)
                            {
                                supportedFxShaderCount++;
                                hasSupportedMaterial = true;
                            }
                        }
                        if (finiteNonZeroBounds && hasSupportedMaterial)
                        {
                            qualifyingFxRendererCount++;
                        }
                    }

                    report.battleFxBundle = source.descriptor.relativePath;
                    report.battleFxAsset = assetName;
                    report.battleFxObject =
                        SanitizePortableText(GetHierarchyPath(instance.transform), null, null);
                    report.particleSystemCount = particleSystems.Length;
                    report.liveParticleCount = liveParticleCount;
                    report.fxRendererCount = renderers.Length;
                    report.activeFxRendererCount = activeFxRendererCount;
                    report.validFxMaterialCount = validFxMaterialCount;
                    report.supportedFxShaderCount = supportedFxShaderCount;
                    report.finiteNonZeroFxBoundsCount = finiteNonZeroFxBoundsCount;
                    report.qualifyingFxRendererCount = qualifyingFxRendererCount;
                    if (liveParticleCount <= 0)
                    {
                        instantiated.Remove(instance);
                        UnityEngine.Object.DestroyImmediate(instance);
                        continue;
                    }
                    if (qualifyingFxRendererCount <= 0)
                    {
                        instantiated.Remove(instance);
                        UnityEngine.Object.DestroyImmediate(instance);
                        continue;
                    }
                    report.battleFxConsumerProofPassed = true;
                    SetContext(
                        report,
                        source.descriptor.relativePath,
                        assetName,
                        GetHierarchyPath(instance.transform));
                    return instance;
                }
            }
            throw new InvalidDataException(
                "No explicit attack FX prefab with ParticleSystem and Renderer was found.");
        }

        private static bool ContainsAttackToken(string value)
        {
            foreach (string token in attackTokens)
            {
                if (value.IndexOf(token, StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    return true;
                }
            }
            return false;
        }

        private static void CaptureDeterministicScreenshot(
            GameObject character,
            GameObject attackFx,
            string outputRoot,
            List<GameObject> instantiated,
            TerminalReport report)
        {
            var cameraObject = new GameObject("UDCP-Camera");
            var lightObject = new GameObject("UDCP-KeyLight");
            instantiated.Add(cameraObject);
            instantiated.Add(lightObject);
            Camera camera = cameraObject.AddComponent<Camera>();
            Light light = lightObject.AddComponent<Light>();
            SetLayerRecursively(character, CharacterProofLayer);
            SetLayerRecursively(attackFx, FxProofLayer);
            cameraObject.layer = CharacterProofLayer;
            lightObject.layer = CharacterProofLayer;

            Bounds bounds = CalculateBounds(character);
            EncapsulateRenderers(attackFx, ref bounds);
            float radius = Mathf.Max(1f, bounds.extents.magnitude);
            camera.clearFlags = CameraClearFlags.SolidColor;
            camera.backgroundColor = new Color(0.08f, 0.08f, 0.10f, 1f);
            camera.allowHDR = false;
            camera.allowMSAA = false;
            camera.cullingMask = 0;
            camera.fieldOfView = 30f;
            camera.nearClipPlane = 0.01f;
            camera.farClipPlane = radius * 20f;
            camera.transform.position =
                bounds.center + new Vector3(radius * 0.45f, radius * 0.25f, -radius * 4f);
            camera.transform.LookAt(bounds.center, Vector3.up);

            light.type = LightType.Directional;
            light.color = Color.white;
            light.intensity = 1f;
            light.cullingMask = 0;
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

                int characterMask = 1 << CharacterProofLayer;
                int fxMask = 1 << FxProofLayer;
                Color32[] baselinePixels =
                    RenderPixels(camera, light, pixels, 0);
                Color32[] characterPixels =
                    RenderPixels(camera, light, pixels, characterMask);
                Color32[] fxPixels =
                    RenderPixels(camera, light, pixels, fxMask);
                Color32[] compositePixels =
                    RenderPixels(camera, light, pixels, characterMask | fxMask);

                VisibilityMetrics characterVisibility =
                    AnalyzeVisibility(baselinePixels, characterPixels);
                VisibilityMetrics fxVisibility =
                    AnalyzeVisibility(baselinePixels, fxPixels);
                VisibilityMetrics compositeVisibility =
                    AnalyzeVisibility(baselinePixels, compositePixels);
                report.characterForegroundPixelCount =
                    characterVisibility.foregroundPixelCount;
                report.characterBrightnessRange =
                    characterVisibility.brightnessRange;
                report.characterDistinctColorCount =
                    characterVisibility.distinctColorCount;
                report.fxForegroundPixelCount = fxVisibility.foregroundPixelCount;
                report.fxBrightnessRange = fxVisibility.brightnessRange;
                report.fxDistinctColorCount = fxVisibility.distinctColorCount;
                report.compositeForegroundPixelCount =
                    compositeVisibility.foregroundPixelCount;
                report.compositeBrightnessRange =
                    compositeVisibility.brightnessRange;
                report.compositeDistinctColorCount =
                    compositeVisibility.distinctColorCount;

                RequireVisibility("character-only", characterVisibility);
                RequireVisibility("FX-only", fxVisibility);
                RequireVisibility("composite", compositeVisibility);

                byte[] png = pixels.EncodeToPNG();
                if (png == null || png.Length == 0)
                {
                    throw new InvalidDataException("Composite screenshot PNG is empty.");
                }
                WriteBytesCreateNew(outputRoot, ScreenshotFileName, png);
                report.screenshotRelativePath = ScreenshotFileName;
                report.screenshotWidth = ScreenshotWidth;
                report.screenshotHeight = ScreenshotHeight;
                report.screenshotByteCount = png.LongLength;
                report.screenshotSha256 = ComputeSha256(png);
                report.screenshotProofPassed = true;
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
            }
        }

        private static Color32[] RenderPixels(
            Camera camera,
            Light light,
            Texture2D pixels,
            int cullingMask)
        {
            camera.cullingMask = cullingMask;
            light.cullingMask = cullingMask;
            camera.Render();
            pixels.ReadPixels(
                new Rect(0, 0, ScreenshotWidth, ScreenshotHeight),
                0,
                0,
                false);
            pixels.Apply(false, false);
            return pixels.GetPixels32();
        }

        private static VisibilityMetrics AnalyzeVisibility(
            Color32[] baselinePixels,
            Color32[] renderedPixels)
        {
            if (baselinePixels == null ||
                renderedPixels == null ||
                baselinePixels.Length != renderedPixels.Length)
            {
                throw new InvalidDataException("Visibility pixel accounting mismatch.");
            }

            int foregroundPixelCount = 0;
            int minimumBrightness = 255;
            int maximumBrightness = 0;
            var distinctColors = new HashSet<int>();
            for (int index = 0; index < renderedPixels.Length; index++)
            {
                Color32 baseline = baselinePixels[index];
                Color32 rendered = renderedPixels[index];
                int redDifference = rendered.r - baseline.r;
                int greenDifference = rendered.g - baseline.g;
                int blueDifference = rendered.b - baseline.b;
                int differenceSquared =
                    (redDifference * redDifference) +
                    (greenDifference * greenDifference) +
                    (blueDifference * blueDifference);
                if (differenceSquared <= ForegroundDifferenceSquared)
                {
                    continue;
                }

                foregroundPixelCount++;
                int brightness =
                    ((77 * rendered.r) + (150 * rendered.g) + (29 * rendered.b)) >> 8;
                minimumBrightness = Math.Min(minimumBrightness, brightness);
                maximumBrightness = Math.Max(maximumBrightness, brightness);
                int colorBin =
                    ((rendered.r >> 4) << 8) |
                    ((rendered.g >> 4) << 4) |
                    (rendered.b >> 4);
                distinctColors.Add(colorBin);
            }

            return new VisibilityMetrics
            {
                foregroundPixelCount = foregroundPixelCount,
                brightnessRange = foregroundPixelCount == 0
                    ? 0
                    : maximumBrightness - minimumBrightness,
                distinctColorCount = distinctColors.Count
            };
        }

        private static void RequireVisibility(
            string evidenceName,
            VisibilityMetrics metrics)
        {
            if (metrics.foregroundPixelCount < MinimumForegroundPixels)
            {
                throw new InvalidDataException(
                    $"{evidenceName} foreground pixel count is below the fixed threshold.");
            }
            if (metrics.brightnessRange < MinimumBrightnessRange)
            {
                throw new InvalidDataException(
                    $"{evidenceName} brightness variation is below the fixed threshold.");
            }
            if (metrics.distinctColorCount < MinimumDistinctColorBins)
            {
                throw new InvalidDataException(
                    $"{evidenceName} color variation is below the fixed threshold.");
            }
        }

        private static Bounds CalculateBounds(GameObject root)
        {
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0)
            {
                throw new InvalidDataException("Instantiated object has no Renderer bounds.");
            }
            Bounds bounds = renderers[0].bounds;
            for (int index = 1; index < renderers.Length; index++)
            {
                bounds.Encapsulate(renderers[index].bounds);
            }
            return bounds;
        }

        private static void EncapsulateRenderers(GameObject root, ref Bounds bounds)
        {
            foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
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

        private static void Cleanup(
            TerminalReport report,
            List<GameObject> instantiated,
            List<LoadedBundle> loadedBundles,
            string inputRoot,
            string outputRoot,
            ref int exitCode)
        {
            report.stage = "Cleanup";
            BeginStage(report, report.stage);
            try
            {
                for (int index = instantiated.Count - 1; index >= 0; index--)
                {
                    if (instantiated[index] != null)
                    {
                        UnityEngine.Object.DestroyImmediate(instantiated[index]);
                    }
                }
                for (int index = loadedBundles.Count - 1; index >= 0; index--)
                {
                    if (loadedBundles[index].bundle != null)
                    {
                        loadedBundles[index].bundle.Unload(true);
                    }
                }
                CompleteStage(report);
            }
            catch (Exception exception)
            {
                CaptureFailure(report, exception, inputRoot, outputRoot);
                exitCode = 2;
            }
        }

        private static void WriteTerminalAndExit(
            TerminalReport report,
            string inputRoot,
            string outputRoot,
            int exitCode)
        {
            report.stage = "TerminalWrite";
            BeginStage(report, report.stage);
            report.exitCode = exitCode;
            try
            {
                if (string.IsNullOrEmpty(outputRoot))
                {
                    throw new InvalidOperationException("A safe output root was not established.");
                }

                CompleteStage(report);
                string terminalJson = JsonUtility.ToJson(report, true);
                WriteBytesCreateNew(
                    outputRoot,
                    TerminalFileName,
                    new UTF8Encoding(false, true).GetBytes(terminalJson));
            }
            catch (Exception exception)
            {
                exitCode = 3;
                report.exitCode = exitCode;
                CaptureFailure(report, exception, inputRoot, outputRoot);
                Debug.LogError(JsonUtility.ToJson(report, true));
            }
            EditorApplication.Exit(exitCode);
        }

        private static void WriteBytesCreateNew(
            string outputRoot,
            string fileName,
            byte[] bytes)
        {
            string outputPath = GetOutputPath(outputRoot, fileName);
            using (var stream = new FileStream(
                outputPath, FileMode.CreateNew, FileAccess.Write, FileShare.None))
            {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
            }
        }

        private static string GetOutputPath(string outputRoot, string fileName)
        {
            string outputPath = Path.GetFullPath(Path.Combine(outputRoot, fileName));
            if (!IsSameOrDescendant(outputPath, outputRoot))
            {
                throw new InvalidOperationException("Evidence path escapes output root.");
            }
            return outputPath;
        }

        private static void SetContext(
            TerminalReport report,
            string bundle,
            string asset,
            string objectPath)
        {
            report.contextBundle = bundle ?? NotApplicable;
            report.contextAsset = SanitizePortableText(asset, null, null) ?? NotApplicable;
            report.contextObject = SanitizePortableText(objectPath, null, null) ?? NotApplicable;
        }

        private static void CaptureFailure(
            TerminalReport report,
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
            report.exceptionMessage =
                SanitizePortableText(exception.Message, inputRoot, outputRoot);
            report.exceptionStack =
                SanitizePortableText(exception.StackTrace, inputRoot, outputRoot);
            FailCurrentStage(report, exception, inputRoot, outputRoot);
        }

        private static void BeginStage(TerminalReport report, string stage)
        {
            report.stageResults.Add(new StageResult
            {
                stage = stage,
                status = "Running"
            });
        }

        private static void CompleteStage(TerminalReport report)
        {
            report.stageResults[report.stageResults.Count - 1].status = "Succeeded";
        }

        private static void FailCurrentStage(
            TerminalReport report,
            Exception exception,
            string inputRoot,
            string outputRoot)
        {
            if (report.stageResults.Count == 0)
            {
                return;
            }
            StageResult stage = report.stageResults[report.stageResults.Count - 1];
            stage.status = "Failed";
            stage.exceptionType = exception.GetType().FullName;
            stage.exceptionMessage =
                SanitizePortableText(exception.Message, inputRoot, outputRoot);
            stage.exceptionStack =
                SanitizePortableText(exception.StackTrace, inputRoot, outputRoot);
        }

        private static bool IsFinite(Transform transform)
        {
            return IsFinite(transform.localPosition) &&
                   IsFinite(transform.localRotation) &&
                   IsFinite(transform.localScale);
        }

        private static bool IsFinite(Vector3 value)
        {
            return IsFinite(value.x) && IsFinite(value.y) && IsFinite(value.z);
        }

        private static bool IsFinite(Quaternion value)
        {
            return IsFinite(value.x) && IsFinite(value.y) &&
                   IsFinite(value.z) && IsFinite(value.w);
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

        private static void AssertSeparatedRoots(string inputRoot, string outputRoot)
        {
            if (PathsEqual(inputRoot, outputRoot) ||
                IsSameOrDescendant(inputRoot, outputRoot) ||
                IsSameOrDescendant(outputRoot, inputRoot))
            {
                throw new InvalidOperationException("Input and output roots must be disjoint.");
            }
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

        private static bool PathsEqual(string left, string right)
        {
            return string.Equals(
                NormalizeDirectoryPath(left),
                NormalizeDirectoryPath(right),
                StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsSameOrDescendant(string candidate, string ancestor)
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

        private static string NormalizeDirectoryPath(string path)
        {
            string fullPath = Path.GetFullPath(path);
            string root = Path.GetPathRoot(fullPath);
            if (!string.Equals(fullPath, root, StringComparison.OrdinalIgnoreCase))
            {
                fullPath = fullPath.TrimEnd(
                    Path.DirectorySeparatorChar,
                    Path.AltDirectorySeparatorChar);
            }
            return fullPath;
        }

        private static void AssertExistingAncestorsNoReparse(string fullPath)
        {
            string root = Path.GetPathRoot(fullPath);
            if (string.IsNullOrEmpty(root))
            {
                throw new InvalidOperationException("Path has no local volume root.");
            }

            string cursor = root;
            AssertExistingEntryNoReparse(cursor);
            string remainder = fullPath.Substring(root.Length);
            string[] parts = remainder.Split(
                new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar },
                StringSplitOptions.RemoveEmptyEntries);
            foreach (string part in parts)
            {
                cursor = Path.Combine(cursor, part);
                if (!Directory.Exists(cursor) && !File.Exists(cursor))
                {
                    break;
                }
                AssertExistingEntryNoReparse(cursor);
            }
        }

        private static void AssertNoReparsePath(string fullPath, bool expectDirectory)
        {
            AssertExistingAncestorsNoReparse(fullPath);
            if (expectDirectory && !Directory.Exists(fullPath))
            {
                throw new DirectoryNotFoundException("Expected directory does not exist.");
            }
            if (!expectDirectory && !File.Exists(fullPath))
            {
                throw new FileNotFoundException("Expected file does not exist.");
            }
            AssertExistingEntryNoReparse(fullPath);
        }

        private static void AssertExistingEntryNoReparse(string path)
        {
            FileAttributes attributes = File.GetAttributes(path);
            if ((attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException("Reparse path component is forbidden.");
            }
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
            for (int index = 0; index < lines.Length; index++)
            {
                int absoluteIndex = FindAbsolutePathStart(lines[index]);
                if (absoluteIndex >= 0)
                {
                    lines[index] =
                        lines[index].Substring(0, absoluteIndex) + "<ABSOLUTE_PATH>";
                }
            }
            return string.Join("\n", lines);
        }

        private static int FindAbsolutePathStart(string value)
        {
            for (int index = 0; index + 2 < value.Length; index++)
            {
                if (char.IsLetter(value[index]) &&
                    value[index + 1] == ':' &&
                    IsDirectorySeparator(value[index + 2]))
                {
                    return index;
                }
                if (IsDirectorySeparator(value[index]) &&
                    IsDirectorySeparator(value[index + 1]))
                {
                    return index;
                }
            }
            return -1;
        }

        private sealed class AuthorizedMember
        {
            public AuthorizedMember(string relativePath, long expectedLength, string expectedSha256)
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
            public string[] assetNames;
        }

        private sealed class TransformState
        {
            private readonly Vector3 position;
            private readonly Quaternion rotation;
            private readonly Vector3 scale;

            public TransformState(Transform transform)
            {
                position = transform.localPosition;
                rotation = transform.localRotation;
                scale = transform.localScale;
            }

            public float Difference(Transform transform)
            {
                return Mathf.Max(
                    Vector3.Distance(position, transform.localPosition),
                    Quaternion.Angle(rotation, transform.localRotation),
                    Vector3.Distance(scale, transform.localScale));
            }
        }

        private sealed class VisibilityMetrics
        {
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
        }

        private enum ValidationMode
        {
            Smoke,
            Full
        }

        [Serializable]
        private sealed class TerminalReport
        {
            public string schemaVersion;
            public string validationMode;
            public string stage;
            public string status;
            public string unityVersion;
            public string expectedInputRelativePath;
            public int authorizedMemberCount;
            public int effectiveBundleCount;
            public int shadowedMemberCount;
            public List<MemberResult> memberResults;
            public List<EffectiveBundleResult> effectiveBundles;
            public List<BundleResult> bundleResults;
            public List<StageResult> stageResults;

            public bool modelConsumerProofPassed;
            public string modelBundle;
            public string modelAsset;
            public string modelObject;
            public int skinnedMeshRendererCount;
            public int meshCount;
            public int rootBoneCount;
            public int boneCount;
            public int materialCount;
            public int supportedCharacterShaderCount;
            public int textureCount;

            public bool animationConsumerProofPassed;
            public string animationBundle;
            public string animationAsset;
            public string bindingPath;
            public int resolvedBindingCount;
            public int animationClipEvaluatedCount;
            public float numericChangeMagnitude;

            public bool battleFxConsumerProofPassed;
            public string battleFxBundle;
            public string battleFxAsset;
            public string battleFxObject;
            public int particleSystemCount;
            public int liveParticleCount;
            public int fxRendererCount;
            public int activeFxRendererCount;
            public int validFxMaterialCount;
            public int supportedFxShaderCount;
            public int finiteNonZeroFxBoundsCount;
            public int qualifyingFxRendererCount;

            public bool screenshotProofPassed;
            public string screenshotRelativePath;
            public int screenshotWidth;
            public int screenshotHeight;
            public long screenshotByteCount;
            public string screenshotSha256;
            public int characterForegroundPixelCount;
            public int characterBrightnessRange;
            public int characterDistinctColorCount;
            public int fxForegroundPixelCount;
            public int fxBrightnessRange;
            public int fxDistinctColorCount;
            public int compositeForegroundPixelCount;
            public int compositeBrightnessRange;
            public int compositeDistinctColorCount;

            public int discoveredAnimationCount;
            public int totalAnimationClipCount;
            public int inScopeAnimationCount;
            public int outOfScopeAnimationCount;
            public int animationUniverseBundleCount;
            public string animationUniverseBundle;
            public int ineligibleAnimationCount;
            public int eligibleAnimationCount;
            public int passedAnimationCount;
            public int failedAnimationCount;
            public int eligibleAttackAnimationCount;
            public List<AnimationValidationResult> animationResults;

            public int discoveredFxCount;
            public int ineligibleFxCount;
            public int eligibleFxCount;
            public int passedFxCount;
            public int failedFxCount;
            public int eligibleAttackFxCount;
            public int passedAttackFxCount;
            public int failedAttackFxCount;
            public List<FxValidationResult> fxResults;
            public string attackCombinationRelativePath;
            public long attackCombinationByteCount;
            public string attackCombinationSha256;

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
            public long expectedLength;
            public long actualLength;
            public string expectedSha256;
            public string actualSha256;
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
            public string disposition;
            public string status;
            public int assetCount;
        }

        [Serializable]
        private sealed class StageResult
        {
            public string stage;
            public string status;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
        }
    }
}
