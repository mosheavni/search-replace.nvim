---@mod search_replace API
---@brief [[
---The plugin exports the following functions via `require('search-replace')`:
---
--->lua
---    local sr = require('search-replace')
---
---    -- Core functions
---    sr.populate_searchline(mode) -- 'n' for normal, 'v' for visual
---    sr.toggle_char(char)         -- Toggle a flag ('g', 'c', or 'i')
---    sr.toggle_replace_term()     -- Toggle replace term
---    sr.toggle_all_file()         -- Cycle range
---    sr.toggle_separator()        -- Cycle separator
---    sr.toggle_magic()            -- Cycle magic mode
---    sr.is_active()               -- Check if search-replace mode is active
---    sr.get_config()              -- Get current configuration
---<
---
---Implementation details:
---- Toggle functions return keystroke sequences using the `<C-\>e` expression
---  pattern, which allows replacing the entire command line via expression
---  evaluation
---- All toggle functions use `set_cmd_and_pos()` to update command and cursor
---  atomically
---@brief ]]

local M = {}

local utils = require('search-replace.utils')

-- Config is set by setup() from init.lua, which uses centralized config.lua defaults
local config

local sar_state = {
  active = false,
  cword = '',
  sep = '/',
  magic = '\\V',
  new_cmd = '',
  cursor_pos = 0,
}

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

local function get_current_sep()
  if sar_state.active then
    return sar_state.sep
  end
  local parsed = utils.parse_substitute_cmd(vim.fn.getcmdline())
  return parsed and parsed.sep or '/'
end

local function find_unique_char(char_list, str)
  for _, char in ipairs(char_list) do
    if not str:find(vim.pesc(char), 1, true) then
      return char
    end
  end
  return ''
end

---Check if search-replace mode is active
---
---Returns true when the user has initiated a search-replace session via the
---populate keymap (e.g., `<leader>r`). This is useful for conditional logic
---in custom keymaps or scripts.
---@return boolean active True if search-replace mode is active
function M.is_active()
  return sar_state.active
end

---@private
---Set the command line text and cursor position
---Used internally by toggle functions via expression evaluation
---@return string cmd The new command line text
function M.set_cmd_and_pos()
  vim.fn.setcmdpos(sar_state.cursor_pos)

  -- Trigger dashboard refresh via fake keystroke
  -- This causes a one-time CmdlineChanged event which refreshes the dashboard
  local ok, dashboard = pcall(require, 'search-replace.dashboard')
  if ok and dashboard and dashboard.invalidate_cache then
    utils.trigger_cmdline_refresh(dashboard.invalidate_cache)
  end

  return sar_state.new_cmd
end

---Get parts from current command line using proper parsing
---@param sep string The separator character
---@return string[] parts The command parts [range, search, replace, flags]
local function get_cmd_parts(sep)
  local cmdline = vim.fn.getcmdline()
  local parsed = utils.parse_substitute_cmd(cmdline)

  if parsed then
    -- Use properly parsed components
    return { parsed.range, parsed.search, parsed.replace, parsed.flags }
  end

  -- Fallback: split by separator respecting escapes
  local after_range = cmdline:match('^([%%.,0-9$]*s)') or ''
  local rest = cmdline:sub(#after_range + 2) -- +2 to skip past separator
  local split_parts = utils.split_by_separator(rest, sep)

  return utils.normalize_parts({ after_range, split_parts[1] or '', split_parts[2] or '', split_parts[3] or '' })
end

---Apply a toggle transformation to the current command
---@param transform_fn fun(parts: string[], sep: string): string[], string Function that transforms parts and returns (new_parts, new_sep)
---@return string keystrokes The keystrokes to return from the expr mapping
local function apply_toggle(transform_fn)
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = get_cmd_parts(sep)

  local new_parts, new_sep = transform_fn(parts, sep)
  local new_cmd = table.concat(new_parts, new_sep)

  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #new_sep - #new_parts[4] + 1

  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

---Populate the command line with a substitute command
---
---Builds a substitute command using the word under cursor (normal mode) or
---visual selection (visual mode). The command uses the configured default
---range, flags, and magic mode.
---@param mode string Mode: 'n' for normal mode, 'v' for visual mode
---@return string cmd The substitute command string
---@return integer move_left Number of characters to move cursor left (to position at end of replace term)
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

---Toggle a flag character in the substitute command
---
---Adds or removes a flag ('g', 'c', or 'i') from the current substitute command.
---Flags are maintained in a consistent order as defined in configuration.
---@param char string The flag character to toggle ('g', 'c', or 'i')
---@return string keystrokes Keystroke sequence for expression mapping
function M.toggle_char(char)
  return apply_toggle(function(parts, sep)
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
    return parts, sep
  end)
end

---Toggle the replace term between empty and original word
---
---Clears the replace term (for delete operations) or restores it to the
---original word under cursor. Useful for quickly switching between
---replace and delete operations.
---@return string keystrokes Keystroke sequence for expression mapping
function M.toggle_replace_term()
  return apply_toggle(function(parts, sep)
    -- Use stored cword if in active mode, otherwise use search term or empty
    local current_replace = parts[3]
    local search_term = parts[2]
    local replace_term = current_replace == '' and (sar_state.active and sar_state.cword or search_term) or ''
    parts[3] = replace_term
    return parts, sep
  end)
end

---Cycle through range options for the substitute command
---
---Cycles through: `%s` (whole file) -> `.,$s` (cursor to end) ->
---`0,.s` (start to cursor) -> `%s` (whole file)
---@return string keystrokes Keystroke sequence for expression mapping
function M.toggle_all_file()
  return apply_toggle(function(parts, sep)
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
    return parts, sep
  end)
end

---Cycle through separator characters for the substitute command
---
---Cycles through configured separators (default: `/`, `?`, `#`, `:`, `@`).
---Automatically skips separators that appear in the search or replace terms.
---Useful when dealing with paths or URLs that contain `/`.
---@return string keystrokes Keystroke sequence for expression mapping
function M.toggle_separator()
  return apply_toggle(function(parts, old_sep)
    local search = parts[2]
    local replace = parts[3]

    -- Find current separator index
    local idx = 0
    for i, c in ipairs(config.separators) do
      if c == old_sep then
        idx = i
        break
      end
    end

    -- Find next valid separator (one that doesn't appear in search or replace)
    local new_sep = old_sep
    for _ = 1, #config.separators do
      idx = (idx % #config.separators) + 1
      local candidate = config.separators[idx]
      -- Check if candidate appears in search or replace (plain text search)
      local in_search = search:find(candidate, 1, true)
      local in_replace = replace:find(candidate, 1, true)
      if not in_search and not in_replace then
        new_sep = candidate
        break
      end
    end

    sar_state.sep = new_sep
    return parts, new_sep
  end)
end

---Cycle through magic modes for pattern matching
---
---Cycles through: `\v` (very magic) -> `\m` (magic) -> `\M` (nomagic) ->
---`\V` (very nomagic/literal) -> none -> `\v`
---See |/magic| for details on each mode.
---@return string keystrokes Keystroke sequence for expression mapping
function M.toggle_magic()
  return apply_toggle(function(parts, sep)
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

    return parts, sep
  end)
end

---@private
function M._init(opts)
  config = opts
  vim.api.nvim_create_autocmd('CmdlineLeave', {
    pattern = ':',
    callback = function()
      sar_state.active = false
    end,
  })
end

return M
