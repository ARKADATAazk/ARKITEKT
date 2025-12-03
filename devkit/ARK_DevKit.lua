-- @description ARK DevKit - Launch ARKITEKT app from any worktree
-- @version 2.0.0
-- @author ARKADATA
-- @noindex
-- @about
--   # ARK DevKit
--
--   Development launcher for ARKITEKT apps across multiple git worktrees.
--
--   ## Features
--   - Auto-detects all ARKITEKT* and ARKITEKT-Dev* worktrees
--   - Lists all ARK_*.lua entrypoints with ImGui interface
--   - Persists state under REAPER/Data/ARKITEKT/DevKit/
--   - Single stable entry point for REAPER actions
--
--   ## Usage
--   1. Register this script as a REAPER action
--   2. Run it to select worktree and app via GUI
--   3. State is remembered between sessions

-- ============================================================================
-- LOAD ARKITEKT FRAMEWORK
-- ============================================================================
local Ark = dofile(debug.getinfo(1,'S').source:sub(2):match('(.-ARKITEKT%-Dev[/\\])') .. 'ARKITEKT' .. package.config:sub(1,1) .. 'arkitekt' .. package.config:sub(1,1) .. 'init.lua')

-- ============================================================================
-- LOAD MODULES
-- ============================================================================
local ImGui = Ark.ImGui
local Settings = require('arkitekt.core.settings')
local hexrgb = Ark.Colors.Hexrgb

local reaper = reaper
local sep = package.config:sub(1,1)

-- ============================================================================
-- HELPERS
-- ============================================================================

-- Generate a subtle background color based on first letter
-- Returns a nice hue-based color with low saturation
local function get_tile_color(name)
  local first_char = name:sub(1, 1):upper()
  local char_code = first_char:byte() or 65 -- Default to 'A' if invalid

  -- Map A-Z (65-90) to hue range 0-360
  -- Skip yellows/greens (60-150) which can be harsh
  local hue_map = {
    -- Red-Orange range (0-30)
    65, 66, 67, -- A,B,C
    -- Orange-Red (30-60)
    68, 69, 70, -- D,E,F
    -- Blue-Cyan range (180-240)
    71, 72, 73, 74, 75, -- G,H,I,J,K
    -- Blue-Purple (240-270)
    76, 77, 78, 79, -- L,M,N,O
    -- Purple-Magenta (270-330)
    80, 81, 82, 83, 84, -- P,Q,R,S,T
    -- Magenta-Red (330-360)
    85, 86, 87, 88, 89, 90 -- U,V,W,X,Y,Z
  }

  local hue_idx = char_code - 64 -- A=1, B=2, etc
  if hue_idx < 1 or hue_idx > 26 then hue_idx = 1 end

  -- Distribute across spectrum, avoiding harsh yellows
  local hue = ((hue_idx - 1) * 360 / 26) % 360
  if hue >= 60 and hue < 150 then
    -- Shift yellows/greens to blues
    hue = hue + 90
  end

  -- Moderate saturation, low-medium value for visible but not flashy
  local s = 0.45  -- 45% saturation (visible)
  local v = 0.22  -- 22% brightness (noticeable)

  -- HSV to RGB
  local c = v * s
  local x = c * (1 - math.abs((hue / 60) % 2 - 1))
  local m = v - c

  local r, g, b
  if hue < 60 then
    r, g, b = c, x, 0
  elseif hue < 120 then
    r, g, b = x, c, 0
  elseif hue < 180 then
    r, g, b = 0, c, x
  elseif hue < 240 then
    r, g, b = 0, x, c
  elseif hue < 300 then
    r, g, b = x, 0, c
  else
    r, g, b = c, 0, x
  end

  r = (r + m) * 255
  g = (g + m) * 255
  b = (b + m) * 255

  return ImGui.ColorConvertDouble4ToU32(r/255, g/255, b/255, 1.0)
end

local function normalize(path)
  return (path:gsub(sep..'+$', ''))
end

local function dirname(path)
  path = normalize(path)
  local dir = path:match('^(.*'..sep..')')
  if not dir then return nil end
  return normalize(dir)
end

local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

