"""Package the portable Windows build, bilingual instructions and attribution."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
build = ROOT / "build"
VERSION = "0.6.1"
(build / "licenses").mkdir(exist_ok=True)
for filename in ["LICENSE", "NOTICE.md"]:
    shutil.copy2(ROOT / filename, build / filename)
shutil.copy2(ROOT / "licenses/N14-ORIGINAL-LICENSE.txt", build / "licenses/N14-ORIGINAL-LICENSE.txt")
shutil.copy2(ROOT / "sources/prts/ATTRIBUTION.txt", build / "licenses/PRTS-TEST-ASSETS.txt")
(build / "tools").mkdir(exist_ok=True)
shutil.copy2(ROOT / "sources/media_tools/ffmpeg.exe", build / "tools/ffmpeg.exe")
for filename in ["FFMPEG-LICENSE.txt", "FFMPEG-README.txt"]:
    shutil.copy2(ROOT / "sources/media_tools" / filename, build / "licenses" / filename)
(build / "licenses/V06-TEST-ASSETS.txt").write_text(
    "Texas Move GIF and Lemuen Idle PNG supplied by the user from PRTS / Arknights.\n"
    "Platinum and Nearl default setup-pose assets downloaded from PRTS for v0.6.1.\n"
    "https://prts.wiki/w/%E7%99%BD%E9%87%91\n"
    "https://prts.wiki/w/%E4%B8%B4%E5%85%89\n"
    "Platinum uses calibrated parts; Nearl uses a baked N run, not original Spine animation.\n"
    "Copyright Hypergryph and respective rights holders. Non-commercial discussion/test examples.\n"
    "These assets are excluded from the project's source license. See NOTICE.md.\n",
    encoding="utf-8")
exe = build / f"NVLink-{VERSION}.exe"
(build / "Play.cmd").write_text(
    '@echo off\nsetlocal\n'
    'set "APPDATA=%~dp0userdata\\engine"\n'
    'set "LOCALAPPDATA=%~dp0userdata\\cache"\n'
    'if not exist "%APPDATA%" mkdir "%APPDATA%"\n'
    'if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"\n'
    f'start "" "%~dp0{exe.name}" --log-file "%~dp0userdata\\game.log"\n'
    'endlocal\n', encoding="ascii")
shutil.copy2(ROOT / "docs/animation-assets-v06.md", build / "USER-GUIDE-ZH-EN.md")
(build / "README.txt").write_text(
    """N VLink 0.6.1 — 使用说明 / Quick start

仅供学习、交流讨论，禁止商业用途。自主源码与第三方素材的许可范围见 LICENSE、NOTICE.md。
For non-commercial learning and discussion only. See LICENSE and NOTICE.md for source and third-party terms.

双击 Play.cmd；保留 tools/ffmpeg.exe。无需安装 Python 或 Godot。
Run Play.cmd; keep tools/ffmpeg.exe. No Python or Godot installation is required.

完整中英双语说明：USER-GUIDE-ZH-EN.md（可用任意文本编辑器阅读）。
Full Chinese/English guide: USER-GUIDE-ZH-EN.md (readable in any text editor).

首页 > 自定义贴图 > 外观预设：读取整包、新建副本、保存、导入/导出 .nvskin。
Home > Custom Textures > Appearance presets: load, copy, save, import/export .nvskin.
内置：默认、i能tv、白金·临光。新建复制全部内容，读取整体替换。
Included: Default, i能tv, 白金·临光. New copies include everything; loading replaces everything.
修改自动存入工作副本；点击“保存到此名称”更新预设库。切换前先保存想保留的修改。
Edits persist in the working copy. Save updates the library. Save wanted edits before switching.

首页 > 自定义贴图 > PRTS 抓取：输入角色名/网址，开始下载，查看逐文件结果。
Home > Custom Textures > PRTS download: enter a character name/URL, download, inspect per-file results.
保存到 sources/input pictures/<角色>/，有成功、部分失败、失败和取消提示。
Saved under sources/input pictures/<character>/, with success, partial, failure and cancellation feedback.
抓取的是 Spine 原始模型；并非一键转动画。请导出 GIF/MP4/WebM 后绑定动作槽。
Downloads are raw Spine models, not automatically converted animation. Export GIF/MP4/WebM and bind action slots.

设置 > 按键绑定：可更改全部快捷键。默认 R 自杀，Enter 死亡后重试，F11 全屏。
Settings > Key Bindings: remap every shortcut. Defaults: R suicide, Enter retry after death, F11 fullscreen.
方向键/A/D 移动，Shift/空格/Z 跳跃；按住延长跳跃，连续蹬墙需要重新按键。
Arrow keys/A/D move; Shift/Space/Z jump. Hold extends jump height; repeated wall jumps require fresh presses.
设置可改帧率上限、垂直同步、最大移速、加速度、碰撞箱显示、音量。
Settings include frame cap, VSync, maximum speed, acceleration, collision display and volume.
默认最大移速 216；最大移速与加速度独立。外观不改变碰撞与操作参数。
Default top speed is 216; speed and acceleration are independent. Appearance never changes gameplay parameters.
游戏上方可调整地图缩放，默认跟随玩家；原版 100 组 / 500 张地图。
Adjust map zoom in the top bar; the camera follows the player. 100 episodes / 500 original maps.

userdata/ 保存进度、设置、预设库和工作副本。旧版文件保留供迁移。
userdata/ stores progress, settings, preset library and working copies. Legacy files remain for migration.
本项目仍为独立重构原型；地图编辑器、回放录制/播放尚未实现。
This is an independent reconstruction prototype. Map editing and replay recording/playback are not implemented.
资源归属和许可证见 licenses/ 与 NOTICE.md；方舟示例用于非商业交流讨论，原权利不变。
See licenses/ and NOTICE.md. Arknights examples are for non-commercial discussion; original rights remain.
""", encoding="utf-8-sig")
(build / "build-info.json").write_text(json.dumps({
    "version": VERSION + "-prototype", "revision": "appearance-layer-fix-1", "executable": exe.name, "engine": "4.7.2.stable",
    "physics_hz": 120, "sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
    "campaign_maps": 500, "preset_schema": 1, "builtin_presets": ["默认 / Default", "i能tv", "白金·临光"],
}, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"Packaged {exe} ({exe.stat().st_size:,} bytes)")
