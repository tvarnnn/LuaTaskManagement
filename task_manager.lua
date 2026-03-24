-- tasks.lua
-- Manages the in-memory task list and all CRUD operations

local tasks = {}
local task_list = {}
local next_id = 1

function tasks.add(name, due_date, description, priority)
    table.insert(task_list, {
        id          = next_id,
        name        = name,
        due_date    = due_date,
        description = description,
        status      = "pending",
        priority    = priority or 2  -- 1=High, 2=Medium, 3=Low
    })
    next_id = next_id + 1
end

function tasks.delete(id)
    for i, t in ipairs(task_list) do
        if t.id == id then
            table.remove(task_list, i)
            return
        end
    end
end

function tasks.complete(id)
    for _, t in ipairs(task_list) do
        if t.id == id then
            t.status = "done"
            return
        end
    end
end

function tasks.get_all()
    return task_list
end

-- Returns a copy of the task list sorted by priority (high first), then by id
function tasks.get_sorted()
    local sorted = {}
    for _, t in ipairs(task_list) do
        table.insert(sorted, t)
    end
    table.sort(sorted, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority
        end
        return a.id < b.id
    end)
    return sorted
end

-- Called on startup to populate from saved data
function tasks.load_tasks(data)
    task_list = data
    next_id = 1
    for _, t in ipairs(task_list) do
        if t.id >= next_id then
            next_id = t.id + 1
        end
    end
end

return tasks
