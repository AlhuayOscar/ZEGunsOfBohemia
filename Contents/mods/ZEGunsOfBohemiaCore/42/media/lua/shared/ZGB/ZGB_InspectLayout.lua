--[[
    ZGB_InspectLayout.lua  —  where everything goes on the Gunsmith (inspect) screen.

    Pure: no game API, so the layout is tested offline. Given a gun, its
    attachments and the stage (the screen area left for the gun), returns:

      gun    { x, y, w, h, scale, ox, oy }      where the side view is drawn
      slots  { { slotId, label, lane, state, installed, via, anchor = {x,y},
                 box = {x,y,w,h} }, ... }

    Every slot sits next to the place its part goes, outside the gun, in one of
    four lanes: above (optics, mounts), in front (muzzle), behind (stock, butt)
    and below (grip, laser, light, bipod, sling). Boxes never overlap and stay
    inside the stage; the screen draws a line from each box to its anchor.
    Ghost slots (that need another part first) are included, marked "ghost".
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_Attachments"
require "ZGB/ZGB_Visuals"

ZGB.InspectLayout = ZGB.InspectLayout or {}
local L = ZGB.InspectLayout
local R, MF, V = ZGB.Attachments, ZGB.ModelFactory, ZGB.Visuals

L.BOX = 56            -- slot square (px)
L.LABEL_W = 132       -- label to its right
L.GAP = 26            -- gun edge -> lane
L.SPACING = 10        -- between boxes in a lane
L.MAX_ZOOM = 5.0      -- a pistol sprite is small: let it fill the middle like a rifle

-- gun point name -> lane
L.LANE_OF_POINT = {
    top = "top", side = "top",
    muzzle = "front",
    stock = "back", butt = "back", butt_side = "back",
    under = "bottom", handguard = "bottom", sling = "bottom", receiver_side = "bottom",
}

local function overlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end
L.overlap = overlap

--- Every slot the screen shows: live ones (open or occupied) and ghosts (need a part first).
function L.slotList(spec, att)
    local out, seen = {}, {}
    for _, row in ipairs(R.buildTree(spec, att or {})) do
        if row.kind == "slot" and not seen[row.slotId] then
            seen[row.slotId] = true
            out[#out + 1] = { slotId = row.slotId, label = row.label, state = row.state,
                              installed = row.installed, via = row.via }
        end
    end
    return out
end

--- Gun-model point of a slot (metres, forward / up): its own point, else the point of the slot
--- whose part provides it (an optic rail on an AK side mount sits where the mount is).
function L.slotPointOf(spec, att, slotId)
    local p = MF.slotPoint(spec, slotId)
    if p then return p, MF.SLOT_POINT[slotId] end
    local live = R.liveSlots(spec, att or {})
    local info = live[slotId]
    if info and info.parentSlot then
        local pp = MF.slotPoint(spec, info.parentSlot)
        if pp then return { pp[1], pp[2] + 0.03, pp[3] }, "top" end
    end
    local m = MF.gunModel(spec)
    if m then
        local b = MF.bounds(m.prims)
        return { (b.min[1] + b.max[1]) / 2, b.max[2], 0 }, "top"
    end
    return { 0, 0, 0 }, "top"
end

--- The whole screen layout. stage = { x, y, w, h }. nil if the gun has no model.
function L.compute(spec, att, stage)
    att = att or {}
    if not MF.gunModel(spec) then return nil end
    local pr = V.previewRects(spec, att)
    local b = pr.bounds
    local bw, bh = math.max(1, b[3] - b[1]), math.max(1, b[4] - b[2])
    -- the gun takes the middle of the stage, leaving room for the lanes around it
    local laneW = L.BOX + L.LABEL_W + L.GAP
    local s = math.min((stage.w - 2 * laneW) / bw, (stage.h - 2 * (L.BOX + L.GAP) - 40) / bh, L.MAX_ZOOM)
    s = math.max(s, 0.2)
    local gw, gh = bw * s, bh * s
    local gx = stage.x + (stage.w - gw) / 2
    local gy = stage.y + (stage.h - gh) / 2
    local gun = { x = gx, y = gy, w = gw, h = gh, scale = s, ox = gx - b[1] * s, oy = gy - b[2] * s }

    local lanes = { top = {}, bottom = {}, front = {}, back = {} }
    for _, slot in ipairs(L.slotList(spec, att)) do
        local p, pointName = L.slotPointOf(spec, att, slot.slotId)
        local px, py = pr.gunPx(p[1], p[2])
        slot.anchor = { x = gun.ox + px * s, y = gun.oy + py * s }
        slot.lane = L.LANE_OF_POINT[pointName or ""] or "top"
        table.insert(lanes[slot.lane], slot)
    end

    local slotW, slotH = L.BOX + L.LABEL_W, L.BOX
    local placed = {}
    -- horizontal lanes: sorted by anchor x, pushed right to make room, wrapped outwards
    local function horizontal(list, y0, dir)
        table.sort(list, function(a, c) return a.anchor.x < c.anchor.x end)
        local row, x = 0, -math.huge
        for _, slot in ipairs(list) do
            local want = math.max(slot.anchor.x - L.BOX / 2, x)
            if want + slotW > stage.x + stage.w then row, want = row + 1, slot.anchor.x - L.BOX / 2 end
            want = math.max(stage.x, math.min(want, stage.x + stage.w - slotW))
            slot.box = { x = want, y = y0 + dir * row * (slotH + L.SPACING), w = slotW, h = slotH }
            x = want + slotW + L.SPACING
            placed[#placed + 1] = slot
        end
    end
    -- vertical lanes: sorted by anchor y, pushed down to make room
    local function vertical(list, x0)
        table.sort(list, function(a, c) return a.anchor.y < c.anchor.y end)
        local total = #list * slotH + math.max(0, #list - 1) * L.SPACING
        local y = math.max(stage.y, math.min(gun.y + gh / 2 - total / 2, stage.y + stage.h - total))
        for _, slot in ipairs(list) do
            slot.box = { x = x0, y = y, w = slotW, h = slotH }
            y = y + slotH + L.SPACING
            placed[#placed + 1] = slot
        end
    end
    horizontal(lanes.top, gun.y - L.GAP - slotH, -1)
    horizontal(lanes.bottom, gun.y + gh + L.GAP, 1)
    vertical(lanes.front, math.min(gun.x + gw + L.GAP, stage.x + stage.w - slotW))
    vertical(lanes.back, math.max(gun.x - L.GAP - slotW, stage.x))

    -- last resort: anything still overlapping moves down until it is free
    for i = 2, #placed do
        local moved = true
        while moved do
            moved = false
            for j = 1, i - 1 do
                if overlap(placed[i].box, placed[j].box) then
                    placed[i].box.y = placed[j].box.y + slotH + L.SPACING
                    moved = true
                end
            end
        end
    end
    table.sort(placed, function(a, c) return a.slotId < c.slotId end)
    return { gun = gun, slots = placed, stage = stage }
end

return L
