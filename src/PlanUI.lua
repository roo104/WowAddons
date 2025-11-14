-- PlanUI: User interface for creating, editing, and viewing cooldown plans
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

local PlanUI = {}

-- UI Elements
local mainFrame = nil
local planListFrame = nil
local planEditorFrame = nil
local planViewerFrame = nil
local currentPlan = nil

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

    mainFrame = CreateFrame("Frame", "RooMonkPlanFrame", UIParent, "BasicFrameTemplateWithInset")
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
    mainFrame.title:SetText("RooMonk - Cooldown Plans")

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
    local tab1 = CreateFrame("Button", "RooMonkPlanTab1", parent, "PanelTabButtonTemplate")
    tab1:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 5, -28)
    tab1:SetText("My Plans")
    tab1:SetScript("OnClick", function()
        PanelTemplates_SetTab(parent, 1)
        PlanUI.ShowPlanList()
    end)
    table.insert(tabs, tab1)

    -- Tab 2: Received Plans
    local tab2 = CreateFrame("Button", "RooMonkPlanTab2", parent, "PanelTabButtonTemplate")
    tab2:SetPoint("LEFT", tab1, "RIGHT", -15, 0)
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

    planListFrame = CreateFrame("Frame", "RooMonkPlanList", mainFrame)
    planListFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 10, -30)
    planListFrame:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -10, 10)

    -- Scroll frame for plans
    local scrollFrame = CreateFrame("ScrollFrame", "RooMonkPlanListScroll", planListFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -25, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 1)
    scrollFrame:SetScrollChild(scrollChild)

    planListFrame.scrollChild = scrollChild
    planListFrame.planButtons = {}

    -- New plan button
    local newPlanButton = CreateFrame("Button", "RooMonkNewPlanButton", planListFrame, "UIPanelButtonTemplate")
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

    -- Hide other frames
    if planEditorFrame then planEditorFrame:Hide() end
    if planViewerFrame then planViewerFrame:Hide() end

    planListFrame:Show()
    PlanUI.RefreshPlanList()
end

