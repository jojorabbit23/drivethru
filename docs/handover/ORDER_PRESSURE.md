# Order pressure (orders side of the QoL split)

Makes the drive-thru pull against the fight, so ignoring the hatch to shoot has a cost
and later waves feel busier at the window as well as at the barricades.

## Reputation (`game/reputation.gd`)
- 0-100, starts at 50. One node per game, a child of main (group `reputation`);
  `Reputation.attach(main)` is the one line main.gd calls, at the end of `_ready()`.
- Changes: completed order +3, each perfect burger +1, cold -1, burnt salvage -2,
  car missed -10, delivery cancelled -6.
- Tiers (floor, tip multiplier, car gap multiplier):
  LEGENDARY 90 (x1.5, x0.85) · GOOD 70 (x1.25, x0.92) · DECENT 40 (x1, x1) ·
  SHAKY 20 (x0.75, x1.15) · TERRIBLE 0 (x0.5, x1.3).
  Tips are scaled in `customer_window._pay` (and shown in the hatch prompt); the gap
  before the next car and delivery call is scaled in their `left` handlers.
- Serve streak: completed orders without a miss; every 3rd pays $10 x (streak / 3),
  capped at $30. A miss resets it.

## Rush hour (`game/customer_window.gd`, `game/customer_car.gd`)
- When a car arrives at the hatch, from wave `rush_from_wave` (5) a second car may be
  scheduled 4-12 s later: 30% at wave 5, +10% a wave, max 80%; 100% on main's dinner-rush
  waves if main has `is_rush_wave(n)` (added by the waves side; optional here).
- The second car (`hatch.queued`) stops 13 m behind the hatch in state `queued`, honks
  quietly, shows no bubble. `hatch.car` stays the front car, so the rail, prep bench and
  clarity HUD are unchanged.
- When the front car leaves, the queued car moves up after 1.2 s (no usual gap). Time in
  line costs 0.4 s of patience per second, at most 30% of its patience.
- The delivery hatch never queues (`allow_queue = false`).

## Impatience
- At 25% patience left a car honks once (`impatient` / `hatch.customer_impatient`), its
  bubble shakes and its bar blinks; a "CUSTOMER LOSING PATIENCE" toast shows.

## HUD (`game/order_hud.gd`)
- Bottom left above the health line: NEXT IN LINE (queued car's ticket), REP tier, tip
  multiplier and streak, and a reputation bar that blinks on a big change.

## Tests and captures
- `tools/order_pressure_test.gd` (29 checks).
- `tools/capture_order_pressure.gd` → `docs/previews/order_pressure_{hud,queue,impatient}.png`.
- `tools/loop_test.gd` pins reputation to 50 before its exact-payment check.
