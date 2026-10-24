--[[
    Offline tests for the pure-logic part of ZE Guns Of Bohemia (factory, rules, stats).
    Run from the ZEGunsOfBohemia folder with any Lua 5.1:
        lua5.1 tests/run_tests.lua
]]
package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/shared/?.lua;" .. package.path

require "ZGB/ZGB_Core"
require "ZGB/ZGB_Mode"
require "ZGB/Defs/ZGB_Def_Parts"
require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/ZGB_Attachments"
require "ZGB/ZGB_Stats"
require "ZGB/ZGB_ScriptApply"

local R, WF, PF, MF = ZGB.Attachments, ZGB.WeaponFactory, ZGB.PartFactory, ZGB.MagazineFactory
local passed, failed = 0, 0
local function test(name, fn)
    local ok, e = pcall(fn)
    if ok then passed = passed + 1; print("  ok   " .. name)
    else failed = failed + 1; print("  FAIL " .. name .. "\n       " .. tostring(e)) end
end
local function eq(a, b, msg) if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

local ak, glock, m590 = WF.get("AK47"), WF.get("Glock17"), WF.get("M590")

print("factory")
local function near(a, b, msg) if math.abs(a - b) > 1e-6 then error((msg or "") .. " expected " .. tostring(b) .. ", got " .. tostring(a), 2) end end

