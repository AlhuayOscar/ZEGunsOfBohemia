--[[
    ZGB_Def_Anims.lua  —  how each kind of gun moves (camera-independent).

    Clips are abstract names; each view (iso, fp) maps them to real animations.
    Timings are seconds at Reloading 0 and are scaled by the reload addon.
    Reload kinds:
      tactical  magazine swap with a round still chambered (keep the old mag)
      empty     slide/bolt locked back: drop the mag, insert, release
      single    one round at a time (tube shotguns, lever actions, internal-box bolt guns)
      cylinder  swing-out revolver: dump all, load, close
      gate      loading-gate revolver: one chamber at a time
      break     break-action: open, extract, load, close
]]
require "ZGB/Factory/ZGB_AnimFactory"
local AF = ZGB.AnimFactory

local BASE_CLIPS = { "idle", "aim", "fire", "draw", "holster" }
local function clips(extra)
    local out = {}
    for _, c in ipairs(BASE_CLIPS) do out[#out + 1] = c end
    for _, c in ipairs(extra) do out[#out + 1] = c end
    return out
end
local MAG_CLIPS = { "magOut", "magDrop", "magIn" }

-- ---------------------------------------------------------------- magazine-fed
AF.defineType{
    id = "handgun", label = "Handgun (magazine)", hands = "one", feed = "magazine",
    clips = clips{ "magOut", "magDrop", "magIn", "boltRelease" },
    timings = { magOut = 0.5, magDrop = 0.25, magIn = 0.7, boltRelease = 0.3, draw = 0.5, holster = 0.6 },
    reloads = {
        tactical = { "magOut", "magIn" },
        empty    = { "magDrop", "magIn", "boltRelease" },
    },
    casing = { on = "fire", delay = 0, side = "right" },
}
AF.defineType{
    id = "rifle", label = "Rifle / carbine (magazine)", hands = "two", feed = "magazine",
    clips = clips{ "magOut", "magDrop", "magIn", "chargingHandle" },
    timings = { magOut = 0.7, magDrop = 0.3, magIn = 0.9, chargingHandle = 0.6, draw = 0.8, holster = 0.9 },
    reloads = {
        tactical = { "magOut", "magIn" },
        empty    = { "magDrop", "magIn", "chargingHandle" },
    },
    casing = { on = "fire", delay = 0, side = "right" },
}
AF.defineType{
    id = "smg", base = "rifle", label = "Submachine gun",
    timings = { magOut = 0.6, magIn = 0.8, chargingHandle = 0.5, draw = 0.6, holster = 0.7 },
}
AF.defineType{
    id = "bullpup", base = "rifle", label = "Bullpup (magazine behind the grip)",
    timings = { magOut = 0.8, magIn = 1.1, chargingHandle = 0.7 },
}
AF.defineType{
    id = "bolt_mag", label = "Bolt action (detachable magazine)", hands = "two", feed = "magazine",
    manualAction = true,          -- racked by hand after every shot (vanilla RackAfterShoot)
    clips = clips{ "cycle", "magOut", "magDrop", "magIn", "openAction", "closeAction" },
    timings = { cycle = 0.7, magOut = 0.7, magDrop = 0.3, magIn = 0.9, openAction = 0.4, closeAction = 0.4, draw = 0.9, holster = 1.0 },
    reloads = {
        tactical = { "magOut", "magIn" },
        empty    = { "magDrop", "magIn", "openAction", "closeAction" },
    },
    casing = { on = "fire", delay = 0.5, side = "right" },   -- ejected when the bolt is cycled
}

-- ---------------------------------------------------------------- internal / tube
AF.defineType{
    id = "bolt_internal", base = "bolt_mag", label = "Bolt action (internal box)", feed = "internal",
    clips = clips{ "cycle", "openAction", "loadRound", "closeAction" },
    timings = { loadRound = 0.55 },
    reloads = { single = { "openAction", { clip = "loadRound", perRound = true }, "closeAction" } },
    internalReload = "single",
}
AF.defineType{
    id = "lever", label = "Lever action", hands = "two", feed = "tube", manualAction = true,
    clips = clips{ "cycle", "loadRound" },
    timings = { cycle = 0.45, loadRound = 0.6, draw = 0.8, holster = 0.9 },
    reloads = { single = { { clip = "loadRound", perRound = true }, { clip = "cycle", ifEmpty = true } } },
    internalReload = "single",
    casing = { on = "fire", delay = 0.35, side = "up" },     -- lever throws the case up and out
}
AF.defineType{
    id = "pump", label = "Pump-action shotgun", hands = "two", feed = "tube", manualAction = true,
    clips = clips{ "cycle", "loadRound" },
    timings = { cycle = 0.5, loadRound = 0.55, draw = 0.8, holster = 0.9 },
    reloads = { single = { { clip = "loadRound", perRound = true }, { clip = "cycle", ifEmpty = true } } },
    internalReload = "single",
    casing = { on = "fire", delay = 0.4, side = "right" },
}
AF.defineType{
    id = "semi_shotgun", base = "pump", label = "Semi-automatic shotgun", manualAction = false,
    clips = clips{ "loadRound", "boltRelease" },
    timings = { boltRelease = 0.3 },
    reloads = { single = { { clip = "loadRound", perRound = true }, { clip = "boltRelease", ifEmpty = true } } },
    casing = { on = "fire", delay = 0, side = "right" },
}
AF.defineType{
    id = "break_action", label = "Break-action shotgun", hands = "two", feed = "break",
    clips = clips{ "breakOpen", "extract", "loadRound", "breakClose" },
    timings = { breakOpen = 0.4, extract = 0.3, loadRound = 0.5, breakClose = 0.35, draw = 0.8, holster = 0.9 },
    reloads = { ["break"] = { "breakOpen", "extract", { clip = "loadRound", perRound = true }, "breakClose" } },
    internalReload = "break",
    casing = { on = "reload", side = "down" },               -- spent hulls come out when it opens
}
AF.defineType{
    id = "revolver", label = "Revolver (swing-out cylinder)", hands = "one", feed = "cylinder",
    clips = clips{ "openCylinder", "ejectAll", "loadRound", "closeCylinder" },
    timings = { openCylinder = 0.4, ejectAll = 0.4, loadRound = 0.45, closeCylinder = 0.3, draw = 0.5, holster = 0.6 },
    reloads = { cylinder = { "openCylinder", "ejectAll", { clip = "loadRound", perRound = true }, "closeCylinder" } },
    internalReload = "cylinder",
    casing = { on = "reload", side = "down" },
}
AF.defineType{
    id = "revolver_gate", base = "revolver", label = "Revolver (loading gate)", feed = "gate",
    clips = clips{ "openGate", "ejectOne", "loadRound", "closeGate" },
    timings = { openGate = 0.35, ejectOne = 0.45, loadRound = 0.5, closeGate = 0.3 },
    reloads = { gate = { "openGate", { clip = "ejectOne", perRound = true }, { clip = "loadRound", perRound = true }, "closeGate" } },
    internalReload = "gate",
}
