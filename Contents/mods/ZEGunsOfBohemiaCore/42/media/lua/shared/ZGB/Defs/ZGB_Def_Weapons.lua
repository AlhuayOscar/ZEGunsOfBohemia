--[[
    ZGB_Def_Weapons.lua  —  the gun catalogue (v0.4: 70 guns).

    Adding a gun = one define{} block + a model. The item script skeleton is
    generated (tools/gen_scripts.lua). Anything not listed comes from the
    archetype (ZGB_Archetypes.lua); damage / range / recoil / noise are scaled
    from the caliber unless `stats` sets them.

    Magazines are ids from ZGB_Def_Magazines.lua, one per tier, and only the
    tiers that exist for that gun. Guns without a detachable magazine use
    internalCapacity (cylinder, tube or internal box).

    `replaces`: vanilla items this gun takes the place of in loot.
    `rarity`:   loot weight next to its family when it replaces nothing.
]]
require "ZGB/Defs/ZGB_Def_Magazines"
require "ZGB/Defs/ZGB_Def_Anims"
require "ZGB/Defs/ZGB_Def_Recoil"
require "ZGB/Factory/ZGB_WeaponFactory"
local W = ZGB.WeaponFactory

-- ---------------------------------------------------------------- slot builders
local function sling()          return { kind = "sling",      accepts = { "sling_loop" },       label = "Sling",        order = 9 } end
local function optic(i)         return { kind = "optic",      accepts = { i or "picatinny" },   label = "Optic rail",   order = 1 } end
local function mount(i, label)  return { kind = "mount",      accepts = { i },                  label = label,          order = 1 } end
local function under()          return { kind = "underbarrel",accepts = { "picatinny_under" },  label = "Under rail",   order = 2 } end
local function handguard(i)     return { kind = "handguard",  accepts = { i },                  label = "Handguard",    order = 2 } end
local function muzzle(i)        return { kind = "muzzle",     accepts = { i },                  label = "Muzzle",       order = 3 } end
local function stock(i)         return { kind = "stock",      accepts = { i },                  label = "Stock",        order = 4 } end
local function bipod()          return { kind = "bipod",      accepts = { "sling_stud" },       label = "Bipod stud",   order = 5 } end
local function sidesaddle()     return { kind = "sidesaddle", accepts = { "shotgun_receiver" }, label = "Receiver side",order = 6 } end
local function adapter(i, label, order) return { kind = "adapter", accepts = { i }, label = label, order = order } end
local function scopeBase()      return mount("drilled_tapped", "Scope base") end

local AUTO, BURST = { "auto", "single" }, { "burst", "single" }
local GLOCK9  = { standard = "Glock17_Mag17", extended = "Glock17_Mag33", drum = "Glock_Drum50" }
local STANAG  = { standard = "STANAG_Mag30",  extended = "STANAG_Mag40",  drum = "STANAG_CMag100" }

-- ================================================================ handguns (16)
W.define{ id = "Glock17", archetype = "pistol", displayName = "Glock 17", caliber = "9x19",
    magazines = GLOCK9, stats = { weight = 0.63 }, rarity = 0.6,
    slots = { under_rail = under(), muzzle = muzzle("muzzle_pistol_9mm") },
    notes = "Threaded barrel variant so the muzzle slot is real." }
W.define{ id = "Glock19", archetype = "pistol", displayName = "Glock 19", caliber = "9x19",
    magazines = { standard = "Glock19_Mag15", extended = "Glock17_Mag33", drum = "Glock_Drum50" },
    stats = { weight = 0.60 }, rarity = 0.5,
    slots = { under_rail = under(), muzzle = muzzle("muzzle_pistol_9mm") } }
W.define{ id = "Glock18C", recoil = { pattern = "erratic" }, archetype = "pistol", displayName = "Glock 18C", caliber = "9x19",
    magazines = GLOCK9, fireModes = AUTO, stats = { weight = 0.62 }, rarity = 0.05,
    slots = { under_rail = under() },
    notes = "Ported (compensated) slide: no muzzle slot." }
