class_name DemonData extends Resource
extends Resource

# Demon data resource that integrates with Mymiff AARPG enemy system
# Links enemy stats with capture rhythm game parameters

@export var id: String                              # Unique identifier
@export var display_name: String                    # Display name for UI
@export var demon_type: String                      # fire, ice, shadow, electric, etc

# Mymiff AARPG enemy integration
@export var base_hp: float                          # Starting HP in battles
@export var attack_damage: float                    # Damage dealt to player
@export var defense: float                          # Damage reduction
@export var level: int                              # Enemy level
@export var xp_reward: int                          # XP given to player

# Capture system parameters
@export var capture_difficulty: float              # 0.0-1.0, affects beatmap density
@export var capture_threshold: float               # HP percentage when capture becomes available (0.25 = 25%)
@export var capture_duration: float               # Capture sequence duration in seconds
@export var can_be_captured: bool                  # Whether this demon can be captured

# BeatLearning integration
@export var theme_song_path: String                # Path to MP3 file
@export var beatmap_path: String                   # Path to JSON beatmap
@export var desired_bpm: float                     # Target BPM for beatmap generation
@export var note_density: String                   # low, medium, high, very_high
@export var special_note_frequency: float          # 0.0-1.0, chance of special notes

# Visual and audio
@export var theme_color: Color                      # Primary color for UI/effects
@export var secondary_color: Color                  # Accent color
@export var capture_animation: String              # Animation name when captured
@export var defeat_animation: String               # Animation name when defeated

# Gameplay and lore
@export_multiline var description: String          # Flavor text
@export_multiline var capture_quote: String        # Quote when captured
@export_multiline var defeat_quote: String         # Quote when defeated
@export var abilities: Array[String]               # Special abilities list
@export var drop_items: Array[String]              # Items that can be dropped

# Mymiff AARPG compatibility
@export var enemy_scene_path: String               # Path to enemy scene file
@export var sprite_frames: SpriteFrames            # Enemy sprite frames

func _init(p_id: String = "", p_display_name: String = "", p_demon_type: String = ""):
	id = p_id
	display_name = p_display_name
	demon_type = p_demon_type

	# Set defaults for Mymiff AARPG integration
	base_hp = 80.0
	attack_damage = 15.0
	defense = 5.0
	level = 5
	xp_reward = 50

	# Capture defaults
	capture_difficulty = 0.5
	capture_threshold = 0.25
	capture_duration = 30.0
	can_be_captured = true

	# BeatLearning defaults
	theme_song_path = ""
	beatmap_path = ""
	desired_bpm = 120.0
	note_density = "medium"
	special_note_frequency = 0.1

	# Visual defaults
	theme_color = Color.PURPLE
	secondary_color = Color.GRAY
	capture_animation = "capture"
	defeat_animation = "defeat"

	# Gameplay defaults
	description = "A mysterious demon with unknown powers."
	capture_quote = "I will serve you, master."
	defeat_quote = "This cannot be..."
	abilities = []
	drop_items = []

# Calculate HP restoration percentage based on capture performance
func calculate_hp_restoration(performance_score: float) -> float:
	"""
	performance_score: 0.0 (terrible) to 1.0 (perfect)
	Returns: 0.3 (30%) to 0.7 (70%) HP restoration
	"""
	return 0.3 + (1.0 - performance_score) * 0.4

# Get difficulty multiplier for BeatLearning beatmap generation
func get_beatlearning_difficulty_multiplier() -> float:
	"""
	Returns difficulty multiplier based on capture_difficulty
	0.0 (easy) -> 0.5x density
	1.0 (hard) -> 2.0x density
	"""
	return 0.5 + capture_difficulty * 1.5

# Get BeatLearning note density setting
func get_beatlearning_note_density() -> String:
	match note_density:
		"low":
			return "low"
		"medium":
			return "medium"
		"high":
			return "high"
		"very_high":
			return "very_high"
		_:
			return "medium"

# Get difficulty description for UI
func get_difficulty_description() -> String:
	if capture_difficulty <= 0.25:
		return "Very Easy"
	elif capture_difficulty <= 0.4:
		return "Easy"
	elif capture_difficulty <= 0.6:
		return "Medium"
	elif capture_difficulty <= 0.8:
		return "Hard"
	else:
		return "Very Hard"

# Get capture availability threshold in HP
func get_capture_hp_threshold(enemy_max_hp: float) -> float:
	return enemy_max_hp * capture_threshold

# Validate demon data integrity
func validate() -> bool:
	if id.is_empty() or display_name.is_empty() or demon_type.is_empty():
		push_error("Demon missing required identifier fields")
		return false

	if base_hp <= 0 or attack_damage < 0 or defense < 0 or level <= 0:
		push_error("Demon has invalid combat stats")
		return false

	if capture_difficulty < 0.0 or capture_difficulty > 1.0:
		push_error("Demon has invalid capture difficulty")
		return false

	if capture_threshold <= 0.0 or capture_threshold > 1.0:
		push_error("Demon has invalid capture threshold")
		return false

	if capture_duration <= 0.0:
		push_error("Demon has invalid capture duration")
		return false

	if theme_song_path.is_empty() or beatmap_path.is_empty():
		push_error("Demon missing beatmap or theme song")
		return false

	if desired_bpm <= 0:
		push_error("Demon has invalid BPM setting")
		return false

	if special_note_frequency < 0.0 or special_note_frequency > 1.0:
		push_error("Demon has invalid special note frequency")
		return false

	return true

# Generate BeatLearning-compatible configuration
func generate_beatlearning_config() -> Dictionary:
	return {
		"id": id,
		"difficulty": capture_difficulty,
		"bpm": desired_bpm,
		"note_density": get_beatlearning_note_density(),
		"special_note_frequency": special_note_frequency,
		"duration_seconds": int(capture_duration),
		"lanes": 4,
		"style": "guitar_hero"
	}

# Create a DemonData instance from Mymiff Enemy node
func static func from_enemy_node(enemy: Enemy, demon_id: String = "") -> DemonData:
	var demon_data = DemonData.new()

	demon_data.id = demon_id if not demon_id.is_empty() else "enemy_" + str(enemy.get_instance_id())
	demon_data.display_name = enemy.name if enemy.name else "Unknown Demon"
	demon_data.demon_type = "unknown"
	demon_data.base_hp = enemy.hp
	demon_data.xp_reward = enemy.xp_reward

	# Extract additional data from enemy if available
	if enemy.has_method("get_attack_power"):
		demon_data.attack_damage = enemy.get_attack_power()

	if enemy.has_method("get_defense"):
		demon_data.defense = enemy.get_defense()

	return demon_data