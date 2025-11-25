-- ARKITEKT Namespace
-- Provides ImGui-style access to all widgets via lazy loading
-- Usage: local ark = dofile(debug.getinfo(1,"S").source:sub(2):match("(.-ARKITEKT[/\\])") .. "arkitekt/init.lua")
--        ark.Button.draw(ctx, {label = "Click"})

-- ============================================================================
-- AUTO-BOOTSTRAP
-- ============================================================================
-- Run bootstrap to set up package paths and validate dependencies
local bootstrap_path = debug.getinfo(1,"S").source:sub(2):match("(.-arkitekt[/\\])") .. "app/bootstrap.lua"
local bootstrap_context = dofile(bootstrap_path).init()

if not bootstrap_context then
  error("ARKITEKT bootstrap failed - cannot continue")
end

local ark = {}

-- Store bootstrap context for scripts that need it (ImGui, utilities, etc.)
ark._bootstrap = bootstrap_context

-- Module registry - maps names to module paths
-- Lazy loaded on first access to minimize startup overhead
local MODULES = {
  -- Primitives (alphabetically sorted)
  Badge = 'arkitekt.gui.widgets.primitives.badge',
  Button = 'arkitekt.gui.widgets.primitives.button',
  Checkbox = 'arkitekt.gui.widgets.primitives.checkbox',
  CloseButton = 'arkitekt.gui.widgets.primitives.close_button',
  Combo = 'arkitekt.gui.widgets.primitives.combo',
  CornerButton = 'arkitekt.gui.widgets.primitives.corner_button',
  HueSlider = 'arkitekt.gui.widgets.primitives.hue_slider',
  InputText = 'arkitekt.gui.widgets.primitives.inputtext',
  MarkdownField = 'arkitekt.gui.widgets.primitives.markdown_field',
  RadioButton = 'arkitekt.gui.widgets.primitives.radio_button',
  Scrollbar = 'arkitekt.gui.widgets.primitives.scrollbar',
  Separator = 'arkitekt.gui.widgets.primitives.separator',
  Slider = 'arkitekt.gui.widgets.primitives.slider',
  Spinner = 'arkitekt.gui.widgets.primitives.spinner',

  -- Containers
  Panel = 'arkitekt.gui.widgets.containers.panel',
  TileGroup = 'arkitekt.gui.widgets.containers.tile_group',

  -- Utilities (commonly used modules)
  Anim = 'arkitekt.core.animation',
  Colors = 'arkitekt.core.colors',
  Style = 'arkitekt.gui.style.defaults',
  Draw = 'arkitekt.gui.draw',
  Easing = 'arkitekt.gui.fx.animation.easing',
  Math = 'arkitekt.core.math',
  UUID = 'arkitekt.core.uuid',
}

-- Lazy loading with metatable
-- Widgets are only loaded when first accessed (like ImGui namespace)
setmetatable(ark, {
  __index = function(t, key)
    local module_path = MODULES[key]
    if module_path then
      -- Load and cache the module
      local success, module = pcall(require, module_path)
      if success then
        t[key] = module  -- Cache to avoid future requires
        return module
      else
        error(string.format("ark.%s: Failed to load module '%s'\n%s",
                          key, module_path, module), 2)
      end
    end
    error(string.format("ark.%s is not a valid widget. See MODULES table in arkitekt/init.lua", key), 2)
  end
})

return ark
