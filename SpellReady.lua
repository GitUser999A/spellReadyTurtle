-- SpellReady (Vanilla 1.12.1 / Turtle WoW style)
-- Center-screen pulse when enabled spells become ready + simple checkbox menu.

-- SavedVariables (ensure exists)
SpellReadyDB = SpellReadyDB or {}

local DEFAULT_SPELLS = {
  "Aimed Shot",
  "Multi-Shot",
  "Arcane Shot",
  "Rapid Fire",
  "Readiness",
  "Scatter Shot",
  "Concussive Shot",
  "Distracting Shot",
  "Viper Sting",
  "Serpent Sting",
  "Wyvern Sting",
  "Volley",
  "Raptor Strike",
  "Mongoose Bite",
  "Disengage",
  "Feign Death",
  "Wing Clip",
  "Deterrence",
  "Counterattack",
  "Intimidation",
  "Bestial Wrath",
  "Scare Beast",
  "Flare",
  "Immolation Trap",
  "Explosive Trap",
  "Freezing Trap",
  "Frost Trap",
}

table.sort(DEFAULT_SPELLS)

local DEFAULT_ICON_SIZE = 110
local DEFAULT_TEXT_SIZE = 240
local DEFAULT_ROW_SIZE = 64
local DEFAULT_ICON_FADE = 1.20
local DEFAULT_TEXT_FADE = 1.20
local DEFAULT_B_USED_ALPHA = 0.35
local SR_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local function SR_Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00SpellReady:|r " .. msg)
end

local function SR_PrintLoaded()
  DEFAULT_CHAT_FRAME:AddMessage("|cff7fff7f[SpellReadyTurtle]|r Loaded. Open menu with |cffffff00/srt|r or |cffffff00/spellready|r.")
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
  if SpellReadyDB.size == nil then SpellReadyDB.size = DEFAULT_ICON_SIZE end
  if SpellReadyDB.posX == nil then SpellReadyDB.posX = 0 end
  if SpellReadyDB.posY == nil then SpellReadyDB.posY = 0 end
  if SpellReadyDB.duration == nil then SpellReadyDB.duration = 0.6 end
  if SpellReadyDB.textFadeDuration == nil then SpellReadyDB.textFadeDuration = DEFAULT_TEXT_FADE end
  if SpellReadyDB.iconFadeDuration == nil then SpellReadyDB.iconFadeDuration = DEFAULT_ICON_FADE end
  if SpellReadyDB.minScale == nil then SpellReadyDB.minScale = 0.25 end
  if SpellReadyDB.alphaStart == nil then SpellReadyDB.alphaStart = 1.0 end
  if SpellReadyDB.alphaEnd == nil then SpellReadyDB.alphaEnd = 0.0 end
  if SpellReadyDB.displayMode == nil then SpellReadyDB.displayMode = "ICON" end
  if SpellReadyDB.designMode == nil then SpellReadyDB.designMode = "A" end
  if SpellReadyDB.designBPosX == nil then SpellReadyDB.designBPosX = 0 end
  if SpellReadyDB.designBPosY == nil then SpellReadyDB.designBPosY = -140 end
  if SpellReadyDB.designBSize == nil then SpellReadyDB.designBSize = DEFAULT_ROW_SIZE end
  if SpellReadyDB.designBFlyHeight == nil then SpellReadyDB.designBFlyHeight = 96 end
  if SpellReadyDB.designBUseTransparent == nil then SpellReadyDB.designBUseTransparent = false end
  if SpellReadyDB.designBUsedAlpha == nil then SpellReadyDB.designBUsedAlpha = DEFAULT_B_USED_ALPHA end
  if SpellReadyDB.fontSize == nil then SpellReadyDB.fontSize = DEFAULT_TEXT_SIZE end
  if type(SpellReadyDB.fontColor) ~= "table" then
    SpellReadyDB.fontColor = { r = 1.0, g = 0.82, b = 0.0 }
  end
  if SpellReadyDB.fontColor.r == nil then SpellReadyDB.fontColor.r = 1.0 end
  if SpellReadyDB.fontColor.g == nil then SpellReadyDB.fontColor.g = 0.82 end
  if SpellReadyDB.fontColor.b == nil then SpellReadyDB.fontColor.b = 0.0 end

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
pulse:SetWidth(80)
pulse:SetHeight(80)
pulse:SetMovable(true)
pulse:EnableMouse(true)
pulse:RegisterForDrag("LeftButton")
pulse:Hide()

local pulseTex = pulse:CreateTexture(nil, "ARTWORK")
pulseTex:SetAllPoints(pulse)
pulseTex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
pulse.tex = pulseTex

local pulseText = pulse:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
pulseText:SetWidth(320)
pulseText:SetJustifyH("CENTER")
pulseText:SetPoint("CENTER", pulse, "CENTER", 0, 0)
pulseText:Hide()
pulse.text = pulseText

local anim = { active = false, t = 0 }
local testQueue = {}
local testQueueIndex = 1
local testSequenceActive = false
local designBButtons = {}
local designBButtonBySpell = {}
local designBAmmoBorderBySpell = {}
local designBArrowsBySpell = {}
local designBFlyAnims = {}
local designBRowFadeAnims = {}
local IsDesignBMode
local ammoPulse = {
  activeSpell = nil,
  eventSpell = nil,
  eventExpiresAt = 0,
  lockAndLoadActive = false,
  t = 0,
  scanT = 0,
  r = 1.0,
  g = 0.82,
  b = 0.0,
}

local DESIGN_B_GAP = 4

local SR_AMMO_BUFF_TO_SPELL = {
  ["explosive ammunition"] = { spell = "Multi-Shot", r = 1.0, g = 0.84, b = 0.18 },
  ["explossive ammunition"] = { spell = "Multi-Shot", r = 1.0, g = 0.84, b = 0.18 },
  ["enchanted ammunition"] = { spell = "Arcane Shot", r = 1.0, g = 0.84, b = 0.18 },
  ["poisonous ammunition"] = { spell = "Serpent Sting", r = 1.0, g = 0.84, b = 0.18 },
}

local srBuffScanTip = CreateFrame("GameTooltip", "SpellReadyBuffScanTooltip", nil, "GameTooltipTemplate")
srBuffScanTip:SetOwner(UIParent, "ANCHOR_NONE")

local function MatchAmmoSpellStrict(txt)
  if not txt or txt == "" then return nil end
  local s = string.lower(txt)

  local direct = SR_AMMO_BUFF_TO_SPELL[s]
  if direct then
    return direct.spell, direct.r, direct.g, direct.b
  end

  for buffName, data in pairs(SR_AMMO_BUFF_TO_SPELL) do
    if string.find(s, buffName, 1, true) then
      return data.spell, data.r, data.g, data.b
    end
  end

  return nil
end

local function MatchAmmoSpellFromText(txt)
  local spell, r, g, b = MatchAmmoSpellStrict(txt)
  if spell then
    return spell, r, g, b
  end

  local s = string.lower(txt or "")

  if string.find(s, "multi-shot", 1, true) or string.find(s, "explos", 1, true) then
    local d = SR_AMMO_BUFF_TO_SPELL["explosive ammunition"]
    return d.spell, d.r, d.g, d.b
  end
  if string.find(s, "arcane shot", 1, true) or string.find(s, "100% increased damage", 1, true) then
    local d = SR_AMMO_BUFF_TO_SPELL["enchanted ammunition"]
    return d.spell, d.r, d.g, d.b
  end
  if string.find(s, "serpent sting", 1, true) or string.find(s, "poison", 1, true) then
    local d = SR_AMMO_BUFF_TO_SPELL["poisonous ammunition"]
    return d.spell, d.r, d.g, d.b
  end

  return nil
end

local function MatchAmmoFromTooltipLines()
  local i
  for i = 1, 4 do
    local left = getglobal("SpellReadyBuffScanTooltipTextLeft" .. i)
    if left then
      local spell, r, g, b = MatchAmmoSpellFromText(left:GetText())
      if spell then
        return spell, r, g, b
      end
    end
  end
  return nil
end

local function TryMatchAmmoFromPlayerBuffIndex(index)
  if not srBuffScanTip or not srBuffScanTip.SetPlayerBuff then return nil end
  if index == nil or index < 0 then return nil end
  srBuffScanTip:ClearLines()
  srBuffScanTip:SetPlayerBuff(index)
  return MatchAmmoFromTooltipLines()
