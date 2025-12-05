class_name BeatmapParser
extends RefCounted

# Universal Beatmap Parser
# Parses .osu files, .json Godot format, and IBF files (when converted)
# Extracts timing data for rhythm game gameplay

const LANE_POSITIONS = {
	64: 0,   # Lane 0 (leftmost)
	192: 1,  # Lane 1
	320: 2,  # Lane 2
	448: 3   # Lane 3 (rightmost)
}

const NOTE_TYPES = {
	0: "tap",   # Hit circle
	1: "tap",   # Hit circle
	2: "tap",   # Hit circle
	4: "hold",  # Slider (treated as hold note)
	8: "tap",   # Spinner (treated as tap note)
	12: "hold"  # Spinner + Slider
}

func parse_beatmap(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Failed to open beatmap file: " + file_path)
		return {}

	var content = file.get_as_text()
	file.close()

	# Determine file format based on extension and content
	if file_path.ends_with(".json"):
		return _parse_godot_json(content)
	elif file_path.ends_with(".osu"):
		return _parse_osu_format(content)
	elif file_path.ends_with(".ibf"):
		push_error("IBF files must be converted to JSON first. Use the Python converter.")
		return {}
	else:
		# Try to auto-detect format
		if content.begins_with("{"):
			return _parse_godot_json(content)
		elif content.contains("osu file format"):
			return _parse_osu_format(content)
		else:
			push_error("Unknown beatmap format: " + file_path)
			return {}

func _parse_godot_json(content: String) -> Dictionary:
	var json = JSON.new()
	var parse_result = json.parse(content)

	if parse_result != OK:
		push_error("Failed to parse JSON beatmap")
		return {}

	var beatmap_data = json.data

	# Validate required sections
	if not beatmap_data.has("metadata"):
		beatmap_data["metadata"] = {}
	if not beatmap_data.has("timing_points"):
		beatmap_data["timing_points"] = []
	if not beatmap_data.has("hit_objects"):
		beatmap_data["hit_objects"] = []

	# Add BeatLearning-specific metadata if missing
	if not beatmap_data.metadata.has("generated_by"):
		beatmap_data.metadata["generated_by"] = "Unknown"
	if not beatmap_data.metadata.has("beatlearning_version"):
		beatmap_data.metadata["beatlearning_version"] = "Unknown"

	# Sort hit objects by time
	beatmap_data.hit_objects.sort_custom(func(a, b): return a.time < b.time)

	return beatmap_data

func _parse_osu_format(content: String) -> Dictionary:
	var beatmap_data = {
		"metadata": {},
		"timing_points": [],
		"hit_objects": []
	}

	var lines = content.split("\n")
	var current_section = ""

	for line in lines:
		line = line.strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("//"):
			continue

		# Check for section headers
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2)
			continue

		# Parse based on current section
		match current_section:
			"General":
				_parse_general_line(line, beatmap_data.metadata)
			"Metadata":
				_parse_metadata_line(line, beatmap_data.metadata)
			"Difficulty":
				_parse_difficulty_line(line, beatmap_data.metadata)
			"TimingPoints":
				_parse_timing_point_line(line, beatmap_data.timing_points)
			"HitObjects":
				_parse_hit_object_line(line, beatmap_data.hit_objects)

	# Add OSU format metadata
	beatmap_data.metadata["format"] = "osu"
	beatmap_data.metadata["generated_by"] = "OSU Editor"

	# Sort hit objects by time
	beatmap_data.hit_objects.sort_custom(func(a, b): return a.time < b.time)

	return beatmap_data

func _parse_general_line(line: String, metadata: Dictionary):
	var parts = line.split(":")
	if parts.size() >= 2:
		var key = parts[0].strip_edges()
		var value = parts[1].strip_edges()

		match key:
			"AudioFilename":
				metadata["audio_filename"] = value
			"AudioLeadIn":
				metadata["audio_lead_in"] = value.to_int()

