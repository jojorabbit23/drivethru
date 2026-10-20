# Stock-aware mushroom drops

Drops now favour raw mushroom types that are scarce relative to the best-stocked type. Counts include fridge stock, player-carried mushrooms, untaken world pickups and delayed drops already rolled after a kill. Collected pickups are excluded so transfers do not count twice. Cooked patties and burgers are not raw mushroom stock.

Each eligible type receives its normal weight multiplied by `1 + 3 * (highest - count) / (highest + 2)`, then weights are normalized. The two-unit buffer softens small shortages and the boost stays below fourfold. Equal stock (including all empty) retains the original odds. The calculation runs on kills, not every frame.

Enemy pools are preserved: ordinary infected Common/Blue (80/20 base), Scuttlers Blue/Yellow (70/30 base), Lancers guaranteed Yellow. Legacy `red` remains the internal ID for Yellow. One mushroom per death and the independent 7.5% health roll remain unchanged. Rapid kills reserve their pending mushroom types immediately until the normal drop appears.

Examples: Common 20, Blue 0, Yellow 20 makes an ordinary zombie about 48% likely to drop Blue. Common 20, Blue 20, Yellow 0 makes a Scuttler about 62% likely to drop Yellow. This is assistance, not a guaranteed next drop.

Verification: tools/mushroom_balance_test.gd checks equal supply, shortages of every type, carried/loose/pending counts, collection exclusion, preserved enemy pools, actual sampled rolls and a real death transitioning one reservation into one pickup. Run all tools/*test.gd suites and validate.gd before publication.
