#!/usr/bin/env godot
# Test script for OSU parser functionality

extends SceneTree

func _init():
	print("Testing OSU Beatmap Parser...")

	# Test OSU parser
	var parser = OSUParser.new()
	var beatmap_data = parser.parse_beatmap("res://src/assets/beatmaps/test_song.osu")

	if beatmap_data.is_empty():
		print("❌ Failed to parse beatmap")
	else:
		print("✅ Successfully parsed beatmap")

		# Print metadata
		if beatmap_data.has("metadata"):
			var metadata = beatmap_data.metadata
			print("📋 Metadata:")
			print("   Title: ", metadata.get("title", "Unknown"))
			print("   Artist: ", metadata.get("artist", "Unknown"))
			print("   Difficulty: ", metadata.get("difficulty", "Unknown"))
			print("   Audio: ", metadata.get("audio_filename", "Unknown"))

		# Print hit objects summary
		if beatmap_data.has("hit_objects"):
			var hit_objects = beatmap_data.hit_objects
			print("🎵 Hit Objects: ", hit_objects.size(), " notes")

			# Print first few notes
			print("📝 First 5 notes:")
			for i in range(min(5, hit_objects.size())):
				var note = hit_objects[i]
				print("   Note ", i + 1, ": Lane ", note.lane, " at ", note.time, "ms (", note.type, ")")

		# Validate beatmap
		if parser.validate_beatmap(beatmap_data):
			print("✅ Beatmap validation passed")
		else:
			print("❌ Beatmap validation failed")

	print("🎮 Parser test complete")
	quit()