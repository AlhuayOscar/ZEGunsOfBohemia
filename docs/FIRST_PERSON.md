# Isometric vs first person

ZE Guns Of Bohemia runs every gun through the same data in both cameras. What
changes between them is the **view**: how that data is turned into what the
player sees. This page is the contract the first-person (FP) addon will build on.

## One factory, two applications

| Layer | Lives in | Same in both views? |
|---|---|---|
| Gun spec: caliber, magazines, stats, attachments | Core `Defs/` | Yes |
| Anim type: abstract clips, reload sequences, timings, casing rule | Core `Defs/ZGB_Def_Anims.lua` | Yes |
| Recoil profile and spray pattern | Core `Factory/ZGB_RecoilFactory.lua` | Yes (the pattern itself) |
| Holding stance | Holding addon | Yes (the stance id) |
| Reload plan and events | Reloading addon | Yes |
| **View**: real clips, script params, AnimSet variables | Iso addon (`ZGB_Def_IsoView.lua`), future FP addon | **No** |

A view is registered with `ZGB.AnimFactory.defineView{ id = "fp", ... }` and
maps every abstract clip of every anim type to its own animation. The tests
fail if a view leaves a clip unmapped (`AnimFactory.missingClips`), so a new
gun type can't ship half-animated in one camera.

Only one view provider may own animations per session (`ZGB.Mode`), and the
Iso addon refuses to start next to ZombieBuddy-based FP mods.

## What differs, system by system

| System | Isometric (pure Lua) | First person (Java + ZombieBuddy, future) |
|---|---|---|
| Animation | Vanilla skeleton clips picked by AnimSet variables `ZGB_AnimType`, `ZGB_Stance`, `ZGB_Kick` | FP arm/weapon rig; clips come from view `fp` |
| Recoil | No camera to move: a kick animation (light / medium / heavy) and a hit-chance penalty that follows the spray pattern during a burst, reset between bursts (`RecoilFactory.iso`) | The camera follows the pattern: `RecoilFactory.patternFor(spec).shots[n]` is the cumulative `{x, y}` offset in degrees; `recovery` pulls the view back per second |
| Holding | The stance is **chosen** by Aiming level (or sandbox): it picks idle / aim clip variants. Cosmetic only | The stance is **passive**: `Holding.fpPassive(level)` gives sway, walk bob and settle time, blended between stances so every level feels a little steadier |
| Casings | A casing item lands next to the shooter on the ejection side, cleaned up after a while | A physical casing spawns at the ejection port and follows `side` and `delay` |
| Aiming | Vanilla aim with our hit-chance and aim-time stats | Sight picture from each optic's `fp.sightAlignment` (eye offset + zoom) and the gun's `fp.ironSight` |
| Reload | Vanilla timed action, scaled by the reload plan; steps emitted as events | Same plan; each step plays its FP clip at the planned time |

## Data already in place for FP

- `spec.recoil.fp` (vertical, horizontal, recovery) per archetype, overridable per gun.
- `spec.recoil.pattern` and the profiles in `ZGB_Def_Recoil.lua`.
- `spec.fp.ironSight` and every optic's `fp.sightAlignment`.
- Stance `fp` values in the Holding addon.
- Events: `weapon.fire` (with the shot's place in the burst), `reload.start / step / complete`, `hold.changed` (includes `fp` passive values).

## Recoil numbers at a glance

The pattern's size comes from the gun's archetype values times the caliber's
energy relative to the archetype's reference caliber. Attachments scale it at
runtime: `current recoilDelay / base recoilDelay`, so a compensator or grip
shrinks the whole spray in both views.
