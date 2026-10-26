--[[
    ZGB_ScriptApply.lua  —  push factory specs into the item SCRIPTS at boot.

    The .txt item scripts are deliberately thin skeletons (type, model, icon).
    Every number that matters — ammo, capacity, damage, sounds, animation set —
    is written here from the spec, so the script can never disagree with the
    Lua side. New item instances then spawn with correct base values.

    DoParam is the long-standing way mods tweak script items at load. -- VERIFY on your build
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_Mode"
require "ZGB/Factory/ZGB_WeaponFactory"

ZGB.ScriptApply = ZGB.ScriptApply or {}
local SA = ZGB.ScriptApply

local function scriptItem(fullType)
    if not ScriptManager then return nil end
    return ScriptManager.instance:getItem(fullType)
end

local function param(item, key, value)
    if value == nil then return end
    if type(value) == "boolean" then value = value and "TRUE" or "FALSE" end
    local ok, e = pcall(function() item:DoParam(key .. " = " .. tostring(value)) end)
    if not ok then ZGB.warn("DoParam failed", key, e) end
end

-- spec.stats key -> script field
SA.STAT_FIELDS = {
    minDamage = "MinDamage", maxDamage = "MaxDamage", range = "MaxRange", minRange = "MinRange",
    aimTime = "AimingTime", recoilDelay = "RecoilDelay", hitChance = "HitChance",
    critChance = "CriticalChance", reloadTime = "ReloadTime", soundRadius = "SoundRadius",
    weight = "Weight",
}
-- fields the game parses as whole numbers: "RecoilDelay = 12.5" is rejected as "not a valid
-- parameter" (seen in game on 41 guns). Vanilla writes all of these as integers.
SA.INT_FIELDS = {
    AimingTime = true, RecoilDelay = true, HitChance = true, ReloadTime = true, SoundRadius = true,
    MaxAmmo = true, ProjectileCount = true, ClipSize = true,
}
SA.SOUND_FIELDS = {
    fire = "SwingSound", rack = "RackSound", click = "ClickSound",
    insertAmmo = "InsertAmmoSound", ejectAmmo = "EjectAmmoSound", shellFall = "ShellFallSound",
}

--- Fire modes for a spec: FireMode, FireModePossibilities ("Auto/Burst/Single").
--- Vanilla B42 knows Auto and Single; Burst is Gunworks' (its rate of fire runs it,
--- ZGB_Gunworks registers the burst count), like the Gunworks gun packs write it.
function SA.fireModes(spec)
    local has = {}
    for _, m in ipairs(spec.fireModes or { "single" }) do has[m] = true end
    local list = {}
    if has.auto then list[#list + 1] = "Auto" end
    if has.burst then list[#list + 1] = "Burst" end
    if has.single or #list == 0 then list[#list + 1] = "Single" end
    return list[1], table.concat(list, "/")
end

--- Returns list of {key, value} the weapon script should get. Pure — testable.
function SA.paramsFor(spec, animParams)
    local out = {}
    local function add(k, v)
        if v == nil then return end
        if SA.INT_FIELDS[k] and type(v) == "number" then v = math.floor(v + 0.5) end
        out[#out + 1] = { k, v }
    end

    add("DisplayName", spec.displayName)
    add("AmmoType", ZGB.AmmoCatalog.registryId(spec.ammo))   -- B42: registry id (base:bullets_45, zgb:...)
    add("MaxAmmo", spec.maxAmmo)
    add("ClipSize", spec.maxAmmo)
    local fireMode, possible = SA.fireModes(spec)
    add("FireMode", fireMode)
    add("FireModePossibilities", possible)
    local animType = ZGB.AnimFactory and ZGB.AnimFactory.getType(spec.animType or "")
    if animType then add("RackAfterShoot", animType.manualAction == true) end
    if spec.magazine then add("MagazineType", spec.magazine.item) end
    add("WeaponReloadType", spec.reloadType)
    add("TwoHandWeapon", spec.twoHanded)
    add("RequiresEquippedBothHands", spec.twoHanded)
    add("AttachmentType", spec.attachSlot)
    if spec.ballistics and spec.ballistics.projectileCount then
        add("ProjectileCount", spec.ballistics.projectileCount)
    end
    for key, field in pairs(SA.STAT_FIELDS) do add(field, spec.stats[key]) end
    for _, key in ipairs(ZGB.sortedKeys(SA.SOUND_FIELDS)) do add(SA.SOUND_FIELDS[key], spec.sounds[key]) end
    for field, v in pairs(animParams or {}) do add(field, v) end
    return out
end

function SA.applyAll()
    local provider = ZGB.Mode.get()
    if not provider then
        ZGB.warn("No view addon active (ZEGunsOfBohemiaIso / ZEGunsOfBohemiaFP). Stats applied, animations left as scripted.")
    end
    local count, magsDone = 0, {}
    for _, spec in ipairs(ZGB.WeaponFactory.all()) do
        local item = scriptItem(spec.fullType)
        if not item then
            ZGB.err("Spec has no script item:", spec.fullType, "- run tools/gen_scripts.lua")
        else
            local anim = provider and provider.getAnimParams(spec.archetype, spec) or nil
            for _, kv in ipairs(SA.paramsFor(spec, anim)) do param(item, kv[1], kv[2]) end

            -- every magazine script gets ITS capacity + its caliber's default ammo — the old
            -- "wrong mag size" bug. Shared magazines (STANAG...) are written once; GunType
            -- names the first gun that takes it.
            for _, m in ipairs(spec.magazines or {}) do
                if not magsDone[m.item] then
                    magsDone[m.item] = true
                    local mag = scriptItem(m.item)
                    if mag then
                        param(mag, "MaxAmmo", m.capacity)
                        param(mag, "AmmoType", ZGB.AmmoCatalog.registryId(spec.ammo))
                        param(mag, "GunType", spec.fullType)   -- VERIFY field name
                    else
                        ZGB.err("Magazine script missing:", m.item)
                    end
                end
            end
            count = count + 1
        end
    end
    ZGB.log("Applied", count, "weapon specs to scripts")
end

if Events and Events.OnGameBoot then
    Events.OnGameBoot.Add(SA.applyAll)
end

return SA
