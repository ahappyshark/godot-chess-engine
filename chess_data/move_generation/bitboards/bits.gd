class_name Bits

const FILE_A: int = 0x101010101010101

const WHITE_KINGSIDE_MASK: int = 1 << BoardHelper.F1 | 1 << BoardHelper.G1
const BLACK_KINGSIDE_MASK: int = 1 << BoardHelper.F8 | 1 << BoardHelper.G8

const WHITE_QUEENSIDE_MASK2: int = 1 << BoardHelper.D1 | 1 << BoardHelper.C1
const BLACK_QUEENSIDE_MASK2: int = 1 << BoardHelper.D8 | 1 << BoardHelper.C8

const WHITE_QUEENSIDE_MASK: int = WHITE_QUEENSIDE_MASK2 | 1 << BoardHelper.B1
const BLACK_QUEENSIDE_MASK: int = BLACK_QUEENSIDE_MASK2 | 1 << BoardHelper.B8

static var white_passed_pawn_mask: Array[int]
static var black_passed_pawn_mask: Array[int]

static var white_pawn_support_mask: Array[int]
static var black_pawn_support_mask: Array[int]

static var file_mask: Array[int]
static var adjacent_file_masks: Array[int]

static var king_safety_mask: Array[int]

static var white_forward_file_mask: Array[int]
static var black_forward_file_mask: Array[int]

static var triple_file_mask: Array[int]


static func _static_init() -> void:
	file_mask = []
	file_mask.resize(8)
	adjacent_file_masks = []
	adjacent_file_masks.resize(8)

	for i in 8:
		file_mask[i] = FILE_A << i
		var left: int = FILE_A << (i - 1) if i > 0 else 0
		var right: int = FILE_A << (i + 1) if i < 7 else 0
		adjacent_file_masks[i] = left | right

	triple_file_mask = []
	triple_file_mask.resize(8)
	for i in 8:
		var clamped_file: int = clampi(i, 1, 6)
		triple_file_mask[i] = file_mask[clamped_file] | adjacent_file_masks[clamped_file]

	white_passed_pawn_mask = []
	white_passed_pawn_mask.resize(64)
	black_passed_pawn_mask = []
	black_passed_pawn_mask.resize(64)
	white_pawn_support_mask = []
	white_pawn_support_mask.resize(64)
	black_pawn_support_mask = []
	black_pawn_support_mask.resize(64)
	white_forward_file_mask = []
	white_forward_file_mask.resize(64)
	black_forward_file_mask = []
	black_forward_file_mask.resize(64)

	for square in 64:
		var file: int = BoardHelper.file_index(square)
		var rank: int = BoardHelper.rank_index(square)
		var adjacent_files: int = FILE_A << max(0, file - 1) | FILE_A << min(7, file + 1)
		var white_forward_mask: int = ~(-1 >> (64 - 8 * (rank + 1)))
		var black_forward_mask: int = (1 << (8 * rank)) - 1

		white_passed_pawn_mask[square] = (FILE_A << file | adjacent_files) & white_forward_mask
		black_passed_pawn_mask[square] = (FILE_A << file | adjacent_files) & black_forward_mask

		var adjacent: int = (1 << (square - 1) | 1 << (square + 1)) & adjacent_files
		white_pawn_support_mask[square] = adjacent | BitBoardUtility.shift(adjacent, -8)
		black_pawn_support_mask[square] = adjacent | BitBoardUtility.shift(adjacent, +8)

		white_forward_file_mask[square] = white_forward_mask & file_mask[file]
		black_forward_file_mask[square] = black_forward_mask & file_mask[file]

	king_safety_mask = []
	king_safety_mask.resize(64)
	for i in 64:
		king_safety_mask[i] = BitBoardUtility.king_moves[i] | (1 << i)
