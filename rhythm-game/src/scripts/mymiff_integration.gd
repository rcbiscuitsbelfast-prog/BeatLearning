# Mymiff AARPG Integration Guide and Example Code
# This file shows how to integrate BeatLearning rhythm capture into Mymiff AARPG

# ============================================================================
# MODIFIED ENEMY.GD - Add capture functionality to existing enemy script
# ============================================================================

# Add these signals and properties to existing Enemy class:

# Add to existing signals:
signal capture_available( enemy : Enemy )  # NEW: Capture available signal

# Add these new properties:
@export var demon_data: DemonData = null    # NEW: Demon data for capture system
var capture_available: bool = false         # NEW: Track capture availability
var capture_threshold: float = 0.25         # NEW: HP percentage for capture

# MODIFIED _take_damage function - Add capture check:
func _take_damage( hurt_box : HurtBox ) -> void:
	if invulnerable == true:
		return

	var old_hp = hp
	hp -= hurt_box.damage
	PlayerManager.shake_camera()
	EffectManager.damage_text( hurt_box.damage, global_position + Vector2(0,-36) )

	if hp > 0:
		enemy_damaged.emit( hurt_box )

		# NEW: Check for capture availability
		_check_capture_availability()
	else:
		enemy_destroyed.emit( hurt_box )

# NEW: Add capture availability checking function:
func _check_capture_availability() -> void:
	if demon_data == null or not demon_data.can_be_captured:
		return

	var max_hp = demon_data.base_hp
	var hp_percentage = float(hp) / float(max_hp)

	if hp_percentage <= demon_data.capture_threshold and not capture_available:
		capture_available = true
		capture_available.emit(self)
		print("CAPTURE AVAILABLE for: ", demon_data.display_name)

# NEW: Add capture attempt function:
func attempt_capture() -> bool:
	if not capture_available or demon_data == null:
		return false

	return true

# NEW: Add HP restoration function:
func restore_health(percentage: float) -> void:
	var max_hp = demon_data.base_hp if demon_data else hp
	var restore_amount = int(max_hp * percentage)
	hp = min(hp + restore_amount, max_hp)
	print("Enemy HP restored by: ", percentage * 100, "% (", restore_amount, " HP)")

# ============================================================================
# CAPTURE MODE SCENE - New scene for rhythm-based capture
# ============================================================================

class_name CaptureMode extends Control
extends Control

signal capture_successful(demon_data: DemonData)
signal capture_failed(demon_data: DemonData, performance_score: float)

var demon_data: DemonData
var gameplay_manager: CaptureGameplayManager

# UI References
@onready var capture_meter: ProgressBar = $UI/CaptureMeter
@onready var timer_label: Label = $UI/TimerLabel
@onready var demon_sprite: AnimatedSprite2D = $DemonDisplay
@onready var background: ColorRect = $Background
@onready var instructions: Label = $UI/Instructions

func initialize(demon: DemonData) -> void:
	demon_data = demon

	# Setup visuals
	background.modulate = demon.theme_color
	capture_meter.max_value = 100.0
	capture_meter.value = 0.0

	# Setup demon display
	demon_sprite.sprite_frames = demon.sprite_frames
	demon_sprite.play("idle")  # Or "struggle" animation

	# Setup instructions
	instructions.text = "Press D, F, J, K keys to capture " + demon.display_name + "!"

	# Setup gameplay manager
	gameplay_manager = $CaptureGameplayManager
	gameplay_manager.capture_progress_updated.connect(_on_capture_progress)
	gameplay_manager.capture_successful.connect(_on_capture_success)
	gameplay_manager.capture_failed.connect(_on_capture_failure)

	# Start capture sequence
	_start_capture_sequence()

func _start_capture_sequence() -> void:
	if not demon_data.beatmap_path.is_empty() and not demon_data.theme_song_path.is_empty():
		gameplay_manager.start_capture_mode(
			demon_data.beatmap_path,
			demon_data.theme_song_path,
			demon_data.capture_duration
		)
	else:
		push_error("Missing beatmap or theme song for demon: " + demon_data.id)

func _process(delta):
	if gameplay_manager and gameplay_manager.is_playing:
		var status = gameplay_manager.get_capture_status()
		timer_label.text = "Time: %.1f" % status.time_remaining

func _on_capture_progress(progress: float) -> void:
	capture_meter.value = progress * 100.0

	# Update demon animation based on progress
	if progress >= 0.8:
		demon_sprite.play("weak")
	elif progress >= 0.5:
		demon_sprite.play("hurt")
	else:
		demon_sprite.play("struggle")

