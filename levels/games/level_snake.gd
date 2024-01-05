extends Node2D

############################################
## GAME CONSTANTS

const TILESET_SOURCE_ID_DOG = 0
const TILESET_SOURCE_ID_BONE = 1

const INITIAL_WAIT_TIME:float = 0.4
const SPEED_MULTIPLER:float = 1.1
const INITIAL_DOG_BLOCKS:Array[Vector2] = [Vector2(3,2), Vector2(2,2), Vector2(1,2)]
const INITIAL_DOG_DIR:Vector2 = Vector2.RIGHT

# @note: Hardcoded in the tileset as well (and for scale)
const CELL_SIZE:int = 64 
# @note: Obtain size of the window
@onready var X_MAX:int = get_viewport().size.x
@onready var Y_MAX:int = get_viewport().size.y
@onready var CELL_COLS:float = float(X_MAX) / CELL_SIZE
@onready var CELL_ROWS:float = float(Y_MAX) / CELL_SIZE

# Keep orignal text because it's changed via format_string
# and we lose the `%s` for the score
@onready var GAME_OVER_TEXT:String = $Labels/GameOver/Label.text

# Keep one (or more) directions) in memory for the next ticks
var direction_buffer:Array[String]

signal exit()

############################################
## GAME VARIABLES

var is_started:bool = false
var is_paused:bool = false
var is_game_over:bool = false
var score:int = 0
var bone_position:Vector2
var dog_blocks:Array[Vector2]
var dog_direction:Vector2 

############################################
## GAME FUNCTIONS
	
func gen_random_vector():
	var x = randi_range(1, CELL_COLS - 2)
	var y = randi_range(1, CELL_ROWS - 2)
	return Vector2(x,y)

func draw_bone():
	$TileMapGame.clear_layer(1)
	var new_bone_position = gen_random_vector()
	# Ensure we don't draw the bone on the dog
	# or on the previous bone position
	while (new_bone_position in dog_blocks
		or new_bone_position == bone_position):
		new_bone_position = gen_random_vector()
	bone_position = new_bone_position
	$TileMapGame.set_cell(1, bone_position, TILESET_SOURCE_ID_BONE, Vector2(2, 2))

func get_head():
	if dog_direction == Vector2.RIGHT:
		return Vector2(6,2)
	if dog_direction == Vector2.LEFT:
		return Vector2(4,3)
	if dog_direction == Vector2.DOWN:
		return Vector2(7,4)
	if dog_direction == Vector2.UP:
		return Vector2(3,2)
	
func get_tail(current_block:Vector2, prev_block:Vector2):
	var block_relation = prev_block - current_block
	if block_relation == Vector2.RIGHT:
		return Vector2(4,2)
	if block_relation == Vector2.LEFT:
		return Vector2(6,3)
	if block_relation == Vector2.DOWN:
		return Vector2(7,2)
	if block_relation == Vector2.UP:
		return Vector2(3,4)

func get_body(current_block:Vector2, prev_block:Vector2, next_block: Vector2):
	var block_relation_1 = prev_block - current_block
	var block_relation_2 = current_block - next_block
	
	# movements on x axis
	if (block_relation_1.x > 0 and block_relation_1.y == 0
		and block_relation_2.x > 0 and block_relation_2.y == 0):
		return Vector2(5,2)
	if (block_relation_1.x < 0 and block_relation_1.y == 0
		and block_relation_2.x < 0 and block_relation_2.y == 0):
		return Vector2(5,3)

	# movements on y axis
	if (block_relation_1.x == 0 and block_relation_1.y > 0
		and block_relation_2.x == 0 and block_relation_2.y > 0):
		return Vector2(7,3)
	if (block_relation_1.x == 0 and block_relation_1.y < 0
		and block_relation_2.x == 0 and block_relation_2.y < 0):
		return Vector2(3,3)

	# corners clockwise
	if (block_relation_1.x == 0 and block_relation_1.y > 0
		and block_relation_2.x > 0 and block_relation_2.y == 0):
		return Vector2(9,3)
	if (block_relation_1.x < 0 and block_relation_1.y == 0
		and block_relation_2.x == 0 and block_relation_2.y > 0):
		return Vector2(9,4)
	if (block_relation_1.x == 0 and block_relation_1.y < 0
		and block_relation_2.x < 0 and block_relation_2.y == 0):
		return Vector2(8,4)
	if (block_relation_1.x > 0 and block_relation_1.y == 0
		and block_relation_2.x == 0 and block_relation_2.y < 0):
		return Vector2(8,3)
		
	# corners anticlockwise
	if (block_relation_1.x < 0 and block_relation_1.y == 0
		and block_relation_2.x == 0 and block_relation_2.y < 0):
		return Vector2(9,3)
	if (block_relation_1.x == 0 and block_relation_1.y > 0
		and block_relation_2.x < 0 and block_relation_2.y == 0):
		return Vector2(8,3)
	if (block_relation_1.x > 0 and block_relation_1.y == 0
		and block_relation_2.x == 0 and block_relation_2.y > 0):
		return Vector2(8,4)
	if (block_relation_1.x == 0 and block_relation_1.y < 0
		and block_relation_2.x > 0 and block_relation_2.y == 0):
		return Vector2(9,4)

