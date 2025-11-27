-- @noindex
-- WalterBuilder/defs/tcp_elements.lua
-- TCP (Track Control Panel) element definitions
--
-- Based on WALTER documentation: each element has default coordinates
-- that represent a reasonable starting point for customization.

local Element = require('WalterBuilder.domain.element')

local M = {}

-- Element categories for grouping in UI
local CAT = Element.CATEGORIES

-- TCP element definitions with sensible defaults
-- Coordinates follow typical track panel layout (300px wide, 90px tall)
M.elements = {
  -- SIZE element (special - defines panel size)
  {
    id = "tcp.size",
    name = "Panel Size",
    category = CAT.CONTAINER,
    description = "Baseline size (x,y) and minimum size (w,h)",
    is_size = true,
    coords = {x = 300, y = 90, w = 200, h = 60, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- MARGIN (inner padding)
  {
    id = "tcp.margin",
    name = "Inner Margins",
    category = CAT.CONTAINER,
    description = "Inner margin padding (l,t,r,b)",
    is_margin = true,
    coords = {x = 4, y = 4, w = 4, h = 4, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- BUTTONS
  -- ============================================
  {
    id = "tcp.recarm",
    name = "Record Arm",
    category = CAT.BUTTON,
    description = "Record arm button",
    coords = {x = 4, y = 4, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.recmon",
    name = "Record Monitor",
    category = CAT.BUTTON,
    description = "Record monitor mode button",
    coords = {x = 26, y = 4, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.recmode",
    name = "Record Mode",
    category = CAT.BUTTON,
    description = "Record mode button",
    coords = {x = 48, y = 4, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.mute",
    name = "Mute",
    category = CAT.BUTTON,
    description = "Mute button",
    coords = {x = 4, y = 26, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.solo",
    name = "Solo",
    category = CAT.BUTTON,
    description = "Solo button",
    coords = {x = 26, y = 26, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.fx",
    name = "FX",
    category = CAT.BUTTON,
    description = "FX button",
    coords = {x = 4, y = 48, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.fxbyp",
    name = "FX Bypass",
    category = CAT.BUTTON,
    description = "FX bypass button",
    coords = {x = 26, y = 48, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.fxin",
    name = "Input FX",
    category = CAT.BUTTON,
    description = "Input-FX button",
    coords = {x = 48, y = 48, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.env",
    name = "Envelope",
    category = CAT.BUTTON,
    description = "Envelope/automation mode button",
    coords = {x = 4, y = 70, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.phase",
    name = "Phase",
    category = CAT.BUTTON,
    description = "Phase/polarity button",
    coords = {x = 26, y = 70, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.io",
    name = "I/O",
    category = CAT.BUTTON,
    description = "IO button",
    coords = {x = 48, y = 70, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.folder",
    name = "Folder",
    category = CAT.BUTTON,
    description = "Folder button",
    coords = {x = 70, y = 4, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.foldercomp",
    name = "Folder Compact",
    category = CAT.BUTTON,
    description = "Folder compact button",
    coords = {x = 70, y = 26, w = 20, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- FADERS/CONTROLS
  -- ============================================
  {
    id = "tcp.volume",
    name = "Volume Fader",
    category = CAT.FADER,
    description = "Volume fader",
    coords = {x = 94, y = 4, w = 100, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.pan",
    name = "Pan Fader",
    category = CAT.FADER,
    description = "Pan fader/knob",
    coords = {x = 94, y = 26, w = 60, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.width",
    name = "Width Fader",
    category = CAT.FADER,
    description = "Width fader/knob",
    coords = {x = 156, y = 26, w = 60, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- LABELS/TEXT
  -- ============================================
  {
    id = "tcp.label",
    name = "Track Name",
    category = CAT.LABEL,
    description = "Track name text",
    coords = {x = 94, y = 48, w = 120, h = 20, ls = 0, ts = 0, rs = 1, bs = 0},  -- Stretches horizontally
  },
  {
    id = "tcp.trackidx",
    name = "Track Index",
    category = CAT.LABEL,
    description = "Track index number",
    coords = {x = 94, y = 70, w = 30, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- VOLUME/PAN LABELS (readouts)
  -- ============================================
  {
    id = "tcp.volume.label",
    name = "Volume Readout",
    category = CAT.LABEL,
    description = "Volume readout text",
    coords = {x = 196, y = 4, w = 50, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.pan.label",
    name = "Pan Readout",
    category = CAT.LABEL,
    description = "Pan readout text",
    coords = {x = 94, y = 4, w = 40, h = 16, ls = 0, ts = 0, rs = 0, bs = 0},
  },
  {
    id = "tcp.width.label",
    name = "Width Readout",
    category = CAT.LABEL,
    description = "Width readout text",
    coords = {x = 156, y = 4, w = 40, h = 16, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- INPUT
  -- ============================================
  {
    id = "tcp.recinput",
    name = "Record Input",
    category = CAT.INPUT,
    description = "Record input text field",
    coords = {x = 126, y = 70, w = 80, h = 20, ls = 0, ts = 0, rs = 0, bs = 0},
  },

  -- ============================================
  -- METER
  -- ============================================
  {
    id = "tcp.meter",
    name = "Meter",
    category = CAT.METER,
    description = "Meter outer coordinates",
    coords = {x = 250, y = 4, w = 46, h = 82, ls = 0, ts = 0, rs = 1, bs = 1},  -- Anchored right, stretches vertically
  },

  -- ============================================
  -- FX PARAMETER AREA
  -- ============================================
  {
    id = "tcp.fxparm",
    name = "FX Parameter List",
    category = CAT.CONTAINER,
    description = "FX parameter list area",
    coords = {x = 4, y = 92, w = 200, h = 60, ls = 0, ts = 0, rs = 1, bs = 1},  -- Stretches both ways
  },
  {
    id = "tcp.fxlist",
    name = "FX Insert List",
    category = CAT.CONTAINER,
    description = "FX insert list area",
    coords = {x = 4, y = 92, w = 200, h = 60, ls = 0, ts = 0, rs = 1, bs = 1},
  },
  {
    id = "tcp.sendlist",
    name = "Send List",
    category = CAT.CONTAINER,
    description = "TCP send list area",
    coords = {x = 4, y = 92, w = 200, h = 60, ls = 0, ts = 0, rs = 1, bs = 1},
  },
  {
    id = "tcp.fxembed",
    name = "FX Embed Area",
    category = CAT.CONTAINER,
    description = "FX Embed area rectangle",
    coords = {x = 4, y = 92, w = 200, h = 60, ls = 0, ts = 0, rs = 1, bs = 1},
  },
}

-- Group elements by category
function M.get_by_category()
  local result = {}

  for _, def in ipairs(M.elements) do
    local cat = def.category
    if not result[cat] then
      result[cat] = {}
    end
    result[cat][#result[cat] + 1] = def
  end

  return result
end

-- Get a specific element definition by ID
function M.get_definition(id)
  for _, def in ipairs(M.elements) do
    if def.id == id then
      return def
    end
  end
  return nil
end

-- Create Element instances from definitions
function M.create_elements()
  local elements = {}

  for _, def in ipairs(M.elements) do
    elements[#elements + 1] = Element.new({
      id = def.id,
      name = def.name,
      category = def.category,
      description = def.description,
      is_size = def.is_size,
      is_margin = def.is_margin,
      coords = def.coords,
    })
  end

  return elements
end

-- Get subset of main (non-sub) elements for palette display
function M.get_main_elements()
  local result = {}

  for _, def in ipairs(M.elements) do
    -- Skip sub-elements (.color, .font, .label of controls)
    local parts = {}
    for p in def.id:gmatch("[^.]+") do parts[#parts + 1] = p end

    if #parts <= 2 then
      result[#result + 1] = def
    end
  end

  return result
end

-- Category display names
M.category_names = {
  [CAT.BUTTON] = "Buttons",
  [CAT.FADER] = "Faders",
  [CAT.LABEL] = "Labels",
  [CAT.METER] = "Meters",
  [CAT.CONTAINER] = "Containers",
  [CAT.INPUT] = "Inputs",
  [CAT.OTHER] = "Other",
}

-- Category order for display
M.category_order = {
  CAT.BUTTON,
  CAT.FADER,
  CAT.LABEL,
  CAT.METER,
  CAT.INPUT,
  CAT.CONTAINER,
  CAT.OTHER,
}

return M
