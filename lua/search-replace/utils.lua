--- Shared utilities for search-replace functionality
--- Part of search-replace.nvim plugin
---
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
M.SUBSTITUTE_PATTERN = '^[%%.,0-9$]*s.'
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

---Trigger a cmdline refresh via fake keystroke
---This is needed because direct refresh calls don't work properly in cmdline mode
---@param invalidate_fn? fun() Optional function to call before triggering (e.g., cache invalidation)
---@return nil
function M.trigger_cmdline_refresh(invalidate_fn)
  vim.defer_fn(function()
    if invalidate_fn then
      invalidate_fn()
    end
    vim.fn.feedkeys(' ' .. vim.keycode('<BS>'), 'in')
  end, 50)
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
