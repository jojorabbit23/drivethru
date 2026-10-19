# Burger inventory and serving tray

Owner request: up to four individually boxed burgers next to the serving hatch,
150 seconds of warmth from collection, retrieval for disposal, selected-item bin
interaction, wave-based inventory capacity, and both shotguns in the shop.

## Player rules

- Carry one burger initially. Clearing wave 3 unlocks slot 2, clearing 6 unlocks
  slot 3, clearing 9 unlocks slot 4. Never exceed four. Grill upgrades are separate.
- V cycles occupied slots left to right, wrapping to the first. The outlined icon
  is selected. Icons display remaining warmth / COLD; locked slots show W3/W6/W9.
- Prep can fill free inventory slots. Each assembled burger consumes its existing
  recipe ingredients. Existing double/special recipes remain separate recipe types;
  a quantity-two customer requests two boxed burgers, each using its own bun.
- Each burger receives hot_remaining=150 when collected from prep. Time continues
  in inventory and on the serving tray. Transfer/retrieval never resets it. Pause
  freezes simulation time. Cold burgers stay cold.
- Aim at an empty tray position and E to place the selected burger. Aim at an
  occupied box and E to retrieve that specific box. Full inventory leaves it there;
  full tray never removes a carried burger.
- E at the slim bin beside the hatch discards only the selected burger, hot or cold.
  Counter-mounted geometry avoids narrowing the aisle or adding a jumpable obstacle.

## Customers and money

Automatic customers request one or two burgers of their order recipe. Their bubble
and ticket show quantity. While waiting they collect matching boxes from the tray,
oldest first, checked at 5 Hz. Wrong recipes remain. They may collect an available
item and wait for the remainder; leave once the quantity is complete. Served count
increments once per completed customer order. Existing direct handover still works.

Payment is calculated per collected item. A hot burger keeps its existing quality
price/tip. A cold burger receives half its base price and half its tip, rounded down
to whole dollars. One cold item does not reduce other items' payment. Removed boxes
cannot pay twice. A perfect single mixed hot/cold pair pays $36+$18=$54.

## Weapons

Shop > Weapons and ammo lists pistol rounds, Sawn-off (Crop Duster) $90, Pump
shotgun $150, then Back. After purchase each weapon's row sells its own 12-shell
pack for $30. Duplicate purchases cannot charge again. Sawn-off remains reserved
in slot 3, unavailable until bought; wheel skips unpurchased weapons. Pump appends
to the loadout. Knife, dagger, pistol and their animations remain intact.

## Implementation and checks

burger_items.gd owns timer/payment helpers. Player owns carried items and selection;
serving_tray.gd owns four boxes and slot-specific interaction areas; burger_bin.gd
owns disposal. Existing warming tray still stores patties and is independent.

All 22 suites pass, including the new inventory/transfer/temperature/quantity/shop
regressions. Native capture_serving_inventory.gd asserts every box is reachable with
the actual look ray and verifies E retrieval/disposal, then renders HUD/tray/bin/shop.
Movement checks pass with the bin attached to the counter. Pixel-font validation
and changed-script checks pass. Captures are in docs/previews/serving_inventory_*.png.

The capped 120 FPS diagnostic retained the prior rendering gains: shop CPU render
mean 1.91 ms and stress-stage p95 frame time 12.01 ms in this run. Native frame
outliers remain possible; see burger_inventory_performance.json for measurements.
