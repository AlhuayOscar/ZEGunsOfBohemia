--[[
    ZGB_Def_IsoView.lua  —  the isometric APPLICATION of the animation factory.

    Maps every abstract clip of every anim type (Core Defs/ZGB_Def_Anims.lua)
    to a real animation. There are no custom models or clips yet, so each
    entry points at a VANILLA skeleton clip as a stand-in, tuned per type with
    playback speed. When the 3D side delivers clips, only the names below change.

    Holding stances are clip variants: "idle@novice", "aim@expert" ...
    (stances come from the tactical holding addon). `lowered` (0-1) is how far
    the muzzle sits below the line of sight, `sway` scales idle motion; both
    are written to the generated AnimSet drafts (tools/gen_animsets.lua).

    !! VERIFY every clip name against your build's media/anims (or AnimSets
    !! XML). They follow vanilla's "Bob_" naming but were not checked in game.
]]
require "ZGB/Factory/ZGB_AnimFactory"
require "ZGB/Defs/ZGB_Def_Anims"
require "ZGB/Factory/ZGB_RecoilFactory"

local AF = ZGB.AnimFactory

-- Vanilla stand-in clips, one family for handguns and one for long guns. VERIFY
local CLIP = {
    handgun = {
        idle = "Bob_IdleHandgun", idleLow = "Bob_IdleHandgunLowered", aim = "Bob_AimHandgun",
        fire = "Bob_ShootHandgun", reload = "Bob_ReloadHandgun", rack = "Bob_RackHandgun",
        draw = "Bob_EquipHandgun", holster = "Bob_UnequipHandgun", insert = "Bob_InsertBulletRevolver",
    },
    long = {
        idle = "Bob_IdleRifle", idleLow = "Bob_IdleRifleLowered", aim = "Bob_AimRifle",
        fire = "Bob_ShootRifle", reload = "Bob_ReloadRifle", rack = "Bob_RackRifle",
        draw = "Bob_EquipRifle", holster = "Bob_UnequipRifle", insert = "Bob_InsertBulletShotgun",
        pump = "Bob_RackShotgun", bolt = "Bob_RackBoltAction",
    },
}

-- Stance variants of idle / aim, shared by every type of a family.
-- novice: muzzle low, shaky, slow to raise; expert: high compressed ready, steady.
local STANCES = {
    novice     = { lowered = 0.8, sway = 1.6, aimSpeed = 0.80 },
    trained    = { lowered = 0.5, sway = 1.2, aimSpeed = 0.92 },
    proficient = { lowered = 0.3, sway = 1.0, aimSpeed = 1.00 },
    expert     = { lowered = 0.1, sway = 0.7, aimSpeed = 1.12 },
}

local function family(f, extra)
    local c = CLIP[f]
    local map = {
        idle = { anim = c.idle, speed = 1 }, aim = { anim = c.aim, speed = 1 },
        fire = { anim = c.fire, speed = 1 }, draw = { anim = c.draw, speed = 1 }, holster = { anim = c.holster, speed = 1 },
        magOut = { anim = c.reload, speed = 1.2 }, magDrop = { anim = c.reload, speed = 1.6 },
        magIn = { anim = c.reload, speed = 1 }, boltRelease = { anim = c.rack, speed = 1.4 },
        chargingHandle = { anim = c.rack, speed = 1 }, loadRound = { anim = c.insert, speed = 1 },
    }
    for stance, s in pairs(STANCES) do
        map["idle@" .. stance] = { anim = s.lowered >= 0.5 and c.idleLow or c.idle, speed = s.sway, lowered = s.lowered, sway = s.sway }
        map["aim@" .. stance]  = { anim = c.aim, speed = s.aimSpeed, lowered = 0, sway = s.sway }
    end
    for k, v in pairs(extra or {}) do map[k] = v end
    return map
end

local H, L = CLIP.handgun, CLIP.long

AF.defineView{
    id = "iso",
    types = {
        handgun = family("handgun"),
        revolver = family("handgun", {
            openCylinder = { anim = H.reload, speed = 1.3 }, ejectAll = { anim = H.reload, speed = 1.5 },
            closeCylinder = { anim = H.rack, speed = 1.3 },
        }),
        revolver_gate = {
            openGate = { anim = H.reload, speed = 1.4 }, ejectOne = { anim = H.insert, speed = 1.2 },
            closeGate = { anim = H.rack, speed = 1.4 },
        },
        rifle = family("long"),
        smg = { fire = { anim = L.fire, speed = 1.2 }, magIn = { anim = L.reload, speed = 1.15 } },
        bullpup = { magOut = { anim = L.reload, speed = 1.0 }, magIn = { anim = L.reload, speed = 0.9 } },
        bolt_mag = family("long", {
            cycle = { anim = L.bolt, speed = 1 }, openAction = { anim = L.bolt, speed = 1.6 }, closeAction = { anim = L.bolt, speed = 1.6 },
        }),
        bolt_internal = {},
        lever = family("long", { cycle = { anim = L.bolt, speed = 1.3 } }),
        pump = family("long", { cycle = { anim = L.pump, speed = 1 } }),
        semi_shotgun = {},
        break_action = family("long", {
            breakOpen = { anim = L.reload, speed = 1.4 }, extract = { anim = L.reload, speed = 1.6 },
            breakClose = { anim = L.rack, speed = 1.4 },
        }),
    },
    -- vanilla weapon-script params (SwingAnim decides the base upper-body set). VERIFY names
    scriptParams = {
        handgun  = { SwingAnim = "Handgun", IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
        revolver = { SwingAnim = "Handgun", IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
        default  = { SwingAnim = "Rifle",   IdleAnim = "Idle_Weapon2", RunAnim = "Run_Weapon2" },
    },
    -- extra AnimSet variables: how hard the fire animation kicks
    variables = function(spec)
        return { ZGB_Kick = ZGB.RecoilFactory.kickClass(spec) }
    end,
}

-- the iso stance table is useful to the holding addon's UI and to the AnimSet generator
ZGB.IsoStances = STANCES
