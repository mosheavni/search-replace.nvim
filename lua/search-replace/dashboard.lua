---@diagnostic disable: undefined-field

---@brief [[
---Dashboard UI for search-replace.nvim.
---
---Displays a floating window showing the current state of the substitute
---command during command-line editing. The dashboard auto-detects substitute
---commands and updates in real-time as you type.
---
---Features:
---- Parses substitute commands and displays range, magic mode, flags
---- Shows search and replace terms with magic prefix stripped
---- Displays keymap hints with active/inactive indicators
---- Uses syntax highlighting via extmarks
---- Respects user's manual toggle (hidden state)
---
---The dashboard uses `CmdlineChanged` autocmd to detect and refresh for any
---substitute command, not just those started via the plugin keymaps.
---@brief ]]

---@tag search-replace.dashboard

---@class SearchReplaceDashboard
---@field invalidate_cache fun() Invalidate the dashboard cache
---@field refresh_dashboard fun(cmdline?: string) Refresh the dashboard with current cmdline state
---@field close_dashboard fun() Close the dashboard
---@field toggle_dashboard fun() Toggle the dashboard visibility
---@field setup fun() Setup autocmds for the dashboard
local M = {}

local utils = require('search-replace.utils')

---Get config from init.lua (lazy-loaded to avoid circular dependency)
---@return SearchReplaceConfig
local function get_config()
  return require('search-replace').get_config()
end

-- Float state (inlined from float.lua)
---@class FloatState
---@field buf_id integer? Buffer ID (nil if not created)
---@field win_id integer? Window ID (nil if not created)
local float_state = {
  buf_id = nil,
  win_id = nil,
}

---@class DashboardState
---@field ns_id integer? Namespace ID for highlights
---@field last_parsed ParsedCommand? Cache of last parsed command
---@field hidden boolean Track if user manually hid the dashboard

---@type DashboardState
local dashboard_state = {
  ns_id = nil,
  last_parsed = nil,
  hidden = false,
}

---@class RefreshState
---@field last_fake_keystroke_time integer Timestamp of last fake keystroke

---@type RefreshState
local refresh_state = {
  last_fake_keystroke_time = 0,
}

-- Float helpers (inlined from float.lua)

---Check if buffer is valid
---@param buf_id integer?
---@return boolean
local function is_valid_buf(buf_id)
  return buf_id ~= nil and vim.api.nvim_buf_is_valid(buf_id)
end

---Check if window is valid
---@param win_id integer?
---@return boolean
local function is_valid_win(win_id)
  return win_id ~= nil and vim.api.nvim_win_is_valid(win_id)
end

---Check if window is in current tabpage
---@param win_id integer
---@return boolean
local function is_win_in_tabpage(win_id)
  return vim.api.nvim_win_get_tabpage(win_id) == vim.api.nvim_get_current_tabpage()
end

---Create a new buffer for the float
---@return integer buf_id The created buffer ID
local function buffer_create()
  local buf_id = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf_id })
  return buf_id
end

---Refresh buffer content with new lines
---@param buf_id integer Buffer ID to refresh
---@param lines string[] Lines to set in buffer
local function buffer_refresh(buf_id, lines)
  vim.api.nvim_set_option_value('modifiable', true, { buf = buf_id })
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, lines)
  vim.api.nvim_set_option_value('modifiable', false, { buf = buf_id })
end

---Close the floating window
local function window_close()
  if is_valid_win(float_state.win_id) then
    vim.api.nvim_win_close(float_state.win_id, true)
    float_state.win_id = nil
  end
end

---Check if the floating window is currently shown
---@return boolean
local function float_is_shown()
  return is_valid_win(float_state.win_id) and is_win_in_tabpage(float_state.win_id)
end

---Trigger a dashboard refresh via fake keystroke
---@return nil
local function trigger_refresh()
  utils.trigger_cmdline_refresh(M.invalidate_cache)
end

---@class KeymapInfo
---@field key string The keymap key combination
---@field flag string? The flag this keymap toggles (nil for non-flag keymaps)
---@field desc string Description of what the keymap does

