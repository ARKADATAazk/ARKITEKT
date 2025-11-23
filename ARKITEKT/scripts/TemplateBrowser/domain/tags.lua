-- @noindex
-- TemplateBrowser/domain/tags.lua
-- Tag management

local Colors = require('arkitekt.core.colors')

local M = {}

-- Create a new tag
function M.create_tag(metadata, tag_name, color)
  if metadata.tags[tag_name] then
    reaper.ShowConsoleMsg("Tag already exists: " .. tag_name .. "\n")
    return false
  end

  metadata.tags[tag_name] = {
    name = tag_name,
    color = color or Colors.hexrgb("#646464"),  -- Default dark grey
    created = os.time()
  }

  reaper.ShowConsoleMsg("Created tag: " .. tag_name .. "\n")
  return true
end

-- Rename a tag
function M.rename_tag(metadata, old_name, new_name)
  if not metadata.tags[old_name] then
    reaper.ShowConsoleMsg("Tag not found: " .. old_name .. "\n")
    return false
  end

  if metadata.tags[new_name] then
    reaper.ShowConsoleMsg("Tag already exists: " .. new_name .. "\n")
    return false
  end

  -- Copy tag data with new name
  local tag_data = metadata.tags[old_name]
  tag_data.name = new_name
  metadata.tags[new_name] = tag_data
  metadata.tags[old_name] = nil

  -- Update tag references in all templates
  for _, tmpl in pairs(metadata.templates) do
    if tmpl.tags then
      for i, t in ipairs(tmpl.tags) do
        if t == old_name then
          tmpl.tags[i] = new_name
        end
      end
    end
  end

  -- Update tag references in all folders
  for _, fld in pairs(metadata.folders) do
    if fld.tags then
      for i, t in ipairs(fld.tags) do
        if t == old_name then
          fld.tags[i] = new_name
        end
      end
    end
  end

  reaper.ShowConsoleMsg("Renamed tag: " .. old_name .. " -> " .. new_name .. "\n")
  return true
end

-- Delete a tag
function M.delete_tag(metadata, tag_name)
  if not metadata.tags[tag_name] then
    return false
  end

  -- Remove tag from all templates
  for _, tmpl in pairs(metadata.templates) do
    if tmpl.tags then
      for i = #tmpl.tags, 1, -1 do
        if tmpl.tags[i] == tag_name then
          table.remove(tmpl.tags, i)
        end
      end
    end
  end

  -- Remove tag from all folders
  for _, fld in pairs(metadata.folders) do
    if fld.tags then
      for i = #fld.tags, 1, -1 do
        if fld.tags[i] == tag_name then
          table.remove(fld.tags, i)
        end
      end
    end
  end

  metadata.tags[tag_name] = nil
  reaper.ShowConsoleMsg("Deleted tag: " .. tag_name .. "\n")
  return true
end

-- Add tag to template
function M.add_tag_to_template(metadata, template_uuid, tag_name)
  local tmpl = metadata.templates[template_uuid]
  if not tmpl then
    reaper.ShowConsoleMsg("Template not found: " .. template_uuid .. "\n")
    return false
  end

  if not metadata.tags[tag_name] then
    reaper.ShowConsoleMsg("Tag not found: " .. tag_name .. "\n")
    return false
  end

  if not tmpl.tags then
    tmpl.tags = {}
  end

  -- Check if already has tag
  for _, t in ipairs(tmpl.tags) do
    if t == tag_name then
      return false  -- Already has tag
    end
  end

  table.insert(tmpl.tags, tag_name)
  reaper.ShowConsoleMsg("Added tag '" .. tag_name .. "' to template: " .. tmpl.name .. "\n")
  return true
end

-- Remove tag from template
function M.remove_tag_from_template(metadata, template_uuid, tag_name)
  local tmpl = metadata.templates[template_uuid]
  if not tmpl or not tmpl.tags then
    return false
  end

  for i, t in ipairs(tmpl.tags) do
    if t == tag_name then
      table.remove(tmpl.tags, i)
      reaper.ShowConsoleMsg("Removed tag '" .. tag_name .. "' from template: " .. tmpl.name .. "\n")
      return true
    end
  end

  return false
end

-- Add tag to folder
function M.add_tag_to_folder(metadata, folder_uuid, tag_name)
  local fld = metadata.folders[folder_uuid]
  if not fld then
    return false
  end

  if not metadata.tags[tag_name] then
    return false
  end

  if not fld.tags then
    fld.tags = {}
  end

  -- Check if already has tag
  for _, t in ipairs(fld.tags) do
    if t == tag_name then
      return false
    end
  end

  table.insert(fld.tags, tag_name)
  reaper.ShowConsoleMsg("Added tag '" .. tag_name .. "' to folder: " .. fld.name .. "\n")
  return true
end

-- Remove tag from folder
function M.remove_tag_from_folder(metadata, folder_uuid, tag_name)
  local fld = metadata.folders[folder_uuid]
  if not fld or not fld.tags then
    return false
  end

  for i, t in ipairs(fld.tags) do
    if t == tag_name then
      table.remove(fld.tags, i)
      return true
    end
  end

  return false
end

-- Set notes for template
function M.set_template_notes(metadata, template_uuid, notes)
  local tmpl = metadata.templates[template_uuid]
  if not tmpl then
    return false
  end

  tmpl.notes = notes
  reaper.ShowConsoleMsg("Updated notes for template: " .. tmpl.name .. "\n")
  return true
end

-- Get templates by tag
function M.get_templates_by_tag(metadata, tag_name)
  local results = {}

  for uuid, tmpl in pairs(metadata.templates) do
    if tmpl.tags then
      for _, t in ipairs(tmpl.tags) do
        if t == tag_name then
          table.insert(results, tmpl)
          break
        end
      end
    end
  end

  return results
end

return M
