using System;
using System.Collections.Generic;
using System.IO;
using StellaGaia.Validation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace StellaGaia.EditorTools
{
    public static class RunSampleValidationGate
    {
        private const string ScenePath = "Assets/StellaGaia/Scenes/SampleValidation.unity";
        private const string ValidatorObjectName = "SampleAssetBundleValidator";

        public static void Run()
        {
            var lines = new List<string>
            {
                "StellaGaia sample validation gate",
                $"Timestamp: {DateTimeOffset.Now:O}",
                $"Scene: {ScenePath}"
            };

            var scene = EditorSceneManager.OpenScene(ScenePath, OpenSceneMode.Single);
            var validatorObject = FindGameObjectInScene(scene, ValidatorObjectName);
            if (validatorObject == null)
            {
                throw new InvalidOperationException($"Missing validator object: {ValidatorObjectName}");
            }

            var validator = validatorObject.GetComponent<SampleAssetBundleValidator>();
            if (validator == null)
            {
                throw new InvalidOperationException($"Missing {nameof(SampleAssetBundleValidator)} component.");
            }

            bool hardFailure = false;
            foreach (SampleAssetBundleValidator.BundleSample sample in validator.bundleSamples)
            {
                hardFailure |= !ValidateBundleSample(sample, lines);
            }

            foreach (AudioClip clip in validator.audioSamples)
            {
                hardFailure |= !ValidateAudioSample(clip, lines);
            }

            string reportPath = Path.GetFullPath(Path.Combine("Extracted", "Logs", "unity-sample-validation-gate.txt"));
            Directory.CreateDirectory(Path.GetDirectoryName(reportPath));
            File.WriteAllLines(reportPath, lines);
            Debug.Log($"Wrote sample validation gate report to {reportPath}");

            if (hardFailure)
            {
                throw new InvalidOperationException($"Sample validation gate found hard failures. See {reportPath}");
            }
        }

        private static bool ValidateBundleSample(SampleAssetBundleValidator.BundleSample sample, ICollection<string> lines)
        {
            if (sample == null)
            {
                lines.Add("BUNDLE label=<null> status=hard-fail reason=missing-sample-config");
                return false;
            }

            string projectRoot = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            string absolutePath = Path.GetFullPath(Path.Combine(projectRoot, sample.projectRelativePath));
            if (!File.Exists(absolutePath))
            {
                lines.Add($"BUNDLE label={sample.label} status=hard-fail reason=missing-file path={absolutePath}");
                return false;
            }

            AssetBundle bundle = AssetBundle.LoadFromFile(absolutePath);
            if (bundle == null)
            {
                lines.Add($"BUNDLE label={sample.label} status=hard-fail reason=load-failed path={absolutePath}");
                return false;
            }

            try
            {
                string[] assetNames = bundle.GetAllAssetNames();
                int gameObjectCount = 0;
                foreach (string assetName in assetNames)
                {
                    if (bundle.LoadAsset<GameObject>(assetName) != null)
                    {
                        gameObjectCount++;
                    }
                }

                string visualStatus = gameObjectCount > 0 ? "candidate" : "partial";
                lines.Add($"BUNDLE label={sample.label} status=loaded visualStatus={visualStatus} assetCount={assetNames.Length} gameObjectCandidates={gameObjectCount} path={absolutePath}");
                return true;
            }
            finally
            {
                bundle.Unload(false);
            }
        }

        private static bool ValidateAudioSample(AudioClip clip, ICollection<string> lines)
        {
            if (clip == null)
            {
                lines.Add("AUDIO name=<null> status=hard-fail reason=missing-audio-reference");
                return false;
            }

            lines.Add($"AUDIO name={clip.name} status=imported lengthSeconds={clip.length:0.00} frequency={clip.frequency} channels={clip.channels}");
            return true;
        }

        private static GameObject FindGameObjectInScene(UnityEngine.SceneManagement.Scene scene, string objectName)
        {
            foreach (GameObject rootObject in scene.GetRootGameObjects())
            {
                GameObject match = FindGameObjectInHierarchy(rootObject.transform, objectName);
                if (match != null)
                {
                    return match;
                }
            }

            return null;
        }

        private static GameObject FindGameObjectInHierarchy(Transform transform, string objectName)
        {
            if (transform.name == objectName)
            {
                return transform.gameObject;
            }

            foreach (Transform child in transform)
            {
                GameObject match = FindGameObjectInHierarchy(child, objectName);
                if (match != null)
                {
                    return match;
                }
            }

            return null;
        }
    }
}
