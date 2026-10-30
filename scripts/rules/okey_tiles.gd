class_name OkeyTiles
## The 106-tile okey set as pure data. A tile id (0..105) names one physical tile; its value is
## Vector2i(color, number) like TileFactory (colors 0-3, numbers 1-13; color 4 number 0 is a sahte okey).
## The okey (joker) is the tile after the gösterge in its colour (13 -> 1). The two real okey tiles are jokers;
## a sahte okey plays as the okey's own value.

const COUNT := 106
const FAKE := Vector2i(TileFactory.FAKE_OKEY, 0)


static func value(id: int) -> Vector2i:
	if id >= 104:
		return FAKE
	return Vector2i((id % 52) / 13, id % 13 + 1)


static func okey_of(indicator: Vector2i) -> Vector2i:
	return Vector2i(indicator.x, indicator.y % TileFactory.NUMBERS + 1)


static func is_joker(id: int, okey: Vector2i) -> bool:
	return value(id) == okey


## The value a tile plays as when it is not a joker (a sahte okey becomes the okey's value).
static func plays_as(id: int, okey: Vector2i) -> Vector2i:
	var v := value(id)
	return okey if v == FAKE else v


## Penalty points of a tile left in the rack at the end of a hand.
static func rack_points(id: int, okey: Vector2i, okey_value: int) -> int:
	return okey_value if is_joker(id, okey) else plays_as(id, okey).y


static func colour_name(color: int) -> String:
	return ["Kırmızı", "Siyah", "Mavi", "Sarı", "Sahte okey"][color]


static func name(id: int) -> String:
	var v := value(id)
	return "Sahte okey" if v == FAKE else "%s %d" % [colour_name(v.x), v.y]
