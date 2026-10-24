--[[
    ZGB_AmmoActions.lua  —  loading / unloading magazines in the core mod,
    so no external "load all magazines" mod is needed (one less incompatibility).

    One timed action per magazine: if the player cancels, the magazines already
    done stay loaded and nothing is half-counted. Each action re-checks the
    inventory when it completes, so a plan made from the menu can't over-spend.
]]
require "TimedActions/ISBaseTimedAction"
require "ZGB/ZGB_ItemBridge"

ZGB.LoadAll = ZGB.LoadAll or {}
local LA, I = ZGB.LoadAll, ZGB.Item

LA.TICKS_PER_ROUND   = 8      -- tune to taste; vanilla thumbing is in this range
LA.TICKS_PER_UNLOAD  = 4
LA.MIN_TICKS         = 20

-- ---------------------------------------------------------------- load one magazine
ZGB_LoadMagazineAction = ISBaseTimedAction:derive("ZGB_LoadMagazineAction")

function ZGB_LoadMagazineAction:isValid()
    return self.character:getInventory():containsRecursive(self.mag)
end
function ZGB_LoadMagazineAction:start()
    self:setActionAnim("Loot")
    self.mag:setJobType("Loading")
    self.mag:setJobDelta(0)
end
function ZGB_LoadMagazineAction:update() self.mag:setJobDelta(self:getJobDelta()) end
function ZGB_LoadMagazineAction:stop()
    self.mag:setJobDelta(0)
    ISBaseTimedAction.stop(self)
end
function ZGB_LoadMagazineAction:perform()
    self.mag:setJobDelta(0)
    ISBaseTimedAction.perform(self)
end
function ZGB_LoadMagazineAction:complete()
    local inv = self.character:getInventory()
    local st = I.magazineState(self.mag)
    if not st then return true end
    if st.ammo > 0 and st.variant ~= self.ammoFt then
        ZGB.warn("Magazine holds another ammo type; skipped")
        return true
    end
    local have = I.ammoCounts(inv, ZGB.AmmoCatalog.variantOfItem(self.ammoFt).caliber)[self.ammoFt] or 0
    local n = math.min(self.count, st.capacity - st.ammo, have)
    if n <= 0 then return true end
    local removed = I.takeAmmo(inv, self.ammoFt, n)
    I.setMagazineContents(self.mag, self.ammoFt, st.ammo + removed)
    return true
end
function ZGB_LoadMagazineAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return math.max(LA.MIN_TICKS, self.count * LA.TICKS_PER_ROUND)
end
function ZGB_LoadMagazineAction:new(character, mag, ammoFt, count)
    local o = ISBaseTimedAction.new(self, character)
    o.mag, o.ammoFt, o.count = mag, ammoFt, count
    o.stopOnWalk, o.stopOnRun = false, true
    o.maxTime = o:getDuration()
    return o
end

-- ---------------------------------------------------------------- unload one magazine
ZGB_UnloadMagazineAction = ISBaseTimedAction:derive("ZGB_UnloadMagazineAction")

ZGB_UnloadMagazineAction.isValid = ZGB_LoadMagazineAction.isValid
ZGB_UnloadMagazineAction.update  = ZGB_LoadMagazineAction.update
ZGB_UnloadMagazineAction.stop    = ZGB_LoadMagazineAction.stop
ZGB_UnloadMagazineAction.perform = ZGB_LoadMagazineAction.perform
function ZGB_UnloadMagazineAction:start()
    self:setActionAnim("Loot")
    self.mag:setJobType("Unloading")
    self.mag:setJobDelta(0)
end
function ZGB_UnloadMagazineAction:complete()
    local st = I.magazineState(self.mag)
    if not st or st.ammo <= 0 then return true end
    I.giveAmmo(self.character:getInventory(), st.variant, st.ammo)
    I.setMagazineContents(self.mag, st.variant, 0)
    return true
end
function ZGB_UnloadMagazineAction:getDuration()
    if self.character:isTimedActionInstant() then return 1 end
    return math.max(LA.MIN_TICKS, (self.count or 1) * LA.TICKS_PER_UNLOAD)
end
function ZGB_UnloadMagazineAction:new(character, mag, count)
    local o = ISBaseTimedAction.new(self, character)
    o.mag, o.count = mag, count
    o.stopOnWalk, o.stopOnRun = false, true
    o.maxTime = o:getDuration()
    return o
end

-- ---------------------------------------------------------------- tube-fed: choose shells
-- Vanilla loads single rounds of the gun's AmmoType, so picking buckshot vs slug
-- = retargeting AmmoType while the gun is empty (no mixing in the tube).
ZGB_SetGunAmmoAction = ISBaseTimedAction:derive("ZGB_SetGunAmmoAction")
function ZGB_SetGunAmmoAction:isValid() return self.character:getInventory():contains(self.gun) end
function ZGB_SetGunAmmoAction:start() end
function ZGB_SetGunAmmoAction:update() end
function ZGB_SetGunAmmoAction:perform() ISBaseTimedAction.perform(self) end
function ZGB_SetGunAmmoAction:complete()
    if I.ammoCount(self.gun) > 0 then
        ZGB.warn("Gun not empty; ammo type unchanged")
    else
        I.setGunAmmo(self.gun, self.ammoFt)
        I.applyStats(self.gun)
    end
    return true
end
function ZGB_SetGunAmmoAction:getDuration() return 1 end
function ZGB_SetGunAmmoAction:new(character, gun, ammoFt)
    local o = ISBaseTimedAction.new(self, character)
    o.gun, o.ammoFt = gun, ammoFt
    o.maxTime = 1
    return o
end

-- ---------------------------------------------------------------- queue helpers (client)
--- Queue loading every eligible magazine of `caliberId` with `ammoFt`.
function LA.queueLoadAll(player, caliberId, ammoFt)
    local inv = player:getInventory()
    local have = I.ammoCounts(inv, caliberId)[ammoFt] or 0
    local plan = ZGB.Ammo.planLoadAll(I.magazinesOfCaliberIn(inv, caliberId), ammoFt, have)
    for _, load in ipairs(plan.loads) do
        ISInventoryPaneContextMenu.transferIfNeeded(player, load.ref)
        ISTimedActionQueue.add(ZGB_LoadMagazineAction:new(player, load.ref, ammoFt, load.count))
    end
    return plan
end

--- Queue unloading every non-empty magazine of `caliberId` (to switch ammo type).
function LA.queueUnloadAll(player, caliberId)
    local n = 0
    for _, st in ipairs(I.magazinesOfCaliberIn(player:getInventory(), caliberId)) do
        if st.ammo > 0 then
            ISInventoryPaneContextMenu.transferIfNeeded(player, st.ref)
            ISTimedActionQueue.add(ZGB_UnloadMagazineAction:new(player, st.ref, st.ammo))
            n = n + 1
        end
    end
    return n
end

function LA.queueSetGunAmmo(player, gun, ammoFt)
    ISInventoryPaneContextMenu.transferIfNeeded(player, gun)
    ISTimedActionQueue.add(ZGB_SetGunAmmoAction:new(player, gun, ammoFt))
end
