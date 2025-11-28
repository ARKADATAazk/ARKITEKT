-- @noindex
-- WalterBuilder/domain/element.lua
-- WalterElement model - represents a UI element with coordinates

local Coordinate = require('WalterBuilder.domain.coordinate')

local M = {}
local Element = {}
Element.__index = Element

-- Element categories
M.CATEGORIES = {
  BUTTON = "button",
  FADER = "fader",
  LABEL = "label",
  METER = "meter",
  CONTAINER = "container",
  INPUT = "input",
  OTHER = "other",
}

-- Create a new element
function M.new(opts)
  opts = opts or {}

  local self = setmetatable({
    -- Identity
    id = opts.id or "element",  -- e.g., "tcp.mute", "tcp.volume"
    name = opts.name or opts.id or "Element",  -- Display name
    category = opts.category or M.CATEGORIES.OTHER,

    -- Coordinates
    coords = opts.coords and Coordinate.clone(opts.coords) or Coordinate.new(),

    -- Visual
    visible = opts.visible ~= false,
    color = opts.color,  -- Override color (optional)

    -- Metadata
    description = opts.description or "",
    is_size = opts.is_size or false,  -- Is this a .size element?
    is_color = opts.is_color or false,  -- Is this a .color element?
    is_font = opts.is_font or false,  -- Is this a .font element?
    is_margin = opts.is_margin or false,  -- Is this a .margin element?
    is_custom = opts.is_custom or false,  -- Custom element (not in default definitions)

    -- Parent reference
    parent = opts.parent,  -- For nested elements like tcp.volume.label
  }, Element)

  return self
end

-- Get the base element ID (e.g., "tcp.mute" from "tcp.mute.color")
function Element:get_base_id()
  local parts = {}
  for part in self.id:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end

  -- Return first two parts (context.element)
  if #parts >= 2 then
    return parts[1] .. "." .. parts[2]
  end
  return self.id
end

-- Get the context (tcp, mcp, envcp, trans, etc.)
function Element:get_context()
  return self.id:match("^([^.]+)")
end

-- Check if this is a sub-element (e.g., .color, .font, .label)
function Element:is_sub_element()
  local parts = {}
  for part in self.id:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  return #parts > 2
end

-- Get the sub-element type (.color, .font, .label, etc.)
function Element:get_sub_type()
  if not self:is_sub_element() then return nil end

  local parts = {}
  for part in self.id:gmatch("[^.]+") do
    parts[#parts + 1] = part
  end
  return parts[3]
end

-- Compute actual rectangle given parent dimensions
function Element:compute_rect(parent_w, parent_h)
  return Coordinate.compute_rect(self.coords, parent_w, parent_h)
end

-- Get horizontal attachment behavior
function Element:get_horizontal_behavior()
  return Coordinate.get_horizontal_behavior(self.coords)
end

-- Get vertical attachment behavior
function Element:get_vertical_behavior()
  return Coordinate.get_vertical_behavior(self.coords)
end

-- Set coordinates
function Element:set_coords(coords)
  self.coords = Coordinate.clone(coords)
end

-- Set individual coordinate value
function Element:set_coord(key, value)
  if self.coords[key] ~= nil then
    self.coords[key] = value
  end
end

-- Clone element
function Element:clone()
  return M.new({
    id = self.id,
    name = self.name,
    category = self.category,
    coords = self.coords,
    visible = self.visible,
    color = self.color,
    description = self.description,
    is_size = self.is_size,
    is_color = self.is_color,
    is_font = self.is_font,
    is_margin = self.is_margin,
    is_custom = self.is_custom,
    parent = self.parent,
  })
end

-- Serialize to WALTER format
function Element:serialize()
  if not self.visible then
    return "clear " .. self.id
  end
  return "set " .. self.id .. " " .. Coordinate.serialize(self.coords)
end

return M
