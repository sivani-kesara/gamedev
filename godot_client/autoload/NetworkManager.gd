extends Node

signal connected_to_server(my_id: String, players_dict: Dictionary)
signal player_joined(id: String, data: Dictionary)
signal player_moved(id: String, x: float, y: float)
signal player_left(id: String)
signal player_customized(id: String, data: Dictionary)
signal player_chat(id: String, message: String)
signal auth_success(avatar_data: Dictionary)
signal auth_error(message: String)
signal auth_result(success: bool, message: String, mode: String)

var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:8000/ws"
var is_new_signup: bool = false

var pending_auth_mode: String = ""
var pending_username: String = ""
var pending_password: String = ""
var connection_start_time: int = 0
var is_connecting: bool = false

func _ready() -> void:
	connect_to_server()

func connect_to_server(mode: String = "") -> void:
	if socket != null and socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("NetworkManager: Unable to connect to ", server_url)
		is_connecting = false
		auth_result.emit(false, "Unable to reach server.", mode)
	else:
		print("NetworkManager: Connecting to ", server_url, "...")
		set_process(true)
		is_connecting = true
		connection_start_time = Time.get_ticks_msec()
		pending_auth_mode = mode

func start_auth(mode: String, user: String, pass_str: String) -> void:
	pending_auth_mode = mode
	pending_username = user
	pending_password = pass_str
	
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		send_auth_request(mode == "signup", user, pass_str)
	else:
		connect_to_server(mode)

func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()

	if is_connecting:
		if state == WebSocketPeer.STATE_OPEN:
			is_connecting = false
			if pending_auth_mode != "":
				send_auth_request(pending_auth_mode == "signup", pending_username, pending_password)
		elif Time.get_ticks_msec() - connection_start_time > 3000:
			is_connecting = false
			socket.close()
			print("NetworkManager: Connection timed out.")
			auth_result.emit(false, "Connection timeout.", pending_auth_mode)

	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count() > 0:
			var packet = socket.get_packet()
			var msg_text = packet.get_string_from_utf8()
			_handle_message(msg_text)

	elif state == WebSocketPeer.STATE_CLOSED:
		var code = socket.get_close_code()
		var reason = socket.get_close_reason()
		print("NetworkManager: WebSocket Closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
		set_process(false)

func _handle_message(msg_text: String) -> void:
	var parsed = JSON.parse_string(msg_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	
	if not data.has("type"):
		return
		
	var msg_type = data["type"]
	
	if msg_type == "init":
		print("NetworkManager: Connected as ", data.get("id"))
		connected_to_server.emit(data.get("id", ""), data.get("players", {}))
	elif msg_type == "playerJoined":
		player_joined.emit(data.get("id", ""), data.get("player", {}))
	elif msg_type == "playerMoved":
		player_moved.emit(data.get("id", ""), data.get("x", 0.0), data.get("y", 0.0))
	elif msg_type == "playerLeft":
		player_left.emit(data.get("id", ""))
	elif msg_type == "playerCustomized":
		player_customized.emit(data.get("id", ""), data.get("player", {}))
	elif msg_type == "playerChat":
		player_chat.emit(data.get("id", ""), data.get("message", ""))
	elif msg_type == "auth_success":
		auth_result.emit(true, "", pending_auth_mode)
		auth_success.emit(data.get("avatar_data", {}))
	elif msg_type == "auth_error":
		auth_result.emit(false, data.get("message", "Unknown error"), pending_auth_mode)
		auth_error.emit(data.get("message", "Unknown error"))

func send_move(x: float, y: float) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = {
			"action": "move",
			"x": x,
			"y": y
		}
		socket.send_text(JSON.stringify(dict))

func send_customize(avatar_state: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = avatar_state.duplicate()
		dict["action"] = "customize"
		socket.send_text(JSON.stringify(dict))

func send_chat(message: String) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = {
			"action": "chat",
			"message": message
		}
		socket.send_text(JSON.stringify(dict))

func send_auth_request(is_signup: bool, user: String, pass_str: String) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = {
			"action": "signup" if is_signup else "login",
			"username": user,
			"password": pass_str
		}
		socket.send_text(JSON.stringify(dict))

func send_customization_update(selections: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = selections.duplicate()
		dict["action"] = "customize"
		socket.send_text(JSON.stringify(dict))
