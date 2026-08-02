# Aria and the Pink Star

**▶ Play: <https://johnkpaul.github.io/aria-and-the-pink-star/>**

A 10-minute, 4-level free-flight touch game for a 7-year-old: Aria, a colorful friendly
unicorn, is stranded in outer space with her little brother. Find 3 hidden keys and the
pink gem, dodge black holes and asteroids, dissolve sticky pink traps, and fly home. Built
for Godot 4.2+, mobile web first. Every texture and sound is generated in code, with one
deliberate exception: Aria's and her brother's sprites are real AI-generated images (via
[Sprixen](https://sprixen.com)) checked into `imported_assets/` — see "Art pipeline" below.

## Opening in Godot

1. Install Godot 4.2 or later (the [Standard build](https://godotengine.org/download), not
   .NET/C# — this project is pure GDScript).
2. Open Godot, choose **Import**, and select the `project.godot` file in this folder.
3. On first open, Godot will import the project. Press **F5** (or the Play button) to run.
   `main.gd` automatically calls `ProceduralArt.run_all()` if `generated_assets/` is empty,
   so the very first run may take an extra second to generate all sprites before the title
   screen appears.
4. If you regenerate `generated_assets/` or `imported_assets/` outside the editor (e.g. via
   `godot --headless --script scripts/procedural_art.gd`), run
   `godot --headless --import .` once afterward so Godot writes the `.import` sidecar files
   — without that pass, a headless `--path .` run fails to load the new PNGs at all
   ("no resource loaders" / "no loader found for resource"), even though the files exist.

## The mechanic

Aria flies freely in 2D space (no gravity, no floor) — the joystick drives her velocity on
both axes directly. Two action buttons:

- **Reveal Light** — finds and reveals the nearest hidden key or gem within range.
- **Dissolve Light** — melts the sticky pink trap currently holding her, if she's stuck in one.

Hazards, all no-permanent-failure:

- **Black holes** — drift too close and a gentle pull tugs her in; cross the event horizon
  and she's snapped back to her last safe position with a brief flash. No game over, no
  progress lost.
- **Sticky pink traps** — freeze her in place until Dissolve Light is used on the trap she's
  stuck in, which then melts away permanently.
- **Asteroids** — drift slowly and bounce her back a short distance on contact. No penalty.

Each of the first 3 levels hides one key behind its own hazard mix (asteroid field, sticky
planet, black hole belt); the 4th and final level hides the pink gem and opens the home
portal once it's found.

## Testing on desktop

Desktop testing uses your mouse as a stand-in for touch:

- `input_devices/pointing/emulate_touch_from_mouse` is enabled in `project.godot`, and
  `touch_controls.gd` also listens for `InputEventMouseButton`/`InputEventMouseMotion`
  directly, so the left mouse button drives the joystick (left half of the screen) and the
  two action buttons (right half) exactly like a finger would.
- There is **no keyboard control scheme** — this is intentional. The game is touch-native.
- Run the project with F5 and click-drag on the left half of the window to fly Aria, and
  click the circular buttons on the right for Reveal Light / Dissolve Light.

## Exporting for mobile web

1. In the Godot editor, open **Project > Export…**. The `export_presets.cfg` in this repo
   already defines a **Web** preset (HTML5, canvas resizes to fill the browser window,
   headless export). You'll need the Godot **Web export templates** installed (Editor >
   Manage Export Templates).
2. Either export from the editor UI, or run the automation script from a terminal:
   - macOS/Linux: `./build.sh`
   - Windows: `build.bat`
   Both scripts (a) regenerate `generated_assets/` via
   `godot --headless --script scripts/procedural_art.gd`, then (b) export the "Web" preset
   to `build/web/index.html`. Set `GODOT_BIN` if `godot` isn't on your `PATH`.
3. Serve `build/web/` over HTTP (opening `index.html` via `file://` will not work — browsers
   block the WASM/threading requirements). Locally: `cd build/web && python3 -m http.server`.

### Mobile audio note

Browsers block audio playback until the user interacts with the page. `main.gd` calls
`ProceduralAudio.unlock_audio()` on the first tap on the title screen, which plays a
near-silent buffer to wake the browser's audio context before the background music starts.

## Customizing the Mission File message

The home reveal at the end of Level 4 is controlled by `GameManager.custom_mission_message`
(set it before Level 4 finishes) or, more simply, by editing the **Custom Message** export
variable directly on the `MissionFile` node/scene (`scenes/mission_file.tscn` →
`mission_file.gd` → `@export var custom_message`). It defaults to
`"A SPECIAL SURPRISE IS WAITING FOR YOU"` — edit this string to reveal your own family news
instead.

## Browser deployment notes

- **GitHub Pages** (what this repo uses): run `./deploy.sh`, which rebuilds the export and
  force-pushes `build/web/` to the `gh-pages` branch as a single commit, so the ~38MB
  `index.wasm` never accumulates history. Pages serves over HTTPS, which the WASM build needs
  for its secure context.
  - Pages cannot send custom headers, so this only works because the export doesn't need
    cross-origin isolation (`COOP`/`COEP`). Godot's web build only requires those when
    **thread support is enabled** in the export preset — leave it off and plain static hosting
    is fine. If you ever turn threads on, Pages will stop working and you'll need a host that
    can set headers (or a `coi-serviceworker` shim).
- **Netlify / Vercel / any static host**: drag-and-drop or deploy the `build/web/` folder
  directly — no build step is required on the host side.
- Make sure your host serves `.wasm` files with the `application/wasm` MIME type (most modern
  static hosts do this correctly out of the box).
- The game locks to landscape orientation and requests fullscreen-friendly canvas resizing —
  test on an actual phone in landscape before sharing the link.

## Project layout

```
project.godot              Window/stretch/input config, autoloads
default_bus_layout.tres    Master/SFX/BGM audio buses
imported_assets/           Real (non-procedural) art - Aria and her brother sidekick
generated_assets/          Everything else - regenerated by ProceduralArt, git-ignored
scenes/                    All .tscn scene files
scripts/
  game_manager.gd           Autoload: level index + this-level key/gem-found state
  procedural_audio.gd        Autoload: generates & plays all SFX/BGM
  procedural_art.gd          Generates every non-hero PNG into generated_assets/
  level_data.gd               4 levels as ASCII hazard/pickup grids (no walls/tiles)
  world_generator.gd           Builds a level: hazards, collectible, home portal
  player.gd                    Aria: free-flight movement, reveal/dissolve, hazard reactions
  collectible.gd                Hidden key/gem: invisible until revealed, then collectible
  black_hole.gd / sticky_trap.gd / asteroid.gd   The three hazard types
  touch_controls.gd / touch_button.gd   Joystick (both axes) + two action buttons
  camera_follow.gd              Smoothed, bounds-clamped camera
  ui_manager.gd                 Key/gem meter, idle hint
  mission_file.gd                End-of-game home reveal screen
  main.gd                        Title -> Level 1-4 -> Mission File flow
build.sh / build.bat        Generate assets + export the Web build
export_presets.cfg          HTML5 "Web" export preset
```

## Art pipeline

Aria and her brother are real images from [Sprixen](https://sprixen.com), an AI sprite
generator, checked into `imported_assets/` — **not** regenerated by `procedural_art.gd`,
which only draws hazards, pickups, backgrounds, and UI into the git-ignored
`generated_assets/`.

- `aria_sprite.png` / `brother_sprite.png` - single front-facing standing poses. There's no
  separate walk/hurt artwork; all reactions (idle bob, facing flip, get-stuck, pulled-back
  flash) are conveyed with code-driven tweens in `player.gd` instead, so a new reaction never
  needs new art.
- Two API quirks carried over from earlier games in this series, confirmed again here:
  (1) Sprixen forces a "side-scroller" camera angle unless `viewAngle: front_facing` is set
  at the *project* level (`POST /v1/projects`) - the per-generation prompt alone doesn't
  override it; (2) credits charged were 2x the per-generation nominal cost in practice.

## Design constraints (for future contributors)

- Everything is generated via `Image`/`AudioStreamWAV` APIs, except Aria's and her brother's
  sprites (see "Art pipeline" above) - that's a deliberate, documented exception.
- No keyboard `InputMap` entries — touch (and mouse-as-touch for desktop testing) only.
- Two action buttons (Reveal Light, Dissolve Light), each clearly iconed - one verb each,
  never contextual/morphing, so a 7-year-old always knows what a tap will do.
- Every hazard is visible and learnable, never a hidden-timer gamble.
- No permanent failure states: every hazard interaction is a short, undoable detour - a
  pull-back, a freeze-until-dissolved, or a bounce - never a game-over screen or lost
  progress.
