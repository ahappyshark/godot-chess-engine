class_name ChessPiece
extends Node2D

const _TEX: Dictionary = {
	Piece.WHITE_KING:   preload("res://art/white_king_tex.tres"),
	Piece.WHITE_PAWN:   preload("res://art/white_pawn_tex.tres"),
	Piece.WHITE_KNIGHT: preload("res://art/white_knight_tex.tres"),
	Piece.WHITE_BISHOP: preload("res://art/white_bishop_tex.tres"),
	Piece.WHITE_ROOK:   preload("res://art/white_rook_tex.tres"),
	Piece.WHITE_QUEEN:  preload("res://art/white_queen_tex.tres"),
	Piece.BLACK_KING:   preload("res://art/black_king_tex.tres"),
	Piece.BLACK_PAWN:   preload("res://art/black_pawn_tex.tres"),
	Piece.BLACK_KNIGHT: preload("res://art/black_knight_tex.tres"),
	Piece.BLACK_BISHOP: preload("res://art/black_bishop_tex.tres"),
	Piece.BLACK_ROOK:   preload("res://art/black_rook_tex.tres"),
	Piece.BLACK_QUEEN:  preload("res://art/black_queen_tex.tres"),
}

@onready var sprite: Sprite2D = $Sprite2D

var piece_code: int = Piece.NONE

func set_piece(code: int) -> void:
	piece_code = code
	sprite.texture = _TEX.get(code)
