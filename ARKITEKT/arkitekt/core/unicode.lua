-- @noindex
-- arkitekt/core/unicode.lua
-- Unicode utility functions

local M = {}

--- Convert a Unicode code point to UTF-8 encoded string
--- @param codepoint number|string The code point (e.g., 0xF3B4 or 'F3B4')
--- @return string The UTF-8 encoded string
function M.utf8(codepoint)
  -- Handle string input (e.g., 'F3B4' or '0xF3B4')
  if type(codepoint) == 'string' then
    codepoint = codepoint:gsub('^0x', ''):gsub('^U%+', '')
    codepoint = tonumber(codepoint, 16)
  end

  -- Validate codepoint range (0 to 0x10FFFF max Unicode)
  if not codepoint or codepoint < 0 or codepoint > 0x10FFFF then
    return ''
  end

  if codepoint < 0x80 then
    -- 1-byte ASCII
    return string.char(codepoint)
  elseif codepoint < 0x800 then
    -- 2-byte sequence
    return string.char(
      0xC0 + codepoint / 0x40 // 1,
      0x80 + (codepoint % 0x40)
    )
  elseif codepoint < 0x10000 then
    -- 3-byte sequence (most common for icons)
    return string.char(
      0xE0 + codepoint / 0x1000 // 1,
      0x80 + (codepoint % 0x1000) / 0x40 // 1,
      0x80 + (codepoint % 0x40)
    )
  else
    -- 4-byte sequence
    return string.char(
      0xF0 + codepoint / 0x40000 // 1,
      0x80 + (codepoint % 0x40000) / 0x1000 // 1,
      0x80 + (codepoint % 0x1000) / 0x40 // 1,
      0x80 + (codepoint % 0x40)
    )
  end
end

return M
