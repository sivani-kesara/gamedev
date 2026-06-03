## Main — Root scene controller.
## Draws the whimsical cartoon background, manages the local Avatar,
## handles multiplayer sync, and navigates to CustomizerUI scene on tap.
extends Node2D


@onready var avatar: Node2D = $Avatar

var other_players: Dictionary = {}
var my_id: String = ""
var avatar_scene: PackedScene = preload("res://scenes/Avatar.tscn")


func _ready() -> void:
	# Load any previously saved avatar state
	_load_saved_state()

	# If this is a brand new signup, go straight to the wardrobe
	if NetworkManager.is_new_signup:
		NetworkManager.is_new_signup = false
		get_tree().change_scene_to_file("res://scenes/CustomizerUI.tscn")
		return

	# Network bindings
	NetworkManager.connected_to_server.connect(_on_connected)
	NetworkManager.player_joined.connect(_on_player_joined)
	NetworkManager.player_moved.connect(_on_player_moved)
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.player_customized.connect(_on_player_customized)

	# Setup local avatar click button (opens wardrobe)
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(360, 360)
	btn.position = Vector2(-180, -300)
	btn.pressed.connect(_on_local_avatar_clicked)
	avatar.add_child(btn)


func _load_saved_state() -> void:
	if FileAccess.file_exists("user://avatar_save.json"):
		var file := FileAccess.open("user://avatar_save.json", FileAccess.READ)
		if file:
			var json: String = file.get_as_text()
			file.close()
			var data = JSON.parse_string(json)
			if data != null and data is Dictionary:
				avatar.init_avatar(data)


func _save_state() -> void:
	var json: String = avatar.export_avatar_state()
	var file := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file:
		file.store_string(json)
		file.close()

	# Also send to server
	if my_id != "":
		NetworkManager.send_customization_update(JSON.parse_string(json))


# ─── Background Drawing ─────────────────────────────────────────────
# Draws a whimsical cartoon scene behind the avatar: deep sky, clouds,
# stars, rolling grass hills, mushrooms, and trees.
func _draw() -> void:
	# ── Sky ──
	var sky_colors: Array[Color] = [
		Color("0f0a2e"), Color("1a1145"), Color("2d1b69"),
		Color("3b2d8e"), Color("4f46e5"), Color("6366f1"),
		Color("818cf8"), Color("a5b4fc"), Color("c7d2fe"), Color("bae6fd"),
	]
	var band_height: float = 580.0 / sky_colors.size()
	for i in range(sky_colors.size()):
		draw_rect(Rect2(0, i * band_height, 720, band_height + 1), sky_colors[i])

	# ── Stars & sparkles ──
	var star_positions: Array[Vector2] = [
		Vector2(80, 45), Vector2(200, 25), Vector2(340, 60),
		Vector2(480, 35), Vector2(600, 55), Vector2(150, 95),
		Vector2(420, 20), Vector2(550, 85), Vector2(300, 110),
		Vector2(660, 40), Vector2(100, 140), Vector2(260, 150),
	]
	var star_colors: Array[Color] = [
		Color("fde047"), Color("f472b6"), Color("60a5fa"),
		Color("fde047"), Color("34d399"), Color("f472b6"),
		Color("fde047"), Color("60a5fa"), Color("fde047"),
		Color("34d399"), Color("f472b6"), Color("fde047"),
	]
	for i in range(star_positions.size()):
		var r: float = 1.5 + fmod(float(i) * 0.7, 2.0)
		draw_circle(star_positions[i], r, star_colors[i])
		if i % 3 == 0:
			draw_circle(star_positions[i], r * 2.5, Color(star_colors[i], 0.15))

	# ── Clouds ──
	_draw_cloud(Vector2(120, 120), 1.0)
	_draw_cloud(Vector2(520, 90), 1.3)
	_draw_cloud(Vector2(350, 170), 0.8)

	# ── Grass base ──
	draw_rect(Rect2(0, 500, 720, 780), Color("86efac"))

	# ── Rolling hills ──
	_draw_hill(Vector2(180, 510), 260, 120, Color("4ade80"))
	_draw_hill(Vector2(550, 540), 200, 100, Color("22c55e"))
	_draw_hill(Vector2(380, 560), 180, 80, Color("16a34a"))

	# ── Yellow path ──
	_draw_hill(Vector2(360, 540), 130, 50, Color("fef08a", 0.4))
	_draw_hill(Vector2(360, 540), 110, 40, Color("fef08a", 0.6))

	# ── Mushrooms ──
	_draw_mushroom(Vector2(90, 490))
	_draw_mushroom(Vector2(630, 480))
	_draw_mushroom(Vector2(250, 530))
	_draw_mushroom(Vector2(500, 540))

	# ── Trees ──
	_draw_tree(Vector2(60, 380), Color("16a34a"), Color("15803d"))
	_draw_tree(Vector2(660, 400), Color("22c55e"), Color("16a34a"))


