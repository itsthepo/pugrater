---@diagnostic disable: undefined-global
local addonName, addon = ...
addon.DB_VERSION = 1

local function debug(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater]|r " .. tostring(msg))
end

-- Initialize SavedVariables
function addon:InitDB()
  if not PugRaterDB or not PugRaterDB.version then
    PugRaterDB = {
      version = addon.DB_VERSION,
      players = {}, -- [normalizedFullName] = { rating = 1-5, note = "", lastSeen = time(), timesGrouped = 0 }
      history = {}, -- array of { player=, date=, instanceId=, instanceName= }
      options = { notifyOnJoin = true, minBadRating = 2 }
    }
  end
end

-- Utility: normalize name-realm using WoW API (handles same realm)
local function NormalizeName(fullName)
  if not fullName or fullName == "" then return nil end
  local name, realm = fullName:match("([^%-]+)%-?(.*)")
  if realm == nil or realm == "" then
    realm = GetNormalizedRealmName()
  else
    realm = realm:gsub("%s","")
  end
  return name .. "-" .. realm
end

-- Accessors
function addon:GetPlayer(name)
  local key = NormalizeName(name)
  if not key then return nil, nil end
  PugRaterDB.players[key] = PugRaterDB.players[key] or { rating = 0, note = "", lastSeen = 0, timesGrouped = 0 }
  return PugRaterDB.players[key], key
end

function addon:SetRating(name, rating, note)
  local rec = select(1, addon:GetPlayer(name))
  if not rec then return end
  rec.rating = tonumber(rating) or 0
  if note ~= nil then rec.note = tostring(note) end
  rec.lastSeen = time()
end

function addon:IncrementTimesGrouped(name)
  local rec = select(1, addon:GetPlayer(name))
  if not rec then return end
  rec.timesGrouped = (rec.timesGrouped or 0) + 1
  rec.lastSeen = time()
end

-- Messaging
local function NotifySelf(msg)
  local me = UnitName("player")
  SendChatMessage(msg, "WHISPER", nil, me)
end

