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
- Includes inlined float helpers for buffer/window management

### utils.lua (Shared Utilities)

- Pattern constants for substitute command detection
- `parse_substitute_cmd()` - parses `:s` commands into range/separator/magic/search/replace/flags
- `split_by_separator()` - splits strings while respecting escaped separators
- `trigger_cmdline_refresh()` - uses fake keystroke (space + backspace) to force cmdline refresh for toggles

## Key Implementation Details

- Toggle functions return expression strings that Neovim evaluates (using `{ expr = true }` in keymap)
- The `<C-\>e` pattern allows replacing the entire command line via expression evaluation
- Dashboard refresh strategy (to preserve inccommand highlights):
  - During typing: `CmdlineChanged` calls `refresh_dashboard()` directly (no fake keystroke)
  - During toggles/initial populate: uses `trigger_cmdline_refresh()` with fake keystroke (space + backspace)
- The fake keystroke uses `nvim_feedkeys(..., 'nt', true)` to behave like typed input for inccommand
- The plugin auto-detects any substitute command (not just those started via `<leader>r`) to show the dashboard

## Critical: Inccommand Compatibility

**DO NOT BREAK THIS** - The plugin must coexist with Neovim's `inccommand` feature (live preview of substitutions).

### The Problem

When the dashboard refreshes, it can interfere with inccommand highlights. The naive approach of using fake keystrokes (space+backspace) to trigger `CmdlineChanged` on every keystroke causes inccommand to flicker and disappear.

### The Solution (Two-Strategy Approach)

1. **During typing** (`CmdlineChanged` autocmd in `dashboard.lua`):
   - Call `refresh_dashboard()` directly - NO fake keystrokes
   - This preserves inccommand highlights while user types

2. **During toggles and initial populate** (`set_cmd_and_pos()` in `core.lua`, keymaps in `init.lua`):
   - Use `trigger_cmdline_refresh()` which sends fake keystrokes
   - This is acceptable because it's a one-time event, not continuous

### Critical Implementation Details

1. **`trigger_cmdline_refresh()` in `utils.lua`**:
   - Must use `vim.api.nvim_feedkeys(..., 'nt', true)` - the `'t'` flag makes keys behave like typed input
   - Without `'t'` flag, inccommand won't process the keystrokes properly
   - The `true` for `escape_csi` is required

2. **Cannot refresh during `<C-\>e` expression evaluation**:
   - `set_cmd_and_pos()` is called during expression evaluation
   - Cannot modify buffers/windows in this context (causes E565 error)
   - Must use `vim.defer_fn()` to schedule the refresh after evaluation completes

3. **Initial `<leader>r` needs explicit refresh**:
   - The `populate_searchline()` function just returns the command string
   - The keymap must call `trigger_cmdline_refresh()` after `feedkeys()` to trigger inccommand

### Testing Checklist

When modifying refresh logic, always verify:
- [ ] Inccommand highlights appear on initial `<leader>r`
- [ ] Inccommand highlights persist while typing in the substitute command
- [ ] Inccommand highlights update after toggles (`<M-d>`, `<M-g>`, etc.)
- [ ] Dashboard shows correct values after all operations
- [ ] No E565 errors when using toggles

## Code Style

- Uses 2-space indentation
- Single quotes preferred
- Max line length: 120 characters
- LuaDoc annotations for type hints (`---@class`, `---@param`, `---@return`)
