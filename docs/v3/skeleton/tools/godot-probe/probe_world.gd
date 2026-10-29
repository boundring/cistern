extends SceneTree
## SKELETON -- no implementation. Target path: tools/godot-probe/probe_world.gd
## Owning slice: B (world law) / donor probe
##
## Responsibility: own the golden generation for the donor's relief law over
## the web's 68x32 playable grid -- the full donor closure
## (tile_table.gd, scatter_hash.gd, hd2d_heightmap.gd, world_heightmap.gd,
## slab_def.gd, prefab_factory.gd, slab_assembler.gd, world_level.gd) sampled
## at the pinned cells, printed in the exact format
## tests/golden/world.txt stores. It must NOT own the web-side extensions
## (the ocean band and the desert classification): the golden pins the donor
## law, like for like.
##
## Golden file it produces: tests/golden/world.txt.
##
## Regeneration recipe (deliberate, never casual -- the donor repo is
## READ-ONLY, so the closure is copied into a scratch project):
##   scratch=/tmp/gp-world
##   mkdir -p "$scratch"
##   printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
##   cp <donor>/godot/scripts/view/{tile_table.gd,scatter_hash.gd,hd2d_heightmap.gd,world_heightmap.gd,slab_def.gd,prefab_factory.gd,slab_assembler.gd} "$scratch/scripts/view/"
##   cp <donor>/godot/scripts/world/world_level.gd "$scratch/scripts/world/"
##   cp tools/godot-probe/probe_world.gd "$scratch/"
##   godot --headless --path "$scratch" --import
##   godot --headless --path "$scratch" -s probe_world.gd \
##     > tests/golden/world.txt
##
## Like-for-like rules -- the probe MUST apply the same two trims as the
## web port, so the golden values compare like for like:
##   1. Corridor trim: the web build has no roads, so the corridor grid is
##      sized and left zeroed (the parent's version resizes and fills 0.0
##      before its corridor loop -- replicate that and skip the loop, so
##      _corridor_bilinear stays in range) and the analytic corridor damping
##      the uplift reads is overridden to return 0.0.
##   2. Village relocation: the village disc is moved to the web's
##      VILLAGE_X / VILLAGE_Y (34, 16); the donor's own 96x96-world village
##      data does not apply. VILLAGE_FLAT_RADIUS 13 and VILLAGE_FLAT_CORE 6
##      stay.
## Everything else (the salts, the basins, the river functions, the parent's
## town flat at town_center_for(w, h, margin_z), SUB, VOXEL, MAX_STEPS) is
## the donor's, verbatim.

func _init() -> void:
	pass
