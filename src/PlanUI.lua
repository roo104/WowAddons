-- PlanUI: User interface for creating, editing, and viewing cooldown plans
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local PlanUI = {}

-- UI Elements
local mainFrame = nil
local planListFrame = nil
local planEditorFrame = nil
local currentPlan = nil

-- Available spells for dropdown
local AVAILABLE_SPELLS = {
    {id = 51052, name = "Anti-Magic Zone"},
    {id = 31842, name = "Devotion Aura"},
    {id = 64843, name = "Divine Hymn"},
    {id = 108280, name = "Healing Tide Totem"},
    {id = 62618, name = "Power Word: Barrier"},
    {id = 97462, name = "Rallying Cry"},
    {id = 115310, name = "Revival"},
    {id = 76577, name = "Smoke Bomb"},
    {id = 740, name = "Tranquility"},
}

-- Colors
local COLOR_HEADER = {0.5, 0.8, 1}
local COLOR_BUTTON = {0.2, 0.6, 0.8}
local COLOR_BUTTON_HOVER = {0.3, 0.7, 0.9}
local COLOR_COMPLETED = {0.2, 0.8, 0.2}
local COLOR_PENDING = {0.8, 0.8, 0.2}

-- Create main plan manager frame
function PlanUI.CreateMainFrame()
    if mainFrame then
        return mainFrame
    end

    mainFrame = CreateFrame("Frame", "NordensParisPlanFrame", UIParent, "BasicFrameTemplateWithInset")
    mainFrame:SetSize(500, 400)
    mainFrame:SetPoint("CENTER")
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    mainFrame:SetClampedToScreen(true)
    mainFrame:Hide()

    -- Title
    mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mainFrame.title:SetPoint("TOP", 0, -5)
    mainFrame.title:SetText("Nordens Paris - Cooldown Plans")

    -- Close button (already part of BasicFrameTemplate)
    mainFrame.CloseButton:SetScript("OnClick", function()
        mainFrame:Hide()
    end)

    -- Create tabs
    PlanUI.CreateTabs(mainFrame)

    return mainFrame
end

-- Create tab system
function PlanUI.CreateTabs(parent)
    local tabs = {}

    -- Tab 1: My Plans
    local tab1 = CreateFrame("Button", "NordensParisPlanTab1", parent, "PanelTabButtonTemplate")
    tab1:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 10, 0)
    tab1:SetText("My Plans")
    tab1:SetScript("OnClick", function()
        PanelTemplates_SetTab(parent, 1)
        PlanUI.ShowPlanList()
    end)
    table.insert(tabs, tab1)

    -- Tab 2: Received Plans
    local tab2 = CreateFrame("Button", "NordensParisPlanTab2", parent, "PanelTabButtonTemplate")
    tab2:SetPoint("LEFT", tab1, "RIGHT", 5, 0)
    tab2:SetText("Received Plans")
    tab2:SetScript("OnClick", function()
        PanelTemplates_SetTab(parent, 2)
        PlanUI.ShowReceivedPlans()
    end)
    table.insert(tabs, tab2)

    parent.numTabs = #tabs
    parent.tabs = tabs

    -- Default to tab 1
    PanelTemplates_SetTab(parent, 1)
    PanelTemplates_SetNumTabs(parent, #tabs)
end

-- Create plan list view
function PlanUI.CreatePlanListFrame()
    if planListFrame then
        return planListFrame
    end

    planListFrame = CreateFrame("Frame", "NordensParisPlanList", mainFrame)
    planListFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
    planListFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)

    -- Scroll frame for plans
    local scrollFrame = CreateFrame("ScrollFrame", "NordensParisPlanListScroll", planListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 1)
    scrollFrame:SetScrollChild(scrollChild)

    planListFrame.scrollFrame = scrollFrame
    planListFrame.scrollChild = scrollChild
    planListFrame.planButtons = {}

    -- New plan button
    local newPlanButton = CreateFrame("Button", "NordensParisNewPlanButton", planListFrame, "UIPanelButtonTemplate")
    newPlanButton:SetSize(120, 25)
    newPlanButton:SetPoint("TOPLEFT", 5, -5)
    newPlanButton:SetText("New Plan")
    newPlanButton:SetScript("OnClick", function()
        PlanUI.ShowNewPlanDialog()
    end)

    return planListFrame
