# StellaGaia 第三方审查说明（2026-07-09）

本文档用于给第三方快速审查当前 StellaGaia 资源迁移工作的真实状态。它只汇总仓库内已有证据，不新增资源提取，不运行 Unity，不改变任何资源门禁结论。

## 1. 项目目标

项目目标是验证 StellaSora 原始素材能否在 Unity `2022.3.62f2` 中支撑一个本地 Hades-like 同人原型。Hades 只作为玩法机制参考，不复制 Hades 资产或代码；StellaSora 资产只用于本地同人原型验证，不做公开分发。

当前最根本的门禁不是玩法代码，而是原始素材复用：角色、敌人、场景或房间模块、战斗特效、战斗音频、奖励/强化卡牌 UI 等素材必须先达到可验证的 Unity 可见/可听状态，且问题被记录清楚，才有资格进入正式玩法竖切。

这里的 `ReadyForUnityFocusedValidation` 只表示离线前置条件已齐，允许进行一次聚焦 Unity 实机验收；它不是 `DevelopmentUsable`，也不能替代后续实机复用证据。

外部检索后的口径修正：公开资料中确实有大量 Unity 资产提取、AssetStudio/AssetRipper/Il2CppDumper/UABEA/wwiser/vgmstream 工具教程，以及 Daggerfall Unity、OpenMW、DevilutionX、OpenRCT2、Outer Wilds Mods 这类“用户自备原始数据 + 新运行层/新控制层”的成功复用路线。因此本文不再把问题表述为“找不到资产复用分享”。正确区分是：资产获取/提取可行性较高；现代 Unity 原工程完整复原则仍低确定性；StellaGaia 当前目标应是本地重建控制层并只让通过 Unity 可见/可听证据的候选进入开发。

## 2. 当前结论

当前不是通过状态。根门禁为 `StaticReadyNeedsUnityFocusedValidation`，`runUnity=false`，`canStartGameplayMainline=false`。

当前可给出的中立结论是：离线前置已齐，等待 Unity 实机验收。已有证据显示若干单资产候选和模块候选存在继续验收价值，但尚未达到素材复用门槛。

现有门禁状态如下：

| 门禁 | 当前状态 | 结论 |
| --- | --- | --- |
| Asset Acquisition Gate | `AssetAcquisitionEvidenceReady` | 证明资产定位、提取、解码、交叉验证证据足以支持 Unity import triage；不授予 `DevelopmentUsable` |
| Original Asset Reuse Gate | `StaticReadyNeedsUnityFocusedValidation` | 需要运行 Unity 聚焦验收后才能决定 Go / Repair / Stop |
| Unity Focused Validation Readiness | `ReadyForUnityFocusedValidation` | 静态前置检查通过，允许下一步跑 Unity；不是开发可用证明 |
| Asset Acceptance Manifest | `NotPassed` | 禁止进入玩法主线 |
| Minimum Vertical Slice Assets | `NotReady` | 最小竖切所需 8 项仍有 blocker |

最小竖切当前仍阻塞在 8 个需求项：

| 需求项 | 当前状态 | 主要缺口 |
| --- | --- | --- |
| 玩家角色 | `CandidateReadyForControlledImport` | 需要 Unity 控制导入、动画控制器重建和采样动画截图 |
| 敌人 | `CandidateReadyForControlledImport` | 需要 Unity 控制导入、动画控制器重建和采样动画截图 |
| 战斗特效 | `CandidateReadyForControlledImport` | 需要控制导入证明，不能按类别扩批 |
| 房间或地图模块 | `BlockedNeedsUnityVisibleValidation` | Rebind04 只有静态闭包和预览，缺 Unity 可识别截图 |
| 战斗音乐 | `SelectedNeedsUnityPlaybackValidation` | 需要 Unity 播放、循环和听感语义确认 |
| 战斗音效 | `SelectedNeedsUnityPlaybackValidation` | 需要 Unity 播放、人工试听或 Wwise 事件语义确认 |
| 奖励道具美术 | `SelectedNeedsUnityVisibleValidation` | 需要 Unity 生成 prefab 截图验收 |
| 强化卡牌美术 | `SelectedNeedsUnityVisibleValidation` | 需要 Unity 生成 prefab 截图验收 |

