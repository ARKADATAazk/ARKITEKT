-- @noindex
-- ItemPicker/domain/items/utils.lua
-- Item processing utilities
-- @migrated 2024-11-27 from services/utils.lua

local Ark = require('arkitekt')

-- PERF: Localize math functions (SampleLimit called in tight waveform loops)
local max = math.max
local min = math.min

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
  return Ark.Colors.ComponentsToRgba((r*255)//1, (g*255)//1, (b*255)//1, ((a or 1)*255)//1)
end

function M.SampleLimit(spl)
  return max(-1, min(spl, 1))
end

function M.RemoveKeyFromChunk(chunk_string, key)
  local pattern = key .. '[^\n]*\n?'
  local modified_chunk = string.gsub(chunk_string, pattern, '')
  return modified_chunk
end

return M
