-- @noindex
-- Arkitekt/app/hub.lua
-- Embedded hub for launching apps and managing settings

package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua;' .. package.path
local ImGui = require 'imgui' '0.10'

local M = {}

local function scan_apps(base_path)
  local apps = {}
  
  -- Scan for ARK_*.lua scripts
  local i = 0
  repeat
    local file = reaper.EnumerateFiles(base_path, i)
    if file and file:match("^ARK_.*%.lua$") then
      table.insert(apps, {
        name = file:match("^ARK_(.*)%.lua$"),
        path = base_path .. file,
        file = file,
      })
    end
    i = i + 1
  until not file
  
  return apps
end

function M.launch_app(app_path)
  if not reaper.file_exists(app_path) then
    reaper.ShowConsoleMsg("App not found: " .. app_path .. "\n")
    return false
  end
  
  -- Try to find existing registered command
  local sanitized = app_path:gsub("[^%w]", "")
  local cmd_name = "_RS" .. sanitized
  local cmd_id = reaper.NamedCommandLookup(cmd_name)
  
  -- If not found, register it now
  if not cmd_id or cmd_id == 0 then
    local section_id = 0
    cmd_id = reaper.AddRemoveReaScript(true, section_id, app_path, true)
    
    if not cmd_id or cmd_id == 0 then
      reaper.ShowConsoleMsg("Failed to register script: " .. app_path .. "\n")
      return false
    end
  end
  
  reaper.Main_OnCommand(cmd_id, 0)
  return true
end

function M.render_hub(ctx, opts)
  opts = opts or {}
  local apps_path = opts.apps_path or ""
  
  ImGui.Text(ctx, "ARKITEKT Hub")
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 1, 10)
  
  local apps = scan_apps(apps_path)
  
  if #apps == 0 then
    ImGui.TextWrapped(ctx, "No apps found in: " .. apps_path)
    ImGui.Dummy(ctx, 1, 10)
    ImGui.TextWrapped(ctx, "Place ARK_*.lua scripts in this directory to see them here.")
  else
    ImGui.Text(ctx, "Available Apps:")
    ImGui.Dummy(ctx, 1, 5)
    
    for _, app in ipairs(apps) do
      if ImGui.Button(ctx, app.name .. "##launch_" .. app.file, 200, 30) then
        M.launch_app(app.path)
      end
      
      if ImGui.IsItemHovered(ctx) then
        ImGui.SetTooltip(ctx, app.path)
      end
    end
  end
  
  ImGui.Dummy(ctx, 1, 20)
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 1, 10)
  
  ImGui.Text(ctx, "Settings")
  ImGui.TextWrapped(ctx, "Theme and general settings coming soon...")
end

return M