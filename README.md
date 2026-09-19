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
janitors, gardeners and doctors. Every ten seconds the terminal counts each
kind it has a number for, and while one is short a new member of staff arrives
at the terminal every second and a half. Its screen is blue while it is hiring
and green when every post is filled, and hovering over it lists every number.

It never goes over the number. The head count is taken again the moment
before each arrival, so staff you hired by hand since the last count are not
doubled. If an arrival does not show up in the next count, the count cannot be
trusted and that kind stops hiring until its number is changed. With two
terminals on the map, only the older one hires.

It holds to the game's own cap. The game lets you hire one Armed Guard for
each Guard Locker standing in an Armoury and caps no other kind of staff, so
the Armed Guard number stops at your lockers and its readout says how many
they allow. Sell a locker and the number the terminal works to drops with it.
A script cannot read what a room is, so an Armoury is taken to be a room that
also holds a Weapon Rack, which every Armoury must.

It never fires anybody. A number set under the head count is met by not
replacing the ones who leave. One terminal covers the whole prison.

## What it cannot do

A script cannot reach the prison's money, so an arrival skips the hiring fee.
Wages are paid like any other staff. It cannot read research either, so a
number set for a kind that is not unlocked yet is still filled.

## Layout

| Path | Holds |
| :--- | :--- |
| `data/scripts/StaffingTerminal.lua` | The terminal, written by hand |
| `tools/gen_assets.py` | Builds the sprites, `materials.txt`, the language file and the thumbnail |
| `tools/simulate.py` | Runs the script against a stand-in for the game and checks it |

Install by copying `manifest.txt`, `thumbnail.png` and `data/` into a folder
under the game's `mods` directory and turning the mod on in the game.
