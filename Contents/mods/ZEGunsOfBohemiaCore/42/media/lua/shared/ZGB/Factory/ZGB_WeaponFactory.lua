--[[
    ZGB_WeaponFactory.lua  —  Factory Method for guns.

    ZGB.WeaponFactory.define{ ... }  takes a SHORT definition, merges it over its
    archetype, validates it and registers the finished spec. Every other system
    (script stats, ammo, attachments, UI, animations, the future FP addon) reads
    the spec — never the vanilla script — so there is one source of truth.

    That is what kills the "wrong magazine size" class of bugs: MaxAmmo is not
    inherited from whatever vanilla gun a script was copied from, it is DERIVED
    from `magazine.capacity` here.

    ------------------------------------------------------------------ schema
    {
      id          = "AK47",                 -- required, becomes ZGB.AK47
      archetype   = "assault_rifle",        -- required, see ZGB_Archetypes
      displayName = "AK-47",                -- required
      caliber     = "762x39",                -- required: a key of ZGB_AmmoCatalog.CALIBERS
                                             -- (spec.ammoVariants / spec.ammo are derived from it)
      magazine    = { item = "ZGB.AK47_Mag30", capacity = 30 },  -- required for mag-fed
      altMagazines= { { item = "ZGB.AK47_Drum75", capacity = 75, label = "75rd drum",
                        mods = { add = { weight = 1.2, aimTime = 5 } } } },   -- mods apply while loaded
      stats       = { ...overrides of archetype stats... },
      sounds      = { fire=, rack=, click=, insertAmmo=, ejectAmmo=, shellFall= },
      slots       = {                      -- what the bare gun physically has
         side_mount = { kind="mount", accepts={"ak_dovetail"}, label="Side mount", order=1 },
         ...
      },
      fp          = { ... },               -- reserved for the first-person addon
    }
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_Archetypes"
require "ZGB/Factory/ZGB_AmmoCatalog"

ZGB.WeaponFactory = ZGB.WeaponFactory or { _specs = {}, _order = {}, errors = {} }
local WF = ZGB.WeaponFactory

local REQUIRED = { "id", "archetype", "displayName", "caliber" }
local MAG_FREE_RELOADS = { shotgun = true, boltactionnomag = true, revolver = true, doublebarrelshotgun = true }

local function validate(def, spec)
    local errs = {}
    for _, k in ipairs(REQUIRED) do
        if def[k] == nil then errs[#errs + 1] = "missing field '" .. k .. "'" end
    end
    if def.archetype and not ZGB.Archetypes[def.archetype] then
        errs[#errs + 1] = "unknown archetype '" .. tostring(def.archetype) .. "'"
    end
    if def.caliber and not ZGB.AmmoCatalog.exists(def.caliber) then
        errs[#errs + 1] = "unknown caliber '" .. tostring(def.caliber) .. "' (add it to ZGB_AmmoCatalog)"
    end
    if spec then
        local magFed = not MAG_FREE_RELOADS[spec.reloadType]
        if magFed then
            if not spec.magazine or not spec.magazine.item then
                errs[#errs + 1] = "mag-fed weapon needs magazine.item"
            end
            -- default magazine + every alternative must be valid and unique
            local all, seen = { spec.magazine or {} }, {}
            for _, m in ipairs(spec.altMagazines or {}) do all[#all + 1] = m end
            for i, m in ipairs(all) do
                local label = (i == 1) and "magazine" or ("altMagazines[" .. (i - 1) .. "]")
                if not m.item then
                    if i > 1 then errs[#errs + 1] = label .. " needs item" end
                elseif type(m.capacity) ~= "number" or m.capacity < 1 or m.capacity % 1 ~= 0 then
                    errs[#errs + 1] = label .. ".capacity must be a positive integer"
                elseif seen[m.item] then
                    errs[#errs + 1] = label .. " duplicates " .. m.item
                end
                if m.item then seen[m.item] = true end
            end
        elseif type(spec.internalCapacity) ~= "number" then
            errs[#errs + 1] = "tube/internal weapon needs internalCapacity"
        end
        for slotId, s in pairs(spec.slots or {}) do
            if not s.kind or type(s.accepts) ~= "table" or #s.accepts == 0 then
                errs[#errs + 1] = "slot '" .. slotId .. "' needs kind + accepts{}"
            end
        end
    end
    return errs
end

--- Define and register a weapon. Returns spec, or nil + list of errors.
function WF.define(def)
    local errs = validate(def, nil)
    if #errs > 0 then
        WF.errors[#WF.errors + 1] = { id = def.id, errors = errs }
        ZGB.err("Weapon '" .. tostring(def.id) .. "' rejected:", table.concat(errs, "; "))
        return nil, errs
    end

    local spec = ZGB.merge(ZGB.Archetypes[def.archetype], def)
    spec.fullType = ZGB.fullType(def.id)
    spec.slots    = spec.slots or {}
    spec.sounds   = spec.sounds or {}
    spec.fp       = spec.fp or {}

    errs = validate(def, spec)
    if #errs > 0 then
        WF.errors[#WF.errors + 1] = { id = def.id, errors = errs }
        ZGB.err("Weapon '" .. def.id .. "' rejected:", table.concat(errs, "; "))
        return nil, errs
    end

    -- Derived values: the ONLY place ammo capacity is decided.
    -- spec.magazines = default first, then alternatives; each { item, capacity, label, mods }
    spec.magazines = {}
    if spec.magazine then
        spec.magazine.default = true
        spec.magazines[1] = spec.magazine
        for _, m in ipairs(spec.altMagazines or {}) do spec.magazines[#spec.magazines + 1] = m end
        for _, m in ipairs(spec.magazines) do
            m.mods = m.mods or {}
            m.mods.add, m.mods.mul = m.mods.add or {}, m.mods.mul or {}
        end
    end
    spec.maxAmmo = spec.magazine and spec.magazine.capacity or spec.internalCapacity

    -- Ammo: every variant the caliber comes in; default = first in the catalog.
    spec.ammoVariants = ZGB.AmmoCatalog.variantsFor(spec.caliber)
    spec.ammo = spec.ammoVariants[1].item

    if WF._specs[spec.fullType] then ZGB.warn("Weapon redefined:", spec.fullType)
    else WF._order[#WF._order + 1] = spec.fullType end
    WF._specs[spec.fullType] = spec
    if ZGB.Ammo then ZGB.Ammo.invalidate() end   -- magazine index must see the new gun
    ZGB.debug("Weapon registered:", spec.fullType, "maxAmmo=" .. spec.maxAmmo)
    return spec
end

function WF.get(idOrFullType)
    if not idOrFullType then return nil end
    return WF._specs[ZGB.fullType(idOrFullType)]
end

--- Accepts an InventoryItem (or anything with getFullType) and returns its spec.
function WF.specOf(item)
    if not item then return nil end
    local ok, ft = pcall(function() return item:getFullType() end)
    if not ok or not ft then return nil end
    return WF._specs[ft]
end

function WF.isOurs(item) return WF.specOf(item) ~= nil end

function WF.all()
    local out = {}
    for i, ft in ipairs(WF._order) do out[i] = WF._specs[ft] end
    return out
end

--- Testing helper.
function WF._reset() WF._specs, WF._order, WF.errors = {}, {}, {} end

return WF
