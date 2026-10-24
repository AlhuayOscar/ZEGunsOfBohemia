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

    `energy` is typical muzzle energy in joules for the standard load. The
    weapon factory scales an archetype's damage / range / recoil / noise by it
    relative to the archetype's reference caliber, so a .22 pistol and a
    .50 AE pistol come out different without hand-tuning every gun.

    Which loads exist follows the real cartridge: tube-fed lever calibers
    (.30-30, .45-70) have no pointed match load, .22 LR has no long-range load,
    .45 ACP has no subsonic (it already is), and so on.
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
    match    = { label = "Match (Long Range)", rarity = 0.20, mods = { mul = { range = 1.15 }, add = { hitChance = 6, critChance = 5 } } },
    wc       = { label = "Wadcutter",     rarity = 0.30, mods = { mul = { maxDamage = 0.90 }, add = { recoilDelay = -2, hitChance = 3 } } },
    -- shotgun
    buck     = { label = "00 Buckshot",   rarity = 1.00, mods = {} },
    bird     = { label = "Birdshot",      rarity = 0.60, mods = { mul = { minDamage = 0.55, maxDamage = 0.55, range = 0.8 }, add = { hitChance = 10 } } },
    slug     = { label = "Slug",          rarity = 0.30, mods = { mul = { range = 1.6 }, add = { hitChance = -15, critChance = 15 }, set = { projectileCount = 1 } } },
    flechette= { label = "Flechette",     rarity = 0.08, mods = { mul = { range = 1.3, minDamage = 0.85, maxDamage = 0.85 }, add = { hitChance = 5 } }, traits = { armorPiercing = true } },
}

