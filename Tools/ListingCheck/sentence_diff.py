#!/usr/bin/env python3
"""Guideline 4.3(a) guard: Just Nurikabe's public text must not share a
sentence with any sibling "Just" app (Just Shikaku's spam rejection was fed by
listings that read alike). Also enforces App Store character limits and the
family's no-publisher / no-dash rules.

    python3 Tools/ListingCheck/sentence_diff.py      # from the nurikabe repo root

Exits 1 on any finding.
"""
import glob, html, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PUZZLES = os.path.dirname(ROOT)

OURS = sorted(glob.glob(os.path.join(ROOT, "AppStore/metadata/*.txt"))
              + glob.glob(os.path.join(ROOT, "AppStore/*.html")))
SIBLINGS = []
for app in ("shikaku", "hashi", "kakuro", "numeriqo"):
    SIBLINGS += glob.glob(os.path.join(PUZZLES, app, "AppStore/metadata/*.txt"))
    SIBLINGS += glob.glob(os.path.join(PUZZLES, app, "AppStore/*.html"))
    SIBLINGS += glob.glob(os.path.join(PUZZLES, app, "docs/STORE.md"))
SIBLINGS += glob.glob(os.path.join(PUZZLES, "numeriqo-site/*.html"))

LIMITS = {"subtitle.txt": 30, "keywords.txt": 100, "promo.txt": 170, "description.txt": 4000}
FORBIDDEN = [r"nikoli", r"[—–]"]   # publisher name; em/en dashes


def text_of(path):
    raw = open(path, encoding="utf-8").read()
    if path.endswith(".html"):
        raw = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", raw, flags=re.S | re.I)
        raw = html.unescape(re.sub(r"<[^>]+>", " ", raw))
    return raw


def sentences(text):
    for s in re.split(r"(?<=[.!?])\s+|\n+", text):
        words = re.findall(r"[a-z0-9×]+", s.lower())
        if len(words) >= 5:
            yield " ".join(words)


def grams(s, n=3):
    w = s.split()
    return {tuple(w[i:i + n]) for i in range(len(w) - n + 1)}


def main():
    failures = []
    theirs = {}
    for path in SIBLINGS:
        for s in sentences(text_of(path)):
            theirs.setdefault(s, os.path.relpath(path, PUZZLES))
    their_grams = [(s, grams(s), src) for s, src in theirs.items()]

    for path in OURS:
        rel = os.path.relpath(path, ROOT)
        text = text_of(path)
        for pattern in FORBIDDEN:
            if re.search(pattern, text, re.I):
                failures.append(f"{rel}: contains forbidden /{pattern}/")
        name = os.path.basename(path)
        if name in LIMITS and len(text.rstrip("\n")) > LIMITS[name]:
            failures.append(f"{rel}: {len(text.rstrip())} chars > {LIMITS[name]}")
        for s in sentences(text):
            if s in theirs:
                failures.append(f"{rel}: shared sentence with {theirs[s]}: \"{s}\"")
                continue
            g = grams(s)
            if len(g) < 3:
                continue
            for t, tg, src in their_grams:
                if tg and len(g & tg) / len(g | tg) >= 0.5:
                    failures.append(f"{rel}: near-duplicate of {src}: \"{s}\" ~ \"{t}\"")
                    break

    print(f"checked {len(OURS)} files against {len(SIBLINGS)} sibling files ({len(theirs)} sentences)")
    for f in failures:
        print("FAIL", f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