func _on_capture_success(accuracy: float) -> void:
	print("CAPTURE SUCCESS! Accuracy: ", accuracy * 100, "%")

	# Play success animation
	demon_sprite.play(demon_data.capture_animation)

	# Wait for animation then emit success
	await get_tree().create_timer(2.0).timeout
	capture_successful.emit(demon_data)

func _on_capture_failure(accuracy: float) -> void:
	print("CAPTURE FAILED! Accuracy: ", accuracy * 100, "%")

	# Play failure animation
	demon_sprite.play(demon_data.defeat_animation)

	# Wait for animation then emit failure
	await get_tree().create_timer(2.0).timeout
	capture_failed.emit(demon_data, accuracy)

# ============================================================================
# BATTLE UI MODIFICATION - Add capture button to existing battle UI
# ============================================================================

# Add to existing battle UI script:

# Add UI reference:
@onready var capture_button: Button = $CaptureButton

# Add to _ready() function:
func _ready():
	# Existing setup code...

	# NEW: Setup capture button
	capture_button.visible = false
	capture_button.pressed.connect(_on_capture_pressed)

	# Connect to enemy capture signal
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_signal("capture_available"):
			enemy.capture_available.connect(_on_capture_available)

# NEW: Add capture button handlers:
func _on_capture_available(enemy: Enemy) -> void:
	capture_button.visible = true
	capture_button.text = "CAPTURE " + enemy.demon_data.display_name.to_upper()

	# Add pulsing animation
	var tween = create_tween().set_loops()
	tween.tween_property(capture_button, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(capture_button, "scale", Vector2(1.0, 1.0), 0.5)

func _on_capture_pressed() -> void:
	# Find the enemy with capture available
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target_enemy: Enemy = null

	for enemy in enemies:
		if enemy.capture_available:
			target_enemy = enemy
			break

	if target_enemy == null:
		return

	# Start capture mode
	_start_capture_mode(target_enemy)

func _start_capture_mode(enemy: Enemy) -> void:
	# Pause the game
	get_tree().paused = true

	# Hide battle UI
	visible = false

	# Load and start capture mode
	var capture_scene = preload("res://Capture/Scenes/capture_mode.tscn")
	var capture_mode = capture_scene.instantiate()

	# Setup capture mode
	capture_mode.initialize(enemy.demon_data)
	capture_mode.capture_successful.connect(_on_capture_successful)
	capture_mode.capture_failed.connect(_on_capture_failed)

	# Add to scene tree
	get_tree().root.add_child(capture_mode)

func _on_capture_successful(demon: DemonData) -> void:
	print("Demon captured: ", demon.display_name)

	# Add to player's collection (you'll need to implement this)
	GlobalData.add_captured_demon(demon)

	# Grant XP reward
	PlayerManager.reward_xp(demon.xp_reward)

	# End battle
	_end_battle_victory()

func _on_capture_failed(demon: DemonData, performance: float) -> void:
	print("Capture failed, restoring enemy HP")

	# Find the enemy and restore HP
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.demon_data.id == demon.id:
			var restore_percentage = demon.calculate_hp_restoration(performance)
			enemy.restore_health(restore_percentage)
			enemy.capture_available = false
			break

	# Resume battle
	_resume_battle()

func _resume_battle() -> void:
	# Unpause game
	get_tree().paused = false

	# Show battle UI again
	visible = true

	# Hide capture button
	capture_button.visible = false

# ============================================================================
# SAVE MANAGER MODIFICATION - Add demon collection tracking
# ============================================================================

# Add to existing SaveManager current_save dictionary:
var current_save : Dictionary = {
	# ... existing data ...
	captured_demons = [],  # NEW: Track captured demons
	total_demons_captured = 0,  # NEW: Total capture count
	demon_collection_unlocked = false  # NEW: Collection feature unlock
}

# Add these new functions to SaveManager:
func add_captured_demon(demon_data: DemonData) -> void:
	var demon_info = {
		"id": demon_data.id,
		"display_name": demon_data.display_name,
		"capture_date": Time.get_datetime_string_from_system(),
		"capture_difficulty": demon_data.capture_difficulty
	}

	current_save.captured_demons.append(demon_info)
	current_save.total_demons_captured += 1

	# Unlock collection feature if not already unlocked
	if not current_save.demon_collection_unlocked:
		current_save.demon_collection_unlocked = true

	save_game()

func is_demon_captured(demon_id: String) -> bool:
	for demon_info in current_save.captured_demons:
		if demon_info.id == demon_id:
			return true
	return false

func get_captured_demons() -> Array:
	return current_save.captured_demons

func get_capture_statistics() -> Dictionary:
	return {
		"total_captured": current_save.total_demons_captured,
		"collection_unlocked": current_save.demon_collection_unlocked,
		"unique_demons": current_save.captured_demons.size()
	}