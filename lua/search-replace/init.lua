--- search-replace.nvim
--- A Neovim plugin for enhanced search and replace with a floating dashboard
---
--- Usage:
---   require('search-replace').setup({
---     -- your configuration here
---   })
---
---@class SearchReplace
---@field setup fun(opts?: SearchReplaceConfig) Setup the plugin with user configuration
---@field populate_searchline fun(mode: string): string, integer Populate the search line
---@field toggle_char fun(char: string): string Toggle a flag character
---@field toggle_replace_term fun(): string Toggle the replace term
---@field toggle_all_file fun(): string Toggle range (all file)
---@field toggle_separator fun(): string Toggle separator
---@field toggle_magic fun(): string Toggle magic mode
---@field is_active fun(): boolean Check if search-replace mode is active
---@field get_config fun(): SearchReplaceConfig Get the current configuration
local M = {}

local core = require('search-replace.core')
local config_module = require('search-replace.config')

---Setup keymaps for search-replace functionality
---@param keymap_config SearchReplaceKeymapConfig
---@return nil
local function setup_keymaps(keymap_config)
  if not keymap_config.enable then
    return
  end

  -- Normal mode mapping
  if keymap_config.populate then
    vim.keymap.set('n', keymap_config.populate, function()
      local cmd, move_left = core.populate_searchline('n')
      local cursor_keys = string.rep(vim.keycode('<Left>'), move_left)
      vim.fn.feedkeys(':' .. cmd .. cursor_keys, 'n')
    end, { desc = 'Search and replace word under cursor' })

    -- Visual mode mapping
    vim.keymap.set('v', keymap_config.populate, function()
      local cmd, move_left = core.populate_searchline('v')
      local cursor_keys = string.rep(vim.keycode('<Left>'), move_left)
      vim.fn.feedkeys(':' .. vim.keycode('<C-u>') .. cmd .. cursor_keys, 'n')
    end, { desc = 'Search and replace visual selection' })
  end

  -- Command-line mode mappings
  if keymap_config.toggle_g then
    vim.keymap.set('c', keymap_config.toggle_g, function()
      return core.toggle_char('g')
    end, { expr = true, desc = "Toggle 'g' flag" })
  end

  if keymap_config.toggle_c then
    vim.keymap.set('c', keymap_config.toggle_c, function()
      return core.toggle_char('c')
    end, { expr = true, desc = "Toggle 'c' flag" })
  end

  if keymap_config.toggle_i then
    vim.keymap.set('c', keymap_config.toggle_i, function()
      return core.toggle_char('i')
    end, { expr = true, desc = "Toggle 'i' flag" })
  end

  if keymap_config.toggle_replace then
    vim.keymap.set('c', keymap_config.toggle_replace, core.toggle_replace_term, {
      expr = true,
      desc = 'Toggle replace term',
    })
  end

  if keymap_config.toggle_range then
    vim.keymap.set('c', keymap_config.toggle_range, core.toggle_all_file, {
      expr = true,
      desc = 'Toggle range',
    })
  end

  if keymap_config.toggle_separator then
    vim.keymap.set('c', keymap_config.toggle_separator, core.toggle_separator, {
      expr = true,
      desc = 'Toggle separator',
    })
  end

  if keymap_config.toggle_magic then
    vim.keymap.set('c', keymap_config.toggle_magic, core.toggle_magic, {
      expr = true,
      desc = 'Toggle magic mode',
    })
  end

  if keymap_config.toggle_dashboard then
    vim.keymap.set('c', keymap_config.toggle_dashboard, function()
      local ok, dashboard = pcall(require, 'search-replace.dashboard')
      if ok then
        dashboard.toggle_dashboard()
      end
      return ''
    end, { expr = true, desc = 'Toggle search/replace dashboard' })
  end
end

--- Setup the plugin with user configuration
---@param opts? table User configuration options
function M.setup(opts)
  -- Merge user options with defaults in centralized config
  config_module.setup(opts)
  local config = config_module.get()

  -- Setup core module
  core.setup({
    separators = config.separators,
    magic_modes = config.magic_modes,
    flags = config.flags,
    default_range = config.default_range,
    default_flags = config.default_flags,
    default_magic = config.default_magic,
  })

  -- Setup dashboard if enabled
  if config.dashboard.enable then
    local dashboard = require('search-replace.dashboard')
    dashboard.setup({
      symbols = config.dashboard.symbols,
      highlights = config.dashboard.highlights,
      keymaps = {
        { key = config.keymaps.toggle_g or '<M-g>', flag = 'g', desc = "Toggle 'g' flag (global)" },
        { key = config.keymaps.toggle_c or '<M-c>', flag = 'c', desc = "Toggle 'c' flag (confirm)" },
        { key = config.keymaps.toggle_i or '<M-i>', flag = 'i', desc = "Toggle 'i' flag (case-insensitive)" },
        { key = config.keymaps.toggle_replace or '<M-d>', flag = nil, desc = 'Toggle replace term' },
        { key = config.keymaps.toggle_range or '<M-5>', flag = nil, desc = 'Cycle range' },
        { key = config.keymaps.toggle_separator or '<M-/>', flag = nil, desc = 'Cycle separator' },
        { key = config.keymaps.toggle_magic or '<M-m>', flag = nil, desc = 'Cycle magic mode' },
        { key = config.keymaps.toggle_dashboard or '<M-h>', flag = nil, desc = 'Toggle dashboard' },
      },
    })
  end

  -- Setup keymaps if enabled
  if config.keymaps.enable then
    setup_keymaps(config.keymaps)
  end
end

---@type fun(mode: string): string, integer
M.populate_searchline = core.populate_searchline
---@type fun(char: string): string
M.toggle_char = core.toggle_char
---@type fun(): string
M.toggle_replace_term = core.toggle_replace_term
---@type fun(): string
M.toggle_all_file = core.toggle_all_file
---@type fun(): string
M.toggle_separator = core.toggle_separator
---@type fun(): string
M.toggle_magic = core.toggle_magic
---@type fun(): boolean
M.is_active = core.is_active

---Get the current configuration
---@return SearchReplaceConfig config The current configuration
function M.get_config()
  return config_module.get()
end

return M
