# Next edits — agreed owner brief

19 October 2026. Original agreed requirements. Codex-side implementation status and integration hooks are recorded in CODEX_SIDE_IMPLEMENTED.md; Claude-side gameplay remains to be integrated. This supersedes the earlier ambiguous wording about a two-patty order.

## Ownership

Codex owns shotgun presentation and damage tuning, distant ambience, grinder visuals/animation/audio, and the kitchen bin model/placement. Claude owns orders, ingredient accounting, burger freshness, carrying/grill upgrades, bin interactions, fridge power-up storage, and connecting successful storage deposits to the grinder effect.

The split follows existing work ownership, rather than a claim that either assistant is inherently better at a particular kind of code. Do not overwrite the other side's changes or replace shared scenes wholesale.

## Confirmed requirements

### Orders — Claude

At the beginning, customers can order up to two separate burgers using the same mushroom option. A two-burger order consumes two patties and two buns. This is not a double-patty burger, and it does not change ingredient yield to two patties per mushroom. Preserve the existing mushroom-to-patty yield unless the owner separately changes it.

### Freshness and cold food — Claude

Each burger starts its own 30-second cooling timer when removed from the grill. It becomes a cold burger when that time expires, including while carried in a stack. Serving a cold burger is allowed but reduces the tip and therefore the total payment. The exact tip reduction has not been specified; choose a clearly named tunable value and document it. A separate reduction to the base burger price has not been requested.

Keep each burger's freshness independent. Stacking, selecting or reordering burgers must not reset their age. Timers follow gameplay time and pause with the game.

### Disposal — Claude behavior; Codex model/placement

Add an interactable kitchen bin so the player can dispose of cold burgers and restart preparation. When carrying two or three burgers, disposal removes cold burgers only and retains any hot burgers. The count and freshness display must reflect what remains. With no cold burger held, show a clear no-op prompt rather than throwing away hot food. The exact visual bin position should keep doors, windows and cooking stations accessible.

### Capacity — Claude

Start with two available grill slots and capacity to carry two finished burgers. Unlocking additional grill capacity also unlocks the matching carrying capacity; three carried burgers require the three-slot upgrade. Use one authoritative capacity value or a shared upgrade source so the two limits cannot drift apart. Upgrade price and purchase route remain unspecified; use the existing upgrade/economy design where applicable and document provisional choices.

### Kitchen fridge — Claude

Make the existing kitchen fridge interactable as power-up storage, with clear store/retrieve feedback. Power-up contents, storage capacity and acquisition rules have not been specified: keep these explicitly configurable/provisional and resolve them before implementing a new power-up catalogue. Do not invent a new buff system as an incidental part of the fridge interaction.

### Mushroom grinder — Codex visuals; Claude deposit integration

Place a small, low-poly mushroom grinder beside the mushroom tray. On a successful mushroom deposit into storage, show a processing animation: mushrooms enter the grinder, mushroom mince leaves its spout and falls into the tray, visually explaining patty preparation. Use the existing oxidised teal, burnt orange and worn steel/chalk palette.

The effect is cosmetic. Claude owns the inventory transaction and triggers the effect exactly once after a successful deposit; Codex owns the grinder scene and effect. Failed/empty deposits must not play a successful processing animation or create stock. Repeated input must not duplicate ingredients. Use a bounded animation/pool and a documented busy/retrigger policy.

The current storage station is in the storeroom. The owner described the grinder next to the mushroom tray; agree the tray/deposit position during integration instead of moving the station independently on both sides.

### Shotgun — Codex

- Fix the reload hand disappearing. Keep it visible throughout the reload.
- Bring the loading hand over the top to the actual shell-loading area, rather than around the rear/wrong side of the gun. Inspect both shell insertions and return to grip.
- Give firing a louder, fuller, deeper report with more weight. Keep the master limiter and audio controls working.
- Increase backward recoil and use a controlled return to aim.
- Increase damage, expose/document the chosen tuning and check close-range results against both enemy types. No exact target damage was specified.
- Add a brief, restrained smoke/steam release and extra firing motion to sell force. Do not obscure the view with a persistent effect.
- Preserve seated-shell accounting, interrupted reload behavior, ammunition limits, weapon switching and the existing controls.

### Distant atmosphere — Codex

Add faint distant zombie moans and a low ominous drone/hum, suggesting trouble far away. Keep them spatially distant, subtle and intermittent; preserve the distinction from immediate enemy attack cues. Respect ambience settings, background mute, pause and performance limits.

## File boundaries and integration

Codex: `weapons/crop_duster/`, `tools/build_crop_duster.gd`, relevant weapon capture/tests, `presentation/audio_library.gd`, `presentation/world_feedback.gd`, and dedicated grinder/bin visual files. Kitchen geometry changes go through `tools/kitchen_room.gd` and `tools/build_shop.gd`, never hand-edit generated room files.

Claude: `game/` gameplay scripts, necessary inventory methods in `player/player.gd`, necessary station wiring/HUD in `main.gd`, and gameplay tests. Avoid replacing `player/player.tscn`: keep the Presentation and PauseMenu children. Preserve all existing weapon slots and public weapon APIs.

Only one side rebuilds/commits shared generated room assets during integration. Codex owns that room rebuild. Claude should provide required station positions and interaction dimensions, rather than independently rebuilding the shop.

Agree one small signal/call interface for successful storage deposits before connecting the grinder. No polling inventory counts to guess whether a deposit occurred.

## Review order

1. Codex: shotgun reload visibility and hand alignment.
2. Codex: firing audio/recoil/effects and damage tuning.
3. Claude in parallel: order quantity, independent burger freshness, selective disposal and linked capacity upgrades.
4. Codex: distant ambience and grinder/bin visuals. Claude: fridge and deposit integration.
5. Merge the two branches without replacing shared scenes. Run every AGENTS.md check plus existing pistol, Crop Duster, menu and presentation suites; add meaningful tests for the new gameplay rules.
6. Render and inspect both shotgun shell insertions, all firing effects, the grinder deposit, mixed hot/cold stacks, and bin/fridge placement. Run the bounded performance check, refresh the latest playtest only after integration, and document any provisional balance values.

## Existing implementation facts to account for

The current grill has three hard-coded slots and the player has one string-valued held-item field. The new two-slot starting capacity and multiple independently aged burgers require a real inventory/capacity change, not just a HUD label. Current storage code explicitly uses one mushroom per common patty; the two-burger order does not alter that yield.

The current shotgun fires eight pellets with 16 damage per pellet. Tune based on actual spread/range and observed hit results; do not equate nominal summed pellet damage with guaranteed damage on target.

The presentation polish already adds cached sound, separate audio buses, pause/settings and nearby attack/death cues. Extend those systems rather than adding a second settings or ambience manager.
