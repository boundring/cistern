extends SceneTree
## SKELETON -- no implementation. Target path: tools/godot-probe/probe_noise.gd
## Owning slice: A (noise port) / donor probe
##
## Responsibility: own the golden generation for the donor's six sibling
## FastNoiseLite noises (world_heightmap.gd _sibling_noise: TYPE_SIMPLEX_SMOOTH,
## default FBM fractal, lacunarity 2.0, gain 0.5, seeds over
## TileTable.SCATTER_SEED) -- the salt, the frequency denominator, the
## fractal octaves and the sample lattice -- and print them in the exact
## format tests/golden/noise.txt stores. It must NOT own the heightmap law
## and must NOT reimplement the noise in GDScript: Godot's built-in
## FastNoiseLite IS the donor engine, and the probe merely samples it.
##
## Golden file it produces: tests/golden/noise.txt (one NOISE line per
## sample: the config name, x, y and the value in the shortest round-tripping
## form, String.num_scientific(v)). The probe must print the FULL float32
## value: a fixed-decimal print truncates small magnitudes (e.g.
## 4.645590088e-4 becomes 0.000464559), which loses the donor's bits in the
## golden and reads as a false mismatch against a bit-exact port.
##
## Regeneration recipe (deliberate, never casual -- the donor repo is
## READ-ONLY, so the closure is copied into a scratch project):
##   scratch=/tmp/gp-noise
##   mkdir -p "$scratch"
##   printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
##   cp tools/godot-probe/probe_noise.gd "$scratch/"
##   godot --headless --path "$scratch" --import
##   godot --headless --path "$scratch" -s probe_noise.gd \
##     > tests/golden/noise.txt
##
## Like-for-like rules: the probe samples the DONOR engine only -- no corridor
## trim and no village relocation apply here (both belong to the world probe);
## the lattice it prints is the same lattice tests/noise.test.mjs rebuilds.

func _init() -> void:
	pass
