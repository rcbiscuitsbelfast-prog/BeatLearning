class_name GameplayManager
extends Node

# Core gameplay logic, timing synchronization, and note spawning
# Manages the entire game flow from start to finish

signal song_started(beatmap_data: Dictionary)
signal song_finished(score: int)
signal note_hit(lane: int, accuracy: String, score: int)
signal note_missed(lane: int)
signal combo_changed(combo: int, max_combo: int)
signal score_changed(score: int)

@onready var audio_manager: AudioManager = $AudioManager
@onready var note_spawn_timer: Timer = $NoteSpawnTimer
@onready var game_timer: Timer = $GameTimer
@onready var visual_effects: VisualEffectsManager = $VisualEffectsManager

# Lane system
var lanes: Array[Lane] = []
var lane_nodes: Array[Node2D] = []

# Game state
var current_beatmap: Dictionary = {}
var current_audio_file: String = ""
var is_playing: bool = false
var is_paused: bool = false

# Timing and scoring
const NOTE_TRAVEL_TIME_MS = 2000  # Time for notes to travel from spawn to hit zone
const HIT_WINDOW_MS = 150  # Hit detection window
var current_time_ms: int = 0
var song_start_time_ms: int = 0
var song_duration_ms: int = 0

# Scoring system
var score: int = 0
var combo: int = 0
var max_combo: int = 0
var total_notes: int = 0
var notes_hit: int = 0
var perfect_hits: int = 0
var great_hits: int = 0
var good_hits: int = 0
var misses: int = 0

# Score values
const SCORE_PERFECT = 300
const SCORE_GREAT = 200
const SCORE_GOOD = 100
const SCORE_MISS = 0

# Note management
var note_scene: PackedScene
var active_notes: Array[Note] = []
var note_index: int = 0  # Current index in beatmap hit objects

func _ready():
	setup_lanes()
	setup_note_scene()
	connect_signals()

func setup_lanes():
	# Create 4 lanes
	for i in range(4):
		var lane = Lane.new()
		lane.lane_index = i
		lane.name = "Lane" + str(i)
		lane.hit_window_ms = HIT_WINDOW_MS

		# Connect lane signals
		lane.note_hit.connect(_on_lane_note_hit)
		lane.note_missed.connect(_on_lane_note_missed)
		lane.combo_changed.connect(_on_lane_combo_changed)

		lanes.append(lane)
		add_child(lane)

	# Position lanes based on screen size
	call_deferred("position_lanes")

func position_lanes():
	var screen_size = get_viewport().get_visible_rect().size
	var lane_width = screen_size.x * 0.1875  # 15% per lane
	var spacer_width = screen_size.x * 0.0125  # 2.5% between lanes
	var total_width = (lane_width + spacer_width) * 4 - spacer_width
	var start_x = (screen_size.x - total_width) / 2

	for i in range(lanes.size()):
		var lane = lanes[i]
		var x_position = start_x + i * (lane_width + spacer_width)
		lane.position.x = x_position
		lane.position.y = 0

func setup_note_scene():
	# Create or load note scene
	note_scene = PackedScene.new()
	var note_node = Note.new()
	note_scene.pack(note_node)

func connect_signals():
	# Connect audio manager signals
	audio_manager.audio_started.connect(_on_audio_started)
	audio_manager.audio_finished.connect(_on_audio_finished)
	audio_manager.audio_paused.connect(_on_audio_paused)
	audio_manager.audio_resumed.connect(_on_audio_resumed)

	# Connect timer signals
	note_spawn_timer.timeout.connect(_spawn_notes)
	game_timer.timeout.connect(_update_game_state)

