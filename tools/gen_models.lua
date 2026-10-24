--[[
    Generates every placeholder model from the model factory, one folder per
    item so the 3D artist can replace them one by one:

      media/models_X/ZGB/Guns/<Category>/<GunId>/<GunId>.X           base gun
      media/models_X/ZGB/Guns/<Category>/<GunId>/<GunId>__<Parts>.X  variants (baked parts)
      media/models_X/ZGB/Attachments/<Type>/<PartId>/<PartId>.X      e.g. Attachments/Suppressors/Suppressor_Rifle556/
      media/models_X/ZGB/Magazines/<Caliber>/<MagId>/<MagId>.X
      media/models_X/ZGB/Casings/<CasingId>/<CasingId>.X
      media/textures/ZGB/ZGB_Placeholder.png       colour atlas shared by every placeholder
      media/textures/Item_ZGB_<Id>.png              inventory icons (side view)
      media/textures/ZGB/Preview/<Id>.png           Gunsmith preview sprites (side view, 300 px/m)
      media/scripts/ZGB_models.txt                  model scripts + attachment points (GENERATED)

    Run from the repo root after editing ZGB_Def_Models.lua, parts or guns:

        lua5.1 tools/gen_models.lua

    !! VERIFY in game: the .X axis convention / winding, the model script
    !! syntax, and `scale`. Change AXES / WINDING / SCALE below, not the data.
]]
local CORE = "Contents/mods/ZEGunsOfBohemiaCore/42/media/"
package.path = CORE .. "lua/shared/?.lua;tools/lib/?.lua;" .. package.path
local realPrint = print
print = function() end
require "ZGB/Defs/ZGB_Def_Parts"
require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/Defs/ZGB_Def_Models"
require "ZGB/ZGB_Visuals"
print = realPrint
local Img = require "zgb_image"

local WF, PF, MGF, MF, V, AC = ZGB.WeaponFactory, ZGB.PartFactory, ZGB.MagazineFactory, ZGB.ModelFactory, ZGB.Visuals, ZGB.AmmoCatalog

local AXES    = function(x, y, z) return x, y, z end   -- our (forward, up, right) -> file axes. VERIFY
local WINDING = "ccw"                                    -- "ccw" | "cw". VERIFY (inside-out faces = flip)
local SCALE   = 1.0                                      -- model script scale. VERIFY
local SEGMENTS = 8
local ATLAS = "ZGB_Placeholder"

local isWindows = package.config:sub(1, 1) == "\\"
local function mkdir(path)
    if isWindows then os.execute('mkdir "' .. path:gsub("/", "\\") .. '" 2>nul')
    else os.execute('mkdir -p "' .. path .. '"') end
end
local function rmdir(path)
    if isWindows then os.execute('rmdir /s /q "' .. path:gsub("/", "\\") .. '" 2>nul')
    else os.execute('rm -rf "' .. path .. '"') end
end
local function write(path, text)
    local f = assert(io.open(path, "wb")); f:write(text); f:close()
end

-- ---------------------------------------------------------------- folders
local CATEGORY_FOLDER = { handgun = "Handguns", revolver = "RevolversHandCannons", assault_rifle = "AssaultRifles",
    dmr = "DMRs", sniper = "SniperRifles", smg = "SMGs", shotgun = "Shotguns", lever = "LeverActions" }
local function partFolder(p)
    local id = p.id
    if p.kind == "muzzle" then
        if id:find("Suppressor") then return "Suppressors" end
        if id:find("FlashHider") then return "FlashHiders" end
        if id:find("Choke") then return "Chokes" end
        return "MuzzleBrakes"
    end
    if p.kind == "underbarrel" then
        if id:find("^Grip") then return "Grips" end
        if id:find("^Laser") then return "Lasers" end
        return "Lights"
    end
    local map = { optic = "Optics", mount = "Mounts", handguard = "Handguards", adapter = "Adapters", bipod = "Bipods",
                  stock = "Stocks", sidesaddle = "ShellHolders", shellholder = "ShellHolders", recoilpad = "RecoilPads", sling = "Slings" }
    return map[p.kind] or "Other"
end
local function calFolder(id) return (AC.CALIBERS[id].label:gsub("[^%w]+", "")) end

-- ---------------------------------------------------------------- meshes
local function uvFor(mat)
    local m = MF.MATERIALS[mat] or MF.MATERIALS.steel
    local g = MF.ATLAS_GRID
    return ((m.i % g) + 0.5) / g, (math.floor(m.i / g) + 0.5) / g
end

