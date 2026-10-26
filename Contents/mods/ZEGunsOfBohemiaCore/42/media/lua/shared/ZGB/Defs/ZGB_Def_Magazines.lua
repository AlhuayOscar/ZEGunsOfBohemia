--[[
    ZGB_Def_Magazines.lua  —  every detachable magazine, by caliber.

    Real capacities only. A magazine shared by several guns is defined ONCE
    here and listed by each gun (STANAG, Glock 9mm, Glock 21 / KRISS Vector).
    Tier penalties come from ZGB_MagazineFactory.TIERS unless `mods` is given.
]]
require "ZGB/Factory/ZGB_MagazineFactory"
local G = ZGB.MagazineFactory

local function mag(id, caliber, tier, capacity, displayName, weight, mods)
    G.define{ id = id, caliber = caliber, tier = tier, capacity = capacity,
              displayName = displayName, weight = weight, mods = mods }
end

-- ---------------------------------------------------------------- 9x19mm
mag("Glock17_Mag17",   "9x19", "standard", 17, "Glock 17rd Magazine",           0.08)
mag("Glock19_Mag15",   "9x19", "standard", 15, "Glock 19 15rd Magazine",        0.07)
mag("Glock17_Mag33",   "9x19", "extended", 33, "Glock 33rd Extended Magazine",  0.15)   -- fits G17 / G18C / G19
mag("Glock_Drum50",    "9x19", "drum",     50, "Glock 50rd Drum",               0.60)
mag("Beretta92_Mag15", "9x19", "standard", 15, "Beretta 92 15rd Magazine",      0.09)
mag("Beretta92_Mag30", "9x19", "extended", 30, "Beretta 92 30rd Extended Magazine", 0.16)
mag("P226_Mag15",      "9x19", "standard", 15, "SIG P226 15rd Magazine",        0.09)
mag("P226_Mag20",      "9x19", "extended", 20, "SIG P226 20rd Extended Magazine", 0.11)
mag("CZ75_Mag16",      "9x19", "standard", 16, "CZ 75 16rd Magazine",           0.09)
mag("CZ75_Mag26",      "9x19", "extended", 26, "CZ 75 26rd Extended Magazine",  0.14)
mag("M17_Mag17",       "9x19", "standard", 17, "SIG M17 17rd Magazine",         0.09)
mag("M17_Mag21",       "9x19", "extended", 21, "SIG M17 21rd Extended Magazine", 0.11)
mag("Prodigy_Mag17",   "9x19", "standard", 17, "Prodigy 17rd Magazine",         0.09)
mag("Prodigy_Mag20",   "9x19", "extended", 20, "Prodigy 20rd Extended Magazine", 0.10)
mag("MP5_Mag30",       "9x19", "standard", 30, "MP5 30rd Magazine",             0.12)
mag("MP5_CMag100",     "9x19", "drum",    100, "MP5 100rd Twin Drum (C-Mag)",   0.90)
mag("Uzi_Mag32",       "9x19", "standard", 32, "Uzi 32rd Magazine",             0.20)
mag("Uzi_Mag50",       "9x19", "extended", 50, "Uzi 50rd Extended Magazine",    0.30)

-- ---------------------------------------------------------------- .45 ACP
mag("M1911_Mag7",      "45acp", "standard",  7, "M1911 7rd Magazine",           0.07)
mag("M1911_Mag10",     "45acp", "extended", 10, "M1911 10rd Extended Magazine", 0.10)
mag("Glock21_Mag13",   "45acp", "standard", 13, "Glock 21 13rd Magazine",       0.09)   -- also KRISS Vector
mag("Glock21_Mag26",   "45acp", "extended", 26, "Glock 21 26rd Extended Magazine", 0.17)
mag("USP45_Mag12",     "45acp", "standard", 12, "HK USP45 12rd Magazine",       0.10)
mag("MAC10_Mag30",     "45acp", "standard", 30, "MAC-10 30rd Magazine",         0.20)
mag("Thompson_Mag20",  "45acp", "standard", 20, "Thompson 20rd Stick Magazine", 0.20)
mag("Thompson_Mag30",  "45acp", "extended", 30, "Thompson 30rd Stick Magazine", 0.28)
mag("Thompson_Drum50", "45acp", "drum",     50, "Thompson 50rd L-Drum",         1.10)
mag("UMP45_Mag25",     "45acp", "standard", 25, "UMP45 25rd Magazine",          0.15)

