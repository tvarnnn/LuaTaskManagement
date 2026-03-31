-- storage.lua
-- Handles reading and writing task data to a local file.
-- Tasks are persisted as a plain Lua table literal so the file can be
-- loaded back with dofile() — no external parser or format needed.

local storage = {}

-- Path to the data file, relative to wherever the server is launched from.
local FILE = "tasks_data.lua"

-- storage.save(task_list)
-- Serializes the entire task list to FILE as a Lua table literal.
-- Each task is written as a row with all fields explicitly named,
-- using %q for strings to safely escape quotes and special characters.
function storage.save(task_list)
    local file = io.open(FILE, "w")
    if not file then
        -- Non-fatal: warn and continue — in-memory state is still valid
        print("Warning: could not open " .. FILE .. " for writing")
        return
    end
    file:write("return {\n")
    for _, t in ipairs(task_list) do
        -- %q wraps strings in quotes and escapes any special characters automatically
        file:write(string.format(
            "  {id=%d, name=%q, due_date=%q, description=%q, status=%q, priority=%d},\n",
            t.id, t.name, t.due_date, t.description, t.status, t.priority
        ))
    end
    file:write("}\n")
    file:close()
end

-- storage.load()
-- Reads and executes FILE using dofile(), which returns the Lua table literal.
-- pcall wraps the call so a missing or malformed file returns an empty table
-- instead of crashing the server on first run.
function storage.load()
    local ok, data = pcall(dofile, FILE)
    if ok and type(data) == "table" then
        return data
    end
    return {}  -- first run or corrupted file — start fresh
end

return storage
