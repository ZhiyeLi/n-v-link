"""Publish a verified Windows archive using the configured GitHub account.

Uses the Git Credential Manager account already configured on this machine.
Credentials stay in memory and are never printed or written to files.
"""
from pathlib import Path
import json
import hashlib
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OWNER = "ZhiyeLi"
TAG = "v0.6.1"
NOTICE = ("**仅供学习、交流讨论，禁止商业用途。自主源码采用非商业使用条款；第三方素材保留原权利人与许可，声明不构成额外授权。**\n\n"
          "**For non-commercial learning and discussion only. Original source uses non-commercial terms; third-party assets retain their owners' rights and licenses. This notice grants no additional third-party rights.**\n\n"
          "[LICENSE](https://github.com/ZhiyeLi/n-v-link/blob/main/LICENSE) · [NOTICE](https://github.com/ZhiyeLi/n-v-link/blob/main/NOTICE.md)")


def credential():
    result = subprocess.run(
        ["git", "credential", "fill"],
        input="protocol=https\nhost=github.com\n\n",
        text=True,
        capture_output=True,
        check=True,
    )
    values = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    return values["password"]


def request(method, url, token, payload=None, content_type="application/vnd.github+json"):
    data = None if payload is None else (payload if isinstance(payload, bytes) else json.dumps(payload).encode("utf-8"))
    headers = {"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "User-Agent": "NVLink-release"}
    if data is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=600) as response:
            body = response.read()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        if error.code == 404 and method == "GET":
            return None
        detail = error.read().decode("utf-8", errors="replace")[:400]
        raise RuntimeError(f"GitHub API {method} {url} returned {error.code}: {detail}") from None


def api(method, path, token, payload=None):
    return request(method, "https://api.github.com" + path, token, payload)


def account_and_repo(name, token):
    account = api("GET", "/user", token)
    if account["login"] != OWNER:
        raise RuntimeError("GitHub account changed; refusing to publish")
    repo = api("GET", f"/repos/{OWNER}/{name}", token)
    return repo


def create_repo(name, token):
    if account_and_repo(name, token) is not None:
        raise RuntimeError("Repository already exists; refusing to replace or guess its contents")
    repo = api("POST", "/user/repos", token, {
        "name": name,
        "description": "N 1.4 Godot reconstruction prototype for private development",
        "private": True,
        "auto_init": False,
    })
    if repo["full_name"] != f"{OWNER}/{name}" or not repo["private"]:
        raise RuntimeError("Repository creation returned an unexpected target or visibility")
    print("CREATED_PRIVATE_REPOSITORY:", repo["html_url"])


