# ZE Guns Of Bohemia

*Idk, Guns and a lot of messing around.*

A firearms mod for **Project Zomboid Build 42** that works the same in isometric
and first person — without the animation overlap, flicker and crashes you get
when you mix isometric gun packs with ZombieBuddy-based first-person (viewpoint / ADS) mods.

![Build](https://img.shields.io/badge/Project%20Zomboid-Build%2042-8b0000)
![Version](https://img.shields.io/badge/version-0.3.0-blue)
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

## Features

- **Modular attachments with real mounting rules.** Slots accept specific
  interfaces (dovetail, picatinny, muzzle threads...). Parts can add new slots:
  an AK has no optic slot until you fit a side-rail mount. The game tells you
  what you're missing ("needs AK Side Rail Optic Mount").
- **Gunsmith window.** Right-click a gun → **Gunsmith...** for the full attachment
  tree, including "ghost" slots that appear once a mount is on, with ownership,
  install state and a stat preview for the selected part.
- **Multiple magazines per gun.** Standard, extended and drum mags, each with its
  own capacity and handling penalties that only apply while loaded. **R** picks
  the fullest carried magazine automatically.
- **Ammo variants per caliber.** FMJ, Hollow Point, +P, Armor Piercing, Tracer,
  Soft Point, Subsonic, High Velocity, and Buckshot / Birdshot / Slug for shotguns.
  Each changes damage, crits, noise or range.
- **Load all / Unload all magazines** in one menu click, topping off partly
  filled mags with the same ammo and never mixing types.
- **Stats recomputed from scratch** (base + parts + loaded magazine + loaded
  ammo), so attaching and detaching never drifts.
- **Vanilla-friendly.** Standard rounds of vanilla calibers reuse the vanilla
  items, so vanilla ammo boxes, crafting and other ammo mods keep working.
- **Loot integration.** Vanilla guns and magazines in loot tables are replaced
  by ours; variant ammo and extended mags spawn by rarity.

## What's in the box

**Guns**

| Gun | Family | Caliber | Feeds from |
|---|---|---|---|
| AK-47 | assault rifle | 7.62x39mm | 30rd mag, 75rd drum |
| Glock 17 | pistol | 9x19mm | 17rd mag, 33rd extended |
| Mossberg 590 | shotgun | 12 Gauge | 8-round tube |

**Attachments:** AK side-rail optic mount, AK quad-rail handguard, red dot sight,
4x combat scope, AK suppressor, AK compensator, vertical foregrip, weapon light,
AK folding stock, 2-point sling.

**Ammo by caliber** (first entry is the default round):

| Caliber | Variants |
|---|---|
| .22 LR | Round Nose, High Velocity, Hollow Point (weak), Subsonic |
| 9x19mm | FMJ, HP, +P, Subsonic, AP |
| .38 Special | FMJ, HP, +P |
| .45 ACP | FMJ, HP, +P (already subsonic, no AP) |
| .44 Magnum | FMJ, HP, Soft Point |
| 5.56x45mm | FMJ, AP, Tracer, Soft Point |
| .223 Rem | FMJ, HP, Soft Point |
| 7.62x39mm | FMJ, AP, Tracer, HP, Soft Point |
| .308 Win | FMJ, AP, Tracer, Soft Point |
| 12 Gauge | 00 Buckshot, Birdshot, Slug (1 projectile, long range) |

## Installation

ZE Guns Of Bohemia isn't on the Steam Workshop yet. To run it locally:

1. Clone or download this repo into your Zomboid Workshop folder:
   ```
   %UserProfile%\Zomboid\Workshop\ZEGunsOfBohemia\
   ```
   The repo's `Contents/mods/...` layout is the Workshop format, so the game picks it up as-is.
2. In **Mods**, enable:
   - **ZE Guns Of Bohemia - Core** (always), and
   - **exactly one** view addon: **ZE Guns Of Bohemia - Isometric** for now.
3. Start a new game. Existing saves keep their vanilla guns (conversion isn't done yet).

## Compatibility

| Mod | Works with |
|---|---|
| Core + Isometric addon | vanilla isometric camera |
| Core + First Person addon *(planned)* | ZombieBuddy-based first-person / viewpoint mods |
| Isometric addon + ZombieBuddy / Viewpoint | **No** — blocked on purpose, that's the overlap this mod fixes |
| Other ammo mods | Yes for standard rounds of vanilla calibers (we reuse the vanilla items) |
| Other mods wrapping vanilla reload functions | Yes — our wrappers always call the original and install once |

Multiplayer isn't supported yet: inventory changes are single-player correct
but don't send the B42 sync calls.

## How it works

```
Contents/mods/
  ZEGunsOfBohemiaCore/   logic, items, UI, loot. No animations, no Java. Always enabled.
  ZEGunsOfBohemiaIso/    isometric view addon (pure Lua). Registers provider "iso".
  ZEGunsOfBohemiaFP/     (planned) first-person addon, requires ZombieBuddy. Provider "fp".
tests/                   offline tests (Lua 5.1) with a fake inventory
tools/gen_scripts.lua    regenerates part and ammo item scripts from the Lua catalogs
```

Each mod folder follows the B42 layout: `42/` (mod.info + media) and `common/`.

| File | Job | Touches game API? |
|---|---|---|
| `Factory/ZGB_Archetypes` | defaults per family (pistol, smg, assault_rifle, shotgun, bolt_rifle) | no |
| `Factory/ZGB_WeaponFactory` | `define{}` → validated spec. `MaxAmmo` comes from `magazine.capacity` | no |
| `Factory/ZGB_PartFactory` | `define{}` for attachments: `kind`, `interface`, `provides`, `mods` | no |
| `Factory/ZGB_AmmoCatalog` | ammo variant effects × which variants exist per caliber | no |
| `ZGB_Attachments` | rules engine: canAttach / canDetach / requirement chains / UI tree | no |
| `ZGB_Stats` | final stats = base + parts + magazine + ammo (add → mul → set → clamp) | no |
| `ZGB_Magazines`, `ZGB_Ammo` | magazine choice and the load-all planner | no |
| `ZGB_Mode` | view-provider gate (only one owner of animations) | `getActivatedMods` |
| `ZGB_ScriptApply` | at boot, writes every spec into the item scripts | yes |
| `ZGB_ItemBridge` | the **only** place that calls live item / weapon methods | yes |
| `ZGB_Service`, `ZGB_PartActions`, `ZGB_MagazineActions`, `ZGB_AmmoActions` | timed actions | yes |
| `client/.../ZGB_ReloadHooks` | wraps vanilla reload / insert / eject | yes |
| `client/.../ZGB_GunsmithWindow` | attachment UI | yes |
| `server/.../ZGB_Distributions` | swaps vanilla guns for ours in loot, adds variants | yes |
| `ZGBIso/ZGB_ViewIso` | archetype → isometric animation set | no |

Files marked "no" never touch the game API, which is what lets them run in the offline tests.

### Attachments: how "a red dot needs a mount on an AK" works

Nothing is special-cased. Slots have a `kind` and accepted `interfaces`; parts
have a `kind`, an `interface`, and may `provide` new slots.

- The AK-47's `side_mount` slot accepts `ak_dovetail` — there is **no** optic slot.
- `Mount_AK_SideRail` (interface `ak_dovetail`) provides `optic_rail`, which accepts `picatinny`.
- `Optic_RedDot` is `picatinny`, so `canAttach` returns `needs {Mount_AK_SideRail}`.
- The Glock 17 has an `under_rail` directly, so a light goes straight on; the AK needs the quad-rail handguard first.
- Removing a mount with an optic still on it is blocked ("remove Red Dot first").

### Magazines

`magazine` is the default and `altMagazines` lists the rest. Each has its own
`capacity` and optional `mods` that apply **only while it's loaded** (the AK drum
adds weight, aim time and reload time).

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

1. In `Defs/ZGB_Def_Weapons.lua`, add a
   `ZGB.WeaponFactory.define{ id, archetype, displayName, caliber, magazine = { item, capacity }, slots = { ... } }`.
   Anything you leave out comes from the archetype.
2. In `media/scripts/ZGB_items_weapons.txt`, add a skeleton `item <id>`
   (identity + model only) and its magazine item.
3. That's it. Stats, capacity, sounds and animations come from the spec at boot.

> [!IMPORTANT]
> Never put `MaxAmmo`, `AmmoType` or animations in an item script by hand. The spec overwrites them.

New attachments go in `Defs/ZGB_Def_Parts.lua`, new ammo in
`Factory/ZGB_AmmoCatalog.lua`. After editing either one, regenerate the item
scripts (`*_parts.txt` and `*_ammo.txt` are generated files).

## Development

Requires **Lua 5.1** (Project Zomboid's Kahlua is roughly 5.1: no `goto`, no `//`, no `utf8`).

```bash
lua5.1 tests/run_tests.lua      # 55 tests: factory, rules, chains, stats, magazines, ammo, load-all planner, loot, mode gate
```

```bash
lua5.1 tools/gen_scripts.lua    # after editing ZGB_Def_Parts.lua or ZGB_AmmoCatalog.lua
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

## Roadmap

- [x] Spec-driven weapon factory and archetypes
- [x] Attachment rules engine with mount chains and the Gunsmith window
- [x] Multiple magazines per gun
- [x] Ammo variants, Load all / Unload all magazines
- [x] Loot distribution
- [x] Isometric view addon
- [ ] First in-game test and the VERIFY list
- [ ] Fire-mode switching
- [ ] Weapon light behaviour
- [ ] Converting vanilla guns in existing saves; code-spawned guns (zombie holsters)
- [ ] Translations
- [ ] Multiplayer sync
- [ ] AP armor penetration and tracer visuals (the traits are data only today); mixed magazine loads
- [ ] **First Person addon** — reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`, which are already in the data

## Notes for the 3D side

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
