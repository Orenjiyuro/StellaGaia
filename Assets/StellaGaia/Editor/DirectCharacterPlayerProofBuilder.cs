using System;
using System.IO;
using System.Text;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace StellaGaia.Editor
{
    public static class DirectCharacterPlayerProofBuilder
    {
        private const string RequiredUnityVersion = "2022.3.62f2";
        private const string ScenePath =
            "Assets/StellaGaia/Scenes/SampleValidation.unity";
        private const string AttemptRelativePath =
            "Extracted/DirectCharacterConsumerProof/char_14401/UDCP-LO2-Player";
        private const string PlayerRelativePath =
            "Build/DirectCharacterPlayerProof.exe";
        private const string ResultFileName = "build-result.json";

        public static void Build()
        {
            var result = new BuildResultRecord
            {
                schemaVersion = "player-build/1.0.0",
                status = "Running",
                unityVersion = Application.unityVersion,
                requiredUnityVersion = RequiredUnityVersion,
                scene = ScenePath,
                target = BuildTarget.StandaloneWindows64.ToString(),
                playerRelativePath = PlayerRelativePath,
                exitCode = 1,
                nextAction = "StopBeforePlayer"
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
                        $"Builder requires Unity {RequiredUnityVersion}.");
                }
                if (!File.Exists(ScenePath))
                {
                    throw new FileNotFoundException(
                        $"Required scene is missing: {ScenePath}.");
                }
                string projectRoot = Path.GetFullPath(
                    Path.Combine(Application.dataPath, ".."));
                attemptRoot = Path.GetFullPath(Path.Combine(
                    projectRoot,
                    AttemptRelativePath.Replace(
                        '/', Path.DirectorySeparatorChar)));
                string buildRoot = Path.Combine(attemptRoot, "Build");
                string playerPath = Path.Combine(
                    attemptRoot,
                    PlayerRelativePath.Replace(
                        '/', Path.DirectorySeparatorChar));
                string resultPath = Path.Combine(attemptRoot, ResultFileName);
                if (!Directory.Exists(attemptRoot))
                {
                    throw new DirectoryNotFoundException(
                        "Authorized LO2 attempt root does not exist.");
                }
                if (Directory.Exists(buildRoot) ||
                    File.Exists(buildRoot) ||
                    File.Exists(resultPath))
                {
                    throw new IOException(
                        "Build evidence target already exists.");
                }
                Directory.CreateDirectory(buildRoot);

                var options = new BuildPlayerOptions
                {
                    scenes = new[] { ScenePath },
                    locationPathName = playerPath,
                    target = BuildTarget.StandaloneWindows64,
                    options = BuildOptions.None
                };
                BuildReport report = BuildPipeline.BuildPlayer(options);
                result.buildResult = report.summary.result.ToString();
                result.totalErrors = report.summary.totalErrors;
                result.totalWarnings = report.summary.totalWarnings;
                result.totalSize = report.summary.totalSize;
                result.durationSeconds = report.summary.totalTime.TotalSeconds;
                if (report.summary.result != BuildResult.Succeeded ||
                    report.summary.totalErrors != 0 ||
                    !File.Exists(playerPath))
                {
                    throw new InvalidDataException(
                        "Windows Player build did not succeed without errors.");
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
                result.exitCode = 1;
                result.nextAction = "StopBeforePlayer";
                exitCode = 1;
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
                    string resultPath =
                        Path.Combine(attemptRoot, ResultFileName);
                    byte[] json = new UTF8Encoding(false, true).GetBytes(
                        JsonUtility.ToJson(result, true));
                    using (var stream = new FileStream(
                        resultPath,
                        FileMode.CreateNew,
                        FileAccess.Write,
                        FileShare.None))
                    {
                        stream.Write(json, 0, json.Length);
                        stream.Flush(true);
                    }
                }
                catch (Exception exception)
                {
                    exitCode = 2;
                    Debug.LogError(exception);
                    Debug.LogError(JsonUtility.ToJson(result, true));
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
            string[] lines = value.Replace("\r\n", "\n").Split('\n');
            for (int line = 0; line < lines.Length; line++)
            {
                for (int index = 0; index + 2 < lines[line].Length; index++)
                {
                    if (char.IsLetter(lines[line][index]) &&
                        lines[line][index + 1] == ':' &&
                        (lines[line][index + 2] == '\\' ||
                         lines[line][index + 2] == '/'))
                    {
                        lines[line] =
                            lines[line].Substring(0, index) +
                            "<ABSOLUTE_PATH>";
                        break;
                    }
                }
            }
            return string.Join("\n", lines);
        }

        [Serializable]
        private sealed class BuildResultRecord
        {
            public string schemaVersion;
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
