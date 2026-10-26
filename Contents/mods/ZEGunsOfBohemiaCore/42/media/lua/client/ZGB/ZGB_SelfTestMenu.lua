--[[
    ZGB_SelfTestMenu.lua  —  debug mode only: right-click the ground for

      ZGB: run self-test   checks every gun, magazine, round and part (ZGB_SelfTest),
                           shows the summary over your head; details in console.txt
                           ([ZGB][TEST]) and Zomboid/Lua/ZGB_selftest.txt
      ZGB: pose check      equips one gun of every animation type, aims, takes a screenshot of
                           each (ZGB_pose_<type>_<gun>) and records the animation variables
                           in Zomboid/Lua/ZGB_poses.txt
      ZGB: give test kit   Glock 17, AK-47, Remington 870, full magazines, rounds, a suppressor
      ZGB: give ALL guns   every gun (empty) and one of every attachment, to look at the models
]]
require "ZGB/ZGB_SelfTest"

local function debugOn()
    local ok, on = pcall(function() return isDebugEnabled() end)
    return ok and on
end

local function runSelfTest(player)
    local r = ZGB.SelfTest.run()
    local where = r.written and ("Zomboid/Lua/" .. ZGB.SelfTest.FILE) or "console.txt"
    ZGB.Item.say(player, string.format("ZGB self-test: %d FAIL, %d pass, %d skip - %s", r.fail, r.pass, r.skip, where))
end

local function giveKit(player)
    local n = ZGB.SelfTest.giveKit(player)
    ZGB.Item.say(player, "ZGB test kit: " .. n .. " guns with magazines and rounds")
end

local function giveAll(player)
    local guns, parts = ZGB.SelfTest.giveAll(player)
    ZGB.Item.say(player, "ZGB: " .. guns .. " guns and " .. parts .. " attachments")
end

-- one pose session at a time, stepped every tick until it is done
local session
local function poseTick()
    if not session then return end
    -- an error must END the check: once it broke into the debugger on every tick and left
    -- the character unable to shove or shoot
    local ok, finished = pcall(session.step, session)
    if not ok then
        ZGB.err("Pose check stopped:", tostring(finished))
        pcall(session.abort, session, tostring(finished))
        finished = true
    end
    if finished then
        local s = session
        session = nil
        Events.OnTick.Remove(poseTick)
        ZGB.Item.say(s.player, string.format("ZGB pose check: %d screenshots, %d FAIL - Zomboid/Lua/%s",
            #s.shots, s.report.fail, ZGB.SelfTest.POSE_FILE))
    end
end

--- Emergency: hands, aim and actions back to normal (after a test went wrong).
local function resetCharacter(player)
    if session then pcall(session.abort, session, "reset by the player"); session = nil; Events.OnTick.Remove(poseTick) end
    ZGB.SelfTest.resetCharacter(player)
    ZGB.Item.say(player, "ZGB: character reset")
end

local function poseCheck(player)
    if session then return end
    session = ZGB.SelfTest.newPoseSession(player)
    session.player = player
    ZGB.Item.say(player, "ZGB pose check: " .. #session.guns .. " guns, don't move for a minute")
    Events.OnTick.Add(poseTick)
end

local function onFillWorldMenu(playerNum, context)
    if not debugOn() then return end
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    context:addOption("ZGB: run self-test", player, runSelfTest)
    if not session then context:addOption("ZGB: pose check (screenshots)", player, poseCheck) end
    context:addOption("ZGB: give test kit", player, giveKit)
    context:addOption("ZGB: give ALL guns + attachments", player, giveAll)
    context:addOption("ZGB: reset character (if stuck)", player, resetCharacter)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