W.define{ id = "Beretta92FS", archetype = "pistol", displayName = "Beretta 92FS", caliber = "9x19",
    magazines = { standard = "Beretta92_Mag15", extended = "Beretta92_Mag30" },
    stats = { weight = 0.95 }, replaces = { "Base.Pistol" },
    slots = { muzzle = muzzle("muzzle_pistol_9mm") } }
W.define{ id = "SIG_P226", archetype = "pistol", displayName = "SIG Sauer P226", caliber = "9x19",
    magazines = { standard = "P226_Mag15", extended = "P226_Mag20" }, stats = { weight = 0.96 }, rarity = 0.3,
    slots = { under_rail = under() } }
W.define{ id = "CZ75", archetype = "pistol", displayName = "CZ 75", caliber = "9x19",
    magazines = { standard = "CZ75_Mag16", extended = "CZ75_Mag26" }, stats = { weight = 1.0 }, rarity = 0.25 }
W.define{ id = "SIG_M17", archetype = "pistol", displayName = "SIG Sauer M17", caliber = "9x19",
    magazines = { standard = "M17_Mag17", extended = "M17_Mag21" }, stats = { weight = 0.83 }, rarity = 0.2,
    slots = { under_rail = under(), optic = optic("rmr") },
    notes = "Optics-ready slide (RMR cut)." }
W.define{ id = "Colt1911", archetype = "pistol", displayName = "Colt M1911A1", caliber = "45acp",
    magazines = { standard = "M1911_Mag7", extended = "M1911_Mag10" },
    stats = { weight = 1.1 }, replaces = { "Base.Pistol2" },
    slots = { muzzle = muzzle("muzzle_pistol_45") } }
W.define{ id = "Glock21", archetype = "pistol", displayName = "Glock 21", caliber = "45acp",
    magazines = { standard = "Glock21_Mag13", extended = "Glock21_Mag26" }, stats = { weight = 0.74 }, rarity = 0.3,
    slots = { under_rail = under(), muzzle = muzzle("muzzle_pistol_45") } }
W.define{ id = "HK_USP45", archetype = "pistol", displayName = "HK USP45 Tactical", caliber = "45acp",
    magazines = { standard = "USP45_Mag12" }, stats = { weight = 0.78 }, rarity = 0.2,
    slots = { usp_rail = adapter("usp_rail", "USP rail", 2), muzzle = muzzle("muzzle_pistol_45") },
    notes = "Proprietary rail: lights need the USP rail adapter first." }
W.define{ id = "Glock22", archetype = "pistol", displayName = "Glock 22", caliber = "40sw",
    magazines = { standard = "Glock22_Mag15", extended = "Glock22_Mag22" }, stats = { weight = 0.65 }, rarity = 0.4,
    slots = { under_rail = under() },
    notes = "Police service pistol: common in police stations." }
W.define{ id = "WaltherPPK", archetype = "pistol", displayName = "Walther PPK", caliber = "380acp",
    magazines = { standard = "PPK_Mag7" }, stats = { weight = 0.59 }, rarity = 0.3 }
W.define{ id = "RugerMkII", archetype = "pistol", displayName = "Ruger Mk II", caliber = "22lr",
    magazines = { standard = "MkII_Mag10" }, stats = { weight = 1.0 }, rarity = 0.4,
    slots = { muzzle = muzzle("muzzle_rimfire") } }
W.define{ id = "MakarovPM", archetype = "pistol", displayName = "Makarov PM", caliber = "9x18",
    magazines = { standard = "PM_Mag8" }, stats = { weight = 0.73 }, rarity = 0.1 }
W.define{ id = "TokarevTT33", archetype = "pistol", displayName = "Tokarev TT-33", caliber = "762x25",
    magazines = { standard = "TT33_Mag8" }, stats = { weight = 0.85 }, rarity = 0.1 }
