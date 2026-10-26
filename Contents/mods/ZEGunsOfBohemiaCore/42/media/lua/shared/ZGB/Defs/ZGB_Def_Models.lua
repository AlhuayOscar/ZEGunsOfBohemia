--[[
    ZGB_Def_Models.lua  —  placeholder 3D models: gun shapes + per-gun sizes,
    and one model per attachment, magazine and casing.

    Sizes are real-world overall lengths (metres). Each gun picks a SHAPE
    family; the family builds the receiver, barrel, stock, grip, magazine and
    the generic attachment points (see ZGB_ModelFactory.SLOT_POINT).

    Prims can carry a `tag` ("stock", "handguard"): a part that replaces that
    piece lists it in `hides`, and the gun's variant model leaves it out.
]]
require "ZGB/Factory/ZGB_ModelFactory"
require "ZGB/Factory/ZGB_AmmoCatalog"

local MF = ZGB.ModelFactory
local box, boxc, cyl = MF.box, MF.boxc, MF.cyl

local function tag(p, t) p.tag = t; return p end
local function add(list, ...) for _, p in ipairs({ ... }) do list[#list + 1] = p end end

-- finish -> materials for the main body / furniture
local FINISH = {
    polymer = { body = "polymer", furn = "polymer", metal = "alloy" },
    wood    = { body = "blued",   furn = "wood",    metal = "blued" },
    steel   = { body = "steel",   furn = "rubber",  metal = "steel" },
    blued   = { body = "blued",   furn = "wood",    metal = "blued" },
    olive   = { body = "olive",   furn = "olive",   metal = "alloy" },
    tan     = { body = "tan",     furn = "tan",     metal = "alloy" },
}
local function mats(d) return FINISH[d.finish] or FINISH.polymer end

-- ================================================================ shapes
-- pistol: slide, frame, grip. d = { len, finish }
MF.defineShape("pistol", function(d)
    local f, L = mats(d), d.len
    local p = {}
    add(p, box(f.body, -0.045, 0.0, -0.013, L - 0.045, 0.034, 0.013),            -- slide
           box(f.furn == "wood" and "polymer" or f.furn, -0.035, -0.013, -0.012, L - 0.075, 0.0, 0.012),  -- frame
           box(f.furn == "wood" and "polymer" or f.furn, -0.048, -0.115, -0.014, -0.006, -0.005, 0.014),  -- grip
           box("steel", -0.004, -0.035, -0.003, 0.05, -0.030, 0.003),             -- trigger guard
           cyl("steel", "x", L - 0.046, 0.019, 0, 0.004, 0.0065))                 -- muzzle crown
    local m = { prims = p, points = {
        top = { 0.02, 0.034, 0 }, side = { 0.02, 0.02, -0.013 }, under = { L * 0.5 - 0.03, -0.013, 0 },
        muzzle = { L - 0.042, 0.019, 0 }, handguard = { L * 0.5, 0, 0 }, stock = { -0.048, -0.05, 0 },
        sling = { -0.03, -0.115, 0 }, receiver_side = { 0.02, 0.02, 0.013 }, butt = { -0.048, -0.06, 0 },
        butt_side = { -0.048, -0.06, 0.014 }, mag = { -0.027, -0.115, 0 } } }
    return m
end)

-- revolver: frame, cylinder, barrel, grip. d = { len, finish }
MF.defineShape("revolver", function(d)
    local f, L = mats(d), d.len
    local p = {}
    add(p, box(f.body, -0.03, -0.005, -0.012, 0.055, 0.045, 0.012),               -- frame
           cyl(f.body, "x", 0.0, 0.022, 0, 0.045, 0.019),                          -- cylinder
           cyl(f.body, "x", 0.055, 0.03, 0, L - 0.12, 0.009),                      -- barrel
           box(f.body, 0.055, 0.016, -0.006, L - 0.065, 0.03, 0.006),              -- ejector shroud
           box(f.furn, -0.05, -0.11, -0.015, -0.012, -0.004, 0.015),               -- grip
           box("steel", -0.004, -0.03, -0.003, 0.03, -0.025, 0.003))
    return { prims = p, points = {
        top = { 0.03, 0.047, 0 }, side = { 0.02, 0.03, -0.012 }, under = { L * 0.5 - 0.03, 0.012, 0 },
        muzzle = { L - 0.065, 0.03, 0 }, handguard = { 0.055, 0.03, 0 }, stock = { -0.05, -0.05, 0 },
        sling = { -0.04, -0.11, 0 }, receiver_side = { 0.02, 0.03, 0.012 }, butt = { -0.05, -0.06, 0 },
        butt_side = { -0.05, -0.06, 0.015 }, mag = { 0.02, 0.022, 0 } } }
end)

--[[ long gun, shared by rifles / SMGs / DMRs / box-fed shotguns.
     d = { len, finish, style = "ar"|"ak"|"battle"|"smg", stock = "fixed"|"buffer"|"folded"|"none",
           stockLen, hg (handguard length), mag = "curved"|"straight"|"none"|"grip", carry = bool,
           rail = bool (flat-top rail), bore (barrel radius) } ]]
local function longGun(d)
    local f = mats(d)
    local stockLen = d.stockLen or ((d.stock == "none") and 0.0 or 0.30)
    local rear = -0.08 - stockLen
    local muzzleX = rear + d.len
    local recvFront = d.recv or 0.20
    local hgEnd = math.max(recvFront + 0.05, math.min(muzzleX - 0.07, recvFront + (d.hg or 0.30)))
    local p = {}
    add(p, box(f.body, -0.08, 0.0, -0.022, recvFront, 0.07, 0.022),                -- receiver
           box(f.furn == "wood" and "polymer" or f.furn, -0.048, -0.10, -0.015, -0.008, 0.0, 0.015),  -- pistol grip
           box(f.metal, -0.005, -0.032, -0.003, 0.065, -0.027, 0.003),             -- trigger guard
           tag(box(f.furn, recvFront, 0.018, -0.026, hgEnd, 0.072, 0.026), "handguard"),
           cyl("steel", "x", recvFront, 0.045, 0, muzzleX - recvFront, d.bore or 0.010))
    if d.style == "ak" or d.style == "battle" then
        add(p, box("steel", muzzleX - 0.07, 0.055, -0.004, muzzleX - 0.055, 0.085, 0.004))   -- front sight post
        add(p, box(f.body, -0.08, 0.07, -0.018, 0.12, 0.085, 0.018))                         -- dust cover
    end
    if d.carry then add(p, box("alloy", -0.02, 0.07, -0.008, 0.15, 0.12, 0.008)) end
    if d.rail then add(p, box("alloy", -0.07, 0.07, -0.011, recvFront - 0.005, 0.08, 0.011)) end
    if d.stock == "fixed" then
        add(p, tag(box(f.furn, rear, -0.07, -0.02, -0.08, 0.06, 0.02), "stock"))
    elseif d.stock == "buffer" then
        add(p, tag(cyl("alloy", "x", rear + 0.10, 0.045, 0, -0.08 - (rear + 0.10), 0.015), "buffer"))
        -- the stock that slides on the tube: a part of its own (the gun's factory stock); the tube stays
        add(p, tag(box(f.furn, rear, -0.06, -0.02, rear + 0.17, 0.065, 0.02), "stock"))
    elseif d.stock == "folded" then
        add(p, tag(box("steel", -0.08, 0.005, 0.022, recvFront - 0.02, 0.02, 0.03), "stock"))
    end
    local magX = d.magX or 0.05
    if d.mag == "curved" then
        add(p, box(d.magMat or f.body, magX, -0.15, -0.013, magX + 0.075, 0.0, 0.013),
               box(d.magMat or f.body, magX + 0.03, -0.2, -0.013, magX + 0.1, -0.13, 0.013))
    elseif d.mag == "straight" then
        add(p, box(d.magMat or f.body, magX, -0.17, -0.013, magX + 0.065, 0.0, 0.013))
    elseif d.mag == "grip" then
        add(p, box("steel", -0.045, -0.13, -0.012, -0.012, -0.10, 0.012))   -- mag base under the grip
    end
    local points = {
        top = { 0.04, d.rail and 0.08 or 0.07, 0 }, side = { 0.05, 0.045, -0.022 },
        under = { recvFront + (hgEnd - recvFront) * 0.45, 0.018, 0 }, handguard = { recvFront, 0.045, 0 },
        muzzle = { muzzleX, 0.045, 0 }, stock = { -0.08, 0.045, 0 }, sling = { rear + 0.06, -0.02, 0 },
        receiver_side = { 0.06, 0.035, 0.022 }, butt = { rear, 0.0, 0 }, butt_side = { rear + 0.12, 0.0, 0.02 },
        mag = { magX + 0.035, 0, 0 },
    }
    if d.carry then points.top = { 0.06, 0.12, 0 } end
    return { prims = p, points = points }
end
MF.defineShape("rifle", longGun)
MF.defineShape("smg", function(d)
    -- no stock = no stock length (the MAC10 got an invisible 25 cm one: muzzle behind the grip)
    d = ZGB.merge({ recv = 0.14, hg = 0.14, stockLen = (d.stock == "none") and 0.0 or 0.25, style = "smg" }, d)
    return longGun(d)
end)

-- bullpup: grip forward, magazine behind it, stock built into the receiver. d = { len, finish, mag }
MF.defineShape("bullpup", function(d)
    local f = mats(d)
    local rear = -0.40
    local muzzleX = rear + d.len
    local front = 0.16
    local p = {}
    add(p, box(f.body, rear, -0.03, -0.028, front, 0.075, 0.028),                  -- body + butt
           box(f.furn == "wood" and "polymer" or f.furn, -0.045, -0.10, -0.015, -0.008, -0.03, 0.015),
           cyl("steel", "x", front, 0.045, 0, math.max(0.04, muzzleX - front), d.bore or 0.010))
    if d.mag ~= "top" then
        add(p, box(d.magMat or f.body, -0.20, -0.17, -0.013, -0.13, -0.03, 0.013))
    else
        add(p, box("glass", -0.25, 0.075, -0.02, 0.10, 0.095, 0.02))               -- P90 top magazine
    end
    if d.optic then add(p, cyl("polymer", "x", -0.08, 0.10, 0, 0.18, 0.018)) end
    return { prims = p, points = {
        top = { 0.0, 0.075, 0 }, side = { 0.0, 0.04, -0.028 }, under = { 0.08, -0.03, 0 },
        handguard = { front, 0.045, 0 }, muzzle = { muzzleX, 0.045, 0 }, stock = { rear, 0.02, 0 },
        sling = { rear + 0.05, -0.03, 0 }, receiver_side = { -0.1, 0.03, 0.028 }, butt = { rear, 0.02, 0 },
        butt_side = { rear + 0.08, 0.02, 0.028 }, mag = { -0.165, -0.03, 0 } } }
end)

-- bolt action: one-piece stock, round receiver, bolt handle. d = { len, finish, mag = "box"|nil }
MF.defineShape("bolt", function(d)
    local f = mats(d)
    local rear = -0.36
    local muzzleX = rear + d.len
    local stockEnd = 0.15 + (muzzleX - 0.15) * (d.forend or 0.6)
    local p = {}
    add(p, tag(box(f.furn, rear, -0.07, -0.022, -0.02, 0.035, 0.022), "stock"),    -- buttstock
           box(f.furn, -0.05, -0.10, -0.015, 0.0, 0.0, 0.015),                     -- wrist / grip
           box(f.furn, -0.02, 0.0, -0.022, stockEnd, 0.035, 0.022),                -- forend
           cyl(f.metal, "x", -0.04, 0.05, 0, 0.20, 0.017),                         -- receiver
           cyl("steel", "x", 0.16, 0.05, 0, muzzleX - 0.16, d.bore or 0.009),      -- barrel
           box("steel", 0.0, 0.035, 0.017, 0.012, 0.045, 0.06),                    -- bolt handle
           box("steel", 0.0, -0.03, -0.003, 0.06, -0.025, 0.003))                  -- trigger guard
    if d.mag == "box" then add(p, box(f.metal, 0.04, -0.07, -0.014, 0.12, 0.0, 0.014)) end
    return { prims = p, points = {
        top = { 0.06, 0.067, 0 }, side = { 0.05, 0.05, -0.017 }, under = { stockEnd - 0.08, 0.0, 0 },
        handguard = { 0.16, 0.05, 0 }, muzzle = { muzzleX, 0.05, 0 }, stock = { -0.02, 0.0, 0 },
        sling = { rear + 0.10, -0.06, 0 }, receiver_side = { 0.06, 0.04, 0.022 }, butt = { rear, -0.015, 0 },
        butt_side = { rear + 0.12, -0.015, 0.022 }, mag = { 0.08, 0, 0 } } }
end)

-- tube shotgun (pump / semi): receiver, barrel over magazine tube, forend. d = { len, finish, pump = bool }
MF.defineShape("shotgun", function(d)
    local f = mats(d)
    local rear = d.stock == "none" and -0.10 or -0.38
    local muzzleX = rear + d.len
    local p = {}
    add(p, box(f.body, -0.07, -0.005, -0.022, 0.17, 0.06, 0.022),                  -- receiver
           box(f.furn, -0.05, -0.10, -0.015, -0.005, 0.0, 0.015),                  -- wrist / grip
           cyl("steel", "x", 0.17, 0.045, 0, muzzleX - 0.17, 0.0115),              -- barrel
           cyl(f.metal, "x", 0.17, 0.018, 0, (muzzleX - 0.17) * (d.tube or 0.85), 0.011),  -- magazine tube
           box(f.furn, 0.24, 0.0, -0.022, 0.42, 0.04, 0.022),                      -- forend
           box("steel", -0.005, -0.032, -0.003, 0.06, -0.027, 0.003))
    if d.stock ~= "none" then add(p, tag(box(f.furn, rear, -0.075, -0.022, -0.05, 0.035, 0.022), "stock")) end
    return { prims = p, points = {
        top = { 0.05, 0.06, 0 }, side = { 0.05, 0.03, -0.022 }, under = { 0.33, 0.0, 0 },
        handguard = { 0.24, 0.02, 0 }, muzzle = { muzzleX, 0.045, 0 }, stock = { -0.05, 0.0, 0 },
        sling = { rear + 0.10, -0.06, 0 }, receiver_side = { 0.06, 0.03, 0.022 }, butt = { rear, -0.02, 0 },
        butt_side = { rear + 0.12, -0.02, 0.022 }, mag = { 0.3, 0.018, 0 } } }
end)

-- break action: side-by-side barrels. d = { len, finish }
MF.defineShape("break", function(d)
    local f = mats(d)
    local rear = -0.36
    local muzzleX = rear + d.len
    local p = {}
    add(p, box(f.body, -0.05, -0.005, -0.024, 0.06, 0.05, 0.024),
           box(f.furn, -0.05, -0.10, -0.015, -0.005, 0.0, 0.015),
           cyl("steel", "x", 0.06, 0.03, -0.0115, muzzleX - 0.06, 0.011),
           cyl("steel", "x", 0.06, 0.03, 0.0115, muzzleX - 0.06, 0.011),
           box(f.furn, 0.06, 0.0, -0.022, 0.26, 0.02, 0.022),
           tag(box(f.furn, rear, -0.075, -0.022, -0.05, 0.035, 0.022), "stock"))
    return { prims = p, points = {
        top = { 0.03, 0.05, 0 }, side = { 0.0, 0.03, -0.024 }, under = { 0.16, 0.0, 0 },
        handguard = { 0.06, 0.03, 0 }, muzzle = { muzzleX, 0.03, 0 }, stock = { -0.05, 0.0, 0 },
        sling = { rear + 0.10, -0.06, 0 }, receiver_side = { 0.0, 0.03, 0.024 }, butt = { rear, -0.02, 0 },
        butt_side = { rear + 0.12, -0.02, 0.022 }, mag = { 0.0, 0.0, 0 } } }
end)

-- lever action: receiver, lever loop, barrel over tube. d = { len, finish }
MF.defineShape("lever", function(d)
    local f = mats(d)
    local rear = -0.34
    local muzzleX = rear + d.len
    local p = {}
    add(p, box(f.body, -0.06, -0.005, -0.02, 0.12, 0.06, 0.02),
           box(f.furn, -0.05, -0.09, -0.015, -0.005, 0.0, 0.015),
           box("steel", -0.02, -0.06, -0.004, 0.10, -0.05, 0.004),                 -- lever loop bottom
           box("steel", 0.09, -0.06, -0.004, 0.10, 0.0, 0.004),                    -- lever loop front
           cyl("steel", "x", 0.12, 0.045, 0, muzzleX - 0.12, 0.009),
           cyl(f.metal, "x", 0.12, 0.022, 0, (muzzleX - 0.12) * 0.9, 0.008),
           box(f.furn, 0.12, 0.005, -0.019, 0.32, 0.04, 0.019),
           tag(box(f.furn, rear, -0.07, -0.02, -0.05, 0.035, 0.02), "stock"))
    return { prims = p, points = {
        top = { 0.03, 0.06, 0 }, side = { 0.03, 0.03, -0.02 }, under = { 0.22, 0.005, 0 },
        handguard = { 0.12, 0.03, 0 }, muzzle = { muzzleX, 0.045, 0 }, stock = { -0.05, 0.0, 0 },
        sling = { rear + 0.10, -0.06, 0 }, receiver_side = { 0.03, 0.03, 0.02 }, butt = { rear, -0.015, 0 },
        butt_side = { rear + 0.12, -0.015, 0.02 }, mag = { 0.2, 0.022, 0 } } }
end)

-- ================================================================ guns (overall length in metres)
local function G(id, shape, len, finish, extra)
    local d = { shape = shape, len = len, finish = finish }
    for k, v in pairs(extra or {}) do d[k] = v end
    MF.defineGun(id, d)
end
-- handguns
G("Glock17", "pistol", 0.186, "polymer");   G("Glock19", "pistol", 0.174, "polymer")
G("Glock18C", "pistol", 0.186, "polymer");  G("Beretta92FS", "pistol", 0.217, "steel")
G("SIG_P226", "pistol", 0.196, "steel");    G("CZ75", "pistol", 0.206, "steel")
G("SIG_M17", "pistol", 0.203, "tan");       G("Colt1911", "pistol", 0.216, "steel")
G("M45A1", "pistol", 0.216, "tan");           G("SpringfieldProdigy", "pistol", 0.216, "polymer")
G("Glock21", "pistol", 0.208, "polymer");   G("HK_USP45", "pistol", 0.219, "polymer")
G("Glock22", "pistol", 0.186, "polymer");   G("WaltherPPK", "pistol", 0.155, "steel")
G("RugerMkII", "pistol", 0.27, "steel");    G("MakarovPM", "pistol", 0.161, "blued")
G("TokarevTT33", "pistol", 0.196, "blued"); G("FN_FiveSeven", "pistol", 0.208, "polymer")
-- revolvers & hand cannons
G("SW_Model10", "revolver", 0.24, "blued");  G("ColtPython", "revolver", 0.29, "blued")
G("RugerGP100", "revolver", 0.24, "steel");  G("SW_686Plus", "revolver", 0.28, "steel")
G("SW_Model29", "revolver", 0.30, "blued");  G("ColtAnaconda", "revolver", 0.33, "steel")
G("ColtSAA", "revolver", 0.28, "blued");     G("TaurusJudge", "revolver", 0.24, "blued")
G("RugerSuperRedhawk", "revolver", 0.33, "steel"); G("SW_Model500", "revolver", 0.38, "steel")
G("NagantM1895", "revolver", 0.235, "blued"); G("DesertEagle", "pistol", 0.27, "steel")
-- assault rifles
G("AK47", "rifle", 0.88, "wood", { style = "ak", stock = "fixed", mag = "curved", hg = 0.22 })
G("AK74", "rifle", 0.94, "polymer", { style = "ak", stock = "fixed", mag = "curved", hg = 0.22, magMat = "tan" })
G("M16A2", "rifle", 1.00, "polymer", { style = "ar", stock = "fixed", mag = "straight", carry = true, hg = 0.30, magMat = "alloy" })
G("M4A1", "rifle", 0.84, "polymer", { style = "ar", stock = "buffer", stockLen = 0.26, mag = "straight", rail = true, hg = 0.18, magMat = "alloy" })
G("M4A4", "rifle", 0.84, "polymer", { style = "ar", stock = "buffer", stockLen = 0.26, mag = "straight", rail = true, hg = 0.18, magMat = "alloy" })
G("M4A1S", "rifle", 0.84, "polymer", { style = "ar", stock = "buffer", stockLen = 0.26, mag = "straight", rail = true, hg = 0.18, magMat = "alloy" })
G("HK416", "rifle", 0.90, "tan", { style = "ar", stock = "buffer", stockLen = 0.27, mag = "straight", rail = true, hg = 0.26, magMat = "polymer" })
G("SteyrAUG", "bullpup", 0.79, "olive", { optic = true })
G("IMI_Galil", "rifle", 0.98, "polymer", { style = "ak", stock = "folded", stockLen = 0.0, mag = "curved", hg = 0.22 })
G("HK_G36", "rifle", 1.00, "polymer", { style = "ar", stock = "fixed", mag = "straight", carry = true, hg = 0.25, magMat = "glass" })
-- DMRs
G("M14", "rifle", 1.12, "wood", { style = "battle", stock = "fixed", mag = "straight", hg = 0.38 })
G("SVD", "rifle", 1.22, "wood", { style = "battle", stock = "fixed", stockLen = 0.32, mag = "straight", hg = 0.30 })
G("SR25", "rifle", 1.12, "polymer", { style = "ar", stock = "buffer", stockLen = 0.30, mag = "straight", rail = true, hg = 0.38, bore = 0.012 })
G("Mk12SPR", "rifle", 0.96, "tan", { style = "ar", stock = "buffer", stockLen = 0.28, mag = "straight", rail = true, hg = 0.32 })
-- bolt actions
G("M24", "bolt", 1.09, "olive");   G("Rem700", "bolt", 1.06, "wood");  G("Win70", "bolt", 1.13, "wood")
G("MosinNagant", "bolt", 1.23, "wood", { forend = 0.85 }); G("Kar98k", "bolt", 1.11, "wood", { forend = 0.8 })
G("LeeEnfieldNo4", "bolt", 1.13, "wood", { forend = 0.85, mag = "box" })
G("AI_AWM", "bolt", 1.23, "olive", { mag = "box", bore = 0.011 }); G("RugerRPR", "bolt", 1.08, "polymer", { mag = "box", forend = 0.7 })
G("BarrettM95", "bullpup", 1.14, "polymer", { bore = 0.015 })
-- SMGs
G("MP5A3", "smg", 0.70, "polymer", { stock = "buffer", mag = "curved", magMat = "steel" })
G("Uzi", "smg", 0.64, "steel", { stock = "fixed", mag = "grip", hg = 0.12 })   -- stock out: the real model has it extended
G("MAC10", "smg", 0.30, "steel", { stock = "none", mag = "grip", recv = 0.12, hg = 0.04 })
G("ThompsonM1928", "smg", 0.85, "wood", { stock = "fixed", mag = "straight", hg = 0.14 })
G("UMP45", "smg", 0.69, "polymer", { stock = "folded", stockLen = 0.0, mag = "straight", rail = true })
G("FN_P90", "bullpup", 0.50, "polymer", { mag = "top" })
G("KrissVector", "smg", 0.62, "polymer", { stock = "buffer", mag = "straight", rail = true })
G("PPSh41", "smg", 0.84, "wood", { stock = "fixed", mag = "curved" })
-- shotguns
G("M590", "shotgun", 1.00, "polymer");   G("Rem870", "shotgun", 1.06, "wood")
G("SPAS12", "shotgun", 1.04, "polymer"); G("BenelliM4", "shotgun", 1.01, "polymer"); G("Saiga12", "rifle", 1.15, "polymer", { style = "ak", stock = "fixed", mag = "straight", bore = 0.012 })
G("KSG", "bullpup", 0.66, "polymer", { bore = 0.012 }); G("CoachGun", "break", 0.94, "wood")
G("Win1897", "shotgun", 1.00, "wood");    G("AA12", "rifle", 0.97, "polymer", { style = "ar", stock = "fixed", mag = "straight", rail = true, bore = 0.012 })
-- lever actions
G("Win1894", "lever", 0.96, "wood"); G("Marlin336", "lever", 0.97, "wood")
G("HenryBigBoy", "lever", 0.97, "wood"); G("Marlin1894", "lever", 0.91, "wood")
G("HenryH001", "lever", 0.93, "wood"); G("Marlin1895GG", "lever", 0.95, "steel")

-- ================================================================ attachments
local P = MF.definePart
local function M(prims, provides, extra)
    local m = { prims = prims, provides = provides or {} }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end
local function rail(len) return box("alloy", -len / 2, 0.0, -0.011, len / 2, 0.009, 0.011) end
local function tube(m, len, r, y) return cyl(m, "x", -len / 2, y, 0, len, r) end

-- optics (sit on top of their mount point)
P("Optic_RedDot",     function() return M{ rail(0.05), boxc("polymer", 0, 0.025, 0, 0.045, 0.03, 0.03), cyl("glass", "x", 0.02, 0.03, 0, 0.004, 0.011) } end)
P("Optic_Holo",       function() return M{ rail(0.08), boxc("polymer", 0, 0.025, 0, 0.09, 0.035, 0.035), boxc("glass", 0.03, 0.032, 0, 0.004, 0.025, 0.028) } end)
P("Optic_4x",         function() return M{ rail(0.06), boxc("polymer", 0, 0.03, 0, 0.06, 0.03, 0.03), tube("polymer", 0.14, 0.017, 0.035) } end)
P("Optic_Hunting3x9", function() return M{ rail(0.10), tube("blued", 0.31, 0.0127, 0.035), tube("blued", 0.06, 0.021, 0.035) } end)
P("Optic_Scope8x",    function() return M{ rail(0.12), tube("polymer", 0.36, 0.015, 0.04), cyl("polymer", "x", 0.10, 0.04, 0, 0.08, 0.026), cyl("polymer", "x", -0.18, 0.04, 0, 0.06, 0.02) } end)
P("Optic_Pistol_RMR", function() return M{ boxc("polymer", 0, 0.013, 0, 0.045, 0.026, 0.026), boxc("glass", 0.0, 0.018, 0, 0.004, 0.016, 0.02) } end)
P("Optic_PSO1",       function() return M{ boxc("steel", 0, 0.025, 0.012, 0.08, 0.05, 0.015), cyl("steel", "x", -0.18, 0.06, 0.03, 0.375, 0.016) } end)
P("Optic_PU",         function() return M{ cyl("blued", "x", -0.085, 0.01, 0, 0.17, 0.012) } end)
P("Optic_Rimfire4x",  function() return M{ tube("blued", 0.27, 0.0095, 0.025), boxc("blued", 0, 0.01, 0, 0.06, 0.02, 0.016) } end)

-- mounts (provide a new slot point)
P("Mount_AK_SideRail",    function() return M({ boxc("steel", 0.0, 0.0, 0.0, 0.09, 0.04, 0.008), boxc("steel", 0, 0.04, 0.012, 0.09, 0.012, 0.03), MF.translate({ rail(0.09) }, 0, 0.046, 0.022)[1] },
                                                { optic_rail = { 0, 0.055, 0.022 } }) end)
P("Mount_AR_CarryHandle", function() return M({ rail(0.10) }, { optic_rail = { 0, 0.009, 0 } }) end)
P("Mount_ScopeBase",      function() return M({ rail(0.12) }, { optic_rail = { 0, 0.009, 0 } }) end)
P("Mount_HK_Claw",        function() return M({ boxc("steel", 0, 0.012, 0, 0.10, 0.024, 0.03), MF.translate({ rail(0.10) }, 0, 0.024, 0)[1] }, { optic_rail = { 0, 0.033, 0 } }) end)
P("Mount_M14",            function() return M({ boxc("steel", 0, 0.02, 0.008, 0.10, 0.06, 0.012), MF.translate({ rail(0.12) }, 0, 0.05, 0.022)[1] }, { optic_rail = { 0, 0.059, 0.022 } }) end)
P("Mount_Mosin_PU",       function() return M({ boxc("blued", 0, 0.015, 0.006, 0.08, 0.03, 0.012), boxc("blued", 0, 0.035, 0.015, 0.06, 0.012, 0.03) }, { optic_mount = { 0, 0.05, 0.017 } }) end)
P("Mount_Ruger_Rings",    function() return M({ boxc("steel", -0.03, 0.008, 0, 0.012, 0.016, 0.03), boxc("steel", 0.03, 0.008, 0, 0.012, 0.016, 0.03), MF.translate({ rail(0.09) }, 0, 0.016, 0)[1] }, { optic_rail = { 0, 0.025, 0 } }) end)

-- handguards (replace the gun's own) and adapters
P("Handguard_AK_Quad",  function() return M({ box("polymer", 0.0, -0.028, -0.028, 0.21, 0.028, 0.028), box("alloy", 0.0, -0.036, -0.011, 0.21, -0.028, 0.011) },
                                            { under_rail = { 0.10, -0.036, 0 } }, { hides = { "handguard" } }) end)
P("Handguard_AR_Quad",  function() return M({ box("alloy", 0.0, -0.028, -0.028, 0.30, 0.028, 0.028), box("alloy", 0.0, -0.036, -0.011, 0.30, -0.028, 0.011) },
                                            { under_rail = { 0.14, -0.036, 0 } }, { hides = { "handguard" } }) end)
P("Handguard_MP5_Rail", function() return M({ box("alloy", 0.0, -0.026, -0.026, 0.14, 0.026, 0.026), box("alloy", 0.0, -0.034, -0.011, 0.14, -0.026, 0.011) },
                                            { under_rail = { 0.07, -0.034, 0 } }, { hides = { "handguard" } }) end)
P("Adapter_USP_Rail",   function() return M({ box("polymer", -0.025, -0.01, -0.012, 0.025, 0.0, 0.012) }, { under_rail = { 0, -0.01, 0 } }) end)
P("Adapter_HK_3Lug",    function() return M({ cyl("steel", "x", 0.0, 0.0, 0, 0.03, 0.012) }, { muzzle_thread = { 0.03, 0, 0 } }) end)

-- underbarrel (hang below their point)
P("Grip_Vertical", function() return M{ cyl("polymer", "y", 0, -0.10, 0, 0.10, 0.016) } end)
P("Grip_Angled",   function() return M{ box("polymer", -0.04, -0.035, -0.013, 0.04, 0.0, 0.013), box("polymer", -0.04, -0.045, -0.013, -0.02, -0.035, 0.013) } end)
P("Grip_Stubby",   function() return M{ cyl("polymer", "y", 0, -0.055, 0, 0.055, 0.017) } end)
P("Light_Weapon",  function() return M{ cyl("polymer", "x", -0.06, -0.022, 0, 0.12, 0.014), cyl("lens", "x", 0.06, -0.022, 0, 0.004, 0.015) } end)
P("Light_Pistol",  function() return M{ box("polymer", -0.03, -0.03, -0.014, 0.03, 0.0, 0.014), cyl("lens", "x", 0.03, -0.016, 0, 0.003, 0.012) } end)
P("Laser_Rifle",   function() return M{ box("tan", -0.04, -0.03, -0.017, 0.04, 0.0, 0.017), cyl("laser", "x", 0.04, -0.015, 0.006, 0.004, 0.004) } end)
P("Laser_Pistol",  function() return M{ box("polymer", -0.025, -0.022, -0.013, 0.025, 0.0, 0.013), cyl("laser", "x", 0.025, -0.012, 0, 0.003, 0.003) } end)
P("Bipod_Harris",  function() return M{ box("steel", -0.02, -0.02, -0.02, 0.02, 0.0, 0.02),
                                        box("steel", -0.006, -0.2, -0.05, 0.006, -0.02, -0.04), box("steel", -0.006, -0.2, 0.04, 0.006, -0.02, 0.05) } end)

-- muzzle devices (grow forward from the thread)
local function can(r, len, m) return function() return M{ cyl(m or "polymer", "x", 0, 0, 0, len, r) } end end
local function brake(r, len) return function() return M{ cyl("steel", "x", 0, 0, 0, len, r), boxc("steel", len * 0.5, 0, 0, len * 0.6, r * 0.8, r * 2.4) } end end
local function hider(r, len) return function() return M{ cyl("steel", "x", 0, 0, 0, len, r) } end end
P("Suppressor_Pistol9",   can(0.017, 0.17)); P("Suppressor_Pistol45", can(0.019, 0.19))
P("Suppressor_Rimfire",   can(0.013, 0.14)); P("Suppressor_Rifle556", can(0.020, 0.17))
P("Suppressor_Rifle308",  can(0.023, 0.20)); P("Muzzle_AK_Suppressor", can(0.022, 0.18, "steel"))
P("Suppressor_AK74",      can(0.021, 0.18, "steel")); P("Suppressor_338", can(0.025, 0.24))
P("Brake_Rifle556", brake(0.012, 0.055)); P("Brake_Rifle308", brake(0.014, 0.07))
P("Muzzle_AK_Compensator", brake(0.012, 0.07)); P("Brake_AK74", brake(0.012, 0.075))
P("FlashHider_556", hider(0.011, 0.055)); P("FlashHider_308", hider(0.013, 0.06))
P("Muzzle_AK_FlashHider", hider(0.011, 0.06)); P("Comp_Pistol9", function() return M{ box("steel", 0, -0.012, -0.013, 0.035, 0.015, 0.013) } end)

-- stocks (grow backward from the receiver)
P("Stock_AK_Folding",     function() return M({ box("steel", -0.25, 0.0, -0.004, 0.0, 0.01, 0.004), box("steel", -0.25, -0.06, -0.004, -0.23, 0.01, 0.004), box("steel", -0.25, -0.07, -0.004, 0.0, -0.06, 0.004) }) end)
P("Stock_AR_Collapsible", function() return M{ box("polymer", -0.26, -0.06, -0.019, -0.10, 0.03, 0.019), cyl("alloy", "x", -0.10, 0.0, 0, 0.10, 0.015) } end)
P("Stock_AR_Precision",   function() return M{ box("polymer", -0.32, -0.08, -0.022, -0.06, 0.04, 0.022), box("polymer", -0.20, 0.04, -0.015, -0.08, 0.06, 0.015) } end)
P("Stock_M590_PistolGrip",function() return M({ box("polymer", -0.32, -0.075, -0.022, 0.0, 0.035, 0.022), box("polymer", -0.04, -0.12, -0.015, 0.0, 0.0, 0.015) }) end)
P("Stock_870_Folding",    function() return M({ box("steel", -0.28, 0.0, -0.005, 0.0, 0.012, 0.005), box("steel", -0.28, -0.07, -0.005, -0.26, 0.012, 0.005) }) end)

-- shell holders, recoil pads, slings
local function shells(n, x0, y, z, axis)
    local out = {}
    for i = 0, n - 1 do out[#out + 1] = cyl("hull", axis or "y", x0 + i * 0.022, y, z, 0.06, 0.0095) end
    return out
end
P("Sidesaddle_Shotgun", function()
    local p = { box("polymer", -0.06, -0.025, 0.0, 0.07, 0.04, 0.006) }
    for _, s in ipairs(shells(6, -0.05, -0.02, 0.016)) do p[#p + 1] = s end
    return M(p)
end)
P("ShellHolder_Butt", function()
    local p = { box("nylon", -0.06, -0.04, 0.0, 0.06, 0.04, 0.006) }
    for _, s in ipairs(shells(5, -0.045, -0.03, 0.016)) do p[#p + 1] = s end
    return M(p)
end)
P("RecoilPad_Rubber", function() return M{ box("rubber", -0.025, -0.075, -0.024, 0.0, 0.04, 0.024) } end)
P("Sling_2Point", function() return M{ box("nylon", 0.0, -0.10, -0.012, 0.45, -0.09, 0.012), box("steel", 0.0, -0.09, -0.004, 0.01, 0.0, 0.004) } end)
P("Sling_1Point", function() return M{ box("nylon", -0.005, -0.20, -0.012, 0.005, 0.0, 0.012) } end)

-- ================================================================ magazines and casings
local MAG_SIZE = {      -- caliber group -> round thickness / cartridge length (metres)
    pistol = { 0.0028, 0.032 }, revolver = { 0.0035, 0.04 }, rifle = { 0.0028, 0.065 },
    full_rifle = { 0.0035, 0.075 }, magnum_rifle = { 0.0045, 0.095 }, shotgun = { 0.010, 0.07 },
}
MF.magazineBuilder = function(mag)
    local cal = ZGB.AmmoCatalog.CALIBERS[mag.caliber]
    local s = MAG_SIZE[cal and cal.group or "rifle"] or MAG_SIZE.rifle
    local body = (cal and cal.group == "rifle" or cal and cal.group == "full_rifle") and "steel" or "polymer"
    if mag.tier == "drum" then
        if string.find(mag.id, "CMag", 1, true) then   -- twin drum
            return M{ cyl(body, "z", 0, -0.06, -0.06, 0.03, 0.055), cyl(body, "z", 0, -0.06, 0.03, 0.03, 0.055),
                      box(body, -0.012, -0.05, -0.03, 0.012, 0.0, 0.03) }
        end
        local r = 0.04 + math.min(0.04, mag.capacity * 0.0006)
        return M{ cyl(body, "z", 0, -r - 0.03, -0.022, 0.044, r), box(body, -0.015, -0.035, -0.012, 0.015, 0.0, 0.012) }
    end
    local h = math.max(0.06, math.min(0.36, mag.capacity * s[1] + 0.02))
    return M{ box(body, -s[2] / 2, -h, -0.012, s[2] / 2, 0.0, 0.012), box("polymer", -s[2] / 2 - 0.003, -h - 0.006, -0.014, s[2] / 2 + 0.003, -h, 0.014) }
end

MF.casingBuilder = function(id, group)
    if group == "shotgun" then
        return M{ cyl("hull", "x", 0, 0, 0, 0.055, 0.0095), cyl("brass", "x", -0.012, 0, 0, 0.012, 0.0105) }
    end
    local len = (group == "full_rifle" or group == "magnum_rifle") and 0.06 or (group == "rifle" and 0.045 or 0.02)
    return M{ cyl("brass", "x", 0, 0, 0, len, 0.0055) }
end

-- fitted bounds of the real models (generated by tools/blender/import_models.py); absent until it has run
pcall(require, "ZGB/Defs/ZGB_Def_RealModels")