def publish_release(name, token):
    repo = account_and_repo(name, token)
    if repo is None or not repo.get("permissions", {}).get("push"):
        raise RuntimeError("Target repository is missing or not writable")
    status = subprocess.run(["git", "-c", "safe.directory=" + ROOT.as_posix(), "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True, check=True).stdout
    if status.strip():
        raise RuntimeError("Commit source changes before publishing")
    digest = subprocess.run(
        ["git", "-c", "safe.directory=" + str(ROOT).replace("\\", "/"), "rev-parse", "HEAD"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.strip()
    ref = api("GET", f"/repos/{OWNER}/{name}/git/ref/tags/{TAG}", token)
    if ref is None or ref["object"]["sha"] != digest:
        raise RuntimeError("The remote release tag does not match the local commit")
    branch = api("GET", f"/repos/{OWNER}/{name}/branches/{repo['default_branch']}", token)
    if branch["commit"]["sha"] != digest:
        raise RuntimeError("The default branch does not match the release source")
    releases = api("GET", f"/repos/{OWNER}/{name}/releases?per_page=100", token)
    existing = next((entry for entry in releases if entry["tag_name"] == TAG), None)
    info = json.loads((ROOT / "build/build-info.json").read_text(encoding="utf-8"))
    if info["version"] != TAG[1:] + "-prototype":
        raise RuntimeError("Build metadata differs from release version")
    archive = ROOT / f"build/NVLink-{TAG}-Windows.zip"
    with zipfile.ZipFile(archive) as zipped:
        if zipped.testzip() is not None:
            raise RuntimeError("Archive CRC validation failed")
        if hashlib.sha256(zipped.read(info["executable"])).hexdigest() != info["sha256"]:
            raise RuntimeError("Archive executable does not match build metadata")
        for required in ["LICENSE", "NOTICE.md", "USER-GUIDE-ZH-EN.md", "tools/ffmpeg.exe"]:
            if required not in zipped.namelist():
                raise RuntimeError("Missing release file: " + required)
    checksums = ROOT / "build/SHA256SUMS.txt"
    checksums.write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n" + info["sha256"] + "  " + info["executable"] + "\n", encoding="ascii")
    notes = (ROOT / f"docs/releases/{TAG}.md").read_text(encoding="utf-8-sig")
    if existing is None:
        release = api("POST", f"/repos/{OWNER}/{name}/releases", token, {
            "tag_name": TAG,
            "target_commitish": digest,
            "name": "N VLink " + TAG[1:],
            "body": notes,
            "draft": True,
            "prerelease": True,
        })
    else:
        release = existing
    assets = api("GET", f"/repos/{OWNER}/{name}/releases/{release['id']}/assets", token)
    for path in [archive, checksums]:
        asset = next((entry for entry in assets if entry["name"] == path.name), None)
        if asset is None:
            print("UPLOADING:", path.name, path.stat().st_size, flush=True)
            upload_url = f"https://uploads.github.com/repos/{OWNER}/{name}/releases/{release['id']}/assets?" + urllib.parse.urlencode({"name": path.name})
            asset = request("POST", upload_url, token, path.read_bytes(), "application/zip" if path.suffix == ".zip" else "text/plain")
        expected = "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()
        if asset["size"] != path.stat().st_size or asset.get("digest") != expected:
            raise RuntimeError("Uploaded asset size/digest verification failed: " + path.name)
        print("VERIFIED_ASSET:", asset["browser_download_url"], expected, flush=True)
    if release["draft"]:
        release = api("PATCH", f"/repos/{OWNER}/{name}/releases/{release['id']}", token, {"draft": False, "prerelease": True})
    print("RELEASE:", release["html_url"], flush=True)


def make_public(name, token):
    repo = account_and_repo(name, token)
    if repo is None or not repo.get("permissions", {}).get("admin"):
        raise RuntimeError("Repository admin permission is required")
    latest = api("GET", f"/repos/{OWNER}/{name}/releases/tags/{TAG}", token)
    if latest is None or latest["draft"]:
        raise RuntimeError("Publish and verify the release before changing visibility")
    # Preserve older releases and add the requested notice before exposing them.
    for release in api("GET", f"/repos/{OWNER}/{name}/releases?per_page=100", token):
        if "禁止商业用途" not in (release.get("body") or ""):
            api("PATCH", f"/repos/{OWNER}/{name}/releases/{release['id']}", token, {"body": NOTICE + "\n\n---\n\n" + (release.get("body") or "")})
    repo = api("PATCH", f"/repos/{OWNER}/{name}", token, {
        "private": False,
        "description": "N 1.4 Godot reconstruction. Source available for non-commercial learning and discussion; third-party rights retained.",
    })
    if repo["private"] or repo["visibility"] != "public":
        raise RuntimeError("Repository did not become public")
    print("PUBLIC_REPOSITORY:", repo["html_url"], flush=True)


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ["create", "release", "public"]:
        raise SystemExit("Usage: python tools/github_publish.py create|release|public REPOSITORY_NAME")
    name = sys.argv[2]
    if not name or not all(character.isascii() and (character.isalnum() or character in "-._") for character in name):
        raise SystemExit("Invalid GitHub repository name")
    token = credential()
    if sys.argv[1] == "create":
        create_repo(name, token)
    elif sys.argv[1] == "release":
        publish_release(name, token)
    else:
        make_public(name, token)


if __name__ == "__main__":
    main()
