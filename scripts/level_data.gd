class_name LevelData
extends RefCounted

## Static level definitions. Aria flies freely in 2D (no gravity/floor) —
## these grids only place hazards and pickups, never solid walls. Legend:
##   '.' = empty space
##   'A' = Aria start position
##   'K' = a hidden key (revealed by Reveal Light, then collectible)
##   'G' = the hidden pink gem (final level only)
##   'O' = black hole (gentle pull, then a snap-back reset if you drift in close)
##   'S' = sticky pink trap (freezes you until Dissolve Light is used on it)
##   'X' = drifting asteroid (bumps you back on contact, no penalty)
##   '^' = home portal (2 rows tall, one column) — opens once the key/gem is found

const TILE_SIZE := 64

const LEVEL_1 := {
	"name": "The Drifting Field",
	"story": "Aria's light magic flickers to life, but she's drifting\nfar from home. A key glimmers somewhere out here...",
	"rows": [
		"..................................",
		"..................................",
		"......X...........................",
		"..............X...................",
		"..A.................K.............",
		"........................X.........",
		".........X.....................^..",
		"...............O...............^..",
		"..................................",
		"....X..............X..............",
		"..................................",
		"..................................",
		"..................................",
		"..................................",
	],
}

const LEVEL_2 := {
	"name": "The Sticky Pink Planet",
	"story": "A whole planet of glowing pink goo! Aria's light can\nmelt the sticky traps - fly carefully and find the key.",
	"rows": [
		"..................................",
		"..................................",
		"..................................",
		"........S...........S.......X.....",
		"..A...............................",
		"..............S...................",
		"......................K..S.....^..",
		"...............................^..",
		"..............S...................",
		"........S...........S.............",
		".....X...........O................",
		"..................................",
		"..................................",
		"..................................",
	],
}

const LEVEL_3 := {
	"name": "The Black Hole Belt",
	"story": "The last key is somewhere past the belt. The black\nholes here pull hard - stay clear of their centers!",
	"rows": [
		"..................................",
		"..................................",
		"....S.........X...................",
		"..........O...............O.......",
		"..A...............................",
		"..................................",
		"...................O....K......^..",
		"......X.........................^..",
		"..................................",
		"......................X...........",
		"....S.....O...............O.......",
		"..............X...................",
		"..................................",
		"..................................",
	],
}

const LEVEL_4 := {
	"name": "The Way Home",
	"story": "Three keys found! One more thing stands between\nAria and home: the pink gem, hidden just ahead.",
	"rows": [
		"..................................",
		"..................................",
		"............S.....................",
		"........O.......X..........S......",
		"..A...............................",
		".......................G..........",
		"...........X........O..........^..",
		"............................X..^..",
		"......S...........................",
		"........................X.........",
		"........O.........S...............",
		"..................................",
		"..................................",
		"..................................",
	],
}

const LEVELS: Array = [LEVEL_1, LEVEL_2, LEVEL_3, LEVEL_4]


static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]


static func get_level_count() -> int:
	return LEVELS.size()


static func get_width(level: Dictionary) -> int:
	var rows: Array = level["rows"]
	return (rows[0] as String).length()


static func get_height(level: Dictionary) -> int:
	var rows: Array = level["rows"]
	return rows.size()


static func is_final(index: int) -> bool:
	return index == LEVELS.size() - 1
