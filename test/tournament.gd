class_name Tournament

# Each bot entry: { "bot": ChessBot, "elo": float, "wins": int, "losses": int, "draws": int }
var roster: Array = []

const K_FACTOR = 32.0
const STARTING_ELO = 1000.0

func add_bot(bot: ChessBot) -> void:
	roster.append({
		"bot": bot,
		"elo": STARTING_ELO,
		"wins": 0, "losses": 0, "draws": 0
	})

# Play every bot against every other bot, N games each side.
# Safe to call from a background thread — HeadlessGame creates its own Board.
func run_round_robin(games_per_matchup: int = 10) -> void:
	var total_matchups = roster.size() * (roster.size() - 1) / 2
	print("=== TOURNAMENT START — %d bots, %d matchups, %d games each ===" % [
		roster.size(), total_matchups, games_per_matchup
	])
	var matchup_num = 0
	for i in roster.size():
		for j in range(i + 1, roster.size()):
			matchup_num += 1
			print("\n[%d/%d] %s vs %s" % [
				matchup_num, total_matchups,
				roster[i].bot.name, roster[j].bot.name
			])
			_play_matchup(roster[i], roster[j], games_per_matchup)
	print("")
	print_standings()

func _play_matchup(a: Dictionary, b: Dictionary, n: int) -> void:
	var a_wins := 0
	var b_wins := 0
	var draws  := 0
	for game_num in n:
		var is_a_white := (game_num % 2 == 0)
		var white_entry = a if is_a_white else b
		var black_entry = b if is_a_white else a

		var result = HeadlessGame.play(white_entry.bot, black_entry.bot)

		match result:
			HeadlessGame.Result.WHITE_WIN:
				_record_result(white_entry, black_entry, 1.0)
				if is_a_white: a_wins += 1 else: b_wins += 1
				print("  G%d: %s wins (white)" % [game_num + 1, white_entry.bot.name])
			HeadlessGame.Result.BLACK_WIN:
				_record_result(black_entry, white_entry, 1.0)
				if not is_a_white: a_wins += 1 else: b_wins += 1
				print("  G%d: %s wins (black)" % [game_num + 1, black_entry.bot.name])
			HeadlessGame.Result.DRAW:
				_record_result(white_entry, black_entry, 0.5)
				draws += 1
				print("  G%d: draw" % [game_num + 1])

	print("  → %s %d – %d %s  (%d draws)  Elo now: %.0f / %.0f" % [
		a.bot.name, a_wins, b_wins, b.bot.name, draws, a.elo, b.elo
	])

func _record_result(winner: Dictionary, loser: Dictionary, score: float) -> void:
	var expected_w = _expected(winner.elo, loser.elo)
	var expected_l = _expected(loser.elo, winner.elo)
	
	winner.elo += K_FACTOR * (score - expected_w)
	loser.elo += K_FACTOR * ((1.0 - score) - expected_l)
	
	if score == 1.0:
		winner.wins += 1
		loser.losses += 1
	else:
		winner.draws += 1
		loser.draws += 1

func _expected(rating_a: float, rating_b: float) -> float:
	return 1.0 / (1.0 + pow(10.0, (rating_b - rating_a) / 400.0))

func print_standings() -> void:
	var sorted = roster.duplicate()
	sorted.sort_custom(func(a, b): return a.elo > b.elo)
	print("=== STANDINGS ===")
	for entry in sorted:
		print("%s — Elo: %.0f  W:%d D:%d L:%d" % [
			entry.bot.name, entry.elo,
			entry.wins, entry.draws, entry.losses
		])
