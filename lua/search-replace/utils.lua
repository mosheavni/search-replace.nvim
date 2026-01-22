---@brief [[
---Shared utilities for search-replace.nvim.
---
---This module provides common functions used across the plugin:
---- Pattern constants for substitute command detection
---- `parse_substitute_cmd()` - Parses `:s` commands into components
---- `split_by_separator()` - Splits strings while respecting escaped separators
---- `trigger_cmdline_refresh()` - Forces cmdline refresh via fake keystroke
---- `normalize_parts()` - Ensures command parts array has 4 elements
---- `get_visual_selection()` - Retrieves visual selection text
---
---The fake keystroke technique (space + backspace) is used for toggle operations
---to trigger CmdlineChanged and properly refresh the dashboard. This is only
---used for one-time operations (toggles), not during typing, to avoid
---interfering with inccommand preview.
---@brief ]]

---@tag search-replace.utils

---@class SearchReplaceUtils
---@field SUBSTITUTE_PATTERN string Pattern to match substitute commands
---@field MAGIC_PATTERN string Pattern to match magic mode prefixes
---@field is_substitute_cmd fun(cmd: string): boolean Check if a command looks like a substitute command
---@field split_by_separator fun(str: string, sep: string): string[] Split string by separator, respecting escapes
---@field parse_substitute_cmd fun(cmd: string): ParsedSubstituteCmd|nil Parse a substitute command into components
---@field trigger_cmdline_refresh fun(invalidate_fn?: function) Trigger a cmdline refresh via fake keystroke
---@field normalize_parts fun(parts: string[]): string[] Normalize command parts to always have 4 elements
---@field get_visual_selection fun(): string Get the visual selection and exit visual mode
local M = {}

---@type string
-- Requires a non-alphanumeric, non-whitespace separator after 's' to avoid matching :set, :sort, etc.
M.SUBSTITUTE_PATTERN = '^[%%.,0-9$]*s[^%w%s]'
---@type string
M.MAGIC_PATTERN = '^(\\[vmMV])'

---@class ParsedSubstituteCmd
---@field sep string The separator character
---@field range string The range part (e.g., ".,$s", "%s")
---@field magic string The magic mode (e.g., "\\V", "\\v")
---@field search string The search term
---@field replace string The replace term
---@field flags string Flags (e.g., "gc", "gi")

---Check if a command looks like a substitute command
---@param cmd string The command to check
---@return boolean
function M.is_substitute_cmd(cmd)
  return cmd and cmd:match(M.SUBSTITUTE_PATTERN) ~= nil
end

---Split string by separator, respecting escapes
---@param str string The string to split
---@param sep string The separator character
---@return string[] parts The split parts
function M.split_by_separator(str, sep)
  local parts = {}
  local current = ''
  local i = 1

  while i <= #str do
    local char = str:sub(i, i)

    if char == '\\' and i < #str then
      -- Escaped character - include both backslash and next char
      current = current .. char .. str:sub(i + 1, i + 1)
      i = i + 2
    elseif char == sep then
      -- Unescaped separator - split here
      table.insert(parts, current)
      current = ''
      i = i + 1
    else
      current = current .. char
      i = i + 1
    end
  end

  -- Add remaining content
  table.insert(parts, current)

  return parts
end

---Parse a substitute command into components
---@param cmd string The command line content
---@return ParsedSubstituteCmd|nil parsed The parsed components, or nil if not valid
function M.parse_substitute_cmd(cmd)
  if not cmd or not M.is_substitute_cmd(cmd) then
    return nil
  end

  -- Extract range (everything before 's')
  local range = cmd:match('^([%%.,0-9$]*)s') or ''
  range = range .. 's'

  -- Get the separator (first character after the range)
  local after_range = cmd:sub(#range + 1)
  if #after_range == 0 then
    return nil
  end

  local sep = after_range:sub(1, 1)

  -- Split by separator to get parts (respecting escapes)
  local parts = M.split_by_separator(after_range:sub(2), sep)

  local search = parts[1] or ''
  local replace = parts[2] or ''
  local flags = parts[3] or ''

  -- Extract magic mode from search
  local magic = search:match(M.MAGIC_PATTERN) or ''

  return {
    sep = sep,
    range = range,
    magic = magic,
    search = search,
    replace = replace,
    flags = flags,
  }
end

---Trigger a cmdline refresh via fake keystroke (space + backspace)
---This triggers CmdlineChanged which properly refreshes the dashboard.
---Only use this for one-time operations (toggles), not for every keystroke.
---@param invalidate_fn? fun() Optional function to call before triggering (e.g., cache invalidation)
---@return nil
function M.trigger_cmdline_refresh(invalidate_fn)
  vim.defer_fn(function()
    if invalidate_fn then
      invalidate_fn()
    end
    -- Save cursor position before triggering refresh
    local pos = vim.fn.getcmdpos()
    local cmd_len = #vim.fn.getcmdline()
    -- Calculate how many <Left> keys needed to restore position after going to end
    local chars_to_move_left = cmd_len - pos + 1

    -- Go to end, insert space, delete it, then restore position
    -- This triggers CmdlineChanged which refreshes the dashboard
    -- Use 't' flag to handle keys as if typed (needed for inccommand)
    local restore_keys = string.rep(vim.keycode('<Left>'), chars_to_move_left)
    vim.api.nvim_feedkeys(vim.keycode('<End>') .. ' ' .. vim.keycode('<BS>') .. restore_keys, 'nt', true)
  end, 10)
end

---Normalize command parts to always have 4 elements: range, search, replace, flags
---Fills in missing parts with sensible defaults
---@param parts string[] The parts to normalize
---@return string[] parts The normalized parts (always 4 elements)
function M.normalize_parts(parts)
  if #parts < 2 then
    table.insert(parts, '') -- Add empty search
  end
  if #parts < 3 then
    table.insert(parts, parts[2]) -- Copy search to replace
  end
  if #parts < 4 then
    table.insert(parts, '') -- Add empty flags
  end
  return parts
end

---Get the visual selection and exit visual mode
---@return string text The selected text
function M.get_visual_selection()
  local esc = vim.keycode('<esc>')
  vim.api.nvim_feedkeys(esc, 'x', false)
  local vstart = vim.fn.getpos("'<")
  local vend = vim.fn.getpos("'>")
  return table.concat(vim.fn.getregion(vstart, vend), '\n')
end

return M
