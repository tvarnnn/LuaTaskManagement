-- server.lua
-- HTTP server entry point — run with: lua server.lua
-- Listens on localhost:8080 and handles all routing, HTML generation,
-- and request/response handling using the LuaSocket library.
-- All task logic is delegated to task_manager.lua; persistence to storage.lua.

local socket  = require("socket")   -- LuaSocket: TCP server and sleep
local tasks   = require("task_manager")  -- in-memory CRUD operations
local storage = require("storage")       -- file-based persistence

local HOST = "127.0.0.1"  -- only accept connections from localhost
local PORT = 8080

-- ─── Utilities ───────────────────────────────────────────────────────────────

-- url_decode(s)
-- Decodes a URL-encoded string: converts "+" back to spaces and "%XX" hex
-- sequences back to their ASCII characters. Used when parsing form POST bodies.
local function url_decode(s)
    return s:gsub("+", " "):gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end)
end

-- parse_form(body)
-- Parses an application/x-www-form-urlencoded POST body into a key-value table.
-- Example: "name=Buy+milk&priority=1" -> { name = "Buy milk", priority = "1" }
local function parse_form(body)
    local p = {}
    for k, v in (body or ""):gmatch("([^&=]+)=([^&=]*)") do
        p[url_decode(k)] = url_decode(v)
    end
    return p
end

-- ─── HTML Generation ─────────────────────────────────────────────────────────

-- Lookup tables indexed by priority number (1/2/3) for display label and badge color.
-- Using tables here avoids a chain of if-else checks every time a row renders.
local PRIORITY_LABELS = { "High", "Medium", "Low" }
local PRIORITY_COLORS = { "#e05555", "#d4a017", "#4caf50" }

-- task_row(task)
-- Builds and returns the HTML string for a single table row.
-- Done tasks get a strikethrough name and no "Done" button.
-- Buttons POST to /complete/<id> and /delete/<id> respectively.
local function task_row(task)
    local color = PRIORITY_COLORS[task.priority] or "#888"
    local label = PRIORITY_LABELS[task.priority] or "?"
    local done  = task.status == "done"
    local name  = done and ("<s>" .. task.name .. "</s>") or task.name

    local done_btn = ""
    if not done then
        done_btn = string.format([[
            <form method="POST" action="/complete/%d" style="display:inline">
                <button class="btn btn-success">Done</button>
            </form>]], task.id)
    end

    return string.format([[
        <tr class="%s">
            <td><span class="badge" style="background:%s; color:#111">%s</span></td>
            <td class="task-name">%s</td>
            <td>%s</td>
            <td class="task-desc">%s</td>
            <td class="actions">
                %s
                <form method="POST" action="/delete/%d" style="display:inline">
                    <button class="btn btn-danger">Del</button>
                </form>
            </td>
        </tr>]],
        done and "row-done" or "",
        color, label,
        name,
        task.due_date ~= "" and task.due_date or "—",
        task.description ~= "" and task.description or "—",
        done_btn,
        task.id
    )
end

