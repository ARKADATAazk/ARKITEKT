-- @noindex
-- Blocks/ui/init.lua
-- Main UI orchestrator with tabbed interface

local M = {}

-- DEPENDENCIES
local Ark = require('arkitekt')
local MacroControls = require('scripts.Blocks.ui.views.macro_controls')
local Loader = require('scripts.Blocks.app.loader')
local ImGui = Ark.ImGui
local Colors = Ark.Colors
local Theme = require('arkitekt.theme')

-- Component-based blocks (lazy loaded)
local DrumRackComponent = nil
local ItemBrowserComponent = nil

-- STATE
local state = {
  current_tab = 1, -- 1 = Macros, 2 = Drum Rack, 3 = Browser (future)
  initialized = false,

  -- Component mode testing
  available_blocks = {},    -- Discovered block components
  loaded_components = {},   -- Currently loaded component instances
}

---Initialize UI
function M.init()
  if state.initialized then return end

  MacroControls.init()

  -- Load component-based blocks
  _G.ARKITEKT_BLOCKS_HOST = true  -- Tell Shell.run to return component handle

  local drum_rack, err1 = Loader.load_by_name('drum_rack')
  if drum_rack then
    DrumRackComponent = drum_rack
    reaper.ShowConsoleMsg('[Blocks] Loaded drum_rack component\n')
  else
    reaper.ShowConsoleMsg('[Blocks] Failed to load drum_rack: ' .. (err1 or 'unknown') .. '\n')
  end

  local item_browser, err2 = Loader.load_by_name('item_browser')
  if item_browser then
    ItemBrowserComponent = item_browser
    reaper.ShowConsoleMsg('[Blocks] Loaded item_browser component\n')
  else
    reaper.ShowConsoleMsg('[Blocks] Failed to load item_browser: ' .. (err2 or 'unknown') .. '\n')
  end

  -- Discover available block components (for component test tab)
  state.available_blocks = Loader.discover()

  state.initialized = true
end