---Build keymap info array from config
---@return KeymapInfo[]
local function get_keymaps_info()
  local cfg = get_config()
  return {
    { key = cfg.keymaps.toggle_g or '<M-g>', flag = 'g', desc = "Toggle 'g' flag (global)" },
    { key = cfg.keymaps.toggle_c or '<M-c>', flag = 'c', desc = "Toggle 'c' flag (confirm)" },
    { key = cfg.keymaps.toggle_i or '<M-i>', flag = 'i', desc = "Toggle 'i' flag (case-insensitive)" },
    { key = cfg.keymaps.toggle_replace or '<M-d>', flag = nil, desc = 'Toggle replace term' },
    { key = cfg.keymaps.toggle_range or '<M-5>', flag = nil, desc = 'Cycle range' },
    { key = cfg.keymaps.toggle_separator or '<M-/>', flag = nil, desc = 'Cycle separator' },
    { key = cfg.keymaps.toggle_magic or '<M-m>', flag = nil, desc = 'Cycle magic mode' },
    { key = cfg.keymaps.toggle_dashboard or '<M-h>', flag = nil, desc = 'Toggle dashboard' },
  }
end

---@class ParsedCommand
---@field range string The range part (e.g., ".,$s", "%s")
---@field separator string The separator character
---@field magic string The magic mode (e.g., "\\V", "\\v")
---@field search string The search term
---@field replace string The replace term
---@field flags table<string, boolean> Flags as {g=true, c=true, i=false}
---@field raw string The original command

---Parse a substitute command into components (dashboard-specific format with flags as table)
---@param cmdline string The command line content
---@return ParsedCommand|nil parsed The parsed components, or nil if not a valid substitute
local function parse_substitute_command(cmdline)
  -- Use shared utility for basic parsing
  local base = utils.parse_substitute_cmd(cmdline)
  if not base then
    -- Check if it's an incomplete command (just range + separator, no search yet)
    if not cmdline:match('^[%%.,0-9$]*s') then
      return nil
    end
    -- Handle incomplete command
    local range = (cmdline:match('^([%%.,0-9$]*)s') or '') .. 's'
    local after_s = cmdline:sub(#range + 1)
    if #after_s == 0 then
      return nil
    end
    return {
      range = range,
      separator = after_s:sub(1, 1),
      magic = '',
      search = '',
      replace = '',
      flags = { g = false, c = false, i = false },
      raw = cmdline,
    }
  end

  -- Convert to dashboard format (flags as table)
  local flags_str = base.flags or ''
  return {
    range = base.range,
    separator = base.sep,
    magic = base.magic,
    search = base.search,
    replace = base.replace,
    flags = {
      g = flags_str:find('g') ~= nil,
      c = flags_str:find('c') ~= nil,
      i = flags_str:find('i') ~= nil,
    },
    raw = cmdline,
  }
end

---Get description for a range
---@param range string The range part (e.g., "%s", ".,$s")
---@return string description The range description
local function get_range_description(range)
  if range == '%s' then
    return 'Entire file'
  elseif range == '.,$s' then
    return 'Current line to end of file'
  elseif range == '0,.s' then
    return 'Start of file to current line'
  elseif range == 's' or range == '.s' then
    return 'Current line only'
  else
    return 'Custom range'
  end
end

---Format the range display lines
---@param parsed ParsedCommand The parsed command
---@return string[] lines The formatted range lines
local function format_range_lines(parsed)
  local range_value = parsed.range ~= '' and parsed.range or 's'
  local range_desc = get_range_description(range_value)
  return {
    '  Range: ' .. range_value,
    '    -> ' .. range_desc,
  }
end

---Get description for a magic mode
---@param magic string The magic mode (e.g., "\\v", "\\V")
---@return string description The magic mode description
local function get_magic_description(magic)
  if magic == '\\v' then
    return 'Very magic: Extended regex syntax'
  elseif magic == '\\m' then
    return 'Magic: Standard regex syntax (default)'
  elseif magic == '\\M' then
    return 'Nomagic: Minimal regex syntax'
  elseif magic == '\\V' then
    return 'Very nomagic: Literal search'
  else
    return 'Default magic mode'
  end
end

---Format the magic display lines
---@param parsed ParsedCommand The parsed command
---@return string[] lines The formatted magic lines
local function format_magic_lines(parsed)
  local magic_value = parsed.magic ~= '' and parsed.magic or 'none'
  local magic_desc = get_magic_description(parsed.magic)
  return {
    '  Magic: ' .. magic_value,
    '    -> ' .. magic_desc,
  }
end

---Format the status line showing current state (separator and flags)
---@param parsed ParsedCommand The parsed command
---@return string status_line The formatted status line
local function format_status_line(parsed)
  local parts = {}

  -- Separator
  table.insert(parts, 'Sep: ' .. (parsed.separator ~= '' and parsed.separator or '/'))

  -- Flags
  local flags_str = ''
  if parsed.flags.g then
    flags_str = flags_str .. 'g'
  end
  if parsed.flags.c then
    flags_str = flags_str .. 'c'
  end
  if parsed.flags.i then
    flags_str = flags_str .. 'i'
  end
  table.insert(parts, 'Flags: ' .. (flags_str ~= '' and flags_str or 'none'))

  return '  ' .. table.concat(parts, '  ')
end

---Format the search/replace display lines
---@param parsed ParsedCommand The parsed command
---@return string[] lines The formatted search/replace lines
local function format_search_replace_lines(parsed)
  -- Strip magic prefix from search term for display
  local search_display = parsed.search
  if parsed.magic ~= '' then
    search_display = search_display:gsub('^' .. vim.pesc(parsed.magic), '')
  end

  return {
    '  Search:  ' .. search_display,
    '  Replace: ' .. parsed.replace,
  }
end

---Format the keymap lines with state indicators
---@param parsed ParsedCommand The parsed command
---@return string[] keymap_lines The formatted keymap lines
local function format_keymap_lines(parsed)
  local cfg = get_config()
  local keymaps = get_keymaps_info()
  local lines = {}

  for _, km in ipairs(keymaps) do
    local indicator = '  '
    if km.flag then
      -- Check if this flag is active
      if parsed.flags[km.flag] then
        indicator = cfg.dashboard.symbols.active .. ' '
      else
        indicator = cfg.dashboard.symbols.inactive .. ' '
      end
    end

    local line = '  ' .. indicator .. km.key .. '  ->  ' .. km.desc
    table.insert(lines, line)
  end

  return lines
end

---@class HighlightRule
---@field line integer Buffer line index (0-based)
---@field label string Label text to find
---@field label_hl string Highlight group for label
---@field value_hl string Highlight group for value

---Apply a label+value highlight to a line
---@param buf_id integer Buffer ID
---@param ns_id integer Namespace ID
---@param line_idx integer Line index (0-based)
---@param line string Line content
---@param label string Label to find
---@param label_hl string Highlight group for label
---@param value_hl string Highlight group for value
local function highlight_label_value(buf_id, ns_id, line_idx, line, label, label_hl, value_hl)
  local label_pos = line:find(label, 1, true)
  if label_pos then
    vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, label_pos - 1, {
      end_col = label_pos + #label - 1,
      hl_group = label_hl,
    })
    local value_start = label_pos + #label
    vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, value_start, {
      end_col = #line,
      hl_group = value_hl,
    })
  end