end

-- Show plan list
function PlanUI.ShowPlanList()
    if not planListFrame then
        PlanUI.CreatePlanListFrame()
    end

    -- Hide other frames (but not viewer - it's independent)
    if planEditorFrame then planEditorFrame:Hide() end

    planListFrame:Show()
    PlanUI.RefreshPlanList()
end

-- Refresh plan list display
function PlanUI.RefreshPlanList()
    if not planListFrame or not NordensParis_PlanManager then
        return
    end

    local scrollChild = planListFrame.scrollChild
    local plans = NordensParis_PlanManager.GetAllPlans()

    -- Clear existing buttons
    for _, btn in ipairs(planListFrame.planButtons) do
        btn:Hide()
    end

    -- Create/update plan buttons
    local yOffset = 0
    local index = 1

    for planName, plan in pairs(plans) do
        local btn = planListFrame.planButtons[index]

        if not btn then
            btn = CreateFrame("Frame", nil, scrollChild)
            btn:SetSize(400, 60)
            btn:EnableMouse(true)

            -- Background
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

            -- Plan name
            btn.nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            btn.nameText:SetPoint("TOPLEFT", 10, -5)
            btn.nameText:SetJustifyH("LEFT")

            -- Info text
            btn.infoText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.infoText:SetPoint("TOPLEFT", 10, -20)
            btn.infoText:SetJustifyH("LEFT")
            btn.infoText:SetTextColor(0.7, 0.7, 0.7)

            -- Activate button (leftmost)
            btn.activateButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.activateButton:SetSize(70, 20)
            btn.activateButton:SetPoint("TOPLEFT", 10, -35)
            btn.activateButton:SetText("Activate")

            -- Share button
            btn.shareButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.shareButton:SetSize(60, 20)
            btn.shareButton:SetPoint("LEFT", btn.activateButton, "RIGHT", 5, 0)
            btn.shareButton:SetText("Share")

            -- Edit button
            btn.editButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.editButton:SetSize(60, 20)
            btn.editButton:SetPoint("LEFT", btn.shareButton, "RIGHT", 5, 0)
            btn.editButton:SetText("Edit")

            -- Delete button
            btn.deleteButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.deleteButton:SetSize(60, 20)
            btn.deleteButton:SetPoint("LEFT", btn.editButton, "RIGHT", 5, 0)
            btn.deleteButton:SetText("Delete")

            table.insert(planListFrame.planButtons, btn)
        end

        btn:SetPoint("TOPLEFT", 10, -yOffset)
        btn:Show()

        local summary = NordensParis_PlanManager.GetPlanSummary(planName)
        btn.nameText:SetText(planName)
        btn.infoText:SetText(string.format("%d steps | by %s",
            summary.stepCount, summary.author or "Unknown"))

        -- Button handlers
        btn.editButton:SetScript("OnClick", function()
            PlanUI.EditPlan(planName)
        end)

        btn.shareButton:SetScript("OnClick", function()
            PlanUI.SharePlan(planName)
        end)

        btn.deleteButton:SetScript("OnClick", function()
            PlanUI.DeletePlan(planName)
        end)

        btn.activateButton:SetScript("OnClick", function()
            PlanUI.ActivatePlan(planName)
        end)

        yOffset = yOffset + 65
        index = index + 1
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))

    -- Hide scrollbar if content fits
    local scrollBar = planListFrame.scrollFrame.ScrollBar
    if scrollBar then
        if yOffset <= planListFrame.scrollFrame:GetHeight() then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end
end

