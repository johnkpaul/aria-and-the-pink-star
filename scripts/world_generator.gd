extends Node2D
class_name WorldGenerator

## Builds a playable level from LevelData: no tiles or floor collision at
## all, since Aria flies freely in open space. Just instances hazards
## (black holes, sticky traps, asteroids), the hidden key/gem, and the
## home portal as lightweight Area2D/Node2D entities placed on a grid.

signal all_keys_collected
signal level_complete
signal key_collected(collected: int, total: int)

const TILE_SIZE := LevelData.TILE_SIZE

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const COLLECTIBLE_SCENE := preload("res://scenes/collectible.tscn")
const BLACK_HOLE_SCENE := preload("res://scenes/black_hole.tscn")
const STICKY_TRAP_SCENE := preload("res://scenes/sticky_trap.tscn")
const ASTEROID_SCENE := preload("res://scenes/asteroid.tscn")

## Warm dusk pink for the final "coming home" level, cooler/darker purples
## for the earlier ones - a small mood shift so The Way Home visibly feels
## like the destination, not just "another zone".
const ZONE_TINTS := [
	Color(0.85, 0.85, 1.0),
	Color(1.0, 0.85, 0.95),
	Color(0.75, 0.75, 0.95),
	Color(1.0, 0.92, 0.85),
]

var player: CharacterBody2D
@onready var camera: CameraFollow = $Camera2D
@onready var background: Sprite2D = $BackgroundSpace

var level_index := 0
var level: Dictionary
var level_width := 0
var level_height := 0

var total_collectibles := 0
var collected_collectibles := 0

var _black_holes: Array[Node2D] = []
var _sticky_traps: Array[Node2D] = []


func _ready() -> void:
	add_to_group("world")


func build_level(index: int) -> void:
	if not camera:
		camera = get_node_or_null("Camera2D")
	level_index = index
	level = LevelData.get_level(index)
	level_width = LevelData.get_width(level)
	level_height = LevelData.get_height(level)

	_clear_previous()
	_parse_rows()

	if background:
		background.modulate = ZONE_TINTS[level_index % ZONE_TINTS.size()]

	camera.set_level_bounds(level_width * TILE_SIZE, level_height * TILE_SIZE)
	camera.set_target(player)
	camera.set_parallax_target(background)
	if camera.is_inside_tree():
		camera.make_current()
	else:
		camera.call_deferred("make_current")


func _clear_previous() -> void:
	for child in get_children():
		if child == camera or child == background:
			continue
		child.queue_free()
	_black_holes.clear()
	_sticky_traps.clear()
	total_collectibles = 0
	collected_collectibles = 0
	player = null


func _parse_rows() -> void:
	var rows: Array = level["rows"]
	var start_cell := Vector2i(1, 1)
	var gate_cells: Array[Vector2i] = []

	for y in range(rows.size()):
		var row: String = rows[y]
		for x in range(row.length()):
			var ch := row[x]
			var cell := Vector2i(x, y)
			match ch:
				"A":
					start_cell = cell
				"K":
					_spawn_collectible(cell, false)
				"G":
					_spawn_collectible(cell, true)
				"O":
					_spawn_black_hole(cell)
				"S":
					_spawn_sticky_trap(cell)
				"X":
					_spawn_asteroid(cell)
				"^":
					gate_cells.append(cell)
				_:
					pass

	if not gate_cells.is_empty():
		_spawn_home_portal(gate_cells)

	_spawn_player(start_cell)


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2.0, cell.y * TILE_SIZE + TILE_SIZE / 2.0)


func get_bounds_px() -> Vector2:
	return Vector2(level_width * TILE_SIZE, level_height * TILE_SIZE)


func _spawn_player(start_cell: Vector2i) -> void:
	player = PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = cell_to_world(start_cell)
	player.set_world(self)
	player.set_safe_position(player.global_position)


func _spawn_collectible(cell: Vector2i, gem: bool) -> void:
	var item := COLLECTIBLE_SCENE.instantiate()
	add_child(item)
	item.global_position = cell_to_world(cell)
	item.set_gem(gem)
	item.collected.connect(_on_collectible_collected)
	total_collectibles += 1


func _on_collectible_collected(_gem: bool) -> void:
	collected_collectibles += 1
	key_collected.emit(collected_collectibles, total_collectibles)
	ProceduralAudio.play_sfx("key")
	if collected_collectibles >= total_collectibles:
		all_keys_collected.emit()


func _spawn_black_hole(cell: Vector2i) -> void:
	var hole := BLACK_HOLE_SCENE.instantiate()
	add_child(hole)
	hole.global_position = cell_to_world(cell)
	_black_holes.append(hole)


func _spawn_sticky_trap(cell: Vector2i) -> void:
	var trap := STICKY_TRAP_SCENE.instantiate()
	add_child(trap)
	trap.global_position = cell_to_world(cell)
	_sticky_traps.append(trap)


func _spawn_asteroid(cell: Vector2i) -> void:
	var rock := ASTEROID_SCENE.instantiate()
	add_child(rock)
	rock.global_position = cell_to_world(cell)


func _spawn_home_portal(cells: Array[Vector2i]) -> void:
	var gate := Area2D.new()
	gate.name = "HomePortal"
	var top_cell: Vector2i = cells[0]
	for c in cells:
		if c.y < top_cell.y:
			top_cell = c
	var center := cell_to_world(top_cell) + Vector2(0, TILE_SIZE * 0.5 * (cells.size() - 1))
	gate.global_position = center
	gate.collision_layer = 0
	gate.collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(TILE_SIZE, TILE_SIZE * cells.size())
	shape.shape = rect
	gate.add_child(shape)

	var portal_tex: Texture2D = load("res://generated_assets/portal.png")
	var sprite := Sprite2D.new()
	sprite.texture = portal_tex
	sprite.scale = Vector2(
		rect.size.x / portal_tex.get_width(),
		rect.size.y / portal_tex.get_height()
	)
	gate.add_child(sprite)
	add_child(gate)

	var pulse := gate.create_tween()
	pulse.set_loops()
	pulse.tween_property(sprite, "modulate", Color(1.15, 1.15, 1.15), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(sprite, "modulate", Color(0.9, 0.9, 0.9), 0.7).set_trans(Tween.TRANS_SINE)
	gate.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and collected_collectibles >= total_collectibles:
			level_complete.emit()
	)
