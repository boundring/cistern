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
##   copy scripts/{sim,protocol} closure into /tmp/gp-v2 (donor repo stays
##   read-only), then
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
