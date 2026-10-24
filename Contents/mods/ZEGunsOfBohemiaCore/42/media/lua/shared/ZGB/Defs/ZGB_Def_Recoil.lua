--[[
    ZGB_Def_Recoil.lua  —  spray-pattern profiles.

    Guns pick one with `recoil = { pattern = "climb_right" }` (archetypes set
    a default). Magnitude comes from the gun, the profile only sets the shape.
]]
require "ZGB/Factory/ZGB_RecoilFactory"
local RF = ZGB.RecoilFactory

RF.defineProfile{ id = "vertical",    label = "Straight climb",            ramp = 7, plateau = 0.30, noise = 0.15 }
RF.defineProfile{ id = "climb_right", label = "Climb, then drift right",   ramp = 6, plateau = 0.35, drift = 0.55, noise = 0.20 }
RF.defineProfile{ id = "climb_left",  label = "Climb, then drift left",    ramp = 6, plateau = 0.35, drift = -0.55, noise = 0.20 }
RF.defineProfile{ id = "s_curve",     label = "Climb with an S sway",      ramp = 8, plateau = 0.30, sway = 0.9, swayPeriod = 12, noise = 0.15 }
RF.defineProfile{ id = "erratic",     label = "Erratic (light, fast guns)", ramp = 4, plateau = 0.50, noise = 0.90 }
RF.defineProfile{ id = "low",         label = "Low and flat (recoil-mitigated)", ramp = 3, plateau = 0.15, noise = 0.12 }
RF.defineProfile{ id = "kick",        label = "Single heavy kick (follow-up shots re-aim)", ramp = 1, plateau = 1.0, noise = 0.30 }
