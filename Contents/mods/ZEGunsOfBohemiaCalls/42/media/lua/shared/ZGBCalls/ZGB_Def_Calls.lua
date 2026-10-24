--[[
    ZGB_Def_Calls.lua  —  the callouts. Higher priority wins when several match.
]]
require "ZGBCalls/ZGB_Calls"
require "ZGB/Factory/ZGB_AnimFactory"
local C = ZGB.Calls

local function kindIs(...)
    local set = {}
    for _, k in ipairs({ ... }) do set[k] = true end
    return function(p) return set[p.kind] == true end
end
local function feedIs(...)
    local set = {}
    for _, f in ipairs({ ... }) do set[f] = true end
    return function(p)
        local t = p.spec and ZGB.AnimFactory and ZGB.AnimFactory.getType(p.spec.animType)
        return t ~= nil and set[t.feed] == true and p.kind == "single"
    end
end

-- ---------------------------------------------------------------- reloads
C.defineCall{ id = "reload_tactical", event = "reload.start", category = "reloads", priority = 2,
              when = kindIs("tactical"), lines = { "CHANGING MAG!", "MAG CHANGE!", "TOPPING OFF!" } }
C.defineCall{ id = "reload_empty", event = "reload.start", category = "reloads", priority = 3,
              when = kindIs("empty"), lines = { "RELOADING!", "COVER ME, RELOADING!", "CHANGING MAG!" } }
C.defineCall{ id = "reload_shells", event = "reload.start", category = "reloads", priority = 2,
              when = function(p)
                  return p.kind == "single" and p.spec and (p.spec.caliber == "12ga" or p.spec.caliber == "410ga")
              end,
              lines = { "LOADING SHELLS!", "RELOADING!" } }
C.defineCall{ id = "reload_rounds", event = "reload.start", category = "reloads", priority = 1,
              when = feedIs("tube", "internal"), lines = { "LOADING!", "RELOADING!" } }
C.defineCall{ id = "reload_revolver", event = "reload.start", category = "reloads", priority = 2,
              when = kindIs("cylinder", "gate"), lines = { "RELOADING!", "SPEEDLOADING!" } }
C.defineCall{ id = "reload_break", event = "reload.start", category = "reloads", priority = 2,
              when = kindIs("break"), lines = { "RELOADING!" } }

-- ---------------------------------------------------------------- ammo
C.defineCall{ id = "out_of_ammo", event = "ammo.empty", category = "ammo", priority = 4,
              lines = { "I'M OUT!", "EMPTY!", "DRY!" } }
C.defineCall{ id = "last_mag", event = "ammo.lastMag", category = "ammo", priority = 3,
              lines = { "LAST MAG!", "LAST MAGAZINE!" } }

-- ---------------------------------------------------------------- weapon
C.defineCall{ id = "sidearm", event = "weapon.equip", category = "weapon", priority = 3,
              when = function(p)
                  local prev, now = p.previous, p.spec
                  return prev and now and (prev.category ~= "handgun" and prev.category ~= "revolver")
                         and (now.category == "handgun" or now.category == "revolver")
              end,
              lines = { "SWITCHING TO PISTOL!", "SIDEARM!" } }

-- ---------------------------------------------------------------- grenades (the grenade feature will emit these)
C.defineCall{ id = "frag_out", event = "grenade.throw", category = "grenades", priority = 5,
              when = function(p) return p.kind == nil or p.kind == "frag" end, lines = { "FRAG OUT!", "GRENADE!" } }
C.defineCall{ id = "smoke_out", event = "grenade.throw", category = "grenades", priority = 5,
              when = function(p) return p.kind == "smoke" end, lines = { "SMOKE OUT!" } }
C.defineCall{ id = "flash_out", event = "grenade.throw", category = "grenades", priority = 5,
              when = function(p) return p.kind == "flash" end, lines = { "FLASHBANG!", "FLASH OUT!" } }
