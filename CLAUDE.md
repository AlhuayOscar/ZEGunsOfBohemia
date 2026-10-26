# ZE Guns Of Bohemia — context for Claude Code

Project Zomboid Build 42 firearms mod. Two devs: one does code (Lua now, Java later), one does 3D models. Goal: a gun mod that works in isometric and first person without the animation overlap / crashes seen when mixing iso gun packs with the ZombieBuddy-based first-person (viewpoint/ADS) mods.

## Golden rules (don't break these)

1. **One spec per gun is the single source of truth.** Ammo, capacity, stats, sounds, attachments and animation set come from `ZGB.WeaponFactory.define{}`. Magazines are their own catalogue (`ZGB.MagazineFactory.define{}`): capacity, caliber and tier live there. Item `.txt` scripts are GENERATED skeletons (identity + model, `tools/gen_scripts.lua`); `ZGB_ScriptApply` writes the numbers at boot. Never put `MaxAmmo`, `AmmoType` or anims in a script by hand, and never hand-edit `ZGB_items_*.txt`.
2. **Only one view provider owns animations.** `ZGB.Mode.registerProvider` refuses a second one; `mod.info` `incompatible=` blocks Iso + FP loading together. Keep both guards.
3. **All live game-object calls go through `ZGB_ItemBridge.lua`** (plus the timed actions and UI). Logic files (`Factory/*`, `Defs/*`, `ZGB_Attachments`, `ZGB_Stats`, `ZGB_Magazines`, `ZGB_Ammo`, `ZGB_AmmoCatalog`) must stay free of game API so they run in the tests.
4. **Game-API calls not yet confirmed on a real install are marked `-- VERIFY` and wrapped in `pcall`**: a wrong name logs a warning and disables that feature, it never crashes. When one is confirmed in game, remove its `VERIFY` tag.
5. **Stats are recomputed from scratch** (base + parts + loaded magazine + loaded ammo; add → mul → set → clamp). Never apply deltas to current values.
6. **The mod runs on Gunworks (SWMG, Workshop 3722064198); other gun frameworks are blocked.** Core `mod.info` has `require=\SWMG`. Gunworks does reloading (best magazine, mixed rounds, speedloaders), fire modes / rate of fire / bursts and the stat layers; the catalogue stays ours and is handed to it by `ZGB_Gunworks` (data from the pure `ZGB_GunworksPlan`: ammo family per caliber, magazine profile per gun, rate of fire, our stat layer). Never re-implement what Gunworks does, never write a gun's stats behind its back: `ZGB.Item.applyStats` calls `StatsFactory.ReapplyAllModifiers` and our numbers are the "ZGB" layer (Adjust from the spec base, so they compose with Gunworks' own layers). Other gun packs, reload mods and generic frameworks are listed in `ZGB_Mode.FOREIGN_GUN_MOD_IDS` AND Core `mod.info` `incompatible=` (a test keeps them in sync); if one is active, `ZGB.Mode.isBlocked()` is true and hooks, menus and loot do nothing.
7. **Wrappers around vanilla functions (`ZGB_ReloadHooks` in the optional Reload events addon) always call the original, are installed once, and only observe:** Gunworks wraps the same reload actions, so ours never change what they do.
9. **Systems talk through `ZGB.Events`, never by calling each other.** Core emits weapon.* / ammo.*, Reloading emits reload.*, Holding emits hold.changed; views and Callouts only listen. Every new behaviour is data in a factory (`AnimFactory.defineType/defineView`, `RecoilFactory.defineProfile`, `Holding.defineStance`, `Calls.defineCall`), not a special case.
10. **Views are applications of the animation factory.** Anim types (Core `Defs/ZGB_Def_Anims.lua`) are camera-independent; a view (`iso` in the Iso addon, later `fp`) maps every abstract clip. Never put camera-specific data in an anim type, and keep every clip mapped (a test checks `missingClips`).
11. **Models are data too.** Placeholder geometry, attachment points and per-gun sizes live in `Defs/ZGB_Def_Models.lua` (ModelFactory). `ZGB_Visuals` decides per part: "rendered" (vanilla draws it via a `Vis_<Id>` twin on a channel point) or "baked" (into a gun model variant). Never hand-edit `models_X/ZGB/`, `textures/ZGB/`, `Item_ZGB_*.png`, `ZGB_models.txt`, `ZGB_Def_RealModels.lua` or `CREDITS.txt`: the generators wipe and rewrite them. Every new part needs a model (or `noModel = true`); tests fail otherwise.
12. **Real models only from free licenses, always credited.** `tools/model_sources.lua` is the single list of downloaded models (pack, author, license, url, per-model `fix`). Only CC0 / CC-BY (credit required) sources; never Sketchfab/marketplace models with NC/ND or unknown licenses. Raw downloads stay in `.cache/model_sources/` (git-ignored); only converted models ship. After changing a source or fix, re-render `--review` and look at it before committing.
8. **Magazine rules:** tiers are only `standard`, `extended`, `drum`; at most one per tier per gun, and only tiers that exist for that gun in real life. A magazine has ONE caliber and holds only that caliber's catalog loads. Internal-fed guns (revolvers, tubes, internal boxes) use `internalCapacity` and take no magazines.

