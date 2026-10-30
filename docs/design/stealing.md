# Stealing, catching and evidence

Settings keys are in [101_rules.md](101_rules.md#çalma-stealing). Code: `scripts/play/stealing.gd` (what is a
theft, calls, giving tiles back), `scripts/play/visibility.gd` (who sees what, witnesses), `scripts/play/bot.gd`
(bot thieves), `scripts/play/watcher.gd` (where bots look). Tests: `tests/stealing_test.gd` (every case below, one
by one) and `tests/game_flow_test.gd -- --stealing` (whole hands with greedy bots: no tile may be lost or doubled).

## Core idea
- The rules engine keeps track of how many tiles each player **should** hold (`OkeyGame.expected`).
- The physical table is the truth of what each player **does** hold.
- A theft moves a tile physically without telling the rules engine. The difference between the two is evidence
  for "Taş say!". Being seen doing it is evidence for "Yakala!".

Nothing stops a player from reaching. The risks are being seen during the act and being counted later.

## Three ways of looking (everyone, bots included)
Every seat says how it is looking (`Seat.look_mode`, `Seat.look_dir`). Bots set it from their Watcher, the player
from his camera. The dayı's body shows it to everyone, so a human can read the table too.

| Mode | Key | Sees | Body |
|------|-----|------|------|
| Observe | (default) | Plain view within 35° of the head direction, corner of the eye out to 70° | Head turned where he looks |
| Rack | Space / right click | Only his own rack and a hand in it. The screen above the rack is blurred and dark (`rack_blindness`) | Head bowed |
| Lean | W / mouse wheel | The whole table from above (melds, pile, discard rows) except his own rack and the strip in front of it (`Seat.LEAN_BLIND`) | Bent over the table |

- Leaning is how you read the melds. While you lean, your own rack is the easiest target at the table.
- Reading your rack protects it, because you would see a hand in it. In return you see nothing else.
- Someone walking between (group `view_blockers`, the çaycı) hides what is behind him.

## What counts as evidence
- The thief's hand once it is away from his own place (`Visibility.OWN_PLACE_*`: his rack, the felt in front of
  it, the corners). A hand busy at one's own rack is nothing to see.
- The tile once it has left where it lay (in a hand, or gliding to one).
- For the first `PLUCK_TIME` (0.5 s), the spot it was taken from. However fast a thief is, that moment can be seen.
- A witness needs `WITNESS_TIME` (0.3 s) of plain view in total. Glances add up; a blink does not count.
- 35-70° off the head direction is the corner of the eye: not evidence. The player gets "◀ Solunda bir kıpırtı" on
  the HUD; a bot turns his head toward it (by his vigilance) and may then see it properly.
- Sound: a tile plucked or put down where it should not be clicks; vigilant bots turn toward the click. Holding
  Shift steals quietly but slowly (the tile follows the hand at a crawl), so the evidence is out longer.

## Steal zones (each has a setting)
1. **Neighbours' racks** (`steal_from_racks`): the opposite rack is out of reach. Reach is measured from where you
   sit, so leaning over the table does not lengthen your arm. Rack tiles face their owner, so you steal blind
   (bots too: they take the end of the rack nearest them).
2. **Discard rows** (`steal_from_discards`): any tile in any row, not only the newest. The rules only allow taking
   the newest tile from the left player's row as your draw; everything else is theft. The row closes up behind it.
3. **The pile** (`steal_from_pile`): drawing when it is not your draw.
4. **Your own tiles, the other way:**
   - **Plant:** put one of your tiles into someone's rack. It is watched from the moment it hovers over his rack.
     A theft plus a plant leaves both counts right, so "Taş say!" cannot catch it. That is the usta's trick.
   - **Dump:** slip one into the pile (it goes to the bottom).
5. Laid melds are not a zone yet. The legal okey swap (`okey_swap_from_table`) exists.

## "Yakala!" (F, at the player you look at)
- Goes to the seat whose head or rack is nearest the middle of your view (`GameDirector.looked_at_seat`). It does not
  work while you read your rack.
- **Right** if that player has a theft in progress or finished within `catch_window` seconds and you are one of its
  witnesses:
  - The tile goes back where it came from: rack slot, place in the discard row, top of the pile. A planted tile
    goes back to the planter; a dumped one comes out of the pile.
  - The thief pays `catch_penalty`. Everyone turns to look at him and he shakes his head.
- **Wrong** otherwise: the caller pays `false_accusation_penalty`. Calls have a 2.5 s cooldown.
- Bots call it when they are witnesses: chance 0.3 + 0.7 × vigilance, after 0.3-0.8 s to take it in.
- While you watch someone's theft, the HUD says "Gördün: X taş çalıyor! F: Yakala!" for the catch window.

## "Taş say!" (C, at the player you look at)
- If he physically holds more than he should (a tile in the player's hand counts if it is his own or stolen, but not
  a legal draw on its way to his rack), he pays `count_check_penalty`. The extra tiles go back, newest theft first,
  and any that cannot be named go into the pile.
- Otherwise the caller pays the same.
- Bots count when their own rack comes up short at the start of their turn (chance by vigilance). Anyone can count
  the backs on a rack, so they only call it on a neighbour who really has too many. Now and then a vigilant bot
  counts the table anyway.

## What the player sees while he steals
An awareness meter over every opponent's head (`Buddy.set_alert_level`), as in stealth games:
- "?" means a glance from the corner of the eye.
- "!" grows from yellow to red as that opponent watches the evidence.
- A big red "!" means he is a witness, and "Yakala!" is coming if he is the kind who calls it.

## Bots
Each bot seat has a level (`GameDirector.LEVELS`, chosen per seat on the "Masa kur" page; everyone else will be a real person online):

| Level | skill | vigilance | greed | swaps |
|-------|-------|-----------|-------|-------|
| Kolay | 0.6 | 0.3 | 0.10 | no |
| Normal | 0.85 | 0.55 | 0.20 | no |
| Zor | 0.95 | 0.8 | 0.35 | yes |

The room rule `bots_steal` ("Botlar taş çalar") off sets greed to 0 for every bot.

- **Vigilance:** how often he looks up from his rack (and how long he stays down), how likely he is to hear a click or
  turn to a glimpse, call what he saw, and count when short.
- **Greed:**
  - Out of his turn (and not when his own turn is next), every 1.2-2.6 s he looks for a target nobody can see
    (`Stealing.opportunity`).
  - A greedy bot (greed > 0.5) risks being glimpsed by someone other than the victim; the victim must not see even
    that much.
  - He steals with his real hands (`DayiHands.snatch`): he leans right over toward the target (`STRETCH`, in the
    direction of the reach), stretches out, and the tile comes the last stretch to his fingertips.
- **Swaps:** an usta later plants his least useful tile back into the victim's rack, when nobody is looking at it.

## Friend mode
No penalties are written. Calls are announced in the event feed ("... (arkadaş modu, ceza yok)") and players settle
it themselves.

## Hooks for later modes (guncellemeOnerisi.md)
- **Blackout:** the room lights fade out on a timer. `Visibility.sees` gets a light factor.
- **Distractions:** table tap, lighter, radio, a goal on the TV. `Watcher.notice(point)` already turns heads toward
  a point; the player gets a HUD cue.
- **Drink spill:** a timed blur on one player's camera, his look mode forced to RACK.
- **Bomb tile:** a special tile with a timer. Passing it into another rack is a plant.
- **Stealing from laid melds:** swap a rack tile into a meld and take the okey out. Valid swaps are silent; invalid
  ones leave evidence on the table.
- **Replay of the catch:** the last 3 s from the catcher's eyes (YAPILACAKLAR 6).
