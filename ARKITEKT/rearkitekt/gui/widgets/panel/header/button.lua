-- @noindex
-- ReArkitekt/gui/widgets/panel/header/button.lua
-- Panel header button adapter - wraps base button with panel features

local BaseButton = require('rearkitekt.gui.widgets.controls.button')

local M = {}

-- ============================================================================
-- PANEL HEADER ADAPTER
-- ============================================================================
-- This is a thin wrapper that:
-- 1. Uses the base button component for rendering
-- 2. Passes panel state for proper ID generation
-- 3. Handles corner rounding from layout engine
-- 4. Maintains compatibility with existing panel header API

function M.draw(ctx, dl, x, y, width, height, config, state)
  -- Panel-specific: Pass state object (contains _panel_id)
  -- Base button will detect panel context and use it for unique ID
  return BaseButton.draw(ctx, dl, x, y, width, height, config, state)
end

function M.measure(ctx, config)
  -- Delegate to base button
  return BaseButton.measure(ctx, config)
end

-- ============================================================================
-- MIGRATION NOTES
-- ============================================================================
-- For existing code using panel headers, this adapter ensures:
-- - No breaking changes to existing panel code
-- - Corner rounding still works via config.corner_rounding
-- - State-based ID generation still works via state._panel_id
-- - All callbacks and tooltips work as before
--
-- The base button can now be used elsewhere:
--   local Button = require('rearkitekt.gui.widgets.controls.button')
--   Button.draw(ctx, dl, x, y, w, h, { label = "Click me" }, "my_button_id")

return M