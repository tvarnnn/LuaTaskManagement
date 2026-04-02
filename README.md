# Lua Task Manager

A terminal-based task management system built in Lua.

---

## Requirements

- Lua

---

## Installation

### macOS

**1. Install Homebrew** (if you don't have it):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**2. Install Lua:**

```bash
brew install lua
```

---

### Windows

**1. Install Lua:**

- Download the installer from [luabinaries.sourceforge.net](https://luabinaries.sourceforge.net) or install via [Scoop](https://scoop.sh):

```powershell
scoop install lua
```

---

## Running the App

Navigate to the project folder in your terminal (macOS) or Command Prompt / PowerShell (Windows) and run:

```bash
lua main.lua
```

Press `0` then `Enter` to exit.

---

## Features

- Add tasks with a name, due date, description, and priority
- Priority levels: High, Medium, Low
- Mark tasks as done or delete them
- Tasks are sorted by priority automatically
- Data is saved to a file and persists between sessions

---

## Project Structure

```
main.lua          — Terminal UI, menu loop, and user input handling
task_manager.lua  — In-memory task list and CRUD operations
storage.lua       — Saves and loads tasks to/from a local file
tasks_data.lua    — Auto-generated save file (created on first run)
```
