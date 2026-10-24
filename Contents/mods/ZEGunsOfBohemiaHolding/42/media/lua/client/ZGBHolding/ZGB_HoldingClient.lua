--[[
    ZGB_HoldingClient.lua  —  keeps each player's holding stance up to date.

    Recomputed when a ZGB gun is equipped and when the Aiming skill levels up,
    then announced as hold.changed. The view addon in use (iso now, fp later)
    turns the stance into animation; this file never touches animation itself.
]]
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Sandbox"
require "ZGB/ZGB_Addons"
require "ZGB/ZGB_ItemBridge"
require "ZGBHolding/ZGB_Holding"

local E, SB, I, H = ZGB.Events, ZGB.Sandbox, ZGB.Item, ZGB.Holding

ZGB.Addons.register{ id = "holding", name = "ZE Guns Of Bohemia - Tactical Holding", modId = "ZEGunsOfBohemiaHolding",
                     version = "0.6.0", essential = true }

local current = setmetatable({}, { __mode = "k" })   -- player -> { stance, spec }

local function refresh(player, spec, force)
    if not player or not spec then return end
    local level = I.perkLevel(player, "Aiming")
    local stance = H.stanceFor(level, H.optionsFromSandbox(SB))
    local c = current[player]
    if force or not c or c.stance ~= stance or c.spec ~= spec then
        current[player] = { stance = stance, spec = spec }
        E.emit("hold.changed", { player = player, spec = spec, stance = stance, level = level,
                                 fp = H.fpPassive(level) })
    end
end

E.on("weapon.equip", function(p) refresh(p.player, p.spec, true) end)
E.on("weapon.unequip", function(p) current[p.player] = nil end)

if Events.LevelPerk then                                                       -- VERIFY event name / args
    Events.LevelPerk.Add(function(character, perk)
        local c = current[character]
        if c and tostring(perk) == "Aiming" then refresh(character, c.spec, false) end
    end)
end
