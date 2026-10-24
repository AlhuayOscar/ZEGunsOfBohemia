--[[
    ZGB_Archetypes.lua  —  the "product families" of the factory.

    A weapon definition only has to say what's DIFFERENT from its archetype.
    Animations are NOT here: they belong to the view provider (iso / fp), which
    maps archetype -> animation set. That keeps one gun = one animation owner.

    stats units follow the vanilla script fields they end up in:
      aimTime -> AimingTime, recoilDelay -> RecoilDelay, range -> MaxRange, ...
]]
require "ZGB/ZGB_Core"

ZGB.Archetypes = ZGB.Archetypes or {}
local A = ZGB.Archetypes

A.pistol = {
    twoHanded   = false,
    reloadType  = "handgun",          -- vanilla WeaponReloadType
    attachSlot  = "Holster",          -- vanilla AttachmentType (belt/holster)
    fireModes   = { "single" },
    stats = {
        minDamage = 0.6, maxDamage = 1.0, range = 11, minRange = 0.6,
        aimTime = 20, recoilDelay = 12, hitChance = 40, critChance = 20,
        reloadTime = 25, soundRadius = 50, weight = 1.0,
    },
    recoil = { fp = { vertical = 1.6, horizontal = 0.5, recovery = 0.9 } },
}

A.smg = {
    twoHanded   = true,
    reloadType  = "handgun",
    attachSlot  = "Rifle",
    fireModes   = { "auto", "single" },
    stats = {
        minDamage = 0.6, maxDamage = 1.0, range = 13, minRange = 0.6,
        aimTime = 22, recoilDelay = 8, hitChance = 35, critChance = 15,
        reloadTime = 28, soundRadius = 60, weight = 2.5,
    },
    recoil = { fp = { vertical = 1.0, horizontal = 0.6, recovery = 0.85 } },
}

A.assault_rifle = {
    twoHanded   = true,
    reloadType  = "handgun",          -- vanilla mag-fed rifles use "handgun" reload. VERIFY vs your build
    attachSlot  = "Rifle",
    fireModes   = { "auto", "single" },
    stats = {
        minDamage = 1.3, maxDamage = 2.0, range = 20, minRange = 0.6,
        aimTime = 30, recoilDelay = 15, hitChance = 30, critChance = 25,
        reloadTime = 30, soundRadius = 90, weight = 3.5,
    },
    recoil = { fp = { vertical = 1.4, horizontal = 0.7, recovery = 0.8 } },
}

A.shotgun = {
    twoHanded   = true,
    reloadType  = "shotgun",
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    stats = {
        minDamage = 1.5, maxDamage = 2.5, range = 8, minRange = 0.6,
        aimTime = 25, recoilDelay = 25, hitChance = 60, critChance = 10,
        reloadTime = 35, soundRadius = 100, weight = 3.5,
    },
    ballistics = { projectileCount = 5 },
    recoil = { fp = { vertical = 3.0, horizontal = 1.0, recovery = 0.6 } },
}

A.bolt_rifle = {
    twoHanded   = true,
    reloadType  = "boltaction",
    attachSlot  = "Rifle",
    fireModes   = { "single" },
    stats = {
        minDamage = 2.0, maxDamage = 3.5, range = 28, minRange = 0.6,
        aimTime = 40, recoilDelay = 40, hitChance = 25, critChance = 40,
        reloadTime = 35, soundRadius = 110, weight = 4.0,
    },
    recoil = { fp = { vertical = 2.4, horizontal = 0.5, recovery = 0.7 } },
}

return A
