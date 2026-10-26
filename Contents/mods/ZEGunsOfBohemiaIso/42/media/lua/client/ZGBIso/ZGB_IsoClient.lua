--[[
    ZGB_IsoClient.lua  —  what the isometric view does while you play.

      * sets the AnimSet variables for the gun in hand (anim type, stance, kick)
        so the iso animation nodes can pick the right clip
      * recoil in iso: a burst gets a growing hit-chance penalty that follows
        the gun's spray pattern (no camera to move in iso), reset between bursts
      * case dropping: spent casings land next to the shooter on the ejection
        side, when the gun's anim type ejects them (fire, cycle or reload).
        Old casings are cleaned up after a while so saves don't fill with brass.

    Everything listens to ZGB events, so it does nothing if the essential
    addons that emit them are missing. Options: sandbox page "ZGB", ZGBIso.*
]]
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Sandbox"
require "ZGB/ZGB_Casings"
require "ZGB/ZGB_ItemBridge"
require "ZGBIso/ZGB_ViewIso"

local E, SB, I, RF, CS, AF = ZGB.Events, ZGB.Sandbox, ZGB.Item, ZGB.RecoilFactory, ZGB.Casings, ZGB.AnimFactory

local stanceOf = setmetatable({}, { __mode = "k" })   -- player -> current stance id

local function applyVariables(player, spec)
    if not ZGB.Mode.is("iso") then return end
    if not SB.get("ZGBIso", "CustomAnimations", false) then          -- vanilla animation: nodes never match
        I.setAnimVariable(player, "ZGB_AnimType", "none")
        return
    end
    local built = AF.build("iso", spec, stanceOf[player])
    if not built then return end
    for k, v in pairs(built.variables) do I.setAnimVariable(player, k, v) end
end

E.on("weapon.equip", function(p) applyVariables(p.player, p.spec) end)
E.on("weapon.unequip", function(p) I.setAnimVariable(p.player, "ZGB_AnimType", "none") end)
E.on("hold.changed", function(p)
    stanceOf[p.player] = p.stance
    if p.spec then applyVariables(p.player, p.spec) end
end)

-- ---------------------------------------------------------------- recoil (iso application)
E.on("weapon.fire", function(p)
    if not SB.get("ZGBIso", "RecoilPenalty", true) then return end
    local base = p.spec.stats.recoilDelay or 1
    local current = base
    pcall(function() current = p.gun:getRecoilDelay() end)                     -- VERIFY
    local r = RF.iso(p.spec, p.shot, base > 0 and current / base or 1)
    if r.hitPenalty > 0 then
        I.setTransient(p.gun, "recoil", { add = { hitChance = -r.hitPenalty } })
    elseif p.shot == 1 then
        I.setTransient(p.gun, "recoil", nil)
    end
end)

-- ---------------------------------------------------------------- case dropping
local pending, dropped = {}, {}   -- delayed drops; dropped world items with their time

local function clock() return (getTimestampMs and getTimestampMs() or os.time() * 1000) / 1000 end    -- VERIFY

local function drop(player, c)
    local dx, dy = I.facing(player)
    for i = 1, c.count do
        local ox, oy = CS.offset(c.side, dx, dy, 0.35 + 0.1 * ZombRand(4))          -- VERIFY ZombRand
        local wi = I.dropWorldItem(player, c.item, ox, oy)
        if wi then dropped[#dropped + 1] = { item = wi, t = clock() } end
    end
    local cap = SB.get("ZGBIso", "MaxCasings", 60)
    while #dropped > cap do I.removeWorldItem(table.remove(dropped, 1).item) end
end

local function queue(player, c)
    if not c or not SB.get("ZGBIso", "Casings", true) then return end
    if (c.delay or 0) <= 0 then drop(player, c)
    else pending[#pending + 1] = { at = clock() + c.delay, player = player, c = c } end
end

E.on("weapon.fire", function(p) queue(p.player, CS.forEvent(p.spec, "fire", p)) end)
E.on("reload.start", function(p) queue(p.player, CS.forEvent(p.spec, "reload", p)) end)

Events.OnTick.Add(function()
    if #pending == 0 then return end
    local t = clock()
    for i = #pending, 1, -1 do
        if pending[i].at <= t then
            local job = table.remove(pending, i)
            drop(job.player, job.c)
        end
    end
end)

Events.EveryOneMinute.Add(function()
    local life = SB.get("ZGBIso", "CasingLifetime", 10) * 60
    if life <= 0 then return end
    local t = clock()
    while dropped[1] and (t - dropped[1].t) > life do
        I.removeWorldItem(table.remove(dropped, 1).item)
    end
end)
