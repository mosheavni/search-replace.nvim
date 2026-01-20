--- Centralized configuration for search-replace.nvim
--- All default values and type definitions live here

---@class SearchReplaceKeymapConfig
---@field enable boolean Whether to enable keymaps
---@field populate? string Normal/Visual mode keymap to populate search line
---@field toggle_g? string Keymap to toggle global flag
---@field toggle_c? string Keymap to toggle confirm flag
---@field toggle_i? string Keymap to toggle case-insensitive flag
---@field toggle_replace? string Keymap to toggle replace term
---@field toggle_range? string Keymap to cycle range
---@field toggle_separator? string Keymap to cycle separator
---@field toggle_magic? string Keymap to cycle magic mode
---@field toggle_dashboard? string Keymap to toggle dashboard

---@class SearchReplaceDashboardSymbols
---@field active string Symbol for active flag indicator
---@field inactive string Symbol for inactive flag indicator

---@class SearchReplaceDashboardHighlights
---@field title string Highlight group for title
---@field key string Highlight group for key
---@field arrow string Highlight group for arrow
---@field active_desc string Highlight group for active description
---@field inactive_desc string Highlight group for inactive description
---@field active_indicator string Highlight group for active indicator
---@field inactive_indicator string Highlight group for inactive indicator
---@field status_label string Highlight group for status label
---@field status_value string Highlight group for status value

---@class SearchReplaceDashboardConfig
---@field enable boolean Whether to enable the dashboard
---@field symbols SearchReplaceDashboardSymbols Visual symbols configuration
---@field highlights SearchReplaceDashboardHighlights Highlight groups configuration

---@class SearchReplaceConfig
---@field keymaps SearchReplaceKeymapConfig Keymaps configuration
---@field dashboard SearchReplaceDashboardConfig Dashboard configuration
---@field separators string[] Available separator characters
---@field magic_modes string[] Available magic modes
---@field flags string[] Available flags
---@field default_range string Default range for substitute command
---@field default_flags string Default flags for substitute command
---@field default_magic string Default magic mode

---@class ConfigModule
---@field defaults SearchReplaceConfig The default configuration
---@field current SearchReplaceConfig The current merged configuration
---@field setup fun(opts?: table) Merge user options with defaults
---@field get fun(): SearchReplaceConfig Get the current configuration
local M = {}

---@type SearchReplaceConfig
M.defaults = {
  -- Keymaps configuration
  keymaps = {
    enable = true,
    populate = '<leader>r', -- Normal/Visual mode
    toggle_g = '<M-g>', -- Toggle global flag
    toggle_c = '<M-c>', -- Toggle confirm flag
    toggle_i = '<M-i>', -- Toggle case-insensitive
    toggle_replace = '<M-d>', -- Toggle replace term
    toggle_range = '<M-5>', -- Cycle range
    toggle_separator = '<M-/>', -- Cycle separator
    toggle_magic = '<M-m>', -- Cycle magic mode
    toggle_dashboard = '<M-h>', -- Toggle dashboard
  },
  -- Dashboard configuration
  dashboard = {
    enable = true,
    symbols = {
      active = '●', -- Active flag indicator
      inactive = '○', -- Inactive flag indicator
    },
    highlights = {
      title = 'Title',
      key = 'Special',
      arrow = 'Comment',
      active_desc = 'String',
      inactive_desc = 'Comment',
      active_indicator = 'DiagnosticOk',
      inactive_indicator = 'Comment',
      status_label = 'Comment',
      status_value = 'Constant',
    },
  },
  -- Core configuration
  separators = { '/', '?', '#', ':', '@' },
  magic_modes = { '\\v', '\\m', '\\M', '\\V', '' },
  flags = { 'g', 'c', 'i' },
  default_range = '.,$s',
  default_flags = 'gc',
  default_magic = '\\V',
}

---@type SearchReplaceConfig
M.current = vim.deepcopy(M.defaults)

---Setup configuration by merging user options with defaults
---@param opts? table User configuration options
function M.setup(opts)
  opts = opts or {}
  M.current = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts)
end

---Get the current configuration
---@return SearchReplaceConfig
function M.get()
  return M.current
end

return M
