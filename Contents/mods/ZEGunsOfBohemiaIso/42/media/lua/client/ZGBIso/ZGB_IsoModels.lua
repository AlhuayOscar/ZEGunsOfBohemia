--[[
    ZGB_IsoModels.lua  —  the gun in your hands looks like its attachments.

    Whenever a ZGB gun is equipped or its attachments change, the gun's model
    is switched to the variant that has its BAKED parts (mounts, handguards,
    lasers, lights, shell holders, recoil pads...) built in. Parts vanilla can
    draw (optics, muzzle devices, grips, slings, some stocks) are attached by
    Core as visual twins and sit on the variant's attachment points.
    See ZGB_Visuals for which part goes where.

    Sandbox: ZGBIso.ModelVariants (on by default).
]]
require "ZGB/ZGB_Sandbox"
require "ZGB/ZGB_Visuals"
require "ZGB/ZGB_ItemBridge"

ZGB.IsoModels = ZGB.IsoModels or {}
local IM = ZGB.IsoModels
local I, V, SB = ZGB.Item, ZGB.Visuals, ZGB.Sandbox

--- Model script id the gun should use right now.
function IM.modelFor(item, spec)
    if not SB.get("ZGBIso", "ModelVariants", true) then return ZGB.MODULE .. "." .. spec.id end
    return ZGB.MODULE .. "." .. V.modelId(spec, I.getAttachments(item))
end

--- partsChanged: an attachment went on or off. Parts vanilla draws (suppressors, optics...)
--- sit on the same variant, so the hands are redrawn even when the model id is unchanged:
--- without that the suppressor never showed up in game.
function IM.apply(player, item, spec, partsChanged)
    if not item or not spec then return end
    local model = IM.modelFor(item, spec)
    local st = I.state(item)
    if st.model ~= model then
        if not I.setWeaponModel(item, model) then return end
        st.model = model
        ZGB.debug("Iso model ->", model)
    elseif not partsChanged then
        return
    end
    if player then I.refreshHandModels(player) end
end

return IM
