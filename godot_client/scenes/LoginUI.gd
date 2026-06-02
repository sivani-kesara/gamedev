extends Control

@onready var username_input: LineEdit = $VBoxContainer/UsernameInput
@onready var enter_button: Button = $VBoxContainer/EnterButton

func _ready() -> void:
	enter_button.pressed.connect(_on_enter_pressed)
	# Wait for a successful handshake before allowing transition if not yet connected
	NetworkManager.connected_to_server.connect(_on_connected)

func _on_enter_pressed() -> void:
	var username: String = username_input.text.strip_edges()
	if username == "":
		# Simple validation: shake or ignore if empty
		return
		
	# Disable to prevent spamming
	enter_button.disabled = true
	enter_button.text = "Connecting..."
	
	# Check if NetworkManager already established the socket connection
	if NetworkManager.socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_authenticate_and_transition(username)

func _on_connected(_id: String, _players: Dictionary) -> void:
	# If the user already pressed Enter while we were handshaking, proceed
	if enter_button.disabled:
		_authenticate_and_transition(username_input.text.strip_edges())

func _authenticate_and_transition(username: String) -> void:
	var avatar_state: Dictionary = {"name": username}
	
	# Preserve existing local customizations (colors, mood, skin)
	if FileAccess.file_exists("user://avatar_save.json"):
		var file := FileAccess.open("user://avatar_save.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				avatar_state = parsed
				avatar_state["name"] = username
			file.close()
	
	# Call the connection/authentication methods (customize registers the name)
	NetworkManager.send_customize(avatar_state)
	
	# Save the authenticated state locally
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(avatar_state))
		file_out.close()
	
	# Cleanly transition to the game scene containing CustomizerUI
	# Note: Main.tscn is the root coordinator that houses CustomizerUI.tscn
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
