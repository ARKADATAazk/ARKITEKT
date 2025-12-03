-- @noindex
-- arkitekt/gui/widgets/primitives/hue_slider.lua
-- DEPRECATED: Use arkitekt.gui.widgets.primitives.slider instead
-- This module forwards to Slider for backwards compatibility

local Slider = require('arkitekt.gui.widgets.primitives.slider')

return {
  DrawHue = Slider.DrawHue,
  DrawSaturation = Slider.DrawSaturation,
  DrawGamma = Slider.DrawGamma,
}
