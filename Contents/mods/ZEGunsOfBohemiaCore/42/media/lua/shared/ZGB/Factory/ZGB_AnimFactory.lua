--[[
    ZGB_AnimFactory.lua  —  Factory Method for gun animation.

    Two layers, same idea as weapons (archetype -> gun):

      ANIM TYPES  how a kind of gun MOVES, independent of the camera:
                  its abstract clips (idle, aim, fire, magOut, loadRound ...),
                  reload sequences, clip timings and where spent casings go.
                  Defined in Defs/ZGB_Def_Anims.lua. A type can extend another
                  (`base`), so a bullpup only states what differs from a rifle.

      VIEWS       an APPLICATION of the factory to one camera. A view maps each
                  abstract clip to the real animation it plays (vanilla skeleton
                  clips for now) plus the script params the game needs.
                  The isometric addon defines view "iso"; the first-person addon
                  will define "fp" with its own clips and never touch iso's.

    A gun picks its anim type through `spec.animType` (archetype default,
    overridable per gun). Holding stances (see the holding addon) are clip
    VARIANTS: a view may define "idle@novice" next to "idle"; resolve() falls
    back to the plain clip when a stance has no variant of its own.

    ------------------------------------------------------------------ type schema
    {
      id       = "rifle",
      base     = nil,                         -- optional parent type
      label    = "Rifle (magazine)",
      hands    = "two",                       -- "one" | "two"
      feed     = "magazine",                  -- magazine | tube | cylinder | gate | break | internal
      clips    = { "idle", "aim", "fire", "magOut", ... },     -- abstract clips this type uses
      timings  = { magOut = 0.6, magIn = 0.8, ... },          -- seconds at reload skill 0
      reloads  = {                                             -- kind -> steps
          tactical = { "magOut", "magIn" },
          empty    = { "magDrop", "magIn", "chargingHandle" },
          single   = { { clip = "loadRound", perRound = true }, { clip = "cycle", ifEmpty = true } },
      },
      internalReload = "single",              -- reload kind for guns without magazines
      casing   = { on = "fire", delay = 0, side = "right" },   -- fire | reload | none
    }
]]
require "ZGB/ZGB_Core"

ZGB.AnimFactory = ZGB.AnimFactory or { _types = {}, _views = {}, errors = {} }
local AF = ZGB.AnimFactory

AF.STANCE_SEP = "@"

