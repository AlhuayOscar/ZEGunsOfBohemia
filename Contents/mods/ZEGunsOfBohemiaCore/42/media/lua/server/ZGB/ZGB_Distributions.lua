--[[
    ZGB_Distributions.lua  —  swap vanilla guns for factory guns in loot tables.

    Replacing at the LOOT level (instead of re-skinning vanilla items) means a
    vanilla gun's script/anims never get mixed with ours: the vanilla item just
    stops spawning, ours spawns in its place with the same weight.

    Known gaps (v0.2): guns spawned by code (zombie belts/holsters, map stories)
    and vanilla guns already in existing saves are not converted.
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/Factory/ZGB_WeaponFactory"

ZGB.Distributions = ZGB.Distributions or { map = {}, extras = {} }
local D = ZGB.Distributions

--- Register a 1:1 replacement. Edit this list to taste.
function D.replace(vanillaFullType, ourFullType)
    D.map[vanillaFullType] = ourFullType
    local short = string.match(vanillaFullType, "^Base%.(.+)$")
    if short then D.map[short] = ourFullType end   -- tables often list items without "Base."
end

--- Wherever `ourFullType` ends up in a loot list, also add `extraFullType`
--- at `weightFactor` of its weight (e.g. drums spawn alongside 30rd mags, rarer).
function D.alsoSpawn(ourFullType, extraFullType, weightFactor)
    local keys = { ourFullType }
    local short = string.match(ourFullType, "^Base%.(.+)$")
    if short then keys[2] = short end              -- vanilla lists often omit "Base."
    for _, k in ipairs(keys) do
        D.extras[k] = D.extras[k] or {}
        table.insert(D.extras[k], { item = extraFullType, factor = weightFactor })
    end
end

-- Calibers vanilla doesn't have need somewhere to spawn: next to this vanilla ammo.
D.AMMO_ANCHORS = {
    ["762x39"] = { "Base.556Bullets", 0.6 },
    ["22lr"]   = { "Base.Bullets9mm", 0.5 },
}

--- Ammo variants spawn next to the caliber's standard rounds, weighted by rarity.
--- Only calibers used by a registered gun are added (no orphan ammo in loot).
function D.registerAmmoLoot()
    local used = {}
    for _, spec in ipairs(ZGB.WeaponFactory.all()) do used[spec.caliber] = true end
    for calId in pairs(used) do
        local variants = ZGB.AmmoCatalog.variantsFor(calId)
        local std = variants[1]
        local anchor, factor = std.item, 1
        if not std.isVanilla then
            local a = D.AMMO_ANCHORS[calId]
            if a then
                anchor, factor = a[1], a[2]
                D.alsoSpawn(anchor, std.item, factor)
            else
                ZGB.warn("No loot anchor for caliber", calId, "- its ammo won't spawn")
            end
        end
        for i = 2, #variants do
            D.alsoSpawn(anchor, variants[i].item, factor * (variants[i].rarity or 0.2))
        end
    end
end

-- Example mapping. Vanilla has no AK — pick what makes sense for your mod. VERIFY ids on your build.
D.replace("Base.AssaultRifle", "ZGB.AK47")
D.replace("Base.Pistol",       "ZGB.Glock17")
D.replace("Base.Shotgun",      "ZGB.M590")
-- magazines follow their guns
D.replace("Base.556Clip",      "ZGB.AK47_Mag30")
D.replace("Base.9mmClip",      "ZGB.Glock17_Mag17")
-- alternate magazines: rarer than the standard ones
D.alsoSpawn("ZGB.AK47_Mag30",    "ZGB.AK47_Drum75",  0.15)
D.alsoSpawn("ZGB.Glock17_Mag17", "ZGB.Glock17_Mag33", 0.25)

local function replaceInItemList(items)
    local n, toAdd = 0, {}
    for i = 1, #items, 2 do                     -- flat list: name, weight, name, weight...
        local rep = D.map[items[i]]
        if rep then items[i] = rep; n = n + 1 end
        for _, e in ipairs(D.extras[items[i]] or {}) do
            toAdd[#toAdd + 1] = { e.item, (tonumber(items[i + 1]) or 1) * e.factor }
        end
    end
    for _, a in ipairs(toAdd) do               -- append after the loop, never while iterating
        items[#items + 1] = a[1]; items[#items + 1] = a[2]
    end
    return n
end

local function walk(t, seen, depth)
    if type(t) ~= "table" or seen[t] or depth > 8 then return 0 end
    seen[t] = true
    local n = 0
    if type(t.items) == "table" then n = n + replaceInItemList(t.items) end
    if type(t.junk) == "table" and type(t.junk.items) == "table" then n = n + replaceInItemList(t.junk.items) end
    for k, v in pairs(t) do
        if k ~= "items" and type(v) == "table" then n = n + walk(v, seen, depth + 1) end
    end
    return n
end

function D.apply()
    if not D._ammoRegistered then D.registerAmmoLoot(); D._ammoRegistered = true end
    local seen, n = {}, 0
    if ProceduralDistributions then n = n + walk(ProceduralDistributions.list, seen, 0) end
    if SuburbsDistributions   then n = n + walk(SuburbsDistributions, seen, 0) end
    if VehicleDistributions   then n = n + walk(VehicleDistributions, seen, 0) end
    ZGB.log("Loot: replaced", n, "vanilla gun entries")
end

if Events and Events.OnPostDistributionMerge then
    Events.OnPostDistributionMerge.Add(D.apply)
end

return D
