---
--- Created by jenni
--- DateTime: 2/22/2026 12:57 PM
---
local addonName = ...
local frame = CreateFrame("Frame")

-- SavedVariables
PetCheckQoLDB = PetCheckQoLDB or {}

-- =========================================================
-- Config
-- =========================================================
local DEFAULTS = {
    text = "CALL YOUR PET, IDIOT",
    fontSize = 64,
    fontPath = "Fonts\\FRIZQT__.TTF", -- safe default; STANDARD_TEXT_FONT may not be ready at initial load
    -- Position relative to center of screen
    x = 0,
    y = 180,
    color = { 0.72, 0.45, 1.0, 1.0 },
    shadowColor = { 0, 0, 0, 1 },

    -- Hunter behavior:
    -- true  = warn MM hunters too
    -- false = do not warn MM by default
    warnMarksmanship = false,

    -- Death Knight behavior:
    warnDeathKnight = true,
    warnNonUnholyDK = false,
}

local CONFIG = {}

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            CopyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

CopyDefaults(PetCheckQoLDB, DEFAULTS)
CONFIG = PetCheckQoLDB

-- =========================================================
-- Warning Frame
-- =========================================================
local warningFrame = CreateFrame("Frame", "PetCheckQoLWarningFrame", UIParent)
warningFrame:SetSize(900, 80)
warningFrame:SetPoint("CENTER", UIParent, "CENTER", CONFIG.x, CONFIG.y)
warningFrame:Hide()

local warningText = warningFrame:CreateFontString(nil, "OVERLAY")
warningText:SetAllPoints()
warningText:SetJustifyH("CENTER")
warningText:SetJustifyV("MIDDLE")
warningText:SetShadowOffset(2, -2)

local function EnsureDefaultFont()
    local fallback = (type(STANDARD_TEXT_FONT) == "string" and STANDARD_TEXT_FONT ~= "") and STANDARD_TEXT_FONT or DEFAULTS.fontPath

    if type(CONFIG.fontPath) ~= "string" or CONFIG.fontPath == "" then
        CONFIG.fontPath = fallback
    end

    if type(CONFIG.fontSize) ~= "number" then
        CONFIG.fontSize = DEFAULTS.fontSize
    end
    if CONFIG.fontSize < 8 then CONFIG.fontSize = 8 end
    if CONFIG.fontSize > 200 then CONFIG.fontSize = 200 end
end

local function ApplyTextStyle()
    EnsureDefaultFont()

    local ok = warningText:SetFont(CONFIG.fontPath, CONFIG.fontSize, "OUTLINE")
    if not ok then
        CONFIG.fontPath = DEFAULTS.fontPath or STANDARD_TEXT_FONT
        warningText:SetFont(CONFIG.fontPath, CONFIG.fontSize, "OUTLINE")
    end

    local c = CONFIG.color or DEFAULTS.color
    warningText:SetTextColor(c[1], c[2], c[3], c[4])

    local s = CONFIG.shadowColor or DEFAULTS.shadowColor
    warningText:SetShadowColor(s[1], s[2], s[3], s[4])
end

ApplyTextStyle()
warningText:SetText(CONFIG.text or DEFAULTS.text)

-- Optional backdrop-ish drag helper (invisible unless moving)
warningFrame:SetMovable(true)
warningFrame:EnableMouse(false)
warningFrame:RegisterForDrag("LeftButton")
warningFrame:SetClampedToScreen(true)

warningFrame:SetScript("OnDragStart", function(self)
    if self.isMoving then
        self:StartMoving()
    end
end)

warningFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, xOfs, yOfs = self:GetPoint(1)
    CONFIG.x = math.floor(xOfs + 0.5)
    CONFIG.y = math.floor(yOfs + 0.5)
    print(string.format("|cffb58cff[PetCheck]|r Moved to x=%d y=%d", CONFIG.x, CONFIG.y))
