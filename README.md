# Auto Hire

A Prison Architect mod. Prison Architect has no way to keep staff at a set
number: every hire is a click, and a guard who dies or quits stays gone until
somebody notices. This adds one object that does the noticing.

## The Staffing Terminal

Build one anywhere. Click it and its window has one row of controls:

| Control | Does |
| :--- | :--- |
| `Staff: Guards` | Steps to the next kind of staff |
| `Keep 12, have 9` | The number set for that kind and the head count |
| `-10` `-1` `+1` `+10` | Change the number, from 0 to 500 |

The kinds are guards, armed guards, dog handlers, snipers, workmen, cooks,
janitors, gardeners and doctors. Every three seconds while any kind is short, and every eight once every post
is filled, the terminal counts the living staff of one kind that has a number
set, and when that kind is short it
brings in up to five at the terminal, half a second apart, before it counts
that kind again. A body waiting for the hearse is not staff. Its screen is
blue while it is hiring and green when every post is filled, and hovering over
it lists every number.

A search of the map is the dearest thing a script can ask the game for, so the
terminal makes one a round and none at all with no numbers set, and it writes
to its window only when what the window says has changed.

It holds to the game's own cap. The game lets you hire one Armed Guard for
each Guard Locker standing in an Armoury and caps no other kind of staff, so
the Armed Guard number stops at your lockers and its readout says how many
they allow. Sell a locker and the number the terminal works to drops with it.
A script cannot read what a room is, so an Armoury is taken to be a room that
also holds a Weapon Rack, which every Armoury must.

Staff you hire by hand in the seconds a batch is arriving can put a kind over
its number by that batch, five at most. With two terminals on the map, only
the older one hires.

It never fires anybody. A number set under the head count is met by not
replacing the ones who leave. One terminal covers the whole prison.

## What it costs

Every arrival pays the game's own hiring fee out of the prison's balance, and
draws wages like any other staff. The terminal hires whether or not the money
is there, so a big order on a small balance puts you in the red.

## What it cannot do

It cannot read research, so a number set for a kind that is not unlocked yet is
still filled.

## Layout

| Path | Holds |
| :--- | :--- |
| `data/scripts/StaffingTerminal.lua` | The terminal, written by hand |
| `tools/gen_assets.py` | Builds the sprites, `materials.txt`, the language file and the thumbnail |
| `tools/simulate.py` | Runs the script against a stand-in for the game and checks it |

Install by copying `manifest.txt`, `thumbnail.png` and `data/` into a folder
under the game's `mods` directory and turning the mod on in the game.
