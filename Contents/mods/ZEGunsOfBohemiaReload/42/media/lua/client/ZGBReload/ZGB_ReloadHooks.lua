--[[
    ZGB_ReloadHooks.lua  —  the reloading addon's link to vanilla reloading.
    (Moved out of Core in v0.5.)

    Since v0.8 Gunworks (SWMG) does the reloading itself: it picks the best magazine,
    keeps mixed rounds in a magazine, sets the reload speed and handles speedloaders.
    This addon only follows those actions to tell the rest of the mod:
      * every reload is planned by ZGB.Reload (kind, steps, timing) and
        reload.start / reload.step / reload.complete / ammo.lastMag are emitted
        for the views (case dropping) and the callouts;
      * after a magazine goes in, the stats are recomputed (the magazine tier counts).

    Wrappers are installed once at OnGameStart and always call the original.
    Gun frameworks other than Gunworks are incompatible (Core blocks them).
    -- VERIFY names/fields
]]
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Addons"
require "ZGBReload/ZGB_Reload"

local I, M, E, R = ZGB.Item, ZGB.Magazines, ZGB.Events, ZGB.Reload

ZGB.Addons.register{ id = "reload", name = "ZE Guns Of Bohemia - Reloading", modId = "ZEGunsOfBohemiaReload",
                     version = "0.8.0", essential = false }

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
                          speed = 100 })     -- the real speed is Gunworks': the plan only times the events
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
    if ZGB.isEmpty(active) then return end
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
    I.applyStats(gun)
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
    -- after an insert: stats again (B42 does the work in complete(); perform() covers older builds)
    if ISInsertMagazine then
        wrap(ISInsertMagazine, "complete", onInserted)
        wrap(ISInsertMagazine, "perform", onInserted)
        -- planned reloads: start -> plan + events, complete/perform -> done, stop -> cancelled
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
end

Events.OnGameStart.Add(installHooks)