W.define{ id = "FN_FiveSeven", archetype = "pistol", displayName = "FN Five-seveN", caliber = "57x28",
    magazines = { standard = "FiveSeven_Mag20", extended = "FiveSeven_Mag30" }, stats = { weight = 0.61 }, rarity = 0.08,
    slots = { under_rail = under(), optic = optic("rmr") },
    notes = "MRD slide (optic cut)." }

-- ================================================================ revolvers & hand cannons (12)
W.define{ id = "SW_Model10", archetype = "revolver", displayName = "S&W Model 10", caliber = "38spl",
    internalCapacity = 6, stats = { weight = 0.86 }, replaces = { "Base.Revolver_Short" } }
W.define{ id = "ColtPython", archetype = "revolver", displayName = "Colt Python", caliber = "357mag",
    internalCapacity = 6, stats = { weight = 1.1 }, rarity = 0.2 }
W.define{ id = "RugerGP100", archetype = "revolver", displayName = "Ruger GP100", caliber = "357mag",
    internalCapacity = 6, stats = { weight = 1.1 }, rarity = 0.3 }
W.define{ id = "SW_686Plus", archetype = "revolver", displayName = "S&W 686 Plus", caliber = "357mag",
    internalCapacity = 7, stats = { weight = 1.2 }, rarity = 0.3 }
W.define{ id = "SW_Model29", archetype = "revolver", displayName = "S&W Model 29", caliber = "44mag",
    internalCapacity = 6, stats = { weight = 1.4 }, replaces = { "Base.Revolver_Long" } }
W.define{ id = "ColtAnaconda", archetype = "revolver", displayName = "Colt Anaconda", caliber = "44mag",
    internalCapacity = 6, stats = { weight = 1.5 }, rarity = 0.15 }
W.define{ id = "ColtSAA", animType = "revolver_gate", archetype = "revolver", displayName = "Colt Single Action Army", caliber = "45colt",
    internalCapacity = 6, stats = { weight = 1.0, reloadTime = 45 }, replaces = { "Base.Revolver" },
    notes = "Single action, loading gate: loads one chamber at a time (slower reload)." }
W.define{ id = "TaurusJudge", archetype = "revolver", displayName = "Taurus Judge", caliber = "410ga",
    internalCapacity = 5, ballistics = { projectileCount = 3 },
    stats = { weight = 0.82, minDamage = 0.7, maxDamage = 1.1, range = 6 }, rarity = 0.3 }
W.define{ id = "RugerSuperRedhawk", archetype = "revolver", displayName = "Ruger Super Redhawk", caliber = "454casull",
    internalCapacity = 6, stats = { weight = 1.5 }, rarity = 0.1,
    slots = { scope_rings = mount("ruger_integral", "Integral ring cuts") } }
W.define{ id = "SW_Model500", archetype = "revolver", displayName = "S&W Model 500", caliber = "500sw",
    internalCapacity = 5, stats = { weight = 2.0 }, rarity = 0.05 }
W.define{ id = "NagantM1895", animType = "revolver_gate", archetype = "revolver", displayName = "Nagant M1895", caliber = "762x38r",
    internalCapacity = 7, stats = { weight = 0.8, reloadTime = 50 }, rarity = 0.08,
    notes = "Gas-seal revolver, loads through a gate one round at a time." }
W.define{ id = "DesertEagle", archetype = "pistol", category = "revolver", displayName = "Desert Eagle Mark XIX",
    caliber = "50ae", magazines = { standard = "DEagle_Mag7" }, stats = { weight = 2.0 },
    replaces = { "Base.Pistol3" },
    slots = { optic = optic() },
    notes = "Mag-fed hand cannon; integral top rail." }

