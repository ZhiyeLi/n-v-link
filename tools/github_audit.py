"""Inspect the currently authenticated GitHub account without printing credentials."""
import json
import subprocess
import urllib.request


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


def get(path, token):
    request = urllib.request.Request(
        "https://api.github.com" + path,
        headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json", "User-Agent": "NVLink-release-audit"},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return json.load(response)


def main():
    token = credential()
    account = get("/user", token)
    print("AUTHENTICATED_ACCOUNT:", account["login"], account["html_url"])
    page = 1
    while True:
        repos = get("/user/repos?affiliation=owner,collaborator,organization_member&sort=updated&per_page=100&page=" + str(page), token)
        for repo in repos:
            print("REPO:", json.dumps({
                "full_name": repo["full_name"],
                "private": repo["private"],
                "push": repo.get("permissions", {}).get("push"),
                "default_branch": repo["default_branch"],
                "description": repo.get("description"),
                "updated_at": repo["updated_at"],
                "html_url": repo["html_url"],
            }, ensure_ascii=False))
        if len(repos) < 100:
            break
        page += 1


if __name__ == "__main__":
    main()
