extends Control

signal item_selected(category: String, item_id: String)

@onready var avatar_preview: Node2D = $PreviewContainer/AvatarPreview
@onready var category_tabs: HBoxContainer = $WardrobePanel/VBox/CategoryScroll/CategoryTabs
@onready var item_grid: GridContainer = $WardrobePanel/VBox/ItemScroll/ItemGrid
@onready var save_button: Button = $WardrobePanel/VBox/ActionButtons/SaveButton
@onready var color_picker_container: HBoxContainer = $WardrobePanel/VBox/ColorPickerContainer
@onready var color_picker_button: ColorPickerButton = $WardrobePanel/VBox/ColorPickerContainer/ColorPickerButton

var _current_tab: String = "hair"
var current_selections: Dictionary = {}
var _tab_buttons: Dictionary = {}

const CATEGORIES: Array = ["hair", "hat", "outfit", "back", "skin"]
const TAB_ICONS: Dictionary = {
	"hair": "💇",
	"hat": "🎩",
	"outfit": "👔",
	"back": "🎒",
	"skin": "🎨",
}
const TAB_LABELS: Dictionary = {
	"hair": "Hair",
	"hat": "Hats",
	"outfit": "Outfits",
	"back": "Back",
	"skin": "Skin",
}

func _ready() -> void:
	_load_current_selections()
	_build_category_tabs()
	_populate_grid()
	
	save_button.pressed.connect(_on_save_pressed)
	color_picker_button.color_changed.connect(_on_color_changed)
	_style_save_button()

func _load_current_selections() -> void:
	if FileAccess.file_exists("user://avatar_save.json"):
		var file := FileAccess.open("user://avatar_save.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				current_selections = {
					"hair": parsed.get("hair", "emo_black"),
					"hat": parsed.get("hat", "cap_sb"),
					"outfit": parsed.get("outfit", "collared_tie"),
					"back": parsed.get("back", "skateboard"),
					"skin_color": parsed.get("skin_color", "fbcfe8"),
					"mood": parsed.get("mood", "is happy"),
					"name": parsed.get("name", "Player"),
					"color": parsed.get("color", "0xffffff")
				}
				avatar_preview.init_avatar(current_selections)
				return
				
	# Default fallback
	current_selections = {
		"hair": "emo_black",
		"hat": "cap_sb",
		"outfit": "collared_tie",
		"back": "skateboard",
		"skin_color": "fbcfe8",
		"mood": "is happy",
		"name": "Player",
		"color": "0xffffff"
	}
	avatar_preview.init_avatar(current_selections)

func set_avatar(avatar_node: Node2D) -> void:
	if avatar_node and avatar_node.current_state:
		current_selections = avatar_node.current_state.duplicate()
		avatar_preview.init_avatar(current_selections)

func _build_category_tabs() -> void:
	for child in category_tabs.get_children():
		child.queue_free()

	for cat in CATEGORIES:
		var btn := Button.new()
		btn.name = cat.capitalize() + "Tab"
		btn.text = TAB_ICONS.get(cat, "⭐") + " " + TAB_LABELS.get(cat, cat.capitalize())
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(120, 52)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color.WHITE)

		_apply_tab_style(btn, cat == _current_tab)

		var hover_style := _make_tab_stylebox(Color(0.25, 0.22, 0.38))
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_on_tab_pressed.bind(cat))
		category_tabs.add_child(btn)
		_tab_buttons[cat] = btn

func _on_tab_pressed(category: String) -> void:
	_current_tab = category
	for cat in _tab_buttons:
		_apply_tab_style(_tab_buttons[cat], cat == category)
	
	if category == "skin":
		color_picker_container.visible = true
		var sc = current_selections.get("skin_color", "fbcfe8")
		color_picker_button.color = Color(sc)
	else:
		color_picker_container.visible = false
		
	_populate_grid()

func _apply_tab_style(btn: Button, is_active: bool) -> void:
	if is_active:
		var active_style := _make_tab_stylebox(Color(0.45, 0.2, 0.72))
		active_style.border_width_bottom = 3
		active_style.border_color = Color(0.75, 0.45, 1.0)
		btn.add_theme_stylebox_override("normal", active_style)
		btn.add_theme_color_override("font_color", Color.WHITE)
	else:
		var normal_style := _make_tab_stylebox(Color(0.14, 0.13, 0.22))
		btn.add_theme_stylebox_override("normal", normal_style)
		btn.add_theme_color_override("font_color", Color(0.7, 0.65, 0.85))

