--[[
    ZGB_WeaponFactory.lua  —  Factory Method for guns.

    ZGB.WeaponFactory.define{ ... }  takes a SHORT definition, merges it over its
    archetype, validates it and registers the finished spec. Every other system
    (script stats, ammo, attachments, UI, animations, the future FP addon) reads
    the spec — never the vanilla script — so there is one source of truth.

    That is what kills the "wrong magazine size" class of bugs: MaxAmmo is not
    inherited from whatever vanilla gun a script was copied from, it is DERIVED
    from the standard magazine's capacity (or internalCapacity) here.

    ------------------------------------------------------------------ schema
    {
      id          = "AK47",                 -- required, becomes ZGB.AK47
      archetype   = "assault_rifle",        -- required, see ZGB_Archetypes
      displayName = "AK-47",                -- required
      caliber     = "762x39",               -- required: a key of ZGB_AmmoCatalog.CALIBERS
                                            -- (spec.ammoVariants / spec.ammo are derived from it)
      magazines   = {                       -- mag-fed: ids from ZGB_Def_Magazines, one per tier
          standard = "AK47_Mag30",          --   required for mag-fed guns
          extended = "AK_Mag40",            --   optional, only if it exists for real
          drum     = "AK47_Drum75",         --   optional, only if it exists for real
      },
      internalCapacity = 6,                 -- cylinder / tube / internal box instead of magazines
      stats       = { ...overrides... },    -- anything set here is NOT caliber-scaled
      sounds      = { fire=, rack=, click=, insertAmmo=, ejectAmmo=, shellFall= },
      slots       = {                       -- what the bare gun physically has
         side_mount = { kind="mount", accepts={"ak_dovetail"}, label="Side mount", order=1 },
         ...
      },
      category    = "revolver",             -- optional: overrides the archetype's catalogue group
      rarity      = 0.3,                    -- loot weight next to its family (1 = as common as vanilla)
      model       = "ZGB_AK47",             -- optional: WeaponSprite once the 3D model exists
      notes       = "...",                  -- optional: shown in the catalogue (for the 3D side)
      fp          = { ... },                -- reserved for the first-person addon
    }
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_Archetypes"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/Factory/ZGB_MagazineFactory"

ZGB.WeaponFactory = ZGB.WeaponFactory or { _specs = {}, _order = {}, errors = {} }
local WF = ZGB.WeaponFactory
local MF = ZGB.MagazineFactory

local REQUIRED = { "id", "archetype", "displayName", "caliber" }
WF.MAG_FREE_RELOADS = { shotgun = true, boltactionnomag = true, revolver = true, doublebarrelshotgun = true }

-- How strongly muzzle energy moves each stat (stat *= (E / E_ref) ^ exponent).
WF.ENERGY_EXPONENT = { minDamage = 0.35, maxDamage = 0.35, range = 0.15, recoilDelay = 0.30, soundRadius = 0.20 }

--- Multiplier for `stat` of a gun in `caliberId` built on an archetype tuned for `refCaliber`.
function WF.caliberScale(stat, caliberId, refCaliber)
    local exp = WF.ENERGY_EXPONENT[stat]
    local cal, ref = ZGB.AmmoCatalog.CALIBERS[caliberId], ZGB.AmmoCatalog.CALIBERS[refCaliber or ""]
    if not exp or not cal or not ref or not cal.energy or not ref.energy then return 1 end
    return (cal.energy / ref.energy) ^ exp
end

local function round2(x) return math.floor(x * 100 + 0.5) / 100 end

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
        local magFed = not WF.MAG_FREE_RELOADS[spec.reloadType]
        local mags = def.magazines or {}
        for tier, magId in pairs(mags) do
            local m = MF.get(magId)
            if not MF.TIERS[tier] then
                errs[#errs + 1] = "magazines." .. tostring(tier) .. ": tiers are standard, extended, drum"
            elseif not m then
                errs[#errs + 1] = "magazines." .. tier .. ": unknown magazine '" .. tostring(magId) .. "'"
            elseif m.tier ~= tier then
                errs[#errs + 1] = "magazines." .. tier .. ": '" .. magId .. "' is tier " .. m.tier
            elseif m.caliber ~= def.caliber then
                errs[#errs + 1] = "magazines." .. tier .. ": '" .. magId .. "' is " .. m.caliber .. ", gun is " .. tostring(def.caliber)
            end
        end
        if magFed then
            if not mags.standard then errs[#errs + 1] = "mag-fed weapon needs magazines.standard" end
            if def.internalCapacity then errs[#errs + 1] = "mag-fed weapon can't have internalCapacity" end
        else
            if next(mags) then errs[#errs + 1] = spec.reloadType .. " weapon can't take magazines" end
            if type(spec.internalCapacity) ~= "number" or spec.internalCapacity < 1 then
                errs[#errs + 1] = "tube/internal weapon needs internalCapacity"
            end
        end
        for slotId, s in pairs(spec.slots or {}) do
            if not s.kind or type(s.accepts) ~= "table" or #s.accepts == 0 then
                errs[#errs + 1] = "slot '" .. slotId .. "' needs kind + accepts{}"
            end
        end
    end
    return errs
end

local function reject(def, errs)
    WF.errors[#WF.errors + 1] = { id = def.id, errors = errs }
    ZGB.err("Weapon '" .. tostring(def.id) .. "' rejected:", table.concat(errs, "; "))
    return nil, errs
end

--- Define and register a weapon. Returns spec, or nil + list of errors.
function WF.define(def)
    local errs = validate(def, nil)
    if #errs > 0 then return reject(def, errs) end

    local arch = ZGB.Archetypes[def.archetype]
    local spec = ZGB.merge(arch, def)
    spec.fullType = ZGB.fullType(def.id)
    spec.slots    = spec.slots or {}
    spec.sounds   = spec.sounds or {}
    spec.fp       = spec.fp or {}
    spec.category = def.category or arch.category
    spec.rarity   = def.rarity or 0.2

    errs = validate(def, spec)
    if #errs > 0 then return reject(def, errs) end

    -- Caliber decides punch, archetype decides handling, the definition overrides both.
    local own = def.stats or {}
    for stat in pairs(WF.ENERGY_EXPONENT) do
        if own[stat] == nil and spec.stats[stat] then
            spec.stats[stat] = round2(spec.stats[stat] * WF.caliberScale(stat, spec.caliber, arch.refCaliber))
        end
    end

    -- Derived values: the ONLY place ammo capacity is decided.
    -- spec.magazines = tier order (standard first); each a copy of the magazine spec + `default`.
    spec.magazines, spec.magazine = {}, nil
    for _, tier in ipairs(MF.TIER_ORDER) do
        local id = (def.magazines or {})[tier]
        if id then
            local m = ZGB.copy(MF.get(id))
            m.default = (tier == "standard")
            spec.magazines[#spec.magazines + 1] = m
            if m.default then spec.magazine = m end
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

--- Guns that take a given magazine item (shared magazines list several).
function WF.gunsForMagazine(magFullType)
    local out = {}
    for _, spec in ipairs(WF.all()) do
        for _, m in ipairs(spec.magazines) do
            if m.item == magFullType then out[#out + 1] = spec; break end
        end
    end
    return out
end

--- Testing helper.
function WF._reset() WF._specs, WF._order, WF.errors = {}, {}, {} end

return WF
