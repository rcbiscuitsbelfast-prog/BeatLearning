class_name AudioManager
extends Node

# Audio Manager for MP3 playback and synchronization
# Handles audio loading, playback, and timing synchronization

signal audio_started
signal audio_finished
signal audio_paused
signal audio_resumed

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var audio_timer: Timer = $AudioTimer

var current_audio_file: String = ""
var is_playing: bool = false
var is_paused: bool = false
var start_time: float = 0.0
var pause_time: float = 0.0
var total_duration: float = 0.0

# Timing compensation for audio latency
var audio_offset: float = 0.0  # Can be adjusted per song

func _ready():
	audio_player.finished.connect(_on_audio_finished)
	audio_timer.timeout.connect(_on_audio_timer_timeout)

	# Set up audio bus for better control
	var bus_index = AudioServer.get_bus_count()
	AudioServer.add_bus()
	AudioServer.set_bus_name(bus_index, "Music")
	audio_player.bus = "Music"

func load_audio(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Audio file not found: " + file_path)
		return false

	var audio_stream = AudioStreamMP3.new()
	if audio_stream.load_from_file(file_path) != OK:
		push_error("Failed to load audio file: " + file_path)
		return false

	audio_player.stream = audio_stream
	current_audio_file = file_path

	# Get the duration of the audio (approximate for MP3)
	# In Godot 4.x, we need to estimate this from the stream
	if audio_stream:
		total_duration = _estimate_mp3_duration(file_path)

	return true

func _estimate_mp3_duration(file_path: String) -> float:
	# This is a rough estimation - in a real implementation
	# you might want to use a more accurate method
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0.0

	var file_size = file.get_length()
	file.close()

	# Rough estimate: MP3 at 128 kbps, 8 seconds per MB
	var size_mb = float(file_size) / (1024.0 * 1024.0)
	return size_mb * 8.0

func play_audio(start_position: float = 0.0) -> bool:
	if audio_player.stream == null:
		push_error("No audio loaded")
		return false

	if is_paused:
		resume_audio()
		return true

	# Seek to start position
	audio_player.seek(start_position)

	# Start playback
	audio_player.play()
	is_playing = true
	is_paused = false
	start_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0 - start_position

	# Start timer for tracking playback
	audio_timer.wait_time = 0.016  # ~60 FPS update rate
	audio_timer.start()

	audio_started.emit()
	return true

func pause_audio():
	if not is_playing or is_paused:
		return

	audio_player.pause()
	is_paused = true
	pause_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0

	audio_timer.stop()
	audio_paused.emit()

func resume_audio():
	if not is_paused:
		return

	audio_player.play()
	is_paused = false

	# Adjust start_time to account for pause duration
	var pause_duration = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0 - pause_time

	start_time += pause_duration
	audio_timer.start()
	audio_resumed.emit()

func stop_audio():
	if not is_playing:
		return

	audio_player.stop()
	is_playing = false
	is_paused = false
	audio_timer.stop()
	audio_finished.emit()

func get_playback_position() -> float:
	if not is_playing or audio_player.stream == null:
		return 0.0

	if is_paused:
		return pause_time - start_time

	# Use both AudioStreamPlayer position and system time for accuracy
	var stream_position = audio_player.get_playback_position()
	var system_time = Time.get_time_dict_from_system()["hour"] * 3600.0 + \
		Time.get_time_dict_from_system()["minute"] * 60.0 + \
		Time.get_time_dict_from_system()["second"] + \
		Time.get_time_dict_from_system()["millisecond"] / 1000.0
	var calculated_position = system_time - start_time

	# Return the more accurate position (stream position is usually more reliable)
	# But add compensation for any detected drift
	var drift = calculated_position - stream_position
	if abs(drift) > 0.1:  # If drift is more than 100ms, trust system time
		return calculated_position + audio_offset
	else:
		return stream_position + audio_offset

func get_playback_position_ms() -> int:
	return int(get_playback_position() * 1000.0)

func set_volume(volume: float):
	# Volume should be between 0.0 and 1.0
	volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(volume))

func get_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")))

func set_audio_offset(offset_ms: float):
	# Set audio offset in milliseconds (positive = delay audio)
	audio_offset = offset_ms / 1000.0

func get_audio_offset() -> float:
	return audio_offset * 1000.0  # Return in milliseconds

func is_audio_playing() -> bool:
	return is_playing and not is_paused

func get_duration() -> float:
	return total_duration

func get_duration_ms() -> int:
	return int(total_duration * 1000.0)

func _on_audio_finished():
	is_playing = false
	is_paused = false
	audio_timer.stop()
	audio_finished.emit()

func _on_audio_timer_timeout():
	# Timer callback for periodic updates
	# Can be used for UI updates or synchronization checks
	pass

func get_current_time_with_compensation() -> int:
	# Get current playback position with millisecond precision
	# This is useful for precise rhythm game timing
	var position = get_playback_position()
	return int(position * 1000.0)

func preload_audio(file_path: String) -> AudioStreamMP3:
	# Preload audio without setting it as current
	if not FileAccess.file_exists(file_path):
		push_error("Audio file not found: " + file_path)
		return null

	var audio_stream = AudioStreamMP3.new()
	if audio_stream.load_from_file(file_path) != OK:
		push_error("Failed to preload audio file: " + file_path)
		return null

	return audio_stream

func debug_info() -> Dictionary:
	return {
		"current_file": current_audio_file,
		"is_playing": is_playing,
		"is_paused": is_paused,
		"playback_position": get_playback_position(),
		"playback_position_ms": get_playback_position_ms(),
		"volume": get_volume(),
		"audio_offset_ms": get_audio_offset(),
		"total_duration": total_duration
	}