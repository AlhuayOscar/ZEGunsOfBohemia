--[[
    ZGB_GunsmithWindow.lua  —  the attachment UI.

    Shows the gun's whole attachment tree, including slots that only exist once
    a mount is fitted (ghost slots), e.g. for a bare AK:

        Side mount              (empty)
          AK Side Rail Mount        READY
            Optic rail              needs AK Side Rail Mount
              Red Dot Sight         needs AK Side Rail Mount
              4x Combat Scope       needs AK Side Rail Mount
        Muzzle                  (empty)
          AK Suppressor             NOT OWNED
        ...

    Selecting a part shows the stat change it would cause. Attach/Detach queue
    the timed actions; the window refreshes itself when the gun changes.
]]
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_PartActions"

ZGB_GunsmithWindow = ISCollapsableWindow:derive("ZGB_GunsmithWindow")
ZGB_GunsmithWindow.instances = {}

local R, PF = ZGB.Attachments, ZGB.PartFactory

local COLORS = {
    installed = { 0.35, 0.95, 0.45 },
    ready     = { 1.00, 1.00, 1.00 },
    notOwned  = { 0.60, 0.60, 0.60 },
    needs     = { 1.00, 0.65, 0.20 },
    taken     = { 0.95, 0.85, 0.35 },
    slot      = { 0.75, 0.85, 1.00 },
    ghost     = { 0.55, 0.55, 0.65 },
    bad       = { 1.00, 0.35, 0.35 },
}

local STAT_LINES = {
    { "maxDamage",   "Damage",  "%.2f", false },
    { "range",       "Range",   "%.1f", false },
    { "aimTime",     "Aim time","%d",   true  },   -- true = lower is better
    { "recoilDelay", "Recoil",  "%d",   true  },
    { "hitChance",   "Accuracy","%d",   false },
    { "soundRadius", "Noise",   "%d",   true  },
    { "weight",      "Weight",  "%.2f", true  },
}

local function nameOf(fullType)
    local p = PF.get(fullType)
    return p and p.displayName or tostring(fullType)
end

