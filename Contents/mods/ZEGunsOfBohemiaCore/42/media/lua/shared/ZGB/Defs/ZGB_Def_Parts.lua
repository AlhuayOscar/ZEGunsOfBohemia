--[[
    ZGB_Def_Parts.lua  —  attachment catalogue.

    Interfaces are the physical standards. A slot accepts interfaces; a part
    has exactly one. A part that `provides` slots is how chains happen
    (AK side mount -> picatinny optic rail -> red dot).

      optics       picatinny        top optic rail (flat-tops, mounts, handguards)
                   rmr              pistol slide optic cut (RMR footprint)
                   dovetail_22      3/8" rimfire receiver groove
                   svd_side_rail    SVD / Dragunov side rail (PSO-1 only)
                   mosin_pu         Mosin PU scope mount
      mount bases  ak_dovetail      AK side-rail dovetail
                   ar_carry_handle  M16A2 carry handle
                   drilled_tapped   receiver drilled & tapped for a scope base
                   hk_claw          HK claw-mount dimples (MP5)
                   m14_receiver     M14 receiver side mount
                   mosin_receiver   Mosin-Nagant receiver (PU side mount)
                   ruger_integral   Ruger integral ring cuts (Super Redhawk)
      handguards   ak_handguard / ar_handguard / hk_handguard
      underbarrel  picatinny_under  bottom accessory rail
                   usp_rail         HK USP proprietary rail (needs an adapter)
                   sling_stud       front sling stud (bipods)
      muzzle       muzzle_pistol_9mm / muzzle_pistol_45 / muzzle_rimfire
                   muzzle_rifle_556 (1/2-28)  muzzle_rifle_308 (5/8-24)  muzzle_338
                   ak_muzzle_14l (AK-47 14x1 LH)  ak74_24x15 (AK-74 24x1.5)
                   hk_3lug          HK 3-lug barrel (MP5, needs an adapter for cans)
                   choke_12ga       screw-in shotgun choke tubes
      stock        ak_stock / ar_buffer_tube / m590_stock / r870_stock
      other        shotgun_receiver (side saddle), sling_loop

    `noModel = true`: the part has no visible 3D model (internal, e.g. chokes).
]]
require "ZGB/Factory/ZGB_PartFactory"
local P = ZGB.PartFactory

local OPTIC_RAIL = { optic_rail = { kind = "optic", accepts = { "picatinny" }, label = "Optic rail", order = 1 } }
local UNDER_RAIL = { under_rail = { kind = "underbarrel", accepts = { "picatinny_under" }, label = "Under rail", order = 2 } }

-- ---------------------------------------------------------------- mounts
P.define{
    id = "Mount_AK_SideRail", displayName = "AK Side Rail Optic Mount",
    kind = "mount", interface = "ak_dovetail", attachTime = 150,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.25 } },
}
P.define{
    id = "Mount_AR_CarryHandle", displayName = "Carry Handle Rail Mount",
    kind = "mount", interface = "ar_carry_handle", attachTime = 120,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.15 } },
}
P.define{
    id = "Mount_ScopeBase", displayName = "Picatinny Scope Base",
    kind = "mount", interface = "drilled_tapped", attachTime = 200,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.1 } },
}
P.define{
    id = "Mount_HK_Claw", displayName = "HK Claw Rail Mount",
    kind = "mount", interface = "hk_claw", attachTime = 120,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.2 } },
}
P.define{
    id = "Mount_M14", displayName = "M14 Scope Mount",
    kind = "mount", interface = "m14_receiver", attachTime = 180,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.3 } },
}
P.define{
    id = "Mount_Mosin_PU", displayName = "Mosin PU Side Mount",
    kind = "mount", interface = "mosin_receiver", attachTime = 220,
    provides = { optic_mount = { kind = "optic", accepts = { "mosin_pu" }, label = "PU scope mount", order = 1 } },
    mods = { add = { weight = 0.15 } },
}
P.define{
    id = "Mount_Ruger_Rings", displayName = "Ruger Ring Mount Rail",
    kind = "mount", interface = "ruger_integral", attachTime = 150,
    provides = OPTIC_RAIL, mods = { add = { weight = 0.12 } },
}

