# Sneaky Okey

3D, stylized, 4-player party Okey game with stealth/stealing mechanics. Full vision and roadmap: [master.md](master.md). Future ideas: [guncellemeOnerisi.md](guncellemeOnerisi.md).

## Working with the team
- Talha owns the project; friends pull the repo and develop with Claude Code too. Talk to them in Turkish, casual tone.
- Assume no 3D modelling or game-engine knowledge: explain what to click/test in plain words.
- They test by running the game and giving feedback on feel; keep each change small and testable.
- Several people push to `main`: pull before starting, commit small, and do not rewrite shared history.

## Tech
- **Engine:** Godot 4.7 (GDScript, Forward+). Executable: `C:\Tools\Godot\godot.cmd` (on user PATH as `godot`).
- Scenes are thin; most geometry is built in code so it stays text-editable.
- Look: realistic lighting and PBR materials (Liar's Bar style) around stylized dayı characters. Dark warm kahvehane,
  volumetric fog, SSAO/SSIL, AgX tonemap, vignette + film grain (`scripts/ui/post_fx.gd`).
- Environment props and textures are CC0 from Poly Haven: `python tools/fetch_polyhaven.py model|texture <id>...`
  downloads 1k sets into `assets/polyhaven/<id>/` and adds the CREDITS row. Use them via `Mat.model()` / `Mat.textured()`.
- Art is made by Claude, not by hand: Blender 5.2.3 LTS lives in `C:\Tools\blender-5.2.3-windows-x64\` and models are
  built by Python scripts in `tools/blender/` (metaballs for organic shapes), exported to `assets/models/`.
  Scripts share helpers in `tools/blender/kit.py` (metaballs, lathe, torus, hand builder, preview render, export).
  Rebuild: `blender -b --factory-startup -P tools/blender/<dayi|hands>.py -- <abs path>/assets/models/dayi/<name>.glb [preview.png]`,
  props: `... -P tools/blender/props.py -- <abs path>/assets/models/props [preview.png]` (tea_set, tespih, semaver).
  Always render the preview and look at it after changing a model.
- AI models come from Meshy (paid plan, assets are ours). Key: `MESHY_API_KEY` in the git-ignored `.env`.
  `python tools/meshy.py balance|image|text|rig|animate|actions` saves raw GLBs to `raw/meshy/` (ignored by git and Godot);
  `blender -b --factory-startup -P tools/blender/meshy_import.py -- <raw.glb> <out.glb> <height m> <faces> <texture px> [preview.png]`
  makes them game-ready in `assets/models/meshy/`; place them with `Mat.meshy()`.
- Opponents are rigged Meshy dayıs (`scripts/world/meshy_dayi.gd`, `Seat.DAYIS`, `Buddy.setup_meshy`): Meshy's Chair_Sit_Idle_M
  frozen at frame 0 plus procedural breathing, head turn and two-bone arm IK (`reach()` / `release_hand()`), so arms never clip the table.
  Pipeline per dayı: `meshy.py picture` -> `image` -> `meshy_import.py` -> `rig` -> `animate <rig id> <name> 33 343 307`,
  then copy `raw/meshy/<name>_anim.glb` to `assets/models/meshy/<name>_sit.glb`. Meshy skeletons are in centimetres.
- Better rig: Mixamo (free, Talha uploads by hand) adds finger bones. `mixamo_export.py` makes the upload FBX from
  `assets/models/meshy/<name>.glb`; Talha's download goes to `raw/mixamo/indir/<name>.fbx` and `mixamo_import.py` turns it
  into `assets/models/dayi_rig/<name>.glb` (Y-up metres, head and hands shrunk in the mesh by `proportions.py`).
  Mixamo clips (FBX, Without Skin, 30 fps) go to `raw/mixamo/anim/` and `mixamo_anim.py` makes `dayi_rig/anim/<clip>.glb`.
  `RiggedDayi` plays them (motion is mocap, never posed by hand) and only adds HandsOnTable (small arm IK onto the felt)
  and HeadTurn (±45°). `Buddy.setup_meshy` uses it whenever a rig exists. Never scale bones at runtime: it tears the collar.
  Check a seat with `godot --path . --script tests/dayi_side_view.gd -- <out prefix> <seat index>`.
  After any change to dayıs, hands or racks run `godot --path . --headless --fixed-fps 30 --script tests/hands_clear_test.gd`:
  it fails if any hand joint enters a rack or the felt in any frame (`Rack.penetration`).
- `DayiHands` (`scripts/character/dayi_hands.gd`) makes a RiggedDayi handle real tiles: `rearrange`, `discard`, `pick_up`.
  Per hand the pinch point (thumb/index tips) is carried by arm IK, fingers close, and the Tile is locked to the hand
  (socket offset) until handed to `Rack.put` / `Table.put_loose`. Tiles leave a slot straight up (`RACK_LIFT`) before
  moving sideways; he leans in only for far reaches. `RiggedDayi.demo` makes him fiddle on his own until rules drive him.
  `godot --path . --headless --fixed-fps 30 --script tests/dayi_hands_test.gd` checks pinch accuracy, tile end
  positions, held-tile drift and that no finger goes through a rack board.
- Smoothness rules (learned the hard way: the hands jittered and wrists wrung while every still-frame test passed):
  never correct a hand per frame from its fingertips (the clip drums its fingers); HandsOnTable uses constant
  offsets found once by `calibrate()`; IK keeps the hand's rotation against the forearm and a fixed elbow pole; actions
  only flex the wrist about the hand's own axis (no aiming/twisting, no rig twist bones); the lean's direction
  eases round (DayiHands LEAN_TURN), never snaps; one IK solve per frame
  using last frame's pinch offset; each finger curls about one fixed axis. Run
  `godot --path . --headless --fixed-fps 30 --script tests/hands_smooth_test.gd` too: it compares frame-to-frame jerk
  and wrist angles against the bare clip, and look at 30 fps consecutive frames, not single screenshots.
- Godot drops SkeletonModifier3D results after each frame: outside `_process_modification` (in coroutines, `_process`,
  scripts) `get_bone_global_pose` returns the clip's pose. Anything tied to a modified bone (a held tile's offset) must
  be computed inside the modifier; tests must measure in `skeleton_updated`. A tile once hung 30 cm from the fingers
  because of this. While acting, the hand's fingers start from rest, not the clip (its finger drumming opened the pinch).
- The local player is a dayı too (`Seat.DAYIS[0]`, `--player=<kind>` overrides for testing): a RiggedDayi built with
  `first_person` (`scripts/character/first_person_arms.gd`) whose arms follow the hand pivots (`Seat.glove` /
  `left_hand`, still driven by ArmMotion and hand.gd), head folded away, camera at his eyes (`RiggedDayi.eye` ->
  `head_anchor`); rack focus sits 40% of the way from his eyes to the rack, above his shoulders. Without his Mixamo rig
  the old MPFB arms are shown. Looking at any face-up tile names it above it (hand.gd `_name_tile`, "Mavi 13").
- Atmosphere (`scripts/world/atmosphere.gd`): faint cigarette smoke on ashtrays, steam on tea glasses, dust motes in
  the lamp light. Particle size lives on the quad (process scale alone drew 1 m squares). Tea glasses are Talha's Meshy
  `cay_bardagi` (TeaGlass, physical). `tests/fps_check.gd` measures frame times; results swing a lot between runs.
- Decor (`scripts/world/decor.gd`, placed in room.gd): rainy night windows (`shaders/night_window.gdshader`), a match on
  the TV (`shaders/tv_match.gdshader`), the wood stove with firelight (`fire_light.gd`), the çay ocağı counter, wall
  clock, tear-off calendar (today's date), Meshy-made old photographs (`meshy.py photo`, `assets/textures/pictures/`),
  ceiling beams, stools. Background tables seat regulars (`scripts/world/regular.gd`): with a Mixamo rig
  (`dayi_rig/mudavim_<kind>.glb`) they are RiggedDayis like our opponents (`model`, `felt_height`, `table_edge` set for
  the round table); otherwise Meshy's clips play untouched (`assets/models/mudavim/`).
- When Mixamo's auto-rigger fails on a model, `tools/blender/rig_from_donor.py` moves another dayı's Mixamo armature
  onto Meshy's joints for that model and reuses Meshy's skin weights (fingers then carry no weight; fine far away).
- The room must look lived-in from every seat (multiplayer). `godot --path . --script tests/room_survey.gd -- <prefix>`
  renders all four seats looking ahead/left/behind/right (each viewer's own dayı hidden) into `<prefix>_sheet.png`;
  check it after changing the room. Front wall (+Z): street door, coat rack, notice board, glass cabinet, bookshelf.
  Background tables have tavla boards; regulars sit with hips 0.14 m above the seat and 4 cm forward (`regular.gd`).
- Looking at a far face-up tile (not in rack view, not your own rack) shows a TilePeek card (`scripts/ui/tile_peek.gd`)
  with that tile's face from the atlas.
- Keys 1-4 look out of that seat's eyes (`Main.view_seat`, `Seat.set_viewed`; screenshots: `--view=<0-3>`); only
  seat 0 plays. The player's dayı (`Seat.player_kind()`, eşofmanlı) sits in seat 0 for the others to see: with a
  fingerless Mixamo rig (`mixamo_import.py ... --no-fingers-ok`) as a third-person RiggedDayi that cannot handle
  tiles (DayiHands stays empty); with a full rig as the first-person body.
- Sound: `python tools/make_sounds.py` synthesises everything into `assets/audio/` (no recordings, no licences);
  `scripts/world/ambience.gd` places loops and one-shots in 3D on a "Room" reverb bus (room.gd `_sounds`).
- People moving (`scripts/world/walker.gd`, Meshy rigs with in-place walk clips, `assets/models/walkers/`):
  `scripts/world/visitors.gd` sends the çaycı round the tables with a tray and, every 35-80 s, a customer through
  the street door (hinged, `Decor.door` returns the hinge); the table's dayıs (group "dayis") turn to look.
  A sleeping cat (`Decor.cat`) breathes by the stove.
- Props must stand on real surfaces: `godot --path . --headless --script tests/floating_props_test.gd` rays down
  under every small prop (wall-hung things carry `set_meta("hung", true)`) and fails on floating or sunk ones. Model
  tops are not where their bounding box says (the left-wall shelf's ledge is 0.884 m, its lower shelf 0.235 m).
- The çaycı freezes his carry clip when he stops (`Walker.hold_pose`); the tray is posed from his wrists on
  `skeleton_updated` (`Visitors.tray_pose`). `tests/cayci_tray_test.gd` checks palms at its ends and its edge off his chest.
- `tests/fps_check.gd [-- --no-demo]` prints average and slowest-1% frame times and any hitch over 50 ms. Close the
  game first: a running copy shares the GPU and ruins the numbers. A one-off ~2 s hitch ~5 s after loading is not
  explained yet (suspect first-use shader compilation).
- Presentation (2026-10-30): `Main` plays `Intro` once per run before the menu (`--no-intro` or the "intro" setting
  skip it; `Intro.enabled` is false headless, tests switch it on), then `MainMenu`: sign drops on its chains, rack
  rises, five tiles (OYNA, KURALLAR, NASIL OYNANIR, AYARLAR, ÇIKIŞ); pages fade up while the rack sinks. Menu -> table
  and table -> menu go through `main.fade`. Each hand opens with `DealShow` (`DealShow.enabled`, "deal_show" pref;
  GameDirector._deal awaits it, any key/click skips). HUD: the turn banner drops in when the turn passes and its
  stripe blinks under 5 s; Tab/H pages fade up; the pause menu fades in/out and has Ayarlar. The last hand of a match
  gives the winner a moment (camera to his face, sparks, stamp, sting) before the board. Sfx play on a "Game" bus
  (made by Prefs, sent to "Room") so the game's sounds and the kahvehane have separate volumes.
  Screens to check by eye: `xvfb-run ... godot --path . --fixed-fps 30 --script tests/presentation_shots.gd -- <prefix> [intro|menu|deal|pause]`
  (on Windows without xvfb-run). Test: `godot --path . --headless --fixed-fps 30 --script tests/presentation_test.gd`.
- HUD facts (2026-10-30): there is no always-on score sign. Tab opens the veresiye defteri (`Hud.show_ledger`, data from
  `GameDirector._ledger_data`: columns per player, a row per hand, totals, margin notes of the last hand). Name plates
  (`Nameplate`) show only while you look at that dayı (`GameDirector._show_names`, NAME_ANGLE), carry name and colour only,
  and scale with distance. The banner shows "Sıra sende" with the clock, or a small "Sıra: <name>".
- `tests/live_hands_audit.gd` plays the real game with greedy bots and checks every hand joint, held tile, wrist snap
  (m/s^2) and board crossing in every frame (in `run_all.sh`; fails on snaps, `--strict` also on penetrations; `--shots=<prefix>`
  dumps the frames before the first fingers-under-felt). Hands pass over the board, never through (`_board_safe_path`).
  A tile on the felt just beyond his own board (the pull spot, `Bot.PULL_SPOT`) is taken with the hand hanging from a
  wrist over the board (`DayiHands.STEEP_FLEX`, `_felt_flex`): held level there, the wrist went through the board and
  the folded fingers 9 cm under the felt. The hang stays at 30-45° because the elbow hangs low (`ELBOW` pole) and
  the arm is nearly straight at that spot, so the wrist rests on the board's top edge and the thumb and curled fingers
  still touch the board's top corner (<= 2.2 cm, listed by the audit, `--strict` still fails on them). Tried and
  rejected: a raised elbow pole (any weight strong enough to lift it rolls the arm chain through ArmIK's shortest-arc
  aims and the hand hangs sideways; a plane-aligned IK did not cure it and changed the resting hands), taller
  shoulders (the whole body scales, the elbow drops further), a farther pull spot (the arm locks straight and the
  pinch falls short; the meld rows start 2 cm further on), a pull spot beside the rack's end (discard rows and the
  tea glass are there). The arm is handed from the clip in `BLEND_TIME`: blended over the whole reach, the pinch
  point ran well below its planned path.
- Mixamo downloads must use Skeleton LOD "Standard Skeleton (65)"; mixamo_import.py refuses rigs without finger bones.
- `tools/blender/neck_weights.py` (run by mixamo_import.py) gives the chin and jowls fully to the head bone; Mixamo
  splits them between head and chest and the double chin stretches when the head turns. Head turning is shared
  with the chest (Posture) so the neck itself twists little.

## Layout
```
scenes/            boot.tscn (project entry: the table with the main menu), main.tscn (the table), table.tscn, seat.tscn
scripts/main.gd    wires camera/hand/watchers/HUD; menu -> start_game(rules, bots); Esc -> pause; debug screenshots
scripts/boot.gd    puts the menu over the table unless `--play`/`--screenshot`/`--preset`/`--set` is given (`--menu` forces it)
scripts/rules/     pure 101 rules, no nodes (tests/rules_test.gd): okey_tiles (ids 0-105), meld (per/seri/çift,
                   işleme, okey swap), solver (best opening, pairs), game_settings (house rules + presets/*.json),
                   okey_game (turns, opening bar, penalties, scoring, expected tile counts), bot_brain (decisions)
scripts/camera/    focus_camera.gd: observe / rack / lean modes, depth-of-field blur, shake, cine_blend (the end-of-hand show)
scripts/world/     rounded_box, mat (materials, Poly Haven textures/models), tile + tile_factory, rack (2x15 slots, groups,
                   arrange), table (pile + count, gösterge, diagonal discard rows, meld wedges, zone_at, loose tiles),
                   seat (monobloc chair), buddy (dayı: procedural breathing, head turn, head shake),
                   sfx (Sfx.at / Sfx.ui: every game sound, counted in Sfx.played for tests),
                   room (kahvehane shell, lamps, background tables with regulars, props), flicker (TV light)
scripts/character/ appearance.gd: dayı colours + optional parts (hat, mustache), random(), apply() to a dayi.glb
tools/            fetch_polyhaven.py; blender/kit.py + dayi.py (seated dayı, head parts under a "Head" pivot),
                  hands.py (first-person hands with ring and watch), props.py (Turkish props)
scripts/play/      hand.gd: local glove, ray picking, drop targets, steal/caught (grab_check/drop_check hooks);
                   watcher.gd: where a bot looks (rack/observe/lean, notice, vigilance); game_director.gd: rules <->
                   table, player moves, turns, F/C keys, HUD; bot.gd: plays a seat with DayiHands (pull from the pile,
                   pick up, discard, lay melds) and steals (personality: vigilance, greed, swaps);
                   visibility.gd: who sees what, theft events, witnesses; stealing.gd: thefts, plant/dump,
                   "Yakala!", "Taş say!", giving tiles back, awareness meter, bots' chances and counting;
                   effects.gd: sparkle, floating text, slow motion (off headless); hand_end_show.gd: the end of a hand
                   (camera, racks tip over, chalkboard)
scripts/ui/        hud.gd: crosshair, hint, flash, status, totals, feed, rack buttons, chalkboard, score sheet;
                   post_fx.gd: vignette + grain + rack blindness + colour pulse; kahve_theme.gd: the look of every
                   screen (wood, brass, cream paper); main_menu.gd, room_setup.gd ("Masa kur": table page with seat cards + rule-set cards, rules page with search/categories/steppers; every
                   rule), pause_menu.gd (Esc), settings_menu.gd ("Ayarlar": the rows of Prefs on paper),
                   intro.gd (the opening: in from the door to the menu's camera pose, letter tiles title, any key skips),
                   fade.gd (the black curtain between intro / menu / table; `Fade.instant` headless)
scripts/play/      prefs.gd: the player's own settings (user://prefs.json: volumes, fullscreen, vsync, render scale,
                   grain, intro, deal show), applied by Prefs.apply(); deal_show.gd: the start of a hand (camera over
                   the table, tiles fly from the pile into the racks, gösterge flips, okey stamp; holds the first turn)
assets/            models/dayi/{dayi,hands}.glb + models/props/*.glb (generated, do not hand-edit),
                  polyhaven/ (CC0 downloads), CREDITS.md
```

## Commands
- Import / refresh class cache: `godot --path . --headless --import`
- Run the game: `godot --path .` (Talha uses `.\oyna.cmd`, which calls the full exe path; VS Code terminals may not see the PATH entry).
  It opens on the main menu; `godot --path . -- --play` deals at once.
- Debug screenshot (opens a window briefly, saves PNG, quits):
  `godot --path . -- --screenshot=screenshots/observe.png`. Extra flags: `--focus` (rack mode), `--yaw=<rad>` /
  `--pitch=<rad>` (head direction; negative yaw looks right), `--hold` (a tile in the glove), `--caught` (caught flash),
  `--top` (straight down on the table), `--frames=<n>`. Read the PNG to check visuals after any rendering change.
- House rules: `--preset=<klasik|kahvehane|tam_kaos|temiz>` and `--set=<key>=<value>` (e.g. `--set=turn_time_limit=2`:
  when the player's time runs out a bot plays his turn, handy for watching bots).
- Game tests (run after touching rules, table, hand, bots): `godot --path . --headless --script tests/rules_test.gd`,
  `godot --path . --headless --fixed-fps 30 --script tests/player_moves_test.gd`,
  `godot --path . --headless --fixed-fps 30 --script tests/game_flow_test.gd -- --set=turn_time_limit=1 [--hands=2]`
  (windowed: `--shots=<prefix>` saves frames, `--sheet=<png>` the score sheet; `--stealing`: greedy bots steal and
  call all through, checks that no tile is lost or doubled),
  `godot --path . --headless --fixed-fps 30 --script tests/stealing_test.gd` (every theft/catch/count case),
  `... tests/quick_moves_test.gd` (click to draw, double-click to throw, Ctrl+click groups, rack buttons, lines),
  `... tests/ui_test.gd` (menu -> Masa kur -> Başlat -> Esc -> back, through the real Boot scene),
  `... tests/hand_end_test.gd` (the end-of-hand show), `... tests/sfx_test.gd` (sounds fire where they should),
  `... tests/presentation_test.gd` (intro, deal show, settings file and page).
  Headless the window is tiny (64x64): test what a screen needs (`get_combined_minimum_size`), not where it ends up.
- The whole suite in one go (several minutes): `bash tests/run_all.sh`. Green is exit=0 and FAILS: 0 / PASS on every line.
- Screens (windowed, PNGs to read): `godot --path . --script tests/ui_shots.gd -- screenshots/ui [rack|menu|fx|end]`.
- Sounds: `python tools/make_sounds.py` (appends the game's own sounds after the room's, so those stay byte-identical).
- Files here are CRLF (Windows). A multi-line GDScript string keeps the CRs: strip them before showing it
  (`MainMenu.controls_text()`); scripted edits must match the file's line ends.
- Looking at people (windowed, PNGs to read): `godot --path . --script tests/poses_shot.gd -- screenshots/poses`
  (bowed / bent over / watching, the lean view, the "!" meter) and
  `godot --path . --fixed-fps 30 --script tests/steal_shot.gd -- screenshots/steal/steal` (a bot's long reach).

## Setup on a new machine
- Install Godot **4.7.2 standard (not .NET)** from https://godotengine.org. Either unzip to `C:\Tools\Godot\` (matches `oyna.cmd` and `.mcp.json`) or put `godot` on PATH and edit `GODOT_PATH` in `.mcp.json`.
- To change models, also unzip Blender 5.2.3 LTS (https://download.blender.org/release/Blender5.2/) to `C:\Tools\`.
- First run: `godot --path . --headless --import`, then `.\oyna.cmd`.

## Status (2026-10-29)
- Done: Phase 1 (room, table, seats, racks, tiles, deal, observe/rack camera with depth-of-field blur).
- Done: Phase 2 single-player demo.
  - Opponents are our own Blender dayıs with random Appearance (vest, cap, skin, hair colours; hat/mustache on or off).
  - Left click grabs/drops: aim with the crosshair in observe mode, with the mouse in rack mode. Reach is 1.35 m.
  - Drops go to the nearest free slot on any rack, or loose on the felt.
  - Tiles taken from another player's rack are "stolen" until dropped. If a Watcher looks at you meanwhile,
    the tile snaps back, the opponent shakes its head and the HUD shows "YAKALANDIN!".
  - Watchers glance at players every 2.5-6 s, with a short half-turn first. They show a yellow "!" when looking at you.
- Not yet: Okey rules/turns (Phase 4), multiplayer (Phase 3), sounds.
- **Direction changed (see master.md section 6):** 101 Okey, "Yakala!" key instead of automatic catching, kahvehane dayıları
  with a modular character creator. The procedural room is a throwaway placeholder.
- Done: layout pass (1.5 m table, chairs at 1.15 m, eye at 1.35 m; centre pile visible, own rack low and blurred).
- Done: kahvehane look pass (Poly Haven props/textures, moody lighting, fog, skin subsurface, cloth textures).
- Done: first-person dayı hands (the right one reaches and turns toward the tile), fingered hands on every dayı,
  higher-resolution dayı mesh, tea sets on every table, tespih by the player's left hand, semaver on the shelf.
- Realistic humans: MPFB (MakeHuman for Blender, CC0 assets) is the planned route, but installing the extension
  needs Talha's permission (the auto-mode classifier blocks installing third-party extension code).
- Done (2026-10-30): 101 is playable against three bots (plan: docs/design/101_rules.md "Table layout").
  Rack blindness; rules engine with every house rule as a setting; one pile with a count, gösterge, discard rows
  on the diagonals, meld wedges; drag to draw / take / discard; Enter opens rack groups, R auto-arranges, dropping on
  a meld işles or takes its okey; penalties, scoring, score sheet (Tab), turn timer. Bots pull the pile tile toward
  themselves (the middle is out of their reach) and use their real hands.
- Done (2026-10-30): stealing 2.0 (docs/design/stealing.md). W bends the player over the table (melds from above,
  own rack out of sight); every dayı's head/body shows how he looks (bowed = his rack, bent over = the table).
  Visibility with evidence, pluck moment and witnesses; F "Yakala!", C "Taş say!", Shift sneaks; plant and dump;
  awareness "!" over heads; bot levels (Kolay, Normal, Zor; `GameDirector.LEVELS`) that look, notice, count and steal
  with a long lean toward the target. The table is 1.5 m and arms 0.5 m: bots reach as far as they can and tiles
  glide the rest (discards slide into the row, pile tiles are pulled, stolen tiles come to the fingertips).
  A tile in flight must never outlive its hand: `GameDirector._deal` waits until no Bot is busy, and a bot's snatch
  is called off (empty hand) if he was caught reaching or the hand ended (`game_flow_test --stealing` caught this).
- Done (2026-10-30, later): 12-13-1 is no longer a run by default (house rule `run_wraps_13_1`); click to draw, double-click
  to throw, Ctrl+click groups carried together, rack buttons (best groups / pairs / by colour / by number) and counting
  lines under groups, both switchable per room ("Yardımcılar"); main menu, "Masa kur" (bot level per seat, profile name, every
  rule with its Turkish text, own rule sets saved in user://presets/), Esc pause menu; synthesised tile and UI sounds;
  tile sounds, gold sparkle on opening, floating "+101", colour pulse / shake / slow motion when caught; the end of a hand
  is a show (camera to the finisher, racks tip over face up, chalkboard counts the scores).
- Done (2026-10-30, presentation pass): opening intro, menu arrival and page transitions, fades between menu and
  table, deal show at the start of every hand, HUD banner/page animation, pause menu fade, winner moment, "Ayarlar"
  (sound/picture/shows) kept in user://prefs.json.
- Next: modes as presets (eşli 101, karanlık, hırsızlar gecesi), distractions (TV goal, table tap), stealing from laid
  melds, character creator.

## Rules
1. Keep network, camera/visual effects and Okey rules in separate modules (see master.md section 5).
2. One module per step; every step must run without errors and be checkable by screenshot or by Talha.
3. Assets: only CC0 or CC-BY. Record source URL + license in `assets/CREDITS.md` before using.
