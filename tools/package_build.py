"""Copy attribution and create a portable launcher. Does not fetch any files."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
build = ROOT / "build"
(build / "licenses").mkdir(exist_ok=True)
(build / "licenses/N14-ORIGINAL-LICENSE.txt").write_bytes((ROOT / "licenses/N14-ORIGINAL-LICENSE.txt").read_bytes())
(build / "licenses/PRTS-TEST-ASSETS.txt").write_bytes((ROOT / "sources/prts/ATTRIBUTION.txt").read_bytes())
(build / "Play.cmd").write_text(
    '@echo off\nsetlocal\n'
    'set "APPDATA=%~dp0userdata\\engine"\n'
    'set "LOCALAPPDATA=%~dp0userdata\\cache"\n'
    'if not exist "%APPDATA%" mkdir "%APPDATA%"\n'
    'if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"\n'
    'start "" "%~dp0NVLink-0.5.1.exe" --log-file "%~dp0userdata\\game.log"\n'
    'endlocal\n', encoding="ascii")
(build / "README.txt").write_text(
    "N VLink / N 1.4 Godot reconstruction prototype\n\n"
    "Run Play.cmd to keep runtime data beside the game.\n"
    "Open Settings > Key Bindings to configure every gameplay shortcut.\n"
    "Settings: unlimited/custom render FPS, VSync, fullscreen, maximum speed, acceleration, collision display, volume.\n"
    "Default player speed: 216 pixels/sec, 5% above the floor guard (205.714 pixels/sec).\n"
    "Maximum speed (60-400) and acceleration multiplier (0.25-4.0) are independent.\n"
    "Home > Custom Textures: import PNG/JPG/WebP for 13 entity types and 12 player parts.\n"
    "Imports are cropped, scaled to fit and copied into userdata/skins/. Physics stays unchanged.\n"
    "Apply Two Test Cases installs Exusiai player parts and an Originium Slug patrol-drone image.\n"
    "Character Parts > Joints and Proportions: drag joint anchors, set proportional image size and connection offsets.\n"
    "Exusiai uses measured source skeleton anchors; images keep their aspect ratio.\n"
    "These are static images on retargeted N animation, not Arknights animation or AI playback.\n"
    "Map zoom: 1x-4x in the top bar. Default 1.5x follows the player; Full Map resets zoom.\n"
    "Camera API supports follow, fixed, group targets and live custom view providers.\n"
    "Original campaign: 100 episodes, 500 maps. Maps copyright Metanet Software.\n"
    "Animation joint markers and zap-drone silhouettes are derived from the supplied N 1.4 archive.\n"
    "Version 0.5.1: corrected run retargeting; 120ms jump buffer, 100ms wall grace and fast-tap input edges.\n"
    "One press gives one jump. Hold extends height but does not auto-hop on wall contact.\n"
    "This is an independent reconstruction, not a bit-exact emulator.\n"
    "Enemy AI, corner collision and movement feel still need reference-play validation.\n"
    "Map editing and replay playback are not implemented in this stage.\n"
    "Godot and original game attribution are in licenses/.\n", encoding="utf-8")
exe = build / "NVLink-0.5.1.exe"
(build / "build-info.json").write_text(json.dumps({
    "version": "0.5.1-prototype", "executable": exe.name, "engine": "4.7.2.stable", "physics_hz": 120,
    "sha256": hashlib.sha256(exe.read_bytes()).hexdigest(),
    "campaign_maps": 500,
}, indent=2), encoding="utf-8")
print(f"Packaged {exe} ({exe.stat().st_size:,} bytes)")
