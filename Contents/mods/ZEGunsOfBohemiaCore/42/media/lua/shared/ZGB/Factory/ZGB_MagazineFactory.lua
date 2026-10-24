--[[
    ZGB_MagazineFactory.lua  —  Factory Method for detachable magazines.

    Magazines are items of their own, not fields of a gun, so one magazine can
    feed several guns the way it does in real life (a STANAG fits an M16, M4,
    HK416 and Mk 12; a Glock 21 mag fits a KRISS Vector).

    The rules (v0.4):
      * three tiers only: standard, extended, drum. A gun takes at most one
        magazine per tier, and only the tiers that really exist for it.
      * a magazine belongs to ONE caliber. It can hold any ammo variant that
        caliber comes in (ZGB_AmmoCatalog) and nothing else. So a .22 magazine
        can never hold a long-range load, because .22 LR has none.
      * capacity is decided here and nowhere else.

    ------------------------------------------------------------------ schema
    {
      id          = "STANAG_Mag30",        -- required, becomes ZGB.STANAG_Mag30
      displayName = "STANAG 30rd Magazine",-- required
      caliber     = "556x45",              -- required: key of ZGB_AmmoCatalog.CALIBERS
      tier        = "standard",            -- required: standard | extended | drum
      capacity    = 30,                    -- required, positive integer
      label       = "30rd STANAG",         -- optional short menu label
      weight      = 0.12,                  -- optional item weight (script skeleton)
      mods        = { add = { aimTime = 4 } }, -- optional: replaces the tier's default penalty
    }
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_AmmoCatalog"

ZGB.MagazineFactory = ZGB.MagazineFactory or { _specs = {}, _order = {}, errors = {} }
local MF = ZGB.MagazineFactory

-- Tier order is menu / loot order. `mods` apply only while that magazine is loaded;
-- `loot` is the spawn weight relative to the gun the magazine belongs to.
MF.TIERS = {
    standard = { order = 1, label = "Standard", loot = 0.80, mods = {} },
    extended = { order = 2, label = "Extended", loot = 0.25, mods = { add = { aimTime = 2, weight = 0.1 } } },
    drum     = { order = 3, label = "Drum",     loot = 0.06, mods = { add = { aimTime = 6, reloadTime = 12, weight = 0.8 } } },
}
MF.TIER_ORDER = { "standard", "extended", "drum" }

local REQUIRED = { "id", "displayName", "caliber", "tier", "capacity" }

function MF.define(def)
    local errs = {}
    for _, k in ipairs(REQUIRED) do
        if def[k] == nil then errs[#errs + 1] = "missing field '" .. k .. "'" end
    end
    if def.tier and not MF.TIERS[def.tier] then
        errs[#errs + 1] = "unknown tier '" .. tostring(def.tier) .. "' (standard, extended or drum)"
    end
    if def.caliber and not ZGB.AmmoCatalog.exists(def.caliber) then
        errs[#errs + 1] = "unknown caliber '" .. tostring(def.caliber) .. "'"
    end
    if def.capacity ~= nil and (type(def.capacity) ~= "number" or def.capacity < 1 or def.capacity % 1 ~= 0) then
        errs[#errs + 1] = "capacity must be a positive integer"
    end
    if #errs > 0 then
        MF.errors[#MF.errors + 1] = { id = def.id, errors = errs }
        ZGB.err("Magazine '" .. tostring(def.id) .. "' rejected:", table.concat(errs, "; "))
        return nil, errs
    end

    local spec = ZGB.copy(def)
    spec.item     = ZGB.fullType(def.id)
    spec.fullType = spec.item
    spec.label    = spec.label or (def.capacity .. "rd " .. string.lower(MF.TIERS[def.tier].label))
    spec.mods     = ZGB.copy(def.mods or MF.TIERS[def.tier].mods)
    spec.mods.add, spec.mods.mul = spec.mods.add or {}, spec.mods.mul or {}

    if MF._specs[spec.item] then ZGB.warn("Magazine redefined:", spec.item)
    else MF._order[#MF._order + 1] = spec.item end
    MF._specs[spec.item] = spec
    if ZGB.Ammo then ZGB.Ammo.invalidate() end
    return spec
end

function MF.get(idOrFullType)
    if not idOrFullType then return nil end
    return MF._specs[ZGB.fullType(idOrFullType)]
end

function MF.all()
    local out = {}
    for i, ft in ipairs(MF._order) do out[i] = MF._specs[ft] end
    return out
end

function MF.tierOrder(tier) return (MF.TIERS[tier] or {}).order or 99 end

--- Testing helper.
function MF._reset() MF._specs, MF._order, MF.errors = {}, {}, {} end

return MF
