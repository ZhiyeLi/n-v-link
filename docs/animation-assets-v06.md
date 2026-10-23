# N VLink 0.6 / 0.6.1 使用说明 · User guide

## 启动与入口 · Getting started

双击 `Play.cmd`（工作区为 `build/Play.cmd`）启动 0.6.1。在首页选择“自定义贴图”，顶部有“外观预设”和“PRTS 抓取”。游戏和资源导入不需要安装 Python 或 Godot。保留包内 `tools/ffmpeg.exe`，用于转换动画。

Run `Play.cmd` (`build/Play.cmd` in the workspace) to start 0.6.1. Open **自定义贴图 / Custom Textures** from the home screen. **外观预设 / Appearance presets** and **PRTS 抓取 / Resource download** are at the top. Playing and resource import require neither Python nor Godot. Keep the bundled `tools/ffmpeg.exe` for animation conversion.

## 完整外观预设 · Complete appearance presets

每套全量包明确包含所有静态槽和动作槽、默认外观定义、原版动作/无人机轮廓数据、12 部位骨骼配置、显示尺寸、播放参数和背景。没有自定义素材的槽明确采用默认，不从上一套预设继承。

Each complete package explicitly defines every static/action slot, builtin defaults, original motion/drone silhouette data, all 12 part configurations, display scales, playback settings and background. Unmodified slots explicitly select defaults; nothing is inherited from the previous preset.

| 预设 / Preset | 玩家 / Player | 定轨无人机 / Patrol | 追踪无人机 / Scout | 激光无人机 / Laser |
| --- | --- | --- | --- | --- |
| 默认 / Default | 原版小人 / Original ninja | 默认 / Default | 默认 / Default | 默认 / Default |
| **i能tv** | 能天使 / Exusiai | 源石虫 / Originium Slug | Texas 移动 GIF，冲刺 1.65× / Move GIF, dash at 1.65× | 蕾缪安静态 Idle / Lemuen static Idle |
| **白金·临光** | 白金 / Platinum | 源石虫 / Originium Slug | 临光重定向跑动，冲刺 1.65× / Nearl retargeted run, dash at 1.65× | 默认 / Default |

能天使、白金使用校准关节的分部位图像和 N 的动作；临光是重定向 N 跑步后烘焙的 32 帧动画，不是方舟原版动画。其他实体和背景均为默认。

Exusiai and Platinum use calibrated part images driven by N animation. Nearl uses a baked 32-frame retargeted N run, not original Arknights animation playback. Other entities and backgrounds use defaults.

0.6.1 外观修正：白金头部位于身体和四肢之后；临光身体与裙摆遮住双腿。启动或读取旧预设时会修正原始示例资源，保留用户的关节调整、播放参数和其他自定义图像。

0.6.1 appearance fix: Platinum's head draws behind the torso and limbs; Nearl's torso and skirt cover both legs. Starting the game or loading an older preset repairs the original example assets while preserving edited anchors, playback settings and unrelated custom images.

1. **读取整包 / Load**：选择预设，整体替换工作外观，包括清除上一套独有的素材、骨骼、尺寸和背景。先保存想保留的修改。
   Select a preset to replace the entire working appearance, including defaults. Save edits you want to keep before switching.
2. **新建副本 / New copy**：填写新名称，完整复制当前工作包及素材并切换到副本。重名会提示失败；修改副本不影响原包。
   Enter a new name to copy all current definitions and assets into an independent package and switch to it. Duplicate names are rejected. Editing the copy leaves the original unchanged.
3. **保存到此名称 / Save**：保存当前工作外观到所填名称，同名包会更新。平时编辑会自动存到工作副本，但只有此操作更新预设库快照。
   Save the working appearance under the entered name, replacing an existing package of that name. Regular edits persist in the working copy; this button updates the library snapshot.
4. **导入包 / Import .nvskin**：读取整包到独立工作目录；若要留在预设库，再点保存。**导出包 / Export .nvskin**：把当前完整外观导出为一个文件，可在另一台电脑导入，无需原素材目录。
   Import loads a complete package into an independent working directory; save it to keep it in the library. Export creates one self-contained file, importable on another computer without the original source folder.

预设库在 `userdata/presets/`，工作副本在 `userdata/preset_working/`，`userdata/active_skin.json` 记录当前包。重启恢复工作副本。旧版 `userdata/skins/` 保留，不强制覆盖已有外观。`.nvskin` 是带 SHA256 校验的 ZIP；缺少槽位、素材损坏或路径非法时拒绝加载，并保留当前外观。默认图形由包内指定版本的 N 绘制器显示；包不含可执行脚本。

The library is in `userdata/presets/`, working copies in `userdata/preset_working/`, and the active pointer in `userdata/active_skin.json`. Restarting restores the working copy. Legacy `userdata/skins/` files and existing appearances are preserved. An `.nvskin` file is a ZIP with SHA256 asset hashes. Incomplete definitions, corrupt assets and invalid paths are rejected without changing the current appearance. Default graphics use the package's versioned N renderer; packages contain no executable scripts.

## 游戏内 PRTS 抓取 · In-game PRTS downloader

