--[[
    ZGB_GunsmithWindow.lua  —  the Gunsmith: a full-screen inspect screen.

        [icon] 100% / Pistol / 9x19        Glock 17                      [X]
        [rounds] 45   [mags] 3
                          [ ] Optic rail
                               \
             [ ] Muzzle ----  ==GUN==  ---- [ ] Stock         Weapon Data
                               /                                Damage   1.80
                          [ ] Laser                             Range   27.8 ...
                                                     [mag] 17-round magazine

    Every slot sits next to where its part goes (ZGB_InspectLayout, pure and
    tested), with a line to that spot. Click a slot: a grid of every part that
    fits it. Green = fitted (click to remove), white = you have it (click to
    fit), grey = you don't have it, orange = needs another part first (the
    slot of an AK optic rail before the side mount). Hovering a part shows the
    stat change in Weapon Data and the gun with that part. Fitting and removing
    queue the same timed actions as before; the screen refreshes when the gun
    changes and closes with X, Escape or when the gun leaves the inventory.
]]
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ZGB/ZGB_ItemBridge"
require "ZGB/ZGB_PartActions"
require "ZGB/ZGB_InspectLayout"

ZGB_GunsmithWindow = ISPanel:derive("ZGB_GunsmithWindow")
ZGB_GunsmithWindow.instances = {}

local R, PF, IL, I = ZGB.Attachments, ZGB.PartFactory, ZGB.InspectLayout, ZGB.Item

local C = {
    dim       = { 0.62, 0.02, 0.02, 0.03 },     -- a, r, g, b of the backdrop
    panel     = { 0.80, 0.10, 0.10, 0.11 },
    box       = { 0.55, 0.35, 0.35, 0.37 },
    boxHover  = { 0.70, 0.50, 0.50, 0.52 },
    installed = { 0.35, 0.95, 0.45 },
    ready     = { 1.00, 1.00, 1.00 },
    notOwned  = { 0.50, 0.50, 0.50 },
    needs     = { 1.00, 0.65, 0.20 },
    ghost     = { 0.45, 0.45, 0.55 },
    line      = { 0.55, 0.80, 0.80, 0.80 },
    good      = { 0.40, 1.00, 0.40 },
    bad       = { 1.00, 0.40, 0.40 },
}

-- Weapon Data rows: stat key, label, format, lower is better
local STAT_LINES = {
    { "maxDamage",   "Damage",       "%.2f", false },
    { "range",       "Max Range",    "%.1f", false },
    { "recoilDelay", "Recoil",       "%d",   true  },
    { "aimTime",     "Aiming Time",  "%d",   true  },
    { "reloadTime",  "Reload Time",  "%d",   true  },
    { "hitChance",   "Accuracy",     "%d",   false },
    { "critChance",  "Critical",     "%.0f", false },
    { "soundRadius", "Noise",        "%d",   true  },
    { "weight",      "Weight",       "%.2f", true  },
}

local GRID_COLS, CELL = 5, 58
local STATS_W = 300

local function nameOf(fullType)
    local p = PF.get(fullType)
    return p and p.displayName or tostring(fullType)
end

local function inside(px, py, r) return px >= r.x and py >= r.y and px < r.x + r.w and py < r.y + r.h end

--- Cut text to a width (labels sit next to each other in a lane).
local function fit(s, width)
    local tm = getTextManager()
    if tm:MeasureStringX(UIFont.Small, s) <= width then return s end
    while #s > 1 and tm:MeasureStringX(UIFont.Small, s .. "..") > width do s = s:sub(1, -2) end
    return s .. ".."
end

-- ------------------------------------------------------------ open / close
function ZGB_GunsmithWindow.open(player, weapon)
    local num = player:getPlayerNum()
    local existing = ZGB_GunsmithWindow.instances[num]
    if existing then existing:close() end
    local core = getCore()
    local w = ZGB_GunsmithWindow:new(0, 0, core:getScreenWidth(), core:getScreenHeight(), player, weapon)
    w:initialise()
    w:addToUIManager()
    w:bringToTop()
    ZGB_GunsmithWindow.instances[num] = w
    return w
end

function ZGB_GunsmithWindow:close()
    ZGB_GunsmithWindow.instances[self.player:getPlayerNum()] = nil
    self:setVisible(false)
    self:removeFromUIManager()
end

Events.OnKeyPressed.Add(function(key)
    if key ~= Keyboard.KEY_ESCAPE then return end
    for _, w in pairs(ZGB_GunsmithWindow.instances) do w:close() end
end)

