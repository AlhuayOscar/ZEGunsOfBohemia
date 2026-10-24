--[[
    ZGB_AmmoCatalog.lua  —  calibers and the ammo variants each one really comes in.

    Two layers:
      VARIANTS  what a kind of round DOES (HP = more damage, subsonic = quieter, ...)
      CALIBERS  which kinds EXIST for that cartridge, in menu order (first = default)

    So "no AP for .45 ACP" or "no subsonic for .45 (it already is)" is just data.
    Per-caliber `overrides` tune a variant for that cartridge (a .22 hollow point
    exists, but adds far less than a 9mm one).

    Standard rounds for calibers vanilla already has REUSE THE VANILLA ITEM
    (`vanilla = { fmj = "Base.Bullets9mm" }`). Vanilla boxes, crafting and other
    mods' ammo keep working with our guns — the variants are the only new items.

    mods use the same keys as weapon stats:  add / mul / set
      set.projectileCount = 1   -> a slug fires one projectile
    traits are reserved flags for later systems (armor, tracer visuals).
]]
require "ZGB/ZGB_Core"

ZGB.AmmoCatalog = ZGB.AmmoCatalog or {}
local C = ZGB.AmmoCatalog

C.VARIANTS = {
    fmj      = { label = "FMJ",           rarity = 1.00, mods = {} },
    hp       = { label = "Hollow Point",  rarity = 0.35, mods = { mul = { minDamage = 1.15, maxDamage = 1.15 }, add = { critChance = 5 } } },
    plusp    = { label = "+P",            rarity = 0.20, mods = { mul = { minDamage = 1.10, maxDamage = 1.10 }, add = { recoilDelay = 2 } } },
    ap       = { label = "Armor Piercing",rarity = 0.15, mods = { mul = { maxDamage = 0.95 }, add = { critChance = 10 } }, traits = { armorPiercing = true } },
    tracer   = { label = "Tracer",        rarity = 0.20, mods = { add = { hitChance = 5 } }, traits = { tracer = true } },
    sp       = { label = "Soft Point",    rarity = 0.30, mods = { mul = { minDamage = 1.12, maxDamage = 1.12 }, add = { critChance = 3 } } },
    subsonic = { label = "Subsonic",      rarity = 0.20, mods = { mul = { soundRadius = 0.60, range = 0.85, maxDamage = 0.90 } } },
    hv       = { label = "High Velocity", rarity = 0.40, mods = { mul = { range = 1.10 }, add = { hitChance = 2 } } },
    -- shotgun
    buck     = { label = "00 Buckshot",   rarity = 1.00, mods = {} },
    bird     = { label = "Birdshot",      rarity = 0.60, mods = { mul = { minDamage = 0.55, maxDamage = 0.55, range = 0.8 }, add = { hitChance = 10 } } },
    slug     = { label = "Slug",          rarity = 0.30, mods = { mul = { range = 1.6 }, add = { hitChance = -15, critChance = 15 }, set = { projectileCount = 1 } } },
}

-- Order matters: first variant is the default (what spawns most / script default).
-- VERIFY the vanilla item ids against your build's media/scripts.
C.CALIBERS = {
    ["22lr"]   = { label = ".22 LR",     variants = { "fmj", "hv", "hp", "subsonic" },
                   overrides = { fmj = { label = "Round Nose" },
                                 hp  = { mods = { mul = { minDamage = 1.05, maxDamage = 1.05 }, add = { critChance = 2 } } } } },
    ["9x19"]   = { label = "9x19mm",     variants = { "fmj", "hp", "plusp", "subsonic", "ap" },
                   vanilla = { fmj = "Base.Bullets9mm" } },
    ["38spl"]  = { label = ".38 Special",variants = { "fmj", "hp", "plusp" },
                   vanilla = { fmj = "Base.Bullets38" } },
    ["45acp"]  = { label = ".45 ACP",    variants = { "fmj", "hp", "plusp" },          -- already subsonic: no subsonic load
                   vanilla = { fmj = "Base.Bullets45" } },
    ["44mag"]  = { label = ".44 Magnum", variants = { "fmj", "hp", "sp" },
                   vanilla = { fmj = "Base.Bullets44" } },
    ["556x45"] = { label = "5.56x45mm",  variants = { "fmj", "ap", "tracer", "sp" },
                   vanilla = { fmj = "Base.556Bullets" } },
    ["223rem"] = { label = ".223 Rem",   variants = { "fmj", "hp", "sp" },
                   vanilla = { fmj = "Base.223Bullets" } },
    ["762x39"] = { label = "7.62x39mm",  variants = { "fmj", "ap", "tracer", "hp", "sp" } },
    ["308win"] = { label = ".308 Win",   variants = { "fmj", "ap", "tracer", "sp" },
                   vanilla = { fmj = "Base.308Bullets" } },
    ["12ga"]   = { label = "12 Gauge",   variants = { "buck", "bird", "slug" },
                   vanilla = { buck = "Base.ShotgunShells" } },
}

--- Item full type for a caliber's variant: vanilla item if mapped, else ours.
function C.itemFor(caliberId, variantKey)
    local cal = C.CALIBERS[caliberId]
    if cal and cal.vanilla and cal.vanilla[variantKey] then return cal.vanilla[variantKey] end
    return ZGB.MODULE .. ".Ammo_" .. caliberId .. "_" .. string.upper(variantKey)
end

--- Resolved variant list for a caliber:
--- { {key, item, label, rarity, mods={add,mul,set}, traits, isVanilla, default}, ... }
function C.variantsFor(caliberId)
    local cal = C.CALIBERS[caliberId]
    if not cal then return nil end
    local out = {}
    for i, key in ipairs(cal.variants) do
        local base = C.VARIANTS[key]
        if not base then
            ZGB.err("Caliber", caliberId, "lists unknown variant", key)
        else
            local v = ZGB.merge(base, (cal.overrides or {})[key] or {})
            v.mods = v.mods or {}
            v.mods.add, v.mods.mul, v.mods.set = v.mods.add or {}, v.mods.mul or {}, v.mods.set or {}
            v.key, v.caliber, v.default = key, caliberId, (i == 1)
            v.item = C.itemFor(caliberId, key)
            v.isVanilla = (cal.vanilla and cal.vanilla[key]) ~= nil
            out[#out + 1] = v
        end
    end
    return out
end

function C.exists(caliberId) return C.CALIBERS[caliberId] ~= nil end

--- Reverse lookup: ammo item full type -> resolved variant (built lazily).
local byItem
function C.variantOfItem(itemFullType)
    if not byItem then
        byItem = {}
        for calId in pairs(C.CALIBERS) do
            for _, v in ipairs(C.variantsFor(calId)) do byItem[v.item] = v end
        end
    end
    return byItem[itemFullType]
end

--- Call after adding calibers at runtime (addons / tests).
function C.invalidate() byItem = nil end

--- Addon API: register a caliber from another mod.
function C.addCaliber(id, def)
    C.CALIBERS[id] = def
    C.invalidate()
end

return C
