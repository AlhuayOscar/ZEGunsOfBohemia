--[[
    ZGB_Casings.lua  —  where and when spent casings come out (pure logic).

    The anim type decides WHEN (Defs/ZGB_Def_Anims.lua, `casing`):
      on = "fire"    every shot; `delay` is the time until the action cycles
                     (0 for semi-autos, ~0.5 s for bolt / pump / lever)
      on = "reload"  revolvers and break-actions keep their empties until reloaded
      on = "none"    nothing comes out
    The caliber decides WHAT (ZGB_AmmoCatalog.casingFor).

    A view turns the result into something visible: the iso addon drops a
    casing item on the ground next to the shooter, the FP addon will spawn a
    physical casing from the ejection port.
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/Factory/ZGB_AnimFactory"

ZGB.Casings = ZGB.Casings or {}
local CS = ZGB.Casings

--[[ event: "fire" or "reload".
     payload.spent: rounds fired since the last reload (reload events).
     returns { item, count, delay, side } or nil when nothing drops ]]
function CS.forEvent(spec, event, payload)
    local t = ZGB.AnimFactory.getType(spec.animType)
    local rule = t and t.casing
    if not rule or rule.on ~= event then return nil end
    local item = ZGB.AmmoCatalog.casingFor(spec.caliber)
    if not item then return nil end
    local count = 1
    if event == "reload" then
        count = math.min((payload and payload.spent) or 0, spec.maxAmmo or 0)
        if count <= 0 then return nil end
    end
    return { item = item, count = count, delay = rule.delay or 0, side = rule.side or "right" }
end

--- Tile offset for a casing thrown to `side` of a shooter facing (dx, dy).
function CS.offset(side, dx, dy, spread)
    spread = spread or 0.5
    if side == "right" then return -dy * spread, dx * spread end
    if side == "up" then return -dy * spread * 0.6, dx * spread * 0.6 end
    return 0, 0          -- "down": at the shooter's feet
end

return CS
