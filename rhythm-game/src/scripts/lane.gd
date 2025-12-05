class_name Lane
extends Node2D

# Lane system for 4-lane rhythm game layout
# Manages individual lanes and note detection

@export var lane_index: int = 0
@export var lane_color: Color = Color.WHITE
@export var hit_window_ms: int = 150  # Timing window in milliseconds

@onready var lane_sprite: ColorRect = $LaneColor
@onready var hit_zone: ColorRect = $HitZone
@onready var lane_label: Label = $LaneLabel
@onready var effect_parent: Node2D = $Effects
var visual_effects: VisualEffectsManager

var notes_in_lane: Array[Note] = []
var current_combo: int = 0
var last_hit_time: int = 0
var hit_flash_timer: float = 0.0

# Lane configuration
const LANE_WIDTH_PERCENT = 0.1875  # 15% of screen width per lane
const LANE_SPACER_PERCENT = 0.0125  # 2.5% between lanes

# Colors for different lanes
const LANE_COLORS = [
	Color(1.0, 0.2, 0.2, 0.3),    # Red - Lane 0 (D key)
	Color(0.2, 0.2, 1.0, 0.3),    # Blue - Lane 1 (F key)
	Color(0.2, 1.0, 0.2, 0.3),    # Green - Lane 2 (J key)
	Color(1.0, 1.0, 0.2, 0.3)     # Yellow - Lane 3 (K key)
]

# Key bindings for lanes
const LANE_KEYS = [KEY_D, KEY_F, KEY_J, KEY_K]

signal note_hit(lane_index: int, accuracy: String)
signal note_missed(lane_index: int)
signal combo_changed(lane_index: int, combo: int)

func _ready():
	setup_lane_appearance()
	connect_input()
	setup_visual_effects()

func setup_lane_appearance():
	# Set lane color
	if lane_index >= 0 and lane_index < LANE_COLORS.size():
		lane_color = LANE_COLORS[lane_index]
		lane_sprite.color = lane_color

	# Set up hit zone
	hit_zone.color.a = 0.8
	hit_zone.color = lane_color.lightened(0.5)

	# Set lane label
	if lane_index < LANE_KEYS.size():
		var key_name = OS.get_keycode_string(LANE_KEYS[lane_index])
		lane_label.text = key_name
		lane_label.modulate = lane_color.lightened(0.8)

func connect_input():
	# Input is handled by the gameplay manager, but we could listen here too
	pass

func setup_visual_effects():
	# Try to find or create visual effects manager
	visual_effects = get_node_or_null("../VisualEffectsManager")
	if visual_effects == null:
		# Create visual effects manager if it doesn't exist
		visual_effects = VisualEffectsManager.new()
		visual_effects.name = "VisualEffectsManager"
		get_parent().add_child(visual_effects)

func _input(event):
	if event is InputEventKey and event.pressed:
		for i in range(LANE_KEYS.size()):
			if event.keycode == LANE_KEYS[i] and i == lane_index:
				handle_lane_press()
				break

func handle_lane_press():
	# Check for notes in hit zone
	var current_time = Time.get_ticks_msec()
	var hit_note = find_note_in_hit_window(current_time)

	if hit_note:
		var time_diff = abs(current_time - hit_note.time)
		var accuracy = calculate_accuracy(time_diff)

		hit_note.hit_note(time_diff)
		remove_note_from_lane(hit_note)

		current_combo += 1
		trigger_hit_effect(accuracy)

		note_hit.emit(lane_index, accuracy)
		combo_changed.emit(lane_index, current_combo)
	else:
		# No note hit - could handle empty hit feedback here
		pass

func add_note(note: Note):
	if note.lane == lane_index:
		notes_in_lane.append(note)
		note.connect("note_destroyed", _on_note_destroyed)
		note.connect("note_missed", _on_note_missed)
		note.connect("note_hit", _on_note_hit)

func remove_note_from_lane(note: Note):
	notes_in_lane.erase(note)

func find_note_in_hit_window(current_time: int) -> Note:
	for note in notes_in_lane:
		if note.current_state == Note.NoteState.MOVING:
			var time_diff = abs(current_time - note.time)
			if time_diff <= hit_window_ms:
				return note
	return null

func calculate_accuracy(time_diff: int) -> String:
	if time_diff <= 50:
		return "PERFECT"
	elif time_diff <= 100:
		return "GREAT"
	elif time_diff <= 150:
		return "GOOD"
	else:
		return "MISS"

