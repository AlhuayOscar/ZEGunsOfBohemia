--[[ Minimal fakes of the PZ objects the ammo code touches, so the real
     ZGB_ItemBridge + ZGB_AmmoActions code paths run offline. Not a game emulator. ]]
local Mock = {}

local function list(t)  -- java ArrayList-ish
    return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

-- B42 ammo types: a registry of AmmoType objects, looked up by ResourceLocation, each
-- naming its item with getItemKey(). Only ids from media/registries.lua and vanilla exist.
local registry
local function ammoObject(item)
    return { item = item, getItemKey = function(self) return self.item end }
end
AmmoType = {
    get = function(loc)
        if not registry then
            registry = {}
            for ft, id in pairs(ZGB.AmmoCatalog.VANILLA_AMMO_IDS) do registry[id] = ammoObject(ft) end
            for _, r in ipairs(ZGB.AmmoCatalog.registrations()) do registry[r[1]] = ammoObject(r[2]) end
        end
        return registry[loc.id]
    end,
}
ResourceLocation = { of = function(id) return { id = id } end }

function Mock.item(fullType, props)
    local it = { ft = fullType, ammo = 0, md = {} }
    for k, v in pairs(props or {}) do it[k] = v end
    -- tests may set `ammoType = "<item full type>"`: store it as the game would, as an object
    if type(it.ammoType) == "string" then it.ammoType = ammoObject(it.ammoType) end
    function it:getFullType() return self.ft end
    function it:getCurrentAmmoCount() return self.ammo end
    function it:setCurrentAmmoCount(n) self.ammo = n end
    function it:getAmmoType() return self.ammoType end
    function it:setAmmoType(t)
        assert(type(t) == "table" and t.getItemKey, "setAmmoType wants an AmmoType object (B42), got " .. tostring(t))
        self.ammoType = t
    end
    function it:getModData() return self.md end
    function it:setJobType() end
    function it:setJobDelta() end
    return it
end