function ZGB_GunsmithWindow:createChildren()
    ISPanel.createChildren(self)
    self.btnClose = ISButton:new(self.width - 44, 12, 32, 32, "X", self, ZGB_GunsmithWindow.close)
    self.btnClose:initialise(); self.btnClose:instantiate()
    self:addChild(self.btnClose)
    self:refresh()
end

-- ------------------------------------------------------------ data
function ZGB_GunsmithWindow:owned(fullType)
    return self.player:getInventory():getFirstTypeRecurse(fullType)
end

function ZGB_GunsmithWindow:signature()
    local att, keys = I.getAttachments(self.weapon), {}
    for k, v in pairs(att) do keys[#keys + 1] = k .. "=" .. v end
    table.sort(keys)
    return table.concat(keys, ";") .. "|mag=" .. tostring(I.loadedMagazine(self.weapon))
        .. "|ammo=" .. tostring(I.loadedAmmo(self.weapon))
end

function ZGB_GunsmithWindow:stage()
    return { x = 24, y = 96, w = self.width - STATS_W - 72, h = self.height - 170 }
end

function ZGB_GunsmithWindow:refresh()
    self.spec = ZGB.WeaponFactory.specOf(self.weapon)
    if not self.spec then return end
    self.att = I.getAttachments(self.weapon)
    self.mag = I.loadedMagazine(self.weapon)
    self.ammoFt = I.loadedAmmo(self.weapon)
    self.stats = ZGB.Stats.compute(self.spec, self.att, self.mag, self.ammoFt)
    self.layout = IL.compute(self.spec, self.att, self:stage())
    self.sig = self:signature()
    -- parts per slot, from the same tree the rules use
    self.partsBySlot = {}
    for _, row in ipairs(R.buildTree(self.spec, self.att)) do
        if row.kind == "part" then
            local list = self.partsBySlot[row.slotId] or {}
            list[#list + 1] = row
            self.partsBySlot[row.slotId] = list
        end
    end
    if self.picker and not self:slotById(self.picker.slotId) then self.picker = nil end
end

function ZGB_GunsmithWindow:slotById(slotId)
    for _, s in ipairs(self.layout and self.layout.slots or {}) do if s.slotId == slotId then return s end end
end

--- Status of one part in a slot: "installed" | "ready" | "notOwned" | "needs" | "taken"
function ZGB_GunsmithWindow:partState(row)
    if row.installed then return "installed" end
    local ok, reason = R.canAttach(self.spec, self.att, row.part)
    if ok then return self:owned(row.part) and "ready" or "notOwned" end
    if reason == "needs" then return "needs" end
    if reason == "occupied" then return self:owned(row.part) and "taken" or "notOwned" end
    return "notOwned"
end

-- ------------------------------------------------------------ actions
function ZGB_GunsmithWindow:fit(row)
    local item = self:owned(row.part)
    if not item then return end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, item)
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, self.weapon)
    ISTimedActionQueue.add(ZGB_AttachPartAction:new(self.player, self.weapon, item))
end

function ZGB_GunsmithWindow:remove(slotId)
    local ok, reason, info = R.canDetach(self.spec, self.att, slotId)
    if not ok then
        if reason == "has_children" then I.say(self.player, "Remove " .. nameOf(info.children[1].part) .. " first") end
        return
    end
    ISInventoryPaneContextMenu.transferIfNeeded(self.player, self.weapon)
    ISTimedActionQueue.add(ZGB_DetachPartAction:new(self.player, self.weapon, slotId))
end

-- ------------------------------------------------------------ picker (grid of parts for a slot)
function ZGB_GunsmithWindow:pickerRect()
    local p = self.picker
    local slot = p and self:slotById(p.slotId)
    if not slot then return nil end
    local n = #(self.partsBySlot[p.slotId] or {})
    local rows = math.max(1, math.ceil(n / GRID_COLS))
    local w, h = GRID_COLS * CELL + 8, rows * CELL + 30
    local x = math.min(slot.box.x + IL.BOX + 6, self.width - STATS_W - w - 40)
    local y = math.max(60, math.min(slot.box.y, self.height - h - 20))
    return { x = x, y = y, w = w, h = h }
end

function ZGB_GunsmithWindow:pickerCellAt(mx, my)
    local r = self:pickerRect()
    if not r then return nil end
    local list = self.partsBySlot[self.picker.slotId] or {}
    for i, row in ipairs(list) do
        local cx = r.x + 4 + ((i - 1) % GRID_COLS) * CELL
        local cy = r.y + 26 + math.floor((i - 1) / GRID_COLS) * CELL
        if inside(mx, my, { x = cx, y = cy, w = CELL - 4, h = CELL - 4 }) then return row, cx, cy end
    end
