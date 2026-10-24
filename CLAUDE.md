# ZE Guns Of Bohemia — context for Claude Code

Project Zomboid Build 42 firearms mod. Two devs: one does code (Lua now, Java later), one does 3D models. Goal: a gun mod that works in isometric and first person without the animation overlap / crashes seen when mixing iso gun packs with the ZombieBuddy-based first-person (viewpoint/ADS) mods.

## Golden rules (don't break these)

1. **One spec per gun is the single source of truth.** Ammo, capacity, stats, sounds, attachments and animation set come from `ZGB.WeaponFactory.define{}`. Magazines are their own catalogue (`ZGB.MagazineFactory.define{}`): capacity, caliber and tier live there. Item `.txt` scripts are GENERATED skeletons (identity + model, `tools/gen_scripts.lua`); `ZGB_ScriptApply` writes the numbers at boot. Never put `MaxAmmo`, `AmmoType` or anims in a script by hand, and never hand-edit `ZGB_items_*.txt`.
2. **Only one view provider owns animations.** `ZGB.Mode.registerProvider` refuses a second one; `mod.info` `incompatible=` blocks Iso + FP loading together. Keep both guards.
3. **All live game-object calls go through `ZGB_ItemBridge.lua`** (plus the timed actions and UI). Logic files (`Factory/*`, `Defs/*`, `ZGB_Attachments`, `ZGB_Stats`, `ZGB_Magazines`, `ZGB_Ammo`, `ZGB_AmmoCatalog`) must stay free of game API so they run in the tests.
4. **Game-API calls not yet confirmed on a real install are marked `-- VERIFY` and wrapped in `pcall`**: a wrong name logs a warning and disables that feature, it never crashes. When one is confirmed in game, remove its `VERIFY` tag.
5. **Stats are recomputed from scratch** (base + parts + loaded magazine + loaded ammo; add → mul → set → clamp). Never apply deltas to current values.
6. **We own the gun basics; foreign gun/reload frameworks are blocked.** Reloading, magazines, ammo loading and (planned) tactical holding are ours. Other gun packs, reload mods and generic gun frameworks are listed in `ZGB_Mode.FOREIGN_GUN_MOD_IDS` AND Core `mod.info` `incompatible=` (a test keeps them in sync). If one is active, `ZGB.Mode.isBlocked()` is true and hooks, menus and loot do nothing. New features come in as addons on our factories, never by tolerating another framework.
7. **Wrappers around vanilla functions (`ZGB_ReloadHooks`, now in the Reloading addon) always call the original and are installed once.**
9. **Systems talk through `ZGB.Events`, never by calling each other.** Core emits weapon.* / ammo.*, Reloading emits reload.*, Holding emits hold.changed; views and Callouts only listen. Every new behaviour is data in a factory (`AnimFactory.defineType/defineView`, `RecoilFactory.defineProfile`, `Holding.defineStance`, `Calls.defineCall`), not a special case.
10. **Views are applications of the animation factory.** Anim types (Core `Defs/ZGB_Def_Anims.lua`) are camera-independent; a view (`iso` in the Iso addon, later `fp`) maps every abstract clip. Never put camera-specific data in an anim type, and keep every clip mapped (a test checks `missingClips`).
8. **Magazine rules:** tiers are only `standard`, `extended`, `drum`; at most one per tier per gun, and only tiers that exist for that gun in real life. A magazine has ONE caliber and holds only that caliber's catalog loads. Internal-fed guns (revolvers, tubes, internal boxes) use `internalCapacity` and take no magazines.

## Layout

```
Contents/mods/ZEGunsOfBohemiaCore/42/   logic, items, UI, loot (no anims, no Java)
  media/lua/shared/ZGB/Factory/          Archetypes, WeaponFactory, MagazineFactory, PartFactory, AmmoCatalog
  media/lua/shared/ZGB/Defs/             the catalogue: ZGB_Def_Weapons (70 guns), ZGB_Def_Magazines, ZGB_Def_Parts
  media/lua/shared/ZGB/                  rules, stats, magazines, ammo planner, mode gates, bridge, actions
  media/lua/client/ZGB/                  context menus, reload hooks, UI/ZGB_GunsmithWindow
  media/lua/server/ZGB/                  ZGB_Distributions (loot)
  media/scripts/                         item skeletons, ALL generated (weapons, magazines, parts, ammo)
Contents/mods/ZEGunsOfBohemiaIso/42/    view "iso": clip map + stance variants, anim variables, burst recoil, case dropping
Contents/mods/ZEGunsOfBohemiaReload/42/ ESSENTIAL addon: reload rules (ZGB_Reload) + vanilla reload hooks
Contents/mods/ZEGunsOfBohemiaHolding/42/ ESSENTIAL addon: stance by Aiming level + sandbox options
Contents/mods/ZEGunsOfBohemiaCalls/42/  optional addon: callouts
Contents/mods/ZEGunsOfBohemiaFP/        (future) first-person provider, needs ZombieBuddy (see docs/FIRST_PERSON.md)
docs/                                     catalogue.json, animsets/iso drafts (NOT loaded by the game), FIRST_PERSON.md
tests/run_tests.lua, tests/mock_game.lua  offline tests (Lua 5.1)
tools/gen_scripts.lua                     regenerates every item script from the catalogue
tools/gen_catalog.lua                     dumps the catalogue to docs/catalogue.json (3D model list)
```