end)

local function SetMoveMode(enabled)
    warningFrame.isMoving = enabled
    warningFrame:EnableMouse(enabled)

    if enabled then
        -- Show helper text while moving
        warningFrame:Show()
        warningText:SetText("|cffb58cff[PetCheck]|r Drag me (left-click)\nType /petcheck lock when done")
        warningText:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
    else
        warningText:SetText(CONFIG.text)
        ApplyTextStyle()
        -- Refresh actual visibility based on pet state
    end
end

-- =========================================================
-- Class / Spec Logic
-- =========================================================
local function GetPlayerClass()
    if not UnitExists("player") then return nil end
    local _, classTag = UnitClass("player")
    return classTag
end

local function GetSpecID()
    -- Returns nil if spec not available yet during loading
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex then return nil end

    local specID = GetSpecializationInfo(specIndex)
    return specID
end

local function ShouldTrackPet()
    local classTag = GetPlayerClass()
    if not classTag then return false end

    -- Warlock: usually yes for all specs
    if classTag == "WARLOCK" then
        return true
    end

    -- Hunter: spec-aware
    if classTag == "HUNTER" then
        local specID = GetSpecID()
        -- 253 BM, 254 MM, 255 Survival
        if specID == 253 or specID == 255 then
            return true
        end
        if specID == 254 then
            return CONFIG.warnMarksmanship
        end
        -- If spec isn't available yet on load, default to true for hunter
        if specID == nil then
            return true
        end
    end

    if classTag == "DEATHKNIGHT" and CONFIG.warnDeathKnight then
        local specID = GetSpecID()
        -- 250 Blood, 251 Frost, 252 Unholy
        if specID == 252 then
            return true
        end
        if specID == 250 or specID == 251 then
            return CONFIG.warnNonUnholyDK
        end
        if specID == nil then
            return true
        end
    end

    return false
end

-- =========================================================
-- Core Update Logic
-- =========================================================
local function IsPetMissing()
    return not UnitExists("pet")
end

local function UpdatePetWarning()
    if warningFrame.isMoving then
        return -- don't override while dragging
    end

    if not UnitExists("player") then
        warningFrame:Hide()
        return
    end

    if not ShouldTrackPet() then
        warningFrame:Hide()
        return
    end

    if IsPetMissing() then
        warningText:SetText(CONFIG.text)
        ApplyTextStyle()
        warningFrame:Show()
    else
        warningFrame:Hide()
    end
end

-- =========================================================
-- Slash Helpers
-- =========================================================
local FONT_ALIASES = {
    default = STANDARD_TEXT_FONT,
    frizqt = "Fonts\\FRIZQT__.TTF",
    arialn = "Fonts\\ARIALN.TTF",
    morpheus = "Fonts\\MORPHEUS.TTF",
    skurri = "Fonts\\skurri.ttf",
}

CONFIG.customFonts = CONFIG.customFonts or {}

local function GetCombinedFontOptions()
    local options = {
        { text = "Default UI", path = FONT_ALIASES.default },
        { text = "Friz Quadrata", path = FONT_ALIASES.frizqt },
        { text = "Arial Narrow", path = FONT_ALIASES.arialn },
        { text = "Morpheus", path = FONT_ALIASES.morpheus },
        { text = "Skurri", path = FONT_ALIASES.skurri },
    }

    for name, path in pairs(CONFIG.customFonts) do
        if type(name) == "string" and name ~= "" and type(path) == "string" and path ~= "" then
            table.insert(options, { text = name, path = path, isCustom = true })
        end
    end

    table.sort(options, function(a, b)
        if a.isCustom ~= b.isCustom then
            return not a.isCustom
        end
        return string.lower(a.text) < string.lower(b.text)
    end)

    return options
end

