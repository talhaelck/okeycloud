# 101 Okey rules and house-rule settings

Every rule that people play differently is a setting in `GameSettings` (`scripts/rules/game_settings.gd`).
Settings are grouped by the tab they appear on in the settings page (see [screens.md](screens.md)).
The "Default" column is the "Klasik 101" preset.

## Base game (not configurable)
- 106 tiles: 4 colours (kırmızı, siyah, mavi, sarı) × numbers 1-13 × 2 copies, plus 2 sahte okey.
- 4 players, play goes counter-clockwise. Every player draws, then discards to his right.
- Gösterge: a face-up tile after the deal. The **okey** is the next number in the same colour (13 → 1).
  Okey tiles are jokers. A sahte okey plays as the okey's real value.
- **Per:** 3-4 tiles with the same number in different colours.
- **Seri:** 3+ consecutive tiles of the same colour.
- A turn has three parts:
  1. Draw from the centre pile, or take the tile the left-hand player just discarded.
  2. Optionally open (el açma) or add tiles to opened sets (işleme). İşleme is only allowed after you have opened.
  3. Discard one tile.
- The hand ends when a player has placed every tile and makes his last discard, or when the centre pile runs out.
- Only 20 tiles are left in the pile after the deal (22 + 3 × 21 + gösterge), so many hands end with it.
- In code: `scripts/rules/` (OkeyGame, Meld, Solver, BotBrain, GameSettings), tested by `tests/rules_test.gd`.
  OkeyGame keeps the public state and how many tiles each player should hold; the physical rack is what he holds.

## Table layout
- **Centre:** one draw pile (a short stack, the count written above it) and the gösterge beside it.
- **Discards:** each player's own row on his right-hand diagonal, from the corner toward the middle, so it lies
  between him and the next player, who may take the newest (innermost) tile. Every tile in a row stays visible.
- **Opened melds:** in the wedge in front of each player, between his rack and the pile. The two rows nearest the
  pile fill first, because the owner's rack hides the felt right behind it from his own eyes.
- **Player controls:** drag from the pile or the left row onto your rack to draw, drag a tile onto your row to
  discard. Group tiles on the rack with an empty slot between groups and press Enter to open them. R lays the rack
  out as the best groups (press again for pairs). Drop a tile on a laid meld to işle it; if it is the tile an okey
  in that meld stands for, it takes the okey's place and the okey comes to your rack.
- **Quick ways:** a quick click on the pile or the left discard draws it; a double-click on a rack tile throws it (a costly one
  the second time); Ctrl+click picks tiles on the rack and dragging one carries them all, keeping their shape.
- **End of a hand:** the camera turns to whoever finished, every rack tips over face up, and a chalkboard counts the scores.
- **Looking:** Space reads your rack, W (or the mouse wheel) bends you over the table to see the melds from above.
  Both leave you blind somewhere: see [stealing.md](stealing.md). F calls "Yakala!", C "Taş say!", Shift sneaks.
- **Scoring:** lower is better.
  - The finisher gets a bonus (negative score).
  - Players who opened score the sum of the tiles left in their rack.
  - Players who never opened get the "did not open" penalty.
  - The match winner has the lowest total after N hands.

## Settings

### Açma (opening)
| Key | Default | Meaning |
|-----|---------|---------|
| `open_threshold` | 101 | Minimum total of the opened sets. |
| `open_must_beat_previous` | true | Must open higher than the highest opening so far this hand. |
| `open_pairs_enabled` | true | Opening with pairs (çift) is allowed. |
| `open_pairs_min` | 5 | Number of pairs needed for a pair opening. |
| `pairs_must_beat_previous` | false | A pair opening must have more pairs than a previous pair opening. |
| `run_wraps_13_1` | false | House rule: 12-13-1 counts as a run (1 worth 11 there). Normal 101 has no such run; the 1 only starts 1-2-3. |
| `pair_opener_can_open_sets` | false | A player who opened with pairs may later lay pers and seris. |
| `pair_opener_can_extend` | true | A player who opened with pairs may işle onto other melds. |
| `okey_swap_from_table` | true | After opening, give the real tile for an okey in a laid meld and take the okey. |

An okey in a meld always counts as the tile it replaces.

