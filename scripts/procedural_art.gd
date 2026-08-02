extends SceneTree
class_name ProceduralArt

## Generates every non-hero game texture at runtime/editor-time and saves
## PNGs to res://generated_assets/. Aria and her brother sidekick are the
## two deliberate exceptions - real AI-generated art from Sprixen, checked
## into res://imported_assets/ (see README's "Art pipeline" section).
##
## Callable two ways:
##   1. Headless CLI: `godot --headless --path . --script scripts/procedural_art.gd`
##   2. From game code: `ProceduralArt.run_all()` (pure static call, no instancing needed)

const OUT_DIR := "res://generated_assets/"

## Every _make_* function below thinks and draws in "classic" logical
## pixel-art coordinates - the primitive draw helpers (_new_image,
## _fill_rect, _fill_circle, ...) transparently multiply everything by
## SCALE before touching real pixels, so a phone screen still gets
## genuinely fine detail instead of just a bigger blurry blow-up.
const SCALE := 4

const PINK := Color8(0xFF, 0x6E, 0xC7)
const LIGHT_PINK := Color8(0xFF, 0xB3, 0xE6)
const DARK_PINK := Color8(0xCC, 0x2E, 0x8F)
const GOLD := Color8(0xFF, 0xD9, 0x4D)
const LIGHT_GOLD := Color8(0xFF, 0xEC, 0xA8)
const GEM_PINK := Color8(0xFF, 0x4D, 0xB8)
const SPACE_NAVY := Color8(0x12, 0x0B, 0x2E)
const SPACE_PURPLE := Color8(0x3A, 0x1F, 0x6E)
const STAR_WHITE := Color8(0xFF, 0xFF, 0xFF)
const VOID_BLACK := Color8(0x05, 0x02, 0x0A)
const ASTEROID_GREY := Color8(0x8A, 0x82, 0x8F)
const ASTEROID_DARK := Color8(0x4A, 0x44, 0x4E)
const GOO_PINK := Color8(0xFF, 0x8F, 0xD6)
const GOO_DARK := Color8(0xC7, 0x3F, 0x9E)
const SLATE_GREY := Color8(0x7A, 0x8B, 0x99)

const TRANSPARENT := Color(0, 0, 0, 0)


func _initialize() -> void:
	run_all()
	quit()


static func run_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	_save(_make_key(), "key")
	_save(_make_gem(), "gem")

	_save(_make_background_space(), "background_space")
	_save(_make_mission_scene(), "mission_scene")

	_save(_make_meter_frame(), "ui_meter_frame")
	_save(_make_meter_fill(), "ui_meter_fill")
	_save(_make_portal(), "portal")

	_save(_make_joystick_base(), "joystick_base")
	_save(_make_joystick_thumb(), "joystick_thumb")
	_save(_make_button_base(), "button_base")

	_save(_make_icon_reveal(), "icon_reveal")
	_save(_make_icon_dissolve(), "icon_dissolve")
	_save(_make_icon_arrow_hint(), "icon_arrow_hint")
	_save(_make_icon_lock(), "icon_lock")
	_save(_make_icon_play(), "icon_play")

	_save(_make_black_hole_core(), "black_hole_core")
	_save(_make_black_hole_swirl(), "black_hole_swirl")
	_save(_make_sticky_trap(), "sticky_trap")
	_save(_make_asteroid(), "asteroid")

	_save(_make_reveal_pulse(), "reveal_pulse")
	_save(_make_sparkle(), "sparkle")

	print("ProceduralArt: all textures generated in ", OUT_DIR)


static func _save(img: Image, name: String) -> void:
	var path := OUT_DIR + name + ".png"
	var err := img.save_png(path)
	if err != OK:
		push_error("ProceduralArt: failed to save %s (err %d)" % [path, err])


static func _new_image(w: int, h: int) -> Image:
	var img := Image.create(w * SCALE, h * SCALE, false, Image.FORMAT_RGBA8)
	img.fill(TRANSPARENT)
	return img


static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, color)


static func _fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	r *= SCALE
	var minx := int(max(0, cx - r))
	var maxx := int(min(img.get_width() - 1, cx + r))
	var miny := int(max(0, cy - r))
	var maxy := int(min(img.get_height() - 1, cy + r))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx := px + 0.5 - cx
			var dy := py + 0.5 - cy
			if dx * dx + dy * dy <= r * r:
				img.set_pixel(px, py, color)


