extends Node2D
# state machine
enum {WAIT, MOVE, BOMB}
var state

# grid
@export var width: int
@export var height: int
@export var x_start: int
@export var y_start: int
@export var offset: int
@export var y_offset: int

@export var icing_spaces: PackedVector2Array
signal make_icing(icing_space)
signal damage_icing(icing_space)

@export var lock_spaces: PackedVector2Array
signal make_lock(lock_space)
signal damage_lock(lock_space)

@export var empty_spaces: PackedVector2Array

@export var slime_spaces: PackedVector2Array
signal make_slime(slime_space)
signal damage_slime(slime_space)

@export var jelly_spaces: PackedVector2Array
signal make_jelly(jelly_space)
signal damage_jelly(jelly_space)

@export var can_bomb: bool
var bomb_space=false
var bomb_counter=0

@export var can_color_bomb: bool
var color_bomb_space=false
var color_bomb_counter=0
# piece array
var possible_pieces = [
	preload("res://scenes/blue_piece.tscn"),
	preload("res://scenes/green_piece.tscn"),
	preload("res://scenes/light_green_piece.tscn"),
	preload("res://scenes/pink_piece.tscn"),
	preload("res://scenes/yellow_piece.tscn"),
	preload("res://scenes/orange_piece.tscn"),
]
# current pieces in scene
var all_pieces = []

# swap back
var piece_one = null
var piece_two = null
var last_place = Vector2.ZERO
var last_direction = Vector2.ZERO
var move_checked = false

# touch variables
var first_touch = Vector2.ZERO
var final_touch = Vector2.ZERO
var is_controlling = false

var damaged_slime = false
# scoring variables and signals
signal update_score(new_score)
var streak=0
var old_score=0
# counter variables and signals
signal update_timer(new_time)
signal update_move_counter(new_move_counter)
@export var timer : bool
@export var counter : int
@export var move_counter : int
# para ganar
@export var target_score: int
var won = false

#special things
func put_icing():
	for i in icing_spaces.size():
		make_icing.emit(icing_spaces[i])

func put_locks():
	for i in lock_spaces.size():
		make_lock.emit(lock_spaces[i])

func put_slime():
	for i in slime_spaces.size():
		make_slime.emit(slime_spaces[i])
func put_jelly():
	for i in jelly_spaces.size():
		make_jelly.emit(jelly_spaces[i])

func remove_from_array(array, item):
	for i in range(array.size()-1,-1,-1):
		if array[i]==item:
			array.remove(i)

# Called when the node enters the scene tree for the first time.
func _ready():
	state = MOVE
	randomize()
	all_pieces = make_2d_array()
	spawn_pieces()
	put_icing()
	put_locks()
	put_slime()
	put_jelly()
	if timer:
		update_timer.emit(counter)
		get_node("clock").start()
		move_counter=0
	else:
		update_move_counter.emit(move_counter)

func no_fill(position):
	if in_array(icing_spaces,position):
		return true
	if in_array(empty_spaces,position):
		return true 
	if in_array(slime_spaces, position):
		return true
	return false

func no_movement(position):
	if in_array(icing_spaces,position):
		return true
	if in_array(empty_spaces,position):
		return true
	if in_array(lock_spaces,position):
		return true
	return false

func is_special(position):
	return in_array(empty_spaces,position) && in_array(icing_spaces,position) 

func in_array(array,item):
	for i in array.size():
		if array[i] == item:
			return true
	return false

func make_2d_array():
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array
	
func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start - offset * row
	return Vector2(new_x, new_y)
	
func pixel_to_grid(pixel_x, pixel_y):
	var new_x = round((pixel_x - x_start) / offset)
	var new_y = round((pixel_y - y_start) / -offset)
	return Vector2(new_x, new_y)
	
func in_grid(column, row):
	return column >= 0 and column < width and row >= 0 and row < height
	
