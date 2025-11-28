-- @noindex
-- TemplateBrowser/domain/tags/service.lua
-- Tag management

local Logger = require('arkitekt.debug.logger')
local ark = require('arkitekt')

local M = {}

-- Create a new tag
function M.create_tag(metadata, tag_name, color)
  if metadata.tags[tag_name] then
    Logger.warn("TAGS", "Tag already exists: %s", tag_name)
    return false
  end

  metadata.tags[tag_name] = {
    name = tag_name,
    color = color or ark.Colors.hexrgb("#646464"),  -- Default dark grey
    created = os.time()
  }

  Logger.info("TAGS", "Created tag: %s", tag_name)
  return true
end

-- Rename a tag
function M.rename_tag(metadata, old_name, new_name)
  if not metadata.tags[old_name] then
    Logger.warn("TAGS", "Tag not found: %s", old_name)
    return false
  end

  if metadata.tags[new_name] then
    Logger.warn("TAGS", "Tag already exists: %s", new_name)
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

  Logger.info("TAGS", "Renamed tag: %s -> %s", old_name, new_name)
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
  Logger.info("TAGS", "Deleted tag: %s", tag_name)
  return true
end

-- Add tag to template
function M.add_tag_to_template(metadata, template_uuid, tag_name)
  local tmpl = metadata.templates[template_uuid]
  if not tmpl then
    Logger.warn("TAGS", "Template not found: %s", template_uuid)
    return false
  end

  if not metadata.tags[tag_name] then
    Logger.warn("TAGS", "Tag not found: %s", tag_name)
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

  tmpl.tags[#tmpl.tags + 1] = tag_name
  Logger.debug("TAGS", "Added tag '%s' to template: %s", tag_name, tmpl.name)
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
      Logger.debug("TAGS", "Removed tag '%s' from template: %s", tag_name, tmpl.name)
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

  fld.tags[#fld.tags + 1] = tag_name
  Logger.debug("TAGS", "Added tag '%s' to folder: %s", tag_name, fld.name)
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
  Logger.debug("TAGS", "Updated notes for template: %s", tmpl.name)
  return true
end

-- Get templates by tag
function M.get_templates_by_tag(metadata, tag_name)
  local results = {}

  for uuid, tmpl in pairs(metadata.templates) do
    if tmpl.tags then
      for _, t in ipairs(tmpl.tags) do
        if t == tag_name then
          results[#results + 1] = tmpl
          break
        end
      end
    end
  end

  return results
end

return M