-- Launch a script as a separate REAPER process (not compartmentalized)
-- opts: { debug = bool, profiler = bool } - optional launch options
local function launch_script(script_path, opts)
  opts = opts or {}

  if not file_exists(script_path) then
    reaper.MB('Script not found: ' .. script_path, 'DevKit Error', 0)
    return false
  end

  -- Pass launch options via ExtState (read by arkitekt bootstrap)
  -- Using non-persistent ExtState so it's only valid for this launch
  -- debug = enable metrics/debug mode
  -- profiler = enable Lua profiler (only relevant if debug is also true)
  reaper.SetExtState('ARKITEKT_LAUNCH', 'debug', opts.debug and '1' or '0', false)
  reaper.SetExtState('ARKITEKT_LAUNCH', 'profiler', opts.profiler and '1' or '0', false)
  reaper.SetExtState('ARKITEKT_LAUNCH', 'script_path', script_path, false)

  -- Register the script as an action temporarily (don't commit to reaper-kb.ini)
  local section_id = 0  -- Main section
  local cmd_id = reaper.AddRemoveReaScript(true, section_id, script_path, false)

  if not cmd_id or cmd_id == 0 then
    reaper.MB('Failed to register script: ' .. script_path, 'DevKit Error', 0)
    return false
  end

  -- Execute the action - wrap in pcall to prevent crashes from killing DevKit
  local ok, err = pcall(function()
    reaper.Main_OnCommand(cmd_id, 0)
  end)

  -- Unregister the action (clean up)
  reaper.AddRemoveReaScript(false, section_id, script_path, false)

  if not ok then
    reaper.MB('Script crashed on launch:\n\n' .. tostring(err), 'DevKit Error', 0)
    return false
  end

  return true
end

-- ============================================================================
-- DEVKIT STATE & SETTINGS
-- ============================================================================

local data_dir = Ark._bootstrap.get_data_dir('DevKit')
local settings = Settings.new(data_dir, 'DevKit_State.json')

-- ============================================================================
-- AUTO-DETECT BASE_DIR & WORKTREES
-- ============================================================================

local function detect_default_base_dir()
  -- We assume this DevKit script lives in:
  --   <base_dir>/ARKITEKT-Dev/devkit/ARK_DevKit.lua
  local src = debug.getinfo(1, 'S').source:sub(2)
  local devkit_dir = dirname(src)             -- .../ARKITEKT-Dev/devkit
  if not devkit_dir then return nil end
  local repo_root = dirname(devkit_dir)       -- .../ARKITEKT-Dev
  if not repo_root then return nil end
  local base_dir = dirname(repo_root)         -- .../ (parent of all worktrees)
  return base_dir
end

local function find_worktrees(base_dir)
  base_dir = normalize(base_dir)
  local worktrees = {}

  local i = 0
  while true do
    local name = reaper.EnumerateSubdirectories(base_dir, i)
    if not name then break end
    if name == 'ARKITEKT' or name == 'ARKITEKT-Dev' or name:match('^ARKITEKT%-Dev%-') then
      local path = normalize(base_dir .. sep .. name)
      local key
      if name == 'ARKITEKT' then
        key = 'stable'
      elseif name == 'ARKITEKT-Dev' then
        key = 'main'
      else
        -- e.g. ARKITEKT-Dev-tiles -> tiles
        key = name:sub(#'ARKITEKT-Dev-' + 1)
      end
      table.insert(worktrees, {
        key  = key,
        name = name,
        path = path
      })
    end
    i = i + 1
  end

  return worktrees
end

local function find_entrypoints(worktree_path)
  local apps = {}

  -- Determine search root: ARKITEKT-Dev* looks in /ARKITEKT, ARKITEKT looks in /
  local search_root
  local worktree_name = worktree_path:match('([^'..sep..']+)$')
  if worktree_name == 'ARKITEKT' then
    search_root = worktree_path
  else
    -- ARKITEKT-Dev or ARKITEKT-Dev-*
    search_root = normalize(worktree_path .. sep .. 'ARKITEKT')
  end

  -- 1) Check for ARK_*.lua directly in search_root
  local i = 0
  while true do
    local fname = reaper.EnumerateFiles(search_root, i)
    if not fname then break end
    if fname:match('^ARK_.*%.lua$') then
      local full = normalize(search_root .. sep .. fname)
      local app_key = fname:match('^ARK_(.*)%.lua$')
      table.insert(apps, {
        key       = app_key,
        name      = app_key,
        full_path = full
      })
    end
    i = i + 1
  end

  -- 2) Check for ARK_*.lua in scripts/[AppName]/ subdirectories
  local scripts_dir = normalize(search_root .. sep .. 'scripts')
  local j = 0
  while true do
    local app_dir_name = reaper.EnumerateSubdirectories(scripts_dir, j)
    if not app_dir_name then break end
    local app_dir = normalize(scripts_dir .. sep .. app_dir_name)

    -- Look for ARK_*.lua inside this app dir
    local k = 0
    while true do
      local fname = reaper.EnumerateFiles(app_dir, k)
      if not fname then break end
      if fname:match('^ARK_.*%.lua$') then
        local full = normalize(app_dir .. sep .. fname)
        table.insert(apps, {
          key       = app_dir_name,
          name      = app_dir_name,
          full_path = full
        })
      end
      k = k + 1
    end

    j = j + 1
  end

  return apps