local function SystemMessage(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffd100[PugRater]|r " .. msg)
end

-- UI stub, implemented in UI.lua
function addon:ShowRateFrame(playerName)
  if addon.UI and addon.UI.Show then
    addon.UI:Show(playerName)
  else
    SystemMessage("UI not loaded")
  end
end

-- Group tracking
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

local lastGroupMembers = {}

local function ScanGroup()
  local num = GetNumGroupMembers()
  local isInGroup = IsInGroup()
  if not isInGroup then
    lastGroupMembers = {}
    return
  end

  local unitPrefix = IsInRaid() and "raid" or "party"
  local count = IsInRaid() and num or (num - 1) -- party includes player

  local seen = {}
  for i = 1, count do
    local unit = unitPrefix .. i
    local name = GetUnitName(unit, true) -- with realm
    if name then
      local rec, key = addon:GetPlayer(name)
      if key then seen[key] = true end
      if rec and key then
        if not lastGroupMembers[key] then
          -- newly seen joiner
          addon:IncrementTimesGrouped(name)
          if PugRaterDB.options.notifyOnJoin and rec.rating > 0 then
            local msg = string.format("You have played with %s before. Rating: %d. Note: %s", key, rec.rating, rec.note or "")
            if rec.rating <= (PugRaterDB.options.minBadRating or 2) then
              NotifySelf("[PugRater] WARNING: " .. msg)
            else
              SystemMessage(msg)
            end
          end
        end
      end
      if key then lastGroupMembers[key] = true end
    end
  end

  -- remove those who left
  for k in pairs(lastGroupMembers) do
    if not seen[k] then lastGroupMembers[k] = nil end
  end
end

local function AddMenuEntry()
  if not UnitPopupButtons or not UnitPopupMenus then return end

  if not UnitPopupButtons["PUGRATER_RATE"] then
    UnitPopupButtons["PUGRATER_RATE"] = { text = "Rate Player", dist = 0 }
  end

  local function insertAfter(menu, afterKey, newKey)
    local t = UnitPopupMenus[menu]
    if not t then return end
    local idx
    for i, v in ipairs(t) do if v == afterKey then idx = i; break end end
    if not idx then
      -- avoid duplicates
      for _, v in ipairs(t) do if v == newKey then return end end
      table.insert(t, newKey)
    else
      -- avoid duplicates
      for _, v in ipairs(t) do if v == newKey then return end end
      table.insert(t, idx + 1, newKey)
    end
  end

  -- Common player menus
  local menus = {
    { name = "PLAYER", after = "INSPECT" },
    { name = "PARTY", after = "INSPECT" },
    { name = "RAID_PLAYER", after = "INSPECT" },
    { name = "FRIEND", after = "WHISPER" },
    { name = "TARGET", after = "INSPECT" },
    { name = "CHAT_ROSTER", after = "WHISPER" },
    { name = "GUILD", after = "WHISPER" },
  }
  for _, m in ipairs(menus) do insertAfter(m.name, m.after, "PUGRATER_RATE") end

  if hooksecurefunc then
    hooksecurefunc("UnitPopup_OnClick", function(self)
      if self and self.value == "PUGRATER_RATE" then
        local dropdown = UIDROPDOWNMENU_INIT_MENU
        local name
        if dropdown and dropdown.unit then
          name = GetUnitName(dropdown.unit, true)
        elseif dropdown and dropdown.name then
          name = dropdown.name
          if dropdown.server and dropdown.server ~= "" and name and not name:find("-", 1, true) then
            name = name .. "-" .. dropdown.server
          end
        end
        if name then addon:ShowRateFrame(name) end
      end
    end)
  end
end

-- Event handling
frame:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    addon:InitDB()
    -- Hook invites you send
    if hooksecurefunc then
      if InviteUnit then
        hooksecurefunc("InviteUnit", function(invitee)
          local rec, key = addon:GetPlayer(invitee)
          if rec and key and rec.rating and rec.rating > 0 then
            local msg = string.format("Inviting %s. Prior rating %d. Note: %s", key, rec.rating, rec.note or "")
            if rec.rating <= (PugRaterDB.options.minBadRating or 2) then
              NotifySelf("[PugRater] WARNING: " .. msg)
            else
              SystemMessage(msg)
            end
          end
        end)
      end
      if C_PartyInfo and C_PartyInfo.InviteUnit then
        hooksecurefunc(C_PartyInfo, "InviteUnit", function(_, invitee)
          local rec, key = addon:GetPlayer(invitee)
          if rec and key and rec.rating and rec.rating > 0 then
            local msg = string.format("Inviting %s. Prior rating %d. Note: %s", key, rec.rating, rec.note or "")
            if rec.rating <= (PugRaterDB.options.minBadRating or 2) then
              NotifySelf("[PugRater] WARNING: " .. msg)
            else
              SystemMessage(msg)
            end
          end
        end)
      end
    end
    -- Add right-click context menu item
    AddMenuEntry()
  end
  ScanGroup()
end)

-- Dungeon completion detection to trigger rating UI
local instFrame = CreateFrame("Frame")
instFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
instFrame:RegisterEvent("CHALLENGE_MODE_START")
instFrame:RegisterEvent("SCENARIO_COMPLETED")
instFrame:RegisterEvent("LFG_COMPLETION_REWARD")
instFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

-- Track mythic keystone run data
local currentRun = {
  isActive = false,
  startTime = nil,
  mapID = nil,
  level = nil,
  members = {},
  completed = false,
  inTime = false,
  bossesKilled = 0,
  totalBosses = 0
}

local function ResetRunData()
  currentRun = {
    isActive = false,
    startTime = nil,
    mapID = nil,
    level = nil,
    members = {},
    completed = false,
    inTime = false,
    bossesKilled = 0,
    totalBosses = 0
  }
end

local function CaptureGroupMembers()
  local members = {}
  if not IsInGroup() then return members end
  
  local unitPrefix = IsInRaid() and "raid" or "party"
  local num = GetNumGroupMembers()
  local count = IsInRaid() and num or (num - 1)
  
  for i = 1, count do
    local unit = unitPrefix .. i
    local name, realm = UnitName(unit)
    if name then
      -- Ensure we have full name-realm format
      local fullName = name
      if realm and realm ~= "" then
        fullName = name .. "-" .. realm
      elseif not name:find("-") then
        -- Add current realm if no realm specified
        fullName = name .. "-" .. GetNormalizedRealmName()
      end
      table.insert(members, fullName)
      debug("Captured member: " .. fullName)
    end
  end
  return members
end

