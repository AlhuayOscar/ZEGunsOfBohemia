--[[
    model_sources.lua  —  real 3D models that replace placeholders.

    PACKS: where each source comes from, its license and who to credit. The
    downloads are NOT in the repo; put them under .cache/model_sources/
    (paths below) to rebuild. Only the converted models ship with the mod,
    and CREDITS.txt is generated from this table.

    MODELS: our asset id -> { pack, file [, object] [, fix] }
      file    path inside the pack folder
      object  for .blend files holding several models: the top-level object
      texture / maxFaces  (optional, also per pack, number or { gun = , part = }) baked
              texture size and face budget; detailed packs get more of both
      fix     alignment corrections found in the visual review:
                flip = "x" (muzzle was backwards), "y" (upside down), "z", or combinations
                swap = "yz" (up and side were swapped)

    The Blender step (tools/blender/import_models.py) turns each source to
    our axes, scales it to the placeholder's size, bakes its colours into the
    shared atlas and exports it to the placeholder's folder.
]]
local S = {}

-- Detailed (textured, game-ready) sources: 1024 px for a gun, enough for first person;
-- 512 for a part. Flat-colour low-poly packs bake fine at the 256 default.
local DETAILED = { texture = { gun = 1024, part = 512 }, maxFaces = { gun = 15000, part = 4000 } }

S.PACKS = {
    -- One model per author: the credit (title, author, license, url) of each comes from
    -- tools/sketchfab/credits.lua, written by tools/sketchfab/fetch.py when it downloads them.
    sketchfab = {
        title = "Sketchfab models (one credit per model, below)", author = "various", license = "CC-BY 4.0 / CC0 1.0",
        url = "https://sketchfab.com", dir = "sketchfab", perModel = true,
        texture = DETAILED.texture, maxFaces = DETAILED.maxFaces,
    },
    quaternius = {
        title = "Ultimate Gun Pack", author = "Quaternius", license = "CC0 1.0",
        url = "https://quaternius.itch.io/50-lowpoly-guns", dir = "quaternius/OBJ",   -- OBJ: Blender 5.2 crashes on some of the FBX files
    },
    cc0guns = {
        title = "Free CC0 Guns & Explosives Pack", author = "3DModelsCC0", license = "CC0 1.0",
        url = "https://3dmodelscc0.itch.io/free-cc0-guns-explosives-pack", dir = "cc0guns",
        texture = DETAILED.texture, maxFaces = DETAILED.maxFaces,
    },
    chilly = {
        title = "Low Poly Gun Models", author = "chilly-durango", license = "CC0 1.0",
        url = "https://chilly-durango.itch.io/low-poly-firearms", dir = "", file = "LowPolyFirearms.blend",
    },
    oga_attach = {
        title = "Lowpoly gun attachments", author = "FaizanDurrany (Faizan Durrani)", license = "CC-BY 3.0",
        url = "https://opengameart.org/content/lowpoly-gun-attachments", dir = "oga", file = "attachments.blend",
    },
    oga_reddot = {
        title = "Red dot sight", author = "Jean", license = "CC0 1.0",
        url = "https://opengameart.org/content/red-dot-sight", dir = "oga", file = "red_dot.blend",
    },
}

local function q(file, fix) return { pack = "quaternius", file = file .. ".obj", fix = fix } end
local function c(file, fix) return { pack = "cc0guns", file = file, fix = fix or { flip = "xz" } } end   -- this pack points backwards (turned 180 degrees about up)
local function ch(object, fix) return { pack = "chilly", object = object, fix = fix or { flip = "yz" } } end   -- this pack is upside down (turned 180 degrees about the barrel)
local function oa(object, fix) return { pack = "oga_attach", object = object, fix = fix } end

local SCOPE_CUT = { cut_top = 0.33 }   -- remove the top third of the height (the built-in scope)

-- Sketchfab model by uid (tools/sketchfab/picks.lua -> fetch.py). The credit is per model.
local SF = (function()
    local f = io.open("tools/sketchfab/credits.lua", "rb")
    if not f then return {} end
    f:close()
    return dofile("tools/sketchfab/credits.lua")
end)()
S.SKETCHFAB = SF
local function sf(uid, fix)
    local c = SF[uid]
    if not c then return nil end                  -- not downloaded yet: the older source stays
    local file = c.file:match("%.zip$") and (uid .. "/scene.gltf") or c.file
    return { pack = "sketchfab", file = file, fix = fix, uid = uid,
             credit = { title = c.title, author = c.author, license = c.license, url = c.url } }
end

