--[[
    ZGB_Gunworks.lua  —  hands our catalogue to Gunworks (SWMG), the framework the mod
    runs on since v0.8 (Core mod.info: require=SWMG).

    What it registers (the data comes from ZGB_GunworksPlan, which is pure and tested):
      * one ammo family per caliber: our rounds, vanilla's and the Gunworks library's
        (Ammo), so a magazine can hold mixed rounds and R loads the preferred one
      * one magazine profile per magazine-fed gun, standard -> extended -> drum (Magazine)
      * rate of fire / burst for auto and burst guns (RateOfFire)
      * our stat layer (StatsFactory): base + attachments + loaded magazine tier +
        the round being fired, recomputed from scratch on every Gunworks pass
      * a restore handler for what Gunworks has no stat for: item weight and the
        suppressed shot sound

    Registration runs at OnGameBoot (scripts are loaded, so every round's AmmoType
    exists) and again at OnGameStart in case the boot pass ran too early; it is done once.
    If Gunworks is missing, nothing here runs and the mod falls back to applying stats
    itself (ZGB.Item.applyStats), which is what the offline tests use.
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_GunworksPlan"
require "ZGB/ZGB_Mode"

ZGB.Gunworks = ZGB.Gunworks or { active = false, registered = false }
local GW = ZGB.Gunworks
local P, I = ZGB.GunworksPlan, ZGB.Item

-- Gunworks modules, set by load()
local Ammo, Magazine, Rate, Stats

--- true when the SWMG mod is enabled and its modules load.
function GW.load()
    if Stats then return true end
    if not ZGB.Mode.isModActive(P.MOD_ID) then return false end
    Ammo = require("WeaponSystems/Utils/Ammo")
    Magazine = require("WeaponSystems/Utils/Magazine")
    Rate = require("WeaponSystems/Utils/RateOfFire")
    Stats = require("WeaponSystems/Utils/StatsFactory")
    return Ammo ~= nil and Magazine ~= nil and Rate ~= nil and Stats ~= nil
end

local function op(row)
    if row.op == "Adjust" then return Stats.Adjust(row.stat, row.value) end
    if row.op == "Multiply" then return Stats.Multiply(row.stat, row.value) end
    return Stats.Set(row.stat, row.value)
end

--- Live state of one gun as the plan wants it.
local function stateOf(weapon)
    local extra = {}
    for _, e in pairs(I.transient[weapon] or {}) do extra[#extra + 1] = e end
    return {
        attachments = I.getAttachments(weapon),
        magazine = I.loadedMagazine(weapon),
        round = I.ammoTypeOf(weapon),
        fireMode = I.fireMode(weapon),
        extra = extra,
    }
end

local lastTarget = setmetatable({}, { __mode = "k" })   -- weapon -> our last computed stats

local function layerModifiers(weapon)
    local spec = ZGB.WeaponFactory.specOf(weapon)
    if not spec then return nil end
    local rows, target = P.layer(spec, stateOf(weapon))
    lastTarget[weapon] = target
    local mods = {}
    for _, row in ipairs(rows) do mods[#mods + 1] = op(row) end
    return mods
end

local function isOurs(weapon) return ZGB.WeaponFactory.isOurs(weapon) end

-- after every Gunworks pass: weight and the shot sound (no Gunworks stat for either)
local function restoreHandler(weapon)
    local spec = ZGB.WeaponFactory.specOf(weapon)
    if not spec then return end
    local target = lastTarget[weapon]
    if target and target.weight then I.setWeight(weapon, target.weight) end
    local snd = spec.sounds or {}
    local att = I.getAttachments(weapon)
    local fire = (ZGB.Sounds and ZGB.Sounds.isSuppressed(att) and snd.fireSuppressed) or snd.fire
    if fire and weapon.setSwingSound then weapon:setSwingSound(fire) end
end

--- Our stats on a live gun: Gunworks restores the base and re-applies all its layers.
function GW.reapply(weapon)
    if not GW.active or not weapon then return nil end
    Stats.ReapplyAllModifiers(weapon)
    return lastTarget[weapon]
end

local function registerAmmo(summary)
    for family, f in pairs(P.families()) do
        local bullets = {}
        for _, b in ipairs(f.bullets) do
            local enum = I.scriptAmmoType(b.type) or (not b.library and I.ammoTypeObject(b.type)) or nil
            if enum then
                -- keep a profile another Gunworks pack gave a shared library round
                local existing = Ammo.FindBulletEntry(b.type)
                bullets[#bullets + 1] = { type = b.type, enum = enum, profile = existing and existing.profile or nil }
            elseif not b.library then
                ZGB.warn("Gunworks: no AmmoType for", b.type, "- left out of", family)
            end
        end
        if #bullets > 0 then
            Ammo.RegisterAmmoFamily(family, bullets)
            Ammo.RegisterItemWithFamily(family, f.items)
            summary.families = summary.families + 1
        end
    end
end

local function registerMagazines(summary)
    for profile, p in pairs(P.magazineProfiles()) do
        Magazine.RegisterMagazineProfile(profile, p.magazines)
        Magazine.RegisterWeaponWithProfile(profile, p.weapon)
        summary.magazines = summary.magazines + 1
    end
end

local function registerRate(summary)
    for weapon, e in pairs(P.rateOfFire()) do
        Rate.RegisterWeapon(weapon, e)
        summary.rate = summary.rate + 1
    end
end

--- Register everything once. Returns true when Gunworks took it.
function GW.register()
    if GW.registered then return true end
    if ZGB.Mode.isBlocked() then return false end
    if not GW.load() then
        ZGB.warn("Gunworks (SWMG) not active: the mod needs it for reloading, magazines and fire modes")
        return false
    end
    local summary = { families = 0, magazines = 0, rate = 0 }
    registerAmmo(summary)
    registerMagazines(summary)
    registerRate(summary)
    Stats.RegisterModifierLayer("ZGB", layerModifiers, P.restoreStats(), isOurs)
    Stats.RegisterRestoreHandler("ZGB", restoreHandler)
    GW.registered, GW.active = true, true
    ZGB.log(string.format("Gunworks: %d ammo families, %d magazine profiles, %d rate-of-fire guns",
        summary.families, summary.magazines, summary.rate))
    return true
end

if Events then
    if Events.OnGameBoot then Events.OnGameBoot.Add(GW.register) end
    if Events.OnGameStart then Events.OnGameStart.Add(GW.register) end
end

return GW