-- render_page(sorted_tasks)
-- Builds and returns the full HTML page as a string.
-- Accepts the pre-sorted task list and injects rows into the table body.
-- Uses %% inside the CSS block to escape literal % signs in string.format.
local function render_page(sorted_tasks)
    local rows = {}
    for _, t in ipairs(sorted_tasks) do
        table.insert(rows, task_row(t))
    end

    local empty = ""
    if #sorted_tasks == 0 then
        empty = '<tr><td colspan="5" class="empty">No tasks yet — add one below.</td></tr>'
    end

    return string.format([[<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Task Manager</title>
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  body {
    font-family: 'Segoe UI', system-ui, sans-serif;
    background: #0d0d15;
    color: #c8c8dc;
    padding: 36px 28px;
    min-height: 100vh;
  }

  h1 {
    font-size: 1.5rem;
    color: #ffffff;
    letter-spacing: 2px;
    margin-bottom: 28px;
  }

  h2 {
    font-size: 0.78rem;
    color: #6666aa;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-bottom: 14px;
  }

  /* ── Table ── */
  .table-wrap { overflow-x: auto; margin-bottom: 48px; }

  table { width: 100%%; border-collapse: collapse; }

  thead th {
    text-align: left;
    padding: 8px 14px;
    font-size: 0.74rem;
    text-transform: uppercase;
    letter-spacing: 1px;
    color: #55557a;
    border-bottom: 1px solid #1e1e2e;
  }

  tbody td {
    padding: 11px 14px;
    border-bottom: 1px solid #16161f;
    vertical-align: middle;
    font-size: 0.9rem;
  }

  tbody tr:hover td { background: #111120; }

  tr.row-done td { opacity: 0.38; }

  .task-name { font-weight: 500; color: #e0e0f0; max-width: 220px; }
  .task-desc { color: #6a6a88; font-size: 0.84rem; max-width: 200px; }
  .actions   { white-space: nowrap; }
  .empty     { text-align: center; color: #444; padding: 36px; font-style: italic; }

  /* ── Badge ── */
  .badge {
    display: inline-block;
    padding: 2px 9px;
    border-radius: 4px;
    font-size: 0.73rem;
    font-weight: 700;
    letter-spacing: 0.5px;
  }

  /* ── Buttons ── */
  .btn {
    padding: 4px 13px;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    font-size: 0.8rem;
    font-weight: 600;
    margin-left: 4px;
    transition: filter 0.15s;
  }
  .btn:hover        { filter: brightness(1.2); }
  .btn-success      { background: #1b6b1b; color: #cfffcf; }
  .btn-danger       { background: #7a1818; color: #ffd0d0; }
  .btn-primary      {
    background: #2040aa;
    color: #fff;
    padding: 10px 26px;
    font-size: 0.92rem;
    margin-top: 6px;
  }

  /* ── Add Task Form ── */
  .card {
    background: #11111c;
    border: 1px solid #1e1e32;
    border-radius: 10px;
    padding: 26px 28px;
    max-width: 580px;
  }

  .field { display: flex; flex-direction: column; margin-bottom: 16px; }

  .field label {
    font-size: 0.76rem;
    color: #7777aa;
    margin-bottom: 5px;
    text-transform: uppercase;
    letter-spacing: 0.8px;
  }

  .field input,
  .field select,
  .field textarea {
    background: #09090f;
    border: 1px solid #22223a;
    color: #d0d0e8;
    border-radius: 5px;
    padding: 8px 11px;
    font-size: 0.9rem;
    outline: none;
    transition: border-color 0.15s;
  }

  .field input:focus,
  .field select:focus,
  .field textarea:focus { border-color: #3a4fcc; }

  .field textarea { resize: vertical; min-height: 64px; }

  select option { background: #11111c; }
</style>
</head>
<body>

<h1>TASK MANAGER</h1>

<div class="table-wrap">
  <table>
    <thead>
      <tr>
        <th>Priority</th>
        <th>Name</th>
        <th>Due Date</th>
        <th>Description</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody>
      %s
      %s
    </tbody>
  </table>
</div>

<h2>Add New Task</h2>
<div class="card">
  <form method="POST" action="/add">
    <div class="field">
      <label>Name *</label>
      <input type="text" name="name" required placeholder="What needs to be done?">
    </div>
    <div class="field">
      <label>Due Date</label>
      <input type="date" name="due_date">
    </div>
    <div class="field">
      <label>Description</label>
      <textarea name="description" placeholder="Optional details..."></textarea>
    </div>
    <div class="field">
      <label>Priority</label>
      <select name="priority">
        <option value="1">High</option>
        <option value="2" selected>Medium</option>
        <option value="3">Low</option>
      </select>
    </div>
    <button class="btn btn-primary" type="submit">+ Add Task</button>
  </form>
</div>

</body>
</html>]], table.concat(rows, "\n"), empty)
end

-- ─── HTTP Helpers ────────────────────────────────────────────────────────────

-- read_request(client)
-- Reads a full HTTP request from the client socket.
-- Headers are read line-by-line until the blank line separator.
-- For POST requests, Content-Length is extracted so we can read the exact
-- number of body bytes — avoids blocking or reading too much.
-- Returns: method (string), path (string), body (string)
local function read_request(client)
    local lines = {}
    local line  = client:receive()
    while line and line ~= "" do
        table.insert(lines, line)
        line = client:receive()
    end

    -- First line of an HTTP request is always "METHOD /path HTTP/1.x"
    local method, path = (lines[1] or ""):match("(%u+) (/[^ ]*)")

    local body = ""
    if method == "POST" then
        local len = 0
        for _, h in ipairs(lines) do
            local l = h:match("[Cc]ontent%-[Ll]ength: (%d+)")
            if l then len = tonumber(l); break end
        end
        if len > 0 then body = client:receive(len) end
    end

    return method, path, body
end

-- redirect(client)
-- Sends an HTTP 302 redirect back to the root "/" after any POST action.
-- This implements the Post/Redirect/Get pattern so refreshing doesn't resubmit.
local function redirect(client)
    client:send("HTTP/1.1 302 Found\r\nLocation: /\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
end

-- send_html(client, html)
-- Sends an HTTP 200 response with the given HTML string as the body.
-- Content-Length is set to the byte length of the HTML string using the # operator.
local function send_html(client, html)
    client:send(
        "HTTP/1.1 200 OK\r\n" ..
        "Content-Type: text/html; charset=utf-8\r\n" ..
        "Content-Length: " .. #html .. "\r\n" ..
        "Connection: close\r\n\r\n" ..
        html
    )
end

-- ─── Startup ─────────────────────────────────────────────────────────────────

-- Load any previously saved tasks from disk into memory on startup.
tasks.load_tasks(storage.load())

-- Seed with sample tasks if the data file was empty or missing.
-- This ensures the UI is never blank on first run.
if #tasks.get_all() == 0 then
    tasks.add("Read Lua documentation", "2026-03-25", "Cover tables and metatables", 1)
    tasks.add("Build task input form",  "2026-03-27", "Name, date, desc, priority",  2)
    tasks.add("Style the UI",           "2026-03-30", "Colors and layout polish",     3)
    tasks.add("Add file persistence",   "2026-03-26", "Save/load with storage.lua",   1)
    storage.save(tasks.get_all())
end

-- Bind the TCP server socket. settimeout(0) makes accept() non-blocking
-- so the main loop can use socket.sleep() instead of hanging on idle connections.
local server = assert(socket.bind(HOST, PORT), "Could not bind to port " .. PORT)
server:settimeout(0)

print("Task Manager running at http://localhost:" .. PORT)
print("Press Ctrl+C to stop.\n")

-- ─── Main Loop ───────────────────────────────────────────────────────────────
-- Continuously polls for incoming connections. When a client connects:
--   1. Read the HTTP request (wrapped in pcall to handle dropped connections)
--   2. Route based on method + path
--   3. Close the connection (HTTP/1.0 style — one request per connection)
-- socket.sleep(0.01) yields the CPU between polls to avoid busy-waiting.

while true do
    local client = server:accept()
    if client then
        client:settimeout(5)  -- 5s timeout so a stalled client doesn't block the loop

        -- pcall catches any socket errors during reading so the server stays up
        local ok, method, path, body = pcall(read_request, client)

        if ok and method then
            -- GET / : render the full task list page
            if method == "GET" and path == "/" then
                send_html(client, render_page(tasks.get_sorted()))

            -- POST /add : create a new task from form data, then redirect
            elseif method == "POST" and path == "/add" then
                local p = parse_form(body)
                if p.name and p.name ~= "" then
                    tasks.add(p.name, p.due_date or "", p.description or "", tonumber(p.priority) or 2)
                    storage.save(tasks.get_all())
                end
                redirect(client)

            -- POST /complete/<id> or /delete/<id> : update task state, then redirect
            elseif method == "POST" then
                local id = tonumber(path:match("/complete/(%d+)"))
                if id then tasks.complete(id); storage.save(tasks.get_all()) end

                id = tonumber(path:match("/delete/(%d+)"))
                if id then tasks.delete(id); storage.save(tasks.get_all()) end

                redirect(client)
            end
        end

        client:close()
    end
    socket.sleep(0.01)  -- prevent busy-loop; yields ~10ms between connection checks
end
