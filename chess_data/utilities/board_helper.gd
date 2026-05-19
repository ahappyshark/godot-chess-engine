class_name BoardHelper

static var rook_directions: Array[Vector2i] = [
	Vector2i(0, 1),
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(-1, 0)
]

static var bishop_directions: Array[Vector2i] = [
	Vector2i(1, 1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(-1,-1)
]

const FILES: String = "abcdefgh"
const RANKS: String = "12345678"
const A1: int = 0
const B1: int = 1
const C1: int = 2
const D1: int = 3
const E1: int = 4
const F1: int = 5
const G1: int = 6
const H1: int = 7

const A8: int = 56
const B8: int = 57
const C8: int = 58
const D8: int = 59
const E8: int = 60
const F8: int = 61
const G8: int = 62
const H8: int = 63

static func rank_index(square_index: int) -> int:
	return square_index >> 3

static func file_index(square_index: int) -> int:
	return square_index & 0b000111

static func index_from_values(p_file_index: int, p_rank_index: int) -> int:
	return p_rank_index * 8 + p_file_index

static func index_from_coord(coord: Coord) -> int:
	return index_from_values(coord.file_index, coord.rank_index)

static func coord_from_index(square_index: int) -> Coord:
	return Coord.new(file_index(square_index), rank_index(square_index))

static func is_fr_light_square(p_file_index: int, p_rank_index: int) -> bool:
	return (p_file_index + p_rank_index) % 2 != 0

static func light_square(square_index: int) -> bool:
	return is_fr_light_square(file_index(square_index), rank_index(square_index))

static func is_index_light_square(square_index: int) -> bool:
	return is_fr_light_square(file_index(square_index), rank_index(square_index))

static func square_name_from_coord(p_file_index: int, p_rank_index: int) -> String:
	return FILES[p_file_index] + "" + str(p_rank_index + 1)

static func square_name_from_index(square_index: int) -> String:
	return square_name_from_coord(coord_from_index(square_index).file_index, coord_from_index(square_index).rank_index)

static func square_index_from_name(name: String) -> int:
	var file_name: String = name[0]
	var rank_name: String = name[1]
	var fi: int = FILES.find(file_name)
	var ri: int = RANKS.find(rank_name)
	return index_from_values(fi, ri)