function Mock.inventory()
    local inv = { items = {} }
    function inv:add(it) table.insert(self.items, it); return it end
    function inv:AddItem(ft) return self:add(Mock.item(ft)) end
    function inv:AddItems(ft, n) for _ = 1, n do self:AddItem(ft) end end
    function inv:getAllTypeRecurse(ft)
        local out = {}
        for _, it in ipairs(self.items) do if it.ft == ft then out[#out + 1] = it end end
        return list(out)
    end
    function inv:getCountTypeRecurse(ft) return self:getAllTypeRecurse(ft):size() end
    function inv:getFirstTypeRecurse(ft) for _, it in ipairs(self.items) do if it.ft == ft then return it end end end
    function inv:RemoveOneOf(ft)
        for i, it in ipairs(self.items) do if it.ft == ft then table.remove(self.items, i); return end end
        error("none left")
    end
    function inv:containsRecursive(x) for _, it in ipairs(self.items) do if it == x then return true end end return false end
    inv.contains = inv.containsRecursive
    function inv:getItems() return list(self.items) end
    return inv
end

function Mock.player()
    local inv = Mock.inventory()
    return { inv = inv, getInventory = function() return inv end, isTimedActionInstant = function() return false end }
end

-- engine globals the action files touch at load time
ISBaseTimedAction = { derive = function(_, name) local c = { Type = name }; c.__index = c; return c end,
                      new = function(cls, ch) local o = setmetatable({}, cls); o.character = ch; return o end,
                      perform = function() end, stop = function() end }
Mock.queue = {}
ISTimedActionQueue = { add = function(a) table.insert(Mock.queue, a) end }
ISInventoryPaneContextMenu = { transferIfNeeded = function() end }
function Mock.runQueue() for _, a in ipairs(Mock.queue) do a:complete() end; Mock.queue = {} end

-- ------------------------------------------------------------ a fake game for the self-test
-- It reads OUR GENERATED FILES the way the game does: item scripts (ZGB_items_*.txt,
-- vanilla template fields and tags included), then the values ScriptApply writes at
-- boot on top; sound scripts (only `module Base` is known: the in-game silent-sound
-- bug); model scripts (attachment points). Any other getX / setX / isX is a plain
-- property, like a HandWeapon.
local SCRIPTS = "Contents/mods/ZEGunsOfBohemiaCore/42/media/scripts/"
local function readAll(path) local f = io.open(path, "rb"); if not f then return "" end local s = f:read("*a"); f:close(); return s end
local function scalar(v)
    if v == "true" or v == "TRUE" then return true elseif v == "false" or v == "FALSE" then return false end
    return tonumber(v) or v
end
local parsed
local function scripts()
    if parsed then return parsed end
    parsed = { items = {}, sounds = {}, models = {} }
    for _, f in ipairs({ "ZGB_items_weapons.txt", "ZGB_items_magazines.txt", "ZGB_items_parts.txt",
                         "ZGB_items_ammo.txt", "ZGB_items_casings.txt" }) do
        local text = readAll(SCRIPTS .. f):gsub("/%*.-%*/", "")
        local module = text:match("module%s+([%w_]+)")
        for name, body in text:gmatch("\n%s*item%s+([%w_]+)%s*{(.-)}") do
            local fields = {}
            for k, v in body:gmatch("\n%s*([%w_]+)%s*=%s*([^\n]-)%s*,") do fields[k] = scalar(v) end
            parsed.items[module .. "." .. name] = fields
        end
    end
    -- vanilla guns (the pose check's references), from the data extracted from the game
    for name, list in pairs(dofile("tools/data/vanilla_guns.lua")) do
        local fields = {}
        for _, kv in ipairs(list) do fields[kv[1]] = scalar(kv[2]) end
        parsed.items["Base." .. name] = fields
    end
    -- vanilla rounds our guns use (the game has them; we only reference them)
    for ft in pairs(ZGB.AmmoCatalog.VANILLA_AMMO_IDS) do
        parsed.items[ft] = { Tags = (ft == "Base.ShotgunShells") and "base:ammo;base:shotgunshell" or "base:ammo" }
    end
    local sounds = readAll(SCRIPTS .. "ZGB_sounds.txt"):gsub("/%*.-%*/", "")
    if sounds:match("module%s+([%w_]+)") == "Base" then          -- bare sound names are found only in Base
        for name, body in sounds:gmatch("\n%s*sound%s+([%w_]+)%s*{(.-)\n    }") do
            parsed.sounds[name] = body:match("file%s*=%s*([^,\n]+)")
        end
    end
    local models = readAll(SCRIPTS .. "ZGB_models.txt"):gsub("/%*.-%*/", "")
    for name, body in models:gmatch("\n%s*model%s+([%w_]+)%s*{(.-)\n    }") do
        local points = {}
        for p, x, y, z in body:gmatch("attachment%s+([%w_]+)%s*{%s*offset%s*=%s*([-%d%.]+)%s+([-%d%.]+)%s+([-%d%.]+)") do
            points[p] = { tonumber(x), tonumber(y), tonumber(z) }
        end
        parsed.models["ZGB." .. name] = points
    end
    return parsed
end

-- HandWeapon setters that take a Java int truncate (setRecoilDelay(12.67) -> 12, seen in game)
local JAVA_INT = { RecoilDelay = true, AimingTime = true, HitChance = true, ReloadTime = true,
                   SoundRadius = true, ProjectileCount = true }
-- vanilla spells a few script fields differently from their getters
local ALIAS = { Aimingtime = "AimingTime", Reloadtime = "ReloadTime", Projectilecount = "ProjectileCount",
                Swingtime = "SwingTime" }

local function scriptedItem(ft)
    local fields = scripts().items[ft]
    if not fields then return nil end
    local it = Mock.item(ft)
    local p = {}
    for k, v in pairs(fields) do p[ALIAS[k] or k] = v end
    function it:hasTag(tag) return (";" .. tostring(p.Tags or "") .. ";"):find(";" .. tag .. ";", 1, true) ~= nil end
    setmetatable(it, { __index = function(_, k)
        local field = k:match("^get(%u.*)") or k:match("^is(%u.*)")
        if field then return function() return p[field] end end
        field = k:match("^set(%u.*)")
        if field then return function(_, v)
            if JAVA_INT[field] and type(v) == "number" then v = (v >= 0) and math.floor(v) or math.ceil(v) end
            p[field] = v
        end end
    end })
    -- what ScriptApply's DoParam writes at boot (the view's anim params included)
    local spec = ZGB.WeaponFactory.get(ft)
    if spec then
        local provider = ZGB.Mode and ZGB.Mode.get()
        local anim = provider and provider.getAnimParams(spec.archetype, spec)
        for _, kv in ipairs(ZGB.ScriptApply.paramsFor(spec, anim)) do p[ALIAS[kv[1]] or kv[1]] = kv[2] end
        if Mock.scriptOverrides[ft] then for k, v in pairs(Mock.scriptOverrides[ft]) do p[k] = v end end
        it.ammoType = AmmoType.get(ResourceLocation.of(p.AmmoType))
    end
    local mag = ZGB.MagazineFactory.get(ft)
    if mag then
        p.MaxAmmo = mag.capacity
        for _, g in ipairs(ZGB.WeaponFactory.all()) do
            if ZGB.Magazines.accepts(g, ft) then it.ammoType = AmmoType.get(ResourceLocation.of(ZGB.AmmoCatalog.registryId(g.ammo))); break end
        end
    end
    function it:getMaxAmmo() return p.MaxAmmo end
    function it:setMaxAmmo(n) p.MaxAmmo = n end
    it.props = p
    return it
end

ItemTag = { FIREARM = "base:firearm", AMMO = "base:ammo", PISTOL_MAGAZINE = "base:pistolmagazine",
            RIFLE_MAGAZINE = "base:riflemagazine", SHOTGUN_SHELL = "base:shotgunshell" }

Mock.written, Mock.screenshots = {}, {}
Mock.scriptOverrides = {}
function Mock.installGame(opts)
    opts = opts or {}
    parsed = nil                                 -- re-read the generated files
    Mock.scriptOverrides = opts.script or {}     -- { ["ZGB.Glock17"] = { SwingSound = "..." } }: a script DoParam got wrong
    instanceItem = function(ft)
        if opts.noItem and opts.noItem[ft] then return nil end
        return scriptedItem(ft)
    end
    ScriptManager = { instance = {
        -- the item script's AmmoType as the registry object (Gunworks wants it as each round's enum)
        FindItem = function(_, ft)
            if opts.noItem and opts.noItem[ft] then return nil end
            local fields = scripts().items[ft]
            if not fields then return nil end
            return { getAmmoType = function()
                return fields.AmmoType and AmmoType.get(ResourceLocation.of(fields.AmmoType)) or nil
            end }
        end,
        getItem = function(_, ft)
            if opts.noItem and opts.noItem[ft] then return nil end
            local fields = scripts().items[ft]
            if not fields then return nil end
            return { getNormalTexture = function() return { path = "Item_" .. tostring(fields.Icon) } end }
        end,
        getModelScript = function(_, id)
            local points = scripts().models[id]
            if not points then return nil end
            return { getAttachmentById = function(_, p)
                local o = points[p]
                if not o then return nil end
                return { getOffset = function()
                    return { x = function() return o[1] end, y = function() return o[2] end, z = function() return o[3] end }
                end }
            end }
        end,
    } }
    GameSounds = {
        isKnownSound = function(name) return scripts().sounds[name] ~= nil end,
        getSound = function(name)
            local file = scripts().sounds[name]
            return file and { getRandomClip = function() return { getFile = function() return file end } end } or nil
        end,
    }
    getFileWriter = function(name)
        local lines = {}
        Mock.written[name] = lines
        return { writeln = function(_, l) lines[#lines + 1] = l end, close = function() end }
    end
    Mock.screenshots = {}
    takeScreenshot = function(name) Mock.screenshots[#Mock.screenshots + 1] = name end
    -- the game's instanceof: our scripted guns and the vanilla references are HandWeapons
    instanceof = function(o, class)
        if type(o) ~= "table" then return false end
        if class == "HandWeapon" then return o.props ~= nil and o.props.Ranged == true end
        if class == "InventoryItem" then return o.ft ~= nil end
        return false
    end
end

--- A player for the pose check: hands, aiming, inventory and the vanilla "Weapon" anim variable
--- (vanilla AnimSets pick the gun poses with Weapon = firearm, which needs the base:firearm tag).
function Mock.posePlayer()
    local p = Mock.player()
    p.vars = {}
    function p:getInventory()
        return { AddItem = function(_, ft) return p.inv:add(instanceItem(ft)) end,
                 Remove = function(_, it) for i, x in ipairs(p.inv.items) do if x == it then table.remove(p.inv.items, i) end end end }
    end
    function p:setPrimaryHandItem(it)
        self.primaryItem = it
        -- as the game does (pose check in game): one-handed firearms are "handgun", long guns "firearm"
        local firearm = it and it.hasTag and it:hasTag("base:firearm")
        self.vars.Weapon = firearm and (it:isTwoHandWeapon() and "firearm" or "handgun") or ""
    end
    function p:setSecondaryHandItem(it) self.secondaryItem = it end
    function p:getPrimaryHandItem() return self.primaryItem end
    function p:setIsAiming(on) self.aiming = on end
    function p:isAiming() return self.aiming end
    function p:getActionStateName() return self.aiming and "aim" or "idle" end
    function p:getVariableString(k) return self.vars[k] end
    function p:Say() end
    return p
end

return Mock