## Layout

```
Contents/mods/ZEGunsOfBohemiaCore/42/   logic, items, UI, loot (no anims, no Java)
  media/lua/shared/ZGB/Factory/          Archetypes, WeaponFactory, MagazineFactory, PartFactory, AmmoCatalog
  media/lua/shared/ZGB/Defs/             the catalogue: ZGB_Def_Weapons (76 guns), ZGB_Def_Magazines, ZGB_Def_Parts
  media/lua/shared/ZGB/                  rules, stats, magazines, ammo planner, mode gates, bridge, actions, ZGB_Gunworks(+Plan)
  media/lua/client/ZGB/                  context menus, reload hooks, UI/ZGB_GunsmithWindow (full-screen inspect layout: ZGB_InspectLayout)
  media/lua/server/ZGB/                  ZGB_Distributions (loot)
  media/scripts/                         item skeletons, ALL generated (weapons, magazines, parts, ammo)
Contents/mods/ZEGunsOfBohemiaIso/42/    view "iso": clip map + stance variants, anim variables, burst recoil, case dropping
Contents/mods/ZEGunsOfBohemiaReload/42/ optional addon: reload events (ZGB_Reload plans kind/timing; hooks only observe Gunworks' reloads)
Contents/mods/ZEGunsOfBohemiaHolding/42/ ESSENTIAL addon: stance by Aiming level + sandbox options
Contents/mods/ZEGunsOfBohemiaCalls/42/  optional addon: callouts
Contents/mods/ZEGunsOfBohemiaFP/        (future) first-person provider, needs ZombieBuddy (see docs/FIRST_PERSON.md)
  Core media/models_X/ZGB/                 GENERATED placeholder models, one folder per item (Guns/<Cat>/<Id>/, Attachments/<Type>/<Id>/, Magazines/, Casings/)
  docs/animsets/iso/{idle,aim,fire}/      GENERATED AnimSet node drafts (not shipped: see Kahlua notes)
docs/                                     catalogue.json, animsets/iso/fire drafts, FIRST_PERSON.md, MODELS.md (3D artist guide)
tools/gen_models.lua, tools/lib/zgb_image.lua  models, icons, preview sprites, model scripts (PNG writer + side-view rasterizer)
tests/run_tests.lua, tests/mock_game.lua  offline tests (Lua 5.1)
tools/gen_scripts.lua                     regenerates every item script from the catalogue
tools/gen_catalog.lua                     dumps the catalogue to docs/catalogue.json (3D model list)
```

