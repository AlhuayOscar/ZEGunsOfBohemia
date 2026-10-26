"""
check_rips.py  -  flags downloaded Sketchfab models that look ripped from a game.

    "<blender>/5.2/python/bin/python.exe" -I tools/sketchfab/check_rips.py

A CC-BY label on Sketchfab is only as good as the uploader: some "free" guns are models
extracted from commercial games (Call of Duty, CS, Tarkov...), which nobody but the game's
owner may license. Their files usually keep the game's internal names. This reads the node,
mesh, material and image names inside every downloaded .glb / .gltf and prints the ones that
match a known game naming pattern. A flagged model must not be used: take it out of
tools/sketchfab/picks.lua (and add its uid to REJECTED below so a re-pick is noticed).
Exit code 1 when something is flagged.
"""
import json, os, re, struct, sys

REPO = os.getcwd()
DIR = os.path.join(REPO, ".cache", "model_sources", "sketchfab")
PICKS = os.path.join(REPO, "tools", "sketchfab", "picks.lua")

# internal naming of games' asset pipelines
PATTERNS = [
    (r"\bt[5-9]_|_t[5-9]_|^t[5-9]_", "Call of Duty (Treyarch t5-t9 asset prefix)"),
    (r"\b(wpn|weapon)_.*_(view|world)(_lod\d)?", "Call of Duty view/world model naming"),
    (r"\bv_(rif|pist|smg|snip|shot|mach)_|\bw_(rif|pist|smg|snip|shot|mach)_", "Source engine / CS weapon model naming"),
    (r"\bmtl_(t[5-9]|wpn|weapon)", "Call of Duty material naming"),
    (r"tarkov|(^|[^a-z])eft_|weapon_[a-z]+_\d+mm_", "Escape from Tarkov"),   # not "left_"
    (r"\bpubg|fortnite|warzone|modern ?warfare|black ?ops|battlefield|counter.?strike|csgo|cs2_", "game name in the file"),
    (r"_lod0\b|_lod[1-4]\b", "game LOD naming (check by hand)"),
]
# models found to be rips (never pick again)
REJECTED = {
    "76627cc312cd4add9b2d6da974f059e5": "Five-seveN: Call of Duty Black Ops 2 rip (t6_wpn_pistol_fiveseven_view)",
}


def glb_json(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"glTF": return {}
    n = struct.unpack_from("<I", data, 12)[0]
    return json.loads(data[20:20 + n].decode("utf-8", "replace"))


def names(doc):
    out = []
    for key in ("nodes", "meshes", "materials", "images", "textures"):
        for item in doc.get(key) or []:
            for f in ("name", "uri"):
                if item.get(f): out.append(str(item[f]))
    return out


def main():
    picks = dict((uid, iid) for iid, uid in re.findall(r'(\w+)\s*=\s*\{\s*uid\s*=\s*"([0-9a-f]{32})"', open(PICKS, encoding="utf-8").read()))
    flagged = 0
    for f in sorted(os.listdir(DIR)):
        path = os.path.join(DIR, f)
        uid = f.split(".")[0]
        if f.endswith(".glb"): doc = glb_json(path)
        elif os.path.isdir(path) and os.path.exists(os.path.join(path, "scene.gltf")):
            doc = json.load(open(os.path.join(path, "scene.gltf"), encoding="utf-8"))
        else: continue
        hits = []
        if uid in REJECTED: hits.append(REJECTED[uid])
        for n in names(doc):
            for pat, why in PATTERNS:
                if re.search(pat, n, re.I): hits.append("%s: '%s'" % (why, n)); break
        if hits:
            flagged += 1
            print("RIP? %-20s %s" % (picks.get(uid, "?"), uid))
            for h in sorted(set(hits))[:4]: print("       " + h)
    print("%d flagged" % flagged)
    sys.exit(1 if flagged else 0)


if __name__ == "__main__":
    main()