## 3. 已完成工作

### 3.1 资源盘点与安全边界

- 已建立 `Source Install` 和 `Extracted Workspace` 的边界：源安装目录为 `C:\SoftGame\YostarGames\StellaSora_CN`，中间产物写入 `C:\SoftWork\Git\StellaGaia\Extracted`。
- 根门禁安全检查显示源目录下没有新增 `Extracted`、`Assets`、`Tools`。
- 工具链已记录 Unity `2022.3.62f2`，并建立 AssetRipper、ffmpeg、vgmstream、Unity validation 相关脚本。
- 已建立资产获取层：`asset-acquisition-manifest.json` 与 `Test-AssetAcquisitionGate.ps1` 只记录和校验现有资产定位、提取、解码、交叉验证证据；它明确不能授予 `DevelopmentUsable`。
- `Extracted/` 仍作为忽略目录保存中间产物和截图证据，不作为正式 Git 资源提交。

### 3.2 音频

- 已完成 6,040 个独立 WEM 到 WAV 的解码，记录为 0 decode failure。
- 已对 `Impact.bnk`、`Monster_10001.bnk`、`Character_Common.bnk` 等战斗相关 bank 做聚焦解码，得到 328 个 bank media WAV，0 failure。
- 已建立最小音频候选：1 个战斗 BGM 候选、3 个攻击/命中/死亡 SFX 候选、1 个角色语音或战斗语音候选。
- 已生成 audition pack、波形图和语义 hints。当前状态仍是 `StaticReadyNeedsUnityPlaybackAndListening`，不能视为 Unity 中可播放或语义已确认。

### 3.3 角色与敌人

- 已选出一个角色候选 `14401_fx_battle_0.prefab` 和一个敌人候选 `10001TuBoShu_Actor.prefab`。
- 角色/敌人候选已有离线材质与贴图修复证据，代表样例可作为单资产继续尝试。
- 已建立 actor prototype controller rebuild 路线，脚本编译预检通过。
- 当前仍缺 Unity 控制导入、Animator Controller 重建后的实机播放和采样动画截图，因此不能判定为开发可用。

### 3.4 战斗特效

- 已选出单个修复候选 `fx_drop_note_red_bullet.prefab`。
- 该特效候选已有 GUID-closure、材质槽修复、截图和静态 usability 证据。
- 但这只是单资产候选，不代表 `EffectArt` 类别可扩批；仍需要 controlled project import proof。

### 3.5 场景与环境

- 完整房间路线曾多次尝试，仍存在大量缺依赖、placeholder 或不可识别问题。
- 当前最强环境候选是 `Environment009ModuleSalvageSet01SemanticMaterialTextureRebind04` 五 prefab 模块切片。
- Rebind04 的静态证据包括：11 个 diffuse-bound semantic materials、25 个 texture preview、0 generic renderer material slots、静态引用图无普通缺失引用。
- 一个 material 仍有意未绑定，因为候选贴图冲突，不能强行伪造通过。
- 当前环境状态是静态可继续验收，不是房间/地图可用。关键缺口是 Unity 可见截图必须显示可识别的原始环境模块，而不是非空几何或 fallback 灰模。

### 3.6 UI、掉落道具与强化卡牌

- 已选择最小 UI/reward 候选，包括掉落物、治疗/奖励纹理、fate-card 图标和大图。
- 已生成 4 个 texture preview、视觉 review pack 和 texture-only prototype rebuild 路线。
- 4 个 Texture2D 候选及 `.meta` 已按控制路径 staging，UI reward prototype builder 编译预检通过。
- 原始 drop/UI prefab 仍有 placeholder、脚本、字体、材质或缺 FX 引用风险。当前只说明 texture-only rebuild 路线可继续验收，不能说明原 prefab 已可用。

### 3.7 Android 对比

- Android 输入包括 APK、DATA cache、Unity data entry、AssetBundle indicator、Wwise bank 和 WEM entry。
- Android 对比对诊断有价值，尤其用于平台变体、缓存 bundle 和 SoundBank 核对。
- 当前本地证据显示 Android 没有直接解决 `009` 房间依赖闭包，也没有显著提高选中角色/敌人 Animator Override Controller 恢复概率。
- 因此 Android 资料能提高诊断覆盖面，但不能替代 Unity 实机可见验收。

