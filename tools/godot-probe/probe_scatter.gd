extends SceneTree

func _init() -> void:
	var res := {}
	var cells := [[0,0],[1,2],[5,4],[14,9],[17,13],[20,9],[19,4],[11,4],[33,15],[2,7]]
	for fid in [0, 1]:
		var sh := ScatterHash.new(fid)
		var rows := []
		for c in cells:
			rows.append({
				"gx": c[0], "gy": c[1],
				"cell_seed": sh._cell_seed(c[0], c[1]),
				"presence_012": sh.presence(c[0], c[1], 0.12),
				"presence_050": sh.presence(c[0], c[1], 0.5),
				"variant_3": sh.variant(c[0], c[1], 3),
				"jitter": [sh.jitter(c[0], c[1]).x, sh.jitter(c[0], c[1]).y],
			})
		res[str(fid)] = rows
	print("VECT_SCATTER " + JSON.stringify(res))
	quit()
