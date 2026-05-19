class_name RngService

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func seed_run(seed_val: int) -> void:
	_rng.seed = seed_val

func randi64() -> int:
	var high: int = _rng.randi()
	var low: int = _rng.randi()
	return (high << 32) | low