end

local function FindAmmoProcFromVisibleBuffButtons()
  local seen = {}
  local suffix
  for suffix = 0, 32 do
    local button = getglobal("BuffButton" .. suffix)
    if button and button.IsVisible and button:IsVisible() then
      local candidates = {
        button.buffIndex,
        button.GetID and button:GetID() or nil,
        suffix,
        suffix - 1,
      }
      local i
      for i = 1, table.getn(candidates) do
        local idx = candidates[i]
        if idx ~= nil and idx >= 0 and not seen[idx] then
          seen[idx] = true
          local spell, r, g, b = TryMatchAmmoFromPlayerBuffIndex(idx)
          if spell then
            return spell, r, g, b
          end
        end
      end
    end
  end
  return nil
end

local function SetActiveAmmoProc(spell, r, g, b)
  if not spell then return end
  ammoPulse.eventSpell = spell
  ammoPulse.eventExpiresAt = (GetTime and GetTime() or 0) + 1.5
  ammoPulse.activeSpell = spell
  ammoPulse.t = 0
  ammoPulse.r = r or ammoPulse.r
  ammoPulse.g = g or ammoPulse.g
  ammoPulse.b = b or ammoPulse.b
  ammoPulse.scanT = 0
end

local function UpdateAmmoEventState(msg)
  local s = string.lower(msg or "")

  if string.find(s, "lock and load", 1, true) then
    if string.find(s, "fade", 1, true) or string.find(s, "fades", 1, true) then
      ammoPulse.lockAndLoadActive = false
    else
      ammoPulse.lockAndLoadActive = true
    end
    return true
  end

  if string.find(s, "you are afflicted by", 1, true) and string.find(s, "ammunition", 1, true) then
    local spell, r, g, b = MatchAmmoSpellStrict(msg)
    if spell then
      SetActiveAmmoProc(spell, r, g, b)
      return true
    end
  end

  if string.find(s, "your ", 1, true) and string.find(s, " ammunition", 1, true) and string.find(s, " hits ", 1, true) then
    local spell, r, g, b = MatchAmmoSpellStrict(msg)
    if spell then
      SetActiveAmmoProc(spell, r, g, b)
      return true
    end
  end

  if string.find(s, " is afflicted by ", 1, true) and string.find(s, "ammunition", 1, true) then
    local spell, r, g, b = MatchAmmoSpellStrict(msg)
    if spell then
      SetActiveAmmoProc(spell, r, g, b)
      return true
    end
  end

  if string.find(s, "ammunition", 1, true) and (string.find(s, "fade", 1, true) or string.find(s, "fades", 1, true) or string.find(s, "removed", 1, true)) then
    local fadedSpell = MatchAmmoSpellStrict(msg)
    if fadedSpell and ammoPulse.eventSpell == fadedSpell then
      ammoPulse.eventSpell = nil
      ammoPulse.eventExpiresAt = 0
      ammoPulse.activeSpell = nil
    end
    ammoPulse.scanT = 0
    return true
  end

  local spell, r, g, b = MatchAmmoSpellStrict(msg)
  if spell then
    SetActiveAmmoProc(spell, r, g, b)
    return true
  end

  if string.find(s, "multi-shot", 1, true) or string.find(s, "arcane shot", 1, true) or string.find(s, "serpent sting", 1, true) then
    ammoPulse.eventSpell = nil
    ammoPulse.eventExpiresAt = 0
    ammoPulse.activeSpell = nil
    ammoPulse.scanT = 0
    return true
  end

  if string.find(s, "aimed shot", 1, true) then
    ammoPulse.lockAndLoadActive = false
    ammoPulse.scanT = 0
    return true
  end

  return false
end

local function GetPlayerBuffName(index)
  if not UnitBuff then return nil end

  local v1 = UnitBuff("player", index)
  if not v1 then return nil end

  -- Clients with modern aura returns may provide the name directly.
  if type(v1) == "string" and not string.find(v1, "\\") then
    return v1
  end

  if srBuffScanTip and srBuffScanTip.SetUnitBuff then
    srBuffScanTip:ClearLines()
    srBuffScanTip:SetUnitBuff("player", index)
    local left = getglobal("SpellReadyBuffScanTooltipTextLeft1")
    if left then
      return left:GetText()
    end
  end

  return nil
end

local function FindActiveAmmoProcSpell()
  local idx

  -- Modern/compat path: UnitBuff with tolerant index handling.
  if UnitBuff then
    local miss = 0
    for idx = 0, 50 do
      local hadAny = false

      local a = UnitBuff("player", idx)
      if a then
        hadAny = true
        local buffName = GetPlayerBuffName(idx)
        local spell, r, g, b = MatchAmmoSpellFromText(buffName)
        if spell then
          return spell, r, g, b
        end

        if srBuffScanTip and srBuffScanTip.SetUnitBuff then
          srBuffScanTip:ClearLines()
          srBuffScanTip:SetUnitBuff("player", idx)
          spell, r, g, b = MatchAmmoFromTooltipLines()
          if spell then
            return spell, r, g, b
          end
        end
      end

      local b = UnitBuff("player", idx + 1)
      if b then
        hadAny = true
        local buffName = GetPlayerBuffName(idx + 1)
        local spell, r, g, bb = MatchAmmoSpellFromText(buffName)
        if spell then
          return spell, r, g, bb
        end

        if srBuffScanTip and srBuffScanTip.SetUnitBuff then
          srBuffScanTip:ClearLines()
          srBuffScanTip:SetUnitBuff("player", idx + 1)
          spell, r, g, bb = MatchAmmoFromTooltipLines()
          if spell then
            return spell, r, g, bb
          end
        end
      end

      if hadAny then
        miss = 0
      else
        miss = miss + 1
        if miss >= 8 and idx >= 8 then
          break
        end
      end
    end
  end

  -- Vanilla fallback: GetPlayerBuff + tooltip text.
  if GetPlayerBuff and srBuffScanTip and srBuffScanTip.SetPlayerBuff then
    for idx = 0, 31 do
      local buffIndex = GetPlayerBuff(idx, "HELPFUL")
      if buffIndex and buffIndex >= 0 then
        srBuffScanTip:ClearLines()
        srBuffScanTip:SetPlayerBuff(buffIndex)
        local spell, r, g, b = MatchAmmoFromTooltipLines()
        if spell then
          return spell, r, g, b
        end
      end
    end
  end

  local spell, r, g, b = FindAmmoProcFromVisibleBuffButtons()
  if spell then
    return spell, r, g, b
  end

  return nil
end

local function ClearAmmoProcBorders()
  for _, borderFx in pairs(designBAmmoBorderBySpell) do
    if borderFx then
      if borderFx.glow then borderFx.glow:Hide() end
      if borderFx.ring then borderFx.ring:Hide() end
    end
  end
  for _, arrows in pairs(designBArrowsBySpell) do
    if arrows then
      for i = 1, 3 do
        if arrows[i] then arrows[i]:Hide() end
      end
    end
  end
  ammoPulse.activeSpell = nil
  ammoPulse.t = 0
end