func _draw_cloud(center: Vector2, scale_factor: float) -> void:
	var c := Color(1, 1, 1, 0.22)
	draw_circle(center, 30 * scale_factor, c)
	draw_circle(center + Vector2(28, -8) * scale_factor, 22 * scale_factor, c)
	draw_circle(center + Vector2(-24, -5) * scale_factor, 20 * scale_factor, c)
	draw_circle(center + Vector2(10, -15) * scale_factor, 18 * scale_factor, c)


func _draw_hill(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 24
	for i in range(segments + 1):
		var angle: float = PI + PI * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	points.append(center + Vector2(rx, 0))
	draw_colored_polygon(points, color)


func _draw_mushroom(pos: Vector2) -> void:
	draw_rect(Rect2(pos.x - 5, pos.y, 10, 18), Color("ffedd5"))
	_draw_oval(pos + Vector2(0, 2), 14.0, 9.0, Color("ef4444"))
	draw_circle(pos + Vector2(-5, -1), 2.5, Color.WHITE)
	draw_circle(pos + Vector2(5, 2), 2.0, Color.WHITE)
	draw_circle(pos + Vector2(0, -3), 2.5, Color.WHITE)


func _draw_tree(base: Vector2, primary: Color, dark: Color) -> void:
	draw_rect(Rect2(base.x - 7, base.y, 14, 70), Color("78350f"))
	_draw_oval(base + Vector2(0, 5), 42.0, 42.0, dark)
	_draw_oval(base + Vector2(0, -10), 38.0, 38.0, primary)
	_draw_oval(base + Vector2(-12, -22), 16.0, 16.0, Color("86efac", 0.4))


func _draw_oval(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments: int = 16
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)


# ─── Input Handling ──────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_pos = get_global_mouse_position()
		_handle_ground_tap(target_pos)
	elif event is InputEventScreenTouch and event.pressed:
		var target_pos = event.position
		_handle_ground_tap(target_pos)


func _on_local_avatar_clicked() -> void:
	# Navigate to the wardrobe customizer scene
	_save_state()
	get_tree().change_scene_to_file("res://scenes/CustomizerUI.tscn")


func _handle_ground_tap(target_pos: Vector2) -> void:
	# Send move to server
	NetworkManager.send_move(target_pos.x, target_pos.y)
	# Optimistic local movement
	_tween_avatar_move(avatar, target_pos)


# ─── Multiplayer Networking ─────────────────────────────────────────────

func _on_connected(id: String, players: Dictionary) -> void:
	my_id = id
	# Broadcast our look to the server
	var state_dict = JSON.parse_string(avatar.export_avatar_state())
	NetworkManager.send_customization_update(state_dict)

	# Set our local avatar name/color from the server
	if players.has(my_id):
		avatar.current_state["name"] = players[my_id].get("name", "You!")
		avatar.current_state["color"] = players[my_id].get("color", "0xdb2777")
		avatar.queue_redraw()

	# Setup existing players
	for pid in players.keys():
		if pid != my_id:
			_spawn_player(pid, players[pid])


func _on_player_joined(id: String, data: Dictionary) -> void:
	if id != my_id:
		_spawn_player(id, data)


func _on_player_left(id: String) -> void:
	if other_players.has(id):
		other_players[id].queue_free()
		other_players.erase(id)


func _on_player_moved(id: String, x: float, y: float) -> void:
	if other_players.has(id):
		var other_avatar = other_players[id]
		_tween_avatar_move(other_avatar, Vector2(x, y))


func _on_player_customized(id: String, data: Dictionary) -> void:
	if other_players.has(id):
		var other_avatar = other_players[id]
		other_avatar.init_avatar(data)


func _spawn_player(id: String, data: Dictionary) -> void:
	if other_players.has(id):
		return

	var new_avatar = avatar_scene.instantiate()
	add_child(new_avatar)

	# Load customized state using init_avatar
	new_avatar.init_avatar(data)

	# Set position
	new_avatar.position = Vector2(data.get("x", 360), data.get("y", 500))

	# Scale to match local avatar
	new_avatar.scale = Vector2(0.55, 0.55)

	other_players[id] = new_avatar


func _tween_avatar_move(target_avatar: Node2D, target_pos: Vector2) -> void:
	var dist = target_avatar.position.distance_to(target_pos)
	var duration = clamp(dist * 0.003, 0.2, 1.0)

	var tween = create_tween()
	tween.set_parallel(true)

	# Move position
	tween.tween_property(target_avatar, "position", target_pos, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	# Waddle effect - scale bounce
	var original_scale = Vector2(0.55, 0.55)
	if target_avatar == avatar:
		original_scale = avatar.scale
	else:
		target_avatar.scale = original_scale

	var waddle_steps = max(1, int(duration / 0.2))

	var scale_tween = create_tween()
	for i in range(waddle_steps):
		scale_tween.tween_property(target_avatar, "scale", Vector2(original_scale.x * 1.15, original_scale.y * 0.8), 0.1)
		scale_tween.tween_property(target_avatar, "scale", original_scale, 0.1)
