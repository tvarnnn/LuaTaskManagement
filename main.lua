-- main.lua
-- Terminal entry point for the Task Manager.
-- Run with: lua main.lua
-- All task logic lives in task_manager.lua; persistence in storage.lua.
-- History tracking (completed/deleted tasks) lives in history.lua.

local tasks   = require("task_manager")
local storage = require("storage")
local history = require("task_history")

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

-- print_history(entries)
-- Prints history entries in a formatted table.
-- Shows original id, action, priority, name, due date, and timestamp.
local function print_history(entries)
    if #entries == 0 then
        print("  (no history yet)")
        return
    end
    print(string.format("  %-4s %-10s %-8s %-25s %-12s %s",
        "ID", "Action", "Priority", "Name", "Due Date", "Timestamp"))
    print("  " .. string.rep("-", 82))
    for _, e in ipairs(entries) do
        local label = PRIORITY_LABELS[e.priority] or "?"
        print(string.format("  %-4d %-10s %-8s %-25s %-12s %s",
            e.id,
            e.action,
            label,
            e.name,
            e.due_date ~= "" and e.due_date or "—",
            e.timestamp))
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
-- Marks a task as done by its ID and records it in history.
local function complete_task()
    print("\n── Complete Task ──")
    view_tasks()
    local id = tonumber(prompt("\n  Enter task ID to mark complete: "))
    if not id then
        print("  Invalid ID. Cancelled.")
        return
    end

    -- Find the task first so we can snapshot it for history before completing it
    local found = nil
    for _, t in ipairs(tasks.get_all()) do
        if t.id == id then
            found = t
            break
        end
    end

    if not found then
        print("  Task ID not found. Cancelled.")
        return
    end

    -- Record in history BEFORE mutating status
    history.record(found, "completed")
    tasks.complete(id)
    storage.save(tasks.get_all())
    history.save()
    print("  Task marked as done.")
end

-- delete_task()
-- Permanently removes a task by its ID and records it in history.
local function delete_task()
    print("\n── Delete Task ──")
    view_tasks()
    local id = tonumber(prompt("\n  Enter task ID to delete: "))
    if not id then
        print("  Invalid ID. Cancelled.")
        return
    end

    -- Find the task first so we can snapshot it for history before deletion
    local found = nil
    for _, t in ipairs(tasks.get_all()) do
        if t.id == id then
            found = t
            break
        end
    end

    if not found then
        print("  Task ID not found. Cancelled.")
        return
    end

    -- Record in history BEFORE removing from the list
    history.record(found, "deleted")
    tasks.delete(id)
    storage.save(tasks.get_all())
    history.save()
    print("  Task deleted.")
end

-- print_history_indexed(entries)
-- Like print_history but also shows a list index (#) so the user can
-- reference an entry by number when choosing to undo.
local function print_history_indexed(entries)
    if #entries == 0 then
        print("  (no history yet)")
        return
    end
    print(string.format("  %-4s %-4s %-10s %-8s %-25s %-12s %s",
        "#", "ID", "Action", "Priority", "Name", "Due Date", "Timestamp"))
    print("  " .. string.rep("-", 88))
    for i, e in ipairs(entries) do
        local label = PRIORITY_LABELS[e.priority] or "?"
        print(string.format("  %-4d %-4d %-10s %-8s %-25s %-12s %s",
            i,
            e.id,
            e.action,
            label,
            e.name,
            e.due_date ~= "" and e.due_date or "—",
            e.timestamp))
    end
end

-- undo_task()
-- Shows the full history with list indices, lets the user pick one entry,
-- and restores that task to the active task list.
--
-- Undo behaviour by action type:
--   "completed" → task already exists in task_list with status "done";
--                 resets its status back to "pending".
--   "deleted"   → task was removed; re-inserts it with its original fields
--                 and the SAME original id (next_id is not affected because
--                 task_manager only advances next_id forward on add()).
--
-- After a successful undo the history entry is removed so it cannot be
-- undone twice, and both task and history files are saved.
local function undo_task()
    print("\n── Undo from History ──")
    local all = history.get_all()
    print_history_indexed(all)

    if #all == 0 then return end

    local idx = tonumber(prompt("\n  Enter # to undo (or 0 to cancel): "))
    if not idx or idx == 0 then
        print("  Cancelled.")
        return
    end
    if idx < 1 or idx > #all then
        print("  Invalid number. Cancelled.")
        return
    end

    local entry = all[idx]

    if entry.action == "completed" then
        -- Task still lives in task_list with status "done" — revert it
        local found = false
        for _, t in ipairs(tasks.get_all()) do
            if t.id == entry.id then
                t.status = "pending"
                found = true
                break
            end
        end
        if not found then
            print("  Could not find task in list (it may have been deleted separately).")
            return
        end
        print(string.format("  Task #%d \"%s\" restored to pending.", entry.id, entry.name))

    elseif entry.action == "deleted" then
        -- Task was fully removed — re-insert it with all original fields intact
        tasks.restore(entry.id, entry.name, entry.due_date, entry.description, entry.priority)
        print(string.format("  Task #%d \"%s\" restored to task list.", entry.id, entry.name))

    else
        print("  Unknown action type — cannot undo.")
        return
    end

    -- Remove this entry from history so it can't be undone twice
    history.remove_entry(idx)
    storage.save(tasks.get_all())
    history.save()
end

-- view_history()
-- Shows a sub-menu letting the user browse all, completed-only, or deleted-only history,
-- undo an entry, or clear all history.
local function view_history()
    print("\n── Task History ──")
    print("  a. All history")
    print("  c. Completed tasks only")
    print("  d. Deleted tasks only")
    print("  u. Undo a task")
    print("  x. Clear all history")
    print("  b. Back")
    local choice = prompt("  Choice: ")

    if choice == "a" then
        print("\n── Full History ──")
        print_history(history.get_all())

    elseif choice == "c" then
        print("\n── Completed Tasks ──")
        print_history(history.get_by_action("completed"))

    elseif choice == "d" then
        print("\n── Deleted Tasks ──")
        print_history(history.get_by_action("deleted"))

    elseif choice == "u" then
        undo_task()

    elseif choice == "x" then
        local confirm = prompt("  Are you sure you want to clear all history? (yes/no): ")
        if confirm == "yes" then
            history.clear()
            print("  History cleared.")
        else
            print("  Cancelled.")
        end

    elseif choice == "b" then
        return  -- go back to main menu

    else
        print("  Invalid option.")
    end
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
    print("║  5. View history         ║")
    print("║  0. Exit                 ║")
    print("╚══════════════════════════╝")
end

-- ─── Startup ─────────────────────────────────────────────────────────────────

-- Load saved tasks and history from disk into memory on startup.
tasks.load_tasks(storage.load())
history.load()

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
    elseif choice == "5" then
        view_history()
    elseif choice == "0" then
        print("\nGoodbye!\n")
        break
    else
        print("  Invalid option. Please enter 0-5.")
    end
end
