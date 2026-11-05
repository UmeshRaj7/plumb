"""Computes the study numbers from results/<version>/*.json + apps_pinned.tsv
+ verdicts.tsv (hand verification). Prints Markdown tables for REPORT.md.

Usage: python3 -I study/2026-11-launch/stats.py
"""

import collections
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
VERSIONS = ("0.0.1", "0.1.0", "0.1.1")
LATEST = VERSIONS[-1]
FLAGGED = ("missing", "warning", "error")


def load_apps():
    rows = [l.rstrip("\n").split("\t") for l in open(os.path.join(HERE, "apps_pinned.tsv"))]
    return [dict(zip(rows[0], r)) for r in rows[1:] if r and r[0]]


def load_result(version, repo):
    path = os.path.join(HERE, "results", version, repo.replace("/", "_") + ".json")
    return json.load(open(path))


def load_verdicts():
    """finding id + repo -> verdict (real | docs | false_positive), from hand checks."""
    path = os.path.join(HERE, "verdicts.tsv")
    out = {}
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        repo, fid, verdict, note = line.rstrip("\n").split("\t")
        out[(repo, fid)] = (verdict, note)
    return out


def precision(per_verdict):
    right = per_verdict["real"] + per_verdict["docs"]
    total = right + per_verdict["false_positive"]
    return f"{right}/{total} = {100 * right / total:.0f}%" if total else "n/a"


def platforms(result):
    missing = {f["platform"] for f in result["findings"]
               if f["package"] is None and "not found" in f["message"]}
    return "+".join(p for p in ("ios", "android") if p not in missing)


def main():
    apps = load_apps()
    verdicts = load_verdicts()
    print(f"Apps: {len(apps)}\n")

    # Per-app table.
    print("| # | App | ⭐ | Platforms | Plugins with recipes | "
          + " | ".join(f"{v} ✗/⚠" for v in VERSIONS) + f" | {LATEST} ✓ | {LATEST} ℹ |")
    print("|---|---|---|---|---|" + "---|" * (len(VERSIONS) + 2))
    for i, app in enumerate(apps, 1):
        results = [load_result(v, app["repo"]) for v in VERSIONS]
        new = results[-1]
        flagged = lambda r: sum(r["summary"][k] for k in FLAGGED)
        checked = [p["name"] for p in new["packages"] if p["status"] == "checked"]
        print(f"| {i} | {app['repo']} | {int(app['stars']) / 1000:.1f}k | {platforms(new)} | "
              f"{', '.join(checked)} | " + " | ".join(str(flagged(r)) for r in results) + " | "
              f"{new['summary']['ok']} | {new['summary']['info']} |")

    # Totals per version.
    print("\n| | " + " | ".join(VERSIONS) + " |\n|---|" + "---|" * len(VERSIONS))
    totals = {}
    for v in VERSIONS:
        t = collections.Counter()
        flagged_apps = set()
        per_verdict = collections.Counter()
        unverified = []
        for app in apps:
            r = load_result(v, app["repo"])
            for k in ("ok", "missing", "warning", "info", "error"):
                t[k] += r["summary"][k]
            for f in r["findings"]:
                if f["severity"] in FLAGGED:
                    flagged_apps.add(app["repo"])
                    key = (app["repo"], f["id"])
                    if key in verdicts:
                        per_verdict[verdicts[key][0]] += 1
                    else:
                        unverified.append(key)
        totals[v] = (t, flagged_apps, per_verdict, unverified)
    rows = [
        ("✗ missing", lambda t, a, p: t["missing"]),
        ("⚠ warning", lambda t, a, p: t["warning"]),
        ("✓ ok", lambda t, a, p: t["ok"]),
        ("ℹ info", lambda t, a, p: t["info"]),
        ("Apps with any ✗/⚠", lambda t, a, p: len(a)),
        ("✗/⚠ confirmed real", lambda t, a, p: p["real"]),
        ("✗/⚠ docs-backed, low impact", lambda t, a, p: p["docs"]),
        ("✗/⚠ false positive", lambda t, a, p: p["false_positive"]),
        ("Precision (real or docs ÷ all ✗/⚠)", lambda t, a, p: precision(p)),
    ]
    for label, fn in rows:
        print(f"| {label} | " + " | ".join(str(fn(*totals[v][:3])) for v in VERSIONS) + " |")
    for v in VERSIONS:
        if totals[v][3]:
            print(f"\nUNVERIFIED in {v}: {totals[v][3]}")

    # Plugin usage across apps (latest packages list).
    usage = collections.Counter()
    for app in apps:
        for p in load_result(LATEST, app["repo"])["packages"]:
            usage[(p["name"], p["status"])] += 1
    print("\n| Plugin (has a recipe) | Apps |\n|---|---|")
    for (name, status), n in sorted(usage.items(), key=lambda x: (-x[1], x[0])):
        label = name if status == "checked" else f"{name} ({status})"
        print(f"| {label} | {n} |")

    # Other facts.
    flavors = [a["repo"] for a in apps if any(
        f["id"].endswith("/flavors") for f in load_result(LATEST, a["repo"])["findings"])]
    no_ios = [a["repo"] for a in apps if "ios" not in platforms(load_result(LATEST, a["repo"]))]
    print(f"\nApps in a subfolder (monorepo): {[a['repo'] for a in apps if a['app'] != '.']}")
    print(f"Apps with flavor manifests/plists plumb lists as not checked: {len(flavors)} {flavors}")
    print(f"Android-only (no ios/): {len(no_ios)} {no_ios}")
    stars = sorted(int(a["stars"]) for a in apps)
    print(f"Stars: min {stars[0]}, median {stars[len(stars) // 2]}, max {stars[-1]}, "
          f"total {sum(stars)}")


if __name__ == "__main__":
    main()
