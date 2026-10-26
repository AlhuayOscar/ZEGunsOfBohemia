--[[
    Draws the Gunsmith screen OFFLINE into a PNG, from the real window code:

        lua5.1 tools/preview_gunsmith.lua [GunId] [slotId] [part]      (default AK47 muzzle)
          -> .cache/gunsmith_<GunId>.png

    Runs ZGB_GunsmithWindow against tests/mock_game.lua (items read from our
    generated scripts) and tests/mock_ui.lua (records every draw call). The
    player carries the gun and every part that fits it; the screen opens the
    picker of [slotId] and hovers [part] (stats preview). Text shows as bars,
    the gun and parts as their placeholder silhouettes.
]]
local CORE = "Contents/mods/ZEGunsOfBohemiaCore/42/media/lua/"
package.path = CORE .. "shared/?.lua;" .. CORE .. "client/?.lua;tests/?.lua;tools/lib/?.lua;" .. package.path
local gunId, slotId, hoverPart = arg[1] or "AK47", arg[2] or "muzzle", arg[3]

local realPrint = print
print = function() end
require "ZGB/ZGB_Core"; require "ZGB/ZGB_Mode"
require "ZGB/Defs/ZGB_Def_Parts"; require "ZGB/Defs/ZGB_Def_Weapons"
require "ZGB/ZGB_ScriptApply"; require "ZGB/ZGB_Visuals"; require "ZGB/ZGB_Stats"
local Mock = require "mock_game"
local MockUI = require "mock_ui"
local Img = require "zgb_image"
MockUI.install(1920, 1080)
Mock.installGame()
require "ZGB/UI/ZGB_GunsmithWindow"
print = realPrint

local player = Mock.posePlayer()
function player:getPlayerNum() return 0 end
local inv = player.inv
function player:getInventory() return inv end
local spec = assert(ZGB.WeaponFactory.get(gunId), "unknown gun " .. gunId)
local gun = inv:add(instanceItem(spec.fullType))
for _, p in ipairs(ZGB.PartFactory.all()) do
    if ZGB.Attachments.isCompatible(spec, p.fullType) then inv:add(Mock.item(p.fullType)) end
end
for _, m in ipairs(ZGB.Magazines.list(spec)) do inv:add(Mock.item(m.item)) end

local w = ZGB_GunsmithWindow.open(player, gun)
w:createChildren()
w:onMouseDown(-1, -1)                                       -- nothing open
local slot = w:slotById(slotId)
if slot then
    w:onMouseDown(slot.box.x + 5, slot.box.y + 5)           -- open the slot's picker
    local list = w.partsBySlot[slotId] or {}
    local idx = 1
    for i, row in ipairs(list) do if hoverPart and row.part:find(hoverPart, 1, true) then idx = i end end
    local r = w:pickerRect()
    if r and list[idx] then
        MockUI.mouseX = r.x + 4 + ((idx - 1) % 5) * 58 + 10
        MockUI.mouseY = r.y + 26 + math.floor((idx - 1) / 5) * 58 + 10
        w:onMouseMove(0, 0)
    end
end
MockUI.ops = {}
w:prerender(); w:render()
local out = ".cache/gunsmith_" .. gunId .. ".png"
MockUI.toPNG(out, Img)
print(string.format("wrote %s (%d draw calls, %d slots)", out, #MockUI.ops, #(w.layout and w.layout.slots or {})))
