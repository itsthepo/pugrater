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
instFrame:RegisterEvent("SCENARIO_COMPLETED")
instFrame:RegisterEvent("LFG_COMPLETION_REWARD")

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
  -- show the post-run list popup
  if addon.UI and addon.UI.ShowPostRun then addon.UI:ShowPostRun(names) end
  -- also open individual rater windows if desired (commented)
  -- for _, n in ipairs(names) do addon:ShowRateFrame(n) end
end

instFrame:SetScript("OnEvent", function(_, event)
  if event == "CHALLENGE_MODE_COMPLETED" or event == "SCENARIO_COMPLETED" or event == "LFG_COMPLETION_REWARD" then
    C_Timer.After(2, PromptRateAllCurrent)
  end
end)

-- Slash command
SLASH_PUGRATER1 = "/pugrater"
SlashCmdList["PUGRATER"] = function(msg)
  local cmd, rest = msg:match("^(%S+)%s*(.-)$")
  if cmd == "rate" and rest ~= "" then
    addon:ShowRateFrame(rest)
  elseif cmd == "list" or msg == "" then
    if addon.UI and addon.UI.ShowList then addon.UI:ShowList() end
  elseif cmd == "toggle" then
    PugRaterDB.options.notifyOnJoin = not PugRaterDB.options.notifyOnJoin
    SystemMessage("Notify on join: " .. tostring(PugRaterDB.options.notifyOnJoin))
  else
    SystemMessage("Usage: /pugrater list | rate <name-realm> | toggle")
  end
end
