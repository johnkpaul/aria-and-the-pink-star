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
