-- main.lua
-- Terminal entry point for the Task Manager.
-- Run with: lua main.lua
-- All task logic lives in task_manager.lua; persistence in storage.lua.

local tasks   = require("task_manager")
local storage = require("storage")

-- ─── Display Helpers ─────────────────────────────────────────────────────────

-- Priority labels indexed by priority number (1=High, 2=Medium, 3=Low)
local PRIORITY_LABELS = { "High", "Medium", "Low" }

-- print_tasks(task_list)
-- Prints all tasks in a formatted table to the terminal.
-- Shows id, priority, name, due date, description, and status.
local function print_tasks(task_list)
    if #task_list == 0 then
        print("  (no tasks)")
        return
    end
    print(string.format("  %-4s %-8s %-25s %-12s %-20s %s",
        "ID", "Priority", "Name", "Due Date", "Description", "Status"))
    print("  " .. string.rep("-", 80))
    for _, t in ipairs(task_list) do
        local label = PRIORITY_LABELS[t.priority] or "?"
        print(string.format("  %-4d %-8s %-25s %-12s %-20s %s",
            t.id,
            label,
            t.name,
            t.due_date ~= "" and t.due_date or "—",
            t.description ~= "" and t.description or "—",
            t.status))
    end
end

-- prompt(msg)
-- Prints a prompt and returns the trimmed user input string.
local function prompt(msg)
    io.write(msg)
    io.flush()
    local input = io.read()
    return input and input:match("^%s*(.-)%s*$") or ""
end

-- ─── Menu Actions ────────────────────────────────────────────────────────────

-- view_tasks()
-- Displays all tasks sorted by priority (highest first).
local function view_tasks()
    print("\n── All Tasks (sorted by priority) ──")
    print_tasks(tasks.get_sorted())
end

-- add_task()
-- Prompts the user for task details and adds a new task.
-- Name is required; due date, description, and priority are optional.
local function add_task()
    print("\n── Add New Task ──")
    local name = prompt("  Name (required): ")
    if name == "" then
        print("  Name cannot be empty. Cancelled.")
        return
    end

    local due_date    = prompt("  Due Date (YYYY-MM-DD, or leave blank): ")
    local description = prompt("  Description (or leave blank): ")

    -- Priority selection with a simple numbered menu
    print("  Priority: 1=High  2=Medium  3=Low")
    local p_input  = prompt("  Choose (default 2): ")
    local priority = tonumber(p_input)
    if not priority or priority < 1 or priority > 3 then
        priority = 2  -- default to Medium if input is invalid or blank
    end

    tasks.add(name, due_date, description, priority)
    storage.save(tasks.get_all())
    print("  Task added.")
end

-- complete_task()
-- Marks a task as done by its ID.
local function complete_task()
    print("\n── Complete Task ──")
    view_tasks()
    local id = tonumber(prompt("\n  Enter task ID to mark complete: "))
    if not id then
        print("  Invalid ID. Cancelled.")
        return
    end
    tasks.complete(id)
    storage.save(tasks.get_all())
    print("  Task marked as done.")
end

-- delete_task()
-- Permanently removes a task by its ID.
local function delete_task()
    print("\n── Delete Task ──")
    view_tasks()
    local id = tonumber(prompt("\n  Enter task ID to delete: "))
    if not id then
        print("  Invalid ID. Cancelled.")
        return
    end
    tasks.delete(id)
    storage.save(tasks.get_all())
    print("  Task deleted.")
end

-- ─── Main Menu ───────────────────────────────────────────────────────────────

-- print_menu()
-- Prints the main menu options to the terminal.
local function print_menu()
    print("\n╔══════════════════════════╗")
    print("║       TASK MANAGER       ║")
    print("╠══════════════════════════╣")
    print("║  1. View tasks           ║")
    print("║  2. Add task             ║")
    print("║  3. Complete task        ║")
    print("║  4. Delete task          ║")
    print("║  0. Exit                 ║")
    print("╚══════════════════════════╝")
end

-- ─── Startup ─────────────────────────────────────────────────────────────────

-- Load saved tasks from disk into memory on startup.
tasks.load_tasks(storage.load())

-- Seed with sample data if no tasks exist yet (first run).
if #tasks.get_all() == 0 then
    tasks.add("Read Lua documentation", "2026-03-25", "Cover tables and metatables", 1)
    tasks.add("Build task input form",  "2026-03-27", "Name, date, desc, priority",  2)
    tasks.add("Style the UI",           "2026-03-30", "Colors and layout polish",     3)
    tasks.add("Add file persistence",   "2026-03-26", "Save/load with storage.lua",   1)
    storage.save(tasks.get_all())
end

-- ─── Main Loop ───────────────────────────────────────────────────────────────
-- Repeatedly shows the menu and dispatches to the appropriate action function
-- until the user enters 0 to exit.

while true do
    print_menu()
    local choice = prompt("  Choice: ")

    if choice == "1" then
        view_tasks()
    elseif choice == "2" then
        add_task()
    elseif choice == "3" then
        complete_task()
    elseif choice == "4" then
        delete_task()
    elseif choice == "0" then
        print("\nGoodbye!\n")
        break
    else
        print("  Invalid option. Please enter 0-4.")
    end
end
