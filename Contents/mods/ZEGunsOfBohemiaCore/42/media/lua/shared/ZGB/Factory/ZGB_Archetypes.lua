--[[
    ZGB_Archetypes.lua  —  the "product families" of the factory.

    A weapon definition only has to say what's DIFFERENT from its archetype.
    Animations are NOT here: they belong to the view provider (iso / fp), which
    maps archetype -> animation set. That keeps one gun = one animation owner.

    stats units follow the vanilla script fields they end up in:
      aimTime -> AimingTime, recoilDelay -> RecoilDelay, range -> MaxRange, ...

    `refCaliber`: the stats below are tuned for this cartridge. A gun in another
    caliber gets damage / range / recoil / noise scaled by muzzle energy
    (see ZGB_WeaponFactory.caliberScale), unless its definition sets them.

    `category`: the catalogue group the gun is listed under (docs, loot, UI).
    reloadType values are vanilla WeaponReloadType names. -- VERIFY vs your build
]]
require "ZGB/ZGB_Core"

ZGB.Archetypes = ZGB.Archetypes or {}
local A = ZGB.Archetypes

-- Catalogue groups, in display order.
ZGB.CATEGORIES = {
    { id = "handgun",       label = "Handguns" },
    { id = "revolver",      label = "Revolvers & hand cannons" },
    { id = "assault_rifle", label = "Assault rifles" },
    { id = "dmr",           label = "Designated marksman rifles" },
    { id = "sniper",        label = "Sniper rifles (bolt action)" },
    { id = "smg",           label = "Submachine guns" },
    { id = "shotgun",       label = "Shotguns" },
    { id = "lever",         label = "Lever-action rifles" },
}

-- Placeholder vanilla sounds until custom ones exist. VERIFY names on your build.
local PISTOL_SOUNDS  = { fire = "PistolShoot" }
local RIFLE_SOUNDS   = { fire = "AssaultRifleShoot" }
local SHOTGUN_SOUNDS = { fire = "ShotgunShoot" }
local HUNTING_SOUNDS = { fire = "HuntingRifleShoot" }

A.pistol = {
    animType    = "handgun",           -- see Defs/ZGB_Def_Anims.lua
    category    = "handgun",
    refCaliber  = "9x19",
    twoHanded   = false,
    reloadType  = "handgun",          -- vanilla WeaponReloadType
    attachSlot  = "Holster",          -- vanilla AttachmentType (belt/holster)
    fireModes   = { "single" },
    sounds      = PISTOL_SOUNDS,
    stats = {
        minDamage = 0.6, maxDamage = 1.0, range = 11, minRange = 0.6,
        aimTime = 20, recoilDelay = 12, hitChance = 40, critChance = 20,
        reloadTime = 25, soundRadius = 50, weight = 1.0,
    },
    recoil = { pattern = "vertical", fp = { vertical = 1.6, horizontal = 0.5, recovery = 0.9 } },
}

A.revolver = {
    animType    = "revolver",           -- see Defs/ZGB_Def_Anims.lua
    category    = "revolver",
    refCaliber  = "38spl",
    twoHanded   = false,
    reloadType  = "revolver",
    attachSlot  = "Holster",
    fireModes   = { "single" },
    sounds      = PISTOL_SOUNDS,
    stats = {
        minDamage = 0.6, maxDamage = 1.0, range = 11, minRange = 0.6,
        aimTime = 22, recoilDelay = 14, hitChance = 42, critChance = 22,
        reloadTime = 35, soundRadius = 50, weight = 1.0,
    },
    recoil = { pattern = "kick", fp = { vertical = 2.0, horizontal = 0.4, recovery = 0.85 } },
}

A.smg = {
    animType    = "smg",           -- see Defs/ZGB_Def_Anims.lua
    category    = "smg",
    refCaliber  = "9x19",
    twoHanded   = true,
    reloadType  = "handgun",
    attachSlot  = "Rifle",
    fireModes   = { "auto", "single" },
    sounds      = PISTOL_SOUNDS,
    stats = {
        minDamage = 0.6, maxDamage = 1.0, range = 13, minRange = 0.6,
        aimTime = 22, recoilDelay = 8, hitChance = 35, critChance = 15,
        reloadTime = 28, soundRadius = 60, weight = 2.5,
    },
    recoil = { pattern = "vertical", fp = { vertical = 1.0, horizontal = 0.6, recovery = 0.85 } },
}

