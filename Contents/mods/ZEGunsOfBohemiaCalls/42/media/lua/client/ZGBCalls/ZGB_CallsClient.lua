--[[
    ZGB_CallsClient.lua  —  listens to ZGB events and shows the callout over
    the character's head. Optional addon; sandbox page "ZGB", ZGBCalls.*
]]
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Sandbox"
require "ZGB/ZGB_Addons"
require "ZGB/ZGB_ItemBridge"
require "ZGBCalls/ZGB_Def_Calls"

local E, SB, I, C = ZGB.Events, ZGB.Sandbox, ZGB.Item, ZGB.Calls

ZGB.Addons.register{ id = "calls", name = "ZE Guns Of Bohemia - Callouts", modId = "ZEGunsOfBohemiaCalls", version = "0.6.0" }

local state = setmetatable({}, { __mode = "k" })      -- player -> cooldown state
local lastSpec = setmetatable({}, { __mode = "k" })   -- player -> previous gun spec (sidearm call)

local function clock() return (getTimestampMs and getTimestampMs() or os.time() * 1000) / 1000 end   -- VERIFY

local function options()
    return {
        now = clock(),
        cooldown = SB.get("ZGBCalls", "Cooldown", 4),
        enabled = {
            reloads  = SB.get("ZGBCalls", "Reloads", true),
            ammo     = SB.get("ZGBCalls", "Ammo", true),
            weapon   = SB.get("ZGBCalls", "Weapon", true),
            grenades = SB.get("ZGBCalls", "Grenades", true),
        },
        rng = function() return ZombRand(1000) / 1000 end,                         -- VERIFY ZombRand
    }
end

local function shout(event, payload)
    if not SB.get("ZGBCalls", "Enabled", true) then return end
    local player = payload and payload.player
    if not player then return end
    state[player] = state[player] or {}
    local line = C.pick(event, payload, state[player], options())
    if line then I.say(player, line) end
end

for _, event in ipairs({ "reload.start", "ammo.empty", "ammo.lastMag", "grenade.throw" }) do
    E.on(event, function(p) shout(event, p) end)
end
E.on("weapon.equip", function(p)
    local copy = {}
    for k, v in pairs(p) do copy[k] = v end
    copy.previous = lastSpec[p.player]
    lastSpec[p.player] = p.spec
    shout("weapon.equip", copy)
end)
E.on("weapon.unequip", function(p) lastSpec[p.player] = p.spec end)
