using System;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace StellaGaia.Editor
{
    public static class CoreCharacterVisualCaptureBuilder
    {
        private const string RequiredUnityVersion = "2022.3.62f2";
        private const string ScenePath =
            "Assets/StellaGaia/Scenes/SampleValidation.unity";
        private const string AttemptRelativePath =
            "Extracted/DirectCharacterConsumerProof/char_14401/CCVC-LO1";
        private const string PlayerRelativePath =
            "Build/CoreCharacterVisualCapture.exe";

        public static void Build()
        {
            var result = new BuildRecord
            {
                schemaVersion = "ccvc-player-build/1.0.0",
                artifactId = "CCVC-LO1-BUILD",
                status = "Running",
                unityVersion = Application.unityVersion,
                requiredUnityVersion = RequiredUnityVersion,
                scene = ScenePath,
                target = BuildTarget.StandaloneWindows64.ToString(),
                playerRelativePath = PlayerRelativePath,
                exitCode = 1,
                nextAction = "CoreVisualFailed"
            };
            string attemptRoot = null;
            int exitCode = 1;
            try
            {
                if (!string.Equals(
                        Application.unityVersion,
                        RequiredUnityVersion,
                        StringComparison.Ordinal))
                {
                    throw new InvalidOperationException(
                        "Unity version identity mismatch.");
                }
                if (!File.Exists(ScenePath))
                {
                    throw new FileNotFoundException(
                        "Fixed SampleValidation scene is missing.");
                }
                string projectRoot = Path.GetFullPath(
                    Path.Combine(Application.dataPath, ".."));
                attemptRoot = Path.GetFullPath(Path.Combine(
                    projectRoot,
                    AttemptRelativePath.Replace(
                        '/',
                        Path.DirectorySeparatorChar)));
                if (!Directory.Exists(attemptRoot))
                {
                    throw new DirectoryNotFoundException(
                        "Authorized CCVC attempt root is missing.");
                }
                string buildRoot = Path.Combine(attemptRoot, "Build");
                string playerPath = Path.Combine(
                    attemptRoot,
                    PlayerRelativePath.Replace(
                        '/',
                        Path.DirectorySeparatorChar));
                string resultPath =
                    Path.Combine(attemptRoot, "build-result.json");
                if (File.Exists(resultPath) ||
                    File.Exists(buildRoot) ||
                    Directory.Exists(buildRoot))
                {
                    throw new IOException(
                        "CCVC build evidence target already exists.");
                }
                Directory.CreateDirectory(buildRoot);
                var options = new BuildPlayerOptions
                {
                    scenes = new[] { ScenePath },
                    locationPathName = playerPath,
                    target = BuildTarget.StandaloneWindows64,
                    options = BuildOptions.None
                };
                BuildReport build = BuildPipeline.BuildPlayer(options);
                result.buildResult = build.summary.result.ToString();
                result.totalErrors = build.summary.totalErrors;
                result.totalWarnings = build.summary.totalWarnings;
                result.totalSize = build.summary.totalSize;
                result.durationSeconds =
                    build.summary.totalTime.TotalSeconds;
                if (build.summary.result != BuildResult.Succeeded ||
                    build.summary.totalErrors != 0 ||
                    !File.Exists(playerPath))
                {
                    throw new InvalidDataException(
                        "CCVC Windows Player build failed.");
                }
                result.playerByteCount = new FileInfo(playerPath).Length;
                result.status = "Passed";
                result.exitCode = 0;
                result.nextAction = "RunGeneratedPlayerOnce";
                exitCode = 0;
            }
            catch (Exception exception)
            {
                result.status = "Failed";
                result.exceptionType = exception.GetType().FullName;
                result.exceptionMessage = Sanitize(exception.Message);
                result.exceptionStack = Sanitize(exception.StackTrace);
            }
            finally
            {
                try
                {
                    if (string.IsNullOrEmpty(attemptRoot))
                    {
                        throw new InvalidOperationException(
                            "Attempt root was not established.");
                    }
                    byte[] bytes = new UTF8Encoding(false, true).GetBytes(
                        JsonUtility.ToJson(result, true) + "\n");
                    using (var stream = new FileStream(
                        Path.Combine(attemptRoot, "build-result.json"),
                        FileMode.CreateNew,
                        FileAccess.Write,
                        FileShare.None))
                    {
                        stream.Write(bytes, 0, bytes.Length);
                        stream.Flush(true);
                    }
                }
                catch (Exception exception)
                {
                    Debug.LogError(exception);
                    Debug.LogError(JsonUtility.ToJson(result, true));
                    exitCode = 2;
                }
                EditorApplication.Exit(exitCode);
            }
        }

        private static string Sanitize(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return value;
            }
            int marker = value.IndexOf(":\\", StringComparison.Ordinal);
            return marker <= 0 ? value : "<ABSOLUTE_PATH>";
        }

        [Serializable]
        private sealed class BuildRecord
        {
            public string schemaVersion;
            public string artifactId;
            public string status;
            public string unityVersion;
            public string requiredUnityVersion;
            public string scene;
            public string target;
            public string playerRelativePath;
            public string buildResult;
            public int totalErrors;
            public int totalWarnings;
            public ulong totalSize;
            public double durationSeconds;
            public long playerByteCount;
            public string exceptionType;
            public string exceptionMessage;
            public string exceptionStack;
            public int exitCode;
            public string nextAction;
        }
    }
}