local function UpdateAmmoProcHighlight(elapsed)
  if not IsDesignBMode() then
    ClearAmmoProcBorders()
    return
  end

  ammoPulse.scanT = ammoPulse.scanT + elapsed
  if ammoPulse.scanT >= 0.15 then
    ammoPulse.scanT = 0
    local spellName, r, g, b = FindActiveAmmoProcSpell()
    local now = GetTime and GetTime() or 0

    if not spellName and ammoPulse.eventSpell and now <= (ammoPulse.eventExpiresAt or 0) then
      spellName = ammoPulse.eventSpell
    end

    if not spellName and ammoPulse.eventSpell and now > (ammoPulse.eventExpiresAt or 0) then
      ammoPulse.eventSpell = nil
      ammoPulse.eventExpiresAt = 0
      ammoPulse.activeSpell = nil
    end

    if spellName and spellName ~= ammoPulse.activeSpell then
      ammoPulse.activeSpell = spellName
      ammoPulse.t = 0
    end

    if spellName then
      ammoPulse.r = r or ammoPulse.r or 1.0
      ammoPulse.g = g or ammoPulse.g or 0.82
      ammoPulse.b = b or ammoPulse.b or 0.0
    end
  end

  for spellName, borderFx in pairs(designBAmmoBorderBySpell) do
    if borderFx and spellName ~= ammoPulse.activeSpell then
      if borderFx.glow then borderFx.glow:Hide() end
      if borderFx.ring then borderFx.ring:Hide() end
    end
  end

  local aimedShotArrows = designBArrowsBySpell["Aimed Shot"]
  if aimedShotArrows then
    if not ammoPulse.lockAndLoadActive then
      if aimedShotArrows.glow then aimedShotArrows.glow:Hide() end
      if aimedShotArrows.core then aimedShotArrows.core:Hide() end
      if aimedShotArrows.borderGlow then aimedShotArrows.borderGlow:Hide() end
      if aimedShotArrows.borderRing then aimedShotArrows.borderRing:Hide() end
    end
  end

  ammoPulse.t = ammoPulse.t + elapsed
  local wave = (math.sin(ammoPulse.t * 8.0) + 1.0) * 0.5
  local wave2 = (math.sin(ammoPulse.t * 5.5 + 1.1) + 1.0) * 0.5

  if ammoPulse.lockAndLoadActive and aimedShotArrows then
    local pulseScale = 1.00 + (0.18 * wave)
    local bob = math.sin(ammoPulse.t * 7.5) * 1
    local core = aimedShotArrows.core
    local glow = aimedShotArrows.glow
    local borderGlow = aimedShotArrows.borderGlow
    local borderRing = aimedShotArrows.borderRing
    local baseSize = aimedShotArrows.baseSize or 22
    local glowSize = aimedShotArrows.glowSize or (baseSize + 10)
    local fontPath = aimedShotArrows.fontPath or SR_FONT_PATH
    local x = aimedShotArrows.srX or 0
    local y = (aimedShotArrows.srY or 10) + bob

    if borderGlow then
      borderGlow:SetAlpha(0.30 + (0.22 * wave2))
      borderGlow:Show()
    end
    if borderRing then
      borderRing:SetAlpha(0.65 + (0.20 * wave))
      borderRing:Show()
    end

    if glow then
      glow:SetFont(fontPath, math.floor(glowSize * pulseScale), "OUTLINE")
      glow:ClearAllPoints()
      glow:SetPoint("BOTTOM", designBButtonBySpell["Aimed Shot"], "TOP", x, y)
      glow:SetAlpha(0.65 + (0.20 * wave2))
      glow:SetTextColor(1.0, 0.88, 0.22)
      glow:Show()
    end

    if core then
      core:SetFont(fontPath, math.floor(baseSize * pulseScale), "OUTLINE")
      core:ClearAllPoints()
      core:SetPoint("BOTTOM", designBButtonBySpell["Aimed Shot"], "TOP", x, y)
      core:SetAlpha(0.95)
      core:SetTextColor(1.0, 0.94, 0.55)
      core:Show()
    end
  end

  if not ammoPulse.activeSpell then return end

  local borderFx = designBAmmoBorderBySpell[ammoPulse.activeSpell]
  if not borderFx then return end
  local ring = borderFx.ring
  local glow = borderFx.glow
  local iconSize = borderFx.iconSize or (SpellReadyDB.designBSize or DEFAULT_ROW_SIZE)
  if not ring or not glow then return end

  local ringScale = 1.82 + (0.16 * wave2)
  local glowScale = 1.48 + (0.08 * wave)
  ring:SetWidth(iconSize * ringScale)
  ring:SetHeight(iconSize * ringScale)
  glow:SetWidth(iconSize * glowScale)
  glow:SetHeight(iconSize * glowScale)

  local ringA = 0.78 + (0.22 * wave)
  local glowA = 0.36 + (0.26 * wave2)

  ring:SetVertexColor(ammoPulse.r, ammoPulse.g, ammoPulse.b, ringA)
  glow:SetVertexColor(ammoPulse.r, ammoPulse.g, ammoPulse.b, glowA)
  glow:Show()
  ring:Show()
end

local designBBar = CreateFrame("Frame", "SpellReadyDesignBBar", UIParent)
designBBar:SetWidth(1)
designBBar:SetHeight(1)
designBBar:SetMovable(true)
designBBar:EnableMouse(true)
designBBar:RegisterForDrag("LeftButton")
designBBar:Hide()

IsDesignBMode = function()
  return (SpellReadyDB and SpellReadyDB.designMode) == "B"
end

local function GetDesignBUsedAlpha()
  if SpellReadyDB and SpellReadyDB.designBUseTransparent then
    return SpellReadyDB.designBUsedAlpha or DEFAULT_B_USED_ALPHA
  end
  return 0
end

local function SetDesignBRowIconAlpha(spellName, a)
  local btn = designBButtonBySpell[spellName]
  if not btn then return end
  btn:SetAlpha(a)
end

local function StartDesignBRowFadeIn(spellName)
  local btn = designBButtonBySpell[spellName]
  if not btn then return end
  table.insert(designBRowFadeAnims, {
    btn = btn,
    startA = btn:GetAlpha() or 0,
    targetA = 1.0,
    t = 0,
    duration = 0.35,
  })
end

local function ResetDBToDefaults()
  SpellReadyDB.spells = {}
  for _, s in ipairs(DEFAULT_SPELLS) do
    SpellReadyDB.spells[s] = false
  end
  SpellReadyDB.spells["Aimed Shot"] = true
  SpellReadyDB.spells["Multi-Shot"] = true

  SpellReadyDB.size = DEFAULT_ICON_SIZE
  SpellReadyDB.posX = 0
  SpellReadyDB.posY = 0
  SpellReadyDB.duration = 0.6
  SpellReadyDB.textFadeDuration = DEFAULT_TEXT_FADE
  SpellReadyDB.iconFadeDuration = DEFAULT_ICON_FADE
  SpellReadyDB.minScale = 0.25
  SpellReadyDB.alphaStart = 1.0
  SpellReadyDB.alphaEnd = 0.0
  SpellReadyDB.displayMode = "ICON"
  SpellReadyDB.designMode = "A"
  SpellReadyDB.designBPosX = 0
  SpellReadyDB.designBPosY = -140
  SpellReadyDB.designBSize = DEFAULT_ROW_SIZE
  SpellReadyDB.designBFlyHeight = 96
  SpellReadyDB.designBUseTransparent = false
  SpellReadyDB.designBUsedAlpha = DEFAULT_B_USED_ALPHA
  SpellReadyDB.fontSize = DEFAULT_TEXT_SIZE
  SpellReadyDB.fontColor = { r = 1.0, g = 0.82, b = 0.0 }
end

local function ApplyDesignBBarPosition()
  designBBar:ClearAllPoints()
  designBBar:SetPoint(
    "CENTER",
    UIParent,
    "CENTER",
    SpellReadyDB.designBPosX or 0,
    SpellReadyDB.designBPosY or -140
  )
end

designBBar:SetScript("OnDragStart", function()
  if not IsDesignBMode() then return end
  designBBar:StartMoving()
end)

designBBar:SetScript("OnDragStop", function()
  designBBar:StopMovingOrSizing()
  if not SpellReadyDB then return end

  local cx, cy = designBBar:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return end

  local dx = cx - ux
  local dy = cy - uy
  if dx >= 0 then
    SpellReadyDB.designBPosX = math.floor(dx + 0.5)
  else
    SpellReadyDB.designBPosX = math.ceil(dx - 0.5)
  end
  if dy >= 0 then
    SpellReadyDB.designBPosY = math.floor(dy + 0.5)
  else
    SpellReadyDB.designBPosY = math.ceil(dy - 0.5)
  end
  ApplyDesignBBarPosition()
end)

