---@mod search-replace.api API
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

function M.is_active()
  return sar_state.active
end

function M.set_cmd_and_pos()
  vim.fn.setcmdpos(sar_state.cursor_pos)

  -- Trigger dashboard refresh by invalidating cache and simulating a keystroke
  local ok, dashboard = pcall(require, 'search-replace.dashboard')
  if ok and dashboard and dashboard.invalidate_cache then
    utils.trigger_cmdline_refresh(dashboard.invalidate_cache)
  end

  return sar_state.new_cmd
end

---Apply a toggle transformation to the current command
---@param transform_fn fun(parts: string[], sep: string): string[], string Function that transforms parts and returns (new_parts, new_sep)
---@return string keystrokes The keystrokes to return from the expr mapping
local function apply_toggle(transform_fn)
  if not should_sar() then
    return ''
  end

  local sep = get_current_sep()
  local parts = utils.normalize_parts(vim.split(vim.fn.getcmdline(), sep, { plain = true }))

  local new_parts, new_sep = transform_fn(parts, sep)
  local new_cmd = table.concat(new_parts, new_sep)

  sar_state.new_cmd = new_cmd
  sar_state.cursor_pos = #new_cmd - #new_sep - #new_parts[4] + 1

  return vim.keycode('<C-\\>e')
    .. 'luaeval(\'require("search-replace.core").set_cmd_and_pos()\')'
    .. vim.keycode('<CR>')
end

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

function M.toggle_separator()
  return apply_toggle(function(parts, old_sep)
    -- Find next separator
    local idx = 0
    for i, c in ipairs(config.separators) do
      if c == old_sep then
        idx = i
        break
      end
    end
    local new_sep = config.separators[(idx % #config.separators) + 1]
    sar_state.sep = new_sep
    return parts, new_sep
  end)
end

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

-- Internal setup function (not documented to avoid tag conflicts)
local function setup(opts)
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

M.setup = setup

return M
