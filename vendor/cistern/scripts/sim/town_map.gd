class_name TownMap
extends RefCounted
## The starter town: a hand-authored 34x16 char-map template, parsed
## fail-fast into wire tile names (worldgen-design §3; ported from the
## archived crates/cistern-procgen/src/town.rs — the LAYOUT CONSTANTS, not
## the Rust code).
##
## Wave-2 depth: each shop carries one interior fixture tile and the plaza
## carries one landmark, all inside the frozen 14-id vocabulary (no new ids);
## shop names follow hengband order.
##
## The template is **data, not RNG output**. The seed enters in exactly two
## quarantined places (§3.4): template selection (one keyed draw) and FLAVOR
## dressing (cosmetic plaza grass off the flavor sub-key). The replay-relevant
## machinery streams are never drawn — quarantine-safe by construction.

## The starter town (worldgen-design §3.2, verbatim): 16 rows x 34 cols.
## Shops 1-6 are hengband order (General, Armoury, Weapon Smiths, Bookseller,
## Alchemy, Home); `@` is the player start; `>` in the north cliff is the
## dungeon entrance; `o` is the well; `~` runs down the west side. Wave-2
## markers: `=` gantry stock (shop 1), `~` quench trough (shop 3), `D` drain
## grate (shop 5), `C` conduit light-line (shop 2), `Y` nest mark (shop 4),
## `<` back stair (shop 6), `A` plaza monument — once-only like `@`/`>`,
## except `~`, shared with the west stream.
const STARTER_TOWN_ROWS: Array = [
	"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
	"X\"\"\"########XXXXXXXXXXXXXXXX#####X",
	"X\"\"\"#>#X....................X##\"\"X",
	"X\"\"\"BBBB\"\"BBBB\"\"\"\"BBBB\"\"\"\"\"\"\"\"\"\"\"X",
	"X\"\"\"B=.B\"\"B~.B\"\"\"\"BD.B\"\"\"\"\"\"\"\"\"\"\"X",
	"X\"\"\"B1BB\"\"B3BB\"\"\"\"B5BB\"\"\"\"\"\"\"\"\"\"\"X",
	"X\"\"\".....o...................\"\"\"\"X",
	"X~~,,...,,....................,\"\"X",
	"X~~,,...,,....BBBB\"\"BBBB......,\"\"X",
	"X\"\"\"...,,....BC.B\"\"BY.B.......,\"\"X",
	"X\"\"\"...,,....B2BB\"\"B4BB.A.....,\"\"X",
	"X\"\"\"..,,......@.....,,........,\"\"X",
	"X\"\"\"..,,........B6BB..........,\"\"X",
	"X\"\"\"..,,........B<.B..........,\"\"X",
	"X\"\"\"..,,........BBBB..........,\"\"X",
	"XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
]

## Registered templates. Selection is a keyed draw modulo the count (§3.4);
## with one template the draw still happens so the choice stays a pinned
## function of the seed when a second template lands.
const TEMPLATES: Array = [STARTER_TOWN_ROWS]

## Template-selection sub-key, worldgen-design §3.4 literal `(1 << 8) | 2`.
const TEMPLATE_SELECT_KEY: int = (1 << 8) | 2

## FLAVOR dressing sub-key: stream 6 (FLAVOR), town role 2 — mirrors the
## archived `(coarse << 8) | role` shape (dump.rs, spec-05 §5).
const TOWN_FLAVOR_KEY: int = (6 << 8) | 2

const TEMPLATE_COLS: int = 34
const TEMPLATE_ROWS: int = 16

## Glyph -> wire tile name (§3.3). `@`, `>`, `o` and digits carry markers on
## top of their tile; `parse` handles those, everything else is pure tile
## identity. Names match the frozen 14-id wire vocabulary the view consumes.
const GLYPH_TILES: Dictionary = {
	"X": "wall", "B": "wall",
	".": "floor", "@": "floor",
	",": "rubble",
	"\"": "grass",
	"~": "stream_water",
	"#": "soil",
	">": "elevator_down",
	"o": "settlement",
	"=": "gantry",
	"C": "conduit",
	"Y": "nest_mark",
	"D": "drain_grate",
	"<": "elevator_up",
	"A": "settlement",
	"1": "gate", "2": "gate", "3": "gate",
	"4": "gate", "5": "gate", "6": "gate",
}

## Shop display names, hengband order; id is 1-based to match shop_doors.
const SHOP_NAMES: Array[String] = ["General Store", "Armoury", "Weapon Smiths", "Bookseller", "Alchemy", "Home"]

