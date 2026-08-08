# Learnings: building Aria and the Pink Star

A playbook addendum for the birthdaycade game business, building on
`xavier-game/learnings.md` and `chip-game/README.md` - distilled from adapting that
existing codebase into a third, differently-mechanic'd game.

## Reuse a working scaffold instead of starting from zero

- **Copying a sibling project's full scaffold (project.godot, touch controls, camera,
  mission-file flow) and re-theming it was much faster and lower-risk than writing a new
  game from scratch**, even though the mechanic changed substantially (platform-dig-and-build
  → free-flight-and-reveal). The proven, already-debugged pieces - touch joystick input
  handling, the smoothed camera, the level-intro/mission-file narrative flow - needed zero
  changes. Only the parts that were genuinely mechanic-specific (player movement/physics,
  hazard entities, level data format) needed a real rewrite.
- **Free-flight (no gravity, no floor, no tile collision) turned out simpler to build than
  the platformer it replaced** - no feet-probe raycasting, no "is this a safe standing spot"
  edge-case logic, no tilemap at all. When a new game's premise doesn't need solid ground,
  don't drag along physics machinery a platformer needed; it's not free complexity, it's
  cost with no matching benefit.

## Procedural art pitfalls worth re-checking every time

- **A `_new_image()`/`_fill_ellipse()` helper convention that internally multiplies
  coordinates by a SCALE constant is easy to double-apply by accident** when a later function
  reads `img.get_width()` (already physical, already-scaled pixels) and then multiplies by
  SCALE again for a *different* calculation in the same function (e.g. a random star
  scatter). Godot's `Image.set_pixel` throws hard index-out-of-bounds errors for this, which
  is at least loud and easy to catch - but it's exactly the kind of bug that's invisible
  until you actually run the generator, so run it (headless, in seconds) before assuming a
  new `_make_*` function is correct.
- **A semi-transparent color painted directly onto a flat background image via `set_pixel`
  does not blend with what's already there** - `set_pixel` overwrites, it doesn't composite.
  For "faint smear over a gradient" effects (like a nebula on a starfield), read the existing
  pixel and `Color.lerp()` toward the tint instead of writing a low-alpha color and hoping
  the renderer blends it later. This matters most for textures that are the *entire*
  background with nothing behind them at runtime - there's no lower layer for the alpha to
  composite against.

## Headless Godot testing