打开“PRTS 抓取”，输入角色名（例如 `蕾缪安`、`白金`、`临光`）或完整角色页网址，点击“开始”。默认抓取默认皮肤的正面、背面、基建模型；勾选“全部皮肤”可下载该角色索引列出的全部皮肤。支持取消、打开保存目录。

Open **PRTS 抓取**, enter a character name (for example `蕾缪安`, `白金`, `临光`) or full character page URL, then **开始 / Download**. The default outfit's front, back and base models are fetched by default. Enable **全部皮肤 / All outfits** to fetch all indexed outfits. You can cancel or open the destination folder.

逐文件显示进度和结果，并汇总“成功 / 部分失败 / 失败 / 已取消”、文件数和错误数。失败显示 HTTP 状态或网络/TLS 错误。部分失败不会报成全部成功，下载不会阻塞界面。每次写入 `resources.json`，记录来源、SHA256、文件清单和错误，保留成功下载的文件。

The panel logs progress and results per file and reports **success / partial failure / failed / cancelled**, file counts and errors. Failures show HTTP status or network/TLS details. Partial downloads never report full success and the UI stays responsive. Each run writes `resources.json` with sources, SHA256 hashes, downloaded files and errors. Successful files are retained.

工作区下载到 `sources/input pictures/<角色>/`；独立便携包下载到游戏旁的同名目录。原始模型在 `raw-models/` 下。这里已原生实现脚本的角色模型抓取流程，不依赖外部 Python；下载不会自动改变当前外观。

Workspace downloads go to `sources/input pictures/<character>/`; a standalone portable build uses that folder beside the executable. Raw models are under `raw-models/`. The script's character-model workflow now runs natively without external Python. Downloading does not change the active appearance.

