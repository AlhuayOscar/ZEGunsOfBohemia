--[[
    ZGB_Core.lua  —  ZE Guns Of Bohemia core namespace + small utilities.

    Everything in the mod hangs off the global table `ZGB`.
    This file has NO game-API calls so it can be unit-tested outside the game.
]]

ZGB = ZGB or {}

ZGB.VERSION = "0.8.0"
ZGB.MODULE  = "ZGB"          -- script module of our items: ZGB.AK47, ZGB.Optic_RedDot, ...
ZGB.DEBUG   = (getDebug ~= nil and getDebug()) or false

-- ---------------------------------------------------------------- logging
local function join(...)
    local n = select("#", ...)
    local parts = {}
    for i = 1, n do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, " ")
end

function ZGB.log(...)   print("[ZGB] " .. join(...)) end
function ZGB.warn(...)  print("[ZGB][WARN] " .. join(...)) end
function ZGB.err(...)   print("[ZGB][ERROR] " .. join(...)) end
function ZGB.debug(...) if ZGB.DEBUG then print("[ZGB][DBG] " .. join(...)) end end

-- ---------------------------------------------------------------- tables
--- True when the table has no entries. PZ's Kahlua has no `next`, so never call it.
function ZGB.isEmpty(t)
    for _ in pairs(t or {}) do return false end
    return true
end

function ZGB.copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = ZGB.copy(v) end
    return out
end

--- Deep merge: returns a NEW table = base overlaid with `over`.
--- Arrays (tables with [1]) in `over` replace, they are not merged.
function ZGB.merge(base, over)
    local out = ZGB.copy(base or {})
    for k, v in pairs(over or {}) do
        if type(v) == "table" and type(out[k]) == "table" and v[1] == nil then
            out[k] = ZGB.merge(out[k], v)
        else
            out[k] = ZGB.copy(v)
        end
    end
    return out
end

function ZGB.contains(list, value)
    if not list then return false end
    for _, v in ipairs(list) do if v == value then return true end end
    return false
end

function ZGB.sortedKeys(t, orderFn)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, orderFn or function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

--- "ZGB.AK47" -> "ZGB.AK47", "AK47" -> "ZGB.AK47"
function ZGB.fullType(idOrFullType)
    if string.find(idOrFullType, ".", 1, true) then return idOrFullType end
    return ZGB.MODULE .. "." .. idOrFullType
end

return ZGB