test("whole catalogue registers with no errors", function()
    eq(#WF.all(), 70); eq(#WF.errors, 0); eq(#MF.errors, 0); eq(#PF.errors, 0)
end)
test("catalogue counts per category", function()
    local want = { handgun = 16, revolver = 12, assault_rifle = 8, dmr = 4, sniper = 8, smg = 8, shotgun = 8, lever = 6 }
    local got = {}
    for _, s in ipairs(WF.all()) do got[s.category] = (got[s.category] or 0) + 1 end
    for cat, n in pairs(want) do eq(got[cat], n, cat .. ":") end
end)
test("maxAmmo derived from standard magazine", function() eq(ak.maxAmmo, 30); eq(glock.maxAmmo, 17) end)
test("tube-fed uses internalCapacity", function() eq(m590.maxAmmo, 8) end)
test("archetype defaults merged, overrides win", function()
    eq(ak.stats.recoilDelay, 16); eq(ak.stats.minDamage, 1.4); eq(ak.twoHanded, true)
end)
test("caliber scales stats the definition didn't set", function()
    local want = 20 * WF.caliberScale("range", "762x39", "556x45")
    near(ak.stats.range, math.floor(want * 100 + 0.5) / 100)
    eq(WF.caliberScale("range", "556x45", "556x45"), 1)
    local mk2, de = WF.get("RugerMkII"), WF.get("DesertEagle")
    assert(mk2.stats.maxDamage < glock.stats.maxDamage and glock.stats.maxDamage < de.stats.maxDamage,
           ".22 < 9mm < .50 AE")
end)
test("mag-fed gun without magazine is rejected", function()
    local spec, errs = WF.define{ id = "BadGun", archetype = "assault_rifle", displayName = "x", caliber = "9x19" }
    eq(spec, nil); assert(#errs > 0)
    WF.errors = {}
end)
test("unknown archetype is rejected", function()
    eq(WF.define{ id = "B3", archetype = "railgun", displayName = "x", caliber = "9x19" }, nil); WF.errors = {}
end)
test("internal-fed gun can't take magazines", function()
    eq(WF.define{ id = "B4", archetype = "revolver", displayName = "x", caliber = "38spl", internalCapacity = 6,
                  magazines = { standard = "Glock17_Mag17" } }, nil); WF.errors = {}
end)

print("magazine rules")
test("bad magazine capacity is rejected", function()
    eq(MF.define{ id = "TM1", displayName = "x", caliber = "9x19", tier = "standard", capacity = 7.5 }, nil); MF.errors = {}
end)
test("only three tiers exist", function()
    eq(MF.define{ id = "TM2", displayName = "x", caliber = "9x19", tier = "box", capacity = 10 }, nil); MF.errors = {}
end)
test("magazine of another caliber is rejected", function()
    local spec, errs = WF.define{ id = "B5", archetype = "pistol", displayName = "x", caliber = "45acp",
                                  magazines = { standard = "Glock17_Mag17" } }
    eq(spec, nil); assert(string.find(errs[1], "9x19", 1, true)); WF.errors = {}
end)
test("magazine in the wrong tier is rejected", function()
    eq(WF.define{ id = "B6", archetype = "pistol", displayName = "x", caliber = "9x19",
                  magazines = { standard = "Glock17_Mag17", drum = "Glock17_Mag33" } }, nil); WF.errors = {}
end)
test("every gun: at most one magazine per tier, all its own caliber", function()
    for _, s in ipairs(WF.all()) do
        local seen = {}
        assert(#s.magazines <= 3, s.id)
        for _, m in ipairs(s.magazines) do
            assert(not seen[m.tier], s.id .. " has two " .. m.tier); seen[m.tier] = true
            eq(m.caliber, s.caliber, s.id .. " " .. m.item .. ":")
        end
        if #s.magazines > 0 then eq(s.magazines[1].tier, "standard", s.id .. ":") end
    end
end)
test("shared magazines feed several guns", function()
    eq(#WF.gunsForMagazine("ZGB.STANAG_Mag30"), 4)
    local vector = WF.get("KrissVector")
    eq(vector.magazine.item, "ZGB.Glock21_Mag13")
end)
test("magazine ammo follows its caliber: no long-range .22", function()
    for _, v in ipairs(ZGB.AmmoCatalog.variantsFor(MF.get("MkII_Mag10").caliber)) do
        assert(v.key ~= "match", ".22 must not have a match load")
    end
end)

print("catalogue integrity")
test("every slot interface has a part that fits it", function()
    local offered = {}
    for _, p in ipairs(PF.all()) do offered[p.kind .. "/" .. p.interface] = true end
    local function check(owner, slotId, s)
        for _, i in ipairs(s.accepts) do
            if string.sub(i, 1, 2) ~= "t_" then
                assert(offered[s.kind .. "/" .. i], owner .. "." .. slotId .. " accepts " .. s.kind .. "/" .. i .. " but no part offers it")
            end
        end
    end
    for _, g in ipairs(WF.all()) do for id, s in pairs(g.slots) do check(g.id, id, s) end end
    for _, p in ipairs(PF.all()) do for id, s in pairs(p.provides) do check(p.id, id, s) end end
end)
test("every part fits at least one gun", function()
    for _, p in ipairs(PF.all()) do
        local fits = false
        for _, g in ipairs(WF.all()) do
            if R.isCompatible(g, p.fullType) then fits = true; break end
        end
        assert(fits, p.id .. " fits no gun")
    end
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
        magazines = { standard = "Glock17_Mag17" }, slots = { a = { kind = "t_kind", accepts = { "ak_dovetail" } } } }
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
test("AK lists standard, extended, drum in tier order", function()
    local l = M.list(ak); eq(#l, 3)
    eq(l[1].item, "ZGB.AK47_Mag30"); eq(l[2].item, "ZGB.AK_Mag40"); eq(l[3].item, "ZGB.AK47_Drum75")
    eq(l[1].default, true); eq(l[2].default, false)
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
test("extended tier gets the default tier penalty", function()
    local base = ZGB.Stats.compute(glock, {}, "ZGB.Glock17_Mag17")
    local ext  = ZGB.Stats.compute(glock, {}, "ZGB.Glock17_Mag33")
    eq(ext.aimTime, base.aimTime + MF.TIERS.extended.mods.add.aimTime)
end)
test("unknown magazine id rejected", function()
    eq(WF.define{ id = "Dup2", archetype = "pistol", displayName = "x", caliber = "9x19",
        magazines = { standard = "NoSuchMag" } }, nil)
    WF.errors = {}
end)

print("loot")
local lootFound
test("vanilla guns and mags replaced from the catalogue's `replaces`", function()
    package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/server/?.lua;" .. package.path
    ProceduralDistributions = { list = { GunStore = { items = { "Pistol", 10, "556Clip", 20, "Axe", 5 },
                                                     junk = { items = { "Base.AssaultRifle", 2 } } } } }
    require "ZGB/ZGB_Distributions"
    ZGB.Distributions.apply()
    local items = ProceduralDistributions.list.GunStore.items
    eq(items[1], "ZGB.Beretta92FS"); eq(items[3], "ZGB.STANAG_Mag30"); eq(items[5], "Axe")
    eq(ProceduralDistributions.list.GunStore.junk.items[1], "ZGB.M16A2")
    lootFound = {}
    for i = 1, #items, 2 do lootFound[items[i]] = items[i + 1] end
end)
test("family guns spawn next to their anchor at their rarity", function()
    near(lootFound["ZGB.Glock17"], 10 * glock.rarity)
    eq(lootFound["ZGB.AK47"], nil, "rifles don't spawn in a pistol slot:")
end)
test("magazines spawn by tier; shared mags keep the best weight", function()
    near(lootFound["ZGB.Beretta92_Mag30"], 10 * MF.TIERS.extended.loot)
    near(lootFound["ZGB.Glock17_Mag17"], 10 * glock.rarity * MF.TIERS.standard.loot)
    eq(lootFound["ZGB.Beretta92_Mag15"], nil, "standard mag already comes from 9mmClip:")
end)
test("every family has an anchor that replaces a vanilla gun", function()
    for _, c in ipairs(ZGB.CATEGORIES) do
        local anchor = WF.get(ZGB.Distributions.FAMILY_ANCHORS[c.id])
        assert(anchor and anchor.replaces, c.id)
    end
end)

print("ammo")
require "ZGB/ZGB_Ammo"
local AC, AM = ZGB.AmmoCatalog, ZGB.Ammo
test("gun ammo derived from caliber; vanilla item reused for standard 9mm", function()
    eq(glock.ammo, "Base.Bullets9mm"); eq(ak.ammo, "ZGB.Ammo_762x39_FMJ"); eq(m590.ammo, "Base.ShotgunShells")
end)
test("unknown caliber rejected", function()
    eq(WF.define{ id = "X1", archetype = "pistol", displayName = "x", caliber = "6mm_railgun",
                  magazines = { standard = "Glock17_Mag17" } }, nil); WF.errors = {}
end)
test("realistic variant sets", function()
    local function keys(c) local t = {} for _, v in ipairs(AC.variantsFor(c)) do t[v.key] = true end return t end
    local k45, k556, k22, k3030 = keys("45acp"), keys("556x45"), keys("22lr"), keys("3030")
    assert(not k45.subsonic and not k45.ap, ".45: no subsonic/AP")
    assert(k556.ap and k556.tracer and k556.sp and k556.match, "5.56: AP/tracer/SP/match")
    assert(not k22.ap and not k22.tracer and not k22.match, ".22: no AP/tracer/long range")
    assert(not k3030.match and not k3030.fmj, ".30-30: tube-fed, flat noses only")
end)
test("every caliber has an energy and the default variant first", function()
    for id, cal in pairs(AC.CALIBERS) do
        assert(type(cal.energy) == "number", id .. " has no energy")
        eq(AC.variantsFor(id)[1].default, true, id .. ":")
    end
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
test("magazines of caliber include every tier", function()
    local l = AM.magazinesOfCaliber("762x39"); eq(#l, 3)
    eq(AM.magazineInfo("ZGB.STANAG_CMag100").tier, "drum")
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
    assert(found["ZGB.Ammo_22lr_FMJ"] and found["ZGB.Ammo_22lr_FMJ"] < 10, ".22 anchored to 9mm")
    eq(ZGB.Distributions.extras["Base.223Bullets"], nil, "no gun uses .223 Rem: no variants")
end)
test("every caliber a gun uses has somewhere to spawn", function()
    for _, s in ipairs(WF.all()) do
        local std = AC.variantsFor(s.caliber)[1]
        assert(std.isVanilla or ZGB.Distributions.AMMO_ANCHORS[s.caliber], s.caliber .. " has no loot anchor")
    end
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

print("foreign gun mods")
test("an active foreign gun/reload mod blocks the core", function()
    local active = { "SomeMap", "\\Brita" }
    getActivatedMods = function()
        return { size = function() return #active end, get = function(_, i) return active[i + 1] end }
    end
    ZGB.Mode.blocked, ZGB.Mode.conflicts = nil, {}
    eq(ZGB.Mode.isBlocked(), true)
    assert(string.find(ZGB.Mode.conflicts[1], "Brita", 1, true))
    getActivatedMods, ZGB.Mode.blocked, ZGB.Mode.conflicts = nil, nil, {}
    eq(ZGB.Mode.isBlocked(), false)
end)
test("Core mod.info lists the same foreign mods", function()
    local f = assert(io.open("Contents/mods/ZEGunsOfBohemiaCore/42/mod.info"))
    local info = f:read("*a"); f:close()
    for _, id in ipairs(ZGB.Mode.FOREIGN_GUN_MOD_IDS) do
        assert(string.find(info, "\\" .. id, 1, true), id .. " missing from incompatible=")
    end
end)

-- ==================================================================== v0.5
local MODS = "Contents/mods/"
for _, m in ipairs({ "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaReload", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaCalls" }) do
    package.path = MODS .. m .. "/42/media/lua/shared/?.lua;" .. package.path
end
require "ZGB/ZGB_Events"; require "ZGB/ZGB_Addons"; require "ZGB/ZGB_Sandbox"; require "ZGB/ZGB_Casings"
require "ZGBIso/ZGB_Def_IsoView"
require "ZGBReload/ZGB_Reload"
require "ZGBHolding/ZGB_Holding"
require "ZGBCalls/ZGB_Def_Calls"
local E, AD, SB, AF, RF, CS = ZGB.Events, ZGB.Addons, ZGB.Sandbox, ZGB.AnimFactory, ZGB.RecoilFactory, ZGB.Casings
local RL, HD, CL = ZGB.Reload, ZGB.Holding, ZGB.Calls
local G = WF.get

print("events and addons")
test("events reach every listener; a failing one doesn't stop the rest", function()
    E._reset()
    local got = {}
    E.on("t.ev", function(p) got[#got + 1] = p.n end)
    E.on("t.ev", function() error("boom") end)
    E.on("t.ev", function(p) got[#got + 1] = p.n * 2 end)
    eq(E.emit("t.ev", { n = 2 }), 2); eq(got[1], 2); eq(got[2], 4)
    E._reset()
end)
test("missing essential addons are reported until they register", function()
    AD._reset()
    eq(#AD.missingEssentials(), 2)
    AD.register{ id = "reload" }; AD.register{ id = "holding" }
    eq(#AD.missingEssentials(), 0)
    AD._reset()
end)
test("sandbox: default without SandboxVars, override wins", function()
    eq(SB.get("ZGBX", "A", 7), 7)
    SandboxVars = { ZGBX = { A = "12" } }; eq(SB.get("ZGBX", "A", 7), 12)
    SB.set("ZGBX", "A", 3); eq(SB.get("ZGBX", "A", 7), 3)
    SandboxVars = nil; SB._reset()
end)

print("animation factory")
test("every gun has a known anim type", function()
    for _, s in ipairs(WF.all()) do assert(AF.getType(s.animType), s.id .. ": " .. tostring(s.animType)) end
    eq(G("SteyrAUG").animType, "bullpup"); eq(G("ColtSAA").animType, "revolver_gate"); eq(G("Rem700").animType, "bolt_internal")
end)
test("iso view resolves every clip of every anim type", function()
    for _, t in ipairs(AF.types()) do
        local missing = AF.missingClips("iso", t.id)
        assert(#missing == 0, t.id .. " missing iso clips: " .. table.concat(missing, ", "))
    end
end)
test("child types inherit and override (bullpup is a slower rifle)", function()
    local rifle, bull = AF.getType("rifle"), AF.getType("bullpup")
    assert(bull.timings.magIn > rifle.timings.magIn)
    eq(bull.timings.magDrop, rifle.timings.magDrop)
    eq(#bull.reloads.empty, #rifle.reloads.empty)
end)
test("reload sequences: per-round and only-if-empty steps", function()
    local cyl = AF.sequence("revolver", "cylinder", 6, true); eq(#cyl, 3 + 6)
    eq(#AF.sequence("pump", "single", 4, false), 4)
    local dry = AF.sequence("pump", "single", 4, true); eq(#dry, 5); eq(dry[5].clip, "cycle")
    eq(AF.sequence("handgun", "single", 3, true), nil)
end)
test("iso build: script params by type, stance variants fall back", function()
    eq(AF.build("iso", glock).scriptParams.SwingAnim, "Handgun")
    eq(AF.build("iso", ak).scriptParams.SwingAnim, "Rifle")
    local novice = AF.build("iso", ak, "novice")
    local expert = AF.build("iso", ak, "expert")
    assert(novice.clips.idle.lowered > expert.clips.idle.lowered, "novice carries lower")
    eq(AF.build("iso", ak, "nonsense").clips.idle.anim, AF.build("iso", ak).clips.idle.anim)
    eq(novice.variables.ZGB_Stance, "novice"); eq(novice.variables.ZGB_AnimType, "rifle")
end)

print("recoil")
test("spray pattern: deterministic, as long as the biggest magazine", function()
    local p = RF.patternFor(ak)
    eq(p.length, 75); eq(p.profile, "climb_right")
    RF._cache = {}
    near(RF.patternFor(ak).shots[30].x, p.shots[30].x)
end)
test("profiles shape the spray; caliber sets its size", function()
    assert(RF.patternFor(ak).shots[30].x > 0, "AK drifts right")
    assert(RF.patternFor(G("ThompsonM1928")).shots[30].x < 0, "Thompson drifts left")
    assert(RF.patternFor(G("DesertEagle")).vertical > RF.patternFor(glock).vertical)
end)
test("iso recoil: first shot free, penalty grows and caps", function()
    eq(RF.iso(ak, 1).hitPenalty, 0)
    local a, b = RF.iso(ak, 5).hitPenalty, RF.iso(ak, 15).hitPenalty
    assert(a > 0 and b >= a)
    assert(RF.iso(G("M16A2"), 100).hitPenalty <= RF.ISO_PENALTY_CAP)
    assert(RF.iso(ak, 5, 0.5).hitPenalty < a, "a compensator (lower recoil) shrinks it")
end)
test("kick class and burst tracking", function()
    eq(RF.kickClass(G("BarrettM95")), "heavy"); eq(RF.kickClass(G("RugerMkII")), "light")
    local st = {}
    eq(RF.track(st, 10.0), 1); eq(RF.track(st, 10.2), 2); eq(RF.track(st, 11.5), 1)
end)
test("transient effects join the from-scratch stats pass", function()
    local s = ZGB.Stats.compute(ak, {}, nil, nil, { { mods = { add = { hitChance = -10 } } } })
    eq(s.hitChance, ak.stats.hitChance - 10)
    eq(ZGB.Stats.compute(ak, {}).hitChance, ak.stats.hitChance)
end)

print("casings")
test("semi-autos drop a casing per shot, bolt guns after cycling", function()
    local c = CS.forEvent(glock, "fire"); eq(c.item, "ZGB.Casing_Pistol"); eq(c.delay, 0)
    assert(CS.forEvent(G("Rem700"), "fire").delay > 0)
    eq(CS.forEvent(m590, "fire").item, "ZGB.Casing_ShotgunHull")
end)
test("revolvers and break-actions drop their empties on reload", function()
    eq(CS.forEvent(G("SW_Model10"), "fire"), nil)
    eq(CS.forEvent(G("SW_Model10"), "reload", { spent = 4 }).count, 4)
    eq(CS.forEvent(G("CoachGun"), "reload", { spent = 2 }).count, 2)
    eq(CS.forEvent(G("SW_Model10"), "reload", { spent = 0 }), nil)
end)

print("reloading addon")
test("reload kind follows the gun and its state", function()
    eq(RL.kindFor(glock, { rounds = 5 }), "tactical"); eq(RL.kindFor(glock, { rounds = 0 }), "empty")
    eq(RL.kindFor(G("SW_Model10"), {}), "cylinder"); eq(RL.kindFor(G("ColtSAA"), {}), "gate")
    eq(RL.kindFor(G("CoachGun"), {}), "break"); eq(RL.kindFor(m590, {}), "single")
    eq(RL.kindFor(G("Rem700"), {}), "single")
end)
test("chambered +1 only for closed-bolt guns", function()
    eq(RL.hasChamber(glock), true); eq(RL.capacity(glock, 17), 18)
    eq(RL.hasChamber(G("Uzi")), false); eq(RL.hasChamber(G("SW_Model10")), false)
    eq(RL.hasChamber(m590), true); eq(RL.hasChamber(G("CoachGun")), false)
    eq(RL.plan(glock, { rounds = 3 }).chamberPlusOne, true)
    eq(RL.plan(glock, { rounds = 0 }).chamberPlusOne, false)
end)
test("plan timing: skill speeds it up, drums slow it down, sandbox scales", function()
    local base = RL.plan(ak, { rounds = 0 }, { skill = 0 }).duration
    assert(RL.plan(ak, { rounds = 0 }, { skill = 10 }).duration < base)
    assert(RL.plan(ak, { rounds = 0, magTier = "drum" }, { skill = 0 }).duration > base)
    near(RL.plan(ak, { rounds = 0 }, { skill = 0, speed = 200 }).duration, base / 2)
    assert(RL.plan(ak, { rounds = 0 }).duration > RL.plan(ak, { rounds = 5 }).duration, "empty is slower than tactical")
end)
test("internal reloads load what's missing; revolvers reload every chamber", function()
    eq(RL.plan(m590, { rounds = 5 }).rounds, 3)
    local rv = RL.plan(G("SW_Model10"), { rounds = 2 }); eq(rv.rounds, 6); eq(rv.spent, 4)
end)
test("reload steps come due in order", function()
    local plan = RL.plan(glock, { rounds = 0 }, { skill = 0 })
    local due, nxt = RL.dueSteps(plan, 0, 1); eq(#due, 1); eq(due[1].step.clip, "magDrop")
    due, nxt = RL.dueSteps(plan, plan.duration, nxt); eq(#due, 2); eq(nxt, 4)
end)

print("tactical holding addon")
test("stance follows Aiming level", function()
    eq(HD.stanceFor(0), "novice"); eq(HD.stanceFor(3), "trained"); eq(HD.stanceFor(7), "proficient"); eq(HD.stanceFor(10), "expert")
end)
test("sandbox: level link off, fixed stance, custom thresholds, disabled", function()
    eq(HD.stanceFor(0, { useLevel = false, fixed = "expert" }), "expert")
    eq(HD.stanceFor(2, { thresholds = { trained = 2 } }), "trained")
    eq(HD.stanceFor(10, { enabled = false }), nil)
    SB.set("ZGBHolding", "UseAimingLevel", false); SB.set("ZGBHolding", "FixedStance", 2)
    eq(HD.stanceFor(0, HD.optionsFromSandbox(SB)), "trained")
    SB._reset()
end)
test("first-person passive hold steadies with experience", function()
    local a, b, c = HD.fpPassive(0), HD.fpPassive(4), HD.fpPassive(10)
    assert(a.sway > b.sway and b.sway > c.sway)
    near(c.sway, HD.get("expert").fp.sway)
end)
test("every stance has an iso idle and aim variant", function()
    for _, s in ipairs(HD.all()) do
        local _, _, key = AF.resolve("iso", "rifle", "idle", s.id); eq(key, "idle@" .. s.id)
        _, _, key = AF.resolve("iso", "handgun", "aim", s.id); eq(key, "aim@" .. s.id)
    end
end)

print("callouts addon")
test("reload callouts match the reload kind", function()
    local line, call = CL.pick("reload.start", { kind = "tactical", spec = ak }, {}, { now = 0 })
    eq(call.id, "reload_tactical"); assert(line)
    eq(select(2, CL.pick("reload.start", { kind = "single", spec = m590 }, {}, { now = 0 })).id, "reload_shells")
    eq(select(2, CL.pick("reload.start", { kind = "single", spec = G("Win1894") }, {}, { now = 0 })).id, "reload_rounds")
end)
test("cooldown blocks chatter; urgent calls interrupt", function()
    local st = {}
    assert(CL.pick("reload.start", { kind = "tactical" }, st, { now = 0, cooldown = 4 }))
    eq(CL.pick("reload.start", { kind = "tactical" }, st, { now = 1, cooldown = 4 }), nil)
    assert(CL.pick("ammo.empty", {}, st, { now = 2, cooldown = 4 }), "out of ammo interrupts")
    assert(CL.pick("reload.start", { kind = "tactical" }, st, { now = 7, cooldown = 4 }))
end)
test("categories can be switched off; sidearm and grenade calls", function()
    eq(CL.pick("ammo.empty", {}, {}, { now = 0, enabled = { ammo = false } }), nil)
    eq(select(2, CL.pick("weapon.equip", { previous = ak, spec = glock }, {}, { now = 0 })).id, "sidearm")
    eq(CL.pick("weapon.equip", { previous = glock, spec = ak }, {}, { now = 0 }), nil)
    eq(CL.pick("grenade.throw", { kind = "frag" }, {}, { now = 0 }), "FRAG OUT!")
end)

print("addon packaging")
test("every addon has mod.info requiring Core, and a common/ folder", function()
    for _, m in ipairs({ "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaReload", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaCalls" }) do
        local f = assert(io.open(MODS .. m .. "/42/mod.info"), m)
        local info = f:read("*a"); f:close()
        assert(string.find(info, "require=\\ZEGunsOfBohemiaCore", 1, true), m .. " must require Core")
        assert(string.find(info, "modversion=" .. ZGB.VERSION, 1, true), m .. " version")
        assert(io.open(MODS .. m .. "/common/README.txt"), m .. " needs common/")
    end
end)
test("every sandbox option has a label", function()
    for _, m in ipairs({ "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaReload", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaCalls" }) do
        local opts = io.open(MODS .. m .. "/42/media/sandbox-options.txt"):read("*a")
        local labels = io.open(MODS .. m .. "/42/media/lua/shared/Translate/EN/Sandbox_EN.txt"):read("*a")
        for key in string.gmatch(opts, "translation = ([%w_]+)") do
            assert(string.find(labels, "Sandbox_" .. key .. " =", 1, true), m .. ": no label for " .. key)
        end
    end
end)

print("models and visuals (v0.6)")
require "ZGB/ZGB_Visuals"
local MDF, VIS = ZGB.ModelFactory, ZGB.Visuals
local SCRIPTS = "Contents/mods/ZEGunsOfBohemiaCore/42/media/scripts/"
local function readFile(path) local f = io.open(path, "rb"); if not f then return nil end local s = f:read("*a"); f:close(); return s end
local function catalogueGuns()
    local out = {}
    for _, s in ipairs(WF.all()) do if s.id ~= "TGun" then out[#out + 1] = s end end   -- TGun is a test-only gun
    return out
end
local function pngSize(path)
    local s = readFile(path); if not s then return nil end
    local function u32(i) local a, b, c, d = s:byte(i, i + 3); return ((a * 256 + b) * 256 + c) * 256 + d end
    assert(s:sub(1, 8) == "\137PNG\r\n\26\n", path .. " is not a PNG")
    return u32(17), u32(21)
end
test("every gun has a model and every slot a mounting point", function()
    for _, s in ipairs(catalogueGuns()) do
        assert(MDF.gunModel(s), s.id .. " has no model")
        for sid in pairs(s.slots) do assert(MDF.slotPoint(s, sid), s.id .. "." .. sid .. " has no point") end
    end
end)
test("every attachment has a model except internal ones; modes are consistent", function()
    for _, p in ipairs(PF.all()) do
        if string.sub(p.id, 1, 2) ~= "T_" then
            local mode = VIS.mode(p)
            if p.noModel then eq(mode, "none", p.id) else assert(MDF.partModel(p), p.id .. " has no model") end
            if mode == "rendered" then assert(p.vanillaPartType, p.id) end
        end
    end
    eq(VIS.mode(PF.get("Optic_RedDot")), "rendered"); eq(VIS.mode(PF.get("Mount_AK_SideRail")), "baked")
    eq(VIS.mode(PF.get("Stock_AK_Folding")), "baked", "replaces the wooden stock:")
    eq(VIS.mode(PF.get("Choke_Full")), "none")
end)
test("new v0.6 attachments fit where they should", function()
    eq((R.canAttach(G("M4A1"), {}, "FlashHider_556")), true)
    eq((R.canAttach(glock, {}, "Comp_Pistol9")), true)
    eq((R.canAttach(G("M4A1"), {}, "Laser_Rifle")), true)
    eq((R.canAttach(m590, {}, "RecoilPad_Rubber")), true)
    eq((R.canAttach(G("Win1894"), {}, "ShellHolder_Butt")), true)
    eq(R.isCompatible(G("M4A1"), "RecoilPad_Rubber"), false)
end)
test("variants: base first, bounded, unique names", function()
    local total = 0
    for _, s in ipairs(catalogueGuns()) do
        local vs, seen = VIS.variants(s), {}
        eq(next(vs[1]), nil, s.id .. " base first:")
        assert(#vs < VIS.MAX_VARIANTS, s.id .. " hit the variant cap")
        for _, att in ipairs(vs) do
            local id = VIS.modelId(s, att)
            assert(not seen[id], "duplicate variant " .. id); seen[id] = true
        end
        total = total + #vs
    end
    assert(total < 500, "too many variants: " .. total)
end)
test("a side mount moves the scope point on top of it", function()
    local base = VIS.variantModel(ak, {})
    eq(base.points.scope, nil, "bare AK has nowhere for an optic:")
    local m = VIS.variantModel(ak, { side_mount = "ZGB.Mount_AK_SideRail" })
    eq(m.id, "AK47__Mount_AK_SideRail")
    assert(m.points.scope[2] > MDF.gunModel(ak).points.top[2], "scope sits above the receiver")
    near(m.points.scope[3], 0)
end)
test("replacement parts hide the piece they replace", function()
    local hidden = VIS.hiddenTags(ak, { stock = "ZGB.Stock_AK_Folding" })
    eq(hidden.stock, true)
    local m = VIS.variantModel(ak, { stock = "ZGB.Stock_AK_Folding" })
    for _, p in ipairs(m.prims) do assert(p.tag ~= "stock", "the wooden stock is still there") end
    eq(VIS.previewLayers(ak, { stock = "ZGB.Stock_AK_Folding" })[1].sprite, "AK47_nostock")
end)
test("rendered parts don't change the model; baked ones do", function()
    eq(VIS.modelId(G("M4A1"), { optic_rail = "ZGB.Optic_RedDot", muzzle = "ZGB.Suppressor_Rifle556" }), "M4A1")
    eq(VIS.modelId(G("M4A1"), { under_rail = "ZGB.Laser_Rifle" }), "M4A1__Laser_Rifle")
end)
test("preview layout lines up with the generated sprites", function()
    local w, h = pngSize("Contents/mods/ZEGunsOfBohemiaCore/42/media/textures/ZGB/Preview/AK47.png")
    local lay = VIS.previewRects(ak, { side_mount = "ZGB.Mount_AK_SideRail", optic_rail = "ZGB.Optic_RedDot" })
    eq(lay.rects[1].w, w); eq(lay.rects[1].h, h)
    local dot = lay.rects[3]
    eq(dot.sprite, "Optic_RedDot")
    local dw, dh = pngSize("Contents/mods/ZEGunsOfBohemiaCore/42/media/textures/ZGB/Preview/Optic_RedDot.png")
    eq(dot.w, dw); eq(dot.h, dh)
    assert(dot.y < 0 + h * 0.4, "the red dot sits on top")
end)
test("generated files match the catalogue (run tools/gen_models.lua + gen_scripts.lua)", function()
    local models = assert(readFile(SCRIPTS .. "ZGB_models.txt"), "ZGB_models.txt missing")
    local weapons = assert(readFile(SCRIPTS .. "ZGB_items_weapons.txt"))
    local parts = assert(readFile(SCRIPTS .. "ZGB_items_parts.txt"))
    for _, s in ipairs(catalogueGuns()) do
        for _, att in ipairs(VIS.variants(s)) do
            local id = VIS.modelId(s, att)
            assert(string.find(models, "model " .. id .. "\n", 1, true), "model script missing " .. id)
        end
        assert(readFile("Contents/mods/ZEGunsOfBohemiaCore/42/media/textures/Item_ZGB_" .. s.id .. ".png"), "icon missing " .. s.id)
    end
    for _, p in ipairs(PF.all()) do
        if VIS.mode(p) == "rendered" then
            assert(string.find(parts, "item Vis_" .. p.id .. "[\r\n]"), "visual twin missing " .. p.id)
            assert(string.find(models, "model " .. p.id .. "\n", 1, true), "part model missing " .. p.id)
        end
    end
    for twin, model in string.gmatch(weapons, "ModelWeaponPart = (%S+) (%S+) anchor") do
        assert(string.find(models, "model " .. model:gsub("^ZGB%.", "") .. "\n", 1, true), "ModelWeaponPart points at missing model " .. model)
    end
    assert(readFile("Contents/mods/ZEGunsOfBohemiaCore/42/media/models_X/ZGB/Guns/AssaultRifles/AK47/AK47__Mount_AK_SideRail.X"))
    assert(readFile("Contents/mods/ZEGunsOfBohemiaCore/42/media/models_X/ZGB/Attachments/Suppressors/Suppressor_Rifle556/Suppressor_Rifle556.X"))
end)
test("PNG writer round-trips size and signature", function()
    package.path = "tools/lib/?.lua;" .. package.path
    local Img = require "zgb_image"
    local im = Img.new(5, 3); Img.fillRect(im, 0, 0, 5, 3, 200, 10, 10, 255)
    local tmp = os.tmpname()
    Img.save(im, tmp)
    local w, h = pngSize(tmp); eq(w, 5); eq(h, 3)
    os.remove(tmp)
end)

print("addon clients (stub game)")
test("clients load and react: equip -> stance -> anim variables, reload -> callout + casings", function()
    -- the smallest slice of the game the client files touch
    local handlers = {}
    Events = setmetatable({}, { __index = function(t, name)
        local ev = { Add = function(fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end }
        rawset(t, name, ev); return ev
    end })
    Perks = { Aiming = "Aiming", Reloading = "Reloading" }
    ZombRand = function(n) return 0 end
    local dropped = {}
    local square = { AddWorldInventoryItem = function(_, ft) local wi = { ft = ft }; dropped[#dropped + 1] = wi; return wi end }
    local player = { vars = {}, said = {}, aiming = 0 }
    function player:setVariable(k, v) self.vars[k] = v end
    function player:Say(s) self.said[#self.said + 1] = s end
    function player:getPerkLevel(perk) return perk == "Aiming" and self.aiming or 0 end
    function player:getForwardDirection() return { getX = function() return 1 end, getY = function() return 0 end } end
    function player:getCurrentSquare() return square end
    function player:getX() return 10.5 end
    function player:getY() return 10.5 end
    for _, m in ipairs({ "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaReload", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaCalls" }) do
        package.path = MODS .. m .. "/42/media/lua/client/?.lua;" .. package.path
    end
    E._reset(); AD._reset()
    package.loaded["ZGBIso/ZGB_ViewIso"] = nil
    require "ZGBIso/ZGB_IsoClient"
    require "ZGBHolding/ZGB_HoldingClient"
    require "ZGBCalls/ZGB_CallsClient"
    eq(#AD.missingEssentials(), 1, "holding registered, reload not yet:")
    require "ZGBReload/ZGB_ReloadHooks"
    eq(#AD.missingEssentials(), 0)

    E.emit("weapon.equip", { player = player, gun = {}, spec = ak })
    eq(player.vars.ZGB_AnimType, "rifle"); eq(player.vars.ZGB_Stance, "novice")
    eq(player.vars.ZGB_Kick, RF.kickClass(ak))
    player.aiming = 9
    for _, fn in ipairs(handlers.LevelPerk or {}) do fn(player, "Aiming") end
    eq(player.vars.ZGB_Stance, "expert")

    E.emit("weapon.fire", { player = player, gun = Mock.item("ZGB.Glock17"), spec = glock, shot = 1 })
    eq(#dropped, 1); eq(dropped[1].ft, "ZGB.Casing_Pistol")
    E.emit("reload.start", { player = player, spec = G("SW_Model10"), kind = "cylinder", spent = 5 })
    eq(#dropped, 6, "five empties out of the cylinder:")
    eq(player.said[#player.said], "RELOADING!")

    -- model variants follow the attachments
    require "ZGBIso/ZGB_IsoModels"
    local gun = Mock.item("ZGB.AK47")
    function gun:setWeaponSprite(m) self.sprite = m end
    local refreshed = 0
    function player:resetEquippedHandsModels() refreshed = refreshed + 1 end
    ZGB.Item.setAttachments(gun, { side_mount = "ZGB.Mount_AK_SideRail" })
    ZGB.Mode.notify("onAttachmentsChanged", player, gun, ak)
    eq(gun.sprite, "ZGB.AK47__Mount_AK_SideRail"); eq(refreshed, 1)
    ZGB.Mode.notify("onAttachmentsChanged", player, gun, ak)
    eq(refreshed, 1, "same model: no refresh:")
    SB.set("ZGBIso", "ModelVariants", false)
    ZGB.Mode.notify("onAttachmentsChanged", player, gun, ak)
    eq(gun.sprite, "ZGB.AK47"); SB._reset()
    Events, Perks, ZombRand = nil, nil, nil
    E._reset()
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