func _parse_metadata_line(line: String, metadata: Dictionary):
	var parts = line.split(":")
	if parts.size() >= 2:
		var key = parts[0].strip_edges()
		var value = parts[1].strip_edges()

		match key:
			"Title":
				metadata["title"] = value
			"Artist":
				metadata["artist"] = value
			"Creator":
				metadata["creator"] = value
			"Version":
				metadata["difficulty"] = value

func _parse_difficulty_line(line: String, metadata: Dictionary):
	var parts = line.split(":")
	if parts.size() >= 2:
		var key = parts[0].strip_edges()
		var value = parts[1].strip_edges()

		match key:
			"CircleSize":
				metadata["circle_size"] = value.to_int()
			"OverallDifficulty":
				metadata["overall_difficulty"] = value.to_float()
			"HPDrainRate":
				metadata["hp_drain_rate"] = value.to_float()

func _parse_timing_point_line(line: String, timing_points: Array):
	var parts = line.split(",")
	if parts.size() >= 2:
		var timing_point = {
			"time": parts[0].to_int(),
			"beat_length": parts[1].to_float()
		}

		if parts.size() >= 3:
			timing_point["meter"] = parts[2].to_int()
		if parts.size() >= 7:
			timing_point["uninherited"] = parts[6].to_int() == 1

		timing_points.append(timing_point)

func _parse_hit_object_line(line: String, hit_objects: Array):
	var parts = line.split(",")
	if parts.size() >= 4:
		var x = parts[0].to_int()
		var y = parts[1].to_int()
		var time = parts[2].to_int()
		var type_value = parts[3].to_int()

		# Convert x position to lane (0-3)
		var lane = _x_to_lane(x)

		# Determine note type from OSU type flags
		var note_type = "tap"
		if type_value & 4:  # Slider flag
			note_type = "hold"

		var hit_object = {
			"time": time,
			"lane": lane,
			"type": note_type,
			"x": x,
			"y": y
		}

		# Parse additional parameters for hold notes
		if note_type == "hold" and parts.size() >= 8:
			var object_params = parts[5].split("|")
			if object_params.size() >= 2:
				hit_object["duration"] = object_params[0].to_int()
			else:
				# Fallback duration for sliders
				hit_object["duration"] = 1000  # 1 second default

		hit_objects.append(hit_object)

func _x_to_lane(x: int) -> int:
	# Convert OSU x coordinate to lane (0-3)
	# Find closest lane position
	var closest_lane = 0
	var closest_distance = abs(x - 64)

	var positions = [64, 192, 320, 448]
	for i in range(1, positions.size()):
		var distance = abs(x - positions[i])
		if distance < closest_distance:
			closest_distance = distance
			closest_lane = i

	return closest_lane

func get_available_beatmaps(beatmap_dir: String) -> Array:
	var beatmaps = []
	var dir = DirAccess.open(beatmap_dir)

	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "":
			# Support both .osu and .json beatmaps
			if file_name.ends_with(".osu") or file_name.ends_with(".json"):
				var file_path = beatmap_dir.path_join(file_name)
				var beatmap_data = parse_beatmap(file_path)

				if beatmap_data.has("metadata") and beatmap_data.metadata.has("title"):
					var format = "OSU"
					if file_name.ends_with(".json"):
						format = "Godot JSON"
						if beatmap_data.metadata.get("generated_by") == "BeatLearning AI":
							format = "BeatLearning"

					beatmaps.append({
						"file_path": file_path,
						"file_name": file_name,
						"title": beatmap_data.metadata.get("title", "Unknown"),
						"artist": beatmap_data.metadata.get("artist", "Unknown"),
						"difficulty": beatmap_data.metadata.get("difficulty", "Normal"),
						"format": format,
						"generated_by": beatmap_data.metadata.get("generated_by", "Unknown"),
						"bpm": beatmap_data.metadata.get("bpm", 0),
						"lanes": beatmap_data.metadata.get("lanes", 4)
					})

			file_name = dir.get_next()

	return beatmaps

