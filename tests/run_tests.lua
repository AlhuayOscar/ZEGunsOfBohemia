--[[
    Offline tests for the pure-logic part of ZE Guns Of Bohemia (factory, rules, stats).
    Run from the ZEGunsOfBohemia folder with any Lua 5.1:
        lua5.1 tests/run_tests.lua
]]
package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/shared/?.lua;" .. package.path

-- PZ's Kahlua has no `next`: hide it from the mod code, so a call fails here and not only in game
local next = next
_G.next = nil

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
    eq(#WF.all(), 76); eq(#WF.errors, 0); eq(#MF.errors, 0); eq(#PF.errors, 0)
end)
test("catalogue counts per category", function()
    local want = { handgun = 18, revolver = 12, assault_rifle = 10, dmr = 4, sniper = 9, smg = 8, shotgun = 9, lever = 6 }
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
    eq(#WF.gunsForMagazine("ZGB.STANAG_Mag30"), 6)        -- M16A2, M4A1, M4A4, M4A1-S, HK416, Mk 12
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
    local att = R.attach(ak, { stock = "ZGB.Stock_AK_Wood" }, "Mount_AK_SideRail")
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
test("B42 ammo types: every round has a registry id, ours are in media/registries.lua", function()
    local AC = ZGB.AmmoCatalog
    eq(AC.registryId("Base.Bullets45"), "base:bullets_45"); eq(AC.registryId("ZGB.Ammo_9x19_HP"), "zgb:ammo_9x19_hp")
    local reg = assert(io.open("Contents/mods/ZEGunsOfBohemiaCore/42/media/registries.lua"), "run tools/gen_scripts.lua"):read("*a")
    for calId, cal in pairs(AC.CALIBERS) do
        for key, ft in pairs(cal.vanilla or {}) do
            assert(AC.VANILLA_AMMO_IDS[ft], calId .. "." .. key .. ": " .. ft .. " has no B42 ammo type (item removed in B42?)")
        end
    end
    for _, r in ipairs(AC.registrations()) do
        assert(reg:find('AmmoType.register("' .. r[1] .. '", "' .. r[2] .. '")', 1, true), r[1] .. " missing: run tools/gen_scripts.lua")
    end
    for _, g in ipairs(WF.all()) do
        local id = AC.registryId(g.ammo)
        assert(id:find("^base:") or reg:find('"' .. id .. '"', 1, true), g.id .. ": ammo type " .. id .. " is never registered")
    end
end)
test("whole-number script fields are written as integers for every gun (B42 rejects 12.5)", function()
    local SA = ZGB.ScriptApply
    for _, g in ipairs(WF.all()) do
        for _, kv in ipairs(SA.paramsFor(g)) do
            if SA.INT_FIELDS[kv[1]] then
                assert(kv[2] == math.floor(kv[2]), g.id .. "." .. kv[1] .. " = " .. tostring(kv[2]) .. " is not a whole number")
            end
        end
    end
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
    eq(mag30.ammo, 30); eq(drum.ammo, 20); eq(apMag.ammo, 10); eq(apMag:getAmmoType():getItemKey(), AP)
    eq(ZGB.Item.ammoCounts(p.inv, "762x39")[FMJ], 0)
end)
test("load all AP: tops off AP mag first", function()
    local p, mag30, drum, apMag = setup()
    ZGB.LoadAll.queueLoadAll(p, "762x39", AP); Mock.runQueue()
    eq(apMag.ammo, 30); eq(mag30.ammo, 5); eq(mag30:getAmmoType():getItemKey(), AP); eq(drum.ammo, 0)
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
    eq(#AD.missingEssentials(), 1)          -- since v0.8 reloading is Gunworks': holding only
    AD.register{ id = "holding" }
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
    local s = ZGB.Stats.compute(ak, { stock = "ZGB.Stock_AK_Wood" }, nil, nil, { { mods = { add = { hitChance = -10 } } } })
    eq(s.hitChance, ak.stats.hitChance - 10)
    eq(ZGB.Stats.compute(ak, { stock = "ZGB.Stock_AK_Wood" }).hitChance, ak.stats.hitChance)
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
    for _, m in ipairs({ "ZEGunsOfBohemiaIso", "ZEGunsOfBohemiaHolding", "ZEGunsOfBohemiaCalls" }) do
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
    eq(VIS.mode(PF.get("Stock_AK_Folding")), "rendered", "guns are built without their stock (v0.8):")
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
test("removable stocks: the gun is built without it, the stock it shipped with is a part", function()
    -- every gun with a stock slot has no stock in its own model
    for _, s in ipairs(WF.all()) do
        if MDF.removableStock(s) then
            for _, p in ipairs(MDF.gunModel(s).prims) do assert(p.tag ~= "stock", s.id .. " still has its stock") end
        end
    end
    -- its factory stock is a part with a model, behind the mounting point, that fits the gun
    for _, p in ipairs(PF.all()) do
        if p.factoryOf then
            local m = assert(MDF.partModel(p), p.id .. " has no model")
            assert(R.canAttach(G(p.factoryOf), {}, p.id), p.id .. " doesn't fit " .. p.factoryOf)
            eq(VIS.mode(p), "rendered", p.id)
        end
    end
    eq(VIS.mode(PF.get("Stock_AK_Folding")), "rendered")
    -- no stock costs: slower aim, more recoil, worse hit chance
    local bare, wood = ZGB.Stats.compute(ak, {}), ZGB.Stats.compute(ak, { stock = "ZGB.Stock_AK_Wood" })
    eq(wood.aimTime, ak.stats.aimTime)
    assert(bare.aimTime > wood.aimTime and bare.recoilDelay > wood.recoilDelay and bare.hitChance < wood.hitChance)
end)
test("stock spawn: the factory stock most often, another that fits now and then, or none", function()
    local SS = ZGB.StockSpawn
    eq(SS.pick(G("Glock17"), function() return 0 end), nil, "no stock slot:")
    local list, total, factory = SS.choices(ak), 0, nil
    for _, c in ipairs(list) do
        total = total + c.weight
        if c.part and c.part.id == "Stock_AK_Wood" then factory = c.weight end
    end
    eq(factory, SS.WEIGHT.factory)
    for _, c in ipairs(list) do
        if c.part then eq(c.part.interface, "ak_stock") end
    end
    -- walk every outcome: each comes back, none is a stock of another family
    local seen = {}
    for r = 0, total - 1 do
        local slot, ft = SS.pick(ak, function(n) assert(n == total); return r end)
        eq(slot, "stock"); seen[ft or "none"] = true
    end
    assert(seen["ZGB.Stock_AK_Wood"] and seen["ZGB.Stock_AK_Folding"] and seen.none)
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
    -- every model script points at a mesh that exists: a placeholder .X or a real .fbx
    local n = 0
    for mesh in string.gmatch(models, "mesh = ([^,]+),") do
        local base = "Contents/mods/ZEGunsOfBohemiaCore/42/media/models_X/" .. mesh
        assert(readFile(base .. ".X") or readFile(base .. ".fbx"), "no mesh file for " .. mesh)
        n = n + 1
    end
    assert(n >= 470, "only " .. n .. " model scripts")   -- fewer variants since v0.8: stocks are drawn, not baked
end)
test("gun models: the muzzle is in front of the grip and the stock behind it", function()
    -- the grip is the model origin (where the hand holds it); MAC10 once had its muzzle at -0.03
    for _, g in ipairs(WF.all()) do
        local m = MDF.gunModel(g)
        if m and m.points.muzzle then
            assert(m.points.muzzle[1] > 0.05, g.id .. ": muzzle at x = " .. m.points.muzzle[1] .. ", behind the grip")
            if m.points.stock then
                assert(m.points.stock[1] < m.points.muzzle[1], g.id .. ": stock in front of the muzzle")
            end
        end
    end
end)
test("model scripts: points are at game scale, in the vanilla frame (muzzle = +Y)", function()
    -- vanilla guns are ~0.6 of real length; at real size ours looked too big in game
    assert(MDF.GAME_SCALE > 0.4 and MDF.GAME_SCALE < 0.8, "GAME_SCALE out of the vanilla range")
    local text = assert(readFile(SCRIPTS .. "ZGB_models.txt"))
    for _, id in ipairs({ "Glock17", "AK47", "Rem870", "AI_AWM", "SW_Model29", "Uzi" }) do
        local spec = WF.get(id)
        local m = MDF.gunModel(spec)
        -- one-handed guns use vanilla's upside-down pistol rig, long guns the rifle rig
        local frame = spec.twoHanded and MDF.FRAMES.long or MDF.FRAMES.hand
        local block = assert(text:match("\n    model " .. id .. "\n    {(.-)\n    }"), id .. ": no model script")
        local x, y, z, rot = block:match("attachment muzzle\n%s*{%s*offset = ([-%d%.]+) ([-%d%.]+) ([-%d%.]+),%s*rotate = ([^,]+),")
        assert(y, id .. ": no muzzle point (vanilla fires from it)")
        local ex, ey, ez = frame.axes(m.points.muzzle[1], m.points.muzzle[2], m.points.muzzle[3])
        local k = MDF.GAME_SCALE
        assert(math.abs(tonumber(y) - ey * k) < 0.002, string.format("%s: muzzle y %s, want %.4f", id, y, ey * k))
        assert(math.abs(tonumber(z) - ez * k) < 0.002, id .. ": muzzle height")
        assert(tonumber(z) * (spec.twoHanded and 1 or -1) > 0, id .. ": barrel on the wrong side for its rig")
        eq(rot, frame.muzzleRotate, id .. " muzzle rotate:")
    end
end)
test("real models: every source maps to an asset, is credited, and is built", function()
    local S = dofile("tools/model_sources.lua")
    local credits = assert(readFile("CREDITS.txt"), "CREDITS.txt missing (run tools/gen_models.lua)")
    local models = assert(readFile(SCRIPTS .. "ZGB_models.txt"))
    for id, src in pairs(S.MODELS) do
        assert(WF.get(id) or PF.get(id), "model_sources.lua maps unknown asset " .. id)
        local pack = assert(S.PACKS[src.pack], id .. " uses unknown pack " .. tostring(src.pack))
        assert(pack.license and pack.author and pack.url, src.pack .. " needs license, author and url")
        local url = pack.perModel and src.credit and src.credit.url or pack.url
        assert(string.find(credits, url, 1, true), url .. " missing from CREDITS.txt")
        -- one texture per real gun / part (the gun's also holds the parts baked into its variants)
        local tex = (WF.get(id) and "Guns/" or "Parts/") .. id
        assert(string.find(models, "model " .. id .. "\n    {\n        mesh = [^\n]*\n        texture = ZGB/" .. tex:gsub("%p", "%%%0") .. ","),
               id .. " should use its own texture ZGB/" .. tex)
        assert(MDF.REAL and MDF.REAL[id], id .. " has no fitted bounds (run tools/blender/import_models.py)")
    end
end)
test("sounds: families follow archetype and caliber", function()
    local SND = ZGB.Sounds
    eq(G("AK47").sounds.fire, "ZGB_Fire_AK"); eq(G("M4A1").sounds.fire, "ZGB_Fire_AR")
    eq(G("Glock17").sounds.family, "P9"); eq(G("Colt1911").sounds.family, "P45")
    eq(G("SW_Model29").sounds.family, "RMAG"); eq(G("MosinNagant").sounds.family, "MOSIN")
    eq(G("Win1897").sounds.family, "MODEL12")
    local r870 = G("Rem870").sounds
    eq(r870.rack, "ZGB_Pump"); eq(r870.insertAmmo, "ZGB_ShellInsert"); eq(r870.ejectAmmo, nil)
    eq(G("Glock17").sounds.insertAmmo, "ZGB_MagIn"); eq(G("Glock17").sounds.ejectAmmo, "ZGB_MagOut")
    assert(SND.isSuppressed({ muzzle = "ZGB.Suppressor_Pistol9" }), "a suppressor should count")
    assert(not SND.isSuppressed({ muzzle = "ZGB.FlashHider_556" }), "a flash hider is not a suppressor")
end)
test("sounds: every gun's sounds are scripted and their audio files exist", function()
    local scripts = assert(readFile(SCRIPTS .. "ZGB_sounds.txt"), "ZGB_sounds.txt missing (run tools/gen_sounds.lua)")
    for _, g in ipairs(WF.all()) do
        for key, name in pairs(g.sounds) do
            if key ~= "family" then
                local file = string.match(scripts, "sound " .. name .. "\n%s*{.-file = ([^,\n]+)")
                assert(file, g.id .. "." .. key .. ": no sound script " .. name)
                assert(readFile("Contents/mods/ZEGunsOfBohemiaCore/42/" .. file .. ".ogg") or
                       readFile("Contents/mods/ZEGunsOfBohemiaCore/42/" .. file), name .. ": audio file missing " .. file)
            end
        end
    end
end)
test("offline mod validator passes (tools/validate_mod.lua)", function()
    local lua = arg and arg[-1] or "lua5.1"
    local r = os.execute('"' .. lua .. '" tools/validate_mod.lua > ' .. (package.config:sub(1, 1) == "\\" and "NUL" or "/dev/null"))
    assert(r == 0 or r == true, "validate_mod.lua found problems: run it to see them")
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

print("gunsmith inspect layout")
require "ZGB/ZGB_InspectLayout"
test("inspect layout: every gun, two screen sizes: slots don't overlap, stay on screen, sit by their part", function()
    local IL = ZGB.InspectLayout
    local stages = { { x = 0, y = 40, w = 1540, h = 980 }, { x = 0, y = 40, w = 940, h = 640 } }   -- 1080p / 720p minus the stats panel
    local function check(spec, att, stage)
        local lay = IL.compute(spec, att, stage)
        local tag = spec.id .. " @" .. stage.w .. ": "
        for i, a in ipairs(lay.slots) do
            local bx = a.box
            assert(bx.x >= stage.x - 0.5 and bx.y >= stage.y - 0.5 and bx.x + bx.w <= stage.x + stage.w + 0.5
                   and bx.y + bx.h <= stage.y + stage.h + 0.5, tag .. a.slotId .. " off screen")
            for j = i + 1, #lay.slots do
                assert(not IL.overlap(bx, lay.slots[j].box), tag .. a.slotId .. " overlaps " .. lay.slots[j].slotId)
            end
            -- lanes: in front of / behind / above the gun
            local g = lay.gun
            if a.lane == "front" then assert(bx.x >= g.x + g.w - 1, tag .. a.slotId .. " not in front") end
            if a.lane == "back" then assert(bx.x + bx.w <= g.x + 1, tag .. a.slotId .. " not behind") end
            if a.lane == "top" then assert(bx.y + bx.h <= g.y + 1, tag .. a.slotId .. " not above") end
        end
        return lay
    end
    for _, g in ipairs(WF.all()) do
        if MDF.gunModel(g) then for _, st in ipairs(stages) do check(g, {}, st) end end   -- test fixtures have no model
    end
    -- the muzzle goes in front, the stock behind; an AK side mount brings its optic rail along
    local lay = check(ak, { side_mount = "ZGB.Mount_AK_SideRail" }, stages[1])
    local lanes = {}
    for _, s in ipairs(lay.slots) do lanes[s.slotId] = s end
    eq(lanes.muzzle.lane, "front"); eq(lanes.stock.lane, "back")
    assert(lanes.optic_rail and lanes.optic_rail.lane == "top", "AK optic rail above the gun")
    eq(lanes.optic_rail.state, "open", "rail live once the mount is on:")
    local bare = IL.compute(ak, {}, stages[1])
    for _, s in ipairs(bare.slots) do if s.slotId == "optic_rail" then eq(s.state, "ghost", "no mount yet:") end end
end)

print("in-game self-test (against the mock game)")
local function silently(fn) local p = print; print = function() end; local ok, r = pcall(fn); print = p; assert(ok, r); return r end
-- In debug mode the game stops in the debugger on every Lua error, even one a pcall
-- catches (the "break" during the in-game pose check). Run like that: list them all.
local function debugMode(fn)
    local caught, realPcall = {}, pcall
    pcall = function(f, ...)
        local res = { realPcall(f, ...) }
        if not res[1] then caught[#caught + 1] = tostring(res[2]) end
        return unpack(res)
    end
    local ok, r = realPcall(silently, fn)
    pcall = realPcall
    assert(ok, r)
    return r, caught
end
test("self-test and pose check raise no Lua error at all (debug mode stops on caught ones too)", function()
    -- Glock18C has no muzzle point: the case that broke into the debugger in game
    require "ZGB/ZGB_SelfTest"
    Mock.installGame()
    local _, caught = debugMode(function() return ZGB.SelfTest.run({ "AK47", "Glock17", "Glock18C", "Rem870", "SW_Model29" }) end)
    local player = Mock.posePlayer()
    player:setPrimaryHandItem({ ft = "Base.Torch" })                -- not a gun: the hand you start with
    local session = ZGB.SelfTest.newPoseSession(player)
    local _, caught2 = debugMode(function() while not session:step() do end end)
    for _, e in ipairs(caught2) do caught[#caught + 1] = e end
    eq(#caught, 0, table.concat(caught, "\n") .. "\n")
end)
test("gunsmith screen: opens, draws, every slot's picker and hover, fits a part (no Lua error at all)", function()
    local MockUI = require "mock_ui"
    MockUI.install(1920, 1080)
    Mock.installGame()
    package.path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/client/?.lua;" .. package.path
    local errors = {}
    for _, id in ipairs({ "AK47", "Glock17", "Rem870", "SW_Model29", "M4A1" }) do
        local player = Mock.posePlayer()
        function player:getPlayerNum() return 0 end
        local inv = player.inv
        function player:getInventory() return inv end
        local spec = WF.get(id)
        local gun = inv:add(instanceItem(spec.fullType))
        for _, p in ipairs(PF.all()) do if R.isCompatible(spec, p.fullType) then inv:add(Mock.item(p.fullType)) end end
        local _, caught = debugMode(function()
            require "ZGB/UI/ZGB_GunsmithWindow"
            local w = ZGB_GunsmithWindow.open(player, gun)
            w:createChildren()
            assert(w.layout, id .. ": no layout")              -- a revolver may have no slots at all
            w:prerender(); w:render()
            for _, slot in ipairs(w.layout.slots) do
                w:onMouseDown(-1, -1)                           -- close the open grid (it can cover this slot)
                w:onMouseDown(slot.box.x + 2, slot.box.y + 2)
                assert(w.picker and w.picker.slotId == slot.slotId, id .. ": slot " .. slot.slotId .. " didn't open")
                for i = 1, #(w.partsBySlot[slot.slotId] or {}) do
                    local r = w:pickerRect()
                    MockUI.mouseX = r.x + 4 + ((i - 1) % 5) * 58 + 10
                    MockUI.mouseY = r.y + 26 + math.floor((i - 1) / 5) * 58 + 10
                    w:onMouseMove(0, 0); w:render()
                end
            end
            -- fit: the first part we own that can go on now queues the timed action
            Mock.queue = {}
            for _, slot in ipairs(w.layout.slots) do
                w.picker = { slotId = slot.slotId }
                for i, row in ipairs(w.partsBySlot[slot.slotId] or {}) do
                    if #Mock.queue == 0 and w:partState(row) == "ready" then
                        local r = w:pickerRect()
                        w:onMouseDown(r.x + 4 + ((i - 1) % 5) * 58 + 10, r.y + 26 + math.floor((i - 1) / 5) * 58 + 10)
                    end
                end
            end
            if #w.layout.slots > 0 then
                assert(#Mock.queue == 1 and Mock.queue[1].Type == "ZGB_AttachPartAction", id .. ": fitting a part queued no action")
            end
            w:close()
        end)
        for _, e in ipairs(caught) do errors[#errors + 1] = id .. ": " .. e end
    end
    eq(#errors, 0, table.concat(errors, "\n") .. "\n")
end)

test("self-test passes on a correct install and writes its report", function()
    require "ZGB/ZGB_SelfTest"
    Mock.installGame()
    local r = silently(function() return ZGB.SelfTest.run() end)
    -- fixtures other tests registered (T_Mount, TGun...) have no generated scripts: expected FAILs
    local real = {}
    for _, l in ipairs(r.lines) do
        local subject, check = l:match("^FAIL%s+(%S+)%s+(%S+)")
        local fixture = subject and (subject:match("^T_") or subject == "TGun" or check:match("^T_"))
        if subject and not fixture then real[#real + 1] = l end
    end
    for _, l in ipairs(real) do print("       " .. l) end
    eq(#real, 0, r.summary .. ":")
    eq(r.skip, 0, "every probe answers in the mock:")
    assert(r.pass > 3000, "expected well over 3000 checks, got " .. r.pass)
    assert(r.written and Mock.written[ZGB.SelfTest.FILE][1] == r.summary, "report file not written")
end)
test("self-test catches the in-game bugs: silent sounds, no firearm tag, pistol reload on a rifle", function()
    Mock.installGame{ script = { ["ZGB.AK47"] = { Tags = "ZGBWeapon", WeaponReloadType = "handgun" } } }
    local r = silently(function() return ZGB.SelfTest.run({ "AK47" }) end)
    local text = table.concat(r.lines, "\n")
    assert(text:find("FAIL AK47%s+tag base:firearm"), "missing firearm tag not reported")
    assert(text:find("FAIL AK47%s+reload type%s+expected boltaction, got handgun"), "wrong reload type not reported")
    -- sounds in module ZGB: the game doesn't know them (the silent shots and racks)
    local path = "Contents/mods/ZEGunsOfBohemiaCore/42/media/scripts/ZGB_sounds.txt"
    local f = io.open(path, "rb"); local original = f:read("*a"); f:close()
    f = io.open(path, "wb"); f:write((original:gsub("\nmodule Base\n", "\nmodule ZGB\n"))); f:close()
    local ok, r2 = pcall(function() Mock.installGame(); return silently(function() return ZGB.SelfTest.run({ "AK47" }) end) end)
    f = io.open(path, "wb"); f:write(original); f:close()
    Mock.installGame()
    assert(ok, r2)
    assert(table.concat(r2.lines, "\n"):find("FAIL AK47%s+sound fire%s+game doesn't know sound ZGB_Fire_AK"),
        "sounds outside module Base not reported")
end)
test("pose check: one gun per animation type, a screenshot each, vanilla firearm pose", function()
    Mock.installGame()
    local player = Mock.posePlayer()
    local before = Mock.item("ZGB.Glock17")
    player:setPrimaryHandItem(before)
    local session = ZGB.SelfTest.newPoseSession(player)
    local types = {}
    for _, g in ipairs(session.guns) do types[g.animType] = true end
    for _, t in ipairs(ZGB.AnimFactory.types()) do
        local used = false
        for _, g in ipairs(WF.all()) do if g.animType == t.id then used = true end end
        if used then assert(types[t.id], "no pose gun for anim type " .. t.id) end
    end
    local ticks = 0
    silently(function() while not session:step() do ticks = ticks + 1; assert(ticks < 100000, "pose check never ends") end end)
    eq(#Mock.screenshots, #session.guns)
    for _, s in ipairs(Mock.screenshots) do assert(s:find("^ZGB_pose_.+%.png$"), "screenshot " .. s .. " needs .png (they came out without one in game)") end
    local refs = 0
    for _, s in ipairs(Mock.screenshots) do if s:find("^ZGB_pose_vanilla_") then refs = refs + 1 end end
    eq(refs, #ZGB.SelfTest.POSE_REFERENCES, "vanilla reference shots:")
    local r = session.report
    local fails = {}
    for _, l in ipairs(r.lines) do if l:sub(1, 4) == "FAIL" then fails[#fails + 1] = l end end
    eq(#fails, 0, table.concat(fails, "\n") .. "\n")
    eq(player:getPrimaryHandItem(), before, "the gun you held comes back:")
    eq(#player.inv.items, 0, "test guns are removed:")
    assert(Mock.written[ZGB.SelfTest.POSE_FILE][1] == r.summary, "pose report not written")
end)
test("pose check stopped halfway leaves the character usable (aim off, own gun back, test gun gone)", function()
    -- in game an error mid-check broke into the debugger and left the character unable to shove or shoot
    Mock.installGame()
    local player = Mock.posePlayer()
    local before = Mock.item("ZGB.Glock17")
    player:setPrimaryHandItem(before)
    local session = ZGB.SelfTest.newPoseSession(player)
    silently(function()
        for _ = 1, ZGB.SelfTest.POSE_START_WAIT + ZGB.SelfTest.POSE_WAIT + 3 do session:step() end   -- a gun in hand, aiming
        assert(player.aiming and player.primaryItem ~= before, "should be mid-check")
        session:abort("test")
    end)
    eq(player.aiming, false); eq(player:getPrimaryHandItem(), before); eq(#player.inv.items, 0)
    assert(table.concat(session.report.lines, "\n"):find("FAIL .-stopped%s+test"), "stop not reported")
    -- and the emergency reset
    player:setIsAiming(true)
    ZGB.SelfTest.resetCharacter(player)
    eq(player.aiming, false)
end)
test("self-test reports a missing magazine script and a wrong fire sound", function()
    Mock.installGame{ noItem = { ["ZGB.AK47_Mag30"] = true }, script = { ["ZGB.Glock17"] = { SwingSound = "M9Shoot" } } }
    local r = silently(function() return ZGB.SelfTest.run({ "AK47", "Glock17" }) end)
    Mock.installGame()
    local text = table.concat(r.lines, "\n")
    assert(text:find("FAIL magazine%s+ZGB.AK47_Mag30"), "missing magazine script not reported")
    assert(text:find("FAIL AK47/standard%s+create magazine"), "magazine creation failure not reported")
    assert(text:find("FAIL Glock17%s+fire sound %(script%)%s+expected ZGB_Fire_P9, got M9Shoot"), "wrong fire sound not reported")
end)
test("test kit gives guns, full magazines of each tier, rounds and a suppressor", function()
    Mock.installGame()
    local p = Mock.player()
    function p:getInventory() return { AddItem = function(_, ft) return p.inv:add(instanceItem(ft)) end } end
    eq(ZGB.SelfTest.giveKit(p), 3)
    local have = {}
    for _, it in ipairs(p.inv.items) do have[it.ft] = (have[it.ft] or 0) + 1 end
    assert(have["ZGB.AK47"] and have["ZGB.AK47_Mag30"], "AK and its magazine")
    eq(have[WF.get("Glock17").ammo], 30)
    for _, it in ipairs(p.inv.items) do
        if it.ft == "ZGB.AK47_Mag30" then eq(it:getCurrentAmmoCount(), 30) end
    end
end)
test("give all: every gun and one of every attachment", function()
    Mock.installGame()
    local p = Mock.player()
    function p:getInventory() return { AddItem = function(_, ft) return p.inv:add(instanceItem(ft)) end } end
    local guns, parts = ZGB.SelfTest.giveAll(p)
    local real = 0
    for _, s in ipairs(WF.all()) do if ScriptManager.instance:getItem(s.fullType) then real = real + 1 end end
    eq(guns, real); assert(guns >= 70, "every catalogue gun")
    local realParts = 0
    for _, s in ipairs(PF.all()) do if ScriptManager.instance:getItem(s.fullType) then realParts = realParts + 1 end end
    eq(parts, realParts); assert(parts >= 50, "every catalogue part")
    eq(#p.inv.items, guns + parts)
end)

print("gunworks (v0.8)")
require "ZGB/ZGB_GunworksPlan"
local GP = ZGB.GunworksPlan
test("gunworks plan: one ammo family per caliber, vanilla first, library rounds after ours", function()
    local fams = GP.families()
    for _, spec in ipairs(WF.all()) do
        if ZGB.AmmoCatalog.exists(spec.caliber or "") then
            assert(fams[GP.familyName(spec.caliber)], spec.id .. " has no ammo family")
        end
    end
    local f9 = fams["ZGB:9x19"]
    eq(f9.bullets[1].type, "Base.Bullets9mm")
    local last = f9.bullets[#f9.bullets]
    eq(last.type, "SWMG.9x19_Bullet"); assert(last.library)
    local seen, hasGlock, hasMag = {}, false, false
    for _, ft in ipairs(f9.items) do
        assert(not seen[ft], "duplicate " .. ft); seen[ft] = true
        if ft == "ZGB.Glock17" then hasGlock = true end
        if ZGB.MagazineFactory.get(ft) then hasMag = true end
    end
    assert(hasGlock and hasMag, "9x19 family lists the Glock and its magazines")
end)
test("gunworks plan: magazine profiles go standard -> extended -> drum; internal feeds get none", function()
    local prof = GP.magazineProfiles()
    local ak = prof["ZGB:AK47"]
    eq(ak.weapon, "ZGB.AK47")
    eq(ak.magazines[1], "ZGB.AK47_Mag30"); eq(ak.magazines[2], "ZGB.AK_Mag40"); eq(ak.magazines[3], "ZGB.AK47_Drum75")
    eq(prof["ZGB:SW_Model10"], nil)
end)
test("gunworks plan: rate of fire only for auto / burst guns, bursts of 3", function()
    local rof = GP.rateOfFire()
    assert(rof["ZGB.Glock18C"] and rof["ZGB.Glock18C"].rpm > 0, "Glock 18C fires auto")
    eq(rof["ZGB.M16A2"].burstCount, 3)
    eq(rof["ZGB.Glock17"], nil)
    local mode, possible = ZGB.ScriptApply.fireModes(G("M16A2"))
    eq(mode, "Burst"); eq(possible, "Burst/Single")
end)
test("gunworks plan: our layer adjusts from the base, skips RecoilDelay in Gunworks auto", function()
    local ak = G("AK47")
    eq(#GP.layer(ak, { attachments = { stock = "ZGB.Stock_AK_Wood" } }), 0, "factory stock, nothing loaded:")
    local rows, target = GP.layer(ak, { attachments = { stock = "ZGB.Stock_AK_Wood" }, magazine = "ZGB.AK47_Drum75" })
    local by = {}
    for _, r in ipairs(rows) do eq(r.op, "Adjust"); by[r.stat] = r.value end
    eq(by.AimingTime, 6); eq(by.ReloadTime, 12)
    eq(target.aimTime, ak.stats.aimTime + 6)
    local hp = select(1, GP.layer(ak, { round = "ZGB.Ammo_762x39_HP" }))
    local dmg
    for _, r in ipairs(hp) do if r.stat == "MaxDamage" then dmg = r.value end end
    assert(dmg and dmg > 0, "hollow points hit harder")
    local plusp = GP.layer(ak, { round = "ZGB.Ammo_762x39_HP", fireMode = "RealAuto", extra = { { mods = { add = { recoilDelay = 3 } } } } })
    for _, r in ipairs(plusp) do assert(r.stat ~= "RecoilDelay", "Gunworks owns RecoilDelay in RealAuto") end
    eq(GP.variantItem(G("M4A1"), "SWMG.556x45_Bullet_ArmorPiercing"), "ZGB.Ammo_556x45_AP")
    eq(GP.variantItem(G("M4A1"), "SWMG.556x45_Bullet_HollowPoint"), nil, "no 5.56 HP of ours: fires as standard")
end)
test("gunworks adapter: registers the catalogue and runs our stat layer", function()
    Mock.installGame()
    -- a small stand-in for the SWMG modules (same calls and layer pass as Gunworks)
    local reg = { families = {}, items = {}, profiles = {}, weapons = {}, rate = {}, layers = {}, handlers = {} }
    local Stats = {}
    function Stats.Adjust(stat, d) return function(w) w["set" .. stat](w, w["get" .. stat](w) + d) end end
    function Stats.Set(stat, v) return function(w) w["set" .. stat](w, v) end end
    function Stats.Multiply(stat, k) return function(w) w["set" .. stat](w, w["get" .. stat](w) * k) end end
    function Stats.RegisterModifierLayer(id, fn, restore, applies) reg.layers[#reg.layers + 1] = { id = id, fn = fn, restore = restore, applies = applies } end
    function Stats.RegisterRestoreHandler(id, fn) reg.handlers[#reg.handlers + 1] = fn end
    function Stats.ReapplyAllModifiers(w)
        local base = instanceItem(w:getFullType())
        for _, l in ipairs(reg.layers) do
            if not l.applies or l.applies(w) then
                for name in pairs(l.restore) do w["set" .. name](w, base["get" .. name](base)) end
                for _, m in ipairs(l.fn(w) or {}) do m(w) end
            end
        end
        for _, h in ipairs(reg.handlers) do h(w) end
    end
    local Ammo = { FindBulletEntry = function() return nil end }
    function Ammo.RegisterAmmoFamily(f, b) reg.families[f] = b end
    function Ammo.RegisterItemWithFamily(f, items) for _, i in ipairs(items) do reg.items[i] = f end end
    local Magazine = {}
    function Magazine.RegisterMagazineProfile(p, list) reg.profiles[p] = list end
    function Magazine.RegisterWeaponWithProfile(p, w) reg.weapons[w] = p end
    local Rate = { RegisterWeapon = function(w, e) reg.rate[w] = e end }
    package.loaded["WeaponSystems/Utils/Ammo"] = Ammo
    package.loaded["WeaponSystems/Utils/Magazine"] = Magazine
    package.loaded["WeaponSystems/Utils/RateOfFire"] = Rate
    package.loaded["WeaponSystems/Utils/StatsFactory"] = Stats
    local oldMods = getActivatedMods
    getActivatedMods = function() return { size = function() return 1 end, get = function() return "\\SWMG" end } end
    package.loaded["ZGB/ZGB_Gunworks"] = nil
    ZGB.Gunworks = nil
    require "ZGB/ZGB_Gunworks"
    local GW = ZGB.Gunworks
    assert(GW.register(), "registers when SWMG is active")
    assert(GW.register(), "second call is a no-op")
    eq(#reg.layers, 1)
    eq(reg.weapons["ZGB.AK47"], "ZGB:AK47")
    eq(reg.items["ZGB.AK47_Drum75"], "ZGB:762x39")
    eq(reg.families["ZGB:9x19"][1].type, "Base.Bullets9mm")
    assert(reg.families["ZGB:9x19"][1].enum, "each round carries its AmmoType object")
    eq(reg.rate["ZGB.M16A2"].burstCount, 3)
    -- a drum in the AK: our layer adds the tier's aim time on top of the base
    local ak = instanceItem("ZGB.AK47")
    ZGB.Item.setAttachments(ak, { stock = "ZGB.Stock_AK_Wood" })
    local baseAim = ak:getAimingTime()
    function ak:isContainsClip() return true end
    ak:setMagazineType("ZGB.AK47_Drum75")
    local st = ZGB.Item.applyStats(ak)
    eq(ak:getAimingTime(), baseAim + 6)
    eq(st.aimTime, baseAim + 6)
    ZGB.Item.applyStats(ak)
    eq(ak:getAimingTime(), baseAim + 6, "re-applying never stacks:")
    GW.active = false
    getActivatedMods = oldMods
    for _, k in ipairs({ "Ammo", "Magazine", "RateOfFire", "StatsFactory" }) do package.loaded["WeaponSystems/Utils/" .. k] = nil end
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
    eq(#AD.missingEssentials(), 0, "holding is the only essential addon:")
    require "ZGBReload/ZGB_ReloadHooks"
    assert(AD.has("reload"), "reload events addon registers (optional)")

    -- stance animations are experimental and off by default: vanilla poses
    E.emit("weapon.equip", { player = player, gun = {}, spec = ak })
    eq(player.vars.ZGB_AnimType, "none", "stance animations off by default:")
    SB.set("ZGBIso", "CustomAnimations", true)
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
    -- a suppressor is drawn by vanilla on the SAME variant: the hands must still be redrawn
    -- (in game the suppressor never showed up while we skipped this)
    ZGB.Item.setAttachments(gun, { side_mount = "ZGB.Mount_AK_SideRail", muzzle = "ZGB.Muzzle_AK_Suppressor" })
    ZGB.Mode.notify("onAttachmentsChanged", player, gun, ak)
    eq(gun.sprite, "ZGB.AK47__Mount_AK_SideRail", "suppressor is not baked:"); eq(refreshed, 2, "redrawn for the suppressor:")
    -- equipping again with nothing changed does not redraw
    ZGB.Mode.notify("onWeaponEquipped", player, gun, ak)
    eq(refreshed, 2, "re-equip, same model: no redraw:")
    SB.set("ZGBIso", "ModelVariants", false)
    ZGB.Mode.notify("onAttachmentsChanged", player, gun, ak)
    eq(gun.sprite, "ZGB.AK47"); SB._reset()
    Events, Perks, ZombRand = nil, nil, nil
    E._reset()
end)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
