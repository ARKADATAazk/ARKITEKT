local M = {}

function M.new(max_per_frame)
  local queue = {
    waveform_queue = {},
    midi_queue = {},
    max_per_frame = max_per_frame or 3,
    processing_keys = {},
  }
  
  queue.add_waveform_job = function(cache, item, cache_key)
    return M.add_waveform_job(queue, cache, item, cache_key)
  end
  
  queue.add_midi_job = function(cache, item, width, height, cache_key)
    return M.add_midi_job(queue, cache, item, width, height, cache_key)
  end
  
  return queue
end

function M.add_waveform_job(job_queue, cache, item, cache_key)
  if job_queue.processing_keys[cache_key] then
    return
  end
  
  for i, job in ipairs(job_queue.waveform_queue) do
    if job.cache_key == cache_key then
      return
    end
  end
  
  table.insert(job_queue.waveform_queue, {
    type = "waveform",
    cache = cache,
    item = item,
    cache_key = cache_key,
  })
end

function M.add_midi_job(job_queue, cache, item, width, height, cache_key)
  if job_queue.processing_keys[cache_key] then
    return
  end
  
  for i, job in ipairs(job_queue.midi_queue) do
    if job.cache_key == cache_key then
      return
    end
  end
  
  table.insert(job_queue.midi_queue, {
    type = "midi",
    cache = cache,
    item = item,
    width = width,
    height = height,
    cache_key = cache_key,
  })
end

function M.process_jobs(job_queue, visualization, cache_mgr, imgui_ctx)
  local total_queued = #job_queue.waveform_queue + #job_queue.midi_queue
  if total_queued == 0 then 
    return 0
  end
  
  local processed = 0
  
  while processed < job_queue.max_per_frame do
    local job = nil
    
    if #job_queue.waveform_queue > 0 then
      job = table.remove(job_queue.waveform_queue, 1)
    elseif #job_queue.midi_queue > 0 then
      job = table.remove(job_queue.midi_queue, 1)
    else
      break
    end
    
    if job then
      job_queue.processing_keys[job.cache_key] = true
      
      if job.type == "waveform" then
        if visualization.GetItemWaveform then
          visualization.GetItemWaveform(job.cache, job.item)
        end
      elseif job.type == "midi" then
        if visualization.GenerateMidiThumbnail then
          visualization.GenerateMidiThumbnail(job.cache, job.item, job.width, job.height)
        end
      end
      
      job_queue.processing_keys[job.cache_key] = nil
      processed = processed + 1
    end
  end
  
  return processed
end

function M.get_queue_stats(job_queue)
  return {
    waveforms_pending = #job_queue.waveform_queue,
    midi_pending = #job_queue.midi_queue,
    total_pending = #job_queue.waveform_queue + #job_queue.midi_queue,
    processing = 0,
  }
end

function M.clear(job_queue)
  job_queue.waveform_queue = {}
  job_queue.midi_queue = {}
  job_queue.processing_keys = {}
end

function M.has_pending_jobs(job_queue)
  return #job_queue.waveform_queue > 0 or #job_queue.midi_queue > 0
end

return M