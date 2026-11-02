"""Downloads only the files `plumb doctor` reads, for each app in apps.tsv,
pinned to the default branch's current commit. No cloning.

Usage: python3 -I study/2026-11-launch/fetch.py <out-dir>
Writes <out-dir>/<owner>_<repo>/<repo paths...> and study/2026-11-launch/apps_pinned.tsv.
Apps already in apps_pinned.tsv are fetched at their pinned commit (so a rerun
gets exactly the files the study checked); new apps are pinned to the current
commit and appended. Resumable: apps already in <out-dir> are skipped. Stops cleanly when
the unauthenticated GitHub API quota (60/hour, ~2 calls per app) runs out.
Commit hashes come from `git ls-remote` (no API call); files from
raw.githubusercontent.com.
"""

import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://api.github.com/repos/"
RAW = "https://raw.githubusercontent.com/"


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "plumb-launch-study"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def api(path):
    return json.loads(get(API + path))


def raw(repo, sha, path):
    try:
        return get(f"{RAW}{repo}/{sha}/{path}")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def tree_paths(repo, sha, app):
    """All blob paths under the app folder (relative to the repo root)."""
    tree_sha = sha
    if app != ".":
        parent, name = os.path.split(app)
        listing = api(f"{repo}/contents/{parent}?ref={sha}")
        tree_sha = next(e["sha"] for e in listing if e["name"] == name)
    tree = api(f"{repo}/git/trees/{tree_sha}?recursive=1")
    if tree.get("truncated"):
        sys.exit(f"tree truncated for {repo}/{app}; narrow it by hand")
    prefix = "" if app == "." else app + "/"
    return [prefix + e["path"] for e in tree["tree"] if e["type"] == "blob"]


def wanted(paths, app, manifest_text):
    """The subset of [paths] that plumb reads."""
    a = "" if app == "." else app + "/"
    out = []
    for p in paths:
        rel = p[len(a):]
        d, base = os.path.split(rel)
        if rel in ("pubspec.yaml", "pubspec.lock",
                   "ios/Runner.xcodeproj/project.pbxproj"):
            out.append(p)
        elif d == "ios/Runner" and (base.endswith(".entitlements")
                                    or (base.startswith("Info") and base.endswith(".plist"))):
            out.append(p)
        elif re.fullmatch(r"android/app/src/[^/]+/AndroidManifest\.xml", rel):
            out.append(p)
        elif re.match(r"android/app/src/main/(kotlin|java)/", rel) and \
                re.search(r"\.(kt|java)$", base):
            # Only sources whose class name the main manifest mentions
            # (a superset of the launcher activity plumb looks for).
            name = base.rsplit(".", 1)[0]
            if manifest_text and re.search(r"[.\"]" + re.escape(name) + r"\"", manifest_text):
                out.append(p)
    return out


def workspace_root_files(repo, sha, app, pubspec):
    """pubspec.yaml + pubspec.lock of the workspace root, if the app is a member."""
    if not re.search(r"^resolution:\s*workspace", pubspec, re.M):
        return {}
    d = app
    while d not in ("", "."):
        d = os.path.dirname(d)
        base = "" if d == "" else d + "/"
        text = raw(repo, sha, base + "pubspec.yaml")
        if text and re.search(rb"^workspace:", text, re.M):
            return {base + "pubspec.yaml": text,
                    base + "pubspec.lock": raw(repo, sha, base + "pubspec.lock")}
    return {}


def head_commit(repo):
    """Commit of the default branch (HEAD), without using the API quota."""
    out = subprocess.run(["git", "ls-remote", f"https://github.com/{repo}.git", "HEAD"],
                         capture_output=True, text=True, check=True).stdout
    return out.split()[0]


def main(out):
    pinned_path = os.path.join(HERE, "apps_pinned.tsv")
    header = "repo\tapp\tcommit\tstars\tpushed\tfiles\n"
    pinned = {}
    if os.path.exists(pinned_path):
        for l in open(pinned_path).readlines()[1:]:
            if l.strip():
                row = l.rstrip("\n").split("\t")
                pinned[row[0]] = row[2]
    else:
        open(pinned_path, "w").write(header)
    for line in open(os.path.join(HERE, "apps.tsv")):
        if not line.strip():
            continue
        repo, app = line.rstrip("\n").split("\t")
        root = os.path.join(out, repo.replace("/", "_"))
        if os.path.isdir(root):
            continue
        try:
            info = None if repo in pinned else api(repo)
            sha = pinned.get(repo) or head_commit(repo)
            paths = tree_paths(repo, sha, app)
        except urllib.error.HTTPError as e:
            if e.code in (403, 429):
                sys.exit(f"GitHub API quota used up at {repo}; rerun later to resume.")
            raise
        a = "" if app == "." else app + "/"
        manifest = raw(repo, sha, a + "android/app/src/main/AndroidManifest.xml")
        files = {p: None for p in wanted(paths, app, manifest.decode() if manifest else "")}
        pubspec = raw(repo, sha, a + "pubspec.yaml").decode()
        files.update(workspace_root_files(repo, sha, app, pubspec))
        total = 0
        for p, data in sorted(files.items()):
            data = data if data is not None else raw(repo, sha, p)
            if data is None:
                continue
            dest = os.path.join(root, p)
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(data)
            total += len(data)
        if info is not None:
            row = [repo, app, sha, str(info["stargazers_count"]),
                   info["pushed_at"][:10], str(len(files))]
            with open(pinned_path, "a") as f:
                f.write("\t".join(row) + "\n")
        print(f"{repo:40} {len(files):3} files {total // 1024:5} KB  {sha[:10]}")


if __name__ == "__main__":
    main(sys.argv[1])
