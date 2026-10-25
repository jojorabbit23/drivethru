# Wave flow and drive-thru QoL (25 October 2026)

Owner brief: "do some QoL on the drive thru, get it up to scratch, tighten
maths, get the waves flowing correctly". Measured first with
`tools/wave_flow_sim.gd` (real main scene, invulnerable player, enemies
killed N s after spawning; logs spawns, clears, cap stalls, stuck enemies and
customers). Mechanically the waves already worked (no stalls or stuck enemies
across 8 waves); the problems were shape and seams.

## What changed (main.gd)

- One new enemy type per wave, announced in the wave banner:
  wave 1 Shamblers + Hollowheads, wave 2 +Scuttlers (`scuttler_from_wave`),
  wave 3 +Scientists (`scientist_from_wave`), wave 4 +Lancers
  (`lancer_from_wave`, was 2). Previously wave 1 already had two Scuttlers and
  a Scientist. The every-N rotation (`*_every`) is unchanged.
- Groups: waves 1-3 single file, 4-6 pairs, 7-9 threes, then fours
  (`group_size`, `max_group`). A group arrives 0.35 s apart through different
  windows; the next group follows after `wave_interval x group size`, so the
  average rate per enemy is unchanged. The banner says when groups grow.
- Cap: a spawn held back by `max_zombies` retries after 1 s instead of a whole
  interval (nothing is lost; wave_capacity_test still holds).
- Breaks: 20 s after wave 1, +2 s per wave, capped at 30 s (`break_length`),
  as orders grow in size.
- Wave cleared toast: kills and cash earned during that wave.

## Maths

- Customer patience: the extra time for extra patties
  (`order_progression.gd patience_bonus`) now applies from wave 1. It was
  gated to wave 3+, so an early two-burger order got no more time than a
  single (50 s vs 56 s now).
- Shop: the heated serving tray label uses `SERVING_HEATER_PRICE`.
- Checked and left as designed: kill cash ($2) roughly covers pistol ammo per
  kill ($0.50/round); shells cost more than a kill pays (shotguns are bought
  for safety, burgers carry the economy); supplies $8/burger single, $7.33 bulk.

## QoL toasts

- "N BUNS LEFT · BUY SUPPLIES SOON" at 3, "OUT OF BUNS/TOPPINGS" at 0 (once per crossing).
- "NO <KIND> MUSHROOMS FOR THIS ORDER" when a customer arrives wanting a patty
  kind that is nowhere: not stored, not on the grill, not in the warming tray,
  and no finished burger of that recipe carried or on the serving tray
  (`main.missing_kinds`).

## Checks

`tools/wave_flow_test.gd` (20 checks), lancer/scientist tests now read
`*_from_wave`, `tools/capture_wave_toasts.gd` renders the new toasts.