### 3.8 门禁脚本与清单

- 已建立根门禁 `Test-OriginalAssetReuseGate.ps1`。
- 已建立 Unity 聚焦验收前置门禁 `Test-UnityFocusedValidationReadiness.ps1`。
- 已建立资源准入清单 `asset-acceptance-manifest.json`。
- 已建立最小竖切资产清单 `minimum-vertical-slice-assets.json`。
- 已建立面向环境、UI/reward、actor controller、audio、controlled import candidate 的分门禁脚本。

## 4. 当前困难

1. Unity license / 实机验收阻塞：当前最关键证据必须来自 Unity batch 或 Editor 实机运行，但前一次 Unity 可见验证被本机 license 阻塞。没有这一步，任何静态证据都不能升级为素材可复用结论。
2. 资产获取和资产开发可用仍是两层门禁：获取层已经可支撑 Unity import triage，但不能替代原始素材复用门禁。
3. 环境可识别度未证明：环境模块已有静态闭包和材质预览，但需要 Unity 截图证明它是可识别的 StellaSora 原始环境模块，而不是只显示了 fallback 几何。
4. 角色动画链路不完整：角色/敌人有 Avatar 和核心 `.anim` 的静态可能性，但 Animator Controller 或 Override Controller 仍需重建并在 Unity 中播放验证。
5. UI prefab 风险高：原始 drop/UI prefab 存在 placeholder、脚本、材质、字体、FX 引用问题；当前更现实的路线是用原始 Texture2D 重建本地 reward/card prefab，但还没跑 Unity 截图验收。
6. 音频语义没有最终确认：WAV 可读和 bank hints 只能说明候选有来源依据，不能说明它们在玩法中就是攻击、命中、死亡或 BGM loop 的正确语义。
7. 批量扩展门槛未到：当前证据集中在单资产、单模块、最小候选，不支持扩批导入正式玩法工程。

## 5. 关键证据索引

第三方审查时建议优先看以下文件。本文档不复制大文件和中间产物，只提供索引。

| 证据 | 路径 | 用途 |
| --- | --- | --- |
| 根门禁状态报告 | `docs/asset-migration/hades-like-gate-status.md` | 理解当前总体判断、阶段、历史尝试和下一步 |
| 资源准入清单 | `docs/asset-migration/asset-acceptance-manifest.json` | 审查各类别是否允许进入 gameplay mainline |
| 最小竖切清单 | `docs/asset-migration/minimum-vertical-slice-assets.json` | 审查 8 个竖切必需素材项的 blocker |
| 资产获取清单 | `docs/asset-migration/asset-acquisition-manifest.json` | 审查资产定位、提取、解码、交叉验证层，不应当成开发可用证明 |
| 外部复用研究 | `docs/asset-migration/external-asset-reuse-research.md` | 审查公开工具/教程和成功复用路线如何影响本项目方案 |
| 资产获取门禁 summary | `Extracted/Validation/AssetAcquisitionGate/asset-acquisition-gate-summary.json` | 审查 `AssetAcquisitionEvidenceReady` 与 `canGrantDevelopmentUsability=false` |
| 原始素材复用根门禁 summary | `Extracted/Validation/OriginalAssetReuseGate/original-asset-reuse-gate-summary.json` | 审查 `StaticReadyNeedsUnityFocusedValidation`、`canStartGameplayMainline=false` 和下个必需动作 |
| Unity 聚焦验收准备 summary | `Extracted/Validation/UnityFocusedValidationReadiness/unity-focused-validation-readiness-summary.json` | 审查为什么当前可进入 Unity 聚焦验收，但还不能通过 |
| 音频解码报告 | `docs/asset-migration/full-audio-decode-report.md` | 审查 6,040 个 WAV 解码结果 |
| bank media 解码报告 | `docs/asset-migration/bank-media-decode-report.md` | 审查聚焦战斗 bank 解码结果 |
| Android 输入报告 | `docs/asset-migration/android-package-intake-report.md` | 审查 Android 资料的诊断价值 |
| Android/PC 对比报告 | `docs/asset-migration/android-pc-bundle-comparison-report.md` | 审查 Android 是否补足 PC 缺失资源 |
| 手动预览审查报告 | `docs/asset-migration/manual-preview-review-report.md` | 审查离线 preview 的人工筛选证据 |

