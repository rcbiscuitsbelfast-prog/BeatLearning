class_name VisualEffectsManager
extends Node2D

# Visual Effects Manager for Rhythm Game
# Handles particle effects, screen shake, lane glow, and combo visual feedback

signal effect_completed(effect_name: String)

# Particle scene templates
var particle_scenes: Dictionary = {}
var active_effects: Array[Node] = []
var screen_shake_active: bool = false
var shake_intensity: float = 0.0
var shake_duration: float = 0.0

# Lane glow system
var lane_glows: Dictionary = {}
var original_lane_colors: Dictionary = {}

@export var particle_container: Node2D
@export var camera: Camera2D

# Effect configurations
const PARTICLE_COUNTS = {
	"perfect": 30,
	"great": 20,
	"good": 15,
	"miss": 5
}

const SCREEN_SHAKE_CONFIGS = {
	"perfect": {"intensity": 15.0, "duration": 0.15},
	"great": {"intensity": 10.0, "duration": 0.1},
	"good": {"intensity": 5.0, "duration": 0.05},
	"combo_milestone": {"intensity": 20.0, "duration": 0.3}
}

func _ready():
	setup_particle_templates()
	setup_particle_container()
	setup_camera_reference()

func setup_particle_templates():
	# Create basic particle templates since we can't load actual textures
	create_basic_particle_templates()

func create_basic_particle_templates():
	# Perfect hit effect - golden stars
	particle_scenes["perfect"] = create_particle_template(Color.GOLD, 2.0)

	# Great hit effect - green sparkles
	particle_scenes["great"] = create_particle_template(Color.GREEN, 1.5)

	# Good hit effect - blue sparkles
	particle_scenes["good"] = create_particle_template(Color.CYAN, 1.0)

	# Miss effect - red X marks
	particle_scenes["miss"] = create_particle_template(Color.RED, 0.8)

	# Combo milestone effect - rainbow burst
	particle_scenes["combo_milestone"] = create_particle_template(Color.WHITE, 3.0)

func create_particle_template(color: Color, scale: float) -> GPUParticles2D:
	var particles = GPUParticles2D.new()

	# Configure particle system
	particles.emitting = false
	particles.amount = PARTICLE_COUNTS["perfect"]  # Will be overridden per effect
	particles.lifetime = 0.8
	particles.one_shot = true
	particles.explosiveness = 1.0

	# Configure texture (using a simple circle)
	var texture = ImageTexture.new()
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color.WHITE)
	texture.set_image(image)
	particles.texture = texture

	# Configure color
	particles.color = color
	particles.modulate = color

	# Configure process material
	var process_material = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0, -1, 0)  # Upward
	process_material.spread = 45.0
	process_material.initial_velocity_min = 50.0
	process_material.initial_velocity_max = 150.0
	process_material.angular_velocity_min = -90.0
	process_material.angular_velocity_max = 90.0
	process_material.scale_min = Vector3(scale * 0.1, scale * 0.1, 1.0)
	process_material.scale_max = Vector3(scale, scale, 1.0)
	process_material.color = color

	particles.process_material = process_material

	return particles

func setup_particle_container():
	if particle_container == null:
		particle_container = Node2D.new()
		particle_container.name = "ParticleContainer"
		add_child(particle_container)

func setup_camera_reference():
	if camera == null:
		# Try to find camera in scene tree
		camera = get_viewport().get_camera_2d()

