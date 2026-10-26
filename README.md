# ZE Guns Of Bohemia

*Idk, Guns and a lot of messing around.*

A firearms mod for **Project Zomboid Build 42** that works the same in isometric
and first person — without the animation overlap, flicker and crashes you get
when you mix isometric gun packs with ZombieBuddy-based first-person (viewpoint / ADS) mods.

![Build](https://img.shields.io/badge/Project%20Zomboid-Build%2042-8b0000)
![Version](https://img.shields.io/badge/version-0.7.0-blue)
![Status](https://img.shields.io/badge/status-pre--alpha-orange)
![License](https://img.shields.io/badge/license-CC0--1.0-lightgrey)

> [!WARNING]
> **Pre-alpha. Not run in game yet.** The logic is covered by offline tests, but
> several game-API calls are still unconfirmed (see [VERIFY list](#before-the-first-in-game-run--verify-list)).
> Expect things to be disabled with a warning in the log rather than working on the first boot.

---

## Table of contents

- [Why this mod exists](#why-this-mod-exists)
- [Features](#features)
- [What's in the box](#whats-in-the-box)
- [Installation](#installation)
- [Compatibility](#compatibility)
- [How it works](#how-it-works)
- [The addons](#the-addons)
- [3D models](#3d-models)
- [Sounds](#sounds)
- [Testing without starting the game](#testing-without-starting-the-game)
- [Testing in game](#testing-in-game)
- [Adding a gun](#adding-a-gun)
- [Development](#development)
- [Before the first in-game run — VERIFY list](#before-the-first-in-game-run--verify-list)
- [Roadmap](#roadmap)
- [Notes for the 3D side](#notes-for-the-3d-side)
- [Team](#team)
- [License](#license)

## Why this mod exists

Most Project Zomboid gun packs hard-code their numbers into item scripts and
assume the isometric camera. First-person mods built on ZombieBuddy then layer
their own animations on top of the same guns, and two systems end up fighting
over one weapon.

ZE Guns Of Bohemia is built the other way around:

- **One spec per gun is the single source of truth.** Ammo, capacity, stats,
  sounds, attachment rules and which animation set to use all come from one
  `ZGB.WeaponFactory.define{}` block. Item scripts only hold identity and model;
  the numbers are written in at boot.
- **Exactly one view provider owns animations.** The core mod has no animations.
  You pick one view addon — Isometric now, First Person later — and the mod
  refuses to load two at once, both at load time (`mod.info` `incompatible=`)
  and at runtime (`ZGB.Mode.registerProvider` rejects a second provider).
- **Nothing crashes on an unknown API.** Every game call that hasn't been
  confirmed on a real install is wrapped in `pcall`: a wrong name logs a warning
  and switches that one feature off.
- **Built on Gunworks.** Since v0.8 the mod runs on the
  [Gunworks Framework](https://steamcommunity.com/sharedfiles/filedetails/?id=3722064198)
  (mod id `SWMG`): it does the reloading (best magazine on R, mixed rounds in a
  magazine, speedloaders), fire modes with real rate of fire and bursts, and the
  stat layers. Our catalogue registers everything in it (`ZGB_Gunworks`, data from
  the pure `ZGB_GunworksPlan`). We own the catalogue, the attachment rules, the
  Gunsmith, models, sounds and loot. Other gun frameworks stay **incompatible**:
  two systems patching the same reload code is the kind of bug this mod exists
  to avoid. Gun packs built on Gunworks share its ammunition library with us.

## Features

- **Modular attachments with real mounting rules.** Slots accept specific
  interfaces (dovetail, picatinny, muzzle threads...). Parts can add new slots:
  an AK has no optic slot until you fit a side-rail mount. The game tells you
  what you're missing ("needs AK Side Rail Optic Mount").
- **Gunsmith screen.** Right-click a gun → **Gunsmith...**: a full-screen inspect view
  with the gun in the middle and every slot next to where its part goes (line to the
  spot), "ghost" slots that appear once a mount is on, a grid of parts per slot
  (fitted, owned, not owned, needs a mount), Weapon Data with the change the
  hovered part would make, and what you carry for the gun (rounds, magazines).
- **70 real guns in 32 calibers.** Pistols, revolvers and hand cannons, assault
  rifles, DMRs, bolt-action sniper rifles, SMGs, shotguns and lever actions.
  Damage, range, recoil and noise scale from each caliber's real muzzle energy.
- **Three magazine tiers.** Standard, extended and drum, and only the ones that
  exist for that gun. Extended and drum mags carry handling penalties while
  loaded. Real shared magazines are shared in game too (a STANAG fits the M16A2,
  M4A1, HK416 and Mk 12). **R** picks the fullest carried magazine automatically.
- **Ammo variants per caliber.** FMJ, Hollow Point, +P, Armor Piercing, Tracer,
  Soft Point, Subsonic, High Velocity, Match (long range), Wadcutter, and
  Buckshot / Birdshot / Slug / Flechette for shotguns. Each caliber only gets the
  loads that really exist for it, and a magazine holds only its caliber's loads.
- **Load all / Unload all magazines** in one menu click, topping off partly
  filled mags with the same ammo and never mixing types.
- **Stats recomputed from scratch** (base + parts + loaded magazine + loaded
  ammo), so attaching and detaching never drifts.
- **Vanilla-friendly.** Standard rounds of vanilla calibers reuse the vanilla
  items, so vanilla ammo boxes, crafting and other ammo mods keep working.
- **Loot integration.** Vanilla guns and magazines in loot tables are replaced
  by ours. Every other gun spawns next to its family by rarity, magazines spawn
  next to their gun by tier, and variant ammo spawns next to standard rounds.

## What's in the box

70 guns, 65 magazines, 58 attachments and 32 calibers, each with a placeholder 3D model (see [3D models](#3d-models)). The full catalogue with
every attachment slot and what it needs is generated into
[`docs/catalogue.json`](docs/catalogue.json) by `tools/gen_catalog.lua`.
Numbers after the caliber are magazine capacities (standard/extended/drum),
or "int" for an internal cylinder, tube or box.

| Category | Guns |
|---|---|
| Handguns (16) | Glock 17 (9x19mm, 17/33/50), Glock 19 (9x19mm, 15/33/50), Glock 18C (9x19mm, 17/33/50), Beretta 92FS (9x19mm, 15/30), SIG Sauer P226 (9x19mm, 15/20), CZ 75 (9x19mm, 16/26), SIG Sauer M17 (9x19mm, 17/21), Colt M1911A1 (.45 ACP, 7/10), Glock 21 (.45 ACP, 13/26), HK USP45 Tactical (.45 ACP, 12), Glock 22 (.40 S&W, 15/22), Walther PPK (.380 ACP, 7), Ruger Mk II (.22 LR, 10), Makarov PM (9x18mm Makarov, 8), Tokarev TT-33 (7.62x25mm Tokarev, 8), FN Five-seveN (5.7x28mm, 20/30) |
| Revolvers & hand cannons (12) | S&W Model 10 (.38 Special, 6 int), Colt Python (.357 Magnum, 6 int), Ruger GP100 (.357 Magnum, 6 int), S&W 686 Plus (.357 Magnum, 7 int), S&W Model 29 (.44 Magnum, 6 int), Colt Anaconda (.44 Magnum, 6 int), Colt Single Action Army (.45 Colt, 6 int), Taurus Judge (.410 Bore, 5 int), Ruger Super Redhawk (.454 Casull, 6 int), S&W Model 500 (.500 S&W Magnum, 5 int), Nagant M1895 (7.62x38mmR Nagant, 7 int), Desert Eagle Mark XIX (.50 AE, 7) |
| Assault rifles (8) | AK-47 (7.62x39mm, 30/40/75), AK-74 (5.45x39mm, 30/45), M16A2 (5.56x45mm, 30/40/100), M4A1 (5.56x45mm, 30/40/100), HK416 (5.56x45mm, 30/40/100), Steyr AUG A1 (5.56x45mm, 30/42), IMI Galil ARM (5.56x45mm, 35/50), HK G36 (5.56x45mm, 30/100) |
| Designated marksman rifles (4) | M14 (.308 Win / 7.62x51mm, 20/30), SVD Dragunov (7.62x54mmR, 10), Knight's SR-25 (.308 Win / 7.62x51mm, 20/25), Mk 12 SPR (5.56x45mm, 30/40/100) |
| Sniper rifles (bolt action) (8) | Remington 700 (.308 Win / 7.62x51mm, 4 int), Winchester Model 70 (.30-06 Springfield, 5 int), Mosin-Nagant M91/30 (7.62x54mmR, 5 int), Mauser Kar98k (7.92x57mm Mauser, 5 int), Lee-Enfield No. 4 (.303 British, 10 int), Accuracy International AWM (.338 Lapua Magnum, 5), Ruger Precision Rifle (6.5 Creedmoor, 10), Barrett M95 (.50 BMG, 5) |
| Submachine guns (8) | HK MP5A3 (9x19mm, 30/100), IMI Uzi (9x19mm, 32/50), MAC-10 (.45 ACP, 30), Thompson M1928A1 (.45 ACP, 20/30/50), HK UMP45 (.45 ACP, 25), FN P90 (5.7x28mm, 50), KRISS Vector (.45 ACP, 13/26), PPSh-41 (7.62x25mm Tokarev, 35/71) |
| Shotguns (8) | Mossberg 590 (12 Gauge, 8 int), Remington 870 (12 Gauge, 4 int), Benelli M4 (12 Gauge, 5 int), Saiga-12 (12 Gauge, 5/10/20), Kel-Tec KSG (12 Gauge, 14 int), Double-Barrel Coach Gun (12 Gauge, 2 int), Winchester Model 1897 (12 Gauge, 5 int), AA-12 (12 Gauge, 8/32) |
| Lever-action rifles (6) | Winchester Model 1894 (.30-30 Win, 7 int), Marlin 336 (.30-30 Win, 6 int), Henry Big Boy (.44 Magnum, 10 int), Marlin 1894C (.357 Magnum, 9 int), Henry H001 .22 (.22 LR, 15 int), Marlin 1895 Guide Gun (.45-70 Govt, 6 int) |

**Attachments:** optics (red dot, holographic, 4x, 3-9x hunting, 8x precision,
pistol RMR, PSO-1, PU, rimfire 4x), mounts (AK side rail, carry handle, scope
base, HK claw, M14, Mosin PU, Ruger rings), railed handguards, rail and 3-lug
adapters, foregrip, lights, bipod, suppressors and brakes per thread, shotgun
chokes, stocks, side saddle and slings.

**Ammo by caliber** (first entry is the default round, sorted by muzzle energy):

| Caliber | Loads |
|---|---|
| .22 LR | Round Nose, High Velocity, Hollow Point, Subsonic |
| .380 ACP | FMJ, Hollow Point |
| 9x18mm Makarov | FMJ, Hollow Point, Armor Piercing |
| .38 Special | FMJ, Hollow Point, +P, Wadcutter |
| 5.7x28mm | Sporting (SS197), Armor Piercing, Tracer, Subsonic |
| 7.62x38mmR Nagant | FMJ |
| 9x19mm | FMJ, Hollow Point, +P, Subsonic, Armor Piercing |
| .45 ACP | FMJ, Hollow Point, +P |
| .40 S&W | FMJ, Hollow Point |
| .45 Colt | Lead Round Nose, Hollow Point |
| 7.62x25mm Tokarev | FMJ, Armor Piercing |
| .357 Magnum | Jacketed Soft Point, Hollow Point, FMJ |
| .410 Bore | 00 Buckshot, Birdshot, Slug |
| .44 Magnum | FMJ, Hollow Point, Soft Point |
| 5.45x39mm | FMJ, Armor Piercing, Tracer, Hollow Point |
| .223 Rem | FMJ, Hollow Point, Soft Point |
| 5.56x45mm | FMJ, Armor Piercing, Tracer, Soft Point, Match (Long Range) |
| .50 AE | FMJ, Hollow Point |
| 7.62x39mm | FMJ, Armor Piercing, Tracer, Hollow Point, Soft Point |
| .454 Casull | Soft Point, Hollow Point |
| .30-30 Win | Soft Point, Hollow Point |
| 12 Gauge | 00 Buckshot, Birdshot, Slug, Flechette |
| 6.5 Creedmoor | Match (Long Range), Soft Point, Hollow Point |
| .303 British | FMJ, Soft Point, Tracer, Armor Piercing |
| .308 Win / 7.62x51mm | FMJ, Armor Piercing, Tracer, Soft Point, Match (Long Range) |
| .500 S&W Magnum | Soft Point, Hollow Point |
| 7.62x54mmR | FMJ, Armor Piercing, Tracer, Soft Point, 7N1 Sniper (Long Range) |
| .30-06 Springfield | FMJ, Soft Point, Armor Piercing, Tracer |
| .45-70 Govt | Soft Point, Hollow Point |
| 7.92x57mm Mauser | FMJ, Armor Piercing, Tracer, Soft Point |
| .338 Lapua Magnum | Match (Long Range), Armor Piercing, Soft Point |
| .50 BMG | FMJ, Armor Piercing, Tracer, Match (Long Range) |

## Installation

ZE Guns Of Bohemia isn't on the Steam Workshop yet. The repo root is a
complete Workshop item (`workshop.txt`, `preview.png`, `Contents/mods/...`,
a `poster.png` per mod). To run it locally:

1. Put the repo in your Zomboid Workshop folder, or link it there so you keep
   working in the clone (Windows, no admin needed):
   ```
   mklink /J "%UserProfile%\Zomboid\Workshop\ZEGunsOfBohemia" "C:\path\to\zegunsofbohemia"
   ```
   The game lists it under **Workshop** in the main menu (to upload) and the
   mods under **Mods**.
2. Subscribe to **Gunworks Framework** (Workshop 3722064198, mod id `SWMG`). In **Mods**, enable:
   - **Gunworks-gang** (required by Core),
   - **ZE Guns Of Bohemia - Core** (always),
   - the essential addon **ZE Guns Of Bohemia - Tactical Holding**,
   - **exactly one** view addon: **ZE Guns Of Bohemia - Isometric** for now,
   - optionally **ZE Guns Of Bohemia - Reload events** (needed by Callouts and the spent-case drop on reload) and **ZE Guns Of Bohemia - Callouts**.

   Core tells you on game start if a view addon or an essential addon is missing.
3. Start a new game. Existing saves keep their vanilla guns (conversion isn't done yet).

## Compatibility

| Mod | Works with |
|---|---|
| Core + Isometric addon | vanilla isometric camera |
| Core + First Person addon *(planned)* | ZombieBuddy-based first-person / viewpoint mods |
| Isometric addon + ZombieBuddy / Viewpoint | **No** — blocked on purpose, that's the overlap this mod fixes |
| Gunworks Framework (`SWMG`) | **Required** — reloading, magazines, mixed rounds, fire modes |
| Gun packs built on Gunworks | Expected to work: same framework, shared ammunition library (not tested yet) |
| Other gun packs, reloading mods, generic gun frameworks | **No** — blocked on purpose (see below) |
| Mods that only add vanilla-caliber ammo | Yes for standard rounds of vanilla calibers (we reuse the vanilla items) |
| Addons built on ZE Guns Of Bohemia's API | Yes — this is how to extend the mod |

**Why other gun mods are blocked.** Gunworks does our reloading, magazines and
fire modes. Mods that rework guns or reloading in general patch the
same functions in ways we can't predict, which is exactly the overlap and
crash problem this mod was built to fix. So Core lists known gun and reload
mods under `incompatible=` in its `mod.info`, and if one is active anyway,
Core switches itself off at runtime (no hooks, no loot changes) and tells the
player why. The list lives in `ZGB_Mode.FOREIGN_GUN_MOD_IDS` and is checked
against `mod.info` by the tests.

Want a new effect, ammo type or gun? Build it as an addon: register calibers
with `ZGB.AmmoCatalog.addCaliber`, magazines with `ZGB.MagazineFactory.define`,
parts with `ZGB.PartFactory.define` and guns with `ZGB.WeaponFactory.define`.

Multiplayer isn't supported yet: inventory changes are single-player correct
but don't send the B42 sync calls.

## How it works

```
Contents/mods/
  ZEGunsOfBohemiaCore/   logic, items, UI, loot. No animations, no Java. Always enabled.
  ZEGunsOfBohemiaIso/    isometric view addon (pure Lua). Registers provider "iso".
  ZEGunsOfBohemiaReload/ optional: reload events (kind, timing) for callouts and case dropping
  ZEGunsOfBohemiaHolding/ essential: tactical holding (stance by Aiming level)
  ZEGunsOfBohemiaCalls/  optional: callouts ("CHANGING MAG!")
  ZEGunsOfBohemiaFP/     (planned) first-person addon, requires ZombieBuddy. Provider "fp".
tests/                   offline tests (Lua 5.1) with a fake inventory
tools/gen_scripts.lua    regenerates weapon, magazine, part, ammo and casing item scripts from the Lua catalogs
tools/gen_catalog.lua    dumps the catalogue to docs/catalogue.json (for the 3D side and docs)
tools/gen_animsets.lua   writes draft iso AnimSet nodes to docs/animsets/iso/ from the animation factory
docs/FIRST_PERSON.md     isometric vs first person: what each view does with the same data
```

Each mod folder follows the B42 layout: `42/` (mod.info + media) and `common/`.

| File | Job | Touches game API? |
|---|---|---|
| `Factory/ZGB_Archetypes` | defaults per family (pistol, revolver, smg, assault_rifle, dmr, shotgun, bolt_rifle, lever_rifle) and the catalogue categories | no |
| `Factory/ZGB_WeaponFactory` | `define{}` → validated spec. `MaxAmmo` comes from the standard magazine; stats scale with caliber energy | no |
| `Factory/ZGB_MagazineFactory` | `define{}` for magazines: caliber, tier, capacity; tier rules and loot weights | no |
| `Factory/ZGB_PartFactory` | `define{}` for attachments: `kind`, `interface`, `provides`, `mods` | no |
| `Factory/ZGB_AmmoCatalog` | ammo variant effects × which variants exist per caliber; spent casing per caliber group | no |
| `Factory/ZGB_AnimFactory` + `Defs/ZGB_Def_Anims` | anim types (how a gun moves and reloads) and views (how a camera shows it) | no |
| `Factory/ZGB_RecoilFactory` + `Defs/ZGB_Def_Recoil` | spray patterns per gun; iso and FP applications | no |
| `ZGB_Events`, `ZGB_Addons`, `ZGB_Sandbox` | event bus between systems, addon registry, sandbox reads | no |
| `ZGB_Casings` | when and what a gun ejects | no |
| `ZGB_Attachments` | rules engine: canAttach / canDetach / requirement chains / UI tree | no |
| `ZGB_Stats` | final stats = base + parts + magazine + ammo (add → mul → set → clamp) | no |
| `ZGB_Magazines`, `ZGB_Ammo` | magazine choice and the load-all planner (menus used only without Gunworks) | no |
| `ZGB_GunworksPlan` | the catalogue as Gunworks registrations: ammo families, magazine profiles, rate of fire, our stat layer | no |
| `ZGB_Gunworks` | feeds the plan to Gunworks at boot; our stat layer and restore handler | yes |
| `ZGB_Mode` | view-provider gate (only one owner of animations) and the foreign gun-mod block | `getActivatedMods` |
| `ZGB_ScriptApply` | at boot, writes every spec into the item scripts | yes |
| `ZGB_ItemBridge` | the **only** place that calls live item / weapon methods | yes |
| `ZGB_Service`, `ZGB_PartActions`, `ZGB_MagazineActions`, `ZGB_AmmoActions` | timed actions | yes |
| `client/.../ZGB_ClientHooks` | menus; emits `weapon.equip`, `weapon.fire`, `ammo.empty` | yes |
| `client/.../ZGB_GunsmithWindow` | attachment UI | yes |
| `server/.../ZGB_Distributions` | swaps vanilla guns for ours in loot, adds variants | yes |
| Iso `ZGBIso/ZGB_Def_IsoView`, `ZGB_ViewIso` | the iso view: clip map, stance variants, script params | no |
| Iso `client/ZGBIso/ZGB_IsoClient` | anim variables, burst recoil penalty, case dropping | yes |
| Reload `ZGBReload/ZGB_Reload` | reload rules: kind, chamber +1, plan and timing | no |
| Reload `client/ZGBReload/ZGB_ReloadHooks` | follows Gunworks' reload / insert actions, emits `reload.*` | yes |
| Holding `ZGBHolding/ZGB_Holding` | stances and which one a level gets | no |
| Calls `ZGBCalls/ZGB_Calls`, `ZGB_Def_Calls` | callout rules and lines | no |

Files marked "no" never touch the game API, which is what lets them run in the offline tests.

## The addons

Core holds the data and the rules engines. Everything a player sees or does
with a gun comes from addons that talk to each other only through the event
bus (`ZGB_Events`), so each one can change or be replaced on its own:

```
 Core ──weapon.equip / weapon.fire / ammo.empty──►┐
 Reloading ──reload.start / step / complete, ammo.lastMag──►├──► Isometric view (animation, recoil, casings)
 Tactical Holding ──hold.changed──►┘                    └──► Callouts (shouts)
```

### Animation factory (Core) and the isometric view

Animation follows the same factory pattern as guns:

- **Anim types** (`Defs/ZGB_Def_Anims.lua`) say how a kind of gun moves: its
  abstract clips (idle, aim, fire, magOut, magIn, chargingHandle, loadRound,
  openCylinder...), reload sequences, clip timings and when it ejects casings.
  There are 12: handgun, revolver, revolver_gate, rifle, smg, bullpup,
  bolt_mag, bolt_internal, lever, pump, semi_shotgun, break_action. A type can
  extend another (`base`), so a bullpup only states what differs from a rifle.
- **Views** apply the factory to one camera. The Isometric addon defines view
  `iso` (`ZGB_Def_IsoView.lua`): every abstract clip maps to a vanilla
  skeleton clip as a stand-in until our own clips exist, tuned per type with
  playback speed. The first-person addon will define view `fp` with its own clips.
- A gun picks its type with `animType` (archetype default, per-gun override:
  AUG and P90 are bullpups, the SAA and Nagant load through a gate...).
- The iso addon sets AnimSet variables `ZGB_AnimType`, `ZGB_Stance` and
  `ZGB_Kick` on the character. `tools/gen_animsets.lua` writes the matching
  AnimSet nodes as **drafts** in `docs/animsets/iso/` (idle, aim, fire). None
  ship: the third in-game test showed that `x_extends` looks for the parent
  node in our own mod folder, so nodes extending vanilla's failed to parse and
  guns could not aim or fire. Guns use the vanilla poses (which the pose check
  shows match the vanilla guns) until stance nodes are self-contained and
  checked in game. `validate_mod` rejects an `x_extends` our mod can't resolve.
- **Case dropping (iso):** semi-autos drop a casing per shot, bolt, pump and
  lever guns after the action cycles, revolvers and break-actions drop all
  their empties when you reload. Casings land on the ejection side and are
  cleaned up after a while (sandbox: on/off, lifetime, max on the ground).

### Recoil and spray patterns (Core)

Each gun has a spray pattern built from a named profile (`vertical`,
`climb_right`, `climb_left`, `s_curve`, `erratic`, `low`, `kick`) and its own
numbers: the archetype's recoil values times the caliber's energy. The pattern
is seeded from the gun, so it is the same every time and can be learned (AK-47
climbs then drifts right, Thompson drifts left, PPSh-41 sways in an S).
Attachments that lower recoil shrink the whole pattern.

- **Iso:** no camera to move, so recoil is a kick animation (light, medium,
  heavy) plus a hit-chance penalty that follows the pattern during a burst and
  resets when you stop firing (sandbox switch).
- **First person:** the camera will follow the pattern itself. See
  [`docs/FIRST_PERSON.md`](docs/FIRST_PERSON.md) for every difference between the two views.

### Gunworks (Core) and reload events (optional addon)

- **Gunworks reloads.** R picks the fullest magazine of the gun's profile
  (standard, then extended, then drum), a magazine can hold mixed rounds of its
  caliber (our variants, vanilla's and the Gunworks ammunition library's), and
  its radial menu selects magazine, ammunition and fire mode. Auto and burst
  guns get its rate of fire (`ZGB_GunworksPlan.RPM` per archetype unless the gun
  sets `rpm`; bursts of 3).
- **Our stats are a Gunworks stat layer.** Gunworks restores the script base and
  re-applies every layer; ours adds attachments, the loaded magazine's tier and
  the round being fired, from scratch each time, so nothing stacks. While
  Gunworks runs a gun in RealAuto / RealBurst it owns RecoilDelay.
- **Reload events addon.** Follows the reloads Gunworks performs, plans their
  kind and timing (`ZGB_Reload`: tactical with +1 on closed bolts, empty, one
  round at a time, dump-and-reload, gate, break-action) and emits `reload.start`,
  `reload.step`, `reload.complete` and `ammo.lastMag` for the callouts and the
  spent-case drop. It does not change the reload itself.

### Tactical holding (essential addon)

How a character holds the gun depends on their **Aiming** level:

| Stance | Default level | Iso look |
|---|---|---|
| Novice | 0 | muzzle carried low, shaky, slow to raise |
| Trained | 3 | low ready |
| Proficient | 6 | steady ready |
| Expert | 9 | high compressed ready, snaps onto target |

Sandbox options: switch it off, move each level threshold, or turn the level
link off ("no level cap") so everyone uses one fixed stance. In iso the
stance only changes how the character looks. In first person it will be
passive: an inexperienced shooter's idle hold sways more (`fpPassive`).

### Callouts (optional addon)

The character shouts what they're doing: **CHANGING MAG!** on a tactical
reload, **RELOADING!** when empty, **LOADING SHELLS!**, **I'M OUT!**,
**LAST MAG!**, **SWITCHING TO PISTOL!**, and **FRAG OUT! / SMOKE OUT! /
FLASHBANG!** once grenades exist. Calls are data (`ZGB_Def_Calls.lua`), share a
cooldown, and urgent ones interrupt it. Sandbox: on/off, cooldown, and each
category (reloads, ammo, weapon, grenades).

### Writing your own addon

Register with `ZGB.Addons.register{ id, name, modId, version }`, listen with
`ZGB.Events.on("reload.start", fn)`, and add data through the factories:
`AnimFactory.defineType / defineView`, `RecoilFactory.defineProfile`,
`Holding.defineStance`, `Calls.defineCall`, plus the gun, magazine, part and
caliber factories. Read sandbox options with `ZGB.Sandbox.get`.

### Attachments: how "a red dot needs a mount on an AK" works

Nothing is special-cased. Slots have a `kind` and accepted `interfaces`; parts
have a `kind`, an `interface`, and may `provide` new slots.

- The AK-47's `side_mount` slot accepts `ak_dovetail` — there is **no** optic slot.
- `Mount_AK_SideRail` (interface `ak_dovetail`) provides `optic_rail`, which accepts `picatinny`.
- `Optic_RedDot` is `picatinny`, so `canAttach` returns `needs {Mount_AK_SideRail}`.
- The Glock 17 has an `under_rail` directly, so a light goes straight on; the AK needs the quad-rail handguard first.
- Removing a mount with an optic still on it is blocked ("remove Red Dot first").

### Magazines

Magazines are items of their own, defined once in `Defs/ZGB_Def_Magazines.lua`.
The rules:

- **Three tiers only:** `standard`, `extended`, `drum`. A gun lists at most one
  magazine per tier, and only the tiers that really exist for it (a 1911 has
  standard + extended, an AWM only standard). Guns without a detachable magazine
  (revolvers, tube shotguns, lever actions, internal-box bolt actions) use
  `internalCapacity` instead and can't take magazines.
- **One caliber per magazine.** A magazine holds any load its caliber comes in
  and nothing else, so a .22 magazine can never hold a long-range load (.22 LR
  has none) and none spawns in loot.
- **Shared where real.** STANAG mags fit the M16A2, M4A1, HK416 and Mk 12; Glock 9mm
  extended mags and drums fit the G17, G18C and G19; Glock 21 mags fit the KRISS Vector.
- **Tier penalties while loaded:** extended adds a little aim time and weight,
  drums add more aim time, reload time and weight. A magazine can override its
  tier's default (the AK drum does).

- **Right-click the gun → Load magazine** lists the fullest carried mag of each
  type. Swapping queues eject → retarget → insert, so ejecting always hands back the right item.
- **R** on an empty gun picks the carried mag with the most rounds (ties keep the type you were using).
- Any insert (R, our menu, the vanilla menu) records the loaded mag and re-applies stats.

Vanilla supports only one `MagazineType` per gun, so we retarget `MagazineType`
and `MaxAmmo` right before a magazine goes in.

### Ammo

Guns declare a `caliber` (e.g. `"762x39"`); the ammo list comes from the catalog.
A magazine's ammo variant is its vanilla `AmmoType`, so vanilla bullet loading stays
consistent. Inserting a mag switches the gun to that ammo and its stats change
(AP crits, HP damage, subsonic noise...). Tube-fed shotguns get
**Load with... Buckshot / Slug** while empty.

**Load all magazines** (right-click any of our guns, magazines or matching ammo):

- one usable ammo type → a single "Load all 7.62x39mm magazines (FMJ, 60 rds)"
- several → a submenu: "FMJ - loads 60 (have 120)", "Armor Piercing - loads 25 (have 25)"...
- partly-filled mags are topped off with the **same** type first; mags holding
  another type are skipped. "Unload all ... magazines" empties them so you can switch.
- one timed action per magazine: cancelling keeps what's already loaded.

## 3D models

Every gun, attachment, magazine and casing has a model in its own folder
under `media/models_X/ZGB/`, so the artist can replace them one by one:

- **Real models** from free-licensed sources (CC0 and CC-BY only), fitted to
  each item's size and attachment points. Since v0.8 each gun is its own
  detailed model from Sketchfab where one exists (`tools/sketchfab/picks.lua`),
  with the older low-poly packs as the fallback. Sources, authors and
  licenses, one credit per Sketchfab model: [`CREDITS.txt`](CREDITS.txt), also
  shipped with the mod.
- **One texture per gun** (`textures/ZGB/Guns/<Id>.png`: the gun at 1024 px for
  detailed sources, plus every part baked into its variants) and per real
  attachment (`Parts/<Id>.png`); placeholder-only models share the palette
  `ZGB_Atlas.png`. A model script names one texture, so this is the unit.
- **Placeholders** (boxes and cylinders at real-world size, from
  `Defs/ZGB_Def_Models.lua`) for everything else: 100 items, including all
  magazines and casings.
- Everything (490 models with the variants) ships as FBX. [`docs/MODEL_LIST.txt`](docs/MODEL_LIST.txt) lists
  every asset and marks which ones are still placeholders.

Getting the Sketchfab models (Blender's bundled Python runs the tools):

1. `tools/sketchfab/search.py` asks Sketchfab's public search for
   downloadable CC0 / CC-BY candidates for every gun and part and makes a
   numbered contact sheet per item (`.cache/sketchfab/sheets/`). The picks go
   in `tools/sketchfab/picks.lua` with any `fix` (`drop_loose` for a magazine
   lying beside the gun, `cut_top` for a built-in scope, `pca` for a model
   tilted in its file).
2. `tools/sketchfab/fetch.py` downloads the picks. It needs your own Sketchfab
   API token in `SKETCHFAB_API_TOKEN` (Settings, Password & API), checks each
   license again, skips what is already there and writes the credits to
   `tools/sketchfab/credits.lua`.
3. `tools/sketchfab/check_rips.py` reads the names inside every download and
   flags models ripped from games (Call of Duty, CS, Tarkov naming). A CC-BY
   label is only as good as the uploader: flagged models are never used.
4. `gen_models.lua`, then `import_models.py -- --review sheet.png` to look at
   every fitted model next to its placeholder before the full run.

The pipeline also makes inventory icons, the side-view sprites for the
attachment window and the model scripts with attachment points. Full guide:
[`docs/MODELS.md`](docs/MODELS.md).

How attachments show on the gun (`ZGB_Visuals`):

- **Drawn by the game:** optics, muzzle devices, grips, bipods, slings and AR
  stocks have their own model. Core attaches a visual twin (`ZGB.Vis_<Id>`, a
  vanilla WeaponPart with no stats, never in loot) so vanilla draws it on the
  gun's `scope` / `canon` / `stock` / `sling` / `recoilpad` point.
- **Built into a variant:** mounts, rail handguards, adapters, lasers, lights,
  shell holders, recoil pads and stocks that replace the original. The Iso
  addon switches the gun to the variant model for its current parts
  (`AK47__Handguard_AK_Quad__Mount_AK_SideRail`). 366 variants cover every
  combination the rules allow.
- The **Gunsmith screen** draws the build as a large side view and shows the gun
  with the hovered part before you fit it. Slot placement is `ZGB_InspectLayout`
  (pure, tested for all 70 guns at 1080p and 720p: no overlaps, on screen, by the part).

New attachments in v0.6: 5.56, .308 and AK flash hiders, a 9mm pistol
compensator, angled and stubby grips, rifle and pistol lasers, a rubber recoil
pad and a buttstock shell holder (shotguns, lever and bolt guns get recoil pad
and buttstock slots).

Known placeholder gap: on shotguns, a recoil pad or buttstock shell holder
stays where the original stock ended when a folding stock replaces it.

## Sounds

Gunshots are recordings of real guns from The Free Firearm Sound Library
(CC0); magazine, rack and shell sounds are zer0_sol's reload recordings
(CC0). `Defs/ZGB_Def_Sounds.lua` sorts every gun into a sound family by
archetype and caliber (9mm pistol, .45, .22, magnum revolver, AK, AR,
Mosin, .50 BMG, pump shotgun...): 19 families, each with a suppressed
version. The weapon factory puts them in `spec.sounds` (a gun def can
override any of them), and with a suppressor fitted the bridge swaps the
fire sound for the suppressed one.

`tools/gen_sounds.lua` cuts, normalises and converts the sources (ffmpeg)
to mono Ogg in `media/sound/ZGB/` (43 files, about 650 KB) and writes the
sound scripts `scripts/ZGB_sounds.txt`. The sources are downloaded into
`.cache/sound_sources/` (not in git).

## Testing without starting the game

Project Zomboid is slow to start, so most problems can be caught offline:

| Tool | What it checks |
|---|---|
| `lua5.1 tests/run_tests.lua` | All the game logic (136 tests), against a stub game |
| `lua5.1 tools/validate_mod.lua` | The mod the way the game reads it: mod.info files, every item script -> icon / model / twin, every model -> mesh and texture file, every sound -> audio file, Lua syntax and `goto`, AnimSet XML, sandbox labels, PNG / FBX / OGG headers, Workshop files |
| `lua5.1 tools/gen_pz_api.lua` | Indexes every method and field name of the installed game (jar + vanilla Lua) into `.cache/pz_api/`; from then on `validate_mod` fails on any game method we call that this build doesn't have. Rerun after a game update |
| `blender -b -P tools/blender/check_models.py` | Re-imports every FBX and draws contact sheets into `.cache/check/` |
| `lua5.1 tools/preview_gunsmith.lua AK47 muzzle Suppressor` | Draws the Gunsmith screen from the real UI code into `.cache/gunsmith_AK47.png` (fake UI in `tests/mock_ui.lua`: text as bars, guns as silhouettes) |
| `blender -b -P tools/blender/import_models.py -- --review review.png` | Each real model over its placeholder, to check the fit |

What only the game can tell is in the [VERIFY list](#before-the-first-in-game-run--verify-list).

## Testing in game

### Self-test (one click, debug mode)

Start the game with `-debug`, load a save, right-click the ground:

- **ZGB: run self-test** creates every gun, magazine and round in memory and
  checks what the game really holds: name, ammo type, capacity, magazine type,
  model and sound scripts (strict: `GameSounds.isKnownSound`, and the file each
  sound plays), the `base:firearm` / magazine / ammo tags, fire mode, rack
  after shot, reload type, swing anim, muzzle flash, two-handed, the muzzle
  point as the game read it (must be on +Y), stats after `applyStats`, each
  magazine tier filled and inserted, a second ammo load, and the suppressed
  shot. About 3,500 checks in a few seconds. The summary appears over your
  head; `FAIL` and `SKIP` lines go to `console.txt` as `[ZGB][TEST]`,
  everything to `%UserProfile%\Zomboid\Lua\ZGB_selftest.txt`. Send that file.
- **ZGB: pose check (screenshots)** equips one gun of every animation type in
  turn (pistol, revolver, rifle, SMG, bullpup, bolt, lever, pump, semi-auto
  and break-action shotgun), lets the idle pose settle, aims, takes a
  screenshot (`ZGB_pose_<type>_<gun>`) and records the animation variables the
  game used (`Weapon` must be `firearm`) in `Zomboid\Lua\ZGB_poses.txt`. About a
  minute; don't move. Your own gun goes back in your hands afterwards.
- **ZGB: give test kit** puts a Glock 17, an AK-47 and a Remington 870 in your
  inventory with full magazines of every tier, 30 rounds each and a
  suppressor, to try firing by hand.
- **ZGB: give ALL guns + attachments** puts every gun (empty) and one of every
  attachment in your inventory, to look at each model up close. It is heavy:
  drop what you are done with.

The same checks run offline against `tests/mock_game.lua` (`run_tests.lua`),
which reads our generated item, sound and model scripts the way the game does,
so a FAIL in game means the game behaves differently from what we assumed.

### Manual checklist

A checklist for the first runs. Enable Gunworks, Core, Tactical Holding,
Isometric (and Reload events + Callouts), start a new game, and use debug mode to spawn items
(`ZGB.AK47`, `ZGB.Mount_AK_SideRail`, `ZGB.Optic_RedDot`...).

| Check | What you should see | If not |
|---|---|---|
| Item icons | Side-view icons for ZGB guns, parts and magazines | `Icon = ZGB_<Id>` / texture naming (VERIFY 18) |
| Gun in hand | The gun's model, held at the grip | `WeaponSprite = ZGB.<Id>` format, FBX axes / scale, origin (VERIFY 18-19, 22) |
| Gunshot | A real gunshot per gun family; muffled with a suppressor | sound scripts, `setSwingSound` (VERIFY 23) |
| Attachment window | Right-click gun -> Gunsmith: side view of the build at the top | `getTexture` path, `drawTextureScaled` (VERIFY 21) |
| Optic / suppressor | The part visible on the gun after attaching | visual twin `Vis_` items, `ModelWeaponPart` (VERIFY 20) |
| Side mount / handguard / laser | The gun switches to a model with it built in | `setWeaponSprite`, `resetEquippedHandsModels` (VERIFY 20) |
| Holding stance | Vanilla gun pose (stance nodes are drafts for now) | pose check screenshots next to the vanilla references |
| Callouts | CHANGING MAG! over the character on a reload | `Say`, reload hooks (VERIFY 14, 17) |
| Casings | Brass next to you after firing | `AddWorldInventoryItem` (VERIFY 15) |
| Recoil | Long bursts lose accuracy, single shots don't | `OnWeaponSwing` (VERIFY 14) |

A wrong game-API name logs one `[ZGB][WARN]` line in `console.txt` and turns
that feature off instead of crashing. Searching the log for `[ZGB]` shows
what worked and what didn't.

## Adding a gun

1. If it takes magazines nobody defined yet, add them to `Defs/ZGB_Def_Magazines.lua`
   (caliber, tier, real capacity).
2. In `Defs/ZGB_Def_Weapons.lua`, add a
   `ZGB.WeaponFactory.define{ id, archetype, displayName, caliber, magazines = { standard = ..., extended = ..., drum = ... }, slots = { ... } }`
   (or `internalCapacity = n` instead of `magazines`). Give it `replaces = {...}`
   or a loot `rarity`. Anything you leave out comes from the archetype, and
   damage / range / recoil / noise are scaled from the caliber.
3. Run `tools/gen_scripts.lua` and `tools/gen_catalog.lua`. The item skeletons
   and the catalogue are generated; stats, capacity, sounds and animations come
   from the spec at boot.

> [!IMPORTANT]
> Never put `MaxAmmo`, `AmmoType` or animations in an item script by hand, and
> never edit the generated `ZGB_items_*.txt` files. The spec overwrites them.

New attachments go in `Defs/ZGB_Def_Parts.lua`, new ammo in
`Factory/ZGB_AmmoCatalog.lua`. The tests check that every slot has a part that
fits it, every part fits some gun, and every caliber in use has somewhere to spawn.

## Development

Requires **Lua 5.1** (Project Zomboid's Kahlua is roughly 5.1: no `goto`, no `//`, no `utf8`, and no `next()`: use `ZGB.isEmpty` or `pairs`).
On Windows, `winget install DEVCOM.LuaJIT` works: run the same commands with `luajit`.
LuaJIT accepts `goto`, so don't rely on it to catch that one.

```bash
lua5.1 tests/run_tests.lua      # 136 tests: catalogue, magazines, attachments, stats, ammo, loot, mod gates, animation factory, recoil, casings, models and variants, sounds, the three addons, the addon clients against a stub game, and validate_mod
```

```bash
lua5.1 tools/validate_mod.lua   # offline check of the whole mod as the game reads it
```

```bash
lua5.1 tools/gen_scripts.lua    # after editing anything in Defs/ or ZGB_AmmoCatalog.lua
```

```bash
lua5.1 tools/gen_catalog.lua    # refresh docs/catalogue.json
```

```bash
lua5.1 tools/gen_animsets.lua   # refresh the iso AnimSet node drafts (docs/animsets/iso, nothing shipped)
```

```bash
lua5.1 tools/gen_models.lua     # placeholder models, icons, preview sprites, model scripts, credits
blender -b -P tools/blender/import_models.py   # real models from .cache/model_sources (see docs/MODELS.md), then gen_scripts.lua
blender -b -P tools/blender/check_models.py    # contact sheets of the exported FBX in .cache/check/
blender -b -P tools/blender/make_art.py        # Workshop preview.png and each mod's poster.png
```

```bash
lua5.1 tools/gen_sounds.lua     # sounds from .cache/sound_sources (needs ffmpeg), sound scripts, credits
```

Conventions:

- Code prefix is `ZGB`: global table `ZGB`, item module `ZGB`, files `ZGB_*.lua`.
- Pure-logic changes get a test; bridge and action code is tested against `tests/mock_game.lua`.
- Unconfirmed game-API calls are tagged `-- VERIFY` and wrapped in `pcall`. Remove the tag once confirmed in game.
- Code, comments and commits are in English.

## Before the first in-game run — VERIFY list

These game-API details were written from Build 41/42 conventions without an
install to check against. Each is marked `-- VERIFY` in the code:

1. **FP mod IDs** in `ZGB_Mode.FP_MOD_IDS` and `ZEGunsOfBohemiaIso/42/mod.info` — copy the exact `id=` from ZombieBuddy's and the viewpoint mod's `mod.info`.
2. **Item script fields** (`ItemType = base:weapon`, etc.) — compare with vanilla `AssaultRifle` / `Pistol` in your build's `media/scripts`.
3. **`AmmoType` format** — CONFIRMED on the first test: B42 uses registry ids (`base:bullets_45`). Ours are registered in the generated `media/registries.lua` (`AmmoType.register("zgb:...", "ZGB.Ammo_...")`, the B42 `ModRegistries` hook); at runtime the bridge resolves them with `AmmoType.get(ResourceLocation.of(id))` and reads `getAmmoType():getItemKey()` like vanilla. The in-game self-test confirmed all 97 ammo types resolve and magazines report them. `Base.223Bullets` no longer exists in B42, so .223 Rem is all ours.
4. **HandWeapon setter names** in `ZGB_ItemBridge.SETTERS` — CHECKED offline: every method our Lua calls exists in build 42.21 (`tools/gen_pz_api.lua` + `validate_mod`). Existing is not the same as doing what we think: the self-test checks the values they leave.
5. **Anim names** in `ZGB_ViewIso.lua` — copy from vanilla gun scripts.
6. **Timed-action style** (`perform` / `complete`) — compare with vanilla `ISUpgradeWeapon`.
7. **Magazine hooks** (`ZGB_ReloadHooks`, `ZGB_MagazineActions`): `ISInsertMagazine` / `ISEjectMagazine` constructors and the `gun` field, `ISReloadWeaponAction.BeginAutomaticReload`, `setMagazineType`, `isContainsClip`, `getAllTypeRecurse`. If one is missing, a warning is logged and that feature turns off.
8. **Ammo** (`ZGB_ItemBridge`): `setAmmoType` / `getAmmoType` on magazines and guns, `getCountTypeRecurse`, whether `RemoveOneOf` reaches into bags, `AddItems`; the vanilla ammo ids in `ZGB_AmmoCatalog`; `Count` in the ammo scripts.
9. **MP**: inventory add/remove in `ZGB_Service` is single-player correct; MP needs the B42 send* sync calls.
10. **Foreign gun-mod ids** in `ZGB_Mode.FOREIGN_GUN_MOD_IDS` and Core's `mod.info` `incompatible=`. Brita, both Arsenal[26] ids and Ammocraft are confirmed; `VFExpansion1`, `firearmmod` and `Guns93` are guesses. Also check that `mod.info` accepts the `(`, `)` and `[` `]` in the Arsenal ids.
11. **Reload types** for the new archetypes: `revolver`, and `boltactionnomag` for lever actions (vanilla has no lever reload).
12. **Vanilla gun and magazine ids** used by `replaces` and `ZGB_Distributions.VANILLA_MAGAZINES` (`Pistol2`, `Pistol3`, `Revolver_Short`, `M14Clip`, `44Clip`...).
13. **Animation (v0.5):** the vanilla clip names in `ZGB_Def_IsoView.lua` (`Bob_IdleRifle`, `Bob_AimHandgun`...), the AnimSet node format and folder of the drafts in `docs/animsets/iso/` (move them into the Iso addon's `media/AnimSets/player/` once confirmed), and `setVariable` on the character.
14. **Events used by the addons:** `OnWeaponSwing` fires for ranged shots, `LevelPerk` arguments, `getTimestampMs`, `ZombRand`; timed-action fields `maxTime` and `start` on `ISInsertMagazine` / `ISReloadWeaponAction`.
15. **Case dropping:** `IsoGridSquare:AddWorldInventoryItem` and removing world items (`transmitRemoveItemFromSquare`, `removeFromWorld`).
16. **Sandbox and labels:** the `sandbox-options.txt` syntax (enum options included) and that each addon's `Sandbox_EN.txt` is merged with the others (B42 may expect JSON translations).
17. **Speech:** `IsoPlayer:Say` for callouts.
18. **Models (v0.6):** `.X` text format, axes, winding and `scale` (change `AXES` / `WINDING` / `SCALE` in `tools/gen_models.lua`), the model script syntax with `attachment` blocks, `WeaponSprite` / `WorldStaticModel` with the `ZGB.` prefix, and `Icon = ZGB_<Id>` resolving to `media/textures/Item_ZGB_<Id>.png`.
19. **Hand placement:** the gun origin is the top of the grip; if guns sit wrong in the hand, move the origin in the shapes (`ZGB_Def_Models.lua`).
20. **Attached parts:** `base:weaponpart` item fields (`PartType`, `MountOn` with the module prefix), the `ModelWeaponPart = <twin> <model> anchor <point>` order, `instanceItem`, `attachWeaponPart`, `HandWeapon:setWeaponSprite`, `IsoGameCharacter:resetEquippedHandsModels`.
21. **Attachment window preview:** `getTexture("media/textures/ZGB/Preview/<Id>.png")` and `ISUIElement:drawTextureScaled`.
22. **Real models (FBX):** that B42 loads `.fbx` static meshes from `models_X` with `mesh = <path without extension>`, the scale and axes. First test: the game applies the FBX node transform, so Blender's default x100 node scale made guns giant and its -90° node rotation turned barrels sideways. Now models are plain metres with node scale 1 (like BCGTools) and the meshes are turned so the barrel points along the game's +Y with +Z up, like vanilla guns (Glock muzzle at y = 0.144, vanilla M9 0.1443); attachment offsets follow (`AXES` in gen_models). Third test: real size looked too big next to vanilla, which draws guns at ~0.6 of their real length; models and points are now shrunk by `MF.GAME_SCALE` = 0.6. Still to see: the size next to vanilla guns (pose check reference shots), the gun points where the character aims, and a 4096 x 4096 texture (`ZGB_Atlas.png`).
23. **Sounds:** second in-game test: our shots and racks were silent with the scripts in `module ZGB`. Now in `module Base` like every vanilla sound script, and the self-test checks `GameSounds.isKnownSound` and the file each one plays. Still to hear: shot, rack, magazine and the suppressed shot.

## Roadmap

- [x] Spec-driven weapon factory and archetypes
- [x] Attachment rules engine with mount chains and the Gunsmith window
- [x] Multiple magazines per gun
- [x] Ammo variants, Load all / Unload all magazines
- [x] Loot distribution
- [x] Isometric view addon
- [x] 70-gun catalogue, three magazine tiers, shared magazines, caliber-scaled stats (v0.4)
- [x] Block foreign gun / reload frameworks (v0.4)
- [x] Essential addons: Reloading and Tactical Holding; optional Callouts (v0.5)
- [x] Animation factory with the isometric view, case dropping, spray patterns per gun (v0.5)
- [x] Runs on the Gunworks Framework: reloading, magazine profiles, mixed rounds, fire modes, bursts (v0.8)
- [x] Placeholder models for every gun, attachment, magazine and casing; model variants; attachment window preview; idle/aim AnimSets shipped (v0.6)
- [ ] Confirm models, animations and the fire-kick AnimSets in game; real models and clips from the 3D side
- [ ] First in-game test and the VERIFY list
- [ ] Grenades (the callouts are already waiting for `grenade.throw`)
- [ ] Speedloaders and stripper clips for revolvers and internal-box rifles (Gunworks SpeedLoader)
- [ ] Folding stocks and bipods as Gunworks pairs; loose stocks, grips and parts in loot
- [ ] Addon API docs (calibers, magazines, parts, guns, ammo effects)
- [ ] Weapon light behaviour
- [ ] Converting vanilla guns in existing saves; code-spawned guns (zombie holsters)
- [ ] Translations
- [ ] Multiplayer sync
- [ ] AP armor penetration and tracer visuals (the traits are data only today); mixed loads are Gunworks' since v0.8
- [ ] **First Person addon** — reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`, which are already in the data

## Notes for the 3D side

- Start with [`docs/MODELS.md`](docs/MODELS.md): folder layout, coordinates,
  attachment points and how to replace a placeholder.
- The model list (every gun, magazine and attachment, with ids, magazine sizes
  and which attachments need a mount first) is in `docs/catalogue.json`.
- The mounts / handguards question is settled: the gun switches to a **model
  variant** with those parts built in (see [3D models](#3d-models)).
- Each optic has an `fp.sightAlignment` (eye offset + zoom) — fill it per model so ADS lines up.

## Team

Two people: one on code (Lua now, Java later), one on 3D models.
Issues and pull requests are welcome.

## License

[CC0 1.0 Universal](LICENSE) — public domain. Use it however you like.