-- ---------------------------------------------------------------- anim types
function AF.defineType(def)
    local errs = {}
    if not def.id then errs[#errs + 1] = "missing id" end
    if def.base and not AF._types[def.base] then errs[#errs + 1] = "unknown base '" .. tostring(def.base) .. "'" end
    if #errs > 0 then
        AF.errors[#AF.errors + 1] = { id = def.id, errors = errs }
        ZGB.err("Anim type '" .. tostring(def.id) .. "' rejected:", table.concat(errs, "; "))
        return nil, errs
    end
    local t = def.base and ZGB.merge(AF._types[def.base], def) or ZGB.copy(def)
    t.base = def.base
    t.timings = t.timings or {}
    t.reloads = t.reloads or {}
    t.casing  = t.casing or { on = "none" }
    t.clips   = t.clips or {}
    AF._types[t.id] = t
    return t
end

function AF.getType(id) return AF._types[id] end
function AF.types()
    local out = {}
    for _, id in ipairs(ZGB.sortedKeys(AF._types)) do out[#out + 1] = AF._types[id] end
    return out
end

--- The type and its ancestors, nearest first: { rifle_bullpup, rifle }.
function AF.lineage(typeId)
    local out, seen, t = {}, {}, AF._types[typeId]
    while t and not seen[t.id] do
        out[#out + 1] = t; seen[t.id] = true
        t = t.base and AF._types[t.base] or nil
    end
    return out
end

-- ---------------------------------------------------------------- reload sequences
--[[ Steps for one reload, with base durations (seconds, before skill / tier factors).
     kind:    tactical | empty | single | cylinder | gate | break
     rounds:  rounds to load (per-round steps repeat this many times)
     empty:   the gun was empty (ifEmpty steps run only then)
     returns { { clip, duration }, ... } or nil if the type has no such reload ]]
function AF.sequence(typeId, kind, rounds, empty)
    local t = AF._types[typeId]
    local steps = t and t.reloads[kind]
    if not steps then return nil end
    local out = {}
    local function add(clip) out[#out + 1] = { clip = clip, duration = t.timings[clip] or 0.5 } end
    for _, s in ipairs(steps) do
        if type(s) == "string" then add(s)
        elseif s.perRound then for _ = 1, math.max(0, rounds or 0) do add(s.clip) end
        elseif s.ifEmpty then if empty then add(s.clip) end
        else add(s.clip) end
    end
    return out
end

function AF.totalDuration(seq)
    local t = 0
    for _, s in ipairs(seq or {}) do t = t + s.duration end
    return t
end

-- ---------------------------------------------------------------- views
--[[ view schema:
     {
       id = "iso",
       defaults = { [clip] = { anim = "...", speed = 1 } , ["idle@novice"] = {...} },
       types    = { [animTypeId] = { [clip or clip@stance] = { anim=, speed= } } },
       scriptParams = { [animTypeId] = { SwingAnim = "Rifle", ... } },   -- inherited through `base`
       variables    = function(spec, stance) return { ... } end,         -- optional extra anim variables
     } ]]
function AF.defineView(def)
    assert(type(def) == "table" and def.id, "view needs an id")
    local v = ZGB.copy(def)
    v.variables = def.variables
    v.defaults, v.types, v.scriptParams = v.defaults or {}, v.types or {}, v.scriptParams or {}
    AF._views[v.id] = v
    return v
end

function AF.getView(id) return AF._views[id] end

--- Real animation for an abstract clip. Search order:
---   type@stance, type, parent types (same order), view default@stance, view default.
function AF.resolve(viewId, typeId, clip, stance)
    local v = AF._views[viewId]
    if not v then return nil end
    local keys = {}
    if stance then keys[#keys + 1] = clip .. AF.STANCE_SEP .. stance end
    keys[#keys + 1] = clip
    for _, t in ipairs(AF.lineage(typeId)) do
        local map = v.types[t.id]
        if map then
            for _, k in ipairs(keys) do if map[k] then return map[k], t.id, k end end
        end
    end
    for _, k in ipairs(keys) do if v.defaults[k] then return v.defaults[k], "default", k end end
    return nil
end

--- Vanilla script params (SwingAnim...) a view gives an anim type, following its `base`.
function AF.scriptParams(viewId, typeId)
    local v = AF._views[viewId]
    if not v then return nil end
    for _, t in ipairs(AF.lineage(typeId)) do
        if v.scriptParams[t.id] then return v.scriptParams[t.id] end
    end
    return v.scriptParams.default
end
local function scriptParamsFor(v, typeId) return AF.scriptParams(v.id, typeId) end

--[[ Everything a view needs for one gun:
     { animType, scriptParams, clips = { [clip] = resolved }, variables = { ... } } ]]
function AF.build(viewId, spec, stance)
    local v = AF._views[viewId]
    if not v then return nil end
    local typeId = spec.animType
    local out = { animType = typeId, clips = {}, scriptParams = {}, variables = {} }
    for k, val in pairs(scriptParamsFor(v, typeId) or {}) do out.scriptParams[k] = val end
    -- per-gun override hook: spec.anim = { iso = { SwingAnim = "..." } }
    for k, val in pairs(((spec.anim or {})[viewId]) or {}) do out.scriptParams[k] = val end
    local t = AF._types[typeId]
    for _, clip in ipairs(t and t.clips or {}) do out.clips[clip] = AF.resolve(viewId, typeId, clip, stance) end
    out.variables.ZGB_AnimType = typeId
    out.variables.ZGB_Stance = stance or "none"
    if v.variables then
        for k, val in pairs(v.variables(spec, stance) or {}) do out.variables[k] = val end
    end
    return out
end

--- Abstract clips of `typeId` that `viewId` can't resolve (should be empty).
function AF.missingClips(viewId, typeId)
    local out, t = {}, AF._types[typeId]
    for _, clip in ipairs(t and t.clips or {}) do
        if not AF.resolve(viewId, typeId, clip) then out[#out + 1] = clip end
    end
    return out
end

function AF._resetViews() AF._views = {} end

return AF
