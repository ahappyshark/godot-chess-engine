# CHESS GOBLIN

### *or: That Time I Got Stranded in a World of Goblins and Was Forced to Play Chess in Order to Earn a Way Back Home*

-----

## What This Game Is

A chess game with a goblin skin, a trash-talking opponent, and the bones of a larger narrative. Built in Godot 4, exported to HTML5 for itch.io. The engine is real — perft-verified, bot-capable, no shortcuts. The goblin layer sits on top of that solid foundation.

The original sin: a one-day prototype that grew a spine.

-----

## Engine Status ✅ DONE

These are complete and tested. Don’t touch them unless something is broken.

- **Chess engine** — correct move generation, perft 5 verified
- **Bot interface** — composable behavior system
  - Random bot
  - Minimax bot
  - Searcher bot (unbeatable at current depth)
- **Headless tournament runner** — round-robin, configurable games, time estimates
- **Visual board** — moveable pieces, playable against bots
- **UI overlay helpers** — expandable debug/helper panel

-----

## Phase 1 — Ship Something

*“A goblin next to a chessboard that talks shit.” That’s the whole pitch. This is the goal.*

**Scope: intentionally tiny.** Resist the urge to expand it. Do this first.

### Screens

|Screen      |Contents                                                          |
|------------|------------------------------------------------------------------|
|Title       |Game name, Start button, maybe a goblin doing something dumb      |
|Color Select|White / Black / Random — one button each                          |
|Game        |Board + goblin portrait + dialogue bubble + eval-driven trash talk|
|End         |Win/Loss/Draw message, Rematch, Quit                              |

### Gameplay Loop

```
Title → Color Select → Game vs Searcher Bot → End Screen → [loop]
```

### The Goblin

- Static or lightly animated portrait next to the board
- Dialogue bubble that updates based on board evaluation
- A small bank of lines per eval tier (losing badly, losing, even, winning, winning badly, checkmate)
- Lines written in goblin voice — dumb, confident, occasionally accidentally insightful
- No branching. No state machine. Just vibes.

### Eval-Driven Dialogue (simple version)

Map Stockfish-style centipawn score to tiers from goblin’s perspective:

```
goblin_losing_badly   → smack talk that sounds nervous
goblin_losing         → confused overconfidence
even                  → generic posturing
goblin_winning        → unbearable smugness
goblin_winning_badly  → full villain monologue energy
checkmate             → one special line
player_wins           → goblin rage quits / threatens sequel
```

Pull a random line from the appropriate bucket each time eval crosses a threshold. Debounce so it doesn’t fire every move.

### Acceptance Criteria for Phase 1

- [ ] Title screen renders
- [ ] Color select works
- [ ] Game starts correctly as white or black
- [ ] Goblin portrait visible during game
- [ ] At least 5 lines per eval tier
- [ ] Dialogue updates during play
- [ ] Win/loss/draw detected and displayed
- [ ] Rematch resets cleanly
- [ ] HTML5 export works on itch.io
- [ ] Someone other than you can pick it up and play it without instructions

-----

## Phase 2 — The Game That Wants to Be Made

*The ADHD vision. After Phase 1 ships.*

### Core Premise Expansion

The player didn’t just stumble into a chess match. There’s a world here. Goblins have a culture around chess — it’s law, economy, status. You’re an outsider who got stranded and chess is the only way out. Different goblins, different stakes, different board vibes.

### Planned Systems

**Dialogue Engine (branching, data-driven)**

- YAML or JSON-driven dialogue trees
- Visual novel style: portrait + text box + optional choices
- Supports: character lines, conditional branches, event triggers
- Dialogue can react to: game state, win/loss history, flags set by player choices
- Reusable across all characters and scenes

**Game State Manager**

- Persistent flags (did player beat X goblin, did player choose Y dialogue path)
- Save/load (or at minimum, session persistence for HTML5)
- Drives: which opponent is available, what dialogue plays, story progression

**Opponent Roster**
Each goblin is a data record:

```
name, portrait, voice_style, bot_difficulty, unlock_condition, 
pre_game_dialogue, post_win_dialogue, post_loss_dialogue, taunt_pool
```

**The Cheating System** *(tabled — post-engine, post-Phase 1)*

- Illegal moves that goblins may or may not notice
- Suspicion meter, tiered violations
- Goblins have different detection rates based on personality
- High risk/reward layer over the base chess game

**Story Structure** (loose, not final)

- Linear-ish progression through goblin characters
- Each win unlocks the next opponent / new area
- Dialogue choices affect tone, not outcome (at first)
- End goal: earn passage home, probably by beating the goblin king or some nonsense

### Data-Driven Architecture Goal

Everything that can be data, should be data. The code handles systems. Content lives in files.

```
/data
  /dialogue      ← conversation trees per character
  /opponents     ← goblin opponent definitions  
  /eval_lines    ← taunt banks by tier
  /events        ← story flag triggers
  /items         ← future: board modifiers, power-ups, whatever
```

-----

## What to Build Next (After Phase 1 Ships)

Suggested order, not gospel:

1. **Data-driven dialogue engine** — foundational, everything else uses it
1. **Game state / flag system** — persistence, unlock logic
1. **Opponent select screen** — goblin roster, lock/unlock states
1. **Story pass** — write actual dialogue for 3–5 goblins
1. **The cheating system** — when the above are all stable

-----

## Technical Notes

- Godot 4, GDScript throughout
- Web export: Compatibility renderer (not Mobile)
- All chess engine work is decoupled from visual layer ✅
- Bot difficulty scales via existing interface — easy to wire to opponent data records
- GUT tests cover engine; don’t let goblin features break them

-----

## The Vibe

Dumb fun with real chess underneath. The goblin is stupid and annoying and you want to beat it. The chess is real so winning actually feels earned. The story is an excuse to meet more goblins.

It respects the player’s intelligence about chess and absolutely does not respect anything else.