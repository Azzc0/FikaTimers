local AceLibrary = AceLibrary
local BigWigs = BigWigs

local FikaTimers = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceEvent-2.0")

-- Timer tracking
FikaTimers.scheduledTimers = {}
FikaTimers.lastCheck = nil

function FikaTimers:OnEnable()
    -- Initialize scheduledTimers
    self.scheduledTimers = {}
    self.lastCheck = nil
    
    -- Create and store frame reference
    self.checkFrame = CreateFrame("Frame", "FikaTimersCheckFrame")
    
    -- Store self reference for OnUpdate
    local addon = self
    
    -- Set update script
    self.checkFrame:SetScript("OnUpdate", function(frame, elapsed)
        local currentTime = date("%H:%M")
        if currentTime ~= addon.lastCheck then
            addon.lastCheck = currentTime
            addon:CheckScheduledTimers()
        end
    end)
    
    -- Register slash commands
    self:RegisterChatCommand("ft", function(input)
        local command = string.lower(input)
        if command == "list" then
            self:ListScheduledTimers()
        elseif command == "clear" then
            self:ClearScheduledTimers()
        elseif string.find(command, "^schedule%s+") then
            self:HandleScheduledTimer(string.sub(command, 9))
        elseif string.find(command, "^timer%s+") then
            self:HandleTimer(string.sub(command, 6))
        else
            self:Print("Usage: /ft {timer <duration> <name>|schedule HH:MM <duration>m <name>|list|clear}")
        end
    end)
    
    -- Register as BigWigs module
    BigWigs:RegisterModule(self)
end

function FikaTimers:HandleTimer(input)
    if not input or input == "" then
        self:Print("Usage: /ft timer <duration> <name>")
        return
    end

    -- Parse duration and name
    local _, _, duration, name = string.find(input, "(%d+)%s+(.+)")
    if not (duration and name) then
        self:Print("Usage: /ft timer <duration> <name>")
        return
    end

    BWCB(tonumber(duration), name)
end

function FikaTimers:HandleScheduledTimer(input)
    if not input or input == "" then
        self:Print("Usage: /ft schedule HH:MM <duration>m <name>")
        return
    end

    local _, _, hour, min, duration, name = string.find(input, "(%d+):(%d+)%s+(%d+)m%s+(.+)")
    if not (hour and min and duration and name) then
        self:Print("Usage: /ft schedule HH:MM <duration>m <name>")
        return
    end

    -- Convert to numbers
    hour = tonumber(hour)
    min = tonumber(min)
    duration = tonumber(duration)

    -- Validate time format
    if hour < 0 or hour > 23 or min < 0 or min > 59 then
        self:Print("Invalid time format. Use 24-hour format (00:00 - 23:59)")
        return
    end

    -- Calculate start time (end time minus duration)
    local totalMinutes = hour * 60 + min - duration
    if totalMinutes < 0 then
        totalMinutes = totalMinutes + (24 * 60)
    end

    local startHour = math.floor(totalMinutes / 60)
    local startMin = math.mod(totalMinutes, 60)

    -- Format time strings using concatenation
    local startTime = string.format("%.2d:%.2d", startHour, startMin)
    local endTime = string.format("%.2d:%.2d", hour, min)
    
    -- Store scheduled timer with start time
    table.insert(self.scheduledTimers, {
        time = startTime,
        duration = duration,
        name = name,
        executed = false,
        endTime = endTime
    })
    
    self:Print(string.format("Scheduled \"%s\" (%dm) to end at %s", name, duration, endTime))
end

function FikaTimers:CheckScheduledTimers()
    local now = date("%H:%M")
    
    for _, timer in ipairs(self.scheduledTimers) do
        if timer.time == now and not timer.executed then
            BWCB(timer.duration * 60, timer.name)
            timer.executed = true
            self:Print(string.format("Starting timer: %s", timer.name))
        end
    end
    
    -- Clean up executed timers
    for i = table.getn(self.scheduledTimers), 1, -1 do
        if self.scheduledTimers[i].executed then
            table.remove(self.scheduledTimers, i)
        end
    end
end

function FikaTimers:StartTimer(name, duration)
    if not name or not duration then
        self:Print("Invalid timer parameters")
        return
    end
    
    BWCB(duration, name)
end

function FikaTimers:ListScheduledTimers()
    if table.getn(self.scheduledTimers) == 0 then
        self:Print("No timers scheduled")
        return
    end
    
    self:Print("Scheduled timers:")
    for i, timer in ipairs(self.scheduledTimers) do
        self:Print(string.format("[%d] \"%s\" (%dm) ends at %s", 
            i, timer.name, timer.duration, timer.endTime))
    end
end

function FikaTimers:ClearScheduledTimers()
    self.scheduledTimers = {}
    self:Print("Schedule cleared")
end

function FikaTimers:OnInitialize()
    self:RegisterChatCommand({ "/ft", "/fikatimer" }, {
        type = "group",
        args = {
            timer = {
                type = "text",
                name = "Timer",
                desc = "Create a timer bar",
                usage = "<duration> <name>",
                get = false,
                set = function(v) self:HandleTimer(v) end,
            },
            schedule = {
                type = "text",
                name = "Schedule",
                desc = "Schedule a timer for specific time",
                usage = "HH:MM <duration>m <name>",
                get = false,
                set = function(v) self:HandleScheduledTimer(v) end,
            },
            list = {
                type = "execute",
                name = "List",
                desc = "List all scheduled timers",
                func = function() self:ListScheduledTimers() end,
            },
            clear = {
                type = "execute",
                name = "Clear",
                desc = "Clear all scheduled timers",
                func = function() self:ClearScheduledTimers() end,
            }
        }
    })
end