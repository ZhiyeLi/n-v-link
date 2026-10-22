"""Fetch explicitly selected PRTS reference assets into this workspace."""
from pathlib import Path
import hashlib
import json
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'sources/prts'
OUT.mkdir(parents=True, exist_ok=True)


def fetch(url, filename):
    dest = (OUT / filename).resolve()
    if not dest.is_relative_to(OUT.resolve()):
        raise ValueError('Destination must stay under sources/prts')
    request = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0', 'Referer': 'https://prts.wiki/'})
    with urllib.request.urlopen(request, timeout=25) as response:
        data = response.read(40 * 1024 * 1024 + 1)
    if len(data) > 40 * 1024 * 1024: raise ValueError('Asset exceeds 40 MiB')
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    manifest = OUT / 'downloads.json'
    records = json.loads(manifest.read_text('utf-8')) if manifest.exists() else {}
    records[filename] = {'url': url, 'sha256': hashlib.sha256(data).hexdigest(), 'bytes': len(data)}
    manifest.write_text(json.dumps(records, indent=2, ensure_ascii=False), encoding='utf-8')
    print(filename, len(data), 'bytes')


if __name__ == '__main__':
    if len(sys.argv) == 3:
        fetch(sys.argv[1], sys.argv[2])
    else:
        fetch('https://prts.wiki/w/%E8%83%BD%E5%A4%A9%E4%BD%BF', 'exusiai.html')
        fetch('https://prts.wiki/w/%E6%BA%90%E7%9F%B3%E8%99%AB', 'slug.html')
