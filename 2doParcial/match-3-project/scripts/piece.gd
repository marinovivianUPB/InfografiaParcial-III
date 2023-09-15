extends Node2D

@export var color: String

var matched = false

func move(target):
	var move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_ELASTIC)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property(self, "position", target, 0.4)

func dim():
	$Sprite2D.modulate = Color(1, 1, 1, 0.5)

func selected():
	$Sprite2D.modulate = Color(229/255.0,51/255.0,39/255.0, 0.5)
	
func color_selected():
	$Sprite2D.modulate = Color(127/255.0,20/255.0,178/255.0, 0.5)
