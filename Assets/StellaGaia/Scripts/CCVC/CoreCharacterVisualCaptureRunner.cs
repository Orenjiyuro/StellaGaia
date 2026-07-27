using System;
using System.Collections.Generic;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace StellaGaia.CCVC
{
    public static class CoreCharacterVisualCaptureRunner
    {
        private const string RequiredUnityVersion = "2022.3.62f2";
        private const string InputVariable = "STELLAGAIA_CCVC_PLAYER_INPUT_ROOT";
        private const string OutputVariable = "STELLAGAIA_CCVC_PLAYER_OUTPUT_ROOT";
        private const string ExpectedInputSuffix =
            "Extracted/DirectCharacterConsumerProof/char_14401/LO-DCP1-A02/Input";
        private const string TerminalFileName = "terminal-result.json";
        private const int Width = 512;
        private const int Height = 512;
        private const int CharacterLayer = 30;
        private const float MotionEpsilon = 0.00001f;

        private static readonly AuthorizedMember[] AuthorizedMembers =
        {
            new AuthorizedMember(
                "xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d",
                4909859L,
                "cbd84ffa6353fa7a8a8babfb133aa9bc38af245d98cb7bcabf7c78a520911ddd"),
            new AuthorizedMember(
                "xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d",
                6682L,
                "8b31e52dc4307aecc0c40b7c054f2dc653cfb776cdc2e05d41022aa55db2c9bb"),
            new AuthorizedMember(
                "Persistent_Store/AssetBundles/char_14401_models.unity3d",
                3080984L,
                "66545d7be64e115dbc7f24071c9531e1154bbff80bbad24db4cba25f3f712fb7"),
            new AuthorizedMember(
                "Persistent_Store/AssetBundles/char_14401_animations.unity3d",
                37819874L,
                "8e51afa19518df92ced48eca91263e9214840e42d41f817688eb047a2301325d")
        };

        private static readonly string[] DeniedBundlePaths =
        {
            "Persistent_Store/AssetBundles/char_14401_fx.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d"
        };

        private static readonly float[] SampleFractions =
            { 0.0f, 0.25f, 0.50f, 0.75f, 1.0f };

        private static readonly string[] ExpectedAnimationNames =
        {
            "144_Attack",
            "144_Attack_1",
            "144_Attack_1_Shadow",
            "144_Attack_2",
            "144_Attack_2_Shadow",
            "144_Attack_3",
            "144_Attack_3_Hide",
            "144_Attack_3_Shadow",
            "144_Attack_4",
            "144_Attack_4_Shadow",
            "144_Attack_5",
            "144_Attack_5_Shadow",
            "144_Attack_6",
            "144_Attack_6_Shadow",
            "144_B1_Shadow",
            "144_B1_Shadow_0",
            "144_B1_Skill",
            "144_B1_Skill_2",
            "144_B2_Attack",
            "144_B2_Attack_2",
            "144_B2_Connect",
            "144_B2_Idle",
            "144_B2_Start",
            "144_Daze",
            "144_Die",
            "144_Dodge",
            "144_Hide",
            "144_HurtA1",
            "144_HurtA2",
            "144_HurtB",
            "144_Idle",
            "144_Out01",
            "144_Ready",
            "144_ReadyLoop",
            "144_Run",
            "144_Rush",
            "144_RushStop",
            "144_Snake_Attack_1",
            "144_Snake_Attack_2",
            "144_Snake_Attack_3",
            "144_Snake_Attack_3a",
            "144_Snake_Attack_4",
            "144_Snake_Attack_5",
            "144_Snake_Attack_6",
            "144_Snake_B1",
            "144_Snake_B1_0",
            "144_Snake_Ultra",
            "144_Ultra_01",
            "144_Ultra_02",
            "144_Ultra_03",
            "144_Ultra_04",
            "144_Ultra_05",
            "144_Ultra_06",
            "144_Ultra_07",
            "144_Ultra_End",
            "144_Ultra_NoTL",
            "144_Ultra_Start",
            "144_Ultra_TL",
            "144_Victory",
            "144_VictoryLoop",
            "144_Walk"
        };
        private static bool hasRun;
        private static string suppressionFailure;

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.BeforeSceneLoad)]
        private static void SuppressHistoricalRunners()
        {
            foreach (string typeName in new[]
            {
                "StellaGaia.UDCP.DirectCharacterPlayerProofRunner, Assembly-CSharp",
                "StellaGaia.VASP.VisualAssetSubsetProofRunner, Assembly-CSharp"
            })
            {
                try
                {
                    Type type = Type.GetType(typeName, false);
                    var field = type == null ? null : type.GetField(
                        "hasRun",
                        System.Reflection.BindingFlags.NonPublic |
                        System.Reflection.BindingFlags.Static);
                    if (field == null || field.FieldType != typeof(bool))
                    {
                        throw new InvalidOperationException(
                            "Historical runner gate is unavailable.");
                    }
                    field.SetValue(null, true);
                }
                catch (Exception exception)
                {
                    suppressionFailure =
                        exception.GetType().FullName + ": " + exception.Message;
                    return;
                }
            }
        }

        [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
        private static void AutoRun()
        {
            if (hasRun)
            {
                return;
            }
            hasRun = true;
            Run();
        }

        private static void Run()
        {
            var report = CreateReport();
            var bundles = new List<LoadedBundle>();
            var objects = new List<GameObject>();
            string inputRoot = null;
            string outputRoot = null;
            int exitCode = 1;
            try
            {
                report.stage = "PathGate";
                inputRoot = ResolveInputRoot();
                outputRoot = ResolveOutputRoot(inputRoot);
                PrepareOutput(outputRoot);
                if (!string.IsNullOrEmpty(suppressionFailure))
                {
                    throw new InvalidOperationException(suppressionFailure);
                }

                report.stage = "InputIdentity";
                ValidateMembers(inputRoot, report);
                report.stage = "BundleLoad";
                LoadCoreBundles(inputRoot, bundles, report);
                report.stage = "CharacterInstantiate";
                GameObject character =
                    InstantiateCharacter(bundles, objects, report);
                report.stage = "CharacterStructure";
                ValidateCharacter(character, report);
                report.stage = "AnimationValidation";
                ValidateAnimations(
                    bundles,
                    character,
                    outputRoot,
                    objects,
                    report);

                if (!(report.modelStructurePassed &&
                      report.materialShaderPassed &&
                      report.animationValidationPassed &&
                      report.captureValidationPassed))
                {
                    throw new InvalidDataException(
                        "Core visual machine gates did not all pass.");
                }
                report.status = "Passed";
                report.stage = "Completed";
                report.exitCode = 0;
                report.nextAction = "AwaitHumanVisualAcceptance";
                exitCode = 0;
            }
            catch (Exception exception)
            {
                report.status = "Failed";
                report.failureStage = report.stage;
                report.exceptionType = exception.GetType().FullName;
                report.exceptionMessage = Sanitize(exception.Message);
                report.exceptionStack = Sanitize(exception.StackTrace);
                report.exitCode = 1;
                report.nextAction = "CoreVisualFailed";
            }
            finally
            {
                for (int i = objects.Count - 1; i >= 0; i--)
                {
                    if (objects[i] != null)
                    {
                        UnityEngine.Object.DestroyImmediate(objects[i]);
                    }
                }
                for (int i = bundles.Count - 1; i >= 0; i--)
                {
                    if (bundles[i].bundle != null)
                    {
                        bundles[i].bundle.Unload(true);
                    }
                }
                WriteTerminal(report, outputRoot, ref exitCode);
                Application.Quit(exitCode);
            }
        }

        private static Report CreateReport()
        {
            return new Report
            {
                schemaVersion = "ccvc-player-capture/1.0.0",
                artifactId = "CCVC-LO1-PLAYER",
                status = "Running",
                stage = "Initialize",
                unityVersion = Application.unityVersion,
                requiredUnityVersion = RequiredUnityVersion,
                authorizedInputCount = AuthorizedMembers.Length,
                deniedBundleCount = DeniedBundlePaths.Length,
                inputResults = new List<InputResult>(),
                bundleResults = new List<BundleResult>(),
                rendererResults = new List<RendererResult>(),
                animationResults = new List<AnimationResult>(),
                captures = new List<CaptureResult>(),
                exitCode = 1,
                nextAction = "CoreVisualFailed"
            };
        }

        private static string ResolveInputRoot()
        {
            string value = Environment.GetEnvironmentVariable(InputVariable);
            if (string.IsNullOrWhiteSpace(value) || !Path.IsPathRooted(value) ||
                IsNetworkPath(value))
            {
                throw new InvalidDataException("CCVC input root is invalid.");
            }
            string full = NormalizeDirectory(value);
            string suffix = ExpectedInputSuffix.Replace(
                '/', Path.DirectorySeparatorChar);
            if (!full.EndsWith(
                    suffix,
                    StringComparison.OrdinalIgnoreCase) ||
                !Directory.Exists(full))
            {
                throw new InvalidDataException(
                    "CCVC input root binding is invalid.");
            }
            AssertExistingAncestorsNoReparse(full);
            AssertNoReparse(full, true);
            return full;
        }

        private static string ResolveOutputRoot(string inputRoot)
        {
            string value = Environment.GetEnvironmentVariable(OutputVariable);
            if (string.IsNullOrWhiteSpace(value) || !Path.IsPathRooted(value) ||
                IsNetworkPath(value))
            {
                throw new InvalidDataException("CCVC output root is invalid.");
            }
            string full = NormalizeDirectory(value);
            if (PathsEqual(full, inputRoot) ||
                IsSameOrDescendant(full, inputRoot) ||
                IsSameOrDescendant(inputRoot, full))
            {
                throw new InvalidDataException(
                    "CCVC input and output roots overlap.");
            }
            AssertExistingAncestorsNoReparse(full);
            if (!Directory.Exists(full))
            {
                throw new DirectoryNotFoundException(
                    "Authorized Player output root does not exist.");
            }
            AssertNoReparse(full, true);
            return full;
        }

        private static void PrepareOutput(string outputRoot)
        {
            if (Directory.GetFileSystemEntries(outputRoot).Length != 1 ||
                !File.Exists(Path.Combine(outputRoot, "player.log")))
            {
                throw new IOException(
                    "Player output root is not in its initial state.");
            }
            AssertNew(Path.Combine(outputRoot, TerminalFileName));
            foreach (string name in CaptureNames())
            {
                AssertNew(Path.Combine(outputRoot, name));
            }
        }

        private static void ValidateMembers(string inputRoot, Report report)
        {
            if (!string.Equals(
                    Application.unityVersion,
                    RequiredUnityVersion,
                    StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    "Unity version identity mismatch.");
            }
            var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            long total = 0;
            foreach (AuthorizedMember member in AuthorizedMembers)
            {
                if (!seen.Add(member.relativePath))
                {
                    throw new InvalidDataException(
                        "Duplicate core input selector.");
                }
                foreach (string denied in DeniedBundlePaths)
                {
                    if (string.Equals(
                            member.relativePath,
                            denied,
                            StringComparison.OrdinalIgnoreCase))
                    {
                        throw new InvalidDataException(
                            "Denied FX input entered the core set.");
                    }
                }
                string path = ResolveMember(inputRoot, member.relativePath);
                var info = new FileInfo(path);
                if (!info.Exists ||
                    (info.Attributes & FileAttributes.ReparsePoint) != 0 ||
                    info.Length != member.length)
                {
                    throw new InvalidDataException(
                        "Core input metadata identity mismatch.");
                }
                string sha = ComputeSha256(path);
                if (!string.Equals(
                        sha,
                        member.sha256,
                        StringComparison.Ordinal))
                {
                    throw new InvalidDataException(
                        "Core input content identity mismatch.");
                }
                total += info.Length;
                report.inputResults.Add(new InputResult
                {
                    relativePath = member.relativePath,
                    length = info.Length,
                    sha256 = sha,
                    status = "Matched"
                });
            }
            report.inputBytes = total;
        }

        private static void LoadCoreBundles(
            string inputRoot,
            List<LoadedBundle> bundles,
            Report report)
        {
            for (int index = 0; index < AuthorizedMembers.Length; index++)
            {
                AuthorizedMember member = AuthorizedMembers[index];
                string path = ResolveMember(inputRoot, member.relativePath);
                AssetBundle bundle = AssetBundle.LoadFromFile(path);
                if (bundle == null)
                {
                    throw new InvalidDataException(
                        "Core AssetBundle.LoadFromFile returned null: " +
                        member.relativePath);
                }
                string[] names = bundle.GetAllAssetNames();
                Array.Sort(names, StringComparer.Ordinal);
                bundles.Add(new LoadedBundle(member.relativePath, bundle));
                report.bundleResults.Add(new BundleResult
                {
                    relativePath = member.relativePath,
                    loadOrdinal = index + 1,
                    assetCount = names.Length,
                    assetNames = names,
                    status = "Loaded"
                });
            }
            report.loadedBundleCount = bundles.Count;
        }

        private static GameObject InstantiateCharacter(
            List<LoadedBundle> bundles,
            List<GameObject> objects,
            Report report)
        {
            LoadedBundle modelBundle = FindBundle(
                bundles,
                "char_14401_models.unity3d");
            GameObject[] prefabs = modelBundle.bundle.LoadAllAssets<GameObject>();
            Array.Sort(prefabs, CompareObjects);
            GameObject selected = null;
            int bestCount = -1;
            bool ambiguous = false;
            foreach (GameObject prefab in prefabs)
            {
                int count = prefab.GetComponentsInChildren<SkinnedMeshRenderer>(
                    true).Length;
                if (count > bestCount)
                {
                    selected = prefab;
                    bestCount = count;
                    ambiguous = false;
                }
                else if (count == bestCount && count > 0)
                {
                    ambiguous = true;
                }
            }
            if (selected == null || bestCount < 16 || ambiguous)
            {
                throw new InvalidDataException(
                    "A unique 16-renderer character prefab was not found.");
            }
            GameObject character = UnityEngine.Object.Instantiate(selected);
            character.name = selected.name;
            character.SetActive(true);
            SetLayer(character.transform, CharacterLayer);
            objects.Add(character);
            report.characterBundle = modelBundle.relativePath;
            report.characterAsset = selected.name;
            report.instantiatedCharacterName = character.name;
            return character;
        }

        private static void ValidateCharacter(GameObject character, Report report)
        {
            SkinnedMeshRenderer[] renderers =
                character.GetComponentsInChildren<SkinnedMeshRenderer>(true);
            Array.Sort(renderers, (left, right) => string.CompareOrdinal(
                HierarchyPath(left.transform),
                HierarchyPath(right.transform)));
            report.skinnedMeshRendererCount = renderers.Length;
            report.transformCount =
                character.GetComponentsInChildren<Transform>(true).Length;
            var uniqueBones = new HashSet<Transform>();
            var uniqueMaterials = new HashSet<Material>();
            var uniqueTextures = new HashSet<Texture>();
            foreach (SkinnedMeshRenderer renderer in renderers)
            {
                if (renderer.sharedMesh == null || renderer.rootBone == null ||
                    renderer.bones == null || renderer.bones.Length == 0 ||
                    !Finite(renderer.bounds))
                {
                    throw new InvalidDataException(
                        "Renderer mesh/rootBone/bones/bounds gate failed.");
                }
                foreach (Transform bone in renderer.bones)
                {
                    if (bone == null || !bone.IsChildOf(character.transform) ||
                        !Finite(bone))
                    {
                        throw new InvalidDataException(
                            "Renderer bone hierarchy or finite pose failed.");
                    }
                    uniqueBones.Add(bone);
                }
                int rendererTextureCount = 0;
                Material[] materials = renderer.sharedMaterials;
                if (materials == null || materials.Length == 0)
                {
                    throw new InvalidDataException(
                        "Renderer has no materials.");
                }
                foreach (Material material in materials)
                {
                    if (material == null || material.shader == null ||
                        !material.shader.isSupported ||
                        string.Equals(
                            material.shader.name,
                            "Hidden/InternalErrorShader",
                            StringComparison.Ordinal))
                    {
                        throw new InvalidDataException(
                            "Character shader gate failed.");
                    }
                    uniqueMaterials.Add(material);
                    foreach (string property in material.GetTexturePropertyNames())
                    {
                        Texture texture = material.GetTexture(property);
                        if (texture != null)
                        {
                            rendererTextureCount++;
                            uniqueTextures.Add(texture);
                        }
                    }
                }
                if (rendererTextureCount == 0)
                {
                    throw new InvalidDataException(
                        "Renderer has no bound texture.");
                }
                report.rendererResults.Add(new RendererResult
                {
                    objectPath = HierarchyPath(renderer.transform),
                    enabled = renderer.enabled,
                    active = renderer.gameObject.activeInHierarchy,
                    mesh = renderer.sharedMesh.name,
                    materialCount = materials.Length,
                    textureBindingCount = rendererTextureCount,
                    rootBone = HierarchyPath(renderer.rootBone),
                    boneCount = renderer.bones.Length,
                    finiteBounds = true
                });
            }
            Animator animator = character.GetComponentInChildren<Animator>(true);
            report.animatorPresent = animator != null;
            report.avatarPresent = animator != null && animator.avatar != null;
            report.avatarValid =
                report.avatarPresent && animator.avatar.isValid;
            report.avatarHuman =
                report.avatarPresent && animator.avatar.isHuman;
            report.uniqueBoneCount = uniqueBones.Count;
            report.materialCount = uniqueMaterials.Count;
            report.textureCount = uniqueTextures.Count;
            report.modelStructurePassed =
                renderers.Length >= 16 &&
                uniqueBones.Count > 0 &&
                report.animatorPresent &&
                report.avatarPresent &&
                report.avatarValid;
            report.materialShaderPassed =
                uniqueMaterials.Count > 0 && uniqueTextures.Count > 0;
        }

        private static void ValidateAnimations(
            List<LoadedBundle> bundles,
            GameObject character,
            string outputRoot,
            List<GameObject> objects,
            Report report)
        {
            LoadedBundle animationBundle = FindBundle(
                bundles,
                "char_14401_animations.unity3d");
            AnimationClip[] clips =
                animationBundle.bundle.LoadAllAssets<AnimationClip>();
            Array.Sort(clips, CompareClips);
            var names = new HashSet<string>(StringComparer.Ordinal);
            var expectedNames = new HashSet<string>(
                ExpectedAnimationNames,
                StringComparer.Ordinal);
            var eligible = new List<AnimationClip>();
            foreach (AnimationClip clip in clips)
            {
                if (clip == null || clip.length <= 0.0f)
                {
                    continue;
                }
                if (!names.Add(clip.name))
                {
                    throw new InvalidDataException(
                        "Animation names are not unique.");
                }
                eligible.Add(clip);
            }
            report.loadedAnimationClipCount = clips.Length;
            report.eligibleAnimationClipCount = eligible.Count;
            report.uniqueAnimationNameCount = names.Count;
            report.expectedAnimationClipCount =
                ExpectedAnimationNames.Length;
            if (clips.Length != ExpectedAnimationNames.Length ||
                eligible.Count != ExpectedAnimationNames.Length ||
                names.Count != ExpectedAnimationNames.Length ||
                !names.SetEquals(expectedNames))
            {
                throw new InvalidDataException(
                    "Loaded animation set does not equal the frozen 61-name registry.");
            }

            AnimationClip idle = SelectUniqueRepresentative(
                eligible,
                "144_Idle");
            AnimationClip attack = SelectUniqueRepresentative(
                eligible,
                "144_Attack_1");
            report.selectedIdleClip = idle.name;
            report.selectedAttackClip = attack.name;
            var pose = new PoseSnapshot(character);

            foreach (AnimationClip clip in eligible)
            {
                var result = new AnimationResult
                {
                    clip = clip.name,
                    length = clip.length,
                    sampleCount = SampleFractions.Length,
                    status = "Running"
                };
                try
                {
                    float maximumChange = 0.0f;
                    foreach (float fraction in SampleFractions)
                    {
                        pose.Restore();
                        clip.SampleAnimation(character, clip.length * fraction);
                        ValidateFiniteCharacter(character);
                        maximumChange = Mathf.Max(
                            maximumChange,
                            pose.MaximumDifference());
                        report.completedAnimationSampleCount++;
                    }
                    result.maximumBoneChange = maximumChange;
                    result.classification = maximumChange > MotionEpsilon
                        ? "Motion"
                        : "ConstantPose";
                    if ((ReferenceEquals(clip, idle) ||
                         ReferenceEquals(clip, attack)) &&
                        maximumChange <= MotionEpsilon)
                    {
                        throw new InvalidDataException(
                            "Representative idle/attack clip produced no measurable bone motion.");
                    }
                    result.status = "Passed";
                    report.passedAnimationCount++;
                }
                catch (Exception exception)
                {
                    result.status = "Failed";
                    result.exceptionType = exception.GetType().FullName;
                    result.exceptionMessage = Sanitize(exception.Message);
                    report.failedAnimationCount++;
                }
                finally
                {
                    pose.Restore();
                    report.animationResults.Add(result);
                }
            }
            if (report.eligibleAnimationClipCount !=
                report.passedAnimationCount + report.failedAnimationCount ||
                report.failedAnimationCount != 0 ||
                report.passedAnimationCount != ExpectedAnimationNames.Length ||
                report.completedAnimationSampleCount !=
                    ExpectedAnimationNames.Length * SampleFractions.Length)
            {
                throw new InvalidDataException(
                    "Animation conservation or finite-pose gate failed.");
            }

            CapturePose(character, idle, 0.0f, "front.png", 0.0f, outputRoot, report);
            CapturePose(character, idle, 0.0f, "three-quarter.png", 35.0f, outputRoot, report);
            CapturePose(character, idle, 0.0f, "side.png", 90.0f, outputRoot, report);
            CapturePose(character, idle, 0.0f, "idle-00.png", 20.0f, outputRoot, report);
            CapturePose(character, idle, 0.25f, "idle-25.png", 20.0f, outputRoot, report);
            CapturePose(character, idle, 0.50f, "idle-50.png", 20.0f, outputRoot, report);
            CapturePose(character, idle, 0.75f, "idle-75.png", 20.0f, outputRoot, report);
            CapturePose(character, attack, 0.0f, "attack-00.png", 20.0f, outputRoot, report);
            CapturePose(character, attack, 0.25f, "attack-25.png", 20.0f, outputRoot, report);
            CapturePose(character, attack, 0.50f, "attack-50.png", 20.0f, outputRoot, report);
            CapturePose(character, attack, 0.75f, "attack-75.png", 20.0f, outputRoot, report);
            pose.Restore();
            report.animationValidationPassed = true;
            report.captureValidationPassed = report.captures.Count == 11;
        }

        private static AnimationClip SelectUniqueRepresentative(
            List<AnimationClip> clips,
            string exactName)
        {
            var exact = clips.FindAll(clip => string.Equals(
                clip.name,
                exactName,
                StringComparison.OrdinalIgnoreCase));
            if (exact.Count != 1)
            {
                throw new InvalidDataException(
                    "Frozen representative clip is missing or ambiguous: " +
                    exactName);
            }
            return exact[0];
        }

        private static void CapturePose(
            GameObject character,
            AnimationClip clip,
            float fraction,
            string fileName,
            float yaw,
            string outputRoot,
            Report report)
        {
            clip.SampleAnimation(character, clip.length * fraction);
            ValidateFiniteCharacter(character);
            Bounds bounds = CalculateBounds(character);
            Color background = new Color(0.035f, 0.045f, 0.065f, 1.0f);
            var cameraObject = new GameObject("CCVC Camera");
            var lightObject = new GameObject("CCVC Key Light");
            Camera camera = cameraObject.AddComponent<Camera>();
            Light light = lightObject.AddComponent<Light>();
            RenderTexture target = null;
            Texture2D texture = null;
            try
            {
                camera.clearFlags = CameraClearFlags.SolidColor;
                camera.backgroundColor = background;
                camera.cullingMask = 1 << CharacterLayer;
                camera.fieldOfView = 30.0f;
                float extent = Mathf.Max(
                    bounds.extents.x,
                    Mathf.Max(bounds.extents.y, bounds.extents.z));
                float distance = Mathf.Max(2.0f, extent * 4.2f);
                Quaternion rotation = Quaternion.Euler(0.0f, yaw, 0.0f);
                Vector3 direction = rotation * Vector3.forward;
                camera.transform.position =
                    bounds.center + direction * distance;
                camera.transform.LookAt(bounds.center);
                camera.nearClipPlane = 0.01f;
                camera.farClipPlane = distance * 4.0f;
                light.type = LightType.Directional;
                light.intensity = 1.25f;
                light.transform.rotation = Quaternion.Euler(35.0f, -35.0f, 0.0f);
                RenderSettings.ambientLight = new Color(0.45f, 0.45f, 0.45f);

                target = new RenderTexture(Width, Height, 24);
                texture = new Texture2D(
                    Width,
                    Height,
                    TextureFormat.RGBA32,
                    false);
                camera.targetTexture = target;
                RenderTexture.active = target;
                camera.Render();
                texture.ReadPixels(new Rect(0, 0, Width, Height), 0, 0);
                texture.Apply();
                Color32[] pixels = texture.GetPixels32();
                Visibility metrics = Measure(pixels, (Color32)background);
                if (metrics.foregroundPixelCount < 64 ||
                    metrics.brightnessRange < 4 ||
                    metrics.distinctColorCount < 2 ||
                    metrics.magentaPixelCount != 0)
                {
                    throw new InvalidDataException(
                        "Rendered character visibility/material gate failed.");
                }
                byte[] png = texture.EncodeToPNG();
                string path = Path.Combine(outputRoot, fileName);
                WriteCreateNew(path, png);
                report.captures.Add(new CaptureResult
                {
                    relativePath = fileName,
                    width = Width,
                    height = Height,
                    byteCount = png.LongLength,
                    sha256 = ComputeSha256(png),
                    foregroundPixelCount = metrics.foregroundPixelCount,
                    brightnessRange = metrics.brightnessRange,
                    distinctColorCount = metrics.distinctColorCount,
                    magentaPixelCount = metrics.magentaPixelCount,
                    clip = clip.name,
                    normalizedTime = fraction,
                    yawDegrees = yaw
                });
            }
            finally
            {
                camera.targetTexture = null;
                RenderTexture.active = null;
                if (target != null)
                {
                    target.Release();
                    UnityEngine.Object.DestroyImmediate(target);
                }
                if (texture != null)
                {
                    UnityEngine.Object.DestroyImmediate(texture);
                }
                UnityEngine.Object.DestroyImmediate(cameraObject);
                UnityEngine.Object.DestroyImmediate(lightObject);
            }
        }

        private static Visibility Measure(Color32[] pixels, Color32 background)
        {
            int foreground = 0;
            int minimum = 255;
            int maximum = 0;
            int magenta = 0;
            var colors = new HashSet<int>();
            foreach (Color32 pixel in pixels)
            {
                int dr = pixel.r - background.r;
                int dg = pixel.g - background.g;
                int db = pixel.b - background.b;
                if (dr * dr + dg * dg + db * db <= 64)
                {
                    continue;
                }
                foreground++;
                int brightness = (pixel.r + pixel.g + pixel.b) / 3;
                minimum = Math.Min(minimum, brightness);
                maximum = Math.Max(maximum, brightness);
                colors.Add((pixel.r >> 4) << 8 |
                           (pixel.g >> 4) << 4 |
                           (pixel.b >> 4));
                if (pixel.r > 200 && pixel.b > 200 && pixel.g < 80)
                {
                    magenta++;
                }
            }
            return new Visibility
            {
                foregroundPixelCount = foreground,
                brightnessRange = foreground == 0 ? 0 : maximum - minimum,
                distinctColorCount = colors.Count,
                magentaPixelCount = magenta
            };
        }

        private static void ValidateFiniteCharacter(GameObject root)
        {
            foreach (Transform transform in
                root.GetComponentsInChildren<Transform>(true))
            {
                if (!Finite(transform))
                {
                    throw new InvalidDataException(
                        "Animation produced a non-finite Transform.");
                }
            }
            foreach (Renderer renderer in
                root.GetComponentsInChildren<Renderer>(true))
            {
                if (!Finite(renderer.bounds))
                {
                    throw new InvalidDataException(
                        "Animation produced non-finite Renderer bounds.");
                }
            }
        }

        private static Bounds CalculateBounds(GameObject root)
        {
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            if (renderers.Length == 0)
            {
                throw new InvalidDataException("Character has no renderers.");
            }
            Bounds result = renderers[0].bounds;
            for (int i = 1; i < renderers.Length; i++)
            {
                result.Encapsulate(renderers[i].bounds);
            }
            if (!Finite(result) || result.size.sqrMagnitude <= 0.0f)
            {
                throw new InvalidDataException(
                    "Character bounds are invalid.");
            }
            return result;
        }

        private static LoadedBundle FindBundle(
            List<LoadedBundle> bundles,
            string fileName)
        {
            LoadedBundle match = null;
            foreach (LoadedBundle bundle in bundles)
            {
                if (string.Equals(
                        Path.GetFileName(bundle.relativePath),
                        fileName,
                        StringComparison.OrdinalIgnoreCase))
                {
                    if (match != null)
                    {
                        throw new InvalidDataException(
                            "Core bundle lookup is ambiguous.");
                    }
                    match = bundle;
                }
            }
            return match ?? throw new InvalidDataException(
                "Required core bundle was not loaded.");
        }

        private static string ResolveMember(string root, string relativePath)
        {
            string path = Path.GetFullPath(Path.Combine(
                root,
                relativePath.Replace('/', Path.DirectorySeparatorChar)));
            if (!IsSameOrDescendant(path, root) || !File.Exists(path))
            {
                throw new InvalidDataException(
                    "Core member path escaped or is missing.");
            }
            AssertExistingAncestorsNoReparse(path);
            AssertNoReparse(path, false);
            return path;
        }

        private static void WriteTerminal(
            Report report,
            string outputRoot,
            ref int exitCode)
        {
            if (string.IsNullOrEmpty(outputRoot) ||
                !Directory.Exists(outputRoot))
            {
                Debug.LogError(JsonUtility.ToJson(report, true));
                exitCode = 2;
                return;
            }
            try
            {
                report.exitCode = exitCode;
                string json = JsonUtility.ToJson(report, true) + "\n";
                WriteCreateNew(
                    Path.Combine(outputRoot, TerminalFileName),
                    new UTF8Encoding(false, true).GetBytes(json));
            }
            catch (Exception exception)
            {
                Debug.LogError(exception);
                Debug.LogError(JsonUtility.ToJson(report, true));
                exitCode = 2;
            }
        }

        private static void WriteCreateNew(string path, byte[] bytes)
        {
            using (var stream = new FileStream(
                path,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None))
            {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
            }
        }

        private static void AssertNew(string path)
        {
            if (File.Exists(path) || Directory.Exists(path))
            {
                throw new IOException("Evidence target already exists.");
            }
        }

        private static string[] CaptureNames()
        {
            return new[]
            {
                "front.png", "three-quarter.png", "side.png",
                "idle-00.png", "idle-25.png", "idle-50.png", "idle-75.png",
                "attack-00.png", "attack-25.png",
                "attack-50.png", "attack-75.png"
            };
        }

        private static int CompareObjects(GameObject left, GameObject right)
        {
            return string.CompareOrdinal(left.name, right.name);
        }

        private static int CompareClips(AnimationClip left, AnimationClip right)
        {
            return string.CompareOrdinal(left.name, right.name);
        }

        private static void SetLayer(Transform root, int layer)
        {
            root.gameObject.layer = layer;
            foreach (Transform child in root)
            {
                SetLayer(child, layer);
            }
        }

        private static string HierarchyPath(Transform transform)
        {
            var names = new List<string>();
            for (Transform current = transform;
                 current != null;
                 current = current.parent)
            {
                names.Add(current.name);
            }
            names.Reverse();
            return string.Join("/", names);
        }

        private static bool Finite(Transform value)
        {
            return Finite(value.localPosition) &&
                   Finite(value.localRotation) &&
                   Finite(value.localScale);
        }

        private static bool Finite(Vector3 value)
        {
            return Finite(value.x) && Finite(value.y) && Finite(value.z);
        }

        private static bool Finite(Quaternion value)
        {
            return Finite(value.x) && Finite(value.y) &&
                   Finite(value.z) && Finite(value.w);
        }

        private static bool Finite(Bounds value)
        {
            return Finite(value.center) && Finite(value.size);
        }

        private static bool Finite(float value)
        {
            return !float.IsNaN(value) && !float.IsInfinity(value);
        }

        private static string ComputeSha256(string path)
        {
            using (var stream = new FileStream(
                path,
                FileMode.Open,
                FileAccess.Read,
                FileShare.Read))
            using (SHA256 algorithm = SHA256.Create())
            {
                return Hex(algorithm.ComputeHash(stream));
            }
        }

        private static string ComputeSha256(byte[] bytes)
        {
            using (SHA256 algorithm = SHA256.Create())
            {
                return Hex(algorithm.ComputeHash(bytes));
            }
        }

        private static string Hex(byte[] bytes)
        {
            var builder = new StringBuilder(bytes.Length * 2);
            foreach (byte value in bytes)
            {
                builder.Append(value.ToString("x2"));
            }
            return builder.ToString();
        }

        private static string Sanitize(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }
            return value.Replace(
                Environment.GetEnvironmentVariable(InputVariable) ?? "",
                "<INPUT_ROOT>").Replace(
                Environment.GetEnvironmentVariable(OutputVariable) ?? "",
                "<OUTPUT_ROOT>");
        }

        private static string NormalizeDirectory(string path)
        {
            return Path.GetFullPath(path).TrimEnd(
                Path.DirectorySeparatorChar,
                Path.AltDirectorySeparatorChar);
        }

        private static bool PathsEqual(string left, string right)
        {
            return string.Equals(
                NormalizeDirectory(left),
                NormalizeDirectory(right),
                StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsSameOrDescendant(string path, string root)
        {
            string candidate = NormalizeDirectory(path);
            string parent = NormalizeDirectory(root);
            return PathsEqual(candidate, parent) ||
                   candidate.StartsWith(
                       parent + Path.DirectorySeparatorChar,
                       StringComparison.OrdinalIgnoreCase);
        }

        private static bool IsNetworkPath(string path)
        {
            return path.StartsWith("\\\\", StringComparison.Ordinal) ||
                   path.StartsWith("//", StringComparison.Ordinal);
        }

        private static void AssertExistingAncestorsNoReparse(string path)
        {
            string current = Path.GetFullPath(path);
            while (!string.IsNullOrEmpty(current))
            {
                if (Directory.Exists(current))
                {
                    AssertNoReparse(current, true);
                }
                DirectoryInfo parent = Directory.GetParent(current);
                current = parent == null ? null : parent.FullName;
            }
        }

        private static void AssertNoReparse(string path, bool directory)
        {
            string current = Path.GetFullPath(path);
            FileSystemInfo info = directory
                ? (FileSystemInfo)new DirectoryInfo(current)
                : new FileInfo(current);
            if ((info.Attributes & FileAttributes.ReparsePoint) != 0)
            {
                throw new InvalidDataException(
                    "Reparse paths are forbidden.");
            }
        }

        private sealed class PoseSnapshot
        {
            private readonly Transform[] transforms;
            private readonly Vector3[] positions;
            private readonly Quaternion[] rotations;
            private readonly Vector3[] scales;

            public PoseSnapshot(GameObject root)
            {
                transforms = root.GetComponentsInChildren<Transform>(true);
                positions = new Vector3[transforms.Length];
                rotations = new Quaternion[transforms.Length];
                scales = new Vector3[transforms.Length];
                for (int i = 0; i < transforms.Length; i++)
                {
                    positions[i] = transforms[i].localPosition;
                    rotations[i] = transforms[i].localRotation;
                    scales[i] = transforms[i].localScale;
                }
            }

            public void Restore()
            {
                for (int i = 0; i < transforms.Length; i++)
                {
                    transforms[i].localPosition = positions[i];
                    transforms[i].localRotation = rotations[i];
                    transforms[i].localScale = scales[i];
                }
            }

            public float MaximumDifference()
            {
                float maximum = 0.0f;
                for (int i = 0; i < transforms.Length; i++)
                {
                    maximum = Mathf.Max(
                        maximum,
                        Vector3.Distance(
                            positions[i],
                            transforms[i].localPosition));
                    maximum = Mathf.Max(
                        maximum,
                        Quaternion.Angle(
                            rotations[i],
                            transforms[i].localRotation) / 180.0f);
                    maximum = Mathf.Max(
                        maximum,
                        Vector3.Distance(
                            scales[i],
                            transforms[i].localScale));
                }
                return maximum;
            }
        }

        private sealed class AuthorizedMember
        {
            public readonly string relativePath;
            public readonly long length;
            public readonly string sha256;

            public AuthorizedMember(
                string relativePath,
                long length,
                string sha256)
            {
                this.relativePath = relativePath;
                this.length = length;
                this.sha256 = sha256;
            }
        }

        private sealed class LoadedBundle
        {
            public readonly string relativePath;
            public readonly AssetBundle bundle;

            public LoadedBundle(string relativePath, AssetBundle bundle)
            {
                this.relativePath = relativePath;
                this.bundle = bundle;
            }
        }

        private sealed class Visibility
        {
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
            public int magentaPixelCount;
        }

        [Serializable]
        private sealed class Report
        {
            public string schemaVersion;
            public string artifactId;
            public string status;
            public string stage;
            public string unityVersion;
            public string requiredUnityVersion;
            public int authorizedInputCount;
            public long inputBytes;
            public int deniedBundleCount;
            public List<InputResult> inputResults;
            public int loadedBundleCount;
            public List<BundleResult> bundleResults;
            public string characterBundle;
            public string characterAsset;
            public string instantiatedCharacterName;
            public int skinnedMeshRendererCount;
            public int transformCount;
            public int uniqueBoneCount;
            public int materialCount;
            public int textureCount;
            public bool animatorPresent;
            public bool avatarPresent;
            public bool avatarValid;
            public bool avatarHuman;
            public List<RendererResult> rendererResults;
            public bool modelStructurePassed;
            public bool materialShaderPassed;
            public int loadedAnimationClipCount;
            public int expectedAnimationClipCount;
            public int eligibleAnimationClipCount;
            public int uniqueAnimationNameCount;
            public int completedAnimationSampleCount;
            public int passedAnimationCount;
            public int failedAnimationCount;
            public string selectedIdleClip;
            public string selectedAttackClip;
            public List<AnimationResult> animationResults;
            public bool animationValidationPassed;
            public List<CaptureResult> captures;
            public bool captureValidationPassed;
            public string failureStage;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
            public int exitCode;
            public string nextAction;
        }

        [Serializable]
        private sealed class InputResult
        {
            public string relativePath;
            public long length;
            public string sha256;
            public string status;
        }

        [Serializable]
        private sealed class BundleResult
        {
            public string relativePath;
            public int loadOrdinal;
            public int assetCount;
            public string[] assetNames;
            public string status;
        }

        [Serializable]
        private sealed class RendererResult
        {
            public string objectPath;
            public bool enabled;
            public bool active;
            public string mesh;
            public int materialCount;
            public int textureBindingCount;
            public string rootBone;
            public int boneCount;
            public bool finiteBounds;
        }

        [Serializable]
        private sealed class AnimationResult
        {
            public string clip;
            public float length;
            public int sampleCount;
            public float maximumBoneChange;
            public string classification;
            public string status;
            public string exceptionType;
            public string exceptionMessage;
        }

        [Serializable]
        private sealed class CaptureResult
        {
            public string relativePath;
            public int width;
            public int height;
            public long byteCount;
            public string sha256;
            public int foregroundPixelCount;
            public int brightnessRange;
            public int distinctColorCount;
            public int magentaPixelCount;
            public string clip;
            public float normalizedTime;
            public float yawDegrees;
        }
    }
}