local function meshOf(prims)
    local verts, norms, uvs, faces = {}, {}, {}, {}
    local function v(x, y, z, nx, ny, nz, u, w)
        verts[#verts + 1] = { AXES(x, y, z) }; norms[#norms + 1] = { AXES(nx, ny, nz) }; uvs[#uvs + 1] = { u, w }
        return #verts - 1
    end
    local function tri(a, b, c)
        if WINDING == "ccw" then faces[#faces + 1] = { a, b, c } else faces[#faces + 1] = { a, c, b } end
    end
    local function quad(p1, p2, p3, p4, n, u, w)
        local a = v(p1[1], p1[2], p1[3], n[1], n[2], n[3], u, w)
        local b = v(p2[1], p2[2], p2[3], n[1], n[2], n[3], u, w)
        local c = v(p3[1], p3[2], p3[3], n[1], n[2], n[3], u, w)
        local d = v(p4[1], p4[2], p4[3], n[1], n[2], n[3], u, w)
        tri(a, b, c); tri(a, c, d)
    end
    for _, p in ipairs(prims) do
        local u, w = uvFor(p.m)
        if p.t == "box" then
            local x0, y0, z0, x1, y1, z1 = p.a[1], p.a[2], p.a[3], p.b[1], p.b[2], p.b[3]
            quad({ x1, y0, z0 }, { x1, y1, z0 }, { x1, y1, z1 }, { x1, y0, z1 }, { 1, 0, 0 }, u, w)
            quad({ x0, y0, z1 }, { x0, y1, z1 }, { x0, y1, z0 }, { x0, y0, z0 }, { -1, 0, 0 }, u, w)
            quad({ x0, y1, z0 }, { x0, y1, z1 }, { x1, y1, z1 }, { x1, y1, z0 }, { 0, 1, 0 }, u, w)
            quad({ x0, y0, z1 }, { x0, y0, z0 }, { x1, y0, z0 }, { x1, y0, z1 }, { 0, -1, 0 }, u, w)
            quad({ x0, y0, z1 }, { x1, y0, z1 }, { x1, y1, z1 }, { x0, y1, z1 }, { 0, 0, 1 }, u, w)
            quad({ x1, y0, z0 }, { x0, y0, z0 }, { x0, y1, z0 }, { x1, y1, z0 }, { 0, 0, -1 }, u, w)
        else
            -- local frame: t along the axis, (s1, s2) across it
            local function at(t, a1, a2)
                local c = p.c
                if p.axis == "x" then return { c[1] + t, c[2] + a1, c[3] + a2 } end
                if p.axis == "y" then return { c[1] + a2, c[2] + t, c[3] + a1 } end
                return { c[1] + a1, c[2] + a2, c[3] + t }
            end
            local function dir(a1, a2) local q = at(0, a1, a2); return { q[1] - p.c[1], q[2] - p.c[2], q[3] - p.c[3] } end
            local axisN = dir(0, 0); axisN = (p.axis == "x" and { 1, 0, 0 }) or (p.axis == "y" and { 0, 1, 0 }) or { 0, 0, 1 }
            for i = 0, SEGMENTS - 1 do
                local t0, t1 = i / SEGMENTS * 2 * math.pi, (i + 1) / SEGMENTS * 2 * math.pi
                local c0, s0, c1, s1 = math.cos(t0), math.sin(t0), math.cos(t1), math.sin(t1)
                local n0 = dir(c0, s0)
                quad(at(0, p.r * c0, p.r * s0), at(0, p.r * c1, p.r * s1), at(p.len, p.r * c1, p.r * s1), at(p.len, p.r * c0, p.r * s0),
                     { n0[1], n0[2], n0[3] }, u, w)
                -- caps
                local a = v(at(p.len, 0, 0)[1], at(p.len, 0, 0)[2], at(p.len, 0, 0)[3], axisN[1], axisN[2], axisN[3], u, w)
                local q0, q1 = at(p.len, p.r * c0, p.r * s0), at(p.len, p.r * c1, p.r * s1)
                local b = v(q0[1], q0[2], q0[3], axisN[1], axisN[2], axisN[3], u, w)
                local c = v(q1[1], q1[2], q1[3], axisN[1], axisN[2], axisN[3], u, w)
                tri(a, b, c)
                local e = at(0, 0, 0)
                local a2 = v(e[1], e[2], e[3], -axisN[1], -axisN[2], -axisN[3], u, w)
                local r0, r1 = at(0, p.r * c0, p.r * s0), at(0, p.r * c1, p.r * s1)
                local b2 = v(r0[1], r0[2], r0[3], -axisN[1], -axisN[2], -axisN[3], u, w)
                local c2 = v(r1[1], r1[2], r1[3], -axisN[1], -axisN[2], -axisN[3], u, w)
                tri(a2, c2, b2)
            end
        end
    end
    return verts, norms, uvs, faces
end

local function f4(n) local s = string.format("%.4f", n); if s == "-0.0000" then s = "0.0000" end return s end
local function xFile(prims)
    local verts, norms, uvs, faces = meshOf(prims)
    local o = { "xof 0303txt 0032\n\n",
        "Material ", ATLAS, " {\n 1.000000;1.000000;1.000000;1.000000;;\n 8.000000;\n 0.000000;0.000000;0.000000;;\n 0.000000;0.000000;0.000000;;\n",
        " TextureFilename { \"", ATLAS, ".png\"; }\n}\n\n",
        "Frame ZGB_Root {\n FrameTransformMatrix { 1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0;; }\n",
        " Mesh ZGB_Mesh {\n  ", #verts, ";\n" }
    local function list(items, fmt)
        for i, it in ipairs(items) do o[#o + 1] = "  " .. fmt(it) .. (i == #items and ";\n" or ",\n") end
    end
    list(verts, function(p) return f4(p[1]) .. ";" .. f4(p[2]) .. ";" .. f4(p[3]) .. ";" end)
    o[#o + 1] = "  " .. #faces .. ";\n"
    list(faces, function(f) return "3;" .. f[1] .. "," .. f[2] .. "," .. f[3] .. ";" end)
    o[#o + 1] = "  MeshNormals {\n  " .. #norms .. ";\n"
    list(norms, function(p) return f4(p[1]) .. ";" .. f4(p[2]) .. ";" .. f4(p[3]) .. ";" end)
    o[#o + 1] = "  " .. #faces .. ";\n"
    list(faces, function(f) return "3;" .. f[1] .. "," .. f[2] .. "," .. f[3] .. ";" end)
    o[#o + 1] = "  }\n  MeshTextureCoords {\n  " .. #uvs .. ";\n"
    list(uvs, function(t) return f4(t[1]) .. ";" .. f4(t[2]) .. ";" end)
    o[#o + 1] = "  }\n  MeshMaterialList {\n  1;\n  " .. #faces .. ";\n"
    for i = 1, #faces do o[#o + 1] = "  0" .. (i == #faces and ";;\n" or ",\n") end
    o[#o + 1] = "  {" .. ATLAS .. "}\n  }\n }\n}\n"
    return table.concat(o), #faces
end

-- ---------------------------------------------------------------- outputs
local MODELS, TEX = CORE .. "models_X/ZGB/", CORE .. "textures/ZGB/"
rmdir(MODELS); rmdir(TEX)
if isWindows then os.execute('del /q "' .. (CORE .. "textures/Item_ZGB_*.png"):gsub("/", "\\") .. '" 2>nul')
else os.execute('rm -f "' .. CORE .. 'textures/"Item_ZGB_*.png') end
mkdir(TEX .. "Preview")
local scripts = { "/*\n    ZE Guns Of Bohemia - model scripts.\n    GENERATED by tools/gen_models.lua from ZGB_Def_Models.lua - do not edit by hand.\n",
                  "    Attachment points are where parts mount; part models mount by their \"anchor\".\n    VERIFY: syntax, scale and axes on your build.\n*/\nmodule ZGB\n{\n    imports { Base }\n" }
local stats = { models = 0, faces = 0, icons = 0, previews = 0 }

local function modelScript(id, mesh, points)
    local o = { string.format("\n    model %s\n    {\n        mesh = %s,\n        texture = ZGB/%s,\n        scale = %s,\n", id, mesh, ATLAS, tostring(SCALE)) }
    for _, name in ipairs(ZGB.sortedKeys(points)) do
        local p = points[name]
        local x, y, z = AXES(p[1], p[2], p[3])
        o[#o + 1] = string.format("        attachment %s\n        {\n            offset = %s %s %s,\n            rotate = 0.0000 0.0000 0.0000,\n        }\n", name, f4(x), f4(y), f4(z))
    end
    o[#o + 1] = "    }\n"
    scripts[#scripts + 1] = table.concat(o)
end

local function emitModel(folder, id, prims, points)
    mkdir(MODELS .. folder)
    local text, nf = xFile(prims)
    write(MODELS .. folder .. "/" .. id .. ".X", text)
    modelScript(id, "ZGB/" .. folder .. "/" .. id, points)
    stats.models, stats.faces = stats.models + 1, stats.faces + nf
end

local function icon(name, prims)
    local b = MF.bounds(prims)
    local wM, hM = math.max(0.01, b.max[1] - b.min[1]), math.max(0.01, b.max[2] - b.min[2])
    local ppm = math.min(30 / wM, 30 / hM)
    local sprite = Img.renderSide(prims, MF.MATERIALS, b, ppm, 0, 3)
    local out = Img.new(32, 32)
    local ox, oy = math.floor((32 - sprite.w) / 2), math.floor((32 - sprite.h) / 2)
    for y = 0, sprite.h - 1 do
        for x = 0, sprite.w - 1 do
            local i = (y * sprite.w + x) * 4
            local a = sprite.px[i + 4]
            if a > 0 then Img.set(out, ox + x, oy + y, sprite.px[i + 1], sprite.px[i + 2], sprite.px[i + 3], a) end
        end
    end
    Img.save(out, CORE .. "textures/Item_ZGB_" .. name .. ".png")
    stats.icons = stats.icons + 1
end

local function preview(name, prims, bounds)
    local sprite = Img.renderSide(prims, MF.MATERIALS, bounds or MF.bounds(prims), MF.PREVIEW_PPM, MF.PREVIEW_PAD, 2)
    Img.save(sprite, TEX .. "Preview/" .. name .. ".png")
    stats.previews = stats.previews + 1
end

-- atlas
local G = MF.ATLAS_GRID
local atlas = Img.new(G * 16, G * 16)
for _, m in pairs(MF.MATERIALS) do
    local cx, cy = (m.i % G) * 16, math.floor(m.i / G) * 16
    Img.fillRect(atlas, cx, cy, cx + 16, cy + 16, m.rgb[1] * 255, m.rgb[2] * 255, m.rgb[3] * 255, 255)
end
Img.save(atlas, TEX .. ATLAS .. ".png")

-- guns: base + every variant, icons, preview sprites (with hidden pieces left out)
for _, spec in ipairs(WF.all()) do
    local folder = "Guns/" .. (CATEGORY_FOLDER[spec.category] or "Other") .. "/" .. spec.id
    local base = MF.gunModel(spec)
    for _, att in ipairs(V.variants(spec)) do
        local vm = V.variantModel(spec, att)
        emitModel(folder, vm.id, vm.prims, vm.points)
    end
    icon(spec.id, base.prims)
    local full = MF.bounds(base.prims)
    preview(spec.id, base.prims, full)
    local function without(tags)
        local out = {}
        for _, p in ipairs(base.prims) do if not (p.tag and tags[p.tag]) then out[#out + 1] = p end end
        return out
    end
    local hasTag = {}
    for _, p in ipairs(base.prims) do if p.tag then hasTag[p.tag] = true end end
    if hasTag.stock then preview(spec.id .. "_nostock", without({ stock = true }), full) end
    if hasTag.handguard then preview(spec.id .. "_nohandguard", without({ handguard = true }), full) end
    if hasTag.stock and hasTag.handguard then preview(spec.id .. "_nostock_nohandguard", without({ stock = true, handguard = true }), full) end
end

-- attachments
for _, part in ipairs(PF.all()) do
    local m = MF.partModel(part)
    if m then
        emitModel("Attachments/" .. partFolder(part) .. "/" .. part.id, part.id, m.prims, ZGB.merge({ anchor = { 0, 0, 0 }, world = { 0, 0, 0 } }, m.provides))
        icon(part.id, m.prims)
        preview(part.id, m.prims)
    else
        icon(part.id, { MF.cyl("steel", "x", 0, 0, 0, 0.05, 0.012) })   -- no model (chokes): a plain tube icon
    end
end

-- magazines and casings
for _, mag in ipairs(MGF.all()) do
    local m = MF.magazineModel(mag)
    emitModel("Magazines/" .. calFolder(mag.caliber) .. "/" .. mag.id, mag.id, m.prims, { anchor = { 0, 0, 0 }, world = { 0, 0, 0 } })
    icon(mag.id, m.prims)
end
local doneCasing = {}
for group, c in pairs(AC.CASINGS) do
    if not doneCasing[c.id] then
        doneCasing[c.id] = true
        local m = MF.casingModel(c.id, group)
        emitModel("Casings/" .. c.id, c.id, m.prims, { world = { 0, 0, 0 } })
        icon(c.id, m.prims)
    end
end

scripts[#scripts + 1] = "}\n"
write(CORE .. "scripts/ZGB_models.txt", table.concat(scripts))
print(string.format("wrote %d models (%d triangles), %d icons, %d preview sprites, atlas %s.png",
      stats.models, stats.faces, stats.icons, stats.previews, ATLAS))
