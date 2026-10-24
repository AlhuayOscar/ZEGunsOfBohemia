--[[
    ZGB_ViewIso.lua  —  the Isometric view provider (pure Lua, no Java).

    The animation set of every gun comes from the animation factory applied to
    view "iso" (ZGB_Def_IsoView.lua): anim type -> clips + script params.
    Because animations are chosen per anim type (not copied from whichever
    vanilla gun a script was based on), a pistol can never end up with rifle
    anims, and the FP addon later supplies view "fp" without the two mixing.
]]
require "ZGB/ZGB_Mode"
require "ZGB/ZGB_Addons"
require "ZGBIso/ZGB_Def_IsoView"

local Mode, AF = ZGB.Mode, ZGB.AnimFactory

local IsoProvider = {
    name = "iso",

    getAnimParams = function(archetypeId, spec)
        local built = spec and AF.build("iso", spec)
        if not built then
            ZGB.warn("Iso: no anim data for", spec and spec.id or archetypeId, "- using rifle params")
            return { SwingAnim = "Rifle", IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" }
        end
        return built.scriptParams
    end,

    --- Full build for one gun in one stance (clips + AnimSet variables).
    build = function(spec, stance) return AF.build("iso", spec, stance) end,

    -- Core calls these; the client side (ZGB_IsoModels) swaps the gun to the
    -- model variant that matches its attachments.
    onWeaponEquipped = function(player, item, spec)
        if ZGB.IsoModels then ZGB.IsoModels.apply(player, item, spec) end
    end,
    onAttachmentsChanged = function(player, item, spec)
        if ZGB.IsoModels then ZGB.IsoModels.apply(player, item, spec) end
    end,
}

ZGB.Addons.register{ id = "iso", name = "ZE Guns Of Bohemia - Isometric", modId = "ZEGunsOfBohemiaIso", version = "0.6.0" }

-- Hard stop: never register alongside a first-person / Java animation mod.
local fp = Mode.activeFpMods()
if #fp > 0 then
    local msg = "ZE Guns Of Bohemia - Isometric disabled itself: first-person mod(s) active: " ..
                table.concat(fp, ", ") .. ". Use the First Person addon instead."
    Mode.conflicts[#Mode.conflicts + 1] = msg
    ZGB.err(msg)
else
    Mode.registerProvider(IsoProvider)
end

return IsoProvider
