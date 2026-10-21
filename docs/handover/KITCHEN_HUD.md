# Kitchen HUD and order codes

Player-facing Common/Brown is now Regular; legacy brown and red save IDs remain unchanged. Kitchen codes are R, B, Y, DBL R/B/Y and SP. Quantity counts complete burgers, not patties: DBL Y X2 means two double-Yellow burgers. ASCII X is intentional because the supplied pixel font lacks the multiplication glyph.

The persistent customer card, vehicle bubble and kitchen ticket rail use Recipes.ticket_text and update remaining quantity after partial service. Colour comes from the base recipe: Brown for Regular, teal-blue for Blue, amber-yellow for Yellow. Special speech bubbles carry both Blue and Yellow edge stripes. Text remains readable against the background. Yellow mushroom icons and world tint now use yellow rather than orange.

ClarityHUD has compact grill slot cards: mushroom icon, type code, state and seconds until burning. Raw/cooking countdown includes remaining cook time, adjusted for the faster flipped rate, then the current grill's ready window. Cooked countdown shows actual remaining burn time. Empty, burnt and upgrade states are explicit. A two-line code legend stays beneath the cards. Updates reuse widgets at the existing 10 Hz refresh rate; no new per-frame rebuild loop.

Tests cover every code, legacy labels, quantity semantics, matching bubble/HUD after partial service, Double Yellow border, Special dual stripes, burn timers before/after flipping, upgraded slots and hidden HUD on death. capture_kitchen_hud.gd renders a four-slot mixed grill and DBL Y X2 customer view for native visual QA.

Verification: validator, import, touched-script checks and all 36 test suites passed (cooking loop updated for code-based rail text and rerun). Native mixed-grill/customer captures inspected after layout corrections; standard room/weapon captures also rendered. Double-Blue tray lids now resolve base recipe colour consistently and are covered by the HUD regression suite.

Speech bubble refinements: the actual order letters and rim use Recipes.colour for the requested mushroom, with a dark text outline. A separate full REGULAR / BLUE / YELLOW caption distinguishes pixel-font R and B; Special says BLUE + YELLOW with a split rim. Native captures include Regular, Blue and Special separately.
## Gameplay clarity pass (21 October 2026)

The customer card separates complete burger quantity from ingredients for EACH
burger (including a bun and topping), and reports matching boxed burgers on the
serving tray. Spoiled or wrong-recipe burgers do not count; cold matches are
explicit. The last ten seconds show LAST CALL. Order lettering uses recipe colour.

A four-slot serving-tray strip reports boxed recipe codes and freshness from any
room. It hides when empty, and gives separate cold-pay and spoiled-bin reminders.
V COLD means Very Cold. All ages remain owned by the existing burger dictionary;
this HUD never ticks or resets them, reserves food or changes automated purchases.

Grill cards identify a flipped patty and highlight the aimed slot. While the real
quick-discard window is armed, the hint names the slot that a second F discards.
Ready patties with three seconds or less until burning show BAG NOW. Cooked patties
never display the uncooked-discard hint. All readouts hide on death; the grill panel
moves up into unused customer space when no order is active.

Widgets and cached icons are reused at the existing 10 Hz update rate. A local copy
of the bitmap font enables size scaling so the four-card layouts fit their panels;
the global font and other menus are untouched. Decorations remain disabled.

Run gameplay_clarity_test.gd, clarity_test.gd and kitchen_hud_test.gd alongside the
full suite. capture_gameplay_clarity.gd renders mixed stock, flip/discard, last call,
Very Cold and no-customer layouts at 1280x720, asserting visible panels stay inside
the viewport and above the bottom HUD.

Verification for this pass: import, validator and all 38 test suites passed.
After final typography adjustments, all touched GDScript checks and the three
clarity/HUD suites passed again. Five dedicated Vulkan previews were inspected,
including all four Very Cold slots; panel viewport assertions passed. All six
standard room/weapon native capture scripts also completed successfully.
