--[[
    ZGB_ClientHooks.lua  —  context menu entry + keep stats fresh on equip.

    With Gunworks active (the normal case since v0.8) magazines, rounds and loading are
    its menus (radial: select magazine / ammunition, the ammo loader), so ours only
    show without it.
]]
require "ZGB/ZGB_Service"
require "ZGB/ZGB_Events"
require "ZGB/ZGB_Addons"
require "ZGB/Factory/ZGB_RecoilFactory"
require "ZGB/UI/ZGB_GunsmithWindow"
require "ZGB/ZGB_MagazineActions"
require "ZGB/ZGB_AmmoActions"
require "ZGB/ZGB_Gunworks"

local function gunworks() return ZGB.Gunworks.active end

local function firstItem(v)
    if instanceof(v, "InventoryItem") then return v end
    return v.items and v.items[1] or nil          -- stacked entries in the inventory pane
end

--- "Load magazine >" with the fullest carried magazine of each compatible type.
local function addMagazineMenu(player, context, gun)
    local spec = ZGB.WeaponFactory.specOf(gun)
    if not spec or #ZGB.Magazines.list(spec) == 0 then return end
    local bestPerType = {}
    for _, c in ipairs(ZGB.Item.compatibleMagazinesIn(player:getInventory(), spec)) do
        local b = bestPerType[c.fullType]
        if not b or c.ammo > b.ammo then bestPerType[c.fullType] = c end
    end
    local loaded = ZGB.Item.loadedMagazine(gun)
    local parent, sub
    for _, m in ipairs(ZGB.Magazines.list(spec)) do
        local c = bestPerType[m.item]
        if c and m.item ~= loaded then
            if not sub then
                parent = context:addOption("Load magazine")
                sub = ISContextMenu:getNew(context)
                context:addSubMenu(parent, sub)
            end
            sub:addOption(string.format("%s (%d/%d)", ZGB.Magazines.labelOf(m), c.ammo, m.capacity),
                gun, function(g) ZGB.MagSwap.queue(player, g, c.ref) end)
        end
    end
end

--[[ "Load all <caliber> magazines"
     - exactly one carried ammo type would load something -> a single option
     - several (FMJ + AP + Tracer...)                      -> pick which one
     - if some magazines hold a different type, "Unload all" lets you switch ]]
local function addLoadAllMenu(player, context, caliberId)
    local cal = ZGB.AmmoCatalog.CALIBERS[caliberId]
    if not cal then return end
    local inv = player:getInventory()
    local mags = ZGB.Item.magazinesOfCaliberIn(inv, caliberId)
    if #mags == 0 then return end
    local opts = ZGB.Ammo.loadOptions(caliberId, mags, ZGB.Item.ammoCounts(inv, caliberId))
    local title = "Load all " .. cal.label .. " magazines"

    if #opts == 1 then
        local o = opts[1]
        context:addOption(string.format("%s (%s, %d rds)", title, o.variant.label, o.plan.total),
            caliberId, function(c) ZGB.LoadAll.queueLoadAll(player, c, o.variant.item) end)
    elseif #opts > 1 then
        local parent = context:addOption(title)
        local sub = ISContextMenu:getNew(context)
        context:addSubMenu(parent, sub)
        for _, o in ipairs(opts) do
            sub:addOption(string.format("%s - loads %d (have %d)", o.variant.label, o.plan.total, o.have),
                caliberId, function(c) ZGB.LoadAll.queueLoadAll(player, c, o.variant.item) end)
        end
    end

    local anyLoaded = false
    for _, m in ipairs(mags) do if m.ammo > 0 then anyLoaded = true; break end end
    if anyLoaded then
        context:addOption("Unload all " .. cal.label .. " magazines", caliberId,
            function(c) ZGB.LoadAll.queueUnloadAll(player, c) end)
    end
end