local function RefreshDesignBBar()
  local i
  for i = table.getn(designBRowFadeAnims), 1, -1 do
    designBRowFadeAnims[i] = nil
  end
  for i = 1, table.getn(designBButtons) do
    if designBButtons[i] then
      designBButtons[i]:Hide()
    end
    designBButtons[i] = nil
  end
  designBButtonBySpell = {}
  designBAmmoBorderBySpell = {}
  for spellName, arrows in pairs(designBArrowsBySpell) do
    if arrows then
      if arrows.glow then arrows.glow:Hide() end
      if arrows.core then arrows.core:Hide() end
      if arrows.borderGlow then arrows.borderGlow:Hide() end
      if arrows.borderRing then arrows.borderRing:Hide() end
    end
  end
  designBArrowsBySpell = {}
  ClearAmmoProcBorders()

  if not IsDesignBMode() then
    designBBar:Hide()
    return
  end

  local lastBtn = nil
  local count = 0
  local iconSize = SpellReadyDB.designBSize or DEFAULT_ROW_SIZE
  for _, spellName in ipairs(DEFAULT_SPELLS) do
    if SpellReadyDB.spells and SpellReadyDB.spells[spellName] then
      local btn = CreateFrame("Frame", nil, designBBar)
      btn:SetWidth(iconSize)
      btn:SetHeight(iconSize)
      if lastBtn then
        btn:SetPoint("LEFT", lastBtn, "RIGHT", DESIGN_B_GAP, 0)
      else
        btn:SetPoint("LEFT", designBBar, "LEFT", 0, 0)
      end

      local tex = btn:CreateTexture(nil, "ARTWORK")
      tex:SetAllPoints(btn)
      tex:SetTexture(GetSpellIcon(spellName) or "Interface\\Icons\\INV_Misc_QuestionMark")
      btn.tex = tex

      local glow = btn:CreateTexture(nil, "OVERLAY")
      glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
      glow:SetBlendMode("ADD")
      glow:SetPoint("CENTER", btn, "CENTER", 0, 0)
      glow:SetWidth(iconSize * 1.5)
      glow:SetHeight(iconSize * 1.5)
      glow:SetVertexColor(1.0, 0.84, 0.2, 0.0)
      glow:Hide()

      local ring = btn:CreateTexture(nil, "OVERLAY")
      ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      ring:SetBlendMode("ADD")
      ring:SetPoint("CENTER", btn, "CENTER", 0, 0)
      ring:SetWidth(iconSize * 1.85)
      ring:SetHeight(iconSize * 1.85)
      ring:SetVertexColor(1.0, 0.84, 0.2, 0.0)
      ring:Hide()

      btn.spellName = spellName
      if IsSpellOnCooldown(spellName) then
        btn:SetAlpha(GetDesignBUsedAlpha())
      else
        btn:SetAlpha(1.0)
      end

      lastBtn = btn
      count = count + 1
      designBButtons[count] = btn
      designBButtonBySpell[spellName] = btn
      designBAmmoBorderBySpell[spellName] = {
        glow = glow,
        ring = ring,
        iconSize = iconSize,
      }

      if spellName == "Aimed Shot" then
        local fontPath = STANDARD_TEXT_FONT or SR_FONT_PATH
        local core = btn:CreateFontString(nil, "OVERLAY")
        local glowArrow = btn:CreateFontString(nil, "OVERLAY")
        local borderGlow = btn:CreateTexture(nil, "OVERLAY")
        local borderRing = btn:CreateTexture(nil, "OVERLAY")
        local baseSize = math.max(30, math.floor(iconSize * 0.62))
        local glowSize = baseSize + 16
        local xOffset = 0
        local yOffset = 12

        borderGlow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        borderGlow:SetBlendMode("ADD")
        borderGlow:SetPoint("CENTER", btn, "CENTER", 0, 0)
        borderGlow:SetWidth(iconSize * 1.45)
        borderGlow:SetHeight(iconSize * 1.45)
        borderGlow:SetVertexColor(1.0, 0.18, 0.18, 0.0)
        borderGlow:Hide()

        borderRing:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        borderRing:SetBlendMode("ADD")
        borderRing:SetPoint("CENTER", btn, "CENTER", 0, 0)
        borderRing:SetWidth(iconSize * 1.82)
        borderRing:SetHeight(iconSize * 1.82)
        borderRing:SetVertexColor(1.0, 0.18, 0.18, 0.0)
        borderRing:Hide()

        glowArrow:SetFont(fontPath, glowSize, "OUTLINE")
        glowArrow:SetText("^")
        glowArrow:SetJustifyH("CENTER")
        glowArrow:SetTextColor(1.0, 0.88, 0.22)
        glowArrow:SetShadowColor(1.0, 0.88, 0.22)
        glowArrow:SetShadowOffset(0, 0)
        glowArrow:SetPoint("BOTTOM", btn, "TOP", xOffset, yOffset)
        glowArrow:Hide()

        core:SetFont(fontPath, baseSize, "OUTLINE")
        core:SetText("^")
        core:SetJustifyH("CENTER")
        core:SetTextColor(1.0, 0.94, 0.55)
        core:SetShadowColor(1.0, 0.84, 0.18)
        core:SetShadowOffset(0, 0)
        core:SetPoint("BOTTOM", btn, "TOP", xOffset, yOffset)
        core:Hide()

        designBArrowsBySpell[spellName] = {
          core = core,
          glow = glowArrow,
          borderGlow = borderGlow,
          borderRing = borderRing,
          srX = xOffset,
          srY = yOffset,
          baseSize = baseSize,
          glowSize = glowSize,
          fontPath = fontPath,
        }
      end
    end
  end

  if count == 0 then
    designBBar:Hide()
    return
  end

  local totalW = (count * iconSize) + ((count - 1) * DESIGN_B_GAP)
  designBBar:SetWidth(totalW)
  designBBar:SetHeight(iconSize)
  ApplyDesignBBarPosition()
  designBBar:Show()
end

local function StartDesignBFly(spellName)
  local src = designBButtonBySpell[spellName]
  if not src then return false end

  -- entering "used" state immediately (test path and real trigger path)
  SetDesignBRowIconAlpha(spellName, GetDesignBUsedAlpha())

  local cx, cy = src:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return false end

  local f = CreateFrame("Frame", nil, UIParent)
  local iconSize = SpellReadyDB.designBSize or DEFAULT_ROW_SIZE
  f:SetWidth(iconSize)
  f:SetHeight(iconSize)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetPoint("CENTER", UIParent, "CENTER", cx - ux, cy - uy)

  local t = f:CreateTexture(nil, "OVERLAY")
  t:SetAllPoints(f)
  t:SetTexture(src.tex and src.tex:GetTexture() or "Interface\\Icons\\INV_Misc_QuestionMark")
  t:SetAlpha(1.0)

  table.insert(designBFlyAnims, {
    frame = f,
    tex = t,
    ox = cx - ux,
    oy = cy - uy,
    dy = SpellReadyDB.designBFlyHeight or 96,
    duration = SpellReadyDB.iconFadeDuration or 0.6,
    t = 0,
  })

  if testSequenceActive then
    anim.active = true
    anim.t = 0
    pulse:Hide()
  end
  return true
end

local function RoundNearest(v)
  if v >= 0 then
    return math.floor(v + 0.5)
  end
  return math.ceil(v - 0.5)
end

local function ApplyPulsePosition()
  pulse:ClearAllPoints()
  pulse:SetPoint("CENTER", UIParent, "CENTER", SpellReadyDB.posX or 0, SpellReadyDB.posY or 0)
end

local function UpdatePulseTextStyle()
  local c = SpellReadyDB.fontColor or {}
  local r = c.r or 1.0
  local g = c.g or 0.82
  local b = c.b or 0.0
  local fs = SpellReadyDB.fontSize or DEFAULT_TEXT_SIZE
  local fontPath = STANDARD_TEXT_FONT or SR_FONT_PATH
  pulse.text:SetFont(fontPath, fs, "OUTLINE")
  pulse.text:SetTextHeight(fs)
  pulse.text:SetWidth(math.max(320, fs * 8))
  pulse.text:SetTextColor(r, g, b)
end

pulse:SetScript("OnDragStart", function()
  pulse:StartMoving()
end)

pulse:SetScript("OnDragStop", function()
  pulse:StopMovingOrSizing()
  if not SpellReadyDB then return end

  local cx, cy = pulse:GetCenter()
  local ux, uy = UIParent:GetCenter()
  if not cx or not cy or not ux or not uy then return end

  SpellReadyDB.posX = RoundNearest(cx - ux)
  SpellReadyDB.posY = RoundNearest(cy - uy)
  ApplyPulsePosition()
end)

local pulseDragMode = false
local SetPulseDragMode

