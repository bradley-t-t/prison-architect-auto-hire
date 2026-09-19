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
local COUNT_EVERY = 10          -- seconds between head counts
local HIRE_GAP = 1.5            -- seconds between two arrivals, so a big order trickles in
local MOST = 500                -- ceiling on one kind

local ready = false
local countTimer = math.random() * COUNT_EVERY
local hireTimer = 0
local chosen = 1                -- which kind the buttons are set to
local short = {}                -- kind -> how many are still owed
local heads = {}                -- kind -> the last head count
local awaited = {}              -- kind -> the head count the last arrival should have made
local stopped = {}              -- kind -> true once an arrival went uncounted
local leader = true

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

local function show()
    local kind = KINDS[chosen]
    this.SetInterfaceCaption("StaffKind", "staffing_kind", "staffing_name_" .. kind, "X")
    if kind == "ArmedGuard" then
        this.SetInterfaceCaption("StaffLevel", "staffing_level_lockers", target(kind), "X", heads[kind] or 0, "Y", limit(kind), "Z")
    else
        this.SetInterfaceCaption("StaffLevel", "staffing_level", target(kind), "X", heads[kind] or 0, "Y")
    end
    local owed = 0
    local line = { "tooltip_StaffingTerminal" }
    for i, each in ipairs(KINDS) do
        owed = owed + (short[each] or 0)
        line[#line + 1] = target(each)
        line[#line + 1] = LETTERS[i]
    end
    this.Tooltip = line
    this.SubType = owed > 0 and 1 or 0
end

local function count(kind)
    if kind == "ArmedGuard" then allowed[kind] = armouryLockers() end
    local n = 0
    for _ in pairs(Find(kind, WHOLE_MAP) or {}) do n = n + 1 end
    heads[kind] = n
    if awaited[kind] and n >= awaited[kind] then awaited[kind] = nil end
    short[kind] = math.max(0, target(kind) - n)
end

local function change(by)
    local kind = KINDS[chosen]
    if kind == "ArmedGuard" then allowed[kind] = armouryLockers() end
    local wanted = math.min(limit(kind), math.max(0, target(kind) + by))
    Object.SetProperty("Target" .. kind, wanted)
    stopped[kind], awaited[kind] = nil, nil
    count(kind)
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

local function headCount()
    for _, kind in ipairs(KINDS) do
        if setting(kind) > 0 then count(kind) else short[kind] = 0 end
    end
    show()
end

-- Only one terminal hires. With two on the map each would see the same gap
-- and fill it, so the one with the lowest id does the work and the rest rest.
local function inCharge()
    local mine = tonumber(this.Id.i) or 0
    for other in pairs(Find("StaffingTerminal", WHOLE_MAP) or {}) do
        local theirs = tonumber(other.Id.i) or 0
        if theirs < mine then return false end
    end
    return true
end

-- The head count is taken again the moment before each arrival, so staff you
-- hired by hand since the last count are never doubled. An arrival the next
-- count cannot see means the count cannot be trusted, and that kind stops
-- rather than filling the map.
local function hireOne()
    for _, kind in ipairs(KINDS) do
        if (short[kind] or 0) > 0 and not stopped[kind] then
            local expected = awaited[kind]
            count(kind)
            if expected and heads[kind] < expected then
                stopped[kind] = true
                short[kind] = 0
            elseif heads[kind] < target(kind) and Spawn(kind, this.Pos.x + math.random() - 0.5, this.Pos.y + 1) then
                awaited[kind] = heads[kind] + 1
                heads[kind] = heads[kind] + 1
                short[kind] = math.max(0, target(kind) - heads[kind])
            else
                awaited[kind] = nil
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
        headCount()
    end
    countTimer = countTimer + timePassed
    if countTimer >= COUNT_EVERY then
        countTimer = 0
        leader = inCharge()
        headCount()
    end
    hireTimer = hireTimer + timePassed
    if hireTimer >= HIRE_GAP then
        hireTimer = 0
        if leader then hireOne() end
    end
end