## 6. 后续计划与止损规则

下一步分两层：资产获取层已经由 `Test-AssetAcquisitionGate.ps1` 校验；Unity license 激活后运行根门禁做聚焦分流。该 Unity run 是 Go / Repair / Stop 的输入，不是自动 Go。运行：

```powershell
Tools\AssetImport\Test-OriginalAssetReuseGate.ps1 -RunUnity
```

这一步应同时核查 actor sampled-animation screenshots、environment/UI fidelity、audio import/playback 和语义线索。运行后必须把结果反映到 `minimum-vertical-slice-assets.json` 与 `asset-acceptance-manifest.json`，再重跑根门禁；最终 Go 只能来自重跑后的 root gate。验收结果按以下规则处理：

| 结果 | 条件 | 动作 |
| --- | --- | --- |
| Go | 根门禁通过，`canStartGameplayMainline=true`，最小竖切 8 项 blocker 清零，且 Unity 截图/播放证据真实存在 | 允许开始最小玩法竖切，但仍只导入已通过的单资产或模块 |
| Repair | 至少角色、敌人、特效、UI 或音频中有部分真实可见/可听证据，但某些类别失败且失败原因可定位 | 只允许做一轮有目标的修复，例如补依赖、材质映射、Animator Controller 重建、UI texture-only prefab 生成、音频语义复核 |
| Stop | 核心组合无法在 Unity 中产出可信证据，尤其是角色/敌人/场景/UI/audio 中多数仍不可见或不可听 | 停止 StellaSora 资产驱动路线，改用原创或占位资产验证玩法；不要继续无限静态分析 |

局部止损规则：

- 如果 EnvironmentArt 不能显示可识别房间或模块，不再把 StellaSora 地图作为 Hades-like 房间基础。
- 如果角色和敌人动画不能恢复，允许先评估静态模型加简化 hitbox，但不得把它们标为动画可用。
- 如果 UI prefab 继续高风险，保留原 Texture2D 重建本地 UI 的路线，放弃直接复用复杂原 prefab。
- 如果 Wwise event mapping 不能恢复，可用手动试听 manifest 做原型音频，但不能声称原事件语义完整复用。
- 如果一次聚焦 Unity 验收和一轮定向修复后仍没有核心素材组合通过，项目应停止推进资产迁移路线。

## 7. 审查建议

第三方审查应重点判断“素材复用证据是否充分”，而不是审查玩法代码是否可写。玩法本身在 Unity 中可重建，但如果原始素材不能稳定复用，这个项目的成立基础就不存在。

建议审查顺序：

1. 先看 `asset-acquisition-gate-summary.json`，确认资产获取层为 `AssetAcquisitionEvidenceReady` 且 `canGrantDevelopmentUsability=false`。
2. 再看 `original-asset-reuse-gate-summary.json`，确认根门禁仍是 `StaticReadyNeedsUnityFocusedValidation` 且 `canStartGameplayMainline=false`。
3. 再看 `unity-focused-validation-readiness-summary.json`，确认 `ReadyForUnityFocusedValidation` 只代表下一步可跑 Unity。
4. 再看 `minimum-vertical-slice-assets.json`，逐项核查 8 个 blocker 是否有真实 Unity 证据。
5. 最后看具体类别证据，区分“已导出/已预览/已 staging”和“Unity 中真实可见/可听/可开发”。

不应得出的结论：

- 不能把当前状态表述为 StellaSora 素材已达成复用门槛。
- 不能说 Hades-like 玩法主线可以开始。
- 不能说角色、敌人、场景、UI、音频已经是 `DevelopmentUsable`。
- 不能说可以批量导入正式工程。
- 不能把 Android 资料视为已经补齐 PC 缺依赖。
- 不能把 AssetStudio/AssetRipper/Il2CppDumper/wwiser/vgmstream 教程或工具能力本身当成 StellaGaia 的 Unity 开发可用证据。

当前审查建议是：接受资产获取层可行性较高这个前提，但继续要求 Unity 聚焦验收和 manifest 回写重跑；不要继续扩大静态分析和批量导出。验收若失败，应按 Stop 或局部替代路线止损。
