"""
import_models.py  -  the Blender step of the model pipeline.

Run after tools/gen_models.lua (which writes .cache/model_manifest.json):

    blender -b -P tools/blender/import_models.py

For every real model in tools/model_sources.lua it:
  1. imports the source (FBX / .blend object), joins it into one mesh
  2. bakes its colours / textures into its own image (256 px for flat-colour low-poly
     packs, 512-1024 px for detailed ones: the manifest's `texture`), cutting detailed
     meshes down to the face budget (`maxFaces`) first
  3. fits it into the placeholder's box: longest side to longest side, same
     size, same centre (plus the per-model `fix` flips from the review)
  4. builds every job: the asset itself and each gun variant (real and
     placeholder pieces composed at their attachment positions), exported as
     FBX next to the placeholder it replaces. A model script names ONE texture,
     so each job's `atlas` (textures/ZGB/Guns/<gun>.png, Parts/<part>.png or the
     palette-only ZGB_Atlas.png) is assembled from the baked images its jobs use,
     and the UVs of every copy are pointed at its block there
  5. renders inventory icons and Gunsmith preview sprites
  6. writes Defs/ZGB_Def_RealModels.lua with the fitted bounds (preview layout)

Our axes: x forward, y up, z right (metres). Blender: X forward, Z up, -Y right.
In game (seen on the first test): the game applies the FBX node transform, and the
exporter's node rotation (-90 about X) turns Blender Z into the game's +Y. Vanilla guns
point along the game's +Y with +Z up, so every mesh is turned by GAME_FRAME just before
export (Blender X->Z, Z->-Y): in game forward = +Y, up = +Z, right = +X.
VERIFY in game: that the gun now points where the character aims.
"""
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Vector

REPO = os.getcwd()
MAN = json.load(open(os.path.join(REPO, ".cache", "model_manifest.json")))
TILE = MAN["tile"]
OUT = {k: os.path.join(REPO, v) for k, v in MAN["out"].items()}
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
if "--review" in ARGS:
    i = ARGS.index("--review"); ARGS = ARGS[:i] + ARGS[i + 2:]
ONLY = set(ARGS)          # optional: only these asset ids

def log(*a): print("[ZGB]", *a, flush=True)

# ------------------------------------------------------------------ helpers
def to_bl(x, y, z): return (x, -z, y)

