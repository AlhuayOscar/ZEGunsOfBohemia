--[[
    ZGB_Def_Parts.lua  —  attachment catalogue.

    Interfaces used here (the "physical standards"):
      ak_dovetail       AK side-rail dovetail
      ak_muzzle_14l     AK 14x1 LH thread
      ak_handguard      AK handguard retainer
      ak_stock          AK stock trunnion
      picatinny         top optic rail
      picatinny_under   bottom/side accessory rail
      sling_loop        sling swivel / loop
]]
require "ZGB/Factory/ZGB_PartFactory"
local P = ZGB.PartFactory

-- ---------------------------------------------------------------- mounts / furniture
P.define{
    id = "Mount_AK_SideRail", displayName = "AK Side Rail Optic Mount",
    kind = "mount", interface = "ak_dovetail", attachTime = 150,
    provides = { optic_rail = { kind = "optic", accepts = { "picatinny" }, label = "Optic rail", order = 1 } },
    mods = { add = { weight = 0.25 } },
}

P.define{
    id = "Handguard_AK_Quad", displayName = "AK Quad-Rail Handguard",
    kind = "handguard", interface = "ak_handguard", attachTime = 200,
    provides = { under_rail = { kind = "underbarrel", accepts = { "picatinny_under" }, label = "Under rail", order = 2 } },
    mods = { add = { weight = 0.3 } },
}

-- ---------------------------------------------------------------- optics
P.define{
    id = "Optic_RedDot", displayName = "Red Dot Sight",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { aimTime = -4, weight = 0.15 }, mul = { hitChance = 1.10 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.045, 0 }, zoom = 1.0 } },
}

P.define{
    id = "Optic_4x", displayName = "4x Combat Scope",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { range = 6, aimTime = 6, weight = 0.4 }, mul = { hitChance = 1.18 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.05, -0.02 }, zoom = 4.0 } },
}

-- ---------------------------------------------------------------- muzzle
P.define{
    id = "Muzzle_AK_Suppressor", displayName = "AK Suppressor",
    kind = "muzzle", interface = "ak_muzzle_14l", vanillaPartType = "Canon",
    mods = { add = { weight = 0.5 }, mul = { soundRadius = 0.45, range = 0.95 } },
}

P.define{
    id = "Muzzle_AK_Compensator", displayName = "AK Compensator",
    kind = "muzzle", interface = "ak_muzzle_14l", vanillaPartType = "Canon",
    mods = { add = { recoilDelay = -3, weight = 0.1 }, mul = { soundRadius = 1.1 } },
}

-- ---------------------------------------------------------------- underbarrel
P.define{
    id = "Grip_Vertical", displayName = "Vertical Foregrip",
    kind = "underbarrel", interface = "picatinny_under", vanillaPartType = "RecoilPad",
    mods = { add = { recoilDelay = -4, weight = 0.1 } },
}

P.define{
    id = "Light_Weapon", displayName = "Weapon Light",
    kind = "underbarrel", interface = "picatinny_under",
    mods = { add = { weight = 0.15 } },
    -- light behaviour itself is a TODO (v0.2)
}

-- ---------------------------------------------------------------- stock / sling
P.define{
    id = "Stock_AK_Folding", displayName = "AK Folding Stock",
    kind = "stock", interface = "ak_stock", vanillaPartType = "Stock",
    mods = { add = { aimTime = -2, weight = -0.2 }, mul = { hitChance = 0.97 } },
}

P.define{
    id = "Sling_2Point", displayName = "2-Point Sling",
    kind = "sling", interface = "sling_loop", vanillaPartType = "Sling",
    mods = { add = { aimTime = -1, weight = 0.1 } },
}
