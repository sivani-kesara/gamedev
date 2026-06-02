## CustomizerUI — Mobile-friendly wardrobe panel for avatar customization.
## Builds the entire UI tree programmatically for maximum flexibility.
## Occupies the bottom ~55% of the viewport with a dark translucent panel,
## category tabs, and a scrollable item grid.
extends CanvasLayer

## Emitted when the player taps an item. Main scene uses this for auto-save.
signal item_selected(category: String, item_id: String)

## Reference to the Avatar node, set by Main.gd after scene ready.
var avatar: Node2D = null

## Currently active category tab.
var _current_tab: String = "hair"

## Grid container holding item cards (populated dynamically).
var _item_grid: GridContainer

## Map of category name → tab Button node (for highlight management).
var _tab_buttons: Dictionary = {}

## Emoji icons per category for visual flair on tab buttons.
const TAB_ICONS: Dictionary = {
	"hair": "💇",
	"hat": "🎩",
	"outfit": "👔",
	"back": "🎒",
	"skin": "🎨",
}

## Full display names for tab buttons.
const TAB_LABELS: Dictionary = {
	"hair": "Hair",
	"hat": "Hats",
	"outfit": "Outfits",
	"back": "Back",
	"skin": "Skin",
}

## Category ordering.
const CATEGORIES: Array = ["hair", "hat", "outfit", "back", "skin"]


func _ready() -> void:
	_build_ui()
	_populate_grid()


## Sets the avatar reference. Call this from Main after all nodes are ready.
func set_avatar(avatar_node: Node2D) -> void:
	avatar = avatar_node


# ═══════════════════════════════════════════════════════════════════
# UI Construction
# ═══════════════════════════════════════════════════════════════════

func _build_ui() -> void:
	# --- Root Panel anchored to bottom 55% of screen ---
	var panel := PanelContainer.new()
	panel.name = "RootPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.45
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.05, 0.12, 0.96)
	panel_style.corner_radius_top_left = 28
	panel_style.corner_radius_top_right = 28
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	panel_style.content_margin_left = 16
	panel_style.content_margin_right = 16
	panel_style.content_margin_top = 20
	panel_style.content_margin_bottom = 16
	# Subtle top border glow
	panel_style.border_width_top = 2
	panel_style.border_color = Color(0.6, 0.35, 1.0, 0.5)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# --- Vertical layout inside panel ---
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# --- Title label ---
	var title := Label.new()
	title.text = "✨ WARDROBE ✨"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 1.0))
	vbox.add_child(title)

	# --- Category tab buttons ---
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.name = "CategoryTabs"
	tabs_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(tabs_hbox)

	for cat in CATEGORIES:
		var btn := Button.new()
		btn.name = cat.capitalize() + "Tab"
		btn.text = TAB_ICONS.get(cat, "⭐") + " " + TAB_LABELS.get(cat, cat.capitalize())
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 52)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color.WHITE)

		# Normal style
		_apply_tab_style(btn, false)

		# Hover style
		var hover_style := _make_tab_stylebox(Color(0.25, 0.22, 0.38))
		btn.add_theme_stylebox_override("hover", hover_style)

		# Focus style (for accessibility)
		var focus_style := _make_tab_stylebox(Color(0.3, 0.25, 0.5))
		btn.add_theme_stylebox_override("focus", focus_style)

		btn.pressed.connect(_on_tab_pressed.bind(cat))
		tabs_hbox.add_child(btn)
		_tab_buttons[cat] = btn

	# Highlight default tab
	_apply_tab_style(_tab_buttons["hair"], true)

	# --- Decorative separator ---
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.5, 0.3, 0.8, 0.3)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(sep)

	# --- Scrollable item grid ---
	var scroll := ScrollContainer.new()
	scroll.name = "ItemScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_item_grid = GridContainer.new()
	_item_grid.name = "ItemGrid"
	_item_grid.columns = 2
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.add_theme_constant_override("h_separation", 12)
	_item_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_item_grid)


# ═══════════════════════════════════════════════════════════════════
# Tab Management
# ═══════════════════════════════════════════════════════════════════

func _on_tab_pressed(category: String) -> void:
	_current_tab = category
	# Update all tab highlights
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
	for child in _item_grid.get_children():
		child.queue_free()

	var items: Array = ItemDatabase.get_items(_current_tab)
	for item in items:
		var card := _create_item_card(item)
		_item_grid.add_child(card)


func _create_item_card(item: Dictionary) -> PanelContainer:
	# Determine if this item is currently equipped
	var is_equipped := false
	if avatar:
		if _current_tab == "skin":
			is_equipped = avatar.current_state.get("skin", "") == item["id"]
		else:
			is_equipped = avatar.current_state.get(_current_tab, "") == item["id"]

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
		var swatch := ColorRect.new()
		swatch.color = item["color"]
		swatch.custom_minimum_size = Vector2(40, 40)
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Apply rounded style
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
		# Use a Panel instead of ColorRect for rounded corners
		var swatch_panel := Panel.new()
		swatch_panel.custom_minimum_size = Vector2(40, 40)
		swatch_panel.add_theme_stylebox_override("panel", swatch_style)
		swatch_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch_container.add_child(swatch_panel)
		vbox.add_child(swatch_container)
	else:
		# Star icon for non-skin items
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
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE if is_equipped else Color(0.9, 0.85, 1.0))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	# Item description
	if item.has("desc"):
		var desc_label := Label.new()
		desc_label.text = item["desc"]
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.add_theme_font_size_override("font_size", 11)
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
		if avatar:
			avatar.equip_item(_current_tab, item["id"])
		emit_signal("item_selected", _current_tab, item["id"])
		# Rebuild grid to refresh highlight states
		_populate_grid()
