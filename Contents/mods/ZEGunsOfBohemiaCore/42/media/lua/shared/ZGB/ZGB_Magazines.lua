--[[
    ZGB_Magazines.lua  —  which magazines a gun takes, and which one to load.
    Pure logic (no game API) so it is unit-tested.

    Vanilla only understands ONE MagazineType per gun. We keep the full list in
    the spec and, right before a magazine goes in, point the gun's MagazineType
    and MaxAmmo at that magazine (see ZGB_ItemBridge.setLoadedMagazine).
    Ejecting then naturally hands back the right magazine item.
]]
require "ZGB/ZGB_Core"

ZGB.Magazines = ZGB.Magazines or {}
local M = ZGB.Magazines

function M.list(spec) return spec.magazines or {} end

function M.get(spec, magFullType)
    for _, m in ipairs(M.list(spec)) do
        if m.item == magFullType then return m end
    end
    return nil
end

function M.accepts(spec, magFullType) return M.get(spec, magFullType) ~= nil end

--- Capacity the gun should report with this magazine (or default/internal).
function M.capacityFor(spec, magFullType)
    local m = magFullType and M.get(spec, magFullType)
    if m then return m.capacity end
    return spec.maxAmmo
end

function M.labelOf(m)
    return m.label or (m.capacity .. "rd" .. (m.default and "" or " mag"))
end

--[[ Pick the best magazine to load for an automatic reload.
     candidates = list of { fullType = "...", ammo = <rounds in it>, ref = <item> }
     Preference: most rounds loaded; tie -> the type currently in use; tie -> default mag.
     Empty magazines are never picked (vanilla would load an empty mag). ]]
function M.chooseBest(spec, candidates, currentType)
    local best, bestScore
    for _, c in ipairs(candidates or {}) do
        local m = M.get(spec, c.fullType)
        if m and (c.ammo or 0) > 0 then
            local score = (c.ammo or 0) * 1000
                        + ((c.fullType == currentType) and 10 or 0)
                        + (m.default and 1 or 0)
            if not bestScore or score > bestScore then best, bestScore = c, score end
        end
    end
    return best
end

return M
