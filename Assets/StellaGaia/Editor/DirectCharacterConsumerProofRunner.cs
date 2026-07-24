using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.Editor
{
    public static class DirectCharacterConsumerProofRunner
    {
        private const string InputRootEnvironmentVariable = "STELLAGAIA_UDCP_INPUT_ROOT";
        private const string OutputRootEnvironmentVariable = "STELLAGAIA_UDCP_OUTPUT_ROOT";
        private const string TerminalFileName = "terminal-result.json";
        private const int AuthorizedMemberCount = 17;
        private const int EffectiveBundleCount = 12;

        private static readonly string[] AuthorizedMembers =
        {
            "Persistent_Store/AssetBundles/char_14401.unity3d",
            "Persistent_Store/AssetBundles/char_14401_animations.unity3d",
            "Persistent_Store/AssetBundles/char_14401_fx.unity3d",
            "Persistent_Store/AssetBundles/char_14401_models.unity3d",
            "Persistent_Store/AssetBundles/char_14401_timeline.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_animations.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_buff.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_combos.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_combos_monster.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_configs.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_fx.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_materials.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_models.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_textures.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_timeline.unity3d",
            "xtlr_Data/StreamingAssets/InstallResource/char_14401_weapons.unity3d"
        };

        public static void RunSmoke()
        {
            var report = new TerminalReport
            {
                schemaVersion = "udcp-smoke-terminal/1.0.0",
                status = "Running",
                unityVersion = Application.unityVersion,
                authorizedMemberCount = AuthorizedMemberCount,
                effectiveBundleCount = 0,
                memberResults = new List<MemberResult>(),
                effectiveBundles = new List<EffectiveBundleResult>(),
                bundleResults = new List<BundleResult>(),
                stageResults = new List<StageResult>(),
                exitCode = 1,
                nextAction = "AwaitUDCPLO1Audit"
            };

            var loadedBundles = new List<AssetBundle>();
            string inputRoot = null;
            string outputRoot = null;
            int exitCode = 1;

            try
            {
                report.stage = "PathGate";
                BeginStage(report, report.stage);
                inputRoot = ResolveInputRoot();
                outputRoot = ResolveOutputRoot();
                AssertSeparatedRoots(inputRoot, outputRoot);
                PrepareOutputRoot(outputRoot);
                CompleteStage(report);

                report.stage = "MemberValidation";
                BeginStage(report, report.stage);
                List<ValidatedMember> validatedMembers = ValidateAuthorizedMembers(inputRoot, report);
                CompleteStage(report);

                report.stage = "EffectiveSelection";
                BeginStage(report, report.stage);
                List<EffectiveBundle> effective = BuildEffectiveBundles(validatedMembers);
                if (effective.Count != EffectiveBundleCount)
                {
                    throw new InvalidDataException(
                        $"Effective bundle accounting mismatch: expected {EffectiveBundleCount}, found {effective.Count}.");
                }

                report.effectiveBundleCount = effective.Count;
                foreach (EffectiveBundle descriptor in effective)
                {
                    report.effectiveBundles.Add(new EffectiveBundleResult
                    {
                        logicalName = descriptor.logicalName,
                        relativePath = descriptor.relativePath,
                        disposition = descriptor.disposition
                    });
                }
                CompleteStage(report);

                foreach (EffectiveBundle descriptor in effective)
                {
                    report.stage = "BundleLoad";
                    BeginStage(report, report.stage);
                    var bundleResult = new BundleResult
                    {
                        logicalName = descriptor.logicalName,
                        relativePath = descriptor.relativePath,
                        disposition = descriptor.disposition,
                        status = "Loading",
                        assets = new List<AssetResult>()
                    };
                    report.bundleResults.Add(bundleResult);

                    try
                    {
                        AssetBundle bundle = AssetBundle.LoadFromFile(descriptor.absolutePath);
                        if (bundle == null)
                        {
                            throw new InvalidDataException(
                                $"Unity returned null while loading effective bundle {descriptor.relativePath}.");
                        }

                        loadedBundles.Add(bundle);
                        report.bundleLoadSuccessCount++;
                        bundleResult.status = "Loaded";
                        CompleteStage(report);

                        report.stage = "Discovery";
                        BeginStage(report, report.stage);
                        DiscoverBundle(bundle, descriptor, bundleResult, report);
                        bundleResult.status = "Discovered";
                        CompleteStage(report);
                    }
                    catch (Exception exception)
                    {
                        report.bundleLoadFailureCount++;
                        bundleResult.status = "Failed";
                        bundleResult.exceptionType = exception.GetType().FullName;
                        bundleResult.exceptionMessage = SanitizePortableText(exception.Message, inputRoot, outputRoot);
                        bundleResult.exceptionStack = SanitizePortableText(exception.StackTrace, inputRoot, outputRoot);
                        throw;
                    }
                }

                report.stage = "Discovery";
                if (report.modelCount <= 0)
                {
                    throw new InvalidDataException("Model smoke discovery produced zero candidates.");
                }
                if (report.animationClipCount <= 0)
                {
                    throw new InvalidDataException("AnimationClip smoke discovery produced zero candidates.");
                }
                if (report.battleFxCount <= 0)
                {
                    throw new InvalidDataException("BattleFx smoke discovery produced zero candidates.");
                }

                report.status = "Passed";
                report.nextAction = "AwaitUDCPLO1Audit";
                exitCode = 0;
            }
            catch (Exception exception)
            {
                report.status = "Failed";
                report.failureStage = report.stage;
                report.exceptionType = exception.GetType().FullName;
                report.exceptionMessage = SanitizePortableText(exception.Message, inputRoot, outputRoot);
                report.exceptionStack = SanitizePortableText(exception.StackTrace, inputRoot, outputRoot);
                FailCurrentStage(report, exception, inputRoot, outputRoot);
                exitCode = 1;
            }
            finally
            {
                report.stage = "Cleanup";
                BeginStage(report, report.stage);
                try
                {
                    for (int index = loadedBundles.Count - 1; index >= 0; index--)
                    {
                        AssetBundle bundle = loadedBundles[index];
                        if (bundle != null)
                        {
                            bundle.Unload(true);
                        }
                    }
                    CompleteStage(report);
                }
                catch (Exception cleanupException)
                {
                    if (exitCode == 0)
                    {
                        report.status = "Failed";
                        report.failureStage = "Cleanup";
                        report.exceptionType = cleanupException.GetType().FullName;
                        report.exceptionMessage = SanitizePortableText(cleanupException.Message, inputRoot, outputRoot);
                        report.exceptionStack = SanitizePortableText(cleanupException.StackTrace, inputRoot, outputRoot);
                    }
                    FailCurrentStage(report, cleanupException, inputRoot, outputRoot);
                    exitCode = 2;
                }

                report.stage = "TerminalWrite";
                BeginStage(report, report.stage);
                report.exitCode = exitCode;
                string terminalJson = JsonUtility.ToJson(report, true);
                try
                {
                    if (string.IsNullOrEmpty(outputRoot))
                    {
                        throw new InvalidOperationException("A safe output root was not established.");
                    }

                    WriteTerminalCreateNew(outputRoot, terminalJson);
                }
                catch (Exception terminalException)
                {
                    exitCode = 3;
                    report.exitCode = exitCode;
                    report.failureStage = "TerminalWrite";
                    report.exceptionType = terminalException.GetType().FullName;
                    report.exceptionMessage = SanitizePortableText(terminalException.Message, inputRoot, outputRoot);
                    report.exceptionStack = SanitizePortableText(terminalException.StackTrace, inputRoot, outputRoot);
                    FailCurrentStage(report, terminalException, inputRoot, outputRoot);
                    Debug.LogError(JsonUtility.ToJson(report, true));
                }

                EditorApplication.Exit(exitCode);
            }
        }

        private static string ResolveInputRoot()
        {
            string value = Environment.GetEnvironmentVariable(InputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException($"{InputRootEnvironmentVariable} is required.");
            }
            if (!Path.IsPathRooted(value) || IsUncOrDevicePath(value))
            {
                throw new InvalidOperationException("Input root must be an absolute local path.");
            }

            string fullPath = NormalizeDirectoryPath(value);
            if (!Directory.Exists(fullPath))
            {
                throw new DirectoryNotFoundException("Input root does not exist.");
            }
            AssertNoReparsePath(fullPath, true);
            return fullPath;
        }

        private static string ResolveOutputRoot()
        {
            string value = Environment.GetEnvironmentVariable(OutputRootEnvironmentVariable);
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException($"{OutputRootEnvironmentVariable} is required.");
            }
            if (!Path.IsPathRooted(value) || IsUncOrDevicePath(value))
            {
                throw new InvalidOperationException("Output root must be an absolute local path.");
            }

            string fullPath = NormalizeDirectoryPath(value);
            AssertExistingAncestorsNoReparse(fullPath);
            return fullPath;
        }

        private static void PrepareOutputRoot(string outputRoot)
        {
            Directory.CreateDirectory(outputRoot);
            AssertNoReparsePath(outputRoot, true);
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

        private static List<ValidatedMember> ValidateAuthorizedMembers(string inputRoot, TerminalReport report)
        {
            if (AuthorizedMembers.Length != AuthorizedMemberCount)
            {
                throw new InvalidDataException("Authorized selector accounting drifted.");
            }

            var seen = new HashSet<string>(StringComparer.Ordinal);
            var validated = new List<ValidatedMember>(AuthorizedMemberCount);
            foreach (string relativePath in AuthorizedMembers)
            {
                if (!seen.Add(relativePath))
                {
                    throw new InvalidDataException($"Duplicate authorized selector: {relativePath}");
                }
                if (Path.IsPathRooted(relativePath) || relativePath.IndexOf('\\') >= 0)
                {
                    throw new InvalidDataException($"Authorized selector is not portable: {relativePath}");
                }

                string absolutePath = Path.GetFullPath(
                    Path.Combine(inputRoot, relativePath.Replace('/', Path.DirectorySeparatorChar)));
                if (!IsSameOrDescendant(absolutePath, inputRoot))
                {
                    throw new InvalidDataException($"Authorized selector escapes the input root: {relativePath}");
                }

                AssertNoReparsePath(absolutePath, false);
                var fileInfo = new FileInfo(absolutePath);
                if (!fileInfo.Exists ||
                    (fileInfo.Attributes & FileAttributes.Directory) != 0 ||
                    (fileInfo.Attributes & FileAttributes.ReparsePoint) != 0 ||
                    (fileInfo.Attributes & FileAttributes.Device) != 0)
                {
                    throw new InvalidDataException($"Authorized member is not a regular non-reparse file: {relativePath}");
                }

                validated.Add(new ValidatedMember
                {
                    relativePath = relativePath,
                    absolutePath = absolutePath,
                    byteCount = fileInfo.Length
                });
                report.memberResults.Add(new MemberResult
                {
                    relativePath = relativePath,
                    byteCount = fileInfo.Length,
                    status = "Validated"
                });
            }

            return validated;
        }

        private static List<EffectiveBundle> BuildEffectiveBundles(List<ValidatedMember> members)
        {
            var byLogicalName = new Dictionary<string, EffectiveBundle>(StringComparer.Ordinal);
            var logicalOrder = new List<string>();

            foreach (ValidatedMember member in members)
            {
                string logicalName = Path.GetFileName(member.relativePath);
                int priority = GetPriority(member.relativePath);
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
                    continue;
                }

                if (priority < existing.priority)
                {
                    byLogicalName[logicalName] = candidate;
                }
            }

            var effective = new List<EffectiveBundle>(logicalOrder.Count);
            var uniqueLogicalNames = new HashSet<string>(StringComparer.Ordinal);
            foreach (string logicalName in logicalOrder)
            {
                if (!uniqueLogicalNames.Add(logicalName))
                {
                    throw new InvalidDataException($"Duplicate effective logical name: {logicalName}");
                }
                effective.Add(byLogicalName[logicalName]);
            }
            return effective;
        }

        private static int GetPriority(string relativePath)
        {
            return relativePath.StartsWith(
                "Persistent_Store/AssetBundles/",
                StringComparison.Ordinal) ? 0 : 1;
        }

        private static void DiscoverBundle(
            AssetBundle bundle,
            EffectiveBundle descriptor,
            BundleResult bundleResult,
            TerminalReport report)
        {
            string[] assetNames = bundle.GetAllAssetNames();
            Array.Sort(assetNames, StringComparer.Ordinal);
            bundleResult.assetCount = assetNames.Length;

            foreach (string assetName in assetNames)
            {
                UnityEngine.Object asset = bundle.LoadAsset(assetName);
                string typeName = asset == null ? "<null>" : asset.GetType().FullName;
                bool isModel = false;
                bool isAnimationClip = asset is AnimationClip;
                bool isBattleFx = IsBattleFx(descriptor.logicalName, assetName, asset);

                if (asset is GameObject gameObject)
                {
                    isModel = gameObject.GetComponentInChildren<Renderer>(true) != null;
                }

                if (isModel)
                {
                    report.modelCount++;
                }
                if (isAnimationClip)
                {
                    report.animationClipCount++;
                }
                if (isBattleFx)
                {
                    report.battleFxCount++;
                }

                bundleResult.assets.Add(new AssetResult
                {
                    assetName = SanitizePortableText(assetName, null, null),
                    typeName = typeName,
                    model = isModel,
                    animationClip = isAnimationClip,
                    battleFx = isBattleFx
                });
            }
        }

        private static bool IsBattleFx(string logicalName, string assetName, UnityEngine.Object asset)
        {
            bool fxBundle = logicalName.IndexOf("_fx.", StringComparison.OrdinalIgnoreCase) >= 0;
            bool fxName = assetName.IndexOf("/fx/", StringComparison.OrdinalIgnoreCase) >= 0 ||
                          assetName.IndexOf("effect", StringComparison.OrdinalIgnoreCase) >= 0;
            bool supportedType = asset is GameObject ||
                                 asset is Material ||
                                 asset is Texture ||
                                 asset is AnimationClip;
            return supportedType && (fxBundle || fxName);
        }

        private static void WriteTerminalCreateNew(string outputRoot, string json)
        {
            string terminalPath = Path.GetFullPath(Path.Combine(outputRoot, TerminalFileName));
            if (!IsSameOrDescendant(terminalPath, outputRoot))
            {
                throw new InvalidOperationException("Terminal path escapes the output root.");
            }

            byte[] bytes = new UTF8Encoding(false, true).GetBytes(json);
            using (var stream = new FileStream(
                terminalPath,
                FileMode.CreateNew,
                FileAccess.Write,
                FileShare.None))
            {
                stream.Write(bytes, 0, bytes.Length);
                stream.Flush(true);
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
            if (string.Equals(normalizedCandidate, normalizedAncestor, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }
            return normalizedCandidate.StartsWith(
                normalizedAncestor + Path.DirectorySeparatorChar,
                StringComparison.OrdinalIgnoreCase);
        }

        private static string NormalizeDirectoryPath(string path)
        {
            string fullPath = Path.GetFullPath(path);
            string root = Path.GetPathRoot(fullPath);
            if (!string.Equals(fullPath, root, StringComparison.OrdinalIgnoreCase))
            {
                fullPath = fullPath.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
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

        private static string SanitizePortableText(string value, string inputRoot, string outputRoot)
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
                    lines[index] = lines[index].Substring(0, absoluteIndex) + "<ABSOLUTE_PATH>";
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
            if (report.stageResults.Count > 0)
            {
                report.stageResults[report.stageResults.Count - 1].status = "Succeeded";
            }
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
            stage.exceptionMessage = SanitizePortableText(exception.Message, inputRoot, outputRoot);
            stage.exceptionStack = SanitizePortableText(exception.StackTrace, inputRoot, outputRoot);
        }

        private sealed class ValidatedMember
        {
            public string relativePath;
            public string absolutePath;
            public long byteCount;
        }

        private sealed class EffectiveBundle
        {
            public string logicalName;
            public string relativePath;
            public string absolutePath;
            public string disposition;
            public int priority;
        }

        [Serializable]
        private sealed class TerminalReport
        {
            public string schemaVersion;
            public string stage;
            public string status;
            public string unityVersion;
            public int authorizedMemberCount;
            public int effectiveBundleCount;
            public int bundleLoadSuccessCount;
            public int bundleLoadFailureCount;
            public int modelCount;
            public int animationClipCount;
            public int battleFxCount;
            public List<MemberResult> memberResults;
            public List<EffectiveBundleResult> effectiveBundles;
            public List<BundleResult> bundleResults;
            public List<StageResult> stageResults;
            public string failureStage;
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
            public long byteCount;
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
            public List<AssetResult> assets;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
        }

        [Serializable]
        private sealed class AssetResult
        {
            public string assetName;
            public string typeName;
            public bool model;
            public bool animationClip;
            public bool battleFx;
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
