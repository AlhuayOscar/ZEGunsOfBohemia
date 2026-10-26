--[[
    ZGB_ItemBridge.lua  —  the ONLY file that touches live HandWeapon objects.

    Keeping every Java call in one place means:
      * if a build renames a method, you fix it here and nowhere else
      * the logic files stay testable outside the game

    Lines marked  -- VERIFY  are game-API calls to double-check against your
    build (open the decompiled HandWeapon / vanilla Lua if one errors).
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_WeaponFactory"
require "ZGB/Factory/ZGB_PartFactory"
require "ZGB/ZGB_Attachments"
require "ZGB/ZGB_Stats"
require "ZGB/ZGB_Magazines"
require "ZGB/ZGB_Ammo"
require "ZGB/ZGB_Visuals"

ZGB.Item = ZGB.Item or {}
local I = ZGB.Item

local STATE_VERSION = 1

-- ------------------------------------------------------------ saved state
-- Lives in item modData so it survives save/load and travels with the item.
function I.state(item)
    local md = item:getModData()
    if not md.ZGB then md.ZGB = { v = STATE_VERSION, attachments = {} } end
    md.ZGB.attachments = md.ZGB.attachments or {}
    return md.ZGB
end

--- Plain Lua copy of the attachments map (safe to pass to ZGB.Attachments).
function I.getAttachments(item)
    local out = {}
    for slotId, ft in pairs(I.state(item).attachments) do out[slotId] = ft end
    return out
end

function I.setAttachments(item, att)
    local st = I.state(item)
    st.attachments = {}
    for slotId, ft in pairs(att) do st.attachments[slotId] = ft end
end

-- ------------------------------------------------------------ stat apply
-- spec stat key -> HandWeapon setter.  VERIFY each name on your build.
I.SETTERS = {
    minDamage   = "setMinDamage",
    maxDamage   = "setMaxDamage",
    range       = "setMaxRange",
    minRange    = "setMinRange",
    aimTime     = "setAimingTime",
    recoilDelay = "setRecoilDelay",
    hitChance   = "setHitChance",
    critChance  = "setCriticalChance",
    reloadTime  = "setReloadTime",
    soundRadius = "setSoundRadius",
    weight      = "setActualWeight",
    projectileCount = "setProjectileCount",
}

-- setters that take a Java int: the game truncates 12.67 to 12 (seen in the self-test),
-- so we round first and the stats we report match what the gun really has
I.INT_STATS = { aimTime = true, recoilDelay = true, hitChance = true, reloadTime = true,
                soundRadius = true, projectileCount = true }

local warnedSetters = {}

local function callSetter(item, setter, value)
    local ok, err = pcall(function() item[setter](item, value) end)
    if not ok and not warnedSetters[setter] then
        warnedSetters[setter] = true
        ZGB.warn("Setter failed (check name for this build):", setter, err)
    end
end

-- Transient stat effects (burst recoil penalty ...): item -> key -> { mods = {...} }.
-- Not saved; weak keys so dropped items are collected.
I.transient = I.transient or setmetatable({}, { __mode = "k" })

--- Set (or clear with mods = nil) a transient effect, then re-apply stats.
function I.setTransient(item, key, mods)
    I.transient[item] = I.transient[item] or {}
    I.transient[item][key] = mods and { mods = mods } or nil
    return I.applyStats(item)
end

--- Recompute and push stats onto the instance. Idempotent — safe to call often.
--- With Gunworks active our numbers are one of its stat layers (ZGB_Gunworks): it
--- restores the base and re-applies every layer, ours included.
function I.applyStats(item)
    local spec = ZGB.WeaponFactory.specOf(item)
    if not spec then return end
    local att = I.getAttachments(item)

    -- self-heal saves made with an older spec
    local clean, removed = ZGB.Attachments.sanitize(spec, att)
    if #removed > 0 then
        ZGB.warn("Dropped invalid attachments on", spec.fullType, table.concat(removed, ","))
        I.setAttachments(item, clean)
        att = clean
        I.state(item).pendingRefund = removed   -- Service gives these back to the player
    end

    if ZGB.Gunworks and ZGB.Gunworks.active then return ZGB.Gunworks.reapply(item) end

    local mag = I.loadedMagazine(item)
    local extra = {}
    for _, e in pairs(I.transient[item] or {}) do extra[#extra + 1] = e end
    local stats = ZGB.Stats.compute(spec, att, mag, I.loadedAmmo(item), extra)
    for key, setter in pairs(I.SETTERS) do
        if stats[key] ~= nil then
            if I.INT_STATS[key] then stats[key] = math.floor(stats[key] + 0.5) end
            callSetter(item, setter, stats[key])
        end
    end
    -- Ammo capacity is always the spec's (for the loaded mag), never a vanilla leftover.
    callSetter(item, "setMaxAmmo", ZGB.Magazines.capacityFor(spec, mag))   -- VERIFY
    -- a suppressor swaps the recorded shot for its suppressed version
    local snd = spec.sounds or {}
    local fire = (ZGB.Sounds and ZGB.Sounds.isSuppressed(att) and snd.fireSuppressed) or snd.fire
    if fire then callSetter(item, "setSwingSound", fire) end                 -- VERIFY
    return stats
end

-- ------------------------------------------------------------ magazines
local function containsClip(item)
    local ok, v = pcall(function() return item:isContainsClip() end)     -- VERIFY
    return ok and v == true
end
I.containsClip = containsClip

--- The magazine type currently IN the gun, or nil if none / tube-fed. Gunworks points
--- the gun's MagazineType at the magazine it inserts, so the gun itself says which one.
function I.loadedMagazine(item)
    if not containsClip(item) then return nil end
    local t = item.getMagazineType and item:getMagazineType()
    if t and t ~= "" then return tostring(t) end
    return I.state(item).loadedMag
end

--- Fire mode string ("Single", "Auto", Gunworks' "RealAuto" / "RealBurst"), or nil.
function I.fireMode(item)
    if not item or not item.getFireMode then return nil end
    local m = item:getFireMode()
    return m and tostring(m) or nil
end

--- AmmoType object an item script declares (`AmmoType = ...`), or nil. Gunworks wants
--- this object as the `enum` of each round; works for our rounds, vanilla and SWMG's.
function I.scriptAmmoType(fullType)
    local sm = ScriptManager and ScriptManager.instance
    local script = sm and sm:FindItem(fullType)
    if not script or not script.getAmmoType then return nil end
    return script:getAmmoType()
end

function I.setWeight(item, w)
    if item and item.setActualWeight and w then item:setActualWeight(w) end
end

--- Point vanilla at `magFullType` BEFORE it is inserted: MagazineType decides
--- what vanilla inserts/ejects, MaxAmmo what the HUD shows.
function I.setLoadedMagazine(item, magFullType)
    local spec = ZGB.WeaponFactory.specOf(item)
    if not spec or not ZGB.Magazines.accepts(spec, magFullType) then return false end
    callSetter(item, "setMagazineType", magFullType)                    -- VERIFY
    callSetter(item, "setMaxAmmo", ZGB.Magazines.capacityFor(spec, magFullType))
    I.state(item).loadedMag = magFullType
    return true
end

--- Rounds in a magazine item. VERIFY: vanilla stores it as current ammo count.
function I.magazineAmmo(magItem)
    local ok, n = pcall(function() return magItem:getCurrentAmmoCount() end)
    return ok and n or 0
end

--- All magazines in the inventory this gun accepts: { fullType, ammo, ref }
function I.compatibleMagazinesIn(inventory, spec)
    local out = {}
    for _, m in ipairs(ZGB.Magazines.list(spec)) do
        local items
        pcall(function() items = inventory:getAllTypeRecurse(m.item) end)   -- VERIFY
        if items then
            for i = 0, items:size() - 1 do
                local it = items:get(i)
                out[#out + 1] = { fullType = m.item, ammo = I.magazineAmmo(it), ref = it }
            end
        end
    end
    return out
end

-- ------------------------------------------------------------ vanilla visuals
-- Vanilla only knows 6 part types (Scope, Clip, Sling, Canon, Stock, RecoilPad)
-- and renders a part's 3D model only when it is a real WeaponPart attached the
-- vanilla way. So: OUR rules decide what is allowed and what the stats are;
-- this bridge mirrors parts that have `vanillaPartType` into vanilla purely so
-- the model shows. Their script modifiers should be zero (applyStats overwrites
-- anyway).
function I.mirrorVanillaAttach(character, item, partSpec)
    if not partSpec.vanillaPartType then return end
    if ZGB.Visuals and ZGB.Visuals.mode(partSpec) ~= "rendered" then return end   -- baked into a model variant
    local twin = ZGB.Visuals and ZGB.Visuals.twinOf(partSpec) or partSpec.fullType
    local vp = instanceItem and instanceItem(twin)                     -- VERIFY B42 item creation
    if not vp or not instanceof(vp, "WeaponPart") then
        ZGB.debug("No vanilla WeaponPart for", partSpec.fullType, "(fine until models exist)")
        return
    end
    -- B42 signature may include the character; try both.            -- VERIFY
    local ok = pcall(function() item:attachWeaponPart(character, vp) end)
    if not ok then pcall(function() item:attachWeaponPart(vp) end) end
end

function I.mirrorVanillaDetach(character, item, partSpec)
    if not partSpec.vanillaPartType then return end
    local current
    pcall(function() current = item:getWeaponPart(partSpec.vanillaPartType) end) -- VERIFY
    if not current then return end
    local ok = pcall(function() item:detachWeaponPart(character, current) end)
    if not ok then pcall(function() item:detachWeaponPart(current) end) end
end


-- ------------------------------------------------------------ ammo variants
-- A magazine's variant IS its AmmoType (vanilla bullet loading then stays
-- consistent automatically). A gun's AmmoType is set to the variant of the
-- magazine/rounds inside it, so racking ejects the right round.

local function ammoCount(item)
    local ok, n = pcall(function() return item:getCurrentAmmoCount() end)
    return ok and n or 0
end
I.ammoCount = ammoCount

-- B42 ammo types are registry objects (AmmoType); the rest of the mod speaks item full
-- types ("Base.Bullets45", "ZGB.Ammo_9x19_HP"). These two convert at the edge.
local function getAmmoType(item)
    local ok, t = pcall(function() return item:getAmmoType() end)
    if not ok or t == nil then return nil end
    if type(t) == "string" then return t end
    local ok2, key = pcall(function() return t:getItemKey() end)            -- same call vanilla Lua uses
    return ok2 and key and tostring(key) or nil
end
I.ammoTypeOf = getAmmoType

local ammoTypeCache = {}
--- AmmoType object for an ammo item full type, or nil (logged once) if the game has none.
function I.ammoTypeObject(ammoFt)
    if not ammoFt then return nil end
    if ammoTypeCache[ammoFt] ~= nil then return ammoTypeCache[ammoFt] or nil end
    local id = ZGB.AmmoCatalog.registryId(ammoFt)
    local ok, obj = pcall(function() return AmmoType.get(ResourceLocation.of(id)) end)   -- confirmed by the in-game self-test
    if not ok or not obj then ZGB.warn("No B42 AmmoType", id, "for", ammoFt, ok and "" or tostring(obj)) end
    ammoTypeCache[ammoFt] = (ok and obj) or false
    return ammoTypeCache[ammoFt] or nil
end

local function setAmmoType(item, ammoFt)
    local obj = I.ammoTypeObject(ammoFt)
    if obj then callSetter(item, "setAmmoType", obj) end
end

--- Variant currently in the gun (nil if empty). Used for stats.
function I.loadedAmmo(gun)
    if ammoCount(gun) <= 0 and not containsClip(gun) then return nil end
    return I.state(gun).loadedAmmo or getAmmoType(gun)
end

function I.setGunAmmo(gun, ammoFt)
    setAmmoType(gun, ammoFt)
    I.state(gun).loadedAmmo = ammoFt
end

--- { ref, capacity, ammo, variant } for one magazine item of ours.
function I.magazineState(mag)
    local info = ZGB.Ammo.magazineInfo(mag:getFullType())
    if not info then return nil end
    local n = ammoCount(mag)
    return { ref = mag, capacity = info.capacity, ammo = n, variant = (n > 0) and getAmmoType(mag) or nil }
end

function I.setMagazineContents(mag, ammoFt, count)
    setAmmoType(mag, ammoFt)
    callSetter(mag, "setCurrentAmmoCount", count)
end

--- Every magazine of a caliber the player carries (bags included).
function I.magazinesOfCaliberIn(inventory, caliberId)
    local out = {}
    for _, magFt in ipairs(ZGB.Ammo.magazinesOfCaliber(caliberId)) do
        local items
        pcall(function() items = inventory:getAllTypeRecurse(magFt) end)     -- VERIFY
        if items then
            for i = 0, items:size() - 1 do
                local st = I.magazineState(items:get(i))
                if st then out[#out + 1] = st end
            end
        end
    end
    return out
end

--- Rounds carried per variant item of a caliber: { [itemFt] = n }
function I.ammoCounts(inventory, caliberId)
    local counts = {}
    for _, v in ipairs(ZGB.AmmoCatalog.variantsFor(caliberId) or {}) do
        local n = 0
        pcall(function() n = inventory:getCountTypeRecurse(v.item) end)     -- VERIFY
        counts[v.item] = n or 0
    end
    return counts
end

--- Remove up to n rounds; returns how many were really removed.
function I.takeAmmo(inventory, ammoFt, n)
    local removed = 0
    for _ = 1, n do
        local ok = pcall(function() inventory:RemoveOneOf(ammoFt) end)     -- VERIFY recursion into bags; MP sync
        if not ok then break end
        removed = removed + 1
    end
    return removed
end

function I.giveAmmo(inventory, ammoFt, n)
    if n <= 0 then return end
    local ok = pcall(function() inventory:AddItems(ammoFt, n) end)          -- VERIFY; MP sync
    if not ok then for _ = 1, n do inventory:AddItem(ammoFt) end end
end

-- ------------------------------------------------------------ character (addons)
-- Used by the reload, holding, calls and view addons. Every call is guarded:
-- a wrong name logs once and returns the fallback.
local warnedCalls = {}
local function guarded(name, fallback, fn)
    local ok, v = pcall(fn)
    if ok then return v end
    if not warnedCalls[name] then
        warnedCalls[name] = true
        ZGB.warn("Game call failed (check name for this build):", name, v)
    end
    return fallback
end

--- Perk level 0-10, e.g. I.perkLevel(player, "Aiming").
function I.perkLevel(character, perkName)
    return guarded("getPerkLevel", 0, function()
        return character:getPerkLevel(Perks[perkName])                        -- VERIFY
    end) or 0
end

--- Animation variable read by AnimSet conditions (iso / fp views).
function I.setAnimVariable(character, key, value)
    return guarded("setVariable", false, function()
        character:setVariable(key, tostring(value)); return true              -- VERIFY
    end)
end

--- Overhead speech text (callouts).
function I.say(character, text)
    return guarded("Say", false, function() character:Say(text); return true end)   -- VERIFY
end

--- Facing as a unit vector (dx, dy).
function I.facing(character)
    local v = guarded("getForwardDirection", nil, function() return character:getForwardDirection() end)  -- VERIFY
    if not v then return 1, 0 end
    return v:getX(), v:getY()
end

--- Drop an item on the ground at an offset (tiles) from the character. Returns the world item.
function I.dropWorldItem(character, fullType, dx, dy)
    return guarded("AddWorldInventoryItem", nil, function()
        local sq = character:getCurrentSquare()
        local x = (character:getX() % 1) + (dx or 0)
        local y = (character:getY() % 1) + (dy or 0)
        x, y = math.min(math.max(x, 0.05), 0.95), math.min(math.max(y, 0.05), 0.95)
        return sq:AddWorldInventoryItem(fullType, x, y, 0)                     -- VERIFY
    end)
end

--- Remove a world item dropped by dropWorldItem.
function I.removeWorldItem(worldItemOrItem)
    return guarded("removeWorldItem", false, function()
        local wi = worldItemOrItem.getWorldItem and worldItemOrItem:getWorldItem() or worldItemOrItem
        local sq = wi:getSquare()
        if sq then sq:transmitRemoveItemFromSquare(wi) end                       -- VERIFY
        wi:removeFromWorld(); wi:removeFromSquare()                              -- VERIFY
        return true
    end)
end

--- Point the gun at another model script (an attachment variant). Returns true on success.
function I.setWeaponModel(item, modelFullId)
    return guarded("setWeaponSprite", false, function()
        item:setWeaponSprite(modelFullId)                                       -- VERIFY
        return true
    end)
end

--- Make the character re-read the models in their hands after a model change.
function I.refreshHandModels(character)
    return guarded("resetEquippedHandsModels", false, function()
        character:resetEquippedHandsModels(); return true                      -- VERIFY
    end)
end

--- Rounds currently in the gun (magazine + chamber as vanilla counts it).
function I.gunAmmo(gun)
    return guarded("getCurrentAmmoCount", 0, function() return gun:getCurrentAmmoCount() end) or 0
end

--- Scale a timed action's duration (reload speed). factor 1 = unchanged.
function I.scaleActionTime(action, factor)
    return guarded("maxTime", false, function()
        if action.maxTime and action.maxTime > 0 then
            action.maxTime = math.max(1, math.floor(action.maxTime * factor + 0.5))   -- VERIFY field
            return true
        end
        return false
    end)
end

-- ------------------------------------------------------------ probes (self-test, debug tools)
-- Never warn: the self-test reports a missing call itself as SKIP.

--- New item instance that is in no container (nil if the type can't be made).
function I.create(fullType)
    local ok, it = pcall(function() return instanceItem(fullType) end)
    if ok and it then return it end
    ok, it = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
    return ok and it or nil
end

--- Read a getter: value, or nil + "missing" when the game has no such call / it threw.
function I.probe(item, getter)
    local ok, v = pcall(function() return item[getter](item) end)
    if not ok then return nil, "missing" end
    return v
end

--- Call a setter on purpose (the self-test simulating what a timed action does).
function I.poke(item, setter, value)
    local ok = pcall(function() item[setter](item, value) end)
    return ok
end

--- Pretend a timed action inserted `magFullType` holding `count` rounds (stats, MaxAmmo, chamber).
function I.simulateInsert(gun, magFullType, count)
    if not I.setLoadedMagazine(gun, magFullType) then return false end
    I.state(gun).loadedMag = magFullType
    I.poke(gun, "setContainsClip", true)
    I.poke(gun, "setCurrentAmmoCount", count)
    I.poke(gun, "setRoundChambered", count > 0)
    I.applyStats(gun)
    return true
end

function I.scriptExists(fullType)
    local ok, s = pcall(function() return ScriptManager.instance:getItem(fullType) end)
    return ok and s ~= nil
end

function I.modelScriptExists(fullId)
    local ok, s = pcall(function() return ScriptManager.instance:getModelScript(fullId) end)
    if not ok then return nil end                                              -- can't tell
    return s ~= nil
end

--- true / false, or nil when this build can't be asked. isKnownSound is strict:
--- getSound also answered for names that play nothing (sounds in the wrong module).
function I.soundExists(name)
    local ok, known = pcall(function() return GameSounds.isKnownSound(name) end)
    if not ok then return nil end
    return known == true
end

--- File the sound plays (first clip), or nil.
function I.soundFile(name)
    -- step by step: in debug mode even an error caught by pcall stops in the debugger
    local ok, f = pcall(function()
        local snd = GameSounds.getSound(name)
        local clip = snd and snd:getRandomClip()
        return clip and clip:getFile()
    end)
    return ok and f and tostring(f) or nil
end

--- Inventory icon of any item type (from its script), or nil. Used by the Gunsmith screen.
local iconCache = {}
function I.iconOf(fullType)
    if not fullType then return nil end
    if iconCache[fullType] ~= nil then return iconCache[fullType] or nil end
    local tex = nil
    local sm = ScriptManager and ScriptManager.instance
    local script = sm and sm:getItem(fullType)
    if script then tex = script:getNormalTexture() end
    iconCache[fullType] = tex or false
    return tex
end

--- Condition 0..1 of an item (1 when it can't be read).
function I.conditionOf(item)
    if not item then return 1 end
    local max = item:getConditionMax()
    if not max or max <= 0 then return 1 end
    return (item:getCondition() or max) / max
end

--- item:hasTag(ItemTag.<KEY>), e.g. I.hasTag(gun, "FIREARM"); nil if it can't be asked.
function I.hasTag(item, key)
    local ok, v = pcall(function() return item:hasTag(ItemTag[key]) end)
    if not ok then return nil end
    return v == true
end

--- Attachment point of a model script as the game read it: x, y, z (nil if missing).
function I.modelAttachment(modelFullId, point)
    -- nil-checked step by step: guns without that point made getOffset index nil, and in debug
    -- mode an error stops in the debugger even inside pcall (seen in game)
    local ok, x, y, z = pcall(function()
        local script = ScriptManager.instance:getModelScript(modelFullId)
        local att = script and script:getAttachmentById(point)
        local o = att and att:getOffset()
        if not o then return nil end
        return o:x(), o:y(), o:z()
    end)
    if not ok then return nil end
    return x, y, z
end

-- ------------------------------------------------------------ pose check (character)
function I.equipPrimary(character, item)
    return pcall(function()
        character:setPrimaryHandItem(item)
        -- instanceof first: the item held before may be a torch, and an error stops debug mode
        local twoHanded = item ~= nil and instanceof(item, "HandWeapon") and item:isTwoHandWeapon()
        character:setSecondaryHandItem(twoHanded and item or nil)
    end)
end
function I.primary(character)
    local ok, it = pcall(function() return character:getPrimaryHandItem() end)
    return ok and it or nil
end
function I.setAiming(character, on) return pcall(function() character:setIsAiming(on) end) end
--- Drop every queued timed action (vanilla ISTimedActionQueue.clear).
function I.clearActions(character) return pcall(function() ISTimedActionQueue.clear(character) end) end
--- Name of the animation state the character is in ("aim", "idle"...), or nil.
function I.actionState(character)
    local ok, v = pcall(function() return character:getActionStateName() end)
    return ok and v and tostring(v) or nil
end
function I.animVar(character, name)
    local ok, v = pcall(function() return character:getVariableString(name) end)
    return ok and v or nil
end
function I.removeItem(character, item)
    return pcall(function() character:getInventory():Remove(item) end)
end
--- Saves a screenshot (B42 global takeScreenshot(fileName)); true if the call worked.
function I.screenshot(fileName)
    return (pcall(function() takeScreenshot(fileName) end))
end

--- Add an item to a character's main inventory; returns it.
function I.give(character, fullType)
    local ok, it = pcall(function() return character:getInventory():AddItem(fullType) end)
    return ok and it or nil
end

--- Write lines to Zomboid/Lua/<name>. Returns true on success.
function I.writeLines(name, lines)
    local ok = pcall(function()
        local w = getFileWriter(name, true, false)
        for _, l in ipairs(lines) do w:writeln(l) end
        w:close()
    end)
    return ok
end

return I
