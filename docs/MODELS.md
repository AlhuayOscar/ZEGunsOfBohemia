# Models: guide for the 3D side

Every gun, attachment, magazine and casing already has a **placeholder** model
built from boxes and cylinders at real-world size. Each one lives in its own
folder. Replacing a placeholder means putting your mesh in that folder under
the same name; nothing else in the mod has to change.

## Where everything is

```
Contents/mods/ZEGunsOfBohemiaCore/42/media/
  models_X/ZGB/
    Guns/<Category>/<GunId>/<GunId>.X                  the bare gun
    Guns/<Category>/<GunId>/<GunId>__<Part>__<Part>.X  the gun with mounts / handguards / ... built in (variants)
    Attachments/<Type>/<PartId>/<PartId>.X             one folder per attachment
    Magazines/<Caliber>/<MagId>/<MagId>.X
    Casings/<CasingId>/<CasingId>.X
  textures/ZGB/ZGB_Placeholder.png                     colour atlas used by every placeholder
  textures/Item_ZGB_<Id>.png                           inventory icons (32 x 32)
  textures/ZGB/Preview/<Id>.png                        side views for the attachment window
  scripts/ZGB_models.txt                               model scripts + attachment points
```

Gun categories: `Handguns`, `RevolversHandCannons`, `AssaultRifles`, `DMRs`,
`SniperRifles`, `SMGs`, `Shotguns`, `LeverActions`.

Attachment types: `Optics`, `Mounts`, `Handguards`, `Adapters`, `Grips`,
`Lights`, `Lasers`, `Bipods`, `Suppressors`, `MuzzleBrakes`, `FlashHiders`,
`Stocks`, `ShellHolders`, `RecoilPads`, `Slings` (choke tubes are internal and
have no model).

The full list with ids is in `docs/catalogue.json` and on the armory catalogue page.

## How attachments end up on a gun

The game can only draw an attached part through six channels (scope, barrel,
stock, sling, recoil pad, clip), one part each, at a named point on the gun
model. So the mod splits attachments in two:

| Kind | Examples | How it shows |
|---|---|---|
| **Drawn by the game** | optics, suppressors, brakes, flash hiders, grips, bipods, slings, AR stocks | Its own model, mounted by its `anchor` point on the gun's `scope` / `canon` / `stock` / `sling` / `recoilpad` point |
| **Built into a variant** | mounts, rail handguards, adapters, lasers, lights, shell holders, recoil pads, stocks that replace the original | The gun switches to a variant model with the part already in it. Variants only exist for combinations the attachment rules allow (366 in total, at most 32 for one gun) |

A variant also moves the gun's points. An AK with the side-rail mount gets a
`scope` point on top of the mount, so a red dot lands on the rail. A bare AK
has no `scope` point at all.

## Coordinates and points

- Metres. `x` points forward (muzzle), `y` up, `z` to the right.
- The origin is the top of the firing hand's grip, where the hand holds the gun.
- Attachment models are built around their mounting point (their origin):
  muzzle devices grow forward, stocks backward, optics up, grips down.
- Point positions for every gun come from `ZGB_Def_Models.lua` (gun shape +
  real length). If your real model is a different size, move the points there
  and rerun the generator, rather than editing `ZGB_models.txt` by hand.

## Replacing a placeholder

1. Model the item with its origin and axes as above.
2. Export it into the item's folder with the same file name (e.g.
   `Attachments/Suppressors/Suppressor_Rifle556/Suppressor_Rifle556.X`).
   Add your texture next to it and point the model script at it.
3. For a gun: also rebuild its variants (the gun plus each built-in part), or
   ask the code side to compose them from your parts.
4. Check in game, then ask the code side to stop generating that placeholder.

## Regenerating

```bash
lua5.1 tools/gen_models.lua    # models, icons, preview sprites, model scripts
lua5.1 tools/gen_scripts.lua   # item scripts (icons, models, visual twins)
```

The generator wipes `models_X/ZGB/` and `textures/ZGB/` before writing, so
keep real models out of those folders until the generator learns to skip
them (or commit them and restore after a run).