func create_hit_effect(position: Vector2, accuracy: String, lane: int = -1):
	# Create hit effect at specified position
	var particles = get_particle_template(accuracy)
	if particles == null:
		return

	var instance = particles.duplicate()
	instance.position = position

	# Adjust particle count based on accuracy
	var count = PARTICLE_COUNTS.get(accuracy, 10)
	instance.amount = count

	# Set specific colors for lanes
	if lane >= 0 and lane <= 3:
		var lane_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
		instance.color = lane_colors[lane]
		instance.modulate = lane_colors[lane].lightened(0.3)

	particle_container.add_child(instance)
	instance.emitting = true

	# Auto-remove after particles finish
	await get_tree().create_timer(instance.lifetime).timeout
	instance.queue_free()

	# Add screen shake for good hits
	if SCREEN_SHAKE_CONFIGS.has(accuracy):
		apply_screen_shake(
			SCREEN_SHAKE_CONFIGS[accuracy].intensity,
			SCREEN_SHAKE_CONFIGS[accuracy].duration
		)

func get_particle_template(effect_name: String) -> GPUParticles2D:
	return particle_scenes.get(effect_name)

func apply_screen_shake(intensity: float, duration: float):
	if camera == null:
		return

	screen_shake_active = true
	shake_intensity = intensity
	shake_duration = duration

	# Store original offset if not already stored
	if not camera.has_meta("original_offset"):
		camera.set_meta("original_offset", camera.offset)

func _process(delta):
	# Handle screen shake
	if screen_shake_active:
		shake_duration -= delta

		if shake_duration <= 0:
			screen_shake_active = false
			# Reset camera offset
			if camera and camera.has_meta("original_offset"):
				camera.offset = camera.get_meta("original_offset")
		else:
			# Apply random offset
			var random_offset = Vector2(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity)
			)

			if camera and camera.has_meta("original_offset"):
				var original_offset = camera.get_meta("original_offset")
				camera.offset = original_offset + random_offset

func create_lane_glow_effect(lane_index: int, intensity: float = 1.0):
	# Create glowing effect for a lane
	if not lane_glows.has(lane_index):
		setup_lane_glow(lane_index)

	var glow = lane_glows[lane_index]
	if glow == null:
		return

	# Animate the glow
	var tween = create_tween()
	tween.set_parallel(true)

	# Brighten the glow
	tween.tween_property(glow, "modulate:a", intensity, 0.1)

	# Scale effect
	tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.1)

	# Fade out
	tween.tween_property(glow, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2)

func setup_lane_glow(lane_index: int):
	# Create lane glow visual if it doesn't exist
	if lane_glows.has(lane_index):
		return

	# Create glow sprite (simplified - would be a proper glow texture in real implementation)
	var glow = Sprite2D.new()
	glow.name = "LaneGlow_" + str(lane_index)
	glow.scale = Vector2(2.0, 1.0)
	glow.z_index = -1  # Behind notes but above background
	glow.modulate.a = 0.0  # Initially invisible

	# Set color based on lane
	var lane_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
	glow.modulate = lane_colors[lane_index].lightened(0.5)

	# Create a simple glow texture
	var texture = ImageTexture.new()
	var image = Image.create(64, 256, false, Image.FORMAT_RGBA8)
	image.fill(lane_colors[lane_index].lightened(0.8))
	texture.set_image(image)
	glow.texture = texture

	particle_container.add_child(glow)
	lane_glows[lane_index] = glow

func create_combo_milestone_effect(combo_count: int, position: Vector2):
	# Special effect for combo milestones (every 10, 25, 50, 100)
	var effect_type = "combo_milestone"
	var particles = get_particle_template(effect_type)

	if particles == null:
		return

	var instance = particles.duplicate()
	instance.position = position

	# Rainbow effect for combo milestones
	var rainbow_colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.BLUE, Color.PURPLE]
	instance.color = rainbow_colors[combo_count % rainbow_colors.size()]

	# More particles for higher combos
	instance.amount = min(50, 20 + combo_count / 5)

	particle_container.add_child(instance)
	instance.emitting = true

	# Stronger screen shake for combo milestones
	apply_screen_shake(25.0, 0.4)

	# Create floating text showing combo
	create_floating_text(str(combo_count) + " COMBO!", position, Color.GOLD)

	await get_tree().create_timer(instance.lifetime).timeout
	instance.queue_free()

