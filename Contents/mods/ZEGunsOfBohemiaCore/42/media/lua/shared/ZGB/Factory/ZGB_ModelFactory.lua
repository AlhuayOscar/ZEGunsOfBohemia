--[[
    ZGB_ModelFactory.lua  —  Factory Method for 3D models (pure Lua).

    Until the 3D side delivers real meshes, every gun, attachment, magazine and
    casing gets a PLACEHOLDER model built from boxes and cylinders at real-world
    size. The same data drives:
      * the .X meshes, item icons and preview sprites (tools/gen_models.lua)
      * the model scripts and their attachment points
      * where each part sits on each gun (ZGB_Visuals) and the Gunsmith preview

    Replacing a placeholder with a real model means dropping the artist's mesh
    into that item's folder (media/models_X/ZGB/...) with the same name, and
    moving the attachment points here if the real gun differs.

    Coordinates are metres. x = forward (towards the muzzle), y = up,
    z = right. The origin is the top of the firing hand's grip.

    ------------------------------------------------------------------ shapes
    A model is { prims = { prim... }, points = { name = {x,y,z} }, provides = { slotId = {x,y,z} } }
      prim  { t = "box", m = material, a = {x0,y0,z0}, b = {x1,y1,z1} }
            { t = "cyl", m = material, axis = "x"|"y"|"z", c = {x,y,z} (start of the axis), len, r }
    Gun points are generic places (top, side, under, handguard, muzzle, stock,
    sling, receiver_side, butt, butt_side, mag); a gun slot maps to one of them
    (SLOT_POINT). Part models are built around their mounting point (origin):
    muzzle devices grow forward, stocks backward, optics up, grips down.
]]
require "ZGB/ZGB_Core"

ZGB.ModelFactory = ZGB.ModelFactory or { _guns = {}, _parts = {}, _kinds = {}, _shapes = {}, _cache = {} }
local MF = ZGB.ModelFactory

-- Placeholder palette: material -> atlas swatch (index) + colour (r, g, b 0-1).
-- tools/gen_models.lua paints the atlas texture from this.
MF.MATERIALS = {
    steel   = { i = 0,  rgb = { 0.20, 0.21, 0.23 } },
    polymer = { i = 1,  rgb = { 0.11, 0.11, 0.12 } },
    wood    = { i = 2,  rgb = { 0.47, 0.29, 0.15 } },
    alloy   = { i = 3,  rgb = { 0.36, 0.37, 0.40 } },
    tan     = { i = 4,  rgb = { 0.63, 0.56, 0.41 } },
    olive   = { i = 5,  rgb = { 0.31, 0.34, 0.21 } },
    rubber  = { i = 6,  rgb = { 0.06, 0.06, 0.06 } },
    glass   = { i = 7,  rgb = { 0.22, 0.38, 0.55 } },
    brass   = { i = 8,  rgb = { 0.78, 0.62, 0.26 } },
    hull    = { i = 9,  rgb = { 0.62, 0.11, 0.10 } },
    nylon   = { i = 10, rgb = { 0.22, 0.24, 0.19 } },
    laser   = { i = 11, rgb = { 0.85, 0.12, 0.10 } },
    lens    = { i = 12, rgb = { 0.92, 0.90, 0.74 } },
    blued   = { i = 13, rgb = { 0.13, 0.14, 0.18 } },
}
MF.ATLAS_GRID = 4          -- 4 x 4 swatches

