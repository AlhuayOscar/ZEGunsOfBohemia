--[[
    ZGB_RecoilFactory.lua  —  spray patterns and recoil, per gun.

    A recoil PROFILE describes the shape of a spray (straight climb, climb
    then drift right, S-curve, erratic ...). A gun picks a profile
    (`spec.recoil.pattern`, archetype default) and the factory builds its
    pattern from the profile + the gun's own numbers:

      magnitude  spec.recoil.fp.vertical / horizontal (archetype, per-gun override)
                 x caliber energy vs the archetype's reference caliber
      length     the largest magazine the gun takes (internal capacity otherwise)

    The pattern is deterministic (seeded from the gun id), so the same gun
    always sprays the same way and players can learn it.

    Two applications, because the cameras are different (see docs/FIRST_PERSON.md):
      ISO  can't move a camera. Recoil shows as a kick animation (light /
           medium / heavy) and a hit-chance penalty that grows during a
           burst and recovers between bursts:  RF.iso(spec, shot, scale)
      FP   (Java addon, future) moves the camera by the pattern itself:
           RF.patternFor(spec).shots[n] = cumulative { x, y } offset in degrees.
           Recovery pulls the view back by `recovery` per second.

    Attachments change recoil through stats: scale = current recoilDelay /
    base recoilDelay, so a compensator or grip shrinks the whole pattern.

    ------------------------------------------------------------------ profile schema
    {
      id      = "climb_right",
      label   = "Climb, then drift right",
      ramp    = 6,        -- shots until the vertical climb levels off
      plateau = 0.35,     -- vertical kick per shot after the ramp, as a share of the first shots
      drift   = 0.6,      -- steady horizontal pull per shot (+ right, - left), x horizontal
      sway    = 0,        -- side-to-side amplitude (S-curve), x horizontal
      swayPeriod = 10,    -- shots per full S
      noise   = 0.15,     -- random jitter, x horizontal
    }
]]
require "ZGB/ZGB_Core"
require "ZGB/Factory/ZGB_WeaponFactory"

ZGB.RecoilFactory = ZGB.RecoilFactory or { _profiles = {}, _cache = {} }
local RF = ZGB.RecoilFactory

RF.MAX_SHOTS = 100
RF.BURST_GAP = 0.6          -- seconds without firing before the next shot counts as a new burst
RF.ISO_PENALTY_PER_DEG = 4  -- hit chance lost per degree of accumulated climb (iso)
RF.ISO_PENALTY_CAP = 30

function RF.defineProfile(def)
    assert(def and def.id, "recoil profile needs an id")
    local p = ZGB.merge({ ramp = 6, plateau = 0.35, drift = 0, sway = 0, swayPeriod = 10, noise = 0.15 }, def)
    RF._profiles[p.id] = p
    RF._cache = {}
    return p
end

function RF.getProfile(id) return RF._profiles[id] end

-- small deterministic PRNG (LCG), seeded from a string
local function seeded(str)
    local s = 0
    for i = 1, #str do s = (s * 31 + string.byte(str, i)) % 2147483647 end
    if s == 0 then s = 1 end
    return function()
        s = (s * 48271) % 2147483647
        return s / 2147483647
    end
end

local function patternLength(spec)
    local n = spec.internalCapacity or 0
    for _, m in ipairs(spec.magazines or {}) do if m.capacity > n then n = m.capacity end end
    if n < 1 then n = 1 end
    return math.min(n, RF.MAX_SHOTS)
end

--- Energy multiplier for kick, same curve as recoilDelay in the weapon factory.
function RF.energyScale(spec)
    local arch = ZGB.Archetypes[spec.archetype]
    return ZGB.WeaponFactory.caliberScale("recoilDelay", spec.caliber, arch and arch.refCaliber)
end

--[[ { profile, vertical, horizontal, recovery, length,
       kicks = { {x, y} per shot },  shots = { cumulative {x, y} per shot } }  (degrees) ]]
function RF.patternFor(spec)
    local key = spec.fullType or spec.id
    if RF._cache[key] then return RF._cache[key] end
    local rc = spec.recoil or {}
    local fp = rc.fp or {}
    local prof = RF._profiles[rc.pattern or "vertical"] or RF._profiles.vertical
    local e = RF.energyScale(spec)
    local vertical   = (fp.vertical or 1) * e
    local horizontal = (fp.horizontal or 0.5) * e
    local rand = seeded(tostring(key))
    local out = { profile = prof.id, vertical = vertical, horizontal = horizontal,
                  recovery = fp.recovery or 0.8, length = patternLength(spec), kicks = {}, shots = {} }
    local x, y = 0, 0
    for i = 1, out.length do
        local climb = (i <= prof.ramp) and 1 or prof.plateau
        local dy = vertical * climb
        local dx = horizontal * (prof.drift
                 + prof.sway * math.sin((i - 1) / prof.swayPeriod * 2 * math.pi)
                 + prof.noise * (rand() * 2 - 1))
        x, y = x + dx, y + dy
        out.kicks[i] = { x = dx, y = dy }
        out.shots[i] = { x = x, y = y }
    end
    RF._cache[key] = out
    return out
end

--- Shot counter for bursts. state = {} kept per gun by the caller; now in seconds.
function RF.track(state, now)
    if state.last and (now - state.last) <= RF.BURST_GAP then
        state.shot = (state.shot or 0) + 1
    else
        state.shot = 1
    end
    state.last = now
    return state.shot
end

--- Kick class for the iso fire animation, from the first-shot vertical kick.
function RF.kickClass(spec)
    local v = RF.patternFor(spec).vertical
    if v >= 2.6 then return "heavy" end
    if v >= 1.5 then return "medium" end
    return "light"
end

--[[ Iso application for shot `shot` of a burst.
     scale: current recoilDelay / base recoilDelay (attachments), default 1.
     returns { hitPenalty = n, kick = "light"|"medium"|"heavy", climb = degrees } ]]
function RF.iso(spec, shot, scale)
    local p = RF.patternFor(spec)
    local s = p.shots[math.min(math.max(shot or 1, 1), p.length)]
    local climb = math.sqrt(s.x * s.x + s.y * s.y) * (scale or 1)
    -- the first shot is free: the penalty is what the previous shots did to the aim
    local prev = (shot or 1) > 1 and p.shots[math.min(shot - 1, p.length)] or { x = 0, y = 0 }
    local before = math.sqrt(prev.x * prev.x + prev.y * prev.y) * (scale or 1)
    local penalty = math.min(RF.ISO_PENALTY_CAP, before * RF.ISO_PENALTY_PER_DEG)
    return { hitPenalty = math.floor(penalty * 10 + 0.5) / 10, kick = RF.kickClass(spec), climb = climb }
end

function RF._reset() RF._profiles, RF._cache = {}, {} end

return RF
