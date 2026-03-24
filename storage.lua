-- storage.lua
-- Saves and loads tasks to/from a local file using plain Lua io

local storage = {}

local FILE = "tasks_data.lua"

function storage.save(task_list)
    local file = io.open(FILE, "w")
    if not file then
        print("Warning: could not open " .. FILE .. " for writing")
        return
    end
    file:write("return {\n")
    for _, t in ipairs(task_list) do
        file:write(string.format(
            "  {id=%d, name=%q, due_date=%q, description=%q, status=%q, priority=%d},\n",
            t.id, t.name, t.due_date, t.description, t.status, t.priority
        ))
    end
    file:write("}\n")
    file:close()
end

function storage.load()
    local ok, data = pcall(dofile, FILE)
    if ok and type(data) == "table" then
        return data
    end
    return {}
end

return storage
