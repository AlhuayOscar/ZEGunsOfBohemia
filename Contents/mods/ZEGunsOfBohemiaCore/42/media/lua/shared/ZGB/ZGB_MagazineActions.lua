--[[
    ZGB_MagazineActions.lua  —  loading a specific magazine type.

    Swap flow (e.g. 30rd mag in the AK -> 75rd drum):
        1. vanilla ISEjectMagazine   (gives back the 30rd mag, because MagazineType is still the 30rd)
        2. ZGB_SetMagTypeAction      (instant: MagazineType/MaxAmmo -> drum)
        3. vanilla ISInsertMagazine  (inserts the drum)
    Our wrapper on ISInsertMagazine (ZGB_ReloadHooks) then records the loaded
    mag and re-applies stats so the drum's weight/aim penalty counts.
]]
require "TimedActions/ISBaseTimedAction"
require "ZGB/ZGB_ItemBridge"

ZGB_SetMagTypeAction = ISBaseTimedAction:derive("ZGB_SetMagTypeAction")

function ZGB_SetMagTypeAction:isValid()
    return self.character:getInventory():contains(self.weapon)
end
function ZGB_SetMagTypeAction:start() end
function ZGB_SetMagTypeAction:update() end
function ZGB_SetMagTypeAction:perform() ISBaseTimedAction.perform(self) end
function ZGB_SetMagTypeAction:complete()
    if ZGB.Item.containsClip(self.weapon) then
        ZGB.warn("Mag type change skipped: gun still has a magazine in it")
    else
        ZGB.Item.setLoadedMagazine(self.weapon, self.magType)
    end
    return true
end
function ZGB_SetMagTypeAction:getDuration() return 1 end
function ZGB_SetMagTypeAction:new(character, weapon, magType)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon, o.magType = weapon, magType
    o.stopOnWalk, o.stopOnRun = false, false
    o.maxTime = 1
    return o
end

ZGB.MagSwap = ZGB.MagSwap or {}

--- Queue: eject current (if any) -> retarget -> insert `magItem`.
function ZGB.MagSwap.queue(player, weapon, magItem)
    ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
    ISInventoryPaneContextMenu.transferIfNeeded(player, magItem)
    if ZGB.Item.containsClip(weapon) then
        ISTimedActionQueue.add(ISEjectMagazine:new(player, weapon))             -- VERIFY ctor
    end
    ISTimedActionQueue.add(ZGB_SetMagTypeAction:new(player, weapon, magItem:getFullType()))
    ISTimedActionQueue.add(ISInsertMagazine:new(player, weapon, magItem))       -- VERIFY ctor
end