local function StartPulseForSpell(spellName)
  if pulseDragMode then
    SetPulseDragMode(false)
  end

  if IsDesignBMode() then
    return StartDesignBFly(spellName)
  end

  local mode = SpellReadyDB.displayMode or "ICON"
  local icon = GetSpellIcon(spellName)
  if (mode == "ICON" or mode == "BOTH") and not icon then
    return false
  end

  if icon then
    pulse.tex:SetTexture(icon)
  end

  UpdatePulseTextStyle()
  pulse.text:SetText(spellName or "")
  pulse.text:ClearAllPoints()
  anim.showIcon = false
  anim.showText = false
  if mode == "TEXT" then
    pulse.tex:Hide()
    pulse.text:SetPoint("CENTER", pulse, "CENTER", 0, 0)
    pulse.text:Show()
    pulse.text:SetAlpha(SpellReadyDB.alphaStart)
    anim.showText = true
  elseif mode == "BOTH" then
    pulse.tex:Show()
    pulse.tex:SetAlpha(SpellReadyDB.alphaStart)
    pulse.text:SetPoint("BOTTOM", pulse, "TOP", 0, 6)
    pulse.text:Show()
    pulse.text:SetAlpha(SpellReadyDB.alphaStart)
    anim.showIcon = true
    anim.showText = true
  else
    pulse.tex:Show()
    pulse.tex:SetAlpha(SpellReadyDB.alphaStart)
    pulse.text:Hide()
    anim.showIcon = true
  end

  anim.active = true
  anim.t = 0
  local iconDur = SpellReadyDB.iconFadeDuration or 0.6
  local textDur = SpellReadyDB.textFadeDuration or 1.0
  if mode == "TEXT" then
    anim.duration = textDur
  elseif mode == "BOTH" then
    if iconDur > textDur then
      anim.duration = iconDur
    else
      anim.duration = textDur
    end
  else
    anim.duration = iconDur
  end
  if anim.duration <= 0 then
    anim.duration = 0.01
  end

  local startSize = SpellReadyDB.size * SpellReadyDB.minScale
  pulse:SetWidth(startSize)
  pulse:SetHeight(startSize)
  pulse:SetAlpha(1.0)
  pulse:Show()
  return true
end

local function StartNextTestPulse()
  while testSequenceActive and testQueueIndex <= table.getn(testQueue) do
    local spellName = testQueue[testQueueIndex]
    testQueueIndex = testQueueIndex + 1
    if StartPulseForSpell(spellName) then
      return
    end
  end
  testSequenceActive = false
end

local function StopPulse(noQueueAdvance)
  anim.active = false
  pulse:Hide()
  if noQueueAdvance then return end
  if testSequenceActive then
    StartNextTestPulse()
  end
end

SetPulseDragMode = function(enabled)
  pulseDragMode = enabled and true or false
  if not pulseDragMode then
    if not anim.active then
      pulse:Hide()
    end
    return
  end

  if anim.active then
    StopPulse(true)
  end
  testSequenceActive = false

  local mode = SpellReadyDB.displayMode or "ICON"
  local chosen = nil
  for _, spellName in ipairs(DEFAULT_SPELLS) do
    if SpellReadyDB.spells and SpellReadyDB.spells[spellName] then
      chosen = spellName
      break
    end
  end

  local icon = chosen and GetSpellIcon(chosen) or nil
  pulse.tex:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
  UpdatePulseTextStyle()
  pulse.text:SetText(chosen or "Drag Me")
  pulse.text:ClearAllPoints()

  if mode == "TEXT" then
    pulse.tex:Hide()
    pulse.text:SetPoint("CENTER", pulse, "CENTER", 0, 0)
    pulse.text:SetAlpha(1.0)
    pulse.text:Show()
  elseif mode == "BOTH" then
    pulse.tex:Show()
    pulse.tex:SetAlpha(1.0)
    pulse.text:SetPoint("BOTTOM", pulse, "TOP", 0, 6)
    pulse.text:SetAlpha(1.0)
    pulse.text:Show()
  else
    pulse.tex:Show()
    pulse.tex:SetAlpha(1.0)
    pulse.text:Hide()
  end

  pulse:SetWidth(SpellReadyDB.size or 80)
  pulse:SetHeight(SpellReadyDB.size or 80)
  pulse:SetAlpha(1.0)
  pulse:Show()
end

------------------------------------------------------------
-- Cooldown Watcher (multiple spells)
------------------------------------------------------------
local lastOnCD = {} -- spellName -> bool

local function ScanSpellsAndTrigger()
  if not SpellReadyDB.spells then return end
  if testSequenceActive then return end

  for spellName, enabled in pairs(SpellReadyDB.spells) do
    if enabled then
      local onCD = IsSpellOnCooldown(spellName)
      local wasOnCD = lastOnCD[spellName]
      if IsDesignBMode() then
        if wasOnCD ~= onCD then
          if onCD then
            StartPulseForSpell(spellName)
            SetDesignBRowIconAlpha(spellName, GetDesignBUsedAlpha())
          else
            StartDesignBRowFadeIn(spellName)
          end
        end
      else
        if wasOnCD == true and onCD == false then
          StartPulseForSpell(spellName)
        end
      end

      lastOnCD[spellName] = onCD
    end
  end
end

------------------------------------------------------------
-- Menu Window with Checkboxes
------------------------------------------------------------
local MENU_PADDING_TOP = 72
local MENU_PADDING_BOTTOM = 270
local ROW_H = 22
local MENU_MIN_H = 260
local SPELL_LIST_COLUMNS = 3
local SPELL_LIST_COL_W = 130
local SPELL_LIST_COL_GAP = 15

local menu = CreateFrame("Frame", "SpellReadyMenu", UIParent)
menu:SetWidth(490) -- wider to prevent control overlap
-- height will be set later after we know how many rows we need
menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
menu:SetToplevel(true)
menu:SetClampedToScreen(true)
menu:SetFrameStrata("DIALOG")
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
sub:SetText("Select spells to track (drag this window to move)")

local closeBtn = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -6)

local BuildMenu
local RefreshControlVisibility

local testBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
testBtn:SetWidth(80)
testBtn:SetHeight(22)
testBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 16)
testBtn:SetText("Test")
testBtn:SetScript("OnClick", function()
  if anim.active then
    StopPulse(true)
  end

  testQueue = {}
  testQueueIndex = 1
  for _, spellName in ipairs(DEFAULT_SPELLS) do
    if SpellReadyDB.spells[spellName] then
      table.insert(testQueue, spellName)
    end
  end

  if table.getn(testQueue) == 0 then
    SR_Print("Enable at least one spell in the menu first.")
    return
  end

  testSequenceActive = true
  StartNextTestPulse()
end)

local resetBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
resetBtn:SetWidth(80)
resetBtn:SetHeight(22)
resetBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 98, 16)
resetBtn:SetText("Reset")

local movePulseBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
movePulseBtn:SetWidth(90)
movePulseBtn:SetHeight(22)
movePulseBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 182, 16)
movePulseBtn:SetText("Edit Position")
movePulseBtn:SetScript("OnClick", function()
  if pulseDragMode then
    SetPulseDragMode(false)
    movePulseBtn:SetText("Edit Position")
  else
    SetPulseDragMode(true)
    movePulseBtn:SetText("Lock Position")
  end
end)

local centerRowBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
centerRowBtn:SetWidth(90)
centerRowBtn:SetHeight(22)
centerRowBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 276, 16)
centerRowBtn:SetText("Center Row")
centerRowBtn:SetScript("OnClick", function()
  SpellReadyDB.designBPosX = 0
  ApplyDesignBBarPosition()
end)

local centerPulseBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
centerPulseBtn:SetWidth(90)
centerPulseBtn:SetHeight(22)
centerPulseBtn:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 276, 16)
centerPulseBtn:SetText("Center")
centerPulseBtn:SetScript("OnClick", function()
  SpellReadyDB.posX = 0
  SpellReadyDB.posY = 0
  ApplyPulsePosition()
end)

-- Size slider (icon size)
local sizeLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
sizeLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 46)
sizeLabel:SetText("Size: " .. tostring(SpellReadyDB.size or 80))

local sizeSlider = CreateFrame("Slider", "SpellReadySizeSlider", menu, "OptionsSliderTemplate")
sizeSlider:SetWidth(140)
sizeSlider:SetHeight(16)
sizeSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 60)
sizeSlider:SetMinMaxValues(40, 240)
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

local rowSizeLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
rowSizeLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 106)
rowSizeLabel:SetText("Size: " .. tostring(SpellReadyDB.designBSize or DEFAULT_ROW_SIZE))

local rowSizeSlider = CreateFrame("Slider", "SpellReadyRowSizeSlider", menu, "OptionsSliderTemplate")
rowSizeSlider:SetWidth(140)
rowSizeSlider:SetHeight(16)
rowSizeSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 120)
rowSizeSlider:SetMinMaxValues(16, 64)
rowSizeSlider:SetValueStep(2)
if rowSizeSlider.SetObeyStepOnDrag then
  rowSizeSlider:SetObeyStepOnDrag(true)