func spawn_pieces():
	for i in width:
		for j in height:
			if !no_fill(Vector2(i,j)):
				# random number
				var rand = randi_range(0, possible_pieces.size() - 1)
				# instance 
				var piece = possible_pieces[rand].instantiate()
				# repeat until no matches
				var max_loops = 100
				var loops = 0
				while (match_at(i, j, piece.color) and loops < max_loops):
					rand = randi_range(0, possible_pieces.size() - 1)
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.position = grid_to_pixel(i, j)
				# fill array with pieces
				all_pieces[i][j] = piece

func is_piece_sinker(column, row):
	if all_pieces[column][row] != null:
		if all_pieces[column][row].color == "None":
			return true
	return false

func match_at(i, j, color):
	# check left
	if i > 1:
		if all_pieces[i - 1][j] != null and all_pieces[i - 2][j] != null:
			if all_pieces[i - 1][j].color == color and all_pieces[i - 2][j].color == color:
				return true
	# check down
	if j> 1:
		if all_pieces[i][j - 1] != null and all_pieces[i][j - 2] != null:
			if all_pieces[i][j - 1].color == color and all_pieces[i][j - 2].color == color:
				return true

func restart():
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()

func touch_input():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if Input.is_action_just_pressed("ui_touch") and in_grid(grid_pos.x, grid_pos.y):
		first_touch = grid_pos
		is_controlling = true
		
	# release button
	if Input.is_action_just_released("ui_touch") and in_grid(grid_pos.x, grid_pos.y) and is_controlling:
		is_controlling = false
		final_touch = grid_pos
		touch_difference(first_touch, final_touch)

func swap_pieces(column, row, direction: Vector2):
	var first_piece = all_pieces[column][row]
	var other_piece = all_pieces[column + direction.x][row + direction.y]
	if first_piece == null or other_piece == null:
		return
	if !no_movement(Vector2(column,row)) and !no_movement(Vector2(column,row)+direction):
	# swap
		state = WAIT
		store_info(first_piece, other_piece, Vector2(column, row), direction)
		all_pieces[column][row] = other_piece
		all_pieces[column + direction.x][row + direction.y] = first_piece
		#first_piece.position = grid_to_pixel(column + direction.x, row + direction.y)
		#other_piece.position = grid_to_pixel(column, row)
		first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
		other_piece.move(grid_to_pixel(column, row))
		if not move_checked:
			find_matches()

func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction

func swap_back():
	if piece_one != null and piece_two != null:
		swap_pieces(last_place.x, last_place.y, last_direction)
	state = MOVE
	move_checked = false

func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
	# should move x or y?
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(1, 0))
		elif difference.x < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(-1, 0))
	if abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, 1))
		elif difference.y < 0:
			swap_pieces(grid_1.x, grid_1.y, Vector2(0, -1))

func _process(delta):
	if state == MOVE && !bomb_space && !color_bomb_space:
		touch_input()
	if bomb_space && !color_bomb_space:
		activate_bomb()
	if !bomb_space && color_bomb_space:
		activate_color_bomb()

func activate_bomb():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if Input.is_action_just_pressed("ui_touch") and in_grid(grid_pos.x, grid_pos.y):
		var touch = grid_pos
		if all_pieces[touch.x][touch.y] != null:
			all_pieces[touch.x][touch.y].selected()
			all_pieces[touch.x][touch.y].matched=true
			for i in range(width):
				if all_pieces[i][touch.y] != null && i!=touch.x:
					all_pieces[i][touch.y].matched = true
					all_pieces[i][touch.y].dim()
			for j in range(height):
				if all_pieces[touch.x][j] != null && j!=touch.y:
					all_pieces[touch.x][j].matched = true
					all_pieces[touch.x][j].selected()
		get_parent().get_node("destroy_timer").start()
		bomb_space=false
		get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").hide()

func activate_color_bomb():
	var mouse_pos = get_global_mouse_position()
	var grid_pos = pixel_to_grid(mouse_pos.x, mouse_pos.y)
	if Input.is_action_just_pressed("ui_touch") and in_grid(grid_pos.x, grid_pos.y):
		var touch = grid_pos
		if all_pieces[touch.x][touch.y] != null:
			var current_color = all_pieces[touch.x][touch.y].color
			all_pieces[touch.x][touch.y].color_selected()
			all_pieces[touch.x][touch.y].matched=true
			for i in range(width):
				for j in range(height):
					if all_pieces[i][j]!=null && !is_special(Vector2(i,j)) && (all_pieces[i][j].color ==  current_color):
						all_pieces[i][j].color_selected()
						all_pieces[i][j].matched = true
		get_parent().get_node("destroy_timer").start()
		color_bomb_space=false
		get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").hide()

