class_name Coord
extends RefCounted

var file_index: int
var rank_index: int

func _init(p_file_index: int, p_rank_index: int) -> void:
	file_index = p_file_index
	rank_index = p_rank_index

static func coord_from_square_index(square_index: int) -> Coord:
	var file: int = BoardHelper.file_index(square_index)
	var rank: int = BoardHelper.rank_index(square_index)
	return Coord.new(file, rank)

func is_light_square() -> bool:
	return (file_index + rank_index) % 2 != 0

func compare_to(other: Coord) -> int:
	var matched: bool = (file_index == other.file_index) && (rank_index == other.rank_index)
	return 0 if matched else 1

func plus(c: Coord) -> Coord:
	return Coord.new(file_index + c.file_index, rank_index + c.rank_index)

func minus(c: Coord) -> Coord:
	return Coord.new(file_index - c.file_index, rank_index - c.rank_index)

func multiply(m: int) -> Coord:
	return Coord.new(file_index * m, rank_index * m)

func is_valid_square() -> bool:
	return file_index >= 0 && file_index < 8 && rank_index >= 0 && rank_index < 8
