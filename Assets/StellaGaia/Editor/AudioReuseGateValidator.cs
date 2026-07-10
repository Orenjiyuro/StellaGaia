using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Threading;
using UnityEditor;
using UnityEngine;
using UnityEngine.Networking;

namespace StellaGaia.EditorTools
{
    public static class AudioReuseGateValidator
    {
        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string selectionListPath = GetArg(args, "-stellaGaiaAudioSelectionList", string.Empty);
            string outputDirectory = GetArg(args, "-stellaGaiaAudioGateOutput", Path.GetFullPath(Path.Combine("Extracted", "Validation", "AudioReuseGate", "MinimumAudioSelection")));

            if (string.IsNullOrWhiteSpace(selectionListPath) || !File.Exists(selectionListPath))
            {
                throw new InvalidOperationException($"Missing audio selection list: {selectionListPath}");
            }

            Directory.CreateDirectory(outputDirectory);

            var report = new AudioGateReport
            {
                generatedAt = DateTimeOffset.Now.ToString("O"),
                selectionListPath = Path.GetFullPath(selectionListPath),
                outputDirectory = Path.GetFullPath(outputDirectory),
                clips = new List<AudioClipResult>()
            };

            foreach (AudioSelection selection in ReadSelections(selectionListPath))
            {
                report.clips.Add(ValidateSelection(selection));
            }

            Summarize(report);

            string jsonPath = Path.Combine(outputDirectory, "unity-audio-gate-validation.json");
            string textPath = Path.Combine(outputDirectory, "unity-audio-gate-validation.txt");
            File.WriteAllText(jsonPath, JsonUtility.ToJson(report, true));
            File.WriteAllLines(textPath, BuildTextReport(report));
            Debug.Log($"Wrote audio reuse gate validation to {jsonPath}");

            if (report.loadFailureCount > 0)
            {
                throw new InvalidOperationException($"Audio reuse gate found {report.loadFailureCount} load failure(s). See {jsonPath}");
            }
        }

        private static AudioClipResult ValidateSelection(AudioSelection selection)
        {
            var result = new AudioClipResult
            {
                id = selection.id,
                role = selection.role,
                path = selection.path
            };

            if (!File.Exists(selection.path))
            {
                result.status = "LoadFailed";
                result.error = "missing-file";
                return result;
            }

            using (UnityWebRequest request = UnityWebRequestMultimedia.GetAudioClip(new Uri(selection.path).AbsoluteUri, AudioType.WAV))
            {
                UnityWebRequestAsyncOperation operation = request.SendWebRequest();
                while (!operation.isDone)
                {
                    Thread.Sleep(10);
                }

                if (request.result != UnityWebRequest.Result.Success)
                {
                    result.status = "LoadFailed";
                    result.error = request.error;
                    return result;
                }

                AudioClip clip = DownloadHandlerAudioClip.GetContent(request);
                if (clip == null)
                {
                    result.status = "LoadFailed";
                    result.error = "null-audioclip";
                    return result;
                }

                result.status = "ClipDecoded";
                result.clipName = clip.name;
                result.lengthSeconds = clip.length;
                result.channels = clip.channels;
                result.frequency = clip.frequency;
                result.samples = clip.samples;
                result.loadState = clip.loadState.ToString();
                result.canAttachToAudioSource = CanAttachToAudioSource(clip);
                return result;
            }
        }

        private static bool CanAttachToAudioSource(AudioClip clip)
        {
            GameObject audioObject = new GameObject("AudioReuseGatePreviewSource");
            try
            {
                AudioSource source = audioObject.AddComponent<AudioSource>();
                source.playOnAwake = false;
                source.clip = clip;
                source.volume = 0.5f;
                source.loop = clip.length > 30f;
                return source.clip == clip;
            }
            finally
            {
                UnityEngine.Object.DestroyImmediate(audioObject);
            }
        }

        private static List<AudioSelection> ReadSelections(string path)
        {
            var selections = new List<AudioSelection>();
            string[] lines = File.ReadAllLines(path);
            for (int i = 1; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                if (line.Length == 0)
                {
                    continue;
                }

                string[] parts = line.Split('\t');
                if (parts.Length < 3)
                {
                    continue;
                }

                selections.Add(new AudioSelection
                {
                    id = parts[0],
                    role = parts[1],
                    path = parts[2]
                });
            }

            return selections;
        }

        private static void Summarize(AudioGateReport report)
        {
            report.clipCount = report.clips.Count;
            foreach (AudioClipResult clip in report.clips)
            {
                if (clip.status == "ClipDecoded")
                {
                    report.decodedClipCount++;
                }
                else
                {
                    report.loadFailureCount++;
                }

                if (clip.canAttachToAudioSource)
                {
                    report.audioSourceAttachCount++;
                }
            }
        }

        private static IEnumerable<string> BuildTextReport(AudioGateReport report)
        {
            yield return "StellaGaia audio reuse gate";
            yield return "GeneratedAt=" + report.generatedAt;
            yield return "ClipCount=" + report.clipCount.ToString(CultureInfo.InvariantCulture);
            yield return "DecodedClipCount=" + report.decodedClipCount.ToString(CultureInfo.InvariantCulture);
            yield return "LoadFailureCount=" + report.loadFailureCount.ToString(CultureInfo.InvariantCulture);
            foreach (AudioClipResult clip in report.clips)
            {
                yield return string.Format(
                    CultureInfo.InvariantCulture,
                    "CLIP id={0} role={1} status={2} length={3:0.000} channels={4} frequency={5} attachSource={6} path={7}",
                    clip.id,
                    clip.role,
                    clip.status,
                    clip.lengthSeconds,
                    clip.channels,
                    clip.frequency,
                    clip.canAttachToAudioSource,
                    clip.path);
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

        private sealed class AudioSelection
        {
            public string id;
            public string role;
            public string path;
        }

        [Serializable]
        private sealed class AudioGateReport
        {
            public string generatedAt;
            public string selectionListPath;
            public string outputDirectory;
            public int clipCount;
            public int decodedClipCount;
            public int loadFailureCount;
            public int audioSourceAttachCount;
            public List<AudioClipResult> clips;
        }

        [Serializable]
        private sealed class AudioClipResult
        {
            public string id;
            public string role;
            public string path;
            public string status;
            public string error;
            public string clipName;
            public float lengthSeconds;
            public int channels;
            public int frequency;
            public int samples;
            public string loadState;
            public bool canAttachToAudioSource;
        }
    }
}
