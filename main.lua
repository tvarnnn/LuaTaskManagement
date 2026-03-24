-- main.lua
-- Entry point — wires everything together

local tasks   = require("task_manager")
local storage = require("storage")
local ui      = require("ui")

function love.load()
    love.window.setTitle("Lua Task Manager")
    love.window.setMode(800, 600, { resizable = false })

    -- Load saved tasks from file
    local saved = storage.load()
    tasks.load_tasks(saved)

    -- Seed some sample tasks if none exist yet
    if #tasks.get_all() == 0 then
        tasks.add("Read Lua documentation",   "2026-03-25", "Cover tables and metatables",  1)
        tasks.add("Build task input form",    "2026-03-27", "Name, date, desc, priority",   2)
        tasks.add("Style the UI",             "2026-03-30", "Colors and layout polish",      3)
        tasks.add("Add file persistence",     "2026-03-26", "Save/load with storage.lua",    1)
        storage.save(tasks.get_all())
    end
end

function love.update(dt)
    ui.update(dt)
end

function love.draw()
    ui.draw()
end

function love.textinput(t)
    ui.textinput(t)
end

function love.keypressed(key)
    ui.keypressed(key)
end

function love.mousepressed(x, y, button)
    ui.mousepressed(x, y, button)
end
