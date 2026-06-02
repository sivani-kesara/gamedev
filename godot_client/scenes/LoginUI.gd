extends Control

enum LoginMode {
	NEW_PLAYER,
	RETURNING_PLAYER
}

var current_mode: LoginMode = LoginMode.NEW_PLAYER

@onready var selection_menu: VBoxContainer = $CenterContainer/SelectionMenu
@onready var input_form: VBoxContainer = $CenterContainer/InputForm
@onready var form_title: Label = $CenterContainer/InputForm/FormTitle
@onready var username_input: LineEdit = $CenterContainer/InputForm/UsernameInput
@onready var submit_button: Button = $CenterContainer/InputForm/SubmitButton

func _ready() -> void:
	$CenterContainer/SelectionMenu/NewPlayerButton.pressed.connect(_on_new_player_pressed)
	$CenterContainer/SelectionMenu/ReturningPlayerButton.pressed.connect(_on_returning_player_pressed)
	$CenterContainer/InputForm/SubmitButton.pressed.connect(_on_submit_pressed)
	$CenterContainer/InputForm/BackButton.pressed.connect(_on_back_pressed)
	
	_show_selection_menu()
	NetworkManager.connected_to_server.connect(_on_connected)

func _show_selection_menu() -> void:
	selection_menu.visible = true
	input_form.visible = false
	username_input.text = ""

func _show_input_form() -> void:
	selection_menu.visible = false
	input_form.visible = true

func _on_new_player_pressed() -> void:
	current_mode = LoginMode.NEW_PLAYER
	form_title.text = "Create Account!"
	submit_button.text = "Start Building"
	_show_input_form()

func _on_returning_player_pressed() -> void:
	current_mode = LoginMode.RETURNING_PLAYER
	form_title.text = "Welcome Back!"
	submit_button.text = "Enter World"
	_show_input_form()

func _on_back_pressed() -> void:
	_show_selection_menu()

func _on_submit_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	if username == "":
		return
		
	submit_button.disabled = true
	submit_button.text = "Connecting..."
	
	if NetworkManager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_authenticate_and_transition(username)

func _on_connected(_id: String, _players: Dictionary) -> void:
	if submit_button.disabled:
		_authenticate_and_transition(username_input.text.strip_edges())

func _authenticate_and_transition(username: String) -> void:
	var avatar_state: Dictionary = {"name": username}
	
	# Preserve existing local customizations
	if FileAccess.file_exists("user://avatar_save.json"):
		var file := FileAccess.open("user://avatar_save.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				avatar_state = parsed
				avatar_state["name"] = username
			file.close()
	
	# Handshake payload
	NetworkManager.send_customize(avatar_state)
	
	# Save updated name locally
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(avatar_state))
		file_out.close()
	
	# Scene routing based on state
	if current_mode == LoginMode.NEW_PLAYER:
		get_tree().change_scene_to_file("res://scenes/CustomizerUI.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
