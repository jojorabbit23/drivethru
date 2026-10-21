# Building decoration guide

Owner requested the whole set be removed from play on 21 October 2026.
`main.building_decorations_enabled` defaults to false. All individual assets and
builders remain saved for selective placement later. Decoration captures/tests
explicitly opt in; normal play has none of these props, audio or lighting effects.


When explicitly enabled, main.gd installs all 64 guide IDs as BuildingDecorations. Each has
its own reusable scene under props/building_decor/generated; the combined scene
stores layout only. Edit tools/build_building_decor.gd, then rebuild, never edit
mesh scene output. Owner text and machine-readable catalogue are retained in
art/building_decor. The 14-colour guide palette is local to this set.

Existing grill, patty prep, serving tray, ticket rail, room lights, desk and garage
remain authoritative. The fryer is decoration, as requested, until fried food is
designed. The freezer overlay forwards the existing $250 garage purchase and hides
when opened; it never activates the zombie entrance early. The jukebox opens the
owned-weapon selector. The service bell rings, loose signs/cones/mop/standee topple,
and furniture/vehicles accept existing weapon damage with no extra kill rewards.
Interior loose props and new crate cover use damage Areas to avoid movement snags;
physical cover is used for exterior props and the booth. Shared Hitscan.cast includes
world-layer Areas. Interaction Areas remain on layer 32 and are excluded from bullets.
Cosmetic break debris is limited to six batches of six pieces, cleaned after 7 seconds.

Barricade board loss increases wear: hatch cracks, torn poster, shortened hazard tape
and missing roof letters. This persists through repairs during a run. There is no
separate shift system, so wave_started advances the recurring employee-of-month gag.
One roof bulb flickers through material visibility; the other stays dead. Moss glows
faintly through emission without adding a light. Existing four room lights receive
staggered 120 ms dips every 19 seconds to 78% brightness. Existing shadow budget stays.

Original synthesized mono WAVs: fridge hum at kitchen/storage, quiet cheerful intercom
music, occasional ice clunk. Maximum four spatial voices, 8 m maximum distance, on
Ambience. Headless runs skip playback. No external sound licences needed.

Validation: building_decor_test.gd exercises all 64 reusable scenes, damage, toppling,
bell, door price, wear and gag. capture_building_decor.gd renders ten views including wear and the employee gag;
benchmark_building_decor.gd compares the same kitchen view hidden/visible at 1280x720.
Measured RTX 3060 Ti Vulkan: hidden median 1.374 ms / p95 1.640 ms / 433 draws;
visible median 1.283 ms / p95 1.818 ms / 472 draws. These are an idle view comparison,
not a guarantee for every wave or machine. Additional props cast no shadows.

