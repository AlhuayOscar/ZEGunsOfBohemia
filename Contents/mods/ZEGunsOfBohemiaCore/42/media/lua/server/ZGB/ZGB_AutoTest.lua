--[[
    ZGB_AutoTest.lua  —  the self-test, run by itself on a test server.

    tools/pzserver/ (a dedicated server on a scratch profile, see its README) starts the game
    with no graphics. When that profile has Lua/ZGB_autotest.txt, this runs the whole
    self-test once the server is up and writes Lua/ZGB_selftest.txt, then a last line
    "[ZGB][AUTOTEST] DONE <summary>" in the log so the tool knows it can stop the server.

    Without the trigger file it does nothing: players never run it.
]]
require "ZGB/ZGB_SelfTest"

local TRIGGER = "ZGB_autotest.txt"

local function triggered()
    if not getFileReader then return false end
    local r = getFileReader(TRIGGER, false)
    if not r then return false end
    r:close()
    return true
end

local function run()
    if ZGB._autotestDone or not triggered() then return end
    ZGB._autotestDone = true
    print("[ZGB][AUTOTEST] START")
    local ok, r = pcall(ZGB.SelfTest.run)
    if ok and r then
        print("[ZGB][AUTOTEST] DONE " .. tostring(r.summary))
    else
        print("[ZGB][AUTOTEST] DONE crashed: " .. tostring(r))
    end
end

if Events and Events.OnServerStarted then Events.OnServerStarted.Add(run) end
