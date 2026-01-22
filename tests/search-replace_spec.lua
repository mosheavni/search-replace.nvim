---@diagnostic disable: undefined-field
--# selene: allow(undefined_variable)
local utils = require('search-replace.utils')
local search_replace = require('search-replace')
local eq = assert.are.same

describe('search-replace.utils', function()
  describe('is_substitute_cmd', function()
    it('detects basic substitute command', function()
      assert.is_true(utils.is_substitute_cmd('%s/foo/bar/g'))
    end)

    it('detects range substitute command', function()
      assert.is_true(utils.is_substitute_cmd('.,$s/foo/bar/g'))
    end)

    it('rejects non-substitute command', function()
      assert.is_false(utils.is_substitute_cmd(':write'))
    end)

    it('rejects nil input', function()
      assert.is_falsy(utils.is_substitute_cmd(nil))
    end)

    it('rejects empty string', function()
      assert.is_false(utils.is_substitute_cmd(''))
    end)

    it('detects substitute with line number range', function()
      assert.is_true(utils.is_substitute_cmd('1,10s/foo/bar/'))
    end)

    it('detects substitute with current line only', function()
      assert.is_true(utils.is_substitute_cmd('s/foo/bar/'))
    end)

    it('detects substitute with 0,. range', function()
      assert.is_true(utils.is_substitute_cmd('0,.s/foo/bar/'))
    end)

    it('detects substitute with different separators', function()
      assert.is_true(utils.is_substitute_cmd('%s#foo#bar#g'))
      assert.is_true(utils.is_substitute_cmd('%s?foo?bar?g'))
      assert.is_true(utils.is_substitute_cmd('%s:foo:bar:g'))
      assert.is_true(utils.is_substitute_cmd('%s@foo@bar@g'))
    end)

    it('detects incomplete substitute command', function()
      assert.is_true(utils.is_substitute_cmd('%s/'))
      assert.is_true(utils.is_substitute_cmd('.,$s#'))
    end)

    it('rejects commands starting with s followed by alphanumeric chars', function()
      -- The pattern requires a non-alphanumeric separator after 's'
      -- This prevents false positives on :set, :sort, :source, etc.
      assert.is_false(utils.is_substitute_cmd('set number')) -- 'e' is alphanumeric
      assert.is_false(utils.is_substitute_cmd('syntax on')) -- 'y' is alphanumeric
      assert.is_false(utils.is_substitute_cmd('sort')) -- 'o' is alphanumeric
      assert.is_false(utils.is_substitute_cmd('source file.lua')) -- 'o' is alphanumeric
      -- And of course, commands without 's' at the start don't match
      assert.is_false(utils.is_substitute_cmd('write')) -- no 's'
      assert.is_false(utils.is_substitute_cmd('quit')) -- no 's'
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
      local parsed = utils.parse_substitute_cmd('%s/foo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.range, '%s')
      eq(parsed.sep, '/')
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, 'g')
    end)

    it('parses command with magic mode', function()
      local parsed = utils.parse_substitute_cmd('.,$s/\\Vfoo/bar/gc')
      assert.is_not_nil(parsed)
      eq(parsed.range, '.,$s')
      eq(parsed.magic, '\\V')
      eq(parsed.search, '\\Vfoo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, 'gc')
    end)

    it('parses command with different separator', function()
      local parsed = utils.parse_substitute_cmd('%s#foo#bar#g')
      assert.is_not_nil(parsed)
      eq(parsed.sep, '#')
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
    end)

    it('returns nil for invalid command', function()
      local parsed = utils.parse_substitute_cmd(':write')
      assert.is_nil(parsed)
    end)

    it('parses command with empty replace term', function()
      local parsed = utils.parse_substitute_cmd('%s/foo//g')
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo')
      eq(parsed.replace, '')
      eq(parsed.flags, 'g')
    end)

    it('parses command with no flags', function()
      local parsed = utils.parse_substitute_cmd('%s/foo/bar/')
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo')
      eq(parsed.replace, 'bar')
      eq(parsed.flags, '')
    end)

    it('parses command with all flags', function()
      local parsed = utils.parse_substitute_cmd('%s/foo/bar/gci')
      assert.is_not_nil(parsed)
      eq(parsed.flags, 'gci')
    end)

    it('parses all magic modes', function()
      -- Very magic
      local parsed = utils.parse_substitute_cmd('%s/\\vfoo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\v')

      -- Magic (default)
      parsed = utils.parse_substitute_cmd('%s/\\mfoo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\m')

      -- Nomagic
      parsed = utils.parse_substitute_cmd('%s/\\Mfoo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\M')

      -- Very nomagic
      parsed = utils.parse_substitute_cmd('%s/\\Vfoo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.magic, '\\V')

      -- No magic mode
      parsed = utils.parse_substitute_cmd('%s/foo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.magic, '')
    end)

    it('parses command with current line only range', function()
      local parsed = utils.parse_substitute_cmd('s/foo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.range, 's')
    end)

    it('parses command with 0,. range', function()
      local parsed = utils.parse_substitute_cmd('0,.s/foo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.range, '0,.s')
    end)

    it('parses command with line number range', function()
      local parsed = utils.parse_substitute_cmd('1,10s/foo/bar/g')
      assert.is_not_nil(parsed)
      eq(parsed.range, '1,10s')
    end)

    it('returns nil for empty string', function()
      local parsed = utils.parse_substitute_cmd('')
      assert.is_nil(parsed)
    end)

    it('returns nil for nil input', function()
      local parsed = utils.parse_substitute_cmd(nil)
      assert.is_nil(parsed)
    end)

    it('parses command with special characters in search/replace', function()
      local parsed = utils.parse_substitute_cmd('%s/foo.*/bar_baz/g')
      assert.is_not_nil(parsed)
      eq(parsed.search, 'foo.*')
      eq(parsed.replace, 'bar_baz')
    end)

    it('parses command with @ separator', function()
      local parsed = utils.parse_substitute_cmd('%s@/path/to/file@/new/path@g')
      assert.is_not_nil(parsed)
      eq(parsed.sep, '@')
      eq(parsed.search, '/path/to/file')
      eq(parsed.replace, '/new/path')
    end)
  end)

  describe('normalize_parts', function()
    it('normalizes single element', function()
      local parts = utils.normalize_parts({ '.,$s' })
      eq(#parts, 4)
      eq(parts[1], '.,$s')
    end)

    it('normalizes two elements', function()
      local parts = utils.normalize_parts({ '.,$s', 'foo' })
      eq(#parts, 4)
      eq(parts[3], 'foo') -- Replace copied from search
    end)

    it('normalizes three elements', function()
      local parts = utils.normalize_parts({ '.,$s', 'foo', 'bar' })
      eq(#parts, 4)
      eq(parts[4], '') -- Empty flags
    end)

    it('keeps four elements unchanged', function()
      local parts = utils.normalize_parts({ '.,$s', 'foo', 'bar', 'gc' })
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

describe('search-replace.get_config', function()
  describe('defaults', function()
    it('has default keymaps', function()
      local config = search_replace.get_config()
      eq(config.keymaps.enable, true)
      eq(config.keymaps.populate, '<leader>r')
      eq(config.keymaps.toggle_g, '<M-g>')
      eq(config.keymaps.toggle_c, '<M-c>')
      eq(config.keymaps.toggle_i, '<M-i>')
      eq(config.keymaps.toggle_replace, '<M-d>')
      eq(config.keymaps.toggle_range, '<M-5>')
      eq(config.keymaps.toggle_separator, '<M-/>')
      eq(config.keymaps.toggle_magic, '<M-m>')
      eq(config.keymaps.toggle_dashboard, '<M-h>')
    end)

    it('has default dashboard config', function()
      local config = search_replace.get_config()
      eq(config.dashboard.enable, true)
      eq(config.dashboard.symbols.active, '●')
      eq(config.dashboard.symbols.inactive, '○')
    end)

    it('has default separators', function()
      local config = search_replace.get_config()
      eq(config.separators, { '/', '?', '#', ':', '@' })
    end)

    it('has default magic modes', function()
      local config = search_replace.get_config()
      eq(config.magic_modes, { '\\v', '\\m', '\\M', '\\V', '' })
    end)

    it('has default flags', function()
      local config = search_replace.get_config()
      eq(config.flags, { 'g', 'c', 'i' })
    end)

    it('has default range and flags', function()
      local config = search_replace.get_config()
      eq(config.default_range, '.,$s')
      eq(config.default_flags, 'gc')
      eq(config.default_magic, '\\V')
    end)
  end)

  describe('setup', function()
    it('merges user options with defaults', function()
      search_replace.setup({ default_range = '%s' })
      eq(search_replace.get_config().default_range, '%s')
      -- Other defaults should remain
      eq(search_replace.get_config().default_flags, 'gc')
      -- Reset
      search_replace.setup({})
    end)

    it('allows disabling keymaps', function()
      search_replace.setup({ keymaps = { enable = false } })
      eq(search_replace.get_config().keymaps.enable, false)
      -- Other keymap defaults should remain
      eq(search_replace.get_config().keymaps.populate, '<leader>r')
      -- Reset
      search_replace.setup({})
    end)

    it('allows custom separators', function()
      search_replace.setup({ separators = { '/', '#' } })
      eq(search_replace.get_config().separators, { '/', '#' })
      -- Reset
      search_replace.setup({})
    end)

    it('handles empty options', function()
      search_replace.setup({})
      eq(search_replace.get_config().default_range, '.,$s')
    end)

    it('handles nil options', function()
      search_replace.setup(nil)
      eq(search_replace.get_config().default_range, '.,$s')
    end)
  end)

  describe('get_config', function()
    it('returns current configuration', function()
      local cfg = search_replace.get_config()
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
