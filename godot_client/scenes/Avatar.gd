## Avatar — Procedurally-drawn 2D character with layered customization.
## Ported from Phaser.js drawCharacterParts() in game.js.
##
## Rendering order (back to front):
##   Shadow → Back Items → Body (legs/arms/torso/head) → Outfit → Face → Hair → Hat → Held Items
##
## Usage:
##   avatar.equip_item("hair", "punk_pink")
##   avatar.equip_item("skin", "sky")
##   var json = avatar.export_avatar_state()
extends Node2D

## Current equipped items and visual state.
var current_state: Dictionary = {}


func _ready() -> void:
	current_state = ItemDatabase.get_default_profile()
	_start_idle_animation()


func _start_idle_animation() -> void:
	var base_y := position.y
	var tween := create_tween().set_loops()
	tween.tween_property(self, "position:y", base_y - 6.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "position:y", base_y + 6.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## Equips an item by category. For "skin", also updates the skin_color.
func equip_item(category: String, item_id: String) -> void:
	if category == "skin":
		current_state["skin"] = item_id
		var item := ItemDatabase.get_item_by_id("skin", item_id)
		if not item.is_empty():
			current_state["skin_color"] = item["color"]
	else:
		current_state[category] = item_id
	queue_redraw()


## Sets skin color directly (bypasses item lookup).
func set_skin_color(color: Color) -> void:
	current_state["skin_color"] = color
	queue_redraw()


## Serializes the current avatar state into a compact JSON string (< 500 bytes).
## Keys are abbreviated for compactness: h=hair, t=hat(top), o=outfit, b=back, s=skin, m=mood.
func export_avatar_state() -> String:
	var compact := {
		"h": current_state.get("hair", "none"),
		"t": current_state.get("hat", "none"),
		"o": current_state.get("outfit", "none"),
		"b": current_state.get("back", "none"),
		"s": current_state.get("skin", "default"),
		"m": current_state.get("mood", "is happy"),
	}
	return JSON.stringify(compact)


## Loads avatar state from a compact JSON string and redraws.
func load_avatar_state(json_string: String) -> void:
	var data = JSON.parse_string(json_string)
	if data == null or not data is Dictionary:
		push_warning("Avatar: Invalid JSON state string.")
		return
	current_state["hair"] = data.get("h", "none")
	current_state["hat"] = data.get("t", "none")
	current_state["outfit"] = data.get("o", "none")
	current_state["back"] = data.get("b", "none")
	current_state["skin"] = data.get("s", "default")
	current_state["mood"] = data.get("m", "is happy")
	# Resolve skin color from skin ID
	var skin_item := ItemDatabase.get_item_by_id("skin", current_state["skin"])
	if not skin_item.is_empty():
		current_state["skin_color"] = skin_item["color"]
	else:
		current_state["skin_color"] = Color("fbcfe8")
	queue_redraw()


# ─── Main Draw Entry Point ──────────────────────────────────────────
func _draw() -> void:
	var skin_color: Color = current_state.get("skin_color", Color("fbcfe8"))

	# Soft shadow underneath character
	_draw_ellipse_filled(Vector2(0, 28), 11.0, 3.0, Color(0, 0, 0, 0.15))

	# Layer 1: Back items (behind body)
	_draw_back_item()

	# Layer 2: Body (legs, arms, torso, head)
	_draw_body(skin_color)

	# Layer 3: Outfit overlay
	_draw_outfit()

	# Layer 4: Face (eyes, cheeks, mouth — always visible)
	_draw_face()

	# Layer 5: Hair
	_draw_hair()

	# Layer 6: Hat (topmost head layer)
	_draw_hat()

	# Layer 7: Held items drawn in front (wand)
	_draw_held_items()


# ─── Layer 1: Back Items ────────────────────────────────────────────
func _draw_back_item() -> void:
	var back: String = current_state.get("back", "none")
	if back == "skateboard":
		# Board body
		_draw_ellipse_filled(Vector2(-26, 4), 6.0, 22.5, Color("d97706"))
		_draw_ellipse_filled(Vector2(-26, 4), 4.0, 20.5, Color("ef4444"))
		# Wheels
		draw_circle(Vector2(-32, -10), 5.0, Color("475569"))
		draw_circle(Vector2(-32, 18), 5.0, Color("475569"))
	elif back == "wings":
		var wing_color := Color(1, 1, 1, 0.85)
		var stroke_color := Color("e2e8f0")
		# Left wing
		_draw_ellipse_filled(Vector2(-28, -6), 12.0, 7.0, wing_color)
		_draw_ellipse_stroke(Vector2(-28, -6), 12.0, 7.0, stroke_color, 2.0)
		# Right wing
		_draw_ellipse_filled(Vector2(28, -6), 12.0, 7.0, wing_color)
		_draw_ellipse_stroke(Vector2(28, -6), 12.0, 7.0, stroke_color, 2.0)


# ─── Layer 2: Body ──────────────────────────────────────────────────
func _draw_body(skin_color: Color) -> void:
	var stroke_col := Color.WHITE
	var stroke_w := 2.0

	# Legs
	_draw_rounded_rect_filled(Rect2(-10, 10, 8, 15), 4.0, skin_color)
	_draw_rounded_rect_stroke(Rect2(-10, 10, 8, 15), 4.0, stroke_col, stroke_w)
	_draw_rounded_rect_filled(Rect2(2, 10, 8, 15), 4.0, skin_color)
	_draw_rounded_rect_stroke(Rect2(2, 10, 8, 15), 4.0, stroke_col, stroke_w)

	# Arms
	_draw_rounded_rect_filled(Rect2(-20, -6, 8, 20), 4.0, skin_color)
	_draw_rounded_rect_stroke(Rect2(-20, -6, 8, 20), 4.0, stroke_col, stroke_w)
	_draw_rounded_rect_filled(Rect2(12, -6, 8, 20), 4.0, skin_color)
	_draw_rounded_rect_stroke(Rect2(12, -6, 8, 20), 4.0, stroke_col, stroke_w)

	# Torso
	_draw_rounded_rect_filled(Rect2(-12, -8, 24, 26), 8.0, skin_color)
	_draw_rounded_rect_stroke(Rect2(-12, -8, 24, 26), 8.0, stroke_col, stroke_w)

	# Head
	draw_circle(Vector2(0, -22), 15.0, skin_color)
	draw_arc(Vector2(0, -22), 15.0, 0, TAU, 32, stroke_col, stroke_w, true)


# ─── Layer 3: Outfit ────────────────────────────────────────────────
func _draw_outfit() -> void:
	var outfit: String = current_state.get("outfit", "none")

	if outfit == "collared_tie":
		var white := Color.WHITE
		# White shirt covers torso and arms
		_draw_rounded_rect_filled(Rect2(-12, -8, 24, 26), 4.0, white)
		_draw_rounded_rect_filled(Rect2(-20, -6, 8, 20), 4.0, white)
		_draw_rounded_rect_filled(Rect2(12, -6, 8, 20), 4.0, white)
		# Dark tie
		_draw_rounded_rect_filled(Rect2(-2.5, -6, 5, 16), 1.5, Color("1e293b"))

	elif outfit == "wedding_gown":
		var gown := Color(1, 1, 1, 0.95)
		# Bodice
		_draw_rounded_rect_filled(Rect2(-12, -8, 24, 20), 4.0, gown)
		# Skirt (wide)
		_draw_rounded_rect_filled(Rect2(-18, 10, 36, 15), 6.0, gown)
		# Short sleeves
		_draw_rounded_rect_filled(Rect2(-20, -6, 8, 15), 4.0, gown)
		_draw_rounded_rect_filled(Rect2(12, -6, 8, 15), 4.0, gown)
		# Rose detail
		draw_circle(Vector2(0, 0), 4.0, Color("ec4899"))

	elif outfit == "green_hoodie":
		var green := Color("22c55e")
		# Hoodie body
		_draw_rounded_rect_filled(Rect2(-13, -9, 26, 28), 6.0, green)
		# Hoodie sleeves
		_draw_rounded_rect_filled(Rect2(-21, -6, 10, 21), 4.0, green)
		_draw_rounded_rect_filled(Rect2(11, -6, 10, 21), 4.0, green)
		# Drawstrings
		var string_col := Color(1, 1, 1, 0.95)
		draw_line(Vector2(-4, -2), Vector2(-4, 8), string_col, 2.5, true)
		draw_line(Vector2(4, -2), Vector2(4, 8), string_col, 2.5, true)

	elif outfit == "cool_jacket":
		var dark := Color("1e293b")
		# Jacket body
		_draw_rounded_rect_filled(Rect2(-13, -9, 26, 27), 4.0, dark)
		# Jacket sleeves
		_draw_rounded_rect_filled(Rect2(-21, -6, 10, 21), 4.0, dark)
		_draw_rounded_rect_filled(Rect2(11, -6, 10, 21), 4.0, dark)
		# Red triangle lapel detail
		draw_colored_polygon(
			PackedVector2Array([Vector2(-6, -8), Vector2(6, -8), Vector2(0, 4)]),
			Color("ef4444")
		)


# ─── Layer 4: Face ──────────────────────────────────────────────────
func _draw_face() -> void:
	# Eye whites
	draw_circle(Vector2(-6, -24), 4.5, Color.WHITE)
	draw_circle(Vector2(6, -24), 4.5, Color.WHITE)
	# Pupils
	draw_circle(Vector2(-6, -24), 2.0, Color.BLACK)
	draw_circle(Vector2(6, -24), 2.0, Color.BLACK)
	# Highlight sparkle
	draw_circle(Vector2(-7, -25), 1.0, Color.WHITE)
	draw_circle(Vector2(5, -25), 1.0, Color.WHITE)

	# Rosy cheeks
	var cheek_color := Color(0.988, 0.647, 0.647, 0.7)
	draw_circle(Vector2(-10, -18), 3.0, cheek_color)
	draw_circle(Vector2(10, -18), 3.0, cheek_color)

	# Smile arc (bottom half of a small circle)
	draw_arc(Vector2(0, -18), 3.0, 0, PI, 12, Color(0, 0, 0, 0.8), 1.5, true)


# ─── Layer 5: Hair ──────────────────────────────────────────────────
func _draw_hair() -> void:
	var hair: String = current_state.get("hair", "none")

	if hair == "emo_black":
		# Sweeping curved fringe using quadratic bezier approximation
		var points := PackedVector2Array()
		points.append(Vector2(-16, -37))
		# Top curve: (-16,-37) → (14,-30) via control (-5,-42)
		points.append_array(
			_quadratic_bezier(Vector2(-16, -37), Vector2(-5, -42), Vector2(14, -30))
		)
		points.append(Vector2(10, -22))
		# Bottom curve: (10,-22) → (-14,-21) via control (-4,-28)
		points.append_array(
			_quadratic_bezier(Vector2(10, -22), Vector2(-4, -28), Vector2(-14, -21))
		)
		draw_colored_polygon(points, Color("1e293b"))

	elif hair == "wavy_gold":
		var gold := Color("facc15")
		# Side curls
		draw_circle(Vector2(-16, -22), 6.0, gold)
		draw_circle(Vector2(-17, -14), 5.0, gold)
		draw_circle(Vector2(16, -22), 6.0, gold)
		draw_circle(Vector2(17, -14), 5.0, gold)
		# Top wave
		_draw_ellipse_filled(Vector2(0, -36), 8.0, 4.0, gold)

	elif hair == "punk_pink":
		var pink := Color("ec4899")
		# Three spikes
		draw_colored_polygon(
			PackedVector2Array([Vector2(-16, -32), Vector2(-8, -46), Vector2(-2, -34)]),
			pink
		)
		draw_colored_polygon(
			PackedVector2Array([Vector2(-6, -34), Vector2(2, -49), Vector2(10, -34)]),
			pink
		)
		draw_colored_polygon(
			PackedVector2Array([Vector2(6, -34), Vector2(14, -46), Vector2(16, -32)]),
			pink
		)

	elif hair == "cozy_brown":
		var brown := Color("78350f")
		# Soft oval top + side tufts
		_draw_ellipse_filled(Vector2(0, -36), 8.5, 4.0, brown)
		draw_circle(Vector2(-15, -28), 5.0, brown)
		draw_circle(Vector2(15, -28), 5.0, brown)


# ─── Layer 6: Hat ───────────────────────────────────────────────────
func _draw_hat() -> void:
	var hat: String = current_state.get("hat", "none")

	if hat == "cap_sb":
		# Cap dome
		_draw_ellipse_filled(Vector2(0, -38), 8.0, 4.5, Color("475569"))
		# Visor brim
		_draw_rounded_rect_filled(Rect2(-22, -36, 16, 4), 2.0, Color("1e293b"))
		# Gold SB badge
		draw_circle(Vector2(0, -37), 3.0, Color("facc15"))

	elif hat == "newsboy":
		# Puffy cap
		_draw_ellipse_filled(Vector2(0, -38), 9.0, 4.0, Color("64748b"))
		# Band
		_draw_ellipse_filled(Vector2(0, -34), 9.5, 1.5, Color("475569"))

	elif hat == "wizard":
		# Cone
		draw_colored_polygon(
			PackedVector2Array([Vector2(-18, -34), Vector2(18, -34), Vector2(0, -60)]),
			Color("6366f1")
		)
		# Rim
		_draw_ellipse_filled(Vector2(0, -34), 10.0, 2.0, Color("4f46e5"))
		# Star tip
		draw_circle(Vector2(0, -48), 3.0, Color("facc15"))

	elif hat == "crown":
		# Multi-point crown
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(-14, -34), Vector2(-12, -46), Vector2(-6, -38),
				Vector2(0, -50), Vector2(6, -38),
				Vector2(12, -46), Vector2(14, -34),
			]),
			Color("eab308")
		)
		# Ruby gems
		draw_circle(Vector2(0, -49), 2.0, Color("ef4444"))
		draw_circle(Vector2(-12, -45), 1.5, Color("ef4444"))
		draw_circle(Vector2(12, -45), 1.5, Color("ef4444"))


