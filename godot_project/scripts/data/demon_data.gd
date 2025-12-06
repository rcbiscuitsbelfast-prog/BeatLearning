class_name DemonData extends Resource
extends Resource

@export var id: String                              # Unique identifier
@export var display_name: String                    # Display name
@export var demon_type: String                      # fire, ice, shadow, electric, etc
@export var base_hp: float                          # Starting HP in battles
@export var attack_power: float                     # Base attack damage
@export var defense: float                          # Damage reduction
@export var speed: float                            # Movement speed multiplier
@export var capture_difficulty: float              # 0.0-1.0, affects beatmap density
@export var capture_theme_song: String             # Path to MP3 file
@export var capture_beatmap: String                # Path to JSON beatmap
@export var theme_color: Color                      # Primary color for UI/effects
@export var secondary_color: Color                  # Accent color
@export var description: String                    # Flavor text
@export var capture_quote: String                  # Quote when captured
@export var defeat_quote: String                   # Quote when defeated

# Battle-specific properties
@export var attack_patterns: Array[String]          # AI attack patterns
@export var special_abilities: Array[String]        # Special moves
@export var weakness_type: String                   # Elemental weakness
@export var resistance_type: String                 # Elemental resistance

# Beatmap generation settings
@export var desired_bpm: float                      # Target BPM for beatmap generation
@export var note_density: String                    # low, medium, high, very_high
@export var special_note_frequency: float           # 0.0-1.0, chance of special notes

func _init(p_id: String = "", p_display_name: String = "", p_demon_type: String = ""):
	id = p_id
	display_name = p_display_name
	demon_type = p_demon_type
	base_hp = 100.0
	attack_power = 20.0
	defense = 10.0
	speed = 1.0
	capture_difficulty = 0.5
	theme_color = Color.WHITE
	secondary_color = Color.GRAY
	description = "A mysterious demon with unknown powers."
	capture_quote = "I will serve you, master."
	defeat_quote = "This cannot be..."
	attack_patterns = ["basic_attack"]
	special_abilities = []
	weakness_type = ""
	resistance_type = ""
	desired_bpm = 120.0
	note_density = "medium"
	special_note_frequency = 0.1

# Calculate HP restoration percentage based on capture performance
func calculate_hp_restoration(performance_score: float) -> float:
	"""
	performance_score: 0.0 (terrible) to 1.0 (perfect)
	Returns: 0.3 (30%) to 0.7 (70%) HP restoration
	"""
	return 0.3 + (1.0 - performance_score) * 0.4

# Get difficulty multiplier for beatmap generation
func get_difficulty_multiplier() -> float:
	"""
	Returns difficulty multiplier based on capture_difficulty
	0.0 (easy) -> 0.5x density
	1.0 (hard) -> 2.0x density
	"""
	return 0.5 + capture_difficulty * 1.5

# Validate demon data integrity
func validate() -> bool:
	if id.is_empty() or display_name.is_empty() or demon_type.is_empty():
		return false
	if base_hp <= 0 or attack_power < 0 or defense < 0 or speed <= 0:
		return false
	if capture_difficulty < 0.0 or capture_difficulty > 1.0:
		return false
	if capture_theme_song.is_empty() or capture_beatmap.is_empty():
		return false
	if desired_bpm <= 0 or special_note_frequency < 0.0 or special_note_frequency > 1.0:
		return false
	return true

# Get a readable difficulty description
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