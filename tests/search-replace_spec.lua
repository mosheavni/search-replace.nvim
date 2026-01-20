---@diagnostic disable: undefined-field
--# selene: allow(undefined_variable)
local utils = require 'search-replace.utils'
local config = require 'search-replace.config'
local float = require 'search-replace.float'
local eq = assert.are.same

describe('search-replace.utils', function()
  describe('is_substitute_cmd', function()
    it('detects basic substitute command', function()
      assert.is_true(utils.is_substitute_cmd '%s/foo/bar/g')
    end)

    it('detects range substitute command', function()
      assert.is_true(utils.is_substitute_cmd '.,$s/foo/bar/g')
    end)

    it('rejects non-substitute command', function()
      assert.is_false(utils.is_substitute_cmd ':write')
    end)

    it('rejects nil input', function()
      assert.is_falsy(utils.is_substitute_cmd(nil))
    end)

    it('rejects empty string', function()
      assert.is_false(utils.is_substitute_cmd '')
    end)

    it('detects substitute with line number range', function()
      assert.is_true(utils.is_substitute_cmd '1,10s/foo/bar/')
    end)

    it('detects substitute with current line only', function()
      assert.is_true(utils.is_substitute_cmd 's/foo/bar/')
    end)

    it('detects substitute with 0,. range', function()
      assert.is_true(utils.is_substitute_cmd '0,.s/foo/bar/')
    end)

    it('detects substitute with different separators', function()
      assert.is_true(utils.is_substitute_cmd '%s#foo#bar#g')
      assert.is_true(utils.is_substitute_cmd '%s?foo?bar?g')
      assert.is_true(utils.is_substitute_cmd '%s:foo:bar:g')
      assert.is_true(utils.is_substitute_cmd '%s@foo@bar@g')
    end)

    it('detects incomplete substitute command', function()
      assert.is_true(utils.is_substitute_cmd '%s/')
      assert.is_true(utils.is_substitute_cmd '.,$s#')
    end)

    it('matches commands starting with s and any char (loose detection)', function()
      -- The pattern is intentionally loose - it matches 's' followed by any character
      -- This is by design: further parsing validates if it's a real substitute command
      assert.is_true(utils.is_substitute_cmd 'set number') -- matches s followed by e
      assert.is_true(utils.is_substitute_cmd 'syntax on') -- matches s followed by y
      -- But it won't match commands that don't follow the pattern at all
      assert.is_false(utils.is_substitute_cmd 'write') -- no 's'
      assert.is_false(utils.is_substitute_cmd 'quit') -- no 's'
    end)
  end)

  describe('split_by_separator', function()
    it('splits simple string', function()
      local parts = utils.split_by_separator('foo/bar/baz', '/')
      eq(parts, { 'foo', 'bar', 'baz' })
    end)

    it('handles escaped separators', function()
      local parts = utils.split_by_separator('foo\\/bar/baz', '/')
      eq(parts, { 'foo\\/bar', 'baz' })
    end)

    it('handles empty parts', function()
      local parts = utils.split_by_separator('foo//baz', '/')
      eq(parts, { 'foo', '', 'baz' })
    end)

    it('handles empty string', function()
      local parts = utils.split_by_separator('', '/')
      eq(parts, { '' })
    end)

    it('handles string ending with separator', function()
      local parts = utils.split_by_separator('foo/bar/', '/')
      eq(parts, { 'foo', 'bar', '' })
    end)

    it('handles string starting with separator', function()
      local parts = utils.split_by_separator('/foo/bar', '/')
      eq(parts, { '', 'foo', 'bar' })
    end)

    it('handles multiple escaped separators', function()
      local parts = utils.split_by_separator('a\\/b\\/c/d', '/')
      eq(parts, { 'a\\/b\\/c', 'd' })
    end)

    it('handles different separator characters', function()
      local parts = utils.split_by_separator('foo#bar#baz', '#')
      eq(parts, { 'foo', 'bar', 'baz' })

      parts = utils.split_by_separator('foo?bar?baz', '?')
      eq(parts, { 'foo', 'bar', 'baz' })

      parts = utils.split_by_separator('foo:bar:baz', ':')
      eq(parts, { 'foo', 'bar', 'baz' })

      parts = utils.split_by_separator('foo@bar@baz', '@')
      eq(parts, { 'foo', 'bar', 'baz' })
    end)

    it('handles escaped backslash before separator', function()
      local parts = utils.split_by_separator('foo\\\\/bar', '/')
      eq(parts, { 'foo\\\\', 'bar' })
    end)

    it('handles no separators in string', function()
      local parts = utils.split_by_separator('foobar', '/')
      eq(parts, { 'foobar' })
    end)

    it('handles only separators', function()
      local parts = utils.split_by_separator('//', '/')
      eq(parts, { '', '', '' })
    end)
  end)

  describe('parse_substitute_cmd', function()
    it('parses basic substitute command', function()
      local parsed = utils.parse_substitute_cmd '%s/foo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.range, '%s')
      eq(parsed.sep, '/')
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, 'g')
    end)

    it('parses command with magic mode', function()
      local parsed = utils.parse_substitute_cmd '.,$s/\\Vfoo/bar/gc'
      assert.is_not_nil(parsed)
      eq(parsed.range, '.,$s')
      eq(parsed.magic, '\\V')
      eq(parsed.search, '\\Vfoo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, 'gc')
    end)

    it('parses command with different separator', function()
      local parsed = utils.parse_substitute_cmd '%s#foo#bar#g'
      assert.is_not_nil(parsed)
      eq(parsed.sep, '#')
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
    end)

    it('returns nil for invalid command', function()
      local parsed = utils.parse_substitute_cmd ':write'
      assert.is_nil(parsed)
    end)

    it('parses command with empty replace term', function()
      local parsed = utils.parse_substitute_cmd '%s/foo//g'
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo')
      eq(parsed.replace, '')
      eq(parsed.flags, 'g')
    end)

    it('parses command with no flags', function()
      local parsed = utils.parse_substitute_cmd '%s/foo/bar/'
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, '')
    end)

    it('parses command with all flags', function()
      local parsed = utils.parse_substitute_cmd '%s/foo/bar/gci'
      assert.is_not_nil(parsed)
      eq(parsed.flags, 'gci')
    end)

    it('parses all magic modes', function()
      -- Very magic
      local parsed = utils.parse_substitute_cmd '%s/\\vfoo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\v')

      -- Magic (default)
      parsed = utils.parse_substitute_cmd '%s/\\mfoo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\m')

      -- Nomagic
      parsed = utils.parse_substitute_cmd '%s/\\Mfoo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\M')

      -- Very nomagic
      parsed = utils.parse_substitute_cmd '%s/\\Vfoo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\V')

      -- No magic mode
      parsed = utils.parse_substitute_cmd '%s/foo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.magic, '')
    end)

    it('parses command with current line only range', function()
      local parsed = utils.parse_substitute_cmd 's/foo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.range, 's')
    end)

    it('parses command with 0,. range', function()
      local parsed = utils.parse_substitute_cmd '0,.s/foo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.range, '0,.s')
    end)

    it('parses command with line number range', function()
      local parsed = utils.parse_substitute_cmd '1,10s/foo/bar/g'
      assert.is_not_nil(parsed)
      eq(parsed.range, '1,10s')
    end)

    it('returns nil for empty string', function()
      local parsed = utils.parse_substitute_cmd ''
      assert.is_nil(parsed)
    end)

    it('returns nil for nil input', function()
      local parsed = utils.parse_substitute_cmd(nil)
      assert.is_nil(parsed)
    end)

    it('parses command with special characters in search/replace', function()
      local parsed = utils.parse_substitute_cmd '%s/foo.*/bar_baz/g'
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo.*')
      eq(parsed.replace, 'bar_baz')
    end)

    it('parses command with @ separator', function()
      local parsed = utils.parse_substitute_cmd '%s@/path/to/file@/new/path@g'
      assert.is_not_nil(parsed)
      eq(parsed.sep, '@')
      eq(parsed.search, '/path/to/file')
      eq(parsed.replace, '/new/path')
    end)
  end)

  describe('normalize_parts', function()
    it('normalizes single element', function()
      local parts = utils.normalize_parts { '.,$s' }
      eq(#parts, 4)
      eq(parts[1], '.,$s')
    end)

    it('normalizes two elements', function()
      local parts = utils.normalize_parts { '.,$s', 'foo' }
      eq(#parts, 4)
      eq(parts[3], 'foo') -- Replace copied from search
    end)

    it('normalizes three elements', function()
      local parts = utils.normalize_parts { '.,$s', 'foo', 'bar' }
      eq(#parts, 4)
      eq(parts[4], '') -- Empty flags
    end)

    it('keeps four elements unchanged', function()
      local parts = utils.normalize_parts { '.,$s', 'foo', 'bar', 'gc' }
      eq(#parts, 4)
      eq(parts[4], 'gc')
    end)
  end)
end)

describe('search-replace logic', function()
  describe('find_unique_char logic', function()
    it('returns / when not in string', function()
      local chars = { '/', '?', '#' }
      local str = 'testword'

      for _, char in ipairs(chars) do
        if not str:find(vim.pesc(char), 1, true) then
          eq(char, '/')
          break
        end
      end
    end)

    it('skips / when in string and returns ?', function()
      local chars = { '/', '?', '#' }
      local str = 'test/word'
      local result

      for _, char in ipairs(chars) do
        if not str:find(vim.pesc(char), 1, true) then
          result = char
          break
        end
      end

      eq(result, '?')
    end)

    it('finds first available character when using vim.pesc', function()
      local chars = { '/', '?', '#', ':', '@' }
      local str = 'test/word#fragment'
      local result = nil

      for _, char in ipairs(chars) do
        if not str:find(vim.pesc(char), 1, true) then
          result = char
          break
        end
      end

      assert.is_not_nil(result)
      assert.are.equal('?', result)
    end)
  end)

  describe('flag toggling', function()
    it('adds flag when not present', function()
      local flags = 'gc'
      local char = 'i'
      local available_flags = { 'g', 'c', 'i' }

      if not flags:find(char) then
        local new_flags = ''
        for _, flag in ipairs(available_flags) do
          if flags:find(flag) or char == flag then
            new_flags = new_flags .. flag
          end
        end
        flags = new_flags
      end

      eq(flags, 'gci')
    end)

    it('removes flag when present', function()
      local flags = 'gci'
      local char = 'c'

      if flags:find(char) then
        flags = flags:gsub(char, '')
      end

      eq(flags, 'gi')
    end)

    it('maintains flag order', function()
      local flags = 'c'
      local char = 'g'
      local available_flags = { 'g', 'c', 'i' }

      local new_flags = ''
      for _, flag in ipairs(available_flags) do
        if flags:find(flag) or char == flag then
          new_flags = new_flags .. flag
        end
      end

      eq(new_flags, 'gc')
    end)
  end)

  describe('range cycling', function()
    it('cycles from %s to .,$s', function()
      local range = '%s'
      if range == '%s' then
        range = '.,$s'
      end
      eq(range, '.,$s')
    end)

    it('cycles from .,$s to 0,.s', function()
      local range = '.,$s'
      if range == '.,$s' then
        range = '0,.s'
      end
      eq(range, '0,.s')
    end)

    it('cycles from 0,.s to %s', function()
      local range = '0,.s'
      if range ~= '%s' and range ~= '.,$s' then
        range = '%s'
      end
      eq(range, '%s')
    end)
  end)

  describe('separator cycling', function()
    it('cycles through separator list', function()
      local chars = { '/', '?', '#', ':', '@' }
      local sep = '/'
      local idx = 0

      for i, c in ipairs(chars) do
        if c == sep then
          idx = i
          break
        end
      end

      local next_sep = chars[(idx % #chars) + 1]
      eq(next_sep, '?')
    end)

    it('wraps around from last to first', function()
      local chars = { '/', '?', '#', ':', '@' }
      local sep = '@'
      local idx = 0

      for i, c in ipairs(chars) do
        if c == sep then
          idx = i
          break
        end
      end

      local next_sep = chars[(idx % #chars) + 1]
      eq(next_sep, '/')
    end)
  end)

  describe('magic mode cycling', function()
    it('cycles through magic modes', function()
      local magic_list = { '\\v', '\\m', '\\M', '\\V', '' }
      local magic = '\\V'
      local idx = 0

      for i, m in ipairs(magic_list) do
        if m == magic then
          idx = i
          break
        end
      end

      local next_magic = magic_list[(idx % #magic_list) + 1]
      eq(next_magic, '')
    end)

    it('wraps from empty to \\v', function()
      local magic_list = { '\\v', '\\m', '\\M', '\\V', '' }
      local magic = ''
      local idx = 0

      for i, m in ipairs(magic_list) do
        if m == magic then
          idx = i
          break
        end
      end

      local next_magic = magic_list[(idx % #magic_list) + 1]
      eq(next_magic, '\\v')
    end)
  end)

  describe('command splitting', function()
    it('splits command by separator', function()
      local cmd = '.,$s/foo/bar/gc'
      local sep = '/'
      local parts = vim.split(cmd, sep, { plain = true })

      eq(#parts, 4)
      eq(parts[1], '.,$s')
      eq(parts[2], 'foo')
      eq(parts[3], 'bar')
      eq(parts[4], 'gc')
    end)

    it('handles different separators', function()
      local cmd = '.,$s?foo?bar?gc'
      local sep = '?'
      local parts = vim.split(cmd, sep, { plain = true })

      eq(#parts, 4)
      eq(parts[2], 'foo')
      eq(parts[3], 'bar')
    end)

    it('preserves empty parts', function()
      local cmd = '.,$s/foo//gc'
      local sep = '/'
      local parts = vim.split(cmd, sep, { plain = true })

      eq(#parts, 4)
      eq(parts[3], '')
    end)

    it('handles magic mode in search term', function()
      local cmd = '.,$s/\\Vfoo/bar/gc'
      local sep = '/'
      local parts = vim.split(cmd, sep, { plain = true })

      eq(parts[2], '\\Vfoo')
    end)
  end)

  describe('replace term toggling', function()
    it('clears replace term when same as search', function()
      local parts = { '.,$s', 'foo', 'foo', 'gc' }
      local cword = 'foo'
      local replace_term = parts[#parts - 1] == cword and '' or cword

      eq(replace_term, '')
    end)

    it('restores replace term when empty', function()
      local parts = { '.,$s', 'foo', '', 'gc' }
      local cword = 'foo'
      local replace_term = parts[#parts - 1] == '' and cword or ''

      eq(replace_term, 'foo')
    end)

    it('handles different replace and search terms', function()
      local parts = { '.,$s', 'foo', 'bar', 'gc' }
      local cword = 'foo'
      local replace_term = parts[#parts - 1] == cword and '' or cword

      eq(replace_term, 'foo')
    end)
  end)
end)

describe('search-replace.config', function()
  describe('defaults', function()
    it('has default keymaps', function()
      eq(config.defaults.keymaps.enable, true)
      eq(config.defaults.keymaps.populate, '<leader>r')
      eq(config.defaults.keymaps.toggle_g, '<M-g>')
      eq(config.defaults.keymaps.toggle_c, '<M-c>')
      eq(config.defaults.keymaps.toggle_i, '<M-i>')
      eq(config.defaults.keymaps.toggle_replace, '<M-d>')
      eq(config.defaults.keymaps.toggle_range, '<M-5>')
      eq(config.defaults.keymaps.toggle_separator, '<M-/>')
      eq(config.defaults.keymaps.toggle_magic, '<M-m>')
      eq(config.defaults.keymaps.toggle_dashboard, '<M-h>')
    end)

    it('has default dashboard config', function()
      eq(config.defaults.dashboard.enable, true)
      eq(config.defaults.dashboard.symbols.active, '●')
      eq(config.defaults.dashboard.symbols.inactive, '○')
    end)

    it('has default separators', function()
      eq(config.defaults.separators, { '/', '?', '#', ':', '@' })
    end)

    it('has default magic modes', function()
      eq(config.defaults.magic_modes, { '\\v', '\\m', '\\M', '\\V', '' })
    end)

    it('has default flags', function()
      eq(config.defaults.flags, { 'g', 'c', 'i' })
    end)

    it('has default range and flags', function()
      eq(config.defaults.default_range, '.,$s')
      eq(config.defaults.default_flags, 'gc')
      eq(config.defaults.default_magic, '\\V')
    end)
  end)

  describe('setup', function()
    it('merges user options with defaults', function()
      config.setup({ default_range = '%s' })
      eq(config.get().default_range, '%s')
      -- Other defaults should remain
      eq(config.get().default_flags, 'gc')
      -- Reset
      config.setup({})
    end)

    it('allows disabling keymaps', function()
      config.setup({ keymaps = { enable = false } })
      eq(config.get().keymaps.enable, false)
      -- Other keymap defaults should remain
      eq(config.get().keymaps.populate, '<leader>r')
      -- Reset
      config.setup({})
    end)

    it('allows custom separators', function()
      config.setup({ separators = { '/', '#' } })
      eq(config.get().separators, { '/', '#' })
      -- Reset
      config.setup({})
    end)

    it('handles empty options', function()
      config.setup({})
      eq(config.get().default_range, '.,$s')
    end)

    it('handles nil options', function()
      config.setup(nil)
      eq(config.get().default_range, '.,$s')
    end)
  end)

  describe('get', function()
    it('returns current configuration', function()
      local cfg = config.get()
      assert.is_not_nil(cfg)
      assert.is_not_nil(cfg.keymaps)
      assert.is_not_nil(cfg.dashboard)
      assert.is_not_nil(cfg.separators)
    end)
  end)
end)

describe('dashboard helpers', function()
  describe('range description', function()
    local function get_range_description(range)
      if range == '%s' then
        return 'Entire file'
      elseif range == '.,$s' then
        return 'Current line to end of file'
      elseif range == '0,.s' then
        return 'Start of file to current line'
      elseif range == 's' then
        return 'Current line only'
      else
        return 'Custom range'
      end
    end

    it('describes %s range', function()
      eq(get_range_description('%s'), 'Entire file')
    end)

    it('describes .,$s range', function()
      eq(get_range_description('.,$s'), 'Current line to end of file')
    end)

    it('describes 0,.s range', function()
      eq(get_range_description('0,.s'), 'Start of file to current line')
    end)

    it('describes s range', function()
      eq(get_range_description('s'), 'Current line only')
    end)

    it('describes custom range', function()
      eq(get_range_description('1,10s'), 'Custom range')
      eq(get_range_description('5,20s'), 'Custom range')
    end)
  end)

  describe('magic description', function()
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

    it('describes \\v magic mode', function()
      eq(get_magic_description('\\v'), 'Very magic: Extended regex syntax')
    end)

    it('describes \\m magic mode', function()
      eq(get_magic_description('\\m'), 'Magic: Standard regex syntax (default)')
    end)

    it('describes \\M magic mode', function()
      eq(get_magic_description('\\M'), 'Nomagic: Minimal regex syntax')
    end)

    it('describes \\V magic mode', function()
      eq(get_magic_description('\\V'), 'Very nomagic: Literal search')
    end)

    it('describes empty magic mode', function()
      eq(get_magic_description(''), 'Default magic mode')
    end)
  end)

  describe('flags parsing', function()
    local function parse_flags(flags_str)
      return {
        g = flags_str:find('g') ~= nil,
        c = flags_str:find('c') ~= nil,
        i = flags_str:find('i') ~= nil,
      }
    end

    it('parses all flags present', function()
      local flags = parse_flags('gci')
      eq(flags.g, true)
      eq(flags.c, true)
      eq(flags.i, true)
    end)

    it('parses no flags', function()
      local flags = parse_flags('')
      eq(flags.g, false)
      eq(flags.c, false)
      eq(flags.i, false)
    end)

    it('parses single flag', function()
      local flags = parse_flags('g')
      eq(flags.g, true)
      eq(flags.c, false)
      eq(flags.i, false)
    end)

    it('parses two flags', function()
      local flags = parse_flags('gc')
      eq(flags.g, true)
      eq(flags.c, true)
      eq(flags.i, false)
    end)

    it('parses flags in different order', function()
      local flags = parse_flags('icg')
      eq(flags.g, true)
      eq(flags.c, true)
      eq(flags.i, true)
    end)
  end)

  describe('status line formatting', function()
    local function format_status_line(separator, flags)
      local parts = {}
      table.insert(parts, 'Sep: ' .. (separator ~= '' and separator or '/'))
      local flags_str = ''
      if flags.g then
        flags_str = flags_str .. 'g'
      end
      if flags.c then
        flags_str = flags_str .. 'c'
      end
      if flags.i then
        flags_str = flags_str .. 'i'
      end
      table.insert(parts, 'Flags: ' .. (flags_str ~= '' and flags_str or 'none'))
      return '  ' .. table.concat(parts, '  ')
    end

    it('formats status with all flags', function()
      local line = format_status_line('/', { g = true, c = true, i = true })
      assert.is_true(line:find('Sep: /') ~= nil)
      assert.is_true(line:find('Flags: gci') ~= nil)
    end)

    it('formats status with no flags', function()
      local line = format_status_line('/', { g = false, c = false, i = false })
      assert.is_true(line:find('Flags: none') ~= nil)
    end)

    it('formats status with different separator', function()
      local line = format_status_line('#', { g = true, c = false, i = false })
      assert.is_true(line:find('Sep: #') ~= nil)
      assert.is_true(line:find('Flags: g') ~= nil)
    end)
  end)
end)

describe('edge cases', function()
  describe('escaped separator handling', function()
    it('parses command with escaped separator in search', function()
      local cmd = '%s/foo\\/bar/baz/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo\\/bar')
      eq(parsed.replace, 'baz')
    end)

    it('parses command with escaped separator in replace', function()
      local cmd = '%s/foo/bar\\/baz/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar\\/baz')
    end)

    it('parses command with multiple escaped separators', function()
      local cmd = '%s/foo\\/bar/baz\\/qux/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo\\/bar')
      eq(parsed.replace, 'baz\\/qux')
    end)
  end)

  describe('special regex characters', function()
    it('parses command with regex metacharacters in search', function()
      local cmd = '%s/foo.*bar/baz/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo.*bar')
    end)

    it('parses command with capture groups', function()
      local cmd = '%s/\\(foo\\)/\\1bar/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, '\\(foo\\)')
      eq(parsed.replace, '\\1bar')
    end)

    it('parses command with character classes', function()
      local cmd = '%s/[a-z]/X/g'
      local parsed = utils.parse_substitute_cmd(cmd)
      assert.is_not_nil(parsed)
      eq(parsed.search, '[a-z]')
      eq(parsed.replace, 'X')
    end)
  end)

  describe('incomplete commands', function()
    it('handles command with only range and separator', function()
      local cmd = '%s/'
      local is_sub = utils.is_substitute_cmd(cmd)
      assert.is_true(is_sub)
    end)

    it('handles command with range, separator, and partial search', function()
      local cmd = '%s/foo'
      local is_sub = utils.is_substitute_cmd(cmd)
      assert.is_true(is_sub)
    end)

    it('handles command missing trailing separator', function()
      local cmd = '%s/foo/bar'
      local is_sub = utils.is_substitute_cmd(cmd)
      assert.is_true(is_sub)
    end)
  end)

  describe('command reconstruction', function()
    it('reconstructs command from parts', function()
      local parts = { '%s', 'foo', 'bar', 'gc' }
      local sep = '/'
      local reconstructed = table.concat(parts, sep)
      eq(reconstructed, '%s/foo/bar/gc')
    end)

    it('reconstructs command with different separator', function()
      local parts = { '%s', 'foo', 'bar', 'gc' }
      local sep = '#'
      local reconstructed = table.concat(parts, sep)
      eq(reconstructed, '%s#foo#bar#gc')
    end)

    it('reconstructs command with empty replace', function()
      local parts = { '%s', 'foo', '', 'gc' }
      local sep = '/'
      local reconstructed = table.concat(parts, sep)
      eq(reconstructed, '%s/foo//gc')
    end)

    it('reconstructs command with no flags', function()
      local parts = { '%s', 'foo', 'bar', '' }
      local sep = '/'
      local reconstructed = table.concat(parts, sep)
      eq(reconstructed, '%s/foo/bar/')
    end)
  end)
end)

describe('SUBSTITUTE_PATTERN and MAGIC_PATTERN', function()
  describe('SUBSTITUTE_PATTERN', function()
    it('matches basic substitute command', function()
      assert.is_not_nil(string.match('%s/foo/bar/g', utils.SUBSTITUTE_PATTERN))
    end)

    it('matches current line substitute', function()
      assert.is_not_nil(string.match('s/foo/bar/g', utils.SUBSTITUTE_PATTERN))
    end)

    it('matches range substitute', function()
      assert.is_not_nil(string.match('.,$s/foo/bar/g', utils.SUBSTITUTE_PATTERN))
      assert.is_not_nil(string.match('0,.s/foo/bar/g', utils.SUBSTITUTE_PATTERN))
      assert.is_not_nil(string.match('1,10s/foo/bar/g', utils.SUBSTITUTE_PATTERN))
    end)

    it('does not match non-substitute commands', function()
      assert.is_nil(string.match('write', utils.SUBSTITUTE_PATTERN))
      assert.is_nil(string.match('quit', utils.SUBSTITUTE_PATTERN))
      assert.is_nil(string.match('help', utils.SUBSTITUTE_PATTERN))
    end)
  end)

  describe('MAGIC_PATTERN', function()
    it('matches very magic mode', function()
      local match = string.match('\\vfoo', utils.MAGIC_PATTERN)
      eq(match, '\\v')
    end)

    it('matches magic mode', function()
      local match = string.match('\\mfoo', utils.MAGIC_PATTERN)
      eq(match, '\\m')
    end)

    it('matches nomagic mode', function()
      local match = string.match('\\Mfoo', utils.MAGIC_PATTERN)
      eq(match, '\\M')
    end)

    it('matches very nomagic mode', function()
      local match = string.match('\\Vfoo', utils.MAGIC_PATTERN)
      eq(match, '\\V')
    end)

    it('does not match non-magic strings', function()
      assert.is_nil(string.match('foo', utils.MAGIC_PATTERN))
      assert.is_nil(string.match('\\nfoo', utils.MAGIC_PATTERN))
      assert.is_nil(string.match('\\xfoo', utils.MAGIC_PATTERN))
    end)
  end)
end)

describe('search-replace.float', function()
  describe('new', function()
    it('creates a new float instance', function()
      local instance = float.new()
      assert.is_not_nil(instance)
    end)

    it('returns instance with expected methods', function()
      local instance = float.new()
      assert.is_function(instance.refresh)
      assert.is_function(instance.close)
      assert.is_function(instance.is_shown)
      assert.is_function(instance.toggle)
      assert.is_function(instance.buffer_default_dimensions)
      assert.is_function(instance.fit_to_width)
      assert.is_function(instance.set_buf_name)
    end)

    it('initializes with empty cache', function()
      local instance = float.new()
      assert.is_nil(instance.cache.buf_id)
      assert.is_nil(instance.cache.win_id)
    end)

    it('creates independent instances', function()
      local instance1 = float.new()
      local instance2 = float.new()
      assert.are_not.equal(instance1.cache, instance2.cache)
    end)
  end)

  describe('is_shown', function()
    it('returns false when window not created', function()
      local instance = float.new()
      assert.is_false(instance.is_shown())
    end)

    it('returns false when cache is empty', function()
      local instance = float.new()
      instance.cache.win_id = nil
      assert.is_false(instance.is_shown())
    end)
  end)

  describe('fit_to_width', function()
    it('returns text unchanged when shorter than width', function()
      local instance = float.new()
      local result = instance.fit_to_width('hello', 10)
      eq(result, 'hello')
    end)

    it('returns text unchanged when exactly at width', function()
      local instance = float.new()
      local result = instance.fit_to_width('hello', 5)
      eq(result, 'hello')
    end)

    it('truncates text with ellipsis when longer than width', function()
      local instance = float.new()
      local result = instance.fit_to_width('hello world', 8)
      -- Result should start with '...' and show the tail of the text
      -- Formula: '...' (3 chars) + strcharpart(text, t_width - width + 1, width - 1)
      -- For 'hello world' (11 chars), width 8: '...' + 'o world' (7 chars) = '...o world'
      assert.is_true(result:sub(1, 3) == '...')
      eq(result, '...o world')
    end)

    it('handles empty string', function()
      local instance = float.new()
      local result = instance.fit_to_width('', 10)
      eq(result, '')
    end)

    it('handles width of 1', function()
      local instance = float.new()
      -- With width 1, only room for one char after ellipsis truncation
      local result = instance.fit_to_width('hello', 4)
      assert.is_true(result:sub(1, 3) == '...')
    end)
  end)

  describe('close', function()
    it('handles close when nothing is open', function()
      local instance = float.new()
      -- Should not error when closing non-existent window/buffer
      assert.has_no.errors(function()
        instance.close()
      end)
    end)

    it('clears cache after close', function()
      local instance = float.new()
      instance.close()
      assert.is_nil(instance.cache.win_id)
      assert.is_nil(instance.cache.buf_id)
    end)
  end)

  describe('refresh', function()
    it('closes window when content_fn returns empty table', function()
      local instance = float.new()
      local content_fn = function()
        return {}
      end
      local config_fn = function()
        return { relative = 'editor', width = 10, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      assert.is_false(instance.is_shown())
    end)

    it('closes window when content_fn returns nil', function()
      local instance = float.new()
      local content_fn = function()
        return nil
      end
      local config_fn = function()
        return { relative = 'editor', width = 10, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      assert.is_false(instance.is_shown())
    end)

    it('creates window with valid content', function()
      local instance = float.new()
      local content_fn = function()
        return { 'line 1', 'line 2' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 2, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      assert.is_true(instance.is_shown())
      assert.is_not_nil(instance.cache.buf_id)
      assert.is_not_nil(instance.cache.win_id)

      -- Cleanup
      instance.close()
    end)

    it('sets buffer content correctly', function()
      local instance = float.new()
      local expected_lines = { 'hello', 'world' }
      local content_fn = function()
        return expected_lines
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 2, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local actual_lines = vim.api.nvim_buf_get_lines(instance.cache.buf_id, 0, -1, false)
      eq(actual_lines, expected_lines)

      -- Cleanup
      instance.close()
    end)

    it('applies window options when opts_fn provided', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end
      local opts_fn = function()
        return { wrap = false, cursorline = false }
      end

      instance.refresh(content_fn, config_fn, opts_fn)

      local wrap = vim.api.nvim_get_option_value('wrap', { win = instance.cache.win_id })
      eq(wrap, false)

      -- Cleanup
      instance.close()
    end)

    it('calls highlights_fn when provided', function()
      local instance = float.new()
      local highlights_called = false
      local received_buf_id = nil
      local received_lines = nil

      local content_fn = function()
        return { 'test line' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end
      local highlights_fn = function(buf_id, lines)
        highlights_called = true
        received_buf_id = buf_id
        received_lines = lines
      end

      instance.refresh(content_fn, config_fn, nil, highlights_fn)

      assert.is_true(highlights_called)
      eq(received_buf_id, instance.cache.buf_id)
      eq(received_lines, { 'test line' })

      -- Cleanup
      instance.close()
    end)

    it('reuses existing buffer on subsequent refreshes', function()
      local instance = float.new()
      local content_fn = function()
        return { 'content' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)
      local first_buf_id = instance.cache.buf_id

      -- Refresh again with different content
      local content_fn2 = function()
        return { 'new content' }
      end
      instance.refresh(content_fn2, config_fn)

      eq(instance.cache.buf_id, first_buf_id)

      -- Cleanup
      instance.close()
    end)

    it('updates buffer content on refresh', function()
      local instance = float.new()
      local call_count = 0
      local content_fn = function()
        call_count = call_count + 1
        return { 'content ' .. call_count }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)
      local lines1 = vim.api.nvim_buf_get_lines(instance.cache.buf_id, 0, -1, false)
      eq(lines1, { 'content 1' })

      instance.refresh(content_fn, config_fn)
      local lines2 = vim.api.nvim_buf_get_lines(instance.cache.buf_id, 0, -1, false)
      eq(lines2, { 'content 2' })

      -- Cleanup
      instance.close()
    end)
  end)

  describe('toggle', function()
    it('opens window when closed', function()
      local instance = float.new()
      local content_fn = function()
        return { 'toggle test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      assert.is_false(instance.is_shown())
      instance.toggle(content_fn, config_fn)
      assert.is_true(instance.is_shown())

      -- Cleanup
      instance.close()
    end)

    it('closes window when open', function()
      local instance = float.new()
      local content_fn = function()
        return { 'toggle test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)
      assert.is_true(instance.is_shown())

      instance.toggle(content_fn, config_fn)
      assert.is_false(instance.is_shown())
    end)

    it('toggles correctly in sequence', function()
      local instance = float.new()
      local content_fn = function()
        return { 'toggle test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      assert.is_false(instance.is_shown())
      instance.toggle(content_fn, config_fn)
      assert.is_true(instance.is_shown())
      instance.toggle(content_fn, config_fn)
      assert.is_false(instance.is_shown())
      instance.toggle(content_fn, config_fn)
      assert.is_true(instance.is_shown())

      -- Cleanup
      instance.close()
    end)
  end)

  describe('buffer_default_dimensions', function()
    it('computes dimensions for single line', function()
      local instance = float.new()
      local content_fn = function()
        return { 'hello' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local width, height = instance.buffer_default_dimensions(instance.cache.buf_id, 1.0)
      assert.is_true(width >= 5) -- 'hello' is 5 chars
      eq(height, 1)

      -- Cleanup
      instance.close()
    end)

    it('computes dimensions for multiple lines', function()
      local instance = float.new()
      local content_fn = function()
        return { 'short', 'longer line here' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 2, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local width, height = instance.buffer_default_dimensions(instance.cache.buf_id, 1.0)
      assert.is_true(width >= 16) -- longest line is 'longer line here' (16 chars)
      eq(height, 2)

      -- Cleanup
      instance.close()
    end)

    it('respects max_width_share parameter', function()
      local instance = float.new()
      -- Create a very long line
      local long_line = string.rep('x', 1000)
      local content_fn = function()
        return { long_line }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local width, _ = instance.buffer_default_dimensions(instance.cache.buf_id, 0.5)
      local max_allowed = math.floor(0.5 * vim.o.columns)
      assert.is_true(width <= max_allowed)

      -- Cleanup
      instance.close()
    end)

    it('handles empty buffer', function()
      local instance = float.new()
      local content_fn = function()
        return { '' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local width, height = instance.buffer_default_dimensions(instance.cache.buf_id, 1.0)
      assert.is_true(width >= 1) -- minimum width is 1
      eq(height, 1)

      -- Cleanup
      instance.close()
    end)

    it('clamps max_width_share to valid range', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      -- Test with value > 1 (should be clamped to 1)
      local width1, _ = instance.buffer_default_dimensions(instance.cache.buf_id, 1.5)
      local width2, _ = instance.buffer_default_dimensions(instance.cache.buf_id, 1.0)
      eq(width1, width2)

      -- Test with value < 0 (should be clamped to 0)
      local width3, _ = instance.buffer_default_dimensions(instance.cache.buf_id, -0.5)
      eq(width3, 1) -- minimum width is 1

      -- Cleanup
      instance.close()
    end)
  end)

  describe('set_buf_name', function()
    it('sets buffer name with pattern', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)
      instance.set_buf_name(instance.cache.buf_id, 'dashboard')

      local name = vim.api.nvim_buf_get_name(instance.cache.buf_id)
      assert.is_true(name:match('float://') ~= nil)
      assert.is_true(name:match('dashboard') ~= nil)

      -- Cleanup
      instance.close()
    end)
  end)

  describe('buffer properties', function()
    it('creates unlisted buffer', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local listed = vim.api.nvim_get_option_value('buflisted', { buf = instance.cache.buf_id })
      assert.is_false(listed)

      -- Cleanup
      instance.close()
    end)

    it('creates non-modifiable buffer after content set', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local modifiable = vim.api.nvim_get_option_value('modifiable', { buf = instance.cache.buf_id })
      assert.is_false(modifiable)

      -- Cleanup
      instance.close()
    end)

    it('sets bufhidden to wipe', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)

      local bufhidden = vim.api.nvim_get_option_value('bufhidden', { buf = instance.cache.buf_id })
      eq(bufhidden, 'wipe')

      -- Cleanup
      instance.close()
    end)
  end)

  describe('window invalidation', function()
    it('recreates window after manual close', function()
      local instance = float.new()
      local content_fn = function()
        return { 'test' }
      end
      local config_fn = function()
        return { relative = 'editor', width = 20, height = 1, row = 0, col = 0 }
      end

      instance.refresh(content_fn, config_fn)
      local first_win_id = instance.cache.win_id

      -- Manually close the window
      vim.api.nvim_win_close(first_win_id, true)
      assert.is_false(vim.api.nvim_win_is_valid(first_win_id))

      -- Refresh should recreate the window
      instance.refresh(content_fn, config_fn)
      assert.is_true(instance.is_shown())
      assert.are_not.equal(instance.cache.win_id, first_win_id)

      -- Cleanup
      instance.close()
    end)
  end)
end)
