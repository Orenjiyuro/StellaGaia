using System.Collections.Generic;
using System.IO;
using StellaGaia.Validation;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace StellaGaia.EditorTools
{
    public static class CreateSampleValidationScene
    {
        private const string ScenePath = "Assets/StellaGaia/Scenes/SampleValidation.unity";
        private const string SfxPath = "Assets/StellaGaia/Audio/SFX/vo_108_combat_ultskill_002_jp.ogg";
        private const string MusicPath = "Assets/StellaGaia/Audio/Music/195906654.ogg";

        [MenuItem("StellaGaia/Create Sample Validation Scene")]
        public static void CreateScene()
        {
            Directory.CreateDirectory("Assets/StellaGaia/Scenes");
            Directory.CreateDirectory("Assets/StellaGaia/Audio/SFX");
            Directory.CreateDirectory("Assets/StellaGaia/Audio/Music");

            AssetDatabase.ImportAsset(SfxPath, ImportAssetOptions.ForceUpdate);
            AssetDatabase.ImportAsset(MusicPath, ImportAssetOptions.ForceUpdate);
            AssetDatabase.Refresh();

            var scene = EditorSceneManager.NewScene(NewSceneSetup.DefaultGameObjects, NewSceneMode.Single);
            var validatorObject = new GameObject("SampleAssetBundleValidator");
            var validator = validatorObject.AddComponent<SampleAssetBundleValidator>();

            validator.bundleSamples = new[]
            {
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "Character",
                    projectRelativePath = "Extracted/Samples/AssetBundle/Characters/char_14401_animations.unity3d"
                },
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "Enemy",
                    projectRelativePath = "Extracted/Samples/AssetBundle/Enemies/mons_16510fengcao_animations.unity3d"
                },
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "Environment",
                    projectRelativePath = "Extracted/Samples/AssetBundle/Environments/env_roguelike_2_texture-7.unity3d"
                },
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "Effect",
                    projectRelativePath = "Extracted/Samples/AssetBundle/Effects/fx_actorcommon_textures_uncollated.unity3d"
                },
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "UI",
                    projectRelativePath = "Extracted/Samples/AssetBundle/UI/ui_big_sprites.unity3d"
                },
                new SampleAssetBundleValidator.BundleSample
                {
                    label = "Items",
                    projectRelativePath = "Extracted/Samples/AssetBundle/Items/icon-0.unity3d"
                }
            };

            validator.audioSamples = LoadAudioSamples();

            EditorSceneManager.SaveScene(scene, ScenePath);
            AssetDatabase.Refresh();
            Debug.Log($"Created validation scene at {ScenePath}");
        }

        private static AudioClip[] LoadAudioSamples()
        {
            var clips = new List<AudioClip>();
            AddAudioSample(clips, SfxPath);
            AddAudioSample(clips, MusicPath);
            return clips.ToArray();
        }

        private static void AddAudioSample(ICollection<AudioClip> clips, string assetPath)
        {
            AudioClip clip = AssetDatabase.LoadAssetAtPath<AudioClip>(assetPath);
            if (clip == null)
            {
                Debug.LogWarning($"Audio sample could not be assigned: {assetPath}");
                return;
            }

            clips.Add(clip);
        }
    }
}
