# OTG Saloon V2

**Version 2.0.0** — commercial-oriented RSG Core / RedM business creator.


Dynamic RedM saloon/business foundation for **RSG Core**.

## Included in v1.0.0

- In-game `/saloonadmin` business creator
- In-game station placement
- In-game recipe creator
- Server-authoritative crafting
- RSG Inventory storage
- Supply ordering from configurable depots
- Persistent shipments
- Public freight contracts via `/freight` and depot boards
- Physical crate pickup/carry flow
- Saloon delivery points
- Delivered business stock
- SQL persistence and transaction log
- Server-side job, grade, distance, item, shipment and contract validation

## Dependencies

- rsg-core
- ox_lib
- oxmysql
- ox_target
- rsg-inventory

## Install

1. Import `sql/install.sql`.
2. Put `otg-saloon` in your resources folder.
3. Add `ensure otg-saloon` after the dependencies.
4. Configure `shared/config.lua`.
5. Add each saloon job to `rsg-core/shared/jobs.lua` before creating that business.
6. Restart the server after adding new RSG jobs.
7. In game, use `/saloonadmin`.
8. Create the business, then stand at each desired point and use **Place Station**.
9. Place at least a `craft`, `storage`, `manager`, and `delivery` station.
10. Create recipes in game.

## Important item setup

Recipe results, recipe ingredients, and configured supplier ingredients must exist in
`rsg-core/shared/items.lua`. The sample supplier catalog uses `water` and `bread`;
change these to your server's actual RSG item names.

### Recipe output images and usable items

Recipe outputs are created dynamically by OTG through RSG Core's supported runtime
item API and restored from the recipe database whenever the resource starts. Choose
a unique item key, weight, description, and local inventory PNG filename in the recipe
editor. The PNG must exist in `rsg-inventory/html/images/`; external HTTPS/FiveManage
images remain available separately as menu artwork. Ingredients are selected only
from the server's static `rsg-core/shared/items.lua` definitions. Dynamic outputs are
registered as usable items and apply the recipe's configured consumable effects.

### Saloon management

- `/saloonadmin` -> **Manage Businesses** lets admins edit business details,
  storage limits, blip coordinates, stations, and recipes.
- Stations support configurable **sphere** or **box** interaction zones. Use
  **Stations** -> a station -> **Edit Details** to set the shape and dimensions.
- A `tray` station is a shared RSG Inventory stash: employees can place prepared
  items into it and any player can take items from it.
- Business storage remains job-restricted and uses the per-business weight/slot
  limits selected by the admin.
- The actual RSG job `isboss` grade can create recipes from the manager station;
  admins can create or edit recipes from `/saloonadmin`.
- Supply orders set a RedM map waypoint and notify the ordering employee of the
  exact pickup depot.

## Freight flow

Manager orders supplies -> shipment becomes ready at configured depot -> manager can
post a public contract -> player accepts `/freight` -> player visits depot -> collects
crates -> takes them to the saloon's in-game delivery station -> server verifies each
delivery -> stock is credited -> contractor is paid on verified completion.

## V1 note: wagon loading

The shipment/cargo lifecycle is implemented and persistent. V1 represents a collected
crate as a carried physical crate and keeps cargo state server-side. Model-specific
visual crate attachment slots on wagon beds are intentionally left isolated for the
next pass because RedM wagon attachment offsets differ by model. No GTA/FiveM vehicle
native assumptions are included.

## Security

Client data is treated as requests, not authority. Crafting validates job/grade,
station identity, distance, ingredients and output capacity server-side. Freight
validates assignment, depot distance, delivery distance, crate counts and completion
server-side.

## FiveM contamination check

This resource targets `game 'rdr3'`, uses RSG Core/RSG Inventory, ox_lib/ox_target,
RedM entities, and contains no QBCore/ESX/GTA vehicle spawn logic or FiveM-only
restaurant dependencies.


## V2 creator

V2 replaces the admin creator's primary context-menu workflow with a custom western NUI.
Physical station placement uses a reusable RedM-safe key-mapped controller:

- Arrow keys: horizontal movement
- Page Up / Page Down: raise/lower
- Q / E: rotate
- Left Shift: precision modifier
- Enter: confirm
- Backspace: cancel

The prop transform is saved separately from the interaction-zone transform. The preview prop
is intentionally deleted on confirmation; the authoritative business sync recreates the
display prop from the saved station settings.