-- ---------------------------------------------------------------- other pistol calibers
mag("Glock22_Mag15",   "40sw",   "standard", 15, "Glock 22 15rd Magazine",      0.08)
mag("Glock22_Mag22",   "40sw",   "extended", 22, "Glock 22 22rd Extended Magazine", 0.12)
mag("PPK_Mag7",        "380acp", "standard",  7, "Walther PPK 7rd Magazine",    0.05)
mag("MkII_Mag10",      "22lr",   "standard", 10, "Ruger Mk II 10rd Magazine",   0.05)
mag("PM_Mag8",         "9x18",   "standard",  8, "Makarov PM 8rd Magazine",     0.06)
mag("TT33_Mag8",       "762x25", "standard",  8, "Tokarev TT-33 8rd Magazine",  0.06)
mag("PPSh_Mag35",      "762x25", "standard", 35, "PPSh-41 35rd Box Magazine",   0.25)
mag("PPSh_Drum71",     "762x25", "drum",     71, "PPSh-41 71rd Drum",           1.20)
mag("FiveSeven_Mag20", "57x28",  "standard", 20, "Five-seveN 20rd Magazine",    0.06)
mag("FiveSeven_Mag30", "57x28",  "extended", 30, "Five-seveN 30rd Extended Magazine", 0.09)
mag("P90_Mag50",       "57x28",  "standard", 50, "P90 50rd Magazine",           0.20)
mag("DEagle_Mag7",     "50ae",   "standard",  7, "Desert Eagle .50 7rd Magazine", 0.16)

-- ---------------------------------------------------------------- rifle
mag("AK47_Mag30",      "762x39", "standard", 30, "AK-47 30rd Magazine",         0.30)
mag("AK_Mag40",        "762x39", "extended", 40, "RPK 40rd Magazine",           0.40)
mag("AK47_Drum75",     "762x39", "drum",     75, "AK-47 75rd Drum",             1.40,
    { add = { weight = 1.4, aimTime = 6, reloadTime = 12 } })
mag("AK74_Mag30",      "545x39", "standard", 30, "AK-74 30rd Magazine",         0.23)
mag("AK74_Mag45",      "545x39", "extended", 45, "RPK-74 45rd Magazine",        0.35)
mag("STANAG_Mag30",    "556x45", "standard", 30, "STANAG 30rd Magazine",        0.12)   -- M16A2 / M4A1 / HK416 / Mk 12
mag("STANAG_Mag40",    "556x45", "extended", 40, "STANAG 40rd Magazine",        0.16)
mag("STANAG_CMag100",  "556x45", "drum",    100, "STANAG 100rd Twin Drum (C-Mag)", 1.00)
mag("AUG_Mag30",       "556x45", "standard", 30, "Steyr AUG 30rd Magazine",     0.13)
mag("AUG_Mag42",       "556x45", "extended", 42, "Steyr AUG 42rd Magazine",     0.17)
mag("Galil_Mag35",     "556x45", "standard", 35, "Galil 35rd Magazine",         0.25)
mag("Galil_Mag50",     "556x45", "extended", 50, "Galil 50rd Magazine",         0.35)
mag("G36_Mag30",       "556x45", "standard", 30, "G36 30rd Magazine",           0.13)
mag("G36_CMag100",     "556x45", "drum",    100, "G36 100rd Twin Drum (C-Mag)", 1.00)
mag("M14_Mag20",       "308win", "standard", 20, "M14 20rd Magazine",           0.24)
mag("M14_Mag30",       "308win", "extended", 30, "M14 30rd Magazine",           0.33)
mag("SR25_Mag20",      "308win", "standard", 20, "SR-25 20rd Magazine",         0.15)
mag("SR25_Mag25",      "308win", "extended", 25, "SR-25 25rd Magazine",         0.18)
mag("SVD_Mag10",       "762x54r","standard", 10, "SVD 10rd Magazine",           0.20)
mag("AWM_Mag5",        "338lm",  "standard",  5, "AWM .338 5rd Magazine",       0.20)
mag("AICS_Mag10",      "65cm",   "standard", 10, "AICS 10rd Magazine",          0.15)
mag("M95_Mag5",        "50bmg",  "standard",  5, "Barrett M95 5rd Magazine",    0.40)

-- ---------------------------------------------------------------- shotgun
mag("Saiga12_Mag5",    "12ga", "standard",  5, "Saiga-12 5rd Magazine",         0.30)
mag("Saiga12_Mag10",   "12ga", "extended", 10, "Saiga-12 10rd Magazine",        0.50)
mag("Saiga12_Drum20",  "12ga", "drum",     20, "Saiga-12 20rd Drum",            1.60)
mag("AA12_Mag8",       "12ga", "standard",  8, "AA-12 8rd Box Magazine",        0.40)
mag("AA12_Drum32",     "12ga", "drum",     32, "AA-12 32rd Drum",               2.20)