local function RecordRunCompletion(completed, inTime)
  if not currentRun.isActive then 
    debug("RecordRunCompletion called but no active run!")
    return 
  end
  
  debug(string.format("RecordRunCompletion: completed=%s, inTime=%s, members=%d", 
        tostring(completed), tostring(inTime), #currentRun.members))
  
  currentRun.completed = completed
  currentRun.inTime = inTime
  
  -- Get dungeon name from mapID
  local dungeonName = "Unknown Dungeon"
  if currentRun.mapID then
    dungeonName = C_ChallengeMode.GetMapUIInfo(currentRun.mapID) or "Unknown Dungeon"
  end
  
  -- Store run data in history
  local runData = {
    date = time(),
    mapID = currentRun.mapID,
    dungeonName = dungeonName,
    level = currentRun.level,
    completed = completed,
    inTime = inTime,
    duration = currentRun.completionTime or (currentRun.startTime and (time() - currentRun.startTime) or 0),
    members = currentRun.members
  }
  
  -- Add to history
  PugRaterDB.history = PugRaterDB.history or {}
  table.insert(PugRaterDB.history, runData)
  
  -- Also add to activities for individual player logs
  PugRaterDB.activities = PugRaterDB.activities or {}
  
  debug("Adding activities for members:")
  for _, memberName in ipairs(currentRun.members) do
    debug("Processing member: " .. tostring(memberName))
    local normalizedName = memberName
    
    -- Initialize activities for this player if needed
    PugRaterDB.activities[normalizedName] = PugRaterDB.activities[normalizedName] or {}
    
    -- Create activity entry for logs
    local durationText = "Unknown"
    if runData.duration and runData.duration > 0 then
      if runData.completionTime then
        -- Use the actual completion time from the event (in milliseconds)
        local minutes = math.floor(runData.completionTime / 60000)
        local seconds = math.floor((runData.completionTime % 60000) / 1000)
        durationText = string.format("%d:%02d", minutes, seconds)
      else
        -- Fallback to calculated duration (in seconds)
        local minutes = math.floor(runData.duration / 60)
        local seconds = runData.duration % 60
        durationText = string.format("%d:%02d", minutes, seconds)
      end
    end
    
    local activity = {
      date = date("%m/%d %H:%M", runData.date),
      type = "M+",
      name = string.format("%s +%d", dungeonName, runData.level or 0),
      dungeonName = dungeonName,
      level = runData.level,
      completed = completed,
      inTime = inTime,
      completionStatus = inTime and "timed" or (completed and "overtime" or "depleted"),
      duration = durationText
    }
    
    -- Add to player's activity log
    table.insert(PugRaterDB.activities[normalizedName], activity)
    debug(string.format("Added activity for %s: %s", normalizedName, activity.name))
    
    -- Keep only last 50 activities per player to prevent bloat
    if #PugRaterDB.activities[normalizedName] > 50 then
      table.remove(PugRaterDB.activities[normalizedName], 1)
    end
  end
  
  -- Update player records with run completion data
  for _, memberName in ipairs(currentRun.members) do
    local rec, key = addon:GetPlayer(memberName)
    if rec and key then
      rec.lastRunCompleted = completed
      rec.lastRunInTime = inTime
      rec.lastRunDate = time()
      rec.totalRuns = (rec.totalRuns or 0) + 1
      if completed then
        rec.completedRuns = (rec.completedRuns or 0) + 1
      end
      if inTime then
        rec.inTimeRuns = (rec.inTimeRuns or 0) + 1
      end
    end
  end
  
  local statusText = completed and (inTime and "COMPLETED IN TIME" or "COMPLETED") or "FAILED"
  SystemMessage(string.format("Mythic+ %s: %s +%d - Recorded for %d players", statusText, dungeonName, currentRun.level or 0, #currentRun.members))
  
  -- Debug output
  debug(string.format("Recorded run: %s, %s +%d, Members: %d, inTime: %s", statusText, dungeonName, currentRun.level or 0, #currentRun.members, tostring(inTime)))
end

local function PromptRateAllCurrent()
  if not IsInGroup() then return end
  local unitPrefix = IsInRaid() and "raid" or "party"
  local num = GetNumGroupMembers()
  local count = IsInRaid() and num or (num - 1)
  local names = {}
  for i = 1, count do
    local unit = unitPrefix .. i
    local name = GetUnitName(unit, true)
    if name then table.insert(names, name) end
  end
  -- show the post-run list popup with completion status
  if addon.UI and addon.UI.ShowPostRun then 
    addon.UI:ShowPostRun(names, currentRun.completed, currentRun.inTime) 
  end
end

instFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "CHALLENGE_MODE_START" then
    ResetRunData()
    currentRun.isActive = true
    currentRun.startTime = time()
    currentRun.members = CaptureGroupMembers()
    
    -- Get keystone info
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then
      currentRun.mapID = mapID
      local keystoneLevel = C_ChallengeMode.GetActiveKeystoneInfo()
      currentRun.level = keystoneLevel
      SystemMessage(string.format("Mythic+ Started: Level %d", keystoneLevel or 0))
    end
    
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    local mapID, level, time, onTime = ...
    -- Debug the completion parameters
    debug(string.format("CHALLENGE_MODE_COMPLETED: mapID=%s, level=%s, time=%s, onTime=%s", 
          tostring(mapID), tostring(level), tostring(time), tostring(onTime)))
    
    -- Store the completion time for duration calculation
    if time then
      currentRun.completionTime = time
    end
    
    RecordRunCompletion(true, onTime)
    C_Timer.After(2, PromptRateAllCurrent)
    
  elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
    -- Simplified combat log tracking - mainly for backup detection
    -- Rely primarily on CHALLENGE_MODE_COMPLETED for accurate tracking
    if currentRun.isActive then
      local timestamp, subevent = CombatLogGetCurrentEventInfo()
      -- Only track specific events that might indicate completion
      -- This is kept minimal to avoid false positives
    end
    
  elseif event == "SCENARIO_COMPLETED" or event == "LFG_COMPLETION_REWARD" then
    -- Only record non-mythic+ completions or as backup
    if not currentRun.isActive then
      -- This might be regular dungeon completion
      RecordRunCompletion(true, false) -- Assume completed but not necessarily in time
      C_Timer.After(2, PromptRateAllCurrent)
    end
  end
  
  -- Reset run data if we leave the group or after a timeout
  if not IsInGroup() and currentRun.isActive then
    C_Timer.After(10, function() 
      if not IsInGroup() then 
        ResetRunData() 
      end 
    end)
  end
  
  ScanGroup()
end)

-- Slash command
SLASH_PUGRATER1 = "/pugrater"
SLASH_PUGRATER2 = "/pr"  -- Shorter alias
SlashCmdList["PUGRATER"] = function(msg)
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  if cmd == "rate" and rest ~= "" then
    addon:ShowRateFrame(rest)
  elseif cmd == "rate" and rest == "" then
    -- Rate current target if no name provided
    local targetName = UnitName("target")
    if targetName then
      local fullName = targetName
      local realm = select(2, UnitName("target"))
      if realm and realm ~= "" then
        fullName = targetName .. "-" .. realm
      elseif not fullName:find("-") then
        fullName = targetName .. "-" .. GetNormalizedRealmName()
      end
      addon:ShowRateFrame(fullName)
    else
      SystemMessage("No target selected. Usage: /pr rate <name-realm> or target a player first")
    end
  elseif cmd == "list" or msg == "" then
    if addon.UI and addon.UI.ShowList then addon.UI:ShowList() end
  elseif cmd == "history" or cmd == "logs" then
    if addon.UI and addon.UI.ShowLogs then addon.UI:ShowLogs() end
  elseif cmd == "group" then
    -- Rate all current group members
    if IsInGroup() then
      local unitPrefix = IsInRaid() and "raid" or "party"
      local num = GetNumGroupMembers()
      local count = IsInRaid() and num or (num - 1)
      local names = {}
      for i = 1, count do
        local unit = unitPrefix .. i
        local name = GetUnitName(unit, true)
        if name then table.insert(names, name) end
      end
      if #names > 0 then
        if addon.UI and addon.UI.ShowPostRun then 
          addon.UI:ShowPostRun(names, nil, nil) 
        end
      else
        SystemMessage("No group members found")
      end
    else
      SystemMessage("You are not in a group")
    end
  elseif cmd == "toggle" then
    PugRaterDB.options.notifyOnJoin = not PugRaterDB.options.notifyOnJoin
    SystemMessage("Notify on join: " .. tostring(PugRaterDB.options.notifyOnJoin))
  elseif cmd == "stats" then
    local total = #(PugRaterDB.history or {})
    local completed = 0
    local inTime = 0
    for _, run in ipairs(PugRaterDB.history or {}) do
      if run.completed then completed = completed + 1 end
      if run.inTime then inTime = inTime + 1 end
    end
    SystemMessage(string.format("Total Runs: %d | Completed: %d | In Time: %d", total, completed, inTime))
  elseif cmd == "test" then
    -- Test command to simulate a run completion
    currentRun.isActive = true
    currentRun.level = 15
    currentRun.mapID = 168 -- Everbloom mapID as example
    currentRun.startTime = time() - 1800 -- 30 minutes ago
    currentRun.members = CaptureGroupMembers()
    if #currentRun.members == 0 then
      -- Add current player if no group
      local playerName = UnitName("player") .. "-" .. GetNormalizedRealmName()
      currentRun.members = {playerName}
    end
    RecordRunCompletion(true, true) -- Test with completed in time
    SystemMessage("Test run recorded!")
  elseif cmd == "testplayer" and rest ~= "" then
    -- Test command to create activity for a specific player
    PugRaterDB.activities = PugRaterDB.activities or {}
    PugRaterDB.activities[rest] = PugRaterDB.activities[rest] or {}
    
    local testActivity = {
      date = date("%m/%d %H:%M"),
      type = "M+",
      name = "The Everbloom +15",
      dungeonName = "The Everbloom",
      level = 15,
      completed = true,
      inTime = true,
      completionStatus = "timed",
      duration = "25m"
    }
    
    table.insert(PugRaterDB.activities[rest], testActivity)
    SystemMessage("Test activity added for: " .. rest)
  elseif cmd == "reset" or cmd == "clear" then
    -- Reset all addon data with confirmation
    if rest == "confirm" then
      -- Actually perform the reset
      PugRaterDB.players = {}
      PugRaterDB.history = {}
      PugRaterDB.activities = {}
      PugRaterDB.options = {
        notifyOnJoin = true,
        autoShowPostRun = true
      }
      SystemMessage("|cffff0000PugRater: All data has been reset!|r")
    else
      -- Show confirmation message
      SystemMessage("|cffff9900WARNING: This will delete ALL PugRater data including:|r")
      SystemMessage("- All player ratings and notes")
      SystemMessage("- All mythic+ run history")
      SystemMessage("- All player activity logs")
      SystemMessage("- All addon settings")
      SystemMessage("|cffff0000Type '/pr reset confirm' to proceed|r")
    end
  elseif cmd == "cleardata" then
    -- Clear only tracking data for testing (keep ratings)
    PugRaterDB.history = {}
    PugRaterDB.activities = {}
    SystemMessage("Tracking data cleared (ratings preserved)!")
  elseif cmd == "debug" then
    debug("Current run active: " .. tostring(currentRun.isActive))
    debug("History entries: " .. #(PugRaterDB.history or {}))
    local activityCount = 0
    for playerName, activities in pairs(PugRaterDB.activities or {}) do 
      activityCount = activityCount + 1
      debug(string.format("Player %s has %d activities", playerName, #activities))
    end
    debug("Activities keys: " .. activityCount)
  elseif cmd == "checkplayer" and rest ~= "" then
    -- Check activity data for a specific player
    local activities = PugRaterDB.activities and PugRaterDB.activities[rest]
    if activities then
      SystemMessage(string.format("Player %s has %d activities:", rest, #activities))
      for i, activity in ipairs(activities) do
        SystemMessage(string.format("  %d. %s - %s", i, activity.date, activity.name))
      end
    else
      SystemMessage(string.format("No activities found for player: %s", rest))
      SystemMessage("Available players:")
      for playerName in pairs(PugRaterDB.activities or {}) do
        SystemMessage("  " .. playerName)
      end
    end
  else
    SystemMessage("PugRater Commands:")
    SystemMessage("/pr rate - Rate your current target")
    SystemMessage("/pr rate <name-realm> - Rate a specific player")
    SystemMessage("/pr list - Show player list")
    SystemMessage("/pr group - Rate all group members")
    SystemMessage("/pr history - Show run history")
    SystemMessage("/pr stats - Show your statistics")
    SystemMessage("/pr toggle - Toggle notifications")
    SystemMessage("/pr reset - Reset all addon data (requires confirmation)")
    SystemMessage("/pr checkplayer <name-realm> - Check activity data for player")
  end
end