end

-- ============================================================================
-- STATE
-- ============================================================================

local State = {
  base_dir = nil,
  worktrees = {},
  -- Organized apps: app_name -> { name, instances = { {worktree_idx, full_path}, ... }, selected_wt_idx }
  apps_by_name = {},
  search_query = '',
  active_tab = 'Apps',  -- 'Apps' or 'Sandbox'
  sandbox_scripts = {},
  profiler_enabled = false,  -- Add profiler to Debug launches
}

function State:initialize()
  -- Load base_dir from settings or detect
  self.base_dir = settings:get('base_dir') or detect_default_base_dir()

  if not self.base_dir or self.base_dir == '' then
    self.base_dir = reaper.GetResourcePath() .. sep .. 'Scripts'
  end

  self.base_dir = normalize(self.base_dir)

  -- Find worktrees
  self:refresh_worktrees()

  -- Build apps_by_name
  self:refresh_apps()

  -- Refresh sandbox scripts
  self:refresh_sandbox()

  -- Restore last selections
  local saved_selections = settings:get('app_worktree_selections') or {}
  for app_name, wt_idx in pairs(saved_selections) do
    if self.apps_by_name[app_name] then
      self.apps_by_name[app_name].selected_wt_idx = wt_idx
    end
  end

  -- Restore active tab
  self.active_tab = settings:get('active_tab') or 'Apps'

  -- Restore profiler setting
  self.profiler_enabled = settings:get('profiler_enabled') or false
end

function State:set_profiler_enabled(enabled)
  self.profiler_enabled = enabled
  settings:set('profiler_enabled', enabled)
end

function State:refresh_worktrees()
  self.worktrees = find_worktrees(self.base_dir)
end

function State:refresh_apps()
  self.apps_by_name = {}

  -- Scan all worktrees and organize apps by name
  for wt_idx, wt in ipairs(self.worktrees) do
    local apps = find_entrypoints(wt.path)

    for _, app in ipairs(apps) do
      if not self.apps_by_name[app.name] then
        self.apps_by_name[app.name] = {
          name = app.name,
          instances = {},
          selected_wt_idx = nil,
        }
      end

      table.insert(self.apps_by_name[app.name].instances, {
        worktree_idx = wt_idx,
        full_path = app.full_path,
      })

      -- Default to first instance if not set
      if not self.apps_by_name[app.name].selected_wt_idx then
        self.apps_by_name[app.name].selected_wt_idx = wt_idx
      end
    end
  end
end

function State:select_worktree_for_app(app_name, wt_idx)
  if self.apps_by_name[app_name] then
    self.apps_by_name[app_name].selected_wt_idx = wt_idx

    -- Save selection
    local saved_selections = settings:get('app_worktree_selections') or {}
    saved_selections[app_name] = wt_idx
    settings:set('app_worktree_selections', saved_selections)
  end
end