from mathutils import Matrix
# Blender (X fwd, Z up, -Y right) -> export frame (Z fwd, -Y up, X right); see the header
GAME_FRAME = Matrix(((0, -1, 0, 0), (0, 0, -1, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
# Long guns and parts also turn 180 deg around the barrel (export Z): in game they showed up
# upside down, while one-handed guns, which vanilla holds upside down, looked right (MF.FRAMES)
ROLL = Matrix(((-1, 0, 0, 0), (0, -1, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def select_only(objs, active=None):
    bpy.context.view_layer.update()
    for o in list(bpy.context.view_layer.objects):
        if o is not None: o.select_set(False)          # glTF imports can leave an empty entry after a join
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = active or (objs[0] if objs else None)

def import_source(src):
    path = os.path.join(REPO, src["file"])
    before = set(bpy.data.objects)
    if path.lower().endswith((".glb", ".gltf")):
        bpy.ops.import_scene.gltf(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
        # the importer's helpers (bone shapes) live in a hidden "glTF_not_exported" collection
        for o in [o for o in new if any(c.name.startswith("glTF_not_exported") for c in o.users_collection)]:
            new.remove(o); bpy.data.objects.remove(o, do_unlink=True)
    elif path.lower().endswith((".fbx", ".obj")):
        if path.lower().endswith(".fbx"): bpy.ops.import_scene.fbx(filepath=path)
        else: bpy.ops.wm.obj_import(filepath=path)
        new = [o for o in bpy.data.objects if o not in before]
    else:
        with bpy.data.libraries.load(path, link=False) as (df, dt):
            names = list(df.objects)
            dt.objects = list(names)
        by_src_name = dict(zip(names, dt.objects))       # loaded copies may be renamed (.001)
        new = [o for o in dt.objects if o is not None]
        want = src.get("object")
        if want:
            root = by_src_name[want]
            keep, stack = [], [root]
            while stack:
                o = stack.pop(); keep.append(o); stack.extend(o.children)
            new = keep
        for o in new:
            bpy.context.scene.collection.objects.link(o)
    for pat in (src.get("fix") or {}).get("exclude") or []:      # stray pieces (a loose magazine...)
        for o in [o for o in new if pat in o.name]:
            new.remove(o); bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in new if o.type == "MESH"]
    if (src.get("fix") or {}).get("drop_loose") and len(meshes) > 1:
        # showcase extras (a spare magazine, loose rounds) lie beside the gun: keep what touches
        # the biggest piece, drop what doesn't
        bpy.context.view_layer.update()
        def box(o):
            pts = [o.matrix_world @ Vector(c) for c in o.bound_box]
            return Vector([min(p[k] for p in pts) for k in range(3)]), Vector([max(p[k] for p in pts) for k in range(3)])
        boxes = {o.name: box(o) for o in meshes}
        def vol(b): d = b[1] - b[0]; return d.x * d.y * d.z
        main = max(meshes, key=lambda o: vol(boxes[o.name]))
        mn, mx = boxes[main.name]; grow = (mx - mn) * 0.05; mn, mx = mn - grow, mx + grow
        for o in list(meshes):
            a, b = boxes[o.name]
            if o is not main and any(b[k] < mn[k] or a[k] > mx[k] for k in range(3)):
                log("  dropped loose piece", o.name)
                meshes.remove(o); new.remove(o); bpy.data.objects.remove(o, do_unlink=True)
    for o in new:
        if o.type != "MESH": o.hide_set(True)
    # textured packs ship maps next to the FBX: hook *_Base_Color.png where a material has no image
    folder = os.path.dirname(path)
    colour = [f for f in os.listdir(folder) if f.lower().endswith("_base_color.png")] if path.lower().endswith(".fbx") else []
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if not m: continue
            m.use_nodes = True
            nt = m.node_tree
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            def usable(img):
                return img is not None and (img.packed_file or os.path.exists(bpy.path.abspath(img.filepath)))
            for n in [n for n in nt.nodes if n.type == "TEX_IMAGE" and not usable(n.image)]:
                nt.nodes.remove(n)                         # broken paths would bake as magenta
            has_img = any(n.type == "TEX_IMAGE" for n in nt.nodes)
            if bsdf and colour and not has_img:
                img = bpy.data.images.load(os.path.join(folder, colour[0]))
                tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
                nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    # one mesh, transforms applied
    fallback = None
    for o in meshes:
        if not o.material_slots:
            if fallback is None:          # no material in the file: use the pack's colour map if there is one
                fallback = bpy.data.materials.new("fallback"); fallback.use_nodes = True
                if colour:
                    nt = fallback.node_tree; bsdf = nt.nodes.get("Principled BSDF")
                    tex = nt.nodes.new("ShaderNodeTexImage")
                    tex.image = bpy.data.images.load(os.path.join(folder, colour[0]))
                    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            o.data.materials.append(fallback)
    for o in meshes:
        mw = o.matrix_world.copy(); o.parent = None; o.matrix_world = mw
    select_only(meshes)
    # instanced pieces (the same rounds several times) share one mesh: give each its own, or join fails
    bpy.ops.object.make_single_user(type="SELECTED_OBJECTS", object=True, obdata=True)
    bpy.ops.object.convert(target="MESH")             # applies modifiers (mirror, bevel...)
    select_only(meshes)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    others = [o.name for o in new if o.type != "MESH"]           # names: joined meshes are gone after join()
    if len(meshes) > 1: bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    for name in others:
        o = bpy.data.objects.get(name)
        if o: bpy.data.objects.remove(o, do_unlink=True)
    return obj

# ------------------------------------------------------------------ textures
# Every source is baked once into its own image (UV layer "ZGBBake" in 0..1). Atlases are
# assembled per job texture afterwards (section 4), from square blocks on a TILE grid:
# the palette swatches (placeholder pieces) always take the first tile.
PG = MAN["paletteGrid"]; SW = TILE // PG
palette_px = np.zeros((TILE, TILE, 4), dtype=np.float32)
for name, m in MAN["palette"].items():
    cx, cy = (m["i"] % PG) * SW, (m["i"] // PG) * SW
    palette_px[cy:cy + SW, cx:cx + SW, :3] = m["rgb"]; palette_px[cy:cy + SW, cx:cx + SW, 3] = 1.0

def palette_uv(mat, size):
    m = MAN["palette"].get(mat) or MAN["palette"]["steel"]
    return (((m["i"] % PG) + 0.5) * SW / size, ((m["i"] // PG) + 0.5) * SW / size)

def image_material(name, img):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage"); tex.image = img
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m

def decimate(obj, max_faces):
    n = len(obj.data.polygons)
    if not max_faces or n <= max_faces: return
    select_only([obj])
    mod = obj.modifiers.new("ZGBDecimate", "DECIMATE"); mod.ratio = max_faces / n
    bpy.ops.object.modifier_apply(modifier=mod.name)
    log("  decimated", n, "->", len(obj.data.polygons), "faces")

source_px = {}           # source key -> (size, pixels) of its bake

def emit_base_colour(mat):
    """Make a material output its base colour (texture or flat) as emission, for an EMIT bake."""
    mat.use_nodes = True
    nt = mat.node_tree
    out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL"), None) or nt.nodes.new("ShaderNodeOutputMaterial")
    shader = next((n for n in nt.nodes if n.type in ("BSDF_PRINCIPLED", "BSDF_DIFFUSE")), None)
    em = nt.nodes.new("ShaderNodeEmission"); em.inputs["Strength"].default_value = 1.0
    col = shader.inputs.get("Base Color") or shader.inputs.get("Color") if shader else None
    if col is not None and col.is_linked:
        nt.links.new(col.links[0].from_socket, em.inputs["Color"])
    elif col is not None:
        em.inputs["Color"].default_value = col.default_value
    else:
        em.inputs["Color"].default_value = mat.diffuse_color
    nt.links.new(em.outputs["Emission"], out.inputs["Surface"])

def bake_source(obj, key, size):
    """Smart-unwrap, bake diffuse colour into a size x size image; the object keeps a
    material showing it (icons, previews) and the UVs stay 0..1 until a job places it."""
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"; scene.cycles.samples = 4; scene.cycles.device = "CPU"
    img = bpy.data.images.new("bake_" + str(len(source_px)), size, size, alpha=True)
    me = obj.data
    uv = me.uv_layers.new(name="ZGBBake"); me.uv_layers.active = uv
    select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    for slot in obj.material_slots:
        if slot.material: emit_base_colour(slot.material)
        nt = slot.material.node_tree
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = img
        nt.nodes.active = n
    # EMIT, not DIFFUSE: the diffuse colour pass of a metallic or specular-workflow material
    # (most Sketchfab glTFs) comes out empty, and the HK416 / G36 / M16A2 baked almost blank
    bpy.ops.object.bake(type="EMIT", margin=4, uv_layer="ZGBBake")
    source_px[key] = (size, np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4))
    if os.environ.get("ZGB_SAVE_BAKES"):              # debug: every source's bake in .cache/bakes/
        d = os.path.join(REPO, ".cache", "bakes"); os.makedirs(d, exist_ok=True)
        img.filepath_raw = os.path.join(d, os.path.basename(key.split("#")[0]) + ".png"); img.file_format = "PNG"; img.save()
    # (fetch the layers again: edit-mode round trips invalidate old references in Blender 5)
    for name in [l.name for l in me.uv_layers if l.name != "ZGBBake"]:
        me.uv_layers.remove(me.uv_layers[name])
    me.materials.clear(); me.materials.append(image_material("src_" + img.name, img))

class Atlas:
    """Square blocks on a TILE grid, palette in tile 0; grows 1024 -> 2048 -> 4096."""
    def __init__(self, name, sizes):
        self.name, self.blocks, self.size = name, {}, TILE
        if not sizes: return                               # palette only
        need = TILE * TILE + sum(sz * sz for sz in sizes.values())
        for grid in (4, 8, 16):
            if (grid * TILE) ** 2 >= need and self._pack(grid, sizes): return
        raise RuntimeError("atlas %s: blocks do not fit in 4096 px" % name)
    def _pack(self, grid, sizes):
        used = np.zeros((grid, grid), dtype=bool); used[0, 0] = True
        blocks = {}
        for key in sorted(sizes, key=lambda k: -sizes[k]):           # biggest first: squares of 2^n pack
            k = max(1, sizes[key] // TILE); spot = None
            for ty in range(0, grid - k + 1, k):
                for tx in range(0, grid - k + 1, k):
                    if not used[ty:ty + k, tx:tx + k].any(): spot = (tx, ty); break
                if spot: break
            if not spot: return False
            used[spot[1]:spot[1] + k, spot[0]:spot[0] + k] = True
            blocks[key] = (spot[0] * TILE, spot[1] * TILE, sizes[key])
        self.size, self.blocks = grid * TILE, blocks
        return True
    def save(self, write=True):
        px = np.zeros((self.size, self.size, 4), dtype=np.float32)
        px[0:TILE, 0:TILE] = palette_px
        for key, (ox, oy, sz) in self.blocks.items():
            src_sz, src = source_px[key]
            if src_sz != sz: raise RuntimeError("block size mismatch for " + key)
            px[oy:oy + sz, ox:ox + sz] = src
        img = bpy.data.images.new(self.name.replace("/", "_"), self.size, self.size, alpha=True)
        img.pixels.foreach_set(px.reshape(-1))
        path = os.path.join(OUT["textures"], self.name + ".png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        if write: img.filepath_raw = path; img.file_format = "PNG"; img.save()
        self.material = image_material("atlas_" + self.name, img)

# ------------------------------------------------------------------ fitting
def verts_our(me):
    co = np.zeros(len(me.vertices) * 3, dtype=np.float64)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return np.stack([co[:, 0], co[:, 2], -co[:, 1]], axis=1)       # blender -> our

def set_verts_our(me, v):
    bl = np.stack([v[:, 0], -v[:, 2], v[:, 1]], axis=1)
    me.vertices.foreach_set("co", bl.reshape(-1))
    me.update()

def fit(obj, bounds, fix):
    me = obj.data
    v = verts_our(me)
    if fix.get("pca"):
        # model tilted in its file: turn its main axes onto ours first (the review shows
        # whether it then needs a flip like any other model)
        c = v.mean(axis=0)
        w, vec = np.linalg.eigh(np.cov((v - c).T))
        R = vec[:, np.argsort(-w)]
        if np.linalg.det(R) < 0: R[:, 2] *= -1
        v = (v - c) @ R
        set_verts_our(me, v)
    mn, mx = v.min(axis=0), v.max(axis=0)
    ext = mx - mn
    tmin, tmax = np.array(bounds["min"]), np.array(bounds["max"])
    text = tmax - tmin
    # longest real axis -> longest target axis, and so on
    ro, to = np.argsort(-ext), np.argsort(-text)
    perm = np.zeros((3, 3))
    for r, tt in zip(ro, to): perm[tt, r] = 1.0
    swaps = fix.get("swap") or []
    if isinstance(swaps, str): swaps = [swaps]
    rows = {"xy": [0, 1], "yz": [1, 2], "xz": [0, 2]}
    for sw in swaps:                                  # applied in order
        a, b = rows[sw]; perm[[a, b]] = perm[[b, a]]
    flips = fix.get("flip", "")
    for k, axis in enumerate("xyz"):
        if axis in flips: perm[k] *= -1
    v = (v - (mn + mx) / 2) @ perm.T
    s = text.max() / max(ext.max(), 1e-9)
    v = v * s + (tmin + tmax) / 2
    set_verts_our(me, v)
    if np.linalg.det(perm) < 0:
        bm = bmesh.new(); bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:]); bm.to_mesh(me); bm.free()
    if me.has_custom_normals:
        select_only([obj]); bpy.ops.mesh.customdata_custom_splitnormals_clear()
    me.update()
    # cut: drop faces entirely in the top share of the height (a scope that is part
    # of the gun mesh), then refit what is left to the target box
    cut_top = fix.get("cut_top")
    if cut_top is not None:
        v = verts_our(me)
        cut = v[:, 1].max() - cut_top * (v[:, 1].max() - v[:, 1].min())
        bm = bmesh.new(); bm.from_mesh(me); bm.verts.ensure_lookup_table()
        doomed = [f for f in bm.faces if min(v[x.index][1] for x in f.verts) > cut]
        bmesh.ops.delete(bm, geom=doomed, context="FACES")
        loose = [x for x in bm.verts if not x.link_faces]
        bmesh.ops.delete(bm, geom=loose, context="VERTS")
        bm.to_mesh(me); bm.free(); me.update()
        v = verts_our(me); mn, mx = v.min(axis=0), v.max(axis=0)
        s = (tmax[0] - tmin[0]) / max(mx[0] - mn[0], 1e-9)
        v = (v - (mn + mx) / 2) * s + (tmin + tmax) / 2
        set_verts_our(me, v)

def auto_orient(obj, aid, share=0.15):
    """Point a fitted gun the right way: the box fit knows sizes, not which end is the muzzle
    or which side is up (some guns came in backwards or upside down in game). The muzzle end
    is the thinner one (the rear carries the grip, stock or magazine), and the barrel runs in
    the upper half of the gun. Flips turn about the box centre, so the fit still holds."""
    v = verts_our(obj.data)
    mn, mx = v.min(axis=0), v.max(axis=0); c = (mn + mx) / 2; L = mx[0] - mn[0]
    front, rear = v[v[:, 0] > mx[0] - share * L], v[v[:, 0] < mn[0] + share * L]
    def height(p): return (p[:, 1].max() - p[:, 1].min()) if len(p) else 0.0
    flips = []
    if height(front) > height(rear) * 1.15:                 # muzzle at the back: turn around (x and z)
        v = (v - c) * np.array([-1.0, 1.0, -1.0]) + c; flips.append("front/back")
        front = v[v[:, 0] > mx[0] - share * L]
    if len(front) and float(np.median(front[:, 1])) < c[1]:   # barrel in the lower half: roll over (y and z)
        v = (v - c) * np.array([1.0, -1.0, -1.0]) + c; flips.append("upside down")
    if flips:
        set_verts_our(obj.data, v)
        log("  %s: turned (%s)" % (aid, ", ".join(flips)))

def align_bore(obj, muzzle, aid, slice_m=0.012, max_shift=0.05):
    """Move a fitted gun so its real barrel ends on the muzzle point. Fitting by bounding box
    puts the bore wherever the model's proportions put it, so the shot, the flash and a
    suppressor came out off the barrel (in game: from the chest). The barrel tip is the
    front-most slice of the mesh; its median height / side is the bore."""
    v = verts_our(obj.data)
    tip = v[v[:, 0] > v[:, 0].max() - slice_m]
    if len(tip) < 3: return
    dy, dz = muzzle[1] - float(np.median(tip[:, 1])), muzzle[2] - float(np.median(tip[:, 2]))
    if abs(dy) > max_shift or abs(dz) > max_shift:
        log("  %s: bore %.3f / %.3f m off the muzzle point, too far to trust - left as fitted" % (aid, dy, dz))
        return
    set_verts_our(obj.data, v + np.array([0.0, dy, dz]))
    log("  %s: bore aligned (%.3f, %.3f m)" % (aid, dy, dz))

def translate(obj, pos):
    me = obj.data
    v = verts_our(me) + np.array(pos)
    set_verts_our(me, v)

def prims_object(prims, name, atlas):
    """Placeholder pieces (boxes / cylinders) as a mesh with palette UVs in `atlas`."""
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("ZGBBake")
    def face(pts, mat):
        vs = [bm.verts.new(to_bl(*p)) for p in pts]
        f = bm.faces.new(vs)
        u = palette_uv(mat, atlas.size)
        for l in f.loops: l[uvl].uv = u
    for p in prims:
        if p["t"] == "box":
            (x0, y0, z0), (x1, y1, z1) = p["a"], p["b"]
            c = [(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
            for q in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(2,3,7,6),(1,2,6,5),(0,4,7,3)):
                face([c[i] for i in q], p["m"])
        else:
            seg, (cx, cy, cz), L, r = 8, p["c"], p["len"], p["r"]
            def at(t, a, b):
                if p["axis"] == "x": return (cx + t, cy + a, cz + b)
                if p["axis"] == "y": return (cx + b, cy + t, cz + a)
                return (cx + a, cy + b, cz + t)
            ring0 = [at(0, r * math.cos(i / seg * 2 * math.pi), r * math.sin(i / seg * 2 * math.pi)) for i in range(seg)]
            ring1 = [at(L, r * math.cos(i / seg * 2 * math.pi), r * math.sin(i / seg * 2 * math.pi)) for i in range(seg)]
            for i in range(seg):
                j = (i + 1) % seg
                face([ring0[i], ring0[j], ring1[j], ring1[i]], p["m"])
            face(list(reversed(ring0)), p["m"]); face(ring1, p["m"])
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    me.materials.append(atlas.material)
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o)
    return o

# ------------------------------------------------------------------ 1-3: sources -> fitted assets
reset()
baked = {}      # source key -> object (baked, unfitted)
asset_key = {}  # asset id -> source key
fitted = {}     # asset id -> object (fitted, hidden template)
for aid, asset in sorted(MAN["assets"].items()):
    if ONLY and aid not in ONLY: continue
    src = MAN["sources"][aid]
    key = src["file"] + "#" + (src.get("object") or "")
    kind = asset["kind"]
    def per_kind(v, default):
        return (v.get(kind) or default) if isinstance(v, dict) else (v or default)
    if key not in baked:
        log("import", key)
        o = import_source(src)
        decimate(o, per_kind(src.get("maxFaces"), None))
        bake_source(o, key, per_kind(src.get("texture"), TILE))
        o.hide_render = True; o.hide_set(True)
        baked[key] = o
    asset_key[aid] = key
    tpl = baked[key]
    o = tpl.copy(); o.data = tpl.data.copy(); o.name = "asset_" + aid
    bpy.context.scene.collection.objects.link(o)
    fit(o, asset["bounds"], src.get("fix") or {})
    if asset["kind"] == "gun" and not (src.get("fix") or {}).get("flip"): auto_orient(o, aid)
    if asset.get("muzzle"): align_bore(o, asset["muzzle"], aid)
    o.hide_render = True; o.hide_set(True)
    fitted[aid] = o


# ------------------------------------------------------------------ review sheet (--review <png>)
# Each cell: the fitted real model (top) above its placeholder (bottom), side view
# from the right, muzzle should point right and the top should be up in both.
if "--review" in sys.argv:
    out_png = sys.argv[sys.argv.index("--review") + 1]
    review_atlas = Atlas("review", {}); review_atlas.save(write=False)
    ids = sorted(fitted)
    cols = 6; cell = 1.6
    scene = bpy.context.scene
    for i, aid in enumerate(ids):
        b = MAN["assets"][aid]["bounds"]; size = max(b["max"][k] - b["min"][k] for k in range(3)) or 1
        s = 1.0 / size
        gx, gy = (i % cols) * cell, -(i // cols) * cell
        ph = prims_object(MAN["assets"][aid]["prims"], "ph_" + aid, review_atlas)
        for obj, dy in ((fitted[aid].copy(), 0.35), (ph, -0.35)):
            if obj is not ph:
                obj.data = fitted[aid].data.copy(); scene.collection.objects.link(obj)
            v = verts_our(obj.data)
            c = (np.array(b["min"]) + np.array(b["max"])) / 2
            set_verts_our(obj.data, (v - c) * s + np.array([gx, gy + dy, 0]))
            obj.hide_set(False); obj.hide_render = False
        t = bpy.data.curves.new("t" + aid, "FONT"); t.body = aid; t.size = 0.1
        to = bpy.data.objects.new("t" + aid, t); scene.collection.objects.link(to)
        to.location = to_bl(gx - 0.5, gy - 0.72, 0.2); to.rotation_euler = (math.radians(90), 0, 0)
    rows = math.ceil(len(ids) / cols)
    scene.render.engine = "BLENDER_WORKBENCH"; scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"; scene.display.shading.show_object_outline = True
    cd = bpy.data.cameras.new("rc"); cd.type = "ORTHO"; cd.ortho_scale = max(cols, rows) * cell
    rc = bpy.data.objects.new("rc", cd); scene.collection.objects.link(rc); scene.camera = rc
    rc.location = to_bl((cols - 1) * cell / 2, -(rows - 1) * cell / 2, 10); rc.rotation_euler = (math.radians(90), 0, 0)
    scene.render.resolution_x = scene.render.resolution_y = 2400
    scene.world = bpy.data.worlds.new("w"); scene.world.color = (0.8, 0.8, 0.8)
    scene.render.filepath = out_png
    bpy.ops.render.render(write_still=True)
    log("review sheet:", out_png)
    sys.exit(0)
os.makedirs(OUT["textures"], exist_ok=True)
# the job textures: every real source a job uses gets a block in that job's atlas
wanted = {}
for job in MAN["jobs"]:
    sizes = wanted.setdefault(job["atlas"], {})
    for c in job["components"]:
        if "real" in c and c["real"] in asset_key:
            key = asset_key[c["real"]]; sizes[key] = source_px[key][0]
atlases = {}
for name in sorted(wanted):
    atlases[name] = Atlas(name, wanted[name]); atlases[name].save()
log("textures:", len(atlases), "atlases,", sum(1 for a in atlases.values() if a.size >= 2048), "of 2048 px or more")

def place_uvs(obj, atlas, key):
    """Point a copy's ZGBBake UVs (0..1 in its own bake) at its block in `atlas`."""
    ox, oy, sz = atlas.blocks[key]
    me = obj.data; uv = me.uv_layers["ZGBBake"]
    uvd = np.zeros(len(me.loops) * 2, dtype=np.float32); uv.data.foreach_get("uv", uvd)
    uvd = uvd.reshape(-1, 2)
    uvd[:, 0] = (ox + uvd[:, 0] * sz) / atlas.size
    uvd[:, 1] = (oy + uvd[:, 1] * sz) / atlas.size
    uv.data.foreach_set("uv", uvd.reshape(-1))
    me.materials.clear(); me.materials.append(atlas.material)

# ------------------------------------------------------------------ 4: jobs
def export(objs, path, roll=True):
    select_only(objs)
    if len(objs) > 1: bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    select_only([o])
    # game scale (MF.GAME_SCALE, same factor as the attachment points) and frame; a proper rotation:
    # normals and winding stay right
    frame = (ROLL @ GAME_FRAME) if roll else GAME_FRAME
    o.data.transform(Matrix.Scale(MAN.get("game_scale", 1.0), 4) @ frame @ o.matrix_world)
    o.matrix_world = Matrix.Identity(4)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"},
                             path_mode="STRIP", add_leaf_bones=False,
                             # axis conversion baked into the mesh, node rotation 0: the game reads
                             # attachment points (muzzle flash, parts) in the file's raw space, without
                             # the node rotation, so with a -90 deg node the flash came out above the
                             # head (sixth in-game test). The mesh shows the same either way.
                             bake_space_transform=True,
                             # plain metres and node scale 1 like vanilla / working mods: the game ignores the FBX
                             # unit, so Blender's x100 node scale made every model 100 times too big
                             apply_unit_scale=False, global_scale=0.01, apply_scale_options="FBX_SCALE_NONE")
    bpy.data.objects.remove(o, do_unlink=True)

n = 0
for job in MAN["jobs"]:
    if ONLY and not any(c.get("real") in ONLY for c in job["components"]): continue
    objs = []
    atlas = atlases.get(job["atlas"])
    if atlas is None:                                  # placeholder-only texture (palette)
        atlas = atlases[job["atlas"]] = Atlas(job["atlas"], {}); atlas.save()
    for c in job["components"]:
        if "real" in c:
            if c["real"] not in fitted: break
            t = fitted[c["real"]]
            o = t.copy(); o.data = t.data.copy(); bpy.context.scene.collection.objects.link(o)
            o.hide_set(False); o.hide_render = False
            translate(o, c.get("pos") or [0, 0, 0])
            place_uvs(o, atlas, asset_key[c["real"]])
            objs.append(o)
        else:
            objs.append(prims_object(c["prims"], "prims", atlas))
    else:
        export(objs, os.path.join(OUT["models"], job["folder"], job["id"] + ".fbx"), job.get("roll", True))
        n += 1
log("exported", n, "models")

# ------------------------------------------------------------------ 5: icons and previews
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"; scene.display.shading.color_type = "TEXTURE"
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"; scene.render.image_settings.color_mode = "RGBA"
cam_data = bpy.data.cameras.new("cam"); cam_data.type = "ORTHO"
cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)

def shoot(aid, w, h, ortho, path):
    o = fitted[aid]; o.hide_set(False); o.hide_render = False
    v = verts_our(o.data); mn, mx = v.min(axis=0), v.max(axis=0)
    c = (mn + mx) / 2
    cam.location = Vector(to_bl(c[0], c[1], 10.0))
    cam_data.ortho_scale = ortho
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    o.hide_set(True); o.hide_render = True
    return mn, mx

real_bounds = {}
ppm, pad = MAN["ppm"], MAN["pad"]
for p in MAN["previews"]:
    aid = p["asset"]
    if aid not in fitted: continue
    v = verts_our(fitted[aid].data)
    # round first: the Lua side computes the sprite size from these written values
    mn, mx = np.round(v.min(axis=0), 5), np.round(v.max(axis=0), 5)
    W = max(1, math.ceil((mx[0] - mn[0]) * ppm + pad * 2)); H = max(1, math.ceil((mx[1] - mn[1]) * ppm + pad * 2))
    shoot(aid, W, H, max(W, H) / ppm, os.path.join(OUT["textures"], "Preview", p["name"] + ".png"))
    real_bounds[aid] = {"min": [float(x) for x in mn], "max": [float(x) for x in mx]}
for aid in MAN["icons"]:
    if aid not in fitted: continue
    v = verts_our(fitted[aid].data); mn, mx = v.min(axis=0), v.max(axis=0)
    shoot(aid, 32, 32, max(mx[0] - mn[0], mx[1] - mn[1]) * 1.07, os.path.join(OUT["icons"], "Item_ZGB_" + aid + ".png"))

# ------------------------------------------------------------------ 6: bounds for the preview layout
lines = ["--[[", "    ZGB_Def_RealModels.lua  -  GENERATED by tools/blender/import_models.py. Do not edit.",
         "    Bounds (metres, our axes) of the real models after fitting, so the Gunsmith",
         "    preview places their sprites exactly. Sources and licenses: CREDITS.txt.", "]]",
         'require "ZGB/Factory/ZGB_ModelFactory"', "ZGB.ModelFactory.REAL = {"]
for aid in sorted(real_bounds):
    b = real_bounds[aid]
    lines.append("    %s = { min = { %.5f, %.5f, %.5f }, max = { %.5f, %.5f, %.5f } }," % ((aid,) + tuple(b["min"]) + tuple(b["max"])))
lines.append("}")
with open(os.path.join(OUT["lua"], "ZGB_Def_RealModels.lua"), "w", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
log("done:", len(fitted), "real assets,", n, "models,", len(real_bounds), "previews")
