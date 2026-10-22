"""Exercise the exported Windows binary, with all outputs inside this workspace."""
from pathlib import Path
import os
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
env = os.environ.copy()
for key, folder in (("APPDATA", "engine"), ("LOCALAPPDATA", "cache")):
    path = ROOT / "build/userdata" / folder
    path.mkdir(parents=True, exist_ok=True)
    env[key] = str(path)
startup = subprocess.STARTUPINFO()
startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
startup.wShowWindow = subprocess.SW_HIDE
screens = ["smoke"] if "--headless" in sys.argv else (["window", "animation", "presentation"] if "--checks" in sys.argv else ["menu", "play", "settings", "bindings", "skins", "rig", "collisions", "death", "explosive"])
if "--prepare-assets" in sys.argv: screens = ["prepare"]
if "--v04-checks" in sys.argv: screens = ["skins-ui", "skin-poses"]
if "--window-check" in sys.argv: screens = ["window"]
if "--skin-window-check" in sys.argv: screens = ["skins-ui"]
if "--poses-v05" in sys.argv: screens = ["poses-v05"]
if "--v05-checks" in sys.argv: screens = ["rig-camera", "poses-v05"]
if "--run-v051" in sys.argv: screens = ["run-v051"]
for argument in sys.argv[1:]:
    if argument.startswith("--screen="):
        screen = argument.split("=", 1)[1]
        if screen not in ["menu", "play", "settings", "bindings", "skins", "rig", "collisions", "death", "explosive"]:
            raise ValueError("Unknown capture screen")
        screens = [screen]
executable = json.loads((ROOT / "build/build-info.json").read_text(encoding="utf-8")).get("executable", "NVLink.exe")
for screen in screens:
    command = [str(ROOT / "build" / executable), "--audio-driver", "Dummy",
               "--log-file", str(ROOT / f"logs/export-{screen}.log"), "--quit-after", "180"]
    if screen in ("window", "animation", "presentation", "prepare", "skins-ui", "skin-poses", "rig-camera", "poses-v05", "run-v051"):
        script = {"window": "test_window.gd", "animation": "animation_gallery.gd", "presentation": "presentation_v03.gd", "prepare": "prepare_demo_skins.gd", "skins-ui": "test_skin_window.gd", "skin-poses": "presentation_v04.gd", "rig-camera": "test_rig_camera_window.gd", "poses-v05": "presentation_v05.gd", "run-v051": "presentation_v051.gd"}[screen]
        command = [str(ROOT / "sources/godot/Godot_v4.7.2-stable_win64_console.exe"),
                   "--path", str(ROOT / "game"), "--audio-driver", "Dummy", "--script", f"res://tests/{script}",
                   "--log-file", str(ROOT / f"logs/export-{screen}.log")]
    elif screen == "smoke":
        command += ["--headless", "--quit-after", "5"]
    else:
        command += ["--", f"--capture={ROOT / f'logs/{screen}.png'}", f"--capture-screen={screen}"]
    result = subprocess.run(command, env=env, cwd=ROOT, startupinfo=startup, timeout=35)
    log = (ROOT / f"logs/export-{screen}.log").read_text(encoding="utf-8")
    print(f"{screen}: exit {result.returncode}")
    print(log)
    expected = "WINDOW_TEST_RESULT:" if screen == "window" else "CAPTURE_RESULT=0"
    if result.returncode or "SCRIPT ERROR" in log or (screen != "smoke" and expected not in log):
        raise SystemExit(1)
