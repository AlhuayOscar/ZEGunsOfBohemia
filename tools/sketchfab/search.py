"""
search.py  -  candidate real models for every gun and part, from Sketchfab's public search.

    "<blender>/5.2/python/bin/python.exe" -I tools/sketchfab/search.py [ids...]

No login needed: the search API is public. Only downloadable models under a license the
mod may ship (CC0, CC-BY; tools/model_sources.lua rule) are kept: NC / ND / SA and
"Standard" are dropped. Writes, under .cache/sketchfab/ (git-ignored):

    candidates.json        { id: [ {uid, name, author, license, faces, url, thumb, query}, ... ] }
    thumbs/<uid>.jpg       256 px thumbnails
    sheets/<id>.jpg        a numbered contact sheet per item, to pick from (needs ffmpeg)

The picks go to tools/sketchfab/picks.lua; tools/sketchfab/fetch.py downloads them.
"""
import json, os, subprocess, sys, time, urllib.parse, urllib.request

REPO = os.getcwd()
CACHE = os.path.join(REPO, ".cache", "sketchfab")
API = "https://api.sketchfab.com/v3/search"
OK_LICENSES = {"CC Attribution": "CC-BY 4.0", "CC0 Public Domain": "CC0 1.0"}
PER_ITEM = 8
MAX_FACES = 400000          # anything bigger is a showcase scan, not a game model

# extra words per item kind so "Harris Bipod" doesn't return tripods for cameras
KIND_HINT = {"optic": "scope sight", "muzzle": "suppressor muzzle", "stock": "rifle stock",
             "underbarrel": "rifle", "bipod": "rifle bipod", "sling": "rifle sling",
             "mount": "rail mount", "handguard": "handguard rail", "adapter": "rail",
             "sidesaddle": "shotgun", "recoilpad": "recoil pad", "shellholder": "shotgun shell holder"}