end

-- ------------------------------------------------------------ input
function ZGB_GunsmithWindow:onMouseDown(x, y)
    if not self.layout then return true end
    if self.picker then
        local row = self:pickerCellAt(x, y)
        if row then
            local st = self:partState(row)
            if st == "installed" then self:remove(row.slotId)
            elseif st == "ready" then self:fit(row)
            elseif st == "needs" then I.say(self.player, "Fit the part this slot sits on first")
            elseif st == "taken" then I.say(self.player, "Remove " .. nameOf(self.att[row.slotId]) .. " first")
            end
            return true
        end
        local r = self:pickerRect()
        if r and inside(x, y, r) then return true end
    end
    for _, slot in ipairs(self.layout.slots) do
        if inside(x, y, slot.box) then
            self.picker = (self.picker and self.picker.slotId == slot.slotId) and nil or { slotId = slot.slotId }
            return true
        end
    end
    self.picker = nil
    return true
end

function ZGB_GunsmithWindow:onMouseMove(dx, dy)
    self.mx, self.my = self:getMouseX(), self:getMouseY()
end
ZGB_GunsmithWindow.onMouseMoveOutside = ZGB_GunsmithWindow.onMouseMove

function ZGB_GunsmithWindow:update()
    ISPanel.update(self)
    if not self.player:getInventory():containsRecursive(self.weapon) then self:close(); return end
    if self:signature() ~= self.sig then self:refresh() end
end

-- ------------------------------------------------------------ drawing
local textures = {}
local function sprite(name)
    if textures[name] == nil then textures[name] = getTexture("media/textures/ZGB/Preview/" .. name .. ".png") or false end
    return textures[name] or nil
end

function ZGB_GunsmithWindow:text(s, x, y, c, font, a)
    c = c or C.ready
    self:drawText(s, x, y, c[1], c[2], c[3], a or 1, font or UIFont.Small)
end

function ZGB_GunsmithWindow:drawGun(att, alpha)
    local g = self.layout.gun
    local pr = ZGB.Visuals.previewRects(self.spec, att)
    for _, r in ipairs(pr.rects) do
        local tex = sprite(r.sprite)
        if tex then self:drawTextureScaled(tex, g.ox + r.x * g.scale, g.oy + r.y * g.scale, r.w * g.scale, r.h * g.scale, alpha, 1, 1, 1) end
    end
end

function ZGB_GunsmithWindow:drawSlot(slot, hover)
    local b = slot.box
    local sq = { x = b.x, y = b.y, w = IL.BOX, h = IL.BOX }
    local edge = slot.installed and C.installed or (slot.state == "ghost" and C.ghost or { 0.75, 0.35, 0.35 })
    -- line from the box to where the part goes
    self:drawLine2(sq.x + sq.w / 2, sq.y + sq.h / 2, slot.anchor.x, slot.anchor.y, C.line[1], C.line[2], C.line[3], C.line[4])
    self:drawRect(slot.anchor.x - 2, slot.anchor.y - 2, 5, 5, 0.9, edge[1], edge[2], edge[3])
    local bg = hover and C.boxHover or C.box
    self:drawRect(sq.x, sq.y, sq.w, sq.h, bg[1], bg[2], bg[3], bg[4])
    self:drawRectBorder(sq.x, sq.y, sq.w, sq.h, 0.9, edge[1], edge[2], edge[3])
    local icon = slot.installed and I.iconOf(slot.installed)
    if icon then
        self:drawTextureScaledAspect(icon, sq.x + 6, sq.y + 6, sq.w - 12, sq.h - 12, 1, 1, 1, 1)
    else
        self:drawTextCentre("+", sq.x + sq.w / 2, sq.y + sq.h / 2 - 9, 0.85, 0.85, 0.85, slot.state == "ghost" and 0.4 or 0.9, UIFont.Medium)
    end
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local name = slot.installed and nameOf(slot.installed) or (slot.state == "ghost" and ("needs " .. nameOf(slot.via)) or "None")
    local labelW = IL.LABEL_W - 12
    self:text(fit(name, labelW), sq.x + sq.w + 8, sq.y + sq.h / 2 - fh, slot.state == "ghost" and C.ghost or C.ready)
    self:text(fit(slot.label, labelW), sq.x + sq.w + 8, sq.y + sq.h / 2 + 1, { 0.70, 0.70, 0.70 })
end

