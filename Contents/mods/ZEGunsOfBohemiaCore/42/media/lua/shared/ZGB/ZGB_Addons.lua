--[[
    ZGB_Addons.lua  —  registry of ZE Guns Of Bohemia addons.

    Every addon (ours or a third party's) announces itself here when it loads.
    Core uses the list to tell the player when an ESSENTIAL addon is missing,
    and addons use it to check for each other without reading mod ids.

      ZGB.Addons.register{ id = "reload", name = "Reloading", modId = "ZEGunsOfBohemiaReload",
                           version = "0.5.0", essential = true }
]]
require "ZGB/ZGB_Core"

ZGB.Addons = ZGB.Addons or { _list = {}, _byId = {} }
local AD = ZGB.Addons

-- Addons the mod is designed around: enable them together with Core.
AD.ESSENTIAL = {
    { id = "reload",  name = "ZE Guns Of Bohemia - Reloading",       modId = "ZEGunsOfBohemiaReload" },
    { id = "holding", name = "ZE Guns Of Bohemia - Tactical Holding", modId = "ZEGunsOfBohemiaHolding" },
}

function AD.register(def)
    assert(type(def) == "table" and def.id, "addon needs an id")
    if AD._byId[def.id] then
        ZGB.warn("Addon registered twice:", def.id)
        return AD._byId[def.id]
    end
    local a = ZGB.copy(def)
    AD._list[#AD._list + 1] = a
    AD._byId[a.id] = a
    ZGB.log("Addon loaded:", a.name or a.id, a.version or "")
    return a
end

function AD.has(id) return AD._byId[id] ~= nil end
function AD.get(id) return AD._byId[id] end
function AD.all() return AD._list end

--- Essential addons that did not register.
function AD.missingEssentials()
    local out = {}
    for _, e in ipairs(AD.ESSENTIAL) do
        if not AD.has(e.id) then out[#out + 1] = e end
    end
    return out
end

function AD._reset() AD._list, AD._byId = {}, {} end

return AD