### Çekme (drawing)
| Key | Default | Meaning |
|-----|---------|---------|
| `side_take_requires_open` | true | Taking the left discard requires opening (or işleme if already open) with that tile in the same turn. |
| `side_take_penalty` | 101 | Penalty when the rule above is broken. |
| `feed_penalty` | false | Whoever discards the tile his right-hand neighbour then opens with pays `penalty_unit`. |

### Cezalar (penalties)
| Key | Default | Meaning |
|-----|---------|---------|
| `penalty_unit` | 101 | The "101" amount used by penalties below. |
| `not_opened_penalty` | 202 | Score for a player who never opened. |
| `discard_playable_penalty` | true | Discarding a tile that could be added to an opened set (işlek taş) costs `penalty_unit`. |
| `discard_okey_penalty` | true | Discarding an okey costs `penalty_unit`. |
| `pair_opener_double` | true | A player who opened with pairs pays double his rack total. |
| `okey_left_in_hand` | 101 | What an okey still in the rack counts at the end (a sahte okey counts as the okey's number). |

### Bitirme (finishing)
| Key | Default | Meaning |
|-----|---------|---------|
| `finish_bonus` | -101 | Score for the finisher. |
| `finish_with_okey_double` | true | Finishing by discarding an okey doubles everyone's score for the hand. |
| `finish_with_pairs_double` | true | Finishing after a pair opening doubles everyone's score. |
| `finish_in_hand_bonus` | true | Opening everything at once ("elden bitme") doubles again. |

### Maç (match)
| Key | Default | Meaning |
|-----|---------|---------|
| `hands_per_match` | 9 | Number of hands. |
| `turn_time_limit` | 30 | Seconds per turn (0 = no limit). |
| `dealer_tiles` | 22 | The dealer starts with 22 tiles and discards first. Everyone else gets 21. |
| `indicator_show_bonus` | false | Showing the gösterge's twin before your first turn ends earns -`penalty_unit`. |

### Çalma (stealing)
See [stealing.md](stealing.md) for the mechanics. These keys live in the same resource.
| Key | Default | Meaning |
|-----|---------|---------|
| `stealing_enabled` | true | Master switch. |
| `steal_from_racks` | true | Neighbours' racks. |
| `steal_from_discards` | true | Any tile in any discard row. |
| `steal_from_melds` | true | Swap a tile into an opened set and take the okey out. |
| `steal_from_pile` | true | Draw out of turn, or peek at the top tile. |
| `catch_window` | 4.0 | Seconds after a theft during which "Yakala!" can catch it. |
| `catch_penalty` | 101 | Thief's penalty when caught. |
| `false_accusation_penalty` | 101 | Penalty for a wrong "Yakala!". |
| `count_check_enabled` | true | "Taş say!" challenge. |
| `count_check_penalty` | 101 | Penalty for the loser of a "Taş say!". |

### Mod (modes)
| Key | Default | Meaning |
|-----|---------|---------|
| `friend_mode` | false | The game never applies stealing penalties. It only announces who was seen. |
| `blackout_mode` | false | The lights cut out at random. See stealing.md. |
| `panic_mode` | false | Very short turn timer (Speed/Panic Okey). |

### Yardımcılar (helpers)
| Key | Default | Meaning |
|-----|---------|---------|
| `auto_arrange_allowed` | true | Buttons while reading the rack (best groups, pairs, by colour, by number); R still does the first. |
| `group_hints` | true | Counting: a green / blue / red line under each group on your rack (valid meld with its points, pair, not valid), the total you could open with, and an "El aç" button. Off, you count your own tiles. |

### Masa (table)
| Key | Default | Meaning |
|-----|---------|---------|
| `rack_blindness` | 0.85 | How blind reading your rack makes you: everything above its top edge is smeared and darkened. |

## Presets
- **Klasik 101:** the defaults above.
- **Kahvehane usulü:** `open_must_beat_previous` and `pairs_must_beat_previous` on, `turn_time_limit` 45.
- **Tam kaos:** every stealing zone on, `blackout_mode` on, `catch_window` 2.5.
- **Temiz oyun:** `stealing_enabled` off.

Presets are JSON files holding only the rules they change: built-in ones in `presets/`, the player's own in
`user://presets/`, so players can share their own house rules. Until the lobby exists, pick them on the command line:
`godot --path . -- --preset=kahvehane --set=open_threshold=81`.