A.assault_rifle = {
    animType    = "rifle",           -- see Defs/ZGB_Def_Anims.lua
    category    = "assault_rifle",
    refCaliber  = "556x45",
    twoHanded   = true,
    reloadType  = "handgun",          -- vanilla mag-fed rifles use "handgun" reload. VERIFY vs your build
    attachSlot  = "Rifle",
    fireModes   = { "auto", "single" },
    sounds      = RIFLE_SOUNDS,
    stats = {
        minDamage = 1.3, maxDamage = 2.0, range = 20, minRange = 0.6,
        aimTime = 30, recoilDelay = 15, hitChance = 30, critChance = 25,
        reloadTime = 30, soundRadius = 90, weight = 3.5,
    },
    recoil = { pattern = "vertical", fp = { vertical = 1.4, horizontal = 0.7, recovery = 0.8 } },
}

A.dmr = {
    animType    = "rifle",           -- see Defs/ZGB_Def_Anims.lua
    category    = "dmr",
    refCaliber  = "308win",
    twoHanded   = true,
    reloadType  = "handgun",
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    sounds      = RIFLE_SOUNDS,
    stats = {
        minDamage = 1.8, maxDamage = 3.0, range = 25, minRange = 0.6,
        aimTime = 34, recoilDelay = 24, hitChance = 30, critChance = 32,
        reloadTime = 32, soundRadius = 100, weight = 4.5,
    },
    recoil = { pattern = "kick", fp = { vertical = 2.0, horizontal = 0.6, recovery = 0.75 } },
}

A.shotgun = {
    animType    = "pump",           -- see Defs/ZGB_Def_Anims.lua
    category    = "shotgun",
    refCaliber  = "12ga",
    twoHanded   = true,
    reloadType  = "shotgun",
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    sounds      = SHOTGUN_SOUNDS,
    stats = {
        minDamage = 1.5, maxDamage = 2.5, range = 8, minRange = 0.6,
        aimTime = 25, recoilDelay = 25, hitChance = 60, critChance = 10,
        reloadTime = 35, soundRadius = 100, weight = 3.5,
    },
    ballistics = { projectileCount = 5 },
    recoil = { pattern = "kick", fp = { vertical = 3.0, horizontal = 1.0, recovery = 0.6 } },
}

A.bolt_rifle = {
    animType    = "bolt_mag",           -- see Defs/ZGB_Def_Anims.lua
    category    = "sniper",
    refCaliber  = "308win",
    twoHanded   = true,
    reloadType  = "boltaction",       -- detachable magazine; internal ones use "boltactionnomag"
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    sounds      = HUNTING_SOUNDS,
    stats = {
        minDamage = 2.0, maxDamage = 3.5, range = 28, minRange = 0.6,
        aimTime = 40, recoilDelay = 40, hitChance = 25, critChance = 40,
        reloadTime = 35, soundRadius = 110, weight = 4.0,
    },
    recoil = { pattern = "kick", fp = { vertical = 2.4, horizontal = 0.5, recovery = 0.7 } },
}

A.lever_rifle = {
    animType    = "lever",           -- see Defs/ZGB_Def_Anims.lua
    category    = "lever",
    refCaliber  = "3030",
    twoHanded   = true,
    reloadType  = "boltactionnomag",  -- loads one round at a time into the tube. VERIFY: no vanilla lever type
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    sounds      = HUNTING_SOUNDS,
    stats = {
        minDamage = 1.6, maxDamage = 2.8, range = 22, minRange = 0.6,
        aimTime = 30, recoilDelay = 22, hitChance = 30, critChance = 30,
        reloadTime = 30, soundRadius = 95, weight = 3.3,
    },
    recoil = { pattern = "kick", fp = { vertical = 2.0, horizontal = 0.4, recovery = 0.75 } },
}

return A