func find_matches():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null:
				var current_color = all_pieces[i][j].color
				# detect horizontal matches
				if (
					i > 0 and i < width -1 
					and 
					all_pieces[i - 1][j] != null and all_pieces[i + 1][j]
					and 
					all_pieces[i - 1][j].color == current_color and all_pieces[i + 1][j].color == current_color
				):
					all_pieces[i - 1][j].matched = true
					all_pieces[i - 1][j].dim()
					all_pieces[i][j].matched = true
					all_pieces[i][j].dim()
					all_pieces[i + 1][j].matched = true
					all_pieces[i + 1][j].dim()
				# detect vertical matches
				if (
					j > 0 and j < height -1 
					and 
					all_pieces[i][j - 1] != null and all_pieces[i][j + 1]
					and 
					all_pieces[i][j - 1].color == current_color and all_pieces[i][j + 1].color == current_color
				):
					all_pieces[i][j - 1].matched = true
					all_pieces[i][j - 1].dim()
					all_pieces[i][j].matched = true
					all_pieces[i][j].dim()
					all_pieces[i][j + 1].matched = true
					all_pieces[i][j + 1].dim()
					
	get_parent().get_node("destroy_timer").start()
	
func destroy_matched():
	streak+=1
	var number_of_matched=0
	var was_matched = false
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and all_pieces[i][j].matched:
				damage_special(i,j)
				was_matched = true
				number_of_matched+=1
				all_pieces[i][j].queue_free()
				all_pieces[i][j] = null
				
	move_checked = true
	old_score+=number_of_matched*10*streak
	if can_bomb:
		bomb_counter+=number_of_matched*10*streak
	if can_color_bomb:
		color_bomb_counter+=number_of_matched*10*streak
	update_score.emit(old_score)
	if old_score >= target_score:
		won = true
		if bomb_counter>=target_score && !color_bomb_space:
			bomb_space=true
			bomb_counter=0
			get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").text = "BOMB!"
			get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").show()
		if color_bomb_counter>=1000 && !bomb_space:
			color_bomb_space=true
			color_bomb_counter=0
			get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").text = "COLOR BOMB!"
			get_parent().get_node("bottom_ui/MarginContainer/HBoxContainer/Label").show()
	if was_matched:
		get_parent().get_node("collapse_timer").start()
	else:
		swap_back()

func check_icing(column,row):
	if column<width-1:
		damage_icing.emit(Vector2(column+1, row))
	if column>0:
		damage_icing.emit(Vector2(column-1, row))
	if row<height-1:
		damage_icing.emit(Vector2(column, row+1))
	if row>0:
		damage_icing.emit(Vector2(column, row-1))
	pass

func check_slime(column,row):
	if column<width-1:
		damage_slime.emit(Vector2(column+1, row))
	if column>0:
		damage_slime.emit(Vector2(column-1, row))
	if row<height-1:
		damage_slime.emit(Vector2(column, row+1))
	if row>0:
		damage_slime.emit(Vector2(column, row-1))
	pass

func damage_special(column, row):
	if icing_spaces.size() >0:
		check_icing(column,row)
	if lock_spaces.size()>0:
		damage_lock.emit(Vector2(column, row))
	if slime_spaces.size()>0:
		check_slime(column,row)
	if jelly_spaces.size()>0:
		damage_jelly.emit(Vector2(column, row))
	

func collapse_columns():
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !no_fill(Vector2(i,j)):
				print(i, j)
				# look above
				for k in range(j + 1, height):
					if all_pieces[i][k] != null:
						all_pieces[i][k].move(grid_to_pixel(i, j))
						all_pieces[i][j] = all_pieces[i][k]
						all_pieces[i][k] = null
						break
	get_parent().get_node("refill_timer").start()

