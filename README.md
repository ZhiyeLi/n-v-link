# N VLink

**仅供学习、交流讨论，禁止商业用途。公开源码采用非商业使用条款，不属于 OSI 标准开源许可。** 见 [LICENSE](LICENSE) 与 [第三方素材声明](NOTICE.md)。第三方内容保留原权利人的许可，不因本声明获得额外授权。

**For non-commercial learning and discussion only. This is a source-available project under non-commercial terms, not an OSI-approved open-source license.** See [LICENSE](LICENSE) and [NOTICE.md](NOTICE.md). Third-party rights and licenses remain separate.

[下载 0.6.1 / Download](https://github.com/ZhiyeLi/n-v-link/releases/tag/v0.6.1) · [发布说明 / Release notes](docs/releases/v0.6.1.md)

N 1.4 的 Windows / Godot 4.7.2 重构原型，当前版本 **0.6.1**。当前交付用于试玩与手感校准，还没有达到逐关验收、高度还原完成的状态。

A Windows / Godot 4.7.2 reconstruction of N 1.4, version **0.6.1**. This is a playable prototype; full level-by-level fidelity validation remains ongoing.

**中英双语使用说明 / Chinese–English user guide:** [0.6 / 0.6.1 使用说明](docs/animation-assets-v06.md)。便携包也附有 `README.txt` 和 `USER-GUIDE-ZH-EN.md`。The portable build includes both documents.

0.6.1 在“自定义贴图”内加入 PRTS 原生抓取面板，逐文件反馈成功与失败，不需要 Python。新增完整外观包 `.nvskin` 的复制、保存、读取与导入/导出；内置“默认”“i能tv”“白金·临光”。每套都定义全部槽位、默认资源、骨骼、动画、尺寸与背景，整体加载，不继承上一套。下载原始 Spine 模型不等于自动转换成可播放动作。

Version 0.6.1 adds a native PRTS downloader with per-file success/failure feedback and no Python dependency. Complete `.nvskin` appearance packages can be copied, saved, loaded, imported and exported. Bundled presets are Default, i能tv and 白金·临光. Every package defines all slots, defaults, rig data, animations, sizes and background; loading replaces the whole appearance. Downloading raw Spine models does not automatically convert them into playable clips.

## 启动

双击 `build/Play.cmd`，启动 `NVLink-0.6.1.exe`。启动器把引擎缓存、日志、设置及自定义贴图保留在 `build/userdata/` 内，不需要安装 Godot。导入 GIF/MP4/WebM 使用包内 `tools/ffmpeg.exe`，请保留此文件。旧版可执行文件保留供对照，启动器已切换到新版；原来的进度与设置继续保留。

Run `build/Play.cmd` to launch `NVLink-0.6.1.exe`. Runtime data stays in `build/userdata/`; progress and settings are preserved. Keep `tools/ffmpeg.exe` for GIF/MP4/WebM imports. No Godot installation is needed. See the bilingual guide above for all controls, settings and appearance workflows.

0.6 新增实体状态动画槽、整套玩家动画、GIF/MP4/WebM 导入、文件夹动作名自动匹配及自定义地图背景。侦察无人机示例为 Texas：移动 GIF，冲刺暂复用移动并加速至 1.65 倍；激光无人机示例为蕾缪安静态 Idle 图，四个动作槽已开放。原始输入固定在 `sources/input pictures/`。PRTS 下载脚本已实测抓取蕾缪安的正面、背面、基建模型资源；原始 Spine 自动转成游戏动画尚未实现。使用方法、格式限制与完整槽位表见 [0.6 动画资源说明](docs/animation-assets-v06.md)。

0.5.3 区分暗红激光无人机与黑色机枪无人机。激光发现玩家后锁定方向并停机，显示 0.75 秒预警线，随后沿固定方向发射持续 2 秒的光束，冷却 1 秒后恢复移动。预警期间可以躲开，发射期间穿越光束仍会死亡；墙壁与关闭的门阻挡射线。时序依据与回归检查见 [激光无人机修正](docs/laser-drone.md)。

0.5.2 撤回上一轮容错调整，完整恢复 0.5.1 的 120 毫秒跳跃缓存、100 毫秒离墙宽限和侧墙判定。蹬墙动作从 250 毫秒缩短到约 83 毫秒后进入普通跳跃动画。R（可重绑）改为自杀，完整布娃娃和爆炸断肢各 50%；死亡后使用确认键（默认 Enter）或“重试”按钮重新开始。敌对单位碰撞产生短促电弧；地雷与导弹爆炸产生大量红色喷溅；摔落死亡产生少量喷溅，液滴会落地并留下短暂痕迹。死亡提示保持在顶部，场景继续模拟。

0.5.1 修正自定义角色跑动时左右肢体的角度映射，不再把不对称的站姿角度差叠加到跑步动作。其他姿态和玩家关节配置保留。蹬墙增加 **120 毫秒按键缓存**和 **100 毫秒离墙宽限**，碰到新墙时不再受上次跳跃延长状态阻挡，快速点按通过独立输入边沿保留。每次按键仅触发一次，按住不自动连续蹬墙。完整循环预览见 [跑动检查](docs/v051-run.png)。

0.5 修正了角色贴图按固定骨长拉伸的问题。“角色部位 → 关节与比例”支持拖动关节锚点、设置等比尺寸与连接偏移；能天使示例已根据原始骨骼重新校准。守卫、方块等默认图形在贴图页恢复正常预览。游戏上方可调整 1–4 倍地图缩放，默认 1.5 倍跟随角色，保留固定、多目标和自定义镜头接口。交替蹬墙恢复上升动量累积，下降时仍有较强滑墙阻力。操作与接口见 [0.5 技术记录](docs/anchors-camera-and-wall-jumps.md)，外观见 [动作对照](docs/v05-presentation.png)。

0.4 将默认最大移速设为 **216 像素/秒**，比地面守卫快 **5%**，并允许在设置中调整最大移速和开启碰撞箱显示。首页新增“自定义贴图”，支持 13 类场景实体与 12 个角色部位的 PNG/JPG/WebP 导入、自动尺寸归一化、动作预览和恢复默认。点击“应用两个测试用例”可试用能天使分部位贴图和源石虫定轨无人机外观。操作与原始数值依据见 [0.4 技术记录](docs/skins-speed-and-collisions.md)，效果见 [贴图动作预览](docs/v04-presentation.png)。

0.3 修复了左侧肢体被背景遮住的问题，使用从原版提取的 72 帧跑步轨迹和速度驱动的空中姿态，区分贴墙上升、滑墙与蹬墙。定轨无人机与带天线的侦察无人机恢复不同图形和索敌行为。贴墙阻力增强；普通死亡保持完整布娃娃，地雷/导弹爆炸拆开四肢。死亡提示位于顶部，场景继续运行。原版依据、实现差异和测试见 [本轮技术记录](docs/animation-drones-and-death.md)，图形对照见 [动作与死亡预览](docs/v03-presentation.png)。

- 在“设置 → 按键绑定”中修改向左、向右、跳跃、自杀、暂停/返回、下一关/确认、切换全屏的全部游戏快捷键。每项最多三个键，支持清空、冲突提示和恢复默认。
- 初始绑定提供方向键/A/D、Shift/空格/Z、R、Esc、Enter、F11，玩家可全部更改。封面不再显示键位表；游戏内提示跟随当前绑定。
- 跳跃按住延长、松开缩短；角色朝向由最后一次方向按键决定，松开、惯性和两个方向同时按下不会自行翻转朝向。
- 100 组原版关卡全部开放，每组 5 关；每组初始 90 秒，金块增加 2 秒。

设置中可以选择无限渲染帧率，或手动输入 1–1000 FPS 上限。垂直同步独立控制，开启后仍受显示器刷新率限制。默认无限帧率、关闭垂直同步。

“最大移速”范围 60–400 像素/秒，默认 216。“加速度倍率”范围 0.25–4.00，默认 1.00。地面与空中按键加速度一起调整，只改变达到目标速度的快慢。**各倍率下都能达到所选最大移速**，不会因低倍率与持续阻力相抵而降低最终速度。松键摩擦、跳跃和重力不随倍率修改。弹射器等关卡机关仍可提供独立冲量。

0.2 将基础地面/空中加速度从 240/160 降到 180/120 像素/秒²，0.4 仍保留。原版守卫追击速度换算为 205.714286 像素/秒；本轮按“玩家略快”的要求将玩家速度从 0.3 的 144 调至 216，而非沿用原版玩家的 200。早期调整记录见 [移动与动画技术记录](docs/movement-and-animation.md)。

帧率、音量、加速度、按键、恢复默认等设置不改变窗口模式或尺寸。只有全屏开关和玩家绑定的全屏键会切换模式；退出全屏会恢复原来的最大化状态或自定义窗口尺寸。失焦会释放操作并暂停。

## 当前范围

- 独立的 120 Hz 物理计算与渲染插值，不沿用原版内部的 40 Hz 模拟步长。
- 原版 500 张内置地图、原版关卡组顺序、全部 34 种地形编号。
- 跑动、变高度跳跃、蹬墙、滑墙、斜坡、摔落死亡、倒计时、金块、出口开关。
- 基础实体行为：地雷、无人机、炮塔、追踪导弹、地面守卫、冲撞方块、弹性方块、弹射器、单向平台、三类门。
- 关卡选择、暂停、重试、组内关卡切换、完成记录、设置持久化。
- 12 个独立部位的角色层级：头、躯干、双侧大臂/小臂、大腿/小腿/脚。待机、跑动、急停、起跳、上升、下落、贴墙上升、滑墙、蹬墙分别使用不同姿态；每个部位可独立接入贴图。
- 自定义图片导入、裁透明边与等比归一化、预览、持久化和恢复默认；两组 PRTS 图像样例可一键应用。
- 玩家/地形/实体/危险/触发范围的碰撞图层，设置中可开关。
- 等比角色贴图、可编辑关节锚点与连接偏移；模型大小独立于碰撞箱。
- 地图局部渲染、角色跟随和动态镜头策略接口；HUD 保持固定尺寸。

尚未实现：地图编辑器、回放录制或播放。输入位、模拟版本、地图哈希、固定随机种子和配置接口已分离，方便以后接入回放；**不代表已经兼容原版回放文件**。

## 还原程度与待验收项

地图数据来自用户提供的 `n_v1pc.zip`，没有凭图重画。跳跃与重力以原版数值换算为参考，新步长下独立积分；0.2 的横向跑速与加速响应按试玩反馈主动调低，属于有意修改。

当前仍是重构原型：移动积分、碰撞解算顺序、圆弧的 32 段近似、弹性方块、敌人寻路与射击时序都可能与原版有差异。自动检查验证载入和基础规则，不等于 500 张地图已逐关通关。下一轮应针对原版录像/实测轨迹校准，尤其是斜坡接缝、冲撞方块夹击、无人机转向、导弹追踪与炮塔瞄准。

## 本地开发

从工作区根目录执行：

```powershell
# 编辑器、模板都来自 sources 中的本地下载包
python tools/prepare_sources.py

# 原版数据检查与地图提取；不执行原版游戏代码
python tools/inspect_reference.py
python tools/extract_campaign.py
python tools/extract_reference_poses.py

# 启动、检查与导出；工具为子进程设置工作区内的缓存路径
python tools/godot.py --editor
python tools/godot.py --headless --script res://tests/test_simulation.gd
python tools/godot.py --headless --script res://tests/test_ui.gd
python tools/godot.py --headless --script res://tests/test_controls.gd
python tools/godot.py --headless --script res://tests/test_v03.gd
python tools/godot.py --headless --script res://tests/test_v04.gd
python tools/godot.py --headless --script res://tests/test_v05.gd
powershell -ExecutionPolicy Bypass -File tools/build.ps1
```

也可以用便携 Godot 打开 `game/project.godot`。直接打开编辑器时，引擎自身的运行时目录由 Godot 决定；使用上述包装脚本可以把它们保留在工作区。

主要文件：

| 路径 | 用途 |
| --- | --- |
| `game/core/ninja.gd` | 玩家加速度、重力、跳跃、接触状态 |
| `game/core/ragdoll.gd` | 完整/分离布娃娃的固定步长物理 |
| `game/core/terrain.gd` | 地形编号、轮廓、碰撞、视线 |
| `game/core/simulation.gd` | 实体、计时、关卡规则与未来回放配置边界 |
| `game/core/settings.gd` | 设置与进度的验证、保存 |
| `game/core/skins.gd` | 图片归一化、贴图槽与本地保存 |
| `game/core/bindings.gd` | 可修改的键位、冲突检查与 InputMap 接口 |
| `game/core/window_mode.gd` | 显式全屏切换与窗口状态恢复 |
| `game/main.gd` | 菜单、设置、游戏流程 |
| `game/view/ninja_rig.gd` | 关节层级、双段肢体解算、动作状态 |
| `game/view/ninja_part.gd` | 每个角色部位独立的图形/贴图插槽 |
| `game/view/ninja_animation.gd` | 原版动作轨迹采样与分段关节解算 |
| `game/view/drone_icon.gd` | 两类电击无人机的原版轮廓与状态表现 |
| `game/view/skin_screen.gd` | 自定义贴图界面、选择器与预览 |
| `game/view/collision_view.gd` | 实际碰撞几何的显示层 |
| `game/view/rig_layout.gd` | 等比图像、关节锚点与骨骼重定位 |
| `game/view/rig_editor.gd` | 锚点拖拽与尺寸编辑界面 |
| `game/view/map_camera.gd` | 跟随、固定、多目标和自定义镜头策略 |
| `game/view/map_view.gd` | 独立地图视口和运行时镜头接口 |
| `game/data/campaign.json` | 提取的原版 500 关 |
| `sources/n14_reference/` | 本地参考检查结果 |
| `logs/tests.json` | 自动验证报告 |

## 验证

模拟测试覆盖全部地图载入及短时运行、地形轮廓、平地接缝、长短跳、蹬墙、摔落死亡、加速度、摩擦、金块、出口、倒计时和设置保存。

UI 测试覆盖关卡选择、暂停、修改帧率、修改加速度、改键/松键/冲突/保存、继续、死亡、重试及下一关。控制回归测试验证多个倍率下的地面与空中最大速度、短按位移、朝向和分部位动画。真实 Windows 图形环境验证自定义尺寸、最大化、全屏、全屏快捷键焦点优先级和改键后的全屏行为。帧率测试在 Godot 的 60、144、1000 FPS 帧调度下输入同一组按物理步编号指定的按键，比较完整运动轨迹哈希。

沙箱内启动 Godot 时可能输出无法读取 Windows 根证书存储的消息。离线检查不依赖网络；0.6.1 的 PRTS 抓取在实际 Windows 图形环境中另行实测 HTTPS 成功与失败反馈。

## 来源

原作、原版关卡、提取的关节轨迹和无人机轮廓属于 Metanet Software，参见 https://www.thewayoftheninja.org/ 。用户提供的两个 ZIP 是游戏发行包，不能据此认定它们是完整开源项目。此处 GDScript 为独立重构；提取资源保留原作者权利与原始许可文本。

Godot 使用 MIT 许可，导出包的 `licenses/` 中包含引擎与第三方声明。窗口中文使用 Windows 系统字体，没有复制或打包系统字体文件。教程 ZIP 未取得；当前构建不依赖这两个文件。

能天使与源石虫测试图像来自 PRTS，原图版权归鹰角网络及关联权利人。原始下载和哈希记录在 `sources/prts/`，署名随包放入 `build/licenses/PRTS-TEST-ASSETS.txt`。仅将静态部件用于既有 N 骨骼的贴图测试，没有打包 Spine 运行时。

便携目录的引擎行为参考：[Godot 数据路径文档](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html) 与 [Windows 路径实现](https://github.com/godotengine/godot/blob/4.7/platform/windows/os_windows.cpp)。所有本项目下载、解包、提取和构建产物都放在当前工作区。
