--[[
    ZGB_Attachments.lua  —  attachment rules engine (pure logic, no game API).

    State of one gun = a map  slotId -> part fullType
        { side_mount = "ZGB.Mount_AK_SideRail", optic_rail = "ZGB.Optic_RedDot" }

    Slots come from two places:
        1. the weapon spec (`spec.slots`)          -> always there
        2. `provides` of every INSTALLED part      -> appear when the part is on

    Main questions this answers (the UI is just a view of these):
        canAttach(spec, att, part)  -> true, slotId
                                     | false, "needs",     { chains = {{"ZGB.Mount_AK_SideRail"}} }
                                     | false, "occupied",  { slotId=..., by=... }
                                     | false, "incompatible" / "already_installed" / "unknown_part"
        canDetach(spec, att, slotId)-> true | false, "has_children", { children = {...} }
        buildTree(spec, att)        -> rows for the attachment UI, including "ghost"
                                       slots that only exist once a mount is fitted
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_PartFactory"

ZGB.Attachments = ZGB.Attachments or {}
local R  = ZGB.Attachments
local PF = ZGB.PartFactory

R.MAX_CHAIN_DEPTH = 3     -- mount -> adapter -> optic is the deepest real-world chain
R.MAX_CHAINS      = 6     -- how many alternative "you need X" options to report

function R.accepts(slotDef, part)
    return slotDef ~= nil and part ~= nil
        and slotDef.kind == part.kind
        and ZGB.contains(slotDef.accepts, part.interface)
end

--- All slots that exist right now. Returns map slotId -> { def=, providedBy=fullType|nil }
function R.liveSlots(spec, att)
    att = att or {}
    local live = {}
    for slotId, def in pairs(spec.slots or {}) do live[slotId] = { def = def } end

    -- Provided slots can chain (mount -> adapter rail -> optic), so expand until stable.
    local changed = true
    while changed do
        changed = false
        for slotId, partFt in pairs(att) do
            local part = PF.get(partFt)
            if live[slotId] and part then
                for pSlotId, pDef in pairs(part.provides) do
                    if not live[pSlotId] then
                        live[pSlotId] = { def = pDef, providedBy = partFt, parentSlot = slotId }
                        changed = true
                    end
                end
            end
        end
    end
    return live
end

--- Every slot this gun could EVER have with the registered parts (fixed point).
function R.reachableSlots(spec)
    local reach = {}
    for slotId, def in pairs(spec.slots or {}) do reach[slotId] = def end
    local changed = true
    while changed do
        changed = false
        for _, part in ipairs(PF.all()) do
            for _, def in pairs(reach) do
                if R.accepts(def, part) then
                    for pSlotId, pDef in pairs(part.provides) do
                        if not reach[pSlotId] then reach[pSlotId] = pDef; changed = true end
                    end
                    break
                end
            end
        end
    end
    return reach
end

function R.isCompatible(spec, partIdOrFt)
    local part = PF.get(partIdOrFt)
    if not part then return false end
    for _, def in pairs(R.reachableSlots(spec)) do
        if R.accepts(def, part) then return true end
    end
    return false
end

function R.compatibleParts(spec)
    local out, reach = {}, R.reachableSlots(spec)
    for _, part in ipairs(PF.all()) do
        for _, def in pairs(reach) do
            if R.accepts(def, part) then out[#out + 1] = part; break end
        end
    end
    return out
end

local function installedSet(att)
    local s = {}
    for _, ft in pairs(att or {}) do s[ft] = true end
    return s
end

--- Find chains of parts that, installed in order, would create a slot for `part`.
--- Example result: { {"ZGB.Mount_AK_SideRail"} }  or  { {"ZGB.Handguard_AK_Quad"} }
function R.requirementChains(spec, att, part, depth, visited)
    depth   = depth or R.MAX_CHAIN_DEPTH
    visited = visited or {}
    if depth <= 0 then return {} end
    local chains, installed = {}, installedSet(att)
    local live = R.liveSlots(spec, att)

    for _, provider in ipairs(PF.all()) do
        if not installed[provider.fullType] and not visited[provider.fullType] then
            local createsSlot = false
            for _, pDef in pairs(provider.provides) do
                if R.accepts(pDef, part) then createsSlot = true; break end
            end
            if createsSlot then
                -- Can the provider itself go on right now?
                local direct = false
                for slotId, l in pairs(live) do
                    if R.accepts(l.def, provider) and not att[slotId] then direct = true; break end
                end
                if direct then
                    chains[#chains + 1] = { provider.fullType }
                else
                    visited[provider.fullType] = true
                    for _, sub in ipairs(R.requirementChains(spec, att, provider, depth - 1, visited)) do
                        sub[#sub + 1] = provider.fullType
                        chains[#chains + 1] = sub
                    end
                    visited[provider.fullType] = nil
                end
                if #chains >= R.MAX_CHAINS then break end
            end
        end
    end
    return chains
end

function R.canAttach(spec, att, partIdOrFt)
    att = att or {}
    local part = PF.get(partIdOrFt)
    if not part then return false, "unknown_part", {} end
    if installedSet(att)[part.fullType] then return false, "already_installed", {} end

    local live = R.liveSlots(spec, att)
    local occupied
    for _, slotId in ipairs(ZGB.sortedKeys(live)) do
        if R.accepts(live[slotId].def, part) then
            if not att[slotId] then return true, slotId end
            occupied = occupied or { slotId = slotId, by = att[slotId] }
        end
    end
    if occupied then return false, "occupied", occupied end

    local chains = R.requirementChains(spec, att, part)
    if #chains > 0 then return false, "needs", { chains = chains } end
    return false, "incompatible", {}
end

--- Slots (with parts in them) that exist only because of the part in `slotId`.
function R.dependents(spec, att, slotId)
    local live, out = R.liveSlots(spec, att), {}
    local function walk(parentSlot)
        for sId, l in pairs(live) do
            if l.parentSlot == parentSlot and att[sId] then
                out[#out + 1] = { slotId = sId, part = att[sId] }
                walk(sId)
            end
        end
    end
    walk(slotId)
    return out
end

function R.canDetach(spec, att, slotId)
    att = att or {}
    if not att[slotId] then return false, "empty", {} end
    local deps = R.dependents(spec, att, slotId)
    if #deps > 0 then return false, "has_children", { children = deps } end
    return true
end

--- Pure state transitions (return NEW maps; callers persist them).
function R.attach(spec, att, partIdOrFt)
    local ok, slotOrReason, info = R.canAttach(spec, att, partIdOrFt)
    if not ok then return nil, slotOrReason, info end
    local nextAtt = ZGB.copy(att or {})
    nextAtt[slotOrReason] = PF.get(partIdOrFt).fullType
    return nextAtt, slotOrReason
end

function R.detach(spec, att, slotId)
    local ok, reason, info = R.canDetach(spec, att, slotId)
    if not ok then return nil, reason, info end
    local nextAtt = ZGB.copy(att)
    local removed = nextAtt[slotId]
    nextAtt[slotId] = nil
    return nextAtt, removed
end

--- Repair saved state after a spec change (mod update): drops parts whose slot
--- no longer exists or no longer accepts them. Returns cleanAtt, removedList.
function R.sanitize(spec, att)
    local clean, removed = {}, {}
    for slotId, ft in pairs(att or {}) do clean[slotId] = ft end
    local changed = true
    while changed do
        changed = false
        local live = R.liveSlots(spec, clean)
        for slotId, ft in pairs(clean) do
            local part = PF.get(ft)
            if not part or not live[slotId] or not R.accepts(live[slotId].def, part) then
                removed[#removed + 1] = ft
                clean[slotId] = nil
                changed = true
            end
        end
    end
    return clean, removed
end

--[[ UI tree. Each row:
     { kind="slot", slotId, label, depth, state="open"|"occupied"|"ghost", installed=ft|nil, via=ft|nil }
     { kind="part", part=ft, slotId, depth, installed=bool }
   Ghost slots are shown under a candidate mount that is NOT installed yet, so the
   player can see "Red Dot -> needs AK Side Rail Mount" before owning anything. ]]
local function slotOrder(defs)
    return function(a, b)
        local oa, ob = defs[a].order or 99, defs[b].order or 99
        if oa ~= ob then return oa < ob end
        return a < b
    end
end

function R.buildTree(spec, att, maxDepth)
    att, maxDepth = att or {}, maxDepth or 8
    local rows, live = {}, R.liveSlots(spec, att)
    local parts = PF.all()

    local function emitSlot(slotId, def, depth, ghostVia)
        if depth > maxDepth then return end
        local installed = (not ghostVia) and att[slotId] or nil
        local state = ghostVia and "ghost" or (installed and "occupied" or "open")
        rows[#rows + 1] = { kind = "slot", slotId = slotId, label = def.label or slotId,
                            depth = depth, state = state, installed = installed, via = ghostVia }
        for _, part in ipairs(parts) do
            if R.accepts(def, part) then
                local isOn = (installed == part.fullType)
                rows[#rows + 1] = { kind = "part", part = part.fullType, slotId = slotId,
                                    depth = depth + 1, installed = isOn, ghost = ghostVia ~= nil }
                local childDefs = part.provides
                for _, cId in ipairs(ZGB.sortedKeys(childDefs, slotOrder(childDefs))) do
                    if isOn and live[cId] then
                        emitSlot(cId, childDefs[cId], depth + 2, nil)
                    else
                        emitSlot(cId, childDefs[cId], depth + 2, ghostVia or part.fullType)
                    end
                end
            end
        end
    end

    local base = spec.slots or {}
    for _, slotId in ipairs(ZGB.sortedKeys(base, slotOrder(base))) do
        emitSlot(slotId, base[slotId], 0, nil)
    end
    return rows
end

return R
