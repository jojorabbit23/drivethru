# Grill mistake recovery

F on an unflipped raw/cooking patty still flips it. A second F on the same slot within 0.45 seconds discards it, even while the flip tween is running. The second-tap prompt says what will happen. Late presses, other slots, losing grill focus, a reused slot, and any cooked/burnt patty cannot inherit that discard action. Cooking reaching the ready threshold immediately cancels it.

Discard frees the slot without refunding stock or producing a burger. One cosmetic mushroom is thrown onto the floor: no collision/physics, at most six waste visuals, automatic cleanup after about eight seconds. Material and pose are copied so later slot reuse does not change floor waste.

An incomplete double/special recipe preserves every requested kind, but may box a ready unrelated patty as a single (warming tray first, then oldest ready grill spare). Full requested recipes retain priority. Raw/cooking spares cannot be boxed; missing-recipe prompts and burnt salvage remain available when no spare exists.

Regression tests exercise real grill interactions, timing, slot identity, cooked cutoff, ingredient conservation, wrong-single boxing, preserving matching patties, completing the double with a replacement, and warming-tray fallback. Native capture_grill_recovery.gd verifies the falling visual, floor position, no colliders and cleanup, and saves flip/floor screenshots.

Updated input: F is the flip/discard action, routed through player flip_patty binding. E opens placement menus and never flips or discards. Key echo cannot supply the second tap. Native capture uses viewport keyboard injection (F press, release, F press). Sawn-off inspect moved to I to remove the F conflict.

F update validation: physical-key event regressions include E opening the menu, held-key echo rejection, timing, cooked cutoff and slot reuse. Native viewport key injection passed toss/floor/cleanup checks. Import, touched-script checks and all 36 suites pass.
