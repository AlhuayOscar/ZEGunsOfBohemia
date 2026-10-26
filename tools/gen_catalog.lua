--[[
    Dumps the gun / magazine / attachment catalogue as JSON for people who
    don't read Lua (the 3D side, docs, the catalogue page). Run from the repo
    root after editing anything in Defs/ or ZGB_AmmoCatalog.lua:

        lua5.1 tools/gen_catalog.lua            -> docs/catalogue.json
        lua5.1 tools/gen_catalog.lua out.json   -> somewhere else
]]
local ROOT = "Contents/mods/ZEGunsOfBohemiaCore/42/media/"
package.path = ROOT .. "lua/shared/?.lua;tools/lib/?.lua;" .. package.path
local realPrint = print
print = function() end          -- silence mod logging
require "ZGB/Defs/ZGB_Def_Parts"
require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/ZGB_Attachments"
require "ZGB/Factory/ZGB_RecoilFactory"
print = realPrint

local WF, MF, PF, AC, R = ZGB.WeaponFactory, ZGB.MagazineFactory, ZGB.PartFactory, ZGB.AmmoCatalog, ZGB.Attachments

local encode = require("zgb_json").encode

-- ---------------------------------------------------------------- slot trees
local function sortedSlots(slots)
    local ids = ZGB.sortedKeys(slots)
    table.sort(ids, function(a, b)
        local oa, ob = slots[a].order or 99, slots[b].order or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return ids
end

-- slot -> { label, kind, accepts, parts = { { id, name, provides = {slot...} } } }
local function slotTree(slotId, def, depth)
    local node = { id = slotId, label = def.label or slotId, kind = def.kind, accepts = def.accepts, parts = {} }
    if depth > 6 then return node end
    for _, p in ipairs(PF.all()) do
        if R.accepts(def, p) then
            local child = { id = p.id, name = p.displayName, provides = {} }
            for _, cid in ipairs(sortedSlots(p.provides)) do
                child.provides[#child.provides + 1] = slotTree(cid, p.provides[cid], depth + 1)
            end
            node.parts[#node.parts + 1] = child
        end
    end
    return node
end

-- ---------------------------------------------------------------- guns
local guns = {}
for _, s in ipairs(WF.all()) do
    local g = {
        id = s.id, name = s.displayName, category = s.category, archetype = s.archetype,
        caliber = s.caliber, caliberLabel = AC.CALIBERS[s.caliber].label,
        weight = s.stats.weight, notes = s.notes, fireModes = s.fireModes,
        internalCapacity = s.internalCapacity, magazines = {}, slots = {},
        replaces = s.replaces, rarity = (not s.replaces) and s.rarity or nil,
        model = "ZGB_" .. s.id,
        animType = s.animType, openBolt = s.openBolt or false,
    }
    local rp = ZGB.RecoilFactory.patternFor(s)
    g.recoil = { pattern = rp.profile, vertical = math.floor(rp.vertical * 100 + 0.5) / 100,
                 horizontal = math.floor(rp.horizontal * 100 + 0.5) / 100, kick = ZGB.RecoilFactory.kickClass(s) }
    for _, m in ipairs(s.magazines) do
        g.magazines[#g.magazines + 1] = { id = m.id, name = m.displayName, tier = m.tier, capacity = m.capacity }
    end
    for _, sid in ipairs(sortedSlots(s.slots)) do g.slots[#g.slots + 1] = slotTree(sid, s.slots[sid], 0) end
    guns[#guns + 1] = g
end

-- ---------------------------------------------------------------- magazines
local mags = {}
for _, m in ipairs(MF.all()) do
    local users = {}
    for _, s in ipairs(WF.gunsForMagazine(m.item)) do users[#users + 1] = s.id end
    mags[#mags + 1] = { id = m.id, name = m.displayName, caliber = m.caliber, caliberLabel = AC.CALIBERS[m.caliber].label,
                        tier = m.tier, capacity = m.capacity, weight = m.weight, guns = users, model = "ZGB_" .. m.id }
end

-- ---------------------------------------------------------------- parts
-- For each part: which guns it fits directly, and which need something fitted first.
local parts = {}
for _, p in ipairs(PF.all()) do
    local direct, chained = {}, {}
    for _, s in ipairs(WF.all()) do
        local onBase = false
        for _, def in pairs(s.slots) do if R.accepts(def, p) then onBase = true; break end end
        if onBase then direct[#direct + 1] = s.id
        elseif R.isCompatible(s, p.fullType) then
            local _, reason, info = R.canAttach(s, {}, p.fullType)
            local chain = {}
            if reason == "needs" and info.chains[1] then
                for _, ft in ipairs(info.chains[1]) do chain[#chain + 1] = PF.get(ft).id end
            end
            chained[#chained + 1] = { gun = s.id, needs = chain }
        end
    end
    local provides = {}
    for _, cid in ipairs(sortedSlots(p.provides)) do
        provides[#provides + 1] = { id = cid, label = p.provides[cid].label or cid, accepts = p.provides[cid].accepts }
    end
    parts[#parts + 1] = { id = p.id, name = p.displayName, kind = p.kind, interface = p.interface,
                          noModel = p.noModel or false, vanillaPartType = p.vanillaPartType,
                          provides = provides, direct = direct, chained = chained, model = "ZGB_" .. p.id }
end

-- ---------------------------------------------------------------- calibers
local calibers = {}
for _, id in ipairs(ZGB.sortedKeys(AC.CALIBERS)) do
    local c, vs = AC.CALIBERS[id], {}
    for _, v in ipairs(AC.variantsFor(id)) do vs[#vs + 1] = v.label end
    calibers[#calibers + 1] = { id = id, label = c.label, group = c.group, energy = c.energy, variants = vs }
end

local animTypes = {}
for _, t in ipairs(ZGB.AnimFactory.types()) do
    local reloads = {}
    for _, kind in ipairs(ZGB.sortedKeys(t.reloads)) do reloads[#reloads + 1] = kind end
    animTypes[#animTypes + 1] = { id = t.id, label = t.label, base = t.base, hands = t.hands, feed = t.feed,
                                  clips = t.clips, reloads = reloads, casing = t.casing }
end

local doc = {
    version = ZGB.VERSION, categories = ZGB.CATEGORIES, tiers = MF.TIER_ORDER,
    guns = guns, magazines = mags, parts = parts, calibers = calibers, animTypes = animTypes,
}
local path = arg[1] or "docs/catalogue.json"
local f = assert(io.open(path, "w"))
f:write(encode(doc)); f:close()
print(string.format("wrote %s: %d guns, %d magazines, %d parts, %d calibers", path, #guns, #mags, #parts, #calibers))
