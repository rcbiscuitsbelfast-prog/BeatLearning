class_name CaptureGameplayManager extends GameplayManager
extends GameplayManager

# Specialized version of GameplayManager for demon capture sequences
# Integrates with Mymiff AARPG's enemy and capture systems

signal capture_progress_updated(progress: float)  # 0.0 to 1.0
signal capture_successful(accuracy: float)
signal capture_failed(accuracy: float)

# Capture-specific settings
var capture_duration: float = 30.0  # seconds
var time_remaining: float = 30.0
var capture_progress: float = 0.0   # 0.0 to 1.0
var capture_threshold: float = 1.0  # Progress needed for success

# Capture scoring gains (per note hit)
const CAPTURE_GAIN_PERFECT = 0.03
const CAPTURE_GAIN_GREAT = 0.02
const CAPTURE_GAIN_GOOD = 0.01
const CAPTURE_PENALTY_MISS = -0.01

@onready var capture_timer: Timer = $CaptureTimer

func _ready():
	super._ready()
	setup_capture_timer()

func setup_capture_timer():
	capture_timer = Timer.new()
	capture_timer.wait_time = 1.0  # Update every second
	capture_timer.timeout.connect(_update_capture_timer)
	add_child(capture_timer)

func start_capture_mode(beatmap_file: String, audio_file: String, duration: float = 30.0) -> bool:
	"""Start capture mode with specified duration"""
	capture_duration = duration
	time_remaining = duration
	capture_progress = 0.0

	# Start the underlying rhythm game
	var success = start_song(beatmap_file, audio_file)
	if success:
		capture_timer.start()
		print("Capture mode started - Duration: ", duration, " seconds")
	return success

func _update_capture_timer():
	"""Update capture timer"""
	if not is_playing:
		return

	time_remaining -= 1.0

	# Check for time-based capture failure
	if time_remaining <= 0.0:
		end_capture_mode(false)
		return

	# Check for progress-based capture success
	if capture_progress >= capture_threshold:
		end_capture_mode(true)

func _on_lane_note_hit(lane_index: int, accuracy: String):
	"""Override to add capture progress logic"""
	super._on_lane_note_hit(lane_index, accuracy)

	# Update capture progress based on accuracy
	var gain: float
	match accuracy:
		"PERFECT":
			gain = CAPTURE_GAIN_PERFECT
		"GREAT":
			gain = CAPTURE_GAIN_GREAT
		"GOOD":
			gain = CAPTURE_GAIN_GOOD
		"MISS":
			gain = CAPTURE_PENALTY_MISS
		_:
			gain = 0.0

	# Update progress and clamp between 0 and 1
	capture_progress = clamp(capture_progress + gain, 0.0, 1.0)
	capture_progress_updated.emit(capture_progress)

	# Visual feedback for capture progress
	if capture_progress >= 0.8 and visual_effects:
		visual_effects.create_capture_near_success_effect()

func _on_lane_note_missed(lane_index: int):
	"""Override to add capture progress penalty"""
	super._on_lane_note_missed(lane_index)

	# Apply penalty for missed notes
	capture_progress = clamp(capture_progress + CAPTURE_PENALTY_MISS, 0.0, 1.0)
	capture_progress_updated.emit(capture_progress)

func end_capture_mode(success: bool):
	"""End capture mode and emit appropriate signal"""
	if not is_playing:
		return

	# Stop the rhythm game
	stop_game()
	capture_timer.stop()

	# Calculate final accuracy
	var final_accuracy = calculate_accuracy() / 100.0  # Convert to 0.0-1.0 range

	if success:
		print("Capture SUCCESSFUL! Accuracy: ", final_accuracy * 100, "%")
		capture_successful.emit(final_accuracy)
	else:
		print("Capture FAILED! Accuracy: ", final_accuracy * 100, "%")
		capture_failed.emit(final_accuracy)

func get_capture_status() -> Dictionary:
	"""Get current capture status"""
	return {
		"time_remaining": time_remaining,
		"capture_progress": capture_progress,
		"is_playing": is_playing,
		"accuracy": calculate_accuracy() / 100.0,
		"combo": combo,
		"max_combo": max_combo
	}

func force_end_capture():
	"""Manually force end capture mode"""
	if is_playing:
		end_capture_mode(capture_progress >= capture_threshold)

func set_capture_duration(duration: float):
	"""Set custom capture duration"""
	capture_duration = duration
	if is_playing:
		time_remaining = duration

func set_capture_threshold(threshold: float):
	"""Set custom capture threshold (0.0 to 1.0)"""
	capture_threshold = clamp(threshold, 0.0, 1.0)