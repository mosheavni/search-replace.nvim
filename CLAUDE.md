<!-- markdownlint-disable MD013 -->

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

search-replace.nvim is a Neovim plugin for enhanced search and replace with a floating dashboard. It provides quick keymaps to populate substitute commands, toggle flags (g/c/i), cycle through ranges/separators/magic modes, and shows a live dashboard during command-line editing.

## Commands

### Linting

```bash
luacheck lua/ --globals vim
stylua --check lua/
```

### Formatting

```bash
stylua lua/
```

### Testing

```bash
# Run all tests (requires busted test framework)
busted tests/

# Run a specific test file
busted tests/search-replace_spec.lua
```

## Architecture

The plugin follows a modular architecture with four main components:

### init.lua (Entry Point)

- Handles `setup()` configuration merging
- Sets up keymaps for normal/visual/command-line modes
- Re-exports public API from core module

### core.lua (Business Logic)

- Manages search-replace state (`sar_state`) tracking active session, current word, separator, magic mode
- Implements toggle functions that return keystroke sequences using `<C-\>e` expression pattern
- All toggle functions use `set_cmd_and_pos()` helper to update both command text and cursor position atomically
- Uses `should_sar()` to detect if current cmdline is a substitute command (either in active mode or auto-detected)

### dashboard.lua (UI)

- Parses substitute commands and displays current state in a floating window
- Uses `CmdlineChanged` autocmd to auto-detect and display dashboard for any substitute command
- Maintains a `hidden` state to respect user's manual toggle
- Applies syntax highlighting using extmarks in a namespace

### float.lua (Window Management)

- Reusable floating window implementation inspired by mini.notify architecture
- Handles buffer/window caching, creation, and cleanup
- Uses `vim.cmd('redraw')` after updates for immediate display
- Reschedules operations via `vim.schedule()` when in fast event context

### utils.lua (Shared Utilities)

- Pattern constants for substitute command detection
- `parse_substitute_cmd()` - parses `:s` commands into range/separator/magic/search/replace/flags
- `split_by_separator()` - splits strings while respecting escaped separators
- `trigger_cmdline_refresh()` - uses fake keystroke (space + backspace) to force cmdline refresh

## Key Implementation Details

- Toggle functions return expression strings that Neovim evaluates (using `{ expr = true }` in keymap)
- The `<C-\>e` pattern allows replacing the entire command line via expression evaluation
- Dashboard refresh uses a fake keystroke technique because direct redraws don't work in cmdline mode
- The plugin auto-detects any substitute command (not just those started via `<leader>r`) to show the dashboard

## Code Style

- Uses 2-space indentation
- Single quotes preferred
- Max line length: 120 characters
- LuaDoc annotations for type hints (`---@class`, `---@param`, `---@return`)