-- ================================================================ assault rifles (8)
W.define{ id = "AK47", recoil = { pattern = "climb_right" }, archetype = "assault_rifle", displayName = "AK-47", caliber = "762x39",
    magazines = { standard = "AK47_Mag30", extended = "AK_Mag40", drum = "AK47_Drum75" },
    stats    = { minDamage = 1.4, maxDamage = 2.1, recoilDelay = 16, weight = 3.6 },
    rarity   = 0.3,
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
W.define{ id = "AK74", recoil = { pattern = "low" }, archetype = "assault_rifle", displayName = "AK-74", caliber = "545x39",
    magazines = { standard = "AK74_Mag30", extended = "AK74_Mag45" }, stats = { weight = 3.3 }, rarity = 0.15,
    slots = { side_mount = mount("ak_dovetail", "Side mount"), muzzle = muzzle("ak74_24x15"),
              handguard = handguard("ak_handguard"), stock = stock("ak_stock"), sling = sling() } }
W.define{ id = "M16A2", archetype = "assault_rifle", displayName = "M16A2", caliber = "556x45",
    magazines = STANAG, fireModes = BURST, stats = { weight = 3.4 }, replaces = { "Base.AssaultRifle" },
    slots = { carry_handle = mount("ar_carry_handle", "Carry handle"), muzzle = muzzle("muzzle_rifle_556"),
              handguard = handguard("ar_handguard"), sling = sling() },
    notes = "Carry handle and fixed A2 stock; optics need the carry-handle mount." }
W.define{ id = "M4A1", archetype = "assault_rifle", displayName = "M4A1", caliber = "556x45",
    magazines = STANAG, stats = { weight = 2.9 }, rarity = 0.3,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_rifle_556"),
              stock = stock("ar_buffer_tube"), sling = sling() } }
W.define{ id = "HK416", recoil = { pattern = "low" }, archetype = "assault_rifle", displayName = "HK416", caliber = "556x45",
    magazines = STANAG, stats = { weight = 3.3 }, rarity = 0.1,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_rifle_556"),
              stock = stock("ar_buffer_tube"), sling = sling() } }
W.define{ id = "SteyrAUG", animType = "bullpup", archetype = "assault_rifle", displayName = "Steyr AUG A1", caliber = "556x45",
    magazines = { standard = "AUG_Mag30", extended = "AUG_Mag42" }, stats = { weight = 3.6, aimTime = 26 }, rarity = 0.08,
    slots = { sling = sling() },
    notes = "Bullpup with an integral 1.5x optic in the carry handle: no optic slot." }
W.define{ id = "IMI_Galil", recoil = { pattern = "climb_right" }, archetype = "assault_rifle", displayName = "IMI Galil ARM", caliber = "556x45",
    magazines = { standard = "Galil_Mag35", extended = "Galil_Mag50" }, stats = { weight = 4.0 }, rarity = 0.08,
    slots = { sling = sling() },
    notes = "Built-in folding stock and bipod (part of the gun model)." }
W.define{ id = "HK_G36", archetype = "assault_rifle", displayName = "HK G36", caliber = "556x45",
    magazines = { standard = "G36_Mag30", drum = "G36_CMag100" }, stats = { weight = 3.3, aimTime = 27 }, rarity = 0.08,
    slots = { sling = sling() },
    notes = "Integral optic in the carry handle: no optic slot." }

-- ================================================================ designated marksman rifles (4)
W.define{ id = "M14", archetype = "dmr", displayName = "M14", caliber = "308win",
    magazines = { standard = "M14_Mag20", extended = "M14_Mag30" }, stats = { weight = 4.5 },
    replaces = { "Base.AssaultRifle2" },
    slots = { scope_mount = mount("m14_receiver", "Receiver mount"), muzzle = muzzle("muzzle_rifle_308"), sling = sling() } }
W.define{ id = "SVD", archetype = "dmr", displayName = "SVD Dragunov", caliber = "762x54r",
    magazines = { standard = "SVD_Mag10" }, stats = { weight = 4.3 }, rarity = 0.08,
    slots = { side_rail = optic("svd_side_rail"), sling = sling() },
    notes = "Side rail takes the PSO-1 only." }
W.define{ id = "SR25", archetype = "dmr", displayName = "Knight's SR-25", caliber = "308win",
    magazines = { standard = "SR25_Mag20", extended = "SR25_Mag25" }, stats = { weight = 4.9 }, rarity = 0.1,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_rifle_308"),
              stock = stock("ar_buffer_tube"), sling = sling() } }