function ZGB_GunsmithWindow:drawPicker()
    local r = self:pickerRect()
    if not r then return end
    local slot = self:slotById(self.picker.slotId)
    self:drawRect(r.x, r.y, r.w, r.h, 0.92, 0.08, 0.08, 0.09)
    self:drawRectBorder(r.x, r.y, r.w, r.h, 1, 0.6, 0.6, 0.6)
    self:text(slot.label, r.x + 6, r.y + 5, { 0.85, 0.85, 0.85 })
    local hoverRow = self.mx and self:pickerCellAt(self.mx, self.my)
    for i, row in ipairs(self.partsBySlot[self.picker.slotId] or {}) do
        local cx = r.x + 4 + ((i - 1) % GRID_COLS) * CELL
        local cy = r.y + 26 + math.floor((i - 1) / GRID_COLS) * CELL
        local st = self:partState(row)
        local c = C[st] or C.notOwned
        self:drawRect(cx, cy, CELL - 4, CELL - 4, hoverRow == row and 0.8 or 0.5, 0.22, 0.22, 0.24)
        self:drawRectBorder(cx, cy, CELL - 4, CELL - 4, 1, c[1], c[2], c[3])
        local icon = I.iconOf(row.part)
        local a = (st == "notOwned" or st == "needs") and 0.35 or 1
        if icon then self:drawTextureScaledAspect(icon, cx + 5, cy + 5, CELL - 14, CELL - 14, a, 1, 1, 1) end
    end
    if hoverRow then
        local st = self:partState(hoverRow)
        local tip = nameOf(hoverRow.part) .. ({ installed = "  (click to remove)", ready = "  (click to fit)",
            notOwned = "  (you don't have it)", needs = "  (needs another part first)", taken = "  (slot taken)" })[st]
        self:text(tip, r.x + 6, r.y + r.h + 4, C[st] or C.ready)
    end
end

--- Stats if the hovered part were fitted / removed (nil when nothing is hovered).
function ZGB_GunsmithWindow:previewAttachments()
    local row = self.picker and self.mx and self:pickerCellAt(self.mx, self.my)
    if not row then return nil end
    if row.installed then return R.detach(self.spec, self.att, row.slotId) end
    return R.attach(self.spec, self.att, row.part)
end

function ZGB_GunsmithWindow:drawStats(previewAtt)
    local x, y, w = self.width - STATS_W - 24, 64, STATS_W
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local h = 40 + #STAT_LINES * (fh + 8) + fh + 16
    self:drawRect(x, y, w, h, C.panel[1], C.panel[2], C.panel[3], C.panel[4])
    self:text("Weapon Data", x + 12, y + 8, C.ready, UIFont.Medium)
    local preview = previewAtt and ZGB.Stats.compute(self.spec, previewAtt, self.mag, self.ammoFt)
    local ty = y + 40
    for i, line in ipairs(STAT_LINES) do
        local key, label, fmt, lowerBetter = line[1], line[2], line[3], line[4]
        local cur = self.stats[key]
        if cur then
            if i % 2 == 0 then self:drawRect(x + 4, ty - 2, w - 8, fh + 6, 0.25, 0.3, 0.3, 0.3) end
            self:text(label, x + 12, ty)
            local val = string.format("(" .. fmt .. ")", cur)
            local nv = preview and preview[key]
            if nv and math.abs(nv - cur) > 0.001 then
                local good = ((nv - cur) < 0) == lowerBetter
                val = string.format("(" .. fmt .. " > " .. fmt .. ")", cur, nv)
                local vw = getTextManager():MeasureStringX(UIFont.Small, val)
                self:text(val, x + w - 12 - vw, ty, good and C.good or C.bad)
            else
                local vw = getTextManager():MeasureStringX(UIFont.Small, val)
                self:text(val, x + w - 12 - vw, ty)
            end
            ty = ty + fh + 8
        end
    end
    local M = ZGB.Magazines
    local cap = M.capacityFor(self.spec, self.mag)
    local capTxt = string.format("(%d)", cap)
    self:text("Magazine Capacity", x + 12, ty)
    self:text(capTxt, x + w - 12 - getTextManager():MeasureStringX(UIFont.Small, capTxt), ty)
end

