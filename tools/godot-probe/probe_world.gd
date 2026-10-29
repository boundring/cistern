extends SceneTree
## Open-world relief golden probe (v3): the DONOR law with the web's two
## documented trims -- no engineered corridors, village disc relocated to
## (34, 16) -- over the web's 68x32 playable grid. This is the exact
## function src/core/world.ts must reproduce; the web-only extensions
## (ocean band, desert classification) deliberately do NOT appear here --
## the golden pins the donor law, like for like.
##
## Regenerate (deliberately, never casually):
##   build a scratch Godot project (donor repo stays read-only):
##     <scratch>/project.godot          -- config_version=5, app name "probe"
##     <scratch>/scripts/view/          -- tile_table.gd scatter_hash.gd
##                                         hd2d_heightmap.gd
##                                         world_heightmap.gd slab_def.gd
##                                         prefab_factory.gd slab_assembler.gd
##     <scratch>/scripts/world/         -- world_level.gd
##     <scratch>/probe_world.gd         -- this file
##   (eight .gd files total: the full closure -- world_level.gd names
##   PrefabFactory, which names SlabAssembler; every class resolves via
##   class_name; nothing reads content/.)
##   then let Godot build the class cache and run the probe:
##     godot --headless --path <scratch> --import
##   godot --headless --path <scratch> -s probe_world.gd \
##     > tests/golden/world.txt

const WORLD_W := 68
const WORLD_H := 32
const SUB := 8


## The web build has no roads: keep the corridor grid sized and zeroed
## (the parent's version resizes and fills 0.0 before its corridor loop --
## replicate that and skip the loop, so _corridor_bilinear stays in range)
## and kill the analytic corridor damping the uplift reads.
class TrimWorld extends WorldHeightmap:
	func _build_corridors() -> void:
		var fw := playable_w + margin_x * 2
		var fh := playable_h + margin_z * 2
		_cell_w.resize(fw * fh)
		_cell_h.resize(fw * fh)
		_cell_t.resize(fw * fh)
		_cell_w.fill(0.0)
		_cell_h.fill(0.0)
		_cell_t.fill(0.0)

	func _corridor_damp(_fx: float, _fz: float) -> float:
		return 0.0


func _init() -> void:
	var w := TrimWorld.new(WORLD_W, WORLD_H)
	# Trim 2: the village disc sits under the town (the donor keeps the
	# 96x96 demo's plaza at (44.5, 58.5)).
	w.village_center = Vector2(34, 16)
	w._village_base_h = maxf(w._macro_steps(34.0, 16.0), w.TABLE_STEPS + 2.0)
	# Sub-voxel points: town + village flats, river valley, northeast rift
	# basin + outlet channel, rim ring/edges, and donor-world points outside
	# the web footprint (west/southeast basins, the donor plaza the
	# relocation trim moved away, deep plateau). Cell coords -> sub-voxels.
	var step_cells := [
		[34, 16], [34, 20], [34, 24], [30, 24], [38, 25],
		[28, 17], [40, 12], [34, 10], [27, 28], [41, 28],
		[77, 0], [78, 8], [78, 16], [78, 24], [76, 32], [73, 40],
		[70, 47], [70, 24],
		[64, 20], [60, 17], [70, 23], [63, 20], [69, 20], [76, 21],
		[79, 23],
		[-30, -12], [50, -14], [95, -10], [100, 20], [95, 44], [0, 44],
		[-20, 40], [0, 0], [50, 20], [17, 8], [20, 40],
		[15, 75], [72, 67], [44, 58], [66, 120],
	]
	for c: Array in step_cells:
		var isx: int = int(c[0]) * SUB + SUB / 2
		var isz: int = int(c[1]) * SUB + SUB / 2
		print("WSTEP %d %d %d" % [isx, isz, w.steps_at(isx, isz)])
	var biome_pts := [
		[34, 16], [28, 10], [40, 22], [20, 20],
		[0, 0], [10, 10], [20, 30], [30, 40], [50, 0], [50, 20],
		[50, 40], [60, 30],
		[-30, -12], [95, -10], [100, 40], [0, 44], [-33, 16], [100, 0],
		[15, 75], [72, 67],
	]
	for p: Array in biome_pts:
		var bw := w.biome_weights(float(p[0]), float(p[1]))
		print("WBIOME %d %d %.17f %.17f %.17f" % [p[0], p[1], bw.x, bw.y, bw.z])
	var uplift_pts := [
		[34, 16], [0, 0], [10, -10], [60, 40], [-20, 20], [80, 10],
		[20, 44], [50, -16], [90, 30], [5, 25], [70, 0], [15, 75],
	]
	for p: Array in uplift_pts:
		print("WUPLIFT %d %d %.17f" % [p[0], p[1], w.tectonic_uplift(float(p[0]), float(p[1]))])
	var rift_pts := [
		[15, 75], [20, 78], [10, 72], [64, 20], [68, 23], [58, 16],
		[72, 67], [76, 70], [66, 62], [34, 16], [0, 0], [50, 20],
	]
	for p: Array in rift_pts:
		# The warp noise at SALT_WARP: the desert mask reads it, and the
		# test pins it to bind the sibling-noise seeds, not just the law.
		print("WRIFT %d %d %.17f" % [p[0], p[1], w._warp.get_noise_2d(float(p[0]), float(p[1]))])
	print("WTABLE %.17f" % w.table_height())
	quit()
