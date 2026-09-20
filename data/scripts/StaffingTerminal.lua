-- The Staffing Terminal keeps each kind of staff at the number set on it. It
-- counts who is on the map, and when a kind is under its number it brings one
-- in at the terminal. It never fires anybody: a number set under the head
-- count is met by not replacing the ones who leave.
--
-- A script cannot reach the prison's money, so nobody brought in here pays a
-- hiring fee. They are staff like any other from then on, wages included.

local Find = Object.GetNearbyObjects
local Spawn = Object.Spawn

-- The order the Staff button steps through. Each name is the object type, the
-- end of its Target property and the end of its language keys.
local KINDS = { "Guard", "ArmedGuard", "DogHandler", "Sniper", "Workman", "Cook", "Janitor", "Gardener", "Doctor" }
local LETTERS = { "A", "B", "C", "D", "E", "F", "G", "H", "I" }

local WHOLE_MAP = 5000
local ROUND = 3                 -- seconds between head counts, one kind of staff a round, while a kind is short
local RESTING_ROUND = 8         -- the same with every post filled, when nothing is waiting on a count
local BATCH = 5                 -- the most one head count may bring in
local HIRE_GAP = 0.5            -- seconds between two arrivals
local LEAD_EVERY = 30           -- seconds between looks for an older terminal
local MOST = 500                -- ceiling on one kind

local ready = false
local roundTimer = math.random() * ROUND
local hireTimer = 0
local leadTimer = LEAD_EVERY
local leader = true
local turn = 0                  -- the kind counted last
local chosen = 1                -- which kind the buttons are set to
local short = {}                -- kind -> arrivals still owed from its last head count
local heads = {}                -- kind -> the last head count
local shown = ""                -- what the window and tooltip last said
local wasShort = {}             -- kind -> whether its last head count came up short
local hiring = true             -- whether any kind did

local allowed = {}              -- kind -> the most the game itself would let you hire

local function roomOf(object)
    local cell = World.GetCell(math.floor(object.Pos.x), math.floor(object.Pos.y))
    local room = cell and cell.Room
    if not room or (tonumber(room.i) or -1) < 0 then return nil end
    return room.i .. ":" .. room.u
end

-- The game lets you hire one Armed Guard for each Guard Locker standing in an
-- Armoury, and caps no other kind here. A script cannot read what a room is,
-- so an Armoury is taken to be a room that also holds a Weapon Rack, which
-- every Armoury must.
local function armouryLockers()
    local armouries = {}
    for rack in pairs(Find("WeaponRack", WHOLE_MAP) or {}) do
        local room = roomOf(rack)
        if room then armouries[room] = true end
    end
    local n = 0
    for locker in pairs(Find("GuardLocker", WHOLE_MAP) or {}) do
        local room = roomOf(locker)
        if room and armouries[room] then n = n + 1 end
    end
    return n
end

local function limit(kind)
    if kind == "ArmedGuard" then return math.min(MOST, allowed[kind] or 0) end
    return MOST
end

local function setting(kind)
    return tonumber(this["Target" .. kind]) or 0
end

-- What the terminal works to: the number set, held under the game's own cap
-- even when the cap has dropped since, as when a locker is sold.
local function target(kind)
    return math.min(setting(kind), limit(kind))
end

