--[[
    ZGB_Calls.lua  —  callouts: the character shouts what they're doing (pure logic).

    Optional addon. Every call is data: which event triggers it, an optional
    condition on the event payload, a category (sandbox can switch whole
    categories off), a priority and a few lines to pick from.

      ZGB.Calls.defineCall{ id = "frag_out", event = "grenade.throw", category = "grenades",
                            when = function(p) return p.kind == "frag" end,
                            lines = { "FRAG OUT!" } }

    A shared cooldown per character stops the same voice spamming; a call
    with a higher priority than the last one may interrupt the cooldown.
]]
require "ZGB/ZGB_Core"

ZGB.Calls = ZGB.Calls or { _calls = {}, _byEvent = {} }
local C = ZGB.Calls

C.CATEGORIES = { "reloads", "ammo", "weapon", "grenades" }

function C.defineCall(def)
    assert(def and def.id and def.event and def.lines and #def.lines > 0, "call needs id, event, lines")
    local c = ZGB.copy(def)
    c.when = def.when
    c.priority = c.priority or 1
    c.category = c.category or "weapon"
    C._calls[c.id] = c
    C._byEvent[c.event] = C._byEvent[c.event] or {}
    table.insert(C._byEvent[c.event], c)
    table.sort(C._byEvent[c.event], function(a, b) return a.priority > b.priority end)
    return c
end

function C.forEvent(event) return C._byEvent[event] or {} end

--[[ The line to shout for an event, or nil.
     state: per character { lastAt, lastPriority } (updated when a line is picked)
     opts:  { now = seconds, cooldown = seconds, enabled = { reloads = true, ... }, rng = fn() -> [0,1) }
     returns line, call ]]
function C.pick(event, payload, state, opts)
    opts = opts or {}
    local now, cooldown = opts.now or 0, opts.cooldown or 4
    for _, c in ipairs(C.forEvent(event)) do
        local on = not opts.enabled or opts.enabled[c.category] ~= false
        if on and (not c.when or c.when(payload or {})) then
            local cooling = state.lastAt and (now - state.lastAt) < cooldown
            if cooling and c.priority <= (state.lastPriority or 0) then return nil end
            local r = opts.rng and opts.rng() or 0
            local line = c.lines[math.floor(r * #c.lines) + 1] or c.lines[1]
            state.lastAt, state.lastPriority = now, c.priority
            return line, c
        end
    end
    return nil
end

return C