function ZGB_GunsmithWindow:drawInfo()
    local x, y = 20, 16
    local gunIcon = I.iconOf(self.spec.fullType)
    self:drawRect(x, y, 64, 64, 0.6, 0.15, 0.25, 0.15)
    self:drawRectBorder(x, y, 64, 64, 1, 0.35, 0.6, 0.35)
    if gunIcon then self:drawTextureScaledAspect(gunIcon, x + 4, y + 4, 56, 56, 1, 1, 1, 1) end
    local cal = ZGB.AmmoCatalog.CALIBERS[self.spec.caliber]
    local fh = getTextManager():getFontHeight(UIFont.Small)
    self:text(string.format("%d%%", math.floor(I.conditionOf(self.weapon) * 100 + 0.5)), x + 74, y + 4)
    self:text((string.gsub(self.spec.category or self.spec.archetype or "", "_", " ")), x + 74, y + 6 + fh)
    self:text(cal and cal.label or self.spec.caliber, x + 74, y + 8 + fh * 2)
    -- what you carry for it
    local inv = self.player:getInventory()
    local rounds = 0
    for _, n in pairs(I.ammoCounts(inv, self.spec.caliber)) do rounds = rounds + n end
    local mags = #I.compatibleMagazinesIn(inv, self.spec)
    local ammoIcon = I.iconOf(self.spec.ammo)
    local ly = y + 76
    if ammoIcon then self:drawTextureScaledAspect(ammoIcon, x, ly, 28, 28, 1, 1, 1, 1) end
    self:text(string.format("%d rounds", rounds), x + 34, ly + 6)
    if #ZGB.Magazines.list(self.spec) > 0 then
        local magIcon = I.iconOf(ZGB.Magazines.list(self.spec)[1].item)
        if magIcon then self:drawTextureScaledAspect(magIcon, x, ly + 32, 28, 28, 1, 1, 1, 1) end
        self:text(string.format("%d magazines", mags), x + 34, ly + 38)
    end
end

function ZGB_GunsmithWindow:drawMagazine()
    local M = ZGB.Magazines
    local st = self:stage()
    local x, y = st.x + st.w - IL.BOX - 220, st.y + st.h + 8
    local loaded = self.mag and M.get(self.spec, self.mag)
    local icon = loaded and I.iconOf(loaded.item) or (#M.list(self.spec) > 0 and I.iconOf(M.list(self.spec)[1].item))
    self:drawRect(x, y, IL.BOX, IL.BOX, C.box[1], C.box[2], C.box[3], C.box[4])
    self:drawRectBorder(x, y, IL.BOX, IL.BOX, 0.9, 0.35, 0.6, 0.35)
    if icon then self:drawTextureScaledAspect(icon, x + 6, y + 6, IL.BOX - 12, IL.BOX - 12, loaded and 1 or 0.4, 1, 1, 1) end
    local fh = getTextManager():getFontHeight(UIFont.Small)
    local line1
    if #M.list(self.spec) == 0 then line1 = string.format("Internal: %d rounds", self.spec.maxAmmo or 0)
    else line1 = loaded and M.labelOf(loaded) or "No magazine" end
    self:text(line1, x + IL.BOX + 8, y + IL.BOX / 2 - fh)
    local v = self.ammoFt and ZGB.AmmoCatalog.variantOfItem(self.ammoFt)
    self:text("Load: " .. (v and v.label or "-"), x + IL.BOX + 8, y + IL.BOX / 2 + 1, { 0.70, 0.70, 0.70 })
end

function ZGB_GunsmithWindow:prerender()
    self:drawRect(0, 0, self.width, self.height, C.dim[1], C.dim[2], C.dim[3], C.dim[4])
end

function ZGB_GunsmithWindow:render()
    ISPanel.render(self)
    if not self.spec then return end
    self:drawTextCentre(self.spec.displayName, self.width / 2, 14, 1, 1, 1, 1, UIFont.Large)
    self:drawInfo()
    if not self.layout then
        self:drawTextCentre("No model for this gun", self.width / 2, self.height / 2, 1, 0.6, 0.6, 1, UIFont.Medium)
        return
    end
    local previewAtt = self:previewAttachments()
    self:drawGun(previewAtt or self.att, 1)
    if previewAtt then self:drawTextCentre("Preview", self.layout.gun.x + self.layout.gun.w / 2, self.layout.gun.y - 22, 1, 0.75, 0.3, 1, UIFont.Small) end
    for _, slot in ipairs(self.layout.slots) do
        local hover = self.mx and inside(self.mx, self.my, slot.box)
        self:drawSlot(slot, hover)
    end
    self:drawMagazine()
    self:drawStats(previewAtt)
    if self.picker then self:drawPicker() end
end

-- ------------------------------------------------------------ ctor
function ZGB_GunsmithWindow:new(x, y, w, h, player, weapon)
    local o = ISPanel.new(self, x, y, w, h)
    o.player, o.weapon = player, weapon
    o.background = false
    o.moveWithMouse = false
    o.anchorRight, o.anchorBottom = true, true
    return o
end
