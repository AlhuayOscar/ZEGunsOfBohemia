--[[
    ZGB_Reload.lua  —  the reloading system's rules (pure logic, unit-tested).

    Essential addon. Core owns the magazines and ammo; this addon decides HOW a
    gun is reloaded and tells everyone else through events:

      kind        tactical  rounds still in the gun: swap the mag, keep the chambered round
                  empty     gun ran dry: drop the mag, insert, release the slide / bolt
                  single / cylinder / gate / break  (guns without magazines, from the anim type)
      chamber     closed-bolt guns hold one extra round in the chamber after a
                  tactical reload (+1). Open-bolt guns (Uzi, MAC-10, Thompson,
                  PPSh-41, AA-12), revolvers and break-actions don't.
      steps       the anim type's reload sequence (Core ZGB_Def_Anims), so the
                  views animate it and the calls addon can shout over it
      duration    clip timings x magazine tier x Reloading skill x sandbox speed

    The vanilla timed action's own length is scaled by actionFactor() (tier,
    reload kind and sandbox speed); vanilla already applies the Reloading
    skill to it, so skill is NOT applied twice there.
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_AnimFactory"
require "ZGB/Factory/ZGB_MagazineFactory"

ZGB.Reload = ZGB.Reload or {}
local R = ZGB.Reload
local AF = ZGB.AnimFactory

R.TIER_FACTOR = { standard = 1.0, extended = 1.1, drum = 1.35 }
R.KIND_FACTOR = { tactical = 1.0, empty = 1.15 }
R.SKILL_STEP  = 0.045            -- each Reloading level shaves 4.5% (level 10 = 55% of the time)
R.CHAMBERED_FEEDS = { magazine = true, tube = true, internal = true }

function R.feedOf(spec)
    local t = AF.getType(spec.animType)
    return t and t.feed or (#(spec.magazines or {}) > 0 and "magazine" or "internal")
end

--- True when the gun keeps a round in the chamber (+1 after a tactical reload).
function R.hasChamber(spec)
    if spec.openBolt then return false end
    return R.CHAMBERED_FEEDS[R.feedOf(spec)] == true
end

--- Rounds the gun holds with this magazine, counting the chamber.
function R.capacity(spec, magCapacity)
    local base = magCapacity or spec.maxAmmo or 0
    return base + (R.hasChamber(spec) and 1 or 0)
end

--- Reload kind for the gun's current state. state = { rounds = n in the gun }
function R.kindFor(spec, state)
    if #(spec.magazines or {}) == 0 then
        local t = AF.getType(spec.animType)
        return (t and t.internalReload) or "single"
    end
    return ((state and state.rounds) or 0) > 0 and "tactical" or "empty"
end

function R.skillFactor(level)
    level = math.max(0, math.min(10, level or 0))
    return 1 - R.SKILL_STEP * level
end

--[[ Full plan for one reload.
     state: { rounds = in the gun now, magTier = tier of the magazine going in }
     opts:  { skill = Reloading level, speed = sandbox percent (100 = normal) }
     returns { kind, steps = { {clip, duration, at} }, duration, rounds, spent, chamberPlusOne } ]]
function R.plan(spec, state, opts)
    state, opts = state or {}, opts or {}
    local kind = R.kindFor(spec, state)
    local inGun = state.rounds or 0
    local internal = #(spec.magazines or {}) == 0
    local toLoad = internal and math.max(0, (spec.internalCapacity or 0) - inGun) or 0
    -- revolvers / break actions eject every chamber, so they reload them all
    if kind == "cylinder" or kind == "break" then toLoad = spec.internalCapacity or 0 end
    if kind == "gate" then toLoad = math.max(0, (spec.internalCapacity or 0) - inGun) end
    local spent = (kind == "cylinder" or kind == "break") and math.max(0, (spec.internalCapacity or 0) - inGun) or 0
    local seq = AF.sequence(spec.animType, kind, toLoad, inGun == 0) or {}

    local factor = R.skillFactor(opts.skill) * (R.TIER_FACTOR[state.magTier or "standard"] or 1)
                 * (100 / math.max(10, opts.speed or 100))
    local at, steps = 0, {}
    for i, s in ipairs(seq) do
        local d = s.duration * factor
        steps[i] = { clip = s.clip, duration = d, at = at }
        at = at + d
    end
    return {
        kind = kind, steps = steps, duration = at, rounds = toLoad, spent = spent,
        chamberPlusOne = (kind == "tactical") and R.hasChamber(spec),
    }
end

--- Multiplier for the vanilla timed action (skill excluded: vanilla applies it).
function R.actionFactor(kind, magTier, speedPercent)
    return (R.KIND_FACTOR[kind] or 1) * (R.TIER_FACTOR[magTier or "standard"] or 1)
         * (100 / math.max(10, speedPercent or 100))
end

--- Steps whose start time has passed since the last check (for reload.step events).
function R.dueSteps(plan, elapsed, fromIndex)
    local out, i = {}, fromIndex or 1
    while plan.steps[i] and plan.steps[i].at <= elapsed do
        out[#out + 1] = { index = i, step = plan.steps[i] }
        i = i + 1
    end
    return out, i
end

return R
