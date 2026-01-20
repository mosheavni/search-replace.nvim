---@brief [[
---Core business logic for search-replace.nvim.
---
---This module manages the search-replace state and provides toggle functions
---that manipulate the command line during substitute command editing.
---
---Key concepts:
---- `sar_state` tracks the active session, current word, separator, and magic mode
---- Toggle functions return keystroke sequences using the `<C-\>e` expression pattern
---- All toggle functions use `set_cmd_and_pos()` to update command and cursor atomically
---- `should_sar()` detects if the current cmdline is a substitute command
---
---The `<C-\>e` pattern allows replacing the entire command line via expression
---evaluation, which is necessary because direct command line manipulation is
---not possible in cmdline mode.
---@brief ]]

---@tag search-replace.core

---@class SearchReplaceCore
---@field setup fun(opts?: CoreConfig) Setup the core module with configuration
---@field is_active fun(): boolean Check if search-replace mode is active
---@field set_cmd_and_pos fun(): string Set command and cursor position (called from C-\ e expression)
---@field populate_searchline fun(mode: string): string, integer Populate the search line
---@field toggle_char fun(char: string): string Toggle a flag character
---@field toggle_replace_term fun(): string Toggle the replace term
---@field toggle_all_file fun(): string Toggle range (all file)
---@field toggle_separator fun(): string Toggle separator
---@field toggle_magic fun(): string Toggle magic mode
local M = {}

local utils = require('search-replace.utils')

---@class CoreConfig
---@field separators string[] Available separator characters
---@field magic_modes string[] Available magic modes
---@field flags string[] Available flags
---@field default_range string Default range for substitute command
---@field default_flags string Default flags for substitute command
---@field default_magic string Default magic mode

-- Config is set by setup() from init.lua, which uses centralized config.lua defaults
---@type CoreConfig
local config

---@class SarState
---@field active boolean Whether search-replace mode is active
---@field cword string The current word or visual selection
---@field sep string The current separator character
---@field magic string The current magic mode
---@field new_cmd string The new command (used by set_cmd_and_pos)
---@field cursor_pos integer The cursor position (used by set_cmd_and_pos)

---@type SarState
local sar_state = {
  active = false,
  cword = '',
  sep = '/',
  magic = '\\V',
  new_cmd = '',
  cursor_pos = 0,
}

---Check if we should process the current command line as a substitute command
---@return boolean
local function should_sar()
  if vim.fn.getcmdtype() ~= ':' then
    return false
  end
  -- Active mode (triggered by <leader>r) or detected substitute command
  if sar_state.active then
    return true
  end
  -- Check if current cmdline looks like a substitute command
  return utils.is_substitute_cmd(vim.fn.getcmdline())
end

---Get the current separator (from state if active, or parse from cmdline)
---@return string sep The current separator character
local function get_current_sep()
  if sar_state.active then
    return sar_state.sep
  end
  local parsed = utils.parse_substitute_cmd(vim.fn.getcmdline())
  return parsed and parsed.sep or '/'
end

---Find a character from the list that doesn't appear in the string
---@param char_list string[] List of candidate characters
---@param str string String to check against
---@return string char The first unique character, or empty string if none found
local function find_unique_char(char_list, str)
  for _, char in ipairs(char_list) do
    if not str:find(vim.pesc(char), 1, true) then
      return char
    end
  end
  return ''
end

---Check if search-replace mode is active
---@return boolean active Whether search-replace mode is active
function M.is_active()
  return sar_state.active
end

---Set command and cursor position (called from C-\ e expression)
---This function is called via luaeval from the keymap expressions
---@return string new_cmd The new command line content
function M.set_cmd_and_pos()
  vim.fn.setcmdpos(sar_state.cursor_pos)

  -- Trigger dashboard refresh by invalidating cache and simulating a keystroke
  local ok, dashboard = pcall(require, 'search-replace.dashboard')
  if ok and dashboard and dashboard.invalidate_cache then
    utils.trigger_cmdline_refresh(dashboard.invalidate_cache)
  end

  return sar_state.new_cmd
end

---Populate the search line with the current word or visual selection
---@param mode string The mode ('n' for normal, 'v' for visual)
---@return string cmd The substitute command
---@return integer move_left Number of characters to move cursor left
function M.populate_searchline(mode)
  -- Get word under cursor or visual selection
  if mode == 'n' then
    sar_state.cword = vim.fn.expand('<cword>')
  else
    sar_state.cword = utils.get_visual_selection()
  end

  -- Find unique separator
  sar_state.sep = find_unique_char(config.separators, sar_state.cword)
  sar_state.magic = config.default_magic

  -- Build command
  local flags = config.default_flags
  local cmd = config.default_range
    .. sar_state.sep
    .. sar_state.magic
    .. sar_state.cword
    .. sar_state.sep
    .. sar_state.cword
    .. sar_state.sep
    .. flags

  -- Activate search-replace mode (hints will be shown by CmdlineEnter autocmd)
  sar_state.active = true

  -- Return command and cursor movement count (to position cursor at end of replace term)
  local chars_to_move_left = #sar_state.sep + #flags
  return cmd, chars_to_move_left