W.define{ id = "Mk12SPR", archetype = "dmr", displayName = "Mk 12 SPR", caliber = "556x45",
    magazines = STANAG, stats = { weight = 4.5 }, rarity = 0.08,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_rifle_556"),
              stock = stock("ar_buffer_tube"), sling = sling() } }

-- ================================================================ sniper rifles, bolt action (8)
W.define{ id = "Rem700", animType = "bolt_internal", archetype = "bolt_rifle", displayName = "Remington 700", caliber = "308win",
    reloadType = "boltactionnomag", internalCapacity = 4, stats = { weight = 3.4 },
    replaces = { "Base.HuntingRifle", "Base.VarmintRifle" },
    slots = { scope_base = scopeBase(), bipod = bipod(), sling = sling() } }
W.define{ id = "Win70", animType = "bolt_internal", archetype = "bolt_rifle", displayName = "Winchester Model 70", caliber = "3006",
    reloadType = "boltactionnomag", internalCapacity = 5, stats = { weight = 3.6 }, rarity = 0.5,
    slots = { scope_base = scopeBase(), bipod = bipod(), sling = sling() } }
W.define{ id = "MosinNagant", animType = "bolt_internal", archetype = "bolt_rifle", displayName = "Mosin-Nagant M91/30", caliber = "762x54r",
    reloadType = "boltactionnomag", internalCapacity = 5, stats = { weight = 4.0 }, rarity = 0.2,
    slots = { pu_mount = mount("mosin_receiver", "Receiver side mount"), sling = sling() } }
W.define{ id = "Kar98k", animType = "bolt_internal", archetype = "bolt_rifle", displayName = "Mauser Kar98k", caliber = "792x57",
    reloadType = "boltactionnomag", internalCapacity = 5, stats = { weight = 3.9 }, rarity = 0.1,
    slots = { sling = sling() } }
W.define{ id = "LeeEnfieldNo4", animType = "bolt_internal", archetype = "bolt_rifle", displayName = "Lee-Enfield No. 4", caliber = "303brit",
    reloadType = "boltactionnomag", internalCapacity = 10, stats = { weight = 4.1 }, rarity = 0.1,
    slots = { sling = sling() },
    notes = "Fixed 10-round box loaded with stripper clips; treated as internal." }
W.define{ id = "AI_AWM", archetype = "bolt_rifle", displayName = "Accuracy International AWM", caliber = "338lm",
    magazines = { standard = "AWM_Mag5" }, stats = { weight = 6.5 }, rarity = 0.03,
    slots = { optic_rail = optic(), muzzle = muzzle("muzzle_338"), bipod = bipod(), sling = sling() } }
W.define{ id = "RugerRPR", archetype = "bolt_rifle", displayName = "Ruger Precision Rifle", caliber = "65cm",
    magazines = { standard = "AICS_Mag10" }, stats = { weight = 4.8 }, rarity = 0.1,
    slots = { optic_rail = optic(), muzzle = muzzle("muzzle_rifle_308"), bipod = bipod(),
              stock = stock("ar_buffer_tube"), sling = sling() },
    notes = "5/8-24 thread takes the .308 can; AR buffer tube takes AR stocks." }
W.define{ id = "BarrettM95", archetype = "bolt_rifle", displayName = "Barrett M95", caliber = "50bmg",
    magazines = { standard = "M95_Mag5" }, stats = { weight = 10.0 }, rarity = 0.01,
    slots = { optic_rail = optic(), sling = sling() },
    notes = "Bullpup, integral bipod and muzzle brake (part of the gun model)." }

