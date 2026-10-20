# Empty breakable bottles

Owner-supplied glass bottle.glb retained in props/empty_bottle/source/bottle.glb. tools/build_empty_bottle.gd builds a bottom-centred 27cm mesh, keeping UVs and the supplied texture (512px shared material embedded in the mesh).

One bottle sits on the kitchen sink rim; two sit in the fridge room on a crate and shelf. These are decorative empty bottles, separate from blue health drops. No health, cash or kill rewards.

Static world-layer hit shapes use take_prop_damage; Hitscan.damage_prop dispatches only at actual weapon impact, never while querying a ray. Pistol, pump shotgun, sawn-off and knife/dagger support it. Glass sound plays on Effects; seven short-lived visual shards have no physics. Multiple pellets can only break a bottle once. Bottle bodies are removed after the brief effect. Three bottles bound the maximum number of effects.

Audio can be rebuilt with tools/audio/make_glass_break.py (NumPy). Native placement captures: tools/capture_empty_bottles.gd. Dedicated tests exercise pistol, knife, both shotguns, duplicate damage, bottle count and absence from enemy counts.

Validation: import, touched-script parse checks, validate and all 27 regression suites passed, including dedicated breakable-bottle tests. Final placement and live shard effect rendered with Vulkan and inspected.