end

local rlow = getglobal(rowSizeSlider:GetName() .. "Low")
local rhigh = getglobal(rowSizeSlider:GetName() .. "High")
local rtext = getglobal(rowSizeSlider:GetName() .. "Text")
if rlow then rlow:Hide() end
if rhigh then rhigh:Hide() end
if rtext then rtext:Hide() end

rowSizeSlider:SetScript("OnValueChanged", function()
  local v = tonumber(rowSizeSlider:GetValue()) or DEFAULT_ROW_SIZE
  v = math.floor((v / 2) + 0.5) * 2
  SpellReadyDB.designBSize = v
  rowSizeLabel:SetText("Size: " .. v)
  RefreshDesignBBar()
end)

local usedTransparentCB = CreateFrame("CheckButton", "SpellReadyBTransparent", menu, "UICheckButtonTemplate")
usedTransparentCB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 166)
local usedTransparentText = getglobal("SpellReadyBTransparentText")
if usedTransparentText then usedTransparentText:SetText("Transparency while cooldown") end
usedTransparentCB:SetScript("OnClick", function()
  SpellReadyDB.designBUseTransparent = usedTransparentCB:GetChecked() and true or false
  RefreshDesignBBar()
  RefreshControlVisibility()
end)

local usedAlphaLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
usedAlphaLabel:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 36, 148)
usedAlphaLabel:SetText("Used Alpha: " .. string.format("%.2f", SpellReadyDB.designBUsedAlpha or DEFAULT_B_USED_ALPHA))

local usedAlphaSlider = CreateFrame("Slider", "SpellReadyBUsedAlphaSlider", menu, "OptionsSliderTemplate")
usedAlphaSlider:SetWidth(150)
usedAlphaSlider:SetHeight(16)
usedAlphaSlider:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 132)
usedAlphaSlider:SetMinMaxValues(0.05, 1.00)
usedAlphaSlider:SetValueStep(0.05)
if usedAlphaSlider.SetObeyStepOnDrag then
  usedAlphaSlider:SetObeyStepOnDrag(true)
end

local ualow = getglobal(usedAlphaSlider:GetName() .. "Low")
local uahigh = getglobal(usedAlphaSlider:GetName() .. "High")
local uatext = getglobal(usedAlphaSlider:GetName() .. "Text")
if ualow then ualow:Hide() end
if uahigh then uahigh:Hide() end
if uatext then uatext:Hide() end

usedAlphaSlider:SetScript("OnValueChanged", function()
  local v = tonumber(usedAlphaSlider:GetValue()) or DEFAULT_B_USED_ALPHA
  v = math.floor((v / 0.05) + 0.5) * 0.05
  SpellReadyDB.designBUsedAlpha = v
  usedAlphaLabel:SetText("Used Alpha: " .. string.format("%.2f", v))
  if SpellReadyDB.designBUseTransparent then
    RefreshDesignBBar()
  end
end)

local textFadeLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
textFadeLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 136)
textFadeLabel:SetText("Text Fade: " .. string.format("%.2fs", SpellReadyDB.textFadeDuration or 1.0))

local textFadeSlider = CreateFrame("Slider", "SpellReadyTextFadeSlider", menu, "OptionsSliderTemplate")
textFadeSlider:SetWidth(140)
textFadeSlider:SetHeight(16)
textFadeSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 150)
textFadeSlider:SetMinMaxValues(0.20, 2.50)
textFadeSlider:SetValueStep(0.05)
if textFadeSlider.SetObeyStepOnDrag then
  textFadeSlider:SetObeyStepOnDrag(true)
end

local tlow = getglobal(textFadeSlider:GetName() .. "Low")
local thigh = getglobal(textFadeSlider:GetName() .. "High")
local ttext = getglobal(textFadeSlider:GetName() .. "Text")
if tlow then tlow:Hide() end
if thigh then thigh:Hide() end
if ttext then ttext:Hide() end

textFadeSlider:SetScript("OnValueChanged", function()
  local v = tonumber(textFadeSlider:GetValue()) or 1.0
  v = math.floor((v / 0.05) + 0.5) * 0.05
  SpellReadyDB.textFadeDuration = v
  textFadeLabel:SetText("Text Fade: " .. string.format("%.2fs", v))
end)

local iconFadeLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
iconFadeLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 166)
iconFadeLabel:SetText("Icon Fade: " .. string.format("%.2fs", SpellReadyDB.iconFadeDuration or 0.6))

local iconFadeSlider = CreateFrame("Slider", "SpellReadyIconFadeSlider", menu, "OptionsSliderTemplate")
iconFadeSlider:SetWidth(140)
iconFadeSlider:SetHeight(16)
iconFadeSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 180)
iconFadeSlider:SetMinMaxValues(0.20, 2.50)
iconFadeSlider:SetValueStep(0.05)
if iconFadeSlider.SetObeyStepOnDrag then
  iconFadeSlider:SetObeyStepOnDrag(true)
end

local ilow = getglobal(iconFadeSlider:GetName() .. "Low")
local ihigh = getglobal(iconFadeSlider:GetName() .. "High")
local itext = getglobal(iconFadeSlider:GetName() .. "Text")
if ilow then ilow:Hide() end
if ihigh then ihigh:Hide() end
if itext then itext:Hide() end

iconFadeSlider:SetScript("OnValueChanged", function()
  local v = tonumber(iconFadeSlider:GetValue()) or 0.6
  v = math.floor((v / 0.05) + 0.5) * 0.05
  SpellReadyDB.iconFadeDuration = v
  iconFadeLabel:SetText("Icon Fade: " .. string.format("%.2fs", v))
end)

local modeIconCB = CreateFrame("CheckButton", "SpellReadyModeIcon", menu, "UICheckButtonTemplate")
modeIconCB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 70)
local modeIconText = getglobal("SpellReadyModeIconText")
if modeIconText then modeIconText:SetText("Icon") end

local modeTextCB = CreateFrame("CheckButton", "SpellReadyModeText", menu, "UICheckButtonTemplate")
modeTextCB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 90)
local modeTextText = getglobal("SpellReadyModeTextText")
if modeTextText then modeTextText:SetText("Text") end

local modeBothCB = CreateFrame("CheckButton", "SpellReadyModeBoth", menu, "UICheckButtonTemplate")
modeBothCB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 110)
local modeBothText = getglobal("SpellReadyModeBothText")
if modeBothText then modeBothText:SetText("Both") end

local designACB = CreateFrame("CheckButton", "SpellReadyDesignA", menu, "UICheckButtonTemplate")
designACB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 208)
local designAText = getglobal("SpellReadyDesignAText")
if designAText then designAText:SetText("Style A") end

local designBCB = CreateFrame("CheckButton", "SpellReadyDesignB", menu, "UICheckButtonTemplate")
designBCB:SetPoint("BOTTOMLEFT", menu, "BOTTOMLEFT", 14, 188)
local designBText = getglobal("SpellReadyDesignBText")
if designBText then designBText:SetText("Style B") end

local function SyncDisplayModeChecks()
  local mode = SpellReadyDB.displayMode or "ICON"
  modeIconCB:SetChecked(mode == "ICON")
  modeTextCB:SetChecked(mode == "TEXT")
  modeBothCB:SetChecked(mode == "BOTH")
end

local function SetDisplayMode(mode)
  if (SpellReadyDB.designMode or "A") == "B" then
    mode = "ICON"
  end
  SpellReadyDB.displayMode = mode
  SyncDisplayModeChecks()
  RefreshControlVisibility()
end

local function SyncDesignModeChecks()
  local mode = SpellReadyDB.designMode or "A"
  designACB:SetChecked(mode == "A")
  designBCB:SetChecked(mode == "B")
end

local function SetDesignMode(mode)
  SpellReadyDB.designMode = mode
  if mode == "B" then
    SpellReadyDB.displayMode = "ICON"
  end
  SyncDesignModeChecks()
  SyncDisplayModeChecks()
  RefreshDesignBBar()
  if mode ~= "A" and pulseDragMode then
    SetPulseDragMode(false)
    movePulseBtn:SetText("Edit Position")
  end
  if mode == "B" then
    pulse:Hide()
  end
  if mode == "A" then
    movePulseBtn:Show()
    centerPulseBtn:Show()
    centerRowBtn:Hide()
  else
    movePulseBtn:Hide()
    centerPulseBtn:Hide()
    centerRowBtn:Show()
  end
  RefreshControlVisibility()
