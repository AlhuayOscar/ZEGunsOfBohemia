--[[
    ZGB_Events.lua  —  the mod's own event bus (pure Lua, testable).

    Systems talk through named events instead of calling each other, so the
    essential addons (reload, holding, calls) and the view addons (iso, later
    first person) can each be added or removed without touching the others:

      reload addon   emits  reload.start / reload.step / reload.complete
      core           emits  weapon.fire / weapon.equip / weapon.unequip / ammo.empty
      holding addon  emits  hold.changed
      calls addon    listens to everything above and shouts about it
      iso addon      listens to fire / reload / hold to animate and drop casings

    Listeners run in pcall: a broken listener logs an error and never stops
    the others or the game.

    Known events and their payload (all tables):
      weapon.fire      { player, gun, spec, shot = n (1 = first shot of a burst) }
      weapon.equip     { player, gun, spec }
      weapon.unequip   { player, spec }
      ammo.empty       { player, gun, spec }
      ammo.lastMag     { player, gun, spec }
      reload.start     { player, gun, spec, kind, duration }
      reload.step      { player, gun, spec, kind, step, index }
      reload.complete  { player, gun, spec, kind }
      hold.changed     { player, spec, stance, level }
      grenade.throw    { player, kind }            -- reserved for the grenade feature
]]
require "ZGB/ZGB_Core"

ZGB.Events = ZGB.Events or { _listeners = {} }
local E = ZGB.Events

--- Subscribe. Returns the listener so it can be removed with E.off.
function E.on(name, fn)
    assert(type(fn) == "function", "listener must be a function")
    E._listeners[name] = E._listeners[name] or {}
    table.insert(E._listeners[name], fn)
    return fn
end

function E.off(name, fn)
    local list = E._listeners[name]
    if not list then return end
    for i = #list, 1, -1 do if list[i] == fn then table.remove(list, i) end end
end

--- Emit to every listener of `name`. Returns how many listeners ran without error.
function E.emit(name, payload)
    local ok_count = 0
    for _, fn in ipairs(E._listeners[name] or {}) do
        local ok, err = pcall(fn, payload or {})
        if ok then ok_count = ok_count + 1
        else ZGB.err("Listener for", name, "failed:", err) end
    end
    return ok_count
end

--- Testing helper.
function E._reset() E._listeners = {} end

return E