end

---Apply arrow and description highlight to a line
---@param buf_id integer Buffer ID
---@param ns_id integer Namespace ID
---@param line_idx integer Line index (0-based)
---@param line string Line content
---@param arrow_hl string Highlight group for arrow
---@param desc_hl string Highlight group for description
local function highlight_arrow_desc(buf_id, ns_id, line_idx, line, arrow_hl, desc_hl)
  local arrow_pos = line:find('->', 1, true)
  if arrow_pos then
    vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, arrow_pos - 1, {
      end_col = arrow_pos + 1,
      hl_group = arrow_hl,
    })
    vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, arrow_pos + 2, {
      end_col = #line,
      hl_group = desc_hl,
    })
  end
end

---Apply highlights to the dashboard buffer
---@param buf_id number The buffer ID
---@param lines string[] The buffer lines
---@param parsed ParsedCommand The parsed command
local function apply_highlights(buf_id, lines, parsed)
  local cfg = get_config()
  local hl = cfg.dashboard.highlights
  local keymaps = get_keymaps_info()

  if not dashboard_state.ns_id then
    dashboard_state.ns_id = vim.api.nvim_create_namespace('SearchReplaceDashboard')
  end
  local ns_id = dashboard_state.ns_id

  vim.api.nvim_buf_clear_namespace(buf_id, ns_id, 0, -1)

  -- Line 0: Title
  vim.api.nvim_buf_set_extmark(buf_id, ns_id, 0, 0, {
    end_col = #lines[1],
    hl_group = hl.title,
  })

  -- Lines 2-3: Range (label + value, arrow + description)
  highlight_label_value(buf_id, ns_id, 2, lines[3], 'Range:', hl.status_label, hl.status_value)
  highlight_arrow_desc(buf_id, ns_id, 3, lines[4], hl.arrow, hl.inactive_desc)

  -- Lines 5-6: Magic (label + value, arrow + description)
  highlight_label_value(buf_id, ns_id, 5, lines[6], 'Magic:', hl.status_label, hl.status_value)
  highlight_arrow_desc(buf_id, ns_id, 6, lines[7], hl.arrow, hl.inactive_desc)

  -- Line 8: Status line (Sep: and Flags:)
  local status_line = lines[9]
  for _, label in ipairs({ 'Sep:', 'Flags:' }) do
    local start_pos = status_line:find(label, 1, true)
    if start_pos then
      vim.api.nvim_buf_set_extmark(buf_id, ns_id, 8, start_pos - 1, {
        end_col = start_pos + #label - 1,
        hl_group = hl.status_label,
      })
      local value_start = start_pos + #label
      local next_label_pos = status_line:find('%s%s[A-Z]', value_start)
      local value_end = next_label_pos or #status_line + 1
      vim.api.nvim_buf_set_extmark(buf_id, ns_id, 8, value_start - 1, {
        end_col = value_end - 1,
        hl_group = hl.status_value,
      })
    end
  end

  -- Lines 10-11: Search and Replace
  highlight_label_value(buf_id, ns_id, 10, lines[11], 'Search:', hl.status_label, hl.status_value)
  highlight_label_value(buf_id, ns_id, 11, lines[12], 'Replace:', hl.status_label, hl.status_value)

  -- Lines 13+: Keymap lines
  for i, km in ipairs(keymaps) do
    local line_idx = 13 + i - 1
    local line = lines[line_idx + 1]
    if not line then
      break
    end

    -- Highlight indicator symbol
    if km.flag then
      local is_active = parsed.flags[km.flag]
      local indicator_hl = is_active and hl.active_indicator or hl.inactive_indicator
      vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, 2, {
        end_col = 3,
        hl_group = indicator_hl,
      })
    end

    -- Highlight keymap key
    local key_start = line:find(km.key, 1, true)
    if key_start then
      vim.api.nvim_buf_set_extmark(buf_id, ns_id, line_idx, key_start - 1, {
        end_col = key_start + #km.key - 1,
        hl_group = hl.key,
      })
    end

    -- Highlight arrow
    highlight_arrow_desc(
      buf_id,
      ns_id,
      line_idx,
      line,
      hl.arrow,
      (km.flag and parsed.flags[km.flag]) and hl.active_desc or hl.inactive_desc
    )
  end