func create_floating_text(text: String, position: Vector2, color: Color = Color.WHITE):
	# Create floating damage/popup text effect
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.modulate = color
	label.position = position
	label.z_index = 100  # On top of everything

	# Add shadow for better visibility
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)

	particle_container.add_child(label)

	# Animate floating up and fading
	var tween = create_tween()
	tween.set_parallel(true)

	# Float upward
	tween.tween_property(label, "position:y", position.y - 100, 1.5)

	# Scale up then down
	tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3).set_delay(0.2)

	# Fade out
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.5)

	# Remove after animation
	await get_tree().create_timer(1.5).timeout
	label.queue_free()

func create_miss_feedback(position: Vector2, lane: int = -1):
	# Create visual feedback for missed notes
	var particles = get_particle_template("miss")
	if particles == null:
		return

	var instance = particles.duplicate()
	instance.position = position
	particle_container.add_child(instance)
	instance.emitting = true

	# Create "MISS" floating text
	var lane_colors = [Color.RED, Color.BLUE, Color.GREEN, Color.YELLOW]
	var text_color = Color.RED
	if lane >= 0 and lane <= 3:
		text_color = lane_colors[lane].darkened(0.3)

	create_floating_text("MISS", position, text_color)

	# Subtle screen shake
	apply_screen_shake(5.0, 0.1)

	await get_tree().create_timer(instance.lifetime).timeout
	instance.queue_free()

func create_perfect_feedback(position: Vector2, lane: int = -1):
	# Enhanced feedback for perfect hits
	create_hit_effect(position, "perfect", lane)
	create_floating_text("PERFECT!", position, Color.GOLD)

func create_hold_complete_effect(position: Vector2, lane: int, hold_quality: float):
	# Effect when a hold note is successfully completed
	var accuracy = "good"
	if hold_quality > 0.9:
		accuracy = "perfect"
	elif hold_quality > 0.7:
		accuracy = "great"

	create_hit_effect(position, accuracy, lane)

	# Special hold completion text
	if accuracy == "perfect":
		create_floating_text("HOLD PERFECT!", position, Color.GOLD)
	else:
		create_floating_text("HOLD " + accuracy.to_upper() + "!", position, Color.CYAN)

func create_beatlearning_startup_effect():
	# Special effect when starting a BeatLearning-generated beatmap
	var position = get_viewport().get_visible_rect().size / 2

	# Create series of expanding circles
	for i in range(3):
		var circle = create_expanding_circle()
		circle.position = position
		particle_container.add_child(circle)

		var tween = create_tween()
		tween.tween_delay(i * 0.2)
		tween.tween_property(circle, "scale", Vector3(3, 3, 1), 0.8)
		tween.tween_property(circle, "modulate:a", 0.0, 0.8)

		await get_tree().create_timer(1.0).timeout
		circle.queue_free()

	# Show "BeatLearning" text
	create_floating_text("BeatLearning", position, Color.CYAN)

func create_expanding_circle() -> Node2D:
	# Create an expanding ring effect
	var circle = Node2D.new()
	var sprite = Sprite2D.new()

	# Create circle texture
	var texture = ImageTexture.new()
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	# Draw a circle outline
	for x in range(64):
		for y in range(64):
			var center = Vector2(32, 32)
			var distance = Vector2(x, y).distance_to(center)
			if distance > 28 and distance < 32:
				image.set_pixel(x, y, Color.CYAN)

	texture.set_image(image)
	sprite.texture = texture
	sprite.modulate = Color.CYAN
	sprite.position = Vector2(-32, -32)

	circle.add_child(sprite)
	return circle

func cleanup():
	# Clean up all active effects
	for effect in active_effects:
		if is_instance_valid(effect):
			effect.queue_free()

	active_effects.clear()
	screen_shake_active = false

func get_active_effects_count() -> int:
	return active_effects.size()