# better search words where our display name is not what people call the model
QUERY = {
    "Colt1911": ["M1911", "Colt 1911"], "MP5A3": ["MP5"], "Uzi": ["Uzi"], "AA12": ["AA-12 shotgun", "AA12"],
    "KSG": ["KSG shotgun", "Kel-Tec KSG"], "CoachGun": ["double barrel shotgun", "coach gun"],
    "MosinNagant": ["Mosin Nagant"], "Kar98k": ["Kar98k", "Karabiner 98k"], "LeeEnfieldNo4": ["Lee Enfield"],
    "AI_AWM": ["AWM", "AWP rifle"], "BarrettM95": ["Barrett M95", "Barrett"], "SVD": ["SVD Dragunov", "Dragunov"],
    "SR25": ["SR-25", "M110 rifle"], "Mk12SPR": ["Mk12 SPR", "Mk 12"], "HK_G36": ["G36"], "SteyrAUG": ["Steyr AUG"],
    "IMI_Galil": ["Galil"], "FN_P90": ["P90"], "KrissVector": ["Kriss Vector"], "PPSh41": ["PPSh-41", "PPSh"],
    "ThompsonM1928": ["Thompson submachine gun", "Tommy gun"], "MAC10": ["MAC-10", "MAC 10"], "UMP45": ["UMP45", "UMP"],
    "Rem700": ["Remington 700"], "Win70": ["Winchester Model 70", "bolt action rifle"], "RugerRPR": ["Ruger Precision Rifle"],
    "Win1894": ["Winchester 1894", "lever action rifle"], "Marlin336": ["Marlin 336", "lever action"],
    "HenryBigBoy": ["Henry Big Boy", "lever action rifle"], "Marlin1894": ["Marlin 1894", "lever action carbine"],
    "HenryH001": ["Henry lever action 22", "lever action rifle"], "Marlin1895GG": ["Marlin 1895", "guide gun"],
    "Win1897": ["Winchester 1897", "trench gun"], "M590": ["Mossberg 590", "Mossberg"], "Rem870": ["Remington 870"],
    "BenelliM4": ["Benelli M4", "M1014"], "Saiga12": ["Saiga 12", "Saiga"], "SW_Model10": ["Smith Wesson Model 10", "revolver 38"],
    "ColtPython": ["Colt Python"], "RugerGP100": ["Ruger GP100"], "SW_686Plus": ["Smith Wesson 686"],
    "SW_Model29": ["Smith Wesson Model 29", "44 magnum revolver"], "ColtAnaconda": ["Colt Anaconda"],
    "ColtSAA": ["Colt Single Action Army", "Colt Peacemaker"], "TaurusJudge": ["Taurus Judge"],
    "RugerSuperRedhawk": ["Ruger Super Redhawk", "Redhawk"], "SW_Model500": ["Smith Wesson 500", "S&W 500"],
    "NagantM1895": ["Nagant revolver"], "DesertEagle": ["Desert Eagle"], "FN_FiveSeven": ["Five-seveN", "FN Five Seven"],
    "TokarevTT33": ["Tokarev TT-33", "TT-33"], "MakarovPM": ["Makarov"], "RugerMkII": ["Ruger Mark II", "Ruger 22 pistol"],
    "WaltherPPK": ["Walther PPK"], "HK_USP45": ["HK USP", "USP 45"], "SIG_M17": ["SIG M17", "P320"],
    "SIG_P226": ["SIG P226"], "CZ75": ["CZ 75", "CZ75"], "Beretta92FS": ["Beretta 92", "Beretta M9"],
    "Glock17": ["Glock 17", "Glock"], "Glock19": ["Glock 19", "Glock"], "Glock18C": ["Glock 18", "Glock"], "Glock21": ["Glock 21", "Glock"],
    "Glock22": ["Glock 22", "Glock"], "AK47": ["AK-47", "AKM"], "AK74": ["AK-74", "AK74"], "M16A2": ["M16A2", "M16"],
    "M4A1": ["M4A1", "M4 carbine"], "HK416": ["HK416"], "M14": ["M14 rifle"],
    "M24": ["M24 sniper rifle", "M24 SWS"], "SPAS12": ["SPAS-12", "SPAS 12 shotgun"], "M4A4": ["M4A4", "M4 rifle"],
    "M4A1S": ["M4A1-S", "M4A1 silencer", "M4A1 suppressor"], "M45A1": ["M45A1", "1911 rail"],
    "SpringfieldProdigy": ["Springfield Prodigy", "2011 pistol", "1911 red dot"],
    "Optic_RedDot": ["red dot sight", "Aimpoint"], "Optic_Holo": ["holographic sight", "EOTech"],
    "Optic_4x": ["ACOG", "4x scope"], "Optic_Hunting3x9": ["hunting scope", "rifle scope"],
    "Optic_Scope8x": ["sniper scope", "rifle scope"], "Optic_Pistol_RMR": ["RMR sight", "pistol red dot"],
    "Optic_PSO1": ["PSO-1 scope"], "Optic_PU": ["PU scope", "Mosin scope"], "Optic_Rimfire4x": ["rimfire scope", "small rifle scope"],
    "Grip_Vertical": ["vertical foregrip"], "Grip_Angled": ["angled foregrip"], "Grip_Stubby": ["stubby grip", "foregrip"],
    "Light_Weapon": ["weapon light", "tactical flashlight rail"], "Light_Pistol": ["pistol light", "weapon light"],
    "Laser_Rifle": ["PEQ-15", "laser module"], "Laser_Pistol": ["pistol laser"], "Bipod_Harris": ["Harris bipod", "bipod"],
    "Suppressor_Pistol9": ["pistol suppressor", "silencer"], "Suppressor_Pistol45": ["pistol suppressor", "silencer"],
    "Suppressor_Rimfire": ["22 suppressor", "silencer"], "Suppressor_Rifle556": ["rifle suppressor", "suppressor"],
    "Suppressor_Rifle308": ["rifle suppressor", "suppressor"], "Suppressor_338": ["sniper suppressor", "suppressor"],
    "Muzzle_AK_Suppressor": ["AK suppressor", "PBS-1"], "Suppressor_AK74": ["AK-74 suppressor", "PBS-4"],
    "Brake_Rifle556": ["muzzle brake"], "Brake_Rifle308": ["muzzle brake"], "Brake_AK74": ["AK-74 muzzle brake"],
    "Muzzle_AK_Compensator": ["AK compensator", "muzzle brake"], "Muzzle_AK_FlashHider": ["AK flash hider"],
    "FlashHider_556": ["flash hider", "A2 flash hider"], "FlashHider_308": ["flash hider"], "Comp_Pistol9": ["pistol compensator"],
    "Stock_AK_Folding": ["AK folding stock", "AKS stock"], "Stock_AR_Collapsible": ["AR-15 stock", "M4 stock"],
    "Stock_AR_Precision": ["PRS stock", "AR-10 stock"], "Stock_M590_PistolGrip": ["shotgun pistol grip stock"],
    "Stock_870_Folding": ["shotgun folding stock"], "Sidesaddle_Shotgun": ["shotgun side saddle"],
    "Sling_2Point": ["rifle sling"], "Sling_1Point": ["single point sling"], "Mount_AK_SideRail": ["AK side mount"],
    "Mount_AR_CarryHandle": ["carry handle"], "Mount_ScopeBase": ["picatinny rail"], "Mount_HK_Claw": ["HK claw mount"],
    "Mount_M14": ["M14 scope mount"], "Mount_Mosin_PU": ["Mosin scope mount"], "Mount_Ruger_Rings": ["scope rings"],
    "Handguard_AK_Quad": ["AK quad rail"], "Handguard_AR_Quad": ["quad rail handguard"], "Handguard_MP5_Rail": ["MP5 handguard"],
    "Adapter_USP_Rail": ["pistol rail adapter"], "Adapter_HK_3Lug": ["3 lug adapter"],
    "RecoilPad_Rubber": ["recoil pad"], "ShellHolder_Butt": ["buttstock shell holder"],
}


