-- @noindex
-- arkitekt/gui/widgets/primitives/hue_slider.lua
-- DEPRECATED: Use arkitekt.gui.widgets.primitives.slider instead
-- This module is a shim for backwards compatibility

local Slider = require('arkitekt.gui.widgets.primitives.slider')

-- Forward all functions to Slider module
return {
  draw_hue = Slider.draw_hue,
  draw_saturation = Slider.draw_saturation,
  draw_gamma = Slider.draw_gamma,
}
