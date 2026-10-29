extends SceneTree
## Golden noise probe: the donor's six sibling FastNoiseLite noises
## (world_heightmap.gd _sibling_noise: TYPE_SIMPLEX_SMOOTH, default FBM
## fractal, lacunarity 2.0, gain 0.5, seeds over TileTable.SCATTER_SEED).
## Needs no donor files at all -- Godot's FastNoiseLite is built in.
##
## Regenerate (deliberately, never casually):
##   build a scratch Godot project (donor repo stays read-only):
##     scratch=/tmp/gp-noise
##     mkdir -p "$scratch"
##     printf '[application]\nconfig_version=5\nname="probe"\n' > "$scratch/project.godot"
##     cp tools/godot-probe/probe_noise.gd "$scratch/"
##   then let Godot build the class cache and run the probe:
##     godot --headless --path "$scratch" --import
##   godot --headless --path "$scratch" -s probe_noise.gd \
##     > tests/golden/noise.txt

## salt, frequency denominator, fractal octaves (world_heightmap.gd:73-78).
const CONFIGS := [
	["WARP", 242, 45.0, 2],
	["MTN", 243, 64.0, 2],
	["PLATEAU", 244, 52.0, 2],
	["RIDGE", 245, 26.0, 3],
	["TERRACE", 246, 30.0, 2],
	["HILL", 247, 20.0, 4],
]

## Deterministic sample lattice, shared by every config (tests/noise.test.mjs
## rebuilds it): x = i * 1.7 + 0.3, y = j * 2.3 - 1.1 for i, j in 0..11.
const LATTICE_N := 12
const LATTICE_X_STEP := 1.7
const LATTICE_X_OFF := 0.3
const LATTICE_Y_STEP := 2.3
const LATTICE_Y_OFF := -1.1

func _sibling_noise(salt: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = int(absi(0x0C157E2026 + salt) % 2147483647)
	n.frequency = freq  # the donor assigns the frequency directly
	n.fractal_octaves = octaves
	return n

func _init() -> void:
	for cfg in CONFIGS:
		var n := _sibling_noise(cfg[1], 1.0 / cfg[2], cfg[3])
		for i in LATTICE_N:
			var x := i * LATTICE_X_STEP + LATTICE_X_OFF
			for j in LATTICE_N:
				var y := j * LATTICE_Y_STEP + LATTICE_Y_OFF
				var v := n.get_noise_2d(x, y)
				# Full precision: String.num(v, 9) is 9 DECIMALS, not 9
				# significant digits, so it truncated small magnitudes (e.g.
				# 4.6e-4 -> 0.000464559) and lost the donor's float32 bits.
				# String.num_scientific prints the shortest round-tripping
				# representation, so the golden carries the exact float32.
				print("NOISE %s %s %s %s" % [cfg[0], x, y, String.num_scientific(v)])
	quit()
