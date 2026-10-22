"""Run the workspace's portable Godot with process-local data/cache paths."""
from pathlib import Path
import os
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / "sources/godot/Godot_v4.7.2-stable_win64_console.exe"


def main():
    env = os.environ.copy()
    for key, folder in (("APPDATA", "roaming"), ("LOCALAPPDATA", "cache"), ("TEMP", "temp"), ("TMP", "temp")):
        location = ROOT / "sources/runtime" / folder
        location.mkdir(parents=True, exist_ok=True)
        env[key] = str(location)
    log = ROOT / "logs/godot.log"
    log.parent.mkdir(exist_ok=True)
    arguments = sys.argv[1:]
    if "--log-file" in arguments:
        index = arguments.index("--log-file")
        log = Path(arguments[index + 1])
        if not log.is_absolute(): log = ROOT / log
        log = log.resolve()
        if not log.is_relative_to(ROOT):
            raise ValueError("Keep Godot logs inside the workspace")
        del arguments[index:index + 2]
        log.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.call([str(ENGINE), "--path", str(ROOT / "game"),
                              "--log-file", str(log), *arguments], env=env, cwd=ROOT)
    # Godot can return zero even if a dependent script failed to compile.
    if result == 0 and log.exists() and "SCRIPT ERROR" in log.read_text(encoding="utf-8", errors="replace"):
        return 1
    return result


if __name__ == "__main__":
    raise SystemExit(main())
