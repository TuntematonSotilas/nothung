class_name CardPalette
extends RefCounted
## Card colours: frame colour = faction, rarity badge colour = rarity, dark gold for the Ring.
## Source of truth: docs/functional/08-art-and-audio.md (faction palette, rarity colours).

const TEXT_LIGHT: Color = Color("#F4EFE4")
const TEXT_DARK: Color = Color("#1C1A17")
## Card background, the same for every card until the illustrations (which will include it) arrive.
## Card text is always TEXT_LIGHT on it; the faction colour is the frame (border).
const BACKGROUND: Color = Color("#16181D")

## faction id → {frame, trim, text}.
const FACTIONS: Dictionary = {
	&"gods": {"frame": Color("#2E4A7D"), "trim": Color("#B8C4D6"), "text": TEXT_LIGHT},
	&"nibelungs": {"frame": Color("#4E3366"), "trim": Color("#2B2930"), "text": TEXT_LIGHT},
	&"walsungs": {"frame": Color("#3B6E3E"), "trim": Color("#B07D4F"), "text": TEXT_LIGHT},
	&"valkyries": {"frame": Color("#E0A0B8"), "trim": Color("#9C4A6E"), "text": TEXT_DARK},
	&"neutral": {"frame": Color("#A39A86"), "trim": Color("#DCCFAE"), "text": TEXT_DARK},
	# Reserved for expansions.
	&"giants": {"frame": Color("#6B5A4C"), "trim": Color("#9C9286"), "text": TEXT_LIGHT},
	&"gibichungs": {"frame": Color("#8A4A24"), "trim": Color("#D8B07A"), "text": TEXT_LIGHT},
}

## The Ring (and Cursed cards) use dark gold whatever their faction.
const RING: Dictionary = {"frame": Color("#7A5A14"), "trim": Color("#C9A33A"), "text": TEXT_LIGHT}

## Rarity badge colours (behind the rarity letter).
const RARITY_COLORS: Dictionary = {
	CardData.Rarity.COMMON: Color("#9A9A9A"),
	CardData.Rarity.RARE: Color("#3A7BD5"),
	CardData.Rarity.EPIC: Color("#8E44AD"),
	CardData.Rarity.LEGENDARY: Color("#E0B33A"),
}


## Frame, trim and text colours for a card ({frame, trim, text}).
static func colors_for(data: CardData) -> Dictionary:
	if data == null:
		return FACTIONS[&"neutral"]
	if data.is_ring:
		return RING
	return FACTIONS.get(data.faction, FACTIONS[&"neutral"])


## Rarity letters: the same in every language (not translated).
const RARITY_LETTERS: Dictionary = {
	CardData.Rarity.COMMON: "C",
	CardData.Rarity.RARE: "R",
	CardData.Rarity.EPIC: "E",
	CardData.Rarity.LEGENDARY: "L",
}


static func rarity_letter(rarity: CardData.Rarity) -> String:
	return RARITY_LETTERS.get(rarity, "C")


static func rarity_color(rarity: CardData.Rarity) -> Color:
	return RARITY_COLORS.get(rarity, RARITY_COLORS[CardData.Rarity.COMMON])


## Light or dark text, whichever reads best on this background.
static func ink_on(background: Color) -> Color:
	return TEXT_DARK if background.get_luminance() > 0.5 else TEXT_LIGHT


## WCAG 2 contrast ratio between two colours (1 to 21).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _relative_luminance(a)
	var lb: float = _relative_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _relative_luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value: float in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