-- Writing a caption or a tooltip is a call into the game, so nothing is
-- written that the window already says.
local function show()
    local kind = KINDS[chosen]
    local owed = 0
    local line = { "tooltip_StaffingTerminal" }
    for i, each in ipairs(KINDS) do
        owed = owed + math.max(0, target(each) - (heads[each] or target(each)))
        line[#line + 1] = target(each)
        line[#line + 1] = LETTERS[i]
    end
    local says = table.concat(line, ",") .. "|" .. kind .. "|" .. (heads[kind] or 0) .. "|" .. limit(kind) .. "|" .. owed
    if says == shown then return end
    shown = says
    this.SetInterfaceCaption("StaffKind", "staffing_kind", "staffing_name_" .. kind, "X")
    if kind == "ArmedGuard" then
        this.SetInterfaceCaption("StaffLevel", "staffing_level_lockers", target(kind), "X", heads[kind] or 0, "Y", limit(kind), "Z")
    else
        this.SetInterfaceCaption("StaffLevel", "staffing_level", target(kind), "X", heads[kind] or 0, "Y")
    end
    this.Tooltip = line
    this.SubType = owed > 0 and 1 or 0
end

-- The head count is the living staff of one kind. A body waiting for the
-- hearse is still a Guard to the game, and counting it leaves the post empty.
-- The game keeps no flag for the dead: a body is a member of staff whose
-- Damage has reached 1.
-- A search of the map is the dearest thing a script can ask for, so a count
-- is taken for one kind a round and never while that kind's last batch is
-- still arriving: what a count orders is bounded by that count.
local function count(kind)
    if kind == "ArmedGuard" then allowed[kind] = armouryLockers() end
    local found = Find(kind, WHOLE_MAP)
    if not found then
        short[kind] = 0
        return
    end
    local n = 0
    for member in pairs(found) do
        if (tonumber(member.Damage) or 0) < 1 then n = n + 1 end
    end
    heads[kind] = n
    short[kind] = math.min(BATCH, math.max(0, target(kind) - n))
end

local function change(by)
    local kind = KINDS[chosen]
    if kind == "ArmedGuard" then allowed[kind] = armouryLockers() end
    local wanted = math.min(limit(kind), math.max(0, target(kind) + by))
    Object.SetProperty("Target" .. kind, wanted)
    count(kind)
    wasShort[kind] = (short[kind] or 0) > 0
    hiring = hiring or wasShort[kind]
    show()
end

-- The game calls <component name>Clicked on this script.
function StaffKindClicked()
    chosen = chosen % #KINDS + 1
    count(KINDS[chosen])
    show()
end
function StaffLess10Clicked() change(-10) end
function StaffLessClicked() change(-1) end
function StaffMoreClicked() change(1) end
function StaffMore10Clicked() change(10) end

-- Counts the next kind that has a number set and no batch still arriving.
local function nextCount()
    for _ = 1, #KINDS do
        turn = turn % #KINDS + 1
        local kind = KINDS[turn]
        if setting(kind) > 0 and (short[kind] or 0) == 0 then
            count(kind)
            wasShort[kind] = (short[kind] or 0) > 0
            hiring = false
            for _, each in ipairs(KINDS) do hiring = hiring or wasShort[each] == true end
            show()
            return
        end
    end
end

-- Only one terminal hires. With two on the map each would see the same gap
-- and fill it, so the one with the lowest id does the work and the rest rest.
local function inCharge()
    local mine = tonumber(this.Id.i) or 0
    for other in pairs(Find("StaffingTerminal", WHOLE_MAP) or {}) do
        local theirs = tonumber(other.Id.i)
        if theirs and theirs < mine then return false end
    end
    return true
end

local function hireOne()
    for _, kind in ipairs(KINDS) do
        if (short[kind] or 0) > 0 then
            short[kind] = short[kind] - 1
            if heads[kind] < target(kind) and Spawn(kind, this.Pos.x + math.random() - 0.5, this.Pos.y + 1) then
                heads[kind] = heads[kind] + 1
            else
                short[kind] = 0
            end
            show()
            return
        end
    end
end

local function addControls()
    for _, kind in ipairs(KINDS) do
        if this["Target" .. kind] == nil then Object.SetProperty("Target" .. kind, 0) end
    end
    Interface.AddComponent(this, "StaffKind", "Button", "staffing_kind", "staffing_name_" .. KINDS[chosen], "X")
    Interface.AddComponent(this, "StaffLevel", "Caption", "staffing_level", 0, "X", 0, "Y")
    Interface.AddComponent(this, "StaffLess10", "Button", "staffing_less10")
    Interface.AddComponent(this, "StaffLess", "Button", "staffing_less")
    Interface.AddComponent(this, "StaffMore", "Button", "staffing_more")
    Interface.AddComponent(this, "StaffMore10", "Button", "staffing_more10")
end

function Create()
    for _, kind in ipairs(KINDS) do Object.SetProperty("Target" .. kind, 0) end
end

function Update(timePassed)
    timePassed = tonumber(timePassed) or 0
    if not ready then
        addControls()
        ready = true
        show()
    end
    leadTimer = leadTimer + timePassed
    if leadTimer >= LEAD_EVERY then
        leadTimer = 0
        leader = inCharge()
    end
    if not leader then return end
    roundTimer = roundTimer + timePassed
    if roundTimer >= (hiring and ROUND or RESTING_ROUND) then
        roundTimer = 0
        nextCount()
    end
    hireTimer = hireTimer + timePassed
    if hireTimer >= HIRE_GAP then
        hireTimer = 0
        hireOne()
    end
end

-- Every scripted object is a Lua state of its own, and what a script drops
-- stays in memory until a collection runs. A full one every GC_EVERY seconds
-- keeps a long session from piling it up. The state is small, so it is cheap.
local GC_EVERY = 20
local gcTimer = math.random() * GC_EVERY
local runUpdate = Update
function Update(timePassed)
    gcTimer = gcTimer + timePassed
    if gcTimer >= GC_EVERY then
        gcTimer = 0
        if collectgarbage then collectgarbage("collect") end
    end
    return runUpdate(timePassed)
end
