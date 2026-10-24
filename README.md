# ZE Guns Of Bohemia

*Idk, Guns and a lot of messing around.*

A firearms mod for **Project Zomboid Build 42** that works the same in isometric
and first person — without the animation overlap, flicker and crashes you get
when you mix isometric gun packs with ZombieBuddy-based first-person (viewpoint / ADS) mods.

![Build](https://img.shields.io/badge/Project%20Zomboid-Build%2042-8b0000)
![Version](https://img.shields.io/badge/version-0.5.0-blue)
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
- **Self-contained on purpose.** Reloading, magazines, ammo loading and (soon)
  tactical holding are built in, so you don't need other gun mods for the basics.
  In return, ZE Guns Of Bohemia is **not compatible** with other reloading mods
  or generic gun frameworks: two systems patching the same reload code is the
  kind of bug this mod exists to avoid. Extensions are welcome as addons built
  on our own API.

## Features

- **Modular attachments with real mounting rules.** Slots accept specific
  interfaces (dovetail, picatinny, muzzle threads...). Parts can add new slots:
  an AK has no optic slot until you fit a side-rail mount. The game tells you
  what you're missing ("needs AK Side Rail Optic Mount").
- **Gunsmith window.** Right-click a gun → **Gunsmith...** for the full attachment
  tree, including "ghost" slots that appear once a mount is on, with ownership,
  install state and a stat preview for the selected part.
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

70 guns, 65 magazines, 48 attachments and 32 calibers. The full catalogue with
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

ZE Guns Of Bohemia isn't on the Steam Workshop yet. To run it locally:

1. Clone or download this repo into your Zomboid Workshop folder:
   ```
   %UserProfile%\Zomboid\Workshop\ZEGunsOfBohemia\
   ```
   The repo's `Contents/mods/...` layout is the Workshop format, so the game picks it up as-is.
2. In **Mods**, enable:
   - **ZE Guns Of Bohemia - Core** (always),
   - the essential addons **ZE Guns Of Bohemia - Reloading** and **ZE Guns Of Bohemia - Tactical Holding**,
   - **exactly one** view addon: **ZE Guns Of Bohemia - Isometric** for now,
   - optionally **ZE Guns Of Bohemia - Callouts**.

   Core tells you on game start if a view addon or an essential addon is missing.
3. Start a new game. Existing saves keep their vanilla guns (conversion isn't done yet).

## Compatibility

| Mod | Works with |
|---|---|
| Core + Isometric addon | vanilla isometric camera |
| Core + First Person addon *(planned)* | ZombieBuddy-based first-person / viewpoint mods |
| Isometric addon + ZombieBuddy / Viewpoint | **No** — blocked on purpose, that's the overlap this mod fixes |
| Other gun packs, reloading mods, generic gun frameworks | **No** — blocked on purpose (see below) |
| Mods that only add vanilla-caliber ammo | Yes for standard rounds of vanilla calibers (we reuse the vanilla items) |
| Addons built on ZE Guns Of Bohemia's API | Yes — this is how to extend the mod |

**Why other gun mods are blocked.** This mod brings its own reloading,
magazine, ammo and (soon) tactical holding systems, so you don't need another
mod for the basics. Mods that rework guns or reloading in general patch the
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
  ZEGunsOfBohemiaReload/ essential: reloading system (reload kinds, timing, events)
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
| `ZGB_Magazines`, `ZGB_Ammo` | magazine choice and the load-all planner | no |
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
| Reload `client/ZGBReload/ZGB_ReloadHooks` | wraps vanilla reload / insert / eject, emits `reload.*` | yes |
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
  AnimSet nodes as **drafts** in `docs/animsets/iso/` (132 nodes). They are not
  loaded by the game until the node format is confirmed in game (VERIFY list).
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

### Reloading (essential addon)

- **Tactical reload** with rounds left keeps the chambered round (+1) on
  closed-bolt guns. **Empty reloads** drop the magazine and release the slide
  or bolt, and take longer. Open-bolt guns (Uzi, MAC-10, Thompson, PPSh-41,
  AA-12), revolvers and break-actions have no +1.
- Guns without magazines reload the way they're built: one round at a time
  into tubes and internal boxes, dump-and-reload for swing-out revolvers, one
  chamber at a time through a loading gate, open-extract-load for break-actions.
- Time = the anim type's clip timings × magazine tier (drums are slower) ×
  Reloading skill × sandbox **Reload speed**.
- Emits `reload.start`, `reload.step` (each clip as it plays), `reload.complete`
  and `ammo.lastMag` when no loaded spare magazine is left.

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

Requires **Lua 5.1** (Project Zomboid's Kahlua is roughly 5.1: no `goto`, no `//`, no `utf8`).
On Windows, `winget install DEVCOM.LuaJIT` works: run the same commands with `luajit`.
LuaJIT accepts `goto`, so don't rely on it to catch that one.

```bash
lua5.1 tests/run_tests.lua      # 103 tests: catalogue, magazines, attachments, stats, ammo, loot, mod gates, animation factory, recoil, casings, the three addons, and the addon clients against a stub game
```

```bash
lua5.1 tools/gen_scripts.lua    # after editing anything in Defs/ or ZGB_AmmoCatalog.lua
```

```bash
lua5.1 tools/gen_catalog.lua    # refresh docs/catalogue.json
```

```bash
lua5.1 tools/gen_animsets.lua   # refresh the draft iso AnimSet nodes in docs/animsets/iso/
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
3. **`AmmoType` format** — B42 may expect a registry-style id; check a vanilla gun.
4. **HandWeapon setter names** in `ZGB_ItemBridge.SETTERS` (failures are logged once, never crash).
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
- [ ] Confirm the iso AnimSet drafts in game and ship them; real clips once models exist
- [ ] First in-game test and the VERIFY list
- [ ] Grenades (the callouts are already waiting for `grenade.throw`)
- [ ] Speedloaders and stripper clips for revolvers and internal-box rifles
- [ ] Addon API docs (calibers, magazines, parts, guns, ammo effects)
- [ ] Fire-mode switching
- [ ] Weapon light behaviour
- [ ] Converting vanilla guns in existing saves; code-spawned guns (zombie holsters)
- [ ] Translations
- [ ] Multiplayer sync
- [ ] AP armor penetration and tracer visuals (the traits are data only today); mixed magazine loads
- [ ] **First Person addon** — reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`, which are already in the data

## Notes for the 3D side

- The model list (every gun, magazine and attachment, with ids, magazine sizes
  and which attachments need a mount first) is in `docs/catalogue.json`,
  regenerated with `tools/gen_catalog.lua`. Name each model `ZGB_<id>`.
- Vanilla can render parts in only 6 types (Scope, Clip, Sling, Canon, Stock, RecoilPad).
  Parts with `vanillaPartType` are mirrored into vanilla purely so their model shows;
  stats always come from our Lua.
- **Mounts and handguards have no vanilla part type.** Open decision: bake the mount
  into the optic model (one model per optic + mount combo), or swap the gun's model
  variant when a mount is fitted. Worth settling before modelling optics.
- Each optic has an `fp.sightAlignment` (eye offset + zoom) — fill it per model so ADS lines up.

## Team

Two people: one on code (Lua now, Java later), one on 3D models.
Issues and pull requests are welcome.

## License

[CC0 1.0 Universal](LICENSE) — public domain. Use it however you like.
