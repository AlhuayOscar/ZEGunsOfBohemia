"""
check_models.py  -  look at the exported models WITHOUT starting the game.

    blender -b -P tools/blender/check_models.py [-- <out_dir> [variants]]

Re-imports every exported FBX from disk (Contents/.../models_X/ZGB), checks
that it loads, has geometry, uses the shared atlas texture and has a sane
size, and renders one labelled contact sheet per folder (guns by category,
attachments by type, magazines, casings) into .cache/check/ (default).
Pass "variants" to also include every gun variant (slow, hundreds of files).

Everything is drawn from the right side, muzzle pointing right, with the
atlas texture, i.e. roughly how the item looks in the game.
"""
import bpy, sys, os, math, json
from mathutils import Matrix
TO_VIEW = Matrix(((0, 0, 1, 0), (-1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 0, 1)))   # inverse of import_models GAME_FRAME
# long guns and parts were also rolled 180 deg at export (import_models ROLL): undo that too
ROLL = Matrix(((-1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
try:
    import json as _json
    _ROLLED = {j["id"]: j.get("roll", True) for j in _json.load(open(os.path.join(os.getcwd(), ".cache", "model_manifest.json")))["jobs"]}
except Exception:
    _ROLLED = {}
def to_view(model_id):
    return TO_VIEW @ ROLL if _ROLLED.get(model_id, True) else TO_VIEW

REPO = os.getcwd()
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.join(REPO, ARGS[0]) if ARGS and ARGS[0] != "variants" else os.path.join(REPO, ".cache", "check")
WITH_VARIANTS = "variants" in ARGS
MODELS = os.path.join(REPO, "Contents", "mods", "ZEGunsOfBohemiaCore", "42", "media", "models_X", "ZGB")
MEDIA = os.path.join(REPO, "Contents", "mods", "ZEGunsOfBohemiaCore", "42", "media")

# texture of every model, as its model script names it (one per gun / part since v0.8)
import re as _re
def _model_textures(media):
    text = open(os.path.join(media, "scripts", "ZGB_models.txt"), encoding="utf-8").read()
    return {m: t.strip() for m, t in _re.findall(r"model (\w+)\s*\{\s*mesh = [^,]+,\s*texture = ([^,]+),", text)}
_images = {}
def texture_for(media, model_id):
    """bpy image of a model's texture, or None if the script or file is missing."""
    if "_map" not in _images: _images["_map"] = _model_textures(media)
    tex = _images["_map"].get(model_id)
    if not tex: return None
    path = os.path.join(media, "textures", *tex.split("/")) + ".png"
    if not os.path.exists(path): return None
    if path not in _images: _images[path] = bpy.data.images.load(path)
    return _images[path]
os.makedirs(OUT, exist_ok=True)

groups = {}
for root, _, files in os.walk(MODELS):
    for f in sorted(files):
        if not f.lower().endswith(".fbx"): continue
        if "__" in f and not WITH_VARIANTS: continue
        rel = os.path.relpath(root, MODELS).replace("\\", "/").split("/")
        key = "/".join(rel[:2]) if rel[0] in ("Guns", "Attachments") else rel[0]
        groups.setdefault(key, []).append(os.path.join(root, f))

problems, report = [], []
for key, files in sorted(groups.items()):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    _images.clear()                  # factory reset frees the images
    cols = 6 if len(files) > 12 else 4
    cell = 1.5
    for i, path in enumerate(files):
        name = os.path.splitext(os.path.basename(path))[0]
        before = set(bpy.data.objects)
        try:
            bpy.ops.import_scene.fbx(filepath=path, global_scale=100.0)   # files are plain metres (node scale 1, unit cm)
        except Exception as e:
            problems.append("%s: import failed (%s)" % (name, e)); continue
        objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        if not objs:
            problems.append("%s: no mesh in file" % name); continue
        for o in objs:                                   # undo the export turn (import_models GAME_FRAME): muzzle right again
            o.matrix_world = to_view(name) @ o.matrix_world
        verts = sum(len(o.data.vertices) for o in objs)
        mats = {s.material.name.split(".")[0] for o in objs for s in o.material_slots if s.material}
        bpy.context.view_layer.update()
        from mathutils import Vector
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        size = mx - mn
        longest = max(size)
        report.append({"model": name, "group": key, "verts": verts, "size_m": [round(size.x, 3), round(size.z, 3), round(size.y, 3)]})
        if longest < 0.005 or longest > 3.0:
            problems.append("%s: odd size %.3f m (expected 0.005 - 3 m)" % (name, longest))
        atlas = texture_for(MEDIA, name)
        if atlas is None:
            problems.append("%s: its model script names no texture, or the file is missing" % name)
        # show it with its texture, scaled into its cell
        for o in objs:
            for s in o.material_slots:
                m = s.material
                if m and m.use_nodes:
                    n = next((n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"), None)
                    if n: n.image = atlas
        root = bpy.data.objects.new("r" + name, None); scene.collection.objects.link(root)
        centre = (mn + mx) / 2
        for o in objs:
            if o.parent is None: o.parent = root
        s = 1.0 / max(longest, 1e-6)
        gx, gy = (i % cols) * cell, -(i // cols) * cell
        root.scale = (s, s, s)
        root.location = (gx - centre.x * s, -centre.y * s, gy - centre.z * s)
        t = bpy.data.curves.new("t" + name, "FONT"); t.body = name; t.size = 0.09
        to = bpy.data.objects.new("t" + name, t); scene.collection.objects.link(to)
        to.location = (gx - 0.65, -0.5, gy - 0.62); to.rotation_euler = (math.radians(90), 0, 0)
    rows = max(1, math.ceil(len(files) / cols))
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = max(cols, rows) * cell
    cam = bpy.data.objects.new("c", cd); scene.collection.objects.link(cam); scene.camera = cam
    cam.location = ((cols - 1) * cell / 2, -10, -(rows - 1) * cell / 2); cam.rotation_euler = (math.radians(90), 0, 0)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"; scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_object_outline = True
    scene.world = bpy.data.worlds.new("w"); scene.world.color = (0.8, 0.8, 0.8)
    scene.render.resolution_x = scene.render.resolution_y = 1600
    scene.render.filepath = os.path.join(OUT, key.replace("/", "_") + ".png")
    bpy.ops.render.render(write_still=True)
    print("[ZGB] sheet", scene.render.filepath, len(files), "models", flush=True)

with open(os.path.join(OUT, "report.json"), "w") as f:
    json.dump({"models": report, "problems": problems}, f, indent=1)
print("[ZGB] checked %d models in %d groups, %d problems" % (len(report), len(groups), len(problems)), flush=True)
for p in problems[:40]: print("[ZGB] PROBLEM", p, flush=True)