-- ================================================================ submachine guns (8)
W.define{ id = "MP5A3", recoil = { pattern = "low" }, archetype = "smg", displayName = "HK MP5A3", caliber = "9x19",
    magazines = { standard = "MP5_Mag30", drum = "MP5_CMag100" }, fireModes = { "auto", "burst", "single" },
    stats = { weight = 2.5 }, rarity = 0.15,
    slots = { claw_mount = mount("hk_claw", "Claw mount"), handguard = handguard("hk_handguard"),
              muzzle = adapter("hk_3lug", "3-lug barrel", 3), sling = sling() },
    notes = "Suppressor chain: 3-lug adapter first, then a 9mm can." }
W.define{ id = "Uzi", openBolt = true, recoil = { pattern = "erratic" }, archetype = "smg", displayName = "IMI Uzi", caliber = "9x19",
    magazines = { standard = "Uzi_Mag32", extended = "Uzi_Mag50" }, stats = { weight = 3.5 }, rarity = 0.15,
    slots = { sling = sling() } }
W.define{ id = "MAC10", openBolt = true, recoil = { pattern = "erratic" }, archetype = "smg", displayName = "MAC-10", caliber = "45acp",
    magazines = { standard = "MAC10_Mag30" }, stats = { weight = 2.8, hitChance = 28 }, rarity = 0.1,
    slots = { muzzle = muzzle("muzzle_pistol_45"), sling = sling() } }
W.define{ id = "ThompsonM1928", openBolt = true, recoil = { pattern = "climb_left" }, archetype = "smg", displayName = "Thompson M1928A1", caliber = "45acp",
    magazines = { standard = "Thompson_Mag20", extended = "Thompson_Mag30", drum = "Thompson_Drum50" },
    stats = { weight = 4.9 }, rarity = 0.05, slots = { sling = sling() } }