# ─── Layer 7: Held Items (front) ────────────────────────────────────
func _draw_held_items() -> void:
	if current_state.get("back", "none") == "wand":
		# Wand stick
		draw_line(Vector2(16, 6), Vector2(28, -12), Color("78350f"), 2.5, true)
		# Sparkle orb
		draw_circle(Vector2(28, -12), 5.5, Color("facc15"))


# ═══════════════════════════════════════════════════════════════════
# Drawing Helpers
# ═══════════════════════════════════════════════════════════════════

## Generates points for a rounded rectangle polygon.
func _get_rounded_rect_points(rect: Rect2, radius: float, segments: int = 4) -> PackedVector2Array:
	radius = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var points := PackedVector2Array()
	# Corner centers: TL, TR, BR, BL
	var centers: Array[Vector2] = [
		rect.position + Vector2(radius, radius),
		rect.position + Vector2(rect.size.x - radius, radius),
		rect.position + Vector2(rect.size.x - radius, rect.size.y - radius),
		rect.position + Vector2(radius, rect.size.y - radius),
	]
	# Starting angle for each corner arc
	var start_angles: Array[float] = [PI, PI * 1.5, 0.0, PI * 0.5]

	for i in range(4):
		for j in range(segments + 1):
			var angle: float = start_angles[i] + (PI * 0.5) * float(j) / float(segments)
			points.append(centers[i] + Vector2(cos(angle), sin(angle)) * radius)
	return points


