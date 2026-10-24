--[[
    Offline tests for the pure-logic part of ZE Guns Of Bohemia (factory, rules, stats).
    Run from the ZEGunsOfBohemia folder with any Lua 5.1:
        lua tests/run_tests.lua
]]
package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/shared/?.lua;" .. package.path

require "ZGB/ZGB_Core"
require "ZGB/ZGB_Mode"
require "ZGB/Defs/ZGB_Def_Parts"
require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/ZGB_Attachments"
require "ZGB/ZGB_Stats"
require "ZGB/ZGB_ScriptApply"

local R, WF, PF = ZGB.Attachments, ZGB.WeaponFactory, ZGB.PartFactory
local passed, failed = 0, 0
local function test(name, fn)
    local ok, e = pcall(fn)
    if ok then passed = passed + 1; print("  ok   " .. name)
    else failed = failed + 1; print("  FAIL " .. name .. "\n       " .. tostring(e)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

local ak, glock, m590 = WF.get("AK47"), WF.get("Glock17"), WF.get("M590")

print("factory")
test("all example weapons registered", function() eq(#WF.all(), 3); eq(#WF.errors, 0) end)
test("maxAmmo derived from magazine", function() eq(ak.maxAmmo, 30); eq(glock.maxAmmo, 17) end)
test("tube-fed uses internalCapacity", function() eq(m590.maxAmmo, 8) end)
test("archetype defaults merged, overrides win", function()
    eq(ak.stats.recoilDelay, 16); eq(ak.stats.range, 20); eq(ak.twoHanded, true)
end)
test("mag-fed gun without magazine is rejected", function()
    local spec, errs = WF.define{ id = "BadGun", archetype = "assault_rifle", displayName = "x", caliber = "9x19" }
    eq(spec, nil); assert(#errs > 0)
    WF.errors = {}
end)
test("bad magazine capacity is rejected", function()
    local spec = WF.define{ id = "BadGun2", archetype = "pistol", displayName = "x", caliber = "9x19",
                            magazine = { item = "m", capacity = 7.5 } }
    eq(spec, nil); WF.errors = {}
end)
test("unknown archetype is rejected", function()
    eq(WF.define{ id = "B3", archetype = "railgun", displayName = "x", caliber = "9x19" }, nil); WF.errors = {}
end)

print("attachment rules")
test("red dot on bare AK -> needs side mount", function()
    local ok, reason, info = R.canAttach(ak, {}, "Optic_RedDot")
    eq(ok, false); eq(reason, "needs"); eq(info.chains[1][1], "ZGB.Mount_AK_SideRail")
end)
test("mount attaches to side_mount", function()
    local ok, slot = R.canAttach(ak, {}, "Mount_AK_SideRail"); eq(ok, true); eq(slot, "side_mount")
end)
test("after mount, red dot goes on optic_rail", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    local ok, slot = R.canAttach(ak, att, "Optic_RedDot"); eq(ok, true); eq(slot, "optic_rail")
end)
test("second optic -> occupied", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    att = R.attach(ak, att, "Optic_RedDot")
    local ok, reason, info = R.canAttach(ak, att, "Optic_4x")
    eq(ok, false); eq(reason, "occupied"); eq(info.by, "ZGB.Optic_RedDot")
end)
test("can't remove mount while optic is on it", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    att = R.attach(ak, att, "Optic_RedDot")
    local ok, reason, info = R.canDetach(ak, att, "side_mount")
    eq(ok, false); eq(reason, "has_children"); eq(info.children[1].part, "ZGB.Optic_RedDot")
end)
test("remove optic then mount works", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    att = R.attach(ak, att, "Optic_RedDot")
    att = R.detach(ak, att, "optic_rail")
    local nextAtt, removed = R.detach(ak, att, "side_mount")
    eq(removed, "ZGB.Mount_AK_SideRail"); eq(next(nextAtt), nil)
end)
test("grip: Glock direct, AK needs quad-rail handguard", function()
    eq((R.canAttach(glock, {}, "Grip_Vertical")), true)
    local ok, reason, info = R.canAttach(ak, {}, "Grip_Vertical")
    eq(reason, "needs"); eq(info.chains[1][1], "ZGB.Handguard_AK_Quad")
end)
test("AK suppressor incompatible with Glock", function()
    local _, reason = R.canAttach(glock, {}, "Muzzle_AK_Suppressor"); eq(reason, "incompatible")
    eq(R.isCompatible(glock, "Muzzle_AK_Suppressor"), false)
end)
test("two-step chain is discovered (adapter -> mount -> optic)", function()
    PF.define{ id = "T_Adapter", displayName = "t", kind = "t_kind", interface = "ak_dovetail",
               provides = { t_slot = { kind = "mount", accepts = { "t_iface" } } } }
    PF.define{ id = "T_Mount", displayName = "t", kind = "mount", interface = "t_iface",
               provides = { t_optic = { kind = "optic", accepts = { "t_optic_if" } } } }
    PF.define{ id = "T_Optic", displayName = "t", kind = "optic", interface = "t_optic_if" }
    -- AK side_mount accepts kind "mount" — T_Adapter is kind t_kind so it can't go there;
    -- give a fresh gun a slot for it:
    local gun = WF.define{ id = "TGun", archetype = "pistol", displayName = "t", caliber = "9x19",
        magazine = { item = "m", capacity = 5 }, slots = { a = { kind = "t_kind", accepts = { "ak_dovetail" } } } }
    local _, reason, info = R.canAttach(gun, {}, "T_Optic")
    eq(reason, "needs"); eq(info.chains[1][1], "ZGB.T_Adapter"); eq(info.chains[1][2], "ZGB.T_Mount")
end)
test("sanitize drops orphans", function()
    local clean, removed = R.sanitize(ak, { optic_rail = "ZGB.Optic_RedDot", muzzle = "ZGB.Muzzle_AK_Suppressor" })
    eq(clean.optic_rail, nil); eq(clean.muzzle, "ZGB.Muzzle_AK_Suppressor"); eq(removed[1], "ZGB.Optic_RedDot")
end)

print("ui tree")
test("bare AK shows ghost optic rail under the mount", function()
    local rows, sawGhost = R.buildTree(ak, {}), false
    for _, r in ipairs(rows) do
        if r.kind == "slot" and r.slotId == "optic_rail" and r.state == "ghost" and r.via == "ZGB.Mount_AK_SideRail" then sawGhost = true end
    end
    assert(sawGhost, "ghost optic slot missing")
end)
test("with mount installed optic rail is live", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    for _, r in ipairs(R.buildTree(ak, att)) do
        if r.kind == "slot" and r.slotId == "optic_rail" then eq(r.state, "open"); return end
    end
    error("no optic row")
end)

print("stats")
test("stats recomputed, not accumulated", function()
    local att = R.attach(ak, {}, "Mount_AK_SideRail")
    att = R.attach(ak, att, "Optic_RedDot")
    local a = ZGB.Stats.compute(ak, att)
    local b = ZGB.Stats.compute(ak, att)
    eq(a.aimTime, b.aimTime); eq(a.aimTime, ak.stats.aimTime - 4)
end)
test("suppressor cuts sound radius", function()
    local s = ZGB.Stats.compute(ak, { muzzle = "ZGB.Muzzle_AK_Suppressor" })
    assert(s.soundRadius < ak.stats.soundRadius)
end)
test("clamps hold", function()
    PF.define{ id = "T_Silly", displayName = "t", kind = "sling", interface = "sling_loop", mods = { add = { hitChance = 999 } } }
    eq(ZGB.Stats.compute(ak, { sling = "ZGB.T_Silly" }).hitChance, 100)
end)

print("script params")
test("weapon script gets capacity, mag and anims from provider", function()
    local params = {}
    for _, kv in ipairs(ZGB.ScriptApply.paramsFor(ak, { SwingAnim = "Rifle" })) do params[kv[1]] = kv[2] end
    eq(params.MaxAmmo, 30); eq(params.MagazineType, "ZGB.AK47_Mag30"); eq(params.SwingAnim, "Rifle")
end)

print("mode gate")
test("second, different provider is refused", function()
    local f = function() return {} end
    eq(ZGB.Mode.registerProvider{ name = "iso", getAnimParams = f }, true)
    eq(ZGB.Mode.registerProvider{ name = "fp",  getAnimParams = f }, false)
    eq(ZGB.Mode.providerName, "iso")
end)

print("magazines")
require "ZGB/ZGB_Magazines"
local M = ZGB.Magazines
test("AK lists default + drum, default first", function()
    local l = M.list(ak); eq(#l, 2); eq(l[1].item, "ZGB.AK47_Mag30"); eq(l[2].item, "ZGB.AK47_Drum75")
end)
test("capacity follows loaded mag, default otherwise", function()
    eq(M.capacityFor(ak, "ZGB.AK47_Drum75"), 75); eq(M.capacityFor(ak, nil), 30)
    eq(M.capacityFor(ak, "ZGB.Glock17_Mag33"), 30, "foreign mag ignored:")
end)
test("Glock mag not accepted by AK", function() eq(M.accepts(ak, "ZGB.Glock17_Mag17"), false) end)
test("tube-fed shotgun has no magazines", function() eq(#M.list(m590), 0); eq(M.capacityFor(m590, nil), 8) end)
test("chooseBest: most rounds wins, empties skipped", function()
    local best = M.chooseBest(ak, {
        { fullType = "ZGB.AK47_Mag30", ammo = 30 },
        { fullType = "ZGB.AK47_Drum75", ammo = 41 },
        { fullType = "ZGB.AK47_Drum75", ammo = 0 },
    }, "ZGB.AK47_Mag30")
    eq(best.fullType, "ZGB.AK47_Drum75"); eq(best.ammo, 41)
end)
test("chooseBest: tie keeps current type", function()
    local best = M.chooseBest(ak, { { fullType = "ZGB.AK47_Mag30", ammo = 20 },
                                    { fullType = "ZGB.AK47_Drum75", ammo = 20 } }, "ZGB.AK47_Drum75")
    eq(best.fullType, "ZGB.AK47_Drum75")
end)
test("chooseBest: nothing loaded -> nil", function()
    eq(M.chooseBest(ak, { { fullType = "ZGB.AK47_Mag30", ammo = 0 } }, nil), nil)
end)
test("drum penalty only while loaded", function()
    local base = ZGB.Stats.compute(ak, {}, "ZGB.AK47_Mag30")
    local drum = ZGB.Stats.compute(ak, {}, "ZGB.AK47_Drum75")
    eq(drum.aimTime, base.aimTime + 6)
    assert(math.abs(drum.weight - (base.weight + 1.4)) < 1e-9)
end)
test("duplicate magazine rejected", function()
    eq(WF.define{ id = "Dup", archetype = "pistol", displayName = "x", caliber = "9x19",
        magazine = { item = "m", capacity = 5 }, altMagazines = { { item = "m", capacity = 9 } } }, nil)
    WF.errors = {}
end)
test("bad alt capacity rejected", function()
    eq(WF.define{ id = "Dup2", archetype = "pistol", displayName = "x", caliber = "9x19",
        magazine = { item = "m", capacity = 5 }, altMagazines = { { item = "m2", capacity = 0 } } }, nil)
    WF.errors = {}
end)

print("loot")
test("vanilla guns replaced, drums added at reduced weight", function()
    package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/server/?.lua;" .. package.path
    ProceduralDistributions = { list = { GunStore = { items = { "Pistol", 10, "556Clip", 20, "Axe", 5 },
                                                     junk = { items = { "Base.AssaultRifle", 2 } } } } }
    require "ZGB/ZGB_Distributions"
    ZGB.Distributions.apply()
    local items = ProceduralDistributions.list.GunStore.items
    eq(items[1], "ZGB.Glock17"); eq(items[3], "ZGB.AK47_Mag30"); eq(items[5], "Axe")
    eq(items[7], "ZGB.AK47_Drum75"); assert(math.abs(items[8] - 3) < 1e-9)
    eq(ProceduralDistributions.list.GunStore.junk.items[1], "ZGB.AK47")
end)

print("ammo")
require "ZGB/ZGB_Ammo"
local AC, AM = ZGB.AmmoCatalog, ZGB.Ammo
test("gun ammo derived from caliber; vanilla item reused for standard 9mm", function()
    eq(glock.ammo, "Base.Bullets9mm"); eq(ak.ammo, "ZGB.Ammo_762x39_FMJ"); eq(m590.ammo, "Base.ShotgunShells")
end)
test("unknown caliber rejected", function()
    eq(WF.define{ id = "X1", archetype = "pistol", displayName = "x", caliber = "50bmg",
                  magazine = { item = "m", capacity = 5 } }, nil); WF.errors = {}
end)
test("realistic variant sets", function()
    local function keys(c) local t = {} for _, v in ipairs(AC.variantsFor(c)) do t[v.key] = true end return t end
    local k45, k556, k22 = keys("45acp"), keys("556x45"), keys("22lr")
    assert(not k45.subsonic and not k45.ap, ".45: no subsonic/AP")
    assert(k556.ap and k556.tracer and k556.sp, "5.56: AP/tracer/SP")
    assert(not k22.ap and not k22.tracer, ".22: no AP/tracer")
end)
test(".22 HP is weaker than 9mm HP (per-caliber override)", function()
    local function hp(c) for _, v in ipairs(AC.variantsFor(c)) do if v.key == "hp" then return v end end end
    assert(hp("22lr").mods.mul.maxDamage < hp("9x19").mods.mul.maxDamage)
end)
test("reverse lookup item -> variant", function()
    local v = AC.variantOfItem("ZGB.Ammo_762x39_AP"); eq(v.caliber, "762x39"); eq(v.key, "ap")
    eq(AC.variantOfItem("Base.Bullets9mm").key, "fmj")
end)
test("caliberOf: gun, magazine, ammo", function()
    eq(AM.caliberOf("ZGB.AK47"), "762x39"); eq(AM.caliberOf("ZGB.AK47_Drum75"), "762x39")
    eq(AM.caliberOf("ZGB.Ammo_762x39_TRACER"), "762x39"); eq(AM.caliberOf("Base.Axe"), nil)
end)
test("magazines of caliber include drums", function()
    local l = AM.magazinesOfCaliber("762x39"); eq(#l, 2)
end)
local FMJ, AP = "ZGB.Ammo_762x39_FMJ", "ZGB.Ammo_762x39_AP"
local function mags() return {
    { ref = "A", capacity = 30, ammo = 0 },
    { ref = "B", capacity = 30, ammo = 25, variant = FMJ },
    { ref = "C", capacity = 30, ammo = 10, variant = AP },
    { ref = "D", capacity = 75, ammo = 0 },
} end
test("plan: tops off same type first, skips other type", function()
    local p = AM.planLoadAll(mags(), FMJ, 100)
    eq(p.loads[1].ref, "B"); eq(p.loads[1].count, 5)
    eq(p.loads[2].ref, "A"); eq(p.loads[2].count, 30)
    eq(p.loads[3].ref, "D"); eq(p.loads[3].count, 65)
    eq(p.total, 100); eq(p.skipped, 1)
end)
test("plan: AP tops off C, then empties", function()
    local p = AM.planLoadAll(mags(), AP, 30)
    eq(p.loads[1].ref, "C"); eq(p.loads[1].count, 20); eq(p.loads[2].ref, "A"); eq(p.loads[2].count, 10)
end)
test("menu: one ammo type -> one option", function()
    local o = AM.loadOptions("762x39", mags(), { [FMJ] = 40 })
    eq(#o, 1); eq(o[1].variant.key, "fmj"); eq(o[1].plan.total, 40)
end)
test("menu: several types -> one option each, catalog order", function()
    local o = AM.loadOptions("762x39", mags(), { [FMJ] = 40, [AP] = 15, ["ZGB.Ammo_762x39_TRACER"] = 0 })
    eq(#o, 2); eq(o[1].variant.key, "fmj"); eq(o[2].variant.key, "ap")
end)
test("menu: all mags full -> no option", function()
    local full = { { ref = "A", capacity = 30, ammo = 30, variant = FMJ } }
    eq(#AM.loadOptions("762x39", full, { [FMJ] = 50 }), 0)
end)
test("AP and slug change stats", function()
    local fmj = ZGB.Stats.compute(ak, {}, nil, FMJ)
    local ap  = ZGB.Stats.compute(ak, {}, nil, AP)
    assert(ap.critChance > fmj.critChance)
    local slug = ZGB.Stats.compute(m590, {}, nil, "ZGB.Ammo_12ga_SLUG")
    local buck = ZGB.Stats.compute(m590, {}, nil, "Base.ShotgunShells")
    eq(slug.projectileCount, 1); eq(buck.projectileCount, 5)
end)
test("foreign caliber ammo ignored by stats", function()
    local a = ZGB.Stats.compute(ak, {}, nil, "ZGB.Ammo_9x19_HP")
    eq(a.maxDamage, ak.stats.maxDamage)
end)
test("variant loot: rarer variants spawn next to standard ammo", function()
    ProceduralDistributions = { list = { Shelf = { items = { "Bullets9mm", 10, "556Bullets", 10 } } } }
    ZGB.Distributions.apply()
    local items, found = ProceduralDistributions.list.Shelf.items, {}
    for i = 1, #items, 2 do found[items[i]] = items[i + 1] end
    assert(found["ZGB.Ammo_9x19_HP"] and found["ZGB.Ammo_9x19_HP"] < 10, "9mm HP next to 9mm")
    assert(found["ZGB.Ammo_762x39_FMJ"], "7.62x39 anchored to 5.56")
    eq(found["ZGB.Ammo_22lr_FMJ"], nil)   -- no gun uses .22 yet
end)

print("ammo actions (mock inventory)")
package.path = "tests/?.lua;" .. package.path
package.preload["TimedActions/ISBaseTimedAction"] = function() end
local Mock = require "mock_game"
require "ZGB/ZGB_AmmoActions"
local function setup()
    local p = Mock.player()
    local mag30 = p.inv:add(Mock.item("ZGB.AK47_Mag30", { ammoType = FMJ }))
    local drum  = p.inv:add(Mock.item("ZGB.AK47_Drum75", { ammoType = FMJ }))
    local apMag = p.inv:add(Mock.item("ZGB.AK47_Mag30", { ammo = 10, ammoType = AP }))
    p.inv:AddItems(FMJ, 50); p.inv:AddItems(AP, 25)
    return p, mag30, drum, apMag
end
test("bridge sees mags and ammo counts", function()
    local p = setup()
    eq(#ZGB.Item.magazinesOfCaliberIn(p.inv, "762x39"), 3)
    local c = ZGB.Item.ammoCounts(p.inv, "762x39"); eq(c[FMJ], 50); eq(c[AP], 25)
end)
test("load all FMJ: fills 30rd then drum, skips AP mag, spends ammo", function()
    local p, mag30, drum, apMag = setup()
    ZGB.LoadAll.queueLoadAll(p, "762x39", FMJ); Mock.runQueue()
    eq(mag30.ammo, 30); eq(drum.ammo, 20); eq(apMag.ammo, 10); eq(apMag.ammoType, AP)
    eq(ZGB.Item.ammoCounts(p.inv, "762x39")[FMJ], 0)
end)
test("load all AP: tops off AP mag first", function()
    local p, mag30, drum, apMag = setup()
    ZGB.LoadAll.queueLoadAll(p, "762x39", AP); Mock.runQueue()
    eq(apMag.ammo, 30); eq(mag30.ammo, 5); eq(mag30.ammoType, AP); eq(drum.ammo, 0)
end)
test("action re-checks inventory at completion (no overspend)", function()
    local p, mag30 = setup()
    ZGB.LoadAll.queueLoadAll(p, "762x39", FMJ)
    for _ = 1, 45 do p.inv:RemoveOneOf(FMJ) end      -- ammo disappears before actions run
    Mock.runQueue()
    eq(mag30.ammo, 5)
end)
test("unload all returns rounds of the right type", function()
    local p, _, _, apMag = setup()
    ZGB.LoadAll.queueUnloadAll(p, "762x39"); Mock.runQueue()
    eq(apMag.ammo, 0); eq(ZGB.Item.ammoCounts(p.inv, "762x39")[AP], 35)
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
