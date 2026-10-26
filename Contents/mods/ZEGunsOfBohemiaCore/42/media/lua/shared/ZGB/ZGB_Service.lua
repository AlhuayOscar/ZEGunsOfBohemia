--[[
    ZGB_Service.lua  —  the actions that mutate a real gun.
    Called from the timed actions (ZGB_PartActions) — not directly from the UI —
    so attaching always costs time and goes through the same validation.
]]
require "ZGB/ZGB_Core"
require "ZGB/ZGB_Mode"
require "ZGB/ZGB_ItemBridge"

ZGB.Service = ZGB.Service or {}
local Svc = ZGB.Service
local I   = ZGB.Item

local function giveBack(character, fullTypes)
    local inv = character:getInventory()
    for _, ft in ipairs(fullTypes or {}) do
        inv:AddItem(ft)                                    -- VERIFY MP: sendAddItemToContainer
    end
end

function Svc.attach(character, weapon, partItem)
    local spec = ZGB.WeaponFactory.specOf(weapon)
    local partSpec = partItem and ZGB.PartFactory.get(partItem:getFullType())
    if not spec or not partSpec then return false, "unknown" end

    local nextAtt, slotOrReason = ZGB.Attachments.attach(spec, I.getAttachments(weapon), partSpec.fullType)
    if not nextAtt then return false, slotOrReason end

    character:getInventory():Remove(partItem)               -- VERIFY MP: sendRemoveItemFromContainer
    I.setAttachments(weapon, nextAtt)
    I.mirrorVanillaAttach(character, weapon, partSpec)
    I.applyStats(weapon)
    ZGB.Mode.notify("onAttachmentsChanged", character, weapon, spec)
    return true, slotOrReason
end

function Svc.detach(character, weapon, slotId)
    local spec = ZGB.WeaponFactory.specOf(weapon)
    if not spec then return false, "unknown" end

    local nextAtt, removedOrReason = ZGB.Attachments.detach(spec, I.getAttachments(weapon), slotId)
    if not nextAtt then return false, removedOrReason end

    I.setAttachments(weapon, nextAtt)
    I.mirrorVanillaDetach(character, weapon, ZGB.PartFactory.get(removedOrReason))
    giveBack(character, { removedOrReason })
    I.applyStats(weapon)
    ZGB.Mode.notify("onAttachmentsChanged", character, weapon, spec)
    return true, removedOrReason
end

--- Re-apply stats + refund parts dropped by a spec change. Called on equip.
function Svc.refresh(character, weapon)
    if not ZGB.WeaponFactory.isOurs(weapon) then return end
    local st = I.state(weapon)
    if st.needsMirror and character then
        -- parts it spawned with (its stock): the game draws them once they are attached
        for _, ft in pairs(I.getAttachments(weapon)) do
            local p = ZGB.PartFactory.get(ft)
            if p then I.mirrorVanillaAttach(character, weapon, p) end
        end
        st.needsMirror = nil
        ZGB.Mode.notify("onAttachmentsChanged", character, weapon, ZGB.WeaponFactory.specOf(weapon))
    end
    I.applyStats(weapon)
    if st.pendingRefund and character then
        giveBack(character, st.pendingRefund)
        st.pendingRefund = nil
    end
end

return Svc
