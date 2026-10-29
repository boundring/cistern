extends SceneTree

func _init() -> void:
	var m := TownMap.dressed(0xC1577EED)
	var rows := []
	for y in m.height:
		var r := ""
		for x in m.width:
			r += m.tile_at(Vector2i(x, y)) + "|"
		rows.append(r)
	print("VECT_TOWN " + JSON.stringify({
		"width": m.width, "height": m.height,
		"rows": rows,
		"spawn": [m.spawn.x, m.spawn.y],
		"entrance": [m.entrance.x, m.entrance.y],
		"well": [m.well.x, m.well.y],
		"shop_doors": [m.shop_doors[0].x, m.shop_doors[0].y, m.shop_doors[1].x, m.shop_doors[1].y, m.shop_doors[2].x, m.shop_doors[2].y, m.shop_doors[3].x, m.shop_doors[3].y, m.shop_doors[4].x, m.shop_doors[4].y, m.shop_doors[5].x, m.shop_doors[5].y],
		"shop_interiors": [m.shop_interiors[0].x, m.shop_interiors[0].y, m.shop_interiors[1].x, m.shop_interiors[1].y, m.shop_interiors[2].x, m.shop_interiors[2].y, m.shop_interiors[3].x, m.shop_interiors[3].y, m.shop_interiors[4].x, m.shop_interiors[4].y, m.shop_interiors[5].x, m.shop_interiors[5].y],
		"shop_names": m.SHOP_NAMES,
		"shop_fixtures": m.SHOP_FIXTURES,
	}))
	quit()