W.define{ id = "UMP45", archetype = "smg", displayName = "HK UMP45", caliber = "45acp",
    magazines = { standard = "UMP45_Mag25" }, stats = { weight = 2.3 }, rarity = 0.08,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_pistol_45"), sling = sling() } }
W.define{ id = "FN_P90", animType = "bullpup", recoil = { pattern = "low" }, archetype = "smg", displayName = "FN P90", caliber = "57x28",
    magazines = { standard = "P90_Mag50" }, stats = { weight = 2.6 }, rarity = 0.03,
    slots = { sling = sling() },
    notes = "Top-mounted translucent magazine; integral ring sight." }
W.define{ id = "KrissVector", recoil = { pattern = "low" }, archetype = "smg", displayName = "KRISS Vector", caliber = "45acp",
    magazines = { standard = "Glock21_Mag13", extended = "Glock21_Mag26" }, stats = { weight = 2.7, recoilDelay = 6 },
    rarity = 0.04,
    slots = { optic_rail = optic(), under_rail = under(), muzzle = muzzle("muzzle_pistol_45"), sling = sling() },
    notes = "Takes Glock 21 magazines." }
W.define{ id = "PPSh41", openBolt = true, recoil = { pattern = "s_curve" }, archetype = "smg", displayName = "PPSh-41", caliber = "762x25",
    magazines = { standard = "PPSh_Mag35", drum = "PPSh_Drum71" }, stats = { weight = 3.6 }, rarity = 0.05,
    slots = { sling = sling() } }

-- ================================================================ shotguns (8)
W.define{ id = "M590", archetype = "shotgun", displayName = "Mossberg 590", caliber = "12ga",
    internalCapacity = 8, stats = { weight = 3.4 }, replaces = { "Base.Shotgun" },
    slots = { scope_base = scopeBase(), sidesaddle = sidesaddle(), stock = stock("m590_stock"), sling = sling() } }
W.define{ id = "Rem870", archetype = "shotgun", displayName = "Remington 870", caliber = "12ga",
    internalCapacity = 4, stats = { weight = 3.6 }, rarity = 0.8,
    slots = { scope_base = scopeBase(), sidesaddle = sidesaddle(), choke = muzzle("choke_12ga"),
              stock = stock("r870_stock"), sling = sling() } }
W.define{ id = "BenelliM4", animType = "semi_shotgun", archetype = "shotgun", displayName = "Benelli M4", caliber = "12ga",
    internalCapacity = 5, stats = { weight = 3.8, recoilDelay = 15 }, rarity = 0.1,
    slots = { optic_rail = optic(), sidesaddle = sidesaddle(), choke = muzzle("choke_12ga"), sling = sling() },
    notes = "Semi-automatic: faster follow-up shots." }
W.define{ id = "Saiga12", animType = "rifle", archetype = "shotgun", displayName = "Saiga-12", caliber = "12ga",
    reloadType = "handgun", magazines = { standard = "Saiga12_Mag5", extended = "Saiga12_Mag10", drum = "Saiga12_Drum20" },
    stats = { weight = 3.6, recoilDelay = 16 }, rarity = 0.08,
    slots = { side_mount = mount("ak_dovetail", "Side mount"), sling = sling() } }
W.define{ id = "KSG", archetype = "shotgun", displayName = "Kel-Tec KSG", caliber = "12ga",
    internalCapacity = 14, stats = { weight = 3.5 }, rarity = 0.05,
    slots = { optic_rail = optic(), under_rail = under(), sling = sling() },
    notes = "Bullpup with two 7-round tubes." }
W.define{ id = "CoachGun", animType = "break_action", archetype = "shotgun", displayName = "Double-Barrel Coach Gun", caliber = "12ga",
    reloadType = "doublebarrelshotgun", internalCapacity = 2, stats = { weight = 3.2 },
    replaces = { "Base.DoubleBarrelShotgun", "Base.DoubleBarrelShotgunSawnoff", "Base.ShotgunSawnoff" } }
W.define{ id = "Win1897", archetype = "shotgun", displayName = "Winchester Model 1897", caliber = "12ga",
    internalCapacity = 5, stats = { weight = 3.6 }, rarity = 0.15, slots = { sling = sling() } }
W.define{ id = "AA12", animType = "rifle", openBolt = true, recoil = { pattern = "low" }, archetype = "shotgun", displayName = "AA-12", caliber = "12ga",
    reloadType = "handgun", magazines = { standard = "AA12_Mag8", drum = "AA12_Drum32" }, fireModes = AUTO,
    stats = { weight = 5.2, recoilDelay = 10 }, rarity = 0.01,
    slots = { optic_rail = optic(), sling = sling() } }

-- ================================================================ lever-action rifles (6)
W.define{ id = "Win1894", archetype = "lever_rifle", displayName = "Winchester Model 1894", caliber = "3030",
    internalCapacity = 7, stats = { weight = 3.0 }, rarity = 0.6,
    slots = { scope_base = scopeBase(), sling = sling() } }
W.define{ id = "Marlin336", archetype = "lever_rifle", displayName = "Marlin 336", caliber = "3030",
    internalCapacity = 6, stats = { weight = 3.2 }, rarity = 0.6,
    slots = { scope_base = scopeBase(), sling = sling() } }
W.define{ id = "HenryBigBoy", archetype = "lever_rifle", displayName = "Henry Big Boy", caliber = "44mag",
    internalCapacity = 10, stats = { weight = 3.9 }, rarity = 0.3,
    slots = { scope_base = scopeBase(), sling = sling() } }
W.define{ id = "Marlin1894", archetype = "lever_rifle", displayName = "Marlin 1894C", caliber = "357mag",
    internalCapacity = 9, stats = { weight = 2.9 }, rarity = 0.3,
    slots = { scope_base = scopeBase(), sling = sling() } }
W.define{ id = "HenryH001", archetype = "lever_rifle", displayName = "Henry H001 .22", caliber = "22lr",
    internalCapacity = 15, stats = { weight = 2.4 }, rarity = 0.5,
    slots = { receiver_groove = optic("dovetail_22"), sling = sling() } }
W.define{ id = "Marlin1895GG", archetype = "lever_rifle", displayName = "Marlin 1895 Guide Gun", caliber = "4570",
    internalCapacity = 6, stats = { weight = 3.2 }, rarity = 0.15,
    slots = { scope_base = scopeBase(), sling = sling() } }
