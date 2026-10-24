--[[
    ZGB_Distributions.lua  —  swap vanilla guns for factory guns in loot tables.

    Replacing at the LOOT level (instead of re-skinning vanilla items) means a
    vanilla gun's script/anims never get mixed with ours: the vanilla item just
    stops spawning, ours spawns in its place with the same weight.

    v0.4: everything is derived from the catalogue. A gun with `replaces` takes
    the vanilla gun's place; every other gun spawns next to its family's anchor
    at its `rarity`; magazines spawn next to their gun by tier
    (ZGB_MagazineFactory.TIERS[tier].loot).

    Known gaps: guns spawned by code (zombie belts/holsters, map stories)
    and vanilla guns already in existing saves are not converted.
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_Mode"
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
    ["22lr"]      = { "Base.Bullets9mm", 0.5 },
    ["380acp"]    = { "Base.Bullets9mm", 0.3 },
    ["9x18"]      = { "Base.Bullets9mm", 0.15 },
    ["762x25"]    = { "Base.Bullets9mm", 0.15 },
    ["40sw"]      = { "Base.Bullets9mm", 0.4 },
    ["57x28"]     = { "Base.Bullets9mm", 0.08 },
    ["50ae"]      = { "Base.Bullets44",  0.15 },
    ["762x38r"]   = { "Base.Bullets38",  0.1 },
    ["357mag"]    = { "Base.Bullets38",  0.6 },
    ["45colt"]    = { "Base.Bullets45",  0.4 },
    ["454casull"] = { "Base.Bullets44",  0.15 },
    ["500sw"]     = { "Base.Bullets44",  0.08 },
    ["545x39"]    = { "Base.556Bullets", 0.3 },
    ["762x39"]    = { "Base.556Bullets", 0.6 },
    ["762x54r"]   = { "Base.308Bullets", 0.3 },
    ["65cm"]      = { "Base.308Bullets", 0.2 },
    ["3006"]      = { "Base.308Bullets", 0.5 },
    ["303brit"]   = { "Base.308Bullets", 0.15 },
    ["792x57"]    = { "Base.308Bullets", 0.15 },
    ["3030"]      = { "Base.308Bullets", 0.6 },
    ["4570"]      = { "Base.308Bullets", 0.15 },
    ["338lm"]     = { "Base.308Bullets", 0.05 },
    ["50bmg"]     = { "Base.308Bullets", 0.02 },
    ["410ga"]     = { "Base.ShotgunShells", 0.3 },
}

-- Guns that replace nothing spawn next to their family's anchor gun (which does
-- replace a vanilla gun), at the gun's `rarity`. SMGs share the rifle tables.
D.FAMILY_ANCHORS = {
    handgun = "ZGB.Beretta92FS", revolver = "ZGB.SW_Model10", assault_rifle = "ZGB.M16A2",
    dmr = "ZGB.M14", sniper = "ZGB.Rem700", smg = "ZGB.M16A2", shotgun = "ZGB.M590", lever = "ZGB.Rem700",
}

-- Vanilla magazines become ours (the vanilla guns they fed no longer spawn). VERIFY ids on your build.
D.VANILLA_MAGAZINES = {
    ["Base.9mmClip"] = "ZGB.Beretta92_Mag15", ["Base.45Clip"]  = "ZGB.M1911_Mag7",
    ["Base.44Clip"]  = "ZGB.DEagle_Mag7",     ["Base.556Clip"] = "ZGB.STANAG_Mag30",
    ["Base.M14Clip"] = "ZGB.M14_Mag20",       ["Base.223Clip"] = "ZGB.STANAG_Mag30",
    ["Base.308Clip"] = "ZGB.SR25_Mag20",
}

--- Guns from `replaces` / family anchors, and every magazine next to its gun by tier.
function D.registerWeaponLoot()
    for vanilla, ours in pairs(D.VANILLA_MAGAZINES) do D.replace(vanilla, ours) end
    local fromVanilla = {}
    for _, ours in pairs(D.VANILLA_MAGAZINES) do fromVanilla[ours] = true end

    local best = {}   -- anchor -> item -> factor (shared magazines keep the highest)
    local function offer(anchor, item, factor)
        best[anchor] = best[anchor] or {}
        if (best[anchor][item] or 0) < factor then best[anchor][item] = factor end
    end
    for _, spec in ipairs(ZGB.WeaponFactory.all()) do
        local anchor, factor = spec.fullType, 1
        if spec.replaces and #spec.replaces > 0 then
            for _, vanilla in ipairs(spec.replaces) do D.replace(vanilla, spec.fullType) end
        else
            anchor, factor = D.FAMILY_ANCHORS[spec.category], spec.rarity
            if anchor then offer(anchor, spec.fullType, factor)
            else ZGB.warn("No loot anchor for category", spec.category, "-", spec.id, "won't spawn") end
        end
        if anchor then
            for _, m in ipairs(spec.magazines) do
                if not (fromVanilla[m.item] and m.tier == "standard") then
                    offer(anchor, m.item, factor * ZGB.MagazineFactory.TIERS[m.tier].loot)
                end
            end
        end
    end
    for _, anchor in ipairs(ZGB.sortedKeys(best)) do
        for _, item in ipairs(ZGB.sortedKeys(best[anchor])) do D.alsoSpawn(anchor, item, best[anchor][item]) end
    end
end

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
    if ZGB.Mode and ZGB.Mode.isBlocked() then return end
    if not D._registered then
        D.registerWeaponLoot(); D.registerAmmoLoot(); D._registered = true
    end
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
