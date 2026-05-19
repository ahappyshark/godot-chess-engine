class_name BitBoardUtility
const file_a: int = 0x101010101010101

const rank_1 = 0b11111111
const rank_2 = rank_1 << 8
const rank_3 = rank_2 << 8
const rank_4 = rank_3 << 8
const rank_5 = rank_4 << 8
const rank_6 = rank_5 << 8
const rank_7 = rank_6 << 8
const rank_8 = rank_7 << 8
const not_a_file = ~file_a
const not_h_file = ~(file_a << 7)

static var knight_attacks: Array[int] = []
static var king_moves: Array[int] = []
static var white_pawn_attacks: Array[int] = []
static var black_pawn_attacks: Array[int] = []

# Get index of least significant set bit in given 64bit value. Also clears the bit to zero.
static func pop_lsb(b: int) -> Array:
	var i = trailing_zero_count(b)
	var new_b: int = b & (b - 1)
	return [i, new_b]
		
static func trailing_zero_count(b: int) -> int:
	if b == 0:
		return 64
	var count: int = 0
	while (b & 1) == 0:
		b >>= 1
		count += 1
	return count

static func set_square(bitboard: int, square_index: int) -> int:
	bitboard |= 1 << square_index
	return bitboard

static func clear_square(bitboard: int, square_index: int) -> int:
	bitboard &= ~(1 << square_index)
	return bitboard

static func toggle_square(bitboard: int, square_index: int) -> int:
	bitboard ^= 1 << square_index
	return bitboard

static func toggle_squares(bitboard: int, square_a: int, square_b: int) -> int:
	bitboard ^= (1 << square_a | 1 << square_b)
	return bitboard


static func contains_square(bitboard: int, square: int) -> bool:
	return ((bitboard >> square) & 1) != 0

static func pawn_attacks(pawn_bitboard: int, is_white: bool) -> int:
	# Pawn attacks are calculated like so: (example given with white to move)

	# The first half of the attacks are calculated by shifting all pawns north-east: northEastAttacks = pawn_bitboard << 9
	# Note that pawns on the h file will be wrapped around to the a file, so then mask out the a file: northEastAttacks &= not_a_file
	# (Any pawns that were originally on the a file will have been shifted to the b file, so a file should be empty).

	# The other half of the attacks are calculated by shifting all pawns north-west. This time the h file must be masked out.
	# Combine the two halves to get a bitboard with all the pawn attacks: northEastAttacks | northWestAttacks
	if is_white:
		return ((pawn_bitboard << 9) & not_a_file) | ((pawn_bitboard << 7) & not_h_file)
	return ((pawn_bitboard >> 7) & not_a_file) | ((pawn_bitboard >> 9) & not_h_file)

static func shift(bitboard: int, num_squares_to_shift) -> int:
	if num_squares_to_shift > 0:
		return bitboard << num_squares_to_shift
	return bitboard >> -num_squares_to_shift

func _ready() -> void:
	knight_attacks.resize(64)
	king_moves.resize(64)
	white_pawn_attacks.resize(64)
	black_pawn_attacks.resize(64)

	var orthoDir: Array[Vector2i] = [Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1)]
	var diagDir: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(1, -1)]
	var knightJumps: Array[Vector2i] = [Vector2i(-2, -1), Vector2i(-2, 1), Vector2i(-1, 2), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, -1), Vector2i(1, -2), Vector2i(-1, -2)]

	for y in range(8):
		for x in range(8):
			var square_index = y * 8 + x

			for dir_index in range(4):
				# Orthogonal and diagonal directions
				for dst in range(1, 8):
					var ortho_x = x + orthoDir[dir_index].x * dst
					var ortho_y = y + orthoDir[dir_index].y * dst
					var diag_x = x + diagDir[dir_index].x * dst
					var diag_y = y + diagDir[dir_index].y * dst

					var ortho_target = _valid_square_index(ortho_x, ortho_y)
					if ortho_target != -1:
						if dst == 1:
							king_moves[square_index] |= 1 << ortho_target

					var diag_target = _valid_square_index(diag_x, diag_y)
					if diag_target != -1:
						if dst == 1:
							king_moves[square_index] |= 1 << diag_target

				# Knight jumps
				for i in range(knightJumps.size()):
					var knight_x = x + knightJumps[i].x
					var knight_y = y + knightJumps[i].y
					var knight_target = _valid_square_index(knight_x, knight_y)
					if knight_target != -1:
						knight_attacks[square_index] |= 1 << knight_target

				# Pawn attacks
				var white_pawn_right = _valid_square_index(x + 1, y + 1)
				if white_pawn_right != -1:
					white_pawn_attacks[square_index] |= 1 << white_pawn_right

				var white_pawn_left = _valid_square_index(x - 1, y + 1)
				if white_pawn_left != -1:
					white_pawn_attacks[square_index] |= 1 << white_pawn_left

				var black_pawn_right = _valid_square_index(x + 1, y - 1)
				if black_pawn_right != -1:
					black_pawn_attacks[square_index] |= 1 << black_pawn_right

				var black_pawn_left = _valid_square_index(x - 1, y - 1)
				if black_pawn_left != -1:
					black_pawn_attacks[square_index] |= 1 << black_pawn_left

static func _valid_square_index(x: int, y: int) -> int:
	if x >= 0 and x < 8 and y >= 0 and y < 8:
		return y * 8 + x
	return -1