local function ClampColorValue(v)
    if v > 1 then
        v = v / 255
    end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ParseColorArgs(raw)
    local a1, a2, a3, a4 = string.match(raw or "", "^(%S+)%s+(%S+)%s+(%S+)%s*(%S*)$")
    if not a1 or not a2 or not a3 then
        return nil
    end

    local r = tonumber(a1)
    local g = tonumber(a2)
    local b = tonumber(a3)
    local a = tonumber(a4)
    if not r or not g or not b then
        return nil
    end

    if a == nil then a = 1 end
    return ClampColorValue(r), ClampColorValue(g), ClampColorValue(b), ClampColorValue(a)
end

local function FormatColor(c)
    return string.format("%.2f %.2f %.2f %.2f", c[1], c[2], c[3], c[4])
end

local function OpenColorPicker(initial, onApply)
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        print("|cffb58cff[PetCheck]|r Color picker not available in this client UI.")
        return
    end

    local prev = { initial[1], initial[2], initial[3], initial[4] or 1 }
    local function apply(restore)
        local r, g, b, a
        if restore then
            r, g, b, a = unpack(restore)
        else
            local c = ColorPickerFrame:GetColorRGB()
            r, g, b = c.r, c.g, c.b
            a = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
        end
        onApply(r, g, b, a)
    end

    ColorPickerFrame:SetupColorPickerAndShow({
        r = prev[1],
        g = prev[2],
        b = prev[3],
        opacity = 1 - prev[4],
        hasOpacity = true,
        swatchFunc = function() apply() end,
        opacityFunc = function() apply() end,
        cancelFunc = function(restore) apply(restore) end,
    })
end

-- =========================================================
-- Settings Panel
-- =========================================================
local optionsPanel
local optionsCategoryID

local function OpenAddonOptions()
    if Settings and Settings.OpenToCategory and optionsCategoryID then
        Settings.OpenToCategory(optionsCategoryID)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory and optionsPanel then
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    end
end

local function CreateLabel(parent, text, anchorTo, x, y)
    local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
    label:SetText(text)
    return label
end

local function CreateInput(parent, width, anchorTo, x, y)
    local input = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    input:SetSize(width, 22)
    input:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x, y)
    input:SetAutoFocus(false)
    input:SetMaxLetters(256)
    return input
end

local function CreateDropdown(parent, width, anchorTo, x, y)
    local dropdown = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", x - 16, y + 8)
    UIDropDownMenu_SetWidth(dropdown, width)
    return dropdown
end

