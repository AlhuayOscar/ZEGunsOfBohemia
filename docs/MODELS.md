# Models: guide for the 3D side

Every gun, attachment, magazine and casing already has a **placeholder** model
built from boxes and cylinders at real-world size. Each one lives in its own
folder. Replacing a placeholder means putting your mesh in that folder under
the same name; nothing else in the mod has to change.

## Where everything is

```
Contents/mods/ZEGunsOfBohemiaCore/42/media/
  models_X/ZGB/
    Guns/<Category>/<GunId>/<GunId>.fbx                  the bare gun
    Guns/<Category>/<GunId>/<GunId>__<Part>__<Part>.fbx  the gun with mounts / handguards / ... built in (variants)
    Attachments/<Type>/<PartId>/<PartId>.fbx             one folder per attachment
    Magazines/<Caliber>/<MagId>/<MagId>.fbx
    Casings/<CasingId>/<CasingId>.fbx
  textures/ZGB/ZGB_Atlas.png                           the ONE texture (4096 px): placeholder palette + baked tiles of real models
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
   `Attachments/Suppressors/Suppressor_Rifle556/Suppressor_Rifle556.fbx`).
   Add your texture next to it and point the model script at it.
3. For a gun: also rebuild its variants (the gun plus each built-in part), or
   ask the code side to compose them from your parts.
4. Check in game, then ask the code side to stop generating that placeholder.

## Real models from free packs

94 items (all 70 guns and 24 attachments) use real models from CC0 / CC-BY
packs instead of placeholders; magazines, casings and the other attachments
are still placeholders.
`tools/model_sources.lua` says which pack and file each one comes from, with
the license and author (it also generates `CREDITS.txt`). The Blender step
fits each source to its placeholder:

1. **Orientation:** the longest side becomes the length, and so on. Per-model
   `fix` entries correct what the review found (`flip = "yz"` turns a model
   that was upside down; `swap` exchanges axes; `exclude` drops stray pieces
   such as a loose spare magazine).
2. **Size and position:** same size and centre as the placeholder, so every
   attachment point still lands in the right place.
3. **Texture:** colours and textures are baked into a 256 px tile (2 x 2 tiles for the
   textured pack) of
   `textures/ZGB/ZGB_Atlas.png`. Every real model and every variant uses that
   one texture, so variants are just meshes put together.
4. **Variants:** the gun and its built-in parts (real or placeholder) are
   joined and exported as FBX.

To review the fit, render a sheet with each real model above its placeholder
(muzzle right, top up):

```bash
blender -b -P tools/blender/import_models.py -- --review review.png
```

## Checking models without starting the game

```bash
blender -b -P tools/blender/check_models.py                # sheets in .cache/check/, one per folder
blender -b -P tools/blender/check_models.py -- variants    # also every gun variant (slow)
```

It re-imports every exported FBX from disk (what the game will read), checks
that it loads, has geometry, uses the atlas and has a sane size, and draws
labelled contact sheets with the atlas texture, muzzle right. Problems are
listed at the end and in `.cache/check/report.json`.

Adding another free model: download it into `.cache/model_sources/`, add the
pack (title, author, license, url) and the asset line to
`tools/model_sources.lua`, rebuild, and check the review sheet.

## Regenerating

The downloaded packs live in `.cache/model_sources/` (not in git; the URLs are
in `tools/model_sources.lua`). Run from the repo root, in this order:

```bash
lua5.1 tools/gen_models.lua                       # placeholders, model scripts, manifest, credits
blender -b -P tools/blender/import_models.py      # real models, atlas, their icons and previews
lua5.1 tools/gen_scripts.lua                      # item scripts (icons, models, visual twins)
lua5.1 tools/gen_model_list.lua                   # docs/MODEL_LIST.txt
```

`gen_models.lua` wipes `models_X/ZGB/` and `textures/ZGB/` first, so always run
the Blender step after it. Hand-made models from the artist: add them to
`tools/model_sources.lua` the same way (a pack of your own), and the pipeline
keeps them.
