<!-- markdownlint-disable MD013 -->

# search-replace.nvim

A Neovim plugin for enhanced search and replace with a floating dashboard that shows all available keymaps and current state.

## Features

- **Quick populate**: Press `<leader>r` to populate the command line with a search-replace command using the word under cursor or visual selection
- **Live dashboard**: A floating window that shows all available keymaps and the current state of your search-replace command
- **Toggle flags**: Quickly toggle `g` (global), `c` (confirm), and `i` (case-insensitive) flags
- **Cycle ranges**: Cycle through range options (`%s`, `.,$s`, `0,.s`)
- **Cycle separators**: Change the separator character (`/`, `?`, `#`, `:`, `@`)
- **Cycle magic modes**: Toggle between Vim magic modes (`\v`, `\m`, `\M`, `\V`, none)
- **Toggle replace term**: Quickly clear or restore the replace term
- **Auto-detect**: Dashboard automatically appears when typing any substitute command

## Installation

### lazy.nvim

```lua
{
  'mosheavni/search-replace.nvim',
  config = function()
    require('search-replace').setup()
  end,
}
```

### packer.nvim

```lua
use({
  'mosheavni/search-replace.nvim',
  config = function()
    require('search-replace').setup()
  end,
})
```

### vim-plug

```vim
Plug 'mosheavni/search-replace.nvim'

" In your init.lua or after/plugin:
lua require('search-replace').setup()
```

## Configuration

Here's the default configuration with all available options:

```lua
require('search-replace').setup({
  -- Keymaps configuration
  keymaps = {
    enable = true,
    populate = '<leader>r', -- Normal/Visual mode: populate search-replace
    toggle_g = '<M-g>', -- Toggle global flag
    toggle_c = '<M-c>', -- Toggle confirm flag
    toggle_i = '<M-i>', -- Toggle case-insensitive flag
    toggle_replace = '<M-d>', -- Toggle replace term (clear/restore)
    toggle_range = '<M-5>', -- Cycle range (%s, .,$s, 0,.s)
    toggle_separator = '<M-/>', -- Cycle separator (/, ?, #, :, @)
    toggle_magic = '<M-m>', -- Cycle magic mode (\v, \m, \M, \V, none)
    toggle_dashboard = '<M-h>', -- Toggle dashboard visibility
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
  -- Core settings
  separators = { '/', '?', '#', ':', '@' },
  magic_modes = { '\\v', '\\m', '\\M', '\\V', '' },
  flags = { 'g', 'c', 'i' },
  default_range = '.,$s',
  default_flags = 'gc',
  default_magic = '\\V',
})
```

## Default Keymaps

### Normal/Visual Mode

| Keymap      | Description                                                                           |
| ----------- | ------------------------------------------------------------------------------------- |
| `<leader>r` | Populate command line with search-replace using word under cursor or visual selection |

### Command-line Mode (during search-replace)

| Keymap  | Description                                                     |
| ------- | --------------------------------------------------------------- |
| `<M-g>` | Toggle 'g' flag (global - replace all occurrences on each line) |
| `<M-c>` | Toggle 'c' flag (confirm - ask before each replacement)         |
| `<M-i>` | Toggle 'i' flag (case-insensitive search)                       |
| `<M-d>` | Toggle replace term (clear or restore to original word)         |
| `<M-5>` | Cycle range (%s -> .,$s -> 0,.s -> %s)                          |
| `<M-/>` | Cycle separator (/ -> ? -> # -> : -> @ -> /)                    |
| `<M-m>` | Cycle magic mode (\v -> \m -> \M -> \V -> none -> \v)           |
| `<M-h>` | Toggle dashboard visibility                                     |

Note: `<M-...>` means Alt/Meta key. On macOS, you may need to configure your terminal to send Meta key properly.

## API

The plugin exports the following functions:

```lua
local sr = require('search-replace')

-- Core functions
sr.populate_searchline(mode) -- 'n' for normal, 'v' for visual
sr.toggle_char(char) -- Toggle a flag ('g', 'c', or 'i')
sr.toggle_replace_term() -- Toggle replace term
sr.toggle_all_file() -- Cycle range
sr.toggle_separator() -- Cycle separator
sr.toggle_magic() -- Cycle magic mode
sr.is_active() -- Check if search-replace mode is active
sr.get_config() -- Get current configuration
```

## Magic Modes

Vim's magic modes control how special characters are interpreted in patterns:

| Mode | Description                                        |
| ---- | -------------------------------------------------- |
| `\v` | Very magic: Most characters have special meaning   |
| `\m` | Magic: Standard regex (default Vim behavior)       |
| `\M` | Nomagic: Only `^` and `$` are special              |
| `\V` | Very nomagic: Only `\` is special (literal search) |

The plugin defaults to `\V` (very nomagic) for literal searching.

## Tips

For the best experience, enable Neovim's built-in incremental command preview:

```lua
vim.o.inccommand = 'split' -- Incremental search and replace with small split window
```

This shows a live preview of your substitutions as you type, with matches highlighted in the buffer and a split window showing off-screen changes.

## License

MIT
