extends SceneTree
## Ambient townsfolk golden probe (v2): the donor sim, townsfolk scenario.
## TownState.new() is the pinned-seed state (player marker at the spawn +
## Townsfolk.populate), and 200 ticks of empty-intent ambient running is the
## scenario the web port reproduces -- the same populate/wander code the
## donor golden (tests/fixtures/sim_town_golden.txt) exercises, minus the
## scripted player walk and servants (occupancy couples those to the
## townsfolk stream; they are out of the web's v2 scope).
##
## Regenerate (deliberately, never casually):
##   build a scratch Godot project (donor repo stays read-only):
##     <scratch>/project.godot          -- config_version=5, app name "probe"
##     <scratch>/scripts/sim/           -- town_map.gd town_state.gd
##                                         townsfolk.gd shop_stock.gd
##                                         servant_job_executor.gd
##     <scratch>/scripts/protocol/      -- sim_intent.gd
##     <scratch>/probe_townsfolk.gd     -- this file
##   (six .gd files total: the full closure -- town_state.gd preloads
##   townsfolk.gd/shop_stock.gd by res:// path, the rest resolve via
##   class_name; nothing reads content/.)
##   then let Godot build the class cache and run the probe:
##     godot --headless --path <scratch> --import
##   godot --headless --path /tmp/gp-v2 -s probe_townsfolk.gd \
##     > tests/golden/townsfolk.txt

func _init() -> void:
	var s := TownState.new()
	var place := []
	for a in s.actors:
		var pos: Vector2i = a.pos
		place.append({
			"id": a.id, "kind": a.kind,
			"x": pos.x, "y": pos.y, "speed": a.speed,
		})
	for i in 200:
		s.tick()
	print("VECT_TOWNSFOLK " + JSON.stringify({
		"seed": s.seed_used,
		"place": place,
		"events": Array(s.events),
	}))
	quit()
