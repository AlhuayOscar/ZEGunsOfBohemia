--[[
    ZGB_ReloadHooks.lua  —  make vanilla reloading magazine-aware for our guns.

    1. Reload key (R) with an empty gun: before vanilla looks for a magazine of
       the gun's MagazineType, we point MagazineType at the best compatible
       magazine you carry (most rounds; ties keep the type you were using).
    2. After ANY magazine insert (R key, our menu, vanilla menu) we record which
       magazine is loaded and re-apply stats.

    Wrappers are installed at OnGameStart and always call the original, so other
    mods that also wrap these functions keep working.    -- VERIFY names/fields
]]
require "ZGB/ZGB_ItemBridge"

local I, M = ZGB.Item, ZGB.Magazines

local function onInserted(action)
    local gun = action and (action.gun or action.weapon)              -- VERIFY field name
    if not gun or not ZGB.WeaponFactory.isOurs(gun) then return end
    local mag = action.magazine
    local ft
    if mag then pcall(function() ft = mag:getFullType() end) end
    if not ft then pcall(function() ft = gun:getMagazineType() end) end
    if ft then I.state(gun).loadedMag = ft end
    -- the gun now fires whatever variant the magazine held
    local variant
    if mag then pcall(function() variant = mag:getAmmoType() end) end
    if variant and ZGB.AmmoCatalog.variantOfItem(variant) then I.setGunAmmo(gun, variant) end
    I.applyStats(gun)
end

-- Vanilla eject creates a fresh magazine item from the script, which would reset
-- it to the default ammo. Re-tag the newest magazine with the variant it held.
local function ejectBefore(action)
    local gun = action and (action.gun or action.weapon)              -- VERIFY field name
    if not gun or not ZGB.WeaponFactory.isOurs(gun) then return nil end
    local magType, variant
    pcall(function() magType = gun:getMagazineType() end)
    variant = I.loadedAmmo(gun)
    return { gun = gun, magType = magType, variant = variant }
end

local function ejectAfter(action, ctx)
    if not ctx or not ctx.magType or not ctx.variant then return end
    local items = action.character:getInventory():getItems()
    for i = items:size() - 1, 0, -1 do                                 -- newest first
        local it = items:get(i)
        if it:getFullType() == ctx.magType then
            pcall(function() it:setAmmoType(ctx.variant) end)
            return
        end
    end
end

local function wrapAround(tbl, name, before, after)
    local orig = tbl and tbl[name]
    if type(orig) ~= "function" then return false end
    tbl[name] = function(self, ...)
        local okB, ctx = pcall(before, self)
        local r = orig(self, ...)
        local ok, e = pcall(after, self, okB and ctx or nil)
        if not ok then ZGB.err("hook", name, e) end
        return r
    end
    return true
end

local function wrap(tbl, name, after)
    local orig = tbl and tbl[name]
    if type(orig) ~= "function" then return false end
    tbl[name] = function(self, ...)
        local r = orig(self, ...)
        local ok, e = pcall(after, self)
        if not ok then ZGB.err("hook", name, e) end
        return r
    end
    return true
end

local function installHooks()
    if ZGB._reloadHooksInstalled then return end   -- never double-wrap
    if ZGB.Mode.isBlocked() then return end        -- a foreign reload mod owns these functions
    ZGB._reloadHooksInstalled = true
    -- (2) record magazine after insert. B42 does the work in complete(); also wrap
    -- perform() so SP on builds without complete() is covered. applyStats is idempotent.
    if ISInsertMagazine then
        wrap(ISInsertMagazine, "complete", onInserted)
        wrap(ISInsertMagazine, "perform", onInserted)
    else
        ZGB.warn("ISInsertMagazine not found - magazine tracking disabled")
    end
    if ISEjectMagazine then
        wrapAround(ISEjectMagazine, "complete", ejectBefore, ejectAfter)
        wrapAround(ISEjectMagazine, "perform", ejectBefore, ejectAfter)
    else
        ZGB.warn("ISEjectMagazine not found - ejected mags revert to default ammo")
    end

    -- (1) choose best magazine on R
    if ISReloadWeaponAction and ISReloadWeaponAction.BeginAutomaticReload then
        local orig = ISReloadWeaponAction.BeginAutomaticReload
        ISReloadWeaponAction.BeginAutomaticReload = function(playerObj, ...)
            pcall(function()
                local gun = playerObj:getPrimaryHandItem()
                local spec = ZGB.WeaponFactory.specOf(gun)
                if spec and #M.list(spec) > 1 and not I.containsClip(gun) then
                    local current = I.state(gun).loadedMag or spec.magazine.item
                    local best = M.chooseBest(spec, I.compatibleMagazinesIn(playerObj:getInventory(), spec), current)
                    if best then I.setLoadedMagazine(gun, best.fullType) end
                end
            end)
            return orig(playerObj, ...)
        end
    else
        ZGB.warn("ISReloadWeaponAction.BeginAutomaticReload not found - R key uses default mag only")
    end
end

Events.OnGameStart.Add(installHooks)
