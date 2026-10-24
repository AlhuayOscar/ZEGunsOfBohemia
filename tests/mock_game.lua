--[[ Minimal fakes of the PZ objects the ammo code touches, so the real
     ZGB_ItemBridge + ZGB_AmmoActions code paths run offline. Not a game emulator. ]]
local Mock = {}

local function list(t)  -- java ArrayList-ish
    return { size = function() return #t end, get = function(_, i) return t[i + 1] end }
end

function Mock.item(fullType, props)
    local it = { ft = fullType, ammo = 0, ammoType = nil, md = {} }
    for k, v in pairs(props or {}) do it[k] = v end
    function it:getFullType() return self.ft end
    function it:getCurrentAmmoCount() return self.ammo end
    function it:setCurrentAmmoCount(n) self.ammo = n end
    function it:getAmmoType() return self.ammoType end
    function it:setAmmoType(t) self.ammoType = t end
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

return Mock
