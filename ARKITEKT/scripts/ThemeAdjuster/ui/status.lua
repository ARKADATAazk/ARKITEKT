-- @noindex
-- ThemeAdjuster/ui/status.lua
-- Status bar configuration

local Constants = require('ThemeAdjuster.defs.constants')

local M = {}

local STATUS_COLORS = Constants.STATUS

local function get_app_status(State)
  return function()
    local ok, result = pcall(function()
      local status_message = nil
      local status_color = STATUS_COLORS.READY

      -- Determine status based on cache and theme state
      local cache_status = State.get_cache_status()
      local theme_status = State.get_theme_status()

      if cache_status == "needs_rebuild" then
        status_message = "Cache needs rebuild"
        status_color = STATUS_COLORS.WARNING
      elseif cache_status == "rebuilding" then
        status_message = "Rebuilding cache..."
        status_color = STATUS_COLORS.INFO
      elseif theme_status == "needs-link" then
        status_message = "Theme not linked"
        status_color = STATUS_COLORS.ERROR
      else
        -- Show demo mode status or ready
        if State.get_demo_mode() then
          status_message = "Demo Mode - " .. #State.get_packages() .. " packages"
          status_color = STATUS_COLORS.INFO
        else
          local packages = State.get_packages()
          local active_count = 0
          local active_packages = State.get_active_packages()
          for pkg_id, is_active in pairs(active_packages) do
            if is_active then active_count = active_count + 1 end
          end

          status_message = string.format("%d/%d packages active", active_count, #packages)
          status_color = STATUS_COLORS.READY
        end
      end

      return {
        color = status_color,
        text = status_message or "Ready",
        buttons = nil,
        right_buttons = nil,
      }
    end)

    if ok then
      return result
    else
      return {
        color = STATUS_COLORS.ERROR,
        text = "Status Error: " .. tostring(result),
        buttons = nil,
        right_buttons = nil,
      }
    end
  end
end

function M.get_status_func(State)
  return get_app_status(State)
end

return M