func start_song(beatmap_file: String, audio_file: String) -> bool:
	# Load beatmap
	var beatmap_parser = BeatmapParser.new()
	current_beatmap = beatmap_parser.parse_beatmap(beatmap_file)

	if not beatmap_parser.validate_beatmap(current_beatmap):
		push_error("Invalid beatmap file: " + beatmap_file)
		return false

	# Check if this is a BeatLearning-generated beatmap
	if beatmap_parser.is_beatlearning_generated(current_beatmap):
		print("Playing BeatLearning-generated beatmap")
		var bl_info = beatmap_parser.get_beatlearning_info(current_beatmap)
		print("BeatLearning version: ", bl_info.version)
		print("Lanes: ", bl_info.lanes)
		print("Style: ", bl_info.style)

		# Adjust gameplay parameters for BeatLearning beatmaps
		if bl_info.lanes != 4:
			print("Warning: BeatLearning beatmap uses ", bl_info.lanes, " lanes, but game supports 4")
			# Could adjust lane configuration here if needed

	# Load audio
	if not audio_manager.load_audio(audio_file):
		push_error("Failed to load audio file: " + audio_file)
		return false

	# Initialize game state
	initialize_game()

	# Create special startup effect for BeatLearning beatmaps
	if beatmap_parser.is_beatlearning_generated(current_beatmap) and visual_effects:
		visual_effects.create_beatlearning_startup_effect()

	# Start playback
	if not audio_manager.play_audio():
		push_error("Failed to start audio playback")
		return false

	is_playing = true
	is_paused = false

	# Start game timers
	game_timer.wait_time = 0.016  # ~60 FPS
	game_timer.start()
	note_spawn_timer.wait_time = 0.1  # Check for notes every 100ms
	note_spawn_timer.start()

	song_started.emit(current_beatmap)
	return true

func initialize_game():
	# Reset game state
	current_time_ms = 0
	song_start_time_ms = Time.get_ticks_msec()
	note_index = 0
	score = 0
	combo = 0
	max_combo = 0
	total_notes = current_beatmap.hit_objects.size()
	notes_hit = 0
	perfect_hits = 0
	great_hits = 0
	good_hits = 0
	misses = 0

	# Clear existing notes
	for note in active_notes:
		note.queue_free()
	active_notes.clear()

	# Reset lanes
	for lane in lanes:
		lane.reset_lane()

	# Get song duration
	song_duration_ms = audio_manager.get_duration_ms()

func _process(delta):
	if is_playing and not is_paused:
		# Update current time from audio manager
		current_time_ms = audio_manager.get_playback_position_ms()

func _update_game_state():
	if not is_playing or is_paused:
		return

	# Check for missed notes
	check_missed_notes()

	# Update visual effects and UI (called via signals)
	pass

func _spawn_notes():
	if not is_playing or is_paused:
		return

	# Check which notes should be spawned now
	var spawn_time = current_time_ms + NOTE_TRAVEL_TIME_MS

	while note_index < current_beatmap.hit_objects.size():
		var note_data = current_beatmap.hit_objects[note_index]

		if note_data.time <= spawn_time:
			spawn_note(note_data)
			note_index += 1
		else:
			break

func spawn_note(note_data: Dictionary):
	var note: Note = note_scene.instantiate()

	# Set note properties
	var note_type = Note.NoteType.TAP
	if note_data.type == "hold":
		note_type = Note.NoteType.HOLD

	note.initialize(
		note_data.lane,
		note_type,
		note_data.time,
		note_data.get("duration", 0)
	)

	# Set position
	var screen_size = get_viewport().get_visible_rect().size
	var lane_width = screen_size.x * 0.1875
	var spacer_width = screen_size.x * 0.0125
	var total_width = (lane_width + spacer_width) * 4 - spacer_width
	var start_x = (screen_size.x - total_width) / 2

	var x_position = start_x + note_data.lane * (lane_width + spacer_width) + lane_width / 2
	note.position.x = x_position
	note.position.y = -100  # Start above screen

	# Add to scene and track
	add_child(note)
	active_notes.append(note)

	# Add to appropriate lane
	lanes[note_data.lane].add_note(note)

	# Connect signals
	note.note_hit.connect(_on_note_hit)
	note.note_missed.connect(_on_note_missed)
	note.note_destroyed.connect(_on_note_destroyed)

func check_missed_notes():
	var current_time = audio_manager.get_playback_position_ms()

	for note in active_notes:
		if note.current_state == Note.NoteState.MOVING:
			var time_diff = current_time - note.time

			# If note is significantly past its timing window
			if time_diff > HIT_WINDOW_MS + 200:
				if note.global_position.y > lanes[0].hit_zone.global_position.y + 100:
					note.miss_note()

func pause_game():
	if not is_playing or is_paused:
		return

	audio_manager.pause_audio()
	is_paused = true

	game_timer.paused = true
	note_spawn_timer.paused = true

