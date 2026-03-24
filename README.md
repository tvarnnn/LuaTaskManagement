# Lua Task Manager

A task management system with a web-based GUI, built in Lua. Runs locally in your browser.

---

## Requirements

- Lua
- LuaRocks (Lua package manager)
- LuaSocket (networking library)

---

## Installation

### macOS

**1. Install Homebrew** (if you don't have it):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Install Lua and LuaRocks:**

```bash
brew install lua
brew install luarocks
```

**3. Install LuaSocket:**

```bash
luarocks install luasocket
```

---

### Windows

**1. Install Lua:**

- Download the installer from [luabinaries.sourceforge.net](https://luabinaries.sourceforge.net) or install via [Scoop](https://scoop.sh):

```powershell
scoop install lua
```

**2. Install LuaRocks:**

- Download the Windows installer from [luarocks.org](https://luarocks.org)
- Run the installer and make sure to check "Add to PATH"

**3. Install LuaSocket:**

```powershell
luarocks install luasocket
```

---

## Running the App

Navigate to the project folder in your terminal (macOS) or Command Prompt / PowerShell (Windows) and run:

```bash
lua server.lua
```

Then open your browser and go to:

```
http://localhost:8080
```

Press `Ctrl+C` to stop the server.

---

## Features

- Add tasks with a name, due date, description, and priority
- Priority levels: High, Medium, Low (color coded)
- Mark tasks as done or delete them
- Tasks are sorted by priority automatically
- Data is saved to a file and persists between sessions

---

## Project Structure

```
server.lua        — HTTP server, routing, and HTML generation
task_manager.lua  — In-memory task list and CRUD operations
storage.lua       — Saves and loads tasks to/from a local file
tasks_data.lua    — Auto-generated save file (created on first run)
```
