extends Node2D

signal remove_icing(board_position)

var icing_pieces = []
var width=8
var height=10
var icing = preload("res://scenes/icing.tscn")
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

func _on_grid_make_icing(board_position):
	if icing_pieces.size()==0:
		icing_pieces = make_2d_array()
	var current = icing.instantiate()
	add_child(current)
	current.position= Vector2(board_position.x*64+64, -board_position.y*64+800)
	icing_pieces[board_position.x][board_position.y] = current
	
func _on_grid_damage_icing(board_position):
	if icing_pieces[board_position.x][board_position.y]:
		icing_pieces[board_position.x][board_position.y].take_damage(1)
		if icing_pieces[board_position.x][board_position.y].health<=0:
			icing_pieces[board_position.x][board_position.y].queue_free()
			icing_pieces[board_position.x][board_position.y]=null
			remove_icing.emit(board_position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
