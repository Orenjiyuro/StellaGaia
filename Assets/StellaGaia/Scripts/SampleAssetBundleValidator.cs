using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;

namespace StellaGaia.Validation
{
    public sealed class SampleAssetBundleValidator : MonoBehaviour
    {
        [Serializable]
        public sealed class BundleSample
        {
            public string label;
            public string projectRelativePath;
        }

        public BundleSample[] bundleSamples = Array.Empty<BundleSample>();
        public AudioClip[] audioSamples = Array.Empty<AudioClip>();

        private readonly List<AssetBundle> loadedBundles = new List<AssetBundle>();

        private void Start()
        {
            ValidateBundles();
            ValidateAudio();
        }

        private void OnDestroy()
        {
            foreach (AssetBundle bundle in loadedBundles)
            {
                if (bundle != null)
                {
                    bundle.Unload(false);
                }
            }

            loadedBundles.Clear();
        }

        private void ValidateBundles()
        {
            string projectRoot = Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
            float x = 0f;

            foreach (BundleSample sample in bundleSamples)
            {
                if (sample == null)
                {
                    Debug.LogError("Missing sample bundle configuration.");
                    continue;
                }

                string absolutePath = Path.Combine(projectRoot, sample.projectRelativePath);
                if (!File.Exists(absolutePath))
                {
                    Debug.LogError($"Missing sample bundle [{sample.label}]: {absolutePath}");
                    continue;
                }

                AssetBundle bundle = AssetBundle.LoadFromFile(absolutePath);
                if (bundle == null)
                {
                    Debug.LogError($"Failed to load sample bundle [{sample.label}]: {absolutePath}");
                    continue;
                }

                loadedBundles.Add(bundle);
                string[] assetNames = bundle.GetAllAssetNames();
                Debug.Log($"Loaded sample bundle [{sample.label}] with {assetNames.Length} assets.");

                foreach (string assetName in assetNames)
                {
                    GameObject prefab = bundle.LoadAsset<GameObject>(assetName);
                    if (prefab == null)
                    {
                        continue;
                    }

                    GameObject instance = Instantiate(prefab, new Vector3(x, 0f, 0f), Quaternion.identity);
                    instance.name = $"Sample_{sample.label}_{prefab.name}";
                    x += 3f;
                    break;
                }
            }
        }

        private void ValidateAudio()
        {
            AudioSource source = gameObject.AddComponent<AudioSource>();
            foreach (AudioClip clip in audioSamples)
            {
                if (clip == null)
                {
                    continue;
                }

                Debug.Log($"Audio sample ready: {clip.name}, {clip.length:0.00}s, {clip.frequency}Hz");
                source.clip = clip;
                source.playOnAwake = false;
                break;
            }
        }
    }
}
