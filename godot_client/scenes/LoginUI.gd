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
@onready var password_input: LineEdit = $CenterContainer/InputForm/PasswordInput
@onready var error_label: Label = $CenterContainer/InputForm/ErrorLabel
@onready var submit_button: Button = $CenterContainer/InputForm/SubmitButton

func _ready() -> void:
	$CenterContainer/SelectionMenu/NewPlayerButton.pressed.connect(_on_new_player_pressed)
	$CenterContainer/SelectionMenu/ReturningPlayerButton.pressed.connect(_on_returning_player_pressed)
	$CenterContainer/InputForm/SubmitButton.pressed.connect(_on_submit_pressed)
	$CenterContainer/InputForm/BackButton.pressed.connect(_on_back_pressed)
	
	_show_selection_menu()
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.auth_success.connect(_on_auth_success)
	NetworkManager.auth_error.connect(_on_auth_error)

func _show_selection_menu() -> void:
	selection_menu.visible = true
	input_form.visible = false
	username_input.text = ""

func _show_input_form() -> void:
	selection_menu.visible = false
	input_form.visible = true
	error_label.text = ""
	password_input.text = ""

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
	var password: String = password_input.text
	if username == "" or password == "":
		error_label.text = "Username and Password required"
		return
		
	submit_button.disabled = true
	submit_button.text = "Connecting..."
	error_label.text = ""
	
	if NetworkManager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		NetworkManager.send_auth_request(current_mode == LoginMode.NEW_PLAYER, username, password)
	else:
		error_label.text = "Not connected to server."
		submit_button.disabled = false
		submit_button.text = "Start Building" if current_mode == LoginMode.NEW_PLAYER else "Enter World"

func _on_connected(_id: String, _players: Dictionary) -> void:
	if submit_button.disabled and error_label.text == "":
		var username: String = username_input.text.strip_edges()
		var password: String = password_input.text
		NetworkManager.send_auth_request(current_mode == LoginMode.NEW_PLAYER, username, password)

func _on_auth_error(message: String) -> void:
	error_label.text = message
	submit_button.disabled = false
	submit_button.text = "Start Building" if current_mode == LoginMode.NEW_PLAYER else "Enter World"

func _on_auth_success(avatar_data: Dictionary) -> void:
	# Save updated data locally so it persists for Customizer/Main scenes
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(avatar_data))
		file_out.close()
	
	# Scene routing based on state
	if current_mode == LoginMode.NEW_PLAYER:
		get_tree().change_scene_to_file("res://scenes/CustomizerUI.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