end

RefreshControlVisibility = function()
  -- assigned after all controls are created
end

modeIconCB:SetScript("OnClick", function() SetDisplayMode("ICON") end)
modeTextCB:SetScript("OnClick", function() SetDisplayMode("TEXT") end)
modeBothCB:SetScript("OnClick", function() SetDisplayMode("BOTH") end)
designACB:SetScript("OnClick", function() SetDesignMode("A") end)
designBCB:SetScript("OnClick", function() SetDesignMode("B") end)

local fontLabel = menu:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
fontLabel:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 76)
fontLabel:SetText("Font: " .. tostring(SpellReadyDB.fontSize or DEFAULT_TEXT_SIZE))

local fontSlider = CreateFrame("Slider", "SpellReadyFontSlider", menu, "OptionsSliderTemplate")
fontSlider:SetWidth(140)
fontSlider:SetHeight(16)
fontSlider:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 90)
fontSlider:SetMinMaxValues(10, 20)
fontSlider:SetValueStep(1)
if fontSlider.SetObeyStepOnDrag then
  fontSlider:SetObeyStepOnDrag(true)
end

local flow = getglobal(fontSlider:GetName() .. "Low")
local fhigh = getglobal(fontSlider:GetName() .. "High")
local ftext = getglobal(fontSlider:GetName() .. "Text")
if flow then flow:Hide() end
if fhigh then fhigh:Hide() end
if ftext then ftext:Hide() end

fontSlider:SetScript("OnValueChanged", function()
  local v = tonumber(fontSlider:GetValue()) or DEFAULT_TEXT_SIZE
  v = math.floor(v + 0.5)
  SpellReadyDB.fontSize = v
  fontLabel:SetText("Font: " .. v)
  UpdatePulseTextStyle()
end)

local function SetFontColor(r, g, b)
  SpellReadyDB.fontColor = SpellReadyDB.fontColor or {}
  SpellReadyDB.fontColor.r = r
  SpellReadyDB.fontColor.g = g
  SpellReadyDB.fontColor.b = b
  fontLabel:SetTextColor(r, g, b)
  UpdatePulseTextStyle()
end

local colorBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
colorBtn:SetWidth(80)
colorBtn:SetHeight(20)
colorBtn:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -20, 214)
colorBtn:SetText("Text Color")
colorBtn:SetScript("OnClick", function()
  local c = SpellReadyDB.fontColor or { r = 1.0, g = 0.82, b = 0.0 }
  local prev = { c.r, c.g, c.b }

  ColorPickerFrame.hasOpacity = nil
  ColorPickerFrame.opacity = nil
  ColorPickerFrame.previousValues = prev
  ColorPickerFrame:SetColorRGB(c.r, c.g, c.b)

  ColorPickerFrame.func = function()
    local r, g, b = ColorPickerFrame:GetColorRGB()
    SetFontColor(r, g, b)
  end
  ColorPickerFrame.cancelFunc = function(values)
    if values then
      SetFontColor(values[1], values[2], values[3])
    else
      SetFontColor(prev[1], prev[2], prev[3])
    end
  end
  ColorPickerFrame:Show()
end)

RefreshControlVisibility = function()
  local displayMode = SpellReadyDB.displayMode or "ICON"
  local designMode = SpellReadyDB.designMode or "A"
  local showSizeControl = (designMode == "A") and (displayMode == "ICON" or displayMode == "BOTH")
  local showIconFadeControl = (designMode == "B") or (displayMode == "ICON" or displayMode == "BOTH")
  local showTextControls = (designMode == "A") and (displayMode == "TEXT" or displayMode == "BOTH")

  if showSizeControl then
    sizeLabel:Show()
    sizeSlider:Show()
  else
    sizeLabel:Hide()
    sizeSlider:Hide()
  end

  if showIconFadeControl then
    iconFadeLabel:Show()
    iconFadeSlider:Show()
  else
    iconFadeLabel:Hide()
    iconFadeSlider:Hide()
  end

  if showTextControls then
    fontLabel:Show()
    fontSlider:Show()
    textFadeLabel:Show()
    textFadeSlider:Show()
    colorBtn:Show()
  else
    fontLabel:Hide()
    fontSlider:Hide()
    textFadeLabel:Hide()
    textFadeSlider:Hide()
    colorBtn:Hide()
  end

  if designMode == "B" then
    modeIconCB:Hide()
    modeTextCB:Hide()
    modeBothCB:Hide()
    rowSizeLabel:Show()
    rowSizeSlider:Show()
    usedTransparentCB:Show()
    if SpellReadyDB.designBUseTransparent then
      usedAlphaLabel:Show()
      usedAlphaSlider:Show()
    else
      usedAlphaLabel:Hide()
      usedAlphaSlider:Hide()
    end
  else
    modeIconCB:Show()
    modeTextCB:Show()
    modeBothCB:Show()
    rowSizeLabel:Hide()
    rowSizeSlider:Hide()
    usedTransparentCB:Hide()
    usedAlphaLabel:Hide()
    usedAlphaSlider:Hide()
  end

  if designMode == "B" then
    centerRowBtn:Show()
    centerPulseBtn:Hide()
  else
    centerRowBtn:Hide()
    centerPulseBtn:Show()
  end
end

local function PerformResetSettings()
  if anim.active then
    StopPulse(true)
  end
  testSequenceActive = false
  SetPulseDragMode(false)
  movePulseBtn:SetText("Edit Position")

  ResetDBToDefaults()
  ApplyPulsePosition()
  ApplyDesignBBarPosition()
  UpdatePulseTextStyle()
  BuildMenu()

  -- refresh cooldown snapshots for enabled spells
  for spellName, enabled in pairs(SpellReadyDB.spells) do
    if enabled then
      lastOnCD[spellName] = IsSpellOnCooldown(spellName)
    else
      lastOnCD[spellName] = nil
    end
  end

  SR_Print("Settings reset to defaults.")
end

if StaticPopupDialogs and not StaticPopupDialogs["SPELLREADY_RESET_CONFIRM"] then
  StaticPopupDialogs["SPELLREADY_RESET_CONFIRM"] = {
    text = "Reset SpellReady settings to defaults?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function()
      PerformResetSettings()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
  }
end

resetBtn:SetScript("OnClick", function()
  if StaticPopup_Show then
    StaticPopup_Show("SPELLREADY_RESET_CONFIRM")
  else
    PerformResetSettings()
  end
end)

local UI = {
  sizeSlider = sizeSlider,
  sizeLabel = sizeLabel,
  rowSizeSlider = rowSizeSlider,
  rowSizeLabel = rowSizeLabel,
  usedTransparentCB = usedTransparentCB,
  usedAlphaSlider = usedAlphaSlider,
  usedAlphaLabel = usedAlphaLabel,
  textFadeSlider = textFadeSlider,
  textFadeLabel = textFadeLabel,
  iconFadeSlider = iconFadeSlider,
  iconFadeLabel = iconFadeLabel,
  fontSlider = fontSlider,
  fontLabel = fontLabel,
  movePulseBtn = movePulseBtn,
  centerPulseBtn = centerPulseBtn,
  centerRowBtn = centerRowBtn,
}

local checkboxes = {}

local function CreateCheckbox(parent, spellName, x, y)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)

  local label = cb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetPoint("LEFT", cb, "RIGHT", 4, 1)
  label:SetText(spellName)
  cb.label = label

  cb:SetChecked(SpellReadyDB.spells[spellName] == true)

  cb:SetScript("OnClick", function()
    SpellReadyDB.spells[spellName] = cb:GetChecked() and true or false
    lastOnCD[spellName] = IsSpellOnCooldown(spellName)
    RefreshDesignBBar()
  end)

  return cb
end