-- Gunsmith preview sprites (side views): pixels per metre and margin. The UI
-- places part sprites with the same numbers, so keep them in one place.
-- Models are designed at real size (metres) and shrunk to the game's scale on export:
-- vanilla guns are ~0.6 of their real length (M9 0.59, M16 0.57, M14 0.61, Rem 700 0.63,
-- L92 0.56; measured from the game's .X files). At real size ours looked too big in hand.
-- Applied to meshes AND attachment points, so model scripts keep scale = 1.
MF.GAME_SCALE = 0.6
-- Our points are (forward, up, right) at real size. In game, vanilla guns point along +Y, and
-- the two rigs disagree on "up": long guns use +Z, one-handed guns are held upside down (-Z;
-- the vanilla M9's scope sits below its muzzle). Fourth in-game test: our long guns showed up
-- rolled 180 degrees (magazine up), the pistols looked right.
--   long  points (right, forward, up); the Blender step rolls the mesh 180 deg (job.roll)
--   hand  points (-right, forward, -up); mesh as is
-- Parts are modelled in the long frame; on a one-handed gun their mount points carry a
-- 180 deg roll (partRotate, as vanilla's pistol scope: 180 0 -180).
MF.FRAMES = {
    long = { axes = function(x, y, z) return z, x, y end, roll = true, muzzleRotate = "-90.0000 0.0000 180.0000",
             partRotate = "0.0000 0.0000 0.0000" },
    hand = { axes = function(x, y, z) return -z, x, -y end, roll = false, muzzleRotate = "-90.0000 0.0000 0.0000",
             partRotate = "180.0000 0.0000 180.0000",
             -- vanilla's hand holds a pistol 2.4 cm below the barrel (M9 muzzle z -0.028 x 0.85);
             -- ours sat at 1.1 cm and the hand went into the slide (fifth in-game test). The whole
             -- model goes up this much (real metres) so the hand holds it lower on the grip.
             gripDrop = 0.022 },
}

MF.PREVIEW_PPM = 300
MF.PREVIEW_PAD = 2

-- gun slot id -> generic gun point
MF.SLOT_POINT = {
    optic_rail = "top", optic = "top", carry_handle = "top", scope_base = "top", claw_mount = "top",
    receiver_groove = "top", scope_rings = "top",
    side_mount = "side", pu_mount = "side", scope_mount = "side", side_rail = "side",
    under_rail = "under", usp_rail = "under", bipod = "under",
    handguard = "handguard", muzzle = "muzzle", choke = "muzzle",
    stock = "stock", sling = "sling", sidesaddle = "receiver_side",
    recoil_pad = "butt", butt_holder = "butt_side",
}

-- ---------------------------------------------------------------- primitive helpers
function MF.box(m, x0, y0, z0, x1, y1, z1)
    return { t = "box", m = m, a = { math.min(x0, x1), math.min(y0, y1), math.min(z0, z1) },
                                b = { math.max(x0, x1), math.max(y0, y1), math.max(z0, z1) } }
end
--- Box from centre + size.
function MF.boxc(m, cx, cy, cz, sx, sy, sz)
    return MF.box(m, cx - sx / 2, cy - sy / 2, cz - sz / 2, cx + sx / 2, cy + sy / 2, cz + sz / 2)
end
--- Cylinder starting at (x, y, z) running `len` along +axis.
function MF.cyl(m, axis, x, y, z, len, r)
    return { t = "cyl", m = m, axis = axis, c = { x, y, z }, len = len, r = r }
end

function MF.translate(prims, dx, dy, dz)
    local out = {}
    for i, p in ipairs(prims) do
        local q = ZGB.copy(p)
        if q.t == "box" then
            q.a = { q.a[1] + dx, q.a[2] + dy, q.a[3] + dz }
            q.b = { q.b[1] + dx, q.b[2] + dy, q.b[3] + dz }
        else
            q.c = { q.c[1] + dx, q.c[2] + dy, q.c[3] + dz }
        end
        out[i] = q
    end
    return out
end

--- Axis-aligned bounds { min = {x,y,z}, max = {x,y,z} } of a list of prims.
function MF.bounds(prims)
    local mn, mx = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
    local function grow(x, y, z)
        local v = { x, y, z }
        for k = 1, 3 do
            if v[k] < mn[k] then mn[k] = v[k] end
            if v[k] > mx[k] then mx[k] = v[k] end
        end
    end
    for _, p in ipairs(prims) do
        if p.t == "box" then grow(p.a[1], p.a[2], p.a[3]); grow(p.b[1], p.b[2], p.b[3])
        else
            local c, r = p.c, p.r
            local e = { c[1], c[2], c[3] }
            local k = (p.axis == "x" and 1) or (p.axis == "y" and 2) or 3
            e[k] = e[k] + p.len
            for _, q in ipairs({ c, e }) do
                grow(q[1] - (k == 1 and 0 or r), q[2] - (k == 2 and 0 or r), q[3] - (k == 3 and 0 or r))
                grow(q[1] + (k == 1 and 0 or r), q[2] + (k == 2 and 0 or r), q[3] + (k == 3 and 0 or r))
            end
        end
    end
    if mn[1] == math.huge then return { min = { 0, 0, 0 }, max = { 0, 0, 0 } } end
    return { min = mn, max = mx }
end

-- ---------------------------------------------------------------- registries
--- Gun shape family: fn(dims, spec) -> model. Gun dims come from ZGB_Def_Models.
function MF.defineShape(id, fn) MF._shapes[id] = fn end

--- Per-gun dimensions and look: { shape, len, finish, ... }
function MF.defineGun(id, dims) MF._guns[id] = dims; MF._cache = {} end

--- Part model by part id, or by kind as a fallback: fn(partSpec) -> model
function MF.definePart(id, fn) MF._parts[id] = fn; MF._cache = {} end
function MF.definePartKind(kind, fn) MF._kinds[kind] = fn; MF._cache = {} end

function MF.gunDims(id) return MF._guns[id] end

local function finish(model)
    model.prims = model.prims or {}
    model.points = model.points or {}
    model.provides = model.provides or {}
    return model
end

--- True when the gun's stock comes off (it has a stock slot): its model is built without it,
--- and the stock it shipped with is a part of its own (Def_Parts factoryOf).
function MF.removableStock(spec)
    for _, s in pairs(spec.slots or {}) do if s.kind == "stock" then return true end end
    return false
end

--- Model of a gun's base (nothing attached). nil if the gun has no model data.
--- m.stockPrims: the prims tagged "stock" that a removable-stock gun leaves out.
function MF.gunModel(spec)
    local key = "gun:" .. spec.id
    if MF._cache[key] then return MF._cache[key] end
    local dims = MF._guns[spec.id]
    local shape = dims and MF._shapes[dims.shape]
    if not shape then return nil end
    local m = finish(shape(dims, spec))
    if MF.removableStock(spec) then
        local keep, stock = {}, {}
        for _, p in ipairs(m.prims) do
            if p.tag == "stock" then stock[#stock + 1] = p else keep[#keep + 1] = p end
        end
        m.prims, m.stockPrims = keep, stock
    end
    -- one-handed guns sit higher in the hand (MF.FRAMES.hand.gripDrop): prims and points together
    local drop = (not spec.twoHanded) and MF.FRAMES.hand.gripDrop or 0
    if drop ~= 0 then
        m.prims = MF.translate(m.prims, 0, drop, 0)
        for _, set in ipairs({ m.points, m.provides }) do
            for name, p in pairs(set) do set[name] = { p[1], p[2] + drop, p[3] } end
        end
    end
    m.id, m.kind = spec.id, "gun"
    MF._cache[key] = m
    return m
end

--- Model of an attachment, or nil for parts with no visible model (chokes).
function MF.partModel(part)
    if part.noModel then return nil end
    local key = "part:" .. part.id
    if MF._cache[key] then return MF._cache[key] end
    local m
    if part.factoryOf then
        -- the stock a gun shipped with: the gun's own stock prims, mounting point at the origin
        local spec = ZGB.WeaponFactory and ZGB.WeaponFactory.get(part.factoryOf)
        local gun = spec and MF.gunModel(spec)
        local at = gun and gun.points.stock
        if not (gun and at and gun.stockPrims and #gun.stockPrims > 0) then return nil end
        m = finish({ prims = MF.translate(gun.stockPrims, -at[1], -at[2], -at[3]) })
    else
        local fn = MF._parts[part.id] or MF._kinds[part.kind]
        if not fn then return nil end
        m = finish(fn(part))
    end
    m.id, m.kind = part.id, "part"
    MF._cache[key] = m
    return m
end

MF.magazineBuilder, MF.casingBuilder = nil, nil
function MF.magazineModel(mag)
    local key = "mag:" .. mag.id
    if not MF._cache[key] and MF.magazineBuilder then
        local m = finish(MF.magazineBuilder(mag)); m.id, m.kind = mag.id, "magazine"
        MF._cache[key] = m
    end
    return MF._cache[key]
end
function MF.casingModel(id, group)
    local key = "casing:" .. id
    if not MF._cache[key] and MF.casingBuilder then
        local m = finish(MF.casingBuilder(id, group)); m.id, m.kind = id, "casing"
        MF._cache[key] = m
    end
    return MF._cache[key]
end

--- Where a gun slot sits on the bare gun.
function MF.slotPoint(spec, slotId)
    local m = MF.gunModel(spec)
    local name = MF.SLOT_POINT[slotId]
    return m and name and m.points[name] or nil
end

function MF._resetCache() MF._cache = {} end

return MF
