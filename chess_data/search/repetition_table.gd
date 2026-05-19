class_name RepetitionTable

var hashes: Array[int]
var start_indices: Array[int]
var count: int


func _init() -> void:
	hashes = []
	hashes.resize(256)
	hashes.fill(0)
	start_indices = []
	start_indices.resize(hashes.size() + 1)
	start_indices.fill(0)


func init(board: Board) -> void:
	var initial_hashes: Array = board.repetition_position_history.duplicate()
	initial_hashes.reverse()
	count = initial_hashes.size()

	for i in initial_hashes.size():
		hashes[i] = initial_hashes[i]
		start_indices[i] = 0
	start_indices[count] = 0


func push(hash: int, reset: bool) -> void:
	if count < hashes.size():
		hashes[count] = hash
		start_indices[count + 1] = count if reset else start_indices[count]
	count += 1


func try_pop() -> void:
	count = max(0, count - 1)


func contains(h: int) -> bool:
	var s: int = start_indices[count]
	for i in range(s, count - 1):
		if hashes[i] == h:
			return true
	return false
