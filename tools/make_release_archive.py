"""Package the tested Windows build without caches, settings, or downloads."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
INFO = json.loads((BUILD / "build-info.json").read_text(encoding="utf-8"))
EXE = BUILD / INFO["executable"]
assert hashlib.sha256(EXE.read_bytes()).hexdigest() == INFO["sha256"]

relative_files = [
    Path(INFO["executable"]),
    Path("Play.cmd"),
    Path("README.txt"),
    Path("LICENSE"),
    Path("NOTICE.md"),
    Path("USER-GUIDE-ZH-EN.md"),
    Path("build-info.json"),
    Path("tools/ffmpeg.exe"),
    *sorted(Path("licenses").joinpath(path.name) for path in (BUILD / "licenses").iterdir() if path.is_file()),
]
archive_path = BUILD / "NVLink-v0.6.1-Windows.zip"
with zipfile.ZipFile(archive_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for relative in relative_files:
        archive.write(BUILD / relative, relative.as_posix())
print(json.dumps({
    "archive": str(archive_path),
    "bytes": archive_path.stat().st_size,
    "sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
    "files": [str(path) for path in relative_files],
}, ensure_ascii=False))