B42 layout: every mod folder needs both `42/` (mod.info + media) and `common/`. Code prefix is `ZGB` (global table `ZGB`, item module `ZGB`, files `ZGB_*.lua`).

## Commands

```
lua5.1 tests/run_tests.lua     # must stay green (136 tests)
powershell -ExecutionPolicy Bypass -File tools/pzserver/run_test.ps1   # REAL game, headless: dedicated server (C:/Users/ROG/pzserver, app 380870) on a scratch profile runs the self-test; report in .cache/pzserver/ZGB_selftest.txt. Mods are copied in (through junctions the server lost the AnimSet paths and aborted). Run it after every change that touches items, scripts or game-facing Lua.
lua5.1 tools/validate_mod.lua  # offline check of the whole mod as the game reads it (scripts, files, Lua, XML, Workshop)
lua5.1 tools/gen_pz_api.lua    # index of the installed game's method names (.cache/pz_api); validate_mod then rejects unknown game calls
lua5.1 tools/gen_vanilla_guns.lua  # copies the vanilla template guns' fields into tools/data/vanilla_guns.lua (after a game update)
lua5.1 tools/preview_gunsmith.lua [Gun] [slot] [part]   # PNG of the Gunsmith screen from the real UI code, offline (.cache/gunsmith_<Gun>.png)
lua5.1 tools/gen_models.lua    # after editing models, parts or guns (before gen_scripts; tests read its output)
blender -b -P tools/blender/import_models.py [-- --review out.png]   # ALWAYS after gen_models: real models, atlas, their icons/previews
lua5.1 tools/gen_model_list.lua   # docs/MODEL_LIST.txt (pt-BR list for the 3D side)
lua5.1 tools/gen_scripts.lua   # after editing anything in Defs/ or ZGB_AmmoCatalog.lua
lua5.1 tools/gen_catalog.lua   # then refresh docs/catalogue.json
lua5.1 tools/gen_animsets.lua  # after editing anim types, the iso view or stances
lua5.1 tools/gen_sounds.lua    # after editing Defs/ZGB_Def_Sounds.lua (needs ffmpeg + .cache/sound_sources)
blender -b -P tools/blender/check_models.py   # contact sheets of the exported FBX in .cache/check/ (each with its own texture)
"<blender>/5.2/python/bin/python.exe" -I tools/sketchfab/search.py [ids]   # CC0/CC-BY candidates per item + contact sheets (.cache/sketchfab/sheets)
"<blender>/5.2/python/bin/python.exe" -I tools/sketchfab/fetch.py [ids]    # downloads tools/sketchfab/picks.lua (needs SKETCHFAB_API_TOKEN, the USER's; never ask for it or print it), writes tools/sketchfab/credits.lua
blender -b -P tools/blender/make_art.py       # Workshop preview.png + each mod's poster.png
```

