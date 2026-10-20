# Hollowhead — common infected / Tier 1

The owner's honeycomb-faced, blue-trousered static model is now a separate enemy.
The supplied origin story is that immortality treatment used self-repairing fungal
cells; the sentient colony later hollowed out human minds and replaced neural
tissue with spores. Hollowheads retain broken instincts that draw them to roads,
restaurants, lights, engines and food. Their hollow fungal face is a fruiting body,
not armour. This is the common infected, not a heavy Mauler.

## Spawn policy

One enemy per existing wave slot. Hollowheads take odd-numbered common slots after
Scuttler/Lancer priority; remaining common slots retain the original Shambler.
They appear from wave 1 at a similar rate to the other common types. Wave sizes,
intervals, lane balancing and the global 12-active-enemy cap are unchanged.
Calls and death spores only agitate existing nearby zombies; they never spawn any.
H manually spawns one through the same capped path for testing.

## Behaviour / initial balance

- 80 HP; 3.5x head damage; 15-damage stagger threshold. A 25-damage headshot kills.
- Ordinary shuffling approach, inherited board-ripping, window climb and navigation.
- Visibility-triggered clicking within 8 m, at most once per 8 s. Nearby Hollowheads
  become agitated; other existing types gain a non-stacking 20% movement boost for
  five seconds. Bursts last .8 s in a 3.5 s cycle while agitated.
- Occasional .42 s stumble/flinch pauses while hunting (7–11 s apart).
- Alternating right/left swipe and two-arm slam, damage 8 / 8 / 12. Hits occur at
  .62 s, only once per animation and only with a clear line through world/boards.
- Below 30% health: faster clicking, .45 s telegraph, then a committed one-second
  straight charge at 3.2 m/s. It can be sidestepped or staggered; impact deals 16
  once, followed by a 2.5 s charge cooldown. It cannot steer around corners.
- Death releases a 1.6 s spore cloud. Within 1.7 m of the chest, with an unobstructed
  line, it deals 3 HP once and briefly tints/obscures vision. Nearby zombies become
  agitated for six seconds. Owner explicitly deferred infection progression.
- Normal mushroom, kill cash, wave clearing and independent 10% health-bottle roll
  use the shared death path.

## Asset / performance

Source GLB has no skeleton or clips: 6792 vertices. Builder adds an 18-bone rig,
UV-seam-aware limb labels with isolated-patch cleanup, shoulder blending and LODs.
Existing project Shambler clips are retargeted to measured rest positions. Left
swipe mirrors the right clip; slam has its own synchronous arm/chest tracks.
Source triangles and owner textures, including blue trousers, are retained.
1024px mipmapped nearest texture and compressed mesh share resources across mobs.
No per-enemy lights; one pooled 3D click voice each. The deterministic click WAV is
baked offline. Spore render budget: at most 8 clouds x 14 billboard puffs, no lights,
no shadows, short lifetime. Gameplay effects still resolve when visuals are capped.

Bounded native Vulkan stress check (12 Hollowheads + 8 simultaneous clouds, 720p,
120 FPS diagnostic cap): repeat mean 8.49 ms, p95 10.34 ms, worst 48.65 ms, ~389 MiB
VRAM. First run had a 197 ms first-burst hitch. These are short local checks, not a
promise of hitch-free play. Ordinary waves do not create these mobs in batches.

## Verification

All 26 suites pass, including a new Hollowhead suite: normalised weights, nine
clips, no long hand-to-leg stretch strands in slam, attack damage/single-hit timing,
non-stacking/expiring agitation, no extra spawning, charge telegraph/sidestep/hit/
interrupt, wall-blocked swipes and spores, minor death damage, health/mushroom drops,
weapon-ray head hitbox, headshot kill, both window climbs and wave-one roster.
Native Vulkan captures cover idle, walk, both swipes, slam, death, spores and nearby
vision exposure/clearing. Required room/pistol/knife/pump captures inspected.
Use the existing Try_DriveThru_Vulkan.cmd launcher confirmed smooth by the owner.