--- Tube-fed guns (shotgun): choose which shells go in, only while empty.
local function addShellChoiceMenu(player, context, gun, spec)
    if #ZGB.Magazines.list(spec) > 0 or ZGB.Item.ammoCount(gun) > 0 then return end
    local carried = ZGB.Ammo.carriedVariants(spec.caliber, ZGB.Item.ammoCounts(player:getInventory(), spec.caliber))
    if #carried < 2 then return end
    local current = ZGB.Item.state(gun).loadedAmmo or spec.ammo
    local parent = context:addOption("Load with...")
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(parent, sub)
    for _, c in ipairs(carried) do
        local label = string.format("%s (%d)%s", c.variant.label, c.have, c.variant.item == current and "  - current" or "")
        sub:addOption(label, gun, function(g) ZGB.LoadAll.queueSetGunAmmo(player, g, c.variant.item) end)
    end
end

local function onFillInventoryMenu(playerNum, context, items)
    if ZGB.Mode.isBlocked() then return end
    local player = getSpecificPlayer(playerNum)
    for _, v in ipairs(items) do
        local item = firstItem(v)
        local spec = item and ZGB.WeaponFactory.specOf(item)
        if spec then
            context:addOption("Gunsmith...", item, function(weapon)
                ZGB_GunsmithWindow.open(player, weapon)
            end)
            if not gunworks() then
                addMagazineMenu(player, context, item)
                addShellChoiceMenu(player, context, item, spec)
                addLoadAllMenu(player, context, spec.caliber)
            end
            return
        end
        -- one of our magazines, or any ammo in the catalog (vanilla FMJ included)
        local caliberId = item and ZGB.Ammo.caliberOf(item:getFullType())
        if caliberId and not gunworks() then
            addLoadAllMenu(player, context, caliberId)
            return
        end
    end
end

local equipped = {}   -- player -> spec of the gun in hand (for weapon.unequip)

local function onEquip(character, item)
    if ZGB.Mode.isBlocked() then return end
    local spec = item and ZGB.WeaponFactory.specOf(item)
    if equipped[character] and equipped[character] ~= spec then
        ZGB.Events.emit("weapon.unequip", { player = character, spec = equipped[character] })
    end
    equipped[character] = spec
    if spec then
        ZGB.Service.refresh(character, item)
        ZGB.Mode.notify("onWeaponEquipped", character, item, spec)
        ZGB.Events.emit("weapon.equip", { player = character, gun = item, spec = spec })
    end
end

-- weapon.fire with the shot's place in the current burst (recoil, casings, calls)
local bursts = setmetatable({}, { __mode = "k" })
local function now() return (getTimestampMs and getTimestampMs() or os.time() * 1000) / 1000 end   -- VERIFY

local function onSwing(character, weapon)
    if ZGB.Mode.isBlocked() or not weapon then return end
    local spec = ZGB.WeaponFactory.specOf(weapon)
    if not spec then return end
    bursts[weapon] = bursts[weapon] or {}
    local shot = ZGB.RecoilFactory.track(bursts[weapon], now())
    ZGB.Events.emit("weapon.fire", { player = character, gun = weapon, spec = spec, shot = shot })
    if ZGB.Item.gunAmmo(weapon) <= 1 then          -- this was the last round
        ZGB.Events.emit("ammo.empty", { player = character, gun = weapon, spec = spec })
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryMenu)
Events.OnEquipPrimary.Add(onEquip)
if Events.OnWeaponSwing then Events.OnWeaponSwing.Add(onSwing) end            -- VERIFY: fires for ranged shots

-- Tell the player once if no view addon (or two of them) is active.
Events.OnGameStart.Add(function()
    local msg
    ZGB.Mode.isBlocked()   -- records a conflict message if a foreign gun mod is active
    if #ZGB.Mode.conflicts > 0 then
        msg = ZGB.Mode.conflicts[1]
    elseif not ZGB.Mode.get() then
        msg = "ZE Guns Of Bohemia: no view addon enabled. Enable 'ZE Guns Of Bohemia - Isometric'."
    else
        local missing = ZGB.Addons.missingEssentials()
        if #missing > 0 then
            local names = {}
            for _, m in ipairs(missing) do names[#names + 1] = m.name end
            msg = "ZE Guns Of Bohemia: essential addon(s) not enabled: " .. table.concat(names, ", ")
        end
    end
    if msg then
        local p = getSpecificPlayer(0)
        if p then p:Say(msg) end
        ZGB.err(msg)
    end
end)