Kahlua (PZ's Lua) is roughly Lua 5.1: no `goto`, no integer division `//`, no `utf8` lib, and NO `next()` and no `package` table (use `ZGB.isEmpty` or `pairs`; the tests hide `next` and validate_mod rejects it). FBX models must be plain metres with node scale 1 (`global_scale=0.01` in the Blender export) and node rotation 0 (`bake_space_transform=True`: the game reads model-script attachment points in the file's raw space, so a -90 deg node put the muzzle flash above the head; validate_mod checks both): the game ignores the FBX unit but APPLIES the node transform, so Blender's default x100 node scale made every model giant (validate_mod checks it), and meshes are turned by `GAME_FRAME` so the barrel is the game's +Y and up +Z, like vanilla guns. Models are designed at real size and shrunk by `MF.GAME_SCALE` (0.6, what vanilla guns measure against their real length) in both the exported meshes and the model-script points; model scripts keep `scale = 1`. Two rigs (`MF.FRAMES`): long guns have the barrel up at +Z and their meshes are rolled 180 deg at export; one-handed guns use vanilla's upside-down pistol rig (points flipped, mesh not rolled; parts mounted on them get a 180 deg roll). Every gun model has a `muzzle` attachment with vanilla's rotation: without it the game would not fire ours (fourth in-game test). Ammo types are a B42 registry: scripts say `AmmoType = base:bullets_45` / `zgb:...` (generated `media/registries.lua`), runtime code goes through `ZGB.Item.ammoTypeOf` / `ammoTypeObject`, never `setAmmoType("<item>")`. Every ammo type must ALSO appear as `AmmoType = <id>` in a generated item skeleton (guns, magazines, rounds): the game creates an ammo type's bullet tracer config only while reading item scripts, from its own media/effects folder (mods can't add files there); one set later by DoParam had none and the first shot crashed the game (validate_mod checks it). Every gun copies the fields of its vanilla template gun (`vanillaGun` in Archetypes, data in tools/data/vanilla_guns.lua: fire timing, aim cone, chamber, muzzle flash, equip/aim/jam sounds, `base:firearm` tag) except what the factory owns; reload types are vanilla B42's (mag-fed rifles `boltaction`, levers `leveraction`). Sound scripts live in `module Base` (in module ZGB they played nothing). Gunshot sources are stereo recordings from two different mics: gen_sounds keeps one channel (averaging them cancelled out and sounded like suppressed + plain at once). No AnimSet nodes ship for now: `x_extends` looks for the parent in OUR mod folder, not the game's, so nodes extending vanilla failed to parse and the guns could not aim or fire (validate_mod rejects it); stance nodes stay drafts in docs/animsets/iso and must be self-contained before they ship. Never ship a node that replaces a vanilla pose. In debug mode the game stops in the debugger on every Lua error, even one caught by pcall: game-facing code nil-checks step by step instead of relying on pcall (a test runs the self-test like that). Use vanilla B42 files as the reference, not other gun mods. Whole-number item fields (`SA.INT_FIELDS`) must be integers or DoParam rejects them, and the matching HandWeapon setters take a Java int and TRUNCATE (12.67 -> 12), so the bridge rounds them (`I.INT_STATS`); the mock truncates the same way. This Windows machine has no `lua5.1`: use LuaJIT at `%LOCALAPPDATA%\Programs\LuaJIT\bin\luajit.exe`. LuaJIT accepts `goto`, so grep for it separately.

## Systems at a glance

- **Guns:** `magazines = { standard=, extended=, drum= }` (ids from `ZGB_Def_Magazines`) or `internalCapacity`. Damage / range / recoil / noise scale from the caliber's `energy` vs the archetype's `refCaliber`, unless the def sets them. `category` groups the catalogue; `replaces` / `rarity` drive loot.
- **Magazines:** first-class items, shared between guns where real (STANAG, Glock). Tier penalties (`MagazineFactory.TIERS`) apply only while loaded. Vanilla supports one `MagazineType`, so we retarget it right before insert.
- **Attachments:** slots have `kind` + accepted `interfaces`; parts have `kind`, `interface`, and may `provide` new slots (AK side mount → optic rail, HK 3-lug adapter → muzzle thread). `ZGB.Attachments.canAttach` returns `needs` with the chain of parts required. UI shows "ghost" slots. Tests require every slot to have a fitting part and every part to fit some gun.
- **Ammo:** `ZGB_AmmoCatalog` = variant effects (FMJ/HP/+P/AP/Tracer/SP/Subsonic/HV/Match/Wadcutter, buck/bird/slug/flechette) × which variants exist per caliber (32 calibers). Standard rounds of vanilla calibers reuse vanilla items. A magazine's variant is its `AmmoType`. "Load all / Unload all magazines" live in core (`ZGB_AmmoActions`, planner in `ZGB_Ammo`).
- **Loot:** `ZGB_Distributions` is data-driven: `replaces` swaps vanilla guns, other guns spawn next to their family anchor (`FAMILY_ANCHORS`) at `rarity`, magazines next to their gun by tier, ammo variants next to standard rounds (`AMMO_ANCHORS` for non-vanilla calibers).

