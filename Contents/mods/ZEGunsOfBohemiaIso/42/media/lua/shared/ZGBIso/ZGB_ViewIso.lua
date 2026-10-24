--[[
    ZGB_ViewIso.lua  —  the Isometric view provider (pure Lua, no Java).

    Owns the animation set for every archetype in iso view. Because animations
    are chosen HERE per archetype (not copied from whichever vanilla gun a
    script was based on), a pistol can never end up with rifle anims and the
    FP addon can later supply its own table without the two ever mixing.

    Anim names are vanilla ones. VERIFY against your build's vanilla gun scripts
    (media/scripts/... look at Pistol / AssaultRifle / Shotgun / HuntingRifle).
]]
require "ZGB/ZGB_Mode"

local Mode = ZGB.Mode

local ANIMS = {
    pistol        = { SwingAnim = "Handgun", IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    revolver      = { SwingAnim = "Handgun", IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    smg           = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    assault_rifle = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    dmr           = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    shotgun       = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    bolt_rifle    = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    lever_rifle   = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
}

local IsoProvider = {
    name = "iso",

    getAnimParams = function(archetypeId, spec)
        local set = ANIMS[archetypeId]
        if not set then
            ZGB.warn("Iso: no anim set for archetype", archetypeId, "- using rifle")
            set = ANIMS.assault_rifle
        end
        -- per-weapon override hook: spec.anim = { iso = { SwingAnim = "..." } }
        if spec and spec.anim and spec.anim.iso then
            local merged = {}
            for k, v in pairs(set) do merged[k] = v end
            for k, v in pairs(spec.anim.iso) do merged[k] = v end
            return merged
        end
        return set
    end,
}

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