-- Show new plan dialog
function PlanUI.ShowNewPlanDialog()
    StaticPopupDialogs["NORDENSPARIS_NEW_PLAN"] = {
        text = "Enter a name for the new plan:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                local planName = editBox:GetText()
                if planName and planName ~= "" then
                    local plan, err = NordensParis_PlanManager.CreatePlan(planName)
                    if plan then
                        PlanUI.RefreshPlanList()
                        PlanUI.EditPlan(planName)
                    else
                        print("|cff00ff80Nordens Paris:|r " .. err)
                    end
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("NORDENSPARIS_NEW_PLAN")
end

-- Create plan editor frame
function PlanUI.CreatePlanEditorFrame()
    if planEditorFrame then
        return planEditorFrame
    end

    planEditorFrame = CreateFrame("Frame", "NordensParisPlanEditor", mainFrame)
    planEditorFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
    planEditorFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)
    planEditorFrame:Hide()

    -- Back button
    local backButton = CreateFrame("Button", nil, planEditorFrame, "UIPanelButtonTemplate")
    backButton:SetSize(80, 25)
    backButton:SetPoint("TOPLEFT", 5, -5)
    backButton:SetText("< Back")
    backButton:SetScript("OnClick", function()
        PlanUI.ShowPlanList()
    end)
    planEditorFrame.backButton = backButton

    -- Plan name title
    local titleText = planEditorFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("TOP", 0, -10)
    titleText:SetText("Edit Plan")
    planEditorFrame.titleText = titleText

    -- Rename button
    local renameButton = CreateFrame("Button", nil, planEditorFrame, "UIPanelButtonTemplate")
    renameButton:SetSize(80, 20)
    renameButton:SetPoint("TOP", titleText, "BOTTOM", 0, -5)
    renameButton:SetText("Rename")
    renameButton:SetScript("OnClick", function()
        PlanUI.ShowRenamePlanDialog()
    end)
    planEditorFrame.renameButton = renameButton

    -- Scroll frame for steps
    local scrollFrame = CreateFrame("ScrollFrame", "NordensParisPlanEditorScroll", planEditorFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -60)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 1)
    scrollFrame:SetScrollChild(scrollChild)

    planEditorFrame.scrollFrame = scrollFrame
    planEditorFrame.scrollChild = scrollChild
    planEditorFrame.stepButtons = {}

    -- Add step button
    local addStepButton = CreateFrame("Button", nil, planEditorFrame, "UIPanelButtonTemplate")
    addStepButton:SetSize(120, 25)
    addStepButton:SetPoint("BOTTOMLEFT", 10, 10)
    addStepButton:SetText("Add Step")
    addStepButton:SetScript("OnClick", function()
        PlanUI.ShowAddStepDialog()
    end)
    planEditorFrame.addStepButton = addStepButton

    return planEditorFrame
end

-- Create a step button in the editor
local function CreateStepButton(index)
    local btn = CreateFrame("Frame", nil, planEditorFrame.scrollChild)
    btn:SetSize(420, 50)

    -- Background
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.bg:SetColorTexture(0.1, 0.1, 0.1, 0.7)

    -- Order number
    btn.orderText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    btn.orderText:SetPoint("LEFT", 10, 0)
    btn.orderText:SetJustifyH("LEFT")
    btn.orderText:SetTextColor(1, 0.8, 0)

    -- Spell icon
    btn.spellIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.spellIcon:SetSize(32, 32)
    btn.spellIcon:SetPoint("LEFT", 40, 0)
    btn.spellIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Availability icon (green tick or red cross)
    btn.availIcon = btn:CreateTexture(nil, "OVERLAY")
    btn.availIcon:SetSize(16, 16)
    btn.availIcon:SetPoint("LEFT", 78, 5)

    -- Caster name (on top with yellow text)
    btn.casterText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.casterText:SetPoint("LEFT", 93, 5)
    btn.casterText:SetJustifyH("LEFT")
    btn.casterText:SetTextColor(1, 0.8, 0)

    -- Spell name (below)
    btn.spellText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.spellText:SetPoint("LEFT", 78, -10)
    btn.spellText:SetJustifyH("LEFT")
    btn.spellText:SetTextColor(0.7, 0.7, 0.7)

    -- Edit button
    btn.editButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
    btn.editButton:SetSize(50, 20)
    btn.editButton:SetPoint("RIGHT", -80, 0)
    btn.editButton:SetText("Edit")

    -- Delete button
    btn.deleteButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
    btn.deleteButton:SetSize(50, 20)
    btn.deleteButton:SetPoint("RIGHT", -25, 0)
    btn.deleteButton:SetText("Del")

    -- Move up button
    btn.upButton = CreateFrame("Button", nil, btn, "UIPanelScrollUpButtonTemplate")
    btn.upButton:SetSize(20, 20)
    btn.upButton:SetPoint("RIGHT", -180, 10)

    -- Move down button
    btn.downButton = CreateFrame("Button", nil, btn, "UIPanelScrollDownButtonTemplate")
    btn.downButton:SetSize(20, 20)
    btn.downButton:SetPoint("RIGHT", -180, -10)

    btn:Hide()
    return btn