## Each shop's interior fixture tile (index id-1) and the plaza landmark —
## documentation over tiles that already live in the grid, so sim/view can
## ask without re-deriving.
const SHOP_FIXTURES: Array[String] = ["gantry", "conduit", "stream_water", "nest_mark", "drain_grate", "elevator_up"]
const PLAZA_LANDMARK: String = "settlement"

## Authored shop-interior cells (VALIDATED MAP DATA, not derived): one cell
## per shop id, index id-1, hand-checked against the template above. `parse`
## fail-fasts on any drift (fixture tile, door adjacency, distinctness), so
## a future template edit fails loudly instead of silently stranding a shop.
const SHOP_INTERIOR_CELLS: Array[Vector2i] = [
	Vector2i(5, 4), Vector2i(14, 9), Vector2i(11, 4),
	Vector2i(20, 9), Vector2i(19, 4), Vector2i(17, 13),
]

var width: int = 0
var height: int = 0
## Row-major `y * width + x`, wire tile names.
var tiles: PackedStringArray = PackedStringArray()
## The `@` cell (player start; itself floor).
var spawn: Vector2i = Vector2i(-1, -1)
## The `>` cell (dungeon entrance).
var entrance: Vector2i = Vector2i(-1, -1)
## The `o` well cell.
var well: Vector2i = Vector2i(-1, -1)
## Shop door cells; shop id n lives at index n-1. Shop identity is metadata —
## every door is the shared `gate` tile, so the wire vocabulary stays frozen.
var shop_doors: Array[Vector2i] = []
## The authored interior cells (copied from SHOP_INTERIOR_CELLS at parse);
## sim/view ask `shop_at_interior` instead of re-deriving from tiles.
var shop_interiors: Array[Vector2i] = []


func tile_at(c: Vector2i) -> String:
	return tiles[c.y * width + c.x]


func shop_name(id: int) -> String:
	return SHOP_NAMES[id - 1]


## Shop id 1..=6 for a counter cell, 0 when the cell hosts no shop interior.
## Pure table lookup — no direction assumptions (shop 6's interior is south
## of its door, shops 1-5 north).
func shop_at_interior(c: Vector2i) -> int:
	for i in shop_interiors.size():
		if shop_interiors[i] == c:
			return i + 1
	return 0


func set_tile(c: Vector2i, tile: String) -> void:
	tiles[c.y * width + c.x] = tile


static func template_text(choice: int) -> PackedStringArray:
	return PackedStringArray(TEMPLATES[choice])


## The bare starter town, undressed (marker and gate checks).
static func starter_town() -> TownMap:
	return parse(template_text(0))