## V2 recipe images

OTG's menu/recipe image is independent from the image used by rsg-inventory. V2 accepts an
HTTPS recipe image URL and stores it with the recipe. It does not expose or require a
FiveManage token. A future provider adapter can upload server-side without changing recipe
records.

## Important live validation

This package was statically audited, but it cannot substitute for testing against your exact
installed rsg-core, rsg-inventory and ox_target revisions. Before commercial release, verify
all inventory/target exports against the versions shipped by the target server and run the
tray persistence, placement, crafting, shipment and restart tests in RedM.


## V2.0.1 NUI boot fix

The creator now waits for an explicit browser `uiReady` handshake before taking NUI focus.
This prevents an invisible/failed NUI page from trapping player input. The web script also
avoids nullish-coalescing syntax for compatibility with older RedM CEF builds.



## V2.0.2
- Fixed the NUI packaging regression: `fx_version` is restored to `cerulean`.
- Removed the temporary `saloonuifix` command.
- Removed the loading toast; creator boot is now silent until the NUI page is ready.
- Restyled the creator using the supplied general-store UI as visual direction while keeping OTG's own implementation.


## V2.0.3 creator boot correction
The non-rendering creator was traced to a JavaScript parse failure introduced by the V2.0.1
patch: a literal `\n` token had been inserted between executable statements in `web/app.js`.
That prevented the entire NUI script from executing, which also prevented the `uiReady`
callback. V2.0.3 removes the invalid token. The temporary `saloonuifix` command remains
removed as requested.


## V2.1.0 — Saloon Works Creator
- New OTG-specific visual identity (iron/leather/brass command-ledger design).
- `/saloonadmin` opens a Business Directory rather than silently selecting the first business.
- Directory includes active/inactive businesses, search/filter, balance/station/recipe summaries, edit and destructive delete confirmation.
- Business workspace has explicit breadcrumb/identity, overview metrics and readiness inspection.
- Existing stations can be edited, moved or deleted. Existing recipes can be edited or deleted.
- Recipe editor now exposes category, price and independent HTTPS OTG menu image.
- Existing business identity, owner, job, active state, storage and blip settings remain editable.
- All mutations continue through client -> server validation; the NUI is not authoritative.


## V2.2.0 — Creator depth pass

- Recipe minimum job grade was removed from the creator. The legacy database column remains at 0 for backward-compatible schema/crafting code.
- Recipe ingredients are now visual rows with searchable selectors populated from the installed server's `RSGCore.Shared.Items`, plus +/- quantity controls.
- Result items use the same authoritative RSG item catalog.
- Recipe menu art has its own HTTPS URL field and live NUI preview, separate from rsg-inventory item imagery.
- Boss recipe creation now opens the OTG recipe-book NUI instead of the old ox_lib text dialog.
- Added business-scoped `manage_recipes` permission storage for future/delegated employees; server recipe mutations validate admin/boss/delegated permission.
- Station editor now explicitly exposes an optional prop field and a Prop Browser.
- Prop Browser is data-driven through `Config.PropCatalog`; custom RDR3 model names are validated on the client before placement.
- OTG intentionally does not claim to enumerate every RDR3 base-game prop: RedM does not expose a reliable human-readable all-object catalog. Curated verified models plus custom model validation is safer for a commercial resource.


## V2.3.0 test candidate
Recipes now include bounded hunger, thirst, health, stamina, alcohol-strength and consume-time effects.
Hunger/thirst are applied to RSG player metadata only after authoritative inventory removal. Health/stamina
use RedM-compatible client natives. Alcohol is stored for a later verified RedM drunk-effect adapter.

FiveManage-hosted HTTPS image URLs are supported for OTG menu art. A server-only provider status boundary is
included and credentials are kept in convars. OTG intentionally does not invent/hardcode a FiveManage upload
endpoint. FiveManage hosting does not register an item in RSG Core: result items still must exist in
`rsg-core/shared/items.lua`.

Existing V2.2 databases: run `ALTER TABLE otg_saloon_recipes ADD COLUMN effects LONGTEXT DEFAULT NULL AFTER category;`
before starting V2.3.


## V2.3.1 hotfix
- Fixed Business Directory serialization. Numeric database IDs were becoming a sparse JSON array,
  producing null entries and `Cannot read properties of null (reading 'label')`. NUI now receives a
  string-keyed business object, so all admin-visible businesses render.
