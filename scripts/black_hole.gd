extends Node2D
class_name BlackHole

## A pulling hazard, no permanent penalty: drift within PULL_RADIUS and
## Aria gets nudged toward the center (visible, learnable danger); cross
## EVENT_RADIUS and player.gd snaps her back to her last safe spot with a
## brief flash, same as any other reset in this game. Distance checks and
## the pull force itself live in player.gd (it needs continuous per-frame
## distance math against every hole, not just enter/exit events), so this
## script is just the visual: a dark core with a slowly rotating swirl.

const PULL_RADIUS := 260.0
const EVENT_RADIUS := 70.0
const PULL_STRENGTH := 220.0

@onready var swirl: Sprite2D = $Swirl


func _ready() -> void:
	add_to_group("black_hole")
	if swirl:
		var tw := create_tween()
		tw.set_loops()
		tw.tween_property(swirl, "rotation", swirl.rotation + TAU, 3.0).set_trans(Tween.TRANS_LINEAR)
