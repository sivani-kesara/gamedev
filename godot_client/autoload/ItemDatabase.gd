## ItemDatabase — Global singleton (Autoload) containing all avatar customization items.
## Ported from the Phaser.js CUSTOM_ITEMS dictionary in game.js.
extends Node

var items: Dictionary = {}


func _ready() -> void:
	items = {
		"hair": [
			{"id": "none", "name": "No Hair", "color": Color("000000"), "desc": "Sleek & Bald"},
			{"id": "emo_black", "name": "Emo Fringe", "color": Color("1e293b"), "desc": "Sweeping black locks"},
			{"id": "wavy_gold", "name": "Golden Curls", "color": Color("eab308"), "desc": "Flowing wavy blonde hair"},
			{"id": "punk_pink", "name": "Punk Spikes", "color": Color("ec4899"), "desc": "Bright spiky pink hair"},
			{"id": "cozy_brown", "name": "Cozy Cut", "color": Color("78350f"), "desc": "Soft brown casual hair"},
		],
		"hat": [
			{"id": "none", "name": "No Hat", "desc": "Keep it simple"},
			{"id": "cap_sb", "name": "SB Flatcap", "desc": "Signature grey SB cap"},
			{"id": "newsboy", "name": "Newsboy Cap", "desc": "Textured grey cap"},
			{"id": "wizard", "name": "Wizard Hat", "desc": "Magical purple hat"},
			{"id": "crown", "name": "Royal Crown", "desc": "Shiny gold with ruby gems"},
		],
		"outfit": [
			{"id": "none", "name": "Simple Suit", "desc": "Casual look"},
			{"id": "collared_tie", "name": "Collared Shirt & Tie", "desc": "Fancy school/office look"},
			{"id": "wedding_gown", "name": "Bridal Gown", "desc": "Elegant white dress with a rose"},
			{"id": "green_hoodie", "name": "Green Hoodie", "desc": "Comfy gamer attire"},
			{"id": "cool_jacket", "name": "Leather Jacket", "desc": "Rockstar black biker jacket"},
		],
		"back": [
			{"id": "none", "name": "No Item", "desc": "Travel light"},
			{"id": "skateboard", "name": "Red Skateboard", "desc": "Cool ride carried on back"},
			{"id": "wings", "name": "Angel Wings", "desc": "Soft glowing white wings"},
			{"id": "wand", "name": "Magic Wand", "desc": "Holds a sparkly gold wand"},
		],
		"skin": [
			{"id": "default", "name": "Peach Skin", "color": Color("fbcfe8"), "desc": "Classic peach tone"},
			{"id": "sky", "name": "Sky Blue", "color": Color("bae6fd"), "desc": "Cool blue skin"},
			{"id": "lavender", "name": "Lavender", "color": Color("c7d2fe"), "desc": "Soft purple glow"},
			{"id": "gold", "name": "Golden Glow", "color": Color("fef08a"), "desc": "Radiant gold skin"},
		],
	}


## Returns the list of items for a given category (hair, hat, outfit, back, skin).
func get_items(category: String) -> Array:
	return items.get(category, [])


## Finds a specific item by its category and ID. Returns empty dict if not found.
func get_item_by_id(category: String, item_id: String) -> Dictionary:
	for item in items.get(category, []):
		if item["id"] == item_id:
			return item
	return {}


## Returns the default avatar profile dictionary used when no save data exists.
func get_default_profile() -> Dictionary:
	return {
		"hair": "emo_black",
		"hat": "cap_sb",
		"outfit": "collared_tie",
		"back": "skateboard",
		"skin": "default",
		"skin_color": Color("fbcfe8"),
		"mood": "is happy",
	}
