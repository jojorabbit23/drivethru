# Playtest clarity improvements

Based on the owner's 2026-10-20 playtest review. No changes to wave balance, prices, customer patience, recipes, serving automation, cooking times or weapon damage.

- Cooking: shader sears the pale underside as well as the cap, adds grill marks and chars burnt food. World labels explicitly show RAW, COOKING/percentage, READY/time left, BURNT. Three-line cooking labels fit four slots. A full raw/cooking grill no longer tells players ready patties can be bagged. Targeted prompts direct ready/burnt food to the existing prep interaction.
- Repair: requires proximity, facing the window (dot >= 0.65) and an unobstructed world-layer ray to the opening centre. Looking away, switching windows, death or another focused station clears progress. Existing repair timing and board rules remain. Existing repair simulation tests now explicitly aim toward the window.
- HUD: controls collapse to F1 after eight seconds; full F1 panel retained and unsupported dash glyphs fixed. Smaller announcements sit below inventory. Health and weapon text are larger.
- Customer card: visible from any room while a car approaches/waits; shows recipe, remaining quantity and actual patience time/bar. Clears on departure, freed car or death. Reads existing customer state without reserving or changing sales.
- Warnings: empty magazine vs no ammunition vs last rounds are distinct. <=25% health adds explicit warning and restrained edge pulse. A small directional marker points toward a known damage source for one second. No new lights, screen shaders or audio loops.

Implementation: presentation/clarity_hud.gd is attached by main.gd after stations are constructed. Refreshes labels at 10 Hz; reused bar style; overlay uses a few 2D primitives. Cooking presentation lives in game/grill.gd and game/patty.gdshader. Repair lives in player/player.gd.

Validation: all 28 regression suites plus validate pass; loop suite rerun after fixing safe handling of a departing/freed customer. Dedicated clarity test checks aim, blocked sight, progress reset, cross-room orders and remaining quantity, patience, freed customers, health/ammo/death states, help collapse and full-raw-grill prompt. Native Vulkan captures inspected: clarity_cooking_states, critical_order, quiet_hud, repair_target, repair_away, controls. Required kitchen, service and weapon captures rendered and inspected. Native performance check completed; raw measurements in clarity_performance.json are observations, not an FPS guarantee.
