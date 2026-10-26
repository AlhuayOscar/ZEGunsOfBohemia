"""
make_art.py  -  Workshop and mod-list pictures, rendered from the mod's own models.

    blender -b -P tools/blender/make_art.py

Writes:
    preview.png                                  256 x 256, the Workshop thumbnail (repo root = Workshop item)
    Contents/mods/<Mod>/42/poster.png            512 x 512, shown in the in-game mod list (mod.info poster=)
"""
import bpy, os, math
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

def gun(path):
    return os.path.join(MEDIA, "models_X", "ZGB", *path.split("/")) + ".fbx"

POSTERS = {
    "ZEGunsOfBohemiaCore":    ("ZE GUNS OF BOHEMIA", "70 guns  -  attachments  -  ammo", ["Guns/AssaultRifles/AK47/AK47", "Guns/AssaultRifles/M4A1/M4A1", "Guns/Handguns/MakarovPM/MakarovPM"]),
    "ZEGunsOfBohemiaIso":     ("ISOMETRIC VIEW", "animation, recoil, casings", ["Guns/SMGs/MP5A3/MP5A3", "Guns/Shotguns/Saiga12/Saiga12"]),
    "ZEGunsOfBohemiaReload":  ("RELOADING", "tactical, empty, tube, cylinder", ["Guns/RevolversHandCannons/SW_Model29/SW_Model29", "Guns/Shotguns/Rem870/Rem870"]),
    "ZEGunsOfBohemiaHolding": ("TACTICAL HOLDING", "stance by Aiming level", ["Guns/AssaultRifles/HK416/HK416", "Guns/Handguns/Glock17/Glock17"]),
    "ZEGunsOfBohemiaCalls":   ("CALLOUTS", "\"CHANGING MAG!\"", ["Guns/SMGs/Uzi/Uzi", "Guns/Handguns/Colt1911/Colt1911"]),
}

def scene_for(models, title, sub, size, show_text=True):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    _images.clear()
    sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.045, 0.05, 0.045, 1); bg.inputs[1].default_value = 1.0
    n = len(models)
    for i, path in enumerate(models):
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=gun(path), global_scale=100.0)
        objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
        for o in objs: o.matrix_world = to_view(os.path.basename(path)) @ o.matrix_world
        atlas = texture_for(MEDIA, os.path.basename(path))
        for o in objs:
            for s in o.material_slots:
                m = s.material
                if m and m.use_nodes:
                    t = next((x for x in m.node_tree.nodes if x.type == "TEX_IMAGE"), None)
                    if t: t.image = atlas
        bpy.context.view_layer.update()
        from mathutils import Vector
        pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
        mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        root = bpy.data.objects.new("r%d" % i, None); sc.collection.objects.link(root)
        for o in objs:
            if o.parent is None: o.parent = root
        s = min(1.6 / max(mx.x - mn.x, 1e-6), (1.5 / n - 0.08) / max(mx.z - mn.z, 1e-6))
        root.scale = (s, s, s)
        y = 0.75 - (i + 0.5) * 1.5 / n
        c = (mn + mx) / 2
        root.location = (-c.x * s, -c.y * s, y - c.z * s)
        root.rotation_euler = (0, 0, math.radians(-8))
    if show_text:
        for text, z, sz in ((title, 1.05, 0.19), (sub, -1.12, 0.095)):
            cu = bpy.data.curves.new("t", "FONT"); cu.body = text; cu.size = sz; cu.align_x = "CENTER"
            to = bpy.data.objects.new("t", cu); sc.collection.objects.link(to)
            to.location = (0, -1, z); to.rotation_euler = (math.radians(90), 0, 0)
            mat = bpy.data.materials.new("txt"); mat.use_nodes = True
            mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.63, 0.22, 1)
            cu.materials.append(mat)
    cd = bpy.data.cameras.new("c"); cd.type = "ORTHO"; cd.ortho_scale = 2.6
    cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
    cam.location = (0, -10, 0); cam.rotation_euler = (math.radians(90), 0, 0)
    sun = bpy.data.lights.new("s", "SUN"); sun.energy = 3.0
    so = bpy.data.objects.new("s", sun); sc.collection.objects.link(so); so.rotation_euler = (math.radians(60), 0, math.radians(20))
    sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_WORKBENCH"
    if sc.render.engine == "BLENDER_WORKBENCH":
        sc.display.shading.light = "STUDIO"; sc.display.shading.color_type = "TEXTURE"
    sc.render.resolution_x = sc.render.resolution_y = size
    sc.render.image_settings.file_format = "PNG"
    return sc

def render(path, sc):
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("[ZGB] wrote", path, flush=True)

for mod, (title, sub, models) in POSTERS.items():
    sc = scene_for(models, title, sub, 512)
    render(os.path.join(REPO, "Contents", "mods", mod, "42", "poster.png"), sc)

sc = scene_for(["Guns/AssaultRifles/AK47/AK47", "Guns/AssaultRifles/M4A1/M4A1", "Guns/Shotguns/BenelliM4/BenelliM4"], "ZE GUNS OF BOHEMIA", "Build 42", 256)
render(os.path.join(REPO, "preview.png"), sc)
