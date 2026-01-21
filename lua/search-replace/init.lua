---@toc search-replace.contents

---@mod search-replace.nvim Introduction
---@brief [[
---search-replace.nvim is a Neovim plugin for enhanced search and replace with
---a floating dashboard.
---
---Features:
---- Quick keymaps to populate substitute commands with word under cursor
---- Toggle flags (g/c/i) during command-line editing
---- Cycle through ranges, separators, and magic modes
---- Live dashboard showing current state during editing
---- Auto-detect any substitute command to show the dashboard
---@brief ]]

---@mod search-replace.installation Installation
---@brief [[
---lazy.nvim:
--->lua
---    {
---      'mosheavni/search-replace.nvim',
---      config = function()
---        require('search-replace').setup()
---      end,
---    }
---<
---
---packer.nvim:
--->lua
---    use({
---      'mosheavni/search-replace.nvim',
---      config = function()
---        require('search-replace').setup()
---      end,
---    })
---<
---
---vim-plug:
--->vim
---    Plug 'mosheavni/search-replace.nvim'
---
---    " In your init.lua or after/plugin:
---    lua require('search-replace').setup()
---<
---@brief ]]

---@mod search-replace.keymaps Default Keymaps
---@brief [[
---Normal/Visual Mode:
---  `<leader>r` - Populate command line with search-replace using word under
---                cursor or visual selection
---
---Command-line Mode (during search-replace):
---  `<M-g>` - Toggle 'g' flag (global - replace all occurrences on each line)
---  `<M-c>` - Toggle 'c' flag (confirm - ask before each replacement)
---  `<M-i>` - Toggle 'i' flag (case-insensitive search)
---  `<M-d>` - Toggle replace term (clear or restore to original word)
---  `<M-5>` - Cycle range (%s -> .,$s -> 0,.s -> %s)
---  `<M-/>` - Cycle separator (/ -> ? -> # -> : -> @ -> /)
---  `<M-m>` - Cycle magic mode (\v -> \m -> \M -> \V -> none -> \v)
---  `<M-h>` - Toggle dashboard visibility
---
---Note: `<M-...>` means Alt/Meta key. On macOS, you may need to configure
---your terminal to send Meta key properly.
---@brief ]]

---@mod search-replace.magic Magic Modes
---@brief [[
---Vim's magic modes control how special characters are interpreted in patterns:
---
---  `\v` - Very magic: Most characters have special meaning (like Perl regex)
---  `\m` - Magic: Standard regex (default Vim behavior)
---  `\M` - Nomagic: Only `^` and `$` are special
---  `\V` - Very nomagic: Only `\` is special (literal search)
---
---The plugin defaults to `\V` (very nomagic) for literal searching, which is
---often what you want when replacing exact text.
---@brief ]]

---@mod search-replace.tips Tips
---@brief [[
---For the best experience, enable Neovim's built-in incremental command preview:
--->lua
---    vim.o.inccommand = 'split'
---<
---
---This shows a live preview of your substitutions as you type, with matches
---highlighted in the buffer and a split window showing off-screen changes.
---@brief ]]

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
    dashboard.setup()
  end

  -- Setup keymaps if enabled
  if config.keymaps.enable then
    setup_keymaps(config.keymaps)
  end
end

-- Re-export core functions (see search-replace.api for documentation)
M.populate_searchline = core.populate_searchline
M.toggle_char = core.toggle_char
M.toggle_replace_term = core.toggle_replace_term
M.toggle_all_file = core.toggle_all_file
M.toggle_separator = core.toggle_separator
M.toggle_magic = core.toggle_magic
M.is_active = core.is_active

-- Re-export config function
M.get_config = config_module.get

return M