func validate_beatmap(beatmap_data: Dictionary) -> bool:
	if not beatmap_data.has("metadata"):
		push_error("Beatmap missing metadata section")
		return false

	if not beatmap_data.has("hit_objects") or beatmap_data.hit_objects.is_empty():
		push_error("Beatmap has no hit objects")
		return false

	if not beatmap_data.metadata.has("audio_filename"):
		push_error("Beatmap missing audio filename")
		return false

	return true

# BeatLearning integration methods
func is_beatlearning_generated(beatmap_data: Dictionary) -> bool:
	return beatmap_data.metadata.get("generated_by", "").contains("BeatLearning")

func get_beatlearning_info(beatmap_data: Dictionary) -> Dictionary:
	return {
		"version": beatmap_data.metadata.get("beatlearning_version", "Unknown"),
		"lanes": beatmap_data.metadata.get("lanes", 4),
		"style": beatmap_data.metadata.get("style", "guitar-hero"),
		"difficulty": beatmap_data.metadata.get("difficulty", "Normal")
	}

func convert_beatmap_to_godot_format(beatmap_data: Dictionary, output_path: String) -> bool:
	# Convert any format to Godot JSON format
	var godot_format = {
		"metadata": {},
		"timing_points": [],
		"hit_objects": []
	}

	# Copy metadata
	godot_format.metadata = beatmap_data.metadata.duplicate()

	# Ensure required metadata fields
	if not godot_format.metadata.has("generated_by"):
		godot_format.metadata["generated_by"] = "Converted"

	# Copy timing points
	godot_format.timing_points = beatmap_data.get("timing_points", [])

	# Normalize hit objects
	godot_format.hit_objects = _normalize_hit_objects(beatmap_data.get("hit_objects", []))

	# Write to file
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write Godot format beatmap: " + output_path)
		return false

	var json_string = JSON.stringify(godot_format, "\t")
	file.store_string(json_string)
	file.close()

	return true

func _normalize_hit_objects(hit_objects: Array) -> Array:
	var normalized = []

	for hit_object in hit_objects:
		var normalized_object = {
			"time": 0,
			"lane": 0,
			"type": "tap",
			"duration": 0
		}

		# Copy time
		if hit_object.has("time"):
			normalized_object.time = hit_object.time
		elif hit_object.has("timestamp"):
			normalized_object.time = hit_object.timestamp

		# Copy lane
		if hit_object.has("lane"):
			normalized_object.lane = hit_object.lane
		elif hit_object.has("x"):
			normalized_object.lane = _x_to_lane(hit_object.x)

		# Copy type
		if hit_object.has("type"):
			normalized_object.type = hit_object.type
		else:
			# Default to tap note
			normalized_object.type = "tap"

		# Copy duration
		if hit_object.has("duration"):
			normalized_object.duration = hit_object.duration

		normalized.append(normalized_object)

	return normalized

func generate_beatmap_statistics(beatmap_data: Dictionary) -> Dictionary:
	var stats = {
		"total_notes": 0,
		"tap_notes": 0,
		"hold_notes": 0,
		"special_notes": 0,
		"lanes_used": [],
		"difficulty_estimate": "Normal",
		"duration": 0
	}

	var hit_objects = beatmap_data.get("hit_objects", [])
	stats.total_notes = hit_objects.size()

	# Count note types and lane usage
	for hit_object in hit_objects:
		match hit_object.get("type", "tap"):
			"tap":
				stats.tap_notes += 1
			"hold":
				stats.hold_notes += 1
			"special":
				stats.special_notes += 1
			_:
				stats.tap_notes += 1

		var lane = hit_object.get("lane", 0)
		if not lane in stats.lanes_used:
			stats.lanes_used.append(lane)

	# Estimate difficulty based on note density
	var duration = beatmap_data.metadata.get("duration", 0)
	if duration > 0:
		var notes_per_minute = (stats.total_notes * 60000.0) / duration
		if notes_per_minute > 300:
			stats.difficulty_estimate = "Expert"
		elif notes_per_minute > 200:
			stats.difficulty_estimate = "Hard"
		elif notes_per_minute > 120:
			stats.difficulty_estimate = "Normal"
		else:
			stats.difficulty_estimate = "Easy"

	stats.duration = duration

	return stats