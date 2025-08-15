---@diagnostic disable: undefined-global
local addonName, addon = ...

local UI = {}
addon.UI = UI

local LOGO_PATH = "Interface/AddOns/PugRater/media/pugrater_logo"
local RATING_ICON_FILE_ID = 413585
local LOGO_WIDTH, LOGO_HEIGHT = 128, 128

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
  f:SetSize(450, 240)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  
  f:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:Hide()
      return
    end
  end)
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)

  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(80, 80)
    f.logo:SetPoint("CENTER", -75, 100)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  f.logo:SetShown(true)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title:SetPoint("CENTER", 22, 100.50)
  f.title:SetText("- Rate Player")

  f.closeX = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.closeX:SetSize(24, 24)
  f.closeX:SetPoint("TOPRIGHT", -8, -8)
  f.closeX:SetText("X")
  f.closeX:SetScript("OnClick", function() f:Hide() end)

  f.nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.nameText:SetPoint("TOPLEFT", 16, -50)
  f.nameText:SetText("Player:")

  f.nameValue = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.nameValue:SetPoint("LEFT", f.nameText, "RIGHT", 8, 0)
  f.nameValue:SetText("")

  f.viewLogsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.viewLogsBtn:SetSize(80, 20)
  f.viewLogsBtn:SetPoint("LEFT", f.nameValue, "RIGHT", 15, 0)
  f.viewLogsBtn:SetText("View Logs")
  f.viewLogsBtn:SetScript("OnClick", function()
    addon.UI:ShowLogs(f.targetName)
  end)

  f.ratingText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.ratingText:SetPoint("TOPLEFT", f.nameText, "BOTTOMLEFT", 0, -30)
  f.ratingText:SetText("Rating:")

  f.stars = {}
  local function SetIconSelected(btn, selected)
    if not btn or not btn.tex then return end
    if selected then
      btn.tex:SetDesaturated(false)
      btn.tex:SetVertexColor(1.5, 1.2, 0)
    else
      btn.tex:SetDesaturated(true)
      btn.tex:SetVertexColor(0.3, 0.3, 0.3)
    end
  end

  function f:UpdateStars(current)
    for j=1,5 do
      SetIconSelected(self.stars[j], j <= (current or 0))
    end
    local rating = current or 0
    if rating == 0 then
      self.ratingDisplay:SetText("")
      if self.removeRating then
        self.removeRating:Hide()
      end
    elseif rating == 1 then
      self.ratingDisplay:SetText("1 Star")
      if self.removeRating then
        self.removeRating:Show()
      end
    else
      self.ratingDisplay:SetText(rating .. " Stars")
      if self.removeRating then
        self.removeRating:Show()
      end
    end
  end

  for i=1,5 do
    local b = CreateFrame("Button", nil, f)
    b:SetSize(28, 28)
    b:SetPoint("LEFT", f.ratingText, "RIGHT", 25 + (i-1)*35, 0)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    
    local cropAmount = 0.15
    local horizontalOffset = 0.05
    local verticalOffset = -0.06
    local angle = math.rad(36)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    local cx, cy = 0.5 + horizontalOffset, 0.5 - verticalOffset
    local size = 0.35
    
    local corners = {
      {-size, -size}, {-size, size}, {size, -size}, {size, size}
    }
    
    local rotated = {}
    for j, corner in ipairs(corners) do
      local x, y = corner[1], corner[2]
      rotated[j] = {
        cx + (x * cos_a - y * sin_a),
        cy + (x * sin_a + y * cos_a)
      }
    end
    
    b.tex:SetTexCoord(
      rotated[1][1], rotated[1][2],
      rotated[2][1], rotated[2][2],
      rotated[3][1], rotated[3][2],
      rotated[4][1], rotated[4][2]
    )
    
    b.tex:SetPoint("TOPLEFT", b, "TOPLEFT", -2, 1)
    b.tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 1)
    b.tex:SetTexture(RATING_ICON_FILE_ID)
    
    b.mask = b:CreateMaskTexture()
    b.mask:SetAllPoints(b.tex)
    b.mask:SetTexture("Interface/CharacterFrame/TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    b.tex:AddMaskTexture(b.mask)
    
    SetIconSelected(b, false)
    b:SetScript("OnClick", function()
      f.currentRating = i
      f:UpdateStars(i)
    end)
    f.stars[i] = b
  end

  f.ratingDisplay = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.ratingDisplay:SetPoint("LEFT", f.stars[5], "RIGHT", 15, 0)
  f.ratingDisplay:SetTextColor(1, 1, 1)
  f.ratingDisplay:SetText("")

  f.removeRating = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.removeRating:SetSize(100, 20)
  f.removeRating:SetPoint("LEFT", f.ratingDisplay, "RIGHT", 15, 0)
  f.removeRating:SetText("Remove rating")
  f.removeRating:Hide()
  f.removeRating:SetScript("OnClick", function()
    f.currentRating = 0
    f:UpdateStars(0)
    f.noteBox:SetText("")
  end)

  f.noteText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.noteText:SetPoint("TOPLEFT", f.ratingText, "BOTTOMLEFT", 0, -30)
  f.noteText:SetText("Note:")

  f.noteBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.noteBox:SetPoint("TOPLEFT", f.noteText, "BOTTOMLEFT", 7, -2)
  f.noteBox:SetSize(400, 24)
  f.noteBox:SetAutoFocus(false)
  f.noteBox:SetMaxLetters(500)

  f.save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.save:SetSize(80, 24)
  f.save:SetPoint("BOTTOMRIGHT", -16, 16)
  f.save:SetText("Save")

  f.cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.cancel:SetSize(80, 24)
  f.cancel:SetPoint("RIGHT", f.save, "LEFT", -8, 0)
  f.cancel:SetText("Undo")

  f.list = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.list:SetSize(100, 24)
  f.list:SetPoint("BOTTOMLEFT", 16, 16)
  f.list:SetText("Player List")
  f.list:SetScript("OnClick", function() addon.UI:ShowList() end)

  local baseLevel = f:GetFrameLevel() or 0
  local function normalizeButton(btn)
    if not btn then return end
    btn:SetFrameStrata(f:GetFrameStrata())
    btn:SetFrameLevel(baseLevel + 2)
  end
  normalizeButton(f.save)
  normalizeButton(f.cancel)
  normalizeButton(f.list)
  normalizeButton(f.closeX)
  normalizeButton(f.viewLogsBtn)

  f.cancel:SetScript("OnClick", function() 
    local currentTarget = f.targetName
    f:Hide() 
    if currentTarget and addon.UI then
      addon.UI:Show(currentTarget)
    end
  end)
  f.save:SetScript("OnClick", function()
    if f.targetName and f.currentRating then
      addon:SetRating(f.targetName, f.currentRating, f.noteBox:GetText())
    end
    f:Hide()
    if addon.UI and addon.UI.RefreshList then addon.UI:RefreshList() end
  end)

  f:HookScript("OnShow", function(self)
    local topLevel = (UIParent:GetFrameLevel() or 0) + 100
    local listFrameRef = rawget(_G, "PugRaterListFrame") or listFrame
    local postFrameRef = rawget(_G, "PugRaterPostRunFrame") or postRunFrame
    if listFrameRef and listFrameRef.GetFrameLevel then
      topLevel = math.max(topLevel, (listFrameRef:GetFrameLevel() or 0) + 50)
    end
    if postFrameRef and postFrameRef.GetFrameLevel then
      topLevel = math.max(topLevel, (postFrameRef:GetFrameLevel() or 0) + 50)
    end
    self:SetFrameLevel(topLevel)
    self:Raise()
  end)

  f:HookScript("OnHide", function()
    local listFrameRef = rawget(_G, "PugRaterListFrame") or listFrame
    if listFrameRef then 
      listFrameRef:EnableMouse(true)
      if listFrameRef.SetMovable then
        listFrameRef:SetMovable(true)
        listFrameRef:RegisterForDrag("LeftButton")
      end
    end
    if postRunFrame then 
      postRunFrame:EnableMouse(true)
      if postRunFrame.SetMovable then
        postRunFrame:SetMovable(true)
        postRunFrame:RegisterForDrag("LeftButton")
      end
    end
  end)

  f:Hide()
  return f
end

local rateFrame

function UI:Show(playerName)
  rateFrame = rateFrame or CreateRateFrame()
  local key = NormalizeName(playerName)
  local rec = nil
  if PugRaterDB and PugRaterDB.players and PugRaterDB.players[key] then
    rec = PugRaterDB.players[key]
  end
  rateFrame.targetName = key
  rateFrame.nameValue:SetText(key)
  rateFrame.noteBox:SetText(rec and rec.note or "")
  rateFrame.currentRating = rec and rec.rating or 0
  if rateFrame.UpdateStars then rateFrame:UpdateStars(rateFrame.currentRating or 0) end
  rateFrame:Raise()
  rateFrame:Show()
end

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
  
  f:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:Hide()
      return
    end
  end)
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)
  
  f:SetScript("OnShow", function(self)
    self:EnableKeyboard(false)
    C_Timer.After(0.1, function()
      if self:IsShown() then
        self:EnableKeyboard(true)
      end
    end)
  end)
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  f.closeX = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.closeX:SetSize(24, 24)
  f.closeX:SetPoint("TOPRIGHT", -16, -16)
  f.closeX:SetText("X")
  f.closeX:SetScript("OnClick", function() f:Hide() end)
  f.closeX:SetFrameStrata(f:GetFrameStrata())
  f.closeX:SetFrameLevel((f:GetFrameLevel() or 0) + 2)

  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(LOGO_WIDTH, LOGO_HEIGHT)
    f.logo:SetPoint("TOP", 0, 20)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  f.logo:SetShown(true)

  f.sortLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.sortLabel:SetPoint("TOPLEFT", 16, -80)
  f.sortLabel:SetText("Sort By:")

  f.sortDropdown = CreateFrame("Button", nil, f, "UIDropDownMenuTemplate")
  f.sortDropdown:SetPoint("LEFT", f.sortLabel, "RIGHT", -15, 0)

  f.searchLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.searchLabel:SetPoint("LEFT", f.sortDropdown, "RIGHT", -3, 0)
  f.searchLabel:SetText("Search:")

  f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  f.search:SetSize(180, 24)
  f.search:SetPoint("LEFT", f.searchLabel, "RIGHT", 5, 0)
  f.search:SetAutoFocus(false)

  f.ratingFilterLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.ratingFilterLabel:SetPoint("TOPRIGHT", -120, -80)
  f.ratingFilterLabel:SetText("Filter:")

  f.ratingFilter = CreateFrame("Button", nil, f, "UIDropDownMenuTemplate")
  f.ratingFilter:SetPoint("LEFT", f.ratingFilterLabel, "RIGHT", -15, 0)
  
  f.selectedRatingFilter = "all"

  f.headerBg = f:CreateTexture(nil, "BACKGROUND")
  f.headerBg:SetPoint("TOPLEFT", 16, -107)
  f.headerBg:SetPoint("TOPRIGHT", -36, -107)
  f.headerBg:SetHeight(20)
  f.headerBg:SetTexture("Interface/Tooltips/UI-Tooltip-Background")
  f.headerBg:SetVertexColor(0, 0, 0, 0.7)

  f.hName = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hName:SetPoint("TOPLEFT", 23.5, -110)
  f.hName:SetText("Name")
  f.hRating = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hRating:SetPoint("LEFT", f.hName, "RIGHT", 179.5, 0)
  f.hRating:SetText("Rating")
  f.hLastRun = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hLastRun:SetPoint("LEFT", f.hRating, "RIGHT", 45, 0)
  f.hLastRun:SetText("Last Run")
  f.hNote = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.hNote:SetPoint("LEFT", f.hLastRun, "RIGHT", 55, 0)
  f.hNote:SetText("Note")

  f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 16, -135)
  f.scroll:SetPoint("BOTTOMRIGHT", -36, 16)

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetSize(1,1)
  f.scroll:SetScrollChild(f.content)

  f.rows = {}
  f.sortMode = "recent"

  f.search:SetScript("OnTextChanged", function() addon.UI:RefreshList() end)

  local function RatingFilterDropDown_OnClick(self)
    f.selectedRatingFilter = self.value
    UIDropDownMenu_SetText(f.ratingFilter, self:GetText())
    
    if f.selectedRatingFilter == "unrated" then
      f.deleteUnratedBtn:Show()
    else
      f.deleteUnratedBtn:Hide()
    end
    
    addon.UI:RefreshList()
  end

  local function RatingFilterDropDown_Initialize()
    local info = {}
    local ratings = {
      {text = "All", value = "all"},
      {text = "Unrated", value = "unrated"},
      {text = "Rated", value = "rated"},
      {text = "1 Star", value = "1"},
      {text = "2 Stars", value = "2"},
      {text = "3 Stars", value = "3"},
      {text = "4 Stars", value = "4"},
      {text = "5 Stars", value = "5"}
    }
    
    for _, rating in ipairs(ratings) do
      info.text = rating.text
      info.value = rating.value
      info.func = RatingFilterDropDown_OnClick
      info.checked = (f.selectedRatingFilter == rating.value)
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(f.ratingFilter, RatingFilterDropDown_Initialize)
  UIDropDownMenu_SetWidth(f.ratingFilter, 80)
  UIDropDownMenu_SetText(f.ratingFilter, "All")

  local function SortDropDown_OnClick(self)
    f.sortMode = self.value
    UIDropDownMenu_SetText(f.sortDropdown, self:GetText())
    addon.UI:RefreshList()
  end

  local function SortDropDown_Initialize()
    local info = {}
    local sortOptions = {
      {text = "Recent", value = "recent"},
      {text = "Name A-Z", value = "name"},
      {text = "Bad First", value = "rating"},
      {text = "Good First", value = "rating_desc"}
    }
    
    for _, option in ipairs(sortOptions) do
      info.text = option.text
      info.value = option.value
      info.func = SortDropDown_OnClick
      info.checked = (f.sortMode == option.value)
      UIDropDownMenu_AddButton(info)
    end
  end

  UIDropDownMenu_Initialize(f.sortDropdown, SortDropDown_Initialize)
  UIDropDownMenu_SetWidth(f.sortDropdown, 100)
  UIDropDownMenu_SetText(f.sortDropdown, "Recent")

  f.deleteUnratedBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.deleteUnratedBtn:SetSize(120, 24)
  f.deleteUnratedBtn:SetPoint("BOTTOMRIGHT", -32, 6)
  f.deleteUnratedBtn:SetText("Delete all unrated")
  f.deleteUnratedBtn:Hide()
  f.deleteUnratedBtn:SetScript("OnClick", function()
    StaticPopup_Show("PUGRATER_DELETE_UNRATED")
  end)

  f:Hide()
  return f
