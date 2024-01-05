extends Control

var snake_scene:PackedScene = preload("res://levels/games/level_snake.tscn")
var current_game

func _ready():
	$Menu/SnakeButton.grab_focus()

func _on_snake_button_pressed():
	$Menu.hide() # disable all buttons
	
	# instanciate scene
	current_game = snake_scene.instantiate()
	add_child(current_game)
	current_game.connect("exit", _on_exit_game)

func _on_exit_game():
	$Menu.show() # enable all buttons
	$Menu/SnakeButton.grab_focus()
	current_game.queue_free() # remove scene

func _on_quit_button_pressed():
	get_tree().quit()
