--[[
    ZGB_ReloadHooks.lua  —  the reloading addon's link to vanilla reloading.
    (Moved out of Core in v0.5: reloading is an essential addon now.)

    1. Reload key (R) with an empty gun: before vanilla looks for a magazine of
       the gun's MagazineType, we point MagazineType at the best compatible
       magazine you carry (most rounds; ties keep the type you were using).
    2. After ANY magazine insert (R key, our menu, vanilla menu) we record which
       magazine is loaded and re-apply stats.
    3. Every reload is planned by ZGB.Reload (kind, steps, timing). The vanilla
       action is scaled to the plan, and reload.start / reload.step /
       reload.complete / ammo.lastMag are emitted for the views and callouts.

    Wrappers are installed once at OnGameStart and always call the original.
    Other gun / reload frameworks are incompatible (Core blocks them).
    -- VERIFY names/fields
]]
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Sandbox"
require "ZGB/ZGB_Addons"
require "ZGBReload/ZGB_Reload"

local I, M, E, SB, R = ZGB.Item, ZGB.Magazines, ZGB.Events, ZGB.Sandbox, ZGB.Reload

ZGB.Addons.register{ id = "reload", name = "ZE Guns Of Bohemia - Reloading", modId = "ZEGunsOfBohemiaReload",
                     version = "0.5.0", essential = true }

-- ---------------------------------------------------------------- planned reloads
local active = setmetatable({}, { __mode = "k" })   -- action -> { plan, payload, t0, next }
local function clock() return (getTimestampMs and getTimestampMs() or os.time() * 1000) / 1000 end   -- VERIFY

local function gunOf(action) return action and (action.gun or action.weapon) end    -- VERIFY field name

local function begin(action, magItem)
    local gun = gunOf(action)
    local spec = gun and ZGB.WeaponFactory.specOf(gun)
    if not spec or active[action] then return end
    local tier
    if magItem then
        local ft
        pcall(function() ft = magItem:getFullType() end)
        local m = ft and ZGB.MagazineFactory.get(ft)
        tier = m and m.tier
    end
    local plan = R.plan(spec, { rounds = I.gunAmmo(gun), magTier = tier },
                        { skill = I.perkLevel(action.character, "Reloading"),
                          speed = SB.get("ZGBReload", "Speed", 100) })
    I.scaleActionTime(action, R.actionFactor(plan.kind, tier, SB.get("ZGBReload", "Speed", 100)))
    local payload = { player = action.character, gun = gun, spec = spec, kind = plan.kind,
                      duration = plan.duration, spent = plan.spent, plan = plan }
    active[action] = { plan = plan, payload = payload, t0 = clock(), next = 1 }
    E.emit("reload.start", payload)
end

local function finish(action)
    local a = active[action]
    if not a then return end
    active[action] = nil
    E.emit("reload.complete", a.payload)
    local p = a.payload
    if #M.list(p.spec) > 0 then
        local spare = 0
        for _, c in ipairs(I.compatibleMagazinesIn(p.player:getInventory(), p.spec)) do
            if c.ammo > 0 then spare = spare + 1 end
        end
        if spare == 0 then E.emit("ammo.lastMag", p) end
    end
end

Events.OnTick.Add(function()
    if next(active) == nil then return end
    local t = clock()
    for action, a in pairs(active) do
        local due
        due, a.next = R.dueSteps(a.plan, t - a.t0, a.next)
        for _, d in ipairs(due) do
            local p = {}
            for k, v in pairs(a.payload) do p[k] = v end
            p.step, p.index = d.step.clip, d.index
            E.emit("reload.step", p)
        end
    end
end)

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
        -- (3) planned reloads: start -> plan + events, complete/perform -> done, stop -> cancelled
        wrap(ISInsertMagazine, "start", function(self) begin(self, self.magazine) end)
        wrap(ISInsertMagazine, "complete", finish)
        wrap(ISInsertMagazine, "perform", finish)
        wrap(ISInsertMagazine, "stop", function(self) active[self] = nil end)
    else
        ZGB.warn("ISInsertMagazine not found - magazine tracking disabled")
    end
    -- rounds into tubes, cylinders and internal boxes (shotguns, revolvers, bolt / lever guns)
    if ISReloadWeaponAction then
        wrap(ISReloadWeaponAction, "start", function(self)
            local spec = ZGB.WeaponFactory.specOf(gunOf(self))
            if spec and #M.list(spec) == 0 then begin(self, nil) end
        end)
        wrap(ISReloadWeaponAction, "complete", finish)
        wrap(ISReloadWeaponAction, "perform", finish)
        wrap(ISReloadWeaponAction, "stop", function(self) active[self] = nil end)
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
