class_name GlobalData
extends Node

# Singleton instance
static var instance: GlobalData

# Game state tracking
@export var captured_demons: Array[DemonData] = []
@export var total_battles_won: int = 0
@export var total_demons_captured: int = 0
@export var current_battle_streak: int = 0
@export var unlocked_demon_types: Array[String] = []
@export var player_level: int = 1
@export var experience_points: int = 0

# Settings and preferences
@export var master_volume: float = 1.0
@export var music_volume: float = 0.8
@export var sfx_volume: float = 0.9
@export var screen_shake_enabled: bool = true
@export var particle_effects_enabled: bool = true

# Current session data
var current_battle_enemy: DemonData = null
var is_in_battle: bool = false
var is_in_capture_mode: bool = false

# Signals
signal demon_captured(demon_data: DemonData)
signal demon_defeated(demon_data: DemonData)
signal battle_won(enemy: DemonData)
signal battle_lost(enemy: DemonData)
signal player_leveled_up(new_level: int)
signal experience_gained(amount: int)
signal battle_streak_updated(streak: int)

func _ready():
	# Set up singleton
	if instance == null:
		instance = self
	else:
		queue_free()
		return

	# Load saved data if available
	load_game_data()

# Add a captured demon to the collection
func add_captured_demon(demon_data: DemonData) -> void:
	if demon_data == null or demon_data.id.is_empty():
		push_error("Invalid demon data provided to add_captured_demon")
		return

	# Check if already captured
	for existing_demon in captured_demons:
		if existing_demon.id == demon_data.id:
			print("Demon ", demon_data.display_name, " already captured")
			return

	# Add to collection
	captured_demons.append(demon_data)
	total_demons_captured += 1

	# Unlock demon type if not already unlocked
	if demon_data.demon_type not in unlocked_demon_types:
		unlocked_demon_types.append(demon_data.demon_type)

	# Grant experience based on demon difficulty
	var exp_gained = int(100 + demon_data.capture_difficulty * 400)
	gain_experience(exp_gained)

	# Emit signals
	demon_captured.emit(demon_data)
	print("Captured demon: ", demon_data.display_name)

	# Save game data
	save_game_data()

# Remove a demon from collection (for debugging/testing)
func remove_captured_demon(demon_id: String) -> bool:
	for i in range(captured_demons.size()):
		if captured_demons[i].id == demon_id:
			var removed_demon = captured_demons[i]
			captured_demons.remove_at(i)
			print("Removed demon: ", removed_demon.display_name)
			save_game_data()
			return true
	return false

# Check if a demon is captured
func is_demon_captured(demon_id: String) -> bool:
	for demon in captured_demons:
		if demon.id == demon_id:
			return true
	return false

# Get captured demon by ID
func get_captured_demon(demon_id: String) -> DemonData:
	for demon in captured_demons:
		if demon.id == demon_id:
			return demon
	return null

# Get total capture count for a specific demon type
func get_capture_count_by_type(demon_type: String) -> int:
	var count = 0
	for demon in captured_demons:
		if demon.demon_type == demon_type:
			count += 1
	return count

# Add experience and handle leveling
func gain_experience(amount: int) -> void:
	experience_points += amount
	experience_gained.emit(amount)

	# Check for level up (simple progression: 1000 XP per level)
	var exp_for_next_level = player_level * 1000
	while experience_points >= exp_for_next_level:
		experience_points -= exp_for_next_level
		player_level += 1
		player_leveled_up.emit(player_level)
		print("Player leveled up to level ", player_level)
		exp_for_next_level = player_level * 1000

# Handle battle won
func on_battle_won(enemy: DemonData) -> void:
	total_battles_won += 1
	current_battle_streak += 1
	battle_won.emit(enemy)
	battle_streak_updated.emit(current_battle_streak)

	# Grant victory experience
	var victory_exp = int(50 + enemy.capture_difficulty * 150)
	gain_experience(victory_exp)

	save_game_data()

# Handle battle lost
func on_battle_lost(enemy: DemonData) -> void:
	current_battle_streak = 0
	battle_lost.emit(enemy)
	battle_streak_updated.emit(current_battle_streak)
	save_game_data()

# Get capture statistics
func get_capture_statistics() -> Dictionary:
	var type_counts = {}
	for demon in captured_demons:
		if demon.demon_type not in type_counts:
			type_counts[demon.demon_type] = 0
		type_counts[demon.demon_type] += 1

	return {
		"total_captured": total_demons_captured,
		"total_battles": total_battles_won,
		"current_streak": current_battle_streak,
		"player_level": player_level,
		"experience": experience_points,
		"unlocked_types": unlocked_demon_types.size(),
		"type_breakdown": type_counts
	}

# Save game data to file
func save_game_data() -> void:
	var save_data = {
		"captured_demons": [],
		"total_battles_won": total_battles_won,
		"total_demons_captured": total_demons_captured,
		"current_battle_streak": current_battle_streak,
		"unlocked_demon_types": unlocked_demon_types,
		"player_level": player_level,
		"experience_points": experience_points,
		"settings": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"screen_shake_enabled": screen_shake_enabled,
			"particle_effects_enabled": particle_effects_enabled
		}
	}

	# Convert demon data to saveable format
	for demon in captured_demons:
		save_data.captured_demons.append({
			"id": demon.id,
			"capture_date": Time.get_datetime_string_from_system()
		})

	# Save to user data directory
	var save_file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if save_file:
		save_file.store_string(JSON.stringify(save_data))
		save_file.close()
		print("Game data saved successfully")
	else:
		push_error("Failed to save game data")

# Load game data from file
func load_game_data() -> void:
	var save_file = FileAccess.open("user://save_data.json", FileAccess.READ)
	if not save_file:
		print("No save data found, starting fresh")
		return

	var json_string = save_file.get_as_text()
	save_file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("Failed to parse save data")
		return

	var save_data = json.data
	if not save_data is Dictionary:
		push_error("Invalid save data format")
		return

	# Load basic stats
	total_battles_won = save_data.get("total_battles_won", 0)
	total_demons_captured = save_data.get("total_demons_captured", 0)
	current_battle_streak = save_data.get("current_battle_streak", 0)
	unlocked_demon_types = save_data.get("unlocked_demon_types", [])
	player_level = save_data.get("player_level", 1)
	experience_points = save_data.get("experience_points", 0)

	# Load settings
	var settings = save_data.get("settings", {})
	master_volume = settings.get("master_volume", 1.0)
	music_volume = settings.get("music_volume", 0.8)
	sfx_volume = settings.get("sfx_volume", 0.9)
	screen_shake_enabled = settings.get("screen_shake_enabled", true)
	particle_effects_enabled = settings.get("particle_effects_enabled", true)

	print("Game data loaded successfully")

# Reset all game data (for new game)
func reset_game_data() -> void:
	captured_demons.clear()
	total_battles_won = 0
	total_demons_captured = 0
	current_battle_streak = 0
	unlocked_demon_types.clear()
	player_level = 1
	experience_points = 0

	# Delete save file
	var save_file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if save_file:
		save_file.close()

	if DirAccess.remove_absolute("user://save_data.json") != OK:
		print("No save file to delete")

	print("Game data reset")