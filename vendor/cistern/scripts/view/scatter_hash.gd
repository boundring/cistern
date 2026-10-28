class_name ScatterHash
extends RefCounted
## Per-cell deterministic decoration RNG (plan-04 §4.1 no-flicker law):
## every query reseeds a RandomNumberGenerator from the pinned seed combined
## with a position hash of (|gx|, |gy|, floor_identity), so results are a
## pure function of the cell and never iteration-order dependent.

var _floor_identity: int
var _seed: int


func _init(floor_identity: int, seed: int = TileTable.SCATTER_SEED) -> void:
	_floor_identity = floor_identity
	_seed = seed


func _cell_seed(gx: int, gy: int) -> int:
	var h := _seed
	h = h * 0x100000001B3 + absi(gx)
	h = h * 0x100000001B3 + absi(gy)
	h = h * 0x100000001B3 + _floor_identity
	return h ^ (h >> 29)


func _rng_for(gx: int, gy: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = _cell_seed(gx, gy)
	return rng


func presence(gx: int, gy: int, density: float) -> bool:
	return _rng_for(gx, gy).randf() < density


func variant(gx: int, gy: int, n: int) -> int:
	if n <= 0:
		return 0
	return _rng_for(gx, gy).randi_range(0, n - 1)


func jitter(gx: int, gy: int) -> Vector2:
	var rng := _rng_for(gx, gy)
	return Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
