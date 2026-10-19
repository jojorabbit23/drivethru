# Rush shelf

Four carried boxes maximum, four shared serving/clearance boxes maximum. Inventory
slots unlock at the START of waves 3, 6 and 9. V selects left to right and wraps.
Look at an occupied tray box and press E to retrieve it, then E at the bin to discard.

## Freshness

Age begins on pickup/bagging. Each burger keeps its own age across every transfer.
Fresh 0–50s; Warm 50–110s; Cooling 110–150s; Cold 150–300s;
Very Cold 300–450s; Spoiled at 450s. HUD and physical boxes show pixel icons and names.
Cold pays 50%, Very Cold 25%, rounded down separately for price and tip. Spoiled
cannot sell and must be binned. A quiet bell marks the cold transition. Cold tray
stock triggers a faint tick every 20s; filling/rejecting a full tray plays a low tone.

## Automatic sales

Customers check on arrival and every 0.2s while waiting. No reservations. Matching
recipe stock sells freshest first. Orders can contain 1–2 boxes initially and up
to 3 from wave 6. The existing customer patience window remains 50s (75s with bell).
Each box pays immediately; the car leaves when its quantity is complete.

Hot matching boxes stocked before arrival earn +25% on their quality tip if taken
within 3s of arrival. Round the resulting tip to whole dollars. No bonus for manual
handover, cold stock or later deposits. Standard burgers still have no quality tip.

The DISCOUNT BOX plaque beside the tray deposits selected cold/very-cold stock into
an available one of the SAME FOUR spaces and marks it SALE. Customers first choose
their exact recipe; otherwise they accept marked clearance as a discounted substitute.
Retrieval and disposal work identically for sale boxes. No extra hidden storage.

## Upgrade

Shop > Upgrades > More upgrades > Heated serving tray: $180. This slows hot food's
age on the serving shelf by half: a newly bagged box remains hot for 300 real seconds
there instead of 150. Carried food ages normally. Already cold food does not reheat;
post-cold stages remain 150s each. Earlier time is never refunded. The old patty
warming tray remains a separate upgrade. Box lid colours identify common/brown,
blue and red recipes; special recipes use gold.

## Verification

Extended burger_inventory_test.gd covers boundaries, 50/25% pricing, spoilage,
freshest-first selection, shared clearance capacity, retrieval, heater purchase,
warning interval and immediate triple sales with the preparation tip bonus.
Native capture_serving_inventory.gd exercises actual look-ray pickup and bin use.