func refill_columns():
	
	for i in width:
		for j in height:
			if all_pieces[i][j] == null && !no_fill(Vector2(i,j)):
				# random number
				var rand = randi_range(0, possible_pieces.size() - 1)
				# instance 
				var piece = possible_pieces[rand].instantiate()
				# repeat until no matches
				var max_loops = 100
				var loops = 0
				while (match_at(i, j, piece.color) and loops < max_loops):
					rand = randi_range(0, possible_pieces.size() - 1)
					loops += 1
					piece = possible_pieces[rand].instantiate()
				add_child(piece)
				piece.position = grid_to_pixel(i, j - y_offset)
				piece.move(grid_to_pixel(i, j))
				# fill array with pieces
				all_pieces[i][j] = piece
				
	check_after_refill()

func check_after_refill():
	for i in width:
		for j in height:
			if all_pieces[i][j] != null and match_at(i, j, all_pieces[i][j].color):
				find_matches()
				get_parent().get_node("destroy_timer").start()
				return
	if !damaged_slime:
		generate_slime()
	state = MOVE
	streak=0
	if move_counter > 0 && !timer:
		move_counter-=1
		update_move_counter.emit(move_counter)
	elif !timer && move_counter<=0:
		game_over()
	move_checked = false
	damaged_slime = false

func generate_slime():
	if slime_spaces.size() > 0:
		var slime_made = false
		var tracker = 0
		while !slime_made and tracker < 100:
			var random_num = floor(randf_range(0, slime_spaces.size()))
			var curr_x = slime_spaces[random_num].x
			var curr_y = slime_spaces[random_num].y
			var neighbor = find_normal_neighbor(curr_x, curr_y)
			if neighbor != null:
				all_pieces[neighbor.x][neighbor.y].queue_free()
				all_pieces[neighbor.x][neighbor.y] = null
				slime_spaces.append(Vector2(neighbor.x, neighbor.y))
				make_slime.emit(Vector2(neighbor.x, neighbor.y))
				slime_made = true
			tracker += 1

func find_normal_neighbor(column, row):

	if in_grid(column + 1, row):
		if all_pieces[column + 1][row] != null and !is_piece_sinker(column + 1, row):
			return Vector2(column + 1, row)

	elif in_grid(column - 1, row):
		if all_pieces[column - 1][row] != null and !is_piece_sinker(column - 1, row):
			return Vector2(column - 1, row)

	elif in_grid(column, row + 1):
		if all_pieces[column][row + 1] != null and !is_piece_sinker(column, row + 1):
			return Vector2(column, row + 1)

	elif in_grid(column, row -1):
		if all_pieces[column][row-1] != null and !is_piece_sinker(column, row - 1):
			return Vector2(column, row-1)
	return null

func _on_destroy_timer_timeout():
	print("destroy")
	destroy_matched()

func _on_collapse_timer_timeout():
	print("collapse")
	collapse_columns()

func _on_refill_timer_timeout():
	refill_columns()
	
func game_over():
	state = WAIT
	print("game over")
	if won:
		get_tree().change_scene_to_file('res://scenes/won.tscn')
	else:
		get_tree().change_scene_to_file('res://scenes/lost.tscn')

func _on_clock_timeout():
	if counter>0:
		counter-=1
		update_timer.emit(counter)
	else:
		game_over()
	

func _on_icing_holder_remove_icing(board_position):
	for i in range(icing_spaces.size()-1,-1,-1):
		if icing_spaces[i]==board_position:
			icing_spaces.remove_at(i)

func _on_lock_holder_remove_lock(board_position):
	for i in range(lock_spaces.size()-1,-1,-1):
		if lock_spaces[i]==board_position:
			lock_spaces.remove_at(i)

func _on_slime_holder_remove_slime(board_position):
	damaged_slime = true
	for i in range(slime_spaces.size()-1,-1,-1):
		if slime_spaces[i]==board_position:
			slime_spaces.remove_at(i)


func _on_jelly_holder_remove_jelly(board_position):
	for i in range(jelly_spaces.size()-1,-1,-1):
		if jelly_spaces[i]==board_position:
			jelly_spaces.remove_at(i)