## Fail-fast parse: exact 34x16 dims, known glyphs only, digits 1-6 once
## each, exactly one `@`, exactly one `>`, the well present. Never a
## fallback — a broken registry is a build bug. Returns null on any fault.
static func parse(rows: PackedStringArray) -> TownMap:
	if rows.size() != TEMPLATE_ROWS:
		push_error("town template: expected %d rows, got %d" % [TEMPLATE_ROWS, rows.size()])
		return null
	for y in rows.size():
		if rows[y].length() != TEMPLATE_COLS:
			push_error("town template row %d: expected %d cols, got %d"
				% [y, TEMPLATE_COLS, rows[y].length()])
			return null
	var m := TownMap.new()
	m.width = TEMPLATE_COLS
	m.height = TEMPLATE_ROWS
	m.tiles.resize(TEMPLATE_COLS * TEMPLATE_ROWS)
	m.shop_doors.resize(6)
	for i in 6:
		m.shop_doors[i] = Vector2i(-1, -1)
	var seen_shops: Dictionary = {}
	var seen_fixtures: Dictionary = {}
	for y in rows.size():
		for x in rows[y].length():
			var glyph: String = rows[y][x]
			if not GLYPH_TILES.has(glyph):
				push_error("town template at %d,%d: unknown glyph '%s'" % [x, y, glyph])
				return null
			m.tiles[y * TEMPLATE_COLS + x] = GLYPH_TILES[glyph]
			var c := Vector2i(x, y)
			match glyph:
				"=", "C", "Y", "D", "<", "A":
					if seen_fixtures.has(glyph):
						push_error("town template at %d,%d: '%s' appears twice" % [x, y, glyph])
						return null
					seen_fixtures[glyph] = true
				"@":
					if m.spawn.x >= 0:
						push_error("town template at %d,%d: '@' player start appears twice" % [x, y])
						return null
					m.spawn = c
				">":
					if m.entrance.x >= 0:
						push_error("town template at %d,%d: '>' entrance appears twice" % [x, y])
						return null
					m.entrance = c
				"o":
					if m.well.x >= 0:
						push_error("town template at %d,%d: 'o' well appears twice" % [x, y])
						return null
					m.well = c
				"1", "2", "3", "4", "5", "6":
					if seen_shops.has(glyph):
						push_error("town template at %d,%d: shop '%s' appears twice" % [x, y, glyph])
						return null
					seen_shops[glyph] = true
					m.shop_doors[glyph.to_int() - 1] = c
	if m.spawn.x < 0:
		push_error("town template: no '@' player start")
		return null
	if m.entrance.x < 0:
		push_error("town template: no '>' dungeon entrance")
		return null
	if m.well.x < 0:
		push_error("town template: no 'o' well")
		return null
	for id in range(1, 7):
		if m.shop_doors[id - 1].x < 0:
			push_error("town template: shop '%d' missing" % id)
			return null
	for glyph in ["=", "C", "Y", "D", "<", "A"]:
		if not seen_fixtures.has(glyph):
			push_error("town template: fixture glyph '%s' missing" % glyph)
			return null
	m.shop_interiors.assign(SHOP_INTERIOR_CELLS)
	for id in range(1, 7):
		var c := SHOP_INTERIOR_CELLS[id - 1]
		if c.x < 0 or c.y < 0 or c.x >= m.width or c.y >= m.height:
			push_error("town template: shop %d interior %d,%d is off-map" % [id, c.x, c.y])
			return null
		if m.tile_at(c) != SHOP_FIXTURES[id - 1]:
			push_error("town template: shop %d interior %d,%d does not carry its fixture '%s'"
				% [id, c.x, c.y, SHOP_FIXTURES[id - 1]])
			return null
		for j in range(id + 1, 7):
			if SHOP_INTERIOR_CELLS[j - 1] == c:
				push_error("town template: shops %d and %d share interior %d,%d"
					% [id, j, c.x, c.y])
				return null
		var door: Vector2i = m.shop_doors[id - 1]
		if absi(c.x - door.x) + absi(c.y - door.y) != 1:
			push_error("town template: shop %d interior %d,%d not adjacent to its door %d,%d"
				% [id, c.x, c.y, door.x, door.y])
			return null
	return m


## The keyed template choice (§3.4): a pure function of the seed off its own
## sub-key — never a machinery-stream draw.
static func template_choice(seed: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = keyed(seed, TEMPLATE_SELECT_KEY)
	return rng.randi_range(0, TEMPLATES.size() - 1)


## The starter surface for `seed`: the town template, FLAVOR-dressed. Port of
## the archived `starter_level` up to tile identity (Level/Spawn plumbing is
## Rust-estate structure the spike does not carry).
static func dressed(seed: int) -> TownMap:
	var m := parse(template_text(template_choice(seed)))
	if m == null:
		return null # parse already push_error'd: registry is a build bug
	_dress(m, seed)
	return m


## Keyed sub-key derivation: seed mixed with the sub-key (the archived
## RngStream::keyed role; the spike pins its own mix, documented here).
static func keyed(seed: int, key: int) -> int:
	return (seed ^ (key * 0x6A09E667F3BCC909)) & 0x7FFFFFFFFFFFFFFF


## FLAVOR dressing (§3.4): cosmetic grass tufts on open-plaza floor cells —
## a cell qualifies only when it and all 8 neighbours are plain floor, so
## streets, doorways, the spawn, the well and the entrance are untouchable.
## Grass is walkable and sky-open like floor, so dressing never changes sim
## reachability. One row-major pass, draws only from the FLAVOR sub-key.
static func _dress(m: TownMap, seed: int) -> void:
	var flavor := RandomNumberGenerator.new()
	flavor.seed = keyed(seed, TOWN_FLAVOR_KEY)
	for y in m.height:
		for x in m.width:
			var c := Vector2i(x, y)
			if c == m.spawn or m.tile_at(c) != "floor":
				continue
			if not _open_plaza(m, c):
				continue
			if flavor.randi_range(0, 6) == 0:
				m.set_tile(c, "grass")


static func _open_plaza(m: TownMap, c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x < 0 or n.y < 0 or n.x >= m.width or n.y >= m.height:
				return false
			if m.tile_at(n) != "floor":
				return false
	return true
