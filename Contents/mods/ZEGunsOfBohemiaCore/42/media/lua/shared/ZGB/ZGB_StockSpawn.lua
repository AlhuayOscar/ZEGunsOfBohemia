--[[
    ZGB_StockSpawn.lua  —  which stock a gun comes with when it spawns.

    Guns whose stock comes off are built without it (ModelFactory.removableStock); a found
    gun gets one at random: most often the stock it shipped with (its factory stock), now and
    then another stock that fits it, sometimes none at all. Pure: the game's random number
    comes in as `rnd(n)` (0 .. n-1, ZombRand), so it is tested offline.
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_PartFactory"

ZGB.StockSpawn = ZGB.StockSpawn or {}
local SS = ZGB.StockSpawn

-- relative weights (integers: ZombRand is integer)
SS.WEIGHT = { factory = 6, other = 1, none = 3 }

--- The gun's stock slot id and the interfaces it accepts, or nil.
function SS.slotOf(spec)
    for id, s in pairs(spec.slots or {}) do
        if s.kind == "stock" then return id, s end
    end
    return nil
end

--- { { part = <part spec or false>, weight = n }, ... } in a stable order.
function SS.choices(spec)
    local slotId, slot = SS.slotOf(spec)
    if not slotId then return {} end
    local accepts = {}
    for _, i in ipairs(slot.accepts or {}) do accepts[i] = true end
    local out = {}
    for _, p in ipairs(ZGB.PartFactory.all()) do
        if p.kind == "stock" and accepts[p.interface] then
            out[#out + 1] = { part = p, weight = (p.factoryOf == spec.id) and SS.WEIGHT.factory or SS.WEIGHT.other }
        end
    end
    table.sort(out, function(a, b) return a.part.id < b.part.id end)
    out[#out + 1] = { part = false, weight = SS.WEIGHT.none }
    return out
end

--- Pick a stock: returns slotId, part fullType (or slotId, nil for no stock); nil if the gun
--- has no stock slot or no random source.
function SS.pick(spec, rnd)
    local slotId = SS.slotOf(spec)
    if not slotId or type(rnd) ~= "function" then return nil end
    local list, total = SS.choices(spec), 0
    for _, c in ipairs(list) do total = total + c.weight end
    local r = rnd(total)
    for _, c in ipairs(list) do
        if r < c.weight then return slotId, c.part and c.part.fullType or nil end
        r = r - c.weight
    end
    return slotId, nil
end

return SS
