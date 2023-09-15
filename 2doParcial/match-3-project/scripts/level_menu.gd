extends Node2D


func _on_bomb_color_bomb_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/bombs.tscn")


func _on_empty_spaces_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/empty spaces.tscn")


func _on_jelly_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/jelly.tscn")


func _on_icing_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/icing.tscn")


func _on_chocolate_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/chocolate.tscn")


func _on_licorice_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/licorice.tscn")


func _on_all_pressed():
	get_tree().change_scene_to_file("res://scenes/niveles/all.tscn")