## Status / next steps

- v0.8: Gunworks (SWMG) is the base (not yet run in game: its register summary is logged as "[ZGB] Gunworks: N ammo families...", the self-test checks every gun's family and magazine profile). Our load-all / magazine / shell menus only show without Gunworks; the Reload addon is optional and only emits events. Next: models rework (real per-gun models from Sketchfab CC-BY/CC0 via its public search API; downloads need the user's own API token in an env var), Gunsmith 3D view (vanilla `ISUI3DScene`: `createModel`, `setObjectParent` child->parent attachments, as in DebugUIs/AttachmentEditorUI.lua), loose stocks / grips / parts in loot, sounds.
- First in-game tests done (v0.7): fixed next(), FBX scale and axes, integer item fields, B42 AmmoType registry. In game, debug mode: right-click ground -> "ZGB: run self-test" (ZGB_SelfTest, ~2500 checks, report in Zomboid/Lua/ZGB_selftest.txt) and "ZGB: give test kit". Probe calls it uses live in the bridge (`I.create`, `I.probe`, `I.simulateInsert`...). Keep the self-test passing against tests/mock_game.lua; add a check there for every new game-facing behaviour.
- Not yet run in game: work through the VERIFY list in README.md on the first test.
- Mod IDs of ZombieBuddy / viewpoint mod in `ZGB_Mode.FP_MOD_IDS` and Iso `mod.info` are guesses; so are `VFExpansion1`, `firearmmod` and `Guns93` in `FOREIGN_GUN_MOD_IDS`.
- v0.5 systems (animation factory, iso view, recoil, casings, reloading, holding, callouts) are unverified in game; their game calls are VERIFY items 13-17 in README. The iso AnimSet nodes are drafts in docs/animsets/iso until the node format is confirmed.
- Next systems: grenades (callouts already listen for `grenade.throw`); speedloaders / stripper clips; FP view; addon API docs.
- Todo: fire-mode switching, weapon light, converting vanilla guns in existing saves, translations, MP sync (send* calls), armor/tracer effects for AP/tracer traits.
- Later: the FP addon reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment`.
- Sounds (v0.7): CC0 gunshots per family (`Defs/ZGB_Def_Sounds.lua`), generated by tools/gen_sounds.lua into `media/sound/ZGB/` + `ZGB_sounds.txt` (never hand-edit either); sound scripts and `setSwingSound` are VERIFY item 23. The repo root is a Workshop item (workshop.txt, preview.png, poster.png per mod).
- Textures (v0.8): a model script names ONE texture, so each real gun has its own (textures/ZGB/Guns/<id>.png: the gun at 1024 px for detailed sources plus every part baked into its variants), each real part its own (Parts/<id>.png), placeholder-only models the palette ZGB_Atlas.png. Sketchfab picks (tools/sketchfab/picks.lua) replace the low-poly sources once downloaded; fixes add drop_loose (props beside the gun) and cut_top (built-in scope).
- Real models (94: all 70 guns + 24 attachments, from CC0/CC-BY packs, see CREDITS.txt; everything ships as FBX) are fitted to placeholder boxes by tools/blender/import_models.py; FBX loading in PZ is VERIFY item 22. Blender 5.2 is installed at `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` (its FBX importer crashes on some Quaternius files: use their OBJ).
- 3D decision made (v0.6): parts vanilla can't draw are baked into gun model variants (366, generated); the Iso addon swaps `setWeaponSprite` on attachment change. Model/attachment game calls are VERIFY items 18-21. Known gap: recoil pad / butt shell holder don't follow a replacement folding stock.

## Working style

- The user writes in English or Portuguese; code, comments and commits are in English.
- Add a test for every pure-logic change; use `tests/mock_game.lua` for bridge/action code.
- Keep README.md in sync when a system changes.