end

-- Edit a plan
function PlanUI.EditPlan(planName)
    if not NordensParis_PlanManager then
        return
    end

    local plan = NordensParis_PlanManager.GetPlan(planName)
    if not plan then
        print("|cff00ff80Nordens Paris:|r Plan not found: " .. planName)
        return
    end

    currentPlan = planName

    if not planEditorFrame then
        PlanUI.CreatePlanEditorFrame()
    end

    -- Hide other frames (but not viewer - it's independent)
    if planListFrame then planListFrame:Hide() end

    planEditorFrame:Show()
    planEditorFrame.titleText:SetText(planName)

    PlanUI.RefreshPlanEditor()
end

-- Refresh plan editor display
function PlanUI.RefreshPlanEditor()
    if not planEditorFrame or not currentPlan or not NordensParis_PlanManager then
        return
    end

    local plan = NordensParis_PlanManager.GetPlan(currentPlan)
    if not plan then
        return
    end

    local scrollChild = planEditorFrame.scrollChild
    local stepButtons = planEditorFrame.stepButtons

    -- Clear existing buttons
    for _, btn in ipairs(stepButtons) do
        btn:Hide()
    end

    -- Create/update step buttons
    local yOffset = 0
    for i, step in ipairs(plan.steps) do
        local btn = stepButtons[i]

        if not btn then
            btn = CreateStepButton(i)
            table.insert(stepButtons, btn)
        end

        btn:SetPoint("TOPLEFT", 5, -yOffset)
        btn:Show()

        btn.orderText:SetText(step.order .. ".")
        btn.spellText:SetText(step.spellName)
        btn.casterText:SetText(step.caster or "Anyone")

        -- Check if caster is available
        local isAvailable = false
        if not step.caster then
            -- "Anyone" means always available
            isAvailable = true
        else
            local casterName = step.caster
            local playerName = UnitName("player")

            -- Check if it's the player
            if casterName == playerName then
                isAvailable = true
            elseif IsInRaid() then
                -- Check raid members
                for i = 1, GetNumGroupMembers() do
                    if UnitName("raid" .. i) == casterName then
                        isAvailable = true
                        break
                    end
                end
            elseif IsInGroup() then
                -- Check party members
                for i = 1, GetNumSubgroupMembers() do
                    if UnitName("party" .. i) == casterName then
                        isAvailable = true
                        break
                    end
                end
            end
        end

        -- Set availability icon
        if isAvailable then
            -- Green checkmark - using WoW's ready check icon
            btn.availIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
        else
            -- Red X - using WoW's ready check icon
            btn.availIcon:SetTexture("Interface\\RaidFrame\\ReadyCheck-NotReady")
        end

        -- Set spell icon
        local spellId = nil
        for _, spell in ipairs(AVAILABLE_SPELLS) do
            if spell.name == step.spellName then
                spellId = spell.id
                break
            end
        end
        if spellId then
            local texture = GetSpellTexture(spellId)
            if texture then
                btn.spellIcon:SetTexture(texture)
            end
        end

        -- Edit button
        btn.editButton:SetScript("OnClick", function()
            PlanUI.ShowEditStepDialog(i, step)
        end)

        -- Delete button
        btn.deleteButton:SetScript("OnClick", function()
            NordensParis_PlanManager.RemoveStep(currentPlan, i)
            PlanUI.RefreshPlanEditor()
        end)

        -- Move up button
        btn.upButton:SetScript("OnClick", function()
            NordensParis_PlanManager.MoveStep(currentPlan, i, "up")
            PlanUI.RefreshPlanEditor()
        end)

        -- Move down button
        btn.downButton:SetScript("OnClick", function()
            NordensParis_PlanManager.MoveStep(currentPlan, i, "down")
            PlanUI.RefreshPlanEditor()
        end)

        yOffset = yOffset + 55
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))

    -- Hide scrollbar if content fits
    local scrollBar = planEditorFrame.scrollFrame.ScrollBar
    if scrollBar then
        if yOffset <= planEditorFrame.scrollFrame:GetHeight() then
            scrollBar:Hide()
        else
            scrollBar:Show()
        end
    end