def get(url, tries=4):
    for k in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "ZEGunsOfBohemia-model-search"})
            with urllib.request.urlopen(req, timeout=30) as r:
                return r.read()
        except Exception as e:                      # rate limit / network: back off
            if k == tries - 1: raise
            time.sleep(2 + 3 * k)


def search(q):
    url = API + "?" + urllib.parse.urlencode({"type": "models", "q": q, "downloadable": "true", "count": 24})
    return json.loads(get(url)).get("results", [])


def thumb_of(r):
    imgs = sorted((r.get("thumbnails") or {}).get("images") or [], key=lambda i: i.get("width") or 0)
    for i in imgs:
        if (i.get("width") or 0) >= 256: return i["url"]
    return imgs[-1]["url"] if imgs else None


def candidates(item):
    kind, iid, name = item["kind"], item["id"], item["name"]
    queries = QUERY.get(iid) or [name]
    out, seen = [], set()
    for q in queries:
        for r in search(q):
            lic = (r.get("license") or {}).get("label")
            if lic not in OK_LICENSES or r["uid"] in seen: continue
            faces = r.get("faceCount") or 0
            if faces > MAX_FACES: continue
            seen.add(r["uid"])
            out.append({"uid": r["uid"], "name": r["name"], "author": (r.get("user") or {}).get("displayName"),
                        "username": (r.get("user") or {}).get("username"), "license": OK_LICENSES[lic],
                        "faces": faces, "url": r["viewerUrl"], "thumb": thumb_of(r), "query": q})
            if len(out) >= PER_ITEM: return out
        time.sleep(0.4)
    return out


def ffmpeg():
    base = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages")
    for root, _, files in os.walk(base):
        if "ffmpeg.exe" in files: return os.path.join(root, "ffmpeg.exe")
    return "ffmpeg"


def sheet(iid, cands, ff):
    """4x2 numbered thumbnails with face counts."""
    tdir, sdir = os.path.join(CACHE, "thumbs"), os.path.join(CACHE, "sheets")
    os.makedirs(tdir, exist_ok=True); os.makedirs(sdir, exist_ok=True)
    files = []
    for c in cands:
        p = os.path.join(tdir, c["uid"] + ".jpg")
        if not os.path.exists(p) and c["thumb"]:
            try: open(p, "wb").write(get(c["thumb"]))
            except Exception: continue
        if os.path.exists(p): files.append((p, c))
    if not files: return
    args, chains = [ff, "-hide_banner", "-loglevel", "error", "-y"], []
    font = "C\\:/Windows/Fonts/arial.ttf"
    for k, (p, c) in enumerate(files):
        args += ["-i", p]
        label = "%d  %dk  %s" % (k + 1, round(c["faces"] / 1000), "CC0" if c["license"].startswith("CC0") else "BY")
        label = label.replace(":", "\\:")
        chains.append("[%d:v]scale=320:180:force_original_aspect_ratio=decrease,pad=320:180:(ow-iw)/2:(oh-ih)/2:color=gray,"
                      "drawtext=fontfile='%s':text='%s':x=6:y=6:fontsize=20:fontcolor=yellow:box=1:boxcolor=black@0.6[t%d]" % (k, font, label, k))
    n = len(files)
    while n < 8:                                   # pad to a full 4x2 grid
        chains.append("color=c=black:s=320x180:d=1[t%d]" % n); n += 1
    layout = "|".join("%d_%d" % ((k % 4) * 320, (k // 4) * 180) for k in range(8))
    graph = ";".join(chains) + ";" + "".join("[t%d]" % k for k in range(8)) + "xstack=inputs=8:layout=" + layout + "[out]"
    args += ["-filter_complex", graph, "-map", "[out]", "-frames:v", "1", "-q:v", "4", os.path.join(sdir, iid + ".jpg")]
    subprocess.run(args, check=False)


def main():
    os.makedirs(CACHE, exist_ok=True)
    items = []
    for line in open(os.path.join(CACHE, "items.tsv"), encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        if len(f) < 3: continue
        if f[0] == "part" and len(f) > 5 and f[5] == "true": continue      # chokes: no model
        items.append({"kind": f[3] if f[0] == "part" else "gun", "id": f[1], "name": f[2]})
    only = set(sys.argv[1:])
    path = os.path.join(CACHE, "candidates.json")
    result = json.load(open(path)) if os.path.exists(path) else {}
    ff = ffmpeg()
    for it in items:
        if only and it["id"] not in only: continue
        if not only and it["id"] in result: continue
        try:
            result[it["id"]] = candidates(it)
        except Exception as e:
            print("search failed", it["id"], e); continue
        sheet(it["id"], result[it["id"]], ff)
        print("%-24s %d candidates" % (it["id"], len(result[it["id"]])), flush=True)
        json.dump(result, open(path, "w"), indent=1)


if __name__ == "__main__":
    main()
