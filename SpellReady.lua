-- SpellReady (Vanilla 1.12.1 / Turtle WoW style)
-- Center-screen pulse when enabled spells become ready + simple checkbox menu.

-- SavedVariables (ensure exists)
SpellReadyDB = SpellReadyDB or {}

local DEFAULT_SPELLS = {
  "Aimed Shot",
  "Multi-Shot",
  "Arcane Shot",
  "Raptor Strike",
  "Feign Death",
  "Wing Clip",
  "Deterrence",
  "Counterattack",
  "Freezing Trap",
  "Frost Trap",
}

local function SR_Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SpellReady:|r " .. msg)
end

------------------------------------------------------------
-- Spellbook helpers (MUST be defined before use)
------------------------------------------------------------
local function FindSpellBookSlot(spellName)
  if not spellName or spellName == "" then return nil end

  local i = 1
  while true do
    local name = GetSpellName(i, BOOKTYPE_SPELL)
    if not name then break end
    if name == spellName then return i end
    i = i + 1
  end
  return nil
end

local function GetSpellIcon(spellName)
  local slot = FindSpellBookSlot(spellName)
  if not slot then return nil end
  return GetSpellTexture(slot, BOOKTYPE_SPELL)
end

local function IsSpellOnCooldown(spellName)
  local slot = FindSpellBookSlot(spellName)
  if not slot then return false end

  local start, duration, enabled = GetSpellCooldown(slot, BOOKTYPE_SPELL)
  if enabled == 0 then return false end

  -- ignore GCD
  if start and duration and start > 0 and duration > 1.5 then
    return true
  end
  return false
end

------------------------------------------------------------
-- Defaults
------------------------------------------------------------
local function EnsureDefaults()
  if type(SpellReadyDB) ~= "table" then SpellReadyDB = {} end
  if type(SpellReadyDB.spells) ~= "table" then SpellReadyDB.spells = {} end
  if SpellReadyDB.size == nil then SpellReadyDB.size = 80 end
  if SpellReadyDB.duration == nil then SpellReadyDB.duration = 0.6 end
  if SpellReadyDB.minScale == nil then SpellReadyDB.minScale = 0.25 end
  if SpellReadyDB.alphaStart == nil then SpellReadyDB.alphaStart = 1.0 end
  if SpellReadyDB.alphaEnd == nil then SpellReadyDB.alphaEnd = 0.0 end

  -- Initialize defaults only if empty
  local hasAny = false
  for _ in pairs(SpellReadyDB.spells) do hasAny = true break end

  if not hasAny then
    for _, s in ipairs(DEFAULT_SPELLS) do
      SpellReadyDB.spells[s] = false
    end
    SpellReadyDB.spells["Aimed Shot"] = true
    SpellReadyDB.spells["Multi-Shot"] = true
  else
    -- Ensure new default spells exist in DB (if you add more later)
    for _, s in ipairs(DEFAULT_SPELLS) do
      if SpellReadyDB.spells[s] == nil then
        SpellReadyDB.spells[s] = false
      end
    end
  end
end

------------------------------------------------------------
-- Center Pulse Frame
------------------------------------------------------------
local pulse = CreateFrame("Frame", "SpellReadyPulseFrame", UIParent)
pulse:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
pulse:SetWidth(80)
pulse:SetHeight(80)
pulse:Hide()

local pulseTex = pulse:CreateTexture(nil, "ARTWORK")
pulseTex:SetAllPoints(pulse)
pulseTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
pulse.tex = pulseTex

local anim = { active = false, t = 0 }

local function StartPulseForSpell(spellName)
  local icon = GetSpellIcon(spellName)
  if not icon then return end

  pulse.tex:SetTexture(icon)
  anim.active = true
  anim.t = 0

  local startSize = SpellReadyDB.size * SpellReadyDB.minScale
  pulse:SetWidth(startSize)
  pulse:SetHeight(startSize)
  pulse:SetAlpha(SpellReadyDB.alphaStart)
  pulse:Show()
end

local function StopPulse()
  anim.active = false
  pulse:Hide()
end

------------------------------------------------------------
-- Cooldown Watcher (multiple spells)
------------------------------------------------------------
local lastOnCD = {} -- spellName -> bool

local function ScanSpellsAndTrigger()
  if not SpellReadyDB.spells then return end

  for spellName, enabled in pairs(SpellReadyDB.spells) do
    if enabled then
      local onCD = IsSpellOnCooldown(spellName)

      if lastOnCD[spellName] == true and onCD == false then
        StartPulseForSpell(spellName)
      end

      lastOnCD[spellName] = onCD
    end
  end
end

------------------------------------------------------------
-- Menu Window with Checkboxes
------------------------------------------------------------
local MENU_PADDING_TOP = 72
local MENU_PADDING_BOTTOM = 60
local ROW_H = 22
local MENU_MIN_H = 260

local menu = CreateFrame("Frame", "SpellReadyMenu", UIParent)
menu:SetWidth(280) -- a bit wider
-- height will be set later after we know how many rows we need
menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
menu:SetMovable(true)
menu:EnableMouse(true)
menu:RegisterForDrag("LeftButton")
menu:SetScript("OnDragStart", function() menu:StartMoving() end)
menu:SetScript("OnDragStop", function() menu:StopMovingOrSizing() end)
menu:Hide()

