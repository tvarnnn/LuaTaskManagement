-- ui.lua
-- Handles all rendering and user input

local tasks   = require("task_manager")
local storage = require("storage")

local ui = {}

local view     = "list"
local selected = 1

-- Form state
local field_names  = { "name", "due_date", "description" }
local field_labels = { "Name:", "Due Date:", "Description:" }
local field_index  = 1
local form = { name = "", due_date = "", description = "", priority = 2 }

local priority_labels = { "High", "Medium", "Low" }
local priority_colors = {
    { 1,    0.35, 0.35 },  -- red    (High)
    { 1,    0.8,  0    },  -- yellow (Medium)
    { 0.35, 1,    0.35 },  -- green  (Low)
}

-- Mouse state (updated each frame)
local mouse_x, mouse_y = 0, 0

-- Button registry — rebuilt every draw frame so clicks can be checked against it
local btn_reg = {}

-- ─── Button Helpers ──────────────────────────────────────────────────────────

local function draw_btn(id, label, x, y, w, h, style)
    -- Register bounds for click detection
    btn_reg[id] = { x = x, y = y, w = w, h = h }

    local hovered = mouse_x >= x and mouse_x <= x + w and mouse_y >= y and mouse_y <= y + h

    local bg, border
    if style == "primary" then
        bg     = hovered and { 0.28, 0.48, 0.92 } or { 0.18, 0.36, 0.75 }
        border = { 0.5, 0.65, 1 }
    elseif style == "success" then
        bg     = hovered and { 0.18, 0.62, 0.18 } or { 0.12, 0.48, 0.12 }
        border = { 0.35, 1, 0.35 }
    elseif style == "danger" then
        bg     = hovered and { 0.75, 0.2, 0.2 } or { 0.55, 0.12, 0.12 }
        border = { 1, 0.38, 0.38 }
    else  -- default / neutral
        bg     = hovered and { 0.28, 0.28, 0.42 } or { 0.18, 0.18, 0.3 }
        border = { 0.42, 0.42, 0.62 }
    end

    love.graphics.setColor(bg)
    love.graphics.rectangle("fill", x, y, w, h, 5, 5)
    love.graphics.setColor(border)
    love.graphics.rectangle("line", x, y, w, h, 5, 5)

    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local tw = font:getWidth(label)
    local th = font:getHeight()
    love.graphics.print(label, x + (w - tw) / 2, y + (h - th) / 2)
end

local function clicked(id, cx, cy)
    local b = btn_reg[id]
    return b and cx >= b.x and cx <= b.x + b.w and cy >= b.y and cy <= b.y + b.h
end

-- ─── Drawing ─────────────────────────────────────────────────────────────────

function ui.draw()
    love.graphics.clear(0.08, 0.08, 0.12)
    btn_reg = {}

    if view == "list" then
        ui.draw_list()
    else
        ui.draw_form()
    end
end

function ui.draw_list()
    local sorted = tasks.get_sorted()

    -- Header
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("TASK MANAGER", 20, 14)

    draw_btn("new_task", "+ New Task", 668, 8, 114, 30, "primary")

    love.graphics.setColor(0.3, 0.3, 0.42)
    love.graphics.line(10, 46, 790, 46)

    -- Column headers
    love.graphics.setColor(0.45, 0.45, 0.58)
    love.graphics.print("STATUS", 18, 54)
    love.graphics.print("PRIORITY", 58, 54)
    love.graphics.print("NAME", 150, 54)
    love.graphics.print("DUE DATE", 430, 54)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.line(10, 70, 790, 70)

    -- Task rows
    local y = 78
    for i, task in ipairs(sorted) do
        local pc = priority_colors[task.priority]

        -- Row hover / selection highlight
        local row_hovered = mouse_x >= 10 and mouse_x <= 650 and
                            mouse_y >= y - 2 and mouse_y <= y + 26
        if i == selected then
            love.graphics.setColor(0.15, 0.15, 0.26)
            love.graphics.rectangle("fill", 10, y - 2, 780, 28)
        elseif row_hovered then
            love.graphics.setColor(0.12, 0.12, 0.2)
            love.graphics.rectangle("fill", 10, y - 2, 780, 28)
        end

        -- Checkbox
        love.graphics.setColor(0.55, 0.55, 0.65)
        love.graphics.print(task.status == "done" and "[X]" or "[ ]", 18, y + 4)

        -- Priority badge
        love.graphics.setColor(pc[1], pc[2], pc[3])
        love.graphics.print(string.format("[%-6s]", priority_labels[task.priority]), 58, y + 4)

        -- Name
        love.graphics.setColor(task.status == "done" and { 0.38, 0.38, 0.38 } or { 1, 1, 1 })
        love.graphics.print(task.name, 150, y + 4)

        -- Due date
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.print(task.due_date, 430, y + 4)

        -- Action buttons
        if task.status ~= "done" then
            draw_btn("complete_" .. i, "Done", 560, y + 2, 52, 24, "success")
        end
        draw_btn("delete_" .. i, "Del", 622, y + 2, 46, 24, "danger")

        -- Row click region for selection
        btn_reg["row_" .. i] = { x = 10, y = y - 2, w = 540, h = 28 }

        y = y + 32
    end

    if #sorted == 0 then
        love.graphics.setColor(0.38, 0.38, 0.5)
        love.graphics.print("No tasks yet — click '+ New Task' to get started.", 20, 90)
    end

    -- Footer
    love.graphics.setColor(0.28, 0.28, 0.38)
    love.graphics.line(10, 558, 790, 558)
    love.graphics.setColor(0.42, 0.42, 0.55)
    love.graphics.print("Up/Down or click to select   Q: Quit", 20, 566)
end