## Draws a filled rounded rectangle.
func _draw_rounded_rect_filled(rect: Rect2, radius: float, color: Color) -> void:
	var points := _get_rounded_rect_points(rect, radius)
	draw_colored_polygon(points, color)


## Draws a stroked (outlined) rounded rectangle.
func _draw_rounded_rect_stroke(rect: Rect2, radius: float, color: Color, width: float) -> void:
	var points := _get_rounded_rect_points(rect, radius)
	points.append(points[0])  # Close the loop
	draw_polyline(points, color, width, true)


## Draws a filled ellipse centered at `center` with radii `rx`, `ry`.
func _draw_ellipse_filled(center: Vector2, rx: float, ry: float, color: Color, segments: int = 20) -> void:
	var points := PackedVector2Array()
	for i in range(segments):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)


## Draws a stroked (outlined) ellipse.
func _draw_ellipse_stroke(center: Vector2, rx: float, ry: float, color: Color, width: float, segments: int = 20) -> void:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle: float = TAU * float(i) / float(segments)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polyline(points, color, width, true)


## Approximates a quadratic Bézier curve from p0→p2 via control point p1.
## Skips the first point (t=0) since callers typically already have it in their array.
func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, segments: int = 8) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var q0 := p0.lerp(p1, t)
		var q1 := p1.lerp(p2, t)
		points.append(q0.lerp(q1, t))
	return points
