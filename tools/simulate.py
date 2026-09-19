"""Runs data/scripts/StaffingTerminal.lua against a stand-in for the game and
checks what it does: that it hires up to the number set and no further, that
it replaces staff who leave, that it never removes anybody, and that with
every number at zero it searches the map for nobody.

Usage: python simulate.py      (needs lupa)
"""

import os
import sys

from lupa import LuaRuntime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "data", "scripts", "StaffingTerminal.lua")

lua = LuaRuntime(unpack_returned_tuples=True)
staff = {}          # kind -> head count on the map
searches = [0]
captions = {}


cap = [None]        # the most one search may return, to stand in for a count that cannot be trusted
others = []         # ids of other terminals on the map


lockers = {"armoury": 0, "elsewhere": 0}      # Guard Lockers in the Armoury and in a room with no Weapon Rack
PLACED = lua.eval("function(x, n) local t = {} for _ = 1, n do t[{ Pos = { x = x, y = 1 } }] = 1 end return t end")


def find(kind, _reach):
    if kind == "WeaponRack":
        return PLACED(1, 1)
    if kind == "GuardLocker":
        both = PLACED(1, lockers["armoury"])
        for k in PLACED(2, lockers["elsewhere"]):
            both[k] = 1
        return both
    if kind == "StaffingTerminal":
        return lua.eval("function(ids) local t = {} for _, i in ipairs(ids) do t[{ Id = { i = i } }] = 1 end return t end")(lua.table_from(others))
    searches[0] += 1
    if cap[0] is not None:
        return lua.table_from({f"{kind}{i}": "1" for i in range(min(cap[0], staff.get(kind, 0)))})
    return lua.table_from({f"{kind}{i}": "1" for i in range(staff.get(kind, 0))})


def spawn(kind, _x, _y):
    staff[kind] = staff.get(kind, 0) + 1
    return f"{kind}{staff[kind]}"


g = lua.globals()
this = lua.eval("{ Pos = { x = 10, y = 10 }, Id = { i = 50 } }")
this.SetInterfaceCaption = lambda name, *args: captions.__setitem__(name, args)
g.this = this
g.Object = lua.table_from({
    "GetNearbyObjects": find,
    "Spawn": spawn,
    "SetProperty": lambda name, value: this.__setitem__(name, value),
})
g.World = lua.eval("{ GetCell = function(x, y) return { Room = { i = x, u = x + 100 } } end }")
g.Interface = lua.table_from({"AddComponent": lambda *a: None})
lua.execute(open(SCRIPT).read())


def run(seconds, step=0.1):
    for _ in range(int(seconds / step)):
        g.Update(str(step))


failures = []


def check(what, ok):
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        failures.append(what)


g.Create()
run(60)
check("nothing set: nobody hired", sum(staff.values()) == 0)
check("nothing set: no map searches after the first look", searches[0] <= 1)

staff["Guard"] = 3
for _ in range(12):
    g.StaffMoreClicked()                       # Guards to 12
run(60)
check("guards brought up from 3 to 12", staff["Guard"] == 12)
run(120)
check("and held there", staff["Guard"] == 12)

staff["Guard"] = 7                             # five quit or die
run(60)
check("the five who left are replaced", staff["Guard"] == 12)

g.StaffLess10Clicked()                         # Guards to 2
run(120)
check("a lower number fires nobody", staff["Guard"] == 12)

g.StaffKindClicked()                           # Armed Guards
lockers["elsewhere"] = 40
g.StaffMore10Clicked()
run(60)
check("no lockers in an Armoury: no Armed Guards", staff.get("ArmedGuard", 0) == 0 and this.TargetArmedGuard == 0)
lockers["armoury"] = 6
g.StaffMore10Clicked()
run(60)
check("six lockers: the number stops at 6", this.TargetArmedGuard == 6 and staff.get("ArmedGuard") == 6)
lockers["armoury"] = 4
staff["ArmedGuard"] = 3
run(60)
check("a locker sold lowers the cap", staff["ArmedGuard"] == 4)
lockers["armoury"] = 600
staff["ArmedGuard"] = 0
this.TargetArmedGuard = 0
g.StaffMore10Clicked()
run(60)
check("the next kind is set on its own", staff.get("ArmedGuard") == 10 and staff["Guard"] == 12)
check("the caption names the kind", captions["StaffKind"][1] == "staffing_name_ArmedGuard")

for _ in range(60):
    g.StaffMore10Clicked()
check("a kind stops at 500", this.TargetArmedGuard == 500)

g.StaffKindClicked()                           # Dog Handlers
g.StaffMore10Clicked()
staff["DogHandler"] = 10                       # hired by hand before the terminal's next look
run(60)
check("staff hired by hand are not doubled", staff["DogHandler"] == 10)

g.StaffKindClicked()                           # Snipers
cap[0] = 4
for _ in range(3):
    g.StaffMore10Clicked()
run(300)
check("a count that cannot see arrivals stops the hiring", staff.get("Sniper", 0) <= 5)
cap[0] = None

g.StaffKindClicked()                           # Workmen
others.append(7)                               # an older terminal exists
run(15)
g.StaffMore10Clicked()
run(60)
check("a second terminal hires nobody", staff.get("Workman", 0) == 0)

print("failures:", len(failures))
sys.exit(1 if failures else 0)
