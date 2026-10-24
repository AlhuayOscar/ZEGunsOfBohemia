--[[
    ZGB_Stats.lua  —  final weapon stats = spec.stats + attachment mods.

    Always recomputed FROM SCRATCH (never "add the delta to the current value"),
    so attaching/detaching 100 times can't drift the numbers, and vanilla part
    modifiers can't stack on top of ours.
      order: all `add` first, then all `mul`, then clamp.
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_PartFactory"
require "ZGB/ZGB_Magazines"
require "ZGB/Factory/ZGB_AmmoCatalog"

ZGB.Stats = ZGB.Stats or {}
local S = ZGB.Stats

S.CLAMP = {
    minDamage   = { 0.05, 50 }, maxDamage  = { 0.05, 50 },
    range       = { 1, 60 },    minRange   = { 0, 5 },
    aimTime     = { 1, 200 },   recoilDelay= { 0, 200 },
    hitChance   = { 1, 100 },   critChance = { 0, 100 },
    reloadTime  = { 1, 200 },   soundRadius= { 1, 300 },
    weight      = { 0.1, 50 },  projectileCount = { 1, 20 },
}

--- magFullType (optional): the loaded magazine; its `mods` count like a part's.
--- ammoFullType (optional): the loaded ammo variant (AP, HP, slug...).
--- extra (optional): list of { mods = { add=, mul=, set= } } for transient effects
--- such as the burst recoil penalty. They join the same from-scratch pass.
--- order: all add -> all mul -> all set -> clamp.
function S.compute(spec, att, magFullType, ammoFullType, extra)
    local out = ZGB.copy(spec.stats or {})
    local PF = ZGB.PartFactory
    local parts = {}
    for _, ft in pairs(att or {}) do
        local p = PF.get(ft)
        if p then parts[#parts + 1] = p end
    end
    if magFullType and ZGB.Magazines then
        local m = ZGB.Magazines.get(spec, magFullType)
        if m and m.mods then parts[#parts + 1] = m end
    end
    if ammoFullType then
        local v = ZGB.AmmoCatalog.variantOfItem(ammoFullType)
        if v and v.caliber == spec.caliber then parts[#parts + 1] = v end
    end
    for _, e in ipairs(extra or {}) do
        if e.mods then parts[#parts + 1] = { mods = { add = e.mods.add or {}, mul = e.mods.mul or {}, set = e.mods.set } } end
    end
    if spec.ballistics and spec.ballistics.projectileCount and out.projectileCount == nil then
        out.projectileCount = spec.ballistics.projectileCount
    end
    for _, p in ipairs(parts) do
        for k, v in pairs(p.mods.add or {}) do out[k] = (out[k] or 0) + v end
    end
    for _, p in ipairs(parts) do
        for k, v in pairs(p.mods.mul or {}) do out[k] = (out[k] or 0) * v end
    end
    for _, p in ipairs(parts) do
        for k, v in pairs(p.mods.set or {}) do out[k] = v end
    end
    for k, range in pairs(S.CLAMP) do
        if out[k] then
            if out[k] < range[1] then out[k] = range[1] end
            if out[k] > range[2] then out[k] = range[2] end
        end
    end
    if out.minDamage and out.maxDamage and out.minDamage > out.maxDamage then
        out.minDamage = out.maxDamage
    end
    return out
end

return S
