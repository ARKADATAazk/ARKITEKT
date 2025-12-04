-- @noindex
-- TemplateBrowser/domain/template/stats.lua
-- Usage statistics calculations for templates

local M = {}

-- Time constants (in seconds)
local DAY = 86400
local WEEK = 7 * DAY
local MONTH = 30 * DAY

-- Calculate usage stats from history array
-- history: array of unix timestamps when template was used
function M.calculate_stats(history)
  if not history or #history == 0 then
    return {
      total = 0,
      last_7_days = 0,
      last_30_days = 0,
      trend = 'none',  -- 'up', 'down', 'stable', 'none'
      avg_per_week = 0,
      streak_days = 0,
    }
  end

  local now = os.time()
  local week_ago = now - WEEK
  local month_ago = now - MONTH
  local two_weeks_ago = now - (2 * WEEK)

  local total = #history
  local last_7_days = 0
  local last_30_days = 0
  local prev_week = 0  -- 8-14 days ago for trend calculation

  -- Count usages in time periods
  for _, timestamp in ipairs(history) do
    if timestamp >= week_ago then
      last_7_days = last_7_days + 1
    end
    if timestamp >= month_ago then
      last_30_days = last_30_days + 1
    end
    if timestamp >= two_weeks_ago and timestamp < week_ago then
      prev_week = prev_week + 1
    end
  end

  -- Calculate trend (compare last 7 days vs previous 7 days)
  local trend = 'stable'
  if last_7_days > prev_week * 1.5 then
    trend = 'up'
  elseif last_7_days < prev_week * 0.5 and prev_week > 0 then
    trend = 'down'
  elseif last_7_days == 0 and prev_week == 0 then
    trend = 'none'
  end

  -- Calculate average per week (based on history span)
  local avg_per_week = 0
  if total > 0 then
    local oldest = history[1]
    local newest = history[#history]
    local span_days = math.max(1, (newest - oldest) / DAY)
    local span_weeks = math.max(1, span_days / 7)
    avg_per_week = total / span_weeks
  end

  -- Calculate usage streak (consecutive days with usage)
  local streak_days = M.calculate_streak(history)

  return {
    total = total,
    last_7_days = last_7_days,
    last_30_days = last_30_days,
    trend = trend,
    avg_per_week = avg_per_week,
    streak_days = streak_days,
  }
end

-- Calculate consecutive day streak ending today or yesterday
function M.calculate_streak(history)
  if not history or #history == 0 then return 0 end

  -- Get unique days (as day numbers since epoch)
  local days = {}
  for _, timestamp in ipairs(history) do
    local day_num = math.floor(timestamp / DAY)
    days[day_num] = true
  end

  -- Convert to sorted array
  local day_list = {}
  for day_num, _ in pairs(days) do
    day_list[#day_list + 1] = day_num
  end
  table.sort(day_list)

  if #day_list == 0 then return 0 end

  -- Check streak from most recent day
  local today = math.floor(os.time() / DAY)
  local most_recent = day_list[#day_list]

  -- Streak only counts if used today or yesterday
  if most_recent < today - 1 then return 0 end

  -- Count consecutive days backwards
  local streak = 1
  for i = #day_list - 1, 1, -1 do
    if day_list[i] == day_list[i + 1] - 1 then
      streak = streak + 1
    else
      break
    end
  end

  return streak
end

-- Generate sparkline data (usage per day for last N days)
-- Returns array of counts, one per day, most recent last
function M.get_daily_sparkline(history, num_days)
  num_days = num_days or 14

  local now = os.time()
  local today = math.floor(now / DAY)
  local counts = {}

  -- Initialize counts for each day
  for i = 1, num_days do
    counts[i] = 0
  end

  if not history then return counts end

  -- Count usages per day
  for _, timestamp in ipairs(history) do
    local day_num = math.floor(timestamp / DAY)
    local days_ago = today - day_num

    if days_ago >= 0 and days_ago < num_days then
      local idx = num_days - days_ago
      counts[idx] = counts[idx] + 1
    end
  end

  return counts
end

-- Format trend as icon/text
function M.format_trend(trend)
  if trend == 'up' then
    return '↑'
  elseif trend == 'down' then
    return '↓'
  elseif trend == 'stable' then
    return '→'
  else
    return ''
  end
end

-- Format stats as short summary text
function M.format_summary(stats)
  if not stats or stats.total == 0 then
    return 'Never used'
  end

  local parts = {}

  -- Total usage
  parts[#parts + 1] = string.format('%d total', stats.total)

  -- Recent activity
  if stats.last_7_days > 0 then
    parts[#parts + 1] = string.format('%d this week', stats.last_7_days)
  end

  -- Trend indicator
  if stats.trend ~= 'none' then
    parts[#parts + 1] = M.format_trend(stats.trend)
  end

  return table.concat(parts, ' · ')
end

return M
