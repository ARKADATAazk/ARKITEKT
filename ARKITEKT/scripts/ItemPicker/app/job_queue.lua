local M = {}

function M.new(max_per_frame)
  return {
    queue = {},
    max_per_frame = max_per_frame or 2,
    processing = false
  }
end

function M.add_bitmap_job(job_queue, item, width, height, color, cache_key)
  for i, job in ipairs(job_queue.queue) do
    if job.cache_key == cache_key then
      return
    end
  end
  
  table.insert(job_queue.queue, {
    type = "bitmap",
    item = item,
    width = width,
    height = height,
    color = color,
    cache_key = cache_key
  })
end

function M.process_jobs(job_queue, cache, visualization, imgui_ctx)
  if #job_queue.queue == 0 then return end
  
  local processed = 0
  while processed < job_queue.max_per_frame and #job_queue.queue > 0 do
    local job = table.remove(job_queue.queue, 1)
    
    if job.type == "bitmap" then
      visualization.CreateWaveformBitmap(
        cache,
        job.item,
        job.width,
        job.height,
        job.color
      )
    end
    
    processed = processed + 1
  end
end

function M.get_queue_length(job_queue)
  return #job_queue.queue
end

function M.clear(job_queue)
  job_queue.queue = {}
end

function M.has_job(job_queue, cache_key)
  for i, job in ipairs(job_queue.queue) do
    if job.cache_key == cache_key then
      return true
    end
  end
  return false
end

return M