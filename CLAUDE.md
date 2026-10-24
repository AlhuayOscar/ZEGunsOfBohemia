# ZE Guns Of Bohemia — context for Claude Code

Project Zomboid Build 42 firearms mod. Two devs: one does code (Lua now, Java later), one does 3D models. Goal: a gun mod that works in isometric and first person without the animation overlap / crashes seen when mixing iso gun packs with the ZombieBuddy-based first-person (viewpoint/ADS) mods.

## Golden rules (don't break these)

1. **One spec per gun is the single source of truth.** Ammo, capacity, stats, sounds, attachments and animation set come from `ZGB.WeaponFactory.define{}`. Item `.txt` scripts are skeletons (identity + model); `ZGB_ScriptApply` writes the numbers at boot. Never put `MaxAmmo`, `AmmoType` or anims in a script by hand.
2. **Only one view provider owns animations.** `ZGB.Mode.registerProvider` refuses a second one; `mod.info` `incompatible=` blocks Iso + FP loading together. Keep both guards.
3. **All live game-object calls go through `ZGB_ItemBridge.lua`** (plus the timed actions and UI). Logic files (`Factory/*`, `ZGB_Attachments`, `ZGB_Stats`, `ZGB_Magazines`, `ZGB_Ammo`, `ZGB_AmmoCatalog`) must stay free of game API so they run in the tests.
4. **Game-API calls not yet confirmed on a real install are marked `-- VERIFY` and wrapped in `pcall`**: a wrong name logs a warning and disables that feature, it never crashes. When one is confirmed in game, remove its `VERIFY` tag.
5. **Stats are recomputed from scratch** (base + parts + loaded magazine + loaded ammo; add → mul → set → clamp). Never apply deltas to current values.
6. **Wrappers around vanilla functions (`ZGB_ReloadHooks`) always call the original and are installed once** — other mods may wrap the same functions.

## Layout

```
Contents/mods/ZEGunsOfBohemiaCore/42/   logic, items, UI, loot (no anims, no Java)
  media/lua/shared/ZGB/Factory/          Archetypes, WeaponFactory, PartFactory, AmmoCatalog
  media/lua/shared/ZGB/Defs/             the catalogue: ZGB_Def_Weapons, ZGB_Def_Parts
  media/lua/shared/ZGB/                  rules, stats, magazines, ammo planner, bridge, actions
  media/lua/client/ZGB/                  context menus, reload hooks, UI/ZGB_GunsmithWindow
  media/lua/server/ZGB/                  ZGB_Distributions (loot)
  media/scripts/                         item skeletons; *_parts.txt and *_ammo.txt are GENERATED
Contents/mods/ZEGunsOfBohemiaIso/42/    iso view provider (archetype -> vanilla anim set)
Contents/mods/ZEGunsOfBohemiaFP/        (future) first-person provider, needs ZombieBuddy
tests/run_tests.lua, tests/mock_game.lua  offline tests (Lua 5.1)
tools/gen_scripts.lua                     regenerates parts/ammo item scripts
```

B42 layout: every mod folder needs both `42/` (mod.info + media) and `common/`. Code prefix is `ZGB` (global table `ZGB`, item module `ZGB`, files `ZGB_*.lua`).

## Commands

```
lua5.1 tests/run_tests.lua     # must stay green (55 tests at v0.3.0)
lua5.1 tools/gen_scripts.lua   # after editing ZGB_Def_Parts.lua or ZGB_AmmoCatalog.lua
```

Kahlua (PZ's Lua) is roughly Lua 5.1: no `goto`, no integer division `//`, no `utf8` lib.

## Systems at a glance

- **Attachments:** slots have `kind` + accepted `interfaces`; parts have `kind`, `interface`, and may `provide` new slots (AK side mount → optic rail). `ZGB.Attachments.canAttach` returns `needs` with the chain of parts required. UI shows "ghost" slots.
- **Magazines:** `magazine` (default) + `altMagazines`, each with capacity and optional mods while loaded. Vanilla supports one `MagazineType`, so we retarget it right before insert.
- **Ammo:** `ZGB_AmmoCatalog` = variant effects (FMJ/HP/+P/AP/Tracer/SP/Subsonic/HV, buck/bird/slug) × which variants exist per caliber. Standard rounds of vanilla calibers reuse vanilla items. A magazine's variant is its `AmmoType`. "Load all / Unload all magazines" live in core (`ZGB_AmmoActions`, planner in `ZGB_Ammo`).
- **Loot:** `ZGB_Distributions` replaces vanilla guns/mags and adds variants by rarity.

## Status / next steps

- Not yet run in game: work through the VERIFY list in README.md on the first test.
- Mod IDs of ZombieBuddy / viewpoint mod in `ZGB_Mode.FP_MOD_IDS` and Iso `mod.info` are guesses.
- Todo: fire-mode switching, weapon light, converting vanilla guns in existing saves, translations, MP sync (send* calls), armor/tracer effects for AP/tracer traits.
- Later: the FP addon reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`.
- Open 3D decision: vanilla can't render mounts/handguards (only 6 part types) — bake mount into optic models, or swap the gun model variant when a mount is fitted.

## Working style

- The user writes in English or Portuguese; code, comments and commits are in English.
- Add a test for every pure-logic change; use `tests/mock_game.lua` for bridge/action code.
- Keep README.md in sync when a system changes.
