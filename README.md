# ZE Guns Of Bohemia — v0.3.0, Build 42

*Idk, Guns and a lot of messing around.*

A Project Zomboid firearms framework built so that ISO and first-person never fight
over the same gun. One **spec** per weapon is the single source of truth for ammo,
capacity, stats, sounds, attachment rules and which animation set it uses.

## Layout

```
Contents/mods/
  ZEGunsOfBohemiaCore/     logic only — no animations, no Java. Always enabled.
  ZEGunsOfBohemiaIso/      ISO view addon (pure Lua). Registers provider "iso".
  ZEGunsOfBohemiaFP/       (future) first-person addon, requires ZombieBuddy. Provider "fp".
tests/run_tests.lua   offline tests (lua 5.1); tests/mock_game.lua fakes inventories
tools/gen_scripts.lua regenerates item scripts from the Lua catalogs
```

Iso and FP are blocked from running together twice over: `incompatible=` in
`mod.info` (load time) and `ZGB.Mode.registerProvider` refusing a second provider
(runtime). That is the fix for the animation overlap / flicker / crash.

## How the pieces fit

| File | Job | Touches game API? |
|---|---|---|
| `Factory/ZGB_Archetypes` | defaults per family (pistol, smg, assault_rifle, shotgun, bolt_rifle) | no |
| `Factory/ZGB_WeaponFactory` | `define{}` → validated spec. **MaxAmmo derived from `magazine.capacity`** | no |
| `Factory/ZGB_PartFactory` | `define{}` for attachments: `kind`, `interface`, `provides`, `mods` | no |
| `ZGB_Attachments` | rules engine: canAttach / canDetach / requirement chains / UI tree | no |
| `ZGB_Stats` | final stats = base + all part mods, recomputed from scratch | no |
| `ZGB_Mode` | view-provider gate (only one owner of animations) | `getActivatedMods` |
| `ZGB_ScriptApply` | at boot, writes every spec into the item scripts (DoParam) | yes |
| `ZGB_ItemBridge` | **only** place that calls HandWeapon methods | yes |
| `ZGB_Service` + `ZGB_PartActions` | attach/detach as timed actions | yes |
| `client/.../ZGB_GunsmithWindow` | attachment UI | yes |
| `server/.../ZGB_Distributions` | swaps vanilla guns for ours in loot | yes |
| `ZGBIso/ZGB_ViewIso` | archetype → ISO animation set | no |

## Attachments: how "red dot needs a mount on an AK" works

Nothing is special-cased. Slots have a `kind` and accepted `interfaces`; parts
have a `kind`, an `interface`, and may `provide` new slots.

- AK47 slot `side_mount` accepts `ak_dovetail` — there is **no** optic slot.
- `Mount_AK_SideRail` (interface `ak_dovetail`) provides `optic_rail` accepting `picatinny`.
- `Optic_RedDot` is `picatinny` → `canAttach` returns `needs {Mount_AK_SideRail}`.
- Glock17 has `under_rail` directly, so a grip/light goes straight on; the AK needs the quad-rail handguard first.

The Gunsmith window (right-click a ZE Guns Of Bohemia gun → **Gunsmith...**) shows the
whole tree, including "ghost" slots that appear once a mount is fitted, with
READY / NOT OWNED / needs X / INSTALLED, and a stat preview for the selected part.
Removing a mount with an optic still on it is blocked ("remove Red Dot first").

## Magazines (v0.2)

A gun can take several magazines: `magazine` is the default, `altMagazines` the rest.
Each has its own `capacity` and optional `mods` that apply **only while it is loaded**
(the AK drum adds weight, aim time and reload time).

- **Right-click the gun → Load magazine** lists the fullest carried mag of each type. Swapping queues: eject → retarget → insert, so ejecting always hands back the right magazine item.
- **R key** on an empty gun picks the best carried mag (most rounds; ties keep the type you were using).
- Any insert (R, our menu, vanilla menu) records the loaded mag and re-applies stats.
- The Gunsmith window shows `Ammo x/capacity`, the loaded mag, and every mag the gun takes.
- Loot: `D.alsoSpawn` adds drums / extended mags next to standard mags at a lower weight.

Vanilla only supports one `MagazineType` per gun, so the trick is to retarget
`MagazineType` + `MaxAmmo` right before a magazine goes in.

## Ammo types (v0.3)

`Factory/ZGB_AmmoCatalog.lua` defines **what each kind of round does** (FMJ, Hollow Point,
+P, Armor Piercing, Tracer, Soft Point, Subsonic, High Velocity, Buckshot, Birdshot, Slug)
and **which kinds exist for each caliber** — first in the list is the default:

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

