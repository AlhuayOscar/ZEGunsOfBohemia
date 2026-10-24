--[[
    ZGB_Holding.lua  —  tactical holding: how a character carries a gun (pure logic).

    Essential addon. A STANCE is how the gun is held at rest and on the way to
    the aim: a novice carries it low and shaky and is slow to raise it, an
    expert holds a high, compressed ready and snaps onto target.

      iso   the stance picks the idle / aim clip variants ("idle@novice" ...)
            of the iso view. Cosmetic only: stats don't change.
      fp    (future) the stance is passive, not chosen: the first-person
            addon reads fpPassive(level) for weapon sway, bob and settle time,
            so an inexperienced shooter's idle hold visibly wanders.

    Which stance a character gets:
      by Aiming level (default), thresholds from sandbox options; or
      "level cap disabled" (UseAimingLevel = false): everyone uses FixedStance.

    Stances are a small factory too, so addons can add their own:
      ZGB.Holding.defineStance{ id = "operator", minLevel = 10, label = "Operator", fp = {...} }
]]
require "ZGB/ZGB_Core"

ZGB.Holding = ZGB.Holding or { _stances = {}, _order = {} }
local H = ZGB.Holding

--- fp: sway = idle wander (1 = baseline), bob = walk bob, settle = seconds to steady after raising
function H.defineStance(def)
    assert(def and def.id and def.minLevel, "stance needs id + minLevel")
    if not H._stances[def.id] then H._order[#H._order + 1] = def.id end
    H._stances[def.id] = ZGB.copy(def)
    table.sort(H._order, function(a, b) return H._stances[a].minLevel < H._stances[b].minLevel end)
    return H._stances[def.id]
end

function H.get(id) return H._stances[id] end
function H.all()
    local out = {}
    for i, id in ipairs(H._order) do out[i] = H._stances[id] end
    return out
end

H.defineStance{ id = "novice",     minLevel = 0, label = "Novice: low carry, shaky",
                fp = { sway = 1.8, bob = 1.4, settle = 0.9 } }
H.defineStance{ id = "trained",    minLevel = 3, label = "Trained: low ready",
                fp = { sway = 1.3, bob = 1.15, settle = 0.6 } }
H.defineStance{ id = "proficient", minLevel = 6, label = "Proficient: steady ready",
                fp = { sway = 1.0, bob = 1.0, settle = 0.4 } }
H.defineStance{ id = "expert",     minLevel = 9, label = "Expert: high compressed ready",
                fp = { sway = 0.7, bob = 0.85, settle = 0.25 } }

-- Sandbox FixedStance (enum 1..4) -> stance id
H.FIXED = { "novice", "trained", "proficient", "expert" }

--[[ opts (all optional, normally from sandbox):
       enabled          false -> nil (vanilla holding)
       useLevel         false -> the fixed stance for everyone ("level cap disabled")
       fixed            stance id used when useLevel is false (default "expert")
       thresholds       { trained = 3, proficient = 6, expert = 9 } overrides minLevel
     returns stance id or nil ]]
function H.stanceFor(level, opts)
    opts = opts or {}
    if opts.enabled == false then return nil end
    if opts.useLevel == false then return opts.fixed or "expert" end
    level = level or 0
    local pick = H._order[1]
    for _, id in ipairs(H._order) do
        local min = (opts.thresholds and opts.thresholds[id]) or H._stances[id].minLevel
        if level >= min then pick = id end
    end
    return pick
end

--- First-person passive hold for an Aiming level: stance values blended toward the next stance.
function H.fpPassive(level)
    level = math.max(0, math.min(10, level or 0))
    local list = H.all()
    for i = #list, 1, -1 do
        local s = list[i]
        if level >= s.minLevel then
            local nxt = list[i + 1]
            if not nxt then return ZGB.copy(s.fp) end
            local t = (level - s.minLevel) / (nxt.minLevel - s.minLevel)
            local out = {}
            for k, v in pairs(s.fp) do out[k] = v + (nxt.fp[k] - v) * t end
            return out
        end
    end
    return ZGB.copy(list[1].fp)
end

--- Sandbox options -> opts for stanceFor.
function H.optionsFromSandbox(SB)
    return {
        enabled  = SB.get("ZGBHolding", "Enabled", true),
        useLevel = SB.get("ZGBHolding", "UseAimingLevel", true),
        fixed    = H.FIXED[SB.get("ZGBHolding", "FixedStance", 4)] or "expert",
        thresholds = {
            trained    = SB.get("ZGBHolding", "TrainedLevel", 3),
            proficient = SB.get("ZGBHolding", "ProficientLevel", 6),
            expert     = SB.get("ZGBHolding", "ExpertLevel", 9),
        },
    }
end

return H
