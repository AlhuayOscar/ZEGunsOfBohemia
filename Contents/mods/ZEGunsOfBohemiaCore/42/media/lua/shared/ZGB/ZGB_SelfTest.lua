--[[
    ZGB_SelfTest.lua  —  checks every gun, magazine, round and part INSIDE the game,
    in a few seconds, and writes one line per check:

        PASS / FAIL / SKIP  <subject>  <check>  <detail>

    FAIL and SKIP lines go to console.txt as [ZGB][TEST]; everything goes to
    Zomboid/Lua/ZGB_selftest.txt. SKIP = this build can't be asked (a probe call
    is missing), so the check says nothing either way.

    Run it from the debug world menu ("ZGB: run self-test", ZGB_SelfTestMenu.lua)
    or the Lua console: ZGB.SelfTest.run().  Items are created in no container
    and never added to the world. Only bridge calls touch the game, so the same
    checks run offline against tests/mock_game.lua.
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_Attachments"
require "ZGB/ZGB_Magazines"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/ZGB_Gunworks"

ZGB.SelfTest = ZGB.SelfTest or {}
local T = ZGB.SelfTest
local I, WF, PF, MF, AC, R, M = ZGB.Item, ZGB.WeaponFactory, ZGB.PartFactory, ZGB.MagazineFactory, ZGB.AmmoCatalog, ZGB.Attachments, ZGB.Magazines

T.FILE = "ZGB_selftest.txt"

-- ------------------------------------------------------------ recording
local function newReport() return { lines = {}, pass = 0, fail = 0, skip = 0, failed = {} } end

local function record(r, status, subject, check, detail)
    local line = string.format("%-4s %-22s %-24s %s", status, subject, check, detail or "")
    r.lines[#r.lines + 1] = line
    if status == "PASS" then r.pass = r.pass + 1
    elseif status == "FAIL" then r.fail = r.fail + 1; r.failed[subject] = true
    elseif status == "SKIP" then r.skip = r.skip + 1 end           -- INFO: just a line in the report
end

local function approx(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return a == b end
    return math.abs(a - b) <= 0.011 * math.max(1, math.abs(b))
end

--- Compare a probed value with what the spec says. A missing probe is a SKIP, not a FAIL.
local function expect(r, subject, check, got, want, how)
    if got == nil and how == "missing" then return record(r, "SKIP", subject, check, "game has no getter for this") end
    local same = approx(got, want)
    if not same and (type(got) == "userdata" or type(got) == "table") then same = tostring(got) == tostring(want) end
    if same then record(r, "PASS", subject, check, tostring(want))
    else record(r, "FAIL", subject, check, "expected " .. tostring(want) .. ", got " .. tostring(got)) end
end

local function truthy(r, subject, check, value, failDetail)
    if value == nil then record(r, "SKIP", subject, check, "this build can't be asked")
    elseif value then record(r, "PASS", subject, check, "")
    else record(r, "FAIL", subject, check, failDetail or "") end
end

-- ------------------------------------------------------------ per gun
local function suppressorFor(spec)
    for _, p in ipairs(PF.all()) do
        if p.suppressor or string.find(p.id, "Suppressor", 1, true) then
            local ok = R.canAttach(spec, {}, p.fullType)
            if ok then return p end
        end
    end
end

local function otherVariant(spec)
    for _, v in ipairs(AC.variantsFor(spec.caliber) or {}) do
        if not v.default then return v end
    end
end

function T.checkGun(r, spec)
    local s = spec.id
    if not I.scriptExists(spec.fullType) then return record(r, "FAIL", s, "item script", "no script " .. spec.fullType) end
    local gun = I.create(spec.fullType)
    if not gun then return record(r, "FAIL", s, "create", "instanceItem(" .. spec.fullType .. ") gave nothing") end
    record(r, "PASS", s, "create", "")

    -- what ScriptApply wrote into the script at boot
    expect(r, s, "ranged", I.probe(gun, "isRanged"), true)
    expect(r, s, "name", I.probe(gun, "getDisplayName"), spec.displayName)
    expect(r, s, "ammo type", I.ammoTypeOf(gun), spec.ammo)
    expect(r, s, "max ammo", I.probe(gun, "getMaxAmmo"), spec.maxAmmo)
    if spec.magazine then expect(r, s, "magazine type", I.probe(gun, "getMagazineType"), spec.magazine.item) end
    expect(r, s, "model (WeaponSprite)", I.probe(gun, "getWeaponSprite"), spec.fullType)
    truthy(r, s, "model script", I.modelScriptExists(spec.fullType), "no model script " .. spec.fullType)
    local snd = spec.sounds or {}
    for _, key in ipairs({ "fire", "fireSuppressed", "rack", "insertAmmo", "ejectAmmo" }) do
        if snd[key] then
            truthy(r, s, "sound " .. key, I.soundExists(snd[key]), "game doesn't know sound " .. snd[key])
            local file = I.soundFile(snd[key])
            if file then truthy(r, s, "sound file " .. key, file:find("sound/ZGB/", 1, true) ~= nil, "plays " .. file) end
        end
    end

    expect(r, s, "fire sound (script)", I.probe(gun, "getSwingSound"), snd.fire)

    -- vanilla mechanics: what makes it fire, kick, rack and look like a firearm
    truthy(r, s, "tag base:firearm", I.hasTag(gun, "FIREARM"), "vanilla won't treat it as a firearm")
    local fireMode = ZGB.ScriptApply and ZGB.ScriptApply.fireModes(spec)
    if fireMode then expect(r, s, "fire mode", tostring(I.probe(gun, "getFireMode")), fireMode) end
    local animType = ZGB.AnimFactory and ZGB.AnimFactory.getType(spec.animType or "")
    if animType then expect(r, s, "rack after shot", I.probe(gun, "isRackAfterShoot"), animType.manualAction == true) end
    expect(r, s, "reload type", I.probe(gun, "getWeaponReloadType"), spec.reloadType)
    expect(r, s, "two-handed", I.probe(gun, "isTwoHandWeapon"), spec.twoHanded == true)
    local provider = ZGB.Mode and ZGB.Mode.get()
    local anim = provider and provider.getAnimParams(spec.archetype, spec)
    if anim and anim.SwingAnim then expect(r, s, "swing anim", I.probe(gun, "getSwingAnim"), anim.SwingAnim) end
    local flash = I.probe(gun, "getMuzzleFlashModelKey")
    truthy(r, s, "muzzle flash", flash ~= nil and tostring(flash) ~= "", "no MuzzleFlashModelKey")

    -- placement: the game must read our model points in the vanilla gun frame (muzzle on +Y)
    -- "muzzle" is where vanilla starts the shot and the flash: without it ours didn't fire.
    -- Its height tells the rig: long guns have the barrel at +Z, one-handed guns at -Z
    -- (vanilla holds them upside down: M16 muzzle z 0.024, M9 -0.028)
    local mx, my, mz = I.modelAttachment(spec.fullType, "muzzle")
    local wantUp = spec.twoHanded and 1 or -1
    if mx == nil and I.modelScriptExists(spec.fullType) then record(r, "FAIL", s, "muzzle point", "no muzzle attachment: vanilla can't fire it")
    elseif mx == nil then record(r, "SKIP", s, "muzzle point", "model attachment can't be read")
    elseif my > 0.02 and math.abs(mx) < 0.05 and mz * wantUp > 0 then
        record(r, "PASS", s, "muzzle point", string.format("%.3f %.3f %.3f", mx, my, mz))
    else
        record(r, "FAIL", s, "muzzle point", string.format("expected forward on +Y and barrel at %sZ (%s rig), got %.3f %.3f %.3f",
            wantUp > 0 and "+" or "-", spec.twoHanded and "long gun" or "one-handed", mx, my, mz))
    end

    -- stats pushed onto the instance
    local stats = I.applyStats(gun) or {}
    -- after Gunworks' stat pass (it rebuilds the gun from its script): still our shot
    expect(r, s, "fire sound (live)", I.probe(gun, "getSwingSound"), snd.fire)
    expect(r, s, "recoil delay", I.probe(gun, "getRecoilDelay"), stats.recoilDelay)
    expect(r, s, "max range", I.probe(gun, "getMaxRange"), stats.range)
    expect(r, s, "aim time", I.probe(gun, "getAimingTime"), stats.aimTime)
    expect(r, s, "hit chance", I.probe(gun, "getHitChance"), stats.hitChance)
    expect(r, s, "reload time", I.probe(gun, "getReloadTime"), stats.reloadTime)
    expect(r, s, "noise radius", I.probe(gun, "getSoundRadius"), stats.soundRadius)
    expect(r, s, "min damage", I.probe(gun, "getMinDamage"), stats.minDamage)
    expect(r, s, "max damage", I.probe(gun, "getMaxDamage"), stats.maxDamage)

    -- every magazine: capacity, default load, fill, insert
    local mags = M.list(spec)
    for _, m in ipairs(mags) do
        local tag = s .. "/" .. (m.tier or "?")
        local mag = I.create(m.item)
        if not mag then record(r, "FAIL", tag, "create magazine", m.item)
        else
            expect(r, tag, "magazine capacity", I.probe(mag, "getMaxAmmo"), m.capacity)
            local pistolMag = (AC.CALIBERS[spec.caliber] or {}).group == "pistol" or (AC.CALIBERS[spec.caliber] or {}).group == "revolver"
            truthy(r, tag, "magazine tag", I.hasTag(mag, pistolMag and "PISTOL_MAGAZINE" or "RIFLE_MAGAZINE"),
                "missing base:" .. (pistolMag and "pistolmagazine" or "riflemagazine"))
            expect(r, tag, "magazine ammo type", I.ammoTypeOf(mag), spec.ammo)
            I.setMagazineContents(mag, spec.ammo, m.capacity)
            expect(r, tag, "magazine filled", I.ammoCount(mag), m.capacity)
            truthy(r, tag, "insert into gun", I.simulateInsert(gun, m.item, m.capacity), "gun refused " .. m.item)
            expect(r, tag, "gun capacity w/ mag", I.probe(gun, "getMaxAmmo"), m.capacity)
            expect(r, tag, "gun ready to fire", I.gunAmmo(gun) > 0, true)
        end
    end
    if #mags == 0 then
        I.poke(gun, "setCurrentAmmoCount", spec.maxAmmo)
        I.poke(gun, "setRoundChambered", true)
        expect(r, s, "loaded (internal)", I.gunAmmo(gun), spec.maxAmmo)
    end

    -- another load: the gun reports it and its stats follow
    local v = otherVariant(spec)
    if v then
        I.setGunAmmo(gun, v.item)
        expect(r, s, "variant " .. v.key, I.ammoTypeOf(gun), v.item)
        local st = I.applyStats(gun) or {}
        expect(r, s, "variant damage", I.probe(gun, "getMaxDamage"), st.maxDamage)
        I.setGunAmmo(gun, spec.ammo)
    end

    -- a suppressor muffles the shot
    local sup = suppressorFor(spec)
    if sup then
        local _, slot = R.canAttach(spec, {}, sup.fullType)
        I.setAttachments(gun, { [slot] = sup.fullType })
        I.applyStats(gun)
        expect(r, s, "suppressed sound", I.probe(gun, "getSwingSound"), snd.fireSuppressed)
        I.setAttachments(gun, {})
        I.applyStats(gun)
        expect(r, s, "unsuppressed again", I.probe(gun, "getSwingSound"), snd.fire)
    end
end

-- ------------------------------------------------------------ catalogue-wide
function T.checkCatalogue(r)
    for _, reg in ipairs(AC.registrations()) do
        truthy(r, "ammo", reg[1], I.ammoTypeObject(reg[2]) ~= nil, "AmmoType not registered (media/registries.lua)")
    end
    for ft, id in pairs(AC.VANILLA_AMMO_IDS) do
        truthy(r, "ammo", id, I.ammoTypeObject(ft) ~= nil, "vanilla AmmoType missing")
    end
    for calId in pairs(AC.CALIBERS) do
        for _, v in ipairs(AC.variantsFor(calId)) do
            truthy(r, "ammo item", v.item, I.scriptExists(v.item), "no item script")
            local round = I.create(v.item)
            if round then truthy(r, "ammo item", v.item .. " tag", I.hasTag(round, "AMMO"), "missing base:ammo") end
        end
    end
    for _, mag in ipairs(MF.all and MF.all() or {}) do
        truthy(r, "magazine", mag.fullType or mag.id, I.scriptExists(mag.fullType or ZGB.fullType(mag.id)), "no item script")
    end
    for _, p in ipairs(PF.all()) do
        truthy(r, "part", p.id, I.scriptExists(p.fullType), "no item script")
        if ZGB.Visuals and ZGB.Visuals.mode(p) == "rendered" then
            truthy(r, "part", p.id .. " twin", I.scriptExists(ZGB.Visuals.twinOf(p)), "no visual twin " .. ZGB.Visuals.twinOf(p))
        end
    end
end

-- ------------------------------------------------------------ run
--- Runs everything (or only the guns whose id is in `onlyIds`). Returns the report.
-- ------------------------------------------------------------ Gunworks
--- Did Gunworks take our catalogue? Every gun in its ammo family, every magazine-fed
--- gun with its magazine profile, every family with rounds the game knows.
function T.checkGunworks(r)
    local GW = ZGB.Gunworks
    if not ZGB.Mode.isModActive("SWMG") then
        return record(r, "INFO", "Gunworks", "SWMG active", "Gunworks is not enabled (the mod requires it)")
    end
    truthy(r, "Gunworks", "registered", GW and GW.active == true, "ZGB_Gunworks did not register (see console)")
    if not (GW and GW.active) then return end
    -- the modules ZGB_Gunworks loaded (Kahlua has no `package` table: package.loaded crashed
    -- the first self-test on a real server)
    local Ammo, Magazine = GW.modules and GW.modules.Ammo, GW.modules and GW.modules.Magazine
    if type(Ammo) ~= "table" or type(Magazine) ~= "table" then
        return record(r, "FAIL", "Gunworks", "modules", "Ammo / Magazine modules not loaded")
    end
    local P = ZGB.GunworksPlan
    for _, spec in ipairs(WF.all()) do
        local fam = Ammo.ItemAmmoFamily and Ammo.ItemAmmoFamily[spec.fullType]
        expect(r, spec.id, "gunworks ammo family", fam, P.familyName(spec.caliber))
        local bullets = fam and Ammo.AmmoFamilies and Ammo.AmmoFamilies[fam]
        truthy(r, spec.id, "gunworks rounds", bullets ~= nil and #bullets > 0, "family has no rounds")
        if #M.list(spec) > 0 then
            local prof = Magazine.WeaponMagazineProfile and Magazine.WeaponMagazineProfile[spec.fullType]
            expect(r, spec.id, "gunworks magazine profile", prof, P.profileName(spec))
        end
    end
end

function T.run(onlyIds)
    local r = newReport()
    local only
    if onlyIds then only = {}; for _, id in ipairs(onlyIds) do only[id] = true end end
    T.checkCatalogue(r)
    T.checkGunworks(r)
    for _, spec in ipairs(WF.all()) do
        if not only or only[spec.id] then
            local ok, err = pcall(T.checkGun, r, spec)
            if not ok then record(r, "FAIL", spec.id, "self-test crashed", tostring(err)) end
        end
    end
    local nFailedSubjects = 0
    for _ in pairs(r.failed) do nFailedSubjects = nFailedSubjects + 1 end
    r.summary = string.format("ZGB self-test %s: %d pass, %d FAIL (%d subjects), %d skip",
        ZGB.VERSION or "", r.pass, r.fail, nFailedSubjects, r.skip)
    for _, l in ipairs(r.lines) do
        if l:sub(1, 4) ~= "PASS" then print("[ZGB][TEST] " .. l) end
    end
    print("[ZGB][TEST] " .. r.summary)
    local out = { r.summary, "" }
    for _, l in ipairs(r.lines) do out[#out + 1] = l end
    r.written = I.writeLines(T.FILE, out)
    return r
end

-- ------------------------------------------------------------ pose check
-- One gun of every animation type: equip it, let the idle pose settle, aim, take a
-- screenshot, read the animation variables the game is using, put it away. Driven
-- one tick at a time (step()) so the game draws each pose before the picture.
T.POSE_FILE = "ZGB_poses.txt"
T.POSE_WAIT = 45                       -- ticks to let a pose settle (~0.75 s)
-- before the first gun: the camera is still moving back to the character after the menu
-- closes (the first shot, the Glock, missed the character in every in-game pose check)
T.POSE_START_WAIT = 120

--- First gun of each anim type, in catalogue order.
-- vanilla guns photographed in the same poses, to compare ours against (not checked)
T.POSE_REFERENCES = {
    { id = "Pistol", fullType = "Base.Pistol", twoHanded = false },
    { id = "AssaultRifle", fullType = "Base.AssaultRifle", twoHanded = true },
    { id = "Shotgun", fullType = "Base.Shotgun", twoHanded = true },
    { id = "HuntingRifle", fullType = "Base.HuntingRifle", twoHanded = true },
}

function T.poseGuns()
    local seen, out = {}, {}
    for _, spec in ipairs(WF.all()) do
        if spec.animType and not seen[spec.animType] then seen[spec.animType] = true; out[#out + 1] = spec end
    end
    for _, ref in ipairs(T.POSE_REFERENCES) do
        out[#out + 1] = { id = ref.id, fullType = ref.fullType, twoHanded = ref.twoHanded, animType = "vanilla" }
    end
    return out
end

function T.newPoseSession(player)
    local session = { report = newReport(), shots = {}, guns = T.poseGuns(), i = 0, phase = "next", wait = T.POSE_START_WAIT,
                      previous = I.primary(player) }
    local r = session.report

    function session:step()
        if self.wait > 0 then
            -- the game re-reads the aim button every frame: setting it once let it drop
            -- before the picture (first pose check), so hold it every tick
            if self.phase == "aim" then I.setAiming(player, true) end
            self.wait = self.wait - 1
            return false
        end
        local spec = self.guns[self.i]
        if self.phase == "next" then
            self.i = self.i + 1
            spec = self.guns[self.i]
            if not spec then return self:finish() end
            self.item = I.give(player, spec.fullType)
            if not self.item then record(r, "FAIL", spec.id, "pose: give", "could not add " .. spec.fullType); return false end
            I.applyStats(self.item)
            I.equipPrimary(player, self.item)
            self.phase, self.wait = "idle", T.POSE_WAIT
        elseif self.phase == "idle" then
            local subj = spec.animType .. " (" .. spec.id .. ")"
            expect(r, subj, "in hand", I.primary(player) == self.item, true)
            -- vanilla's AnimSets pick the gun poses by this: "handgun" for one-handed guns,
            -- "firearm" for long guns (seen in game)
            expect(r, subj, "anim var Weapon", I.animVar(player, "Weapon"), spec.twoHanded and "firearm" or "handgun")
            local zgbType = I.animVar(player, "ZGB_AnimType")
            record(r, "INFO", subj, "anim vars", string.format("ZGB_AnimType=%s ZGB_Stance=%s ZGB_Kick=%s",
                tostring(zgbType), tostring(I.animVar(player, "ZGB_Stance")), tostring(I.animVar(player, "ZGB_Kick"))))
            I.setAiming(player, true)
            self.phase, self.wait = "aim", T.POSE_WAIT
        elseif self.phase == "aim" then
            local subj = spec.animType .. " (" .. spec.id .. ")"
            I.setAiming(player, true)
            local aiming = I.probe(player, "isAiming") == true
            -- if the game still drops it, the picture shows the idle pose: say so, don't fail
            record(r, aiming and "PASS" or "INFO", subj, "aiming at screenshot",
                aiming and "" or "game dropped the aim: hold right mouse during the pose check")
            -- isAiming said true while the picture showed the idle pose (second pose check):
            -- the animation state is what the picture shows
            local state = I.actionState(player) or "?"
            record(r, "INFO", subj, "animation state", state)
            -- takeScreenshot uses the name as given: without .png the files had no extension
            local name = "ZGB_pose_" .. spec.animType .. "_" .. spec.id .. "_" .. state .. ".png"
            if I.screenshot(name) then
                self.shots[#self.shots + 1] = name
                record(r, "PASS", subj, "screenshot", name)
            else
                record(r, "SKIP", subj, "screenshot", "takeScreenshot not available")
            end
            I.setAiming(player, false)
            self.phase, self.wait = "clean", 5
        elseif self.phase == "clean" then
            I.equipPrimary(player, nil)
            I.removeItem(player, self.item)
            self.item, self.phase = nil, "next"
        end
        return false
    end

    --- Stop now, leave the character as it was: aim off, test gun gone, own gun back.
    function session:abort(reason)
        I.setAiming(player, false)
        if self.item then I.equipPrimary(player, nil); I.removeItem(player, self.item); self.item = nil end
        local spec = self.guns[self.i]
        record(r, "FAIL", spec and spec.id or "pose check", "stopped", tostring(reason))
        return self:finish()
    end

    function session:finish()
        I.equipPrimary(player, self.previous)
        r.summary = string.format("ZGB pose check %s: %d guns, %d screenshots, %d FAIL",
            ZGB.VERSION or "", #self.guns, #self.shots, r.fail)
        print("[ZGB][TEST] " .. r.summary)
        for _, l in ipairs(r.lines) do if l:sub(1, 4) ~= "PASS" then print("[ZGB][TEST] " .. l) end end
        local out = { r.summary, "Screenshots: Zomboid/Screenshots/, named ZGB_pose_<type>_<gun>_<animation state>.png (type vanilla = reference guns)", "" }
        for _, l in ipairs(r.lines) do out[#out + 1] = l end
        r.written = I.writeLines(T.POSE_FILE, out)
        self.done = true
        return true
    end

    return session
end

--- Hands, aim and action queue back to normal after a test went wrong.
function T.resetCharacter(player)
    I.setAiming(player, false)
    I.clearActions(player)
    I.equipPrimary(player, I.primary(player))      -- re-pairs the second hand with a two-handed gun
end

-- ------------------------------------------------------------ test kit
--- Puts a small kit in the player's inventory to try firing by hand: a pistol, a rifle,
--- a pump shotgun, a full magazine of each tier, loose rounds and a suppressor.
T.KIT = { "Glock17", "AK47", "Rem870" }
function T.giveKit(player)
    local given = 0
    for _, id in ipairs(T.KIT) do
        local spec = WF.get(id)
        if spec and I.give(player, spec.fullType) then
            given = given + 1
            for _, m in ipairs(M.list(spec)) do
                local mag = I.give(player, m.item)
                if mag then I.setMagazineContents(mag, spec.ammo, m.capacity) end
            end
            for _ = 1, 30 do I.give(player, spec.ammo) end
            local sup = suppressorFor(spec)
            if sup then I.give(player, sup.fullType) end
        end
    end
    return given
end


--- Every gun (empty, to look at the models up close) and one of every attachment, so each
--- model can be checked in game with the parts on. Returns guns, parts given.
function T.giveAll(player)
    local guns, parts = 0, 0
    for _, spec in ipairs(WF.all()) do
        if I.give(player, spec.fullType) then guns = guns + 1 end
    end
    for _, part in ipairs(PF.all()) do
        if I.give(player, part.fullType) then parts = parts + 1 end
    end
    return guns, parts
end

return T
