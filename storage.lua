-- storage.lua
-- Handles saving and loading tasks to/from a file using LOVE's filesystem

local storage = {}

local FILE = "tasks.lua"

function storage.save(task_list)
    local lines = { "return {\n" }
    for _, t in ipairs(task_list) do
        table.insert(lines, string.format(
            "  {id=%d, name=%q, due_date=%q, description=%q, status=%q, priority=%d},\n",
            t.id, t.name, t.due_date, t.description, t.status, t.priority
        ))
    end
    table.insert(lines, "}\n")
    love.filesystem.write(FILE, table.concat(lines))
end

function storage.load()
    if not love.filesystem.getInfo(FILE) then
        return {}
    end
    local content = love.filesystem.read(FILE)
    if not content then return {} end

    local fn, err = load(content)
    if fn then
        local ok, data = pcall(fn)
        if ok and type(data) == "table" then
            return data
        end
    end
    return {}
end

return storage
