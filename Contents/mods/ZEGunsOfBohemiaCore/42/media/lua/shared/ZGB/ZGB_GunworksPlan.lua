--[[
    ZGB_GunworksPlan.lua  —  our catalogue as Gunworks (SWMG) registrations.

    Pure: no game API, so what we hand to Gunworks is tested offline. The game-facing
    side (ZGB_Gunworks.lua) only feeds these tables to the Gunworks registries.

    Gunworks is the base the mod runs on since v0.8: it owns reloading (best magazine,
    mixed rounds in a magazine, speedloaders), fire modes with real rate of fire and
    bursts, folding stocks / bipods and the stat layers. We own the catalogue, the
    attachments rules, the Gunsmith, models, sounds and loot.

      families()          one ammo family per caliber: { [family] = { items = {...}, bullets = {...} } }
                          bullets: our variants in menu order (vanilla item first where it exists),
                          then the same-caliber rounds of the Gunworks shared ammunition library
      magazineProfiles()  { [profile] = { weapon = fullType, magazines = {standard, extended, drum} } }
      rateOfFire()        { [weapon fullType] = { rpm, burstCount } } for auto / burst guns
      layer(...)          our stat layer for one weapon: a list of { op, stat, value }
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_WeaponFactory"
require "ZGB/Factory/ZGB_MagazineFactory"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/ZGB_Magazines"
require "ZGB/ZGB_Stats"

ZGB.GunworksPlan = ZGB.GunworksPlan or {}
local P = ZGB.GunworksPlan
local WF, MF, AC, M, S = ZGB.WeaponFactory, ZGB.MagazineFactory, ZGB.AmmoCatalog, ZGB.Magazines, ZGB.Stats

P.MOD_ID = "SWMG"

-- Same-caliber rounds of the Gunworks shared ammunition library (SWMG/media/scripts/
-- AmmunitionLibrary): other Gunworks gun packs drop these, and they fit our guns.
-- Exact calibers only, like the real chambers (.223 Rem in 5.56, .308 Win in 7.62x51).
P.LIBRARY = {
    ["9x19"]   = { "SWMG.9x19_Bullet" },
    ["45acp"]  = { "SWMG.45_Bullet" },
    ["38spl"]  = { "SWMG.38_Bullet" },
    ["357mag"] = { "SWMG.357_Bullet", "SWMG.38_Bullet" },          -- a .357 chamber fires .38 Special
    ["44mag"]  = { "SWMG.44_Bullet" },
    ["50ae"]   = { "SWMG.50_Bullet" },
    ["57x28"]  = { "SWMG.57x28_Bullet" },
    ["556x45"] = { "SWMG.556x45_Bullet", "SWMG.556x45_Bullet_HollowPoint", "SWMG.556x45_Bullet_ArmorPiercing",
                   "SWMG.556x45_Bullet_Subsonic", "SWMG.556x45_Bullet_Overpressured", "SWMG.223_Bullet" },
    ["223rem"] = { "SWMG.223_Bullet" },
    ["545x39"] = { "SWMG.545x39_Bullet" },
    ["762x39"] = { "SWMG.762x39_Bullet" },
    ["308win"] = { "SWMG.308_Bullet", "SWMG.762x51_Bullet" },
    ["762x54r"]= { "SWMG.762x54_Bullet" },
    ["3006"]   = { "SWMG.3006_Bullet" },
    ["3030"]   = { "SWMG.3030_Bullet" },
    ["4570"]   = { "SWMG.4570_Bullet" },
    ["12ga"]   = { "SWMG.12Gauge_Shell_Buckshot", "SWMG.12Gauge_Shell_Slug" },
}

-- What the library rounds DO, in our variant terms, so our stat layer treats an SWMG
-- hollow point like ours. Anything not listed fires as the caliber's standard round.
P.LIBRARY_VARIANT = {
    ["SWMG.556x45_Bullet_HollowPoint"]  = "hp",
    ["SWMG.556x45_Bullet_ArmorPiercing"] = "ap",
    ["SWMG.556x45_Bullet_Subsonic"]     = "subsonic",
    ["SWMG.556x45_Bullet_Overpressured"] = "plusp",
    ["SWMG.12Gauge_Shell_Slug"]         = "slug",
}

-- our stat key -> Gunworks StatsFactory.Registry name
P.STATS = {
    minDamage = "MinDamage", maxDamage = "MaxDamage", range = "MaxRange", minRange = "MinRange",
    aimTime = "AimingTime", recoilDelay = "RecoilDelay", hitChance = "HitChance",
    critChance = "CriticalChance", reloadTime = "ReloadTime", soundRadius = "SoundRadius",
    projectileCount = "ProjectileCount",
}
-- integer stats: Gunworks adjusts with the int setter, which truncates
P.INT = { aimTime = true, recoilDelay = true, hitChance = true, reloadTime = true,
          soundRadius = true, projectileCount = true }

-- Gunworks' own fire modes: it turns Auto / Burst into these and takes RecoilDelay over
P.GUNWORKS_AUTO = { RealAuto = true, RealBurst = true }

-- rate of fire (rounds per minute) per archetype when the gun does not say
P.RPM = { smg = 800, assault_rifle = 700, dmr = 650, shotgun = 300, pistol = 1100, default = 650 }

function P.familyName(caliberId) return "ZGB:" .. caliberId end
function P.profileName(spec) return "ZGB:" .. spec.id end

local function hasMode(spec, mode)
    for _, m in ipairs(spec.fireModes or {}) do if m == mode then return true end end
    return false
end

--- One family per caliber that one of our guns uses.
function P.families()
    local out = {}
    for _, spec in ipairs(WF.all()) do
        local cal = spec.caliber
        if cal and AC.exists(cal) then
            local fam = P.familyName(cal)
            local f = out[fam]
            if not f then
                f = { caliber = cal, items = {}, bullets = {} }
                for _, v in ipairs(AC.variantsFor(cal)) do
                    f.bullets[#f.bullets + 1] = { type = v.item, variant = v.key }
                end
                for _, ft in ipairs(P.LIBRARY[cal] or {}) do
                    f.bullets[#f.bullets + 1] = { type = ft, variant = P.LIBRARY_VARIANT[ft], library = true }
                end
                out[fam] = f
            end
            f.items[#f.items + 1] = spec.fullType
            for _, m in ipairs(M.list(spec)) do f.items[#f.items + 1] = m.item end
        end
    end
    for _, f in pairs(out) do
        local seen, list = {}, {}
        for _, ft in ipairs(f.items) do if not seen[ft] then seen[ft] = true; list[#list + 1] = ft end end
        f.items = list
    end
    return out
end

--- Magazine profile per magazine-fed gun, tiers in order (Gunworks reloads in that order).
function P.magazineProfiles()
    local out = {}
    for _, spec in ipairs(WF.all()) do
        local mags = M.list(spec)
        if #mags > 0 then
            local sorted = {}
            for _, m in ipairs(mags) do sorted[#sorted + 1] = m end
            table.sort(sorted, function(a, b)
                local ta, tb = MF.tierOrder(a.tier), MF.tierOrder(b.tier)
                if ta ~= tb then return ta < tb end
                return a.item < b.item
            end)
            local list = {}
            for _, m in ipairs(sorted) do list[#list + 1] = m.item end
            out[P.profileName(spec)] = { weapon = spec.fullType, magazines = list }
        end
    end
    return out
end

--- Gunworks rate control for guns that fire auto or burst; semi and manual guns keep vanilla.
function P.rateOfFire()
    local out = {}
    for _, spec in ipairs(WF.all()) do
        local auto, burst = hasMode(spec, "auto"), hasMode(spec, "burst")
        if auto or burst then
            local e = { rpm = spec.rpm or P.RPM[spec.archetype] or P.RPM.default }
            if burst then e.burstCount = spec.burstCount or 3 end
            out[spec.fullType] = e
        end
    end
    return out
end

--- The ammo variant a loaded round stands for (ours, or a library round we know).
function P.variantItem(spec, roundFullType)
    if not roundFullType then return nil end
    local v = AC.variantOfItem(roundFullType)
    if v then return roundFullType end
    local key = P.LIBRARY_VARIANT[roundFullType]
    if key and spec.caliber then
        for _, cv in ipairs(AC.variantsFor(spec.caliber) or {}) do
            if cv.key == key then return cv.item end
        end
    end
    return nil
end

--[[ Our stat layer for one weapon, as Gunworks modifiers. Gunworks restores every
     stat to the script's base first, so each entry ADJUSTS by (our from-scratch
     result - the spec base): it composes with Gunworks' own layers (bipod, folding
     stock) in any order. While Gunworks runs the gun in RealAuto / RealBurst it owns
     RecoilDelay, so we leave it alone then.
       state = { attachments, magazine, round, fireMode, extra }
     returns list of { op = "Adjust", stat = <Gunworks name>, value = n } ]]
function P.layer(spec, state)
    state = state or {}
    local base = spec.stats or {}
    local target = S.compute(spec, state.attachments or {}, state.magazine,
                             P.variantItem(spec, state.round), state.extra)
    local out = {}
    local keys = {}
    for k in pairs(P.STATS) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local skip = (k == "recoilDelay" and P.GUNWORKS_AUTO[state.fireMode or ""])
        local b, t = base[k], target[k]
        if not skip and b ~= nil and t ~= nil then
            if P.INT[k] then b, t = math.floor(b + 0.5), math.floor(t + 0.5) end
            local d = t - b
            if math.abs(d) > 1e-6 then out[#out + 1] = { op = "Adjust", stat = P.STATS[k], value = d } end
        end
    end
    return out, target
end

--- Every stat our layer may touch (Gunworks restores these to base before each pass).
function P.restoreStats()
    local out = {}
    for _, name in pairs(P.STATS) do out[name] = true end
    return out
end

return P
