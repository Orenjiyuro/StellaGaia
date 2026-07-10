using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.EditorTools
{
    public static class ControlledImportCandidateValidator
    {
        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string candidateListPath = GetArg(args, "-stellaGaiaControlledImportCandidateList", string.Empty);
            string outputDirectory = GetArg(args, "-stellaGaiaControlledImportOutput", Path.GetFullPath(Path.Combine("Extracted", "Validation", "ControlledImportCandidateGate")));

            if (string.IsNullOrWhiteSpace(candidateListPath) || !File.Exists(candidateListPath))
            {
                throw new InvalidOperationException($"Missing controlled import candidate list: {candidateListPath}");
            }

            Directory.CreateDirectory(outputDirectory);

            var report = new ControlledImportReport
            {
                generatedAt = DateTimeOffset.Now.ToString("O"),
                candidateListPath = Path.GetFullPath(candidateListPath),
                outputDirectory = Path.GetFullPath(outputDirectory),
                candidates = new List<ControlledImportResult>()
            };

            foreach (ControlledImportSelection selection in ReadSelections(candidateListPath))
            {
                report.candidates.Add(ValidateSelection(selection));
            }

            Summarize(report);

            string jsonPath = Path.Combine(outputDirectory, "unity-controlled-import-validation.json");
            string textPath = Path.Combine(outputDirectory, "unity-controlled-import-validation.txt");
            File.WriteAllText(jsonPath, JsonUtility.ToJson(report, true));
            File.WriteAllLines(textPath, BuildTextReport(report));
            Debug.Log($"Wrote controlled import validation to {jsonPath}");

            if (report.criticalIssueCount > 0 || report.loadedPrefabCount != report.candidateCount)
            {
                throw new InvalidOperationException($"Controlled import candidate validation found failures. See {jsonPath}");
            }
        }

        private static ControlledImportResult ValidateSelection(ControlledImportSelection selection)
        {
            var result = new ControlledImportResult
            {
                id = selection.id,
                sourceCategory = selection.sourceCategory,
                sourceCandidate = selection.sourceCandidate,
                controlledImportPath = selection.controlledImportPath
            };

            if (string.IsNullOrWhiteSpace(selection.controlledImportPath) || !selection.controlledImportPath.StartsWith("Assets/", StringComparison.Ordinal))
            {
                result.status = "ImportFailed";
                result.error = "controlled-import-path-must-be-project-asset-path";
                result.criticalIssueCount = 1;
                return result;
            }

            GameObject prefab = AssetDatabase.LoadAssetAtPath<GameObject>(selection.controlledImportPath);
            if (prefab == null)
            {
                result.status = "MissingImportedPrefab";
                result.error = "assetdatabase-load-null";
                result.criticalIssueCount = 1;
                return result;
            }

            result.loadedPrefab = true;
            GameObject instance = null;
            try
            {
                instance = PrefabUtility.InstantiatePrefab(prefab) as GameObject;
                if (instance == null)
                {
                    result.status = "InstantiateFailed";
                    result.error = "prefabutility-instantiate-null";
                    result.criticalIssueCount = 1;
                    return result;
                }

                result.instantiated = true;
                InspectHierarchy(instance, result);
                result.status = result.criticalIssueCount == 0 ? "ControlledImportUsable" : "ControlledImportHasIssues";
                return result;
            }
            finally
            {
                if (instance != null)
                {
                    UnityEngine.Object.DestroyImmediate(instance);
                }
            }
        }

        private static void InspectHierarchy(GameObject root, ControlledImportResult result)
        {
            Renderer[] renderers = root.GetComponentsInChildren<Renderer>(true);
            ParticleSystem[] particleSystems = root.GetComponentsInChildren<ParticleSystem>(true);
            Animator[] animators = root.GetComponentsInChildren<Animator>(true);

            result.rendererCount = renderers.Length;
            result.particleSystemCount = particleSystems.Length;
            result.animatorCount = animators.Length;

            foreach (Renderer renderer in renderers)
            {
                if (renderer == null)
                {
                    continue;
                }

                if (renderer is SkinnedMeshRenderer skinnedMeshRenderer && skinnedMeshRenderer.sharedMesh == null)
                {
                    result.missingMeshCount++;
                }
                else if (renderer is MeshRenderer)
                {
                    MeshFilter meshFilter = renderer.GetComponent<MeshFilter>();
                    if (meshFilter == null || meshFilter.sharedMesh == null)
                    {
                        result.missingMeshCount++;
                    }
                }

                foreach (Material material in renderer.sharedMaterials)
                {
                    if (material == null)
                    {
                        result.missingMaterialSlotCount++;
                        continue;
                    }

                    if (material.shader == null || material.shader.name.IndexOf("Hidden/InternalErrorShader", StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        result.brokenShaderCount++;
                    }
                }
            }

            foreach (Animator animator in animators)
            {
                if (animator.runtimeAnimatorController == null && animator.avatar == null)
                {
                    result.missingAnimatorBindingCount++;
                }
            }

            if (result.rendererCount == 0 && result.particleSystemCount == 0)
            {
                result.noRenderableComponent = true;
            }

            result.criticalIssueCount =
                result.missingMeshCount +
                result.missingMaterialSlotCount +
                result.brokenShaderCount +
                result.missingAnimatorBindingCount +
                (result.noRenderableComponent ? 1 : 0);
        }

        private static List<ControlledImportSelection> ReadSelections(string path)
        {
            var selections = new List<ControlledImportSelection>();
            string[] lines = File.ReadAllLines(path);
            for (int i = 1; i < lines.Length; i++)
            {
                string line = lines[i].Trim();
                if (line.Length == 0)
                {
                    continue;
                }

                string[] parts = line.Split('\t');
                if (parts.Length < 4)
                {
                    continue;
                }

                selections.Add(new ControlledImportSelection
                {
                    id = parts[0],
                    sourceCategory = parts[1],
                    sourceCandidate = parts[2],
                    controlledImportPath = parts[3]
                });
            }

            return selections;
        }

        private static void Summarize(ControlledImportReport report)
        {
            report.candidateCount = report.candidates.Count;
            foreach (ControlledImportResult candidate in report.candidates)
            {
                if (candidate.loadedPrefab)
                {
                    report.loadedPrefabCount++;
                }

                if (candidate.instantiated)
                {
                    report.instantiatedCount++;
                }

                if (candidate.criticalIssueCount == 0 && candidate.loadedPrefab && candidate.instantiated)
                {
                    report.usableCandidateCount++;
                }

                report.criticalIssueCount += candidate.criticalIssueCount;
            }
        }

        private static IEnumerable<string> BuildTextReport(ControlledImportReport report)
        {
            yield return "StellaGaia controlled import candidate gate";
            yield return "GeneratedAt=" + report.generatedAt;
            yield return "CandidateCount=" + report.candidateCount.ToString(CultureInfo.InvariantCulture);
            yield return "LoadedPrefabCount=" + report.loadedPrefabCount.ToString(CultureInfo.InvariantCulture);
            yield return "InstantiatedCount=" + report.instantiatedCount.ToString(CultureInfo.InvariantCulture);
            yield return "UsableCandidateCount=" + report.usableCandidateCount.ToString(CultureInfo.InvariantCulture);
            yield return "CriticalIssueCount=" + report.criticalIssueCount.ToString(CultureInfo.InvariantCulture);

            foreach (ControlledImportResult candidate in report.candidates)
            {
                yield return string.Format(
                    CultureInfo.InvariantCulture,
                    "CANDIDATE id={0} status={1} loaded={2} instantiated={3} renderers={4} particles={5} criticalIssues={6} path={7}",
                    candidate.id,
                    candidate.status,
                    candidate.loadedPrefab,
                    candidate.instantiated,
                    candidate.rendererCount,
                    candidate.particleSystemCount,
                    candidate.criticalIssueCount,
                    candidate.controlledImportPath);
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

        private sealed class ControlledImportSelection
        {
            public string id;
            public string sourceCategory;
            public string sourceCandidate;
            public string controlledImportPath;
        }

        [Serializable]
        private sealed class ControlledImportReport
        {
            public string generatedAt;
            public string candidateListPath;
            public string outputDirectory;
            public int candidateCount;
            public int loadedPrefabCount;
            public int instantiatedCount;
            public int usableCandidateCount;
            public int criticalIssueCount;
            public List<ControlledImportResult> candidates;
        }

        [Serializable]
        private sealed class ControlledImportResult
        {
            public string id;
            public string sourceCategory;
            public string sourceCandidate;
            public string controlledImportPath;
            public string status;
            public string error;
            public bool loadedPrefab;
            public bool instantiated;
            public int rendererCount;
            public int particleSystemCount;
            public int animatorCount;
            public int missingMeshCount;
            public int missingMaterialSlotCount;
            public int brokenShaderCount;
            public int missingAnimatorBindingCount;
            public bool noRenderableComponent;
            public int criticalIssueCount;
        }
    }
}
