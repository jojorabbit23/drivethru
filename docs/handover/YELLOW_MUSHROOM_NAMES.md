# Yellow mushroom naming

Owner correction: the mushroom previously labelled Red is Yellow. Economy names, single/double recipe names, storage prompts and customer speech bubbles now display Yellow. Existing grill, prep, tray, inventory and order-rail labels use these shared names. Design docs updated.

Legacy red/double_red identifiers remain stable for existing stored stock, burger dictionaries and recipes. Gameplay probabilities, prices, ingredients and texture assets are unchanged. This is a display-name correction.

Native customer bubble preview: docs/previews/customer_order_yellow.png. Capture assertions and the patty-menu regression expectation updated to the corrected label.

Validation: all 27 regression suites plus validate pass (loop suite rerun with corrected two-patty prompt expectation). Touched scripts parse; customer bubble and required room/weapon Vulkan renders inspected.