- Hardened the NUI against null business records.
- Fixed RedM business blips: coordinate blip style and icon sprite are now applied separately.
- Removed `OTG NETWORK` and `BUSINESS ADMINISTRATION & OPERATIONS` from the creator UI.


## V2.4.0 audit/stabilization
- Fixed edit-save slug handling: existing business can keep its own slug; duplicate check excludes its ID.
- Database errors now log the real server-side error instead of always reporting a duplicate slug.
- Active checkbox now updates local creator state immediately and persists as a boolean.
- Blip capture returns/stores XYZ in the NUI payload and resets draft coordinates between businesses.
- Blips are created only for active businesses with valid coordinates.
- Removed Business Readiness from the creator.
- Expanded the data-driven prop browser and kept client-side model validation before placement.
- Prop thumbnails are intentionally not fabricated. Actual world placement is the authoritative model preview.


## V2.4.1 blip schema hotfix
The default RedM blip sprite used by OTG can be represented as a negative signed 32-bit hash
(e.g. `-1861245094`). Older OTG install SQL declared `blip_sprite` as `INT UNSIGNED`, which
caused business updates to fail with `Out of range value for column 'blip_sprite'`.

Existing databases must run:
`ALTER TABLE otg_saloon_businesses MODIFY COLUMN blip_sprite INT NULL;`

Fresh V2.4.1 installs use a signed INT for `blip_sprite`.


## V2.5.0 — creator reliability / visual placement pass

- Fixed the original default saloon sprite. `BLIP_AMBIENT_SALOON` was not the correct RDR2 saloon sprite;
  OTG now uses `blip_saloon` (`1879260108`) and automatically repairs the exact legacy persisted value.
- Blips now use `BLIP_STYLE_SHOP` and a separate sprite, matching established RedM/RDR3 usage.
- Added a searchable Blip Browser. OTG loads the public RDR2 hash database server-side and uses femga preview
  images when available. A packaged fallback remains if outbound HTTP is unavailable.
- Added full RDR2 object-database search for the Prop Browser (2+ character search, capped at 250 results).
  The selected object is validated by the RedM client before use.
- Added PREVIEW IN WORLD for prop results. This shows the actual game model instead of pretending a third-party
  thumbnail is authoritative.
- Rebuilt station placement as two independent stages: PROP transform, then INTERACTION ZONE transform.
- Sphere zones render as a translucent RDR3 sphere marker; box zones render as a translucent RDR3 cube marker.
  Arrow/PgUp/PgDn/Q/E place the zone and [ / ] resize it.
- Manager stations now provide explicit job/boss feedback before opening OTG management.
- The runtime interaction layer remains ox_target because current RSG documentation uses ox_target; no unverified
  rsg-target API was substituted. PolyZone remains available for servers that deliberately choose that adapter.


## V2.5.1 NUI boot hotfix
V2.5.0 could throw during app.js startup because the Blip Browser event handler was bound to a
button that the HTML patch had failed to create. Since uiReady is sent earlier in the script, Lua
could focus an NUI whose JavaScript had already crashed, making the creator appear not to open.
V2.5.1 creates the button explicitly, makes the optional binding null-safe, removes the accidental
binding inserted inside page(), and merges the reference catalog callbacks into the established
businesses server module to reduce resource startup ordering risk.


## V2.6.0 runtime reliability pass
- Restored the proven RedM coordinate blip style `1664425300`.
- Blip names now use `CreateVarString(..., 'LITERAL_STRING', label)` before SET_BLIP_NAME_FROM_PLAYER_STRING.
- Removed fragile remote blip image URLs. The blip browser now has PREVIEW, which creates the actual selected
  RDR2 blip at the player's position temporarily so the administrator can inspect it on the real map.
- Manager zones are always target-visible. RSG job/boss authorization happens after selection and gives an
  explicit error instead of silently hiding the target.
- Boss detection accepts the normal RSG `job.isboss` flag and grade-table `isboss` fallback.
- Zone placement now uses the actual ox_target addSphereZone/addBoxZone implementation with `debug=true`.
  Walk to the desired center; the real target zone follows the player. [ and ] resize; Enter saves.
- Prop browser keeps authoritative in-world PREVIEW rather than unreliable third-party thumbnails.
- `Config.Debug = true` draws the real ox_target station zones and automatically logs every synchronized
  station/blip, its coordinates and dimensions, its runtime handle, and aggregate rebuild failures in F8.