end

---Compute window configuration for centered positioning
---@param buf_id number The buffer ID
---@return table config The window configuration
local function compute_config(buf_id)
  local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)

  -- Calculate window size
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(line))
  end
  local height = #lines

  -- Calculate centered position
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    return {}
  end

  local screen_width = ui.width
  local screen_height = ui.height

  return {
    relative = 'editor',
    width = width + 2,
    height = height,
    col = math.floor((screen_width - width) / 2), -- Center horizontally
    row = math.floor((screen_height - height) / 2) - 5, -- Center vertically (slightly above center)
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    zindex = 50,
  }
end

---Invalidate the dashboard cache to force next refresh
function M.invalidate_cache()
  dashboard_state.last_parsed = nil
end

---Refresh the dashboard with current cmdline state
---@param cmdline? string Optional cmdline to parse (if not provided, reads current)
function M.refresh_dashboard(cmdline)
  -- CRITICAL: Guard for fast events (mini.notify pattern)
  if vim.in_fast_event() then
    return vim.schedule(function()
      M.refresh_dashboard(cmdline)
    end)
  end

  -- Get current command line in safe context
  cmdline = cmdline or vim.fn.getcmdline()

  -- Parse the command
  local parsed = parse_substitute_command(cmdline)
  if not parsed then
    return -- Not a substitute command
  end

  -- Check if command changed (optimization)
  if dashboard_state.last_parsed and dashboard_state.last_parsed.raw == parsed.raw then
    return -- No change, skip refresh
  end

  dashboard_state.last_parsed = parsed

  -- Build content
  local lines = {}
  table.insert(lines, '  Search & Replace')
  table.insert(lines, '')

  -- Add range display
  local range_lines = format_range_lines(parsed)
  for _, line in ipairs(range_lines) do
    table.insert(lines, line)
  end
  table.insert(lines, '')

  -- Add magic display
  local magic_lines = format_magic_lines(parsed)
  for _, line in ipairs(magic_lines) do
    table.insert(lines, line)
  end
  table.insert(lines, '')

  table.insert(lines, format_status_line(parsed))
  table.insert(lines, '')

  -- Add search/replace display
  local search_replace_lines = format_search_replace_lines(parsed)
  for _, line in ipairs(search_replace_lines) do
    table.insert(lines, line)
  end
  table.insert(lines, '')

  local keymap_lines = format_keymap_lines(parsed)
  for _, line in ipairs(keymap_lines) do
    table.insert(lines, line)
  end

  -- Refresh buffer
  local buf_id = float_state.buf_id
  if not is_valid_buf(buf_id) then
    buf_id = buffer_create()
  end
  buffer_refresh(buf_id, lines)

  -- Apply highlights synchronously
  apply_highlights(buf_id, lines, parsed)

  -- Refresh window
  local win_id = float_state.win_id
  if not (is_valid_win(win_id) and is_win_in_tabpage(win_id)) then
    window_close()
    local win_config = compute_config(buf_id)
    win_id = vim.api.nvim_open_win(buf_id, false, win_config)
  else
    local new_config = compute_config(buf_id)
    vim.api.nvim_win_set_config(win_id, new_config)
  end

  -- CRUCIAL: Force redraw
  vim.cmd('redraw')

  -- Update cache
  float_state.buf_id = buf_id
  float_state.win_id = win_id