static func _stroke_circle(img: Image, cx: float, cy: float, r: float, thickness: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	r *= SCALE
	thickness *= SCALE
	var minx := int(max(0, cx - r - 1))
	var maxx := int(min(img.get_width() - 1, cx + r + 1))
	var miny := int(max(0, cy - r - 1))
	var maxy := int(min(img.get_height() - 1, cy + r + 1))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx := px + 0.5 - cx
			var dy := py + 0.5 - cy
			var dist := sqrt(dx * dx + dy * dy)
			if dist <= r and dist >= r - thickness:
				img.set_pixel(px, py, color)


static func _fill_diamond(img: Image, cx: float, cy: float, w: float, h: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	w *= SCALE
	h *= SCALE
	var minx := int(max(0, cx - w / 2.0))
	var maxx := int(min(img.get_width() - 1, cx + w / 2.0))
	var miny := int(max(0, cy - h / 2.0))
	var maxy := int(min(img.get_height() - 1, cy + h / 2.0))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = absf(px + 0.5 - cx) / (w / 2.0)
			var dy: float = absf(py + 0.5 - cy) / (h / 2.0)
			if dx + dy <= 1.0:
				img.set_pixel(px, py, color)


static func _fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	rx *= SCALE
	ry *= SCALE
	var minx := int(max(0, cx - rx))
	var maxx := int(min(img.get_width() - 1, cx + rx))
	var miny := int(max(0, cy - ry))
	var maxy := int(min(img.get_height() - 1, cy + ry))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = (px + 0.5 - cx) / rx
			var dy: float = (py + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, color)


static func _stroke_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, thickness: float, color: Color) -> void:
	cx *= SCALE
	cy *= SCALE
	rx *= SCALE
	ry *= SCALE
	thickness *= SCALE
	var minx := int(max(0, cx - rx - 1))
	var maxx := int(min(img.get_width() - 1, cx + rx + 1))
	var miny := int(max(0, cy - ry - 1))
	var maxy := int(min(img.get_height() - 1, cy + ry + 1))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = (px + 0.5 - cx) / rx
			var dy: float = (py + 0.5 - cy) / ry
			var d: float = dx * dx + dy * dy
			if d <= 1.0 and d >= (1.0 - thickness / max(rx, ry)) * (1.0 - thickness / max(rx, ry)):
				img.set_pixel(px, py, color)


## Softly tints an existing region toward `color` by reading and lerping
## each pixel already there, rather than overwriting it - used for nebula
## smears on a background texture that has nothing else behind it at
## runtime, so a genuinely transparent overwrite would just look washed
## out instead of blending with the sky gradient beneath it.
static func _blend_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color, amount: float) -> void:
	cx *= SCALE
	cy *= SCALE
	rx *= SCALE
	ry *= SCALE
	var minx := int(max(0, cx - rx))
	var maxx := int(min(img.get_width() - 1, cx + rx))
	var miny := int(max(0, cy - ry))
	var maxy := int(min(img.get_height() - 1, cy + ry))
	for py in range(miny, maxy + 1):
		for px in range(minx, maxx + 1):
			var dx: float = (px + 0.5 - cx) / rx
			var dy: float = (py + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var existing := img.get_pixel(px, py)
				img.set_pixel(px, py, existing.lerp(color, amount))


static func _draw_line(img: Image, x0: float, y0: float, x1: float, y1: float, thickness: float, color: Color) -> void:
	x0 *= SCALE
	y0 *= SCALE
	x1 *= SCALE
	y1 *= SCALE
	thickness *= SCALE
	var dist := Vector2(x0, y0).distance_to(Vector2(x1, y1))
	var steps := int(maxi(1, ceili(dist)))
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var px := lerpf(x0, x1, t)
		var py := lerpf(y0, y1, t)
		var r := thickness / 2.0
		for oy in range(-ceili(r), ceili(r) + 1):
			for ox in range(-ceili(r), ceili(r) + 1):
				if Vector2(ox, oy).length() <= r:
					var ix := int(px) + ox
					var iy := int(py) + oy
					if ix >= 0 and iy >= 0 and ix < img.get_width() and iy < img.get_height():
						img.set_pixel(ix, iy, color)


static func _fill_triangle_up(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	x *= SCALE
	y *= SCALE
	w *= SCALE
	h *= SCALE
	for py in range(h):
		var t := float(py) / float(h - 1) if h > 1 else 0.0
		var half_w := (t * w) / 2.0
		var cx := x + w / 2.0
		var minx := int(round(cx - half_w))
		var maxx := int(round(cx + half_w))
		for px in range(minx, maxx + 1):
			if px >= 0 and (y + py) >= 0 and px < img.get_width() and (y + py) < img.get_height():
				img.set_pixel(px, y + py, color)


## Deterministic per-call RNG so repeated builds produce byte-identical
## textures (useful for diffing generated_assets/ across regenerations).
static func _rng(seed_val: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	return rng


# ---------------------------------------------------------------------------
# Key & gem (the hunted collectibles)
# ---------------------------------------------------------------------------

static func _make_key() -> Image:
	var img := _new_image(32, 32)
	_fill_circle(img, 11, 11, 7, GOLD)
	_fill_circle(img, 11, 11, 3.5, TRANSPARENT)
	_stroke_circle(img, 11, 11, 7, 2, LIGHT_GOLD)
	_fill_rect(img, 11, 15, 4, 13, GOLD)
	_fill_rect(img, 15, 22, 4, 3, GOLD)
	_fill_rect(img, 15, 26, 3, 3, GOLD)
	return img


static func _make_gem() -> Image:
	var img := _new_image(40, 40)
	var c := 20.0
	_fill_diamond(img, c, c, 40 * 0.75, 40 * 0.9, GEM_PINK)
	_fill_diamond(img, c, c - 40 * 0.05, 40 * 0.4, 40 * 0.5, LIGHT_PINK)
	for y in range(40 * SCALE):
		for x in range(40 * SCALE):
			var lx: float = (x + 0.5) / SCALE
			var ly: float = (y + 0.5) / SCALE
			var dx: float = absf(lx - c) / (40 * 0.375)
			var dy: float = absf(ly - c) / (40 * 0.45)
			var d: float = dx + dy
			if d <= 1.0 and d > 0.85:
				img.set_pixel(x, y, DARK_PINK)
	return img


# ---------------------------------------------------------------------------
# Backgrounds
# ---------------------------------------------------------------------------

static func _make_background_space() -> Image:
	var img := _new_image(480, 270)
	var h := img.get_height()
	var w := img.get_width()
	for y in range(h):
		var t := float(y) / float(h - 1)
		var col := SPACE_NAVY.lerp(SPACE_PURPLE, t)
		for x in range(w):
			img.set_pixel(x, y, col)

	# A faint pink nebula smear, not a hard shape - blended into the
	# gradient already there rather than overwritten.
	_blend_ellipse(img, 340, 60, 90, 40, PINK, 0.16)
	_blend_ellipse(img, 90, 180, 80, 45, PINK, 0.12)

	var rng := _rng(7)
	for i in range(140):
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h - 1)
		var bright: float = rng.randf_range(0.4, 1.0)
		img.set_pixel(x, y, Color(STAR_WHITE.r, STAR_WHITE.g, STAR_WHITE.b, bright))
	for i in range(18):
		var x := rng.randi_range(2, w - 3)
		var y := rng.randi_range(2, h - 3)
		_fill_circle(img, x, y, 1.4, STAR_WHITE)
	return img


static func _make_mission_scene() -> Image:
	var img := _new_image(480, 270)
	var w := img.get_width()
	var h := img.get_height()

	for y in range(h):
		var t: float = float(y) / float(h - 1)
		var col: Color = SPACE_PURPLE.lerp(Color(0.35, 0.08, 0.28), t)
		for x in range(w):
			img.set_pixel(x, y, col)

	var rng := _rng(21)
	for i in range(100):
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(0, h / 2)
		var bright: float = rng.randf_range(0.4, 1.0)
		img.set_pixel(x, y, Color(STAR_WHITE.r, STAR_WHITE.g, STAR_WHITE.b, bright))

	# The home planet: a warm pink-gold sphere with a soft ring, low in
	# frame so the reveal reads as "you can see it now, almost there".
	var cx := 240.0
	var cy := 210.0
	_stroke_ellipse(img, cx, cy, 150, 26, 4, LIGHT_PINK)
	_fill_circle(img, cx, cy, 70, GOLD)
	_fill_circle(img, cx - 18, cy - 18, 45, LIGHT_GOLD)
	_stroke_circle(img, cx, cy, 70, 3, PINK)
	return img


# ---------------------------------------------------------------------------
# UI meters & portal
# ---------------------------------------------------------------------------

static func _make_meter_frame() -> Image:
	var img := _new_image(128, 16)
	_fill_rect(img, 0, 0, 128, 16, SLATE_GREY)
	_fill_rect(img, 2, 2, 124, 12, VOID_BLACK)
	return img


static func _make_meter_fill() -> Image:
	var img := _new_image(124, 12)
	_fill_rect(img, 0, 0, 124, 12, PINK)
	_fill_rect(img, 0, 0, 124, 3, LIGHT_PINK)
	return img


## The home portal: a glowing oval, gold core inside a pink ring, so it
## reads as "the way home" (warm, inviting) distinct from a black hole's
## cold dark void even at a glance.
static func _make_portal() -> Image:
	var img := _new_image(16, 32)
	_fill_ellipse(img, 8, 16, 7, 15, PINK)
	_fill_ellipse(img, 8, 16, 5.5, 13, LIGHT_PINK)
	_fill_ellipse(img, 8, 16, 3.5, 10, LIGHT_GOLD)
	_stroke_ellipse(img, 8, 16, 7, 15, 2, DARK_PINK)
	return img


# ---------------------------------------------------------------------------
# Touch controls
# ---------------------------------------------------------------------------

static func _make_joystick_base() -> Image:
	var img := _new_image(120, 120)
	var c := 60.0
	var col := SPACE_PURPLE
	col.a = 0.55
	_fill_circle(img, c, c, 58, col)
	var border := LIGHT_PINK
	border.a = 0.6
	_stroke_circle(img, c, c, 58, 3, border)
	return img


static func _make_joystick_thumb() -> Image:
	var img := _new_image(60, 60)
	var c := 30.0
	_fill_circle(img, c, c, 28, PINK)
	_stroke_circle(img, c, c, 20, 3, STAR_WHITE)
	return img


static func _make_button_base() -> Image:
	var img := _new_image(100, 100)
	var c := 50.0
	var fill := DARK_PINK
	fill.a = 0.75
	_fill_circle(img, c, c, 48, fill)
	_stroke_circle(img, c, c, 48, 4, LIGHT_PINK)
	return img


# ---------------------------------------------------------------------------
# Icons (32x32, except hint 16x16)
# ---------------------------------------------------------------------------

## A four-point sparkle/starburst - "shine a light and reveal something".
static func _make_icon_reveal() -> Image:
	var img := _new_image(32, 32)
	var c := 16.0
	_fill_diamond(img, c, c, 30, 10, STAR_WHITE)
	_fill_diamond(img, c, c, 10, 30, STAR_WHITE)
	_fill_circle(img, c, c, 5, STAR_WHITE)
	return img


## A droplet with a small radiating melt-glow underneath - "light that
## dissolves the goo", distinct silhouette from the reveal sparkle.
static func _make_icon_dissolve() -> Image:
	var img := _new_image(32, 32)
	_fill_circle(img, 16, 19, 9, STAR_WHITE)
	_fill_triangle_up(img, 9, 3, 14, 16, STAR_WHITE)
	_fill_circle(img, 16, 19, 4, TRANSPARENT)
	return img


static func _make_icon_arrow_hint() -> Image:
	var img := _new_image(16, 16)
	_fill_triangle_up(img, 2, 1, 12, 9, PINK)
	_fill_rect(img, 6, 10, 4, 5, PINK)
	return img


static func _make_icon_lock() -> Image:
	var img := _new_image(24, 24)
	_stroke_circle(img, 12, 9, 6, 3, SLATE_GREY)
	_fill_rect(img, 4, 11, 16, 11, SLATE_GREY)
	_fill_rect(img, 5, 12, 14, 9, VOID_BLACK)
	_fill_circle(img, 12, 16, 2, SLATE_GREY)
	return img


## A soft ring, bright at its edge and transparent at the center, so a kid
## can see exactly how far Reveal Light actually searches every time they
## tap it - stretched to REVEAL_RADIUS and faded out by player.gd, whether
## or not anything was actually found.
static func _make_reveal_pulse() -> Image:
	var img := _new_image(64, 64)
	var c := 32.0
	_stroke_circle(img, c, c, 30, 5, LIGHT_PINK)
	_stroke_circle(img, c, c, 30, 10, PINK)
	return img


## The little "go" triangle on the NEXT/START buttons. This exists as a
## texture rather than a "▶" in the button's text because Godot's built-in
## font has no glyph for U+25B6 - the web build rendered it as a tofu box
## with the literal codepoint "25B6" printed inside, on a button every
## player taps on the way into every level.
static func _make_icon_play() -> Image:
	var img := _new_image(12, 12)
	var tri := PackedVector2Array([Vector2(3, 2), Vector2(3, 10), Vector2(10, 6)])
	for y in range(12 * SCALE):
		for x in range(12 * SCALE):
			var p := Vector2((x + 0.5) / SCALE, (y + 0.5) / SCALE)
			if _point_in_polygon(p, tri):
				img.set_pixel(x, y, LIGHT_PINK)
	return img


## A single four-pointed sparkle mote, scattered in a burst when a key or
## the gem is collected (see collectible.gd). Drawn glow-first so the
## brighter core and arms overwrite it - `set_pixel` overwrites rather than
## compositing, so paint order is the only blending available here.
static func _make_sparkle() -> Image:
	const SIZE := 16
	const CENTER := SIZE / 2.0
	var img := _new_image(SIZE, SIZE)

	# Built from a continuous falloff rather than the rect/circle helpers:
	# a sparkle needs arms that taper to nothing, and stacked solid shapes
	# just read as a fat crosshair at this size. Pixels are walked in
	# physical space but converted back to logical units first (the same
	# `(x + 0.5) / SCALE` convention _make_asteroid uses) so the falloff
	# constants stay independent of SCALE.
	for y in range(SIZE * SCALE):
		for x in range(SIZE * SCALE):
			var dx: float = (x + 0.5) / SCALE - CENTER
			var dy: float = (y + 0.5) / SCALE - CENTER
			var r := sqrt(dx * dx + dy * dy)

			var core: float = exp(-r * 0.95)
			var arm_h: float = exp(-absf(dx) * 0.34) * exp(-absf(dy) * 2.3)
			var arm_v: float = exp(-absf(dy) * 0.34) * exp(-absf(dx) * 2.3)
			var v: float = clampf(maxf(core, maxf(arm_h, arm_v)), 0.0, 1.0)
			if v <= 0.02:
				continue

			var col: Color = STAR_WHITE.lerp(PINK, clampf(r / 5.0, 0.0, 1.0))
			col.a = v
			img.set_pixel(x, y, col)
	return img


# ---------------------------------------------------------------------------
# Hazards
# ---------------------------------------------------------------------------

## Static base layer: near-black core with a violet edge glow - the "don't
## touch the middle" danger reads clearly even before it starts pulling.
static func _make_black_hole_core() -> Image:
	var img := _new_image(96, 96)
	var c := 48.0
	var glow := SPACE_PURPLE
	glow.a = 0.5
	_fill_circle(img, c, c, 46, glow)
	_fill_circle(img, c, c, 30, VOID_BLACK)
	_stroke_circle(img, c, c, 30, 2, PINK)
	return img


## Rotating overlay: a few short spiral arm strokes, semi-transparent so
## the core shows through - cheap "swirling" look from a static image
## that's just spun continuously in code (see black_hole.gd).
static func _make_black_hole_swirl() -> Image:
	var img := _new_image(96, 96)
	var c := Vector2(48, 48)
	var col := LIGHT_PINK
	col.a = 0.55
	for arm in range(3):
		var base_angle := arm * TAU / 3.0
		var prev := c
		for i in range(14):
			var t := float(i) / 13.0
			var angle: float = base_angle + t * PI * 1.4
			var radius: float = lerpf(6.0, 44.0, t)
			var p: Vector2 = c + Vector2.from_angle(angle) * radius
			if i > 0:
				_draw_line(img, prev.x, prev.y, p.x, p.y, 2.0, col)
			prev = p
	return img


## Rounded blob with a highlight and darker underside - reads as soft/wet
## goo rather than a solid obstacle, matching its "melt it away" behavior.
static func _make_sticky_trap() -> Image:
	var img := _new_image(40, 40)
	_fill_circle(img, 20, 24, 15, GOO_DARK)
	_fill_circle(img, 17, 19, 14, GOO_PINK)
	_fill_circle(img, 12, 14, 5, LIGHT_PINK)
	_stroke_circle(img, 17, 19, 14, 1.5, GOO_DARK)
	return img


## Irregular rock silhouette (an off-center blob, not a perfect circle) with
## a few darker crater dots - drifts and bounces, never a hard "you failed"
## obstacle.
static func _make_asteroid() -> Image:
	var img := _new_image(40, 40)
	var c := Vector2(20, 20)
	var rng := _rng(99)
	var points := PackedVector2Array()
	var spikes := 9
	for i in range(spikes):
		var angle: float = i * TAU / spikes
		var r: float = rng.randf_range(13.0, 17.0)
		points.append(c + Vector2.from_angle(angle) * r)
	for y in range(40 * SCALE):
		for x in range(40 * SCALE):
			var p := Vector2((x + 0.5) / SCALE, (y + 0.5) / SCALE)
			if _point_in_polygon(p, points):
				img.set_pixel(x, y, ASTEROID_GREY)
	for i in range(5):
		var cx: float = rng.randf_range(10.0, 30.0)
		var cy: float = rng.randf_range(10.0, 30.0)
		_fill_circle(img, cx, cy, rng.randf_range(1.5, 3.0), ASTEROID_DARK)
	return img


static func _point_in_polygon(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[j]
		if (a.y > p.y) != (b.y > p.y):
			var slope: float = (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x
			if p.x < slope:
				inside = not inside
		j = i
	return inside