- **`godot --headless --path .` (running the actual game) and `godot --headless --script
  foo.gd` (running a bare SceneTree script) are not equivalent environments** - autoloads
  (singletons declared in `project.godot`) are only initialized in the former. A script that
  references an autload works fine in the real game and fails to compile ("Identifier not
  found") under `--script`, and a script parse failure inside a custom `SceneTree._initialize()`
  leaves the process hanging in a headless main loop forever (no quit() ever gets called) —
  it looks like a stall, not a compile error, unless you go check stdout/stderr yourself.
- **Newly-generated or newly-added image files are invisible to a headless project run until
  Godot writes `.import` sidecar files for them** - `godot --headless --editor
  --quit-after N` is not reliable for this (it may exit before the import scan finishes);
  `godot --headless --import .` is the correct, purpose-built flag that waits for imports to
  actually complete before quitting. Worth running once after any bulk-regeneration of
  `generated_assets/`/`imported_assets/` before trusting a subsequent headless smoke test.

## Headless tests prove existence, not legibility

- **A headless test can confirm a visual effect spawns, tweens and frees itself while the effect
  is still invisible on screen.** The pickup sparkle burst passed exactly such a test - 10 motes
  created, all freed, no leak - and could not be seen in a single screenshot of the running
  game. Same for the flight trail later. Headless answers "does this run without erroring";
  only a screenshot of the real build answers "can a player see it".
- **When something doesn't appear, exaggerate the parameter before debugging the mechanism.**
  Cranking the trail motes to ~4x size and 3s lifetime made them unmistakable in one run, which
  separated "not rendering" (a real bug) from "rendering, badly tuned" (a number to change)
  immediately. Guessing at causes in that order is much slower than making the thing enormous
  and looking.
- Corollary for capture timing: an effect tied to input will already be fading by the time an
  automated screenshot lands after the input ends. A short-lived effect can look completely
  absent in stills and still be fine in motion - so tune from a frame captured *during* the
  action, or lengthen the effect until stills can see it and then dial back deliberately.

## Tear down test harnesses at the end of a run, not the start of the next one

- **A headless Chrome left running with a WebGL game loaded sat at 224% CPU** and noticeably
  heated the machine. Godot web needs `--use-angle=swiftshader` in headless Chrome, which is
  *software* rasterisation - it renders the game continuously on the CPU with no GPU involved,
  so an idle-looking browser is anything but.
- The failure mode was a cleanup pattern of `pkill` *before* launching the next instance, which
  is invisible while iterating and always leaves the final instance alive indefinitely. Kill the
  browser when a verification run finishes; the next run can afford the ~4s to start a fresh one.

## Swapping a level means freeing the old one, not just reassigning the variable

- **`_load_level` built a new World and assigned it to `current_world` without freeing the
  previous one**, which left the old World *in the scene tree*: still processing, still holding
  a player that was still connected to the touch-control signals. Two players receiving
  identical joystick input move in perfect lockstep, so the duplicate is completely invisible -
  until one of them hits a black hole and gets pulled back to *its own* last safe position, at
  which point they separate and four characters appear at once. The bug was reported as "a bug
  from a black hole"; the black hole was only what made an older bug visible.
- **Reassigning a reference is not cleanup.** `queue_free()` also isn't immediate - it lands at
  the end of the frame, so anything that must stop responding *now* (group membership, signal
  connections) needs `remove_child()` alongside it.
- **A screen-transition guard belongs on the transition, not the widget.** The second load came
  from a double-tap on the title screen: the fade-out runs for 0.2s before the title is hidden,
  so a second tap inside that window passed the `title_screen.visible` check and started the
  whole flow again. Any `await`-ing entry point that a player can trigger twice needs a
  re-entrancy flag - on a touch screen, the accidental double-tap is the common case, not the
  edge case.
- Both halves are worth fixing: the guard stops the usual trigger, and tearing down the
  container makes *any* future double-load harmless.

## Get the stretch settings right before hand-placing a single UI element

Three separate on-device problems all traced back to two lines in `project.godot`.

- **`stretch/mode="viewport"` renders the whole game into a fixed 1920x1080 buffer and
  downsamples it to the screen.** On a modern phone - an iPhone 16 is a 3x-density display -
  that throws away most of the panel's resolution and makes text soft on top of small. For a
  game whose UI is mostly text, **`canvas_items` is the right mode**: geometry is scaled but
  glyphs are rasterised at native device resolution. This was the single biggest legibility
  win, and it's a one-word change.
- **`stretch/aspect="expand"` grows the *logical* viewport on any screen wider than the design
  aspect.** 1920x1080 is 1.78:1; an iPhone 16 in landscape is ~2.17:1, so the logical space
  becomes ~2340x1080. Anything positioned with absolute offsets against an assumed 1920 width
  - which was every screen here - ends up left of centre with a dead strip down the right, and
  it gets worse the wider the device. It's invisible at desktop aspect ratios, which is exactly
  why it survived so long.
- **The same assumption breaks full-screen rects.** Backdrops, the dim overlay and the screen
  fader were all 1920x1080 `ColorRect`s, so on a wide viewport they stopped short of the edge -
  the fader failed to cover the screen it was supposed to be fading. The world's background
  sprite had the identical problem, leaving bare strips down both sides of the level.
- Rather than re-anchor dozens of nodes, shifting each UI `CanvasLayer` by
  `(viewport - 1920x1080) / 2` re-centres a whole authored canvas in one line, and rects that
  must reach the edges get stretched to the real viewport explicitly. Layers whose contents are
  genuinely edge-anchored (the HUD, the touch controls) must be left alone or their corners
  pull inward.
- **Test at the target device's aspect ratio, not just its pixel count.** Every one of these was
  invisible in a 1200x700 desktop browser and obvious the moment the window was resized to
  852x393. Driving the real build at phone dimensions costs one flag (`--window-size`).

## `Camera2D` has no `unproject_position()`

- **That method is Camera3D-only.** Calling it on a Camera2D throws "Invalid call. Nonexistent
  function", and because the only caller was the idle-hint arrow's per-frame position update,
  it failed silently in the sense that nothing crashed the game - the hint just never moved
  from wherever it happened to be, and the errors went to a console nobody was reading during
  on-device testing. It had been wrong since the hint was written.
- **The 2D equivalent is the viewport's canvas transform:**
  `get_viewport().get_canvas_transform() * world_pos`. Verify it numerically rather than by
  eye - moving a point +600 world units right should move it +600 screen px at zoom 1, which is
  a two-line check that would have caught the original bug immediately.
- Found only because a *new* feature (flying a collected key to the HUD) needed the same
  world→screen conversion and was exercised in a headless test that surfaced the error. Reusing
  a broken helper is a good way to finally discover it's broken.

## Don't let a "find it" beat and a "get it" beat collapse into one frame

- **Revealing a collectible enabled its collision at the same moment it started fading in**, so
  revealing a key you were already standing on collected it instantly, at alpha ~0. The player
  got no key sprite, no visible pickup - just a bar quietly growing in a corner of the HUD.
  Both halves worked correctly in isolation; the bug was that they happened simultaneously.
- The fix is to **withhold collision until the reveal animation finishes**, so the object
  visibly exists before it can be taken. And when enabling `monitoring` on an Area2D that a
  body may *already* be standing inside, `body_entered` won't fire (it only reports crossings) -
  check `get_overlapping_bodies()` explicitly after a physics frame.
- **Reward feedback should trace a path, not just update a number.** Flying a copy of the key
  from the pickup point to the HUD meter, and delaying the meter's fill until it lands, turns
  two disconnected events into one legible cause-and-effect.

## A control the player can't see is a control they don't know exists

- **The virtual joystick was fully transparent until touched.** For anyone who hadn't played a
  twin-stick-style game before - the actual target audience here - nothing on screen suggested
  flying was possible at all. It now rests visibly (dimmed) at its parked spot, returns there
  on release instead of fading away, and traces a slow looping orbit until the first real drag
  to demonstrate the gesture. Touch-anywhere still works; only the discoverability changed.
- A tutorial card saying "DRAG TO FLY" is not a substitute for the control being visible during
  play - the card is gone in seconds and never shown again.

## An emitted signal nobody connected is a missing feature, not dead code

- **`all_keys_collected` was emitted correctly and had zero listeners**, which meant the one
  moment the level's goal changes - from "hunt for the key" to "fly home" - happened in total
  silence: no sound, no visual, and a home portal that looked exactly the same whether it was
  shut or open. The only way to discover home had opened was to fly into it and find out. The
  signal existing made this easy to miss in review, because the emit site looked finished.
- **A state change only reads if there's a distinct prior state to read against.** Lighting up
  the portal wasn't enough on its own; it needed a visibly *dormant* look first (dim,
  desaturated, slow pulse) so the flare has something to contrast with. Worth grepping for
  `signal` declarations with no matching `.connect(` when hunting for gaps like this.