func resume_game():
	if not is_playing or not is_paused:
		return

	audio_manager.resume_audio()
	is_paused = false

	game_timer.paused = false
	note_spawn_timer.paused = false

func stop_game():
	if not is_playing:
		return

	audio_manager.stop_audio()
	is_playing = false
	is_paused = false

	game_timer.stop()
	note_spawn_timer.stop()

	# Calculate final score
	var final_score = calculate_final_score()
	song_finished.emit(final_score)

func calculate_final_score() -> int:
	# Apply combo multiplier to base score
	var base_score = (perfect_hits * SCORE_PERFECT +
					great_hits * SCORE_GREAT +
					good_hits * SCORE_GOOD)

	# Combo bonus
	var combo_bonus = max_combo * 10

	return base_score + combo_bonus

func _on_lane_note_hit(lane_index: int, accuracy: String):
	var hit_score = 0

	match accuracy:
		"PERFECT":
			hit_score = SCORE_PERFECT
			perfect_hits += 1
		"GREAT":
			hit_score = SCORE_GREAT
			great_hits += 1
		"GOOD":
			hit_score = SCORE_GOOD
			good_hits += 1
		"MISS":
			hit_score = SCORE_MISS
			misses += 1
			combo = 0

	score += hit_score
	notes_hit += 1

	if accuracy != "MISS":
		combo += 1
		max_combo = max(max_combo, combo)

		# Check for combo milestones
		if combo % 10 == 0:
			trigger_combo_milestone_effect(combo)

	note_hit.emit(lane_index, accuracy, hit_score)
	score_changed.emit(score)
	combo_changed.emit(combo, max_combo)

func _on_lane_note_missed(lane_index: int):
	misses += 1
	combo = 0

	note_missed.emit(lane_index)
	combo_changed.emit(combo, max_combo)

func _on_lane_combo_changed(lane_index: int, lane_combo: int):
	# Individual lane combo tracking (optional)
	pass

# Check for combo milestones in the main combo system
func _on_combo_updated():
	if combo > 0 and combo % 10 == 0:
		trigger_combo_milestone_effect(combo)

func trigger_combo_milestone_effect(combo_count: int):
	# Create special effects for combo milestones
	if visual_effects:
		# Position at center of screen
		var center_pos = get_viewport().get_visible_rect().size / 2
		visual_effects.create_combo_milestone_effect(combo_count, center_pos)

	# Apply stronger screen shake for higher combos
	var shake_intensity = min(10.0 + combo_count / 10.0, 30.0)
	if visual_effects:
		visual_effects.apply_screen_shake(shake_intensity, 0.2)

	print("COMBO MILESTONE: ", combo_count)

func _on_note_hit(note: Note, accuracy: String):
	# Note hit confirmation
	pass

func _on_note_missed(note: Note):
	# Note miss confirmation
	pass

func _on_note_destroyed(note: Note):
	active_notes.erase(note)

func _on_audio_started():
	# Audio has started playing
	pass

func _on_audio_finished():
	# Song has finished
	stop_game()

func _on_audio_paused():
	# Audio was paused
	pass

func _on_audio_resumed():
	# Audio was resumed
	pass

func get_game_stats() -> Dictionary:
	return {
		"score": score,
		"combo": combo,
		"max_combo": max_combo,
		"total_notes": total_notes,
		"notes_hit": notes_hit,
		"perfect_hits": perfect_hits,
		"great_hits": great_hits,
		"good_hits": good_hits,
		"misses": misses,
		"accuracy": calculate_accuracy() if total_notes > 0 else 0.0,
		"current_time": current_time_ms,
		"song_duration": song_duration_ms,
		"is_playing": is_playing,
		"is_paused": is_paused
	}

func calculate_accuracy() -> float:
	if total_notes == 0:
		return 0.0

	var weighted_hits = (perfect_hits * 1.0 +
						great_hits * 0.7 +
						good_hits * 0.4)

	return (weighted_hits / total_notes) * 100.0

func set_hit_window(window_ms: int):
	HIT_WINDOW_MS = window_ms
	for lane in lanes:
		lane.hit_window_ms = window_ms

func set_note_travel_time(time_ms: int):
	NOTE_TRAVEL_TIME_MS = time_ms