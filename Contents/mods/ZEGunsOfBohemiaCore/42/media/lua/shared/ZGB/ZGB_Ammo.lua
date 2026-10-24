--[[
    ZGB_Ammo.lua  —  "Load all magazines" planning (pure logic, unit-tested).

    A magazine holds ONE ammo variant at a time (vanilla stores a count, not a
    list of rounds), so the rules are:
      * an empty magazine can take any variant of its caliber
      * a partly-filled magazine is only topped off with the SAME variant
      * magazines holding another variant are skipped (unload them first)

    The menu then follows directly from the plan:
      one variant you carry that would load something  -> one "Load all" option
      several                                           -> a choice per variant
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_AmmoCatalog"
require "ZGB/Factory/ZGB_WeaponFactory"

ZGB.Ammo = ZGB.Ammo or {}
local A = ZGB.Ammo

-- ------------------------------------------------------------ magazine index
-- magazine item -> { caliber, capacity, label, tier }: every magazine some registered
-- gun takes. Caliber and capacity come from the magazine itself (ZGB_MagazineFactory).
local magIndex
function A.magazineInfo(magFullType)
    if not magIndex then
        magIndex = {}
        for _, spec in ipairs(ZGB.WeaponFactory.all()) do
            for _, m in ipairs(spec.magazines or {}) do
                magIndex[m.item] = { caliber = m.caliber, capacity = m.capacity, label = m.label, tier = m.tier }
            end
        end
    end
    return magIndex[magFullType]
end

--- All magazine item types of a caliber.
function A.magazinesOfCaliber(caliberId)
    A.magazineInfo("")   -- build index
    local out = {}
    for ft, info in pairs(magIndex) do
        if info.caliber == caliberId then out[#out + 1] = ft end
    end
    table.sort(out)
    return out
end

function A.invalidate() magIndex = nil end

--- Caliber of anything we know: our gun, one of its magazines, or an ammo item.
function A.caliberOf(fullType)
    local spec = ZGB.WeaponFactory.get(fullType)
    if spec then return spec.caliber end
    local m = A.magazineInfo(fullType)
    if m then return m.caliber end
    local v = ZGB.AmmoCatalog.variantOfItem(fullType)
    return v and v.caliber or nil
end

-- ------------------------------------------------------------ planning
--[[ mags:   list of { ref=<item>, capacity=n, ammo=n, variant=<ammo item ft or nil> }
     ammoFt: the variant to load;  available: rounds of it the player has
     returns { loads = { {ref, count, mag}... }, total = n, skipped = n } ]]
function A.planLoadAll(mags, ammoFt, available)
    local partial, empty, skipped = {}, {}, 0
    for _, m in ipairs(mags or {}) do
        local missing = (m.capacity or 0) - (m.ammo or 0)
        if missing > 0 then
            if (m.ammo or 0) == 0 then
                empty[#empty + 1] = m
            elseif m.variant == ammoFt then
                partial[#partial + 1] = m
            else
                skipped = skipped + 1
            end
        end
    end
    -- top off partly-filled mags first (fewest missing first), then fill empties
    -- smallest first so more magazines end up usable.
    table.sort(partial, function(a, b) return (a.capacity - a.ammo) < (b.capacity - b.ammo) end)
    table.sort(empty, function(a, b) return a.capacity < b.capacity end)

    local plan, left = { loads = {}, total = 0, skipped = skipped }, available or 0
    local function take(list)
        for _, m in ipairs(list) do
            if left <= 0 then return end
            local n = math.min(m.capacity - m.ammo, left)
            plan.loads[#plan.loads + 1] = { ref = m.ref, count = n, mag = m }
            plan.total, left = plan.total + n, left - n
        end
    end
    take(partial)
    take(empty)
    return plan
end

--[[ One menu entry per variant that would actually load something.
     counts: map ammo item ft -> rounds carried
     returns list (catalog order) of { variant=<resolved variant>, have=n, plan=<plan> } ]]
function A.loadOptions(caliberId, mags, counts)
    local out = {}
    for _, v in ipairs(ZGB.AmmoCatalog.variantsFor(caliberId) or {}) do
        local have = counts[v.item] or 0
        if have > 0 then
            local plan = A.planLoadAll(mags, v.item, have)
            if plan.total > 0 then out[#out + 1] = { variant = v, have = have, plan = plan } end
        end
    end
    return out
end

--- Variants of a caliber the player carries (for the tube-fed ammo selector).
function A.carriedVariants(caliberId, counts)
    local out = {}
    for _, v in ipairs(ZGB.AmmoCatalog.variantsFor(caliberId) or {}) do
        if (counts[v.item] or 0) > 0 then out[#out + 1] = { variant = v, have = counts[v.item] } end
    end
    return out
end

return A