end

---Toggle a flag character (g, c, i) in the substitute command
---@param char string The flag character to toggle
---@return string keys The keystrokes to execute (uses <C-\>e pattern)
function M.toggle_char(char)
  local cmd = vim.fn.getcmdline()
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(cmd, sep, { plain = true }))
  local flags = parts[4]

  -- Toggle the flag
  if flags:find(char) then
    flags = flags:gsub(char, '')
  else
    -- Add flag in correct order
    local new_flags = ''
    for _, flag in ipairs(config.flags) do
      if flags:find(flag) or char == flag then
        new_flags = new_flags .. flag
      end
    end
    flags = new_flags
  end

  parts[4] = flags
  local new_cmd = table.concat(parts, sep)

  -- Store command and cursor position for helper function
  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #sep - #parts[4] + 1

  -- Use <C-\>e to evaluate expression that sets both command and cursor
  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Toggle the replace term (clear/restore original word)
---@return string keys The keystrokes to execute (uses <C-\>e pattern)
function M.toggle_replace_term()
  local cmd = vim.fn.getcmdline()
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(cmd, sep, { plain = true }))
  -- Use stored cword if in active mode, otherwise use search term or empty
  local current_replace = parts[3]
  local search_term = parts[2]
  local replace_term = current_replace == '' and (sar_state.active and sar_state.cword or search_term) or ''
  parts[3] = replace_term

  local new_cmd = table.concat(parts, sep)

  -- Store command and cursor position for helper function
  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #sep - #parts[4] + 1

  -- Use <C-\>e to evaluate expression that sets both command and cursor
  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Toggle the range (cycle through %s -> .,$s -> 0,.s -> %s)
---@return string keys The keystrokes to execute (uses <C-\>e pattern)
function M.toggle_all_file()
  local cmd = vim.fn.getcmdline()
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(cmd, sep, { plain = true }))
  local range = parts[1]

  -- Cycle through ranges: %s -> .,$s -> 0,.s -> %s
  if range == '%s' then
    range = '.,$s'
  elseif range == '.,$s' then
    range = '0,.s'
  else
    range = '%s'
  end

  parts[1] = range
  local new_cmd = table.concat(parts, sep)

  -- Store command and cursor position for helper function
  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #sep - #parts[4] + 1

  -- Use <C-\>e to evaluate expression that sets both command and cursor
  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Toggle the separator character (cycle through configured separators)
---@return string keys The keystrokes to execute (uses <C-\>e pattern)
function M.toggle_separator()
  local cmd = vim.fn.getcmdline()
  if not should_sar() then
    return ''
  end

  local old_sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(cmd, old_sep, { plain = true }))

  -- Find next separator
  local idx = 0
  for i, c in ipairs(config.separators) do
    if c == old_sep then
      idx = i
      break
    end
  end
  sar_state.sep = config.separators[(idx % #config.separators) + 1]

  local new_cmd = table.concat(parts, sar_state.sep)

  -- Store command and cursor position for helper function
  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #sar_state.sep - #parts[4] + 1

  -- Use <C-\>e to evaluate expression that sets both command and cursor
  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Toggle the magic mode (cycle through configured magic modes)
---@return string keys The keystrokes to execute (uses <C-\>e pattern)
function M.toggle_magic()
  local cmd = vim.fn.getcmdline()
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(cmd, sep, { plain = true }))

  -- Get current magic mode from the search pattern
  local search_pattern = parts[2]
  local current_magic = search_pattern:match('^(\\[vmMV])') or ''

  -- Find next magic mode
  local idx = 0
  for i, m in ipairs(config.magic_modes) do
    if m == current_magic then
      idx = i
      break
    end
  end
  local new_magic = config.magic_modes[(idx % #config.magic_modes) + 1]

  -- Strip old magic and add new magic to search pattern
  local search_without_magic = search_pattern:gsub('^\\[vmMV]', '')
  parts[2] = new_magic .. search_without_magic

  local new_cmd = table.concat(parts, sep)

  -- Store command and cursor position for helper function
  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #sep - #parts[4] + 1

  -- Use <C-\>e to evaluate expression that sets both command and cursor
  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Setup the core module with configuration
---@param opts CoreConfig Configuration options (required, provided by init.lua)
---@return nil
function M.setup(opts)
  -- Config is provided by init.lua from centralized config.lua
  config = opts

  -- Autocommand to deactivate search-replace mode when leaving cmdline
  vim.api.nvim_create_autocmd('CmdlineLeave', {
    pattern = ':',
    callback = function()
      sar_state.active = false
    end,
  })
end

return M
