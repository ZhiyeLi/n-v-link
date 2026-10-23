"""Fetch public PRTS character assets; keep source URLs/hashes and offline reports.

No browser automation or access-control bypass. A 403 is recorded and reported.
Rendered GIF/WebM/MP4 exports can instead be placed in sources/input pictures.
"""
from __future__ import annotations
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "sources/input pictures"
MEDIA = {".png", ".jpg", ".jpeg", ".webp", ".gif", ".webm", ".mp4", ".atlas", ".skel"}
HOSTS = {"prts.wiki", "static.prts.wiki", "media.prts.wiki", "torappu.prts.wiki"}


def safe_url(url: str) -> str:
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname not in HOSTS or parts.username:
        raise ValueError("Only public HTTPS PRTS asset hosts are accepted")
    return urllib.parse.urlunsplit((parts.scheme, parts.netloc,
                                   urllib.parse.quote(urllib.parse.unquote(parts.path), safe="/():@"),
                                   parts.query, ""))


def fetch(url: str, destination: Path) -> dict:
    url = safe_url(url)
    req = urllib.request.Request(url, headers={"User-Agent": "NVLink-ResourceImporter/0.6 (local user requested download)",
                                               "Referer": "https://prts.wiki/"})
    with urllib.request.urlopen(req, timeout=25) as response:
        safe_url(response.url)
        data = response.read(128 * 1024 * 1024 + 1)
    if len(data) > 128 * 1024 * 1024:
        raise ValueError("Asset exceeds 128 MiB")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return {"url": url, "file": destination.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def discover(text: str, page: str) -> list[str]:
    text = html.unescape(text).replace("\\/", "/")
    candidates = re.findall(r'''(?:https:)?//[^\s"'<>\\]+|(?:href|src|data-src)=["']([^"']+)["']''', text)
    # Separate URL scan avoids losing the full-match branch to regex groups.
    candidates += re.findall(r'''(?:https:)?//[^\s"'<>\\]+''', text)
    found = set()
    for candidate in candidates:
        if not candidate: continue
        url = urllib.parse.urljoin(page, candidate)
        try: url = safe_url(url)
        except ValueError: continue
        if Path(urllib.parse.urlsplit(url).path).suffix.lower() in MEDIA:
            found.add(url)
    return sorted(found)


def model_specs(meta: dict, skin: str):
    for outfit, views in meta.get("skin", {}).items():
        if skin != "*" and outfit != skin: continue
        for facing, spec in views.items():
            stem = spec.get("file", "")
            if not stem or ".." in stem or stem.startswith("/"): continue
            folder = re.sub(r'[<>:"/\\|?*]', "_", outfit+"-"+facing)
            yield folder, safe_url(urllib.parse.urljoin(meta["prefix"], stem))


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("character", help="PRTS character name or page URL")
    parser.add_argument("--html", type=Path, help="Parse a page saved by the user instead of requesting the website")
    parser.add_argument("--asset", action="append", default=[], help="An exact public PRTS asset URL (repeatable)")
    parser.add_argument("--match", default="", help="Only download filenames containing this text")
    parser.add_argument("--max-assets", type=int, default=40)
    parser.add_argument("--list-only", action="store_true", help="Save the resource index without downloading assets")
    parser.add_argument("--skin", default="默认", help="Outfit name, or * for all outfits (default: 默认)")
    parser.add_argument("--images", action="store_true", help="Also download ordinary page images; default prefers character models")
    args = parser.parse_args(argv)
    name = urllib.parse.unquote(args.character.rstrip("/").split("/")[-1])
    name = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", name).strip(". ")
    if not name: parser.error("A character name is required")
    page = args.character if args.character.startswith("https://") else "https://prts.wiki/w/"+urllib.parse.quote(args.character)
    page = safe_url(page)
    dest = INPUT / name
    dest.mkdir(parents=True, exist_ok=True)
    report = {"character": name, "page": page, "downloads": [], "errors": [], "candidates": [],
              "note": "PRTS Spine previews are rendered in the browser. Raw atlas/skel files are archived, not converted to gameplay animation. Export GIF/WebM/MP4 for automatic action-slot import. Rights remain with the original owners."}
    text = ""
    if args.html:
        text = args.html.read_text("utf-8")
        (dest / "page.html").write_text(text, encoding="utf-8")
    elif not args.asset:
        try:
            report["page_download"] = fetch(page, dest / "page.html")
            text = (dest / "page.html").read_text("utf-8")
        except (OSError, ValueError) as error:
            report["errors"].append({"url": page, "error": str(error)})
    urls = sorted(set(args.asset + discover(text, page)))
    model = re.search(r'id=["\']spine-root["\'][^>]*data-id=["\']([^"\']+)', text)
    if model:
        model_id = model.group(1)
        if not re.fullmatch(r'char_[a-zA-Z0-9_]+',model_id): raise ValueError("Invalid model ID")
        meta_url = "https://torappu.prts.wiki/assets/char_spine/"+model_id+"/meta.json"
        try:
            report["model_index"] = fetch(meta_url, dest / "model-index.json")
            meta = json.loads((dest/"model-index.json").read_text("utf-8"))
            specs = list(model_specs(meta,args.skin))
            report["models"] = [{"name":label,"base_url":url} for label,url in specs]
            if not args.list_only:
                for label, url in specs:
                    if len(report["downloads"])+3>min(200,args.max_assets): break
                    folder = dest / "raw-models" / label
                    basename = urllib.parse.urlsplit(url).path.rsplit("/",1)[-1]
                    for ext in [".skel",".atlas"]:
                        record=fetch(url+ext,folder/(basename+ext))
                        record["file"]=str((folder/(basename+ext)).relative_to(dest))
                        report["downloads"].append(record)
                        time.sleep(0.4)
                    atlas=(folder/(basename+".atlas")).read_text("utf-8")
                    for texture in re.findall(r'^([^\r\n]+\.png)\s*$',atlas,re.MULTILINE):
                        if Path(texture).name != texture or ".." in texture: raise ValueError("Invalid atlas page")
                        record=fetch(urllib.parse.urljoin(url,texture),folder/texture)
                        record["file"]=str((folder/texture).relative_to(dest))
                        report["downloads"].append(record)
                        time.sleep(0.4)
            if not args.images: urls=[]
        except (OSError, ValueError, KeyError) as error:
            report["errors"].append({"url":meta_url,"error":str(error)})
    if args.match: urls = [url for url in urls if args.match in urllib.parse.unquote(url)]
    report["candidates"] = urls
    selected = urls[:max(0, min(200, args.max_assets))]
    if not args.list_only:
        for url in selected:
            filename = urllib.parse.unquote(urllib.parse.urlsplit(url).path.rsplit("/",1)[-1])
            filename = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", filename)
            # Different directories can reuse a basename (e.g. atlas pages).
            filename = hashlib.sha256(url.encode()).hexdigest()[:8] + "-" + filename
            try:
                report["downloads"].append(fetch(url, dest / filename))
            except (OSError, ValueError) as error:
                report["errors"].append({"url": url, "error": str(error)})
            time.sleep(0.4)
    report["unprocessed_count"] = max(0, len(urls)-len(selected))
    (dest / "resources.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    (dest / "README.txt").write_text(report["note"]+"\nSource: "+page+"\n", encoding="utf-8")
    print(json.dumps({"folder":str(dest),"found":len(urls),"downloaded":len(report["downloads"]),"errors":report["errors"]}, ensure_ascii=True))
    return 2 if report["errors"] or not (urls or report.get("models")) else 0


if __name__ == "__main__":
    raise SystemExit(main())