## Coverage
| ID | Object | Implementation |
|---|---|---|
| EXT_roof_sign | Mushroom-cap roof sign | Separate scene, placed in combined layout |
| EXT_barricade_table | Picnic table on its side | Separate scene, placed in combined layout |
| EXT_barricade_menu | Menu board bolted across the door | Separate scene, placed in combined layout |
| EXT_barricade_cones | Traffic cones | Separate scene, placed in combined layout |
| EXT_barricade_pallets | Stacked pallets | Separate scene, placed in combined layout |
| EXT_tape_hazard | Hazard tape | Separate scene, placed in combined layout |
| EXT_decal_nowserving | "NOW SERVING" vinyl, peeling | Separate scene, placed in combined layout |
| EXT_decal_combo | "ASK ABOUT OUR COMBO" vinyl, peeling | Separate scene, placed in combined layout |
| EXT_plywood | Plywood half-covering windows | Separate scene, placed in combined layout |
| EXT_sign_norefunds | "NO REFUNDS AFTER THE APOCALYPSE" | Separate scene, placed in combined layout |
| EXT_sign_limbs | "MANAGEMENT NOT RESPONSIBLE FOR LOST LIMBS" plate | Separate scene, placed in combined layout |
| EXT_fungus_shelf | Shelf mushrooms | Separate scene, placed in combined layout |
| EXT_fungus_moss | Glowing spore moss patches | Separate scene, placed in combined layout |
| EXT_vehicle_pickup | Rusted pickup, flat tyre | Separate scene, placed in combined layout |
| EXT_vehicle_minivan | Minivan, sliding door open | Separate scene, placed in combined layout |
| EXT_decal_kidseatfree | "KIDS EAT FREE" bumper sticker | Separate scene, placed in combined layout |
| LANE_menu_board | Menu board, worn laminate, missing letters | Separate scene, placed in combined layout |
| LANE_speaker_post | Dented intercom with "WELCOME" sticker | Separate scene, placed in combined layout |
| LANE_clearance_bar | "MAX HEIGHT 2.1M" bar bent into a hook | Separate scene, placed in combined layout |
| LANE_arrows | Faded arrows | Separate scene, placed in combined layout |
| LANE_oil_stains | Oil stains | Separate scene, placed in combined layout |
| LANE_claw_gouges | Claw gouges | Separate scene, placed in combined layout |
| WIN_sliding_window | Scratched sliding window | Separate scene, placed in combined layout |
| WIN_sign_knock | Hand-written "PLEASE KNOCK" | Separate scene, placed in combined layout |
| WIN_bell | Service bell, too loud | Separate scene, placed in combined layout |
| WIN_tray_shelf | Stainless counter with burn marks | Separate scene, placed in combined layout |
| WIN_napkins | Battered napkin dispenser | Separate scene, placed in combined layout |
| WIN_special_card | Laminated "TODAY'S SPECIAL" card | Separate scene, placed in combined layout |
| WIN_ticket_rail | Order ticket rail under warm light | Separate scene, placed in combined layout |
| WIN_feedback_box | Customer feedback box, three padlocks | Separate scene, placed in combined layout |
| KIT_grill | Blackened stainless grill | Separate scene, placed in combined layout |
| KIT_fryer | Fryer | Separate scene, placed in combined layout |
| KIT_hood_vent | Grease-stained hood vent | Separate scene, placed in combined layout |
| KIT_sign_cleangrill | "CLEAN GRILL = HAPPY GRILL" | Separate scene, placed in combined layout |
| KIT_hooks_wall | Aprons, hairnet, one-fingered oven glove, cleaver | Separate scene, placed in combined layout |
| KIT_prep_board | Chipped cutting board and spatulas | Separate scene, placed in combined layout |
| KIT_ticket_spike | Ticket spike through old orders | Separate scene, placed in combined layout |
| KIT_health_cert | Framed health certificate, score smudged, expired | Separate scene, placed in combined layout |
| KIT_rota | Shift rota with one name crossed out | Separate scene, placed in combined layout |
| KIT_notice_washhands | "WASH HANDS" reminder with a handprint | Separate scene, placed in combined layout |
| KIT_notice_infection | "IN CASE OF INFECTION" flowchart | Separate scene, placed in combined layout |
| KIT_floor_tiles | Checkerboard with grease patches | Separate scene, placed in combined layout |
| KIT_mop_bucket | Mop bucket | Separate scene, placed in combined layout |
| KIT_sign_wetfloor | "WET FLOOR" sign | Separate scene, placed in combined layout |
| DIN_booth | Vinyl booth with duct-tape repairs, ketchup stains, mould | Separate scene, placed in combined layout |
| DIN_poster_pinup | 1950s-style toadstool pin-up poster | Separate scene, placed in combined layout |
| DIN_calendar | "SPORE OF THE MONTH" calendar stuck on March | Separate scene, placed in combined layout |
| DIN_standee_cleatimus | "CLEATIMUS SAYS: TRY THE DOUBLE!" cut-out with a bite taken out | Separate scene, placed in combined layout |
| DIN_figurine_display | "COLLECT ALL 6 FUNGI FIGURINES" display, five slots empty | Separate scene, placed in combined layout |
| DIN_jukebox | Dead jukebox | Separate scene, placed in combined layout |
| DIN_clock | Wall clock stopped at 12:00 | Separate scene, placed in combined layout |
| BACK_crates | Mushroom crates stencilled "PREMIUM CAPS" and "DO NOT EAT RAW" | Separate scene, placed in combined layout |
| BACK_freezer_door | Frosted freezer door with a handwritten "DON'T." | Separate scene, placed in combined layout |
| BACK_desk | Office desk | Separate scene, placed in combined layout |
| BACK_plant_dead | Dead plant | Separate scene, placed in combined layout |
| BACK_phone_rotary | Rotary phone, off the hook | Separate scene, placed in combined layout |
| BACK_invoices | Stack of unpaid invoices | Separate scene, placed in combined layout |
| BACK_photo_eotm | Framed "EMPLOYEE OF THE MONTH" photo | Separate scene, placed in combined layout |
| FX_light_fluoro | Warm fluorescent tube | Separate scene, placed in combined layout |
| FX_light_fluoro_dead | Dead fluorescent tube | Separate scene, placed in combined layout |
| FX_light_window_glow | Window glow against dusk haze | Separate scene, placed in combined layout |
| FX_audio_ice_machine | Ice machine clunk | Separate scene, placed in combined layout |
| FX_audio_fridge_hum | Fridge hum | Separate scene, placed in combined layout |
| FX_audio_hold_music | Cheerful hold-music loop | Separate scene, placed in combined layout |

All 37 test suites plus validate.gd passed. Every touched GDScript passed check-only.
The import and all six standard native captures also passed; images were inspected.
The permanently shut far garage door remains shut behind its decorative menu board.
