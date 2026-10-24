--[[
    ZGB_PartFactory.lua  —  Factory Method for attachments.

    A part declares:
      kind       what sort of slot it goes in       ("optic", "mount", "muzzle", ...)
      interface  the physical standard it uses      ("picatinny", "ak_dovetail", ...)
      provides   NEW slots it creates once installed (a mount provides an optic rail)
      mods       stat changes  { add = {aimTime=-3}, mul = {hitChance=1.10} }

    So "red dot on an AK needs a side-rail mount" is not a special case anywhere —
    it falls out of the data: the AK has no picatinny optic slot, the mount
    provides one, the red dot needs one.

    ------------------------------------------------------------------ schema
    {
      id          = "Optic_RedDot",          -- required, becomes ZGB.Optic_RedDot
      displayName = "Red Dot Sight",         -- required
      kind        = "optic",                 -- required
      interface   = "picatinny",             -- required
      provides    = { optic_rail = { kind="optic", accepts={"picatinny"}, label="Optic rail" } },
      mods        = { add = {...}, mul = {...} },
      attachTime  = 120,                     -- timed action ticks
      vanillaPartType = "Scope",             -- optional: also attach a vanilla WeaponPart
                                             -- so the 3D model renders (see ZGB_VanillaBridge)
      fp = { sightAlignment = { eyeOffset = {0, 0.045, 0}, zoom = 1.0 } },  -- reserved for FP addon
    }
]]
require "ZGB/ZGB_Core"

ZGB.PartFactory = ZGB.PartFactory or { _specs = {}, _order = {}, errors = {} }
local PF = ZGB.PartFactory

local REQUIRED = { "id", "displayName", "kind", "interface" }

function PF.define(def)
    local errs = {}
    for _, k in ipairs(REQUIRED) do
        if def[k] == nil then errs[#errs + 1] = "missing field '" .. k .. "'" end
    end
    for slotId, s in pairs(def.provides or {}) do
        if not s.kind or type(s.accepts) ~= "table" or #s.accepts == 0 then
            errs[#errs + 1] = "provided slot '" .. slotId .. "' needs kind + accepts{}"
        end
    end
    if #errs > 0 then
        PF.errors[#PF.errors + 1] = { id = def.id, errors = errs }
        ZGB.err("Part '" .. tostring(def.id) .. "' rejected:", table.concat(errs, "; "))
        return nil, errs
    end

    local spec = ZGB.copy(def)
    spec.fullType   = ZGB.fullType(def.id)
    spec.provides   = spec.provides or {}
    spec.mods       = spec.mods or {}
    spec.mods.add   = spec.mods.add or {}
    spec.mods.mul   = spec.mods.mul or {}
    spec.attachTime = spec.attachTime or 100
    spec.fp         = spec.fp or {}

    if not PF._specs[spec.fullType] then PF._order[#PF._order + 1] = spec.fullType end
    PF._specs[spec.fullType] = spec
    return spec
end

function PF.get(idOrFullType)
    if not idOrFullType then return nil end
    return PF._specs[ZGB.fullType(idOrFullType)]
end

function PF.all()
    local out = {}
    for i, ft in ipairs(PF._order) do out[i] = PF._specs[ft] end
    return out
end

function PF._reset() PF._specs, PF._order, PF.errors = {}, {}, {} end

return PF
