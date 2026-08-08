extends RefCounted
class_name ProceduralFont

## A chunky 5x7 pixel font, built entirely in code - no .ttf, no imported
## asset, nothing to license.
##
## Why this exists: every label in the game was rendering in Godot's
## built-in fallback font, a smooth modern sans-serif, on top of artwork
## that is deliberately blocky 4x-scaled pixel art. That mismatch is the
## single loudest "this is a prototype" signal a game can send - the words
## and the world look like they came from different products. Matching the
## type to the art costs nothing and changes the whole impression.
##
## Design notes:
##  * Uppercase-only letterforms. All the game's copy is already uppercase,
##    and at ~16 CSS pixels on a phone a 5x7 lowercase 'e' would be mush.
##    Lowercase codepoints are mapped onto the same glyphs so mixed-case
##    strings like "Total: 0" still render correctly rather than vanishing.
##  * The whole printable ASCII range is covered, because the mission-file
##    message is personalised text supplied per-recipient and can contain
##    anything. Unknown codepoints fall back to a blank of the right width
##    rather than a missing-glyph box.
##  * TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY keeps every pixel square at
##    any font size. It must be set *before* the first cache entry is
##    created, or the font silently ignores font_size entirely and renders
##    everything at 7px - which looks exactly like a broken layout.

const CELL_W := 5
const CELL_H := 7
## One column of padding in the atlas so neighbouring glyphs can't bleed
## into each other, plus one unit of side bearing in the advance.
const PAD := 1
## Baseline sits one row up from the bottom of the cell, so comma and
## semicolon tails fall below it the way they should.
const BASELINE := 6
## Blank rows of leading between lines. Without this the reported line
## height is exactly the cell height, so wrapped and \n-separated lines sit
## flush against each other and the descender row of one line collides with
## the cap row of the next - legible as a smear rather than as text.
const LEADING := 3

