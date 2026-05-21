class_name PieceList

var occupied_squares: Array[int]

var _map: Array[int]
var _num_pieces: int

func _init(max_piece_count: int = 16) -> void:
	occupied_squares.resize(max_piece_count)
	_map.resize(64)
	_num_pieces = 0

func count() -> int:
	return _num_pieces

func add_piece_at_square(square: int) -> void:
	occupied_squares[_num_pieces] = square
	_map[square] = _num_pieces
	_num_pieces += 1

func remove_piece_at_square(square: int) -> void:
	var index: int = _map[square]
	occupied_squares[index] = occupied_squares[_num_pieces - 1]
	_map[occupied_squares[index]] = index
	_num_pieces -= 1

func move_piece(start_square: int, target_square: int) -> void:
	var index: int = _map[start_square]
	occupied_squares[index] = target_square
	_map[target_square] = index
