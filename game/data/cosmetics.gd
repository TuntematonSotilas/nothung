class_name Cosmetics
extends RefCounted

## Backgrounds bought in Nibelheim (docs/functional/06-progression.md#cosmetics): home backgrounds
## (main menu, chosen in Settings) and boards (the player's play area in a match, chosen per deck in
## My decks). Each one is offered from a player level, for Rhinegold. Owned IDs are kept in
## profile["cosmetics"], the home background in profile["home_background"] and a deck's board in its
## entry ("board"); "" is the default. Cosmetic IDs are persisted, so keep them stable when their
## displayed names or artwork change.

const HOME: String = "home"
const BOARD: String = "board"
## id, kind, player level from which it can be bought, Rhinegold. Order = order in Nibelheim.
const LIST: Array[Dictionary] = [
	{"id": "home_rhine_depths", "kind": HOME, "level": 5, "price": 150},
	{"id": "board_valhalla", "kind": BOARD, "level": 10, "price": 200},
	{"id": "home_nibelheim", "kind": HOME, "level": 15, "price": 300},
	{"id": "board_valkyrie_rock", "kind": BOARD, "level": 20, "price": 400},
	{"id": "home_valhalla_burning", "kind": HOME, "level": 25, "price": 500},
	{"id": "board_ring", "kind": BOARD, "level": 30, "price": 600},
]


static func find(cosmetic_id: String) -> Dictionary:
	for cosmetic: Dictionary in LIST:
		if cosmetic["id"] == cosmetic_id:
			return cosmetic
	return {}


## The picture of a background (null for "" or an unknown ID).
static func texture(cosmetic_id: String) -> Texture2D:
	var cosmetic: Dictionary = find(cosmetic_id)
	if cosmetic.is_empty():
		return null
	var folder: String = "backgrounds" if cosmetic["kind"] == HOME else "boards"
	var path: String = "res://assets/art/%s/%s.png" % [folder, cosmetic_id]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


static func name_key(cosmetic_id: String) -> String:
	return "COSMETIC_%s_NAME" % cosmetic_id.to_upper()


static func is_owned(cosmetic_id: String) -> bool:
	return (SaveManager.profile.get("cosmetics", []) as Array).has(cosmetic_id)


## Owned backgrounds of a kind, in LIST order.
static func owned(kind: String) -> Array[String]:
	var ids: Array[String] = []
	for cosmetic: Dictionary in LIST:
		if cosmetic["kind"] == kind and is_owned(cosmetic["id"]):
			ids.append(cosmetic["id"])
	return ids


## What is still missing to buy it: {"level": level needed (0 when reached), "rhinegold": short}.
static func missing(cosmetic_id: String) -> Dictionary:
	var cosmetic: Dictionary = find(cosmetic_id)
	return {
		"level": int(cosmetic["level"]) if PlayerLevel.level() < int(cosmetic["level"]) else 0,
		"rhinegold": maxi(0, int(cosmetic["price"]) - SaveManager.rhinegold()),
	}


static func can_buy(cosmetic_id: String) -> bool:
	if find(cosmetic_id).is_empty() or is_owned(cosmetic_id):
		return false
	var short: Dictionary = missing(cosmetic_id)
	return int(short["level"]) == 0 and int(short["rhinegold"]) == 0


## Spends its price and keeps it; false (nothing spent) when it cannot be bought yet.
static func buy(cosmetic_id: String) -> bool:
	if not can_buy(cosmetic_id):
		return false
	(SaveManager.profile["cosmetics"] as Array).append(cosmetic_id)
	# add_rhinegold saves the profile (with the background) and tells the screens.
	SaveManager.add_rhinegold(-int(find(cosmetic_id)["price"]))
	return true


## The home background in use ("" = default, or one no longer owned).
static func home_background() -> String:
	var chosen: String = str(SaveManager.profile.get("home_background", ""))
	return chosen if is_owned(chosen) else ""


static func set_home_background(cosmetic_id: String) -> bool:
	if not cosmetic_id.is_empty() and (not is_owned(cosmetic_id) or find(cosmetic_id)["kind"] != HOME):
		return false
	SaveManager.profile["home_background"] = cosmetic_id
	SaveManager.save_profile()
	return true


## The board of a deck entry ("" = default, or one no longer owned).
static func board_of(entry: Dictionary) -> String:
	var chosen: String = str(entry.get("board", ""))
	return chosen if is_owned(chosen) else ""


static func set_board(entry: Dictionary, cosmetic_id: String) -> bool:
	if not cosmetic_id.is_empty() and (not is_owned(cosmetic_id) or find(cosmetic_id)["kind"] != BOARD):
		return false
	entry["board"] = cosmetic_id
	SaveManager.update_deck(entry)
	return true


## A background picture filling `parent`'s rect behind its content, covering it (cropped to fit).
static func backdrop(texture_value: Texture2D, dim: float = 0.0) -> TextureRect:
	var picture := TextureRect.new()
	picture.name = "Backdrop"
	picture.texture = texture_value
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.modulate = Color(1.0 - dim, 1.0 - dim, 1.0 - dim)
	return picture