-- ---------------------------------------------------------------- handguards / adapters
P.define{
    id = "Handguard_AK_Quad", displayName = "AK Quad-Rail Handguard",
    kind = "handguard", interface = "ak_handguard", attachTime = 200,
    provides = UNDER_RAIL, mods = { add = { weight = 0.3 } },
}
P.define{
    id = "Handguard_AR_Quad", displayName = "AR Quad-Rail Handguard",
    kind = "handguard", interface = "ar_handguard", attachTime = 220,
    provides = UNDER_RAIL, mods = { add = { weight = 0.35 } },
}
P.define{
    id = "Handguard_MP5_Rail", displayName = "MP5 Railed Handguard",
    kind = "handguard", interface = "hk_handguard", attachTime = 160,
    provides = UNDER_RAIL, mods = { add = { weight = 0.2 } },
}
P.define{
    id = "Adapter_USP_Rail", displayName = "USP Rail Adapter",
    kind = "adapter", interface = "usp_rail", attachTime = 60,
    provides = UNDER_RAIL, mods = { add = { weight = 0.03 } },
}
P.define{
    id = "Adapter_HK_3Lug", displayName = "HK 3-Lug Thread Adapter",
    kind = "adapter", interface = "hk_3lug", attachTime = 60,
    provides = { muzzle_thread = { kind = "muzzle", accepts = { "muzzle_pistol_9mm" }, label = "Muzzle thread", order = 3 } },
    mods = { add = { weight = 0.05 } },
}

-- ---------------------------------------------------------------- optics
P.define{
    id = "Optic_RedDot", displayName = "Red Dot Sight",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { aimTime = -4, weight = 0.15 }, mul = { hitChance = 1.10 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.045, 0 }, zoom = 1.0 } },
}
P.define{
    id = "Optic_Holo", displayName = "Holographic Sight",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { aimTime = -5, weight = 0.3 }, mul = { hitChance = 1.12 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.05, 0 }, zoom = 1.0 } },
}
P.define{
    id = "Optic_4x", displayName = "4x Combat Scope",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { range = 6, aimTime = 6, weight = 0.4 }, mul = { hitChance = 1.18 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.05, -0.02 }, zoom = 4.0 } },
}
P.define{
    id = "Optic_Hunting3x9", displayName = "3-9x Hunting Scope",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { range = 8, aimTime = 8, weight = 0.45 }, mul = { hitChance = 1.20 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.055, -0.03 }, zoom = 6.0 } },
}
P.define{
    id = "Optic_Scope8x", displayName = "8x Precision Scope",
    kind = "optic", interface = "picatinny", vanillaPartType = "Scope",
    mods = { add = { range = 12, aimTime = 12, weight = 0.7 }, mul = { hitChance = 1.25 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.06, -0.04 }, zoom = 8.0 } },
}
P.define{
    id = "Optic_Pistol_RMR", displayName = "Pistol Red Dot (RMR)",
    kind = "optic", interface = "rmr", vanillaPartType = "Scope",
    mods = { add = { aimTime = -3, weight = 0.05 }, mul = { hitChance = 1.08 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.03, 0 }, zoom = 1.0 } },
}
P.define{
    id = "Optic_PSO1", displayName = "PSO-1 4x Scope",
    kind = "optic", interface = "svd_side_rail", vanillaPartType = "Scope",
    mods = { add = { range = 8, aimTime = 8, weight = 0.6 }, mul = { hitChance = 1.20 } },
    fp = { sightAlignment = { eyeOffset = { -0.02, 0.05, -0.03 }, zoom = 4.0 } },
}
P.define{
    id = "Optic_PU", displayName = "PU 3.5x Scope",
    kind = "optic", interface = "mosin_pu", vanillaPartType = "Scope",
    mods = { add = { range = 7, aimTime = 7, weight = 0.27 }, mul = { hitChance = 1.17 } },
    fp = { sightAlignment = { eyeOffset = { -0.015, 0.045, -0.02 }, zoom = 3.5 } },
}
P.define{
    id = "Optic_Rimfire4x", displayName = "4x Rimfire Scope",
    kind = "optic", interface = "dovetail_22", vanillaPartType = "Scope",
    mods = { add = { range = 5, aimTime = 5, weight = 0.3 }, mul = { hitChance = 1.15 } },
    fp = { sightAlignment = { eyeOffset = { 0, 0.045, -0.02 }, zoom = 4.0 } },
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
    -- light behaviour itself is a TODO
}
P.define{
    id = "Light_Pistol", displayName = "Pistol Light",
    kind = "underbarrel", interface = "picatinny_under",
    mods = { add = { weight = 0.1 } },
}
P.define{
    id = "Bipod_Harris", displayName = "Harris Bipod",
    kind = "bipod", interface = "sling_stud", vanillaPartType = "RecoilPad",
    mods = { add = { recoilDelay = -8, aimTime = 4, weight = 0.4 }, mul = { hitChance = 1.08 } },
}