end

---Close the dashboard
function M.close_dashboard()
  window_close()
  if is_valid_buf(float_state.buf_id) then
    vim.api.nvim_buf_delete(float_state.buf_id, { force = true })
    float_state.buf_id = nil
  end
  dashboard_state.last_parsed = nil
end

---Toggle the dashboard visibility
function M.toggle_dashboard()
  -- Use hidden state directly instead of is_shown() which may not be reliable after scheduled close
  if dashboard_state.hidden then
    -- Currently hidden, show it
    dashboard_state.hidden = false
    trigger_refresh()
  else
    -- Currently shown (or would be shown), hide it
    dashboard_state.hidden = true
    vim.schedule(function()
      M.close_dashboard()
    end)
  end
end

---Setup autocmds for the dashboard
---@return nil
function M.setup()
  local augroup = vim.api.nvim_create_augroup('SearchReplaceDashboard', { clear = true })

  -- Reset hidden state on new cmdline session
  vim.api.nvim_create_autocmd('CmdlineEnter', {
    group = augroup,
    pattern = ':',
    callback = function()
      dashboard_state.hidden = false
    end,
  })

  -- Update dashboard on every keystroke - auto-detect substitute commands
  vim.api.nvim_create_autocmd('CmdlineChanged', {
    group = augroup,
    pattern = ':',
    callback = function()
      -- Don't show if user manually hid it
      if dashboard_state.hidden then
        return
      end

      local cmdline = vim.fn.getcmdline()
      -- Quick check: does it look like a substitute command?
      if not utils.is_substitute_cmd(cmdline) then
        -- Not a substitute command, close dashboard if open
        if float_is_shown() then
          M.close_dashboard()
        end
        return
      end

      -- It's a substitute command - refresh dashboard
      local now = vim.loop.now()
      -- Check if we recently triggered a fake keystroke (to prevent infinite loop)
      if now - refresh_state.last_fake_keystroke_time < 100 then
        -- We're in a fake keystroke cycle, just refresh normally
        M.refresh_dashboard()
      else
        -- Trigger fake keystroke for proper refresh
        refresh_state.last_fake_keystroke_time = now
        trigger_refresh()
      end
    end,
  })

  -- Close dashboard when leaving cmdline
  vim.api.nvim_create_autocmd('CmdlineLeave', {
    group = augroup,
    pattern = ':',
    callback = function()
      M.close_dashboard()
    end,
  })
end

return M