function ui.draw_form()
    -- Header
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("NEW TASK", 20, 14)
    love.graphics.setColor(0.3, 0.3, 0.42)
    love.graphics.line(10, 46, 790, 46)

    local y = 80

    -- Text input fields
    for i, field in ipairs(field_names) do
        local active = (i == field_index)

        love.graphics.setColor(active and { 1, 1, 0.4 } or { 0.58, 0.58, 0.68 })
        love.graphics.print(field_labels[i], 20, y + 5)

        love.graphics.setColor(active and { 0.16, 0.16, 0.3 } or { 0.11, 0.11, 0.18 })
        love.graphics.rectangle("fill", 150, y, 612, 30)
        love.graphics.setColor(active and { 0.48, 0.48, 0.88 } or { 0.22, 0.22, 0.35 })
        love.graphics.rectangle("line", 150, y, 612, 30)

        love.graphics.setColor(1, 1, 1)
        love.graphics.print(form[field] .. (active and "|" or ""), 156, y + 5)

        -- Invisible click zone to focus this field
        btn_reg["field_" .. i] = { x = 150, y = y, w = 612, h = 30 }

        y = y + 58
    end

    -- Priority row
    love.graphics.setColor(0.58, 0.58, 0.68)
    love.graphics.print("Priority:", 20, y + 5)

    draw_btn("priority_dec", "<", 150, y, 30, 30, "default")

    local pc = priority_colors[form.priority]
    love.graphics.setColor(pc[1], pc[2], pc[3])
    local font = love.graphics.getFont()
    local lbl  = priority_labels[form.priority]
    love.graphics.print(lbl, 192, y + 5)

    draw_btn("priority_inc", ">", 192 + font:getWidth(lbl) + 12, y, 30, 30, "default")

    -- Submit / Cancel
    draw_btn("submit", "Submit", 582, 510, 110, 36, "primary")
    draw_btn("cancel", "Cancel", 462, 510, 110, 36, "danger")

    -- Footer
    love.graphics.setColor(0.28, 0.28, 0.38)
    love.graphics.line(10, 558, 790, 558)
    love.graphics.setColor(0.42, 0.42, 0.55)
    love.graphics.print("Tab: Next Field   Enter: Submit   Escape: Cancel", 20, 566)
end

-- ─── Input ───────────────────────────────────────────────────────────────────

function ui.update(dt)
    mouse_x, mouse_y = love.mouse.getPosition()
end

function ui.textinput(char)
    if view ~= "form" then return end
    if field_index <= 3 then
        form[field_names[field_index]] = form[field_names[field_index]] .. char
    end
end

function ui.keypressed(key)
    if view == "list" then
        ui.list_keypressed(key)
    else
        ui.form_keypressed(key)
    end
end

function ui.mousepressed(x, y, btn)
    if btn ~= 1 then return end
    if view == "list" then
        ui.list_clicked(x, y)
    else
        ui.form_clicked(x, y)
    end
end

function ui.list_clicked(x, y)
    local sorted = tasks.get_sorted()

    if clicked("new_task", x, y) then
        form = { name = "", due_date = "", description = "", priority = 2 }
        field_index = 1
        view = "form"
        return
    end

    for i = 1, #sorted do
        if clicked("complete_" .. i, x, y) then
            tasks.complete(sorted[i].id)
            storage.save(tasks.get_all())
            return
        end
        if clicked("delete_" .. i, x, y) then
            tasks.delete(sorted[i].id)
            selected = math.max(1, selected - 1)
            storage.save(tasks.get_all())
            return
        end
        if clicked("row_" .. i, x, y) then
            selected = i
        end
    end
end

function ui.form_clicked(x, y)
    -- Focus a field by clicking it
    for i = 1, 3 do
        if clicked("field_" .. i, x, y) then
            field_index = i
            return
        end
    end

    if clicked("priority_dec", x, y) then
        form.priority = math.max(1, form.priority - 1)
    elseif clicked("priority_inc", x, y) then
        form.priority = math.min(3, form.priority + 1)
    elseif clicked("submit", x, y) then
        if form.name ~= "" then
            tasks.add(form.name, form.due_date, form.description, form.priority)
            storage.save(tasks.get_all())
            view = "list"
        end
    elseif clicked("cancel", x, y) then
        view = "list"
    end
end

function ui.list_keypressed(key)
    local sorted = tasks.get_sorted()
    if key == "n" then
        form = { name = "", due_date = "", description = "", priority = 2 }
        field_index = 1
        view = "form"
    elseif key == "up" then
        selected = math.max(1, selected - 1)
    elseif key == "down" then
        selected = math.min(math.max(#sorted, 1), selected + 1)
    elseif key == "c" and sorted[selected] then
        tasks.complete(sorted[selected].id)
        storage.save(tasks.get_all())
    elseif key == "d" and sorted[selected] then
        tasks.delete(sorted[selected].id)
        selected = math.max(1, selected - 1)
        storage.save(tasks.get_all())
    elseif key == "q" then
        love.event.quit()
    end
end

function ui.form_keypressed(key)
    if key == "escape" then
        view = "list"
    elseif key == "tab" then
        field_index = (field_index % 4) + 1
    elseif key == "backspace" then
        if field_index <= 3 then
            local f = field_names[field_index]
            form[f] = form[f]:sub(1, -2)
        end
    elseif key == "left" and field_index == 4 then
        form.priority = math.max(1, form.priority - 1)
    elseif key == "right" and field_index == 4 then
        form.priority = math.min(3, form.priority + 1)
    elseif key == "return" then
        if form.name ~= "" then
            tasks.add(form.name, form.due_date, form.description, form.priority)
            storage.save(tasks.get_all())
            view = "list"
        end
    end
end

return ui
