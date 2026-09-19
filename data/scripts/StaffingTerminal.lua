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

local function target(kind)
    return tonumber(this["Target" .. kind]) or 0
end

local function show()
    local kind = KINDS[chosen]
    this.SetInterfaceCaption("StaffKind", "staffing_kind", "staffing_name_" .. kind, "X")
    this.SetInterfaceCaption("StaffLevel", "staffing_level", target(kind), "X", heads[kind] or 0, "Y")
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
    local n = 0
    for _ in pairs(Find(kind, WHOLE_MAP) or {}) do n = n + 1 end
    heads[kind] = n
    short[kind] = math.max(0, target(kind) - n)
end

local function change(by)
    local kind = KINDS[chosen]
    local wanted = math.min(MOST, math.max(0, target(kind) + by))
    Object.SetProperty("Target" .. kind, wanted)
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
        if target(kind) > 0 then count(kind) else short[kind] = 0 end
    end
    show()
end

local function hireOne()
    for _, kind in ipairs(KINDS) do
        if (short[kind] or 0) > 0 then
            short[kind] = short[kind] - 1
            if Spawn(kind, this.Pos.x + math.random() - 0.5, this.Pos.y + 1) then
                heads[kind] = (heads[kind] or 0) + 1
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
        headCount()
    end
    hireTimer = hireTimer + timePassed
    if hireTimer >= HIRE_GAP then
        hireTimer = 0
        hireOne()
    end
end
