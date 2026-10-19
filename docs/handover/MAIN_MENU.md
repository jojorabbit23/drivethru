# Main menu — 19 October 2026

The default startup scene is ui/menu/menu.tscn. The aligned zombie → burger → mushroom departure sequence plays full-frame, centred with its original 16:9 proportions; after it finishes, bread_loop.ogv repeats a six-second gentle camera hover. Resizing letterboxes the video instead of moving it to the right or stretching it. Video streams are Godot-native Ogg Theora encodes of the approved MP4 edits; the original edits remain in the sibling DriveThru_Intro output directory.

The left menu uses AtlasTexture regions from the owner's menu reference. A shader recolours the selected label orange, other enabled labels cream, and unavailable Continue grey; the teal arrow follows mouse hover or keyboard arrows. Enter/click activates. No slogan or red writing is added. Start Cooking immediately opens the existing main.tscn with pistol, knife and Crop Duster. How to Play and Credits open dismissible panels. Settings exposes master volume and fullscreen for the current session. Continue stays disabled because persistent saves have not been implemented. Esc closes a menu panel; gameplay's existing Esc mouse-release behaviour is unchanged.

The menu is capped at 30 FPS while focused and 15 in the background. Starting gameplay restores its 60 FPS cap. Gameplay is loaded only after Start Cooking, so zombies and physics do not run behind the menu.

Validation: 10 menu checks including Start Cooking loading the real game and all three weapon nodes, plus script parse checks and the full validate/movement/zombie/ooze/knife/knife-viewmodel/pistol/Crop Duster suites pass. Native video intro-to-loop handoff was checked in a bounded rendered run; menu and knife screenshots were inspected. Preview: docs/previews/menu.png.
