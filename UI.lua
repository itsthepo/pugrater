---@diagnostic disable: undefined-global
local addonName, addon = ...

local UI = {}
addon.UI = UI

local LOGO_PATH = "Interface/AddOns/PugRater/media/pugrater_logo"
local RATING_ICON_FILE_ID = 413585 -- achievement-guildperk-honorablemention-rank2
-- Logo size (tune these to match your image aspect ratio to avoid squish)
local LOGO_WIDTH, LOGO_HEIGHT = 128, 64

local function NormalizeName(fullName)
  local name, realm = fullName:match("([^%-]+)%-?(.*)")
  if realm == nil or realm == "" then realm = GetNormalizedRealmName() end
  return name .. "-" .. realm
end

local function CreateRateFrame()
  local f = CreateFrame("Frame", "PugRaterRateFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetClampedToScreen(true)
  f:SetSize(320, 200)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title:SetPoint("TOP", 0, -10)
  f.title:SetText("PugRater: Rate Player")

  f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.nameText:SetPoint("TOPLEFT", 16, -40)
  f.nameText:SetText("Player:")

  f.nameValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.nameValue:SetPoint("LEFT", f.nameText, "RIGHT", 8, 0)
  f.nameValue:SetText("")

  f.ratingText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.ratingText:SetPoint("TOPLEFT", f.nameText, "BOTTOMLEFT", 0, -16)
  f.ratingText:SetText("Rating:")

  f.stars = {}
  local function SetIconSelected(btn, selected)
    if not btn or not btn.tex then return end
    if selected then
      btn.tex:SetDesaturated(false)
      btn.tex:SetVertexColor(1, 0.82, 0) -- gold
    else
      btn.tex:SetDesaturated(true)
      btn.tex:SetVertexColor(0.7, 0.7, 0.7)
    end
  end

  function f:UpdateStars(current)
    for j=1,5 do
      SetIconSelected(self.stars[j], j <= (current or 0))
    end
  end

  for i=1,5 do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(24, 24)
    b:SetPoint("LEFT", f.ratingText, "RIGHT", 8 + (i-1)*28, 0)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetAllPoints()
    b.tex:SetTexture(RATING_ICON_FILE_ID)
    SetIconSelected(b, false)
    b:SetScript("OnEnter", function(self) if self.tex then self.tex:SetAlpha(1) end end)
    b:SetScript("OnLeave", function(self) if self.tex then self.tex:SetAlpha(1) end end)
    b:SetScript("OnClick", function()
      f.currentRating = i
      f:UpdateStars(i)
    end)
    f.stars[i] = b
  end

  f.noteText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.noteText:SetPoint("TOPLEFT", f.ratingText, "BOTTOMLEFT", 0, -16)
  f.noteText:SetText("Note:")

  f.noteBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.noteBox:SetPoint("LEFT", f.noteText, "RIGHT", 8, 0)
  f.noteBox:SetSize(220, 24)
  f.noteBox:SetAutoFocus(false)
  f.noteBox:SetMaxLetters(120)

  f.save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.save:SetSize(80, 24)
  f.save:SetPoint("BOTTOMRIGHT", -16, 16)
  f.save:SetText("Save")

  f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.cancel:SetSize(80, 24)
  f.cancel:SetPoint("RIGHT", f.save, "LEFT", -8, 0)
  f.cancel:SetText("Close")

  -- Add List button to open the player list
  f.list = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.list:SetSize(80, 24)
  f.list:SetPoint("RIGHT", f.cancel, "LEFT", -8, 0)
  f.list:SetText("List")
  f.list:SetScript("OnClick", function() addon.UI:ShowList() end)

  -- Ensure buttons are not on an excessively high strata/level
  local baseLevel = f:GetFrameLevel() or 0
  local function norm(btn)
    if not btn then return end
    btn:SetFrameStrata(f:GetFrameStrata())
    btn:SetFrameLevel(baseLevel + 2)
  end
  norm(f.save); norm(f.cancel); norm(f.list)

  f.cancel:SetScript("OnClick", function() f:Hide() end)
  f.save:SetScript("OnClick", function()
    if f.targetName and f.currentRating then
      addon:SetRating(f.targetName, f.currentRating, f.noteBox:GetText())
    end
    f:Hide()
    if addon.UI and addon.UI.RefreshList then addon.UI:RefreshList() end
  end)

  -- Optional logo
  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(LOGO_WIDTH, LOGO_HEIGHT)
    f.logo:SetPoint("TOPLEFT", 10, -8)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  -- show only if file exists (WoW loads silently; we toggle once to force load)
  f.logo:SetShown(true)

  -- Keep this frame above others and non-click-through
  f:HookScript("OnShow", function(self)
    -- raise above others
    local topLevel = (UIParent:GetFrameLevel() or 0) + 100
    local listFrameRef = rawget(_G, "PugRaterListFrame") or listFrame
    local postFrameRef = rawget(_G, "PugRaterPostRunFrame") or postRunFrame
    if listFrameRef and listFrameRef.GetFrameLevel then
      topLevel = math.max(topLevel, (listFrameRef:GetFrameLevel() or 0) + 50)
      listFrameRef:EnableMouse(false) -- prevent click-through while editor is open
    end
    if postFrameRef and postFrameRef.GetFrameLevel then
      topLevel = math.max(topLevel, (postFrameRef:GetFrameLevel() or 0) + 50)
      postFrameRef:EnableMouse(false)
    end
    self:SetFrameLevel(topLevel)
    self:Raise()
  end)

  f:HookScript("OnHide", function()
    if listFrame then listFrame:EnableMouse(true) end
    if postRunFrame then postRunFrame:EnableMouse(true) end
  end)

  f:Hide()
  return f
end

local rateFrame

function UI:Show(playerName)
  rateFrame = rateFrame or CreateRateFrame()
  local key = NormalizeName(playerName)
  local rec = addon:GetPlayer(key)
  rateFrame.targetName = key
  rateFrame.nameValue:SetText(key)
  rateFrame.noteBox:SetText(rec and rec.note or "")
  rateFrame.currentRating = rec and rec.rating or 0
  if rateFrame.UpdateStars then rateFrame:UpdateStars(rateFrame.currentRating or 0) end
  rateFrame:Raise()
  rateFrame:Show()
end

-- Simple Player List UI (scrollable, searchable)
local function CreateListFrame()
  local f = CreateFrame("Frame", "PugRaterListFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("HIGH")
  f:SetSize(600, 420)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title:SetPoint("TOP", 0, -10)
  f.title:SetText("PugRater: Players")

  f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.searchLabel:SetPoint("TOPLEFT", 16, -40)
  f.searchLabel:SetText("Search:")

  f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.search:SetSize(220, 24)
  f.search:SetPoint("LEFT", f.searchLabel, "RIGHT", 8, 0)
  f.search:SetAutoFocus(false)

  -- headers
  f.hName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hName:SetPoint("TOPLEFT", 16, -70)
  f.hName:SetText("Name")
  f.hRating = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hRating:SetPoint("LEFT", f.hName, "RIGHT", 230, 0)
  f.hRating:SetText("Rating")
  f.hNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hNote:SetPoint("LEFT", f.hRating, "RIGHT", 80, 0)
  f.hNote:SetText("Note")

  f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 16, -90)
  f.scroll:SetPoint("BOTTOMRIGHT", -36, 50)

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetSize(1,1)
  f.scroll:SetScrollChild(f.content)

  f.rows = {}

  f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.close:SetSize(80, 24)
  f.close:SetPoint("BOTTOMRIGHT", -16, 16)
  f.close:SetText("Close")
  f.close:SetScript("OnClick", function() f:Hide() end)
  -- normalize close button strata/level
  f.close:SetFrameStrata(f:GetFrameStrata())
  f.close:SetFrameLevel((f:GetFrameLevel() or 0) + 2)

  f.sortMode = "recent" -- or "name" or "rating"

  -- sort buttons
  f.sortName = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.sortName:SetSize(60, 20)
  f.sortName:SetPoint("LEFT", f.hName, "RIGHT", 150, 0)
  f.sortName:SetText("Sort A-Z")
  f.sortName:SetScript("OnClick", function() f.sortMode = "name"; addon.UI:RefreshList() end)

  f.sortRating = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.sortRating:SetSize(60, 20)
  f.sortRating:SetPoint("LEFT", f.hRating, "RIGHT", 60, 0)
  f.sortRating:SetText("Bad 1st")
  f.sortRating:SetScript("OnClick", function() f.sortMode = "rating"; addon.UI:RefreshList() end)

  f.sortGood = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.sortGood:SetSize(70, 20)
  f.sortGood:SetPoint("LEFT", f.sortRating, "RIGHT", 8, 0)
  f.sortGood:SetText("Good 1st")
  f.sortGood:SetScript("OnClick", function() f.sortMode = "rating_desc"; addon.UI:RefreshList() end)

  f.sortRecent = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.sortRecent:SetSize(60, 20)
  f.sortRecent:SetPoint("LEFT", f.hNote, "RIGHT", 60, 0)
  f.sortRecent:SetText("Recent")
  f.sortRecent:SetScript("OnClick", function() f.sortMode = "recent"; addon.UI:RefreshList() end)

  f.search:SetScript("OnTextChanged", function() addon.UI:RefreshList() end)

  -- Optional logo
  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(LOGO_WIDTH, LOGO_HEIGHT)
    f.logo:SetPoint("TOPLEFT", 10, -8)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  f.logo:SetShown(true)

  f:Hide()
  return f
end

local listFrame

local function matchesFilter(key, rec, needle)
  if not needle or needle == "" then return true end
  needle = needle:lower()
  if key:lower():find(needle, 1, true) then return true end
  if rec.note and rec.note:lower():find(needle, 1, true) then return true end
  return false
end

function UI:RefreshList()
  listFrame = listFrame or CreateListFrame()
  local needle = listFrame.search:GetText() or ""

  -- collect entries
  local entries = {}
  for key, rec in pairs(PugRaterDB.players or {}) do
    if matchesFilter(key, rec, needle) then
      table.insert(entries, { key = key, rec = rec })
    end
  end

  -- sort
  if listFrame.sortMode == "name" then
    table.sort(entries, function(a,b) return a.key:lower() < b.key:lower() end)
  elseif listFrame.sortMode == "rating" then
    table.sort(entries, function(a,b)
      local ar, br = a.rec.rating or 0, b.rec.rating or 0
      if ar == br then return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end
      return ar < br -- bad first
    end)
  elseif listFrame.sortMode == "rating_desc" then
    table.sort(entries, function(a,b)
      local ar, br = a.rec.rating or 0, b.rec.rating or 0
      if ar == br then return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end
      return ar > br -- good first
    end)
  else -- recent
    table.sort(entries, function(a,b) return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end)
  end

  -- build rows (simple, all rows in content)
  for i,row in ipairs(listFrame.rows) do row:Hide() end

  local ROW_H, WIDTH = 22, (listFrame.scroll:GetWidth() or 540)
  listFrame.content:SetSize(WIDTH-20, math.max(#entries*ROW_H, listFrame.scroll:GetHeight()))

  for i, e in ipairs(entries) do
    local row = listFrame.rows[i]
    if not row then
      row = CreateFrame("Button", nil, listFrame.content)
      row:SetSize(WIDTH-20, ROW_H)
      if i == 1 then
        row:SetPoint("TOPLEFT", 0, 0)
      else
        row:SetPoint("TOPLEFT", listFrame.rows[i-1], "BOTTOMLEFT", 0, 0)
      end
      row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.name:SetPoint("LEFT", 8, 0)
      row.name:SetWidth(240)
      row.name:SetJustifyH("LEFT")

      row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.rating:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
      row.rating:SetWidth(60)
      row.rating:SetJustifyH("LEFT")

      row.note = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.note:SetPoint("LEFT", row.rating, "RIGHT", 8, 0)
      row.note:SetWidth(WIDTH - 20 - 240 - 60 - 32)
      row.note:SetJustifyH("LEFT")

      row:SetScript("OnClick", function(self)
        addon.UI:Show(self.key)
      end)

      listFrame.rows[i] = row
    end

    row.key = e.key
    row.name:SetText(e.key)

    local r = tonumber(e.rec.rating or 0)
    if not r or r <= 0 then
      row.rating:SetText("unrated")
      row.rating:SetTextColor(0.6, 0.6, 0.6)
    else
      row.rating:SetText(tostring(r))
      row.rating:SetTextColor(1, 0.82, 0)
    end

    row.note:SetText(e.rec.note or "")
    row:Show()
  end
end

function UI:ShowList()
  listFrame = listFrame or CreateListFrame()
  self:RefreshList()
  listFrame:Show()
end

-- Post-run popup listing teammates with Rate buttons
local function CreatePostRunFrame()
  local f = CreateFrame("Frame", "PugRaterPostRunFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("HIGH")
  f:SetSize(460, 280)
  -- Anchor to the left side of the screen instead of center (end of a key)
  f:SetPoint("LEFT", UIParent, "LEFT", 20, 0)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title:SetPoint("TOP", 0, -12)
  f.title:SetText("Did you enjoy playing with these players?")

  f.rows = {}

  function f:SetMembers(names)
    for i,row in ipairs(self.rows) do row:Hide() end
    local startY = -50
    for i, name in ipairs(names or {}) do
      local row = self.rows[i]
      if not row then
        row = CreateFrame("Frame", nil, self)
        row:SetSize(420, 28)
        if i == 1 then
          row:SetPoint("TOPLEFT", 20, startY)
        else
          row:SetPoint("TOPLEFT", self.rows[i-1], "BOTTOMLEFT", 0, -8)
        end
        row.nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.nameFS:SetPoint("LEFT", 4, 0)
        row.button = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.button:SetSize(110, 22)
        row.button:SetPoint("RIGHT", 0, 0)
        row.button:SetText("Rate Player")
        row.button:SetScript("OnClick", function()
          addon:ShowRateFrame(row.playerName)
          -- keep this window open for rating multiple players
        end)
        self.rows[i] = row
      end
      row.playerName = name
      row.nameFS:SetText(name)
      row:Show()
    end

    local height = 100 + (#names * 36)
    self:SetHeight(math.min(460, height))
  end

  f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.close:SetSize(80, 24)
  f.close:SetPoint("BOTTOMRIGHT", -16, 16)
  f.close:SetText("Close")
  f.close:SetScript("OnClick", function() f:Hide() end)
  -- normalize close button strata/level
  f.close:SetFrameStrata(f:GetFrameStrata())
  f.close:SetFrameLevel((f:GetFrameLevel() or 0) + 2)

  -- Optional logo
  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(LOGO_WIDTH, LOGO_HEIGHT)
    f.logo:SetPoint("TOPLEFT", 10, -8)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  f.logo:SetShown(true)

  f:Hide()
  return f
end

local postRunFrame

function UI:ShowPostRun(names)
  postRunFrame = postRunFrame or CreatePostRunFrame()
  postRunFrame:SetMembers(names or {})
  postRunFrame:Show()
end