-- ---------------------------------------------------------------- muzzle
local function muzzle(id, name, interface, mods) P.define{
    id = id, displayName = name, kind = "muzzle", interface = interface, vanillaPartType = "Canon", mods = mods } end
local CAN_PISTOL = { add = { weight = 0.25 }, mul = { soundRadius = 0.40, range = 0.97 } }
local CAN_RIFLE  = { add = { weight = 0.5 },  mul = { soundRadius = 0.45, range = 0.95 } }
local BRAKE      = { add = { recoilDelay = -3, weight = 0.1 }, mul = { soundRadius = 1.1 } }

muzzle("Suppressor_Pistol9",    "9mm Pistol Suppressor",   "muzzle_pistol_9mm", CAN_PISTOL)
muzzle("Suppressor_Pistol45",   ".45 Pistol Suppressor",   "muzzle_pistol_45",  CAN_PISTOL)
muzzle("Suppressor_Rimfire",    ".22 Rimfire Suppressor",  "muzzle_rimfire",
       { add = { weight = 0.15 }, mul = { soundRadius = 0.30 } })
muzzle("Suppressor_Rifle556",   "5.56 Rifle Suppressor",   "muzzle_rifle_556",  CAN_RIFLE)
muzzle("Brake_Rifle556",        "5.56 Muzzle Brake",       "muzzle_rifle_556",  BRAKE)
muzzle("Suppressor_Rifle308",   ".308 Rifle Suppressor",   "muzzle_rifle_308",
       { add = { weight = 0.6 }, mul = { soundRadius = 0.50, range = 0.95 } })
muzzle("Brake_Rifle308",        ".308 Muzzle Brake",       "muzzle_rifle_308",  { add = { recoilDelay = -5, weight = 0.15 }, mul = { soundRadius = 1.15 } })
muzzle("Muzzle_AK_Suppressor",  "AK Suppressor",           "ak_muzzle_14l",     CAN_RIFLE)
muzzle("Muzzle_AK_Compensator", "AK Compensator",          "ak_muzzle_14l",     BRAKE)
muzzle("Suppressor_AK74",       "AK-74 Suppressor",        "ak74_24x15",        CAN_RIFLE)
muzzle("Brake_AK74",            "AK-74 Muzzle Brake",      "ak74_24x15",        BRAKE)
muzzle("Suppressor_338",        ".338 Magnum Suppressor",  "muzzle_338",
       { add = { weight = 0.7 }, mul = { soundRadius = 0.55, range = 0.96 } })

local function choke(id, name, mods) P.define{
    id = id, displayName = name, kind = "muzzle", interface = "choke_12ga", noModel = true, attachTime = 60, mods = mods } end
choke("Choke_Full",               "Full Choke",               { mul = { range = 1.20, hitChance = 0.92 } })
choke("Choke_Modified",           "Modified Choke",           { mul = { range = 1.10, hitChance = 0.97 } })
choke("Choke_ImprovedCylinder",   "Improved Cylinder Choke",  { mul = { range = 0.95, hitChance = 1.06 } })

