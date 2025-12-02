-- @noindex
-- ItemPicker/domain/items/utils.lua
-- Item processing utilities
-- @migrated 2024-11-27 from services/utils.lua

local Ark = require('arkitekt')

local M = {}

function M.getn(tab)
  local i = 0
  for _ in pairs(tab) do
    i = i + 1
  end
  return i
end

function M.RGBvalues(RGB)
  local R = RGB & 255
  local G = (RGB >> 8) & 255
  local B = (RGB >> 16) & 255
  local R = R / 255
  local G = G / 255
  local B = B / 255
  return R, G, B
end

function M.Color(ImGui, r, g, b, a)
  return Ark.Colors.components_to_rgba(r*255, g*255, b*255, (a or 1)*255)
end

function M.SampleLimit(spl)
  return math.max(-1, math.min(spl, 1))
end

function M.RemoveKeyFromChunk(chunk_string, key)
  local pattern = key .. '[^\n]*\n?'
  local modified_chunk = string.gsub(chunk_string, pattern, '')
  return modified_chunk
end

return M
