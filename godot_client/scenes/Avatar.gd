## Avatar — Sprite2D-layered 2D character with dynamic texture loading.
##
## Rendering order (back to front, via z_index):
##   BackLayer (0) → BodyLayer (1) → OutfitLayer (2) → HairLayer (3) → HatLayer (4)
##
## All asset textures are pre-drawn on identical 512x512 translucent squares
## sharing the same center pivot, so every Sprite2D sits at (0,0) and aligns
## automatically without manual pixel offsets.
##
## Usage:
##   avatar.init_avatar(profile_dict)
##   avatar.update_part("hair", "punk_pink")
##   avatar.update_skin_color("#fbcfe8")
##   var json = avatar.export_avatar_state()
extends Node2D

## Current equipped items and visual state.
var current_state: Dictionary = {}

## Sprite2D layer references.
@onready var back_layer: Sprite2D = $BackLayer
@onready var body_layer: Sprite2D = $BodyLayer
@onready var outfit_layer: Sprite2D = $OutfitLayer
@onready var hair_layer: Sprite2D = $HairLayer
@onready var hat_layer: Sprite2D = $HatLayer

## Maps category keys to their corresponding Sprite2D node.
var _layer_map: Dictionary = {}

## Idle bounce state.
var _idle_time: float = 0.0

## Nametag font (uses the engine fallback).
var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_layer_map = {
		"back": back_layer,
		"outfit": outfit_layer,
		"hair": hair_layer,
		"hat": hat_layer,
	}
	current_state = ItemDatabase.get_default_profile()
	_apply_all_layers()


func _process(delta: float) -> void:
	_idle_time += delta
	# Gentle idle bounce on the entire avatar
	position.y = sin(_idle_time * 3.0) * 3.0


# ═══════════════════════════════════════════════════════════════════
# Public API
# ═══════════════════════════════════════════════════════════════════

## Loads a full profile dictionary and applies all visual layers at once.
## Expected keys: "hair", "hat", "outfit", "back", "color", "skin", "name", "mood"
func init_avatar(profile_dict: Dictionary) -> void:
	current_state["hair"] = profile_dict.get("hair", "none")
	current_state["hat"] = profile_dict.get("hat", "none")
	current_state["outfit"] = profile_dict.get("outfit", "none")
	current_state["back"] = profile_dict.get("back", "none")
	current_state["skin"] = profile_dict.get("skin", "default")
	current_state["mood"] = profile_dict.get("mood", "is happy")
	if profile_dict.has("name"):
		current_state["name"] = profile_dict["name"]
	if profile_dict.has("color"):
		current_state["color"] = profile_dict["color"]
	# Resolve skin color from skin ID via ItemDatabase
	var skin_item := ItemDatabase.get_item_by_id("skin", current_state["skin"])
	if not skin_item.is_empty():
		current_state["skin_color"] = skin_item["color"]
	else:
		current_state["skin_color"] = Color("fbcfe8")
	_apply_all_layers()
	queue_redraw()


## Dynamically loads a texture for a specific category layer.
## If item_id == "none", clears that layer's texture.
func update_part(category: String, item_id: String) -> void:
	current_state[category] = item_id
	if category == "skin":
		var skin_item := ItemDatabase.get_item_by_id("skin", item_id)
		if not skin_item.is_empty():
			current_state["skin_color"] = skin_item["color"]
			body_layer.modulate = skin_item["color"]
		return
	_apply_layer(category, item_id)
	queue_redraw()


## Changes the color tint (modulate) on the BodyLayer only.
## Accepts a hex string like "#fbcfe8" or "fbcfe8".
func update_skin_color(hex_string: String) -> void:
	var color := Color.from_string(hex_string, Color("fbcfe8"))
	body_layer.modulate = color
	current_state["skin_color"] = color


## Equips an item by category (legacy compatibility with CustomizerUI/Main).
func equip_item(category: String, item_id: String) -> void:
	update_part(category, item_id)


## Serializes the current avatar state to a JSON string.
## Uses the full SQLite-compatible keys: hair, hat, outfit, back, skin, mood.
func export_avatar_state() -> String:
	var data := {
		"hair": current_state.get("hair", "none"),
		"hat": current_state.get("hat", "none"),
		"outfit": current_state.get("outfit", "none"),
		"back": current_state.get("back", "none"),
		"skin": current_state.get("skin", "default"),
		"mood": current_state.get("mood", "is happy"),
	}
	if current_state.has("name"):
		data["name"] = current_state["name"]
	if current_state.has("color"):
		data["color"] = current_state["color"]
	return JSON.stringify(data)


## Loads avatar state from a JSON string and redraws.
## Accepts both the full-key format (from server) and the compact format (legacy).
func load_avatar_state(json_string: String) -> void:
	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_warning("Avatar: Invalid JSON state string.")
		return
	# Support both full keys and legacy compact keys
	current_state["hair"] = data.get("hair", data.get("h", "none"))
	current_state["hat"] = data.get("hat", data.get("t", "none"))
	current_state["outfit"] = data.get("outfit", data.get("o", "none"))
	current_state["back"] = data.get("back", data.get("b", "none"))
	current_state["skin"] = data.get("skin", data.get("s", "default"))
	current_state["mood"] = data.get("mood", data.get("m", "is happy"))
	if data.has("name"):
		current_state["name"] = data["name"]
	if data.has("color"):
		current_state["color"] = data["color"]
	# Resolve skin color from skin ID
	var skin_item := ItemDatabase.get_item_by_id("skin", current_state["skin"])
	if not skin_item.is_empty():
		current_state["skin_color"] = skin_item["color"]
	else:
		current_state["skin_color"] = Color("fbcfe8")
	_apply_all_layers()
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════
# Internal Layer Management
# ═══════════════════════════════════════════════════════════════════

## Applies textures and skin color across all layers.
func _apply_all_layers() -> void:
	# Body layer always has body_base.png loaded from the .tscn;
	# just apply the skin color tint.
	var skin_color: Color = current_state.get("skin_color", Color("fbcfe8"))
	body_layer.modulate = skin_color
	# Apply each equipment category
	for category in _layer_map.keys():
		var item_id: String = current_state.get(category, "none")
		_apply_layer(category, item_id)


## Loads a texture into a single Sprite2D layer.
func _apply_layer(category: String, item_id: String) -> void:
	if not _layer_map.has(category):
		return
	var sprite: Sprite2D = _layer_map[category]
	if item_id == "none" or item_id == "":
		sprite.texture = null
		return
	var path := "res://assets/items/" + category + "/" + item_id + ".png"
	if ResourceLoader.exists(path):
		sprite.texture = load(path)
	else:
		push_warning("Avatar: Texture not found at " + path)
		sprite.texture = null


# ═══════════════════════════════════════════════════════════════════
# Nametag Drawing (kept as _draw() overlay above the sprites)
# ═══════════════════════════════════════════════════════════════════

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

	# Background pill
	var pill_points := _get_rounded_rect_points(Rect2(tag_pos, Vector2(tag_width, tag_height)), 9.0)
	draw_colored_polygon(pill_points, Color(1, 1, 1, 0.95))
	# Border
	var border_points := pill_points.duplicate()
	border_points.append(pill_points[0])
	draw_polyline(border_points, border_color, 2.0, true)

	# Text
	var text_pos := Vector2(
		-text_size.x / 2.0,
		tag_pos.y + _font.get_ascent(font_size) + (tag_height - text_size.y) / 2.0
	)
	draw_string(_font, text_pos, player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("0f172a"))


## Generates points for a rounded rectangle polygon.
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
