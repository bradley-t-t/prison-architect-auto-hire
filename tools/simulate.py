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


def find(kind, _reach):
    searches[0] += 1
    return lua.table_from({f"{kind}{i}": "1" for i in range(staff.get(kind, 0))})


def spawn(kind, _x, _y):
    staff[kind] = staff.get(kind, 0) + 1
    return f"{kind}{staff[kind]}"


g = lua.globals()
this = lua.eval("{ Pos = { x = 10, y = 10 } }")
this.SetInterfaceCaption = lambda name, *args: captions.__setitem__(name, args)
g.this = this
g.Object = lua.table_from({
    "GetNearbyObjects": find,
    "Spawn": spawn,
    "SetProperty": lambda name, value: this.__setitem__(name, value),
})
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
g.StaffMore10Clicked()
run(60)
check("the next kind is set on its own", staff.get("ArmedGuard") == 10 and staff["Guard"] == 12)
check("the caption names the kind", captions["StaffKind"][1] == "staffing_name_ArmedGuard")

for _ in range(60):
    g.StaffMore10Clicked()
check("a kind stops at 500", this.TargetArmedGuard == 500)

print("failures:", len(failures))
sys.exit(1 if failures else 0)
