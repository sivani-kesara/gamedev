extends Node2D

var current_state: Dictionary = {}

@onready var back_layer: Sprite2D = $BackLayer
@onready var body_layer: Sprite2D = $BodyLayer
@onready var outfit_layer: Sprite2D = $OutfitLayer
@onready var hair_layer: Sprite2D = $HairLayer
@onready var hat_layer: Sprite2D = $HatLayer

var _idle_time: float = 0.0
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	current_state = ItemDatabase.get_default_profile()
	# Ensure body texture is loaded
	if body_layer.texture == null:
		body_layer.texture = load("res://assets/items/body/body_base.png")
	_apply_all_layers()

func _process(delta: float) -> void:
	_idle_time += delta
	# Gentle idle bounce on the entire avatar
	position.y = sin(_idle_time * 3.0) * 3.0

func init_avatar(profile_dict: Dictionary) -> void:
	current_state["hair"] = profile_dict.get("hair", "none")
	current_state["hat"] = profile_dict.get("hat", "none")
	current_state["outfit"] = profile_dict.get("outfit", "none")
	current_state["back"] = profile_dict.get("back", "none")
	current_state["mood"] = profile_dict.get("mood", "is happy")
	current_state["name"] = profile_dict.get("name", "Player")
	current_state["color"] = profile_dict.get("color", "0xffffff")
	
	# Handle skin color
	var sc = profile_dict.get("skin_color", "")
	if sc == "":
		var skin_id = profile_dict.get("skin", "default")
		var skin_item = ItemDatabase.get_item_by_id("skin", skin_id)
		if not skin_item.is_empty():
			sc = skin_item["color"].to_html(false)
		else:
			sc = "fbcfe8"
	current_state["skin_color"] = sc
	
	_apply_all_layers()
	queue_redraw()

func update_part(category: String, item_id: String) -> void:
	current_state[category] = item_id
	if category == "skin_color":
		update_skin_color(item_id)
	else:
		_apply_layer(category, item_id)
	queue_redraw()

func update_skin_color(hex_color: String) -> void:
	body_layer.modulate = Color(hex_color)
	current_state["skin_color"] = hex_color

func equip_item(category: String, item_id: String) -> void:
	update_part(category, item_id)

func export_avatar_state() -> String:
	var data := {
		"hair": current_state.get("hair", "none"),
		"hat": current_state.get("hat", "none"),
		"outfit": current_state.get("outfit", "none"),
		"back": current_state.get("back", "none"),
		"skin_color": current_state.get("skin_color", "fbcfe8"),
		"mood": current_state.get("mood", "is happy"),
		"name": current_state.get("name", "Player"),
		"color": current_state.get("color", "0xffffff")
	}
	return JSON.stringify(data)

func load_avatar_state(json_string: String) -> void:
	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_warning("Avatar: Invalid JSON state string.")
		return
	init_avatar(data)

func _apply_all_layers() -> void:
	var sc = current_state.get("skin_color", "fbcfe8")
	update_skin_color(str(sc))
	
	_apply_layer("back", current_state.get("back", "none"))
	_apply_layer("outfit", current_state.get("outfit", "none"))
	_apply_layer("hair", current_state.get("hair", "none"))
	_apply_layer("hat", current_state.get("hat", "none"))

func _apply_layer(category: String, item_id: String) -> void:
	var sprite: Sprite2D
	match category:
		"back": sprite = back_layer
		"outfit": sprite = outfit_layer
		"hair": sprite = hair_layer
		"hat": sprite = hat_layer
		_: return

	if item_id == "none" or item_id == "":
		sprite.texture = null
		return
	
	var path := "res://assets/items/" + category + "/" + item_id + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("Avatar: Texture not found at " + path)
		sprite.texture = null

func _draw() -> void:
	if not current_state.has("name"):
		return
	_draw_nametag(current_state["name"], current_state.get("color", "0xffffff"))

func _draw_nametag(player_name: String, border_color_str: String) -> void:
	var font_size := 12
	var text_size := _font.get_string_size(player_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

	var tag_width := maxf(60.0, text_size.x + 16.0)
	var tag_height := 18.0
	var tag_pos := Vector2(-tag_width / 2.0, -280.0)

	var border_color := Color.BLACK
	if border_color_str.begins_with("0x"):
		border_color = Color(border_color_str.replace("0x", "#"))
	elif border_color_str.begins_with("#"):
		border_color = Color(border_color_str)

	var pill_points := _get_rounded_rect_points(Rect2(tag_pos, Vector2(tag_width, tag_height)), 9.0)
	draw_colored_polygon(pill_points, Color(1, 1, 1, 0.95))
	
	var border_points := pill_points.duplicate()
	border_points.append(pill_points[0])
	draw_polyline(border_points, border_color, 2.0, true)

	var text_pos := Vector2(
		-text_size.x / 2.0,
		tag_pos.y + _font.get_ascent(font_size) + (tag_height - text_size.y) / 2.0
	)
	draw_string(_font, text_pos, player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0f172a"))

func _get_rounded_rect_points(rect: Rect2, radius: float, segments: int = 4) -> PackedVector2Array:
	radius = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	var centers: Array[Vector2] = [
		rect.position + Vector2(radius, radius),
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y - radius),
		rect.position + Vector2(radius, rect.size.y - radius),
	]
	var start_angles: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]
	for i in range(4):
		for j in range(segments + 1):
			var angle: float = start_angles[i] + (PI * 0.5) * float(j) / float(segments)
			points.append(centers[i] + Vector2(cos(angle), sin(angle)) * radius)
	return points
