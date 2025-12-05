class_name Note
extends Node2D

# Individual note behavior and rendering
# Handles tap notes, hold notes, and movement

enum NoteType {
	TAP,
	HOLD,
	EMPTY
}

enum NoteState {
	SPAWNING,
	MOVING,
	HIT,
	MISSED,
	DESTROYED
}

@export var lane: int = 0
@export var note_type: NoteType = NoteType.TAP
@export var time: int = 0  # Timestamp in milliseconds
@export var duration: int = 0  # Duration in milliseconds (for hold notes)
@export var speed: float = 300.0  # Pixels per second

@onready var sprite: Sprite2D = $Sprite2D
@onready var hold_body: Sprite2D = $HoldBody
@onready var collision: CollisionShape2D = $Area2D/CollisionShape2D

var current_state: NoteState = NoteState.SPAWNING
var spawn_time: float = 0.0
var start_y: float = -100.0
var hit_zone_y: float = 800.0
var hit_position: float = 0.0

# Colors for different lanes
const LANE_COLORS = [
	Color.RED,     # Lane 0 - D key
	Color.BLUE,    # Lane 1 - F key
	Color.GREEN,   # Lane 2 - J key
	Color.YELLOW   # Lane 3 - K key
]

signal note_hit(note: Note, accuracy: String)
signal note_missed(note: Note)
signal note_destroyed(note: Note)

func _ready():
	setup_note_appearance()

	# Calculate hit position based on speed and travel time
	hit_position = time

	# Hide hold body initially if not a hold note
	if note_type != NoteType.HOLD:
		hold_body.visible = false

func setup_note_appearance():
	# Set color based on lane
	if lane >= 0 and lane < LANE_COLORS.size():
		sprite.modulate = LANE_COLORS[lane]
		if note_type == NoteType.HOLD:
			hold_body.modulate = LANE_COLORS[lane]

	# Set different appearance for different note types
	match note_type:
		NoteType.TAP:
			sprite.scale = Vector2(1.0, 1.0)
		NoteType.HOLD:
			sprite.scale = Vector2(1.2, 1.2)
			setup_hold_note()
		NoteType.EMPTY:
			sprite.modulate.a = 0.5  # Semi-transparent

func setup_hold_note():
	if note_type == NoteType.HOLD:
		hold_body.visible = true
		# Hold body will be updated during movement
		update_hold_body_size()

func initialize(lane_index: int, type: NoteType, timestamp: int, hold_duration: int = 0):
	lane = lane_index
	note_type = type
	time = timestamp
	duration = hold_duration

	setup_note_appearance()

func _process(delta):
	match current_state:
		NoteState.SPAWNING:
			spawn_note(delta)
		NoteState.MOVING:
			move_note(delta)
		NoteState.HIT:
			handle_hit_animation(delta)
		NoteState.MISSED:
			handle_miss_animation(delta)
		NoteState.DESTROYED:
			destroy_note()

func spawn_note(delta: float):
	# Start from top of screen
	global_position.y = start_y
	current_state = NoteState.MOVING
	spawn_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0

func move_note(delta: float):
	# Move downward at constant speed
	global_position.y += speed * delta

	# Update hold note body if this is a hold note
	if note_type == NoteType.HOLD:
		update_hold_body_position()

	# Check if note has passed the hit zone
	if global_position.y > hit_zone_y + 100:
		if current_state == NoteState.MOVING:
			miss_note()

func update_hold_body_size():
	if note_type != NoteType.HOLD:
		return

	# Calculate hold note length based on duration and speed
	var hold_length = (float(duration) / 1000.0) * speed
	hold_body.scale.y = hold_length / 100.0  # Adjust based on texture size

func update_hold_body_position():
	if note_type != NoteType.HOLD:
		return

	# Position hold body below the arrow head
	hold_body.position.y = hold_body.get_texture().get_height() * hold_body.scale.y * 0.5

func check_hit(current_time: int, hit_window: int = 150) -> bool:
	if current_state != NoteState.MOVING:
		return false

	var time_diff = abs(current_time - time)

	if time_diff <= hit_window:
		hit_note(time_diff)
		return true

	return false

func hit_note(time_diff: float = 0.0):
	if current_state != NoteState.MOVING:
		return

	current_state = NoteState.HIT

	# Determine accuracy based on timing difference
	var accuracy = "PERFECT"
	if time_diff > 100:
		accuracy = "GOOD"
	elif time_diff > 50:
		accuracy = "GREAT"

	note_hit.emit(self, accuracy)

	# Create hit effect
	create_hit_effect()

func miss_note():
	if current_state != NoteState.MOVING:
		return

	current_state = NoteState.MISSED
	note_missed.emit(self)

	# Create miss effect
	create_miss_effect()

func create_hit_effect():
	# Visual feedback for successful hit
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(1.5, 1.5)

	# Create particles or other effects here if needed

func create_miss_effect():
	# Visual feedback for missed note
	sprite.modulate = Color.DARK_GRAY
	sprite.scale = Vector2(0.8, 0.8)

	# Create particles or other effects here if needed

func handle_hit_animation(delta: float):
	# Animate hit effect
	sprite.scale = sprite.scale.lerp(Vector2(0.1, 0.1), delta * 8.0)
	sprite.modulate.a = sprite.modulate.a - delta * 4.0

	if sprite.scale.length() < 0.2:
		current_state = NoteState.DESTROYED

func handle_miss_animation(delta: float):
	# Animate miss effect
	sprite.modulate.a = sprite.modulate.a - delta * 2.0

	if sprite.modulate.a <= 0.0:
		current_state = NoteState.DESTROYED

func destroy_note():
	note_destroyed.emit(self)
	queue_free()

func get_current_time_ms() -> int:
	var current_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0
	return int((current_time - spawn_time) * 1000.0)

func is_in_hit_zone() -> bool:
	var note_y = global_position.y
	return note_y >= hit_zone_y - 50 and note_y <= hit_zone_y + 50

func get_distance_to_hit_zone() -> float:
	return abs(global_position.y - hit_zone_y)

func get_time_to_hit_zone() -> float:
	if speed <= 0:
		return INF

	return get_distance_to_hit_zone() / speed

func is_hold_note_active(current_time: int) -> bool:
	if note_type != NoteType.HOLD or current_state != NoteState.HIT:
		return false

	var hold_start_time = time
	var hold_end_time = time + duration
	return current_time >= hold_start_time and current_time <= hold_end_time

func get_hold_progress(current_time: int) -> float:
	if note_type != NoteType.HOLD or duration <= 0:
		return 0.0

	var hold_start_time = time
	var hold_end_time = time + duration
	var progress = float(current_time - hold_start_time) / float(duration)
	return clamp(progress, 0.0, 1.0)