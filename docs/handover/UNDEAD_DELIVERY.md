# Undead Eats delivery hatch

The garage's east wall now has a separate delivery hatch centred at world
`(5.7, 0, 6.25)`. The original zombie window at z=8 is unchanged. Buy the garage
for $250 first, then look at the shutter and press E to open delivery for $200.
The additional rear door stays closed. This hatch never joins the windows group.

## Playing

- First phone call eight seconds after purchase; later calls 35–55 seconds after
  the previous order completes or expires. Car arrivals continue independently.
- Phone orders use the same wave-scaled recipes/quantities, with 120 seconds plus
  the positive complex-order allowance. The existing bell upgrade extends both.
- The wall phone double-rings every eight seconds until acknowledged with E.
  Orders already appear in the speech bubble and HUD: answering is optional.
- G switches the prep bench and its paper ticket between CAR and DELIVERY.
  E on the phone also selects delivery. Each order's state remains independent.
- Four delivery tray boxes work exactly like the first serving tray: E deposits
  the selected burger or retrieves an occupied box, V selects carried burgers.
  Matching burgers are collected automatically, freshest first. Partial orders
  pay per item, without duplicate credit. A second bin sits beside this hatch.
- Food can move between both trays and inventory; its original age survives.
  Cold/very cold penalties, spoiled rejection, the global serving-heater upgrade
  and prepared-in-advance tip bonus use the existing shared implementations.

## Flip tips

Previously only ready-to-box delay affected tips. A patty now records the fraction
of its cooking time at its first flip. A burger boxed PERFECT or GOOD earns an
extra $2 tip if **every** patty was flipped at 40–60%. Existing tips stay intact;
the bonus passes through the same cold scaling and prepared-food multiplier at
both hatches. The warmer preserves this metadata. Burgers without it retain their
old payment. No timer resets were introduced.

## Integration for the incoming bikes and riders

`main.delivery` is `game/delivery_station.gd`, extending `customer_window.gd` for
fulfilment/payment. It creates a lightweight `delivery_order.gd` ticket, extending
the existing customer order book/bubble but never building a car mesh or running
vehicle movement. Do not call CustomerCar.setup() on it.

Use `DeliveryStation/RiderStop` for the delivery vehicle's waiting position,
outside the wall. `customer_arrived(ticket)` announces a phone order and
`pickup_ready(ticket)` announces its completion; `customer_missed` announces
expiry. Copy order data in signal handlers if needed: the ticket is freed on the
next frame after completion/expiry. Rider travel/visuals are intentionally awaiting
the owner's models; current orders finish automatically when fully supplied.
Do not make riders or their hatch additional zombie spawn targets.

Shared API: `bench.active_hatch()`, `select_delivery(bool)`, `cycle_ticket()`;
legacy `bench.hatch` still means the original car hatch. Food belongs to neither
channel, so carrying or preparing it does not reserve it for a particular buyer.

Geometry is built by `tools/garage_room_builder.gd`; regenerate with
`tools/build_shop.gd`. The live counter, shutter, phone and tray belong to
DeliveryStation. Do not hand-edit the generated shop scene/export.

## Findings and checks

- All four tray slots need clear interaction rays. The hatch zone starts above
  the tray rather than enclosing its rear boxes; a real-player E test covers each.
- Counter placement leaves the centre aisle, existing zombie lane, motorcycle,
  three bottles and rear door clear. Phone sound is positional and cached.
- The combined scene exposed a flat-floor movement snag during the sprint tour.
  Collision reporting identified the floor, not kitchen furniture. Disabling
  CharacterBody3D's stop-on-slope option cleared the route/slide probe; the world
  collision margin, speed, capsule and furniture remain unchanged. The full
  movement stress suite also passes (124 doorway runs, six tours and 24 fuzz bots).
- `tools/delivery_test.gd` covers purchase gating/price, E targeting all four
  boxes, parallel mixed orders, independent trays, fresh-first selection,
  acknowledgement, G selection, timers, cold penalties, timeout and flip tips.
- `tools/capture_delivery.gd` renders locked/active hatch, garage context and the
  kitchen with concurrent order displays. Native captures use Vulkan mobile.
