--[[
    ZGB_Def_Sounds.lua  —  which sound every gun makes (pure data).

    Recorded gunshots from real guns (The Free Firearm Sound Library, CC0)
    are grouped into FAMILIES; a gun picks a family from its archetype and
    caliber (rules below), so a new gun gets a sensible sound without extra
    work. Mechanical sounds (magazine out/in, rack, pump, shell insert) come
    from zer0_sol's CC0 reload recordings.

    tools/gen_sounds.lua turns this table into media/sound/ZGB/*.ogg and the
    sound scripts (scripts/ZGB_sounds.txt); the weapon factory writes the names
    into each gun's spec.sounds, and ZGB_ScriptApply into the item scripts.

    Each family also gets a suppressed version (filtered and quieter); the
    item bridge swaps to it while a suppressor is fitted.
]]
require "ZGB/ZGB_Core"

ZGB.Sounds = ZGB.Sounds or {}
local SND = ZGB.Sounds

-- family -> source recording ("near distance" takes) and processing
--   src     file inside the library (pack "ffsl")
--   pitch   < 1 = deeper and heavier (magnums, .50 BMG)
--   len     seconds kept after the shot starts (the tail fades out)
SND.FAMILIES = {
    P9        = { src = "Walther PPQ/X_39P.wav",        label = "9mm pistol (Walther PPQ)", len = 1.4 },
    P45       = { src = "1911/A_42P.wav",               label = ".45 pistol (1911)", len = 1.5 },
    P22       = { src = "Ruger Mark III/R_35P.wav",     label = ".22 pistol (Ruger Mark III)", len = 1.0 },
    P380      = { src = "Bersa/F_47P.wav",              label = ".380 pistol (Bersa)", len = 1.2 },
    R38       = { src = "Smith & Wesson 642/V_27P.wav", label = ".38 revolver (S&W 642)", len = 1.5 },
    RMAG      = { src = "Smith & Wesson 642/V_27P.wav", label = "magnum revolver (S&W 642, deeper)", len = 1.9, pitch = 0.82 },
    SMG9      = { src = "Carl Gustav M45/G_31P.wav",    label = "submachine gun (Carl Gustav M45)", len = 1.2 },
    PPSH      = { src = "PPSh/P_30P.wav",               label = "PPSh-41", len = 1.2 },
    AR        = { src = "AR-15/D_32P.wav",              label = "5.56 rifle (AR-15)", len = 1.8 },
    AK        = { src = "AK-47/C_28P.wav",              label = "7.62x39 rifle (AK-47)", len = 1.8 },
    SKS       = { src = "SKS/U_14P.wav",                label = "semi-auto rifle (SKS)", len = 2.0 },
    BOLT      = { src = "Tikka/W_29P.wav",              label = "bolt rifle (Tikka T3)", len = 2.2 },
    BOLTHEAVY = { src = "Tikka/W_29P.wav",              label = "magnum / .50 rifle (Tikka, deeper)", len = 2.6, pitch = 0.78 },
    MOSIN     = { src = "Mosin Nagant/M_21P.wav",       label = "Mosin-Nagant", len = 2.2 },
    ARISAKA   = { src = "Arisaka/E_25P.wav",            label = "old military bolt rifle (Arisaka)", len = 2.2 },
    LEVER3030 = { src = "Marlin 336/I_22P.wav",         label = ".30-30 lever (Marlin 336)", len = 2.0 },
    LEVER32   = { src = "Model 1894/L_23P.wav",         label = "pistol-caliber lever (Winchester 1894)", len = 1.8 },
    SHOTGUN   = { src = "Nova/O_21P.wav",               label = "12 ga pump (Benelli Nova)", len = 2.0 },
    MODEL12   = { src = "Model 12/K_22P.wav",           label = "old pump shotgun (Winchester Model 12)", len = 2.0 },
}

-- mechanical sounds: name -> source (pack "zer0_sol") and which piece of it
SND.MECHANICS = {
    MagOut      = { src = "reload.wav", segment = 1 },
    MagIn       = { src = "reload.wav", segment = 2 },
    Rack        = { src = "reload.wav", segment = 3 },
    Pump        = { src = "x/ShotgunSounds/Rack.mp3" },
    ShellInsert = { src = "x/ShotgunSounds/Shell in Chamber.mp3" },
}

SND.SOURCES = {
    ffsl = { title = "The Free Firearm Sound Library (Prepared SFX Library)", author = "Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney",
             license = "CC0 1.0", url = "https://opengameart.org/content/the-free-firearm-sound-library",
             dir = ".cache/sound_sources/ffsl/x/Prepared SFX Library" },
    zer0_sol = { title = "Handgun Reload / Shotgun Reload Sound Effects", author = "zer0_sol", license = "CC0 1.0",
                 url = "https://opengameart.org/content/handgun-reload-sound-effect", dir = ".cache/sound_sources/zer0_sol" },
}

--- Sound family for a gun spec.
function SND.familyFor(spec)
    local a, c, id = spec.archetype, spec.caliber, spec.id
    if a == "pistol" then
        if c == "22lr" then return "P22" end
        if c == "380acp" then return "P380" end
        if c == "45acp" or c == "40sw" or c == "50ae" then return "P45" end
        return "P9"
    elseif a == "revolver" then
        if c == "38spl" or c == "762x38r" then return "R38" end
        return "RMAG"
    elseif a == "smg" then
        return (id == "PPSh41") and "PPSH" or "SMG9"
    elseif a == "assault_rifle" then
        return (c == "762x39") and "AK" or "AR"
    elseif a == "dmr" then
        return "SKS"
    elseif a == "bolt_rifle" then
        if c == "762x54r" then return "MOSIN" end
        if c == "792x57" or c == "303brit" then return "ARISAKA" end
        if c == "50bmg" or c == "338lm" then return "BOLTHEAVY" end
        return "BOLT"
    elseif a == "shotgun" then
        return (id == "Win1897") and "MODEL12" or "SHOTGUN"
    elseif a == "lever_rifle" then
        return (c == "3030" or c == "4570") and "LEVER3030" or "LEVER32"
    end
    return "AR"
end

function SND.fireName(family) return "ZGB_Fire_" .. family end
function SND.suppressedName(family) return "ZGB_FireSup_" .. family end
function SND.mechName(name) return "ZGB_" .. name end

--- spec.sounds for a gun (the weapon factory merges the definition's own sounds over this).
function SND.forSpec(spec)
    local fam = SND.familyFor(spec)
    local feedsMag = spec.internalCapacity == nil     -- called before the magazine list is built
    local pumpLike = spec.animType == "pump" or spec.animType == "lever"
    return {
        family = fam,
        fire = SND.fireName(fam),
        fireSuppressed = SND.suppressedName(fam),
        rack = SND.mechName(pumpLike and "Pump" or "Rack"),
        insertAmmo = SND.mechName(feedsMag and "MagIn" or "ShellInsert"),
        ejectAmmo = feedsMag and SND.mechName("MagOut") or nil,
    }
end

--- True when the attachments include a suppressor (fire sound swaps to the suppressed one).
function SND.isSuppressed(att)
    for _, ft in pairs(att or {}) do
        local p = ZGB.PartFactory and ZGB.PartFactory.get(ft)
        if p and (p.suppressor or string.find(p.id, "Suppressor", 1, true)) then return true end
    end
    return false
end

return SND