local function chainText(chain)
    local names = {}
    for _, ft in ipairs(chain) do names[#names + 1] = nameOf(ft) end
    return table.concat(names, " + ")
end

-- ------------------------------------------------------------ open / close
function ZGB_GunsmithWindow.open(player, weapon)
    local num = player:getPlayerNum()
    local existing = ZGB_GunsmithWindow.instances[num]
    if existing then existing:close() end
    local w = ZGB_GunsmithWindow:new(100, 100, 560, 520, player, weapon)
    w:initialise()
    w:addToUIManager()
    ZGB_GunsmithWindow.instances[num] = w
    return w
end

function ZGB_GunsmithWindow:close()
    ZGB_GunsmithWindow.instances[self.player:getPlayerNum()] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

-- ------------------------------------------------------------ layout
function ZGB_GunsmithWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local th = self:titleBarHeight()
    self.fontH = getTextManager():getFontHeight(UIFont.Small)
    self.headerH = self.fontH * 2 + 14
    self.footerH = self.fontH * 6 + 50

    self.list = ISScrollingListBox:new(10, th + self.headerH, self.width - 20,
                                       self.height - th - self.headerH - self.footerH)
    self.list:initialise()
    self.list:instantiate()
    self.list.itemheight = self.fontH + 6
    self.list.font = UIFont.Small
    self.list.drawBorder = true
    self.list.doDrawItem = ZGB_GunsmithWindow.drawRow
    self.list.parentWindow = self
    self.list:setOnMouseDownFunction(self, ZGB_GunsmithWindow.onSelect)
    self:addChild(self.list)

    local by = self.height - 32
    self.btnAttach = ISButton:new(10, by, 110, 24, "Attach", self, ZGB_GunsmithWindow.onAttach)
    self.btnDetach = ISButton:new(130, by, 110, 24, "Detach", self, ZGB_GunsmithWindow.onDetach)
    self.btnClose  = ISButton:new(self.width - 120, by, 110, 24, "Close", self, ZGB_GunsmithWindow.close)
    for _, b in ipairs({ self.btnAttach, self.btnDetach, self.btnClose }) do
        b:initialise(); b:instantiate(); self:addChild(b)
    end
    self:refresh()
end

-- ------------------------------------------------------------ data
function ZGB_GunsmithWindow:hasPart(fullType)
    local inv = self.player:getInventory()
    return inv:getFirstTypeRecurse(fullType) ~= nil            -- VERIFY B42 accepts full types
end

--- Decide what a row says and which buttons it enables.
function ZGB_GunsmithWindow:describe(row)
    local spec, att = self.spec, self.att
    if row.kind == "slot" then
        if row.state == "ghost" then
            return "needs " .. nameOf(row.via), COLORS.ghost
        elseif row.state == "occupied" then
            return nameOf(row.installed), COLORS.installed
        end
        return "(empty)", COLORS.slot
    end

    if row.installed then return "INSTALLED", COLORS.installed, { detach = true } end
    local ok, reason, info = R.canAttach(spec, att, row.part)
    if ok then
        if self:hasPart(row.part) then return "READY", COLORS.ready, { attach = true } end
        return "NOT OWNED", COLORS.notOwned
    end
    if reason == "needs" then return "needs " .. chainText(info.chains[1]), COLORS.needs end
    if reason == "occupied" then return "slot taken: " .. nameOf(info.by), COLORS.taken end
    if reason == "already_installed" then return "installed elsewhere", COLORS.notOwned end
    return "incompatible", COLORS.bad
end

function ZGB_GunsmithWindow:signature()
    local att, keys = ZGB.Item.getAttachments(self.weapon), {}
    for k, v in pairs(att) do keys[#keys + 1] = k .. "=" .. v end
    table.sort(keys)
    return table.concat(keys, ";") .. "|mag=" .. tostring(ZGB.Item.loadedMagazine(self.weapon))
        .. "|ammo=" .. tostring(ZGB.Item.loadedAmmo(self.weapon))
end

function ZGB_GunsmithWindow:refresh()
    self.spec = ZGB.WeaponFactory.specOf(self.weapon)
    self.att  = ZGB.Item.getAttachments(self.weapon)
    self.mag  = ZGB.Item.loadedMagazine(self.weapon)
    self.ammoFt = ZGB.Item.loadedAmmo(self.weapon)
    self.stats = ZGB.Stats.compute(self.spec, self.att, self.mag, self.ammoFt)
    self.sig = self:signature()
    self.title = "Gunsmith - " .. self.spec.displayName

    local keepSelected = self.list.selected
    self.list:clear()
    for _, row in ipairs(R.buildTree(self.spec, self.att)) do
        local status, color, actions = self:describe(row)
        row.status, row.color, row.actions = status, color, actions or {}
        local label = row.kind == "slot" and row.label or nameOf(row.part)
        self.list:addItem(label, row)
    end
    if keepSelected and keepSelected <= #self.list.items then self.list.selected = keepSelected end
    self:updateButtons()
end

function ZGB_GunsmithWindow:selectedRow()
    local it = self.list.items[self.list.selected]
    return it and it.item
end

function ZGB_GunsmithWindow:updateButtons()
    local row = self:selectedRow()
    local a = row and row.actions or {}
    self.btnAttach:setEnable(a.attach == true)
    self.btnDetach:setEnable(a.detach == true or (row and row.kind == "slot" and row.state == "occupied") or false)
end

-- ------------------------------------------------------------ events
function ZGB_GunsmithWindow:onSelect(row) self:updateButtons() end

function ZGB_GunsmithWindow:onAttach()
    local row = self:selectedRow()
    if not row or row.kind ~= "part" then return end
    local item = self.player:getInventory():getFirstTypeRecurse(row.part)
    if not item then return end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, item)
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, self.weapon)
    ISTimedActionQueue.add(ZGB_AttachPartAction:new(self.player, self.weapon, item))
end

function ZGB_GunsmithWindow:onDetach()
    local row = self:selectedRow()
    if not row then return end
    local ok, reason, info = R.canDetach(self.spec, self.att, row.slotId)
    if not ok then
        if reason == "has_children" then
            self.player:Say("Remove " .. nameOf(info.children[1].part) .. " first")
        end
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, self.weapon)
    ISTimedActionQueue.add(ZGB_DetachPartAction:new(self.player, self.weapon, row.slotId))
end

function ZGB_GunsmithWindow:update()
    ISCollapsableWindow.update(self)
    if not self.player:getInventory():containsRecursive(self.weapon) then self:close(); return end
    if self:signature() ~= self.sig then self:refresh() end
end

