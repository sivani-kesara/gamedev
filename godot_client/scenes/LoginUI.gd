extends Control

enum States {
	SELECTION,
	INPUT_FORM
}

var current_state: States = States.SELECTION
var is_signup: bool = false

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
	
	_update_ui_state(States.SELECTION)
	NetworkManager.auth_result.connect(_on_auth_result)
	NetworkManager.auth_success.connect(_on_auth_success)

func _update_ui_state(new_state: States) -> void:
	current_state = new_state
	match current_state:
		States.SELECTION:
			selection_menu.visible = true
			input_form.visible = false
			username_input.text = ""
			password_input.text = ""
			error_label.text = ""
			submit_button.disabled = false
		States.INPUT_FORM:
			selection_menu.visible = false
			input_form.visible = true
			error_label.text = ""
			password_input.text = ""
			submit_button.disabled = false
			if is_signup:
				form_title.text = "Create Account!"
				submit_button.text = "Start Building"
			else:
				form_title.text = "Welcome Back!"
				submit_button.text = "Enter World"

func _on_new_player_pressed() -> void:
	is_signup = true
	_update_ui_state(States.INPUT_FORM)

func _on_returning_player_pressed() -> void:
	is_signup = false
	_update_ui_state(States.INPUT_FORM)

func _on_back_pressed() -> void:
	_update_ui_state(States.SELECTION)

func _on_submit_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	var password: String = password_input.text
	if username == "" or password == "":
		error_label.text = "Username and Password required"
		return
		
	submit_button.disabled = true
	submit_button.text = "Connecting..."
	error_label.text = ""
	
	var mode_str = "signup" if is_signup else "login"
	NetworkManager.start_auth(mode_str, username, password)

func _on_auth_result(success: bool, message: String, mode: String) -> void:
	if not success:
		error_label.text = message
		submit_button.disabled = false
		submit_button.text = "Start Building" if is_signup else "Enter World"

func _on_auth_success(avatar_data: Dictionary) -> void:
	# Save updated data locally so it persists for Customizer/Main scenes
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(avatar_data))
		file_out.close()
	
	if is_signup:
		NetworkManager.is_new_signup = true
	
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
