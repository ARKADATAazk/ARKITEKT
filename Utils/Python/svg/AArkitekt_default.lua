-- @noindex
-- Generated from AArkitekt_default.svg
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

-- Auto-generated from AArkitekt_default.svg
-- Normalized: True
-- Bounds: (910.00, 335.00) to (1148.00, 557.00)
-- ViewBox: 0.0 0.0 410.0 277.0
function M.draw_AArkitekt_default(ctx, x, y, size, color)
  local dl = ImGui.GetWindowDrawList(ctx)
  local dpi = ImGui.GetWindowDpiScale(ctx)
  local s = size * dpi

  -- Path 1
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.534445, y + s*0.044154)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.464979, y + s*0.211595, x + s*0.205739, y + s*0.495412, x + s*0.105644, y + s*0.595469)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.000000, y + s*0.701114, x + s*0.607954, y + s*0.950761, x + s*0.607954, y + s*0.950761)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.668978)
  ImGui.DrawList_PathLineTo(dl, x + s*0.872462, y + s*0.525232)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.872462, y + s*0.525232, x + s*0.829215, y + s*0.478578, x + s*0.780944, y + s*0.352327)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.769550, y + s*0.324859, x + s*0.832645, y + s*0.109920, x + s*0.840731, y + s*0.093160)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.883366, y + s*0.004178, x + s*0.552700, y + s*0.000000, x + s*0.534445, y + s*0.044154)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.5 * dpi)

  -- Path 2
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.028915)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*1.000000, y + s*0.012957, x + s*0.987365, y + s*0.000000, x + s*0.971875, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.651507, y + s*0.000000)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.636017, y + s*0.000000, x + s*0.623382, y + s*0.012957, x + s*0.623382, y + s*0.028915)
  ImGui.DrawList_PathLineTo(dl, x + s*0.623382, y + s*0.141171)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.623382, y + s*0.157129, x + s*0.636017, y + s*0.170086, x + s*0.651507, y + s*0.170086)
  ImGui.DrawList_PathLineTo(dl, x + s*0.971875, y + s*0.170086)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.987365, y + s*0.170086, x + s*1.000000, y + s*0.157129, x + s*1.000000, y + s*0.141171)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.028915)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.5 * dpi)

  -- Path 3
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.028915)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*1.000000, y + s*0.012957, x + s*0.973029, y + s*0.000000, x + s*0.939741, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.683641, y + s*0.000000)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.650353, y + s*0.000000, x + s*0.623382, y + s*0.012957, x + s*0.623382, y + s*0.028915)
  ImGui.DrawList_PathLineTo(dl, x + s*0.623382, y + s*0.141171)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.623382, y + s*0.157129, x + s*0.650353, y + s*0.170086, x + s*0.683641, y + s*0.170086)
  ImGui.DrawList_PathLineTo(dl, x + s*0.939741, y + s*0.170086)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.973029, y + s*0.170086, x + s*1.000000, y + s*0.157129, x + s*1.000000, y + s*0.141171)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.028915)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.5 * dpi)

  -- Path 4
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.013649)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*1.000000, y + s*0.006117, x + s*0.971328, y + s*0.000000, x + s*0.935975, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.687407, y + s*0.000000)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.652053, y + s*0.000000, x + s*0.623382, y + s*0.006117, x + s*0.623382, y + s*0.013649)
  ImGui.DrawList_PathLineTo(dl, x + s*0.623382, y + s*0.156436)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.623382, y + s*0.163969, x + s*0.652053, y + s*0.170086, x + s*0.687407, y + s*0.170086)
  ImGui.DrawList_PathLineTo(dl, x + s*0.935975, y + s*0.170086)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.971328, y + s*0.170086, x + s*1.000000, y + s*0.163969, x + s*1.000000, y + s*0.156436)
  ImGui.DrawList_PathLineTo(dl, x + s*1.000000, y + s*0.013649)
  ImGui.DrawList_PathStroke(dl, color, ImGui.DrawFlags_Closed, 2.5 * dpi)

  -- Path 5
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.184465, y + s*0.020722)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.182430, y + s*0.072317, x + s*0.193161, y + s*0.131730, x + s*0.240987, y + s*0.181730)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.269696, y + s*0.211743, x + s*0.000000, y + s*0.188430, x + s*0.000000, y + s*0.188430)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.000000, y + s*0.188430, x + s*0.047100, y + s*0.158722, x + s*0.047826, y + s*0.040604)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.047961, y + s*0.018865, x + s*0.126087, y + s*0.040604, x + s*0.126087, y + s*0.040604)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.126087, y + s*0.040604, x + s*0.185557, y + s*0.000000, x + s*0.184465, y + s*0.020722)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 6
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.282609, y + s*0.573213)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.282609, y + s*0.632934, x + s*0.429409, y + s*0.779735, x + s*0.489130, y + s*0.779735)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.548851, y + s*0.779735, x + s*0.695652, y + s*0.632934, x + s*0.695652, y + s*0.573213)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.695652, y + s*0.513492, x + s*0.548851, y + s*0.366691, x + s*0.489130, y + s*0.366691)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.429409, y + s*0.366691, x + s*0.282609, y + s*0.513492, x + s*0.282609, y + s*0.573213)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 7
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.000000, y + s*0.249324)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.000000, y + s*0.289419, x + s*0.098560, y + s*0.387979, x + s*0.138655, y + s*0.387979)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.178751, y + s*0.387979, x + s*0.277311, y + s*0.289419, x + s*0.277311, y + s*0.249324)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.277311, y + s*0.209228, x + s*0.178751, y + s*0.110668, x + s*0.138655, y + s*0.110668)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.098560, y + s*0.110668, x + s*0.000000, y + s*0.209228, x + s*0.000000, y + s*0.249324)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 8
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.869748, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.869748, y + s*0.659664)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.659664)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.000000)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 9
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.306723, y + s*0.790907, x + s*0.448589, y + s*0.932773, x + s*0.506303, y + s*0.932773)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.564016, y + s*0.932773, x + s*0.705882, y + s*0.790907, x + s*0.705882, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.705882, y + s*0.675480, x + s*0.564016, y + s*0.533613, x + s*0.506303, y + s*0.533613)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.448589, y + s*0.533613, x + s*0.306723, y + s*0.675480, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 10
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.306723, y + s*0.790907, x + s*0.448589, y + s*0.932773, x + s*0.506303, y + s*0.932773)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.564016, y + s*0.932773, x + s*0.705882, y + s*0.790907, x + s*0.705882, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.705882, y + s*0.675480, x + s*0.564016, y + s*0.533613, x + s*0.506303, y + s*0.533613)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.448589, y + s*0.533613, x + s*0.306723, y + s*0.675480, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 11
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.306723, y + s*0.790907, x + s*0.448589, y + s*0.932773, x + s*0.506303, y + s*0.932773)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.564016, y + s*0.932773, x + s*0.705882, y + s*0.790907, x + s*0.705882, y + s*0.733193)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.705882, y + s*0.675480, x + s*0.564016, y + s*0.533613, x + s*0.506303, y + s*0.533613)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.448589, y + s*0.533613, x + s*0.306723, y + s*0.675480, x + s*0.306723, y + s*0.733193)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 12
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.000000, y + s*0.428571)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.000000, y + s*0.468667, x + s*0.098560, y + s*0.567227, x + s*0.138655, y + s*0.567227)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.178751, y + s*0.567227, x + s*0.277311, y + s*0.468667, x + s*0.277311, y + s*0.428571)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.277311, y + s*0.388476, x + s*0.178751, y + s*0.289916, x + s*0.138655, y + s*0.289916)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.098560, y + s*0.289916, x + s*0.000000, y + s*0.388476, x + s*0.000000, y + s*0.428571)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 13
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.000000, y + s*0.428571)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.000000, y + s*0.468667, x + s*0.098560, y + s*0.567227, x + s*0.138655, y + s*0.567227)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.178751, y + s*0.567227, x + s*0.277311, y + s*0.468667, x + s*0.277311, y + s*0.428571)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.277311, y + s*0.388476, x + s*0.178751, y + s*0.289916, x + s*0.138655, y + s*0.289916)
  ImGui.DrawList_PathBezierCubicCurveTo(dl, x + s*0.098560, y + s*0.289916, x + s*0.000000, y + s*0.388476, x + s*0.000000, y + s*0.428571)
  ImGui.DrawList_PathFillConvex(dl, color)

  -- Path 14
  ImGui.DrawList_PathClear(dl)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.869748, y + s*0.000000)
  ImGui.DrawList_PathLineTo(dl, x + s*0.869748, y + s*0.659664)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.659664)
  ImGui.DrawList_PathLineTo(dl, x + s*0.655462, y + s*0.000000)
  ImGui.DrawList_PathFillConvex(dl, color)
end

return M