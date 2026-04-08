-- task_manager.lua
-- In-memory task store and all CRUD operations.
-- Each task is a Lua table (used here as a struct) with the following fields:
--   id          (number)  : unique auto-incremented identifier
--   name        (string)  : short title of the task
--   due_date    (string)  : due date in YYYY-MM-DD format, or "" if not set
--   description (string)  : optional longer description
--   status      (string)  : "pending" or "done"
--   priority    (number)  : 1 = High, 2 = Medium, 3 = Low

local tasks = {}       -- public module table
local task_list = {}   -- internal array of task tables
local next_id = 1      -- auto-increment counter for task IDs

-- tasks.add(name, due_date, description, priority)
-- Creates a new task and appends it to the task list.
-- Priority defaults to 2 (Medium) if not provided.
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

-- tasks.restore(id, name, due_date, description, priority)
-- Re-inserts a previously deleted task using its ORIGINAL id and fields.
-- Status is always reset to "pending" on restore.
-- next_id is advanced only if the restored id would collide with future ids.
function tasks.restore(id, name, due_date, description, priority)
    table.insert(task_list, {
        id          = id,
        name        = name,
        due_date    = due_date,
        description = description,
        status      = "pending",
        priority    = priority or 2
    })
    -- Keep next_id ahead of any restored id to avoid future collisions
    if id >= next_id then
        next_id = id + 1
    end
end

-- tasks.delete(id)
-- Removes the task with the given id from the list.
-- Uses ipairs to iterate with index so we can call table.remove safely.
function tasks.delete(id)
    for i, t in ipairs(task_list) do
        if t.id == id then
            table.remove(task_list, i)
            return
        end
    end
end

-- tasks.complete(id)
-- Marks the task with the given id as "done".
-- Status is stored as a string so it can be compared directly in the UI.
function tasks.complete(id)
    for _, t in ipairs(task_list) do
        if t.id == id then
            t.status = "done"
            return
        end
    end
end

-- tasks.get_all()
-- Returns the raw task list table (by reference).
-- Used when saving to storage so we always write the full current state.
function tasks.get_all()
    return task_list
end

-- tasks.get_sorted()
-- Returns a shallow copy of the task list sorted by priority ascending (1=High first),
-- with ties broken by id ascending so the order is always deterministic.
function tasks.get_sorted()
    local sorted = {}
    for _, t in ipairs(task_list) do
        table.insert(sorted, t)
    end
    -- table.sort uses an in-place comparison function (closure)
    table.sort(sorted, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority  -- lower number = higher priority
        end
        return a.id < b.id  -- stable secondary sort by insertion order
    end)
    return sorted
end

-- tasks.load_tasks(data)
-- Replaces the in-memory task list with data loaded from storage.
-- Also recalculates next_id so new tasks never collide with loaded ones.
function tasks.load_tasks(data)
    task_list = data
    next_id = 1
    for _, t in ipairs(task_list) do
        if t.id >= next_id then
            next_id = t.id + 1
        end
    end
end

-- tasks.getById(id)
-- Returns the task table with the given id, or nil if not found.
function tasks.getById(id)
    for _, t in ipairs(task_list) do
        if t.id == id then
            return t
        end
    end
    return nil
end

-- tasks.update(id, name, due_date, description, priority)
-- Updates the fields of the task with the given id using tasks.getById to find it.
function tasks.update(id, name, due_date, description, priority)
    local task = tasks.getById(id)
    if not task then return end

    task.name = name
    task.due_date = due_date
    task.description = description
    task.priority = priority
end

return tasks
