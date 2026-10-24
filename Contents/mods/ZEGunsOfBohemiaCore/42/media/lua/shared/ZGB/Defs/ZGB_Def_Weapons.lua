--[[
    ZGB_Def_Weapons.lua  —  the gun catalogue.

    Adding a gun = one define{} block + a skeleton script item + a model.
    Anything not listed comes from the archetype (ZGB_Archetypes.lua).
]]
require "ZGB/Factory/ZGB_WeaponFactory"
local W = ZGB.WeaponFactory

W.define{
    id = "AK47", archetype = "assault_rifle", displayName = "AK-47",
    caliber = "762x39",
    magazine = { item = "ZGB.AK47_Mag30", capacity = 30, label = "30rd mag" },
    altMagazines = {
        -- heavier and slower to aim while loaded
        { item = "ZGB.AK47_Drum75", capacity = 75, label = "75rd drum",
          mods = { add = { weight = 1.4, aimTime = 6, reloadTime = 12 } } },
    },
    stats    = { minDamage = 1.4, maxDamage = 2.1, recoilDelay = 16, weight = 3.6 },
    sounds   = { fire = "AssaultRifleShoot" },   -- placeholder: vanilla sound names until you add yours
    slots = {
        -- no optic slot on purpose: an AK needs a side mount first
        side_mount = { kind = "mount",     accepts = { "ak_dovetail" },   label = "Side mount", order = 1 },
        muzzle     = { kind = "muzzle",    accepts = { "ak_muzzle_14l" }, label = "Muzzle",     order = 2 },
        handguard  = { kind = "handguard", accepts = { "ak_handguard" },  label = "Handguard",  order = 3 },
        stock      = { kind = "stock",     accepts = { "ak_stock" },      label = "Stock",      order = 4 },
        sling      = { kind = "sling",     accepts = { "sling_loop" },    label = "Sling",      order = 5 },
    },
    fp = {  -- reserved for the first-person addon; filled when models exist
        ironSight = { eyeOffset = { 0, 0.03, 0 } },
    },
}

W.define{
    id = "Glock17", archetype = "pistol", displayName = "Glock 17",
    caliber = "9x19",
    magazine = { item = "ZGB.Glock17_Mag17", capacity = 17, label = "17rd mag" },
    altMagazines = {
        { item = "ZGB.Glock17_Mag33", capacity = 33, label = "33rd extended",
          mods = { add = { weight = 0.15, aimTime = 2 } } },
    },
    stats    = { weight = 0.9 },
    sounds   = { fire = "PistolShoot" },
    slots = {
        -- dust-cover rail: lights/grips go straight on, no adapter needed
        under_rail = { kind = "underbarrel", accepts = { "picatinny_under" }, label = "Under rail", order = 1 },
    },
}

W.define{
    id = "M590", archetype = "shotgun", displayName = "Mossberg 590",
    caliber = "12ga",
    internalCapacity = 8,          -- tube-fed: no magazine item
    stats    = { weight = 3.4 },
    sounds   = { fire = "ShotgunShoot" },
    slots = {
        sling = { kind = "sling", accepts = { "sling_loop" }, label = "Sling", order = 1 },
    },
}