-- ------------------------------------------------------------ drawing
function ZGB_GunsmithWindow.drawRow(list, y, item, alt)
    local row, h = item.item, list.itemheight
    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), h - 1, 0.25, 0.7, 0.55, 0.2)
    elseif row.kind == "slot" then
        list:drawRect(0, y, list:getWidth(), h - 1, 0.12, 0.4, 0.5, 0.8)
    end
    local x = 8 + row.depth * 14
    local c = row.kind == "slot" and (row.state == "ghost" and COLORS.ghost or COLORS.slot) or COLORS.ready
    local font = row.kind == "slot" and UIFont.Small or UIFont.Small
    list:drawText(item.text, x, y + 3, c[1], c[2], c[3], 1, font)
    local sc = row.color or COLORS.ready
    local sw = getTextManager():MeasureStringX(UIFont.Small, row.status or "")
    list:drawText(row.status or "", list:getWidth() - sw - 14, y + 3, sc[1], sc[2], sc[3], 1, UIFont.Small)
    return y + h
end

function ZGB_GunsmithWindow:render()
    ISCollapsableWindow.render(self)
    if not self.spec then return end
    local th, fh = self:titleBarHeight(), self.fontH

    -- header: ammo + caliber
    local ammoNow = 0
    pcall(function() ammoNow = self.weapon:getCurrentAmmoCount() end)     -- VERIFY
    local M = ZGB.Magazines
    local capacity = M.capacityFor(self.spec, self.mag)
    local magTxt
    if #M.list(self.spec) == 0 then
        magTxt = "Tube-fed"
    else
        local loadedM = self.mag and M.get(self.spec, self.mag)
        magTxt = "Loaded: " .. (loadedM and M.labelOf(loadedM) or "none")
    end
    local v = self.ammoFt and ZGB.AmmoCatalog.variantOfItem(self.ammoFt)
    local cal = ZGB.AmmoCatalog.CALIBERS[self.spec.caliber]
    local ammoTxt = (cal and cal.label or self.spec.caliber) .. (v and (" " .. v.label) or "")
    self:drawText(string.format("%s   Ammo %d/%d  (%s)   %s", self.spec.displayName, ammoNow,
        capacity, ammoTxt, magTxt), 12, th + 6, 1, 1, 1, 1, UIFont.Small)

    -- line 2: every magazine this gun takes
    local labels = {}
    for _, m in ipairs(M.list(self.spec)) do labels[#labels + 1] = M.labelOf(m) end
    local line2 = #labels > 0 and ("Takes: " .. table.concat(labels, ", "))
                  or "Green = installed, orange = needs another part first, grey = you don't have it"
    self:drawText(line2, 12, th + 6 + fh + 2, 0.6, 0.6, 0.6, 1, UIFont.Small)

    -- footer: stats, with preview for the selected part
    local row = self:selectedRow()
    local preview
    if row and row.kind == "part" and not row.installed then
        local nextAtt = R.attach(self.spec, self.att, row.part)
        if nextAtt then preview = ZGB.Stats.compute(self.spec, nextAtt, self.mag, self.ammoFt) end
    elseif row and row.kind == "part" and row.installed then
        local nextAtt = R.detach(self.spec, self.att, row.slotId)
        if nextAtt then preview = ZGB.Stats.compute(self.spec, nextAtt, self.mag, self.ammoFt) end
    end

    local y0 = self.height - self.footerH + 6
    local colW = math.floor((self.width - 24) / 2)
    for i, line in ipairs(STAT_LINES) do
        local key, label, fmt, lowerBetter = line[1], line[2], line[3], line[4]
        local cur = self.stats[key]
        if cur then
            local col, r = (i - 1) % 2, math.floor((i - 1) / 2)
            local x, y = 12 + col * colW, y0 + r * (fh + 3)
            local txt = label .. ": " .. string.format(fmt, cur)
            self:drawText(txt, x, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
            if preview and preview[key] and math.abs(preview[key] - cur) > 0.001 then
                local d = preview[key] - cur
                local good = (d < 0) == lowerBetter
                local tw = getTextManager():MeasureStringX(UIFont.Small, txt)
                self:drawText(string.format(" -> " .. fmt, preview[key]), x + tw, y,
                    good and 0.4 or 1, good and 1 or 0.4, 0.4, 1, UIFont.Small)
            end
        end
    end
end

-- ------------------------------------------------------------ ctor
function ZGB_GunsmithWindow:new(x, y, w, h, player, weapon)
    local o = ISCollapsableWindow.new(self, x, y, w, h)
    o.player, o.weapon = player, weapon
    o.resizable = false
    o.title = "Gunsmith"
    return o
end