end

-- Show add step dialog
function PlanUI.ShowAddStepDialog()
    -- Create custom dialog frame
    local dialog = CreateFrame("Frame", "NordensParisAddStepDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(350, 220)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetClampedToScreen(true)

    -- Title
    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", 0, -5)
    dialog.title:SetText("Add Step")

    -- Caster name label
    local casterLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    casterLabel:SetPoint("TOPLEFT", 20, -35)
    casterLabel:SetText("Caster Name:")

    -- Caster name editbox with autocomplete
    local casterEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    casterEditBox:SetSize(250, 25)
    casterEditBox:SetPoint("TOPLEFT", 20, -55)
    casterEditBox:SetAutoFocus(false)
    casterEditBox:SetMaxLetters(50)

    -- Create autocomplete dropdown
    local autocompleteFrame = CreateFrame("Frame", nil, dialog)
    autocompleteFrame:SetSize(250, 80)
    autocompleteFrame:SetPoint("TOPLEFT", casterEditBox, "BOTTOMLEFT", 0, -2)
    autocompleteFrame:SetFrameStrata("TOOLTIP")
    autocompleteFrame:Hide()

    local autocompleteBg = autocompleteFrame:CreateTexture(nil, "BACKGROUND")
    autocompleteBg:SetAllPoints()
    autocompleteBg:SetColorTexture(0, 0, 0, 0.9)

    -- Autocomplete buttons
    local autocompleteButtons = {}
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, autocompleteFrame)
        btn:SetSize(250, 20)
        btn:SetPoint("TOPLEFT", 0, -(i-1) * 20)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 5, 0)
        btn.text:SetJustifyH("LEFT")

        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(0.3, 0.3, 0.8, 0.5)

        btn:SetScript("OnClick", function(self)
            casterEditBox:SetText(self.text:GetText())
            autocompleteFrame:Hide()
        end)

        btn:Hide()
        autocompleteButtons[i] = btn
    end

    -- Function to update autocomplete suggestions
    local function UpdateAutocomplete(text)
        if not text or text == "" then
            autocompleteFrame:Hide()
            return
        end

        local members = NordensParis_Utils.GetGroupMembers()
        local matches = {}
        local lowerText = string.lower(text)

        for _, name in ipairs(members) do
            if string.find(string.lower(name), lowerText, 1, true) then
                table.insert(matches, name)
            end
        end

        if #matches == 0 then
            autocompleteFrame:Hide()
            return
        end

        -- Update buttons
        for i = 1, 4 do
            if matches[i] then
                autocompleteButtons[i].text:SetText(matches[i])
                autocompleteButtons[i]:Show()
            else
                autocompleteButtons[i]:Hide()
            end
        end

        autocompleteFrame:Show()
    end

    casterEditBox:SetScript("OnTextChanged", function(self)
        UpdateAutocomplete(self:GetText())
    end)

    casterEditBox:SetScript("OnEditFocusLost", function(self)
        -- Delay hide to allow button clicks
        C_Timer.After(0.2, function()
            autocompleteFrame:Hide()
        end)
    end)

    casterEditBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() ~= "" then
            UpdateAutocomplete(self:GetText())
        end
    end)

    -- Spell label
    local spellLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", 20, -90)
    spellLabel:SetText("Spell:")

    -- Spell dropdown
    local spellDropdown = CreateFrame("Frame", "NordensParisSpellDropdown", dialog, "UIDropDownMenuTemplate")
    spellDropdown:SetPoint("TOPLEFT", 5, -105)

    local selectedSpell = AVAILABLE_SPELLS[1]

    UIDropDownMenu_SetWidth(spellDropdown, 250)
    UIDropDownMenu_Initialize(spellDropdown, function(self, level)
        for _, spell in ipairs(AVAILABLE_SPELLS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spell.name
            info.value = spell
            info.func = function(btn)
                selectedSpell = btn.value
                UIDropDownMenu_SetText(spellDropdown, btn.value.name)
            end

            -- Add icon
            local texture = GetSpellTexture(spell.id)
            if texture then
                info.icon = texture
                info.tCoordLeft = 0.08
                info.tCoordRight = 0.92
                info.tCoordTop = 0.08
                info.tCoordBottom = 0.92
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Set initial text
    UIDropDownMenu_SetText(spellDropdown, AVAILABLE_SPELLS[1].name)

    -- Add button
    local addButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    addButton:SetSize(100, 25)
    addButton:SetPoint("BOTTOMRIGHT", -20, 15)
    addButton:SetText("Add")
    addButton:SetScript("OnClick", function()
        if currentPlan and selectedSpell then
            local casterName = casterEditBox:GetText()
            if casterName == "" then
                casterName = nil
            end
            local plan = NordensParis_PlanManager.GetPlan(currentPlan)
            local nextOrder = plan and (#plan.steps + 1) or 1
            NordensParis_PlanManager.AddStep(currentPlan, nextOrder, selectedSpell.name, casterName)
            PlanUI.RefreshPlanEditor()
            dialog:Hide()
        end
    end)

    -- Cancel button
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 25)
    cancelButton:SetPoint("RIGHT", addButton, "LEFT", -5, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    -- Close button
    dialog.CloseButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end

-- Show edit step dialog
function PlanUI.ShowEditStepDialog(stepIndex, step)
    -- Create custom dialog frame
    local dialog = CreateFrame("Frame", "NordensParisEditStepDialog", UIParent, "BasicFrameTemplateWithInset")
    dialog:SetSize(350, 220)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("DIALOG")
    dialog:SetMovable(true)
    dialog:EnableMouse(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dialog:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    dialog:SetClampedToScreen(true)

    -- Title
    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dialog.title:SetPoint("TOP", 0, -5)
    dialog.title:SetText("Edit Step " .. stepIndex)

    -- Caster name label
    local casterLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    casterLabel:SetPoint("TOPLEFT", 20, -35)
    casterLabel:SetText("Caster Name:")

    -- Caster name editbox with autocomplete
    local casterEditBox = CreateFrame("EditBox", nil, dialog, "InputBoxTemplate")
    casterEditBox:SetSize(250, 25)
    casterEditBox:SetPoint("TOPLEFT", 20, -55)
    casterEditBox:SetAutoFocus(false)
    casterEditBox:SetMaxLetters(50)
    casterEditBox:SetText(step.caster or "")

    -- Create autocomplete dropdown
    local autocompleteFrame = CreateFrame("Frame", nil, dialog)
    autocompleteFrame:SetSize(250, 80)
    autocompleteFrame:SetPoint("TOPLEFT", casterEditBox, "BOTTOMLEFT", 0, -2)
    autocompleteFrame:SetFrameStrata("TOOLTIP")
    autocompleteFrame:Hide()

    local autocompleteBg = autocompleteFrame:CreateTexture(nil, "BACKGROUND")
    autocompleteBg:SetAllPoints()
    autocompleteBg:SetColorTexture(0, 0, 0, 0.9)

    -- Autocomplete buttons
    local autocompleteButtons = {}
    for i = 1, 4 do
        local btn = CreateFrame("Button", nil, autocompleteFrame)
        btn:SetSize(250, 20)
        btn:SetPoint("TOPLEFT", 0, -(i-1) * 20)

        btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        btn.text:SetPoint("LEFT", 5, 0)
        btn.text:SetJustifyH("LEFT")

        btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
        btn.highlight:SetAllPoints()
        btn.highlight:SetColorTexture(0.3, 0.3, 0.8, 0.5)

        btn:SetScript("OnClick", function(self)
            casterEditBox:SetText(self.text:GetText())
            autocompleteFrame:Hide()
        end)

        btn:Hide()
        autocompleteButtons[i] = btn
    end

    -- Function to update autocomplete suggestions
    local function UpdateAutocomplete(text)
        if not text or text == "" then
            autocompleteFrame:Hide()
            return
        end

        local members = NordensParis_Utils.GetGroupMembers()
        local matches = {}
        local lowerText = string.lower(text)

        for _, name in ipairs(members) do
            if string.find(string.lower(name), lowerText, 1, true) then
                table.insert(matches, name)
            end
        end

        if #matches == 0 then
            autocompleteFrame:Hide()
            return
        end

        -- Update buttons
        for i = 1, 4 do
            if matches[i] then
                autocompleteButtons[i].text:SetText(matches[i])
                autocompleteButtons[i]:Show()
            else
                autocompleteButtons[i]:Hide()
            end
        end

        autocompleteFrame:Show()
    end

    casterEditBox:SetScript("OnTextChanged", function(self)
        UpdateAutocomplete(self:GetText())
    end)

    casterEditBox:SetScript("OnEditFocusLost", function(self)
        -- Delay hide to allow button clicks
        C_Timer.After(0.2, function()
            autocompleteFrame:Hide()
        end)
    end)

    casterEditBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() ~= "" then
            UpdateAutocomplete(self:GetText())
        end
    end)

    -- Spell label
    local spellLabel = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spellLabel:SetPoint("TOPLEFT", 20, -90)
    spellLabel:SetText("Spell:")

    -- Spell dropdown
    local spellDropdown = CreateFrame("Frame", "NordensParisSpellDropdownEdit", dialog, "UIDropDownMenuTemplate")
    spellDropdown:SetPoint("TOPLEFT", 5, -105)

    -- Find current spell or default to first
    local selectedSpell = {value = AVAILABLE_SPELLS[1]}
    for _, spell in ipairs(AVAILABLE_SPELLS) do
        if spell.name == step.spellName then
            selectedSpell.value = spell
            break
        end
    end

    UIDropDownMenu_SetWidth(spellDropdown, 250)
    UIDropDownMenu_Initialize(spellDropdown, function(self, level)
        for _, spell in ipairs(AVAILABLE_SPELLS) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = spell.name
            info.value = spell
            info.func = function(btn)
                selectedSpell.value = btn.value
                UIDropDownMenu_SetText(spellDropdown, btn.value.name)
            end

            -- Add checkmark for selected spell
            info.checked = (spell.name == selectedSpell.value.name)

            -- Add icon
            local texture = GetSpellTexture(spell.id)
            if texture then
                info.icon = texture
                info.tCoordLeft = 0.08
                info.tCoordRight = 0.92
                info.tCoordTop = 0.08
                info.tCoordBottom = 0.92
            end

            UIDropDownMenu_AddButton(info, level)
        end
    end)

    -- Set initial text
    UIDropDownMenu_SetText(spellDropdown, selectedSpell.value.name)

    -- Save button
    local saveButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    saveButton:SetSize(100, 25)
    saveButton:SetPoint("BOTTOMRIGHT", -20, 15)
    saveButton:SetText("Save")
    saveButton:SetScript("OnClick", function()
        if currentPlan and selectedSpell.value then
            local casterName = casterEditBox:GetText()
            if casterName == "" then
                casterName = nil
            end
            NordensParis_PlanManager.UpdateStep(currentPlan, stepIndex, step.order, selectedSpell.value.name, casterName)
            PlanUI.RefreshPlanEditor()
            dialog:Hide()
        end
    end)

    -- Cancel button
    local cancelButton = CreateFrame("Button", nil, dialog, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 25)
    cancelButton:SetPoint("RIGHT", saveButton, "LEFT", -5, 0)
    cancelButton:SetText("Cancel")
    cancelButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    -- Close button
    dialog.CloseButton:SetScript("OnClick", function()
        dialog:Hide()
    end)

    dialog:Show()
end

-- Show rename plan dialog
function PlanUI.ShowRenamePlanDialog()
    if not currentPlan then
        return
    end

    StaticPopupDialogs["NORDENSPARIS_RENAME_PLAN"] = {
        text = "Enter new name for plan '" .. currentPlan .. "':",
        button1 = "Rename",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetText(currentPlan)
            end
        end,
        OnAccept = function(self, data)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox and currentPlan then
                local newName = editBox:GetText()
                if newName and newName ~= "" and newName ~= currentPlan then
                    local success, err = NordensParis_PlanManager.RenamePlan(currentPlan, newName)
                    if success then
                        currentPlan = newName
                        planEditorFrame.titleText:SetText(newName)
                        print("|cff00ff80Nordens Paris:|r Plan renamed to '" .. newName .. "'")
                    else
                        print("|cff00ff80Nordens Paris:|r " .. err)
                    end
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("NORDENSPARIS_RENAME_PLAN")
end

-- Share a plan
function PlanUI.SharePlan(planName)
    if not NordensParis_AddonComm or not NordensParis_PlanManager then
        return
    end

    local exportData = NordensParis_PlanManager.ExportPlan(planName)
    if exportData then
        NordensParis_AddonComm.SharePlan(exportData)
    else
        print("|cff00ff80Nordens Paris:|r Failed to share plan")
    end
end

-- Delete a plan
function PlanUI.DeletePlan(planName)
    StaticPopupDialogs["NORDENSPARIS_DELETE_PLAN"] = {
        text = "Delete plan '" .. planName .. "'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            if NordensParis_PlanManager.DeletePlan(planName) then
                PlanUI.RefreshPlanList()
                print("|cff00ff80Nordens Paris:|r Plan deleted")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("NORDENSPARIS_DELETE_PLAN")
end

-- Activate a plan (delegate to ActivePlan module)
function PlanUI.ActivatePlan(planName)
    if NordensParis_ActivePlan then
        -- Initialize with database if not already done
        if NordensParisCharDB then
            NordensParis_ActivePlan.Initialize(NordensParisCharDB)
        end
        NordensParis_ActivePlan.Activate(planName)
    end
end

-- Show received plans
function PlanUI.ShowReceivedPlans()
    print("|cff00ff80Nordens Paris:|r Received plans view")
    print("  This feature will be available in the next update")

    if NordensParis_AddonComm then
        local receivedPlans = NordensParis_AddonComm.GetReceivedPlans()
        if next(receivedPlans) then
            for sender, plans in pairs(receivedPlans) do
                print("  From " .. sender .. ":")
                for planName, plan in pairs(plans) do
                    print("    - " .. planName .. " (" .. #plan.steps .. " steps)")
                end
            end
        else
            print("  No plans received yet")
        end
    end
end

-- Toggle main frame visibility
function PlanUI.Toggle()
    if not mainFrame then
        PlanUI.CreateMainFrame()
    end

    if mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        PlanUI.ShowPlanList()
    end
end

-- Export the module
NordensParis_PlanUI = PlanUI
