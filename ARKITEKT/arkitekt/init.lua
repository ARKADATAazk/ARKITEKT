-- @noindex
-- arkitekt/init.lua
-- Unified namespace for the arkitekt library
-- Usage: local ark = require('arkitekt')

local M = {}

-- Module path mappings (lazy loaded on first access)
local module_map = {
  -- ==========================================================================
  -- CORE
  -- ==========================================================================
  Colors = 'arkitekt.core.colors',
  Config = 'arkitekt.core.config',
  Settings = 'arkitekt.core.settings',
  Json = 'arkitekt.core.json',
  Math = 'arkitekt.core.math',
  Utf8 = 'arkitekt.core.utf8',
  Uuid = 'arkitekt.core.uuid',
  Images = 'arkitekt.core.images',
  UndoManager = 'arkitekt.core.undo_manager',

  -- ==========================================================================
  -- DEFINITIONS
  -- ==========================================================================
  Defs = 'arkitekt.defs',
  AppDefs = 'arkitekt.defs.app',
  ColorDefs = 'arkitekt.defs.colors',
  Timing = 'arkitekt.defs.timing',
  Typography = 'arkitekt.defs.typography',
  ReaperCommands = 'arkitekt.defs.reaper_commands',

  -- ==========================================================================
  -- APP / RUNTIME
  -- ==========================================================================
  Shell = 'arkitekt.app.runtime.shell',
  Fonts = 'arkitekt.app.assets.fonts',
  Window = 'arkitekt.app.chrome.window.window',
  StatusBar = 'arkitekt.app.chrome.status_bar.widget',

  -- ==========================================================================
  -- DEBUG
  -- ==========================================================================
  Logger = 'arkitekt.debug.logger',
  Console = 'arkitekt.debug.console',
  ProfilerInit = 'arkitekt.debug.profiler_init',

  -- ==========================================================================
  -- GUI - PRIMITIVES
  -- ==========================================================================
  Button = 'arkitekt.gui.widgets.primitives.button',
  Checkbox = 'arkitekt.gui.widgets.primitives.checkbox',
  RadioButton = 'arkitekt.gui.widgets.primitives.radio_button',
  Separator = 'arkitekt.gui.widgets.primitives.separator',
  Badge = 'arkitekt.gui.widgets.primitives.badge',
  Spinner = 'arkitekt.gui.widgets.primitives.spinner',
  Scrollbar = 'arkitekt.gui.widgets.primitives.scrollbar',
  Fields = 'arkitekt.gui.widgets.primitives.fields',
  CornerButton = 'arkitekt.gui.widgets.primitives.corner_button',
  HueSlider = 'arkitekt.gui.widgets.primitives.hue_slider',
  MarkdownField = 'arkitekt.gui.widgets.primitives.markdown_field',

  -- ==========================================================================
  -- GUI - INPUTS
  -- ==========================================================================
  Dropdown = 'arkitekt.gui.widgets.inputs.dropdown',
  SearchInput = 'arkitekt.gui.widgets.inputs.search_input',

  -- ==========================================================================
  -- GUI - DATA DISPLAY
  -- ==========================================================================
  Chip = 'arkitekt.gui.widgets.data.chip',
  ChipList = 'arkitekt.gui.widgets.data.chip_list',
  StatusPad = 'arkitekt.gui.widgets.data.status_pad',
  SelectionRectangle = 'arkitekt.gui.widgets.data.selection_rectangle',

  -- ==========================================================================
  -- GUI - NAVIGATION
  -- ==========================================================================
  TreeView = 'arkitekt.gui.widgets.navigation.tree_view',

  -- ==========================================================================
  -- GUI - TEXT
  -- ==========================================================================
  ColoredTextView = 'arkitekt.gui.widgets.text.colored_text_view',

  -- ==========================================================================
  -- GUI - CONTAINERS
  -- ==========================================================================
  Panel = 'arkitekt.gui.widgets.containers.panel',
  PanelDefaults = 'arkitekt.gui.widgets.containers.panel.defaults',
  PanelBackground = 'arkitekt.gui.widgets.containers.panel.background',
  PanelContent = 'arkitekt.gui.widgets.containers.panel.content',
  PanelHeader = 'arkitekt.gui.widgets.containers.panel.header',
  PanelHeaderLayout = 'arkitekt.gui.widgets.containers.panel.header.layout',
  PanelHeaderSeparator = 'arkitekt.gui.widgets.containers.panel.header.separator',
  TabStrip = 'arkitekt.gui.widgets.containers.panel.header.tab_strip',
  TabAnimator = 'arkitekt.gui.widgets.containers.panel.tab_animator',

  TileGroup = 'arkitekt.gui.widgets.containers.tile_group',
  TileGroupDefaults = 'arkitekt.gui.widgets.containers.tile_group.defaults',
  TileGroupHeader = 'arkitekt.gui.widgets.containers.tile_group.header',

  -- Grid system
  Grid = 'arkitekt.gui.widgets.containers.grid.core',
  GridLayout = 'arkitekt.gui.widgets.containers.grid.layout',
  GridInput = 'arkitekt.gui.widgets.containers.grid.input',
  GridRendering = 'arkitekt.gui.widgets.containers.grid.rendering',
  GridAnimation = 'arkitekt.gui.widgets.containers.grid.animation',
  GridBridge = 'arkitekt.gui.widgets.containers.grid.grid_bridge',
  GridDndState = 'arkitekt.gui.widgets.containers.grid.dnd_state',
  GridDropZones = 'arkitekt.gui.widgets.containers.grid.drop_zones',

  -- ==========================================================================
  -- GUI - OVERLAYS
  -- ==========================================================================
  OverlayManager = 'arkitekt.gui.widgets.overlays.overlay.manager',
  OverlayContainer = 'arkitekt.gui.widgets.overlays.overlay.container',
  OverlayDefaults = 'arkitekt.gui.widgets.overlays.overlay.defaults',
  OverlaySheet = 'arkitekt.gui.widgets.overlays.overlay.sheet',
  ModalDialog = 'arkitekt.gui.widgets.overlays.overlay.modal_dialog',
  ContextMenu = 'arkitekt.gui.widgets.overlays.context_menu',
  Tooltip = 'arkitekt.gui.widgets.overlays.tooltip',
  BatchRenameModal = 'arkitekt.gui.widgets.overlays.batch_rename_modal',

  -- ==========================================================================
  -- GUI - TOOLS
  -- ==========================================================================
  ColorPickerWindow = 'arkitekt.gui.widgets.tools.color_picker_window',
  ColorPickerMenu = 'arkitekt.gui.widgets.menus.color_picker_menu',

  -- ==========================================================================
  -- GUI - MEDIA
  -- ==========================================================================
  MediaGrid = 'arkitekt.gui.widgets.media.media_grid',
  PackageGrid = 'arkitekt.gui.widgets.media.package_tiles.grid',
  PackageRenderer = 'arkitekt.gui.widgets.media.package_tiles.renderer',
  PackageMicromanage = 'arkitekt.gui.widgets.media.package_tiles.micromanage',

  -- ==========================================================================
  -- GUI - EDITORS (Nodal)
  -- ==========================================================================
  NodalCanvas = 'arkitekt.gui.widgets.editors.nodal.canvas',
  NodalNode = 'arkitekt.gui.widgets.editors.nodal.core.node',
  NodalConnection = 'arkitekt.gui.widgets.editors.nodal.core.connection',
  NodalPort = 'arkitekt.gui.widgets.editors.nodal.core.port',
  NodalDefaults = 'arkitekt.gui.widgets.editors.nodal.defaults',
  NodalNodeRenderer = 'arkitekt.gui.widgets.editors.nodal.rendering.node_renderer',
  NodalConnectionRenderer = 'arkitekt.gui.widgets.editors.nodal.rendering.connection_renderer',
  NodalAutoLayout = 'arkitekt.gui.widgets.editors.nodal.systems.auto_layout',
  NodalViewport = 'arkitekt.gui.widgets.editors.nodal.systems.viewport',

  -- ==========================================================================
  -- GUI - DRAWING & RENDERING
  -- ==========================================================================
  Draw = 'arkitekt.gui.draw',
  Shapes = 'arkitekt.gui.rendering.shapes',
  Effects = 'arkitekt.gui.rendering.effects',
  TileRenderer = 'arkitekt.gui.rendering.tile.renderer',
  TileAnimator = 'arkitekt.gui.rendering.tile.animator',
  TileDefaults = 'arkitekt.gui.rendering.tile.defaults',

  -- ==========================================================================
  -- GUI - STYLE
  -- ==========================================================================
  Style = 'arkitekt.gui.style.defaults',
  ImGuiStyle = 'arkitekt.gui.style.imgui_defaults',

  -- ==========================================================================
  -- GUI - SYSTEMS
  -- ==========================================================================
  DragDrop = 'arkitekt.gui.systems.drag_drop',
  Selection = 'arkitekt.gui.systems.selection',
  HeightStabilizer = 'arkitekt.gui.systems.height_stabilizer',
  ResponsiveGrid = 'arkitekt.gui.systems.responsive_grid',
  MouseUtil = 'arkitekt.gui.systems.mouse_util',
  InteractionBlocking = 'arkitekt.gui.utils.interaction_blocking',

  -- ==========================================================================
  -- GUI - ANIMATION / FX
  -- ==========================================================================
  Easing = 'arkitekt.gui.fx.animation.easing',
  AnimationLifecycle = 'arkitekt.gui.fx.animation.lifecycle',
  AnimationTracks = 'arkitekt.gui.fx.animation.tracks',
  Dnd = 'arkitekt.gui.fx.interactions.dnd',
  MarchingAnts = 'arkitekt.gui.fx.interactions.marching_ants',

  -- ==========================================================================
  -- REAPER
  -- ==========================================================================
  Regions = 'arkitekt.reaper.regions',
  RegionOperations = 'arkitekt.reaper.region_operations',
  Transport = 'arkitekt.reaper.transport',
}

-- Lazy loading via __index metamethod
setmetatable(M, {
  __index = function(t, key)
    local path = module_map[key]
    if path then
      local ok, mod = pcall(require, path)
      if ok then
        rawset(t, key, mod)  -- Cache after first load
        return mod
      else
        error(string.format("Failed to load arkitekt module '%s' from '%s': %s", key, path, mod))
      end
    end
    return nil
  end
})

-- ==========================================================================
-- CONVENIENCE SHORTCUTS (loaded eagerly for common operations)
-- ==========================================================================

-- These are used SO frequently they deserve top-level access
-- Load Colors eagerly for hexrgb shortcut
local Colors = require('arkitekt.core.colors')
M.hexrgb = Colors.hexrgb
M.with_alpha = Colors.with_alpha
M.auto_text_color = Colors.auto_text_color
M.lerp_color = Colors.lerp
M.adjust_brightness = Colors.adjust_brightness

-- Load Utf8 eagerly for utf8 shortcut
local Utf8 = require('arkitekt.core.utf8')
M.utf8 = Utf8.utf8

-- Common math utilities
function M.lerp(a, b, t)
  return a + (b - a) * math.min(1.0, t)
end

function M.clamp(val, min, max)
  return math.max(min, math.min(max, val))
end

return M
