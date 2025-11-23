-- @noindex
-- TemplateBrowser/domain/fx_queue.lua
-- Background FX parsing queue to prevent UI lag

local M = {}
local FXParser = require('TemplateBrowser.domain.fx_parser')

-- Initialize parsing queue
function M.init_queue(state)
  state.fx_queue = {
    templates = {},  -- Array of templates to parse
    index = 0,       -- Current parsing index
    total = 0,       -- Total templates to parse
    complete = false -- Whether parsing is complete
  }
end

-- Add templates to parsing queue
function M.add_to_queue(state, templates)
  if not state.fx_queue then
    M.init_queue(state)
  end

  -- Only add templates that need FX parsing (new or modified)
  local added = 0
  for _, tmpl in ipairs(templates) do
    if tmpl.needs_fx_parse then
      table.insert(state.fx_queue.templates, tmpl)
      added = added + 1
    end
  end

  state.fx_queue.total = #state.fx_queue.templates
  state.fx_queue.index = 0
  state.fx_queue.complete = (added == 0)  -- If nothing to parse, mark as complete

  if added > 0 then
    reaper.ShowConsoleMsg(string.format("FX Queue: Added %d templates for parsing (%d cached)\n",
                                        added, #templates - added))
  else
    reaper.ShowConsoleMsg("FX Queue: All templates cached, no parsing needed\n")
  end
end

-- Process a batch of templates (called per frame)
function M.process_batch(state, batch_size)
  batch_size = batch_size or 5  -- Default: parse 5 templates per frame

  if not state.fx_queue or state.fx_queue.complete then
    return false  -- Nothing to process
  end

  local processed = 0
  local start_index = state.fx_queue.index + 1

  for i = start_index, math.min(start_index + batch_size - 1, state.fx_queue.total) do
    local tmpl = state.fx_queue.templates[i]

    -- Parse FX from template file
    local fx_list = FXParser.parse_template_fx(tmpl.path)

    -- Update template FX
    tmpl.fx = fx_list

    -- Update metadata if it exists
    if state.metadata and state.metadata.templates and state.metadata.templates[tmpl.uuid] then
      state.metadata.templates[tmpl.uuid].fx = fx_list
      -- Ensure file_size is stored (should already be set during scan, but just to be safe)
      if not state.metadata.templates[tmpl.uuid].file_size then
        local file_handle = io.open(tmpl.path, "r")
        if file_handle then
          file_handle:seek("end")
          state.metadata.templates[tmpl.uuid].file_size = file_handle:seek()
          file_handle:close()
        end
      end
    end

    state.fx_queue.index = i
    processed = processed + 1
  end

  -- Check if complete
  if state.fx_queue.index >= state.fx_queue.total then
    state.fx_queue.complete = true
    reaper.ShowConsoleMsg("FX Queue: Parsing complete!\n")

    -- Save metadata with updated FX
    if state.metadata then
      local Persistence = require('TemplateBrowser.domain.persistence')
      Persistence.save_metadata(state.metadata)
    end

    -- Re-filter templates to update FX display
    local Scanner = require('TemplateBrowser.domain.scanner')
    Scanner.filter_templates(state)
  end

  return true  -- Still processing
end

-- Get parsing progress (0.0 to 1.0)
function M.get_progress(state)
  if not state.fx_queue or state.fx_queue.total == 0 then
    return 1.0  -- No queue or empty queue = complete
  end

  return state.fx_queue.index / state.fx_queue.total
end

-- Check if parsing is complete
function M.is_complete(state)
  if not state.fx_queue then
    return true
  end
  return state.fx_queue.complete
end

-- Get status string for UI
function M.get_status(state)
  if not state.fx_queue or state.fx_queue.complete then
    return ""
  end

  return string.format("Parsing VSTs: %d/%d", state.fx_queue.index, state.fx_queue.total)
end

return M