-- ---------------------------------------------------------------- stocks
P.define{
    id = "Stock_AK_Folding", displayName = "AK Folding Stock",
    kind = "stock", interface = "ak_stock", vanillaPartType = "Stock",
    mods = { add = { aimTime = -2, weight = -0.2 }, mul = { hitChance = 0.97 } },
}
P.define{
    id = "Stock_AR_Collapsible", displayName = "AR Collapsible Stock",
    kind = "stock", interface = "ar_buffer_tube", vanillaPartType = "Stock",
    mods = { add = { aimTime = -2, weight = -0.1 } },
}
P.define{
    id = "Stock_AR_Precision", displayName = "AR Precision Stock",
    kind = "stock", interface = "ar_buffer_tube", vanillaPartType = "Stock",
    mods = { add = { aimTime = 2, recoilDelay = -3, weight = 0.3 }, mul = { hitChance = 1.05 } },
}
P.define{
    id = "Stock_M590_PistolGrip", displayName = "Mossberg Pistol-Grip Stock",
    kind = "stock", interface = "m590_stock", vanillaPartType = "Stock",
    mods = { add = { aimTime = -2, recoilDelay = -2 } },
}
P.define{
    id = "Stock_870_Folding", displayName = "Remington 870 Folding Stock",
    kind = "stock", interface = "r870_stock", vanillaPartType = "Stock",
    mods = { add = { aimTime = -3, weight = -0.3 }, mul = { hitChance = 0.96 } },
}

-- ---------------------------------------------------------------- other
P.define{
    id = "Sidesaddle_Shotgun", displayName = "Shotgun Side Saddle",
    kind = "sidesaddle", interface = "shotgun_receiver", attachTime = 120,
    mods = { add = { reloadTime = -6, weight = 0.2 } },
}
P.define{
    id = "Sling_2Point", displayName = "2-Point Sling",
    kind = "sling", interface = "sling_loop", vanillaPartType = "Sling",
    mods = { add = { aimTime = -1, weight = 0.1 } },
}
P.define{
    id = "Sling_1Point", displayName = "1-Point Sling",
    kind = "sling", interface = "sling_loop", vanillaPartType = "Sling",
    mods = { add = { aimTime = -2, weight = 0.08 }, mul = { hitChance = 0.99 } },
}

-- ---------------------------------------------------------------- v0.6: more muzzle devices, grips, lasers,
-- ---------------------------------------------------------------- recoil pads and shell holders
muzzle("FlashHider_556",        "5.56 Flash Hider",        "muzzle_rifle_556",  { add = { weight = 0.06 }, mul = { soundRadius = 0.95 } })
muzzle("FlashHider_308",        ".308 Flash Hider",        "muzzle_rifle_308",  { add = { weight = 0.08 }, mul = { soundRadius = 0.95 } })
muzzle("Muzzle_AK_FlashHider",  "AK Flash Hider",          "ak_muzzle_14l",     { add = { weight = 0.06 }, mul = { soundRadius = 0.95 } })
muzzle("Comp_Pistol9",          "9mm Pistol Compensator",  "muzzle_pistol_9mm", { add = { recoilDelay = -2, weight = 0.05 }, mul = { soundRadius = 1.05 } })

P.define{
    id = "Grip_Angled", displayName = "Angled Foregrip",
    kind = "underbarrel", interface = "picatinny_under", vanillaPartType = "RecoilPad",
    mods = { add = { recoilDelay = -2, aimTime = -2, weight = 0.08 } },
}
P.define{
    id = "Grip_Stubby", displayName = "Stubby Grip",
    kind = "underbarrel", interface = "picatinny_under", vanillaPartType = "RecoilPad",
    mods = { add = { recoilDelay = -3, aimTime = -1, weight = 0.06 } },
}
P.define{
    id = "Laser_Rifle", displayName = "Rifle Laser Module",
    kind = "underbarrel", interface = "picatinny_under",
    mods = { add = { aimTime = -3, weight = 0.12 }, mul = { hitChance = 1.04 } },
}
P.define{
    id = "Laser_Pistol", displayName = "Pistol Laser",
    kind = "underbarrel", interface = "picatinny_under",
    mods = { add = { aimTime = -2, weight = 0.06 }, mul = { hitChance = 1.03 } },
}
P.define{
    id = "RecoilPad_Rubber", displayName = "Rubber Recoil Pad",
    kind = "recoilpad", interface = "butt_plate", attachTime = 120,
    mods = { add = { recoilDelay = -4, weight = 0.15 } },
}
P.define{
    id = "ShellHolder_Butt", displayName = "Buttstock Shell Holder",
    kind = "shellholder", interface = "buttstock_sleeve", attachTime = 80,
    mods = { add = { reloadTime = -3, weight = 0.15 } },
}
