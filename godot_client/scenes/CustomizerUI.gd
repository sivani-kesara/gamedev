## CustomizerUI — Mobile-friendly wardrobe panel for avatar customization.
## Uses a declarative .tscn layout with category tabs, scrollable item grid,
## live avatar preview, and a Save Looks button that persists to the server.
extends Control


## Emitted when the player taps an item. Main scene uses this for real-time sync.
signal item_selected(category: String, item_id: String)

## Reference to the live Avatar preview node inside PreviewContainer.
@onready var avatar_preview: Node2D = $PreviewContainer/AvatarPreview

## UI node references.
@onready var category_tabs: HBoxContainer = $WardrobePanel/VBox/CategoryScroll/CategoryTabs
@onready var item_grid: GridContainer = $WardrobePanel/VBox/ItemScroll/ItemGrid
@onready var save_button: Button = $WardrobePanel/VBox/ActionButtons/SaveButton

## Currently active category tab.
var _current_tab: String = "hair"

## Tracks the user's temporary selections before saving.
var current_selections: Dictionary = {}

## Tab button references for highlight management.
var _tab_buttons: Dictionary = {}

## Category ordering and display metadata.
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
	# Initialize current_selections from the avatar's current state
	_load_current_selections()
	# Build category tab buttons dynamically
	_build_category_tabs()
	# Populate the default tab's item grid
	_populate_grid()
	# Wire the save button
	save_button.pressed.connect(_on_save_pressed)
	# Style the save button
	_style_save_button()


# ═══════════════════════════════════════════════════════════════════
# Initialization
# ═══════════════════════════════════════════════════════════════════

## Loads current selections from the avatar preview or from saved local file.
func _load_current_selections() -> void:
	if FileAccess.file_exists("user://avatar_save.json"):
		var file := FileAccess.open("user://avatar_save.json", FileAccess.READ)
		if file:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				current_selections = {
					"hair": parsed.get("hair", parsed.get("h", "emo_black")),
					"hat": parsed.get("hat", parsed.get("t", "cap_sb")),
					"outfit": parsed.get("outfit", parsed.get("o", "collared_tie")),
					"back": parsed.get("back", parsed.get("b", "skateboard")),
					"skin": parsed.get("skin", parsed.get("s", "default")),
					"mood": parsed.get("mood", parsed.get("m", "is happy")),
				}
				if parsed.has("name"):
					current_selections["name"] = parsed["name"]
				if parsed.has("color"):
					current_selections["color"] = parsed["color"]
				# Apply to the preview avatar
				avatar_preview.init_avatar(current_selections)
				return
	# Fallback defaults
	current_selections = {
		"hair": "emo_black",
		"hat": "cap_sb",
		"outfit": "collared_tie",
		"back": "skateboard",
		"skin": "default",
		"mood": "is happy",
	}
	avatar_preview.init_avatar(current_selections)


## Allows Main.gd to inject an existing avatar reference if needed.
func set_avatar(avatar_node: Node2D) -> void:
	# In the old architecture this pointed to the world avatar.
	# Now we use our own embedded preview, but sync state from the passed avatar.
	if avatar_node and avatar_node.current_state:
		current_selections = avatar_node.current_state.duplicate()
		avatar_preview.init_avatar(current_selections)


# ═══════════════════════════════════════════════════════════════════
# Category Tab Construction
# ═══════════════════════════════════════════════════════════════════

func _build_category_tabs() -> void:
	# Clear any existing tabs
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

		# Hover style
		var hover_style := _make_tab_stylebox(Color(0.25, 0.22, 0.38))
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_on_tab_pressed.bind(cat))
		category_tabs.add_child(btn)
		_tab_buttons[cat] = btn


func _on_tab_pressed(category: String) -> void:
	_current_tab = category
	for cat in _tab_buttons:
		_apply_tab_style(_tab_buttons[cat], cat == category)
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


# ═══════════════════════════════════════════════════════════════════
# Item Grid Population
# ═══════════════════════════════════════════════════════════════════

func _populate_grid() -> void:
	# Clear existing cards
	for child in item_grid.get_children():
		child.queue_free()

	var items: Array = ItemDatabase.get_items(_current_tab)
	for item in items:
		var card := _create_item_card(item)
		item_grid.add_child(card)


func _create_item_card(item: Dictionary) -> PanelContainer:
	# Determine if this item is currently equipped
	var is_equipped: bool = false
	var equipped_id: String = current_selections.get(_current_tab, "")
	is_equipped = equipped_id == item["id"]

	var card := PanelContainer.new()
	card.name = "Card_" + item["id"]
	card.custom_minimum_size = Vector2(0, 110)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# Card background style
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

	# Content layout
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	# Preview element
	if _current_tab == "skin" and item.has("color"):
		# Colored circle swatch for skin items
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
		# Emoji icon
		var icon := Label.new()
		icon.text = TAB_ICONS.get(_current_tab, "⭐")
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.add_theme_font_size_override("font_size", 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(icon)

	# Item name
	var name_label := Label.new()
	name_label.text = item.get("name", "Unknown")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color.WHITE if is_equipped else Color(0.9, 0.85, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Item description
	if item.has("desc"):
		var desc_label := Label.new()
		desc_label.text = item["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 10)
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.75))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)

	# Equipped badge
	if is_equipped:
		var badge := Label.new()
		badge.text = "✅ Equipped"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(badge)

	# Handle tap/click input
	card.gui_input.connect(_on_card_input.bind(item))

	return card


func _on_card_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Update current selections
		current_selections[_current_tab] = item["id"]

		# Update the live avatar preview
		if _current_tab == "skin":
			avatar_preview.update_part("skin", item["id"])
		else:
			avatar_preview.update_part(_current_tab, item["id"])

		emit_signal("item_selected", _current_tab, item["id"])

		# Rebuild grid to refresh highlight states
		_populate_grid()


# ═══════════════════════════════════════════════════════════════════
# Save & Sync
# ═══════════════════════════════════════════════════════════════════

func _on_save_pressed() -> void:
	# Persist selections locally
	var file_out := FileAccess.open("user://avatar_save.json", FileAccess.WRITE)
	if file_out:
		file_out.store_string(JSON.stringify(current_selections))
		file_out.close()

	# Push to server via NetworkManager
	NetworkManager.send_customization_update(current_selections)

	# Transition to the main world
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


# ═══════════════════════════════════════════════════════════════════
# Save Button Styling
# ═══════════════════════════════════════════════════════════════════

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