- The same reasoning applies to the idle hint arrow, which pointed at the nearest collectible
  and simply hid itself once they were all collected - i.e. it went quiet during precisely the
  stretch where the player was most likely to be lost. It now falls back to pointing at the
  portal.

## Godot's built-in font has no glyphs beyond basic Latin

- **A `"▶"` (U+25B6) in button text rendered as a tofu box in the web export** - and Godot's
  tofu is not a blank rectangle, it draws the literal codepoint ("25B6") in a tiny 2x2 grid
  inside a box, which looks unmistakably broken. This was on the level-intro START button and
  the tutorial's NEXT button: screens every player taps through on the way into every level.
  The project uses no custom font, so it gets Godot's built-in Open Sans subset, which covers
  basic Latin and little else. Arrows, emoji, box-drawing, and most symbols are all absent.
- **The fix that fits an all-procedural art pipeline is to generate the glyph as a texture and
  use `Button.icon`** (plus `icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT` to sit it after the
  word) rather than hunting for a symbol the default font happens to include. Guaranteed to
  render, and it stays consistent with how every other icon in the game is made. Note that
  `icon_alignment = RIGHT` pins the icon to the *button's* right edge, so the button has to be
  sized close to its content or the icon strands itself in empty space.
- Worth grepping sibling projects for non-ASCII characters in `text =` assignments - they share
  the same no-custom-font setup, so the same bug can hide in any of them.

## Check what a UI element animates *from*, not just what it animates to

- **The key meter tweened to its correct value on level load, but its scene-authored starting
  width was full** - so every level opened with the progress bar visibly draining from full to
  empty before gameplay began. It read as losing progress at the exact moment the player should
  feel they're starting fresh. Nothing was wrong with the tween or the value it computed; the
  bug was entirely in the unexamined initial state it animated away from. A "set instantly on
  first bind, tween only on subsequent changes" split is the general fix, and it's worth
  applying to any HUD element whose scene default isn't its real zero state.

## Work out how big a sprite actually lands on the target screen before buying more art

- **"Would it look better with animation frames?" is an arithmetic question first.** The hero
  sprite here is 128px in a 1920x1080 design space. On the phone the game is actually played on,
  1080 logical units map to roughly 393 CSS px in landscape, so she lands at about **47 CSS px**
  - and around **26** in portrait. At that size a leg cycle or mane flutter is invisible, and
  paying an image-generation service per frame buys detail the screen throws away.
