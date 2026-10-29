extends SceneTree

func _init() -> void:
	var res := {}
	var seeds := [12345, 0, -1, 0x0C157E2026]
	for s in seeds:
		var r := RandomNumberGenerator.new()
		r.seed = s
		var ri := []
		for i in 8:
			ri.append(r.randi())
		r.seed = s
		var rf := []
		for i in 8:
			rf.append(r.randf())
		r.seed = s
		var rr := []
		for i in 8:
			rr.append(r.randi_range(0, 6))
		r.seed = s
		var r2 := []
		for i in 8:
			r2.append(r.randi_range(0, 2))
		r.seed = s
		var fr := []
		for i in 8:
			fr.append(r.randf_range(-0.5, 0.5))
		res[str(s)] = {"randi": ri, "randf": rf, "randi_range_0_6": rr, "randi_range_0_2": r2, "randf_range": fr}
	print("VECT_RNG " + JSON.stringify(res))
	var hashes := {}
	for w in ["wall", "floor", "gate", "settlement", "gantry", "elevator_down", "elevator_up", "drain_grate", "nest_mark", "rubble", "grass", "soil", "stream_water", "conduit"]:
		hashes[w] = w.hash()
	print("VECT_STRHASH " + JSON.stringify(hashes))
	quit()
