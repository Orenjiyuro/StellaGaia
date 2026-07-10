[CmdletBinding()]
param(
    [string[]]$Category = @('EffectArt'),
    [string]$ManifestPath,
    [string]$ExportRoot,
    [string]$RepairRoot,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

$Category = @(
    foreach ($name in $Category) {
        foreach ($part in ([string]$name -split ',')) {
            $trimmed = $part.Trim()
            if ($trimmed) {
                $trimmed
            }
        }
    }
)

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $PSScriptRoot 'tool-manifest.json'
}

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$extractedRoot = Join-Path $repoRoot 'Extracted'
if (-not $ExportRoot) {
    $ExportRoot = Join-Path $extractedRoot 'AssetRipper\ByCategory'
}
if (-not $RepairRoot) {
    $RepairRoot = Join-Path $extractedRoot 'Repairs\CategoryMaterials'
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
$unityEditor = [string]$manifest.unityEditor
$sourceInstall = [string]$manifest.sourceInstall

function Resolve-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-PathInside {
    param(
        [Parameter(Mandatory = $true)][string]$Child,
        [Parameter(Mandatory = $true)][string]$Parent
    )

    $childFull = (Resolve-FullPath -Path $Child).TrimEnd('\', '/')
    $parentFull = (Resolve-FullPath -Path $Parent).TrimEnd('\', '/')
    return $childFull.Equals($parentFull, [System.StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-UnderExtracted {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if (-not (Test-PathInside -Child $Path -Parent $extractedRoot)) {
        throw "$Label must stay under Extracted: $Path"
    }
}

function Assert-NotUnderSourceInstall {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($sourceInstall -and (Test-PathInside -Child $Path -Parent $sourceInstall)) {
        throw "$Label must not be written under source install: $Path"
    }
}

function Write-RepairScript {
    param([Parameter(Mandatory = $true)][string]$ProjectPath)

    $editorDir = Join-Path $ProjectPath 'Assets\Editor'
    Assert-UnderExtracted -Path $editorDir -Label 'Temporary material repair directory'
    Assert-NotUnderSourceInstall -Path $editorDir -Label 'Temporary material repair directory'
    New-Item -ItemType Directory -Force -Path $editorDir | Out-Null

    $repairPath = Join-Path $editorDir 'StellaGaiaMaterialFallbackRepair.cs'
    $repairSource = @'
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor;
using UnityEngine;

namespace StellaGaia.ExportRepair
{
    public static class MaterialFallbackRepair
    {
        public static void Run()
        {
            string[] args = Environment.GetCommandLineArgs();
            string category = GetArg(args, "-stellaGaiaRepairCategory", "UnknownCategory");
            string outputDir = GetArg(args, "-stellaGaiaRepairOutput", Path.Combine(ProjectRoot(), "StellaGaiaMaterialRepair"));
            bool dryRun = GetArg(args, "-stellaGaiaRepairDryRun", "false").Equals("true", StringComparison.OrdinalIgnoreCase);

            Directory.CreateDirectory(outputDir);
            var report = new MaterialRepairReport
            {
                category = category,
                generatedAt = DateTimeOffset.Now.ToString("O"),
                projectPath = ProjectRoot(),
                dryRun = dryRun,
                materials = new List<MaterialRepairEntry>(),
                rendererMaterialRepairs = new List<RendererMaterialRepairEntry>()
            };
            TextureCandidate[] textureCandidates = BuildTextureCandidates();
            MaterialCandidate[] materialCandidates = BuildMaterialCandidates();

            string[] guids = AssetDatabase.FindAssets("t:Material", new[] { "Assets" });
            Array.Sort(guids, StringComparer.OrdinalIgnoreCase);
            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (material == null)
                {
                    continue;
                }

                report.totalMaterials++;
                Shader originalShader = material.shader;
                string originalShaderName = originalShader == null ? "<null>" : originalShader.name;
                bool broken = IsBrokenShader(originalShader);
                if (broken)
                {
                    report.brokenShaderMaterials++;
                }

                Texture mainTexture = FindMainTexture(material);
                bool inferredMainTexture = false;
                if (mainTexture == null)
                {
                    mainTexture = InferMainTexture(path, material.name, textureCandidates);
                    inferredMainTexture = mainTexture != null;
                }

                bool hadDisplayTexture = HasDisplayTexture(material);
                bool needsTextureRestore = mainTexture != null && !hadDisplayTexture;
                if (!broken && !needsTextureRestore)
                {
                    continue;
                }

                Color color = FindColor(material);
                float alpha = color.a;
                int originalQueue = material.renderQueue;
                Shader fallback = broken ? PickFallbackShader(path, material.name) : originalShader;
                var entry = new MaterialRepairEntry
                {
                    path = path,
                    materialName = material.name,
                    originalShader = originalShaderName,
                    fallbackShader = fallback == null ? "<missing>" : fallback.name,
                    hadMainTexture = mainTexture != null,
                    hadDisplayTexture = hadDisplayTexture,
                    inferredMainTexture = inferredMainTexture,
                    resolvedMainTexturePath = mainTexture == null ? "" : AssetDatabase.GetAssetPath(mainTexture),
                    textureRestored = needsTextureRestore,
                    originalRenderQueue = originalQueue
                };

                if (broken && fallback == null)
                {
                    entry.status = "FallbackShaderMissing";
                    report.failedRepairs++;
                    report.materials.Add(entry);
                    continue;
                }

                if (!dryRun)
                {
                    if (broken)
                    {
                        material.shader = fallback;
                    }
                    ApplyTexture(material, mainTexture);
                    ApplyColor(material, color);
                    ConfigureTransparency(material, alpha, originalQueue, path);
                    EditorUtility.SetDirty(material);
                }

                entry.status = dryRun ? "WouldRepair" : (broken ? "ShaderRepaired" : "TextureRestored");
                report.repairedMaterials++;
                if (broken)
                {
                    report.shaderRepairedMaterials++;
                }
                if (mainTexture != null)
                {
                    report.repairedWithMainTexture++;
                }
                if (needsTextureRestore)
                {
                    report.textureRestoredMaterials++;
                }
                if (inferredMainTexture)
                {
                    report.inferredMainTextureMaterials++;
                }
                report.materials.Add(entry);
            }

            RepairRendererMaterials(report, materialCandidates, dryRun);

            if (!dryRun)
            {
                AssetDatabase.SaveAssets();
            }

            string reportPath = Path.Combine(outputDir, "material-repair.json");
            File.WriteAllText(reportPath, JsonUtility.ToJson(report, true));
            Debug.Log("StellaGaia material fallback repair wrote " + reportPath);
        }

        private static bool IsBrokenShader(Shader shader)
        {
            if (shader == null)
            {
                return true;
            }

            string name = shader.name ?? "";
            return name == "Hidden/InternalErrorShader" ||
                name.IndexOf("error", StringComparison.OrdinalIgnoreCase) >= 0 ||
                name.IndexOf("missing", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static Shader PickFallbackShader(string path, string materialName)
        {
            string lower = (path + "/" + materialName).ToLowerInvariant();
            string[] candidates;
            if (lower.Contains("/fx/") || lower.Contains("particle") || lower.Contains("trail") || lower.Contains("glow") || lower.Contains("bullet"))
            {
                candidates = new[] { "Particles/Standard Unlit", "Legacy Shaders/Particles/Additive", "Unlit/Transparent", "Unlit/Texture", "Standard" };
            }
            else if (lower.Contains("/ui/") || lower.Contains("/icon/") || lower.Contains("sprite"))
            {
                candidates = new[] { "Unlit/Transparent", "Sprites/Default", "Unlit/Texture", "Standard" };
            }
            else
            {
                candidates = new[] { "Standard", "Unlit/Texture", "Unlit/Transparent" };
            }

            foreach (string candidate in candidates)
            {
                Shader shader = Shader.Find(candidate);
                if (shader != null)
                {
                    return shader;
                }
            }

            return null;
        }

        private static Texture FindMainTexture(Material material)
        {
            string[] names = { "_MainTex", "_BaseMap", "_BaseColorMap", "_Albedo", "_BaseTexture", "_Texture", "_MaskTexture" };
            foreach (string name in names)
            {
                if (material.HasProperty(name))
                {
                    Texture texture = material.GetTexture(name);
                    if (texture != null)
                    {
                        return texture;
                    }
                }
            }

            Texture savedTexture = FindSavedTexture(material, names);
            if (savedTexture != null)
            {
                return savedTexture;
            }

            return null;
        }

        private static Texture FindSavedTexture(Material material, string[] names)
        {
            var wanted = new HashSet<string>(names, StringComparer.Ordinal);
            SerializedObject serializedMaterial = new SerializedObject(material);
            SerializedProperty texEnvs = serializedMaterial.FindProperty("m_SavedProperties.m_TexEnvs");
            if (texEnvs == null || !texEnvs.isArray)
            {
                return null;
            }

            for (int i = 0; i < texEnvs.arraySize; i++)
            {
                SerializedProperty entry = texEnvs.GetArrayElementAtIndex(i);
                SerializedProperty name = entry.FindPropertyRelative("first");
                SerializedProperty texture = entry.FindPropertyRelative("second.m_Texture");
                if (name == null || texture == null || !wanted.Contains(name.stringValue))
                {
                    continue;
                }

                Texture value = texture.objectReferenceValue as Texture;
                if (value != null)
                {
                    return value;
                }
            }

            return null;
        }

        private static bool HasDisplayTexture(Material material)
        {
            string[] names = { "_MainTex", "_BaseMap", "_BaseColorMap", "_BaseTexture", "_Texture" };
            foreach (string name in names)
            {
                if (material.HasProperty(name) && material.GetTexture(name) != null)
                {
                    return true;
                }
            }

            return false;
        }

        private static Color FindColor(Material material)
        {
            string[] names = { "_Color", "_BaseColor", "_TintColor", "_MainColor" };
            foreach (string name in names)
            {
                if (material.HasProperty(name))
                {
                    return material.GetColor(name);
                }
            }

            return Color.white;
        }

        private static void ApplyTexture(Material material, Texture texture)
        {
            if (texture == null)
            {
                return;
            }

            string[] names = { "_MainTex", "_BaseMap", "_BaseColorMap", "_BaseTexture", "_Texture" };
            foreach (string name in names)
            {
                if (material.HasProperty(name))
                {
                    material.SetTexture(name, texture);
                }
            }
        }

        private static void ApplyColor(Material material, Color color)
        {
            string[] names = { "_Color", "_BaseColor", "_TintColor" };
            foreach (string name in names)
            {
                if (material.HasProperty(name))
                {
                    material.SetColor(name, color);
                }
            }
        }

        private static void ConfigureTransparency(Material material, float alpha, int originalQueue, string path)
        {
            bool transparent = alpha < 0.99f || originalQueue >= 3000 || path.ToLowerInvariant().Contains("/fx/");
            if (!transparent)
            {
                return;
            }

            if (material.HasProperty("_Mode"))
            {
                material.SetFloat("_Mode", 3f);
            }
            if (material.HasProperty("_Surface"))
            {
                material.SetFloat("_Surface", 1f);
            }
            if (material.HasProperty("_SrcBlend"))
            {
                material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
            }
            if (material.HasProperty("_DstBlend"))
            {
                material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            }
            if (material.HasProperty("_ZWrite"))
            {
                material.SetFloat("_ZWrite", 0f);
            }

            material.EnableKeyword("_ALPHABLEND_ON");
            material.DisableKeyword("_ALPHATEST_ON");
            material.renderQueue = originalQueue >= 3000 ? originalQueue : 3000;
        }

        private static TextureCandidate[] BuildTextureCandidates()
        {
            string[] guids = AssetDatabase.FindAssets("t:Texture2D", new[] { "Assets" });
            var candidates = new List<TextureCandidate>();
            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid);
                Texture texture = AssetDatabase.LoadAssetAtPath<Texture>(path);
                if (texture == null)
                {
                    continue;
                }

                string name = Path.GetFileNameWithoutExtension(path);
                candidates.Add(new TextureCandidate
                {
                    path = path.Replace('\\', '/'),
                    normalizedName = Normalize(name),
                    texture = texture
                });
            }

            return candidates.ToArray();
        }

        private static Texture InferMainTexture(string materialPath, string materialName, TextureCandidate[] candidates)
        {
            string materialToken = Normalize(Path.GetFileNameWithoutExtension(materialName));
            if (materialToken.Length < 3 || candidates == null || candidates.Length == 0)
            {
                return null;
            }

            string materialDirectory = (Path.GetDirectoryName(materialPath) ?? "").Replace('\\', '/').ToLowerInvariant();
            TextureCandidate best = null;
            int bestScore = 0;
            foreach (TextureCandidate candidate in candidates)
            {
                int score = 0;
                string lowerPath = candidate.path.ToLowerInvariant();
                if (candidate.normalizedName.Contains(materialToken))
                {
                    score += 80;
                }
                if (IsLikelyDiffuse(lowerPath))
                {
                    score += 50;
                }
                if (IsLikelyNonDiffuse(lowerPath))
                {
                    score -= 80;
                }
                if (SharesUsefulPath(materialDirectory, lowerPath))
                {
                    score += 20;
                }

                if (score > bestScore)
                {
                    bestScore = score;
                    best = candidate;
                }
            }

            return bestScore >= 90 ? best.texture : null;
        }

        private static bool IsLikelyDiffuse(string lowerPath)
        {
            return lowerPath.Contains("diffuse") ||
                lowerPath.Contains("albedo") ||
                lowerPath.Contains("basecolor") ||
                lowerPath.Contains("base_color") ||
                lowerPath.Contains("_col");
        }

        private static bool IsLikelyNonDiffuse(string lowerPath)
        {
            return lowerPath.Contains("shadow") ||
                lowerPath.Contains("spec") ||
                lowerPath.Contains("normal") ||
                lowerPath.Contains("mask") ||
                lowerPath.Contains("metal") ||
                lowerPath.Contains("rough");
        }

        private static bool SharesUsefulPath(string materialDirectory, string texturePath)
        {
            if (texturePath.StartsWith(materialDirectory, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            string parent = (Path.GetDirectoryName(materialDirectory) ?? "").Replace('\\', '/');
            return parent.Length > 0 && texturePath.StartsWith(parent, StringComparison.OrdinalIgnoreCase);
        }

        private static MaterialCandidate[] BuildMaterialCandidates()
        {
            string[] guids = AssetDatabase.FindAssets("t:Material", new[] { "Assets" });
            var candidates = new List<MaterialCandidate>();
            foreach (string guid in guids)
            {
                string path = AssetDatabase.GUIDToAssetPath(guid).Replace('\\', '/');
                Material material = AssetDatabase.LoadAssetAtPath<Material>(path);
                if (material == null)
                {
                    continue;
                }

                candidates.Add(new MaterialCandidate
                {
                    path = path,
                    normalizedName = Normalize(Path.GetFileNameWithoutExtension(path)),
                    material = material
                });
            }

            return candidates.ToArray();
        }

        private static void RepairRendererMaterials(MaterialRepairReport report, MaterialCandidate[] candidates, bool dryRun)
        {
            string[] prefabGuids = AssetDatabase.FindAssets("t:Prefab", new[] { "Assets" });
            Array.Sort(prefabGuids, StringComparer.OrdinalIgnoreCase);
            foreach (string guid in prefabGuids)
            {
                string prefabPath = AssetDatabase.GUIDToAssetPath(guid);
                GameObject root = null;
                try
                {
                    root = PrefabUtility.LoadPrefabContents(prefabPath);
                    if (root == null)
                    {
                        continue;
                    }

                    bool dirty = false;
                    foreach (Renderer renderer in root.GetComponentsInChildren<Renderer>(true))
                    {
                        Material[] materials = renderer.sharedMaterials;
                        int missingSlots = CountMissingMaterialSlots(materials);
                        int genericSlots = CountGenericMaterialSlots(materials);
                        if (missingSlots > 0)
                        {
                            report.missingRendererMaterialSlots += missingSlots;
                            MaterialCandidate candidate = InferRendererMaterial(prefabPath, root, renderer, candidates);
                            var entry = new RendererMaterialRepairEntry
                            {
                                prefabPath = prefabPath,
                                rendererPath = HierarchyPath(renderer.gameObject),
                                missingSlotCount = missingSlots,
                                genericSlotCount = 0,
                                originalMaterialPath = "",
                                resolvedMaterialPath = candidate == null ? "" : candidate.path
                            };

                            if (candidate == null)
                            {
                                entry.status = "Unresolved";
                                report.unresolvedRendererMaterialSlots += missingSlots;
                                report.rendererMaterialRepairs.Add(entry);
                                continue;
                            }

                            entry.status = dryRun ? "WouldAssign" : "Assigned";
                            report.resolvedRendererMaterialSlots += missingSlots;
                            if (!dryRun)
                            {
                                if (materials == null || materials.Length == 0)
                                {
                                    materials = new Material[1];
                                }

                                for (int i = 0; i < materials.Length; i++)
                                {
                                    if (materials[i] == null)
                                    {
                                        materials[i] = candidate.material;
                                    }
                                }

                                renderer.sharedMaterials = materials;
                                EditorUtility.SetDirty(renderer);
                                dirty = true;
                            }

                            report.rendererMaterialRepairs.Add(entry);
                        }

                        if (genericSlots > 0)
                        {
                            report.genericRendererMaterialSlots += genericSlots;
                            MaterialCandidate candidate = InferRendererMaterial(prefabPath, root, renderer, candidates);
                            string originalMaterialPath = FirstGenericMaterialPath(materials);
                            var entry = new RendererMaterialRepairEntry
                            {
                                prefabPath = prefabPath,
                                rendererPath = HierarchyPath(renderer.gameObject),
                                missingSlotCount = 0,
                                genericSlotCount = genericSlots,
                                originalMaterialPath = originalMaterialPath,
                                resolvedMaterialPath = candidate == null ? "" : candidate.path
                            };

                            if (candidate == null)
                            {
                                entry.status = "GenericUnresolved";
                                report.unresolvedGenericRendererMaterialSlots += genericSlots;
                                report.rendererMaterialRepairs.Add(entry);
                                continue;
                            }

                            entry.status = dryRun ? "WouldAssignSemantic" : "SemanticAssigned";
                            report.semanticRendererMaterialSlots += genericSlots;
                            if (!dryRun)
                            {
                                for (int i = 0; i < materials.Length; i++)
                                {
                                    if (materials[i] != null && IsGenericExtractedMaterial(materials[i], AssetDatabase.GetAssetPath(materials[i])))
                                    {
                                        materials[i] = candidate.material;
                                    }
                                }

                                renderer.sharedMaterials = materials;
                                EditorUtility.SetDirty(renderer);
                                dirty = true;
                            }

                            report.rendererMaterialRepairs.Add(entry);
                        }
                    }

                    if (dirty)
                    {
                        PrefabUtility.SaveAsPrefabAsset(root, prefabPath);
                    }
                }
                finally
                {
                    if (root != null)
                    {
                        PrefabUtility.UnloadPrefabContents(root);
                    }
                }
            }
        }

        private static int CountMissingMaterialSlots(Material[] materials)
        {
            if (materials == null || materials.Length == 0)
            {
                return 1;
            }

            int count = 0;
            foreach (Material material in materials)
            {
                if (material == null)
                {
                    count++;
                }
            }

            return count;
        }

        private static int CountGenericMaterialSlots(Material[] materials)
        {
            if (materials == null || materials.Length == 0)
            {
                return 0;
            }

            int count = 0;
            foreach (Material material in materials)
            {
                if (material != null && IsGenericExtractedMaterial(material, AssetDatabase.GetAssetPath(material)))
                {
                    count++;
                }
            }

            return count;
        }

        private static string FirstGenericMaterialPath(Material[] materials)
        {
            if (materials == null)
            {
                return "";
            }

            foreach (Material material in materials)
            {
                if (material == null)
                {
                    continue;
                }

                string path = AssetDatabase.GetAssetPath(material);
                if (IsGenericExtractedMaterial(material, path))
                {
                    return path;
                }
            }

            return "";
        }

        private static MaterialCandidate InferRendererMaterial(string prefabPath, GameObject root, Renderer renderer, MaterialCandidate[] candidates)
        {
            if (candidates == null || candidates.Length == 0)
            {
                return null;
            }

            string rendererToken = Normalize(HierarchyPath(renderer.gameObject));
            string prefabToken = Normalize(Path.GetFileNameWithoutExtension(prefabPath));
            string rootToken = Normalize(root.name);
            MaterialCandidate best = null;
            int bestScore = 0;
            foreach (MaterialCandidate candidate in candidates)
            {
                if (candidate.normalizedName.Length < 4)
                {
                    continue;
                }
                if (IsGenericExtractedMaterial(candidate.material, candidate.path))
                {
                    continue;
                }

                int score = 0;
                if (rendererToken.Contains(candidate.normalizedName))
                {
                    score += 120 + candidate.normalizedName.Length;
                }
                if (prefabToken.Contains(candidate.normalizedName) || rootToken.Contains(candidate.normalizedName))
                {
                    score += 90 + candidate.normalizedName.Length;
                }
                if (prefabToken.Contains("battle009") && candidate.normalizedName.Contains("battle009"))
                {
                    score += 50;
                }
                if (prefabToken.Contains("009a01") && candidate.normalizedName.Contains("009a01"))
                {
                    score += 50;
                }
                score += SharedSemanticSuffixScore(prefabToken, candidate.normalizedName);

                int prefix = Math.Max(CommonPrefixLength(rendererToken, candidate.normalizedName), CommonPrefixLength(prefabToken, candidate.normalizedName));
                if (prefix >= 8)
                {
                    score += 50 + prefix;
                }
                if (SharesUsefulAssetPath(prefabPath, candidate.path))
                {
                    score += 25;
                }
                if (candidate.path.IndexOf("/materials/", StringComparison.OrdinalIgnoreCase) >= 0)
                {
                    score += 5;
                }

                if (score > bestScore)
                {
                    bestScore = score;
                    best = candidate;
                }
            }

            return bestScore >= 100 ? best : null;
        }

        private static int SharedSemanticSuffixScore(string assetToken, string candidateToken)
        {
            string[] suffixes =
            {
                "floor01", "floor02", "floor03", "floor04", "floor05",
                "building01", "building02", "wall01", "wall02",
                "trim01", "trim02", "glass01", "glass02"
            };

            int score = 0;
            foreach (string suffix in suffixes)
            {
                if (assetToken.Contains(suffix) && candidateToken.Contains(suffix))
                {
                    score += suffix.StartsWith("floor", StringComparison.Ordinal) || suffix.StartsWith("building", StringComparison.Ordinal) ? 90 : 60;
                }
            }

            return score;
        }

        private static bool IsGenericExtractedMaterial(Material material, string path)
        {
            string materialName = material == null ? "" : material.name ?? "";
            string normalizedPath = (path ?? "").Replace('\\', '/');
            return materialName.Equals("Lit", StringComparison.OrdinalIgnoreCase) ||
                normalizedPath.IndexOf("/Material/Lit_", StringComparison.OrdinalIgnoreCase) >= 0 ||
                normalizedPath.IndexOf("/Assets/Material/Lit_", StringComparison.OrdinalIgnoreCase) >= 0;
        }

        private static int CommonPrefixLength(string left, string right)
        {
            int max = Math.Min(left.Length, right.Length);
            int count = 0;
            for (int i = 0; i < max; i++)
            {
                if (left[i] != right[i])
                {
                    break;
                }

                count++;
            }

            return count;
        }

        private static bool SharesUsefulAssetPath(string assetPath, string candidatePath)
        {
            string assetDirectory = (Path.GetDirectoryName(assetPath) ?? "").Replace('\\', '/');
            string lowerCandidate = candidatePath.Replace('\\', '/');
            if (lowerCandidate.StartsWith(assetDirectory, StringComparison.OrdinalIgnoreCase))
            {
                return true;
            }

            string parent = (Path.GetDirectoryName(assetDirectory) ?? "").Replace('\\', '/');
            return parent.Length > 0 && lowerCandidate.StartsWith(parent, StringComparison.OrdinalIgnoreCase);
        }

        private static string HierarchyPath(GameObject obj)
        {
            var parts = new List<string>();
            Transform current = obj.transform;
            while (current != null)
            {
                parts.Add(current.name);
                current = current.parent;
            }

            parts.Reverse();
            return string.Join("/", parts.ToArray());
        }

        private static string Normalize(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return "";
            }

            char[] chars = value.ToLowerInvariant().ToCharArray();
            var normalized = new System.Text.StringBuilder(chars.Length);
            foreach (char c in chars)
            {
                if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'))
                {
                    normalized.Append(c);
                }
            }

            return normalized.ToString();
        }

        private static string ProjectRoot()
        {
            return Path.GetFullPath(Path.Combine(Application.dataPath, ".."));
        }

        private static string GetArg(string[] args, string name, string fallback)
        {
            for (int i = 0; i < args.Length - 1; i++)
            {
                if (args[i] == name)
                {
                    return args[i + 1];
                }
            }

            return fallback;
        }
    }

    [Serializable]
    public class MaterialRepairReport
    {
        public string category;
        public string generatedAt;
        public string projectPath;
        public bool dryRun;
        public int totalMaterials;
        public int brokenShaderMaterials;
        public int repairedMaterials;
        public int shaderRepairedMaterials;
        public int repairedWithMainTexture;
        public int textureRestoredMaterials;
        public int inferredMainTextureMaterials;
        public int missingRendererMaterialSlots;
        public int resolvedRendererMaterialSlots;
        public int unresolvedRendererMaterialSlots;
        public int genericRendererMaterialSlots;
        public int semanticRendererMaterialSlots;
        public int unresolvedGenericRendererMaterialSlots;
        public int failedRepairs;
        public List<MaterialRepairEntry> materials;
        public List<RendererMaterialRepairEntry> rendererMaterialRepairs;
    }

    [Serializable]
    public class MaterialRepairEntry
    {
        public string path;
        public string materialName;
        public string originalShader;
        public string fallbackShader;
        public bool hadMainTexture;
        public bool hadDisplayTexture;
        public bool inferredMainTexture;
        public string resolvedMainTexturePath;
        public bool textureRestored;
        public int originalRenderQueue;
        public string status;
    }

    [Serializable]
    public class RendererMaterialRepairEntry
    {
        public string prefabPath;
        public string rendererPath;
        public int missingSlotCount;
        public int genericSlotCount;
        public string originalMaterialPath;
        public string resolvedMaterialPath;
        public string status;
    }

    public class TextureCandidate
    {
        public string path;
        public string normalizedName;
        public Texture texture;
    }

    public class MaterialCandidate
    {
        public string path;
        public string normalizedName;
        public Material material;
    }
}
'@

    Set-Content -LiteralPath $repairPath -Value $repairSource -Encoding UTF8
    return $repairPath
}

function Invoke-UnityEditor {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $process = Start-Process -FilePath $unityEditor -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
    return $process.ExitCode
}

function Invoke-CategoryRepair {
    param([Parameter(Mandatory = $true)][string]$Name)

    $projectPath = Join-Path $ExportRoot "$Name\ExportedProject"
    $categoryRepairRoot = Join-Path $RepairRoot $Name
    $repairJsonPath = Join-Path $categoryRepairRoot 'material-repair.json'
    $unityLogPath = Join-Path $categoryRepairRoot 'unity-material-repair.log'

    Assert-UnderExtracted -Path $projectPath -Label 'AssetRipper exported project'
    Assert-NotUnderSourceInstall -Path $projectPath -Label 'AssetRipper exported project'
    Assert-UnderExtracted -Path $categoryRepairRoot -Label 'Material repair output'
    Assert-NotUnderSourceInstall -Path $categoryRepairRoot -Label 'Material repair output'
    New-Item -ItemType Directory -Force -Path $categoryRepairRoot | Out-Null

    if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'ProjectSettings\ProjectVersion.txt') -PathType Leaf)) {
        return [PSCustomObject]@{
            Category = $Name
            Status = 'PendingExport'
            TotalMaterials = 0
            BrokenShaderMaterials = 0
            RepairedMaterials = 0
            TextureRestoredMaterials = 0
            InferredMainTextureMaterials = 0
            MissingRendererMaterialSlots = 0
            ResolvedRendererMaterialSlots = 0
            UnresolvedRendererMaterialSlots = 0
            GenericRendererMaterialSlots = 0
            SemanticRendererMaterialSlots = 0
            UnresolvedGenericRendererMaterialSlots = 0
            FailedRepairs = 0
            UnityExitCode = $null
            Report = $repairJsonPath
            Log = $unityLogPath
        }
    }

    Write-RepairScript -ProjectPath $projectPath | Out-Null
    $arguments = @(
        '-batchmode',
        '-quit',
        '-projectPath', $projectPath,
        '-executeMethod', 'StellaGaia.ExportRepair.MaterialFallbackRepair.Run',
        '-logFile', $unityLogPath,
        '-stellaGaiaRepairOutput', $categoryRepairRoot,
        '-stellaGaiaRepairCategory', $Name,
        '-stellaGaiaRepairDryRun', ([string]$DryRun.IsPresent).ToLowerInvariant()
    )

    $exitCode = Invoke-UnityEditor -Arguments $arguments
    if (-not (Test-Path -LiteralPath $repairJsonPath -PathType Leaf)) {
        $exitCode = Invoke-UnityEditor -Arguments $arguments
    }

    if (-not (Test-Path -LiteralPath $repairJsonPath -PathType Leaf)) {
        return [PSCustomObject]@{
            Category = $Name
            Status = 'RepairReportMissing'
            TotalMaterials = 0
            BrokenShaderMaterials = 0
            RepairedMaterials = 0
            TextureRestoredMaterials = 0
            InferredMainTextureMaterials = 0
            MissingRendererMaterialSlots = 0
            ResolvedRendererMaterialSlots = 0
            UnresolvedRendererMaterialSlots = 0
            GenericRendererMaterialSlots = 0
            SemanticRendererMaterialSlots = 0
            UnresolvedGenericRendererMaterialSlots = 0
            FailedRepairs = 0
            UnityExitCode = $exitCode
            Report = $repairJsonPath
            Log = $unityLogPath
        }
    }

    $report = Get-Content -LiteralPath $repairJsonPath -Raw | ConvertFrom-Json
    return [PSCustomObject]@{
        Category = $Name
        Status = if ($DryRun) { 'DryRunComplete' } else { 'RepairComplete' }
        TotalMaterials = [int]$report.totalMaterials
        BrokenShaderMaterials = [int]$report.brokenShaderMaterials
        RepairedMaterials = [int]$report.repairedMaterials
        TextureRestoredMaterials = [int]$report.textureRestoredMaterials
        InferredMainTextureMaterials = [int]$report.inferredMainTextureMaterials
        MissingRendererMaterialSlots = [int]$report.missingRendererMaterialSlots
        ResolvedRendererMaterialSlots = [int]$report.resolvedRendererMaterialSlots
        UnresolvedRendererMaterialSlots = [int]$report.unresolvedRendererMaterialSlots
        GenericRendererMaterialSlots = [int]$report.genericRendererMaterialSlots
        SemanticRendererMaterialSlots = [int]$report.semanticRendererMaterialSlots
        UnresolvedGenericRendererMaterialSlots = [int]$report.unresolvedGenericRendererMaterialSlots
        FailedRepairs = [int]$report.failedRepairs
        UnityExitCode = $exitCode
        Report = $repairJsonPath
        Log = $unityLogPath
    }
}

if (-not (Test-Path -LiteralPath $unityEditor -PathType Leaf)) {
    throw "Missing Unity editor: $unityEditor"
}

Assert-UnderExtracted -Path $ExportRoot -Label 'Export root'
Assert-UnderExtracted -Path $RepairRoot -Label 'Repair root'
Assert-NotUnderSourceInstall -Path $ExportRoot -Label 'Export root'
Assert-NotUnderSourceInstall -Path $RepairRoot -Label 'Repair root'
New-Item -ItemType Directory -Force -Path $RepairRoot | Out-Null

$results = foreach ($name in $Category) {
    Invoke-CategoryRepair -Name $name
}

$summaryJson = Join-Path $extractedRoot 'Logs\asset-category-material-repair-summary.json'
$summaryCsv = Join-Path $extractedRoot 'Logs\asset-category-material-repair-summary.csv'
Assert-UnderExtracted -Path $summaryJson -Label 'Summary JSON'
Assert-UnderExtracted -Path $summaryCsv -Label 'Summary CSV'
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryJson -Encoding UTF8
$results | Export-Csv -LiteralPath $summaryCsv -NoTypeInformation -Encoding UTF8

$results | Format-Table -AutoSize Category, Status, TotalMaterials, BrokenShaderMaterials, RepairedMaterials, TextureRestoredMaterials, InferredMainTextureMaterials, MissingRendererMaterialSlots, ResolvedRendererMaterialSlots, UnresolvedRendererMaterialSlots, GenericRendererMaterialSlots, SemanticRendererMaterialSlots, UnresolvedGenericRendererMaterialSlots, FailedRepairs, UnityExitCode
Write-Host "Wrote material repair summary to $summaryJson"
