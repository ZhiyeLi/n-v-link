"""Create a private repository and publish the verified local Windows archive.

Uses the Git Credential Manager account already configured on this machine.
Credentials stay in memory and are never printed or written to files.
"""
from pathlib import Path
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OWNER = "ZhiyeLi"
TAG = "v0.5.1"


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
    headers = {"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "User-Agent": "NVLink-private-release"}
    if data is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
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
    if repo is None or not repo["private"]:
        raise RuntimeError("Target repository is missing or not private")
    digest = subprocess.run(
        ["git", "-c", "safe.directory=" + str(ROOT).replace("\\", "/"), "rev-parse", "HEAD"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.strip()
    ref = api("GET", f"/repos/{OWNER}/{name}/git/ref/tags/{TAG}", token)
    if ref is None or ref["object"]["sha"] != digest:
        raise RuntimeError("The remote release tag does not match the local commit")
    releases = api("GET", f"/repos/{OWNER}/{name}/releases?per_page=100", token)
    existing = next((entry for entry in releases if entry["tag_name"] == TAG), None)
    info = json.loads((ROOT / "build/build-info.json").read_text(encoding="utf-8"))
    if info["version"] != "0.5.1-prototype":
        raise RuntimeError("Build metadata is not 0.5.1")
    archive = ROOT / "build/NVLink-v0.5.1-Windows.zip"
    notes = (ROOT / "build/release-notes.txt").read_text(encoding="utf-8")
    if existing is None:
        release = api("POST", f"/repos/{OWNER}/{name}/releases", token, {
            "tag_name": TAG,
            "target_commitish": digest,
            "name": "N VLink 0.5.1",
            "body": notes,
            "draft": True,
            "prerelease": True,
        })
    else:
        release = existing
    assets = api("GET", f"/repos/{OWNER}/{name}/releases/{release['id']}/assets", token)
    asset = next((entry for entry in assets if entry["name"] == archive.name), None)
    if asset is None:
        upload_url = f"https://uploads.github.com/repos/{OWNER}/{name}/releases/{release['id']}/assets?" + urllib.parse.urlencode({"name": archive.name})
        asset = request("POST", upload_url, token, archive.read_bytes(), "application/zip")
    if asset["size"] != archive.stat().st_size:
        raise RuntimeError("Uploaded asset size differs from local archive")
    if release["draft"]:
        release = api("PATCH", f"/repos/{OWNER}/{name}/releases/{release['id']}", token, {"draft": False, "prerelease": True})
    print("PRIVATE_RELEASE:", release["html_url"])
    print("RELEASE_ASSET:", asset["browser_download_url"], asset["size"])


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in ["create", "release"]:
        raise SystemExit("Usage: python tools/github_publish.py create|release REPOSITORY_NAME")
    name = sys.argv[2]
    if not name or not all(character.isascii() and (character.isalnum() or character in "-._") for character in name):
        raise SystemExit("Invalid GitHub repository name")
    token = credential()
    if sys.argv[1] == "create":
        create_repo(name, token)
    else:
        publish_release(name, token)


if __name__ == "__main__":
    main()