func _make_tab_stylebox(bg_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _populate_grid() -> void:
	for child in item_grid.get_children():
		child.queue_free()

	var items: Array = ItemDatabase.get_items(_current_tab)
	for item in items:
		var card := _create_item_card(item)
		item_grid.add_child(card)

func _create_item_card(item: Dictionary) -> PanelContainer:
	var is_equipped: bool = false
	if _current_tab == "skin":
		var sc = current_selections.get("skin_color", "")
		var item_color: Color = item.get("color", Color("fbcfe8"))
		is_equipped = (sc.to_lower() == item_color.to_html(false).to_lower())
	else:
		var equipped_id: String = current_selections.get(_current_tab, "")
		is_equipped = (equipped_id == item["id"])

	var card := PanelContainer.new()
	card.name = "Card_" + item["id"]
	card.custom_minimum_size = Vector2(0, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	if is_equipped:
		style.bg_color = Color(0.4, 0.18, 0.65, 0.7)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.75, 0.45, 1.0, 0.9)
	else:
		style.bg_color = Color(0.16, 0.14, 0.24, 0.85)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
		style.border_color = Color(0.4, 0.3, 0.6, 0.3)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_radius_bottom_right = 14
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	if _current_tab == "skin" and item.has("color"):
		var swatch_container := CenterContainer.new()
		swatch_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch_style := StyleBoxFlat.new()
		swatch_style.bg_color = item["color"]
		swatch_style.corner_radius_top_left = 20
		swatch_style.corner_radius_top_right = 20
		swatch_style.corner_radius_bottom_left = 20
		swatch_style.corner_radius_bottom_right = 20
		swatch_style.border_width_left = 2
		swatch_style.border_width_right = 2
		swatch_style.border_width_top = 2
		swatch_style.border_width_bottom = 2
		swatch_style.border_color = Color(1, 1, 1, 0.4)
		var swatch_panel := Panel.new()
		swatch_panel.custom_minimum_size = Vector2(40, 40)
		swatch_panel.add_theme_stylebox_override("panel", swatch_style)
		swatch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_container.add_child(swatch_panel)
		vbox.add_child(swatch_container)
	else:
		var icon := Label.new()
		icon.text = TAB_ICONS.get(_current_tab, "⭐")
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)

	var name_label := Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE if is_equipped else Color(0.9, 0.85, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	if item.has("desc"):
		var desc_label := Label.new()
		desc_label.text = item["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

	if is_equipped:
		var badge := Label.new()
		badge.text = "✅ Equipped"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge)

	card.gui_input.connect(_on_card_input.bind(item))
	return card

func _on_card_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _current_tab == "skin":
			var color_val = item.get("color", Color("fbcfe8"))
			var hex_str = color_val.to_html(false)
			current_selections["skin_color"] = hex_str
			avatar_preview.update_skin_color(hex_str)
			color_picker_button.color = color_val
		else:
			current_selections[_current_tab] = item["id"]
			avatar_preview.update_part(_current_tab, item["id"])

		emit_signal("item_selected", _current_tab, item["id"])
		_populate_grid()

func _on_color_changed(color: Color) -> void:
	var hex_str = color.to_html(false)
	current_selections["skin_color"] = hex_str
	avatar_preview.update_skin_color(hex_str)
	_populate_grid() # Refresh equipped highlights if preset matches

func _on_save_pressed() -> void:
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(current_selections))
		file_out.close()

	NetworkManager.send_customization_update(current_selections)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _style_save_button() -> void:
	var save_style := StyleBoxFlat.new()
	save_style.bg_color = Color(0.28, 0.73, 0.47)
	save_style.corner_radius_top_left = 14
	save_style.corner_radius_top_right = 14
	save_style.corner_radius_bottom_left = 14
	save_style.corner_radius_bottom_right = 14
	save_style.border_width_left = 2
	save_style.border_width_right = 2
	save_style.border_width_top = 2
	save_style.border_width_bottom = 2
	save_style.border_color = Color(0.4, 0.9, 0.6, 0.8)
	save_button.add_theme_stylebox_override("normal", save_style)

	var hover_style := save_style.duplicate()
	hover_style.bg_color = Color(0.32, 0.8, 0.52)
	save_button.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := save_style.duplicate()
	pressed_style.bg_color = Color(0.22, 0.6, 0.38)
	save_button.add_theme_stylebox_override("pressed", pressed_style)