B42 layout: every mod folder needs both `42/` (mod.info + media) and `common/`. Code prefix is `ZGB` (global table `ZGB`, item module `ZGB`, files `ZGB_*.lua`).

## Commands

```
lua5.1 tests/run_tests.lua     # must stay green (103 tests at v0.5.0)
lua5.1 tools/gen_scripts.lua   # after editing anything in Defs/ or ZGB_AmmoCatalog.lua
lua5.1 tools/gen_catalog.lua   # then refresh docs/catalogue.json
lua5.1 tools/gen_animsets.lua  # after editing anim types, the iso view or stances
```

Kahlua (PZ's Lua) is roughly Lua 5.1: no `goto`, no integer division `//`, no `utf8` lib. This Windows machine has no `lua5.1`: use LuaJIT at `%LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe`. LuaJIT accepts `goto`, so grep for it separately.

## Systems at a glance

- **Guns:** `magazines = { standard=, extended=, drum= }` (ids from `ZGB_Def_Magazines`) or `internalCapacity`. Damage / range / recoil / noise scale from the caliber's `energy` vs the archetype's `refCaliber`, unless the def sets them. `category` groups the catalogue; `replaces` / `rarity` drive loot.
- **Magazines:** first-class items, shared between guns where real (STANAG, Glock). Tier penalties (`MagazineFactory.TIERS`) apply only while loaded. Vanilla supports one `MagazineType`, so we retarget it right before insert.
- **Attachments:** slots have `kind` + accepted `interfaces`; parts have `kind`, `interface`, and may `provide` new slots (AK side mount → optic rail, HK 3-lug adapter → muzzle thread). `ZGB.Attachments.canAttach` returns `needs` with the chain of parts required. UI shows "ghost" slots. Tests require every slot to have a fitting part and every part to fit some gun.
- **Ammo:** `ZGB_AmmoCatalog` = variant effects (FMJ/HP/+P/AP/Tracer/SP/Subsonic/HV/Match/Wadcutter, buck/bird/slug/flechette) × which variants exist per caliber (32 calibers). Standard rounds of vanilla calibers reuse vanilla items. A magazine's variant is its `AmmoType`. "Load all / Unload all magazines" live in core (`ZGB_AmmoActions`, planner in `ZGB_Ammo`).
- **Loot:** `ZGB_Distributions` is data-driven: `replaces` swaps vanilla guns, other guns spawn next to their family anchor (`FAMILY_ANCHORS`) at `rarity`, magazines next to their gun by tier, ammo variants next to standard rounds (`AMMO_ANCHORS` for non-vanilla calibers).

## Status / next steps

- Not yet run in game: work through the VERIFY list in README.md on the first test.
- Mod IDs of ZombieBuddy / viewpoint mod in `ZGB_Mode.FP_MOD_IDS` and Iso `mod.info` are guesses; so are `VFExpansion1`, `firearmmod` and `Guns93` in `FOREIGN_GUN_MOD_IDS`.
- v0.5 systems (animation factory, iso view, recoil, casings, reloading, holding, callouts) are unverified in game; their game calls are VERIFY items 13-17 in README. The iso AnimSet nodes are drafts in docs/animsets/iso until the node format is confirmed.
- Next systems: grenades (callouts already listen for `grenade.throw`); speedloaders / stripper clips; FP view; addon API docs.
- Todo: fire-mode switching, weapon light, converting vanilla guns in existing saves, translations, MP sync (send* calls), armor/tracer effects for AP/tracer traits.
- Later: the FP addon reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`.
- Open 3D decision: vanilla can't render mounts/handguards (only 6 part types) — bake mount into optic models, or swap the gun model variant when a mount is fitted.

## Working style

- The user writes in English or Portuguese; code, comments and commits are in English.
- Add a test for every pure-logic change; use `tests/mock_game.lua` for bridge/action code.
- Keep README.md in sync when a system changes.