function State:launch_app(app_name, opts)
  opts = opts or {}
  -- debug = metrics enabled
  -- profiler = profiler enabled (only when debug is also true)
  local debug = opts.debug or false
  local profiler = debug and (opts.profiler or self.profiler_enabled) or false

  local app_data = self.apps_by_name[app_name]
  if not app_data or not app_data.selected_wt_idx then
    reaper.MB('No worktree selected for ' .. app_name, 'DevKit Error', 0)
    return false
  end

  -- Find the instance for the selected worktree
  local instance = nil
  for _, inst in ipairs(app_data.instances) do
    if inst.worktree_idx == app_data.selected_wt_idx then
      instance = inst
      break
    end
  end

  if not instance or not file_exists(instance.full_path) then
    reaper.MB('Entrypoint not found for ' .. app_name, 'DevKit Error', 0)
    return false
  end

  -- Launch the app as separate process
  launch_script(instance.full_path, { debug = debug, profiler = profiler })
  return true
end

function State:refresh_sandbox()
  self.sandbox_scripts = {}

  -- Look in scripts/Sandbox/ directory (always at worktree root)
  for _, wt in ipairs(self.worktrees) do
    local sandbox_dir = normalize(wt.path .. sep .. 'scripts' .. sep .. 'Sandbox')

    local i = 0
    while true do
      local fname = reaper.EnumerateFiles(sandbox_dir, i)
      if not fname then break end
      if fname:match('%.lua$') then
        table.insert(self.sandbox_scripts, {
          name = fname:gsub('%.lua$', ''),
          full_path = normalize(sandbox_dir .. sep .. fname),
          worktree = wt.key,
        })
      end
      i = i + 1
    end
  end

  -- Sort alphabetically
  table.sort(self.sandbox_scripts, function(a, b) return a.name < b.name end)
end

function State:set_active_tab(tab_name)
  self.active_tab = tab_name
  settings:set('active_tab', tab_name)
  -- Settings auto-flushes on 0.5s debounce timer
end

function State:get_filtered_apps()
  local apps = {}

  for app_name, app_data in pairs(self.apps_by_name) do
    if self.search_query == '' or app_name:lower():find(self.search_query:lower(), 1, true) then
      table.insert(apps, app_data)
    end
  end

  -- Sort alphabetically
  table.sort(apps, function(a, b) return a.name < b.name end)

  return apps
end

-- ============================================================================
-- UI - TILE RENDERING
-- ============================================================================

local TILE_HEIGHT = 36
local TILE_PADDING = 8

local function render_app_tile(ctx, app_data, tile_width, shell_state)
  local x1, y1 = ImGui.GetCursorScreenPos(ctx)
  local x2, y2 = x1 + tile_width, y1 + TILE_HEIGHT
  local dl = ImGui.GetWindowDrawList(ctx)

  -- Tile background
  local bg_color = get_tile_color(app_data.name)
  local border_color = hexrgb('#2A2A2A')

  ImGui.DrawList_AddRectFilled(dl, x1, y1, x2, y2, bg_color, 2)
  ImGui.DrawList_AddRect(dl, x1, y1, x2, y2, border_color, 2, 0, 0.5)

  -- LEFT: App name
  ImGui.SetCursorScreenPos(ctx, x1 + TILE_PADDING, y1 + (TILE_HEIGHT - 14) / 2)
  ImGui.PushFont(ctx, shell_state.fonts.bold, 12)

  local max_name_width = 150
  local name_display = app_data.name
  if #name_display > 22 then
    name_display = name_display:sub(1, 19) .. '...'
  end
  ImGui.Text(ctx, name_display)
  ImGui.PopFont(ctx)

  if ImGui.IsItemHovered(ctx) then
    ImGui.SetTooltip(ctx, app_data.name)
  end

  -- RIGHT: One button per worktree
  local button_start_x = x1 + TILE_PADDING + max_name_width + 12
  ImGui.SetCursorScreenPos(ctx, button_start_x, y1 + (TILE_HEIGHT - 28) / 2)

  -- Find available worktrees for this app
  local available_worktrees = {}
  for _, inst in ipairs(app_data.instances) do
    for wt_idx, wt in ipairs(State.worktrees) do
      if wt_idx == inst.worktree_idx then
        table.insert(available_worktrees, { wt_idx = wt_idx, wt = wt, path = inst.full_path })
        break
      end
    end
  end

  -- Render one button per worktree
  for i, wt_info in ipairs(available_worktrees) do
    local tooltip = string.format('%s\n\nWorktree: %s\nPath: %s\n\nLeft Click: Launch\nRight Click: Debug',
      app_data.name, wt_info.wt.key, wt_info.path)

    -- Measure text width and add padding (button has internal padding of ~12px per side)
    local text_w, text_h = ImGui.CalcTextSize(ctx, wt_info.wt.key)
    local button_width = text_w + 24  -- Add padding for button chrome

    local result = Ark.Button(ctx, {
      id = app_data.name .. '_' .. wt_info.wt.key,
      label = wt_info.wt.key,
      width = button_width,
      height = 28,
      tooltip = tooltip,
      on_click = function()
        State:select_worktree_for_app(app_data.name, wt_info.wt_idx)
        State:launch_app(app_data.name, { debug = false })
      end,
    })

    -- Right click for debug launch
    if ImGui.IsItemClicked(ctx, ImGui.MouseButton_Right) then
      State:select_worktree_for_app(app_data.name, wt_info.wt_idx)
      State:launch_app(app_data.name, { debug = true })
    end

    if i < #available_worktrees then
      ImGui.SameLine(ctx, 0, 4)
    end
  end

  -- Move cursor below tile
  ImGui.SetCursorScreenPos(ctx, x1, y2 + 3)
  ImGui.Dummy(ctx, 0, 0)
