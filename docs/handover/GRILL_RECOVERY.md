# Grill mistake recovery

E on an unflipped raw/cooking patty still flips it. A second E on the same slot within 0.45 seconds discards it, even while the flip tween is running. The second-tap prompt says what will happen. Late presses, other slots, losing grill focus, a reused slot, and any cooked/burnt patty cannot inherit that discard action. Cooking reaching the ready threshold immediately cancels it.

Discard frees the slot without refunding stock or producing a burger. One cosmetic mushroom is thrown onto the floor: no collision/physics, at most six waste visuals, automatic cleanup after about eight seconds. Material and pose are copied so later slot reuse does not change floor waste.

An incomplete double/special recipe preserves every requested kind, but may box a ready unrelated patty as a single (warming tray first, then oldest ready grill spare). Full requested recipes retain priority. Raw/cooking spares cannot be boxed; missing-recipe prompts and burnt salvage remain available when no spare exists.

Regression tests exercise real grill interactions, timing, slot identity, cooked cutoff, ingredient conservation, wrong-single boxing, preserving matching patties, completing the double with a replacement, and warming-tray fallback. Native capture_grill_recovery.gd verifies the falling visual, floor position, no colliders and cleanup, and saves flip/floor screenshots.
