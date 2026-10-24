--[[
    ZGB_PartActions.lua  —  timed actions for fitting / removing parts.

    Written in Build 42 style: perform() runs client-side, complete() does the
    state change (runs on the server in MP, locally in SP).   -- VERIFY vs vanilla ISUpgradeWeapon
    Lives in shared/ because B42 MP needs the class on both sides.
]]
require "TimedActions/ISBaseTimedAction"
require "ZGB/ZGB_Service"

-- ---------------------------------------------------------------- attach
ZGB_AttachPartAction = ISBaseTimedAction:derive("ZGB_AttachPartAction")

function ZGB_AttachPartAction:isValid()
    local inv = self.character:getInventory()
    return inv:contains(self.weapon) and inv:contains(self.part)
end

function ZGB_AttachPartAction:start()
    self:setActionAnim("Craft")
    self.weapon:setJobType("Attaching")
    self.weapon:setJobDelta(0.0)
end

function ZGB_AttachPartAction:update()
    self.weapon:setJobDelta(self:getJobDelta())
end

function ZGB_AttachPartAction:stop()
    self.weapon:setJobDelta(0.0)
    ISBaseTimedAction.stop(self)
end

function ZGB_AttachPartAction:perform()
    self.weapon:setJobDelta(0.0)
    ISBaseTimedAction.perform(self)
end

function ZGB_AttachPartAction:complete()
    local ok, info = ZGB.Service.attach(self.character, self.weapon, self.part)
    if not ok then ZGB.warn("Attach refused:", info) end
    return true
end

function ZGB_AttachPartAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    local spec = ZGB.PartFactory.get(self.part:getFullType())
    return spec and spec.attachTime or 100
end

function ZGB_AttachPartAction:new(character, weapon, part)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon, o.part = weapon, part
    o.stopOnWalk, o.stopOnRun = false, true
    o.maxTime = o:getDuration()
    return o
end

-- ---------------------------------------------------------------- detach
ZGB_DetachPartAction = ISBaseTimedAction:derive("ZGB_DetachPartAction")

function ZGB_DetachPartAction:isValid()
    return self.character:getInventory():contains(self.weapon)
        and ZGB.Item.getAttachments(self.weapon)[self.slotId] ~= nil
end

function ZGB_DetachPartAction:start()
    self:setActionAnim("Craft")
    self.weapon:setJobType("Removing")
    self.weapon:setJobDelta(0.0)
end

ZGB_DetachPartAction.update = ZGB_AttachPartAction.update
ZGB_DetachPartAction.stop   = ZGB_AttachPartAction.stop
ZGB_DetachPartAction.perform = ZGB_AttachPartAction.perform

function ZGB_DetachPartAction:complete()
    local ok, info = ZGB.Service.detach(self.character, self.weapon, self.slotId)
    if not ok then ZGB.warn("Detach refused:", info) end
    return true
end

function ZGB_DetachPartAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return 60
end

function ZGB_DetachPartAction:new(character, weapon, slotId)
    local o = ISBaseTimedAction.new(self, character)
    o.weapon, o.slotId = weapon, slotId
    o.stopOnWalk, o.stopOnRun = false, true
    o.maxTime = o:getDuration()
    return o
end