S.MODELS = {
    -- ------------------------------------------------ guns: textured, detailed (3DModelsCC0)
    AK47      = c("AK-47/AK47.fbx", { flip = "xz", stock_cut = -0.148 }),   -- stock cut: read off the ruler profile
    M4A1      = c("M4A1/M4A1.fbx", { flip = "xz", stock_cut = -0.137, stock_grip = -0.165 }),
    MakarovPM = c("Pistol_MK/Makarov.fbx", { flip = "xz", exclude = { "Magazine" } }),   -- the file has a loose spare mag
    -- ------------------------------------------------ guns: named low-poly (chilly-durango)
    Colt1911    = ch("1911_Body"),       SteyrAUG   = ch("AUG_Body"),
    -- fifth in-game test: the chilly pumps came out white (M590) and twice too thick (Rem870)
    M590        = q("Shotgun_4"), Rem870   = q("Shotgun_3"),
    SW_Model10  = ch("Detective_Body"),  ColtPython = ch("Python_Body"),
    M14         = ch("M14_Body"),        UMP45      = ch("UMP_Body"),
    Uzi         = ch("UZI_Body"),        KrissVector = ch("Vector_Body"),
    Win1894     = ch("LongGun_Body"),
    -- ------------------------------------------------ guns: closest low-poly family match (Quaternius)
    AK74 = q("AssaultRifle_3"), IMI_Galil = q("AssaultRifle_1"), Saiga12 = q("AssaultRifle_5"),
    M16A2 = q("AssaultRifle2_1"), HK416 = q("AssaultRifle2_2"), Mk12SPR = q("AssaultRifle2_4"), SR25 = q("AssaultRifle2_2"),
    Beretta92FS = q("Pistol_1"), WaltherPPK = q("Pistol_1"), CZ75 = q("Pistol_2"), TokarevTT33 = q("Pistol_2"),
    DesertEagle = q("Pistol_3"), SIG_P226 = q("Pistol_4"),
    Glock17 = q("Pistol_5"), Glock19 = q("Pistol_5"), Glock18C = q("Pistol_5"), Glock21 = q("Pistol_5"), Glock22 = q("Pistol_5"),
    HK_USP45 = q("Pistol_6"), FN_FiveSeven = q("Pistol_6"), SIG_M17 = q("Pistol_6"),
    SW_686Plus = q("Revolver_1"), RugerGP100 = q("Revolver_2"), ColtSAA = q("Revolver_2"),
    SW_Model29 = q("Revolver_3"), SW_Model500 = q("Revolver_3"),
    ColtAnaconda = q("Revolver_4"), RugerSuperRedhawk = q("Revolver_4"),
    TaurusJudge = q("Revolver_5"), NagantM1895 = q("Revolver_5"),
    BenelliM4 = q("Shotgun_1"), Win1897 = q("Shotgun_2"),
    MP5A3 = q("SubmachineGun_4"), MAC10 = q("SubmachineGun_3"),
    -- bolt guns: the Quaternius snipers have the scope in the same mesh; cut it off (scopes are attachments)
    Rem700 = q("SniperRifle_1", SCOPE_CUT), Win70 = q("SniperRifle_6", SCOPE_CUT),
    MosinNagant = q("SniperRifle_6", SCOPE_CUT), Kar98k = q("SniperRifle_6", SCOPE_CUT),
    LeeEnfieldNo4 = q("SniperRifle_2", SCOPE_CUT), AI_AWM = q("SniperRifle_3", SCOPE_CUT),
    RugerRPR = q("SniperRifle_4", SCOPE_CUT), BarrettM95 = q("SniperRifle_5", SCOPE_CUT),
    SVD = q("SniperRifle_2", SCOPE_CUT),
    -- the rest of the catalogue, closest family shape
    KSG = q("Bullpup_1"), FN_P90 = q("Bullpup_3"), AA12 = q("Shotgun_ShortStock"), CoachGun = q("Shotgun_SawedOff"),
    HK_G36 = q("AssaultRifle2_3"), ThompsonM1928 = q("SubmachineGun_1"), PPSh41 = q("SubmachineGun_2"),
    RugerMkII = q("Pistol_2"),
    Marlin336 = ch("LongGun_Body"), HenryBigBoy = ch("LongGun_Body"), Marlin1894 = ch("LongGun_Body"),
    HenryH001 = ch("LongGun_Body"), Marlin1895GG = ch("LongGun_Body"),
    -- more attachments from the same packs
    Optic_PSO1 = q("Accessories/Scope_2"), Optic_PU = q("Accessories/Scope_1"), Optic_Rimfire4x = q("Accessories/Scope_1"),

    -- ------------------------------------------------ attachments
    Suppressor_Rifle556 = q("Accessories/Silencer_1"), Suppressor_Rifle308 = q("Accessories/Silencer_long"),
    Muzzle_AK_Suppressor = q("Accessories/Silencer_2"), Suppressor_AK74 = q("Accessories/Silencer_2"),
    Suppressor_338 = q("Accessories/Silencer_long"), Suppressor_Pistol9 = q("Accessories/Silencer_Short"),
    Suppressor_Pistol45 = q("Accessories/Silencer_3"), Suppressor_Rimfire = q("Accessories/Silencer_Short"),
    Optic_Hunting3x9 = q("Accessories/Scope_1"), Optic_4x = q("Accessories/Scope_2"), Optic_Scope8x = q("Accessories/Scope_3"),
    Grip_Stubby = q("Accessories/Grip"), Light_Weapon = q("Accessories/Flashlight"),
    Bipod_Harris = q("Accessories/Tripod", { swap = { "xy", "xz" } }),   -- legs down, spread sideways
    Stock_AK_Folding = q("Accessories/Stock"),
    Optic_RedDot = oa("Cylinder.008"), Grip_Vertical = oa("Cylinder.003"),
    Light_Pistol = oa("Cylinder.001"), Laser_Rifle = oa("Cylinder"), Laser_Pistol = oa("Cylinder"),
    Optic_Holo = { pack = "oga_reddot", object = "Plane" },
}

-- Sketchfab picks replace the entries above once downloaded (tools/sketchfab/picks.lua:
-- our id -> { uid, fix found in the review }). Without a download nothing changes.
do
    local f = io.open("tools/sketchfab/picks.lua", "rb")
    if f then
        f:close()
        for id, pick in pairs(dofile("tools/sketchfab/picks.lua")) do
            local src = sf(pick.uid, pick.fix)
            if src then S.MODELS[id] = src end
        end
    end
end

return S