local function RegisterOptionsPanel()
    if optionsPanel then
        return
    end

    optionsPanel = CreateFrame("Frame", "PetCheckQoLOptionsPanel", UIParent)

    local title = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Pet Check QoL")

    local subtitle = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Configure warning behavior, position, font, and colors.")

    local mmCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    mmCheck:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -16)
    if mmCheck.Text then
        mmCheck.Text:SetText("Warn Marksmanship hunters")
    end
    mmCheck:SetScript("OnClick", function(self)
        CONFIG.warnMarksmanship = self:GetChecked() and true or false
        UpdatePetWarning()
    end)

    local dkCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    dkCheck:SetPoint("TOPLEFT", mmCheck, "BOTTOMLEFT", 0, -6)
    if dkCheck.Text then
        dkCheck.Text:SetText("Warn Unholy Death Knights")
    end
    dkCheck:SetScript("OnClick", function(self)
        CONFIG.warnDeathKnight = self:GetChecked() and true or false
        UpdatePetWarning()
    end)

    local dkNonUhCheck = CreateFrame("CheckButton", nil, optionsPanel, "InterfaceOptionsCheckButtonTemplate")
    dkNonUhCheck:SetPoint("TOPLEFT", dkCheck, "BOTTOMLEFT", 20, -2)
    if dkNonUhCheck.Text then
        dkNonUhCheck.Text:SetText("Also warn Blood/Frost DKs")
    end
    dkNonUhCheck:SetScript("OnClick", function(self)
        CONFIG.warnNonUnholyDK = self:GetChecked() and true or false
        UpdatePetWarning()
    end)

    local fontLabel = CreateLabel(optionsPanel, "Font", dkNonUhCheck, -20, -18)
    local fontDropdown = CreateDropdown(optionsPanel, 220, fontLabel, 0, -10)

    local function GetFontDropdownLabel()
        local options = GetCombinedFontOptions()
        for _, opt in ipairs(options) do
            if opt.path == CONFIG.fontPath then
                return opt.text
            end
        end
        return "Custom Path (slash command)"
    end

    UIDropDownMenu_Initialize(fontDropdown, function(self, level)
        local options = GetCombinedFontOptions()
        local info
        for _, opt in ipairs(options) do
            info = UIDropDownMenu_CreateInfo()
            info.text = opt.text
            info.func = function()
                local ok = warningText:SetFont(opt.path, CONFIG.fontSize, "OUTLINE")
                if not ok then
                    print("|cffb58cff[PetCheck]|r That font failed to load.")
                    return
                end
                CONFIG.fontPath = opt.path
                UIDropDownMenu_SetSelectedName(fontDropdown, opt.text)
                ApplyTextStyle()
                UpdatePetWarning()
            end
            info.checked = (opt.path == CONFIG.fontPath)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    local fontHint = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fontHint:SetPoint("TOPLEFT", fontDropdown, "BOTTOMLEFT", 20, -4)
    fontHint:SetText("WoW can't auto-scan files. Add custom fonts with /petcheck addfont <Name>|<Path>")

    local textLabel = CreateLabel(optionsPanel, "Warning text", fontHint, 0, -18)
    local textInput = CreateInput(optionsPanel, 320, textLabel, 0, -8)
    textInput:SetMaxLetters(120)
    textInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local textApply = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    textApply:SetSize(100, 24)
    textApply:SetPoint("LEFT", textInput, "RIGHT", 10, 0)
    textApply:SetText("Apply Text")
    textApply:SetScript("OnClick", function()
        local newText = textInput:GetText() or ""
        newText = newText:gsub("^%s+", ""):gsub("%s+$", "")
        if newText == "" then
            newText = DEFAULTS.text
        end
        CONFIG.text = string.upper(newText)
        warningText:SetText(CONFIG.text)
        ApplyTextStyle()
        UpdatePetWarning()
        textInput:SetText(CONFIG.text)
    end)

    local sizeLabel = CreateLabel(optionsPanel, "Font size (8-200)", textInput, 0, -14)
    local sizeInput = CreateInput(optionsPanel, 80, sizeLabel, 0, -8)
    sizeInput:SetNumeric(true)
    sizeInput:SetMaxLetters(3)
    sizeInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local sizeApply = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    sizeApply:SetSize(100, 24)
    sizeApply:SetPoint("LEFT", sizeInput, "RIGHT", 10, 0)
    sizeApply:SetText("Apply Size")
    sizeApply:SetScript("OnClick", function()
        local n = tonumber(sizeInput:GetText() or "")
        if not n then
            print("|cffb58cff[PetCheck]|r Font size must be a number.")
            return
        end
        n = math.floor(n + 0.5)
        if n < 8 then n = 8 end
        if n > 200 then n = 200 end
        CONFIG.fontSize = n
        ApplyTextStyle()
        UpdatePetWarning()
        sizeInput:SetText(tostring(CONFIG.fontSize))
    end)

    local colorLabel = CreateLabel(optionsPanel, "Text color (r g b a)", sizeInput, 0, -14)
    local colorInput = CreateInput(optionsPanel, 180, colorLabel, 0, -8)
    colorInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local colorApply = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    colorApply:SetSize(80, 24)
    colorApply:SetPoint("LEFT", colorInput, "RIGHT", 10, 0)
    colorApply:SetText("Apply")
    colorApply:SetScript("OnClick", function()
        local r, g, b, a = ParseColorArgs(colorInput:GetText())
        if not r then
            print("|cffb58cff[PetCheck]|r Use: r g b [a], values 0-1 or 0-255")
            return
        end
        CONFIG.color[1], CONFIG.color[2], CONFIG.color[3], CONFIG.color[4] = r, g, b, a
        ApplyTextStyle()
        UpdatePetWarning()
        colorInput:SetText(FormatColor(CONFIG.color))
    end)

    local colorPick = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    colorPick:SetSize(80, 24)
    colorPick:SetPoint("LEFT", colorApply, "RIGHT", 6, 0)
    colorPick:SetText("Pick")
    colorPick:SetScript("OnClick", function()
        OpenColorPicker(CONFIG.color, function(r, g, b, a)
            CONFIG.color[1], CONFIG.color[2], CONFIG.color[3], CONFIG.color[4] = r, g, b, a
            ApplyTextStyle()
            UpdatePetWarning()
            colorInput:SetText(FormatColor(CONFIG.color))
        end)
    end)

    local shadowLabel = CreateLabel(optionsPanel, "Shadow color (r g b a)", colorInput, 0, -14)
    local shadowInput = CreateInput(optionsPanel, 180, shadowLabel, 0, -8)
    shadowInput:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)

    local shadowApply = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    shadowApply:SetSize(80, 24)
    shadowApply:SetPoint("LEFT", shadowInput, "RIGHT", 10, 0)
    shadowApply:SetText("Apply Shadow")
    shadowApply:SetScript("OnClick", function()
        local r, g, b, a = ParseColorArgs(shadowInput:GetText())
        if not r then
            print("|cffb58cff[PetCheck]|r Use: r g b [a], values 0-1 or 0-255")
            return
        end
        CONFIG.shadowColor[1], CONFIG.shadowColor[2], CONFIG.shadowColor[3], CONFIG.shadowColor[4] = r, g, b, a
        ApplyTextStyle()
        UpdatePetWarning()
        shadowInput:SetText(FormatColor(CONFIG.shadowColor))
    end)

    local shadowPick = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    shadowPick:SetSize(80, 24)
    shadowPick:SetPoint("LEFT", shadowApply, "RIGHT", 6, 0)
    shadowPick:SetText("Pick")
    shadowPick:SetScript("OnClick", function()
        OpenColorPicker(CONFIG.shadowColor, function(r, g, b, a)
            CONFIG.shadowColor[1], CONFIG.shadowColor[2], CONFIG.shadowColor[3], CONFIG.shadowColor[4] = r, g, b, a
            ApplyTextStyle()
            UpdatePetWarning()
            shadowInput:SetText(FormatColor(CONFIG.shadowColor))
        end)
    end)

    local moveButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    moveButton:SetSize(100, 24)
    moveButton:SetPoint("TOPLEFT", shadowInput, "BOTTOMLEFT", 0, -14)
    moveButton:SetText("Move Text")
    moveButton:SetScript("OnClick", function()
        SetMoveMode(true)
    end)

    local lockButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    lockButton:SetSize(100, 24)
    lockButton:SetPoint("LEFT", moveButton, "RIGHT", 10, 0)
    lockButton:SetText("Lock Text")
    lockButton:SetScript("OnClick", function()
        SetMoveMode(false)
        UpdatePetWarning()
    end)

    local resetButton = CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(140, 24)
    resetButton:SetPoint("TOPLEFT", moveButton, "BOTTOMLEFT", 0, -10)
    resetButton:SetText("Reset To Defaults")
    resetButton:SetScript("OnClick", function()
        CONFIG.warnMarksmanship = DEFAULTS.warnMarksmanship
        CONFIG.warnDeathKnight = DEFAULTS.warnDeathKnight
        CONFIG.warnNonUnholyDK = DEFAULTS.warnNonUnholyDK
        CONFIG.fontSize = DEFAULTS.fontSize
        CONFIG.fontPath = DEFAULTS.fontPath
        CONFIG.color[1], CONFIG.color[2], CONFIG.color[3], CONFIG.color[4] = unpack(DEFAULTS.color)
        CONFIG.shadowColor[1], CONFIG.shadowColor[2], CONFIG.shadowColor[3], CONFIG.shadowColor[4] = unpack(DEFAULTS.shadowColor)
        CONFIG.x, CONFIG.y = DEFAULTS.x, DEFAULTS.y

        warningFrame:ClearAllPoints()
        warningFrame:SetPoint("CENTER", UIParent, "CENTER", CONFIG.x, CONFIG.y)
        ApplyTextStyle()
        UpdatePetWarning()

        local onShow = optionsPanel:GetScript("OnShow")
        if onShow then
            onShow(optionsPanel)
        end
    end)

    optionsPanel:SetScript("OnShow", function()
        EnsureDefaultFont()
        mmCheck:SetChecked(CONFIG.warnMarksmanship)
        dkCheck:SetChecked(CONFIG.warnDeathKnight)
        dkNonUhCheck:SetChecked(CONFIG.warnNonUnholyDK)
        UIDropDownMenu_SetText(fontDropdown, GetFontDropdownLabel())
        sizeInput:SetText(tostring(CONFIG.fontSize))
        colorInput:SetText(FormatColor(CONFIG.color))
        shadowInput:SetText(FormatColor(CONFIG.shadowColor))
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(optionsPanel, "Pet Check QoL")
        Settings.RegisterAddOnCategory(category)
        optionsCategoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        optionsPanel.name = "Pet Check QoL"
        InterfaceOptions_AddCategory(optionsPanel)
    end
end

-- =========================================================
-- Events
-- =========================================================
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_PET")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")

