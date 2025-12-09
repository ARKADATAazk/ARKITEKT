-- @noindex
local M = {}
-- Note: Disk cache removed - regeneration is fast enough (~2ms waveform, ~0.05ms MIDI)

function M.new(max_per_frame)
  local queue = {
    waveform_queue = {},
    midi_queue = {},
    -- Priority queues for visible items (processed first)
    waveform_queue_priority = {},
    midi_queue_priority = {},
    max_per_frame = max_per_frame or 3,
    processing_keys = {},
  }

  queue.add_waveform_job = function(item, cache_key, is_visible)
    return M.add_waveform_job(queue, item, cache_key, is_visible)
  end

  queue.add_midi_job = function(item, width, height, cache_key, is_visible)
    return M.add_midi_job(queue, item, width, height, cache_key, is_visible)
  end

  return queue
end

function M.add_waveform_job(job_queue, item, cache_key, is_visible)
  if job_queue.processing_keys[cache_key] then
    return
  end

  -- Check if already in either queue
  local target_queue = is_visible and job_queue.waveform_queue_priority or job_queue.waveform_queue
  local other_queue = is_visible and job_queue.waveform_queue or job_queue.waveform_queue_priority

  for i, job in ipairs(target_queue) do
    if job.cache_key == cache_key then
      return
    end
  end

  for i, job in ipairs(other_queue) do
    if job.cache_key == cache_key then
      return
    end
  end

  target_queue[#target_queue + 1] = {
    type = 'waveform',
    item = item,
    cache_key = cache_key,
  }
end

function M.add_midi_job(job_queue, item, width, height, cache_key, is_visible)
  if job_queue.processing_keys[cache_key] then
    return
  end

  -- Check if already in either queue
  local target_queue = is_visible and job_queue.midi_queue_priority or job_queue.midi_queue
  local other_queue = is_visible and job_queue.midi_queue or job_queue.midi_queue_priority

  for i, job in ipairs(target_queue) do
    if job.cache_key == cache_key then
      return
    end
  end

  for i, job in ipairs(other_queue) do
    if job.cache_key == cache_key then
      return
    end
  end

  target_queue[#target_queue + 1] = {
    type = 'midi',
    item = item,
    width = width,
    height = height,
    cache_key = cache_key,
  }
end

function M.process_jobs(job_queue, visualization, runtime_cache, imgui_ctx)
  -- Count both priority and normal queues
  local total_queued = #job_queue.waveform_queue + #job_queue.midi_queue +
                       #job_queue.waveform_queue_priority + #job_queue.midi_queue_priority
  if total_queued == 0 then
    return 0
  end

  local processed = 0
  local waveforms_this_frame = 0

  -- OPTIMIZATION: Process ALL pending MIDI first (they're ~0.05ms each, essentially free)
  -- This makes the UI feel much more responsive
  while #job_queue.midi_queue_priority > 0 do
    local job = table.remove(job_queue.midi_queue_priority, 1)
    job_queue.processing_keys[job.cache_key] = true
    if visualization.GenerateMidiThumbnail then
      local thumbnail = visualization.GenerateMidiThumbnail(runtime_cache, job.item, job.width, job.height, job.cache_key)
    end
    job_queue.processing_keys[job.cache_key] = nil
    processed = processed + 1
  end

  -- Then process background MIDI (also very fast)
  while #job_queue.midi_queue > 0 do
    local job = table.remove(job_queue.midi_queue, 1)
    job_queue.processing_keys[job.cache_key] = true
    if visualization.GenerateMidiThumbnail then
      local thumbnail = visualization.GenerateMidiThumbnail(runtime_cache, job.item, job.width, job.height, job.cache_key)
    end
    job_queue.processing_keys[job.cache_key] = nil
    processed = processed + 1
  end

  -- Now process waveforms (slower, ~2ms each) with frame budget
  while waveforms_this_frame < job_queue.max_per_frame do
    local job = nil

    -- Priority waveforms first (visible items)
    if #job_queue.waveform_queue_priority > 0 then
      job = table.remove(job_queue.waveform_queue_priority, 1)
    -- Then background waveforms
    elseif #job_queue.waveform_queue > 0 then
      job = table.remove(job_queue.waveform_queue, 1)
    else
      break
    end

    if job then
      job_queue.processing_keys[job.cache_key] = true

      if job.type == 'waveform' then
        -- Generate waveform directly (no disk cache - regeneration is fast enough)
        if visualization.GetItemWaveform then
          visualization.GetItemWaveform(runtime_cache, job.item, job.cache_key)
        end
      elseif job.type == 'midi' then
        -- Generate MIDI thumbnail directly
        if visualization.GenerateMidiThumbnail then
          visualization.GenerateMidiThumbnail(runtime_cache, job.item, job.width, job.height, job.cache_key)
        end
      end

      job_queue.processing_keys[job.cache_key] = nil
      waveforms_this_frame = waveforms_this_frame + 1
      processed = processed + 1
    end
  end

  return processed
end

function M.get_queue_stats(job_queue)
  local total = #job_queue.waveform_queue + #job_queue.midi_queue +
                #job_queue.waveform_queue_priority + #job_queue.midi_queue_priority

  return {
    waveforms_pending = #job_queue.waveform_queue + #job_queue.waveform_queue_priority,
    midi_pending = #job_queue.midi_queue + #job_queue.midi_queue_priority,
    waveforms_priority = #job_queue.waveform_queue_priority,
    midi_priority = #job_queue.midi_queue_priority,
    total_pending = total,
    processing = 0,
  }
end

function M.Clear(job_queue)
  job_queue.waveform_queue = {}
  job_queue.midi_queue = {}
  job_queue.waveform_queue_priority = {}
  job_queue.midi_queue_priority = {}
  job_queue.processing_keys = {}
end

function M.has_pending_jobs(job_queue)
  return #job_queue.waveform_queue > 0 or #job_queue.midi_queue > 0 or
         #job_queue.waveform_queue_priority > 0 or #job_queue.midi_queue_priority > 0
end

return M