-- Refresh plan list display
function PlanUI.RefreshPlanList()
    if not planListFrame or not RooMonk_PlanManager then
        return
    end

    local scrollChild = planListFrame.scrollChild
    local plans = RooMonk_PlanManager.GetAllPlans()

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
            btn.infoText:SetPoint("TOPLEFT", 10, -25)
            btn.infoText:SetJustifyH("LEFT")
            btn.infoText:SetTextColor(0.7, 0.7, 0.7)

            -- Edit button
            btn.editButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.editButton:SetSize(60, 20)
            btn.editButton:SetPoint("TOPRIGHT", -10, -5)
            btn.editButton:SetText("Edit")

            -- Share button
            btn.shareButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.shareButton:SetSize(60, 20)
            btn.shareButton:SetPoint("TOPRIGHT", -75, -5)
            btn.shareButton:SetText("Share")

            -- Delete button
            btn.deleteButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
            btn.deleteButton:SetSize(60, 20)
            btn.deleteButton:SetPoint("TOPRIGHT", -140, -5)
            btn.deleteButton:SetText("Delete")

            table.insert(planListFrame.planButtons, btn)
        end

        btn:SetPoint("TOPLEFT", 10, -yOffset)
        btn:Show()

        local summary = RooMonk_PlanManager.GetPlanSummary(planName)
        btn.nameText:SetText(planName)
        btn.infoText:SetText(string.format("%d steps | %d completed | by %s",
            summary.stepCount, summary.completedCount, summary.author or "Unknown"))

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

        yOffset = yOffset + 65
        index = index + 1
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Show new plan dialog
function PlanUI.ShowNewPlanDialog()
    StaticPopupDialogs["ROOMONK_NEW_PLAN"] = {
        text = "Enter a name for the new plan:",
        button1 = "Create",
        button2 = "Cancel",
        hasEditBox = true,
        OnAccept = function(self, data)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                local planName = editBox:GetText()
                if planName and planName ~= "" then
                    local plan, err = RooMonk_PlanManager.CreatePlan(planName)
                    if plan then
                        PlanUI.RefreshPlanList()
                        PlanUI.EditPlan(planName)
                    else
                        print("|cff00ff80RooMonk:|r " .. err)
                    end
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ROOMONK_NEW_PLAN")
end

-- Create plan editor frame
function PlanUI.CreatePlanEditorFrame()
    if planEditorFrame then
        return planEditorFrame
    end

    planEditorFrame = CreateFrame("Frame", "RooMonkPlanEditor", mainFrame)
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

    -- Scroll frame for steps
    local scrollFrame = CreateFrame("ScrollFrame", "RooMonkPlanEditorScroll", planEditorFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 40)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(430, 1)
    scrollFrame:SetScrollChild(scrollChild)

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

    -- Spell name
    btn.spellText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.spellText:SetPoint("LEFT", 40, 5)
    btn.spellText:SetJustifyH("LEFT")

    -- Caster name
    btn.casterText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.casterText:SetPoint("LEFT", 40, -10)
    btn.casterText:SetJustifyH("LEFT")
    btn.casterText:SetTextColor(0.7, 0.7, 0.7)

    -- Checkbox for completion
    btn.checkBox = CreateFrame("CheckButton", nil, btn, "UICheckButtonTemplate")
    btn.checkBox:SetSize(24, 24)
    btn.checkBox:SetPoint("RIGHT", -140, 0)

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
    btn.upButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
    btn.upButton:SetSize(20, 20)
    btn.upButton:SetPoint("RIGHT", -180, 10)
    btn.upButton:SetText("^")

    -- Move down button
    btn.downButton = CreateFrame("Button", nil, btn, "UIPanelButtonTemplate")
    btn.downButton:SetSize(20, 20)
    btn.downButton:SetPoint("RIGHT", -180, -10)
    btn.downButton:SetText("v")

    btn:Hide()
    return btn
end

-- Edit a plan
function PlanUI.EditPlan(planName)
    if not RooMonk_PlanManager then
        return
    end

    local plan = RooMonk_PlanManager.GetPlan(planName)
    if not plan then
        print("|cff00ff80RooMonk:|r Plan not found: " .. planName)
        return
    end

    currentPlan = planName

    if not planEditorFrame then
        PlanUI.CreatePlanEditorFrame()
    end

    -- Hide other frames
    if planListFrame then planListFrame:Hide() end
    if planViewerFrame then planViewerFrame:Hide() end

    planEditorFrame:Show()
    planEditorFrame.titleText:SetText("Edit: " .. planName)

    PlanUI.RefreshPlanEditor()
end

-- Refresh plan editor display
function PlanUI.RefreshPlanEditor()
    if not planEditorFrame or not currentPlan or not RooMonk_PlanManager then
        return
    end

    local plan = RooMonk_PlanManager.GetPlan(currentPlan)
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
        btn.casterText:SetText(step.caster and ("by " .. step.caster) or "by Anyone")

        -- Checkbox
        btn.checkBox:SetChecked(step.completed)
        btn.checkBox:SetScript("OnClick", function(self)
            RooMonk_PlanManager.MarkStepCompleted(currentPlan, i, self:GetChecked())
        end)

        -- Edit button
        btn.editButton:SetScript("OnClick", function()
            PlanUI.ShowEditStepDialog(i, step)
        end)

        -- Delete button
        btn.deleteButton:SetScript("OnClick", function()
            RooMonk_PlanManager.RemoveStep(currentPlan, i)
            PlanUI.RefreshPlanEditor()
        end)

        -- Move up button
        btn.upButton:SetScript("OnClick", function()
            if i > 1 then
                local prevStep = plan.steps[i-1]
                local tempOrder = step.order
                step.order = prevStep.order
                prevStep.order = tempOrder
                RooMonk_PlanManager.UpdateStep(currentPlan, i, step.order, step.spellName, step.caster)
                RooMonk_PlanManager.UpdateStep(currentPlan, i-1, prevStep.order, prevStep.spellName, prevStep.caster)
                PlanUI.RefreshPlanEditor()
            end
        end)

        -- Move down button
        btn.downButton:SetScript("OnClick", function()
            if i < #plan.steps then
                local nextStep = plan.steps[i+1]
                local tempOrder = step.order
                step.order = nextStep.order
                nextStep.order = tempOrder
                RooMonk_PlanManager.UpdateStep(currentPlan, i, step.order, step.spellName, step.caster)
                RooMonk_PlanManager.UpdateStep(currentPlan, i+1, nextStep.order, nextStep.spellName, nextStep.caster)
                PlanUI.RefreshPlanEditor()
            end
        end)

        yOffset = yOffset + 55
    end

    -- Update scroll child height
    scrollChild:SetHeight(math.max(yOffset, 1))
end

-- Show add step dialog
function PlanUI.ShowAddStepDialog()
    StaticPopupDialogs["ROOMONK_ADD_STEP"] = {
        text = "Add Step\n\nSpell Name:",
        button1 = "Add",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetText("")
            end
        end,
        OnAccept = function(self, data)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox and currentPlan then
                local spellName = editBox:GetText()
                if spellName and spellName ~= "" then
                    local plan = RooMonk_PlanManager.GetPlan(currentPlan)
                    local nextOrder = plan and (#plan.steps + 1) or 1
                    RooMonk_PlanManager.AddStep(currentPlan, nextOrder, spellName, nil)
                    PlanUI.RefreshPlanEditor()
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ROOMONK_ADD_STEP")
end

-- Show edit step dialog
function PlanUI.ShowEditStepDialog(stepIndex, step)
    StaticPopupDialogs["ROOMONK_EDIT_STEP"] = {
        text = "Edit Step " .. stepIndex .. "\n\nSpell Name:",
        button1 = "Save",
        button2 = "Cancel",
        hasEditBox = true,
        OnShow = function(self)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox then
                editBox:SetText(step.spellName)
            end
        end,
        OnAccept = function(self, data)
            local editBox = self.editBox or _G[self:GetName().."EditBox"]
            if editBox and currentPlan then
                local spellName = editBox:GetText()
                if spellName and spellName ~= "" then
                    RooMonk_PlanManager.UpdateStep(currentPlan, stepIndex, step.order, spellName, step.caster)
                    PlanUI.RefreshPlanEditor()
                end
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ROOMONK_EDIT_STEP")
end

-- Share a plan
function PlanUI.SharePlan(planName)
    if not RooMonk_AddonComm or not RooMonk_PlanManager then
        return
    end

    local exportData = RooMonk_PlanManager.ExportPlan(planName)
    if exportData then
        RooMonk_AddonComm.SharePlan(exportData)
    else
        print("|cff00ff80RooMonk:|r Failed to share plan")
    end
end

-- Delete a plan
function PlanUI.DeletePlan(planName)
    StaticPopupDialogs["ROOMONK_DELETE_PLAN"] = {
        text = "Delete plan '" .. planName .. "'?",
        button1 = "Delete",
        button2 = "Cancel",
        OnAccept = function()
            if RooMonk_PlanManager.DeletePlan(planName) then
                PlanUI.RefreshPlanList()
                print("|cff00ff80RooMonk:|r Plan deleted")
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("ROOMONK_DELETE_PLAN")
end

-- Show received plans
function PlanUI.ShowReceivedPlans()
    print("|cff00ff80RooMonk:|r Received plans view")
    print("  This feature will be available in the next update")

    if RooMonk_AddonComm then
        local receivedPlans = RooMonk_AddonComm.GetReceivedPlans()
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
RooMonk_PlanUI = PlanUI
