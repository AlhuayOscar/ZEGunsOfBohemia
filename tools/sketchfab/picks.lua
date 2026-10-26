--[[
    picks.lua  -  the Sketchfab model chosen for each gun and part (by uid).

    Picked from the contact sheets of tools/sketchfab/search.py (.cache/sketchfab/sheets/).
    tools/sketchfab/fetch.py downloads them (your own Sketchfab API token); tools/model_sources.lua
    then uses each downloaded pick instead of the older low-poly source. `fix` is the same as in
    model_sources.lua, plus drop_loose = true (leave out pieces lying beside the gun: a spare
    magazine, loose rounds) and cut_top (a scope that is part of the mesh).
    Only CC0 / CC-BY models: fetch.py checks the license again before downloading.
]]
return {
    AA12 = { uid = "9e5d30e1cbc3472485f95d860de383b7" },              -- Low-Poly AA-12 (TastyTony, CC-BY 4.0)
    AI_AWM = { uid = "bacc05ad5c074c9daa3aa7ca02766a6c", fix = { cut_top = 0.33 } }, -- AWM (ErhanMatur, CC-BY 4.0)
    AK74 = { uid = "9b1dc4d02ff34bd299c713a5b04a0a15", fix = { stock_cut = -0.130 } },              -- Ak 74 (BRAIN_ZIP, CC-BY 4.0)
    Adapter_USP_Rail = { uid = "875c12f39cbd4f01a7c84f58ebb7c236" },  -- H&K USP Rail Adapter Accessory Low Poly (8sianDude, CC-BY 4.0)
    BarrettM95 = { uid = "e86c3ef020ae4e3989ab28f4253c3989" },        -- Barrett M95 (Zeruel_V, CC-BY 4.0)
    BenelliM4 = { uid = "caea90a9470143b69e6042f75b9c59cc", fix = { stock_cut = -0.090, stock_grip = -0.130 } },         -- Low-Poly Benelli M4 Super 90 (TastyTony, CC-BY 4.0)
    Beretta92FS = { uid = "bf58795f626d4251b11c5e23d2922358" },       -- Beretta 92 (clean) (romunql, CC-BY 4.0)
    Bipod_Harris = { uid = "daa7dd1e247e453496974a5d252396f4" },      -- Harris Bipod (Low-Poly) (GoldbergR, CC-BY 4.0)
    Brake_Rifle308 = { uid = "2802bba616e1411594d2200f02075904" },    -- Heart Rifle Flash Hider / Muzzle Brake V (Socksthecat, CC-BY 4.0)
    Brake_Rifle556 = { uid = "2802bba616e1411594d2200f02075904" },    -- Heart Rifle Flash Hider / Muzzle Brake V (Socksthecat, CC-BY 4.0)
    CZ75 = { uid = "455fc253735b4dd7a072fb64ae816ef6" },              -- Game-Ready : CZ 75 TS Czechmate (Akshay Kumar, CC-BY 4.0) - #5 came apart (exploded view)
    CoachGun = { uid = "04741a40f2224cffafc343b0236d5bbe" },          -- Double Barrel Shotgun (Sebastian Kansik, CC-BY 4.0)
    Colt1911 = { uid = "117f542d21954ae0a59afaedadcff338" },          -- Low-Poly M1911 (TastyTony, CC-BY 4.0) - #2 came in loose pieces
    ColtAnaconda = { uid = "515e09e560434ac484f64ee8d2500892" },      -- Colt Anaconda Revolver (Animatable) (CG Nerd, CC-BY 4.0)
    ColtPython = { uid = "e47be5f609ef415f97b51b264cd16259" },        -- Colt Python (Homeless_Models, CC-BY 4.0)
    ColtSAA = { uid = "3cbeeeca808744759464507450b26a50" },           -- Revolver Colt Single Action Army LowPoly (solid3DDD, CC-BY 4.0)
    DesertEagle = { uid = "334462df58b942759122567fa0b81113" },       -- Desert Eagle (Minte Elseviers, CC-BY 4.0)
    FN_FiveSeven = { uid = "b896f7b001864805ae09bb2280b1795a" },      -- FN Five-seveN (TastyTony, CC-BY 4.0) - #2 was a Call of Duty rip
    FN_P90 = { uid = "3f9308f678f94768ba68fee1f15e769b" },            -- P90 (Arjun Perayil, CC-BY 4.0)
    FlashHider_308 = { uid = "799512bc33b4475387a43e98fdbdd2ac" },    -- Flash Hider (FFeller, CC-BY 4.0)
    FlashHider_556 = { uid = "63ca65d9a0cc4d45a65f2cfa3db3b38b" },    -- Flash Hider1 (FFeller, CC-BY 4.0)
    Glock17 = { uid = "e72e230edbfe40d9ba249584bf1f836b" },           -- Glock [psx] (Radint, CC-BY 4.0) - all Glocks share it
    Glock18C = { uid = "e72e230edbfe40d9ba249584bf1f836b" },          -- Glock [psx] (Radint, CC-BY 4.0)
    Glock19 = { uid = "e72e230edbfe40d9ba249584bf1f836b" },           -- Glock [psx] (Radint, CC-BY 4.0)
    Glock21 = { uid = "e72e230edbfe40d9ba249584bf1f836b" },           -- Glock [psx] (Radint, CC-BY 4.0)
    Glock22 = { uid = "e72e230edbfe40d9ba249584bf1f836b" },           -- Glock [psx] (Radint, CC-BY 4.0)
    Grip_Angled = { uid = "a92a52cbb5854f7c8e33507f579073f7" },       -- Low-Poly Magpul AFG (notcplkerry, CC-BY 4.0)
    Grip_Stubby = { uid = "8b676e29ee0e46f1a4948aa5ad3a45c8" },       -- Tango_down_stubby_grip (Dudu, CC-BY 4.0)
    Grip_Vertical = { uid = "a3d66ae7c690404cacc07ddc63fa3b21" },     -- ALFA mod 4 RIOT (HEAVY_PAYLOAD, CC-BY 4.0)
    HK416 = { uid = "059e968f6f764357880807c62c117ab7", fix = { stock_cut = -0.097, stock_grip = -0.120 } },             -- Low-Poly HK416 (TastyTony, CC-BY 4.0)
    HK_G36 = { uid = "526ae321f20c4d62a0fddd5c93783a79", fix = { stock_cut = -0.127, stock_grip = -0.155 } },            -- Low-Poly HK G36 (TastyTony, CC-BY 4.0)
    HK_USP45 = { uid = "e27cf9dcff6b411cb5e7fe0544e402e4" },          -- HP USP 45 (Joche007, CC-BY 4.0)
    IMI_Galil = { uid = "905d96712d03473587114c9eaf9eee5a", fix = { stock_cut = false } },         -- IMI Galil AR (Jusai, CC-BY 4.0)
    KSG = { uid = "6a49a720a5c44ce2acee91d094d6e03d" },               -- Low-Poly Keltec KSG (TastyTony, CC-BY 4.0)
    Kar98k = { uid = "fc66a45db4c64f49b1c94ab23684d4c8" },            -- Kar98k Free (LainMike, CC-BY 4.0)
    KrissVector = { uid = "3916980e5d564fc9bb1971c9d496bdd5", fix = { stock_cut = -0.100 } },       -- KRISS VECTOR (carolineblueeyes, CC-BY 4.0)
    Laser_Pistol = { uid = "522f6a04c34946dbb168022187645c1a" },      -- low-poly AN/PEQ 15 (D_U, CC-BY 4.0)
    Laser_Rifle = { uid = "10297c09417949e8ac10ea6ededee68b" },       -- PEQ-15 (Tuong Truong, CC-BY 4.0) - PEQ-15
    LeeEnfieldNo4 = { uid = "7c35777ac96f4c6693b21a145a6dd7d5" },     -- Lee Enfield SMLE MKIII (skaveria, CC-BY 4.0)
    Light_Pistol = { uid = "c54f9b1152704662a345d5020fd6f872" },      -- Weapon Light (KING MUFFIN, CC-BY 4.0) - compact light
    Light_Weapon = { uid = "208f42ab474b40f08453ee8df016a8e6" },      -- Surefire M952V Weapon Light (RedRogueXIII, CC-BY 4.0)
    M14 = { uid = "d5d0198fef4843c392d280837f74ad66" },               -- M14 | High Poly | PBR | FBX (Stein Games, CC-BY 4.0)
    M16A2 = { uid = "5f14fdfeb4b64f11ac23ec3705cdf4d1", fix = { stock_cut = -0.107, stock_grip = -0.140 } },             -- Low-Poly M16A2 rifle (notcplkerry, CC-BY 4.0)
    M24 = { uid = "d40e74e2259549f5b025807163f1028c", fix = { cut_top = 0.33 } }, -- M24 Bounty Hunter Sniper Rifle (Naudaff3D, CC-BY 4.0)
    M45A1 = { uid = "afa23b99150d453dac92a875e9dc7b08" },             -- Low-Poly Sig Emperor Scorpion (TastyTony, CC-BY 4.0) - #1 had magazine and rounds in the mesh
    M4A1S = { uid = "4ced85fd77e04b71ade5ab11cb28c529", fix = { stock_cut = -0.090, stock_grip = -0.155 } },             -- RIFLE | M4A1-S Weapon Model (CS2) (gettan, CC-BY 4.0)
    M4A4 = { uid = "cfb76a05bfd84ee38ce6663ee3ee5ecf", fix = { stock_cut = -0.060, stock_grip = -0.095 } },              -- RIFLE | M4A4 Weapon Model (CS2) (gettan, CC-BY 4.0)
    M590 = { uid = "fda86dd1e22d43cbaa8bf7deb40ee5ef", fix = { stock_cut = -0.047 } },              -- Mossberg 590 12GA (calico16, CC-BY 4.0)
    MAC10 = { uid = "a8d93858e7a2476db389ba3c05ca5a85" },             -- Ingram Mac 10 (Faheem Yusuf, CC-BY 4.0)
    MP5A3 = { uid = "fad0226e1dcf4af180f707a5509d3a4e", fix = { stock_cut = -0.100 } },             -- HK MP5 SMG (Daniel Zamary, CC-BY 4.0)
    Mk12SPR = { uid = "e66b6868673743cfaa5ede6b31d8f0cc", fix = { stock_cut = -0.125 } },           -- SR-25 (Low-Poly) (GoldbergR, CC-BY 4.0) - AR long rifle
    MosinNagant = { uid = "2fd8a7efd9254b8b81b06934b7782954" },       -- Mosin Nagant (TN_Nomad, CC-BY 4.0)
    Mount_AK_SideRail = { uid = "7715e1f8e89447f7a592738acda9e0d7" }, -- MTK-83 AK Mount (Low Poly) (Jawa, CC-BY 4.0)
    Muzzle_AK_Compensator = { uid = "748a35998fd14266a4ba8a4b88b30fdf" }, -- DTK-1 Zenit (Belonosoff, CC-BY 4.0)
    Muzzle_AK_Suppressor = { uid = "765c230ded3548fbad488adb08219947" }, -- Low-Poly PBS-1 suppressor (notcplkerry, CC-BY 4.0)
    NagantM1895 = { uid = "a43cda5dc44944fdb9acd5b9fb7f8a8b" },       -- Nagant M1895 Type Revolver (B Domeier, CC-BY 4.0)
    Optic_4x = { uid = "288607145bde4f549197f0059e59d9d9" },          -- ACOG Scope (STALKER, CC-BY 4.0) - ACOG
    Optic_Holo = { uid = "c201390e999143d08c209a45579292b5" },        -- Free - Holographic sight game ready (Karnaval, CC-BY 4.0)
    Optic_Hunting3x9 = { uid = "01124a41979d49248a3e50a5ac6e3d49" },  -- PBR Scope (Eric Wallbank, CC-BY 4.0)
    Optic_PSO1 = { uid = "423a3bd9e2344f26b3aff82e0ae185d7" },        -- PSO-1/ПСО-1 Sniper Scope Lowpoly Gamerea (valterjherson1, CC-BY 4.0)
    Optic_PU = { uid = "c6d7df8cbe954a64a3e5bcbc324255b3" },          -- Hensoldt Z-24 Scope (Low-Poly) (GoldbergR, CC-BY 4.0)
    Optic_Pistol_RMR = { uid = "a29f7326e13c454a9de1a027c74dd8ae" },  -- Crimson Trace CTS-1550 Red Dot Sight (Orshia 3D, CC-BY 4.0) - mini reflex
    Optic_RedDot = { uid = "feac84900cf549b0b174a138855a2386" },      -- Red Dot Sight (Nathan.Goodman, CC-BY 4.0)
    Optic_Rimfire4x = { uid = "01124a41979d49248a3e50a5ac6e3d49" },   -- PBR Scope (Eric Wallbank, CC-BY 4.0)
    Optic_Scope8x = { uid = "001a39a65b53467e9e337c8e2a411e62" },     -- Sniper Scope Rework [2K/1K] (Lyndschoko, CC-BY 4.0)
    PPSh41 = { uid = "089bdfb09ada407da3e75cfcbe2180fe" },            -- PPSh-41 (Artem Goyko, CC-BY 4.0)
    Rem700 = { uid = "d14f459bf31f47df887e107f86645318" },            -- Remington 700 Police Tactical (calico16, CC-BY 4.0)
    Rem870 = { uid = "05a6a02909ee4fcfa5cde3d76cb067f0", fix = { pca = true, stock_cut = -0.027 } }, -- Remington 870 Shotgun (Urpo, CC-BY 4.0) - tilted in its file
    RugerMkII = { uid = "9e6077d909a648e7b41f3559bb67f7e2" },         -- Ruger Standard .22lr (calico16, CC-BY 4.0)
    RugerRPR = { uid = "e520b234140049e7890db0b6c29d3925", fix = { cut_top = 0.33, stock_cut = -0.100, stock_grip = -0.120 } }, -- Sniper rifle GameReady Free (pashtetuser, CC-BY 4.0)
    RugerSuperRedhawk = { uid = "32a3140b7eee481d8863ad4ee5a62e28" }, -- Ruger Redhawk .44 Magnum Revolver (calico16, CC-BY 4.0)
    SIG_M17 = { uid = "e0c9faadfa3843ac8ecfd92b12b90e31" },           -- SIG SAUER M17 P320 (RBG_illustrations, CC-BY 4.0) - #5 had the magazine in the mesh
    SIG_P226 = { uid = "0d90f858e9f74c418ce3aae61cef9f4e" },          -- Low-Poly Sig P226 (TastyTony, CC-BY 4.0)
    SPAS12 = { uid = "c95154ea2348443e9195250a6ad122cb", fix = { stock_cut = -0.073, stock_grip = -0.115 } },            -- Low-Poly SPAS-12 (TastyTony, CC-BY 4.0)
    SR25 = { uid = "81976c51d61543a288cf135fd7485951", fix = { stock_cut = -0.110 } },              -- Low-Poly SR-25 (TastyTony, CC-BY 4.0)
    SVD = { uid = "7281b0f78e6d439ab28a7728a69ae346" },               -- Svd Dragunov (Pieter Ferreira, CC-BY 4.0)
    SW_Model10 = { uid = "9e31d23389aa41b58d9663a2e925258b" },        -- Low Poly revolver (Blenderust, CC-BY 4.0)
    SW_Model29 = { uid = "f528be1ad2724d4a91c84e441c7ca16e", fix = { drop_loose = true } }, -- .44 Magnum (Netraraj, CC-BY 4.0)
    SW_Model500 = { uid = "e062ea69600e4bcdb047a74feaa5fe02" },       -- Magnum 500 S&W (Ika3D, CC-BY 4.0)
    Saiga12 = { uid = "1df13d99364849969c5e3126f89a7f68", fix = { stock_cut = -0.092 } },           -- Low-Poly Vepr-12 (TastyTony, CC-BY 4.0)
    SpringfieldProdigy = { uid = "f22ba4d0ca394e169499a6e2fb1e533d" }, -- Low poly Firearm: TTI Combat master 2011 (Marki, CC-BY 4.0)
    SteyrAUG = { uid = "dd8ffca1ab094999a2c332e7540e09ad" },          -- Steyr AUG (emmerick.opsomer, CC-BY 4.0)
    Suppressor_338 = { uid = "1b8252e497b74872a552f04c881ab69a" },    -- TGP-V 2 "Shelest" Suppressor/Silencer Lo (valterjherson1, CC-BY 4.0)
    Suppressor_AK74 = { uid = "6c39d299859944de9b6b36512fdf4f30" },   -- PBS-4 / ПБС-4 Rifle Silencer/Suppressor  (valterjherson1, CC-BY 4.0) - PBS style
    Suppressor_Pistol45 = { uid = "ea3d4260f122455285a28072473a88c1" }, -- USP-S Suppressor (zacheL, CC-BY 4.0)
    Suppressor_Pistol9 = { uid = "ea3d4260f122455285a28072473a88c1" }, -- USP-S Suppressor (zacheL, CC-BY 4.0)
    Suppressor_Rifle308 = { uid = "6c39d299859944de9b6b36512fdf4f30" }, -- PBS-4 / ПБС-4 Rifle Silencer/Suppressor  (valterjherson1, CC-BY 4.0)
    Suppressor_Rifle556 = { uid = "d509d49e3a7944a490dbe9becd9fadf7" }, -- AWC Thundertrap 308 Suppressor (8sianDude, CC-BY 4.0)
    Suppressor_Rimfire = { uid = "2697ccda6f8842828f833a7292cb68d9" }, -- Makarov Pistol Silencer (Coozy, CC-BY 4.0)
    TaurusJudge = { uid = "14da356b624a4557a47a3f5b87b23084" },       -- Low-Poly Taurus Raging Judge (TastyTony, CC-BY 4.0)
    ThompsonM1928 = { uid = "5fe11dfebf734b4aa49c43545397abd1", fix = { stock_cut = -0.113 } },     -- Thompson submachine gun (Artem Goyko, CC-BY 4.0)
    TokarevTT33 = { uid = "e96197a0a9ed46b6aa74757b6ff4c2da" },       -- TT33 Tokarev Pistol (White-Horse, CC-BY 4.0)
    UMP45 = { uid = "e359178a2e30407cbeb5896986412922", fix = { stock_cut = false, flip = "xz" } },             -- ump45 (bachiri87, CC-BY 4.0)
    Uzi = { uid = "4b585cdf292d4f0798ce40f0d5ff2507" },               -- Low-Poly Mini Uzi (TastyTony, CC-BY 4.0)
    WaltherPPK = { uid = "6e2362c3e9894659abf5fa8bcfd7057b" },        -- Walther PPK (hoschu, CC-BY 4.0)
    Win70 = { uid = "4ce2fdd163d942ee822eb4380f2ac512" },             -- Winchester Model 70 Youth (calico16, CC-BY 4.0)
}