---Draw component test view
---@param ctx userdata ImGui context
local function draw_component_test(ctx)
  -- Refresh button
  if ImGui.Button(ctx, 'Refresh Blocks', 120, 24) then
    state.available_blocks = Loader.discover()
  end

  ImGui.SameLine(ctx)
  ImGui.Text(ctx, 'Found: ' .. #state.available_blocks .. ' blocks')

  ImGui.Spacing(ctx)
  ImGui.Separator(ctx)
  ImGui.Spacing(ctx)

  -- Two-column layout: Available blocks | Loaded components
  local avail_width = ImGui.GetContentRegionAvail(ctx)

  -- Left panel: Available blocks
  if ImGui.BeginChild(ctx, 'available_blocks', 200, 0, ImGui.ChildFlags_Borders) then
    ImGui.Text(ctx, 'Available Blocks')
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    for i, block in ipairs(state.available_blocks) do
      ImGui.PushID(ctx, i)

      -- Check if this block is already loaded
      local is_loaded = false
      for _, loaded in ipairs(state.loaded_components) do
        if loaded.name == block.name then
          is_loaded = true
          break
        end
      end

      -- Disable button if already loaded
      if is_loaded then
        ImGui.BeginDisabled(ctx)
      end

      if ImGui.Button(ctx, '+ ' .. block.name, -1, 28) then
        -- Load the block as a component
        local component, err = Loader.load(block)
        if component then
          table.insert(state.loaded_components, {
            id = #state.loaded_components + 1,
            name = block.name,
            component = component,
          })
        else
          reaper.ShowConsoleMsg('Failed to load block: ' .. (err or 'unknown error') .. '\n')
        end
      end

      if is_loaded then
        ImGui.EndDisabled(ctx)
      end

      ImGui.PopID(ctx)
    end

    if #state.available_blocks == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
      ImGui.TextWrapped(ctx, 'No blocks found in blocks/ folder')
      ImGui.PopStyleColor(ctx)
    end

    ImGui.EndChild(ctx)
  end

  ImGui.SameLine(ctx)

  -- Right panel: Loaded components
  if ImGui.BeginChild(ctx, 'loaded_components', 0, 0, ImGui.ChildFlags_Borders) then
    ImGui.Text(ctx, 'Loaded Components (' .. #state.loaded_components .. ')')
    ImGui.Separator(ctx)
    ImGui.Spacing(ctx)

    if #state.loaded_components == 0 then
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
      ImGui.TextWrapped(ctx, 'Click a block in the left panel to load it')
      ImGui.PopStyleColor(ctx)
    else
      -- Draw each loaded component in its own child window
      for i, item in ipairs(state.loaded_components) do
        ImGui.PushID(ctx, 'component_' .. i)

        -- Component header with close button
        local header_text = item.name .. ' (#' .. i .. ')'
        local header_expanded = ImGui.CollapsingHeader(ctx, header_text, true, ImGui.TreeNodeFlags_DefaultOpen)

        -- Close button (on same line as header)
        ImGui.SameLine(ctx, ImGui.GetContentRegionAvail(ctx) - 20)
        if ImGui.SmallButton(ctx, 'X') then
          -- Call on_close if component has it
          if item.component.on_close then
            item.component.on_close()
          end
          table.remove(state.loaded_components, i)
          ImGui.PopID(ctx)
          break -- Exit loop since we modified the table
        end

        if header_expanded then
          -- Component content area
          if ImGui.BeginChild(ctx, 'content', 0, 200, ImGui.ChildFlags_Borders) then
            -- Draw the component (dot syntax - component.draw is a plain function, not a method)
            item.component.draw(ctx)
            ImGui.EndChild(ctx)
          end
        end

        ImGui.Spacing(ctx)
        ImGui.PopID(ctx)
      end
    end

    ImGui.EndChild(ctx)
  end
end

---Draw tabbed interface
---@param ctx userdata ImGui context
---@param shell_state table Shell state
function M.Draw(ctx, shell_state)
  if not state.initialized then
    M.init()
  end

  -- Tab bar
  local tab_flags = ImGui.TabBarFlags_None

  if ImGui.BeginTabBar(ctx, 'blocks_tabs', tab_flags) then

    -- Macro Controls Tab
    if ImGui.BeginTabItem(ctx, '🎛️ Macro Controls') then
      state.current_tab = 1
      ImGui.Spacing(ctx)
      MacroControls.Draw(ctx)
      ImGui.EndTabItem(ctx)
    end

    -- Drum Rack Tab (component-based)
    if ImGui.BeginTabItem(ctx, '🥁 Drum Rack') then
      state.current_tab = 2
      ImGui.Spacing(ctx)
      if DrumRackComponent then
        DrumRackComponent.draw(ctx)
      else
        ImGui.TextColored(ctx, 0xFF8888FF, 'DrumRack component failed to load')
      end
      ImGui.EndTabItem(ctx)
    end

    -- Sample Browser Tab (component-based with ItemPicker)
    if ImGui.BeginTabItem(ctx, '📁 Browser') then
      state.current_tab = 3
      ImGui.Spacing(ctx)
      if ItemBrowserComponent then
        ItemBrowserComponent.draw(ctx)
      else
        ImGui.TextColored(ctx, 0xFF8888FF, 'ItemBrowser component failed to load')
        ImGui.Spacing(ctx)
        ImGui.TextWrapped(ctx, 'Ensure ItemPicker is installed alongside Blocks.')
      end
      ImGui.EndTabItem(ctx)
    end

    -- Settings Tab (placeholder)
    if ImGui.BeginTabItem(ctx, '⚙️ Settings') then
      state.current_tab = 4
      ImGui.Spacing(ctx)

      ImGui.Text(ctx, 'Blocks Settings')
      ImGui.Spacing(ctx)
      ImGui.Separator(ctx)
      ImGui.Spacing(ctx)

      ImGui.PushStyleColor(ctx, ImGui.Col_Text, Theme.COLORS.TEXT_DARK)
      ImGui.TextWrapped(ctx, '📝 Mockup: Settings for MIDI routing, default behaviors, UI preferences, etc.')
      ImGui.Spacing(ctx)
      ImGui.Spacing(ctx)
      ImGui.TextWrapped(ctx, 'Planned settings:')
      ImGui.BulletText(ctx, 'MIDI input channel selection')
      ImGui.BulletText(ctx, 'Default macro count (4, 8, or 16)')
      ImGui.BulletText(ctx, 'Knob sensitivity and behavior')
      ImGui.BulletText(ctx, 'Auto-save preferences')
      ImGui.BulletText(ctx, 'Color themes')
      ImGui.PopStyleColor(ctx)

      ImGui.EndTabItem(ctx)
    end

    -- Component Test Tab (for testing component mode pattern)
    if ImGui.BeginTabItem(ctx, '🧪 Component Test') then
      state.current_tab = 5
      ImGui.Spacing(ctx)
      draw_component_test(ctx)
      ImGui.EndTabItem(ctx)
    end

    ImGui.EndTabBar(ctx)
  end
end

return M
