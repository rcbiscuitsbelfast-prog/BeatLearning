extends Control

# Main game entry point
# Manages scene transitions and overall game flow

@onready var menu_vbox: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var song_selection_button: Button = $VBoxContainer/SongSelectionButton
@onready var start_game_button: Button = $VBoxContainer/StartGameButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

@onready var gameplay_node: Node = $Gameplay

var gameplay_manager: GameplayManager
var song_selection_menu: Control
var current_scene: String = "menu"

var selected_beatmap: String = ""
var selected_audio: String = ""

func _ready():
	setup_gameplay_scene()
	setup_song_selection_menu()
	update_menu_state()

func setup_gameplay_scene():
	# Create gameplay manager
	gameplay_manager = preload("res://src/scripts/gameplay_manager.gd").new()
	gameplay_node.add_child(gameplay_manager)

	# Create background
	var background = ColorRect.new()
	background.color = Color(0.101961, 0.101961, 0.180392, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay_node.add_child(background)

	# Create camera
	var camera = Camera2D.new()
	camera.position = Vector2(960, 540)
	gameplay_node.add_child(camera)

	# Connect signals
	gameplay_manager.song_started.connect(_on_song_started)
	gameplay_manager.song_finished.connect(_on_song_finished)
	gameplay_manager.note_hit.connect(_on_note_hit)
	gameplay_manager.note_missed.connect(_on_note_missed)

func setup_song_selection_menu():
	# Create song selection UI
	song_selection_menu = Control.new()
	song_selection_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(song_selection_menu)

	var background = ColorRect.new()
	background.color = Color(0.101961, 0.101961, 0.180392, 1)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	song_selection_menu.add_child(background)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(100, 100)
	song_selection_menu.add_child(vbox)

	var title = Label.new()
	title.text = "Select Song"
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Song list container
	var song_list = VBoxContainer.new()
	song_list.name = "SongList"
	vbox.add_child(song_list)

	# Back button
	var back_button = Button.new()
	back_button.text = "Back to Menu"
	back_button.pressed.connect(_on_back_to_menu)
	vbox.add_child(back_button)

	song_selection_menu.visible = false

func update_menu_state():
	song_selection_button.disabled = selected_beatmap.is_empty()
	start_game_button.disabled = selected_beatmap.is_empty() or selected_audio.is_empty()

	if not selected_beatmap.is_empty():
		start_game_button.text = "Start Game"
	else:
		start_game_button.text = "Select Song First"

func _on_song_selection_button_pressed():
	show_song_selection()

func _on_start_game_button_pressed():
	if selected_beatmap.is_empty() or selected_audio.is_empty():
		return

	start_gameplay()

func _on_quit_button_pressed():
	get_tree().quit()

func show_song_selection():
	current_scene = "song_selection"
	menu_vbox.visible = false
	song_selection_menu.visible = true

	# Load available songs
	load_available_songs()

func load_available_songs():
	var song_list = song_selection_menu.get_node("SongList")

	# Clear existing song buttons
	for child in song_list.get_children():
		child.queue_free()

	# Find available beatmaps
	var beatmap_parser = BeatmapParser.new()
	var beatmap_dir = "res://src/assets/beatmaps/"
	var beatmaps = beatmap_parser.get_available_beatmaps(beatmap_dir)

	for beatmap in beatmaps:
		var song_button = Button.new()
		var format_indicator = ""
		if beatmap.has("format"):
			format_indicator = " [%s]" % beatmap.format

		song_button.text = "%s - %s (%s)%s" % [beatmap.artist, beatmap.title, beatmap.difficulty, format_indicator]
		song_button.pressed.connect(_on_song_selected.bind(beatmap))
		song_list.add_child(song_button)

	if beatmaps.is_empty():
		var no_songs_label = Label.new()
		no_songs_label.text = "No songs found. Add .osu files to src/assets/beatmaps/"
		song_list.add_child(no_songs_label)

func _on_song_selected(beatmap_info: Dictionary):
	selected_beatmap = beatmap_info.file_path

	# Find corresponding audio file
	var audio_filename = ""
	if FileAccess.file_exists(selected_beatmap):
		var beatmap_parser = BeatmapParser.new()
		var beatmap_data = beatmap_parser.parse_beatmap(selected_beatmap)
		audio_filename = beatmap_data.metadata.get("audio_filename", "")

	if not audio_filename.is_empty():
		var audio_path = "res://src/assets/audio/" + audio_filename
		if FileAccess.file_exists(audio_path):
			selected_audio = audio_path
		else:
			selected_audio = ""
			push_error("Audio file not found: " + audio_path)

	update_menu_state()
	show_main_menu()

func _on_back_to_menu():
	show_main_menu()

func show_main_menu():
	current_scene = "menu"
	menu_vbox.visible = true
	song_selection_menu.visible = false
	gameplay_node.visible = false

func start_gameplay():
	current_scene = "gameplay"
	menu_vbox.visible = false
	song_selection_menu.visible = false
	gameplay_node.visible = true

	# Start the song
	if not gameplay_manager.start_song(selected_beatmap, selected_audio):
		show_main_menu()
		push_error("Failed to start gameplay")

func _on_song_started(beatmap_data: Dictionary):
	print("Song started: ", beatmap_data.metadata.get("title", "Unknown"))

func _on_song_finished(score: int):
	var stats = gameplay_manager.get_game_stats()
	print("Song finished! Score: ", score)
	print("Accuracy: %.1f%%" % stats.accuracy)
	print("Max Combo: ", stats.max_combo)

	# Show results or return to menu
	show_main_menu()

func _on_note_hit(lane: int, accuracy: String, score: int):
	print("Lane %d hit! %s - +%d points" % [lane, accuracy, score])

func _on_note_missed(lane: int):
	print("Lane %d missed!" % lane)

func _input(event):
	if event is InputEventKey and event.pressed:
		match current_scene:
			"gameplay":
				if event.keycode == KEY_ESCAPE:
					# Pause game or return to menu
					if gameplay_manager.is_playing:
						if gameplay_manager.is_paused:
							gameplay_manager.resume_game()
						else:
							gameplay_manager.pause_game()
					else:
						show_main_menu()
				elif event.keycode == KEY_ENTER and not gameplay_manager.is_playing:
					start_gameplay()

			"song_selection":
				if event.keycode == KEY_ESCAPE:
					show_main_menu()