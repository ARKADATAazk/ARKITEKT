-- @noindex
-- TemplateBrowser/ui/tiles/grid_callbacks.lua
-- Factory for creating grid callback handlers
-- Eliminates ~300 LOC duplication between template_grid and quick_access_grid

-- Dependencies (cached at module load per Lua Performance Guide)
local ImGui = require('arkitekt.platform.imgui')
local TemplateOps = require('TemplateBrowser.domain.template.ops')
local Persistence = require('TemplateBrowser.infra.storage')
local Tags = require('TemplateBrowser.domain.tags.service')
local Scanner = require('TemplateBrowser.domain.template.scanner')

local M = {}

--- Create grid callbacks for template or quick access grids
--- @param gui table GUI instance with state, config references
--- @param get_templates_fn function Function that returns current templates list
--- @param opts table? Options: is_quick_access (boolean)
--- @return table Callbacks table for TemplateGridFactory.create()
function M.create(gui, get_templates_fn, opts)
  opts = opts or {}
  local is_quick_access = opts.is_quick_access or false

  return {
    --- Handle template selection
    --- @param selected_keys table Array of selected template keys
    on_select = function(selected_keys)
      -- Store selected keys only for main grid (not quick access)
      if not is_quick_access then
        gui.state.selected_template_keys = selected_keys or {}
      end

      -- Update selected template from grid selection
      if selected_keys and #selected_keys > 0 then
        local key = selected_keys[1]
        local uuid = key:match("template_(.+)")
        local templates = get_templates_fn()

        for _, tmpl in ipairs(templates) do
          if tmpl.uuid == uuid then
            gui.state.selected_template = tmpl
            break
          end
        end
      else
        gui.state.selected_template = nil
      end
    end,

    --- Handle double-click on template
    --- @param template table Template object
    on_double_click = function(template)
      if not template then return end

      -- Check for rename (Ctrl+DoubleClick) only on main grid
      if not is_quick_access then
        local ctrl_down = ImGui.IsKeyDown(gui.ctx, ImGui.Mod_Ctrl)
        if ctrl_down then
          -- Start rename
          gui.state.renaming_item = template
          gui.state.renaming_type = "template"
          gui.state.rename_buffer = template.name
          return
        end
      end

      -- Apply template to track
      TemplateOps.apply_to_selected_track(template.path, template.uuid, gui.state)
    end,

    --- Handle right-click on template
    --- @param template table Template object
    --- @param selected_keys table Array of selected template keys (unused)
    on_right_click = function(template, selected_keys)
      if template then
        -- Set context menu template for color picker / context menu
        gui.state.context_menu_template = template
      end
    end,

    --- Handle star/favorite click
    --- @param template table Template object
    on_star_click = function(template)
      if not template then return end

      local favorites_id = "__FAVORITES__"

      -- Get favorites folder
      local favorites = gui.state.metadata.virtual_folders[favorites_id]
      if not favorites then
        gui.state.set_status("Favorites folder not found", "error")
        return
      end

      -- Check if template is already favorited
      local is_favorited = false
      local favorite_index = nil
      for idx, ref_uuid in ipairs(favorites.template_refs) do
        if ref_uuid == template.uuid then
          is_favorited = true
          favorite_index = idx
          break
        end
      end

      -- Toggle favorite status
      if is_favorited then
        table.remove(favorites.template_refs, favorite_index)
        gui.state.set_status("Removed from Favorites: " .. template.name, "success")
      else
        table.insert(favorites.template_refs, template.uuid)
        gui.state.set_status("Added to Favorites: " .. template.name, "success")
      end

      -- Save metadata
      Persistence.save_metadata(gui.state.metadata)

      -- If currently viewing Favorites folder, refresh the filter
      if gui.state.selected_folder == favorites_id then
        Scanner.filter_templates(gui.state)
      end
    end,

    --- Handle tag drop onto template
    --- @param template table Template object
    --- @param payload table Drag payload with tag info
    on_tag_drop = function(template, payload)
      if not template or not payload then return end

      -- Get tag name from payload
      local tag_name = payload.label or payload.id
      if not tag_name then return end

      -- Check if dropped template is in selection
      local template_key = "template_" .. template.uuid
      local is_selected = false
      local selected_keys = is_quick_access and {} or (gui.state.selected_template_keys or {})

      for _, key in ipairs(selected_keys) do
        if key == template_key then
          is_selected = true
          break
        end
      end

      local tagged_count = 0

      if is_selected and #selected_keys > 1 then
        -- Multi-select: tag all selected templates
        for _, key in ipairs(selected_keys) do
          local uuid = key:match("template_(.+)")
          if uuid and Tags.add_tag_to_template(gui.state.metadata, uuid, tag_name) then
            tagged_count = tagged_count + 1
          end
        end
      else
        -- Single: tag only dropped template
        if Tags.add_tag_to_template(gui.state.metadata, template.uuid, tag_name) then
          tagged_count = 1
        end
      end

      -- Save metadata
      Persistence.save_metadata(gui.state.metadata)

      -- Re-filter if tag filters active
      if next(gui.state.filter_tags) then
        Scanner.filter_templates(gui.state)
      end

      -- Status message
      if tagged_count > 1 then
        gui.state.set_status("Tagged " .. tagged_count .. " templates with " .. tag_name, "success")
      elseif tagged_count == 1 then
        gui.state.set_status("Tagged \"" .. template.name .. "\" with " .. tag_name, "success")
      end
    end,
  }
end

return M