**抓取成功不等于动画已导入。** PRTS 小人是实时渲染的 Spine 模型，下载得到 `.skel/.atlas/.png`，不是现成 GIF。0.6.1 尚无通用 Spine 播放或自动骨骼重定向。请在 [PRTS 角色页](https://prts.wiki/w/%E8%95%BE%E7%BC%AA%E5%AE%89) 模型查看器导出 GIF/WebM，或使用已有 GIF/MP4，再导入动作槽。可以请求任意角色；缺少模型索引、网站限制或格式变化会报错，不承诺所有皮肤和骨骼自动转换。

**Successful downloading does not mean animations have been imported.** PRTS renders Spine models live; downloads contain `.skel/.atlas/.png`, not ready-made GIFs. Version 0.6.1 does not provide a general Spine player or automatic rig retargeting. Export GIF/WebM from the model viewer on a [PRTS character page](https://prts.wiki/w/%E8%95%BE%E7%BC%AA%E5%AE%89), or use existing GIF/MP4 clips, then import them into action slots. Any character can be requested; missing indexes, website restrictions and format changes produce errors. Automatic conversion of every outfit and skeleton is not supported.

## 绑定动作 · Assigning animation slots

选择“场景实体”或“角色动画”，选动作槽，点击“导入图片 / 动画”。倍速和循环按槽保存。“大小”只改变显示，不影响碰撞和物理。未配置状态依次回退：当前动作 → 移动 → 待机 → 静态后备 → 默认图形。缺少玩家死亡动画时保留布娃娃。

Select **场景实体 / Scene entities** or **角色动画 / Character animation**, choose an action and **导入图片 / 动画 / Import image or animation**. Speed and looping are saved per slot. Display size never changes collisions or physics. Missing actions fall back through current action → move → idle → base appearance → builtin graphics. Missing player death animation preserves the ragdoll.

| 对象 / Object | 动作槽 / Action slots |
| --- | --- |
| 定轨无人机 / Patrol | 移动 / Move |
| 侦察（追踪）无人机 / Scout | 移动、冲刺 / Move, dash |
| 激光、机枪无人机 / Laser, chaingun | 移动、前摇、射击、冷却 / Move, charge, fire, cooldown |
| 地面守卫 / Guard | 待机、追击 / Idle, dash |
| 冲撞方块 / Thwump | 待机、冲撞、回位 / Idle, dash, return |
| 炮塔 / Turret | 待机、前摇、射击、冷却 / Idle, charge, fire, cooldown |
| 导弹底座 / Launcher | 待机、发射 / Idle, fire |
| 导弹 / Rocket | 飞行 / Fly |
| 地雷、金块 / Mine, gold | 待机 / Idle |
| 弹性方块、弹射器 / Bounce block, launch pad | 待机、触发 / Idle, active |
| 玩家整套动画 / Player | 待机、跑动、上升、下落、贴墙上升、滑墙、蹬墙、死亡 / Idle, run, rise, fall, wall climb, wall slide, wall jump, death |
| 地图背景 / Background | 静态后备、循环动画 / Base image, idle animation |

槽位跟随现有模拟状态，不添加新的物理阶段。机枪冷却等预留槽在 AI 没有相应状态时不自动触发。每个实例有独立时钟，状态改变从头播放，暂停冻结。素材时长不改变攻击前摇或操作。

Slots follow existing simulation states without introducing physics phases. Reserved slots such as chaingun cooldown do not trigger until the AI supplies that state. Instances have independent clocks, restart on state changes and freeze on pause. Clip length does not change attack timing or controls.

## 格式、背景和骨架 · Formats, backgrounds and rigs

- **PNG/JPG/WebP**：静态图最多 24 MiB、单边 8192 像素，裁透明边并等比归一化。12 个角色部位仍使用静态图，“关节与比例”可改锚点、尺寸与偏移。整套动图放“角色动画”，不要拆到肢体槽。
  Static images: up to 24 MiB and 8192 pixels per side, alpha-cropped and scaled proportionally. The 12 player parts use static images. **关节与比例 / Joints and proportions** edits anchors, size and offsets. Put whole-character clips in **角色动画**, not limb slots.
- **GIF/MP4/WebM**：单文件最多 128 MiB。单位动画最多 12 秒、24 FPS、192×192；背景最多 8 秒、12 FPS、512×384。超长拒绝并保留已有素材。所有帧共享裁剪边界，GIF 按时间重采样。
  Animated media: up to 128 MiB. Units: up to 12 seconds, 24 FPS, 192×192. Backgrounds: up to 8 seconds, 12 FPS, 512×384. Longer clips are rejected without replacing existing assets. Frames share crop bounds; GIF timing is resampled.
- GIF 透明区域保留；普通 MP4 背景保留，不自动抠像。“地图背景”等比铺满，在地形后面绘制，并跟随地图镜头。
  GIF transparency is preserved. Ordinary MP4 backgrounds remain; there is no automatic background removal. Map backgrounds fill proportionally behind terrain and follow the map camera.
- 清空槽位只清除此槽，可能仍显示后备。恢复全部默认重置当前工作包的素材、骨骼调整与尺寸；预设库快照只有保存时才更新。
  Clearing removes only that slot, so fallback art may remain. Reset all restores the working appearance, rig and sizes. Library snapshots update only when saved.

## 文件夹自动匹配 · Automatic folder matching

同一角色的动作放独立文件夹，例如 `sources/input pictures/德克萨斯/`。选择对象，点击“自动匹配动作文件夹”。按文件名匹配 Idle/Default/Relax → 待机，Move → 移动（玩家为跑动），Attack/Skill → 射击，以及 run、dash、charge、cooldown、wall_jump 等动作名。角色名不限；多角色混放会拒绝；缺失动作会提示。

Put one character's action files in a separate folder, such as `sources/input pictures/德克萨斯/`. Select the target and **自动匹配动作文件夹 / Match action folder**. Filenames map Idle/Default/Relax to idle, Move to move (run for players), Attack/Skill to fire, plus run, dash, charge, cooldown and wall_jump. Character names are unrestricted; mixed-character folders are rejected and missing actions are reported.

方舟角色通常缺少跳跃、蹬墙动作，需要另行提供或使用后备。文件名匹配不会自动生成动作。

Arknights characters often lack jumping and wall-jumping clips. Supply them separately or use fallbacks. Filename matching does not generate missing animation.

## 可选命令行 · Optional command line

工作区仍保留脚本，仅此方式需要 Python。脚本另有页面图片筛选、本地 HTML 和单文件下载参数，见 `--help`。游戏面板不要求命令行操作。

The workspace retains the Python script, with extra page-image filtering, local HTML and single-asset options; see `--help`. The game panel does not require command-line use.

```powershell
python tools/prts_resources.py 蕾缪安
python tools/prts_resources.py 德克萨斯 --list-only
python tools/prts_resources.py 蕾缪安 --skin "*"
```

## 验证与来源 · Verification and attribution

0.6.1 测试覆盖预设独立复制、同名保存、贴图/动画/骨骼/背景往返、跨包清理、重启恢复、损坏包拒绝，以及下载成功、部分失败、HTTP 错误、异常索引和取消。真实图形界面下载临光默认模型 9 文件成功，并显示不存在页面的 HTTP 404。回归为 `game/tests/test_v061.gd`；截图为 `logs/v061-*.png`。

Tests cover independent copies, overwriting saves, texture/animation/rig/background round trips, full replacement, restart persistence, corrupt-package rejection, and download success, partial failure, HTTP errors, malformed indexes and cancellation. The real graphical UI downloaded all 9 Nearl default-model files and displayed HTTP 404 for a missing page. See `game/tests/test_v061.gd` and `logs/v061-*.png`.

本作品仅供学习、交流讨论，禁止商业用途，详见 `LICENSE` 与 `NOTICE.md`。示例图像归鹰角网络及相应权利人，项目源码许可不覆盖它们；来源和哈希在各角色 `resources.json` 中。FFmpeg 许可证及对应源码信息随包放在 `licenses/FFMPEG-*`。原作地图和动作数据属于 Metanet Software。

This project is for non-commercial learning and discussion only; see `LICENSE` and `NOTICE.md`. Artwork belongs to Hypergryph and respective rights holders and is excluded from the source license; sources and hashes are in each character's `resources.json`. FFmpeg licensing and corresponding source information ship in `licenses/FFMPEG-*`. Original maps and motion data belong to Metanet Software.