- **At small sizes, distinct state poses beat animation cycles.** A "stuck", "scared" or
  "celebrating" pose changes silhouette and colour, so it reads at 26px *and* communicates game
  state - which is functional, not decorative. A six-frame idle cycle does neither.
- **Scaling the existing sprite up is nearly free and usually wins first.** Scale the *sprite*
  and leave the collision shape alone, so the character reads bigger without quietly making
  hazards harder to dodge.
- **More AI-generated frames carry a consistency risk that can lower polish.** Each generation
  is independent, so hue and proportion drift between frames reads as flicker - visibly worse
  than one clean static sprite. Motion that costs nothing and cannot drift (squash-and-stretch
  along travel, a particle wake, banking into turns) is the safer spend, and reads at any size.
- The same arithmetic answers UI questions: a 36-unit font is ~13 CSS px on that phone. Convert
  design units to real device pixels *before* choosing any size or level of detail.

## Mechanic/UX decisions carried forward from Xavier's game, reconfirmed here

- **One clear verb per button, even with two buttons, beats one button doing two different
  contextual things.** Xavier's game learned "one button beats two"; here, with an
  age-7 audience (vs. age-5) and a premise that needs two genuinely different actions (find
  vs. unstick), splitting them into two clearly-iconed buttons - rather than one
  contextually-morphing button - was the right call specifically *because* each button's
  meaning never changes. Contextual morphing (like Chip's jump/drill button) is worth it when
  a single verb covers both cases; it's not when the two actions are conceptually unrelated.
- **No permanent failure states, again.** Every hazard here (black hole, sticky trap,
  asteroid) resolves to "you lose a few seconds, not your progress" - same principle as
  Xavier's bonk-and-retry, applied to three different hazard types instead of one.

## Sprixen API, reconfirmed

- Both quirks documented in `xavier-game/README.md` reproduced exactly the same way here:
  `viewAngle: front_facing` must be set on `POST /v1/projects`, not the per-generation
  prompt; and `creditsUsed` on a single-image generation was 2, double the naive per-image
  expectation. Worth trusting these as stable platform behavior, not one-off flukes.

## The pixel font (added 2026-08-07)

Aria shipped rendering every label in Godot's built-in fallback, **Open Sans
SemiBold** — a smooth modern sans — on top of pixel art. Nothing was broken,
so it never surfaced as a bug; it just made the game look like a prototype,
and it looked inconsistent next to the sibling games once they were
converted. `procedural_font.gd` (shared, byte-identical with `chip-game` and
`xavier-game`) generates a 5x7 pixel font in code: no `.ttf`, nothing to
license.

**A pixel font is visually larger than Open Sans at the same nominal size**,
because the sans's em includes ascender/descender space the pixel font
doesn't use. Every screen overflowed and each one needed measuring:

| Element | Was | Now | Why |
|---|---|---|---|
| Title | 104 | 91, wider box | measured 1848 units in a 1600 box — "STAR" ran off screen |
| Prologue | 46 | 46, taller box | wrapped to 3 lines (180) in a 136 box, collided with the level buttons |
| Tutorial caption | 88 | 70 | longest caption measured 1800 in a 1600 box |
| Level title | 100 | 84 | "The Sticky Pink Planet" measured 1848 |
| Level story | 56 | 42, bigger box | wrapped to 4 lines (320) in a 200 box |

The arithmetic is worth doing rather than eyeballing: glyph advance is 6
units at scale `floor(font_size / 7)`, and line height is 10 units at that
same scale. That predicted every overflow exactly.

One correction the calculation *doesn't* give you: **word wrapping breaks at
noticeably fewer characters than a raw width division suggests.** The
prologue fit ~38 chars per line where the arithmetic said 46, so it stayed
three lines after the first attempt at widening. Screenshot after each pass.

## `outline_size` silently does nothing with a bitmap font

The MELT and FIND button labels used `theme_override_constants/outline_size`
with a dark outline colour to stay legible on a bright pink button. A bitmap
`FontFile` has no outline cache, so the outline renders nothing at all — no
error, the text just quietly loses its contrast. Replaced with dark text,
which is what the outline was simulating anyway.

Both labels were also sitting in the bottom ~20% of a *circular* button,
where the circle has curved in and the outer letters fall onto the dark
background — "FIND" read as half-missing. Moved up into the solid band
between the icon and the rim, after checking the chord width at that height
(FIND is 144 units wide in a 322-unit chord).

## Three bugs inherited from the shared scaffold (2026-08-07)

All three were already known and fixed in a sibling repo. None of the fixes
crossed, because nothing links the copies. This is the whole argument for
diffing the scaffold files whenever a project is picked back up.

- **The stuck touch button.** `touch_button.gd` handled release only inside
  `_gui_input`, but a Godot Control never *captures* a touch for the rest of
  its gesture - `_gui_input` fires only for events landing inside the rect at
  that instant. A finger lifting a few pixels outside (a kid's tap, or any
  fast tap) never delivered the release, `_is_pressed` stayed true forever,
  and the guard in `_press()` silently swallowed every later tap. MELT and
  FIND would just stop working. Fixed in `xavier-game` in July; this game
  shipped it live regardless.

- **Stale tutorial auto-advance timers.** Each card created a
  `SceneTreeTimer` and never cancelled it, so tapping NEXT left the outgoing
  card's timer pending; it fired partway through the next card and advanced
  again. A few taps could rattle through the whole tutorial in about a
  second.

- **The generated-asset probe.** `FileAccess.file_exists()` on a
  `res://generated_assets/*.png` path always returns false in an exported
  build, because the source PNGs aren't shipped - they become imported
  `.ctex` resources. So the game regenerated its entire art set on every
  single launch, on the device, before the title screen. Caught only because
  the browser console still printed `ProceduralArt: all textures generated`
  in a production build. Use `ResourceLoader.exists()`, which understands
  the import remaps. **Fourth** incarnation of this exact bug in this series.

Each fix was proven with a control run that deliberately defeated it and
confirmed the bug returned - otherwise you don't know your change is what's
doing the work.

## Known, not fixed: stale UIDs in scene files

The browser console reports `invalid UID ... using text path instead` for
several `generated_assets/` textures referenced from `.tscn` files.
`generated_assets/` is gitignored and rebuilt by `build.sh`, which assigns
fresh UIDs on each import, while the scenes still carry the UIDs from
whenever they were authored. Godot falls back to the text path and everything
loads correctly, so this is console noise rather than a defect - but it will
recur on every fresh checkout, and it buried a real warning
(`ProceduralArt: all textures generated`) until it was read carefully.
## The loading screen was advertising Godot, not birthdaycade

For the whole ~38MB wasm download - by far the longest-lived screen in the
product, and the very first thing a kid sees - every game showed the Godot
robot and the words "Game engine". It is entirely replaceable, and the
mechanism is worth writing down because it is spread across three places:

- **`application/boot_splash/image`** is what the web export writes out as
  `index.png`, and the HTML shell references it as `src="index.png"`. Set
  this and the logo is gone. None of the games had it set, so all three
  inherited the engine default.
- **`application/boot_splash/bg_color`** feeds the `$GODOT_SPLASH_COLOR`
  placeholder, which colours the loading overlay behind the image.
- **`application/boot_splash/use_filter`** feeds `$GODOT_SPLASH_CLASSES`;
  `false` yields `use-filter--false`, which is `image-rendering: pixelated`.
  Essential for pixel art, otherwise the splash is smoothed as it scales.

Three traps:

- **Hardcoding a value where the template has a placeholder silently
  disconnects the project setting.** A shell copy here had a literal
  `#242424` where stock has `$GODOT_SPLASH_COLOR`, and literal splash
  classes where stock has `$GODOT_SPLASH_CLASSES` - so `bg_color` and
  `use_filter` were being ignored entirely.
- **Only a fixed set of `$GODOT_*` placeholders is substituted**:
  `CONFIG`, `HEAD_INCLUDE`, `PROJECT_NAME`, `SPLASH`, `SPLASH_CLASSES`,
  `SPLASH_COLOR`, `THREADS_ENABLED`, `URL`. Anything else ships as literal
  text. A shell here had invented `$GODOT_ICON32_PNG` /
  `$GODOT_ICON180_PNG`, which shipped verbatim into production - so the
  favicon and the add-to-home-screen icon were both broken links. Use
  `$GODOT_HEAD_INCLUDE`, which Godot fills with the correct icon tags.
- **The stock shell's bootstrap script is load-bearing** (feature
  detection, service-worker fallback, failure reporting). Patch its CSS;
  don't retype it.

**Capturing the loading screen needs network throttling.** Served from
localhost it is over in under 250ms, so an ordinary screenshot always lands
on the title screen and it looks like nothing changed. Drive it over CDP
with `Network.emulateNetworkConditions` (~10 Mbps) and shoot on a timer
*without* awaiting the load event.