func trigger_hit_effect(accuracy: String):
	var effect_color = Color.WHITE

	match accuracy:
		"PERFECT":
			effect_color = Color.GOLD
			hit_flash_timer = 0.3
		"GREAT":
			effect_color = Color.GREEN
			hit_flash_timer = 0.2
		"GOOD":
			effect_color = Color.CYAN
			hit_flash_timer = 0.1
		_:
			effect_color = Color.WHITE
			hit_flash_timer = 0.1

	# Flash hit zone
	hit_zone.color = effect_color
	hit_zone.color.a = 1.0

	# Create enhanced visual effects using VisualEffectsManager
	if visual_effects:
		visual_effects.create_hit_effect(hit_zone.global_position, accuracy.to_lower(), lane_index)

		# Create lane glow effect
		visual_effects.create_lane_glow_effect(lane_index, 1.0)

		# Special effects for perfect hits
		if accuracy == "PERFECT":
			visual_effects.create_perfect_feedback(hit_zone.global_position, lane_index)

	# Keep simple particle effect as fallback
	create_hit_particle(effect_color)

func create_hit_particle(color: Color):
	# Create a simple particle effect (fallback)
	var particle = Sprite2D.new()
	particle.texture = preload("res://icon.svg")  # Placeholder
	particle.scale = Vector2(0.1, 0.1)
	particle.modulate = color
	particle.position = hit_zone.position + hit_zone.size / 2
	particle.z_index = 100

	effect_parent.add_child(particle)

	# Animate particle
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(particle, "scale", Vector2(0.5, 0.5), 0.3)
	tween.tween_property(particle, "modulate:a", 0.0, 0.3)
	tween.tween_callback(particle.queue_free).set_delay(0.3)

func trigger_miss_effect():
	hit_zone.color = Color.RED
	hit_zone.color.a = 0.8
	hit_flash_timer = 0.2

	# Create miss feedback effect
	if visual_effects:
		visual_effects.create_miss_feedback(hit_zone.global_position, lane_index)

	current_combo = 0
	combo_changed.emit(lane_index, current_combo)

func _process(delta):
	# Update hit zone flash effect
	if hit_flash_timer > 0:
		hit_flash_timer -= delta
		var alpha = hit_flash_timer * 3.0  # Fade out
		hit_zone.color.a = min(1.0, alpha)

		if hit_flash_timer <= 0:
			# Reset to original color
			hit_zone.color = lane_color.lightened(0.5)
			hit_zone.color.a = 0.8

	# Check for missed notes
	check_missed_notes()

func check_missed_notes():
	var current_time = Time.get_ticks_msec()

	for note in notes_in_lane.duplicate():
		if note.current_state == Note.NoteState.MOVING:
			var time_diff = current_time - note.time

			# If note is significantly past its timing window, mark as missed
			if time_diff > hit_window_ms + 200:  # Extra 200ms grace period
				if note.global_position.y > hit_zone.global_position.y + 100:
					note.miss_note()

func _on_note_hit(note: Note, accuracy: String):
	# Handle note hit event
	pass

func _on_note_missed(note: Note):
	# Handle note miss event
	if note.lane == lane_index:
		trigger_miss_effect()
		note_missed.emit(lane_index)

func _on_note_destroyed(note: Note):
	remove_note_from_lane(note)

func get_lanes() -> Array:
	return ["D", "F", "J", "K"]

func reset_lane():
	# Clear all notes
	for note in notes_in_lane.duplicate():
		note.queue_free()

	notes_in_lane.clear()
	current_combo = 0
	combo_changed.emit(lane_index, current_combo)

func set_lane_position(screen_size: Vector2, lane_count: int = 4):
	var lane_width = screen_size.x * LANE_WIDTH_PERCENT
	var spacer_width = screen_size.x * LANE_SPACER_PERCENT

	var total_width = (lane_width + spacer_width) * lane_count - spacer_width
	var start_x = (screen_size.x - total_width) / 2

	var x_position = start_x + lane_index * (lane_width + spacer_width)

	position.x = x_position
	size.x = lane_width
	lane_sprite.size.x = lane_width
	hit_zone.size.x = lane_width

func get_stats() -> Dictionary:
	return {
		"lane_index": lane_index,
		"current_combo": current_combo,
		"active_notes": notes_in_lane.size(),
		"hit_window": hit_window_ms,
		"key_binding": OS.get_keycode_string(LANE_KEYS[min(lane_index, LANE_KEYS.size() - 1)])
	}