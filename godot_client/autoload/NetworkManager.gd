extends Node

signal connected_to_server(my_id: String, players_dict: Dictionary)
signal player_joined(id: String, data: Dictionary)
signal player_moved(id: String, x: float, y: float)
signal player_left(id: String)
signal player_customized(id: String, data: Dictionary)
signal player_chat(id: String, message: String)
signal auth_success(avatar_data: Dictionary)
signal auth_error(message: String)

var socket := WebSocketPeer.new()
var server_url := "ws://127.0.0.1:8000/ws"
var is_new_signup: bool = false
var _reconnect_timer: Timer = null
var _reconnect_elapsed: float = 0.0
const RECONNECT_TIMEOUT: float = 3.0

func _ready() -> void:
	_reconnect_timer = Timer.new()
	_reconnect_timer.one_shot = true
	_reconnect_timer.wait_time = RECONNECT_TIMEOUT
	_reconnect_timer.timeout.connect(_on_reconnect_timeout)
	add_child(_reconnect_timer)
	connect_to_server()

func connect_to_server() -> void:
	if socket != null and socket.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		socket.close()
	socket = WebSocketPeer.new()
	var err = socket.connect_to_url(server_url)
	if err != OK:
		print("NetworkManager: Unable to connect to ", server_url)
		auth_error.emit("Unable to reach server.")
	else:
		print("NetworkManager: Connecting to ", server_url, "...")
		set_process(true)
		_reconnect_elapsed = 0.0
		_reconnect_timer.start()


func _on_reconnect_timeout() -> void:
	# If we're still not open after the timeout, give up and notify the UI
	if socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		print("NetworkManager: Reconnect timed out after ", RECONNECT_TIMEOUT, "s")
		auth_error.emit("Server unreachable. Please try again.")


func _process(_delta: float) -> void:
	socket.poll()
	var state = socket.get_ready_state()

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
		_reconnect_timer.stop()  # Connection succeeded, cancel timeout
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
		auth_success.emit(data.get("avatar_data", {}))
	elif msg_type == "auth_error":
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


## Sends the finalized avatar customization selections to the server.
## Maps the full-key dictionary to the server's "customize" action, which
## persists changes into the SQLite users table.
func send_customization_update(selections: Dictionary) -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var dict = selections.duplicate()
		dict["action"] = "customize"
		socket.send_text(JSON.stringify(dict))