end

-- ============================================================================
-- UI - MAIN VIEW
-- ============================================================================

local apps_panel = Ark.Panel.new({
  id = 'apps_panel',
  width = nil,
  height = nil,
  config = {
    header = {
      enabled = true,
      height = 36,
      position = 'top',
      elements = {
        {
          id = 'search',
          type = 'inputtext',
          align = 'left',
          width = 250,
          spacing_before = 0,
          config = {
            placeholder = 'Search apps...',
            get_value = function() return State.search_query end,
            on_change = function(text)
              State.search_query = text
            end,
          }
        },
        {
          id = 'refresh',
          type = 'button',
          align = 'right',
          spacing_before = 8,
          config = {
            label = 'Refresh',
            on_click = function()
              State:refresh_worktrees()
              State:refresh_apps()
              State:refresh_sandbox()
            end,
          }
        },
        {
          id = 'config',
          type = 'button',
          align = 'right',
          spacing_before = 6,
          config = {
            label = 'Config',
            on_click = function()
              local ok, input = reaper.GetUserInputs('DevKit - Base Directory', 1, 'Base dir:', State.base_dir or '')
              if ok and input ~= '' then
                State.base_dir = normalize(input)
                settings:set('base_dir', State.base_dir)
                State:refresh_worktrees()
                State:refresh_apps()
              end
            end,
          }
        },
      },
    },
  },
})