const GLYPHS := {
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"B": ["####.", "#...#", "####.", "#...#", "#...#", "#...#", "####."],
	"C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
	"D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
	"E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
	"F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"I": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
	"K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
	"N": ["#...#", "##..#", "#.#.#", "#.#.#", "#..##", "#...#", "#...#"],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
	"Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
	"R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
	"S": [".###.", "#...#", "#....", ".###.", "....#", "#...#", ".###."],
	"T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
	"W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "##.##", "#...#"],
	"X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
	"Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
	"Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],

	"0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
	"1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", "#####"],
	"2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
	"3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
	"4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
	"7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
	"8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
	"9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],

	" ": [".....", ".....", ".....", ".....", ".....", ".....", "....."],
	"!": ["..#..", "..#..", "..#..", "..#..", "..#..", ".....", "..#.."],
	"\"": [".#.#.", ".#.#.", ".....", ".....", ".....", ".....", "....."],
	"#": [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", "....."],
	"%": ["#...#", "#...#", "...#.", "..#..", ".#...", "#...#", "#...#"],
	"&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
	"'": ["..#..", "..#..", ".....", ".....", ".....", ".....", "....."],
	"(": ["...#.", "..#..", ".#...", ".#...", ".#...", "..#..", "...#."],
	")": [".#...", "..#..", "...#.", "...#.", "...#.", "..#..", ".#..."],
	"*": [".....", ".#.#.", "..#..", "#####", "..#..", ".#.#.", "....."],
	"+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
	",": [".....", ".....", ".....", ".....", ".....", "..#..", ".#..."],
	"-": [".....", ".....", ".....", "#####", ".....", ".....", "....."],
	".": [".....", ".....", ".....", ".....", ".....", ".....", "..#.."],
	"/": ["....#", "...#.", "...#.", "..#..", ".#...", ".#...", "#...."],
	":": [".....", "..#..", ".....", ".....", ".....", "..#..", "....."],
	";": [".....", "..#..", ".....", ".....", "..#..", "..#..", ".#..."],
	"<": ["...#.", "..#..", ".#...", "#....", ".#...", "..#..", "...#."],
	"=": [".....", ".....", "#####", ".....", "#####", ".....", "....."],
	">": [".#...", "..#..", "...#.", "....#", "...#.", "..#..", ".#..."],
	"?": [".###.", "#...#", "....#", "..##.", "..#..", ".....", "..#.."],
	"@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
	"[": [".###.", ".#...", ".#...", ".#...", ".#...", ".#...", ".###."],
	"\\": ["#....", ".#...", ".#...", "..#..", "...#.", "...#.", "....#"],
	"]": [".###.", "...#.", "...#.", "...#.", "...#.", "...#.", ".###."],
	"^": ["..#..", ".#.#.", "#...#", ".....", ".....", ".....", "....."],
	"_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
	"`": [".#...", "..#..", ".....", ".....", ".....", ".....", "....."],
	"{": ["...#.", "..#..", "..#..", ".#...", "..#..", "..#..", "...#."],
	"|": ["..#..", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
	"}": [".#...", "..#..", "..#..", "...#.", "..#..", "..#..", ".#..."],
	"~": [".....", ".....", ".##.#", "#..#.", ".....", ".....", "....."],
}


## Builds the font. Cheap enough to call once at startup; the atlas is a
## single image a few hundred pixels wide.
static func build() -> FontFile:
	var keys: Array = GLYPHS.keys()
	keys.sort()

	var cols := keys.size()
	var atlas := Image.create(cols * (CELL_W + PAD), CELL_H + PAD, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))

	for i in range(cols):
		var rows: Array = GLYPHS[keys[i]]
		for y in range(CELL_H):
			var row: String = rows[y]
			for x in range(CELL_W):
				if row[x] == "#":
					# White, so Godot's font_color modulation gives the
					# actual colour - the glyphs must not carry their own.
					atlas.set_pixel(i * (CELL_W + PAD) + x, y, Color(1, 1, 1, 1))

	var font := FontFile.new()
	# Must be set before any cache entry exists. If this lands after the
	# first set_texture_image the font ignores font_size completely and
	# renders every label at 7 pixels tall.
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.fixed_size = CELL_H
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE

	var size_key := Vector2i(CELL_H, 0)
	font.set_texture_image(0, size_key, 0, atlas)
	font.set_cache_ascent(0, CELL_H, float(BASELINE))
	font.set_cache_descent(0, CELL_H, float(CELL_H - BASELINE + LEADING))

	for i in range(cols):
		var ch: String = keys[i]
		var rect := Rect2(i * (CELL_W + PAD), 0, CELL_W, CELL_H)
		_register(font, size_key, ch.unicode_at(0), rect)
		# Map the lowercase codepoint onto the same uppercase glyph, so
		# mixed-case strings render instead of coming out blank.
		var lower: String = ch.to_lower()
		if lower != ch:
			_register(font, size_key, lower.unicode_at(0), rect)

	return font


static func _register(font: FontFile, size_key: Vector2i, code: int, rect: Rect2) -> void:
	font.set_glyph_texture_idx(0, size_key, code, 0)
	font.set_glyph_uv_rect(0, size_key, code, rect)
	font.set_glyph_size(0, size_key, code, Vector2(CELL_W, CELL_H))
	font.set_glyph_offset(0, size_key, code, Vector2(0, -BASELINE))
	font.set_glyph_advance(0, CELL_H, code, Vector2(CELL_W + PAD, 0))


static var _font: FontFile
static var _installed := false


## Installs the font across the whole game. Any per-node
## theme_override_font_sizes the scenes already carry still apply.
##
## This has to set a per-node override rather than the tidier route of a
## Theme on the tree root, because none of the obvious mechanisms actually
## reach these labels. Control theme lookup walks up the *Control* parent
## chain, and in both games every label lives under a CanvasLayer, which is
## not a Control - the chain breaks there and the lookup falls straight
## through to Open Sans. A test scene checked all four candidates
## (root.theme with default_font, root.theme with an explicit
## set_font("font", "Label", ...) entry, ThemeDB.fallback_font, and a direct
## override); only the override worked.
##
## Connecting to node_added covers everything built at runtime - the
## tutorial cards, the level-intro cards, the mission reveal, the rotate
## prompt - which is where most of the game's text actually lives.
static func install(tree: SceneTree) -> void:
	if _installed:
		return
	_installed = true
	_font = build()
	tree.node_added.connect(_apply_to)
	_apply_recursive(tree.root)


static func _apply_to(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		node.add_theme_font_override("font", _font)


static func _apply_recursive(node: Node) -> void:
	_apply_to(node)
	for child in node.get_children():
		_apply_recursive(child)
