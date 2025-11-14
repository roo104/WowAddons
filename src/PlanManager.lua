-- PlanManager: Cooldown rotation plan storage and management
-- Compatible with WoW Classic MoP

---@diagnostic disable: undefined-global

-- Module table
local PlanManager = {}

-- Default saved variable will be initialized in NordensParis.lua
local savedPlans = nil

-- Initialize plan storage
function PlanManager.Initialize(db)
    savedPlans = db.plans or {}
    db.plans = savedPlans
end

-- Create a new plan
function PlanManager.CreatePlan(planName)
    if not planName or planName == "" then
        return nil, "Plan name cannot be empty"
    end

    if savedPlans[planName] then
        return nil, "Plan already exists"
    end

    savedPlans[planName] = {
        name = planName,
        steps = {},
        created = time(),
        modified = time(),
        author = UnitName("player")
    }

    return savedPlans[planName]
end

-- Delete a plan
function PlanManager.DeletePlan(planName)
    if not savedPlans[planName] then
        return false, "Plan not found"
    end

    savedPlans[planName] = nil
    return true
end

-- Get a plan by name
function PlanManager.GetPlan(planName)
    return savedPlans[planName]
end

-- Get all plans
function PlanManager.GetAllPlans()
    return savedPlans
end

-- Add a step to a plan
function PlanManager.AddStep(planName, order, spellName, caster)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    local step = {
        order = order or (#plan.steps + 1),
        spellName = spellName,
        caster = caster, -- Can be nil for "Any healer"
        completed = false
    }

    table.insert(plan.steps, step)

    -- Sort steps by order
    table.sort(plan.steps, function(a, b)
        return a.order < b.order
    end)

    plan.modified = time()
    return true
end

-- Remove a step from a plan
function PlanManager.RemoveStep(planName, stepIndex)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    if stepIndex < 1 or stepIndex > #plan.steps then
        return false, "Invalid step index"
    end

    table.remove(plan.steps, stepIndex)

    -- Renumber all steps
    for i, step in ipairs(plan.steps) do
        step.order = i
    end

    plan.modified = time()
    return true
end

-- Update a step in a plan
function PlanManager.UpdateStep(planName, stepIndex, order, spellName, caster)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    if stepIndex < 1 or stepIndex > #plan.steps then
        return false, "Invalid step index"
    end

    local step = plan.steps[stepIndex]
    step.order = order or step.order
    step.spellName = spellName or step.spellName
    step.caster = caster

    -- Sort steps by order
    table.sort(plan.steps, function(a, b)
        return a.order < b.order
    end)

    plan.modified = time()
    return true
end

-- Mark a step as completed
function PlanManager.MarkStepCompleted(planName, stepIndex, completed)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    if stepIndex < 1 or stepIndex > #plan.steps then
        return false, "Invalid step index"
    end

    plan.steps[stepIndex].completed = completed
    return true
end

-- Move a step up or down in the plan
function PlanManager.MoveStep(planName, stepIndex, direction)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    if stepIndex < 1 or stepIndex > #plan.steps then
        return false, "Invalid step index"
    end

    local targetIndex
    if direction == "up" then
        if stepIndex == 1 then
            return false, "Already at top"
        end
        targetIndex = stepIndex - 1
    elseif direction == "down" then
        if stepIndex == #plan.steps then
            return false, "Already at bottom"
        end
        targetIndex = stepIndex + 1
    else
        return false, "Invalid direction"
    end

    -- Swap the steps
    local temp = plan.steps[stepIndex]
    plan.steps[stepIndex] = plan.steps[targetIndex]
    plan.steps[targetIndex] = temp

    -- Renumber all steps
    for i, step in ipairs(plan.steps) do
        step.order = i
    end

    plan.modified = time()
    return true
end

-- Reset all steps to incomplete
function PlanManager.ResetPlan(planName)
    local plan = savedPlans[planName]
    if not plan then
        return false, "Plan not found"
    end

    for _, step in ipairs(plan.steps) do
        step.completed = false
    end

    return true
end

-- Import a plan from another player
function PlanManager.ImportPlan(planData, overwrite)
    local planName = planData.planName or planData.name

    if not planName then
        return false, "Invalid plan data"
    end

    if savedPlans[planName] and not overwrite then
        return false, "Plan already exists (use overwrite=true to replace)"
    end

    savedPlans[planName] = {
        name = planName,
        steps = {},
        created = time(),
        modified = time(),
        author = planData.sender or "Unknown",
        imported = true
    }

    -- Copy steps
    for _, step in ipairs(planData.steps or {}) do
        table.insert(savedPlans[planName].steps, {
            order = step.order,
            spellName = step.spellName,
            caster = step.caster,
            completed = false
        })
    end

    return true
end

-- Export a plan for sharing
function PlanManager.ExportPlan(planName)
    local plan = savedPlans[planName]
    if not plan then
        return nil, "Plan not found"
    end

    return {
        planName = plan.name,
        steps = plan.steps
    }
end

-- Get plan summary (for display)
function PlanManager.GetPlanSummary(planName)
    local plan = savedPlans[planName]
    if not plan then
        return nil
    end

    local summary = {
        name = plan.name,
        stepCount = #plan.steps,
        completedCount = 0,
        author = plan.author,
        created = plan.created,
        modified = plan.modified
    }

    for _, step in ipairs(plan.steps) do
        if step.completed then
            summary.completedCount = summary.completedCount + 1
        end
    end

    return summary
end

-- Duplicate a plan
function PlanManager.DuplicatePlan(sourceName, newName)
    local source = savedPlans[sourceName]
    if not source then
        return false, "Source plan not found"
    end

    if savedPlans[newName] then
        return false, "Destination plan already exists"
    end

    savedPlans[newName] = {
        name = newName,
        steps = {},
        created = time(),
        modified = time(),
        author = UnitName("player")
    }

    -- Copy steps
    for _, step in ipairs(source.steps) do
        table.insert(savedPlans[newName].steps, {
            order = step.order,
            spellName = step.spellName,
            caster = step.caster,
            completed = false
        })
    end

    return true
end

-- Rename a plan
function PlanManager.RenamePlan(oldName, newName)
    if not savedPlans[oldName] then
        return false, "Plan not found"
    end

    if savedPlans[newName] then
        return false, "A plan with the new name already exists"
    end

    savedPlans[newName] = savedPlans[oldName]
    savedPlans[newName].name = newName
    savedPlans[newName].modified = time()
    savedPlans[oldName] = nil

    return true
end

-- Export the module
NordensParis_PlanManager = PlanManager