-- Order matters: first variant is the default (what spawns most / script default).
-- `group` only sorts the catalogue for people (docs, UI).
-- VERIFY the vanilla item ids against your build's media/scripts.
C.CALIBERS = {
    -- ------------------------------------------------ pistol / SMG
    ["22lr"]   = { label = ".22 LR",     group = "pistol", energy = 160,
                   variants = { "fmj", "hv", "hp", "subsonic" },
                   overrides = { fmj = { label = "Round Nose" },
                                 hp  = { mods = { mul = { minDamage = 1.05, maxDamage = 1.05 }, add = { critChance = 2 } } } } },
    ["380acp"] = { label = ".380 ACP",   group = "pistol", energy = 270, variants = { "fmj", "hp" } },
    ["9x18"]   = { label = "9x18mm Makarov", group = "pistol", energy = 300, variants = { "fmj", "hp", "ap" } },
    ["762x25"] = { label = "7.62x25mm Tokarev", group = "pistol", energy = 680, variants = { "fmj", "ap" } },
    ["9x19"]   = { label = "9x19mm",     group = "pistol", energy = 500,
                   variants = { "fmj", "hp", "plusp", "subsonic", "ap" },
                   vanilla = { fmj = "Base.Bullets9mm" } },
    ["40sw"]   = { label = ".40 S&W",    group = "pistol", energy = 600, variants = { "fmj", "hp" } },
    ["45acp"]  = { label = ".45 ACP",    group = "pistol", energy = 550,
                   variants = { "fmj", "hp", "plusp" },          -- already subsonic: no subsonic load
                   vanilla = { fmj = "Base.Bullets45" } },
    ["57x28"]  = { label = "5.7x28mm",   group = "pistol", energy = 400,
                   variants = { "fmj", "ap", "tracer", "subsonic" },   -- SS197 / SS190 / L191 / SB193
                   overrides = { fmj = { label = "Sporting (SS197)" } } },
    ["50ae"]   = { label = ".50 AE",     group = "pistol", energy = 1900, variants = { "fmj", "hp" } },
    -- ------------------------------------------------ revolver
    ["762x38r"]= { label = "7.62x38mmR Nagant", group = "revolver", energy = 400, variants = { "fmj" } },
    ["38spl"]  = { label = ".38 Special",group = "revolver", energy = 300,
                   variants = { "fmj", "hp", "plusp", "wc" },
                   vanilla = { fmj = "Base.Bullets38" } },
    ["357mag"] = { label = ".357 Magnum",group = "revolver", energy = 800, variants = { "sp", "hp", "fmj" },
                   overrides = { sp = { label = "Jacketed Soft Point" } } },
    ["45colt"] = { label = ".45 Colt",   group = "revolver", energy = 600, variants = { "fmj", "hp" },
                   overrides = { fmj = { label = "Lead Round Nose" } } },
    ["44mag"]  = { label = ".44 Magnum", group = "revolver", energy = 1400,
                   variants = { "fmj", "hp", "sp" },
                   vanilla = { fmj = "Base.Bullets44" } },
    ["454casull"]={ label = ".454 Casull",group = "revolver", energy = 2400, variants = { "sp", "hp" } },
    ["500sw"]  = { label = ".500 S&W Magnum", group = "revolver", energy = 3500, variants = { "sp", "hp" } },
    -- ------------------------------------------------ intermediate rifle
    ["556x45"] = { label = "5.56x45mm",  group = "rifle", energy = 1750,
                   variants = { "fmj", "ap", "tracer", "sp", "match" },     -- match = Mk 262
                   vanilla = { fmj = "Base.556Bullets" } },
    ["223rem"] = { label = ".223 Rem",   group = "rifle", energy = 1700,
                   variants = { "fmj", "hp", "sp" },
                   vanilla = { fmj = "Base.223Bullets" } },
    ["545x39"] = { label = "5.45x39mm",  group = "rifle", energy = 1400, variants = { "fmj", "ap", "tracer", "hp" } },
    ["762x39"] = { label = "7.62x39mm",  group = "rifle", energy = 2100, variants = { "fmj", "ap", "tracer", "hp", "sp" } },
    -- ------------------------------------------------ full-power rifle
    ["308win"] = { label = ".308 Win / 7.62x51mm", group = "full_rifle", energy = 3500,
                   variants = { "fmj", "ap", "tracer", "sp", "match" },
                   vanilla = { fmj = "Base.308Bullets" } },
    ["762x54r"]= { label = "7.62x54mmR", group = "full_rifle", energy = 3600, variants = { "fmj", "ap", "tracer", "sp", "match" },
                   overrides = { match = { label = "7N1 Sniper (Long Range)" } } },
    ["65cm"]   = { label = "6.5 Creedmoor", group = "full_rifle", energy = 3200, variants = { "match", "sp", "hp" } },
    ["3006"]   = { label = ".30-06 Springfield", group = "full_rifle", energy = 3900, variants = { "fmj", "sp", "ap", "tracer" } },
    ["303brit"]= { label = ".303 British", group = "full_rifle", energy = 3300, variants = { "fmj", "sp", "tracer", "ap" } },
    ["792x57"] = { label = "7.92x57mm Mauser", group = "full_rifle", energy = 4000, variants = { "fmj", "ap", "tracer", "sp" } },
    ["3030"]   = { label = ".30-30 Win", group = "full_rifle", energy = 2600, variants = { "sp", "hp" } },     -- tube-fed: flat noses only
    ["4570"]   = { label = ".45-70 Govt", group = "full_rifle", energy = 4000, variants = { "sp", "hp" } },
    -- ------------------------------------------------ magnum / anti-materiel
    ["338lm"]  = { label = ".338 Lapua Magnum", group = "magnum_rifle", energy = 6800, variants = { "match", "ap", "sp" } },
    ["50bmg"]  = { label = ".50 BMG",    group = "magnum_rifle", energy = 18000, variants = { "fmj", "ap", "tracer", "match" } },
    -- ------------------------------------------------ shotgun
    ["12ga"]   = { label = "12 Gauge",   group = "shotgun", energy = 2800,
                   variants = { "buck", "bird", "slug", "flechette" },
                   vanilla = { buck = "Base.ShotgunShells" } },
    ["410ga"]  = { label = ".410 Bore",  group = "shotgun", energy = 1100, variants = { "buck", "bird", "slug" } },
}

-- Spent casing item left by each caliber group (iso case dropping). Generated by
-- tools/gen_scripts.lua; a caliber may override with `casing = "ZGB.Casing_..."`.
C.CASINGS = {
    pistol       = { id = "Casing_Pistol",     displayName = "Spent Pistol Casing" },
    revolver     = { id = "Casing_Pistol",     displayName = "Spent Pistol Casing" },
    rifle        = { id = "Casing_Rifle",      displayName = "Spent Rifle Casing" },
    full_rifle   = { id = "Casing_RifleLarge", displayName = "Spent Large Rifle Casing" },
    magnum_rifle = { id = "Casing_RifleLarge", displayName = "Spent Large Rifle Casing" },
    shotgun      = { id = "Casing_ShotgunHull",displayName = "Spent Shotgun Hull" },
}

function C.casingFor(caliberId)
    local cal = C.CALIBERS[caliberId]
    if not cal then return nil end
    if cal.casing then return cal.casing end
    local c = C.CASINGS[cal.group]
    return c and (ZGB.MODULE .. "." .. c.id) or nil
end

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