frame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        RegisterOptionsPanel()
        warningFrame:ClearAllPoints()
        warningFrame:SetPoint("CENTER", UIParent, "CENTER", CONFIG.x, CONFIG.y)
        ApplyTextStyle()

        -- WoW can fire PLAYER_ENTERING_WORLD before all unit/spec data is fully ready.
        -- Do a few delayed retries so the warning appears reliably on login/reload.
        C_Timer.After(0, UpdatePetWarning)
        C_Timer.After(0.25, UpdatePetWarning)
        C_Timer.After(1.0, UpdatePetWarning)
    end

    if event == "UNIT_PET" then
        if unit == "player" then
            UpdatePetWarning()
        end
        return
    end

    if event == "PLAYER_SPECIALIZATION_CHANGED" then
        if unit and unit ~= "player" then
            return
        end
    end

    UpdatePetWarning()
end)

-- =========================================================
-- Slash Commands
-- =========================================================
SLASH_PETCHECKQOL1 = "/petcheck"
SlashCmdList["PETCHECKQOL"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local lmsg = msg:lower()

    if lmsg == "test" then
        warningText:SetText(CONFIG.text)
        ApplyTextStyle()
        warningFrame:Show()
        print("|cffb58cff[PetCheck]|r Test message shown.")
        C_Timer.After(3, function()
            if warningFrame and not warningFrame.isMoving then
                UpdatePetWarning()
            end
        end)
        return
    end

    if lmsg == "hide" then
        warningFrame:Hide()
        print("|cffb58cff[PetCheck]|r Hidden (until next state update).")
        return
    end

    if lmsg == "status" then
        local classTag = GetPlayerClass() or "UNKNOWN"
        local specID = GetSpecID()
        local tracking = ShouldTrackPet() and "YES" or "NO"
        local petStatus = UnitExists("pet") and "SUMMONED" or "MISSING"

        print(string.format(
            "|cffb58cff[PetCheck]|r Class=%s SpecID=%s Track=%s Pet=%s",
            tostring(classTag),
            tostring(specID),
            tracking,
            petStatus
        ))
        print(string.format(
            "|cffb58cff[PetCheck]|r Pos=(%d,%d) Font=%s Size=%d Color=%.2f,%.2f,%.2f,%.2f",
            CONFIG.x,
            CONFIG.y,
            tostring(CONFIG.fontPath),
            CONFIG.fontSize,
            CONFIG.color[1], CONFIG.color[2], CONFIG.color[3], CONFIG.color[4]
        ))
        return
    end

    if lmsg == "move" then
        SetMoveMode(true)
        return
    end

    if lmsg == "lock" then
        SetMoveMode(false)
        UpdatePetWarning()
        return
    end

    if lmsg == "options" then
        OpenAddonOptions()
        return
    end

    if lmsg == "dk on" then
        CONFIG.warnDeathKnight = true
        print("|cffb58cff[PetCheck]|r Death Knight warnings: ON")
        UpdatePetWarning()
        return
    end

    if lmsg == "dk off" then
        CONFIG.warnDeathKnight = false
        print("|cffb58cff[PetCheck]|r Death Knight warnings: OFF")
        UpdatePetWarning()
        return
    end

    if lmsg == "dkall on" then
        CONFIG.warnNonUnholyDK = true
        print("|cffb58cff[PetCheck]|r Blood/Frost DK warnings: ON")
        UpdatePetWarning()
        return
    end

    if lmsg == "dkall off" then
        CONFIG.warnNonUnholyDK = false
        print("|cffb58cff[PetCheck]|r Blood/Frost DK warnings: OFF")
        UpdatePetWarning()
        return
    end

    if lmsg == "mm on" then
        CONFIG.warnMarksmanship = true
        print("|cffb58cff[PetCheck]|r Marksmanship warnings: ON")
        UpdatePetWarning()
        return
    end

    if lmsg == "mm off" then
        CONFIG.warnMarksmanship = false
        print("|cffb58cff[PetCheck]|r Marksmanship warnings: OFF")
        UpdatePetWarning()
        return
    end

    local sizeArg = string.match(lmsg, "^fontsize%s+(%S+)$")
    if sizeArg then
        local n = tonumber(sizeArg)
        if not n then
            print("|cffb58cff[PetCheck]|r Usage: /petcheck fontsize <number>")
            return
        end
        n = math.floor(n + 0.5)
        if n < 8 then n = 8 end
        if n > 200 then n = 200 end
        CONFIG.fontSize = n
        ApplyTextStyle()
        UpdatePetWarning()
        print(string.format("|cffb58cff[PetCheck]|r Font size set to %d", n))
        return
    end

    local addFontArg = string.match(msg, "^addfont%s+(.+)$")
    if addFontArg then
        local name, path = string.match(addFontArg, "^([^|]+)|%s*(.+)$")
        if not name or not path then
            print("|cffb58cff[PetCheck]|r Usage: /petcheck addfont <Name>|<Path>")
            print("|cffb58cff[PetCheck]|r Example: /petcheck addfont MyWA|Interface\\AddOns\\PetCheckQoL\\fonts\\MyFont.ttf")
            return
        end
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        path = path:gsub("^%s+", ""):gsub("%s+$", "")
        local ok = warningText:SetFont(path, CONFIG.fontSize, "OUTLINE")
        if not ok then
            print("|cffb58cff[PetCheck]|r Could not load that font path.")
            return
        end
        CONFIG.customFonts[name] = path
        CONFIG.fontPath = path
        ApplyTextStyle()
        UpdatePetWarning()
        print(string.format("|cffb58cff[PetCheck]|r Added custom font '%s'", name))
        return
    end

    local delFontArg = string.match(msg, "^delfont%s+(.+)$")
    if delFontArg then
        local name = delFontArg:gsub("^%s+", ""):gsub("%s+$", "")
        if CONFIG.customFonts[name] then
            local removedPath = CONFIG.customFonts[name]
            CONFIG.customFonts[name] = nil
            if CONFIG.fontPath == removedPath then
                CONFIG.fontPath = DEFAULTS.fontPath
            end
            ApplyTextStyle()
            UpdatePetWarning()
            print(string.format("|cffb58cff[PetCheck]|r Removed custom font '%s'", name))
        else
            print(string.format("|cffb58cff[PetCheck]|r No custom font named '%s'", name))
        end
        return
    end

    local fontArg = string.match(msg, "^font%s+(.+)$")
    if fontArg then
        local key = string.lower(fontArg)
        local fontPath = FONT_ALIASES[key] or CONFIG.customFonts[fontArg] or fontArg
        local ok = warningText:SetFont(fontPath, CONFIG.fontSize, "OUTLINE")
        if not ok then
            print("|cffb58cff[PetCheck]|r Invalid font. Try a built-in, a custom font name, or a full font path.")
            return
        end
        CONFIG.fontPath = fontPath
        ApplyTextStyle()
        UpdatePetWarning()
        print(string.format("|cffb58cff[PetCheck]|r Font set to %s", tostring(fontPath)))
        return
    end

    local colorArg = string.match(lmsg, "^color%s+(.+)$")
    if colorArg then
        local r, g, b, a = ParseColorArgs(colorArg)
        if not r then
            print("|cffb58cff[PetCheck]|r Usage: /petcheck color <r> <g> <b> [a] (0-1 or 0-255)")
            return
        end
        CONFIG.color[1], CONFIG.color[2], CONFIG.color[3], CONFIG.color[4] = r, g, b, a
        ApplyTextStyle()
        UpdatePetWarning()
        print(string.format("|cffb58cff[PetCheck]|r Text color set to %.2f %.2f %.2f %.2f", r, g, b, a))
        return
    end

    local shadowArg = string.match(lmsg, "^shadow%s+(.+)$")
    if shadowArg then
        local r, g, b, a = ParseColorArgs(shadowArg)
        if not r then
            print("|cffb58cff[PetCheck]|r Usage: /petcheck shadow <r> <g> <b> [a] (0-1 or 0-255)")
            return
        end
        CONFIG.shadowColor[1], CONFIG.shadowColor[2], CONFIG.shadowColor[3], CONFIG.shadowColor[4] = r, g, b, a
        ApplyTextStyle()
        UpdatePetWarning()
        print(string.format("|cffb58cff[PetCheck]|r Shadow color set to %.2f %.2f %.2f %.2f", r, g, b, a))
        return
    end

    print("|cffb58cff[PetCheck]|r Commands:")
    print("  /petcheck test   - Show test warning for 3 sec")
    print("  /petcheck status - Print class/spec/pet state")
    print("  /petcheck move   - Drag the text")
    print("  /petcheck lock   - Lock text position")
    print("  /petcheck options               - Open addon settings")
    print("  /petcheck fontsize <n>          - Set text size (8-200)")
    print("  /petcheck font <name|path>      - Set font (built-in, custom name, or path)")
    print("  /petcheck addfont <Name>|<Path> - Add custom font to dropdown")
    print("  /petcheck delfont <Name>        - Remove custom font from dropdown")
    print("  /petcheck color <r> <g> <b> [a] - Set text color (0-1 or 0-255)")
    print("  /petcheck shadow <r> <g> <b> [a]- Set shadow color (0-1 or 0-255)")
    print("  /petcheck dk on  - Warn Unholy Death Knights")
    print("  /petcheck dk off - Do not warn Death Knights")
    print("  /petcheck dkall on  - Also warn Blood/Frost DKs")
    print("  /petcheck dkall off - Only warn Unholy DKs")
    print("  /petcheck mm on  - Warn Marksmanship hunters too")
    print("  /petcheck mm off - Do not warn Marksmanship hunters")
end
