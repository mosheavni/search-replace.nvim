-- Luacheck configuration for Neovim Lua plugins

-- Global objects
globals = {
  "vim",
}

-- Read-only globals
read_globals = {
  "vim",
}

-- Don't report unused self arguments of methods
self = false

-- Don't report unused arguments when they start with underscore
unused_args = false

-- Max line length
max_line_length = 120

-- Ignore some warnings
ignore = {
  "212", -- Unused argument
  "631", -- Line is too long
}

-- Exclude test files from some checks
files["tests/**/*.lua"] = {
  globals = {
    "describe",
    "it",
    "before_each",
    "after_each",
    "assert",
  }
}
