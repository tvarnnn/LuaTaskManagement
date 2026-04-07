-- history.lua
-- Tracks completed and deleted tasks so the user can review them later.
-- History entries are persisted to history_data.lua alongside tasks_data.lua.
--
-- Each history entry is a table with the following fields:
--   id          (number)  : the original task id
--   name        (string)  : task name
--   due_date    (string)  : due date in YYYY-MM-DD format, or ""
--   description (string)  : optional description
--   priority    (number)  : 1 = High, 2 = Medium, 3 = Low
--   action      (string)  : "completed" or "deleted"
--   timestamp   (string)  : date/time when the action was taken (os.date)

local history = {}

local log = {}   -- in-memory history list

local FILE = "history_data.lua"

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- now()
-- Returns the current local date and time as a readable string.
local function now()
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- ─── Public API ──────────────────────────────────────────────────────────────

-- history.record(task, action)
-- Appends a copy of the task table to the in-memory log with an action label
-- and the current timestamp.  Call this BEFORE deleting or completing the task
-- in task_manager so all fields are still available.
--
-- Parameters:
--   task   (table)  : a task table from task_manager (id, name, due_date, …)
--   action (string) : "completed" or "deleted"
function history.record(task, action)
    table.insert(log, {
        id          = task.id,
        name        = task.name,
        due_date    = task.due_date,
        description = task.description,
        priority    = task.priority,
        action      = action,
        timestamp   = now(),
    })
end

-- history.get_all()
-- Returns the full in-memory history list (most recent last).
function history.get_all()
    return log
end

-- history.get_by_action(action)
-- Returns a filtered list of entries matching the given action string.
-- Useful for showing only "completed" or only "deleted" entries.
function history.get_by_action(action)
    local result = {}
    for _, entry in ipairs(log) do
        if entry.action == action then
            table.insert(result, entry)
        end
    end
    return result
end

-- history.remove_entry(index)
-- Removes a single entry from the log by its position in the list.
-- Called after a successful undo so the entry doesn't linger in history.
function history.remove_entry(index)
    table.remove(log, index)
end

-- history.clear()
-- Wipes the in-memory log and overwrites the file with an empty table.
-- Exposed so the user can optionally clear history from the menu.
function history.clear()
    log = {}
    history.save()
end

-- ─── Persistence ─────────────────────────────────────────────────────────────

-- history.save()
-- Writes the current in-memory log to FILE as a plain Lua table literal.
-- Uses the same format as storage.lua so it can be loaded with dofile().
function history.save()
    local file = io.open(FILE, "w")
    if not file then
        print("Warning: could not open " .. FILE .. " for writing")
        return
    end
    file:write("return {\n")
    for _, e in ipairs(log) do
        file:write(string.format(
            "  {id=%d, name=%q, due_date=%q, description=%q, priority=%d, action=%q, timestamp=%q},\n",
            e.id, e.name, e.due_date, e.description, e.priority, e.action, e.timestamp
        ))
    end
    file:write("}\n")
    file:close()
end

-- history.load()
-- Reads FILE with dofile() and restores the in-memory log.
-- Returns silently on first run or if the file is missing/corrupted.
function history.load()
    local ok, data = pcall(dofile, FILE)
    if ok and type(data) == "table" then
        log = data
    else
        log = {}   -- first run or corrupted file — start fresh
    end
end

return history
