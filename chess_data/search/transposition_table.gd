class_name TranspositionTable

const LOOKUP_FAILED: int = -1
const EXACT: int = 0
const LOWER_BOUND: int = 1
const UPPER_BOUND: int = 2

var entries: Array
var count: int
var enabled: bool = true
var board: Board


func _init(board: Board, size_mb: int) -> void:
	self.board = board

	const TT_ENTRY_SIZE_BYTES: int = 16  # no Marshal.SizeOf equivalent in GDScript
	var desired_table_size_bytes: int = size_mb * 1024 * 1024
	var num_entries: int = desired_table_size_bytes / TT_ENTRY_SIZE_BYTES

	count = num_entries
	entries = []
	entries.resize(num_entries)
	for i in num_entries:
		entries[i] = Entry.new()


func clear() -> void:
	for i in entries.size():
		entries[i] = Entry.new()


var index: int:
	get:
		# count is always a power of 2 (size_mb * 1024*1024 / 16), so & avoids
		# the negative result that % gives on negative Zobrist keys.
		return board.current_game_state.zobrist_key & (count - 1)


func try_get_stored_move() -> Move:
	return entries[index].move


func try_lookup_evaluation(depth: int, ply_from_root: int, alpha: int, beta: int) -> Dictionary:
	return {"success": false, "eval": 0}


func lookup_evaluation(depth: int, ply_from_root: int, alpha: int, beta: int) -> int:
	if not enabled:
		return LOOKUP_FAILED
	var entry: Entry = entries[index]

	if entry.key == board.current_game_state.zobrist_key:
		if entry.depth >= depth:
			var corrected_score: int = correct_retrieved_mate_score(entry.value, ply_from_root)
			if entry.node_type == EXACT:
				return corrected_score
			if entry.node_type == UPPER_BOUND and corrected_score <= alpha:
				return corrected_score
			if entry.node_type == LOWER_BOUND and corrected_score >= beta:
				return corrected_score
	return LOOKUP_FAILED


func store_evaluation(depth: int, num_ply_searched: int, eval: int, eval_type: int, move: Move) -> void:
	if not enabled:
		return
	var idx: int = index
	var entry: Entry = Entry.new(board.current_game_state.zobrist_key, correct_mate_score_for_storage(eval, num_ply_searched), depth, eval_type, move)
	entries[index] = entry


func correct_mate_score_for_storage(score: int, num_ply_searched: int) -> int:
	if Searcher.is_mate_score(score):
		var s: int = sign(score)
		return (score * s + num_ply_searched) * s
	return score


func correct_retrieved_mate_score(score: int, num_ply_searched: int) -> int:
	if Searcher.is_mate_score(score):
		var s: int = sign(score)
		return (score * s - num_ply_searched) * s
	return score


func get_entry(zobrist_key: int) -> Entry:
	return entries[zobrist_key & (entries.size() - 1)]


class Entry:
	var key: int
	var value: int
	var move: Move
	var depth: int
	var node_type: int

	func _init(key: int = 0, value: int = 0, depth: int = 0, node_type: int = 0, move: Move = null) -> void:
		self.key = key
		self.value = value
		self.depth = depth
		self.node_type = node_type
		self.move = move

	static func get_size() -> int:
		return 16  # no Marshal.SizeOf equivalent in GDScript
