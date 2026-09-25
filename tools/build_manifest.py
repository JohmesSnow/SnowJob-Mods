"""Build manifest.json from tools/pack.json.

Downloads each Thunderstore package once (cached in tools/.cache), records the SHA-256 of the
package and of every file the updater installs, and hashes the files kept in this repo.
Run from anywhere:  python tools/build_manifest.py
"""
import hashlib
import io
import json
import os
import sys
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", ".cache")
OWNER, REPO, BRANCH = "JohmesSnow", "SnowJob-Mods", "main"
RAW = f"https://raw.githubusercontent.com/{OWNER}/{REPO}/{BRANCH}/"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check_rel(path: str) -> str:
    p = path.replace("\\", "/")
    if p.startswith("/") or ":" in p or any(part == ".." for part in p.split("/")):
        sys.exit(f"unsafe path in pack.json: {path}")
    return p


def thunderstore_zip(package: str, version: str) -> tuple[str, bytes]:
    owner, name = package.split("-", 1)
    url = f"https://thunderstore.io/package/download/{owner}/{name}/{version}/"
    os.makedirs(CACHE, exist_ok=True)
    cached = os.path.join(CACHE, f"{package}-{version}.zip")
    if not os.path.exists(cached):
        print(f"  downloading {package} {version}")
        req = urllib.request.Request(url, headers={"User-Agent": "SnowJob-Mods manifest builder"})
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        with open(cached, "wb") as f:
            f.write(data)
    with open(cached, "rb") as f:
        return url, f.read()


def build_mod(mod: dict) -> dict:
    src = mod["source"]
    out = {k: mod[k] for k in ("id", "name", "author", "side", "page")}
    files = []
    if src["type"] == "thunderstore":
        out["version"] = src["version"]
        url, data = thunderstore_zip(src["package"], src["version"])
        out["source"] = {"type": "zip", "url": url, "sha256": sha256(data)}
        z = zipfile.ZipFile(io.BytesIO(data))
        entries = {n.replace("\\", "/"): n for n in z.namelist() if not n.endswith(("/", "\\"))}
        for m in mod["map"]:
            frm, to = check_rel(m["from"]), check_rel(m["to"])
            picks = [(e, to + e[len(frm):]) for e in entries if e.startswith(frm)] if frm.endswith("/") else [(frm, to)]
            if not picks or any(e not in entries for e, _ in picks):
                sys.exit(f"{mod['id']}: '{frm}' not found in {src['package']} {src['version']}")
            for e, dest in sorted(picks):
                f = {"from": entries[e], "to": check_rel(dest), "sha256": sha256(z.read(entries[e]))}
                if m.get("onlyIfMissing"):
                    f["onlyIfMissing"] = True
                files.append(f)
    elif src["type"] == "repo":
        out["version"] = mod["version"]
        out["source"] = {"type": "files", "base": RAW}
        for m in mod["map"]:
            frm, to = check_rel(m["from"]), check_rel(m["to"])
            base = os.path.join(ROOT, frm)
            if frm.endswith("/"):
                picks = []
                for dirpath, _, names in os.walk(base):
                    for n in names:
                        rel = os.path.relpath(os.path.join(dirpath, n), ROOT).replace("\\", "/")
                        picks.append((rel, to + rel[len(frm):]))
            else:
                picks = [(frm, to)]
            for rel, dest in sorted(picks):
                with open(os.path.join(ROOT, rel), "rb") as fh:
                    files.append({"from": rel, "to": check_rel(dest), "sha256": sha256(fh.read())})
    else:
        sys.exit(f"{mod['id']}: unknown source type {src['type']}")
    out["files"] = files
    return out


def main():
    with open(os.path.join(ROOT, "tools", "pack.json"), encoding="utf-8") as f:
        spec = json.load(f)
    manifest = {
        "schema": 1,
        "name": spec["name"],
        "game": spec["game"],
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "repoBase": RAW,
        "mods": [],
        "configs": [],
        "remove": [check_rel(p) for p in spec.get("remove", [])],
    }
    for mod in spec["mods"]:
        print(mod["id"])
        manifest["mods"].append(build_mod(mod))
    for c in spec.get("configs", []):
        frm = check_rel(c["from"])
        with open(os.path.join(ROOT, frm), "rb") as fh:
            manifest["configs"].append({"from": frm, "to": check_rel(c["to"]), "sha256": sha256(fh.read())})
    seen = {}
    for m in manifest["mods"]:
        for f in m["files"]:
            key = f["to"].lower()
            if key in seen:
                sys.exit(f"two mods install {f['to']}: {seen[key]} and {m['id']}")
            seen[key] = m["id"]
    with open(os.path.join(ROOT, "manifest.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    n = sum(len(m["files"]) for m in manifest["mods"])
    print(f"manifest.json: {len(manifest['mods'])} mods, {n} files, {len(manifest['configs'])} configs")


if __name__ == "__main__":
    main()