Guns now declare `caliber = "762x39"`; the ammo list comes from the catalog.
**Standard rounds of calibers vanilla already has reuse the vanilla item**
(`Base.Bullets9mm`, `Base.556Bullets`, `Base.ShotgunShells`...), so vanilla boxes,
crafting and other ammo mods keep working. Only the variants are new items.

**Load all magazines** (right-click any of our guns, magazines, or matching ammo):
- one carried ammo type that would load something → a single "Load all 7.62x39mm magazines (FMJ, 60 rds)"
- several → a submenu: "FMJ - loads 60 (have 120)", "Armor Piercing - loads 25 (have 25)"...
- partly-filled mags are topped off with the **same** type first; mags holding another type
  are skipped — "Unload all ... magazines" empties them so you can switch.
- one timed action per magazine: cancelling keeps what's already loaded.

A magazine's ammo type is its vanilla `AmmoType`, so vanilla's own bullet loading stays
consistent. Inserting a mag sets the gun to that ammo (stats change: AP crit, HP damage,
subsonic noise...). Shotguns (tube-fed) get **Load with... Buckshot / Slug** while empty.
Variants spawn next to the standard rounds weighted by rarity; 7.62x39 spawns near 5.56.

Edit the catalog, then run `lua tools/gen_scripts.lua` to regenerate the item scripts.

## Adding a gun

1. `ZGB_Def_Weapons.lua` → `ZGB.WeaponFactory.define{ id, archetype, displayName, caliber, magazine={item,capacity}, slots={...} }`
2. `ZGB_items_weapons.txt` → a skeleton `item <id>` (identity + model only) and its magazine item.
3. Done. Stats, capacity, sounds and anims come from the spec at boot.

## Run the tests

```
lua5.1 tests/run_tests.lua      # 55 tests: factory, rules, chains, stats, magazines, ammo catalog, load-all planner, load/unload actions on a mock inventory, loot, mode gate
```

## Before the first in-game run — VERIFY list

These are game-API details I wrote from Build 41/42 conventions without your
install to check against. Each is marked `-- VERIFY` in the code:

1. **FP mod IDs** in `ZGB_Mode.FP_MOD_IDS` and `ZEGunsOfBohemiaIso/42/mod.info` — copy the exact `id=` from ZombieBuddy's and the viewpoint mod's `mod.info`.
2. **Item script fields** (`ItemType = base:weapon`, etc.) — compare with vanilla `AssaultRifle`/`Pistol` in your build's `media/scripts`.
3. **`AmmoType` format** — B42 may expect a registry-style id; check a vanilla gun.
4. **HandWeapon setter names** in `ZGB_ItemBridge.SETTERS` (failures are logged once, never crash).
5. **Anim names** in `ZGB_ViewIso.lua` — copy from vanilla gun scripts.
6. **Timed-action style** (`perform`/`complete`) — compare with vanilla `ISUpgradeWeapon`.
7. **Magazine hooks** (`ZGB_ReloadHooks`, `ZGB_MagazineActions`): `ISInsertMagazine` / `ISEjectMagazine` constructors and the `gun` field, `ISReloadWeaponAction.BeginAutomaticReload`, `setMagazineType`, `isContainsClip`, `getAllTypeRecurse`. If one is missing, a warning is logged and that feature turns off instead of crashing.
8. **Ammo** (`ZGB_ItemBridge`): `setAmmoType`/`getAmmoType` on magazines and guns, `getCountTypeRecurse`, whether `RemoveOneOf` reaches into bags, `AddItems`; the vanilla ammo ids in `ZGB_AmmoCatalog`; `Count` in the ammo scripts.
9. **MP**: inventory add/remove in `ZGB_Service` is SP-correct; MP needs the B42 send* sync calls.

## Not done yet

- fire-mode switching, weapon light behaviour
- converting vanilla guns already in a save; code-spawned guns (zombie holsters)
- translations
- AP/tracer `traits` are data only (no armor or tracer visuals yet); one ammo type per magazine (no mixed loads)
- the FP addon: reads `spec.fp`, `spec.recoil.fp` and each optic's `fp.sightAlignment` (already in the data so sights are planned from day one)

## Notes for the 3D side

- Vanilla can only render parts in 6 types (Scope, Clip, Sling, Canon, Stock, RecoilPad).
  Parts with `vanillaPartType` get mirrored into vanilla purely so their model shows;
  stats always come from our Lua.
- **Mounts/handguards have no vanilla part type.** Open decision: bake the mount into
  the optic model (one model per optic+mount combo), or swap the gun's model variant
  when a mount is on. Worth deciding before modelling optics.
- Each optic has an `fp.sightAlignment` (eye offset + zoom) — fill it per model so ADS lines up.