local function draw_sandbox(ctx, shell_state)
  ImGui.Text(ctx, string.format('Found %d sandbox scripts:', #State.sandbox_scripts))
  ImGui.Separator(ctx)
  ImGui.Dummy(ctx, 0, 8)

  if #State.sandbox_scripts == 0 then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#888888'))
    ImGui.TextWrapped(ctx, 'No sandbox scripts found in scripts/Sandbox/')
    ImGui.PopStyleColor(ctx)
    return
  end

  -- List all sandbox scripts with launch buttons
  for i, script in ipairs(State.sandbox_scripts) do
    ImGui.PushID(ctx, i)

    -- Script name
    ImGui.AlignTextToFramePadding(ctx)
    ImGui.Text(ctx, script.name)
    ImGui.SameLine(ctx)

    -- Worktree badge
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#888888'))
    ImGui.Text(ctx, string.format('[%s]', script.worktree))
    ImGui.PopStyleColor(ctx)
    ImGui.SameLine(ctx, 0, 16)

    -- Launch button (normal, no debug)
    Ark.Button(ctx, {
      label = 'Run',
      width = 60,
      height = 24,
      preset = 'primary',
      tooltip = script.full_path,
      on_click = function()
        launch_script(script.full_path, {})
      end
    })

    ImGui.PopID(ctx)
  end
end

local Checkbox = require('arkitekt.gui.widgets.primitives.checkbox')

local function draw_main(ctx, shell_state)
  -- Tab buttons (simple approach instead of TabBar)
  local tabs = {'Apps', 'Sandbox'}
  for i, tab in ipairs(tabs) do
    local is_active = (State.active_tab == tab)

    Ark.Button(ctx, {
      id = 'tab_' .. tab,
      label = tab,
      width = 100,
      height = 28,
      preset = is_active and 'primary' or nil,
      on_click = function()
        State:set_active_tab(tab)
      end
    })

    if i < #tabs then
      ImGui.SameLine(ctx, 0, 4)
    end
  end

  -- Profiler checkbox (right side of tab row) - only affects Debug button
  ImGui.SameLine(ctx, 0, 20)
  local result = Checkbox.Draw(ctx, {
    id = 'profiler_checkbox',
    label = 'Profiler',
    checked = State.profiler_enabled,
    tooltip = 'Also enable Lua profiler when using Debug button',
    on_change = function(value)
      State:set_profiler_enabled(value)
    end,
  })

  ImGui.Dummy(ctx, 0, 8)

  -- Check for no worktrees outside panel
  if #State.worktrees == 0 then
    ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#FF6666'))
    ImGui.TextWrapped(ctx, 'No worktrees found. Click Config to set the base directory.')
    ImGui.PopStyleColor(ctx)

    ImGui.Dummy(ctx, 0, 12)

    if Ark.Button(ctx, {
      id = 'config_btn_main',
      label = 'Config',
      width = 100,
      height = 28,
      on_click = function()
        local ok, input = reaper.GetUserInputs('DevKit - Base Directory', 1, 'Base dir:', State.base_dir or '')
        if ok and input ~= '' then
          State.base_dir = normalize(input)
          settings:set('base_dir', State.base_dir)
          State:refresh_worktrees()
          State:refresh_apps()
          State:refresh_sandbox()
        end
      end
    }).clicked then
    end

    return
  end

  -- Render active tab content
  if State.active_tab == 'Sandbox' then
    draw_sandbox(ctx, shell_state)
    return
  end

  -- Panel with header toolbar
  if apps_panel:begin_draw(ctx) then
    local panel_w = ImGui.GetContentRegionAvail(ctx)

    -- APPS GRID
    local filtered_apps = State:get_filtered_apps()

    if #filtered_apps == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, hexrgb('#888888'))
      if State.search_query ~= '' then
        ImGui.TextWrapped(ctx, 'No apps match your search.')
      else
        ImGui.TextWrapped(ctx, 'No apps found.')
      end
      ImGui.PopStyleColor(ctx)
    else
      -- Single column layout
      local tile_width = panel_w

      for i, app_data in ipairs(filtered_apps) do
        render_app_tile(ctx, app_data, tile_width, shell_state)
        if i < #filtered_apps then
          ImGui.Dummy(ctx, 0, 4)
        end
      end
    end
  end
  apps_panel:end_draw(ctx)
end

local function get_status()
  local wt_count = #State.worktrees
  local app_count = 0
  for _ in pairs(State.apps_by_name) do
    app_count = app_count + 1
  end

  if wt_count == 0 then
    return {
      color = hexrgb('#FF6666'),
      text = 'NO WORKTREES',
    }
  end

  return {
    color = hexrgb('#41E0A3'),
    text = string.format('%d WORKTREE(S) • %d APP(S)', wt_count, app_count),
  }
end

-- ============================================================================
-- INITIALIZE & RUN
-- ============================================================================

State:initialize()

Ark.Shell.run({
  title = 'ARKITEKT DevKit',
  version = 'v2.0.0',
  draw = draw_main,
  settings = settings,
  initial_pos = { x = 200, y = 200 },
  initial_size = { w = 900, h = 600 },
  min_size = { w = 750, h = 400 },
  icon_color = hexrgb('#FF6600'),
  icon_size = 18,
  content_padding = 12,
  get_status_func = get_status,
})