menu:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true, tileSize = 32, edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 }
})

local title = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOP", menu, "TOP", 0, -14)
title:SetText("SpellReady")

local sub = menu:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOP", title, "BOTTOM", 0, -6)
sub:SetText("Select spells to track (drag to move)")

local closeBtn = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6)

local testBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
testBtn:SetWidth(80)
testBtn:SetHeight(22)
testBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 16)
testBtn:SetText("Test")
testBtn:SetScript("OnClick", function()
  for spellName, enabled in pairs(SpellReadyDB.spells) do
    if enabled then
      StartPulseForSpell(spellName)
      return
    end
  end
  SR_Print("Enable at least one spell in the menu first.")
end)

-- Size slider (icon size)
local sizeLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
sizeLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 22)
sizeLabel:SetText("Size: " .. tostring(SpellReadyDB.size or 80))

local sizeSlider = CreateFrame("Slider", "SpellReadySizeSlider", menu, "OptionsSliderTemplate")
sizeSlider:SetWidth(140)
sizeSlider:SetHeight(16)
sizeSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 40)
sizeSlider:SetMinMaxValues(40, 160)
sizeSlider:SetValueStep(5)
if sizeSlider.SetObeyStepOnDrag then
  sizeSlider:SetObeyStepOnDrag(true)
end

-- Hide default min/max text if it exists (varies by client)
local low = getglobal(sizeSlider:GetName() .. "Low")
local high = getglobal(sizeSlider:GetName() .. "High")
local text = getglobal(sizeSlider:GetName() .. "Text")
if low then low:Hide() end
if high then high:Hide() end
if text then text:Hide() end

sizeSlider:SetScript("OnValueChanged", function()
  local v = tonumber(sizeSlider:GetValue()) or 80
  v = math.floor((v / 5) + 0.5) * 5
  SpellReadyDB.size = v
  sizeLabel:SetText("Size: " .. v)
end)

local checkboxes = {}

local function CreateCheckbox(parent, spellName, x, y)
  -- Give it a unique GLOBAL name so cb:GetName() is not nil
  local safe = string.gsub(spellName, "[^%w]", "")
  local cbName = "SpellReadyCB_" .. safe

  local cb = CreateFrame("CheckButton", cbName, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

  local text = getglobal(cbName .. "Text")
  if text then text:SetText(spellName) end

  cb:SetChecked(SpellReadyDB.spells[spellName] == true)

  cb:SetScript("OnClick", function()
    SpellReadyDB.spells[spellName] = cb:GetChecked() and true or false
    lastOnCD[spellName] = IsSpellOnCooldown(spellName)
  end)

  return cb
end

local function BuildMenu()
  -- clear old
  for i = 1, table.getn(checkboxes) do
    if checkboxes[i] then
      checkboxes[i]:Hide()
    end
    checkboxes[i] = nil
  end

  local y = -60
  local x = 18
  local rowH = ROW_H

  for _, spellName in ipairs(DEFAULT_SPELLS) do
    if SpellReadyDB.spells[spellName] == nil then
      SpellReadyDB.spells[spellName] = false
    end

    local cb = CreateCheckbox(menu, spellName, x, y)
    table.insert(checkboxes, cb)
    y = y - rowH
  end

  -- Resize menu so all spells fit (no overflow)
  local neededRows = table.getn(DEFAULT_SPELLS)
  local neededH = MENU_PADDING_TOP + (neededRows * rowH) + MENU_PADDING_BOTTOM
  if neededH < MENU_MIN_H then neededH = MENU_MIN_H end
  menu:SetHeight(neededH)

  -- Keep slider in sync with saved value
  if sizeSlider then
    sizeSlider:SetValue(SpellReadyDB.size or 80)
    sizeLabel:SetText("Size: " .. tostring(SpellReadyDB.size or 80))
  end
end

------------------------------------------------------------
-- Main driver frame
------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:SetScript("OnEvent", function()
  EnsureDefaults()
  BuildMenu()

  -- init cooldown states
  for spellName, enabled in pairs(SpellReadyDB.spells) do
    if enabled then
      lastOnCD[spellName] = IsSpellOnCooldown(spellName)
    end
  end

  SR_Print("Loaded. Type /sr to open the menu.")
end)

driver:SetScript("OnUpdate", function()
  ScanSpellsAndTrigger()

  if not anim.active then return end
  anim.t = anim.t + arg1

  local p = anim.t / SpellReadyDB.duration
  if p >= 1 then
    StopPulse()
    return
  end

  local scale = SpellReadyDB.minScale + (1.0 - SpellReadyDB.minScale) * p
  local sz = SpellReadyDB.size * scale
  pulse:SetWidth(sz)
  pulse:SetHeight(sz)

  local a = SpellReadyDB.alphaStart + (SpellReadyDB.alphaEnd - SpellReadyDB.alphaStart) * p
  pulse:SetAlpha(a)
end)

------------------------------------------------------------
-- Slash command: /sr
------------------------------------------------------------
SLASH_SPELLREADY1 = "/sr"
SlashCmdList["SPELLREADY"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "test" then
    testBtn:GetScript("OnClick")()
    return
  end

  if menu:IsShown() then
    menu:Hide()
  else
    menu:Show()
  end
end