func draw_dog():
	$TileMapGame.clear_layer(0)
	for i in dog_blocks.size():
		var current_block = dog_blocks[i]
		var tile:Vector2
		if(i == 0):
			tile = get_head()
		elif(i == dog_blocks.size() - 1):
				tile = get_tail(current_block, dog_blocks[i-1])
		else:
			tile = get_body(current_block, dog_blocks[i-1], dog_blocks[i+1])
		$TileMapGame.set_cell(0, current_block, TILESET_SOURCE_ID_DOG, tile)
	
func move_dog():
	var new_dog_blocks = dog_blocks
	var new_head = dog_blocks[0] + dog_direction
	
	# Check GameOver
	if (new_head.x < 0
		|| new_head.x > CELL_COLS - 1
		|| new_head.y < 1
		|| new_head.y > CELL_ROWS - 2
		|| new_head in dog_blocks):
		game_over()
		pass
		
	# Check bone eaten
	if new_head == bone_position:
		eat_bone()
	else:
		# remove the last position to keep the same length
		new_dog_blocks = dog_blocks.slice(0,-1)
	
	# add the new head at the new position
	new_dog_blocks.push_front(new_head)
	
	dog_blocks = new_dog_blocks
	draw_dog()
	
func eat_bone():
	score += 1
	# Update score
	$Labels/Score/ScoreCount.text = str(score)
	# Play crunch sound
	$Sounds/CrunchSound.play()
	# Speed up game
	$DogTick.wait_time /= SPEED_MULTIPLER
	# Draw new bone inside the grid
	draw_bone()

func start():
	score = 0
	is_started = true
	is_game_over = false
	is_paused = false
	$TileMapGame.show()
	$DogTick.wait_time = INITIAL_WAIT_TIME
	$DogTick.start()
	$Labels/Start.hide()
	$Labels/Score.show()
	$Labels/GameOver.hide()
	$Labels/GameOver/Label.text = GAME_OVER_TEXT
	dog_blocks = INITIAL_DOG_BLOCKS
	dog_direction = INITIAL_DOG_DIR
	draw_bone()
	draw_dog()

func pause():
	is_paused = true
	$DogTick.stop()
	$Labels/Pause/RestartButton.grab_focus()
	$Labels/Pause.show()

func restart():
	is_paused = false
	$DogTick.start()
	$Labels/Pause.hide()

func game_over():
	is_game_over = true
	$DogTick.stop()
	$TileMapGame.hide()
	$Labels/GameOver.show()
	$Labels/GameOver/StartButton.grab_focus()
	$Labels/GameOver/Label.text %= str(score)

############################################
## PRE-BUILT FUNCTIONS

func _ready():
	$Labels/Start/StartButton.grab_focus()

func _input(_event):
	if is_started and !is_game_over and !is_paused:
		if Input.is_action_pressed("escape"):
			pause()
	if is_started:
		if Input.is_action_just_pressed("down"):
			if dog_direction != Vector2.UP:
				dog_direction = Vector2.DOWN
		if Input.is_action_just_pressed("up"):
			if dog_direction != Vector2.DOWN:
				dog_direction = Vector2.UP
		if Input.is_action_just_pressed("right"):
			if dog_direction != Vector2.LEFT:
				dog_direction = Vector2.RIGHT
		if Input.is_action_just_pressed("left"):
			if dog_direction != Vector2.RIGHT:
				dog_direction = Vector2.LEFT

func _on_dog_tick_timeout():
	move_dog()

func _on_start_button_pressed():
	start()

func _on_restart_button_pressed():
	restart()

func _on_exit_button_pressed():
	exit.emit()


