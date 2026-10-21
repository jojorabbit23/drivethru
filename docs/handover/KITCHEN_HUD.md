# Kitchen HUD and order codes

Player-facing Common/Brown is now Regular; legacy brown and red save IDs remain unchanged. Kitchen codes are R, B, Y, DBL R/B/Y and SP. Quantity counts complete burgers, not patties: DBL Y X2 means two double-Yellow burgers. ASCII X is intentional because the supplied pixel font lacks the multiplication glyph.

The persistent customer card, vehicle bubble and kitchen ticket rail use Recipes.ticket_text and update remaining quantity after partial service. Colour comes from the base recipe: Brown for Regular, teal-blue for Blue, amber-yellow for Yellow. Special speech bubbles carry both Blue and Yellow edge stripes. Text remains readable against the background. Yellow mushroom icons and world tint now use yellow rather than orange.

ClarityHUD has compact grill slot cards: mushroom icon, type code, state and seconds until burning. Raw/cooking countdown includes remaining cook time, adjusted for the faster flipped rate, then the current grill's ready window. Cooked countdown shows actual remaining burn time. Empty, burnt and upgrade states are explicit. A two-line code legend stays beneath the cards. Updates reuse widgets at the existing 10 Hz refresh rate; no new per-frame rebuild loop.

Tests cover every code, legacy labels, quantity semantics, matching bubble/HUD after partial service, Double Yellow border, Special dual stripes, burn timers before/after flipping, upgraded slots and hidden HUD on death. capture_kitchen_hud.gd renders a four-slot mixed grill and DBL Y X2 customer view for native visual QA.

Verification: validator, import, touched-script checks and all 36 test suites passed (cooking loop updated for code-based rail text and rerun). Native mixed-grill/customer captures inspected after layout corrections; standard room/weapon captures also rendered. Double-Blue tray lids now resolve base recipe colour consistently and are covered by the HUD regression suite.
