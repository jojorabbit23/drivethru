# Progressive mixed customer orders

Automatic customers scale with the current wave. Explicit spawn_customer(n) and
next_order remain the original single-recipe test/film API; next_orders can force
an exact mixed ticket. Normal spawning calls spawn_customer(0).

| Waves | Ticket size | Mixed chance | Recipe progression |
|---|---|---|---|
| 1–2 | 1–2 burgers | 0% | Existing served-count unlocks |
| 3–5 | 1–2; mixed always 2 | 45% | Mixed singles, e.g. R X1 + B X1 |
| 6–8 | 2–3; 35% have 3 | 70% | Doubles and Special join mixed orders |
| 9+ | 2–3; 60% have 3 | 85% | Full recipe pool, maximum 3 burgers |

The mixed chance is the fraction choosing a mixed ticket, not the fraction of
all requested patties. At least two distinct recipes are guaranteed on that path.
The earlier served-count recipe unlock still works. From wave 6, advanced recipes
are available even if the player has missed early customers.

Initial kitchen capacity and all prices stay unchanged. Each burger consumes its
normal recipe: a Double Yellow plus a Blue uses 3 patties, 2 buns and 2 toppings;
base revenue is $80. Payment and freshness penalties apply to each delivered item.
There is no new cash fine for a missed order: unfinished items lose their potential
revenue and the order does not count as a completed customer. Partial payment stays.

From wave 3, automatic orders add 6 seconds per extra required patty to base patience,
then lose 1.25 seconds per wave after wave 3. This adjustment is bounded to -12..30
seconds, before the existing bell multiplier. The first two waves retain base
patience. Vehicle gaps shorten by 0.5 seconds minimum / 1 second maximum per wave
after wave 2, capped at a 6 / 12 second reduction: defaults go from 18–32 seconds to
12–20 seconds by wave 14. Existing single-customer queue and zombie budget remain.
This is the initial tuning curve for playtesting, not an asserted failure-rate target.

## Shared APIs

CustomerCar.order_lines stores grouped {kind, quantity, received} dictionaries for
mixed tickets only. Legacy single-recipe tickets keep an empty array so existing
order / quantity / received callers remain compatible. `order` always points at
the first outstanding recipe, `quantity` counts all burgers, and `received` counts
all paid deliveries. Use remaining_lines(), wants(kind), record_delivery(kind),
and ticket_text() for mixed-aware logic. Do not increment received directly in
new service logic. Configure before setup() so the right speech bubble is built.

Manual service accepts any outstanding recipe and rejects fulfilled recipes without
consuming food. The tray tries every exact requested recipe before discount fallback,
using the existing freshest-first selection within each kind. Burnt salvage and
clearance substitution keep their existing rules. Each burger pays at most once.
The prediction tip bonus and no-reset freshness transfers are retained.

Prep searches outstanding recipes for a complete burger first, so a ready Blue can
be boxed while a Double Yellow is incomplete. If nothing requested is complete,
it preserves a pending double/special's patties and keeps the existing unrelated
spare/salvage behavior. Two Blue patties requested as a double will not be split
into a wrong single merely because a Regular is listed first.

The HUD, paper ticket and speech bubble list remaining recipe lines and quantities.
Each HUD/bubble line uses its recipe colour; the bubble includes full names and
shrinks/reflows after payment. Burger icons are created once; its tiny rim texture
is rebuilt only on a delivery. Disabled decoration ticket readouts also use the
mixed-aware API, but the decoration set remains absent from normal play.

## Validation

mixed_orders_test.gd sweeps 600 seeded orders at five wave tiers, checks bounded
size and increasing income opportunity, and exercises grouping, out-of-order
service, rejection, cold payments, no duplicate payout, prep reservation, partial
expiry, discount fallback and automatic generation. Run it with every existing
suite. capture_mixed_orders.gd renders Regular/Blue, Double Yellow/Blue, a
three-recipe order, kitchen and partial fulfillment with HUD viewport assertions.

Verification: import, validator and all 39 test suites passed. After final bubble
layout changes, mixed-order, burger-inventory, cooking-loop and both HUD suites
were rechecked. Every touched script passed check-only. Five native Vulkan mixed
order views were inspected (including partial fulfillment); HUD viewport assertions
passed. All six standard room/weapon capture scripts completed successfully.