BuildMenu = function()
  if (SpellReadyDB.designMode or "A") == "B" then
    SpellReadyDB.displayMode = "ICON"
  end

  -- clear old
  for i = 1, table.getn(checkboxes) do
    if checkboxes[i] then
      checkboxes[i]:Hide()
    end
    checkboxes[i] = nil
  end

  local startY = -60
  local startX = 18
  local rowH = ROW_H
  local spellCount = table.getn(DEFAULT_SPELLS)
  local rowsPerColumn = math.floor((spellCount + SPELL_LIST_COLUMNS - 1) / SPELL_LIST_COLUMNS)

  for idx, spellName in ipairs(DEFAULT_SPELLS) do
    if SpellReadyDB.spells[spellName] == nil then
      SpellReadyDB.spells[spellName] = false
    end

    local zero = idx - 1
    local col = math.floor(zero / rowsPerColumn)
    local row = math.mod(zero, rowsPerColumn)
    local x = startX + (col * (SPELL_LIST_COL_W + SPELL_LIST_COL_GAP))
    local y = startY - (row * rowH)

    local cb = CreateCheckbox(menu, spellName, x, y)
    table.insert(checkboxes, cb)
  end

  -- Resize menu so all spells fit (no overflow)
  local neededRows = rowsPerColumn
  local neededH = MENU_PADDING_TOP + (neededRows * rowH) + MENU_PADDING_BOTTOM
  if neededH < MENU_MIN_H then neededH = MENU_MIN_H end
  menu:SetHeight(neededH)

  -- Keep slider in sync with saved value
  if UI.sizeSlider then
    UI.sizeSlider:SetValue(SpellReadyDB.size or 80)
    UI.sizeLabel:SetText("Size: " .. tostring(SpellReadyDB.size or 80))
  end
  if UI.rowSizeSlider then
    UI.rowSizeSlider:SetValue(SpellReadyDB.designBSize or DEFAULT_ROW_SIZE)
    UI.rowSizeLabel:SetText("Size: " .. tostring(SpellReadyDB.designBSize or DEFAULT_ROW_SIZE))
  end
  if UI.usedTransparentCB then
    UI.usedTransparentCB:SetChecked(SpellReadyDB.designBUseTransparent == true)
  end
  if UI.usedAlphaSlider then
    UI.usedAlphaSlider:SetValue(SpellReadyDB.designBUsedAlpha or DEFAULT_B_USED_ALPHA)
    UI.usedAlphaLabel:SetText("Used Alpha: " .. string.format("%.2f", SpellReadyDB.designBUsedAlpha or DEFAULT_B_USED_ALPHA))
  end
  if UI.textFadeSlider then
    UI.textFadeSlider:SetValue(SpellReadyDB.textFadeDuration or 1.0)
    UI.textFadeLabel:SetText("Text Fade: " .. string.format("%.2fs", SpellReadyDB.textFadeDuration or 1.0))
  end
  if UI.iconFadeSlider then
    UI.iconFadeSlider:SetValue(SpellReadyDB.iconFadeDuration or 0.6)
    UI.iconFadeLabel:SetText("Icon Fade: " .. string.format("%.2fs", SpellReadyDB.iconFadeDuration or 0.6))
  end
  if UI.fontSlider then
    UI.fontSlider:SetValue(SpellReadyDB.fontSize or DEFAULT_TEXT_SIZE)
    UI.fontLabel:SetText("Font: " .. tostring(SpellReadyDB.fontSize or DEFAULT_TEXT_SIZE))
  end
  if SpellReadyDB.fontColor then
    UI.fontLabel:SetTextColor(
      SpellReadyDB.fontColor.r or 1.0,
      SpellReadyDB.fontColor.g or 0.82,
      SpellReadyDB.fontColor.b or 0.0
    )
  end
  SyncDisplayModeChecks()
  SyncDesignModeChecks()
  RefreshControlVisibility()
  RefreshDesignBBar()
  if (SpellReadyDB.designMode or "A") == "A" then
    UI.movePulseBtn:Show()
    UI.centerPulseBtn:Show()
    UI.centerRowBtn:Hide()
  else
    UI.movePulseBtn:Hide()
    UI.centerPulseBtn:Hide()
    UI.centerRowBtn:Show()
  end
  if pulseDragMode then
    UI.movePulseBtn:SetText("Lock Position")
  else
    UI.movePulseBtn:SetText("Edit Position")
  end
end

------------------------------------------------------------
-- Main driver frame
------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_AURAS_CHANGED")
driver:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
driver:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
driver:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS")
driver:RegisterEvent("CHAT_MSG_SPELL_AURA_GONE_SELF")
driver:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
driver:RegisterEvent("CHAT_MSG_SPELL_CAST_SELF")
driver:SetScript("OnEvent", function()
  if event == "PLAYER_AURAS_CHANGED" then
    ammoPulse.scanT = 0
    return
  end

  if event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_SPELL_SELF_BUFF" or event == "CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS" or event == "CHAT_MSG_SPELL_AURA_GONE_SELF" or event == "CHAT_MSG_SPELL_CAST_SELF" then
    UpdateAmmoEventState(arg1)
    return
  end

  if event == "PLAYER_LOGIN" then
    EnsureDefaults()
    ApplyPulsePosition()
    ApplyDesignBBarPosition()
    UpdatePulseTextStyle()
    BuildMenu()

    -- init cooldown states
    for spellName, enabled in pairs(SpellReadyDB.spells) do
      if enabled then
        lastOnCD[spellName] = IsSpellOnCooldown(spellName)
      end
    end

    SR_PrintLoaded()
  end
end)

driver:SetScript("OnUpdate", function()
  ScanSpellsAndTrigger()
  UpdateAmmoProcHighlight(arg1)

  local i
  for i = table.getn(designBFlyAnims), 1, -1 do
    local a = designBFlyAnims[i]
    if a and a.frame then
      a.t = a.t + arg1
      local p = a.t / a.duration
      if p >= 1 then
        a.frame:Hide()
        table.remove(designBFlyAnims, i)
      else
        a.frame:ClearAllPoints()
        a.frame:SetPoint("CENTER", UIParent, "CENTER", a.ox, a.oy + (a.dy * p))
        if a.tex then
          a.tex:SetAlpha(1.0 - p)
        end
      end
    else
      table.remove(designBFlyAnims, i)
    end
  end

  for i = table.getn(designBRowFadeAnims), 1, -1 do
    local f = designBRowFadeAnims[i]
    if f and f.btn then
      f.t = f.t + arg1
      local p = f.t / f.duration
      if p >= 1 then
        f.btn:SetAlpha(f.targetA)
        table.remove(designBRowFadeAnims, i)
      else
        local a = f.startA + (f.targetA - f.startA) * p
        f.btn:SetAlpha(a)
      end
    else
      table.remove(designBRowFadeAnims, i)
    end
  end

  if not anim.active then return end
  anim.t = anim.t + arg1

  local duration = anim.duration or SpellReadyDB.duration or 0.6
  if duration <= 0 then duration = 0.01 end
  local p = anim.t / duration
  if p >= 1 then
    StopPulse()
    return
  end

  local scale = SpellReadyDB.minScale + (1.0 - SpellReadyDB.minScale) * p
  local sz = SpellReadyDB.size * scale
  pulse:SetWidth(sz)
  pulse:SetHeight(sz)

  local iconDur = SpellReadyDB.iconFadeDuration or 0.6
  local textDur = SpellReadyDB.textFadeDuration or 1.0
  local iconP = p
  local textP = p
  if iconDur > 0 then
    iconP = anim.t / iconDur
    if iconP > 1 then iconP = 1 end
  end
  if textDur > 0 then
    textP = anim.t / textDur
    if textP > 1 then textP = 1 end
  end

  local iconA = SpellReadyDB.alphaStart + (SpellReadyDB.alphaEnd - SpellReadyDB.alphaStart) * iconP
  local textA = SpellReadyDB.alphaStart + (SpellReadyDB.alphaEnd - SpellReadyDB.alphaStart) * textP
  if anim.showIcon then
    pulse.tex:SetAlpha(iconA)
  end
  if anim.showText then
    pulse.text:SetAlpha(textA)
  end
end)

------------------------------------------------------------
-- Slash command: /sr
------------------------------------------------------------
SLASH_SPELLREADYTURTLE1 = "/sr"
SLASH_SPELLREADYTURTLE2 = "/srt"
SLASH_SPELLREADYTURTLE3 = "/spellready"
SlashCmdList["SPELLREADYTURTLE"] = function(msg)
  msg = string.lower(msg or "")

  if msg == "test" then
    testBtn:GetScript("OnClick")()
    return
  end

  if menu:IsShown() then
    menu:Hide()
  else
    menu:ClearAllPoints()
    menu:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    menu:Raise()
    menu:Show()
  end
end
