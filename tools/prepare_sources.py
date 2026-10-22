"""Prepare only the supplied portable Godot editor and Windows export templates."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "sources"
VERSION = "4.7.2-stable"


def digest(path):
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def unpack_selected(archive, destination, names):
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as zipped:
        for name in names:
            target = destination / Path(name).name
            info = zipped.getinfo(name)
            if target.exists() and target.stat().st_size == info.file_size:
                continue
            with zipped.open(name) as source, target.open("wb") as output:
                import shutil
                shutil.copyfileobj(source, output)
            print(f"Prepared {target.relative_to(ROOT)}")


def main():
    engine_zip = SOURCES / f"Godot_v{VERSION}_win64.exe.zip"
    template_zip = SOURCES / f"Godot_v{VERSION}_export_templates.tpz"
    engine_dir = SOURCES / "godot"
    unpack_selected(engine_zip, engine_dir, [
        f"Godot_v{VERSION}_win64.exe", f"Godot_v{VERSION}_win64_console.exe"])
    # Godot's documented self-contained mode keeps editor data in this directory.
    (engine_dir / "_sc_").touch()
    unpack_selected(template_zip, SOURCES / "export_templates", [
        "templates/version.txt", "templates/windows_debug_x86_64.exe",
        "templates/windows_release_x86_64.exe",
        "templates/windows_debug_x86_64_console.exe",
        "templates/windows_release_x86_64_console.exe"])
    report = {str(p.relative_to(ROOT)): {"bytes": p.stat().st_size, "sha256": digest(p)}
              for p in [engine_zip, template_zip, ROOT / "n_v1pc.zip"]}
    (SOURCES / "local-checksums.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("All prepared resources are inside the workspace.")


if __name__ == "__main__":
    main()
