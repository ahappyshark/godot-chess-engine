extends Node
# Global auto load
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
static var _seed: int = 0

static func _static_init() -> void:
	seed_run("goblinchess")

static func seed_run(seed_value: String) -> void:
	_rng.seed = hash(seed_value)
	_rng.randomize()
	_seed = _rng.seed

static func get_seed() -> int:
	return _seed

static func randf_0_1() -> float:
	return _rng.randf()

static func chance(probability: float) -> bool:
	if probability <= 0.0:
		return false
	if probability >= 1.0:
		return true
	return _rng.randf() < probability

static func randi_range_inclusive(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)

static func randi64() -> int:
	var high: int = _rng.randi()
	var low: int = _rng.randi()
	return (high << 32) | low

static func pick_index(size: int) -> int:
	if size <= 0:
		return -1
	return _rng.randi_range(0, size - 1)

static func pick_from(array: Array):
	var index := pick_index(array.size())
	if index < 0:
		return null
	return array[index]

static func shuffle_copy(array: Array) -> Array:
	var result := array.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result
