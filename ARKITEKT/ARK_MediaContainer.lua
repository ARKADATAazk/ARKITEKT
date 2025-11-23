-- @description Media Container - Linked container groups for items
-- @version 0.1.0
-- @author ARKITEKT
-- @about
--   Create linked containers that mirror changes across all copies.
--   Perfect for glitch percussion and repetitive patterns.

-- ============================================================================
-- BOOTSTRAP ARKITEKT FRAMEWORK
-- ============================================================================
local ARK
do
  local sep = package.config:sub(1,1)
  local src = debug.getinfo(1, "S").source:sub(2)
  local path = src:match("(.*"..sep..")")
  while path and #path > 3 do
    local init = path .. "arkitekt" .. sep .. "app" .. sep .. "init" .. sep .. "init.lua"
    local f = io.open(init, "r")
    if f then
      f:close()
      local Init = dofile(init)
      ARK = Init.bootstrap()
      break
    end
    path = path:match("(.*"..sep..")[^"..sep.."]-"..sep.."$")
  end
  if not ARK then
    reaper.MB("ARKITEKT framework not found!", "FATAL ERROR", 0)
    return
  end
end

-- ============================================================================
-- LOAD MODULES
-- ============================================================================

local ImGui = require 'imgui' '0.10'
local Shell = require("arkitekt.app.runtime.shell")
local MediaContainer = require("MediaContainer.init")
local Colors = require("arkitekt.core.colors")

local hexrgb = Colors.hexrgb

-- Initialize
MediaContainer.initialize()

-- ============================================================================
-- RUN APPLICATION
-- ============================================================================

Shell.run({
  title        = "Media Container",
  version      = "v0.1.0",
  draw         = function(ctx, shell_state)
    local draw_list = ImGui.GetBackgroundDrawList(ctx)
    MediaContainer.update(ctx, draw_list)

    local containers = MediaContainer.get_containers()

    -- Action buttons
    local button_width = 80
    if ImGui.Button(ctx, "Create", button_width, 0) then
      MediaContainer.create_container()
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Copy", button_width, 0) then
      MediaContainer.copy_container()
    end
    ImGui.SameLine(ctx)
    if ImGui.Button(ctx, "Paste", button_width, 0) then
      MediaContainer.paste_container()
    end

    ImGui.Separator(ctx)

    -- Container count and list
    ImGui.Text(ctx, string.format("Containers: %d", #containers))

    if #containers > 0 then
      -- Scrollable list
      if ImGui.BeginChild(ctx, "ContainerList", 0, 120) then
        for i, container in ipairs(containers) do
          local linked_text = container.master_id and " [linked]" or " [master]"
          local label = string.format("%s%s (%d items)", container.name, linked_text, #container.items)

          -- Color indicator
          local r, g, b, a = Colors.rgba_to_components(container.color or 0xFF6600FF)
          ImGui.PushStyleColor(ctx, ImGui.Col_Text, ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, 1))
          ImGui.Bullet(ctx)
          ImGui.PopStyleColor(ctx, 1)
          ImGui.SameLine(ctx)

          -- Selectable item - click to select items in Reaper
          if ImGui.Selectable(ctx, label, false) then
            MediaContainer.select_container(container.id)
          end

          -- Context menu for individual container
          if ImGui.BeginPopupContextItem(ctx) then
            if ImGui.MenuItem(ctx, "Delete") then
              MediaContainer.delete_container(container.id)
            end
            ImGui.EndPopup(ctx)
          end
        end
        ImGui.EndChild(ctx)
      end

      ImGui.Separator(ctx)

      -- Delete all button
      ImGui.PushStyleColor(ctx, ImGui.Col_Button, hexrgb("#662222FF"))
      ImGui.PushStyleColor(ctx, ImGui.Col_ButtonHovered, hexrgb("#883333FF"))
      if ImGui.Button(ctx, "Delete All", -1, 0) then
        -- Clear all containers
        local State = MediaContainer.State
        State.containers = {}
        State.container_lookup = {}
        State.persist()
      end
      ImGui.PopStyleColor(ctx, 2)
    else
      ImGui.TextDisabled(ctx, "No containers yet")
      ImGui.TextDisabled(ctx, "Select items and click Create")
    end

    ImGui.Separator(ctx)
    ImGui.TextDisabled(ctx, "Sync: Active")
  end,
  initial_pos  = { x = 100, y = 100 },
  initial_size = { w = 300, h = 300 },
  icon_color   = hexrgb("#FF9933"),
  icon_size    = 18,
  min_size     = { w = 280, h = 200 },
})
