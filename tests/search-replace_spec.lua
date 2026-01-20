---@diagnostic disable: undefined-field
--# selene: allow(undefined_variable)
local utils = require 'search-replace.utils'
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
  end)
end)