end

StaticPopupDialogs["PUGRATER_DELETE_UNRATED"] = {
  text = "Are you sure you want to delete all unrated players? This cannot be undone.",
  button1 = "Yes",
  button2 = "No",
  OnAccept = function()
    if PugRaterDB and PugRaterDB.players then
      for key, rec in pairs(PugRaterDB.players) do
        if not rec.rating or rec.rating == 0 then
          PugRaterDB.players[key] = nil
        end
      end
      if addon.UI and addon.UI.RefreshList then
        addon.UI:RefreshList()
      end
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

local listFrame

local function truncateText(text, maxLength)
  if not text or text == "" then return "" end
  if string.len(text) <= maxLength then
    return text
  else
    return string.sub(text, 1, maxLength - 3) .. "..."
  end
end

local function matchesFilter(key, rec, needle, ratingFilter)
  if needle and needle ~= "" then
    needle = needle:lower()
    if not (key:lower():find(needle, 1, true) or (rec.note and rec.note:lower():find(needle, 1, true))) then
      return false
    end
  end
  
  if ratingFilter and ratingFilter ~= "all" then
    local rating = rec.rating or 0
    if ratingFilter == "unrated" then
      if rating > 0 then return false end
    elseif ratingFilter == "rated" then
      if rating <= 0 then return false end
    else
      local targetRating = tonumber(ratingFilter)
      if rating ~= targetRating then return false end
    end
  end
  
  return true
end

function UI:RefreshList()
  listFrame = listFrame or CreateListFrame()
  local needle = listFrame.search:GetText() or ""
  local ratingFilter = listFrame.selectedRatingFilter or "all"

  local entries = {}
  for key, rec in pairs(PugRaterDB.players or {}) do
    if matchesFilter(key, rec, needle, ratingFilter) then
      table.insert(entries, { key = key, rec = rec })
    end
  end

  if listFrame.sortMode == "name" then
    table.sort(entries, function(a,b) return a.key:lower() < b.key:lower() end)
  elseif listFrame.sortMode == "rating" then
    table.sort(entries, function(a,b)
      local ar, br = a.rec.rating or 0, b.rec.rating or 0
      if ar == br then return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end
      return ar < br
    end)
  elseif listFrame.sortMode == "rating_desc" then
    table.sort(entries, function(a,b)
      local ar, br = a.rec.rating or 0, b.rec.rating or 0
      if ar == br then return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end
      return ar > br
    end)
  else
    table.sort(entries, function(a,b) return (a.rec.lastSeen or 0) > (b.rec.lastSeen or 0) end)
  end

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
      
      row.bg = row:CreateTexture(nil, "BACKGROUND")
      row.bg:SetAllPoints()
      row.bg:SetTexture("Interface/Buttons/UI-Listbox-Highlight")
      row.bg:SetAlpha(0)
      
      row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.name:SetPoint("LEFT", 8, 0)
      row.name:SetWidth(210)
      row.name:SetJustifyH("LEFT")

      row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.rating:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
      row.rating:SetWidth(50)
      row.rating:SetJustifyH("LEFT")

      row.lastRun = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.lastRun:SetPoint("LEFT", row.rating, "RIGHT", 28, 0) -- Moved right to make room for icon
      row.lastRun:SetWidth(60)
      row.lastRun:SetJustifyH("LEFT")

      -- Create thumbs up/down icon for last run status
      row.lastRunIcon = row:CreateTexture(nil, "ARTWORK")
      row.lastRunIcon:SetSize(16, 16)
      row.lastRunIcon:SetPoint("LEFT", row.rating, "RIGHT", 8, 0)

      row.note = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      row.note:SetPoint("LEFT", row.lastRun, "RIGHT", 8, 0)
      row.note:SetWidth(WIDTH - 20 - 210 - 50 - 80 - 32)
      row.note:SetJustifyH("LEFT")

      row:SetScript("OnEnter", function(self)
        self.bg:SetAlpha(0.3)
        self.name:SetTextColor(1, 1, 0.5)
        self.rating:SetTextColor(1, 1, 0.5)
        self.note:SetTextColor(0.5, 0.8, 1)
      end)
      
      row:SetScript("OnLeave", function(self)
        self.bg:SetAlpha(0)
        self.name:SetTextColor(1, 1, 1)
        local r = tonumber(self.ratingValue or 0)
        if not r or r <= 0 then
          self.rating:SetTextColor(0.6, 0.6, 0.6)
        else
          self.rating:SetTextColor(1, 0.82, 0)
        end
        self.note:SetTextColor(0.5, 0.8, 1)
      end)

      row:SetScript("OnClick", function(self)
        addon.UI:Show(self.key)
      end)

      listFrame.rows[i] = row
    end

    row.key = e.key
    row.name:SetText(e.key)

    local r = tonumber(e.rec.rating or 0)
    row.ratingValue = r
    if not r or r <= 0 then
      row.rating:SetText("unrated")
      row.rating:SetTextColor(0.6, 0.6, 0.6)
    else
      row.rating:SetText(tostring(r))
      row.rating:SetTextColor(1, 0.82, 0)
    end

    -- Last Run completion status with icons
    if e.rec.lastRunCompleted ~= nil then
      if e.rec.lastRunCompleted then
        if e.rec.lastRunInTime then
          -- Thumbs up for in time completion
          row.lastRunIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
          row.lastRunIcon:SetVertexColor(0, 1, 0) -- Green
          row.lastRun:SetText("In Time")
          row.lastRun:SetTextColor(0, 1, 0) -- Green
          row.lastRunIcon:Show()
        else
          -- Thumbs down for overtime completion
          row.lastRunIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
          row.lastRunIcon:SetVertexColor(1, 0.65, 0) -- Orange
          row.lastRun:SetText("Over Time")
          row.lastRun:SetTextColor(1, 0.65, 0) -- Orange
          row.lastRunIcon:Show()
        end
      else
        -- X for failed runs
        row.lastRunIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        row.lastRunIcon:SetVertexColor(1, 0, 0) -- Red
        row.lastRun:SetText("Failed")
        row.lastRun:SetTextColor(1, 0, 0) -- Red
        row.lastRunIcon:Show()
      end
    else
      row.lastRunIcon:Hide()
      row.lastRun:SetText("No Data")
      row.lastRun:SetTextColor(0.6, 0.6, 0.6) -- Gray
    end

    row.note:SetText(truncateText(e.rec.note or "", 25)) -- Reduced to fit new column
    row.note:SetTextColor(0.5, 0.8, 1)
    row:Show()
  end
end

function UI:ShowList()
  listFrame = listFrame or CreateListFrame()
  self:RefreshList()
  listFrame:Show()
end

local function CreatePostRunFrame()
  local f = CreateFrame("Frame", "PugRaterPostRunFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("HIGH")
  f:SetSize(460, 280)
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

  f.subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.subtitle:SetPoint("TOP", 0, -35)
  f.subtitle:SetText("")

  f.rows = {}

  function f:SetMembers(names, completed, inTime)
    -- Update subtitle with completion status
    if completed ~= nil then
      if completed then
        if inTime then
          f.subtitle:SetText("|cff00ff00Key Completed In Time!|r")
        else
          f.subtitle:SetText("|cffffff00Key Completed (Over Time)|r")
        end
      else
        f.subtitle:SetText("|cffff0000Key Failed|r")
      end
    else
      f.subtitle:SetText("")
    end

    for i,row in ipairs(self.rows) do row:Hide() end
    local startY = -60  -- Moved down to accommodate subtitle
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
        row.button:SetSize(105, 22)
        row.button:SetPoint("RIGHT", 0, 0)
        row.button:SetText("Rate Player")
        row.button:SetScript("OnClick", function()
          addon:ShowRateFrame(row.playerName)
        end)
        self.rows[i] = row
      end
      row.playerName = name
      row.nameFS:SetText(name)
      row:Show()
    end

    local height = 120 + (#names * 36)  -- Increased base height for subtitle
    self:SetHeight(math.min(480, height))
  end

  f.close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.close:SetSize(80, 24)
  f.close:SetPoint("BOTTOMRIGHT", -16, 16)
  f.close:SetText("Close")
  f.close:SetScript("OnClick", function() f:Hide() end)
  f.close:SetFrameStrata(f:GetFrameStrata())
  f.close:SetFrameLevel((f:GetFrameLevel() or 0) + 2)

  if not f.logo then
    f.logo = f:CreateTexture(nil, "ARTWORK")
    f.logo:SetSize(LOGO_WIDTH, LOGO_HEIGHT)
    f.logo:SetPoint("BOTTOMLEFT", 16, -35)
    f.logo:SetTexture(LOGO_PATH)
    f.logo:Hide()
  end
  f.logo:SetShown(true)

  f:Hide()
  return f
end

local postRunFrame

function UI:ShowPostRun(names, completed, inTime)
  postRunFrame = postRunFrame or CreatePostRunFrame()
  postRunFrame:SetMembers(names or {}, completed, inTime)
  postRunFrame:Show()
end

local function CreateLogsFrame()
  local f = CreateFrame("Frame", "PugRaterLogsFrame", UIParent, "BackdropTemplate")
  f:SetFrameStrata("DIALOG")
  f:SetFrameLevel(200)
  f:SetToplevel(true)
  f:SetSize(650, 450)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  
  f:SetScript("OnKeyDown", function(self, key)
    if key == "ESCAPE" then
      self:Hide()
      return
    end
  end)
  f:EnableKeyboard(true)
  f:SetPropagateKeyboardInput(true)
  
  f:SetBackdrop({
    bgFile = "Interface/Tooltips/UI-Tooltip-Background",
    edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  f:SetBackdropColor(0,0,0,0.9)

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  f.title:SetPoint("TOP", 0, -16)
  f.title:SetText("Activity Logs")

  f.playerName = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.playerName:SetPoint("TOP", 0, -40)
  f.playerName:SetText("")

  f.closeX = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  f.closeX:SetSize(24, 24)
  f.closeX:SetPoint("TOPRIGHT", -8, -8)
  f.closeX:SetText("X")
  f.closeX:SetScript("OnClick", function() f:Hide() end)

  f.scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  f.scroll:SetPoint("TOPLEFT", 16, -70)
  f.scroll:SetPoint("BOTTOMRIGHT", -36, 50)

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetSize(1,1)
  f.scroll:SetScrollChild(f.content)

  f.noDataText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.noDataText:SetPoint("CENTER", f.scroll, "CENTER", 0, 0)
  f.noDataText:SetText("No activity data found for this player.")
  f.noDataText:SetTextColor(0.7, 0.7, 0.7)

  f.infoText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.infoText:SetPoint("BOTTOM", 0, 16)
  f.infoText:SetText("Note: Only activities since PugRater was installed are tracked.")
  f.infoText:SetTextColor(0.6, 0.6, 0.6)

  f.rows = {}

  f:Hide()
  return f
end

local logsFrame

function UI:ShowLogs(playerName)
  logsFrame = logsFrame or CreateLogsFrame()
  
  for i, row in ipairs(logsFrame.rows) do
    row:Hide()
  end
  
  local activities = {}
  
  -- Debug output
  if playerName then
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r ShowLogs called for: " .. tostring(playerName))
    if PugRaterDB and PugRaterDB.activities then
      DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r Activities table exists")
      local count = 0
      for key, _ in pairs(PugRaterDB.activities) do
        count = count + 1
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r Activity key: " .. tostring(key))
      end
      DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r Total activity keys: " .. count)
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r No activities table found")
    end
  end
  
  if playerName then
    -- Show specific player activities
    logsFrame.playerName:SetText("Activity with: " .. playerName)
    if PugRaterDB and PugRaterDB.activities and PugRaterDB.activities[playerName] then
      activities = PugRaterDB.activities[playerName]
      DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r Found " .. #activities .. " activities for " .. playerName)
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0[PugRater Debug]|r No activities found for " .. tostring(playerName))
    end
  else
    -- Show all run history
    logsFrame.playerName:SetText("All Mythic+ Run History")
    if PugRaterDB and PugRaterDB.history then
      for _, run in ipairs(PugRaterDB.history) do
        local dungeonName = run.dungeonName or "Unknown Dungeon"
        local activity = {
          date = date("%m/%d %H:%M", run.date),
          type = "M+",
          name = string.format("%s +%d", dungeonName, run.level or 0),
          completed = run.completed,
          inTime = run.inTime,
          completionStatus = run.inTime and "timed" or (run.completed and "overtime" or "depleted"),
          duration = run.duration and string.format("%dm", math.floor(run.duration / 60)) or "Unknown"
        }
        table.insert(activities, activity)
      end
      -- Sort by most recent first
      table.sort(activities, function(a, b) 
        return (a.date or "") > (b.date or "")
      end)
    end
  end
  
  if #activities == 0 then
    logsFrame.noDataText:Show()
    logsFrame.content:SetSize(600, 100)
  else
    logsFrame.noDataText:Hide()
    
    local ROW_H = 24
    local WIDTH = logsFrame.scroll:GetWidth() or 600
    logsFrame.content:SetSize(WIDTH-20, math.max(#activities * ROW_H, logsFrame.scroll:GetHeight()))
    
    for i, activity in ipairs(activities) do
      local row = logsFrame.rows[i]
      if not row then
        row = CreateFrame("Frame", nil, logsFrame.content)
        row:SetSize(WIDTH-20, ROW_H)
        if i == 1 then
          row:SetPoint("TOPLEFT", 0, 0)
        else
          row:SetPoint("TOPLEFT", logsFrame.rows[i-1], "BOTTOMLEFT", 0, -2)
        end
        
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture("Interface/Buttons/UI-Listbox-Highlight")
        row.bg:SetAlpha(0.1)
        
        row.date = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.date:SetPoint("LEFT", 8, 0)
        row.date:SetWidth(80)
        row.date:SetJustifyH("LEFT")
        
        row.type = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.type:SetPoint("LEFT", row.date, "RIGHT", 8, 0)
        row.type:SetWidth(60)
        row.type:SetJustifyH("LEFT")
        
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.name:SetPoint("LEFT", row.type, "RIGHT", 8, 0)
        row.name:SetWidth(180)
        row.name:SetJustifyH("LEFT")
        
        row.result = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.result:SetPoint("LEFT", row.name, "RIGHT", 8, 0)
        row.result:SetWidth(120)
        row.result:SetJustifyH("LEFT")
        
        row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.time:SetPoint("LEFT", row.result, "RIGHT", 8, 0)
        row.time:SetWidth(80)
        row.time:SetJustifyH("LEFT")
        
        logsFrame.rows[i] = row
      end
      
      row.date:SetText(activity.date or "Unknown")
      row.type:SetText(activity.type or "Unknown")
      row.name:SetText(activity.name or "Unknown")
      
      if activity.type == "M+" and activity.completionStatus then
        if activity.completionStatus == "timed" then
          row.result:SetText("Timed")
          row.result:SetTextColor(0, 1, 0) -- Green for timed keys
        elseif activity.completionStatus == "overtime" then
          row.result:SetText("Over Time")
          row.result:SetTextColor(0, 0.5, 1) -- Blue for over time
        else
          row.result:SetText("Depleted")
          row.result:SetTextColor(1, 0, 0) -- Red for depleted keys
        end
      else
        if activity.completed then
          row.result:SetText("Completed")
          row.result:SetTextColor(0, 1, 0)
        else
          row.result:SetText("Failed")
          row.result:SetTextColor(1, 0, 0)
        end
      end
      
      row.time:SetText(activity.time or "Unknown")
      
      row:Show()
    end
  end
  
  logsFrame:Show()
end

local keyTracker = CreateFrame("Frame")
local groupMembersAtStart = {}
local raidMembersAtStart = {}
local currentKeyInfo = nil

local function InitializeActivityDB()
  if not PugRaterDB then PugRaterDB = {} end
  if not PugRaterDB.activities then PugRaterDB.activities = {} end
end

local function GetGroupMembers()
  local members = {}
  local numGroupMembers = GetNumGroupMembers()
  
  if numGroupMembers > 0 then
    for i = 1, numGroupMembers do
      local unit = (IsInRaid() and "raid" or "party") .. i
      if UnitExists(unit) then
        local name, realm = UnitFullName(unit)
        if name then
          local fullName = name
          if realm and realm ~= "" and realm ~= GetRealmName() then
            fullName = name .. "-" .. realm
          else
            fullName = name .. "-" .. GetRealmName()
          end
          table.insert(members, fullName)
        end
      end
    end
  end
  
  return members
end

local function RecordActivity(activityData, membersList)
  InitializeActivityDB()
  
  for _, memberName in ipairs(membersList) do
    if not PugRaterDB.activities[memberName] then
      PugRaterDB.activities[memberName] = {}
    end
    
    table.insert(PugRaterDB.activities[memberName], activityData)
  end
end

keyTracker:SetScript("OnEvent", function(self, event, ...)
  if event == "CHALLENGE_MODE_START" then
    if currentKeyInfo and groupMembersAtStart and #groupMembersAtStart > 0 then
      local mapName = C_ChallengeMode.GetMapUIInfo(currentKeyInfo.mapID)
      local keyData = {
        date = date("%Y-%m-%d"),
        type = "M+",
        name = (mapName or "Unknown") .. " +" .. (currentKeyInfo.level or "?"),
        completed = false,
        completionStatus = "failed",
        time = "Abandoned",
        timestamp = time()
      }
      
      print("PugRater: Previous key abandoned/failed - " .. keyData.name)
      RecordActivity(keyData, groupMembersAtStart)
    end
    
    groupMembersAtStart = GetGroupMembers()
    local mapID = C_ChallengeMode.GetActiveChallengeMapID()
    if mapID then
      local level = select(3, C_ChallengeMode.GetActiveKeystoneInfo()) or 
                   select(2, C_MythicPlus.GetCurrentAffixes()) or 
                   C_ChallengeMode.GetActiveKeystoneLevel() or
                   select(4, GetInstanceInfo())
      
      currentKeyInfo = {
        mapID = mapID,
        level = level,
        startTime = time()
      }
      
      print("PugRater: Started tracking M+ key - " .. (C_ChallengeMode.GetMapUIInfo(mapID) or "Unknown") .. " +" .. (level or "?"))
    end
    
  elseif event == "CHALLENGE_MODE_COMPLETED" then
    local mapID, level, time, onTime, keystoneUpgraded = C_ChallengeMode.GetCompletionInfo()
    print("PugRater: CHALLENGE_MODE_COMPLETED - mapID:", mapID, "level:", level, "time:", time, "onTime:", onTime)
    
    if mapID and level and groupMembersAtStart then
      local mapName = C_ChallengeMode.GetMapUIInfo(mapID)
      local minutes = math.floor(time / 60)
      local seconds = time % 60
      local timeString = string.format("%d:%02d", minutes, seconds)
      
      local completionStatus = "failed" -- Default to failed
      if onTime then
        completionStatus = "timed" -- Completed in time (green)
      elseif time > 0 then
        completionStatus = "overtime" -- Completed over time (blue)
      end
      
      local keyData = {
        date = date("%Y-%m-%d"),
        type = "M+",
        name = (mapName or "Unknown") .. " +" .. level,
        completed = (time > 0), -- Key was completed (either timed or overtime)
        completionStatus = completionStatus, -- Additional field for M+ status
        time = timeString,
        timestamp = time()
      }
      
      print("PugRater: Recording M+ completion:", keyData.name, "Status:", completionStatus)
      RecordActivity(keyData, groupMembersAtStart)
      currentKeyInfo = nil
    else
      print("PugRater: Failed to record M+ - missing data. mapID:", mapID, "level:", level, "groupMembers:", #(groupMembersAtStart or {}))
    end
    
  elseif event == "ENCOUNTER_START" then
    local instanceName, instanceType = GetInstanceInfo()
    if instanceType == "raid" then
      raidMembersAtStart = GetGroupMembers()
    end
    
  elseif event == "ENCOUNTER_END" then
    local encounterID, encounterName, difficultyID, groupSize, success = ...
    local instanceName, instanceType = GetInstanceInfo()
    
    if encounterName and success ~= nil and instanceType == "raid" and raidMembersAtStart then
      local difficultyName = GetDifficultyInfo(difficultyID)
      
      local raidData = {
        date = date("%Y-%m-%d"),
        type = "Raid",
        name = (instanceName or "Unknown") .. " - " .. (encounterName or "Unknown Boss"),
        completed = (success == 1),
        time = (difficultyName or "Unknown"),
        timestamp = time()
      }
      
      RecordActivity(raidData, raidMembersAtStart)
    end
    
  elseif event == "CHALLENGE_MODE_RESET" then
    if currentKeyInfo and groupMembersAtStart then
      local mapName = C_ChallengeMode.GetMapUIInfo(currentKeyInfo.mapID)
      local keyData = {
        date = date("%Y-%m-%d"),
        type = "M+",
        name = (mapName or "Unknown") .. " +" .. (currentKeyInfo.level or "?"),
        completed = false,
        completionStatus = "failed",
        time = "Depleted",
        timestamp = time()
      }
      
      RecordActivity(keyData, groupMembersAtStart)
      currentKeyInfo = nil
    end
    
  elseif event == "PLAYER_ENTERING_WORLD" then
    local isInstance, instanceType = IsInInstance()
    
    if currentKeyInfo and groupMembersAtStart and #groupMembersAtStart > 0 and 
       (not isInstance or instanceType ~= "party") then
      local mapName = C_ChallengeMode.GetMapUIInfo(currentKeyInfo.mapID)
      local keyData = {
        date = date("%Y-%m-%d"),
        type = "M+",
        name = (mapName or "Unknown") .. " +" .. (currentKeyInfo.level or "?"),
        completed = false,
        completionStatus = "failed",
        time = "Left Instance",
        timestamp = time()
      }
      
      print("PugRater: Key failed due to leaving instance - " .. keyData.name)
      RecordActivity(keyData, groupMembersAtStart)
    end
    
    if not isInstance or instanceType ~= "party" then
      currentKeyInfo = nil
      groupMembersAtStart = {}
    end
    
  elseif event == "ADDON_LOADED" then
    local addonName = ...
    if addonName == "PugRater" then
      InitializeActivityDB()
    end
  end
end)

keyTracker:RegisterEvent("CHALLENGE_MODE_START")
keyTracker:RegisterEvent("CHALLENGE_MODE_COMPLETED")
keyTracker:RegisterEvent("CHALLENGE_MODE_RESET")
keyTracker:RegisterEvent("ENCOUNTER_START")
keyTracker:RegisterEvent("ENCOUNTER_END")
keyTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
keyTracker:RegisterEvent("ADDON_LOADED")
